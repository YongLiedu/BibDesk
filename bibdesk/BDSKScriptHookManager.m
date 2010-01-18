//
//  BDSKScriptHookManager.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 19/10/05.
/*
 This software is Copyright (c) 2005-2010
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "BDSKScriptHookManager.h"
#import "BibDocument.h"
#import "BDSKStringConstants.h"
#import "KFAppleScriptHandlerAdditionsCore.h"

// these correspond to the script codes in the .sdef file
#define kBDSKBibdeskSuite				'BDSK'
#define kBDSKPerformBibdeskAction		'pAct'
#define kBDSKPrepositionForScriptHook	'fshk'

#define MAX_RUNNING_SCRIPT_HOOKS	100

NSString *BDSKChangeFieldScriptHookName = @"Change Field";
NSString *BDSKCloseEditorWindowScriptHookName = @"Close Editor Window";
NSString *BDSKAddFileScriptHookName = @"Add File or URL";
NSString *BDSKRemoveFileScriptHookName = @"Remove File or URL";
NSString *BDSKWillAutoFileScriptHookName = @"Will Auto File";
NSString *BDSKDidAutoFileScriptHookName = @"Did Auto File";
NSString *BDSKWillGenerateCiteKeyScriptHookName = @"Will Generate Cite Key";
NSString *BDSKDidGenerateCiteKeyScriptHookName = @"Did Generate Cite Key";
NSString *BDSKImportPublicationsScriptHookName = @"Import Publications";
NSString *BDSKSaveDocumentScriptHookName = @"Save Document";

static BDSKScriptHookManager *sharedManager = nil;
static NSArray *scriptHookNames = nil;

@implementation BDSKScriptHookManager

+ (BDSKScriptHookManager *)sharedManager {
	if (sharedManager == nil)
		sharedManager = [[self alloc] init];
	return sharedManager;
}

+ (NSArray *)scriptHookNames {
    if (scriptHookNames == nil) {
		scriptHookNames = [[NSArray alloc] initWithObjects:BDSKChangeFieldScriptHookName, 
														   BDSKCloseEditorWindowScriptHookName, 
														   BDSKAddFileScriptHookName, 
														   BDSKRemoveFileScriptHookName, 
														   BDSKWillAutoFileScriptHookName, 
														   BDSKDidAutoFileScriptHookName, 
														   BDSKWillGenerateCiteKeyScriptHookName, 
														   BDSKDidGenerateCiteKeyScriptHookName, 
                                                           BDSKImportPublicationsScriptHookName, 
														   BDSKSaveDocumentScriptHookName, nil];
    }
    return scriptHookNames;
}

- (id)init {
    BDSKPRECONDITION(sharedManager == nil);
    if (self = [super init]) {
		scriptHooks = [[NSMutableDictionary alloc] initWithCapacity:3];
	}
	return self;
}

- (BDSKScriptHook *)scriptHookWithUniqueID:(NSNumber *)uniqueID {
	return [scriptHooks objectForKey:uniqueID];
}

- (void)removeScriptHook:(BDSKScriptHook *)scriptHook {
	[scriptHooks removeObjectForKey:[scriptHook uniqueID]];
}

- (BDSKScriptHook *)makeScriptHookWithName:(NSString *)name {
	if (name == nil)
		return nil;
	// Safety call in case a script generates a loop
	if ([scriptHooks count] >= MAX_RUNNING_SCRIPT_HOOKS) {
        [NSException raise:NSRangeException format:@"Too many script hooks are running. There may be a loop."];
		return nil;
	}
	// We could also build a cache of scripts for each name.
	NSString *path = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:BDSKScriptHooksKey] objectForKey:name];
	NSAppleScript *script = nil;
	
	if ([NSString isEmptyString:path]) {
		return nil; // no script hook with this name set in the prefs
	} else if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSLog(@"No script file found for script hook %@.", name);
		return nil;
	} else {
		NSDictionary *errorInfo = nil;
		script = [[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&errorInfo];
		if (script == nil) {
			NSLog(@"Error creating AppleScript: %@", [errorInfo objectForKey:NSAppleScriptErrorMessage]);
			return nil;
		}
	}
	
	BDSKScriptHook *scriptHook = [[[BDSKScriptHook alloc] initWithName:name script:script] autorelease];
	[scriptHooks setObject:scriptHook forKey:[scriptHook uniqueID]];
	[script release];
	
	return scriptHook;
}

- (BOOL)runScriptHook:(BDSKScriptHook *)scriptHook forPublications:(NSArray *)items document:(BibDocument *)document {
	BOOL rv = NO;
    
    if (scriptHook) {
        BDSKPRECONDITION([scriptHooks objectForKey:[scriptHook uniqueID]] == scriptHook);
        BDSKPRECONDITION([scriptHook script] != nil);
        
        [scriptHook setDocument:document];
        
        // execute the script
        @try {
            [[scriptHook script] executeHandler:kBDSKPerformBibdeskAction 
                                      fromSuite:kBDSKBibdeskSuite 
                        withLabelsAndParameters:keyDirectObject, items, kBDSKPrepositionForScriptHook, scriptHook, nil];
            rv = YES;
        }
        @catch(id exception) {
            NSLog(@"Error executing %@: %@", scriptHook, [exception respondsToSelector:@selector(reason)] ? [exception reason] : exception);
            rv = NO;
        }
        // cleanup
        [self removeScriptHook:scriptHook];
    }
	return rv;
}

- (BOOL)runScriptHookWithName:(NSString *)name forPublications:(NSArray *)items document:(BibDocument *)document {
	return [self runScriptHookWithName:name forPublications:items document:document field:nil oldValues:nil newValues:nil];
}

- (BOOL)runScriptHookWithName:(NSString *)name forPublications:(NSArray *)items document:(BibDocument *)document field:(NSString *)field oldValues:(NSArray *)oldValues newValues:(NSArray *)newValues {
	BDSKScriptHook *scriptHook = [self makeScriptHookWithName:name];
	if (scriptHook == nil)
		return NO;
	// set the values
    [scriptHook setField:field];
    [scriptHook setOldValues:oldValues];
    [scriptHook setNewValues:newValues];
	// execute the script and remove the script hook
	return [self runScriptHook:scriptHook forPublications:items document:document];
}

@end

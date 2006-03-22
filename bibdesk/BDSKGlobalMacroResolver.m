//
//  BDSKGlobalMacroResolver.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/20/06.
/*
 This software is Copyright (c) 2006
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

#import "BDSKGlobalMacroResolver.h"
#import "BibPrefController.h"
#import "NSMutableDictionary+ThreadSafety.h"

@implementation BDSKGlobalMacroResolver

// stores system-defined macros for the months.
// we grab their localized versions for display.
static BDSKGlobalMacroResolver *defaultMacroResolver; 

+ (BDSKGlobalMacroResolver *)defaultMacroResolver{
    if(defaultMacroResolver == nil)
        defaultMacroResolver = [[BDSKGlobalMacroResolver alloc] init];
    return defaultMacroResolver;
}

- (id)init{
    if (self = [super init]) {
        // Note we treat upper and lowercase values the same, 
        // because that's how btparse gives the string constants to us.
        // It is not quite correct because bibtex does discriminate,
        // but this is the best we can do.  The OFCreateCaseInsensitiveKeyMutableDictionary()
        // is used to create a dictionary with case-insensitive keys.
        standardMacroDefinitions = (NSMutableDictionary *)BDSKCreateCaseInsensitiveKeyMutableDictionary();
        macroDefinitions = (NSMutableDictionary *)BDSKCreateCaseInsensitiveKeyMutableDictionary();
        [self loadMacrosFromPreferences];
    }
    return self;
}

- (void)dealloc {
    [macroDefinitions release];
    [super dealloc];
}

- (void)loadMacrosFromPreferences{
    // stores system-defined macros for the months.
    // we grab their localized versions for display.
    NSDictionary *standardDefs = [NSDictionary dictionaryWithObjects:[[NSUserDefaults standardUserDefaults] objectForKey:NSMonthNameArray]
                                                             forKeys:[NSArray arrayWithObjects:@"jan", @"feb", @"mar", @"apr", @"may", @"jun", @"jul", @"aug", @"sep", @"oct", @"nov", @"dec", nil]];
    [standardMacroDefinitions addEntriesFromDictionary:standardDefs];
    
    OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
    // legacy, load old style prefs
    NSDictionary *oldMacros = [pw dictionaryForKey:BDSKBibStyleMacroDefinitionsKey];
    if (oldMacros)
        [macroDefinitions addEntriesFromDictionary:oldMacros];
    
    NSDictionary *macros = [pw dictionaryForKey:BDSKGlobalMacroDefinitionsKey];
    NSEnumerator *keyEnum = [macros keyEnumerator];
    NSString *key;
    
    while (key = [keyEnum nextObject]) {
        [macroDefinitions setObject:[NSString complexStringWithBibTeXString:[macros objectForKey:key] macroResolver:self]
                             forKey:key];
    }
    if(oldMacros){
        // we remove the old style prefs, as they are now merged with the new ones
        [pw removeObjectForKey:BDSKBibStyleMacroDefinitionsKey];
        [self synchronizePreferences];
    }
}

- (void)synchronizePreferences{
    NSMutableDictionary *macros = [[NSMutableDictionary alloc] initWithCapacity:[macroDefinitions count]];
    NSEnumerator *keyEnum = [macroDefinitions keyEnumerator];
    NSString *key;
    while (key = [keyEnum nextObject]) {
        [macros setObject:[[macroDefinitions objectForKey:key] stringAsBibTeXString] forKey:key];
    }
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:macros forKey:BDSKGlobalMacroDefinitionsKey];
}

// should we create an undomanager?
- (NSUndoManager *)undoManager{
    return nil;
}

#pragma mark BDSKMacroResolver protocol

- (NSDictionary *)macroDefinitions {
    return macroDefinitions;
}

- (void)addMacroDefinitionWithoutUndo:(NSString *)macroString forMacro:(NSString *)macroKey{
    [macroDefinitions setObject:macroString forKey:macroKey];
    
    [self synchronizePreferences];
}

- (void)changeMacroKey:(NSString *)oldKey to:(NSString *)newKey{
    if([macroDefinitions objectForKey:oldKey] == nil)
        [NSException raise:NSInvalidArgumentException
                    format:@"tried to change the value of a macro key that doesn't exist"];
    [[[self undoManager] prepareWithInvocationTarget:self]
        changeMacroKey:newKey to:oldKey];
    NSString *val = [macroDefinitions valueForKey:oldKey];
    [val retain]; // so the next line doesn't kill it
    [macroDefinitions removeObjectForKey:oldKey];
    [macroDefinitions setObject:[val autorelease] forKey:newKey];
    
    [self synchronizePreferences];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:newKey, @"newKey", oldKey, @"oldKey", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibDocMacroKeyChangedNotification
														object:self
													  userInfo:notifInfo];    
}

- (void)addMacroDefinition:(NSString *)macroString forMacro:(NSString *)macroKey{
    // we're adding a new one, so to undo, we remove.
    [[[self undoManager] prepareWithInvocationTarget:self]
            removeMacro:macroKey];

    [macroDefinitions setObject:macroString forKey:macroKey];
    
    [self synchronizePreferences];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:macroKey, @"macroKey", @"Add macro", @"type", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibDocMacroDefinitionChangedNotification
														object:self
													  userInfo:notifInfo];    
}

- (void)setMacroDefinition:(NSString *)newDefinition forMacro:(NSString *)macroKey{
    NSString *oldDef = [macroDefinitions objectForKey:macroKey];
    if(oldDef == nil){
        [self addMacroDefinition:newDefinition forMacro:macroKey];
        return;
    }
    // we're just changing an existing one, so to undo, we change back.
    [[[self undoManager] prepareWithInvocationTarget:self]
            setMacroDefinition:oldDef forMacro:macroKey];
    [macroDefinitions setObject:newDefinition forKey:macroKey];
    
    [self synchronizePreferences];

	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:macroKey, @"macroKey", @"Change macro", @"type", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibDocMacroDefinitionChangedNotification
														object:self
													  userInfo:notifInfo];    
}

- (void)removeMacro:(NSString *)macroKey{
    NSString *currentValue = [macroDefinitions objectForKey:macroKey];
    if(!currentValue){
        return;
    }else{
        [[[self undoManager] prepareWithInvocationTarget:self]
        addMacroDefinition:currentValue
                  forMacro:macroKey];
    }
    [macroDefinitions removeObjectForKey:macroKey];
    
    [self synchronizePreferences];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:macroKey, @"macroKey", @"Remove macro", @"type", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibDocMacroDefinitionChangedNotification
														object:self
													  userInfo:notifInfo];    
}

- (NSString *)valueOfMacro:(NSString *)macroString{
    NSString *value = [macroDefinitions objectForKey:macroString];
    if(value == nil)
        value = [standardMacroDefinitions objectForKey:macroString];
    return value;
}

@end

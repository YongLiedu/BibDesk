//
//  BDSKMacroResolver.m
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
#import "BDSKComplexString.h"
#import "NSMutableDictionary+ThreadSafety.h"
#import "BDSKConverter.h"
#import "BibTeXParser.h"
#import "BibDocument.h"


@interface BDSKGlobalMacroResolver : BDSKMacroResolver {
    NSMutableDictionary *standardMacroDefinitions;
    NSMutableDictionary *fileMacroDefinitions;
}

- (NSDictionary *)fileMacroDefinitions;
- (void)loadMacrosFromFiles;
- (void)synchronize;
- (void)handleMacroFilesChanged:(NSNotification *)notification;

@end


@interface BDSKMacroResolver (Private)
- (void)loadMacroDefinitions;
@end


@implementation BDSKMacroResolver

static BDSKGlobalMacroResolver *defaultMacroResolver; 

+ (id)defaultMacroResolver{
    if(defaultMacroResolver == nil)
        defaultMacroResolver = [[BDSKGlobalMacroResolver alloc] init];
    return defaultMacroResolver;
}

- (id)init{
    self = [self initWithDocument:nil];
    return self;
}

- (id)initWithDocument:(BibDocument *)aDocument{
    if (self = [super init]) {
        macroDefinitions = nil;
        document = aDocument;
    }
    return self;
}

- (void)dealloc {
    [macroDefinitions release];
    document = nil;
    [super dealloc];
}

- (BibDocument *)document{
    return document;
}

- (NSUndoManager *)undoManager{
    return [document undoManager];
}


- (NSString *)bibTeXString{
    BOOL shouldTeXify = [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShouldTeXifyWhenSavingAndCopyingKey];
	NSMutableString *macroString = [NSMutableString string];
    NSString *value;
    NSArray *macros = [[[self macroDefinitions] allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSEnumerator *macroEnum = [macros objectEnumerator];
    NSString *macro;
    
    while (macro = [macroEnum nextObject]){
		value = [[self macroDefinitions] objectForKey:macro];
		if(shouldTeXify){
			
			@try{
				value = [[BDSKConverter sharedConverter] stringByTeXifyingString:value];
			}
            @catch(id localException){
				if([localException isKindOfClass:[NSException class]] && [[localException name] isEqualToString:BDSKTeXifyException]){
                    NSException *exception = [NSException exceptionWithName:BDSKTeXifyException reason:[NSString stringWithFormat:NSLocalizedString(@"Character \"%@\" in the macro %@ can't be converted to TeX.", @"character conversion warning"), [localException reason], macro] userInfo:[NSDictionary dictionary]];
                    @throw exception;
				} else 
                    @throw;
            }							
		}                
        [macroString appendStrings:@"\n@string{", macro, @" = ", [value stringAsBibTeXString], @"}\n", nil];
    }
	return macroString;
}

#pragma mark BDSKMacroResolver protocol

- (NSDictionary *)macroDefinitions {
    if (macroDefinitions == nil)
        [self loadMacroDefinitions];
    return macroDefinitions;
}

- (void)addMacroDefinitionWithoutUndo:(NSString *)macroString forMacro:(NSString *)macroKey{
    if (macroDefinitions == nil)
        [self loadMacroDefinitions];
    [macroDefinitions setObject:macroString forKey:macroKey];
}

- (void)changeMacroKey:(NSString *)oldKey to:(NSString *)newKey{
    if (macroDefinitions == nil)
        [self loadMacroDefinitions];
    if([macroDefinitions objectForKey:oldKey] == nil)
        [NSException raise:NSInvalidArgumentException
                    format:@"tried to change the value of a macro key that doesn't exist"];
    [[[self undoManager] prepareWithInvocationTarget:self]
        changeMacroKey:newKey to:oldKey];
    NSString *val = [macroDefinitions valueForKey:oldKey];
    [val retain]; // so the next line doesn't kill it
    [macroDefinitions removeObjectForKey:oldKey];
    [macroDefinitions setObject:[val autorelease] forKey:newKey];
	
    [self synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKMacroDefinitionChangedNotification object:self];    
}

- (void)addMacroDefinition:(NSString *)macroString forMacro:(NSString *)macroKey{
    if (macroDefinitions == nil)
        [self loadMacroDefinitions];
    // we're adding a new one, so to undo, we remove.
    [[[self undoManager] prepareWithInvocationTarget:self]
            removeMacro:macroKey];

    [macroDefinitions setObject:macroString forKey:macroKey];
	
    [self synchronize];
	
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKMacroDefinitionChangedNotification object:self];    
}

- (void)setMacroDefinition:(NSString *)newDefinition forMacro:(NSString *)macroKey{
    if (macroDefinitions == nil)
        [self loadMacroDefinitions];
    NSString *oldDef = [macroDefinitions objectForKey:macroKey];
    if(oldDef == nil){
        [self addMacroDefinition:newDefinition forMacro:macroKey];
        return;
    }
    // we're just changing an existing one, so to undo, we change back.
    [[[self undoManager] prepareWithInvocationTarget:self]
            setMacroDefinition:oldDef forMacro:macroKey];
    [macroDefinitions setObject:newDefinition forKey:macroKey];
	
    [self synchronize];

    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKMacroDefinitionChangedNotification object:self];    
}

- (void)removeMacro:(NSString *)macroKey{
    if (macroDefinitions == nil)
        [self loadMacroDefinitions];
    NSString *currentValue = [macroDefinitions objectForKey:macroKey];
    if(!currentValue){
        return;
    }else{
        [[[self undoManager] prepareWithInvocationTarget:self]
              addMacroDefinition:currentValue
                        forMacro:macroKey];
    }
    [macroDefinitions removeObjectForKey:macroKey];
	
    [self synchronize];
	
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKMacroDefinitionChangedNotification object:self];    
}

- (NSString *)valueOfMacro:(NSString *)macroString{
    return [[self macroDefinitions] objectForKey:macroString];
}

@end


@implementation BDSKMacroResolver (Private)

- (void)loadMacroDefinitions{
    // Note we treat upper and lowercase values the same, 
    // because that's how btparse gives the string constants to us.
    // It is not quite correct because bibtex does discriminate,
    // but this is the best we can do.  The OFCreateCaseInsensitiveKeyMutableDictionary()
    // is used to create a dictionary with case-insensitive keys.
    macroDefinitions = (NSMutableDictionary *)BDSKCreateCaseInsensitiveKeyMutableDictionary();
}

@end


@implementation BDSKGlobalMacroResolver

- (id)initWithDocument:(BibDocument *)aDocument{
    if (self = [super initWithDocument:nil]) {
        // store system-defined macros for the months.
        // we grab their localized versions for display.
        NSDictionary *standardDefs = [NSDictionary dictionaryWithObjects:[[NSUserDefaults standardUserDefaults] objectForKey:NSMonthNameArray]
                                                                 forKeys:[NSArray arrayWithObjects:@"jan", @"feb", @"mar", @"apr", @"may", @"jun", @"jul", @"aug", @"sep", @"oct", @"nov", @"dec", nil]];
        standardMacroDefinitions = (NSMutableDictionary *)BDSKCreateCaseInsensitiveKeyMutableDictionary();
        [standardMacroDefinitions addEntriesFromDictionary:standardDefs];
        // these need to be loaded lazily, because loading them can use ourselves, but we aren't yet initialized
        fileMacroDefinitions = nil; 
		
        [[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(handleMacrosChanged:)
													 name:BDSKMacroDefinitionChangedNotification
												   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(handleMacroFilesChanged:)
													 name:BDSKMacroFilesChangedNotification
												   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [standardMacroDefinitions release];
    [fileMacroDefinitions release];
    [super dealloc];
}

- (void)loadMacroDefinitions{
    OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
    
    macroDefinitions = (NSMutableDictionary *)BDSKCreateCaseInsensitiveKeyMutableDictionary();
    
    // legacy, load old style prefs
    NSDictionary *oldMacros = [pw dictionaryForKey:BDSKBibStyleMacroDefinitionsKey];
    if ([oldMacros count])
        [macroDefinitions addEntriesFromDictionary:oldMacros];
    
    NSDictionary *macros = [pw dictionaryForKey:BDSKGlobalMacroDefinitionsKey];
    NSEnumerator *keyEnum = [macros keyEnumerator];
    NSString *key;
    
    while (key = [keyEnum nextObject]) {
        // we don't check for circular macros, there shouldn't be any. Or do we want to be paranoid?
        [macroDefinitions setObject:[NSString complexStringWithBibTeXString:[macros objectForKey:key] macroResolver:self]
                             forKey:key];
    }
    if ([oldMacros count]) {
        // we remove the old style prefs, as they are now merged with the new ones
        [pw removeObjectForKey:BDSKBibStyleMacroDefinitionsKey];
        [self synchronize];
    }
}

- (void)loadMacrosFromFiles{
    OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
    NSEnumerator *fileE = [[pw stringArrayForKey:BDSKGlobalMacroFilesKey] objectEnumerator];
    NSString *file;
    BOOL hadProblems;
    
    fileMacroDefinitions = (NSMutableDictionary *)BDSKCreateCaseInsensitiveKeyMutableDictionary();
    
    while (file = [fileE nextObject]) {
        NSString *fileContent = [NSString stringWithContentsOfFile:file];
        NSDictionary *macroDefs = nil;
        if (fileContent == nil) continue;
        hadProblems = NO;
        if ([[file pathExtension] caseInsensitiveCompare:@"bib"] == NSOrderedSame)
            macroDefs = [BibTeXParser macrosFromBibTeXString:fileContent hadProblems:&hadProblems document:nil];
        else if ([[file pathExtension] caseInsensitiveCompare:@"bst"] == NSOrderedSame)
            macroDefs = [BibTeXParser macrosFromBibTeXStyle:fileContent document:nil];
        else continue;
        if (hadProblems == NO) {
            NSEnumerator *macroE = [macroDefs keyEnumerator];
            NSString *macroKey;
            NSString *macroString;
            
            while (macroKey = [macroE nextObject]) {
                macroString = [macroDefs objectForKey:macroKey];
                if([BDSKComplexString isCircularMacro:macroKey forDefinition:macroString macroResolver:self])
                    NSLog(@"Macro from file %@ leads to circular definition, ignored: %@ = %@", file, macroKey, [macroString stringAsBibTeXString]);
                else
                    [fileMacroDefinitions setObject:macroString forKey:macroKey];
            }
        }
    }
}

- (void)synchronize{
    NSMutableDictionary *macros = [[NSMutableDictionary alloc] initWithCapacity:[[self macroDefinitions] count]];
    NSEnumerator *keyEnum = [[self macroDefinitions] keyEnumerator];
    NSString *key;
    while (key = [keyEnum nextObject]) {
        [macros setObject:[[[self macroDefinitions] objectForKey:key] stringAsBibTeXString] forKey:key];
    }
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:macros forKey:BDSKGlobalMacroDefinitionsKey];
}

- (void)handleMacroFilesChanged:(NSNotification *)notification{
    [fileMacroDefinitions release];
    fileMacroDefinitions = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKMacroDefinitionChangedNotification object:self];    
}

- (NSDictionary *)fileMacroDefinitions{
    if (fileMacroDefinitions == nil)
        [self loadMacrosFromFiles];
    return fileMacroDefinitions;
}

- (NSString *)valueOfMacro:(NSString *)macroString{
    NSString *value = [[self macroDefinitions] objectForKey:macroString];
    if(value == nil)
        value = [[self fileMacroDefinitions] objectForKey:macroString];
    if(value == nil)
        value = [standardMacroDefinitions objectForKey:macroString];
    return value;
}

@end

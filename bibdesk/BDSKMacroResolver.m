//
//  BDSKMacroResolver.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/20/06.
/*
 This software is Copyright (c) 2006-2009
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

#import "BDSKMacroResolver.h"
#import "BDSKStringConstants.h"
#import "BDSKComplexString.h"
#import "BDSKStringNode.h"
#import "NSDictionary_BDSKExtensions.h"
#import "BDSKConverter.h"
#import "BDSKBibTeXParser.h"
#import "BDSKOwnerProtocol.h"
#import "BibDocument.h"
#import "NSError_BDSKExtensions.h"

static char BDSKMacroResolverDefaultsObservationContext;

@interface BDSKGlobalMacroResolver : BDSKMacroResolver {
    NSMutableDictionary *standardMacroDefinitions;
    NSMutableDictionary *fileMacroDefinitions;
}

- (NSDictionary *)fileMacroDefinitions;
- (void)loadMacrosFromFiles;
- (void)synchronize;

@end


@interface BDSKMacroResolver (Private)
- (void)loadMacroDefinitions;
- (void)synchronize;
- (void)addMacro:(NSString *)macroKey toArray:(NSMutableArray *)array;
@end


@implementation BDSKMacroResolver

static BDSKGlobalMacroResolver *defaultMacroResolver = nil; 

+ (id)defaultMacroResolver{
    if(defaultMacroResolver == nil)
        defaultMacroResolver = [[BDSKGlobalMacroResolver alloc] init];
    return defaultMacroResolver;
}

- (id)init{
    self = [self initWithOwner:nil];
    return self;
}

- (id)initWithOwner:(id<BDSKOwner>)anOwner{
    if (self = [super init]) {
        macroDefinitions = nil;
        owner = anOwner;
        modification = 0;
    }
    return self;
}

- (void)dealloc {
    [macroDefinitions release];
    owner = nil;
    [super dealloc];
}

- (id<BDSKOwner>)owner{
    return owner;
}

- (NSUndoManager *)undoManager{
    return [owner undoManager];
}

- (unsigned long long)modification {
    return modification;
}

- (NSString *)bibTeXString{
    if (macroDefinitions == nil)
        return @"";
    
    // bibtex requires that macros whose definitions contain macros are ordered in the document after the macros on which they depend
    NSMutableArray *orderedMacros = [NSMutableArray array];
    
    for (NSString *macro in [[macroDefinitions allKeys] sortedArrayUsingSelector:@selector(compare:)])
        [self addMacro:macro toArray:orderedMacros];
    
    BOOL shouldTeXify = [[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldTeXifyWhenSavingAndCopyingKey];
	NSMutableString *macroString = [NSMutableString string];
    NSString *value;
    
    for (NSString *macro in orderedMacros) {
		value = [macroDefinitions objectForKey:macro];
		if (shouldTeXify)
            value = [value stringByTeXifyingString];
        [macroString appendStrings:@"\n@string{", macro, @" = ", [value stringAsBibTeXString], @"}\n", nil];
    }
	return macroString;
}

- (BOOL)macroDefinition:(NSString *)macroDef dependsOnMacro:(NSString *)macroKey{
    if ([macroDef isComplex] == NO) 
        return NO;
    
    BDSKASSERT([[macroDef macroResolver] isEqual:self]);
    
    for (BDSKStringNode *node in [macroDef nodes]) {
        if([node type] != BDSKStringNodeMacro)
            continue;
        
        NSString *key = [node value];
        
        if ([key caseInsensitiveCompare:macroKey] == NSOrderedSame)
            return YES;
        
        NSString *value = [self valueOfMacro:key];
        if ([self macroDefinition:value dependsOnMacro:macroKey])
            return YES;
    }
    return NO;
}

#pragma mark Macros management

// used for autocompletion; returns global macro definitions + local (document) definitions
- (NSDictionary *)allMacroDefinitions {
    NSMutableDictionary *allDefs = [[[[BDSKMacroResolver defaultMacroResolver] allMacroDefinitions] mutableCopy] autorelease];
    [allDefs addEntriesFromDictionary:[self macroDefinitions]];
    return allDefs;
}

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
    
    // retain in case these go away with removeObjectForKey:
    [[val retain] autorelease]; 
    [[oldKey retain] autorelease];
    [macroDefinitions removeObjectForKey:oldKey];
    [macroDefinitions setObject:val forKey:newKey];
	
    modification++;
    [self synchronize];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Change key", @"type", oldKey, @"oldKey", newKey, @"newKey", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKMacroDefinitionChangedNotification 
                                                        object:self
                                                      userInfo:userInfo];    
}

- (void)addMacroDefinition:(NSString *)macroString forMacro:(NSString *)macroKey{
    if (macroDefinitions == nil)
        [self loadMacroDefinitions];
    // we're adding a new one, so to undo, we remove.
    [[[self undoManager] prepareWithInvocationTarget:self]
            removeMacro:macroKey];

    [macroDefinitions setObject:macroString forKey:macroKey];
	
    modification++;
    [self synchronize];
	
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Add macro", @"type", macroKey, @"macroKey", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKMacroDefinitionChangedNotification 
                                                        object:self
                                                      userInfo:userInfo];    
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
	
    modification++;
    [self synchronize];

    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Change macro", @"type", macroKey, @"macroKey", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKMacroDefinitionChangedNotification 
                                                        object:self
                                                      userInfo:userInfo];    
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
	
    modification++;
    [self synchronize];
	
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Remove macro", @"type", macroKey, @"macroKey", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKMacroDefinitionChangedNotification 
                                                        object:self
                                                      userInfo:userInfo];    
}

- (void)removeAllMacros{
    [macroDefinitions release];
    macroDefinitions = nil;
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Remove macro", @"type", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKMacroDefinitionChangedNotification 
                                                        object:self
                                                      userInfo:userInfo];    
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
    macroDefinitions = [[NSMutableDictionary alloc] initForCaseInsensitiveKeys];
    modification++;
}

- (void)synchronize{}

- (void)addMacro:(NSString *)macroKey toArray:(NSMutableArray *)array{
    if([array containsObject:macroKey])
        return;
    NSString *value = [macroDefinitions objectForKey:macroKey];
    
    // if the definition is complex, we first have to add the macros that appear there
    if ([value isComplex]) {
        for (BDSKStringNode *node in [value nodes]) {
            if ([node type] == BDSKStringNodeMacro)
                [self addMacro:[node value] toArray:array];
        }
    }
    [array addObject:macroKey];
}

@end


@implementation BDSKGlobalMacroResolver

- (id)initWithOwner:(id<BDSKOwner>)anOwner{
    if (self = [super initWithOwner:nil]) {
        // store system-defined macros for the months.
        NSArray *monthNames = [[[[NSDateFormatter alloc] init] autorelease] standaloneMonthSymbols];
        NSDictionary *standardDefs = [NSDictionary dictionaryWithObjects:monthNames
                                                                 forKeys:[NSArray arrayWithObjects:@"jan", @"feb", @"mar", @"apr", @"may", @"jun", @"jul", @"aug", @"sep", @"oct", @"nov", @"dec", nil]];
        standardMacroDefinitions = [[NSMutableDictionary alloc] initForCaseInsensitiveKeys];
        [standardMacroDefinitions addEntriesFromDictionary:standardDefs];
        // these need to be loaded lazily, because loading them can use ourselves, but we aren't yet initialized
        fileMacroDefinitions = nil; 
		
        
        [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self
            forKeyPath:[@"values." stringByAppendingString:BDSKGlobalMacroFilesKey]
               options:0
               context:&BDSKMacroResolverDefaultsObservationContext];
    }
    return self;
}

- (void)dealloc {
    [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKGlobalMacroFilesKey]];
    [standardMacroDefinitions release];
    [fileMacroDefinitions release];
    [super dealloc];
}

- (void)loadMacroDefinitions{
    NSUserDefaults*sud = [NSUserDefaults standardUserDefaults];
    
    macroDefinitions = [[NSMutableDictionary alloc] initForCaseInsensitiveKeys];
    
    // legacy, load old style prefs
    NSDictionary *oldMacros = [sud dictionaryForKey:BDSKBibStyleMacroDefinitionsKey];
    if ([oldMacros count])
        [macroDefinitions addEntriesFromDictionary:oldMacros];
    
    NSDictionary *macros = [sud dictionaryForKey:BDSKGlobalMacroDefinitionsKey];
    NSString *value;
    NSError *error = nil;
    
    for (NSString *key in macros) {
        // we don't check for circular macros, there shouldn't be any. Or do we want to be paranoid?
        if (value = [NSString stringWithBibTeXString:[macros objectForKey:key] macroResolver:self error:&error])
            [macroDefinitions setObject:value forKey:key];
        else
            NSLog(@"Ignoring invalid complex macro: %@", [error localizedDescription]);
    }
    if ([oldMacros count]) {
        // we remove the old style prefs, as they are now merged with the new ones
        [sud removeObjectForKey:BDSKBibStyleMacroDefinitionsKey];
        [self synchronize];
    }
    modification++;
}

- (void)loadMacrosFromFiles{
    NSUserDefaults*sud = [NSUserDefaults standardUserDefaults];
    
    fileMacroDefinitions = [[NSMutableDictionary alloc] initForCaseInsensitiveKeys];
    
    for (NSString *file in [sud stringArrayForKey:BDSKGlobalMacroFilesKey]) {
        NSString *fileContent = [NSString stringWithContentsOfFile:file encoding:0 guessEncoding:YES];
        NSDictionary *macroDefs = nil;
        if (fileContent == nil) continue;
        if ([[file pathExtension] caseInsensitiveCompare:@"bib"] == NSOrderedSame)
            macroDefs = [BDSKBibTeXParser macrosFromBibTeXString:fileContent document:nil];
        else if ([[file pathExtension] caseInsensitiveCompare:@"bst"] == NSOrderedSame)
            macroDefs = [BDSKBibTeXParser macrosFromBibTeXStyle:fileContent document:nil];
        else continue;
        if (macroDefs != nil) {
            NSString *macroString;
            
            for (NSString *macroKey in macroDefs) {
                macroString = [macroDefs objectForKey:macroKey];
                if([self macroDefinition:macroString dependsOnMacro:macroKey])
                    NSLog(@"Macro from file %@ leads to circular definition, ignored: %@ = %@", file, macroKey, [macroString stringAsBibTeXString]);
                else
                    [fileMacroDefinitions setObject:macroString forKey:macroKey];
            }
        }
    }
    modification++;
}

- (void)synchronize{
    NSMutableDictionary *macros = [[NSMutableDictionary alloc] initWithCapacity:[[self macroDefinitions] count]];
    for (NSString *key in [self macroDefinitions])
        [macros setObject:[[[self macroDefinitions] objectForKey:key] stringAsBibTeXString] forKey:key];
    [[NSUserDefaults standardUserDefaults] setObject:macros forKey:BDSKGlobalMacroDefinitionsKey];
    [macros release];
}

- (NSDictionary *)allMacroDefinitions {
    NSMutableDictionary *allDefs = [[standardMacroDefinitions mutableCopy] autorelease];
    [allDefs addEntriesFromDictionary:[self fileMacroDefinitions]];
    [allDefs addEntriesFromDictionary:[self macroDefinitions]];
    return allDefs;
}

- (NSDictionary *)fileMacroDefinitions{
    if (fileMacroDefinitions == nil)
        [self loadMacrosFromFiles];
    return fileMacroDefinitions;
}

- (NSString *)valueOfMacro:(NSString *)macroString{
    return ([[self macroDefinitions] objectForKey:macroString] ?:
            [[self fileMacroDefinitions] objectForKey:macroString]) ?:
            [standardMacroDefinitions objectForKey:macroString];
}
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &BDSKMacroResolverDefaultsObservationContext) {
        [fileMacroDefinitions release];
        fileMacroDefinitions = nil;
        modification++;
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKMacroDefinitionChangedNotification object:self];    
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

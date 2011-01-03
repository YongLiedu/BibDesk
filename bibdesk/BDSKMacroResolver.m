//
//  BDSKMacroResolver.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/20/06.
/*
 This software is Copyright (c) 2006-2011
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

NSString *BDSKMacroResolverTypeKey = @"type";
NSString *BDSKMacroResolverMacroKey = @"macro";
NSString *BDSKMacroResolverOldMacroKey = @"oldMacro";
NSString *BDSKMacroResolverNewMacroKey = @"newMacro";

NSString *BDSKMacroResolverAddType = @"add";
NSString *BDSKMacroResolverRemoveType = @"remove";
NSString *BDSKMacroResolverChangeType = @"change";
NSString *BDSKMacroResolverRenameType = @"rename";
NSString *BDSKMacroResolverSetType = @"set";

static char BDSKMacroResolverDefaultsObservationContext;

@interface BDSKGlobalMacroResolver : BDSKMacroResolver {
    NSDictionary *standardMacroDefinitions;
    NSMutableDictionary *fileMacroDefinitions;
}

- (NSDictionary *)fileMacroDefinitions;
- (void)loadMacrosFromFiles;
- (void)synchronize;

@end


@interface BDSKMacroResolver (Private)
- (void)loadMacroDefinitions;
- (void)synchronize;
- (void)addMacro:(NSString *)macro toArray:(NSMutableArray *)array;
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
    BDSKDESTROY(macroDefinitions);
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

- (BOOL)string:(NSString *)string dependsOnMacro:(NSString *)macro {
    return [self string:string dependsOnMacro:macro inMacroDefinitions:nil];
}

- (BOOL)string:(NSString *)string dependsOnMacro:(NSString *)macro inMacroDefinitions:(NSDictionary *)dictionary {
    if ([string isComplex] == NO) 
        return NO;
    
    BDSKASSERT([[string macroResolver] isEqual:self]);
    
    for (BDSKStringNode *node in [string nodes]) {
        if([node type] != BDSKStringNodeMacro)
            continue;
        
        NSString *aMacro = [node value];
        
        if ([aMacro caseInsensitiveCompare:macro] == NSOrderedSame)
            return YES;
        
        NSString *aString = dictionary ? [dictionary objectForKey:aMacro] : [self valueOfMacro:aMacro];
        
        if ([self string:aString dependsOnMacro:macro])
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

- (void)setMacroDefinitions:(NSDictionary *)dictionary {
    if (macroDefinitions == nil)
        [self loadMacroDefinitions];
    [macroDefinitions setDictionary:dictionary];
    
    modification++;

    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:BDSKMacroResolverSetType, BDSKMacroResolverTypeKey, nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKMacroDefinitionChangedNotification 
                                                        object:self
                                                      userInfo:userInfo];    
}

- (void)changeMacro:(NSString *)oldMacro to:(NSString *)newMacro{
    if (macroDefinitions == nil)
        [self loadMacroDefinitions];
    if([macroDefinitions objectForKey:oldMacro] == nil)
        [NSException raise:NSInvalidArgumentException
                    format:@"tried to change the value of a macro key that doesn't exist"];
    [[[self undoManager] prepareWithInvocationTarget:self]
        changeMacro:newMacro to:oldMacro];
    NSString *val = [macroDefinitions valueForKey:oldMacro];
    
    // retain in case these go away with removeObjectForKey:
    [[val retain] autorelease]; 
    [[oldMacro retain] autorelease];
    [macroDefinitions removeObjectForKey:oldMacro];
    [macroDefinitions setObject:val forKey:newMacro];
	
    modification++;
    [self synchronize];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:BDSKMacroResolverRenameType, BDSKMacroResolverTypeKey, oldMacro, BDSKMacroResolverOldMacroKey, newMacro,BDSKMacroResolverNewMacroKey, nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKMacroDefinitionChangedNotification 
                                                        object:self
                                                      userInfo:userInfo];    
}

- (void)setMacro:(NSString *)macro toValue:(NSString *)value {
    if (macroDefinitions == nil)
        [self loadMacroDefinitions];
    NSString *oldDef = [macroDefinitions objectForKey:macro];
    [[[self undoManager] prepareWithInvocationTarget:self]
            setMacro:macro toValue:oldDef];
    NSString *type;
    if (value == nil) {
        if (oldDef == nil)
            return;
        type = BDSKMacroResolverRemoveType;
    } else if (oldDef == nil) {
        type = BDSKMacroResolverAddType;
    } else {
        type = BDSKMacroResolverChangeType;
    }
    [macroDefinitions setValue:value forKey:macro];
	
    modification++;
    [self synchronize];

    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:type, BDSKMacroResolverTypeKey, macro, BDSKMacroResolverMacroKey, nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKMacroDefinitionChangedNotification 
                                                        object:self
                                                      userInfo:userInfo];    
}

- (NSString *)valueOfMacro:(NSString *)macro{
    return [[self macroDefinitions] objectForKey:macro];
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

- (void)addMacro:(NSString *)macro toArray:(NSMutableArray *)array{
    if([array containsObject:macro])
        return;
    NSString *value = [macroDefinitions objectForKey:macro];
    
    // if the definition is complex, we first have to add the macros that appear there
    if ([value isComplex]) {
        for (BDSKStringNode *node in [value nodes]) {
            if ([node type] == BDSKStringNodeMacro)
                [self addMacro:[node value] toArray:array];
        }
    }
    [array addObject:macro];
}

@end


@implementation BDSKGlobalMacroResolver

- (id)initWithOwner:(id<BDSKOwner>)anOwner{
    if (self = [super initWithOwner:nil]) {
        // store system-defined macros for the months.
        NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
        if ([[[formatter calendar] calendarIdentifier] isEqualToString:NSGregorianCalendar] == NO)
            [formatter setCalendar:[[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease]];
        NSString *shortMonthNames[12] = {@"jan", @"feb", @"mar", @"apr", @"may", @"jun", @"jul", @"aug", @"sep", @"oct", @"nov", @"dec"};
        NSString *monthNames[12];
        [[formatter standaloneMonthSymbols] getObjects:monthNames range:NSMakeRange(0, 12)];
        standardMacroDefinitions = [[NSDictionary alloc] initWithObjects:monthNames forCaseInsensitiveKeys:shortMonthNames count:12];
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
    BDSKDESTROY(standardMacroDefinitions);
    BDSKDESTROY(fileMacroDefinitions);
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
            macroDefs = [BDSKBibTeXParser macrosFromBibTeXString:fileContent macroResolver:nil];
        else if ([[file pathExtension] caseInsensitiveCompare:@"bst"] == NSOrderedSame)
            macroDefs = [BDSKBibTeXParser macrosFromBibTeXStyle:fileContent macroResolver:nil];
        else continue;
        if (macroDefs != nil) {
            NSString *value;
            
            for (NSString *macro in macroDefs) {
                value = [macroDefs objectForKey:macro];
                if([self string:value dependsOnMacro:macro])
                    NSLog(@"Macro from file %@ leads to circular definition, ignored: %@ = %@", file, macro, [value stringAsBibTeXString]);
                else
                    [fileMacroDefinitions setObject:value forKey:macro];
            }
        }
    }
    modification++;
}

- (void)synchronize{
    NSMutableDictionary *macros = [[NSMutableDictionary alloc] initWithCapacity:[[self macroDefinitions] count]];
    for (NSString *macro in [self macroDefinitions])
        [macros setObject:[[[self macroDefinitions] objectForKey:macro] stringAsBibTeXString] forKey:macro];
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

- (NSString *)valueOfMacro:(NSString *)macro{
    return ([[self macroDefinitions] objectForKey:macro] ?:
            [[self fileMacroDefinitions] objectForKey:macro]) ?:
            [standardMacroDefinitions objectForKey:macro];
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

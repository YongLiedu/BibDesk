//
//  BDSKGroup+Scripting.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/5/08.
/*
 This software is Copyright (c) 2008-2012
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

#import "BDSKGroup+Scripting.h"
#import "BibDocument.h"
#import "BibDocument+Scripting.h"
#import "BibDocument_Groups.h"
#import "BDSKGroupsArray.h"
#import "BDSKPublicationsArray.h"
#import "BDSKMacro.h"
#import "BDSKMacroResolver.h"
#import "BDSKMacroResolver+Scripting.h"
#import "BibItem.h"
#import "BibItem+Scripting.h"
#import "BibAuthor.h"
#import "BibAuthor+Scripting.h"
#import "BDSKCondition+Scripting.h"
#import "NSObject_BDSKExtensions.h"
#import "BDSKServerInfo.h"
#import "BDSKCondition.h"
#import "BDSKFilter.h"
#import "NSWorkspace_BDSKExtensions.h"


@implementation BDSKGroup (Scripting)

+ (BOOL)accessInstanceVariablesDirectly {
	return NO;
}

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSUniqueIDSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"groups" uniqueID:[self uniqueID]] autorelease];
}

- (id)newScriptingObjectOfClass:(Class)class forValueForKey:(NSString *)key withContentsValue:(id)contentsValue properties:(NSDictionary *)properties {
    if ([class isSubclassOfClass:[BibItem class]])
        // external groups do not accept new scriptable items, so the owner for the new item should always be the document
        return [[self document] newScriptingObjectOfClass:class forValueForKey:key withContentsValue:contentsValue properties:properties];
    return [super newScriptingObjectOfClass:class forValueForKey:key withContentsValue:contentsValue properties:properties];
}

- (id)copyScriptingValue:(id)value forKey:(NSString *)key withProperties:(NSDictionary *)properties {
    if ([key isEqualToString:@"scriptingPublications"])
        // external groups do not accept new scriptable items, so the owner for the copied item should always be the document
        return [[self document] copyScriptingValue:value forKey:key withProperties:properties];
    return [super copyScriptingValue:value forKey:key withProperties:properties];
}

- (id)valueInScriptingPublicationsWithUniqueID:(NSString *)aUniqueID {
	NSURL *identifierURL = [NSURL URLWithString:aUniqueID];
    id pub = nil;
    if (identifierURL) {
        pub = [[document publications] itemForIdentifierURL:identifierURL];
        if ([self containsItem:pub] == NO)
            pub = nil;
    }
    return pub;
}

- (NSArray *)scriptingPublications {
    NSMutableArray *scriptingPublications = [NSMutableArray array];
    
    for (BibItem *pub in [document publications]) {
        if ([self containsItem:pub])
            [scriptingPublications addObject:pub];
    }
    
    return scriptingPublications;
}

- (NSArray *)authors {
    return [BibAuthor authorsInPublications:[self scriptingPublications]];
}

- (BibAuthor *)valueInAuthorsWithName:(NSString *)aName {
    return [BibAuthor authorWithName:aName inPublications:[self scriptingPublications]];
}

- (NSArray *)editors {
    return [BibAuthor editorsInPublications:[self scriptingPublications]];
}

- (BibAuthor *)valueInEditorsWithName:(NSString *)aName {
    return [BibAuthor editorWithName:aName inPublications:[self scriptingPublications]];
}

- (NSArray *)macros {
    return [[self macroResolver] macros];
}

- (BDSKMacro *)valueInMacrosWithName:(NSString *)aName {
    return [[self macroResolver] valueInMacrosWithName:aName];
}

- (NSString *)scriptingName {
    return [self stringValue];
}

@end

#pragma mark -

@implementation BDSKLibraryGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSUniqueIDSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"libraryGroups" uniqueID:[self uniqueID]] autorelease];
}

- (NSArray *)scriptingPublications {
    return [[self document] scriptingPublications];
}

- (void)insertObject:(BibItem *)pub inScriptingPublicationsAtIndex:(NSUInteger)idx {
    [[self document] insertObject:pub inScriptingPublicationsAtIndex:idx];
}

- (void)removeObjectFromScriptingPublicationsAtIndex:(NSUInteger)idx {
    [[self document] removeObjectFromScriptingPublicationsAtIndex:idx];
}

@end

#pragma mark -

@implementation BDSKMutableGroup (Scripting)

- (void)setScriptingName:(NSString *)newName {
    if ([self isNameEditable]) {
        [self setName:newName];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of group.",@"Error description")];
    }
}

@end

#pragma mark -

@implementation BDSKStaticGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSUniqueIDSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"staticGroups" uniqueID:[self uniqueID]] autorelease];
}

- (NSArray *)scriptingPublications {
    return [self publications];
}

- (void)insertObject:(BibItem *)pub inScriptingPublicationsAtIndex:(NSUInteger)idx {
    if ([pub owner] == nil)
        [[self document] addPublication:pub];
	if ([[pub owner] isEqual:[self document]] == NO) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add publication from another document or external group, use duplicate.",@"Error description")];
    } else if ([self containsItem:pub] == NO) {
        [self addPublication:pub];
        [[[self document] undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    }
}

- (void)removeObjectFromScriptingPublicationsAtIndex:(NSUInteger)idx {
    [self removePublication:[publications objectAtIndex:idx]];
    [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

@end

#pragma mark -

@implementation BDSKLastImportGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSUniqueIDSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"lastImportGroups" uniqueID:[self uniqueID]] autorelease];
}

- (void)setAsName:(NSString *)newName {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of last import group.",@"Error description")];
}

- (void)insertObject:(BibItem *)pub inScriptingPublicationsAtIndex:(NSUInteger)idx {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [cmd setScriptErrorString:NSLocalizedString(@"Cannot modify publications of last import group.",@"Error description")];
}

- (void)removeObjectFromScriptingPublicationsAtIndex:(NSUInteger)idx {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [cmd setScriptErrorString:NSLocalizedString(@"Cannot modify publications of last import group.",@"Error description")];
}

@end

#pragma mark -

@implementation BDSKSmartGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSUniqueIDSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"smartGroups" uniqueID:[self uniqueID]] autorelease];
}

- (id)newScriptingObjectOfClass:(Class)class forValueForKey:(NSString *)key withContentsValue:(id)contentsValue properties:(NSDictionary *)properties {
    if ([class isSubclassOfClass:[BDSKCondition class]])
        return [[BDSKCondition alloc] initWithScriptingProperties:properties];
    return [super newScriptingObjectOfClass:class forValueForKey:key withContentsValue:contentsValue properties:properties];
}

- (NSArray *)conditions {
    return [[self filter] conditions];
}

- (void)insertObject:(BDSKCondition *)condition inConditionsAtIndex:(NSUInteger)idx {
	if ([condition group]) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add condition from another smart group, use make or duplicate.",@"Error description")];
	} else {
        NSMutableArray *conditions = [[[self filter] conditions] mutableCopy];
        [conditions insertObject:condition atIndex:idx];
        [[self filter] setConditions:conditions];
        [conditions release];
        [[[self document] undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    }
}

- (void)removeObjectFromConditionsAtIndex:(NSUInteger)idx {
	NSMutableArray *conditions = [[[self filter] conditions] mutableCopy];
    [conditions removeObjectAtIndex:idx];
    [[self filter] setConditions:conditions];
    [conditions release];
    [[[self document] undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (BOOL)satisfyAll {
    return [[self filter] conjunction] == BDSKAnd;
}

- (void)setSatisfyAll:(BOOL)flag {
    return [[self filter] setConjunction:flag ? BDSKAnd : BDSKOr];
}

@end

#pragma mark -

@implementation BDSKCategoryGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSUniqueIDSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"fieldGroups" uniqueID:[self uniqueID]] autorelease];
}

- (void)insertObject:(BibItem *)pub inScriptingPublicationsAtIndex:(NSUInteger)idx {
    if ([pub owner] == nil)
        [[self document] addPublication:pub];
	if ([[pub owner] isEqual:[self document]] == NO) {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot add publication from another document or external group, use duplicate.",@"Error description")];
    } else if ([self containsItem:pub] == NO) {
        [[self document] addPublications:[NSArray arrayWithObject:pub] toGroup:self];
        [[[self document] undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    }
}

- (void)removeObjectFromScriptingPublicationsAtIndex:(NSUInteger)idx {
    [[self document] removePublications:[[self scriptingPublications] subarrayWithRange:NSMakeRange(idx, 1)] fromGroups:[NSArray arrayWithObject:self]];
    [[[self document] undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

@end

#pragma mark -

@implementation BDSKExternalGroup (Scripting)

- (NSArray *)scriptingPublications {
    return [self publications];
}

- (id)valueInScriptingPublicationsWithUniqueID:(NSString *)aUniqueID {
	NSURL *identifierURL = [NSURL URLWithString:aUniqueID];
    return identifierURL ? [[self publications] itemForIdentifierURL:identifierURL] : nil;
}

@end

#pragma mark -

@implementation BDSKMutableExternalGroup (Scripting)

- (void)setScriptingName:(NSString *)newName {
    [self setName:newName];
    [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

@end

#pragma mark -

@implementation BDSKURLGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSUniqueIDSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"externalFileGroups" uniqueID:[self uniqueID]] autorelease];
}

- (NSString *)URLString {
    return [[self URL] absoluteString];
}

- (void)setURLString:(NSString *)newURLString {
    [self setURL:[NSURL URLWithString:newURLString]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (NSURL *)scriptingFileURL {
    NSURL *fileURL = [self URL];
    return [fileURL isFileURL] ? fileURL : nil;
}

- (void)setScriptingFileURL:(NSURL *)newURL {
    [self setURL:newURL];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

@end

#pragma mark -

@implementation BDSKScriptGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSUniqueIDSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"scriptGroups" uniqueID:[self uniqueID]] autorelease];
}

- (NSURL *)scriptURL {
    return [NSURL fileURLWithPath:[self scriptPath]];
}

- (void)setScriptURL:(NSURL *)newScriptURL {
    [self setScriptPath:[newScriptURL path]];
    [self setScriptType:[[NSWorkspace sharedWorkspace] isAppleScriptFileAtPath:[newScriptURL path]] ? BDSKAppleScriptType : BDSKShellScriptType];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (NSString *)scriptingScriptArguments {
    NSString *arguments = [self scriptArguments];
    return arguments ?: @"";
}

- (void)setScriptingScriptArguments:(NSString *)newArguments {
    [self setScriptArguments:newArguments];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

@end

#pragma mark -

@implementation BDSKSearchGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSUniqueIDSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"searchGroups" uniqueID:[self uniqueID]] autorelease];
}

- (NSString *)scriptingSearchTerm {
    return [self searchTerm];
}

- (void)setScriptingSearchTerm:(NSString *)newSearchTerm {
    [self setSearchTerm:newSearchTerm];
}

- (NSString *)scriptingServerType {
    return [self type];
}

- (NSDictionary *)scriptingServerInfo {
    BDSKServerInfo *serverInfo = [self serverInfo];
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    
    [info setValue:[serverInfo type] forKey:@"type"];
    [info setValue:[serverInfo name] forKey:@"name"];
    [info setValue:[serverInfo database] forKey:@"database"];
    if ([serverInfo isZoom]) {
        [info setValue:[serverInfo host] forKey:@"host"];
        [info setValue:[serverInfo port] forKey:@"port"];
        [info setValue:[serverInfo username] forKey:@"username"];
        [info setValue:[serverInfo password] forKey:@"password"];
        [info setValue:[serverInfo recordSyntax] forKey:@"recordSyntax"];
        [info setValue:[serverInfo resultEncoding] forKey:@"resultEncoding"];
        [info setValue:[NSNumber numberWithBool:[serverInfo removeDiacritics]] forKey:@"removeDiacritics"];
    }
    
    return info;
}

- (void)setScriptingServerInfo:(NSDictionary *)info {
    NSString *serverType = [info objectForKey:@"type"] ?: [self type];
    BDSKMutableServerInfo *serverInfo = nil;
    NSString *serverName = [info valueForKey:@"name"];
    NSString *database = [info valueForKey:@"database"];
    NSString *host = [info valueForKey:@"host"];
    NSString *port = [info valueForKey:@"port"];
    
    if ([serverType isEqualToString:[self type]]) {
        serverInfo = [[self serverInfo] mutableCopy];
        
        NSString *value;
        NSNumber *number;
        
        if (serverName)
            [serverInfo setName:serverName];
        if (database)
            [serverInfo setDatabase:database];
        if ([serverType isEqualToString:BDSKSearchGroupZoom]) {
            if (host)
                [serverInfo setHost:host];
            if (port)
                [serverInfo setPort:port];
            if ((value = [info valueForKey:@"username"]))
                [serverInfo setUsername:value];
            if ((value = [info valueForKey:@"password"]))
                [serverInfo setPassword:value];
            if ((value = [info valueForKey:@"recordSyntax"]))
                [serverInfo setRecordSyntax:value];
            if ((value = [info valueForKey:@"resultEncoding"]))
                [serverInfo setResultEncoding:value];
            if ((number = [info valueForKey:@"removeDiacritics"]))
                [serverInfo setRemoveDiacritics:[number boolValue]];
        }
    } else {
        NSMutableDictionary *options = nil;
        
         if ([serverType isEqualToString:BDSKSearchGroupZoom]) {
            options = [NSMutableDictionary dictionary];
            [options setValue:[info valueForKey:@"username"] forKey:@"username"];
            [options setValue:[info valueForKey:@"password"] forKey:@"password"];
            [options setValue:[info valueForKey:@"resultEncoding"] forKey:@"resultEncoding"];
            [options setValue:[info valueForKey:@"removeDiacritics"] forKey:@"removeDiacritics"];
        }
        
        serverInfo = [[BDSKMutableServerInfo alloc] initWithType:serverType name:serverName database:database host:host port:port options:options];
    }
    
    BOOL isValid = YES;
    id value, validatedValue;
    
    if ([NSString isEmptyString:[serverInfo name]] || [NSString isEmptyString:[serverInfo database]])
        isValid = NO;
    else if ([serverInfo isZoom] && ([NSString isEmptyString:[serverInfo host]] || [[serverInfo port] integerValue] == 0))
        isValid = NO;
    for (NSString *key in info) {
        if (isValid == NO) break;
        value = validatedValue = [info valueForKey:key];
        if ((isValid = [serverInfo validateValue:&validatedValue forKey:key error:NULL]) && 
            [validatedValue isEqual:value] == NO)
            [serverInfo setValue:validatedValue forKey:key];
    }
    
    if (isValid) {
        [self setServerInfo:serverInfo];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Invalid server info.",@"Error description")];
    }
    [serverInfo release];
}

- (NSString *)scriptingServerName {
    return [[self serverInfo] name];
}

@end

#pragma mark -

@implementation BDSKSharedGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSUniqueIDSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"sharedGroups" uniqueID:[self uniqueID]] autorelease];
}

@end

#pragma mark -

@implementation BDSKWebGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSUniqueIDSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"webGroups" uniqueID:[self uniqueID]] autorelease];
}

- (NSString *)URLString {
    return [[self URL] absoluteString] ?: @"";
}

- (void)setURLString:(NSString *)newURLString {
    if (newURLString)
        [self setURL:[NSURL URLWithString:newURLString]];
}

@end

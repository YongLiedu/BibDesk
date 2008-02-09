//
//  BDSKGroup+Scripting.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/5/08.
/*
 This software is Copyright (c) 2008
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
#import "BibAuthor.h"
#import "BibAuthor+Scripting.h"
#import "NSObject_BDSKExtensions.h"


@implementation BDSKGroup (Scripting)

+ (BOOL)accessInstanceVariablesDirectly {
	return NO;
}

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
	unsigned idx = [[doc groups] indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"groups" index:idx] autorelease];
    } else {
        return nil;
    }
}

- (NSArray *)publicationsInGroup {
    if ([self respondsToSelector:@selector(publications)]) {
        return [(id)self publications];
    } else {
        NSEnumerator *pubEnum = [[document publications] objectEnumerator];
        BibItem *pub;
        NSMutableArray *filteredArray = [NSMutableArray array];
        
        while (pub = [pubEnum nextObject]) {
            if ([self containsItem:pub])
                [filteredArray addObject:pub];
        }
        
        return filteredArray;
    }
}

- (unsigned int)countOfPublications {
    return [[self publicationsInGroup] count];
}

- (BibItem *)objectInPublicationsAtIndex:(unsigned int)idx {
    return [[self publicationsInGroup] objectAtIndex:idx];
}

- (BibItem *)valueInPublicationsAtIndex:(unsigned int)idx {
    return [[self publicationsInGroup] objectAtIndex:idx];
}

- (NSArray *)authors {
    return [BibAuthor authorsInPublications:[self publicationsInGroup]];
}

- (BibAuthor *)valueInAuthorsWithName:(NSString *)aName {
    return [BibAuthor authorWithName:aName inPublications:[self publicationsInGroup]];
}

- (NSArray *)editors {
    return [BibAuthor editorsInPublications:[self publicationsInGroup]];
}

- (BibAuthor *)valueInEditorsWithName:(NSString *)aName {
    return [BibAuthor editorWithName:aName inPublications:[self publicationsInGroup]];
}

- (BDSKMacro *)valueInMacrosWithName:(NSString *)aName {
    return [[self document] valueInMacrosWithName:aName];
}

- (NSArray *)macros {
    return [[self document] macros];
}

- (NSString *)asName {
    return [self stringValue];
}

@end

#pragma mark -

@implementation BDSKLibraryGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"libraryGroups" index:0] autorelease];
}

- (NSArray *)publicationsInGroup {
    return [[self document] publications];
}

- (unsigned int)countOfPublications {
    return [[self document] countOfPublications];
}

- (BibItem *)valueInPublicationsAtIndex:(unsigned int)idx {
    return [[self document] valueInPublicationsAtIndex:idx];
}

- (BibItem *)objectInPublicationsAtIndex:(unsigned int)idx {
    return [[self document] objectInPublicationsAtIndex:idx];
}

- (void)insertInPublications:(BibItem *)pub atIndex:(unsigned int)idx {
    [[self document] insertInPublications:pub atIndex:idx];
}

- (void)insertInPublications:(BibItem *)pub {
    if ([pub owner] == nil)
        [[self document] insertInPublications:pub];
}

- (void)insertObject:(BibItem *)pub inPublicationsAtIndex:(unsigned int)idx {
    if ([pub owner] == nil)
        [[self document] insertObject:pub inPublicationsAtIndex:idx];
}

- (void)removeFromPublicationsAtIndex:(unsigned int)idx {
    [[self document] removeFromPublicationsAtIndex:idx];
}

- (void)removeObjectFromPublicationsAtIndex:(unsigned int)idx {
    [[self document] removeObjectFromPublicationsAtIndex:idx];
}

- (NSArray *)authors {
    return [[self document] authors];
}

- (BibAuthor *)valueInAuthorsWithName:(NSString *)aName {
    return [[self document] valueInAuthorsWithName:aName];
}

- (NSArray *)editors {
    return [[self document] editors];
}

- (BibAuthor *)valueInEditorsWithName:(NSString *)aName {
    return [[self document] valueInEditorsWithName:aName];
}

@end

#pragma mark -

@implementation BDSKMutableGroup (Scripting)

- (void)setAsName:(NSString *)newName {
    if ([self hasEditableName]) {
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
    NSArray *groups = [[doc groups] staticGroups];
	unsigned idx = [groups indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"staticGroups" index:idx] autorelease];
    } else {
        return nil;
    }
}

- (void)insertInPublications:(BibItem *)pub {
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

- (void)insertObject:(BibItem *)pub inPublicationsAtIndex:(unsigned int)idx {
    [self insertInPublications:pub];
}

- (void)insertInPublications:(BibItem *)pub  atIndex:(unsigned int)idx {
	[self insertInPublications:pub];
}

- (void)removeFromPublicationsAtIndex:(unsigned int)idx {
    [self removePublication:[publications objectAtIndex:idx]];
    [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (void)removeObjectFromPublicationsAtIndex:(unsigned int)idx {
	[self removeFromPublicationsAtIndex:idx];
}

@end

#pragma mark -

@implementation BDSKLastImportGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"lastImportGroups" index:0] autorelease];
}

- (void)setAsName:(NSString *)newName {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of last import group.",@"Error description")];
}

- (void)insertInPublications:(BibItem *)pub {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [cmd setScriptErrorString:NSLocalizedString(@"Cannot modify publications of last import group.",@"Error description")];
}

- (void)removeFromPublicationsAtIndex:(unsigned int)idx {
    NSScriptCommand *cmd = [NSScriptCommand currentCommand];
    [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [cmd setScriptErrorString:NSLocalizedString(@"Cannot modify publications of last import group.",@"Error description")];
}

@end

#pragma mark -

@implementation BDSKSmartGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSArray *groups = [[doc groups] smartGroups];
	unsigned idx = [groups indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"smartGroups" index:idx] autorelease];
    } else {
        return nil;
    }
}

@end

#pragma mark -

@implementation BDSKCategoryGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSArray *groups = [[doc groups] categoryGroups];
	unsigned idx = [groups indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"fieldGroups" index:idx] autorelease];
    } else {
        return nil;
    }
}

- (void)insertInPublications:(BibItem *)pub {
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

- (void)insertObject:(BibItem *)pub inPublicationsAtIndex:(unsigned int)idx {
    [self insertInPublications:pub];
}

- (void)insertInPublications:(BibItem *)pub  atIndex:(unsigned int)idx {
	[self insertInPublications:pub];
}

- (void)removeFromPublicationsAtIndex:(unsigned int)idx {
    [[self document] removePublications:[[self publicationsInGroup] subarrayWithRange:NSMakeRange(idx, 1)] fromGroups:[NSArray arrayWithObject:self]];
    [[[self document] undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (void)removeObjectFromPublicationsAtIndex:(unsigned int)idx {
	[self removeFromPublicationsAtIndex:idx];
}

@end

#pragma mark -

@implementation BDSKURLGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSArray *groups = [[doc groups] URLGroups];
	unsigned idx = [groups indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"externalFileGroups" index:idx] autorelease];
    } else {
        return nil;
    }
}

- (BDSKMacro *)valueInMacrosWithName:(NSString *)aName {
    return [[self macroResolver] valueInMacrosWithName:aName];
}

- (NSArray *)macros {
    return [[self macroResolver] macros];
}

- (NSString *)URLString {
    return [[self URL] absoluteString];
}

- (void)setURLString:(NSString *)newURLString {
    [self setURL:[NSURL URLWithString:newURLString]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (NSURL *)fileURL {
    NSURL *fileURL = [self URL];
    return [fileURL isFileURL] ? fileURL : (id)[NSNull null];
}

- (void)setFileURL:(NSURL *)newURL {
    [self setURL:newURL];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

@end

#pragma mark -

@implementation BDSKScriptGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSArray *groups = [[doc groups] scriptGroups];
	unsigned idx = [groups indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"scriptGroups" index:idx] autorelease];
    } else {
        return nil;
    }
}

- (BDSKMacro *)valueInMacrosWithName:(NSString *)aName {
    return [[self macroResolver] valueInMacrosWithName:aName];
}

- (NSArray *)macros {
    return [[self macroResolver] macros];
}

- (NSURL *)scriptURL {
    return [NSURL fileURLWithPath:[self scriptPath]];
}

- (void)setScriptURL:(NSURL *)newScriptURL {
    [self setScriptPath:[newScriptURL path]];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

- (NSString *)asScriptArguments {
    NSString *arguments = [self scriptArguments];
    return arguments ? arguments : @"";
}

- (void)setAsScriptArguments:(NSString *)newArguments {
    [self setScriptArguments:newArguments];
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
}

@end

#pragma mark -

@implementation BDSKSearchGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSArray *groups = [[doc groups] searchGroups];
	unsigned idx = [groups indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"searchGroups" index:idx] autorelease];
    } else {
        return nil;
    }
}

- (BDSKMacro *)valueInMacrosWithName:(NSString *)aName {
    return [[self macroResolver] valueInMacrosWithName:aName];
}

- (NSArray *)macros {
    return [[self macroResolver] macros];
}

@end

#pragma mark -

@implementation BDSKSharedGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSArray *groups = [[doc groups] sharedGroups];
	unsigned idx = [groups indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"sharedGroups" index:idx] autorelease];
    } else {
        return nil;
    }
}

- (BDSKMacro *)valueInMacrosWithName:(NSString *)aName {
    return [[self macroResolver] valueInMacrosWithName:aName];
}

- (NSArray *)macros {
    return [[self macroResolver] macros];
}

@end

#pragma mark -

@implementation BDSKWebGroup (Scripting)

- (NSScriptObjectSpecifier *)objectSpecifier {
    BibDocument *doc = (BibDocument *)[self document];
    NSScriptObjectSpecifier *containerRef = [doc objectSpecifier];
    return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"webGroups" index:0] autorelease];
}

- (BDSKMacro *)valueInMacrosWithName:(NSString *)aName {
    return [[self macroResolver] valueInMacrosWithName:aName];
}

- (NSArray *)macros {
    return [[self macroResolver] macros];
}

@end

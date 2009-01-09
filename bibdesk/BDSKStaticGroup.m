//
//  BDSKStaticGroup.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/21/06.
/*
 This software is Copyright (c) 2005-2009
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

#import "BDSKStaticGroup.h"
#import "NSImage_BDSKExtensions.h"
#import "BibItem.h"
#import <OmniBase/OmniBase.h>


@implementation BDSKStaticGroup

static NSString *BDSKLastImportLocalizedString = nil;

+ (void)initialize{
    OBINITIALIZE;
    BDSKLastImportLocalizedString = [NSLocalizedString(@"Last Import", @"Group name for last import") copy];
}

- (id)initWithLastImport:(NSArray *)array {
	NSZone *zone = [self zone];
	[[super init] release];
	self = [[BDSKLastImportGroup allocWithZone:zone] initWithName:BDSKLastImportLocalizedString publications:array];
	return self;
}

// designated initializer
- (id)initWithName:(id)aName publications:(NSArray *)array {
    if (self = [super initWithName:aName count:[array count]]) {
        publications = [array mutableCopy];
    }
    return self;
}

// super's designated initializer
- (id)initWithName:(id)aName count:(int)aCount {
    self = [self initWithName:aName publications:[NSArray array]];
    return self;
}

- (id)initWithDictionary:(NSDictionary *)groupDict {
    NSString *aName = [[groupDict objectForKey:@"group name"] stringByUnescapingGroupPlistEntities];
    self = [self initWithName:aName count:0];
    return self;
}

- (NSDictionary *)dictionaryValue {
    NSString *aName = [[self stringValue] stringByEscapingGroupPlistEntities];
	NSString *keys = [[[self publications] valueForKeyPath:@"@distinctUnionOfObjects.citeKey"] componentsJoinedByString:@","];
    return [NSDictionary dictionaryWithObjectsAndKeys:aName, @"group name", keys, @"keys", nil];
}

- (void)dealloc {
	[[self undoManager] removeAllActionsWithTarget:self];
    [publications release];
    [super dealloc];
}

- (NSImage *)icon {
	return [NSImage imageNamed:@"staticFolderIcon"];
}

- (BOOL)isStatic { return YES; }

- (BOOL)isValidDropTarget { return YES; }

- (NSArray *)publications {
    return publications;
}

- (void)setPublications:(NSArray *)newPublications {
    if (newPublications != publications) {
		[[[self undoManager] prepareWithInvocationTarget:self] setPublications:publications];
        [publications release];
        publications = [newPublications mutableCopy];
        [self setCount:[publications count]];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKStaticGroupChangedNotification object:self];
    }
}

- (void)addPublication:(BibItem *)item {
    [self addPublicationsFromArray:[NSArray arrayWithObjects:item, nil]];
}

- (void)addPublicationsFromArray:(NSArray *)items {
    if ([publications firstObjectCommonWithArray:items]) {
        NSMutableArray *mutableItems = [items mutableCopy];
        [mutableItems removeObjectsInArray:publications];
        items = [mutableItems autorelease];
        if ([items count] == 0)
            return;
    }
    [[[self undoManager] prepareWithInvocationTarget:self] removePublicationsInArray:items];
    [publications addObjectsFromArray:items];
    [self setCount:[publications count]];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKStaticGroupChangedNotification object:self];
}

- (void)removePublication:(BibItem *)item {
    [self removePublicationsInArray:[NSArray arrayWithObjects:item, nil]];
}

- (void)removePublicationsInArray:(NSArray *)items {
    NSMutableArray *removedItems = [NSMutableArray array];
    NSEnumerator *itemEnum = [items objectEnumerator];
    BibItem *item;
    while (item = [itemEnum nextObject]) {
        if ([publications containsObject:item] == NO) continue;
        [removedItems addObject:item];
        [publications removeObject:item];
    }
    [[[self undoManager] prepareWithInvocationTarget:self] addPublicationsFromArray:removedItems];
    [self setCount:[publications count]];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKStaticGroupChangedNotification object:self];
}

- (BOOL)containsItem:(BibItem *)item {
	return [publications containsObject:item];
}

@end

#pragma mark -

@implementation BDSKLastImportGroup

- (NSImage *)icon {
	return [NSImage imageNamed:@"importFolderIcon"];
}

- (void)setName:(NSString *)newName {}

- (BOOL)hasEditableName { return NO; }

- (BOOL)isEditable { return NO; }

- (BOOL)isValidDropTarget { return NO; }

- (BOOL)isEqual:(id)other { return other == self; }

- (unsigned int)hash {
    return( ((unsigned int) self >> 4) | (unsigned int) self << (32 - 4));
}

@end

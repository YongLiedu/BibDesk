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
#import "BibDocument.h"
#import "BDSKOwnerProtocol.h"
#import "BDSKPublicationsArray.h"


@implementation BDSKStaticGroup

static NSString *BDSKLastImportLocalizedString = nil;

+ (void)initialize{
    BDSKINITIALIZE;
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
    if (self = [super initWithName:aName]) {
        publications = [[NSMutableArray alloc] initWithArray:array];
        [self setCount:[array count]];
    }
    return self;
}

// super's designated initializer
- (id)initWithName:(id)aName {
    self = [self initWithName:aName publications:nil];
    return self;
}

- (id)initWithDictionary:(NSDictionary *)groupDict {
    NSString *aName = [[groupDict objectForKey:@"group name"] stringByUnescapingGroupPlistEntities];
    NSArray *keys = [[groupDict objectForKey:@"keys"] componentsSeparatedByString:@","];
    if (self = [self initWithName:aName publications:nil]) {
        tmpKeys = [keys retain];
    }
    return self;
}

- (NSDictionary *)dictionaryValue {
    NSString *aName = [[self stringValue] stringByEscapingGroupPlistEntities];
	NSString *keys = [(tmpKeys ?: [[self publications] valueForKeyPath:@"@distinctUnionOfObjects.citeKey"]) componentsJoinedByString:@","];
    return [NSDictionary dictionaryWithObjectsAndKeys:aName, @"group name", keys, @"keys", nil];
}

- (id)copyWithZone:(NSZone *)aZone {
	return [[[self class] allocWithZone:aZone] initWithName:name publications:publications];
}

- (void)dealloc {
	[[self undoManager] removeAllActionsWithTarget:self];
    [publications release];
    [tmpKeys release];
    [super dealloc];
}

- (NSImage *)icon {
	return [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)];
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
    for (BibItem *item in items) {
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

- (void)update {
    if (tmpKeys) {
        for (NSString *key in tmpKeys) 
            [publications addObjectsFromArray:[[document publications] allItemsForCiteKey:key]];
        [self setCount:[publications count]];
        [tmpKeys release];
        tmpKeys = nil;
    }
}

@end

#pragma mark -

@implementation BDSKLastImportGroup

- (NSImage *)icon {
	static NSImage *importGroupImage = nil;
    if (importGroupImage == nil) {
        importGroupImage = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
        [importGroupImage lockFocus];
        [[NSImage imageNamed:NSImageNameFolderSmart] drawInRect:NSMakeRect(0.0, 0.0, 32.0, 32.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [[NSImage imageNamed:@"importBadge"] drawInRect:NSMakeRect(0.0, 0.0, 32.0, 32.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [importGroupImage unlockFocus];
        NSImage *tinyImage = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
        [tinyImage lockFocus];
        [[NSImage imageNamed:NSImageNameFolderSmart] drawInRect:NSMakeRect(0.0, 0.0, 16.0, 16.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [[NSImage imageNamed:@"importBadge"] drawInRect:NSMakeRect(0.0, 0.0, 16.0, 16.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [tinyImage unlockFocus];
        [importGroupImage addRepresentation:[[tinyImage representations] lastObject]];
        [tinyImage release];
    }
    return importGroupImage;
}

- (void)setName:(NSString *)newName {}

- (BOOL)isNameEditable { return NO; }

- (BOOL)isEditable { return NO; }

- (BOOL)isStatic { return NO; }

- (BOOL)isValidDropTarget { return NO; }

- (BOOL)isEqual:(id)other { return other == self; }

- (NSUInteger)hash {
    return BDSKHash(self);
}

@end

//
//  BDSKSearchBookmark.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/25/08.
/*
 This software is Copyright (c) 2008-2010
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

#import "BDSKSearchBookmark.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKRuntime.h"

#define BOOKMARK_STRING     @"bookmark"
#define FOLDER_STRING       @"folder"
#define SEPARATOR_STRING    @"separator"

#define CHILDREN_KEY        @"children"
#define LABEL_KEY           @"label"
#define BOOKMARK_TYPE_KEY   @"bookmarkType"


@interface BDSKPlaceholderSearchBookmark : BDSKSearchBookmark
@end

@interface BDSKServerSearchBookmark : BDSKSearchBookmark {
    NSString *label;
    NSDictionary *info;
}
@end

@interface BDSKFolderSearchBookmark : BDSKSearchBookmark {
    NSString *label;
    NSMutableArray *children;
}
@end

@interface BDSKRootSearchBookmark : BDSKFolderSearchBookmark
@end

@interface BDSKSeparatorSearchBookmark : BDSKSearchBookmark
@end

#pragma mark -

@implementation BDSKSearchBookmark

static BDSKPlaceholderSearchBookmark *defaultPlaceholderSearchBookmark = nil;
static Class BDSKSearchBookmarkClass = Nil;

+ (void)initialize {
    BDSKINITIALIZE;
    BDSKSearchBookmarkClass = self;
    defaultPlaceholderSearchBookmark = (BDSKPlaceholderSearchBookmark *)NSAllocateObject([BDSKPlaceholderSearchBookmark class], 0, NSDefaultMallocZone());
}

+ (id)allocWithZone:(NSZone *)aZone {
    return BDSKSearchBookmarkClass == self ? defaultPlaceholderSearchBookmark : [super allocWithZone:aZone];
}

+ (id)searchBookmarkFolderWithChildren:(NSArray *)aChildren label:(NSString *)aLabel {
    return [[[self alloc] initFolderWithChildren:aChildren label:aLabel] autorelease];
}

+ (id)searchBookmarkFolderWithLabel:(NSString *)aLabel {
    return [[[self alloc] initFolderWithLabel:aLabel] autorelease];
}

+ (id)searchBookmarkSeparator {
    return [[[self alloc] initSeparator] autorelease];
}

+ (id)searchBookmarkWithInfo:(NSDictionary *)aDictionary label:(NSString *)aLabel {
    return [[[self alloc] initWithInfo:aDictionary label:aLabel] autorelease];
}

+ (id)searchBookmarkWithDictionary:(NSDictionary *)dictionary {
    return [[[self alloc] initWithDictionary:dictionary] autorelease];
}

- (id)initFolderWithChildren:(NSArray *)aChildren label:(NSString *)aLabel {
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (id)initFolderWithLabel:(NSString *)aLabel {
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (id)initRootWithChildren:(NSArray *)aChildren {
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (id)initSeparator {
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (id)initWithInfo:(NSDictionary *)aDictionary label:(NSString *)aLabel {
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (void)dealloc {
    parent = nil;
    [super dealloc];
}

- (NSDictionary *)dictionaryValue { return nil; }

- (BDSKSearchBookmarkType)bookmarkType { return 0; }

- (NSString *)label { return nil; }
- (void)setLabel:(NSString *)newLabel {}

- (NSImage *)icon { return nil; }

- (NSDictionary *)info { return nil; }

- (NSArray *)children { return nil; }
- (NSUInteger)countOfChildren { return 0; }
- (BDSKSearchBookmark *)objectInChildrenAtIndex:(NSUInteger)idx { return nil; }
- (void)insertObject:(BDSKSearchBookmark *)child inChildrenAtIndex:(NSUInteger)idx {}
- (void)removeObjectFromChildrenAtIndex:(NSUInteger)idx {}

- (BDSKSearchBookmark *)parent {
    return parent;
}

- (void)setParent:(BDSKSearchBookmark *)newParent {
    parent = newParent;
}

- (BOOL)isDescendantOf:(BDSKSearchBookmark *)bookmark {
    if (self == bookmark)
        return YES;
    for (BDSKSearchBookmark *child in [bookmark children]) {
        if ([self isDescendantOf:child])
            return YES;
    }
    return NO;
}

- (BOOL)isDescendantOfArray:(NSArray *)bookmarks {
    for (BDSKSearchBookmark *bm in bookmarks) {
        if ([self isDescendantOf:bm]) return YES;
    }
    return NO;
}

@end

#pragma mark -

@implementation BDSKPlaceholderSearchBookmark

- (id)init {
    return nil;
}

- (id)initFolderWithChildren:(NSArray *)aChildren label:(NSString *)aLabel {
    return [[BDSKFolderSearchBookmark alloc] initFolderWithChildren:aChildren label:aLabel];
}

- (id)initFolderWithLabel:(NSString *)aLabel {
    return [self initFolderWithChildren:[NSArray array] label:aLabel];
}

- (id)initRootWithChildren:(NSArray *)aChildren {
    return [[BDSKRootSearchBookmark alloc] initFolderWithChildren:aChildren label:NSLocalizedString(@"Searches Menu", @"Menu item title")];
}

- (id)initSeparator {
    return [[BDSKSeparatorSearchBookmark alloc] init];
}

- (id)initWithInfo:(NSDictionary *)aDictionary label:(NSString *)aLabel {
    return [[BDSKServerSearchBookmark alloc] initWithInfo:aDictionary label:aLabel];
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if ([[dictionary objectForKey:BOOKMARK_TYPE_KEY] isEqualToString:FOLDER_STRING]) {
        NSMutableArray *newChildren = [NSMutableArray array];
        for (NSDictionary *dict in [dictionary objectForKey:CHILDREN_KEY])
            [newChildren addObject:[[[[self class] alloc] initWithDictionary:dict] autorelease]];
        return [self initFolderWithChildren:newChildren label:[dictionary objectForKey:LABEL_KEY]];
    } else if ([[dictionary objectForKey:BOOKMARK_TYPE_KEY] isEqualToString:SEPARATOR_STRING]) {
        return [self initSeparator];
    } else {
        NSMutableDictionary *dict = [[dictionary mutableCopy] autorelease];
        [dict removeObjectForKey:BOOKMARK_TYPE_KEY];
        [dict removeObjectForKey:LABEL_KEY];
        return [self initWithInfo:dict label:[dictionary objectForKey:LABEL_KEY]];
    }
}

- (id)retain { return self; }

- (id)autorelease { return self; }

- (void)release {}

- (NSUInteger)retainCount { return NSUIntegerMax; }

@end

#pragma mark -

@implementation BDSKServerSearchBookmark

- (id)initWithInfo:(NSDictionary *)aDictionary label:(NSString *)aLabel {
    if (self = [super init]) {
        info = [aDictionary copy];
        label = [aLabel copy];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(info);
    BDSKDESTROY(label);
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: label=%@, info=%@>", [self class], label, info];
}

- (NSDictionary *)dictionaryValue {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:BOOKMARK_STRING, BOOKMARK_TYPE_KEY, label, LABEL_KEY, nil];
    [(NSMutableDictionary *)dictionary addEntriesFromDictionary:info];
    return dictionary;
}

- (BDSKSearchBookmarkType)bookmarkType {
    return BDSKSearchBookmarkTypeBookmark;
}

- (NSDictionary *)info {
    return info;
}

- (NSString *)label {
    return label;
}

- (void)setLabel:(NSString *)newLabel {
    if (label != newLabel) {
        [label release];
        label = [newLabel retain];
    }
}

- (NSImage *)icon {
    static NSImage *icon = nil;
    if (icon == nil) {
        icon = [[NSImage imageNamed:@"searchGroup"] copy];
        NSImage *tinyIcon = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
        [tinyIcon lockFocus];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [icon drawInRect:NSMakeRect(0.0, 0.0, 16.0, 16.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
        [tinyIcon unlockFocus];
        [icon addRepresentation:[[tinyIcon representations] lastObject]];
        [tinyIcon release];
    }
    return icon;
}

@end

#pragma mark -

@implementation BDSKFolderSearchBookmark

- (id)initFolderWithChildren:(NSArray *)aChildren label:(NSString *)aLabel {
    if (self = [super init]) {
        label = [aLabel copy];
        children = [aChildren mutableCopy];
        [children setValue:self forKey:@"parent"];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(label);
    BDSKDESTROY(children);
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: label=%@, children=%@>", [self class], label, children];
}

- (NSDictionary *)dictionaryValue {
    return [NSDictionary dictionaryWithObjectsAndKeys:FOLDER_STRING, BOOKMARK_TYPE_KEY, [children valueForKey:@"dictionaryValue"], CHILDREN_KEY, label, LABEL_KEY, nil];
}

- (BDSKSearchBookmarkType)bookmarkType {
    return BDSKSearchBookmarkTypeFolder;
}

- (NSString *)label {
    return label;
}

- (void)setLabel:(NSString *)newLabel {
    if (label != newLabel) {
        [label release];
        label = [newLabel retain];
    }
}

- (NSImage *)icon {
    return [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)];
}

- (NSArray *)children {
    return [[children copy] autorelease];
}

- (NSUInteger)countOfChildren {
    return [children count];
}

- (BDSKSearchBookmark *)objectInChildrenAtIndex:(NSUInteger)idx {
    return [children objectAtIndex:idx];
}

- (void)insertObject:(BDSKSearchBookmark *)child inChildrenAtIndex:(NSUInteger)idx {
    [children insertObject:child atIndex:idx];
    [child setParent:self];
}

- (void)removeObjectFromChildrenAtIndex:(NSUInteger)idx {
    [[children objectAtIndex:idx] setParent:nil];
    [children removeObjectAtIndex:idx];
}

@end

#pragma mark -

@implementation BDSKRootSearchBookmark

- (NSImage *)icon {
    return [NSImage menuIcon];
}

@end

#pragma mark -

@implementation BDSKSeparatorSearchBookmark

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: separator>", [self class]];
}

- (NSDictionary *)dictionaryValue {
    return [NSDictionary dictionaryWithObjectsAndKeys:SEPARATOR_STRING, BOOKMARK_TYPE_KEY, nil];
}

- (BDSKSearchBookmarkType)bookmarkType {
    return BDSKSearchBookmarkTypeSeparator;
}

@end

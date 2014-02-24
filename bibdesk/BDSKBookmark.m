//
//  BDSKBookmark.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/25/08.
/*
 This software is Copyright (c) 2008-2014
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

#import "BDSKBookmark.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKRuntime.h"

#define CHILDREN_KEY    @"Children"
#define TITLE_KEY       @"Title"
#define URLSTRING_KEY   @"URLString"
#define TYPE_KEY        @"Type"

#define BOOKMARK_STRING  @"bookmark"
#define FOLDER_STRING    @"folder"
#define SEPARATOR_STRING @"separator"


@interface BDSKPlaceholderBookmark : BDSKBookmark
@end

@interface BDSKURLBookmark : BDSKBookmark {
    NSString *name;
    NSURL *url;
}
@end

@interface BDSKFolderBookmark : BDSKBookmark {
    NSString *name;
    NSMutableArray *children;
}
@end

@interface BDSKRootBookmark : BDSKFolderBookmark
@end

@interface BDSKSeparatorBookmark : BDSKBookmark
@end

#pragma mark -

@implementation BDSKBookmark

static BDSKPlaceholderBookmark *defaultPlaceholderBookmark = nil;
static Class BDSKBookmarkClass = Nil;

+ (void)initialize {
    BDSKINITIALIZE;
    BDSKBookmarkClass = self;
    defaultPlaceholderBookmark = (BDSKPlaceholderBookmark *)NSAllocateObject([BDSKPlaceholderBookmark class], 0, NSDefaultMallocZone());
}

+ (id)allocWithZone:(NSZone *)aZone {
    return BDSKBookmarkClass == self ? defaultPlaceholderBookmark : [super allocWithZone:aZone];
}

+ (id)bookmarkWithURL:(NSURL *)aURL name:(NSString *)aName {
    return [[[self alloc] initWithURL:aURL name:aName] autorelease];
}

+ (id)bookmarkFolderWithName:(NSString *)aName {
    return [[[self alloc] initFolderWithName:aName] autorelease];
}

+ (id)bookmarkSeparator {
    return [[[self alloc] initSeparator] autorelease];
}

- (id)initWithURL:(NSURL *)aURL name:(NSString *)aName {
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (id)initFolderWithChildren:(NSArray *)aChildren name:(NSString *)aName {
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (id)initFolderWithName:(NSString *)aName {
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

- (id)initWithDictionary:(NSDictionary *)dictionary {
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}

- (void)dealloc {
    parent = nil;
    [super dealloc];
}

- (NSDictionary *)dictionaryValue { return nil; }

- (BDSKBookmarkType)bookmarkType { return 0; }

- (NSString *)name { return nil; }
- (void)setName:(NSString *)newName {}

- (NSImage *)icon { return nil; }

- (NSURL *)URL { return nil; }
- (void)setURL:(NSURL *)newURL {}

- (NSArray *)children { return nil; }
- (NSUInteger)countOfChildren { return 0; }
- (BDSKBookmark *)objectInChildrenAtIndex:(NSUInteger)idx { return nil; }
- (void)insertObject:(BDSKBookmark *)child inChildrenAtIndex:(NSUInteger)idx {}
- (void)removeObjectFromChildrenAtIndex:(NSUInteger)idx {}

- (BDSKBookmark *)parent {
    return parent;
}

- (void)setParent:(BDSKBookmark *)newParent {
    parent = newParent;
}

- (BOOL)isDescendantOf:(BDSKBookmark *)bookmark {
    if (self == bookmark)
        return YES;
    for (BDSKBookmark *child in [bookmark children]) {
        if ([self isDescendantOf:child])
            return YES;
    }
    return NO;
}

- (BOOL)isDescendantOfArray:(NSArray *)bookmarks {
    for (BDSKBookmark *bm in bookmarks) {
        if ([self isDescendantOf:bm]) return YES;
    }
    return NO;
}

@end

#pragma mark -

@implementation BDSKPlaceholderBookmark

- (id)init {
    return [self initWithURL:[NSURL URLWithString:@"http://"] name:nil];
}

- (id)initWithURL:(NSURL *)aURL name:(NSString *)aName {
    return (id)[[BDSKURLBookmark alloc] initWithURL:aURL name:aName ?: NSLocalizedString(@"New Boookmark", @"Default name for boookmark")];
}

- (id)initFolderWithChildren:(NSArray *)aChildren name:(NSString *)aName {
    return (id)[[BDSKFolderBookmark alloc] initFolderWithChildren:aChildren name:aName];
}

- (id)initFolderWithName:(NSString *)aName {
    return [self initFolderWithChildren:[NSArray array] name:aName];
}

- (id)initSeparator {
    return (id)[[BDSKSeparatorBookmark alloc] init];
}

- (id)initRootWithChildren:(NSArray *)aChildren {
    return (id)[[BDSKRootBookmark alloc] initFolderWithChildren:aChildren name:NSLocalizedString(@"Bookmarks Menu", @"Menu item title")];
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if ([[dictionary objectForKey:TYPE_KEY] isEqualToString:FOLDER_STRING]) {
        NSMutableArray *newChildren = [NSMutableArray array];
        BDSKBookmark *child;
        for (NSDictionary *dict in [dictionary objectForKey:CHILDREN_KEY]) {
            if ((child = [[BDSKBookmark alloc] initWithDictionary:dict])) {
                [newChildren addObject:child];
                [child release];
            } else
                NSLog(@"Failed to read child bookmark: %@", dict);
        }
        return [self initFolderWithChildren:newChildren name:[dictionary objectForKey:TITLE_KEY]];
    } else if ([[dictionary objectForKey:TYPE_KEY] isEqualToString:SEPARATOR_STRING]) {
        return [self initSeparator];
    } else {
        return [self initWithURL:[NSURL URLWithString:[dictionary objectForKey:URLSTRING_KEY]] name:[dictionary objectForKey:TITLE_KEY]];
    }
}

- (id)retain { return self; }

- (id)autorelease { return self; }

- (oneway void)release {}

- (NSUInteger)retainCount { return NSUIntegerMax; }

@end

#pragma mark -

@implementation BDSKURLBookmark

- (id)initWithURL:(NSURL *)aURL name:(NSString *)aName {
    self = [super init];
    if (self) {
        url = [aURL copy];
        name = [aName copy];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(name);
    BDSKDESTROY(url);
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: name=%@, URL=%@>", [self class], name, url];
}

- (NSDictionary *)dictionaryValue {
    return [NSDictionary dictionaryWithObjectsAndKeys:BOOKMARK_STRING, TYPE_KEY, [url absoluteString], URLSTRING_KEY, name, TITLE_KEY, nil];
}

- (BDSKBookmarkType)bookmarkType {
    return BDSKBookmarkTypeBookmark;
}

- (NSString *)name {
    return [[name retain] autorelease];
}

- (void)setName:(NSString *)newName {
    if (name != newName) {
        [name release];
        name = [newName retain];
    }
}

- (NSURL *)URL {
    return url;
}

- (void)setURL:(NSURL *)newURL {
    if (url != newURL) {
        [url release];
        url = [newURL retain];
    }
}

- (NSImage *)icon {
    static NSImage *icon = nil;
    if (icon == nil) {
        icon = [[NSImage imageNamed:@"Bookmark"] copy];
        NSImage *tinyIcon = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
        [tinyIcon lockFocus];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [icon drawInRect:NSMakeRect(0.0, 0.0, 16.0, 16.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationDefault];
        [tinyIcon unlockFocus];
        [icon addRepresentation:[[tinyIcon representations] lastObject]];
        [tinyIcon release];
    }
    return icon;
}

@end

#pragma mark -

@implementation BDSKFolderBookmark

- (id)initFolderWithChildren:(NSArray *)aChildren name:(NSString *)aName {
    self = [super init];
    if (self) {
        name = [aName copy];
        children = [aChildren mutableCopy];
        [children setValue:self forKey:@"parent"];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(name);
    BDSKDESTROY(children);
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: name=%@, children=%@>", [self class], name, children];
}

- (NSDictionary *)dictionaryValue {
    return [NSDictionary dictionaryWithObjectsAndKeys:FOLDER_STRING, TYPE_KEY, [children valueForKey:@"dictionaryValue"], CHILDREN_KEY, name, TITLE_KEY, nil];
}

- (BDSKBookmarkType)bookmarkType {
    return BDSKBookmarkTypeFolder;
}

- (NSImage *)icon {
    return [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)];
}

- (NSString *)name {
    return [[name retain] autorelease];
}

- (void)setName:(NSString *)newName {
    if (name != newName) {
        [name release];
        name = [newName retain];
    }
}

- (NSArray *)children {
    return [[children copy] autorelease];
}

- (NSUInteger)countOfChildren {
    return [children count];
}

- (BDSKBookmark *)objectInChildrenAtIndex:(NSUInteger)idx {
    return [children objectAtIndex:idx];
}

- (void)insertObject:(BDSKBookmark *)child inChildrenAtIndex:(NSUInteger)idx {
    [children insertObject:child atIndex:idx];
    [child setParent:self];
}

- (void)removeObjectFromChildrenAtIndex:(NSUInteger)idx {
    [[children objectAtIndex:idx] setParent:nil];
    [children removeObjectAtIndex:idx];
}

@end

#pragma mark -

@implementation BDSKRootBookmark

- (NSImage *)icon {
    return [NSImage menuIcon];
}

@end

#pragma mark -

@implementation BDSKSeparatorBookmark

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: separator>", [self class]];
}

- (NSDictionary *)dictionaryValue {
    return [NSDictionary dictionaryWithObjectsAndKeys:SEPARATOR_STRING, TYPE_KEY, nil];
}

- (BDSKBookmarkType)bookmarkType {
    return BDSKBookmarkTypeSeparator;
}

@end

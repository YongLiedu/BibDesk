//
//  BDSKParentGroup.m
//  Bibdesk
//
//  Created by Adam Maxwell on 4/9/09.
/*
 This software is Copyright (c) 2009
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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

#import "BDSKParentGroup.h"
#import "BDSKSharedGroup.h"
#import "BDSKURLGroup.h"
#import "BDSKScriptGroup.h"
#import "BDSKSearchGroup.h"
#import "BDSKSmartGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKCategoryGroup.h"
#import "BDSKWebGroup.h"
#import "BibDocument.h"
#import "BibAuthor.h"


@implementation BDSKParentGroup

- (id)initWithName:(NSString *)aName {
    if (self = [super initWithName:aName]) {
        children = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    BDSKASSERT_NOT_REACHED("Parent groups should never be decoded");
    if (self = [super initWithCoder:decoder]) {
        children = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    BDSKASSERT_NOT_REACHED("Parent groups should never be encoded");
    [super encodeWithCoder:coder];
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKASSERT_NOT_REACHED("Parent groups should never be copied");
	return [[[self class] allocWithZone:aZone] initWithName:name];
}

- (NSUInteger)hash { return BDSKHash(self); }

- (BOOL)isEqual:(id)other { return self == other; }

- (void)dealloc {
    [children makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
    [children makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
    [children release];
    [sortDescriptors release];
    [super dealloc];
}

- (BOOL)isParent { return YES; }

- (id)cellValue { return [self name]; }

- (NSArray *)children {
    return children;
}

- (NSArray *)childrenInRange:(NSRange)range {
    return [children subarrayWithRange:range];
}

- (NSUInteger)numberOfChildren { return [children count]; }

- (void)resort {
    if (sortDescriptors)
        [children sortUsingDescriptors:sortDescriptors];
}

- (id)childAtIndex:(NSUInteger)anIndex {
    NSParameterAssert(nil != children);
    return [children objectAtIndex:anIndex];
}

- (void)insertChild:(id)child atIndex:(NSUInteger)anIndex {
    [children insertObject:child atIndex:anIndex];
    [child setParent:self];
    [child setDocument:[self document]];
    [self resort];
}

- (void)removeChild:(id)child {
    // -[NSMutableArray removeObject:] removes all occurrences, which is not what we want here
    NSUInteger idx = [children indexOfObjectIdenticalTo:child];
    if (NSNotFound != idx) {
        [child setParent:nil];
        [child setDocument:nil];
        [children removeObjectAtIndex:idx];
    }
}

- (void)replaceChildrenInRange:(NSRange)range withChildren:(NSArray *)newChildren {
    if (NSEqualRanges(range, NSMakeRange(0, [self numberOfChildren]))) {
        [children makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
        [children makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
        [children setArray:newChildren];
    } else {
        [[children subarrayWithRange:range] makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
        [[children subarrayWithRange:range] makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
        [children replaceObjectsInRange:range withObjectsFromArray:newChildren];
    }
    [children makeObjectsPerformSelector:@selector(setParent:) withObject:self];
    [children makeObjectsPerformSelector:@selector(setDocument:) withObject:[self document]];
    if ([newChildren count])
        [self resort];
}

- (void)removeAllChildren {
    [children makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
    [children makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
    [children removeAllObjects];
}

- (BOOL)containsChild:(id)group {
    return NSNotFound != [children indexOfObjectIdenticalTo:group];
}

- (void)sortUsingDescriptors:(NSArray *)newSortDescriptors {
    if (sortDescriptors != newSortDescriptors) {
        [sortDescriptors release];
        sortDescriptors = [newSortDescriptors copy];
    }
    [self resort];
}

- (void)setDocument:(BibDocument *)newDocument {
    [super setDocument:newDocument];
    [children makeObjectsPerformSelector:@selector(setDocument:) withObject:newDocument];
}

- (void)removeAllUndoableChildren {
    [self removeAllChildren];
}

@end

#pragma mark -

@implementation BDSKLibraryParentGroup

- (id)init {
    // all-encompassing, non-expandable name
    self = [self initWithName:NSLocalizedString(@"GROUPS", @"source list group row title")];
    if (self) {
        BDSKGroup *libraryGroup = [[BDSKLibraryGroup alloc] init];
        [self insertChild:libraryGroup atIndex:0];
        [libraryGroup release];
    }
    return self;
}    

- (BOOL)isLibraryParent { return YES; }

// do nothing; this group has a fixed order
- (void)sortUsingDescriptors:(NSArray *)descriptors {}

// do nothing
- (void)removeAllUndoableChildren {}

@end

#pragma mark -

@implementation BDSKExternalParentGroup

- (id)init {
    self = [self initWithName:NSLocalizedString(@"EXTERNAL", @"source list group row title")];
    if (self) {
        webGroupCount = 1;
        sharedGroupCount = 0;
        URLGroupCount = 0;
        scriptGroupCount = 0;
        searchGroupCount = 0;
        BDSKWebGroup *webGroup = [[BDSKWebGroup alloc] initWithName:NSLocalizedString(@"Web", @"")];
        [self insertChild:webGroup atIndex:0];
        [webGroup release];
    }
    return self;
}

- (BDSKWebGroup *)webGroup {
    return [self childAtIndex:0];
}

- (NSArray *)searchGroups {
    return [self childrenInRange:NSMakeRange(webGroupCount, searchGroupCount)];
}

- (NSArray *)sharedGroups {
    return [self childrenInRange:NSMakeRange(webGroupCount + searchGroupCount, sharedGroupCount)];
}

- (NSArray *)URLGroups {
    return [self childrenInRange:NSMakeRange((webGroupCount + searchGroupCount + sharedGroupCount), URLGroupCount)];
}

- (NSArray *)scriptGroups {
    return [self childrenInRange:NSMakeRange((webGroupCount + searchGroupCount + sharedGroupCount + URLGroupCount), scriptGroupCount)];
}

- (void)addSearchGroup:(BDSKSearchGroup *)group {
    NSUInteger idx = webGroupCount;
    searchGroupCount += 1;    
    [self insertChild:group atIndex:idx];
}

- (void)removeSearchGroup:(BDSKSearchGroup *)group {
    NSParameterAssert(searchGroupCount);
    searchGroupCount -= 1;    
    [self removeChild:group];
}

- (void)setSharedGroups:(NSArray *)array {
    NSRange range = NSMakeRange(webGroupCount + searchGroupCount, sharedGroupCount);
    sharedGroupCount = [array count];
    [self replaceChildrenInRange:range withChildren:array];
}

- (void)addURLGroup:(BDSKURLGroup *)group {
    NSUInteger idx = webGroupCount + searchGroupCount + sharedGroupCount;
    URLGroupCount += 1;
    [self insertChild:group atIndex:idx];
}

- (void)removeURLGroup:(BDSKURLGroup *)group {
    NSParameterAssert(URLGroupCount);
    URLGroupCount -= 1;
    [self removeChild:group];
}

- (void)addScriptGroup:(BDSKScriptGroup *)group {
    NSUInteger idx = webGroupCount + searchGroupCount + sharedGroupCount + URLGroupCount;
    scriptGroupCount += 1;
    [self insertChild:group atIndex:idx];
}

- (void)removeScriptGroup:(BDSKScriptGroup *)group {
    NSParameterAssert(scriptGroupCount);
    scriptGroupCount -= 1;
    [self removeChild:group];
}

- (void)resort {
    if (sortDescriptors) {
        NSRange range;
        if (sharedGroupCount > 1) {
            range = NSMakeRange(webGroupCount + searchGroupCount, sharedGroupCount);
            [children replaceObjectsInRange:range withObjectsFromArray:[[children subarrayWithRange:range] sortedArrayUsingDescriptors:sortDescriptors]];
        }
        if (URLGroupCount > 1) {
            range = NSMakeRange((webGroupCount + searchGroupCount + sharedGroupCount), URLGroupCount);
            [children replaceObjectsInRange:range withObjectsFromArray:[[children subarrayWithRange:range] sortedArrayUsingDescriptors:sortDescriptors]];
        }
        if (scriptGroupCount > 1) {
            range = NSMakeRange((webGroupCount + searchGroupCount + sharedGroupCount + URLGroupCount), scriptGroupCount);
            [children replaceObjectsInRange:range withObjectsFromArray:[[children subarrayWithRange:range] sortedArrayUsingDescriptors:sortDescriptors]];
        }
    }
}

- (void)removeAllUndoableChildren {
    NSRange range = NSMakeRange((webGroupCount + searchGroupCount + sharedGroupCount), (URLGroupCount + scriptGroupCount));
    URLGroupCount = 0;
    scriptGroupCount = 0;
    [self replaceChildrenInRange:range withChildren:[NSArray array]];
}

@end

#pragma mark -

@implementation BDSKCategoryParentGroup

- (id)init {
    return [self initWithName:NSLocalizedString(@"FIELD", @"source list group row title")];
}

- (NSArray *)categoryGroups {
    return [self children];
}

- (void)setCategoryGroups:(NSArray *)array {
    [self replaceChildrenInRange:NSMakeRange(0, [self numberOfChildren]) withChildren:array];
}

- (void)resort {
    if (sortDescriptors && [self numberOfChildren]) {
        BDSKCategoryGroup *first = [self childAtIndex:0];
        if ([first isEmpty]) {
            [first retain];
            [children removeObjectAtIndex:0];
            [super resort];
            [children insertObject:first atIndex:0];
            [first release];
        } else {
            [super resort];
        }
    }
}

- (void)setName:(id)newName {
    if (name != newName) {
        [name release];
        name = [newName retain];
    }
}

@end

#pragma mark -

@implementation BDSKStaticParentGroup

- (id)init {
    return [self initWithName:NSLocalizedString(@"STATIC", @"source list group row title")];
}

- (NSArray *)staticGroups {
    return [self children];
}

- (void)addStaticGroup:(BDSKStaticGroup *)group {
    [self insertChild:group atIndex:[self numberOfChildren]];
}

- (void)removeStaticGroup:(BDSKStaticGroup *)group {
    [self removeChild:group];
}

- (BOOL)isValidDropTarget { return YES; }

@end


#pragma mark -

@implementation BDSKSmartParentGroup

- (id)init {
   if (self = [self initWithName:NSLocalizedString(@"SMART", @"source list group row title")]) {
        hasLastImportGroup = NO;
    }
    return self;
}

// return nil if non-existent
- (BDSKStaticGroup *)lastImportGroup {
    return hasLastImportGroup ? [self childAtIndex:0] : nil;
}

- (NSArray *)smartGroups {
    if (hasLastImportGroup == 0)
        return [self children];
    NSRange range = NSMakeRange(1, [self numberOfChildren] - 1);
    return [self childrenInRange:range];
}

- (void)setLastImportedPublications:(NSArray *)pubs {
    if ([pubs count]) {
        if (hasLastImportGroup == NO) {
            hasLastImportGroup = YES;
            BDSKStaticGroup *group = [[BDSKStaticGroup alloc] initWithLastImport:pubs];
            [self insertChild:group atIndex:0];
            [group release];
        } else {
            [[self childAtIndex:0] setPublications:pubs];
        }
    } else if (hasLastImportGroup) {
        hasLastImportGroup = NO;
        [self removeChild:[self childAtIndex:0]];
    }
}

- (void)addSmartGroup:(BDSKSmartGroup *)group {
    [self insertChild:group atIndex:[self numberOfChildren]];
}

- (void)removeSmartGroup:(BDSKSmartGroup *)group {
    [self removeChild:group];
}

- (void)resort {
    if (hasLastImportGroup == NO) {
        [super resort];
    } else if (sortDescriptors && [self numberOfChildren] > 2) {
        BDSKGroup *lastImport = [[self childAtIndex:0] retain];
        [children removeObjectAtIndex:0];
        [super resort];
        [children insertObject:lastImport atIndex:0];
        [lastImport release];
    }
}

- (void)removeAllUndoableChildren {
    hasLastImportGroup = NO;
    [super removeAllUndoableChildren];
}

@end

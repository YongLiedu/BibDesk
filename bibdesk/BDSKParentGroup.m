//
//  BDSKParentGroup.m
//  Bibdesk
//
//  Created by Adam Maxwell on 4/9/09.
/*
 This software is Copyright (c) 2009-2016
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
#import "BDSKLibraryGroup.h"
#import "BDSKLastImportGroup.h"
#import "BDSKWebGroup.h"
#import "BibDocument.h"
#import "BibAuthor.h"

#define BDSKNoInitialWebGroupKey @"BDSKNoInitialWebGroup"

@implementation BDSKParentGroup

- (id)initWithName:(NSString *)aName {
    self = [super initWithName:aName];
    if (self) {
        children = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    BDSKASSERT_NOT_REACHED("Parent groups should never be decoded");
    self = [super initWithCoder:decoder];
    if (self) {
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

- (void)dealloc {
    [children setValue:nil forKey:@"parent"];
    [children setValue:nil forKey:@"document"];
    BDSKDESTROY(children);
    BDSKDESTROY(sortDescriptors);
    [super dealloc];
}

- (NSArray *)publications { return nil; }

- (id)cellValue { return [self name]; }

// this is used to remember expanded state, as they are usually unique we use the class, also for backward compatibility
- (NSString *)identifier { return NSStringFromClass([self class]); }

- (NSArray *)children {
    return children;
}

- (NSUInteger)numberOfChildren { return [children count]; }

- (NSArray *)childrenAtIndex:(NSUInteger)idx count:(NSUInteger)aCount {
    return [children subarrayWithRange:NSMakeRange(idx, aCount)];
}

- (void)resortInRange:(NSRange)range {
    if (sortDescriptors && range.length > 1)
        [children replaceObjectsInRange:range withObjectsFromArray:[[children subarrayWithRange:range] sortedArrayUsingDescriptors:sortDescriptors]];
}

- (void)resort {
    if (sortDescriptors && [self numberOfChildren] > 1)
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
        [children setValue:nil forKey:@"parent"];
        [children setValue:nil forKey:@"document"];
        [children setArray:newChildren];
    } else {
        [[children subarrayWithRange:range] setValue:nil forKey:@"parent"];
        [[children subarrayWithRange:range] setValue:nil forKey:@"document"];
        [children replaceObjectsInRange:range withObjectsFromArray:newChildren];
    }
    [children setValue:self forKey:@"parent"];
    [children setValue:[self document] forKey:@"document"];
    if ([newChildren count])
        [self resort];
}

- (void)removeAllChildren {
    [children setValue:nil forKey:@"parent"];
    [children setValue:nil forKey:@"document"];
    [children removeAllObjects];
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
    [children setValue:newDocument forKey:@"document"];
}

- (void)removeAllUndoableChildren {
    [self removeAllChildren];
}

@end

#pragma mark -

@implementation BDSKLibraryParentGroup

- (id)init {
    // all-encompassing, non-expandable name
    self = [self initWithName:NSLocalizedString(@"Groups", @"source list group row title")];
    if (self) {
        BDSKGroup *libraryGroup = [[BDSKLibraryGroup alloc] init];
        [self insertChild:libraryGroup atIndex:0];
        [libraryGroup release];
    }
    return self;
}    

- (BDSKGroupType)groupType { return BDSKLibraryParentGroupType; }

// do nothing; this group has a fixed order
- (void)sortUsingDescriptors:(NSArray *)descriptors {}

// do nothing
- (void)removeAllUndoableChildren {}

@end

#pragma mark -

@implementation BDSKExternalParentGroup

#define webGroupLocation    0
#define searchGroupLocation webGroupCount
#define sharedGroupLocation webGroupCount + searchGroupCount
#define URLGroupLocation    webGroupCount + searchGroupCount + sharedGroupCount
#define scriptGroupLocation webGroupCount + searchGroupCount + sharedGroupCount + URLGroupCount

- (id)init {
    self = [self initWithName:NSLocalizedString(@"External", @"source list group row title")];
    if (self) {
        webGroupCount = 0;
        sharedGroupCount = 0;
        URLGroupCount = 0;
        scriptGroupCount = 0;
        searchGroupCount = 0;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKNoInitialWebGroupKey] == NO) {
            webGroupCount = 1;
            BDSKWebGroup *webGroup = [[BDSKWebGroup alloc] init];
            [self insertChild:webGroup atIndex:0];
            [webGroup release];
        }
    }
    return self;
}

- (BDSKGroupType)groupType { return BDSKExternalParentGroupType; }

- (NSArray *)webGroups {
    return [self childrenAtIndex:webGroupLocation count:webGroupCount];
}

- (NSArray *)searchGroups {
    return [self childrenAtIndex:searchGroupLocation count:searchGroupCount];
}

- (NSArray *)sharedGroups {
    return [self childrenAtIndex:sharedGroupLocation count:sharedGroupCount];
}

- (NSArray *)URLGroups {
    return [self childrenAtIndex:URLGroupLocation count:URLGroupCount];
}

- (NSArray *)scriptGroups {
    return [self childrenAtIndex:scriptGroupLocation count:scriptGroupCount];
}

- (void)addWebGroup:(BDSKWebGroup *)group {
    NSUInteger idx = webGroupLocation + webGroupCount;
    webGroupCount += 1;    
    [self insertChild:group atIndex:idx];
}

- (void)removeWebGroup:(BDSKWebGroup *)group {
    NSParameterAssert(webGroupCount);
    webGroupCount -= 1;    
    [self removeChild:group];
}

- (void)addSearchGroup:(BDSKSearchGroup *)group {
    NSUInteger idx = searchGroupLocation + searchGroupCount;
    searchGroupCount += 1;    
    [self insertChild:group atIndex:idx];
}

- (void)removeSearchGroup:(BDSKSearchGroup *)group {
    NSParameterAssert(searchGroupCount);
    searchGroupCount -= 1;    
    [self removeChild:group];
}

- (void)setSharedGroups:(NSArray *)array {
    NSRange range = NSMakeRange(sharedGroupLocation, sharedGroupCount);
    sharedGroupCount = [array count];
    [self replaceChildrenInRange:range withChildren:array];
}

- (void)addURLGroup:(BDSKURLGroup *)group {
    NSUInteger idx = URLGroupLocation + URLGroupCount;
    URLGroupCount += 1;
    [self insertChild:group atIndex:idx];
}

- (void)removeURLGroup:(BDSKURLGroup *)group {
    NSParameterAssert(URLGroupCount);
    URLGroupCount -= 1;
    [self removeChild:group];
}

- (void)addScriptGroup:(BDSKScriptGroup *)group {
    NSUInteger idx = scriptGroupLocation + scriptGroupCount;
    scriptGroupCount += 1;
    [self insertChild:group atIndex:idx];
}

- (void)removeScriptGroup:(BDSKScriptGroup *)group {
    NSParameterAssert(scriptGroupCount);
    scriptGroupCount -= 1;
    [self removeChild:group];
}

- (void)resort {
    [self resortInRange:NSMakeRange(webGroupLocation, webGroupCount)];
    [self resortInRange:NSMakeRange(searchGroupLocation, searchGroupCount)];
    [self resortInRange:NSMakeRange(sharedGroupLocation, sharedGroupCount)];
    [self resortInRange:NSMakeRange(URLGroupLocation, URLGroupCount)];
    [self resortInRange:NSMakeRange(scriptGroupLocation, scriptGroupCount)];
}

- (void)removeAllUndoableChildren {
    NSRange range = NSMakeRange(URLGroupLocation, URLGroupCount + scriptGroupCount);
    URLGroupCount = 0;
    scriptGroupCount = 0;
    [self replaceChildrenInRange:range withChildren:[NSArray array]];
}

@end

#pragma mark -

@implementation BDSKCategoryParentGroup

- (id)initWithKey:(NSString *)aKey {
    self = [self initWithName:aKey];
    if (self) {
        key = [aKey retain];
    }
    return self;
}

- (BDSKGroupType)groupType { return BDSKCategoryParentGroupType; }

// category parents aren't unique, so we need to use a different identifier for remembering expanded state
- (NSString *)identifier {
    return [self key];
}

- (NSArray *)categoryGroups {
    return [self children];
}

- (void)setCategoryGroups:(NSArray *)array {
    [self replaceChildrenInRange:NSMakeRange(0, [self numberOfChildren]) withChildren:array];
}

- (void)resort {
    if (sortDescriptors && [self numberOfChildren] > 1) {
        if ([[self childAtIndex:0] isEmpty])
            [self resortInRange:NSMakeRange(1, [self numberOfChildren] - 1)];
        else
            [super resort];
    }
}

- (NSString *)key {
    return key;
}

- (void)setKey:(NSString *)newKey {
    if (key != newKey) {
        [key release];
        key = [newKey retain];
        [name release];
        name = [[key uppercaseString] retain];
    }
}

@end

#pragma mark -

@implementation BDSKStaticParentGroup

- (id)init {
    return [self initWithName:NSLocalizedString(@"Static", @"source list group row title")];
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

- (BDSKGroupType)groupType { return BDSKStaticParentGroupType; }

@end


#pragma mark -

@implementation BDSKSmartParentGroup

- (id)init {
    self = [self initWithName:NSLocalizedString(@"Smart", @"source list group row title")];
    if (self) {
        hasLastImportGroup = NO;
    }
    return self;
}

- (BDSKGroupType)groupType { return BDSKSmartParentGroupType; }

// return nil if non-existent
- (BDSKLastImportGroup *)lastImportGroup {
    return hasLastImportGroup ? [self childAtIndex:0] : nil;
}

- (NSArray *)smartGroups {
    if (hasLastImportGroup == 0)
        return [self children];
    return [self childrenAtIndex:1 count:[self numberOfChildren] - 1];
}

- (void)setLastImportedPublications:(NSArray *)pubs {
    if ([pubs count]) {
        if (hasLastImportGroup == NO) {
            hasLastImportGroup = YES;
            BDSKLastImportGroup *group = [[BDSKLastImportGroup alloc] initWithLastImport:pubs];
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
    if (hasLastImportGroup == NO)
        [super resort];
    else if ([self numberOfChildren] > 2)
        [self resortInRange:NSMakeRange(1, [self numberOfChildren] - 1)];
}

- (void)removeAllUndoableChildren {
    hasLastImportGroup = NO;
    [super removeAllUndoableChildren];
}

@end

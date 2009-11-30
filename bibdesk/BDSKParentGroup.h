//
//  BDSKParentGroup.h
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

#import <Cocoa/Cocoa.h>
#import "BDSKGroup.h"


@class BDSKWebGroup, BDSKSearchGroup, BDSKURLGroup, BDSKScriptGroup, BDSKSmartGroup, BDSKStaticGroup, BDSKLastImportGroup;

@interface BDSKParentGroup : BDSKGroup {
    NSMutableArray *children;
    NSArray *sortDescriptors;
}

- (NSUInteger)numberOfChildren;
- (id)childAtIndex:(NSUInteger)anIndex;
- (NSArray *)children;
- (NSArray *)childrenInRange:(NSRange)range;

- (BOOL)containsChild:(id)group;

- (void)sortUsingDescriptors:(NSArray *)sortDescriptors;

- (void)removeAllUndoableChildren;

@end

#pragma mark -

@interface BDSKLibraryParentGroup : BDSKParentGroup
@end

#pragma mark -

@interface BDSKExternalParentGroup : BDSKParentGroup {
    NSUInteger webGroupCount;
    NSUInteger searchGroupCount;
    NSUInteger sharedGroupCount;
    NSUInteger URLGroupCount;
    NSUInteger scriptGroupCount;
}

- (BDSKWebGroup *)webGroup;
- (NSArray *)searchGroups;
- (NSArray *)sharedGroups;
- (NSArray *)URLGroups;
- (NSArray *)scriptGroups;
- (void)addSearchGroup:(BDSKSearchGroup *)group;
- (void)setSharedGroups:(NSArray *)array;
- (void)removeSearchGroup:(BDSKSearchGroup *)group;
- (void)addURLGroup:(BDSKURLGroup *)group;
- (void)removeURLGroup:(BDSKURLGroup *)group;
- (void)addScriptGroup:(BDSKScriptGroup *)group;
- (void)removeScriptGroup:(BDSKScriptGroup *)group;

@end

#pragma mark -

@interface BDSKSmartParentGroup : BDSKParentGroup {
    BOOL hasLastImportGroup;
}

- (BDSKLastImportGroup *)lastImportGroup;
- (NSArray *)smartGroups;
- (void)setLastImportedPublications:(NSArray *)pubs;
- (void)addSmartGroup:(BDSKSmartGroup *)group;
- (void)removeSmartGroup:(BDSKSmartGroup *)group;

@end

#pragma mark -

@interface BDSKCategoryParentGroup : BDSKParentGroup

- (NSArray *)categoryGroups;
- (void)setCategoryGroups:(NSArray *)array;

- (void)setName:(id)newName;

@end

#pragma mark -

@interface BDSKStaticParentGroup : BDSKParentGroup

- (NSArray *)staticGroups;
- (void)addStaticGroup:(BDSKStaticGroup *)group;
- (void)removeStaticGroup:(BDSKStaticGroup *)group;

@end

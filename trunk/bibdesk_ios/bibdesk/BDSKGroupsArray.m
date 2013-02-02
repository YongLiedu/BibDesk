//
//  BDSKGroupsArray.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/10/06.
/*
 This software is Copyright (c) 2006-2012
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

#import "BDSKGroupsArray.h"
#import "BDSKGroup.h"
#import "BDSKParentGroup.h"
#if BDSK_OS_X
    #import "BDSKSharedGroup.h"
    #import "BDSKURLGroup.h"
    #import "BDSKScriptGroup.h"
    #import "BDSKSearchGroup.h"
#endif
#import "BDSKSmartGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKCategoryGroup.h"
#import "BDSKLibraryGroup.h"
#if BDSK_OS_X
    #import "BDSKLastImportGroup.h"
    #import "BDSKWebGroup.h"
#endif
#import "BDSKPublicationsArray.h"
#import "BibAuthor.h"
#import "BDSKFilter.h"
#import "NSArray_BDSKExtensions.h"

NSString *BDSKGroupsArrayGroupsKey = @"groups";

#define LIBRARY_PARENT_INDEX  0
#define EXTERNAL_PARENT_INDEX 1 /* webGroup, searchGroups, sharedGroups, URLGroups, scriptGroups */
#define SMART_PARENT_INDEX    2 /* lastImportGroup, smartGroups */
#define STATIC_PARENT_INDEX   3 /* staticGroups */
#define CATEGORY_PARENT_INDEX 4 /* categoryGroups */


@implementation BDSKGroupsArray 

- (id)initWithDocument:(BibDocument *)aDocument {
    if(self = [super init]) {
        groups = [[NSMutableArray alloc] init];
        
        BDSKParentGroup *parent;
        
        parent = [[BDSKLibraryParentGroup alloc] init];
        [parent setDocument:aDocument];
        [groups addObject:parent];
        [parent release];
        
        parent = [[BDSKExternalParentGroup alloc] init];
        [parent setDocument:aDocument];
        [groups addObject:parent];
        [parent release];
        
        parent = [[BDSKSmartParentGroup alloc] init];
        [parent setDocument:aDocument];
        [groups addObject:parent];
        [parent release];
        
        parent = [[BDSKStaticParentGroup alloc] init];
        [parent setDocument:aDocument];
        [groups addObject:parent];
        [parent release];
        
        document = aDocument;
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(groups);
    [super dealloc];
}

- (NSUndoManager *)undoManager {
    return [[self document] undoManager];
}

#pragma mark NSArray primitive methods

- (NSUInteger)count {
    return [groups count];
}

- (id)objectAtIndex:(NSUInteger)idx {
    return [groups objectAtIndex:idx];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len {
    return [groups countByEnumeratingWithState:state objects:stackbuf count:len];
}

#pragma mark Subarray Accessors

- (BDSKLibraryParentGroup *)libraryParent { return [groups objectAtIndex:LIBRARY_PARENT_INDEX]; }

- (BDSKExternalParentGroup *)externalParent { return [groups objectAtIndex:EXTERNAL_PARENT_INDEX]; }

- (BDSKSmartParentGroup *)smartParent { return [groups objectAtIndex:SMART_PARENT_INDEX]; }

- (BDSKStaticParentGroup *)staticParent { return [groups objectAtIndex:STATIC_PARENT_INDEX]; }

- (NSArray *)categoryParents {
    return [groups subarrayWithRange:NSMakeRange(CATEGORY_PARENT_INDEX, [groups count] - CATEGORY_PARENT_INDEX)];
}

- (BDSKLibraryGroup *)libraryGroup{
    return [[self libraryParent] childAtIndex:0];
}

#if BDSK_OS_X
- (NSArray *)webGroups{
    return [[self externalParent] webGroups];
}

- (NSArray *)searchGroups{
    return [[self externalParent] searchGroups];
}

- (NSArray *)sharedGroups{
    return [[self externalParent] sharedGroups];
}

- (NSArray *)URLGroups{
    return [[self externalParent] URLGroups];
}

- (NSArray *)scriptGroups{
    return [[self externalParent] scriptGroups];
}

- (BDSKLastImportGroup *)lastImportGroup{
    return [[self smartParent] lastImportGroup];
}
#endif

- (NSArray *)smartGroups{
    return [[self smartParent] smartGroups];
}

- (NSArray *)staticGroups{
    return [[self staticParent] staticGroups];
}

- (NSArray *)categoryGroups{
    NSMutableArray *categoryGroups = [NSMutableArray array];
    for (BDSKCategoryParentGroup *group in groups)
        [categoryGroups addObjectsFromArray:[group categoryGroups]];
    return categoryGroups;
}

- (NSArray *)allChildren{
    NSMutableArray *children = [NSMutableArray array];
    for (BDSKParentGroup *group in groups)
        [children addObjectsFromArray:[group children]];
    return children;
}

#pragma mark Mutable accessors

- (void)addCategoryParent:(BDSKCategoryParentGroup *)group {
    [group setDocument:document];
    [groups addObject:group];
}

- (void)removeCategoryParent:(BDSKCategoryParentGroup *)group {
    NSMutableArray *removedGroups = [[group categoryGroups] mutableCopy];
    [removedGroups addObject:group];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillRemoveGroupsNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:removedGroups, BDSKGroupsArrayGroupsKey, nil]];
    [removedGroups release];
    [group setDocument:nil];
    [groups removeObject:group];
}

#if BDSK_OS_X
- (void)setLastImportedPublications:(NSArray *)pubs{
    [[self smartParent] setLastImportedPublications:pubs];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)setSharedGroups:(NSArray *)array{
    NSMutableArray *removedGroups = [[self sharedGroups] mutableCopy];
    [removedGroups removeObjectsInArray:array];
    if ([removedGroups count])
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillRemoveGroupsNotification
            object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:removedGroups, BDSKGroupsArrayGroupsKey, nil]];
    [removedGroups release];
    [[self externalParent] setSharedGroups:array];
}

- (void)addURLGroup:(BDSKURLGroup *)group {
	[[[self undoManager] prepareWithInvocationTarget:self] removeURLGroup:group];
	[[self externalParent] addURLGroup:group];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)removeURLGroup:(BDSKURLGroup *)group {
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillRemoveGroupsNotification
        object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObjects:group, nil], BDSKGroupsArrayGroupsKey, nil]];
	[[[self undoManager] prepareWithInvocationTarget:self] addURLGroup:group];
	[[self externalParent] removeURLGroup:group];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)addScriptGroup:(BDSKScriptGroup *)group {
	[[[self undoManager] prepareWithInvocationTarget:self] removeScriptGroup:group];
	[[self externalParent] addScriptGroup:group];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)removeScriptGroup:(BDSKScriptGroup *)group {
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillRemoveGroupsNotification
        object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObjects:group, nil], BDSKGroupsArrayGroupsKey, nil]];
	[[[self undoManager] prepareWithInvocationTarget:self] addScriptGroup:group];
	[[self externalParent] removeScriptGroup:group];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)addSearchGroup:(BDSKSearchGroup *)group {
	[[self externalParent] addSearchGroup:group];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)removeSearchGroup:(BDSKSearchGroup *)group {
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillRemoveGroupsNotification
        object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObjects:group, nil], BDSKGroupsArrayGroupsKey, nil]];
	[[self externalParent] removeSearchGroup:group];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)addWebGroup:(BDSKWebGroup *)group {
	[[self externalParent] addWebGroup:group];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)removeWebGroup:(BDSKWebGroup *)group {
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillRemoveGroupsNotification
        object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObjects:group, nil], BDSKGroupsArrayGroupsKey, nil]];
	[[self externalParent] removeWebGroup:group];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}
#endif

- (void)addSmartGroup:(BDSKSmartGroup *)group {
	[[[self undoManager] prepareWithInvocationTarget:self] removeSmartGroup:group];
    // update the count
	[group filterItems:[document publications]];
	[[self smartParent] addSmartGroup:group];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)removeSmartGroup:(BDSKSmartGroup *)group {
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillRemoveGroupsNotification
        object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObjects:group, nil], BDSKGroupsArrayGroupsKey, nil]];
	[[[self undoManager] prepareWithInvocationTarget:self] addSmartGroup:group];
	[[self smartParent] removeSmartGroup:group];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)addStaticGroup:(BDSKStaticGroup *)group {
	[[[self undoManager] prepareWithInvocationTarget:self] removeStaticGroup:group];
	[[self staticParent] addStaticGroup:group];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)removeStaticGroup:(BDSKStaticGroup *)group {
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillRemoveGroupsNotification
        object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObjects:group, nil], BDSKGroupsArrayGroupsKey, nil]];
	[[[self undoManager] prepareWithInvocationTarget:self] addStaticGroup:group];
	[[self staticParent] removeStaticGroup:group];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)setCategoryGroups:(NSArray *)array forParent:(BDSKCategoryParentGroup *)parent {
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillRemoveGroupsNotification
        object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[parent categoryGroups], BDSKGroupsArrayGroupsKey, nil]];
    [parent setCategoryGroups:array];
}

// this should only be used just before reading from file, in particular revert, so we shouldn't make this undoable
- (void)removeAllUndoableGroups {
    [groups makeObjectsPerformSelector:@selector(removeAllUndoableChildren)];
}

#pragma mark Document

- (BibDocument *)document{
    return document;
}

#pragma mark Sorting

- (void)sortUsingDescriptors:(NSArray *)sortDescriptors{
    [groups makeObjectsPerformSelector:_cmd withObject:sortDescriptors];
}

#pragma mark Serializing

- (void)setGroupsOfType:(NSInteger)groupType fromSerializedData:(NSData *)data {
	NSError *error = nil;
	NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
	id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:NSPropertyListImmutable
														  format:&format 
                                                           error:&error];
	
	if (error) {
		NSLog(@"Error deserializing: %@", error);
		return;
	}
	if ([plist isKindOfClass:[NSArray class]] == NO) {
		NSLog(@"Serialized groups was no array.");
		return;
	}
	
    Class groupClass = Nil;
    
    if (groupType == BDSKSmartGroupType)
        groupClass = [BDSKSmartGroup class];
    else if (groupType == BDSKStaticGroupType)
        groupClass = [BDSKStaticGroup class];
#if BDSK_OS_X
	else if (groupType == BDSKURLGroupType)
        groupClass = [BDSKURLGroup class];
	else if (groupType == BDSKScriptGroupType)
        groupClass = [BDSKScriptGroup class];
#endif
    
    if (groupClass) {
        id group = nil;
        
        for (NSDictionary *groupDict in plist) {
            @try {
                group = [[groupClass alloc] initWithDictionary:groupDict];
                if (groupType == BDSKSmartGroupType)
                    [[self smartParent] addSmartGroup:group];
                else if (groupType == BDSKURLGroupType)
                    [[self externalParent] addURLGroup:group];
                else if (groupType == BDSKScriptGroupType)
                    [[self externalParent] addScriptGroup:group];
                else if (groupType == BDSKStaticGroupType)
                    [[self staticParent] addStaticGroup:group];
            }
            @catch(id exception) {
                NSLog(@"Ignoring exception \"%@\" while parsing group data.", exception);
            }
            @finally {
                [group release];
                group = nil;
            }
        }
    }
}

- (NSData *)serializedGroupsDataOfType:(NSInteger)groupType {
    Class groupClass = Nil;
    NSArray *groupArray = nil;
    
    if (groupType == BDSKSmartGroupType) {
        groupClass = [BDSKSmartGroup class];
        groupArray = [self smartGroups];
	} else if (groupType == BDSKStaticGroupType) {
        groupClass = [BDSKStaticGroup class];
        groupArray = [self staticGroups];
#if BDSK_OS_X
	} else if (groupType == BDSKURLGroupType) {
        groupClass = [BDSKURLGroup class];
        groupArray = [self URLGroups];
	} else if (groupType == BDSKScriptGroupType) {
        groupClass = [BDSKScriptGroup class];
        groupArray = [self scriptGroups];
#endif
    }
    
    NSData *data = nil;
    
    if (groupClass && groupArray) {
        NSArray *array = [groupArray valueForKey:@"dictionaryValue"];
        
        NSError *error = nil;
        NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
        data = [NSPropertyListSerialization dataWithPropertyList:array
                                                          format:format
                                                         options:0
                                                           error:&error];
            
        if (error) {
            NSLog(@"Error serializing: %@", error);
            return nil;
        }
	}
    return data;
}

@end

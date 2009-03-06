//
//  BDSKGroupsArray.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/10/06.
/*
 This software is Copyright (c) 2006-2009
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
#import "BDSKSharedGroup.h"
#import "BDSKURLGroup.h"
#import "BDSKScriptGroup.h"
#import "BDSKSearchGroup.h"
#import "BDSKSmartGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKCategoryGroup.h"
#import "BDSKWebGroup.h"
#import "BDSKPublicationsArray.h"
#import "BibAuthor.h"
#import "NSObject_BDSKExtensions.h"
#import "NSIndexSet_BDSKExtensions.h"
#import "BDSKFilter.h"
#import "NSArray_BDSKExtensions.h"

@interface BDSKGroupsArray (Private)

- (void)updateStaticGroupsIfNeeded;
- (NSUndoManager *)undoManager;

@end


@implementation BDSKGroupsArray 

- (id)initWithDocument:(BibDocument *)aDocument {
    if(self = [super init]) {
        libraryGroup = [[BDSKGroup alloc] initLibraryGroup];
        [libraryGroup setDocument:aDocument];
        if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldShowWebGroupPrefKey]){
            webGroup = [[BDSKWebGroup alloc] initWithName:NSLocalizedString(@"Web", @"Web")];
            [webGroup setDocument:aDocument];
        }else{
            webGroup = nil;
        }
        lastImportGroup = nil;
        sharedGroups = [[NSMutableArray alloc] init];
        urlGroups = [[NSMutableArray alloc] init];
        scriptGroups = [[NSMutableArray alloc] init];
        searchGroups = [[NSMutableArray alloc] init];
        smartGroups = [[NSMutableArray alloc] init];
        staticGroups = [[NSMutableArray alloc] init];
        tmpStaticGroups = nil;
        categoryGroups = nil;
        document = aDocument;
        spinners = nil;
    }
    return self;
}

- (void)dealloc {
    [libraryGroup release];
    [webGroup release];
    [lastImportGroup release];
    [sharedGroups release];
    [urlGroups release];
    [scriptGroups release];
    [searchGroups release];
    [smartGroups release];
    [staticGroups release];
    [tmpStaticGroups release];
    [categoryGroups release];
    [spinners release];
    [super dealloc];
}

#pragma mark NSArray primitive methods

- (unsigned int)count {
    [self updateStaticGroupsIfNeeded];
    return [sharedGroups count] + [urlGroups count] + [scriptGroups count] + [searchGroups count]
        + [smartGroups count] + [staticGroups count] + [categoryGroups count] + 
        ([lastImportGroup count] ? 1 : 0) + (webGroup == nil ? 0 : 1) + 1 /* add 1 for all publications group */ ;
}

- (id)objectAtIndex:(unsigned int)idx {
    unsigned int count;
    
    [self updateStaticGroupsIfNeeded];
    
    if (idx == 0)
		return libraryGroup;
    idx -= 1;
    
    if (webGroup != nil){
        // if we are showing the web group, insert it after the library:
        if(idx == 0)
            return webGroup;
        idx -= 1;
    }
        
    count = [sharedGroups count];
    if (idx < count)
        return [sharedGroups objectAtIndex:idx];
    idx -= count;
    
    count = [urlGroups count];
    if (idx < count)
        return [urlGroups objectAtIndex:idx];
    idx -= count;
    
    count = [scriptGroups count];
    if (idx < count)
        return [scriptGroups objectAtIndex:idx];
    idx -= count;
    
    count = [searchGroups count];
    if (idx < count)
        return [searchGroups objectAtIndex:idx];
    idx -= count;
    
    if ([lastImportGroup count] != 0) {
        if (idx == 0)
            return lastImportGroup;
        idx -= 1;
    }
    
	count = [smartGroups count];
    if (idx < count)
		return [smartGroups objectAtIndex:idx];
    idx -= count;
    
    count = [staticGroups count];
    if (idx < count)
        return [staticGroups objectAtIndex:idx];
    idx -= count;
    
    return [categoryGroups objectAtIndex:idx];
}

#pragma mark Subarray Accessors

- (BDSKGroup *)libraryGroup{
    return libraryGroup;
}

- (BDSKWebGroup *)webGroup{
    return webGroup;
}

- (BDSKStaticGroup *)lastImportGroup{
    return lastImportGroup;
}

- (NSArray *)sharedGroups{
    return sharedGroups;
}

- (NSArray *)URLGroups{
    return urlGroups;
}

- (NSArray *)scriptGroups{
    return scriptGroups;
}

- (NSArray *)searchGroups{
    return searchGroups;
}

- (NSArray *)smartGroups{
    return smartGroups;
}

- (NSArray *)staticGroups{
    [self updateStaticGroupsIfNeeded];
    return staticGroups;
}

- (NSArray *)categoryGroups{
    return categoryGroups;
}

#pragma mark Index ranges of groups

- (NSRange)rangeOfSharedGroups{
    if(webGroup != nil)
        return NSMakeRange(2, [sharedGroups count]); // library and web
    else
        return NSMakeRange(1, [sharedGroups count]); // library only
}

- (NSRange)rangeOfURLGroups{
    return NSMakeRange(NSMaxRange([self rangeOfSharedGroups]), [urlGroups count]);
}

- (NSRange)rangeOfScriptGroups{
    return NSMakeRange(NSMaxRange([self rangeOfURLGroups]), [scriptGroups count]);
}

- (NSRange)rangeOfSearchGroups{
    return NSMakeRange(NSMaxRange([self rangeOfScriptGroups]), [searchGroups count]);
}

- (NSRange)rangeOfSmartGroups{
    unsigned startIndex = NSMaxRange([self rangeOfSearchGroups]);
    if([lastImportGroup count] > 0) startIndex++;
    return NSMakeRange(startIndex, [smartGroups count]);
}

- (NSRange)rangeOfStaticGroups{
    [self updateStaticGroupsIfNeeded];
    return NSMakeRange(NSMaxRange([self rangeOfSmartGroups]), [staticGroups count]);
}

- (NSRange)rangeOfCategoryGroups{
    return NSMakeRange(NSMaxRange([self rangeOfStaticGroups]), [categoryGroups count]);
}

- (NSRange)rangeOfExternalGroups{
    return NSMakeRange(1, NSMaxRange([self rangeOfSearchGroups]) - 1);
}

- (unsigned int)numberOfSharedGroupsAtIndexes:(NSIndexSet *)indexes{
    return [indexes numberOfIndexesInRange:[self rangeOfSharedGroups]];
}

- (unsigned int)numberOfURLGroupsAtIndexes:(NSIndexSet *)indexes{
    return [indexes numberOfIndexesInRange:[self rangeOfURLGroups]];
}

- (unsigned int)numberOfScriptGroupsAtIndexes:(NSIndexSet *)indexes{
    return [indexes numberOfIndexesInRange:[self rangeOfScriptGroups]];
}

- (unsigned int)numberOfSearchGroupsAtIndexes:(NSIndexSet *)indexes{
    return [indexes numberOfIndexesInRange:[self rangeOfSearchGroups]];
}

- (unsigned int)numberOfSmartGroupsAtIndexes:(NSIndexSet *)indexes{
    return [indexes numberOfIndexesInRange:[self rangeOfSmartGroups]];
}

- (unsigned int)numberOfStaticGroupsAtIndexes:(NSIndexSet *)indexes{
    return [indexes numberOfIndexesInRange:[self rangeOfStaticGroups]];
}

- (unsigned int)numberOfCategoryGroupsAtIndexes:(NSIndexSet *)indexes{
    return [indexes numberOfIndexesInRange:[self rangeOfCategoryGroups]];
}

- (unsigned int)numberOfExternalGroupsAtIndexes:(NSIndexSet *)indexes{
    return [indexes numberOfIndexesInRange:[self rangeOfExternalGroups]];
}

- (BOOL)hasWebGroupAtIndexes:(NSIndexSet *)indexes{
    if (webGroup == nil) return NO;
    NSRange webRange = NSMakeRange(1,1);
    return [indexes intersectsIndexesInRange:webRange];
}

- (BOOL)hasSharedGroupsAtIndexes:(NSIndexSet *)indexes{
    NSRange sharedRange = [self rangeOfSharedGroups];
    return [indexes intersectsIndexesInRange:sharedRange];
}

- (BOOL)hasURLGroupsAtIndexes:(NSIndexSet *)indexes{
    NSRange urlRange = [self rangeOfURLGroups];
    return [indexes intersectsIndexesInRange:urlRange];
}

- (BOOL)hasScriptGroupsAtIndexes:(NSIndexSet *)indexes{
    NSRange scriptRange = [self rangeOfScriptGroups];
    return [indexes intersectsIndexesInRange:scriptRange];
}

- (BOOL)hasSearchGroupsAtIndexes:(NSIndexSet *)indexes{
    NSRange searchRange = [self rangeOfSearchGroups];
    return [indexes intersectsIndexesInRange:searchRange];
}

- (BOOL)hasSmartGroupsAtIndexes:(NSIndexSet *)indexes{
    NSRange smartRange = [self rangeOfSmartGroups];
    return [indexes intersectsIndexesInRange:smartRange];
}

- (BOOL)hasStaticGroupsAtIndexes:(NSIndexSet *)indexes{
    NSRange staticRange = [self rangeOfStaticGroups];
    return [indexes intersectsIndexesInRange:staticRange];
}

- (BOOL)hasCategoryGroupsAtIndexes:(NSIndexSet *)indexes{
    NSRange categoryRange = [self rangeOfCategoryGroups];
    return [indexes intersectsIndexesInRange:categoryRange];
}

- (BOOL)hasExternalGroupsAtIndexes:(NSIndexSet *)indexes{
    NSRange externalRange = [self rangeOfExternalGroups];
    return [indexes intersectsIndexesInRange:externalRange];
}

#pragma mark Mutable accessors

- (void)duplicateUniqueIDsFromGroups:(NSArray *)oldGroups toGroups:(NSArray *)newGroups {
    NSMutableDictionary *ids = [NSMutableDictionary dictionary];
    NSEnumerator *groupEnum = [oldGroups objectEnumerator];
    BDSKGroup *group;
    NSString *uniqueID;
    while (group = [groupEnum nextObject])
        [ids setObject:[group uniqueID] forKey:[group stringValue]];
    groupEnum = [newGroups objectEnumerator];
    while (group = [groupEnum nextObject]) {
        if (uniqueID = [ids objectForKey:[group stringValue]])
            [group setUniqueID:uniqueID];
    }
}

- (void)setLastImportedPublications:(NSArray *)pubs{
    if(lastImportGroup == nil) {
        lastImportGroup = [[BDSKStaticGroup alloc] initWithLastImport:pubs];
        [lastImportGroup setDocument:[self document]];
    } else {
        [lastImportGroup setPublications:pubs];
    }
}

- (void)setSharedGroups:(NSArray *)array{
    if(sharedGroups != array){
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillAddRemoveGroupNotification object:self];
        
        // try to preserve the unique ID when we regenerate the groups
        if ([array count] && [sharedGroups count])
            [self duplicateUniqueIDsFromGroups:sharedGroups toGroups:array];
        
        [sharedGroups removeObjectsInArray:array];
        [self performSelector:@selector(removeSpinnerForGroup:) withObjectsFromArray:sharedGroups];
        [sharedGroups makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
        [sharedGroups setArray:array]; 
        [sharedGroups makeObjectsPerformSelector:@selector(setDocument:) withObject:[self document]];
    }
}

- (void)addURLGroup:(BDSKURLGroup *)group {
	[[[self undoManager] prepareWithInvocationTarget:self] removeURLGroup:group];
    
	[urlGroups addObject:group];
    [group setDocument:[self document]];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)removeURLGroup:(BDSKURLGroup *)group {
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillAddRemoveGroupNotification object:self];
    
	[[[self undoManager] prepareWithInvocationTarget:self] addURLGroup:group];
    
    [self removeSpinnerForGroup:group];
    
    [group setDocument:nil];
	[urlGroups removeObjectIdenticalTo:group];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)addScriptGroup:(BDSKScriptGroup *)group {
	[[[self undoManager] prepareWithInvocationTarget:self] removeScriptGroup:group];
    
	[scriptGroups addObject:group];
    [group setDocument:[self document]];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)removeScriptGroup:(BDSKScriptGroup *)group {
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillAddRemoveGroupNotification object:self];
    
	[[[self undoManager] prepareWithInvocationTarget:self] addScriptGroup:group];
    
    [self removeSpinnerForGroup:group];
    
    [group setDocument:nil];
	[scriptGroups removeObjectIdenticalTo:group];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)addSearchGroup:(BDSKSearchGroup *)group {
	[searchGroups addObject:group];
    [group setDocument:[self document]];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)removeSearchGroup:(BDSKSearchGroup *)group {
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillAddRemoveGroupNotification object:self];
    
    [self removeSpinnerForGroup:group];
    
    [group setDocument:nil];
	[searchGroups removeObjectIdenticalTo:group];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)addSmartGroup:(BDSKSmartGroup *)group {
	[[[self undoManager] prepareWithInvocationTarget:self] removeSmartGroup:group];
    
    // update the count
	[group filterItems:[document publications]];
	
	[smartGroups addObject:group];
    [group setDocument:[self document]];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)removeSmartGroup:(BDSKSmartGroup *)group {
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillAddRemoveGroupNotification object:self];
    
	[[[self undoManager] prepareWithInvocationTarget:self] addSmartGroup:group];
	
    [group setDocument:nil];
	[smartGroups removeObjectIdenticalTo:group];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)addStaticGroup:(BDSKStaticGroup *)group {
	[[[self undoManager] prepareWithInvocationTarget:self] removeStaticGroup:group];
	
    [group setDocument:[self document]];
    [self updateStaticGroupsIfNeeded];
    [staticGroups addObject:group];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}

- (void)removeStaticGroup:(BDSKStaticGroup *)group {
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillAddRemoveGroupNotification object:self];
    
	[[[self undoManager] prepareWithInvocationTarget:self] addStaticGroup:group];
	
    [group setDocument:nil];
    [self updateStaticGroupsIfNeeded];
    [staticGroups removeObjectIdenticalTo:group];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDidAddRemoveGroupNotification object:self];
}
 
- (void)setCategoryGroups:(NSArray *)array{
    if(categoryGroups != array){
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillAddRemoveGroupNotification object:self];
        
        // try to preserve the unique ID when we regenerate the groups
        if ([[[array lastObject] key] isEqualToString:[[categoryGroups lastObject] key]])
            [self duplicateUniqueIDsFromGroups:categoryGroups toGroups:array];
        
        [categoryGroups makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
        [categoryGroups release];
        categoryGroups = [array mutableCopy]; 
        [categoryGroups makeObjectsPerformSelector:@selector(setDocument:) withObject:[self document]];
    }
}

// this should only be used just before reading from file, in particular revert, so we shouldn't make this undoable
- (void)removeAllNonSharedGroups {
    [self performSelector:@selector(removeSpinnerForGroup:) withObjectsFromArray:urlGroups];
    [self performSelector:@selector(removeSpinnerForGroup:) withObjectsFromArray:scriptGroups];
    
    [lastImportGroup setPublications:[NSArray array]];
    [urlGroups makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
    [urlGroups removeAllObjects];
    [scriptGroups makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
    [scriptGroups removeAllObjects];
    [searchGroups makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
    [searchGroups removeAllObjects];
    [staticGroups makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
    [staticGroups removeAllObjects];
    [smartGroups makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
    [smartGroups removeAllObjects];
    [staticGroups makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
    [staticGroups removeAllObjects];
    [categoryGroups makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
    [categoryGroups removeAllObjects];
}

#pragma mark Document

- (BibDocument *)document{
    return document;
}

#pragma mark Spinners

- (NSProgressIndicator *)spinnerForGroup:(BDSKGroup *)group{
    NSProgressIndicator *spinner = [spinners objectForKey:group];
    
    if(spinner == nil && [group isRetrieving]){
        if(spinners == nil)
            spinners = [[NSMutableDictionary alloc] initWithCapacity:5];
        spinner = [[NSProgressIndicator alloc] init];
        [spinner setControlSize:NSSmallControlSize];
        [spinner setStyle:NSProgressIndicatorSpinningStyle];
        [spinner setDisplayedWhenStopped:NO];
        [spinner sizeToFit];
        [spinner setUsesThreadedAnimation:YES];
        [spinners setObject:spinner forKey:group];
        [spinner release];
    }
    if(spinner){
        if ([group isRetrieving])
            [spinner startAnimation:nil];
        else
            [spinner stopAnimation:nil];
    }
    
    return spinner;
}

- (void)removeSpinnerForGroup:(BDSKGroup *)group{
    NSProgressIndicator *spinner = [spinners objectForKey:group];
    if(spinner){
        [spinner stopAnimation:nil];
        [spinner removeFromSuperview];
        [spinners removeObjectForKey:group];
    }
}

#pragma mark Sorting

- (void)sortUsingDescriptors:(NSArray *)sortDescriptors{
    BDSKGroup *emptyGroup = nil;
    
    if ([categoryGroups count] > 0) {
        id firstName = [[categoryGroups objectAtIndex:0] name];
        if ([firstName isEqual:@""] || [firstName isEqual:[BibAuthor emptyAuthor]]) {
            emptyGroup = [[categoryGroups objectAtIndex:0] retain];
            [categoryGroups removeObjectAtIndex:0];
        }
    }
    
    [self updateStaticGroupsIfNeeded];
    
    // we don't sort serachGroups, as their names change and the order-as-added can be useful to track them
    
    [sharedGroups sortUsingDescriptors:sortDescriptors];
    [urlGroups sortUsingDescriptors:sortDescriptors];
    [scriptGroups sortUsingDescriptors:sortDescriptors];
    [smartGroups sortUsingDescriptors:sortDescriptors];
    [staticGroups sortUsingDescriptors:sortDescriptors];
    [categoryGroups sortUsingDescriptors:sortDescriptors];
	
    if (emptyGroup != nil) {
        [categoryGroups insertObject:emptyGroup atIndex:0];
        [emptyGroup release];
    }
}

#pragma mark Serializing

- (void)setGroupsOfType:(int)groupType fromSerializedData:(NSData *)data {
	NSString *error = nil;
	NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
	id plist = [NSPropertyListSerialization propertyListFromData:data
												mutabilityOption:NSPropertyListImmutable
														  format:&format 
												errorDescription:&error];
	
	if (error) {
		NSLog(@"Error deserializing: %@", error);
        [error release];
		return;
	}
	if ([plist isKindOfClass:[NSArray class]] == NO) {
		NSLog(@"Serialized groups was no array.");
		return;
	}
	
    Class groupClass = Nil;
    NSMutableArray *groupArray = nil;
    
    if (groupType == BDSKSmartGroupType) {
        groupClass = [BDSKSmartGroup class];
        groupArray = smartGroups;
	} else if (groupType == BDSKStaticGroupType) {
        [tmpStaticGroups release]; // just to be sure, for revert
        tmpStaticGroups = [plist retain];
	} else if (groupType == BDSKURLGroupType) {
        groupClass = [BDSKURLGroup class];
        groupArray = urlGroups;
	} else if (groupType == BDSKScriptGroupType) {
        groupClass = [BDSKScriptGroup class];
        groupArray = scriptGroups;
    }
    
    if (groupClass && groupArray) {
        NSEnumerator *groupEnum = [plist objectEnumerator];
        NSDictionary *groupDict;
        NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:[(NSArray *)plist count]];
        BDSKGroup *group = nil;
        
        while (groupDict = [groupEnum nextObject]) {
            @try {
                group = [[groupClass alloc] initWithDictionary:groupDict];
                [group setDocument:[self document]];
                [array addObject:group];
            }
            @catch(id exception) {
                NSLog(@"Ignoring exception \"%@\" while parsing group data.", exception);
            }
            @finally {
                [group release];
                group = nil;
            }
        }
        
        [groupArray setArray:array];
        [array release];
    }
}

- (NSData *)serializedGroupsDataOfType:(int)groupType {
    Class groupClass = Nil;
    NSMutableArray *groupArray = nil;
    
    if (groupType == BDSKSmartGroupType) {
        groupClass = [BDSKSmartGroup class];
        groupArray = smartGroups;
	} else if (groupType == BDSKStaticGroupType) {
        groupClass = [BDSKStaticGroup class];
        groupArray = staticGroups;
	} else if (groupType == BDSKURLGroupType) {
        groupClass = [BDSKURLGroup class];
        groupArray = urlGroups;
	} else if (groupType == BDSKScriptGroupType) {
        groupClass = [BDSKScriptGroup class];
        groupArray = scriptGroups;
    }
    
    NSData *data = nil;
    
    if (groupClass && groupArray) {
        NSArray *array = [groupArray arrayByPerformingSelector:@selector(dictionaryValue)];
        
        NSString *error = nil;
        NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
        data = [NSPropertyListSerialization dataFromPropertyList:array
                                                          format:format 
                                                errorDescription:&error];
            
        if (error) {
            NSLog(@"Error serializing: %@", error);
            [error release];
            return nil;
        }
	}
    return data;
}

@end


@implementation BDSKGroupsArray (Private)

- (void)updateStaticGroupsIfNeeded{
    if (tmpStaticGroups == nil) 
        return;
    
    NSEnumerator *groupEnum = [tmpStaticGroups objectEnumerator];
    NSDictionary *groupDict;
    BDSKStaticGroup *group = nil;
    NSMutableArray *pubArray = nil;
    NSString *name;
    NSArray *keys;
    NSEnumerator *keyEnum;
    NSString *key;
    
    [staticGroups removeAllObjects];
    
    while (groupDict = [groupEnum nextObject]) {
        @try {
            name = [[groupDict objectForKey:@"group name"] stringByUnescapingGroupPlistEntities];
            keys = [[groupDict objectForKey:@"keys"] componentsSeparatedByString:@","];
            keyEnum = [keys objectEnumerator];
            pubArray = [[NSMutableArray alloc] initWithCapacity:[keys count]];
            while (key = [keyEnum nextObject]) 
                [pubArray addObjectsFromArray:[[document publications] allItemsForCiteKey:key]];
            group = [[BDSKStaticGroup alloc] initWithName:name publications:pubArray];
            [group setDocument:[self document]];
            [staticGroups addObject:group];
        }
        @catch(id exception) {
            NSLog(@"Ignoring exception \"%@\" while parsing static groups data.", exception);
        }
        @finally {
            [group release];
            group = nil;
            [pubArray release];
            pubArray = nil;
        }
    }
    
    [tmpStaticGroups release];
    tmpStaticGroups = nil;
}

- (NSUndoManager *)undoManager {
    return [document undoManager];
}

@end

//
//  BDSKGroupsArray.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/10/06.
/*
 This software is Copyright (c) 2006
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
#import "BDSKSmartGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKCategoryGroup.h"
#import "BDSKPublicationsArray.h"
#import "BibAuthor.h"


@implementation BDSKGroupsArray 

- (id)init {
    if(self = [super init]) {
        allPublicationsGroup = [[BDSKGroup alloc] initWithAllPublications];
        lastImportGroup = nil;
        sharedGroups = [[NSMutableArray alloc] init];
        urlGroups = [[NSMutableArray alloc] init];
        scriptGroups = [[NSMutableArray alloc] init];
        smartGroups = [[NSMutableArray alloc] init];
        staticGroups = nil;
        tmpStaticGroups = nil;
        categoryGroups = nil;
    }
    return self;
}

- (void)dealloc {
    [allPublicationsGroup release];
    [lastImportGroup release];
    [sharedGroups release];
    [urlGroups release];
    [scriptGroups release];
    [smartGroups release];
    [staticGroups release];
    [tmpStaticGroups release];
    [categoryGroups release];
    [super dealloc];
}

- (unsigned int)count {
    return [sharedGroups count] + [urlGroups count] + [scriptGroups count] + [smartGroups count] + [[self staticGroups] count] + [categoryGroups count] + ([lastImportGroup count] ? 2 : 1) /* add 1 for all publications group */ ;
}

- (id)objectAtIndex:(unsigned int)index {
    unsigned int count;
    
    if (index == 0)
		return allPublicationsGroup;
    index -= 1;
    
    if ([lastImportGroup count] != 0) {
        if (index == 0)
            return lastImportGroup;
        index -= 1;
    }
    
    count = [sharedGroups count];
    if (index < count)
        return [sharedGroups objectAtIndex:index];
    index -= count;
    
    count = [urlGroups count];
    if (index < count)
        return [urlGroups objectAtIndex:index];
    index -= count;
    
    count = [scriptGroups count];
    if (index < count)
        return [scriptGroups objectAtIndex:index];
    index -= count;
    
	count = [smartGroups count];
    if (index < count)
		return [smartGroups objectAtIndex:index];
    index -= count;
    
    count = [[self staticGroups] count];
    if (index < count)
        return [[self staticGroups] objectAtIndex:index];
    index -= count;
    
    return [categoryGroups objectAtIndex:index];
}

#pragma mark Subarray Accessors

- (BDSKGroup *)allPublicationsGroup{
    return allPublicationsGroup;
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

- (NSArray *)smartGroups{
    return sharedGroups;
}

- (NSArray *)staticGroups{
    if (staticGroups == nil) {
        staticGroups = [[NSMutableArray alloc] init];
        
        NSEnumerator *groupEnum = [tmpStaticGroups objectEnumerator];
        NSDictionary *groupDict;
        BDSKStaticGroup *group = nil;
        NSMutableArray *pubArray = nil;
        NSString *name;
        NSArray *keys;
        NSEnumerator *keyEnum;
        NSString *key;
        
        while (groupDict = [groupEnum nextObject]) {
            @try {
                name = [[groupDict objectForKey:@"group name"] stringByUnescapingGroupPlistEntities];
                keys = [[groupDict objectForKey:@"keys"] componentsSeparatedByString:@","];
                keyEnum = [keys objectEnumerator];
                pubArray = [[NSMutableArray alloc] initWithCapacity:[keys count]];
                while (key = [keyEnum nextObject]) 
                    [pubArray addObjectsFromArray:[[document publications] allItemsForCiteKey:key]];
                group = [[BDSKStaticGroup alloc] initWithName:name publications:pubArray];
                [group setUndoManager:[self undoManager]];
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
    return staticGroups;
}

- (NSArray *)categoryGroups{
    return categoryGroups;
}

#pragma mark Index ranges of groups

- (NSRange)rangeOfSharedGroups{
    return NSMakeRange([lastImportGroup count] == 0 ? 1 : 2, [sharedGroups count]);
}

- (NSRange)rangeOfURLGroups{
    return NSMakeRange(NSMaxRange([self rangeOfSharedGroups]), [urlGroups count]);
}

- (NSRange)rangeOfScriptGroups{
    return NSMakeRange(NSMaxRange([self rangeOfURLGroups]), [scriptGroups count]);
}

- (NSRange)rangeOfSmartGroups{
    return NSMakeRange(NSMaxRange([self rangeOfScriptGroups]), [smartGroups count]);
}

- (NSRange)rangeOfStaticGroups{
    return NSMakeRange(NSMaxRange([self rangeOfSmartGroups]), [[self staticGroups] count]);
}

- (NSRange)rangeOfCategoryGroups{
    return NSMakeRange(NSMaxRange([self rangeOfStaticGroups]), [categoryGroups count]);
}

- (unsigned int)numberOfSharedGroupsAtIndexes:(NSIndexSet *)indexes{
    NSRange sharedRange = [self rangeOfSharedGroups];
    unsigned int maxCount = MIN([indexes count], sharedRange.length);
    unsigned int buffer[maxCount];
    return [indexes getIndexes:buffer maxCount:maxCount inIndexRange:&sharedRange];
}

- (unsigned int)numberOfURLGroupsAtIndexes:(NSIndexSet *)indexes{
    NSRange urlRange = [self rangeOfURLGroups];
    unsigned int maxCount = MIN([indexes count], urlRange.length);
    unsigned int buffer[maxCount];
    return [indexes getIndexes:buffer maxCount:maxCount inIndexRange:&urlRange];
}

- (unsigned int)numberOfScriptGroupsAtIndexes:(NSIndexSet *)indexes{
    NSRange scriptRange = [self rangeOfScriptGroups];
    unsigned int maxCount = MIN([indexes count], scriptRange.length);
    unsigned int buffer[maxCount];
    return [indexes getIndexes:buffer maxCount:maxCount inIndexRange:&scriptRange];
}

- (unsigned int)numberOfSmartGroupsAtIndexes:(NSIndexSet *)indexes{
    NSRange smartRange = [self rangeOfSmartGroups];
    unsigned int maxCount = MIN([indexes count], smartRange.length);
    unsigned int buffer[maxCount];
    return [indexes getIndexes:buffer maxCount:maxCount inIndexRange:&smartRange];
}

- (unsigned int)numberOfStaticGroupsAtIndexes:(NSIndexSet *)indexes{
    NSRange staticRange = [self rangeOfStaticGroups];
    unsigned int maxCount = MIN([indexes count], staticRange.length);
    unsigned int buffer[maxCount];
    return [indexes getIndexes:buffer maxCount:maxCount inIndexRange:&staticRange];
}

- (unsigned int)numberOfCategoryGroupsAtIndexes:(NSIndexSet *)indexes{
    NSRange categoryRange = [self rangeOfCategoryGroups];
    unsigned int maxCount = MIN([indexes count], categoryRange.length);
    unsigned int buffer[maxCount];
    return [indexes getIndexes:buffer maxCount:maxCount inIndexRange:&categoryRange];
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
    return [self hasSharedGroupsAtIndexes:indexes] || [self hasURLGroupsAtIndexes:indexes] || [self hasScriptGroupsAtIndexes:indexes];
}

#pragma mark Mutable accessors

- (void)setLastImportedPublications:(NSArray *)pubs{
    if(lastImportGroup == nil)
        lastImportGroup = [[BDSKStaticGroup alloc] initWithLastImport:pubs];
    else 
        [lastImportGroup setPublications:pubs];
}

- (void)setSharedGroups:(NSArray *)array{
    if(sharedGroups != array){
       [sharedGroups release];
       sharedGroups = [array mutableCopy]; 
    }
}

- (void)addURLGroup:(BDSKURLGroup *)group {
	[[[self undoManager] prepareWithInvocationTarget:self] removeURLGroup:group];
    
	[urlGroups addObject:group];
	[group setUndoManager:[self undoManager]];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKAddRemoveGroupNotification object:self];
}

- (void)removeURLGroup:(BDSKURLGroup *)group {
	[[[self undoManager] prepareWithInvocationTarget:self] addURLGroup:group];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillRemoveExternalGroupNotification object:self];
    
	[group setUndoManager:nil];
	[urlGroups removeObjectIdenticalTo:group];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKAddRemoveGroupNotification object:self];
}

- (void)addScriptGroup:(BDSKScriptGroup *)group {
	[[[self undoManager] prepareWithInvocationTarget:self] removeScriptGroup:group];
    
	[scriptGroups addObject:group];
	[group setUndoManager:[self undoManager]];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKAddRemoveGroupNotification object:self];
}

- (void)removeScriptGroup:(BDSKScriptGroup *)group {
	[[[self undoManager] prepareWithInvocationTarget:self] addScriptGroup:group];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKWillRemoveExternalGroupNotification object:self];
    
	[group setUndoManager:nil];
	[scriptGroups removeObjectIdenticalTo:group];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKAddRemoveGroupNotification object:self];
}

- (void)addSmartGroup:(BDSKSmartGroup *)group {
	[[[self undoManager] prepareWithInvocationTarget:self] removeSmartGroup:group];
    
    // update the count
	[group filterItems:[document publications]];
	
	[smartGroups addObject:group];
	[group setUndoManager:[self undoManager]];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKAddRemoveGroupNotification object:self];
}

- (void)removeSmartGroup:(BDSKSmartGroup *)group {
	[[[self undoManager] prepareWithInvocationTarget:self] addSmartGroup:group];
	
	[group setUndoManager:nil];
	[smartGroups removeObjectIdenticalTo:group];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKAddRemoveGroupNotification object:self];
}

- (void)addStaticGroup:(BDSKStaticGroup *)group {
	[[[self undoManager] prepareWithInvocationTarget:self] removeStaticGroup:group];
	
	[group setUndoManager:[self undoManager]];
	[self staticGroups];
    [staticGroups addObject:group];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKAddRemoveGroupNotification object:self];
}

- (void)removeStaticGroup:(BDSKStaticGroup *)group {
	[[[self undoManager] prepareWithInvocationTarget:self] addStaticGroup:group];
	
	[group setUndoManager:nil];
	[self staticGroups];
    [staticGroups removeObjectIdenticalTo:group];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKAddRemoveGroupNotification object:self];
}

- (void)setTmpStaticGroups:(NSArray *)array{
    if(tmpStaticGroups != array){
        [tmpStaticGroups release];
        tmpStaticGroups = [array retain];
    }
    [staticGroups release];
    staticGroups = nil;
}

- (void)setCategoryGroups:(NSArray *)array{
    if(categoryGroups != array){
       [categoryGroups release];
       categoryGroups = [array mutableCopy]; 
    }
}

#pragma mark Document and UndoManager

- (BibDocument *)document{
    return document;
}

- (void)setDocument:(BibDocument *)newDocument{
    document = newDocument;
}

- (NSUndoManager *)undoManager {
    return [document undoManager];
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
    
    [sharedGroups sortUsingDescriptors:sortDescriptors];
    [urlGroups sortUsingDescriptors:sortDescriptors];
    [scriptGroups sortUsingDescriptors:sortDescriptors];
    [smartGroups sortUsingDescriptors:sortDescriptors];
    [self staticGroups];
    [staticGroups sortUsingDescriptors:sortDescriptors];
    [categoryGroups sortUsingDescriptors:sortDescriptors];
	
    if (emptyGroup != nil) {
        [categoryGroups insertObject:emptyGroup atIndex:0];
        [emptyGroup release];
    }
}

#pragma mark Serializing

- (void)setSmartGroupsFromSerializedData:(NSData *)data {
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
		NSLog(@"Serialized smart groups was no array.");
		return;
	}
	
    NSEnumerator *groupEnum = [plist objectEnumerator];
    NSDictionary *groupDict;
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[(NSArray *)plist count]];
    BDSKSmartGroup *group = nil;
    BDSKFilter *filter = nil;
    
    while (groupDict = [groupEnum nextObject]) {
        @try {
            filter = [[BDSKFilter alloc] initWithDictionary:groupDict];
            group = [[BDSKSmartGroup alloc] initWithName:[groupDict objectForKey:@"group name"] count:0 filter:filter];
            [group setUndoManager:[self undoManager]];
            [array addObject:group];
        }
        @catch(id exception) {
            NSLog(@"Ignoring exception \"%@\" while parsing smart groups data.", exception);
        }
        @finally {
            [group release];
            group = nil;
            [filter release];
            filter = nil;
        }
    }
	
	[smartGroups setArray:array];
}

- (void)setStaticGroupsFromSerializedData:(NSData *)data {
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
		NSLog(@"Serialized static groups was no array.");
		return;
	}
	
    tmpStaticGroups = [plist retain];
}

- (void)setURLGroupsFromSerializedData:(NSData *)data {
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
		NSLog(@"Serialized URL groups was no array.");
		return;
	}
	
    NSString *name = nil;
    NSURL *url = nil;
    NSEnumerator *groupEnum = [plist objectEnumerator];
    NSDictionary *groupDict;
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[(NSArray *)plist count]];
    BDSKURLGroup *group = nil;
    
    while (groupDict = [groupEnum nextObject]) {
        @try {
            name = [[groupDict objectForKey:@"group name"] stringByUnescapingGroupPlistEntities];
            url = [NSURL URLWithString:[groupDict objectForKey:@"URL"]];
            group = [[BDSKURLGroup alloc] initWithName:name URL:url];
            [group setUndoManager:[self undoManager]];
            [array addObject:group];
        }
        @catch(id exception) {
            NSLog(@"Ignoring exception \"%@\" while parsing URL groups data.", exception);
        }
        @finally {
            [group release];
            group = nil;
        }
    }
	
	[urlGroups setArray:array];
}

- (void)setScriptGroupsFromSerializedData:(NSData *)data {
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
		NSLog(@"Serialized URL groups was no array.");
		return;
	}
	
    NSString *name = nil;
    NSString *path = nil;
    NSString *arguments = nil;
    int type;
    NSEnumerator *groupEnum = [plist objectEnumerator];
    NSDictionary *groupDict;
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[(NSArray *)plist count]];
    BDSKScriptGroup *group = nil;
    
    while (groupDict = [groupEnum nextObject]) {
        @try {
            name = [[groupDict objectForKey:@"group name"] stringByUnescapingGroupPlistEntities];
            path = [[groupDict objectForKey:@"script path"] stringByUnescapingGroupPlistEntities];
            arguments = [groupDict objectForKey:@"script arguments"];
            if ([arguments isKindOfClass:[NSArray class]]) // legacy
                arguments = [(NSArray *)arguments componentsJoinedByString:@" "];
            arguments = [arguments stringByUnescapingGroupPlistEntities];
            type = [[groupDict objectForKey:@"script type"] intValue];
            group = [[BDSKScriptGroup alloc] initWithName:name scriptPath:path scriptArguments:arguments scriptType:type];
            [group setName:[groupDict objectForKey:@"group name"]];
            [group setUndoManager:[self undoManager]];
            [array addObject:group];
        }
        @catch(id exception) {
            NSLog(@"Ignoring exception \"%@\" while parsing URL groups data.", exception);
        }
        @finally {
            [group release];
            group = nil;
        }
    }
	
	[scriptGroups setArray:array];
}

- (NSData *)serializedSmartGroupsData {
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[smartGroups count]];
    NSString *name;
    NSMutableDictionary *groupDict;
	NSEnumerator *groupEnum = [smartGroups objectEnumerator];
	BDSKSmartGroup *group;
	
	while (group = [groupEnum nextObject]) {
        name = [[group stringValue] stringByEscapingGroupPlistEntities];
		groupDict = [[[group filter] dictionaryValue] mutableCopy];
		[groupDict setObject:name forKey:@"group name"];
		[array addObject:groupDict];
		[groupDict release];
	}
	
	NSString *error = nil;
	NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
	NSData *data = [NSPropertyListSerialization dataFromPropertyList:array
															  format:format 
													errorDescription:&error];
    	
	if (error) {
		NSLog(@"Error serializing: %@", error);
        [error release];
		return nil;
	}
	return data;
}

- (NSData *)serializedStaticGroupsData {
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[[self staticGroups] count]];
	NSString *keys;
    NSString *name;
    NSDictionary *groupDict;
	NSEnumerator *groupEnum = [[self staticGroups] objectEnumerator];
	BDSKStaticGroup *group;
	
	while (group = [groupEnum nextObject]) {
        name = [[group stringValue] stringByEscapingGroupPlistEntities];
		keys = [[[group publications] valueForKeyPath:@"@distinctUnionOfObjects.citeKey"] componentsJoinedByString:@","];
        groupDict = [[NSDictionary alloc] initWithObjectsAndKeys:name, @"group name", keys, @"keys", nil];
		[array addObject:groupDict];
		[groupDict release];
	}
	
	NSString *error = nil;
	NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
	NSData *data = [NSPropertyListSerialization dataFromPropertyList:array
															  format:format 
													errorDescription:&error];
    	
	if (error) {
		NSLog(@"Error serializing: %@", error);
        [error release];
		return nil;
	}
	return data;
}

- (NSData *)serializedURLGroupsData {
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[urlGroups count]];
    NSString *name;
    NSString *url;
    NSDictionary *groupDict;
	NSEnumerator *groupEnum = [urlGroups objectEnumerator];
	BDSKURLGroup *group;
	
	while (group = [groupEnum nextObject]) {
        name = [[group stringValue] stringByEscapingGroupPlistEntities];
        url = [[group URL] absoluteString];
        groupDict = [[NSDictionary alloc] initWithObjectsAndKeys:name, @"group name", url, @"URL", nil];
		[array addObject:groupDict];
		[groupDict release];
	}
	
	NSString *error = nil;
	NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
	NSData *data = [NSPropertyListSerialization dataFromPropertyList:array
															  format:format 
													errorDescription:&error];
    	
	if (error) {
		NSLog(@"Error serializing: %@", error);
        [error release];
		return nil;
	}
	return data;
}

- (NSData *)serializedScriptGroupsData {
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[urlGroups count]];
    NSString *name;
    NSString *path;
    NSString *args;
    NSNumber *type;
    NSDictionary *groupDict;
	NSEnumerator *groupEnum = [scriptGroups objectEnumerator];
	BDSKScriptGroup *group;
	
	while (group = [groupEnum nextObject]) {
        name = [[group stringValue] stringByEscapingGroupPlistEntities];
        path = [[group scriptPath] stringByEscapingGroupPlistEntities];
        args = [[group scriptArguments] stringByEscapingGroupPlistEntities];
        type = [NSNumber numberWithInt:[group scriptType]];
        groupDict = [[NSDictionary alloc] initWithObjectsAndKeys:name, @"group name", path, @"script path", args, @"script arguments", type, @"script type", nil];
		[array addObject:groupDict];
		[groupDict release];
	}
	
	NSString *error = nil;
	NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
	NSData *data = [NSPropertyListSerialization dataFromPropertyList:array
															  format:format 
													errorDescription:&error];
    	
	if (error) {
		NSLog(@"Error serializing: %@", error);
        [error release];
		return nil;
	}
	return data;
}

@end

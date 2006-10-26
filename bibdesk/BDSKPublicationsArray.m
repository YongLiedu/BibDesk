//
//  BDSKPublicationsArray.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/25/06.
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

#import "BDSKPublicationsArray.h"
#import "BDSKCountedSet.h"
#import "BibItem.h"
#import "BibAuthor.h"
#import <OmniFoundation/OFMultiValueDictionary.h>
#import <OmniFoundation/NSString-OFExtensions.h>


@interface BDSKPublicationsArray (Private)
- (void)addToItemsForCiteKeys:(BibItem *)item;
- (void)removeFromItemsForCiteKeys:(BibItem *)item;
@end


@implementation BDSKPublicationsArray

#pragma mark NSMutableArray primitive methods

- (id)initWithObjects:(id *)objects count:(unsigned)count;
{
    if (self = [super init]) {
        publications = [[NSMutableArray alloc] initWithObjects:objects count:count];
        itemsForCiteKeys = [[OFMultiValueDictionary alloc] initWithKeyCallBacks:&BDSKCaseInsensitiveStringKeyDictionaryCallBacks];
        NSEnumerator *itemEnum = [publications objectEnumerator];
        BibItem *item;
        while(item = [itemEnum nextObject])
            [self addToItemsForCiteKeys:item];
    }
    return self;
}

- (id)initWithCapacity:(unsigned)numItems;
{
    if (self = [super init]) {
        publications = [[NSMutableArray alloc] initWithCapacity:numItems];
        itemsForCiteKeys = [[OFMultiValueDictionary alloc] initWithKeyCallBacks:&BDSKCaseInsensitiveStringKeyDictionaryCallBacks];
    }
    return self;
}

- (void)dealloc{
    [publications release];
    [itemsForCiteKeys release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone;
{
    return [publications copyWithZone:zone];
}

- (id)mutableCopyWithZone:(NSZone *)zone;
{
    return [publications mutableCopyWithZone:zone];
}

- (unsigned)count;
{
    return [publications count];
}

- (id)objectAtIndex:(unsigned)index;
{
    return [publications objectAtIndex:index];
}

- (void)addObject:(id)anObject;
{
    [publications addObject:anObject];
    [self addToItemsForCiteKeys:anObject];
}

- (void)insertObject:(id)anObject atIndex:(unsigned)index;
{
    [publications insertObject:anObject atIndex:index];
    [self addToItemsForCiteKeys:anObject];
}

- (void)removeLastObject;
{
    id lastObject = [publications lastObject];
    if(lastObject){
        [self removeFromItemsForCiteKeys:lastObject];
        [publications removeLastObject];
    }
}

- (void)removeObjectAtIndex:(unsigned)index;
{
    [self removeFromItemsForCiteKeys:[publications objectAtIndex:index]];
    [publications removeObjectAtIndex:index];
}

- (void)replaceObjectAtIndex:(unsigned)index withObject:(id)anObject;
{
    [self removeFromItemsForCiteKeys:[publications objectAtIndex:index]];
    [publications replaceObjectAtIndex:index withObject:anObject];
    [self addToItemsForCiteKeys:anObject];
}

#pragma mark Itmes for cite keys

- (void)addToItemsForCiteKeys:(BibItem *)item;
{
    [itemsForCiteKeys addObject:item forKey:[item citeKey]];
}

- (void)removeFromItemsForCiteKeys:(BibItem *)item{
    [itemsForCiteKeys removeObject:item forKey:[item citeKey]];
}

- (void)changeCiteKey:(NSString *)oldKey toCiteKey:(NSString *)newKey forItem:(BibItem *)anItem;
{
    [itemsForCiteKeys removeObject:anItem forKey:oldKey];
    [itemsForCiteKeys addObject:anItem forKey:newKey];
}

- (BibItem *)itemForCiteKey:(NSString *)key;
{
	if ([NSString isEmptyString:key]) 
		return nil;
    
	NSArray *items = [itemsForCiteKeys arrayForKey:key];
	
	if ([items count] == 0)
		return nil;
    // may have duplicate items for the same key, so just return the first one
    return [items objectAtIndex:0];
}

- (NSArray *)allItemsForCiteKey:(NSString *)key;
{
	NSArray *items = nil;
    if ([NSString isEmptyString:key] == NO) 
		items = [itemsForCiteKeys arrayForKey:key];
    return (items == nil) ? [NSArray array] : items;
}

- (BOOL)citeKeyIsUsed:(NSString *)key byItemOtherThan:(BibItem *)anItem;
{
    NSArray *items = [itemsForCiteKeys arrayForKey:key];
    
	if ([items count] > 1)
		return YES;
	if ([items count] == 1 && [items objectAtIndex:0] != anItem)	
		return YES;
	return NO;
}

#pragma mark Crossref support

- (BOOL)citeKeyIsCrossreffed:(NSString *)key;
{
	if ([NSString isEmptyString:key]) 
		return NO;
    
	NSEnumerator *pubEnum = [publications objectEnumerator];
	BibItem *pub;
	
	while (pub = [pubEnum nextObject]) {
		if ([key caseInsensitiveCompare:[pub valueOfField:BDSKCrossrefString inherit:NO]] == NSOrderedSame) {
			return YES;
        }
	}
	return NO;
}

#pragma mark Authors support

- (NSArray *)itemsForAuthor:(BibAuthor *)anAuthor;
{
    NSMutableSet *auths = BDSKCreateFuzzyAuthorCompareMutableSet();
    NSEnumerator *pubEnum = [publications objectEnumerator];
    BibItem *bi;
    NSMutableArray *anAuthorPubs = [NSMutableArray array];
    
    while(bi = [pubEnum nextObject]){
        [auths addObjectsFromArray:[bi pubAuthors]];
        if([auths containsObject:anAuthor]){
            [anAuthorPubs addObject:bi];
        }
        [auths removeAllObjects];
    }
    [auths release];
    return anAuthorPubs;
}

@end

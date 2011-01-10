//
//  BDSKPublicationsArray.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/25/06.
/*
 This software is Copyright (c) 2006-2011
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
#import "BDSKMultiValueDictionary.h"
#import "BibItem.h"
#import "BibAuthor.h"
#import "NSString_BDSKExtensions.h"


@interface BDSKPublicationsArray (Private)
- (void)addToItemsForCiteKeys:(BibItem *)item;
- (void)removeFromItemsForCiteKeys:(BibItem *)item;
- (void)updateFileOrder;
@end


@implementation BDSKPublicationsArray

#pragma mark Init, dealloc overrides

- (id)init;
{
    if (self = [super init]) {
        NSZone *zone = [self zone];
        publications = [[NSMutableArray allocWithZone:zone] init];
        itemsForCiteKeys = [[BDSKMultiValueDictionary allocWithZone:zone] initWithCaseInsensitiveKeys:YES];
        itemsForIdentifierURLs = [[NSMutableDictionary allocWithZone:zone] init];
    }
    return self;
}

// custom initializers should be explicitly defined in concrete subclasses to be supported, we should not rely on inheritance
- (id)initWithArray:(NSArray *)anArray;
{
    if (self = [super init]) {
        NSZone *zone = [self zone];
        publications = [[NSMutableArray allocWithZone:zone] initWithArray:anArray];
        itemsForCiteKeys = [[BDSKMultiValueDictionary allocWithZone:zone] initWithCaseInsensitiveKeys:YES];
        itemsForIdentifierURLs = [[NSMutableDictionary allocWithZone:zone] init];
        for (BibItem *pub in publications)
            [self addToItemsForCiteKeys:pub];
        [self updateFileOrder];
    }
    return self;
}

- (void)dealloc{
    BDSKDESTROY(publications);
    BDSKDESTROY(itemsForCiteKeys);
    BDSKDESTROY(itemsForIdentifierURLs);
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)aZone {
    return [publications copyWithZone:aZone];
}

- (id)mutableCopyWithZone:(NSZone *)aZone {
    return [publications mutableCopyWithZone:aZone];
}

#pragma mark NSMutableArray primitive methods

- (NSUInteger)count;
{
    return [publications count];
}

- (id)objectAtIndex:(NSUInteger)idx;
{
    return [publications objectAtIndex:idx];
}

- (void)addObject:(id)anObject;
{
    [publications addObject:anObject];
    [self addToItemsForCiteKeys:anObject];
    [anObject setFileOrder:[NSNumber numberWithInteger:[publications count]]];
}

- (void)insertObject:(id)anObject atIndex:(NSUInteger)idx;
{
    [publications insertObject:anObject atIndex:idx];
    [self addToItemsForCiteKeys:anObject];
    [self updateFileOrder];
}

- (void)removeLastObject;
{
    id lastObject = [publications lastObject];
    if(lastObject){
        [self removeFromItemsForCiteKeys:lastObject];
        [publications removeLastObject];
    }
}

- (void)removeObjectAtIndex:(NSUInteger)idx;
{
    [self removeFromItemsForCiteKeys:[publications objectAtIndex:idx]];
    [publications removeObjectAtIndex:idx];
    [self updateFileOrder];
}

- (void)replaceObjectAtIndex:(NSUInteger)idx withObject:(id)anObject;
{
    BibItem *oldObject = [publications objectAtIndex:idx];
    [anObject setFileOrder:[oldObject fileOrder]];
    [self removeFromItemsForCiteKeys:oldObject];
    [publications replaceObjectAtIndex:idx withObject:anObject];
    [self addToItemsForCiteKeys:anObject];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len {
    return [publications countByEnumeratingWithState:state objects:stackbuf count:len];
}

#pragma mark Convenience overrides

- (void)getObjects:(id *)aBuffer range:(NSRange)aRange;
{
    [publications getObjects:aBuffer range:aRange];
}

- (void)removeAllObjects{
    [itemsForCiteKeys removeAllObjects];
    [publications removeAllObjects];
    [itemsForIdentifierURLs removeAllObjects];
}

- (void)addObjectsFromArray:(NSArray *)otherArray{
    [publications addObjectsFromArray:otherArray];
    for (BibItem *pub in publications)
        [self addToItemsForCiteKeys:pub];
    [self updateFileOrder];
}

- (void)insertObjects:(NSArray *)objects atIndexes:(NSIndexSet *)indexes{
    [publications insertObjects:objects atIndexes:indexes];
    for (BibItem *pub in [publications objectsAtIndexes:indexes])
        [self addToItemsForCiteKeys:pub];
    [self updateFileOrder];
}

- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes{
    for (BibItem *pub in [publications objectsAtIndexes:indexes])
        [self removeFromItemsForCiteKeys:pub];
    [publications removeObjectsAtIndexes:indexes];
    [self updateFileOrder];
}

- (void)setArray:(NSArray *)otherArray{
    [self removeAllObjects];
    [self addObjectsFromArray:otherArray];
}

- (NSEnumerator *)objectEnumerator;
{
    return [publications objectEnumerator];
}

#pragma mark Items for cite keys

- (void)changeCiteKey:(NSString *)oldKey toCiteKey:(NSString *)newKey forItem:(BibItem *)anItem;
{
    [itemsForCiteKeys removeObject:anItem forKey:oldKey];
    [itemsForCiteKeys addObject:anItem forKey:newKey];
}

- (BibItem *)itemForCiteKey:(NSString *)key;
{
	if ([NSString isEmptyString:key]) 
		return nil;
    
	NSArray *items = [itemsForCiteKeys allObjectsForKey:key];
	
	if ([items count] == 0)
		return nil;
    // may have duplicate items for the same key, so just return the first one
    return [items objectAtIndex:0];
}

- (NSArray *)allItemsForCiteKey:(NSString *)key;
{
	NSArray *items = nil;
    if ([NSString isEmptyString:key] == NO) 
		items = [itemsForCiteKeys allObjectsForKey:key];
    return items ?: [NSArray array];
}

- (BOOL)citeKeyIsUsed:(NSString *)key byItemOtherThan:(BibItem *)anItem;
{
    NSArray *items = [itemsForCiteKeys allObjectsForKey:key];
    
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
    
	for (BibItem *pub in publications) {
		if ([key isCaseInsensitiveEqual:[pub valueOfField:BDSKCrossrefString inherit:NO]]) {
			return YES;
        }
	}
	return NO;
}

- (id)itemForIdentifierURL:(NSURL *)aURL;
{
    return [itemsForIdentifierURLs objectForKey:aURL];   
}

- (NSArray *)itemsForIdentifierURLs:(NSArray *)anArray;
{
    NSMutableArray *array = [NSMutableArray array];
    BibItem *pub;
    for (NSURL *idURL in anArray) {
        if (pub = [itemsForIdentifierURLs objectForKey:idURL])
            [array addObject:pub];
    }
    return array;
}

#pragma mark Authors support

- (NSArray *)itemsForAuthor:(BibAuthor *)anAuthor;
{
    return [self itemsForPerson:anAuthor forField:BDSKAuthorString];
}

- (NSArray *)itemsForEditor:(BibAuthor *)anEditor;
{
    return [self itemsForPerson:anEditor forField:BDSKEditorString];
}

- (NSArray *)itemsForPerson:(BibAuthor *)aPerson forField:(NSString *)field;
{
    NSMutableSet *auths = [[NSMutableSet alloc] initForFuzzyAuthors];
    NSMutableArray *thePubs = [NSMutableArray array];
    
    for (BibItem *bi in publications) {
        [auths addObjectsFromArray:[bi peopleArrayForField:field]];
        if([auths containsObject:aPerson]){
            [thePubs addObject:bi];
        }
        [auths removeAllObjects];
    }
    [auths release];
    return thePubs;
}

@end


@implementation BDSKPublicationsArray (Private)

- (void)addToItemsForCiteKeys:(BibItem *)item;
{
    [itemsForCiteKeys addObject:item forKey:[item citeKey]];
    [itemsForIdentifierURLs setObject:item forKey:[item identifierURL]];
}

- (void)removeFromItemsForCiteKeys:(BibItem *)item{
    [itemsForCiteKeys removeObject:item forKey:[item citeKey]];
    [itemsForIdentifierURLs removeObjectForKey:[item identifierURL]];
}

- (void)updateFileOrder{
    NSUInteger i, count = [publications count];
    NSInteger fileOrder = 1;
    CFAllocatorRef alloc = CFAllocatorGetDefault();
    for(i = 0; i < count; i++, fileOrder++) {
        CFNumberRef n = CFNumberCreate(alloc, kCFNumberNSIntegerType, &fileOrder);
        [[publications objectAtIndex:i] setFileOrder:(NSNumber *)n];
        CFRelease(n);
    }
}

@end

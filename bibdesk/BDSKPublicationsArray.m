//
//  BDSKPublicationsArray.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/25/06.
/*
 This software is Copyright (c) 2006-2014
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
#import "BibItem.h"
#import "BibAuthor.h"
#import "NSString_BDSKExtensions.h"
#import "CFString_BDSKExtensions.h"


static BOOL caseInsensitiveStringEqual(const void *item1, const void *item2, NSUInteger (*size)(const void *item)) {
    return CFStringCompare(item1, item2, kCFCompareCaseInsensitive | kCFCompareNonliteral) == kCFCompareEqualTo;
}

static NSUInteger caseInsensitiveStringHash(const void *item, NSUInteger (*size)(const void *item)) {
    return BDCaseInsensitiveStringHash(item);
}


@interface BDSKPublicationsArray (Private)
- (void)addItem:(BibItem *)item forCiteKey:(NSString *)key;
- (void)removeItem:(BibItem *)item forCiteKey:(NSString *)key;
- (void)addItem:(BibItem *)item;
- (void)removeItem:(BibItem *)item;
- (void)updateFileOrder;
@end


@implementation BDSKPublicationsArray

#pragma mark Init, dealloc overrides

- (id)init;
{
    return [self initWithArray:nil];
}

// custom initializers should be explicitly defined in concrete subclasses to be supported, we should not rely on inheritance
- (id)initWithArray:(NSArray *)anArray;
{
    self = [super init];
    if (self) {
        NSZone *zone = [self zone];
        publications = [[NSMutableArray allocWithZone:zone] initWithArray:anArray];
        itemsForIdentifierURLs = [[NSMutableDictionary allocWithZone:zone] init];
        NSPointerFunctions *keyPointerFunctions = [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality];
        [keyPointerFunctions setIsEqualFunction:&caseInsensitiveStringEqual];
        [keyPointerFunctions setHashFunction:&caseInsensitiveStringHash];
        NSPointerFunctions *valuePointerFunctions = [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality];
        itemsForCiteKeys = [[NSMapTable allocWithZone:zone] initWithKeyPointerFunctions:keyPointerFunctions valuePointerFunctions:valuePointerFunctions capacity:0];
        if ([anArray count]) {
            for (BibItem *pub in publications)
                [self addItem:pub];
            [self updateFileOrder];
        }
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
    [self addItem:anObject];
    [anObject setFileOrder:[NSNumber numberWithInteger:[publications count]]];
}

- (void)insertObject:(id)anObject atIndex:(NSUInteger)idx;
{
    [publications insertObject:anObject atIndex:idx];
    [self addItem:anObject];
    [self updateFileOrder];
}

- (void)removeLastObject;
{
    id lastObject = [publications lastObject];
    if(lastObject){
        [self removeItem:lastObject];
        [publications removeLastObject];
    }
}

- (void)removeObjectAtIndex:(NSUInteger)idx;
{
    [self removeItem:[publications objectAtIndex:idx]];
    [publications removeObjectAtIndex:idx];
    [self updateFileOrder];
}

- (void)replaceObjectAtIndex:(NSUInteger)idx withObject:(id)anObject;
{
    BibItem *oldObject = [publications objectAtIndex:idx];
    [anObject setFileOrder:[oldObject fileOrder]];
    [self removeItem:oldObject];
    [publications replaceObjectAtIndex:idx withObject:anObject];
    [self addItem:anObject];
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
        [self addItem:pub];
    [self updateFileOrder];
}

- (void)insertObjects:(NSArray *)objects atIndexes:(NSIndexSet *)indexes{
    [publications insertObjects:objects atIndexes:indexes];
    for (BibItem *pub in [publications objectsAtIndexes:indexes])
        [self addItem:pub];
    [self updateFileOrder];
}

- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes{
    for (BibItem *pub in [publications objectsAtIndexes:indexes])
        [self removeItem:pub];
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
    [self removeItem:anItem forCiteKey:oldKey];
    [self addItem:anItem forCiteKey:newKey];
}

- (BibItem *)itemForCiteKey:(NSString *)key;
{
	if ([NSString isEmptyString:key]) 
		return nil;
    
	NSArray *items = [itemsForCiteKeys objectForKey:key];
	
	if ([items count] == 0)
		return nil;
    // may have duplicate items for the same key, so just return the first one
    return [items objectAtIndex:0];
}

- (NSArray *)allItemsForCiteKey:(NSString *)key;
{
	NSArray *items = nil;
    if ([NSString isEmptyString:key] == NO) 
		items = [itemsForCiteKeys objectForKey:key];
    return items ?: [NSArray array];
}

- (BOOL)citeKeyIsUsed:(NSString *)key byItemOtherThan:(BibItem *)anItem;
{
    NSArray *items = [itemsForCiteKeys objectForKey:key];
    
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
        if ((pub = [itemsForIdentifierURLs objectForKey:idURL]))
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

- (void)addItem:(BibItem *)item forCiteKey:(NSString *)key{
    NSMutableArray *array = [itemsForCiteKeys objectForKey:key];
    if (array) {
        [array addObject:item];
    } else {
        array = [[NSMutableArray alloc] initWithObjects:item, nil];
        [itemsForCiteKeys setObject:array forKey:key];
        [array release];
    }
}

- (void)removeItem:(BibItem *)item forCiteKey:(NSString *)key{
    NSMutableArray *array = [itemsForCiteKeys objectForKey:key];
    if (array) {
        [array removeObject:item];
        if ([array count] == 0)
            [itemsForCiteKeys removeObjectForKey:key];
    }
}

- (void)addItem:(BibItem *)item{
    [self addItem:item forCiteKey:[item citeKey]];
    [itemsForIdentifierURLs setObject:item forKey:[item identifierURL]];
}

- (void)removeItem:(BibItem *)item{
    [self removeItem:item forCiteKey:[item citeKey]];
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

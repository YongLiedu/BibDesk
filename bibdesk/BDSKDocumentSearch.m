//
//  BDSKDocumentSearch.m
//  Bibdesk
//
//  Created by Adam Maxwell on 1/19/08.
/*
 This software is Copyright (c) 2008
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

#import "BDSKDocumentSearch.h"
#import "BibDocument.h"
#import "BibItem.h"
#import <libkern/OSAtomic.h>

static OFMessageQueue *searchQueue = nil;

@implementation BDSKDocumentSearch

+ (void)initialize
{
    if (nil == searchQueue) {
        searchQueue = [[OFMessageQueue alloc] init];
        [searchQueue startBackgroundProcessors:1];
    }
}

- (id)initWithDocument:(id)doc;
{
    self = [super init];
    if (self) {
        SEL cb = @selector(handleSearchCallbackWithIdentifiers:normalizedScores:);
        NSMethodSignature *sig = [doc methodSignatureForSelector:cb];
        NSParameterAssert(nil != sig);
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
        [invocation setTarget:doc];
        [invocation setSelector:cb];
        
        callback = [invocation retain];
        originalScores = [NSMutableDictionary new];
        isSearching = 0;
    }
    return self;
}

// owner should have already sent -terminate; sending it from -dealloc causes resurrection
- (void)dealloc
{
    [currentSearchString release];
    [originalScores release];
    [callback release];
    [previouslySelectedPublications release];
    [super dealloc];
}

- (void)_cancelSearch;
{
    if (NULL != search) {
        // set first in case this is called while we're working
        OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&isSearching);
        SKSearchCancel(search);
        CFRelease(search);
        search = NULL;
    }    
}

- (void)cancelSearch;
{
    [searchQueue queueSelector:@selector(_cancelSearch) forObject:self];
}

- (void)terminate;
{
    [self cancelSearch];
    NSInvocation *cb = callback;
    callback = nil;
    [cb release];
}

- (BOOL)isSearching;
{
    OSMemoryBarrier();
    return 1 == isSearching;
}

- (NSDictionary *)normalizedScores
{
    NSMutableDictionary *scores = [NSMutableDictionary dictionary];
    NSEnumerator *keyEnum = [originalScores keyEnumerator];
    id aKey;
    while (aKey = [keyEnum nextObject]) {
        float score = [[originalScores objectForKey:aKey] floatValue];
        [scores setObject:[NSNumber numberWithFloat:(score/maxScore)] forKey:aKey];
    }
    return scores;
}

#define SEARCH_BUFFER_MAX 1024

// array argument is so OFInvocation doesn't barf when it tries to retain the SKIndexRef
- (void)backgroundSearchForString:(NSString *)searchString indexArray:(NSArray *)skIndexArray
{
    // note that the add/remove methods flush the index, so we don't have to do it again
    SKIndexRef skIndex = (void *)[skIndexArray objectAtIndex:0];
    NSParameterAssert(NULL == search);
    search = SKSearchCreate(skIndex, (CFStringRef)searchString, kSKSearchOptionDefault);
    
    SKDocumentID documents[SEARCH_BUFFER_MAX];
    float scores[SEARCH_BUFFER_MAX];
    CFIndex i, foundCount;
    NSMutableSet *foundURLSet = [NSMutableSet set];
    
    Boolean more;
    maxScore = 0.0f;
    
    OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&isSearching);
    NSDictionary *normalizedScores = nil;
    [originalScores removeAllObjects];
    
    do {
        
        more = SKSearchFindMatches(search, SEARCH_BUFFER_MAX, documents, scores, 1.0, &foundCount);
        
        if (foundCount) {
            CFURLRef documentURLs[SEARCH_BUFFER_MAX];
            SKIndexCopyDocumentURLsForDocumentIDs(skIndex, foundCount, documents, documentURLs);
            
            for (i = 0; i < foundCount; i++) {
                [foundURLSet addObject:(id)documentURLs[i]];
                [originalScores setObject:[NSNumber numberWithFloat:scores[i]] forKey:(id)documentURLs[i]];
                CFRelease(documentURLs[i]);
                maxScore = MAX(maxScore, scores[i]);
            }
        }
        
        // check in case the doc is closing while a search is in progress
        if (nil != callback) {
            normalizedScores = [self normalizedScores];
            [callback setArgument:&foundURLSet atIndex:2];
            [callback setArgument:&normalizedScores atIndex:3];
            [callback performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:YES];
        }
        
        [foundURLSet removeAllObjects];
        
    } while (NULL != search && foundCount && more);
        
    if (nil != callback) {
        normalizedScores = [self normalizedScores];
        [callback setArgument:&foundURLSet atIndex:2];
        [callback setArgument:&normalizedScores atIndex:3];
        [callback performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:YES];
    }
    [self cancelSearch];  
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&isSearching);
}

- (NSArray *)previouslySelectedPublications { return previouslySelectedPublications; }

- (void)setPreviouslySelectedPublications:(NSArray *)selPubs
{
    [previouslySelectedPublications autorelease];
    previouslySelectedPublications = [[NSArray alloc] initWithArray:selPubs copyItems:NO];
}

- (void)searchForString:(NSString *)searchString index:(SKIndexRef)skIndex selectedPublications:(NSArray *)selPubs;
{
    [self setPreviouslySelectedPublications:selPubs];
    
    // searchfield seems to send its action multiple times with the same search string; avoid duplicate searches
    if (NO == [self isSearching] || (NO == [currentSearchString isEqualToString:searchString] && skIndex != currentIndex)) {
        [currentSearchString autorelease];
        currentSearchString = [searchString copy];
        
        if ([self isSearching])
            [self cancelSearch];
        
        [searchQueue queueSelector:@selector(backgroundSearchForString:indexArray:) forObject:self withObject:searchString withObject:[NSArray arrayWithObject:(id)skIndex]];
    }
}

@end

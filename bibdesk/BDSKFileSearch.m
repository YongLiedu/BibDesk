//
//  BDSKFileSearch.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/13/06.
/*
 This software is Copyright (c) 2006-2009
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

#import "BDSKFileSearch.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKFileSearchResult.h"
#import "BDSKFileSearchIndex.h"

// Wrapper around a buffers to clean up the interface and avoid malloc/free every time
// a search is performed.

// We don't realloc buffers to a smaller size (which might happens as fewer results are returned).

@interface BDSKSearchPrivateIvars : NSObject
{
 @private
    SKDocumentID *ids;
    float *scores;
    size_t indexSize;
    
    SKDocumentRef *docs;
    size_t resultSize;
}

- (SKDocumentID *)documentIDBuffer;
- (float *)scoreBuffer;
- (SKDocumentRef *)documentRefBuffer;
- (BOOL)changeIndexSize:(size_t)size;
- (BOOL)changeResultSize:(size_t)size;

@end

@interface BDSKFileSearch (Private)

- (void)setSearchString:(NSString *)aString;
- (void)setOptions:(SKSearchOptions)opts;
- (void)updateSearchResults;
- (void)setSearch:(SKSearchRef)aSearch;
- (void)normalizeScoresWithMaximumValue:(double)maxValue;

@end

@implementation BDSKFileSearch

- (id)initWithIndex:(BDSKFileSearchIndex *)anIndex delegate:(id <BDSKSearchDelegate>)aDelegate;
{
    NSParameterAssert(nil != anIndex);
    if ((self = [super init])) {
        searchResults = [[NSMutableSet alloc] initWithCapacity:128];
        
        data = [[BDSKSearchPrivateIvars alloc] init];
        [self setDelegate:aDelegate];
        searchIndex = [anIndex retain];
        [anIndex setDelegate:self];
    }
    return self;
}

- (void)dealloc
{
    [self setSearch:NULL];
    [searchIndex setDelegate:nil];
    [searchIndex release];
    [searchResults release];
    [data release];
    [super dealloc];
}

- (void)cancel;
{
    [self setSearch:NULL];
    [searchResults removeAllObjects];
}

- (void)searchForString:(NSString *)aString withOptions:(SKSearchOptions)opts;
{
    [self setSearchString:aString];
    [self setOptions:opts];
    [self updateSearchResults];
    // If initial indexing is complete, all results are available immediately after the call to updateSearchResults and the controller can remove its progress indicator.  Future changes to the index will call searchIndexDidUpdate:.
    [[self delegate] search:self didUpdateWithResults:[searchResults allObjects]];
}

- (void)searchIndexDidUpdate:(BDSKFileSearchIndex *)anIndex;
{
    if ([anIndex isEqual:searchIndex]) {
        
        // if there's a search in progress, we'll cancel it and re-update
        // if not, we'll notify the delegate with an empty array, since the index is still working
        // throttle the cancel/flush to 10 Hz, since that slows down indexing
        if (NULL != search)
            [self cancel];
        [self updateSearchResults];
        [[self delegate] search:self didUpdateWithResults:[searchResults allObjects]];
    }
}

- (void)searchIndexDidUpdateStatus:(BDSKFileSearchIndex *)anIndex;
{
    if ([anIndex isEqual:searchIndex]) {
        [[self delegate] search:self didUpdateStatus:[searchIndex status]];
    }
}

- (void)setDelegate:(id <BDSKSearchDelegate>)aDelegate;
{
    delegate = aDelegate;
}

- (id <BDSKSearchDelegate>)delegate { return delegate; }

@end


@implementation BDSKFileSearch (Private)

- (void)setSearch:(SKSearchRef)aSearch;
{
    if (aSearch)
        CFRetain(aSearch);
    if (search) {
        SKSearchCancel(search);
        CFRelease(search);
    }
    search = aSearch;
}

- (void)updateSearchResults;
{    
    SKIndexRef skIndex = [searchIndex index];
    
    if (NULL == skIndex)
        return;
    if (SKIndexFlush(skIndex) ==  FALSE) {
        NSLog(@"failed to flush index %@", searchIndex);
        return;
    }
        
    SKSearchRef skSearch = SKSearchCreate(skIndex, (CFStringRef)searchString, options);
    [self setSearch:skSearch];
    CFRelease(skSearch);
    
    // max number of documents we expect
    CFIndex maxCount = SKIndexGetDocumentCount(skIndex);
    
    BOOL changeSize = [data changeIndexSize:maxCount];
    NSAssert1(changeSize, @"Unable to allocate memory for index of size %ld", (long)maxCount);
    if (NO == changeSize) {
        NSLog(@"*** ERROR: unable to allocate memory for index of size %ld", (long)maxCount);
        return;
    }

    CFIndex actualCount;
    
    float *scores = [data scoreBuffer];
    SKDocumentID *documentIDs = [data documentIDBuffer];
    
    SKSearchFindMatches(search, maxCount, documentIDs, scores, 10, &actualCount);
    
    [searchResults removeAllObjects];
    
    if (actualCount > 0) {
        
        changeSize = [data changeResultSize:actualCount];
        NSAssert1(changeSize, @"Unable to allocate memory for results of size %ld", (long)actualCount);
        if (NO == changeSize) {
            NSLog(@"*** ERROR: unable to allocate memory for results of size %ld", (long)actualCount);
            return;
        }
        
        SKDocumentRef *skDocuments = [data documentRefBuffer];
        SKIndexCopyDocumentRefsForDocumentIDs(skIndex, actualCount, documentIDs, skDocuments);
        
        BDSKFileSearchResult *searchResult;
        SKDocumentRef skDocument;
        
        double maxValue = 0.0;
                
        while (actualCount--) {
            
            CGFloat score = *scores++;
            skDocument = *skDocuments++;
            
            // these scores are arbitrarily scaled, so we'll keep track of the search kit's max/min values
            maxValue = MAX(score, maxValue);
            
            NSURL *theURL = (NSURL *)SKDocumentCopyURL(skDocument);
            NSSet *identifierURLs = [searchIndex identifierURLsForURL:theURL];
            NSString *title = nil;
            
            for (NSURL *idURL in identifierURLs) {
                title = [[self delegate] search:self titleForIdentifierURL:idURL];
                searchResult = [[BDSKFileSearchResult alloc] initWithURL:theURL identifierURL:idURL title:title score:score];            
                [searchResults addObject:searchResult];            
                [searchResult release];
            }
            [theURL release];            
            CFRelease(skDocument);
        }      
        
        [self normalizeScoresWithMaximumValue:maxValue];
        
    }    
}

// we need to normalize each batch of results returned from SKSearchFindMatches separately
- (void)normalizeScoresWithMaximumValue:(double)maxValue;
{
    for (BDSKFileSearchResult *result in searchResults) {
        double score = [result score];
        double normalizedScore = score / maxValue * 5;
        [result setScore:normalizedScore];
    }
}

- (void)setSearchString:(NSString *)aString;
{
    if (searchString != aString) {
        [searchString release];
        searchString = [aString copy];
    }
}

- (void)setOptions:(SKSearchOptions)opts;
{
    options = opts;
}

@end


@implementation BDSKSearchPrivateIvars

- (id)init
{
    self = [super init];
    
    indexSize = 0;
    ids = NULL;
    scores = NULL;
    
    resultSize = 0;
    docs = NULL;
    
    return self;
}

- (void)dealloc
{
    if (ids) NSZoneFree(NSZoneFromPointer(ids), ids);
    if (docs) NSZoneFree(NSZoneFromPointer(docs), docs);
    if (scores) NSZoneFree(NSZoneFromPointer(scores), scores);
    [super dealloc];
}

- (BOOL)changeIndexSize:(size_t)size;
{
    if ((!ids && !scores) || indexSize < size) {
        ids = (SKDocumentID *)NSZoneRealloc([self zone], ids, size * sizeof(SKDocumentID));
        scores = (float *)NSZoneRealloc([self zone], scores, size * sizeof(float));
        indexSize = size;
    } 
    return NULL != scores && NULL != ids;
}

- (BOOL)changeResultSize:(size_t)size;
{
    if (!docs || resultSize < size) {
        docs = (SKDocumentRef *)NSZoneRealloc([self zone], docs, size * sizeof(SKDocumentRef));
        resultSize = size;
    }
    return NULL != docs;
}

- (SKDocumentID *)documentIDBuffer { return ids; }
- (float *)scoreBuffer { return scores; }
- (SKDocumentRef *)documentRefBuffer { return docs; }

@end
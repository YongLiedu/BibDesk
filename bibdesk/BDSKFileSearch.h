//
//  BDSKFileSearch.h
//  Bibdesk
//
//  Created by Adam Maxwell on 10/13/06.
/*
 This software is Copyright (c) 2006-2012
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
#import "BDSKFileSearchIndex.h"

@class BDSKFileSearchIndex, BDSKFileSearch, BDSKSearchPrivateIvars;

@protocol BDSKSearchDelegate <NSObject>

// sent as the search is in progress; anArray includes all results
- (void)search:(BDSKFileSearch *)aSearch didUpdateWithResults:(NSArray *)anArray;

// sent when the search index status changed
- (void)search:(BDSKFileSearch *)aSearch didUpdateStatus:(NSUInteger)status;

// sent to get the title for the BibItem used for display
- (NSString *)search:(BDSKFileSearch *)aSearch titleForIdentifierURL:(NSURL *)identifierURL;

@end

@interface BDSKFileSearch : NSObject <BDSKFileSearchIndexDelegate>
{
    @private
    SKSearchRef search;
    BDSKFileSearchIndex *searchIndex;
    NSMutableSet *searchResults;
    
    NSString *searchString;
    SKSearchOptions options;
   
    BDSKSearchPrivateIvars *data;
    id<BDSKSearchDelegate> delegate;
}

/* 
 * File content search classes:
 *
 * BDSKFileContentSearchController: owned by document, creates index/search and displays results
 * BDSKFileSearchIndex: wrapper around SKIndexRef and worker thread
 * BDSKFileSearch: wrapper around SKSearchRef
 * BDSKFileSearchResult: returned by BDSKFileSearch to the BDSKFileContentSearchController 
 *
 */

/*
  
 Search Kit is easy to use if you fully create the index, then search it (as we do with BibItem indexes).  Unfortunately, that's really slow for files, so we want to display results while indexing.  Search Kit gets in our way at a few points:  
 
    - SKSearchRef is a one-shot object, and basically works with a snapshot of the index.  
      Therefore, it needs to be recreated each time the index is updated, even if the 
      search string doesn't change, or you don't get new results.
 
    - SKSearchRef searches asynchronously, so SKSearchFindMatches needs to be called 
      in a loop until all matches are found.
 
    - There's no way to search incrementally, so each time you call SKSearchFindMatches 
      you get all results found previously.
 
    - Search scores need to be renormalized every time you call SKSearchFindMatches.
  
 BDSKFileContentSearchController creates/owns the BDSKFileSearchIndex, since the index needs a pointer to the document (initially) for notification registration and indexing.  BDSKFileContentSearchController creates/owns a single BDSKFileSearch and implements the BDSKSearchDelegate protocol to get updates from the BDSKFileSearch (what new items were found).  BDSKFileSearch creates and returns BDSKFileSearchResult objects to the controller for display.
 
 BDSKFileSearchIndex is a wrapper around an SKIndexRef that handles document/pub changes on a worker thread.  BDSKFileSearch conforms to the BDSKFileSearchIndexDelegate protocol, which allows the BDSKFileSearch to keep updating as new files are indexed, until the search is canceled or the index is done updating.  
 
  BDSKFileSearchResult is a simple container that wraps a search result (URL, title, icon, score) for display.  It implements -hash and -isEqual: so can be used in an NSSet; this was the primary reason it was written, since an NSSet was used to only add new results to the BDSKFileContentSearchController's NSArrayController in order to preserve selection.  At present, it's a simple container with accessors for type checking (vs. an NSMutableDictionary).
 
 So this is how we get incremental updates during indexing: 
 
  1) The BDSKFileSearchIndex informs BDSKFileSearch (its delegate) that new files have been added.  
  2) BDSKFileSearch cancels its current SKSearchRef and creates a new one.  
  3) BDSKFileSearch flushes the index and finds matches for the new SKSearchRef.
  4) All results of the new search are then accumulated and sent to the controller (delegate).
  5) Repeat 1--4 until indexing is complete
 
 
 */

- (id)initWithIndex:(BDSKFileSearchIndex *)anIndex delegate:(id <BDSKSearchDelegate>)aDelegate;

// primary entry point for searching; starts the search, which will send delegate messages
- (void)searchForString:(NSString *)aString withOptions:(SKSearchOptions)opts;

- (void)setDelegate:(id <BDSKSearchDelegate>)aDelegate;
- (id <BDSKSearchDelegate>)delegate;

// cancels the current search; shouldn't be any further update messages until another search is performed
- (void)cancel;

@end


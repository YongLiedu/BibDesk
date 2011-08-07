//
//  BDSKFileContentSearchController.m
//  BibDesk
//
//  Created by Adam Maxwell on 10/06/05.
/*
 This software is Copyright (c) 2005-2011
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
#import "BDSKFileSearch.h"

@class BDSKFileContentSearchController;

@protocol BDSKFileContentSearchControllerDelegate

- (void)removeFileContentSearch:(BDSKFileContentSearchController *)fileContentSearch;
- (NSString *)fileContentSearch:(BDSKFileContentSearchController *)fileContentSearch titleForIdentifierURL:(NSURL *)identifierURL;
- (void)fileContentSearchDidUpdate:(BDSKFileContentSearchController *)fileContentSearch;
- (void)fileContentSearchDidFinishInitialIndexing:(BDSKFileContentSearchController *)fileContentSearch;

@end

@class BDSKFileSearchIndex, BDSKTableView, BDSKCollapsibleView, BDSKEdgeView, BibDicument;

@protocol BDSKOwner;

@interface BDSKSelectionPreservingArrayController : NSArrayController
@end

@interface BDSKFileContentSearchController : NSViewController <BDSKSearchDelegate, NSTableViewDelegate, NSTextFieldDelegate>
{
    NSMutableArray *results;
    NSMutableArray *filteredResults;
    NSMutableSet *filterURLs;
    BDSKFileSearch *search;
    BDSKFileSearchIndex *searchIndex;
    
    id <BDSKFileContentSearchControllerDelegate> delegate;
    
    IBOutlet BDSKSelectionPreservingArrayController *resultsArrayController;
    IBOutlet BDSKTableView *tableView;
    
    IBOutlet BDSKEdgeView *controlView;
    IBOutlet BDSKCollapsibleView *collapsibleView;
    IBOutlet NSProgressIndicator *indexProgressBar;
    IBOutlet NSTextField *statusField;
    BOOL canceledSearch;
    BOOL searchFieldDidEndEditing;
    
    NSSearchField *searchField;
    NSMenu *savedSearchMenuTemplate;
    NSArray *savedRecentSearches;
}

// Use this method to instantiate a search controller for use within a document window
- (id)initForOwner:(id<BDSKOwner>)owner;

- (id<BDSKFileContentSearchControllerDelegate>)delegate;
- (void)setDelegate:(id<BDSKFileContentSearchControllerDelegate>)newDelegate;

- (NSView *)controlView;
- (NSTableView *)tableView;
// Use this to connect a search field and initiate a search
- (void)setSearchField:(NSSearchField *)aSearchField;
- (BOOL)shouldShowControlView;

- (NSArray *)selectedIdentifierURLs;
- (NSArray *)selectedURLs;
- (NSArray *)selectedResults;

- (NSArray *)clickedOrSelectedIdentifierURLs;
- (NSArray *)clickedOrSelectedURLs;
- (NSArray *)clickedOrSelectedResults;

- (NSArray *)identifierURLsAtIndexes:(NSIndexSet *)indexes;
- (NSArray *)URLsAtIndexes:(NSIndexSet *)indexes;
- (NSArray *)resultsAtIndexes:(NSIndexSet *)indexes;

- (NSArray *)results;
- (void)setResults:(NSArray *)newResults;
- (NSArray *)filteredResults;
- (void)setFilteredResults:(NSArray *)newFilteredResults;

- (void)filterUsingURLs:(NSArray *)newFilterURLs;

- (NSData *)sortDescriptorData;
- (void)setSortDescriptorData:(NSData *)data;

- (void)remove;
- (void)terminateForDocumentURL:(NSURL *)fileURL;

- (IBAction)search:(id)sender;
- (IBAction)tableAction:(id)sender;

- (void)handleClipViewFrameChangedNotification:(NSNotification *)note;

@end

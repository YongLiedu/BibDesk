//
//  BibDocument_Search.m
//  Bibdesk
//
/*
 This software is Copyright (c) 2001-2011
 Michael O. McCracken. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BibDocument_Search.h"
#import "BibDocument.h"
#import "BibDocument_UI.h"
#import "BDSKTypeManager.h"
#import <AGRegex/AGRegex.h>
#import "BibItem.h"
#import "CFString_BDSKExtensions.h"
#import "BDSKFieldSheetController.h"
#import "BDSKGroupOutlineView.h"
#import "NSTableView_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKZoomablePDFView.h"
#import "BDSKPreviewer.h"
#import "BDSKOverlayWindow.h"
#import "BibDocument_Groups.h"
#import "BDSKMainTableView.h"
#import "BDSKFindController.h"
#import "BDSKItemSearchIndexes.h"
#import "BDSKNotesSearchIndex.h"
#import "NSArray_BDSKExtensions.h"
#import "BDSKGroup.h"
#import "BDSKSharedGroup.h"
#import "BDSKOwnerProtocol.h"
#import "NSViewAnimation_BDSKExtensions.h"
#import "BDSKDocumentSearch.h"
#import "NSView_BDSKExtensions.h"
#import "NSDictionary_BDSKExtensions.h"
#import "BDSKEdgeView.h"
#import "BDSKButtonBar.h"


@implementation BibDocument (Search)

- (IBAction)changeSearchType:(id)sender{
    [[NSUserDefaults standardUserDefaults] setInteger:[sender tag] forKey:BDSKSearchMenuTagKey];
    [self redoSearch];
}

- (IBAction)makeSearchFieldKey:(id)sender{

    NSToolbar *tb = [documentWindow toolbar];
    [tb setVisible:YES];
    if([tb displayMode] == NSToolbarDisplayModeLabelOnly)
        [tb setDisplayMode:NSToolbarDisplayModeIconAndLabel];
    
	[documentWindow makeFirstResponder:searchField];
    [searchField selectText:sender];
}

- (NSString *)searchString {
	return [searchField stringValue];
}

- (void)setSearchString:(NSString *)filterterm {
    NSParameterAssert(filterterm != nil);
    if([[searchField stringValue] isEqualToString:filterterm] == NO){
        [searchField setStringValue:filterterm];
        [self redoSearch];
    }
}

- (NSString *)fileContentSearchString {
    // See bug #1344720; don't search if this is a known field (Title, Author, etc.).  This feature can be annoying because Preview.app zooms in on the search result in this case, in spite of your zoom settings (bug report filed with Apple).
    return [self isDisplayingFileContentSearch] ? [searchField stringValue] : @"";
}

- (void)updateSearch:(id)sender {
    NSString *field = [searchButtonBar representedObjectOfSelectedButton];
    if (searchButtonBar && nil == field) {
        BDSKASSERT_NOT_REACHED("the search button controller should always have a selected field");
        [searchButtonBar selectButtonWithRepresentedObject:BDSKAllFieldsString];
        field = BDSKAllFieldsString;
    }
    
    NSString *searchString = [searchField stringValue];
    
    if ([field isEqualToString:BDSKFileContentSearchString]) {
        
        // if searchString is empty, there is no buttonBar, and File Content shouldn't be selected
        BDSKASSERT([NSString isEmptyString:searchString] == NO);
        // if the file content search is already shown, we should not get this message, as the search: action is send to the fileSearchController
        BDSKASSERT([self isDisplayingFileContentSearch] == NO);
        
        if ([self isDisplayingFileContentSearch] == NO)
            [self showFileContentSearch];
        
    } else {
        
        if ([self isDisplayingFileContentSearch])
            [fileSearchController remove];
        
        if ([NSString isEmptyString:searchString]) {
            
            NSArray *pubsToSelect = [self selectedPublications];
            
            [shownPublications setArray:groupedPublications];
            [tableView deselectAll:nil];
            [self sortPubsByKey:nil];
            [self updateStatus];
            
            if ([pubsToSelect count])
                [self selectPublications:pubsToSelect];
            
        } else {
            
            SKIndexRef skIndex = NULL;
            
            if ([field isEqualToString:BDSKSkimNotesString]) {
                skIndex = [notesSearchIndex index];
            } else {
                // we need the correct BDSKPublicationsArray for access to the identifierURLs
                id<BDSKOwner> owner = [self hasExternalGroupsSelected] ? [[self selectedGroups] firstObject] : self;
                skIndex = [[owner searchIndexes] indexForField:field];
            }
            [documentSearch searchForString:BDSKSearchKitExpressionWithString(searchString) index:skIndex selectedPublications:[self selectedPublications] scrollPositionAsPercentage:[tableView scrollPositionAsPercentage]];
            
        }
         
    }
}

- (void)makeSearchButtonView {
    searchButtonEdgeView = [[BDSKEdgeView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 0.0, 29.0)];
    [searchButtonEdgeView setEdges:BDSKMinYEdgeMask];
    [searchButtonEdgeView setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    
    searchButtonBar = [[BDSKButtonBar alloc] initWithFrame:[searchButtonEdgeView contentRect]];
    [searchButtonEdgeView setContentView:searchButtonBar];
    [searchButtonBar release];
    
    [searchButtonBar setTarget:self];
    
    [searchButtonBar addButtonWithTitle:NSLocalizedString(@"Any Field", @"Search button") representedObject:BDSKAllFieldsString];
    [searchButtonBar addButtonWithTitle:NSLocalizedString(@"Title", @"Search button") representedObject:BDSKTitleString];
    [searchButtonBar addButtonWithTitle:NSLocalizedString(@"Person", @"Search button") representedObject:BDSKPersonString];
    
    skimNotesItem = [searchButtonBar newButtonWithTitle:NSLocalizedString(@"Skim Notes", @"Search button") representedObject:BDSKSkimNotesString];
    fileContentItem = [searchButtonBar newButtonWithTitle:NSLocalizedString(@"File Content", @"Search button") representedObject:BDSKFileContentSearchString ];
}

- (void)addFileSearchItems {
    if ([[searchButtonBar buttons] containsObject:skimNotesItem] == NO)
        [searchButtonBar addButton:skimNotesItem];
    if ([[searchButtonBar buttons] containsObject:fileContentItem] == NO)
        [searchButtonBar addButton:fileContentItem];
}

- (void)removeFileSearchItems {
    if ([[searchButtonBar buttons] containsObject:fileContentItem])
        [searchButtonBar removeButton:fileContentItem];
    if ([[searchButtonBar buttons] containsObject:skimNotesItem])
        [searchButtonBar removeButton:skimNotesItem];
}

- (void)showSearchButtonView {
    if ([self isDisplayingSearchButtons] == NO) {
        if (nil == searchButtonBar)
            [self makeSearchButtonView];
        
        if ([self hasExternalGroupsSelected])
            [self removeFileSearchItems];
        else
            [self addFileSearchItems];
        
        [self insertControlView:searchButtonEdgeView atTop:YES];
        
        if ([tableView tableColumnWithIdentifier:BDSKRelevanceString] == nil)
            [tableView insertTableColumnWithIdentifier:BDSKRelevanceString atIndex:0];
        
        if ([[searchButtonBar representedObjectOfSelectedButton] isEqualToString:BDSKAllFieldsString] == NO)
            [searchButtonBar selectButtonWithRepresentedObject:BDSKAllFieldsString];
        
        [searchButtonBar setAction:@selector(updateSearch:)];
    }
}

- (void)hideSearchButtonView {
    if ([self isDisplayingSearchButtons]) {
        [tableView removeTableColumnWithIdentifier:BDSKRelevanceString];
        
        [self removeControlView:searchButtonEdgeView];
        
        [searchButtonBar setAction:NULL];
        [searchButtonBar selectButtonWithRepresentedObject:BDSKAllFieldsString];
        
        if ([previousSortKey isEqualToString:BDSKRelevanceString]) {
            [previousSortKey release];
            previousSortKey = [BDSKTitleString retain];
            docFlags.previousSortDescending = NO;
        }
        if ([sortKey isEqualToString:BDSKRelevanceString])
            [self sortPubsByKey:[[previousSortKey retain] autorelease]];
    }
}

- (IBAction)search:(id)sender {
    if ([[sender stringValue] isEqualToString:@""])
        [self hideSearchButtonView];
    else 
        [self showSearchButtonView];    
    // update existing search
    [self updateSearch:nil];
}

- (void)redoSearch {
    // do the correct search: action depending on whether we have the file content shown or not
    [searchField sendAction:[searchField action] to:[searchField target]];
}

#pragma mark -

// simplified search used by BDSKAppController's Service for legacy compatibility
- (NSArray *)publicationsMatchingSubstring:(NSString *)searchString inField:(NSString *)field{
    NSUInteger i, iMax = [publications count];
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:100];
    for (i = 0; i < iMax; i++) {
        BibItem *pub = [publications objectAtIndex:i];
        if ([pub matchesSubstring:searchString inField:field])
            [results addObject:pub];
    }
    return results;
}


NSString *BDSKSearchKitExpressionWithString(NSString *searchFieldString)
{
    // surround with wildcards for substring search; should we check for any operators?
    if ([[NSUserDefaults standardUserDefaults] integerForKey:BDSKSearchMenuTagKey] == 0)
        searchFieldString = [NSString stringWithFormat:@"*%@*", searchFieldString];
    return searchFieldString;
}

- (void)searchDidStart:(BDSKDocumentSearch *)aSearch;
{
    [shownPublications removeAllObjects];
    [tableView deselectAll:nil];
    [self sortPubsByKey:nil];
    [self updateStatus];    
}

- (void)searchDidStop:(BDSKDocumentSearch *)aSearch;
{
    // maintain scroll position, select next item if the user didn't select something else during the search
    if ([self numberOfSelectedPubs] == 0) {
        
        // rowToSelectAfterDelete == -1 for non-delete operations
        if(rowToSelectAfterDelete >= [tableView numberOfRows])
            rowToSelectAfterDelete = [tableView numberOfRows] - 1;
        if(rowToSelectAfterDelete != -1) {
            [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:rowToSelectAfterDelete] byExtendingSelection:NO];
            [tableView setScrollPositionAsPercentage:scrollLocationAfterDelete];
        } else {
            // no prior selection
            [tableView setScrollPositionAsPercentage:[documentSearch previousScrollPositionAsPercentage]];
        }
    }
    
    rowToSelectAfterDelete = -1;
    scrollLocationAfterDelete = NSZeroPoint;
    
    [self updateStatus];
}

- (void)search:(BDSKDocumentSearch *)aSearch foundIdentifiers:(NSSet *)identifierURLs normalizedScores:(NSDictionary *)scores;
{
    id<BDSKOwner> owner = [self hasExternalGroupsSelected] ? [[self selectedGroups] firstObject] : self;    
    BDSKPublicationsArray *pubArray = [owner publications];    
    
    // we searched all publications, but we only want to keep the subset that's shown (if a group is selected)
    NSMutableSet *foundURLSet = [[identifierURLs mutableCopy] autorelease];
    NSMutableSet *identifierURLsToKeep = [NSMutableSet setWithArray:[groupedPublications valueForKey:@"identifierURL"]];
    [foundURLSet intersectSet:identifierURLsToKeep];
    
    [shownPublications addObjectsFromArray:[pubArray itemsForIdentifierURLs:[foundURLSet allObjects]]];
    
    for (BibItem *aPub in [self shownPublications])
        [aPub setSearchScore:[[scores objectForKey:[aPub identifierURL]] doubleValue]];
    
    [self sortPubsByKey:nil];
    [self selectPublications:[documentSearch previouslySelectedPublications]];    
    [self updateStatus];
}

#pragma mark File Content Search

- (void)showFileContentSearch
{
    if(fileSearchController == nil){
        fileSearchController = [[BDSKFileContentSearchController alloc] initForOwner:self];
        [fileSearchController setDelegate:self];
        NSData *sortDescriptorData = [[self mainWindowSetupDictionaryFromExtendedAttributes] objectForKey:BDSKFileContentSearchSortDescriptorKey] ?: [[NSUserDefaults standardUserDefaults] dataForKey:BDSKFileContentSearchSortDescriptorKey];
        if(sortDescriptorData)
            [fileSearchController setSortDescriptorData:sortDescriptorData];
    }
    
    [fileSearchController filterUsingURLs:[groupedPublications valueForKey:@"identifierURL"]];
    
    [NSViewAnimation animateReplaceView:[tableView enclosingScrollView] withView:[[fileSearchController tableView] enclosingScrollView]];
    if ([fileSearchController shouldShowControlView])
        [self insertControlView:[fileSearchController controlView] atTop:NO];
    
    [[fileSearchController tableView] setDelegate:self];
    
    // connect the searchfield to the controller and start the search
    [fileSearchController setSearchField:searchField];
    
    // make sure the previews and fileview are updated
    [self handleTableSelectionChangedNotification:nil];
}

// Method required by the BDSKFileContentSearchController; the implementor is responsible for restoring its state by removing the view passed as an argument and resetting search field target/action.
- (void)removeFileContentSearch:(BDSKFileContentSearchController *)controller
{
    [[fileSearchController tableView] setDelegate:nil];
    
    [NSViewAnimation animateReplaceView:[[fileSearchController tableView] enclosingScrollView] withView:[tableView enclosingScrollView]];
    [self removeControlView:[fileSearchController controlView]];
    
    // reconnect the searchfield
    [searchField setTarget:self];
    [searchField setDelegate:self];
    
    // removeFileContentSearch may be called after the user clicks a different search type, without changing the searchfield; in that case, we want to leave the search button view in place, and refilter the list.  Otherwise, select the pubs corresponding to the file content selection.
    if ([[searchField stringValue] isEqualToString:@""]) {
        // hide the search buttons and update search
        [self redoSearch];
        
        // have to hide the search view before trying to select anything
        NSArray *itemsToSelect = [fileSearchController selectedIdentifierURLs];
        
        if([itemsToSelect count]){
            
            // clear current selection (just in case)
            [tableView deselectAll:nil];
            
            // we match based on title, since that's all the index knows about the BibItem at present
            [self selectPublications:[publications itemsForIdentifierURLs:itemsToSelect]];
            [tableView scrollRowToCenter:[tableView selectedRow]];
            
            // if searchfield doesn't have focus (user clicked cancel button), switch to the tableview
            if ([[documentWindow firstResponder] isEqual:[searchField currentEditor]] == NO)
                [documentWindow makeFirstResponder:(NSResponder *)tableView];
        } else {
            // make sure the previews and fileview are updated
            [self handleTableSelectionChangedNotification:nil];
        }
    } else {
        [mainView setNeedsDisplay:YES];
        // make sure the previews and fileview are updated
        [self handleTableSelectionChangedNotification:nil];
    }
}

- (NSString *)fileContentSearch:(BDSKFileContentSearchController *)fileContentSearch titleForIdentifierURL:(NSURL *)identifierURL {
    return [[[self publications] itemForIdentifierURL:identifierURL] displayTitle];
}

- (void)fileContentSearchDidUpdate:(BDSKFileContentSearchController *)fileContentSearch {
    [self updateStatus];
}

- (void)fileContentSearchDidFinishInitialIndexing:(BDSKFileContentSearchController *)fileContentSearch {
    [self removeControlView:[fileContentSearch controlView]];
}

#pragma mark Find panel

- (NSString *)selectedStringForFind;
{
    // @@ check for hidden?
    if (bottomPreviewDisplay == BDSKPreviewDisplayTeX) {
        return [[[previewer pdfView] currentSelection] string];
    } else if (bottomPreviewDisplay == BDSKPreviewDisplayText || sidePreviewDisplay == BDSKPreviewDisplayText) {
        NSTextView *textView = bottomPreviewDisplay == BDSKPreviewDisplayText ? bottomPreviewTextView : sidePreviewTextView;
        NSRange selRange = [textView selectedRange];
        if (selRange.location == NSNotFound)
            return nil;
        return [[textView string] substringWithRange:selRange];
    }
    return nil;
}

@end

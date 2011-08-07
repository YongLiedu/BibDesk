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

#import "BDSKFileContentSearchController.h"
#import "BDSKFileSearchIndex.h"
#import "BDSKEdgeView.h"
#import "BDSKCollapsibleView.h"
#import "BDSKStatusBar.h"
#import "BibItem.h"
#import "BDSKStringConstants.h"
#import "NSImage_BDSKExtensions.h"
#import <Carbon/Carbon.h>
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKTextWithIconCell.h"
#import "NSAttributedString_BDSKExtensions.h"
#import "BDSKFileSearch.h"
#import "BDSKFileSearchResult.h"
#import "BDSKLevelIndicatorCell.h"
#import "BDSKOwnerProtocol.h"
#import "BibDocument_Search.h"
#import "NSArray_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKTableView.h"
#import "NSTableView_BDSKExtensions.h"


@implementation BDSKFileContentSearchController

- (id)initForOwner:(id<BDSKOwner>)owner
{    
    self = [super initWithNibName:@"BDSKFileContentSearch" bundle:nil];
    if (self) {
        results = nil;
        filteredResults = nil;
        filterURLs = nil;
        canceledSearch = NO;
        searchIndex = [[BDSKFileSearchIndex alloc] initForOwner:owner];
        search = [[BDSKFileSearch alloc] initWithIndex:searchIndex delegate:self];
        searchFieldDidEndEditing = NO;
    }
    return self;
}
    

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [tableView setDelegate:nil];
    [tableView setDataSource:nil];
    // should already have been taken care of in -stopSearching
    BDSKDESTROY(search);
    BDSKDESTROY(searchIndex);
    [[tableView enclosingScrollView] release];
    BDSKDESTROY(results);
    BDSKDESTROY(filteredResults);
    BDSKDESTROY(filterURLs);
    BDSKDESTROY(searchField);
    BDSKDESTROY(savedSearchMenuTemplate);
    BDSKDESTROY(savedRecentSearches);
    [super dealloc];
}

- (void)awakeFromNib
{
    [tableView setTarget:self];
    [tableView setDoubleAction:@selector(tableAction:)];
    
    [tableView setFontNamePreferenceKey:BDSKFileContentSearchTableViewFontNameKey];
    [tableView setFontSizePreferenceKey:BDSKFileContentSearchTableViewFontSizeKey];
    
    BDSKLevelIndicatorCell *cell = [[tableView tableColumnWithIdentifier:@"score"] dataCell];
    [cell setEnabled:NO]; // this is required to make it non-editable
    [cell setMaxHeight:17.0 * 0.7];
    
    BDSKPRECONDITION([[tableView enclosingScrollView] contentView]);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleClipViewFrameChangedNotification:)
                                                 name:NSViewFrameDidChangeNotification
                                               object:[[tableView enclosingScrollView] contentView]];    

    // Do custom view setup 
    NSRect frame = [collapsibleView frame];
    frame.size.width = 350.0;
    [collapsibleView setMinSize:frame.size];
    [collapsibleView setCollapseEdges:BDSKMinXEdgeMask | BDSKMinYEdgeMask];
    [controlView setEdges:BDSKMinYEdgeMask];
    [controlView setColor:[controlView colorForEdge:NSMaxYEdge] forEdge:NSMinYEdge];

    // we might remove this, so keep a retained reference
    [[tableView enclosingScrollView] retain];
    
    // @@ workaround: the font from prefs seems to be overridden by the nib; maybe bindings issue?
    [tableView changeFont:nil];
    
    [tableView sizeToFit];
    
    [indexProgressBar setMaxValue:100.0];
    [indexProgressBar setMinValue:0.0];
    [indexProgressBar setDoubleValue:[searchIndex progressValue]];
}    

- (id<BDSKFileContentSearchControllerDelegate>)delegate {
    return delegate;
}

- (void)setDelegate:(id<BDSKFileContentSearchControllerDelegate>)newDelegate {
    delegate = newDelegate;
}

- (NSView *)controlView
{
    if(controlView == nil)
        [self view]; // this forces a load of the nib
    return controlView;
}

- (BOOL)shouldShowControlView
{
    return [searchIndex status] < BDSKSearchIndexStatusRunning;
}

- (NSTableView *)tableView
{
    if(tableView == nil)
        [self view]; // this forces a load of the nib
    return tableView;
}

- (void)handleClipViewFrameChangedNotification:(NSNotification *)note
{
    // work around for bug where corner view doesn't get redrawn after scrollers hide
    [[tableView cornerView] setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark Actions

- (IBAction)tableAction:(id)sender
{
    NSInteger row = [tableView clickedRow];
    if(row == -1)
        return;
    
    BOOL isDir;
    NSURL *fileURL = [[[resultsArrayController arrangedObjects] objectAtIndex:row] URL];
    
    BDSKASSERT(fileURL);
    BDSKASSERT(searchField);

    if(![[NSFileManager defaultManager] fileExistsAtPath:[fileURL path] isDirectory:&isDir]){
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"File Does Not Exist", @"Message in alert dialog when file could not be found")
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"The file at \"%@\" no longer exists.", @"Informative text in alert dialog "), [fileURL path]];
        [alert beginSheetModalForWindow:[tableView window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
    } else if(isDir){
        // just open it with the Finder; we shouldn't have folders in our index, though
        [[NSWorkspace sharedWorkspace] openLinkedURL:fileURL];
    } else if(![[NSWorkspace sharedWorkspace] openURL:fileURL withSearchString:[searchField stringValue]]){
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Unable to Open File", @"Message in alert dialog when unable to open file")
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"I was unable to open the file at \"%@.\"  You may wish to check permissions on the file or directory.", @"Informative text in alert dialog "), [fileURL path]];
        [alert beginSheetModalForWindow:[tableView window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
    }
}

- (void)setSearchField:(NSSearchField *)aSearchField
{
    if (searchField == aSearchField)
        return;
    
    if (nil != searchField) {
        // disconnect the current searchfield
        [savedSearchMenuTemplate release];
        savedSearchMenuTemplate = [[[searchField cell] searchMenuTemplate] retain];
        [savedRecentSearches release];
        savedRecentSearches = [[[searchField cell] recentSearches] retain];
        [searchField setTarget:nil];
        [searchField setDelegate:nil];  
        [[searchField cell] setSearchMenuTemplate:nil];
        [[searchField cell] setRecentSearches:nil];
    }
    
    [searchField release];
    searchField = [aSearchField retain];
    
    if (nil != searchField) {
        [searchField setTarget:self];
        [searchField setDelegate:self];
        [[searchField cell] setSearchMenuTemplate:savedSearchMenuTemplate];
        [[searchField cell] setRecentSearches:savedRecentSearches];
        BDSKDESTROY(savedSearchMenuTemplate);
        BDSKDESTROY(savedRecentSearches);
        [self search:searchField];
    }     
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
    // we get this message with an empty string when committing an edit, or with a non-empty string after clearing the searchfield (use it to see if this was a cancel action so we can handle it slightly differently in search:)
    if ([[aNotification object] isEqual:searchField])
        searchFieldDidEndEditing = YES;
}

- (IBAction)search:(id)sender
{
    if ([NSString isEmptyString:[searchField stringValue]]) {
        // iTunes/Mail swap out their search view when clearing the searchfield, so we follow suit.  If the user clicks the cancel button, we want the searchfield to lose first responder status, but this doesn't happen by default (maybe depends on whether it sends immediately?  Xcode seems to work correctly).  Don't clear the array when restoring document state, since we may need the array controller's selected objects.

        // we get a search: action after the cancel/controlTextDidEndEditing: combination, so see if this was a cancel action
        if (searchFieldDidEndEditing)
            [[tableView window] makeFirstResponder:nil];

        [self remove];
    } else {
        
        searchFieldDidEndEditing = NO;
        // empty array; this takes care of updating the table for us
        [self setResults:[NSArray array]];        
        // set before starting the search, or we can end up updating with it == YES
        canceledSearch = NO;
        
        // may be hidden if we called restoreDocumentState while indexing
        if ([self shouldShowControlView] && [indexProgressBar isHiddenOrHasHiddenAncestor]) {
            // setHidden:NO doesn't seem to apply to subviews
            [indexProgressBar setHidden:NO];
        }
        
        [search searchForString:BDSKSearchKitExpressionWithString([searchField stringValue])  withOptions:kSKSearchOptionDefault];
    }
}

#pragma mark -
#pragma mark Accessors

- (void)updateFilteredResults
{
    if (filterURLs == nil) {
        [self setFilteredResults:results];
    } else {
        NSMutableArray *newFilteredResults = [NSMutableArray arrayWithCapacity:[results count]];
        for (BDSKFileSearchResult *result in results)
            if ([filterURLs containsObject:[result identifierURL]])
                [newFilteredResults addObject:result];
        [self setFilteredResults:newFilteredResults];
    }
    [[self delegate] fileContentSearchDidUpdate:self];
}

- (void)setResults:(NSArray *)newResults
{
    if(newResults != results){
        [results release];
        results = [newResults mutableCopy];
        [self updateFilteredResults];
    }
}

- (NSArray *)results
{
    return results;
}

- (void)setFilteredResults:(NSArray *)newFilteredResults
{
    if(newFilteredResults != filteredResults){
        [filteredResults release];
        filteredResults = [newFilteredResults mutableCopy];
    }
}

- (NSArray *)filteredResults
{
    return filteredResults;
}

- (void)filterUsingURLs:(NSArray *)newFilterURLs;
{
    [filterURLs release];
    filterURLs = newFilterURLs == nil ? nil : [[NSSet alloc] initWithArray:newFilterURLs];
    [self updateFilteredResults];
}

- (NSData *)sortDescriptorData
{
    [self view];
    return [NSArchiver archivedDataWithRootObject:[resultsArrayController sortDescriptors]];
}

- (void)setSortDescriptorData:(NSData *)data
{
    [self view];
    NSMutableArray *sortDescriptors = [NSMutableArray array];
    [sortDescriptors addObjectsFromArray:[NSUnarchiver unarchiveObjectWithData:data]];
    NSUInteger i = [sortDescriptors count];
    // see https://sourceforge.net/tracker/index.php?func=detail&aid=1837498&group_id=61487&atid=497423
    // We changed BDSKFileSearchResult and started saving sort descriptors in EA at about the same time, so apparently a user ended up with a sort key of @"dictionary.string" in EA; this caused a bunch of ignored exceptions, and content search failed.  Another possibility (remote) is that the EA were corrupted somehow.  Anyway, check for the correct keys to avoid this in future.
    NSSet *keys = [NSSet setWithObjects:@"string", @"score", nil];
    while (i--) {
        NSSortDescriptor *sort = [sortDescriptors objectAtIndex:i];
        if ([keys containsObject:[sort key]] == NO)
            [sortDescriptors removeObjectAtIndex:i];
    }
    [resultsArrayController setSortDescriptors:sortDescriptors];
}

- (NSArray *)selectedIdentifierURLs
{
    return [[resultsArrayController selectedObjects] valueForKey:@"identifierURL"];
}

- (NSArray *)selectedURLs {
    return [[resultsArrayController selectedObjects] valueForKey:@"URL"];
}

- (NSArray *)selectedResults {
    return [resultsArrayController selectedObjects];
}

- (NSArray *)clickedOrSelectedIdentifierURLs
{
    return [[self clickedOrSelectedResults] valueForKey:@"identifierURL"];
}

- (NSArray *)clickedOrSelectedURLs {
    return [[self clickedOrSelectedResults] valueForKey:@"URL"];
}

- (NSArray *)clickedOrSelectedResults {
    return [[resultsArrayController arrangedObjects] objectsAtIndexes:[tableView clickedOrSelectedRowIndexes]];
}

- (NSArray *)identifierURLsAtIndexes:(NSIndexSet *)indexes
{
    return [[[resultsArrayController arrangedObjects] objectsAtIndexes:indexes] valueForKeyPath:@"@distinctUnionOfObjects.identifierURL"];
}

- (NSArray *)URLsAtIndexes:(NSIndexSet *)indexes {
    return [[[resultsArrayController arrangedObjects] objectsAtIndexes:indexes] valueForKeyPath:@"@distinctUnionOfObjects.URL"];
}

- (NSArray *)resultsAtIndexes:(NSIndexSet *)indexes {
    return [[resultsArrayController arrangedObjects] objectsAtIndexes:indexes];
}

#pragma mark -
#pragma mark SearchKit methods

- (void)search:(BDSKFileSearch *)aSearch didUpdateWithResults:(NSArray *)anArray;
{
    if ([search isEqual:aSearch]) {
        
        // don't reset the array
        if (NO == canceledSearch)
            [self setResults:anArray];
        [indexProgressBar setDoubleValue:[searchIndex progressValue]];
    }
}

- (void)search:(BDSKFileSearch *)aSearch didUpdateStatus:(NSUInteger)status;
{
    if ([search isEqual:aSearch]) {
        switch (status) {
            case BDSKSearchIndexStatusStarting:
                [statusField setStringValue:[NSLocalizedString(@"Starting Index", @"status message") stringByAppendingEllipsis]];
                break;
            case BDSKSearchIndexStatusVerifying:
                [statusField setStringValue:[NSLocalizedString(@"Verifying Index", @"status message") stringByAppendingEllipsis]];
                break;
            case BDSKSearchIndexStatusIndexing:
                [statusField setStringValue:[NSLocalizedString(@"Indexing Files", @"status message") stringByAppendingEllipsis]];
                break;
            case BDSKSearchIndexStatusRunning:
                // hides progress bar and text
                [indexProgressBar setHidden:YES];
                [statusField setStringValue:@""];
                [[self delegate] fileContentSearchDidFinishInitialIndexing:self];
                break;
            default:
                break;
        }
    }
}

- (NSString *)search:(BDSKFileSearch *)aSearch titleForIdentifierURL:(NSURL *)identifierURL;
{
    return [[self delegate] fileContentSearch:self titleForIdentifierURL:identifierURL];
}

#pragma mark -
#pragma mark Document interaction

- (void)saveSortDescriptors
{
    [[NSUserDefaults standardUserDefaults] setObject:[self sortDescriptorData] forKey:BDSKFileContentSearchSortDescriptorKey];
}

- (void)remove
{
    [self saveSortDescriptors];
    
    // cancel the search
    [search cancel];
    // this will cancel updates to the tableview
    canceledSearch = YES;
    
    // disconnect the searchfield
    [self setSearchField:nil];
    
    // hide this so it doesn't flash during the transition
    [indexProgressBar setHidden:YES];
    
    [[self delegate] removeFileContentSearch:self];
}

- (void)terminateForDocumentURL:(NSURL *)fileURL
{
    [self saveSortDescriptors];
    
    // cancel the search
    [search cancel];
    // this will cancel updates to the tableview
    canceledSearch = YES;
    
    // the index may continue sending the search object update messages, so make sure it doesn't try to pass them on
    [search setDelegate:nil];
    
    // extra safety here; make sure the index stops messaging the search object now
    [searchIndex setDelegate:nil];
    
    // stops the search index runloop, let the index know the document's location so it can cache the index to disk
    [searchIndex cancelForDocumentURL:fileURL];
    BDSKDESTROY(searchIndex);
}

@end

// The array controller is set to preserve selection, but it seems to work based on pointer equality or else isn't implemented for setContent:.  Consequently, each time setContent: is called (via setResults:), the selection changes randomly.  Here we explicitly preserve selection based on isEqual:, which is implemented correctly for the BDSKSearchResults.  This is generally pretty fast, since the number of selected objects is typically small.

@implementation BDSKSelectionPreservingArrayController

- (void)setContent:(id)object
{
    NSArray *previouslySelectedObjects = [[NSArray alloc] initWithArray:[self selectedObjects] copyItems:NO];
    [super setContent:object];
    
    NSUInteger cnt = [previouslySelectedObjects count];
    NSArray *arrangedObjects = [self arrangedObjects];
    NSMutableIndexSet *indexesToSelect = [NSMutableIndexSet indexSet];
    while (cnt--) {
        id oldObject = [previouslySelectedObjects objectAtIndex:cnt];
        NSUInteger i = [arrangedObjects indexOfObject:oldObject];
        if (NSNotFound != i)
            [indexesToSelect addIndex:i];
    }
    if ([indexesToSelect count])
        [self setSelectionIndexes:indexesToSelect];
    [previouslySelectedObjects release];
}

@end



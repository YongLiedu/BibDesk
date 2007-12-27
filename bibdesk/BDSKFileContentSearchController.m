//
//  BDSKFileContentSearchController.m
//  BibDesk
//
//  Created by Adam Maxwell on 10/06/05.
/*
 This software is Copyright (c) 2005,2006,2007
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
#import "BibItem.h"
#import "BDSKStringConstants.h"
#import "NSImage_BDSKExtensions.h"
#import <Carbon/Carbon.h>
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKTextWithIconCell.h"
#import "NSAttributedString_BDSKExtensions.h"
#import "BDSKSearch.h"
#import "BDSKSearchResult.h"
#import "BDSKLevelIndicatorCell.h"
#import "BibDocument_Search.h"

// Overrides attributedStringValue since we return an attributed string; normally, the cell uses the font of the attributed string, rather than the table's font, so font changes are ignored.  This means that italics and bold in titles will be lost until the search string changes again, but that's not a great loss.
@interface BDSKFileContentTextWithIconCell : BDSKTextWithIconCell
@end

@implementation BDSKFileContentTextWithIconCell

- (NSAttributedString *)attributedStringValue
{
    NSMutableAttributedString *value = [[super attributedStringValue] mutableCopy];
    [value addAttribute:NSFontAttributeName value:[self font] range:NSMakeRange(0, [value length])];
    return [value autorelease];
}

@end

@implementation BDSKFileContentSearchController

- (id)initForDocument:(id)aDocument
{    
    self = [super init];
    if(!self) return nil;
    
    results = nil;
    filteredResults = nil;
    filterURLs = nil;
    
    canceledSearch = NO;
        
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
    
    NSParameterAssert([aDocument conformsToProtocol:@protocol(BDSKSearchContentView)]);
    [self setDocument:aDocument];
    
    searchIndex = [[BDSKSearchIndex alloc] initWithDocument:aDocument];
    search = [[BDSKSearch alloc] initWithIndex:searchIndex delegate:self];
    searchFieldDidEndEditing = NO;
    
    return self;
}
    

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // should already have been taken care of in -stopSearching
    [search release];
    [searchIndex release];
    [searchContentView release];
    [results release];
    [filteredResults release];
    [filterURLs release];
    [super dealloc];
}

- (void)awakeFromNib
{
    [tableView setTarget:self];
    [tableView setDoubleAction:@selector(tableAction:)];
    
    BDSKLevelIndicatorCell *cell = [[BDSKLevelIndicatorCell alloc] initWithLevelIndicatorStyle:NSRelevancyLevelIndicatorStyle];
    [cell setEnabled:NO]; // this is required to make it non-editable
    [cell setMaxHeight:17.0 * 0.7];
    [cell setMaxValue:5.0];
    [[tableView tableColumnWithIdentifier:@"score"] setDataCell:cell];
    [cell release];
    
    // set up the image/text cell combination
    BDSKTextWithIconCell *textCell = [[BDSKFileContentTextWithIconCell alloc] init];
    [textCell setControlSize:[cell controlSize]];
    [textCell setDrawsHighlight:NO];
    [[tableView tableColumnWithIdentifier:@"name"] setDataCell:textCell];
    [textCell release];
    
    OBPRECONDITION([[tableView enclosingScrollView] contentView]);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleClipViewFrameChangedNotification:)
                                                 name:NSViewFrameDidChangeNotification
                                               object:[[tableView enclosingScrollView] contentView]];    

    // Do custom view setup 
    [topBarView setEdges:BDSKMinXEdgeMask | BDSKMaxXEdgeMask | BDSKMaxYEdgeMask];
    [topBarView setColor:[NSColor colorWithCalibratedWhite:0.6 alpha:1.0] forEdge:NSMaxYEdge];

    // we might remove this, so keep a retained reference
    searchContentView = [[[self window] contentView] retain];

    // @@ workaround: the font from prefs seems to be overridden by the nib; maybe bindings issue?
    [tableView changeFont:nil];
    
    [tableView sizeToFit];
    
    [indexProgressBar setMaxValue:100.0];
    [indexProgressBar setMinValue:0.0];
    [indexProgressBar setDoubleValue:[searchIndex progressValue]];
}    

- (NSString *)windowNibName
{
    return @"BDSKFileContentSearch";
}

- (NSView *)searchContentView
{
    if(searchContentView == nil)
        [self window]; // this forces a load of the nib
    return searchContentView;
}

- (NSArray *)identifierURLsOfSelectedItems
{
    return [[resultsArrayController selectedObjects] valueForKey:@"identifierURL"];
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
    int row = [tableView clickedRow];
    if(row == -1)
        return;
    
    BOOL isDir;
    NSURL *fileURL = [[[resultsArrayController arrangedObjects] objectAtIndex:row] URL];
    
    OBASSERT(fileURL);
    OBASSERT(searchField);

    if(![[NSFileManager defaultManager] fileExistsAtPath:[fileURL path] isDirectory:&isDir]){
        NSBeginAlertSheet(NSLocalizedString(@"File Does Not Exist", @"Message in alert dialog when file could not be found"),
                          nil /*default button*/,
                          nil /*alternate button*/,
                          nil /*other button*/,
                          [tableView window],nil,NULL,NULL,NULL,NSLocalizedString(@"The file at \"%@\" no longer exists.", @"Informative text in alert dialog "), [fileURL path]);
    } else if(isDir){
        // just open it with the Finder; we shouldn't have folders in our index, though
        [[NSWorkspace sharedWorkspace] openURL:fileURL];
    } else if(![[NSWorkspace sharedWorkspace] openURL:fileURL withSearchString:[searchField stringValue]]){
        NSBeginAlertSheet(NSLocalizedString(@"Unable to Open File", @"Message in alert dialog when unable to open file"),
                          nil /*default button*/,
                          nil /*alternate button*/,
                          nil /*other button*/,
                          [tableView window],nil,NULL,NULL,NULL,NSLocalizedString(@"I was unable to open the file at \"%@.\"  You may wish to check permissions on the file or directory.", @"Informative text in alert dialog "), [fileURL path]);
    }
}

- (void)setSearchField:(NSSearchField *)aSearchField
{
    if (nil != searchField) {
        // disconnect the current searchfield
        [searchField setTarget:nil];
        [searchField setDelegate:nil];  
    }
    
    searchField = aSearchField;
    
    if (nil != searchField) {
        [searchField setTarget:self];
        [searchField setDelegate:self];
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
            [[searchContentView window] makeFirstResponder:nil];

        [self restoreDocumentState];
    } else {
        
        searchFieldDidEndEditing = NO;
        // empty array; this takes care of updating the table for us
        [self setResults:[NSArray array]];        
        [stopButton setEnabled:YES];
        // set before starting the search, or we can end up updating with it == YES
        canceledSearch = NO;
        
        // may be hidden if we called restoreDocumentState while indexing
        if ([searchIndex isIndexing] && [progressView isHiddenOrHasHiddenAncestor]) {
            [progressView setHidden:NO];
            // setHidden:NO doesn't seem to apply to subviews
            [indexProgressBar setHidden:NO];
        }
        
        [search searchForString:BDSKSearchKitExpressionWithString([searchField stringValue])  withOptions:kSKSearchOptionDefault];
    }
}

- (void)restoreDocumentState
{
    [self saveSortDescriptors];
    [self cancelCurrentSearch:nil];
    
    // disconnect the searchfield
    [self setSearchField:nil];
    
    // hide this so it doesn't flash during the transition
    [progressView setHidden:YES];
    
    [[self document] restoreDocumentStateByRemovingSearchView:[self searchContentView]];
}

#pragma mark -
#pragma mark Accessors

- (void)updateFilteredResults
{
    if (filterURLs == nil) {
        [self setFilteredResults:results];
    } else {
        NSMutableArray *newFilteredResults = [NSMutableArray arrayWithCapacity:[results count]];
        NSEnumerator *resultEnum = [results objectEnumerator];
        BDSKSearchResult *result;
        
        while (result = [resultEnum nextObject])
            if ([filterURLs containsObject:[result identifierURL]])
                [newFilteredResults addObject:result];
        [self setFilteredResults:newFilteredResults];
    }
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
    [self window];
    return [NSArchiver archivedDataWithRootObject:[resultsArrayController sortDescriptors]];
}

- (void)setSortDescriptorData:(NSData *)data
{
    [self window];
    NSMutableArray *sortDescriptors = [NSMutableArray array];
    [sortDescriptors addObjectsFromArray:[NSUnarchiver unarchiveObjectWithData:data]];
    unsigned i = [sortDescriptors count];
    // see https://sourceforge.net/tracker/index.php?func=detail&aid=1837498&group_id=61487&atid=497423
    // We changed BDSKSearchResult and started saving sort descriptors in EA at about the same time, so apparently a user ended up with a sort key of @"dictionary.string" in EA; this caused a bunch of ignored exceptions, and content search failed.  Another possibility (remote) is that the EA were corrupted somehow.  Anyway, check for the correct keys to avoid this in future.
    NSSet *keys = [NSSet setWithObjects:@"string", @"score", nil];
    while (i--) {
        NSSortDescriptor *sort = [sortDescriptors objectAtIndex:i];
        if ([keys containsObject:[sort key]] == NO)
            [sortDescriptors removeObjectAtIndex:i];
    }
    [resultsArrayController setSortDescriptors:sortDescriptors];
}

#pragma mark -
#pragma mark SearchKit methods

- (void)search:(BDSKSearch *)aSearch didUpdateWithResults:(NSArray *)anArray;
{
    if ([search isEqual:aSearch]) {
        
        // don't reset the array
        if (NO == canceledSearch)
            [self setResults:anArray];
        [indexProgressBar setDoubleValue:[searchIndex progressValue]];
    }
}

- (void)search:(BDSKSearch *)aSearch didFinishWithResults:(NSArray *)anArray;
{
    if ([search isEqual:aSearch]) {
        [stopButton setEnabled:NO];
        
        // don't reset the array if we canceled updates
        if (NO == canceledSearch)
            [self setResults:anArray];
        [indexProgressBar setDoubleValue:[searchIndex progressValue]];
        
        // hides progress bar and text
        [progressView setHidden:YES];
    }
}

- (IBAction)cancelCurrentSearch:(id)sender
{
    [search cancel];
    [stopButton setEnabled:NO];
    
    // this will cancel updates to the tableview
    canceledSearch = YES;
}    

#pragma mark -
#pragma mark Document interaction

- (void)terminate
{
    // cancel the search
    [self cancelCurrentSearch:nil];
    
    // the index may continue sending the search object update messages, so make sure it doesn't try to pass them on
    [search setDelegate:nil];
    
    // extra safety here; make sure the index stops messaging the search object now
    [searchIndex setDelegate:nil];
    
    // stops the search index runloop so it will release the document
    [searchIndex cancel];
    [searchIndex release];
    searchIndex = nil;
}

- (void)saveSortDescriptors
{
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:[self sortDescriptorData] forKey:BDSKFileContentSearchSortDescriptorKey];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [self saveSortDescriptors];
}

- (void)handleApplicationWillTerminate:(NSNotification *)notification
{
    [self saveSortDescriptors];
}

#pragma mark TableView delegate

- (NSString *)tableViewFontNamePreferenceKey:(NSTableView *)tv {
    return BDSKFileContentSearchTableViewFontNameKey;
}

- (NSString *)tableViewFontSizePreferenceKey:(NSTableView *)tv {
    return BDSKFileContentSearchTableViewFontSizeKey;
}

@end

// The array controller is set to preserve selection, but it seems to work based on pointer equality or else isn't implemented for setContent:.  Consequently, each time setContent: is called (via setResults:), the selection changes randomly.  Here we explicitly preserve selection based on isEqual:, which is implemented correctly for the BDSKSearchResults.  This is generally pretty fast, since the number of selected objects is typically small.

@implementation BDSKSelectionPreservingArrayController

- (void)setContent:(id)object
{
    NSArray *previouslySelectedObjects = [[NSArray alloc] initWithArray:[self selectedObjects] copyItems:NO];
    [super setContent:object];
    
    unsigned cnt = [previouslySelectedObjects count];
    NSArray *arrangedObjects = [self arrangedObjects];
    NSMutableIndexSet *indexesToSelect = [NSMutableIndexSet indexSet];
    while (cnt--) {
        id oldObject = [previouslySelectedObjects objectAtIndex:cnt];
        unsigned i = [arrangedObjects indexOfObject:oldObject];
        if (NSNotFound != i)
            [indexesToSelect addIndex:i];
    }
    if ([indexesToSelect count])
        [self setSelectionIndexes:indexesToSelect];
    [previouslySelectedObjects release];
}

@end



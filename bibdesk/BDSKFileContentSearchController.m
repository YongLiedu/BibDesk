//
//  BDSKFileContentSearchController.m
//  BibDesk
//
//  Created by Adam Maxwell on 10/06/05.
/*
 This software is Copyright (c) 2005,2006
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
#import "BibPrefController.h"
#import "NSImage+Toolbox.h"
#import <Carbon/Carbon.h>
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKTextWithIconCell.h"
#import "NSAttributedString_BDSKExtensions.h"
#import "BDSKSearch.h"

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
    
    results = [[NSMutableArray alloc] initWithCapacity:10];
    
    searchKey = [[NSString alloc] initWithString:@""];
        
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDocumentCloseNotification:) name:BDSKDocumentWindowWillCloseNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
    
    NSParameterAssert([aDocument conformsToProtocol:@protocol(BDSKSearchContentView)]);
    [self setDocument:aDocument];
    
    searchIndex = [[BDSKSearchIndex alloc] initWithDocument:aDocument];
    search = [[BDSKSearch alloc] initWithIndex:searchIndex delegate:self];

    return self;
}
    

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[statusBar unbind:@"stringValue"];
    [searchContentView release];
    [results release];
    [search release];
    [searchKey release];
    [super dealloc];
}

- (void)awakeFromNib
{
    [objectController setContent:self];
    [tableView setTarget:self];
    [tableView setDoubleAction:@selector(tableAction:)];
    
    NSLevelIndicatorCell *cell = [[tableView tableColumnWithIdentifier:@"score"] dataCell];
    OBASSERT([cell isKindOfClass:[NSLevelIndicatorCell class]]);
    [cell setLevelIndicatorStyle:NSRelevancyLevelIndicatorStyle]; // the default one makes the tableview unusably slow
    [cell setEnabled:NO]; // this is required to make it non-editable
    
    [spinner setUsesThreadedAnimation:NO];
    [spinner setDisplayedWhenStopped:NO];
    
    // set up the image/text cell combination
    BDSKTextWithIconCell *textCell = [[BDSKFileContentTextWithIconCell alloc] init];
    [textCell setControlSize:[cell controlSize]];
    [textCell setDrawsHighlight:NO];
    [[tableView tableColumnWithIdentifier:@"name"] setDataCell:textCell];
    [textCell release];
        
    // preserve sort behavior between launches (set in windowWillClose:)
    NSData *sortDescriptorData = [[NSUserDefaults standardUserDefaults] dataForKey:BDSKFileContentSearchSortDescriptorKey];
    if(sortDescriptorData != nil)
        [resultsArrayController setSortDescriptors:[NSUnarchiver unarchiveObjectWithData:sortDescriptorData]];
    
    OBPRECONDITION([[tableView enclosingScrollView] contentView]);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleClipViewFrameChangedNotification:)
                                                 name:NSViewFrameDidChangeNotification
                                               object:[[tableView enclosingScrollView] contentView]];    

    // Do custom view setup 
    [topBarView setEdges:BDSKMinXEdgeMask | BDSKMaxXEdgeMask];
    [topBarView setEdgeColor:[NSColor windowFrameColor]];
    [topBarView adjustSubviews];
    [statusBar toggleBelowView:[tableView enclosingScrollView] offset:0.0];
    statusBar = nil;
    
    // we might remove this, so keep a retained reference
    searchContentView = [[[self window] contentView] retain];

    // @@ workaround: the font from prefs seems to be overridden by the nib; maybe bindings issue?
    [tableView changeFont:nil];
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

- (NSArray *)titlesOfSelectedItems
{
    return [[resultsArrayController selectedObjects] valueForKey:@"title"];
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex{
    
    if([aCell isKindOfClass:[OATextWithIconCell class]])
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
}

- (void)handleClipViewFrameChangedNotification:(NSNotification *)note
{
    // work around for bug where corner view doesn't get redrawn after scrollers hide
    [[tableView cornerView] setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark Actions

- (void)tableAction:(id)sender
{
    int row = [tableView clickedRow];
    if(row == -1)
        return;
    
    BOOL isDir;
    NSURL *fileURL = [[[resultsArrayController arrangedObjects] objectAtIndex:row] valueForKey:@"url"];
    
    OBASSERT(fileURL);
    OBASSERT(searchKey);

    if(![[NSFileManager defaultManager] fileExistsAtPath:[fileURL path] isDirectory:&isDir]){
        NSBeginAlertSheet(NSLocalizedString(@"File Does Not Exist", @""),
                          nil /*default button*/,
                          nil /*alternate button*/,
                          nil /*other button*/,
                          [tableView window],nil,NULL,NULL,NULL,NSLocalizedString(@"The file at \"%@\" no longer exists.", @""), [fileURL path]);
    } else if(isDir){
        // just open it with the Finder; we shouldn't have folders in our index, though
        [[NSWorkspace sharedWorkspace] openURL:fileURL];
    } else if(![[NSWorkspace sharedWorkspace] openURL:fileURL withSearchString:searchKey]){
        NSBeginAlertSheet(NSLocalizedString(@"Unable to Open File", @""),
                          nil /*default button*/,
                          nil /*alternate button*/,
                          nil /*other button*/,
                          [tableView window],nil,NULL,NULL,NULL,NSLocalizedString(@"I was unable to open the file at \"%@.\"  You may wish to check permissions on the file or directory.", @""), [fileURL path]);
    }
}

- (IBAction)search:(id)sender
{
    [searchKey autorelease];
    searchKey = [[sender stringValue] copy];
    [self rebuildResultsWithNewSearch:searchKey];
}

- (void)restoreDocumentState:(id)sender
{
    [self saveSortDescriptors];
    [self cancelCurrentSearch:nil];
    [[self document] restoreDocumentStateByRemovingSearchView:[self searchContentView]];
}

#pragma mark -
#pragma mark Accessors

- (void)setResults:(NSArray *)newResults
{
    if(newResults != results){
        [results release];
        results = [newResults mutableCopy];
    }
}

- (NSMutableArray *)results
{
    return results;
}

#pragma mark -
#pragma mark SearchKit methods

- (void)search:(BDSKSearch *)aSearch didUpdateWithResults:(NSArray *)anArray;
{
    if ([search isEqual:aSearch]) {
        [self setResults:anArray];
    }
}

- (void)search:(BDSKSearch *)aSearch didFinishWithResults:(NSArray *)anArray;
{
    if ([search isEqual:aSearch]) {
        [spinner stopAnimation:self];
        [stopButton setEnabled:NO];
        [self setResults:anArray];
    }
}

- (void)cancelCurrentSearch:(id)sender
{
    [search cancel];
    [spinner stopAnimation:nil];
}    

- (void)rebuildResultsWithNewSearch:(NSString *)searchString
{            
    if([NSString isEmptyString:searchString]){
        [spinner stopAnimation:self];
        // iTunes/Mail swap out their search view when clearing the searchfield. don't clear the array, though, since we may need the array controller's selected objects
        [self restoreDocumentState:self];
    } else {
    
        // empty array; this takes care of updating the table for us
        [self setResults:[NSArray array]];

        [spinner startAnimation:self];
        
        [search searchForString:searchString withOptions:kSKSearchOptionDefault];
    }
}

#pragma mark -
#pragma mark Document interaction

- (void)handleDocumentCloseNotification:(NSNotification *)notification
{
    id aDocument = [notification object];
    
    // necessary, otherwise we end up creating a retain cycle
    if(aDocument == [self document]){
        
        // cancel the search
        [self cancelCurrentSearch:nil];
        
        // stops the search index runloop so it will release the document
        [searchIndex cancel];
        [searchIndex release];
        searchIndex = nil;

        [objectController setContent:nil];
	}
}

- (void)saveSortDescriptors
{
    NSData *sortDescriptorData = [NSArchiver archivedDataWithRootObject:[resultsArrayController sortDescriptors]];
    OBPRECONDITION(sortDescriptorData);
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:sortDescriptorData forKey:BDSKFileContentSearchSortDescriptorKey];
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

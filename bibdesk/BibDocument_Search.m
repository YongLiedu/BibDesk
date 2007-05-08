//
//  BibDocument_Search.m
//  Bibdesk
//
/*
 This software is Copyright (c) 2001,2002,2003,2004,2005,2006,2007
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
#import "BibTypeManager.h"
#import <AGRegex/AGRegex.h>
#import "BibItem.h"
#import "CFString_BDSKExtensions.h"
#import "BDSKFieldSheetController.h"
#import "BDSKSplitView.h"
#import "BDSKFileContentSearchController.h"
#import "BDSKGroupTableView.h"
#import "NSTableView_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKZoomablePDFView.h"
#import "BDSKPreviewer.h"
#import "BDSKOverlay.h"
#import "BibDocument_Groups.h"
#import "BDSKMainTableView.h"
#import "BDSKFindController.h"
#import <OmniAppKit/OAFindControllerTargetProtocol.h>
#import <OmniAppKit/NSText-OAExtensions.h>
#import "BDSKSearchButtonController.h"
#import "BDSKItemSearchIndexes.h"
#import "NSArray_BDSKExtensions.h"
#import "BDSKGroup.h"
#import "BDSKSharedGroup.h"
#import "BDSKOwnerProtocol.h"

@implementation BibDocument (Search)

- (IBAction)changeSearchType:(id)sender{
    [[OFPreferenceWrapper sharedPreferenceWrapper] setInteger:[sender tag] forKey:BDSKSearchMenuTagKey];
    [self search:searchField];
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
        [searchField sendAction:[searchField action] to:[searchField target]];
    }
}

- (void)buttonBarSelectionDidChange:(NSNotification *)aNotification;
{
    NSString *field = [searchButtonController selectedItemIdentifier];
    if (searchButtonController && nil == field) {
        OBASSERT_NOT_REACHED("the search button controller should always have a selected field");
        [searchButtonController selectItemWithIdentifier:BDSKAllFieldsString];
        field = BDSKAllFieldsString;
    }
    
    if([field isEqualToString:BDSKFileContentSearchString]) {
        [self searchByContent:nil];
    } else {
        if ([[[fileSearchController searchContentView] window] isEqual:documentWindow])
            [fileSearchController restoreDocumentState];
        
        NSArray *pubsToSelect = [self selectedPublications];
        NSString *searchString = [searchField stringValue];
        
        if([NSString isEmptyString:searchString]){
            [shownPublications setArray:groupedPublications];

        } else {
            
            [shownPublications setArray:[self publicationsMatchingSearchString:searchString indexName:field fromArray:groupedPublications]];
            if([shownPublications count] == 1)
                pubsToSelect = [NSMutableArray arrayWithObject:[shownPublications lastObject]];
        }
        
        [tableView deselectAll:nil];
        [self sortPubsByKey:nil];
        [self updateStatus];
        if([pubsToSelect count])
            [self selectPublications:pubsToSelect];
    }
}

/* 

Ensure that views are always ordered vertically from top to bottom as

---- toolbar
---- search button view
---- search group view OR file content

*/

- (void)showSearchButtonView;
{
    if (nil == searchButtonController)
        searchButtonController = [[BDSKSearchButtonController alloc] init];
    
    [searchButtonController setDelegate:self];
    
    if ([self hasExternalGroupsSelected]) {
        [searchButtonController removeSkimNotesItem];
        [searchButtonController removeFileContentItem];
    } else {
        [searchButtonController addSkimNotesItem];
        [searchButtonController addFileContentItem];
    }
    
    NSView *searchButtonView = [searchButtonController view];
    
    if ([self isDisplayingSearchButtons] == NO) {
        [searchButtonController selectItemWithIdentifier:BDSKAllFieldsString];
        [self insertControlView:searchButtonView atTop:YES];
        if ([tableView tableColumnWithIdentifier:BDSKRelevanceString] == nil)
            [tableView insertTableColumnWithIdentifier:BDSKRelevanceString atIndex:0];
        
    }
}

- (void)hideSearchButtonView
{
    NSView *searchButtonView = [searchButtonController view];
    if ([self isDisplayingSearchButtons]) {
        [tableView removeTableColumnWithIdentifier:BDSKRelevanceString];
        [self removeControlView:searchButtonView];
        [searchButtonController selectItemWithIdentifier:BDSKAllFieldsString];
        
        if ([previousSortKey isEqualToString:BDSKRelevanceString]) {
            [previousSortKey release];
            previousSortKey = [BDSKTitleString retain];
        }
        if ([sortKey isEqualToString:BDSKRelevanceString]) {
            NSString *newSortKey = [[previousSortKey retain] autorelease];
            docState.sortDescending = NO;
            [self sortPubsByKey:newSortKey];
        }
    }
    [searchButtonController setDelegate:nil];
}

- (IBAction)search:(id)sender{
    if ([[sender stringValue] isEqualToString:@""])
        [self hideSearchButtonView];
    else [self showSearchButtonView];
    
    [self buttonBarSelectionDidChange:nil];
}

#pragma mark -

// simplified search used by BibAppController's Service for legacy compatibility
- (NSArray *)publicationsMatchingSubstring:(NSString *)searchString inField:(NSString *)field{
    unsigned i, iMax = [publications count];
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:100];
    for (i = 0; i < iMax; i++) {
        BibItem *pub = [publications objectAtIndex:i];
        if ([pub matchesSubstring:searchString withOptions:NSCaseInsensitiveSearch inField:field removeDiacritics:YES])
            [results addObject:pub];
    }
    return results;
}


NSString *BDSKSearchKitExpressionWithString(NSString *searchFieldString)
{
    // surround with wildcards for substring search; should we check for any operators?
    if ([[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKSearchMenuTagKey] == 0)
        searchFieldString = [NSString stringWithFormat:@"*%@*", searchFieldString];
    return searchFieldString;
}

#define SEARCH_BUFFER_MAX 100
        
- (NSArray *)publicationsMatchingSearchString:(NSString *)searchString indexName:(NSString *)field fromArray:(NSArray *)arrayToSearch{
    
    searchString = BDSKSearchKitExpressionWithString(searchString);
    
    NSMutableArray *toReturn = [NSMutableArray arrayWithCapacity:[arrayToSearch count]];
    
    // we need the correct BDSKPublicationsArray for access to the identifierURLs
    id<BDSKOwner> owner = [self hasExternalGroupsSelected] ? [[self selectedGroups] firstObject] : self;
    SKIndexRef skIndex = [[owner searchIndexes] indexForField:field];
    BDSKPublicationsArray *pubArray = [owner publications];
    
    NSAssert1(NULL != skIndex, @"No index for field %@", field);
    
    // note that the add/remove methods flush the index, so we don't have to do it again
    SKSearchRef search = SKSearchCreate(skIndex, (CFStringRef)searchString, kSKSearchOptionDefault);
    
    SKDocumentID documents[SEARCH_BUFFER_MAX];
    float scores[SEARCH_BUFFER_MAX];
    CFIndex i, foundCount;
    NSMutableSet *foundURLSet = [NSMutableSet set];
    
    Boolean more;
    BibItem *aPub;
    float maxScore = 0.0f;
    
    do {
        
        more = SKSearchFindMatches(search, SEARCH_BUFFER_MAX, documents, scores, 1.0, &foundCount);
        
        if (foundCount) {
            CFURLRef documentURLs[SEARCH_BUFFER_MAX];
            SKIndexCopyDocumentURLsForDocumentIDs(skIndex, foundCount, documents, documentURLs);
            
            for (i = 0; i < foundCount; i++) {
                [foundURLSet addObject:(id)documentURLs[i]];
                aPub = [pubArray itemForIdentifierURL:(NSURL *)documentURLs[i]];
                CFRelease(documentURLs[i]);
                [aPub setSearchScore:scores[i]];
                maxScore = MAX(maxScore, scores[i]);
            }
        }
                    
    } while (foundCount && more);
            
    SKSearchCancel(search);
    CFRelease(search);
    
    // we searched all publications, but we only want to keep the subset that's shown (if a group is selected)
    NSMutableSet *identifierURLsToKeep = [NSMutableSet setWithArray:[arrayToSearch valueForKey:@"identifierURL"]];
    [foundURLSet intersectSet:identifierURLsToKeep];
    
    NSEnumerator *keyEnum = [foundURLSet objectEnumerator];
    NSURL *aURL;

    // iterate and normalize search scores
    while (aURL = [keyEnum nextObject]) {
        aPub = [pubArray itemForIdentifierURL:aURL];
        if (aPub) {
            [toReturn addObject:aPub];
            float score = [aPub searchScore];
            [aPub setSearchScore:(score/maxScore)];
        }
    }

    return toReturn;
}

#pragma mark File Content Search

- (IBAction)searchByContent:(id)sender
{
    // @@ File content search isn't really compatible with the group concept yet; this allows us to select publications when the content search is done, and also provides some feedback to the user that all pubs will be searched.  This is ridiculously complicated since we need to avoid calling searchByContent: in a loop.
    [tableView deselectAll:nil];
    [groupTableView updateHighlights];
    
    // here we avoid the table selection change notification that will result in an endless loop
    id tableDelegate = [groupTableView delegate];
    [groupTableView setDelegate:nil];
    [groupTableView deselectAll:nil];
    [groupTableView setDelegate:tableDelegate];
    
    // this is what displaySelectedGroup normally ends up doing
    [self handleGroupTableSelectionChangedNotification:nil];
    [self sortPubsByKey:nil];
    
    if(fileSearchController == nil){
        fileSearchController = [[BDSKFileContentSearchController alloc] initForDocument:self];
        NSData *sortDescriptorData = [[self mainWindowSetupDictionaryFromExtendedAttributes] objectForKey:BDSKFileContentSearchSortDescriptorKey defaultObject:[[NSUserDefaults standardUserDefaults] dataForKey:BDSKFileContentSearchSortDescriptorKey]];
        if(sortDescriptorData)
            [fileSearchController setSortDescriptorData:sortDescriptorData];
    }
    
    NSView *contentView = [fileSearchController searchContentView];
    NSRect frame = [splitView frame];
    [contentView setFrame:frame];
    [contentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [mainBox addSubview:contentView];
    
    if (BDSKDefaultAnimationTimeInterval > 0.0) {
        NSViewAnimation *animation;
        NSDictionary *fadeOutDict = [[NSDictionary alloc] initWithObjectsAndKeys:splitView, NSViewAnimationTargetKey, NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil];
        NSDictionary *fadeInDict = [[NSDictionary alloc] initWithObjectsAndKeys:contentView, NSViewAnimationTargetKey, NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil];

        animation = [[[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObjects:fadeOutDict, fadeInDict, nil]] autorelease];
        [fadeOutDict release];
        [fadeInDict release];
        
        [animation setAnimationBlockingMode:NSAnimationBlocking];
        [animation setDuration:BDSKDefaultAnimationTimeInterval];
        [animation setAnimationCurve:NSAnimationEaseIn];
        [animation startAnimation];
    }
    
    [[previewer progressOverlay] remove];
    
    [splitView removeFromSuperview];
    // connect the searchfield to the controller and start the search
    [fileSearchController setSearchField:searchField];
}

// Method required by the BDSKSearchContentView protocol; the implementor is responsible for restoring its state by removing the view passed as an argument and resetting search field target/action.
- (void)_restoreDocumentStateByRemovingSearchView:(NSView *)view
{
    
    NSRect frame = [view frame];
    [splitView setFrame:frame];
    [mainBox addSubview:splitView];
    
    if(currentPreviewView != [previewTextView enclosingScrollView])
        [[previewer progressOverlay] overlayView:currentPreviewView];
    
    if (BDSKDefaultAnimationTimeInterval > 0.0) {
        NSViewAnimation *animation;
        NSDictionary *fadeOutDict = [[NSDictionary alloc] initWithObjectsAndKeys:view, NSViewAnimationTargetKey, NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil];
        NSDictionary *fadeInDict = [[NSDictionary alloc] initWithObjectsAndKeys:splitView, NSViewAnimationTargetKey, NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil];
        
        animation = [[[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObjects:fadeOutDict, fadeInDict, nil]] autorelease];
        [fadeOutDict release];
        [fadeInDict release];
        
        [animation setAnimationBlockingMode:NSAnimationBlocking];
        [animation setDuration:BDSKDefaultAnimationTimeInterval];
        [animation setAnimationCurve:NSAnimationEaseIn];
        [animation setDelegate:self];
        [animation startAnimation];
    }
    
    [[fileSearchController searchContentView] removeFromSuperview];
    
    // reconnect the searchfield
    [searchField setTarget:self];
    [searchField setDelegate:self];
    
    NSArray *titlesToSelect = [fileSearchController titlesOfSelectedItems];
    
    if([titlesToSelect count]){
        
        // clear current selection (just in case)
        [tableView deselectAll:nil];
        
        // we match based on title, since that's all the index knows about the BibItem at present
        NSMutableArray *pubsToSelect = [NSMutableArray array];
        NSEnumerator *pubEnum = [shownPublications objectEnumerator];
        BibItem *item;
        while(item = [pubEnum nextObject])
            if([titlesToSelect containsObject:[item displayTitle]]) 
                [pubsToSelect addObject:item];
        [self selectPublications:pubsToSelect];
        [tableView scrollRowToCenter:[tableView selectedRow]];
        
        // if searchfield doesn't have focus (user clicked cancel button), switch to the tableview
        if ([[documentWindow firstResponder] isEqual:[searchField currentEditor]] == NO)
            [documentWindow makeFirstResponder:(NSResponder *)tableView];
    }
    
    [mainBox setNeedsDisplay:YES];
    
    // _restoreDocumentStateByRemovingSearchView may be called after the user clicks a different search type, without changing the searchfield; in that case, we want to leave the search button view in place, and refilter the list
    if ([[searchField stringValue] isEqualToString:@""])
        [self hideSearchButtonView];  
    else
        [searchButtonController selectItemWithIdentifier:BDSKAllFieldsString];
}

#pragma mark Find panel

- (NSString *)selectedStringForFind;
{
    if([currentPreviewView isHidden])
        return nil;
    if(currentPreviewView != [previewTextView enclosingScrollView]){
        NSTextView *textView = (NSTextView *)[(NSScrollView *)currentPreviewView documentView];
        NSRange selRange = [textView selectedRange];
        if (selRange.location == NSNotFound)
            return nil;
        return [[textView string] substringWithRange:selRange];
    }else if([currentPreviewView isKindOfClass:[BDSKZoomablePDFView class]]){
        return [[(BDSKZoomablePDFView *)currentPreviewView currentSelection] string];
    }
    return nil;
}

// OAFindControllerAware informal protocol
- (id <OAFindControllerTarget>)omniFindControllerTarget;
{
    if([currentPreviewView isKindOfClass:[NSScrollView class]] && [currentPreviewView isHidden] == NO)
        return [(NSScrollView *)currentPreviewView documentView];
    else
        return nil;
}

- (IBAction)performFindPanelAction:(id)sender{
    NSString *selString = nil;

	switch ([sender tag]) {
        case NSFindPanelActionShowFindPanel:
        case NSFindPanelActionNext:
        case NSFindPanelActionPrevious:
            if([currentPreviewView isKindOfClass:[NSScrollView class]] && [currentPreviewView isHidden] == NO)
                [(NSTextView *)[(NSScrollView *)currentPreviewView documentView] performFindPanelAction:sender];
            else
                NSBeep();
            break;
		case NSFindPanelActionSetFindString:
            selString = [self selectedStringForFind];
            if ([NSString isEmptyString:selString])
                return;
            id firstResponder = [documentWindow firstResponder];
            if (firstResponder == searchField || ([firstResponder isKindOfClass:[NSText class]] && [firstResponder delegate] == searchField)) {
                [searchField setStringValue:selString];
                [searchField selectText:nil];
            } else {
                [[BDSKFindController sharedFindController] setFindString:selString];
                [previewTextView performFindPanelAction:sender];
            }
            break;
        default:
            NSBeep();
            break;
	}
}

@end

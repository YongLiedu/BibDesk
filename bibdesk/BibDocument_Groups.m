//
//  BibDocument_Groups.m
//  Bibdesk
//
/*
 This software is Copyright (c) 2005-2016
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

#import "BibDocument_Groups.h"
#import "BDSKGroupsArray.h"
#import "BDSKOwnerProtocol.h"
#import "BibDocument_Actions.h"
#import "BDSKGroupCell.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKFilterController.h"
#import "BDSKGroupOutlineView.h"
#import "BibDocument_Search.h"
#import "BibDocument_UI.h"
#import "BibDocument_DataSource.h"
#import "BDSKGroup.h"
#import "BDSKSharedGroup.h"
#import "BDSKURLGroup.h"
#import "BDSKScriptGroup.h"
#import "BDSKSmartGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKCategoryGroup.h"
#import "BDSKWebGroup.h"
#import "BDSKParentGroup.h"
#import "BDSKFieldSheetController.h"
#import "BibItem.h"
#import "BibAuthor.h"
#import "BDSKAppController.h"
#import "BDSKTypeManager.h"
#import "BDSKSharingBrowser.h"
#import "NSArray_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKURLGroupSheetController.h"
#import "BDSKScriptGroupSheetController.h"
#import "BDSKEditor.h"
#import "BDSKPersonController.h"
#import "BDSKCollapsibleView.h"
#import "BDSKSearchGroup.h"
#import "BDSKMainTableView.h"
#import "BDSKWebGroupViewController.h"
#import "BDSKSearchGroupSheetController.h"
#import "BDSKSearchGroupViewController.h"
#import "BDSKServerInfo.h"
#import "BDSKSearchBookmarkController.h"
#import "BDSKSearchBookmark.h"
#import "BDSKSharingClient.h"
#import "NSColor_BDSKExtensions.h"
#import "NSView_BDSKExtensions.h"
#import "BDSKCFCallBacks.h"
#import "BDSKFileContentSearchController.h"
#import "NSEvent_BDSKExtensions.h"
#import "NSSplitView_BDSKExtensions.h"
#import "BDSKButtonBar.h"
#import "NSMenu_BDSKExtensions.h"
#import "BDSKBookmarkSheetController.h"
#import "BDSKBookmarkController.h"
#import "NSPasteboard_BDSKExtensions.h"
#import "NSTableView_BDSKExtensions.h"
#import "NSWorkspace_BDSKExtensions.h"


@implementation BibDocument (Groups)

#pragma mark Selected group types

- (BOOL)hasGroupTypeSelected:(BDSKGroupType)groupType {
    return NSNotFound != [[self selectedGroups] indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        return (BOOL)(([obj groupType] & groupType) != 0);
    }];
}

- (BOOL)hasGroupTypeClickedOrSelected:(BDSKGroupType)groupType {
    return NSNotFound != [[self clickedOrSelectedGroups] indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop){
        return (BOOL)(([obj groupType] & groupType) != 0);
    }];
}

/* 
The groupedPublications array is a subset of the publications array, developed by searching the publications array; shownPublications is now a subset of the groupedPublications array, and searches in the searchfield will search only within groupedPublications (which may include all publications).
*/

- (NSArray *)currentGroupFields{
	return [[groups categoryParents] valueForKey:@"key"];
}

- (void)addCurrentGroupField:(NSString *)newField {
    if ([[self currentGroupFields] containsObject:newField] == NO) {
        BDSKCategoryParentGroup *group = [[[BDSKCategoryParentGroup alloc] initWithKey:newField] autorelease];
        [groups addCategoryParent:group];
        [self updateCategoryGroups:group];
        [groupOutlineView expandItem:group];
        [[NSUserDefaults standardUserDefaults] setObject:[self currentGroupFields] forKey:BDSKCurrentGroupFieldsKey];
    }
}

- (void)removeCurrentGroupField:(NSString *)oldField {
    for (BDSKCategoryParentGroup *group in [groups categoryParents]) {
        if ([[group key] isEqualToString:oldField]) {
            [group retain];
            [groups removeCategoryParent:group];
            [self updateCategoryGroups:group];
            [group release];
            [[NSUserDefaults standardUserDefaults] setObject:[self currentGroupFields] forKey:BDSKCurrentGroupFieldsKey];
            break;
        }
    }
    
}

- (void)setCurrentGroupField:(NSString *)newField forGroup:(BDSKCategoryParentGroup *)group {
    if ([[self currentGroupFields] containsObject:newField] == NO) {
        [group setKey:newField];
        [self updateCategoryGroups:group];
        [[NSUserDefaults standardUserDefaults] setObject:[self currentGroupFields] forKey:BDSKCurrentGroupFieldsKey];
    }
    
}

- (NSArray *)selectedGroups {
    return [groupOutlineView selectedItems];
}

- (NSArray *)clickedOrSelectedGroups {
    return [groupOutlineView itemsAtRowIndexes:[groupOutlineView clickedOrSelectedRowIndexes]];
}

#pragma mark Search group view

- (void)showSearchGroupView {
    if (nil == searchGroupViewController)
        searchGroupViewController = [[BDSKSearchGroupViewController alloc] init];
    [self addControlView:[searchGroupViewController view]];
    
    BDSKSearchGroup *group = [[self selectedGroups] firstObject];
    BDSKASSERT([group groupType] == BDSKSearchGroupType);
    [searchGroupViewController setGroup:group];
}

- (void)hideSearchGroupView
{
    [self removeControlView:[searchGroupViewController view]];
    [searchGroupViewController setGroup:nil];
}


#pragma mark Web Group 

- (void)showWebGroupView {
    if (webGroupViewController == nil)
        webGroupViewController = [[BDSKWebGroupViewController alloc] init];
    [self addControlView:[webGroupViewController view]];
    
    WebView *oldWebView = [webGroupViewController webView];
    
    BDSKWebGroup *group = [[self selectedGroups] firstObject];
    BDSKASSERT([group groupType] == BDSKWebGroupType);
    
    // load our start page when this was not used before, this must be done before calling [group webView]
    if ([group isWebViewLoaded] == NO)
        [group setURL:[NSURL URLWithString:@"bibdesk:webgroup"]];
    
    [webGroupViewController setWebView:[group webView]];
    
    NSView *webView = [group webView];
    if ([webView window] == nil) {
        if ([oldWebView window]) {
            [webView setFrame:[oldWebView frame]];
            [splitView replaceSubview:oldWebView with:webView];
        } else {
            NSView *view1 = [[splitView subviews] objectAtIndex:0];
            NSView *view2 = [[splitView subviews] objectAtIndex:1];
            NSRect svFrame = [splitView bounds];
            NSRect webFrame = svFrame;
            NSRect tableFrame = svFrame;
            NSRect previewFrame = svFrame;
            CGFloat height = NSHeight(svFrame) - 2 * [splitView dividerThickness];
            CGFloat oldFraction = [splitView fraction];
            
            if (docState.lastWebViewFraction <= 0.0)
                docState.lastWebViewFraction = 0.4;
            
            webFrame.size.height = round(height * docState.lastWebViewFraction);
            previewFrame.size.height = round((height - NSHeight(webFrame)) * oldFraction);
            tableFrame.size.height = height - NSHeight(webFrame) - NSHeight(previewFrame);
            tableFrame.origin.y = NSMaxY(webFrame) + [splitView dividerThickness];
            previewFrame.origin.y = NSMaxY(tableFrame) + [splitView dividerThickness];
            
            [webView setFrame:webFrame];
            [splitView addSubview:webView positioned:NSWindowBelow relativeTo:mainView];
            [webView setFrame:webFrame];
            [view1 setFrame:tableFrame];
            [view2 setFrame:previewFrame];
            [splitView adjustSubviews];
            [splitView setNeedsDisplay:YES];
        }
    }
}

- (void)hideWebGroupView{
    NSView *webView = [webGroupViewController webView];
    if ([webView window]) {
        NSView *webGroupView = [webGroupViewController view];
        id firstResponder = [documentWindow firstResponder];
        if ([firstResponder respondsToSelector:@selector(isDescendantOf:)] && [firstResponder isDescendantOf:webGroupView])
            [documentWindow makeFirstResponder:tableView];
        docState.lastWebViewFraction = NSHeight([webView frame]) / fmax(1.0, NSHeight([splitView frame]) - 2 * [splitView dividerThickness]);
        [webView removeFromSuperview];
        [splitView adjustSubviews];
        [splitView setNeedsDisplay:YES];
    }
    
    [self removeControlView:[webGroupViewController view]];
    [webGroupViewController setWebView:nil];
}

#pragma mark Notification handlers

- (void)handleFilterChangedNotification:(NSNotification *)notification{
    if (NSNotFound != [[groups smartGroups] indexOfObjectIdenticalTo:[notification object]])
        [self updateSmartGroups];
}

- (void)handleGroupTableSelectionChangedNotification:(NSNotification *)notification{
    // called with notification == nil from showFileContentSearch, shouldn't redisplay group content in that case to avoid a loop
    
    NSString *newSortKey = nil;
    
    if ([self hasGroupTypeSelected:BDSKExternalGroupType]) {
        if ([self isDisplayingSearchButtons]) {
            
            // file content and skim notes search are not compatible with external groups
            if ([BDSKFileContentSearchString isEqualToString:[searchButtonBar representedObjectOfSelectedButton]] || 
                [BDSKSkimNotesString isEqualToString:[searchButtonBar representedObjectOfSelectedButton]])
                [searchButtonBar selectButtonWithRepresentedObject:BDSKAllFieldsString];
            
            [self removeFileSearchItems];
        }
        
        BOOL wasSearch = [self isDisplayingSearchGroupView];
        BOOL wasWeb = [self isDisplayingWebGroupView];
        BOOL isSearch = [self hasGroupTypeSelected:BDSKSearchGroupType];
        BOOL isWeb = [self hasGroupTypeSelected:BDSKWebGroupType];
        
        if (isSearch == NO && wasSearch)
            [self hideSearchGroupView];            
        if (isWeb == NO && wasWeb)
            [self hideWebGroupView];
        if (isWeb) {
            if (wasWeb == NO)
                newSortKey = BDSKImportOrderString;
            [self showWebGroupView];
        }
        if (isSearch) {
            if (wasSearch == NO)
                newSortKey = BDSKImportOrderString;
            [self showSearchGroupView];
        }
        [tableView setAlternatingRowBackgroundColors:[NSColor alternateControlAlternatingRowBackgroundColors]];
        [tableView addTableColumnWithIdentifier:BDSKImportOrderString];
        
    } else {
        if ([self isDisplayingSearchButtons]) {
            [self addFileSearchItems];
        }
        
        [tableView setAlternatingRowBackgroundColors:[NSColor controlAlternatingRowBackgroundColors]];
        [tableView removeTableColumnWithIdentifier:BDSKImportOrderString];
        if ([tmpSortKey isEqualToString:BDSKImportOrderString])
            newSortKey = sortKey;
        [self hideSearchGroupView];
        [self hideWebGroupView];
    }
    // Mail and iTunes clear search when changing groups; users don't like this, though.  Xcode doesn't clear its search field, so at least there's some precedent for the opposite side.
    if (notification)
        [self displaySelectedGroups];
    if (newSortKey)
        [self sortPubsByKey:newSortKey];
    // could force selection of row 0 in the main table here, so we always display a preview, but that flashes the group table highlights annoyingly and may cause other selection problems
}

- (void)handleGroupNameChangedNotification:(NSNotification *)notification{
    if([[notification object] document] == self) {
        if ([sortGroupsKey isEqualToString:BDSKGroupCellStringKey])
            [self sortGroupsByKey:nil];
        else
            [groupOutlineView setNeedsDisplay:YES];
    }
}

- (void)handleStaticGroupChangedNotification:(NSNotification *)notification{
    BDSKGroup *group = [notification object];
    
    if ([[groups staticGroups] containsObject:group] == NO && [group isEqual:[groups lastImportGroup]] == NO)
        return; /// must be from another document
    
    [groupOutlineView reloadData];
    if ([[self selectedGroups] containsObject:group])
        [self displaySelectedGroups];
}

- (void)handleSharedGroupsChangedNotification:(NSNotification *)notification{

    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    [groupOutlineView setDelegate:nil];
	NSArray *selectedGroups = [self selectedGroups];
	
    NSMutableSet *clientsToAdd = [[[BDSKSharingBrowser sharedBrowser] sharingClients] mutableCopy];
    NSMutableArray *currentGroups = [[groups sharedGroups] mutableCopy];
    NSArray *currentClients = [currentGroups valueForKey:@"client"];
    NSSet *currentClientsSet = [NSSet setWithArray:currentClients];
    NSMutableSet *clientsToRemove = [currentClientsSet mutableCopy];
    
    [clientsToRemove minusSet:clientsToAdd];
    [clientsToAdd minusSet:currentClientsSet];
    
    [currentGroups removeObjectsAtIndexes:[currentClients indexesOfObjects:[clientsToRemove allObjects]]];
    
    for (BDSKSharingClient *client in clientsToAdd) {
        BDSKSharedGroup *group = [(BDSKSharedGroup *)[BDSKSharedGroup alloc] initWithClient:client];
        [currentGroups addObject:group];
        [group release];
    }
    
    [groups setSharedGroups:currentGroups];
    
    [clientsToRemove release];
    [clientsToAdd release];
    [currentGroups release];
    
    [self removeSpinnersFromSuperview];
    [groupOutlineView reloadData];
    
	// reset ourself as delegate
    [groupOutlineView setDelegate:self];
	
	// select the current groups, if still around. Otherwise this selects Library
    [self selectGroups:selectedGroups];
    
    // the selection may not have changed, so we won't get this from the notification, and we're not the delegate now anyway
    [self displaySelectedGroups]; 
        
    // Don't flag as imported here, since that forces a (re)load of the shared groups, and causes the spinners to start when just opening a document.  The handleSharedGroupUpdatedNotification: should be enough.
}

- (void)handleExternalGroupUpdatedNotification:(NSNotification *)notification{
    BDSKExternalGroup *group = [notification object];
    
    if ([[group document] isEqual:self]) {
        BOOL succeeded = [[[notification userInfo] objectForKey:BDSKExternalGroupSucceededKey] boolValue];
        BOOL isWeb = [group groupType] == BDSKWebGroupType;
        
        if (isWeb == NO && [sortGroupsKey isEqualToString:BDSKGroupCellCountKey]) {
            [self sortGroupsByKey:nil];
        } else {
            [groupOutlineView reloadData];
            if ([[self selectedGroups] containsObject:group]) {
                if (isWeb || succeeded)
                    [self displaySelectedGroups];
                else
                    [self updateStatus];
            }
        }
        
        if (succeeded)
            [self setImported:YES forPublications:publications inGroup:group];
    }
}

- (void)handleWillRemoveGroupsNotification:(NSNotification *)notification{
    if([groupOutlineView editedRow] != -1 && [documentWindow makeFirstResponder:nil] == NO)
        [documentWindow endEditingFor:groupOutlineView];
    for (BDSKGroup *group in [[notification userInfo] valueForKey:BDSKGroupsArrayGroupsKey])
        [self removeSpinnerForGroup:group];
}

- (void)handleDidAddRemoveGroupNotification:(NSNotification *)notification{
    [self removeSpinnersFromSuperview];
    [groupOutlineView reloadData];
    [self handleGroupTableSelectionChangedNotification:notification];
}

#pragma mark UI updating

typedef struct _setAndBagContext {
    CFMutableSetRef set;
    CFMutableBagRef bag;
} setAndBagContext;

static void addObjectToSetAndBag(const void *value, void *context) {
    setAndBagContext *ctxt = context;
    CFSetAddValue(ctxt->set, value);
    CFBagAddValue(ctxt->bag, value);
}

// this method uses counted sets to compute the number of publications per group; each group object is just a name
// and a count, and a group knows how to compare itself with other groups for sorting/equality, but doesn't know 
// which pubs are associated with it
- (void)updateCategoryGroups:(BDSKCategoryParentGroup *)parent {

    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    docFlags.ignoreGroupSelectionChange = YES;
    
    NSPoint scrollPoint = [tableView scrollPositionAsPercentage];    
    
	NSArray *selectedGroups = [self selectedGroups];
    
    NSArray *parentsToUpdate = [groups categoryParents]; // update all when parents == nil
    if ([parentsToUpdate containsObject:parent]) // after adding this parent only update this one
        parentsToUpdate = [NSArray arrayWithObjects:parent, nil];
    else if (parent) // after removing this parent don't need to update any
        parentsToUpdate = nil;
	
    for (parent in parentsToUpdate) {
        
        NSString *groupField = [parent key];
        
        setAndBagContext setAndBag;
        if([groupField isPersonField]) {
            setAndBag.set = CFSetCreateMutable(kCFAllocatorDefault, 0, &kBDSKAuthorFuzzySetCallBacks);
            setAndBag.bag = CFBagCreateMutable(kCFAllocatorDefault, 0, &kBDSKAuthorFuzzyBagCallBacks);
        } else {
            setAndBag.set = CFSetCreateMutable(kCFAllocatorDefault, 0, &kBDSKCaseInsensitiveStringSetCallBacks);
            setAndBag.bag = CFBagCreateMutable(kCFAllocatorDefault, 0, &kBDSKCaseInsensitiveStringBagCallBacks);
        }
        
        NSArray *oldGroups = [parent categoryGroups];
        NSArray *oldGroupNames = [NSArray array];
        
        if ([groupField isEqualToString:[[oldGroups lastObject] key]] && [groupField isPersonField] == [[(BDSKGroup *)[oldGroups lastObject] name] isKindOfClass:[BibAuthor class]])
            oldGroupNames = [oldGroups valueForKey:@"name"];
        else
            oldGroups = nil;
        
        NSInteger emptyCount = 0;
        
        NSSet *tmpSet = nil;
        for (BibItem *pub in publications) {
            tmpSet = [pub groupsForField:groupField];
            if([tmpSet count])
                CFSetApplyFunction((CFSetRef)tmpSet, addObjectToSetAndBag, &setAndBag);
            else
                emptyCount++;
        }
        
        NSMutableArray *mutableGroups = [[NSMutableArray alloc] initWithCapacity:CFSetGetCount(setAndBag.set) + 1];
        BDSKGroup *group;
                
        // now add the group names that we found from our BibItems, using a generic folder icon
        for (id groupName in (NSSet *)(setAndBag.set)) {
            NSUInteger idx = [oldGroupNames indexOfObject:groupName];
            if (idx == NSNotFound)
                group = [[BDSKCategoryGroup alloc] initWithName:groupName key:groupField];
            else
                group = [[oldGroups objectAtIndex:idx] retain];
            [group setCount:CFBagGetCountOfValue(setAndBag.bag, groupName)];
            [mutableGroups addObject:group];
            [group release];
        }
        
        // add the "empty" group at index 0; this is a group of pubs whose value is empty for this field, so they
        // will not be contained in any of the other groups for the currently selected group field (hence multiple selection is desirable)
        if (emptyCount > 0) {
            if ([oldGroups count] && [[oldGroups objectAtIndex:0] isEmpty])
                group = [[oldGroups objectAtIndex:0] retain];
            else
                group = [[BDSKCategoryGroup alloc] initWithName:nil key:groupField];
            [group setCount:emptyCount];
            [mutableGroups insertObject:group atIndex:0];
            [group release];
        }
        
        [groups setCategoryGroups:mutableGroups forParent:parent];
        CFRelease(setAndBag.set);
        CFRelease(setAndBag.bag);
        [mutableGroups release];
        
    }
    
    // update the count for the first item, not sure if it should be done here
    [[groups libraryGroup] setCount:[publications count]];
	
    [self removeSpinnersFromSuperview];
    [groupOutlineView reloadData];
	
	// select the current groups, if still around. Otherwise select Library
	BOOL didSelect = [self selectGroups:selectedGroups];
    
	[self displaySelectedGroups]; // the selection may not have changed, so we won't get this from the notification
    
    // The search: in displaySelectedGroups will change the main table's scroll location, which isn't necessarily what we want (say when clicking the add button for a search group pub).  If we selected the same groups as previously, we should scroll to the old location instead of centering.
    if (didSelect)
        [tableView setScrollPositionAsPercentage:scrollPoint];
    
	// reset
    docFlags.ignoreGroupSelectionChange = NO;
}

// force the smart groups to refilter their items, so the group content and count get redisplayed
// if this becomes slow, we could make filters thread safe and update them in the background
- (void)updateSmartGroupsCountAndContent:(BOOL)shouldUpdate{
    
	// !!! early return if not expanded in outline view
    if ([groupOutlineView isItemExpanded:[groups smartParent]] == NO)
        return;
    
    BOOL needsUpdate = shouldUpdate && [self hasGroupTypeSelected:BDSKSmartGroupType];
    BOOL hideCount = [[NSUserDefaults standardUserDefaults] boolForKey:BDSKHideGroupCountKey];
    BOOL sortByCount = [sortGroupsKey isEqualToString:BDSKGroupCellCountKey];
    NSArray *smartGroups = [groups smartGroups];
    
    if (hideCount == NO || sortByCount)
        [smartGroups makeObjectsPerformSelector:@selector(filterItems:) withObject:publications];
    
    if (sortByCount) {
        NSPoint scrollPoint = [groupOutlineView scrollPositionAsPercentage];
        [self sortGroupsByKey:nil];
        [groupOutlineView setScrollPositionAsPercentage:scrollPoint];
    } else if (needsUpdate) {
        [groupOutlineView reloadData];
        // fix for bug #1362191: after changing a checkbox that removed an item from a smart group, the table scrolled to the top
        NSPoint scrollPoint = [groupOutlineView scrollPositionAsPercentage];
        [self displaySelectedGroups];
        [groupOutlineView setScrollPositionAsPercentage:scrollPoint];
    } else if (hideCount == NO) {
        [groupOutlineView reloadData];
    }
}

- (void)updateSmartGroupsCount {
    [self updateSmartGroupsCountAndContent:NO];
}

- (void)updateSmartGroups {
    [self updateSmartGroupsCountAndContent:YES];
}

- (void)displaySelectedGroups{
    NSArray *selectedGroups = [self selectedGroups];
    NSArray *array;
    
    // optimize for single selections
    if ([selectedGroups count] == 1) {
        array = [(BDSKGroup *)[selectedGroups lastObject] publications];
    } else {
        // multiple selections are never shared groups, so they are contained in the publications
        NSMutableArray *filteredArray = [NSMutableArray arrayWithCapacity:[publications count]];
        BOOL intersectGroups = [[NSUserDefaults standardUserDefaults] boolForKey:BDSKIntersectGroupsKey];
        
        // to take union, we add the items contained in a selected group
        // to intersect, we remove the items not contained in a selected group
        if (intersectGroups)
            [filteredArray setArray:publications];
        
        for (BibItem *pub in publications) {
            for (BDSKGroup *group in selectedGroups) {
                if ([group containsItem:pub] == !intersectGroups) {
                    if (intersectGroups)
                        [filteredArray removeObject:pub];
                    else
                        [filteredArray addObject:pub];
                    break;
                }
            }
        }
        
        array = filteredArray;
    }
    
    [groupedPublications setArray:array];
    
    if ([self isDisplayingFileContentSearch])
        [fileSearchController filterUsingURLs:[groupedPublications valueForKey:@"identifierURL"]];
    
    [self redoSearch];
}

- (BOOL)selectGroups:(NSArray *)theGroups{
    // expand the parents, or rowForItem: will return -1
    for (id parent in [NSSet setWithArray:[theGroups valueForKey:@"parent"]])
        [groupOutlineView expandItem:parent];

    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    for (id group in theGroups) {
        NSInteger r = [groupOutlineView rowForItem:group];
        if (r != -1) [indexes addIndex:r];
    }
    
    if([indexes count] == 0) {
        // was deselectAll:nil, but that selects the group item...
        [indexes addIndex:1];
        [groupOutlineView selectRowIndexes:indexes byExtendingSelection:NO];
        return NO;
    } else {
        [groupOutlineView selectRowIndexes:indexes byExtendingSelection:NO];
        return YES;
    }
}

- (BOOL)selectGroup:(BDSKGroup *)aGroup{
    return [self selectGroups:[NSArray arrayWithObject:aGroup]];
}

#pragma mark Spinners

- (NSProgressIndicator *)spinnerForGroup:(BDSKGroup *)group{
    NSProgressIndicator *spinner = [groupSpinners objectForKey:group];
    
    if ([group isRetrieving]) {
        if (spinner == nil) {
            // don't use NSMutableDictionary because that copies the groups
            if (groupSpinners == nil)
                groupSpinners = [[NSMapTable alloc] initWithKeyOptions:NSMapTableStrongMemory | NSMapTableObjectPointerPersonality valueOptions:NSMapTableStrongMemory | NSMapTableObjectPointerPersonality capacity:0];
            spinner = [[NSProgressIndicator alloc] init];
            [spinner setControlSize:NSSmallControlSize];
            [spinner setStyle:NSProgressIndicatorSpinningStyle];
            [spinner setDisplayedWhenStopped:NO];
            [spinner sizeToFit];
            [spinner setUsesThreadedAnimation:YES];
            [groupSpinners setObject:spinner forKey:group];
            [spinner release];
        }
        [spinner startAnimation:nil];
    } else if (spinner) {
        [spinner stopAnimation:nil];
        [spinner removeFromSuperview];
        [groupSpinners removeObjectForKey:group];
        spinner = nil;
    }
    
    return spinner;
}

- (void)removeSpinnerForGroup:(BDSKGroup *)group{
    NSProgressIndicator *spinner = [groupSpinners objectForKey:group];
    if (spinner) {
        [spinner stopAnimation:nil];
        [spinner removeFromSuperview];
        [groupSpinners removeObjectForKey:group];
    }
}

- (void)removeSpinnersFromSuperview {
    NSEnumerator *spinnerEnum = [groupSpinners objectEnumerator];
    NSProgressIndicator *spinner;
    while ((spinner = [spinnerEnum nextObject]))
        [spinner removeFromSuperview];
}

#pragma mark Actions

- (IBAction)sortGroupsByGroup:(id)sender{
	[self sortGroupsByKey:BDSKGroupCellStringKey];
}

- (IBAction)sortGroupsByCount:(id)sender{
	[self sortGroupsByKey:BDSKGroupCellCountKey];
}

- (IBAction)toggleGroupFieldAction:(id)sender{
    NSString *field = [sender representedObject];
    
    if ([[self currentGroupFields] containsObject:field])
        [self removeCurrentGroupField:field];
    else
        [self addCurrentGroupField:field];
}

- (IBAction)changeGroupFieldAction:(id)sender{
    NSString *field = [sender representedObject];
    
    id group = [[self clickedOrSelectedGroups] lastObject];
    if ([group groupType] == BDSKCategoryParentGroupType)
        [self setCurrentGroupField:field forGroup:group];
}

// for adding/removing groups, we use the searchfield sheets

- (IBAction)addGroupFieldAction:(id)sender{
	BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
	NSArray *groupFields = [[NSUserDefaults standardUserDefaults] stringArrayForKey:BDSKGroupFieldsKey];
    NSArray *colNames = [typeMan allFieldNamesIncluding:[NSArray arrayWithObjects:BDSKPubTypeString, BDSKCrossrefString, nil]
                                              excluding:[[[typeMan invalidGroupFieldsSet] allObjects] arrayByAddingObjectsFromArray:groupFields]];
    
    BDSKFieldSheetController *addFieldController = [BDSKFieldSheetController fieldSheetControllerWithChoosableFields:colNames
                                                                             label:NSLocalizedString(@"Name of group field:", @"Label for adding group field")];
	[addFieldController beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result){
        NSString *newGroupField = [addFieldController chosenField];
        if(result == NSCancelButton || newGroupField == nil)
            return; // the user canceled
        
        if([newGroupField isInvalidGroupField] || [newGroupField isEqualToString:@""]){
            [[addFieldController window] orderOut:nil];
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setMessageText:NSLocalizedString(@"Invalid Field", @"Message in alert dialog when choosing an invalid group field")];
            [alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"The field \"%@\" can not be used for groups.", @"Informative text in alert dialog"), [newGroupField localizedFieldName]]];
            [alert beginSheetModalForWindow:documentWindow modalDelegate:self didEndSelector:NULL contextInfo:NULL];
            return;
        }
        
        NSMutableArray *array = [groupFields mutableCopy];
        if ([array indexOfObject:newGroupField] == NSNotFound)
            [array addObject:newGroupField];
        [[NSUserDefaults standardUserDefaults] setObject:array forKey:BDSKGroupFieldsKey];	
        id group = [[self clickedOrSelectedGroups] lastObject];
        if ([group groupType] == BDSKCategoryParentGroupType)
            [self setCurrentGroupField:newGroupField forGroup:group];
        else
            [self addCurrentGroupField:newGroupField];
        [array release];
    }];
}

- (IBAction)removeGroupFieldAction:(id)sender{
	NSArray *groupFields = [[NSUserDefaults standardUserDefaults] stringArrayForKey:BDSKGroupFieldsKey];
    BDSKFieldSheetController *removeFieldController = [BDSKFieldSheetController fieldSheetControllerWithSelectableFields:groupFields
                                                                                label:NSLocalizedString(@"Group field to remove:", @"Label for removing group field")];
	[removeFieldController beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result){
        NSString *oldGroupField = [removeFieldController selectedField];
        if(result == NSCancelButton || [NSString isEmptyString:oldGroupField])
            return;
        
        NSMutableArray *array = [groupFields mutableCopy];
        [array removeObject:oldGroupField];
        [[NSUserDefaults standardUserDefaults] setObject:array forKey:BDSKGroupFieldsKey];
        [array release];
        
        if([[self currentGroupFields] containsObject:oldGroupField])
            [self removeCurrentGroupField:oldGroupField];
    }];
}    

- (IBAction)removeCategoryParentAction:(id)sender {
    BDSKCategoryParentGroup *group = [[self clickedOrSelectedGroups] lastObject];
    if ([group groupType] == BDSKCategoryParentGroupType)
        [self removeCurrentGroupField:[group key]];
}

- (void)editGroupWithoutWarning:(BDSKGroup *)group {
    [groupOutlineView expandItem:[group parent]];
    NSInteger i = [groupOutlineView rowForItem:group];
    BDSKASSERT(i != -1);
    
    if(i != -1){
        [groupOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
        [groupOutlineView scrollRowToVisible:i];
        
        // don't show the warning sheet, since presumably the user wants to change the group name
        [groupOutlineView editColumn:0 row:i withEvent:nil select:YES];
    }
}

- (IBAction)addSmartGroupAction:(id)sender {
	BDSKFilterController *filterController = [[[BDSKFilterController alloc] init] autorelease];
    [filterController beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result){
        if(result == NSOKButton){
            BDSKFilter *filter = [[BDSKFilter alloc] initWithConditions:[filterController conditions] conjunction:[filterController conjunction]];
            BDSKSmartGroup *group = [[BDSKSmartGroup alloc] initWithFilter:filter];
            [filter release];
            [groups addSmartGroup:group];
            [self editGroupWithoutWarning:group];
            [group release];
            [[self undoManager] setActionName:NSLocalizedString(@"Add Smart Group", @"Undo action name")];
            // updating of the tables is done when finishing the edit of the name
        }
	}];
}

- (IBAction)addStaticGroupAction:(id)sender {
    BDSKStaticGroup *group = [[BDSKStaticGroup alloc] init];
    [groups addStaticGroup:group];
    [self editGroupWithoutWarning:group];
    [group release];
    [[self undoManager] setActionName:NSLocalizedString(@"Add Static Group", @"Undo action name")];
    // updating of the tables is done when finishing the edit of the name
}

- (IBAction)addWebGroupAction:(id)sender {
    BDSKWebGroup *group = [[BDSKWebGroup alloc] init];
    [groups addWebGroup:group];
    [groupOutlineView expandItem:[group parent]];
    NSInteger row = [groupOutlineView rowForItem:group];
    if (row != -1)
        [groupOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [group release];
}

- (IBAction)addSearchGroupAction:(id)sender {
    BDSKSearchGroupSheetController *sheetController = [[[BDSKSearchGroupSheetController alloc] init] autorelease];
    [sheetController beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result){
        if(result == NSOKButton){
            BDSKSearchGroup *group = [[BDSKSearchGroup alloc] initWithServerInfo:[sheetController serverInfo] searchTerm:nil];
            [groups addSearchGroup:group];
            [groupOutlineView expandItem:[group parent]];
            [group release];
            NSInteger row = [groupOutlineView rowForItem:group];
            if (row != -1)
                [groupOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        }
    }];
}

- (IBAction)newSearchGroupFromBookmark:(id)sender {
    NSDictionary *dict = [sender representedObject];
    BDSKSearchGroup *group = [[[BDSKSearchGroup alloc] initWithDictionary:dict] autorelease];
    if (group) {
        [groups addSearchGroup:(id)group];        
        [groupOutlineView expandItem:[group parent]];
        NSInteger row = [groupOutlineView rowForItem:group];
        if (row != -1)
            [groupOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    } else
        NSBeep();
}

- (void)addMenuItemsForBookmarks:(NSArray *)bookmarksArray level:(NSInteger)level toMenu:(NSMenu *)menu {
    for (BDSKSearchBookmark *bm in bookmarksArray) {
        if ([bm bookmarkType] == BDSKSearchBookmarkTypeFolder) {
            NSString *label = [bm label];
            NSMenuItem *item = [menu addItemWithTitle:label ?: @"" action:NULL keyEquivalent:@""];
            [item setImageAndSize:[bm icon]];
            [item setIndentationLevel:level];
            [item setRepresentedObject:bm];
            [self addMenuItemsForBookmarks:[bm children] level:level+1 toMenu:menu];
        }
    }
}

- (IBAction)addSearchBookmark:(id)sender {
    if ([self hasGroupTypeSelected:BDSKSearchGroupType] == NO) {
        NSBeep();
        return;
    }
    
    BDSKSearchGroup *group = (BDSKSearchGroup *)[[self selectedGroups] lastObject];
    BDSKBookmarkSheetController *bookmarkSheetController = [[[BDSKBookmarkSheetController alloc] init] autorelease];
	NSPopUpButton *folderPopUp = [bookmarkSheetController folderPopUpButton];
    [bookmarkSheetController setStringValue:[[group searchTerm] length] > 0 ? [NSString stringWithFormat:@"%@: %@", [group name], [group searchTerm]] : [group name]];
    [folderPopUp removeAllItems];
    BDSKSearchBookmark *bookmark = [[BDSKSearchBookmarkController sharedBookmarkController] bookmarkRoot];
    [self addMenuItemsForBookmarks:[NSArray arrayWithObjects:bookmark, nil] level:0 toMenu:[folderPopUp menu]];
    [folderPopUp selectItemAtIndex:0];
    
    [bookmarkSheetController beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSInteger result){
        if (result == NSOKButton) {
            BDSKSearchBookmark *newBookmark = [BDSKSearchBookmark searchBookmarkWithInfo:[group dictionaryValue] label:[bookmarkSheetController stringValue]];
            if (newBookmark) {
                BDSKSearchBookmark *folder = [bookmarkSheetController selectedFolder] ?: [[BDSKSearchBookmarkController sharedBookmarkController] bookmarkRoot];
                [folder insertObject:newBookmark inChildrenAtIndex:[folder countOfChildren]];
            }
        }
    }];
}

- (IBAction)addURLGroupAction:(id)sender {
    BDSKURLGroupSheetController *sheetController = [[[BDSKURLGroupSheetController alloc] init] autorelease];
    [sheetController beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result){
        if(result == NSOKButton){
            BDSKURLGroup *group = [[BDSKURLGroup alloc] initWithURL:[sheetController URL]];
            [groups addURLGroup:group];
            [group publications];
            [self editGroupWithoutWarning:group];
            [group release];
            [[self undoManager] setActionName:NSLocalizedString(@"Add External File Group", @"Undo action name")];
            // updating of the tables is done when finishing the edit of the name
        }
    }];
}

- (IBAction)addScriptGroupAction:(id)sender {
    BDSKScriptGroupSheetController *sheetController = [[[BDSKScriptGroupSheetController alloc] init] autorelease];
    [sheetController beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result){
        if(result == NSOKButton){
            BDSKScriptGroup *group = [[BDSKScriptGroup alloc] initWithScriptPath:[sheetController path] scriptArguments:[sheetController arguments]];
            [groups addScriptGroup:group];
            [group publications];
            [self editGroupWithoutWarning:group];
            [group release];
            [[self undoManager] setActionName:NSLocalizedString(@"Add Script Group", @"Undo action name")];
            // updating of the tables is done when finishing the edit of the name
        }
    }];
}

- (void)removeGroups:(NSArray *)theGroups {
    BOOL didRemove = NO;
	
	for (BDSKGroup *group in theGroups) {
		switch ([group groupType]) {
            case BDSKSmartGroupType:
                [groups removeSmartGroup:(BDSKSmartGroup *)group];
                didRemove = YES;
                break;
		    case BDSKStaticGroupType:
                [groups removeStaticGroup:(BDSKStaticGroup *)group];
                didRemove = YES;
                break;
		    case BDSKURLGroupType:
                [groups removeURLGroup:(BDSKURLGroup *)group];
                didRemove = YES;
                break;
		    case BDSKScriptGroupType:
                [groups removeScriptGroup:(BDSKScriptGroup *)group];
                didRemove = YES;
                break;
		    case BDSKSearchGroupType:
                [groups removeSearchGroup:(BDSKSearchGroup *)group];
                break;
		    case BDSKWebGroupType:
                [groups removeWebGroup:(BDSKWebGroup *)group];
                break;
            default: break;
        }
	}
	if (didRemove) {
		[[self undoManager] setActionName:NSLocalizedString(@"Remove Groups", @"Undo action name")];
        [self displaySelectedGroups];
	}
}

- (IBAction)removeSelectedGroups:(id)sender {
    [self removeGroups:[self clickedOrSelectedGroups]];
}

- (void)editGroup:(BDSKGroup *)group {
    
    if ([group isEditable] == NO) {
		NSBeep();
        return;
    }
    
	if ([group groupType] == BDSKSmartGroupType) {
		BDSKFilter *filter = [(BDSKSmartGroup *)group filter];
		BDSKFilterController *filterController = [[BDSKFilterController alloc] initWithFilter:filter];
        [filterController beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result){
            if (result == NSOKButton) {
                [filter setConditions:[filterController conditions]];
                [filter setConjunction:[filterController conjunction]];
                [[filter undoManager] setActionName:NSLocalizedString(@"Edit Smart Group", @"Undo action name")];
            }
        }];
        [filterController release];
	} else if ([group groupType] == BDSKCategoryGroupType) {
        // this must be a person field
        BDSKASSERT([[group name] isKindOfClass:[BibAuthor class]]);
		[self showPerson:(BibAuthor *)[group name]];
	} else if ([group groupType] == BDSKURLGroupType) {
        BDSKURLGroup *urlGroup = (BDSKURLGroup *)group;
        BDSKURLGroupSheetController *sheetController = [(BDSKURLGroupSheetController *)[BDSKURLGroupSheetController alloc] initWithURL:[urlGroup URL]];
        [sheetController beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result){
            if (result == NSOKButton) {
                [urlGroup setURL:[sheetController URL]];
                [[self undoManager] setActionName:NSLocalizedString(@"Edit External File Group", @"Undo action name")];
            }
        }];
        [sheetController release];
	} else if ([group groupType] == BDSKScriptGroupType) {
        BDSKScriptGroup *scriptGroup = (BDSKScriptGroup *)group;
        BDSKScriptGroupSheetController *sheetController = [(BDSKScriptGroupSheetController *)[BDSKScriptGroupSheetController alloc] initWithPath:[scriptGroup scriptPath] arguments:[scriptGroup scriptArguments]];
        [sheetController beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result){
            if (result == NSOKButton) {
                NSString *path = [sheetController path];
                [scriptGroup setScriptPath:path];
                [scriptGroup setScriptArguments:[sheetController arguments]];
                [scriptGroup setScriptType:[[NSWorkspace sharedWorkspace] isAppleScriptFileAtPath:path] ? BDSKAppleScriptType: BDSKShellScriptType];
                [[self undoManager] setActionName:NSLocalizedString(@"Edit Script Group", @"Undo action name")];
            }
        }];
        [sheetController release];
	} else if ([group groupType] == BDSKSearchGroupType) {
        BDSKSearchGroup *searchGroup = (BDSKSearchGroup *)group;
        BDSKSearchGroupSheetController *sheetController = [(BDSKSearchGroupSheetController *)[BDSKSearchGroupSheetController alloc] initWithServerInfo:[searchGroup serverInfo]];
        [sheetController beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result){
            if (result == NSOKButton) {
                [searchGroup setServerInfo:[sheetController serverInfo]];
            }
        }];
        [sheetController release];
	}
}

- (IBAction)editGroupAction:(id)sender {
    NSArray *selectedGroups = [self clickedOrSelectedGroups];
	if ([selectedGroups count] != 1) {
		NSBeep();
		return;
	} 
	[self editGroup:[selectedGroups lastObject]];
}

- (IBAction)renameGroupAction:(id)sender {
	NSInteger row = [groupOutlineView clickedRow];
    if (row == -1 && [groupOutlineView numberOfSelectedRows] == 1)
        row = [groupOutlineView selectedRow];
	if (row == -1) {
		NSBeep();
		return;
	} 
    
    NSTableColumn *tableColumn = [[groupOutlineView tableColumns] objectAtIndex:0];
    id item = [groupOutlineView itemAtRow:row];
    
    if ([groupOutlineView isRowSelected:row] == NO) {
        if ([self outlineView:groupOutlineView shouldSelectItem:item] == NO) {
            NSBeep();
            return;
        }
        [groupOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    }
    if ([self outlineView:groupOutlineView shouldEditTableColumn:tableColumn item:item])
		[groupOutlineView editColumn:0 row:row withEvent:nil select:YES];
	
}

- (IBAction)copyGroupURLAction:(id)sender {
	id group = [[self clickedOrSelectedGroups] lastObject];
    NSURL *url = nil;
    NSString *title = nil;
    
	if (0 == ([group groupType] & BDSKExternalGroupType)) {
		NSBeep();
		return;
	} 
    if ([group groupType] == BDSKSearchGroupType) {
        url = [(BDSKSearchGroup *)group bdsksearchURL];
        title = [[(BDSKSearchGroup *)group serverInfo] name];
    } else if ([group groupType] == BDSKURLGroupType) {
        url = [(BDSKURLGroup *)group URL];
    } else if ([group groupType] == BDSKScriptGroupType && [(BDSKScriptGroup *)group scriptPath]) {
        url = [NSURL fileURLWithPath:[(BDSKScriptGroup *)group scriptPath]];
    } else if ([group groupType] == BDSKWebGroupType) {
        url = [(BDSKWebGroup *)group URL];
        title = [group label];
    }
    if (url == nil) {
		NSBeep();
		return;
	} 
    if (title == nil)
        title = [url isFileURL] ? [[url path] lastPathComponent] : [url absoluteString];
	
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    [pboard clearContents];
    [pboard writeURLs:[NSArray arrayWithObjects:url, nil] names:[NSArray arrayWithObjects:title, nil]];
}

- (IBAction)selectLibraryGroup:(id)sender {
	[groupOutlineView deselectAll:sender];
}

- (IBAction)changeIntersectGroupsAction:(id)sender {
    BOOL flag = (BOOL)[sender tag];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKIntersectGroupsKey] != flag) {
        [[NSUserDefaults standardUserDefaults] setBool:flag forKey:BDSKIntersectGroupsKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupTableSelectionChangedNotification object:self];
    }
}

- (IBAction)editNewStaticGroupWithSelection:(id)sender{
    NSArray *names = [[groups staticGroups] valueForKeyPath:@"@distinctUnionOfObjects.name"];
    NSArray *pubs = [self selectedPublications];
    NSString *baseName = NSLocalizedString(@"Untitled", @"");
    NSString *name = baseName;
    BDSKStaticGroup *group;
    NSUInteger i = 1;
    while([names containsObject:name]){
        name = [NSString stringWithFormat:@"%@%lu", baseName, (unsigned long)i++];
    }
    
    // first merge in shared groups
    if ([self hasGroupTypeSelected:BDSKExternalGroupType])
        pubs = [self mergeInPublications:pubs];
    
    group = [[[BDSKStaticGroup alloc] initWithName:name publications:pubs] autorelease];
    
    [groups addStaticGroup:group];    
    [groupOutlineView deselectAll:nil];
    
    [self performSelector:@selector(editGroupWithoutWarning:) withObject:group afterDelay:0.0];
}

- (void)editNewCategoryGroupWithSelectionForGroupField:(NSString *)groupField {
    NSUInteger idx = [[self currentGroupFields] indexOfObject:groupField];
    BDSKASSERT(idx != NSNotFound);
    if (idx == NSNotFound)
        return;
    BDSKCategoryParentGroup *parent = [[groups categoryParents] objectAtIndex:idx];
    NSArray *categoryGroups = [parent categoryGroups];
    BOOL isAuthor = [groupField isPersonField];
    NSArray *names = [categoryGroups valueForKeyPath:isAuthor ? @"@distinctUnionOfObjects.name.lastName" : @"@distinctUnionOfObjects.name"];
    NSArray *pubs = [self selectedPublications];
    NSString *baseName = NSLocalizedString(@"Untitled", @"");
    id name = baseName;
    BDSKCategoryGroup *group;
    NSUInteger i = 1;
    
    while ([names containsObject:name])
        name = [NSString stringWithFormat:@"%@%lu", baseName, (unsigned long)i++];
    if (isAuthor)
        name = [BibAuthor authorWithName:name];
    group = [[[BDSKCategoryGroup alloc] initWithName:name key:groupField] autorelease];
    
    // first merge in shared groups
    if ([self hasGroupTypeSelected:BDSKExternalGroupType])
        pubs = [self mergeInPublications:pubs];
    
    [self addPublications:pubs toGroup:group];
    [groupOutlineView deselectAll:nil];
    [self updateCategoryGroups:parent];
    
    idx = [categoryGroups indexOfObject:group];
    BDSKASSERT(idx != NSNotFound);
    if (idx != NSNotFound)
        group = [categoryGroups objectAtIndex:idx];
    
    [self performSelector:@selector(editGroupWithoutWarning:) withObject:group afterDelay:0.0];
}

- (IBAction)editNewCategoryGroupWithSelection:(id)sender{
    NSArray *currentGroupFields = [self currentGroupFields];
    if ([currentGroupFields count] == 0) {
        NSBeep();
    } else if ([currentGroupFields count] == 1) {
        [self editNewCategoryGroupWithSelectionForGroupField:[currentGroupFields lastObject]];
    } else {
        BDSKFieldSheetController *chooseFieldController = [BDSKFieldSheetController fieldSheetControllerWithSelectableFields:currentGroupFields
                                                                                    label:NSLocalizedString(@"Group field:", @"Label for choosing group field")];
        [chooseFieldController setDefaultButtonTitle:NSLocalizedString(@"Choose", @"Button title")];
        [chooseFieldController beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result){
            NSString *groupField = [chooseFieldController selectedField];
            if(result == NSCancelButton || [NSString isEmptyString:groupField])
                return;
            
            [self editNewCategoryGroupWithSelectionForGroupField:groupField];
        }];
    }
}

- (IBAction)mergeInExternalGroup:(id)sender{
    // we should have a single external group selected
    id group = [[self clickedOrSelectedGroups] lastObject];
    if (0 == ([group groupType] & BDSKExternalGroupType)) {
        NSBeep();
        return;
    }
    [self mergeInPublications:[group publications]];
}

- (IBAction)mergeInExternalPublications:(id)sender{
    if ([self hasGroupTypeSelected:BDSKExternalGroupType] == NO || [self numberOfClickedOrSelectedPubs] == 0) {
        NSBeep();
        return;
    }
    [self mergeInPublications:[self clickedOrSelectedPublications]];
}

- (IBAction)refreshAllExternalGroups:(id)sender{
    [self refreshSharedBrowsing:sender];
    [[groups URLGroups] setValue:nil forKey:@"publications"];
    [[groups scriptGroups] setValue:nil forKey:@"publications"];
    [[groups searchGroups] setValue:nil forKey:@"publications"];
    for (BDSKWebGroup *group in [groups webGroups]) {
        if ([group isWebViewLoaded])
            [[group webView] reload:nil];
    }
    if ([self hasGroupTypeSelected:BDSKURLGroupType | BDSKScriptGroupType | BDSKSearchGroupType])
        [[[self selectedGroups] lastObject] publications];
}

- (IBAction)refreshSelectedGroups:(id)sender{
    id group = [[self clickedOrSelectedGroups] lastObject];
    if ([group groupType] == BDSKWebGroupType) {
        if ([group isWebViewLoaded])
            [[group webView] reload:nil];
        else NSBeep();
    } else if (([group groupType] & BDSKExternalGroupType) != 0) {
        [group setPublications:nil];
        if ([[self selectedGroups] containsObject:group])
            [group publications];
    } else NSBeep();
}

- (IBAction)openBookmark:(id)sender{
    if ([self openURL:[sender representedObject]] == NO)
        NSBeep();
}

- (IBAction)addBookmark:(id)sender {
    if ([self hasGroupTypeSelected:BDSKWebGroupType])
        [[(BDSKWebGroup *)[[self selectedGroups] lastObject] webView] addBookmark:sender];
    else
        NSBeep();
}

#pragma mark Add or remove items

- (NSArray *)mergeInPublications:(NSArray *)items{
    // first construct a set of current items to compare based on BibItem equality callbacks
    CFIndex countOfItems = [publications count];
    BibItem **pubs = (BibItem **)NSZoneMalloc([self zone], sizeof(BibItem *) * countOfItems);
    [publications getObjects:pubs];
    NSSet *currentPubs = [(NSSet *)CFSetCreate(CFAllocatorGetDefault(), (const void **)pubs, countOfItems, &kBDSKBibItemEquivalenceSetCallBacks) autorelease];
    NSZoneFree([self zone], pubs);
    
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[items count]];
    
    for (BibItem *pub in items) {
        if ([currentPubs containsObject:pub] == NO)
            [array addObject:pub];
    }
    
    if ([array count] == 0)
        return [NSArray array];
    
    // get complex strings with the correct macroResolver
    NSArray *newPubs = [self transferredPublications:array];
    
    [self importPublications:newPubs options:BDSKImportSelectLibrary | BDSKImportNoEdit];
	
	[[self undoManager] setActionName:NSLocalizedString(@"Merge External Publications", @"Undo action name")];
    
    return newPubs;
}

- (BOOL)addPublications:(NSArray *)pubs toGroup:(BDSKGroup *)group{
    BDSKPRECONDITION(([group groupType] & (BDSKStaticGroupType | BDSKCategoryGroupType)) != 0);
    
    if ([group groupType] == BDSKStaticGroupType) {
        [(BDSKStaticGroup *)group addPublicationsFromArray:pubs];
		[[self undoManager] setActionName:NSLocalizedString(@"Add To Group", @"Undo action name")];
        return YES;
    }
    
    NSMutableArray *changedPubs = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSMutableArray *oldValues = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSMutableArray *newValues = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSString *oldValue = nil;
    NSString *field = [group groupType] == BDSKCategoryGroupType ? [(BDSKCategoryGroup *)group key] : nil;
    NSInteger count = 0;
    NSInteger handleInherited = BDSKOperationAsk;
	NSInteger rv;
    
    for (BibItem *pub in pubs) {
        BDSKASSERT([pub isKindOfClass:[BibItem class]]);        
        
        if(field && [field isEqualToString:BDSKPubTypeString] == NO)
            oldValue = [[[pub valueOfField:field] retain] autorelease];
		rv = [pub addToGroup:group handleInherited:handleInherited];
		
		if(rv == BDSKOperationSet || rv == BDSKOperationAppend){
            count++;
            if(field && [field isEqualToString:BDSKPubTypeString] == NO){
                [changedPubs addObject:pub];
                [oldValues addObject:oldValue ?: @""];
                [newValues addObject:[pub valueOfField:field]];
            }
		}else if(rv == BDSKOperationAsk){
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setMessageText:NSLocalizedString(@"Inherited Value", @"Message in alert dialog when trying to edit inherited value")];
            [alert setInformativeText:NSLocalizedString(@"One or more items have a value that was inherited from an item linked to by the Crossref field. This operation would break the inheritance for this value. What do you want me to do with inherited values?", @"Informative text in alert dialog")];
            [[alert addButtonWithTitle:NSLocalizedString(@"Don't Change", @"Button title")] setTag:BDSKOperationIgnore];
            if (field && [field isSingleValuedGroupField] == NO)
                [[alert addButtonWithTitle:NSLocalizedString(@"Append", @"Button title")] setTag:BDSKOperationAppend];
            [[alert addButtonWithTitle:NSLocalizedString(@"Set", @"Button title")] setTag:BDSKOperationSet];
			rv = [alert runModal];
            handleInherited = rv;
			if(handleInherited != BDSKOperationIgnore){
                [pub addToGroup:group handleInherited:handleInherited];
                count++;
                if(field && [field isEqualToString:BDSKPubTypeString] == NO){
                    [changedPubs addObject:pub];
                    [oldValues addObject:oldValue ?: @""];
                    [newValues addObject:[pub valueOfField:field]];
                }
			}
		}
    }
	
	if(count > 0){
        if([changedPubs count])
            [[self undoManager] setActionName:NSLocalizedString(@"Add To Group", @"Undo action name")];
        [self userChangedField:field ofPublications:changedPubs from:oldValues to:newValues];
    }
    
    return YES;
}

- (BOOL)removePublications:(NSArray *)pubs fromGroups:(NSArray *)groupArray{
	NSInteger count = 0;
	NSInteger handleInherited = BDSKOperationAsk;
	NSString *groupName = nil;
    
    for (BDSKGroup *group in groupArray){
		if(([group groupType] & (BDSKCategoryGroupType | BDSKStaticGroupType)) == 0)
			continue;
		
		if (groupName == nil)
			groupName = [NSString stringWithFormat:NSLocalizedString(@"group %@", @"Partial status message"), [group name]];
		else
			groupName = NSLocalizedString(@"selected groups", @"Partial status message");
		
        if ([group groupType] == BDSKStaticGroupType) {
            [(BDSKStaticGroup *)group removePublicationsInArray:pubs];
            [[self undoManager] setActionName:NSLocalizedString(@"Remove From Group", @"Undo action name")];
            count = [pubs count];
            continue;
        }
        
        NSMutableArray *changedPubs = [NSMutableArray arrayWithCapacity:[pubs count]];
        NSMutableArray *oldValues = [NSMutableArray arrayWithCapacity:[pubs count]];
        NSMutableArray *newValues = [NSMutableArray arrayWithCapacity:[pubs count]];
        NSString *oldValue = nil;
        NSString *field = [(BDSKCategoryGroup *)group key];
		NSInteger rv;
        NSInteger tmpCount = 0;
		
        if([field isSingleValuedGroupField] || [field isEqualToString:BDSKPubTypeString])
            continue;
        
		for (BibItem *pub in pubs) {
			BDSKASSERT([pub isKindOfClass:[BibItem class]]);        
			
            if(field)
                oldValue = [[[pub valueOfField:field] retain] autorelease];
			rv = [pub removeFromGroup:group handleInherited:handleInherited];
			
			if(rv == BDSKOperationSet || rv == BDSKOperationAppend){
				tmpCount++;
                if(field){
                    [changedPubs addObject:pub];
                    [oldValues addObject:oldValue ?: @""];
                    [newValues addObject:[pub valueOfField:field]];
                }
			}else if(rv == BDSKOperationAsk){
                NSAlert *alert = [[[NSAlert alloc] init] autorelease];
                [alert setMessageText:NSLocalizedString(@"Inherited Value", @"Message in alert dialog when trying to edit inherited value")];
                [alert setInformativeText:NSLocalizedString(@"One or more items have a value that was inherited from an item linked to by the Crossref field. This operation would break the inheritance for this value. What do you want me to do with inherited values?", @"Informative text in alert dialog")];
                [[alert addButtonWithTitle:NSLocalizedString(@"Don't Change", @"Button title")] setTag:BDSKOperationIgnore];
                [[alert addButtonWithTitle:NSLocalizedString(@"Remove", @"Button title")] setTag:BDSKOperationAppend];
				rv = [alert runModal];
                handleInherited = rv;
				if(handleInherited != BDSKOperationIgnore){
					[pub removeFromGroup:group handleInherited:handleInherited];
                    tmpCount++;
                    if(field){
                        [changedPubs addObject:pub];
                        [oldValues addObject:oldValue ?: @""];
                        [newValues addObject:[pub valueOfField:field]];
                    }
				}
			}
		}
        
        count = MAX(count, tmpCount);
        if([changedPubs count])
            [self userChangedField:field ofPublications:changedPubs from:oldValues to:newValues];
	}
	
	if(count > 0){
		[[self undoManager] setActionName:NSLocalizedString(@"Remove from Group", @"Undo action name")];
		NSString * pubSingularPlural;
		if (count == 1)
			pubSingularPlural = NSLocalizedString(@"publication", @"publication, in status message");
		else
			pubSingularPlural = NSLocalizedString(@"publications", @"publications, in status message");
		[self setStatus:[NSString stringWithFormat:NSLocalizedString(@"Removed %ld %@ from %@", @"Status message: Removed [number] publications(s) from selected group(s)"), (long)count, pubSingularPlural, groupName] immediate:NO];
	}
    
    return YES;
}

- (BOOL)movePublications:(NSArray *)pubs fromGroup:(BDSKGroup *)group toGroupNamed:(NSString *)newGroupName{
	NSInteger count = 0;
	NSInteger handleInherited = BDSKOperationAsk;
	NSInteger rv;
	
	if([group groupType] != BDSKCategoryGroupType)
		return NO;
    
    NSMutableArray *changedPubs = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSMutableArray *oldValues = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSMutableArray *newValues = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSString *oldValue = nil;
    NSString *field = [(BDSKCategoryGroup *)group key];
	
	for (BibItem *pub in pubs){
		BDSKASSERT([pub isKindOfClass:[BibItem class]]);        
		
        oldValue = [[[pub valueOfField:field] retain] autorelease];
		rv = [pub replaceGroup:group withGroupNamed:newGroupName handleInherited:handleInherited];
		
		if(rv == BDSKOperationSet || rv == BDSKOperationAppend){
			count++;
            [changedPubs addObject:pub];
            [oldValues addObject:oldValue ?: @""];
            [newValues addObject:[pub valueOfField:field]];
        }else if(rv == BDSKOperationAsk){
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setMessageText:NSLocalizedString(@"Inherited Value", @"Message in alert dialog when trying to edit inherited value")];
            [alert setInformativeText:NSLocalizedString(@"One or more items have a value that was inherited from an item linked to by the Crossref field. This operation would break the inheritance for this value. What do you want me to do with inherited values?", @"Informative text in alert dialog")];
            [[alert addButtonWithTitle:NSLocalizedString(@"Don't Change", @"Button title")] setTag:BDSKOperationIgnore];
            [[alert addButtonWithTitle:NSLocalizedString(@"Remove", @"Button title")] setTag:BDSKOperationAppend];
			rv = [alert runModal];
            handleInherited = rv;
			if(handleInherited != BDSKOperationIgnore){
				[pub replaceGroup:group withGroupNamed:newGroupName handleInherited:handleInherited];
                count++;
                [changedPubs addObject:pub];
                [oldValues addObject:oldValue ?: @""];
                [newValues addObject:[pub valueOfField:field]];
			}
        }
	}
	
	if(count > 0){
        [[self undoManager] setActionName:NSLocalizedString(@"Rename Group", @"Undo action name")];
        if([changedPubs count])
            [self userChangedField:field ofPublications:changedPubs from:oldValues to:newValues];
    }
    
    return YES;
}

#pragma mark Sorting

- (void)sortGroupsByKey:(NSString *)key{
    if (key == nil) {
		// nil key indicates resort
    } else if ([key isEqualToString:sortGroupsKey]) {
        // clicked the sort arrow in the table header, change sort order
        docFlags.sortGroupsDescending = !docFlags.sortGroupsDescending;
    } else {
        // change key
        // save new sorting selector, and re-sort the array.
        if ([key isEqualToString:BDSKGroupCellStringKey])
			docFlags.sortGroupsDescending = NO;
		else
			docFlags.sortGroupsDescending = YES; // more appropriate for default count sort
		[sortGroupsKey release];
        sortGroupsKey = [key retain];
        if ([sortGroupsKey isEqualToString:BDSKGroupCellCountKey] && [[NSUserDefaults standardUserDefaults] boolForKey:BDSKHideGroupCountKey]) {
            // the smart group counts were not updated, so we need to do that now; this will get back to us, so just return here.
            [self updateSmartGroupsCount];
            return;
        }
	}
    
    if (key) {
        [[NSUserDefaults standardUserDefaults] setObject:sortGroupsKey forKey:BDSKSortGroupsKey];
        [[NSUserDefaults standardUserDefaults] setBool:docFlags.sortGroupsDescending forKey:BDSKSortGroupsDescendingKey];    
    }
    
    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    docFlags.ignoreGroupSelectionChange = YES;

    // cache the selection
	NSArray *selectedGroups = [self selectedGroups];
    
    NSArray *sortDescriptors;
    
    if([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]){
        NSSortDescriptor *countSort = [[NSSortDescriptor alloc] initWithKey:@"numberValue" ascending:!docFlags.sortGroupsDescending  selector:@selector(compare:)];
        NSSortDescriptor *nameSort = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:docFlags.sortGroupsDescending  selector:@selector(sortCompare:)];
        sortDescriptors = [NSArray arrayWithObjects:countSort, nameSort, nil];
        [countSort release];
        [nameSort release];
    } else {
        NSSortDescriptor *nameSort = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:!docFlags.sortGroupsDescending  selector:@selector(sortCompare:)];
        sortDescriptors = [NSArray arrayWithObjects:nameSort, nil];
        [nameSort release];
    }
    
    [groups sortUsingDescriptors:sortDescriptors];
    
    [self removeSpinnersFromSuperview];
    [groupOutlineView reloadData];
	
	// select the current groups. Otherwise select Library
	[self selectGroups:selectedGroups];
	[self displaySelectedGroups];
	
    // reset
    docFlags.ignoreGroupSelectionChange = NO;
}

#pragma mark Importing

- (void)setImported:(BOOL)flag forPublications:(NSArray *)pubs inGroup:(BDSKExternalGroup *)aGroup{
    CFIndex countOfItems = [pubs count];
    BibItem **items = (BibItem **)NSZoneMalloc([self zone], sizeof(BibItem *) * countOfItems);
    [pubs getObjects:items];
    NSSet *pubSet = (NSSet *)CFSetCreate(CFAllocatorGetDefault(), (const void **)items, countOfItems, &kBDSKBibItemEquivalenceSetCallBacks);
    NSZoneFree([self zone], items);
    
    NSArray *groupsToTest = aGroup ? [NSArray arrayWithObject:aGroup] : [[groups externalParent] children];
    
    for (BDSKExternalGroup *group in groupsToTest) {
        // publicationsWithoutUpdating avoids triggering a load or update of external groups every time you add/remove a pub
        for (BibItem *pub in [group publicationsWithoutUpdating]) {
            if ([pubSet containsObject:pub])
                [pub setImported:flag];
        }
    }
    [pubSet release];
	
    NSTableColumn *tc = [tableView tableColumnWithIdentifier:BDSKImportOrderString];
    if(tc && [self hasGroupTypeSelected:BDSKExternalGroupType])
        [tableView setNeedsDisplayInRect:[tableView rectOfColumn:[[tableView tableColumns] indexOfObject:tc]]];
}

- (void)tableView:(NSTableView *)aTableView importItemAtRow:(NSInteger)rowIndex{
    BibItem *pub = [shownPublications objectAtIndex:rowIndex];
    // also import a possible crossref parent if that wasn't already present
    BibItem *parent = [pub crossrefParent];
    if ([parent isImported])
        parent = nil;
    
    NSArray *newPubs = [self transferredPublications:[NSArray arrayWithObjects:pub, parent, nil]];
	
    [self importPublications:newPubs options:BDSKImportAggregate | BDSKImportNoEdit];
    
	[[self undoManager] setActionName:NSLocalizedString(@"Import Publication", @"Undo action name")];
}

#pragma mark Opening a URL

- (BOOL)openURL:(NSURL *)url {
    BDSKWebGroup *group = nil;
    if ([self hasGroupTypeSelected:BDSKWebGroupType]) {
        group = [[self selectedGroups] lastObject];
        [group setURL:url];
    } else {
        for (group in [groups webGroups])
            if ([group isWebViewLoaded] == NO) break;
        if (group == nil) {
            group = [[[BDSKWebGroup alloc] init] autorelease];
            [groups addWebGroup:group];
        }
        [group setURL:url];
        [self selectGroup:group];
    }
    return group != nil;
}

@end

//
//  BibDocument_Groups.m
//  Bibdesk
//
/*
 This software is Copyright (c) 2005,2007,2008
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
#import "BDSKGroupTableView.h"
#import "BDSKHeaderPopUpButtonCell.h"
#import "BibDocument_Search.h"
#import "BDSKGroup.h"
#import "BDSKSharedGroup.h"
#import "BDSKURLGroup.h"
#import "BDSKScriptGroup.h"
#import "BDSKSmartGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKCategoryGroup.h"
#import "BDSKWebGroup.h"
#import "BDSKAlert.h"
#import "BDSKFieldSheetController.h"
#import "BDSKCountedSet.h"
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
#import "BDSKColoredBox.h"
#import "BDSKCollapsibleView.h"
#import "BDSKSearchGroup.h"
#import "BDSKMainTableView.h"
#import "BDSKSearchGroupSheetController.h"
#import "BDSKSearchGroupViewController.h"
#import "BDSKWebGroupViewController.h"
#import "BDSKServerInfo.h"
#import "NSObject_BDSKExtensions.h"
#import "BDSKSearchBookmarkController.h"
#import "BDSKSearchButtonController.h"

@implementation BibDocument (Groups)

#pragma mark Selected group types

- (BOOL)hasLibraryGroupSelected{
    return [groupTableView selectedRow] == 0;
}

- (BOOL)hasWebGroupSelected{
    return [groups webGroup] && [groupTableView selectedRow] == 1;
}

- (BOOL)hasSharedGroupsSelected{
    return [groups hasSharedGroupsAtIndexes:[groupTableView selectedRowIndexes]];
}

- (BOOL)hasURLGroupsSelected{
    return [groups hasURLGroupsAtIndexes:[groupTableView selectedRowIndexes]];
}

- (BOOL)hasScriptGroupsSelected{
    return [groups hasScriptGroupsAtIndexes:[groupTableView selectedRowIndexes]];
}

- (BOOL)hasSearchGroupsSelected{
    return [groups hasSearchGroupsAtIndexes:[groupTableView selectedRowIndexes]];
}

- (BOOL)hasSmartGroupsSelected{
    return [groups hasSmartGroupsAtIndexes:[groupTableView selectedRowIndexes]];
}

- (BOOL)hasStaticGroupsSelected{
    return [groups hasStaticGroupsAtIndexes:[groupTableView selectedRowIndexes]];
}

- (BOOL)hasCategoryGroupsSelected{
    return [groups hasCategoryGroupsAtIndexes:[groupTableView selectedRowIndexes]];
}

- (BOOL)hasExternalGroupsSelected{
    return [groups hasExternalGroupsAtIndexes:[groupTableView selectedRowIndexes]];
}

/* 
The groupedPublications array is a subset of the publications array, developed by searching the publications array; shownPublications is now a subset of the groupedPublications array, and searches in the searchfield will search only within groupedPublications (which may include all publications).
*/

- (void)setCurrentGroupField:(NSString *)field{
	if (field != currentGroupField) {
		[currentGroupField release];
		currentGroupField = [field copy];
	}
}	

- (NSString *)currentGroupField{
	return currentGroupField;
}

- (NSArray *)selectedGroups {
    NSIndexSet *indexSet = [groupTableView selectedRowIndexes];
    // returns nil when groupTableView doesn't exist yet
	return nil == indexSet ? nil : [groups objectsAtIndexes:indexSet];
}

#pragma mark Search group view

- (void)showSearchGroupView {
    
    if ([self isDisplayingFileContentSearch])
        [fileSearchController restoreDocumentState];

    if (nil == searchGroupViewController)
        searchGroupViewController = [[BDSKSearchGroupViewController alloc] init];
    [self insertControlView:[searchGroupViewController view] atTop:NO];
    
    BDSKSearchGroup *group = [[self selectedGroups] firstObject];
    OBASSERT([group isSearch]);
    [searchGroupViewController setGroup:group];
}

- (void)hideSearchGroupView
{
    [self removeControlView:[searchGroupViewController view]];
    [searchGroupViewController setGroup:nil];
}


#pragma mark Web Group 

- (void)showWebGroupView {
    NSAssert([groups webGroup], @"tried to show WebGroupView when web group pref was false");
    if (nil == webGroupViewController)
        webGroupViewController = [[BDSKWebGroupViewController alloc] initWithGroup:[groups webGroup] document:self];
    NSView *webGroupView = [webGroupViewController view];
    NSView *webView = [webGroupViewController webView];
    
    if ([self isDisplayingWebGroupView] == NO) {
        [self insertControlView:webGroupView atTop:NO];
        
        NSView *view1 = [[splitView subviews] objectAtIndex:0];
        NSView *view2 = [[splitView subviews] objectAtIndex:1];
        NSRect svFrame = [splitView bounds];
        NSRect webFrame = svFrame;
        NSRect tableFrame = svFrame;
        NSRect previewFrame = svFrame;
        float height = NSHeight(svFrame) - 2 * [splitView dividerThickness];
        float factor = NSHeight([view2 frame]) / (NSHeight([view1 frame]) + NSHeight([view2 frame]));
        
        webFrame.size.height = roundf(0.4 * height);
        previewFrame.size.height = roundf(0.6 * height * factor);
        tableFrame.size.height = height - NSHeight(webFrame) - NSHeight(previewFrame);
        tableFrame.origin.y = NSMaxY(previewFrame) + [splitView dividerThickness];
        webFrame.origin.y = NSMaxY(tableFrame) + [splitView dividerThickness];
        
        [webView setFrame:webFrame];
        [splitView addSubview:webView positioned:NSWindowBelow relativeTo:mainView];
        [webView setFrame:webFrame];
        [view1 setFrame:tableFrame];
        [view2 setFrame:previewFrame];
        [splitView adjustSubviews];
        [splitView setNeedsDisplay:YES];
    }
}

- (void)hideWebGroupView{
    NSView *webGroupView = [webGroupViewController view];
    NSView *webView = [webGroupViewController webView];
    
    if ([self isDisplayingWebGroupView]) {
        id firstResponder = [documentWindow firstResponder];
        if ([firstResponder respondsToSelector:@selector(isDescendantOf:)] && [firstResponder isDescendantOf:webGroupView])
            [documentWindow makeFirstResponder:tableView];
        [self removeControlView:webGroupView];
        [webView removeFromSuperview];
        [splitView adjustSubviews];
        [splitView setNeedsDisplay:YES];
    }
}


#pragma mark Notification handlers

- (void)handleGroupFieldChangedNotification:(NSNotification *)notification{
    // use the most recently changed group as default for newly opened documents; could also store on a per-document basis
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:currentGroupField forKey:BDSKCurrentGroupFieldKey];
	[self updateCategoryGroupsPreservingSelection:NO];
}

- (void)handleFilterChangedNotification:(NSNotification *)notification{
	[self updateSmartGroupsCountAndContent:YES];
}

- (void)handleGroupTableSelectionChangedNotification:(NSNotification *)notification{
    // called with notification == nil from searchByContent action, shouldn't redisplay group content in that case to avoid a loop
    
    NSString *newSortKey = nil;
    
    if ([self hasExternalGroupsSelected]) {
        if ([self isDisplayingSearchButtons]) {
            
            // file content and skim notes search are not compatible with external groups
            if ([BDSKFileContentSearchString isEqualToString:[searchButtonController selectedItemIdentifier]])
                [searchButtonController selectItemWithIdentifier:BDSKAllFieldsString];
            
            [searchButtonController removeSkimNotesItem];
            [searchButtonController removeFileContentItem];
        }
        
        if ([self hasSearchGroupsSelected] == NO)
            [self hideSearchGroupView];            
            
        if ([self hasWebGroupSelected] == NO){
            [self hideWebGroupView];
        }else{
            if ([sortKey isEqualToString:BDSKImportOrderString] == NO) {
                newSortKey = BDSKImportOrderString;
                docState.sortDescending = NO;
            }  
            [self showWebGroupView];
        }
        
        if ([self hasSearchGroupsSelected]) {
            if ([sortKey isEqualToString:BDSKImportOrderString] == NO) {
                newSortKey = BDSKImportOrderString;
                docState.sortDescending = NO;
            }
            [self showSearchGroupView];
        } 
    
        [tableView setAlternatingRowBackgroundColors:[NSColor alternateControlAlternatingRowBackgroundColors]];
        [tableView insertTableColumnWithIdentifier:BDSKImportOrderString atIndex:0];

    } else {
        if ([self isDisplayingSearchButtons]) {
            [searchButtonController addSkimNotesItem];
            [searchButtonController addFileContentItem];
        }
        
        [tableView setAlternatingRowBackgroundColors:[NSColor controlAlternatingRowBackgroundColors]];
        [tableView removeTableColumnWithIdentifier:BDSKImportOrderString];
        if ([previousSortKey isEqualToString:BDSKImportOrderString]) {
            [previousSortKey release];
            previousSortKey = [BDSKTitleString retain];
        }
        if ([sortKey isEqualToString:BDSKImportOrderString]) {
            newSortKey = [[previousSortKey retain] autorelease];
            docState.sortDescending = NO;
        }
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
    if([groups containsObjectIdenticalTo:[notification object]] == NO)
        return;
    if([sortGroupsKey isEqualToString:BDSKGroupCellStringKey])
        [self sortGroupsByKey:sortGroupsKey];
    else
        [groupTableView setNeedsDisplay:YES];
}


- (void)handleWebGroupUpdatedNotification:(NSNotification *)notification{
    BDSKGroup *group = [notification object];
    BOOL succeeded = [[[notification userInfo] objectForKey:@"succeeded"] boolValue];
    
    if ([[groups webGroup] isEqual:group] == NO)
        return; // must be from another document
    
    [groupTableView reloadData];
    if ([[self selectedGroups] containsObject:group])
        [self displaySelectedGroups];
    
    if (succeeded)
        [self setImported:YES forPublications:publications inGroup:group];
}


- (void)handleStaticGroupChangedNotification:(NSNotification *)notification{
    BDSKGroup *group = [notification object];
    
    if ([[groups staticGroups] containsObject:group] == NO)
        return; /// must be from another document
    
    [groupTableView reloadData];
    if ([[self selectedGroups] containsObject:group])
        [self displaySelectedGroups];
}

- (void)handleSharedGroupUpdatedNotification:(NSNotification *)notification{
    BDSKGroup *group = [notification object];
    BOOL succeeded = [[[notification userInfo] objectForKey:@"succeeded"] boolValue];
    
    if([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]){
        [self sortGroupsByKey:sortGroupsKey];
    }else{
        [groupTableView reloadData];
        if ([[self selectedGroups] containsObject:group] && succeeded == YES)
            [self displaySelectedGroups];
    }
    
    if (succeeded)
        [self setImported:YES forPublications:publications inGroup:group];
}

- (void)handleSharedGroupsChangedNotification:(NSNotification *)notification{

    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    [groupTableView setDelegate:nil];
	NSArray *selectedGroups = [self selectedGroups];
	
    NSMutableArray *array = [[[BDSKSharingBrowser sharedBrowser] sharedGroups] mutableCopy];
    
    if (array != nil) {
        // now sort using the current column and order
        SEL sortSelector = ([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]) ? @selector(countCompare:) : @selector(nameCompare:);
        [array sortUsingSelector:sortSelector ascending:!docState.sortGroupsDescending];
    }
    [groups setSharedGroups:array];
    [array release];
    
    [groupTableView reloadData];
	
	// select the current groups, if still around. Otherwise this selects Library
    [self selectGroups:selectedGroups];
    
    // the selection may not have changed, so we won't get this from the notification, and we're not the delegate now anyway
    [self displaySelectedGroups]; 
        
    // Don't flag as imported here, since that forces a (re)load of the shared groups, and causes the spinners to start when just opening a document.  The handleSharedGroupUpdatedNotification: should be enough.
    
	// reset ourself as delegate
    [groupTableView setDelegate:self];
}

- (void)handleURLGroupUpdatedNotification:(NSNotification *)notification{
    BDSKGroup *group = [notification object];
    BOOL succeeded = [[[notification userInfo] objectForKey:@"succeeded"] boolValue];
    
    if ([[groups URLGroups] containsObject:group] == NO)
        return; /// must be from another document
    
    if([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]){
        [self sortGroupsByKey:sortGroupsKey];
    }else{
        [groupTableView reloadData];
        if ([[self selectedGroups] containsObject:group] && succeeded == YES)
            [self displaySelectedGroups];
    }
    
    if (succeeded)
        [self setImported:YES forPublications:publications inGroup:group];
}

- (void)handleScriptGroupUpdatedNotification:(NSNotification *)notification{
    BDSKGroup *group = [notification object];
    BOOL succeeded = [[[notification userInfo] objectForKey:@"succeeded"] boolValue];
    
    if ([[groups scriptGroups] containsObject:group] == NO)
        return; /// must be from another document
    
    if([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]){
        [self sortGroupsByKey:sortGroupsKey];
    }else{
        [groupTableView reloadData];
        if ([[self selectedGroups] containsObject:group] && succeeded == YES)
            [self displaySelectedGroups];
    }
    
    if (succeeded)
        [self setImported:YES forPublications:publications inGroup:group];
}

- (void)handleSearchGroupUpdatedNotification:(NSNotification *)notification{
    BDSKGroup *group = [notification object];
    BOOL succeeded = [[[notification userInfo] objectForKey:@"succeeded"] boolValue];
    
    if ([[groups searchGroups] containsObject:group] == NO)
        return; /// must be from another document
    
    [groupTableView reloadData];
    if ([[self selectedGroups] containsObject:group] && succeeded == YES)
        [self displaySelectedGroups];
    
    if (succeeded)
        [self setImported:YES forPublications:publications inGroup:group];
}


- (void)handleWillAddRemoveGroupNotification:(NSNotification *)notification{
    if([groupTableView editedRow] != -1 && [documentWindow makeFirstResponder:nil] == NO)
        [documentWindow endEditingFor:groupTableView];
}

- (void)handleDidAddRemoveGroupNotification:(NSNotification *)notification{
    [groupTableView reloadData];
    [self handleGroupTableSelectionChangedNotification:notification];
}

#pragma mark UI updating

// this method uses counted sets to compute the number of publications per group; each group object is just a name
// and a count, and a group knows how to compare itself with other groups for sorting/equality, but doesn't know 
// which pubs are associated with it
- (void)updateCategoryGroupsPreservingSelection:(BOOL)preserve{

    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    [groupTableView setDelegate:nil];
    
    NSPoint scrollPoint = [[tableView enclosingScrollView] scrollPositionAsPercentage];    
    
	NSArray *selectedGroups = [self selectedGroups];
	
    NSString *groupField = [self currentGroupField];
    
    if ([NSString isEmptyString:groupField]) {
        
        [groups setCategoryGroups:[NSArray array]];
        
    } else {
        
        BDSKCountedSet *countedSet;
        if([groupField isPersonField])
            countedSet = [[BDSKCountedSet alloc] initFuzzyAuthorCountedSet];
        else
            countedSet = [[BDSKCountedSet alloc] initCaseInsensitive:YES withCapacity:[publications count]];
        
        int emptyCount = 0;
        
        NSEnumerator *pubEnum = [publications objectEnumerator];
        BibItem *pub;
        
        NSSet *tmpSet = nil;
        while(pub = [pubEnum nextObject]){
            tmpSet = [pub groupsForField:groupField];
            if([tmpSet count])
                [countedSet unionSet:tmpSet];
            else
                emptyCount++;
        }
        
        NSMutableArray *mutableGroups = [[NSMutableArray alloc] initWithCapacity:[countedSet count] + 1];
        NSEnumerator *groupEnum = [countedSet objectEnumerator];
        id groupName;
        BDSKGroup *group;
                
        // now add the group names that we found from our BibItems, using a generic folder icon
        // use OATextWithIconCell keys
        while(groupName = [groupEnum nextObject]){
            group = [[BDSKCategoryGroup alloc] initWithName:groupName key:groupField count:[countedSet countForObject:groupName]];
            [mutableGroups addObject:group];
            [group release];
        }
        
        // now sort using the current column and order
        SEL sortSelector = ([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]) ?
                            @selector(countCompare:) : @selector(nameCompare:);
        [mutableGroups sortUsingSelector:sortSelector ascending:!docState.sortGroupsDescending];
        
        // add the "empty" group at index 0; this is a group of pubs whose value is empty for this field, so they
        // will not be contained in any of the other groups for the currently selected group field (hence multiple selection is desirable)
        if(emptyCount > 0){
            group = [[BDSKCategoryGroup alloc] initEmptyGroupWithKey:groupField count:emptyCount];
            [mutableGroups insertObject:group atIndex:0];
            [group release];
        }
        
        [groups setCategoryGroups:mutableGroups];
        [countedSet release];
        [mutableGroups release];
        
    }
    
    // update the count for the first item, not sure if it should be done here
    [[groups libraryGroup] setCount:[publications count]];
	
    [groupTableView reloadData];
	
	// select the current groups, if still around. Otherwise select Library
	BOOL didSelect = [self selectGroups:selectedGroups];
    
	[self displaySelectedGroups]; // the selection may not have changed, so we won't get this from the notification
    
    // The search: in displaySelectedGroups will change the main table's scroll location, which isn't necessarily what we want (say when clicking the add button for a search group pub).  If we selected the same groups as previously, we should scroll to the old location instead of centering.
    if (didSelect)
        [[tableView enclosingScrollView] setScrollPositionAsPercentage:scrollPoint];
    
	// reset ourself as delegate
    [groupTableView setDelegate:self];
}

// force the smart groups to refilter their items, so the group content and count get redisplayed
// if this becomes slow, we could make filters thread safe and update them in the background
- (void)updateSmartGroupsCountAndContent:(BOOL)shouldUpdate{

	NSRange smartRange = [groups rangeOfSmartGroups];
    unsigned int row = NSMaxRange(smartRange);
	BOOL needsUpdate = NO;
    
    while(NSLocationInRange(--row, smartRange)){
		[(BDSKSmartGroup *)[groups objectAtIndex:row] filterItems:publications];
		if([groupTableView isRowSelected:row])
			needsUpdate = shouldUpdate;
    }
    
    if([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]){
        NSPoint scrollPoint = [[tableView enclosingScrollView] scrollPositionAsPercentage];
        [self sortGroupsByKey:sortGroupsKey];
        [[tableView enclosingScrollView] setScrollPositionAsPercentage:scrollPoint];
    }else{
        [groupTableView reloadData];
        if(needsUpdate == YES){
            // fix for bug #1362191: after changing a checkbox that removed an item from a smart group, the table scrolled to the top
            NSPoint scrollPoint = [[tableView enclosingScrollView] scrollPositionAsPercentage];
            [self displaySelectedGroups];
            [[tableView enclosingScrollView] setScrollPositionAsPercentage:scrollPoint];
        }
    }
}

- (void)displaySelectedGroups{
    NSArray *selectedGroups = [self selectedGroups];
    NSArray *array;
    
    // optimize for single selections
    if ([selectedGroups count] == 1 && [self hasLibraryGroupSelected]) {
        array = publications;
    } else if ([selectedGroups count] == 1 && ([self hasExternalGroupsSelected] || [self hasStaticGroupsSelected])) {
        unsigned int rowIndex = [[groupTableView selectedRowIndexes] firstIndex];
        BDSKGroup *group = [groups objectAtIndex:rowIndex];
        array = [(id)group publications];
    } else {
        // multiple selections are never shared groups, so they are contained in the publications
        NSEnumerator *pubEnum = [publications objectEnumerator];
        BibItem *pub;
        NSEnumerator *groupEnum;
        BDSKGroup *group;
        NSMutableArray *filteredArray = [NSMutableArray arrayWithCapacity:[publications count]];
        BOOL intersectGroups = [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKIntersectGroupsKey];
        
        // to take union, we add the items contained in a selected group
        // to intersect, we remove the items not contained in a selected group
        if (intersectGroups)
            [filteredArray setArray:publications];
        
        while (pub = [pubEnum nextObject]) {
            groupEnum = [selectedGroups objectEnumerator];
            while (group = [groupEnum nextObject]) {
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
    
    [searchField sendAction:[searchField action] to:[searchField target]]; // redo the search to update the table
}

- (BOOL)selectGroups:(NSArray *)theGroups{
    NSIndexSet *indexes = [groups indexesOfObjects:theGroups];
    
    if([indexes count] == 0) {
        [groupTableView deselectAll:nil];
        return NO;
    } else {
        [groupTableView selectRowIndexes:indexes byExtendingSelection:NO];
        return YES;
    }
}

- (BOOL)selectGroup:(BDSKGroup *)aGroup{
    return [self selectGroups:[NSArray arrayWithObject:aGroup]];
}

- (NSIndexSet *)_indexesOfRowsToHighlightInRange:(NSRange)indexRange tableView:(BDSKGroupTableView *)tview{
   
    if([self numberOfSelectedPubs] == 0 || 
       [self hasExternalGroupsSelected] == YES)
        return [NSIndexSet indexSet];
    
    // This allows us to be slightly lazy, only putting the visible group rows in the dictionary
    NSMutableIndexSet *visibleIndexes = [NSMutableIndexSet indexSetWithIndexesInRange:indexRange];
    [visibleIndexes removeIndexes:[groupTableView selectedRowIndexes]];
    
    NSMutableIndexSet *categoryIndexes = [NSMutableIndexSet indexSetWithIndexesInRange:[groups rangeOfCategoryGroups]];
    unsigned int cnt = [categoryIndexes count];
    NSString *groupField = [self currentGroupField];

    // Mutable dictionary with fixed capacity using NSObjects for keys with ints for values; this gives us a fast lookup of row name->index.  Dictionaries can use any pointer-size element for a key or value; see /Developer/Examples/CoreFoundation/Dictionary.  Keys are retained rather than copied for efficiency.  Shark says that BibAuthors are created with alloc/init when using the copy callbacks, so NSShouldRetainWithZone() must be returning NO?
    CFMutableDictionaryRef rowDict;
    
    // group objects are either BibAuthors or NSStrings; we need to use case-insensitive or fuzzy author matching, since that's the way groups are checked for containment
    if([groupField isPersonField]){
        rowDict = CFDictionaryCreateMutable(CFAllocatorGetDefault(), cnt, &BDSKFuzzyDictionaryKeyCallBacks, &OFIntegerDictionaryValueCallbacks);
    } else {
        rowDict = CFDictionaryCreateMutable(CFAllocatorGetDefault(), cnt, &BDSKCaseInsensitiveStringKeyDictionaryCallBacks, &OFIntegerDictionaryValueCallbacks);
    }
    
    unsigned int groupIndex = [categoryIndexes firstIndex];
    
    // exclude smart and shared groups
    while(groupIndex != NSNotFound){
		if([visibleIndexes containsIndex:groupIndex])
			CFDictionaryAddValue(rowDict, (void *)[[groups objectAtIndex:groupIndex] name], (void *)groupIndex);
        groupIndex = [visibleIndexes indexGreaterThanIndex:groupIndex];
    }
    
    // Use this for the indexes we're going to return
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    
    // Unfortunately, we have to check all of the items in the main table, since hidden items may have a visible group
    NSArray *selectedPubs = [self selectedPublications];
    NSEnumerator *pubEnum = [selectedPubs objectEnumerator];
    BibItem *pub;
    CFSetRef possibleGroups;
    
    id *groupNamePtr;
    
    // use a static pointer to a buffer, with initial size of 10
    static id *groupValues = NULL;
    static int groupValueMaxSize = 10;
    if(NULL == groupValues)
        groupValues = (id *)NSZoneMalloc(NSDefaultMallocZone(), groupValueMaxSize * sizeof(id));
    int groupCount = 0;
    
    // we could iterate the dictionary in the outer loop and publications in the inner loop, but there are generally more publications than groups (and we only check visible groups), so this should be more efficient
    while(pub = [pubEnum nextObject]){ 
        
        // here are all the groups that this item can be a part of
        possibleGroups = (CFSetRef)[pub groupsForField:groupField];
        
        groupCount = CFSetGetCount(possibleGroups);
        if(groupCount > groupValueMaxSize){
            NSAssert1(groupCount < 1024, @"insane number of groups for %@", [pub citeKey]);
            groupValues = NSZoneRealloc(NSDefaultMallocZone(), groupValues, sizeof(id) * groupCount);
            groupValueMaxSize = groupCount;
        }
        
        // get all the groups (authors or strings)
        if(groupCount > 0){
            
            // this is the only way to enumerate a set with CF, apparently
            CFSetGetValues(possibleGroups, (const void **)groupValues);
            groupNamePtr = groupValues;
            
            while(groupCount--){
                // The dictionary only has visible group rows, so not all of the keys (potential groups) will exist in the dictionary
                if(CFDictionaryGetValueIfPresent(rowDict, (void *)*groupNamePtr++, (const void **)&cnt))
                    [indexSet addIndex:cnt];
            }
        }
    }
    
    CFRelease(rowDict);
    
    // handle smart and static groups separately, since they have a different approach to containment
    NSMutableIndexSet *staticAndSmartIndexes = [NSMutableIndexSet indexSetWithIndexesInRange:[groups rangeOfSmartGroups]];
    [staticAndSmartIndexes addIndexesInRange:[groups rangeOfStaticGroups]];
    
    if([staticAndSmartIndexes count]){
        groupIndex = [staticAndSmartIndexes firstIndex];
        id aGroup;
        
        while(groupIndex != NSNotFound){
            if([visibleIndexes containsIndex:groupIndex]){
                
                aGroup = [groups objectAtIndex:groupIndex];
                pubEnum = [selectedPubs objectEnumerator];
                
                while(pub = [pubEnum nextObject]){
                
                    if([(BDSKGroup *)aGroup containsItem:pub]){
                        [indexSet addIndex:groupIndex];
                        break;
                    }
                }
            }
            groupIndex = [staticAndSmartIndexes indexGreaterThanIndex:groupIndex];
        }
    }
    
    return indexSet;
}

- (NSIndexSet *)_tableViewSingleSelectionIndexes:(BDSKGroupTableView *)tview{
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSetWithIndexesInRange:[groups rangeOfSharedGroups]];
    [indexes addIndexesInRange:[groups rangeOfURLGroups]];
    [indexes addIndexesInRange:[groups rangeOfScriptGroups]];
    [indexes addIndexesInRange:[groups rangeOfSearchGroups]];
    [indexes addIndex:0];
    return indexes;
}

- (NSMenu *)groupFieldsMenu {
	NSMenu *menu = [[NSMenu allocWithZone:[NSMenu menuZone]] init];
	NSMenuItem *menuItem;
	NSEnumerator *fieldEnum = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKGroupFieldsKey] objectEnumerator];
	NSString *field;
	
    [menu addItemWithTitle:NSLocalizedString(@"No Field", @"Menu item title") action:NULL keyEquivalent:@""];
	
	while (field = [fieldEnum nextObject]) {
		menuItem = [menu addItemWithTitle:field action:NULL keyEquivalent:@""];
        [menuItem setRepresentedObject:field];
	}
    
    [menu addItem:[NSMenuItem separatorItem]];
	
	menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Add Field", @"Menu item title") stringByAppendingEllipsis]
										  action:@selector(addGroupFieldAction:)
								   keyEquivalent:@""];
	[menuItem setTarget:self];
	[menu addItem:menuItem];
    [menuItem release];
	
	menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Remove Field", @"Menu item title") stringByAppendingEllipsis]
										  action:@selector(removeGroupFieldAction:)
								   keyEquivalent:@""];
	[menuItem setTarget:self];
	[menu addItem:menuItem];
    [menuItem release];
	
	return [menu autorelease];
}

- (NSMenu *)tableView:(BDSKGroupTableView *)aTableView menuForTableHeaderColumn:(NSTableColumn *)tableColumn onPopUp:(BOOL)flag{
	if ([[tableColumn identifier] isEqualToString:@"group"] && flag == NO) {
		return [[NSApp delegate] groupSortMenu];
	}
	return nil;
}

#pragma mark Actions

- (IBAction)sortGroupsByGroup:(id)sender{
	if ([sortGroupsKey isEqualToString:BDSKGroupCellStringKey]) return;
	[self sortGroupsByKey:BDSKGroupCellStringKey];
}

- (IBAction)sortGroupsByCount:(id)sender{
	if ([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]) return;
	[self sortGroupsByKey:BDSKGroupCellCountKey];
}

- (IBAction)changeGroupFieldAction:(id)sender{
	NSPopUpButtonCell *headerCell = [groupTableView popUpHeaderCell];
	NSString *field = ([headerCell indexOfSelectedItem] == 0) ? @"" : [[headerCell selectedItem] representedObject];
    
	if(![field isEqualToString:currentGroupField]){
		[self setCurrentGroupField:field];
        [headerCell setTitle:[headerCell titleOfSelectedItem]];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupFieldChangedNotification
															object:self
														  userInfo:[NSDictionary dictionary]];
	}
}

// for adding/removing groups, we use the searchfield sheets
    
- (void)addGroupFieldSheetDidEnd:(BDSKAddFieldSheetController *)addFieldController returnCode:(int)returnCode contextInfo:(void *)contextInfo{
	NSString *newGroupField = [addFieldController field];
    if(returnCode == NSCancelButton || newGroupField == nil)
        return; // the user canceled
    
	if([newGroupField isInvalidGroupField] || [newGroupField isEqualToString:@""]){
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Field", @"Message in alert dialog when choosing an invalid group field")
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                            informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"The field \"%@\" can not be used for groups.", @"Informative text in alert dialog"), [newGroupField localizedFieldName]]];
        [alert beginSheetModalForWindow:documentWindow modalDelegate:self didEndSelector:NULL contextInfo:NULL];
		return;
	}
	
	NSMutableArray *array = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKGroupFieldsKey] mutableCopy];
	[array addObject:newGroupField];
	[[OFPreferenceWrapper sharedPreferenceWrapper] setObject:array forKey:BDSKGroupFieldsKey];	
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupFieldAddRemoveNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionaryWithObjectsAndKeys:newGroupField, NSKeyValueChangeNewKey, [NSNumber numberWithInt:NSKeyValueChangeInsertion], NSKeyValueChangeKindKey, nil]];        
    
	NSPopUpButtonCell *headerCell = [groupTableView popUpHeaderCell];
	
	[headerCell insertItemWithTitle:newGroupField atIndex:[array count]];
	[[headerCell itemAtIndex:[array count]] setRepresentedObject:newGroupField];
	[self setCurrentGroupField:newGroupField];
	[headerCell selectItemAtIndex:[headerCell indexOfItemWithRepresentedObject:currentGroupField]];
	[headerCell setTitle:[headerCell titleOfSelectedItem]];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupFieldChangedNotification
														object:self
													  userInfo:[NSDictionary dictionary]];
    [array release];
}    

- (IBAction)addGroupFieldAction:(id)sender{
	NSPopUpButtonCell *headerCell = [groupTableView popUpHeaderCell];
	
    if ([currentGroupField isEqualToString:@""])
        [headerCell selectItemAtIndex:0];
    else 
        [headerCell selectItemAtIndex:[headerCell indexOfItemWithRepresentedObject:currentGroupField]];
	[headerCell setTitle:[headerCell titleOfSelectedItem]];
    
	BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
	NSArray *groupFields = [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKGroupFieldsKey];
    NSArray *colNames = [typeMan allFieldNamesIncluding:[NSArray arrayWithObjects:BDSKPubTypeString, BDSKCrossrefString, nil]
                                              excluding:[[[typeMan invalidGroupFieldsSet] allObjects] arrayByAddingObjectsFromArray:groupFields]];
    
    BDSKAddFieldSheetController *addFieldController = [[BDSKAddFieldSheetController alloc] initWithPrompt:NSLocalizedString(@"Name of group field:", @"Label for adding group field")
                                                                                              fieldsArray:colNames];
	[addFieldController beginSheetModalForWindow:documentWindow
                                   modalDelegate:self
                                  didEndSelector:NULL
                              didDismissSelector:@selector(addGroupFieldSheetDidEnd:returnCode:contextInfo:)
                                     contextInfo:NULL];
    [addFieldController release];
}

- (void)removeGroupFieldSheetDidEnd:(BDSKRemoveFieldSheetController *)removeFieldController returnCode:(int)returnCode contextInfo:(void *)contextInfo{
	NSString *oldGroupField = [removeFieldController field];
    if(returnCode == NSCancelButton || [NSString isEmptyString:oldGroupField])
        return;
    
    NSMutableArray *array = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKGroupFieldsKey] mutableCopy];
    [array removeObject:oldGroupField];
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:array forKey:BDSKGroupFieldsKey];
    [array release];
    
	NSPopUpButtonCell *headerCell = [groupTableView popUpHeaderCell];
	
    [headerCell removeItemWithTitle:oldGroupField];
    if([oldGroupField isEqualToString:currentGroupField]){
        [self setCurrentGroupField:@""];
        [headerCell selectItemAtIndex:0];
        [headerCell setTitle:@""];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupFieldChangedNotification
                                                            object:self
                                                          userInfo:[NSDictionary dictionary]];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupFieldAddRemoveNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionaryWithObjectsAndKeys:oldGroupField, NSKeyValueChangeNewKey, [NSNumber numberWithInt:NSKeyValueChangeRemoval], NSKeyValueChangeKindKey, nil]];        
}

- (IBAction)removeGroupFieldAction:(id)sender{
	NSPopUpButtonCell *headerCell = [groupTableView popUpHeaderCell];
	
    if ([currentGroupField isEqualToString:@""])
        [headerCell selectItemAtIndex:0];
    else 
        [headerCell selectItemAtIndex:[headerCell indexOfItemWithRepresentedObject:currentGroupField]];
	[headerCell setTitle:[headerCell titleOfSelectedItem]];
    
    BDSKRemoveFieldSheetController *removeFieldController = [[BDSKRemoveFieldSheetController alloc] initWithPrompt:NSLocalizedString(@"Group field to remove:", @"Label for removing group field")
                                                                                                       fieldsArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKGroupFieldsKey]];
	[removeFieldController beginSheetModalForWindow:documentWindow
                                      modalDelegate:self
                                     didEndSelector:@selector(removeGroupFieldSheetDidEnd:returnCode:contextInfo:)
                                        contextInfo:NULL];
    [removeFieldController release];
}    

- (void)handleGroupFieldAddRemoveNotification:(NSNotification *)notification{
    // Handle changes to the popup from other documents.  The userInfo for this notification uses key-value observing keys: NSKeyValueChangeNewKey is the affected field (whether add/remove), and NSKeyValueChangeKindKey will be either insert/remove
    if([notification object] != self){
        NSPopUpButtonCell *headerCell = [groupTableView popUpHeaderCell];
        
        id userInfo = [notification userInfo];
        NSParameterAssert(userInfo && [userInfo valueForKey:NSKeyValueChangeKindKey]);

        NSString *field = [userInfo valueForKey:NSKeyValueChangeNewKey];
        NSParameterAssert(field);
        
        // Ignore this change if we already have that field (shouldn't happen), or are removing the current group field; in the latter case, it's already removed in prefs, so it'll be gone next time the document is opened.  Removing all fields means we have to deal with the add/remove menu items and separator, so avoid that.
        if([[[headerCell selectedItem] representedObject] isEqualToString:field] == NO){
            int changeType = [[userInfo valueForKey:NSKeyValueChangeKindKey] intValue];
            
            if(changeType == NSKeyValueChangeInsertion) {
                [headerCell insertItemWithTitle:field atIndex:0];
                [[headerCell itemAtIndex:0] setRepresentedObject:field];
            } else if(changeType == NSKeyValueChangeRemoval) {
                [headerCell removeItemAtIndex:[headerCell indexOfItemWithRepresentedObject:field]];
            } else [NSException raise:NSInvalidArgumentException format:@"Unrecognized change type %d", changeType];
        }
    }
}

- (IBAction)addSmartGroupAction:(id)sender {
	BDSKFilterController *filterController = [[BDSKFilterController alloc] init];
    [filterController beginSheetModalForWindow:documentWindow
                                 modalDelegate:self
                                didEndSelector:@selector(smartGroupSheetDidEnd:returnCode:contextInfo:)
                                   contextInfo:NULL];
	[filterController release];
}

- (void)smartGroupSheetDidEnd:(BDSKFilterController *)filterController returnCode:(int) returnCode contextInfo:(void *)contextInfo{
	if(returnCode == NSOKButton){
		BDSKSmartGroup *group = [[BDSKSmartGroup alloc] initWithFilter:[filterController filter]];
        unsigned int insertIndex = NSMaxRange([groups rangeOfSmartGroups]);
		[groups addSmartGroup:group];
		[group release];
		
		[groupTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
		[groupTableView editColumn:0 row:insertIndex withEvent:nil select:YES];
		[[self undoManager] setActionName:NSLocalizedString(@"Add Smart Group", @"Undo action name")];
		// updating of the tables is done when finishing the edit of the name
	}
	
}

- (IBAction)addStaticGroupAction:(id)sender {
    BDSKStaticGroup *group = [[BDSKStaticGroup alloc] init];
    unsigned int insertIndex = NSMaxRange([groups rangeOfStaticGroups]);
    [groups addStaticGroup:group];
    [group release];
    
    [groupTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
    [groupTableView editColumn:0 row:insertIndex withEvent:nil select:YES];
    [[self undoManager] setActionName:NSLocalizedString(@"Add Static Group", @"Undo action name")];
    // updating of the tables is done when finishing the edit of the name
}

- (void)searchGroupSheetDidEnd:(BDSKSearchGroupSheetController *)sheetController returnCode:(int) returnCode contextInfo:(void *)contextInfo{
	if(returnCode == NSOKButton){
        unsigned int insertIndex = NSMaxRange([groups rangeOfSearchGroups]);
        BDSKGroup *group = [sheetController group];
		[groups addSearchGroup:(id)group];        
		[groupTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
	}
}

- (IBAction)addSearchGroupAction:(id)sender {
    BDSKSearchGroupSheetController *sheetController = [[BDSKSearchGroupSheetController alloc] init];
    [sheetController beginSheetModalForWindow:documentWindow
                                modalDelegate:self
                               didEndSelector:@selector(searchGroupSheetDidEnd:returnCode:contextInfo:)
                                  contextInfo:NULL];
    [sheetController release];
}

- (IBAction)newSearchGroupFromBookmark:(id)sender {
    NSDictionary *dict = [sender representedObject];
    BDSKSearchGroup *group = [[[BDSKSearchGroup alloc] initWithDictionary:dict] autorelease];
    unsigned int insertIndex = NSMaxRange([groups rangeOfSearchGroups]);
    [groups addSearchGroup:(id)group];        
    [groupTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
}

- (void)searchBookmarkSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSOKButton) {
        BDSKGroup *group = [[self selectedGroups] lastObject];
        BDSKSearchBookmark *folder = [[searchBookmarkPopUp selectedItem] representedObject];
        [[BDSKSearchBookmarkController sharedBookmarkController] addBookmarkWithInfo:[group dictionaryValue] label:[searchBookmarkField stringValue] toFolder:folder];
    }
}

- (void)addMenuItemsForBookmarks:(NSArray *)bookmarksArray level:(int)level toMenu:(NSMenu *)menu {
    int i, iMax = [bookmarksArray count];
    for (i = 0; i < iMax; i++) {
        BDSKSearchBookmark *bm = [bookmarksArray objectAtIndex:i];
        if ([bm bookmarkType] == BDSKSearchBookmarkTypeFolder) {
            NSString *label = [bm label];
            NSMenuItem *item = [menu addItemWithTitle:label ? label : @"" action:NULL keyEquivalent:@""];
            [item setImage:[bm icon]];
            [item setIndentationLevel:level];
            [item setRepresentedObject:bm];
            [self addMenuItemsForBookmarks:[bm children] level:level+1 toMenu:menu];
        }
    }
}

- (IBAction)addSearchBookmark:(id)sender {
    if ([self hasSearchGroupsSelected] == NO) {
        NSBeep();
        return;
    }
    
    BDSKSearchGroup *group = (BDSKSearchGroup *)[[self selectedGroups] lastObject];
	[searchBookmarkField setStringValue:[NSString stringWithFormat:@"%@: %@", [[group serverInfo] name], [group name]]];
    [searchBookmarkPopUp removeAllItems];
    NSArray *bookmarks = [[BDSKSearchBookmarkController sharedBookmarkController] bookmarks];
    NSMenuItem *item = [[searchBookmarkPopUp menu] addItemWithTitle:NSLocalizedString(@"Bookmarks Menu", @"Menu item title") action:NULL keyEquivalent:@""];
    [item setImage:[NSImage imageNamed:@"SmallMenu"]];
    [self addMenuItemsForBookmarks:bookmarks level:1 toMenu:[searchBookmarkPopUp menu]];
    [searchBookmarkPopUp selectItemAtIndex:0];
    
    [NSApp beginSheet:searchBookmarkSheet
       modalForWindow:[self windowForSheet]
        modalDelegate:self 
       didEndSelector:@selector(searchBookmarkSheetDidEnd:returnCode:contextInfo:)
          contextInfo:NULL];
}

- (IBAction)dismissSearchBookmarkSheet:(id)sender {
    [NSApp endSheet:searchBookmarkSheet returnCode:[sender tag]];
    [searchBookmarkSheet orderOut:self];
}

- (IBAction)addURLGroupAction:(id)sender {
    BDSKURLGroupSheetController *sheetController = [[BDSKURLGroupSheetController alloc] init];
    [sheetController beginSheetModalForWindow:documentWindow
                                modalDelegate:self
                               didEndSelector:@selector(URLGroupSheetDidEnd:returnCode:contextInfo:)
                                  contextInfo:NULL];
    [sheetController release];
}

- (void)URLGroupSheetDidEnd:(BDSKURLGroupSheetController *)sheetController returnCode:(int) returnCode contextInfo:(void *)contextInfo{
	if(returnCode == NSOKButton){
        unsigned int insertIndex = NSMaxRange([groups rangeOfURLGroups]);
        BDSKURLGroup *group = [sheetController group];
		[groups addURLGroup:group];
        [group publications];
        
		[groupTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
		[groupTableView editColumn:0 row:insertIndex withEvent:nil select:YES];
		[[self undoManager] setActionName:NSLocalizedString(@"Add External File Group", @"Undo action name")];
		// updating of the tables is done when finishing the edit of the name
	}
}

- (IBAction)addScriptGroupAction:(id)sender {
    BDSKScriptGroupSheetController *sheetController = [[BDSKScriptGroupSheetController alloc] init];
    [sheetController beginSheetModalForWindow:documentWindow
                                modalDelegate:self
                               didEndSelector:@selector(scriptGroupSheetDidEnd:returnCode:contextInfo:)
                                  contextInfo:NULL];
    [sheetController release];
}

- (void)scriptGroupSheetDidEnd:(BDSKScriptGroupSheetController *)sheetController returnCode:(int) returnCode contextInfo:(void *)contextInfo{
	if(returnCode == NSOKButton){
        unsigned int insertIndex = NSMaxRange([groups rangeOfScriptGroups]);
        BDSKScriptGroup *group = [sheetController group];
		[groups addScriptGroup:group];
        [group publications];
        
		[groupTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
		[groupTableView editColumn:0 row:insertIndex withEvent:nil select:YES];
		[[self undoManager] setActionName:NSLocalizedString(@"Add Script Group", @"Undo action name")];
		// updating of the tables is done when finishing the edit of the name
	}
	
}

- (IBAction)addGroupButtonAction:(id)sender {
    if ([NSApp currentModifierFlags] & NSAlternateKeyMask)
        [self addSmartGroupAction:sender];
    else
        [self addStaticGroupAction:sender];
}

- (IBAction)removeSelectedGroups:(id)sender {
	NSIndexSet *rowIndexes = [groupTableView selectedRowIndexes];
    unsigned int rowIndex = [rowIndexes lastIndex];
	BDSKGroup *group;
	unsigned int count = 0;
	
	while (rowIndexes != nil && rowIndex != NSNotFound) {
		group = [groups objectAtIndex:rowIndex];
		if ([group isSmart] == YES) {
			[groups removeSmartGroup:(BDSKSmartGroup *)group];
			count++;
		} else if ([group isStatic] == YES && [group isEqual:[groups lastImportGroup]] == NO) {
			[groups removeStaticGroup:(BDSKStaticGroup *)group];
			count++;
		} else if ([group isURL] == YES) {
			[groups removeURLGroup:(BDSKURLGroup *)group];
			count++;
		} else if ([group isScript] == YES) {
			[groups removeScriptGroup:(BDSKScriptGroup *)group];
			count++;
		} else if ([group isSearch] == YES) {
			[groups removeSearchGroup:(BDSKSearchGroup *)group];
        }
		rowIndex = [rowIndexes indexLessThanIndex:rowIndex];
	}
	if (count > 0) {
		[[self undoManager] setActionName:NSLocalizedString(@"Remove Groups", @"Undo action name")];
        [self displaySelectedGroups];
	}
}

- (void)editGroupAtRow:(int)row {
	OBASSERT(row != -1);
	BDSKGroup *group = [groups objectAtIndex:row];
    
    if ([group isEditable] == NO) {
		NSBeep();
        return;
    }
    
	if ([group isSmart]) {
		BDSKFilter *filter = [(BDSKSmartGroup *)group filter];
		BDSKFilterController *filterController = [[BDSKFilterController alloc] initWithFilter:filter];
        [filterController beginSheetModalForWindow:documentWindow];
        [filterController release];
	} else if ([group isCategory]) {
        // this must be a person field
        OBASSERT([[group name] isKindOfClass:[BibAuthor class]]);
		[self showPerson:(BibAuthor *)[group name]];
	} else if ([group isURL]) {
        BDSKURLGroupSheetController *sheetController = [(BDSKURLGroupSheetController *)[BDSKURLGroupSheetController alloc] initWithGroup:(BDSKURLGroup *)group];
        [sheetController beginSheetModalForWindow:documentWindow];
        [sheetController release];
	} else if ([group isScript]) {
        BDSKScriptGroupSheetController *sheetController = [(BDSKScriptGroupSheetController *)[BDSKScriptGroupSheetController alloc] initWithGroup:(BDSKScriptGroup *)group];
        [sheetController beginSheetModalForWindow:documentWindow];
        [sheetController release];
	} else if ([group isSearch]) {
        BDSKSearchGroupSheetController *sheetController = [(BDSKSearchGroupSheetController *)[BDSKSearchGroupSheetController alloc] initWithGroup:(BDSKSearchGroup *)group];
        [sheetController beginSheetModalForWindow:documentWindow];
        [sheetController release];
	}
}

- (IBAction)editGroupAction:(id)sender {
	if ([groupTableView numberOfSelectedRows] != 1) {
		NSBeep();
		return;
	} 
	
	int row = [groupTableView selectedRow];
	OBASSERT(row != -1);
	if(row > 0) [self editGroupAtRow:row];
}

- (IBAction)renameGroupAction:(id)sender {
	if ([groupTableView numberOfSelectedRows] != 1) {
		NSBeep();
		return;
	} 
	
	int row = [groupTableView selectedRow];
	OBASSERT(row != -1);
	if (row <= 0) return;
    
    if([self tableView:groupTableView shouldEditTableColumn:[[groupTableView tableColumns] objectAtIndex:0] row:row])
		[groupTableView editColumn:0 row:row withEvent:nil select:YES];
	
}

- (IBAction)selectLibraryGroup:(id)sender {
	[groupTableView deselectAll:sender];
}

- (IBAction)changeIntersectGroupsAction:(id)sender {
    BOOL flag = (BOOL)[sender tag];
    if ([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKIntersectGroupsKey] != flag) {
        [[OFPreferenceWrapper sharedPreferenceWrapper] setBool:flag forKey:BDSKIntersectGroupsKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupTableSelectionChangedNotification object:self];
    }
}

- (void)editGroupWithoutWarning:(BDSKGroup *)group {
    unsigned i = [groups indexOfObject:group];
    OBASSERT(i != NSNotFound);
    
    if(i != NSNotFound){
        [groupTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
        [groupTableView scrollRowToVisible:i];
        
        // don't show the warning sheet, since presumably the user wants to change the group name
        [groupTableView editColumn:0 row:i withEvent:nil select:YES];
    }
}

- (IBAction)editNewStaticGroupWithSelection:(id)sender{
    NSArray *names = [[groups staticGroups] valueForKeyPath:@"@distinctUnionOfObjects.name"];
    NSArray *pubs = [self selectedPublications];
    NSString *baseName = NSLocalizedString(@"Untitled", @"");
    NSString *name = baseName;
    BDSKStaticGroup *group;
    unsigned int i = 1;
    while([names containsObject:name]){
        name = [NSString stringWithFormat:@"%@%d", baseName, i++];
    }
    
    // first merge in shared groups
    if ([self hasExternalGroupsSelected])
        pubs = [self mergeInPublications:pubs];
    
    group = [[[BDSKStaticGroup alloc] initWithName:name publications:pubs] autorelease];
    
    [groups addStaticGroup:group];    
    [groupTableView deselectAll:nil];
    
    [self performSelector:@selector(editGroupWithoutWarning:) withObject:group afterDelay:0.0];
}

- (IBAction)editNewCategoryGroupWithSelection:(id)sender{
    if ([currentGroupField isEqualToString:@""]) {
        NSBeep();
        return;
    }
    
    BOOL isAuthor = [currentGroupField isPersonField];
    NSArray *names = [[groups categoryGroups] valueForKeyPath:isAuthor ? @"@distinctUnionOfObjects.name.lastName" : @"@distinctUnionOfObjects.name"];
    NSArray *pubs = [self selectedPublications];
    NSString *baseName = NSLocalizedString(@"Untitled", @"");
    id name = baseName;
    BDSKCategoryGroup *group;
    unsigned int i = 1;
    
    while ([names containsObject:name])
        name = [NSString stringWithFormat:@"%@%d", baseName, i++];
    if (isAuthor)
        name = [BibAuthor authorWithName:name andPub:nil];
    group = [[[BDSKCategoryGroup alloc] initWithName:name key:currentGroupField count:[pubs count]] autorelease];
    
    // first merge in shared groups
    if ([self hasExternalGroupsSelected])
        pubs = [self mergeInPublications:pubs];
    
    [self addPublications:pubs toGroup:group];
    [groupTableView deselectAll:nil];
    [self updateCategoryGroupsPreservingSelection:NO];
    
    [self performSelector:@selector(editGroupWithoutWarning:) withObject:group afterDelay:0.0];
}

- (IBAction)mergeInExternalGroup:(id)sender{
    if ([self hasExternalGroupsSelected] == NO) {
        NSBeep();
        return;
    }
    // we should have a single external group selected
    NSArray *pubs = [[[self selectedGroups] lastObject] publications];
    [self mergeInPublications:pubs];
}

- (IBAction)mergeInExternalPublications:(id)sender{
    if ([self hasExternalGroupsSelected] == NO || [self numberOfSelectedPubs] == 0) {
        NSBeep();
        return;
    }
    [self mergeInPublications:[self selectedPublications]];
}

- (IBAction)refreshURLGroups:(id)sender{
    [[groups URLGroups] makeObjectsPerformSelector:@selector(setPublications:) withObject:nil];
}

- (IBAction)refreshScriptGroups:(id)sender{
    [[groups scriptGroups] makeObjectsPerformSelector:@selector(setPublications:) withObject:nil];
}

- (IBAction)refreshSearchGroups:(id)sender{
    [[groups searchGroups] makeObjectsPerformSelector:@selector(setPublications:) withObject:nil];
}

- (IBAction)refreshAllExternalGroups:(id)sender{
    [self refreshSharedBrowsing:sender];
    [self refreshURLGroups:sender];
    [self refreshScriptGroups:sender];
    [self refreshSearchGroups:sender];
}

- (IBAction)refreshSelectedGroups:(id)sender{
    if([self hasExternalGroupsSelected])
        [[[self selectedGroups] firstObject] setPublications:nil];
    else NSBeep();
}

- (IBAction)openBookmark:(id)sender{
    // switch to the web group
    if ([self hasWebGroupSelected] == NO) {
        // make sure the controller and its nib are loaded
        if (nil == webGroupViewController) {
            webGroupViewController = [[BDSKWebGroupViewController alloc] initWithGroup:[groups webGroup] document:self];
            [webGroupViewController window];
        }
        if ([self selectGroup:[groups webGroup]] == NO) {
            NSBeep();
            return;
        }
    }
    [webGroupViewController loadURL:[sender representedObject]];
}

- (IBAction)addBookmark:(id)sender {
    if ([self hasWebGroupSelected]) {
        [webGroupViewController addBookmark:sender];
    } else
        NSBeep();
}

#pragma mark Add or remove items

- (NSArray *)mergeInPublications:(NSArray *)items{
    // first construct a set of current items to compare based on BibItem equality callbacks
    CFIndex countOfItems = [publications count];
    BibItem **pubs = (BibItem **)NSZoneMalloc([self zone], sizeof(BibItem *) * countOfItems);
    [publications getObjects:pubs];
    NSSet *currentPubs = (NSSet *)CFSetCreate(CFAllocatorGetDefault(), (const void **)pubs, countOfItems, &BDSKBibItemEquivalenceCallBacks);
    NSZoneFree([self zone], pubs);
    
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[items count]];
    NSEnumerator *pubEnum = [items objectEnumerator];
    BibItem *pub;
    
    while (pub = [pubEnum nextObject]) {
        if ([currentPubs containsObject:pub] == NO)
            [array addObject:pub];
    }
    
    if ([array count] == 0)
        return [NSArray array];
    
    // archive and unarchive mainly to get complex strings with the correct macroResolver
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    NSArray *newPubs;
    
    [archiver encodeObject:array forKey:@"publications"];
    [archiver finishEncoding];
    [archiver release];
    
    newPubs = [self newPublicationsFromArchivedData:data];
    
    [self selectLibraryGroup:nil];    
	[self addPublications:newPubs];
	[self selectPublications:newPubs];
    
    BOOL autoGenerate = [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKCiteKeyAutogenerateKey];
    NSMutableArray *generatePubs = [NSMutableArray arrayWithCapacity:[newPubs count]];
    
    pubEnum = [newPubs objectEnumerator];
    
    while (pub = [pubEnum nextObject]) {
        if ((autoGenerate == NO && [pub hasEmptyOrDefaultCiteKey]) ||
            (autoGenerate && [pub canGenerateAndSetCiteKey])) // @@ or should we check for hasEmptyOrDefaultCiteKey ?
            [generatePubs addObject:pub];
    }
    [self generateCiteKeysForPublications:generatePubs];
    
    [groups setLastImportedPublications:newPubs];
	
	[[self undoManager] setActionName:NSLocalizedString(@"Merge External Publications", @"Undo action name")];
    
    return newPubs;
}

- (BOOL)addPublications:(NSArray *)pubs toGroup:(BDSKGroup *)group{
	OBASSERT([group isSmart] == NO && [group isExternal] == NO && [group isEqual:[groups libraryGroup]] == NO && [group isEqual:[groups lastImportGroup]] == NO);
    
    if ([group isStatic]) {
        [(BDSKStaticGroup *)group addPublicationsFromArray:pubs];
		[[self undoManager] setActionName:NSLocalizedString(@"Add To Group", @"Undo action name")];
        return YES;
    }
    
    NSEnumerator *pubEnum = [pubs objectEnumerator];
    BibItem *pub;
    NSMutableArray *changedPubs = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSMutableArray *oldValues = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSMutableArray *newValues = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSString *oldValue = nil;
    NSString *field = [group isCategory] ? [(BDSKCategoryGroup *)group key] : nil;
    int count = 0;
    int handleInherited = BDSKOperationAsk;
	int rv;
    
    while(pub = [pubEnum nextObject]){
        OBASSERT([pub isKindOfClass:[BibItem class]]);        
        
        if(field && [field isEqualToString:BDSKPubTypeString] == NO)
            oldValue = [[[pub valueOfField:field] retain] autorelease];
		rv = [pub addToGroup:group handleInherited:handleInherited];
		
		if(rv == BDSKOperationSet || rv == BDSKOperationAppend){
            count++;
            if(field && [field isEqualToString:BDSKPubTypeString] == NO){
                [changedPubs addObject:pub];
                [oldValues addObject:oldValue ? oldValue : @""];
                [newValues addObject:[pub valueOfField:field]];
            }
		}else if(rv == BDSKOperationAsk){
			NSString *otherButton = nil;
			if([[self currentGroupField] isSingleValuedGroupField] == NO)
				otherButton = NSLocalizedString(@"Append", @"Button title");
			
			BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Inherited Value", @"Message in alert dialog when trying to edit inherited value")
												 defaultButton:NSLocalizedString(@"Don't Change", @"Button title")
											   alternateButton:NSLocalizedString(@"Set", @"Button title")
												   otherButton:otherButton
									 informativeTextWithFormat:NSLocalizedString(@"One or more items have a value that was inherited from an item linked to by the Crossref field. This operation would break the inheritance for this value. What do you want me to do with inherited values?", @"Informative text in alert dialog")];
			rv = [alert runSheetModalForWindow:documentWindow];
			handleInherited = rv;
			if(handleInherited != BDSKOperationIgnore){
                [pub addToGroup:group handleInherited:handleInherited];
                count++;
                if(field && [field isEqualToString:BDSKPubTypeString] == NO){
                    [changedPubs addObject:pub];
                    [oldValues addObject:oldValue ? oldValue : @""];
                    [newValues addObject:[pub valueOfField:field]];
                }
			}
		}
    }
	
	if(count > 0){
        if([changedPubs count])
            [self userChangedField:field ofPublications:changedPubs from:oldValues to:newValues];
		[[self undoManager] setActionName:NSLocalizedString(@"Add To Group", @"Undo action name")];
    }
    
    return YES;
}

- (BOOL)removePublications:(NSArray *)pubs fromGroups:(NSArray *)groupArray{
    NSEnumerator *groupEnum = [groupArray objectEnumerator];
	BDSKGroup *group;
	int count = 0;
	int handleInherited = BDSKOperationAsk;
	NSString *groupName = nil;
    
    while(group = [groupEnum nextObject]){
		if([group isSmart] == YES || [group isExternal] == YES || group == [groups libraryGroup] || group == [groups lastImportGroup])
			continue;
		
		if (groupName == nil)
			groupName = [NSString stringWithFormat:@"group %@", [group name]];
		else
			groupName = @"selected groups";
		
        if ([group isStatic]) {
            [(BDSKStaticGroup *)group removePublicationsInArray:pubs];
            [[self undoManager] setActionName:NSLocalizedString(@"Remove From Group", @"Undo action name")];
            count = [pubs count];
            continue;
        } else if ([group isCategory] && [[(BDSKCategoryGroup *)group key] isSingleValuedGroupField]) {
            continue;
        }
		
		NSEnumerator *pubEnum = [pubs objectEnumerator];
		BibItem *pub;
        NSMutableArray *changedPubs = [NSMutableArray arrayWithCapacity:[pubs count]];
        NSMutableArray *oldValues = [NSMutableArray arrayWithCapacity:[pubs count]];
        NSMutableArray *newValues = [NSMutableArray arrayWithCapacity:[pubs count]];
        NSString *oldValue = nil;
        NSString *field = [group isCategory] ? [(BDSKCategoryGroup *)group key] : nil;
		int rv;
        int tmpCount = 0;
		
        if([field isEqualToString:BDSKPubTypeString])
            continue;
        
		while(pub = [pubEnum nextObject]){
			OBASSERT([pub isKindOfClass:[BibItem class]]);        
			
            if(field)
                oldValue = [[[pub valueOfField:field] retain] autorelease];
			rv = [pub removeFromGroup:group handleInherited:handleInherited];
			
			if(rv == BDSKOperationSet || rv == BDSKOperationAppend){
				tmpCount++;
                if(field){
                    [changedPubs addObject:pub];
                    [oldValues addObject:oldValue ? oldValue : @""];
                    [newValues addObject:[pub valueOfField:field]];
                }
			}else if(rv == BDSKOperationAsk){
				BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Inherited Value", @"Message in alert dialog when trying to edit inherited value")
													 defaultButton:NSLocalizedString(@"Don't Change", @"Button title")
												   alternateButton:nil
													   otherButton:NSLocalizedString(@"Remove", @"Button title")
										 informativeTextWithFormat:NSLocalizedString(@"One or more items have a value that was inherited from an item linked to by the Crossref field. This operation would break the inheritance for this value. What do you want me to do with inherited values?", @"Informative text in alert dialog")];
				rv = [alert runSheetModalForWindow:documentWindow];
				handleInherited = rv;
				if(handleInherited != BDSKOperationIgnore){
					[pub removeFromGroup:group handleInherited:handleInherited];
                    tmpCount++;
                    if(field){
                        [changedPubs addObject:pub];
                        [oldValues addObject:oldValue ? oldValue : @""];
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
		[self setStatus:[NSString stringWithFormat:NSLocalizedString(@"Removed %i %@ from %@", @"Status message: Removed [number] publications(s) from selected group(s)"), count, pubSingularPlural, groupName] immediate:NO];
	}
    
    return YES;
}

- (BOOL)movePublications:(NSArray *)pubs fromGroup:(BDSKGroup *)group toGroupNamed:(NSString *)newGroupName{
	int count = 0;
	int handleInherited = BDSKOperationAsk;
	NSEnumerator *pubEnum = [pubs objectEnumerator];
	BibItem *pub;
	int rv;
	
	if([group isCategory] == NO)
		return NO;
    
    NSMutableArray *changedPubs = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSMutableArray *oldValues = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSMutableArray *newValues = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSString *oldValue = nil;
    NSString *field = [(BDSKCategoryGroup *)group key];
	
	while(pub = [pubEnum nextObject]){
		OBASSERT([pub isKindOfClass:[BibItem class]]);        
		
        oldValue = [[[pub valueOfField:field] retain] autorelease];
		rv = [pub replaceGroup:group withGroupNamed:newGroupName handleInherited:handleInherited];
		
		if(rv == BDSKOperationSet || rv == BDSKOperationAppend){
			count++;
            [changedPubs addObject:pub];
            [oldValues addObject:oldValue ? oldValue : @""];
            [newValues addObject:[pub valueOfField:field]];
        }else if(rv == BDSKOperationAsk){
			BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Inherited Value", @"Message in alert dialog when trying to edit inherited value")
												 defaultButton:NSLocalizedString(@"Don't Change", @"Button title")
											   alternateButton:nil
												   otherButton:NSLocalizedString(@"Remove", @"Button title")
									 informativeTextWithFormat:NSLocalizedString(@"One or more items have a value that was inherited from an item linked to by the Crossref field. This operation would break the inheritance for this value. What do you want me to do with inherited values?", @"Informative text in alert dialog")];
			rv = [alert runSheetModalForWindow:documentWindow];
			handleInherited = rv;
			if(handleInherited != BDSKOperationIgnore){
				[pub replaceGroup:group withGroupNamed:newGroupName handleInherited:handleInherited];
                count++;
                [changedPubs addObject:pub];
                [oldValues addObject:oldValue ? oldValue : @""];
                [newValues addObject:[pub valueOfField:field]];
			}
        }
	}
	
	if(count > 0){
        if([changedPubs count])
            [self userChangedField:field ofPublications:changedPubs from:oldValues to:newValues];
        [[self undoManager] setActionName:NSLocalizedString(@"Rename Group", @"Undo action name")];
    }
    
    return YES;
}

#pragma mark Sorting

- (void)sortGroupsByKey:(NSString *)key{
    if (key == nil) {
        // clicked the sort arrow in the table header, change sort order
        docState.sortGroupsDescending = !docState.sortGroupsDescending;
    } else if ([key isEqualToString:sortGroupsKey]) {
		// same key, resort
    } else {
        // change key
        // save new sorting selector, and re-sort the array.
        if ([key isEqualToString:BDSKGroupCellStringKey])
			docState.sortGroupsDescending = NO;
		else
			docState.sortGroupsDescending = YES; // more appropriate for default count sort
		[sortGroupsKey release];
        sortGroupsKey = [key retain];
	}
    
    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    [groupTableView setDelegate:nil];
	
    // cache the selection
	NSArray *selectedGroups = [self selectedGroups];
    
	NSSortDescriptor *countSort = [[NSSortDescriptor alloc] initWithKey:@"numberValue" ascending:!docState.sortGroupsDescending  selector:@selector(compare:)];
    [countSort autorelease];

    // could use "name" as key path, but then we'd still have to deal with names that are not NSStrings
    NSSortDescriptor *nameSort = [[NSSortDescriptor alloc] initWithKey:@"self" ascending:!docState.sortGroupsDescending  selector:@selector(nameCompare:)];
    [nameSort autorelease];

    NSArray *sortDescriptors;
    
    if([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]){
        if(docState.sortGroupsDescending)
            // doc bug: this is supposed to return a copy of the receiver, but sending -release results in a zombie error
            nameSort = [nameSort reversedSortDescriptor];
        sortDescriptors = [NSArray arrayWithObjects:countSort, nameSort, nil];
    } else {
        if(docState.sortGroupsDescending == NO)
            countSort = [countSort reversedSortDescriptor];
        sortDescriptors = [NSArray arrayWithObjects:nameSort, countSort, nil];
    }
    
    [groups sortUsingDescriptors:sortDescriptors];
    
    // Set the graphic for the new column header
	BDSKHeaderPopUpButtonCell *headerPopup = (BDSKHeaderPopUpButtonCell *)[groupTableView popUpHeaderCell];
	[headerPopup setIndicatorImage:[NSImage imageNamed:docState.sortGroupsDescending ? @"NSDescendingSortIndicator" : @"NSAscendingSortIndicator"]];

    [groupTableView reloadData];
	
	// select the current groups. Otherwise select Library
	[self selectGroups:selectedGroups];
	[self displaySelectedGroups];
	
    // reset ourself as delegate
    [groupTableView setDelegate:self];
}

#pragma mark Importing

- (void)setImported:(BOOL)flag forPublications:(NSArray *)pubs inGroup:(BDSKGroup *)aGroup{
    CFIndex countOfItems = [pubs count];
    BibItem **items = (BibItem **)NSZoneMalloc([self zone], sizeof(BibItem *) * countOfItems);
    [pubs getObjects:items];
    NSSet *pubSet = (NSSet *)CFSetCreate(CFAllocatorGetDefault(), (const void **)items, countOfItems, &BDSKBibItemEquivalenceCallBacks);
    NSZoneFree([self zone], items);
    
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    
    if (aGroup) {
        [indexes addIndex:[groups indexOfObjectIdenticalTo:aGroup]];
    } else {
        if ([groups webGroup])
            [indexes addIndex:1];
        [indexes addIndexesInRange:[groups rangeOfSharedGroups]];
        [indexes addIndexesInRange:[groups rangeOfURLGroups]];
        [indexes addIndexesInRange:[groups rangeOfScriptGroups]];
        [indexes addIndexesInRange:[groups rangeOfSearchGroups]];
    }
    
    unsigned idx = [indexes firstIndex];
    
    while (idx != NSNotFound) {
        id group = [groups objectAtIndex:idx];
        idx = [indexes indexGreaterThanIndex:idx];
        if ([group count] == 0) continue; // otherwise the group will load
        NSEnumerator *pubEnum = [[group publications] objectEnumerator];
        BibItem *pub;
        while (pub = [pubEnum nextObject]) {
            if ([pubSet containsObject:pub])
                [pub setImported:flag];
        }
    }
    [pubSet release];
	
    NSTableColumn *tc = [tableView tableColumnWithIdentifier:BDSKImportOrderString];
    if(tc && [self hasExternalGroupsSelected])
        [tableView setNeedsDisplayInRect:[tableView rectOfColumn:[[tableView tableColumns] indexOfObject:tc]]];
}

- (void)tableView:(NSTableView *)aTableView importItemAtRow:(int)rowIndex{
    BibItem *pub = [shownPublications objectAtIndex:rowIndex];
    
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    NSArray *newPubs;
    NSMutableArray *importedItems = [NSMutableArray array];
    
    [archiver encodeObject:[NSArray arrayWithObjects:pub, nil] forKey:@"publications"];
    [archiver finishEncoding];
    [archiver release];
    
    newPubs = [self newPublicationsFromArchivedData:data];
    
	[self addPublications:newPubs];
    
    if (docState.didImport)
        [importedItems addObjectsFromArray:[[groups lastImportGroup] publications]];
    else
        docState.didImport = YES;
    [importedItems addObjectsFromArray:newPubs];
    [groups setLastImportedPublications:importedItems];
    
    BOOL autoGenerate = [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKCiteKeyAutogenerateKey];
    NSMutableArray *generatePubs = [NSMutableArray arrayWithCapacity:[newPubs count]];
    NSEnumerator *pubEnum = [newPubs objectEnumerator];
    
    while (pub = [pubEnum nextObject]) {
        if ((autoGenerate == NO && [pub hasEmptyOrDefaultCiteKey]) ||
            (autoGenerate && [pub canGenerateAndSetCiteKey])) // @@ or should we check for hasEmptyOrDefaultCiteKey ?
            [generatePubs addObject:pub];
    }
    [self generateCiteKeysForPublications:generatePubs];
    
    [groups setLastImportedPublications:newPubs];
    
	[[self undoManager] setActionName:NSLocalizedString(@"Import Publication", @"Undo action name")];
}

@end

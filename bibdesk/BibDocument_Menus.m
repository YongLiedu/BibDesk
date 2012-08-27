//
//  BibDocument_Menus.m
//  BibDesk
//
//  Created by Sven-S. Porst on Fri Jul 30 2004.
/*
 This software is Copyright (c) 2004-2012
 Sven-S. Porst. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Sven-S. Porst nor the names of any
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

#import "BibDocument_Menus.h"
#import "BDSKGroupCell.h"
#import "BDSKGroup.h"
#import "BDSKWebGroup.h"
#import "BibDocument_Groups.h"
#import "BibDocument_UI.h"
#import "BDSKMainTableView.h"
#import "BDSKGroupOutlineView.h"
#import "BibItem.h"
#import "BDSKTypeManager.h"
#import "BDSKTemplate.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BibDocument_Actions.h"
#import "BibDocument_Search.h"
#import "BDSKGroupsArray.h"
#import "BDSKCustomCiteDrawerController.h"
#import "BDSKPreviewer.h"
#import <objc/runtime.h>

@implementation BibDocument (Menus)

- (BOOL) validateCutMenuItem:(NSMenuItem*) menuItem {
    if ([documentWindow isKeyWindow] == NO)
        return NO;
	id firstResponder = [documentWindow firstResponder];
	if (firstResponder != tableView ||
		[self numberOfSelectedPubs] == 0 ||
        [self hasExternalGroupsSelected]) {
		// no selection or selection includes shared groups
		return NO;
	}
	else {
		// multiple selection
		return YES;
	}
}	

- (BOOL) validateCopyMenuItem:(NSMenuItem*) menuItem {
    if ([documentWindow isKeyWindow] == NO)
        return NO;
	id firstResponder = [documentWindow firstResponder];
	if (firstResponder != tableView ||
		[self numberOfSelectedPubs] == 0) {
		// no selection
		return NO;
	}
	else {
		// multiple selection
		return YES;
	}
}	

- (BOOL) validateCopyAsActionMenuItem:(NSMenuItem*) menuItem {
    if ([documentWindow isKeyWindow] == NO)
        return NO;
    BOOL usesTeX = [[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey];
	NSInteger copyType = [menuItem tag];
    
    if (usesTeX == NO && (copyType == BDSKPDFDragCopyType || copyType == BDSKRTFDragCopyType || copyType == BDSKLaTeXDragCopyType || copyType == BDSKLTBDragCopyType))
        return NO;
    else
        return [self numberOfClickedOrSelectedPubs] > 0;
}

- (BOOL)validatePasteMenuItem:(NSMenuItem *)menuItem{
	return ([documentWindow isKeyWindow] && [[documentWindow firstResponder] isEqual:tableView]);
}

- (BOOL)validateDuplicateMenuItem:(NSMenuItem *)menuItem{
    if ([documentWindow isKeyWindow] == NO)
        return NO;
	if ([[documentWindow firstResponder] isEqual:tableView] == NO ||
		[self numberOfSelectedPubs] == 0 ||
        [self hasExternalGroupsSelected])
		return NO;
	return YES;
}

- (BOOL) validateEditPubCmdMenuItem:(NSMenuItem*) menuItem {
    return [self numberOfClickedOrSelectedPubs] > 0;
}

- (BOOL) validateDeleteSelectedPubsMenuItem:(NSMenuItem*) menuItem {
    return ([self numberOfClickedOrSelectedPubs] > 0 && [self hasExternalGroupsSelected] == NO);
}	
		
- (BOOL) validateRemoveSelectedPubsMenuItem:(NSMenuItem*) menuItem {
    if ([self numberOfClickedOrSelectedPubs] == 0 && [self hasExternalGroupsSelected])
        return NO;
    if([self hasLibraryGroupSelected])
        return [self validateDeleteSelectedPubsMenuItem:menuItem];
    if ([self hasStaticGroupsSelected])
        return YES;
    // don't remove from single valued group field, as that will clear the field, which is most probably a mistake. See bug # 1435344
    if ([[self currentGroupField] isSingleValuedGroupField] == NO && [self hasCategoryGroupsSelected])
        return YES;
    return NO;
}	

- (BOOL)validateSendToLyXMenuItem:(NSMenuItem*) menuItem {
    if ([self numberOfClickedOrSelectedPubs] == 0)
        return NO;
    
    if ([[NSFileManager defaultManager] latestLyXPipePath])
        return YES;
        
    return NO;
}

- (BOOL) validateOpenLocalURLMenuItem:(NSMenuItem*) menuItem {
	NSString *field = [menuItem representedObject] ?: BDSKLocalUrlString;
    for (BibItem *pub in [self clickedOrSelectedPublications]) {
        NSString *path = [[pub localFileURLForField:field] path];
        if (path && [[NSFileManager defaultManager] fileExistsAtPath:path])
            return YES;
    }
    return NO;
}	

- (BOOL) validateRevealLocalURLMenuItem:(NSMenuItem*) menuItem {
	NSString *field = [menuItem representedObject] ?: BDSKLocalUrlString;
    for (BibItem *pub in [self clickedOrSelectedPublications]) {
        NSString *path = [[pub localFileURLForField:field] path];
        if (path && [[NSFileManager defaultManager] fileExistsAtPath:path])
            return YES;
    }
    return NO;
}	

- (BOOL) validateOpenRemoteURLMenuItem:(NSMenuItem*) menuItem {
	NSString *field = [menuItem representedObject] ?: BDSKUrlString;
    for (BibItem *pub in [self clickedOrSelectedPublications]) {
        NSURL *url = [pub remoteURLForField:field];
        if (url)
            return YES;
    }
    return NO;
}	

- (BOOL) validateShowNotesForLocalURLMenuItem:(NSMenuItem*) menuItem {
	NSString *field = [menuItem representedObject] ?: BDSKLocalUrlString;
    for (BibItem *pub in [self clickedOrSelectedPublications]) {
        NSString *path = [[pub localFileURLForField:field] path];
        if (path && [[NSFileManager defaultManager] fileExistsAtPath:path])
            return YES;
    }
    return NO;
}	

- (BOOL) validateCopyNotesForLocalURLMenuItem:(NSMenuItem*) menuItem {
	NSString *field = [menuItem representedObject] ?: BDSKLocalUrlString;
    for (BibItem *pub in [self clickedOrSelectedPublications]) {
        NSString *path = [[pub localFileURLForField:field] path];
        if (path && [[NSFileManager defaultManager] fileExistsAtPath:path])
            return YES;
    }
    return NO;
}	

- (BOOL) validateOpenLinkedFileMenuItem:(NSMenuItem*) menuItem {
    return ([menuItem representedObject] != nil || [[self clickedOrSelectedFileURLs] count] > 0);
}	

- (BOOL) validateRevealLinkedFileMenuItem:(NSMenuItem*) menuItem {
    return ([menuItem representedObject] != nil || [[self clickedOrSelectedFileURLs] count] > 0);
}	

- (BOOL) validateOpenLinkedURLMenuItem:(NSMenuItem*) menuItem {
    return [menuItem representedObject] != nil || [[[self clickedOrSelectedPublications] valueForKeyPath:@"@unionOfArrays.remoteURLs"] count] > 0;
}	

- (BOOL) validateShowNotesForLinkedFileMenuItem:(NSMenuItem*) menuItem {
    return ([menuItem representedObject] != nil || [[self clickedOrSelectedFileURLs] count] > 0);
}	

- (BOOL) validateCopyNotesForLinkedFileMenuItem:(NSMenuItem*) menuItem {
    return ([menuItem representedObject] != nil || [[self clickedOrSelectedFileURLs] count] > 0);
}	

- (BOOL) validatePreviewActionMenuItem:(NSMenuItem*) menuItem {
    return ([[menuItem representedObject] count] ||
            [[self clickedOrSelectedFileURLs] count] ||
            [[[self clickedOrSelectedPublications] valueForKeyPath:@"@unionOfArrays.remoteURLs"] count]);
}	

- (BOOL) validateDuplicateTitleToBooktitleMenuItem:(NSMenuItem*) menuItem {
	return ([self numberOfSelectedPubs] > 0 && [self hasExternalGroupsSelected] == NO);
}

- (BOOL) validateGenerateCiteKeyMenuItem:(NSMenuItem*) menuItem {
	return ([self numberOfSelectedPubs] > 0 && [self hasExternalGroupsSelected] == NO);
}	

- (BOOL) validateConsolidateLinkedFilesMenuItem:(NSMenuItem*) menuItem {
	return ([self numberOfSelectedPubs] > 0 && [self hasExternalGroupsSelected] == NO);
}	

- (BOOL) validateToggleShowingCustomCiteDrawerMenuItem:(NSMenuItem*) menuItem {
    [menuItem setTitle:[drawerController isDrawerOpen] ? NSLocalizedString(@"Hide Custom \\cite Commands", @"Menu item title") : NSLocalizedString(@"Show Custom \\cite Commands", @"Menu item title")];
	return YES;
}

- (BOOL) validateToggleGroupsMenuItem:(NSMenuItem*) menuItem {
	if ([groupSplitView isSubviewCollapsed:[[groupSplitView subviews] objectAtIndex:0]])
		[menuItem setTitle:NSLocalizedString(@"Show Groups", @"Menu item title")];
	else
		[menuItem setTitle:NSLocalizedString(@"Hide Groups", @"Menu item title")];
	return YES;
}

- (BOOL) validateToggleSidebarMenuItem:(NSMenuItem*) menuItem {
	if ([groupSplitView isSubviewCollapsed:[[groupSplitView subviews] objectAtIndex:2]])
		[menuItem setTitle:NSLocalizedString(@"Show Sidebar", @"Menu item title")];
	else
		[menuItem setTitle:NSLocalizedString(@"Hide Sidebar", @"Menu item title")];
	return YES;
}

- (BOOL) validateToggleStatusBarMenuItem:(NSMenuItem*) menuItem {
    [menuItem setTitle:[statusBar isVisible] ? NSLocalizedString(@"Hide Status Bar", @"Menu item title") : NSLocalizedString(@"Show Status Bar", @"Menu item title")];
	return YES;
}

- (BOOL) validateImportFromPasteboardActionMenuItem:(NSMenuItem*) menuItem {
    [menuItem setTitle:[NSLocalizedString(@"New Publications from Clipboard", @"Menu item title") stringByAppendingEllipsis]];
	return YES;
}

- (BOOL) validateImportFromFileActionMenuItem:(NSMenuItem*) menuItem {
	[menuItem setTitle:[NSLocalizedString(@"New Publications from File", @"Menu item title") stringByAppendingEllipsis]];
	return YES;
}

- (BOOL) validateImportFromWebActionMenuItem:(NSMenuItem*) menuItem {
	[menuItem setTitle:[NSLocalizedString(@"New Publications from Web", @"Menu item title") stringByAppendingEllipsis]];
	return YES;
}

- (BOOL)validateSortForCrossrefsMenuItem:(NSMenuItem *)menuItem{
    return ([self hasExternalGroupsSelected] == NO);
}

- (BOOL)validateSelectCrossrefParentActionMenuItem:(NSMenuItem *)menuItem{
    if([self isDisplayingFileContentSearch] == NO && [self numberOfClickedOrSelectedPubs] == 1){
        BibItem *selectedBI = [[self clickedOrSelectedPublications] objectAtIndex:0];
        if(![NSString isEmptyString:[selectedBI valueOfField:BDSKCrossrefString inherit:NO]])
            return YES;
    }
	return NO;
}

- (BOOL)validateSelectCrossrefsMenuItem:(NSMenuItem *)menuItem{
    if([self isDisplayingFileContentSearch] == NO && [self numberOfClickedOrSelectedPubs] > 0)
        return YES;
	return NO;
}

- (BOOL)validateCreateNewPubUsingCrossrefMenuItem:(NSMenuItem *)menuItem{
    if([self numberOfClickedOrSelectedPubs] == 1 && [self hasExternalGroupsSelected] == NO){
        BibItem *selectedBI = [[self clickedOrSelectedPublications] objectAtIndex:0];
        
        // only valid if the selected pub (parent-to-be) doesn't have a crossref field
        if([NSString isEmptyString:[selectedBI valueOfField:BDSKCrossrefString inherit:NO]])
            return YES;
    }
	return NO;
}

- (BOOL) validateSortGroupsByGroupMenuItem:(NSMenuItem *)menuItem{
	if([sortGroupsKey isEqualToString:BDSKGroupCellStringKey]){
		[menuItem setState:NSOnState];
        [menuItem setImage:[NSImage imageNamed:docFlags.sortGroupsDescending ? @"NSDescendingSortIndicator" : @"NSAscendingSortIndicator"]];
	}else{
		[menuItem setState:NSOffState];
        [menuItem setImage:nil];
	}
	return YES;
} 

- (BOOL) validateSortGroupsByCountMenuItem:(NSMenuItem *)menuItem{
	if([sortGroupsKey isEqualToString:BDSKGroupCellCountKey]){
		[menuItem setState:NSOnState];
        [menuItem setImage:[NSImage imageNamed:docFlags.sortGroupsDescending ? @"NSDescendingSortIndicator" : @"NSAscendingSortIndicator"]];
	}else{
		[menuItem setState:NSOffState];
        [menuItem setImage:nil];
	}
	return YES;
} 

- (BOOL) validateChangeGroupFieldActionMenuItem:(NSMenuItem *)menuItem{
	if([([menuItem representedObject] ?: @"") isEqualToString:[self currentGroupField]])
		[menuItem setState:NSOnState];
	else
		[menuItem setState:NSOffState];
	return YES;
} 

- (BOOL) validateRemoveSelectedGroupsMenuItem:(NSMenuItem *)menuItem{
    return [self hasSmartGroupsClickedOrSelected] ||
           [self hasStaticGroupsClickedOrSelected] ||
           [self hasURLGroupsClickedOrSelected] ||
           [self hasScriptGroupsClickedOrSelected] ||
           [self hasSearchGroupsClickedOrSelected] ||
           [self hasWebGroupsClickedOrSelected];
} 

- (BOOL) validateRenameGroupActionMenuItem:(NSMenuItem *)menuItem{
	NSInteger row = [groupOutlineView clickedRow];
    if (row == -1 && [groupOutlineView numberOfSelectedRows] == 1)
        row = [groupOutlineView selectedRow];
	if (row > 0) {
		// single group selection
		return [[groupOutlineView itemAtRow:row] isNameEditable];
	} else {
		// multiple selection or no group selected
		return NO;
	}
} 

- (BOOL) validateCopyGroupURLActionMenuItem:(NSMenuItem *)menuItem{
	if ([self hasSearchGroupsClickedOrSelected] || [self hasURLGroupsClickedOrSelected] || [self hasScriptGroupsClickedOrSelected] || [self hasWebGroupsClickedOrSelected]) {
		return YES;
	} else {
		return NO;
	}
} 

- (BOOL) validateRemoveGroupFieldActionMenuItem:(NSMenuItem *)menuItem{
    // don't allow the removal of the last item
    return ([[menuItem menu] numberOfItems] > 4);
}

- (BOOL) validateEditGroupActionMenuItem:(NSMenuItem *)menuItem{
    if ([documentWindow isKeyWindow] == NO)
        return NO;
	NSInteger row = [groupOutlineView clickedRow];
    if (row == -1 && [groupOutlineView numberOfSelectedRows] == 1)
        row = [groupOutlineView selectedRow];
	if (row > 0) {
		// single group selection
        return [[groupOutlineView itemAtRow:row] isEditable];
	} else {
		// multiple selection or no smart group selected
		return NO;
	}
} 

- (BOOL) validateEditActionMenuItem:(NSMenuItem *)menuItem{
    if ([documentWindow isKeyWindow] == NO) {
        return NO;
	} else if ([documentWindow firstResponder] == groupOutlineView) {
		return [self validateEditGroupActionMenuItem:menuItem];
    } else {
		return [self validateEditPubCmdMenuItem:menuItem];
	}
} 

- (BOOL) validateDeleteMenuItem:(NSMenuItem*) menuItem {
    if ([documentWindow isKeyWindow] == NO)
        return NO;
    id firstResponder = [documentWindow firstResponder];
	if (firstResponder == tableView || tableView == [fileSearchController tableView]) {
		return [self validateRemoveSelectedPubsMenuItem:menuItem];
	} else if (firstResponder == groupOutlineView) {
		return [self validateRemoveSelectedGroupsMenuItem:menuItem];
	} else {
		return NO;
	}
}

- (BOOL)validateSelectAllPublicationsMenuItem:(NSMenuItem *)menuItem{
    return ([documentWindow isKeyWindow]);
}

- (BOOL)validateDeselectAllPublicationsMenuItem:(NSMenuItem *)menuItem{
    return ([documentWindow isKeyWindow]);
}

- (BOOL)validateSelectLibraryGroupMenuItem:(NSMenuItem *)menuItem{
    return ([documentWindow isKeyWindow]);
}

- (BOOL) validateSelectDuplicatesMenuItem:(NSMenuItem *)menuItem{
    return YES;
}

- (BOOL) validateSelectPossibleDuplicatesMenuItem:(NSMenuItem *)menuItem{
    [menuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Select Duplicates by %@", @"Menu item title"), [sortKey localizedFieldName]]];
    return ([self hasExternalGroupsSelected] == NO);
}

- (BOOL) validateSelectIncompletePublicationsMenuItem:(NSMenuItem *)menuItem{
    return ([self hasExternalGroupsSelected] == NO);
}

- (BOOL)validateEditNewStaticGroupWithSelectionMenuItem:(NSMenuItem *)menuItem {
    [menuItem setTitle:[self hasExternalGroupsSelected] ? NSLocalizedString(@"New Static Group With Merged Selection", @"Menu item title") : NSLocalizedString(@"New Static Group With Selection", @"Menu item title")];
    return ([self numberOfSelectedPubs] > 0);
}

- (BOOL)validateEditNewCategoryGroupWithSelectionMenuItem:(NSMenuItem *)menuItem {
    [menuItem setTitle:[self hasExternalGroupsSelected] ? NSLocalizedString(@"New Field Group With Merged Selection", @"Menu item title") : NSLocalizedString(@"New Field Group With Selection", @"Menu item title")];
    return ([self numberOfSelectedPubs] > 0 && [currentGroupField isEqualToString:@""] == NO);
}

- (BOOL)validateAddSearchBookmarkMenuItem:(NSMenuItem *)menuItem {
    return [self hasSearchGroupsSelected];
}

- (BOOL)validateRevertDocumentToSavedMenuItem:(NSMenuItem *)menuItem {
    return [self isDocumentEdited] && [self fileURL] != nil;
}

- (BOOL)validateChangePreviewDisplayMenuItem:(NSMenuItem *)menuItem {
    NSInteger tag = [menuItem tag], state = NSOffState;
    NSString *style = [menuItem representedObject];
    if (tag == bottomPreviewDisplay && tag != BDSKPreviewDisplayText) {
        state = NSOnState;
    } else if (tag == BDSKPreviewDisplayText && [style isEqualToString:bottomPreviewDisplayTemplate]) {
        if (tag == bottomPreviewDisplay || [menuItem menu] == bottomTemplatePreviewMenu)
            state = NSOnState;
    }
    [menuItem setState:state];
    return tag != BDSKPreviewDisplayTeX || [[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey];
}

- (BOOL)validateChangeSidePreviewDisplayMenuItem:(NSMenuItem *)menuItem {
    NSInteger tag = [menuItem tag], state = NSOffState;
    NSString *style = [menuItem representedObject];
    if (tag == sidePreviewDisplay && tag != BDSKPreviewDisplayText) {
        state = NSOnState;
    } else if (tag == BDSKPreviewDisplayText && [style isEqualToString:sidePreviewDisplayTemplate]) {
        if (tag == sidePreviewDisplay || [menuItem menu] == sideTemplatePreviewMenu)
            state = NSOnState;
    }
    [menuItem setState:state];
    return tag != BDSKPreviewDisplayTeX || [[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey];
}

- (BOOL)validateChangeIntersectGroupsActionMenuItem:(NSMenuItem *)menuItem {
    [menuItem setState: ((BOOL)[menuItem tag] == [[NSUserDefaults standardUserDefaults] integerForKey:BDSKIntersectGroupsKey]) ? NSOnState : NSOffState];
    return YES;
}

- (BOOL)validateMergeInExternalGroupMenuItem:(NSMenuItem *)menuItem {
    if ([self hasSharedGroupsClickedOrSelected]) {
        [menuItem setTitle:NSLocalizedString(@"Merge In Shared Group", @"Menu item title")];
        return YES;
    } else if ([self hasURLGroupsClickedOrSelected]) {
        [menuItem setTitle:NSLocalizedString(@"Merge In External File Group", @"Menu item title")];
        return YES;
    } else if ([self hasScriptGroupsClickedOrSelected]) {
        [menuItem setTitle:NSLocalizedString(@"Merge In Script Group", @"Menu item title")];
        return YES;
    } else if ([self hasSearchGroupsClickedOrSelected]) {
        [menuItem setTitle:NSLocalizedString(@"Merge In Search Group", @"Menu item title")];
        return YES;
    } else if ([self hasWebGroupsClickedOrSelected]) {
        [menuItem setTitle:NSLocalizedString(@"Merge In Web Group", @"Menu item title")];
        return YES;
    } else {
        [menuItem setTitle:NSLocalizedString(@"Merge In Shared Group", @"Menu item title")];
        return NO;
    }
}

- (BOOL)validateMergeInExternalPublicationsMenuItem:(NSMenuItem *)menuItem {
    if ([self hasSharedGroupsSelected]) {
        [menuItem setTitle:NSLocalizedString(@"Merge In Shared Publications", @"Menu item title")];
        return [self numberOfClickedOrSelectedPubs] > 0;
    } else if ([self hasURLGroupsSelected] || [self hasScriptGroupsSelected] || [self hasSearchGroupsSelected] || [self hasWebGroupsSelected]) {
        [menuItem setTitle:NSLocalizedString(@"Merge In External Publications", @"Menu item title")];
        return [self numberOfClickedOrSelectedPubs] > 0;
    } else {
        [menuItem setTitle:NSLocalizedString(@"Merge In External Publications", @"Menu item title")];
        return NO;
    }
}

- (BOOL)validateRefreshSharingMenuItem:(NSMenuItem *)menuItem {
    return [[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldShareFilesKey];
}

- (BOOL)validateRefreshSharedBrowsingMenuItem:(NSMenuItem *)menuItem {
    return [[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldLookForSharedFilesKey];
}

- (BOOL)validateRefreshSelectedGroupsMenuItem:(NSMenuItem *)menuItem {
    if([self hasSharedGroupsClickedOrSelected]){
        [menuItem setTitle:NSLocalizedString(@"Refresh Shared Group", @"Menu item title")];
        return YES;
    }else if([self hasURLGroupsClickedOrSelected]){
        [menuItem setTitle:NSLocalizedString(@"Refresh External File Group", @"Menu item title")];
        return YES;
    }else if([self hasScriptGroupsClickedOrSelected]){
        [menuItem setTitle:NSLocalizedString(@"Refresh Script Group", @"Menu item title")];
        return YES;
    }else if([self hasSearchGroupsClickedOrSelected]){
        [menuItem setTitle:NSLocalizedString(@"Refresh Search Group", @"Menu item title")];
        return YES;
    }else if([self hasWebGroupsClickedOrSelected]){
        [menuItem setTitle:NSLocalizedString(@"Refresh Web Group", @"Menu item title")];
        return [[[self clickedOrSelectedGroups] lastObject] isWebViewLoaded];
    } else {
        [menuItem setTitle:NSLocalizedString(@"Refresh External Group", @"Menu item title")];
        return NO;
    }
}

- (BOOL)validateRefreshAllExternalGroupsMenuItem:(NSMenuItem *)menuItem {
    return [[groups URLGroups] count] > 0 ||
           [[groups scriptGroups] count] > 0 ||
           [[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldShareFilesKey];
}

- (BOOL)validateChangeSearchTypeMenuItem:(NSMenuItem *)menuItem {
    if ([[NSUserDefaults standardUserDefaults] integerForKey:BDSKSearchMenuTagKey] == [menuItem tag])
        [menuItem setState:NSOnState];
    else
        [menuItem setState:NSOffState];
    return YES;
}

- (BOOL)validateOpenBookmarkMenuItem:(NSMenuItem *)menuItem {
    return YES;
}

- (BOOL)validateAddBookmarkMenuItem:(NSMenuItem *)menuItem {
    return [self hasWebGroupsSelected];
}

- (BOOL)validateEmailPubCmdMenuItem:(NSMenuItem *)menuItem {
    return ([self numberOfClickedOrSelectedPubs] != 0);
}

static SEL validateMenuItemSelector(SEL sel) {
    static NSMapTable *table = NULL;
    if (sel == NULL)
        return NULL;
    // selectors are unique global "constants" so don't need to be retained and can be compared using pointer equivalence
    if (table == NULL)
        table = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks, NSNonOwnedPointerMapValueCallBacks, 0);
    SEL validateSel = NSMapGet(table, sel);
    if (validateSel == NULL) {
        const char *name = sel_getName(sel);
        int length = strlen(name);
        char buffer[17 + length];
        strcpy(buffer, "validate");
        buffer[8] = toupper(name[0]);
        strcpy(buffer + 9, name + 1);
        strcpy(buffer + 7 + length, "MenuItem:");
        buffer[length + 16] = '\0';
        validateSel = sel_getUid(buffer);
        NSMapInsert(table, sel, validateSel);
    }
    return validateSel;
}

// This methods looks for a method named -validate<Action>MenuItem: formed from the capitalized menuItem action

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem {
    SEL validateSelector = validateMenuItemSelector([menuItem action]);
    if ([self respondsToSelector:validateSelector])
        return ((BOOL(*)(id, SEL, id))[self methodForSelector:validateSelector])(self, validateSelector, menuItem);
    else
        return [super validateMenuItem:menuItem];
}

@end

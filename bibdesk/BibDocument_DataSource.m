//  BibDocument_DataSource.m

//  Created by Michael McCracken on Tue Mar 26 2002.
/*
 This software is Copyright (c) 2002-2009
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

#import "BibDocument_DataSource.h"
#import <SkimNotes/SkimNotes.h>
#import "BibDocument.h"
#import "BibDocument_Actions.h"
#import "BibItem.h"
#import "BibAuthor.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKGroupCell.h"
#import "BDSKGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKWebGroup.h"
#import "BDSKWebGroupViewController.h"
#import "BDSKScriptHookManager.h"
#import "BibDocument_Groups.h"
#import "BibDocument_Search.h"
#import "NSBezierPath_BDSKExtensions.h"
#import "BDSKPreviewer.h"
#import "BDSKTeXTask.h"
#import "BDSKMainTableView.h"
#import "BDSKGroupTableView.h"
#import "BDSKAlert.h"
#import "BDSKTypeManager.h"
#import "NSURL_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSSet_BDSKExtensions.h"
#import "BDSKEditor.h"
#import "NSGeometry_BDSKExtensions.h"
#import "BDSKTemplate.h"
#import "BDSKTemplateObjectProxy.h"
#import "BDSKTypeSelectHelper.h"
#import "NSWindowController_BDSKExtensions.h"
#import "NSTableView_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKStringParser.h"
#import "BDSKGroupsArray.h"
#import "BDSKItemPasteboardHelper.h"
#import "NSMenu_BDSKExtensions.h"
#import "NSIndexSet_BDSKExtensions.h"
#import "BDSKCategoryGroup.h"
#import "BDSKSearchGroup.h"
#import "BDSKURLGroup.h"
#import "BDSKLinkedFile.h"
#import "NSArray_BDSKExtensions.h"
#import "NSWorkspace_BDSKExtensions.h"
#import <FileView/FileView.h>
#import "BDSKApplication.h"
#import "BDSKAppController.h"

#define MAX_DRAG_IMAGE_WIDTH 700.0

@interface NSPasteboard (BDSKExtensions)
- (BOOL)containsUnparseableFile;
@end

#pragma mark -

@implementation BibDocument (DataSource)

#pragma mark TableView data source

- (int)numberOfRowsInTableView:(NSTableView *)tv{
    if(tv == (NSTableView *)tableView){
        return [shownPublications count];
    }else if(tv == groupTableView){
        return [groups count];
    }else{
// should raise an exception or something
        return 0;
    }
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    if(tv == tableView){
        return [[shownPublications objectAtIndex:row] displayValueOfField:[tableColumn identifier]];
    }else if(tv == groupTableView){
		return [[groups objectAtIndex:row] cellValue];
    }else return nil;
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    if(tv == tableView){

		NSString *tcID = [tableColumn identifier];
		if([tcID isRatingField]){
			BibItem *pub = [shownPublications objectAtIndex:row];
			int oldRating = [pub ratingValueOfField:tcID];
			int newRating = [object intValue];
			if(newRating != oldRating) {
				[pub setField:tcID toRatingValue:newRating];
                [self userChangedField:tcID ofPublications:[NSArray arrayWithObject:pub] from:[NSArray arrayWithObject:[NSString stringWithFormat:@"%i", oldRating]] to:[NSArray arrayWithObject:[NSString stringWithFormat:@"%i", newRating]]];
				[[pub undoManager] setActionName:NSLocalizedString(@"Change Rating", @"Undo action name")];
			}
		}else if([tcID isBooleanField]){
			BibItem *pub = [shownPublications objectAtIndex:row];
            NSCellStateValue oldStatus = [pub boolValueOfField:tcID];
			NSCellStateValue newStatus = [object intValue];
			if(newStatus != oldStatus) {
				[pub setField:tcID toBoolValue:newStatus];
                [self userChangedField:tcID ofPublications:[NSArray arrayWithObject:pub] from:[NSArray arrayWithObject:[NSString stringWithBool:oldStatus]] to:[NSArray arrayWithObject:[NSString stringWithBool:newStatus]]];
				[[pub undoManager] setActionName:NSLocalizedString(@"Change Check Box", @"Undo action name")];
			}
		}else if([tcID isTriStateField]){
			BibItem *pub = [shownPublications objectAtIndex:row];
            NSCellStateValue oldStatus = [pub triStateValueOfField:tcID];
			NSCellStateValue newStatus = [object intValue];
			if(newStatus != oldStatus) {
				[pub setField:tcID toTriStateValue:newStatus];
                [self userChangedField:tcID ofPublications:[NSArray arrayWithObject:pub] from:[NSArray arrayWithObject:[NSString stringWithTriStateValue:oldStatus]] to:[NSArray arrayWithObject:[NSString stringWithTriStateValue:newStatus]]];
				[[pub undoManager] setActionName:NSLocalizedString(@"Change Check Box", @"Undo action name")];
			}
		}
	}else if(tv == groupTableView){
		BDSKGroup *group = [groups objectAtIndex:row];
        // object is always a dictionary, see BDSKGroupCellFormatter
        BDSKASSERT([object isKindOfClass:[NSDictionary class]]);
        NSString *newName = [object valueForKey:BDSKGroupCellStringKey];
        if([[group editingStringValue] isEqualToString:newName])  
            return;
		if([group isCategory]){
            NSArray *pubs = [groupedPublications copy];
            // change the name of the group first, so we can preserve the selection; we need to old group info to move though
            id name = [[self currentGroupField] isPersonField] ? (id)[BibAuthor authorWithName:newName andPub:[[group name] publication]] : (id)newName;
            BDSKCategoryGroup *oldGroup = [[[BDSKCategoryGroup alloc] initWithName:[group name] key:[(BDSKCategoryGroup *)group key] count:[group count]] autorelease];
            [(BDSKCategoryGroup *)group setName:name];
            [self movePublications:pubs fromGroup:oldGroup toGroupNamed:newName];
            [pubs release];
		}else if([group hasEditableName]){
            [(BDSKMutableGroup *)group setName:newName];
            [[self undoManager] setActionName:NSLocalizedString(@"Rename Group", @"Undo action name")];
        }
	}
}

- (NSString *)tableView:(NSTableView *)tv toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(int)row mouseLocation:(NSPoint)mouseLocation{
    if (tv == tableView) {
        NSString *tcID = [tableColumn identifier];
        if ([tcID isEqualToString:BDSKImportOrderString]) {
            if ([[shownPublications objectAtIndex:row] isImported] == NO)
                return NSLocalizedString(@"Click to import this item", @"Tool tip message");
        } else if ([tcID isURLField]) {
            NSURL *url = [[shownPublications objectAtIndex:row] URLForField:tcID];
            if (url)
                return [url isFileURL] ? [[url path] stringByAbbreviatingWithTildeInPath] : [url absoluteString];
        } else if ([tcID isEqualToString:BDSKLocalFileString]) {
            return [[[shownPublications objectAtIndex:row] existingLocalFiles] valueForKeyPath:@"path.stringByAbbreviatingWithTildeInPath.@componentsJoinedByComma"];
        } else if ([tcID isEqualToString:BDSKRemoteURLString]) {
            return [[[shownPublications objectAtIndex:row] remoteURLs] valueForKeyPath:@"URL.absoluteString.@componentsJoinedByComma"];
        }
    } else if (tv == groupTableView) {
        return [[groups objectAtIndex:row] toolTip];
    }
    return nil;
}
    

#pragma mark TableView delegate

- (void)disableGroupRenameWarningAlertDidEnd:(BDSKAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if ([alert checkValue] == YES) {
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:BDSKWarnOnRenameGroupKey];
	}
}

- (BOOL)tableView:(NSTableView *)tv shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)row{
    if(tv == groupTableView){
		if ([[groups objectAtIndex:row] hasEditableName] == NO) 
			return NO;
		else if (NSLocationInRange(row, [groups rangeOfCategoryGroups]) &&
				 [[NSUserDefaults standardUserDefaults] boolForKey:BDSKWarnOnRenameGroupKey]) {
			
			BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Warning", @"Message in alert dialog")
												 defaultButton:NSLocalizedString(@"OK", @"Button title")
											   alternateButton:NSLocalizedString(@"Cancel", @"Button title")
												   otherButton:nil
									 informativeTextWithFormat:NSLocalizedString(@"This action will change the %@ field in %i items. Do you want to proceed?", @"Informative text in alert dialog"), [currentGroupField localizedFieldName], [groupedPublications count]];
			[alert setHasCheckButton:YES];
			[alert setCheckValue:NO];
			int rv = [alert runSheetModalForWindow:documentWindow
									 modalDelegate:self 
									didEndSelector:@selector(disableGroupRenameWarningAlertDidEnd:returnCode:contextInfo:) 
								didDismissSelector:NULL 
									   contextInfo:NULL];
			if (rv == NSAlertAlternateReturn)
				return NO;
		}
		return YES;
	}
    return NO;
}

- (void)tableView:(NSTableView *)tv willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)row{
    if (row == -1) return;
    if (tv == tableView) {
        if([aCell isKindOfClass:[NSButtonCell class]]){
            if ([[aTableColumn identifier] isEqualToString:BDSKImportOrderString]) {
                [aCell setEnabled:[[shownPublications objectAtIndex:row] isImported] == NO];
            } else if ([[aTableColumn identifier] isEqualToString:BDSKCrossrefString]) {
                if ([[shownPublications objectAtIndex:row] crossrefParent]) {
                    [aCell setEnabled:YES];
                    [aCell setImage:[NSImage arrowImage]];
                } else {
                    [aCell setEnabled:YES];
                    [aCell setImage:nil];
                    [aCell setAlternateImage:nil];
                }
            } else {
                [aCell setEnabled:[self hasExternalGroupsSelected] == NO];
            }
        }
    } else if (tv == groupTableView) {
        BDSKGroup *group = [groups objectAtIndex:row];
        NSProgressIndicator *spinner = [groups spinnerForGroup:group];
        
        if (spinner) {
            int column = [[tv tableColumns] indexOfObject:aTableColumn];
            NSRect ignored, rect = [tv frameOfCellAtColumn:column row:row];
            NSSize size = [spinner frame].size;
            NSDivideRect(rect, &ignored, &rect, 3.0f, NSMaxXEdge);
            NSDivideRect(rect, &rect, &ignored, size.width, NSMaxXEdge);
            rect = BDSKCenterRectVertically(rect, size.height, [tv isFlipped]);
            
            [spinner setFrame:rect];
            if ([spinner isDescendantOf:tv] == NO)
                [tv addSubview:spinner];
        }
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification{
	NSTableView *tv = [aNotification object];
    if(tv == tableView || ([self isDisplayingFileContentSearch] && tv == [fileSearchController tableView])){
        NSNotification *note = [NSNotification notificationWithName:BDSKTableSelectionChangedNotification object:self];
        [[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostWhenIdle coalesceMask:NSNotificationCoalescingOnName forModes:nil];
	}else if(tv == groupTableView){
        NSNotification *note = [NSNotification notificationWithName:BDSKGroupTableSelectionChangedNotification object:self];
        [[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostWhenIdle coalesceMask:NSNotificationCoalescingOnName forModes:nil];
        docState.didImport = NO;
    }
}

- (NSDictionary *)defaultColumnWidthsForTableView:(NSTableView *)aTableView{
    NSMutableDictionary *defaultTableColumnWidths = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:BDSKColumnWidthsKey]];
    [defaultTableColumnWidths addEntriesFromDictionary:tableColumnWidths];
    return defaultTableColumnWidths;
}

- (NSDictionary *)currentTableColumnWidthsAndIdentifiers {
    NSEnumerator *tcE = [[tableView tableColumns] objectEnumerator];
    NSTableColumn *tc = nil;
    NSMutableDictionary *columns = [NSMutableDictionary dictionaryWithCapacity:5];
    
    while(tc = [tcE nextObject]){
        [columns setObject:[NSNumber numberWithFloat:[tc width]]
                    forKey:[tc identifier]];
    }
    return columns;
}    

- (void)tableViewColumnDidResize:(NSNotification *)notification{
	if([notification object] != tableView) return;
      
    // current setting will override those already in the prefs; we may not be displaying all the columns in prefs right now, but we want to preserve their widths
    NSMutableDictionary *defaultWidths = [[[NSUserDefaults standardUserDefaults] objectForKey:BDSKColumnWidthsKey] mutableCopy];
    [tableColumnWidths release];
    tableColumnWidths = [[self currentTableColumnWidthsAndIdentifiers] retain];
    [defaultWidths addEntriesFromDictionary:tableColumnWidths];
    [[NSUserDefaults standardUserDefaults] setObject:defaultWidths forKey:BDSKColumnWidthsKey];
    [defaultWidths release];
}


- (void)tableViewColumnDidMove:(NSNotification *)notification{
	if([notification object] != tableView) return;
    
    [[NSUserDefaults standardUserDefaults] setObject:[[[tableView tableColumnIdentifiers] arrayByRemovingObject:BDSKImportOrderString] arrayByRemovingObject:BDSKRelevanceString]
                                                      forKey:BDSKShownColsNamesKey];
}

- (void)tableView:(NSTableView *)tv didClickTableColumn:(NSTableColumn *)tableColumn{
	// check whether this is the right kind of table view and don't re-sort when we have a contextual menu click
    if ([[NSApp currentEvent] type] == NSRightMouseDown) 
        return;
    if (tableView == tv){
        [self sortPubsByKey:[tableColumn identifier]];
	}else if (groupTableView == tv){
        [self sortGroupsByKey:sortGroupsKey];
	}

}

static BOOL menuHasNoValidItems(id validator, NSMenu *menu) {
    int i = [menu numberOfItems];
	while (--i >= 0) {
        NSMenuItem *item = [menu itemAtIndex:i];
        if ([item isSeparatorItem] == NO && [validator validateMenuItem:item])
            return NO;
    }
    return YES;
}

- (NSMenu *)tableView:(NSTableView *)tv menuForTableColumn:(NSTableColumn *)tableColumn row:(int)row {
    
    // autorelease when creating an instance, since there are multiple exit points from this method
	NSMenu *menu = nil;
    NSMenuItem *item = nil;
    
	if (tableColumn == nil || row == -1) 
		return nil;
	
	if(tv == tableView){
		
		NSString *tcId = [tableColumn identifier];
        NSArray *linkedURLs;
        NSURL *theURL;
        
		if([tcId isURLField] || [tcId isEqualToString:BDSKLocalFileString] || [tcId isEqualToString:BDSKRemoteURLString]){
            menu = [[[NSMenu allocWithZone:[NSMenu menuZone]] init] autorelease];
            if([tcId isURLField]){
                if([tcId isLocalFileField]){
                    item = [menu addItemWithTitle:NSLocalizedString(@"Open Linked File", @"Menu item title") action:@selector(openLocalURL:) keyEquivalent:@""];
                    [item setTarget:self];
                    [item setRepresentedObject:tcId];
                    item = [menu addItemWithTitle:NSLocalizedString(@"Reveal Linked File in Finder", @"Menu item title") action:@selector(revealLocalURL:) keyEquivalent:@""];
                    [item setTarget:self];
                    [item setRepresentedObject:tcId];
                    item = [menu addItemWithTitle:NSLocalizedString(@"Show Skim Notes For Linked File", @"Menu item title") action:@selector(showNotesForLocalURL:) keyEquivalent:@""];
                    [item setTarget:self];
                    [item setRepresentedObject:tcId];
                    item = [menu addItemWithTitle:NSLocalizedString(@"Copy Skim Notes For Linked File", @"Menu item title") action:@selector(copyNotesForLocalURL:) keyEquivalent:@""];
                    [item setTarget:self];
                    [item setRepresentedObject:tcId];
                }else{
                    item = [menu addItemWithTitle:NSLocalizedString(@"Open URL in Browser", @"Menu item title") action:@selector(openRemoteURL:) keyEquivalent:@""];
                    [item setTarget:self];
                    [item setRepresentedObject:tcId];
                }
                if([tableView numberOfSelectedRows] == 1 &&
                   (theURL = [[shownPublications objectAtIndex:row] URLForField:tcId])){
                    item = [menu insertItemWithTitle:NSLocalizedString(@"Open With", @"Menu item title") 
                                        andSubmenuOfApplicationsForURL:theURL atIndex:1];
                }
            }else if([tcId isEqualToString:BDSKLocalFileString]){
                linkedURLs = [self selectedFileURLs];
                
                if([linkedURLs count]){
                    if([linkedURLs count] == 1){
                        item = [menu addItemWithTitle:NSLocalizedString(@"Quick Look", @"Menu item title") action:@selector(previewAction:) keyEquivalent:@""];
                        [item setTarget:self];
                        [item setRepresentedObject:linkedURLs];
                    }
                    item = [menu addItemWithTitle:NSLocalizedString(@"Open Linked Files", @"Menu item title") action:@selector(openLinkedFile:) keyEquivalent:@""];
                    [item setTarget:self];
                    item = [menu addItemWithTitle:NSLocalizedString(@"Reveal Linked Files in Finder", @"Menu item title") action:@selector(revealLinkedFile:) keyEquivalent:@""];
                    [item setTarget:self];
                    item = [menu addItemWithTitle:NSLocalizedString(@"Show Skim Notes For Linked Files", @"Menu item title") action:@selector(showNotesForLinkedFile:) keyEquivalent:@""];
                    [item setTarget:self];
                    item = [menu addItemWithTitle:NSLocalizedString(@"Copy Skim Notes For Linked Files", @"Menu item title") action:@selector(copyNotesForLinkedFile:) keyEquivalent:@""];
                    [item setTarget:self];
                    if([linkedURLs count] == 1 && (theURL = [linkedURLs lastObject]) && [theURL isEqual:[NSNull null]] == NO){
                        item = [menu insertItemWithTitle:NSLocalizedString(@"Open With", @"Menu item title") 
                                            andSubmenuOfApplicationsForURL:theURL atIndex:1];
                    }
                }
            }else if([tcId isEqualToString:BDSKRemoteURLString]){
                linkedURLs = [[self selectedPublications] valueForKeyPath:@"@unionOfArrays.remoteURLs.URL"];
                
                if([linkedURLs count]){
                    menu = [[[NSMenu allocWithZone:[NSMenu menuZone]] init] autorelease];
                    if([linkedURLs count] == 1){
                        item = [menu addItemWithTitle:NSLocalizedString(@"Quick Look", @"Menu item title") action:@selector(previewAction:) keyEquivalent:@""];
                        [item setTarget:self];
                        [item setRepresentedObject:linkedURLs];
                    }
                    item = [menu addItemWithTitle:NSLocalizedString(@"Open URLs in Browser", @"Menu item title") action:@selector(openLinkedURL:) keyEquivalent:@""];
                    [item setTarget:self];
                    if([linkedURLs count] == 1 && (theURL = [linkedURLs lastObject]) && [theURL isEqual:[NSNull null]] == NO){
                        item = [menu insertItemWithTitle:NSLocalizedString(@"Open With", @"Menu item title") 
                                            andSubmenuOfApplicationsForURL:theURL atIndex:1];
                    }
                }
            }
            [menu addItem:[NSMenuItem separatorItem]];
            item = [menu addItemWithTitle:NSLocalizedString(@"Get Info", @"Menu item title") action:@selector(editPubCmd:) keyEquivalent:@""];
            [item setTarget:self];
            item = [menu addItemWithTitle:NSLocalizedString(@"Remove", @"Menu item title") action:@selector(removeSelectedPubs:) keyEquivalent:@""];
            [item setTarget:self];
            item = [menu addItemWithTitle:NSLocalizedString(@"Delete", @"Menu item title") action:@selector(deleteSelectedPubs:) keyEquivalent:@""];
            [item setTarget:self];
            [item setKeyEquivalentModifierMask:NSAlternateKeyMask];
            [item setAlternate:YES];
		}else{
            [self menuNeedsUpdate:copyAsMenu];
			menu = [[actionMenu copyWithZone:[NSMenu menuZone]] autorelease];
            [menu removeItemAtIndex:0];
		}
		
	}else if (tv == groupTableView){
		menu = [[groupMenu copyWithZone:[NSMenu menuZone]] autorelease];
        [menu removeItemAtIndex:0];
	}else{
		return nil;
	}
	
	// kick out every item we won't need:
	int i = [menu numberOfItems];
    BOOL wasSeparator = YES;
	
	while (--i >= 0) {
		item = (NSMenuItem*)[menu itemAtIndex:i];
		if ([self validateMenuItem:item] == NO || ((wasSeparator || i == 0) && [item isSeparatorItem]) || ([item submenu] && menuHasNoValidItems(self, [item submenu])))
			[menu removeItem:item];
        else
            wasSeparator = [item isSeparatorItem];
	}
	while([menu numberOfItems] > 0 && [(NSMenuItem*)[menu itemAtIndex:0] isSeparatorItem])	
		[menu removeItemAtIndex:0];
	
	if([menu numberOfItems] == 0)
		return nil;
	
	return menu;
}

- (BOOL)tableViewShouldEditNextItemWhenEditingEnds:(BDSKGroupTableView *)tv{
	if (tv == groupTableView && [[NSUserDefaults standardUserDefaults] boolForKey:BDSKWarnOnRenameGroupKey])
		return NO;
	return YES;
}

- (NSColor *)tableView:(NSTableView *)tv highlightColorForRow:(int)row {
    return [[[self shownPublications] objectAtIndex:row] color];
}

- (NSIndexSet *)tableView:(BDSKGroupTableView *)aTableView indexesOfRowsToHighlightInRange:(NSRange)indexRange {
    if([self numberOfSelectedPubs] == 0 || 
       [self hasExternalGroupsSelected] == YES)
        return [NSIndexSet indexSet];
    
    // Use this for the indexes we're going to return
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    
    // This allows us to be slightly lazy, only putting the visible group rows in the dictionary
    NSMutableIndexSet *visibleIndexes = [NSMutableIndexSet indexSetWithIndexesInRange:indexRange];
    [visibleIndexes removeIndexes:[groupTableView selectedRowIndexes]];
    [visibleIndexes removeIndexesInRange:[groups rangeOfExternalGroups]];
    
    NSArray *selectedPubs = [self selectedPublications];
    unsigned int groupIndex = [visibleIndexes firstIndex];
    
    while (groupIndex != NSNotFound) {
        BDSKGroup *group = [groups objectAtIndex:groupIndex];
        NSEnumerator *pubEnum = [selectedPubs objectEnumerator];
        BibItem *pub;
        while(pub = [pubEnum nextObject]){
            if ([group containsItem:pub]) {
                [indexSet addIndex:groupIndex];
                break;
            }
        }
        groupIndex = [visibleIndexes indexGreaterThanIndex:groupIndex];
    }
    
    return indexSet;
}

- (NSIndexSet *)tableViewSingleSelectionIndexes:(BDSKGroupTableView *)tv {
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSetWithIndexesInRange:[groups rangeOfSharedGroups]];
    [indexes addIndexesInRange:[groups rangeOfURLGroups]];
    [indexes addIndexesInRange:[groups rangeOfScriptGroups]];
    [indexes addIndexesInRange:[groups rangeOfSearchGroups]];
    [indexes addIndex:0];
    if ([groups webGroup])
        [indexes addIndex:1];
    return indexes;
}

- (void)tableView:(BDSKGroupTableView *)tv doubleClickedOnIconOfRow:(int)row{
    [self editGroupAtRow:row];
}

- (NSMenu *)tableView:(BDSKGroupTableView *)tv menuForTableHeaderColumn:(NSTableColumn *)tableColumn onPopUp:(BOOL)flag{
	if ([[tableColumn identifier] isEqualToString:@"group"] && flag == NO) {
		return [[NSApp delegate] groupSortMenu];
	}
	return nil;
}

#pragma mark TableView dragging source

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard{
    NSUserDefaults*sud = [NSUserDefaults standardUserDefaults];
    NSString *dragCopyTypeKey = ([NSApp currentModifierFlags] & NSAlternateKeyMask) ? BDSKAlternateDragCopyTypeKey : BDSKDefaultDragCopyTypeKey;
	int dragCopyType = [sud integerForKey:dragCopyTypeKey];
    BOOL success = NO;
	NSString *citeString = [sud stringForKey:BDSKCiteStringKey];
    NSArray *pubs = nil;
    NSArray *additionalFilenames = nil;
    
	BDSKPRECONDITION(pboard == [NSPasteboard pasteboardWithName:NSDragPboard] || pboard == [NSPasteboard pasteboardWithName:NSGeneralPboard]);

    docState.dragFromExternalGroups = NO;
	
    if(tv == groupTableView){
		if([rowIndexes containsIndex:0]){
			pubs = [NSArray arrayWithArray:publications];
		}else if([rowIndexes count] > 1){
			// multiple dragged rows always are the selected rows
			pubs = [NSArray arrayWithArray:groupedPublications];
		}else if([rowIndexes count] == 1){
            // a single row, not necessarily the selected one
            BDSKGroup *group = [groups objectAtIndex:[rowIndexes firstIndex]];
            if ([group isExternal]) {
                pubs = [NSArray arrayWithArray:[(id)group publications]];
                if ([group isSearch])
                    additionalFilenames = [NSArray arrayWithObject:[[[(BDSKSearchGroup *)group serverInfo] name] stringByAppendingPathExtension:@"bdsksearch"]];
			} else {
                NSMutableArray *pubsInGroup = [NSMutableArray arrayWithCapacity:[publications count]];
                NSEnumerator *pubEnum = [publications objectEnumerator];
                BibItem *pub;
                
                while (pub = [pubEnum nextObject]) {
                    if ([group containsItem:pub]) 
                        [pubsInGroup addObject:pub];
                }
                pubs = pubsInGroup;
            }
            docState.dragFromExternalGroups = [groups hasExternalGroupsAtIndexes:rowIndexes];
		}
		if([pubs count] == 0 && [self hasSearchGroupsSelected] == NO){
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Empty Groups", @"Message in alert dialog when dragging from empty groups")
                                             defaultButton:nil
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"The groups you want to drag do not contain any items.", @"Informative text in alert dialog")];
            [alert beginSheetModalForWindow:documentWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
            return NO;
        }
			
    }else if(tv == tableView){
		// drag from the main table
		pubs = [shownPublications objectsAtIndexes:rowIndexes];
        
        docState.dragFromExternalGroups = [self hasExternalGroupsSelected];

		if(pboard == [NSPasteboard pasteboardWithName:NSDragPboard]){
			// see where we clicked in the table
			// if we clicked on a local file column that has a file, we'll copy that file
			// if we clicked on a remote URL column that has a URL, we'll copy that URL
			// but only if we were passed a single row for now
			
			// we want the drag to occur for the row that is dragged, not the row that is selected
			if([rowIndexes count]){
				NSPoint eventPt = [[tv window] mouseLocationOutsideOfEventStream];
				NSPoint dragPosition = [tv convertPoint:eventPt fromView:nil];
				int dragColumn = [tv columnAtPoint:dragPosition];
				NSString *dragColumnId = nil;
						
				if(dragColumn == -1)
					return NO;
				
				dragColumnId = [[[tv tableColumns] objectAtIndex:dragColumn] identifier];
				
				if([dragColumnId isLocalFileField]){

                    // if we have more than one row, we can't put file contents on the pasteboard, but most apps seem to handle file names just fine
                    unsigned row = [rowIndexes firstIndex];
                    BibItem *pub = nil;
                    NSString *path;
                    NSMutableArray *filePaths = [NSMutableArray arrayWithCapacity:[rowIndexes count]];

                    while(row != NSNotFound){
                        pub = [shownPublications objectAtIndex:row];
                        if (path = [[pub localFileURLForField:dragColumnId] path]){
                            [filePaths addObject:path];
                            NSError *xerror = nil;
                            // we can always write xattrs; this doesn't alter the original file's content in any way, but fails if you have a really long abstract/annote
                            if([[SKNExtendedAttributeManager sharedNoSplitManager] setExtendedAttributeNamed:BDSK_BUNDLE_IDENTIFIER @".bibtexstring" toValue:[[pub bibTeXString] dataUsingEncoding:NSUTF8StringEncoding] atPath:path options:0 error:&xerror] == NO)
                                NSLog(@"%@ line %d: adding xattrs failed with error %@", __FILENAMEASNSSTRING__, __LINE__, xerror);
                        }
                        row = [rowIndexes indexGreaterThanIndex:row];
                    }
                    
                    if([filePaths count]){
                        [pboard declareTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil] owner:nil];
                        return [pboard setPropertyList:filePaths forType:NSFilenamesPboardType];
                    }
                    
				}else if([dragColumnId isRemoteURLField]){
					
                    // cache this so we know which column (field) was dragged
					[self setPromiseDragColumnIdentifier:dragColumnId];

                    // if we have more than one row, we can't put file contents on the pasteboard, but most apps seem to handle file names just fine
                    unsigned row = [rowIndexes firstIndex];
                    BibItem *pub = nil;
                    NSURL *url, *theURL = nil;
                    NSMutableArray *filePaths = [NSMutableArray arrayWithCapacity:[rowIndexes count]];

                    while(row != NSNotFound){
                        pub = [shownPublications objectAtIndex:row];
                        url = [pub remoteURLForField:dragColumnId];
                        if(url != nil){
                            if (theURL == nil)
                                theURL = url;
                            [filePaths addObject:[[pub displayTitle] stringByAppendingPathExtension:@"webloc"]];
                        }
                        row = [rowIndexes indexGreaterThanIndex:row];
					}
                    
                    if([filePaths count]){
                        [pboard declareTypes:[NSArray arrayWithObjects:NSFilesPromisePboardType, NSURLPboardType, nil] owner:self];
                        success = [pboard setPropertyList:filePaths forType:NSFilesPromisePboardType];
                        [theURL writeToPasteboard:pboard];
						return success;
                    }
				
                }else if([dragColumnId isEqualToString:BDSKLocalFileString]){

                    // if we have more than one files, we can't put file contents on the pasteboard, but most apps seem to handle file names just fine
                    unsigned row = [rowIndexes firstIndex];
                    BibItem *pub = nil;
                    NSMutableArray *filePaths = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
                    NSEnumerator *fileEnum;
                    BDSKLinkedFile *file;
                    NSString *path;
                    
                    while(row != NSNotFound){
                        pub = [shownPublications objectAtIndex:row];
                        fileEnum = [[pub localFiles] objectEnumerator];
                        
                        while(file = [fileEnum nextObject]){
                            if (path = [file path]) {
                                [filePaths addObject:path];
                                NSError *xerror = nil;
                                // we can always write xattrs; this doesn't alter the original file's content in any way, but fails if you have a really long abstract/annote
                                if([[SKNExtendedAttributeManager sharedNoSplitManager] setExtendedAttributeNamed:BDSK_BUNDLE_IDENTIFIER @".bibtexstring" toValue:[[pub bibTeXString] dataUsingEncoding:NSUTF8StringEncoding] atPath:path options:0 error:&xerror] == NO)
                                    NSLog(@"%@ line %d: adding xattrs failed with error %@", __FILENAMEASNSSTRING__, __LINE__, xerror);
                            }
                        }
                        row = [rowIndexes indexGreaterThanIndex:row];
                    }
                    
                    if([filePaths count]){
                        [pboard declareTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil] owner:nil];
                        return [pboard setPropertyList:filePaths forType:NSFilenamesPboardType];
                    }
                    
				}else if([dragColumnId isEqualToString:BDSKRemoteURLString]){
					// cache this so we know which column (field) was dragged
					[self setPromiseDragColumnIdentifier:dragColumnId];
                    
                    unsigned row = [rowIndexes firstIndex];
                    BibItem *pub = nil;
                    NSMutableArray *filePaths = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
                    NSString *fileName;
                    NSEnumerator *fileEnum;
                    BDSKLinkedFile *file;
                    NSURL *url, *theURL = nil;
                    
                    while(row != NSNotFound){
                        pub = [shownPublications objectAtIndex:row];
                        fileName = [[pub displayTitle] stringByAppendingPathExtension:@"webloc"];
                        fileEnum = [[pub remoteURLs] objectEnumerator];
                        
                        while(file = [fileEnum nextObject]){
                            if (url = [file URL]) {
                                if (theURL == nil)
                                    theURL = url;
                                [filePaths addObject:fileName];
                            }
                        }
                        row = [rowIndexes indexGreaterThanIndex:row];
                    }
                    
                    if([filePaths count]){
                        [pboard declareTypes:[NSArray arrayWithObjects:NSFilesPromisePboardType, NSURLPboardType, nil] owner:self];
                        success = [pboard setPropertyList:filePaths forType:NSFilesPromisePboardType];
                        [theURL writeToPasteboard:pboard];
                        return success;
                    }
				}
			}
		}
    }
    
    if (dragCopyType == BDSKTemplateDragCopyType) {
        NSString *dragCopyTemplateKey = ([NSApp currentModifierFlags] & NSAlternateKeyMask) ? BDSKAlternateDragCopyTemplateKey : BDSKDefaultDragCopyTemplateKey;
        NSString *template = [sud stringForKey:dragCopyTemplateKey];
        unsigned templateIdx = [[BDSKTemplate allStyleNames] indexOfObject:template];
        if (templateIdx != NSNotFound)
            dragCopyType += templateIdx;
    }
	
	success = [self writePublications:pubs forDragCopyType:dragCopyType citeString:citeString toPasteboard:pboard];
	
    if(success && additionalFilenames){
        [pboardHelper addTypes:[NSArray arrayWithObject:NSFilesPromisePboardType] forPasteboard:pboard];
        [pboardHelper setPropertyList:additionalFilenames forType:NSFilesPromisePboardType forPasteboard:pboard];
    }
    
    return success;
}
	
- (BOOL)writePublications:(NSArray *)pubs forDragCopyType:(int)dragCopyType citeString:(NSString *)citeString toPasteboard:(NSPasteboard*)pboard{
	NSString *mainType = nil;
	NSString *string = nil;
	NSData *data = nil;
    NSArray *URLs = nil;
	
	switch(dragCopyType){
		case BDSKBibTeXDragCopyType:
			mainType = NSStringPboardType;
			string = [self bibTeXStringForPublications:pubs];
			BDSKASSERT(string != nil);
			break;
		case BDSKCiteDragCopyType:
			mainType = NSStringPboardType;
			string = [self citeStringForPublications:pubs citeString:citeString];
			BDSKASSERT(string != nil);
			break;
		case BDSKPDFDragCopyType:
			mainType = NSPDFPboardType;
			break;
		case BDSKRTFDragCopyType:
			mainType = NSRTFPboardType;
			break;
		case BDSKLaTeXDragCopyType:
		case BDSKLTBDragCopyType:
			mainType = NSStringPboardType;
			break;
		case BDSKMinimalBibTeXDragCopyType:
			mainType = NSStringPboardType;
			string = [self bibTeXStringDroppingInternal:YES forPublications:pubs];
			BDSKASSERT(string != nil);
			break;
		case BDSKRISDragCopyType:
			mainType = NSStringPboardType;
			string = [self RISStringForPublications:pubs];
			break;
		case BDSKURLDragCopyType:
			mainType = NSURLPboardType;
			URLs = [pubs valueForKey:@"bdskURL"];
			break;
        default:
            if (dragCopyType >= BDSKTemplateDragCopyType ) {
                NSString *style = [[BDSKTemplate allStyleNames] objectAtIndex:dragCopyType - BDSKTemplateDragCopyType];
                BDSKTemplate *template = [BDSKTemplate templateForStyle:style];
                BDSKTemplateFormat format = [template templateFormat];
                if (format & BDSKPlainTextTemplateFormat) {
                    mainType = NSStringPboardType;
                    string = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:self publications:pubs];
                } else if (format & BDSKRichTextTemplateFormat) {
                    NSDictionary *docAttributes = nil;
                    NSAttributedString *templateString = [BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:self publications:pubs documentAttributes:&docAttributes];
                    if (format & BDSKRTFDTemplateFormat) {
                        mainType = NSRTFDPboardType;
                        data = [templateString RTFDFromRange:NSMakeRange(0,[templateString length]) documentAttributes:docAttributes];
                    } else {
                        mainType = NSRTFPboardType;
                        data = [templateString RTFFromRange:NSMakeRange(0,[templateString length]) documentAttributes:docAttributes];
                    }
                }
            }
	}
    
	[pboardHelper declareType:mainType dragCopyType:dragCopyType forItems:pubs forPasteboard:pboard];
    
    if(string != nil) {
        [pboardHelper setString:string forType:mainType forPasteboard:pboard];
	} else if(data != nil) {
        [pboardHelper setData:data forType:mainType forPasteboard:pboard];
    } else if (URLs != nil) {
        [pboardHelper setURLs:URLs forType:mainType forPasteboard:pboard];
    } else if(dragCopyType >= BDSKTemplateDragCopyType) {
        [pboardHelper setData:nil forType:mainType forPasteboard:pboard];
    }
    return YES;
}

- (void)tableView:(NSTableView *)aTableView concludeDragOperation:(NSDragOperation)operation{
    [self clearPromisedDraggedItems];
}

- (void)clearPromisedDraggedItems{
	[pboardHelper clearPromisedTypesForPasteboard:[NSPasteboard pasteboardWithName:NSDragPboard]];
}

- (NSDragOperation)tableView:(NSTableView *)tv draggingSourceOperationMaskForLocal:(BOOL)isLocal{
    return isLocal ? NSDragOperationEvery : NSDragOperationCopy;
}

- (NSImage *)tableView:(NSTableView *)tv dragImageForRowsWithIndexes:(NSIndexSet *)dragRows{
    return [self dragImageForPromisedItemsUsingCiteString:[[NSUserDefaults standardUserDefaults] stringForKey:BDSKCiteStringKey]];
}

- (NSImage *)dragImageForPromisedItemsUsingCiteString:(NSString *)citeString{
    NSImage *image = nil;
    
    NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSDragPboard];
    NSString *dragType = [pb availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, NSFilesPromisePboardType, NSPDFPboardType, NSRTFPboardType, NSStringPboardType, nil]];
	NSArray *promisedDraggedItems = [pboardHelper promisedItemsForPasteboard:[NSPasteboard pasteboardWithName:NSDragPboard]];
	int dragCopyType = -1;
	int count = 0;
    BOOL inside = NO;
    BOOL isIcon = NO;
	
    if ([dragType isEqualToString:NSFilenamesPboardType]) {
		NSArray *fileNames = [pb propertyListForType:NSFilenamesPboardType];
		count = [fileNames count];
		image = [[NSWorkspace sharedWorkspace] iconForFiles:fileNames];
        isIcon = YES;
        
    } else if ([dragType isEqualToString:NSURLPboardType]) {
        count = 1;
        image = [NSImage imageForURL:[NSURL URLFromPasteboard:pb]];
        isIcon = YES;
        if ([pb availableTypeFromArray:[NSArray arrayWithObject:NSFilesPromisePboardType]])
            count = MAX(1, (int)[[pb propertyListForType:NSFilesPromisePboardType] count]);
        else if ([pb availableTypeFromArray:[NSArray arrayWithObject:@"WebURLsWithTitlesPboardType"]])
            count = MAX(1, (int)[[pboardHelper promisedItemsForPasteboard:pb] count]);
    
	} else if ([dragType isEqualToString:NSFilesPromisePboardType]) {
		NSArray *fileNames = [pb propertyListForType:NSFilesPromisePboardType];
		count = [fileNames count];
        NSString *pathExt = count ? [[fileNames objectAtIndex:0] pathExtension] : @"";
        // promise drags don't use full paths
        image = [[NSWorkspace sharedWorkspace] iconForFileType:pathExt];
        isIcon = YES;
    
	} else {
		NSUserDefaults*sud = [NSUserDefaults standardUserDefaults];
		NSMutableString *s = [NSMutableString string];
        NSString *dragCopyTypeKey = ([NSApp currentModifierFlags] & NSAlternateKeyMask) ? BDSKAlternateDragCopyTypeKey : BDSKDefaultDragCopyTypeKey;
        
        dragCopyType = [sud integerForKey:dragCopyTypeKey];
        
		// don't depend on this being non-zero; this method gets called for drags where promisedDraggedItems is nil
		count = [promisedDraggedItems count];
		
		// we draw only the first item and indicate other items using ellipsis
        if (count) {
            BibItem *firstItem = [promisedDraggedItems objectAtIndex:0];

            switch (dragCopyType) {
                case BDSKBibTeXDragCopyType:
                case BDSKMinimalBibTeXDragCopyType:
                    [s appendString:[firstItem bibTeXStringWithOptions:BDSKBibTeXOptionDropInternalMask]];
                    if (count > 1) {
                        [s appendString:@"\n"];
                        [s appendString:[NSString horizontalEllipsisString]];
                    }
                    inside = YES;
                    break;
                case BDSKCiteDragCopyType:
                    // Are we using a custom citeString (from the drawer?)
                    [s appendString:[self citeStringForPublications:[NSArray arrayWithObject:firstItem] citeString:citeString]];
                    if (count > 1) 
                        [s appendString:[NSString horizontalEllipsisString]];
                    break;
                case BDSKLaTeXDragCopyType:
                    [s appendString:@"\\bibitem{"];
                    [s appendString:[firstItem citeKey]];
                    [s appendString:@"}"];
                    if (count > 1) 
                        [s appendString:[NSString horizontalEllipsisString]];
                    break;
                case BDSKLTBDragCopyType:
                    [s appendString:@"\\bib{"];
                    [s appendString:[firstItem citeKey]];
                    [s appendString:@"}{"];
                    [s appendString:[firstItem pubType]];
                    [s appendString:@"}"];
                    if (count > 1) 
                        [s appendString:[NSString horizontalEllipsisString]];
                    break;
                case BDSKRISDragCopyType:
                    [s appendString:[firstItem RISStringValue]];
                    if (count > 1) 
                        [s appendString:[NSString horizontalEllipsisString]];
                    inside = YES;
                    break;
                case BDSKURLDragCopyType:
                    // in fact, this should already be handled above
                    count = 1;
                    image = [NSImage imageForURL:[NSURL URLFromPasteboard:pb]];
                    isIcon = YES;
                    if ([pb availableTypeFromArray:[NSArray arrayWithObject:@"WebURLsWithTitlesPboardType"]])
                        count = MAX(1, (int)[[pboardHelper promisedItemsForPasteboard:pb] count]);
                    break;
                default:
                    [s appendString:@"["];
                    [s appendString:[firstItem citeKey]]; 
                    [s appendString:@"]"];
                    if (count > 1) 
                        [s appendString:[NSString horizontalEllipsisString]];
                    break;
            }
		}
		NSAttributedString *attrString = [[[NSAttributedString alloc] initWithString:s] autorelease];
		NSSize size = [attrString size];
		NSRect rect = NSZeroRect;
		NSPoint point = NSMakePoint(3.0, 2.0); // offset of the string
		NSColor *color = [NSColor secondarySelectedControlColor];
		
        if (size.width <= 0 || size.height <= 0) {
            NSLog(@"string size was zero");
            size = NSMakeSize(30.0,20.0); // work around bug in NSAttributedString
        }
        if (size.width > MAX_DRAG_IMAGE_WIDTH)
            size.width = MAX_DRAG_IMAGE_WIDTH;
        
		size.width += 2 * point.x;
		size.height += 2 * point.y;
		rect.size = size;
		
		image = [[[NSImage alloc] initWithSize:size] autorelease];
        
        [image lockFocus];
        
        [NSBezierPath drawHighlightInRect:rect radius:4.0 lineWidth:2.0 color:color];
		
		NSRectClip(NSInsetRect(rect, 3.0, 3.0));
        [attrString drawAtPoint:point];
        
        [image unlockFocus];
	}
	
    return [image dragImageWithCount:count inside:inside isIcon:isIcon];
}

#pragma mark TableView dragging destination

- (NSDragOperation)tableView:(NSTableView*)tv
                validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(int)row
       proposedDropOperation:(NSTableViewDropOperation)op{
    
    NSPasteboard *pboard = [info draggingPasteboard];
    BOOL isDragFromMainTable = [[info draggingSource] isEqual:tableView];
    BOOL isDragFromGroupTable = [[info draggingSource] isEqual:groupTableView];
    BOOL isDragFromDrawer = [[info draggingSource] isEqual:[drawerController tableView]];
    
    if(tv == tableView){
        NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, BDSKWeblocFilePboardType, BDSKReferenceMinerStringPboardType, NSStringPboardType, NSFilenamesPboardType, NSURLPboardType, NSColorPboardType, nil]];
        
        if([self hasExternalGroupsSelected] || type == nil) 
			return NSDragOperationNone;
		if ([type isEqualToString:NSColorPboardType]) {
            if (row == -1 || row == [tableView numberOfRows])
                return NSDragOperationNone;
            else if (op == NSTableViewDropAbove)
                [tv setDropRow:row dropOperation:NSTableViewDropOn];
            return NSDragOperationEvery;
        }
        if (isDragFromGroupTable && docState.dragFromExternalGroups && [self hasLibraryGroupSelected]) {
            [tv setDropRow:-1 dropOperation:NSTableViewDropOn];
            return NSDragOperationCopy;
        }
        if(isDragFromMainTable || isDragFromGroupTable || isDragFromDrawer) {
			// can't copy onto same table
			return NSDragOperationNone;
		}
        // set drop row to -1 and NSTableViewDropOperation to NSTableViewDropOn, when we don't target specific rows http://www.corbinstreehouse.com/blog/?p=123
        if(row == -1 || op == NSTableViewDropAbove){
            [tv setDropRow:-1 dropOperation:NSTableViewDropOn];
		}
        // We were checking -containsUnparseableFile here as well, but I think it makes sense to allow the user to target a specific row with any file type (including BibTeX).  Further, checking -containsUnparseableFile can be unacceptably slow (see bug #1799630), which ruins the dragging experience.
        else if(([type isEqualToString:NSFilenamesPboardType] == NO) &&
                 [type isEqualToString:BDSKWeblocFilePboardType] == NO && [type isEqualToString:NSURLPboardType] == NO){
            [tv setDropRow:-1 dropOperation:NSTableViewDropOn];
        }
        if ([type isEqualToString:BDSKBibItemPboardType])   
            return NSDragOperationCopy;
        else
            return NSDragOperationEvery;
    }else if(tv == groupTableView){
        NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, BDSKWeblocFilePboardType, BDSKReferenceMinerStringPboardType, NSFilenamesPboardType, NSURLPboardType, NSStringPboardType, nil]];
		
        if ((isDragFromGroupTable || isDragFromMainTable) && docState.dragFromExternalGroups) {
            if (row != 0)
                return NSDragOperationNone;
            [tv setDropRow:row dropOperation:NSTableViewDropOn];
            return NSDragOperationCopy;
        } else if (isDragFromDrawer || isDragFromGroupTable || type == nil) {
            return NSDragOperationNone;
        }
        
        if (op == NSTableViewDropOn && row >= 0 && [[groups objectAtIndex:row] isEqual:[groups webGroup]] && [[NSSet setWithObjects:BDSKWeblocFilePboardType, NSURLPboardType, nil] containsObject:type]) {
            // drop a URL on the web group
        } else if (op == NSTableViewDropAbove || (row >= 0 && [[groups objectAtIndex:row] isValidDropTarget] == NO)) {
            // here we actually target the whole table, as we don't insert in a specific location
            row = -1;
            [tv setDropRow:row dropOperation:NSTableViewDropOn];
        }
        
        if (isDragFromMainTable) {
            if([type isEqualToString:BDSKBibItemPboardType] && row > 0)
                return NSDragOperationLink;
            else
                return NSDragOperationNone;
        } else if([type isEqualToString:BDSKBibItemPboardType]){
            return NSDragOperationCopy; // @@ can't drag row indexes from another document; should use NSArchiver instead
        } else if (row == -1 && [[NSSet setWithObjects:BDSKWeblocFilePboardType, NSFilenamesPboardType, NSURLPboardType, nil] containsObject:type]){
            [tv setDropRow:-1 dropOperation:NSTableViewDropOn];
            return NSDragOperationLink;
        } else {
            return NSDragOperationEvery;
        }
    }
    return NSDragOperationNone;
}

// This method is called when the mouse is released over a table view that previously decided to allow a drop via the validateDrop method.  The data source should incorporate the data from the dragging pasteboard at this time.

- (BOOL)tableView:(NSTableView*)tv
       acceptDrop:(id <NSDraggingInfo>)info
              row:(int)row
    dropOperation:(NSTableViewDropOperation)op{
	
    NSPasteboard *pboard = [info draggingPasteboard];
    
    if(tv == tableView){
        NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, BDSKWeblocFilePboardType, BDSKReferenceMinerStringPboardType, NSStringPboardType, NSFilenamesPboardType, NSURLPboardType, NSColorPboardType, nil]];
        
        if([self hasExternalGroupsSelected])
            return NO;
		if(row != -1){
            BibItem *pub = [shownPublications objectAtIndex:row];
            NSMutableArray *urlsToAdd = [NSMutableArray array];
            NSURL *theURL = nil;
            
            if([type isEqualToString:NSFilenamesPboardType]){
                NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
                if ([fileNames count] == 0)
                    return NO;
                NSEnumerator *fileEnum = [fileNames objectEnumerator];
                NSString *aPath;
                while (aPath = [fileEnum nextObject])
                    [urlsToAdd addObject:[NSURL fileURLWithPath:[aPath stringByExpandingTildeInPath]]];
            }else if([type isEqualToString:BDSKWeblocFilePboardType]){
                [urlsToAdd addObject:[NSURL URLWithString:[pboard stringForType:BDSKWeblocFilePboardType]]];
            }else if([type isEqualToString:NSURLPboardType]){
                [urlsToAdd addObject:[NSURL URLFromPasteboard:pboard]];
            }else if([type isEqualToString:NSColorPboardType]){
                [[[self shownPublications] objectAtIndex:row] setColor:[NSColor colorFromPasteboard:pboard]];
                return YES;
            }else
                return NO;
            
            if([urlsToAdd count] == 0)
                return NO;
            
            NSEnumerator *urlEnum = [urlsToAdd objectEnumerator];
            while (theURL = [urlEnum nextObject])
                [pub addFileForURL:theURL autoFile:YES runScriptHook:YES];
            
            [self selectPublication:pub];
            [[pub undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
            return YES;
            
        }else{
            
            [self selectLibraryGroup:nil];
            
            if([type isEqualToString:NSFilenamesPboardType]){
                NSArray *filenames = [pboard propertyListForType:NSFilenamesPboardType];
                if([filenames count] == 1){
                    NSString *file = [filenames lastObject];
                    if([[file pathExtension] caseInsensitiveCompare:@"aux"] == NSOrderedSame){
                        NSString *auxString = [NSString stringWithContentsOfFile:file encoding:[self documentStringEncoding] guessEncoding:YES];
                        NSString *command = @"\\bibcite{"; // we used to get the command by looking at the line after \bibdata, but that's unreliable as there can be other stuff in between the \bibcite commands
                        
                        if (auxString == nil)
                            return NO;
                        if ([auxString rangeOfString:command].length == 0) {
                            // if there are no \bibcite commands we'll use the cite's, which are usualy added as \citation commands to the .aux file
                            command = @"\\citation{";
                            if ([auxString rangeOfString:command].length == 0)
                                return NO;
                        }
                        
                        NSScanner *scanner = [NSScanner scannerWithString:auxString];
                        NSString *key = nil;
                        NSArray *items = nil;
                        NSMutableArray *selItems = [NSMutableArray array];
                        
                        [scanner setCharactersToBeSkipped:nil];
                        
                        do {
                            if ([scanner scanString:command intoString:NULL] &&
                                [scanner scanUpToString:@"}" intoString:&key] &&
                                (items = [publications allItemsForCiteKey:key]))
                                [selItems addObjectsFromArray:items];
                            [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:NULL];
                            [scanner scanCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:NULL];
                        } while ([scanner isAtEnd] == NO);
                        
                        if ([selItems count])
                            [self selectPublications:selItems];
                        
                        return YES;
                    }
                }
            }
            
            return [self addPublicationsFromPasteboard:pboard selectLibrary:YES verbose:YES error:NULL];
        }
    } else if(tv == groupTableView){
        NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, BDSKWeblocFilePboardType, BDSKReferenceMinerStringPboardType, NSFilenamesPboardType, NSURLPboardType, NSStringPboardType, nil]];
        NSArray *pubs = nil;
        BOOL isDragFromMainTable = [[info draggingSource] isEqual:tableView];
        BOOL isDragFromGroupTable = [[info draggingSource] isEqual:groupTableView];
        BOOL isDragFromDrawer = [[info draggingSource] isEqual:[drawerController tableView]];
        
        // retain is required to fix bug #1356183
        BDSKGroup *group = row == -1 ? nil : [[[groups objectAtIndex:row] retain] autorelease];
        BOOL shouldSelect = row == -1 || [[self selectedGroups] containsObject:group];
        
		if ((isDragFromGroupTable || isDragFromMainTable) && docState.dragFromExternalGroups && row == 0) {
            return [self addPublicationsFromPasteboard:pboard selectLibrary:NO verbose:YES error:NULL];
        } else if (row >= 0 && [[groups objectAtIndex:row] isEqual:[groups webGroup]] && [[NSSet setWithObjects:BDSKWeblocFilePboardType, NSURLPboardType, nil] containsObject:type]){
            NSURL *url = nil;
            if ([type isEqualToString:BDSKWeblocFilePboardType])
                url = [NSURL URLWithString:[pboard stringForType:BDSKWeblocFilePboardType]]; 	
            else if ([type isEqualToString:NSURLPboardType])
                url = [NSURL URLFromPasteboard:pboard];
            if (url) {
                // switch to the web group
                if ([self hasWebGroupSelected] == NO) {
                    // make sure the controller and its nib are loaded
                    [[self webGroupViewController] window];
                    [self selectGroup:[groups webGroup]];
                }
                [[self webGroupViewController] setURLString:[url absoluteString]];
                return YES;
            } else {
                return NO;
            }
        } else if(isDragFromGroupTable || isDragFromDrawer || (row >= 0 && [group isValidDropTarget] == NO)) {
            return NO;
        } else if(isDragFromMainTable){
            // we already have these publications, so we just want to add them to the group, not the document
            
			pubs = [pboardHelper promisedItemsForPasteboard:[NSPasteboard pasteboardWithName:NSDragPboard]];
        } else if (row == -1 && [[NSSet setWithObjects:BDSKWeblocFilePboardType, NSFilenamesPboardType, NSURLPboardType, nil] containsObject:type]){
            NSArray *urls = nil;
            
            if ([type isEqualToString:BDSKWeblocFilePboardType]) {
                urls = [NSArray arrayWithObjects:[NSURL URLWithString:[pboard stringForType:BDSKWeblocFilePboardType]], nil]; 	
            } else if ([type isEqualToString:NSURLPboardType]) {
                urls = [NSArray arrayWithObjects:[NSURL URLFromPasteboard:pboard], nil];
            } else if ([type isEqualToString:NSFilenamesPboardType]) {
                NSEnumerator *fileEnum = [[pboard propertyListForType:NSFilenamesPboardType] objectEnumerator];
                NSString *file;
                urls = [NSMutableArray array];
                while (file = [fileEnum nextObject])
                    [(NSMutableArray *)urls addObject:[NSURL fileURLWithPath:file]];
            }
            
            NSEnumerator *urlEnum = [urls objectEnumerator];
            NSURL *url;
            group = nil;
            
            while (url = [urlEnum nextObject]) {
                if ([url isFileURL] && [[[url path] pathExtension] isEqualToString:@"bdsksearch"]) {
                    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfURL:url];
                    Class groupClass = NSClassFromString([dictionary objectForKey:@"class"]);
                    group = [[[(groupClass ?: [BDSKSearchGroup class]) alloc] initWithDictionary:dictionary] autorelease];
                    if(group)
                        [groups addSearchGroup:(BDSKSearchGroup *)group];
                } else if ([[url scheme] isEqualToString:@"x-bdsk-search"]) {
                    group = [[[BDSKSearchGroup alloc] initWithURL:url] autorelease];
                    if(group)
                        [groups addSearchGroup:(BDSKSearchGroup *)group];
                } else {
                    group = [[[BDSKURLGroup alloc] initWithURL:url] autorelease];
                    [groups addURLGroup:(BDSKURLGroup *)group];
                }
            }
            if (group)
                [self selectGroup:group];
            if ([urls count]) {
                [[self undoManager] setActionName:NSLocalizedString(@"Add Group", @"Undo action name")];
                return YES;
            } else {
                return NO;
            }
            
        } else {
            
            if([self addPublicationsFromPasteboard:pboard selectLibrary:YES verbose:YES error:NULL] == NO)
                return NO;
            
            pubs = [self selectedPublications];            
        }

        if(row == -1 && [pubs count]){
            // add a new static groups with the added items, use a common author name or keyword if available
            NSEnumerator *pubEnum = [pubs objectEnumerator];
            BibItem *pub = [pubEnum nextObject];
            NSMutableSet *auths = [[NSMutableSet alloc] initForFuzzyAuthors];
            NSMutableSet *keywords = [[NSMutableSet alloc] initWithSet:[pub groupsForField:BDSKKeywordsString]];
            [auths setSet:[pub allPeople]];
            while(pub = [pubEnum nextObject]){
                [auths intersectSet:[pub allPeople]];
                [keywords intersectSet:[pub groupsForField:BDSKKeywordsString]];
            }
            group = [[BDSKStaticGroup alloc] init];
            if([auths count])
                [(BDSKStaticGroup *)group setName:[[auths anyObject] displayName]];
            else if([keywords count])
                [(BDSKStaticGroup *)group setName:[keywords anyObject]];
            [auths release];
            [keywords release];
            [groups addStaticGroup:(BDSKStaticGroup *)group];
            [group release];
        }
        
        // add to the group we're dropping on, /not/ the currently selected group; no need to add to all pubs group, though
        if(group != nil && row != 0 && [pubs count]){
            
            [self addPublications:pubs toGroup:group];
            
            // Reselect if necessary, or we default to selecting the all publications group (which is really annoying when creating a new pub by dropping a PDF on a group).  Don't use row, because we might have added the Last Import group.  Also, note that a side effect of addPublicationsFromPasteboard:selectLibrary:verbose:error: may create a new group (if dropping on a selected category group), so [groups indexOfObjectIdenticalTo:group] == NSNotFound.
            if(shouldSelect) 
                [groupTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[groups indexOfObject:group]] byExtendingSelection:NO];
        }
        
        return YES;
    }
      
    return NO;
}

#pragma mark HFS Promise drags

// promise drags (currently used for webloc files)
- (NSArray *)tableView:(NSTableView *)tv namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination forDraggedRowsWithIndexes:(NSIndexSet *)indexSet;
{

    if ([tv isEqual:tableView]) {
        unsigned rowIdx = [indexSet firstIndex];
        NSMutableDictionary *fullPathDict = [NSMutableDictionary dictionaryWithCapacity:[indexSet count]];
        
        // We're supposed to return this to our caller (usually the Finder); just an array of file names, not full paths
        NSMutableArray *fileNames = [NSMutableArray arrayWithCapacity:[indexSet count]];
        
        NSURL *url = nil;
        NSString *fullPath = nil;
        BibItem *theBib = nil;
        
        // this ivar stores the field name (e.g. Url, L2)
        NSString *fieldName = [self promiseDragColumnIdentifier];
        BOOL isRemoteURLField = [fieldName isRemoteURLField];
        NSEnumerator *fileEnum;
        BDSKLinkedFile *file;
        NSString *fileName;
        NSString *basePath = [dropDestination path];
        int i = 0;
        
        BDSKASSERT(isRemoteURLField || [fieldName isEqualToString:BDSKRemoteURLString]);
        
        while(rowIdx != NSNotFound){
            theBib = [shownPublications objectAtIndex:rowIdx];
            if(isRemoteURLField){
                fileName = [theBib displayTitle];
                fullPath = [[basePath stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"webloc"];
                url = [theBib remoteURLForField:fieldName];
                [fullPathDict setValue:url forKey:fullPath];
                [fileNames addObject:fileName];
            } else{
                fileEnum = [[theBib remoteURLs] objectEnumerator];
                i = 0;
                while (file = [fileEnum nextObject]) {
                    if (url = [file URL]) {
                        fileName = [theBib displayTitle];
                        if (i > 0)
                            fileName = [fileName stringByAppendingFormat:@"-%i", i];
                        i++;
                        fullPath = [[basePath stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"webloc"];
                        [fullPathDict setValue:url forKey:fullPath];
                        [fileNames addObject:fileName];
                    }
                }
            }
            rowIdx = [indexSet indexGreaterThanIndex:rowIdx];
        }
        [self setPromiseDragColumnIdentifier:nil];
        
        [[NSFileManager defaultManager] createWeblocFilesInBackgroundThread:fullPathDict];

        return fileNames;
    } else if ([tv isEqual:groupTableView]) {
        BDSKGroup *group = [groups objectAtIndex:[indexSet firstIndex]];
        NSMutableDictionary *plist = [[[group dictionaryValue] mutableCopy] autorelease];
        if (plist) {
            // we probably don't want to share this info with anyone else
            [plist removeObjectForKey:@"search term"];
            [plist removeObjectForKey:@"history"];
            
            NSString *fileName = [group respondsToSelector:@selector(serverInfo)] ? [[(BDSKSearchGroup *)group serverInfo] name] : [group name];
            fileName = [fileName stringByAppendingPathExtension:@"bdsksearch"];
            NSString *fullPath = [[dropDestination path] stringByAppendingPathComponent:fileName];
            
            // make sure the filename is unique
            fullPath = [[NSFileManager defaultManager] uniqueFilePathWithName:fileName atPath:[dropDestination path]];
            return ([plist writeToFile:fullPath atomically:YES]) ? [NSArray arrayWithObject:fileName] : nil;
        } else
            return nil;
    }
    NSAssert(0, @"code path should be unreached");
    return nil;
}

- (void)setPromiseDragColumnIdentifier:(NSString *)identifier;
{
    if(promiseDragColumnIdentifier != identifier){
        [promiseDragColumnIdentifier release];
        promiseDragColumnIdentifier = [identifier copy];
    }
}

- (NSString *)promiseDragColumnIdentifier;
{
    return promiseDragColumnIdentifier;
}

#pragma mark -

- (BOOL)isDragFromExternalGroups;
{
    return docState.dragFromExternalGroups;
}

- (void)setDragFromExternalGroups:(BOOL)flag;
{
    docState.dragFromExternalGroups = flag;
}

#pragma mark TableView actions

// the next 3 are called from tableview actions defined in NSTableView_OAExtensions

- (void)tableViewInsertNewline:(NSTableView *)tv {
	if (tv == tableView || tv == [fileSearchController tableView]) {
		[self editPubCmd:nil];
	} else if (tv == groupTableView) {
		[self renameGroupAction:nil];
	}
}

- (void)tableViewInsertSpace:(NSTableView *)tv {
	if (tv == tableView || tv == [fileSearchController tableView]) {
		[self pageDownInPreview:nil];
	}
}

- (void)tableViewInsertShiftSpace:(NSTableView *)tv {
	if (tv == tableView || tv == [fileSearchController tableView]) {
		[self pageUpInPreview:nil];
	}
}

- (void)tableView:(NSTableView *)tv deleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
	// the rows are always the selected rows
	if (tv == tableView || tv == [fileSearchController tableView]) {
		[self removeSelectedPubs:nil];
	} else if (tv == groupTableView) {
		[self removeSelectedGroups:nil];
	}
}

- (BOOL)tableView:(NSTableView *)tv canDeleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
	if (tv == tableView || tv == [fileSearchController tableView]) {
		return [self hasExternalGroupsSelected] == NO && [rowIndexes count] > 0;
	} else if (tv == groupTableView) {
		return [self hasStaticGroupsSelected] || [self hasSmartGroupsSelected] || [self hasSearchGroupsSelected] || [self hasURLGroupsSelected] || [self hasScriptGroupsSelected];
	}
    return NO;
}

- (void)tableView:(NSTableView *)tv alternateDeleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
	// the rows are always the selected rows
	if (tv == tableView || tv == [fileSearchController tableView]) {
		[self deleteSelectedPubs:nil];
	}
}

- (BOOL)tableView:(NSTableView *)tv canAlternateDeleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
	if (tv == tableView || tv == [fileSearchController tableView] || tv == groupTableView) {
		return [self hasExternalGroupsSelected] == NO && [rowIndexes count] > 0;
	}
    return NO;
}

- (void)tableView:(NSTableView *)tv pasteFromPasteboard:(NSPasteboard *)pboard{
	if (tv == tableView) {
        NSError *error = nil;
        if ([self addPublicationsFromPasteboard:pboard selectLibrary:YES verbose:YES error:&error] == NO)
            [tv presentError:error];
    } else {
		NSBeep();
	}
}

- (BOOL)tableViewCanPasteFromPasteboard:(NSTableView *)tv {
    if (tv == tableView) {
        return [self hasExternalGroupsSelected] == NO;
    }
    return NO;
}

// Don't use the default copy+paste here, as it uses another pasteboard and some more overhead
- (void)tableView:(NSTableView *)tv duplicateRowsWithIndexes:(NSIndexSet *)rowIndexes {
	// the rows are always the selected rows
	if (tv == tableView) {
        NSArray *newPubs = [[NSArray alloc] initWithArray:[self selectedPublications] copyItems:YES];
        
        [newPubs makeObjectsPerformSelector:@selector(setDateAddedField:) withObject:[[NSCalendarDate date] description]];
        [self addPublications:newPubs]; // notification will take care of clearing the search/sorting
        [self selectPublications:newPubs];
        [newPubs release];
        
        if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKEditOnPasteKey])
            [self editPubCmd:nil]; // this will aske the user when there are many pubs
    } else {
        NSBeep();
    }
}

- (BOOL)tableView:(NSTableView *)tv canDuplicateRowsWithIndexes:(NSIndexSet *)rowIndexes {
    if (tv == tableView) {
		return [self hasExternalGroupsSelected] == NO && [rowIndexes count] > 0;
    }
    return NO;
}

- (void)tableView:(NSTableView *)tv openParentForItemAtRow:(int)row{
    BibItem *parent = [[shownPublications objectAtIndex:row] crossrefParent];
    if (parent)
        [self editPub:parent];
}

#pragma mark -

// as the window delegate, we receive these from NSInputManager and doCommandBySelector:
- (void)moveLeft:(id)sender{
    if([documentWindow firstResponder] != groupTableView && [documentWindow makeFirstResponder:groupTableView])
        if([groupTableView numberOfSelectedRows] == 0)
            [self selectLibraryGroup:nil];
}

- (void)moveRight:(id)sender{
    if([documentWindow firstResponder] != tableView && [documentWindow makeFirstResponder:tableView]){
        if([tableView numberOfSelectedRows] == 0)
            [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    } else if([documentWindow firstResponder] == tableView)
        [self editPubCmd:nil];
}

#pragma mark -
#pragma mark TypeSelectHelper delegate

// used for status bar
- (void)tableView:(NSTableView *)tv typeSelectHelper:(BDSKTypeSelectHelper *)typeSelectHelper updateSearchString:(NSString *)searchString{
    if(searchString == nil || sortKey == nil)
        [self updateStatus]; // resets the status line to its default value
    else if([tv isEqual:tableView]) 
        [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"Finding item with %@: \"%@\"", @"Status message:Finding item with [sorting field]: \"[search string]\""), [sortKey localizedFieldName], searchString]];
    else if([tv isEqual:groupTableView]) 
        [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"Finding group: \"%@\"", @"Status message:Finding group: \"[search string]\""), searchString]];
}

- (void)tableView:(NSTableView *)tv typeSelectHelper:(BDSKTypeSelectHelper *)typeSelectHelper didFailToFindMatchForSearchString:(NSString *)searchString{
    if(sortKey == nil)
        [self updateStatus]; // resets the status line to its default value
    else if([tv isEqual:tableView]) 
        [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"No item with %@: \"%@\"", @"Status message:No item with [sorting field]: \"[search string]\""), [sortKey localizedFieldName], searchString]];
    else if([tv isEqual:groupTableView]) 
        [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"No group: \"%@\"", @"Status message:No group: \"[search string]\""), searchString]];
}

// This is where we build the list of possible items which the user can select by typing the first few letters. You should return an array of NSStrings.
- (NSArray *)tableView:(NSTableView *)tv typeSelectHelperSelectionItems:(BDSKTypeSelectHelper *)typeSelectHelper{
    if([tv isEqual:tableView]){    
        
        // Some users seem to expect that the currently sorted table column is used for typeahead;
        // since the datasource method already knows how to convert columns to BibItem values, we
        // can it almost directly.  It might be possible to cache this in the datasource method itself
        // to avoid calling it twice on -reloadData, but that will only work if -reloadData reloads
        // all rows instead of just visible rows.
        
        unsigned int i, count = [shownPublications count];
        NSMutableArray *a = [NSMutableArray arrayWithCapacity:count];

        // table datasource returns an NSImage for URL fields, so we'll ignore those columns
        if([sortKey isURLField] == NO && nil != sortKey){
            BibItem *pub;
            id value;
            
            for (i = 0; i < count; i++){
                pub = [shownPublications objectAtIndex:i];
                value = [pub displayValueOfField:sortKey];
                
                // use @"" for nil values; ensure typeahead index matches shownPublications index
                [a addObject:value ? [value description] : @""];
            }
        }else{
            for (i = 0; i < count; i++)
                [a addObject:@""];
        }
        return a;
        
    } else if([tv isEqual:groupTableView]){
        
        int i;
		int groupCount = [groups count];
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:groupCount];
        BDSKGroup *group;
        
		BDSKPRECONDITION(groupCount);
        for(i = 0; i < groupCount; i++){
			group = [groups objectAtIndex:i];
            [array addObject:[group stringValue]];
		}
        return array;
        
    } else return [NSArray array];
}

#pragma mark FVFileView data source and delegate

- (NSString *)fileView:(FVFileView *)aFileView subtitleAtIndex:(NSUInteger)anIndex;
{
    return [[[self shownFiles] objectAtIndex:anIndex] valueForKey:@"string"];
}

- (NSUInteger)numberOfURLsInFileView:(FVFileView *)aFileView {
    return [[self shownFiles] count];
}

- (NSURL *)fileView:(FVFileView *)aFileView URLAtIndex:(NSUInteger)anIndex {
    return [[[self shownFiles] objectAtIndex:anIndex] valueForKey:@"URL"];
}

- (BOOL)fileView:(FVFileView *)aFileView shouldOpenURL:(NSURL *)aURL {
    if ([aURL isFileURL]) {
        NSString *searchString = @"";
        // See bug #1344720; don't search if this is a known field (Title, Author, etc.).  This feature can be annoying because Preview.app zooms in on the search result in this case, in spite of your zoom settings (bug report filed with Apple).
        if([[searchButtonController selectedItemIdentifier] isEqualToString:BDSKFileContentSearchString])
            searchString = [searchField stringValue];
        return [[NSWorkspace sharedWorkspace] openURL:aURL withSearchString:searchString] == NO;
    } else {
        return [[NSWorkspace sharedWorkspace] openLinkedURL:aURL] == NO;
    }
}

- (void)fileView:(FVFileView *)aFileView willPopUpMenu:(NSMenu *)menu onIconAtIndex:(NSUInteger)anIndex {
    NSURL *theURL = anIndex == NSNotFound ? nil : [[[self shownFiles] objectAtIndex:anIndex] valueForKey:@"URL"];
    int i;
    NSMenuItem *item;
    
    if (theURL && [[aFileView selectionIndexes] count] <= 1) {
        i = [menu indexOfItemWithTag:FVOpenMenuItemTag];
        [menu insertItemWithTitle:[NSLocalizedString(@"Open With", @"Menu item title") stringByAppendingEllipsis]
                andSubmenuOfApplicationsForURL:theURL atIndex:++i];
        
        if ([theURL isFileURL]) {
            i = [menu indexOfItemWithTag:FVRevealMenuItemTag];
            item = [menu insertItemWithTitle:[NSLocalizedString(@"Skim Notes",@"Menu item title: Skim Note...") stringByAppendingEllipsis]
                                      action:@selector(showNotesForLinkedFile:)
                               keyEquivalent:@""
                                     atIndex:++i];
            [item setRepresentedObject:theURL];
            
            item = [menu insertItemWithTitle:[NSLocalizedString(@"Copy Skim Notes",@"Menu item title: Copy Skim Notes...") stringByAppendingEllipsis]
                                      action:@selector(copyNotesForLinkedFile:)
                               keyEquivalent:@""
                                     atIndex:++i];
            [item setRepresentedObject:theURL];
        }
    }
}

@end

#pragma mark -

@implementation NSPasteboard (BDSKExtensions)

- (BOOL)containsUnparseableFile{
    NSString *type = [self availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]];
    
    if(type == nil)
        return NO;
    
    NSArray *fileNames = [self propertyListForType:NSFilenamesPboardType];
    
    if([fileNames count] != 1)  
        return NO;
        
    NSString *fileName = [fileNames lastObject];
    NSSet *unreadableTypes = [NSSet setForCaseInsensitiveStringsWithObjects:@"pdf", @"ps", @"eps", @"doc", @"htm", @"textClipping", @"webloc", @"html", @"rtf", @"tiff", @"tif", @"png", @"jpg", @"jpeg", nil];
    NSSet *readableTypes = [NSSet setForCaseInsensitiveStringsWithObjects:@"bib", @"aux", @"ris", @"fcgi", @"refman", nil];
    
    if([unreadableTypes containsObject:[fileName pathExtension]])
        return YES;
    if([readableTypes containsObject:[fileName pathExtension]])
        return NO;
    
    NSString *contentString = [[NSString alloc] initWithContentsOfFile:fileName encoding:NSUTF8StringEncoding guessEncoding:YES];
    
    if(contentString == nil)
        return YES;
    if([contentString contentStringType] == BDSKUnknownStringType){
        [contentString release];
        return YES;
    }
    [contentString release];
    return NO;
}

@end

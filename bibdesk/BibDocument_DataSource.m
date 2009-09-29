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
#import "BibDocument_UI.h"
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
#import "BDSKMainTableView.h"
#import "BDSKGroupOutlineView.h"
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
#import "BDSKFileContentSearchController.h"

#define MAX_DRAG_IMAGE_WIDTH 700.0

@interface NSPasteboard (BDSKExtensions)
- (BOOL)containsUnparseableFile;
@end

#pragma mark -

@implementation BibDocument (DataSource)

#pragma mark TableView data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv{
    if(tv == (NSTableView *)tableView) {
        return [shownPublications count];
    }
    // should raise an exception or something
    return 0;
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    if(tv == tableView){
        return [[shownPublications objectAtIndex:row] displayValueOfField:[tableColumn identifier]];
    }
    return nil;
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    if(tv == tableView){

		NSString *tcID = [tableColumn identifier];
		if([tcID isRatingField]){
			BibItem *pub = [shownPublications objectAtIndex:row];
			NSInteger oldRating = [pub ratingValueOfField:tcID];
			NSInteger newRating = [object intValue];
			if(newRating != oldRating) {
				[pub setField:tcID toRatingValue:newRating];
                [self userChangedField:tcID ofPublications:[NSArray arrayWithObject:pub] from:[NSArray arrayWithObject:[NSString stringWithFormat:@"%ld", (long)oldRating]] to:[NSArray arrayWithObject:[NSString stringWithFormat:@"%ld", (long)newRating]]];
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
	}
}

- (NSString *)tableView:(NSTableView *)tv toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation{
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
    }
    return nil;
}
    

#pragma mark TableView delegate

- (void)tableView:(NSTableView *)tv willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)row{
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
        } else if ([[aTableColumn identifier] isEqualToString:BDSKCiteKeyString]) {
            BibItem *pub = [[self shownPublications] objectAtIndex:row];
            [aCell setTextColor:[pub isValidCiteKey:[pub citeKey]] ? [NSColor controlTextColor] : [NSColor redColor]];
        }
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification{
	NSTableView *tv = [aNotification object];
    if(tv == tableView || ([self isDisplayingFileContentSearch] && tv == [fileSearchController tableView])){
        NSNotification *note = [NSNotification notificationWithName:BDSKTableSelectionChangedNotification object:self];
        [[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostWhenIdle coalesceMask:NSNotificationCoalescingOnName forModes:nil];
    }
}

- (NSDictionary *)defaultColumnWidthsForTableView:(NSTableView *)aTableView{
    NSMutableDictionary *defaultTableColumnWidths = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:BDSKColumnWidthsKey]];
    [defaultTableColumnWidths addEntriesFromDictionary:tableColumnWidths];
    return defaultTableColumnWidths;
}

- (NSDictionary *)currentTableColumnWidthsAndIdentifiers {
    NSMutableDictionary *columns = [NSMutableDictionary dictionaryWithCapacity:5];
    
    for (NSTableColumn *tc in [tableView tableColumns]) {
        [columns setObject:[NSNumber numberWithFloat:[tc width]]
                    forKey:[tc identifier]];
    }
    return columns;
}    

- (void)tableViewColumnDidResize:(NSNotification *)notification{
	if ([notification object] == tableView) {
        // current setting will override those already in the prefs; we may not be displaying all the columns in prefs right now, but we want to preserve their widths
        NSMutableDictionary *defaultWidths = [[[NSUserDefaults standardUserDefaults] objectForKey:BDSKColumnWidthsKey] mutableCopy];
        [tableColumnWidths release];
        tableColumnWidths = [[self currentTableColumnWidthsAndIdentifiers] retain];
        [defaultWidths addEntriesFromDictionary:tableColumnWidths];
        [[NSUserDefaults standardUserDefaults] setObject:defaultWidths forKey:BDSKColumnWidthsKey];
        [defaultWidths release];
    }
}


- (void)tableViewColumnDidMove:(NSNotification *)notification{
	if ([notification object] != tableView) {
        [[NSUserDefaults standardUserDefaults] setObject:[[[tableView tableColumnIdentifiers] arrayByRemovingObject:BDSKImportOrderString] arrayByRemovingObject:BDSKRelevanceString]
                                                          forKey:BDSKShownColsNamesKey];
    }
}

- (void)tableView:(NSTableView *)tv didClickTableColumn:(NSTableColumn *)tableColumn{
	// check whether this is the right kind of table view and don't re-sort when we have a contextual menu click
    if (tableView == tv && [[NSApp currentEvent] type] != NSRightMouseDown) {
        [self sortPubsByKey:[tableColumn identifier]];
	}

}

static BOOL menuHasNoValidItems(id validator, NSMenu *menu) {
    NSInteger i = [menu numberOfItems];
	while (--i >= 0) {
        NSMenuItem *item = [menu itemAtIndex:i];
        if ([item isSeparatorItem] == NO && [validator validateMenuItem:item])
            return NO;
    }
    return YES;
}

static void addSubmenuForURLsToItem(NSArray *urls, NSMenuItem *anItem) {
    NSMenu *submenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] init] autorelease];
    for (NSURL *url in urls) {
        NSString *title = [url isFileURL] ? [[NSFileManager defaultManager] displayNameAtPath:[url path]] : [url absoluteString];
        NSMenuItem *item = [submenu addItemWithTitle:title action:[anItem action] keyEquivalent:@""];
        [item setTarget:[anItem target]];
        [item setRepresentedObject:url];
    }
    [anItem setSubmenu:submenu];
}

- (NSMenu *)tableView:(NSTableView *)tv menuForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if (tv != tableView || tableColumn == nil || row == -1) 
		return nil;
    
    // autorelease when creating an instance, since there are multiple exit points from this method
	NSMenu *menu = nil;
    NSMenuItem *item = nil;
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
                item = [menu addItemWithTitle:NSLocalizedString(@"Quick Look", @"Menu item title") action:@selector(previewAction:) keyEquivalent:@""];
                [item setTarget:self];
                [item setRepresentedObject:linkedURLs];
                item = [menu addItemWithTitle:NSLocalizedString(@"Open Linked Files", @"Menu item title") action:@selector(openLinkedFile:) keyEquivalent:@""];
                [item setTarget:self];
                if ([linkedURLs count] > 1)
                    addSubmenuForURLsToItem(linkedURLs, item);
                item = [menu addItemWithTitle:NSLocalizedString(@"Reveal Linked Files in Finder", @"Menu item title") action:@selector(revealLinkedFile:) keyEquivalent:@""];
                [item setTarget:self];
                if ([linkedURLs count] > 1)
                    addSubmenuForURLsToItem(linkedURLs, item);
                item = [menu addItemWithTitle:NSLocalizedString(@"Show Skim Notes For Linked Files", @"Menu item title") action:@selector(showNotesForLinkedFile:) keyEquivalent:@""];
                [item setTarget:self];
                if ([linkedURLs count] > 1)
                    addSubmenuForURLsToItem(linkedURLs, item);
                item = [menu addItemWithTitle:NSLocalizedString(@"Copy Skim Notes For Linked Files", @"Menu item title") action:@selector(copyNotesForLinkedFile:) keyEquivalent:@""];
                [item setTarget:self];
                if ([linkedURLs count] > 1)
                    addSubmenuForURLsToItem(linkedURLs, item);
                if([linkedURLs count] == 1 && (theURL = [linkedURLs lastObject]) && [theURL isEqual:[NSNull null]] == NO){
                    item = [menu insertItemWithTitle:NSLocalizedString(@"Open With", @"Menu item title") 
                                        andSubmenuOfApplicationsForURL:theURL atIndex:1];
                }
            }
        }else if([tcId isEqualToString:BDSKRemoteURLString]){
            linkedURLs = [[self selectedPublications] valueForKeyPath:@"@unionOfArrays.remoteURLs.URL"];
            
            if([linkedURLs count]){
                menu = [[[NSMenu allocWithZone:[NSMenu menuZone]] init] autorelease];
                item = [menu addItemWithTitle:NSLocalizedString(@"Quick Look", @"Menu item title") action:@selector(previewAction:) keyEquivalent:@""];
                [item setTarget:self];
                [item setRepresentedObject:linkedURLs];
                item = [menu addItemWithTitle:NSLocalizedString(@"Open URLs in Browser", @"Menu item title") action:@selector(openLinkedURL:) keyEquivalent:@""];
                [item setTarget:self];
                if ([linkedURLs count] > 1)
                    addSubmenuForURLsToItem(linkedURLs, item);
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
    
	// kick out every item we won't need:
	NSInteger i = [menu numberOfItems];
    BOOL wasSeparator = YES;
	
	while (--i >= 0) {
		item = (NSMenuItem*)[menu itemAtIndex:i];
		if ([self validateMenuItem:item] == NO || ((wasSeparator || i == 0) && [item isSeparatorItem]) || ([item submenu] && menuHasNoValidItems(self, [item submenu])))
			[menu removeItem:item];
        else
            wasSeparator = [item isSeparatorItem];
	}
	while ([menu numberOfItems] > 0 && [(NSMenuItem*)[menu itemAtIndex:0] isSeparatorItem])	
		[menu removeItemAtIndex:0];
	
	return [menu numberOfItems] ? menu : nil;
}

- (NSColor *)tableView:(NSTableView *)tv highlightColorForRow:(NSInteger)row {
    return [[[self shownPublications] objectAtIndex:row] color];
}

#pragma mark TableView dragging source

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard{
    NSUserDefaults*sud = [NSUserDefaults standardUserDefaults];
    NSString *dragCopyTypeKey = ([NSApp currentModifierFlags] & NSAlternateKeyMask) ? BDSKAlternateDragCopyTypeKey : BDSKDefaultDragCopyTypeKey;
	NSInteger dragCopyType = [sud integerForKey:dragCopyTypeKey];
    BOOL success = NO;
	NSString *citeString = [sud stringForKey:BDSKCiteStringKey];
    NSArray *pubs = nil;
    NSArray *additionalFilenames = nil;
    
	BDSKPRECONDITION(pboard == [NSPasteboard pasteboardWithName:NSDragPboard] || pboard == [NSPasteboard pasteboardWithName:NSGeneralPboard]);

    docState.dragFromExternalGroups = NO;
	
    if(tv == tableView){
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
				NSInteger dragColumn = [tv columnAtPoint:dragPosition];
				NSString *dragColumnId = nil;
						
				if(dragColumn == -1)
					return NO;
				
				dragColumnId = [[[tv tableColumns] objectAtIndex:dragColumn] identifier];
				
				if([dragColumnId isLocalFileField]){

                    // if we have more than one row, we can't put file contents on the pasteboard, but most apps seem to handle file names just fine
                    NSUInteger row = [rowIndexes firstIndex];
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
                    NSUInteger row = [rowIndexes firstIndex];
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
                    NSUInteger row = [rowIndexes firstIndex];
                    BibItem *pub = nil;
                    NSMutableArray *filePaths = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
                    NSEnumerator *fileEnum;
                    BDSKLinkedFile *file;
                    NSString *path;
                    
                    while(row != NSNotFound){
                        pub = [shownPublications objectAtIndex:row];
                        
                        for (file in [pub localFiles]) {
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
                    
                    NSUInteger row = [rowIndexes firstIndex];
                    BibItem *pub = nil;
                    NSMutableArray *filePaths = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
                    NSString *fileName;
                    NSEnumerator *fileEnum;
                    BDSKLinkedFile *file;
                    NSURL *url, *theURL = nil;
                    
                    while(row != NSNotFound){
                        pub = [shownPublications objectAtIndex:row];
                        fileName = [[pub displayTitle] stringByAppendingPathExtension:@"webloc"];
                        
                        for (file in [pub remoteURLs]) {
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
    } else {
        return NO;
    }
    
    if (dragCopyType == BDSKTemplateDragCopyType) {
        NSString *dragCopyTemplateKey = ([NSApp currentModifierFlags] & NSAlternateKeyMask) ? BDSKAlternateDragCopyTemplateKey : BDSKDefaultDragCopyTemplateKey;
        NSString *template = [sud stringForKey:dragCopyTemplateKey];
        NSUInteger templateIdx = [[BDSKTemplate allStyleNames] indexOfObject:template];
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
	
- (BOOL)writePublications:(NSArray *)pubs forDragCopyType:(NSInteger)dragCopyType citeString:(NSString *)citeString toPasteboard:(NSPasteboard*)pboard{
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
	NSInteger dragCopyType = -1;
	NSInteger count = 0;
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
            count = MAX(1, (NSInteger)[[pb propertyListForType:NSFilesPromisePboardType] count]);
        else if ([pb availableTypeFromArray:[NSArray arrayWithObject:@"WebURLsWithTitlesPboardType"]])
            count = MAX(1, (NSInteger)[[pboardHelper promisedItemsForPasteboard:pb] count]);
    
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
                        count = MAX(1, (NSInteger)[[pboardHelper promisedItemsForPasteboard:pb] count]);
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

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op{
    
    NSPasteboard *pboard = [info draggingPasteboard];
    BOOL isDragFromMainTable = [[info draggingSource] isEqual:tableView];
    BOOL isDragFromGroupTable = [[info draggingSource] isEqual:groupOutlineView];
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
    }
    return NSDragOperationNone;
}

- (BOOL)selectItemsInAuxFileAtPath:(NSString *)auxPath {
    NSString *auxString = [NSString stringWithContentsOfFile:auxPath encoding:[self documentStringEncoding] guessEncoding:YES];
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

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op{
	
    NSPasteboard *pboard = [info draggingPasteboard];
    
    if (tv == tableView) {
        NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, BDSKWeblocFilePboardType, BDSKReferenceMinerStringPboardType, NSStringPboardType, NSFilenamesPboardType, NSURLPboardType, NSColorPboardType, nil]];
        
        if ([self hasExternalGroupsSelected])
            return NO;
		if (row != -1) {
            BibItem *pub = [shownPublications objectAtIndex:row];
            NSMutableArray *urlsToAdd = [NSMutableArray array];
            
            if ([type isEqualToString:NSFilenamesPboardType]) {
                NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
                if ([fileNames count] == 0)
                    return NO;
                for (NSString *aPath in fileNames)
                    [urlsToAdd addObject:[NSURL fileURLWithPath:[aPath stringByExpandingTildeInPath]]];
            } else if([type isEqualToString:BDSKWeblocFilePboardType]) {
                [urlsToAdd addObject:[NSURL URLWithString:[pboard stringForType:BDSKWeblocFilePboardType]]];
            } else if([type isEqualToString:NSURLPboardType]) {
                [urlsToAdd addObject:[NSURL URLFromPasteboard:pboard]];
            } else if([type isEqualToString:NSColorPboardType]) {
                [[[self shownPublications] objectAtIndex:row] setColor:[NSColor colorFromPasteboard:pboard]];
                return YES;
            } else
                return NO;
            
            if([urlsToAdd count] == 0)
                return NO;
            
            for (NSURL *theURL in urlsToAdd)
                [pub addFileForURL:theURL autoFile:YES runScriptHook:YES];
            
            [self selectPublication:pub];
            [[pub undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
            return YES;
            
        } else {
            
            [self selectLibraryGroup:nil];
            
            if ([type isEqualToString:NSFilenamesPboardType]) {
                NSArray *filenames = [pboard propertyListForType:NSFilenamesPboardType];
                if ([filenames count] == 1) {
                    NSString *file = [filenames lastObject];
                    if([[file pathExtension] caseInsensitiveCompare:@"aux"] == NSOrderedSame)
                        return [self selectItemsInAuxFileAtPath:file];
                }
            }
            
            return [self addPublicationsFromPasteboard:pboard selectLibrary:YES verbose:YES error:NULL];
        }
    }
      
    return NO;
}

#pragma mark HFS Promise drags

// promise drags (currently used for webloc files)
- (NSArray *)tableView:(NSTableView *)tv namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination forDraggedRowsWithIndexes:(NSIndexSet *)indexSet {

    if ([tv isEqual:tableView]) {
        NSUInteger rowIdx = [indexSet firstIndex];
        NSMutableDictionary *fullPathDict = [NSMutableDictionary dictionaryWithCapacity:[indexSet count]];
        
        // We're supposed to return this to our caller (usually the Finder); just an array of file names, not full paths
        NSMutableArray *fileNames = [NSMutableArray arrayWithCapacity:[indexSet count]];
        
        NSURL *url = nil;
        NSString *fullPath = nil;
        BibItem *theBib = nil;
        
        // this ivar stores the field name (e.g. Url, L2)
        NSString *fieldName = [self promiseDragColumnIdentifier];
        BOOL isRemoteURLField = [fieldName isRemoteURLField];
        NSString *fileName;
        NSString *basePath = [dropDestination path];
        NSInteger i = 0;
        
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
                i = 0;
                for (BDSKLinkedFile *file in [theBib remoteURLs]) {
                    if (url = [file URL]) {
                        fileName = [theBib displayTitle];
                        if (i > 0)
                            fileName = [fileName stringByAppendingFormat:@"-%ld", (long)i];
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
    }
    NSAssert(0, @"code path should be unreached");
    return nil;
}

- (void)setPromiseDragColumnIdentifier:(NSString *)identifier {
    if(promiseDragColumnIdentifier != identifier){
        [promiseDragColumnIdentifier release];
        promiseDragColumnIdentifier = [identifier copy];
    }
}

- (NSString *)promiseDragColumnIdentifier {
    return promiseDragColumnIdentifier;
}

#pragma mark TypeSelectHelper delegate

// used for status bar
- (void)tableView:(NSTableView *)tv typeSelectHelper:(BDSKTypeSelectHelper *)typeSelectHelper updateSearchString:(NSString *)searchString{
    if(searchString == nil || sortKey == nil)
        [self updateStatus]; // resets the status line to its default value
    else if([tv isEqual:tableView]) 
        [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"Finding item with %@: \"%@\"", @"Status message:Finding item with [sorting field]: \"[search string]\""), [sortKey localizedFieldName], searchString]];
}

- (void)tableView:(NSTableView *)tv typeSelectHelper:(BDSKTypeSelectHelper *)typeSelectHelper didFailToFindMatchForSearchString:(NSString *)searchString{
    if(sortKey == nil)
        [self updateStatus]; // resets the status line to its default value
    else if([tv isEqual:tableView]) 
        [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"No item with %@: \"%@\"", @"Status message:No item with [sorting field]: \"[search string]\""), [sortKey localizedFieldName], searchString]];
}

// This is where we build the list of possible items which the user can select by typing the first few letters. You should return an array of NSStrings.
- (NSArray *)tableView:(NSTableView *)tv typeSelectHelperSelectionItems:(BDSKTypeSelectHelper *)typeSelectHelper{
    if([tv isEqual:tableView]){    
        
        // Some users seem to expect that the currently sorted table column is used for typeahead;
        // since the datasource method already knows how to convert columns to BibItem values, we
        // can it almost directly.  It might be possible to cache this in the datasource method itself
        // to avoid calling it twice on -reloadData, but that will only work if -reloadData reloads
        // all rows instead of just visible rows.
        
        NSUInteger i, count = [shownPublications count];
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
        
    }
    return [NSArray array];
}

#pragma mark TableView actions

// the next 3 are called from tableview actions defined in NSTableView_OAExtensions

- (void)tableViewInsertNewline:(NSTableView *)tv {
	if (tv == tableView || tv == [fileSearchController tableView]) {
		[self editPubCmd:nil];
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
	if (tv == tableView) {
		[self removePublicationsFromSelectedGroups:[shownPublications objectsAtIndexes:rowIndexes]];
	} else if (tv == [fileSearchController tableView]) {
        [self removePublicationsFromSelectedGroups:[publications itemsForIdentifierURLs:[fileSearchController identifierURLsAtIndexes:rowIndexes]]];
	}
}

- (BOOL)tableView:(NSTableView *)tv canDeleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
	if (tv == tableView || tv == [fileSearchController tableView]) {
		return [self hasExternalGroupsSelected] == NO && [rowIndexes count] > 0;
	}
    return NO;
}

- (void)tableView:(NSTableView *)tv alternateDeleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
	if (tv == tableView) {
		[self deletePublications:[shownPublications objectsAtIndexes:rowIndexes]];
	} else if (tv == [fileSearchController tableView]) {
        [self deletePublications:[publications itemsForIdentifierURLs:[fileSearchController identifierURLsAtIndexes:rowIndexes]]];
	}
}

- (BOOL)tableView:(NSTableView *)tv canAlternateDeleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
	if (tv == tableView || tv == [fileSearchController tableView]) {
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

- (void)tableView:(NSTableView *)tv openParentForItemAtRow:(NSInteger)row{
    BibItem *parent = [[shownPublications objectAtIndex:row] crossrefParent];
    if (parent)
        [self editPub:parent];
}

#pragma mark-
#pragma mark OutlineView data source

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    return item ? [item numberOfChildren] : [groups count];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)idx ofItem:(id)item {
    return item ? [item childAtIndex:idx] : [groups objectAtIndex:idx];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return [item isParent];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    return [item cellValue];
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    // should never receive this for parent groups
    if ([item isParent])
        return;
    
    BDSKGroup *group = item;
    // object is always a group, see BDSKGroupCellFormatter
    BDSKASSERT([object isKindOfClass:[NSDictionary class]]);
    NSString *newName = [object valueForKey:BDSKGroupCellStringKey];
    if([[group editingStringValue] isEqualToString:newName])  
        return;
    if ([group isCategory]) {
        NSArray *pubs = [groupedPublications copy];
        // change the name of the group first, so we can preserve the selection; we need to old group info to move though
        id name = [[self currentGroupField] isPersonField] ? (id)[BibAuthor authorWithName:newName andPub:[[group name] publication]] : (id)newName;
        BDSKCategoryGroup *oldGroup = [[[BDSKCategoryGroup alloc] initWithName:[group name] key:[(BDSKCategoryGroup *)group key] count:[group count]] autorelease];
        [(BDSKCategoryGroup *)group setName:name];
        [self movePublications:pubs fromGroup:oldGroup toGroupNamed:newName];
        [pubs release];
    } else if([group hasEditableName]) {
        [(BDSKMutableGroup *)group setName:newName];
        [[self undoManager] setActionName:NSLocalizedString(@"Rename Group", @"Undo action name")];
    }
}

#pragma mark OutlineView delegate

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item {
    return [item isEqual:[groups libraryParent]] == NO;
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    // return nil to avoid getting called elsewhere with nil table column
    if (nil == tableColumn) return nil;
    
    /*
     Returning a static NSTextFieldCell instance causes a zombie crash on close/reopen, 
     so return a new instance each time.  NSOutlineView must be setting some state on the
     cell before or instead of copying it.
     */
    return [item isParent] ? [groupOutlineView parentCell] : [tableColumn dataCell];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    return [item isParent] == NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item {
    return [item isParent];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if ([item isParent] || [item hasEditableName] == NO) {
        return NO;
    } else if ([item isCategory] && [[NSUserDefaults standardUserDefaults] boolForKey:BDSKWarnOnRenameGroupKey]) {
        
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Warning", @"Message in alert dialog")
                                         defaultButton:NSLocalizedString(@"OK", @"Button title")
                                       alternateButton:NSLocalizedString(@"Cancel", @"Button title")
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"This action will change the %@ field in %ld items. Do you want to proceed?", @"Informative text in alert dialog"), [currentGroupField localizedFieldName], (long)[groupedPublications count]];
        [alert setShowsSuppressionButton:YES];
        NSInteger rv = [alert runModal];
        if ([[alert suppressionButton] state] == NSOnState)
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:BDSKWarnOnRenameGroupKey];
        if (rv == NSAlertAlternateReturn)
            return NO;
    }
    return YES;
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification {
    // call this with a delay, otherwise we'll crash on Tiger, probbaly due to an AppKit bug
    if ([[[notification userInfo] objectForKey:@"NSObject"] isEqual:[groups smartParent]])   
        [self performSelector:@selector(updateSmartGroupsCount) withObject:nil afterDelay:0.0];
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification {
    if ([[groupOutlineView selectedRowIndexes] count] == 0)
        [self selectLibraryGroup:nil];
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    BDSKGroup *group = item;
    NSProgressIndicator *spinner = nil;
    if ([item isParent] == NO)
        spinner = [self spinnerForGroup:group];
    
    if (spinner) {
        NSInteger column = [[outlineView tableColumns] indexOfObject:tableColumn];
        NSRect ignored, rect = [outlineView frameOfCellAtColumn:column row:[outlineView rowForItem:item]];
        NSSize size = [spinner frame].size;
        NSDivideRect(rect, &ignored, &rect, 2.0f, NSMaxXEdge);
        NSDivideRect(rect, &rect, &ignored, size.width, NSMaxXEdge);
        rect = BDSKCenterRectVertically(rect, size.height, [outlineView isFlipped]);
        
        [spinner setFrame:rect];
        if ([spinner isDescendantOf:outlineView] == NO)
            [outlineView addSubview:spinner];
    } 
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    NSNotification *note = [NSNotification notificationWithName:BDSKGroupTableSelectionChangedNotification object:self];
    [[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostWhenIdle coalesceMask:NSNotificationCoalescingOnName forModes:nil];
    docState.didImport = NO;
}

- (NSMenu *)outlineView:(NSOutlineView *)ov menuForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	if (ov != groupOutlineView || tableColumn == nil || item == nil) 
		return nil;
    
    if (item == [groups categoryParent])
        return [[NSApp delegate] groupFieldMenu];
    
    NSMenu *menu = [[groupMenu copyWithZone:[NSMenu menuZone]] autorelease];
    [menu removeItemAtIndex:0];
    
	// kick out every item we won't need:
	NSInteger i = [menu numberOfItems];
    BOOL wasSeparator = YES;
	
	while (--i >= 0) {
		NSMenuItem *menuItem = [menu itemAtIndex:i];
		if ([self validateMenuItem:menuItem] == NO || ((wasSeparator || i == 0) && [menuItem isSeparatorItem]))
			[menu removeItem:menuItem];
        else
            wasSeparator = [menuItem isSeparatorItem];
	}
	while ([menu numberOfItems] > 0 && [(NSMenuItem*)[menu itemAtIndex:0] isSeparatorItem])	
		[menu removeItemAtIndex:0];
	
	return [menu numberOfItems] ? menu : nil;
}

- (NSIndexSet *)outlineView:(BDSKGroupOutlineView *)outlineView indexesOfRowsToHighlightInRange:(NSRange)indexRange {
    if([self numberOfSelectedPubs] == 0 || [self hasExternalGroupsSelected])
        return [NSIndexSet indexSet];
    
    // Use this for the indexes we're going to return
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    
    // This allows us to be slightly lazy, only putting the visible group rows in the dictionary
    NSMutableIndexSet *visibleIndexes = [NSMutableIndexSet indexSetWithIndexesInRange:indexRange];
    [visibleIndexes removeIndexes:[groupOutlineView selectedRowIndexes]];
    
    NSArray *selectedPubs = [self selectedPublications];
    NSUInteger groupIndex = [visibleIndexes firstIndex];
    
    while (groupIndex != NSNotFound) {
        BDSKGroup *group = [groupOutlineView itemAtRow:groupIndex];
        if ([group isExternal] == NO) {
            for (BibItem *pub in selectedPubs) {
                if ([group containsItem:pub]) {
                    [indexSet addIndex:groupIndex];
                    break;
                }
            }
        }
        groupIndex = [visibleIndexes indexGreaterThanIndex:groupIndex];
    }
    
    return indexSet;
}

- (BOOL)outlineView:(BDSKGroupOutlineView *)ov isSingleSelectionItem:(id)item {
    return [item isEqual:[groups libraryGroup]] || [item isExternal];
}

- (void)outlineView:(BDSKGroupOutlineView *)aTableView doubleClickedOnIconOfItem:(id)item {
    [self editGroup:item];
}

- (BOOL)outlineViewShouldEditNextItemWhenEditingEnds:(BDSKGroupOutlineView *)ov{
	if (ov == groupOutlineView && [[NSUserDefaults standardUserDefaults] boolForKey:BDSKWarnOnRenameGroupKey])
		return NO;
	return YES;
}

#pragma mark OutlineView dragging source

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard {
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    NSString *dragCopyTypeKey = ([NSApp currentModifierFlags] & NSAlternateKeyMask) ? BDSKAlternateDragCopyTypeKey : BDSKDefaultDragCopyTypeKey;
	NSInteger dragCopyType = [sud integerForKey:dragCopyTypeKey];
    BOOL success = NO;
	NSString *citeString = [sud stringForKey:BDSKCiteStringKey];
    NSArray *pubs = nil;
    NSArray *additionalFilenames = nil;
    
	BDSKPRECONDITION(pboard == [NSPasteboard pasteboardWithName:NSDragPboard] || pboard == [NSPasteboard pasteboardWithName:NSGeneralPboard]);
    
    docState.dragFromExternalGroups = NO;
	
    if ([items containsObject:[groups libraryGroup]]) {
        pubs = [NSArray arrayWithArray:publications];
    } else if ([items count] > 1) {
        // multiple dragged rows always are the selected rows
        pubs = [NSArray arrayWithArray:groupedPublications];
    } else if ([items count] == 1) {
        // a single row, not necessarily the selected one
        BDSKGroup *group = [items firstObject];
        if ([group isExternal]) {
            pubs = [NSArray arrayWithArray:[(id)group publications]];
            if ([group isSearch])
                additionalFilenames = [NSArray arrayWithObject:[[[(BDSKSearchGroup *)group serverInfo] name] stringByAppendingPathExtension:@"bdsksearch"]];
            docState.dragFromExternalGroups = YES;
        } else {
            NSMutableArray *pubsInGroup = [NSMutableArray arrayWithCapacity:[publications count]];
            for (BibItem *pub in publications) {
                if ([group containsItem:pub]) 
                    [pubsInGroup addObject:pub];
            }
            pubs = pubsInGroup;
        }
    }
    if ([pubs count] == 0 && [self hasSearchGroupsSelected] == NO) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Empty Groups", @"Message in alert dialog when dragging from empty groups")
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"The groups you want to drag do not contain any items.", @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:documentWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
        return NO;
    }
    
    if (dragCopyType == BDSKTemplateDragCopyType) {
        NSString *dragCopyTemplateKey = ([NSApp currentModifierFlags] & NSAlternateKeyMask) ? BDSKAlternateDragCopyTemplateKey : BDSKDefaultDragCopyTemplateKey;
        NSString *template = [sud stringForKey:dragCopyTemplateKey];
        NSUInteger templateIdx = [[BDSKTemplate allStyleNames] indexOfObject:template];
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

- (void)outlineView:(NSOutlineView *)ov concludeDragOperation:(NSDragOperation)operation {
    [self clearPromisedDraggedItems];
}

- (NSDragOperation)outlineView:(NSOutlineView *)ov draggingSourceOperationMaskForLocal:(BOOL)isLocal {
    return isLocal ? NSDragOperationEvery : NSDragOperationCopy;
}

- (NSImage *)outlineView:(NSOutlineView *)ov dragImageForItems:(NSArray *)items{ 
    return [self dragImageForPromisedItemsUsingCiteString:[[NSUserDefaults standardUserDefaults] stringForKey:BDSKCiteStringKey]];
}

#pragma mark OutlineView dragging destination

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)idx {
    NSPasteboard *pboard = [info draggingPasteboard];
    
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, BDSKWeblocFilePboardType, BDSKReferenceMinerStringPboardType, NSStringPboardType, NSFilenamesPboardType, NSURLPboardType, nil]];
    
    // bail out if no recognizable types
    if (nil == type)
        return NSDragOperationNone;
    
    BOOL isDragFromMainTable = [[info draggingSource] isEqual:tableView];
    BOOL isDragFromGroupTable = [[info draggingSource] isEqual:groupOutlineView];
    BOOL isDragFromDrawer = [[info draggingSource] isEqual:[drawerController tableView]];
    
    // drop of items from external groups is allowed only on the Library
    if ((isDragFromGroupTable || isDragFromMainTable) && docState.dragFromExternalGroups) {
        if ([item isEqual:[groups libraryGroup]] == NO && [item isEqual:[groups libraryParent]] == NO)
            return NSDragOperationNone;
        [outlineView setDropItem:[groups libraryGroup] dropChildIndex:NSOutlineViewDropOnItemIndex];
        return NSDragOperationCopy;
    }
    
    // we don't allow local drags unless they're targeted on a specific group
    if (isDragFromDrawer || isDragFromGroupTable)
        return NSDragOperationNone;
    
    // drop a file or URL on external groups
    if ([item isEqual:[groups webGroup]] && idx == NSOutlineViewDropOnItemIndex && [[NSSet setWithObjects:BDSKWeblocFilePboardType, NSURLPboardType, nil] containsObject:type]) {
        return NSDragOperationEvery;
    } else if (([item isExternal] || [item isEqual:[groups externalParent]]) && [[NSSet setWithObjects:BDSKWeblocFilePboardType, NSFilenamesPboardType, NSURLPboardType, nil] containsObject:type]) {
        [outlineView setDropItem:[groups externalParent] dropChildIndex:NSOutlineViewDropOnItemIndex];
        return NSDragOperationLink;
    }
    
    // we don't insert in a particular location
    if (idx != NSOutlineViewDropOnItemIndex) {
        if (nil == item || [(BDSKParentGroup *)item numberOfChildren] == 0) {
            // here we actually target the whole table or the parent
            [outlineView setDropItem:item dropChildIndex:NSOutlineViewDropOnItemIndex];
        } else {
            // redirect to a drop on the closest child
            item = [(BDSKParentGroup *)item childAtIndex:MIN((NSInteger)[(BDSKParentGroup *)item numberOfChildren] - 1, idx)];
            [outlineView setDropItem:item dropChildIndex:NSOutlineViewDropOnItemIndex];
        }
        idx = NSOutlineViewDropOnItemIndex;
    }
    
    // no dropping on shared groups or parents other than the static parent
    if (item && [item isValidDropTarget] == NO)
        return NSDragOperationNone;
    
    if (isDragFromMainTable) {
        if ([type isEqualToString:BDSKBibItemPboardType] == NO || item == nil || [item isEqual:[groups libraryGroup]])
            return NSDragOperationNone;
        return NSDragOperationLink;
    } else if ([type isEqualToString:BDSKBibItemPboardType]) {
        return NSDragOperationCopy;
    } else {
        return NSDragOperationEvery;
    }
    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)idx {
	
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, BDSKWeblocFilePboardType, BDSKReferenceMinerStringPboardType, NSFilenamesPboardType, NSURLPboardType, NSStringPboardType, nil]];
    NSArray *pubs = nil;
    BOOL isDragFromMainTable = [[info draggingSource] isEqual:tableView];
    BOOL isDragFromGroupTable = [[info draggingSource] isEqual:groupOutlineView];
    BOOL isDragFromDrawer = [[info draggingSource] isEqual:[drawerController tableView]];
    
    if ((isDragFromGroupTable || isDragFromMainTable) && docState.dragFromExternalGroups) {
        
        return [self addPublicationsFromPasteboard:pboard selectLibrary:NO verbose:YES error:NULL];
        
    } else if (idx == NSOutlineViewDropOnItemIndex && [item isEqual:[groups webGroup]] && [[NSSet setWithObjects:BDSKWeblocFilePboardType, NSURLPboardType, nil] containsObject:type]) {
        
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
        
    } else if (([item isExternal] || [item isEqual:[groups externalParent]]) && [[NSSet setWithObjects:BDSKWeblocFilePboardType, NSFilenamesPboardType, NSURLPboardType, nil] containsObject:type]){
        
        NSArray *urls = nil;
        
        if ([type isEqualToString:BDSKWeblocFilePboardType]) {
            urls = [NSArray arrayWithObjects:[NSURL URLWithString:[pboard stringForType:BDSKWeblocFilePboardType]], nil]; 	
        } else if ([type isEqualToString:NSURLPboardType]) {
            urls = [NSArray arrayWithObjects:[NSURL URLFromPasteboard:pboard], nil];
        } else if ([type isEqualToString:NSFilenamesPboardType]) {
            urls = [NSMutableArray array];
            for (NSString *file in [pboard propertyListForType:NSFilenamesPboardType])
                [(NSMutableArray *)urls addObject:[NSURL fileURLWithPath:file]];
        }
        
        BDSKGroup *group = nil;
        
        for (NSURL *url in urls) {
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
        
    }
    
    if (idx != NSOutlineViewDropOnItemIndex) {
        // we shouldn't get here at this point
        if (item && [(BDSKParentGroup *)item numberOfChildren])
            item = [(BDSKParentGroup *)item childAtIndex:MIN((NSInteger)[(BDSKParentGroup *)item numberOfChildren] - 1, idx)];
        idx = NSOutlineViewDropOnItemIndex;
    }
    
    if (isDragFromGroupTable || isDragFromDrawer || (item && [item isValidDropTarget] == NO)) {
        // shouldn't get here at this point
        return NO;
    } else if (isDragFromMainTable) {
        // we already have these publications, so we just want to add them to the group, not the document
        pubs = [pboardHelper promisedItemsForPasteboard:[NSPasteboard pasteboardWithName:NSDragPboard]];
    } else {
        if ([self addPublicationsFromPasteboard:pboard selectLibrary:YES verbose:YES error:NULL])
            pubs = [self selectedPublications];     
    }
    
    if ([pubs count] == 0)
        return NO;
    
    BOOL shouldSelect = (item == nil || [item isParent] || [[self selectedGroups] containsObject:item]);
    
    // if dropping on the static group parent, create a new static groups using a common author name or keyword if available
    if ([item isEqual:[groups staticParent]]) {
        NSEnumerator *pubEnum = [pubs objectEnumerator];
        BibItem *pub = [pubEnum nextObject];
        NSMutableSet *auths = [[NSMutableSet alloc] initForFuzzyAuthors];
        NSMutableSet *keywords = [[NSMutableSet alloc] initWithSet:[pub groupsForField:BDSKKeywordsString]];
        
        [auths setSet:[pub allPeople]];
        while (pub = [pubEnum nextObject]) {
            [auths intersectSet:[pub allPeople]];
            [keywords intersectSet:[pub groupsForField:BDSKKeywordsString]];
        }
        
        item = [[[BDSKStaticGroup alloc] init] autorelease];
        if ([auths count])
            [(BDSKStaticGroup *)item setName:[[auths anyObject] displayName]];
        else if ([keywords count])
            [(BDSKStaticGroup *)item setName:[keywords anyObject]];
        [auths release];
        [keywords release];
        [groups addStaticGroup:(BDSKStaticGroup *)item];
    }
    
    // add to the group we're dropping on, /not/ the currently selected group; no need to add to all pubs group, though
    if (item && [item isParent] == NO && [item isEqual:[groups libraryGroup]] == NO) {
        
        [self addPublications:pubs toGroup:item];
        // Reselect if necessary, or we default to selecting the all publications group (which is really annoying when creating a new pub by dropping a PDF on a group).
        if (shouldSelect)
            [self selectGroup:item];
    }
    
    return YES;
}

#pragma mark HFS Promise drags

- (NSArray *)outlineView:(NSOutlineView *)outlineView namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination forDraggedItems:(NSArray *)items {
    NSMutableArray *droppedFiles = [NSMutableArray array];
    for (BDSKGroup *group in items) {
        NSMutableDictionary *plist = [[[group dictionaryValue] mutableCopy] autorelease];

        // we probably don't want to share this info with anyone else
        [plist removeObjectForKey:@"search term"];
        [plist removeObjectForKey:@"history"];
        
        NSString *fileName = [group respondsToSelector:@selector(serverInfo)] ? [[(BDSKSearchGroup *)group serverInfo] name] : [group name];
        fileName = [fileName stringByAppendingPathExtension:@"bdsksearch"];
        
        // make sure the filename is unique
        NSString *fullPath = [[NSFileManager defaultManager] uniqueFilePathWithName:fileName atPath:[dropDestination path]];
        if([plist writeToFile:fullPath atomically:YES])
            [droppedFiles addObject:[fullPath lastPathComponent]];
        
    }
    return droppedFiles;
}

#pragma mark TypeSelectHelper delegate

// used for status bar
- (void)outlineView:(NSOutlineView *)ov typeSelectHelper:(BDSKTypeSelectHelper *)typeSelectHelper updateSearchString:(NSString *)searchString{
    if (searchString == nil || sortKey == nil)
        [self updateStatus]; // resets the status line to its default value
    else if ([ov isEqual:groupOutlineView]) 
        [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"Finding group: \"%@\"", @"Status message:Finding group: \"[search string]\""), searchString]];
}

- (void)outlineView:(NSOutlineView *)ov typeSelectHelper:(BDSKTypeSelectHelper *)typeSelectHelper didFailToFindMatchForSearchString:(NSString *)searchString{
    if (sortKey == nil)
        [self updateStatus]; // resets the status line to its default value
    else if ([ov isEqual:groupOutlineView]) 
        [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"No group: \"%@\"", @"Status message:No group: \"[search string]\""), searchString]];
}

// This is where we build the list of possible items which the user can select by typing the first few letters. You should return an array of NSStrings.
- (NSArray *)outlineView:(NSOutlineView *)ov typeSelectHelperSelectionItems:(BDSKTypeSelectHelper *)typeSelectHelper{
    if ([ov isEqual:groupOutlineView]) {
        
        NSInteger i;
		NSInteger groupCount = [ov numberOfRows];
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:groupCount];
        BDSKGroup *group;
        
		BDSKPRECONDITION(groupCount);
        for(i = 0; i < groupCount; i++){
			group = [ov itemAtRow:i];
            [array addObject:[group isParent] ? @"" : [group stringValue]];
		}
        return array;
        
    } else return [NSArray array];
}

#pragma mark OutlineView actions

- (void)outlineViewInsertNewline:(NSOutlineView *)ov {
	if (ov == groupOutlineView) {
		[self renameGroupAction:nil];
	}
}

- (void)outlineView:(NSOutlineView *)ov deleteItems:(NSArray *)items {
	if (ov == groupOutlineView) {
		[self removeGroups:items];
	}
}

- (BOOL)outlineView:(NSOutlineView *)ov canDeleteItems:(NSArray *)items {
	if (ov == groupOutlineView) {
		return [[items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isStatic == YES OR isSmart == YES OR isSearch == YES OR isURL == YES OR isScript == YES"]] count] > 0;
	}
    return NO;
}

#pragma mark -

- (BOOL)isDragFromExternalGroups {
    return docState.dragFromExternalGroups;
}

- (void)setDragFromExternalGroups:(BOOL)flag {
    docState.dragFromExternalGroups = flag;
}

#pragma mark -
#pragma mark FVFileView data source and delegate

- (NSString *)fileView:(FVFileView *)aFileView subtitleAtIndex:(NSUInteger)anIndex {
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
    NSInteger i;
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
    
    if ([self isDisplayingFileContentSearch] == NO && [self hasExternalGroupsSelected] == NO && [[self selectedPublications] count] == 1) {
        i = [menu indexOfItemWithTag:FVRemoveMenuItemTag];
        if (i != NSNotFound && theURL && [[aFileView selectionIndexes] count] == 1) {
            if ([theURL isFileURL]) {
                item = [menu insertItemWithTitle:[NSLocalizedString(@"Replace File", @"Menu item title") stringByAppendingEllipsis]
                                          action:@selector(chooseLinkedFile:)
                                   keyEquivalent:@""
                                         atIndex:++i];
                [item setRepresentedObject:[NSNumber numberWithUnsignedInt:anIndex]];
            } else {
                item = [menu insertItemWithTitle:[NSLocalizedString(@"Replace URL", @"Menu item title") stringByAppendingEllipsis]
                                          action:@selector(chooseLinkedURL:)
                                   keyEquivalent:@""
                                         atIndex:++i];
                [item setRepresentedObject:[NSNumber numberWithUnsignedInt:anIndex]];
            }
        }
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        [menu addItemWithTitle:[NSLocalizedString(@"Choose File", @"Menu item title") stringByAppendingEllipsis]
                        action:@selector(chooseLinkedFile:)
                 keyEquivalent:@""];
        
        [menu addItemWithTitle:[NSLocalizedString(@"Choose URL", @"Menu item title") stringByAppendingEllipsis]
                        action:@selector(chooseLinkedURL:)
                 keyEquivalent:@""];
    }
}

- (BOOL)fileView:(FVFileView *)aFileView moveURLsAtIndexes:(NSIndexSet *)aSet toIndex:(NSUInteger)anIndex forDrop:(id <NSDraggingInfo>)info dropOperation:(FVDropOperation)operation {
    BDSKASSERT(anIndex != NSNotFound);
    if ([self isDisplayingFileContentSearch] == NO && [self hasExternalGroupsSelected] == NO) {
        NSArray *selPubs = [self selectedPublications];
        if ([selPubs count] == 1) {
            [[selPubs lastObject] moveFilesAtIndexes:aSet toIndex:anIndex];
            return YES;
        }
    }
    return NO;
}

- (BOOL)fileView:(FVFileView *)aFileView replaceURLsAtIndexes:(NSIndexSet *)aSet withURLs:(NSArray *)newURLs forDrop:(id <NSDraggingInfo>)info dropOperation:(FVDropOperation)operation {
    BibItem *publication = nil;
    if ([self isDisplayingFileContentSearch] == NO && [self hasExternalGroupsSelected] == NO) {
        NSArray *selPubs = [self selectedPublications];
        if ([selPubs count] == 1)
            publication = [selPubs lastObject];
    }
    if (publication == nil)
        return NO;
    
    BDSKLinkedFile *aFile = nil;
    NSEnumerator *enumerator = [newURLs objectEnumerator];
    NSURL *aURL;
    NSUInteger idx = [aSet firstIndex];
    
    while (NSNotFound != idx) {
        if ((aURL = [enumerator nextObject]) && 
            (aFile = [BDSKLinkedFile linkedFileWithURL:aURL delegate:publication])) {
            NSURL *oldURL = [[[publication objectInFilesAtIndex:idx] URL] retain];
            [publication removeObjectFromFilesAtIndex:idx];
            if (oldURL)
                [self userRemovedURL:oldURL forPublication:publication];
            [oldURL release];
            [publication insertObject:aFile inFilesAtIndex:idx];
            [self userAddedURL:aURL forPublication:publication];
            if (([NSApp currentModifierFlags] & NSCommandKeyMask) == 0)
                [publication autoFileLinkedFile:aFile];
        }
        idx = [aSet indexGreaterThanIndex:idx];
    }
    return YES;
}

- (void)fileView:(FVFileView *)aFileView insertURLs:(NSArray *)absoluteURLs atIndexes:(NSIndexSet *)aSet forDrop:(id <NSDraggingInfo>)info dropOperation:(FVDropOperation)operation {
    BibItem *publication = nil;
    if ([self isDisplayingFileContentSearch] == NO && [self hasExternalGroupsSelected] == NO) {
        NSArray *selPubs = [self selectedPublications];
        if ([selPubs count] == 1)
            publication = [selPubs lastObject];
    }
    if (publication == nil)
        return;
    
    BDSKLinkedFile *aFile;
    NSEnumerator *enumerator = [absoluteURLs objectEnumerator];
    NSURL *aURL;
    NSUInteger idx = [aSet firstIndex], offset = 0;
    
    while (NSNotFound != idx) {
        if ((aURL = [enumerator nextObject]) && 
            (aFile = [BDSKLinkedFile linkedFileWithURL:aURL delegate:publication])) {
            [publication insertObject:aFile inFilesAtIndex:idx - offset];
            [self userAddedURL:aURL forPublication:publication];
            if (([NSApp currentModifierFlags] & NSCommandKeyMask) == 0)
                [publication autoFileLinkedFile:aFile];
        } else {
            // the indexes in aSet assume that we inserted the file
            offset++;
        }
        idx = [aSet indexGreaterThanIndex:idx];
    }
}

- (void)trashAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if (alert && [[alert suppressionButton] state] == NSOnState)
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:BDSKAskToTrashFilesKey];
    NSArray *fileURLs = [(NSArray *)contextInfo autorelease];
    if (returnCode == NSAlertAlternateReturn) {
        for (NSURL *url in fileURLs) {
            NSString *path = [url path];
            NSString *folderPath = [path stringByDeletingLastPathComponent];
            NSString *fileName = [path lastPathComponent];
            NSInteger tag = 0;
            [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:folderPath destination:nil files:[NSArray arrayWithObjects:fileName, nil] tag:&tag];
        }
    }
}

// moveToTrash: 0 = no, 1 = yes, -1 = ask
- (void)publication:(BibItem *)publication deleteURLsAtIndexes:(NSIndexSet *)indexSet moveToTrash:(NSInteger)moveToTrash{
    NSUInteger idx = [indexSet lastIndex];
    NSMutableArray *fileURLs = [NSMutableArray array];
    while (NSNotFound != idx) {
        NSURL *aURL = [[[publication objectInFilesAtIndex:idx] URL] retain];
        if ([aURL isFileURL])
            [fileURLs addObject:aURL];
        [publication removeObjectFromFilesAtIndex:idx];
        if (aURL)
            [self userRemovedURL:aURL forPublication:publication];
        [aURL release];
        idx = [indexSet indexLessThanIndex:idx];
    }
    if ([fileURLs count]) {
        if (moveToTrash == 1) {
            [self trashAlertDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:[fileURLs retain]];
        } else if (moveToTrash == -1) {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Move Files to Trash?", @"Message in alert dialog when deleting a file")
                                             defaultButton:NSLocalizedString(@"No", @"Button title")
                                           alternateButton:NSLocalizedString(@"Yes", @"Button title")
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"Do you want to move the removed files to the trash?", @"Informative text in alert dialog")];
            [alert setShowsSuppressionButton:YES];
            [alert beginSheetModalForWindow:documentWindow
                              modalDelegate:self 
                             didEndSelector:@selector(trashAlertDidEnd:returnCode:contextInfo:)  
                                contextInfo:[fileURLs retain]];
        }
    }
}

- (BOOL)fileView:(FVFileView *)aFileView deleteURLsAtIndexes:(NSIndexSet *)indexSet {
    BibItem *publication = nil;
    if ([self isDisplayingFileContentSearch] == NO && [self hasExternalGroupsSelected] == NO) {
        NSArray *selPubs = [self selectedPublications];
        if ([selPubs count] == 1)
            publication = [selPubs lastObject];
    }
    if (publication == nil)
        return NO;
    
    NSInteger moveToTrash = [[NSUserDefaults standardUserDefaults] boolForKey:BDSKAskToTrashFilesKey] ? -1 : 0;
    [self publication:publication deleteURLsAtIndexes:indexSet moveToTrash:moveToTrash];
    return YES;
}

- (NSDragOperation)fileView:(FVFileView *)aFileView validateDrop:(id <NSDraggingInfo>)info proposedIndex:(NSUInteger)anIndex proposedDropOperation:(FVDropOperation)dropOperation proposedDragOperation:(NSDragOperation)dragOperation {
    BibItem *publication = nil;
    if ([self isDisplayingFileContentSearch] == NO && [self hasExternalGroupsSelected] == NO) {
        NSArray *selPubs = [self selectedPublications];
        if ([selPubs count] == 1)
            publication = [selPubs lastObject];
    }
    if (publication == nil)
        return NSDragOperationNone;
    
    NSDragOperation dragOp = dragOperation;
    if ([[info draggingSource] isEqual:aFileView] && dropOperation == FVDropOn && dragOperation != NSDragOperationCopy) {
        // redirect local drop on icon and drop on view
        NSIndexSet *dragIndexes = [aFileView selectionIndexes];
        NSUInteger firstIndex = [dragIndexes firstIndex], endIndex = [dragIndexes lastIndex] + 1, count = [publication countOfFiles];
        if (anIndex == NSNotFound)
            anIndex = count;
        // if we're dragging a continuous range, don't move when we drop on that range
        if ([dragIndexes count] != endIndex - firstIndex || anIndex < firstIndex || anIndex > endIndex) {
            dragOp = NSDragOperationMove;
            if (anIndex == count) // note that the count must be > 0, or we wouldn't have a local drag
                [aFileView setDropIndex:count - 1 dropOperation:FVDropAfter];
            else
                [aFileView setDropIndex:anIndex dropOperation:FVDropBefore];
        }
    } else if (dragOperation == NSDragOperationLink && ([NSApp currentModifierFlags] & NSCommandKeyMask) == 0) {
        dragOp = NSDragOperationGeneric;
    }
    return dragOp;
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

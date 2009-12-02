//
//  BDSKTableView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/18/09.
/*
 This software is Copyright (c) 2009
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKTableView.h"
#import "NSLayoutManager_BDSKExtensions.h"
#import "NSEvent_BDSKExtensions.h"


static char BDSKTableViewFontDefaultsObservationContext;

@implementation BDSKTableView

+ (BOOL)shouldQueueTypeSelectHelper { return NO; }

- (void)dealloc {
    [self setFontNamePreferenceKey:nil]; // this will also stop observing
    [self setFontSizePreferenceKey:nil];
    [typeSelectHelper setDataSource:nil];
    BDSKDESTROY(typeSelectHelper);
    [super dealloc];
}

#pragma mark TypeSelectHelper methods

- (BDSKTypeSelectHelper *)typeSelectHelper {
    return typeSelectHelper;
}

- (void)setTypeSelectHelper:(BDSKTypeSelectHelper *)newTypeSelectHelper {
    if (typeSelectHelper != newTypeSelectHelper) {
        if ([typeSelectHelper dataSource] == self) {
            if ([[self class] shouldQueueTypeSelectHelper])
                [[typeSelectHelper class] cancelPreviousPerformRequestsWithTarget:typeSelectHelper selector:@selector(rebuildTypeSelectSearchCache) object:nil];
            [typeSelectHelper setDataSource:nil];
        }
        [typeSelectHelper release];
        typeSelectHelper = [newTypeSelectHelper retain];
        [typeSelectHelper setDataSource:self];
    }
}

- (void)reloadData {
    [super reloadData];
    if (typeSelectHelper) {
        if ([[self class] shouldQueueTypeSelectHelper]) {
            [[typeSelectHelper class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(rebuildTypeSelectSearchCache) object:nil];
            [typeSelectHelper performSelector:@selector(rebuildTypeSelectSearchCache) withObject:nil afterDelay:0.0];
        } else {
            [typeSelectHelper rebuildTypeSelectSearchCache];
        }
    }
}

#pragma mark Font preferences methods

- (void)addObserverForFontPreferences {
    if (fontNamePreferenceKey && fontSizePreferenceKey) {
        [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:[@"values." stringByAppendingString:fontNamePreferenceKey] options:0 context:&BDSKTableViewFontDefaultsObservationContext];
        [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:[@"values." stringByAppendingString:fontSizePreferenceKey] options:0 context:&BDSKTableViewFontDefaultsObservationContext];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFontPanel:) name:NSWindowDidBecomeKeyNotification object:[self window]];
    }
}

- (void)removeObserverForFontPreferences {
    if (fontNamePreferenceKey && fontSizePreferenceKey) {
        [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:[@"values." stringByAppendingString:fontNamePreferenceKey]];
        [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:[@"values." stringByAppendingString:fontSizePreferenceKey]];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeKeyNotification object:[self window]];
    }
}

- (NSString *)fontNamePreferenceKey{
    return fontNamePreferenceKey;
}

- (void)setFontNamePreferenceKey:(NSString *)newFontNamePreferenceKey{
    if (fontNamePreferenceKey != newFontNamePreferenceKey) {
        [self removeObserverForFontPreferences];
        [fontNamePreferenceKey release];
        fontNamePreferenceKey = [newFontNamePreferenceKey retain];
        [self addObserverForFontPreferences];
        [self tableViewFontChanged];
    }
}

- (NSString *)fontSizePreferenceKey{
    return fontSizePreferenceKey;
}

- (void)setFontSizePreferenceKey:(NSString *)newFontSizePreferenceKey{
    if (fontSizePreferenceKey != newFontSizePreferenceKey) {
        [self removeObserverForFontPreferences];
        [fontSizePreferenceKey release];
        fontSizePreferenceKey = [newFontSizePreferenceKey retain];
        [self addObserverForFontPreferences];
        [self tableViewFontChanged];
    }
}

- (NSControlSize)cellControlSize {
    NSCell *dataCell = [[[self tableColumns] lastObject] dataCell];
    return nil == dataCell ? NSRegularControlSize : [dataCell controlSize];
}

- (void)changeFont:(id)sender {
    NSString *fontNamePrefKey = [self fontNamePreferenceKey];
    NSString *fontSizePrefKey = [self fontSizePreferenceKey];
    if (fontNamePrefKey == nil || fontSizePrefKey == nil) 
        return;
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    
    NSString *fontName = [sud objectForKey:fontNamePrefKey];
    CGFloat fontSize = [sud floatForKey:fontSizePrefKey];
	NSFont *font = nil;
        
    if(fontName != nil)
        font = [NSFont fontWithName:fontName size:fontSize];
    if(font == nil)
        font = [NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:[self cellControlSize]]];
    font = [fontManager convertFont:font];
    
    [sud setFloat:[font pointSize] forKey:fontSizePrefKey];
    [sud setObject:[font fontName] forKey:fontNamePrefKey];
}

- (void)tableViewFontChanged {
    if (fontNamePreferenceKey && fontSizePreferenceKey) {
        NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:fontNamePreferenceKey];
        CGFloat fontSize = [[NSUserDefaults standardUserDefaults] floatForKey:fontSizePreferenceKey];
        NSFont *font = nil;
        
        if(fontName != nil)
            font = [NSFont fontWithName:fontName size:fontSize];
        if(font == nil)
            font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
        
        [self setFont:font];
        
        [self tile];
        [self reloadData]; // othewise the change isn't immediately visible
        
        [self updateFontPanel:nil];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &BDSKTableViewFontDefaultsObservationContext)
        [self tableViewFontChanged];
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)updateFontPanel:(NSNotification *)notification {
    if ([[[self window] firstResponder] isEqual:self] && fontNamePreferenceKey && fontSizePreferenceKey) {
        NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:fontNamePreferenceKey];
        CGFloat fontSize = [[NSUserDefaults standardUserDefaults] floatForKey:fontSizePreferenceKey];
        [[NSFontManager sharedFontManager] setSelectedFont:[NSFont fontWithName:fontName size:fontSize] isMultiple:NO];
    }
}

- (BOOL)becomeFirstResponder {
    BOOL success = [super becomeFirstResponder];
    if (success)
        [self updateFontPanel:nil];
    return success;
}

#pragma mark Keyboard shortcuts and actions

- (void)keyDown:(NSEvent *)theEvent {
    unichar eventChar = [theEvent firstCharacter];
    NSUInteger modifierFlags = [theEvent deviceIndependentModifierFlags];
    
	if ((eventChar == NSEnterCharacter || eventChar == NSFormFeedCharacter || eventChar == NSNewlineCharacter || eventChar == NSCarriageReturnCharacter) && (modifierFlags & ~NSFunctionKeyMask) == 0) {
        [self insertNewline:self];
    } else if (eventChar == 0x0020 && modifierFlags == 0) {
        [self insertSpace:self];
    } else if (eventChar== 0x0020 && modifierFlags == NSShiftKeyMask) {
        [self insertShiftSpace:self];
    } else if (eventChar == NSHomeFunctionKey && (modifierFlags & ~NSFunctionKeyMask) == 0) {
        [self scrollToBeginningOfDocument:self];
    } else if (eventChar == NSEndFunctionKey && (modifierFlags & ~NSFunctionKeyMask) == 0) {
        [self scrollToEndOfDocument:self];
    } else if ([typeSelectHelper processKeyDownEvent:theEvent] == NO) {
        [super keyDown:theEvent];
    }
}

- (void)invertSelection:(id)sender {
    NSIndexSet *selRows = [self selectedRowIndexes];
    if ([self allowsMultipleSelection]) {
        NSMutableIndexSet *indexesToSelect = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfRows])];
        [indexesToSelect removeIndexes:selRows];
        [self selectRowIndexes:indexesToSelect byExtendingSelection:NO];
    } else {
        NSBeep();
    }
}

- (void)moveUp:(id)sender {
    NSIndexSet *rowIndexes = [self selectedRowIndexes];
    NSUInteger row = [rowIndexes firstIndex];
    if (row == NSNotFound) { // If nothing was selected
        NSUInteger numberOfRows = [self numberOfRows];
        if (numberOfRows > 0) // If there are rows in the table
            row = numberOfRows - 1; // Select the last row
        else
            return; // There are no rows: do nothing
    } else if (row > 0) {
        row--;
    }

    if ([self delegate] && [[self delegate] respondsToSelector:@selector(tableView:shouldSelectRow:)])
        while ([[self delegate] tableView:self shouldSelectRow:row] == NO)
            if (row-- == 0)
                return;	// If we never find a selectable row, don't do anything
    
    // If the first row was selected, select only the first row.  This is consistent with the behavior of many Apple apps.
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self scrollRowToVisible:row];
}

- (void)moveDown:(id)sender {
    NSIndexSet *rowIndexes = [self selectedRowIndexes];
    NSUInteger row = [rowIndexes lastIndex], numberOfRows = [self numberOfRows];
    if (row == NSNotFound) { // If nothing was selected
        if (numberOfRows > 0) // If there are rows in the table
            row = 0; // Select the first row
        else
            return; // There are no rows: do nothing
    } else if (row < numberOfRows - 1) {
        ++row;
    }
    
    if ([self delegate] && [[self delegate] respondsToSelector:@selector(tableView:shouldSelectRow:)])
        while ([[self delegate] tableView:self shouldSelectRow:row] == NO)
            if (++row > numberOfRows - 1)
                return;	// If we never find a selectable row, don't do anything
        
    // If the first row was selected, select only the first row.  This is consistent with the behavior of many Apple apps.
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self scrollRowToVisible:row];
}

- (void)scrollToBeginningOfDocument:(id)sender {
    if ([self numberOfRows])
        [self scrollRowToVisible:0];
}

- (void)scrollToEndOfDocument:(id)sender {
    if ([self numberOfRows])
        [self scrollRowToVisible:[self numberOfRows] - 1];
}

- (void)insertNewline:(id)sender {
    if ([[self delegate] respondsToSelector:@selector(tableViewInsertNewline:)])
        [[self delegate] tableViewInsertNewline:self];
    else
        NSBeep();
}

- (void)insertSpace:(id)sender {
    if ([[self delegate] respondsToSelector:@selector(tableViewInsertSpace:)])
        [[self delegate] tableViewInsertSpace:self];
    else
        [[self enclosingScrollView] pageDown:sender];
}

- (void)insertShiftSpace:(id)sender {
    if ([[self delegate] respondsToSelector:@selector(tableViewInsertShiftSpace:)])
        [[self delegate] tableViewInsertShiftSpace:self];
    else
        [[self enclosingScrollView] pageUp:sender];
}

- (BOOL)canDelete {
    if ([self numberOfSelectedRows] == 0 || [[self dataSource] respondsToSelector:@selector(tableView:deleteRowsWithIndexes:)] == NO)
        return NO;
    else if ([[self dataSource] respondsToSelector:@selector(tableView:canDeleteRowsWithIndexes:)])
        return [[self dataSource] tableView:self canDeleteRowsWithIndexes:[self selectedRowIndexes]];
    else
        return YES;
}

- (void)delete:(id)sender {
    if ([self canDelete]) {
        NSUInteger originalNumberOfRows = [self numberOfRows];
        // -selectedRow is last row of multiple selection, no good for trying to select the row before the selection.
        NSUInteger selectedRow = [[self selectedRowIndexes] firstIndex];
        [[self dataSource] tableView:self deleteRowsWithIndexes:[self selectedRowIndexes]];
        [self reloadData];
        NSUInteger newNumberOfRows = [self numberOfRows];
        
        // Maintain an appropriate selection after deletions
        if (originalNumberOfRows != newNumberOfRows) {
            if (selectedRow == 0) {
                if ([[self delegate] respondsToSelector:@selector(tableView:shouldSelectRow:)]) {
                    if ([[self delegate] tableView:self shouldSelectRow:0])
                        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
                    else
                        [self moveDown:nil];
                } else {
                    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
                }
            } else {
                // Don't try to go past the new # of rows
                selectedRow = MIN(selectedRow - 1, newNumberOfRows - 1);
                
                // Skip all unselectable rows if the delegate responds to -tableView:shouldSelectRow:
                if ([[self delegate] respondsToSelector:@selector(tableView:shouldSelectRow:)]) {
                    while (selectedRow > 0 && [[self delegate] tableView:self shouldSelectRow:selectedRow] == NO)
                        selectedRow--;
                }
                
                // If nothing was selected, move down (so that the top row is selected)
                if (selectedRow < 0)
                    [self moveDown:nil];
                else
                    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
            }
        }
    } else
        NSBeep();
}

- (BOOL)canCopy {
    if ([self numberOfSelectedRows] == 0 || [[self dataSource] respondsToSelector:@selector(tableView:writeRowsWithIndexes:toPasteboard:)] == NO)
        return NO;
    else if ([[self dataSource] respondsToSelector:@selector(tableView:canCopyRowsWithIndexes:)])
        return [[self dataSource] tableView:self canCopyRowsWithIndexes:[self selectedRowIndexes]];
    else
        return YES;
}

- (void)copy:(id)sender {
    if ([self canCopy])
        [[self dataSource] tableView:self writeRowsWithIndexes:[self selectedRowIndexes] toPasteboard:[NSPasteboard generalPasteboard]];
    else
        NSBeep();
}

- (BOOL)canCut {
    return [self canDelete] && [self canCopy];
}

- (void)cut:(id)sender {
    if ([self canCut] && [[self dataSource] tableView:self writeRowsWithIndexes:[self selectedRowIndexes] toPasteboard:[NSPasteboard generalPasteboard]])
        [self delete:sender];
    else
        NSBeep();
}

- (BOOL)canPaste {
    if ([[self dataSource] respondsToSelector:@selector(tableView:pasteFromPasteboard:)] == NO)
        return NO;
    else if ([[self dataSource] respondsToSelector:@selector(tableViewCanPasteFromPasteboard:)])
        return [[self dataSource] tableViewCanPasteFromPasteboard:self];
    else
        return YES;
}

- (void)paste:(id)sender {
    if ([self canPaste])
        [[self dataSource] tableView:self pasteFromPasteboard:[NSPasteboard generalPasteboard]];
    else
        NSBeep();
}

- (BOOL)canDuplicate {
    if ([self numberOfSelectedRows] == 0)
        return NO;
    else if ([[self dataSource] respondsToSelector:@selector(tableView:canDuplicateRowsWithIndexes:)])
        return [[self dataSource] tableView:self canDuplicateRowsWithIndexes:[self selectedRowIndexes]];
    else if ([[self dataSource] respondsToSelector:@selector(tableView:duplicateRowsWithIndexes:)])
        return YES;
    else
        return [self canPaste] && [self canCopy];
}

- (void)duplicate:(id)sender {
    if ([self canDuplicate]) {
        if ([[self dataSource] respondsToSelector:@selector(tableView:duplicateRowsWithIndexes:)]) {
            [[self dataSource] tableView:self duplicateRowsWithIndexes:[self selectedRowIndexes]];
        } else {
            NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];
            if ([[self dataSource] tableView:self writeRowsWithIndexes:[self selectedRowIndexes] toPasteboard:pboard])
                [[self dataSource] tableView:self pasteFromPasteboard:pboard];
        }
    } else
        NSBeep();
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)flag {
    if ([[self dataSource] respondsToSelector:@selector(tableView:draggingSourceOperationMaskForLocal:)])
        return [[self dataSource] tableView:self draggingSourceOperationMaskForLocal:flag];
    else if (flag)
        return NSDragOperationEvery;
    else
        return NSDragOperationNone;        
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation {
    [super draggedImage:anImage endedAt:aPoint operation:operation];
	
    // We get NSDragOperationDelete now for dragging to the Trash.
    if (operation == NSDragOperationDelete && [draggedRowIndexes count] && [[self dataSource] respondsToSelector:@selector(tableView:deleteRowsWithIndexes:)] &&
        ([[self dataSource] respondsToSelector:@selector(tableView:canDeleteRowsWithIndexes:)] == NO || [[self dataSource] tableView:self canDeleteRowsWithIndexes:draggedRowIndexes])) {
        [[self dataSource] tableView:self deleteRowsWithIndexes:draggedRowIndexes];
        [self reloadData];
    }
    [draggedRowIndexes release];
    draggedRowIndexes = nil;
            
    if([[self dataSource] respondsToSelector:@selector(tableView:concludeDragOperation:)]) 
		[[self dataSource] tableView:self concludeDragOperation:operation];
    
    // flag changes during a drag are not forwarded to the application, so we fix that at the end of the drag
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKFlagsChangedNotification object:NSApp];
}

- (NSImage *)dragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns event:(NSEvent *)dragEvent offset:(NSPointPointer)dragImageOffset{
   	[draggedRowIndexes release];
    draggedRowIndexes = [dragRows retain];
    
    if([[self dataSource] respondsToSelector:@selector(tableView:dragImageForRowsWithIndexes:)]) {
		NSImage *image = [[self dataSource] tableView:self dragImageForRowsWithIndexes:dragRows];
		if (image != nil)
			return image;
	}
    return [super dragImageForRowsWithIndexes:dragRows tableColumns:tableColumns event:dragEvent offset:dragImageOffset];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(delete:))
        return [self canDelete];
    else if ([menuItem action] == @selector(copy:))
        return [self canCopy];
    else if ([menuItem action] == @selector(cut:))
        return [self canCut];
    else if ([menuItem action] == @selector(paste:))
        return [self canPaste];
    else if ([menuItem action] == @selector(duplicate:))
        return [self canDuplicate];
    else if ([menuItem action] == @selector(selectAll:))
        return [self allowsMultipleSelection];
    else if ([menuItem action] == @selector(deselectAll:))
        return [self allowsEmptySelection];
    else if ([menuItem action] == @selector(insertNewline:))
        return [[self delegate] respondsToSelector:@selector(tableViewInsertNewline:)];
    else if ([menuItem action] == @selector(insertSpace:))
        return [[self delegate] respondsToSelector:@selector(tableViewInsertSpace:)];
    else if ([menuItem action] == @selector(insertShiftSpace:))
        return [[self delegate] respondsToSelector:@selector(tableViewInsertShiftSpace:)];
    else if ([menuItem action] == @selector(invertSelection:))
        return [self allowsMultipleSelection];
    else if ([[BDSKTableView superclass] instancesRespondToSelector:@selector(validateMenuItem:)])
        return [super validateMenuItem:menuItem];
    else
        return YES;
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *menu = nil;
    
    if ([[self delegate] respondsToSelector:@selector(tableView:menuForTableColumn:row:)]) {
        NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        NSInteger row = [self rowAtPoint:mouseLoc];
        NSInteger column = [self columnAtPoint:mouseLoc];
        if (row != -1 && column != -1) {
            if ([self isRowSelected:row] == NO && ([[self delegate] respondsToSelector:@selector(tableView:shouldSelectRow:)] == NO || [[self delegate] tableView:self shouldSelectRow:row]))
                [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            NSTableColumn *tableColumn = [[self tableColumns] objectAtIndex:column];
            menu = [[self delegate] tableView:self menuForTableColumn:tableColumn row:row];
        }
    }
    
	return menu;
}

- (NSFont *)font {
    for (NSTableColumn *tc in [self tableColumns]) {
        NSCell *cell = [tc dataCell];
        if ([cell type] == NSTextCellType)
            return [cell font];
    }
    return nil;
}

- (void)setFont:(NSFont *)font {
    for (NSTableColumn *tc in [self tableColumns]) {
        NSCell *cell = [tc dataCell];
        if ([cell type] == NSTextCellType)
            [cell setFont:font];
    }
    
    [self setRowHeight:[self rowHeightForFont:font]];
    [self noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfRows])]];
}

- (CGFloat)rowHeightForFont:(NSFont *)font {
    CGFloat rowHeight = [NSLayoutManager defaultViewLineHeightForFont:font];
    if ([self selectionHighlightStyle] == NSTableViewSelectionHighlightStyleSourceList)
        rowHeight += 2.0;
    return rowHeight;
}

#pragma mark SKTypeSelectHelper datasource protocol

- (NSArray *)typeSelectHelperSelectionItems:(BDSKTypeSelectHelper *)aTypeSelectHelper {
    if ([[self delegate] respondsToSelector:@selector(tableView:typeSelectHelperSelectionItems:)])
        return [[self delegate] tableView:self typeSelectHelperSelectionItems:aTypeSelectHelper];
    return nil;
}

- (NSUInteger)typeSelectHelperCurrentlySelectedIndex:(BDSKTypeSelectHelper *)aTypeSelectHelper {
    return [[self selectedRowIndexes] lastIndex];
}

- (void)typeSelectHelper:(BDSKTypeSelectHelper *)aTypeSelectHelper selectItemAtIndex:(NSUInteger)itemIndex {
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] byExtendingSelection:NO];
    [self scrollRowToVisible:itemIndex];
}

- (void)typeSelectHelper:(BDSKTypeSelectHelper *)aTypeSelectHelper didFailToFindMatchForSearchString:(NSString *)searchString {
    if ([[self delegate] respondsToSelector:@selector(tableView:typeSelectHelper:didFailToFindMatchForSearchString:)])
        [[self delegate] tableView:self typeSelectHelper:aTypeSelectHelper didFailToFindMatchForSearchString:searchString];
}

- (void)typeSelectHelper:(BDSKTypeSelectHelper *)aTypeSelectHelper updateSearchString:(NSString *)searchString {
    if ([[self delegate] respondsToSelector:@selector(tableView:typeSelectHelper:updateSearchString:)])
        [[self delegate] tableView:self typeSelectHelper:aTypeSelectHelper updateSearchString:searchString];
}

#pragma mark Delegate and DataSource

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
- (id <BDSKTableViewDelegate>)delegate {
    return (id <BDSKTableViewDelegate>)[super delegate];
}

- (void)setDelegate:(id <BDSKTableViewDelegate>)newDelegate {
    [super setDelegate:newDelegate];
}

- (id <BDSKTableViewDataSource>)dataSource {
    return (id <BDSKTableViewDataSource>)[super dataSource];
}

- (void)setDataSource:(id <BDSKTableViewDataSource>)newDataSource {
    [super setDataSource:newDataSource];
}
#endif

@end

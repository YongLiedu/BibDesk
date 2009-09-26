// BDSKMainTableView.m

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

#import "BDSKMainTableView.h"
#import "BDSKStringConstants.h"
#import "BibDocument.h"
#import "BibDocument_Actions.h"
#import "BDSKTypeSelectHelper.h"
#import "NSTableView_BDSKExtensions.h"
#import "NSString_BDSKExtensions.h"
#import "BDSKFieldSheetController.h"
#import "BDSKTypeManager.h"
#import "BDSKRatingButtonCell.h"
#import "BDSKImagePopUpButton.h"
#import "BDSKImagePopUpButtonCell.h"
#import "NSObject_BDSKExtensions.h"
#import "NSBezierPath_BDSKExtensions.h"
#import "NSBezierPath_CoreImageExtensions.h"
#import "BDSKCenterScaledImageCell.h"
#import "BDSKLevelIndicatorCell.h"
#import <QuartzCore/QuartzCore.h>
#import "BDSKTextWithIconCell.h"
#import "NSImage_BDSKExtensions.h"
#import "NSParagraphStyle_BDSKExtensions.h"
#import "NSMenu_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"

enum {
    BDSKColumnTypeText,
    BDSKColumnTypeURL,
    BDSKColumnTypeLinkedFile,
    BDSKColumnTypeRating,
    BDSKColumnTypeBoolean,
    BDSKColumnTypeTriState,
    BDSKColumnTypeCrossref,
    BDSKColumnTypeImportOrder,
    BDSKColumnTypeRelevance,
    BDSKColumnTypeColor
};

@interface BDSKTableColumn : NSTableColumn {
    NSInteger columnType;
}
- (NSInteger)columnType;
- (void)setColumnType:(NSInteger)type;
@end

@interface BDSKMainTableHeaderView : NSTableHeaderView {
    NSInteger columnForMenu;
}
- (NSInteger)columnForMenu;
@end

@interface BDSKMainTableView (Private)

- (NSImage *)headerImageForField:(NSString *)field;
- (NSString *)headerTitleForField:(NSString *)field;
- (void)columnsMenuSelectTableColumn:(id)sender;
- (void)columnsMenuAddTableColumn:(id)sender;
- (void)addColumnSheetDidEnd:(BDSKAddFieldSheetController *)addFieldController returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)updateColumnsMenu;
- (IBAction)importItem:(id)sender;
- (IBAction)openParentItem:(id)sender;
- (void)autosizeColumn:(id)sender;
- (void)autosizeAllColumns:(id)sender;
@end

@implementation BDSKMainTableView

+ (BOOL)shouldQueueTypeSelectHelper { return YES; }

+ (NSImage *)cornerColumnsImage {
    static NSImage *cornerColumnsImage = nil;
    if (cornerColumnsImage == nil) {
        cornerColumnsImage = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 17.0)];
        [cornerColumnsImage lockFocus];
        NSCell *cell = [[[NSTableHeaderCell alloc] initTextCell:@""] autorelease];
        [cell drawWithFrame:NSMakeRect(0.0, 0.0, 16.0, 17.0) inView:nil];
        [cell drawWithFrame:NSMakeRect(0.0, 0.0, 1.0, 17.0) inView:nil];
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(7.0, 5.5)];
        [path lineToPoint:NSMakePoint(3.5, 5.5)];
        [path lineToPoint:NSMakePoint(3.5, 12.5)];
        [path lineToPoint:NSMakePoint(11.5, 12.5)];
        [path lineToPoint:NSMakePoint(11.5, 8.0)];
        [path moveToPoint:NSMakePoint(3.0, 10.5)];
        [path lineToPoint:NSMakePoint(12.0, 10.5)];
        [path moveToPoint:NSMakePoint(7.5, 8.0)];
        [path lineToPoint:NSMakePoint(7.5, 13.0)];
        [[NSColor colorWithDeviceWhite:0.38 alpha:1.0] set];
        [path stroke];
        path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(7.5, 7.0)];
        [path lineToPoint:NSMakePoint(13.5, 7.0)];
        [path lineToPoint:NSMakePoint(10.5, 3.5)];
        [path fill];
        [cornerColumnsImage unlockFocus];
    }
    return cornerColumnsImage;
}

- (void)awakeFromNib{
	[self setHeaderView:[[[BDSKMainTableHeaderView alloc] initWithFrame:[[self headerView] frame]] autorelease]];	
    NSRect cornerViewFrame = [[self cornerView] frame];
    BDSKImagePopUpButton *cornerViewButton = [[BDSKImagePopUpButton alloc] initWithFrame:cornerViewFrame];
    [cornerViewButton setPullsDown:YES];
    [cornerViewButton setIconSize:cornerViewFrame.size];
    [cornerViewButton setIcon:[[self class] cornerColumnsImage]];
    [[cornerViewButton cell] setArrowPosition:NSPopUpNoArrow];
    [[cornerViewButton cell] setAltersStateOfSelectedItem:NO];
    [[cornerViewButton cell] setUsesItemFromMenu:NO];
    [self setCornerView:cornerViewButton];
    [cornerViewButton release];
    
    BDSKTypeSelectHelper *aTypeSelectHelper = [[BDSKTypeSelectHelper alloc] init];
    [aTypeSelectHelper setCyclesSimilarResults:YES];
    [aTypeSelectHelper setMatchesPrefix:NO];
    [self setTypeSelectHelper:aTypeSelectHelper];
    [aTypeSelectHelper release];
}

- (void)dealloc{
    [alternatingRowBackgroundColors release];
    [super dealloc];
}

- (BOOL)canAlternateDelete {
    if ([self numberOfSelectedRows] == 0 || [[self dataSource] respondsToSelector:@selector(tableView:alternateDeleteRowsWithIndexes:)] == NO)
        return NO;
    else if ([[self dataSource] respondsToSelector:@selector(tableView:canAlternateDeleteRowsWithIndexes:)])
        return [[self dataSource] tableView:self canAlternateDeleteRowsWithIndexes:[self selectedRowIndexes]];
    else
        return YES;
}

- (void)alternateDelete:(id)sender {
    if ([self canDelete]) {
        NSUInteger originalNumberOfRows = [self numberOfRows];
        // -selectedRow is last row of multiple selection, no good for trying to select the row before the selection.
        NSUInteger selectedRow = [[self selectedRowIndexes] firstIndex];
        [[self dataSource] tableView:self alternateDeleteRowsWithIndexes:[self selectedRowIndexes]];
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

- (BOOL)canAlternateCut {
    return [self canAlternateDelete] && [self canCopy];
}

- (void)alternateCut:(id)sender {
    if ([self canAlternateCut] && [[self dataSource] tableView:self writeRowsWithIndexes:[self selectedRowIndexes] toPasteboard:[NSPasteboard generalPasteboard]])
        [self alternateDelete:sender];
    else
        NSBeep();
}

- (void)highlightSelectionInClipRect:(NSRect)clipRect{
    [super highlightSelectionInClipRect:clipRect];
    
    if ([[self delegate] respondsToSelector:@selector(tableView:highlightColorForRow:)]) {
        NSRange visibleRows = [self rowsInRect:clipRect];
        NSUInteger row;
        NSColor *color;
        NSRect ignored, rect;
        for (row = visibleRows.location; row < NSMaxRange(visibleRows); row++) {
            if (color = [[self delegate] tableView:self highlightColorForRow:row]) {
                [NSGraphicsContext saveGraphicsState];
                [color set];
                NSDivideRect([self rectOfRow:row], &ignored, &rect, 1.0, NSMaxYEdge);
                if ([self isRowSelected:row]) {
                    [NSBezierPath setDefaultLineWidth:2.0];
                    [NSBezierPath strokeHorizontalOvalInRect:NSInsetRect(rect, 2.0, 1.0)];
                    [NSBezierPath setDefaultLineWidth:1.0];
                } else {
                    [NSBezierPath fillHorizontalOvalInRect:NSInsetRect(rect, 1.0, 0.0)];
                }
                [NSGraphicsContext restoreGraphicsState];
            }
        }
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(alternateDelete:))
        return [self canAlternateDelete];
    else if ([menuItem action] == @selector(alternateCut:))
        return [self canAlternateCut];
    else
        return [super validateMenuItem:menuItem];
}

#pragma mark Alternating row color

- (void)setAlternatingRowBackgroundColors:(NSArray *)colorArray{
    if (alternatingRowBackgroundColors != colorArray) {
        [alternatingRowBackgroundColors release];
        alternatingRowBackgroundColors = [colorArray retain];
        [self setNeedsDisplay:YES];
    }
}

- (NSArray *)alternatingRowBackgroundColors{
    if (alternatingRowBackgroundColors == nil)
        alternatingRowBackgroundColors = [[NSColor controlAlternatingRowBackgroundColors] retain];
    return alternatingRowBackgroundColors;
}

// override this private method
- (NSArray *)_alternatingRowBackgroundColors{
    return [self alternatingRowBackgroundColors];
}

#pragma mark TableColumn setup

- (NSInteger)columnTypeForField:(NSString *)colName {
    NSInteger type = 0;
    if([colName isURLField])
        type = BDSKColumnTypeURL;
    else if([colName isEqualToString:BDSKLocalFileString] || [colName isEqualToString:BDSKRemoteURLString])
        type = BDSKColumnTypeLinkedFile;
    else if([colName isRatingField])
        type = BDSKColumnTypeRating;
    else if([colName isBooleanField])
        type = BDSKColumnTypeBoolean;
    else if([colName isTriStateField])
        type = BDSKColumnTypeTriState;
    else if ([colName isEqualToString:BDSKCrossrefString]) 
        type = BDSKColumnTypeCrossref;
    else if ([colName isEqualToString:BDSKImportOrderString])
        type = BDSKColumnTypeImportOrder;
    else if ([colName isEqualToString:BDSKRelevanceString])
        type = BDSKColumnTypeRelevance;
    else if ([colName isEqualToString:BDSKColorString] || [colName isEqualToString:BDSKColorLabelString])
        type = BDSKColumnTypeColor;
    else
        type = BDSKColumnTypeText;
    return type;
}

- (id)dataCellForColumnType:(NSInteger)columnType {
    id cell = nil;
    
    switch(columnType) {
        case BDSKColumnTypeURL:
            cell = [[[BDSKCenterScaledImageCell alloc] init] autorelease];
            break;
        case BDSKColumnTypeLinkedFile:
            cell = [[[BDSKTextWithIconCell alloc] init] autorelease];
            [cell setLineBreakMode:NSLineBreakByClipping];
            break;
        case BDSKColumnTypeRating:
            cell = [[[BDSKRatingButtonCell alloc] initWithMaxRating:5] autorelease];
            [cell setBordered:NO];
            [cell setAlignment:NSCenterTextAlignment];
            break;
        case BDSKColumnTypeBoolean:
            cell = [[[NSButtonCell alloc] initTextCell:@""] autorelease];
            [cell setButtonType:NSSwitchButton];
            [cell setImagePosition:NSImageOnly];
            [cell setControlSize:NSSmallControlSize];
            [cell setAllowsMixedState:NO];
            break;
        case BDSKColumnTypeTriState:
            cell = [[[NSButtonCell alloc] initTextCell:@""] autorelease];
            [cell setButtonType:NSSwitchButton];
            [cell setImagePosition:NSImageOnly];
            [cell setControlSize:NSSmallControlSize];
            [cell setAllowsMixedState:YES];
            break;
        case BDSKColumnTypeCrossref: 
            cell = [[[NSButtonCell alloc] initTextCell:@""] autorelease];
            [cell setButtonType:NSMomentaryChangeButton];
            [cell setBordered:NO];
            [cell setImagePosition:NSImageOnly];
            [cell setControlSize:NSSmallControlSize];
            [cell setImage:[NSImage arrowImage]];
            [cell setAction:@selector(openParentItem:)];
            [cell setTarget:self];
            break;
        case BDSKColumnTypeImportOrder:
            cell = [[[BDSKRoundRectButtonCell alloc] initTextCell:NSLocalizedString(@"Import", @"button title")] autorelease];
            [cell setImagePosition:NSNoImage];
            [cell setControlSize:NSSmallControlSize];
            [cell setAction:@selector(importItem:)];
            [cell setTarget:self];
            break;
        case BDSKColumnTypeRelevance: 
            cell = [[[BDSKLevelIndicatorCell alloc] initWithLevelIndicatorStyle:NSRelevancyLevelIndicatorStyle] autorelease];
            [cell setMaxValue:(double)1.0];
            [cell setEnabled:NO];
            [(BDSKLevelIndicatorCell *)cell setMaxHeight:(17.0 * 0.7)];
            break;
        case BDSKColumnTypeColor: 
            cell = [[[BDSKColorCell alloc] initImageCell:nil] autorelease];
            break;
        case BDSKColumnTypeText:
        default:
            cell = [[[BDSKTextFieldCell alloc] initTextCell:@""] autorelease];
            [cell setBordered:NO];
            [cell setLineBreakMode:NSLineBreakByTruncatingTail];
            break;
    }
    
    return cell;
}

- (NSTableColumn *)configuredTableColumnForField:(NSString *)colName {
    BDSKTableColumn *tc = (BDSKTableColumn *)[self tableColumnWithIdentifier:colName];
    id dataCell = [tc dataCell];
    NSInteger columnType = [self columnTypeForField:colName];
    
    if(tc == nil){
        // it is a new column, so create it
        tc = [[[BDSKTableColumn alloc] initWithIdentifier:colName] autorelease];
        [tc setResizingMask:(NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask)];
        [tc setEditable:NO];
        [tc setMinWidth:16.0];
        [tc setMaxWidth:1000.0];
    }
    
    // this may be called in response to a field type change, so the cell may also need to change, even if the column is already in the tableview
    if (dataCell == nil || [tc columnType] != columnType) {
        dataCell = [self dataCellForColumnType:columnType];
        [tc setDataCell:dataCell];
        [tc setColumnType:columnType];
    }

    NSImage *image;
    NSString *title;
    id headerCell = [tc headerCell];
    if(image = [self headerImageForField:colName])
        [headerCell setImage:image];
    else if(title = [self headerTitleForField:colName])
        [headerCell setStringValue:title];
    else
        [headerCell setStringValue:[[NSBundle mainBundle] localizedStringForKey:colName value:@"" table:@"BibTeXKeys"]];
    
    if (columnType != BDSKColumnTypeText && columnType != BDSKColumnTypeLinkedFile && columnType != BDSKColumnTypeRelevance)
        [tc setWidth:BDSKMax([dataCell cellSize].width, [headerCell cellSize].width)];
    
    return tc;
}

- (void)setupTableColumnsWithIdentifiers:(NSArray *)identifiers {
    
    NSEnumerator *shownColNamesE = [identifiers objectEnumerator];
    NSTableColumn *tc;
    NSString *colName;
    NSNumber *tcWidth;
    
    NSDictionary *defaultTableColumnWidths = nil;
    if([[self delegate] respondsToSelector:@selector(defaultColumnWidthsForTableView:)])
        defaultTableColumnWidths = [[self delegate] defaultColumnWidthsForTableView:self];
    
    NSMutableArray *columns = [NSMutableArray arrayWithCapacity:[identifiers count]];
	
	while(colName = [shownColNamesE nextObject]){
		tc = [self configuredTableColumnForField:colName];
        
        if([colName isEqualToString:BDSKImportOrderString] == NO && (tcWidth = [defaultTableColumnWidths objectForKey:colName]))
            [tc setWidth:[tcWidth floatValue]];
		
		[columns addObject:tc];
	}
    
    NSTableColumn *highlightedColumn = [self highlightedTableColumn];
    if([columns containsObject:highlightedColumn] == NO)
        highlightedColumn = nil;
	NSIndexSet *selectedRows = [self selectedRowIndexes];
    
    [self removeAllTableColumns];
    [self performSelector:@selector(addTableColumn:) withObjectsFromArray:columns];
    [self selectRowIndexes:selectedRows byExtendingSelection:NO];
    [self setHighlightedTableColumn:highlightedColumn]; 
    [self tableViewFontChanged];
    [self updateColumnsMenu];
}

- (void)insertTableColumnWithIdentifier:(NSString *)identifier atIndex:(NSUInteger)idx {
    NSMutableArray *shownColumns = [NSMutableArray arrayWithArray:[self tableColumnIdentifiers]];
    NSUInteger oldIndex = [shownColumns indexOfObject:identifier];
    
    // Check if an object already exists in the tableview, remove the old one if it does
    // This means we can't have a column more than once.
    if (oldIndex != NSNotFound) {
        if (idx > oldIndex)
            idx--;
        else if (oldIndex == idx)
            return;
        [shownColumns removeObject:identifier];
    }
    
    [shownColumns insertObject:identifier atIndex:idx];
    
    [self setupTableColumnsWithIdentifiers:shownColumns];
}

- (void)removeTableColumnWithIdentifier:(NSString *)identifier {
    NSMutableArray *shownColumns = [NSMutableArray arrayWithArray:[self tableColumnIdentifiers]];

    // Check if an object already exists in the tableview.
    if ([shownColumns containsObject:identifier] == NO)
        return;
    
    [shownColumns removeObject:identifier];
    
    [self setupTableColumnsWithIdentifiers:shownColumns];
}

- (NSMenu *)columnsMenu{
    NSMenu *menu = [[[self headerView] menu] copy];
    if(menu == nil){
        [self updateColumnsMenu];
        menu = [[[self headerView] menu] copy];
    }
    [menu removeItem:[menu itemWithAction:@selector(autosizeColumn:)]];
    return [menu autorelease];
}

#pragma mark Convenience methods

- (void)removeAllTableColumns {
    while ([self numberOfColumns] > 0)
        [self removeTableColumn:[[self tableColumns] objectAtIndex:0]];
}

- (NSArray *)tableColumnIdentifiers { return [[self tableColumns] valueForKey:@"identifier"]; }

// copied from -[NSTableView (OAExtensions) scrollSelectedRowsToVisibility:]
- (void)scrollRowToCenter:(NSUInteger)row;
{
    NSRect rowRect = [self rectOfRow:row];
    
    if (NSEqualRects(rowRect, NSZeroRect))
        return;
    
    NSRect visibleRect;
    CGFloat heightDifference;
    
    visibleRect = [self visibleRect];
    
    // don't change the scroll position if it's already in view, since that would be unexpected
    if (NSContainsRect(visibleRect, rowRect))
        return;
    
    heightDifference = NSHeight(visibleRect) - NSHeight(rowRect);
    if (heightDifference > 0) {
        // scroll to a rect equal in height to the visible rect but centered on the selected rect
        rowRect = NSInsetRect(rowRect, 0.0, -(heightDifference / 2.0));
    } else {
        // force the top of the selectionRect to the top of the view
        rowRect.size.height = NSHeight(visibleRect);
    }
    [self scrollRectToVisible:rowRect];
}

@end


@implementation BDSKMainTableView (Private)

- (NSImage *)headerImageForField:(NSString *)field {
	static NSDictionary *headerImageCache = nil;
	
	if (headerImageCache == nil) {
		NSDictionary *paths = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKTableHeaderImagesKey];
        NSImage *paperclip = [[[NSImage paperclipImage] copy] autorelease];
        [paperclip setScalesWhenResized:YES];
        [paperclip setSize:NSMakeSize(16, 16)];
        if ([paperclip respondsToSelector:@selector(setTemplate:)])
            [paperclip setTemplate:NO];
        NSImage *color = [[[NSImage imageNamed:@"colors"] copy] autorelease];
        [color setScalesWhenResized:YES];
        [color setSize:NSMakeSize(16, 16)];
		NSMutableDictionary *tmpDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSImage imageNamed:@"TinyFile"], BDSKLocalUrlString, paperclip, BDSKLocalFileString, [NSImage arrowImage], BDSKCrossrefString, color, BDSKColorString, color, BDSKColorLabelString, nil];
		if (paths) {
			NSEnumerator *keyEnum = [paths keyEnumerator];
			NSString *key, *path;
			NSImage *image;
			
			while (key = [keyEnum nextObject]) {
				path = [paths objectForKey:key];
				if ([[NSFileManager defaultManager] fileExistsAtPath:path] &&
					(image = [[NSImage alloc] initWithContentsOfFile:path])) {
					[tmpDict setObject:image forKey:key];
					[image release];
				}
			}
		}
        headerImageCache = [tmpDict copy];
        [tmpDict release];
	}
	
	return [headerImageCache objectForKey:field];
}

- (NSString *)headerTitleForField:(NSString *)field {
	static NSDictionary *headerTitleCache = nil;
	
	if (headerTitleCache == nil) {
        NSMutableDictionary *tmpDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@"@", BDSKUrlString, @"@", BDSKRemoteURLString, @"#", BDSKItemNumberString, @"#", BDSKImportOrderString, nil];
		[tmpDict addEntriesFromDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:BDSKTableHeaderTitlesKey]];
        headerTitleCache = [tmpDict copy];
        [tmpDict release];
	}
	
	return [headerTitleCache objectForKey:field];
}

- (void)columnsMenuSelectTableColumn:(id)sender{
    if ([sender state] == NSOnState)
        [self removeTableColumnWithIdentifier:[sender representedObject]];
    else
        [self insertTableColumnWithIdentifier:[sender representedObject] atIndex:[self numberOfColumns]];
}

- (void)addColumnSheetDidEnd:(BDSKAddFieldSheetController *)addFieldController returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    NSString *newColumnName = [addFieldController field];
    
    if(newColumnName && returnCode == NSOKButton)
        [self insertTableColumnWithIdentifier:newColumnName atIndex:[self numberOfColumns]];
}

- (void)columnsMenuAddTableColumn:(id)sender{
    // first we fill the popup
	BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
    NSArray *colNames = [typeMan allFieldNamesIncluding:[NSArray arrayWithObjects:BDSKPubTypeString, BDSKCiteKeyString, BDSKPubDateString, BDSKDateAddedString, BDSKDateModifiedString, BDSKFirstAuthorString, BDSKSecondAuthorString, BDSKThirdAuthorString, BDSKLastAuthorString, BDSKFirstAuthorEditorString, BDSKSecondAuthorEditorString, BDSKThirdAuthorEditorString, BDSKAuthorEditorString, BDSKLastAuthorEditorString, BDSKItemNumberString, BDSKContainerString, BDSKCrossrefString, BDSKLocalFileString, BDSKRemoteURLString, BDSKColorLabelString, nil]
                                              excluding:[self tableColumnIdentifiers]];
    
    BDSKAddFieldSheetController *addFieldController = [[BDSKAddFieldSheetController alloc] initWithPrompt:NSLocalizedString(@"Name of column to add:", @"Label for adding column")
                                                                                              fieldsArray:colNames];
	[addFieldController beginSheetModalForWindow:[self window]
                                   modalDelegate:self
                                  didEndSelector:@selector(addColumnSheetDidEnd:returnCode:contextInfo:)
                                     contextInfo:NULL];
    [addFieldController release];
}

- (void)updateColumnsMenu{
    NSArray *shownColumns = [self tableColumnIdentifiers];
    NSEnumerator *shownColNamesE = [shownColumns reverseObjectEnumerator];
	NSString *colName;
	NSMenuItem *item = nil;
    NSMenu *menu = [[self headerView] menu];
    
    if(menu == nil){
        menu = [[NSMenu allocWithZone:[NSMenu menuZone]] init];
        [menu addItem:[NSMenuItem separatorItem]];
        item = [menu addItemWithTitle:[NSLocalizedString(@"Add Other", @"Menu title") stringByAppendingEllipsis]
                               action:@selector(columnsMenuAddTableColumn:)
                        keyEquivalent:@""];
		[item setTarget:self];
        [menu addItem:[NSMenuItem separatorItem]];
        item = [menu addItemWithTitle:NSLocalizedString(@"Autosize Column", @"Menu title")
                               action:@selector(autosizeColumn:)
                        keyEquivalent:@""];
		[item setTarget:self];
        item = [menu addItemWithTitle:NSLocalizedString(@"Autosize All Columns", @"Menu title")
                               action:@selector(autosizeAllColumns:)
                        keyEquivalent:@""];
		[item setTarget:self];
        [[self headerView] setMenu:menu];
        [menu release];
    }
	
    while([[menu itemAtIndex:0] isSeparatorItem] == NO)
        [menu removeItemAtIndex:0];
    
	// next add all the shown columns in the order they are shown
	while(colName = [shownColNamesE nextObject]){
        item = [menu insertItemWithTitle:[colName localizedFieldName]
                                  action:@selector(columnsMenuSelectTableColumn:)
                           keyEquivalent:@""
                                 atIndex:0];
		[item setRepresentedObject:colName];
		[item setTarget:self];
		[item setState:NSOnState];
	}
    
	if([[self cornerView] isKindOfClass:[BDSKImagePopUpButton class]] && menu != nil) {
        menu = [self columnsMenu]; // this is already a copy
        [menu insertItemWithTitle:@"" action:NULL keyEquivalent:@"" atIndex:0];
        [(BDSKImagePopUpButton *)[self cornerView] setMenu:menu];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem{
	SEL action = [menuItem action];
	if (action == @selector(columnsMenuSelectTableColumn:))
		return ([[menuItem representedObject] isEqualToString:BDSKImportOrderString] == NO && [[menuItem representedObject] isEqualToString:BDSKRelevanceString] == NO && [self numberOfColumns] > 1);
	else if (action == @selector(columnsMenuAddTableColumn:))
        return YES;
	else
        return [super validateMenuItem:menuItem];
}

// override private method from OmniAppKit/NSTableView-OAColumnConfigurationExtensions
- (BOOL)_allowsAutoresizing{
    return YES;
}

- (void)importItem:(id)sender {
    NSInteger row = [self clickedRow];
    BDSKASSERT(row != -1);
    if (row == -1)
        return;
    if([[self delegate] respondsToSelector:@selector(tableView:importItemAtRow:)])
        [[self delegate] tableView:self importItemAtRow:row];
}

- (void)openParentItem:(id)sender {
    NSInteger row = [self clickedRow];
    BDSKASSERT(row != -1);
    if (row == -1)
        return;
    if([[self delegate] respondsToSelector:@selector(tableView:openParentForItemAtRow:)])
        [[self delegate] tableView:self openParentForItemAtRow:row];
}

- (void)doAutosizeColumn:(NSUInteger)column {
    NSInteger row, numRows = [self numberOfRows];
    NSTableColumn *tableColumn = [[self tableColumns] objectAtIndex:column];
    id cell;
    CGFloat width = 0.0;
    
    for (row = 0; row < numRows; row++) {
        if ([self respondsToSelector:@selector(preparedCellAtColumn:row:)]) {
            cell = [self preparedCellAtColumn:column row:row];
        } else {
            cell = [tableColumn dataCellForRow:row];
            if ([[self delegate] respondsToSelector:@selector(tableView:willDisplayCell:forTableColumn:row:)])
                [[self delegate] tableView:self willDisplayCell:cell forTableColumn:tableColumn row:row];
            [cell setObjectValue:[[self dataSource] tableView:self objectValueForTableColumn:tableColumn row:row]];
        }
        width = BDSKMax(width, [cell cellSize].width);
    }
    width = BDSKMin([tableColumn maxWidth], BDSKMax([tableColumn minWidth], width));
    [tableColumn setWidth:width];
}

- (void)autosizeColumn:(id)sender {
    NSInteger clickedColumn = [(BDSKMainTableHeaderView *)[self headerView] columnForMenu];
    if (clickedColumn >= 0)
        [self doAutosizeColumn:clickedColumn];
}

- (void)autosizeAllColumns:(id)sender {
    NSUInteger column, numColumns = [self numberOfColumns];
    for (column = 0; column < numColumns; column++)
        [self doAutosizeColumn:column];
}

@end


@implementation BDSKTableColumn

- (NSInteger)columnType { return columnType; }

- (void)setColumnType:(NSInteger)type { columnType = type; }

@end

#pragma mark -

@implementation BDSKRoundRectButtonCell

- (id)initTextCell:(NSString *)aString {
    if (self = [super initTextCell:aString]) {
        [self setButtonType:NSMomentaryPushInButton];
        [self setBezelStyle:NSRoundRectBezelStyle];
    }
    return self;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView{
    CGFloat startWhite = [self isHighlighted] ? 0.9 : 1.0;
    CGFloat endWhite = [self isHighlighted] ? 0.95 : 0.9;
    CGFloat alpha = [self isEnabled] ? 1.0 : 0.6;
    NSRect rect = cellFrame;
    rect.size.height -= 1.0;
    rect = NSInsetRect(rect, 0.0, 0.5);
    NSBezierPath *path = [NSBezierPath bezierPathWithHorizontalOvalInRect:rect];

    [path fillPathVerticallyWithStartColor:[CIColor colorWithRed:startWhite green:startWhite blue:startWhite alpha:alpha] endColor:[CIColor colorWithRed:endWhite green:endWhite blue:endWhite alpha:alpha]];
    [[NSColor colorWithCalibratedWhite:0.8 alpha:alpha] set];
    [path stroke];
    [super drawInteriorWithFrame:cellFrame inView:controlView];
}

@end

#pragma mark -

@implementation BDSKTextFieldCell

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    return nil;
}

// Tiger inverts the text color based on the highlight color, which is lame
- (NSColor *)textColor {
    if ([self respondsToSelector:@selector(backgroundStyle)] == NO && [self isHighlighted] && 
        [[[self controlView] window] isKeyWindow] && [[[[self controlView] window] firstResponder] isEqual:[self controlView]])
        return [NSColor textBackgroundColor];
    return [super textColor];
}

@end

#pragma mark -

@implementation BDSKColorCell

- (NSSize)cellSize {
    return NSMakeSize(16.0, 16.0);
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSColor *color = [self objectValue];
    if ([color respondsToSelector:@selector(drawSwatchInRect:)]) {
        NSRect rect, ignored;
        NSDivideRect(cellFrame, &ignored, &rect, 1.0, [controlView isFlipped] ? NSMaxYEdge : NSMinYEdge);
        [color drawSwatchInRect:rect];
    }
}

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    return nil;
}

@end

#pragma mark -

@implementation BDSKMainTableHeaderView 

- (id)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        columnForMenu = -1;
    }
    return self;
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *menu = [super menuForEvent:theEvent];
    NSPoint clickPoint = [self convertPoint:[[NSApp currentEvent] locationInWindow] fromView:nil];
    columnForMenu = [self columnAtPoint:clickPoint];
    return menu;
}

- (NSInteger)columnForMenu {
    return columnForMenu;
}

@end

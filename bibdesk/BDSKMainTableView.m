// BDSKMainTableView.m

/*
 This software is Copyright (c) 2002-2016
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
#import "NSBezierPath_BDSKExtensions.h"
#import "BDSKLevelIndicatorCell.h"
#import <QuartzCore/QuartzCore.h>
#import "BDSKTextWithIconCell.h"
#import "NSImage_BDSKExtensions.h"
#import "NSParagraphStyle_BDSKExtensions.h"
#import "NSMenu_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "NSGeometry_BDSKExtensions.h"

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

@interface BDSKMainTableHeaderView : NSTableHeaderView
@end

@interface BDSKMainTableView (Private)

- (NSImage *)headerImageForField:(NSString *)field;
- (NSString *)headerTitleForField:(NSString *)field;
- (void)updateTableColumnDefaults;
- (void)columnsMenuSelectTableColumn:(id)sender;
- (void)columnsMenuAddTableColumn:(id)sender;
- (void)updateColumnsMenuUpdatingButton:(BOOL)updateButton;
- (void)tableColumnDidMove:(NSNotification *)note;
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
        NSView *view = nil;
        cornerColumnsImage = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 17.0)];
        [cornerColumnsImage lockFocus];
        NSCell *cell = [[[NSTableHeaderCell alloc] initTextCell:@""] autorelease];
        [cell drawWithFrame:NSMakeRect(0.0, 0.0, 16.0, 17.0) inView:view];
        [cell drawWithFrame:NSMakeRect(0.0, 0.0, 1.0, 17.0) inView:view];
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

- (void)commonInit{
    lastMouseDownRow = -1;
    lastMouseDownColumn = -1;
    
	[self setHeaderView:[[[BDSKMainTableHeaderView alloc] initWithFrame:[[self headerView] frame]] autorelease]];
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_6) {
        BDSKImagePopUpButton *cornerViewButton = [[BDSKImagePopUpButton alloc] init];
        [cornerViewButton setPullsDown:YES];
        [[cornerViewButton cell] setArrowPosition:NSPopUpNoArrow];
        [[cornerViewButton cell] setAltersStateOfSelectedItem:NO];
        [self setCornerView:cornerViewButton];
        [cornerViewButton release];
    }
    
    BDSKTypeSelectHelper *aTypeSelectHelper = [[BDSKTypeSelectHelper alloc] init];
    [aTypeSelectHelper setCyclesSimilarResults:YES];
    [aTypeSelectHelper setMatchesPrefix:NO];
    [self setTypeSelectHelper:aTypeSelectHelper];
    [aTypeSelectHelper release];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tableColumnDidMove:) name:NSTableViewColumnDidMoveNotification object:self];
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    BDSKDESTROY(alternatingRowBackgroundColors);
    [super dealloc];
}

- (void)mouseDown:(NSEvent *)theEvent {
    NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    lastMouseDownRow = [self rowAtPoint:point];
    lastMouseDownColumn = [self columnAtPoint:point];
    [super mouseDown:theEvent];
}

- (NSInteger)lastMouseDownRow {
    return lastMouseDownRow;
}

- (NSInteger)lastMouseDownColumn {
    return lastMouseDownColumn;
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
        NSInteger selectedRow = [[self selectedRowIndexes] firstIndex];
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
                selectedRow = MIN((NSUInteger)selectedRow - 1, newNumberOfRows - 1);
                
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

- (void)drawRow:(NSInteger)row clipRect:(NSRect)clipRect {
    if ([[self delegate] respondsToSelector:@selector(tableView:highlightColorForRow:)]) {
        NSColor *color = [[self delegate] tableView:self highlightColorForRow:row];
        if (color) {
            NSRect rect = BDSKShrinkRect(BDSKShrinkRect([self rectOfRow:row], 2.0, NSMaxYEdge), 1.0, NSMinYEdge);
            if (NSIntersectsRect(clipRect, rect)) {
                [NSGraphicsContext saveGraphicsState];
                [color set];
                if ([self isRowSelected:row]) {
                    [NSBezierPath setDefaultLineWidth:2.0];
                    [NSBezierPath strokeHorizontalOvalInRect:NSInsetRect(rect, 1.0, 1.0)];
                    [NSBezierPath setDefaultLineWidth:1.0];
                } else {
                    [NSBezierPath fillHorizontalOvalInRect:rect];
                }
                [NSGraphicsContext restoreGraphicsState];
            }
        }
    }
    [super drawRow:row clipRect:clipRect];
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

- (NSCell *)newDataCellForColumnType:(NSInteger)columnType {
    id cell = nil;
    
    switch(columnType) {
        case BDSKColumnTypeURL:
            cell = [[NSImageCell alloc] init];
            [cell setImageScaling:NSImageScaleProportionallyUpOrDown];
            break;
        case BDSKColumnTypeLinkedFile:
            cell = [[BDSKTextWithIconCell alloc] init];
            [cell setLineBreakMode:NSLineBreakByClipping];
            break;
        case BDSKColumnTypeRating:
            cell = [[BDSKRatingButtonCell alloc] initWithMaxRating:5];
            [cell setBordered:NO];
            [cell setAlignment:NSCenterTextAlignment];
            break;
        case BDSKColumnTypeBoolean:
            cell = [[NSButtonCell alloc] initTextCell:@""];
            [cell setButtonType:NSSwitchButton];
            [cell setImagePosition:NSImageOnly];
            [cell setControlSize:NSSmallControlSize];
            [cell setAllowsMixedState:NO];
            break;
        case BDSKColumnTypeTriState:
            cell = [[NSButtonCell alloc] initTextCell:@""];
            [cell setButtonType:NSSwitchButton];
            [cell setImagePosition:NSImageOnly];
            [cell setControlSize:NSSmallControlSize];
            [cell setAllowsMixedState:YES];
            break;
        case BDSKColumnTypeCrossref: 
            cell = [[NSButtonCell alloc] initTextCell:@""];
            [cell setButtonType:NSMomentaryChangeButton];
            [cell setBordered:NO];
            [cell setImagePosition:NSImageOnly];
            [cell setImageScaling:NSImageScaleProportionallyDown];
            [cell setControlSize:NSSmallControlSize];
            [cell setImage:[NSImage imageNamed:NSImageNameFollowLinkFreestandingTemplate]];
            [cell setAction:@selector(openParentItem:)];
            [cell setTarget:self];
            break;
        case BDSKColumnTypeImportOrder:
            cell = [[NSButtonCell alloc] initTextCell:NSLocalizedString(@"Import", @"button title")];
            [cell setButtonType:NSMomentaryPushInButton];
            [cell setBezelStyle:NSRoundRectBezelStyle];
            [cell setImagePosition:NSNoImage];
            [cell setControlSize:NSSmallControlSize];
            [cell setAction:@selector(importItem:)];
            [cell setTarget:self];
            break;
        case BDSKColumnTypeRelevance: 
            cell = [[BDSKLevelIndicatorCell alloc] initWithLevelIndicatorStyle:NSRelevancyLevelIndicatorStyle];
            [cell setMaxValue:(double)1.0];
            [cell setEnabled:NO];
            [(BDSKLevelIndicatorCell *)cell setMaxHeight:(17.0 * 0.7)];
            break;
        case BDSKColumnTypeColor: 
            cell = [[BDSKColorCell alloc] initImageCell:nil];
            break;
        case BDSKColumnTypeText:
        default:
            cell = [[BDSKTextFieldCell alloc] initTextCell:@""];
            [cell setBordered:NO];
            [cell setLineBreakMode:NSLineBreakByTruncatingTail];
            break;
    }
    
    return cell;
}

- (NSTableColumn *)newConfiguredTableColumnForField:(NSString *)identifier {
    BDSKTableColumn *tc = [[BDSKTableColumn alloc] initWithIdentifier:identifier];
    NSInteger columnType = [self columnTypeForField:identifier];
    NSCell *dataCell = [self newDataCellForColumnType:columnType];
    
    [tc setResizingMask:(NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask)];
    [tc setEditable:NO];
    [tc setMinWidth:16.0];
    [tc setMaxWidth:1000.0];
    [tc setDataCell:dataCell];
    [tc setColumnType:columnType];
    [dataCell release];

    NSTableHeaderCell *headerCell = [tc headerCell];
    NSImage *image;
    NSString *title;
    
    if ((image = [self headerImageForField:identifier]))
        [headerCell setImage:image];
    else if ((title = [self headerTitleForField:identifier]))
        [headerCell setStringValue:title];
    else
        [headerCell setStringValue:[[NSBundle mainBundle] localizedStringForKey:identifier value:@"" table:@"BibTeXKeys"]];
    
    if (columnType != BDSKColumnTypeText && columnType != BDSKColumnTypeLinkedFile && columnType != BDSKColumnTypeRelevance)
        [tc setWidth:fmax([dataCell cellSize].width, [headerCell cellSize].width)];
    
    return tc;
}

- (void)setupTableColumnsWithIdentifiers:(NSArray *)identifiers {
    NSDictionary *defaultTableColumnWidths = nil;
    if ([[self delegate] respondsToSelector:@selector(defaultColumnWidthsForTableView:)])
        defaultTableColumnWidths = [[self delegate] defaultColumnWidthsForTableView:self];
    
    while ([self numberOfColumns] > 0)
        [self removeTableColumn:[[self tableColumns] objectAtIndex:0]];
	
	for (NSString *identifier in identifiers) {
		NSTableColumn *tc = [self newConfiguredTableColumnForField:identifier];
        NSNumber *tcWidth;
        
        if ([identifier isEqualToString:BDSKImportOrderString] == NO &&
            (tcWidth = [defaultTableColumnWidths objectForKey:identifier]))
            [tc setWidth:[tcWidth doubleValue]];
		
		[self addTableColumn:tc];
        [tc release];
	}
    
    [self tableViewFontChanged];
    [self updateColumnsMenuUpdatingButton:YES];
}

- (void)updateTableColumnTypes {
    for (BDSKTableColumn *tc in [self tableColumns]) {
        NSInteger columnType = [self columnTypeForField:[tc identifier]];
        if ([tc columnType] != columnType) {
            NSCell *dataCell = [self newDataCellForColumnType:columnType];
            [tc setDataCell:dataCell];
            [tc setColumnType:columnType];
            [dataCell release];
        }
    }
    [self tableViewFontChanged];
}

- (void)addTableColumnWithIdentifier:(NSString *)identifier {
    // we don't want duplicate columns, so don't add when it's already present
    if ([self tableColumnWithIdentifier:identifier] == nil) {
        NSTableColumn *tc = [self newConfiguredTableColumnForField:identifier];
        NSNumber *tcWidth;
        
        if ([identifier isEqualToString:BDSKImportOrderString] == NO &&
            [[self delegate] respondsToSelector:@selector(defaultColumnWidthsForTableView:)] &&
            (tcWidth = [[[self delegate] defaultColumnWidthsForTableView:self] objectForKey:identifier]))
            [tc setWidth:[tcWidth doubleValue]];
        
        [self addTableColumn:tc];
        [tc release];
    }
    
    // Import Order and Relevance columns should be inserted as the first column
    if ([identifier isEqualToString:BDSKImportOrderString] || [identifier isEqualToString:BDSKRelevanceString]) {
        NSInteger i = [self columnWithIdentifier:identifier];
        if (i > 0) {
            ignoreMovedColumn = YES;
            [self moveColumn:i toColumn:0];
            ignoreMovedColumn = NO;
        }
    }
    
    [self tableViewFontChanged];
    [self updateColumnsMenuUpdatingButton:YES];
}

- (void)removeTableColumnWithIdentifier:(NSString *)identifier {
    NSTableColumn *tc = [self tableColumnWithIdentifier:identifier];
    if (tc) {
        [self removeTableColumn:tc];
        [self updateColumnsMenuUpdatingButton:YES];
    }
}

- (NSMenu *)columnsMenu{
    NSMenu *menu = [[[self headerView] menu] copy];
    if(menu == nil){
        [self updateColumnsMenuUpdatingButton:NO];
        menu = [[[self headerView] menu] copy];
    }
    [menu removeItem:[menu itemWithAction:@selector(autosizeColumn:)]];
    return [menu autorelease];
}

#pragma mark Convenience methods

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

#pragma mark Delegate and DataSource

- (id <BDSKMainTableViewDelegate>)delegate { return (id <BDSKMainTableViewDelegate>)[super delegate]; }
- (void)setDelegate:(id <BDSKMainTableViewDelegate>)newDelegate { [super setDelegate:newDelegate]; }
- (id <BDSKMainTableViewDataSource>)dataSource { return (id <BDSKMainTableViewDataSource>)[super dataSource]; }
- (void)setDataSource:(id <BDSKMainTableViewDataSource>)newDataSource { [super setDataSource:newDataSource]; }

@end


@implementation BDSKMainTableView (Private)

- (NSImage *)headerImageForField:(NSString *)field {
	static NSDictionary *headerImageCache = nil;
	
	if (headerImageCache == nil) {
		NSDictionary *paths = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKTableHeaderImagesKey];
        NSSize size = NSMakeSize(13.0, 13.0);
        NSImage *paperclip = [[[NSImage paperclipImage] copy] autorelease];
        [paperclip setSize:size];
        [paperclip setTemplate:NO];
        NSImage *url = [[[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericURLIcon)] copy] autorelease];
        [url setSize:size];
        NSImage *color = [[[NSImage imageNamed:NSImageNameColorPanel] copy] autorelease];
        [color setSize:size];
        NSImage *crossref = [[[NSImage imageNamed:NSImageNameFollowLinkFreestandingTemplate] copy] autorelease];
        [crossref setSize:size];
        NSImage *import = [[[NSImage alloc] initWithSize:NSMakeSize(13.0, 13.0)] autorelease];
        [import lockFocus];
        NSBezierPath *p = [NSBezierPath bezierPath];
        [p moveToPoint:NSMakePoint(3.0, 13.0)];
        [p lineToPoint:NSMakePoint(10.0, 13.0)];
        [p lineToPoint:NSMakePoint(10.0, 7.0)];
        [p lineToPoint:NSMakePoint(13.0, 7.0)];
        [p lineToPoint:NSMakePoint(6.5, 0.5)];
        [p lineToPoint:NSMakePoint(0.0, 7.0)];
        [p lineToPoint:NSMakePoint(3.0, 7.0)];
        [p closePath];
        [[NSColor colorWithCalibratedWhite:0.4 alpha:1.0] setFill];
        [p fill];
        [import unlockFocus];
		NSMutableDictionary *tmpDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSImage imageNamed:@"TinyFile"], BDSKLocalUrlString, paperclip, BDSKLocalFileString, url, BDSKRemoteURLString, crossref, BDSKCrossrefString, color, BDSKColorString, color, BDSKColorLabelString, import, BDSKImportOrderString, nil];
		if (paths) {
			NSImage *image;
			
			for (NSString *key in paths) {
				NSString *path = [paths objectForKey:key];
                if ([path isEqualToString:@""]) {
                    [tmpDict removeObjectForKey:key];
				} else if ([[NSFileManager defaultManager] fileExistsAtPath:path] &&
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
        NSMutableDictionary *tmpDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@"@", BDSKUrlString, @"#", BDSKItemNumberString, nil];
		[tmpDict addEntriesFromDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:BDSKTableHeaderTitlesKey]];
        headerTitleCache = [tmpDict copy];
        [tmpDict release];
	}
	
	return [headerTitleCache objectForKey:field];
}

- (void)updateTableColumnDefaults {
    NSArray *shownColumnIdentifiers = [[[self tableColumnIdentifiers] arrayByRemovingObject:BDSKImportOrderString] arrayByRemovingObject:BDSKRelevanceString];
    [[NSUserDefaults standardUserDefaults] setObject:shownColumnIdentifiers forKey:BDSKShownColsNamesKey];
}

- (void)columnsMenuSelectTableColumn:(id)sender{
    if ([sender state] == NSOnState)
        [self removeTableColumnWithIdentifier:[sender representedObject]];
    else
        [self addTableColumnWithIdentifier:[sender representedObject]];
    [self updateTableColumnDefaults];
}

- (void)columnsMenuAddTableColumn:(id)sender{
    // first we fill the popup
	BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
    NSArray *colNames = [typeMan allFieldNamesIncluding:[NSArray arrayWithObjects:BDSKPubTypeString, BDSKCiteKeyString, BDSKPubDateString, BDSKDateAddedString, BDSKDateModifiedString, BDSKFirstAuthorString, BDSKSecondAuthorString, BDSKThirdAuthorString, BDSKLastAuthorString, BDSKFirstAuthorEditorString, BDSKSecondAuthorEditorString, BDSKThirdAuthorEditorString, BDSKAuthorEditorString, BDSKLastAuthorEditorString, BDSKItemNumberString, BDSKContainerString, BDSKCrossrefString, BDSKLocalFileString, BDSKRemoteURLString, BDSKColorLabelString, nil]
                                              excluding:[self tableColumnIdentifiers]];
    
    BDSKFieldSheetController *addFieldController = [BDSKFieldSheetController fieldSheetControllerWithChoosableFields:colNames
                                                                             label:NSLocalizedString(@"Name of column to add:", @"Label for adding column")];
	[addFieldController beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
        NSString *newColumnName = [addFieldController chosenField];
        if (result == NSOKButton && newColumnName && [[self tableColumnIdentifiers] containsObject:newColumnName] == NO) {
            [self addTableColumnWithIdentifier:newColumnName];
            [self updateTableColumnDefaults];
        }
    }];
}

- (void)updateColumnsMenuUpdatingButton:(BOOL)updateButton {
    NSArray *shownColumns = [self tableColumnIdentifiers];
	NSMenuItem *item = nil;
    NSMenu *menu = [[self headerView] menu];
    
    if (menu == nil) {
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
	
    while ([[menu itemAtIndex:0] isSeparatorItem] == NO)
        [menu removeItemAtIndex:0];
    
	// next add all the shown columns in the order they are shown
	for (NSString *colName in [shownColumns reverseObjectEnumerator]) {
        item = [menu insertItemWithTitle:[colName localizedFieldName]
                                  action:@selector(columnsMenuSelectTableColumn:)
                           keyEquivalent:@""
                                 atIndex:0];
		[item setRepresentedObject:colName];
		[item setTarget:self];
		[item setState:NSOnState];
	}
    
	if (updateButton && [[self cornerView] isKindOfClass:[NSPopUpButton class]]) {
        menu = [self columnsMenu]; // this is already a copy
        item = [menu insertItemWithTitle:@"" action:NULL keyEquivalent:@"" atIndex:0];
        [item setImage:[[self class] cornerColumnsImage]];
        [(NSPopUpButton *)[self cornerView] setMenu:menu];
    }
}

- (void)tableColumnDidMove:(NSNotification *)note {
    if (ignoreMovedColumn == NO) {
        [self updateColumnsMenuUpdatingButton:YES];
        [self updateTableColumnDefaults];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem{
	SEL action = [menuItem action];
    if (action == @selector(alternateDelete:))
        return [self canAlternateDelete];
    else if (action == @selector(alternateCut:))
        return [self canAlternateCut];
    else if (action == @selector(columnsMenuSelectTableColumn:))
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
        cell = [self preparedCellAtColumn:column row:row];
        width = fmax(width, [cell cellSize].width);
    }
    width = fmin([tableColumn maxWidth], fmax([tableColumn minWidth], ceil(width)));
    [tableColumn setWidth:width];
}

- (void)autosizeColumn:(id)sender {
    NSInteger clickedColumn = [[sender representedObject] integerValue];
    if ([sender representedObject] && clickedColumn >= 0)
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

@implementation BDSKTextFieldCell

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    return nil;
}

@end

#pragma mark -

@implementation BDSKColorCell

- (NSSize)cellSizeForBounds:(NSRect)aRect {
    return NSMakeSize(fmin(16.0, NSWidth(aRect)), fmin(16.0, NSHeight(aRect)));
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSColor *color = [self objectValue];
    if ([color respondsToSelector:@selector(drawSwatchInRect:)])
        [color drawSwatchInRect:BDSKShrinkRect(cellFrame, 1.0, [controlView isFlipped] ? NSMaxYEdge : NSMinYEdge)];
}

@end

#pragma mark -

@implementation BDSKMainTableHeaderView 

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *menu = [super menuForEvent:theEvent];
    NSPoint clickPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    [[menu itemWithAction:@selector(autosizeColumn:)] setRepresentedObject:[NSNumber numberWithInteger:[self columnAtPoint:clickPoint]]];
    return menu;
}

@end

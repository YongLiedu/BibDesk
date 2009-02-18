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
#import <OmniFoundation/OmniFoundation.h>
#import <OmniAppKit/OmniAppKit.h>
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
#import "BDSKImageFadeAnimation.h"
#import "NSViewAnimation_BDSKExtensions.h"
#import <QuartzCore/QuartzCore.h>
#import "BDSKTextWithIconCell.h"
#import "NSImage_BDSKExtensions.h"
#import "NSParagraphStyle_BDSKExtensions.h"

enum {
    BDSKColumnTypeText,
    BDSKColumnTypeURL,
    BDSKColumnTypeLocalFile,
    BDSKColumnTypeRating,
    BDSKColumnTypeBoolean,
    BDSKColumnTypeTriState,
    BDSKColumnTypeCrossref,
    BDSKColumnTypeImportOrder,
    BDSKColumnTypeRelevance
};

@interface BDSKTableColumn : NSTableColumn {
    int columnType;
}
- (int)columnType;
- (void)setColumnType:(int)type;
@end

@interface BDSKMainTableHeaderView : NSTableHeaderView {
    int columnForMenu;
}
- (int)columnForMenu;
@end

@interface BDSKMainTableView (Private)

- (NSImage *)headerImageForField:(NSString *)field;
- (NSString *)headerTitleForField:(NSString *)field;
- (void)columnsMenuSelectTableColumn:(id)sender;
- (void)columnsMenuAddTableColumn:(id)sender;
- (void)addColumnSheetDidEnd:(BDSKAddFieldSheetController *)addFieldController returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)updateColumnsMenu;
- (IBAction)importItem:(id)sender;
- (IBAction)openParentItem:(id)sender;
- (void)autosizeColumn:(id)sender;
- (void)autosizeAllColumns:(id)sender;
@end

@implementation BDSKMainTableView

- (void)awakeFromNib{
    [super awakeFromNib]; // this updates the font
	
	[self setHeaderView:[[[BDSKMainTableHeaderView alloc] initWithFrame:[[self headerView] frame]] autorelease]];	
    
    NSRect cornerViewFrame = [[self cornerView] frame];
    BDSKImagePopUpButton *cornerViewButton = [[BDSKImagePopUpButton alloc] initWithFrame:cornerViewFrame];
    [cornerViewButton setIconSize:cornerViewFrame.size];
    [cornerViewButton setIconImage:[NSImage imageNamed:@"cornerColumns"]];
    [cornerViewButton setArrowImage:nil];
    [cornerViewButton setAlternateImage:[NSImage imageNamed:@"cornerColumns_Pressed"]];
    [cornerViewButton setShowsMenuWhenIconClicked:YES];
    [[cornerViewButton cell] setAltersStateOfSelectedItem:NO];
    [[cornerViewButton cell] setAlwaysUsesFirstItemAsSelected:NO];
    [[cornerViewButton cell] setUsesItemFromMenu:NO];
    [cornerViewButton setRefreshesMenu:NO];
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

- (void)keyDown:(NSEvent *)event{
    if ([[event characters] length] == 0)
        return;
    unichar c = [[event characters] characterAtIndex:0];
    unsigned int flags = ([event modifierFlags] & NSDeviceIndependentModifierFlagsMask & ~NSAlphaShiftKeyMask);
    if (c == 0x0020){ // spacebar to page down in the lower pane of the BibDocument splitview, shift-space to page up
        if(flags & NSShiftKeyMask)
            [[self delegate] pageUpInPreview:nil];
        else
            [[self delegate] pageDownInPreview:nil];
	// somehow alternate menu item shortcuts are not available globally, so we catch them here
	}else if((c == NSDeleteCharacter) &&  (flags & NSAlternateKeyMask)) {
		[[self delegate] alternateDelete:nil];
    // following methods should solve the mysterious problem of arrow/page keys not working for some users
    }else if(c == NSPageDownFunctionKey){
        [[self enclosingScrollView] pageDown:self];
    }else if(c == NSPageUpFunctionKey){
        [[self enclosingScrollView] pageUp:self];
    }else if(c == NSUpArrowFunctionKey){
        int row = [[self selectedRowIndexes] firstIndex];
		if (row == NSNotFound)
			row = 0;
		else if (row > 0)
			row--;
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:([event modifierFlags] | NSShiftKeyMask)];
        [self scrollRowToVisible:row];
    }else if(c == NSDownArrowFunctionKey){
        int row = [[self selectedRowIndexes] lastIndex];
		if (row == NSNotFound)
			row = 0;
		else if (row < [self numberOfRows] - 1)
			row++;
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:([event modifierFlags] | NSShiftKeyMask)];
        [self scrollRowToVisible:row];
    }else {
        [super keyDown:event];
    }
}

- (IBAction)deleteForward:(id)sender{
    // we use the same for Delete and the Backspace
    // Omni's implementation of deleteForward: selects the next item, which selects the wrong item too early because we may delay for the warning
    [self deleteBackward:sender];
}

- (void)highlightSelectionInClipRect:(NSRect)clipRect{
    [super highlightSelectionInClipRect:clipRect];
    
    if ([[self delegate] respondsToSelector:@selector(tableView:highlightColorForRow:)]) {
        NSRange visibleRows = [self rowsInRect:clipRect];
        unsigned int row;
        NSColor *color;
        NSRect ignored, rect;
        for (row = visibleRows.location; row < NSMaxRange(visibleRows); row++) {
            if (color = [[self delegate] tableView:self highlightColorForRow:row]) {
                [NSGraphicsContext saveGraphicsState];
                [color set];
                NSDivideRect([self rectOfRow:row], &ignored, &rect, 1.0, NSMaxYEdge);
                if ([self isRowSelected:row]) {
                    [NSBezierPath setDefaultLineWidth:2.0];
                    [NSBezierPath strokeHorizontalOvalAroundRect:NSInsetRect(rect, 2.0 + 0.5 * NSHeight(rect), 1.0)];
                    [NSBezierPath setDefaultLineWidth:1.0];
                } else {
                    [NSBezierPath fillHorizontalOvalAroundRect:NSInsetRect(rect, 1.0 + 0.5 * NSHeight(rect), 0.0)];
                }
                [NSGraphicsContext restoreGraphicsState];
            }
        }
    }
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

- (int)columnTypeForField:(NSString *)colName {
    int type = 0;
    if([colName isURLField])
        type = BDSKColumnTypeURL;
    else if([colName isEqualToString:BDSKLocalFileString] || [colName isEqualToString:BDSKRemoteURLString])
        type = BDSKColumnTypeLocalFile;
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
    else
        type = BDSKColumnTypeText;
    return type;
}

- (id)dataCellForColumnType:(int)columnType {
    id cell = nil;
    
    switch(columnType) {
        case BDSKColumnTypeURL:
            cell = [[[BDSKCenterScaledImageCell alloc] init] autorelease];
            break;
        case BDSKColumnTypeLocalFile:
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
    int columnType = [self columnTypeForField:colName];
    
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
    
    if (columnType != BDSKColumnTypeText && columnType != BDSKColumnTypeLocalFile && columnType != BDSKColumnTypeRelevance)
        [tc setWidth:fmaxf([dataCell cellSize].width, [headerCell cellSize].width)];
    
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

- (void)changeTableColumnsWithIdentifiers:(NSArray *)identifiers {
    // Store the new column in the preferences
    [[NSUserDefaults standardUserDefaults] setObject:[[identifiers arrayByRemovingObject:BDSKImportOrderString] arrayByRemovingObject:BDSKRelevanceString]
                                                      forKey:BDSKShownColsNamesKey];
    
    if (BDSKDefaultAnimationTimeInterval > 0.0) {
        NSView *cacheView = [self enclosingScrollView];
        NSImage *initialImage = [[NSImage alloc] initWithSize:[cacheView frame].size];
        NSBitmapImageRep *imageRep = [cacheView bitmapImageRepForCachingDisplayInRect:[cacheView frame]];
        [cacheView cacheDisplayInRect:[cacheView frame] toBitmapImageRep:imageRep];
        [initialImage addRepresentation:imageRep];
        
        // set the view up with the new columns; don't force a redraw, though
        [self setupTableColumnsWithIdentifiers:identifiers];
        
        // the added table column's content is not correct during the transition; -reloadData doesn't help
        NSImage *finalImage = [[NSImage alloc] initWithSize:[cacheView frame].size];
        imageRep = [cacheView bitmapImageRepForCachingDisplayInRect:[cacheView frame]];
        [cacheView cacheDisplayInRect:[cacheView frame] toBitmapImageRep:imageRep];
        [finalImage addRepresentation:imageRep];
        
        // block until this is done, so we can handle drawing manually
        BDSKImageFadeAnimation *animation = [[BDSKImageFadeAnimation alloc] initWithDuration:BDSKDefaultAnimationTimeInterval animationCurve:NSAnimationEaseInOut];
        [animation setDelegate:self];
        [animation setAnimationBlockingMode:NSAnimationBlocking];
        
        [animation setTargetImage:finalImage];
        [animation setStartingImage:initialImage];
        [animation startAnimation];
        
        [finalImage release];
        [initialImage release];
        
        [animation autorelease];
    } else {
        // set the view up with the new columns
        [self setupTableColumnsWithIdentifiers:identifiers];
    }
}

- (void)imageAnimationDidUpdate:(BDSKImageFadeAnimation *)anAnimation {
    NSView *scrollView = [self enclosingScrollView];
    NSGraphicsContext *ctxt = [NSGraphicsContext graphicsContextWithWindow:[scrollView window]];
    [NSGraphicsContext setCurrentContext:ctxt];
    
    [ctxt saveGraphicsState];
    NSRectClip([scrollView convertRect:[scrollView visibleRect] toView:nil]);
    
    // we're drawing the scrollview as well as the tableview
    NSRect frameRect = [scrollView convertRect:[scrollView frame] toView:nil];
    CIImage *ciImage = [anAnimation currentCIImage];
    [[ctxt CIContext] drawImage:ciImage atPoint:*(CGPoint *)&(frameRect.origin) fromRect:[ciImage extent]];
    [ctxt flushGraphics];
    [ctxt restoreGraphicsState];
}

- (void)insertTableColumnWithIdentifier:(NSString *)identifier atIndex:(unsigned)idx {
    NSMutableArray *shownColumns = [NSMutableArray arrayWithArray:[self tableColumnIdentifiers]];
    unsigned oldIndex = [shownColumns indexOfObject:identifier];
    
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
    
    [self changeTableColumnsWithIdentifiers:shownColumns];
}

- (void)removeTableColumnWithIdentifier:(NSString *)identifier {
    NSMutableArray *shownColumns = [NSMutableArray arrayWithArray:[self tableColumnIdentifiers]];

    // Check if an object already exists in the tableview.
    if ([shownColumns containsObject:identifier] == NO)
        return;
    
    [shownColumns removeObject:identifier];
    
    [self changeTableColumnsWithIdentifiers:shownColumns];
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
- (void)scrollRowToCenter:(unsigned int)row;
{
    NSRect rowRect = [self rectOfRow:row];
    
    if (NSEqualRects(rowRect, NSZeroRect))
        return;
    
    NSRect visibleRect;
    float heightDifference;
    
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
		NSMutableDictionary *tmpDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSImage imageNamed:@"TinyFile"], BDSKLocalUrlString, paperclip, BDSKLocalFileString, [NSImage arrowImage], BDSKCrossrefString, nil];
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

- (void)addColumnSheetDidEnd:(BDSKAddFieldSheetController *)addFieldController returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    NSString *newColumnName = [addFieldController field];
    
    if(newColumnName && returnCode == NSOKButton)
        [self insertTableColumnWithIdentifier:newColumnName atIndex:[self numberOfColumns]];
}

- (void)columnsMenuAddTableColumn:(id)sender{
    // first we fill the popup
	BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
    NSArray *colNames = [typeMan allFieldNamesIncluding:[NSArray arrayWithObjects:BDSKPubTypeString, BDSKCiteKeyString, BDSKPubDateString, BDSKDateAddedString, BDSKDateModifiedString, BDSKFirstAuthorString, BDSKSecondAuthorString, BDSKThirdAuthorString, BDSKLastAuthorString, BDSKFirstAuthorEditorString, BDSKSecondAuthorEditorString, BDSKThirdAuthorEditorString, BDSKAuthorEditorString, BDSKLastAuthorEditorString, BDSKItemNumberString, BDSKContainerString, BDSKCrossrefString, BDSKLocalFileString, BDSKRemoteURLString, nil]
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
    
	if([[self cornerView] isKindOfClass:[BDSKImagePopUpButton class]] && menu != nil)
        [(BDSKImagePopUpButton *)[self cornerView] setMenu:[self columnsMenu]];
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
    int row = [self clickedRow];
    OBASSERT(row != -1);
    if (row == -1)
        return;
    if([[self delegate] respondsToSelector:@selector(tableView:importItemAtRow:)])
        [[self delegate] tableView:self importItemAtRow:row];
}

- (void)openParentItem:(id)sender {
    int row = [self clickedRow];
    OBASSERT(row != -1);
    if (row == -1)
        return;
    if([[self delegate] respondsToSelector:@selector(tableView:openParentForItemAtRow:)])
        [[self delegate] tableView:self openParentForItemAtRow:row];
}

- (void)doAutosizeColumn:(unsigned int)column {
    int row, numRows = [self numberOfRows];
    NSTableColumn *tableColumn = [[self tableColumns] objectAtIndex:column];
    id cell;
    float width = 0.0;
    
    for (row = 0; row < numRows; row++) {
        if ([self respondsToSelector:@selector(preparedCellAtColumn:row:)]) {
            cell = [self preparedCellAtColumn:column row:row];
        } else {
            cell = [tableColumn dataCellForRow:row];
            if ([[self delegate] respondsToSelector:@selector(tableView:willDisplayCell:forTableColumn:row:)])
                [[self delegate] tableView:self willDisplayCell:cell forTableColumn:tableColumn row:row];
            [cell setObjectValue:[[self dataSource] tableView:self objectValueForTableColumn:tableColumn row:row]];
        }
        width = fmaxf(width, [cell cellSize].width);
    }
    width = fminf([tableColumn maxWidth], fmaxf([tableColumn minWidth], width));
    [tableColumn setWidth:width];
}

- (void)autosizeColumn:(id)sender {
    int clickedColumn = [(BDSKMainTableHeaderView *)[self headerView] columnForMenu];
    if (clickedColumn >= 0)
        [self doAutosizeColumn:clickedColumn];
}

- (void)autosizeAllColumns:(id)sender {
    unsigned int column, numColumns = [self numberOfColumns];
    for (column = 0; column < numColumns; column++)
        [self doAutosizeColumn:column];
}

@end


@implementation BDSKTableColumn

- (int)columnType { return columnType; }

- (void)setColumnType:(int)type { columnType = type; }

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
    float startWhite = [self isHighlighted] ? 0.9 : 1.0;
    float endWhite = [self isHighlighted] ? 0.95 : 0.9;
    float alpha = [self isEnabled] ? 1.0 : 0.6;
    NSRect rect = cellFrame;
    rect.size.height -= 1.0;
    rect = NSInsetRect(rect, 0.5 * NSHeight(rect), 0.5);
    NSBezierPath *path = [NSBezierPath bezierPathWithHorizontalOvalAroundRect:rect];

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

- (int)columnForMenu {
    return columnForMenu;
}

@end

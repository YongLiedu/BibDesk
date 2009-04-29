//
//  BDSKGroupOutlineView.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/19/05.
/*
 This software is Copyright (c) 2005-2009
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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

#import "BDSKGroupOutlineView.h"
#import "BDSKStringConstants.h"
#import "BDSKHeaderPopUpButtonCell.h"
#import "NSBezierPath_BDSKExtensions.h"
#import "BibDocument_Groups.h"
#import "NSTableView_BDSKExtensions.h"
#import "NSIndexSet_BDSKExtensions.h"
#import "BDSKTypeSelectHelper.h"
#import "BDSKGroup.h"
#import "BibAuthor.h"
#import "BDSKGroupCell.h"
#import "NSLayoutManager_BDSKExtensions.h"


@interface BDSKParentGroupCell : NSTextFieldCell
@end


@implementation BDSKGroupOutlineView

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [parentCell release];
    [super dealloc];
}

- (void)awakeFromNib
{
    BDSKPRECONDITION([[self enclosingScrollView] contentView]);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleClipViewFrameChangedNotification:)
                                                 name:NSViewFrameDidChangeNotification
                                               object:[[self enclosingScrollView] contentView]];
    
    BDSKTypeSelectHelper *aTypeSelectHelper = [[BDSKTypeSelectHelper alloc] init];
    [aTypeSelectHelper setCyclesSimilarResults:NO];
    [aTypeSelectHelper setMatchesPrefix:NO];
    [self setTypeSelectHelper:aTypeSelectHelper];
    [aTypeSelectHelper release];
    
    // the source list style sets the vertical spacing to 0, but using the default spacing gives the same result as Mail
    [self setIntercellSpacing:NSMakeSize(3.0, 2.0)];
}

- (NSRect)frameOfOutlineCellAtRow:(NSInteger)row
{
    return row > 0 ? [super frameOfOutlineCellAtRow:row] : NSZeroRect;
}

- (NSTextFieldCell *)parentCell {
    if (parentCell == nil) {
        parentCell = [[BDSKParentGroupCell alloc] init];
        [parentCell setTextColor:[NSColor disabledControlTextColor]];
        [parentCell setFont:[[NSFontManager sharedFontManager] convertFont:[self font] toHaveTrait:NSBoldFontMask]];
    }
    return parentCell;
}

- (void)setFont:(NSFont *)newFont {
    [super setFont:newFont];
    [parentCell setFont:[[NSFontManager sharedFontManager] convertFont:newFont toHaveTrait:NSBoldFontMask]];
}

- (CGFloat)rowHeightForFont:(NSFont *)font {
    // use a larger row height to give space for the highlights, also reproduces the row height in Mail
    return [NSLayoutManager defaultViewLineHeightForFont:font] + 4.0;
}

- (void)handleClipViewFrameChangedNotification:(NSNotification *)note
{
    // work around for bug where corner view doesn't get redrawn after scrollers hide
    [[self cornerView] setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)theEvent{
    if ([theEvent clickCount] == 2) {
        NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        NSInteger row = [self rowAtPoint:point];
        NSInteger column = [self columnAtPoint:point];
        if (row != -1 && column == 0) {
            BDSKGroupCell *cell = [[[self tableColumns] objectAtIndex:0] dataCellForRow:row];
            if ([cell respondsToSelector:@selector(iconRectForBounds:)]) {
                NSRect iconRect = [cell iconRectForBounds:[self frameOfCellAtColumn:column row:row]];
                if (NSMouseInRect(point, iconRect, [self isFlipped])) {
                    if ([[self delegate] respondsToSelector:@selector(outlineView:doubleClickedOnIconOfItem:)])
                        [[self delegate] outlineView:self doubleClickedOnIconOfItem:[self itemAtRow:row]];
                    return;
                }
            }
        }
    }
    [super mouseDown:theEvent];
}

static CGFloat mainColorBlue[3]         = {34695.0/65535.0, 39064.0/65535.0, 48316.0/65535.0};
static CGFloat disabledColorBlue[3]     = {40606.0/65535.0, 40606.0/65535.0, 40606.0/65535.0};
static CGFloat mainColorGraphite[3]     = {37779.0/65535.0, 41634.0/65535.0, 45489.0/65535.0};
static CGFloat disabledColorGraphite[3] = {40606.0/65535.0, 40606.0/65535.0, 40606.0/65535.0};

- (void)drawHighlightOnRows:(NSIndexSet *)rows
{
    NSParameterAssert(rows != nil);
    
    CGFloat lineWidth = 1.0;
    CGFloat heightOffset = BDSKMax(1.0f, BDSKRound(0.25 * [self intercellSpacing].height) - lineWidth);
    NSColor *highlightColor;
    
    if ([self respondsToSelector:@selector(setSelectionHighlightStyle:)]) {
        CGFloat *color;
        BOOL isGraphite = [NSColor currentControlTint] == NSGraphiteControlTint;
        if ([[self window] isMainWindow] || [[self window] isKeyWindow])
            color = isGraphite ? mainColorGraphite : mainColorBlue;
        else
            color = isGraphite ? disabledColorGraphite : disabledColorBlue;
        highlightColor = [NSColor colorWithDeviceRed:color[0] green:color[1] blue:color[2] alpha:1.0];
    } else {
        highlightColor = [NSColor disabledControlTextColor];
    }
    
    NSUInteger rowIndex = [rows firstIndex];
    NSRect drawRect;
    
    while (rowIndex != NSNotFound) {
        drawRect = NSInsetRect([self rectOfRow:rowIndex], 1.0, heightOffset);
        [NSBezierPath drawHighlightInRect:drawRect radius:4.0 lineWidth:lineWidth color:highlightColor];
        rowIndex = [rows indexGreaterThanIndex:rowIndex];
    }
}

// public method for updating the highlights (as when another table's selection changes)
- (void)updateHighlights
{
    [self setNeedsDisplay:YES];
}
- (void)reloadData
{
    const NSInteger nrows = [self numberOfRows];
    [super reloadData];
    
    /*
     Reloading can cause a selection change as side effect, but doesn't ask the delegate if it should select the row.
     This ends up selecting group rows, which is pretty undesirable, and can happen as a result of undo (via a
     notification handler), so isn't straightforward to work around in the controller.
     */
    if (nrows != [self numberOfRows] && [[self delegate] respondsToSelector:@selector(outlineView:shouldSelectItem:)]) {
        
        NSIndexSet *selectedIndexes = [self selectedRowIndexes];
        NSMutableIndexSet *indexesToSelect = [NSMutableIndexSet indexSet];
        NSUInteger row = [selectedIndexes firstIndex];
        while (NSNotFound != row) {
            if ([[self delegate] outlineView:self shouldSelectItem:[self itemAtRow:row]]) {
                [indexesToSelect addIndex:row];
            }
            row = [selectedIndexes indexGreaterThanIndex:row];
        }
        
        if ([indexesToSelect count]) {
            [self selectRowIndexes:indexesToSelect byExtendingSelection:NO];
        }
        else {
            [self deselectAll:nil];
        }
    }
}

- (void)highlightSelectionInClipRect:(NSRect)clipRect
{
    [super highlightSelectionInClipRect:clipRect];
    // check this in case it's been disconnected in one of our reloading optimizations
    if([[self delegate] respondsToSelector:@selector(outlineView:indexesOfRowsToHighlightInRange:)])
        [self drawHighlightOnRows:[[self delegate] outlineView:self indexesOfRowsToHighlightInRange:[self rowsInRect:clipRect]]];
}

// make sure that certain rows are only selected as a single selection
- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)shouldExtend{
    NSIndexSet *singleIndexes = nil;
    if ([[self delegate] respondsToSelector:@selector(outlineViewSingleSelectionIndexes:)])
        singleIndexes = [[self delegate] outlineViewSingleSelectionIndexes:self];
    
    // don't extend rows that should be in single selection
    if (shouldExtend == YES && singleIndexes && [[self selectedRowIndexes] intersectsIndexSet:singleIndexes])
        return;
    // remove single selection rows from multiple selections
    if ((shouldExtend == YES || [indexes count] > 1) && singleIndexes && [indexes intersectsIndexSet:singleIndexes]) {
        NSMutableIndexSet *mutableIndexes = [[indexes mutableCopy] autorelease];
        [mutableIndexes removeIndexes:singleIndexes];
        indexes = mutableIndexes;
    }
    if ([indexes count] == 0) 
        return;
    
    [super selectRowIndexes:indexes byExtendingSelection:shouldExtend];
    // this is needed because we draw multiple selections differently and BDSKGradientTableView calls this only for deprecated 10.3 methods
    [self setNeedsDisplay:YES];
}

- (void)textDidEndEditing:(NSNotification *)notification {
    NSInteger textMovement = [[[notification userInfo] objectForKey:@"NSTextMovement"] intValue];
    if ((textMovement == NSReturnTextMovement || textMovement == NSTabTextMovement) && 
        [[self delegate] respondsToSelector:@selector(outlineViewShouldEditNextItemWhenEditingEnds:)] && [[self delegate] outlineViewShouldEditNextItemWhenEditingEnds:self] == NO) {
        // This is ugly, but just about the only way to do it. NSTableView is determined to select and edit something else, even the text field that it just finished editing, unless we mislead it about what key was pressed to end editing.
        NSMutableDictionary *newUserInfo;
        NSNotification *newNotification;

        newUserInfo = [NSMutableDictionary dictionaryWithDictionary:[notification userInfo]];
        [newUserInfo setObject:[NSNumber numberWithInt:NSIllegalTextMovement] forKey:@"NSTextMovement"];
        newNotification = [NSNotification notificationWithName:[notification name] object:[notification object] userInfo:newUserInfo];
        [super textDidEndEditing:notification];

        // For some reason we lose firstResponder status when we do the above.
        [[self window] makeFirstResponder:self];
    } else {
        [super textDidEndEditing:notification];
    }
}

// the default implementation is broken with the above modifications, and would be invalid anyway
- (IBAction)selectAll:(id)sender {
    NSIndexSet *singleIndexes = nil;
    if ([[self delegate] respondsToSelector:@selector(outlineViewSingleSelectionIndexes:)])
        singleIndexes = [[self delegate] outlineViewSingleSelectionIndexes:self];
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfRows])];
    [indexes removeIndexes:singleIndexes];
    
    if ([[self delegate] respondsToSelector:@selector(outlineView:shouldSelectItem:)]) {
        NSMutableIndexSet *selectableIndexes = [NSMutableIndexSet indexSet];
        NSUInteger row = [indexes firstIndex];
        while (NSNotFound != row) {
            if ([[self delegate] outlineView:self shouldSelectItem:[self itemAtRow:row]]) {
                [selectableIndexes addIndex:row];
            }
        }
        indexes = selectableIndexes;
    }
    
    if ([indexes count] == 0) {
        return;
    } else if ([indexes count] == 1) {
        [self selectRowIndexes:indexes byExtendingSelection:NO];
    } else {
        // this follows the default implementation: do it in 2 steps to make sure the selectedRow will be the last one
        NSIndexSet *lastIndex = [NSIndexSet indexSetWithIndex:[indexes lastIndex]];
        [indexes removeIndex:[indexes lastIndex]];
        [self selectRowIndexes:indexes byExtendingSelection:NO];
        [self selectRowIndexes:lastIndex byExtendingSelection:YES];
    }
}

// the default implementation would be meaningless anyway as we don't allow empty selection
- (IBAction)deselectAll:(id)sender {
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:1] byExtendingSelection:NO];
	[self scrollRowToVisible:0];
}

@end


@implementation BDSKParentGroupCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4) {
        NSRect ignored;
        NSDivideRect(cellFrame, &ignored, &cellFrame, 4.0, NSMinYEdge);
    }
    [super drawInteriorWithFrame:cellFrame inView:controlView];
}

@end

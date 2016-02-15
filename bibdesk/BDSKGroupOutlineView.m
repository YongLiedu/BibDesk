//
//  BDSKGroupOutlineView.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/19/05.
/*
 This software is Copyright (c) 2005-2016
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
#import "NSBezierPath_BDSKExtensions.h"
#import "BibDocument_Groups.h"
#import "NSTableView_BDSKExtensions.h"
#import "BDSKTypeSelectHelper.h"
#import "BDSKGroup.h"
#import "BibAuthor.h"
#import "BDSKGroupCell.h"
#import "NSFont_BDSKExtensions.h"
#import "NSColor_BDSKExtensions.h"
#import "NSGeometry_BDSKExtensions.h"


@interface BDSKParentGroupCell : NSTextFieldCell
@end


@implementation BDSKGroupOutlineView

- (void)commonInit {
    BDSKTypeSelectHelper *aTypeSelectHelper = [[BDSKTypeSelectHelper alloc] init];
    [aTypeSelectHelper setCyclesSimilarResults:NO];
    [aTypeSelectHelper setMatchesPrefix:NO];
    [self setTypeSelectHelper:aTypeSelectHelper];
    [aTypeSelectHelper release];
    
    // the source list style sets the vertical spacing to 0, but using the default spacing gives the same result as Mail
    [self setIntercellSpacing:NSMakeSize(3.0, 2.0)];
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

- (void)dealloc
{
    BDSKDESTROY(parentCell);
    [super dealloc];
}

- (NSRect)frameOfOutlineCellAtRow:(NSInteger)row
{
    return row > 0 ? [super frameOfOutlineCellAtRow:row] : NSZeroRect;
}

- (NSTextFieldCell *)parentCell {
    if (parentCell == nil) {
        parentCell = [[NSTextFieldCell alloc] init];
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
    return [font defaultViewLineHeight] + 4.0;
}

- (void)mouseDown:(NSEvent *)theEvent{
    NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSInteger row = [self rowAtPoint:point];
    NSInteger column = [self columnAtPoint:point];
    if (row != -1 && column == 0 && [self isRowSelected:row]) {
        id cell = nil;
        cell = [self preparedCellAtColumn:column row:row];
        if ([cell isKindOfClass:[BDSKGroupCell class]]) {
            NSRect cellFrame = [self frameOfCellAtColumn:column row:row];
            NSUInteger hit = [cell hitTestForEvent:theEvent inRect:cellFrame ofView:self];
            if ((hit & NSCellHitEditableTextArea) == 0) {
                if ((hit & NSCellHitContentArea) != 0 && [theEvent clickCount] == 2 && 
                    [[self delegate] respondsToSelector:@selector(outlineView:doubleClickedOnIconOfItem:)])
                    [[self delegate] outlineView:self doubleClickedOnIconOfItem:[self itemAtRow:row]];
                return;
            }
        }
    }
    [super mouseDown:theEvent];
}

- (void)reloadData
{
    NSArray *selectedItems = [self selectedItems];
    
    [super reloadData];
    
    /*
     Reloading can cause a selection change as side effect, but doesn't ask the delegate if it should select the row.
     This ends up selecting group rows, which is pretty undesirable, and can happen as a result of undo (via a
     notification handler), so isn't straightforward to work around in the controller.
     */
    if ([[self delegate] respondsToSelector:@selector(outlineView:shouldSelectItem:)] &&
        [selectedItems isEqualToArray:[self selectedItems]] == NO) {
        
        NSMutableIndexSet *indexesToSelect = [NSMutableIndexSet indexSet];
        for (id item in selectedItems) {
            NSInteger row = [self rowForItem:item];
            if (row != -1 && [[self delegate] outlineView:self shouldSelectItem:item])
                [indexesToSelect addIndex:row];
        }
        
        if ([indexesToSelect count])
            [self selectRowIndexes:indexesToSelect byExtendingSelection:NO];
        else
            [self deselectAll:nil];
    }
}

- (void)drawRow:(NSInteger)row clipRect:(NSRect)clipRect {
    if ([[self delegate] respondsToSelector:@selector(outlineView:shouldHighlightItem:)] &&
        [self isRowSelected:row] == NO &&
        [[self delegate] outlineView:self shouldHighlightItem:[self itemAtRow:row]]) {
        
        CGFloat heightOffset = fmax(1.0, round(0.25 * [self intercellSpacing].height) - 1.0);
        NSRect drawRect = NSInsetRect([self rectOfRow:row], 1.0, heightOffset);
        NSWindow *window = [self window];
        NSColor *highlightColor = ([window isMainWindow] || [window isKeyWindow]) ? [NSColor mainSourceListHighlightColor] : [NSColor disabledSourceListHighlightColor];
        
        [NSBezierPath drawHighlightInRect:drawRect radius:4.0 lineWidth:1.0 color:highlightColor];
    }
    [super drawRow:row clipRect:clipRect];
}

// make sure that certain rows are only selected as a single selection
- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)shouldExtend{
    if ([[self delegate] respondsToSelector:@selector(outlineView:isSingleSelectionItem:)]) {
        // don't extend rows that should be in single selection
        if (shouldExtend && [[self selectedRowIndexes] count] == 1 && 
            [[self delegate] outlineView:self isSingleSelectionItem:[self itemAtRow:[[self selectedRowIndexes] firstIndex]]])
            return;
        // remove single selection rows from multiple selections
        if (shouldExtend || [indexes count] > 1) {
            NSMutableIndexSet *mutableIndexes = [NSMutableIndexSet indexSet];
            NSUInteger row = [indexes firstIndex];
            while (NSNotFound != row) {
                if ([[self delegate] outlineView:self isSingleSelectionItem:[self itemAtRow:row]] == NO)
                    [mutableIndexes addIndex:row];
                row = [indexes indexGreaterThanIndex:row];
            }
            indexes = mutableIndexes;
        }
    }
    if ([indexes count]) 
        [super selectRowIndexes:indexes byExtendingSelection:shouldExtend];
}

- (void)textDidEndEditing:(NSNotification *)notification {
    NSInteger textMovement = [[[notification userInfo] objectForKey:@"NSTextMovement"] integerValue];
    if ((textMovement == NSReturnTextMovement || textMovement == NSTabTextMovement) && 
        [[self delegate] respondsToSelector:@selector(outlineViewShouldEditNextItemWhenEditingEnds:)] && [[self delegate] outlineViewShouldEditNextItemWhenEditingEnds:self] == NO) {
        // This is ugly, but just about the only way to do it. NSTableView is determined to select and edit something else, even the text field that it just finished editing, unless we mislead it about what key was pressed to end editing.
        NSMutableDictionary *newUserInfo;
        NSNotification *newNotification;

        newUserInfo = [NSMutableDictionary dictionaryWithDictionary:[notification userInfo]];
        [newUserInfo setObject:[NSNumber numberWithInteger:NSIllegalTextMovement] forKey:@"NSTextMovement"];
        newNotification = [NSNotification notificationWithName:[notification name] object:[notification object] userInfo:newUserInfo];
        [super textDidEndEditing:newNotification];

        // For some reason we lose firstResponder status when we do the above.
        [[self window] makeFirstResponder:self];
    } else {
        [super textDidEndEditing:notification];
    }
}

// the default implementation would be meaningless anyway as we don't allow empty selection
- (IBAction)deselectAll:(id)sender {
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:1] byExtendingSelection:NO];
	[self scrollRowToVisible:0];
}

// very strange workaround for a very strange redrawing problem, when in live resize the table is only partially redrawn
- (void)drawRect:(NSRect)aRect {
    [super drawRect:aRect];
}

#pragma mark Delegate and DataSource

- (id <BDSKGroupOutlineViewDelegate>)delegate { return (id <BDSKGroupOutlineViewDelegate>)[super delegate]; }
- (void)setDelegate:(id <BDSKGroupOutlineViewDelegate>)newDelegate { [super setDelegate:newDelegate]; }

@end


@implementation BDSKParentGroupCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [super drawInteriorWithFrame:BDSKShrinkRect(cellFrame, 3.0, NSMinYEdge) inView:controlView];
}

@end

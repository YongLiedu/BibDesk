//
//  BDSKGroupTableView.m
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

#import "BDSKGroupTableView.h"
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

@implementation BDSKGroupTableView

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)awakeFromNib
{
    if([self numberOfColumns] == 0) 
		[NSException raise:BDSKUnimplementedException format:@"%@ needs at least one column.", [self class]];
    NSTableColumn *column = [[self tableColumns] objectAtIndex:0];
    BDSKPRECONDITION(column);
 	
	NSTableHeaderView *currentTableHeaderView = [self headerView];
	BDSKGroupTableHeaderView *customTableHeaderView = [[BDSKGroupTableHeaderView alloc] initWithTableColumn:column];
	
	[customTableHeaderView setFrame:[currentTableHeaderView frame]];
	[customTableHeaderView setBounds:[currentTableHeaderView bounds]];
	
	[self setHeaderView:customTableHeaderView];	
    [customTableHeaderView release];
    
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
    
    // default is (3.0, 2.0); use a larger spacing for the highlights
    [self setIntercellSpacing:NSMakeSize(3.0, 4.0)];
}

- (NSPopUpButtonCell *)popUpHeaderCell{
	return [(BDSKGroupTableHeaderView *)[self headerView] popUpHeaderCell];
}

- (void)handleClipViewFrameChangedNotification:(NSNotification *)note
{
    // work around for bug where corner view doesn't get redrawn after scrollers hide
    [[self cornerView] setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)theEvent{
    NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    int row = [self rowAtPoint:point];
    int column = [self columnAtPoint:point];
    if (row != -1 && column == 0) {
        BDSKGroupCell *cell = [[[self tableColumns] objectAtIndex:0] dataCellForRow:row];
        NSRect iconRect = [cell iconRectForBounds:[self frameOfCellAtColumn:column row:row]];
        if (NSPointInRect(point, iconRect)) {
            if ([theEvent clickCount] == 2) {
                if ([[self delegate] respondsToSelector:@selector(tableView:doubleClickedOnIconOfRow:)])
                    [[self delegate] tableView:self doubleClickedOnIconOfRow:row];
                return;
            } else if ([self isRowSelected:row]) {
                return;
            }
        }
    }
    [super mouseDown:theEvent];
}

- (void)drawHighlightOnRows:(NSIndexSet *)rows
{
    NSParameterAssert(rows != nil);
    
    float lineWidth = 1.0;
    float heightOffset = fmaxf(1.0f, roundf(0.25 * [self intercellSpacing].height) - lineWidth);
    NSColor *highlightColor;
    
    if ([self respondsToSelector:@selector(setSelectionHighlightStyle:)] == NO)
        highlightColor = [NSColor disabledControlTextColor];
    else if ([[self window] isMainWindow])
        highlightColor = [NSColor colorWithDeviceRed:34695.0/65535.0 green:39064.0/65535.0 blue:48316.0/65535.0 alpha:1.0];
    else
        highlightColor = [NSColor colorWithDeviceRed:40606.0/65535.0 green:40606.0/65535.0 blue:40606.0/65535.0 alpha:1.0];
    
    unsigned rowIndex = [rows firstIndex];
    NSRect drawRect;
    
    while(rowIndex != NSNotFound){
        
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

- (void)highlightSelectionInClipRect:(NSRect)clipRect
{
    [super highlightSelectionInClipRect:clipRect];
    // check this in case it's been disconnected in one of our reloading optimizations
    if([[self delegate] respondsToSelector:@selector(tableView:indexesOfRowsToHighlightInRange:)])
        [self drawHighlightOnRows:[[self delegate] tableView:self indexesOfRowsToHighlightInRange:[self rowsInRect:clipRect]]];
}

// make sure that certain rows are only selected as a single selection
- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)shouldExtend{
    NSIndexSet *singleIndexes = nil;
    if ([[self delegate] respondsToSelector:@selector(tableViewSingleSelectionIndexes:)])
        singleIndexes = [[self delegate] tableViewSingleSelectionIndexes:self];
    
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
    int textMovement = [[[notification userInfo] objectForKey:@"NSTextMovement"] intValue];
    if ((textMovement == NSReturnTextMovement || textMovement == NSTabTextMovement) && 
        [[self delegate] respondsToSelector:@selector(tableViewShouldEditNextItemWhenEditingEnds:)] && [[self delegate] tableViewShouldEditNextItemWhenEditingEnds:self] == NO) {
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
    NSIndexSet *singleIndexes = [[self delegate] tableViewSingleSelectionIndexes:self];
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfRows])];
    [indexes removeIndexes:singleIndexes];
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
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	[self scrollRowToVisible:0];
}

@end

#pragma mark -

@implementation BDSKGroupTableHeaderView 

- (id)initWithTableColumn:(NSTableColumn *)tableColumn
{
    if(![super init])
        return nil;
    
    BDSKHeaderPopUpButtonCell *cell;
    cell = [[BDSKHeaderPopUpButtonCell alloc] initWithHeaderCell:[tableColumn headerCell]];
        
    [tableColumn setHeaderCell:cell];
    [cell release];
    
    return self;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint location = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    
    int colIndex = [self columnAtPoint:location];
    BDSKASSERT(colIndex != -1);
    if(colIndex == -1)
        return;
    
    NSTableColumn *column = [[[self tableView] tableColumns] objectAtIndex:colIndex];
    id cell = [column headerCell];
	NSRect headerRect = [self headerRectOfColumn:colIndex];
    
	if ([cell isKindOfClass:[BDSKHeaderPopUpButtonCell class]]) {
		if (NSPointInRect(location, [cell popUpRectForBounds:headerRect])) {
			[cell trackMouse:theEvent 
					  inRect:headerRect 
					  ofView:self 
				untilMouseUp:YES];
		} else {
			[super mouseDown:theEvent];
		}
	} else {
		[super mouseDown:theEvent];
	}
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
	BDSKGroupTableView *tableView = (BDSKGroupTableView *)[self tableView];
	id delegate = [tableView delegate];
	NSPoint location = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	int column = [self columnAtPoint:location];
	
	if (column == -1)
		return nil;
	
	NSTableColumn *tableColumn = [[tableView tableColumns] objectAtIndex:column];
    id cell = [tableColumn headerCell];
    BOOL onPopUp = NO;
		
	if ([cell isKindOfClass:[BDSKHeaderPopUpButtonCell class]] &&
		NSPointInRect(location, [cell popUpRectForBounds:[self headerRectOfColumn:column]])) 
		onPopUp = YES;
		
	if ([delegate respondsToSelector:@selector(tableView:menuForTableHeaderColumn:onPopUp:)]) {
		return [delegate tableView:tableView menuForTableHeaderColumn:tableColumn onPopUp:onPopUp];
	}
	return nil;
}

- (NSPopUpButtonCell *)popUpHeaderCell{
	id headerCell = [[[[self tableView] tableColumns] objectAtIndex:0] headerCell];
	BDSKASSERT([headerCell isKindOfClass:[NSPopUpButtonCell class]]);
	return headerCell;
}

@end

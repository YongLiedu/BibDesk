//
//  BDSKEditorTableView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/11/07.
/*
 This software is Copyright (c) 2007-2011
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

#import "BDSKEditorTableView.h"
#import "BDSKEditorTextFieldCell.h"


@interface NSTableView (BDSKApplePrivate)
- (void)_dataSourceSetValue:(id)value forColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
@end


@implementation BDSKEditorTableView

- (void)mouseDown:(NSEvent *)theEvent {
    
    NSPoint location = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSInteger clickedColumn = [self columnAtPoint:location];
    NSInteger clickedRow = [self rowAtPoint:location];
    
    if (clickedRow != -1 && clickedColumn != -1) {
        NSTableColumn *tableColumn = [[self tableColumns] objectAtIndex:clickedColumn];
        NSRect cellFrame = [self frameOfCellAtColumn:clickedColumn row:clickedRow];
        id cell = [self preparedCellAtColumn:clickedColumn row:clickedRow];
        BOOL isEditable = [tableColumn isEditable] && 
                ([[self delegate] respondsToSelector:@selector(tableView:shouldEditTableColumn:row:)] == NO || 
                 [[self delegate] tableView:self shouldEditTableColumn:tableColumn row:clickedRow]);
        if ([cell respondsToSelector:@selector(buttonRectForBounds:)] &&
            NSMouseInRect(location, [cell buttonRectForBounds:cellFrame], [self isFlipped])) {
            if ([theEvent clickCount] > 1)
                theEvent = [NSEvent mouseEventWithType:[theEvent type] location:[theEvent locationInWindow] modifierFlags:[theEvent modifierFlags] timestamp:[theEvent timestamp] windowNumber:[theEvent windowNumber] context:[theEvent context] eventNumber:[theEvent eventNumber] clickCount:1 pressure:[theEvent pressure]];
        } else if ([cell isKindOfClass:[NSTextFieldCell class]] && isEditable) {
            if ([[self window] makeFirstResponder:nil]) {
                [self selectRowIndexes:[NSIndexSet indexSetWithIndex:clickedRow] byExtendingSelection:NO];
                [self editColumn:clickedColumn row:clickedRow withEvent:theEvent select:NO];
            }
            return;
        } else if (isEditable == NO && ([theEvent clickCount] != 2 || [self doubleAction] == NULL)) {
            return;
        }
    }
	[super mouseDown:theEvent];
}

// private method called from -[NSTableView textDidEndEditing:]
- (void)_dataSourceSetValue:(id)value forColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    [super _dataSourceSetValue:value forColumn:tableColumn row:row];
    didSetValue = YES;
}

- (void)textDidEndEditing:(NSNotification *)aNotification {
    NSInteger editedRow = [self editedRow];
    NSInteger editedColumn = [self editedColumn];
    
    /*
     NSTableView has an optimization of sorts where the value will not be set if the string in the cell
     is identical to the old string.  When you want to change e.g. year={2009} to year=2009, this becomes
     a problem.  I got fed up with deleting the old string, then setting the new raw string.
     
     Note that the cell's objectValue is an NSCFString, so we have to work with the formatter directly
     in order to get the (possibly complex) edited string.
     */
    BOOL shouldCheckValue = NO;
    id newValue = nil;
    if (editedColumn >= 0 && editedRow >= 0 && [self respondsToSelector:@selector(_dataSourceSetValue:forColumn:row:)]) {
        NSCell *editedCell = [self preparedCellAtColumn:editedColumn row:editedRow];
        id oldValue = [editedCell objectValue];
        if ([[editedCell formatter] getObjectValue:&newValue forString:[[aNotification object] string] errorDescription:NULL]) {
            shouldCheckValue = [oldValue respondsToSelector:@selector(isEqualAsComplexString:)] && [newValue respondsToSelector:@selector(isEqualAsComplexString:)] && 
                               [oldValue isEqualAsComplexString:newValue] == NO;
            newValue = [newValue copy];
        }
    }
    didSetValue = NO;
    
    endEditing = YES;
    [super textDidEndEditing:aNotification];
    endEditing = NO;
    
    // only try setting if NSTableView did not, and if these are not equal as complex strings
    if (didSetValue == NO && shouldCheckValue)
        [self _dataSourceSetValue:newValue forColumn:[[self tableColumns] objectAtIndex:editedColumn] row:editedRow];
    [newValue release];
    
    // on Leopard, we have to manually handle tab/return movements to avoid losing focus
    // http://www.cocoabuilder.com/archive/message/cocoa/2007/10/31/191866
    
    NSInteger movement = [[[aNotification userInfo] objectForKey:@"NSTextMovement"] integerValue];
    if ((editedRow != -1 && editedColumn != -1) && 
        (NSTabTextMovement == movement || NSBacktabTextMovement == movement || NSReturnTextMovement == movement)) {
        
        // assume NSReturnTextMovement
        NSInteger nextRow = editedRow;
        if (NSBacktabTextMovement == movement)
            nextRow = editedRow - 1;
        else if (NSTabTextMovement == movement)
            nextRow = editedRow + 1;
        
        if (nextRow < [self numberOfRows] && nextRow >= 0) {
        
            NSTableColumn *tableColumn = [[self tableColumns] objectAtIndex:editedColumn];
            BOOL isEditable = [tableColumn isEditable] && 
                              ([[self delegate] respondsToSelector:@selector(tableView:shouldEditTableColumn:row:)] == NO || 
                               [[self delegate] tableView:self shouldEditTableColumn:tableColumn row:nextRow]);
            
            if (isEditable) {
                [self selectRowIndexes:[NSIndexSet indexSetWithIndex:nextRow] byExtendingSelection:NO];
                [self editColumn:editedColumn row:nextRow withEvent:nil select:YES];
            }
        }
    }
}

- (void)highlightSelectionInClipRect:(NSRect)clipRect {}
- (void)_drawContextMenuHighlightForIndexes:(NSIndexSet *)rowIndexes clipRect:(NSRect)clipRect {}

- (BOOL)becomeFirstResponder {
    if ([super becomeFirstResponder]) {
        if ([self editedRow] == -1 && endEditing == NO) {
            NSInteger row = -1, column, numRows = [self numberOfRows], numCols = [self numberOfColumns];
            switch ([[self window] keyViewSelectionDirection]) {
                case NSSelectingNext:
                    row = 0;
                    break;
                case NSSelectingPrevious:
                    row = numRows - 1;
                    break;
                default:
                    break;
            }
            if (row != -1 && row < numRows) {
                for (column = 0; column < numCols; column++) {
                    NSTableColumn *tableColumn = [[self tableColumns] objectAtIndex:column];
                    BOOL isEditable = [tableColumn isEditable] && 
                                      ([[self delegate] respondsToSelector:@selector(tableView:shouldEditTableColumn:row:)] == NO || 
                                       [[self delegate] tableView:self shouldEditTableColumn:tableColumn row:row]);
                    if (isEditable) {
                        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
                        [self editColumn:column row:row withEvent:nil select:YES];
                        break;
                    }
                }
            }
        }
        return YES;
    } else {
        return NO;
    }
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
    return isLocal ? NSDragOperationEvery : NSDragOperationCopy;
}

// flag changes during a drag are not forwarded to the application, so we fix that at the end of the drag
- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation{
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKFlagsChangedNotification object:NSApp];
}

@end

//
//  BDSKTextImportItemTableView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 4/29/11.
/*
 This software is Copyright (c) 2011
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

#import "BDSKTextImportItemTableView.h"
#import "BDSKTypeManager.h"
#import "NSEvent_BDSKExtensions.h"


@interface NSTableView (BDSKApplePrivate2)
- (void)_dataSourceSetValue:(id)value forColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
@end


@interface BDSKTextImportItemTableView (Private)
- (void)startTemporaryTypeSelectMode;
- (void)endTemporaryTypeSelectMode;
- (BOOL)performActionForRow:(NSInteger)row;
@end


@implementation BDSKTextImportItemTableView

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent{
    
    unichar c = [theEvent firstCharacter];
    NSUInteger flags = [theEvent modifierFlags];
    
    if (flags & NSCommandKeyMask) {
        
        if (c >= '0' && c <= '9') {
        
            NSUInteger idx = c == '0' ? 9 : (NSUInteger)(c - '1');
            if (flags & NSAlternateKeyMask)
                idx += 10;
            BOOL rv = [self performActionForRow:idx];
            if (temporaryTypeSelectMode)
                [self endTemporaryTypeSelectMode];
            return rv;
        
        } else if (temporaryTypeSelectMode) {
        
            if (c == NSTabCharacter || c == 0x001b) {
                [self endTemporaryTypeSelectMode];
            } else if (c == NSCarriageReturnCharacter || c == NSEnterCharacter || c == NSNewlineCharacter) {
                [self endTemporaryTypeSelectMode];
                [self performActionForRow:[self selectedRow]];
            }
            if (temporaryTypeSelectMode == NO) {
                NSInteger row = [self selectedRow];
                if (row != -1)
                    [self editColumn:2 row:row withEvent:nil select:YES];
                return YES;
            }
        
        } else if (c == '=') {
        
            [self startTemporaryTypeSelectMode];
            return YES;
        }
    }
    
    return [super performKeyEquivalent:theEvent];
}

- (void)keyDown:(NSEvent *)event{
    unichar c = [event firstCharacter];
    NSUInteger flags = ([event deviceIndependentModifierFlags] & ~NSAlphaShiftKeyMask);
    
    static NSCharacterSet *fieldNameCharSet = nil;
    if (fieldNameCharSet == nil) 
        fieldNameCharSet = [[[[BDSKTypeManager sharedManager] strictInvalidCharactersForField:BDSKCiteKeyString] invertedSet] copy];
    
    if (temporaryTypeSelectMode) {
        if ((c == NSTabCharacter || c == 0x001b) && flags == 0) {
            [self endTemporaryTypeSelectMode];
            return;
        } else if ((c == NSCarriageReturnCharacter || c == NSEnterCharacter || c == NSNewlineCharacter) && flags == 0) {
            [self endTemporaryTypeSelectMode];
            [self performActionForRow:[self selectedRow]];
            return;
        } else if ([[self typeSelectHelper] isTypeSelectEvent:event] == NO && 
            (c != NSDownArrowFunctionKey && c != NSUpArrowFunctionKey && c != NSHomeFunctionKey && c != NSEndFunctionKey)) {
            // we allow navigation in the table using arrow keys
            NSBeep();
            return;
        }
    }
    
    [super keyDown:event];
}

- (BOOL)isInTemporaryTypeSelectMode {
    return temporaryTypeSelectMode;
}

- (void)startTemporaryTypeSelectMode {
    if (temporaryTypeSelectMode)
        return;
    temporaryTypeSelectMode = YES;
    savedFirstResponder = [[self window] firstResponder];
    if ([savedFirstResponder isKindOfClass:[NSTextView class]] && [(NSTextView *)savedFirstResponder isFieldEditor])
        savedFirstResponder = (NSResponder *)[(NSTextView *)savedFirstResponder delegate];
    [[self window] makeFirstResponder:self];
    if ([self selectedRow] == -1 && [self numberOfRows] > 0)
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    [[self delegate] tableViewDidChangeTemporaryTypeSelectMode:self];
}

- (void)endTemporaryTypeSelectMode  {
    if (temporaryTypeSelectMode == NO)
        return;
    temporaryTypeSelectMode = NO;
    [[self window] makeFirstResponder:savedFirstResponder];
    savedFirstResponder = nil;
    [[self delegate] tableViewDidChangeTemporaryTypeSelectMode:self];
}

- (BOOL)performActionForRow:(NSInteger)row {
    if ([[self delegate] tableView:self performActionForRow:row]) {
        return YES;
    } else {
        NSBeep();
        return NO;
    }
}

- (BOOL)resignFirstResponder {
    [self endTemporaryTypeSelectMode];
    return [super resignFirstResponder];
}

- (void)awakeFromNib{
    BDSKTypeSelectHelper *aTypeSelectHelper = [[BDSKTypeSelectHelper alloc] init];
    [aTypeSelectHelper setCyclesSimilarResults:YES];
    [self setTypeSelectHelper:aTypeSelectHelper];
    [aTypeSelectHelper release];
}

- (void)textDidEndEditing:(NSNotification *)aNotification {
    /*
     NSTableView has an optimization of sorts where the value will not be set if the string in the cell
     is equal to the old string.  When you want to change e.g. year={2009} to year=2009, this becomes
     a problem.  I got fed up with deleting the old string, then setting the new raw string.
     
     Note that the current cell's objectValue is still the old value, so we have to work with the formatter
     directly in order to get the (possibly complex) edited string.
     */
    NSInteger editedRow = [self editedRow];
    NSInteger editedColumn = [self editedColumn];
    BOOL shouldCheckValue = NO;
    id newValue = nil;
    if (editedColumn >= 0 && editedRow >= 0 && [self respondsToSelector:@selector(_dataSourceSetValue:forColumn:row:)]) {
        NSCell *editedCell = [self preparedCellAtColumn:editedColumn row:editedRow];
        NSFormatter *formatter = [editedCell formatter];
        id oldValue = [editedCell objectValue];
        newValue = [[aNotification object] string];
        if (formatter == nil || [formatter getObjectValue:&newValue forString:newValue errorDescription:NULL]) {
            shouldCheckValue = [oldValue respondsToSelector:@selector(isEqualAsComplexString:)] && 
                               [newValue respondsToSelector:@selector(isEqualAsComplexString:)] && 
                               [oldValue isEqualAsComplexString:newValue] == NO;
        }
        newValue = [newValue copy];
    }
    didSetValue = NO;
    
    [super textDidEndEditing:aNotification];
    
    // only try setting if NSTableView did not, and if these are not equal as complex strings
    if (didSetValue == NO && shouldCheckValue)
        [self _dataSourceSetValue:newValue forColumn:[[self tableColumns] objectAtIndex:editedColumn] row:editedRow];
    [newValue release];
    
    // on Leopard, we have to manually handle tab/return movements to avoid losing focus
    // http://www.cocoabuilder.com/archive/message/cocoa/2007/10/31/191866
}

#pragma mark Delegate and DataSource

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
- (id <BDSKTextImportItemTableViewDelegate>)delegate { return (id <BDSKTextImportItemTableViewDelegate>)[super delegate]; }
- (void)setDelegate:(id <BDSKTextImportItemTableViewDelegate>)newDelegate { [super setDelegate:newDelegate]; }
#endif

@end

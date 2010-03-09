//
//  NSTableView_BDSKExtensions.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/11/05.
/*
 This software is Copyright (c) 2005-2010
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

#import "NSTableView_BDSKExtensions.h"
#import "NSBezierPath_BDSKExtensions.h"
#import "BDSKRuntime.h"


@interface NSTableView (BDSApplePrivate)
-(void)_drawDropHighlightOnRow:(NSInteger)rowIndex;
@end

@implementation NSTableView (BDSKExtensions)

static BOOL (*original_validateUserInterfaceItem)(id, SEL, id) = NULL;

- (BOOL)replacement_validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem {
	if ([anItem action] == @selector(invertSelection:))
		return [self allowsMultipleSelection];
    else
        return original_validateUserInterfaceItem(self, _cmd, anItem);
}

- (IBAction)invertSelection:(id)sender {
    NSIndexSet *selRows = [self selectedRowIndexes];
    if ([self allowsMultipleSelection]) {
        NSMutableIndexSet *indexesToSelect = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfRows])];
        [indexesToSelect removeIndexes:selRows];
        [self selectRowIndexes:indexesToSelect byExtendingSelection:NO];
    } else {
        NSBeep();
    }
}

- (NSInteger)numberOfClickedOrSelectedRows {
    NSInteger number = 1;
    NSInteger clickedRow = [self clickedRow];
    if (clickedRow == -1) {
        number = [self numberOfSelectedRows];
    } else {
        NSIndexSet *selectedIndexes = [self selectedRowIndexes];
        if ([selectedIndexes containsIndex:clickedRow])
            number = [selectedIndexes count];
    }
    return number;
}

- (NSInteger)clickedOrSelectedRow {
    NSInteger row = [self clickedRow];
    if (row == -1)
        row = [self selectedRow];
    return row;
}

- (NSIndexSet *)clickedOrSelectedRowIndexes {
    NSIndexSet *selectedIndexes = [self selectedRowIndexes];
    NSInteger clickedRow = [self clickedRow];
    if (clickedRow != -1 && [selectedIndexes containsIndex:clickedRow] == NO)
        selectedIndexes = [NSIndexSet indexSetWithIndex:clickedRow];
    return selectedIndexes;
}

#pragma mark Drop highlight

+ (void)load {
    original_validateUserInterfaceItem = (BOOL (*)(id, SEL, id))BDSKReplaceInstanceMethodImplementationFromSelector(self, @selector(validateUserInterfaceItem:), @selector(replacement_validateUserInterfaceItem:));
}

@end

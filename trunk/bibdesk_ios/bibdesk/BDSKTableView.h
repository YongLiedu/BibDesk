//
//  BDSKTableView.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/18/09.
/*
 This software is Copyright (c) 2009-2012
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

#import <Cocoa/Cocoa.h>
#import "BDSKTypeSelectHelper.h"

@protocol BDSKTableViewDelegate <NSTableViewDelegate>
@optional

- (void)tableViewInsertNewline:(NSTableView *)aTableView;
- (void)tableViewInsertSpace:(NSTableView *)aTableView;
- (void)tableViewInsertShiftSpace:(NSTableView *)aTableView;

- (NSArray *)tableView:(NSTableView *)aTableView typeSelectHelperSelectionStrings:(BDSKTypeSelectHelper *)aTypeSelectHelper;
- (void)tableView:(NSTableView *)aTableView typeSelectHelper:(BDSKTypeSelectHelper *)aTypeSelectHelper didFailToFindMatchForSearchString:(NSString *)searchString;
- (void)tableView:(NSTableView *)aTableView typeSelectHelper:(BDSKTypeSelectHelper *)aTypeSelectHelper updateSearchString:(NSString *)searchString;

@end

@protocol BDSKTableViewDataSource <NSTableViewDataSource>
@optional

- (BOOL)tableView:(NSTableView *)aTableView canCopyRowsWithIndexes:(NSIndexSet *)rowIndexes;
- (void)tableView:(NSTableView *)aTableView deleteRowsWithIndexes:(NSIndexSet *)rowIndexes;
- (BOOL)tableView:(NSTableView *)aTableView canDeleteRowsWithIndexes:(NSIndexSet *)rowIndexes;
- (void)tableView:(NSTableView *)aTableView pasteFromPasteboard:(NSPasteboard *)pboard;
- (BOOL)tableViewCanPasteFromPasteboard:(NSTableView *)aTableView;
- (void)tableView:(NSTableView *)aTableView duplicateRowsWithIndexes:(NSIndexSet *)rowIndexes; // defaults to copy+paste
- (BOOL)tableView:(NSTableView *)aTableView canDuplicateRowsWithIndexes:(NSIndexSet *)rowIndexes;

- (NSDragOperation)tableView:(NSTableView *)aTableView draggingSourceOperationMaskForLocal:(BOOL)flag;

- (NSImage *)tableView:(NSTableView *)aTableView dragImageForRowsWithIndexes:(NSIndexSet *)dragRows;

- (void)tableView:(NSTableView *)aTableView concludeDragOperation:(NSDragOperation)operation;

@end


@interface BDSKTableView : NSTableView <BDSKTypeSelectDelegate> {
    BDSKTypeSelectHelper *typeSelectHelper;
    NSString *fontNamePreferenceKey;
    NSString *fontSizePreferenceKey;
    NSIndexSet *draggedRowIndexes;
}

+ (BOOL)shouldQueueTypeSelectHelper;

- (BDSKTypeSelectHelper *)typeSelectHelper;
- (void)setTypeSelectHelper:(BDSKTypeSelectHelper *)newTypeSelectHelper;

- (void)changeFont:(id)sender;
- (void)tableViewFontChanged;
- (CGFloat)rowHeightForFont:(NSFont *)font;
- (void)updateFontPanel:(NSNotification *)notification;
- (NSString *)fontNamePreferenceKey;
- (void)setFontNamePreferenceKey:(NSString *)newFontNamePreferenceKey;
- (NSString *)fontSizePreferenceKey;
- (void)setFontSizePreferenceKey:(NSString *)newFontSizePreferenceKey;

- (NSControlSize)cellControlSize;

- (void)invertSelection:(id)sender;
- (void)moveUp:(id)sender;
- (void)moveDown:(id)sender;
- (void)scrollToBeginningOfDocument:(id)sender;
- (void)scrollToEndOfDocument:(id)sender;
- (void)insertNewline:(id)sender;
- (void)insertSpace:(id)sender;
- (void)insertShiftSpace:(id)sender;

- (void)delete:(id)sender;
- (void)copy:(id)sender;
- (void)cut:(id)sender;
- (void)paste:(id)sender;
- (void)duplicate:(id)sender;

- (BOOL)canDelete;
- (BOOL)canCopy;
- (BOOL)canCut;
- (BOOL)canPaste;
- (BOOL)canDuplicate;

- (NSFont *)font;
- (void)setFont:(NSFont *)font;

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
- (id <BDSKTableViewDelegate>)delegate;
- (void)setDelegate:(id <BDSKTableViewDelegate>)newDelegate;
- (id <BDSKTableViewDataSource>)dataSource;
- (void)setDataSource:(id <BDSKTableViewDataSource>)newDataSource;
#endif

@end

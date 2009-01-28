// BDSKMainTableView.h
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

#import <Cocoa/Cocoa.h>

@class BDSKTypeSelectHelper;

/*!
    @class BDSKMainTableView
    @abstract Drag n' Droppable Tableview
    @discussion Subclass of NSTableview that allows drag n' drop.
*/
@interface BDSKMainTableView : NSTableView
{
    // for supporting type-ahead in the tableview:
    // datasource methods to support this are over in BibDocument_DataSource
    BDSKTypeSelectHelper *typeSelectHelper;
    NSArray *alternatingRowBackgroundColors;
}

- (void)setAlternatingRowBackgroundColors:(NSArray *)colorArray;
- (NSArray *)alternatingRowBackgroundColors;

- (BDSKTypeSelectHelper *)typeSelectHelper;

- (void)setupTableColumnsWithIdentifiers:(NSArray *)identifiers;
- (NSMenu *)columnsMenu;
- (void)insertTableColumnWithIdentifier:(NSString *)identifier atIndex:(unsigned)index;
- (void)removeTableColumnWithIdentifier:(NSString *)identifier;

@end


@interface NSObject (BDSKMainTableViewDelegate)
- (NSDictionary *)defaultColumnWidthsForTableView:(NSTableView *)aTableView;
- (void)tableView:(NSTableView *)aTableView importItemAtRow:(int)rowIndex;
- (void)tableView:(NSTableView *)aTableView openParentForItemAtRow:(int)rowIndex;
- (NSColor *)tableView:(NSTableView *)aTableView highlightColorForRow:(int)rowIndex;
@end


@interface NSColor (BDSKExtensions)
+ (NSArray *)alternateControlAlternatingRowBackgroundColors;
@end


@interface BDSKRoundRectButtonCell : NSButtonCell
@end

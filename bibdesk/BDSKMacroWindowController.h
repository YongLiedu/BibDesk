//
//  BDSKMacroWindowController.h
//  BibDesk
//
//  Created by Michael McCracken on 2/21/05.
/*
 This software is Copyright (c) 2005-2009
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
#import "BDSKTableView.h"

@class BDSKMacroResolver, BDSKComplexStringFormatter, BDSKComplexStringEditor;

@interface BDSKMacroWindowController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource> {
    IBOutlet NSArrayController *arrayController;
    IBOutlet NSTableView *tableView;
    IBOutlet NSButton *closeButton;
    IBOutlet NSSegmentedControl *addRemoveButton;
    BDSKMacroResolver *macroResolver;
    NSMutableArray *macros;
	BDSKComplexStringFormatter *tableCellFormatter;
	BDSKComplexStringEditor *complexStringEditor;
    BOOL isEditable;
    BOOL showAll;
}

- (id)initWithMacroResolver:(BDSKMacroResolver *)aMacroResolver;

- (BDSKMacroResolver *)macroResolver;

- (NSArray *)macros;
- (void)setMacros:(NSArray *)newMacros;
- (NSUInteger)countOfMacros;
- (id)objectInMacrosAtIndex:(NSUInteger)idx;
- (void)insertObject:(id)obj inMacrosAtIndex:(NSUInteger)idx;
- (void)removeObjectFromMacrosAtIndex:(NSUInteger)idx;
- (void)replaceObjectInMacrosAtIndex:(NSUInteger)idx withObject:(id)obj;

- (IBAction)addRemoveMacro:(id)sender;
- (BOOL)addMacrosFromBibTeXString:(NSString *)aString;

- (IBAction)closeAction:(id)sender;

- (IBAction)search:(id)sender;

- (IBAction)changeShowAll:(id)sender;

- (IBAction)editSelectedFieldAsRawBibTeX:(id)sender;
- (BOOL)editSelectedCellAsMacro;

- (void)handleMacroChangedNotification:(NSNotification *)notif;
- (void)handleGroupWillBeRemovedNotification:(NSNotification *)notif;

- (void)reloadMacros;

@end

@interface MacroKeyFormatter : NSFormatter {

}

@end


@interface BDSKMacroTableView : BDSKTableView
@end

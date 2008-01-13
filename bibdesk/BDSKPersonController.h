//
//  BDSKPersonController.h
//  BibDesk
//
//  Created by Michael McCracken on Thu Mar 18 2004.
/*
 This software is Copyright (c) 2004-2008
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

#import <AppKit/AppKit.h>

@class BibDocument;
@class BibAuthor;

@class BDSKDragImageView;
@class BDSKCollapsibleView;
@class OASplitView;

@interface BDSKPersonController : NSWindowController {
    BibAuthor *person;
    NSMutableArray *publicationItems;
    NSSet *names;
    NSSet *fields;
	float lastPickerHeight;
    IBOutlet NSTextField *nameTextField;
    IBOutlet BDSKDragImageView *imageView;
    IBOutlet NSTableView *publicationTableView;
    IBOutlet NSTableView *nameTableView;
    IBOutlet NSTableView *fieldTableView;
    IBOutlet BDSKCollapsibleView *collapsibleView;
    IBOutlet OASplitView *splitView;
    IBOutlet NSArrayController *publicationArrayController;
    IBOutlet NSArrayController *fieldArrayController;
    IBOutlet NSArrayController *nameArrayController;
    BOOL isEditable;
}

#pragma mark initialization
- (id)initWithPerson:(BibAuthor *)aPerson;
- (void)awakeFromNib;

#pragma mark accessors
- (BibAuthor *)person;
- (void)setPerson:(BibAuthor *)newPerson;
- (NSArray *)publicationItems;
- (void)setPublicationItems:(NSArray *)items;
- (NSSet *)names;
- (void)setNames:(NSSet *)newNames;
- (NSSet *)fields;
- (void)setFields:(NSSet *)newFields;

#pragma mark actions
- (void)show;
- (void)updateUI;
- (void)updatePublicationItems;
- (void)updateFilter;
- (void)handleBibItemAddDel:(NSNotification *)note;
- (void)handleBibItemChanged:(NSNotification *)note;
- (void)handleGroupWillBeRemoved:(NSNotification *)note;
- (void)openSelectedPub:(id)sender;
- (void)changeNameToString:(NSString *)newNameString;

- (NSUndoManager *)undoManager;

@end

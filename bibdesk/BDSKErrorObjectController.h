//
//  BDSKErrorObjectController.h
//  Bibdesk
//
//  Created by Adam Maxwell on 08/12/05.
/*
 This software is Copyright (c) 2005,2006
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

#import <Cocoa/Cocoa.h>
#import <BTParse/BDSKErrorObject.h>

@class BibDocument, BDSKErrorEditor, BDSKFilteringArrayController;

@interface BDSKErrorObjectController : NSWindowController {
    NSMutableArray *errors;
    NSMutableArray *managers;
    NSMutableArray *editors;
    NSMutableArray *currentErrors;
    
    // error-handling stuff:
    IBOutlet NSTableView *errorTableView;
    IBOutlet BDSKFilteringArrayController *errorsController;
}

+ (BDSKErrorObjectController *)sharedErrorObjectController;

- (NSArray *)errors;
- (unsigned)countOfErrors;
- (id)objectInErrorsAtIndex:(unsigned)index;
- (void)insertObject:(id)obj inErrorsAtIndex:(unsigned)index;
- (void)removeObjectFromErrorsAtIndex:(unsigned)index;

- (NSArray *)managers;
- (unsigned)countOfManagers;
- (id)objectInManagersAtIndex:(unsigned)theIndex;
- (void)insertObject:(id)obj inManagersAtIndex:(unsigned)theIndex;
- (void)removeObjectFromManagersAtIndex:(unsigned)theIndex;

- (NSArray *)editors;
- (void)addEditor:(BDSKErrorEditor *)editor;
- (void)removeEditor:(BDSKErrorEditor *)editorr;

- (BDSKErrorEditor *)editorForDocument:(BibDocument *)document create:(BOOL)create;
- (BDSKErrorEditor *)editorForFileName:(NSString *)fileName  create:(BOOL)create;

// called to edit a failed parse/drag
- (void)showEditorForFileName:(NSString *)fileName;
// called from the tableView doubleclick
- (void)showEditorForErrorObject:(BDSKErrorObject *)errObj;

// called after a failed load
- (void)documentFailedLoad:(BibDocument *)document shouldEdit:(BOOL)shouldEdit;
// called when a document is removed
- (void)handleRemoveDocumentNotification:(NSNotification *)notification;

- (IBAction)toggleShowingErrorPanel:(id)sender;
- (IBAction)hideErrorPanel:(id)sender;
- (IBAction)showErrorPanel:(id)sender;

// tableView actions
- (IBAction)copy:(id)sender;
- (IBAction)gotoError:(id)sender;

// any use of btparse should be bracketed by these two calls
- (void)startObservingErrorsForDocument:(BibDocument *)document;
- (void)endObservingErrorsForDocument:(BibDocument *)document;

- (void)handleErrorNotification:(NSNotification *)notification;

@end

#pragma mark -

@interface BDSKErrorObject (BDSKExtensions)
- (NSString *)displayFileName;
@end

#pragma mark -

@interface BDSKPlaceHolderFilterItem : NSObject {
	NSString *displayName;
}
+ (BDSKPlaceHolderFilterItem *)allItemsPlaceHolderFilterItem;
+ (BDSKPlaceHolderFilterItem *)emptyItemsPlaceHolderFilterItem;
- (id)initWithDisplayName:(NSString *)name;
@end

#pragma mark -

@interface BDSKFilteringArrayController : NSArrayController {
    id filterValue;
	NSString *filterKey;
    NSString *warningKey;
    NSString *warningValue;
    BOOL hideWarnings;
}

- (id)filterValue;
- (void)setFilterValue:(id)newValue;
- (NSString *)filterKey;
- (void)setFilterKey:(NSString *)newKey;
- (NSString *)warningKey;
- (void)setWarningKey:(NSString *)newKey;
- (NSString *)warningValue;
- (void)setWarningValue:(NSString *)newKey;
- (BOOL)hideWarnings;
- (void)setHideWarnings:(BOOL)flag;

@end

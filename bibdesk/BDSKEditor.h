//  BDSKEditor.h

//  Created by Michael McCracken on Mon Dec 24 2001.
/*
 This software is Copyright (c) 2001-2009
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

/*! @header BDSKEditor.h
    @discussion The class for editing BibItems. Handles the UI for the fields and notes.
*/ 

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class BDSKRatingButton, BDSKRatingButtonCell, BDSKStatusBar, BDSKZoomablePDFView, FVFileView, BDSKEditorTableView;
@class BDSKComplexStringFormatter, BDSKCrossrefFormatter, BDSKCitationFormatter, BDSKComplexStringEditor;
@class BibItem, BibAuthor;

/*!
    @class BDSKEditor
    @abstract WindowController for the edit window
    @discussion Subclass of the NSWindowController class, This handles making, reversing and keeping track of changes to the BibItem, and displaying a nice GUI.
*/
@interface BDSKEditor : NSWindowController <NSWindowDelegate, NSTableViewDelegate, NSTableViewDataSource, NSSplitViewDelegate, NSControlTextEditingDelegate> {
	IBOutlet NSSplitView *mainSplitView;
	IBOutlet NSSplitView *fileSplitView;
    IBOutlet NSPopUpButton *bibTypeButton;
    IBOutlet BDSKEditorTableView *tableView;
    IBOutlet NSMatrix *matrix;
    IBOutlet NSTabView *tabView;
    IBOutlet NSTextView *notesView;
    IBOutlet NSTextView *abstractView;
    IBOutlet NSTextView *rssDescriptionView;
	
    // one of the three previous textviews:
    NSTextView *currentEditedView;
    NSString *previousValueForCurrentEditedView;
    
    // each textview gets its own undo manager
    NSUndoManager *notesViewUndoManager;
    NSUndoManager *abstractViewUndoManager;
    NSUndoManager *rssDescriptionViewUndoManager;
    
    // for the splitview double-click handling
	CGFloat lastFileViewWidth;
    CGFloat lastAuthorsHeight;
    
	NSButtonCell *booleanButtonCell;
	NSButtonCell *triStateButtonCell;
	BDSKRatingButtonCell *ratingButtonCell;
    
    IBOutlet NSTextField *citeKeyField;
    IBOutlet NSTextField *citeKeyTitle;
	IBOutlet NSPopUpButton *actionButton;
	IBOutlet NSButton *addFieldButton;
    
    // ----------------------------------------------------------------------------------------
    BibItem *publication;
    
    NSMutableArray *fields;
    
    NSMutableSet *addedFields;
    
// ----------------------------------------------------------------------------------------
// status bar stuff
// ----------------------------------------------------------------------------------------
    IBOutlet BDSKStatusBar *statusBar;
	
// cite-key checking stuff:
	IBOutlet NSButton *citeKeyWarningButton;
	
// form cell formatter
    BDSKComplexStringFormatter *tableCellFormatter;
    BDSKCrossrefFormatter *crossrefFormatter;
	BDSKCitationFormatter *citationFormatter;
    
// Author tableView
	IBOutlet NSTableView *authorTableView;

    // Macro editing stuff
    BDSKComplexStringEditor *complexStringEditor;

	NSTextView *dragFieldEditor;
    
    IBOutlet FVFileView *fileView;
    
    NSButton *disableAutoFileButton;
    
    struct _editorFlags {
        unsigned int ignoreFieldChange:1;
        unsigned int isEditable:1;
        unsigned int isEditing:1;
        unsigned int isAnimating:1;
        unsigned int didSetupFields:1;
    } editorFlags;
}

/*!
@method initWithPublication:
    @abstract designated Initializer
    @discussion
 @param aBib gives us a bib to edit
*/
- (id)initWithPublication:(BibItem *)aBib;

- (BibItem *)publication;

/*!
    @method     show
    @abstract   Shows the window.
    @discussion (comprehensive description)
*/
- (void)show;

- (IBAction)chooseLocalFile:(id)sender;

- (IBAction)chooseRemoteURL:(id)sender;

- (IBAction)raiseAddField:(id)sender;
- (IBAction)raiseDelField:(id)sender;
- (IBAction)raiseChangeFieldName:(id)sender;

/*!
    @method     editSelectedFieldAsRawBibTeX:
    @abstract   edits the current field as a macro.
    @discussion This is not necessary if the field is already a macro.
    @param      sender (description)
    @result     (description)
*/
- (IBAction)editSelectedFieldAsRawBibTeX:(id)sender;

/*!
    @method     recordChangingField:toValue:
    @abstract   sets field to value in publication and does other stuff
    @discussion factored out because setting field and doing other things is done from more than one place.
    @param      fieldName (description)
    @param      value (description)
*/
- (void)recordChangingField:(NSString *)fieldName toValue:(NSString *)value;

- (void)needsToBeFiledDidChange:(NSNotification *)notification;

- (void)updateCiteKeyAutoGenerateStatus;

- (NSInteger)userChangedField:(NSString *)fieldName from:(NSString *)oldValue to:(NSString *)newValue;
- (NSInteger)userChangedField:(NSString *)fieldName from:(NSString *)oldValue to:(NSString *)newValue didAutoGenerate:(NSInteger)mask;

- (NSString *)status;
- (void)setStatus:(NSString *)status;

- (IBAction)openLinkedFile:(id)sender;

- (IBAction)revealLinkedFile:(id)sender;

- (IBAction)openLinkedURL:(id)sender;

- (IBAction)showNotesForLinkedFile:(id)sender;

- (IBAction)copyNotesForLinkedFile:(id)sender;

- (IBAction)previewAction:(id)sender;

/*!
    @method     updateSafariRecentDownloadsMenu:
    @abstract   Updates the menu of items for local paths of recent downloads from Safari.
    @discussion (comprehensive description)
*/
- (void)updateSafariRecentDownloadsMenu:(NSMenu *)menu;

/*!
    @method     updateSafariRecentURLsMenu:
    @abstract   Updates the menu off items for remote URLs of recent downloads from Safari.
    @discussion (comprehensive description)
*/
- (void)updateSafariRecentURLsMenu:(NSMenu *)menu;

/*!
    @method     updatePreviewRecentDocumentsMenu:
    @abstract   Updates the menu of items for local paths of recent documents from Preview.
    @discussion (comprehensive description)
*/
- (void)updatePreviewRecentDocumentsMenu:(NSMenu *)menu;

/*!
    @method     recentDownloadsMenu
    @abstract   Returns a menu of modified files in the system download directory using Spotlight.
    @discussion (comprehensive description)
    @result     (description)
*/
- (NSMenu *)recentDownloadsMenu;

/*!
    @method     addLinkedFileFromMenuItem
    @abstract   Action to select a local file path from a menu item.
    @discussion (comprehensive description)
*/
- (void)addLinkedFileFromMenuItem:(NSMenuItem *)sender;

/*!
    @method     addRemoteURLFromMenuItem
    @abstract   Action to select a remote URL from a menu item.
    @discussion (comprehensive description)
*/
- (void)addRemoteURLFromMenuItem:(NSMenuItem *)sender;

- (IBAction)trashLinkedFiles:(id)sender;

/*!
    @method     showCiteKeyWarning:
    @abstract   Action of the cite-key warning button. Shows the error string in an alert panel.
    @discussion (comprehensive description)
*/
- (IBAction)showCiteKeyWarning:(id)sender;

/*!
    @method     bibTypeDidChange:
    @abstract   Action of a form field to set a new value for a bibliography field.
    @discussion (comprehensive description)
*/
- (IBAction)bibTypeDidChange:(id)sender;
/*!
    @method     updateTypePopup
    @abstract   Update the type popup menu based on the current bibitem's type.  Needed for dragging support (see BDSKDragWindow.m).
    @discussion (comprehensive description)
*/
- (void)updateTypePopup;
- (void)bibWasAddedOrRemoved:(NSNotification *)notification;

- (IBAction)changeRating:(id)sender;
- (IBAction)changeFlag:(id)sender;

/*!
    @method     generateCiteKey:
    @abstract   Action to generate a cite-key for the bibitem, using the cite-key format string. 
    @discussion (comprehensive description)
*/
- (IBAction)generateCiteKey:(id)sender;

/*!
    @method     consolidateLinkedFiles:
    @abstract   Action to auto file the linked paper, using the local-url format string. 
    @discussion (comprehensive description)
*/
- (IBAction)consolidateLinkedFiles:(id)sender;

/*!
    @method     duplicateTitleToBooktitle:
    @abstract   Action to copy the title field to the booktitle field. Overwrites the booktitle field.
    @discussion (comprehensive description)
*/
- (IBAction)duplicateTitleToBooktitle:(id)sender;

- (NSString *)keyField;
- (void)setKeyField:(NSString *)fieldName;

- (void)bibDidChange:(NSNotification *)notification;
- (void)typeInfoDidChange:(NSNotification *)aNotification;
- (void)customFieldsDidChange:(NSNotification *)aNotification;
- (void)fileURLDidChange:(NSNotification *)notification;

- (void)bibWillBeRemoved:(NSNotification *)notification;
- (void)groupWillBeRemoved:(NSNotification *)notification;

- (void)openParentItemForField:(NSString *)field;

- (IBAction)selectCrossrefParentAction:(id)sender;
- (IBAction)createNewPubUsingCrossrefAction:(id)sender;

- (IBAction)tableButtonAction:(id)sender;

- (NSUndoManager *)undoManager;

- (void)deleteURLsAtIndexes:(NSIndexSet *)indexSet moveToTrash:(NSInteger)moveToTrash;

#pragma mark Person controller

- (IBAction)showPersonDetail:(id)sender;

- (NSInteger)numberOfPersons;
- (BibAuthor *)personAtIndex:(NSUInteger)anIndex;
- (NSArray *)persons;

#pragma mark Macro support
    
- (BOOL)editSelectedCellAsMacro;
- (void)macrosDidChange:(NSNotification *)aNotification;


- (IBAction)toggleSidebar:(id)sender;
- (IBAction)toggleStatusBar:(id)sender;

@end


@interface BDSKTabView : NSTabView
@end

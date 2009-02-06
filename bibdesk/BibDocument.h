//  BibDocument.h

//  Created by Michael McCracken on Mon Dec 17 2001.
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

/*! @header BibDocument.h
    @discussion This defines a subclass of NSDocument that reads and writes BibTeX entries. It handles the main document window.
*/

#import <Cocoa/Cocoa.h>
#import "BDSKGroupTableView.h"
#import "BDSKFileContentSearchController.h"
#import "BDSKTemplateParser.h"
#import "BDSKOwnerProtocol.h"

@class BibItem, BibAuthor, BDSKGroup, BDSKStaticGroup, BDSKSmartGroup, BDSKTemplate, BDSKPublicationsArray, BDSKGroupsArray;
@class AGRegex, BDSKTeXTask, BDSKMacroResolver, BDSKItemPasteboardHelper;
@class BDSKEditor, BDSKMacroWindowController, BDSKDocumentInfoWindowController, BDSKPreviewer, BDSKFileContentSearchController, BDSKCustomCiteDrawerController, BDSKSearchGroupViewController;
@class BDSKAlert, BDSKStatusBar, BDSKMainTableView, BDSKGroupTableView, BDSKGradientView, BDSKSplitView, BDSKCollapsibleView, BDSKEdgeView, BDSKImagePopUpButton, BDSKColoredBox, BDSKEncodingPopUpButton, BDSKZoomablePDFView, FileView;
@class BDSKWebGroupViewController, BDSKSearchButtonController;
@class BDSKItemSearchIndexes, BDSKFileMigrationController, BDSKDocumentSearch;

enum {
	BDSKOperationIgnore = NSAlertDefaultReturn, // 1
	BDSKOperationSet = NSAlertAlternateReturn, // 0
	BDSKOperationAppend = NSAlertOtherReturn, // -1
	BDSKOperationAsk = NSAlertErrorReturn, // -2
};

// these should correspond to the tags of copy-as menu items, as well as the default drag/copy type
enum {
	BDSKBibTeXDragCopyType = 0, 
	BDSKCiteDragCopyType = 1, 
	BDSKPDFDragCopyType = 2, 
	BDSKRTFDragCopyType = 3, 
	BDSKLaTeXDragCopyType = 4, 
	BDSKLTBDragCopyType = 5, 
	BDSKMinimalBibTeXDragCopyType = 6, 
	BDSKRISDragCopyType = 7,
	BDSKURLDragCopyType = 8,
    BDSKTemplateDragCopyType = 100
};

enum {
    BDSKDetailsPreviewDisplay = 0,
    BDSKNotesPreviewDisplay = 1,
    BDSKAbstractPreviewDisplay = 2,
    BDSKTemplatePreviewDisplay = 3,
    BDSKPDFPreviewDisplay = 4,
    BDSKRTFPreviewDisplay = 5,
    BDSKLinkedFilePreviewDisplay = 6
};

enum {
    BDSKPreviewDisplayText = 0,
    BDSKPreviewDisplayFiles = 1,
    BDSKPreviewDisplayTeX = 2
};

// our main document types
extern NSString *BDSKBibTeXDocumentType;
extern NSString *BDSKRISDocumentType;
extern NSString *BDSKMinimalBibTeXDocumentType;
extern NSString *BDSKLTBDocumentType;
extern NSString *BDSKEndNoteDocumentType;
extern NSString *BDSKMODSDocumentType;
extern NSString *BDSKAtomDocumentType;
extern NSString *BDSKArchiveDocumentType;

// Some pasteboard types used by the document for dragging and copying.
extern NSString* BDSKReferenceMinerStringPboardType; // pasteboard type from Reference Miner, determined using Pasteboard Peeker
extern NSString *BDSKBibItemPboardType;
extern NSString* BDSKWeblocFilePboardType; // core pasteboard type for webloc files

/*!
    @class BibDocument
    @abstract Controller class for .bib files
    @discussion This is the document class. It keeps an array of BibItems (called (NSMutableArray *)publications) and handles the quick search box. It delegates PDF generation to a BDSKPreviewer.
*/

@interface BibDocument : NSDocument <BDSKGroupTableDelegate, BDSKSearchContentView, BDSKOwner>
{
#pragma mark Main tableview pane variables

    IBOutlet NSWindow *documentWindow;
    IBOutlet BDSKMainTableView *tableView;
    IBOutlet BDSKSplitView *splitView;
    IBOutlet BDSKColoredBox *mainBox;
    IBOutlet NSView *mainView;
    
    IBOutlet BDSKStatusBar *statusBar;
    
    BDSKFileContentSearchController *fileSearchController;
    
    BDSKSearchGroupViewController *searchGroupViewController;
    
    BDSKWebGroupViewController *webGroupViewController;
    
    NSDictionary *tableColumnWidths;
    
#pragma mark Group pane variables

    IBOutlet BDSKGroupTableView *groupTableView;
    IBOutlet BDSKSplitView *groupSplitView;
    IBOutlet BDSKImagePopUpButton *groupActionButton;
    IBOutlet NSButton *groupAddButton;
    IBOutlet BDSKCollapsibleView *groupCollapsibleView;
    IBOutlet BDSKGradientView *groupGradientView;
	NSString *currentGroupField;
    
#pragma mark Side preview variables

    IBOutlet NSTabView *sidePreviewTabView;
    IBOutlet NSTextView *sidePreviewTextView;
    IBOutlet FileView *sideFileView;
    
    IBOutlet BDSKCollapsibleView *fileCollapsibleView;
    IBOutlet BDSKGradientView *fileGradientView;
    
    IBOutlet NSSegmentedControl *sidePreviewButton;
    NSMenu *sideTemplatePreviewMenu;
    
    int sidePreviewDisplay;
    NSString *sidePreviewDisplayTemplate;
    
#pragma mark Bottom preview variables

    IBOutlet NSTabView *bottomPreviewTabView;
    IBOutlet NSTextView *bottomPreviewTextView;
    IBOutlet FileView *bottomFileView;
    BDSKPreviewer *previewer;
	
    IBOutlet NSSegmentedControl *bottomPreviewButton;
    NSMenu *bottomTemplatePreviewMenu;
    
    int bottomPreviewDisplay;
    NSString *bottomPreviewDisplayTemplate;
    
#pragma mark Toolbar variables
    
    NSMutableDictionary *toolbarItems;
	
	IBOutlet BDSKImagePopUpButton * actionMenuButton;
	IBOutlet BDSKImagePopUpButton * groupActionMenuButton;
		
	IBOutlet NSSearchField *searchField;

#pragma mark Custom Cite-String drawer variables
    
    BDSKCustomCiteDrawerController *drawerController;

#pragma mark Sorting variables

    NSString *sortKey;
    NSString *previousSortKey;
    NSString *sortGroupsKey;
    
#pragma mark Menu variables

	IBOutlet NSMenu * groupMenu;
	IBOutlet NSMenu * actionMenu;

#pragma mark Accessory view variables

    IBOutlet NSView *saveAccessoryView;
    IBOutlet NSView *exportAccessoryView;
    IBOutlet BDSKEncodingPopUpButton *saveTextEncodingPopupButton;
    IBOutlet NSButton *exportSelectionCheckButton;
    
#pragma mark Publications and Groups variables

    BDSKPublicationsArray *publications;  // holds all the publications
    NSMutableArray *groupedPublications;  // holds publications in the selected groups
    NSMutableArray *shownPublications;    // holds the ones we want to show.
    // All display related operations should use shownPublications
   
    BDSKGroupsArray *groups;
    
    NSMutableArray *shownFiles;
	
#pragma mark Search group bookmarks

    IBOutlet NSWindow *searchBookmarkSheet;
    IBOutlet NSTextField *searchBookmarkField;
    IBOutlet NSPopUpButton *searchBookmarkPopUp;

#pragma mark Macros, Document Info and Front Matter variables

    BDSKMacroResolver *macroResolver;
    BDSKMacroWindowController *macroWC;
	
    NSMutableDictionary *documentInfo;
    BDSKDocumentInfoWindowController *infoWC;
    
	NSMutableString *frontMatter;    // for preambles, and stuff
	
#pragma mark Copy & Drag related variables

    NSString *promiseDragColumnIdentifier;
    BDSKItemPasteboardHelper *pboardHelper;
    
#pragma mark Scalar state variables

    struct _docState {
        float               lastPreviewHeight;  // for the splitview double-click handling
        float               lastGroupViewWidth;
        float               lastFileViewWidth;
        NSStringEncoding    documentStringEncoding;
        NSSaveOperationType currentSaveOperationType; // used to check for autosave during writeToFile:ofType:
        BOOL                sortDescending;
        BOOL                sortGroupsDescending;
        BOOL                dragFromExternalGroups;
        BOOL                isDocumentClosed;
        BOOL                didImport;
        int                 itemChangeMask;
        BOOL                displayMigrationAlert;
        BOOL                inOptionKeyState;
    } docState;
    
    NSDictionary *mainWindowSetupDictionary;
    
    NSURL *saveTargetURL;
    
    BDSKItemSearchIndexes *searchIndexes;
    BDSKSearchButtonController *searchButtonController;
    BDSKDocumentSearch *documentSearch;
    int rowToSelectAfterDelete;
    NSPoint scrollLocationAfterDelete;
    
    BDSKFileMigrationController *migrationController;
    
}


/*!
@method     init
 @abstract   initializer
 @discussion Sets up initial values. Note that this is called before IBOutlet ivars are connected.
 If you need to set up initial values for those, use awakeFromNib instead.
 @result     A BibDocument, or nil if some serious problem is encountered.
 */
- (id)init;

- (void)saveWindowSetupInExtendedAttributesAtURL:(NSURL *)anURL forSave:(BOOL)isSave;
- (NSDictionary *)mainWindowSetupDictionaryFromExtendedAttributes;
- (BOOL)isMainDocument;

/*!
    @method     clearChangeCount
    @abstract   needed because of finalize changes in BDSKEditor
    @discussion (comprehensive description)
*/
- (void)clearChangeCount;

- (BOOL)writeArchiveToURL:(NSURL *)fileURL forPublications:(NSArray *)items error:(NSError **)outError;

- (NSFileWrapper *)fileWrapperOfType:(NSString *)aType forPublications:(NSArray *)items error:(NSError **)outError;
- (NSData *)dataOfType:(NSString *)aType forPublications:(NSArray *)items error:(NSError **)outError;

- (NSData *)stringDataForPublications:(NSArray *)items usingTemplate:(BDSKTemplate *)template;
- (NSData *)stringDataForPublications:(NSArray *)items publicationsContext:(NSArray *)itemsContext usingTemplate:(BDSKTemplate *)template;
- (NSData *)attributedStringDataForPublications:(NSArray *)items usingTemplate:(BDSKTemplate *)template;
- (NSData *)attributedStringDataForPublications:(NSArray *)items publicationsContext:(NSArray *)itemsContext usingTemplate:(BDSKTemplate *)template;
- (NSData *)dataForPublications:(NSArray *)items usingTemplate:(BDSKTemplate *)template;
- (NSData *)dataForPublications:(NSArray *)items publicationsContext:(NSArray *)itemsContext usingTemplate:(BDSKTemplate *)template;
- (NSFileWrapper *)fileWrapperForPublications:(NSArray *)items usingTemplate:(BDSKTemplate *)template;
- (NSFileWrapper *)fileWrapperForPublications:(NSArray *)items publicationsContext:(NSArray *)itemsContext usingTemplate:(BDSKTemplate *)template;

- (NSData *)atomDataForPublications:(NSArray *)items;
- (NSData *)MODSDataForPublications:(NSArray *)items;
- (NSData *)endNoteDataForPublications:(NSArray *)items;
- (NSData *)bibTeXDataForPublications:(NSArray *)items encoding:(NSStringEncoding)encoding droppingInternal:(BOOL)drop relativeToPath:(NSString *)basePath error:(NSError **)outError;
- (NSData *)RISDataForPublications:(NSArray *)items encoding:(NSStringEncoding)encoding error:(NSError **)error;
- (NSData *)LTBDataForPublications:(NSArray *)items encoding:(NSStringEncoding)encoding error:(NSError **)error;

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)aType encoding:(NSStringEncoding)encoding error:(NSError **)outError;

- (BOOL)readFromBibTeXData:(NSData *)data fromURL:(NSURL *)absoluteURL encoding:(NSStringEncoding)encoding error:(NSError **)outError;
- (BOOL)readFromData:(NSData *)data ofStringType:(int)type fromURL:(NSURL *)absoluteURL encoding:(NSStringEncoding)encoding error:(NSError **)outError;

- (void)reportTemporaryCiteKeys:(NSString *)tmpKey forNewDocument:(BOOL)isNewFile;

// Responses to UI actions

/*!
    @method updatePreviews
    @abstract Updates the document and/or shared previewer if needed. 
    @discussion The actual messages are queued and coalesced, so bulk actions will only update the previews once.
    
*/
- (void)updatePreviews;

/*!
    @method updatePreviewer:
    @abstract Handles updating a previewer.
    @discussion -
    @param aPreviewer The previewer to update
    
*/
- (void)updatePreviewer:(BDSKPreviewer *)aPreviewer;

- (void)updateBottomPreviewPane;
- (void)updateSidePreviewPane;

/*!
	@method bibTeXStringForPublications
	@abstract auxiliary method for generating bibtex string for publication items
	@discussion generates appropriate bibtex string from the document's current selection by calling bibTeXStringDroppingInternal:droppingInternal:.
*/
- (NSString *)bibTeXStringForPublications:(NSArray *)items;

/*!
	@method bibTeXStringDroppingInternal:forPublications:
	@abstract auxiliary method for generating bibtex string for publication items
	@discussion generates appropriate bibtex string from given items.
*/
- (NSString *)bibTeXStringDroppingInternal:(BOOL)drop forPublications:(NSArray *)items;

/*!
	@method previewBibTeXStringForPublications:
	@abstract auxiliary method for generating bibtex string for publication items to use for generating RTF or PDF data
	@discussion generates appropriate bibtex string from given items.
*/
- (NSString *)previewBibTeXStringForPublications:(NSArray *)items;

/*!
	@method RISStringForPublications:
	@abstract auxiliary method for generating RIS string for publication items
	@discussion generates appropriate RIS string from given items.
*/
- (NSString *)RISStringForPublications:(NSArray *)items;

/*!
	@method citeStringForPublications:citeString:
	@abstract  method for generating cite string
	@discussion generates appropriate cite command from the given items 
*/

- (NSString *)citeStringForPublications:(NSArray *)items citeString:(NSString *)citeString;

/*!
    @method setPublications
    @abstract Sets the publications array
    @discussion Simply replaces the publications array
    @param newPubs The new array.
*/
- (void)setPublications:(NSArray *)newPubs;

/*!
    @method publications
 @abstract Returns the publications array.
    @discussion Returns the publications array.
    
*/
- (BDSKPublicationsArray *)publications;
- (NSArray *)shownPublications;

- (BDSKGroupsArray *)groups;
- (void)getCopyOfPublicationsOnMainThread:(NSMutableArray *)dstArray;
- (void)getCopyOfMacrosOnMainThread:(NSMutableDictionary *)dstDict;
- (void)insertPublications:(NSArray *)pubs atIndexes:(NSIndexSet *)indexes;
- (void)insertPublication:(BibItem *)pub atIndex:(unsigned int)index;

- (void)addPublications:(NSArray *)pubArray;
- (void)addPublication:(BibItem *)pub;

- (void)removePublicationsAtIndexes:(NSIndexSet *)indexes;
- (void)removePublications:(NSArray *)pubs;
- (void)removePublication:(BibItem *)pub;

- (NSDictionary *)documentInfo;
- (void)setDocumentInfoWithoutUndo:(NSDictionary *)dict;
- (void)setDocumentInfo:(NSDictionary *)dict;
- (NSString *)documentInfoForKey:(NSString *)key;
- (id)valueForUndefinedKey:(NSString *)key;
- (NSString *)documentInfoString;

#pragma mark bibtex macro support

- (BDSKMacroResolver *)macroResolver;

- (void)handleMacroChangedNotification:(NSNotification *)aNotification;

/* Paste related methods */
- (void)addPublications:(NSArray *)newPubs publicationsToAutoFile:(NSArray *)pubsToAutoFile temporaryCiteKey:(NSString *)tmpCiteKey selectLibrary:(BOOL)shouldSelect edit:(BOOL)shouldEdit;
- (BOOL)addPublicationsFromPasteboard:(NSPasteboard *)pb selectLibrary:(BOOL)select verbose:(BOOL)verbose error:(NSError **)error;
- (BOOL)addPublicationsFromFile:(NSString *)fileName verbose:(BOOL)verbose error:(NSError **)outError;
- (NSArray *)publicationsFromArchivedData:(NSData *)data;
- (NSArray *)publicationsForString:(NSString *)string type:(int)type verbose:(BOOL)verbose error:(NSError **)error;
- (NSArray *)publicationsForFiles:(NSArray *)filenames error:(NSError **)error;
- (NSArray *)extractPublicationsFromFiles:(NSArray *)filenames unparseableFiles:(NSMutableArray *)unparseableFiles verbose:(BOOL)verbose error:(NSError **)error;
- (NSArray *)publicationsForURLFromPasteboard:(NSPasteboard *)pboard error:(NSError **)error;

// Private methods

/*!
    @method updateStatus
    @abstract Updates the status message
    @discussion -
*/
- (void)updateStatus;

/*!
    @method     sortPubsByKey:
    @abstract   Sorts the publications table by the given key.  Pass nil for the table column to re-sort the previously sorted column with the same order.
    @discussion (comprehensive description)
    @param      key (description)
*/
- (void)sortPubsByKey:(NSString *)key;

/*!
    @method     columnsMenu
    @abstract   Returnes the columns menu
    @discussion (comprehensive description)
*/
- (NSMenu *)columnsMenu;

- (void)registerForNotifications;

- (void)handleTeXPreviewNeedsUpdateNotification:(NSNotification *)notification;
- (void)handleUsesTeXChangedNotification:(NSNotification *)notification;
- (void)handleIgnoredSortTermsChangedNotification:(NSNotification *)notification;
- (void)handleNameDisplayChangedNotification:(NSNotification *)notification;
- (void)handleFlagsChangedNotification:(NSNotification *)notification;
- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification;
- (void)handleTableSelectionChangedNotification:(NSNotification *)notification;

// notifications observed on behalf of owned BibItems for efficiency
- (void)handleCustomFieldsDidChangeNotification:(NSNotification *)notification;

- (void)handleTemporaryFileMigrationNotification:(NSNotification *)notification;

/*!
    @method     handleBibItemAddDelNotification:
    @abstract   this method gets called for setPublications: also
    @discussion (comprehensive description)
    @param      notification (description)
*/
- (void)handleBibItemAddDelNotification:(NSNotification *)notification;

	
/*!
    @method handleBibItemChangedNotification
	 @abstract responds to changing bib data
	 @discussion 
*/
- (void)handleBibItemChangedNotification:(NSNotification *)notification;

- (void)handleSkimFileDidSaveNotification:(NSNotification *)notification;

/*!
    @method     numberOfSelectedPubs
    @abstract   (description)
    @discussion (description)
    @result     the number of currently selected pubs in the doc
*/
- (int)numberOfSelectedPubs;

/*!
    @method     selectedPublications
    @abstract   (description)
    @discussion (description)
    @result     an array of the currently selected pubs in the doc
*/
- (NSArray *)selectedPublications;

- (BOOL)selectItemsForCiteKeys:(NSArray *)citeKeys selectLibrary:(BOOL)flag;
- (BOOL)selectItemForPartialItem:(NSDictionary *)partialItem;

- (void)selectPublication:(BibItem *)bib;

- (void)selectPublications:(NSArray *)bibArray;

- (NSArray *)selectedFileURLs;

- (NSArray *)shownFiles;
- (void)updateFileViews;

- (void)setStatus:(NSString *)status;
- (void)setStatus:(NSString *)status immediate:(BOOL)now;

- (BOOL)isDisplayingSearchButtons;
- (BOOL)isDisplayingFileContentSearch;
- (BOOL)isDisplayingSearchGroupView;
- (BOOL)isDisplayingWebGroupView;

- (void)insertControlView:(NSView *)controlView atTop:(BOOL)atTop;
- (void)removeControlView:(NSView *)controlView;

- (NSStringEncoding)documentStringEncoding;
- (void)setDocumentStringEncoding:(NSStringEncoding)encoding;

/*!
    @method     saveSortOrder
    @abstract   Saves current sort order to preferences, to be restored on next launch/document open.
    @discussion (comprehensive description)
*/
- (void)saveSortOrder;

/*!
    @method     userChangedField:ofPublications:from:to:
    @abstract   Autofiles and generates citekey if we should and runs a script hook
    @discussion (comprehensive description)
    @result     Mask indicating what was autogenerated: 1 for autogenerating cite key, 2 for autofile
*/
- (int)userChangedField:(NSString *)fieldName ofPublications:(NSArray *)pubs from:(NSArray *)oldValues to:(NSArray *)newValues;

- (void)userAddedURL:(NSURL *)aURL forPublication:(BibItem *)pub;
- (void)userRemovedURL:(NSURL *)aURL forPublication:(BibItem *)pub;

@end

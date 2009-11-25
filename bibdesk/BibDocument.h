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
#import "BDSKOwnerProtocol.h"
#import "BDSKUndoManager.h"
#import "BDSKItemPasteboardHelper.h"

@class BibItem, BibAuthor, BDSKGroup, BDSKStaticGroup, BDSKSmartGroup, BDSKTemplate, BDSKPublicationsArray, BDSKGroupsArray;
@class AGRegex, BDSKMacroResolver;
@class BDSKEditor, BDSKMacroWindowController, BDSKDocumentInfoWindowController, BDSKPreviewer, BDSKFileContentSearchController, BDSKCustomCiteDrawerController, BDSKSearchGroupViewController;
@class BDSKStatusBar, BDSKMainTableView, BDSKGroupOutlineView, BDSKGradientView, BDSKCollapsibleView, BDSKEdgeView, BDSKImagePopUpButton, BDSKColoredView, BDSKEncodingPopUpButton, BDSKZoomablePDFView, FVFileView;
@class BDSKWebGroupViewController, BDSKSearchButtonController;
@class BDSKItemSearchIndexes, BDSKNotesSearchIndex, BDSKFileMigrationController, BDSKDocumentSearch;

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

@interface BibDocument : NSDocument <BDSKOwner, BDSKUndoManagerDelegate, BDSKItemPasteboardHelperDelegate>
{
#pragma mark Main tableview pane variables

    IBOutlet NSWindow *documentWindow;
    IBOutlet BDSKMainTableView *tableView;
    IBOutlet NSSplitView *splitView;
    IBOutlet BDSKColoredView *mainBox;
    IBOutlet NSView *mainView;
    IBOutlet BDSKStatusBar *statusBar;
    
    BDSKFileContentSearchController *fileSearchController;
    
    BDSKSearchGroupViewController *searchGroupViewController;
    
    BDSKWebGroupViewController *webGroupViewController;
    
    NSDictionary *tableColumnWidths;
    
#pragma mark Group pane variables

    IBOutlet BDSKGroupOutlineView *groupOutlineView;
    IBOutlet NSSplitView *groupSplitView;
    IBOutlet NSPopUpButton *groupActionButton;
    IBOutlet NSPopUpButton *groupAddButton;
    IBOutlet BDSKCollapsibleView *groupButtonView;
    IBOutlet NSMenu *groupFieldMenu;
	NSString *currentGroupField;
    NSMapTable *groupSpinners;
    
#pragma mark Side preview variables

    IBOutlet NSTabView *sidePreviewTabView;
    IBOutlet NSTextView *sidePreviewTextView;
    IBOutlet FVFileView *sideFileView;
    
    IBOutlet NSSegmentedControl *sidePreviewButton;
    NSMenu *sideTemplatePreviewMenu;
    
    NSInteger sidePreviewDisplay;
    NSString *sidePreviewDisplayTemplate;
    
#pragma mark Bottom preview variables

    IBOutlet NSTabView *bottomPreviewTabView;
    IBOutlet NSTextView *bottomPreviewTextView;
    IBOutlet FVFileView *bottomFileView;
    BDSKPreviewer *previewer;
	
    IBOutlet NSSegmentedControl *bottomPreviewButton;
    NSMenu *bottomTemplatePreviewMenu;
    
    NSInteger bottomPreviewDisplay;
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
	IBOutlet NSMenu * copyAsMenu;

#pragma mark Accessory view variables

    IBOutlet NSView *saveAccessoryView;
    IBOutlet NSView *exportAccessoryView;
    IBOutlet BDSKEncodingPopUpButton *saveTextEncodingPopupButton;
    IBOutlet NSButton *exportSelectionCheckButton;
    NSPopUpButton *saveFormatPopupButton;
    
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
        CGFloat             lastPreviewHeight;  // for the splitview double-click handling
        CGFloat             lastGroupViewWidth;
        CGFloat             lastFileViewWidth;
        CGFloat             lastWebViewFraction;
        NSStringEncoding    documentStringEncoding;
        NSSaveOperationType currentSaveOperationType; // used to check for autosave during writeToFile:ofType:
    } docState;
    
    struct _docFlags {
        unsigned int        itemChangeMask:4;
        unsigned int        sortDescending:1;
        unsigned int        previousSortDescending:1;
        unsigned int        sortGroupsDescending:1;
        unsigned int        dragFromExternalGroups:1;
        unsigned int        isDocumentClosed:1;
        unsigned int        didImport:1;
        unsigned int        displayMigrationAlert:1;
        unsigned int        inOptionKeyState:1;
        unsigned int        isAnimating:1;
    } docFlags;
    
    NSDictionary *mainWindowSetupDictionary;
    
    NSURL *saveTargetURL;
    
    BDSKItemSearchIndexes *searchIndexes;
    BDSKNotesSearchIndex *notesSearchIndex;
    BDSKSearchButtonController *searchButtonController;
    BDSKDocumentSearch *documentSearch;
    NSInteger rowToSelectAfterDelete;
    NSPoint scrollLocationAfterDelete;
    
    BDSKFileMigrationController *migrationController;
    
    NSString *uniqueID;
}


/*!
@method     init
 @abstract   initializer
 @discussion Sets up initial values. Note that this is called before IBOutlet ivars are connected.
 If you need to set up initial values for those, use awakeFromNib instead.
 @result     A BibDocument, or nil if some serious problem is encountered.
 */
- (id)init;

- (void)saveWindowSetupInExtendedAttributesAtURL:(NSURL *)anURL forEncoding:(NSStringEncoding)encoding;
- (NSDictionary *)mainWindowSetupDictionaryFromExtendedAttributes;
- (BOOL)isMainDocument;
- (BOOL)commitPendingEdits;

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

- (BOOL)readFromBibTeXData:(NSData *)data fromURL:(NSURL *)absoluteURL encoding:(NSStringEncoding)encoding error:(NSError **)outError;
- (BOOL)readFromData:(NSData *)data ofStringType:(NSInteger)type fromURL:(NSURL *)absoluteURL encoding:(NSStringEncoding)encoding error:(NSError **)outError;

- (void)reportTemporaryCiteKeys:(NSString *)tmpKey forNewDocument:(BOOL)isNewFile;

- (void)markAsImported;

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
- (void)insertPublications:(NSArray *)pubs atIndexes:(NSIndexSet *)indexes;
- (void)insertPublication:(BibItem *)pub atIndex:(NSUInteger)index;

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

/* Paste related methods */
- (void)addPublications:(NSArray *)newPubs publicationsToAutoFile:(NSArray *)pubsToAutoFile temporaryCiteKey:(NSString *)tmpCiteKey selectLibrary:(BOOL)shouldSelect edit:(BOOL)shouldEdit;
- (BOOL)addPublicationsFromPasteboard:(NSPasteboard *)pb selectLibrary:(BOOL)select verbose:(BOOL)verbose error:(NSError **)error;
- (BOOL)addPublicationsFromFile:(NSString *)fileName verbose:(BOOL)verbose error:(NSError **)outError;
- (NSArray *)publicationsFromArchivedData:(NSData *)data;
- (NSArray *)publicationsForString:(NSString *)string type:(NSInteger)type verbose:(BOOL)verbose error:(NSError **)error;
- (NSArray *)publicationsForFiles:(NSArray *)filenames error:(NSError **)error;
- (NSArray *)extractPublicationsFromFiles:(NSArray *)filenames unparseableFiles:(NSMutableArray *)unparseableFiles verbose:(BOOL)verbose error:(NSError **)error;
- (NSArray *)publicationsForURLFromPasteboard:(NSPasteboard *)pboard error:(NSError **)error;

// Private methods

/*!
    @method     sortPubsByKey:
    @abstract   Sorts the publications table by the given key.  Pass nil for the table column to re-sort the previously sorted column with the same order.
    @discussion (comprehensive description)
    @param      key (description)
*/
- (void)sortPubsByKey:(NSString *)key;

/*!
    @method     numberOfSelectedPubs
    @abstract   (description)
    @discussion (description)
    @result     the number of currently selected pubs in the doc
*/
- (NSInteger)numberOfSelectedPubs;

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

- (NSStringEncoding)documentStringEncoding;
- (void)setDocumentStringEncoding:(NSStringEncoding)encoding;

/*!
    @method     saveSortOrder
    @abstract   Saves current sort order to preferences, to be restored on next launch/document open.
    @discussion (comprehensive description)
*/
- (void)saveSortOrder;

- (BOOL)openURL:(NSURL *)aURL;

/*!
    @method     userChangedField:ofPublications:from:to:
    @abstract   Autofiles and generates citekey if we should and runs a script hook
    @discussion (comprehensive description)
    @result     Mask indicating what was autogenerated: 1 for autogenerating cite key, 2 for autofile
*/
- (NSInteger)userChangedField:(NSString *)fieldName ofPublications:(NSArray *)pubs from:(NSArray *)oldValues to:(NSArray *)newValues;

- (void)userAddedURL:(NSURL *)aURL forPublication:(BibItem *)pub;
- (void)userRemovedURL:(NSURL *)aURL forPublication:(BibItem *)pub;

@end

#pragma mark -

// forward declare all IBAction actions, because IB currently does not support categories defined in other headers
@interface BibDocument (IBActions)

- (IBAction)createNewPubUsingCrossrefAction:(id)sender;
- (IBAction)newPub:(id)sender;
- (IBAction)deleteSelectedPubs:(id)sender;
- (IBAction)removeSelectedPubs:(id)sender;
- (IBAction)copyAsAction:(id)sender;
- (IBAction)duplicate:(id)sender;
- (IBAction)editPubCmd:(id)sender;
- (IBAction)emailPubCmd:(id)sender;
- (IBAction)sendToLyX:(id)sender;
- (IBAction)postItemToWeblog:(id)sender;
- (IBAction)openLocalURL:(id)sender;
- (IBAction)revealLocalURL:(id)sender;
- (IBAction)openRemoteURL:(id)sender;
- (IBAction)showNotesForLocalURL:(id)sender;
- (IBAction)copyNotesForLocalURL:(id)sender;
- (IBAction)openLinkedFile:(id)sender;
- (IBAction)revealLinkedFile:(id)sender;
- (IBAction)openLinkedURL:(id)sender;
- (IBAction)showNotesForLinkedFile:(id)sender;
- (IBAction)copyNotesForLinkedFile:(id)sender;
- (IBAction)chooseLinkedFile:(id)sender;
- (IBAction)chooseLinkedURL:(id)sender;
- (IBAction)previewAction:(id)sender;
- (IBAction)migrateFiles:(id)sender;
- (IBAction)selectAllPublications:(id)sender;
- (IBAction)deselectAllPublications:(id)sender;
- (IBAction)toggleGroups:(id)sender;
- (IBAction)toggleSidebar:(id)sender;
- (IBAction)toggleStatusBar:(id)sender;
- (IBAction)changeMainTableFont:(id)sender;
- (IBAction)changeGroupTableFont:(id)sender;
- (IBAction)changePreviewDisplay:(id)sender;
- (IBAction)changeSidePreviewDisplay:(id)sender;
- (IBAction)toggleShowingCustomCiteDrawer:(id)sender;
- (IBAction)showDocumentInfoWindow:(id)sender;
- (IBAction)showMacrosWindow:(id)sender;
- (IBAction)refreshSharing:(id)sender;
- (IBAction)refreshSharedBrowsing:(id)sender;
- (IBAction)importFromPasteboardAction:(id)sender;
- (IBAction)importFromFileAction:(id)sender;
- (IBAction)importFromWebAction:(id)sender;
- (IBAction)consolidateLinkedFiles:(id)sender;
- (IBAction)generateCiteKey:(id)sender;
- (IBAction)sortForCrossrefs:(id)sender;
- (IBAction)selectCrossrefParentAction:(id)sender;
- (IBAction)duplicateTitleToBooktitle:(id)sender;
- (IBAction)selectPossibleDuplicates:(id)sender;
- (IBAction)selectDuplicates:(id)sender;
- (IBAction)selectIncompletePublications:(id)sender;

- (IBAction)changeGroupFieldAction:(id)sender;
- (IBAction)addGroupFieldAction:(id)sender;
- (IBAction)removeGroupFieldAction:(id)sender;
- (IBAction)sortGroupsByGroup:(id)sender;
- (IBAction)sortGroupsByCount:(id)sender;
- (IBAction)addSmartGroupAction:(id)sender;
- (IBAction)addStaticGroupAction:(id)sender;
- (IBAction)addURLGroupAction:(id)sender;
- (IBAction)addScriptGroupAction:(id)sender;
- (IBAction)addSearchGroupAction:(id)sender;
- (IBAction)newSearchGroupFromBookmark:(id)sender;
- (IBAction)addSearchBookmark:(id)sender;
- (IBAction)dismissSearchBookmarkSheet:(id)sender;
- (IBAction)removeSelectedGroups:(id)sender;
- (IBAction)editGroupAction:(id)sender;
- (IBAction)renameGroupAction:(id)sender;
- (IBAction)copyGroupURLAction:(id)sender;
- (IBAction)selectLibraryGroup:(id)sender;
- (IBAction)changeIntersectGroupsAction:(id)sender;
- (IBAction)editNewStaticGroupWithSelection:(id)sender;
- (IBAction)editNewCategoryGroupWithSelection:(id)sender;
- (IBAction)mergeInExternalGroup:(id)sender;
- (IBAction)mergeInExternalPublications:(id)sender;
- (IBAction)refreshURLGroups:(id)sender;
- (IBAction)refreshScriptGroups:(id)sender;
- (IBAction)refreshSearchGroups:(id)sender;
- (IBAction)refreshAllExternalGroups:(id)sender;
- (IBAction)refreshSelectedGroups:(id)sender;
- (IBAction)openBookmark:(id)sender;
- (IBAction)addBookmark:(id)sender;

- (IBAction)makeSearchFieldKey:(id)sender;
- (IBAction)changeSearchType:(id)sender;
- (IBAction)search:(id)sender;
- (IBAction)searchByContent:(id)sender;

@end

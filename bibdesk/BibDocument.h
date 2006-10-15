//  BibDocument.h

//  Created by Michael McCracken on Mon Dec 17 2001.
/*
 This software is Copyright (c) 2001,2002,2003,2004,2005,2006
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

@protocol BDSKGroupTableDelegate, BDSKSearchContentView, BDSKTemplateParserDelegate;

@class BibItem, BibAuthor, BDSKGroup, BDSKStaticGroup, BDSKSmartGroup, BDSKTemplate;
@class AGRegex, BDSKTeXTask, BDSKMacroResolver;
@class BibEditor, MacroWindowController, BDSKDocumentInfoWindowController;
@class BDSKAlert, BDSKStatusBar, BDSKMainTableView, BDSKGroupTableView, BDSKGradientView, BDSKSplitView, BDSKCollapsibleView, BDSKImagePopUpButton;

enum {
	BDSKOperationIgnore = NSAlertDefaultReturn, // 1
	BDSKOperationSet = NSAlertAlternateReturn, // 0
	BDSKOperationAppend = NSAlertOtherReturn, // -1
	BDSKOperationAsk = NSAlertErrorReturn, // -2
};

// these should correspond to the tags of copy-as menu items, as well as the default drag/copy type
enum {
	BDSKBibTeXDragCopyType, 
	BDSKCiteDragCopyType, 
	BDSKPDFDragCopyType, 
	BDSKRTFDragCopyType, 
	BDSKLaTeXDragCopyType, 
	BDSKLTBDragCopyType, 
	BDSKMinimalBibTeXDragCopyType, 
	BDSKRISDragCopyType,
    BDSKTemplateDragCopyType
};

// our main document types
extern NSString *BDSKBibTeXDocumentType;
extern NSString *BDSKRISDocumentType;
extern NSString *BDSKMinimalBibTeXDocumentType;
extern NSString *BDSKWOSDocumentType;
extern NSString *BDSKLTBDocumentType;
extern NSString *BDSKAtomDocumentType;

// Some pasteboard types used by the document for dragging and copying.
extern NSString* BDSKReferenceMinerStringPboardType; // pasteboard type from Reference Miner, determined using Pasteboard Peeker
extern NSString *BDSKBibItemPboardType;
extern NSString* BDSKWeblocFilePboardType; // core pasteboard type for webloc files

/*!
    @class BibDocument
    @abstract Controller class for .bib files
    @discussion This is the document class. It keeps an array of BibItems (called (NSMutableArray *)publications) and handles the quick search box. It delegates PDF generation to a BDSKPreviewer.
*/

@interface BibDocument : NSDocument <BDSKGroupTableDelegate, BDSKSearchContentView>
{
    IBOutlet NSTextView *previewField;
    IBOutlet NSWindow* documentWindow;
    IBOutlet BDSKMainTableView *tableView;
    IBOutlet NSMenuItem *ctxCopyBibTex;
    IBOutlet NSMenuItem *ctxCopyTex;
    IBOutlet NSMenuItem *ctxCopyPDF;
    IBOutlet BDSKSplitView* splitView;
    IBOutlet NSBox* mainBox;
    // for the splitview double-click handling
    float lastPreviewHeight;
	
#pragma mark Toolbar variable declarations

    NSMutableDictionary *toolbarItems;
    NSToolbarItem *editPubButton;
    NSToolbarItem *delPubButton;
	
#pragma mark SearchField variable declarations
		
	IBOutlet NSSearchField *searchField; 
	NSToolbarItem *searchFieldToolbarItem;

    IBOutlet BDSKStatusBar *statusBar;

#pragma mark Custom Cite-String drawer variable declarations:

    IBOutlet NSDrawer* customCiteDrawer;
    IBOutlet NSTableView* ccTableView;
    IBOutlet NSButton *addCustomCiteStringButton;
    IBOutlet NSButton *removeCustomCiteStringButton;
    NSMutableArray* customStringArray;
	BOOL showingCustomCiteDrawer;
    
    NSMutableArray *publications;    // holds all the publications
    NSMutableArray *shownPublications;    // holds the ones we want to show.
    // All display related operations should use shownPublications
    // in aspect oriented objective c i could have coded that assertion!

    NSString *quickSearchKey;
   
	NSMutableString *frontMatter;    // for preambles, and stuff
    NSTableColumn *lastSelectedColumnForSort;
    NSString *sortGroupsKey;
    BOOL sortDescending;
    BOOL sortGroupsDescending;
	
	BDSKTeXTask *texTask;
	
    // --------------------------------------------------------------------------------------
	IBOutlet NSMenu * fileMenu;
	IBOutlet NSMenu * URLMenu;
	IBOutlet NSMenu * groupMenu;
	IBOutlet NSMenu * actionMenu;
	IBOutlet BDSKImagePopUpButton * actionMenuButton;
	IBOutlet BDSKImagePopUpButton * groupActionMenuButton;
	IBOutlet NSMenuItem * actionMenuFirstItem;

    // ----------------------------------------------------------------------------------------
    // stuff for the accessory views
    IBOutlet NSView *saveAccessoryView;
    IBOutlet NSView *exportAccessoryView;
    IBOutlet NSPopUpButton *saveTextEncodingPopupButton;
    IBOutlet NSButton *exportSelectionCheckButton;
    NSStringEncoding documentStringEncoding;
	
    BDSKMacroResolver *macroResolver;
    MacroWindowController *macroWC;
	
    NSMutableDictionary *documentInfo;
    BDSKDocumentInfoWindowController *infoWC;
    
    OFMultiValueDictionary *itemsForCiteKeys;
    
    NSString *promiseDragColumnIdentifier;

    IBOutlet BDSKGroupTableView *groupTableView;
    NSMutableArray *categoryGroups;
    NSMutableArray *smartGroups;
    NSMutableArray *staticGroups;
    NSMutableArray *tmpStaticGroups;
    NSMutableArray *groupedPublications;
	BDSKGroup *allPublicationsGroup;
	BDSKStaticGroup *lastImportGroup;
	NSString *currentGroupField;
    IBOutlet BDSKSplitView *groupSplitView;
	float lastGroupViewWidth;
    
    IBOutlet BDSKImagePopUpButton *groupActionButton;
    IBOutlet NSButton *groupAddButton;
    IBOutlet BDSKCollapsibleView *groupCollapsibleView;
    IBOutlet BDSKGradientView *groupGradientView;
    
    BOOL dragFromSharedGroups;
    NSMutableArray *sharedGroups;
    NSMutableDictionary *sharedGroupSpinners;
    
    id fileSearchController;
	
	NSMutableDictionary *promisedPboardTypes;
    NSSaveOperationType currentSaveOperationType; // used to check for autosave during writeToFile:ofType:
    
    BOOL isDocumentClosed;
}


/*!
@method     init
 @abstract   initializer
 @discussion Sets up initial values. Note that this is called before IBOutlet ivars are connected.
 If you need to set up initial values for those, use awakeFromNib instead.
 @result     A BibDocument, or nil if some serious problem is encountered.
 */
- (id)init;


/*!
    @method     awakeFromNib
    @abstract   Called when the document's nib is finished loading. Don't call this directly.
    @discussion Put things here that need to be done once, as soon as the window is loaded but before it is shown.
*/
- (void)awakeFromNib;

/*!
    @method     dealloc
    @abstract   Releases memory reserved by the BibDocument. 
 @discussion Don't call this. 
 It will be called automatically at the end of the object's lifetime.

*/
- (void)dealloc;

/*!
    @method     publicationsForAuthor:
    @abstract   Returns publications that an author is connected to
    @discussion ...
    @param      anAuthor A BibAuthor that may be connected to a pub in this document.
    @result     An array of BibItems that the author is connected to.
*/
- (NSArray *)publicationsForAuthor:(BibAuthor *)anAuthor;

/*!
    @method     clearChangeCount
    @abstract   needed because of finalize changes in BibEditor
    @discussion (comprehensive description)
*/
- (void)clearChangeCount;

- (NSFileWrapper *)fileWrapperOfType:(NSString *)aType forPublications:(NSArray *)items error:(NSError **)outError;
- (NSData *)dataOfType:(NSString *)aType forPublications:(NSArray *)items error:(NSError **)outError;

- (NSData *)stringDataForPublications:(NSArray *)items usingTemplate:(BDSKTemplate *)template;
- (NSData *)attributedStringDataForPublications:(NSArray *)items usingTemplate:(BDSKTemplate *)template;
- (NSFileWrapper *)fileWrapperForPublications:(NSArray *)items usingTemplate:(BDSKTemplate *)template;

- (NSData *)atomDataForPublications:(NSArray *)items;
- (NSData *)MODSDataForPublications:(NSArray *)items;
- (NSData *)endNoteDataForPublications:(NSArray *)items;
- (NSData *)bibTeXDataForPublications:(NSArray *)items encoding:(NSStringEncoding)encoding droppingInternal:(BOOL)drop error:(NSError **)outError;
- (NSData *)RISDataForPublications:(NSArray *)items encoding:(NSStringEncoding)encoding error:(NSError **)error;
- (NSData *)LTBDataForPublications:(NSArray *)items encoding:(NSStringEncoding)encoding error:(NSError **)error;

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)aType encoding:(NSStringEncoding)encoding error:(NSError **)outError;

- (BOOL)readFromBibTeXData:(NSData *)data fromURL:(NSURL *)absoluteURL encoding:(NSStringEncoding)encoding error:(NSError **)outError;
- (BOOL)readFromData:(NSData *)data ofStringType:(int)type fromURL:(NSURL *)absoluteURL encoding:(NSStringEncoding)encoding error:(NSError **)outError;

- (void)reportTemporaryCiteKeys:(NSString *)tmpKey forNewDocument:(BOOL)isNewFile;

// Responses to UI actions

/*!
    @method updatePreviews
    @abstract updates views because pub selection changed
    @discussion proxy for outline/tableview-selectiondidchange. - not the best name for this method, since it does more than update previews...
    
*/
- (void)updatePreviews:(NSNotification *)aNotification;



/*!
    @method displayPreviewForItems
    @abstract Handles writing the preview pane. (Not the PDF Preview)
    @discussion itemIndexes is an array of NSNumbers that are the row indices of the selected items.
    
*/
- (void)displayPreviewForItems:(NSArray *)itemIndexes;

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
- (NSMutableArray *)publications;
- (void)getCopyOfPublicationsOnMainThread:(NSMutableArray *)dstArray;
- (void)insertPublications:(NSArray *)pubs atIndexes:(NSIndexSet *)indexes;
- (void)insertPublication:(BibItem *)pub atIndex:(unsigned int)index;

- (void)addPublications:(NSArray *)pubArray;
- (void)addPublication:(BibItem *)pub;

- (void)removePublicationsAtIndexes:(NSIndexSet *)indexes;
- (void)removePublications:(NSArray *)pubs;
- (void)removePublication:(BibItem *)pub;
- (NSNumber *)fileOrderOfPublication:(BibItem *)thePub;

- (NSDictionary *)documentInfo;
- (void)setDocumentInfoWithoutUndo:(NSDictionary *)dict;
- (void)setDocumentInfo:(NSDictionary *)dict;
- (NSString *)documentInfoForKey:(NSString *)key;
- (void)setDocumentInfo:(NSString *)value forKey:(NSString *)key;
- (id)valueForUndefinedKey:(NSString *)key;
- (NSString *)documentInfoString;
- (IBAction)showDocumentInfoWindow:(id)sender;

#pragma mark bibtex macro support

- (BDSKMacroResolver *)macroResolver;

- (IBAction)showMacrosWindow:(id)sender;

- (void)handleMacroChangedNotification:(NSNotification *)aNotification;

- (BOOL)citeKeyIsCrossreffed:(NSString *)key;

- (void)changeCrossrefKey:(NSString *)oldKey toKey:(NSString *)newKey;

- (void)invalidateGroupsForCrossreffedCiteKey:(NSString *)key;

- (void)rebuildItemsForCiteKeys;
- (void)addToItemsForCiteKeys:(NSArray *)pubs;
- (void)removeFromItemsForCiteKeys:(NSArray *)pubs;

/*!
    @method     itemsForCiteKeys
    @abstract   Returns a dictionary of publications for cite keys. It can have multiple items for a single key.
    @discussion Keys are case insensitive. Always use this accessor, not the ivar itself, as the ivar is build in this method. 
    @result     (description)
*/
- (OFMultiValueDictionary *)itemsForCiteKeys;

/*!
    @method     publicationForCiteKey:
    @abstract   Returns a publication matching the given citekey, using a case-insensitive comparison.
    @discussion Used for finding parent items for crossref lookups, which require case-insensitivity in cite-keys.
                The case conversion is handled by this method, though, and the caller shouldn't be concerned with it.
    @param      key (description)
    @result     (description)
*/
- (BibItem *)publicationForCiteKey:(NSString *)key;

- (NSArray *)allPublicationsForCiteKey:(NSString *)key;

    /*!
@method citeKeyIsUsed:byItemOtherThan
     @abstract tells whether aCiteKey is in the dict.
     @discussion ...

     */
- (BOOL)citeKeyIsUsed:(NSString *)aCiteKey byItemOtherThan:(BibItem *)anItem;

/* Paste related methods */
- (BOOL)addPublicationsFromPasteboard:(NSPasteboard *)pb error:(NSError **)error;
- (NSArray *)newPublicationsFromArchivedData:(NSData *)data;
- (NSArray *)newPublicationsForString:(NSString *)string type:(int)type error:(NSError **)error;
- (NSArray *)newPublicationsForFiles:(NSArray *)filenames error:(NSError **)error;
- (NSArray *)extractPublicationsFromFiles:(NSArray *)filenames unparseableFiles:(NSMutableArray *)unparseableFiles error:(NSError **)error;
- (NSArray *)newPublicationForURL:(NSURL *)url error:(NSError **)error;

// Private methods

- (void)handleTableSelectionChangedNotification:(NSNotification *)notification;

/*!
    @method updateUI
    @abstract Updates user interface elements
    @discussion Mainly, tells tableview to reload data and calls tableviewselectiondidchange.
*/
- (void)updateUI;

/*!
    @method setupTableColumns
    @abstract \253Abstract\273
    @discussion \253discussion\273
    
*/
- (void)setupTableColumns;

/*!
    @method     sortPubsByColumn:
    @abstract   Sorts the publications table by the given table column.  Pass nil for the table column to re-sort the previously sorted column with the same order.
    @discussion (comprehensive description)
    @param      tableColumn (description)
*/
- (void)sortPubsByColumn:(NSTableColumn *)tableColumn;

/*!
    @method     sortTableByDefaultColumn
    @abstract   Sorts the pubs table by the last column saved to user defaults (saved when a doc window closes).
    @discussion (comprehensive description)
*/
- (void)sortPubsByDefaultColumn;

/*!
    @method columnsMenuSelectTableColumn
    @abstract handles when we choose an already-existing tablecolumn name in the menu
    @discussion \253discussion\273
    
*/
- (IBAction)columnsMenuSelectTableColumn:(id)sender;
/*!
    @method columnsMenuAddTableColumn
    @abstract called by the "add other..." menu item
    @discussion \253discussion\273
    
*/
- (IBAction)columnsMenuAddTableColumn:(id)sender;

/*!
    @method handleTableColumnChangedNotification
    @abstract incorporates changes from other windows.
    @discussion 
    
*/
- (void)handleTableColumnChangedNotification:(NSNotification *)notification;

/*!
    @method     handlePreviewDisplayChangedNotification:
    @abstract   only supposed to handle the pretty-printed preview, /not/ the TeX preview
    @discussion (comprehensive description)
    @param      notification (description)
*/
- (void)handlePreviewDisplayChangedNotification:(NSNotification *)notification;
- (void)handleIgnoredSortTermsChangedNotification:(NSNotification *)notification;
- (void)handleNameDisplayChangedNotification:(NSNotification *)notification;
- (void)handleFlagsChangedNotification:(NSNotification *)notification;
- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification;

// notifications observed on behalf of owned BibItems for efficiency
- (void)handleTypeInfoDidChangeNotification:(NSNotification *)notification;
- (void)handleCustomFieldsDidChangeNotification:(NSNotification *)notification;
    
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


- (BOOL)highlightItemForPartialItem:(NSDictionary *)partialItem;

- (void)highlightBib:(BibItem *)bib;

- (void)highlightBibs:(NSArray *)bibArray;

- (void)setStatus:(NSString *)status;
- (void)setStatus:(NSString *)status immediate:(BOOL)now;

- (NSStringEncoding)documentStringEncoding;
- (void)setDocumentStringEncoding:(NSStringEncoding)encoding;

/*!
    @method     saveSortOrder
    @abstract   Saves current sort order to preferences, to be restored on next launch/document open.
    @discussion (comprehensive description)
*/
- (void)saveSortOrder;

@end

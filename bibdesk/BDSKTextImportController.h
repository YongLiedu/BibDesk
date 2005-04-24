//
//  BDSKTextImportController.h
//  Bibdesk
//
//  Created by Michael McCracken on 4/13/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BibItem.h"
#import "BibTypeManager.h"
@class BibDocument;

@interface BDSKTextImportController : NSWindowController {
    BibDocument* document;
    BibItem* item;
    int itemsAdded;
    NSMutableArray *fields;
    NSMutableArray *bookmarks;
    IBOutlet NSTextView* sourceTextView;
    IBOutlet NSTableView* itemTableView;
    IBOutlet NSTextField* statusLine;
    IBOutlet NSTextField* citeKeyLine;
    IBOutlet NSPopUpButton* itemTypeButton;
    IBOutlet NSPopUpButton* chooseSourceButton;
    IBOutlet NSBox* sourceBox;
    IBOutlet WebView* webView;
    IBOutlet NSBox* webViewBox;
    IBOutlet NSPanel* urlSheet;
    IBOutlet NSTextField* urlTextField;
    IBOutlet NSPopUpButton* bookmarkPopUpButton;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSButton *backButton;
    IBOutlet NSButton *forwardButton;
    IBOutlet NSButton *stopOrReloadButton;
    IBOutlet NSTextField *bookmarkField;
    IBOutlet NSPanel *addBookmarkSheet;
    BOOL showingWebView;
	BOOL isLoading;
	BOOL isDownloading;
	WebDownload *download;
	NSString *downloadFileName;
    int receivedContentLength;
    int expectedContentLength;
}

- (id)initWithDocument:(BibDocument *)doc fromWeb:(BOOL)showWebView;
- (void)setShowingWebView:(BOOL)showWebView;
- (void)setType:(NSString *)type;
- (void)cleanup;

- (IBAction)addCurrentItemAction:(id)sender;
- (IBAction)stopAddingAction:(id)sender;
- (IBAction)addTextToCurrentFieldAction:(id)sender;
- (IBAction)changeTypeOfBibAction:(id)sender;
- (IBAction)loadPasteboard:(id)sender;
- (IBAction)loadFile:(id)sender;
- (IBAction)loadWebPage:(id)sender;
- (IBAction)chooseBookmarkAction:(id)sender;
- (IBAction)dismissUrlSheet:(id)sender;
- (IBAction)dismissAddBookmarkSheet:(id)sender;
- (IBAction)stopOrReloadAction:(id)sender;
- (IBAction)showHelpAction:(id)sender;

- (void)copyLocationAsRemoteUrl:(id)sender;
- (void)copyLinkedLocationAsRemoteUrl:(id)sender;
- (void)saveFileAsLocalUrl:(id)sender;
- (void)downloadLinkedFileAsLocalUrl:(id)sender;
- (void)bookmarkPage:(id)sender;
- (void)bookmarkLink:(id)sender;

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)urlSheetDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)addBookmarkSheetDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)saveDownloadPanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)cancelDownload;
- (void)setLocalUrlFromDownload;
- (void)setDownloading:(BOOL)downloading;
- (void)setLoading:(BOOL)loading;

- (void)loadPasteboardData;
- (void)showWebViewWithURLString:(NSString *)urlString;
- (void)setupTypeUI;
- (void)addCurrentSelectionToFieldAtIndex:(int)index;

- (void)addBookmarkWithURLString:(NSString *)URLString title:(NSString *)title;
- (void)saveBookmarks;

@end

@interface TextImportItemTableView : NSTableView {
    
}

@end

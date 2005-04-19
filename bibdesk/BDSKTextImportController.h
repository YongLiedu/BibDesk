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
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSButton *stopLoadingButton;
    BOOL showingWebView;
	BOOL isDownloading;
	WebDownload *download;
	NSString *downloadFileName;
    int receivedContentLength;
    int expectedContentLength;
}

- (id)initWithDocument:(BibDocument *)document;
- (void)setType:(NSString *)type;

- (IBAction)addCurrentItemAction:(id)sender;
- (IBAction)stopAddingAction:(id)sender;
- (IBAction)addTextToCurrentFieldAction:(id)sender;
- (IBAction)changeTypeOfBibAction:(id)sender;
- (IBAction)loadPasteboard:(id)sender;
- (IBAction)loadFile:(id)sender;
- (IBAction)loadWebPage:(id)sender;
- (IBAction)dismissUrlSheet:(id)sender;
- (IBAction)stopLoadingAction:(id)sender;
- (void)copyLocationAsRemoteUrl:(id)sender;
- (void)copyLinkedLocationAsRemoteUrl:(id)sender;
- (void)saveFileAsLocalUrl:(id)sender;
- (void)downloadLinkedFileAsLocalUrl:(id)sender;
- (void)bookmarkPage:(id)sender;
- (void)bookmarkLink:(id)sender;

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)urlSheetDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)saveDownloadPanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void)cancelDownload;
- (void)setLocalUrlFromDownload;
- (void)setDownloading:(BOOL)downloading;

- (void)setupSourceUI;
- (void)setupTypeUI;
- (void)addCurrentSelectionToFieldAtIndex:(int)index;

@end

@interface TextImportItemTableView : NSTableView {
    
}

@end

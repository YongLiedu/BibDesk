//
//  BDSKTextImportController.h
//  BibDesk
//
//  Created by Michael McCracken on 4/13/05.
/*
 This software is Copyright (c) 2001-2012
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
#import "BDSKOwnerProtocol.h"
#import "BDSKTextImportItemTableView.h"
#import "BDSKComplexStringFormatter.h"
#import "BDSKCitationFormatter.h"
#import "BDSKWebView.h"

@class BibDocument, BibItem, BDSKEdgeView, WebDownload, BDSKComplexStringEditor;
@class BDSKCiteKeyFormatter;

@interface BDSKTextImportController : NSWindowController <BDSKOwner, BDSKTextImportItemTableViewDelegate, NSTableViewDataSource, NSTextViewDelegate, NSSplitViewDelegate, BDSKComplexStringFormatterDelegate, BDSKCitationFormatterDelegate, BDSKWebViewDelegate> {
    IBOutlet NSTextView* sourceTextView;
    IBOutlet NSTableView* itemTableView;
    IBOutlet NSTextField* citeKeyField;
    IBOutlet NSTextField* statusLine;
    IBOutlet NSButton *addButton;
    IBOutlet NSButton *addAndCloseButton;
    IBOutlet NSButton *closeButton;
    IBOutlet NSButton *clearButton;
    IBOutlet NSPopUpButton* itemTypeButton;
    IBOutlet NSPopUpButton *actionMenuButton;
    IBOutlet NSSplitView* splitView;
    IBOutlet NSBox* sourceBox;
    IBOutlet BDSKEdgeView *webViewBox;
    IBOutlet NSView* webViewView;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSButton *backButton;
    IBOutlet NSButton *forwardButton;
    IBOutlet NSButton *stopOrReloadButton;
    IBOutlet NSButton *citeKeyWarningButton;
    
	BibDocument* document;
    BibItem* item;
	NSMutableArray *itemsAdded;
    NSMutableArray *fields;
	NSString *webSelection;
    
    NSUndoManager *undoManager;
    
	BDSKComplexStringFormatter *tableCellFormatter;
	BDSKCiteKeyFormatter *crossrefFormatter;
	BDSKCiteKeyFormatter *citeKeyFormatter;
	BDSKCitationFormatter *citationFormatter;
	NSTextView *tableFieldEditor;
	
	BOOL showingWebView;
	BOOL isLoading;
	BOOL isDownloading;
	
    BDSKWebView *webView;
    
	WebDownload *download;
	NSString *downloadFileName;
    NSInteger receivedContentLength;
    NSInteger expectedContentLength;
	
	BDSKComplexStringEditor *complexStringEditor;
    
    BOOL temporaryTypeSelectMode;
    NSResponder *savedFirstResponder;
}

- (id)initWithDocument:(BibDocument *)doc;

- (void)beginSheetModalForWindow:(NSWindow *)aWindow forURL:(NSURL *)aURL;

- (IBAction)addItemAction:(id)sender;
- (IBAction)closeAction:(id)sender;
- (IBAction)addItemAndCloseAction:(id)sender;
- (IBAction)clearAction:(id)sender;
- (IBAction)showHelpAction:(id)sender;
- (IBAction)addTextToCurrentFieldAction:(id)sender;
- (IBAction)changeTypeOfBibAction:(id)sender;
- (IBAction)importFromPasteboardAction:(id)sender;
- (IBAction)importFromFileAction:(id)sender;
- (IBAction)importFromWebAction:(id)sender;
- (IBAction)openBookmark:(id)sender;
- (IBAction)stopOrReloadAction:(id)sender;
- (IBAction)addField:(id)sender;
- (IBAction)editSelectedFieldAsRawBibTeX:(id)sender;
- (IBAction)generateCiteKey:(id)sender;
- (IBAction)showCiteKeyWarning:(id)sender;
- (IBAction)consolidateLinkedFiles:(id)sender;

- (void)copyLocationAsRemoteUrl:(id)sender;
- (void)copyLinkedLocationAsRemoteUrl:(id)sender;
- (void)saveFileAsLocalUrl:(id)sender;
- (void)downloadLinkedFileAsLocalUrl:(id)sender;

@end

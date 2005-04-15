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
    IBOutlet NSTextField* urlTextField;
    BOOL showingWebView;
}
- (id)initWithDocument:(BibDocument *)document;
- (void)setType:(NSString *)type;
- (IBAction)addCurrentItemAction:(id)sender;
- (IBAction)stopAddingAction:(id)sender;
- (IBAction)addTextToCurrentFieldAction:(id)sender;
- (IBAction)changeTypeOfBibAction:(id)sender;

- (void)setupSourceUI;
- (void)setupTypeUI;
- (void)addCurrentSelectionToFieldAtIndex:(int)index;

@end

@interface TextImportItemTableView : NSTableView {
    
}

@end

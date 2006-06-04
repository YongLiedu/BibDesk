//
//  BDSKDocumentInfoWindowController.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 31/5/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BibDocument;

@interface BDSKDocumentInfoWindowController : NSWindowController {
    IBOutlet NSTableView *tableView;
    NSMutableArray *keys;
    BibDocument *document;
}

- (id)initWithDocument:(BibDocument *)aDocument;
- (IBAction)done:(id)sender;
- (IBAction)addKey:(id)sender;
- (IBAction)removeSelectedKeys:(id)sender;
- (void)beginSheetModalForWindow:(NSWindow *)modalWindow;
- (void)refreshKeys;

@end

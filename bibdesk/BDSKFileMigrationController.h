//
//  BDSKFileMigrationController.h
//  Bibdesk
//
//  Created by Adam Maxwell on 12/16/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BDSKFileMigrationController : NSWindowController {
    IBOutlet NSTableView *tableView;
    IBOutlet NSButton *migrateButton;
    BOOL keepOriginalValues;
    NSMutableArray *results;
    IBOutlet NSProgressIndicator *progressBar;
}

- (IBAction)migrate:(id)sender;
- (IBAction)openParentDirectory:(id)sender;
- (IBAction)editPublication:(id)sender;

@end

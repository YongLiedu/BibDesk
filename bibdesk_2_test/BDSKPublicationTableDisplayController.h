//
//  BDSKPublicationTableDisplayController.h
//  bd2
//
//  Created by Michael McCracken on 6/21/05.
//  Copyright 2005 Michael McCracken. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BDSKTableDisplayController.h"


@interface BDSKPublicationTableDisplayController : BDSKTableDisplayController {
    IBOutlet NSArrayController *contributorsArrayController;
    IBOutlet NSArrayController *tagsArrayController;
    IBOutlet NSArrayController *notesArrayController;
	IBOutlet NSTableView *contributorsTableView;
	IBOutlet NSTableView *tagsTableView;
	IBOutlet NSTableView *notesTableView;
}

- (IBAction)addPublication:(id)sender;
- (IBAction)removePublications:(NSArray *)selectedItems;
- (IBAction)addContributor:(id)sender;

@end

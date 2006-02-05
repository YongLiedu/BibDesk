//
//  BDSKPersonTableDisplayController.h
//  bd2
//
//  Created by Michael McCracken on 7/15/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BDSKTableDisplayController.h"

@interface BDSKPersonTableDisplayController : BDSKTableDisplayController {
    IBOutlet NSArrayController *publicationsArrayController;
    IBOutlet NSArrayController *tagsArrayController;
    IBOutlet NSTableView *publicationsTableView;
    IBOutlet NSTableView *tagsTableView;
}

- (IBAction)addPerson:(id)sender;
- (IBAction)removePersons:(NSArray *)selectedItems;
- (IBAction)addPublication:(id)sender;

@end

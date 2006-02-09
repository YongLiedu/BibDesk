//
//  BDSKInstitutionTableDisplayController.h
//  bd2
//
//  Created by Christiaan Hofman on 2/7/06.
//  Copyright 2006. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BDSKTableDisplayController.h"

@interface BDSKInstitutionTableDisplayController : BDSKTableDisplayController {
    IBOutlet NSArrayController *personsArrayController;
    IBOutlet NSArrayController *publicationsArrayController;
    IBOutlet NSArrayController *tagsArrayController;
    IBOutlet NSTableView *personsTableView;
    IBOutlet NSTableView *publicationsTableView;
    IBOutlet NSTableView *tagsTableView;
}

- (IBAction)addInstitution:(id)sender;
- (IBAction)removeInstitutions:(NSArray *)selectedItems;
- (IBAction)addPerson:(id)sender;
- (IBAction)addPublication:(id)sender;

@end

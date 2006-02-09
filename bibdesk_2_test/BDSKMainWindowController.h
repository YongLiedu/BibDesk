//
//  BDSKMainWindowController.h
//  bd2
//
//  Created by Michael McCracken on 6/16/05.
//  Copyright 2005 Michael McCracken. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BDSKSecondaryWindowController.h"


@interface BDSKMainWindowController : BDSKSecondaryWindowController {

    IBOutlet NSOutlineView *sourceList;
    IBOutlet NSArrayController *selectedItemsArrayController;
    IBOutlet NSTreeController *sourceListTreeController;
}

- (NSSet *)sourceListSelectedItems;
- (void)addSourceListSelectedItemsObject:(id)obj;
- (void)removeSourceListSelectedItemsObject:(id)obj;

// actions
- (IBAction)showWindowForSourceListSelection:(id)sender;

- (IBAction)addNewItemFromSourceListSelection:(id)sender;
- (IBAction)addNewGroupFromSourceListSelection:(id)sender;
- (IBAction)addNewSmartGroupFromSourceListSelection:(id)sender;

- (void)addNewPublicationGroupToContainer:(id)container;
- (void)addNewPersonGroupToContainer:(id)container;
- (void)addNewNoteGroupToContainer:(id)container;
- (void)addNewSmartGroupToContainer:(id)container;

- (void)importFromBibTeXFile:(id)sender;

@end

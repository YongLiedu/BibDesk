//
//  BDSKMainWindowController.h
//  bd2
//
//  Created by Michael McCracken on 6/16/05.
//  Copyright 2005 Michael McCracken. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BDSKDocument.h"
#import "ImageAndTextCell.h"

#import "BDSKPublicationTableDisplayController.h" // @@ TODO: itemdisplayflex this should be temporary
#import "BDSKNoteTableDisplayController.h" // @@ TODO: itemdisplayflex this should be temporary


@interface BDSKMainWindowController : NSWindowController {

    IBOutlet NSOutlineView *sourceList;
    IBOutlet NSArrayController *selectedItemsArrayController;
    NSMutableArray *topLevelSourceListItems;
    
    IBOutlet NSSplitView *mainSplitView;
    
    // Display Controller stuff
    NSDictionary *displayControllersInfoDict;
    NSMutableArray *displayControllers;
    NSMutableDictionary *currentDisplayControllerForEntity;
    id currentDisplayController;
    IBOutlet NSView *currentDisplayView;
}

- (void)setupDisplayControllers;
- (NSArray *)displayControllersForCurrentType;
- (void)setDisplayController:(id)newDisplayController;

- (void)bindDisplayController:(id)displayController;
- (void)unbindDisplayController:(id)displayController;

- (void)setupTopLevelSourceListItems;
- (void)reloadSourceList;

- (NSSet *)sourceListSelectedItems;

// actions
- (IBAction)addNewGroupFromSourceListSelection:(id)container;
- (IBAction)addNewItemFromSourceListSelection:(id)container;

- (IBAction)addNewPublicationToContainer:(id)container;
- (IBAction)addNewPublicationGroupToContainer:(id)container;

- (IBAction)addNewNoteToContainer:(id)container;
- (IBAction)addNewNoteGroupToContainer:(id)container;

- (IBAction)addNewPersonToContainer:(id)container;
- (IBAction)addNewPersonGroupToContainer:(id)container;

- (IBAction)importFromBibTeXFile:(id)sender;

@end

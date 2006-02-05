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
    NSMutableArray *topLevelSourceListItems;
    NSIndexPath *sourceListSelectedIndexPath;
}

- (NSArray *)topLevelSourceListItems;
- (unsigned)countOfTopLevelSourceListItems;
- (id)objectInTopLevelSourceListItemsAtIndex:(unsigned)index;
- (void)insertObject:(id)obj inTopLevelSourceListItemsAtIndex:(unsigned)index;
- (void)removeObjectFromTopLevelSourceListItemsAtIndex:(unsigned)index;

- (NSSet *)sourceListSelectedItems;
- (void)addSourceListSelectedItemsObject:(id)obj;
- (void)removeSourceListSelectedItemsObject:(id)obj;

- (NSIndexPath *)sourceListSelectedIndexPath;
- (void)setSourceListSelectedIndexPath:(NSIndexPath *)indexPath;

- (void)setupTopLevelSourceListItems;
- (void)reloadSourceList;

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

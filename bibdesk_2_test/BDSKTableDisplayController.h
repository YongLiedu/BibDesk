//
//  BDSKTableDisplayController.h
//  bd2xtest
//
//  Created by Christiaan Hofman on 1/29/06.
//  Copyright 2006. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ImageBackgroundBox.h"


@interface BDSKDisplayController : NSWindowController {
    IBOutlet NSView *mainView;
    NSDocument *document;
    NSString *itemEntityName;
}

- (NSView *)view;

- (NSDocument *)document;
- (void)setDocument:(NSDocument *)newDocument;

- (NSManagedObjectContext *)managedObjectContext;

- (NSString *)itemEntityName;
- (void)setItemEntityName:(NSString *)entityName;

- (void)updateUI;

- (BOOL)addRelationshipsFromPasteboard:(NSPasteboard *)pboard forType:(NSString *)type parent:(NSManagedObject *)parent keyPath:(NSString *)keyPath;

@end


@interface BDSKItemDisplayController : BDSKDisplayController {
    IBOutlet NSObjectController *itemObjectController;
}

- (NSObjectController *)itemObjectController;

- (BOOL)addRelationshipsFromPasteboard:(NSPasteboard *)pboard forType:(NSString *)type keyPath:(NSString *)keyPath;

@end


@interface BDSKTableDisplayController : BDSKDisplayController {
    NSManagedObject *currentItem;
    BOOL isEditable;
    NSDictionary *itemDisplayControllersInfoDict;
    NSMutableArray *itemDisplayControllers;
    NSMutableDictionary *currentItemDisplayControllerForEntity;
    BDSKItemDisplayController *currentItemDisplayController;
    IBOutlet NSView *currentItemDisplayView;
    IBOutlet NSArrayController *itemsArrayController;
    IBOutlet NSTableView *itemsTableView;
}

- (NSArrayController *)itemsArrayController;
- (NSTableView *)itemsTableView;

- (NSArray *)filterPredicates;

- (BOOL)isEditable;
- (void)setEditable:(BOOL)value;

- (NSManagedObject *)currentItem;
- (void)setCurrentItem:(NSManagedObject *)newItem;

- (BDSKItemDisplayController *)itemDisplayController;
- (void)setItemDisplayController:(BDSKItemDisplayController *)newDisplayController;

- (NSArray *)itemDisplayControllers;
- (NSArray *)itemDisplayControllersForCurrentType;

- (BDSKItemDisplayController *)itemDisplayControllerForEntity:(NSEntityDescription *)entity;

- (void)setupItemDisplayControllers;
- (void)bindItemDisplayController:(BDSKItemDisplayController *)displayController;
- (void)unbindItemDisplayController:(BDSKItemDisplayController *)displayController;

- (void)addItem;
- (void)removeItems:(NSArray *)selectedItems;

- (BOOL)writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard forType:(NSString *)type;
- (BOOL)addRelationshipsFromPasteboard:(NSPasteboard *)pboard forType:(NSString *)type parentRow:(int)row keyPath:(NSString *)keyPath;

@end

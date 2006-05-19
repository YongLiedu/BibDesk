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

@end


@interface BDSKTableDisplayController : BDSKDisplayController {
    id currentSubDisplayController;
    IBOutlet NSView *currentDisplaySubview;
    IBOutlet NSArrayController *itemsArrayController;
    IBOutlet NSTableView *itemsTableView;
}

- (NSArrayController *)itemsArrayController;
- (NSTableView *)itemsTableView;

- (NSArray *)filterPredicates;

- (void)addItem;
- (void)removeItems:(NSArray *)selectedItems;

- (BOOL)writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard forType:(NSString *)type;
- (BOOL)addRelationshipsFromPasteboard:(NSPasteboard *)pboard forType:(NSString *)type parentRow:(int)row keyPath:(NSString *)keyPath;

@end

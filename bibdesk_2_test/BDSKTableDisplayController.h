//
//  BDSKTableDisplayController.h
//  bd2xtest
//
//  Created by Christiaan Hofman on 1/29/06.
//  Copyright 2006. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ImageBackgroundBox.h"


@interface BDSKTableDisplayController : NSObject {
    IBOutlet NSView *mainView;
    IBOutlet NSObjectController *ownerController;
    IBOutlet NSArrayController *itemsArrayController;
    IBOutlet NSTableView *itemsTableView;
    IBOutlet ImageBackgroundBox *selectionDetailsBox;
    NSDocument *document;
}

- (NSDocument *)document;
- (void)setDocument:(NSDocument *)newDocument;

- (NSManagedObjectContext *)managedObjectContext;

- (NSView *)view;
- (NSString *)viewNibName;

- (NSArrayController *)itemsArrayController;
- (NSTableView *)itemsTableView;

- (NSArray *)filterPredicates;

- (void)setupBinding:(id)controller;

- (BOOL)writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard forType:(NSString *)type;
- (BOOL)addRelationshipsFromPasteboard:(NSPasteboard *)pboard forType:(NSString *)type parentRow:(int)row keyPath:(NSString *)keyPath;

@end

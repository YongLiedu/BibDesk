//
//  BDSKSecondaryWindowController.h
//  bd2
//
//  Created by Christiaan Hofman on 1/29/06.
//  Copyright 2006 Christiaan Hofman. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BDSKGroup;

@interface BDSKSecondaryWindowController : NSWindowController {
    
	BDSKGroup *sourceGroup;
	
    // Display Controller stuff
    NSDictionary *displayControllersInfoDict;
    NSMutableArray *displayControllers;
    NSMutableDictionary *currentDisplayControllerForEntity;
    id currentDisplayController;
    IBOutlet NSView *currentDisplayView;
}

- (BDSKGroup *)sourceGroup;
- (void)setSourceGroup:(BDSKGroup *)newSourceGroup;

- (NSArray *)displayControllersForCurrentType;
- (void)setDisplayController:(id)newDisplayController;

- (void)setupDisplayControllers;
- (void)bindDisplayController:(id)displayController;
- (void)unbindDisplayController:(id)displayController;

// actions
- (IBAction)addNewItem:(id)sender;

- (void)addNewPublicationToContainer:(id)container;
- (void)addNewPersonToContainer:(id)container;
- (void)addNewNoteToContainer:(id)container;
- (void)addNewItemToRootContainer:(id)container;

@end

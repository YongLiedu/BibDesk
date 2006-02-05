//
//  BDSKInspectorWindowController.h
//  bd2xtest
//
//  Created by Christiaan Hofman on 2/5/06.
//  Copyright 2006. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BDSKInspectorWindowController : NSWindowController {
    IBOutlet NSArrayController *itemsArrayController;
    NSWindowController *observedWindowController;
}

+ (id)sharedController;

- (NSString *)windowNibName;
- (NSString *)windowTitle;
- (NSString *)keyPathForBinding;

- (void)setMainWindow:(NSWindow *)mainWindow;

- (void)bindWindowController:(NSWindowController *)controller;
- (void)unbindWindowController:(NSWindowController *)controller;

@end


@interface BDSKNoteWindowController : BDSKInspectorWindowController {} @end


@interface BDSKTagWindowController : BDSKInspectorWindowController {} @end

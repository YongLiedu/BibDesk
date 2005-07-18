//
//  BDSKNoteTableDisplayController.h
//  bd2
//
//  Created by Michael McCracken on 7/13/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BDSKNoteTableDisplayController : NSObject {
    IBOutlet NSView *mainView;
    IBOutlet NSArrayController *itemsArrayController;
}

- (NSArrayController *)itemsArrayController;
- (NSView *)view;

@end

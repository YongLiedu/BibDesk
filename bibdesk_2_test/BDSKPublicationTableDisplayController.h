//
//  BDSKPublicationTableDisplayController.h
//  bd2
//
//  Created by Michael McCracken on 6/21/05.
//  Copyright 2005 Michael McCracken. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ImageBackgroundBox.h"


@interface BDSKPublicationTableDisplayController : NSObject {
    IBOutlet NSView *mainView;
    IBOutlet NSArrayController *itemsArrayController;
    IBOutlet ImageBackgroundBox *selectionDetailsBox;
    NSDocument *document;
}

- (NSView *)view;
- (NSArrayController *)itemsArrayController;

- (NSDocument *)document;
- (void)setDocument:(NSDocument *)newDocument;

@end

//
//  BDSKPersonTableDisplayController.h
//  bd2
//
//  Created by Michael McCracken on 7/15/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BDSKPersonTableDisplayController : NSObject {
    IBOutlet NSView *mainView;  
    IBOutlet NSArrayController *itemsArrayController;
    NSDocument *document;
}

- (NSView *)view;
- (NSArrayController *)itemsArrayController;

- (NSDocument *)document;
- (void)setDocument:(NSDocument *)newDocument;
- (NSManagedObjectContext *)managedObjectContext;

@end

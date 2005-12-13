//
//  BDSKNoteTableDisplayController.m
//  bd2
//
//  Created by Michael McCracken on 7/13/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKNoteTableDisplayController.h"


@implementation BDSKNoteTableDisplayController

- (void)dealloc{
    [super dealloc];
}

- (NSView *)view{
    if(!mainView){
        [NSBundle loadNibNamed:@"BDSKNoteTableDisplayController" owner:self];
    }
    return mainView;
}


- (NSArrayController *)itemsArrayController{
    return itemsArrayController;
}


- (NSDocument *)document{
    return document;
}

- (void)setDocument:(NSDocument *)newDocument{
    document = newDocument;
}


@end

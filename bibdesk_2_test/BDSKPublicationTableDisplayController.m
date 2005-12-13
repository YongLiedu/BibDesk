//
//  BDSKPublicationTableDisplayController.m
//  bd2
//
//  Created by Michael McCracken on 6/21/05.
//  Copyright 2005 Michael McCracken. All rights reserved.
//

#import "BDSKPublicationTableDisplayController.h"


@implementation BDSKPublicationTableDisplayController

- (void)dealloc{
    [super dealloc];
}

- (NSView *)view{
    if(!mainView){
        [NSBundle loadNibNamed:@"BDSKPublicationTableDisplayController" owner:self];
    }
    return mainView;
}


- (void)awakeFromNib{
    [selectionDetailsBox setBackgroundImage:[NSImage imageNamed:@"coffeeStain"]];
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

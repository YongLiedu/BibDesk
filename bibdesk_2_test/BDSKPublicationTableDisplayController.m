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

- (NSArrayController *)itemsArrayController{
    return itemsArrayController;
}


@end

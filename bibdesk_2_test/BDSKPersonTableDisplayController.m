//
//  BDSKPersonTableDisplayController.m
//  bd2
//
//  Created by Michael McCracken on 7/13/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKPersonTableDisplayController.h"


@implementation BDSKPersonTableDisplayController

- (void)dealloc{
    [super dealloc];
}

- (NSView *)view{
    if(!mainView){
        [NSBundle loadNibNamed:@"BDSKPersonTableDisplayController" owner:self];
    }
    return mainView;
}


- (NSArrayController *)itemsArrayController{
    return itemsArrayController;
}

@end

//
//  BDSKBD2AppDelegate.m
//  bd2xtest
//
//  Created by Michael McCracken on 7/17/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKBD2AppDelegate.h"


@implementation BDSKBD2AppDelegate

+ (void)initialize{
    // Register Custom Value Transformers
    BDSKGroupEntityToItemDisplayNameTransformer *groupToItemNameTransformer;
    groupToItemNameTransformer = [[[BDSKGroupEntityToItemDisplayNameTransformer alloc] init]
        autorelease];
    [NSValueTransformer setValueTransformer:groupToItemNameTransformer
                                    forName:@"BDSKGroupEntityToItemDisplayNameTransformer"];
}

@end

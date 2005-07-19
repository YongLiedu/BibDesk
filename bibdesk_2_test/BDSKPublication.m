//
//  BDSKPublication.m
//  bd2xtest
//
//  Created by Michael McCracken on 7/17/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKPublication.h"


@implementation BDSKPublication

- (NSString *)stringValueForSearch{
    return [NSString stringWithFormat:@"%@ %@", [self valueForKey:@"title"],
        [self valueForKey:@"shortTitle"]];
}

@end

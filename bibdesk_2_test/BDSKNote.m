//
//  BDSKNote.m
//  bd2xtest
//
//  Created by Michael McCracken on 7/17/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKNote.h"


@implementation BDSKNote

- (NSString *)stringValueForSearch{
    NSString *val = [self valueForKey:@"value"];
    NSLog(@"getting search value in note: %@", val);
    return val;
}

@end

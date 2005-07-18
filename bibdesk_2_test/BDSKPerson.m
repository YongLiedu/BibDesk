//
//  BDSKPerson.m
//  bd2xtest
//
//  Created by Michael McCracken on 7/17/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKPerson.h"


@implementation BDSKPerson

- (NSString *)stringValueForSearch{
    return [NSString stringWithFormat:@"%@ %@ %@ %@ %@", [self valueForKey:@"firstNamePart"],
        [self valueForKey:@"middleNamePart"],
        [self valueForKey:@"vonNamePart"],
        [self valueForKey:@"lastNamePart"],
        [self valueForKey:@"jrNamePart"]];
}
@end

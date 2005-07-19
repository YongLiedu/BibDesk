//
//  BDSKPerson.m
//  bd2xtest
//
//  Created by Michael McCracken on 7/17/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKPerson.h"


@implementation BDSKPerson


+ (void)initialize {
    [self setKeys:[NSArray arrayWithObjects:@"firstNamePart", @"vonNamePart", @"lastNamePart", @"jrNamePart", nil]
    triggerChangeNotificationsForDependentKey:@"name"];
}

- (NSString *)stringValueForSearch{
    return [NSString stringWithFormat:@"%@ %@ %@ %@", [self valueForKey:@"firstNamePart"],
        [self valueForKey:@"vonNamePart"],
        [self valueForKey:@"lastNamePart"],
        [self valueForKey:@"jrNamePart"]];
}

- (NSString *)name{
    NSString *firstName = [self valueForKey:@"firstNamePart"];
    NSString *vonPart = [self valueForKey:@"vonNamePart"];
    NSString *lastName = [self valueForKey:@"lastNamePart"];
    NSString *jrPart = [self valueForKey:@"jrNamePart"];
    
    BOOL FIRST = (firstName != nil && ![@"" isEqualToString:firstName]);
    BOOL VON = (vonPart != nil && ![@"" isEqualToString:vonPart]);
    BOOL LAST = (lastName != nil && ![@"" isEqualToString:lastName]);
    BOOL JR = (jrPart != nil && ![@"" isEqualToString:jrPart]);
    
    return [NSString stringWithFormat:@"%@%@%@%@%@%@%@", (VON ? vonPart : @""),
        (VON ? @" " : @""),
        (LAST ? lastName : @""),
        (JR ? @", " : @""),
        (JR ? jrPart : @""),
        (FIRST ? @", " : @""),
        (FIRST ? firstName : @"")];
}

@end

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

- (void)setName:(NSString *)newName{
	// TODO: more intelligent name parsing, maybe using btparse?
	NSCharacterSet *wsCharSet = [NSCharacterSet whitespaceCharacterSet];
	NSString *firstNamePart = nil;
	NSString *lastNamePart = nil;
	NSString *vonNamePart = nil;
	NSString *jrNamePart = nil;
	NSArray *components = [newName componentsSeparatedByString:@","];
	int count = [components count];
	if (count == 1) {
		components = [[[components objectAtIndex:0] stringByTrimmingCharactersInSet:wsCharSet] componentsSeparatedByString:@" "];
		count = [components count];
		if (count > 1) {
			firstNamePart = [[components objectAtIndex:0] stringByTrimmingCharactersInSet:wsCharSet];
			if (count > 2) {
				vonNamePart = [[components objectAtIndex:1] stringByTrimmingCharactersInSet:wsCharSet];
				components = [components subarrayWithRange:NSMakeRange(2, count - 2)];
			} else {
				components = [components subarrayWithRange:NSMakeRange(1, count - 1)];
			}
		}
	} else {
		firstNamePart = [[components lastObject] stringByTrimmingCharactersInSet:wsCharSet];
		if (count == 3) 
			jrNamePart = [[components objectAtIndex:1] stringByTrimmingCharactersInSet:wsCharSet];
		components = [[[components objectAtIndex:0] stringByTrimmingCharactersInSet:wsCharSet] componentsSeparatedByString:@" "];
		count = [components count];
		if (count > 1) {
			vonNamePart = [[components objectAtIndex:0] stringByTrimmingCharactersInSet:wsCharSet];
			components = [components subarrayWithRange:NSMakeRange(1, count - 1)];
		}
	}
	lastNamePart = [components componentsJoinedByString:@" "];
	[self setValue:firstNamePart forKey:@"firstNamePart"];
	[self setValue:lastNamePart forKey:@"lastNamePart"];
	[self setValue:vonNamePart forKey:@"vonNamePart"];
	[self setValue:jrNamePart forKey:@"jrNamePart"];
}

- (BDSKPersonInstitutionRelationship *)currentInstitutionRelationship{
    NSMutableSet *institutionRelationships = [self valueForKey:@"institutionRelationships"];
    NSEnumerator *instRelEnumerator = [institutionRelationships objectEnumerator];
    id instRel = nil;
    NSDate *mostRecentDate = [NSDate distantPast];
    id mostRecentInstRel = nil;
    
    // find the relationship with the most recent start date:
    while (instRel = [instRelEnumerator nextObject]) {
        NSDate *startDate = [instRel valueForKey:@"startDate"];
        if([startDate timeIntervalSinceDate:mostRecentDate] > 0){
            mostRecentDate = startDate;
            mostRecentInstRel = instRel;
        }
    }
    return mostRecentInstRel;
}

- (NSString *)currentInstitutionRelationshipDisplayString{
    BDSKPersonInstitutionRelationship *instRel = [self currentInstitutionRelationship];
    
    NSString *instName = [instRel valueForKeyPath:@"institution.name"];
    NSString *relType = [instRel valueForKey:@"relationshipType"];
    NSDate *startDate = [instRel valueForKey:@"startDate"];
    NSString *startDateString = [startDate descriptionWithCalendarFormat:@"%m/%y" 
                                                                timeZone:nil 
                                                                  locale:nil];

    return [NSString stringWithFormat:@"%@, %@ (since %@)", relType, instName, startDateString];
}

@end

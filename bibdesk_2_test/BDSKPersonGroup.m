//
//  BDSKPersonGroup.m
//  bd2
//
//  Created by Michael McCracken on 7/13/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKPersonGroup.h"
#import "BDSKPerson.h"
#import "BDSKDataModelNames.h"


@implementation BDSKPersonGroup

- (void)commonAwake {
    [super commonAwake];
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(replacePerson:) 
                                                 name:@"BDSKPersonWasReplacedNotification" 
                                               object:nil];        
}

- (void)didTurnIntoFault {
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:@"BDSKPersonWasReplacedNotification" 
                                                  object:nil];
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:@"BDSKPersonWasReplacedNotification" 
                                                  object:nil];
    [super dealloc];
}

- (NSString *)itemEntityName {
    return PersonEntityName;
}

- (void)replacePerson:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSEnumerator *removedE = [[userInfo objectForKey:@"removedPersons"] objectEnumerator];
    NSEnumerator *insertedE = [[userInfo objectForKey:@"insertedPersons"] objectEnumerator];
    NSManagedObject *removedPerson;
    NSManagedObject *insertedPerson;
    NSMutableSet *items = [self mutableSetValueForKey:@"items"];
    
    while ((removedPerson = [removedE nextObject]) && (insertedPerson = [insertedE nextObject])) {
        if ([removedPerson managedObjectContext] != [self managedObjectContext]) 
            continue;
        if ([items containsObject:removedPerson] == NO)
            continue;
        [items removeObject:removedPerson];
        [items addObject:insertedPerson];
    }
}

@end

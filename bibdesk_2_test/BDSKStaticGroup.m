//
//  BDSKStaticGroup.m
//  bd2xtest
//
//  Created by Christiaan Hofman on 2/15/06.
//  Copyright 2006. All rights reserved.
//

#import "BDSKStaticGroup.h"
#import "BDSKDataModelNames.h"


@implementation BDSKStaticGroup 

+ (void)initialize {
    // we need to call super's implementation, even though the docs say not to, because otherwise we loose dependent keys
    [super initialize]; 
    [self setKeys:[NSArray arrayWithObjects:@"children", nil]
        triggerChangeNotificationsForDependentKey:@"isLeaf"];
}

- (void)commonAwake {
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(replacePerson:) 
                                                 name:@"BDSKPersonWasReplacedNotification" 
                                               object:nil];        
}

- (void)awakeFromInsert  {
    [super awakeFromInsert];
    [self commonAwake];
}

- (void)awakeFromFetch  {
    [super awakeFromFetch];
    [self commonAwake];
}

- (void)didTurnIntoFault {
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:@"BDSKPersonWasReplacedNotification" 
                                                  object:nil];

    [cachedIcon release];
    cachedIcon = nil;
    
    [super didTurnIntoFault];
}

- (void)replacePerson:(NSNotification *)notification {
    NSString *entityName = [self itemEntityName];
    if ([entityName isEqualToString:PersonEntityName] == NO)
        return;
    
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

#pragma mark Accessors

- (BOOL)isLeaf { return ([[self valueForKey:@"children"] count] == 0); }

- (NSSet *)itemsInSelfOrChildren {
    NSMutableSet *myPubs = [NSMutableSet setWithCapacity:10];
    [myPubs unionSet:[self valueForKey:@"items"]];
    
    NSSet *children = [self valueForKey:@"children"];
    NSEnumerator *childE = [children objectEnumerator];
    id child = nil;
    while (child = [childE nextObject]) {
        if ([child isSmart] == NO)
            [myPubs unionSet:[child valueForKey:@"itemsInSelfOrChildren"]];
    }
    return myPubs;
}

- (void)addItemsInSelfOrChildrenObject:(id)obj {
    NSSet *children = [self valueForKey:@"children"];
    NSEnumerator *childE = [children objectEnumerator];
    id child = nil;
    while (child = [childE nextObject]) {
        if ([child isSmart] == NO && [[child valueForKey:@"itemsInSelfOrChildren"] containsObject:obj])
            return;
    }
    
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&obj count:1];
    [self willChangeValueForKey:@"itemsInSelfOrChildren" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
    [[self mutableSetValueForKey:@"items"] addObject:obj];
    
    [self didChangeValueForKey:@"itemsInSelfOrChildren" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    [changedObjects release];
}

- (void)removeItemsInSelfOrChildrenObject:(id)obj {
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&obj count:1];
    [self willChangeValueForKey:@"itemsInSelfOrChildren" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
    [[self mutableSetValueForKey:@"items"] removeObject:obj];
    
    NSSet *children = [self valueForKey:@"children"];
    NSEnumerator *childE = [children objectEnumerator];
    id child = nil;
    while (child = [childE nextObject]) {
        if ([child isSmart] == NO)
            [child removeItemsInSelfOrChildrenObject:obj];
    }
    
    [self didChangeValueForKey:@"itemsInSelfOrChildren" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    [changedObjects release];
}

@end

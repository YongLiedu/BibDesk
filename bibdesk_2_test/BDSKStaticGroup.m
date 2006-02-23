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

- (void)didTurnIntoFault {
    [cachedIcon release];
    cachedIcon = nil;
    
    [super didTurnIntoFault];
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

//
//  BDSKStaticGroup.h
//  bd2xtest
//
//  Created by Christiaan Hofman on 2/15/06.
//  Copyright 2006. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "BDSKGroup.h"


@interface BDSKStaticGroup :  BDSKGroup {
}

- (NSSet *)itemsInSelfOrChildren;
- (void)addItemsInSelfOrChildrenObject:(id)obj;
- (void)removeItemsInSelfOrChildrenObject:(id)obj;

- (void)commonAwake;
- (void)managedObjectContextObjectsDidChange:(NSNotification *)notification;
- (void)replacePerson:(NSNotification *)notification;

@end

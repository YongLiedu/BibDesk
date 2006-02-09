//
//  BDSKGroup.h
//  bd2xtest
//
//  Created by Christiaan Hofman on 4/2/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <CoreData/CoreData.h>


@interface BDSKGroup :  NSManagedObject {
    NSImage *cachedIcon;

}
- (void)commonAwake;

- (NSString *)groupImageName;
- (NSImage *)icon;

- (NSDictionary *)nameAndIcon;
- (void)setNameAndIcon:(NSString *)name;

- (BOOL)isSmart;

- (BOOL)canEdit;

- (NSString *)itemEntityName;

- (NSSet *)itemsInSelfOrChildren;
- (void)addItemsInSelfOrChildrenObject:(id)obj;
- (void)removeItemsInSelfOrChildrenObject:(id)obj;

- (void)managedObjectContextObjectsDidChange:(NSNotification *)notification;

@end

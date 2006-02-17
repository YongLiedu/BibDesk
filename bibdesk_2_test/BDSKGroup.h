//
//  BDSKGroup.h
//  bd2xtest
//
//  Created by Christiaan Hofman on 2/4/06.
//  Copyright 2006. All rights reserved.
//

#import <CoreData/CoreData.h>


@interface BDSKGroup :  NSManagedObject {
    NSImage *cachedIcon;
}

- (NSString *)itemEntityName;
- (void)setItemEntityName:(NSString *)entityName;

- (NSString *)groupImageName;
- (NSImage *)icon;

- (NSDictionary *)nameAndIcon;
- (void)setNameAndIcon:(NSString *)name;

- (NSSet *)itemsInSelfOrChildren;

- (BOOL)isSmart;
- (BOOL)isCategory;

- (BOOL)isLeaf;

- (BOOL)canEdit;
- (BOOL)canEditName;

@end

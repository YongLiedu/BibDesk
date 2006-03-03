//
//  BDSKSmartGroup.h
//  bd2xtest
//
//  Created by Christiaan Hofman on 2/4/06.
//  Copyright 2006. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "BDSKGroup.h"


@interface BDSKSmartGroup : BDSKGroup {
    NSSet *items;
    NSMutableSet *children;
    NSString *groupImageName;
    BOOL isToMany;
    BOOL recreatingChildren;
}

- (NSPredicate *)predicate;
- (void)setPredicate:(NSPredicate *)predicate;

- (NSString *)itemEntityName;
- (void)setItemEntityName:(NSString *)entityName;

- (NSString *)itemPropertyName;
- (void)setItemPropertyName:(NSString *)propertyName;

- (NSFetchRequest *)fetchRequest;

- (void)setGroupImageName:(NSString *)imageName;

- (NSSet *)items;

- (NSSet *)children;

- (void)refreshItems;
- (void)refreshChildren;
- (void)refreshMetaData;
- (void)managedObjectContextObjectsDidChange:(NSNotification *)notification;

@end


@interface BDSKLibraryGroup :  BDSKSmartGroup {
}
@end


@interface BDSKCategoryGroup : BDSKGroup {
    NSSet *items;
}

- (NSSet *)items;
- (void)setItems:(NSSet *)newItems;

- (NSSet *)children;

@end

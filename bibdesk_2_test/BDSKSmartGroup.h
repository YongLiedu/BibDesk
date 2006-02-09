//
//  BDSKSmartGroup.h
//  bd2xtest
//
//  Created by Christiaan Hofman on 2/4/06.
//  Copyright 2006. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "BDSKGroup.h"


@interface BDSKSmartGroup :  BDSKGroup {
    NSFetchRequest *fetchRequest;       
    NSPredicate *predicate;          
    NSSet *items;
    NSString *groupImageName;
    BOOL canEdit;
    BOOL canEditName;
}

- (NSPredicate *)predicate;
- (void)setPredicate:(NSPredicate *)predicate;

- (NSString *)itemEntityName;
- (void)setItemEntityName:(NSString *)entityName;

- (NSFetchRequest *)fetchRequest;

- (void)setGroupImageName:(NSString *)imageName;

- (void)setCanEdit:(BOOL)flag;

- (NSSet *)items;

- (void)refresh;

@end

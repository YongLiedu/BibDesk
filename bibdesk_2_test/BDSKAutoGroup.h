//
//  BDSKAutoGroup.h
//  bd2xtest
//
//  Created by Christiaan Hofman on 2/8/06.
//  Copyright 2006. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BDSKGroup.h"


@interface BDSKAutoGroup : BDSKGroup {
    NSMutableSet *children;
    BOOL isToMany;
    BOOL recreatingChildren;
}

- (NSString *)itemEntityName;
- (void)setItemEntityName:(NSString *)entityName;

- (NSString *)itemPropertyName;
- (void)setItemPropertyName:(NSString *)propertyName;

- (void)refresh;

- (NSSet *)items;

@end

//
//  BDSKFilterItem.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 20/3/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKFilterItem.h"


@protocol BDSKFilterItem

+ (NSArray *)filterKeys;

- (NSString *)filterValueForKey:(NSString *)key;

@end

//
//  BDSKCondition.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 17/3/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BDSKFilterItem.h"

typedef enum {
	BDSKContain = 0,
	BDSKNotContain = 1,
	BDSKEqual = 2,
	BDSKNotEqual = 3,
	BDSKStartWith = 4,
	BDSKEndWith = 5
} BDSKComparison;

@interface BDSKCondition : NSObject {
	NSString *key;
	NSString *value;
	BDSKComparison comparison;
}

- (BOOL)isSatisfiedByItem:(id<BDSKFilterItem>)item;
- (NSString *)key;
- (void)setKey:(NSString *)newKey;
- (NSString *)value;
- (void)setValue:(NSString *)newValue;
- (BDSKComparison)comparison;
- (void)setComparison:(BDSKComparison)newComparison;

@end

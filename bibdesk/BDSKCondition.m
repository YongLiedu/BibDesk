//
//  BDSKCondition.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 17/3/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKCondition.h"


@implementation BDSKCondition

- (id)init {
    self = [super init];
    if (self) {
        key = [@"Name" retain];
        value = [@"" retain];
        comparison = BDSKContain;
    }
    return self;
}

- (void)dealloc {
	//NSLog(@"dealloc condition");
    [key release];
    key  = nil;
    [value release];
    value  = nil;
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)aZone {
	BDSKCondition *copy = [[BDSKCondition allocWithZone:aZone] init];
	[copy setKey:[self key]];
	[copy setValue:[self value]];
	[copy setComparison:[self comparison]];
	return copy;
}

- (BOOL)isEqual:(id)other {
	if (![other isKindOfClass:[BDSKCondition class]]) 
		return NO;
	return [[self key] isEqualToString:[other key]] &&
		   [[self value] isEqualToString:[other key]] &&
		   [self comparison] == [other comparison];
}

- (BOOL)isSatisfiedByItem:(id<BDSKFilterItem>)item {
	NSString *itemValue = [[item filterValueForKey:key] lowercaseString];
	if (itemValue == nil)
		return NO;
	switch (comparison) {
		case BDSKContain:
			return ([itemValue rangeOfString:value].location != NSNotFound);
		case BDSKNotContain:
			return ([itemValue rangeOfString:value].location == NSNotFound);
		case BDSKEqual:
			return [itemValue isEqualToString:value];
		case BDSKNotEqual:
			return ![itemValue isEqualToString:value];
		case BDSKStartWith:
			return [itemValue hasPrefix:value];
		case BDSKEndWith:
			return [itemValue hasSuffix:value];
	}
}

- (NSString *)key {
    return [[key retain] autorelease];
}

- (void)setKey:(NSString *)newKey {
    if (key != newKey) {
        [key release];
        key = [newKey copy];
    }
}

- (NSString *)value {
    return [[value retain] autorelease];
}

- (void)setValue:(NSString *)newValue {
    newValue = [newValue lowercaseString];
	if (value != newValue) {
        [value release];
        value = [newValue copy];
    }
}

- (BDSKComparison)comparison {
    return comparison;
}

- (void)setComparison:(BDSKComparison)newComparison {
    comparison = newComparison;
}

@end

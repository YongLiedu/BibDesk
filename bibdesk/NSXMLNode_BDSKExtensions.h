//
//  NSXMLNode_BDSKExtensions.h
//  Bibdesk
//
//  Created by Michael McCracken on 9/26/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <WebKit/WebKit.h>


@interface NSXMLNode (BDSKExtensions)
- (NSString *)stringValueOfAttribute:(NSString *)attrName;
- (NSArray *)descendantOrSelfNodesWithClassName:(NSString *)className error:(NSError **)err;
- (BOOL)hasParentWithClassName:(NSString *)class;
- (NSArray *)classNames;
- (NSString *)fullStringValueIfABBR;

@end

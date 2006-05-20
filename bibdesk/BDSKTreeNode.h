//
//  BDSKTreeNode.h
//  Bibdesk
//
//  Created by Adam Maxwell on 05/18/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BDSKTreeNode : NSObject <NSCoding, NSCopying>
{
    NSMutableArray *children;
    NSMutableDictionary *columnValues;
    BDSKTreeNode *parent;
}

- (id)initWithParent:(id)anObject;
// uses isEqual:
- (void)removeChild:(id)anObject;
- (void)addChild:(id)anObject;
- (void)setChildren:(NSArray *)theChildren;
- (NSArray *)children;
- (unsigned int)numberOfChildren;
- (id)parent;
- (void)setParent:(id)aParent;
- (BOOL)isLeaf;

@end
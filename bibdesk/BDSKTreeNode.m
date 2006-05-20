//
//  BDSKTreeNode.m
//  Bibdesk
//
//  Created by Adam Maxwell on 05/18/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "BDSKTreeNode.h"


@implementation BDSKTreeNode

- (id)initWithParent:(id)anObject;
{
    if(self = [super init]){
        [self setParent:anObject];
        [self setChildren:[NSArray array]];
        columnValues = [[NSMutableDictionary alloc] initWithCapacity:2];
    }
    return self;
}

- (void)dealloc
{
    [self setParent:nil];
    [self setChildren:nil];
    [columnValues release];
    [super dealloc];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@: %@ parent object;\n\tvalues: \"%@\"\n\tchildren: \"%@\"", [super description], parent?@"Has":@"No", columnValues, children];
}

- (id)initWithCoder:(NSCoder *)coder;
{
    if(self = [self initWithParent:nil]){
        [self setChildren:[coder decodeObjectForKey:@"children"]];
        columnValues = [[coder decodeObjectForKey:@"columnValues"] retain];
        parent = [coder decodeObjectForKey:@"parent"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder;
{
    [coder encodeObject:children forKey:@"children"];
    [coder encodeObject:columnValues forKey:@"columnValues"];
    [coder encodeConditionalObject:parent forKey:@"parent"];
}

- (id)parent { return parent; }

- (void)setParent:(id)anObject;
{
    parent = anObject;
}

- (id)copyWithZone:(NSZone *)aZone;
{
    BDSKTreeNode *node = [[[self class] alloc] initWithParent:[self parent]];
    
    // deep copy the array of children, since the copy could modify the original
    NSMutableArray *newChildren = [[NSMutableArray alloc] initWithArray:[self children] copyItems:YES];
    [node setChildren:newChildren];
    [newChildren release];
    
    node->columnValues = [columnValues mutableCopy];
    return node;
}

- (id)valueForUndefinedKey:(NSString *)key { return [columnValues valueForKey:key]; }

- (void)setValue:(id)value forUndefinedKey:(NSString *)key;
{
    NSParameterAssert(nil != value);
    NSParameterAssert(nil != key);
    [columnValues setValue:value forKey:key];
}

- (void)addChild:(id)anObject;
{
    [children addObject:anObject];
}

- (void)removeChild:(id)anObject;
{
    [children removeObject:anObject];
}

- (void)setChildren:(NSArray *)theChildren;
{
    if(theChildren != children){
        [children release];
        children = [theChildren mutableCopy];
        
        // make sure these children know their parent
        [children makeObjectsPerformSelector:@selector(setParent:) withObject:self];
    }
}

- (NSArray *)children { return children; }

- (unsigned int)numberOfChildren { return [children count]; }

- (BOOL)isLeaf { return [self numberOfChildren] > 0 ? NO : YES; }

@end

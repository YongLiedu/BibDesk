//
//  BDSKTreeNode.m
//  Bibdesk
//
//  Created by Adam Maxwell on 05/18/06.
/*
 This software is Copyright (c) 2006-2010
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
 contributors may be used to endorse or promote products derived
 from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "BDSKTreeNode.h"


@implementation BDSKTreeNode

- (id)initWithColumnValues:(NSDictionary *)newColumnValues children:(NSArray *)newChildren;
{
    if(self = [super init]){
        parent = nil;
        children = [[NSMutableArray alloc] initWithArray:newChildren];
        columnValues = [[NSDictionary alloc] initWithDictionary:newColumnValues];
    }
    return self;
}

- (id)init;
{
    self = [self initWithColumnValues:nil children:nil];
    return self;
}

- (void)dealloc
{
    parent = nil;
    BDSKDESTROY(children);
    BDSKDESTROY(columnValues);
    [super dealloc];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@: %@ parent object;\n\tvalues: \"%@\"\n\tchildren: \"%@\"", [super description], parent?@"Has":@"No", columnValues, children];
}

- (id)initWithCoder:(NSCoder *)coder;
{
    if(self = [super init]){
        children = [[NSMutableArray alloc] initWithArray:[coder decodeObjectForKey:@"children"]];
        columnValues = [[NSMutableDictionary alloc] initWithDictionary:[coder decodeObjectForKey:@"columnValues"]];
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

- (id)copyWithZone:(NSZone *)aZone;
{
    // deep copy the array of children, since the copy could modify the original
    NSMutableArray *newChildren = [[NSMutableArray alloc] initWithArray:[self children] copyItems:YES];
    BDSKTreeNode *node = [[[self class] alloc] initWithColumnValues:columnValues children:newChildren];
    [newChildren release];
    return node;
}

- (BDSKTreeNode *)parent { return parent; }

- (void)setParent:(BDSKTreeNode *)anObject;
{
    parent = anObject;
}

- (id)valueForUndefinedKey:(NSString *)key { 
    return [columnValues valueForKey:key]; 
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key;
{
    NSParameterAssert(nil != value);
    NSParameterAssert(nil != key);
    [columnValues setValue:value forKey:key];
}

- (NSArray *)children {
    return [[children copy] autorelease];
}

- (void)setChildren:(NSArray *)newChildren {
    if (children != newChildren) {
        // make sure to orphan these children
        [children makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
        
        [children release];
        children = [newChildren mutableCopy];
        
        // make sure these children know their parent
        [children makeObjectsPerformSelector:@selector(setParent:) withObject:self];
    }
}

- (NSUInteger)countOfChildren {
    return [children count];
}

- (id)objectInChildrenAtIndex:(NSUInteger)anIndex {
    return [children objectAtIndex:anIndex];
}

- (void)insertObject:(id)obj inChildrenAtIndex:(NSUInteger)anIndex {
    [children insertObject:obj atIndex:anIndex];
    
    // make sure this child knows its parent
    [obj setParent:self];
}

- (void)removeObjectFromChildrenAtIndex:(NSUInteger)anIndex {
    // make sure to orphan this child
    [[children objectAtIndex:anIndex] setParent:nil];
    
    [children removeObjectAtIndex:anIndex];
}

- (BOOL)isLeaf { return [self countOfChildren] == 0; }

@end

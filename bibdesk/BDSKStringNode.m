//
//  BDSKStringNode.m
//  Bibdesk
//
// Created by Michael McCracken, 2004
/*
 This software is Copyright (c) 2004-2010
 Michael O. McCracken. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BDSKStringNode.h"


@implementation BDSKStringNode

+ (BDSKStringNode *)nodeWithQuotedString:(NSString *)s{
    BDSKStringNode *node = [[BDSKStringNode alloc] initWithType:BDSKStringNodeString value:s];
	return [node autorelease];
}

+ (BDSKStringNode *)nodeWithNumberString:(NSString *)s{
    BDSKStringNode *node = [[BDSKStringNode alloc] initWithType:BDSKStringNodeNumber value:s];
	return [node autorelease];
}

+ (BDSKStringNode *)nodeWithMacroString:(NSString *)s{
    BDSKStringNode *node = [[BDSKStringNode alloc] initWithType:BDSKStringNodeMacro value:s];
	return [node autorelease];
}

- (BDSKStringNode *)initWithQuotedString:(NSString *)s{
    return [self initWithType:BDSKStringNodeString value:s];
}

- (BDSKStringNode *)initWithNumberString:(NSString *)s{
    return [self initWithType:BDSKStringNodeNumber value:s];
}

- (BDSKStringNode *)initWithMacroString:(NSString *)s{
    return [self initWithType:BDSKStringNodeMacro value:s];
}

- (id)init{
	self = [self initWithType:BDSKStringNodeString value:@""];
	return self;
}

- (id)initWithType:(BDSKStringNodeType)aType value:(NSString *)s{
	if (self = [super init]) {
		type = aType;
		value = [s copy];
	}
	return self;
}

- (void)dealloc{
    BDSKDESTROY(value);
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone{
    if (NSShouldRetainWithZone(self, zone))
        return [self retain];
    else
        return [[[self class] allocWithZone:zone] initWithType:type value:value];
}

- (id)initWithCoder:(NSCoder *)coder{
    if([coder allowsKeyedCoding]){
        if (self = [super init]) {
            type = [coder decodeIntegerForKey:@"type"];
            value = [[coder decodeObjectForKey:@"value"] retain];
        }
    } else {       
        [[super init] release];
        self = [[NSKeyedUnarchiver unarchiveObjectWithData:[coder decodeDataObject]] retain];
    }
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder{
    if([encoder allowsKeyedCoding]){
        [encoder encodeInteger:type forKey:@"type"];
        [encoder encodeObject:value forKey:@"value"];
    } else {
        [encoder encodeDataObject:[NSKeyedArchiver archivedDataWithRootObject:self]];
    }
}

- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
    return [encoder isByref] ? (id)[NSDistantObject proxyWithLocal:self connection:[encoder connection]] : self;
}

- (BOOL)isEqual:(BDSKStringNode *)other{
    if(type == [other type] &&
       [value isEqualToString:[other value]])
        return YES;
    return NO;
}

- (NSComparisonResult)compareNode:(BDSKStringNode *)aNode{
	return [self compareNode:aNode options:0];
}

- (NSComparisonResult)compareNode:(BDSKStringNode *)aNode options:(NSUInteger)mask{
	if (type < [aNode type])
		return NSOrderedAscending;
	if (type > [aNode type])
		return NSOrderedDescending;
	return [value compare:[aNode value] options:mask];
}

- (BDSKStringNodeType)type {
    return type;
}

- (NSString *)value {
    return value;
}

- (NSString *)description{
    return [NSString stringWithFormat:@"type: %ld, %@", (long)type, value];
}

@end

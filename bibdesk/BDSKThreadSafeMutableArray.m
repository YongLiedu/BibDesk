//
//  BDSKThreadSafeMutableArray.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/3/06.
/*
 This software is Copyright (c) 2006
 Christiaan Hofman. All rights reserved.

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

#import "BDSKThreadSafeMutableArray.h"


@implementation BDSKThreadSafeMutableArray

- (id)init {
    if (self = [super init]) {
        embeddedArray = [[NSMutableArray allocWithZone:[self zone]] init];
		lock = [[NSLock allocWithZone:[self zone]] init];
    }
    return self;
}

- (id)initWithCapacity:(unsigned)capacity {
    if (self = [super init]) {
        embeddedArray = [[NSMutableArray allocWithZone:[self zone]] initWithCapacity:capacity];
		lock = [[NSLock allocWithZone:[self zone]] init];
    }
    return self;
}

- (id)initWithObjects:(id *)objects count:(unsigned)count {
    if (self = [super init]) {
        embeddedArray = [[NSMutableArray allocWithZone:[self zone]] initWithObjects:objects count:count];
		lock = [[NSLock allocWithZone:[self zone]] init];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
	id copy;
    [lock lock];
	copy = [embeddedArray copy];
    [lock unlock];
	return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
	id copy;
    [lock lock];
	copy = [[[self class] allocWithZone:zone] initWithArray:embeddedArray];
    [lock unlock];
	return copy;
}

- (void)dealloc {
    [lock lock];
	[embeddedArray release];
    embeddedArray = nil;
    [lock unlock];
	[lock release];
    lock = nil;
	[super dealloc];
}

- (unsigned)count {
    [lock lock];
	unsigned count = [embeddedArray count];
    [lock unlock];
    return count;
}

- (id)objectAtIndex:(unsigned)index {
    [lock lock];
    id object = [embeddedArray objectAtIndex:index];
    [lock unlock];
    return object;
}

- (void)insertObject:(id)object atIndex:(unsigned)index {
    [lock lock];
	[embeddedArray insertObject:object atIndex:index];
    [lock unlock];
}

- (void)addObject:object {
    [lock lock];
	[embeddedArray addObject:object];
    [lock unlock];
}

- (void)removeObjectAtIndex:(unsigned)index {
    [lock lock];
	[embeddedArray removeObjectAtIndex:index];
    [lock unlock];
}

- (void)removeLastObject {
    [lock lock];
	[embeddedArray removeLastObject];
    [lock unlock];
}

- (void)replaceObjectAtIndex:(unsigned)index withObject:(id)object{
    [lock lock];
	[embeddedArray replaceObjectAtIndex:index withObject:object];
    [lock unlock];
}

@end

//
//  BDSKThreadSafeMutableDictionary.m
//  BibDesk
//
//  Created by Adam Maxwell on 01/27/05.
/*
 This software is Copyright (c) 2005, 2006
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

#import "BDSKThreadSafeMutableDictionary.h"

@implementation BDSKThreadSafeMutableDictionary

- (id)init {
    if (self = [super init]) {
        embeddedDictionary = [[NSMutableDictionary allocWithZone:[self zone]] init];
		lock = [[NSLock allocWithZone:[self zone]] init];
    }
    return self;
}

- (id)initWithCapacity:(unsigned)capacity {
    if (self = [super init]) {
        embeddedDictionary = [[NSMutableDictionary allocWithZone:[self zone]] initWithCapacity:capacity];
		lock = [[NSLock allocWithZone:[self zone]] init];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    [lock lock];
	id copy = [embeddedDictionary copy];
    [lock unlock];
	return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    [lock lock];
	id copy = [[[self class] allocWithZone:zone] initWithDictionary:embeddedDictionary];
    [lock unlock];
	return copy;
}

- (void)dealloc {
    [lock lock];
	[embeddedDictionary release];
    embeddedDictionary = nil;
    [lock unlock];
	[lock release];
    lock = nil;
	[super dealloc];
}

- (unsigned)count {
    [lock lock];
	unsigned count = [embeddedDictionary count];
    [lock unlock];
    return count;
}

- (id)objectForKey:(id)key {
    [lock lock];
    id object = [embeddedDictionary objectForKey:key];
    [lock unlock];
    return object;
}

- (NSEnumerator *)keyEnumerator {
	[lock lock];
	NSArray *keys = [embeddedDictionary allKeys];
    [lock unlock];
	return [keys objectEnumerator];
}

- (void)setObject:(id)object forKey:(id)key {
    [lock lock];
	[embeddedDictionary setObject:object forKey:key];
    [lock unlock];
}

- (void)removeObjectForKey:(id)key {
    [lock lock];
	[embeddedDictionary removeObjectForKey:key];
    [lock unlock];
}

@end

//
//  BDSKThreadSafeMutableArray.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/3/06.
/*
 This software is Copyright (c) 2006-2009
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
#import "BDSKReadWriteLock.h"


@implementation BDSKThreadSafeMutableArray

- (id)init {
    if (self = [super init]) {
        embeddedArray = [[NSMutableArray allocWithZone:[self zone]] init];
		rwLock = [[BDSKReadWriteLock alloc] init];
    }
    return self;
}

- (id)initWithCapacity:(unsigned)capacity {
    if (self = [super init]) {
        embeddedArray = [[NSMutableArray allocWithZone:[self zone]] initWithCapacity:capacity];
		rwLock = [[BDSKReadWriteLock alloc] init];
    }
    return self;
}

- (id)initWithArray:(NSArray *)array {
    if (self = [super init]) {
        embeddedArray = [[NSMutableArray allocWithZone:[self zone]] initWithArray:array];
		rwLock = [[BDSKReadWriteLock alloc] init];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
	id copy;
    [rwLock lockForReading];
	copy = [embeddedArray copy];
    [rwLock unlock];
	return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
	id copy;
    [rwLock lockForReading];
	copy = [[[self class] allocWithZone:zone] initWithArray:embeddedArray];
    [rwLock unlock];
	return copy;
}

- (void)dealloc {
    [rwLock lockForWriting];
	[embeddedArray release];
    embeddedArray = nil;
    [rwLock unlock];
    [rwLock release];
	[super dealloc];
}

- (unsigned)count {
    [rwLock lockForReading];
	unsigned count = [embeddedArray count];
    [rwLock unlock];
    return count;
}

- (id)objectAtIndex:(unsigned)idx {
    [rwLock lockForReading];
    id object = [[[embeddedArray objectAtIndex:idx] retain] autorelease];
    [rwLock unlock];
    return object;
}

- (void)insertObject:(id)object atIndex:(unsigned)idx {
    [rwLock lockForWriting];
    [object retain];
	[embeddedArray insertObject:object atIndex:idx];
    [object release];
    [rwLock unlock];
}

- (void)addObject:object {
    [rwLock lockForWriting];
    [object retain];
	[embeddedArray addObject:object];
    [object release];
    [rwLock unlock];
}

- (void)removeObjectAtIndex:(unsigned)idx {
    [rwLock lockForWriting];
    id obj = [[embeddedArray objectAtIndex:idx] retain];
	[embeddedArray removeObjectAtIndex:idx];
    [obj autorelease];
    [rwLock unlock];
}

- (void)removeLastObject {
    [rwLock lockForWriting];
    id obj = [[embeddedArray lastObject] retain];
	[embeddedArray removeLastObject];
    [obj autorelease];
    [rwLock unlock];
}

- (void)replaceObjectAtIndex:(unsigned)idx withObject:(id)object{
    [rwLock lockForWriting];
    [object retain];
    id objToReplace = [[embeddedArray objectAtIndex:idx] retain];
	[embeddedArray replaceObjectAtIndex:idx withObject:object];
    [object release];
    [objToReplace autorelease];
    [rwLock unlock];
}

@end

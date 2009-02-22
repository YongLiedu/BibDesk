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
#import <pthread.h>


@implementation BDSKThreadSafeMutableArray

- (id)init {
    if (self = [super init]) {
        embeddedArray = [[NSMutableArray allocWithZone:[self zone]] init];
        pthread_rwlock_init(&rwlock, NULL);
    }
    return self;
}

- (id)initWithCapacity:(unsigned)capacity {
    if (self = [super init]) {
        embeddedArray = [[NSMutableArray allocWithZone:[self zone]] initWithCapacity:capacity];
        pthread_rwlock_init(&rwlock, NULL);
    }
    return self;
}

- (id)initWithArray:(NSArray *)array {
    if (self = [super init]) {
        embeddedArray = [[NSMutableArray allocWithZone:[self zone]] initWithArray:array];
        pthread_rwlock_init(&rwlock, NULL);
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
	id copy;
    pthread_rwlock_rdlock(&rwlock);
	copy = [embeddedArray copy];
    pthread_rwlock_unlock(&rwlock);
	return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
	id copy;
    pthread_rwlock_rdlock(&rwlock);
	copy = [[[self class] allocWithZone:zone] initWithArray:embeddedArray];
    pthread_rwlock_unlock(&rwlock);
	return copy;
}

- (void)dealloc {
    pthread_rwlock_wrlock(&rwlock);
	[embeddedArray release];
    embeddedArray = nil;
    pthread_rwlock_unlock(&rwlock);
    pthread_rwlock_destroy(&rwlock);
	[super dealloc];
}

- (unsigned)count {
    pthread_rwlock_rdlock(&rwlock);
	unsigned count = [embeddedArray count];
    pthread_rwlock_unlock(&rwlock);
    return count;
}

- (id)objectAtIndex:(unsigned)idx {
    pthread_rwlock_rdlock(&rwlock);
    id object = [[[embeddedArray objectAtIndex:idx] retain] autorelease];
    pthread_rwlock_unlock(&rwlock);
    return object;
}

- (void)insertObject:(id)object atIndex:(unsigned)idx {
    pthread_rwlock_wrlock(&rwlock);
    [object retain];
	[embeddedArray insertObject:object atIndex:idx];
    [object release];
    pthread_rwlock_unlock(&rwlock);
}

- (void)addObject:object {
    pthread_rwlock_wrlock(&rwlock);
    [object retain];
	[embeddedArray addObject:object];
    [object release];
    pthread_rwlock_unlock(&rwlock);
}

- (void)removeObjectAtIndex:(unsigned)idx {
    pthread_rwlock_wrlock(&rwlock);
    id obj = [[embeddedArray objectAtIndex:idx] retain];
	[embeddedArray removeObjectAtIndex:idx];
    [obj autorelease];
    pthread_rwlock_unlock(&rwlock);
}

- (void)removeLastObject {
    pthread_rwlock_wrlock(&rwlock);
    id obj = [[embeddedArray lastObject] retain];
	[embeddedArray removeLastObject];
    [obj autorelease];
    pthread_rwlock_unlock(&rwlock);
}

- (void)replaceObjectAtIndex:(unsigned)idx withObject:(id)object{
    pthread_rwlock_wrlock(&rwlock);
    [object retain];
    id objToReplace = [[embeddedArray objectAtIndex:idx] retain];
	[embeddedArray replaceObjectAtIndex:idx withObject:object];
    [object release];
    [objToReplace autorelease];
    pthread_rwlock_unlock(&rwlock);
}

@end

//
//  FVOperation.m
//  FileView
//
//  Created by Adam Maxwell on 2/8/08.
/*
 This software is Copyright (c) 2008-2012
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

#import "FVOperation.h"
#import "FVConcreteOperation.h"
#import "FVOperationQueue.h"
#import "FVThread.h"


@interface FVPlaceholderOperation : FVOperation
@end

@implementation FVOperation

// FVOperation abstract class stuff
static FVOperation *defaultPlaceholderOperation = nil;
static Class FVOperationClass = Nil;

+ (void)initialize
{
    FVINITIALIZE(FVOperation);
    
    FVOperationClass = self;
    defaultPlaceholderOperation = (FVOperation *)NSAllocateObject([FVPlaceholderOperation self], 0, [self zone]);
}

+ (id)allocWithZone:(NSZone *)aZone
{
    return FVOperationClass == self ? defaultPlaceholderOperation : [super allocWithZone:aZone];
}

// ensure that alloc always calls through to allocWithZone:
+ (id)alloc
{
    return [self allocWithZone:NULL];
}

- (id)init
{
    self = [super init];
    return self;
}

- (NSUInteger)hash 
{
    return [super hash];
}

- (BOOL)isEqual:(id)object
{
    // ??? ignores priority for now
    return [super isEqual:object];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ = {\n\t cancelled = %d,\n\t priority = %d,\n}\n", [super description], [self isCancelled], [self queuePriority]];
}

// Subclass responsibility

- (FVOperationQueuePriority)queuePriority { [self doesNotRecognizeSelector:_cmd]; return 0; };
- (void)setQueuePriority:(FVOperationQueuePriority)queuePriority { [self doesNotRecognizeSelector:_cmd]; };
- (void)cancel { [self doesNotRecognizeSelector:_cmd]; };
- (BOOL)isCancelled { [self doesNotRecognizeSelector:_cmd]; return YES; };
- (BOOL)isExecuting { [self doesNotRecognizeSelector:_cmd]; return YES; };
- (BOOL)isFinished { [self doesNotRecognizeSelector:_cmd]; return YES; };
- (void)main { [self doesNotRecognizeSelector:_cmd]; }
- (void)setQueue:(id)queue { [self doesNotRecognizeSelector:_cmd]; }
- (id)queue { [self doesNotRecognizeSelector:_cmd]; return nil; };
- (void)setConcurrent:(BOOL)flag { [self doesNotRecognizeSelector:_cmd]; }

@end


@implementation FVOperation (Extended)

// semantics here as the same as for NSDate, if we consider the dates as absolute time values
- (NSComparisonResult)compare:(FVOperation *)other;
{
    FVOperationQueuePriority otherPriority = [other queuePriority];
    FVOperationQueuePriority priority = [self queuePriority];
    if (priority > otherPriority) return NSOrderedDescending;
    if (priority < otherPriority) return NSOrderedAscending;
    return NSOrderedSame;
}

- (void)start;
{
    if ([self isCancelled])
        [NSException raise:NSInternalInconsistencyException format:@"attempt to execute a cancelled operation"];
    if ([self isExecuting] || [self isFinished])
        [NSException raise:NSInternalInconsistencyException format:@"attempt to start a previously executed operation"];
    
    if ([self isConcurrent])
        [FVThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];
    else
        [self main];
}

- (void)finished
{
    // Make sure the queue releases its reference to this operation.  This always happens if it's cancelled by the queue, but someone else could call -cancel, in which case this might be left in the queue's activeOperations bag.
    [[self queue] finishedOperation:self];
}

- (BOOL)isConcurrent { return NO; }

@end


@implementation FVPlaceholderOperation

- (id)init {
    return [[FVConcreteOperation allocWithZone:[self zone]] init];
}

- (id)retain { return self; }

- (id)autorelease { return self; }

- (void)release {}

- (NSUInteger)retainCount { return NSUIntegerMax; }

@end

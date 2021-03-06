//
//  FVOperationQueue.m
//  FileViewTest
//
//  Created by Adam Maxwell on 09/21/07.
/*
 This software is Copyright (c) 2007-2016
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

#import "FVOperationQueue.h"
#import "FVConcreteOperationQueue.h"
#import "FVMainThreadOperationQueue.h"

NSString * const FVMainQueueRunLoopMode = @"FVMainQueueRunLoopMode";


@interface FVPlaceholderOperationQueue : FVOperationQueue
@end

@implementation FVOperationQueue

static id _mainThreadQueue = nil;
static FVOperationQueue *defaultPlaceholderQueue = nil;
static Class FVOperationQueueClass = Nil;

+ (void)initialize
{
    FVINITIALIZE(FVOperationQueue);  
    FVOperationQueueClass = self;
    defaultPlaceholderQueue = (FVOperationQueue *)NSAllocateObject([FVPlaceholderOperationQueue self], 0, [self zone]);
    _mainThreadQueue = [FVMainThreadOperationQueue new];
}

+ (id)allocWithZone:(NSZone *)aZone
{
    return FVOperationQueueClass == self ? defaultPlaceholderQueue : [super allocWithZone:aZone];
}

// ensure that alloc always calls through to allocWithZone:
+ (id)alloc
{
    return [self allocWithZone:NULL];
}

- (void)subclassResponsibility:(SEL)selector
{
    [NSException raise:@"fabstractClassException" format:@"Abstract class %@ does not implement %@", [self class], NSStringFromSelector(selector)];
}

- (void)cancel;
{
    [self subclassResponsibility:_cmd];
}

- (void)setThreadPriority:(double)p;
{
    [self subclassResponsibility:_cmd];
}

- (void)addOperation:(FVOperation *)operation;
{
    [self subclassResponsibility:_cmd];
}
    
- (void)addOperations:(NSArray *)operations;
{
    [self subclassResponsibility:_cmd];
}

- (void)finishedOperation:(FVOperation *)anOperation;
{
    [self subclassResponsibility:_cmd];
}

- (void)terminate
{
    [self subclassResponsibility:_cmd];
}

@end


@implementation FVOperationQueue (Creation)

+ (FVOperationQueue *)mainQueue
{
    return _mainThreadQueue;
}

- (id)init
{
    self = [super init];
    return self;
}

@end


@implementation FVPlaceholderOperationQueue

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (id)init {
    return (id)[[FVConcreteOperationQueue allocWithZone:[self zone]] init];
}
#pragma clang diagnostic pop

- (id)retain { return self; }

- (id)autorelease { return self; }

- (oneway void)release {}

- (NSUInteger)retainCount { return NSUIntegerMax; }

@end

//
//  BDSKMessageQueue.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/19/09.
/*
 This software is Copyright (c) 2009
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

 - Neither the name of Christiaan Hofman nor the names of any
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
/*
 Omni Source License 2007

 OPEN PERMISSION TO USE AND REPRODUCE OMNI SOURCE CODE SOFTWARE

 Omni Source Code software is available from The Omni Group on their 
 web site at http://www.omnigroup.com/www.omnigroup.com. 

 Permission is hereby granted, free of charge, to any person obtaining 
 a copy of this software and associated documentation files (the 
 "Software"), to deal in the Software without restriction, including 
 without limitation the rights to use, copy, modify, merge, publish, 
 distribute, sublicense, and/or sell copies of the Software, and to 
 permit persons to whom the Software is furnished to do so, subject to 
 the following conditions:

 Any original copyright notices and this permission notice shall be 
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY 
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "BDSKMessageQueue.h"
#import "BDSKQueueProcessor.h"
#import "BDSKMainQueueProcessor.h"
#import "BDSKInvocation.h"

#define QUEUE_HAS_NO_SCHEDULABLE_INVOCATIONS 0
#define QUEUE_HAS_INVOCATIONS 1


@implementation BDSKMessageQueue

- (id)init {
    if (self = [super init]) {
        queue = [[NSMutableArray alloc] init];
        queueLock = [[NSConditionLock alloc] initWithCondition:QUEUE_HAS_NO_SCHEDULABLE_INVOCATIONS];
        
        idleProcessors = 0;
        queueProcessorsLock = [[NSLock alloc] init];
        uncreatedProcessors = 0;
        queueProcessors = [[NSMutableArray alloc] init];
        
        isMain = NO;
    }
    return self;
}

- (id)initMainQueue {
    if (self = [self init]) {
        isMain = YES;
        
        [queueProcessorsLock release];
        queueProcessorsLock = nil;
        
        BDSKMainQueueProcessor *queueProcessor = [[BDSKMainQueueProcessor alloc] initForQueue:self];
        [queueProcessors addObject:queueProcessor];
        [queueProcessor release];
        [queueProcessor startProcessingQueue];
    }
    return self;
}

+ (id)mainQueue {
    static BDSKMessageQueue *mainQueue = nil;
    if (mainQueue == nil)
        mainQueue = [[self alloc] initMainQueue];
    return mainQueue;
}

- (void)dealloc {
    [queueProcessors release];
    [queue release];
    [queueSet release];
    [queueLock release];
    [queueProcessorsLock release];
    [super dealloc];
}

- (BOOL)hasInvocations {
    BOOL hasInvocations;
    [queueLock lock];
    hasInvocations = [queue count] > 0;
    [queueLock unlock];
    return hasInvocations;
}

- (void)createProcessorsForQueueSize:(unsigned int)queueCount {
    unsigned int projectedIdleProcessors;
    
    [queueProcessorsLock lock];
    projectedIdleProcessors = idleProcessors;
    while (projectedIdleProcessors < queueCount && uncreatedProcessors > 0) {
        BDSKQueueProcessor *newProcessor;
        
        newProcessor = [[BDSKQueueProcessor alloc] initForQueue:self];
        [newProcessor startProcessingQueue];
        [queueProcessors addObject:newProcessor];
        [newProcessor release];
        uncreatedProcessors--;
        projectedIdleProcessors++;
    }
    [queueProcessorsLock unlock];
}

- (void)startBackgroundProcessors:(unsigned int)processorCount {
    if (isMain == NO) {
        [queueProcessorsLock lock];
        uncreatedProcessors += processorCount;
        [queueProcessorsLock unlock];

        // Now, go ahead and start some (or all) of those processors to handle messages already queued
        [queueLock lock];
        [self createProcessorsForQueueSize:[queue count]];
        [queueLock unlock];
    }
}

- (BDSKInvocation *)newInvocation {
    unsigned int invocationCount;
    BDSKInvocation *nextInvocation = nil;
    
    [queueLock lock];
    if ([queue count])
        [queueLock unlockWithCondition:QUEUE_HAS_INVOCATIONS];
    else
        [queueLock unlockWithCondition:QUEUE_HAS_NO_SCHEDULABLE_INVOCATIONS];
    
    if (isMain) {
        [queueLock lock];
    } else {
        [queueProcessorsLock lock];
        idleProcessors++;
        [queueProcessorsLock unlock];
        [queueLock lockWhenCondition:QUEUE_HAS_INVOCATIONS];
        [queueProcessorsLock lock];
        idleProcessors--;
        [queueProcessorsLock unlock];
    }
    
    invocationCount = [queue count];
    if (invocationCount == 0) {
        [queueLock unlock];
    } else {
        nextInvocation = [[queue objectAtIndex:0] retain];
        [queue removeObjectAtIndex:0];
        if (queueSet)
            [queueSet removeObject:nextInvocation];
        
        if (invocationCount == 1)
            [queueLock unlockWithCondition:QUEUE_HAS_NO_SCHEDULABLE_INVOCATIONS];
        else
            [queueLock unlockWithCondition:QUEUE_HAS_INVOCATIONS];
    }
    
    return nextInvocation;
}

- (void)queueInvocation:(BDSKInvocation *)anInvocation {
    unsigned int queueCount;
    
    [queueLock lock];
    
    queueCount = [queue count];
    [queue insertObject:anInvocation atIndex:queueCount];
    queueCount++;
    if (queueSet)
        [queueSet addObject:anInvocation];
    
    if (isMain == NO)
        // Create new processor if needed and we can
        [self createProcessorsForQueueSize:queueCount];
    
    [queueLock unlockWithCondition:QUEUE_HAS_INVOCATIONS];
    
    // Tickle main thread processor if needed
    if (isMain && queueCount == 1)
        [[queueProcessors lastObject] continueProcessingQueue];
}

- (void)queueInvocationOnce:(BDSKInvocation *)anInvocation {
    BOOL alreadyContainsObject;

    [queueLock lock];
    if (queueSet == nil)
        queueSet = [[NSMutableSet alloc] initWithArray:queue];
    alreadyContainsObject = [queueSet member:anInvocation] != nil;
    [queueLock unlock];
    if (alreadyContainsObject == NO)
        [self queueInvocation:anInvocation];
}

- (void)dequeueInvocation:(BDSKInvocation *)anInvocation {
    [queueLock lock];
    [queue removeObject:anInvocation];
    if (queueSet)
        [queueSet removeObject:anInvocation];
    [queueLock unlock];
}

- (void)dequeueAllInvocationsForTarget:(id)aTarget {
    [queueLock lock];
    int i = [queue count];
    while (i--) {
        if ([[queue objectAtIndex:i] target] == aTarget)
            [queue removeObjectAtIndex:i];
    }
    if (queueSet) {
        [queueSet release];
        queueSet = nil;
    }
    [queueLock unlock];
}

- (void)queueSelector:(SEL)aSelector forTarget:(id)aTarget {
    if (aTarget) {
        BDSKInvocation *invocation = [[BDSKInvocation alloc] initWithTarget:aTarget selector:aSelector];
        [self queueInvocation:invocation];
        [invocation release];
    }
}

- (void)queueSelectorOnce:(SEL)aSelector forTarget:(id)aTarget {
    if (aTarget) {
        BDSKInvocation *invocation = [[BDSKInvocation alloc] initWithTarget:aTarget selector:aSelector];
        [self queueInvocationOnce:invocation];
        [invocation release];
    }
}

- (void)dequeueSelector:(SEL)aSelector forTarget:(id)aTarget {
    if (aTarget) {
        BDSKInvocation *invocation = [[BDSKInvocation alloc] initWithTarget:aTarget selector:aSelector];
        [self dequeueInvocation:invocation];
        [invocation release];
    }
}

- (void)queueSelector:(SEL)aSelector forTarget:(id)aTarget withObject:(id)anObject {
    if (aTarget) {
        BDSKInvocation *invocation = [[BDSKInvocation alloc] initWithTarget:aTarget selector:aSelector withObject:anObject];
        [self queueInvocation:invocation];
        [invocation release];
    }
}

- (void)queueSelectorOnce:(SEL)aSelector forTarget:(id)aTarget withObject:(id)anObject {
    if (aTarget) {
        BDSKInvocation *invocation = [[BDSKInvocation alloc] initWithTarget:aTarget selector:aSelector withObject:anObject];
        [self queueInvocationOnce:invocation];
        [invocation release];
    }
}

- (void)dequeueSelector:(SEL)aSelector forTarget:(id)aTarget withObject:(id)anObject {
    if (aTarget) {
        BDSKInvocation *invocation = [[BDSKInvocation alloc] initWithTarget:aTarget selector:aSelector withObject:anObject];
        [self dequeueInvocation:invocation];
        [invocation release];
    }
}

- (void)queueSelector:(SEL)aSelector forTarget:(id)aTarget withObject:(id)anObject1 withObject:(id)anObject2 {
    if (aTarget) {
        BDSKInvocation *invocation = [[BDSKInvocation alloc] initWithTarget:aTarget selector:aSelector withObject:anObject1 withObject:anObject2];
        [self queueInvocation:invocation];
        [invocation release];
    }
}

- (void)queueSelectorOnce:(SEL)aSelector forTarget:(id)aTarget withObject:(id)anObject1 withObject:(id)anObject2 {
    if (aTarget) {
        BDSKInvocation *invocation = [[BDSKInvocation alloc] initWithTarget:aTarget selector:aSelector withObject:anObject1 withObject:anObject2];
        [self queueInvocationOnce:invocation];
        [invocation release];
    }
}

- (void)dequeueSelector:(SEL)aSelector forTarget:(id)aTarget withObject:(id)anObject1 withObject:(id)anObject2 {
    if (aTarget) {
        BDSKInvocation *invocation = [[BDSKInvocation alloc] initWithTarget:aTarget selector:aSelector withObject:anObject1 withObject:anObject2];
        [self dequeueInvocation:invocation];
        [invocation release];
    }
}

@end

#pragma mark -

@implementation NSObject (BDSKMessageQueue)

- (void)queueSelector:(SEL)aSelector {
    [[BDSKMessageQueue mainQueue] queueSelector:aSelector forTarget:self];
}

- (void)queueSelectorOnce:(SEL)aSelector {
    [[BDSKMessageQueue mainQueue] queueSelectorOnce:aSelector forTarget:self];
}

- (void)dequeueSelector:(SEL)aSelector {
    [[BDSKMessageQueue mainQueue] dequeueSelector:aSelector forTarget:self];
}

- (void)queueSelector:(SEL)aSelector withObject:(id)anObject {
    [[BDSKMessageQueue mainQueue] queueSelector:aSelector forTarget:self withObject:anObject];
}

- (void)queueSelectorOnce:(SEL)aSelector withObject:(id)anObject {
    [[BDSKMessageQueue mainQueue] queueSelectorOnce:aSelector forTarget:self withObject:anObject];
}

- (void)dequeueSelector:(SEL)aSelector withObject:(id)anObject {
    [[BDSKMessageQueue mainQueue] dequeueSelector:aSelector forTarget:self withObject:anObject];
}

- (void)queueSelector:(SEL)aSelector withObject:(id)anObject1 withObject:(id)anObject2 {
    [[BDSKMessageQueue mainQueue] queueSelector:aSelector forTarget:self withObject:anObject1 withObject:anObject2];
}

- (void)queueSelectorOnce:(SEL)aSelector withObject:(id)anObject1 withObject:(id)anObject2 {
    [[BDSKMessageQueue mainQueue] queueSelectorOnce:aSelector forTarget:self withObject:anObject1 withObject:anObject2];
}

- (void)dequeueSelector:(SEL)aSelector withObject:(id)anObject1 withObject:(id)anObject2 {
    [[BDSKMessageQueue mainQueue] dequeueSelector:aSelector forTarget:self withObject:anObject1 withObject:anObject2];
}

- (void)dequeueAllInvocations {
    [[BDSKMessageQueue mainQueue] dequeueAllInvocationsForTarget:self];
}

@end

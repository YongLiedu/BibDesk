//
//  FVIconQueue.m
//  FileViewTest
//
//  Created by Adam Maxwell on 09/21/07.
/*
 This software is Copyright (c) 2007-2008
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

#import "FVIconQueue.h"


@implementation FVIconQueue

static id sharedInstance = nil;


#define QUEUE_STARTUP 1
#define QUEUE_STARTUP_COMPLETE 2
#define TASK_BATCH_SIZE 5

// I was creating the sharedInstance in +initialize in order to avoid @synchronized and thread safety issues.  However, that led to problems when the _runCacheThread triggered a second main thread message to +initialize, but the main thread was already blocked on _setupLock waiting for _runCacheThread to unlock.  Since +sharedQueue is only used from the main thread, I'll ignore singleton threading issues for now.
+ (FVIconQueue *)sharedQueue;
{  
    if (nil == sharedInstance) {
        sharedInstance = [[self alloc] init];
    }        
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        _taskLock = [[NSLock alloc] init];
        _tasks = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        _iconsToRelease = [NSMutableSet new];
        _setupLock = [[NSConditionLock alloc] initWithCondition:QUEUE_STARTUP];
        
        // this causes a retain cycle, but we want the object to be persistent anyway
        [NSThread detachNewThreadSelector:@selector(_runCacheThread:) toTarget:self withObject:nil];
        
        // block until the NSMachPort is set up to receive messages, or callbacks won't be delivered properly
        [_setupLock lockWhenCondition:QUEUE_STARTUP_COMPLETE];
        [_setupLock unlock];
        
        // done with this lock, so get rid of it now
        [_setupLock release];
        _setupLock = nil;
    }
    return self;
}

// -dealloc is not implemented since these objects are overretained, and we only use one anyway

- (void)enqueueReleaseResourcesForIcons:(NSArray *)icons
{
    [_taskLock lock];
    [_iconsToRelease addObjectsFromArray:icons];
    [_taskLock unlock];
    [_threadPort sendBeforeDate:[NSDate date] components:nil from:nil reserved:0];
}

- (void)enqueueRenderIcons:(NSArray *)icons forObject:(id)anObject;
{
    [_taskLock lock];
    
    // give preference to rendering, since empty icon slots are more noticeable than memory issues
    // the release will still take place, but it will be a bit later in time
    [_iconsToRelease minusSet:[NSSet setWithArray:icons]];
    
    // do not use toll-free bridging here, since setObject:forKey: will stupidly copy the key (a FileView instance)
    CFDictionarySetValue(_tasks, (void *)anObject, (void *)icons);
    [_taskLock unlock];
    // wake the thread up
    [_threadPort sendBeforeDate:[NSDate date] components:nil from:nil reserved:0];
}

- (void)_handleRenderTasks;
{        
    // each key-value in the dictionary is a FileView (key) mapped to an array of paths (NSStrings)
    
    // create a private copy so we can unlock as soon as possible, since _renderThreadFinished may cause further display operations, consequently filling up _tasks again for the same target
    [_taskLock lock];
    CFDictionaryRef taskCopy = CFDictionaryCreateCopy(CFGetAllocator(_tasks), _tasks);
    CFDictionaryRemoveAllValues(_tasks);    
    [_taskLock unlock];
    
    // random order
    NSEnumerator *targetEnumerator = [(NSDictionary *)taskCopy keyEnumerator];
    id target;
    NSArray *modes = [NSArray arrayWithObjects:NSDefaultRunLoopMode, NSEventTrackingRunLoopMode, nil];
    while (target = [targetEnumerator nextObject]) {
        NSArray *taskQueue = [(NSDictionary *)taskCopy objectForKey:target];
        [_taskLock lock];
        [_iconsToRelease minusSet:[NSSet setWithArray:taskQueue]];
        [_taskLock unlock];
        
        // batch these in intervals of TASK_BATCH_SIZE, so the display updates incrementally instead of waiting for all the renders to finish
        NSUInteger i = 0, iMax = [taskQueue count], length = MIN((iMax - i), (NSUInteger)TASK_BATCH_SIZE);
        while (length) {
            NSAutoreleasePool *pool = [NSAutoreleasePool new];
            NSRange r = NSMakeRange(i, length);
            
            id taskBatch[TASK_BATCH_SIZE];
            [taskQueue getObjects:taskBatch range:r];
            
            NSArray *toRender = [[NSArray alloc] initWithObjects:taskBatch count:length];
            [toRender makeObjectsPerformSelector:@selector(renderOffscreen)];
            [target performSelectorOnMainThread:@selector(iconQueueUpdated:) withObject:toRender waitUntilDone:NO modes:modes];
            [toRender release];
            
            i = NSMaxRange(r);
            length = MIN((iMax - i), (NSUInteger)TASK_BATCH_SIZE);
            [pool release];
        }
    }
    CFRelease(taskCopy);
}

- (void)_handleReleaseTasks
{
    NSSet *localCopy = nil;
    
    [_taskLock lock];
    localCopy = [_iconsToRelease copy];
    [_iconsToRelease removeAllObjects];
    [_taskLock unlock];
    
    [localCopy makeObjectsPerformSelector:@selector(releaseResources)];
    [localCopy release];
}

- (void)handleMachMessage:(void *)msg
{    
    NSAutoreleasePool *pool = [NSAutoreleasePool new];

    [self _handleRenderTasks];
    [self _handleReleaseTasks];
    
    [pool release];
}

- (void)_runCacheThread:(id)unused;
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    if ([NSThread instancesRespondToSelector:@selector(setName:)])
        [[NSThread currentThread] setName:@"FVIconQueue thread"];
    
    [_setupLock lockWhenCondition:QUEUE_STARTUP];
    
    NSRunLoop *rl = [NSRunLoop currentRunLoop];
    _threadPort = [[NSMachPort alloc] init];
    [_threadPort setDelegate:self];
    [_threadPort scheduleInRunLoop:rl forMode:NSDefaultRunLoopMode];
    
    [_setupLock unlockWithCondition:QUEUE_STARTUP_COMPLETE];
    
    NSDate *distantFuture = [[NSDate distantFuture] retain];
    BOOL didRun;
    do {
        [pool release];
        pool = [NSAutoreleasePool new];
        didRun = [rl runMode:NSDefaultRunLoopMode beforeDate:distantFuture];
    } while (didRun);
    
    // should never be reached
    id invalidPort = _threadPort;
    _threadPort = nil;
    [invalidPort invalidate];
    [invalidPort release];    
}

@end

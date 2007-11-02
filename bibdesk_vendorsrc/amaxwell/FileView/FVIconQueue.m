//
//  FVIconQueue.m
//  FileViewTest
//
//  Created by Adam Maxwell on 09/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "FVIconQueue.h"


@implementation FVIconQueue

static id sharedInstance = nil;

// let the runtime handle our singleton initialization, since +initialize is thread safe and we can then avoid @synchronized
+ (void)initialize
{
    if (nil == sharedInstance) {
        sharedInstance = [[self alloc] init];
    }        
}

+ (FVIconQueue *)sharedQueue;
{
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        _taskLock = [[NSLock alloc] init];
        _tasks = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        _iconsToRelease = [NSMutableSet new];
        
        // this causes a retain cycle, but we want the object to be persistent anyway
        [NSThread detachNewThreadSelector:@selector(_runCacheThread:) toTarget:self withObject:nil];
    }
    return self;
}

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
        
        // batch these in intervals of 5, so the display updates incrementally instead of waiting for all the renders to finish
        NSUInteger i = 0, iMax = [taskQueue count], length = MIN((iMax - i), (NSUInteger)5);
        while (length) {
            NSRange r = NSMakeRange(i, length);
            [[taskQueue subarrayWithRange:r] makeObjectsPerformSelector:@selector(renderOffscreen)];
            
            // using waitUntilDone:YES keeps the app much more responsive; otherwise we end up with too many drawing updates and repetitive rendering requests
            [target performSelectorOnMainThread:@selector(iconQueueUpdated) withObject:nil waitUntilDone:YES modes:modes];
            i = NSMaxRange(r);
            length = MIN((iMax - i), (NSUInteger)5);
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
    
    NSRunLoop *rl = [NSRunLoop currentRunLoop];
    _threadPort = [[NSMachPort alloc] init];
    [_threadPort setDelegate:self];
    [_threadPort scheduleInRunLoop:rl forMode:NSDefaultRunLoopMode];
    
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

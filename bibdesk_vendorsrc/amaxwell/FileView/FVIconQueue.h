//
//  FVIconQueue.h
//  FileViewTest
//
//  Created by Adam Maxwell on 09/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSObject (FVIconQueueCallBack)
- (void)iconQueueUpdated;
@end

@interface FVIconQueue : NSObject
{
@private
    NSLock                 *_taskLock;
    CFMutableDictionaryRef  _tasks;
    NSMutableSet           *_iconsToRelease;
    NSMachPort             *_threadPort;
}

// these methods may be called from any thread, but the callback will be sent on the main thread
// icon objects respond to -renderOffscreen and -releaseResources; this isn't a general purpose queue

+ (FVIconQueue *)sharedQueue;

// sends -renderOffscreen to icons, invokes iconQueueUpdated at intervals
- (void)enqueueRenderIcons:(NSArray *)icons forObject:(id)anObject;
// sends -releaseResources on icons
- (void)enqueueReleaseResourcesForIcons:(NSArray *)icons;
@end

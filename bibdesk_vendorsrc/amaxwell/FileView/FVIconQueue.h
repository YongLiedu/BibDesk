//
//  FVIconQueue.h
//  FileViewTest
//
//  Created by Adam Maxwell on 09/21/07.
/*
 This software is Copyright (c) 2007
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

#import <Cocoa/Cocoa.h>

@interface NSObject (FVIconQueueCallBack)
- (void)iconQueueUpdated:(NSArray *)updatedIcons;
@end

@interface FVIconQueue : NSObject
{
@private
    NSConditionLock        *_setupLock;
    NSLock                 *_taskLock;
    CFMutableDictionaryRef  _tasks;
    NSMutableSet           *_iconsToRelease;
    NSMachPort             *_threadPort;
}

// these methods may be called from any thread, but the callback will be sent on the main thread
// icon objects respond to -renderOffscreen and -releaseResources; this isn't a general purpose queue

// for main thread only; create another instance per-thread if you need to (but it will leak)
+ (FVIconQueue *)sharedQueue;

// sends -renderOffscreen to icons, invokes iconQueueUpdated at intervals
- (void)enqueueRenderIcons:(NSArray *)icons forObject:(id)anObject;
// sends -releaseResources on icons
- (void)enqueueReleaseResourcesForIcons:(NSArray *)icons;
@end

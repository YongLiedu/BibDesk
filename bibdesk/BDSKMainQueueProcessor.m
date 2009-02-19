//
//  BDSKMainQueueProcessor.m
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

#import "BDSKMainQueueProcessor.h"
#import "BDSKMessageQueue.h"


@implementation BDSKMainQueueProcessor

- (id)initForQueue:(BDSKMessageQueue *)aQueue {
    if (self = [super initForQueue:aQueue]) {
        notificationPort = [[NSPort port] retain];
        [notificationPort setDelegate:self];
        
        portMessage = [[NSPortMessage alloc] initWithSendPort:notificationPort receivePort:notificationPort components:nil];
    }
    return self;
}

- (void)dealloc {
    [notificationPort setDelegate:nil];
    [notificationPort release];
    [portMessage release];
    [super dealloc];
}

- (void)startProcessingQueue {
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    NSArray *modes = [NSArray arrayWithObjects: NSDefaultRunLoopMode, NSModalPanelRunLoopMode, NSEventTrackingRunLoopMode, nil];
    unsigned int modeIndex, modeCount = [modes count];
    for (modeIndex = 0; modeIndex < modeCount; modeIndex++)
        [runLoop addPort:notificationPort forMode:[modes objectAtIndex:modeIndex]];

    [self processQueue];
}

- (void)continueProcessingQueue {
   if (disableCount == 0)
       [portMessage sendBeforeDate:[NSDate distantPast]];
}

- (void)handlePortMessage:(NSPortMessage *)message {
    if (disableCount == 0)
        [self processQueue];
}

// Disallow recursive queue processing.

- (void)processQueue {
    disableCount++;
    @try { [super processQueue]; }
    @catch(id e) { @throw e; }
    @finally {
        if (disableCount > 0)
            disableCount--;
        if (disableCount == 0 && [messageQueue hasInvocations])
            [self continueProcessingQueue];
    }
}

- (BOOL)shouldProcessQueueEnd {
    return nil != [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantPast] inMode:NSEventTrackingRunLoopMode dequeue:NO];
}

@end

//
//  BDSKSearchIndex.h
//  Bibdesk
//
//  Created by Adam Maxwell on 10/11/05.
/*
 This software is Copyright (c) 2005,2006
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

@protocol BDSKSearchIndexDelegate <NSObject>
- (void)updateSearchIfNeeded;
@end

// I think a union guarantees correct alignment; is that true for a struct as well?
typedef struct _BDSKSearchIndexFlags
{
    volatile int32_t shouldKeepRunning __attribute__ ((aligned (4)));
    volatile int32_t isIndexing __attribute__ ((aligned (4)));    
} BDSKSearchIndexFlags;

@interface BDSKSearchIndex : NSObject {
    SKIndexRef index;
    id document;
    
    id delegate;
    NSArray *initialObjectsToIndex;
    
    NSMutableArray *notificationQueue;
    NSMachPort *notificationPort;
    pthread_t notificationThread;
    BDSKSearchIndexFlags flags;
        
    NSLock *queueLock;
}

- (id)initWithDocument:(id)aDocument;

// Warning:  it is /not/ safe to write to this SKIndexRef directly; use it only for reading.
- (SKIndexRef)index;
- (void)cancel;
- (BOOL)isIndexing;
- (void)setDelegate:(id <BDSKSearchIndexDelegate>)anObject;

@end

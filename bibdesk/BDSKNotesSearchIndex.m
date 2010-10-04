//
//  BDSKNotesSearchIndex.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 9/1/09.
/*
 This software is Copyright (c) 2009-2010
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

#import "BDSKNotesSearchIndex.h"
#import "BibItem.h"
#import "BDSKStringConstants.h"
#import "NSURL_BDSKExtensions.h"
#import <libkern/OSAtomic.h>
#import <SkimNotesBase/SkimNotesBase.h>


@interface BDSKNotesSearchIndex (BDSKPrivate)
- (void)runIndexThread;
@end

@implementation BDSKNotesSearchIndex

#define INDEX_STARTUP 1
#define INDEX_STARTUP_COMPLETE 2
#define INDEX_THREAD_WORKING 3
#define INDEX_THREAD_DONE 4

#define QUEUE_EMPTY 0
#define QUEUE_HAS_ITEMS 1

- (id)init
{
    if (self = [super init]) {
        queueLock = [[NSConditionLock alloc] initWithCondition:QUEUE_EMPTY];
        queue = [[NSMutableArray alloc] init];
        shouldKeepRunning = 1;
        needsFlushing = 0;
        
        setupLock = [[NSConditionLock alloc] initWithCondition:INDEX_STARTUP];
        
        [NSThread detachNewThreadSelector:@selector(runIndexThread) toTarget:self withObject:nil];
        
        [setupLock lockWhenCondition:INDEX_STARTUP_COMPLETE];
        [setupLock unlockWithCondition:INDEX_THREAD_WORKING];
        
        [self resetWithPublications:nil];
    }
    return self;
}

- (void)dealloc
{
    BDSKCFDESTROY(skIndex);
    BDSKDESTROY(queue);
	BDSKDESTROY(queueLock);
    BDSKDESTROY(setupLock);
    [super dealloc];
}

- (BOOL)shouldKeepRunning
{
    OSMemoryBarrier();
    return shouldKeepRunning;
}

- (void)terminate
{
    OSAtomicCompareAndSwap32Barrier(1, 0, &shouldKeepRunning);
    [queueLock lock];
    [queue removeAllObjects];
    // make sure the worker thread wakes up
    [queueLock unlockWithCondition:QUEUE_HAS_ITEMS];
    [setupLock lockWhenCondition:INDEX_THREAD_DONE];
    [setupLock unlock];
}

- (void)queueItemForIdentifierURL:(NSURL *)identifierURL fileURLs:(NSArray *)fileURLs
{
    if ([self shouldKeepRunning]) {
        NSDictionary *info = [[NSDictionary alloc] initWithObjectsAndKeys:identifierURL, @"identifierURL", ([fileURLs count] ? fileURLs : nil), @"fileURLs", nil];
        [queueLock lock];
        NSInteger i = [queue count];
        while (i-- > 0) {
            if ([[[queue objectAtIndex:i] valueForKey:@"identifierURL"] isEqual:identifierURL])
                [queue removeObjectAtIndex:i];
        }
        [queue addObject:info];
        [queueLock unlockWithCondition:QUEUE_HAS_ITEMS];
        [info release];
    }
}

- (void)addPublications:(NSArray *)pubs
{
    for (BibItem *pub in pubs)
        [self queueItemForIdentifierURL:[pub identifierURL] fileURLs:[[pub existingLocalFiles] valueForKey:@"URL"]];
}

- (void)removePublications:(NSArray *)pubs
{
    for (BibItem *pub in pubs)
        [self queueItemForIdentifierURL:[pub identifierURL] fileURLs:nil];
}

- (void)resetWithPublications:(NSArray *)pubs
{
    CFMutableDataRef indexData = CFDataCreateMutable(NULL, 0);
    NSDictionary *options = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInteger:0], (id)kSKMaximumTerms, nil];
    @synchronized(self) {
        BDSKCFDESTROY(skIndex);
        skIndex = SKIndexCreateWithMutableData(indexData, (CFStringRef)BDSKSkimNotesString, kSKIndexInverted, (CFDictionaryRef)options);
    }
    CFRelease(indexData);
    [options release];
    
    // this will handle the index flush after adding all the pubs
    [self addPublications:pubs];
}


- (SKIndexRef)index
{
    SKIndexRef theIndex = NULL;
    @synchronized(self) {
        if (skIndex) theIndex = (SKIndexRef)CFRetain(skIndex);
    }
    OSMemoryBarrier();
    if (needsFlushing) {
        SKIndexFlush(theIndex);
        OSAtomicCompareAndSwap32Barrier(1, 0, &needsFlushing);
    }
    return (SKIndexRef)[(id)theIndex autorelease];
}

- (void)indexItem:(NSDictionary *)info
{
    @try {
        SKDocumentRef doc = SKDocumentCreateWithURL((CFURLRef)[info valueForKey:@"identifierURL"]);
        NSArray *fileURLs = [info valueForKey:@"fileURLs"];
        NSMutableString *searchText = nil;
        if ([fileURLs count]) {
            searchText = [NSMutableString string];
            for (NSURL *fileURL in fileURLs) {
                NSString *notesString = nil;
                FSRef fileRef;
                CFStringRef theUTI = NULL;
                if (CFURLGetFSRef((CFURLRef)fileURL, &fileRef))
                    LSCopyItemAttribute(&fileRef, kLSRolesAll, kLSItemContentType, (CFTypeRef *)&theUTI);
                if (theUTI && UTTypeConformsTo(theUTI, CFSTR("net.sourceforge.skim-app.pdfd")))
                    notesString = [fileManager readSkimTextNotesFromPDFBundleAtURL:fileURL error:NULL];
                else
                    notesString = [fileManager readSkimTextNotesFromExtendedAttributesAtURL:fileURL error:NULL];
                if (notesString == nil) {
                    NSArray *notes = nil;
                    if (theUTI && UTTypeConformsTo(theUTI, CFSTR("net.sourceforge.skim-app.pdfd")))
                        notes = [fileManager readSkimNotesFromPDFBundleAtURL:fileURL error:NULL];
                    else if (theUTI && UTTypeConformsTo(theUTI, CFSTR("net.sourceforge.skim-app.skimnotes")))
                        notes = [fileManager readSkimNotesFromSkimFileAtURL:fileURL error:NULL];
                    else
                        notes = [fileManager readSkimNotesFromExtendedAttributesAtURL:fileURL error:NULL];
                    if (notes)
                        notesString = SKNSkimTextNotes(notes);
                }
                if ([notesString length]) {
                    if ([searchText length])
                        [searchText appendString:@"\n"];
                    [searchText appendString:notesString];
                }
            }
        }
        if (doc) {
            SKIndexRef theIndex = NULL;
            @synchronized(self) {
                if (skIndex) theIndex = (SKIndexRef)CFRetain(skIndex);
            }
            if (theIndex) {
                if ([searchText length])
                    SKIndexAddDocumentWithText(theIndex, doc, (CFStringRef)searchText, TRUE);
                else
                    SKIndexRemoveDocument(theIndex, doc);
                CFRelease(theIndex);
                OSAtomicCompareAndSwap32Barrier(0, 1, &needsFlushing);
            }
        }
    }
    @catch(id e) {
        NSLog(@"Ignored exception %@ when executing an index update", e);
    }
}

- (void)runIndexThread
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    fileManager = [[NSFileManager alloc] init];
    
    [setupLock lockWhenCondition:INDEX_STARTUP];
    [setupLock unlockWithCondition:INDEX_STARTUP_COMPLETE];
    [setupLock lockWhenCondition:INDEX_THREAD_WORKING];
	
    // process items from the queue until we should stop
    @try {
        while ([self shouldKeepRunning]) {
            NSDictionary *info = nil;
            
            // get the next item from the queue as soon as it's available
            [queueLock lockWhenCondition:QUEUE_HAS_ITEMS];
            NSUInteger count = [queue count];
            if (count) {
                info = [[queue objectAtIndex:0] retain];
                [queue removeObjectAtIndex:0];
                count--;
            }
            [queueLock unlockWithCondition:count > 0 ? QUEUE_HAS_ITEMS : QUEUE_EMPTY];
            
            if (info)
                [self indexItem:info];
            
            [pool release];
            pool = [[NSAutoreleasePool alloc] init];
        }
    }
    @catch(id e) {
        NSLog(@"Exception %@ raised in search index; exiting thread run loop.", e);
        @throw;
    }
    @finally {
        // allow the top-level pool to catch this autorelease pool
        [fileManager release];
        [setupLock unlockWithCondition:INDEX_THREAD_DONE];
        [pool release];
    }
}

@end

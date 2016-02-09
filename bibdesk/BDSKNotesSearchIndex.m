//
//  BDSKNotesSearchIndex.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 9/1/09.
/*
 This software is Copyright (c) 2009-2016
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
- (void)indexItemForIdentifierURL:(NSURL *)identifierURL fileURLs:(NSArray *)fileURLs;
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
    self = [super init];
    if (self) {
        shouldKeepRunning = 1;
        needsFlushing = 0;
        
        queue = dispatch_queue_create("edu.ucsd.cs.mmccrack.bibdesk.queue.BDSKNotesSearchIndex", NULL);
        lockQueue = dispatch_queue_create("edu.ucsd.cs.mmccrack.bibdesk.lockQueue.BDSKNotesSearchIndex", NULL);
        
        fileManager = [[NSFileManager alloc] init];
        
        [self resetWithPublications:nil];
    }
    return self;
}

- (void)dealloc
{
    BDSKDISPATCHDESTROY(queue);
    BDSKDISPATCHDESTROY(lockQueue);
    BDSKCFDESTROY(skIndex);
    BDSKDESTROY(fileManager);
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
    dispatch_sync(queue, ^{});
}

- (void)addPublications:(NSArray *)pubs
{
    for (BibItem *pub in pubs) {
        if ([self shouldKeepRunning] == NO) break;
        NSURL *identifierURL = [pub identifierURL];
        NSArray *fileURLs = [[pub existingLocalFiles] valueForKey:@"URL"];
        dispatch_async(queue, ^{
            [self indexItemForIdentifierURL:identifierURL fileURLs:fileURLs];
        });
    }
}

- (void)removePublications:(NSArray *)pubs
{
    for (BibItem *pub in pubs) {
        if ([self shouldKeepRunning] == NO) break;
        NSURL *identifierURL = [pub identifierURL];
        dispatch_async(queue, ^{
            [self indexItemForIdentifierURL:identifierURL fileURLs:nil];
        });
    }
}

- (void)resetWithPublications:(NSArray *)pubs
{
    CFMutableDataRef indexData = CFDataCreateMutable(NULL, 0);
    NSDictionary *options = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInteger:0], (id)kSKMaximumTerms, nil];
    dispatch_sync(lockQueue, ^{
        BDSKCFDESTROY(skIndex);
        skIndex = SKIndexCreateWithMutableData(indexData, (CFStringRef)BDSKSkimNotesString, kSKIndexInverted, (CFDictionaryRef)options);
    });
    CFRelease(indexData);
    [options release];
    
    // this will handle the index flush after adding all the pubs
    [self addPublications:pubs];
}


- (SKIndexRef)index
{
    __block SKIndexRef theIndex = NULL;
    dispatch_sync(lockQueue, ^{
        if (skIndex) theIndex = (SKIndexRef)CFRetain(skIndex);
    });
    OSMemoryBarrier();
    if (needsFlushing) {
        SKIndexFlush(theIndex);
        OSAtomicCompareAndSwap32Barrier(1, 0, &needsFlushing);
    }
    return (SKIndexRef)[(id)theIndex autorelease];
}

- (void)indexItemForIdentifierURL:(NSURL *)identifierURL fileURLs:(NSArray *)fileURLs
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    @try {
        SKDocumentRef doc = SKDocumentCreateWithURL((CFURLRef)identifierURL);
        if (doc) {
            
            NSMutableString *searchText = nil;
            if ([fileURLs count]) {
                searchText = [NSMutableString string];
                for (NSURL *fileURL in fileURLs) {
                    NSString *notesString = nil;
                    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
                    NSString *type = [ws typeOfFile:[fileURL path] error:NULL];
                    if (type && [ws type:type conformsToType:@"net.sourceforge.skim-app.pdfd"])
                        notesString = [fileManager readSkimTextNotesFromPDFBundleAtURL:fileURL error:NULL];
                    else
                        notesString = [fileManager readSkimTextNotesFromExtendedAttributesAtURL:fileURL error:NULL];
                    if (notesString == nil) {
                        NSArray *notes = nil;
                        if (type && [ws type:type conformsToType:@"net.sourceforge.skim-app.pdfd"])
                            notes = [fileManager readSkimNotesFromPDFBundleAtURL:fileURL error:NULL];
                        else if (type && [ws type:type conformsToType:@"net.sourceforge.skim-app.skimnotes"])
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
            
            __block SKIndexRef theIndex = NULL;
            dispatch_sync(lockQueue, ^{
                if (skIndex) theIndex = (SKIndexRef)CFRetain(skIndex);
            });
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
    
    [pool drain];
}

@end

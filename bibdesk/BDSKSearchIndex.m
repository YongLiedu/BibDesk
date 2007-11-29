//
//  BDSKSearchIndex.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/11/05.
/*
 This software is Copyright (c) 2005,2006,2007
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

#import "BDSKSearchIndex.h"
#import "BibDocument.h"
#import "BibItem.h"
#import <libkern/OSAtomic.h>
#import "BDSKTypeManager.h"
#import "BDSKThreadSafeMutableArray.h"
#import "NSObject_BDSKExtensions.h"

@interface BDSKSearchIndex (Private)

- (void)rebuildIndex;
- (void)indexFilesForItem:(id)anItem;
void *setupThreading(void *anObject);
- (void)processNotification:(NSNotification *)note;
- (void)handleDocAddItemNotification:(NSNotification *)note;
- (void)handleDocDelItemNotification:(NSNotification *)note;
- (void)handleSearchIndexInfoChangedNotification:(NSNotification *)note;
- (void)handleMachMessage:(void *)msg;

// use this to keep a temporary cache of objects for initial index creation, to avoid messaging the document from our worker thread
- (void)setInitialObjectsToIndex:(NSArray *)objects;

@end

/* Access to the SKIndexRef is no longer locked, since all access to it takes place on the worker pthread.  We could possibly switch to NSThread for running the worker thread now that the retain issue has been addressed, but the pthread solution works  well and has been debugged.  Setting flags.isIndexing should always succeed, since it's only changed from the worker thread; we're using the OSAtomic functions just in case (and because they're interesting). */

@implementation BDSKSearchIndex

#define INDEX_STARTUP 1
#define INDEX_STARTUP_COMPLETE 2

+ (void)initialize
{
    OBINITIALIZE;
    // ensure that the AppKit knows we're multithreaded, since we're using pthreads
    [NSThread detachNewThreadSelector:NULL toTarget:nil withObject:nil];
}

- (id)initWithDocument:(id)aDocument
{
    OBASSERT([NSThread inMainThread]);

    self = [super init];
        
    if(nil != self){
    
        CFMutableDataRef indexData = CFDataCreateMutable(CFAllocatorGetDefault(), 0);
        index = SKIndexCreateWithMutableData(indexData, NULL, kSKIndexInverted, NULL);
        CFRelease(indexData); // @@ doc bug: is this owned by the index now?  seems to be...
            
        document = [aDocument retain];
        delegate = nil;
        [self setInitialObjectsToIndex:[[aDocument publications] arrayByPerformingSelector:@selector(searchIndexInfo)]];
        
        flags.isIndexing = 0;
        flags.shouldKeepRunning = 1;
        
        // maintain a dictionary mapping URL -> item titles, since SKIndex properties are slow
        titles = [[NSMutableDictionary alloc] initWithCapacity:128];
        
        progressValue = 0.0;
        
        setupLock = [[NSConditionLock alloc] initWithCondition:INDEX_STARTUP];
        
        // this will create a retain cycle, so we'll have to tickle the thread to exit properly in -cancel
        [NSThread detachNewThreadSelector:@selector(runIndexThread) toTarget:self withObject:nil];
        
        // block until the NSMachPort is set up to receive messages
        [setupLock lockWhenCondition:INDEX_STARTUP_COMPLETE];
        [setupLock unlock];
        
        // done with this lock, so get rid of it now
        [setupLock release];
        setupLock = nil;
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [notificationPort release];
    [notificationQueue release];
    [titles release];
    if(index) CFRelease(index);
    [super dealloc];
}

// cancel is usually sent from the main thread
- (void)cancel
{
    OSAtomicCompareAndSwap32(flags.shouldKeepRunning, 0, (int32_t *)&flags.shouldKeepRunning);
    
    // the document does cleanup that should only be performed on the main thread (this was causing an assertion failure in -[BDSKFileContentSearchController cancelCurrentSearch:])
    [document performSelectorOnMainThread:@selector(release) withObject:nil waitUntilDone:NO];
    document = nil;
    
    // wake the thread up so the runloop will exit
    [notificationPort sendBeforeDate:[NSDate date] components:nil from:nil reserved:0];
}

- (SKIndexRef)index
{
    return index;
}

- (BOOL)isIndexing
{
    uint32_t isIndexing = flags.isIndexing;
    return isIndexing == 1;
}

- (void)setDelegate:(id <BDSKSearchIndexDelegate>)anObject
{
    if(anObject)
        NSAssert1([(id)anObject conformsToProtocol:@protocol(BDSKSearchIndexDelegate)], @"%@ does not conform to BDSKSearchIndexDelegate protocol", [anObject class]);

    delegate = anObject;
}

- (NSString *)titleForURL:(NSURL *)theURL
{
    NSString *theTitle = nil;
    @synchronized(titles) {
        theTitle = [[titles objectForKey:theURL] retain];
    }
    return [theTitle autorelease];
}

- (double)progressValue
{
    double theValue;
    @synchronized(self) {
        theValue = progressValue;
    }
    return theValue;
}

@end

@implementation BDSKSearchIndex (Private)

- (void)indexFilesForItems:(NSArray *)items
{
    NSAssert2([[NSThread currentThread] isEqual:notificationThread], @"-[%@ %@] must be called from the worker thread!", [self class], NSStringFromSelector(_cmd));
    
    NSEnumerator *enumerator = [items objectEnumerator];
    id anObject = nil;
    double totalObjectCount = [items count];
    double numberIndexed = 0;
    
    // This threshold is sort of arbitrary; for small batches, frequent updates are better if the delegate has a progress indicator, but for large batches (initial indexing), it can kill performance to be continually flushing and searching while indexing.
    const int32_t flushInterval = [items count] > 20 ? 5 : 1;
    int32_t countSinceLastFlush = flushInterval;
    
    // Use a local pool since initial indexing can use a fair amount of memory, and it's not released until the thread's run loop starts
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    while((anObject = [enumerator nextObject]) && flags.shouldKeepRunning == 1) {
        [self indexFilesForItem:anObject];
        numberIndexed++;
        @synchronized(self) {
            progressValue = (numberIndexed / totalObjectCount) * 100;
        }
        
        if (countSinceLastFlush-- == 0) {
            [pool release];
            pool = [NSAutoreleasePool new];
            
            [delegate performSelectorOnMainThread:@selector(searchIndexDidUpdate:) withObject:self waitUntilDone:NO];
            countSinceLastFlush = flushInterval;
        }
    }
    
    // final update to catch any leftovers
    
    // it's possible that we've been told to stop, and the delegate is garbage; in that case, don't message it
    if (flags.shouldKeepRunning == 1)
        [delegate performSelectorOnMainThread:@selector(searchIndexDidUpdate:) withObject:self waitUntilDone:NO];
    [pool release];
}

- (void)rebuildIndex
{    
    NSAssert2([[NSThread currentThread] isEqual:notificationThread], @"-[%@ %@] must be called from the worker thread!", [self class], NSStringFromSelector(_cmd));
    
    OBPRECONDITION(initialObjectsToIndex);
    [self indexFilesForItems:initialObjectsToIndex];
    
    // release these, since they're only used for the initial index creation
    [self setInitialObjectsToIndex:nil];
    if (flags.shouldKeepRunning == 1)
        [delegate performSelectorOnMainThread:@selector(searchIndexDidFinishInitialIndexing:) withObject:self waitUntilDone:NO];
}

- (void)indexFilesForItem:(id)anItem
{
    OBASSERT([[NSThread currentThread] isEqual:notificationThread]);
    NSURL *url = nil;
    
    SKDocumentRef skDocument;
    volatile Boolean success;
    
    NSEnumerator *urlEnumerator = [[anItem valueForKey:@"urls"] objectEnumerator];
        
    BOOL swap;
    swap = OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.isIndexing);
    OBASSERT(swap);
    
    
    while(url = [urlEnumerator nextObject]){
                
        skDocument = SKDocumentCreateWithURL((CFURLRef)url);
        OBPOSTCONDITION(skDocument);
        if(skDocument == NULL) continue;
        
        // SKIndexSetProperties is more generally useful, but is really slow when creating the index
        // SKIndexRenameDocument changes the URL, so it's not useful
        @synchronized(titles) {
            [titles setObject:[anItem valueForKey:@"title"] forKey:url];
        }
        
        success = SKIndexAddDocument(index, skDocument, NULL, TRUE);
        OBPOSTCONDITION(success);
        
        CFRelease(skDocument);
    }
    swap = OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.isIndexing);
    OBASSERT(swap);
    
    // the caller is responsible for updating the delegate, so we can throttle initial indexing
}

- (void)runIndexThread
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [setupLock lockWhenCondition:INDEX_STARTUP];
    
    // release at the end of this method, just before the thread exits
    notificationThread = [[NSThread currentThread] retain];
    
    notificationPort = [[NSMachPort alloc] init];
    [notificationPort setDelegate:self];
    [[NSRunLoop currentRunLoop] addPort:notificationPort forMode:NSDefaultRunLoopMode];
    
    notificationQueue = [[BDSKThreadSafeMutableArray alloc] initWithCapacity:5];
        
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    SEL handler = @selector(processNotification:);
    [nc addObserver:self selector:handler name:BDSKSearchIndexInfoChangedNotification object:document];
    [nc addObserver:self selector:handler name:BDSKDocAddItemNotification object:document];
    [nc addObserver:self selector:handler name:BDSKDocDelItemNotification object:document];
    
    [setupLock unlockWithCondition:INDEX_STARTUP_COMPLETE];
    
    // an exception here can probably be ignored safely
    @try{
        [self rebuildIndex];
    }
    @catch(id localException){
        NSLog(@"Ignoring exception %@ raised while rebuilding index", localException);
    }
        
    // run the current run loop until we get a cancel message, or else the current thread/run loop will just go away when this function returns    
    @try{
        
        NSRunLoop *rl = [NSRunLoop currentRunLoop];
        BOOL keepRunning;
        NSDate *distantFuture = [NSDate distantFuture];
        
        do {
            [pool release];
            pool = [[NSAutoreleasePool alloc] init];
            // Running with beforeDate: distantFuture causes the runloop to block indefinitely if shouldKeepRunning was set to 0 during the initial indexing phase; invalidating and removing the port manually doesn't change this.  Hence, we need to check that flag before running the runloop, or use a short limit date.
            keepRunning = (flags.shouldKeepRunning == 1) && [rl runMode:NSDefaultRunLoopMode beforeDate:distantFuture];
        } while(keepRunning);
    }
    @catch(id localException){
        NSLog(@"Exception %@ raised in search index; exiting thread run loop.", localException);
        @throw;
    }
    @finally{
        // allow the top-level pool to catch this autorelease pool
        
        [notificationThread release];
        notificationThread = nil;
        [notificationPort invalidate];
    }
}

- (void)processNotification:(NSNotification *)note
{    
    if([[NSThread currentThread] isEqual:notificationThread] == NO){
        // Forward the notification to the correct thread
        [notificationQueue addObject:note];
        [notificationPort sendBeforeDate:[NSDate date] components:nil from:nil reserved:0];
        
    } else {
        // this is a background thread that can handle these notifications
        if([[note name] isEqualToString:BDSKSearchIndexInfoChangedNotification])
            [self handleSearchIndexInfoChangedNotification:note];
        else if([[note name] isEqualToString:BDSKDocAddItemNotification])
            [self handleDocAddItemNotification:note];
        else if([[note name] isEqualToString:BDSKDocDelItemNotification])
            [self handleDocDelItemNotification:note];
        else
            [NSException raise:NSInvalidArgumentException format:@"notification %@ is not handled by %@", note, self];
                
    }
}

- (void)handleDocAddItemNotification:(NSNotification *)note
{
    OBASSERT([[NSThread currentThread] isEqual:notificationThread]);

	NSArray *searchIndexInfo = [[note userInfo] valueForKey:@"searchIndexInfo"];
    OBPRECONDITION(searchIndexInfo);
            
    // this will update the delegate when all is complete
    [self indexFilesForItems:searchIndexInfo];        
}

- (void)handleDocDelItemNotification:(NSNotification *)note
{
    OBASSERT([[NSThread currentThread] isEqual:notificationThread]);

	NSEnumerator *itemEnumerator = [[[note userInfo] valueForKey:@"searchIndexInfo"] objectEnumerator];
    id anItem;
    
    NSURL *url = nil;
    
    SKDocumentRef skDocument;
    volatile Boolean success;
    
    NSArray *urls = nil;
    unsigned int idx, maxIdx;
    
    // set this here because we're adding to the index apart from indexFilesForItem:
    BOOL swap;
    swap = OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.isIndexing);
    OBASSERT(swap);

	while(anItem = [itemEnumerator nextObject]){
        urls = [anItem valueForKey:@"urls"];
        maxIdx = [urls count];
        
        // loop through the array of URLs, create a new SKDocumentRef, and try to remove it
		for(idx = 0; idx < maxIdx; idx++){
			
			url = [urls objectAtIndex:idx];
            
            @synchronized(titles) {
                [titles removeObjectForKey:url];
            }
			
			skDocument = SKDocumentCreateWithURL((CFURLRef)url);
			OBPOSTCONDITION(skDocument);
			if(!skDocument) continue;
			
			success = SKIndexRemoveDocument(index, skDocument);
			OBPOSTCONDITION(success);
			
			CFRelease(skDocument);
		}
	}
    swap = OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.isIndexing);
    OBASSERT(swap);
	
    [delegate performSelectorOnMainThread:@selector(searchIndexDidUpdate:) withObject:self waitUntilDone:NO];
}

- (void)handleSearchIndexInfoChangedNotification:(NSNotification *)note
{
    OBASSERT([[NSThread currentThread] isEqual:notificationThread]);

    // reindex all the files; unless you have many local files attached to the item, there won't be much savings vs. just adding the one that changed
    [self indexFilesForItem:[note userInfo]];
    
    // we used to remove the old object from the array, but it's a) not thread safe and b) having an extra document in the index isn't that bad
    [delegate performSelectorOnMainThread:@selector(searchIndexDidUpdate:) withObject:self waitUntilDone:NO];
}    

- (void)handleMachMessage:(void *)msg
{

    while ( [notificationQueue count] ) {
        NSNotification *note = [[notificationQueue objectAtIndex:0] retain];
        [notificationQueue removeObjectAtIndex:0];
        [self processNotification:note];
        [note release];
    }
}

- (void)setInitialObjectsToIndex:(NSArray *)objects{
    if(objects != initialObjectsToIndex){
        [initialObjectsToIndex release];
        initialObjectsToIndex = [objects copy];
    }
}

@end

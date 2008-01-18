//
//  BDSKFileSearchIndex.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/11/05.
/*
 This software is Copyright (c) 2005-2008
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

#import "BDSKFileSearchIndex.h"
#import "BibDocument.h"
#import "BibItem.h"
#import <libkern/OSAtomic.h>
#import "BDSKThreadSafeMutableArray.h"
#import "BDSKThreadSafeMutableDictionary.h"
#import "NSObject_BDSKExtensions.h"

@interface BDSKFileSearchIndex (Private)

+ (NSString *)indexCacheFolder;
+ (NSString *)indexCachePathForDocumentURL:(NSURL *)documentURL;
- (NSArray *)itemsToIndex:(NSArray *)items;
- (void)buildIndexForItems:(NSArray *)items;
- (void)indexFilesForItems:(NSArray *)items numberPreviouslyIndexed:(double)numberIndexed totalCount:(double)totalObjectCount;
- (void)indexFilesForItem:(id)anItem;
- (void)runIndexThreadForItems:(NSArray *)items;
- (void)processNotification:(NSNotification *)note;
- (void)handleDocAddItemNotification:(NSNotification *)note;
- (void)handleDocDelItemNotification:(NSNotification *)note;
- (void)handleSearchIndexInfoChangedNotification:(NSNotification *)note;
- (void)handleMachMessage:(void *)msg;
- (void)writeIndexToDiskForDocumentURL:(NSURL *)documentURL;

@end
        

@implementation BDSKFileSearchIndex

#define INDEX_STARTUP 1
#define INDEX_STARTUP_COMPLETE 2
#define INDEX_THREAD_WORKING 3
#define INDEX_THREAD_DONE 4

- (id)initWithDocument:(id)aDocument
{
    OBASSERT([NSThread inMainThread]);

    self = [super init];
        
    if(nil != self){
        // maintain dictionaries mapping URL -> sha1Signature, so we can check if a URL is outdated
        signatures = [[NSMutableDictionary alloc] initWithCapacity:128];
        
        index = NULL;
        
        // new document won't have a URL, so we'll have to wait for the controller to set it
        NSString *indexCachePath = [aDocument fileURL] ? [[self class] indexCachePathForDocumentURL:[aDocument fileURL]] : nil;
        if (indexCachePath) {
            NSDictionary *cacheDict = [NSKeyedUnarchiver unarchiveObjectWithFile:indexCachePath];
            indexData = (CFMutableDataRef)[[cacheDict objectForKey:@"indexData"] mutableCopy];
            if (indexData != NULL) {
                index = SKIndexOpenWithMutableData(indexData, NULL);
                if (index) {
                    [signatures setDictionary:[cacheDict objectForKey:@"signatures"]];
                } else {
                    CFRelease(indexData);
                    indexData = NULL;
                }
            }
        }
        
        if (index == NULL) {
            indexData = CFDataCreateMutable(CFAllocatorGetDefault(), 0);
            index = SKIndexCreateWithMutableData(indexData, NULL, kSKIndexInverted, NULL);
        }
        
        delegate = nil;
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        SEL handler = @selector(processNotification:);
        [nc addObserver:self selector:handler name:BDSKFileSearchIndexInfoChangedNotification object:aDocument];
        [nc addObserver:self selector:handler name:BDSKDocAddItemNotification object:aDocument];
        [nc addObserver:self selector:handler name:BDSKDocDelItemNotification object:aDocument];
        
        flags.isIndexing = 0;
        flags.shouldKeepRunning = 1;
        
        // maintain dictionaries mapping URL -> itemInfos, since SKIndex properties are slow
        itemInfos = [[BDSKThreadSafeMutableDictionary alloc] initWithCapacity:128];
        
        progressValue = 0.0;
        
        setupLock = [[NSConditionLock alloc] initWithCondition:INDEX_STARTUP];
        
        // this will create a retain cycle, so we'll have to tickle the thread to exit properly in -cancel
        [NSThread detachNewThreadSelector:@selector(runIndexThreadForItems:) toTarget:self withObject:[[aDocument publications] arrayByPerformingSelector:@selector(searchIndexInfo)]];
        
        // block until the NSMachPort is set up to receive messages
        [setupLock lockWhenCondition:INDEX_STARTUP_COMPLETE];
        [setupLock unlockWithCondition:INDEX_THREAD_WORKING];

    }
    
    return self;
}

- (void)dealloc
{
    [notificationPort release];
    [notificationQueue release];
    [itemInfos release];
    [signatures release];
    if(index) CFRelease(index);
    if(indexData) CFRelease(indexData);
    [setupLock release];
    [super dealloc];
}

// cancel is always sent from the main thread
- (void)cancelForDocumentURL:(NSURL *)documentURL
{
    NSParameterAssert([NSThread inMainThread]);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    OSAtomicCompareAndSwap32(flags.shouldKeepRunning, 0, (int32_t *)&flags.shouldKeepRunning);
    
    // wake the thread up so the runloop will exit; shouldKeepRunning may have already done that, so don't send if the port is already dead
    if ([notificationPort isValid])
        [notificationPort sendBeforeDate:[NSDate date] components:nil from:nil reserved:0];
    
    // wait until the thread exits, so we have exclusive access to the ivars
    [setupLock lockWhenCondition:INDEX_THREAD_DONE];
    [self writeIndexToDiskForDocumentURL:documentURL];
    [setupLock unlock];
}

- (SKIndexRef)index
{
    return index;
}

- (BOOL)isIndexing
{
    OSMemoryBarrier();
    return flags.isIndexing == 1;
}

- (void)setDelegate:(id <BDSKFileSearchIndexDelegate>)anObject
{
    if(anObject)
        NSAssert1([(id)anObject conformsToProtocol:@protocol(BDSKFileSearchIndexDelegate)], @"%@ does not conform to BDSKFileSearchIndexDelegate protocol", [anObject class]);

    delegate = anObject;
}

- (NSDictionary *)itemInfoForURL:(NSURL *)theURL
{
    return [itemInfos objectForKey:theURL];
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


static void addLeafURLsInIndexToSet(SKIndexRef anIndex, SKDocumentRef inParentDocument, CFMutableSetRef indexedURLs) {
    SKIndexDocumentIteratorRef iterator = SKIndexDocumentIteratorCreate (anIndex, inParentDocument);
    SKDocumentRef skDocument;
    CFURLRef aURL;
    bool isLeaf = true;
    
    while (skDocument = SKIndexDocumentIteratorCopyNext(iterator)) {
        isLeaf = false;
        addLeafURLsInIndexToSet(anIndex, skDocument, indexedURLs);
        CFRelease(skDocument);
    }
    CFRelease(iterator);
    
    if (isLeaf && inParentDocument && kSKDocumentStateNotIndexed != SKIndexGetDocumentState(anIndex, inParentDocument) && (aURL = SKDocumentCopyURL(inParentDocument))) {
        CFSetAddValue(indexedURLs, aURL);
        CFRelease(aURL);
    }
}

@implementation BDSKFileSearchIndex (Private)

static inline NSData *sha1SignatureForURL(NSURL *aURL) {
    // using the mapped data options will cause a crash in the sha1Signature method
    NSData *data = [[NSData alloc] initWithContentsOfURL:aURL];
    NSData *sha1Signature = [data sha1Signature];
    [data release];
    return sha1Signature;
}

+ (NSString *)indexCacheFolder
{
    static NSString *cacheFolder = nil;
    if (nil == cacheFolder) {
        cacheFolder = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
        cacheFolder = [cacheFolder stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
        if (cacheFolder && [[NSFileManager defaultManager] fileExistsAtPath:cacheFolder] == NO)
            [[NSFileManager defaultManager] createDirectoryAtPath:cacheFolder attributes:nil];
        cacheFolder = [cacheFolder stringByAppendingPathComponent:NSStringFromClass(self)];
        if (cacheFolder && [[NSFileManager defaultManager] fileExistsAtPath:cacheFolder] == NO)
            [[NSFileManager defaultManager] createDirectoryAtPath:cacheFolder attributes:nil];
        cacheFolder = [cacheFolder copy];
    }
    return cacheFolder;
}

// Read each cache file and see which one has a matching documentURL.  If this gets too slow, we could save a plist mapping URL -> UUID and use that instead.
+ (NSString *)indexCachePathForDocumentURL:(NSURL *)documentURL
{
    NSParameterAssert(nil != documentURL);
    NSString *cacheFolder = [self indexCacheFolder];
    NSArray *existingIndexes = [[NSFileManager defaultManager] directoryContentsAtPath:cacheFolder];
    existingIndexes = [existingIndexes pathsMatchingExtensions:[NSArray arrayWithObject:@"bdskindex"]];
    
    NSEnumerator *indexEnum = [existingIndexes objectEnumerator];
    NSString *path;
    NSString *indexCachePath = nil;
    
    while ((path = [indexEnum nextObject]) && nil == indexCachePath) {
        path = [cacheFolder stringByAppendingPathComponent:path];
        NSDictionary *cacheDict = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        if ([[cacheDict objectForKey:@"documentURL"] isEqual:documentURL])
            indexCachePath = path;
    }
    return indexCachePath;
}

- (NSArray *)itemsToIndex:(NSArray *)items
{
    [items retain];
    
    NSMutableSet *indexedURLs = [NSMutableSet set];
    
    addLeafURLsInIndexToSet(index, NULL, (CFMutableSetRef)indexedURLs);
    
    if ([indexedURLs count] == 0)
        return [items autorelease];
    
    NSMutableSet *URLsToRemove = [indexedURLs mutableCopy];
    NSMutableArray *itemsToAdd = [NSMutableArray array];
    
    NSEnumerator *itemEnum = [items objectEnumerator];
    id anItem = nil;
    NSMutableDictionary *previouslyIndexedInfos = [NSMutableDictionary dictionary];
    double numberIndexed = 0;
    double totalObjectCount = [items count];
    
    // see comment later; may need tuning here since this is much faster than adding new docs to the index
    const int32_t flushInterval = 20;
    int32_t countSinceLastFlush = flushInterval;
    
    // update the itemInfos with the items, find items to add and URLs to remove
    OSMemoryBarrier();
    while(flags.shouldKeepRunning == 1 && (anItem = [itemEnum nextObject])) {
        
        NSEnumerator *urlEnum = [[anItem valueForKey:@"urls"] objectEnumerator];
        NSURL *url;
        BOOL needsIndexing = NO;
        
        while (url = [urlEnum nextObject]) {
            if ([indexedURLs containsObject:url]) {
                if ([[signatures objectForKey:url] isEqual:sha1SignatureForURL(url)]) {
                    [URLsToRemove removeObject:url];
                    [previouslyIndexedInfos setObject:anItem forKey:url];
                } else {
                    [signatures removeObjectForKey:url];
                    needsIndexing = YES;
                }
            } else {
                needsIndexing = YES;
            }
        }
                
        if (needsIndexing) {
            [itemsToAdd addObject:anItem];
        } else {
            numberIndexed++;
            @synchronized(self) {
                progressValue = (numberIndexed / totalObjectCount) * 100;
            }
            if (countSinceLastFlush-- == 0) {       
                // must update before sending the delegate message
                [itemInfos addEntriesFromDictionary:previouslyIndexedInfos];
                [previouslyIndexedInfos removeAllObjects];
                
                [[OFMessageQueue mainQueue] queueSelectorOnce:@selector(searchIndexDidUpdate:) forObject:delegate withObject:self];
                countSinceLastFlush = flushInterval;
            }
        }

        OSMemoryBarrier();
    }

    // add any leftovers
    [itemInfos addEntriesFromDictionary:previouslyIndexedInfos];
        
    // remove URLs we could not find in the database
    OSMemoryBarrier();
    if (flags.shouldKeepRunning == 1 && [URLsToRemove count]) {
        NSEnumerator *urlEnum = [URLsToRemove objectEnumerator];
        NSURL *url;
        SKDocumentRef skDocument;
        
        // loop through the array of URLs, create a new SKDocumentRef, and try to remove it
        while (url = [urlEnum nextObject]) {
            
            skDocument = SKDocumentCreateWithURL((CFURLRef)url);
            if (skDocument) {
                SKIndexRemoveDocument(index, skDocument);
                CFRelease(skDocument);
            }
        }
    }
    [URLsToRemove release];
    [items release];

    OSMemoryBarrier();
    if (flags.shouldKeepRunning == 1)
        [delegate performSelectorOnMainThread:@selector(searchIndexDidUpdate:) withObject:self waitUntilDone:NO];
    
    return itemsToAdd;
}

- (void)buildIndexForItems:(NSArray *)items
{
    NSAssert2([[NSThread currentThread] isEqual:notificationThread], @"-[%@ %@] must be called from the worker thread!", [self class], NSStringFromSelector(_cmd));
    
    OBPRECONDITION(items);
    
    // normally set in the indexFilesForItem: method, but we need to avoid returning NO for isIndexing here as well
    OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.isIndexing);

    double totalObjectCount = [items count];
    items = [self itemsToIndex:items];
    double numberIndexed = totalObjectCount - [items count];
    
    [items retain];
    
    // add items that were not yet indexed
    OSMemoryBarrier();
    if (flags.shouldKeepRunning == 1 && [items count]) {
        [self indexFilesForItems:items numberPreviouslyIndexed:numberIndexed totalCount:totalObjectCount];
    }
    
    [items release];
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.isIndexing);

    OSMemoryBarrier();
    if (flags.shouldKeepRunning == 1)
        [delegate performSelectorOnMainThread:@selector(searchIndexDidFinishInitialIndexing:) withObject:self waitUntilDone:NO];
}

- (void)indexFilesForItems:(NSArray *)items numberPreviouslyIndexed:(double)numberIndexed totalCount:(double)totalObjectCount
{
    NSAssert2([[NSThread currentThread] isEqual:notificationThread], @"-[%@ %@] must be called from the worker thread!", [self class], NSStringFromSelector(_cmd));
    
    NSEnumerator *enumerator = [items objectEnumerator];
    id anObject = nil;
    
    // This threshold is sort of arbitrary; for small batches, frequent updates are better if the delegate has a progress indicator, but for large batches (initial indexing), it can kill performance to be continually flushing and searching while indexing.
    const int32_t flushInterval = [items count] > 20 ? 5 : 1;
    int32_t countSinceLastFlush = flushInterval;
    
    // Use a local pool since initial indexing can use a fair amount of memory, and it's not released until the thread's run loop starts
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    OSMemoryBarrier();
    while(flags.shouldKeepRunning == 1 && (anObject = [enumerator nextObject])) {
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
        OSMemoryBarrier();
    }
    
    // final update to catch any leftovers
    
    // it's possible that we've been told to stop, and the delegate is garbage; in that case, don't message it
    OSMemoryBarrier();
    if (flags.shouldKeepRunning == 1)
        [delegate performSelectorOnMainThread:@selector(searchIndexDidUpdate:) withObject:self waitUntilDone:NO];
    [pool release];
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
        
        NSData *signature = sha1SignatureForURL(url);
        
        // SKIndexSetProperties is more generally useful, but is really slow when creating the index
        // SKIndexRenameDocument changes the URL, so it's not useful
        [itemInfos setObject:anItem forKey:url];
        if (signature)
            [signatures setObject:signature forKey:url];
        else
            [signatures removeObjectForKey:url];
        
        success = SKIndexAddDocument(index, skDocument, NULL, TRUE);
        OBPOSTCONDITION(success);
        
        CFRelease(skDocument);
    }
    swap = OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.isIndexing);
    OBASSERT(swap);
    
    // the caller is responsible for updating the delegate, so we can throttle initial indexing
}

- (void)writeIndexToDiskForDocumentURL:(NSURL *)documentURL
{
    NSParameterAssert([NSThread inMainThread]);
    NSParameterAssert([setupLock condition] == INDEX_THREAD_DONE);
    
    // @@ temporary for testing
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKDisableFileSearchIndexCacheKey"])
        return;
    
    if (index && documentURL) {
        // flush all pending updates and compact the index as needed before writing
        SKIndexCompact(index);
        CFRelease(index);
        index = NULL;
        
        NSString *indexCachePath = [[self class] indexCachePathForDocumentURL:documentURL];
        if (nil == indexCachePath) {
            // Could use the doc name, but I keep different files with the same name on shared and local volumes, and presumably others do things that are just as weird.  This guarantees a unique name, so we'll just introspect the caches when loading them.  
            indexCachePath = [[[self class] indexCacheFolder] stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
            indexCachePath = [indexCachePath stringByAppendingPathExtension:@"bdskindex"];
        }
        
        NSDictionary *cacheDict = nil;
        cacheDict = [NSDictionary dictionaryWithObjectsAndKeys:(NSData *)indexData, @"indexData", signatures, @"signatures", documentURL, @"documentURL", nil];
        [NSKeyedArchiver archiveRootObject:cacheDict toFile:indexCachePath];
    }
}

- (void)runIndexThreadForItems:(NSArray *)items
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [setupLock lockWhenCondition:INDEX_STARTUP];
    
    // release at the end of this method, just before the thread exits
    notificationThread = [[NSThread currentThread] retain];
    
    notificationPort = [[NSMachPort alloc] init];
    [notificationPort setDelegate:self];
    [[NSRunLoop currentRunLoop] addPort:notificationPort forMode:NSDefaultRunLoopMode];
    
    notificationQueue = [[BDSKThreadSafeMutableArray alloc] initWithCapacity:5];
    [setupLock unlockWithCondition:INDEX_STARTUP_COMPLETE];
    
    [setupLock lockWhenCondition:INDEX_THREAD_WORKING];
    
    // an exception here can probably be ignored safely
    @try{
        [self buildIndexForItems:items];
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
            OSMemoryBarrier();
            keepRunning = (flags.shouldKeepRunning == 1) && [rl runMode:NSDefaultRunLoopMode beforeDate:distantFuture];
        } while(keepRunning);
    }
    @catch(id localException){
        NSLog(@"Exception %@ raised in search index; exiting thread run loop.", localException);
        
        // clean these up to make sure we have no chance of saving it to disk
        if (index) CFRelease(index);
        index = NULL;
        if (indexData) CFRelease(indexData);
        indexData = NULL;
        @throw;
    }
    @finally{
        // allow the top-level pool to catch this autorelease pool
        
        [notificationThread release];
        notificationThread = nil;
        [notificationPort invalidate];
        [setupLock unlockWithCondition:INDEX_THREAD_DONE];
    }
}

- (void)processNotification:(NSNotification *)note
{    
    OBASSERT([NSThread inMainThread]);
    // Forward the notification to the correct thread
    [notificationQueue addObject:note];
    [notificationPort sendBeforeDate:[NSDate date] components:nil from:nil reserved:0];
}

- (void)handleDocAddItemNotification:(NSNotification *)note
{
    OBASSERT([[NSThread currentThread] isEqual:notificationThread]);

	NSArray *searchIndexInfo = [[note userInfo] valueForKey:@"searchIndexInfo"];
    OBPRECONDITION(searchIndexInfo);
            
    // this will update the delegate when all is complete
    [self indexFilesForItems:searchIndexInfo numberPreviouslyIndexed:0 totalCount:1];        
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
            
            [itemInfos removeObjectForKey:url];
            [signatures removeObjectForKey:url];
			
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

    // Reindex all the files; unless you have many (say a dozen or more) local files attached to the item, there won't be much savings vs. just adding the one that changed.
    [self indexFilesForItem:[note userInfo]];
    
    // @@ files are only added, not removed (unless the BibItem itself is deleted), so we can end up with some stale files in the index
    [delegate performSelectorOnMainThread:@selector(searchIndexDidUpdate:) withObject:self waitUntilDone:NO];
}    

- (void)handleMachMessage:(void *)msg
{
    OBASSERT([NSThread inMainThread] == NO);

    while ( [notificationQueue count] ) {
        NSNotification *note = [[notificationQueue objectAtIndex:0] retain];
        NSString *name = [note name];
        [notificationQueue removeObjectAtIndex:0];
        // this is a background thread that can handle these notifications
        if([name isEqualToString:BDSKFileSearchIndexInfoChangedNotification])
            [self handleSearchIndexInfoChangedNotification:note];
        else if([name isEqualToString:BDSKDocAddItemNotification])
            [self handleDocAddItemNotification:note];
        else if([name isEqualToString:BDSKDocDelItemNotification])
            [self handleDocDelItemNotification:note];
        else
            [NSException raise:NSInvalidArgumentException format:@"notification %@ is not handled by %@", note, self];
        [note release];
    }
}

@end

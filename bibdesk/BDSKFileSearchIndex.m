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
#import "BDSKMultiValueDictionary.h"
#import "NSObject_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSData_BDSKExtensions.h"
#import "UKDirectoryEnumerator.h"

@interface BDSKFileSearchIndex (Private)

+ (NSString *)indexCacheFolder;
+ (NSString *)indexCachePathForDocumentURL:(NSURL *)documentURL;
- (void)buildIndexWithInfo:(NSDictionary *)info;
- (void)indexFileURL:(NSURL *)aURL;
- (void)removeFileURL:(NSURL *)aURL;
- (void)indexFilesForItems:(NSArray *)items numberPreviouslyIndexed:(double)numberIndexed totalCount:(double)totalObjectCount;
- (void)indexFileURLs:(NSSet *)urlstoBeAdded forIdentifierURL:(NSURL *)identifierURL;
- (void)removeFileURLs:(NSSet *)urlstoBeAdded forIdentifierURL:(NSURL *)identifierURL;
- (void)reindexFileURLsIfNeeded:(NSSet *)urlsToReindex forIdentifierURL:(NSURL *)identifierURL;
- (void)runIndexThreadWithInfo:(NSDictionary *)info;
- (void)searchIndexDidUpdate;
- (void)searchIndexDidFinish;
- (void)searchIndexFinishedLoop;
- (void)processNotification:(NSNotification *)note;
- (void)handleDocAddItemNotification:(NSNotification *)note;
- (void)handleDocDelItemNotification:(NSNotification *)note;
- (void)handleSearchIndexInfoChangedNotification:(NSNotification *)note;
- (void)handleMachMessage:(void *)msg;
- (void)writeIndexToDiskForDocumentURL:(NSURL *)documentURL;

@end


@interface OFMessageQueue (BDSKExtensions)

- (void)removeQueueEntry:(OFInvocation *)aQueueEntry;
- (void)removeSelector:(SEL)aSelector forObject:(id <NSObject>)anObject;

@end


@implementation BDSKFileSearchIndex

#define INDEX_STARTUP 1
#define INDEX_STARTUP_COMPLETE 2
#define INDEX_THREAD_WORKING 3
#define INDEX_THREAD_DONE 4

// increment if incompatible changes are introduced
#define CACHE_VERSION @"1"

- (id)initWithDocument:(id)aDocument
{
    OBASSERT([NSThread inMainThread]);

    self = [super init];
        
    if(nil != self){
        // maintain dictionaries mapping URL -> sha1Signature, so we can check if a URL is outdated
        signatures = [[NSMutableDictionary alloc] initWithCapacity:128];
        
        index = NULL;
        
        // new document won't have a URL, so we'll have to wait for the controller to set it
        NSURL *documentURL = [aDocument fileURL];
        NSArray *items = [[aDocument publications] arrayByPerformingSelector:@selector(searchIndexInfo)];
        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:items, @"items", documentURL, @"documentURL", nil];
        
        // setting up the cache folder is not thread safe, so make sure it's done on the main thread
        [[self class] indexCacheFolder];
        
        delegate = nil;
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        SEL handler = @selector(processNotification:);
        [nc addObserver:self selector:handler name:BDSKFileSearchIndexInfoChangedNotification object:aDocument];
        [nc addObserver:self selector:handler name:BDSKDocAddItemNotification object:aDocument];
        [nc addObserver:self selector:handler name:BDSKDocDelItemNotification object:aDocument];
        
        flags.finishedInitialIndexing = 0;
        flags.shouldKeepRunning = 1;
        
        // maintain dictionaries mapping URL -> identifierURL, since SKIndex properties are slow; this should be accessed with the rwlock
        identifierURLs = [[BDSKMultiValueDictionary alloc] init];
		pthread_rwlock_init(&rwlock, NULL);
        
        progressValue = 0.0;
        
        setupLock = [[NSConditionLock alloc] initWithCondition:INDEX_STARTUP];
        
        // this will create a retain cycle, so we'll have to tickle the thread to exit properly in -cancel
        [NSThread detachNewThreadSelector:@selector(runIndexThreadWithInfo:) toTarget:self withObject:info];
        
        // block until the NSMachPort is set up to receive messages
        [setupLock lockWhenCondition:INDEX_STARTUP_COMPLETE];
        [setupLock unlockWithCondition:INDEX_THREAD_WORKING];

    }
    
    return self;
}

- (void)dealloc
{
    pthread_rwlock_wrlock(&rwlock);
	[identifierURLs release];
    identifierURLs = nil;
    pthread_rwlock_unlock(&rwlock);
    pthread_rwlock_destroy(&rwlock);
    [notificationPort release];
    [notificationQueue release];
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

- (BOOL)finishedInitialIndexing
{
    OSMemoryBarrier();
    return flags.finishedInitialIndexing == 1;
}

- (void)setDelegate:(id <BDSKFileSearchIndexDelegate>)anObject
{
    if(anObject)
        NSAssert1([(id)anObject conformsToProtocol:@protocol(BDSKFileSearchIndexDelegate)], @"%@ does not conform to BDSKFileSearchIndexDelegate protocol", [anObject class]);

    delegate = anObject;
}

- (NSURL *)identifierURLForURL:(NSURL *)theURL
{
    pthread_rwlock_rdlock(&rwlock);
    NSURL *identifierURL = [[[identifierURLs anyObjectForKey:theURL] retain] autorelease];
    pthread_rwlock_unlock(&rwlock);
    return identifierURL;
}

- (NSSet *)allIdentifierURLsForURL:(NSURL *)theURL
{
    pthread_rwlock_rdlock(&rwlock);
    NSSet *set = [[[identifierURLs allObjectsForKey:theURL] copy] autorelease];
    pthread_rwlock_unlock(&rwlock);
    return set;
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


@implementation BDSKFileSearchIndex (Private)

static inline NSData *sha1SignatureForURL(NSURL *aURL) {
    NSData *sha1Signature = [NSData copySha1SignatureForFile:[aURL path]];
    return sha1Signature ? [sha1Signature autorelease] : [NSData data];
}

+ (NSString *)indexCacheFolder
{
    static NSString *cacheFolder = nil;
    if (nil == cacheFolder) {
        cacheFolder = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
        cacheFolder = [cacheFolder stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
        if (cacheFolder && [[NSFileManager defaultManager] fileExistsAtPath:cacheFolder] == NO)
            [[NSFileManager defaultManager] createDirectoryAtPath:cacheFolder attributes:nil];
        cacheFolder = [cacheFolder stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-v%@", NSStringFromClass(self), CACHE_VERSION]];
        if (cacheFolder && [[NSFileManager defaultManager] fileExistsAtPath:cacheFolder] == NO)
            [[NSFileManager defaultManager] createDirectoryAtPath:cacheFolder attributes:nil];
        cacheFolder = [cacheFolder copy];
    }
    return cacheFolder;
}

static inline BOOL isIndexCacheForDocumentURL(NSString *path, NSURL *documentURL) {
    BOOL isIndexCache = NO;
    NSData *data = [NSData dataWithContentsOfMappedFile:path];
    if (data) {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        isIndexCache = [[unarchiver decodeObjectForKey:@"documentURL"] isEqual:documentURL];
        [unarchiver finishDecoding];
        [unarchiver release];
    }
    return isIndexCache;
}

// Read each cache file and see which one has a matching documentURL.  If this gets too slow, we could save a plist mapping URL -> UUID and use that instead.
+ (NSString *)indexCachePathForDocumentURL:(NSURL *)documentURL
{
    NSParameterAssert(nil != documentURL);
    NSString *indexCachePath = nil;
    NSString *indexCacheFolder = [self indexCacheFolder];
    NSString *defaultPath = [[[[documentURL path] lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"bdskindex"];
    
    defaultPath = [indexCacheFolder stringByAppendingPathComponent:defaultPath];
    if (isIndexCacheForDocumentURL(defaultPath, documentURL)) {
        indexCachePath = defaultPath;
    } else {
        UKDirectoryEnumerator *indexEnum = [UKDirectoryEnumerator enumeratorWithPath:indexCacheFolder];
        NSString *path;
        
        while ((path = [indexEnum nextObjectFullPath]) && nil == indexCachePath) {
            if ([[path pathExtension] isEqualToString:@"bdskindex"] && 
                [path isEqualToString:defaultPath] == NO && 
                isIndexCacheForDocumentURL(path, documentURL))
                indexCachePath = path;
        }
    }
    return indexCachePath;
}

static void addItemFunction(const void *value, void *context) {
    BDSKMultiValueDictionary *dict = (BDSKMultiValueDictionary *)context;
    NSDictionary *item = (NSDictionary *)value;
    NSURL *identifierURL = [item objectForKey:@"identifierURL"];
    NSSet *keys = [[NSSet alloc] initWithArray:[item objectForKey:@"urls"]];
    [dict addObject:identifierURL forKeys:keys];
    [keys release];
}

- (void)buildIndexWithInfo:(NSDictionary *)info
{
    NSAssert2([[NSThread currentThread] isEqual:notificationThread], @"-[%@ %@] must be called from the worker thread!", [self class], NSStringFromSelector(_cmd));
    
    SKIndexRef tmpIndex = NULL;
    NSURL *documentURL = [info objectForKey:@"documentURL"];
    NSString *indexCachePath = documentURL ? [[self class] indexCachePathForDocumentURL:documentURL] : nil;
    NSArray *items = [info objectForKey:@"items"];
    
    double totalObjectCount = [items count];
    double numberIndexed = 0;
    
    OBPRECONDITION(items);
    
    [items retain];
    
    if (indexCachePath) {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:[NSData dataWithContentsOfFile:indexCachePath]];
        indexData = (CFMutableDataRef)[[unarchiver decodeObjectForKey:@"indexData"] mutableCopy];
        if (indexData != NULL) {
            tmpIndex = SKIndexOpenWithMutableData(indexData, NULL);
            if (tmpIndex) {
                [signatures setDictionary:[unarchiver decodeObjectForKey:@"signatures"]];
            } else {
                CFRelease(indexData);
                indexData = NULL;
            }
        }
        [unarchiver finishDecoding];
        [unarchiver release];
    }
    
    if (tmpIndex == NULL) {
        indexData = CFDataCreateMutable(CFAllocatorGetDefault(), 0);
        tmpIndex = SKIndexCreateWithMutableData(indexData, NULL, kSKIndexInverted, NULL);
    }
    
    index = tmpIndex;
    
    if ([signatures count]) {
        // cached index, update identifierURLs and remove unlinked or invalid indexed URLs
        
        // set the identifierURLs map, so we can build search results immediately; no problem if it contains URLs that were not indexed or are replaced, we know these URLs should be added eventually
        OSMemoryBarrier();
        if (flags.shouldKeepRunning == 1) {
            pthread_rwlock_wrlock(&rwlock);
            CFArrayApplyFunction((CFArrayRef)items, CFRangeMake(0, [items count]), addItemFunction, (void *)identifierURLs);
            pthread_rwlock_unlock(&rwlock);
        }
        
        [[OFMessageQueue mainQueue] queueSelectorOnce:@selector(searchIndexDidUpdate) forObject:self];
        
        NSMutableSet *URLsToRemove = [[NSMutableSet alloc] initWithArray:[signatures allKeys]];
        NSMutableArray *itemsToAdd = [[NSMutableArray alloc] init];
        NSEnumerator *itemEnum = [items objectEnumerator];
        id anItem = nil;
        
        // find URLs in the database that needs to be indexed, and URLs that were indexeed but are not in the database anymore
        OSMemoryBarrier();
        while(flags.shouldKeepRunning == 1 && (anItem = [itemEnum nextObject])) {
            
            NSAutoreleasePool *pool = [NSAutoreleasePool new];
            
            NSURL *identifierURL = [anItem objectForKey:@"identifierURL"];
            NSEnumerator *urlEnum = [[anItem objectForKey:@"urls"] objectEnumerator];
            NSURL *url;
            NSMutableArray *missingURLs = nil;
            NSData *signature;
            
            while (url = [urlEnum nextObject]) {
                signature = [signatures objectForKey:url];
                if (signature && [signature isEqual:sha1SignatureForURL(url)]) {
                    [URLsToRemove removeObject:url];
                } else {
                    if (missingURLs == nil)
                        missingURLs = [NSMutableArray array];
                    [missingURLs addObject:url];
                }
            }
            
            if ([missingURLs count]) {
                [itemsToAdd addObject:[NSDictionary dictionaryWithObjectsAndKeys:identifierURL, @"identifierURL", missingURLs, @"urls", nil]];
            } else {
                numberIndexed++;
                @synchronized(self) {
                    progressValue = (numberIndexed / totalObjectCount) * 100;
                }
                
                [[OFMessageQueue mainQueue] queueSelectorOnce:@selector(searchIndexDidUpdate) forObject:self];
            }
            
            [pool release];
            OSMemoryBarrier();
        }
            
        // remove URLs we could not find in the database
        OSMemoryBarrier();
        if (flags.shouldKeepRunning == 1 && [URLsToRemove count]) {
            NSEnumerator *urlEnum = [URLsToRemove objectEnumerator];
            NSURL *url;
            while (url = [urlEnum nextObject])
                [self removeFileURL:url];
        }
        [URLsToRemove release];
        
        [[OFMessageQueue mainQueue] queueSelectorOnce:@selector(searchIndexDidUpdate) forObject:self];
        
        [items release];
        items = itemsToAdd;
        
    }
    
    // add items that were not yet indexed
    OSMemoryBarrier();
    if (flags.shouldKeepRunning == 1 && [items count]) {
        [self indexFilesForItems:items numberPreviouslyIndexed:numberIndexed totalCount:totalObjectCount];
    }
    
    [items release];

    OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.finishedInitialIndexing);
    OSMemoryBarrier();
    if (flags.shouldKeepRunning == 1)
        [self performSelectorOnMainThread:@selector(searchIndexDidFinish) withObject:nil waitUntilDone:NO];
}

- (void)indexFileURL:(NSURL *)aURL{
    NSData *signature = sha1SignatureForURL(aURL);
    
    if ([[signatures objectForKey:aURL] isEqual:signature] == NO) {
        // either the file was not indexed, or it has changed
        
        SKDocumentRef skDocument = SKDocumentCreateWithURL((CFURLRef)aURL);
        
        OBPOSTCONDITION(skDocument);
        
        if (skDocument != NULL) {
            
            OBASSERT(signature);
            
            if (signature == nil)
                signature = [NSData data];
            [signatures setObject:signature forKey:aURL];
            
            SKIndexAddDocument(index, skDocument, NULL, TRUE);
            CFRelease(skDocument);
        }
    }
}

- (void)removeFileURL:(NSURL *)aURL{
    SKDocumentRef skDocument = SKDocumentCreateWithURL((CFURLRef)aURL);
    
    OBPOSTCONDITION(skDocument);
    
    if (skDocument != NULL) {
        [signatures removeObjectForKey:aURL];
        
        SKIndexRemoveDocument(index, skDocument);
        CFRelease(skDocument);
    }
}

- (void)indexFilesForItems:(NSArray *)items numberPreviouslyIndexed:(double)numberIndexed totalCount:(double)totalObjectCount
{
    NSAssert2([[NSThread currentThread] isEqual:notificationThread], @"-[%@ %@] must be called from the worker thread!", [self class], NSStringFromSelector(_cmd));
    
    NSEnumerator *enumerator = [items objectEnumerator];
    id anObject = nil;
        
    // Use a local pool since initial indexing can use a fair amount of memory, and it's not released until the thread's run loop starts
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
        
    OSMemoryBarrier();
    while(flags.shouldKeepRunning == 1 && (anObject = [enumerator nextObject])) {
        [self indexFileURLs:[NSSet setWithArray:[anObject objectForKey:@"urls"]] forIdentifierURL:[anObject objectForKey:@"identifierURL"]];
        numberIndexed++;
        @synchronized(self) {
            progressValue = (numberIndexed / totalObjectCount) * 100;
        }
        
        [pool release];
        pool = [NSAutoreleasePool new];
        
        [[OFMessageQueue mainQueue] queueSelectorOnce:@selector(searchIndexDidUpdate) forObject:self];
        OSMemoryBarrier();
    }
        
    // final update to catch any leftovers
    
    // it's possible that we've been told to stop, and the delegate is garbage; in that case, don't message it
    [self searchIndexFinishedLoop];
    
    [pool release];
}

- (void)indexFileURLs:(NSSet *)urlsToAdd forIdentifierURL:(NSURL *)identifierURL
{
    OBASSERT([[NSThread currentThread] isEqual:notificationThread]);
    
    OBASSERT(identifierURL);
    
    NSEnumerator *urlEnumerator = [urlsToAdd objectEnumerator];
    NSURL *url = nil;
    
    while(url = [urlEnumerator nextObject]){
        // SKIndexSetProperties is more generally useful, but is really slow when creating the index
        // SKIndexRenameDocument changes the URL, so it's not useful
        
        pthread_rwlock_wrlock(&rwlock);
        [identifierURLs addObject:identifierURL forKey:url];
        pthread_rwlock_unlock(&rwlock);
        
        [self indexFileURL:url];
    }
    
    // the caller is responsible for updating the delegate, so we can throttle initial indexing
}

- (void)removeFileURLs:(NSSet *)urlsToRemove forIdentifierURL:(NSURL *)identifierURL
{
    OBASSERT([[NSThread currentThread] isEqual:notificationThread]);

    OBASSERT(identifierURL);
        
    NSEnumerator *urlEnum = nil;
    NSURL *url = nil;
    BOOL shouldBeRemoved;
    
    urlEnum = [urlsToRemove objectEnumerator];
    
    // loop through the array of URLs, create a new SKDocumentRef, and try to remove it
    while (url = [urlEnum nextObject]) {
        
        pthread_rwlock_wrlock(&rwlock);
        [identifierURLs removeObject:identifierURL forKey:url];
        shouldBeRemoved = (0 == [[identifierURLs allObjectsForKey:url] count]);
        pthread_rwlock_unlock(&rwlock);
        
        if (shouldBeRemoved)
            [self removeFileURL:url];
	}
    
    // the caller is responsible for updating the delegate, so we can throttle initial indexing
}

- (void)reindexFileURLsIfNeeded:(NSSet *)urlsToReindex forIdentifierURL:(NSURL *)identifierURL
{
    OBASSERT([[NSThread currentThread] isEqual:notificationThread]);
    
    OBASSERT(identifierURL);
    
    NSEnumerator *urlEnumerator = [urlsToReindex objectEnumerator];
    NSURL *url = nil;
        
    while(url = [urlEnumerator nextObject])
        [self indexFileURL:url];
    
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
            indexCachePath = [[[[documentURL path] lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"bdskindex"];
            indexCachePath = [[NSFileManager defaultManager] uniqueFilePathWithName:indexCachePath atPath:[[self class] indexCacheFolder]];
        }
        
        NSMutableData *data = [NSMutableData data];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
        [archiver encodeObject:documentURL forKey:@"documentURL"];
        [archiver encodeObject:(NSMutableData *)indexData forKey:@"indexData"];
        [archiver encodeObject:signatures forKey:@"signatures"];
        [archiver finishEncoding];
        [archiver release];
        [data writeToFile:indexCachePath atomically:YES];
    }
}

- (void)runIndexThreadWithInfo:(NSDictionary *)info
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
        [self buildIndexWithInfo:info];
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

- (void)searchIndexDidUpdate
{
    OBASSERT([NSThread inMainThread]);
    OSMemoryBarrier();
    if (flags.shouldKeepRunning == 1)
        [delegate searchIndexDidUpdate:self];
}

- (void)searchIndexDidFinish
{
    OBASSERT([NSThread inMainThread]);
    OSMemoryBarrier();
    if (flags.shouldKeepRunning == 1)
        [delegate searchIndexDidFinish:self];
}

- (void)searchIndexFinishedLoop
{
    if ([notificationQueue count]) {
        [[OFMessageQueue mainQueue] queueSelectorOnce:@selector(searchIndexDidUpdate) forObject:self];
    } else {
        [[OFMessageQueue mainQueue] removeSelector:@selector(searchIndexDidUpdate) forObject:self];
        [[OFMessageQueue mainQueue] queueSelectorOnce:@selector(searchIndexDidFinish) forObject:self];
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
        
    NSURL *identifierURL = nil;
    NSSet *urlsToRemove;
    	
    while (anItem = [itemEnumerator nextObject]) {
        identifierURL = [anItem valueForKey:@"identifierURL"];
        
        pthread_rwlock_rdlock(&rwlock);
        urlsToRemove = [[[identifierURLs allKeysForObject:identifierURL] copy] autorelease];
        pthread_rwlock_unlock(&rwlock);
       
        [self removeFileURLs:urlsToRemove forIdentifierURL:identifierURL];
	}
	
    [self searchIndexFinishedLoop];
}

- (void)handleSearchIndexInfoChangedNotification:(NSNotification *)note
{
    OBASSERT([[NSThread currentThread] isEqual:notificationThread]);
    
    NSDictionary *item = [note userInfo];
    NSURL *identifierURL = [item objectForKey:@"identifierURL"];
    
    NSSet *oldURLs;
    NSSet *newURLs;
    NSMutableSet *removedURLs;
    NSMutableSet *addedURLs;
    NSMutableSet *sameURLs;
    
    pthread_rwlock_rdlock(&rwlock);
    oldURLs = [[identifierURLs allKeysForObject:identifierURL] copy];
    pthread_rwlock_unlock(&rwlock);
    newURLs = [[NSSet alloc] initWithArray:[item valueForKey:@"urls"]];
    
    removedURLs = [oldURLs mutableCopy];
    [removedURLs minusSet:newURLs];
    
    addedURLs = [newURLs mutableCopy];
    [addedURLs minusSet:oldURLs];
    
    sameURLs = [newURLs mutableCopy];
    [sameURLs intersectSet:oldURLs];
    
    [oldURLs release];
    [newURLs release];
        
    if ([removedURLs count])
        [self removeFileURLs:removedURLs forIdentifierURL:identifierURL];
    
    if ([addedURLs count])
        [self indexFileURLs:addedURLs forIdentifierURL:identifierURL];
    
    if ([sameURLs count])
        [self reindexFileURLsIfNeeded:sameURLs forIdentifierURL:identifierURL];
        
    [removedURLs release];
    [addedURLs release];
    [sameURLs release];
    
    [self searchIndexFinishedLoop];
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


@implementation OFMessageQueue (BDSKExtensions)

- (void)removeQueueEntry:(OFInvocation *)aQueueEntry;
{
    BOOL alreadyContainsObject;
    unsigned int idx;
    
    [queueLock lock];
    while ((idx = [queue indexOfObject:aQueueEntry]) != NSNotFound)
        [queue removeObjectAtIndex:idx];
    [queueLock unlock];
}

- (void)removeSelector:(SEL)aSelector forObject:(id <NSObject>)anObject;
{
    OFInvocation *queueEntry;

    if (!anObject)
        return;
    
    queueEntry = [[OFInvocation alloc] initForObject:anObject selector:aSelector];
    [self removeQueueEntry:queueEntry];
    [queueEntry release];
}

@end

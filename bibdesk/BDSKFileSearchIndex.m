//
//  BDSKFileSearchIndex.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/11/05.
/*
 This software is Copyright (c) 2005-2015
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
#import "BDSKOwnerProtocol.h"
#import "BibItem.h"
#import <libkern/OSAtomic.h>
#import "NSFileManager_BDSKExtensions.h"
#import "NSData_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "BDSKReadWriteLock.h"

#define BDSKDisableFileSearchIndexCacheKey @"BDSKDisableFileSearchIndexCacheKey"

@interface BDSKFileSearchIndex (Private)

+ (NSURL *)indexCacheFolderURL;
- (void)buildIndexWithItems:(NSArray *)items forDocumentAtURL:(NSURL *)documentURL;
- (void)processInfoChangedNotification:(NSNotification *)note;
- (void)processAddItemNotification:(NSNotification *)note;
- (void)processDelItemNotification:(NSNotification *)note;
- (void)writeIndexToDiskForDocumentURL:(NSURL *)documentURL;

@end

#pragma mark -

@implementation BDSKFileSearchIndex

// increment if incompatible changes are introduced
#define CACHE_VERSION @"2"

#pragma mark API

- (id)initForOwner:(id <BDSKOwner>)owner
{
    BDSKASSERT([NSThread isMainThread]);

    self = [super init];
        
    if(nil != self){
        // maintain dictionaries mapping URL -> signature, so we can check if a URL is outdated
        signatures = [[NSMutableDictionary alloc] initWithCapacity:128];
        
        skIndex = NULL;
        
        // new document won't have a URL, so we'll have to wait for the controller to set it
        NSURL *documentURL = [owner fileURL];
        NSArray *items = [[owner publications] valueForKey:@"searchIndexInfo"];
        
        // setting up the cache folder is not thread safe, so make sure it's done on the main thread
        [[self class] indexCacheFolderURL];
        
        delegate = nil;
        lastUpdateTime = CFAbsoluteTimeGetCurrent();
        
        flags.shouldKeepRunning = 1;
        flags.updateScheduled = 0;
        flags.status = BDSKSearchIndexStatusStarting;
        
        // maintain dictionaries mapping URL -> identifierURL, since SKIndex properties are slow; this should be accessed with the rwlock
        URLsForIdentifierURLs = [[NSMapTable alloc] initWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableStrongMemory capacity:0];
        identifierURLsForURLs = [[NSMapTable alloc] initWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableStrongMemory capacity:0];
		rwLock = [[BDSKReadWriteLock alloc] init];
        
        progressValue = 0.0;
        
        queue = dispatch_queue_create("edu.ucsd.cs.mmccrack.bibdesk.queue.BDSKFileSearchIndex", NULL);
        lockQueue = dispatch_queue_create("edu.ucsd.cs.mmccrack.bibdesk.lockQueue.BDSKFileSearchIndex", NULL);
        
        dispatch_async(queue, ^{
            [self buildIndexWithItems:items forDocumentAtURL:documentURL];
        });
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(processInfoChangedNotification:) name:BDSKFileSearchIndexInfoChangedNotification object:owner];
        [nc addObserver:self selector:@selector(processAddItemNotification:) name:BDSKDocAddItemNotification object:owner];
        [nc addObserver:self selector:@selector(processDelItemNotification:) name:BDSKDocDelItemNotification object:owner];

    }
    
    return self;
}

- (void)dealloc
{
    BDSKDISPATCHDESTROY(queue);
    BDSKDISPATCHDESTROY(lockQueue);
    [rwLock lockForWriting];
	BDSKDESTROY(URLsForIdentifierURLs);
	BDSKDESTROY(identifierURLsForURLs);
    [rwLock unlock];
    BDSKDESTROY(rwLock);
    BDSKDESTROY(signatures);
    BDSKCFDESTROY(skIndex);
    BDSKCFDESTROY(indexData);
    [super dealloc];
}

- (BOOL)shouldKeepRunning {
    OSMemoryBarrier();
    return flags.shouldKeepRunning == 1;
}

// cancel is always sent from the main thread
- (void)cancelForDocumentURL:(NSURL *)documentURL
{
    NSParameterAssert([NSThread isMainThread]);
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.shouldKeepRunning);
    
    // write index to file as last block on the queue and wait for it to finish
    dispatch_sync(queue, ^{
        [self writeIndexToDiskForDocumentURL:documentURL];
    });
}

- (SKIndexRef)index
{
    return skIndex;
}

- (NSUInteger)status
{
    OSMemoryBarrier();
    return flags.status;
}

- (id)delegate
{
    return delegate;
}

- (void)setDelegate:(id <BDSKFileSearchIndexDelegate>)anObject
{
    delegate = anObject;
}

- (NSSet *)identifierURLsForURL:(NSURL *)theURL
{
    [rwLock lockForReading];
    NSSet *set = [[[identifierURLsForURLs objectForKey:theURL] copy] autorelease];
    [rwLock unlock];
    return set;
}

- (double)progressValue
{
    __block double theValue;
    dispatch_sync(lockQueue, ^{
        theValue = progressValue;
    });
    return theValue;
}

#pragma mark Private methods

#pragma mark Caching

// this can return any object conforming to NSCoding
static inline id signatureForURL(NSURL *aURL) {
    // Use the SHA1 signature if we can get it
    id signature = [NSData sha1SignatureForFile:[aURL path]];
    if (signature == nil) {
        // this could happen for packages, use a timestamp instead
        NSDate *modDate = nil;
        [aURL getResourceValue:&modDate forKey:NSURLContentModificationDateKey error:NULL];
        signature = modDate;
    }
    return signature ?: [NSData data];
}

+ (NSURL *)indexCacheFolderURL
{
    static NSURL *cacheFolderURL = nil;
    if (nil == cacheFolderURL) {
        NSFileManager *fm = [NSFileManager defaultManager];
        cacheFolderURL = [fm URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
        cacheFolderURL = [cacheFolderURL URLByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
        cacheFolderURL = [cacheFolderURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@-v%@", NSStringFromClass(self), CACHE_VERSION]];
        if (cacheFolderURL && [fm fileExistsAtPath:[cacheFolderURL path]] == NO)
            [fm createDirectoryAtPath:[cacheFolderURL path] withIntermediateDirectories:YES attributes:nil error:NULL];
        cacheFolderURL = [cacheFolderURL copy];
    }
    return cacheFolderURL;
}

static inline BOOL isIndexCacheForDocumentURL(NSURL *aURL, NSURL *documentURL) {
    BOOL isIndexCache = NO;
    NSData *data = [NSData dataWithContentsOfURL:aURL options:NSDataReadingMapped error:NULL];
    if (data) {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        isIndexCache = [[unarchiver decodeObjectForKey:@"documentURL"] isEqual:documentURL];
        [unarchiver finishDecoding];
        [unarchiver release];
    }
    return isIndexCache;
}

// Read each cache file and see which one has a matching documentURL.  If this gets too slow, we could save a plist mapping URL -> UUID and use that instead.
+ (NSURL *)indexCacheURLForDocumentURL:(NSURL *)documentURL
{
    NSParameterAssert(nil != documentURL);
    NSURL *indexCacheURL = nil;
    NSURL *indexCacheFolderURL = [self indexCacheFolderURL];
    NSString *defaultPathName = [[[[documentURL path] lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"bdskindex"];
    NSURL *defaultURL = [indexCacheFolderURL URLByAppendingPathComponent:defaultPathName];
    
    if (isIndexCacheForDocumentURL(defaultURL, documentURL)) {
        indexCacheURL = defaultURL;
    } else {
        NSFileManager *fm = [[[NSFileManager alloc] init] autorelease];
        NSArray *folderContents = [fm contentsOfDirectoryAtURL:indexCacheFolderURL includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsSubdirectoryDescendants | NSDirectoryEnumerationSkipsSubdirectoryDescendants error:NULL];
        
        for (NSURL *url in folderContents) {
            if ([[url pathExtension] isEqualToString:@"bdskindex"] && 
                [url isEqual:defaultURL] == NO && 
                isIndexCacheForDocumentURL(url, documentURL)) {
                indexCacheURL = url;
                break;
            }
        }
    }
    return indexCacheURL;
}

- (void)writeIndexToDiskForDocumentURL:(NSURL *)documentURL
{
    NSParameterAssert([NSThread isMainThread]);
    
    // @@ temporary for testing
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKDisableFileSearchIndexCacheKey])
        return;
    
    if (skIndex && documentURL) {
        // flush all pending updates and compact the index as needed before writing
        SKIndexCompact(skIndex);
        
        NSURL *indexCacheURL = [[self class] indexCacheURLForDocumentURL:documentURL];
        if (nil == indexCacheURL) {
            NSString *indexCacheName = [[[documentURL lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"bdskindex"];
            indexCacheURL = [NSURL fileURLWithPath:[[NSFileManager defaultManager] uniqueFilePathWithName:indexCacheName atPath:[[[self class] indexCacheFolderURL] path]]];
        }
        
        NSMutableData *data = [NSMutableData data];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
        [archiver encodeObject:documentURL forKey:@"documentURL"];
        [archiver encodeObject:(NSMutableData *)indexData forKey:@"indexData"];
        [archiver encodeObject:signatures forKey:@"signatures"];
        [archiver finishEncoding];
        [archiver release];
        [data writeToURL:indexCacheURL atomically:YES];
    }
}

#pragma mark Update callbacks

- (void)notifyDelegate
{
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.updateScheduled);
    [delegate searchIndexDidUpdate:self];
}

- (void)searchIndexDidUpdate
{
    BDSKASSERT([NSThread isMainThread]);
    // Make sure we send frequently enough to update a progress bar, but not too frequently to avoid beachball on single-core systems; too many search updates slow down indexing due to repeated flushes. 
    OSMemoryBarrier();
    if (0 == flags.updateScheduled) {
        const double updateDelay = flags.status == BDSKSearchIndexStatusRunning ? 1.0 : 0.1;
        [self performSelector:@selector(notifyDelegate) withObject:nil afterDelay:updateDelay];
        OSAtomicCompareAndSwap32Barrier(0, 1, &flags.updateScheduled);
    }
}

- (void)searchIndexDidUpdateStatus
{
    BDSKASSERT([NSThread isMainThread]);
    if ([self shouldKeepRunning])
        [delegate searchIndexDidUpdateStatus:self];
}

- (void)didUpdate
{
    OSMemoryBarrier();
    if (0 == flags.updateScheduled) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self searchIndexDidUpdate];
        });
    }
}

- (void)updateStatus:(NSUInteger)status
{
    OSAtomicCompareAndSwap32Barrier(flags.status, status, &flags.status);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self searchIndexDidUpdateStatus];
    });
}

#pragma mark Indexing

- (void)addURL:(NSURL *)objectURL forURL:(NSURL *)keyURL inMapTable:(NSMapTable *)mapTable {
    NSMutableSet *set = (NSMutableSet *)[mapTable objectForKey:keyURL];
    if (set) {
        [set addObject:objectURL];
    } else {
        set = [[NSMutableSet alloc] initWithObjects:objectURL, nil];
        [mapTable setObject:set forKey:keyURL];
        [set release];
    }
}

- (void)removeURL:(NSURL *)objectURL forURL:(NSURL *)keyURL inMapTable:(NSMapTable *)mapTable {
    NSMutableSet *set = (NSMutableSet *)[mapTable objectForKey:keyURL];
    if (set) {
        [set removeObject:objectURL];
        if ([set count] == 0)
            [mapTable removeObjectForKey:keyURL];
    }
}

- (void)indexFileURL:(NSURL *)aURL{
    id signature = signatureForURL(aURL);
    
    if ([[signatures objectForKey:aURL] isEqual:signature] == NO) {
        // either the file was not indexed, or it has changed
        
        SKDocumentRef skDocument = SKDocumentCreateWithURL((CFURLRef)aURL);
        
        BDSKPOSTCONDITION(skDocument);
        
        if (skDocument != NULL) {
            
            BDSKASSERT(signature);
            [signatures setObject:signature forKey:aURL];
            
            SKIndexAddDocument(skIndex, skDocument, NULL, TRUE);
            CFRelease(skDocument);
        }
    }
}

- (void)removeFileURL:(NSURL *)aURL{
    SKDocumentRef skDocument = SKDocumentCreateWithURL((CFURLRef)aURL);
    
    BDSKPOSTCONDITION(skDocument);
    
    if (skDocument != NULL) {
        [signatures removeObjectForKey:aURL];
        
        SKIndexRemoveDocument(skIndex, skDocument);
        CFRelease(skDocument);
    }
}

- (void)indexFileURLs:(id<NSFastEnumeration>)urlsToAdd forIdentifierURL:(NSURL *)identifierURL
{
    BDSKASSERT(identifierURL);
    
    // SKIndexSetProperties is more generally useful, but is really slow when creating the index
    // SKIndexRenameDocument changes the URL, so it's not useful
    
    [rwLock lockForWriting];
    for (NSURL *url in urlsToAdd) {
        [self addURL:identifierURL forURL:url inMapTable:identifierURLsForURLs];
        [self addURL:url forURL:identifierURL inMapTable:URLsForIdentifierURLs];
    }
    [rwLock unlock];
    
    for (NSURL *url in urlsToAdd)
        [self indexFileURL:url];
    
    // the caller is responsible for updating the delegate, so we can throttle initial indexing
}

- (void)removeFileURLs:(id<NSFastEnumeration>)urlsToRemove forIdentifierURL:(NSURL *)identifierURL
{
    BDSKASSERT(identifierURL);
        
    BOOL shouldBeRemoved;
    
    // loop through the array of URLs, create a new SKDocumentRef, and try to remove it
    for (NSURL *url in urlsToRemove) {
        
        [rwLock lockForWriting];
        [self removeURL:identifierURL forURL:url inMapTable:identifierURLsForURLs];
        [self removeURL:url forURL:identifierURL inMapTable:URLsForIdentifierURLs];
        shouldBeRemoved = (nil == [identifierURLsForURLs objectForKey:url]);
        [rwLock unlock];
        
        if (shouldBeRemoved)
            [self removeFileURL:url];
	}
    
    // the caller is responsible for updating the delegate, so we can throttle initial indexing
}

- (void)indexFilesForItems:(NSArray *)items numberPreviouslyIndexed:(double)numberIndexed
{
    // Use a local pool since initial indexing can use a fair amount of memory, and it's not released until the thread's run loop starts
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    double totalObjectCount = numberIndexed + [items count];
    
    for (id anObject in items) {
        if ([self shouldKeepRunning] == NO) break;
        [self indexFileURLs:[anObject objectForKey:@"urls"] forIdentifierURL:[anObject objectForKey:@"identifierURL"]];
        numberIndexed++;
        dispatch_async(lockQueue, ^{
            progressValue = (numberIndexed / totalObjectCount) * 100;
        });
        
        [pool release];
        pool = [NSAutoreleasePool new];
        
        [self didUpdate];
    }
    
    // caller queues a final update
    
    [pool release];
}

#pragma mark Change notification handling

- (void)processAddItemNotification:(NSNotification *)note
{
    NSArray *searchIndexInfo = [[note userInfo] valueForKeyPath:@"publications.searchIndexInfo"];
    
    dispatch_async(queue, ^{
        // this will update the delegate when all is complete
        if ([self shouldKeepRunning])
            [self indexFilesForItems:searchIndexInfo numberPreviouslyIndexed:0];
    });
}

- (void)processDelItemNotification:(NSNotification *)note
{
    NSArray *searchIndexInfo = [[note userInfo] valueForKeyPath:@"publications.searchIndexInfo"];

    dispatch_async(queue, ^{
        if ([self shouldKeepRunning]) {
            for (id anItem in searchIndexInfo) {
                NSURL *identifierURL = [anItem valueForKey:@"identifierURL"];
                
                [rwLock lockForReading];
                NSSet *urlsToRemove = [[URLsForIdentifierURLs objectForKey:identifierURL] copy];
                [rwLock unlock];
               
                [self removeFileURLs:urlsToRemove forIdentifierURL:identifierURL];
                
                [urlsToRemove release];
            }
            
            [self didUpdate];
        }
    });
}

- (void)processInfoChangedNotification:(NSNotification *)note
{
    NSArray *searchIndexInfo = [[note userInfo] valueForKeyPath:@"publications.searchIndexInfo"];
    
    dispatch_async(queue, ^{
        if ([self shouldKeepRunning]) {
            NSDictionary *item = [searchIndexInfo lastObject];
            NSURL *identifierURL = [item objectForKey:@"identifierURL"];
            
            NSSet *newURLs = [[NSSet alloc] initWithArray:[item valueForKey:@"urls"]];
            NSMutableSet *removedURLs;
            
            [rwLock lockForReading];
            removedURLs = [[URLsForIdentifierURLs objectForKey:identifierURL] mutableCopy];
            [rwLock unlock];
            [removedURLs minusSet:newURLs];
            
            if ([removedURLs count])
                [self removeFileURLs:removedURLs forIdentifierURL:identifierURL];
            
            if ([newURLs count])
                [self indexFileURLs:newURLs forIdentifierURL:identifierURL];
                
            [removedURLs release];
            [newURLs release];
            
            [self didUpdate];
        }
    });
}    

#pragma mark Index initialization

- (void)buildIndexWithItems:(NSArray *)items forDocumentAtURL:(NSURL *)documentURL
{
    SKIndexRef tmpIndex = NULL;
    NSURL *indexCacheURL = documentURL ? [[self class] indexCacheURLForDocumentURL:documentURL] : nil;
    
    double numberIndexed = 0;
    
    BDSKPRECONDITION(items);
    
    [items retain];
    
    if (indexCacheURL) {
        [self updateStatus:BDSKSearchIndexStatusVerifying];
        
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:[NSData dataWithContentsOfURL:indexCacheURL]];
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
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], (id)kSKMaximumTerms, [NSNumber numberWithInt:3], (id)kSKMinTermLength, nil];
        tmpIndex = SKIndexCreateWithMutableData(indexData, NULL, kSKIndexInverted, (CFDictionaryRef)options);
    }
    
    skIndex = tmpIndex;
    
    if ([signatures count]) {
        // cached index, update identifierURLs and remove unlinked or invalid indexed URLs
        
        // set the identifierURLs map, so we can build search results immediately; no problem if it contains URLs that were not indexed or are replaced, we know these URLs should be added eventually
        if ([self shouldKeepRunning]) {
            [rwLock lockForWriting];
            for (NSDictionary *item in items) {
                NSURL *identifierURL = [item objectForKey:@"identifierURL"];
                for (NSURL *url in [item objectForKey:@"urls"]) {
                    [self addURL:identifierURL forURL:url inMapTable:identifierURLsForURLs];
                    [self addURL:url forURL:identifierURL inMapTable:URLsForIdentifierURLs];
                }
            }
            [rwLock unlock];
        }
        
        [self didUpdate];
        
        NSMutableSet *URLsToRemove = [[NSMutableSet alloc] initWithArray:[signatures allKeys]];
        NSMutableArray *itemsToAdd = [[NSMutableArray alloc] init];
        double totalObjectCount = [items count];
        
        // find URLs in the database that needs to be indexed, and URLs that were indexeed but are not in the database anymore
        for (id anItem in items) {
            if ([self shouldKeepRunning] == NO) break;
            
            NSAutoreleasePool *pool = [NSAutoreleasePool new];
            
            NSURL *identifierURL = [anItem objectForKey:@"identifierURL"];
            NSMutableArray *missingURLs = nil;
            id signature;
            
            for (NSURL *url in [anItem objectForKey:@"urls"]) {
                signature = [signatures objectForKey:url];
                if (signature)
                    [URLsToRemove removeObject:url];
                if (signature == nil || [signature isEqual:signatureForURL(url)] == NO) {
                    if (missingURLs == nil)
                        missingURLs = [NSMutableArray array];
                    [missingURLs addObject:url];
                }
            }
            
            if ([missingURLs count]) {
                [itemsToAdd addObject:[NSDictionary dictionaryWithObjectsAndKeys:identifierURL, @"identifierURL", missingURLs, @"urls", nil]];
            } else {
                numberIndexed++;
                dispatch_async(lockQueue, ^{
                    progressValue = (numberIndexed / totalObjectCount) * 100;
                });
                
                [self didUpdate];
            }
            
            [pool release];
        }
            
        // remove URLs we could not find in the database
        if ([self shouldKeepRunning] && [URLsToRemove count]) {
            for (NSURL *url in URLsToRemove)
                [self removeFileURL:url];
        }
        [URLsToRemove release];
        
        [self didUpdate];
        
        [items release];
        items = itemsToAdd;
        
    }
    
    // add items that were not yet indexed
    if ([self shouldKeepRunning] && [items count]) {
        [self updateStatus:BDSKSearchIndexStatusIndexing];
        [self indexFilesForItems:items numberPreviouslyIndexed:numberIndexed];
    }
    
    [items release];

    [self updateStatus:BDSKSearchIndexStatusRunning];
}

@end

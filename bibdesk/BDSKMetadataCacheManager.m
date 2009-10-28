//
//  BDSKMetadataCacheManager.m
//  Bibdesk
//
//  Created by Christiaan on 10/28/09.
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

#import "BDSKMetadataCacheManager.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import "BDAlias.h"

@implementation BDSKMetadataCacheManager

static BDSKMetadataCacheManager *sharedManager = nil;

+ (BDSKMetadataCacheManager *)sharedManager {
    if (sharedManager == nil)
        [[self alloc] init];
    return sharedManager;
}

+ (id)allocWithZone:(NSZone *)zone {
    return sharedManager ?: [super allocWithZone:zone];
}

- (id)init {
    if ((sharedManager == nil) && (sharedManager = self = [super init])) {
        metadataCacheLock = [[NSLock alloc] init];
        canWriteMetadata = 1;
    }
    return sharedManager;
}

- (void)dealloc {
    [metadataCacheLock release];
    [super dealloc];
}

- (id)retain { return self; }

- (id)autorelease { return self; }

- (void)release {}

- (NSUInteger)retainCount { return NSUIntegerMax; }

- (void)terminate {
    OSAtomicCompareAndSwap32Barrier(1, 0, &canWriteMetadata);
}

- (void)privateRebuildMetadataCache:(id)userInfo{
    
    BDSKPRECONDITION([NSThread isMainThread] == NO);
    
    // we could unlock after checking the flag, but we don't want multiple threads writing to the cache directory at the same time, in case files have identical items
    [metadataCacheLock lock];
    OSMemoryBarrier();
    if(canWriteMetadata == 0){
        NSLog(@"Application will quit without writing metadata cache.");
        [metadataCacheLock unlock];
        return;
    }

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [userInfo retain];
    
    NSArray *publications = [userInfo valueForKey:@"publications"];
    NSError *error = nil;
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    @try{

        // hidden option to use XML plists for easier debugging, but the binary plists are more efficient
        BOOL useXMLFormat = [[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKUseXMLSpotlightCache"];
        NSPropertyListFormat plistFormat = useXMLFormat ? NSPropertyListXMLFormat_v1_0 : NSPropertyListBinaryFormat_v1_0;

        NSString *cachePath = [fileManager spotlightCacheFolderPathByCreating:&error];
        if(cachePath == nil){
            error = [NSError localErrorWithCode:kBDSKFileOperationFailed localizedDescription:NSLocalizedString(@"Unable to create the cache folder for Spotlight metadata.", @"Error description") underlyingError:error];
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Unable to build metadata cache at path \"%@\"", cachePath] userInfo:nil];
        }
        
        NSURL *documentURL = [userInfo valueForKey:@"fileURL"];
        NSString *docPath = [documentURL path];
        
        // After this point, there should be no underlying NSError, so we'll create one from scratch
        
        if([fileManager objectExistsAtFileURL:documentURL] == NO){
            error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Unable to find the file associated with this item.", @"Error description"), NSLocalizedDescriptionKey, docPath, NSFilePathErrorKey, nil]];
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Unable to build metadata cache for document at path \"%@\"", docPath] userInfo:nil];
        }
        
        NSString *path;
        NSString *citeKey;
        
        BDAlias *alias = [[BDAlias alloc] initWithURL:documentURL];
        if(alias == nil){
            error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Unable to create an alias for this document.", @"Error description"), NSLocalizedDescriptionKey, docPath, NSFilePathErrorKey, nil]];
            @throw [NSException exceptionWithName:NSObjectNotAvailableException reason:[NSString stringWithFormat:@"Unable to get an alias for file %@", docPath] userInfo:nil];
        }
        
        NSData *aliasData = [alias aliasData];
        [alias autorelease];
    
        NSMutableDictionary *metadata = [NSMutableDictionary dictionaryWithCapacity:10];    
        
        for (NSDictionary *anItem in publications) {
            OSMemoryBarrier();
            if(canWriteMetadata == 0){
                NSLog(@"Application will quit without finishing writing metadata cache.");
                break;
            }
            
            citeKey = [anItem objectForKey:@"net_sourceforge_bibdesk_citekey"];
            if(citeKey == nil)
                continue;
                        
            // we won't index this, but it's needed to reopen the parent file
            [metadata setObject:aliasData forKey:@"FileAlias"];
            // use doc path as a backup in case the alias fails
            [metadata setObject:docPath forKey:@"net_sourceforge_bibdesk_owningfilepath"];
            
            [metadata addEntriesFromDictionary:anItem];
			
            path = [fileManager spotlightCacheFilePathWithCiteKey:citeKey];

            // Save the plist; we can get an error if these are not plist objects, or the file couldn't be written.  The first case is a programmer error, and the second should have been caught much earlier in this code.
            if(path) {
                
                NSString *errString = nil;
                NSData *data = [NSPropertyListSerialization dataFromPropertyList:metadata format:plistFormat errorDescription:&errString];
                if(nil == data) {
                    error = [NSError mutableLocalErrorWithCode:kBDSKPropertyListSerializationFailed localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"Unable to save metadata cache file for item with cite key \"%@\".  The error was \"%@\"", @"Error description"), citeKey, errString]];
                    [errString release];
                    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Unable to create cache file for %@", [anItem description]] userInfo:nil];
                } else {
                    if(NO == [data writeToFile:path options:NSAtomicWrite error:&error])
                        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Unable to create cache file for %@", [anItem description]] userInfo:nil];
                }
            }
            [metadata removeAllObjects];
        }
    }    
    @catch (id localException){
        NSLog(@"-[%@ %@] discarding exception %@", [self class], NSStringFromSelector(_cmd), [localException description]);
        // log the error since presentError: only gives minimum info
        NSLog(@"%@", [error description]);
        [NSApp performSelectorOnMainThread:@selector(presentError:) withObject:error waitUntilDone:NO];
    }
    @finally{
        [userInfo release];
        [metadataCacheLock unlock];
        [fileManager release];
        [pool release];
    }
}

- (void)rebuildMetadataCache:(id)userInfo{  
    [NSThread detachNewThreadSelector:@selector(privateRebuildMetadataCache:) toTarget:self withObject:userInfo];
}

@end

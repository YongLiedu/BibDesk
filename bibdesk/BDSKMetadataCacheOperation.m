//
//  BDSKMetadataCacheOperation.m
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

#import "BDSKMetadataCacheOperation.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import "BDAlias.h"
#import <libkern/OSAtomic.h>


@implementation BDSKMetadataCacheOperation

- (id)initWithPublicationInfos:(NSArray *)pubInfos forDocumentURL:(NSURL *)aURL {
    if (self = [super init]) {
        publicationInfos = [pubInfos copy];
        documentURL = [aURL copy];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(publicationInfos);
    BDSKDESTROY(documentURL);
    [super dealloc];
}

- (void)main {
    if ([self isCancelled]) {
        NSLog(@"Application will quit without writing metadata cache.");
        return;
    }

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSError *error = nil;
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    @try {

        // hidden option to use XML plists for easier debugging, but the binary plists are more efficient
        BOOL useXMLFormat = [[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKUseXMLSpotlightCache"];
        NSPropertyListFormat plistFormat = useXMLFormat ? NSPropertyListXMLFormat_v1_0 : NSPropertyListBinaryFormat_v1_0;

        NSString *cachePath = [fileManager spotlightCacheFolderPathByCreating:&error];
        if (cachePath == nil) {
            error = [NSError localErrorWithCode:kBDSKFileOperationFailed localizedDescription:NSLocalizedString(@"Unable to create the cache folder for Spotlight metadata.", @"Error description") underlyingError:error];
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Unable to build metadata cache at path \"%@\"", cachePath] userInfo:nil];
        }
        
        NSString *docPath = [documentURL path];
        
        // After this point, there should be no underlying NSError, so we'll create one from scratch
        
        if ([fileManager objectExistsAtFileURL:documentURL] == NO) {
            error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Unable to find the file associated with this item.", @"Error description"), NSLocalizedDescriptionKey, docPath, NSFilePathErrorKey, nil]];
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Unable to build metadata cache for document at path \"%@\"", docPath] userInfo:nil];
        }
        
        BDAlias *alias = [[BDAlias alloc] initWithURL:documentURL];
        if (alias == nil) {
            error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Unable to create an alias for this document.", @"Error description"), NSLocalizedDescriptionKey, docPath, NSFilePathErrorKey, nil]];
            @throw [NSException exceptionWithName:NSObjectNotAvailableException reason:[NSString stringWithFormat:@"Unable to get an alias for file %@", docPath] userInfo:nil];
        }
        
        NSDictionary *docInfo = [NSDictionary dictionaryWithObjectsAndKeys:docPath, @"net_sourceforge_bibdesk_owningfilepath", [alias aliasData], @"FileAlias", nil];
        
        [alias release];
        
        for (NSDictionary *anItem in publicationInfos) {
            if ([self isCancelled]) {
                NSLog(@"Application will quit without finishing writing metadata cache.");
            } else {
                NSString *citeKey = [anItem objectForKey:@"net_sourceforge_bibdesk_citekey"];
                if (citeKey) {
                    NSString *path = [fileManager spotlightCacheFilePathWithCiteKey:citeKey];
                    // Save the plist; we can get an error if these are not plist objects, or the file couldn't be written.  The first case is a programmer error, and the second should have been caught much earlier in this code.
                    if (path) {
                        NSMutableDictionary *metadata = [docInfo mutableCopy];
                        [metadata addEntriesFromDictionary:anItem];
                        NSString *errString = nil;
                        NSData *data = [NSPropertyListSerialization dataFromPropertyList:metadata format:plistFormat errorDescription:&errString];
                        [metadata release];
                        if (nil == data) {
                            error = [NSError mutableLocalErrorWithCode:kBDSKPropertyListSerializationFailed localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"Unable to save metadata cache file for item with cite key \"%@\".  The error was \"%@\"", @"Error description"), citeKey, errString]];
                            [errString release];
                            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Unable to create cache file for %@", anItem] userInfo:nil];
                        } else if (NO == [data writeToFile:path options:NSAtomicWrite error:&error]) {
                            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Unable to create cache file for %@", anItem] userInfo:nil];
                        }
                    }
                }
            }
        }
    }    
    @catch (id localException) {
        NSLog(@"-[%@ %@] discarding exception %@", [self class], NSStringFromSelector(_cmd), [localException description]);
        // log the error since presentError: only gives minimum info
        NSLog(@"%@", [error description]);
        [NSApp performSelectorOnMainThread:@selector(presentError:) withObject:error waitUntilDone:NO];
    }
    @finally {
        [fileManager release];
        [pool release];
    }
}

@end

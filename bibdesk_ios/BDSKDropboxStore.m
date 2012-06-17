//
//  BDSKDropboxStore.m
//  BibDesk
//
//  Created by Colin A. Smith on 3/3/12.
/*
 This software is Copyright (c) 2012-2012
 Colin A. Smith. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Colin A. Smith nor the names of any
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

#import "BDSKDropboxStore.h"

#import <DropboxSDK/DropboxSDK.h>
#import "BDSKLocalFile.h"

static BDSKDropboxStore *sharedDropboxStore = nil;

@interface BDSKDropboxStore () <DBRestClientDelegate> {
    NSMutableArray *_bibliographies;
    NSMutableArray *_pdfs;
    NSMutableDictionary *_pdfFilePaths;
    NSMutableArray *_filesToLoad;
    DBRestClient *_restClient;
    NSString *_rootHash;
    BOOL _syncing;
    
    NSArray *_bibExtensions;
    NSArray *_pdfExtensions;
}

@property (nonatomic, readonly) DBRestClient* restClient;

- (void)setSyncing:(BOOL)syncing;

@end

@implementation BDSKDropboxStore

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey {
 
    BOOL automatic = NO;
    if ([theKey isEqualToString:@"syncing"]) {
        automatic = NO;
    } else {
        automatic=[super automaticallyNotifiesObserversForKey:theKey];
    }
    return automatic;
}

+ (BDSKDropboxStore *)sharedStore {
    
    if (!sharedDropboxStore) {
        sharedDropboxStore = [[BDSKDropboxStore alloc] init];
    }
    
    return sharedDropboxStore;
}

- (id)init {

    [super init];
    _bibliographies = [[NSMutableArray alloc] init];
    _pdfs = [[NSMutableArray alloc] init];
    _pdfFilePaths = [[NSMutableDictionary alloc] init];
    _filesToLoad = [[NSMutableArray alloc] init];
    
    _bibExtensions = [[NSArray alloc] initWithObjects:@"bib", nil];
    _pdfExtensions = [[NSArray alloc] initWithObjects:@"pdf", nil];
    
    return self;
}

- (void) dealloc {

    [_bibliographies release];
    [_pdfs release];
    [_pdfFilePaths release];
    [_restClient release];
    [_rootHash release];
    [_bibExtensions release];
    [_pdfExtensions release];
    [super dealloc];
}

#pragma mark Property methods

- (NSMutableArray*)bibliographies {
    return _bibliographies;
}

- (NSMutableArray*)pdfs {
    return _pdfs;
}

- (NSDictionary *)pdfFilePaths {

    return _pdfFilePaths;
}

- (DBRestClient*)restClient {
    if (_restClient == nil) {
        _restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        _restClient.delegate = self;
    }
    return _restClient;
}

- (BOOL)syncing {

    return _syncing;
}

- (void)setSyncing:(BOOL)syncing {

    [self willChangeValueForKey:@"syncing"];
    _syncing = syncing;
    [self didChangeValueForKey:@"syncing"];
}

#pragma mark Synchronization methods

- (void)addLocalFiles {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:[BDSKLocalFile documentsRoot] error:&error];
    if (error) {
        NSLog(@"Contents of Directory Failed: %@", [error localizedDescription]);
    }
    
    BOOL isDirectory;
    
    NSMutableArray *bibliographiesProxy = [self mutableArrayValueForKey:@"bibliographies"];
    NSMutableArray *pdfsProxy = [self mutableArrayValueForKey:@"pdfs"];
    
    for (NSString *filename in contents) {
        NSString *fullPath = [[BDSKLocalFile documentsRoot] stringByAppendingPathComponent:filename];
        //NSLog(@"Adding Local File: %@", fullPath);
        [fileManager fileExistsAtPath:fullPath isDirectory:(BOOL *)&isDirectory];
        NSString* extension = [[filename pathExtension] lowercaseString];
        if (!isDirectory && [_bibExtensions indexOfObject:extension] != NSNotFound) {
            BDSKLocalFile *newFile = [[BDSKLocalFile alloc] initWithFullPath:fullPath];
            [bibliographiesProxy addObject:newFile];
            [newFile release];
        } else if (!isDirectory && [_pdfExtensions indexOfObject:extension] != NSNotFound) {
            BDSKLocalFile *newFile = [[BDSKLocalFile alloc] initWithFullPath:fullPath];
            //NSLog(@"Adding Path: %@", newFile.path);
            [_pdfFilePaths setObject:newFile forKey:newFile.pathWithoutLeadingSlash];
            [pdfsProxy addObject:newFile];
            [newFile release];
        }
    }
}

- (void)startSync {

    if (!_syncing) {
        NSString *rootPath = [[BDSKLocalFile dropboxRoot] length] ? [BDSKLocalFile dropboxRoot] : @"/";
        [self.restClient loadMetadata:rootPath withHash:_rootHash];
        [self setSyncing:YES];
    }
}

#pragma mark DBRestClientDelegate methods

- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata {

    NSString *rootPath = [[BDSKLocalFile dropboxRoot] length] ? [BDSKLocalFile dropboxRoot] : @"/";
    if ([metadata.path compare:rootPath] == NSOrderedSame) {
        
        [_rootHash release];
        _rootHash = [metadata.hash retain];
        
        NSMutableIndexSet *bibliographiesToRemove = [[NSMutableIndexSet alloc] init];
        NSMutableIndexSet *pdfsToRemove = [[NSMutableIndexSet alloc] init];
        [bibliographiesToRemove addIndexesInRange:NSMakeRange(0, [_bibliographies count])];
        [pdfsToRemove addIndexesInRange:NSMakeRange(0, [_pdfs count])];

        for (DBMetadata* child in metadata.contents) {
            NSString* extension = [[child.path pathExtension] lowercaseString];
            NSString* noExtension = [child.path stringByDeletingPathExtension];
            if (!child.isDirectory && [_bibExtensions indexOfObject:extension] != NSNotFound && ![noExtension hasSuffix:@"(Autosaved)"]) {
                
                BDSKLocalFile *newFile = [[BDSKLocalFile alloc] initWithDropboxPath:child.path lastModifiedDate:child.lastModifiedDate totalByets:child.totalBytes];
                
                NSUInteger existingIndex = [_bibliographies indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                    return [((BDSKLocalFile *)obj).path compare:newFile.path] == NSOrderedSame;
                }];
                
                if (existingIndex == NSNotFound) {
                    [_filesToLoad addObject:newFile];
                } else {
                    [bibliographiesToRemove removeIndex:existingIndex];
                    BDSKLocalFile *existingFile = [_bibliographies objectAtIndex:existingIndex];
                    if (!([newFile.lastModifiedDate isEqualToDate:existingFile.lastModifiedDate] && newFile.totalBytes == existingFile.totalBytes)) {
                        [_filesToLoad addObject:newFile];
                    }
                }
                
                [newFile release];
            
            } else if (!child.isDirectory && [_pdfExtensions indexOfObject:extension] != NSNotFound) {
                
                BDSKLocalFile *newFile = [[BDSKLocalFile alloc] initWithDropboxPath:child.path lastModifiedDate:child.lastModifiedDate totalByets:child.totalBytes];
                
                NSUInteger existingIndex = [_pdfs indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                    return ![((BDSKLocalFile *)obj).path compare:newFile.path];
                }];
                
                if (existingIndex == NSNotFound) {
                    [_filesToLoad addObject:newFile];
                } else {
                    [pdfsToRemove removeIndex:existingIndex];
                    BDSKLocalFile *existingFile = [_pdfs objectAtIndex:existingIndex];
                    if (!([newFile.lastModifiedDate isEqualToDate:existingFile.lastModifiedDate] && newFile.totalBytes == existingFile.totalBytes)) {
                        [_filesToLoad addObject:newFile];
                    }
                }
                
                [newFile release];
            }
        }
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        for (BDSKLocalFile *file in [_bibliographies objectsAtIndexes:bibliographiesToRemove]) {
            NSLog(@"Removing File at Path: %@", file.fullPath);
            [fileManager removeItemAtPath:file.fullPath error:&error];
            if (error) {
                NSLog(@"Remove File Failed: %@", [error localizedDescription]);
            }
        }
        
        NSMutableArray *bibliographiesProxy = [self mutableArrayValueForKey:@"bibliographies"];
        [bibliographiesProxy removeObjectsAtIndexes:bibliographiesToRemove];
        [bibliographiesToRemove release];
        
        for (BDSKLocalFile *file in [_pdfs objectsAtIndexes:pdfsToRemove]) {
            NSLog(@"Removing File at Path: %@", file.fullPath);
            [fileManager removeItemAtPath:file.fullPath error:&error];
            if (error) {
                NSLog(@"Remove File Failed: %@", [error localizedDescription]);
            }
            [_pdfFilePaths removeObjectForKey:file.pathWithoutLeadingSlash];
        }
        
        NSMutableArray *pdfsProxy = [self mutableArrayValueForKey:@"pdfs"];
        [pdfsProxy removeObjectsAtIndexes:pdfsToRemove];
        [pdfsToRemove release];

        if ([_filesToLoad count]) {
            BDSKLocalFile *fileToLoad = [_filesToLoad objectAtIndex:0];
            NSLog(@"Loading File: %@", fileToLoad.dropboxPath);
            [self.restClient loadFile:fileToLoad.dropboxPath intoPath:fileToLoad.fullPath];
        } else {
            [self setSyncing:NO];
        }
    }
}

- (void)restClient:(DBRestClient*)client metadataUnchangedAtPath:(NSString*)path {

    NSString *rootPath = [[BDSKLocalFile dropboxRoot] length] ? [BDSKLocalFile dropboxRoot] : @"/";
    if ([path compare:rootPath] == NSOrderedSame) {
        [self setSyncing:NO];
    }
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error {

    NSLog(@"Load Metadata Failed: %@", [error localizedDescription]);
    
    [self setSyncing:NO];
}

- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)destPath contentType:(NSString*)contentType metadata:(DBMetadata*)metadata {

    NSMutableArray *arrayProxy = nil;
    NSString* extension = [[metadata.path pathExtension] lowercaseString];
    if ([_bibExtensions indexOfObject:extension] != NSNotFound) {
        arrayProxy = [self mutableArrayValueForKey:@"bibliographies"];
    } else if ([_pdfExtensions indexOfObject:extension] != NSNotFound) {
        arrayProxy = [self mutableArrayValueForKey:@"pdfs"];
    }
    
    BDSKLocalFile *loadedFile = [_filesToLoad objectAtIndex:0];

    NSDictionary *attributes = [NSDictionary dictionaryWithObject:loadedFile.lastModifiedDate forKey:NSFileModificationDate];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    //NSLog(@"Setting File Modification Date: %@", loadedFile.lastModifiedDate);
    [fileManager setAttributes:attributes ofItemAtPath:loadedFile.fullPath error:&error];
    if (error) {
        NSLog(@"Set Attributes Failed: %@", [error localizedDescription]);
    }
    
    NSUInteger existingIndex = [arrayProxy indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [((BDSKLocalFile *)obj).path compare:loadedFile.path] == NSOrderedSame;
    }];
    
    if (existingIndex == NSNotFound) {
        if ([_pdfExtensions indexOfObject:extension] != NSNotFound) {
            [_pdfFilePaths setObject:loadedFile forKey:loadedFile.pathWithoutLeadingSlash];
        }
        [arrayProxy addObject:loadedFile];
    } else {
        BDSKLocalFile *existingFile = [arrayProxy objectAtIndex:existingIndex];
        [existingFile updateWithRevisedFile:loadedFile];
    }
    
    [_filesToLoad removeObjectAtIndex:0];

    if ([_filesToLoad count]) {
        BDSKLocalFile *fileToLoad = [_filesToLoad objectAtIndex:0];
        NSLog(@"Loading File: %@", fileToLoad.dropboxPath);
        [self.restClient loadFile:fileToLoad.dropboxPath intoPath:fileToLoad.fullPath];
    } else {
        [self setSyncing:NO];
    }
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error {

    NSLog(@"Load File Failed: %@", [error localizedDescription]);
    
    [_filesToLoad removeObjectAtIndex:0];
    
    if ([_filesToLoad count]) {
        BDSKLocalFile *fileToLoad = [_filesToLoad objectAtIndex:0];
        NSLog(@"Loading File: %@", fileToLoad.dropboxPath);
        [self.restClient loadFile:fileToLoad.dropboxPath intoPath:fileToLoad.fullPath];
    } else {
        [self setSyncing:NO];
    }
}

@end

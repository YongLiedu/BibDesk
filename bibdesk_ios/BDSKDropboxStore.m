//
//  BDSKDropboxStore.m
//  BibDesk
//
//  Created by Colin Smith on 10/28/12.
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
#import "BibDocument.h"
#import "BDSKAppDelegate.h"
#import "BDSKBibFile.h"
#import "BDSKExternalLinkedFile.h"

typedef enum {
    none,
    bibFileMetadata,
    bibFileDownload,
    linkedFileMetadata,
    linkedFileDownload
} BDKSDropboxSyncStage;

static BDSKDropboxStore *sharedDropboxStore = nil;

@interface BDSKDropboxStore () <DBRestClientDelegate> {

    DBRestClient *_restClient;
    NSMutableDictionary *_pathMetadata;
    BDKSDropboxSyncStage _syncStage;
    NSMutableArray *_bibFilesToDownload;
    NSMutableSet *_bibFileNamesToOpen;
    NSMutableSet *_linkedFilePaths;
    NSMutableSet *_linkedFilePathsToStore;
    NSMutableSet *_linkedFilePathsFound;
    NSMutableArray *_linkedFileDirectoriesToFetch;
    NSMutableArray *_linkedFilesToDownload;
    NSArray *_bibFileExtensions;
}

- (DBRestClient*)restClient;
- (void)setSyncStage:(BDKSDropboxSyncStage)syncStage;
- (void)processBibFileMetadata:(DBMetadata *)metadata;

@property (retain) NSString *bibFileRootPath;
@property (retain) NSString *linkedFileRootPath;

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
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        BOOL success;
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *documentsPath = [paths objectAtIndex:0];
        
        documentsPath = [documentsPath stringByAppendingPathComponent:@"Application Support/Dropbox"];
        success = [fileManager createDirectoryAtPath:documentsPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (!success) {
            NSLog(@"Error Creating Dropbox Sync Directory: %@", [error localizedDescription]);
        }
        
        NSURL *documentsURL = [NSURL fileURLWithPath:documentsPath];
        success = [documentsURL setResourceValue:[NSNumber numberWithBool:YES]
                                      forKey:NSURLIsExcludedFromBackupKey error:&error];
        if(!success){
            NSLog(@"Error excluding %@ from backup %@", documentsURL, error);
        }
        
        NSString *bibFileRootPath = [documentsPath stringByAppendingPathComponent:@"BibFiles"];
        success = [fileManager createDirectoryAtPath:bibFileRootPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (!success) {
            NSLog(@"Error Creating BibFiles Directory: %@", [error localizedDescription]);
        }
        [BDSKDropboxStore sharedStore].bibFileRootPath = bibFileRootPath;
        
        NSString *linkedFileRootPath = [documentsPath stringByAppendingPathComponent:@"LinkedFiles"];
        success = [fileManager createDirectoryAtPath:linkedFileRootPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (!success) {
            NSLog(@"Error Creating LinkedFiles Directory: %@", [error localizedDescription]);
        }
        [BDSKDropboxStore sharedStore].linkedFileRootPath = linkedFileRootPath;
        
        NSLog(@"Documents Root: %@", documentsPath);
    }
    
    return sharedDropboxStore;
}

+ (NSString *)storeName {

    return @"Dropbox";
}

- (BDSKDropboxStore *)init {

    if (self = [super init]) {

        _restClient = nil;
        _pathMetadata = [[NSMutableDictionary alloc] init];
        _drobboxBibFilePath = @"/";
#if TARGET_IPHONE_SIMULATOR
        _drobboxBibFilePath = @"/PapersSimulator";
#else
        _drobboxBibFilePath = @"/Papers";
#endif
        _bibFilesToDownload = [[NSMutableArray alloc] init];
        _bibFileNamesToOpen = [[NSMutableSet alloc] init];
        _linkedFilePaths = [[NSMutableSet alloc] init];
        _linkedFilePathsToStore = [[NSMutableSet alloc] init];
        _linkedFilePathsFound = [[NSMutableSet alloc] init];
        _linkedFileDirectoriesToFetch = [[NSMutableArray alloc] init];
        _linkedFilesToDownload = [[NSMutableArray alloc] init];
        _bibFileExtensions = [[NSArray alloc] initWithObjects:@"bib", nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleBibDocumentChangedNotification:) name:@"BDSKBibDocumentChanged" object:self];
    }
    
    return self;
}

- (void)dealloc {

    [_restClient release];
    [_pathMetadata release];
    [_drobboxBibFilePath release];
    [_bibFilesToDownload release];
    [_bibFileNamesToOpen release];
    [_linkedFilePaths release];
    [_linkedFilePathsToStore release];
    [_linkedFilePathsFound release];
    [_linkedFileDirectoriesToFetch release];
    [_linkedFilesToDownload release];
    [_bibFileExtensions release];
    [_bibFileRootPath release];
    [_linkedFileRootPath release];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"BDSKBibDocumentChanged" object:self];

    [super dealloc];
}

- (NSString *)localPathForBibFilePath:(NSString *)path {

    return [self.bibFileRootPath stringByAppendingPathComponent:path];
}

- (NSString *)localPathForLinkedFilePath:(NSString *)path {

    return [self.linkedFileRootPath stringByAppendingPathComponent:path];
}

NSString *BDSKRemoveParentReferencesFromPath(NSString *path) {

    static NSRegularExpression *parentRegexp = nil;
    
    if (!parentRegexp) {
        parentRegexp = [[NSRegularExpression alloc] initWithPattern:@"[^/][^/]*/\\.\\./" options:0 error:nil];
    }
    
    NSUInteger lastLength;
    
    do {
        lastLength = path.length;
        path = [parentRegexp stringByReplacingMatchesInString:path options:0 range:NSMakeRange(0, lastLength) withTemplate:@""];
    } while (path.length < lastLength);
    
    return path;
}

- (NSString *)pathForLinkedFilePath:(NSString *)relativePath relativeToBibFileName:(NSString *)bibFileName {

    NSString *relativeDropboxBibFilePath = [_drobboxBibFilePath substringFromIndex:1];

    return BDSKRemoveParentReferencesFromPath([[relativeDropboxBibFilePath stringByAppendingPathComponent:relativePath] stringByStandardizingPath]);
}

- (NSString *)bibFilePathForDropboxPath:(NSString *)path {

    return [path substringFromIndex:_drobboxBibFilePath.length+1];
}

- (NSString *)dropboxPathForBibFilePath:(NSString *)path {

    return [_drobboxBibFilePath stringByAppendingPathComponent:path];
}

- (NSString *)linkedFilePathForDropboxPath:(NSString *)path {

    return [path substringFromIndex:1];
}

- (NSString *)dropboxPathForLinkedFilePath:(NSString *)path {

    return [@"/" stringByAppendingPathComponent:path];
}

#pragma mark - DBRestClient Interface

- (DBRestClient*)restClient {

    if (_restClient == nil) {
        _restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        _restClient.delegate = self;
    }
    
    return _restClient;
}

- (void)restClient:(DBRestClient *)client loadedMetadata:(DBMetadata *)metadata {

    if (_syncStage == bibFileMetadata) {

        [self processBibFileMetadata:metadata];

    } else if (_syncStage == linkedFileMetadata) {
    
        [self processLinkedFileMetadata:metadata];
    }
}

- (void)restClient:(DBRestClient *)client metadataUnchangedAtPath:(NSString *)path {

    DBMetadata *metadata = [_pathMetadata objectForKey:path];

    [self restClient:client loadedMetadata:metadata];
}

- (void)restClient:(DBRestClient *)client loadMetadataFailedWithError:(NSError *)error {

    if (_syncStage == bibFileMetadata) {
    
        NSLog(@"Error Loading BibFile Metadata: %@", [error localizedDescription]);

        [self setSyncStage:none];
    
    } else if (_syncStage == bibFileMetadata) {
    
        NSLog(@"Error Loading LinkedFile Metadata: %@", [error localizedDescription]);

        [self setSyncStage:none];
    }
}

- (void)restClient:(DBRestClient *)client loadedFile:(NSString *)destPath {

    if (_syncStage == bibFileDownload) {
    
        [self processBibFileDownload:destPath];
    
    } else if (_syncStage == linkedFileDownload) {
    
        [self processLinkedFileDownload:destPath];
    }
}

- (void)restClient:(DBRestClient *)client loadFileFailedWithError:(NSError *)error {

    if (_syncStage == bibFileDownload) {
    
        NSLog(@"Error Downloading BibFile: %@", [error localizedDescription]);

        [self setSyncStage:none];
    
    } else if (_syncStage == linkedFileDownload) {
    
        NSLog(@"Error Downloading LinkedFile: %@", [error localizedDescription]);

        [self setSyncStage:none];
    
    }
}


#pragma mark - Dropbox Synchronization

- (void)addLocalFiles {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:_bibFileRootPath error:&error];
    if (error) {
        NSLog(@"Contents of Directory Failed: %@", [error localizedDescription]);
    }
    
    BOOL isDirectory;
    
    for (NSString *filename in contents) {
        NSString *fullPath = [self localPathForBibFilePath:filename];
        [fileManager fileExistsAtPath:fullPath isDirectory:(BOOL *)&isDirectory];
        NSString* extension = [[filename pathExtension] lowercaseString];
        if (!isDirectory && [_bibFileExtensions indexOfObject:extension] != NSNotFound) {
            
            BDSKBibFile *newFile = [[BDSKBibFile alloc] init];
            newFile.path = filename;
            
            NSLog(@"Adding Local BibFile: %@", newFile.path);
            
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:&error];
            if (error) {
                NSLog(@"Error Getting Attributes: %@", [error localizedDescription]);
            } else {
                newFile.lastModifiedDate = (NSDate *)[attributes objectForKey:NSFileModificationDate];
                newFile.totalBytes = [(NSNumber *)[attributes objectForKey:NSFileSize] longLongValue];
            }
            
            [self addedOrUpdatedBibFile:newFile];
            [newFile release];
        }
    }
    
    [self addLocalLinkedFilesForDirectory:@""];
}

- (void)addLocalLinkedFilesForDirectory:(NSString *)directoryPath {

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSString *fullDirectoryPath = [self localPathForLinkedFilePath:directoryPath];
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:fullDirectoryPath error:&error];
    if (error) {
        NSLog(@"Contents of Directory Failed: %@", [error localizedDescription]);
    }
    
    BOOL isDirectory;
    
    for (NSString *filename in contents) {
        
        NSString *fullPath = [fullDirectoryPath stringByAppendingPathComponent:filename];
        [fileManager fileExistsAtPath:fullPath isDirectory:(BOOL *)&isDirectory];
        
        if (isDirectory) {
        
            [self addLocalLinkedFilesForDirectory:[directoryPath stringByAppendingPathComponent:filename]];
        
        } else {
        
            BDSKExternalLinkedFile *newFile = [[BDSKExternalLinkedFile alloc] init];
            newFile.path = [directoryPath stringByAppendingPathComponent:filename];
            
            //NSLog(@"Adding Local LinkedFile: %@", newFile.path);
            
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:&error];
            if (error) {
                NSLog(@"Error Getting Attributes: %@", [error localizedDescription]);
            } else {
                newFile.lastModifiedDate = (NSDate *)[attributes objectForKey:NSFileModificationDate];
                newFile.totalBytes = [(NSNumber *)[attributes objectForKey:NSFileSize] longLongValue];
                newFile.availability = Available;
            }
            
            [self addedOrUpdatedLinkedFile:newFile newContents:YES];
            [newFile release];
        }
    }
}

- (void)setSyncStage:(BDKSDropboxSyncStage)syncStage {

    if ((_syncStage != none && syncStage == none) || (_syncStage == none && syncStage != none)) {
        [self willChangeValueForKey:@"isSyncing"];
        _syncStage = syncStage;
        [self didChangeValueForKey:@"isSyncing"];
        if (_syncStage == none) {
            [(BDSKAppDelegate *)[UIApplication sharedApplication].delegate hideNetworkActivityIndicator];
        } else {
            [(BDSKAppDelegate *)[UIApplication sharedApplication].delegate showNetworkActivityIndicator];
        }
    } else {
        _syncStage = syncStage;
    }
}

- (BOOL)isSyncing {

    return _syncStage != none;
}

- (void)startSync {

    if (!self.isSyncing) {
    
        [self startBibFileMetadata];
    }
}

- (void) startBibFileMetadata {

    DBMetadata *metadata = [_pathMetadata objectForKey:_drobboxBibFilePath];
    NSString *hash = metadata.hash;
    [self.restClient loadMetadata:_drobboxBibFilePath withHash:hash];
    [self setSyncStage:bibFileMetadata];
}

- (void)processBibFileMetadata:(DBMetadata *)metadata {

    [_pathMetadata setValue:metadata forKey:metadata.path];

    [_bibFilesToDownload removeAllObjects];
    [_bibFileNamesToOpen removeAllObjects];
    [_linkedFilePaths removeAllObjects];
    [_linkedFilePathsToStore removeAllObjects];
    NSMutableDictionary *bibFilesToRemove = [self.bibFiles mutableCopy];

    for (DBMetadata *child in metadata.contents) {
    
        NSString* extension = [[child.path pathExtension] lowercaseString];
        NSString* noExtension = [child.path stringByDeletingPathExtension];
        if (!child.isDirectory && [_bibFileExtensions indexOfObject:extension] != NSNotFound && ![noExtension hasSuffix:@"(Autosaved)"]) {
            
            NSString *bibFilePath = [self bibFilePathForDropboxPath:child.path];
            
            [bibFilesToRemove removeObjectForKey:bibFilePath];
            
            BDSKBibFile *existingBibFile = [self.bibFiles objectForKey:bibFilePath];
            
            if (existingBibFile && [child.lastModifiedDate isEqualToDate:existingBibFile.lastModifiedDate] && child.totalBytes == existingBibFile.totalBytes) {
                [self updateLinkedFilePathsForBibFileName:bibFilePath];
                continue;
            }
            
            BDSKBibFile *newBibFile = [[BDSKBibFile alloc] init];
            newBibFile.path = bibFilePath;
            newBibFile.lastModifiedDate = child.lastModifiedDate;
            newBibFile.totalBytes = child.totalBytes;
            
            [_bibFilesToDownload addObject:newBibFile];
            
            [newBibFile release];
        }
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    for (BDSKBibFile *file in [bibFilesToRemove allValues]) {
        NSString *path = [self localPathForBibFilePath:file.path];
        NSLog(@"Removing File at Path: %@", path);
        [fileManager removeItemAtPath:path error:&error];
        if (error) {
            NSLog(@"Remove File Failed: %@", [error localizedDescription]);
        }
        [self removedBibFile:file];
    }

    [bibFilesToRemove release];
    
    [self startOrContinueBibFileDownload];
}

- (void)startOrContinueBibFileDownload {

    if ([_bibFilesToDownload count]) {
        
        BDSKBibFile *bibFile = [_bibFilesToDownload objectAtIndex:0];
        [_restClient loadFile:[self dropboxPathForBibFilePath:bibFile.path] intoPath:[self localPathForBibFilePath:bibFile.path]];
        NSLog(@"Downloading BibFile: %@", bibFile.path);
        [self setSyncStage:bibFileDownload];
    
    }
    
    if (_bibFilesToDownload.count == 0 && _bibFileNamesToOpen.count == 0) {
        
        [self startLinkedFileMetadata];
    }
}

- (void)processBibFileDownload:(NSString *)destPath {

    BDSKBibFile *bibFile = [_bibFilesToDownload objectAtIndex:0];
    
    if (![destPath isEqualToString:[self localPathForBibFilePath:bibFile.path]]) {
    
        NSLog(@"Destination Path: %@ does not match Expected Path: %@", destPath, [self localPathForBibFilePath:bibFile.path]);
        [self setSyncStage:none];
        return;
    }
    
    NSLog(@"Downloaded BibFile: %@", bibFile.path);
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:bibFile.lastModifiedDate forKey:NSFileModificationDate];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    //NSLog(@"Setting File Modification Date: %@", bibFile.lastModifiedDate);
    [fileManager setAttributes:attributes ofItemAtPath:[self localPathForBibFilePath:bibFile.path] error:&error];
    if (error) {
        NSLog(@"Set Attributes Failed: %@", [error localizedDescription]);
    }
    
    [self addedOrUpdatedBibFile:bibFile];
    
    [_bibFilesToDownload removeObjectAtIndex:0];
    [self updateLinkedFilePathsForBibFileName:bibFile.path];
    
    [self startOrContinueBibFileDownload];
}

- (void)updateLinkedFilePathsForBibFileName:(NSString *)bibFileName {

    BibDocument *bibDocument = [self bibDocumentForName:bibFileName];
    
    if (bibDocument.documentState == UIDocumentStateClosed || bibDocument.documentState == UIDocumentStateEditingDisabled) {
        
        NSLog(@"Waiting to Open BibFile: %@", bibFileName);
        [_bibFileNamesToOpen addObject:bibFileName];
        
    } else if (bibDocument.documentState == UIDocumentStateNormal) {
    
        NSLog(@"Updating Linked Files for BibFile: %@", bibFileName);
        for (NSString *path in bibDocument.linkedFilePaths) {
            [_linkedFilePaths addObject:[self pathForLinkedFilePath:path relativeToBibFileName:bibFileName]];
        }
        for (NSString *path in bibDocument.linkedFilePathsToStore) {
            [_linkedFilePathsToStore addObject:[self pathForLinkedFilePath:path relativeToBibFileName:bibFileName]];
        }
        //NSLog(@"Linked Files %@", _linkedFilePaths);
        [_bibFileNamesToOpen removeObject:bibFileName];
    }
}

- (void)handleBibDocumentChangedNotification:(NSNotification *)notification {

    if (_syncStage == bibFileDownload) {
    
        NSString *bibFileName = [notification.userInfo objectForKey:@"bibFileName"];
        [self updateLinkedFilePathsForBibFileName:bibFileName];
        
        if (_bibFilesToDownload.count == 0 && _bibFileNamesToOpen.count == 0) {
        
            [self startLinkedFileMetadata];
        }
    }
}

- (void)startLinkedFileMetadata {

    NSMutableSet *linkedFileDirectoriesToFetch = [NSMutableSet setWithCapacity:1];

    for (NSString *path in _linkedFilePaths) {
        NSString *fileDirectory = [path stringByDeletingLastPathComponent];
        [linkedFileDirectoriesToFetch addObject:fileDirectory];
    }
    
    for (NSString *path in linkedFileDirectoriesToFetch) {
        if (![path hasPrefix:@"../"]) {
            [_linkedFileDirectoriesToFetch addObject:path];
        }
    }
    
    NSLog(@"Directories to Fetch: %@:", _linkedFileDirectoriesToFetch);

    [_linkedFilePathsFound removeAllObjects];
    [_linkedFilesToDownload removeAllObjects];

    [self setSyncStage:linkedFileMetadata];
    
    [self fetchNextLinkedFileDirectory];
}

- (void)fetchNextLinkedFileDirectory {

    if ([_linkedFileDirectoriesToFetch count]) {

        NSString *directoryPath = [_linkedFileDirectoriesToFetch objectAtIndex:0];
        directoryPath = [@"/" stringByAppendingString:directoryPath];
        DBMetadata *metadata = [_pathMetadata objectForKey:directoryPath];
        NSString *hash = metadata.hash;
        [self.restClient loadMetadata:directoryPath withHash:hash];
    
    } else {
    
        NSArray *linkedFiles = [self.linkedFiles allValues];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        
        for (BDSKExternalLinkedFile *linkedFile in linkedFiles) {
        
            if (![_linkedFilePathsFound containsObject:linkedFile.path]) {
            
                if (linkedFile.availability == Available) {
                    NSString *path = [self localPathForLinkedFilePath:linkedFile.path];
                    NSLog(@"Removing LinkedFile at Path: %@", path);
                    [fileManager removeItemAtPath:path error:&error];
                    if (error) {
                        NSLog(@"Remove File Failed: %@", [error localizedDescription]);
                    }
                }
                [self removedLinkedFile:linkedFile];
                
            } else if (![_linkedFilePathsToStore containsObject:linkedFile.path]) {
                
                if (linkedFile.availability == Available) {
                    NSString *path = [self localPathForLinkedFilePath:linkedFile.path];
                    NSLog(@"Removing LinkedFile at Path: %@", path);
                    [fileManager removeItemAtPath:path error:&error];
                    if (error) {
                        NSLog(@"Remove File Failed: %@", [error localizedDescription]);
                    }
                    if ([_linkedFilePaths containsObject:linkedFile.path]) {
                        linkedFile.availability = Downloadable;
                        [self addedOrUpdatedLinkedFile:linkedFile newContents:YES];
                    } else {
                        [self removedLinkedFile:linkedFile];
                    }
                }
            }
        }
    
        [self startOrContinueLinkedFileDownload];
    }
}

- (void)processLinkedFileMetadata:(DBMetadata *)metadata {

    [_pathMetadata setValue:metadata forKey:metadata.path];

    for (DBMetadata *child in metadata.contents) {
    
        NSString *linkedFilePath = [self linkedFilePathForDropboxPath:child.path];
        
        if ([_linkedFilePaths containsObject:linkedFilePath]) {
            
            [_linkedFilePathsFound addObject:linkedFilePath];
            
            BDSKExternalLinkedFile *existingLinkedFile = [self.linkedFiles objectForKey:linkedFilePath];
            
            if (existingLinkedFile && existingLinkedFile.availability == Available && [child.lastModifiedDate isEqualToDate:existingLinkedFile.lastModifiedDate] && child.totalBytes == existingLinkedFile.totalBytes) {
                continue;
            }
            
            BDSKExternalLinkedFile *newLinkedFile = [[BDSKExternalLinkedFile alloc] init];
            newLinkedFile.path = linkedFilePath;
            newLinkedFile.lastModifiedDate = child.lastModifiedDate;
            newLinkedFile.totalBytes = child.totalBytes;
            newLinkedFile.availability = Downloadable;
            
            [self addedOrUpdatedLinkedFile:newLinkedFile newContents:NO];
            
            [_linkedFilesToDownload addObject:newLinkedFile];
            
            //NSLog(@"Added Linked File: %@", newLinkedFile.path);
            
            [newLinkedFile release];
        }
    }
    
    [_linkedFileDirectoriesToFetch removeObjectAtIndex:0];
    
    [self fetchNextLinkedFileDirectory];
}

- (void)startOrContinueLinkedFileDownload {

    if ([_linkedFilesToDownload count]) {
        
        BDSKExternalLinkedFile *linkedFile = [_linkedFilesToDownload objectAtIndex:0];
        NSString *localPath = [self localPathForLinkedFilePath:linkedFile.path];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error;
        BOOL success = [fileManager createDirectoryAtPath:[localPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
        if (success) {
            [_restClient loadFile:[self dropboxPathForLinkedFilePath:linkedFile.path] intoPath:localPath];
            NSLog(@"Downloading LinkedFile: %@", linkedFile.path);
            [self setSyncStage:linkedFileDownload];
        } else {
            NSLog(@"Error Creating LinkedFile Intermediate Directory: %@", [error localizedDescription]);
            [self setSyncStage:none];
        }
    
    } else {
    
        [self setSyncStage:none];
    }
}

- (void)processLinkedFileDownload:(NSString *)destPath {

    BDSKExternalLinkedFile *linkedFile = [_linkedFilesToDownload objectAtIndex:0];
    
    if (![destPath isEqualToString:[self localPathForLinkedFilePath:linkedFile.path]]) {
    
        NSLog(@"Destination Path: %@ does not match Expected Path: %@", destPath, [self localPathForLinkedFilePath:linkedFile.path]);
        [self setSyncStage:none];
        return;
    }
    
    NSLog(@"Downloaded LinkedFile: %@", linkedFile.path);
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:linkedFile.lastModifiedDate forKey:NSFileModificationDate];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    //NSLog(@"Setting File Modification Date: %@", linkedFile.lastModifiedDate);
    [fileManager setAttributes:attributes ofItemAtPath:[self localPathForLinkedFilePath:linkedFile.path] error:&error];
    if (error) {
        NSLog(@"Set Attributes Failed: %@", [error localizedDescription]);
    }
    linkedFile.availability = Available;
    
    [self addedOrUpdatedLinkedFile:linkedFile newContents:YES];
    
    [_linkedFilesToDownload removeObjectAtIndex:0];
    
    [self startOrContinueLinkedFileDownload];
}

@end

//
//  BDSKFileStore.m
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

#import "BDSKFileStore.h"

#import "BDSKDropboxStore.h"
#import "BibDocument.h"
#import "BDSKBibFile.h"
#import "BDSKExternalLinkedFile.h"

@interface BDSKFileStore () {

    NSMutableDictionary *_bibFiles;
    NSMutableArray *_bibFileNames;
    NSMutableDictionary *_linkedFiles;
    NSMutableArray *_linkedFilePaths;
}

@end

@implementation BDSKFileStore

+ (BDSKFileStore *)fileStoreForName:(NSString *)storeName {

    if ([storeName isEqualToString:[BDSKDropboxStore storeName]]) {
        return [BDSKDropboxStore sharedStore];
    }
    
    return nil;
}

+ (NSString *)storeName {

    return nil;
}

- (BDSKFileStore *)init {

    if (self = [super init]) {
    
        _bibFiles = [[NSMutableDictionary alloc] init];
        _bibFileNames = [[NSMutableArray alloc] init];
        _linkedFiles = [[NSMutableDictionary alloc] init];
        _linkedFilePaths = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)dealloc {

    [_bibFiles release];
    [_bibFileNames release];
    [_linkedFiles release];
    [_linkedFilePaths release];
    
    [super dealloc];
}

- (NSArray *)bibFileNames {

    return _bibFileNames;
}

- (NSArray *)linkedFilePaths {

    return _linkedFilePaths;
}

- (BibDocument *)bibDocumentForName:(NSString *)bibFileName {

    BDSKBibFile *bibFile = [_bibFiles objectForKey:bibFileName];

    return bibFile.bibDocument;
}

- (BDSKLinkedFileAvailability)availabilityForLinkedFilePath:(NSString *)path {

    BDSKExternalLinkedFile *linkedFile = [self.linkedFiles objectForKey:path];
    
    if (linkedFile) return linkedFile.availability;

    return NotAvailable;
}

- (NSString *)localPathForBibFilePath:(NSString *)path {

    return nil;
}

- (NSString *)localPathForLinkedFilePath:(NSString *)path {

    return nil;
}

- (NSString *)pathForLinkedFilePath:(NSString *)relativePath relativeToBibFileName:(NSString *)bibFileName {

    return nil;
}

- (NSDictionary *)bibFiles {

    return _bibFiles;
}

- (NSDictionary *)linkedFiles {

    return _linkedFiles;
}

#pragma mark - bibFileNames KVC/KVO Support

- (void)insertObject:(id)anObject inBibFileNamesAtIndex:(NSUInteger)index {

    [_bibFileNames insertObject:anObject atIndex:index];
}

- (void)removeObjectFromBibFileNamesAtIndex:(NSUInteger)index {

    [_bibFileNames removeObjectAtIndex:index];
}

- (void)insertBibFileName:(NSString *)name {

    NSComparator comparator = ^(NSString *obj1, NSString *obj2) { return [obj1 caseInsensitiveCompare:obj2]; };
    
    NSUInteger index = [_bibFileNames indexOfObject:name
                                      inSortedRange:(NSRange){0, [_bibFileNames count]}
                                            options:NSBinarySearchingInsertionIndex
                                    usingComparator:comparator];

    [self insertObject:name inBibFileNamesAtIndex:index];
}

- (void)removeBibFileName:(NSString *)name {

    NSComparator comparator = ^(NSString *obj1, NSString *obj2) { return [obj1 caseInsensitiveCompare:obj2]; };
    
    NSUInteger index = [_bibFileNames indexOfObject:name
                                      inSortedRange:(NSRange){0, [_bibFileNames count]}
                                            options:NSBinarySearchingFirstEqual
                                    usingComparator:comparator];

    [self removeObjectFromBibFileNamesAtIndex:index];
}

#pragma mark - linkedFilePaths KVC/KVO Support

- (void)insertObject:(id)anObject inLinkedFilePathsAtIndex:(NSUInteger)index {

    [_linkedFilePaths insertObject:anObject atIndex:index];
}

- (void)removeObjectFromLinkedFilePathsAtIndex:(NSUInteger)index {

    [_linkedFilePaths removeObjectAtIndex:index];
}

- (void)insertLinkedFilePath:(NSString *)name {

    NSComparator comparator = ^(NSString *obj1, NSString *obj2) { return [obj1 caseInsensitiveCompare:obj2]; };
    
    NSUInteger index = [_linkedFilePaths indexOfObject:name
                                      inSortedRange:(NSRange){0, [_linkedFilePaths count]}
                                            options:NSBinarySearchingInsertionIndex
                                    usingComparator:comparator];

    [self insertObject:name inLinkedFilePathsAtIndex:index];
}

- (void)removeLinkedFilePath:(NSString *)name {

    NSComparator comparator = ^(NSString *obj1, NSString *obj2) { return [obj1 caseInsensitiveCompare:obj2]; };
    
    NSUInteger index = [_linkedFilePaths indexOfObject:name
                                      inSortedRange:(NSRange){0, [_linkedFilePaths count]}
                                            options:NSBinarySearchingFirstEqual
                                    usingComparator:comparator];

    [self removeObjectFromLinkedFilePathsAtIndex:index];
}

#pragma mark - NSNotificationCenter Support

- (void)notifyBibDocumentChanged:(NSString *)bibFileName {

    [[NSNotificationCenter defaultCenter] postNotificationName:@"BDSKBibDocumentChanged" object:self userInfo:@{ @"bibFileName": bibFileName }];
}


- (void)notifyLinkedFileChanged:(NSString *)linkedFilePath newContents:(BOOL)newContents {

    [[NSNotificationCenter defaultCenter] postNotificationName:@"BDSKLinkedFileChanged" object:self userInfo:@{ @"linkedFilePath": linkedFilePath, @"newContents": [NSNumber numberWithBool:newContents] }];
}

#pragma mark - Subclass Support

- (void)addedOrUpdatedBibFile:(BDSKBibFile *)bibFile {

    BDSKBibFile *existingFile = [_bibFiles valueForKey:bibFile.path];
    NSDate *startOpenDate = [NSDate date];
    
    if (existingFile) {
    
        existingFile.lastModifiedDate = bibFile.lastModifiedDate;
        existingFile.totalBytes = bibFile.totalBytes;
        if (existingFile.bibDocument && existingFile.bibDocument.documentState != UIDocumentStateClosed) {
            [existingFile.bibDocument revertToContentsOfURL:existingFile.bibDocument.fileURL completionHandler:^(BOOL success) {
                NSTimeInterval openingTime = -[startOpenDate timeIntervalSinceNow];
                NSLog(@"Reverted %@ in %f seconds", bibFile.path, openingTime);
                [self notifyBibDocumentChanged:bibFile.path];
            }];
        } else {
            [existingFile.bibDocument openWithCompletionHandler:^(BOOL success) {
                NSTimeInterval openingTime = -[startOpenDate timeIntervalSinceNow];
                NSLog(@"Opened %@ in %f seconds", bibFile.path, openingTime);
                [self notifyBibDocumentChanged:bibFile.path];
            }];
        }
        
    } else {
    
        BibDocument *bibDocument = [[BibDocument alloc] initWithFileURL:[NSURL fileURLWithPath:[self localPathForBibFilePath:bibFile.path]]];
        bibFile.bibDocument = bibDocument;
        [bibDocument release];
        [bibDocument openWithCompletionHandler:^(BOOL success) {
            NSTimeInterval openingTime = -[startOpenDate timeIntervalSinceNow];
            NSLog(@"Opened %@ in %f seconds", bibFile.path, openingTime);
            [self notifyBibDocumentChanged:bibFile.path];
        }];
        [_bibFiles setValue:bibFile forKey:bibFile.path];
        [self insertBibFileName:bibFile.path];
    }
}

- (void)removedBibFile:(BDSKBibFile *)bibFile {

    [_bibFiles removeObjectForKey:bibFile.path];
    [self removeBibFileName:bibFile.path];
    [self notifyBibDocumentChanged:bibFile.path];
}

- (void)addedOrUpdatedLinkedFile:(BDSKExternalLinkedFile *)linkedFile newContents:(BOOL)newContents {

    BDSKExternalLinkedFile *existingFile = [_linkedFiles valueForKey:linkedFile.path];

    if (existingFile) {
    
        existingFile.lastModifiedDate = linkedFile.lastModifiedDate;
        existingFile.totalBytes = linkedFile.totalBytes;
        existingFile.availability = linkedFile.availability;
    
    } else {
    
        [_linkedFiles setValue:linkedFile forKey:linkedFile.path];
        [self insertLinkedFilePath:linkedFile.path];
    }
    [self notifyLinkedFileChanged:linkedFile.path newContents:newContents];
}

- (void)removedLinkedFile:(BDSKExternalLinkedFile *)linkedFile {

    [_linkedFiles removeObjectForKey:linkedFile.path];
    [self removeLinkedFilePath:linkedFile.path];
    [self notifyLinkedFileChanged:linkedFile.path newContents:YES];
}

@end

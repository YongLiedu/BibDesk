//
//  BDSKFileStore.h
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

#import <Foundation/Foundation.h>

#import "BDSKExternalLinkedFile.h"

@class BibDocument;
@class BDSKBibFile;
@class BDSKExternalLinkedFile;

@interface BDSKFileStore : NSObject

@property (readonly) NSArray *bibFileNames;
@property (readonly) NSArray *linkedFilePaths;

+ (BDSKFileStore *)fileStoreForName:(NSString *)storeName;

- (BibDocument *)bibDocumentForName:(NSString *)bibFileName;
- (BDSKLinkedFileAvailability)availabilityForLinkedFilePath:(NSString *)path;

// properties and methods subclasses must override
+ (NSString *)storeName;

- (NSString *)localPathForBibFilePath:(NSString *)path;
- (NSString *)localPathForLinkedFilePath:(NSString *)path;
- (NSURL *)urlForLinkedFilePath:(NSString *)path;
- (NSString *)pathForLinkedFilePath:(NSString *)relativePath relativeToBibFileName:(NSString *)bibFileName;

// only for access by subclasses
@property (readonly) NSDictionary *bibFiles;
@property (readonly) NSDictionary *linkedFiles;

- (void)addedOrUpdatedBibFile:(BDSKBibFile *)bibFile;
- (void)removedBibFile:(BDSKBibFile *)bibFile;

- (void)addedOrUpdatedLinkedFile:(BDSKExternalLinkedFile *)linkedFile newContents:(BOOL)newContents;
- (void)removedLinkedFile:(BDSKExternalLinkedFile *)linkedFile;

@end

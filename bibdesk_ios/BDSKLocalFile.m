//
//  BDSKLocalFile.m
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

#import "BDSKLocalFile.h"


static NSString *documentsRoot = nil;
static NSString *dropboxRoot = nil;

@interface BDSKLocalFile ()

@end

@implementation BDSKLocalFile

@synthesize path;
@synthesize lastModifiedDate;
@synthesize totalBytes;

+ (void)initialize {

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
    
    [BDSKLocalFile setDocumentsRoot:documentsPath];
    
    NSLog(@"Documents Root: %@", documentsPath);
    
    [BDSKLocalFile setDropboxRoot:@""];
}

+ (NSString *)documentsRoot {

    return documentsRoot;
}

+ (void)setDocumentsRoot:(NSString *)root {

    [root retain];
    [documentsRoot release];
    documentsRoot = root;    
}

+ (NSString *)dropboxRoot {

    return dropboxRoot;
}

+ (void)setDropboxRoot:(NSString *)root {

    [root retain];
    [dropboxRoot release];
    dropboxRoot = root;    
}

- (id)initWithFullPath:(NSString *)fullPath {

    if (self = [super init]) {
    
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:&error];
        if (error) {
            NSLog(@"Error Getting Attributes: %@", [error localizedDescription]);
            [self release];
            self = nil;
        } else {
            NSUInteger rootLength = documentsRoot ? [documentsRoot length] : 0;
            self.path = [fullPath substringFromIndex:rootLength];
            self.totalBytes = [(NSNumber *)[attributes objectForKey:NSFileSize] longLongValue];
            self.lastModifiedDate = (NSDate *)[attributes objectForKey:NSFileModificationDate];
        }
    }
    
    return self;
}

- (id)initWithDropboxPath:(NSString *)dropboxPath lastModifiedDate:(NSDate *)date totalByets:(long long)bytes {

    if (self = [super init]) {
    
        NSUInteger dropboxLength = dropboxRoot ? [dropboxRoot length] : 0;
        self.path = [dropboxPath substringFromIndex:dropboxLength];
        self.lastModifiedDate = date;
        self.totalBytes = bytes;
    }
    
    return self;
}

- (void)updateWithRevisedFile:(BDSKLocalFile *)revisedFile {

    self.lastModifiedDate = revisedFile.lastModifiedDate;
    self.totalBytes = revisedFile.totalBytes;
}

- (NSString *)fullPath {

    if (documentsRoot) return [documentsRoot stringByAppendingString:path];

    return path;
}

- (NSString *)dropboxPath {

    if (dropboxRoot) return [dropboxRoot stringByAppendingString:path];

    return path;
}

- (NSString *)name {

    return [self.path lastPathComponent];
}

- (NSString *)nameNoExtension {

    return [[self.path lastPathComponent] stringByDeletingPathExtension];
}

- (NSString *)pathWithoutLeadingSlash {

    if ([self.path hasPrefix:@"/"]) {
        return [self.path substringFromIndex:1];
    }
    
    return self.path;
}

@end

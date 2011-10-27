//
//  BDSKLinkedFile.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/12/07.
/*
 This software is Copyright (c) 2007-2011
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

#import <Cocoa/Cocoa.h>

@class BDSKLinkedFile;

@protocol BDSKLinkedFileDelegate <NSObject>
- (NSString *)basePathForLinkedFile:(BDSKLinkedFile *)file;
- (void)linkedFileURLChanged:(BDSKLinkedFile *)file;
@end


@interface BDSKLinkedFile : NSObject <NSCopying, NSCoding>

- (NSURL *)URL;

// string value to be saved as a field value, base64 encoded data for a local file or an absolute URL string for a remote URL
- (NSString *)stringRelativeToPath:(NSString *)newBasePath;

@end


@interface BDSKLinkedFile (BDSKExtendedLinkedFile)

- (BOOL)isFile;

- (NSURL *)displayURL;
- (NSString *)path;

- (NSString *)stringValue;
- (NSString *)bibTeXString;

// the rest is only relevant for local files, but it's safe to call for any linked file object

- (NSString *)relativePath;

- (void)setDelegate:(id<BDSKLinkedFileDelegate>)aDelegate;
- (id<BDSKLinkedFileDelegate>)delegate;

- (void)update;
- (void)updateWithPath:(NSString *)aPath;

@end


@interface BDSKLinkedFile (BDSKLinkedFileCreation)

+ (id)linkedFileWithURL:(NSURL *)aURL delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
+ (id)linkedFileWithBase64String:(NSString *)base64String delegate:(id)aDelegate;
+ (id)linkedFileWithURLString:(NSString *)aString;

// creates a linked local file or remote URL object depending on the URL
- (id)initWithURL:(NSURL *)aURL delegate:(id<BDSKLinkedFileDelegate>)aDelegate;
// creates a linked local file
- (id)initWithBase64String:(NSString *)base64String delegate:(id)aDelegate;
// creates a linked remote URL
- (id)initWithURLString:(NSString *)aString;

@end

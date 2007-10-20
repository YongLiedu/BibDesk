//
//  BDSKFile.h
//  Bibdesk
//
//  Created by Adam Maxwell on 08/17/06.
/*
 This software is Copyright (c) 2006,2007
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

#import <Cocoa/Cocoa.h>

@class BDAlias;

@interface BDSKFile : NSObject <NSCopying, NSCoding>

- (id)initWithFSRef:(FSRef *)aRef;
- (id)initWithPath:(NSString *)aPath;
- (id)initWithURL:(NSURL *)aURL;
+ (id)fileWithURL:(NSURL *)aURL;

- (NSURL *)fileURL;
- (const FSRef *)fsRef;
- (NSString *)fileName;

- (NSString *)path;
- (NSString *)tildePath;

@end


@interface BDSKAliasFile : NSObject <NSCopying, NSCoding>
{
    BDAlias *alias;
    const FSRef *fileRef;
}

- (id)initWithAlias:(BDAlias *)anAlias;
- (id)initWithData:(NSData *)data;
- (id)initWithBase64String:(NSString *)base64String;
- (id)initWithPath:(NSString *)aPath relativeToPath:(NSString *)basePath;
- (id)initWithPath:(NSURL *)aURL relativeToURL:(NSURL *)baseURL;

- (const FSRef *)fsRefRelativeToToURL:(NSString *)baseURL update:(BOOL)update;
- (const FSRef *)fsRefRelativeToToURL:(NSString *)baseURL;
- (const FSRef *)fsRef;

- (NSURL *)fileURLRelativeToURL:(NSURL *)baseURL;
- (NSURL *)fileURLRelativeToURLNoUpdate:(NSURL *)baseURL;
- (NSURL *)fileURL;

- (NSString *)pathRelativeToPath:(NSString *)basePath;
- (NSString *)pathRelativeToPathNoUpdate:(NSString *)basePath;
- (NSString *)path;

- (BDAlias *)aliasRelativeToPath:(NSString *)basePath;
- (NSData *)aliasDataRelativeToPath:(NSString *)basePath;
- (NSString *)base64StringRelativeToPath:(NSString *)basePath;

@end

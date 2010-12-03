//
//  NSError_BDSKExtensions.h
//  Bibdesk
//
//  Created by Adam Maxwell on 10/15/06.
/*
 This software is Copyright (c) 2006-2010
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

// If we declare all the errors in one place, we can be sure the codes don't overlap.
// This is the recommended way to check an NSError to see if it's a type we can handle.
// Apple reserves codes < 0 for their own use (I think...)
// Omni's OFError is handy, but makes it difficult to check an error code or domain.

enum {
    kBDSKUnknownError = coreFoundationUnknownErr, /* -4960 */
    kBDSKDocumentSaveError = 1,                   /* umbrella error type for document saving */
    kBDSKStringEncodingError,                     /* unable to convert to desired encoding   */
    kBDSKPropertyListDeserializationFailed,       /* NSPropertyListSerialization failed      */
    kBDSKPropertyListSerializationFailed,         /* NSPropertyListSerialization failed      */
    kBDSKNetworkConnectionFailed,                 /* Unable to connect to a network          */
    kBDSKFileNotFound,                            /* File not found (should have URL/path)   */
    kBDSKAppleScriptError,                        /* AppleScript failed                      */
    kBDSKParserIgnoredFrontMatter,                /* BDSKBibTeXParser ignored front matter   */
    kBDSKParserFailed,                            /* Some parser failed for some reason      */
    kBDSKParserUnsupported,                       /* No valid parser for string              */
    kBDSKWebParserFailed,                         /* Some web parser failed for some reason  */
    kBDSKWebParserUnsupported,                    /* No valid web parser for URL             */
    kBDSKFileOperationFailed,                     /* Generic file operation failure          */
    kBDSKURLOperationFailed,                      /* Generic URL operation failure           */
    kBDSKComplexStringError,                      /* Complex string parsing failed           */
    kBDSKCannotFindTemporaryDirectoryError,       /* Cannot find temporary directory         */
    kBDSKCannotCreateTemporaryFileError,          /* Cannot create a temporary file          */
    kBDSKDocumentOpenError,                       /* umbrella error type for document open   */
};

extern NSString *BDSKUnderlyingItemErrorKey;

@interface NSError (BDSKExtensions) <NSMutableCopying>

// returns the BibDesk-specific error domain
+ (NSString *)localErrorDomain;

// returns BibDesk-specific errors that don't allow valueForKey: and setValue:forKey: usage
+ (id)localErrorWithCode:(NSInteger)code localizedDescription:(NSString *)description;
+ (id)localErrorWithCode:(NSInteger)code localizedDescription:(NSString *)description underlyingError:(NSError *)underlyingError;

// returns BibDesk-specific errors that can allow valueForKey: and setValue:forKey: usage
+ (id)mutableErrorWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(NSDictionary *)dict;
+ (id)mutableLocalErrorWithCode:(NSInteger)code localizedDescription:(NSString *)description;
+ (id)mutableLocalErrorWithCode:(NSInteger)code localizedDescription:(NSString *)description underlyingError:(NSError *)underlyingError;

// see if it has our local domain
- (BOOL)isLocalError;

// embed an underlying error; if this isn't a mutable subclass, raises an exception
- (void)embedError:(NSError *)underlyingError;
- (void)setCode:(NSInteger)code;

@end

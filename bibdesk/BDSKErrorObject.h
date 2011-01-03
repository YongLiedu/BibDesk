//
//  BDSKErrorObject.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/26/06.
/*
 This software is Copyright (c) 2005-2011
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

#import <Foundation/Foundation.h>

@class BDSKErrorEditor, BibItem;

@interface BDSKErrorObject : NSObject {
	BDSKErrorEditor *editor;
	BibItem *publication;
    
    NSString *fileName;
    NSInteger lineNumber;
    
    NSString *errorClassName;
    NSString *errorMessage;
    BOOL isIgnorableWarning;
}

+ (void)reportError:(NSString *)className message:(NSString *)msg forFile:(NSString *)filePath line:(NSInteger)line isWarning:(BOOL)flag;
+ (void)reportErrorMessage:(NSString *)msg forFile:(NSString *)filePath line:(NSInteger)line;

- (NSString *)fileName;
- (void)setFileName:(NSString *)newFileName;

- (BDSKErrorEditor *)editor;
- (void)setEditor:(BDSKErrorEditor *)newEditor;

- (BibItem *)publication;
- (void)setPublication:(BibItem *)newPublication;

- (NSInteger)lineNumber;
- (void)setLineNumber:(NSInteger)newLineNumber;

- (NSString *)errorClassName;
- (void)setErrorClassName:(NSString *)newErrorClassName;

- (NSString *)errorMessage;
- (void)setErrorMessage:(NSString *)newErrorMessage;

- (void)setIgnorableWarning:(BOOL)flag;
- (BOOL)isIgnorableWarning;

@end

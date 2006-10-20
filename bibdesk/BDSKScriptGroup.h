//
//  BDSKScriptGroup.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/19/06.
/*
 This software is Copyright (c) 2006
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
#import "BDSKGroup.h"

@class OFMessageQueue;

enum {
    BDSKShellScriptType,
    BDSKAppleScriptType
};

@interface BDSKScriptGroup : BDSKGroup {
    NSArray *publications;
    NSString *scriptPath;
    NSArray *scriptArguments;
    int scriptType;
	NSUndoManager *undoManager;
    BOOL isRetrieving;
    BOOL failedDownload;
    OFMessageQueue *messageQueue;
}

- (id)initWithName:(NSString *)aName scriptPath:(NSString *)path scriptArguments:(NSArray *)arguments scriptType:(int)type;

- (void)setName:(NSString *)newName;

- (NSArray *)publications;
- (void)setPublications:(NSArray *)newPubs;

- (NSString *)scriptPath;
- (void)setScriptPath:(NSString *)newPath;

- (NSArray *)scriptArguments;
- (void)setScriptArguments:(NSArray *)newArguments;

- (int)scriptType;
- (void)setScriptType:(int)newType;

- (NSUndoManager *)undoManager;
- (void)setUndoManager:(NSUndoManager *)newUndoManager;

- (void)startRunningScript;
- (void)scriptDidFinishWithResult:(NSString *)outputString;
- (void)scriptDidFailWithError:(NSError *)error;
- (void)runScriptAtPath:(NSString *)path ofType:(NSNumber *)type withArguments:(NSArray *)args;

@end

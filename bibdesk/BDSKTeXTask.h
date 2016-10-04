//
//  BDSKTeXTask.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 6/8/05.
//
/*
 This software is Copyright (c) 2005-2016
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

enum {
	BDSKGenerateLTB = 0,
	BDSKGenerateLaTeX = 1,
	BDSKGeneratePDF = 2,
};

@class BDSKTeXTask;

@protocol BDSKTeXTaskDelegate <NSObject>
@optional
- (BOOL)texTaskShouldStartRunning:(BDSKTeXTask *)texTask;
- (void)texTask:(BDSKTeXTask *)texTask finishedWithResult:(BOOL)success;
@end

@class BDSKTeXPath, BDSKTaskAndGeneratedType;

@interface BDSKTeXTask : NSObject {	
    NSString *texTemplatePath;
    BDSKTeXPath *texPath;
    NSSet *binDirPaths;
    NSMutableDictionary *environment;
	
	id<BDSKTeXTaskDelegate> delegate;
    
    BDSKTaskAndGeneratedType *currentTask;
    
    NSMutableArray *pendingTasks;
    
    NSUInteger generatedDataMask;
    
	BOOL synchronous;
}

- (id)init;
- (id)initWithFileName:(NSString *)fileName synchronous:(BOOL)isSync;

- (id<BDSKTeXTaskDelegate>)delegate;
- (void)setDelegate:(id<BDSKTeXTaskDelegate>)newDelegate;

- (BOOL)runWithBibTeXString:(NSString *)bibStr citeKeys:(NSArray *)citeKeys generatedTypes:(NSInteger)flag;

- (void)cancel;
- (void)terminate;

- (NSString *)logFileString;
- (NSString *)LTBString;
- (NSString *)LaTeXString;
- (NSData *)PDFData;

- (NSString *)logFilePath;
- (NSString *)LTBFilePath;
- (NSString *)LaTeXFilePath;
- (NSString *)PDFFilePath;

- (BOOL)hasLTB;
- (BOOL)hasLaTeX;
- (BOOL)hasPDFData;

- (BOOL)isProcessing;

@end

//
//  BDSKTeXTask.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 6/8/05.
//
/*
 This software is Copyright (c) 2005-2012
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
	BDSKGenerateRTF = 3,
};

typedef struct _BDSKTeXTaskFlags {
    volatile int32_t hasLTB;
    volatile int32_t hasLaTeX;
    volatile int32_t hasPDFData;
    volatile int32_t hasRTFData;
} BDSKTeXTaskFlags;

@class BDSKTeXTask;

@protocol BDSKTeXTaskDelegate <NSObject>
@optional
- (BOOL)texTaskShouldStartRunning:(BDSKTeXTask *)texTask;
- (void)texTask:(BDSKTeXTask *)texTask finishedWithResult:(BOOL)success;
@end

@class BDSKTeXPath, BDSKTask, BDSKReadWriteLock;

@interface BDSKTeXTask : NSObject {	
    NSString *texTemplatePath;
    BDSKTeXPath *texPath;
    NSString *binDirPath;
	
	id<BDSKTeXTaskDelegate> delegate;
    NSInvocation *taskShouldStartInvocation;
    NSInvocation *taskFinishedInvocation;
    BDSKTask *currentTask;
	
    BDSKTeXTaskFlags flags;

    NSLock *processingLock;    
    BDSKReadWriteLock *dataFileLock;
}

- (id)init;
- (id)initWithFileName:(NSString *)fileName;

- (id<BDSKTeXTaskDelegate>)delegate;
- (void)setDelegate:(id<BDSKTeXTaskDelegate>)newDelegate;

// the next few methods are thread-unsafe

- (BOOL)runWithBibTeXString:(NSString *)bibStr;
- (BOOL)runWithBibTeXString:(NSString *)bibStr citeKeys:(NSArray *)citeKeys;
- (BOOL)runWithBibTeXString:(NSString *)bibStr generatedTypes:(NSInteger)flag;
- (BOOL)runWithBibTeXString:(NSString *)bibStr citeKeys:(NSArray *)citeKeys generatedTypes:(NSInteger)flag;

- (void)terminate;

// these methods are thread-safe

- (NSString *)logFileString;
- (NSString *)LTBString;
- (NSString *)LaTeXString;
- (NSData *)PDFData;
- (NSData *)RTFData;

- (NSString *)logFilePath;
- (NSString *)LTBFilePath;
- (NSString *)LaTeXFilePath;
- (NSString *)PDFFilePath;
- (NSString *)RTFFilePath;

- (BOOL)hasLTB;
- (BOOL)hasLaTeX;
- (BOOL)hasPDFData;
- (BOOL)hasRTFData;

- (BOOL)isProcessing;

@end

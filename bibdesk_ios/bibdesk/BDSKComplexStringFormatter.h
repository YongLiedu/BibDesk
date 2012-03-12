//  BDSKComplexStringFormatter.h

//  Created by Michael McCracken on Mon Jul 22 2002.
/*
 This software is Copyright (c) 2002-2012
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

@class BDSKComplexStringFormatter;

@protocol BDSKComplexStringFormatterDelegate <NSObject>
@optional
- (BOOL)formatter:(BDSKComplexStringFormatter *)formatter shouldEditAsComplexString:(NSString *)object;
@end

@class BDSKMacroResolver;

@interface BDSKComplexStringFormatter : NSFormatter {
	id macroResolver;
	BOOL editAsComplexString;
	id<BDSKComplexStringFormatterDelegate> delegate;
}

- (id)initWithDelegate:(id<BDSKComplexStringFormatterDelegate>)anObject macroResolver:(BDSKMacroResolver *)aMacroResolver;

- (id)macroResolver;
- (void)setMacroResolver:(BDSKMacroResolver *)newMacroResolver;

- (BOOL)editAsComplexString;
- (void)setEditAsComplexString:(BOOL)newEditAsComplexString;

- (id<BDSKComplexStringFormatterDelegate>)delegate;
- (void)setDelegate:(id<BDSKComplexStringFormatterDelegate>)newDelegate;

@end
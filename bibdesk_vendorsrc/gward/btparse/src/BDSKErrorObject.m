//
//  BDSKErrorObject.m
//  BTParse
//
//  Created by Christiaan Hofman on 8/26/06.
/*
 This software is Copyright (c) 2005,2006
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
//

#import "BDSKErrorObject.h"

NSString *BDSKParserErrorNotification = @"BDSKParserErrorNotification";
NSString *BDSKParserHarmlessWarningString = @"harmless";
NSString *BDSKParserWarningString = @"warning";

@implementation BDSKErrorObject

- (void)dealloc {
    [fileName release];
    [editor release];
    [errorClassName release];
    [errorMessage release];
    [super dealloc];
}

- (NSString *)description{
    return [NSString stringWithFormat:@"File name: %@, Editor: %@, line number: %d \n\t item: %@, error class: %@, error message: %@", fileName, editor, lineNumber, itemDescription, errorClassName, errorMessage];
}

- (NSString *)fileName {
    return [[fileName retain] autorelease];
}

- (void)setFileName:(NSString *)newFileName {
    if (fileName != newFileName) {
        [fileName release];
        fileName = [newFileName copy];
    }
}

- (id)editor {
    return [[editor retain] autorelease];
}

- (void)setEditor:(id)newEditor {
    if (editor != newEditor) {
        [editor release];
        editor = [newEditor retain];
    }
}

- (int)lineNumber {
    return lineNumber;
}

- (void)setLineNumber:(int)newLineNumber {
    if (lineNumber != newLineNumber) {
        lineNumber = newLineNumber;
    }
}

- (NSString *)itemDescription {
    return [[itemDescription retain] autorelease];
}

- (void)setItemDescription:(NSString *)newItemDescription {
    if (itemDescription != newItemDescription) {
        [itemDescription release];
        itemDescription = [newItemDescription copy];
    }
}

- (int)itemNumber {
    return itemNumber;
}

- (void)setItemNumber:(int)newItemNumber {
    if (itemNumber != newItemNumber) {
        itemNumber = newItemNumber;
    }
}

- (NSString *)errorClassName {
    return [[errorClassName retain] autorelease];
}

- (void)setErrorClassName:(NSString *)newErrorClassName {
    if (errorClassName != newErrorClassName) {
        [errorClassName release];
        errorClassName = [newErrorClassName copy];
    }
}

- (NSString *)errorMessage {
    return [[errorMessage retain] autorelease];
}

- (void)setErrorMessage:(NSString *)newErrorMessage {
    if (errorMessage != newErrorMessage) {
        [errorMessage release];
        errorMessage = [newErrorMessage copy];
    }
}

- (void)report {
   [[NSNotificationCenter defaultCenter] postNotificationName:BDSKParserErrorNotification object:self];
}

@end

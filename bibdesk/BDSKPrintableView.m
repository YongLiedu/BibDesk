//
//  BDSKPrintableView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/14/08.
/*
 This software is Copyright (c) 2008-2009
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

#import "BDSKPrintableView.h"


@implementation BDSKPrintableView

- (id)initWithAttributedString:(NSAttributedString *)attributedString printInfo:(NSPrintInfo *)printInfo {
    if (self = [self initWithFrame:[(printInfo ?: [NSPrintInfo sharedPrintInfo]) imageablePageBounds]]) {
        [self setVerticallyResizable:YES];
        [self setHorizontallyResizable:NO];
        if (attributedString) {
            [[self textStorage] beginEditing];
            [[self textStorage] setAttributedString:attributedString];
            [[self textStorage] endEditing];
        }
    }
    return self;
}

- (id)initWithString:(NSString *)string color:(NSColor *)color printInfo:(NSPrintInfo *)printInfo {
    if (self = [self initWithFrame:[(printInfo ?: [NSPrintInfo sharedPrintInfo]) imageablePageBounds]]) {
        [self setVerticallyResizable:YES];
        [self setHorizontallyResizable:NO];
        if (string || color) {
            [[self textStorage] beginEditing];
            [[[self textStorage] mutableString] setString:string];
            if (string)
                [[self textStorage] addAttribute:NSFontAttributeName value:[NSFont userFontOfSize:0.0] range:NSMakeRange(0, [[self textStorage] length])];
            if (color)
                [[self textStorage] addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, [[self textStorage] length])];
            [[self textStorage] endEditing];
        }
    }
    return self;
}

- (id)initWithString:(NSString *)string printInfo:(NSPrintInfo *)printInfo {
    return [self initWithString:string color:nil printInfo:printInfo];
}

- (BOOL)knowsPageRange:(NSRangePointer)range {
    NSPrintInfo *info = [[NSPrintOperation currentOperation] printInfo];
    if (info) {
        [self setFrame:NSZeroRect];
        [self setFrame:[info imageablePageBounds]];
    }
    return [super knowsPageRange:range];
}

@end


@implementation NSPrintOperation (BDSKPrintableView)

+ (NSPrintOperation *)printOperationWithAttributedString:(NSAttributedString *)attributedString printInfo:(NSPrintInfo *)printInfo settings:(NSDictionary *)printSettings {
    NSPrintInfo *info = [(printInfo ?: [NSPrintInfo sharedPrintInfo]) copy];
    [[info dictionary] addEntriesFromDictionary:printSettings];
    [info setHorizontalPagination:NSFitPagination];
    [info setHorizontallyCentered:NO];
    [info setVerticallyCentered:NO];
    
    NSTextView *printableView = [[BDSKPrintableView alloc] initWithAttributedString:attributedString printInfo:info];
    NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:printableView printInfo:info];
    [printableView release];
    [info release];
    
    NSPrintPanel *printPanel = [printOperation printPanel];
    [printPanel setOptions:NSPrintPanelShowsCopies | NSPrintPanelShowsPageRange | NSPrintPanelShowsPaperSize | NSPrintPanelShowsOrientation | NSPrintPanelShowsScaling | NSPrintPanelShowsPreview];
    
    return printOperation;
}

+ (NSPrintOperation *)printOperationWithString:(NSString *)string printInfo:(NSPrintInfo *)printInfo settings:(NSDictionary *)printSettings {
    NSPrintInfo *info = [(printInfo ?: [NSPrintInfo sharedPrintInfo]) copy];
    [[info dictionary] addEntriesFromDictionary:printSettings];
    [info setHorizontalPagination:NSFitPagination];
    [info setHorizontallyCentered:NO];
    [info setVerticallyCentered:NO];
    
    NSTextView *printableView = [[BDSKPrintableView alloc] initWithString:string printInfo:info];
    NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:printableView printInfo:info];
    [printableView release];
    [info release];
    
    NSPrintPanel *printPanel = [printOperation printPanel];
    [printPanel setOptions:NSPrintPanelShowsCopies | NSPrintPanelShowsPageRange | NSPrintPanelShowsPaperSize | NSPrintPanelShowsOrientation | NSPrintPanelShowsScaling | NSPrintPanelShowsPreview];
    
    return printOperation;
}

@end


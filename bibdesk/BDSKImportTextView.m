//
//  BDSKImportTextView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 4/29/11.
/*
 This software is Copyright (c) 2011
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

#import "BDSKImportTextView.h"


@implementation BDSKImportTextView

- (IBAction)makePlainText:(id)sender{
    NSTextStorage *textStorage = [self textStorage];
    [textStorage setAttributes:nil range:NSMakeRange(0,[textStorage length])];
}

- (NSMenu *)menuForEvent:(NSEvent *)event{
    NSMenu *menu = [super menuForEvent:event];
    NSInteger i, count = [menu numberOfItems];
    
    for (i = 0; i < count; i++) {
        if ([[menu itemAtIndex:i] action] == @selector(paste:)) {
            [menu insertItemWithTitle:NSLocalizedString(@"Paste as Plain Text", @"Menu item title") action:@selector(pasteAsPlainText:) keyEquivalent:@"" atIndex:i+1];
            break;
        }
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:NSLocalizedString(@"Make Plain Text", @"Menu item title") action:@selector(makePlainText:) keyEquivalent:@""];
    
    return menu;
}

@end

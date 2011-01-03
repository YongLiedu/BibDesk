//
//  BDSKFormatStringFieldEditor.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/19/10.
/*
 This software is Copyright (c) 2010-2011
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

#import "BDSKFormatStringFieldEditor.h"
#import "BDSKFormatParser.h"



@implementation BDSKFormatStringFieldEditor

- (id)initWithFrame:(NSRect)frameRect parseField:(NSString *)field;
{
    // initWithFrame sets up the entire text system for us
    if(self = [super initWithFrame:frameRect]){
        BDSKASSERT(field != nil);
        parseField = [field copy];
    }
    return self;
}

- (void)dealloc
{
    BDSKDESTROY(parseField);
    [super dealloc];
}

- (BOOL)isFieldEditor { return YES; }

- (void)recolorText
{
    NSTextStorage *textStorage = [self textStorage];
    NSUInteger length = [textStorage length];
    
    NSRange range;
    NSDictionary *attributes;
    
    range.length = 0;
    range.location = 0;
	
    // get the attributed string from the format parser
    NSAttributedString *attrString = nil;
    NSString *format = [[[self string] copy] autorelease]; // pass a copy so we don't change the backing store of our text storage
    [BDSKFormatParser validateFormat:&format attributedFormat:&attrString forField:parseField error:NULL];   
    
	if ([[self string] isEqualToString:[attrString string]] == NO) 
		return;
    
    // get the attributes of the parsed string and apply them to our NSTextStorage; it may not be safe to set it directly at this point
    NSUInteger start = 0;
    while(start < length){
        
        attributes = [attrString attributesAtIndex:start effectiveRange:&range];        
        [textStorage setAttributes:attributes range:range];
        
        start += range.length;
    }
}    

// this is a convenient override point that gets called often enough to recolor everything
- (void)setSelectedRange:(NSRange)charRange
{
    [super setSelectedRange:charRange];
    [self recolorText];
}

- (void)didChangeText
{
    [super didChangeText];
    [self recolorText];
}

@end

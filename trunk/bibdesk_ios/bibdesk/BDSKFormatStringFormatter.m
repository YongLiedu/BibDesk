//
//  BDSKFormatStringFormatter.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/19/10.
/*
 This software is Copyright (c) 2010-2012
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

#import "BDSKFormatStringFormatter.h"
#import "BDSKFormatParser.h"


@implementation BDSKFormatStringFormatter

- (id)initWithField:(NSString *)field {
    // initWithFrame sets up the entire text system for us
    if(self = [super init]){
        BDSKASSERT(field != nil);
        parseField = [field retain];
    }
    return self;
}

- (void)dealloc
{
    BDSKDESTROY(parseField);
    [super dealloc];
}

- (NSString *)stringForObjectValue:(id)obj{
    return obj;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary *)attrs{
    NSAttributedString *attrString = nil;
    NSString *format = [[obj copy] autorelease];
    
	[BDSKFormatParser validateFormat:&format attributedFormat:&attrString forField:parseField error:NULL];
    
    return attrString;
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error{
    *obj = string;
    return YES;
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString **)error{
    NSAttributedString *attrString = nil;
    NSString *format = [[*partialStringPtr copy] autorelease];
    NSString *errorString = nil;
    
	[BDSKFormatParser validateFormat:&format attributedFormat:&attrString forField:parseField error:&errorString];
    format = [attrString string];
	
	if (NO == [format isEqualToString:*partialStringPtr]) {
		NSUInteger length = [format length];
		*partialStringPtr = format;
		if ([format isEqualToString:origString]) 
			*proposedSelRangePtr = origSelRange;
		else if (NSMaxRange(*proposedSelRangePtr) > length){
			if ((*proposedSelRangePtr).location <= length)
				*proposedSelRangePtr = NSIntersectionRange(*proposedSelRangePtr, NSMakeRange(0, length));
			else
				*proposedSelRangePtr = NSMakeRange(length, 0);
		}
        if (error) *error = errorString;
		return NO;
	} else return YES;
}


@end

//
//  BDSKCitationFormatter.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/6/07.
/*
 This software is Copyright (c) 2005-2009
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

#import "BDSKCitationFormatter.h"
#import "BDSKTypeManager.h"


@implementation BDSKCitationFormatter

static NSCharacterSet *invalidSet = nil;
static NSCharacterSet *keySepCharSet = nil;
static NSCharacterSet *keyCharSet = nil;

+ (void)initialize {
    BDSKINITIALIZE;
    
    // comma and space are used to separate the keys
    
    keySepCharSet = [[NSCharacterSet characterSetWithCharactersInString:@", "] retain];
    
    keyCharSet = [[keySepCharSet invertedSet] retain];
    
    NSMutableCharacterSet *tmpSet = [[[BDSKTypeManager sharedManager] invalidCharactersForField:BDSKCiteKeyString inFileType:BDSKBibtexString] mutableCopy];
    [tmpSet formIntersectionWithCharacterSet:keyCharSet];
    invalidSet = [tmpSet copy];
    [tmpSet release];
}

- (id)initWithDelegate:(id<BDSKCitationFormatterDelegate>)aDelegate {
    if (self = [super init]) {
        delegate = aDelegate;
    }
    return self;
}

- (id<BDSKCitationFormatterDelegate>)delegate { return delegate; }

- (void)setDelegate:(id<BDSKCitationFormatterDelegate>)newDelegate { delegate = newDelegate; }

- (NSString *)stringForObjectValue:(id)obj{
    return obj;
}

// Display valid keys as underlined links
// This is used when the text field cell is not edited, the links are not really active, as there's no responder mechanism for links
// When it's edited BDSKFieldEditor will use essentially the same code to display these links
// When the user tries to use these dummy links, the field editor will be automatically inserted, magically making the links work, as NSTextView has the proper responder code for links
- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary *)attrs{
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:[self stringForObjectValue:obj] attributes:attrs];
    
    NSString *string = [attrString string];
    
    NSUInteger start, length = [string length];
    NSRange range = NSMakeRange(0, 0);
    NSString *keyString;
    
    [attrString removeAttribute:NSLinkAttributeName range:NSMakeRange(0, length)];
    
    do {
        // find the start of a key
        start = NSMaxRange(range);
        range = [string rangeOfCharacterFromSet:keyCharSet options:0 range:NSMakeRange(start, length - start)];
        
        if (range.length) {
            // find the end of a key, by searching a separator character or the end of the string 
            start = range.location;
            range = [string rangeOfCharacterFromSet:keySepCharSet options:0 range:NSMakeRange(start, length - start)];
            if (range.length == 0)
                range.location = length;
            if (range.location > start) {
                range = NSMakeRange(start, range.location - start);
                keyString = [string substringWithRange:range];
                if ([[self delegate] citationFormatter:self isValidKey:keyString]) {
                    // we found a valid key, so now underline it and make it blue
                    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
                    [attrString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInteger:NSUnderlineStyleSingle] range:range];
                    [attrString addAttribute:NSLinkAttributeName value:keyString range:range]; // this won't work, but who cares
                }
            }
        }
    } while (range.length);
    
    return [attrString autorelease];
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error{
    NSRange r = [string rangeOfCharacterFromSet:invalidSet];
    if (r.location != NSNotFound) {
        if(error) *error = [NSString stringWithFormat:NSLocalizedString(@"The character \"%@\" is not allowed in a BibTeX cite key.", @"Error description"), [string substringWithRange:r]];
        return NO;
   }
    *obj = string;
    return YES;
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString **)error {
    NSString *partialString = *partialStringPtr;
    NSRange r = [partialString rangeOfCharacterFromSet:invalidSet];
    if (r.location != NSNotFound) {
        NSMutableString *new = [[partialString mutableCopy] autorelease];
        [new replaceOccurrencesOfCharactersInSet:invalidSet withString:@""];
        if ([new length]) {
            *partialStringPtr = new;
            if (NSMaxRange(*proposedSelRangePtr) > [new length])
                *proposedSelRangePtr = NSMakeRange(r.location, 0);
        } else {
            *partialStringPtr = origString;
            *proposedSelRangePtr = origSelRange;
        }
        if(error) *error = [NSString stringWithFormat:NSLocalizedString(@"The character \"%@\" is not allowed in a BibTeX cite key.", @"Error description"), [partialString substringWithRange:r]];
        return NO;
    }else
        return YES;
}

@end

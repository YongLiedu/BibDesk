//
//  BDSKTemplateParser.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 5/17/06.
/*
 This software is Copyright (c)2006
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
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION)HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE)ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "BDSKTemplateParser.h"

#define START_DELIM @"<$"
#define END_DELIM @">"
#define CLOSE_END_DELIM @"/>"
#define CLOSE_DELIM @"/"
#define START_CLOSE_DELIM @"</$"
#define NEWLINE @"\n"
#define RETURN @"\n"
#define RETURN_NEWLINE @"\r\n"

@implementation BDSKTemplateParser


static NSCharacterSet *letterAndDotCharacterSet = nil;

+ (void)initialize {
    
    OBINITIALIZE;
    
    NSMutableCharacterSet *tmpSet = [[NSCharacterSet letterCharacterSet] mutableCopy];
    [tmpSet addCharactersInString:@".-0123456789:;@"];
    letterAndDotCharacterSet = [tmpSet copy];
    [tmpSet release];
}

+ (NSString *)stringByParsingTemplate:(NSString *)template usingObject:(id)object {
    return [self stringByParsingTemplate:template usingObject:object delegate:nil];
}

+ (NSString *)stringByParsingTemplate:(NSString *)template usingObject:(id)object delegate:(id <BDSKTemplateParserDelegate>)delegate {
    NSScanner *scanner = [NSScanner scannerWithString:template];
    NSMutableString *result = [[NSMutableString alloc] init];

    [scanner setCharactersToBeSkipped:nil];
    
    while (![scanner isAtEnd]) {
        NSString *beforeText = nil;
        NSString *tag = nil;
        NSString *itemTemplate = nil;
        NSString *endTag = nil;
        id keyValue = nil;
        int start;
        NSRange wsRange;
                
        if ([scanner scanUpToString:START_DELIM intoString:&beforeText])
            [result appendString:beforeText];
        
        if ([scanner scanString:START_DELIM intoString:nil]) {
            
            start = [scanner scanLocation];
            
            // scan the key, must be letters and dots. We don't allow extra spaces
            [scanner scanCharactersFromSet:letterAndDotCharacterSet intoString:&tag];
            
            if ([scanner scanString:CLOSE_END_DELIM intoString:nil]) {
                
                // simple template tag
                @try{ keyValue = [object valueForKeyPath:tag]; }
                @catch (id exception) { keyValue = nil; }
                if (keyValue != nil) 
                    [result appendString:[keyValue stringDescription]];
                
            } else if ([scanner scanString:END_DELIM intoString:nil]) {
                
                // collection template tag
                // ignore whitespace before the tag. Should we also remove a newline?
                wsRange = [result rangeOfTrailingWhitespaceLine];
                if (wsRange.location != NSNotFound)
                    [result deleteCharactersInRange:wsRange];
                
                endTag = [NSString stringWithFormat:@"%@%@%@", START_CLOSE_DELIM, tag, END_DELIM];
                // ignore the rest of an empty line after the tag
                [scanner scanWhitespaceAndSingleNewline];
                if ([scanner scanString:endTag intoString:nil])
                    continue;
                if ([scanner scanUpToString:endTag intoString:&itemTemplate] && [scanner scanString:endTag intoString:nil]) {
                    // ignore whitespace before the tag. Should we also remove a newline?
                    wsRange = [itemTemplate rangeOfTrailingWhitespaceLine];
                    if (wsRange.location != NSNotFound)
                        itemTemplate = [itemTemplate substringToIndex:wsRange.location];
                    
                    @try{ keyValue = [object valueForKeyPath:tag]; }
                    @catch (id exception) { keyValue = nil; }
                    if ([keyValue respondsToSelector:@selector(objectEnumerator)]) {
                        NSEnumerator *itemE = [keyValue objectEnumerator];
                        id item;
                        while (item = [itemE nextObject]) {
                            [delegate templateParserWillParseTemplate:itemTemplate usingObject:item isAttributed:NO];
                            keyValue = [self stringByParsingTemplate:itemTemplate usingObject:item delegate:delegate];
                            [delegate templateParserDidParseTemplate:itemTemplate usingObject:item isAttributed:NO];
                            if (keyValue != nil)
                                [result appendString:keyValue];
                        }
                    }
                    // ignore the the rest of an empty line after the tag
                    [scanner scanWhitespaceAndSingleNewline];
                    
                }
                
            } else {
                
                // a START_DELIM without END_DELIM, so no template tag. Rewind
                [result appendString:START_DELIM];
                [scanner setScanLocation:start];
                
            }
        } // scan START_DELIM
    } // while
    
    return [result autorelease];    
}

+ (NSAttributedString *)attributedStringByParsingTemplate:(NSAttributedString *)template usingObject:(id)object {
    return [self attributedStringByParsingTemplate:template usingObject:object delegate:nil];
}

+ (NSAttributedString *)attributedStringByParsingTemplate:(NSAttributedString *)template usingObject:(id)object delegate:(id <BDSKTemplateParserDelegate>)delegate {
    NSString *templateString = [template string];
    NSScanner *scanner = [NSScanner scannerWithString:templateString];
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];

    [scanner setCharactersToBeSkipped:nil];
    
    while (![scanner isAtEnd]) {
        NSString *beforeText = nil;
        NSString *tag = nil;
        NSString *itemTemplateString = nil;
        NSAttributedString *itemTemplate = nil;
        NSString *endTag = nil;
        NSDictionary *attr = nil;
        NSAttributedString *tmpAttrStr = nil;
        id keyValue = nil;
        int start;
        NSRange wsRange;
        
        start = [scanner scanLocation];
                
        if ([scanner scanUpToString:START_DELIM intoString:&beforeText])
            [result appendAttributedString:[template attributedSubstringFromRange:NSMakeRange(start, [beforeText length])]];
        
        if ([scanner scanString:START_DELIM intoString:nil]) {
            
            attr = [template attributesAtIndex:[scanner scanLocation] - 1 effectiveRange:NULL];
            start = [scanner scanLocation];
            
            // scan the key, must be letters and dots. We don't allow extra spaces
            [scanner scanCharactersFromSet:letterAndDotCharacterSet intoString:&tag];
            
            if ([scanner scanString:CLOSE_END_DELIM intoString:nil]) {
                
                // simple template tag
                @try{ keyValue = [object valueForKeyPath:tag]; }
                @catch (id exception) { keyValue = nil; }
                if (keyValue != nil) {
                    if ([keyValue isKindOfClass:[NSAttributedString class]]) {
                        tmpAttrStr = [keyValue mutableCopy];
                        [(NSMutableAttributedString *)tmpAttrStr addAttributes:attr range:NSMakeRange(0, [keyValue length])];
                    } else {
                        tmpAttrStr = [[NSAttributedString alloc] initWithString:[keyValue stringDescription] attributes:attr];
                    }
                    [result appendAttributedString:tmpAttrStr];
                    [tmpAttrStr release];
                }
                
            } else if ([scanner scanString:END_DELIM intoString:nil]) {
                
                // collection template tag
                // ignore whitespace before the tag. Should we also remove a newline?
                wsRange = [[result string] rangeOfTrailingWhitespaceLine];
                if (wsRange.location != NSNotFound)
                    [result deleteCharactersInRange:wsRange];
                
                endTag = [NSString stringWithFormat:@"%@%@%@", START_CLOSE_DELIM, tag, END_DELIM];
                // ignore the rest of an empty line after the tag
                [scanner scanWhitespaceAndSingleNewline];
                if ([scanner scanString:endTag intoString:nil])
                    continue;
                start = [scanner scanLocation];
                if ([scanner scanUpToString:endTag intoString:&itemTemplateString] && [scanner scanString:endTag intoString:nil]) {
                    // ignore whitespace before the tag. Should we also remove a newline?
                    wsRange = [itemTemplateString rangeOfTrailingWhitespaceLine];
                    itemTemplate = [template attributedSubstringFromRange:NSMakeRange(start, [itemTemplateString length] - wsRange.length)];
                    
                    @try{ keyValue = [object valueForKeyPath:tag]; }
                    @catch (id exception) { keyValue = nil; }
                    if ([keyValue respondsToSelector:@selector(objectEnumerator)]) {
                        NSEnumerator *itemE = [keyValue objectEnumerator];
                        id item;
                        while (item = [itemE nextObject]) {
                            [delegate templateParserWillParseTemplate:itemTemplate usingObject:item isAttributed:YES];
                            tmpAttrStr = [self attributedStringByParsingTemplate:itemTemplate usingObject:item delegate:delegate];
                            [delegate templateParserDidParseTemplate:itemTemplate usingObject:item isAttributed:YES];
                            if (tmpAttrStr != nil)
                                [result appendAttributedString:tmpAttrStr];
                        }
                    }
                    // ignore the the rest of an empty line after the tag
                    [scanner scanWhitespaceAndSingleNewline];
                    
                }
                
            } else {
                
                // a START_DELIM without END_DELIM, so no template tag. Rewind
                [result appendAttributedString:[template attributedSubstringFromRange:NSMakeRange(start - [START_DELIM length], [START_DELIM length])]];
                [scanner setScanLocation:start];
                
            }
        } // scan START_DELIM
    } // while
    
    [result fixAttributesInRange:NSMakeRange(0, [result length])];
    
    return [result autorelease];    
}

@end


@implementation NSObject (BDSKTemplateParser)

- (NSString *)stringDescription {
    if ([self isKindOfClass:[NSString class]])
        return (NSString *)self;
    if ([self respondsToSelector:@selector(stringValue)])
        return [self performSelector:@selector(stringValue)];
    if ([self respondsToSelector:@selector(string)])
        return [self performSelector:@selector(string)];
    return [self description];
}

@end


@implementation NSScanner (BDSKTemplateParser)

- (BOOL)scanWhitespaceAndSingleNewline {
    BOOL foundNewline = NO;
    BOOL foundWhitepace = NO;
    int startLoc = [self scanLocation];
    foundWhitepace = [self scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
    foundNewline = [self scanString:RETURN_NEWLINE intoString:nil] || [self scanString:NEWLINE intoString:nil] || [self scanString:RETURN intoString:nil];
    if (foundNewline == NO && foundWhitepace == YES)
        [self setScanLocation:startLoc];
    return foundNewline;
}

@end


@implementation NSString (BDSKTemplateParser)

- (NSRange)rangeOfTrailingWhitespaceLine {
    static NSCharacterSet *nonWhitespace = nil;
    if (nonWhitespace == nil) 
        nonWhitespace = [[[NSCharacterSet whitespaceCharacterSet] invertedSet] retain];
    NSRange lastCharRange = [self rangeOfCharacterFromSet:nonWhitespace options:NSBackwardsSearch];
    NSRange wsRange = NSMakeRange(NSNotFound, 0);
    unsigned int length = [self length];
    if (lastCharRange.location == NSNotFound) {
        wsRange = NSMakeRange(0, length);
    } else {
        unichar lastChar = [self characterAtIndex:lastCharRange.location];
        unsigned int rangeEnd = NSMaxRange(lastCharRange);
        if (rangeEnd < length && (lastChar == '\r' || lastChar == '\n')) 
            wsRange = NSMakeRange(rangeEnd, length - rangeEnd);
    }
    return wsRange;
}

@end

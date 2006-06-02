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

#define STARTTAG_OPEN_DELIM @"<$"
#define ENDTAG_OPEN_DELIM @"</$"
#define SEPTAG_OPEN_DELIM @"<?$"
#define SINGLETAG_CLOSE_DELIM @"/>"
#define MULTITAG_CLOSE_DELIM @">"

/*
    single tag: <$key/>
     multi tag: <$key> </$key> 
            or: <$key> <?$key> </$key>
*/

@implementation BDSKTemplateParser


static NSCharacterSet *keyCharacterSet = nil;
static NSCharacterSet *invertedKeyCharacterSet = nil;

+ (void)initialize {
    
    OBINITIALIZE;
    
    NSMutableCharacterSet *tmpSet = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
    [tmpSet addCharactersInString:@".-:;@"];
    keyCharacterSet = [tmpSet copy];
    [tmpSet release];
    
    invertedKeyCharacterSet = [[keyCharacterSet invertedSet] copy];
}

+ (NSString *)stringByParsingTemplate:(NSString *)template usingObject:(id)object {
    return [self stringByParsingTemplate:template usingObject:object delegate:nil];
}

+ (NSString *)stringByParsingTemplate:(NSString *)template usingObject:(id)object delegate:(id <BDSKTemplateParserDelegate>)delegate {
    NSScanner *scanner = [[NSScanner alloc] initWithString:template];
    NSMutableString *result = [[NSMutableString alloc] init];

    [scanner setCharactersToBeSkipped:nil];
    
    while (![scanner isAtEnd]) {
        NSString *beforeText = nil;
        NSString *tag = nil;
        NSString *itemTemplate = nil;
        NSString *lastItemTemplate;
        NSString *endTag = nil;
        NSString *sepTag = nil;
        NSRange sepTagRange;
        NSMutableString *tmpString;
        id keyValue = nil;
        int start;
        NSRange wsRange;
                
        if ([scanner scanUpToString:STARTTAG_OPEN_DELIM intoString:&beforeText])
            [result appendString:beforeText];
        
        if ([scanner scanString:STARTTAG_OPEN_DELIM intoString:nil]) {
            
            start = [scanner scanLocation];
            
            // scan the key, must be letters and dots. We don't allow extra spaces
            // scanUpToCharactersFromSet is used for efficiency instead of scanCharactersFromSet
            [scanner scanUpToCharactersFromSet:keyCharacterSet intoString:nil];
            [scanner scanUpToCharactersFromSet:invertedKeyCharacterSet intoString:&tag];
            
            if ([scanner scanString:SINGLETAG_CLOSE_DELIM intoString:nil]) {
                
                // simple template tag
                @try{ keyValue = [object valueForKeyPath:tag]; }
                @catch (id exception) { keyValue = nil; }
                if (keyValue != nil) 
                    [result appendString:[keyValue stringDescription]];
                
            } else if ([scanner scanString:MULTITAG_CLOSE_DELIM intoString:nil]) {
                
                // collection template tag
                // ignore whitespace before the tag. Should we also remove a newline?
                wsRange = [result rangeOfTrailingWhitespaceLine];
                if (wsRange.location != NSNotFound)
                    [result deleteCharactersInRange:wsRange];
                
                endTag = [NSString stringWithFormat:@"%@%@%@", ENDTAG_OPEN_DELIM, tag, MULTITAG_CLOSE_DELIM];
                sepTag = [NSString stringWithFormat:@"%@%@%@", SEPTAG_OPEN_DELIM, tag, MULTITAG_CLOSE_DELIM];
                // ignore the rest of an empty line after the tag
                [scanner scanWhitespaceAndSingleNewline];
                if ([scanner scanString:endTag intoString:nil])
                    continue;
                if ([scanner scanUpToString:endTag intoString:&itemTemplate] && [scanner scanString:endTag intoString:nil]) {
                    // ignore whitespace before the tag. Should we also remove a newline?
                    wsRange = [itemTemplate rangeOfTrailingWhitespaceLine];
                    if (wsRange.location != NSNotFound)
                        itemTemplate = [itemTemplate substringToIndex:wsRange.location];
                    
                    lastItemTemplate = nil;
                    sepTagRange = [itemTemplate rangeOfString:sepTag];
                    if (sepTagRange.location != NSNotFound) {
                        // ignore whitespaces before and after the tag, including a trailing newline 
                        wsRange = [itemTemplate rangeOfTrailingWhitespaceLineInRange:NSMakeRange(0, sepTagRange.location)];
                        if (wsRange.location != NSNotFound) 
                            sepTagRange = NSMakeRange(wsRange.location, NSMaxRange(sepTagRange) - wsRange.location);
                        wsRange = [itemTemplate rangeOfLeadingWhitespaceLineInRange:NSMakeRange(NSMaxRange(sepTagRange), [itemTemplate length] - NSMaxRange(sepTagRange))];
                        if (wsRange.location != NSNotFound)
                            sepTagRange.length = NSMaxRange(wsRange) - sepTagRange.location;
                        lastItemTemplate = [itemTemplate substringToIndex:sepTagRange.location];
                        tmpString = [itemTemplate mutableCopy];
                        [tmpString deleteCharactersInRange:sepTagRange];
                        itemTemplate = [tmpString autorelease];
                    }
                    
                    @try{ keyValue = [object valueForKeyPath:tag]; }
                    @catch (id exception) { keyValue = nil; }
                    if ([keyValue respondsToSelector:@selector(objectEnumerator)]) {
                        NSEnumerator *itemE = [keyValue objectEnumerator];
                        id nextItem, item = [itemE nextObject];
                        while (item) {
                            nextItem = [itemE nextObject];
                            if (lastItemTemplate != nil && nextItem == nil)
                                itemTemplate = lastItemTemplate;
                            [delegate templateParserWillParseTemplate:itemTemplate usingObject:item isAttributed:NO];
                            keyValue = [self stringByParsingTemplate:itemTemplate usingObject:item delegate:delegate];
                            [delegate templateParserDidParseTemplate:itemTemplate usingObject:item isAttributed:NO];
                            if (keyValue != nil)
                                [result appendString:keyValue];
                            item = nextItem;
                        }
                    }
                    // ignore the the rest of an empty line after the tag
                    [scanner scanWhitespaceAndSingleNewline];
                    
                }
                
            } else {
                
                // an open delimiter without a close delimiter, so no template tag. Rewind
                [result appendString:STARTTAG_OPEN_DELIM];
                [scanner setScanLocation:start];
                
            }
        } // scan STARTTAG_OPEN_DELIM
    } // while
    [scanner release];
    return [result autorelease];    
}

+ (NSAttributedString *)attributedStringByParsingTemplate:(NSAttributedString *)template usingObject:(id)object {
    return [self attributedStringByParsingTemplate:template usingObject:object delegate:nil];
}

+ (NSAttributedString *)attributedStringByParsingTemplate:(NSAttributedString *)template usingObject:(id)object delegate:(id <BDSKTemplateParserDelegate>)delegate {
    NSString *templateString = [template string];
    NSScanner *scanner = [[NSScanner alloc] initWithString:templateString];
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];

    [scanner setCharactersToBeSkipped:nil];
    
    while (![scanner isAtEnd]) {
        NSString *beforeText = nil;
        NSString *tag = nil;
        NSString *itemTemplateString = nil;
        NSAttributedString *itemTemplate = nil;
        NSAttributedString *lastItemTemplate = nil;
        NSString *endTag = nil;
        NSString *sepTag = nil;
        NSRange sepTagRange;
        NSDictionary *attr = nil;
        NSAttributedString *tmpAttrStr = nil;
        id keyValue = nil;
        int start;
        NSRange wsRange;
        
        start = [scanner scanLocation];
                
        if ([scanner scanUpToString:STARTTAG_OPEN_DELIM intoString:&beforeText])
            [result appendAttributedString:[template attributedSubstringFromRange:NSMakeRange(start, [beforeText length])]];
        
        if ([scanner scanString:STARTTAG_OPEN_DELIM intoString:nil]) {
            
            attr = [template attributesAtIndex:[scanner scanLocation] - 1 effectiveRange:NULL];
            start = [scanner scanLocation];
            
            // scan the key, must be letters and dots. We don't allow extra spaces
            // scanUpToCharactersFromSet is used for efficiency instead of scanCharactersFromSet
            [scanner scanUpToCharactersFromSet:keyCharacterSet intoString:nil];
            [scanner scanUpToCharactersFromSet:invertedKeyCharacterSet intoString:&tag];

            if ([scanner scanString:SINGLETAG_CLOSE_DELIM intoString:nil]) {
                
                // simple template tag
                @try{ keyValue = [object valueForKeyPath:tag]; }
                @catch (id exception) { keyValue = nil; }
                if (keyValue != nil) {
                    if ([keyValue isKindOfClass:[NSAttributedString class]]) {
                        tmpAttrStr = [[NSAttributedString alloc] initWithAttributedString:keyValue attributes:attr];
                    } else {
                        tmpAttrStr = [[NSAttributedString alloc] initWithString:[keyValue stringDescription] attributes:attr];
                    }
                    [result appendAttributedString:tmpAttrStr];
                    [tmpAttrStr release];
                }
                
            } else if ([scanner scanString:MULTITAG_CLOSE_DELIM intoString:nil]) {
                
                // collection template tag
                // ignore whitespace before the tag. Should we also remove a newline?
                wsRange = [[result string] rangeOfTrailingWhitespaceLine];
                if (wsRange.location != NSNotFound)
                    [result deleteCharactersInRange:wsRange];
                
                endTag = [NSString stringWithFormat:@"%@%@%@", ENDTAG_OPEN_DELIM, tag, MULTITAG_CLOSE_DELIM];
                sepTag = [NSString stringWithFormat:@"%@%@%@", SEPTAG_OPEN_DELIM, tag, MULTITAG_CLOSE_DELIM];
                // ignore the rest of an empty line after the tag
                [scanner scanWhitespaceAndSingleNewline];
                if ([scanner scanString:endTag intoString:nil])
                    continue;
                start = [scanner scanLocation];
                if ([scanner scanUpToString:endTag intoString:&itemTemplateString] && [scanner scanString:endTag intoString:nil]) {
                    // ignore whitespace before the tag. Should we also remove a newline?
                    wsRange = [itemTemplateString rangeOfTrailingWhitespaceLine];
                    itemTemplate = [template attributedSubstringFromRange:NSMakeRange(start, [itemTemplateString length] - wsRange.length)];
                    
                    lastItemTemplate = nil;
                    sepTagRange = [[itemTemplate string] rangeOfString:sepTag];
                    if (sepTagRange.location != NSNotFound) {
                        // ignore whitespaces before and after the tag, including a trailing newline 
                        wsRange = [[itemTemplate string] rangeOfTrailingWhitespaceLineInRange:NSMakeRange(0, sepTagRange.location)];
                        if (wsRange.location != NSNotFound) 
                            sepTagRange = NSMakeRange(wsRange.location, NSMaxRange(sepTagRange) - wsRange.location);
                        wsRange = [[itemTemplate string] rangeOfLeadingWhitespaceLineInRange:NSMakeRange(NSMaxRange(sepTagRange), [itemTemplate length] - NSMaxRange(sepTagRange))];
                        if (wsRange.location != NSNotFound)
                            sepTagRange.length = NSMaxRange(wsRange) - sepTagRange.location;
                        lastItemTemplate = [itemTemplate attributedSubstringFromRange:NSMakeRange(0, sepTagRange.location)];
                        tmpAttrStr = [itemTemplate mutableCopy];
                        [(NSMutableAttributedString *)tmpAttrStr deleteCharactersInRange:sepTagRange];
                        itemTemplate = [tmpAttrStr autorelease];
                    }
                    
                    @try{ keyValue = [object valueForKeyPath:tag]; }
                    @catch (id exception) { keyValue = nil; }
                    if ([keyValue respondsToSelector:@selector(objectEnumerator)]) {
                        NSEnumerator *itemE = [keyValue objectEnumerator];
                        id nextItem, item = [itemE nextObject];
                        while (item) {
                            nextItem = [itemE nextObject];
                            if (lastItemTemplate != nil && nextItem == nil)
                                itemTemplate = lastItemTemplate;
                            [delegate templateParserWillParseTemplate:itemTemplate usingObject:item isAttributed:YES];
                            tmpAttrStr = [self attributedStringByParsingTemplate:itemTemplate usingObject:item delegate:delegate];
                            [delegate templateParserDidParseTemplate:itemTemplate usingObject:item isAttributed:YES];
                            if (tmpAttrStr != nil)
                                [result appendAttributedString:tmpAttrStr];
                            item = nextItem;
                        }
                    }
                    // ignore the the rest of an empty line after the tag
                    [scanner scanWhitespaceAndSingleNewline];
                    
                }
                
            } else {
                
                // a STARTTAG_OPEN_DELIM without MULTITAG_CLOSE_DELIM, so no template tag. Rewind
                [result appendAttributedString:[template attributedSubstringFromRange:NSMakeRange(start - [STARTTAG_OPEN_DELIM length], [STARTTAG_OPEN_DELIM length])]];
                [scanner setScanLocation:start];
                
            }
        } // scan STARTTAG_OPEN_DELIM
    } // while
    
    [result fixAttributesInRange:NSMakeRange(0, [result length])];
    [scanner release];
    
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
    BOOL foundWhitespace = NO;
    int startLoc = [self scanLocation];

    // [self scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil] is much more sensible, but NSScanner creates an autoreleased inverted character set every time you use it, so it's pretty inefficient
    foundWhitespace = [self scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
    if (foundWhitespace){
        static NSCharacterSet *nonWhitespaceCharacterSet = nil;
        if(nil == nonWhitespaceCharacterSet)
            nonWhitespaceCharacterSet = [[[NSCharacterSet whitespaceCharacterSet] invertedSet] copy];
        [self scanUpToCharactersFromSet:nonWhitespaceCharacterSet intoString:nil];
    }

    if ([self isAtEnd] == NO) {
        foundNewline = [self scanString:@"\r\n" intoString:nil];
        if (foundNewline == NO) {
            unichar nextChar = [[self string] characterAtIndex:[self scanLocation]];
            if (foundNewline = [[NSCharacterSet newlineCharacterSet] characterIsMember:nextChar])
                [self setScanLocation:[self scanLocation] + 1];
        }
    }
    if (foundNewline == NO && foundWhitespace == YES)
        [self setScanLocation:startLoc];
    return foundNewline;
}

@end


@implementation NSString (BDSKTemplateParser)

// whitespace at the beginning of the string up to the end or until (and including) a newline
- (NSRange)rangeOfLeadingWhitespaceLine {
    return [self rangeOfLeadingWhitespaceLineInRange:NSMakeRange(0, [self length])];
}

- (NSRange)rangeOfLeadingWhitespaceLineInRange:(NSRange)range {
    static NSCharacterSet *nonWhitespace = nil;
    if (nonWhitespace == nil) 
        nonWhitespace = [[[NSCharacterSet whitespaceCharacterSet] invertedSet] retain];
    NSRange firstCharRange = [self rangeOfCharacterFromSet:nonWhitespace options:0 range:range];
    NSRange wsRange = NSMakeRange(NSNotFound, 0);
    unsigned int start = range.location;
    if (firstCharRange.location == NSNotFound) {
        wsRange = range;
    } else {
        unichar firstChar = [self characterAtIndex:firstCharRange.location];
        unsigned int rangeEnd = NSMaxRange(firstCharRange);
        if([[NSCharacterSet newlineCharacterSet] characterIsMember:firstChar]) {
            if (firstChar == '\r' && rangeEnd < NSMaxRange(range) && [self characterAtIndex:rangeEnd] == '\n')
                wsRange = NSMakeRange(start, rangeEnd + 1 - start);
            else 
                wsRange = NSMakeRange(start, rangeEnd - start);
        }
    }
    return wsRange;
}

// whitespace at the end of the string from the beginning or after a newline
- (NSRange)rangeOfTrailingWhitespaceLine {
    return [self rangeOfTrailingWhitespaceLineInRange:NSMakeRange(0, [self length])];
}

- (NSRange)rangeOfTrailingWhitespaceLineInRange:(NSRange)range {
    static NSCharacterSet *nonWhitespace = nil;
    if (nonWhitespace == nil) 
        nonWhitespace = [[[NSCharacterSet whitespaceCharacterSet] invertedSet] retain];
    NSRange lastCharRange = [self rangeOfCharacterFromSet:nonWhitespace options:NSBackwardsSearch range:range];
    NSRange wsRange = NSMakeRange(NSNotFound, 0);
    unsigned int end = NSMaxRange(range);
    if (lastCharRange.location == NSNotFound) {
        wsRange = range;
    } else {
        unichar lastChar = [self characterAtIndex:lastCharRange.location];
        unsigned int rangeEnd = NSMaxRange(lastCharRange);
        if (rangeEnd < end && [[NSCharacterSet newlineCharacterSet] characterIsMember:lastChar]) 
            wsRange = NSMakeRange(rangeEnd, end - rangeEnd);
    }
    return wsRange;
}

@end


@implementation NSAttributedString (BDSKTemplateParser)

- (id)initWithAttributedString:(NSAttributedString *)attributedString attributes:(NSDictionary *)attributes {
    [[self init] release];
    NSMutableAttributedString *tmpStr = [[NSMutableAttributedString alloc] initWithAttributedString:attributedString];
    unsigned index = 0, length = [attributedString length];
    NSRange range = NSMakeRange(0, length);
    NSDictionary *attrs;
    [tmpStr addAttributes:attributes range:range];
    while (index < length) {
        attrs = [attributedString attributesAtIndex:index effectiveRange:&range];
        if (range.length > 0) {
            [tmpStr addAttributes:attrs range:range];
            index = NSMaxRange(range);
        } else index++;
    }
    [tmpStr fixAttributesInRange:NSMakeRange(0, [self length])];
    return self = tmpStr;
}

@end

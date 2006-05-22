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

+ (NSString *)stringByParsingTemplate:(NSString *)template usingObject:(id)object {
    return [self stringByParsingTemplate:template usingObject:object delegate:nil];
}

+ (NSString *)stringByParsingTemplate:(NSString *)template usingObject:(id)object delegate:(id <BDSKTemplateParserDelegate>)delegate {
    NSScanner *scanner = [NSScanner scannerWithString:template];
    NSMutableString *result = [[NSMutableString alloc] init];

    [scanner setCharactersToBeSkipped:nil];
    
    while (![scanner isAtEnd]) {
        NSString *beforeText;
        NSString *tag;
        NSString *itemTemplate;
        NSString *endTag;
        id keyValue;
                
        if ([scanner scanUpToString:START_DELIM intoString:&beforeText])
            [result appendString:beforeText];
        
        if ([scanner scanString:START_DELIM intoString:nil]) {
            if ([scanner scanString:END_DELIM intoString:nil] || [scanner scanString:CLOSE_END_DELIM intoString:nil])
                continue;
            if ([scanner scanUpToString:END_DELIM intoString:&tag] && [scanner scanString:END_DELIM intoString:nil]) {
                if ([tag hasSuffix:CLOSE_DELIM]) {
                    tag = [tag substringToIndex:[tag length] - [CLOSE_DELIM length]];
                    keyValue = [object valueForKeyPath:[tag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                    if (keyValue != nil) {
                        [result appendString:[keyValue stringDescription]];
                    }
                } else {
                    endTag = [NSString stringWithFormat:@"%@%@%@", START_CLOSE_DELIM, tag, END_DELIM];
                    [scanner scanString:RETURN_NEWLINE intoString:nil] || [scanner scanString:NEWLINE intoString:nil] || [scanner scanString:RETURN intoString:nil];
                    if ([scanner scanString:endTag intoString:nil])
                        continue;
                    if ([scanner scanUpToString:endTag intoString:&itemTemplate] && [scanner scanString:endTag intoString:nil]) {
                        @try{
                            keyValue = [object valueForKeyPath:[tag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                        }
                        @catch (id exception) {
                            keyValue = nil;
                        }
                        if (keyValue != nil) {
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
                        [scanner scanString:RETURN_NEWLINE intoString:nil] || [scanner scanString:NEWLINE intoString:nil] || [scanner scanString:RETURN intoString:nil];
                    }
                }
            }
        }
    }
    
    return [result autorelease];    
}

+ (NSAttributedString *)attributedStringByParsingTemplate:(NSAttributedString *)template usingObject:(id)object {
    return [self attributedStringByParsingTemplate:template usingObject:object delegate:nil];
}

+ (NSAttributedString *)attributedStringByParsingTemplate:(NSAttributedString *)template usingObject:(id)object delegate:(id <BDSKTemplateParserDelegate>)delegate {
    NSScanner *scanner = [NSScanner scannerWithString:[template string]];
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];

    [scanner setCharactersToBeSkipped:nil];
    
    while (![scanner isAtEnd]) {
        NSString *beforeText;
        NSString *tag;
        NSAttributedString *itemTemplate;
        NSString *endTag;
        int start;
        NSDictionary *attr;
        NSAttributedString *tmpAttrStr;
        id keyValue;
        
        start = [scanner scanLocation];
        
        if ([scanner scanUpToString:START_DELIM intoString:&beforeText])
            [result appendAttributedString:[template attributedSubstringFromRange:NSMakeRange(start, [beforeText length])]];
        
        if ([scanner isAtEnd] == NO)
            attr = [template attributesAtIndex:[scanner scanLocation] effectiveRange:NULL];
        
        if ([scanner scanString:START_DELIM intoString:nil]) {
            if ([scanner scanString:END_DELIM intoString:nil] || [scanner scanString:CLOSE_END_DELIM intoString:nil])
                continue;
            if ([scanner scanUpToString:END_DELIM intoString:&tag] && [scanner scanString:END_DELIM intoString:nil]) {
                start = [scanner scanLocation];
                if ([tag hasSuffix:CLOSE_DELIM]) {
                    tag = [tag substringToIndex:[tag length] - [CLOSE_DELIM length]];
                    @try{
                        keyValue = [object valueForKeyPath:[tag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                    }
                    @catch (id exception) {
                        keyValue = nil;
                    }
                    if (keyValue != nil) {
                        if ([keyValue isKindOfClass:[NSAttributedString class]]) {
                            tmpAttrStr = [keyValue mutableCopy];
                            [keyValue addAttributes:attr range:NSMakeRange(0, [keyValue length])];
                        } else {
                            tmpAttrStr = [[NSAttributedString alloc] initWithString:[keyValue stringDescription] attributes:attr];
                        }
                        [result appendAttributedString:tmpAttrStr];
                        [tmpAttrStr release];
                    }
                } else {
                    endTag = [NSString stringWithFormat:@"%@%@%@", START_CLOSE_DELIM, tag, END_DELIM];
                    [scanner scanString:RETURN_NEWLINE intoString:nil] || [scanner scanString:NEWLINE intoString:nil] || [scanner scanString:RETURN intoString:nil];
                    if ([scanner scanString:endTag intoString:nil])
                        continue;
                    if ([scanner scanUpToString:endTag intoString:nil] && [scanner scanString:endTag intoString:nil]) {
                        itemTemplate = [template attributedSubstringFromRange:NSMakeRange(start, [scanner scanLocation] - [endTag length] - start)];
                        @try{
                            keyValue = [object valueForKeyPath:[tag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                        }
                        @catch (id exception) {
                            keyValue = nil;
                        }
                        if ([keyValue respondsToSelector:@selector(objectEnumerator)]) {
                            NSEnumerator *itemE = [keyValue objectEnumerator];
                            id item;
                            while (item = [itemE nextObject]) {
                                [delegate templateParserWillParseTemplate:template usingObject:item isAttributed:YES];
                                tmpAttrStr = [self attributedStringByParsingTemplate:itemTemplate usingObject:item delegate:delegate];
                                [delegate templateParserDidParseTemplate:template usingObject:item isAttributed:YES];
                                if (tmpAttrStr != nil) {
                                    [result appendAttributedString:tmpAttrStr];
                                }
                            }
                        }
                        [scanner scanString:RETURN_NEWLINE intoString:nil] || [scanner scanString:NEWLINE intoString:nil] || [scanner scanString:RETURN intoString:nil];
                    }
                }
            }
        }
    }
    
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

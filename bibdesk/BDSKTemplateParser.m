//
//  BDSKTemplateParser.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 5/17/06.
/*
 This software is Copyright (c) 2006,2007
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
#import "BDSKTag.h"
#import "NSString_BDSKExtensions.h"
#import "NSAttributedString_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "BibAuthor.h"

#define STARTTAG_OPEN_DELIM @"<$"
#define ENDTAG_OPEN_DELIM @"</$"
#define SEPTAG_OPEN_DELIM @"<?$"
#define SINGLETAG_CLOSE_DELIM @"/>"
#define MULTITAG_CLOSE_DELIM @">"
#define CONDITIONTAG_CLOSE_DELIM @"?>"
#define CONDITIONTAG_EQUAL @"="
#define CONDITIONTAG_CONTAIN @"~"
#define CONDITIONTAG_SMALLER @"<"
#define CONDITIONTAG_SMALLER_OR_EQUAL @"<="

/*
       single tag: <$key/>
        multi tag: <$key> </$key> 
               or: <$key> <?$key> </$key>
    condition tag: <$key?> </$key?> 
               or: <$key?> <?$key?> </$key?>
               or: <$key=value?> </$key?>
               or: <$key=value?> <?$key?> </$key?>
               or: <$key~value?> </$key?>
               or: <$key~value?> <?$key?> </$key?>
               or: <$key<value?> </$key?>
               or: <$key<value?> <?$key?> </$key?>
               or: <$key<=value?> </$key?>
               or: <$key<=value?> <?$key?> </$key?>
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

static NSMutableDictionary *endMultiDict = nil;
static inline NSString *endMultiTagWithTag(NSString *tag){
    if(nil == endMultiDict)
        endMultiDict = [[NSMutableDictionary alloc] init];
    
    NSString *endTag = [endMultiDict objectForKey:tag];
    if(nil == endTag){
        endTag = [NSString stringWithFormat:@"%@%@%@", ENDTAG_OPEN_DELIM, tag, MULTITAG_CLOSE_DELIM];
        [endMultiDict setObject:endTag forKey:tag];
    }
    return endTag;
}

static NSMutableDictionary *sepMultiDict = nil;
static inline NSString *sepMultiTagWithTag(NSString *tag){
    if(nil == sepMultiDict)
        sepMultiDict = [[NSMutableDictionary alloc] init];
    
    NSString *altTag = [sepMultiDict objectForKey:tag];
    if(nil == altTag){
        altTag = [NSString stringWithFormat:@"%@%@%@", SEPTAG_OPEN_DELIM, tag, MULTITAG_CLOSE_DELIM];
        [sepMultiDict setObject:altTag forKey:tag];
    }
    return altTag;
}

static NSMutableDictionary *endConditionDict = nil;
static inline NSString *endConditionTagWithTag(NSString *tag){
    if(nil == endConditionDict)
        endConditionDict = [[NSMutableDictionary alloc] init];
    
    NSString *endTag = [endConditionDict objectForKey:tag];
    if(nil == endTag){
        endTag = [NSString stringWithFormat:@"%@%@%@", ENDTAG_OPEN_DELIM, tag, CONDITIONTAG_CLOSE_DELIM];
        [endConditionDict setObject:endTag forKey:tag];
    }
    return endTag;
}

static NSMutableDictionary *altConditionDict = nil;
static inline NSString *altConditionTagWithTag(NSString *tag){
    if(nil == altConditionDict)
        altConditionDict = [[NSMutableDictionary alloc] init];
    
    NSString *altTag = [altConditionDict objectForKey:tag];
    if(nil == altTag){
        altTag = [NSString stringWithFormat:@"%@%@%@", SEPTAG_OPEN_DELIM, tag, CONDITIONTAG_CLOSE_DELIM];
        [altConditionDict setObject:altTag forKey:tag];
    }
    return altTag;
}

static NSMutableDictionary *equalConditionDict = nil;
static NSMutableDictionary *containConditionDict = nil;
static NSMutableDictionary *smallerConditionDict = nil;
static NSMutableDictionary *smallerOrEqualConditionDict = nil;
static inline NSString *compareConditionTagWithTag(NSString *tag, int matchType){
    NSString *altTag = nil;
    switch (matchType) {
        case BDSKConditionTagMatchEqual:
            if(nil == equalConditionDict)
                equalConditionDict = [[NSMutableDictionary alloc] init];
            altTag = [equalConditionDict objectForKey:tag];
            if(nil == altTag){
                altTag = [NSString stringWithFormat:@"%@%@%@", SEPTAG_OPEN_DELIM, tag, CONDITIONTAG_EQUAL];
                [equalConditionDict setObject:altTag forKey:tag];
            }
            break;
        case BDSKConditionTagMatchContain:
            if(nil == containConditionDict)
                containConditionDict = [[NSMutableDictionary alloc] init];
            altTag = [containConditionDict objectForKey:tag];
            if(nil == altTag){
                altTag = [NSString stringWithFormat:@"%@%@%@", SEPTAG_OPEN_DELIM, tag, CONDITIONTAG_CONTAIN];
                [containConditionDict setObject:altTag forKey:tag];
            }
            break;
        case BDSKConditionTagMatchSmaller:
            if(nil == smallerConditionDict)
                smallerConditionDict = [[NSMutableDictionary alloc] init];
            altTag = [smallerConditionDict objectForKey:tag];
            if(nil == altTag){
                altTag = [NSString stringWithFormat:@"%@%@%@", SEPTAG_OPEN_DELIM, tag, CONDITIONTAG_SMALLER];
                [smallerConditionDict setObject:altTag forKey:tag];
            }
            break;
        case BDSKConditionTagMatchSmallerOrEqual:
            if(nil == smallerOrEqualConditionDict)
                smallerOrEqualConditionDict = [[NSMutableDictionary alloc] init];
            altTag = [smallerOrEqualConditionDict objectForKey:tag];
            if(nil == altTag){
                altTag = [NSString stringWithFormat:@"%@%@%@", SEPTAG_OPEN_DELIM, tag, CONDITIONTAG_SMALLER_OR_EQUAL];
                [smallerOrEqualConditionDict setObject:altTag forKey:tag];
            }
            break;
    }
    return altTag;
}

static inline NSRange altTemplateTagRange(NSString *template, NSString *altTag, NSString *endDelim, NSString **argString){
    NSRange altTagRange = [template rangeOfString:altTag];
    if (altTagRange.location != NSNotFound) {
        // ignore whitespaces before the tag
        NSRange wsRange = [template rangeOfTrailingEmptyLineInRange:NSMakeRange(0, altTagRange.location)];
        if (wsRange.location != NSNotFound) 
            altTagRange = NSMakeRange(wsRange.location, NSMaxRange(altTagRange) - wsRange.location);
        if (nil != endDelim) {
            // find the end tag and the argument (match string)
            NSRange endRange = [template rangeOfString:endDelim options:0 range:NSMakeRange(NSMaxRange(altTagRange), [template length] - NSMaxRange(altTagRange))];
            if (endRange.location != NSNotFound) {
                *argString = [template substringWithRange:NSMakeRange(NSMaxRange(altTagRange), endRange.location - NSMaxRange(altTagRange))];
                altTagRange.length = NSMaxRange(endRange) - altTagRange.location;
            } else {
                *argString = @"";
            }
        }
        // ignore whitespaces after the tag, including a trailing newline 
        wsRange = [template rangeOfLeadingEmptyLineInRange:NSMakeRange(NSMaxRange(altTagRange), [template length] - NSMaxRange(altTagRange))];
        if (wsRange.location != NSNotFound)
            altTagRange.length = NSMaxRange(wsRange) - altTagRange.location;
    }
    return altTagRange;
}

#pragma mark Parsing string templates

+ (NSString *)stringByParsingTemplate:(NSString *)template usingObject:(id)object {
    return [self stringByParsingTemplate:template usingObject:object delegate:nil];
}

+ (NSString *)stringByParsingTemplate:(NSString *)template usingObject:(id)object delegate:(id <BDSKTemplateParserDelegate>)delegate {
    return [self stringFromTemplateArray:[self arrayByParsingTemplateString:template] usingObject:object delegate:delegate];
}

+ (NSArray *)arrayByParsingTemplateString:(NSString *)template {
    NSScanner *scanner = [[NSScanner alloc] initWithString:template];
    NSMutableArray *result = [[NSMutableArray alloc] init];
    id currentTag = nil;

    [scanner setCharactersToBeSkipped:nil];
    
    while (![scanner isAtEnd]) {
        NSString *beforeText = nil;
        NSString *tag = nil;
        int start;
                
        if ([scanner scanUpToString:STARTTAG_OPEN_DELIM intoString:&beforeText]) {
            if (currentTag && [(BDSKTag *)currentTag type] == BDSKTextTagType) {
                [currentTag setText:[[currentTag text] stringByAppendingString:beforeText]];
            } else {
                currentTag = [[BDSKTextTag alloc] initWithText:beforeText];
                [result addObject:currentTag];
                [currentTag release];
            }
        }
        
        if ([scanner scanString:STARTTAG_OPEN_DELIM intoString:nil]) {
            
            start = [scanner scanLocation];
            
            // scan the key, must be letters and dots. We don't allow extra spaces
            // scanUpToCharactersFromSet is used for efficiency instead of scanCharactersFromSet
            [scanner scanUpToCharactersFromSet:invertedKeyCharacterSet intoString:&tag];
            
            if ([scanner scanString:SINGLETAG_CLOSE_DELIM intoString:nil]) {
                
                // simple template currentTag
                currentTag = [[BDSKValueTag alloc] initWithKeyPath:tag];
                [result addObject:currentTag];
                [currentTag release];
                
            } else if ([scanner scanString:MULTITAG_CLOSE_DELIM intoString:nil]) {
                
                NSString *itemTemplate = nil, *separatorTemplate = nil;
                NSString *endTag;
                NSRange sepTagRange, wsRange;
                
                // collection template tag
                // ignore whitespace before the tag. Should we also remove a newline?
                if (currentTag && [(BDSKTag *)currentTag type] == BDSKTextTagType) {
                    wsRange = [[currentTag text] rangeOfTrailingEmptyLineRequiringNewline:[result count] != 1];
                    if (wsRange.location != NSNotFound) {
                        if (wsRange.length == [[currentTag text] length]) {
                            [result removeLastObject];
                            currentTag = [result lastObject];
                        } else {
                            [currentTag setText:[[currentTag text] substringToIndex:wsRange.location]];
                        }
                    }
                }
                
                endTag = endMultiTagWithTag(tag);
                // ignore the rest of an empty line after the tag
                [scanner scanEmptyLine];
                if ([scanner scanString:endTag intoString:nil])
                    continue;
                if ([scanner scanUpToString:endTag intoString:&itemTemplate] && [scanner scanString:endTag intoString:nil]) {
                    // ignore whitespace before the currentTag. Should we also remove a newline?
                    wsRange = [itemTemplate rangeOfTrailingEmptyLine];
                    if (wsRange.location != NSNotFound)
                        itemTemplate = [itemTemplate substringToIndex:wsRange.location];
                    
                    sepTagRange = altTemplateTagRange(itemTemplate, sepMultiTagWithTag(tag), nil, NULL);
                    if (sepTagRange.location != NSNotFound) {
                        separatorTemplate = [itemTemplate substringFromIndex:NSMaxRange(sepTagRange)];
                        itemTemplate = [itemTemplate substringToIndex:sepTagRange.location];
                    }
                    
                    currentTag = [[BDSKCollectionTag alloc] initWithKeyPath:tag itemTemplateString:itemTemplate separatorTemplateString:separatorTemplate];
                    [result addObject:currentTag];
                    [currentTag release];
                    
                    // ignore the the rest of an empty line after the currentTag
                    [scanner scanEmptyLine];
                    
                }
                
            } else {
                
                NSString *matchString = nil;
                int matchType = BDSKConditionTagMatchNotEmpty;
                
                if ([scanner scanString:CONDITIONTAG_EQUAL intoString:nil]) {
                    if([scanner scanUpToString:CONDITIONTAG_CLOSE_DELIM intoString:&matchString] == NO)
                        matchString = @"";
                    matchType = BDSKConditionTagMatchEqual;
                } else if ([scanner scanString:CONDITIONTAG_CONTAIN intoString:nil]) {
                    if([scanner scanUpToString:CONDITIONTAG_CLOSE_DELIM intoString:&matchString] == NO)
                        matchString = @"";
                    matchType = BDSKConditionTagMatchContain;
                } else if ([scanner scanString:CONDITIONTAG_SMALLER_OR_EQUAL intoString:nil]) {
                    if([scanner scanUpToString:CONDITIONTAG_CLOSE_DELIM intoString:&matchString] == NO)
                        matchString = @"";
                    matchType = BDSKConditionTagMatchSmallerOrEqual;
                } else if ([scanner scanString:CONDITIONTAG_SMALLER intoString:nil]) {
                    if([scanner scanUpToString:CONDITIONTAG_CLOSE_DELIM intoString:&matchString] == NO)
                        matchString = @"";
                    matchType = BDSKConditionTagMatchSmaller;
                }
                
                if ([scanner scanString:CONDITIONTAG_CLOSE_DELIM intoString:nil]) {
                    
                    NSMutableArray *subTemplates, *matchStrings;
                    NSString *subTemplate = nil;
                    NSString *endTag, *altTag;
                    NSRange altTagRange, wsRange;
                    
                    // condition template tag
                    // ignore whitespace before the tag. Should we also remove a newline?
                    if (currentTag && [(BDSKTag *)currentTag type] == BDSKTextTagType) {
                        wsRange = [[currentTag text] rangeOfTrailingEmptyLineRequiringNewline:[result count] != 1];
                        if (wsRange.location != NSNotFound) {
                            if (wsRange.length == [[currentTag text] length]) {
                                [result removeLastObject];
                                currentTag = [result lastObject];
                            } else {
                                [currentTag setText:[[currentTag text] substringToIndex:wsRange.location]];
                            }
                        }
                    }
                    
                    endTag = endConditionTagWithTag(tag);
                    // ignore the rest of an empty line after the currentTag
                    [scanner scanEmptyLine];
                    if ([scanner scanString:endTag intoString:nil])
                        continue;
                    if ([scanner scanUpToString:endTag intoString:&subTemplate] && [scanner scanString:endTag intoString:nil]) {
                        // ignore whitespace before the currentTag. Should we also remove a newline?
                        wsRange = [subTemplate rangeOfTrailingEmptyLine];
                        if (wsRange.location != NSNotFound)
                            subTemplate = [subTemplate substringToIndex:wsRange.location];
                        
                        subTemplates = [[NSMutableArray alloc] init];
                        matchStrings = [[NSMutableArray alloc] initWithObjects:matchString ? matchString : @"", nil];
                        
                        if (matchType != BDSKConditionTagMatchNotEmpty) {
                            altTag = compareConditionTagWithTag(tag, matchType);
                            altTagRange = altTemplateTagRange(subTemplate, altTag, CONDITIONTAG_CLOSE_DELIM, &matchString);
                            while (altTagRange.location != NSNotFound) {
                                [subTemplates addObject:[subTemplate substringToIndex:altTagRange.location]];
                                [matchStrings addObject:matchString ? matchString : @""];
                                subTemplate = [subTemplate substringFromIndex:NSMaxRange(altTagRange)];
                                altTagRange = altTemplateTagRange(subTemplate, altTag, CONDITIONTAG_CLOSE_DELIM, &matchString);
                            }
                        }
                        
                        altTagRange = altTemplateTagRange(subTemplate, altConditionTagWithTag(tag), nil, NULL);
                        if (altTagRange.location != NSNotFound) {
                            [subTemplates addObject:[subTemplate substringToIndex:altTagRange.location]];
                            subTemplate = [subTemplate substringFromIndex:NSMaxRange(altTagRange)];
                        }
                        [subTemplates addObject:subTemplate];
                        
                        currentTag = [[BDSKConditionTag alloc] initWithKeyPath:tag matchType:matchType matchStrings:matchStrings subtemplates:subTemplates];
                        [result addObject:currentTag];
                        [currentTag release];
                        
                        [subTemplates release];
                        [matchStrings release];
                        // ignore the the rest of an empty line after the currentTag
                        [scanner scanEmptyLine];
                        
                    }
                    
                } else {
                    
                    // an open delimiter without a close delimiter, so no template tag. Rewind
                    if (currentTag && [(BDSKTag *)currentTag type] == BDSKTextTagType) {
                        [currentTag setText:[[currentTag text] stringByAppendingString:STARTTAG_OPEN_DELIM]];
                    } else {
                        currentTag = [[BDSKTextTag alloc] initWithText:STARTTAG_OPEN_DELIM];
                        [result addObject:currentTag];
                        [currentTag release];
                    }
                    [scanner setScanLocation:start];
                    
                }
            }
        } // scan STARTTAG_OPEN_DELIM
    } // while
    [scanner release];
    return [result autorelease];    
}

+ (NSString *)stringFromTemplateArray:(NSArray *)template usingObject:(id)object {
    return [self stringFromTemplateArray:template usingObject:object delegate:nil];
}

+ (NSString *)stringFromTemplateArray:(NSArray *)template usingObject:(id)object delegate:(id <BDSKTemplateParserDelegate>)delegate {
    NSEnumerator *tagEnum = [template objectEnumerator];
    id tag;
    NSMutableString *result = [[NSMutableString alloc] init];
    
    while (tag = [tagEnum nextObject]) {
        int type = [(BDSKTag *)tag type];
        id keyValue = nil;
        
        if (type == BDSKTextTagType) {
            
            [result appendString:[tag text]];
            
        } else if (type == BDSKValueTagType) {
            
            if (keyValue = [object safeValueForKeyPath:[tag keyPath]])
                [result appendString:[keyValue stringDescription]];
            
        } else if (type == BDSKCollectionTagType) {
            
            keyValue = [object safeValueForKeyPath:[tag keyPath]];
            if ([keyValue respondsToSelector:@selector(objectEnumerator)]) {
                NSEnumerator *itemE = [keyValue objectEnumerator];
                id nextItem, item = [itemE nextObject];
                NSArray *itemTemplate = [[tag itemTemplate] arrayByAddingObjectsFromArray:[tag separatorTemplate]];
                while (item) {
                    nextItem = [itemE nextObject];
                    if (nextItem == nil)
                        itemTemplate = [tag itemTemplate];
                    [delegate templateParserWillParseTemplate:itemTemplate usingObject:item isAttributed:NO];
                    keyValue = [self stringFromTemplateArray:itemTemplate usingObject:item delegate:delegate];
                    [delegate templateParserDidParseTemplate:itemTemplate usingObject:item isAttributed:NO];
                    if (keyValue != nil)
                        [result appendString:keyValue];
                    item = nextItem;
                }
            }
            
        } else {
            
            NSString *matchString = nil;
            BOOL isMatch;
            NSArray *matchStrings = [tag matchStrings];
            unsigned int i, count = [matchStrings count];
            NSArray *subtemplate = nil;
            
            keyValue = [object safeValueForKeyPath:[tag keyPath]];
            for (i = 0; i < count; i++) {
                matchString = [matchStrings objectAtIndex:i];
                if ([matchString hasPrefix:@"$"]) {
                    matchString = [[object safeValueForKeyPath:[matchString substringFromIndex:1]] stringDescription];
                    if (matchString == nil)
                        matchString = @"";
                }
                switch ([tag matchType]) {
                    case BDSKConditionTagMatchEqual:
                        isMatch = [matchString isEqualToString:@""] ? NO == [keyValue isNotEmpty] : [[keyValue stringDescription] caseInsensitiveCompare:matchString] == NSOrderedSame;
                        break;
                    case BDSKConditionTagMatchContain:
                        isMatch = [matchString isEqualToString:@""] ? NO == [keyValue isNotEmpty] : [[keyValue stringDescription] rangeOfString:matchString options:NSCaseInsensitiveSearch].location != NSNotFound;
                        break;
                    case BDSKConditionTagMatchSmaller:
                        isMatch = [matchString isEqualToString:@""] ? NO == [keyValue isNotEmpty] : [[keyValue stringDescription] localizedCaseInsensitiveNumericCompare:matchString] == NSOrderedAscending;
                        break;
                    case BDSKConditionTagMatchSmallerOrEqual:
                        isMatch = [matchString isEqualToString:@""] ? NO == [keyValue isNotEmpty] : [[keyValue stringDescription] localizedCaseInsensitiveNumericCompare:matchString] != NSOrderedDescending;
                        break;
                    default:
                        isMatch = [keyValue isNotEmpty];
                        break;
                }
                if (isMatch) {
                    subtemplate = [tag subtemplateAtIndex:i];
                    break;
                }
            }
            if (subtemplate == nil && [[tag subtemplates] count] > count) {
                subtemplate = [tag subtemplateAtIndex:count];
            }
            if (subtemplate != nil) {
                keyValue = [self stringFromTemplateArray:subtemplate usingObject:object delegate:delegate];
                [result appendString:keyValue];
            }
            
        }
    } // while
    
    return [result autorelease];    
}

#pragma mark Parsing attributed string templates

+ (NSAttributedString *)attributedStringByParsingTemplate:(NSAttributedString *)template usingObject:(id)object {
    return [self attributedStringByParsingTemplate:template usingObject:object delegate:nil];
}

+ (NSAttributedString *)attributedStringByParsingTemplate:(NSAttributedString *)template usingObject:(id)object delegate:(id <BDSKTemplateParserDelegate>)delegate {
    return [self attributedStringFromTemplateArray:[self arrayByParsingTemplateAttributedString:template] usingObject:object delegate:delegate];
}

+ (NSArray *)arrayByParsingTemplateAttributedString:(NSAttributedString *)template {
    NSString *templateString = [template string];
    NSScanner *scanner = [[NSScanner alloc] initWithString:templateString];
    NSMutableArray *result = [[NSMutableArray alloc] init];
    id currentTag = nil;

    [scanner setCharactersToBeSkipped:nil];
    
    while (![scanner isAtEnd]) {
        NSString *beforeText = nil;
        NSString *tag = nil;
        int start;
        NSDictionary *attr = nil;
        NSMutableAttributedString *tmpAttrStr = nil;
        
        start = [scanner scanLocation];
                
        if ([scanner scanUpToString:STARTTAG_OPEN_DELIM intoString:&beforeText]) {
            if (currentTag && [(BDSKTag *)currentTag type] == BDSKTextTagType) {
                tmpAttrStr = [[currentTag attributedText] mutableCopy];
                [tmpAttrStr appendAttributedString:[template attributedSubstringFromRange:NSMakeRange(start, [beforeText length])]];
                [tmpAttrStr fixAttributesInRange:NSMakeRange(0, [tmpAttrStr length])];
                [currentTag setAttributedText:tmpAttrStr];
                [tmpAttrStr release];
            } else {
                currentTag = [[BDSKRichTextTag alloc] initWithAttributedText:[template attributedSubstringFromRange:NSMakeRange(start, [beforeText length])]];
                [result addObject:currentTag];
                [currentTag release];
            }
        }
        
        if ([scanner scanString:STARTTAG_OPEN_DELIM intoString:nil]) {
            
            attr = [template attributesAtIndex:[scanner scanLocation] - 1 effectiveRange:NULL];
            start = [scanner scanLocation];
            
            // scan the key, must be letters and dots. We don't allow extra spaces
            // scanUpToCharactersFromSet is used for efficiency instead of scanCharactersFromSet
            [scanner scanUpToCharactersFromSet:invertedKeyCharacterSet intoString:&tag];

            if ([scanner scanString:SINGLETAG_CLOSE_DELIM intoString:nil]) {
                
                // simple template tag
                currentTag = [[BDSKRichValueTag alloc] initWithKeyPath:tag attributes:attr];
                [result addObject:currentTag];
                [currentTag release];
               
            } else if ([scanner scanString:MULTITAG_CLOSE_DELIM intoString:nil]) {
                
                NSString *itemTemplateString = nil;
                NSAttributedString *itemTemplate = nil, *separatorTemplate = nil;
                NSString *endTag;
                NSRange sepTagRange, wsRange;
                
                // collection template tag
                // ignore whitespace before the tag. Should we also remove a newline?
                if (currentTag && [(BDSKTag *)currentTag type] == BDSKTextTagType) {
                    wsRange = [[[currentTag attributedText] string] rangeOfTrailingEmptyLineRequiringNewline:[result count] != 1];
                    if (wsRange.location != NSNotFound) {
                        if (wsRange.length == [[currentTag attributedText] length]) {
                            [result removeLastObject];
                            currentTag = [result lastObject];
                        } else {
                            [currentTag setAttributedText:[[currentTag attributedText] attributedSubstringFromRange:NSMakeRange(0, wsRange.location)]];
                        }
                    }
                }
                
                endTag = endMultiTagWithTag(tag);
                // ignore the rest of an empty line after the tag
                [scanner scanEmptyLine];
                if ([scanner scanString:endTag intoString:nil])
                    continue;
                start = [scanner scanLocation];
                if ([scanner scanUpToString:endTag intoString:&itemTemplateString] && [scanner scanString:endTag intoString:nil]) {
                    // ignore whitespace before the tag. Should we also remove a newline?
                    wsRange = [itemTemplateString rangeOfTrailingEmptyLine];
                    itemTemplate = [template attributedSubstringFromRange:NSMakeRange(start, [itemTemplateString length] - wsRange.length)];
                    
                    sepTagRange = altTemplateTagRange([itemTemplate string], sepMultiTagWithTag(tag), nil, NULL);
                    if (sepTagRange.location != NSNotFound) {
                        separatorTemplate = [itemTemplate attributedSubstringFromRange:NSMakeRange(NSMaxRange(sepTagRange), [itemTemplate length] - NSMaxRange(sepTagRange))];
                        itemTemplate = [itemTemplate attributedSubstringFromRange:NSMakeRange(0, sepTagRange.location)];
                    }
                    
                    currentTag = [[BDSKRichCollectionTag alloc] initWithKeyPath:tag itemTemplateAttributedString:itemTemplate separatorTemplateAttributedString:separatorTemplate];
                    [result addObject:currentTag];
                    [currentTag release];
                    
                    // ignore the the rest of an empty line after the tag
                    [scanner scanEmptyLine];
                    
                }
                
            } else {
                
                NSString *matchString = nil;
                int matchType = BDSKConditionTagMatchNotEmpty;
                
                if ([scanner scanString:CONDITIONTAG_EQUAL intoString:nil]) {
                    if([scanner scanUpToString:CONDITIONTAG_CLOSE_DELIM intoString:&matchString] == NO)
                        matchString = @"";
                    matchType = BDSKConditionTagMatchEqual;
                } else if ([scanner scanString:CONDITIONTAG_CONTAIN intoString:nil]) {
                    if([scanner scanUpToString:CONDITIONTAG_CLOSE_DELIM intoString:&matchString] == NO)
                        matchString = @"";
                    matchType = BDSKConditionTagMatchContain;
                } else if ([scanner scanString:CONDITIONTAG_SMALLER_OR_EQUAL intoString:nil]) {
                    if([scanner scanUpToString:CONDITIONTAG_CLOSE_DELIM intoString:&matchString] == NO)
                        matchString = @"";
                    matchType = BDSKConditionTagMatchSmallerOrEqual;
                } else if ([scanner scanString:CONDITIONTAG_SMALLER intoString:nil]) {
                    if([scanner scanUpToString:CONDITIONTAG_CLOSE_DELIM intoString:&matchString] == NO)
                        matchString = @"";
                    matchType = BDSKConditionTagMatchSmaller;
                }
                
                if ([scanner scanString:CONDITIONTAG_CLOSE_DELIM intoString:nil]) {
                    
                    NSMutableArray *subTemplates, *matchStrings;
                    NSString *subTemplateString = nil;
                    NSAttributedString *subTemplate = nil;
                    NSString *endTag, *altTag;
                    NSRange altTagRange, wsRange;
                    
                    // condition template tag
                    // ignore whitespace before the tag. Should we also remove a newline?
                    if (currentTag && [(BDSKTag *)currentTag type] == BDSKTextTagType) {
                        wsRange = [[[currentTag attributedText] string] rangeOfTrailingEmptyLineRequiringNewline:[result count] != 1];
                        if (wsRange.location != NSNotFound) {
                            if (wsRange.length == [[currentTag attributedText] length]) {
                                [result removeLastObject];
                                currentTag = [result lastObject];
                            } else {
                                [currentTag setAttributedText:[[currentTag attributedText] attributedSubstringFromRange:NSMakeRange(0, wsRange.location)]];
                            }
                        }
                    }
                    
                    endTag = endConditionTagWithTag(tag);
                    altTag = altConditionTagWithTag(tag);
                    // ignore the rest of an empty line after the tag
                    [scanner scanEmptyLine];
                    if ([scanner scanString:endTag intoString:nil])
                        continue;
                    start = [scanner scanLocation];
                    if ([scanner scanUpToString:endTag intoString:&subTemplateString] && [scanner scanString:endTag intoString:nil]) {
                        // ignore whitespace before the tag. Should we also remove a newline?
                        wsRange = [subTemplateString rangeOfTrailingEmptyLine];
                        subTemplate = [template attributedSubstringFromRange:NSMakeRange(start, [subTemplateString length] - wsRange.length)];
                        
                        subTemplates = [[NSMutableArray alloc] init];
                        matchStrings = [[NSMutableArray alloc] initWithObjects:matchString ? matchString : @"", nil];
                        
                        if (matchType != BDSKConditionTagMatchNotEmpty) {
                            altTag = compareConditionTagWithTag(tag, matchType);
                            altTagRange = altTemplateTagRange([subTemplate string], altTag, CONDITIONTAG_CLOSE_DELIM, &matchString);
                            while (altTagRange.location != NSNotFound) {
                                [subTemplates addObject:[subTemplate attributedSubstringFromRange:NSMakeRange(0, altTagRange.location)]];
                                [matchStrings addObject:matchString ? matchString : @""];
                                subTemplate = [subTemplate attributedSubstringFromRange:NSMakeRange(NSMaxRange(altTagRange), [subTemplate length] - NSMaxRange(altTagRange))];
                                altTagRange = altTemplateTagRange([subTemplate string], altTag, CONDITIONTAG_CLOSE_DELIM, &matchString);
                            }
                        }
                        
                        altTagRange = altTemplateTagRange([subTemplate string], altConditionTagWithTag(tag), nil, NULL);
                        if (altTagRange.location != NSNotFound) {
                            [subTemplates addObject:[subTemplate attributedSubstringFromRange:NSMakeRange(0, altTagRange.location)]];
                            subTemplate = [subTemplate attributedSubstringFromRange:NSMakeRange(NSMaxRange(altTagRange), [subTemplate length] - NSMaxRange(altTagRange))];
                        }
                        [subTemplates addObject:subTemplate];
                        
                        currentTag = [[BDSKRichConditionTag alloc] initWithKeyPath:tag matchType:matchType matchStrings:matchStrings subtemplates:subTemplates];
                        [result addObject:currentTag];
                        [currentTag release];
                        
                        [subTemplates release];
                        [matchStrings release];
                        // ignore the the rest of an empty line after the tag
                        [scanner scanEmptyLine];
                        
                    }
                    
                } else {
                    
                    // a STARTTAG_OPEN_DELIM without MULTITAG_CLOSE_DELIM, so no template tag. Rewind
                    if (currentTag && [(BDSKTag *)currentTag type] == BDSKTextTagType) {
                        tmpAttrStr = [[currentTag attributedText] mutableCopy];
                        [tmpAttrStr appendAttributedString:[template attributedSubstringFromRange:NSMakeRange(start - [STARTTAG_OPEN_DELIM length], [STARTTAG_OPEN_DELIM length])]];
                        [tmpAttrStr fixAttributesInRange:NSMakeRange(0, [tmpAttrStr length])];
                        [currentTag setAttributedText:tmpAttrStr];
                        [tmpAttrStr release];
                    } else {
                        currentTag = [[BDSKRichTextTag alloc] initWithAttributedText:[template attributedSubstringFromRange:NSMakeRange(start - [STARTTAG_OPEN_DELIM length], [STARTTAG_OPEN_DELIM length])]];
                        [result addObject:currentTag];
                        [currentTag release];
                    }
                    [scanner setScanLocation:start];
                    
                }
            }
        } // scan STARTTAG_OPEN_DELIM
    } // while
    
    [scanner release];
    
    return [result autorelease];    
}

+ (NSAttributedString *)attributedStringFromTemplateArray:(NSArray *)template usingObject:(id)object {
    return [self attributedStringFromTemplateArray:template usingObject:object delegate:nil];
}

+ (NSAttributedString *)attributedStringFromTemplateArray:(NSArray *)template usingObject:(id)object delegate:(id <BDSKTemplateParserDelegate>)delegate {
    NSEnumerator *tagEnum = [template objectEnumerator];
    id tag;
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
    
    while (tag = [tagEnum nextObject]) {
        int type = [(BDSKTag *)tag type];
        id keyValue = nil;
        NSAttributedString *tmpAttrStr = nil;
        
        if (type == BDSKTextTagType) {
            
            [result appendAttributedString:[tag attributedText]];
            
        } else if (type == BDSKValueTagType) {
            
            if (keyValue = [object safeValueForKeyPath:[tag keyPath]]) {
                if ([keyValue isKindOfClass:[NSAttributedString class]]) {
                    tmpAttrStr = [[NSAttributedString alloc] initWithAttributedString:keyValue attributes:[(BDSKRichValueTag *)tag attributes]];
                } else {
                    tmpAttrStr = [[NSAttributedString alloc] initWithString:[keyValue stringDescription] attributes:[(BDSKRichValueTag *)tag attributes]];
                }
                [result appendAttributedString:tmpAttrStr];
                [tmpAttrStr release];
            }
            
        } else if (type == BDSKCollectionTagType) {
            
            keyValue = [object safeValueForKeyPath:[tag keyPath]];
            if ([keyValue respondsToSelector:@selector(objectEnumerator)]) {
                NSEnumerator *itemE = [keyValue objectEnumerator];
                id nextItem, item = [itemE nextObject];
                NSArray *itemTemplate = [[tag itemTemplate] arrayByAddingObjectsFromArray:[tag separatorTemplate]];
                while (item) {
                    nextItem = [itemE nextObject];
                    if (nextItem == nil)
                        itemTemplate = [tag itemTemplate];
                    [delegate templateParserWillParseTemplate:itemTemplate usingObject:item isAttributed:YES];
                    tmpAttrStr = [self attributedStringFromTemplateArray:itemTemplate usingObject:item delegate:delegate];
                    [delegate templateParserDidParseTemplate:itemTemplate usingObject:item isAttributed:YES];
                    if (tmpAttrStr != nil)
                        [result appendAttributedString:tmpAttrStr];
                    item = nextItem;
                }
            }
            
        } else {
            
            NSString *matchString = nil;
            BOOL isMatch;
            NSArray *matchStrings = [tag matchStrings];
            unsigned int i, count = [matchStrings count];
            NSArray *subtemplate = nil;
            
            keyValue = [object safeValueForKeyPath:[tag keyPath]];
            count = [matchStrings count];
            subtemplate = nil;
            for (i = 0; i < count; i++) {
                matchString = [matchStrings objectAtIndex:i];
                if ([matchString hasPrefix:@"$"]) {
                    matchString = [[object safeValueForKeyPath:[matchString substringFromIndex:1]] stringDescription];
                    if (matchString == nil)
                        matchString = @"";
                }
                switch ([tag matchType]) {
                    case BDSKConditionTagMatchEqual:
                        isMatch = [matchString isEqualToString:@""] ? NO == [keyValue isNotEmpty] : [[keyValue stringDescription] caseInsensitiveCompare:matchString] == NSOrderedSame;
                        break;
                    case BDSKConditionTagMatchContain:
                        isMatch = [matchString isEqualToString:@""] ? NO == [keyValue isNotEmpty] : [[keyValue stringDescription] rangeOfString:matchString options:NSCaseInsensitiveSearch].location != NSNotFound;
                        break;
                    case BDSKConditionTagMatchSmaller:
                        isMatch = [matchString isEqualToString:@""] ? NO == [keyValue isNotEmpty] : [[keyValue stringDescription] localizedCaseInsensitiveNumericCompare:matchString] == NSOrderedAscending;
                        break;
                    case BDSKConditionTagMatchSmallerOrEqual:
                        isMatch = [matchString isEqualToString:@""] ? NO == [keyValue isNotEmpty] : [[keyValue stringDescription] localizedCaseInsensitiveNumericCompare:matchString] != NSOrderedDescending;
                        break;
                    default:
                        isMatch = [keyValue isNotEmpty];
                        break;
                }
                if (isMatch) {
                    subtemplate = [tag subtemplateAtIndex:i];
                    break;
                }
            }
            if (subtemplate == nil && [[tag subtemplates] count] > count) {
                subtemplate = [tag subtemplateAtIndex:count];
            }
            if (subtemplate != nil) {
                tmpAttrStr = [self attributedStringFromTemplateArray:subtemplate usingObject:object delegate:delegate];
                [result appendAttributedString:tmpAttrStr];
            }
            
        }
    } // while
    
    [result fixAttributesInRange:NSMakeRange(0, [result length])];
    
    return [result autorelease];    
}

@end


@implementation NSObject (BDSKTemplateParser)

- (NSString *)stringDescription {
    NSString *description = nil;
    if ([self respondsToSelector:@selector(stringValue)])
        description = [self performSelector:@selector(stringValue)];
    return description ? description : [self description];
}

- (BOOL)isNotEmpty {
    return YES;
}

- (id)safeValueForKeyPath:(NSString *)keyPath {
    id value = nil;
    OBPRECONDITION([keyPath isKindOfClass:[NSString class]]);
    @try{ value = [self valueForKeyPath:keyPath]; }
    @catch (id exception) { value = nil; }
    return value;
}

@end


@implementation NSScanner (BDSKTemplateParser)

- (BOOL)scanEmptyLine {
    BOOL foundEndOfLine = NO;
    BOOL foundWhitespace = NO;
    int startLoc = [self scanLocation];
    
    // [self scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil] is much more sensible, but NSScanner creates an autoreleased inverted character set every time you use it, so it's pretty inefficient
    foundWhitespace = [self scanUpToCharactersFromSet:[NSCharacterSet nonWhitespaceCharacterSet] intoString:nil];

    if ([self isAtEnd]) {
        foundEndOfLine = foundWhitespace;
    } else {
        foundEndOfLine = [self scanString:@"\r\n" intoString:nil];
        if (foundEndOfLine == NO) {
            unichar nextChar = [[self string] characterAtIndex:[self scanLocation]];
            if (foundEndOfLine = [[NSCharacterSet newlineCharacterSet] characterIsMember:nextChar])
                [self setScanLocation:[self scanLocation] + 1];
        }
    }
    if (foundEndOfLine == NO && foundWhitespace == YES)
        [self setScanLocation:startLoc];
    return foundEndOfLine;
}

@end


@implementation NSString (BDSKTemplateParser)

- (NSString *)stringDescription
{
    return self;
}

- (NSString *)stringBySurroundingWithSpacesIfNotEmpty 
{ 
    return [self isEqualToString:@""] ? self : [NSString stringWithFormat:@" %@ ", self];
}

- (NSString *)stringByAppendingSpaceIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [self stringByAppendingString:@" "];
}

- (NSString *)stringByAppendingDoubleSpaceIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [self stringByAppendingString:@"  "];
}

- (NSString *)stringByPrependingSpaceIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [NSString stringWithFormat:@" %@", self];
}

- (NSString *)stringByAppendingCommaIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [self stringByAppendingString:@","];
}

- (NSString *)stringByAppendingFullStopIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [self stringByAppendingString:@"."];
}

- (NSString *)stringByAppendingCommaAndSpaceIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [self stringByAppendingString:@", "];
}

- (NSString *)stringByAppendingFullStopAndSpaceIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [self stringByAppendingString:@". "];
}

- (NSString *)stringByPrependingCommaAndSpaceIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [NSString stringWithFormat:@", %@", self];
}

- (NSString *)stringByPrependingFullStopAndSpaceIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [NSString stringWithFormat:@". %@", self];
}

- (NSString *)parenthesizedStringIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [NSString stringWithFormat:@"(%@)", self];
}

- (BOOL)isNotEmpty
{
    return [self isEqualToString:@""] == NO;
}

@end


@implementation NSAttributedString (BDSKTemplateParser)

- (NSString *)stringDescription {
    return [self string];
}

- (BOOL)isNotEmpty
{
    return [self length] > 0;
}

@end

@implementation NSNumber (BDSKTemplateParser)

- (BOOL)isNotEmpty
{
    return [self isEqualToNumber:[NSNumber numberWithBool:NO]] == NO;
}

@end


@implementation NSArray (BDSKTemplateParser)

- (BOOL)isNotEmpty
{
    return [self count] > 0;
}

- (NSString *)componentsJoinedByAnd
{
    return [self componentsJoinedByString:@" and "];
}

- (NSString *)componentsJoinedByForwardSlash
{
    return [self componentsJoinedByString:@"/"];
}

- (NSString *)componentsJoinedByDefaultJoinString
{
    return [self componentsJoinedByString:[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKDefaultArrayJoinStringKey]];
}

- (NSString *)componentsJoinedByCommaAndAmpersand
{
    unsigned count = [self count];
    switch (count) {
        case 0:
            return @"";
        case 1:
            return [self objectAtIndex:0];
        case 2:
            return [NSString stringWithFormat:@"%@ & %@", [self objectAtIndex:0], [self objectAtIndex:1]];
        default:
            return [[[[self subarrayWithRange:NSMakeRange(0, count - 1)] componentsJoinedByComma] stringByAppendingString:@", & "] stringByAppendingString:[self lastObject]];
    }
}

- (NSString *)componentsWithEtAlAfterOne
{
    return [self count] > 1 ? [[self firstObject] stringByAppendingString:@" et al."] : [self firstObject];
}

- (NSString *)componentsJoinedByAndWithSingleEtAlAfterTwo
{
    return [self count] > 2 ? [[self firstObject] stringByAppendingString:@" et al."] : [self componentsJoinedByAnd];
}

- (NSString *)componentsJoinedByCommaAndAndWithSingleEtAlAfterThree
{
    return [self count] > 3 ? [[self firstObject] stringByAppendingString:@" et al."] : [self componentsJoinedByCommaAndAnd];
}

- (NSString *)componentsJoinedByAndWithEtAlAfterTwo
{
    return [self count] > 2 ? [[[self firstTwoObjects] componentsJoinedByComma] stringByAppendingString:@", et al."] : [self componentsJoinedByAnd];
}

- (NSString *)componentsJoinedByCommaAndAndWithEtAlAfterThree
{
    return [self count] > 3 ? [[[self firstThreeObjects] componentsJoinedByComma] stringByAppendingString:@", et al."] : [self componentsJoinedByCommaAndAnd];
}

- (NSString *)componentsJoinedByCommaAndAmpersandWithSingleEtAlAfterFive
{
    return [self count] > 5 ? [[self firstObject] stringByAppendingString:@" et al."] : [self componentsJoinedByCommaAndAmpersand];
}

- (NSString *)componentsJoinedByCommaAndAmpersandWithEtAlAfterSix
{
    return [self count] > 6 ? [[[self firstSixObjects] componentsJoinedByComma] stringByAppendingString:@", et al."] : [self componentsJoinedByCommaAndAmpersand];
}

@end


@implementation NSDictionary (BDSKTemplateParser)

- (BOOL)isNotEmpty
{
    return [self count] > 0;
}

@end


@implementation NSSet (BDSKTemplateParser)

- (BOOL)isNotEmpty
{
    return [self count] > 0;
}

@end


@implementation BibAuthor (BDSKTemplateParser)

- (BOOL)isNotEmpty
{
    return [BibAuthor emptyAuthor] != self;
}

@end

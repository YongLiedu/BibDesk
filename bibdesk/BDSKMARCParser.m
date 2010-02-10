//
//  BDSKMARCParser.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/4/06.
/*
 This software is Copyright (c) 2006-2010
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

#import "BDSKMARCParser.h"
#import "NSString_BDSKExtensions.h"
#import "BDSKTypeManager.h"
#import "BibItem.h"
#import "BDSKAppController.h"
#import "NSScanner_BDSKExtensions.h"
#import <AGRegex/AGRegex.h>
#import "NSError_BDSKExtensions.h"
#import "NSXMLNode_BDSKExtensions.h"

@interface NSString (BDSKMARCParserExtensions)
- (BOOL)isMARCString;
- (BOOL)isFormattedMARCString;
- (BOOL)isMARCXMLString;
- (NSString *)stringByFixingFormattedMARCStart;
- (NSString *)stringByRemovingPunctuationCharactersAndBracketedText;
@end

static void addStringToDictionary(NSString *value, NSMutableDictionary *dict, NSString *tag, NSString *subFieldIndicator, BOOL isUNIMARC);
static void addSubstringToDictionary(NSString *subValue, NSMutableDictionary *pubDict, NSString *tag, NSString *subTag, BOOL isUNIMARC);
static BibItem *createPublicationWithRecord(NSXMLNode *record);

@implementation BDSKMARCParser

+ (BOOL)canParseString:(NSString *)string{
	return [string isMARCString] || [string isFormattedMARCString] || [string isMARCXMLString];
}

+ (NSArray *)itemsFromFormattedMARCString:(NSString *)itemString error:(NSError **)outError{
    // make sure that we only have one type of space and line break to deal with, since HTML copy/paste can have odd whitespace characters
    itemString = [itemString stringByNormalizingSpacesAndLineBreaks];
	
    itemString = [itemString stringByFixingFormattedMARCStart];
    
    AGRegex *regex = [AGRegex regexWithPattern:@"^([ \t]*)1[013]{2}[ \t]*[0-9]{0,1}[0 \t#\\-][ \t]*[^ \t[:alnum:]]a" options:AGRegexMultiline];
    AGRegexMatch *match = [regex findInString:itemString];
    
    if(match == nil){
        if(outError)
            *outError = [NSError localErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Unknown MARC format.", @"Error description")];
        return [NSArray array];
    }
    
    NSUInteger tagStartIndex = [match rangeAtIndex:1].length;
    NSUInteger fieldStartIndex = [match range].length - 2;
    NSString *subFieldIndicator = [[match group] substringWithRange:NSMakeRange(fieldStartIndex, 1)];
    
    BibItem *newBI = nil;
    NSMutableArray *returnArray = [NSMutableArray arrayWithCapacity:10];
	
    NSArray *sourceLines = [itemString sourceLinesBySplittingString];
    
    //dictionary is the publication entry
    NSMutableDictionary *pubDict = [[NSMutableDictionary alloc] init];
    
    NSString *tag = nil;
    NSString *tmpTag = nil;
    NSString *value = nil;
    NSMutableString *mutableValue = [NSMutableString string];
    NSCharacterSet *whitespaceAndNewlineCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    
    for (NSString *sourceLine in sourceLines) {
        
        if([sourceLine length] < tagStartIndex + 3)
            continue;
        
        tmpTag = [sourceLine substringWithRange:NSMakeRange(tagStartIndex, 3)];
        
        if([tmpTag hasPrefix:@" "]){
            // continuation of a value
            
			value = [sourceLine stringByTrimmingCharactersInSet:whitespaceAndNewlineCharacterSet];
            [mutableValue appendString:@" "];
            [mutableValue appendString:value];
            
        }else if([tmpTag isEqualToString:@"LDR"]){
            // start of a new item, first safe the last one
            
            // add the last key/value pair
            if(tag && [mutableValue length])
                addStringToDictionary(mutableValue, pubDict, tag, subFieldIndicator, NO);
            
            if([pubDict count] > 0){
                [pubDict setObject:itemString forKey:BDSKAnnoteString];
                
                newBI = [[BibItem alloc] initWithType:BDSKBookString
                                              citeKey:nil
                                            pubFields:pubDict
                                                isNew:YES];
                [returnArray addObject:newBI];
                [newBI release];
            }
            
            // reset these for the next pub
            [pubDict removeAllObjects];
            
            // we don't care about the rest of the leader
            continue;
            
        }else if([sourceLine length] > fieldStartIndex){
			// first save the last key/value pair if necessary
            
            if(tag && [mutableValue length])
                addStringToDictionary(mutableValue, pubDict, tag, subFieldIndicator, NO);
            
            tag = tmpTag;
            value = [[sourceLine substringFromIndex:fieldStartIndex] stringByTrimmingCharactersInSet:whitespaceAndNewlineCharacterSet];
            [mutableValue setString:value];
            
        }
        
    }
    
    // add the last key/value pair
    if(tag && [mutableValue length])
        addStringToDictionary(mutableValue, pubDict, tag, subFieldIndicator, NO);
	
	// add the last item
	if([pubDict count] > 0){
		
		newBI = [[BibItem alloc] initWithType:BDSKBookString
									  citeKey:nil
									pubFields:pubDict
                                        isNew:YES];
		[returnArray addObject:newBI];
		[newBI release];
	}
    
    [pubDict release];
    return returnArray;
}

+ (NSArray *)itemsFromMARCString:(NSString *)itemString error:(NSError **)outError{
    // make sure that we only have one type of space and line break to deal with, since HTML copy/paste can have odd whitespace characters
    itemString = [itemString stringByNormalizingSpacesAndLineBreaks];
	
    BibItem *newBI = nil;
    NSMutableArray *returnArray = [NSMutableArray arrayWithCapacity:10];
    
    NSString *recordTerminator = [NSString stringWithFormat:@"%C", 0x1D];
    NSString *fieldTerminator = [NSString stringWithFormat:@"%C", 0x1E];
    NSString *subFieldIndicator = [NSString stringWithFormat:@"%C", 0x1F];
	
    BOOL isUNIMARC = [itemString characterAtIndex:23] == ' ';
    
    NSArray *records = [itemString componentsSeparatedByString:recordTerminator];
    
    //dictionary is the publication entry
    NSMutableDictionary *pubDict = [[NSMutableDictionary alloc] init];
    
    NSMutableString *formattedString = [NSMutableString string];
    
    NSArray *fields;
    NSString *tag = nil, *field = nil, *value = nil, *dir = nil;
    NSUInteger base, fieldsStart, i, dirLength;
    BOOL isControlField;
    
    for (NSString *record in records) {
        
        if([record length] < 25)
            continue;
        
        base = [[record substringWithRange:NSMakeRange(12, 5)] integerValue];
        dir = [record substringWithRange:NSMakeRange(24, base - 25)];
        dirLength = [dir length] / 12;
        
        fieldsStart = base + [[dir substringWithRange:NSMakeRange(7, 5)] integerValue];
        fields = [[record substringFromIndex:fieldsStart] componentsSeparatedByString:fieldTerminator];
        
        [formattedString setString:@""];
        [formattedString appendStrings:@"LDR    ", [record substringToIndex:24], @"\n", nil];
        
        for(i = 0; i < dirLength; i++){
            
            if ([fields count] <= i)
                break;
            
            tag = [dir substringWithRange:NSMakeRange(12 * i, 3)];
            field = [fields objectAtIndex:i];
            isControlField = [tag hasPrefix:@"00"];
            
            if (isControlField == NO && [field length] < 2)
                continue;
            
            // the first 2 characters are indicators
            value = [field substringFromIndex:isControlField ? 0 : 2];
            
            addStringToDictionary(value, pubDict, tag, subFieldIndicator, isUNIMARC);
            
            [formattedString appendStrings:tag, @" ", isControlField ? @"  " : [field substringToIndex:2], @" ", nil];
            [formattedString appendStrings:[value stringByReplacingOccurrencesOfString:subFieldIndicator withString:@"$"], @"\n", nil];
        }
        
        if([pubDict count] > 0){
            value = [formattedString copy];
            [pubDict setObject:value forKey:BDSKAnnoteString];
            [value release];
            
            newBI = [[BibItem alloc] initWithType:BDSKBookString
                                          citeKey:nil
                                        pubFields:pubDict
                                            isNew:YES];
            [returnArray addObject:newBI];
            [newBI release];
        }
        
    }
    
    [pubDict release];
    return returnArray;
}

+ (NSArray *)itemsFromMARCXMLString:(NSString *)itemString error:(NSError **)outError{
    NSMutableArray *pubs = [NSMutableArray array];
    NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithXMLString:itemString options:0 error:NULL] autorelease];
    NSXMLElement *root = [doc rootElement];
    NSXMLNode *marcns = [NSXMLNode namespaceWithName:@"marc" stringValue:@"http://www.loc.gov/MARC21/slim"];
    
    // if the XML uses the MARC namespace, we need to add it to the root element, otherwise xpath queries won't know about it
    [root addNamespace:marcns];
    
    NSArray *nodes = [root nodesForXPath:@"//marc:record" error:NULL];
    if ([nodes count] == 0)
        nodes = [root nodesForXPath:@"//record" error:NULL];
    
    for (NSXMLNode *node in nodes) {
        BibItem *pub = createPublicationWithRecord(node);
        [pubs addObject:pub];
        [pub release];
    }
    
    return pubs;
}

+ (NSArray *)itemsFromString:(NSString *)itemString error:(NSError **)outError{
    if([itemString isMARCString]){
        return [self itemsFromMARCString:itemString error:outError];
    }else if([itemString isFormattedMARCString]){
        return [self itemsFromFormattedMARCString:itemString error:outError];
    }else if([itemString isMARCXMLString]){
        return [self itemsFromMARCXMLString:itemString error:outError];
    }else {
        if(outError)
            *outError = [NSError localErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Unknown MARC format.", @"Error description")];
        return [NSArray array];
    }
}

@end

#pragma mark -

static void addStringToDictionary(NSString *value, NSMutableDictionary *pubDict, NSString *tag, NSString *subFieldIndicator, BOOL isUNIMARC){
	unichar subTag = 0;
    NSString *subValue = nil;
	
    NSScanner *scanner = [[NSScanner alloc] initWithString:value];
    
    [scanner setCharactersToBeSkipped:nil];
    
    while([scanner isAtEnd] == NO){
        if(NO == [scanner scanString:subFieldIndicator intoString:NULL] || NO == [scanner scanCharacter:&subTag])
            break;
        
        if([scanner scanUpToString:subFieldIndicator intoString:&subValue]){
            subValue = [subValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            addSubstringToDictionary(subValue, pubDict, tag, [NSString stringWithFormat:@"%C", subTag], isUNIMARC);
        }
    }
    
    [scanner release];
}

#define MARCTitleTag @"245"
#define MARCSubtitleSubTag @"b"
#define MARCPersonTag @"700"
#define MARCNameSubTag @"a"
#define MARCRelatorSubTag @"e"

static void addSubstringToDictionary(NSString *subValue, NSMutableDictionary *pubDict, NSString *tag, NSString *subTag, BOOL isUNIMARC){
    NSString *key = [[[BDSKTypeManager sharedManager] fieldNamesForMARCTag:tag] objectForKey:subTag];
    NSString *tmpValue = nil;
    
    if (isUNIMARC)
        key = [[[BDSKTypeManager sharedManager] fieldNamesForUNIMARCTag:tag] objectForKey:subTag];
    else
        key = [[[BDSKTypeManager sharedManager] fieldNamesForMARCTag:tag] objectForKey:subTag];
    
    if(key == nil)
        return;
    
    subValue = [subValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    tmpValue = [pubDict objectForKey:key];
    
    if(isUNIMARC == NO && [tag isEqualToString:MARCTitleTag]){
        if([subTag isEqualToString:MARCSubtitleSubTag] && tmpValue){
            // this is the subtitle, append it to the title if present
            
            subValue = [NSString stringWithFormat:@"%@: %@", tmpValue, subValue];
            tmpValue = nil;
        }
    }else if(isUNIMARC == NO && [tag isEqualToString:MARCPersonTag]){
        if([subTag isEqualToString:MARCNameSubTag] && tmpValue){
            subValue = [NSString stringWithFormat:@"%@ and %@", tmpValue, subValue];
        }else if([subTag isEqualToString:MARCRelatorSubTag]){
            // this is the person role, see if it is an editor
            if([subValue caseInsensitiveCompare:@"editor"] != NSOrderedSame || tmpValue == nil)
                return;
            NSRange range = [tmpValue rangeOfString:@" and " options:NSBackwardsSearch];
            if(range.location == NSNotFound){
                [pubDict removeObjectForKey:BDSKAuthorString];
                subValue = tmpValue;
            }else{
                [pubDict setObject:[tmpValue substringToIndex:range.location] forKey:BDSKAuthorString];
                subValue = [tmpValue substringFromIndex:NSMaxRange(range)];
            }
            if(tmpValue = [pubDict objectForKey:BDSKEditorString]){
                subValue = [NSString stringWithFormat:@"%@ and %@", tmpValue, subValue];
            }
        }
        tmpValue = nil;
    }else if([key isEqualToString:BDSKAuthorString] && tmpValue){
        subValue = [NSString stringWithFormat:@"%@ and %@", tmpValue, subValue];
    }else if([key isEqualToString:BDSKAnnoteString] && tmpValue){
        subValue = [NSString stringWithFormat:@"%@. %@", tmpValue, subValue];
        tmpValue = nil;
    }else if([key isEqualToString:BDSKYearString]){
        // This is used for stripping extraneous characters from BibTeX year fields
        static AGRegex *findYearRegex = nil;
        if(findYearRegex == nil)
            findYearRegex = [[AGRegex alloc] initWithPattern:@"(.*)(\\d{4})(.*)"];
        subValue = [findYearRegex replaceWithString:@"$2" inString:subValue];
    }
    
    if (tmpValue)
        return;
    
    subValue = [[[subValue stringByRemovingPunctuationCharactersAndBracketedText] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    [pubDict setObject:subValue forKey:key];
    [subValue release];
}


static BibItem *createPublicationWithRecord(NSXMLNode *record) {
    NSMutableDictionary *pubDict = [[NSMutableDictionary alloc] init];
    NSMutableString *formattedString = [[NSMutableString alloc] init];
    NSArray *nodes, *subnodes;
    NSXMLNode *node, *subnode;
    NSString *value, *tag, *subTag, *ind1, *ind2;
    
    nodes = [record nodesForXPath:@"./marc:leader" error:NULL];
    if ([nodes count] == 0)
        nodes = [record nodesForXPath:@"./leader" error:NULL];
    if ([nodes count]) {
        node = [nodes lastObject];
        value = [node stringValue];
        tag = [node stringValueOfAttribute:@"tag"];
        [formattedString appendStrings:@"LDR    ", value, @"\n", nil];
    }
    
    nodes = [record nodesForXPath:@"./marc:controlfield" error:NULL];
    if ([nodes count] == 0)
        nodes = [record nodesForXPath:@"./controlfield" error:NULL];
    for (node in nodes) {
        value = [node stringValue];
        tag = [node stringValueOfAttribute:@"tag"];
        [formattedString appendStrings:tag, @"    ", value, @"\n", nil];
    }
    
    nodes = [record nodesForXPath:@"./marc:datafield" error:NULL];
    if ([nodes count] == 0)
        nodes = [record nodesForXPath:@"./datafield" error:NULL];
    for (node in nodes) {
        tag = [node stringValueOfAttribute:@"tag"];
        ind1 = [node stringValueOfAttribute:@"ind1"] ?: @" ";
        ind2 = [node stringValueOfAttribute:@"ind2"] ?: @" ";
        [formattedString appendStrings:tag, @" ", ind1, ind2, nil];
        
        subnodes = [node nodesForXPath:@"./marc:subfield" error:NULL];
        if ([subnodes count] == 0)
            subnodes = [node nodesForXPath:@"./subfield" error:NULL];
        for (subnode in subnodes) {
            value = [subnode stringValue];
            subTag = [subnode stringValueOfAttribute:@"code"];
            [formattedString appendStrings:@" ", @"$", subTag, @" " , value, nil];
            if (tag && subTag && [value length])
                addSubstringToDictionary(value, pubDict, tag, subTag, NO);
        }
        [formattedString appendString:@"\n"];
    }
    
    [pubDict setObject:formattedString forKey:BDSKAnnoteString];
    [formattedString release];
    
    BibItem *newBI = [[BibItem alloc] initWithType:BDSKBookString
                                           citeKey:nil
                                         pubFields:pubDict
                                             isNew:YES];
    [pubDict release];
    
    return newBI;
}

#pragma mark -

@implementation NSString (BDSKMARCParserExtensions)

// Regexes:
// MARC: @"^[0-9]{5}[a-z]{3}[ a][ a0-9]22[0-9]{5}[ 1-8uz][ a-z][ r]45[ 0A-Z]0([0-9]{12})+%C"
// German libraries are converting from MAB to MARC, but they sometimes just leave the leader from the MAB2 format, so we'll accept that too
// MAB: @"^[0-9]{5}[a-z][a-zA-Z0-9 \\-\\.]{4}[0-9]{7}[a-zA-Z0-9 \\-\\.]{6}[a-z]([0-9]{12})+%C"
// UNIMARC: @"^[0-9]{5}[a-z]{3}[ 012][ a0-9]22[0-9]{5}[ 1-8uz][ a-z][ r]45[ 0A-Z] ([0-9]{12})+%C"
// Formatted MARC: @"^[ \t]*LDR[ \t]+[ \\-0-9]{5}[a-z]{3}[ \\-a][ a\\-0-9]22[ \\-0-9]{5}[ \\-1-8uz][ \\-a-z][ \\-r]45[ 0A-Z]0\n{1,2}[ \t]*[0-9]{3}[ \t]+"

- (BOOL)isMARCString{
    NSUInteger fieldTerminator = 0x1E;
    NSString *pattern = [NSString stringWithFormat:@"^[0-9]{5}[0-9a-zA-Z \\-\\.]{19}([0-9]{12})+%C", fieldTerminator];
    AGRegex *MARCRegex = [AGRegex regexWithPattern:pattern];
    
    return nil != [MARCRegex findInString:self];
}

- (BOOL)isFormattedMARCString{
    AGRegex *regex = [AGRegex regexWithPattern:@"^[ \t]*LDR[ \t]+[ \\-0-9]{5}[a-z]{3}[ \\-a][ a\\-0-9]22[ \\-0-9]{5}[ \\-1-8uz][ \\-a-z][ \\-r]45[ 0A-Z]0\n{1,2}[ \t]*[0-9]{3}[ \t]+" options:AGRegexMultiline];
    NSUInteger maxLen = MIN([self length], (NSUInteger)100);
    return nil != [regex findInString:[[self substringToIndex:maxLen] stringByNormalizingSpacesAndLineBreaks]];
}

- (BOOL)isMARCXMLString{
    AGRegex *regex = [AGRegex regexWithPattern:@"<(marc:)?record( xmlns(:marc)?=\"[^<>\"]*\")?>\n *<(marc:)?leader>[ 0-9]{5}[a-z]{3}[ a]{2}22[ 0-9]{5}[ 1-8uz][ a-z][ r]45[ 0A-Z]0</(marc:)?leader>\n *<(marc:)?controlfield tag=\"00[0-9]\">"];
    NSUInteger maxLen = MIN([self length], (NSUInteger)200);
    return nil != [regex findInString:[[self substringToIndex:maxLen] stringByNormalizingSpacesAndLineBreaks]];
}

- (NSString *)stringByFixingFormattedMARCStart{
    AGRegex *regex = [AGRegex regexWithPattern:@"^[ \t]*LDR[ \t]+[ \\-0-9]{5}[a-z]{3}[ \\-a][ a\\-0-9]22[ \\-0-9]{5}[ \\-1-8uz][ \\-a-z][ \\-r]45[ 0A-Z]0\n{1,2}[ \t]*[0-9]{3}[ \t]+" options:AGRegexMultiline];
    NSUInteger start = [[regex findInString:self] range].location;
    return start == 0 || start == NSNotFound ? self : [self substringFromIndex:start];
}

- (NSString *)stringByRemovingPunctuationCharactersAndBracketedText{
    static NSCharacterSet *punctuationCharacterSet = nil;
    if(punctuationCharacterSet == nil)
        punctuationCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@".,:;/"] retain];
    static NSCharacterSet *bracketCharacterSet = nil;
    if(bracketCharacterSet == nil)
        bracketCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"[]"] retain];
    
    NSString *string = self;
    NSUInteger length = [string length];
    NSRange range = [self rangeOfString:@"["];
    NSUInteger start = range.location;
    if(start != NSNotFound){
        range = [self rangeOfString:@"]" options:0 range:NSMakeRange(start, length - start)];
        if(range.location != NSNotFound){
            NSMutableString *mutString = [string mutableCopy];
            [mutString deleteCharactersInRange:NSMakeRange(start, NSMaxRange(range) - start)];
            CFStringTrimWhitespace((CFMutableStringRef)mutString);
            string = [mutString autorelease];
            length = [string length];
        }
    }
    
    if(length == 0)
        return string;
    NSString *cleanedString = [string stringByReplacingCharactersInSet:bracketCharacterSet withString:@""];
    length = [cleanedString length];
    if([punctuationCharacterSet characterIsMember:[cleanedString characterAtIndex:length - 1]])
        cleanedString = [cleanedString substringToIndex:length - 1];
    return cleanedString;
}

@end

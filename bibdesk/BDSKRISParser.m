//
//  BDSKRISParser.m
//  BibDesk
//
//  Created by Michael McCracken on Sun Nov 16 2003.
/*
 This software is Copyright (c) 2003-2010
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BDSKRISParser.h"
#import "BDSKTypeManager.h"
#import "BibItem.h"
#import "BDSKAppController.h"
#import <AGRegex/AGRegex.h>
#import "NSString_BDSKExtensions.h"
#import "CFString_BDSKExtensions.h"


@interface BDSKRISParser (Private)
+ (void)addString:(NSMutableString *)value toDictionary:(NSMutableDictionary *)pubDict forTag:(NSString *)tag;
+ (NSString *)pubTypeFromDictionary:(NSDictionary *)pubDict;
+ (NSString *)stringByFixingInputString:(NSString *)inputString;
+ (void)fixPublicationDictionary:(NSMutableDictionary *)pubDict;
@end


@implementation BDSKRISParser

+ (BOOL)canParseString:(NSString *)string{
    string = [[string substringToIndex:MIN([string length], (NSUInteger)100)] stringByNormalizingSpacesAndLineBreaks];
    AGRegex *risRegex = [AGRegex regexWithPattern:@"^TY  - [A-Z]+\n[A-Z0-9]{2}  - " options:AGRegexMultiline];
    return nil != [risRegex findInString:string];
}

// The RIS specs can be found at http://www.refman.com/support/risformat_intro.asp

+ (NSArray *)itemsFromString:(NSString *)itemString error:(NSError **)outError{
    
    // make sure that we only have one type of space and line break to deal with, since HTML copy/paste can have odd whitespace characters
    itemString = [itemString stringByNormalizingSpacesAndLineBreaks];
    
    itemString = [self stringByFixingInputString:itemString];
        
    BibItem *newBI = nil;
    NSMutableArray *returnArray = [NSMutableArray arrayWithCapacity:10];
    
    //dictionary is the publication entry
    NSMutableDictionary *pubDict = [[NSMutableDictionary alloc] init];
    
    NSArray *sourceLines = [itemString sourceLinesBySplittingString];
    
    NSString *tag = nil;
    NSString *value = nil;
    NSMutableString *mutableValue = [NSMutableString string];
    NSCharacterSet *whitespaceAndNewlineCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    
    NSSet *tagsNotToConvert = [NSSet setWithObjects:@"UR", @"L1", @"L2", @"L3", @"L4", nil];
    
    for (NSString *sourceLine in sourceLines) {

        if(([sourceLine length] > 5 && [[sourceLine substringWithRange:NSMakeRange(4,2)] isEqualToString:@"- "]) ||
           [sourceLine isEqualToString:@"ER  -"]){
			// this is a "key - value" line
			
			// first save the last key/value pair if necessary
			if(tag && ![tag isEqualToString:@"ER"]){
				[self addString:mutableValue toDictionary:pubDict forTag:tag];
			}
			
			// get the tag...
            tag = [[sourceLine substringWithRange:NSMakeRange(0,4)] 
						stringByTrimmingCharactersInSet:whitespaceAndNewlineCharacterSet];
			
			if([tag isEqualToString:@"ER"]){
				// we are done with this publication
				
				if([[pubDict allKeys] count] > 0){
                    [self fixPublicationDictionary:pubDict];
                    newBI = [[BibItem alloc] initWithType:[self pubTypeFromDictionary:pubDict]
                                                  citeKey:nil
                                                pubFields:pubDict
                                                    isNew:YES];
					[returnArray addObject:newBI];
					[newBI release];
				}
				
				// reset these for the next pub
				[pubDict removeAllObjects];
				
				// we don't care about the rest, ER has no value
				continue;
			}
			
			// get the value...
			value = [[sourceLine substringWithRange:NSMakeRange(6,[sourceLine length]-6)]
						stringByTrimmingCharactersInSet:whitespaceAndNewlineCharacterSet];
			
			// don't convert specials in URL/link fields, bug #1244625
			if(![tagsNotToConvert containsObject:tag])
				value = [value stringByConvertingHTMLToTeX];
		
			[mutableValue setString:value];                
			
		} else {
			// this is a continuation of a multiline value
			[mutableValue appendString:@" "];
			[mutableValue appendString:[sourceLine stringByTrimmingCharactersInSet:whitespaceAndNewlineCharacterSet]];
        }
        
    }
    
    if(outError) *outError = nil;
    
    [pubDict release];
    return returnArray;
}

+ (void)addString:(NSMutableString *)value toDictionary:(NSMutableDictionary *)pubDict forTag:(NSString *)tag;
{
	NSString *key = nil;
	NSString *oldString = nil;
    NSString *newString = nil;
	
    key = [[BDSKTypeManager sharedManager] fieldNameForRISTag:tag] ?: [tag fieldName];
	oldString = [pubDict objectForKey:key];
	
	BOOL isAuthor = [key isPersonField];
    
    // sometimes we have authors as "Feelgood, D.R.", but BibTeX and btparse need "Feelgood, D. R." for parsing
    // this leads to some unnecessary trailing space, though, in some cases (e.g. "Feelgood, D. R. ") so we can
    // either ignore it, be clever and not add it after the last ".", or add it everywhere and collapse it later
    if(isAuthor){
		[value replaceOccurrencesOfString:@"." withString:@". " 
			options:NSLiteralSearch range:NSMakeRange(0, [value length])];
    }
	// concatenate authors and keywords, as they can appear multiple times
	// other duplicates keys should have at least different tags, so we use the tag instead
	if(![NSString isEmptyString:oldString]){
		if(isAuthor){
			if([[oldString componentsSeparatedByString:@" and "] containsObject:value]){
				NSLog(@"Not adding duplicate author %@", value);
			}else{
				newString = [[NSString alloc] initWithFormat:@"%@ and %@", oldString, value];
                // This next step isn't strictly necessary for splitting the names, since the name parsing will do it for us, but you still see duplicate whitespace when editing the author field
                NSString *collapsedWhitespaceString = (NSString *)BDStringCreateByCollapsingAndTrimmingCharactersInSet(NULL, (CFStringRef)newString, (CFCharacterSetRef)[NSCharacterSet whitespaceCharacterSet]);
                [newString release];
                newString = collapsedWhitespaceString;
			}
        } else if([key isSingleValuedField] || [key isURLField]) {
            // for single valued and URL fields, create a new field name
            NSInteger i = 1;
            NSString *newKey = [key stringByAppendingFormat:@"%ld", (long)i];
            while ([pubDict objectForKey:newKey] != nil) {
                i++;
                newKey = [key stringByAppendingFormat:@"%ld", (long)i];
            }
            key = newKey;
            newString = [value copy];
        } else {
			// append to old value, using separator from prefs
            newString = [[NSString alloc] initWithFormat:@"%@%@%@", oldString, [[NSUserDefaults standardUserDefaults] objectForKey:BDSKDefaultGroupFieldSeparatorKey], value];
		}
    }else{
        // the default, just set the value
        newString = [value copy];
    }
    if(newString != nil){
        [pubDict setObject:newString forKey:key];
        [newString release];
    }
}

+ (NSString *)pubTypeFromDictionary:(NSDictionary *)pubDict;
{
    BDSKTypeManager *typeManager = [BDSKTypeManager sharedManager];
    NSString *type = BDSKArticleString;
    if([typeManager bibTeXTypeForRISType:[pubDict objectForKey:@"Ty"]] != nil)
        type = [typeManager bibTeXTypeForRISType:[pubDict objectForKey:@"Ty"]];
    return type;
}

#define RISStartPageString @"Sp"
#define RISEndPageString @"Ep"

+ (void)fixPublicationDictionary:(NSMutableDictionary *)pubDict;
{
    // fix up the page numbers if necessary
    NSString *start = [pubDict objectForKey:RISStartPageString];
    NSString *end = [pubDict objectForKey:RISEndPageString];
    
    if(start != nil && end != nil){
       NSMutableString *merge = [start mutableCopy];
       [merge appendString:@"--"];
       [merge appendString:end];
       [pubDict setObject:merge forKey:BDSKPagesString];
       [merge release];
       
       [pubDict removeObjectForKey:RISStartPageString];
       [pubDict removeObjectForKey:RISEndPageString];
	}
    
    // the PY field should have the format YYYY/MM/DD/part, but may only contain the year
    NSString *date = [[[pubDict objectForKey:BDSKYearString] retain] autorelease];
    
    if (date) {
        NSUInteger first = NSNotFound, second = NSNotFound, third = NSNotFound, length = [date length];
        first = [date rangeOfString:@"/"].location;
        if (first != NSNotFound && first + 1 < length) {
            second = [date rangeOfString:@"/" options:0 range:NSMakeRange(first + 1, length - first - 1)].location;
            if (second != NSNotFound && second + 1 < length)
                third = [date rangeOfString:@"/" options:0 range:NSMakeRange(second + 1, length - second - 1)].location;
        }
        if (first != NSNotFound) {
            if ([pubDict objectForKey:BDSKDateString] == nil)
                [pubDict setObject:date forKey:BDSKDateString];
            [pubDict setObject:[date substringToIndex:first] forKey:BDSKYearString];
            if (second != NSNotFound) {
                if ([pubDict objectForKey:BDSKMonthString] == nil) {
                    if (second > first + 1)
                        [pubDict setObject:[date substringWithRange:NSMakeRange(first + 1, second - first - 1)] forKey:BDSKMonthString];
                    else if (third != NSNotFound && third < length - 1)
                        [pubDict setObject:[date substringWithRange:NSMakeRange(third + 1, length - third - 1)] forKey:BDSKMonthString];
                }
                if (third != NSNotFound && third > second + 1 && [pubDict objectForKey:@"Day"] == nil)
                    [pubDict setObject:[date substringWithRange:NSMakeRange(second + 1, third - second - 1)] forKey:@"Day"];
            }
        }
    }
}

+ (NSString *)stringByFixingInputString:(NSString *)inputString;
{
    // Some sources add extra lines with some context info before the entries
    AGRegex *risRegex = [AGRegex regexWithPattern:@"^TY  - [A-Z]+\n[A-Z0-9]{2}  - " options:AGRegexMultiline];
    AGRegexMatch *match = [risRegex findInString:inputString];
    if (match)
        inputString = [inputString substringFromIndex:[match range].location];
    
    // Scopus doesn't put the end tag ER on a separate line.
    AGRegex *endTag = [AGRegex regexWithPattern:@"([^\r\n])ER  - $" options:AGRegexMultiline];
    return [endTag replaceWithString:@"$1\r\nER  - " inString:inputString];
}

@end

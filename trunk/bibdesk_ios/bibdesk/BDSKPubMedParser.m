//
//  BDSKPubMedParser.m
//  BibDesk
//
//  Created by Michael McCracken on Sun Nov 16 2003.
/*
 This software is Copyright (c) 2003-2012
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

#import "BDSKPubMedParser.h"
#import "BDSKTypeManager.h"
#import "BibItem.h"
#import "BDSKAppController.h"
#import <AGRegex/AGRegex.h>
#import "NSString_BDSKExtensions.h"
#import "CFString_BDSKExtensions.h"


@interface BDSKPubMedParser (Private)
+ (void)addString:(NSMutableString *)value toDictionary:(NSMutableDictionary *)pubDict forTag:(NSString *)tag;
+ (NSString *)pubTypeFromDictionary:(NSDictionary *)pubDict;
+ (NSString *)stringByFixingInputString:(NSString *)inputString;
+ (void)fixPublicationDictionary:(NSMutableDictionary *)pubDict;
@end


@implementation BDSKPubMedParser

+ (BOOL)canParseString:(NSString *)string{
    NSScanner *scanner = [[NSScanner alloc] initWithString:string];
    [scanner setCharactersToBeSkipped:nil];
    BOOL isPubMed = NO;
    
    // skip leading whitespace
    [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
    
    if([scanner scanString:@"PMID-" intoString:nil] &&
       [scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil]) // for Medline
        isPubMed = YES;
    [scanner release];
    return isPubMed;
}

// The Medline specs can be found at http://www.nlm.nih.gov/bsd/mms/medlineelements.html

+ (NSArray *)itemsFromString:(NSString *)itemString error:(NSError **)outError{
    
    // make sure that we only have one type of space and line break to deal with, since HTML copy/paste can have odd whitespace characters
    itemString = [itemString stringByNormalizingSpacesAndLineBreaks];
    
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

        if([sourceLine length] > 5 && [[sourceLine substringWithRange:NSMakeRange(4,2)] isEqualToString:@"- "]){
			// this is a "key - value" line
			
			// first save the last key/value pair if necessary
			if(tag)
				[self addString:mutableValue toDictionary:pubDict forTag:tag];
			
			// get the tag...
            tag = [[sourceLine substringWithRange:NSMakeRange(0,4)] 
						stringByTrimmingCharactersInSet:whitespaceAndNewlineCharacterSet];
			
			if([tag isEqualToString:@"PMID"]){
				// we are done with the previous publication
				
				if([pubDict count] > 0){
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
    
    // add the last item
    if([pubDict count] > 0){
        [self fixPublicationDictionary:pubDict];
        newBI = [[BibItem alloc] initWithType:[self pubTypeFromDictionary:pubDict]
                                      citeKey:nil
                                    pubFields:pubDict
                                        isNew:YES];
        [returnArray addObject:newBI];
        [newBI release];
    }
    
    if(outError) *outError = nil;
    
    [pubDict release];
    return returnArray;
}

+ (void)addString:(NSMutableString *)value toDictionary:(NSMutableDictionary *)pubDict forTag:(NSString *)tag;
{
	NSString *key = [[BDSKTypeManager sharedManager] fieldNameForPubMedTag:tag];
	BOOL isAuthor = [key isPersonField];
	NSString *oldString = nil;
    NSString *newString = nil;
    
	// we handle fieldnames for authors later, as FAU can duplicate AU
    if(key == nil || [key isEqualToString:BDSKAuthorString]) key = [tag fieldName];
	oldString = [pubDict objectForKey:key];
	
    // sometimes we have authors as "Feelgood, D.R.", but BibTeX and btparse need "Feelgood, D. R." for parsing
    // this leads to some unnecessary trailing space, though, in some cases (e.g. "Feelgood, D. R. ") so we can
    // either ignore it, be clever and not add it after the last ".", or add it everywhere and collapse it later
    if(isAuthor){
		[value replaceOccurrencesOfString:@"." withString:@". " 
			options:NSLiteralSearch range:NSMakeRange(0, [value length])];
        // see bug #1584054, PubMed now doesn't use a comma between the lastName and the firstName
        // this should be OK for valid RIS, as that should be in the format "last, first"
        NSInteger lastSpace = [value rangeOfString:@" " options:NSBackwardsSearch].location;
        if([value rangeOfString:@","].location == NSNotFound && lastSpace != NSNotFound)
            [value insertString:@"," atIndex:lastSpace];
    }
    
    // the AID tag contains links like DOI, and looks like "10.1038/ng1726 [doi]", note we have ecaped "[" to "{$[$}"
    if([key isEqualToString:@"Aid"]){
        AGRegex *aidRegex = [AGRegex regexWithPattern:@"(.+) {\\$\\[\\$}(\\w+){\\$\\]\\$}$"];
        AGRegexMatch *match = [aidRegex findInString:value];
        if(match){
            key = [[match groupAtIndex:2] fieldName];
            [value setString:[match groupAtIndex:1]];
            oldString = [pubDict objectForKey:key];
        }
    }
    
	// concatenate authors and keywords, as they can appear multiple times
	// other duplicates keys should have at least different tags, so we use the tag instead
	if(![NSString isEmptyString:oldString]){
		if(isAuthor){
            newString = [[NSString alloc] initWithFormat:@"%@ and %@", oldString, value];
            // This next step isn't strictly necessary for splitting the names, since the name parsing will do it for us, but you still see duplicate whitespace when editing the author field
            NSString *collapsedWhitespaceString = (NSString *)BDStringCreateByCollapsingAndTrimmingCharactersInSet(NULL, (CFStringRef)newString, (CFCharacterSetRef)[NSCharacterSet whitespaceCharacterSet]);
            [newString release];
            newString = collapsedWhitespaceString;
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
    if([typeManager bibTeXTypeForPubMedType:[pubDict objectForKey:@"Pt"]] != nil)
        type = [typeManager bibTeXTypeForPubMedType:[pubDict objectForKey:@"Pt"]];
    return type;
}

+ (void)fixPublicationDictionary:(NSMutableDictionary *)pubDict;
{
    // choose the authors from the FAU or AU or CN tag as available
    NSString *authors;
    
    if(authors = [pubDict objectForKey:@"Fau"]){
        [pubDict setObject:authors forKey:BDSKAuthorString];
		[pubDict removeObjectForKey:@"Fau"];
		[pubDict removeObjectForKey:@"Au"];
    }else if(authors = [pubDict objectForKey:@"Au"]){
        [pubDict setObject:authors forKey:BDSKAuthorString];
		[pubDict removeObjectForKey:@"Au"];
    }else if(authors = [pubDict objectForKey:@"Cn"]){
        [pubDict setObject:authors forKey:BDSKAuthorString];
		[pubDict removeObjectForKey:@"Cn"];
	}
    
    NSString *pages = [pubDict objectForKey:BDSKPagesString];
    if(pages){
        AGRegex *pagesRegex = [AGRegex regexWithPattern:@"^([0-9]*)-([0-9]*)?"];
        AGRegexMatch *match = [pagesRegex findInString:pages];
        if([match count] == 3){
            NSMutableString *page = [[match groupAtIndex:1] mutableCopy];
            NSString *endPage = [match groupAtIndex:2];
            [page appendString:@"--"];
            if([page length] - 2 > [endPage length])
                [page appendString:[page substringToIndex:[page length] - [endPage length] - 2]];
            [page appendString:endPage];
            [pubDict setObject:page forKey:BDSKPagesString];
            [page release];
        }
    }
    
    NSString *date = [pubDict objectForKey:BDSKDateString];
    if (date != nil) {
        // the DP field should be something like "2001", "2001 Apr", "2001 Apr 15", "2001 Apr-May", or "2001 Spring"
        NSArray *dateComponents = [date componentsSeparatedByString:@" "];
        
        // Provide a valid year from the date
        if ([pubDict objectForKey:BDSKYearString] == nil) {
            if ([dateComponents count] > 0)
                [pubDict setObject:[dateComponents objectAtIndex:0] forKey:BDSKYearString];
            else
                [pubDict setObject:date forKey:BDSKYearString];
        }
        // Provide a valid month from the date
        if ([pubDict objectForKey:BDSKMonthString] == nil && [dateComponents count] > 1)
            [pubDict setObject:[dateComponents objectAtIndex:1] forKey:BDSKMonthString];
    }
}

@end

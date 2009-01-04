//
//  BDSKPubMedParser.m
//  BibDesk
//
//  Created by Michael McCracken on Sun Nov 16 2003.
/*
 This software is Copyright (c) 2003-2008
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
    
    itemString = [self stringByFixingInputString:itemString];
        
    BibItem *newBI = nil;
    NSMutableArray *returnArray = [NSMutableArray arrayWithCapacity:10];
    
    //dictionary is the publication entry
    NSMutableDictionary *pubDict = [[NSMutableDictionary alloc] init];
    
    NSArray *sourceLines = [itemString sourceLinesBySplittingString];
    
    NSEnumerator *sourceLineE = [sourceLines objectEnumerator];
    NSString *sourceLine = nil;
    
    NSString *tag = nil;
    NSString *value = nil;
    NSMutableString *mutableValue = [NSMutableString string];
    NSCharacterSet *whitespaceAndNewlineCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    
    NSSet *tagsNotToConvert = [NSSet setWithObjects:@"UR", @"L1", @"L2", @"L3", @"L4", nil];
    
    while(sourceLine = [sourceLineE nextObject]){

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
                                                 fileType:BDSKBibtexString
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
	
	// we handle fieldnames for authors later, as FAU can duplicate AU. All others are treated as AU. 
	if([tag isEqualToString:@"A1"] || [tag isEqualToString:@"A2"] || [tag isEqualToString:@"A3"])
		tag = @"AU";
    // PubMed uses IP for issue number and IS for ISBN
    if([tag isEqualToString:@"IP"])
        key = BDSKNumberString;
    else if([tag isEqualToString:@"IS"])
        key = @"Issn";
	else
        key = [[BDSKTypeManager sharedManager] fieldNameForPubMedTag:tag];
    if(key == nil || [key isEqualToString:BDSKAuthorString]) key = [tag fieldName];
	oldString = [pubDict objectForKey:key];
	
	BOOL isAuthor = ([key isEqualToString:@"Fau"] ||
					 [key isEqualToString:@"Au"] ||
					 [key isEqualToString:BDSKEditorString]);
    
    // sometimes we have authors as "Feelgood, D.R.", but BibTeX and btparse need "Feelgood, D. R." for parsing
    // this leads to some unnecessary trailing space, though, in some cases (e.g. "Feelgood, D. R. ") so we can
    // either ignore it, be clever and not add it after the last ".", or add it everywhere and collapse it later
    if(isAuthor){
		[value replaceOccurrencesOfString:@"." withString:@". " 
			options:NSLiteralSearch range:NSMakeRange(0, [value length])];
        // see bug #1584054, PubMed now doesn't use a comma between the lastName and the firstName
        // this should be OK for valid RIS, as that should be in the format "last, first"
        int lastSpace = [value rangeOfString:@" " options:NSBackwardsSearch].location;
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
            NSString *collapsedWhitespaceString = (NSString *)BDStringCreateByCollapsingAndTrimmingWhitespace(NULL, (CFStringRef)newString);
            [newString release];
            newString = collapsedWhitespaceString;
        } else if([key isSingleValuedField] || [key isURLField]) {
            // for single valued and URL fields, create a new field name
            int i = 1;
            NSString *newKey = [key stringByAppendingFormat:@"%d", i];
            while ([pubDict objectForKey:newKey] != nil) {
                i++;
                newKey = [key stringByAppendingFormat:@"%d", i];
            }
            key = newKey;
            newString = [value copy];
        } else {
			// append to old value, using separator from prefs
            newString = [[NSString alloc] initWithFormat:@"%@%@%@", oldString, [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKDefaultGroupFieldSeparatorKey], value];
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
    if([typeManager bibtexTypeForPubMedType:[pubDict objectForKey:@"Pt"]] != nil)
        type = [typeManager bibtexTypeForPubMedType:[pubDict objectForKey:@"Pt"]];
    return type;
}

+ (void)fixPublicationDictionary:(NSMutableDictionary *)pubDict;
{
    // choose the authors from the FAU or AU tag as available
    NSString *authors;
    
    if(authors = [pubDict objectForKey:@"Fau"]){
        [pubDict setObject:authors forKey:BDSKAuthorString];
		[pubDict removeObjectForKey:@"Fau"];
		// should we remove the AU also?
    }else if(authors = [pubDict objectForKey:@"Au"]){
        [pubDict setObject:authors forKey:BDSKAuthorString];
		[pubDict removeObjectForKey:@"Au"];
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
    
    NSString *date = [pubDict objectForKey:@"Dp"];
    if (date != nil) {
        AGRegex *dateRegex = [AGRegex regexWithPattern:@"^([1-9][0-9]{3})\\s*(([A-Z][a-z]{2}){0,1}\\s*([1-9][0-9]{0,1}){0,1})"];
        AGRegexMatch *dateMatch = [dateRegex findInString:date];
        
        // Provide a valid year from DP
        if ([pubDict objectForKey:BDSKYearString] == nil) {
            if ([dateMatch count] > 1)
                [pubDict setObject:[dateMatch groupAtIndex:1] forKey:BDSKYearString];
            else
                [pubDict setObject:date forKey:BDSKYearString];
        }
        // Provide a valid month from DP
        if ([pubDict objectForKey:BDSKMonthString] == nil && [dateMatch count] > 2)
            [pubDict setObject:[dateMatch groupAtIndex:2] forKey:BDSKMonthString];
        [pubDict removeObjectForKey:@"Dp"];
    }
}

// Adds ER tags to a stream of PubMed records, so it's (more) valid RIS
+ (NSString *)stringByFixingInputString:(NSString *)inputString;
{
    OFStringScanner *scanner = [[OFStringScanner alloc] initWithString:inputString];
    NSMutableString *fixedString = [[NSMutableString alloc] initWithCapacity:[inputString length]];
    
    NSString *scannedString = [scanner readFullTokenUpToString:@"PMID- "];
    unsigned start;
    unichar prevChar;
    BOOL scannedPMID = NO;
    
    // this means we scanned some garbage before the PMID tag, or else this isn't a PubMed string...
    OBPRECONDITION([NSString isEmptyString:scannedString]);
    
    do {
        
        start = scannerScanLocation(scanner);
        
        // scan past the PMID tag
        scannedPMID = scannerReadString(scanner, @"PMID- ");
        OBPRECONDITION(scannedPMID);
        
        // scan to the next PMID tag
        scannedString = [scanner readFullTokenUpToString:@"PMID- "];
        [fixedString appendString:[inputString substringWithRange:NSMakeRange(start, scannerScanLocation(scanner) - start)]];
        
        // see if the previous character is a newline; if not, then some clod put a "PMID- " in the text
        if(scannerScanLocation(scanner)){
            prevChar = *(scanner->scanLocation - 1);
            if(BDIsNewlineCharacter(prevChar))
                [fixedString appendString:@"ER  - \r\n"];
            // if we're operating on a text selection, it may not have a trailing newline
            else if (scannerHasData(scanner) == NO)
                [fixedString appendString:@"\r\nER  - \r\n"];
        }
        
        OBASSERT(scannedString);
        
    } while(scannerHasData(scanner));
    
    OBPOSTCONDITION(!scannerHasData(scanner));
    
    [scanner release];
    OBPOSTCONDITION(![NSString isEmptyString:fixedString]);
    
#if OMNI_FORCE_ASSERTIONS
    // Here's our reference method, which caused swap death on large strings (AGRegex uses a lot of autoreleased NSData objects)
	NSString *tmpStr;
	
    AGRegex *regex = [AGRegex regexWithPattern:@"(?<!\\A)^PMID- " options:AGRegexMultiline];
    tmpStr = [regex replaceWithString:@"ER  - \r\nPMID- " inString:inputString];
	
    tmpStr = [tmpStr stringByAppendingString:@"ER  - \r\n"];
    OBPOSTCONDITION([tmpStr isEqualToString:fixedString]);
#endif
    
    return [fixedString autorelease];
}

@end

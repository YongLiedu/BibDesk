//
//  BDSKRISParser.m
//  BibDesk
//
//  Created by Michael McCracken on Sun Nov 16 2003.
/*
 This software is Copyright (c) 2003,2004,2005,2006
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
#import "BibTypeManager.h"
#import "BibItem.h"
#import "BibAppController.h"
#import <AGRegex/AGRegex.h>
#import "NSString_BDSKExtensions.h"


@interface NSString (RISExtensions)
- (NSString *)stringByFixingReferenceMinerString;
- (NSString *)stringByFixingScopusEndTags;

@end


@interface BDSKRISParser (Private)

/*!
@function	addStringToDict
 @abstract   Used to add additional strings to an existing dictionary entry.
 @discussion This is useful for multiple authors and multiple keywords, so we don't wipe them out by overwriting.
 @param      wholeValue String object that we are adding (e.g. <tt>Ann Author</tt>).
 @param	pubDict NSMutableDictionary containing the current publication.
 @param	theKey NSString object with the key that we are adding an item to (e.g. <tt>Author</tt>).
 */
static void addStringToDict(NSMutableString *wholeValue, NSMutableDictionary *pubDict, NSString *theKey);
/*!
@function   isDuplicateAuthor
 @abstract   Check to see if we have a duplicate author in the list
 @discussion Some online databases (Scopus in particular) give us RIS with multiple instances of the same author.
 BibTeX accepts this, and happily prints out duplicate author names.  This isn't a very robust check.
 @param      oldList Existing author list in the dictionary
 @param      newAuthor The author that we want to add
 @result     Returns YES if it's a duplicate
 */
static BOOL isDuplicateAuthor(NSString *oldList, NSString *newAuthor);
/*!
@function   mergePageNumbers
 @abstract   Elsevier/ScienceDirect RIS output has SP for start page and EP for end page.  If we find
 both of those in the entry, we merge them and add them back into the dictionary as
 SP--EP forKey:Pages.
 @param      dict NSMutableDictionary containing a single RIS bibliography entry
 */
static void mergePageNumbers(NSMutableDictionary *dict);

// creates a new BibItem from the dictionary
// caller is responsible for releasing the returned item
static BibItem *createBibItemWithRISDictionary(NSMutableDictionary *pubDict);
@end

@implementation BDSKRISParser

+ (NSMutableArray *)itemsFromString:(NSString *)itemString
                              error:(NSError **)outError{
    return [BDSKRISParser itemsFromString:itemString error:outError frontMatter:nil filePath:BDSKParserPasteDragString];
}

+ (NSMutableArray *)itemsFromString:(NSString *)itemString
                              error:(NSError **)outError
                        frontMatter:(NSMutableString *)frontMatter
                           filePath:(NSString *)filePath{
    
    // get rid of any leading whitespace or newlines, so our range checks at the beginning are more reliable
    // don't trim trailing whitespace/newlines, since that breaks parsing RIS (possibly the RIS end tag regex?)
    itemString = [itemString stringByTrimmingPrefixCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // make sure that we only have one type of space and line break to deal with, since HTML copy/paste can have odd whitespace characters
    itemString = [itemString stringByNormalizingSpacesAndLineBreaks];
    
    if([itemString rangeOfString:@"Amazon" options:0 range:NSMakeRange(0,6)].location != NSNotFound)
        itemString = [itemString stringByFixingReferenceMinerString]; // run a crude hack for fixing the broken RIS that we get for Amazon entries from Reference Miner
    
    itemString = [itemString stringByFixingScopusEndTags];
        
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
    BibTypeManager *typeManager = [BibTypeManager sharedManager];
    NSCharacterSet *whitespaceAndNewlineCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    
    NSSet *tagsNotToConvert = [NSSet setWithObjects:@"UR", @"L1", @"L2", @"L3", @"L4", nil];
    
    // This is used for stripping extraneous characters from BibTeX year fields
    AGRegex *findYearString = [AGRegex regexWithPattern:@"(.*)(\\d{4})(.*)"];
    
    while(sourceLine = [sourceLineE nextObject]){

        if(([sourceLine length] > 5 && [[sourceLine substringWithRange:NSMakeRange(4,2)] isEqualToString:@"- "]) ||
           [sourceLine isEqualToString:@"ER  -"]){
			// this is a "key - value" line
			
			// first save the last key/value pair if necessary
			if(tag && ![tag isEqualToString:@"ER"]){
				addStringToDict(mutableValue, pubDict, tag);
			}
			
			// get the tag...
            tag = [[sourceLine substringWithRange:NSMakeRange(0,4)] 
						stringByTrimmingCharactersInSet:whitespaceAndNewlineCharacterSet];
			
			if([tag isEqualToString:@"ER"]){
				// we are done with this publication
				
				if([[pubDict allKeys] count] > 0){
					newBI = createBibItemWithRISDictionary(pubDict);
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
		
			// Scopus returns a PY with //// after it.  Others may return a full date, where BibTeX wants a year.  
			// Use a regex to find a substring with four consecutive digits and use that instead.  Not sure how robust this is.
			if([[typeManager fieldNameForPubMedTag:tag] isEqualToString:BDSKYearString])
				value = [findYearString replaceWithString:@"$2" inString:value];
			
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

@end

@implementation BDSKRISParser (Private)

static void addStringToDict(NSMutableString *value, NSMutableDictionary *pubDict, NSString *tag){
	NSString *key = nil;
	NSString *oldString = nil;
    NSString *newString = nil;
	
	// we handle fieldnames for authors later, as FAU can duplicate AU. All others are treated as AU. 
	if([tag isEqualToString:@"A1"] || [tag isEqualToString:@"A2"] || [tag isEqualToString:@"A3"])
		tag = @"AU";
    // most RIS uses IS for issue number
    if([tag isEqualToString:@"IS"])
        key = BDSKNumberString;
	else
        key = [[BibTypeManager sharedManager] fieldNameForPubMedTag:tag];
	if(key == nil) key = [tag capitalizedString];
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
			if(isDuplicateAuthor(oldString, value)){
				NSLog(@"Not adding duplicate author %@", value);
			}else{
				newString = [[NSString alloc] initWithFormat:@"%@ and %@", oldString, value];
                // This next step isn't strictly necessary for splitting the names, since the name parsing will do it for us, but you still see duplicate whitespace when editing the author field
                NSString *collapsedWhitespaceString = (NSString *)BDStringCreateByCollapsingAndTrimmingWhitespace(NULL, (CFStringRef)newString);
                [newString release];
                newString = collapsedWhitespaceString;
			}
        }else if([key isEqualToString:BDSKKeywordsString]){
            newString = [[NSString alloc] initWithFormat:@"%@, %@", oldString, value];
		}else{
			// we already had a tag mapping to the same fieldname, so use the tag instead
			key = [tag capitalizedString];
            oldString = [pubDict objectForKey:key];
            if (![NSString isEmptyString:oldString]){
                newString = [[NSString alloc] initWithFormat:@"%@, %@", oldString, value];
            }else{
                newString = [value copy];
            }
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

static BOOL isDuplicateAuthor(NSString *oldList, NSString *newAuthor){ // check to see if it's a duplicate; this relies on the whitespace around the " and ", and is basically a hack for Scopus
    NSArray *oldAuthArray = [oldList componentsSeparatedByString:@" and "];
    return [oldAuthArray containsObject:newAuthor];
}

static BibItem *createBibItemWithRISDictionary(NSMutableDictionary *pubDict)
{
    
    BibTypeManager *typeManager = [BibTypeManager sharedManager];
    BibItem *newBI = nil;
    NSString *type = BDSKArticleString;
    
    // fix up the page numbers if necessary
    mergePageNumbers(pubDict);
	
    // set the pub type if we know the bibtex equivalent, otherwise leave it as misc
    if([typeManager bibtexTypeForPubMedType:[pubDict objectForKey:@"Ty"]] != nil)
        type = [typeManager bibtexTypeForPubMedType:[pubDict objectForKey:@"Ty"]];
    
    newBI = [[BibItem alloc] initWithType:type
								 fileType:BDSKBibtexString
								  citeKey:nil
								pubFields:pubDict
                                    isNew:YES];
    
    return newBI;
}

static NSString *RISStartPageString = @"Sp";
static NSString *RISEndPageString = @"Ep";

static void mergePageNumbers(NSMutableDictionary *dict)
{
    NSString *start = [dict objectForKey:RISStartPageString];
    NSString *end = [dict objectForKey:RISEndPageString];
    
    if(start != nil && end != nil){
       NSMutableString *merge = [start mutableCopy];
       [merge appendString:@"--"];
       [merge appendString:end];
       [dict setObject:merge forKey:BDSKPagesString];
       [merge release];
       
       [dict removeObjectForKey:RISStartPageString];
       [dict removeObjectForKey:RISEndPageString];
	}
}

@end

@implementation NSString (RISExtensions)

- (NSString *)stringByFixingReferenceMinerString;
{
    //
    // For cleaning up reference miner output for Amazon references.  Use an NSLog to see
    // what it's giving us, then compare with <http://www.refman.com/support/risformat_intro.asp>.  We'll
    // fix it up enough to separate the references and save typing the author/title, but the date is just
    // too messed up to bother with.
    //
	NSString *tmpStr;
	
    // this is what Ref Miner uses to mark the beginning; should be TY key instead, so we'll fake it; this means the actual type doesn't get set
    AGRegex *start = [AGRegex regexWithPattern:@"^Amazon,RM[0-9]{3}," options:AGRegexMultiline];
    tmpStr = [start replaceWithString:@"" inString:self];
    
    start = [AGRegex regexWithPattern:@"^ITEM" options:AGRegexMultiline];
    tmpStr = [start replaceWithString:@"TY  - " inString:tmpStr];
    
    // special case for handling the url; others we just won't worry about
    AGRegex *url = [AGRegex regexWithPattern:@"^URL- " options:AGRegexMultiline];
    tmpStr = [url replaceWithString:@"UR  - " inString:tmpStr];
    
    AGRegex *tag2Regex = [AGRegex regexWithPattern:@"^([A-Z]{2})- " options:AGRegexMultiline];
    tmpStr = [tag2Regex replaceWithString:@"$1  - " inString:tmpStr];
    
    AGRegex *tag3Regex = [AGRegex regexWithPattern:@"^([A-Z]{3})- " options:AGRegexMultiline];
    tmpStr = [tag3Regex replaceWithString:@"$1 - " inString:tmpStr];
    
    AGRegex *ends = [AGRegex regexWithPattern:@"(?<!\\A)^TY  - " options:AGRegexMultiline];
    tmpStr = [ends replaceWithString:@"ER  - \r\nTY  - " inString:tmpStr];
	
    return [tmpStr stringByAppendingString:@"\r\nER  - "];	
}

- (NSString *)stringByFixingScopusEndTags;
{    
    // Scopus doesn't put the end tag RE on a separate line.
    AGRegex *endTag = [AGRegex regexWithPattern:@"([^\r\n])ER  - $" options:AGRegexMultiline];
    return [endTag replaceWithString:@"$1\r\nER  - " inString:self];
}

@end

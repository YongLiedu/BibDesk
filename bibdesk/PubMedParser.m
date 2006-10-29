//
//  PubMedParser.m
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

#import "PubMedParser.h"
#import "BibTypeManager.h"
#import "BibItem.h"
#import "BibAppController.h"
#import <AGRegex/AGRegex.h>
#import "NSString_BDSKExtensions.h"


@interface NSString (PubMedExtensions)
/*!
@method     stringByAddingRISEndTagsToPubMedString
@abstract   Adds ER tags to a stream of PubMed records, so it's (more) valid RIS
@discussion (comprehensive description)
@result     (description)
*/
- (NSString *)stringByAddingRISEndTagsToPubMedString;
@end


@interface PubMedParser (Private)

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
@function   chooseAuthors
 @abstract   PubMed has full author tags (FAU) which duplicate the AU. If available, we use those 
 for the Author field as it contains more information, otherwise we take AU. 
 @param      dict NSMutableDictionary containing a single RIS bibliography entry
 */
static void chooseAuthors(NSMutableDictionary *dict);

// creates a new BibItem from the dictionary
// caller is responsible for releasing the returned item
static BibItem *createBibItemWithPubMedDictionary(NSMutableDictionary *pubDict);
@end


@implementation PubMedParser

+ (NSMutableArray *)itemsFromString:(NSString *)itemString
                              error:(NSError **)outError{
    return [PubMedParser itemsFromString:itemString error:outError frontMatter:nil filePath:BDSKParserPasteDragString];
}

+ (NSMutableArray *)itemsFromString:(NSString *)itemString
                              error:(NSError **)outError
                        frontMatter:(NSMutableString *)frontMatter
                           filePath:(NSString *)filePath{
    
    // make sure that we only have one type of space and line break to deal with, since HTML copy/paste can have odd whitespace characters
    itemString = [itemString stringByNormalizingSpacesAndLineBreaks];
    
    itemString = [itemString stringByAddingRISEndTagsToPubMedString];
        
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
					newBI = createBibItemWithPubMedDictionary(pubDict);
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

@implementation PubMedParser (Private)

static void addStringToDict(NSMutableString *value, NSMutableDictionary *pubDict, NSString *tag){
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
        key = [[BibTypeManager sharedManager] fieldNameForPubMedTag:tag];
    if(key == nil || [key isEqualToString:BDSKAuthorString]) key = [tag capitalizedString];
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
        int firstSpace = [value rangeOfString:@" "].location;
        if([value rangeOfString:@","].location == NSNotFound && firstSpace != NSNotFound)
            [value insertString:@"," atIndex:firstSpace];
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

static void chooseAuthors(NSMutableDictionary *dict){
    NSString *authors;
    
    if(authors = [dict objectForKey:@"Fau"]){
        [dict setObject:authors forKey:BDSKAuthorString];
		[dict removeObjectForKey:@"Fau"];
		// should we remove the AU also?
    }else if(authors = [dict objectForKey:@"Au"]){
        [dict setObject:authors forKey:BDSKAuthorString];
		[dict removeObjectForKey:@"Au"];
	}
}

static BibItem *createBibItemWithPubMedDictionary(NSMutableDictionary *pubDict)
{
    
    BibTypeManager *typeManager = [BibTypeManager sharedManager];
    BibItem *newBI = nil;
    NSString *type = BDSKArticleString;
    
	// choose the authors from the FAU or AU tag as available
    chooseAuthors(pubDict);
	
    // set the pub type if we know the bibtex equivalent, otherwise leave it as misc
    if([typeManager bibtexTypeForPubMedType:[pubDict objectForKey:@"Pt"]] != nil)
		type = [typeManager bibtexTypeForPubMedType:[pubDict objectForKey:@"Pt"]];
    
    newBI = [[BibItem alloc] initWithType:type
								 fileType:BDSKBibtexString
								  citeKey:nil
								pubFields:pubDict
                                    isNew:YES];
    
    return newBI;
}

@end

@implementation NSString (PubMedExtensions)

- (NSString *)stringByAddingRISEndTagsToPubMedString;
{
    OFStringScanner *scanner = [[OFStringScanner alloc] initWithString:self];
    NSMutableString *fixedString = [[NSMutableString alloc] initWithCapacity:[self length]];
    
    NSString *scannedString = [scanner readFullTokenUpToString:@"PMID- "];
    unsigned start;
    unichar prevChar;
    BOOL scannedPMID = NO;
    
    // this means we scanned some garbage before the PMID tag, or else this isn't a PubMed string...
    OBPRECONDITION(scannedString == nil);
    
    do {
        
        start = scannerScanLocation(scanner);
        
        // scan past the PMID tag
        scannedPMID = scannerReadString(scanner, @"PMID- ");
        OBPRECONDITION(scannedPMID);
        
        // scan to the next PMID tag
        scannedString = [scanner readFullTokenUpToString:@"PMID- "];
        [fixedString appendString:[self substringWithRange:NSMakeRange(start, scannerScanLocation(scanner) - start)]];
        
        // see if the previous character is a newline; if not, then some clod put a "PMID- " in the text
        if(scannerScanLocation(scanner)){
            prevChar = *(scanner->scanLocation - 1);
            if(BDIsNewlineCharacter(prevChar))
                [fixedString appendString:@"ER  - \r\n"];
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
    tmpStr = [regex replaceWithString:@"ER  - \r\nPMID- " inString:self];
	
    tmpStr = [tmpStr stringByAppendingString:@"ER  - \r\n"];
    OBPOSTCONDITION([tmpStr isEqualToString:fixedString]);
#endif
    
    return [fixedString autorelease];
}

@end

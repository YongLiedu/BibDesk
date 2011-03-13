//
//  BDSKCOinSParser.m
//  Bibdesk
//
//
//  Created by Sven-S. Porst on 2009-04-14.
/*
 This software is Copyright (c) 2009-2011
 Sven-S. Porst. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Sven-S. Porst nor the names of any
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

#import "BDSKCOinSParser.h"
#import <AGRegex/AGRegex.h>
#import "NSXMLNode_BDSKExtensions.h"
#import "BDSKLinkedFile.h"
#import "NSString_BDSKExtensions.h"

/*
 The COinS or Z3988 format is a microformat which is embedded in web pages to include bibliographic information there.

 The data it transparts are stored in the title attribute of a span tag which has the class Z3988. That string is separated into fields by &amp; strings. Each field contains a = with the string coming before it being the field name and the string coming after it being a (presumably UTF-8) percent encoded string.
 
 As COinS lacks any formal specification of what can/shoud/must occur when and where, parsing it is mostly an effort in heuristics (there is a lazy POS pseudo-spec). Implementations on web sites differ greatly as well. One supposes due to both the poor specification and the incompetence of the people doing the implementation. 
 
 Related links: 
 . Allegedly 'official' site: http://ocoins.info/
 . Instead of an actual specification they offer generator whose output you can study: http://generator.ocoins.info/ 
 . Clear and useful example of COinS usage at Uni-Bremen Library: http://suche3.suub.uni-bremen.de/index.html 
 . Not all that useful examples are found in a bunch of OPACs which insert the tags into individual item pages only instead of adding them to search listings. E.g. http://www.stabikat.de/  https://kataloge.uni-hamburg.de/ 
 . Ambitious implementation with plenty of mistakes / quirks: http://www.base-search.net/
 . Implementation for search results with plenty of junk characters in them: https://opacplus.bsb-muenchen.de/ 
 . For single entry pages on http://citeseerx.ist.psu.edu/
 . Wikipedia articles with references in them, e.g. http://en.wikipedia.org/wiki/Library feature poor quality COinS tags (whose author names appear in duplicate because of the "spec"'s ambiguity.
*/


@implementation BDSKCOinSParser


// Claim that the can parse the document if its markup contains the string Z3988.
+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
	if (!domDocument) return NO;
	
    NSError *error;
    NSArray *nodes = [[xmlDocument rootElement] nodesForXPath:@".//span[@class='Z3988']" error:&error];
    
    return [nodes count] > 0;
}

// Convert publication type name from COinS to BibTeX names.
+ (NSString *) convertType:(NSString *) type {
	// default to misc. For unknown values as well as 'document', 'unknown',   
	NSString * BibTeXType = @"GEN";
	
	if ([type isEqualToString:@"article"]) { BibTeXType = BDSKArticleString; }
	else if ([type isEqualToString:@"book"]) { BibTeXType = BDSKBookString; }
	else if ([type isEqualToString:@"bookitem"]) { BibTeXType = BDSKInbookString; }
	else if ([type isEqualToString:@"conference"]) { BibTeXType = BDSKProceedingsString; }
	else if ([type isEqualToString:@"issue"]) { BibTeXType = @"periodical"; } // ?? correct
	else if ([type isEqualToString:@"preprint"]) { BibTeXType = BDSKUnpublishedString; }
	else if ([type isEqualToString:@"proceeding"]) { BibTeXType = BDSKInproceedingsString; }
	else if ([type isEqualToString:@"report"]) { BibTeXType = BDSKTechreportString; }
//	else if ([type isEqualToString:@"info:ofi/fmt:kev:mtx:dissertation"]) { BibTeXType = @"phdthesis"; }
	
	return BibTeXType;
}

// Converts a COins String to a BibItem. All sorts of heuristics and attempts to interpret the format in there. 
+ (BibItem *) parseCOinSString: (NSString *) COinSString {
	NSString * inputString = COinSString;
	if ([inputString rangeOfString:@"%20"].location == NSNotFound) {
		// COinS has a laughable 'specification' but even that is quite clear about spaces being percent escaped to %20. It seems microformat geeks seem to be even lazier/stupider than the people who failed to write an actual spec and suffer from the misconception that 'URL Encoding' is the same as 'Percent Escaping', leading to + being used for a space on many sites. To minimise the impact of that, replace all + by spaces if no occurrences of %20 are found.
		inputString = [inputString stringByReplacingOccurrencesOfString:@"+" withString:@" "];
	}
	
	
	NSArray * components = [inputString componentsSeparatedByString:@"&amp;"];
	if ([components count] < 2 ) { return nil; }

    NSMutableDictionary *fieldsDict = [NSMutableDictionary dictionary];
    NSMutableArray *files = [NSMutableArray array];
	NSString * publicationType = BDSKMiscString;
	NSString * startPage = nil;
	NSString * endPage = nil;
	NSString * auFirst = nil;
	NSString * auLast = nil;
	NSString * auInitials = nil;
	NSString * auSuffix = nil;

	for (NSString *component in components) {
		NSArray * keyValue = [component componentsSeparatedByString:@"="];
		if ([keyValue count] == 2 ) {
			NSString * key = [keyValue objectAtIndex:0];
			NSString * value = [[(NSString*)[keyValue objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

			if (value) {
				
			NSString * fieldName = nil;
			if ([key isEqualToString:@"rft.genre"]) {
				if ([publicationType isEqualToString:BDSKMiscString]) {
					publicationType =  [self convertType:value]; 
				}
			} 
			else if ([key isEqualToString:@"rft.atitle"]) { // article title
				fieldName = BDSKTitleString;
				publicationType = @"article";				
			}			
			else if ([key isEqualToString:@"rft.btitle"]) { // book title
				fieldName = BDSKTitleString;
				publicationType = @"book";
			}
			else if ([key isEqualToString:@"rft.title"]) { // general journal title
				fieldName = BDSKJournalString;
			}
			else if ([key isEqualToString:@"rft.jtitle"]) { // full journal title
				fieldName = BDSKJournalString;				
			}
			else if ([key isEqualToString:@"rft.stitle"]) { // short journal title: only use it if no full journal title is present
				if ([NSString isEmptyString:[fieldsDict objectForKey:BDSKJournalString]]) {
					fieldName = BDSKJournalString;
				}
			}
			else if ([key isEqualToString:@"rft.series"]) { 
				fieldName = BDSKSeriesString;
			}
			else if ([key isEqualToString:@"rft.au"]) { // this simplistic approach hopes that .au is used rather than .aufirst .aulast etc.
				fieldName = BDSKAuthorString;
			}
			else if ([key isEqualToString:@"rft.aufirst"]) {
				auFirst = value;
			}
			else if ([key isEqualToString:@"rft.aulast"]) {
				auLast = value;
			}
			else if ([key isEqualToString:@"rft.auinit"] || [key isEqualToString:@"rft.auinitm"]) {
				if ( auInitials ) {
					// append to existing initials
					auInitials = [auInitials stringByAppendingFormat:@" %@", value];
				}
				else {
					auInitials = value;
				}
			}
			else if ([key isEqualToString:@"rft.auinit1"]) {
				if ( auInitials ) {
					// prepend to existing initials
					auInitials = [NSString stringWithFormat:@"%@ %@", value, auInitials];
				}
				else {
					auInitials = value;
				}
			}
			else if ([key isEqualToString:@"rft.auSuffix"]) {
				auSuffix = value;
			}
			else if ([key isEqualToString:@"rft.date"]) { 
				// try to find a four digit year, otherwise leave fieldName nil
				// add support for months?
				AGRegex * yearRegexp = [AGRegex regexWithPattern:@"[0-9]{4}"];
				AGRegexMatch * match = [yearRegexp findInString:value];
				if (match) {
						value = [match group];
						fieldName = BDSKYearString; 
				}
			}
			else if ([key isEqualToString:@"rft.pub"]) {  // publisher
				fieldName = BDSKPublisherString;
			}
			else if ([key isEqualToString:@"rft.place"]) { 
				fieldName = BDSKAddressString;
			}
			else if ([key isEqualToString:@"rft.edition"]) {
				fieldName = @"Edition";
			}
			else if ([key isEqualToString:@"rft.volume"]) { 
				fieldName = BDSKVolumeString;
			}
			else if ([key isEqualToString:@"rft.issue"]) { 
				fieldName = BDSKNumberString;
			}
			else if ([key isEqualToString:@"rft.pages"] || [key isEqualToString:@"rft.tpages"]) {
				fieldName = BDSKPagesString;
			}
			else if ([key isEqualToString:@"rft.spage"]) { // start page
				startPage = value;
			}
			else if ([key isEqualToString:@"rft.epage"]) { // end page
				endPage = value;
			}
			else if ([key isEqualToString:@"rft_id"] || [key isEqualToString:@"rft.identifier"]) { 
				// these are most likely URLs or DOI type information
				NSURL * URL = [NSURL URLWithString:value];
				if (URL && ([@"http" isCaseInsensitiveEqual:[URL scheme]] || [@"https" isCaseInsensitiveEqual:[URL scheme]])) {
                    // add http/https URLs to the FileView items only, rather than the Url field. This lets us process more than one of them and avoid adding links to library catalogue entries to the BibTeX record. I haven't seen other usable URL typese yet.
                    [files addObject:[BDSKLinkedFile linkedFileWithURL:URL delegate:nil]];
				}
				if ([value rangeOfString:@"doi" options:NSCaseInsensitiveSearch].location != NSNotFound) {
					// the value contains doi, so assume it's DOI information and also add it to the DOI field. There should only be a single occurrence of those, so add it right here to make sure the format isn't messed up in case multiple fields contain that substring
					NSRange range = [value rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]];
                    if (range.length && range.location > 0)
						[fieldsDict setObject:[value substringFromIndex:range.location] forKey:BDSKDoiString];
                }
			}
			else if ([key isEqualToString:@"rft.isbn"]) { 
				fieldName = @"ISBN";
			}
			else if ([key isEqualToString:@"rft.issn"]) { 
				fieldName = @"ISSN";
			}
			else if ([key isEqualToString:@"rft.aucorp"]) { 
				fieldName = BDSKInstitutionString;
			}
			else if ([key isEqualToString:@"rft.description"]) { // ?
				fieldName = @"Comments"; 
			}
			
			// ignored items which apparently may exist: rft.artnum (kind of ID), rft.part, rft.coden (no clue), rft.sici (no clue), rft.chron (free-style dates), rft.ssn (Seasonal Dates), rft.quarter
			
			if ( fieldName ) {
				NSString * previousValue = [fieldsDict objectForKey:fieldName];
				BOOL wasNonEmpty = ([NSString isEmptyString:previousValue] == NO);
				
				/* now treat a few cases specially */
				if ( [fieldName isEqualToString:BDSKAuthorString] && wasNonEmpty ) {
					// if author already exists, append another one with an 'and' separator
					value = [previousValue stringByAppendingFormat:@" and %@", value];
				}
				else if ( wasNonEmpty ) {
					// for other values append multiple occurrencs with a semicolon as a separator, make sure the new string is not contained in the existing string already before adding it as sometimes fields end up twice in the COinS record
					if ( [previousValue rangeOfString:value options:NSLiteralSearch].location == NSNotFound ) {
						value = [previousValue stringByAppendingFormat:@"; %@", value];
					}
				}
							
				if (value) {
					[fieldsDict setObject:value forKey:fieldName];
				}
			}			
			
			}
			
		}
	}
	
	if ( [NSString isEmptyString:[fieldsDict objectForKey:BDSKPagesString]] && (startPage != nil)) {
		NSString * pages = startPage;
		if (endPage)
            pages = [startPage stringByAppendingFormat:@"--%@", endPage];
		[fieldsDict setObject:pages forKey:BDSKPagesString];
	}
	
	if (auFirst || auLast || auInitials || auSuffix) {
		NSString * name = auFirst;
		if (!name) { 
			name = auInitials; 
		}
		else {
			if (auInitials) { name = [name stringByAppendingFormat:@" %@", auInitials]; }
		}
		if (name && auLast) {
			name = [name stringByAppendingFormat:@" %@", auLast];
		}	
		else if (auLast) {
			name = auLast;
		}
		if (name && auSuffix) {
			name = [name stringByAppendingFormat:@", %@", auSuffix];
		}
		
		NSString * authors = [fieldsDict objectForKey:BDSKAuthorString];
		if ([authors length] > 0) {
			name = [name stringByAppendingFormat:@" and %@", authors];
		}
		
		[fieldsDict setObject:name forKey:BDSKAuthorString];
	}
	
    return [[[BibItem alloc] initWithType:publicationType
                                  citeKey:nil
                                pubFields:fieldsDict
                                    files:files
                                    isNew:YES] autorelease];
}

// Process the document. 
+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	NSError *error;
    NSArray *nodes = [[xmlDocument rootElement] nodesForXPath:@".//span[@class='Z3988']" error:&error];
	NSMutableArray *results = [NSMutableArray arrayWithCapacity:[nodes count]];
    NSString *title;
    BibItem *bibItem;
    
    for (NSXMLNode *node in nodes) {
        if ([node kind] == NSXMLElementKind &&
            (title = [[(NSXMLElement *)node attributeForName:@"title"] XMLString]) &&
            (bibItem = [BDSKCOinSParser parseCOinSString:title]))
            [results addObject:bibItem];
    }
	
	return results;	
}

// Array with feature description dictionary for the COinS microformat.
+ (NSDictionary *) parserInfo {
	NSString * parserDescription = NSLocalizedString(@"The COinS microformat can be used to embed bibliographic information in web pages.", @"Description for COinS mircoformat");
	return [BDSKWebParser parserInfoWithName:@"COinS" address:@"http://ocoins.info/" description: parserDescription feature:BDSKParserFeatureGeneric];
}

@end

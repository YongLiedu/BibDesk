//
//  BDSKMathSciNetParser.m
//  Bibdesk
//
//  Created by Sven-S. Porst on 2009-03-24.
/*
 This software is Copyright (c) 2009
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

#import "BDSKMathSciNetParser.h"
#import "BDSKBibTeXParser.h"
#import "BibItem.h"
#import "NSError_BDSKExtensions.h"
#import "NSString_BDSKExtensions.h"
#import <AGRegEx/AGRegEx.h>



@implementation BDSKMathSciNetParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
	BOOL result = (0 == [[[[url path] pathComponents] objectAtIndex:1] rangeOfString:@"mathscinet"].location);	
	return result;
}

	
+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	NSError * error;
	
	/* 
		Find occurrences of strings MR1234567 on the page and remove leading zeroes.
		These are the IDs of the related records.
	*/
	AGRegex *MRRegexp = [AGRegex regexWithPattern:@"MR0*([1-9][0-9]*)" options:AGRegexMultiline];
	NSArray * regexpResults = [MRRegexp findAllInString:[xmlDocument XMLString]];
	
	if (0 == [regexpResults count]) { return nil; }

	
	/*  
		Ask server for BibTeX records for all related records found on the page
	*/
	NSEnumerator * matchEnumerator = [regexpResults objectEnumerator];
	AGRegexMatch * match;
	NSMutableArray * IDArray = [NSMutableArray arrayWithCapacity:[regexpResults count]];
	
	while (match = [matchEnumerator nextObject]) {
		NSString * matchedString = [[match string] substringWithRange:[match rangeAtIndex:1]];
		if (![IDArray containsObject:matchedString]) {
			[IDArray addObject:matchedString];
		}
	}
	
	
	NSMutableArray * results = [NSMutableArray arrayWithCapacity:[IDArray count]];

	/* MSN will return 50 results in one go, so loop in batches of 50 */
	while ([IDArray count] > 0) {
		NSRange elementRange = NSMakeRange(0, MIN(50u, [IDArray count]));
		NSArray * processArray = [IDArray subarrayWithRange:elementRange];
		[IDArray removeObjectsInRange:elementRange];
		
		NSString * queryString = [processArray componentsJoinedByString:@"&b="];
		NSString * URLString = [NSString stringWithFormat:@"http://%@/mathscinet/search/publications.html?&fmt=bibtex&extend=1&b=%@", [url host], queryString];
		NSURL * URL = [NSURL URLWithString:URLString];
	
		NSXMLDocument * resultsPage = [[[NSXMLDocument alloc] initWithContentsOfURL:URL options: NSXMLDocumentTidyHTML error:&error] autorelease];
	
		if ((error != nil)  && (resultsPage == nil)) {
			/* only return with an error if we don't receive an XML object back.
				NSXMLDocument returns an  NSXMLParserInternalError NSError if markup was slightly invalid.
				MSN sends such markup by including unescaped ampersands in their XHTML, but the NSXMLDocumentTidyHTML fixes that problem despite the NSError
			*/
			if (outError != NULL) { *outError = error; }
			return nil; 
		}

		
		/* 
			In the returned web page results live inside a <div class="doc"> tag.
			Each of them is wrapped in a <pre> tag. 
			Find these, kill the potentially superfluous whitespace in there and create BibItems for each of them.
		*/
		NSArray * preArray = [resultsPage nodesForXPath:@".//div[@class='doc']/pre" error:&error];
		
		if (error != nil ) { 
			if (outError != NULL) { *outError = error; }
			return nil; 
		}
		
		NSEnumerator * nodeEnumerator = [preArray objectEnumerator];
		NSXMLNode * node;
		
		while (node = [nodeEnumerator nextObject]) {
			NSString * preContent = [node stringValue];		
			NSString * cleanedRecord = 	[preContent stringByCollapsingAndTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			cleanedRecord = [cleanedRecord stringByReplacingOccurrencesOfString:@"\\&" withString:@"\\&amp;"];
			
			BOOL isPartialData;
			NSError * parseError;
			NSArray * newPubs = [BDSKBibTeXParser itemsFromString:cleanedRecord document:nil isPartialData:&isPartialData error: &parseError];
			
			if (error == nil) {
				[results addObjectsFromArray:newPubs];
			}
		}
	}  // end of while loop over 50 element subarrays

	

	
	/* STEP 4
		Add a URL reference to the review's web page to each record.
	*/
	NSEnumerator * itemEnumerator = [results objectEnumerator];	
	BibItem * item;
	
	while (item = [itemEnumerator nextObject]) {
		NSString * MRNumber = [[item citeKey] stringByRemovingPrefix:@"MR"];
		NSString * MRItemURLString = [NSString stringWithFormat:@"http://%@/mathscinet-getitem?mr=%@", [url host], MRNumber];
		[item setField:BDSKUrlString toValue:MRItemURLString];
	}
	
	return results;  
}

@end

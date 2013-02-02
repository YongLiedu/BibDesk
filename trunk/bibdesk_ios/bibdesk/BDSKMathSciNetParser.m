//
//  BDSKMathSciNetParser.m
//  Bibdesk
//
//  Created by Sven-S. Porst on 2009-03-24.
/*
 This software is Copyright (c) 2009-2012
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
#import <AGRegex/AGRegex.h>

#define MSNBATCHSIZE 50u


@implementation BDSKMathSciNetParser


/*
 MathSciNet is mirrored across different servers, don't use the server name to recognise the URL.
 Instead recognise all URLs beginning with 'mathscinet', to match both general MatSciNet URLs like <http://www.ams.org/mathscinet/...>  and MathSciNet reference URLS <http://www.ams.org/mathscinet-getitem?...>.
*/
+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
	BOOL result = NO;
	NSString * path = [url path];
	if (path) {
		result = [[url path] rangeOfString:@"/mathscinet" options: (NSAnchoredSearch)].location != NSNotFound;
	}
	return result;
}



/*
 Finds strings of type MR1234567 in the current page. 
 Creates a list of their IDs (without leading zeroes), and retrieves the BibItems for them.
 Returns an array wit those BibItems.
*/
+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	AGRegex * MRRegexp = [AGRegex regexWithPattern:@"MR0*([0-9]+)" options:AGRegexMultiline];
	NSArray * regexpResults = [MRRegexp findAllInString:[xmlDocument XMLString]];
	
	if (0 == [regexpResults count]) { return regexpResults; } // no matches but no error => return empty array

	NSMutableArray * IDArray = [NSMutableArray arrayWithCapacity:[regexpResults count]];
	
	for (AGRegexMatch * match in regexpResults) {
		NSString * matchedString = [[match string] substringWithRange:[match rangeAtIndex:1]];
		if (![IDArray containsObject:matchedString]) {
			[IDArray addObject:matchedString];
		}
	}
	
	NSArray * results = [BDSKMathSciNetParser bibItemsForMRIDs:IDArray referrer:url error:outError];
	return results;  
}



/*
 Helper method that turns an array of MR ID numbers into an array of BibItems using the default server.
*/
+ (NSArray *) bibItemsForMRIDs:(NSArray *) IDs {
	return [BDSKMathSciNetParser bibItemsForMRIDs:IDs referrer:nil error:NULL];
}



/*
 Turns an array of MR ID numbers into an array of BibItems.
 The referrer: URL argument is used to send requests to the same mirror that was used originally. 
*/
+ (NSArray *) bibItemsForMRIDs:(NSArray *) IDs referrer:(NSURL *) URL error:(NSError **) outError {
	NSError * error;
	
	/*	Determine the server name to use.
		If the referring URL's server name contains 'ams', assume we were using a mirror server before and continue using that.
		If not, we're processing MR IDs not coming from a MathSciNet page and use the default 'ams.org' server.
	*/
	NSString * serverName = [[URL host] lowercaseString];
	if (!serverName || [serverName rangeOfString:@"ams"].location == NSNotFound) {
		serverName = @"www.ams.org";
	}
	
	
	/*	Downloaded BibTeX records sometimes use \"o for umlauts which is incorrect and rejected by the parser. Use a regular expression to find and replace them. Also add brackets to acute and grave accents, so BibDesk translates them to Unicode properly for display. 
	*/
	AGRegex * umlautFixer = [AGRegex regexWithPattern:@"(\\\\[\"'`][a-zA-Z])" options:AGRegexMultiline];
	

	/* Loop through IDs in batches of MSNBATCHSIZE. */
	NSUInteger count = [IDs count];
	NSMutableArray * results = [NSMutableArray arrayWithCapacity:count];
	NSUInteger firstElement = 0;
	while (firstElement < count) {
		NSRange elementRange = NSMakeRange(firstElement, MIN(MSNBATCHSIZE, count - firstElement));
		NSArray * processArray = [IDs subarrayWithRange:elementRange];
		firstElement += MSNBATCHSIZE;
		
		NSString * queryString = [processArray componentsJoinedByString:@"&b="];
		NSString * URLString = [NSString stringWithFormat:@"http://%@/mathscinet/search/publications.html?&fmt=bibtex&extend=1&b=%@", serverName, queryString];
		NSURL * bibTeXBatchDownloadURL = [NSURL URLWithString:URLString];
		
		NSXMLDocument * resultsPage = [[[NSXMLDocument alloc] initWithContentsOfURL:bibTeXBatchDownloadURL options: NSXMLDocumentTidyHTML error:&error] autorelease];
		
		if ((error != nil)  && (resultsPage == nil)) {
			/*  Only return with an error if we don't receive an XML object back.
				NSXMLDocument returns an  NSXMLParserInternalError NSError if markup was slightly invalid.
				MSN sends such markup by including unescaped ampersands in their XHTML, but the NSXMLDocumentTidyHTML fixes that problem despite the NSError.
			*/
			if (outError != NULL) { *outError = error; }
			return nil; 
		}
		
		
		/*	In the returned web page results live inside a <div class="doc"> tag.
			Each of them is wrapped in a <pre> tag. 
			Find these, kill the potentially superfluous whitespace in there and create BibItems for each of them.
		*/
		NSArray * preArray = [resultsPage nodesForXPath:@".//div[@class='doc']/pre" error:&error];
		
		if ( preArray == nil ) { 
			if (outError != NULL) { *outError = error; }
			return nil; 
		}
		
		for (NSXMLNode *node in preArray) {
			NSString * preContent = [node stringValue];		
			NSString * cleanedRecord = 	[preContent stringByCollapsingAndTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			cleanedRecord = [umlautFixer replaceWithString:@"{$1}" inString:cleanedRecord];
			
			NSError * parseError;
			NSArray * newPubs = [BDSKBibTeXParser itemsFromString:cleanedRecord owner:nil isPartialData:NULL error: &parseError];
			
			if (newPubs != nil) {
				[results addObjectsFromArray:newPubs];
			}
		}
	}  // end of while loop over MSNBATCHSIZE element subarrays
	
	

	//	Add a URL reference pointing to the review's web page to each record.
	for (BibItem * item in results) {
		NSString * MRNumber = [[item citeKey] stringByRemovingPrefix:@"MR"];
		NSString * MRItemURLString = [NSString stringWithFormat:@"http://%@/mathscinet-getitem?mr=%@", serverName, MRNumber];
		NSURL * MRItemURL = [NSURL URLWithString:MRItemURLString];
		[item addFileForURL:MRItemURL autoFile:NO runScriptHook:NO];
	}
	
	return results;
}



/*
 Returns URL to the review for a given ID.
 It always points to the default server.
*/
+ (NSURL *) reviewLinkForID: (NSString *) MRID {
	NSString * MRItemURLString = [NSString stringWithFormat:@"http://www.ams.org/mathscinet-getitem?mr=%@", MRID];
	NSURL * MRItemURL = [NSURL URLWithString:MRItemURLString];
	return MRItemURL;
}



/*
 Array with site description dictionary for ams.org/mathscinet.
*/
+ (NSDictionary *)parserInfo {
	NSString *parserDescription = NSLocalizedString(@"Database of Mathematical Reviews by the American Mathematical Society.", @"Description for MathSciNet site");
	return [BDSKWebParser parserInfoWithName:@"MathSciNet" address:@"http://www.ams.org/mathscinet/" description: parserDescription feature:BDSKParserFeatureSubscription];
}


@end

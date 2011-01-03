//
//  BDSKZentralblattParser.m
//  Bibdesk
//
//  Created by Sven-S. Porst on 2009-03-25.
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

#import "BDSKZentralblattParser.h"
#import "BDSKBibTeXParser.h"
#import "BibItem.h"
#import <AGRegex/AGRegex.h>

#define ZMATHBATCHSIZE 100u



@implementation BDSKZentralblattParser
/*
 Zentralblatt Math is mirrored across several servers. See http://www.zentralblatt-math.org/zmath/en/mirrors/ .
 Accept URLs whose path begins with zmath. As sometimes paths begin with multiple slashes, trim those first.
*/
+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
	BOOL result = NO;
	NSString * cleanedPath = [[url path] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
	if (cleanedPath) {
		result = ([cleanedPath rangeOfString:@"zmath" options: (NSCaseInsensitiveSearch|NSAnchoredSearch)].location != NSNotFound );
	}
	return result;
}



/*
 Find occurrences of strings Zbl [pre]1234.56789 or JFM 12.3456.78 on the page.
 Extract their IDs and look them up.
 Return the resulting BibItems.
*/	
+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	AGRegex *ZMathRegexp = [AGRegex regexWithPattern:@"(Zbl|JFM) (pre)?([0-9.]*)" options:AGRegexMultiline];
	NSArray * regexpResults = [ZMathRegexp findAllInString:[xmlDocument XMLString]];
	
	if (0 == [regexpResults count]) { return regexpResults; } // no matches but no error => return empty array

	NSMutableArray * IDArray = [NSMutableArray arrayWithCapacity:[regexpResults count]];
	
	for (AGRegexMatch *match in regexpResults) {
		NSString * matchedString = [[match string] substringWithRange:[match rangeAtIndex:3]];
		if (![IDArray containsObject:matchedString]) {
			[IDArray addObject:matchedString];
		}
	}

	NSArray * results = [BDSKZentralblattParser bibItemsForZMathIDs:IDArray referrer:url error:outError];	
	return results;  
}



/*
 Turns an array of Zentralblatt Math IDs into an array of BibItems using the default server.
*/
+ (NSArray *) bibItemsForZMathIDs:(NSArray *) IDs {
	return [BDSKZentralblattParser bibItemsForZMathIDs:IDs referrer:nil error:NULL];
}



/*
 Turns an array of Zentralblatt Math IDs into an array of BibItems.
*/
+ (NSArray *) bibItemsForZMathIDs:(NSArray *) IDs referrer:(NSURL *) referrer error:(NSError **) outError {
	NSError * error;
	
	/*	Determine the server name to use.
		If the referring URL's path begins with '/zmath', assume we are using a Zentralblatt mirror server before and continue using that.
		If not, use the default server instead.
	*/
	NSString * serverName = [[referrer host] lowercaseString];
	if ( [BDSKZentralblattParser canParseDocument:nil xmlDocument:nil fromURL:referrer] ) {
		if ( [[referrer path] rangeOfString:@"/ZMATH/zmath"].location != NSNotFound ) {
			// some mirrors' paths begin with /ZMATH, add that
			serverName = [serverName stringByAppendingString:@"/ZMATH"];
		}
	}
	else {
		serverName = @"www.zentralblatt-math.org";
	}
	
	/*	ZMath sometimes uses \"o for umlauts which is incorrect, fix that by adding brackets around it for the parser to work. Also add brackets to acute and grave accents, so BibDesk translates them to Unicode properly for display */
	AGRegex * umlautFixer = [AGRegex regexWithPattern:@"(\\\\[\"'`][a-zA-Z])" options:AGRegexMultiline];

	// Loop through IDs in batches of ZMATHBATCHSIZE.
	NSUInteger count = [IDs count];
	NSMutableArray * results = [NSMutableArray arrayWithCapacity:count];
	NSUInteger firstElement = 0;
	while (firstElement < count) {
		NSRange elementRange = NSMakeRange(firstElement, MIN(ZMATHBATCHSIZE, count - firstElement));
		NSArray * processArray = [IDs subarrayWithRange:elementRange];
		firstElement += ZMATHBATCHSIZE;
		
		// Query ZMath with a POST request
		NSString * URLString = [NSString stringWithFormat:@"http://%@/zmath/en/command/", serverName];
		NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];
		[request setHTTPMethod:@"post"];
		[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];
		NSString * queryString = [NSString stringWithFormat:@"type=bibtex&count=100&q=an:%@", [processArray componentsJoinedByString:@"|an:"]];
		queryString = [queryString stringByAddingPercentEscapes];
		[request setHTTPBody:[queryString dataUsingEncoding:NSUTF8StringEncoding]];
		
		NSURLResponse * response;
		NSData * result = [NSURLConnection sendSynchronousRequest:request returningResponse: &response error: &error];
		
		if (result == nil) {
			if (outError != NULL) { *outError = error; } 
			return nil; 
		}
		
		NSString * bibTeXString = [[[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding] autorelease];
		bibTeXString = [bibTeXString stringByCollapsingAndTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		bibTeXString = [umlautFixer replaceWithString:@"{$1}" inString:bibTeXString];
		BOOL isPartialData;
		NSError * ignoreError;
		NSArray * newPubs = [BDSKBibTeXParser itemsFromString:bibTeXString owner:nil isPartialData:&isPartialData error: &ignoreError];
		
		if (newPubs != nil) {
			[results addObjectsFromArray:newPubs];
		}
	}  // end of while loop over ZMATHBATCHSIZE element subarrays
	
	
	// Add a URL reference to the review's web page to each record.
	for (BibItem * item in results) {
		NSString * ZMathNumber = [item citeKey];
		NSURL * reviewURL = [BDSKZentralblattParser reviewLinkForID:ZMathNumber];
		[item addFileForURL:reviewURL autoFile:NO runScriptHook:NO];
	}
	
	return results;
}



/*
 Returns URL to the review for a given ID.
 Always uses the default server.
*/
+ (NSURL *) reviewLinkForID: (NSString *) ZMathID {
	NSString * ZMathItemURLString = [NSString stringWithFormat:@"http://www.zentralblatt-math.org/zmath/en/search/?format=complete&q=an:%@", ZMathID];
	NSURL * ZMathItemURL = [NSURL URLWithString:ZMathItemURLString];
	return ZMathItemURL;
}



/*
 Array with site description dictionary for main www.zentralblatt-math.org.
*/
+ (NSDictionary *)parserInfo {
	NSString * parserDescription = NSLocalizedString(@"Database of Zentralblatt Mathematik with reviews of mathematical papers. Only the first three search results are displayed without a subscription.", @"Description for Zentralblatt Math site.");
	return [BDSKWebParser parserInfoWithName:@"Zentralblatt Math" address:@"http://www.zentralblatt-math.org/zmath/en/" description: parserDescription feature:BDSKParserFeatureSubscription];
}


@end

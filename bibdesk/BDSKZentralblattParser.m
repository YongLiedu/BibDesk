//
//  BDSKZentralblattParser.m
//  Bibdesk
//
//  Created by Sven-S. Porst on 2009-03-25.
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

#import "BDSKZentralblattParser.h"
#import "BDSKBibTeXParser.h"
#import "BibItem.h"
#import "NSError_BDSKExtensions.h"
#import "NSString_BDSKExtensions.h"
#import <AGRegEx/AGRegEx.h>



@implementation BDSKZentralblattParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
	BOOL result = ([[url host] rangeOfString:@"zentralblatt-math.org"].location != NSNotFound);
	return result;
}

	
+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	NSError * error;
	
	/* 
		Find occurrences of strings Zbl [pre]1234.56789 or JFM 12.3456.78 on the page.
		The numbers in them are the records'  IDs.
	*/
	AGRegex *ZblRegexp = [AGRegex regexWithPattern:@"(Zbl|JFM) (pre)?([0-9.]*)" options:AGRegexMultiline];
	NSArray * regexpResults = [ZblRegexp findAllInString:[xmlDocument XMLString]];
	
	if (0 == [regexpResults count]) { return nil; }

	
	/*  
		Ask server for BibTeX records for all related records found on the page.
	*/
	NSEnumerator * matchEnumerator = [regexpResults objectEnumerator];
	AGRegexMatch * match;
	NSMutableArray * IDArray = [NSMutableArray arrayWithCapacity:[regexpResults count]];
	
	while (match = [matchEnumerator nextObject]) {
		NSString * matchedString = [[match string] substringWithRange:[match rangeAtIndex:3]];
		if (![IDArray containsObject:matchedString]) {
			[IDArray addObject:matchedString];
		}
	}

	/* ZMath sometimes uses \"o for umlauts which is incorrect, fix that for the parser to work. */
	AGRegex * umlautFixer = [AGRegex regexWithPattern:@"\\\\\"([a-zA-Z])" options:AGRegexMultiline];
	NSMutableArray * results = [NSMutableArray arrayWithCapacity:[IDArray count]];

	/* ZMath will return 100 results in one go, so loop in batches of 100 */
	while ([IDArray count] > 0) {
		NSRange elementRange = NSMakeRange(0, MIN(100u, [IDArray count]));
		NSArray * processArray = [IDArray subarrayWithRange:elementRange];
		[IDArray removeObjectsInRange:elementRange];
		
		/* ZMath need to be queried with a POST request */
		NSString * URLString = @"http://www.zentralblatt-math.org/zmath/en/command/";
		NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];
		[request setHTTPMethod:@"post"];
		[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];
		NSString * queryString = [NSString stringWithFormat:@"type=bibtex&count=100&q=an:%@", [processArray componentsJoinedByString:@"|an:"]];
		queryString = [queryString stringByAddingPercentEscapes];
		[request setHTTPBody:[queryString dataUsingEncoding:NSUTF8StringEncoding]];

		NSURLResponse * response;
		NSData * result = [NSURLConnection sendSynchronousRequest:request returningResponse: &response error: &error];
		
		if (error != nil) {
			if (outError != NULL) { *outError = error; } 
			return nil; 
		}
		
		NSString * bibTeXString = [[[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding] autorelease];
		bibTeXString = [bibTeXString stringByCollapsingAndTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([bibTeXString rangeOfString:@"\\\""].length)
            bibTeXString = [umlautFixer replaceWithString:@"{\\\\\"$1}" inString:bibTeXString];
		BOOL isPartialData;
		NSError * ignoreError;
		NSArray * newPubs = [BDSKBibTeXParser itemsFromString:bibTeXString document:nil isPartialData:&isPartialData error: &ignoreError];
			
		if (newPubs != nil) {
			[results addObjectsFromArray:newPubs];
		}
	}  // end of while loop over 100 element subarrays
		
		
	/*
		Add a URL reference to the review's web page to each record.
	*/
	NSEnumerator * itemEnumerator = [results objectEnumerator];	
	BibItem * item;
	
	while (item = [itemEnumerator nextObject]) {
		NSString * ZMathNumber = [item citeKey];
		NSString * ZMathItemURLString = [NSString stringWithFormat:@"http://www.zentralblatt-math.org/zmath/en/search/?format=complete&q=an:%@", ZMathNumber];
		[item setField:BDSKUrlString toValue:ZMathItemURLString];
	}
	
	return results;  
}

@end

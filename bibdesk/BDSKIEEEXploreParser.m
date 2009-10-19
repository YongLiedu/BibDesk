//
//  BDSKIEEEXploreParser.m
//
//  Created by Michael O. McCracken on 9/26/07.
/*
 This software is Copyright (c) 2007-2009
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

#import "BDSKIEEEXploreParser.h"
#import <WebKit/WebKit.h>
#import "BibItem.h"
#import "BDSKBibTeXParser.h"
#import "NSError_BDSKExtensions.h"
#import <AGRegex/AGRegex.h>

// sometimes the link says AbstractPlus, sometimes it only says Abstract. This should catch both:
NSString *containsAbstractPlusLinkNode = @"//a[contains(lower-case(text()),'abstract')]";
NSString *abstractPageURLPath = @"/xpls/abs_all.jsp";
NSString *searchResultPageURLPath = @"/search/srchabstract.jsp";

@implementation BDSKIEEEXploreParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    if (! [[url host] isEqualToString:@"ieeexplore.ieee.org"]){
        return NO;
    }
        
	bool isOnAbstractPage     = [[url path] isEqualToString:abstractPageURLPath];
	bool isOnSearchResultPage = [[url path] isEqualToString:searchResultPageURLPath];
    
    NSError *error = nil;    

    bool nodecountisok =  [[[xmlDocument rootElement] nodesForXPath:containsAbstractPlusLinkNode error:&error] count] > 0;

    return nodecountisok || isOnAbstractPage || isOnSearchResultPage;
}


+ (NSString *)ARNumberFromURLSubstring:(NSString *)urlPath error:(NSError **)outError{
	
	AGRegex * ARNumberRegex = [AGRegex regexWithPattern:@"arnumber=([0-9]+)" options:AGRegexMultiline];
	AGRegexMatch *match = [ARNumberRegex findInString:urlPath];
	if([match count] == 0 && outError){
		*outError = [NSError localErrorWithCode:0 localizedDescription:NSLocalizedString(@"missingARNumberKey", @"Can't get an ARNumber from the URL")];

		return NULL;
	}
	return [match groupAtIndex:1];
}

+ (NSString *)ISNumberFromURLSubstring:(NSString *)urlPath error:(NSError **)outError{
	
	AGRegex * ISNumberRegex = [AGRegex regexWithPattern:@"isnumber=([0-9]+)" options:AGRegexMultiline];
	AGRegexMatch *match = [ISNumberRegex findInString:urlPath];
	if([match count] == 0 && outError){
		*outError = [NSError localErrorWithCode:0 localizedDescription:NSLocalizedString(@"missingISNumberKey", @"Can't get an ISNumber from the URL")];
		
		return NULL;
	}
	return [match groupAtIndex:1];
}



+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:0];
    
    // http://ieeexplore.ieee.org/search/srchabstract.jsp?arnumber=4723961&isnumber=4723954&punumber=4711036&k2dockey=4723961@ieeecnfs&query=%28%28pegasus+on+the+virtual+grid%29%3Cin%3Emetadata%29&pos=0&access=no
    // http://ieeexplore.ieee.org/xpls/abs_all.jsp?isnumber=4723954&arnumber=4723958&count=9&index=3
	// http://ieeexplore.ieee.org/search/srchabstract.jsp?arnumber=928956&isnumber=20064&punumber=7385&k2dockey=928956@ieeecnfs&query=%28%28planning+deformable+objects%29%3Cin%3Emetadata%29&pos=0&access=no
    if([[url path] isEqualToString:abstractPageURLPath] ||
	   [[url path] isEqualToString:searchResultPageURLPath]){        
		
        BibItem *item = [self itemFromURL:url xmlDocument:xmlDocument error:outError];
		return item ? [NSArray arrayWithObject:item] : nil;
	}else{
        // The following code parses all the links on a TOC page and is unusably slow.
		// Included for posterity in case we ever add async parsing.
        /*
		 NSError *error = nil;    
		
		 NSArray *AbstractPlusLinkNodes = [[xmlDocument rootElement] nodesForXPath:containsAbstractPlusLinkNode
																			error:&error];  
		
		if ([AbstractPlusLinkNodes count] < 1) {
			if (outError) *outError = error;
			return nil;
		}
		
		NSUInteger i, count = [AbstractPlusLinkNodes count];
		 for (i = 0; i < count; i++) {
		 NSXMLNode *aplinknode = [AbstractPlusLinkNodes objectAtIndex:i];
		 NSString *hrefValue = [aplinknode stringValueOfAttribute:@"href"];
			NSURL *abstractPageURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@%@", [url host], hrefValue]];
			
		 [items addObject:[self itemFromURL:abstractPageURL error:&error]];
		}
		*/
		
		// display a fake item in the table so the user knows one of the items failed to parse, but still gets the rest of the data
		NSString     *msg        = NSLocalizedString(@"Click the \"AbstractPlus\" link for the item you want to import.",
														@"IEEE TOC page fake marker item title");
		NSDictionary *pubFields     = [NSDictionary dictionaryWithObjectsAndKeys:msg, BDSKTitleString, nil];
		BibItem      *tocMarkerItem = [[BibItem alloc] initWithType:BDSKMiscString fileType:BDSKBibtexString citeKey:nil pubFields:pubFields isNew:YES];
		[items addObject:tocMarkerItem];
		[tocMarkerItem release];
		
	}

	return items;
	
}


+ (BibItem *)itemFromURL:(NSURL *)url error:(NSError **)outError{
	return [self itemFromURL:url xmlDocument:nil error:outError];
}

+ (BibItem *)itemFromURL:(NSURL *)url xmlDocument:(NSXMLDocument *)xmlDocument error:(NSError **)outError{
	
	NSError *error;
	
	NSString *arnumberString = [self ARNumberFromURLSubstring:[url query] error:outError];
	NSString *isnumberString = [self ISNumberFromURLSubstring:[url query] error:outError];

	
	// Query IEEEXplore with a POST request	
	
	NSString * serverName = [[url host] lowercaseString];

	NSString * URLString = [NSString stringWithFormat:@"http://%@/xpls/citationAct", serverName];
	
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];
	[request setHTTPMethod:@"POST"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];
	
	// note, do not actually url-encode this. they are expecting their angle brackets raw.
	NSString * queryString = [NSString stringWithFormat:@"dlSelect=cite_abs&fileFormate=BibTex&arnumber=<arnumber>%@</arnumber>", arnumberString];

	[request setHTTPBody:[queryString dataUsingEncoding:NSUTF8StringEncoding]];

	NSURLResponse * response;
	NSData * result = [NSURLConnection sendSynchronousRequest:request returningResponse: &response error: &error];
	
	if (nil == result) {
		if (outError != NULL) { *outError = error; } 
		return nil; 
	}
	
    /*
     Use NSAttributedString to unescape XML entities
	 For example: http://ieeexplore.ieee.org/xpls/abs_all.jsp?isnumber=4977283&arnumber=4977305&count=206&index=11
	 has a (tm) as an entity.

     http://ieeexplore.ieee.org/search/srchabstract.jsp?arnumber=259629&isnumber=6559&punumber=16&k2dockey=259629@ieeejrns&query=%28%28moll%29%3Cin%3Emetadata%29&pos=1&access=no
     has smart quotes and a Greek letter (converted) and <sub> and <sup> (which are lost).
     Using stringByConvertingHTMLToTeX will screw up too much stuff here, so that's not really an option.
     */
	
    NSAttributedString * attrString = [[[NSAttributedString alloc] initWithHTML:result options:nil documentAttributes:NULL] autorelease];
	NSString * bibTeXString = [[attrString string] stringByCollapsingAndTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	BOOL isPartialData;
	NSArray * newPubs = [BDSKBibTeXParser itemsFromString:bibTeXString document:nil isPartialData:&isPartialData error: outError];
	
	BibItem *newPub = nil;
	
	if (newPubs != nil && [newPubs count] > 0) {
		newPub = [newPubs objectAtIndex:0];
	}
	
	// Get the PDF URL, if possible:
    // Need to load the page if it isn't passed in:
	if(xmlDocument == nil){
		NSString * ARNumberURLString = [NSString stringWithFormat:@"http://ieeexplore.ieee.org/xpls/abs_all.jsp?tp=&arnumber=%@&isnumber=%@", arnumberString, isnumberString];
		xmlDocument = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL URLWithString:ARNumberURLString]
																 options:NSXMLDocumentTidyHTML 
																   error:&error];
        [xmlDocument autorelease];

	}
    NSArray *pdfLinkNodes = [[xmlDocument rootElement] nodesForXPath:@"//a[contains(text(), 'PDF')]"
                                                               error:&error];
    if ([pdfLinkNodes count] > 0){
        NSXMLNode *pdfLinkNode = [pdfLinkNodes objectAtIndex:0];
        NSString *hrefValue = [pdfLinkNode stringValueOfAttribute:@"href"];
        
        NSString *pdfURLString = [NSString stringWithFormat:@"http://%@%@", serverName, hrefValue];
        
        [newPub setField:BDSKUrlString toValue:pdfURLString];
    }
	
	return newPub;
}

+ (NSArray *) parserInfos {
	NSString * parserDescription = NSLocalizedString(@"IEEE Xplore Library Portal. Searching and browsing are free, but subscription is required for citation importing and full text access",
													 @"Description for IEEE Xplore site.");
	NSDictionary * parserInfo = [BDSKWebParser parserInfoWithName:@"IEEE Xplore" address:@"http://ieeexplore.ieee.org/" 
													  description: parserDescription 
															flags: BDSKParserFeatureSubscriptionMask];
	
	return [NSArray arrayWithObject:parserInfo];
}


@end 


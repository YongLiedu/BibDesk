//
//  BDSKBibDeskProtocol.m
//  Bibdesk
//
//  Created by Sven-S. Porst on 12.04.09.
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

/* 
	Mostly nicked from Apple's PictureBrowser example project.
*/

#import "BDSKBibDeskProtocol.h"
#import "BDSKWebParser.h"
#import <WebKit/WebView.h>


@implementation BDSKBibDeskProtocol

/*
 Only accept the bibdesk:webgroup URL.
*/
+ (BOOL)canInitWithRequest:(NSURLRequest *)theRequest {
	BOOL result = ([[[theRequest URL] absoluteString] caseInsensitiveCompare:BDSKBibDeskWebGroupURLString] == NSOrderedSame);
	return result;
}



+(NSURLRequest *) canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}



/*
 Immediately provide the requested data.
*/ 
- (void)startLoading {
    id<NSURLProtocolClient> client = [self client];
    NSURLRequest *request = [self request];
    NSData * data = [self welcomeHTMLData];
	
    if (data) {
        NSURLResponse *response = [[NSURLResponse alloc] initWithURL:[request URL] MIMEType:@"text/html" expectedContentLength:[data length] textEncodingName:@"utf-8"];
        [client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [client URLProtocol:self didLoadData:data];
        [client URLProtocolDidFinishLoading:self];
        [response release];
    } else {
        int resultCode = NSURLErrorResourceUnavailable;		
        [client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:resultCode userInfo:nil]];
    }
}



- (void)stopLoading
{
}



#pragma mark Create Information Web page

/*
 Loads web page template from resource file, inserts links to the web sites known by the available parser classes and returns the resulting HTML code as UTF-8 encoded data.
*/
- (NSData *) welcomeHTMLData {
	NSError * error;
	NSString * baseStringPath = [[NSBundle mainBundle] pathForResource:@"WebGroupStartPage" ofType:@"html"];
	NSString * baseString = [NSString stringWithContentsOfFile:baseStringPath encoding:NSUTF8StringEncoding error:&error];
	if (!baseString) return nil;
	
	NSMutableArray * parserFeatures = [NSMutableArray array];
		
	int webParserID = 0;
	Class webParserClass;
	while ( webParserClass = [BDSKWebParser webParserClassForType:webParserID] ) {
		[parserFeatures addObjectsFromArray: [webParserClass parserInfos]];
		webParserID++;
	}
	
	NSSortDescriptor * sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:BDSKPARSERFEATURENAME ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
	[parserFeatures sortUsingDescriptors:[NSArray arrayWithObject: sortDescriptor]];

	NSMutableArray * publicFeatures = [NSMutableArray array];
	NSMutableArray * subscriptionFeatures = [NSMutableArray array];
	NSMutableArray * generalFeatures = [NSMutableArray array];
	
	NSEnumerator * myEnum = [parserFeatures objectEnumerator];
	NSDictionary * parserInfo; 
	while ( parserInfo = [myEnum nextObject] ) {
		NSUInteger parserFlags = [[parserInfo objectForKey:BDSKPARSERFEATUREFLAGS] unsignedIntValue];
		if ( parserFlags & BDSKPARSERFEATUREFLAGALLPAGES ) {
			// it's a 'general' parser that's not limited to particular sites
			[generalFeatures addObject: parserInfo];
		}
		else {
			if ( parserFlags & BDSKPARSERFEATUREFLAGSUBSCRIPTION ) {
				[subscriptionFeatures addObject: parserInfo];
			}
			else {
				[publicFeatures addObject: parserInfo];
			}
		}
	}
	
	NSString * publicFeatureMarkup = [self markupForSiteArray:publicFeatures];
	NSString * subscriptionFeatureMarkup = [self markupForSiteArray:subscriptionFeatures];
	NSString * generalFeatureMarkup = [self markupForSiteArray:generalFeatures];
	
	NSString * result = [NSString stringWithFormat:baseString, publicFeatureMarkup, subscriptionFeatureMarkup, generalFeatureMarkup];
	NSData * data = [result dataUsingEncoding:NSUTF8StringEncoding];
	
	return data;
}



/*
 Input: Array of Site Dictionaries
 Output: HTML markup for a list of links to the sites described in the dictionaries with list items separated by commas and ending with a full stop. If available, a description of the site is inserted in the anchor tag's title attribute.
*/
- (NSString *) markupForSiteArray: (NSArray *) siteArray {
	NSEnumerator * myEnum = [siteArray objectEnumerator];
	NSMutableArray * linkStrings = [NSMutableArray arrayWithCapacity:[siteArray count] * 2];
	NSDictionary * siteInfo;
	NSString * s;
	
	while (siteInfo = [myEnum nextObject]) {
		NSXMLElement * aElement = [NSXMLElement elementWithName:@"a" stringValue:[siteInfo objectForKey:BDSKPARSERFEATURENAME]];
		NSString * addressString = [siteInfo objectForKey:BDSKPARSERFEATUREADDRESS];
		if (addressString) {
			NSXMLNode * hrefNode = [NSXMLNode attributeWithName:@"href" stringValue: addressString];
			[aElement addAttribute:hrefNode];
		}
		NSString * titleString = [siteInfo objectForKey:BDSKPARSERFEATUREDESCRIPTION];
		if (titleString) {
			NSXMLNode * titleNode = [NSXMLNode attributeWithName:@"title" stringValue:titleString];
			[aElement addAttribute:titleNode];
		}
		
		[linkStrings addObject:[aElement XMLString]];
	}
	
	NSString * result = [[linkStrings componentsJoinedByString:@", "] stringByAppendingString:@"."];
	return result;
}


@end

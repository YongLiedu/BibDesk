//
//  BDSKIACRParser.m
//  Bibdesk
//
//  Created by Douglas Stebila on 2/10/10.
/*
 This software is Copyright (c) 2010-2011
 Douglas Stebila. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Douglas Stebila nor the names of any
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

#import "BDSKIACRParser.h"
#import "BibItem.h"
#import "NSError_BDSKExtensions.h"
#import "NSXMLNode_BDSKExtensions.h"
#import <AGRegex/AGRegex.h>


@implementation BDSKIACRParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    if (nil == [url host] || NO == [[[url host] lowercaseString] hasSuffix:@"eprint.iacr.org"]){
        return NO;
    }
    
    AGRegex *absRegex = [AGRegex regexWithPattern:@"^/[0-9]{4}/[0-9]+$"];
	BOOL isAbstract = ([absRegex findInString:[url path]] != nil);

	BOOL isSearch = [[[url path] lowercaseString] hasPrefix:@"/cgi-bin/search.pl"];
	
	return isAbstract || isSearch;
	
}

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:0];
	
	NSError *error = nil;

	// is this a search results page or an individual article?
	BOOL isSearch = [[[url path] lowercaseString] hasPrefix:@"/cgi-bin/search.pl"];

	// construct the source item(s) to parse
	NSArray *sources = nil;
    if (isSearch) {
        sources = [[xmlDocument rootElement] nodesForXPath:@"//dt" error:&error];
    } else {
        sources = [NSArray arrayWithObjects:[xmlDocument rootElement], nil];
	}
	
	NSUInteger i;
    for (i = 0; i < [sources count]; i++) {
		
        NSXMLNode *xmlNode = [sources objectAtIndex:i];
		NSMutableDictionary *pubFields = [NSMutableDictionary dictionary];
		NSMutableArray *filesArray = [NSMutableArray arrayWithCapacity:0];
		
		// set title
		if (isSearch) {
			[xmlNode searchXPath:@"following-sibling::dd/b" addTo:pubFields forKey:BDSKTitleString];
		} else {
			[xmlNode searchXPath:@".//b" addTo:pubFields forKey:BDSKTitleString];
		}
		
		// set authors
		if (isSearch) {
			[xmlNode searchXPath:@"following-sibling::dd[position()=2]/em" addTo:pubFields forKey:BDSKAuthorString];
		} else {
			[xmlNode searchXPath:@".//i" addTo:pubFields forKey:BDSKAuthorString];
		}

		// compute year and report number
		NSString *year = nil;
		NSString *reportNum = nil;
		NSString *pathToSearch;
		if (isSearch) {
			pathToSearch = [xmlNode searchXPath:@".//a/@href" addTo:nil forKey:nil];
		} else {
			pathToSearch = [url path];
		}
		AGRegex *yrnRegex = [AGRegex regexWithPattern:@"^/([0-9]{4})/([0-9]+)$"];
		AGRegexMatch *yrnMatch = [yrnRegex findInString:pathToSearch];
		year = [yrnMatch groupAtIndex:1];
		reportNum = [yrnMatch groupAtIndex:2];
		
		// set year, report number, PDF url, eprint
		if ((year != nil) && (reportNum != nil)) {
			[pubFields setValue:year forKey:BDSKYearString];
			[pubFields setValue:[NSString stringWithFormat:@"Cryptology ePrint Archive, Report %@/%@", year, reportNum] forKey:@"Note"];
			[filesArray addObject:[BDSKLinkedFile linkedFileWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@/%@/%@.pdf", [url host], year, reportNum]] delegate:nil]];
			[filesArray addObject:[BDSKLinkedFile linkedFileWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@/%@/%@", [url host], year, reportNum]] delegate:nil]];
			[pubFields setValue:[NSString stringWithFormat:@"\\url{http://%@/%@/%@}", [url host], year, reportNum] forKey:@"Eprint"];
		}

		// add item
		BibItem *item = [[BibItem alloc] initWithType:BDSKMiscString citeKey:nil pubFields:pubFields files:filesArray isNew:YES];
		[items addObject:item];
		[item release];
			
	}
	
	return items;  
}
	
+ (NSDictionary *)parserInfo {
	NSString *parserDescription = NSLocalizedString(@"ePrint archive of the International Association for Cryptologic Research (IACR).", @"Description for IACR site");
	return [BDSKWebParser parserInfoWithName:@"IACR (Cryptology)" address:@"http://eprint.iacr.org/" description:parserDescription feature:BDSKParserFeaturePublic];
}

@end

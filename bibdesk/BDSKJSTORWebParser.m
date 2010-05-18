//
//  BDSKJSTORWebParser.m
//  Bibdesk
//
//  Created by Douglas Stebila on 5/18/10.
/*
 This software is Copyright (c) 2010
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

#import "BDSKJSTORWebParser.h"
#import "BDSKBibTeXParser.h"
#import "BibItem.h"
#import "NSError_BDSKExtensions.h"
#import "NSXMLNode_BDSKExtensions.h"
#import <AGRegex/AGRegex.h>


@implementation BDSKJSTORWebParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    if (nil == [url host] || NO == [[[url host] lowercaseString] hasSuffix:@"jstor.org"]){
        return NO;
    }
    
    AGRegex *absRegex = [AGRegex regexWithPattern:@"^/stable/[0-9]+"];
	BOOL isAbstract = ([absRegex findInString:[url path]] != nil);
	
	return isAbstract;
	
}

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:1];
	
	NSError *error = nil;
	NSStringEncoding encoding = NSASCIIStringEncoding;
	
	// extract JSTOR article number
	NSString *jstorNumber;
	AGRegex *jstorRegex = [AGRegex regexWithPattern:@"^/stable/([0-9]+)"];
	AGRegexMatch *jstorMatch = [jstorRegex findInString:[url path]];
	if ([jstorMatch count] != 2) {
		return items;
	}
	jstorNumber = [jstorMatch groupAtIndex:1];
	
	// download BibTeX data
	NSString *bibtexURLString = [NSString stringWithFormat:@"http://www.jstor.org/action/downloadSingleCitation?format=bibtex&include=abs&singleCitation=true&suffix=%@", jstorNumber];
	NSURL *bibtexURL = [NSURL URLWithString:bibtexURLString];
	NSString *bibtexData = [NSString stringWithContentsOfURL:bibtexURL usedEncoding:&encoding error:&error];
	if (bibtexData == nil) {
		return items;
	}
	
	// remove characters before the first @ symbol
	NSRange range = [bibtexData rangeOfString:@"@"];
	if (range.location == NSNotFound) {
		return items;
	}
	bibtexData = [bibtexData substringFromIndex:range.location];

	// parse BibTeX data
	NSArray *parsedItems = [BDSKBibTeXParser itemsFromString:bibtexData owner:nil isPartialData:NO error:outError];
	if (parsedItems) {
		[items addObjectsFromArray:parsedItems];
	}
	
	return items;  
}

+ (NSArray *) parserInfos {
	NSString * parserDescription = NSLocalizedString(@"JSTOR archives.", @"Description for JSTOR site");
	NSDictionary * parserInfo = [BDSKWebParser parserInfoWithName:@"JSTOR" address:@"http://www.jstor.org/" description:parserDescription flags:BDSKParserFeatureSubscriptionMask];
	
	return [NSArray arrayWithObject: parserInfo];
}

@end

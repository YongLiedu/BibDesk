//
//  BDSKACMDLParser.m
//  Bibdesk
//
//  Created by Douglas Stebila on 3/3/11.
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

#import "BDSKACMDLParser.h"
#import "BDSKBibTeXParser.h"
#import "BibItem.h"
#import "NSError_BDSKExtensions.h"
#import "NSXMLNode_BDSKExtensions.h"
#import <AGRegex/AGRegex.h>


@implementation BDSKACMDLParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    if (nil == [url host] || NO == [[[url host] lowercaseString] isEqualToString:@"portal.acm.org"]){
        return NO;
    }
    
    NSError *error;
    NSArray *nodes = [xmlDocument nodesForXPath:@".//meta[@name='citation_abstract_html_url']/@content" error:&error];
    if ([nodes count] == 0) return NO;
    NSString *node = [[nodes objectAtIndex:0] stringValue];
    
    AGRegex *doiRegex = [AGRegex regexWithPattern:@"^http://portal.acm.org/citation.cfm.id=[0-9]*\\.[0-9]*$"];
	return ([doiRegex findInString:node] != nil);
	
}

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:1];
	
	NSError *error = nil;
	NSStringEncoding encoding = NSASCIIStringEncoding;
	
	// extract article number and parent number
    NSArray *nodes = [xmlDocument nodesForXPath:@".//meta[@name='citation_abstract_html_url']/@content" error:&error];
    if ([nodes count] == 0) return items;
    NSString *node = [[nodes objectAtIndex:0] stringValue];

    AGRegex *doiRegex = [AGRegex regexWithPattern:@"^http://portal.acm.org/citation.cfm.id=([0-9]*)\\.([0-9]*)$"];
	AGRegexMatch *match = [doiRegex findInString:node];
	if ([match count] != 3) {
		return items;
	}
	NSString *parentNumber = [match groupAtIndex:1];
	NSString *articleNumber = [match groupAtIndex:2];
	
	// download BibTeX data
	NSString *bibtexURLString = [NSString stringWithFormat:@"http://portal.acm.org/downformats.cfm?id=%@&parent_id=%@&expformat=bibtex", articleNumber, parentNumber];
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
    
    // remove spaces in cite key (for some reason, ACM will use author names with spaces in the cite key
    // but btparse chokes on these)
	range = [bibtexData rangeOfString:@","];
	if (range.location == NSNotFound) {
		return items;
	}
    NSRange newrange;
    newrange.length = range.location;
    newrange.location = 0;
    bibtexData = [bibtexData stringByReplacingOccurrencesOfString:@" " withString:@"" options:0 range:newrange];
    
	// parse BibTeX data
	NSArray *parsedItems = [BDSKBibTeXParser itemsFromString:bibtexData owner:nil isPartialData:NO error:outError];
	if (parsedItems) {
		[items addObjectsFromArray:parsedItems];
	}
	
	return items;  
}

+ (NSDictionary *)parserInfo {
	return [BDSKWebParser parserInfoWithName:@"ACM" address:@"http://portal.acm.org/" description:nil feature:BDSKParserFeaturePublic];
}

@end

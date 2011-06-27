//
//  BDSKBibTeXWebParser.m
//  Bibdesk
//
//  Created by Douglas Stebila on 2/11/10.
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

#import "BDSKBibTeXWebParser.h"
#import "BDSKBibTeXParser.h"
#import "BibItem.h"
#import "NSError_BDSKExtensions.h"
#import "NSXMLNode_BDSKExtensions.h"
#import <AGRegex/AGRegex.h>


@implementation BDSKBibTeXWebParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{

	AGRegex *regex = [AGRegex regexWithPattern:@"@[[:alpha:]]+[ \\t]*[{(]"];
	AGRegexMatch *match = [regex findInString:[xmlDocument XMLStringWithOptions:NSXMLDocumentTextKind]];
	if ([match count] > 0) {
		return YES;
	}
	
	return NO;
	
}

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	
	// get a plain text representation of the document, erasing any XML tags along the way
	NSString *inputString = [xmlDocument XMLStringWithOptions:NSXMLDocumentTextKind];
	AGRegex *cleanRegex = [AGRegex regexWithPattern:@"<[^>]*>"];
	inputString = [cleanRegex replaceWithString:@"" inString:inputString];
	
    NSMutableArray *items = [NSMutableArray array];
	
	// get a list of all things that might be the beginnings of a BibTeX item
	AGRegex *regex = [AGRegex regexWithPattern:@"@[[:alpha:]]+[ \\t]*[{(]"];
	NSArray *sourceItems = [regex findAllInString:inputString];
	NSUInteger i, iMax = [sourceItems count];
    
	for (i = 0; i < iMax; i++) {
		AGRegexMatch *match = [sourceItems objectAtIndex:i];
		NSString *sourceItem;
		NSRange r = [match range];
		if (i < iMax - 1)
			// if this isn't the last item, then we need to trim the next item off of it
			// since the BibTeX parser will parse as many consecutive BibTeX strings as it can find
			r.length = [[sourceItems objectAtIndex:i+1] range].location - r.location;
		else
			r.length = [inputString length] - r.location;
        sourceItem = [inputString substringWithRange:r];
		// parse this string as BibTeX, if we can
		if ([BDSKBibTeXParser canParseString:sourceItem])
			[items addObjectsFromArray:[BDSKBibTeXParser itemsFromString:sourceItem owner:nil isPartialData:NO error:outError]];
	}
	
	return items;  
	
}

+ (NSDictionary *)parserInfo {
	NSString *parserDescription = NSLocalizedString(@"BibTeX is often used in conjunction with LaTeX for storing bibliographic data and is the native format of BibDesk.", @"Description for BibTeX web parser");
	return [BDSKWebParser parserInfoWithName:@"BibTeX" 
                                     address:@"http://en.wikipedia.org/wiki/BibTeX" 
                                 description:parserDescription 
                                       feature:BDSKParserFeatureGeneric];
}

@end

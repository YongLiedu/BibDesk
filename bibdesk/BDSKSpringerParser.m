//
//  BDSKSpringerParser.m
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

#import "BDSKSpringerParser.h"
#import "BibItem.h"
#import "NSError_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "NSXMLNode_BDSKExtensions.h"
#import <AGRegex/AGRegex.h>


@implementation BDSKSpringerParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    if ((nil == [url host]) || 
        (NO == [[[url host] lowercaseString] hasSuffix:@"www.springerlink.com"]) || 
		(NO == [[[url path] lowercaseString] hasPrefix:@"/content/"])
	) {
        return NO;
    }

	return YES;
	
}

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:1];
    BibItem *item = [BDSKSpringerParser itemFromXMLDocument:xmlDocument fromURL:url error:outError];
    if (item != nil) {
        [items addObject:item];
        [item release];
    }
	return items;  
}

+ (NSString *)authorStringFromXMLNode:(NSXMLNode *)xmlNode searchXPath:(NSString *)xPath {
	NSError *error = nil;
	NSArray *authorNodes = [xmlNode nodesForXPath:xPath error:&error];
    NSMutableArray *authorStrings = [[NSMutableArray alloc] initWithCapacity:[authorNodes count]];
    NSXMLNode *node;
    for (node in authorNodes) {
        [authorStrings addObject:[node stringValue]];
    }
	return [authorStrings componentsJoinedByAnd];;
}

+ (BibItem *)itemFromXMLDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
    
	NSXMLNode *xmlNode = [xmlDocument rootElement];
	NSMutableDictionary *pubFields = [NSMutableDictionary dictionary];
	NSMutableArray *filesArray = [NSMutableArray arrayWithCapacity:0];
    
    NSString *pubType = BDSKMiscString;
    // set publication type
    NSString *pubTypeGuess = [xmlNode searchXPath:@".//div[@id='ContentHeading']/div[@class='heading enumeration']/div[@class='primary']/a/@title" addTo:nil forKey:nil];
    if (pubTypeGuess != nil) {
        if ([pubTypeGuess isEqualToString:@"Link to the Book of this Chapter"]) {
            pubType = BDSKChapterString;
        } else if ([pubTypeGuess isEqualToString:@"Link to the Journal of this Article"]) {
            pubType = BDSKArticleString;
        } else {
            return nil;
        }
    }
    
	// set title
	[xmlNode searchXPath:@".//div[@id='ContentHeading']/div[@class='heading primitive']/div[@class='text']/h1" addTo:pubFields forKey:BDSKTitleString];
	// set book or journal
    if ([pubType isEqualToString:BDSKChapterString]) {
        [xmlNode searchXPath:@".//div[@id='ContentHeading']/div[@class='heading enumeration']/div[@class='primary']/a" addTo:pubFields forKey:BDSKBooktitleString];
    } else if ([pubType isEqualToString:BDSKArticleString]) {
        [xmlNode searchXPath:@".//div[@id='ContentHeading']/div[@class='heading enumeration']/div[@class='primary']/a" addTo:pubFields forKey:BDSKJournalString];
    }
	// set DOI and store for later use
	NSString *doi = [xmlNode searchXPath:@".//div[@id='ContentHeading']/div[@class='heading enumeration']//span[@class='doi']/span[@class='value']" addTo:pubFields forKey:BDSKDoiString];

	// set pages
	NSString *pages = [xmlNode searchXPath:@".//div[@id='ContentHeading']/div[@class='heading enumeration']//span[@class='pagination']" addTo:pubFields forKey:BDSKPagesString];
    if (pages != nil) {
        AGRegex *pagesRegex = [AGRegex regexWithPattern:@"^([0-9]*)-([0-9]*)?"];
        AGRegexMatch *match = [pagesRegex findInString:pages];
        if ([match count] == 3) {
            NSMutableString *page = [[match groupAtIndex:1] mutableCopy];
            NSString *endPage = [match groupAtIndex:2];
            [page appendString:@"--"];
            if([page length] - 2 > [endPage length])
                [page appendString:[page substringToIndex:[page length] - [endPage length] - 2]];
            [page appendString:endPage];
            [pubFields setObject:page forKey:BDSKPagesString];
            [page release];
        }
    }
	// set authors
	[pubFields setValue:[BDSKSpringerParser authorStringFromXMLNode:xmlNode searchXPath:@".//div[@id='ContentHeading']/div[@class='heading primitive']/div[@class='text']/p[@class='authors']/a"] forKey:BDSKAuthorString];
	// set editors
	[pubFields setValue:[BDSKSpringerParser authorStringFromXMLNode:xmlNode searchXPath:@".//div[@id='ContentHeading']/div[@class='heading primitive']/div[@class='text']/p[@class='editors']/a"] forKey:BDSKEditorString];
	// set series
    if ([pubType isEqualToString:BDSKChapterString]) {
        [xmlNode searchXPath:@".//div[@id='ContentHeading']/div[@class='heading enumeration']/div[@class='secondary']/a" addTo:pubFields forKey:BDSKSeriesString];
    }
    
    // volume, number, and year
    NSString *vyString = [xmlNode searchXPath:@".//div[@id='ContentHeading']/div[@class='heading enumeration']/div[@class='secondary']" addTo:nil forKey:nil];
    if (vyString != nil) {
        // parse volume number
		AGRegex *volRegex = [AGRegex regexWithPattern:@"Volume ([0-9]*)[^0-9]"];
		AGRegexMatch *volMatch = [volRegex findInString:vyString];
		// set volume
		if (nil != [volMatch groupAtIndex:1]) {
			[pubFields setValue:[volMatch groupAtIndex:1] forKey:BDSKVolumeString];
		}
        // parse issue number
		AGRegex *numRegex = [AGRegex regexWithPattern:@"Number ([0-9]*)[^0-9]"];
		AGRegexMatch *numMatch = [numRegex findInString:vyString];
		// set number
		if (nil != [numMatch groupAtIndex:1]) {
			[pubFields setValue:[numMatch groupAtIndex:1] forKey:BDSKNumberString];
		}
        // parse year
		AGRegex *yearRegex = [AGRegex regexWithPattern:@"[^0-9]([12][0-9][0-9][0-9])[^0-9]"];
		AGRegexMatch *yearMatch = [yearRegex findInString:vyString];
		// set year
		if (nil != [yearMatch groupAtIndex:1]) {
            // only if it appears before the string DOI to avoid confusing parts of the DOI as the year
            if ([vyString rangeOfString:[yearMatch groupAtIndex:1]].location < [vyString rangeOfString:@"DOI"].location) {
                [pubFields setValue:[yearMatch groupAtIndex:1] forKey:BDSKYearString];
            }
		}
    }
	
	// URL to PDF
	[filesArray addObject:[BDSKLinkedFile linkedFileWithURL:[NSURL URLWithString:@"fulltext.pdf" relativeToURL:url] delegate:nil]];
	// URL to DOI
	if (doi != nil) {
		[filesArray addObject:[BDSKLinkedFile linkedFileWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://dx.doi.org/%@", doi]] delegate:nil]];
	}
    
	return [[BibItem alloc] initWithType:pubType citeKey:nil pubFields:pubFields files:filesArray isNew:YES];
    
}

+ (NSDictionary *)parserInfo {
	NSString *parserDescription = NSLocalizedString(@"SpringerLink portal.  Browsing and abstracts are free but full text requires a subscription.", @"Description for Springer site");
	return [BDSKWebParser parserInfoWithName:@"SpringerLink" 
                                     address:@"http://www.springerlink.com/" 
                                 description:parserDescription 
                                       feature:BDSKParserFeatureSubscription];
}

@end

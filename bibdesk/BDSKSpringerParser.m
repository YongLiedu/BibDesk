//
//  BDSKSpringerParser.m
//  Bibdesk
//
//  Created by Douglas Stebila on 2/11/10.
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

#import "BDSKSpringerParser.h"
#import "BibItem.h"
#import "NSError_BDSKExtensions.h"
#import "NSXMLNode_BDSKExtensions.h"
#import <AGRegex/AGRegex.h>


@implementation BDSKSpringerParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    if ((NO == [[[url host] lowercaseString] hasSuffix:@"www.springerlink.com"]) || 
		(NO == [[[url path] lowercaseString] hasPrefix:@"/content/"])
	) {
        return NO;
    }

	NSString *itemType = [[xmlDocument rootElement] searchXPath:@".//span[@id=\"ctl00_PageHeadingLabel\"]" addTo:nil forKey:nil];
	if ([itemType isEqualToString:@"Journal Article"]) {
		return YES;
	} else if ([itemType isEqualToString:@"Book Chapter"]) {
		return YES;
	} else if ([itemType isEqualToString:@"Book"]) {
		return YES;
	}
	
	return NO;
	
}

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:0];
	
	NSString *itemType = [[xmlDocument rootElement] searchXPath:@".//span[@id=\"ctl00_PageHeadingLabel\"]" addTo:nil forKey:nil];

	if ([itemType isEqualToString:@"Journal Article"]) {
		BibItem *item = [BDSKSpringerParser journalArticleFromXMLDocument:xmlDocument fromURL:url error:outError];
		[items addObject:item];
		[item release];
	} else if ([itemType isEqualToString:@"Book Chapter"]) {
		BibItem *item = [BDSKSpringerParser bookChapterFromXMLDocument:xmlDocument fromURL:url error:outError];
		[items addObject:item];
		[item release];
	} else if ([itemType isEqualToString:@"Book"]) {
		BibItem *item = [BDSKSpringerParser bookFromXMLDocument:xmlDocument fromURL:url error:outError];
		[items addObject:item];
		[item release];
	}
	
	return items;  
	
}

+ (NSString *)authorStringFromXMLNode:(NSXMLNode *)xmlNode {
	// this is annoying because the SpringerLink HTML is not properly nested
	// we have to get the AuthorGroup string, chop the junk off the end of it, then remove all the extra junk that's inside of it
	NSError *error = nil;
	NSArray *authorNodes = [xmlNode nodesForXPath:@".//p[@class=\"AuthorGroup\"]" error:&error];
	if ([authorNodes count] == 0) {
		return nil;
	}
	NSString *authorXMLString = [[authorNodes objectAtIndex:0] XMLString];
	// trim junk off the end
	NSRange r = [authorXMLString rangeOfString:@"<table"];
	if (r.location != NSNotFound) {
		authorXMLString = [authorXMLString substringToIndex:r.location];
	}
	// trim junk off the beginning
	r = [authorXMLString rangeOfString:@">"];
	if (r.location != NSNotFound) {
		authorXMLString = [authorXMLString substringFromIndex:r.location + 1];
	}
	// trim junk out of the middle
	AGRegex *regex = [AGRegex regexWithPattern:@"<[^>]*>"];
	authorXMLString = [regex replaceWithString:@"<>" inString:authorXMLString];
	regex = [AGRegex regexWithPattern:@">and"];
	authorXMLString = [regex replaceWithString:@">," inString:authorXMLString];
	regex = [AGRegex regexWithPattern:@"<[^,]*"];
	authorXMLString = [regex replaceWithString:@"" inString:authorXMLString];
	regex = [AGRegex regexWithPattern:@","];
	authorXMLString = [regex replaceWithString:@" and " inString:authorXMLString];
	return authorXMLString;
}

+ (BibItem *)bookFromXMLDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	
	NSXMLNode *xmlNode = [xmlDocument rootElement];
	NSMutableDictionary *pubFields = [NSMutableDictionary dictionary];
	NSMutableArray *filesArray = [NSMutableArray arrayWithCapacity:0];
	
	// set title
	[xmlNode searchXPath:@".//h2[@class='MPReader_Profiles_SpringerLink_Content_PrimitiveHeadingControlName']" addTo:pubFields forKey:BDSKTitleString];
	[xmlNode searchXPath:@".//h2[@class='MPReader_Profiles_SpringerLink_Content_PrimitiveHeadingControlName']" addTo:pubFields forKey:BDSKBooktitleString];
	// set note from subtitle
	[xmlNode searchXPath:@".//div[@class='labelValue subtitle']" addTo:pubFields forKey:@"Note"];
	// set publisher
	[xmlNode searchXPath:@".//td[.='Publisher']/following-sibling::td" addTo:pubFields forKey:BDSKPublisherString];
	// set DOI and store for later use
	NSString *doi = [xmlNode searchXPath:@".//td[.='DOI']/following-sibling::td" addTo:pubFields forKey:BDSKDoiString];
	// set year
	[xmlNode searchXPath:@".//td[.='Copyright']/following-sibling::td" addTo:pubFields forKey:BDSKYearString];
	// set series
	[xmlNode searchXPath:@".//td[.='Book Series']/following-sibling::td/a" addTo:pubFields forKey:BDSKSeriesString];
	// set ISBN
	[xmlNode searchXPath:@".//td[.='ISBN']/following-sibling::td" addTo:pubFields forKey:@"Isbn"];
	// set edition
	[xmlNode searchXPath:@".//td[.='Edition']/following-sibling::td" addTo:pubFields forKey:@"Edition"];
	
	// parse volume number
	NSString *volumeString = [xmlNode searchXPath:@".//td[.='Volume']/following-sibling::td" addTo:nil forKey:nil];
	if (volumeString != nil) {
		AGRegex *volRegex = [AGRegex regexWithPattern:@"^Volume ([^/]*)"];
		AGRegexMatch *volMatch = [volRegex findInString:volumeString];
		// set volume
		if (nil != [volMatch groupAtIndex:1]) {
			[pubFields setValue:[volMatch groupAtIndex:1] forKey:BDSKVolumeString];
		}
	}
	
	// URL to DOI
	if (doi != nil) {
		[filesArray addObject:[BDSKLinkedFile linkedFileWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://dx.doi.org/%@", doi]] delegate:nil]];
	}
	
	return [[BibItem alloc] initWithType:BDSKBookString citeKey:nil pubFields:pubFields files:filesArray isNew:YES];
	
}

+ (BibItem *)bookChapterFromXMLDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{

	NSXMLNode *xmlNode = [xmlDocument rootElement];
	NSMutableDictionary *pubFields = [NSMutableDictionary dictionary];
	NSMutableArray *filesArray = [NSMutableArray arrayWithCapacity:0];

	// set title
	[xmlNode searchXPath:@".//h2[@class='MPReader_Profiles_SpringerLink_Content_PrimitiveHeadingControlName']" addTo:pubFields forKey:BDSKTitleString];
	// set note from subtitle
	[xmlNode searchXPath:@".//div[@class='labelValue subtitle']" addTo:pubFields forKey:@"Note"];
	// set book
	[xmlNode searchXPath:@".//td[.='Book']/following-sibling::td/a" addTo:pubFields forKey:BDSKBooktitleString];
	// set publisher
	[xmlNode searchXPath:@".//td[.='Publisher']/following-sibling::td" addTo:pubFields forKey:BDSKPublisherString];
	// set DOI and store for later use
	NSString *doi = [xmlNode searchXPath:@".//td[.='DOI']/following-sibling::td" addTo:pubFields forKey:BDSKDoiString last:YES];
	// set pages
	[xmlNode searchXPath:@".//td[.='Pages']/following-sibling::td" addTo:pubFields forKey:BDSKPagesString];
	// set authors
	[pubFields setValue:[BDSKSpringerParser authorStringFromXMLNode:xmlNode] forKey:BDSKAuthorString];
	// set year
	[xmlNode searchXPath:@".//td[.='Copyright']/following-sibling::td" addTo:pubFields forKey:BDSKYearString];
	// set series
	[xmlNode searchXPath:@".//td[.='Book Series']/following-sibling::td/a" addTo:pubFields forKey:BDSKSeriesString];

	// parse volume number
	NSString *volumeString = [xmlNode searchXPath:@".//td[.='Volume']/following-sibling::td" addTo:nil forKey:nil];
	if (volumeString != nil) {
		AGRegex *volRegex = [AGRegex regexWithPattern:@"^Volume (.*)/.*"];
		AGRegexMatch *volMatch = [volRegex findInString:volumeString];
		// set volume
		if (nil != [volMatch groupAtIndex:1]) {
			[pubFields setValue:[volMatch groupAtIndex:1] forKey:BDSKVolumeString];
		}
	}
	
	// URL to PDF
	[filesArray addObject:[BDSKLinkedFile linkedFileWithURL:[NSURL URLWithString:@"fulltext.pdf" relativeToURL:url] delegate:nil]];
	// URL to DOI
	if (doi != nil) {
		[filesArray addObject:[BDSKLinkedFile linkedFileWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://dx.doi.org/%@", doi]] delegate:nil]];
	}

	return [[BibItem alloc] initWithType:BDSKChapterString citeKey:nil pubFields:pubFields files:filesArray isNew:YES];

}
	
+ (BibItem *)journalArticleFromXMLDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	
	NSXMLNode *xmlNode = [xmlDocument rootElement];
	NSMutableDictionary *pubFields = [NSMutableDictionary dictionary];
	NSMutableArray *filesArray = [NSMutableArray arrayWithCapacity:0];
	
	// set title
	[xmlNode searchXPath:@".//h2[@class=\"MPReader_Profiles_SpringerLink_Content_PrimitiveHeadingControlName\"]" addTo:pubFields forKey:BDSKTitleString];
	// set journal
	[xmlNode searchXPath:@".//td[.='Journal']/following-sibling::td/a" addTo:pubFields forKey:BDSKJournalString];
	// set DOI and store for later use
	NSString *doi = [xmlNode searchXPath:@".//td[.='DOI']/following-sibling::td" addTo:pubFields forKey:BDSKDoiString];
	// set pages
	[xmlNode searchXPath:@".//td[.='Pages']/following-sibling::td" addTo:pubFields forKey:BDSKPagesString];
	// set authors
	[pubFields setValue:[BDSKSpringerParser authorStringFromXMLNode:xmlNode] forKey:BDSKAuthorString];
	
	// parse volume, issue number
	NSString *issueString = [xmlNode searchXPath:@".//td[.='Issue']/following-sibling::td/a" addTo:nil forKey:nil];
	if (issueString != nil) {
		AGRegex *issRegex = [AGRegex regexWithPattern:@"^Volume (.*), Number (.*) / ([^,]*), ([0-9]*)$"];
		AGRegexMatch *issMatch = [issRegex findInString:issueString];
		// set volume
		if (nil != [issMatch groupAtIndex:1]) {
			[pubFields setValue:[issMatch groupAtIndex:1] forKey:BDSKVolumeString];
		}
		// set number
		if (nil != [issMatch groupAtIndex:2]) {
			[pubFields setValue:[issMatch groupAtIndex:2] forKey:BDSKNumberString];
		}
		// set month
		if (nil != [issMatch groupAtIndex:3]) {
			[pubFields setValue:[issMatch groupAtIndex:3] forKey:BDSKMonthString];
		}
		// set year
		if (nil != [issMatch groupAtIndex:3]) {
			[pubFields setValue:[issMatch groupAtIndex:4] forKey:BDSKYearString];
		}
	}
	
	// URL to PDF
	[filesArray addObject:[BDSKLinkedFile linkedFileWithURL:[NSURL URLWithString:@"fulltext.pdf" relativeToURL:url] delegate:nil]];
	// URL to DOI
	if (doi != nil) {
		[filesArray addObject:[BDSKLinkedFile linkedFileWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://dx.doi.org/%@", doi]] delegate:nil]];
	}
	
	return [[BibItem alloc] initWithType:BDSKArticleString citeKey:nil pubFields:pubFields files:filesArray isNew:YES];
	
}

+ (NSArray *) parserInfos {
	NSString *parserDescription = NSLocalizedString(@"SpringerLink portal.  Browsing and abstracts are free but full text requires a subscription.", @"Description for Springer site");
	NSDictionary *parserInfo = [BDSKWebParser parserInfoWithName:@"SpringerLink" 
														  address:@"http://www.springerlink.com/" 
													  description:parserDescription 
															flags:BDSKParserFeatureSubscriptionMask];
	return [NSArray arrayWithObject: parserInfo];
}

@end

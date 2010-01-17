//
//  BDSKMathSiteParser.m
//  Bibdesk
//
//  Created by Sven-S. Porst on 2009-04-08.
/*
 This software is Copyright (c) 2009-2010
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

#import "BDSKMathSiteParser.h"
#import "BDSKMathSciNetParser.h"
#import "BDSKZentralblattParser.h"

#import "BibItem.h"
#import "BDSKComplexString.h"
#import <AGRegex/AGRegex.h>



@implementation BDSKMathSiteParser

/*
 Receives two arrays of paper IDs: one for MatSciNet, the other for Zentralblatt Math.
 If the arrays exist, they should both contain the same number of elements corresponding to the publications found on the page. Gaps are filled with NSNull.
 Tries to turn it into the best array of BibItems it can get, preferring MR records over those from Zentralblatt if both are available.
*/
+ (NSArray *) bibItemsForMRIDs:(NSArray *) MRIDs andZMathIDs:(NSArray *) ZMathIDs error:(NSError **) outError {
	NSObject * item;
	NSUInteger itemCount = (MRIDs) ? [MRIDs count] : [ZMathIDs count];
	NSMutableArray * list = [NSMutableArray arrayWithCapacity:itemCount];
	NSMutableArray * result = [NSMutableArray arrayWithCapacity:itemCount];
	NSUInteger i;
	for (i = 0; i < itemCount; i++) { [result addObject:[NSNull null]]; }
	
	// create list of (non-Null) MRIDs and retrive BibItems for them
	for (item in MRIDs) {
		if ([NSNull null] != item) {
			[list addObject:item];
		}
	}
		
	NSArray * bibItems = [BDSKMathSciNetParser bibItemsForMRIDs:list referrer:nil error:outError];
	
	// fill result array with bibItems at the correct position
	for (BibItem * bibItem in bibItems) {
		NSUInteger count;
		NSString * MRID = [[[bibItem citeKey] stringByRemovingPrefix:@"MR"] stringByReplacingOccurrencesOfString:@"0" withString:@"" options: NSAnchoredSearch replacements:&count];
		NSUInteger position = [MRIDs indexOfObject:MRID];
		if (position < [ZMathIDs count] && [NSNull null] != [ZMathIDs objectAtIndex:position]) {
			// this publication is also available in Zentralblatt Math -> add the link
			[bibItem addFileForURL:[BDSKZentralblattParser reviewLinkForID:[ZMathIDs objectAtIndex:position]] autoFile:NO runScriptHook:NO];
		}
		[result replaceObjectAtIndex:position withObject:bibItem];
	}
	
	
	// create list of (non-Null) Zentralblatt items that can provide further records
	[list removeAllObjects];
	if ( [ZMathIDs count] == itemCount) { // make sure our ZMath array contains enough elements
		for (i = 0; i < itemCount; i++) {
			if ([result objectAtIndex:i] == [NSNull null]) {
				if (item = [ZMathIDs objectAtIndex:i]) {
					[list addObject:item];
				}
			}
		}
		
		// add these new results to the result array
		if ([list count] > 0) {
			bibItems = [BDSKZentralblattParser bibItemsForZMathIDs:list referrer:nil error:outError];
			for (BibItem *bibItem in bibItems) {
				NSString * ZMathID = [bibItem  citeKey];
				NSUInteger position = [ZMathIDs indexOfObject:ZMathID];
				[result replaceObjectAtIndex:position withObject:bibItem];
			}
		}
	}
	
	[result removeObject:[NSNull null]];
	
	return result;
}

@end






@implementation BDSKProjectEuclidParser


/*
 Recognise Project Euclid pages by their server name ending in projecteuclid.org.
*/
+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
	BOOL result = NO;
	NSString * hostName = [url host];
	if (hostName) {
		result = ([hostName rangeOfString:@"projecteuclid.org" options: (NSAnchoredSearch | NSCaseInsensitiveSearch | NSBackwardsSearch)].location != NSNotFound);
	}
	return result;
}

	

/*
 Find references for Mathematical Reviews and Zentralblatt Math in the page. Then look them up, giving preference to MSN if both are available.
*/ 
+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	NSError * error;

	NSArray * identifiers = [xmlDocument nodesForXPath:@".//div[@id='identifier']/p" error:&error];
	if ( [identifiers count] == 0 ) { return identifiers; } // no identifier on this page => probably a non-article page on the site => return empty array
	
	NSXMLElement * identifier = [identifiers objectAtIndex:0];
	NSString * identifierString = [identifier stringValue];
	
	AGRegex * MRRegexp = [AGRegex regexWithPattern:@"MR([1-9][0-9]*)" options:0];
	AGRegex * ZMathRegexp = [AGRegex regexWithPattern:@"Zentralblatt.* ([0-9.]+)" options:0];
	AGRegexMatch * match;
	
	// find IDs for the item itself
	match = [MRRegexp findInString:identifierString];
	NSObject * myMRID = [[match string] substringWithRange:[match rangeAtIndex:1]];
	if (nil == myMRID) { myMRID = [NSNull null]; }
	
	match = [ZMathRegexp findInString:identifierString];
	NSObject * myZMathID = [[match string] substringWithRange:[match rangeAtIndex:1]];
	if (nil == myZMathID) { myZMathID = [NSNull null]; }


	// Set up arrays for the lists of MathSciNet and Zentralblatt IDs. These will have the ID for the current element at position 0 and contain NSNull when no ID is found for the respective service.
	NSArray * references = [xmlDocument nodesForXPath:@".//div[@id='references']/div[@class='ref-block']" error:&error];
	NSMutableArray * MRIDs = [NSMutableArray arrayWithCapacity:[references count]];
	[MRIDs addObject:myMRID];
	NSMutableArray * ZMathIDs = [NSMutableArray arrayWithCapacity:[references count]];
	[ZMathIDs addObject:myZMathID];
	
	for (NSXMLElement * reference in references) {
		NSString * referenceString = [reference stringValue];

		match = [MRRegexp findInString:referenceString];
		NSObject * referenceID = [[match string] substringWithRange:[match rangeAtIndex:1]];
		if (nil == referenceID) { referenceID = [NSNull null]; }
		[MRIDs addObject:referenceID];
		
		match = [ZMathRegexp findInString:referenceString];
		referenceID = [[match string] substringWithRange:[match rangeAtIndex:1]];
		if (nil == referenceID) { referenceID = [NSNull null]; }
		[ZMathIDs addObject:referenceID];
	}
	
	NSArray * result = [BDSKMathSiteParser bibItemsForMRIDs:MRIDs andZMathIDs:ZMathIDs error:outError];
	
	// add Project Euclid URL to item's own record
	if ( [result count] > 0 ) {
		NSObject * item = [result objectAtIndex:0];
		if ( [item isKindOfClass:[BibItem class]] ) {
			AGRegex * ProjectEuclidRegexp = [AGRegex regexWithPattern:@"(http://projecteuclid.org/[^\\s]*)" options:0];
			match = [ProjectEuclidRegexp findInString:identifierString];
			NSString * projectEuclidURLString = [[match string] substringWithRange:[match rangeAtIndex:1]];
			NSURL * projectEuclidURL = [NSURL URLWithString:projectEuclidURLString];
	
			if ( projectEuclidURL ) {
				BOOL added = [(BibItem *)item addFileForURL:projectEuclidURL autoFile:NO runScriptHook:NO];
				if ( added ) {
					NSIndexSet * indexSet = [NSIndexSet indexSetWithIndex:[(BibItem *)item countOfFiles] - 1];
					[(BibItem *)item moveFilesAtIndexes:indexSet toIndex:0];
				}
			}
		}
	}
	
	return result;
}


+ (NSArray *) parserInfos {
	NSString * parserDescription = NSLocalizedString(@"Project Euclid provides a publishing platform for \342\200\230independent and society journals\342\200\231 in mathematics and statistics. BibDesk can provide bibliographic information for its articles if you have access to MathSciNet or Zentralblatt Math.", @"Description for Project Euclid site");
	NSDictionary * parserInfo = [BDSKWebParser parserInfoWithName:@"Project Euclid" address:@"http://projecteuclid.org/"  description: parserDescription flags: BDSKParserFeatureSubscriptionMask];
	
	return [NSArray arrayWithObject:parserInfo];
}

@end





@implementation BDSKNumdamParser

/*
 Recognise Numdam pages by their server name ending in numdam.org.
*/
+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
	BOOL result =  NO;
	NSString * hostName = [url host];
	if (hostName) {
		result = ([hostName rangeOfString:@"numdam.org" options: (NSAnchoredSearch | NSCaseInsensitiveSearch | NSBackwardsSearch)].location != NSNotFound) ;
	}
	return result;
}


/*
 Find references from Zentralblatt Math referred to by the page. Then look them up. Insert link to NUMDAM in the item's own record.
 (Support for MatSciNet is currently commented out as their lookup script requires online-style MR1234567 identifiers and NUMDAM uses paper-style identifiers a la 16,957b.)
*/ 
+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	NSError * error;
	
	NSArray * tableCells = [xmlDocument nodesForXPath:@".//td[@id='contenu']" error:&error];
	NSXMLElement * tableCell = [tableCells objectAtIndex:0];
	NSString * content = [tableCell stringValue];

	NSArray * rawReferences = [content componentsSeparatedByString:@"\n"];

	// NSMutableArray * MRReferences = [NSMutableArray arrayWithCapacity:[rawReferences count]];
	NSMutableArray * ZMathReferences = [NSMutableArray arrayWithCapacity:[rawReferences count]];
	
	// MR Regexp should cover things like  MR 16,957b / MR 46 #912. Spaces are normal for main item and non-breaking for bibliography items.
	// AGRegex * MRRegexp = [AGRegex regexWithPattern:@"MR[ \302\240]([0-9#,a-zA-Z: ]*[0-9a-z])" options:0];
	
	// Zbl Regexp should cover things like  Zbl 0374.57002. Spaces are normal for main item and non-breaking for bibliography items.
	AGRegex * ZMathRegexp = [AGRegex regexWithPattern:@"Zbl[ \302\240]([0-9]+\\.[0-9]+)" options:0]; 
	AGRegexMatch * match;	

	
	BOOL firstElementIsOwnId = NO; // to know whether the initial BibItem is for this item later on
	BOOL inReferences = NO;
	for (NSString *item in rawReferences) {
		if ([item rangeOfString:@"References"].location != NSNotFound) { inReferences = YES; }
		/* 
		match = [MRRegexp findInString:item];
		NSObject * MRID = nil;
		if (match) {
			NSUInteger count;
			MRID = [[[match string] substringWithRange:[match rangeAtIndex:1]] stringByReplacingOccurrencesOfString:@" #" withString:@":" options:NSLiteralSearch replacements:&count];
		}
		*/
		
		match = [ZMathRegexp findInString:item];
		NSObject * ZMathID = nil;
		if (match) {
			ZMathID = [[match string] substringWithRange:[match rangeAtIndex:1]];
		}
		
		if ( /* MRID || */  ZMathID) {
			// if ( nil == MRID ) { MRID = [NSNull null]; }
			// if ( nil == ZMathID ) { ZMathID = [NSNull null]; }
			// [MRReferences addObject:MRID];
			[ZMathReferences addObject:ZMathID];
			if ( !inReferences ) {
				firstElementIsOwnId = YES;
				inReferences = YES;
			}
		}		
	}
	
	
	NSArray * result = [BDSKMathSiteParser bibItemsForMRIDs:nil andZMathIDs:ZMathReferences error:outError];
	
	// add Numdam URL to item's own record
	if ( [result count] > 0 && firstElementIsOwnId ) {
		BibItem *item = [result objectAtIndex:0];
		if ( [item isKindOfClass:[BibItem class]] ) {
			AGRegex * URLRegexp = [AGRegex regexWithPattern:@"stable URL: ([a-zA-Z0-9:=./?_]*)" options:0];
			match = [URLRegexp findInString:content];
			
			if ([match count] >= 2) {
				NSString * myURLString = [[match string] substringWithRange:[match rangeAtIndex:1]];
				NSURL * myURL = [NSURL URLWithString:myURLString];
				if ( myURL ) {
					BOOL added = [(BibItem *)item addFileForURL:myURL autoFile:NO runScriptHook:NO];
					if (added) {
						NSIndexSet * indexSet = [NSIndexSet indexSetWithIndex:[(BibItem *)item countOfFiles] - 1];
						[(BibItem *)item moveFilesAtIndexes:indexSet toIndex:0];
					}
				}
			}
		}
	}
	
	return result;
}



+ (NSArray *) parserInfos {
	NSString * parserDescription = NSLocalizedString(@"NUMDAM (Num\303\251risation de documents anciens math\303\251matiques) provides digital versions of old mathematical papers. The site itself is public but BibDesk\342\200\231s support for it requires access to the Zentralblatt Math service.", @"Description for NUMDAM site");
	NSDictionary * parserInfo = [BDSKWebParser parserInfoWithName:@"NUMDAM" address:NSLocalizedString(@"http://www.numdam.org/?lang=en", @"URL for NUMDAM")  description:parserDescription flags: BDSKParserFeatureSubscriptionMask];
	
	return [NSArray arrayWithObject: parserInfo];
}


@end


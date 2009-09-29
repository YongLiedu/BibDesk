//
//  TestBibItem.m
//  Bibdesk
//
//  Created by Gregory Jefferis on 2009-01-05.
/* This software is Copyright (c) 2009
 Gregory Jefferis. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Gregory Jefferis nor the names of any
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

#import "TestBibItem.h"
#import "BibItem.h"
#import "BibAuthor.h"
#import "BDSKBibTeXParser.h"
#import "BDSKStringConstants.h"
#import "BDSKTypeManager.h"
#import "BDSKStringParser.h"
#import "NSString_BDSKExtensions.h"

#define oneItem @"@inproceedings{Lee96RTOptML,\nYear = {1996},\nUrl = {http://citeseer.nj.nec.com/70627.html},\nTitle = {Optimizing ML with Run-Time Code Generation},\nBooktitle = {PLDI},\nAuthor = {Peter Lee and Mark Leone}}"
#define twoItems @"@inproceedings{Lee96RTOptML,\nYear = {1996},\nUrl = {http://citeseer.nj.nec.com/70627.html},\nTitle = {Optimizing ML with Run-Time Code Generation},\nBooktitle = {PLDI},\nAuthor = {Peter Lee and Mark Leone}}\n\n@inproceedings{yang01LoopTransformPowerImpact,\nYear = {2001},\nTitle = {Power and Energy Impact by Loop Transformations},\nBooktitle = {COLP '01},\nAuthor = {Hongbo Yang and Guang R. Gao and Andres Marquez and George Cai and Ziang Hu}}"


@implementation TestBibItem
- (void)setUp {
    // create the object(s) that we want to test
    [super setUp];
}

-(void)tearDown {
    // clean up any stuff like open files or whatever
    [super tearDown];
}

- (void)testInitWithType{		
	
	// This was Mike's original test, but I'm not sure what Less, von More is supposed to mean anyway
	NSDictionary *pubFields = [NSDictionary dictionaryWithObjectsAndKeys:@"Hello", BDSKTitleString,
							   @"Less, von More, Jr.", BDSKAuthorString, nil];
	BibItem *b = [[[BibItem alloc] initWithType:BDSKArticleString fileType:BDSKBibtexString citeKey:nil pubFields:pubFields isNew:YES] autorelease];
	
    STAssertEquals(1, [b numberOfAuthors],@"Check that Less, von More, Jr. parses to single author");
}

- (void)testComplexAuthorNameNormalisation{
	// Check for parsing of two variants
	// "First von Last" "von Last, First"
	NSDictionary *pubFields1 = [NSDictionary dictionaryWithObjectsAndKeys:@"Hello", BDSKTitleString,
								@"First von Last", BDSKAuthorString, nil];
	NSDictionary *pubFields2 = [NSDictionary dictionaryWithObjectsAndKeys:@"Hello", BDSKTitleString,
								@"von Last, First", BDSKAuthorString, nil];
	BibItem *b1 = [[[BibItem alloc] initWithType:BDSKArticleString fileType:BDSKBibtexString citeKey:nil pubFields:pubFields1 isNew:YES] autorelease];
	BibItem *b2 = [[[BibItem alloc] initWithType:BDSKArticleString fileType:BDSKBibtexString citeKey:nil pubFields:pubFields2 isNew:YES] autorelease];

	STAssertEqualObjects([[b1 firstAuthor] firstName], @"First", @"first name of First von Last");
	STAssertEqualObjects([[b1 firstAuthor] lastName], @"Last", @"last name of First von Last");
	STAssertEqualObjects([[b1 firstAuthor] vonPart], @"von", @"von part of First von Last");
	STAssertEqualObjects([[b2 firstAuthor] firstName], @"First", @"first name of von Last, First");
	STAssertEqualObjects([[b2 firstAuthor] lastName], @"Last", @"last name of von Last, First");
	STAssertEqualObjects([[b2 firstAuthor] vonPart], @"von", @"von part of von Last, First");
	
	STAssertEqualObjects([b1 bibTeXAuthorStringNormalized:YES],[b2 bibTeXAuthorStringNormalized:YES],
						 @"check normalised representation of complex author names");		
}

- (void)testComplexAuthorNameNormalisationWithJr{
	// Check for parsing of two variants
	// "First von Last, Jr" "von Last, Jr, First"
	NSDictionary *pubFields1 = [NSDictionary dictionaryWithObjectsAndKeys:@"Hello", BDSKTitleString,
								@"First von Last, Jr.", BDSKAuthorString, nil];
	NSDictionary *pubFields2 = [NSDictionary dictionaryWithObjectsAndKeys:@"Hello", BDSKTitleString,
								@"von Last, Jr., First", BDSKAuthorString, nil];
	BibItem *b1 = [[[BibItem alloc] initWithType:BDSKArticleString fileType:BDSKBibtexString citeKey:nil pubFields:pubFields1 isNew:YES] autorelease];
	BibItem *b2 = [[[BibItem alloc] initWithType:BDSKArticleString fileType:BDSKBibtexString citeKey:nil pubFields:pubFields2 isNew:YES] autorelease];
	
	// GJ: my understanding was that "First von Last, Jr." was an acceptable BibTex form,
	// but a note before BibAuthor's setupNames method suggests otherwise
//	STAssertEqualObjects([[b1 firstAuthor] firstName], @"First", @"first name of First von Last, Jr.");
//	STAssertEqualObjects([[b1 firstAuthor] lastName], @"Last", @"last name of First von Last, Jr.");
//	STAssertEqualObjects([[b1 firstAuthor] vonPart], @"von", @"von part of First von Last, Jr.");
//	STAssertEqualObjects([[b1 firstAuthor] jrPart], @"Jr.", @"jr part of First von Last, Jr.");
	
	STAssertEqualObjects([[b2 firstAuthor] firstName], @"First", @"first name of von Last, Jr., First");
	STAssertEqualObjects([[b2 firstAuthor] lastName], @"Last", @"last name of von Last, Jr., First");
	STAssertEqualObjects([[b2 firstAuthor] vonPart], @"von", @"von part of von Last, Jr., First");
	STAssertEqualObjects([[b2 firstAuthor] jrPart], @"Jr.", @"jr part of von Last, Jr., First");

//	STAssertEqualObjects([b1 bibTeXAuthorStringNormalized:YES],[b2 bibTeXAuthorStringNormalized:YES],
//						 @"check normalised representation of complex author names");
}

- (void)testMakeMinimalBibtex{
	// Note, this test is deliberately rather fragile, so feel free to refine if it breaks
	// with a new behaviour that you consider reasonable
	BOOL isPartialData = NO;
	NSError *parseError = nil;
	
	NSArray *testArray = [BDSKBibTeXParser itemsFromString:oneItem document:nil isPartialData:&isPartialData error:&parseError];
	
	BibItem *item1 = [testArray objectAtIndex:0];

	// Turn off the normalised author setting if it is ON.  Otherwise we should have:
	// Author = {Lee, Peter and Leone, Mark}
	BOOL authorNormalization = [[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldSaveNormalizedAuthorNamesKey];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:BDSKShouldSaveNormalizedAuthorNamesKey];
	NSString * leeAsBibtex = [item1 bibTeXStringWithOptions:BDSKBibTeXOptionDropInternalMask];
	STAssertEqualObjects([leeAsBibtex stringByReplacingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\t\n"]
															withString:@""],
						 @"@inproceedings{Lee96RTOptML,Author = {Peter Lee and Mark Leone},Booktitle = {PLDI},Title = {Optimizing ML with Run-Time Code Generation},Year = {1996}}",nil);
	[[NSUserDefaults standardUserDefaults] setBool:authorNormalization forKey:BDSKShouldSaveNormalizedAuthorNamesKey];
	
}

- (void)testParseTwoRecords{
	// init two bibitems, then check that the difference in their fileorder is one
    BOOL isPartialData = NO;
	NSError *parseError = nil;

	NSArray *testArray = [BDSKBibTeXParser itemsFromString:twoItems document:nil isPartialData:&isPartialData error:&parseError];

    BibItem *item1 = [testArray objectAtIndex:0];
    BibItem *item2 = [testArray objectAtIndex:1];

	STAssertNotNil(testArray,@"Failed to parse two BibTex records");
    STAssertEquals([testArray count],(NSUInteger) 2, @"Parsed 2 Bibtex records as %ld BibTex records",[testArray count]);

	// File order seems to be nil when reading those 2 strings
//	STAssertEquals([item2 fileOrder] - [item1 fileOrder], 1,
//				   @"File orders of two records should differ by 1");
}

- (void)testMakeTypeBibTeX{
    BOOL isPartialData = NO;
	NSError *parseError = nil;
	
	NSArray *testArray = [BDSKBibTeXParser itemsFromString:oneItem document:nil isPartialData:&isPartialData error:&parseError];

	BibItem *item1 = [testArray objectAtIndex:0];

    NSString *firstType = [item1 pubType];
    NSString *beforeString = [item1 bibTeXString];
	 
    for (NSString *aType in [[BDSKTypeManager sharedManager] bibTypesForFileType:BDSKBibtexString])
        [item1 setPubType:aType];
    [item1 setPubType:firstType];
    STAssertEqualObjects(beforeString, [item1 bibTeXString],nil);
}

@end


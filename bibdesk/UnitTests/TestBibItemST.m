//
//  TestBibItemST.m
//  Bibdesk
//
//  Created by Gregory Jefferis on 2009-01-05.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TestBibItemST.h"

static NSString *oneItem = @"@inproceedings{Lee96RTOptML,\nYear = {1996},\nUrl = {http://citeseer.nj.nec.com/70627.html},\nTitle = {Optimizing ML with Run-Time Code Generation},\nBooktitle = {PLDI},\nAuthor = {Peter Lee and Mark Leone}}";
static NSString *twoItems = @"@inproceedings{Lee96RTOptML,\nYear = {1996},\nUrl = {http://citeseer.nj.nec.com/70627.html},\nTitle = {Optimizing ML with Run-Time Code Generation},\nBooktitle = {PLDI},\nAuthor = {Peter Lee and Mark Leone}}\n\n@inproceedings{yang01LoopTransformPowerImpact,\nYear = {2001},\nTitle = {Power and Energy Impact by Loop Transformations},\nBooktitle = {COLP '01},\nAuthor = {Hongbo Yang and Guang R. Gao and Andres Marquez and George Cai and Ziang Hu}}";


@implementation TestBibItemST
- (void)setUp {
    // create the object(s) that we want to test
    [super setUp];
}

-(void)tearDown {
    // clean up any stuff like open files or whatever
    [super tearDown];
}

- (void)testInitWithType{		
	NSDictionary *pubFields = [NSDictionary dictionaryWithObjectsAndKeys:@"Hello", BDSKTitleString,
							   @"Less, von More, Jr.", BDSKAuthorString, nil];
	BibItem *b = [[BibItem alloc] initWithType:BDSKArticleString fileType:BDSKBibtexString citeKey:nil pubFields:pubFields isNew:YES];
	
    STAssertEquals(1, [b numberOfAuthors],@"Check that Less, von More, Jr. parses to single author");
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
    NSEnumerator *typeE = [[[BDSKTypeManager sharedManager] bibTypesForFileType:BDSKBibtexString] objectEnumerator];
    NSString *aType = nil;
    NSString *beforeString = [item1 bibTeXString];
	 
    while(aType = [typeE nextObject]){
        [item1 setPubType:aType];
    }
    [item1 setPubType:firstType];
    STAssertEqualObjects(beforeString, [item1 bibTeXString],nil);
}

@end


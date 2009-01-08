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
static OFCharacterSet *endOfLineSet;


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
	endOfLineSet = [[OFCharacterSet alloc] initWithString:@"\r\n"];
		
	NSDictionary *pubFields = [NSDictionary dictionaryWithObjectsAndKeys:@"Hello", BDSKTitleString,
							   @"Less, von More, Jr.", BDSKAuthorString, nil];
	BibItem *b = [[BibItem alloc] initWithType:BDSKArticleString fileType:BDSKBibtexString citeKey:nil pubFields:pubFields isNew:YES];
	
    STAssertEquals(1, [b numberOfAuthors],@"Check that Less, von More, Jr. parses to single author");
}
@end


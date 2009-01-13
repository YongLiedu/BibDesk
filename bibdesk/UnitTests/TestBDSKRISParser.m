//
//  TestBDSKRISParser.m
//  Bibdesk
//
//  Created by Gregory Jefferis on 2009-01-12.
//  Copyright 2009 Gregory Jefferis. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "BibItem.h"
#import "BDSKStringConstants.h"
#import "BDSKRISParser.h"


static NSString *goodRIS = @"TY  - JOUR\nT1  - Julian Steward, American Anthropology, and Colonialism\nA1  - Marc Pinkoski\nJF  - Histories of Anthropology Annual\nVL  - 4\nSP  - 172\nEP  - 204\nY1  - 2008\nPB  - University of Nebraska Press\nSN  - 1940-5138\nUR  - http://muse.jhu.edu/journals/histories_of_anthropology_annual/v004/4.pinkoski.html\nN1  - Volume 4, 2008\nER  - \n";
static NSString *goodRISNoFinalReturnOrSpace = @"TY  - JOUR\nT1  - Julian Steward, American Anthropology, and Colonialism\nA1  - Marc Pinkoski\nJF  - Histories of Anthropology Annual\nVL  - 4\nSP  - 172\nEP  - 204\nY1  - 2008\nPB  - University of Nebraska Press\nSN  - 1940-5138\nUR  - http://muse.jhu.edu/journals/histories_of_anthropology_annual/v004/4.pinkoski.html\nN1  - Volume 4, 2008\nER  -";
static NSString *badRISSingleSpace = @"TY - JOUR\nT1 - Julian Steward, American Anthropology, and Colonialism\nA1 - Marc Pinkoski\nJF - Histories of Anthropology Annual\nVL - 4\nSP - 172\nEP - 204\nY1 - 2008\nPB - University of Nebraska Press\nSN - 1940-5138\nUR - http://muse.jhu.edu/journals/histories_of_anthropology_annual/v004/4.pinkoski.html\nN1 - Volume 4, 2008\nER -\n";

@interface TestBDSKRISParser : SenTestCase {
}
@end

@implementation TestBDSKRISParser
- (void)testCanParseString{
	
    STAssertEquals([BDSKStringParser canParseString:goodRIS ofType:BDSKRISStringType ],
				   YES, @"Check that we can parse a basic RIS record");
    STAssertEquals([BDSKStringParser canParseString:goodRIS ofType:BDSKRISStringType ],
				   YES, @"Check that we can parse a basic RIS record even with missing final return");
    STAssertEquals([BDSKStringParser canParseString:badRISSingleSpace ofType:BDSKRISStringType ],
				   NO, @"Check that we reject a RIS record with a missing space in front of dash");
}

- (void)testContentStringType{
	STAssertEquals(BDSKRISStringType, [goodRIS contentStringType],@"Check that this string is recognised as RIS content");
	STAssertEquals(BDSKUnknownStringType, [badRISSingleSpace contentStringType],@"Check that this string is not recognised as RIS content");
}

- (void)testRISToMinimalBibTex{
	BibItem *b = [[BDSKStringParser itemsFromString:goodRIS error:NULL] lastObject];
	BibItem *b2 = [[BDSKStringParser itemsFromString:goodRISNoFinalReturnOrSpace error:NULL] lastObject];
	
	// These are fairly broad spectrum tests - would probably be better to break it down some more.
	
	STAssertEqualObjects([b bibTeXStringWithOptions:BDSKBibTeXOptionDropInternalMask],
						 @"@article{cite-key,\n\tAuthor = {Marc Pinkoski},\n\tJournal = {Histories of Anthropology Annual},\n\tPages = {172--204},\n\tTitle = {Julian Steward, American Anthropology, and Colonialism},\n\tVolume = {4},\n\tYear = {2008}}",
						 @"BibTex format error for RIS record, Pinkoski 2008");
	STAssertEqualObjects([b2 bibTeXStringWithOptions:BDSKBibTeXOptionDropInternalMask],
						 @"@article{cite-key,\n\tAuthor = {Marc Pinkoski},\n\tJournal = {Histories of Anthropology Annual},\n\tPages = {172--204},\n\tTitle = {Julian Steward, American Anthropology, and Colonialism},\n\tVolume = {4},\n\tYear = {2008}}",
						 @"BibTex format error for RIS record, Pinkoski 2008");
}

@end

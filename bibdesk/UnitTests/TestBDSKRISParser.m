//
//  TestBDSKRISParser.m
//  Bibdesk
//
//  Created by Gregory Jefferis on 2009-01-12.
/* This software is Copyright (c) 2009-2010
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

#import "TestBDSKRISParser.h"
#import "BibItem.h"
#import "BDSKStringConstants.h"
#import "BDSKRISParser.h"


#define goodRIS @"TY  - JOUR\nT1  - Julian Steward, American Anthropology, and Colonialism\nA1  - Marc Pinkoski\nJF  - Histories of Anthropology Annual\nVL  - 4\nSP  - 172\nEP  - 204\nY1  - 2008\nPB  - University of Nebraska Press\nSN  - 1940-5138\nUR  - http://muse.jhu.edu/journals/histories_of_anthropology_annual/v004/4.pinkoski.html\nN1  - Volume 4, 2008\nER  - \n"
#define goodRISNoFinalReturnOrSpace @"TY  - JOUR\nT1  - Julian Steward, American Anthropology, and Colonialism\nA1  - Marc Pinkoski\nJF  - Histories of Anthropology Annual\nVL  - 4\nSP  - 172\nEP  - 204\nY1  - 2008\nPB  - University of Nebraska Press\nSN  - 1940-5138\nUR  - http://muse.jhu.edu/journals/histories_of_anthropology_annual/v004/4.pinkoski.html\nN1  - Volume 4, 2008\nER  -"
#define badRISSingleSpace @"TY - JOUR\nT1 - Julian Steward, American Anthropology, and Colonialism\nA1 - Marc Pinkoski\nJF - Histories of Anthropology Annual\nVL - 4\nSP - 172\nEP - 204\nY1 - 2008\nPB - University of Nebraska Press\nSN - 1940-5138\nUR - http://muse.jhu.edu/journals/histories_of_anthropology_annual/v004/4.pinkoski.html\nN1 - Volume 4, 2008\nER -\n"


@implementation TestBDSKRISParser
- (void)testCanParseString{
	
    STAssertTrue([BDSKStringParser canParseString:goodRIS ofType:BDSKRISStringType ],
				   @"Check that we can parse a basic RIS record");
    STAssertTrue([BDSKStringParser canParseString:goodRISNoFinalReturnOrSpace ofType:BDSKRISStringType ],
				   @"Check that we can parse a basic RIS record even with missing final return");
    STAssertTrue([BDSKStringParser canParseString:goodRIS ofType:BDSKUnknownStringType ],
				   @"Check that we can parse a basic RIS record without type information");
    STAssertTrue([BDSKStringParser canParseString:badRISSingleSpace ofType:BDSKRISStringType ]==NO,
				   @"Check that we reject a RIS record with a missing space in front of dash");
}

- (void)testContentStringType{
	STAssertTrue(BDSKRISStringType==[goodRIS contentStringType],@"Check that this string is recognised as RIS content");
	STAssertTrue(BDSKUnknownStringType==[badRISSingleSpace contentStringType],@"Check that this string is not recognised as RIS content");
}

- (void)testRISToMinimalBibTex{
	BibItem *b = [[BDSKStringParser itemsFromString:goodRIS ofType:BDSKUnknownStringType error:NULL] lastObject];
	BibItem *b2 = [[BDSKStringParser itemsFromString:goodRISNoFinalReturnOrSpace ofType:BDSKUnknownStringType error:NULL] lastObject];
	
	// These are fairly broad spectrum tests - would probably be better to break it down some more.
	
	STAssertEqualObjects([b bibTeXAuthorStringNormalized:YES],@"Pinkoski, Marc",nil);
	STAssertEqualObjects([b valueOfField:BDSKTitleString],@"Julian Steward, American Anthropology, and Colonialism",nil);
	STAssertEqualObjects([b valueOfField:BDSKJournalString],@"Histories of Anthropology Annual",nil);
	STAssertEqualObjects([b valueOfField:BDSKPagesString],@"172--204",nil);
	STAssertEqualObjects([b valueOfField:BDSKYearString],@"2008",nil);

	STAssertEqualObjects([b2 bibTeXStringWithOptions:BDSKBibTeXOptionDropInternalMask],[b bibTeXStringWithOptions:BDSKBibTeXOptionDropInternalMask],@"final return should not affect RIS parsing");
}

@end

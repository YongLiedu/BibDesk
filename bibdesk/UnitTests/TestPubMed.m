//
//  TestPubMed.m
//  Bibdesk
//
//  Created by Gregory Jefferis on 2009-01-05.
/* This software is Copyright (c) 2009-2012
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

#import "TestPubMed.h"
#import "BibItem.h"
#import "BDSKBibTeXParser.h"
#import "BDSKStringConstants.h"
#import "BDSKPubMedParser.h"
#import "BibItem_PubMedLookup.h"

#define watsonCrick @"PMID- 13054692\nOWN - NLM\nSTAT- MEDLINE\nDA  - 19531201\nDCOM- 20030501\nLR  - 20061115\nIS  - 0028-0836 (Print)\nVI  - 171\nIP  - 4356\nDP  - 1953 Apr 25\nTI  - Molecular structure of nucleic acids; a structure for deoxyribose nucleic acid.\nPG  - 737-8\nFAU - WATSON, J D\nAU  - WATSON JD\nFAU - CRICK, F H\nAU  - CRICK FH\nLA  - eng\nPT  - Journal Article\nPL  - Not Available\nTA  - Nature\nJT  - Nature\nJID - 0410462\nRN  - 0 (Nucleic Acids)\nSB  - OM\nMH  - *Nucleic Acids\nOID - CLML: 5324:25254:447\nOTO - NLM\nOT  - *NUCLEIC ACIDS\nEDAT- 1953/04/25\nMHDA- 1953/04/25 00:01\nCRDT- 1953/04/25 00:00\nPST - ppublish\nSO  - Nature. 1953 Apr 25;171(4356):737-8.\n"
#define jefferisetal @"PMID- 17382886\nOWN - NLM\nSTAT- MEDLINE\nDA  - 20070326\nDCOM- 20070508\nLR  - 20081120\nIS  - 0092-8674 (Print)\nVI  - 128\nIP  - 6\nDP  - 2007 Mar 23\nTI  - Comprehensive maps of Drosophila higher olfactory centers: spatially segregated\n      fruit and pheromone representation.\nPG  - 1187-203\nAB  - In Drosophila, approximately 50 classes of olfactory receptor neurons (ORNs) send\n      axons to 50 corresponding glomeruli in the antennal lobe. Uniglomerular\n      projection neurons (PNs) relay olfactory information to the mushroom body (MB)\n      and lateral horn (LH). Here, we combine single-cell labeling and image\n      registration to create high-resolution, quantitative maps of the MB and LH for 35\n      input PN channels and several groups of LH neurons. We find (1) PN inputs to the \n      MB are stereotyped as previously shown for the LH; (2) PN partners of ORNs from\n      different sensillar groups are clustered in the LH; (3) fruit odors are\n      represented mostly in the posterior-dorsal LH, whereas candidate\n      pheromone-responsive PNs project to the anterior-ventral LH; (4) dendrites of\n      single LH neurons each overlap with specific subsets of PN axons. Our results\n      suggest that the LH is organized according to biological values of olfactory\n      input.\nAD  - Department of Biological Sciences, Stanford University, Stanford, CA 94305, USA. \n      gsxej2@cam.ac.uk\nFAU - Jefferis, Gregory S X E\nAU  - Jefferis GS\nFAU - Potter, Christopher J\nAU  - Potter CJ\nFAU - Chan, Alexander M\nAU  - Chan AM\nFAU - Marin, Elizabeth C\nAU  - Marin EC\nFAU - Rohlfing, Torsten\nAU  - Rohlfing T\nFAU - Maurer, Calvin R Jr\nAU  - Maurer CR Jr\nFAU - Luo, Liqun\nAU  - Luo L\nLA  - eng\nGR  - AA05965/AA/NIAAA NIH HHS/United States\nGR  - AA13521/AA/NIAAA NIH HHS/United States\nGR  - R01-DC005982/DC/NIDCD NIH HHS/United States\nPT  - Journal Article\nPT  - Research Support, N.I.H., Extramural\nPT  - Research Support, Non-U.S. Gov't\nPL  - United States\nTA  - Cell\nJT  - Cell\nJID - 0413066\nRN  - 0 (Pheromones)\nSB  - IM\nMH  - Animals\nMH  - Brain/anatomy & histology/physiology\nMH  - Brain Mapping\nMH  - Drosophila/*anatomy & histology/*physiology\nMH  - Female\nMH  - Fruit\nMH  - Male\nMH  - Mushroom Bodies/*physiology\nMH  - Odors\nMH  - Olfactory Pathways/physiology\nMH  - Olfactory Receptor Neurons/*physiology\nMH  - Pheromones\nMH  - Presynaptic Terminals/physiology\nMH  - Sex Characteristics\nMH  - Smell/physiology\nMH  - Synapses/physiology\nPMC - PMC1885945\nOID - NLM: PMC1885945\nEDAT- 2007/03/27 09:00\nMHDA- 2007/05/09 09:00\nCRDT- 2007/03/27 09:00\nPHST- 2006/08/21 [received]\nPHST- 2006/11/10 [revised]\nPHST- 2007/01/17 [accepted]\nAID - S0092-8674(07)00204-8 [pii]\nAID - 10.1016/j.cell.2007.01.040 [doi]\nPST - ppublish\nSO  - Cell. 2007 Mar 23;128(6):1187-203.\n"
#define semCell @"PMID- 16439169\nOWN - NLM\nSTAT- MEDLINE\nDA  - 20060426\nDCOM- 20060810\nLR  - 20061115\nIS  - 1084-9521 (Print)\nVI  - 17\nIP  - 1\nDP  - 2006 Feb\nTI  - Wiring specificity in the olfactory system.\nPG  - 50-65\nAB  - The fruitfly brain learns about the olfactory world by reading the activity of\n      about 50 distinct channels of incoming information. The receptor neurons that\n      compose each channel have their own distinctive odour response profile governed\n      by a specific receptor molecule. These receptor neurons form highly specific\n      connections in the first olfactory relay of the fly brain, each synapsing with\n      specific second order partner neurons. We use this system to discuss the logic of\n      wiring specificity in the brain and to review the cellular and molecular\n      mechanisms that allow such precise wiring to develop.\nAD  - Department of Zoology, University of Cambridge, Downing Street, Cambridge CB2\n      3EJ, United Kingdom. gsxej2@cam.ac.uk\nFAU - Jefferis, Gregory S X E\nAU  - Jefferis GS\nFAU - Hummel, Thomas\nAU  - Hummel T\nLA  - eng\nPT  - Journal Article\nPT  - Research Support, Non-U.S. Gov't\nPT  - Review\nDEP - 20060124\nPL  - England\nTA  - Semin Cell Dev Biol\nJT  - Seminars in cell & developmental biology\nJID - 9607332\nRN  - 0 (Receptors, Odorant)\nSB  - IM\nMH  - Animals\nMH  - *Drosophila melanogaster/anatomy & histology/physiology\nMH  - Nerve Net\nMH  - *Neurons/cytology/physiology\nMH  - *Olfactory Pathways/anatomy & histology/physiology\nMH  - Olfactory Receptor Neurons/cytology/physiology\nMH  - Receptors, Odorant/metabolism\nMH  - Synapses/metabolism/ultrastructure\nRF  - 80\nEDAT- 2006/01/28 09:00\nMHDA- 2006/08/11 09:00\nCRDT- 2006/01/28 09:00\nPHST- 2006/01/24 [aheadofprint]\nAID - S1084-9521(05)00125-4 [pii]\nAID - 10.1016/j.semcdb.2005.12.002 [doi]\nPST - ppublish\nSO  - Semin Cell Dev Biol. 2006 Feb;17(1):50-65. Epub 2006 Jan 24.\n"

// For Elsevier PIIs
#define textFromBenton2009 @"*Correspondence: leslie@mail.rockefeller.edu\nDOI 10.1016/j.cell.2008.12.001\n"
#define originalPII @"S0092-8674(02)00700-6"
#define normalisedPII @"S0092867402007006"
#define PIIWithISSNWithX @"S1936-959X(02)00700-6"
#define normalisedPIIWithISSNWithX @"S1936959X02007006"
#define brokenPII @"S0092-8674(0200700-6\n"
#define PIIMissingInitialSandWithTerminalM @"0092-8674(93)90422-M"

@implementation TestPubMed

- (void)setUp {
    // create the object(s) that we want to test
    [super setUp];
	//bibitem = [[BDSKStringParser itemsFromString:watsonCrick ofType:BDSKUnknownStringType error:NULL] lastObject];
	//STAssertNotNil(bibitem,@"Check that we can parse the Watson Crick PubMed record");
	//    testable = [[Testable alloc] init];
}

-(void)tearDown {
    // clean up any stuff like open files or whatever
	//[bibitem release];
    [super tearDown];
}

- (void)testCanParseString{
	
    STAssertTrue([BDSKStringParser canParseString:watsonCrick ofType:BDSKPubMedStringType],
                    @"Check that we can parse a basic PubMed record");
	STAssertTrue([BDSKStringParser canParseString:watsonCrick ofType:BDSKUnknownStringType],
                    @"Check that we can parse a basic PubMed record without type information");
}

- (void)testContentStringType{
	STAssertTrue(BDSKPubMedStringType==[watsonCrick contentStringType],@"Check that this string is recognised as PubMed content");
}

- (void)testOldMedlineArticleParsing{
	BibItem *b = [[BDSKStringParser itemsFromString:watsonCrick ofType:BDSKUnknownStringType error:NULL] lastObject];

	// Test BibDesk internal fields
	// ============================
	// Article Type
	STAssertEqualObjects(@"article", [b pubType],@"");
	// Authors
	STAssertTrue(2==[[b pubAuthors] count],@"There are 2 authors");
	STAssertEqualObjects([[b firstAuthor] valueForKey:@"name"],
						 @"J D WATSON", @"Watson's full name");
	STAssertEqualObjects([[b firstAuthor] valueForKey:@"lastName"],
						 @"WATSON", @"Watson's last name");
	STAssertEqualObjects([[b lastAuthor] valueForKey:@"name"],
						 @"F H CRICK", @"Crick's full name");
	STAssertEqualObjects([[b lastAuthor] valueForKey:@"lastName"],
						 @"CRICK", @"Crick's last name");
}

- (void)testRecentMedlineArticleParsing{
	BibItem *b = [[BDSKStringParser itemsFromString:jefferisetal ofType:BDSKUnknownStringType error:NULL] lastObject];
	
	// Test BibItem internal fields
	// ============================
	// Article Type
	STAssertEqualObjects([b pubType], @"article", @"");
	// Authors
	STAssertTrue(7==[[b pubAuthors] count],@"There are 7 authors");
	STAssertEqualObjects([[b firstAuthor] valueForKey:@"name"],
						 @"Gregory S X E Jefferis", @"Greg Jefferis's full name");
	STAssertEqualObjects([[b firstAuthor] valueForKey:@"lastName"],
						 @"Jefferis", @"Greg Jefferis's last name");
	STAssertEqualObjects([[b lastAuthor] valueForKey:@"name"],
						 @"Liqun Luo", @"Liqun Luo's full name");
	STAssertEqualObjects([[b lastAuthor] valueForKey:@"lastName"],
						 @"Luo", @"Liqun Luo's last name");
	// Date fields

	// GJ TODO - wouldn't it be nice to have the date parse the full date info 
	// if available in the Month field.  Right now everything is converted to the
	// 15th of the month even if more info is available	
	//STAssertEqualObjects([b displayValueOfField:BDSKPubDateString],
	//					 @"Mar 2007", @"for BibItem pubDate Publication Date");

	// Test pubFields ie direct results of BDSKPubMedParser
	// ==============
	// Date fields
//	STAssertEqualObjects([b valueOfField:@"Dp"],
//						 @"2007 Mar 23", @" for PubMed field DP (Date of Publication)");
	STAssertEqualObjects([b valueOfField:@"Dp"],
						 @"", @" have decided to remove DP (Date of Publication) field");
	// Check that DP is copied into the BibTex date field as Christiaan Hofman would like
	// I still worry that this date field and the BibItem pubDate variable may get confused.
	STAssertEqualObjects([b valueOfField:BDSKDateString],
						 @"2007 Mar 23", @" ie PubMed DP field => BibTex Date field");
	STAssertEqualObjects([b valueOfField:@"Year"],
						 @"2007", @"for Year field");
	STAssertEqualObjects([b valueOfField:@"Month"],
						 @"Mar", @"for Month field");
	
}
- (void)testAbbreviatedJournalTitle{
	BibItem *b = [[BDSKStringParser itemsFromString:semCell ofType:BDSKUnknownStringType error:NULL] lastObject];
	
	// NB this is the value of the TA (abbreviated) field which is preferred over the 
	// JT field because that field often contains annoying additions eg:
	//	TA  - Curr Biol
	//	JT  - Current biology : CB
	// There is also a historical precedent in that it is what was used up to 
	// BibDesk 1.3.19
	STAssertEqualObjects([b valueOfField:@"Journal"],
						 @"Semin Cell Dev Biol", @"for Journal field");
	
}

- (void)testParseMedlineToMinimalBibTex{
	BibItem *b = [[BDSKStringParser itemsFromString:jefferisetal ofType:BDSKUnknownStringType error:NULL] lastObject];

	// These are fairly broad spectrum tests - would probably be better to break it down some more.
	
	STAssertEqualObjects([b bibTeXStringWithOptions:BDSKBibTeXOptionDropInternalMask],
						 @"@article{cite-key,\n\tAuthor = {Jefferis, Gregory S X E and Potter, Christopher J and Chan, Alexander M and Marin, Elizabeth C and Rohlfing, Torsten and Maurer, Calvin R Jr and Luo, Liqun},\n\tJournal = {Cell},\n\tMonth = {Mar},\n\tNumber = {6},\n\tPages = {1187--1203},\n\tTitle = {Comprehensive maps of Drosophila higher olfactory centers: spatially segregated fruit and pheromone representation.},\n\tVolume = {128},\n\tYear = {2007}}",
						 @"BibTex format error for PubMed record, Jefferis et al Cell 2007");
	// This has a funky Journal Title
	b = [[BDSKStringParser itemsFromString:semCell ofType:BDSKUnknownStringType error:NULL] lastObject];

	STAssertEqualObjects([b bibTeXStringWithOptions:BDSKBibTeXOptionDropInternalMask],
						 @"@article{cite-key,\n\tAuthor = {Jefferis, Gregory S X E and Hummel, Thomas},\n\tJournal = {Semin Cell Dev Biol},\n\tMonth = {Feb},\n\tNumber = {1},\n\tPages = {50--65},\n\tTitle = {Wiring specificity in the olfactory system.},\n\tVolume = {17},\n\tYear = {2006}}",
						 @"BibTex format error for PubMed record, Jefferis and Hummel Semin Cell Dev Biol 2006");
	
}
- (void)testMedlineDateOfPublicationVariants{
	BibItem *b;
	// Year Only
	b = [[BDSKStringParser itemsFromString:@"PMID- 13054692\nDP  - 1953\nTI  - Test.\nPG  - 737-8\nFAU - WATSON, J D\nPT  - Journal Article\nJT  - Nature\n"
                                    ofType:BDSKUnknownStringType error:NULL] lastObject];
	STAssertEqualObjects([b valueOfField:@"Year"],@"1953", @"for Year field");
	STAssertEqualObjects([b valueOfField:@"Month"],@"", @"for Month field");

	// Year and Month (no Day)
	b = [[BDSKStringParser itemsFromString:@"PMID- 13054692\nDP  - 1953 Mar\nTI  - Test.\nPG  - 737-8\nFAU - WATSON, J D\nPT  - Journal Article\nJT  - Nature\n"
                                    ofType:BDSKUnknownStringType error:NULL] lastObject];
	STAssertEqualObjects([b valueOfField:@"Year"],@"1953", @"for Year field");
	STAssertEqualObjects([b valueOfField:@"Month"],@"Mar", @"for Month field");

	// Year and Season	
	b = [[BDSKStringParser itemsFromString:@"PMID- 13054692\nDP  - 1953 Spring\nTI  - Test.\nPG  - 737-8\nFAU - WATSON, J D\nPT  - Journal Article\nJT  - Nature\n"
									ofType:BDSKUnknownStringType error:NULL] lastObject];
	STAssertEqualObjects([b valueOfField:@"Year"],@"1953", @"for Year field");
	STAssertEqualObjects([b valueOfField:@"Month"],@"Spring", @"for Month field");

	// Year and Month Range
	b = [[BDSKStringParser itemsFromString:@"PMID- 13054692\nDP  - 1953 Jan-Feb\nTI  - Test.\nPG  - 737-8\nFAU - WATSON, J D\nPT  - Journal Article\nJT  - Nature\n"
									ofType:BDSKUnknownStringType error:NULL] lastObject];
	STAssertEqualObjects([b valueOfField:@"Year"],@"1953", @"for Year field");
	STAssertEqualObjects([b valueOfField:@"Month"],@"Jan-Feb", @"for Month field");
	
}

- (void)testDOIParsing{
	static NSString *pdfTitleFromAtaman2009=@"doi:10.1016/j.neuron.2008.01.026";
	static NSString *textWithoutADOI=@"*Correspondence: leslie@mail.rockefeller.edu\n";
	static NSString *doiInUrl=@"http://www.jcb.org/cgi/doi/10.1083/jcb.200611141\n";
//	NSString *doiWithInterveningHighUnicode = [NSString stringWithUTF8String:"To whom correspondence should be addressed. E-mail: borst@neuro.mpg.de.\n\u00a9 2005 by The National Academy of Sciences of the USA\n6172\u2013 6176 \udbff\udc00 PNAS \udbff\udc00 April 26, 2005 \udbff\udc00 vol. 102 \udbff\udc00 no. 17 www.pnas.org\udbff\udc01cgi\udbff\udc01doi\udbff\udc0110.1073\udbff\udc01pnas.0500491102"];
	NSString *doiWithInterveningHighUnicode = @"To whom correspondence should be addressed. E-mail: borst@neuro.mpg.de.\n\\u00a9 2005 by The National Academy of Sciences of the USA\n6172\\u2013 6176 \\udbff\\udc00 PNAS \\udbff\\udc00 April 26, 2005 \\udbff\\udc00 vol. 102 \\udbff\\udc00 no. 17 www.pnas.org\\udbff\\udc01cgi\\udbff\\udc01doi\\udbff\\udc0110.1073\\udbff\\udc01pnas.0500491102";

	//DOI 10.1016/j.cell.2008.12.001
	STAssertEqualObjects([textFromBenton2009 stringByExtractingDOIFromString],@"10.1016/j.cell.2008.12.001",nil);
	STAssertEqualObjects([pdfTitleFromAtaman2009 stringByExtractingDOIFromString],@"10.1016/j.neuron.2008.01.026",nil);
	STAssertEqualObjects([@"doi:10.1016/S0166-2236(03)00166-8" stringByExtractingDOIFromString],@"10.1016/S0166-2236(03)00166-8",nil);
//	STAssertEqualObjects([doiWithInterveningHighUnicode stringByExtractingDOIFromString],@"10.1073/pnas.0500491102",nil);
	STAssertEqualObjects([doiInUrl stringByExtractingDOIFromString],@"10.1083/jcb.200611141",nil);

	// More dois extracted from test pdfs from Miguel Ortiz Lombardia
	STAssertEqualObjects([@"doi:10.1371/ journal.pbio.0060283\n" stringByExtractingDOIFromString],@"10.1371/journal.pbio.0060283",nil);
	// this doi is not present in pubmed, although the 'ar010054t' part is present as ar010054t [pii].
//	STAssertEqualObjects([@"10.1021/ar010054t\n" stringByExtractingDOIFromString],@"10.1021/ar010054t",nil);
	// Let's just say we don't parse this one for now
	STAssertEqualObjects([@"10.1021/ar010054t\n" stringByExtractingDOIFromString],nil,nil);
	STAssertEqualObjects([@"doi:10.1371/\njournal.pbio.0060283" stringByExtractingDOIFromString],@"10.1371/journal.pbio.0060283",nil);
	// Check that a PNAS doi can be stitched backtogether
	STAssertEqualObjects([@"doi 10.1073 pnas.0810631106\n" stringByExtractingDOIFromString],@"10.1073/pnas.0810631106",nil);

	
	STAssertNil([textWithoutADOI stringByExtractingDOIFromString],nil);
	STAssertNil([@"" stringByExtractingDOIFromString],nil);
}

- (void)testStringByExtractingNormalisedPIIFromString{
	STAssertEqualObjects([originalPII stringByExtractingNormalisedPIIFromString],normalisedPII,nil);
	STAssertEqualObjects([normalisedPII stringByExtractingNormalisedPIIFromString],normalisedPII,nil);	
	STAssertEqualObjects([PIIWithISSNWithX stringByExtractingNormalisedPIIFromString],@"S1936959X02007006",nil);
	STAssertEqualObjects([normalisedPIIWithISSNWithX stringByExtractingNormalisedPIIFromString],@"S1936959X02007006",nil);
	

	STAssertNil([textFromBenton2009 stringByExtractingNormalisedPIIFromString],nil);
	STAssertNil([brokenPII stringByExtractingNormalisedPIIFromString],nil);
	STAssertNil([@"" stringByExtractingNormalisedPIIFromString],nil);	
}

- (void)testStringByExtractingPIIFromString{
	NSString *textWithPII=[NSString stringWithFormat:@"%@ PII: %@ some random gibberish &\t\n",
						   [NSString stringWithString:textFromBenton2009],
						   [NSString stringWithString:originalPII]];

	STAssertEqualObjects([originalPII stringByExtractingPIIFromString],originalPII,nil);
	STAssertEqualObjects([textWithPII stringByExtractingPIIFromString],originalPII,nil);
	STAssertEqualObjects([PIIWithISSNWithX stringByExtractingPIIFromString],PIIWithISSNWithX,nil);
	STAssertEqualObjects([PIIMissingInitialSandWithTerminalM stringByExtractingPIIFromString],PIIMissingInitialSandWithTerminalM,nil);
	// note that this WILL match and return a normalised PII (ie without any non-alphanumerics)
	STAssertEqualObjects([normalisedPII stringByExtractingPIIFromString],normalisedPII,nil);
	
	STAssertNil([textFromBenton2009 stringByExtractingNormalisedPIIFromString],nil);
	STAssertNil([brokenPII stringByExtractingNormalisedPIIFromString],nil);
	STAssertNil([@"" stringByExtractingNormalisedPIIFromString],nil);	
}

- (void)testStringByMakingPubmedSearchFromAnyBibliographicIDsInString{
	// Check DOI identifiers
	STAssertEqualObjects([textFromBenton2009 stringByMakingPubmedSearchFromAnyBibliographicIDsInString],
						 @"10.1016/j.cell.2008.12.001 [AID]",nil);
	// Check Elsevier PII identifiers
	STAssertEqualObjects([originalPII stringByMakingPubmedSearchFromAnyBibliographicIDsInString],
						  @"\"S0092-8674(02)00700-6\" [AID] OR S0092867402007006 [AID]",nil);
	
	// Check Nature Publishing group identifiers, note pubmed search is case insensitive
	STAssertEqualObjects([@"NPGRJ_NMETH_989 73..79" stringByMakingPubmedSearchFromAnyBibliographicIDsInString],
						 @"nmeth_989 [AID] OR nmeth989 [AID]",nil);
	STAssertNil([@"rhubarb_NMETH_989 73..79" stringByMakingPubmedSearchFromAnyBibliographicIDsInString]
				,nil);
}

@end

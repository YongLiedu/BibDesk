//
//  TestPubMed.m
//  Bibdesk
//
//  Created by Gregory Jefferis on 2009-01-05.
//  Copyright 2009 Gregory Jefferis. All rights reserved.
//

#import "TestPubMed.h"

static NSString *watsonCrick = @"PMID- 13054692\nOWN - NLM\nSTAT- MEDLINE\nDA  - 19531201\nDCOM- 20030501\nLR  - 20061115\nIS  - 0028-0836 (Print)\nVI  - 171\nIP  - 4356\nDP  - 1953 Apr 25\nTI  - Molecular structure of nucleic acids; a structure for deoxyribose nucleic acid.\nPG  - 737-8\nFAU - WATSON, J D\nAU  - WATSON JD\nFAU - CRICK, F H\nAU  - CRICK FH\nLA  - eng\nPT  - Journal Article\nPL  - Not Available\nTA  - Nature\nJT  - Nature\nJID - 0410462\nRN  - 0 (Nucleic Acids)\nSB  - OM\nMH  - *Nucleic Acids\nOID - CLML: 5324:25254:447\nOTO - NLM\nOT  - *NUCLEIC ACIDS\nEDAT- 1953/04/25\nMHDA- 1953/04/25 00:01\nCRDT- 1953/04/25 00:00\nPST - ppublish\nSO  - Nature. 1953 Apr 25;171(4356):737-8.\n";

@implementation TestPubMed

- (void)setUp {
    // create the object(s) that we want to test
    [super setUp];
	bibitem = [[BDSKStringParser itemsFromString:watsonCrick error:NULL] lastObject];
	STAssertNotNil(bibitem,@"Check that we can parse the Watson Crick PubMed record");
	//    testable = [[Testable alloc] init];
}

-(void)tearDown {
    // clean up any stuff like open files or whatever
	//[bibitem release];
    [super tearDown];
}

- (void)testCanParseString{
	
    STAssertEquals(YES, [BDSKStringParser canParseString:watsonCrick ofType:BDSKPubMedStringType ],@"Check that we can parse a basic PubMed record");
    // GJ: Maybe it would be nice to make this possible some day ...
	STAssertEquals(NO, [BDSKStringParser canParseString:watsonCrick],@"Can't parse without type information");
}

- (void)testContentStringType{
	STAssertEquals(BDSKPubMedStringType, [watsonCrick contentStringType],@"Check that this string is recognised as PubMed content");
}

- (void)testBasicParsing{
	STAssertEqualObjects(@"article", [bibitem pubType],@"");
	NSLog(@"count=%d",[[bibitem pubAuthors] count]);
	STAssertEquals( (NSUInteger) 2, [[bibitem pubAuthors] count],@"There are 2 authors");
	STAssertEqualObjects(@"WATSON, J D", [[bibitem pubAuthors] lastObject],@"");
}

- (void)testRecentMedlineArticleParsing{
	NSString *jefferisetal=@"PMID- 17382886\nOWN - NLM\nSTAT- MEDLINE\nDA  - 20070326\nDCOM- 20070508\nLR  - 20081120\nIS  - 0092-8674 (Print)\nVI  - 128\nIP  - 6\nDP  - 2007 Mar 23\nTI  - Comprehensive maps of Drosophila higher olfactory centers: spatially segregated\n      fruit and pheromone representation.\nPG  - 1187-203\nAB  - In Drosophila, approximately 50 classes of olfactory receptor neurons (ORNs) send\n      axons to 50 corresponding glomeruli in the antennal lobe. Uniglomerular\n      projection neurons (PNs) relay olfactory information to the mushroom body (MB)\n      and lateral horn (LH). Here, we combine single-cell labeling and image\n      registration to create high-resolution, quantitative maps of the MB and LH for 35\n      input PN channels and several groups of LH neurons. We find (1) PN inputs to the \n      MB are stereotyped as previously shown for the LH; (2) PN partners of ORNs from\n      different sensillar groups are clustered in the LH; (3) fruit odors are\n      represented mostly in the posterior-dorsal LH, whereas candidate\n      pheromone-responsive PNs project to the anterior-ventral LH; (4) dendrites of\n      single LH neurons each overlap with specific subsets of PN axons. Our results\n      suggest that the LH is organized according to biological values of olfactory\n      input.\nAD  - Department of Biological Sciences, Stanford University, Stanford, CA 94305, USA. \n      gsxej2@cam.ac.uk\nFAU - Jefferis, Gregory S X E\nAU  - Jefferis GS\nFAU - Potter, Christopher J\nAU  - Potter CJ\nFAU - Chan, Alexander M\nAU  - Chan AM\nFAU - Marin, Elizabeth C\nAU  - Marin EC\nFAU - Rohlfing, Torsten\nAU  - Rohlfing T\nFAU - Maurer, Calvin R Jr\nAU  - Maurer CR Jr\nFAU - Luo, Liqun\nAU  - Luo L\nLA  - eng\nGR  - AA05965/AA/NIAAA NIH HHS/United States\nGR  - AA13521/AA/NIAAA NIH HHS/United States\nGR  - R01-DC005982/DC/NIDCD NIH HHS/United States\nPT  - Journal Article\nPT  - Research Support, N.I.H., Extramural\nPT  - Research Support, Non-U.S. Gov't\nPL  - United States\nTA  - Cell\nJT  - Cell\nJID - 0413066\nRN  - 0 (Pheromones)\nSB  - IM\nMH  - Animals\nMH  - Brain/anatomy & histology/physiology\nMH  - Brain Mapping\nMH  - Drosophila/*anatomy & histology/*physiology\nMH  - Female\nMH  - Fruit\nMH  - Male\nMH  - Mushroom Bodies/*physiology\nMH  - Odors\nMH  - Olfactory Pathways/physiology\nMH  - Olfactory Receptor Neurons/*physiology\nMH  - Pheromones\nMH  - Presynaptic Terminals/physiology\nMH  - Sex Characteristics\nMH  - Smell/physiology\nMH  - Synapses/physiology\nPMC - PMC1885945\nOID - NLM: PMC1885945\nEDAT- 2007/03/27 09:00\nMHDA- 2007/05/09 09:00\nCRDT- 2007/03/27 09:00\nPHST- 2006/08/21 [received]\nPHST- 2006/11/10 [revised]\nPHST- 2007/01/17 [accepted]\nAID - S0092-8674(07)00204-8 [pii]\nAID - 10.1016/j.cell.2007.01.040 [doi]\nPST - ppublish\nSO  - Cell. 2007 Mar 23;128(6):1187-203.";
	BibItem *b = [[BDSKStringParser itemsFromString:jefferisetal error:NULL] lastObject];

	STAssertEqualObjects(@"article", [bibitem pubType],@"");
	NSLog(@"count=%d",[[bibitem pubAuthors] count]);
	STAssertEquals( (NSUInteger) 7, [[bibitem pubAuthors] count],@"There are 7 authors");
	STAssertEqualObjects(@"Luo, Liqun", [[bibitem pubAuthors] lastObject],@"");
}

@end

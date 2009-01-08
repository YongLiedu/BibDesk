//
//  TestPubMed.h
//  Bibdesk
//
//  Created by Gregory Jefferis on 2009-01-05.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import <Cocoa/Cocoa.h>
#import <OmniFoundation/OmniFoundation.h>
#import "BibItem.h"
#import "BDSKBibTeXParser.h"
#import "BDSKStringConstants.h"
#import "BDSKPubMedParser.h"


@interface TestPubMed : SenTestCase {
	BibItem *bibitem;
}

@end

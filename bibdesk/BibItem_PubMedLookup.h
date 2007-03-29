//
//  BibItem_PubMedLookup.h
//  Bibdesk
//
//  Created by Adam Maxwell on 03/29/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BibItem.h"

@interface BibItem (PubMedLookup)

+ (id)itemWithPMID:(NSString *)pmid;

@end

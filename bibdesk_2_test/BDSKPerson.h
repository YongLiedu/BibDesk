//
//  BDSKPerson.h
//  bd2xtest
//
//  Created by Michael McCracken on 7/17/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BDSKContributor.h"


@interface BDSKPerson : BDSKContributor {

}

- (NSString *)stringValueForSearch;
- (NSString *)name;

@end

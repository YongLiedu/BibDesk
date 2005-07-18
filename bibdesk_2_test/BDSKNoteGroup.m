//
//  BDSKNoteGroup.m
//  bd2
//
//  Created by Michael McCracken on 7/13/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKNoteGroup.h"


@implementation BDSKNoteGroup

// TODO: make an analog to publicationsinselforchildren. 
// consider doing something different if a child has an exclude 
// bit set or if self is (not) root...

- (NSImage *)icon{
    NSImage *theIcon = [NSImage imageNamed:@"NSApplicationIcon"];
    [theIcon setSize:NSMakeSize(16, 16)];
    return theIcon;
}

@end

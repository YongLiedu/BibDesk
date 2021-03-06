// Copyright 2002-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "NSMutableSet-OFExtensions.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSMutableSet-OFExtensions.m 93428 2007-10-25 16:36:11Z kc $");

@implementation NSMutableSet (OFExtensions)

- (void) removeObjectsFromArray: (NSArray *) objects;
{
    unsigned int objectIndex;
    
    objectIndex = [objects count];
    while (objectIndex--)
        [self removeObject: [objects objectAtIndex: objectIndex]];
}

- (void) exclusiveDisjoinSet: (NSSet *) otherSet;
{
    NSEnumerator *otherEnumerator;
    id otherElement;

    /* special case: avoid modifying set while enumerating over it */
    if (otherSet == self) {
        [self removeAllObjects];
        return;
    }

    /* general case */
    otherEnumerator = [otherSet objectEnumerator];
    while( (otherElement = [otherEnumerator nextObject]) != nil ) {
        if ([self containsObject:otherElement])
            [self removeObject:otherElement];
        else
            [self addObject:otherElement];
    }
}


@end

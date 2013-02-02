// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFStaticObject.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/OFStaticObject.m 93428 2007-10-25 16:36:11Z kc $")

@implementation OFStaticObject

- (void)dealloc;
{
    OBASSERT_NOT_REACHED("We override -release to do nothing, so how did you get here?");
    
    // Squelch warning emitted by 10.4 compiler
    return;
    [super dealloc];
}

- (unsigned int)retainCount;
{
    return 1;
}

- retain;
{
    return self;
}

- (void)release;
{
}

- autorelease;
{
    return self;
}

@end

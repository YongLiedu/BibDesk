// Copyright 1997-2003 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// http://www.omnigroup.com/DeveloperResources/OmniSourceLicense.html.

#import <OmniFoundation/OFStaticObject.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>

RCS_ID("$Header: /Network/Source/CVS/OmniGroup/Frameworks/OmniFoundation/OFStaticObject.m,v 1.8 2003/01/15 22:51:50 kc Exp $")

@implementation OFStaticObject

- (void)dealloc;
{
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

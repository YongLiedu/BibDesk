// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/OFObject.h 89466 2007-08-01 23:35:13Z kc $

#ifndef __OFObjectHeader__
#define __OFObjectHeader__

#import <OmniBase/OBObject.h>

@interface OFObject : OBObject
{
    unsigned int retainCount; /*" Inline retain count for faster -retain/-release. "*/
}

@end

extern id <NSObject> OFCopyObject(OFObject *object, unsigned extraBytes, NSZone *zone);

#endif // __OFObjectHeader__

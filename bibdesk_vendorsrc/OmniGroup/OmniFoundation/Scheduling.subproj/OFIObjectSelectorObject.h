// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/Scheduling.subproj/OFIObjectSelectorObject.h 68913 2005-10-03 19:36:19Z kc $

#import "OFIObjectSelector.h"

@interface OFIObjectSelectorObject : OFIObjectSelector
{
    id withObject;
}

- initForObject:(id)anObject selector:(SEL)aSelector withObject:(id)aWithObject;

@end

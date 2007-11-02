// Copyright 2003-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/CoreFoundationExtensions/CFArray-OFExtensions.h 92223 2007-10-03 00:02:16Z wiml $

#import <CoreFoundation/CFArray.h>
#import <OmniFoundation/FrameworkDefines.h>

OmniFoundation_EXTERN const CFArrayCallBacks OFNonOwnedPointerArrayCallbacks;
OmniFoundation_EXTERN const CFArrayCallBacks OFNSObjectArrayCallbacks;
OmniFoundation_EXTERN const CFArrayCallBacks OFIntegerArrayCallbacks;

// Convenience functions
@class NSMutableArray;
OmniFoundation_EXTERN NSMutableArray *OFCreateNonOwnedPointerArray(void);
OmniFoundation_EXTERN NSMutableArray *OFCreateIntegerArray(void);


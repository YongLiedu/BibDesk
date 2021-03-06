// Copyright 2000-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/OFWeakRetainProtocol.h 68913 2005-10-03 19:36:19Z kc $

#import <objc/objc.h>

@protocol OFWeakRetain
// Must be implemented by the class itself
- (void)invalidateWeakRetains;

// Implemented by the OFWeakRetainConcreteImplementation_IMPLEMENTATION macro
- (void)incrementWeakRetainCount;
- (void)decrementWeakRetainCount;
- (id)strongRetain;
@end

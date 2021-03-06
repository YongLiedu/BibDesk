// Copyright 1998-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniBase/SystemType.h 89466 2007-08-01 23:35:13Z kc $


// We only support Mac OS X currently but we'll keep the macros defined here.

// This header has gone missing on 10.5.  We should wean ourselves off of it.
#if !defined(MAC_OS_X_VERSION_10_5) || MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5
#import <sys/version.h>

#define OBOperatingSystemMajorVersion KERNEL_MAJOR_VERSION
#define OBOperatingSystemMinorVersion KERNEL_MINOR_VERSION
#endif

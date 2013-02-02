// Copyright 1997-2006 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniAppKit/OpenStepExtensions.subproj/NSWindow-OAExtensions.h 80079 2006-10-10 21:25:06Z wiml $

#import <AppKit/NSWindow.h>

#import <Foundation/NSGeometry.h> // for NSPoint
#import <Foundation/NSDate.h> // for NSTimeInterval

@interface NSWindow (OAExtensions)

+ (NSArray *)windowsInZOrder;

- (NSPoint)frameTopLeftPoint;
- (void)morphToFrame:(NSRect)newFrame overTimeInterval:(NSTimeInterval)morphInterval;

- (BOOL)isBecomingKey;
- (BOOL)shouldDrawAsKey;

- (void *)carbonWindowRef;

#if defined(MAC_OS_X_VERSION_10_4) && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_4
- (void)addConstructionWarning;
#endif

- (CGPoint)convertBaseToCGScreen:(NSPoint)windowPoint;

@end

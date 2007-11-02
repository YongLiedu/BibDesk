// Copyright 2006-2007 The Omni Group.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniAppKit/OpenStepExtensions.subproj/NSWindowController-OAExtensions.h 87505 2007-05-28 00:17:35Z kc $

#import <AppKit/NSWindowController.h>

#import <AppKit/NSCell.h> // For NSControlSize

@interface NSWindowController (OAExtensions)

+ (NSWindow *)startingLongOperation:(NSString *)operationDescription controlSize:(NSControlSize)controlSize;
+ (void)startingLongOperation:(NSString *)operationDescription controlSize:(NSControlSize)controlSize inWindow:(NSWindow *)documentWindow automaticallyEnds:(BOOL)shouldAutomaticallyEnd;
+ (void)continuingLongOperation:(NSString *)operationStatus;
+ (void)finishedLongOperationForWindow:(NSWindow *)window;
+ (void)finishedLongOperation;

- (void)startingLongOperation:(NSString *)operationDescription;

@end

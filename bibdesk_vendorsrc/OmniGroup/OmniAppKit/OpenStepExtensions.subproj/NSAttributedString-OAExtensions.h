// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniAppKit/OpenStepExtensions.subproj/NSAttributedString-OAExtensions.h 89466 2007-08-01 23:35:13Z kc $

#import <Foundation/NSAttributedString.h>
#import <Foundation/NSGeometry.h> // For NSRect

@interface NSAttributedString (OAExtensions)

+ (NSString *)attachmentString;

- (NSAttributedString *)initWithHTML:(NSString *)htmlString;
- (NSString *)htmlString;
- (NSData *)rtf;

- (void)drawInRectangle:(NSRect)rectangle alignment:(int)alignment verticallyCentered:(BOOL)verticallyCenter;

- (void)drawCenteredShrinkingToFitInRect:(NSRect)rect;

@end

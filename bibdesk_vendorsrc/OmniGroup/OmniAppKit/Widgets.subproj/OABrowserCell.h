// Copyright 1997-2004 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: /Network/Source/CVS/OmniGroup/Frameworks/OmniAppKit/Widgets.subproj/OABrowserCell.h,v 1.12 2004/02/10 04:07:36 kc Exp $

#import <AppKit/NSBrowserCell.h>

@class NSDictionary;

@interface OABrowserCell : NSBrowserCell
{
    NSDictionary   *userInfo;
}

- (NSDictionary *) userInfo;
- (void)setUserInfo: (NSDictionary *) newInfo;

@end

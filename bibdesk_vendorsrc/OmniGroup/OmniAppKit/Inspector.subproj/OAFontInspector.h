// Copyright 2002-2003 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// http://www.omnigroup.com/DeveloperResources/OmniSourceLicense.html.
//
// $Header: /Network/Source/CVS/OmniGroup/Frameworks/OmniAppKit/Inspector.subproj/OAFontInspector.h,v 1.4 2003/01/25 01:24:45 toon Exp $

#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>
#import <OmniAppKit/OAGroupedInspectorProtocol.h>

@class NSView;

@interface OAFontInspector : NSObject <OAGroupedInspector>
{
    NSView *contentView;
    NSSize minimumContentSize;
    float styleHeight;
}

// API

@end

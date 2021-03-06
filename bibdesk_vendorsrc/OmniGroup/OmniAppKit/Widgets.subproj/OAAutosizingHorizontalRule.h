// Copyright 2005-2006 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniAppKit/Widgets.subproj/OAAutosizingHorizontalRule.h 79079 2006-09-07 22:35:32Z kc $

#import <AppKit/NSBox.h>

@class NSTextField;

#import <AppKit/NSNibDeclarations.h> // For IBOutlet

@interface OAAutosizingHorizontalRule : NSBox
{
    IBOutlet NSTextField *labelTextField;
}

@end


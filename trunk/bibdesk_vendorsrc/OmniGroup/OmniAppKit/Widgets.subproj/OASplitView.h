// Copyright 2000-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniAppKit/Widgets.subproj/OASplitView.h 93428 2007-10-25 16:36:11Z kc $

#import <AppKit/NSSplitView.h>

@interface OASplitView : NSSplitView
{
    NSString *positionAutosaveName;
}

- (void)setPositionAutosaveName:(NSString *)name;
- (NSString *)positionAutosaveName;

@end


@interface NSObject (OASplitViewExtendedDelegate)
- (void)splitView:(OASplitView *)sender multipleClick:(NSEvent *)mouseEvent; // Called when the divider is double-clicked.
@end

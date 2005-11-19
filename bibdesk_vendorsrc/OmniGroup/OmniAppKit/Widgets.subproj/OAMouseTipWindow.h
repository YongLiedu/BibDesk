// Copyright 2002-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/SourceRelease_2005-10-03/OmniGroup/Frameworks/OmniAppKit/Widgets.subproj/OAMouseTipWindow.h 68913 2005-10-03 19:36:19Z kc $

#import <AppKit/NSPanel.h>

@class NSAttributedString;
@class NSTimer;
@class OAMouseTipView;

typedef enum {
    MouseTip_TooltipStyle, MouseTip_ExposeStyle, MouseTip_DockStyle
} OAMouseTipStyle;

#define OAMouseTipsEnabledPreferenceKey (@"DisplayMouseTips")

@interface OAMouseTipWindow : NSPanel
{
    id nonretainedOwner;
    OAMouseTipView *mouseTipView;
    OAMouseTipStyle currentStyle;
    NSTimer *waitTimer;
    BOOL hasRegisteredForNotification;
}

// API

+ (void)setStyle:(OAMouseTipStyle)aStyle;
+ (void)setLevel:(int)windowLevel;

+ (void)showMouseTipWithTitle:(NSString *)aTitle;
+ (void)showMouseTipWithTitle:(NSString *)aTitle activeRect:(NSRect)activeRect edge:(NSRectEdge)onEdge delay:(float)delay;
+ (void)showMouseTipWithAttributedTitle:(NSAttributedString *)aTitle activeRect:(NSRect)activeRect maxWidth:(float)maxWidth edge:(NSRectEdge)onEdge delay:(float)delay;
+ (void)hideMouseTip;

// A way to keep objects from hiding the tip if it is now being used by someone else 
// +hideMouseTipForOwner: does nothing if the owner doesn't match the last +setOwner call
+ (void)setOwner:(id)owner;
+ (void)hideMouseTipForOwner:(id)owner;

@end

// Copyright 2002-2003 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// http://www.omnigroup.com/DeveloperResources/OmniSourceLicense.html.
//
// $Header: /Network/Source/CVS/OmniGroup/Frameworks/OmniAppKit/Inspector.subproj/OAInspectorGroup.h,v 1.32 2003/03/28 20:51:39 toon Exp $

#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h> // for NSRect

@class NSArray, NSMutableArray, NSWindow, NSScreen, NSMenuItem, NSTimer;
@class OAInspectorController;

@interface OAInspectorGroup : NSObject
{
    NSMutableArray *inspectors;
    BOOL isResizing, isToggling, ignoreResizing, isShowing, screenChangesEnabled;
    void *_private;
}

// API

+ (void)restoreInspectorGroupsWithInspectors:(NSArray *)inspectors;
+ (void)clearAllGroups;
+ (void)enableWorkspaces;

+ (void)setDynamicMenuPlaceholder:(NSMenuItem *)placeholder;
+ (NSArray *)groups;
+ (NSArray *)visibleGroups;

- (void)hideGroup;
- (void)showGroup;
- (void)orderFrontGroup;

- (void)addInspector:(OAInspectorController *)aController;
- (NSRect)inspector:(OAInspectorController *)aController willResizeToFrame:(NSRect)aFrame isToggling:(BOOL)isToggling;

- (void)detachFromGroup:(OAInspectorController *)aController;
- (NSRect)snapToOtherGroupWithFrame:(NSRect)aRect;
- (NSRect)fitFrame:(NSRect)aFrame onScreen:(NSScreen *)aScreen;
- (void)windowsDidMoveToFrame:(NSRect)aFrame;

- (BOOL)isHeadOfGroup:(OAInspectorController *)aController;
- (NSArray *)inspectors;
- (NSRect)groupFrame;
- (BOOL)isVisible;
- (BOOL)isBelowOverlappingGroup;

- (float)minimumWidth;
- (float)desiredWidth;
- (float)singlePaneExpandedMaxHeight;
- (BOOL)ignoreResizing;
- (BOOL)canBeginResizingOperation;

- (BOOL)screenChangesEnabled;
- (void)setScreenChangesEnabled:(BOOL)yn;
- (void)setFloating:(BOOL)yn;

@end

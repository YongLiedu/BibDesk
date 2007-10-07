//
//  AMButtonBarItem.h
//  ButtonBarTest
//
//  Created by Andreas on 09.02.07.
//  Copyright 2007 Andreas Mayer. All rights reserved.
//

//  tool tips and special items like separators and overflow menus are not yet supported


#import <Cocoa/Cocoa.h>

@class AMButtonBarCell, AMButtonBar;

@interface AMButtonBarItem : NSButton <NSCoding> {
	BOOL active;
	BOOL separatorItem;
	BOOL overflowItem;
	NSString *itemIdentifier;
    NSMenu *overflowMenu;
    AMButtonBar *buttonBar;
}

- (id)initWithIdentifier:(NSString *)identifier;

- (BOOL)isActive;
- (void)setActive:(BOOL)value;

- (BOOL)isSeparatorItem;
- (void)setSeparatorItem:(BOOL)value;

- (BOOL)isOverflowItem;
- (void)setOverflowItem:(BOOL)value;

- (NSString *)itemIdentifier;
- (void)setItemIdentifier:(NSString *)value;

- (NSMenu *)overflowMenu;
- (void)setOverflowMenu:(NSMenu *)value;

- (void)setButtonBar:(AMButtonBar *)aBar;

@end

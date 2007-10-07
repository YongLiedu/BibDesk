//
//  AMButtonBarItem.m
//  ButtonBarTest
//
//  Created by Andreas on 09.02.07.
//  Copyright 2007 Andreas Mayer. All rights reserved.
//

#import "AMButtonBarItem.h"
#import "AMButtonBarCell.h"
#import "AMButtonBar.h"

@implementation AMButtonBarItem

+ (Class)cellClass { return [AMButtonBarCell class]; }

- (id)initWithIdentifier:(NSString *)theIdentifier;
{
	self = [super initWithFrame:NSZeroRect];
	if (self != nil) {
		[self setItemIdentifier:theIdentifier];
		[self setFrame:NSZeroRect];
		[self setEnabled:YES];
        [self setBezelStyle:NSRecessedBezelStyle];
        [self setButtonType:NSPushOnPushOffButton];
        [self setShowsBorderOnlyWhileMouseInside:YES];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];
	itemIdentifier = [[decoder decodeObjectForKey:@"AMBBIItemIdentifier"] retain];
	active = [decoder decodeBoolForKey:@"AMBBIActive"];
	separatorItem = [decoder decodeBoolForKey:@"AMBBISeparatorItem"];
	overflowItem = [decoder decodeBoolForKey:@"AMBBIOverflowItem"];
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:itemIdentifier forKey:@"AMBBIItemIdentifier"];
	[coder encodeBool:active forKey:@"AMBBIActive"];
	[coder encodeBool:separatorItem forKey:@"AMBBISeparatorItem"];
	[coder encodeBool:overflowItem forKey:@"AMBBIOverflowItem"];
}


- (void)dealloc
{
	[overflowMenu release];
	[itemIdentifier release];
	[super dealloc];
}

- (BOOL)isActive
{
	return active;
}

- (void)setActive:(BOOL)value
{
	if (active != value) {
		active = value;
	}
}

- (BOOL)isSeparatorItem
{
	return separatorItem;
}

- (void)setSeparatorItem:(BOOL)value
{
	if (separatorItem != value) {
		separatorItem = value;
	}
}

- (BOOL)isOverflowItem
{
	return overflowItem;
}

- (void)setOverflowItem:(BOOL)value
{
	if (overflowItem != value) {
		overflowItem = value;
	}
}

- (NSString *)itemIdentifier
{
	return itemIdentifier;
}

- (void)setItemIdentifier:(NSString *)value
{
	if (itemIdentifier != value) {
		id old = itemIdentifier;
		itemIdentifier = [value retain];
		[old release];
	}
}

- (NSMenu *)overflowMenu
{
	return overflowMenu;
}

- (void)setOverflowMenu:(NSMenu *)value
{
	if (overflowMenu != value) {
		id old = overflowMenu;
		overflowMenu = [value retain];
		[old release];
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
    [buttonBar didClickItem:self];
}

- (void)setButtonBar:(AMButtonBar *)aBar
{
    buttonBar = aBar;
}

- (BOOL)isOpaque { return NO; }

@end

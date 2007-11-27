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

- (void)commonInit
{
    [self setEnabled:YES];
    [self setBezelStyle:NSRecessedBezelStyle];
    [self setShowsBorderOnlyWhileMouseInside:YES];
    [self setButtonType:NSPushOnPushOffButton];
    [[self cell] setControlSize:NSSmallControlSize];
    [self setFont:[NSFont boldSystemFontOfSize:[NSFont systemFontSizeForControlSize:[[self cell] controlSize]]]];    
}

- (id)initWithIdentifier:(NSString *)theIdentifier;
{
	self = [super initWithFrame:NSZeroRect];
    [self setItemIdentifier:theIdentifier];
    [self commonInit];
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];
    [self commonInit];
    itemIdentifier = [[decoder decodeObjectForKey:@"AMBBIItemIdentifier"] retain];
	active = [decoder decodeBoolForKey:@"AMBBIActive"];
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
	[coder encodeObject:itemIdentifier forKey:@"AMBBIItemIdentifier"];
	[coder encodeBool:active forKey:@"AMBBIActive"];
}


- (void)dealloc
{
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

- (void)mouseDown:(NSEvent *)theEvent
{
    // don't call super, since the button bar handles selecting/deselecting
    [buttonBar didClickItem:self];
}

- (void)setButtonBar:(AMButtonBar *)aBar
{
    buttonBar = aBar;
}

- (BOOL)isOpaque { return NO; }

- (void)viewDidMoveToWindow {
    // fix for a Tiger bug when a button is swapped in, it does not reset the tracking rects
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4 && [self showsBorderOnlyWhileMouseInside]) {
        [self setShowsBorderOnlyWhileMouseInside:NO];
        [self setShowsBorderOnlyWhileMouseInside:YES];
    }
    [super viewDidMoveToWindow];
}

- (void)viewDidMoveToSuperview {
    // fix for a Tiger bug when a button is swapped in, it does not reset the tracking rects
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4 && [self showsBorderOnlyWhileMouseInside]) {
        [self setShowsBorderOnlyWhileMouseInside:NO];
        [self setShowsBorderOnlyWhileMouseInside:YES];
    }
    [super viewDidMoveToSuperview];
}

@end

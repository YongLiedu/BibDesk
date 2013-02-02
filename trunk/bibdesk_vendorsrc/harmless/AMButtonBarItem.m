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
	if (self = [super initWithFrame:NSZeroRect]) {
        [self setItemIdentifier:theIdentifier];
        [self commonInit];
	}
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    if (self = [super initWithCoder:decoder]) {
        [self commonInit];
	}
    return self;
}

- (NSString *)itemIdentifier
{
	return [[self cell] representedObject];
}

- (void)setItemIdentifier:(NSString *)value
{
	[[self cell] setRepresentedObject:value];
}

- (BOOL)isOpaque { return NO; }

@end

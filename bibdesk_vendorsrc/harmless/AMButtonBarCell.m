//
//  AMButtonBarCell.m
//  AMButtonBar
//
//  Created by Andreas on 2007-02-10
//  Copyright (c) 2004 Andreas Mayer. All rights reserved.

#import "AMButtonBarCell.h"
#import <math.h>

static float am_backgroundInset = 1.5;
static float am_textGap = 1.5;

static NSShadow *__whiteShadow = nil;
static NSShadow *__darkShadow = nil;

@implementation AMButtonBarCell

+ (void) initialize
{
	__whiteShadow = [[NSShadow alloc] init];
	[__whiteShadow setShadowOffset:NSMakeSize(0.0, -1.0)];
	[__whiteShadow setShadowBlurRadius:1.0];
	[__whiteShadow setShadowColor:[NSColor whiteColor]];
    
	__darkShadow = [[NSShadow alloc] init];
	[__darkShadow setShadowOffset:NSMakeSize(0.0, -1.0)];
	[__darkShadow setShadowBlurRadius:1.0];
	[__darkShadow setShadowColor:[NSColor controlDarkShadowColor]];
}

- (void)finishInit
{
    isMouseOver = NO;
}

- (id)initTextCell:(NSString *)aString
{
    self = [super initTextCell:aString];
    [self finishInit];
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super initWithCoder:decoder];
	[self finishInit];
	return self;
}

- (void)mouseEntered:(NSEvent *)event
{
    isMouseOver = YES;
    [super mouseEntered:event];
}

- (void)mouseExited:(NSEvent *)event
{
    isMouseOver = NO;
    [super mouseExited:event];
}

/*
 Don't customize drawing at all on 10.5 and later.  We only override these methods
 to fix some drawing glitches on 10.4 (white square drawn behind the button when it's
 supposed to only draw text).
 */

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView*)controlView
{
	if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4 || [self state] == NSOnState || isMouseOver)
		[super drawBezelWithFrame:frame inView:controlView];	
}

- (NSRect)drawTitle:(NSAttributedString *)title withFrame:(NSRect)frame inView:(NSView *)controlView
{
    id titleToDraw = title;
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4) {

        titleToDraw = [[title mutableCopy] autorelease];
        NSColor *color;
        NSShadow *textShadow;
        if ([self state] == NSOnState || isMouseOver) {
            color = [NSColor whiteColor];
            textShadow = __darkShadow;
        }
        else {
            color = [NSColor blackColor];
            textShadow = __whiteShadow;
    }
        [titleToDraw addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, [titleToDraw length])];
        [titleToDraw addAttribute:NSShadowAttributeName value:textShadow range:NSMakeRange(0, [titleToDraw length])];
    }
    return [super drawTitle:titleToDraw withFrame:frame inView:controlView];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4) {
        [self drawBezelWithFrame:cellFrame inView:controlView];
        [self drawTitle:[self attributedTitle] withFrame:cellFrame inView:controlView];
    }
    else {
        [super drawInteriorWithFrame:cellFrame inView:controlView];
    }
}

@end



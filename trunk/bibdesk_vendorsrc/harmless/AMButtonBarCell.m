//
//  AMButtonBarCell.m
//  AMButtonBar
//
//  Created by Andreas on 2007-02-10
//  Copyright (c) 2004 Andreas Mayer. All rights reserved.

#import "AMButtonBarCell.h"

static NSParagraphStyle *paragraphStyle = nil;

@implementation AMButtonBarCell

+ (void) initialize
{
    NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [ps setAlignment:NSCenterTextAlignment];
    paragraphStyle = [ps copy];
}

- (id)initTextCell:(NSString *)aString
{
    if (self = [super initTextCell:aString]) {
        isMouseOver = NO;
    }
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder]) {
        isMouseOver = NO;
    }
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

- (void)drawBezelWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    // this is called for each mouseEntered: event, and we have to perform the bezel adjustment for those as well
    if (isMouseOver && [self state] != NSOnState)
        [super drawBezelWithFrame:cellFrame inView:controlView];
}

/*
We can remove this class when compiling for 10.5 and greater.  With the 10.4 SDK, the button does not show on state when the mouse is outside the button.  Behavior changes at link time, which is not documented.  
 
 Drawing while the mouse is inside still is not correct, as the background color shouldn't change, so we hack around that.  Additionally, text isn't perfectly centered in the vertical direction; there's more gap at the top than the bottom, so we add a 1 point vertical offset.
 */

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSFont *font = [[NSFontManager sharedFontManager] convertFont:[self font] toHaveTrait:NSBoldFontMask];
	NSColor *textColor;
    NSShadow *textShadow = [[NSShadow alloc] init];
    
    [textShadow setShadowBlurRadius:1.0];
    [textShadow setShadowOffset:NSMakeSize(0.0, -1.0)];

	if ([self state] == NSOnState || isMouseOver) {
		
        // in this case, offset the rect and call super, so we don't offset it again in our own implementation
        if ([self state] == NSOnState) {
            [super drawBezelWithFrame:cellFrame inView:controlView];
        }
        else {
            // this is a mouseOver in a cell that's off
            [self drawBezelWithFrame:cellFrame inView:controlView];
        }
		textColor = [NSColor whiteColor];
		[textShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.6]];
		
	} else {
		textColor = [NSColor colorWithCalibratedWhite:0.2 alpha:1.0];
		[textShadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.6]];
	}
	    
	NSDictionary *attributes = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, textColor, NSForegroundColorAttributeName, paragraphStyle, NSParagraphStyleAttributeName, textShadow, NSShadowAttributeName, nil];
    NSAttributedString *title = [[NSAttributedString alloc] initWithString:[self title] attributes:attributes];
    cellFrame.origin.y += [controlView isFlipped] ? -1.0 : 1.0;
    [self drawTitle:title withFrame:cellFrame inView:controlView];
    [attributes release];
    [title release];
    [textShadow release];
}

@end



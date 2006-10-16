//
//  BDSKSplitView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 31/10/05.
/*
 This software is Copyright (c) 2005,2006
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "BDSKSplitView.h"
#import "BDSKStatusBar.h"
#import "NSBezierPath_CoreImageExtensions.h"
#import "CIImage_BDSKExtensions.h"

#define END_JOIN_WIDTH 3.0f
#define END_JOIN_HEIGHT 20.0f

@interface BDSKSplitView (Private)

- (float)horizontalFraction;
- (void)setHorizontalFraction:(float)newFract;

- (float)verticalFraction;
- (void)setVerticalFraction:(float)newFract;

@end

@implementation BDSKSplitView

+ (CIColor *)startColor{
    static CIColor *startColor = nil;
    if (startColor == nil)
        startColor = [[CIColor colorWithNSColor:[NSColor colorWithCalibratedWhite:0.85 alpha:1.0]] retain];
    return startColor;
}

+ (CIColor *)endColor{
    static CIColor *endColor = nil;
    if (endColor == nil)
        endColor = [[CIColor colorWithNSColor:[NSColor colorWithCalibratedWhite:0.95 alpha:1.0]] retain];
   return endColor;
}

- (id)initWithFrame:(NSRect)frameRect{
    if (self = [super initWithFrame:frameRect]) {
        drawEnd = NO;
    }
    return self;
}

- (void)drawBlendedJoinEndAtLeftInRect:(NSRect)rect {
    // this blends us smoothly with the a vertical divider on our left
    Class svClass = [self class];
    [[NSBezierPath bezierPathWithRect:rect] fillPathWithCIColor:[svClass startColor]
                                                 blendedAtRight:NO
                                  ofVerticalGradientFromCIColor:[svClass startColor]
                                                      toCIColor:[svClass endColor]];
}

- (void)drawBlendedJoinEndAtBottomInRect:(NSRect)rect {
    // this blends us smoothly with the status bar
    [[NSBezierPath bezierPathWithRect:rect] fillPathWithHorizontalGradientFromCIColor:[[self class] startColor]
                                                                            toCIColor:[[self class] endColor]
                                                                         blendedAtTop:NO
                                                        ofVerticalGradientFromCIColor:[BDSKStatusBar lowerColor]
                                                                            toCIColor:[BDSKStatusBar upperColor]];
}

- (void)drawRect:(NSRect)rect {
	
	NSArray *subviews = [self subviews];
	int i, count = [subviews count];
	id view;
	NSRect divRect;

	// draw the dimples 
	for (i = 0; i < (count-1); i++) {
		view = [subviews objectAtIndex:i];
		divRect = [view frame];
		if ([self isVertical] == NO) {
			divRect.origin.y = NSMaxY (divRect);
			divRect.size.height = [self dividerThickness];
		} else {
			divRect.origin.x = NSMaxX (divRect);
			divRect.size.width = [self dividerThickness];
		}
		if (NSIntersectsRect(rect, divRect)) {
			[[NSBezierPath bezierPathWithRect:divRect] fillPathVertically:![self isVertical] withStartCIColor:[[self class] startColor] endCIColor:[[self class] endColor]];
            if (drawEnd) {
                NSRect endRect, ignored;
                if ([self isVertical]) {
                    NSDivideRect(divRect, &endRect, &ignored, END_JOIN_HEIGHT, NSMaxYEdge);
                    [self drawBlendedJoinEndAtBottomInRect:endRect];
                } else {
                    NSDivideRect(divRect, &endRect, &ignored, END_JOIN_WIDTH, NSMinXEdge);
                    [self drawBlendedJoinEndAtLeftInRect:endRect];
                }
            }
			[self drawDividerInRect: divRect];
		}
	}
}

- (float)dividerThickness {
	return 6.0;
}

- (void)adjustSubviews {
	// we send the notifications because NSSplitView doesn't and we need them for AutoSave of e.g. double click actions
	[[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewWillResizeSubviewsNotification object:self];
	[super adjustSubviews];
	[[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewDidResizeSubviewsNotification object:self];
}

- (BOOL)drawEnd {
    return drawEnd;
}

- (void)setDrawEnd:(BOOL)flag {
    drawEnd = flag;
}

// Omni assumes that splitviews have a horizontal divider, but we want fraction to be correct for vertical dividers as well.  
// Overriding in an NSSplitView category gives a conflict with the implementation NSSplitView-OAExtensions, with unpredictable result
- (float)fraction;
{
    return [self isVertical] ? [self verticalFraction] : [self horizontalFraction];
}

- (void)setFraction:(float)newFract;
{
    if ([self isVertical])
        [self setVerticalFraction:newFract];
    else
        [self setHorizontalFraction:newFract];
}

@end


@implementation BDSKSplitView (Private)

- (float)horizontalFraction;
{
    NSRect topFrame, bottomFrame;
    
    if ([[self subviews] count] < 2)
        return 0.0;
    
    topFrame = [[[self subviews] objectAtIndex:0] frame];
    bottomFrame = [[[self subviews] objectAtIndex:1] frame];
    return NSHeight(bottomFrame) / (NSHeight(bottomFrame) + NSHeight(topFrame));
}

- (void)setHorizontalFraction:(float)newFract;
{
    NSRect topFrame, bottomFrame;
    NSView *topSubView;
    NSView *bottomSubView;
    float totalHeight;
    
    if ([[self subviews] count] < 2)
        return;
    
    topSubView = [[self subviews] objectAtIndex:0];
    bottomSubView = [[self subviews] objectAtIndex:1];
    topFrame = [topSubView frame];
    bottomFrame = [bottomSubView frame];
    totalHeight = NSHeight(bottomFrame) + NSHeight(topFrame);
    bottomFrame.size.height = newFract * totalHeight;
    topFrame.size.height = totalHeight - NSHeight(bottomFrame);
    [topSubView setFrame:topFrame];
    [bottomSubView setFrame:bottomFrame];
    [self adjustSubviews];
    [self setNeedsDisplay: YES];
}

- (float)verticalFraction;
{
    NSRect leftFrame, rightFrame;
    
    if ([[self subviews] count] < 2)
        return 0.0;
    
    leftFrame = [[[self subviews] objectAtIndex:0] frame];
    rightFrame = [[[self subviews] objectAtIndex:1] frame];
    return NSWidth(rightFrame) / (NSWidth(rightFrame) + NSWidth(leftFrame));
}

- (void)setVerticalFraction:(float)newFract;
{
    NSRect leftFrame, rightFrame;
    NSView *leftSubView;
    NSView *rightSubView;
    float totalWidth;
    
    if ([[self subviews] count] < 2)
        return;
    
    leftSubView = [[self subviews] objectAtIndex:0];
    rightSubView = [[self subviews] objectAtIndex:1];
    leftFrame = [leftSubView frame];
    rightFrame = [rightSubView frame];
    totalWidth = NSWidth(rightFrame) + NSWidth(leftFrame);
    rightFrame.size.width = newFract * totalWidth;
    leftFrame.size.width = totalWidth - NSWidth(rightFrame);
    [leftSubView setFrame:leftFrame];
    [rightSubView setFrame:rightFrame];
    [self adjustSubviews];
    [self setNeedsDisplay: YES];
}

@end
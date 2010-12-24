//
//  BDSKScrollableTextFieldCell.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 16/8/05.
/*
 This software is Copyright (c) 2005-2010
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

#import "BDSKScrollableTextFieldCell.h"
#import "NSGeometry_BDSKExtensions.h"


@implementation BDSKScrollableTextFieldCell

#pragma mark Class methods: images

+ (NSImage *)scrollArrowImageForButton:(BDSKScrollButton)button highlighted:(BOOL)highlighted{
	static NSImage *scrollArrowLeftImage = nil;
	static NSImage *scrollArrowLeftPressedImage = nil;
	static NSImage *scrollArrowRightImage = nil;
	static NSImage *scrollArrowRightPressedImage = nil;
	
	if (scrollArrowLeftImage == nil) {
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(0.0, 3.5)];
        [path lineToPoint:NSMakePoint(5.0, 0.5)];
        [path lineToPoint:NSMakePoint(5.0, 6.5)];
        [path closePath];
        
		scrollArrowLeftImage = [[NSImage alloc] initWithSize:NSMakeSize(6.0, 7.0)];
        [scrollArrowLeftImage lockFocus];
        [[NSColor colorWithCalibratedWhite:0.25 alpha:0.75] setFill];
        [path fill];
        [scrollArrowLeftImage unlockFocus];
        
		scrollArrowLeftPressedImage = [[NSImage alloc] initWithSize:NSMakeSize(6.0, 7.0)];
        [scrollArrowLeftPressedImage lockFocus];
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.75] setFill];
        [path fill];
        [scrollArrowLeftPressedImage unlockFocus];
        
        path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(6.0, 3.5)];
        [path lineToPoint:NSMakePoint(1.0, 0.5)];
        [path lineToPoint:NSMakePoint(1.0, 6.5)];
        [path closePath];
        
		scrollArrowRightImage = [[NSImage alloc] initWithSize:NSMakeSize(6.0, 7.0)];
        [scrollArrowRightImage lockFocus];
        [[NSColor colorWithCalibratedWhite:0.25 alpha:0.75] setFill];
        [path fill];
        [scrollArrowRightImage unlockFocus];
        
		scrollArrowRightPressedImage = [[NSImage alloc] initWithSize:NSMakeSize(6.0, 7.0)];
        [scrollArrowRightPressedImage lockFocus];
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.75] setFill];
        [path fill];
        [scrollArrowRightPressedImage unlockFocus];
	}
	
	if (button == BDSKScrollLeftButton) {
		if (highlighted)
			return scrollArrowLeftPressedImage;
		else
			return scrollArrowLeftImage;
	} else {
		if (highlighted)
			return scrollArrowRightPressedImage;
		else
			return scrollArrowRightImage;
	}
}

#pragma mark Init and dealloc

- (id)initTextCell:(NSString *)aString
{
	if (self = [super initTextCell:aString]) {
		scrollStep = 0;
		isLeftButtonHighlighted = NO;
		isRightButtonHighlighted = NO;
		isClipped = NO;
		
		[self stringHasChanged];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
		scrollStep = 0;
		isLeftButtonHighlighted = NO;
		isRightButtonHighlighted = NO;
		isClipped = NO;
		
		[self stringHasChanged];
    }
    return self;
}

#pragma mark Actions and accessors

- (IBAction)scrollForward:(id)sender {
	if (scrollStep < maxScrollStep)
		scrollStep++;
}

- (IBAction)scrollBack:(id)sender {
	if (scrollStep > 0) 
		scrollStep--;
}

- (BOOL)isButtonHighlighted:(BDSKScrollButton)button {
    if (button == BDSKScrollLeftButton)
		return isLeftButtonHighlighted;
	else
		return isRightButtonHighlighted;
}

- (void)setButton:(BDSKScrollButton)button highlighted:(BOOL)highlighted {
    if (button == BDSKScrollLeftButton) {
		if (isLeftButtonHighlighted == highlighted) return;
        isLeftButtonHighlighted = highlighted;
		[(NSControl *)[self controlView] updateCell:self];
    } else {
		if (isRightButtonHighlighted == highlighted) return;
        isRightButtonHighlighted = highlighted;
		[(NSControl *)[self controlView] updateCell:self];
	}
}

#pragma mark Drawing related methods

- (NSRect)buttonRect:(BDSKScrollButton)button forBounds:(NSRect)theRect{
	NSRect buttonRect = NSZeroRect;
	
	if(isClipped){
		NSSize buttonSize = [[[self class] scrollArrowImageForButton:button highlighted:NO] size];
        buttonRect = BDSKCenterRect(theRect, buttonSize, NO);
        if (button == BDSKScrollLeftButton)
			buttonRect.origin.x = NSMaxX(theRect) - 2.0f * buttonSize.width;
		else
			buttonRect.origin.x = NSMaxX(theRect) - buttonSize.width;
	}
	return buttonRect;
}

- (NSRect)textRectForBounds:(NSRect)theRect{
	NSRect rect = [self drawingRectForBounds:theRect];
	
	return rect;
}

// override this to get the rect in which the text is drawn right
- (NSRect)drawingRectForBounds:(NSRect)theRect{
	NSRect rect = [super drawingRectForBounds:theRect];
    
	if(isClipped){
		NSSize buttonSize = [[[self class] scrollArrowImageForButton:BDSKScrollLeftButton highlighted:NO] size];
		rect.size.width -= NSMaxX(rect) - NSMaxX(theRect) + 2 * buttonSize.width;
	}
	
	return rect;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView{
	NSAttributedString *attrString = [self attributedStringValue];
	NSRect textRect = NSInsetRect([self textRectForBounds:cellFrame], 1.0, 0.0);
	NSPoint textOrigin = textRect.origin;
	
	if (isClipped) {
		if (scrollStep == maxScrollStep) 
			textOrigin.x -= [self stringWidth] - NSWidth(textRect);
		else
			textOrigin.x -= 0.5f * scrollStep * NSWidth(textRect);
	}
	
	// draw the (clipped) text
	
	[controlView lockFocus];
	NSRectClip(textRect);
	[attrString drawAtPoint:textOrigin];
    [controlView unlockFocus];
	
	if(!isClipped)
        return;
	
    // draw the buttons
	
	NSImage *leftButtonImage = [[self class] scrollArrowImageForButton:BDSKScrollLeftButton 
														   highlighted:[self isButtonHighlighted:BDSKScrollLeftButton]];
	NSImage *rightButtonImage = [[self class] scrollArrowImageForButton:BDSKScrollRightButton
															highlighted:[self isButtonHighlighted:BDSKScrollRightButton]];
	
	NSRect leftButtonRect = [self buttonRect:BDSKScrollLeftButton forBounds:cellFrame]; 
	NSRect rightButtonRect = [self buttonRect:BDSKScrollRightButton  forBounds:cellFrame]; 
	NSPoint leftPoint = leftButtonRect.origin;
	NSPoint rightPoint = rightButtonRect.origin;
	if([controlView isFlipped]){
		leftPoint.y += leftButtonRect.size.height;
		rightPoint.y += rightButtonRect.size.height;
    }
	
	[controlView lockFocus];
	[leftButtonImage compositeToPoint:leftPoint operation:NSCompositeSourceOver];
	[rightButtonImage compositeToPoint:rightPoint operation:NSCompositeSourceOver];
    [controlView unlockFocus];
}

#pragma mark String widths

- (CGFloat)stringWidth {
	return [[self attributedStringValue] size].width;
}

- (void)stringHasChanged {
	CGFloat stringWidth = [self stringWidth];
	NSRect cellFrame = [[self controlView] bounds];
    
    isClipped = NO;
	
    NSRect textRect = [self textRectForBounds:cellFrame];
	
	if (NSWidth(textRect) > 2.0 && stringWidth > NSWidth(textRect) - 2.0)
		isClipped = YES;
	else 
		isClipped = NO;

	textRect = NSInsetRect([self textRectForBounds:cellFrame], 1.0, 0.0);
	
	scrollStep = 0;
	maxScrollStep = ceil(2 * stringWidth / NSWidth(textRect)) - 2;
	if (maxScrollStep < 0 ) 
		maxScrollStep = 0;
}

@end

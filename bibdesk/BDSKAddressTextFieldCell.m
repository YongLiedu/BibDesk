//
//  BDSKAddressTextFieldCell.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/26/11.
/*
 This software is Copyright (c) 2011
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

#import "BDSKAddressTextFieldCell.h"


@implementation BDSKAddressTextFieldCell

+ (Class)formatterClass { return Nil; }
 
- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
		[self setDrawsBackground:NO];
    }
    return self;
}

static inline NSRect adjustedFrame(NSRect cellFrame, NSView *controlView) {
	NSRect ignored;
    NSDivideRect(cellFrame, &ignored, &cellFrame, 1.0, [controlView isFlipped] ? NSMaxYEdge : NSMinYEdge);
    return cellFrame;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	NSRect outlineRect = [self layoutRectForBounds:cellFrame inView:controlView];
    NSRect outerShadowRect, innerShadowRect, ignored;
	NSGradient *gradient = nil;
    
    NSDivideRect(cellFrame, &outerShadowRect, &ignored, 10.0, [controlView isFlipped] ? NSMaxYEdge : NSMinYEdge);
    NSDivideRect(NSInsetRect(cellFrame, 1.0, 1.0), &innerShadowRect, &ignored, 10.0, [controlView isFlipped] ? NSMinYEdge : NSMaxYEdge);
    
	[[NSColor colorWithCalibratedWhite:1.0 alpha:0.394] set];
	[[NSBezierPath bezierPathWithRoundedRect:outerShadowRect xRadius:3.6 yRadius:3.6] fill];
	
	if ([[controlView window] isMainWindow] || [[controlView window] isKeyWindow])
		gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.24 alpha:1.0] endingColor:[NSColor colorWithCalibratedWhite:0.374 alpha:1.0]];
	else
		gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.55 alpha:1.0] endingColor:[NSColor colorWithCalibratedWhite:0.558 alpha:1.0]];
	[gradient drawInBezierPath:[NSBezierPath bezierPathWithRoundedRect:outlineRect xRadius:3.6 yRadius:3.6] angle:[controlView isFlipped] ? 90.0 : 270.0];
	[gradient release];
    
	[[NSColor colorWithCalibratedWhite:0.88 alpha:1.0] set];
	[[NSBezierPath bezierPathWithRoundedRect:innerShadowRect xRadius:2.9 yRadius:2.9] fill];
	
	[[NSColor whiteColor] set];
	[[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(cellFrame, 1.0, 2.0) xRadius:2.6 yRadius:2.6] fill];
	
    [self drawInteriorWithFrame:cellFrame inView:controlView];
    
	if ([self showsFirstResponder]) {	
		[NSGraphicsContext saveGraphicsState];
		NSSetFocusRingStyle(NSFocusRingOnly);
		[[NSBezierPath bezierPathWithRoundedRect:outlineRect xRadius:3.6 yRadius:3.6] fill]; 
		[NSGraphicsContext restoreGraphicsState];
	}
}

- (NSRect)textRectForBounds:(NSRect)aRect {
    NSRect ignored, rect = [super textRectForBounds:aRect];
    NSDivideRect(rect, &ignored, &rect, 17.0, NSMaxXEdge);
    return rect;
}

- (NSRect)layoutRectForBounds:(NSRect)aRect inView:(NSView *)controlView {
	NSRect ignored;
    NSDivideRect(aRect, &ignored, &aRect, 1.0, [controlView isFlipped] ? NSMaxYEdge : NSMinYEdge);
    return aRect;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [super drawInteriorWithFrame:[self layoutRectForBounds:cellFrame inView:controlView] inView:controlView];
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent {
    [super editWithFrame:[self layoutRectForBounds:aRect inView:controlView] inView:controlView editor:textObj delegate:anObject event:theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength {
    [super selectWithFrame:[self layoutRectForBounds:aRect inView:controlView] inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

@end

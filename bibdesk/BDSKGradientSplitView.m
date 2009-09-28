//
//  BDSKGradientSplitView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 31/10/05.
/*
 This software is Copyright (c) 2005-2009
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

#import "BDSKGradientSplitView.h"
#import "BDSKStatusBar.h"

#define END_JOIN_WIDTH 3.0f
#define END_JOIN_HEIGHT 22.0f

@interface BDSKGradientSplitView (Private)

- (CGFloat)horizontalFraction;
- (void)setHorizontalFraction:(CGFloat)newFract;

- (CGFloat)verticalFraction;
- (void)setVerticalFraction:(CGFloat)newFract;

@end

@implementation BDSKGradientSplitView

+ (NSColor *)startColor{
    static NSColor *startColor = nil;
    if (startColor == nil)
        startColor = [[NSColor colorWithCalibratedWhite:0.95 alpha:1.0] retain];
    return startColor;
}

+ (NSColor *)endColor{
    static NSColor *endColor = nil;
    if (endColor == nil)
        endColor = [[NSColor colorWithCalibratedWhite:0.85 alpha:1.0] retain];
    return endColor;
}

- (id)initWithFrame:(NSRect)frameRect{
    if (self = [super initWithFrame:frameRect]) {
        blendStyle = 0;
    }
    return self;
}

- (void)drawDividerInRect:(NSRect)aRect {
    NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:[[self class] startColor] endingColor:[[self class] endColor]] autorelease];
    [gradient drawInRect:aRect angle:[self isVertical] ? 0.0 : 90.0];

    if (blendStyle) {
        NSRect endRect, ignored;
        
        if (blendStyle & BDSKMinBlendStyleMask) {
            NSDivideRect(aRect, &endRect, &ignored, END_JOIN_WIDTH, [self isVertical] ? NSMinYEdge : NSMinXEdge);
            gradient = [[[NSGradient alloc] initWithStartingColor:[[self class] endColor] endingColor:[[[self class] endColor] colorWithAlphaComponent:0.0]] autorelease];
            [gradient drawInRect:endRect angle:[self isVertical] ? 90.0 : 0.0];
        }
        
        if (blendStyle & BDSKMaxBlendStyleMask) {
            NSDivideRect(aRect, &endRect, &ignored, END_JOIN_WIDTH, [self isVertical] ? NSMaxYEdge : NSMaxXEdge);
            gradient = [[[NSGradient alloc] initWithStartingColor:[[self class] startColor] endingColor:[[[self class] startColor] colorWithAlphaComponent:0.0]] autorelease];
            [gradient drawInRect:endRect angle:[self isVertical] ? 270.0 : 180.0];
        } else if ([self isVertical] && (blendStyle & BDSKStatusBarBlendStyleMask)) {
            NSDivideRect(aRect, &endRect, &ignored, END_JOIN_HEIGHT, NSMaxYEdge);
            gradient = [[[NSGradient alloc] initWithStartingColor:[BDSKStatusBar lowerColor] endingColor:[BDSKStatusBar upperColor]] autorelease];
            [gradient drawInRect:endRect angle:270.0];
            NSDivideRect(ignored, &endRect, &ignored, END_JOIN_WIDTH, NSMaxYEdge);
            gradient = [[[NSGradient alloc] initWithStartingColor:[BDSKStatusBar upperColor] endingColor:[[BDSKStatusBar upperColor] colorWithAlphaComponent:0.0]] autorelease];
            [gradient drawInRect:endRect angle:270.0];
        }
    }
    // Draw dimple
    [super drawDividerInRect:aRect];
}

- (CGFloat)dividerThickness {
	return 6.0;
}

- (void)adjustSubviews {
	// we send the notifications because NSSplitView doesn't and we need them for AutoSave of e.g. double click actions
	[[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewWillResizeSubviewsNotification object:self];
	[super adjustSubviews];
	[[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewDidResizeSubviewsNotification object:self];
}

- (NSInteger)blendStyle {
    return blendStyle;
}

- (void)setBlendStyle:(NSInteger)mask {
    if (blendStyle != mask) {
        blendStyle = mask;
    }
}

@end

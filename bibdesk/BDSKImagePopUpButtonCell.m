//
//  BDSKImagePopUpButtonCell.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/22/05.
//
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

#import "BDSKImagePopUpButtonCell.h"
#import "BDSKImagePopUpButton.h"


@implementation BDSKImagePopUpButtonCell

- (void)makeButtonCell {
    buttonCell = [[NSButtonCell allocWithZone:[self zone]] initTextCell:@""];
    [buttonCell setBordered: NO];
    [buttonCell setHighlightsBy:NSContentsCellMask];
    [buttonCell setImagePosition:NSImageOnly];
    [buttonCell setImageScaling:NSImageScaleProportionallyDown];
    [buttonCell setEnabled:[self isEnabled]];
    [buttonCell setShowsFirstResponder:[self showsFirstResponder]];
}

// we should always be unbordered and pulldown
- (id)initTextCell:(NSString *)stringValue pullsDown:(BOOL)pullsDown{
    if (self = [super initTextCell:stringValue pullsDown:YES]) {
		[self makeButtonCell];
        [self setBordered:NO];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder{
	if (self = [super initWithCoder:coder]) {
		[self makeButtonCell];
        [self setBordered:NO];
		// hack to always get regular controls in a toolbar customization palette, there should be a better way
		[self setControlSize:NSRegularControlSize];
	}
	return self;
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKImagePopUpButtonCell *copy = [super copyWithZone:aZone];
    [copy makeButtonCell];
    return copy;
}

- (void)dealloc{
    BDSKDESTROY(buttonCell);
    [super dealloc];
}

#pragma mark Accessors

- (void)setEnabled:(BOOL)flag {
	[super setEnabled:flag];
	[buttonCell setEnabled:flag];
}

- (void)setShowsFirstResponder:(BOOL)flag{
	[super setShowsFirstResponder:flag];
	[buttonCell setShowsFirstResponder:flag];
}

- (void)setBackgroundStyle:(NSBackgroundStyle)style {
    [super setBackgroundStyle:style];
    [buttonCell setBackgroundStyle:style];
}

#pragma mark Drawing and highlighting

- (NSSize)cellSize {
    [buttonCell setImage:[self numberOfItems] ? [[self itemAtIndex:0] image] : nil];
	NSSize size = [buttonCell cellSize];
	if ([self controlSize] != NSRegularControlSize) {
        size = NSMakeSize(round(0.75 * size.width), round(0.75 * size.height));
        if ([self arrowPosition] != NSPopUpNoArrow)
            size.width += 5.0;
	} else if ([self arrowPosition] != NSPopUpNoArrow) {
        size.width += 7.0;
    }
    return size;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView{
    NSRect arrowRect = NSZeroRect, rect = cellFrame;
    CGFloat arrowWidth = [self controlSize] == NSRegularControlSize ? 6.0 : 4.0;
    
   if ([self arrowPosition] != NSPopUpNoArrow)
        NSDivideRect(rect, &arrowRect, &rect, arrowWidth + 1.0, NSMaxXEdge);
    
    [buttonCell setImage:[self numberOfItems] ? [[self itemAtIndex:0] image] : nil];
    [buttonCell drawWithFrame:rect inView:controlView];
    
    if (NSIsEmptyRect(arrowRect) == NO) {
        NSBezierPath *path = [NSBezierPath bezierPath];
        NSPoint offset = NSMakePoint(NSMinX(arrowRect), NSMinY(arrowRect));
        char s = 1;
        if ([controlView isFlipped]) {
            offset.y += NSHeight(arrowRect);
            s = -1;
        }
        [path moveToPoint:NSMakePoint(offset.x + 0.5, offset.y + s * arrowWidth)];
        [path relativeLineToPoint:NSMakePoint(arrowWidth, 0.0)];
        [path relativeLineToPoint:NSMakePoint(-0.5 * arrowWidth, -s * (arrowWidth - 1.0))];
        [path closePath];
        [NSGraphicsContext saveGraphicsState];
        if ([self showsFirstResponder])
            NSSetFocusRingStyle(NSFocusRingBelow);
        [[NSColor colorWithCalibratedWhite:0.0 alpha:[self isEnabled] ? 0.75 : 0.375] setFill];
        [path fill];
        [NSGraphicsContext restoreGraphicsState];
    }
}

- (void)highlight:(BOOL)flag withFrame:(NSRect)cellFrame inView:(NSView *)controlView{
	[buttonCell highlight:flag withFrame:cellFrame inView:controlView];
	[super highlight:flag withFrame:cellFrame inView:controlView];
}

@end

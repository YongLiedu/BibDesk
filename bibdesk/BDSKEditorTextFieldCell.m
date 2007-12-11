//
//  BDSKEditorTextFieldCell.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/11/07.
/*
 This software is Copyright (c) 2007
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

#import "BDSKEditorTextFieldCell.h"

#define BUTTON_SIZE     NSMakeSize(15.0, 15.0)
#define BUTTON_MARGIN   2.0

@implementation BDSKEditorTextFieldCell

- (id)initTextCell:(NSString *)aString {
    if (self = [super initTextCell:aString]) {
        buttonHighlighted = NO;
        hasButton = NO;
        buttonTarget = nil;
        buttonAction = NULL;
        [self setBezeled:YES];
        [self setDrawsBackground:YES];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        buttonHighlighted = NO;
        hasButton = NO;
        buttonTarget = nil;
        buttonAction = NULL;
        [self setBezeled:YES];
        [self setDrawsBackground:YES];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    BDSKEditorTextFieldCell *copy = [super copyWithZone:zone];
    copy->buttonHighlighted = buttonHighlighted;
    copy->hasButton = hasButton;
    copy->buttonTarget = buttonTarget;
    copy->buttonAction = buttonAction;
    return copy;
}

- (NSUInteger)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView
{
    NSUInteger hit = [super hitTestForEvent:event inRect:cellFrame ofView:controlView];
    // super returns 0 for button clicks, so -[NSTableView mouseDown:] doesn't track the cell
    NSRect buttonRect = [self buttonRectForBounds:cellFrame];
    NSPoint mouseLoc = [controlView convertPoint:[event locationInWindow] fromView:nil];
    if (NSMouseInRect(mouseLoc, buttonRect, [controlView isFlipped]))
        hit = NSCellHitContentArea | NSCellHitTrackableArea;
    return hit;
}

- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)untilMouseUp {
    NSRect buttonRect = [self buttonRectForBounds:cellFrame];
    NSPoint mouseLoc = [controlView convertPoint:[theEvent locationInWindow] fromView:nil];
    if (hasButton && NSMouseInRect(mouseLoc, buttonRect, [controlView isFlipped])) {
        [self setButtonHighlighted:YES];
        [controlView setNeedsDisplayInRect:buttonRect];
		BOOL keepOn = YES;
		BOOL isInside = YES;
		while (keepOn) {
			theEvent = [[controlView window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
			mouseLoc = [controlView convertPoint:[theEvent locationInWindow] fromView:nil];
			isInside = NSMouseInRect(mouseLoc, buttonRect, [controlView isFlipped]);
			switch ([theEvent type]) {
				case NSLeftMouseDragged:
					if (isInside != buttonHighlighted) {
                        [self setButtonHighlighted:isInside];
                        [controlView setNeedsDisplayInRect:buttonRect];
					}
                    break;
				case NSLeftMouseUp:
					if (isInside) {
                        [(NSControl *)controlView sendAction:buttonAction to:buttonTarget];
                        [self setButtonHighlighted:NO];
                        [controlView setNeedsDisplayInRect:buttonRect];
                    }
					keepOn = NO;
					break;
				default:
					// Ignore any other kind of event.
					break;
			}
		}
        return YES;
    } else 
        return [super trackMouse:theEvent inRect:cellFrame ofView:controlView untilMouseUp:untilMouseUp];
}

- (BOOL)isButtonHighlighted {
    return buttonHighlighted;
}

- (void)setButtonHighlighted:(BOOL)highlighted {
    if (buttonHighlighted != highlighted) {
        buttonHighlighted = highlighted;
    }
}

- (BOOL)hasButton {
    return hasButton;
}

- (void)setHasButton:(BOOL)flag {
    if (hasButton != flag) {
        hasButton = flag;
    }
}

- (id)buttonTarget {
    return buttonTarget;
}

- (void)setButtonTarget:(id)target {
    buttonTarget = target;
}

- (SEL)buttonAction {
    return buttonAction;
}

- (void)setButtonAction:(SEL)selector {
    buttonAction = selector;
}

- (NSRect)buttonRectForBounds:(NSRect)theRect {
	NSRect buttonRect = NSZeroRect;
    
	if (hasButton) {
        NSSize size = BUTTON_SIZE;
        buttonRect.origin.x = NSMaxX(theRect) - size.width - BUTTON_MARGIN;
        buttonRect.origin.y = ceilf(NSMidY(theRect) - 0.5 * size.height);
        buttonRect.size = size;
	}
    return buttonRect;
}

- (NSRect)drawingRectForBounds:(NSRect)theRect {
	if (hasButton) {
        NSRect ignored;
        NSSize size = BUTTON_SIZE;
        NSDivideRect(theRect, &ignored, &theRect, size.width + BUTTON_MARGIN, NSMaxXEdge);
    }
    return [super drawingRectForBounds:theRect];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [super drawInteriorWithFrame:cellFrame inView:controlView];
	
    if (hasButton) {
        NSImage *buttonImage = [NSImage imageNamed:buttonHighlighted ? @"ArrowImage_Pressed" : @"ArrowImage"];
        NSRect buttonRect = [self buttonRectForBounds:cellFrame];
        [buttonImage drawFlippedInRect:buttonRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    }
}

- (NSText *)setUpFieldEditorAttributes:(NSText *)textObj {
    textObj = [super setUpFieldEditorAttributes:textObj];
    if ([self drawsBackground])
        [textObj setBackgroundColor:[NSColor textBackgroundColor]];
    return textObj;
}

@end

#define LABEL_EFFECTIVE_HEIGHT 20.0

@implementation BDSKLabelTextFieldCell

// make sure it uses black text on Leopard when the row is selected
- (NSBackgroundStyle)backgroundStyle { return NSBackgroundStyleLight; }

// NSTextFieldCell seems to align the text at the top in flipped views such as NSTableView, which is weird
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    if (NSHeight(cellFrame) > LABEL_EFFECTIVE_HEIGHT) {
        if ([controlView isFlipped])
            cellFrame.origin.y += NSHeight(cellFrame) - LABEL_EFFECTIVE_HEIGHT;
        cellFrame.size.height = LABEL_EFFECTIVE_HEIGHT;
    }
    [super drawInteriorWithFrame:cellFrame inView:controlView];
}

@end

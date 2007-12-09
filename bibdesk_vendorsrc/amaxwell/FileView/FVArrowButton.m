//
//  FVArrowButton.m
//  FileViewTest
//
//  Created by Adam Maxwell on 09/21/07.
/*
 This software is Copyright (c) 2007
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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

#import "FVArrowButton.h"

static NSBezierPath *rightArrowBezierPathWithSize(NSSize size);

@interface FVArrowButtonCell : NSButtonCell {
    NSUInteger arrowDirection;
}
- (NSUInteger)arrowDirection;
- (void)setArrowDirection:(NSUInteger)newArrowDirection;
@end

@implementation FVArrowButtonCell

- (id)initTextCell:(NSString *)aString {
    if (self = [super initTextCell:@""]) {
        [self setHighlightsBy:NSNoCellMask];
        [self setImagePosition:NSImageOnly];
        [self setBezelStyle:NSRegularSquareBezelStyle];
        [self setBordered:NO];
    }
    return self;
}

- (NSUInteger)arrowDirection;
{
    return arrowDirection;
}

- (void)setArrowDirection:(NSUInteger)newArrowDirection;
{
    arrowDirection = newArrowDirection;
}

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)controlView;
{
    // NSCell's highlight drawing does not look correct against a dark background, so override it completely
    NSColor *bgColor = nil;
    NSColor *arrowColor = nil;
    if ([self isHighlighted]) {
        bgColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.5];
        arrowColor = [NSColor colorWithCalibratedWhite:0.7 alpha:0.8];
    } else if ([self isEnabled]) {
        bgColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.7];
        arrowColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.9];
    } else {
        bgColor = [NSColor colorWithCalibratedWhite:0.3 alpha:0.5];
        arrowColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.9];
    }
    
    [bgColor setFill];
    [[NSBezierPath bezierPathWithOvalInRect:frame] fill];
    
    CGContextRef ctxt = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextTranslateCTM(ctxt, NSMinX(frame), NSMinY(frame));
    if (FVArrowLeft == arrowDirection) {
        CGContextTranslateCTM(ctxt, NSWidth(frame), 0);
        CGContextScaleCTM(ctxt, -1, 1);
    }
    [arrowColor setFill];
    [rightArrowBezierPathWithSize(frame.size) fill];
}

@end

@implementation FVArrowButton

+ (Class)cellClass { return [FVArrowButtonCell class]; }

- (id)initWithFrame:(NSRect)frameRect direction:(NSUInteger)arrowDirection;
{
    if (self = [super initWithFrame:frameRect]) {
        [[self cell] setArrowDirection:arrowDirection];
    }
    return self;
}

- (id)initWithFrame:(NSRect)frameRect {
    return [self initWithFrame:frameRect direction:FVArrowRight];
}

// Modify mouseDown: behavior slightly.  Wince this control is superimposed on another pseudo-control (the FileView), we want to avoid passing some events to the next responder.
- (void)mouseDown:(NSEvent *)event
{
    // convert double-clicks to a single-click event, so you can click the button rapidly without passing a double-click to the FileView
    if ([event clickCount] > 1) {
        NSEvent *newEvent;
        newEvent = [NSEvent mouseEventWithType:[event type]
                                      location:[event locationInWindow]
                                 modifierFlags:[event modifierFlags]
                                     timestamp:[event timestamp]
                                  windowNumber:[event windowNumber]
                                       context:[event context]
                                   eventNumber:([event eventNumber] + 1)
                                    clickCount:1
                                      pressure:[event pressure]]; 
        event = newEvent;
    }
    
    // swallow clicks when disabled to avoid changing FileView selection
    if ([self isEnabled])
        [super mouseDown:event];
}

@end

static NSBezierPath *rightArrowBezierPathWithSize(NSSize size)
{
    CGFloat w = size.width, h = size.height;
    NSBezierPath *arrow = [NSBezierPath bezierPath];
    [arrow moveToPoint:NSMakePoint(3.0/16.0*w, 6.0/16.0*h)];
    [arrow lineToPoint:NSMakePoint(3.0/16.0*w, 10.0/16.0*h)];
    [arrow lineToPoint:NSMakePoint(8.0/16.0*w, 10.0/16.0*h)];
    
    // top point of triangle
    [arrow lineToPoint:NSMakePoint(8.0/16.0*w, 13.0/16.0*h)];
    // right point of triangle
    [arrow lineToPoint:NSMakePoint(14.0/16.0*w, 8.0/16.0*h)];
    // bottom point of triangle
    [arrow lineToPoint:NSMakePoint(8.0/16.0*w, 3.0/16.0*h)];
    
    [arrow lineToPoint:NSMakePoint(8.0/16.0*w, 6.0/16.0*h)];
    [arrow closePath];
    return arrow;
}

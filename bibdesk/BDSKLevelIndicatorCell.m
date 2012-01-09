//
//  BDSKLevelIndicatorCell.m
//  Bibdesk
//
//  Created by Adam Maxwell on 04/05/07.
/*
 This software is Copyright (c) 2007-2012
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

#import "BDSKLevelIndicatorCell.h"
#import "NSGeometry_BDSKExtensions.h"

/* Subclass of NSLevelIndicatorCell.  The default relevancy cell draws bars the entire vertical height of the table row, which looks bad.  Using setControlSize: seems to have no effect.
*/

@implementation BDSKLevelIndicatorCell

- (id)initWithLevelIndicatorStyle:(NSLevelIndicatorStyle)levelIndicatorStyle;
{
    self = [super initWithLevelIndicatorStyle:levelIndicatorStyle];
    maxHeight = 0.8 * [self cellSize].height;
    return self;
}

- (id)copyWithZone:(NSZone *)aZone
{
    BDSKLevelIndicatorCell *obj = [super copyWithZone:aZone];
    [obj setMaxHeight:maxHeight];
    return obj;
}

- (NSSize)cellSizeForBounds:(NSRect)aRect {
    // this is used for column auto-resizing, and NSLevelIndicatorCell seems to return an insanely large size
    NSSize cellSize = [super cellSizeForBounds:aRect];
    cellSize.width = fmin(100.0, cellSize.width);
    return cellSize;
}

- (void)setMaxHeight:(CGFloat)h;
{
    maxHeight = h;
}

- (CGFloat)indicatorHeight { return maxHeight; }

// DigitalColor Meter indicates 0.7 and 0.5 are the approximate values for a deselected level indicator cell (relevancy mode).  This looks really bad when selected in a gradient tableview, though, particularly when the table doesn't have focus.
#define WIDTH 2
#define HEIGHT 10

- (CGLayerRef)darkRelevancyLayer
{
    static CGLayerRef layer = NULL;
    if (NULL == layer) {
        // height is irrelevant; it will be scaled when drawn
        NSRect r = NSMakeRect(0, 0, WIDTH, HEIGHT);
        layer = CGLayerCreateWithContext([[NSGraphicsContext currentContext] graphicsPort], CGSizeMake(WIDTH, HEIGHT), NULL);
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:CGLayerGetContext(layer) flipped:NO]];
        [[NSColor clearColor] setFill];
        NSRectFillUsingOperation(r, NSCompositeCopy);
        [[NSColor colorWithCalibratedWhite:0.7 alpha:1.0] setFill];
        NSRectFill(NSMakeRect(0, 0, WIDTH/2, HEIGHT));
        [[NSColor colorWithCalibratedWhite:0.5 alpha:1.0] setFill];
        NSRectFill(NSMakeRect(WIDTH/2, 0, WIDTH/2, HEIGHT));
        [NSGraphicsContext restoreGraphicsState];
    }
    return layer;
}

- (CGLayerRef)lightRelevancyLayer
{
    static CGLayerRef layer = NULL;
    if (NULL == layer) {
        // height is irrelevant; it will be scaled when drawn
        NSRect r = NSMakeRect(0, 0, WIDTH, HEIGHT);
        layer = CGLayerCreateWithContext([[NSGraphicsContext currentContext] graphicsPort], CGSizeMake(WIDTH, HEIGHT), NULL);
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:CGLayerGetContext(layer) flipped:NO]];
        [[NSColor clearColor] setFill];
        NSRectFillUsingOperation(r, NSCompositeCopy);
        [[NSColor colorWithCalibratedWhite:0.7 alpha:1.0] setFill];
        NSRectFill(NSMakeRect(0, 0, WIDTH/2, HEIGHT));
        [[NSColor colorWithCalibratedWhite:0.9 alpha:1.0] setFill];
        NSRectFill(NSMakeRect(WIDTH/2, 0, WIDTH/2, HEIGHT));
        [NSGraphicsContext restoreGraphicsState];
    }
    return layer;    
}

- (void)setDoubleValue:(double)v
{
    NSParameterAssert(isfinite(v));
    [super setDoubleValue:v];
}

/*
 This method and -drawingRectForBounds: are never called as of 10.4.8 rdar://problem/4998206
 
 - (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
 {
     log_method();
     NSRect r = BDSKCenterRectVertically(cellFrame, [self indicatorHeight], [controlView isFlipped]);
     [super drawInteriorWithFrame:r inView:controlView];
 }
 
 The necessary override point is this method, with variants for other styles.
 Since we now do all drawing manually, this is no longer necessary unless we
 want to use other indicator styles.
 - (void)_drawRelevancyWithFrame:(NSRect)cellFrame inView:(NSView *)controlView 
 */

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    NSRect r = BDSKCenterRectVertically(cellFrame, [self indicatorHeight], [controlView isFlipped]);
    // For some reason, the cell's vertical origin is still off by a point in a tableview, and none of the ...rectForBounds: methods seem to improve it.  Hardcoding a 1 point offset seems lame, but it works.
    if ([controlView isFlipped])
        r.origin.y -= 1;
    else
        r.origin.y += 1;
    
    r = [controlView centerScanRect:r];
    
    // Could happen if the search scores have issues?  See bug #1932040.
    double ratio = [self doubleValue] / [self maxValue];
    if (ratio > 1 || isfinite(ratio) == false) {
        NSLog(@"BDSKLevelIndicatorCell: %.3f / %.3f = %.3f, clipping to 1.0", [self doubleValue], [self maxValue], ratio);
        ratio = 1.0;
    }
    
    NSUInteger i, iMax = floor(ratio * (NSWidth(r) / 2));
    CGLayerRef toDraw;
    
    NSBackgroundStyle style = [self backgroundStyle];
    if (NSBackgroundStyleLight == style)
        toDraw = [self darkRelevancyLayer];
    else
        toDraw = [self lightRelevancyLayer];
    
    CGContextRef ctxt = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState(ctxt);
    
    // clip since doubleValue may exceed maxValue
    CGContextClipToRect(ctxt, NSRectToCGRect(cellFrame));
    
    NSRect drawRect = r;
    drawRect.size.width = 2;
    CGContextSetBlendMode(ctxt, kCGBlendModeNormal);
    for (i = 0; i < iMax; i++) {
        drawRect.origin.x += 2;
        CGContextDrawLayerInRect(ctxt, NSRectToCGRect(drawRect), toDraw);
    }
    CGContextRestoreGState(ctxt);
}

@end

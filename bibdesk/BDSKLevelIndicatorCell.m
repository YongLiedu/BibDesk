//
//  BDSKLevelIndicatorCell.m
//  Bibdesk
//
//  Created by Adam Maxwell on 04/05/07.
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

#import "BDSKLevelIndicatorCell.h"
#import "NSGeometry_BDSKExtensions.h"

/* Subclass of NSLevelIndicatorCell.  The default relevancy cell draws bars the entire vertical height of the table row, which looks bad.  Using setControlSize: seems to have no effect.
*/
@interface NSLevelIndicatorCell (BDSKPrivateOverrideBecauseApplesSubclassingIsBroken)
- (void)_drawRelevancyWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
@end

@implementation BDSKLevelIndicatorCell

- (id)initWithLevelIndicatorStyle:(NSLevelIndicatorStyle)levelIndicatorStyle;
{
    self = [super initWithLevelIndicatorStyle:levelIndicatorStyle];
    maxHeight = 0.8 * [self cellSize].height;
    return self;
}

- (id)copyWithZone:(NSZone *)aZone
{
    id obj = [super copyWithZone:aZone];
    [obj setMaxHeight:maxHeight];
    return obj;
}

- (void)setMaxHeight:(float)h;
{
    maxHeight = h;
}

- (float)indicatorHeight { return maxHeight; }

// DigitalColor Meter indicates 0.7 and 0.5 are the approximate values for a deselected level indicator cell (relevancy mode).  This looks really bad when selected in a gradient tableview, though, particularly when the table doesn't have focus.
- (NSImage *)deselectedRelevancyImage
{
    static NSImage *image = nil;
    if (nil == image) {
        NSRect r = NSMakeRect(0, 0, 2, [self indicatorHeight]);
        image = [[NSImage alloc] initWithSize:r.size];
        [image lockFocus];
        [image setBackgroundColor:[NSColor clearColor]];
        [[NSColor colorWithCalibratedWhite:0.7 alpha:1.0] setFill];
        NSRectFill(NSMakeRect(0, 0, 1, [self indicatorHeight]));
        [[NSColor colorWithCalibratedWhite:0.5 alpha:1.0] setFill];
        NSRectFill(NSMakeRect(1, 0, 1, [self indicatorHeight]));
        [image unlockFocus];
    }
    return image;
}

- (NSImage *)selectedRelevancyImage
{
    static NSImage *image = nil;
    if (nil == image) {
        NSRect r = NSMakeRect(0, 0, 2, [self indicatorHeight]);
        image = [[NSImage alloc] initWithSize:r.size];
        [image lockFocus];
        [image setBackgroundColor:[NSColor clearColor]];
        [[NSColor colorWithCalibratedWhite:0.7 alpha:1.0] setFill];
        NSRectFill(NSMakeRect(0, 0, 1, [self indicatorHeight]));
        [[NSColor colorWithCalibratedWhite:0.9 alpha:1.0] setFill];
        NSRectFill(NSMakeRect(1, 0, 1, [self indicatorHeight]));
        [image unlockFocus];
    }
    return image;    
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
    unsigned i, iMax = floor([self doubleValue] / [self maxValue] * (NSWidth(r) / 2));
    NSImage *toDraw;
    
    // @@ fixme; better way to do this on 10.5
    if ([self isHighlighted])
        toDraw = [self selectedRelevancyImage];
    else
        toDraw = [self deselectedRelevancyImage];
    
    CGContextRef ctxt = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState(ctxt);
    if ([controlView isFlipped]) {
        CGContextTranslateCTM(ctxt, 0, NSMaxY(r));
        CGContextScaleCTM(ctxt, 1, -1);
        r.origin.y = 0;
    }
    
    NSRect drawRect = r;
    drawRect.size.width = 2;
    for (i = 0; i < iMax; i++) {
        drawRect.origin.x += 2;
        [toDraw drawInRect:drawRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    }
    CGContextRestoreGState(ctxt);
}

@end

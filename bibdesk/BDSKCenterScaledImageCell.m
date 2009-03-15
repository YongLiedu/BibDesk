//
//  BDSKCenterScaledImageCell.m
//  Bibdesk
//
//  Created by Adam Maxwell on 02/21/07.
/*
 This software is Copyright (c) 2007-2009
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

#import "BDSKCenterScaledImageCell.h"
#import "NSGeometry_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"

@implementation BDSKCenterScaledImageCell

// limitation: this assumes you always want a proportionally scaled, centered image (hence the class name)
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
{
    NSImage *img = [self image];
    
    if (nil != img) {
        
        NSRect srcRect = NSZeroRect;
        srcRect.size = [img size];
        
        NSRect drawFrame = [self drawingRectForBounds:cellFrame];
                
        // NSImage will use the largest rep if it doesn't find an exact size match; we can improve on that by choosing the next larger one with respect to our drawing rect, and scaling it down.
        NSBitmapImageRep *rep = [img bestImageRepForSize:drawFrame.size device:nil];
        
        // draw the image rep directly to avoid creating a new NSImage and adding the rep to it
        if (rep) {
            
            srcRect.size = [rep size];
            float ratio = fminf(NSWidth(drawFrame) / srcRect.size.width, NSHeight(drawFrame) / srcRect.size.height);
            drawFrame.size.width = ratio * srcRect.size.width;
            drawFrame.size.height = ratio * srcRect.size.height;
            
            drawFrame = BDSKCenterRect(drawFrame, drawFrame.size, [controlView isFlipped]);
            
            CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
            CGContextSaveGState(context);
            CGContextClipToRect(context, NSRectToCGRect(drawFrame));
            CGContextSetAllowsAntialiasing(context, true);
            CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
            
            // draw into a new layer so we preserve the background of the tableview
            CGContextBeginTransparencyLayer(context, NULL);
            
            if ([controlView isFlipped]) {
                CGContextTranslateCTM(context, 0, NSMaxY(drawFrame));
                CGContextScaleCTM(context, 1, -1);
                drawFrame.origin.y = 0;
                [rep drawInRect:drawFrame];
            } else {
                [rep drawInRect:drawFrame];
            }
            
            CGContextEndTransparencyLayer(context);
            CGContextRestoreGState(context);
            
        } else {
            
            float ratio = MIN(NSWidth(drawFrame) / srcRect.size.width, NSHeight(drawFrame) / srcRect.size.height);
            drawFrame.size.width = ratio * srcRect.size.width;
            drawFrame.size.height = ratio * srcRect.size.height;
            
            drawFrame = BDSKCenterRect(drawFrame, drawFrame.size, [controlView isFlipped]);
            
            NSGraphicsContext *ctxt = [NSGraphicsContext currentContext];
            [ctxt saveGraphicsState];
            
            // this is the critical part that NSImageCell doesn't do
            [ctxt setImageInterpolation:NSImageInterpolationHigh];
            
            [img drawFlipped:[controlView isFlipped] inRect:drawFrame fromRect:srcRect operation:NSCompositeSourceOver fraction:1.0];
            
            [ctxt restoreGraphicsState];
        }
        
    } else {
        [super drawInteriorWithFrame:cellFrame inView:controlView];
    }
}

@end

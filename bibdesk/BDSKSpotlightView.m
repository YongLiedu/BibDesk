//
//  BDSKSpotlightView.m
//  Bibdesk
//
//  Created by Adam Maxwell on 05/04/06.
/*
 This software is Copyright (c) 2006-2011
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

#import "BDSKSpotlightView.h"
#import <QuartzCore/QuartzCore.h>

#define MASK_ALPHA 0.3
#define CIRCLE_FACTOR 1.0
#define MAXIMUM_BLUR 10U

@implementation BDSKSpotlightView;

- (id)initWithFrame:(NSRect)frameRect flipped:(BOOL)isFlipped {
    if (self = [super initWithFrame:frameRect]) {
        flipped = isFlipped;
    }
    return self;
}

- (id)initWithFrame:(NSRect)frameRect {
    return [self initWithFrame:frameRect flipped:NO];
}

- (id)initFlipped:(BOOL)isFlipped {
    return [self initWithFrame:NSZeroRect flipped:isFlipped];
}

- (id)delegate {
    return delegate;
}

- (void)setDelegate:(id)newDelegate {
    NSParameterAssert(newDelegate == nil || [newDelegate respondsToSelector:@selector(spotlightViewCircleRects:)]);
    delegate = newDelegate;
}

- (BOOL)isFlipped {
    return flipped;
}

- (void)drawRect:(NSRect)aRect {
    NSArray *highlightCircleRects = [delegate spotlightViewCircleRects:self];
    
    if (highlightCircleRects == nil) {
        [[NSColor clearColor] setFill];
        NSRectFill(aRect);
        return;
    }
    
    CGFloat blurPadding = MAXIMUM_BLUR * 2.0;
    NSRect bounds = [self bounds];

    // we make the bounds larger so the blurred edges will fall outside the view
    NSRect maskRect = NSInsetRect(bounds, -blurPadding, -blurPadding);
    NSBezierPath *path = [NSBezierPath bezierPathWithRect:maskRect];
    
    // this causes the paths we append to act as holes in the overall path
    [path setWindingRule:NSEvenOddWindingRule];
    
    for (NSValue *rectValue in highlightCircleRects) {
        NSRect rect = [rectValue rectValue];
        CGFloat diameter = CIRCLE_FACTOR * fmax(NSHeight(rect), NSWidth(rect));
        [path appendBezierPathWithOvalInRect:NSInsetRect(rect, (NSWidth(rect) - diameter) / 2.0, (NSHeight(rect) - diameter) / 2.0)];
    }
    
    // Drawing to an NSImage and then creating the CIImage with -[NSImage TIFFRepresentation] gives an incorrect CIImage extent when display scaling is turned on, probably due to NSCachedImageRep.  We also have to pass bytesPerRow:0 when scaling is on, which seems like a bug.
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL 
                                                                         pixelsWide:NSWidth(maskRect) 
                                                                         pixelsHigh:NSHeight(maskRect) 
                                                                      bitsPerSample:8 
                                                                    samplesPerPixel:4
                                                                           hasAlpha:YES 
                                                                           isPlanar:NO 
                                                                     colorSpaceName:NSCalibratedRGBColorSpace 
                                                                       bitmapFormat:0 
                                                                        bytesPerRow:0 /*(4 * NSWidth(maskRect)) */
                                                                       bitsPerPixel:32];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep]];
    // we need to shift because canvas of the image is at positive values
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform translateXBy:blurPadding yBy:blurPadding];
    [transform concat];
    // fill the entire space with clear
    [[NSColor clearColor] setFill];
    NSRectFill(maskRect);
    // draw the mask
    [[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:MASK_ALPHA] setFill];
    [path fill];
    [NSGraphicsContext restoreGraphicsState];
    
    // apply the blur filter to soften the edges of the circles
    CIFilter *gaussianBlurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    // sys prefs uses fuzzier circles for more matches; filter range 0 -- 100, values 0 -- 10 are reasonable?
    [gaussianBlurFilter setValue:[NSNumber numberWithDouble:MIN([highlightCircleRects count], MAXIMUM_BLUR)] forKey:@"inputRadius"];
    // see NSCIImageRep.h for this and other useful methods that aren't documented
    [gaussianBlurFilter setValue:[[[CIImage alloc] initWithBitmapImageRep:imageRep] autorelease] forKey:@"inputImage"];
    [imageRep release];
    
    // crop to the original bounds size; this crops all sides of the image
    CIFilter *cropFilter = [CIFilter filterWithName:@"CICrop"];
    [cropFilter setValue:[CIVector vectorWithX:blurPadding Y:blurPadding Z:NSWidth(bounds) W:NSHeight(bounds)] forKey:@"inputRectangle"];
    [cropFilter setValue:[gaussianBlurFilter valueForKey:@"outputImage"] forKey:@"inputImage"];
    
    CIImage *image = [cropFilter valueForKey:@"outputImage"];
    [image drawInRect:[self bounds] fromRect:NSRectFromCGRect([image extent]) operation:NSCompositeCopy fraction:1.0];
}

@end
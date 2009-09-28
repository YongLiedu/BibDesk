//
//  CIImage_BDSKExtensions.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 5/7/06.
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

#import "CIImage_BDSKExtensions.h"

@implementation CIImage (BDSKExtensions)

+ (CIImage *)imageWithConstantColor:(CIColor *)color;
{
    CIFilter *colorFilter = [CIFilter filterWithName:@"CIConstantColorGenerator"];    
    
    [colorFilter setValue:color forKey:@"inputColor"];
    
    return [colorFilter valueForKey:@"outputImage"];
}

+ (CIImage *)imageInRect:(CGRect)aRect withLinearGradientFromPoint:(CGPoint)startPoint toPoint:(CGPoint)endPoint fromColor:(CIColor *)startColor toColor:(CIColor *)endColor;
{
    CIFilter *linearFilter = [CIFilter filterWithName:@"CILinearGradient"];    
    
    [linearFilter setValue:startColor forKey:@"inputColor0"];
    [linearFilter setValue:endColor forKey:@"inputColor1"];
    
    [linearFilter setValue:[CIVector vectorWithX:startPoint.x Y:startPoint.y] forKey:@"inputPoint0"];
    [linearFilter setValue:[CIVector vectorWithX:endPoint.x Y:endPoint.y] forKey:@"inputPoint1"];
    
    return [linearFilter valueForKey:@"outputImage"];
}

+ (CIImage *)imageInRect:(CGRect)aRect withHorizontalGradientFromColor:(CIColor *)startColor toColor:(CIColor *)endColor;
{
    CGPoint startPoint = aRect.origin;
    CGPoint endPoint = startPoint;
    endPoint.x += CGRectGetWidth(aRect);
    return [self imageInRect:aRect withLinearGradientFromPoint:startPoint toPoint:endPoint fromColor:startColor toColor:endColor];
}

+ (CIImage *)imageInRect:(CGRect)aRect withVerticalGradientFromColor:(CIColor *)startColor toColor:(CIColor *)endColor;
{
    CGPoint startPoint = aRect.origin;
    CGPoint endPoint = startPoint;
    endPoint.y += CGRectGetHeight(aRect);
    return [self imageInRect:aRect withLinearGradientFromPoint:startPoint toPoint:endPoint fromColor:startColor toColor:endColor];
}

+ (CIImage *)imageWithGaussianGradientWithCenter:(CGPoint)center radius:(CGFloat)radius fromColor:(CIColor *)startColor toColor:(CIColor *)endColor;
{
    CIFilter *gaussianFilter = [CIFilter filterWithName:@"CIGaussianGradient"];    
    
    [gaussianFilter setValue:startColor forKey:@"inputColor0"];
    [gaussianFilter setValue:endColor forKey:@"inputColor1"];
    
    [gaussianFilter setValue:[NSNumber numberWithFloat:radius] forKey:@"inputRadius"];
    [gaussianFilter setValue:[CIVector vectorWithX:center.x Y:center.y] forKey:@"inputCenter"];
    
    return [gaussianFilter valueForKey:@"outputImage"];
}

+ (CIColor *)colorWithWhiteOne;
{
    static CIColor *color = nil;
    if (nil == color)
        color = [[CIColor colorWithWhite:1.0] retain];
    return color;
}

+ (CIColor *)colorWithWhiteZero;
{
    static CIColor *color = nil;
    if (nil == color)
        color = [[CIColor colorWithWhite:0.0] retain];
    return color;    
}

+ (CIImage *)imageInRect:(CGRect)aRect withHorizontalGradientFromColor:(CIColor *)fgStartColor toColor:(CIColor *)fgEndColor blendedAtTop:(BOOL)top ofVerticalGradientFromColor:(CIColor *)bgStartColor toColor:(CIColor *)bgEndColor;
{
    CGFloat radius = 0.5f * CGRectGetWidth(aRect);
    CGPoint center = CGPointMake(CGRectGetMidX(aRect), top ? CGRectGetMaxY(aRect) : CGRectGetMinY(aRect));
    
    CIImage *foreground = [self imageInRect:aRect withHorizontalGradientFromColor:fgStartColor toColor:fgEndColor];
    CIImage *background = [self imageInRect:aRect withVerticalGradientFromColor:bgStartColor toColor:bgEndColor];
    CIImage *mask = [self imageWithGaussianGradientWithCenter:center radius:radius fromColor:[self colorWithWhiteOne] toColor:[self colorWithWhiteZero]];
    
    return [foreground blendedImageWithBackground:background usingMask:mask];
}

+ (CIImage *)imageInRect:(CGRect)aRect withVerticalGradientFromColor:(CIColor *)fgStartColor toColor:(CIColor *)fgEndColor blendedAtRight:(BOOL)right ofHorizontalGradientFromColor:(CIColor *)bgStartColor toColor:(CIColor *)bgEndColor;
{
    CGFloat radius = 0.5f * CGRectGetHeight(aRect);
    CGPoint center = CGPointMake(right ? CGRectGetMaxX(aRect) : CGRectGetMinX(aRect), CGRectGetMidY(aRect));
    
    CIImage *foreground = [self imageInRect:aRect withVerticalGradientFromColor:fgStartColor toColor:fgEndColor];
    CIImage *background = [self imageInRect:aRect withHorizontalGradientFromColor:bgStartColor toColor:bgEndColor];
    CIImage *mask = [self imageWithGaussianGradientWithCenter:center radius:radius fromColor:[self colorWithWhiteOne] toColor:[self colorWithWhiteZero]];
    
    return [foreground blendedImageWithBackground:background usingMask:mask];
}

+ (CIImage *)imageInRect:(CGRect)aRect withColor:(CIColor *)fgColor blendedAtRight:(BOOL)right ofVerticalGradientFromColor:(CIColor *)bgStartColor toColor:(CIColor *)bgEndColor;
{
    CIColor *start, *end;
    if (right) {
        start = [self colorWithWhiteOne];
        end = [self colorWithWhiteZero];
    } else {
        start = [self colorWithWhiteZero];
        end = [self colorWithWhiteOne];
    }
    
    CIImage *foreground = [self imageWithConstantColor:fgColor];
    CIImage *background = [self imageInRect:aRect withVerticalGradientFromColor:bgStartColor toColor:bgEndColor];
    CIImage *mask = [self imageInRect:aRect withHorizontalGradientFromColor:start toColor:end];
    
    return [foreground blendedImageWithBackground:background usingMask:mask];
}

+ (CIImage *)imageInRect:(CGRect)aRect withColor:(CIColor *)fgColor blendedAtTop:(BOOL)top ofHorizontalGradientFromColor:(CIColor *)bgStartColor toColor:(CIColor *)bgEndColor;
{
    CIColor *start, *end;
    if (top) {
        start = [self colorWithWhiteOne];
        end = [self colorWithWhiteZero];
    } else {
        start = [self colorWithWhiteZero];
        end = [self colorWithWhiteOne];
    }
    
    CIImage *foreground = [self imageWithConstantColor:fgColor];
    CIImage *background = [self imageInRect:aRect withHorizontalGradientFromColor:bgStartColor toColor:bgEndColor];
    CIImage *mask = [self imageInRect:aRect withVerticalGradientFromColor:start toColor:end];
    
    return [foreground blendedImageWithBackground:background usingMask:mask];
}

- (CIImage *)blendedImageWithBackground:(CIImage *)background usingMask:(CIImage *)mask;
{
    CIFilter *blendFilter = [CIFilter filterWithName:@"CIBlendWithMask"];    
    
    [blendFilter setValue:self forKey:@"inputImage"];
    [blendFilter setValue:background forKey:@"inputBackgroundImage"];
    [blendFilter setValue:mask forKey:@"inputMaskImage"];
    
    return [blendFilter valueForKey:@"outputImage"];
}

- (CIImage *)blurredImageWithBlurRadius:(CGFloat)radius;
{
    CIFilter *gaussianBlurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];    
    
    [gaussianBlurFilter setValue:[NSNumber numberWithFloat:radius] forKey:@"inputRadius"];
    [gaussianBlurFilter setValue:self forKey:@"inputImage"];
    
    return [gaussianBlurFilter valueForKey:@"outputImage"];
}

- (CIImage *)croppedImageWithRect:(CGRect)aRect;
{
    CIFilter *transformFilter = [CIFilter filterWithName:@"CIAffineTransform"];
    CIFilter *cropFilter = [CIFilter filterWithName:@"CICrop"];
    CIImage *image = self;
    
    if (CGPointEqualToPoint(aRect.origin, CGPointZero) == NO) {
        // shift the cropped rect to the origin
        NSAffineTransform *transform = [NSAffineTransform transform];
        [transform translateXBy:-CGRectGetMinX(aRect) yBy:-CGRectGetMinY(aRect)];
        [transformFilter setValue:transform forKey:@"inputTransform"];
        [transformFilter setValue:self forKey:@"inputImage"];
        
        image = [transformFilter valueForKey:@"outputImage"];
    }
    
    CIVector *cropVector = [CIVector vectorWithX:0 Y:0 Z:CGRectGetWidth(aRect) W:CGRectGetHeight(aRect)];
    
    [cropFilter setValue:cropVector forKey:@"inputRectangle"];
    [cropFilter setValue:image forKey:@"inputImage"];
    
    return [cropFilter valueForKey:@"outputImage"];
}

- (CIImage *)imageWithAdjustedHueAngle:(CGFloat)hue saturationFactor:(CGFloat)saturation brightnessBias:(CGFloat)brightness;
{
    CIFilter *hueAdjustFilter = [CIFilter filterWithName:@"CIHueAdjust"];
    CIFilter *colorControlsFilter = [CIFilter filterWithName:@"CIColorControls"];
    
    [hueAdjustFilter setValue:[NSNumber numberWithFloat:hue * M_PI] forKey:@"inputAngle"];
    [hueAdjustFilter setValue:self forKey:@"inputImage"];
    
    [colorControlsFilter setDefaults];
    [colorControlsFilter setValue:[NSNumber numberWithFloat:saturation] forKey:@"inputSaturation"];
    [colorControlsFilter setValue:[NSNumber numberWithFloat:brightness] forKey:@"inputBrightness"];
    [colorControlsFilter setValue:[hueAdjustFilter valueForKey:@"outputImage"] forKey:@"inputImage"];
    
    return [colorControlsFilter valueForKey:@"outputImage"];
}

- (CIImage *)invertedImage {
    CIFilter *invertFilter = [CIFilter filterWithName:@"CIColorInvert"];
    
    [invertFilter setValue:self forKey:@"inputImage"];
    
    return [invertFilter valueForKey:@"outputImage"];
}

@end 


@implementation CIColor (BDSKExtensions)

+ (CIColor *)colorWithWhite:(CGFloat)white
{
    return [self colorWithRed:white green:white blue:white];
}

+ (CIColor *)colorWithNSColor:(NSColor *)color
{
    color = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    return [CIColor colorWithRed:[color redComponent] green:[color greenComponent] blue:[color blueComponent] alpha:[color alphaComponent]];
}

+ (CIColor *)clearColor;
{
    static CIColor *color = nil;
    if (nil == color)
        color = [[self colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.0] retain];
    return color;
}

@end

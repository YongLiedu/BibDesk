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

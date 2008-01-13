//
//  FVFinderLabel.m
//  FileView
//
//  Created by Adam Maxwell on 1/12/08.
/*
 This software is Copyright (c) 2008
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

#import "FVFinderLabel.h"
#import "FVIcon.h"

@implementation FVFinderLabel

static CFMutableDictionaryRef __layers = NULL;

static Boolean intEqual(const void *v1, const void *v2) { return v1 == v2; }
static CFStringRef intDesc(const void *value) { return (CFStringRef)[[NSString alloc] initWithFormat:@"%ld", (long)value]; }
static CFHashCode intHash(const void *value) { return (CFHashCode)value; }

+ (void)initialize
{
    if (NULL == __layers) {
        const CFDictionaryKeyCallBacks integerKeyCallBacks = { 0, NULL, NULL, intDesc, intEqual, intHash };
        __layers = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &integerKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    }
}

typedef struct FVRGBAColor { 
    CGFloat red;
    CGFloat green; 
    CGFloat blue;
    CGFloat alpha;
} FVRGBAColor;

typedef struct _FVGradientColor {
    FVRGBAColor color1;
    FVRGBAColor color2;
} FVGradientColor;

static void linearColorBlendFunction(void *info, const CGFloat *in, float *out)
{
    FVGradientColor *color = info;
    out[0] = (1.0 - *in) * color->color1.red + *in * color->color2.red;
    out[1] = (1.0 - *in) * color->color1.green + *in * color->color2.green;
    out[2] = (1.0 - *in) * color->color1.blue + *in * color->color2.blue;
    out[3] = (1.0 - *in) * color->color1.alpha + *in * color->color2.alpha;    
}

static void linearColorReleaseFunction(void *info)
{
    CFAllocatorDeallocate(CFAllocatorGetDefault(), info);
}

static const CGFunctionCallbacks linearFunctionCallbacks = {0, &linearColorBlendFunction, &linearColorReleaseFunction};

#define LABEL_ALPHA 1.0

+ (NSColor *)_lowerColorForFinderLabel:(NSUInteger)label
{
    NSColor *color = nil;
    switch (label) {
        case 1:
            // gray
            color = [NSColor colorWithDeviceRed:0.66 green:0.66 blue:0.66 alpha:LABEL_ALPHA];
            break;
        case 3:
            // purple
            color = [NSColor colorWithDeviceRed:0.81 green:0.51 blue:0.86 alpha:LABEL_ALPHA]; 
            break;
        case 4:
            // blue
            color = [NSColor colorWithDeviceRed:0.22 green:0.64 blue:1.0 alpha:LABEL_ALPHA];
            break;
        case 2:
            // green
            color = [NSColor colorWithDeviceRed:0.64 green:0.87 blue:0.24 alpha:LABEL_ALPHA];
            break;
        case 5:
            // yellow
            color = [NSColor colorWithDeviceRed:0.95 green:0.86 blue:0.24 alpha:LABEL_ALPHA];
            break;
        case 7:
            // orange
            color = [NSColor colorWithDeviceRed:1.0 green:0.64 blue:0.23 alpha:LABEL_ALPHA];
            break;
        case 6:
            // red
            color = [NSColor colorWithDeviceRed:1.0 green:0.30 blue:0.34 alpha:LABEL_ALPHA];
            break;
        default:
            color = [NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:0.0];
            break;
    }
    return color;
}

+ (NSColor *)_upperColorForFinderLabel:(NSUInteger)label
{
    NSColor *color = nil;
    switch (label) {
        case 1:
            // gray
            color = [NSColor colorWithDeviceRed:0.84 green:0.84 blue:0.84 alpha:LABEL_ALPHA];
            break;
        case 3:
            // purple
            color = [NSColor colorWithDeviceRed:0.92 green:0.77 blue:0.93 alpha:LABEL_ALPHA]; 
            break;
        case 4:
            // blue
            color = [NSColor colorWithDeviceRed:0.66 green:0.85 blue:1.0 alpha:LABEL_ALPHA];
            break;
        case 2:
            // green
            color = [NSColor colorWithDeviceRed:0.84 green:0.94 blue:0.65 alpha:LABEL_ALPHA];
            break;
        case 5:
            // yellow
            color = [NSColor colorWithDeviceRed:0.98 green:0.96 blue:0.64 alpha:LABEL_ALPHA];
            break;
        case 7:
            // orange
            color = [NSColor colorWithDeviceRed:1.0 green:0.83 blue:0.62 alpha:LABEL_ALPHA];
            break;
        case 6:
            // red
            color = [NSColor colorWithDeviceRed:1.0 green:0.66 blue:0.66 alpha:LABEL_ALPHA];
            break;
        default:
            color = [NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:0.0];
            break;
    }
    return color;
}

+ (NSString *)localizedNameForLabel:(NSInteger)label
{
    NSString *name = nil;
    NSBundle *bundle = [NSBundle bundleForClass:[FVFinderLabel self]];
    switch (label) {
        case 1:
            // gray
            name = NSLocalizedStringFromTableInBundle(@"Gray", @"FileView", bundle, @"Finder label color");
            break;
        case 3:
            // purple
            name = NSLocalizedStringFromTableInBundle(@"Purple", @"FileView", bundle, @"Finder label color"); 
            break;
        case 4:
            // blue
            name = NSLocalizedStringFromTableInBundle(@"Blue", @"FileView", bundle, @"Finder label color");
            break;
        case 2:
            // green
            name = NSLocalizedStringFromTableInBundle(@"Green", @"FileView", bundle, @"Finder label color");
            break;
        case 5:
            // yellow
            name = NSLocalizedStringFromTableInBundle(@"Yellow", @"FileView", bundle, @"Finder label color");
            break;
        case 7:
            // orange
            name = NSLocalizedStringFromTableInBundle(@"Orange", @"FileView", bundle, @"Finder label color");
            break;
        case 6:
            // red
            name = NSLocalizedStringFromTableInBundle(@"Red", @"FileView", bundle, @"Finder label color");
            break;
        default:
            name = NSLocalizedStringFromTableInBundle(@"None", @"FileView", bundle, @"Finder label color");
            break;
    }
    return name;
}

+ (void)_drawLabel:(NSUInteger)label inRect:(NSRect)rect ofContext:(CGContextRef)context;
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();    
    FVGradientColor *gradientColor = CFAllocatorAllocate(CFAllocatorGetDefault(), sizeof(FVGradientColor), 0);
    
    NSColor *upperColor = [self _upperColorForFinderLabel:label];
    NSColor *lowerColor = [self _lowerColorForFinderLabel:label];
    
    // all colors were created using device RGB since we only draw to the screen, so we know that extracting components will work
    [lowerColor getRed:&gradientColor->color1.red green:&gradientColor->color1.green blue:&gradientColor->color1.blue alpha:&gradientColor->color1.alpha];
    [upperColor getRed:&gradientColor->color2.red green:&gradientColor->color2.green blue:&gradientColor->color2.blue alpha:&gradientColor->color2.alpha];
    
    // basic idea borrowed from OAGradientTableView and simplified
    static const CGFloat domainAndRange[8] = { 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0 };
    CGFunctionRef linearBlendFunctionRef = CGFunctionCreate(gradientColor, 1, domainAndRange, 4, domainAndRange, &linearFunctionCallbacks);    
    CGContextSaveGState(context); 
    CGContextClipToRect(context, *(CGRect *)&rect);
    CGShadingRef cgShading = CGShadingCreateAxial(colorSpace, CGPointMake(0, NSMinY(rect)), CGPointMake(0, NSMaxY(rect)), linearBlendFunctionRef, NO, NO);
    CGContextDrawShading(context, cgShading);
    CGShadingRelease(cgShading);
    CGContextRestoreGState(context);
    
    CGFunctionRelease(linearBlendFunctionRef);
    CGColorSpaceRelease(colorSpace);
}

+ (CGSize)_layerSize { return (CGSize) { 1, 20 }; }

+ (CGLayerRef)_layerForLabel:(NSUInteger)label context:(CGContextRef)context
{
    CGLayerRef layer = (void *)CFDictionaryGetValue(__layers, (const void *)label);    
    if (NULL == layer) {
        CGSize layerSize = [self _layerSize];
        if (NULL == context)
            context = [[NSGraphicsContext currentContext] graphicsPort];

        layer = CGLayerCreateWithContext(context, layerSize, NULL);
        CGContextRef layerContext = CGLayerGetContext(layer);
        [self _drawLabel:label inRect:NSMakeRect(0, 0, layerSize.width, layerSize.height) ofContext:layerContext];
        CFDictionarySetValue(__layers, (const void *)label, layer);
        CGLayerRelease(layer);
    }
    return layer;
}

// Finder labels appear to be rectangles with a semicircle cap instead of a round-cornered rect
static void ClipContextToCircleCappedPathInRect(CGContextRef context, CGRect rect)
{
    CGFloat radius = CGRectGetHeight(rect) / 2.0;
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, CGRectGetMinX(rect) + radius, CGRectGetMinY(rect));
    CGPathAddArc(path, NULL, CGRectGetMinX(rect) + radius, CGRectGetMidY(rect), radius, -M_PI_2, M_PI_2, true);
    CGPathAddArc(path, NULL, CGRectGetMaxX(rect) - radius, CGRectGetMidY(rect), radius, M_PI_2, -M_PI_2, true);
    CGPathCloseSubpath(path);
    CGContextAddPath(context, path);
    CGContextClip(context);
    CGPathRelease(path);
}

+ (void)drawFinderLabel:(NSUInteger)label inRect:(CGRect)rect ofContext:(CGContextRef)context flipped:(BOOL)isFlipped roundEnds:(BOOL)flag;
{
    CGContextSaveGState(context);
    if (isFlipped) {
        CGContextTranslateCTM(context, 0, CGRectGetMaxY(rect));
        CGContextScaleCTM(context, 1, -1);
        rect.origin.y = 0;
    }
    if (flag)
        ClipContextToCircleCappedPathInRect(context, rect);
    else
        CGContextClipToRect(context, rect);
    CGContextDrawLayerInRect(context, rect, [self _layerForLabel:label context:context]);
    CGContextRestoreGState(context);
}

+ (void)drawFinderLabel:(NSUInteger)label inRect:(NSRect)rect roundEnds:(BOOL)flag;
{
    NSGraphicsContext *nsContext = [NSGraphicsContext currentContext];
    [self drawFinderLabel:label inRect:*(CGRect *)&rect ofContext:[nsContext graphicsPort] flipped:[nsContext isFlipped] roundEnds:flag];
}

@end

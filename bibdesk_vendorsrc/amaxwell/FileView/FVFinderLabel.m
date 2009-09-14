//
//  FVFinderLabel.m
//  FileView
//
//  Created by Adam Maxwell on 1/12/08.
/*
 This software is Copyright (c) 2008-2009
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

typedef struct _FVRGBAColor { 
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
    NSColorSpace *cspace = [NSColorSpace genericRGBColorSpace];
    CGFloat components[4] = { 0, 0, 0, LABEL_ALPHA };

    switch (label) {
        case 1:
            // gray
            components[0] = 168.0/255.0;
            components[1] = 168.0/255.0;
            components[2] = 168.0/255.0;
            color = [NSColor colorWithColorSpace:cspace components:components count:sizeof(components)/sizeof(CGFloat)];
            break;
        case 3:
            // purple
            components[0] = 193.0/255.0;
            components[1] = 140.0/255.0;
            components[2] = 217.0/255.0;
            color = [NSColor colorWithColorSpace:cspace components:components count:sizeof(components)/sizeof(CGFloat)];
            break;
        case 4:
            // blue
            components[0] =  95.0/255.0;
            components[1] = 165.0/255.0;
            components[2] = 251.0/255.0;
            color = [NSColor colorWithColorSpace:cspace components:components count:sizeof(components)/sizeof(CGFloat)];
            break;
        case 2:
            // green
            components[0] = 178.0/255.0;
            components[1] = 217.0/255.0;
            components[2] =  73.0/255.0;
            color = [NSColor colorWithColorSpace:cspace components:components count:sizeof(components)/sizeof(CGFloat)];
            break;
        case 5:
            // yellow
            components[0] = 238.0/255.0;
            components[1] = 219.0/255.0;
            components[2] =  73.0/255.0;
            color = [NSColor colorWithColorSpace:cspace components:components count:sizeof(components)/sizeof(CGFloat)];
            break;
        case 7:
            // orange
            components[0] = 239.0/255.0;
            components[1] = 168.0/255.0;
            components[2] =  67.0/255.0;
            color = [NSColor colorWithColorSpace:cspace components:components count:sizeof(components)/sizeof(CGFloat)];
            break;
        case 6:
            // red
            components[0] = 228.0/255.0;
            components[1] =  92.0/255.0;
            components[2] =  90.0/255.0;
            color = [NSColor colorWithColorSpace:cspace components:components count:sizeof(components)/sizeof(CGFloat)];
            break;
        default:
            components[3] = 0.0;
            color = [NSColor colorWithColorSpace:cspace components:components count:sizeof(components)/sizeof(CGFloat)];
            break;
    }
    return color;
}

+ (NSColor *)_upperColorForFinderLabel:(NSUInteger)label
{
    NSColor *color = nil;
    NSColorSpace *cspace = [NSColorSpace genericRGBColorSpace];
    CGFloat components[4] = { 0, 0, 0, LABEL_ALPHA };
    
    switch (label) {
        case 1:
            // gray
            components[0] = 207.0/255.0;
            components[1] = 207.0/255.0;
            components[2] = 207.0/255.0;
            color = [NSColor colorWithColorSpace:cspace components:components count:sizeof(components)/sizeof(CGFloat)];
            break;
        case 3:
            // purple
            components[0] = 229.0/255.0;
            components[1] = 206.0/255.0;
            components[2] = 239.0/255.0;
            color = [NSColor colorWithColorSpace:cspace components:components count:sizeof(components)/sizeof(CGFloat)];
            break;
        case 4:
            // blue
            components[0] = 174.0/255.0;
            components[1] = 212.0/255.0;
            components[2] = 253.0/255.0;
            color = [NSColor colorWithColorSpace:cspace components:components count:sizeof(components)/sizeof(CGFloat)];
            break;
        case 2:
            // green
            components[0] = 224.0/255.0;
            components[1] = 240.0/255.0;
            components[2] = 180.0/255.0;
            color = [NSColor colorWithColorSpace:cspace components:components count:sizeof(components)/sizeof(CGFloat)];
            break;
        case 5:
            // yellow
            components[0] = 250.0/255.0;
            components[1] = 244.0/255.0;
            components[2] = 161.0/255.0;
            color = [NSColor colorWithColorSpace:cspace components:components count:sizeof(components)/sizeof(CGFloat)];
            break;
        case 7:
            // orange
            components[0] = 246.0/255.0;
            components[1] = 208.0/255.0;
            components[2] = 148.0/255.0;
            color = [NSColor colorWithColorSpace:cspace components:components count:sizeof(components)/sizeof(CGFloat)];
            break;
        case 6:
            // red
            components[0] = 239.0/255.0;
            components[1] = 172.0/255.0;
            components[2] = 168.0/255.0;
            color = [NSColor colorWithColorSpace:cspace components:components count:sizeof(components)/sizeof(CGFloat)];
            break;
        default:
            components[3] = 0.0;
            color = [NSColor colorWithColorSpace:cspace components:components count:sizeof(components)/sizeof(CGFloat)];
            break;
    }
    return color;
}

+ (NSString *)localizedNameForLabel:(NSInteger)label
{
    FVAPIAssert1(label <= 7, @"Invalid Finder label %d (must be in the range 0--7)", label);
    static NSArray *labelNames = nil;
    if (nil == labelNames) {
        NSBundle *bundle = [NSBundle bundleForClass:[FVFinderLabel self]];
        
        // Apple preference for Finder label names
        NSDictionary *labelPrefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.Labels"];
        NSMutableArray *names = [NSMutableArray arrayWithCapacity:8];
        NSString *name;
        name = [labelPrefs objectForKey:@"Label_Name_0"];
        if (name == nil || [name isKindOfClass:[NSString class]] == NO)
            name = NSLocalizedStringFromTableInBundle(@"None", @"FileView", bundle, @"Finder label color");
        [names addObject:name];
        name = [labelPrefs objectForKey:@"Label_Name_1"];
        if (name == nil || [name isKindOfClass:[NSString class]] == NO)
            name = NSLocalizedStringFromTableInBundle(@"Gray", @"FileView", bundle, @"Finder label color");
        [names addObject:name];
        name = [labelPrefs objectForKey:@"Label_Name_2"];
        if (name == nil || [name isKindOfClass:[NSString class]] == NO)
            name = NSLocalizedStringFromTableInBundle(@"Green", @"FileView", bundle, @"Finder label color");
        [names addObject:name];
        name = [labelPrefs objectForKey:@"Label_Name_3"];
        if (name == nil || [name isKindOfClass:[NSString class]] == NO)
            name = NSLocalizedStringFromTableInBundle(@"Purple", @"FileView", bundle, @"Finder label color");
        [names addObject:name];
        name = [labelPrefs objectForKey:@"Label_Name_4"];
        if (name == nil || [name isKindOfClass:[NSString class]] == NO)
            name = NSLocalizedStringFromTableInBundle(@"Blue", @"FileView", bundle, @"Finder label color");
        [names addObject:name];
        name = [labelPrefs objectForKey:@"Label_Name_5"];
        if (name == nil || [name isKindOfClass:[NSString class]] == NO)
            name = NSLocalizedStringFromTableInBundle(@"Yellow", @"FileView", bundle, @"Finder label color");
        [names addObject:name];
        name = [labelPrefs objectForKey:@"Label_Name_6"];
        if (name == nil || [name isKindOfClass:[NSString class]] == NO)
            name = NSLocalizedStringFromTableInBundle(@"Red", @"FileView", bundle, @"Finder label color");
        [names addObject:name];
        name = [labelPrefs objectForKey:@"Label_Name_7"];
        if (name == nil || [name isKindOfClass:[NSString class]] == NO)
            name = NSLocalizedStringFromTableInBundle(@"Orange", @"FileView", bundle, @"Finder label color");
        [names addObject:name];
        labelNames = [names copy];
    }
    return [labelNames objectAtIndex:label];
}

// Note: there is no optimization or caching here because this is only called once per color to draw the CGLayer
+ (void)_drawLabel:(NSUInteger)label inRect:(NSRect)rect ofContext:(CGContextRef)context;
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    FVGradientColor *gradientColor = CFAllocatorAllocate(CFAllocatorGetDefault(), sizeof(FVGradientColor), 0);
    
    NSColor *upperColor = [[self _upperColorForFinderLabel:label] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    NSColor *lowerColor = [[self _lowerColorForFinderLabel:label] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    
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
    FVAPIAssert1(label <= 7, @"Invalid Finder label %d (must be in the range 0--7)", label);
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

+ (NSUInteger)finderLabelForURL:(NSURL *)aURL;
{
    FSRef fileRef;
    NSUInteger label = 0;
    
    if ([aURL isFileURL] && CFURLGetFSRef((CFURLRef)aURL, &fileRef)) {
        
        FSCatalogInfo catalogInfo;    
        OSStatus err;
        
        err = FSGetCatalogInfo(&fileRef, kFSCatInfoNodeFlags | kFSCatInfoFinderInfo, &catalogInfo, NULL, NULL, NULL);
        if (noErr == err) {
            
            // coerce to FolderInfo or FileInfo as needed and get the color bit
            if ((catalogInfo.nodeFlags & kFSNodeIsDirectoryMask) != 0) {
                FolderInfo *fInfo = (FolderInfo *)&catalogInfo.finderInfo;
                label = fInfo->finderFlags & kColor;
            }
            else {
                FileInfo *fInfo = (FileInfo *)&catalogInfo.finderInfo;
                label = fInfo->finderFlags & kColor;
            }
        }
    }
    return (label >> 1L);
}

+ (void)setFinderLabel:(NSUInteger)label forURL:(NSURL *)aURL;
{
    FSRef fileRef;
    
    FVAPIAssert1(label <= 7, @"Invalid Finder label %d (must be in the range 0--7)", label);
        
    if ([aURL isFileURL] && CFURLGetFSRef((CFURLRef)aURL, &fileRef)) {

        FSCatalogInfo catalogInfo;    
        OSStatus err;
        
        // get the current catalog info
        err = FSGetCatalogInfo(&fileRef, kFSCatInfoNodeFlags | kFSCatInfoFinderInfo, &catalogInfo, NULL, NULL, NULL);
        
        if (noErr == err) {
            
            label = (label << 1L);
            
            // coerce to FolderInfo or FileInfo as needed and set the color bit
            if ((catalogInfo.nodeFlags & kFSNodeIsDirectoryMask) != 0) {
                FolderInfo *fInfo = (FolderInfo *)&catalogInfo.finderInfo;
                fInfo->finderFlags &= ~kColor;
                fInfo->finderFlags |= (label & kColor);
            }
            else {
                FileInfo *fInfo = (FileInfo *)&catalogInfo.finderInfo;
                fInfo->finderFlags &= ~kColor;
                fInfo->finderFlags |= (label & kColor);
            }
            FSSetCatalogInfo(&fileRef, kFSCatInfoFinderInfo, &catalogInfo);
        }
    }
}

@end

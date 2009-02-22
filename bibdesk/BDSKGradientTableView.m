//
//  BDSKGradientTableView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/18/09.
/*
 This software is Copyright (c) 2009
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

#import "BDSKGradientTableView.h"

// This class is basically a copy of OAGradientTableView

@implementation BDSKGradientTableView

typedef struct {
    float red1, green1, blue1, alpha1;
    float red2, green2, blue2, alpha2;
} _twoColorsType;

static void _linearColorBlendFunction(void *info, const float *in, float *out) {
    _twoColorsType *twoColors = info;
    
    out[0] = (1.0 - *in) * twoColors->red1 + *in * twoColors->red2;
    out[1] = (1.0 - *in) * twoColors->green1 + *in * twoColors->green2;
    out[2] = (1.0 - *in) * twoColors->blue1 + *in * twoColors->blue2;
    out[3] = (1.0 - *in) * twoColors->alpha1 + *in * twoColors->alpha2;
}

static void _linearColorReleaseInfoFunction(void *info) { free(info); }

static const CGFunctionCallbacks linearFunctionCallbacks = {0, &_linearColorBlendFunction, &_linearColorReleaseInfoFunction};

static NSColor *highlightColor = nil;
static NSColor *secondaryHighlightColor = nil;
static CGFunctionRef linearBlendFunctionRef = NULL;
static CGFunctionRef secondaryLinearBlendFunctionRef = NULL;

+ (void)initialize {
    
    BDSKINITIALIZE;
    
    highlightColor = [[NSColor alternateSelectedControlColor] retain];
    // If this view isn't key, use the gray version of the dark color. Note that this varies from the standard gray version that NSCell returns as its highlightColorWithFrame: when the cell is not in a key view, in that this is a lot darker. Mike and I think this is justified for this kind of view -- if you're using the dark selection color to show the selected status, it makes sense to leave it dark.
    secondaryHighlightColor = [[[highlightColor colorUsingColorSpaceName:NSDeviceWhiteColorSpace] colorUsingColorSpaceName:NSDeviceRGBColorSpace] retain];
    
    // Take the color apart
    float hue, saturation, brightness, alpha;
    [[highlightColor colorUsingColorSpaceName:NSDeviceRGBColorSpace] getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];

    // Create synthetic darker and lighter versions
    // NSColor *lighterColor = [NSColor colorWithDeviceHue:hue - (1.0/120.0) saturation:MAX(0.0, saturation-0.12) brightness:MIN(1.0, brightness+0.045) alpha:alpha];
    NSColor *lighterColor = [NSColor colorWithDeviceHue:hue saturation:MAX(0.0, saturation-.12) brightness:MIN(1.0, brightness+0.30) alpha:alpha];
    NSColor *darkerColor = [NSColor colorWithDeviceHue:hue saturation:MIN(1.0, (saturation > .04) ? saturation+0.12 : 0.0) brightness:MAX(0.0, brightness-0.045) alpha:alpha];
    NSColor *secondaryLighterColor = [[lighterColor colorUsingColorSpaceName:NSDeviceWhiteColorSpace] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    NSColor *secondaryDarkerColor = [[darkerColor colorUsingColorSpaceName:NSDeviceWhiteColorSpace] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    
    // Set up the helper function for drawing washes
    _twoColorsType *twoColors;
    static const float domainAndRange[8] = {0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0};
    
    twoColors = malloc(sizeof(_twoColorsType)); // We malloc() the helper data because we may draw this wash during printing, in which case it won't necessarily be evaluated immediately. We need for all the data the shading function needs to draw to potentially outlive us.
    [lighterColor getRed:&twoColors->red1 green:&twoColors->green1 blue:&twoColors->blue1 alpha:&twoColors->alpha1];
    [darkerColor getRed:&twoColors->red2 green:&twoColors->green2 blue:&twoColors->blue2 alpha:&twoColors->alpha2];
    linearBlendFunctionRef = CGFunctionCreate(twoColors, 1, domainAndRange, 4, domainAndRange, &linearFunctionCallbacks);
    
    twoColors = malloc(sizeof(_twoColorsType)); // We malloc() the helper data because we may draw this wash during printing, in which case it won't necessarily be evaluated immediately. We need for all the data the shading function needs to draw to potentially outlive us.
    [secondaryLighterColor getRed:&twoColors->red1 green:&twoColors->green1 blue:&twoColors->blue1 alpha:&twoColors->alpha1];
    [secondaryDarkerColor getRed:&twoColors->red2 green:&twoColors->green2 blue:&twoColors->blue2 alpha:&twoColors->alpha2];
    secondaryLinearBlendFunctionRef = CGFunctionCreate(twoColors, 1, domainAndRange, 4, domainAndRange, &linearFunctionCallbacks);
}

- (id)_highlightColorForCell:(NSCell *)cell { return nil; }

- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)shouldExtend {
    [super selectRowIndexes:indexes byExtendingSelection:shouldExtend];
    [self setNeedsDisplay:YES]; // we display extra because we draw multiple contiguous selected rows differently, so changing one row's selection can change how others draw.
}

- (void)deselectRow:(int)row {
    [super deselectRow:row];
    [self setNeedsDisplay:YES]; // we display extra because we draw multiple contiguous selected rows differently, so changing one row's selection can change how others draw.
}

- (void)highlightSelectionInClipRect:(NSRect)rect {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    NSColor *color;
    CGFunctionRef functionRef;
    
    if ([[self window] firstResponder] == self && [[self window] isKeyWindow]) {
        color = highlightColor;
        functionRef = linearBlendFunctionRef;
    } else {
        color = secondaryHighlightColor;
        functionRef = secondaryLinearBlendFunctionRef;
    }
    
    NSIndexSet *selectedRowIndexes = [self selectedRowIndexes];
    unsigned int rowIndex = [selectedRowIndexes firstIndex];
    
    while (rowIndex != NSNotFound) {
        unsigned int endOfCurrentRunRowIndex, newRowIndex = rowIndex;
        do {
            endOfCurrentRunRowIndex = newRowIndex;
            newRowIndex = [selectedRowIndexes indexGreaterThanIndex:endOfCurrentRunRowIndex];
        } while (newRowIndex == endOfCurrentRunRowIndex + 1);
            
        NSRect rowRect = NSUnionRect([self rectOfRow:rowIndex], [self rectOfRow:endOfCurrentRunRowIndex]);
        
        NSRect topBar, washRect;
        NSDivideRect(rowRect, &topBar, &washRect, 1.0, NSMinYEdge);
        
        // Draw the top line of pixels of the selected row in the alternateSelectedControlColor
        [color set];
        NSRectFill(topBar);

        // Draw a soft wash underneath it
        CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
        CGContextSaveGState(context); {
            CGContextClipToRect(context, *(CGRect*)&washRect);
            CGShadingRef cgShading = CGShadingCreateAxial(colorSpace, CGPointMake(0, NSMinY(washRect)), CGPointMake(0, NSMaxY(washRect)), functionRef, NO, NO);
            CGContextDrawShading(context, cgShading);
            CGShadingRelease(cgShading);
        } CGContextRestoreGState(context);

        rowIndex = newRowIndex;
    }
    CGColorSpaceRelease(colorSpace);
}

@end

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
/*
 Omni Source License 2007

 OPEN PERMISSION TO USE AND REPRODUCE OMNI SOURCE CODE SOFTWARE

 Omni Source Code software is available from The Omni Group on their 
 web site at http://www.omnigroup.com/www.omnigroup.com. 

 Permission is hereby granted, free of charge, to any person obtaining 
 a copy of this software and associated documentation files (the 
 "Software"), to deal in the Software without restriction, including 
 without limitation the rights to use, copy, modify, merge, publish, 
 distribute, sublicense, and/or sell copies of the Software, and to 
 permit persons to whom the Software is furnished to do so, subject to 
 the following conditions:

 Any original copyright notices and this permission notice shall be 
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY 
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "BDSKGradientTableView.h"
#import "NSLayoutManager_BDSKExtensions.h"

// This class is basically a copy of OAGradientTableView

typedef struct {
    CGFloat red1, green1, blue1, alpha1;
    CGFloat red2, green2, blue2, alpha2;
} _twoColorsType;

static void _linearColorBlendFunction(void *info, const CGFloat *in, CGFloat *out) {
    _twoColorsType *twoColors = info;
    
    out[0] = (1.0 - *in) * twoColors->red1 + *in * twoColors->red2;
    out[1] = (1.0 - *in) * twoColors->green1 + *in * twoColors->green2;
    out[2] = (1.0 - *in) * twoColors->blue1 + *in * twoColors->blue2;
    out[3] = (1.0 - *in) * twoColors->alpha1 + *in * twoColors->alpha2;
}

static void _linearColorReleaseInfoFunction(void *info) { free(info); }

static const CGFunctionCallbacks linearFunctionCallbacks = {0, &_linearColorBlendFunction, &_linearColorReleaseInfoFunction};

static NSColor *highlightColor = nil;
static NSColor *highlightLightColor = nil;
static NSColor *highlightDarkColor = nil;
static NSColor *secondaryHighlightColor = nil;
static NSColor *secondaryHighlightLightColor = nil;
static NSColor *secondaryHighlightDarkColor = nil;

static void initializeHighlightColors() {
    if (highlightColor == nil) {
        highlightColor = [[NSColor alternateSelectedControlColor] retain];
        // If this view isn't key, use the gray version of the dark color. Note that this varies from the standard gray version that NSCell returns as its highlightColorWithFrame: when the cell is not in a key view, in that this is a lot darker. Mike and I think this is justified for this kind of view -- if you're using the dark selection color to show the selected status, it makes sense to leave it dark.
        secondaryHighlightColor = [[[highlightColor colorUsingColorSpaceName:NSDeviceWhiteColorSpace] colorUsingColorSpaceName:NSDeviceRGBColorSpace] retain];
        
        // Take the color apart
        CGFloat hue, saturation, brightness, alpha;
        [[highlightColor colorUsingColorSpaceName:NSDeviceRGBColorSpace] getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];

        // Create synthetic darker and lighter versions
        // NSColor *highlightLightColor = [NSColor colorWithDeviceHue:hue - (1.0/120.0) saturation:MAX(0.0, saturation-0.12) brightness:MIN(1.0, brightness+0.045) alpha:alpha];
        highlightLightColor = [[NSColor colorWithDeviceHue:hue saturation:MAX(0.0, saturation-.12) brightness:MIN(1.0, brightness+0.30) alpha:alpha] retain];
        highlightDarkColor = [[NSColor colorWithDeviceHue:hue saturation:MIN(1.0, (saturation > .04) ? saturation+0.12 : 0.0) brightness:MAX(0.0, brightness-0.045) alpha:alpha] retain];
        secondaryHighlightLightColor = [[[highlightLightColor colorUsingColorSpaceName:NSDeviceWhiteColorSpace] colorUsingColorSpaceName:NSDeviceRGBColorSpace] retain];
        secondaryHighlightDarkColor = [[[highlightDarkColor colorUsingColorSpaceName:NSDeviceWhiteColorSpace] colorUsingColorSpaceName:NSDeviceRGBColorSpace] retain];
    }
}

@implementation BDSKGradientTableView

+ (void)initialize {
    BDSKINITIALIZE;
    initializeHighlightColors();
}

- (id)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        if ([self respondsToSelector:@selector(setSelectionHighlightStyle:)])
            [self setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
        else // from Mail.app on 10.4
            [self setBackgroundColor:[[NSColor colorWithCalibratedRed:231.0f/255.0f green:237.0f/255.0f blue:246.0f/255.0f alpha:1.0] colorUsingColorSpaceName:NSDeviceRGBColorSpace]];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        if ([self respondsToSelector:@selector(setSelectionHighlightStyle:)])
            [self setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
        else // from Mail.app on 10.4
            [self setBackgroundColor:[[NSColor colorWithCalibratedRed:231.0f/255.0f green:237.0f/255.0f blue:246.0f/255.0f alpha:1.0] colorUsingColorSpaceName:NSDeviceRGBColorSpace]];
    }
    return self;
}

- (id)_highlightColorForCell:(NSCell *)cell { return nil; }

- (void)highlightSelectionInClipRect:(NSRect)rect {
    if ([self respondsToSelector:@selector(setSelectionHighlightStyle:)]) {
        [super highlightSelectionInClipRect:rect];
        return;
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    NSColor *color, *lightColor, *darkColor;
    CGFunctionRef linearBlendFunctionRef;
    
    if ([[self window] firstResponder] == self && [[self window] isKeyWindow]) {
        color = highlightColor;
        lightColor = highlightLightColor;
        darkColor = highlightDarkColor;
    } else {
        color = secondaryHighlightColor;
        lightColor = secondaryHighlightLightColor;
        darkColor = secondaryHighlightDarkColor;
    }
    
    static const CGFloat domainAndRange[8] = {0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0};
    
    _twoColorsType *twoColors = malloc(sizeof(_twoColorsType)); // We malloc() the helper data because we may draw this wash during printing, in which case it won't necessarily be evaluated immediately. We need for all the data the shading function needs to draw to potentially outlive us.
    [lightColor getRed:&twoColors->red1 green:&twoColors->green1 blue:&twoColors->blue1 alpha:&twoColors->alpha1];
    [darkColor getRed:&twoColors->red2 green:&twoColors->green2 blue:&twoColors->blue2 alpha:&twoColors->alpha2];
    linearBlendFunctionRef = CGFunctionCreate(twoColors, 1, domainAndRange, 4, domainAndRange, &linearFunctionCallbacks);
    
    NSIndexSet *selectedRowIndexes = [self selectedRowIndexes];
    NSUInteger rowIndex = [selectedRowIndexes firstIndex], prevRowIndex = NSNotFound;
    
    while (rowIndex != NSNotFound) {
        NSRect rowRect = [self rectOfRow:rowIndex];
        
        NSRect topBar, washRect;
        NSDivideRect(rowRect, &topBar, &washRect, 1.0, NSMinYEdge);
        
        // Draw the top line of pixels of the selected row in the alternateSelectedControlColor
        if (rowIndex == 0 || rowIndex - 1 != prevRowIndex) {
            [color setFill];
            NSRectFill(topBar);
        }
        
        // Draw a soft wash underneath it
        CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
        CGContextSaveGState(context);
        CGContextClipToRect(context, NSRectToCGRect(washRect));
        CGShadingRef cgShading = CGShadingCreateAxial(colorSpace, CGPointMake(0, NSMinY(washRect)), CGPointMake(0, NSMaxY(washRect)), linearBlendFunctionRef, NO, NO);
        CGContextDrawShading(context, cgShading);
        CGShadingRelease(cgShading);
        CGContextRestoreGState(context);

        prevRowIndex = rowIndex;
        rowIndex = [selectedRowIndexes indexGreaterThanIndex:rowIndex];
    }
    CGFunctionRelease(linearBlendFunctionRef);
    CGColorSpaceRelease(colorSpace);
}

- (CGFloat)rowHeightForFont:(NSFont *)font {
    return [NSLayoutManager defaultViewLineHeightForFont:font] + 2.0;
}

@end

#pragma mark -

@implementation BDSKGradientOutlineView

+ (void)initialize {
    BDSKINITIALIZE;
    initializeHighlightColors();
}

- (id)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        if ([self respondsToSelector:@selector(setSelectionHighlightStyle:)])
            [self setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
        else // from Mail.app on 10.4
            [self setBackgroundColor:[[NSColor colorWithCalibratedRed:231.0f/255.0f green:237.0f/255.0f blue:246.0f/255.0f alpha:1.0] colorUsingColorSpaceName:NSDeviceRGBColorSpace]];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        if ([self respondsToSelector:@selector(setSelectionHighlightStyle:)])
            [self setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
        else // from Mail.app on 10.4
            [self setBackgroundColor:[[NSColor colorWithCalibratedRed:231.0f/255.0f green:237.0f/255.0f blue:246.0f/255.0f alpha:1.0] colorUsingColorSpaceName:NSDeviceRGBColorSpace]];
    }
    return self;
}

- (id)_highlightColorForCell:(NSCell *)cell { return nil; }

- (void)highlightSelectionInClipRect:(NSRect)rect {
    if ([self respondsToSelector:@selector(setSelectionHighlightStyle:)]) {
        [super highlightSelectionInClipRect:rect];
        return;
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    NSColor *color, *lightColor, *darkColor;
    CGFunctionRef linearBlendFunctionRef;
    
    if ([[self window] firstResponder] == self && [[self window] isKeyWindow]) {
        color = highlightColor;
        lightColor = highlightLightColor;
        darkColor = highlightDarkColor;
    } else {
        color = secondaryHighlightColor;
        lightColor = secondaryHighlightLightColor;
        darkColor = secondaryHighlightDarkColor;
    }
    
    static const CGFloat domainAndRange[8] = {0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0};
    
    _twoColorsType *twoColors = malloc(sizeof(_twoColorsType)); // We malloc() the helper data because we may draw this wash during printing, in which case it won't necessarily be evaluated immediately. We need for all the data the shading function needs to draw to potentially outlive us.
    [lightColor getRed:&twoColors->red1 green:&twoColors->green1 blue:&twoColors->blue1 alpha:&twoColors->alpha1];
    [darkColor getRed:&twoColors->red2 green:&twoColors->green2 blue:&twoColors->blue2 alpha:&twoColors->alpha2];
    linearBlendFunctionRef = CGFunctionCreate(twoColors, 1, domainAndRange, 4, domainAndRange, &linearFunctionCallbacks);
    
    NSIndexSet *selectedRowIndexes = [self selectedRowIndexes];
    NSUInteger rowIndex = [selectedRowIndexes firstIndex], prevRowIndex = NSNotFound;
    
    while (rowIndex != NSNotFound) {
        NSRect rowRect = [self rectOfRow:rowIndex];
        
        NSRect topBar, washRect;
        NSDivideRect(rowRect, &topBar, &washRect, 1.0, NSMinYEdge);
        
        // Draw the top line of pixels of the selected row in the alternateSelectedControlColor
        if (rowIndex == 0 || rowIndex - 1 != prevRowIndex) {
            [color setFill];
            NSRectFill(topBar);
        }
        
        // Draw a soft wash underneath it
        CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
        CGContextSaveGState(context);
        CGContextClipToRect(context, NSRectToCGRect(washRect));
        CGShadingRef cgShading = CGShadingCreateAxial(colorSpace, CGPointMake(0, NSMinY(washRect)), CGPointMake(0, NSMaxY(washRect)), linearBlendFunctionRef, NO, NO);
        CGContextDrawShading(context, cgShading);
        CGShadingRelease(cgShading);
        CGContextRestoreGState(context);

        prevRowIndex = rowIndex;
        rowIndex = [selectedRowIndexes indexGreaterThanIndex:rowIndex];
    }
    CGFunctionRelease(linearBlendFunctionRef);
    CGColorSpaceRelease(colorSpace);
}

- (CGFloat)rowHeightForFont:(NSFont *)font {
    return [NSLayoutManager defaultViewLineHeightForFont:font] + 2.0;
}

@end

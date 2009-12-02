//
//  BDSKZoomableTextView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/1/06.
/*
 This software is Copyright (c) 2006-2009
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

#import "BDSKZoomableTextView.h"
#import "NSScrollview_BDSKExtensions.h"
#import "NSView_BDSKExtensions.h"
#import "BDSKHighlightingPopUpButton.h"


@interface NSResponder (BDSKGesturesPrivate)
- (void)magnifyWithEvent:(NSEvent *)theEvent;
- (void)beginGestureWithEvent:(NSEvent *)theEvent;
- (void)endGestureWithEvent:(NSEvent *)theEvent;
@end

@interface NSEvent (BDSKGesturesPrivate)
- (CGFloat)magnification;
@end

@implementation BDSKZoomableTextView

static NSString *BDSKDefaultScaleMenuLabels[] = {@"10%", @"20%", @"25%", @"35%", @"50%", @"60%", @"71%", @"85%", @"100%", @"120%", @"141%", @"170%", @"200%", @"300%", @"400%", @"600%", @"800%"};
static CGFloat BDSKDefaultScaleMenuFactors[] = {0.1, 0.2, 0.25, 0.35, 0.5, 0.6, 0.71, 0.85, 1.0, 1.2, 1.41, 1.7, 2.0, 3.0, 4.0, 6.0, 8.0};

#define BDSKMinDefaultScaleMenuFactor (BDSKDefaultScaleMenuFactors[1])
#define BDSKDefaultScaleMenuFactorsCount (sizeof(BDSKDefaultScaleMenuFactors) / sizeof(CGFloat))

#define BDSKScaleMenuFontSize ((CGFloat)11.0)

#pragma mark Instance methods

- (id)initWithFrame:(NSRect)rect {
    if (self = [super initWithFrame:rect]) {
		scaleFactor = 1.0;
        pinchZoomFactor = 1.0;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
		scaleFactor = 1.0;
        pinchZoomFactor = 1.0;
    }
    return self;
}

- (void)awakeFromNib
{
    // make sure we have a horizontal scroller to show the popup
    [self makeScalePopUpButton];
    [[self enclosingScrollView] setAutohidesScrollers:NO];
}

#pragma mark Instance methods - scaling related

static void sizePopUpToItemAtIndex(NSPopUpButton *popUpButton, NSUInteger anIndex) {
    NSUInteger i = [popUpButton indexOfSelectedItem];
    [popUpButton selectItemAtIndex:anIndex];
    [popUpButton sizeToFit];
    NSSize frameSize = [popUpButton frame].size;
    frameSize.width -= 22.0 + 2 * [[popUpButton cell] controlSize];
    [popUpButton setFrameSize:frameSize];
    [popUpButton selectItemAtIndex:i];
}

- (void)makeScalePopUpButton {
    if (scalePopUpButton == nil) {
        [[self enclosingScrollView] setHasHorizontalScroller:YES];
        
        // create it
        scalePopUpButton = [[BDSKHighlightingPopUpButton allocWithZone:[self zone]] initWithFrame:NSMakeRect(0.0, 0.0, 1.0, 1.0) pullsDown:NO];
        [[scalePopUpButton cell] setControlSize:[[[self enclosingScrollView] horizontalScroller] controlSize]];
		[scalePopUpButton setBordered:NO];
		[scalePopUpButton setEnabled:YES];
		[scalePopUpButton setRefusesFirstResponder:YES];
		[[scalePopUpButton cell] setUsesItemFromMenu:YES];
        
        // set a suitable font, the control size is 0, 1 or 2
        [scalePopUpButton setFont:[NSFont toolTipsFontOfSize: BDSKScaleMenuFontSize - [[scalePopUpButton cell] controlSize]]];
		
        NSUInteger cnt, numberOfDefaultItems = BDSKDefaultScaleMenuFactorsCount;
        id curItem;
        NSString *label;
        CGFloat width, maxWidth = 0.0;
        NSSize size = NSMakeSize(1000.0, 1000.0);
        NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:[scalePopUpButton font], NSFontAttributeName, nil];
        NSUInteger maxIndex = 0;
        
        // fill it
        for (cnt = 0; cnt < numberOfDefaultItems; cnt++) {
            label = [[NSBundle mainBundle] localizedStringForKey:BDSKDefaultScaleMenuLabels[cnt] value:@"" table:@"ZoomValues"];
            width = NSWidth([label boundingRectWithSize:size options:0 attributes:attrs]);
            if (width > maxWidth) {
                maxWidth = width;
                maxIndex = cnt;
            }
            [scalePopUpButton addItemWithTitle:label];
            curItem = [scalePopUpButton itemAtIndex:cnt];
            [curItem setRepresentedObject:(BDSKDefaultScaleMenuFactors[cnt] > 0.0 ? [NSNumber numberWithDouble:BDSKDefaultScaleMenuFactors[cnt]] : nil)];
        }
        // select the appropriate item, adjusting the scaleFactor if necessary
		[self setScaleFactor:scaleFactor adjustPopup:YES];
        
        // hook it up
        [scalePopUpButton setTarget:self];
        [scalePopUpButton setAction:@selector(scalePopUpAction:)];
        
        // Make sure the popup is big enough to fit the largest cell
        sizePopUpToItemAtIndex(scalePopUpButton, maxIndex);
        
		// don't let it become first responder
		[scalePopUpButton setRefusesFirstResponder:YES];
        
        // put it in the scrollview
        [[self enclosingScrollView] setPlacards:[NSArray arrayWithObject:scalePopUpButton]];
        [scalePopUpButton release];
    }
}

- (void)scalePopUpAction:(id)sender {
    NSNumber *selectedFactorObject = [[sender selectedCell] representedObject];
    
    if (selectedFactorObject == nil) {
        NSLog(@"Scale popup action: setting arbitrary zoom factors is not yet supported.");
        return;
    } else {
        [self setScaleFactor:[selectedFactorObject doubleValue] adjustPopup:NO];
    }
}

- (NSUInteger)lowerIndexForScaleFactor:(CGFloat)scale {
    NSUInteger i, count = BDSKDefaultScaleMenuFactorsCount;
    for (i = count - 1; i > 0; i--) {
        if (scale * 1.01 > BDSKDefaultScaleMenuFactors[i])
            return i;
    }
    return 1;
}

- (NSUInteger)upperIndexForScaleFactor:(CGFloat)scale {
    NSUInteger i, count = BDSKDefaultScaleMenuFactorsCount;
    for (i = 1; i < count; i++) {
        if (scale * 0.99 < BDSKDefaultScaleMenuFactors[i])
            return i;
    }
    return count - 1;
}

- (NSUInteger)indexForScaleFactor:(CGFloat)scale {
    NSUInteger lower = [self lowerIndexForScaleFactor:scaleFactor], upper = [self upperIndexForScaleFactor:scale];
    if (upper > lower && scale < 0.5 * (BDSKDefaultScaleMenuFactors[lower] + BDSKDefaultScaleMenuFactors[upper]))
        return lower;
    return upper;
}

- (CGFloat)scaleFactor {
    return scaleFactor;
}

- (void)setScaleFactor:(CGFloat)newScaleFactor {
	[self setScaleFactor:newScaleFactor adjustPopup:YES];
}

- (void)setScaleFactor:(CGFloat)newScaleFactor adjustPopup:(BOOL)flag {
	if (flag) {
            NSUInteger i = [self indexForScaleFactor:newScaleFactor];
            [scalePopUpButton selectItemAtIndex:i];
            newScaleFactor = BDSKDefaultScaleMenuFactors[i];
    }
	
	if (fabs(scaleFactor - newScaleFactor) > 0.01) {
        NSPoint scrollPoint = [self scrollPositionAsPercentage];
		
		scaleFactor = newScaleFactor;
		
        [self scaleUnitSquareToSize:[self convertSize:NSMakeSize(scaleFactor, scaleFactor) fromView:nil]];
        [self sizeToFit];
		[[NSNotificationCenter defaultCenter] postNotificationName:NSViewFrameDidChangeNotification object:self];
        [self setScrollPositionAsPercentage:scrollPoint]; // maintain approximate scroll position
        [[self superview] setNeedsDisplay:YES];
    }
}

- (IBAction)zoomToActualSize:(id)sender{
    [self setScaleFactor:1.0];
}

- (IBAction)zoomIn:(id)sender{
    NSUInteger numberOfDefaultItems = BDSKDefaultScaleMenuFactorsCount;
    NSUInteger i = [self lowerIndexForScaleFactor:[self scaleFactor]];
    if (i < numberOfDefaultItems - 1) i++;
    [self setScaleFactor:BDSKDefaultScaleMenuFactors[i]];
}

- (IBAction)zoomOut:(id)sender{
    NSUInteger i = [self upperIndexForScaleFactor:[self scaleFactor]];
    if (i > 1) i--;
    [self setScaleFactor:BDSKDefaultScaleMenuFactors[i]];
}

- (BOOL)canZoomToActualSize{
    return fabs(scaleFactor - 1.0) > 0.01;
}

- (BOOL)canZoomIn{
    NSUInteger numberOfDefaultItems = BDSKDefaultScaleMenuFactorsCount;
    NSUInteger i = [self lowerIndexForScaleFactor:[self scaleFactor]];
    return i < numberOfDefaultItems - 1;
}

- (BOOL)canZoomOut{
    NSUInteger i = [self upperIndexForScaleFactor:[self scaleFactor]];
    return i > 1;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem{
    if([menuItem action] == @selector(zoomIn:))
        return [self canZoomIn];
    else if([menuItem action] == @selector(zoomOut:))
        return [self canZoomOut];
    else if([menuItem action] == @selector(zoomToActualSize:))
        return [self canZoomToActualSize];
    else if ([NSScrollView instancesRespondToSelector:_cmd])
        return [super validateMenuItem:menuItem];
    return YES;
}

- (NSMenu *)menuForEvent:(NSEvent *)event{
    NSMenu *menu = [super menuForEvent:event];
    
    [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
    [menu insertItemWithTitle:NSLocalizedString(@"Zoom Out", @"Menu item title") action:@selector(zoomOut:) keyEquivalent:@"" atIndex:0];
    [menu insertItemWithTitle:NSLocalizedString(@"Zoom In", @"Menu item title") action:@selector(zoomIn:) keyEquivalent:@"" atIndex:0];
    [menu insertItemWithTitle:NSLocalizedString(@"Actual Size", @"Menu item title") action:@selector(zoomToActualSize:) keyEquivalent:@"" atIndex:0];
    
    return menu;
}

- (void)beginGestureWithEvent:(NSEvent *)theEvent {
    if ([[BDSKZoomableTextView superclass] instancesRespondToSelector:_cmd])
        [super beginGestureWithEvent:theEvent];
    pinchZoomFactor = 1.0;
}

- (void)endGestureWithEvent:(NSEvent *)theEvent {
    if (pinchZoomFactor > 1.1 || pinchZoomFactor < 0.9)
        [self setScaleFactor:fmax(pinchZoomFactor * [self scaleFactor], BDSKMinDefaultScaleMenuFactor)];
    pinchZoomFactor = 1.0;
    if ([[BDSKZoomableTextView superclass] instancesRespondToSelector:_cmd])
        [super endGestureWithEvent:theEvent];
}

- (void)magnifyWithEvent:(NSEvent *)theEvent {
    if ([theEvent respondsToSelector:@selector(magnification)]) {
        pinchZoomFactor *= 1.0 + fmax(-0.5, fmin(1.0 , [theEvent magnification]));
        CGFloat scale = pinchZoomFactor * [self scaleFactor];
        NSUInteger i = [self indexForScaleFactor:fmax(scale, BDSKMinDefaultScaleMenuFactor)];
        if (i != [self indexForScaleFactor:[self scaleFactor]]) {
            [self setScaleFactor:BDSKDefaultScaleMenuFactors[i]];
            pinchZoomFactor = scale / [self scaleFactor];
        }
    }
}

@end

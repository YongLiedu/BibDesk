//
//  FVSlider.m
//  FileView
//
//  Created by Adam Maxwell on 2/17/08.
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

#import "FVSlider.h"
#import "FVUtilities.h"
#import <QuartzCore/QuartzCore.h>

@interface FVSliderCell : NSSliderCell
@end

@implementation FVSliderCell

- (void)drawBarInside:(NSRect)aRect flipped:(BOOL)flipped
{
    [NSGraphicsContext saveGraphicsState];
    
    [[NSColor clearColor] setFill];
    NSRectFill(aRect);
    
    CGFloat radius = NSHeight(aRect) / 2;
    NSBezierPath *outerPath = [NSBezierPath fv_bezierPathWithRoundRect:aRect xRadius:radius yRadius:radius];
    CGFloat angle = flipped ? 90 : -90;
    Class gradientClass = NSClassFromString(@"NSGradient");
    
    [outerPath addClip];
    
    // border highlight
    [[NSColor colorWithCalibratedWhite:0.4 alpha:0.8] setStroke];
    [outerPath setLineWidth:1.5];
    [outerPath stroke];
    
    // draw a dark background
    if (gradientClass) {
        id gradient = [[[gradientClass alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.4 alpha:0.6] endingColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.6]] autorelease];
        [gradient drawInBezierPath:outerPath angle:angle];
    } else {
        [[NSColor colorWithCalibratedWhite:0.1 alpha:0.5] setFill];
        [outerPath fill];
    }
    
    // draw the track
    NSRect track = NSInsetRect(aRect, 4.0, 4.0);
    radius = NSHeight(track) / 2;
    NSBezierPath *innerPath = [NSBezierPath fv_bezierPathWithRoundRect:track xRadius:radius yRadius:radius];
    [innerPath addClip];
    if (gradientClass) {
        id gradient = [[[gradientClass alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.3] endingColor:[NSColor colorWithCalibratedWhite:0.3 alpha:0.3]] autorelease];
        [gradient drawInBezierPath:innerPath angle:angle];
    } else {
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.2] setFill];
        [innerPath fill];
    }
    
    // draw a dark outline for the track
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.2] setStroke];
    [innerPath setLineWidth:1.5];
    [innerPath stroke];
    [innerPath setLineWidth:1.0];
    
    // if we don't save/restore, the knob gets clipped
    [NSGraphicsContext restoreGraphicsState];
}

- (id)init
{
    self = [super init];
    [self setControlSize:NSMiniControlSize];
    return self;
}

@end

@implementation FVSlider

+ (Class)cellClass { return [FVSliderCell self]; }

- (id)initWithFrame:(NSRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self)
        _trackingTag = -1;
    return self;
}

- (void)drawRect:(NSRect)aRect
{
    if (-1 != _trackingTag)
        [self removeTrackingRect:_trackingTag];
    _trackingTag = [self addTrackingRect:[self bounds] owner:self userData:nil assumeInside:YES];  
    [super drawRect:aRect];
}

- (void)mouseExited:(NSEvent *)event
{
    [super mouseExited:event];
    [[[self window] parentWindow] removeChildWindow:[self window]];
    [(FVSliderWindow *)[self window] fadeOut:self];
}

@end

@implementation FVSliderWindow

- (id)init
{
    self = [super initWithContentRect:NSMakeRect(0,0,50,10) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];
    if (self) {
        [self setReleasedWhenClosed:NO];
        [self setBackgroundColor:[NSColor clearColor]];
        [self setOpaque:NO];
        [self setHasShadow:YES];
        _slider = [[FVSlider alloc] initWithFrame:NSMakeRect(0,0,50,10)];
        [_slider setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
        [[self contentView] addSubview:_slider];
        [_slider release];
        
        id animation = [NSClassFromString(@"CABasicAnimation") animation];
        if (animation && [self respondsToSelector:@selector(setAnimations:)]) {
            [self setAnimations:[NSDictionary dictionaryWithObject:animation forKey:@"alphaValue"]];
        }

    }
    return self;
}

- (FVSlider *)slider { return _slider; }

- (void)fadeIn:(id)sender {
    if ([self isVisible] == NO && [self respondsToSelector:@selector(animator)]) {
        [self setAlphaValue:0.0];
        [self orderFront:sender];
        [[self animator] setAlphaValue:1.0];
    } else {
        [self orderFront:sender];
    }
}

- (void)fadeOut:(id)sender {
    if ([self isVisible] && [self respondsToSelector:@selector(animator)]) {
        [[self animationForKey:@"alphaValue"] setDelegate:self];
        [[self animator] setAlphaValue:0.0];
    } else {
        [self orderOut:sender];
    }
}

- (void)orderOut:(id)sender {
    [[self parentWindow] removeChildWindow:self];
    [super orderOut:self];
}

- (void)animationDidStop:(id)animation finished:(BOOL)flag  {
    [self orderOut:self];
    [animation setDelegate:nil];
}

@end

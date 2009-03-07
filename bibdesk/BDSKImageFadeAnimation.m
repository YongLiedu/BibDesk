//
//  BDSKImageFadeAnimation.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/29/06.
/*
 This software is Copyright (c) 2006-2009
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

#import "BDSKImageFadeAnimation.h"
#import <QuartzCore/QuartzCore.h>

@implementation BDSKImageFadeAnimation

- (id)initWithDuration:(NSTimeInterval)duration animationCurve:(NSAnimationCurve)animationCurve;
{
    self = [super initWithDuration:duration animationCurve:animationCurve];
    if (self) {
        filter = [[CIFilter filterWithName:@"CIDissolveTransition"] retain];
        [filter setDefaults];
    }
    return self;
}

- (void)dealloc
{
    [filter release];
    [super dealloc];
}

- (void)setDelegate:(id)anObject
{
    // not much point in using the class if the delegate doesn't implement this method...
    NSAssert(nil == anObject || [anObject respondsToSelector:@selector(imageAnimationDidUpdate:)], @"Delegate must implement imageAnimationDidUpdate:");
    [super setDelegate:anObject];
}

- (void)setCurrentProgress:(NSAnimationProgress)progress;
{
    [super setCurrentProgress:progress];
    
    // -currentValue ranges 0--1.0 and accounts for the animation curve
    [filter setValue:[NSNumber numberWithFloat:[self currentValue]] forKey:@"inputTime"];
    [[self delegate] imageAnimationDidUpdate:self];
}

- (void)setStartingImage:(NSImage *)anImage;
{
    [filter setValue:[CIImage imageWithData:[anImage TIFFRepresentation]] forKey:@"inputImage"];
}

- (void)setTargetImage:(NSImage *)anImage;
{
    [filter setValue:[CIImage imageWithData:[anImage TIFFRepresentation]] forKey:@"inputTargetImage"];
}

- (NSImage *)finalImage;
{
    NSNumber *inputTime = [[[filter valueForKey:@"inputTime"] retain] autorelease];
    
    [filter setValue:[NSNumber numberWithInt:1] forKey:@"inputTime"];
    NSImage *currentImage = [self currentImage];
    
    // restore the input time, since calling -finalImage shouldn't interrupt the animation
    [filter setValue:inputTime forKey:@"inputTime"];
    return currentImage;
}

- (CIImage *)currentCIImage;
{
    return [filter valueForKey:@"outputImage"];
}

- (NSImage *)currentImage;
{ 
    NSImage *nsImage = nil;
    CIImage *ciImage = [filter valueForKey:@"outputImage"];
    if (nil != ciImage) {
        CGRect extent = [ciImage extent];
        NSRect sourceRect = *(NSRect *)&extent;
        NSRect targetRect = sourceRect;
        targetRect.origin = NSZeroPoint;
        
        nsImage = [[NSImage alloc] initWithSize:targetRect.size];
        [nsImage lockFocus];
        [ciImage drawInRect:targetRect fromRect:sourceRect operation:NSCompositeSourceOver fraction:1.0];
        [nsImage unlockFocus];
    }
    return [nsImage autorelease];
}

@end


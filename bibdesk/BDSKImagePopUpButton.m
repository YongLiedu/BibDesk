//
//  BDSKImagePopUpButton.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/22/05.
//
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

#import "BDSKImagePopUpButton.h"
#import "NSBezierPath_BDSKExtensions.h"
#import "BDSKImageFadeAnimation.h"

@implementation BDSKImagePopUpButton

+ (Class)cellClass{
    return [BDSKImagePopUpButtonCell class];
}

- (id)initWithFrame:(NSRect)frameRect {
	if (self = [super initWithFrame:frameRect]) {
		highlight = NO;
		delegate = nil;
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)coder{
	if (self = [super initWithCoder:coder]) {
		highlight = NO;
		[self setDelegate:[coder decodeObjectForKey:@"delegate"]];
		
		if (![[self cell] isKindOfClass:[BDSKImagePopUpButtonCell class]]) {
			BDSKImagePopUpButtonCell *cell = [[[BDSKImagePopUpButtonCell alloc] init] autorelease];
			
			if ([self image] != nil) {
				[cell setIconImage:[self image]];
				[cell setIconSize:[[self image] size]];
			}
			if ([self menu] != nil) {
				if ([self pullsDown])	
					[[self menu] removeItemAtIndex:0];
				[cell setMenu:[self menu]];
			}
			[self setCell:cell];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder{
	[super encodeWithCoder:encoder];
	[encoder encodeConditionalObject:delegate forKey:@"delegate"];
}

- (void)dealloc{
    [animation setDelegate:nil];
    [animation stopAnimation];
    [animation release];
	[super dealloc];
}

#pragma mark Accessors

- (id)delegate {
    return delegate;
}

- (void)setDelegate:(id)newDelegate {
	delegate = newDelegate;
}

- (NSSize)iconSize{
    return [[self cell] iconSize];
}

- (void) setIconSize:(NSSize)iconSize{
    [[self cell] setIconSize:iconSize];
}

- (NSImage *)iconImage{
    return [[self cell] iconImage];
}

- (void)animationDidStop:(BDSKImageFadeAnimation *)anAnimation {
    BDSKASSERT(anAnimation == animation);
    [animation setDelegate:nil];
    [animation autorelease];
    animation = nil;
}

- (void)animationDidEnd:(BDSKImageFadeAnimation *)anAnimation {
    BDSKASSERT(anAnimation == animation);
    [self setIconImage:[anAnimation finalImage]];
    [animation setDelegate:nil];
    [animation autorelease];
    animation = nil;
}

- (void)imageAnimationDidUpdate:(BDSKImageFadeAnimation *)anAnimation {
    [self setIconImage:[anAnimation currentImage]];
}

- (void)fadeIconImageToImage:(NSImage *)newImage {
    
    if ([animation isAnimating])
        [animation stopAnimation];
        
    NSImage *iconImage = [self iconImage];
    
    if (nil != iconImage && nil != newImage) {
        animation = [[BDSKImageFadeAnimation alloc] initWithDuration:1.0f animationCurve:NSAnimationEaseInOut];
        [animation setDelegate:self];
        [animation setAnimationBlockingMode:NSAnimationNonblocking];
        
        [animation setTargetImage:newImage];
        [animation setStartingImage:iconImage];
        [animation startAnimation];
    } else {
        [self setIconImage:newImage];
    }
}

- (void)setIconImage:(NSImage *)iconImage{
    [[self cell] setIconImage: iconImage];
}

- (NSImage *)arrowImage{
    return [[self cell] arrowImage];
}

- (void)setArrowImage:(NSImage *)arrowImage{
    [[self cell] setArrowImage: arrowImage];
}

#pragma mark Drawing and Highlighting

-(void)drawRect:(NSRect)rect {
	[super drawRect:rect];
	
	if (highlight)  {
        [NSGraphicsContext saveGraphicsState];
        [NSBezierPath drawHighlightInRect:[self bounds] radius:4.0 lineWidth:2.0 color:[NSColor alternateSelectedControlColor]];
        [NSGraphicsContext restoreGraphicsState];
	}
}

@end

//
//  BDSKSpotlightView.m
//  Bibdesk
//
//  Created by Adam Maxwell on 05/04/06.
/*
 This software is Copyright (c) 2006
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

#import "BDSKSpotlightView.h"
#import <QuartzCore/QuartzCore.h>

@implementation BDSKSpotlightView;

- (id)initWithFrame:(NSRect)frameRect delegate:(id)anObject;
{
    if(self = [super initWithFrame:frameRect]){
        [self setDelegate:anObject];
    }
    return self;
}

- (void)setDelegate:(id)anObject;
{
    NSParameterAssert([anObject conformsToProtocol:@protocol(BDSKSpotlightViewDelegate)]);
    delegate = anObject;
}

- (CIImage *)image
{
    NSImage *image = [[NSImage alloc] initWithSize:[self bounds].size];
    NSEnumerator *rectEnum = [[delegate highlightRects] objectEnumerator];
    NSValue *value;
    NSBezierPath *path = [NSBezierPath bezierPathWithRect:[self bounds]];
    [path setWindingRule:NSEvenOddWindingRule];
    
    while(value = [rectEnum nextObject]){
        [path appendBezierPathWithOvalInRect:[value rectValue]];
    }
    
    NSGraphicsContext *nsContext = [NSGraphicsContext currentContext];
    [nsContext saveGraphicsState];
    [image lockFocus];
    [[[NSColor blackColor] colorWithAlphaComponent:0.3] setFill];
    [path fill];
    [image unlockFocus];
    [nsContext restoreGraphicsState];
    
    CIImage *ciImage = [CIImage imageWithData:[image TIFFRepresentation]];
    [image release];
    
    static CIFilter *filter = nil;
    if(nil == filter){
        filter = [[CIFilter filterWithName:@"CIGaussianBlur"] retain];
        [filter setValue:[NSNumber numberWithInt:5] forKey:@"inputRadius"];
    }
    [filter setValue:ciImage forKey:@"inputImage"];
    
    return [filter valueForKey:@"outputImage"];
}

- (void)drawRect:(NSRect)aRect;
{
    if([delegate isSearchActive]){
        CIContext *ciContext = [[NSGraphicsContext currentContext] CIContext];
        [ciContext drawImage:[self image] atPoint:CGPointZero fromRect:CGRectMake(0,0,NSWidth([self bounds]),NSHeight([self bounds]))];
    } else {
        [[NSColor clearColor] setFill];
        NSRectFill(aRect);
    }
}

@end
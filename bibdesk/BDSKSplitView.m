//
//  BDSKSplitView.m
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

#import "BDSKSplitView.h"

// This class is basically a copy of OASplitView

@interface BDSKSplitView (BDSKPrivate)
- (void)didResizeSubviews:(NSNotification *)notification;
@end


@implementation BDSKSplitView

#pragma mark AutosaveName

- (id)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didResizeSubviews:) name:NSSplitViewDidResizeSubviewsNotification object:self];
    }
    return self;

}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didResizeSubviews:) name:NSSplitViewDidResizeSubviewsNotification object:self];
    }
    return self;

}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [positionAutosaveName release];
    [super dealloc];
}

- (NSString *)positionAutosaveName {
    return positionAutosaveName;
}

- (NSString *)positionAutosaveKey {
    return positionAutosaveName ? [@"BDSKSplitView Frame " stringByAppendingString:positionAutosaveName] : nil;
}

- (void)setPositionAutosaveName:(NSString *)name {
    if (positionAutosaveName != name) {
        [positionAutosaveName release];
        positionAutosaveName = [name retain];
        
        if ([NSString isEmptyString:positionAutosaveName] == NO) {
            NSArray *frameStrings = [[NSUserDefaults standardUserDefaults] arrayForKey:[self positionAutosaveKey]];
            if (frameStrings) {
                NSArray *subviews = [self subviews];
                unsigned int subviewCount = [subviews count];
                unsigned int frameCount = [frameStrings count];
                unsigned int i;

                // Walk through our subviews re-applying frames so we don't explode in the event that the archived frame strings become out of sync with our subview count
                for (i = 0; i < subviewCount && i < frameCount; i++)
                    [[subviews objectAtIndex:i] setFrame:NSRectFromString([frameStrings objectAtIndex:i])];
            }
        }
    }
}

- (void)didResizeSubviews:(NSNotification *)notification {
    if ([NSString isEmptyString:positionAutosaveName] == NO) {
        NSMutableArray *frameStrings = [NSMutableArray array];
        NSArray *subviews = [self subviews];
        unsigned int i, iMax = [subviews count];
        for (i = 0; i < iMax; i++)
            [frameStrings addObject:NSStringFromRect([[subviews objectAtIndex:i] frame])];
        [[NSUserDefaults standardUserDefaults] setObject:frameStrings forKey:[self positionAutosaveKey]];
    }
}

#pragma mark Double-click support

// arm: mouseDown: swallows mouseDragged: needlessly
- (void)mouseDown:(NSEvent *)theEvent {
    BOOL inDivider = NO;
    NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSArray *subviews = [self subviews];
    int i, count = [subviews count];
    id view;
    NSRect divRect;
    
    for (i = 0; i < count - 1; i++) {
        view = [subviews objectAtIndex:i];
        divRect = [view frame];
        if ([self isVertical]) {
            divRect.origin.x = NSMaxX(divRect);
            divRect.size.width = [self dividerThickness];
        } else {
            divRect.origin.y = NSMaxY(divRect);
            divRect.size.height = [self dividerThickness];
        }
        
        if (NSPointInRect(mouseLoc, divRect)) {
            inDivider = YES;
            break;
        }
    }
    
    if (inDivider) {
        if ([theEvent clickCount] > 1 && [[self delegate] respondsToSelector:@selector(splitView:doubleClickedDividerAt:)])
            [[self delegate] splitView:self doubleClickedDividerAt:i];
        else
            [super mouseDown:theEvent];
    } else {
        [[self nextResponder] mouseDown:theEvent];
    }
}

#pragma mark Fraction

- (float)horizontalDividerFraction {
    NSRect topFrame, bottomFrame;
    
    if ([[self subviews] count] < 2)
        return 0.0;
    
    topFrame = [[[self subviews] objectAtIndex:0] frame];
    bottomFrame = [[[self subviews] objectAtIndex:1] frame];
    return NSHeight(bottomFrame) / (NSHeight(bottomFrame) + NSHeight(topFrame));
}

- (void)setHorizontalDividerFraction:(float)newFraction {
    NSRect topFrame, bottomFrame;
    NSView *topSubView;
    NSView *bottomSubView;
    float totalHeight;
    
    if ([[self subviews] count] < 2)
        return;
    
    topSubView = [[self subviews] objectAtIndex:0];
    bottomSubView = [[self subviews] objectAtIndex:1];
    topFrame = [topSubView frame];
    bottomFrame = [bottomSubView frame];
    totalHeight = NSHeight(bottomFrame) + NSHeight(topFrame);
    bottomFrame.size.height = newFraction * totalHeight;
    topFrame.size.height = totalHeight - NSHeight(bottomFrame);
    [topSubView setFrame:topFrame];
    [bottomSubView setFrame:bottomFrame];
    [self adjustSubviews];
    [self setNeedsDisplay:YES];
}

- (float)verticalDividerFraction {
    NSRect leftFrame, rightFrame;
    
    if ([[self subviews] count] < 2)
        return 0.0;
    
    leftFrame = [[[self subviews] objectAtIndex:0] frame];
    rightFrame = [[[self subviews] objectAtIndex:1] frame];
    return NSWidth(rightFrame) / (NSWidth(rightFrame) + NSWidth(leftFrame));
}

- (void)setVerticalDividerFraction:(float)newFraction {
    NSRect leftFrame, rightFrame;
    NSView *leftSubView;
    NSView *rightSubView;
    float totalWidth;
    
    if ([[self subviews] count] < 2)
        return;
    
    leftSubView = [[self subviews] objectAtIndex:0];
    rightSubView = [[self subviews] objectAtIndex:1];
    leftFrame = [leftSubView frame];
    rightFrame = [rightSubView frame];
    totalWidth = NSWidth(rightFrame) + NSWidth(leftFrame);
    rightFrame.size.width = newFraction * totalWidth;
    leftFrame.size.width = totalWidth - NSWidth(rightFrame);
    [leftSubView setFrame:leftFrame];
    [rightSubView setFrame:rightFrame];
    [self adjustSubviews];
    [self setNeedsDisplay:YES];
}

- (float)fraction {
    return [self isVertical] ? [self verticalDividerFraction] : [self horizontalDividerFraction];
}

- (void)setFraction:(float)newFraction {
    if ([self isVertical])
        [self setVerticalDividerFraction:newFraction];
    else
        [self setHorizontalDividerFraction:newFraction];
}

@end

//
//  BDSKFormCell.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/7/05.
/*
 This software is Copyright (c) 2005,2006,2007
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

#import "BDSKFormCell.h"
#import "BDSKForm.h"
#import "BDSKComplexString.h"
#import "NSImage+Toolbox.h"
#import "NSGeometry_BDSKExtensions.h"
#import <OmniBase/OmniBase.h>

#define ICON_PADDING 4.0

static NSSize arrowImageSize;

@implementation BDSKFormCell

+ (void)initialize{
    
    OBINITIALIZE;
    
    arrowImageSize = [(NSImage *)[NSImage imageNamed:@"ArrowImage"] size];
}

// designated initializer
- (id)initTextCell:(NSString *)aString{
	if(self = [super initTextCell:aString]){
		buttonHighlighted = NO;
	}
	return self;
}

- (BOOL)buttonHighlighted {
    return buttonHighlighted;
}

- (void)setButtonHighlighted:(BOOL)highlighted {
    if (buttonHighlighted != highlighted) {
        buttonHighlighted = highlighted;
		[(NSControl *)[self controlView] updateCell:self];
    }
}

- (BOOL)hasArrowButton{
	id <BDSKFormDelegate>delegate = [[self controlView] delegate];
	return [delegate formCellHasArrowButton:self];
}

- (BDSKForm *)controlView{
    id controlView = [super controlView];
    OBPRECONDITION(controlView == nil || [controlView isKindOfClass:[BDSKForm class]]);
    return controlView;
}

# pragma mark Drawing methods

- (NSRect)buttonRectForBounds:(NSRect)theRect{
	NSRect buttonRect = NSZeroRect;
	
	if([self hasArrowButton]){
        buttonRect = BDSKCenterRect(theRect, arrowImageSize, YES);
		buttonRect.origin.x = NSMaxX(theRect) - arrowImageSize.width - ICON_PADDING;
	}
	return buttonRect;
}

// returns the rect in which the cell's value text is drawn
- (NSRect)titleRectForBounds:(NSRect)theRect{
    NSRect ignored, rect = [self drawingRectForBounds:theRect];
    NSDivideRect(rect, &rect, &ignored, [self titleWidth], NSMinXEdge);
    return rect;
}

// returns the rect in which the cell's value text is drawn
- (NSRect)textRectForBounds:(NSRect)theRect{
    NSRect ignored, rect = [self drawingRectForBounds:theRect];
    NSDivideRect(rect, &ignored, &rect, [self titleWidth], NSMinXEdge);
    return rect;
}

// override this to get the rect in which the text (title + value) is drawn
- (NSRect)drawingRectForBounds:(NSRect)theRect{
	NSRect rect = [super drawingRectForBounds:theRect];
    
	if([self hasArrowButton]){
        NSRect textRect;
        NSRect imageRect;
        NSDivideRect(rect, &imageRect, &textRect, arrowImageSize.width + ICON_PADDING, NSMaxXEdge);
        return textRect;
	}
	
	return rect;
}

// this method is actually called by NSMatrix
- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView{    
    
    if(!NSIntersectsRect(cellFrame, [controlView visibleRect]))
        return;
    
    [super drawWithFrame:cellFrame inView:controlView];

    OBASSERT([[(BDSKForm *)controlView delegate] conformsToProtocol:@protocol(BDSKFormDelegate)]);

	NSImage *buttonImage;
    NSRect buttonRect = [self buttonRectForBounds:cellFrame]; 

    if([self hasArrowButton]){
        if(buttonHighlighted)
            buttonImage = [NSImage imageNamed:@"ArrowImage_Pressed"];
        else
            buttonImage = [NSImage imageNamed:@"ArrowImage"];
        [controlView lockFocus];
        [buttonImage drawFlippedInRect:buttonRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [controlView unlockFocus];
    }

}

@end
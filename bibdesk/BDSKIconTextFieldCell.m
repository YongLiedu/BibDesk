//
//  BDSKIconTextFieldCell.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/11/09.
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

#import "BDSKIconTextFieldCell.h"
#import "NSGeometry_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"


@implementation BDSKIconTextFieldCell

#define BORDER_BETWEEN_EDGE_AND_IMAGE_BORDERLESS (1.0)
#define BORDER_BETWEEN_IMAGE_AND_TEXT_BORDERLESS (0.0)
#define BORDER_BETWEEN_EDGE_AND_IMAGE_BORDERED (2.0)
#define BORDER_BETWEEN_IMAGE_AND_TEXT_BORDERED (-1.0)
#define BORDER_BETWEEN_EDGE_AND_IMAGE_BEZELED (3.0)
#define BORDER_BETWEEN_IMAGE_AND_TEXT_BEZELED (-2.0)
#define IMAGE_OFFSET (1.0)

- (id)initTextCell:(NSString *)aString {
    if (self = [super initTextCell:aString]) {
        imageCell = [[NSImageCell alloc] init];
        [imageCell setImageScaling:NSImageScaleProportionallyUpOrDown];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    BDSKIconTextFieldCell *copy = [super copyWithZone:zone];
    copy->imageCell = [imageCell copyWithZone:zone];
    return copy;
}

- (void)dealloc {
    BDSKDESTROY(imageCell);
    [super dealloc];
}

- (void)setBackgroundStyle:(NSBackgroundStyle)style {
    [super setBackgroundStyle:style];
    [imageCell setBackgroundStyle:style];
}

- (NSSize)cellSize {
    NSSize cellSize = [super cellSize];
    if ([self isBordered])
        cellSize.width += cellSize.height - BORDER_BETWEEN_EDGE_AND_IMAGE_BORDERED + BORDER_BETWEEN_IMAGE_AND_TEXT_BORDERED;
    else if ([self isBezeled])
        cellSize.width += cellSize.height - BORDER_BETWEEN_EDGE_AND_IMAGE_BEZELED + BORDER_BETWEEN_IMAGE_AND_TEXT_BEZELED;
    else
        cellSize.width += cellSize.height - 1 + BORDER_BETWEEN_EDGE_AND_IMAGE_BORDERLESS + BORDER_BETWEEN_IMAGE_AND_TEXT_BORDERLESS;
    return cellSize;
}

- (void)drawIconWithFrame:(NSRect)iconRect inView:(NSView *)controlView {
    NSImage *img = [self icon];
    if (nil != img) {
        [imageCell setImage:img];
        [imageCell drawInteriorWithFrame:iconRect inView:controlView];
    }
}

- (NSRect)textRectForBounds:(NSRect)aRect {
    NSRect ignored, textRect = aRect;
    CGFloat border;
    
    if ([self isBordered])
        border = NSHeight(aRect) - BORDER_BETWEEN_EDGE_AND_IMAGE_BORDERED + BORDER_BETWEEN_IMAGE_AND_TEXT_BORDERED;
    if ([self isBezeled])
        border = NSHeight(aRect) - BORDER_BETWEEN_EDGE_AND_IMAGE_BEZELED + BORDER_BETWEEN_IMAGE_AND_TEXT_BEZELED;
    else
        border = NSHeight(aRect) - 1 + BORDER_BETWEEN_EDGE_AND_IMAGE_BORDERLESS + BORDER_BETWEEN_IMAGE_AND_TEXT_BORDERLESS;
    
    NSDivideRect(aRect, &ignored, &textRect, border, NSMinXEdge);
    
    return textRect;
}

- (NSRect)iconRectForBounds:(NSRect)aRect {
    CGFloat border, imageWidth;
    NSRect ignored, imageRect = aRect;
    
    if ([self isBordered]) {
        border = BORDER_BETWEEN_EDGE_AND_IMAGE_BORDERED;
        imageWidth = NSHeight(aRect) - 2.0 * border;
    } else if ([self isBezeled]) {
        // if we ever want to support round bezels we should increase the border here
        border = BORDER_BETWEEN_EDGE_AND_IMAGE_BEZELED;
        imageWidth = NSHeight(aRect) - 2.0 * border;
    } else {
        border = BORDER_BETWEEN_EDGE_AND_IMAGE_BORDERLESS;
        imageWidth = NSHeight(aRect) - 1;
    }
    
    NSDivideRect(aRect, &ignored, &imageRect, border, NSMinXEdge);
    NSDivideRect(imageRect, &imageRect, &ignored, imageWidth, NSMinXEdge);
    
    return imageRect;
}

- (void)drawInteriorWithFrame:(NSRect)aRect inView:(NSView *)controlView {
    // let super draw the text, but vertically center the text for tall cells, because NSTextFieldCell aligns at the top
    NSRect textRect = [self textRectForBounds:aRect];
    if (NSHeight(textRect) > [self cellSize].height + 2.0)
        textRect = BDSKCenterRectVertically(textRect, [self cellSize].height + 2.0, [controlView isFlipped]);
    [super drawInteriorWithFrame:textRect inView:controlView];
    
    // Draw the image
    NSRect imageRect = [self iconRectForBounds:aRect];
    imageRect = BDSKCenterRectVertically(imageRect, NSWidth(imageRect), [controlView isFlipped]);
    if ([self isBordered] == NO && [self isBezeled] == NO)
        imageRect.origin.y += [controlView isFlipped] ? -IMAGE_OFFSET : IMAGE_OFFSET;
    [self drawIconWithFrame:imageRect inView:controlView];
}

// this is supposed to be implemented by subclasses
- (NSImage *)icon {
    return nil;
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength {
    [super selectWithFrame:[self textRectForBounds:aRect] inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (NSUInteger)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView {
    NSRect textRect = [self textRectForBounds:cellFrame];
    NSPoint mouseLoc = [controlView convertPoint:[event locationInWindow] fromView:nil];
    NSUInteger hit = NSCellHitNone;
    if (NSMouseInRect(mouseLoc, textRect, [controlView isFlipped]))
        hit = [super hitTestForEvent:event inRect:textRect ofView:controlView];
    else if (NSMouseInRect(mouseLoc, [self iconRectForBounds:cellFrame], [controlView isFlipped]))
        hit = NSCellHitContentArea;
    return hit;
}

@end

#pragma mark -

@implementation BDSKConcreteIconTextFieldCell

- (NSImage *)icon {
    return [imageCell image];
}

- (void)setIcon:(NSImage *)newIcon {
    if ([imageCell image] != newIcon) {
        [imageCell setImage:newIcon];
        [(NSControl *)[self controlView] updateCellInside:self];
    }
}

@end

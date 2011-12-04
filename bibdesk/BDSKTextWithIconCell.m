//
//  BDSKTextWithIconCell.m
//  Bibdesk
//
//  Created by Adam Maxwell on 12/10/05.
/*
 This software is Copyright (c) 2005-2011
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

#import "BDSKTextWithIconCell.h"
#import "NSGeometry_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"

NSString *BDSKTextWithIconCellStringKey = @"string";
NSString *BDSKTextWithIconCellImageKey = @"image";

static id nonNullObjectValueForKey(id object, id stringObject, NSString *key) {
    if ([object isKindOfClass:[NSString class]])
        return stringObject;
    id value = [object valueForKey:key];
    return [value isEqual:[NSNull null]] ? nil : value;
}

@implementation BDSKTextWithIconCell

#define BORDER_BETWEEN_EDGE_AND_IMAGE_BORDERLESS (1.0)
#define BORDER_BETWEEN_IMAGE_AND_TEXT_BORDERLESS (0.0)
#define BORDER_BETWEEN_EDGE_AND_IMAGE_BORDERED (2.0)
#define BORDER_BETWEEN_IMAGE_AND_TEXT_BORDERED (-1.0)
#define BORDER_BETWEEN_EDGE_AND_IMAGE_BEZELED (3.0)
#define BORDER_BETWEEN_IMAGE_AND_TEXT_BEZELED (-2.0)
#define IMAGE_OFFSET (1.0)

+ (Class)formatterClass {
    return [BDSKTextWithIconFormatter class];
}

- (void)commonInit {
    if (imageCell == nil) {
        imageCell = [[NSImageCell alloc] init];
        [imageCell setImageScaling:NSImageScaleProportionallyUpOrDown];
    }
    if ([self formatter] == nil && [[self class] formatterClass])
        [self setFormatter:[[[[[self class] formatterClass] alloc] init] autorelease]];
}

- (id)initTextCell:(NSString *)aString {
    self = [super initTextCell:aString];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        imageCell = [[decoder decodeObjectForKey:@"imageCell"] retain];
        [self commonInit];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:imageCell forKey:@"imageCell"];
}

- (id)copyWithZone:(NSZone *)zone {
    BDSKTextWithIconCell *copy = [super copyWithZone:zone];
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
    // Draw the image
    NSRect imageRect = [self iconRectForBounds:aRect];
    imageRect = BDSKCenterRectVertically(imageRect, NSWidth(imageRect), [controlView isFlipped]);
    if ([self isBordered] == NO && [self isBezeled] == NO)
        imageRect.origin.y += [controlView isFlipped] ? -IMAGE_OFFSET : IMAGE_OFFSET;
    [imageCell drawInteriorWithFrame:imageRect inView:controlView];
    
    // let super draw the text, but vertically center the text for tall cells, because NSTextFieldCell aligns at the top
    NSRect textRect = [self textRectForBounds:aRect];
    if (NSHeight(textRect) > [self cellSize].height + 2.0)
        textRect = BDSKCenterRectVertically(textRect, [self cellSize].height + 2.0, [controlView isFlipped]);
    [super drawInteriorWithFrame:textRect inView:controlView];
}

- (NSImage *)icon {
    return [imageCell image];
}

- (void)setIcon:(NSImage *)newIcon {
    if ([imageCell image] != newIcon) {
        [imageCell setImage:newIcon];
        [(NSControl *)[self controlView] updateCellInside:self];
    }
}

- (void)setObjectValue:(id <NSCopying>)obj {
    [super setObjectValue:obj];
    if ([[self formatter] respondsToSelector:@selector(imageForObjectValue:)])
        [self setIcon:[[self formatter] imageForObjectValue:obj]];
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

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    return nil;
}

@end

#pragma mark -

@implementation BDSKTextWithIconFormatter

- (NSImage *)imageForObjectValue:(id)obj {
    return nonNullObjectValueForKey(obj, nil, BDSKTextWithIconCellImageKey);
}

- (NSString *)stringForObjectValue:(id)obj {
    return nonNullObjectValueForKey(obj, obj, BDSKTextWithIconCellStringKey);
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error {
    // even though 'string' is reported as immutable, it's actually changed after this method returns and before it's returned by the control!
    string = [[string copy] autorelease];
    *obj = [NSDictionary dictionaryWithObjectsAndKeys:string, BDSKTextWithIconCellStringKey, nil];
    return YES;
}

@end

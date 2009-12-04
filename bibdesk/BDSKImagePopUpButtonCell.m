//
//  BDSKImagePopUpButtonCell.m
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

#import "BDSKImagePopUpButtonCell.h"
#import "BDSKImagePopUpButton.h"


@implementation BDSKImagePopUpButtonCell

+ (NSImage *)arrowImage {
    static NSImage *arrowImage = nil;
    if (arrowImage == nil) {
        arrowImage = [[NSImage alloc] initWithSize:NSMakeSize(7.0, 5.0)];
        [arrowImage lockFocus];
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(0.5, 5.0)];
        [path lineToPoint:NSMakePoint(6.5, 5.0)];
        [path lineToPoint:NSMakePoint(3.5, 0.0)];
        [path closePath];
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.75] setFill];
        [path fill];
        [arrowImage unlockFocus];
    }
    return arrowImage;
}

- (void)makeButtonCell {
    buttonCell = [[NSButtonCell allocWithZone:[self zone]] initTextCell: @""];
    [buttonCell setBordered: NO];
    [buttonCell setHighlightsBy: NSContentsCellMask];
    [buttonCell setImagePosition: NSImageLeft];
    [buttonCell setEnabled:[self isEnabled]];
    [buttonCell setShowsFirstResponder:[self showsFirstResponder]];
}

// this used to be the designated intializer
- (id)initTextCell:(NSString *)stringValue pullsDown:(BOOL)pullsDown{
    return [self initImageCell:nil];
}

// this is now the designated intializer
- (id)initImageCell:(NSImage *)anImage{
    if (self = [super initTextCell:@"" pullsDown:YES]) {
		[self makeButtonCell];
        icon = [anImage retain];
        iconSize = icon ? [icon size] : NSMakeSize(32.0, 32.0);
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder{
	if (self = [super initWithCoder:coder]) {
		[self makeButtonCell];
		icon = [[coder decodeObjectForKey:@"icon"] retain];
		iconSize = [coder decodeSizeForKey:@"iconSize"];
		// hack to always get regular controls in a toolbar customization palette, there should be a better way
		[self setControlSize:NSRegularControlSize];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder{
	[super encodeWithCoder:encoder];
	[encoder encodeObject:icon forKey:@"icon"];
	[encoder encodeSize:iconSize forKey:@"iconSize"];
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKImagePopUpButtonCell *copy = [super copyWithZone:aZone];
    [copy makeButtonCell];
    copy->icon = [icon copyWithZone:aZone];
    copy->iconSize = iconSize;
    return copy;
}

- (void)dealloc{
    BDSKDESTROY(buttonCell);
    BDSKDESTROY(icon);
    [super dealloc];
}

#pragma mark Accessors

- (NSSize)iconSize {
    return iconSize;
}

- (void)setIconSize:(NSSize)newIconSize {
    if (NSEqualSizes(iconSize, newIconSize) == NO) {
        iconSize = newIconSize;
        [buttonCell setImage:nil];
    }
}

- (NSImage *)icon {
    return icon;
}

- (void)setIcon:(NSImage *)anImage{
    if (icon != anImage) {
        [icon release];
        icon = [anImage retain];
        [buttonCell setImage:nil]; // invalidate the image
    }
}

- (void)setArrowPosition:(NSPopUpArrowPosition)position {
    [super setArrowPosition:position];
    [buttonCell setImage:nil]; // invalidate the image
}

- (void)setEnabled:(BOOL)flag {
	[super setEnabled:flag];
	[buttonCell setEnabled:flag];
}

- (void)setShowsFirstResponder:(BOOL)flag{
	[super setShowsFirstResponder:flag];
	[buttonCell setShowsFirstResponder:flag];
}

- (void)setUsesItemFromMenu:(BOOL)flag{
	[super setUsesItemFromMenu:flag];
	[buttonCell setImage:nil]; // invalidate the image
}

- (void)setControlSize:(NSControlSize)size {
    [super setControlSize:size];
    [buttonCell setImage:nil]; // invalidate the image
}

- (void)setBackgroundStyle:(NSBackgroundStyle)style {
    [super setBackgroundStyle:style];
    [buttonCell setBackgroundStyle:style];
    [buttonCell setImage:nil]; // invalidate the image
}

#pragma mark Drawing and highlighting

- (NSSize)iconDrawSize {
	NSSize size = iconSize;
	if ([self controlSize] != NSRegularControlSize) {
		// for small and mini controls we just scale the icon by 75% 
		size = NSMakeSize(size.width * 0.75, size.height * 0.75);
	}
	return size;
}

- (NSSize)cellSize {
	NSSize size = [self iconDrawSize];
	if ([self arrowPosition] != NSPopUpNoArrow) {
		size.width += [[[self class] arrowImage] size].width;
	}
	return size;
}

- (void)drawWithFrame:(NSRect)cellFrame  inView:(NSView *)controlView{
	if ([buttonCell image] == nil || [self usesItemFromMenu]) {
		// we need to redraw the image
        
		NSImage *img = [self usesItemFromMenu] ? [[self selectedItem] image] : [self icon];
        NSImage *popUpImage = nil;
        NSSize drawSize = [self iconDrawSize];
        
        if ([self arrowPosition] == NSPopUpNoArrow && NSEqualSizes([img size], drawSize)) {
            popUpImage = [img retain];
        } else {
            NSRect iconRect = NSZeroRect;
            NSRect iconDrawRect = NSZeroRect;
            NSRect arrowRect = NSZeroRect;
            NSRect arrowDrawRect = NSZeroRect;
            
            iconRect.size = [img size];
            iconDrawRect.size = drawSize;
            if ([self arrowPosition] != NSPopUpNoArrow) {
                arrowRect.size = arrowDrawRect.size = [[[self class] arrowImage] size];
                arrowDrawRect.origin = NSMakePoint(NSWidth(iconDrawRect), 1.0);
                drawSize.width += NSWidth(arrowRect);
            }
            
            popUpImage = [[NSImage alloc] initWithSize: drawSize];
            [popUpImage lockFocus];
            if (img)
                [img drawInRect: iconDrawRect  fromRect: iconRect  operation: NSCompositeSourceOver  fraction: 1.0];
            if ([self arrowPosition] != NSPopUpNoArrow)
                [[[self class] arrowImage] drawInRect: arrowDrawRect  fromRect: arrowRect  operation: NSCompositeSourceOver  fraction: 1.0];
            [popUpImage unlockFocus];
        }
        
		[buttonCell setImage: popUpImage];
		[popUpImage release];
    }
	//   NSLog(@"cellFrame: %@  selectedItem: %@", NSStringFromRect(cellFrame), [[self selectedItem] title]);
	
    [buttonCell drawWithFrame: cellFrame  inView: controlView];
}

- (void)highlight:(BOOL)flag  withFrame:(NSRect)cellFrame  inView:(NSView *)controlView{
	[buttonCell highlight: flag  withFrame: cellFrame  inView: controlView];
	[super highlight: flag  withFrame: cellFrame  inView: controlView];
}

@end

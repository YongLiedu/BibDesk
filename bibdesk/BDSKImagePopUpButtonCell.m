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
#import "NSCharacterSet_BDSKExtensions.h"

@interface BDSKImagePopUpButtonCell (Private)

- (void)setButtonCell:(NSButtonCell *)buttonCell;
//- (void)showMenuInView:(NSView *)controlView withEvent:(NSEvent *)event;
- (NSSize)iconDrawSize;

@end

@implementation BDSKImagePopUpButtonCell

// this used to be the designated intializer
- (id)initTextCell:(NSString *)stringValue pullsDown:(BOOL)pullsDown{
    self = [self initImageCell:nil];
    return self;
}

// this is now the designated intializer
- (id)initImageCell:(NSImage *)anImage{
    if (self = [super initTextCell:@"" pullsDown:YES]) {
		NSButtonCell *cell = [[NSButtonCell alloc] initTextCell: @""];
		[cell setBordered: NO];
		[cell setHighlightsBy: NSContentsCellMask];
		[cell setImagePosition: NSImageLeft];
        [self setButtonCell:cell];
        [cell release];
		
		iconSize = NSMakeSize(32.0, 32.0);
        
        static NSImage *defaultArrowImage = nil;
        if (defaultArrowImage == nil) {
            defaultArrowImage = [[NSImage alloc] initWithSize:NSMakeSize(7.0, 5.0)];
            [defaultArrowImage lockFocus];
            NSBezierPath *path = [NSBezierPath bezierPath];
            [path moveToPoint:NSMakePoint(0.5, 5.0)];
            [path lineToPoint:NSMakePoint(6.5, 5.0)];
            [path lineToPoint:NSMakePoint(3.5, 0.0)];
            [path closePath];
            [[NSColor colorWithCalibratedWhite:0.0 alpha:0.75] setFill];
            [path fill];
            [defaultArrowImage unlockFocus];
        }
        
		[self setIconImage: anImage];	
		[self setArrowImage: defaultArrowImage];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder{
	if (self = [super initWithCoder:coder]) {
        [self setButtonCell:[coder decodeObjectForKey:@"buttonCell"]];
		
		iconSize = [coder decodeSizeForKey:@"iconSize"];
		
		[self setIconImage:[coder decodeObjectForKey:@"iconImage"]];
		[self setArrowImage:[coder decodeObjectForKey:@"arrowImage"]];
		
		// hack to always get regular controls in a toolbar customization palette, there should be a better way
		[self setControlSize:NSRegularControlSize];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder{
	[super encodeWithCoder:encoder];
	[encoder encodeObject:buttonCell forKey:@"buttonCell"];
	
	[encoder encodeSize:iconSize forKey:@"iconSize"];
	
	[encoder encodeObject:iconImage forKey:@"iconImage"];
	
	[encoder encodeObject:arrowImage forKey:@"arrowImage"];
}

- (void)dealloc{
    [self setButtonCell:nil]; // release the ivar and set to nil, or [super dealloc] causes a crash
    [iconImage release];
    [arrowImage release];
    [super dealloc];
}

#pragma mark Accessors

- (NSSize)iconSize{
    return iconSize;
}

- (void)setIconSize:(NSSize)aSize{
    iconSize = aSize;
	[buttonCell setImage:nil]; // invalidate the image
}

- (NSImage *)iconImage{
    return iconImage;
}

- (void)setIconImage:(NSImage *)anImage{
    if (anImage != iconImage) {
        [iconImage release];
        iconImage = [anImage retain];
        [buttonCell setImage:nil]; // invalidate the image
        [(NSControl *)[self controlView] updateCell:self];
    }
}

- (NSImage *)arrowImage{
    return arrowImage;
}

- (void)setArrowImage:(NSImage *)anImage{
    if (anImage != iconImage) {
        [arrowImage release];
        arrowImage = [anImage retain];
        [buttonCell setImage:nil]; // invalidate the image
        [(NSControl *)[self controlView] updateCell:self];
    }
}

- (void)setAlternateImage:(NSImage *)anImage{
	[super setAlternateImage:anImage];
	[buttonCell setAlternateImage:nil]; // invalidate the image
	[buttonCell setImage:nil]; // invalidate the image
}

- (BOOL)isEnabled {
	return [buttonCell isEnabled];
}

- (void)setEnabled:(BOOL)flag {
	[buttonCell setEnabled:flag];
}

- (BOOL)showsFirstResponder{
	return [buttonCell showsFirstResponder];
}

- (void)setShowsFirstResponder:(BOOL)flag{
	[buttonCell setShowsFirstResponder:flag];
}

- (void)setUsesItemFromMenu:(BOOL)flag{
	[super setUsesItemFromMenu:flag];
	[buttonCell setImage:nil]; // invalidate the image
}

#pragma mark Drawing and highlighting

- (NSSize)cellSize {
	NSSize size = [self iconDrawSize];
	if ([self arrowImage]) {
		size.width += [[self arrowImage] size].width;
	}
	return size;
}

- (void)drawWithFrame:(NSRect)cellFrame  inView:(NSView *)controlView{
	if ([buttonCell image] == nil || [self usesItemFromMenu]) {
		// we need to redraw the image

		NSImage *image = [self usesItemFromMenu] ? [[self selectedItem] image] : [self iconImage];
				
		NSSize drawSize = [self iconDrawSize];
		NSRect iconRect = NSZeroRect;
		NSRect iconDrawRect = NSZeroRect;
		NSRect arrowRect = NSZeroRect;
		NSRect arrowDrawRect = NSZeroRect;
 		
		iconRect.size = [image size];
		iconDrawRect.size = drawSize;
		if (arrowImage) {
			arrowRect.size = arrowDrawRect.size = [arrowImage size];
			arrowDrawRect.origin = NSMakePoint(NSWidth(iconDrawRect), 1.0);
			drawSize.width += NSWidth(arrowRect);
		}
		
		NSImage *popUpImage = [[NSImage alloc] initWithSize: drawSize];
		
		[popUpImage lockFocus];
		if (image)
			[image drawInRect: iconDrawRect  fromRect: iconRect  operation: NSCompositeSourceOver  fraction: 1.0];
		if (arrowImage)
			[arrowImage drawInRect: arrowDrawRect  fromRect: arrowRect  operation: NSCompositeSourceOver  fraction: 1.0];
		[popUpImage unlockFocus];

		[buttonCell setImage: popUpImage];
		[popUpImage release];
		
		if ([self alternateImage]) {
			popUpImage = [[NSImage alloc] initWithSize: drawSize];
			
			[popUpImage lockFocus];
			[[self alternateImage] drawInRect: iconDrawRect  fromRect: iconRect  operation: NSCompositeSourceOver  fraction: 1.0];
			if (arrowImage)
				[arrowImage drawInRect: arrowDrawRect  fromRect: arrowRect  operation: NSCompositeSourceOver  fraction: 1.0];
			[popUpImage unlockFocus];
		
			[buttonCell setAlternateImage: popUpImage];
			[popUpImage release];
		}
    }
	//   NSLog(@"cellFrame: %@  selectedItem: %@", NSStringFromRect(cellFrame), [[self selectedItem] title]);
	
    [buttonCell drawWithFrame: cellFrame  inView: controlView];
}

- (void)highlight:(BOOL)flag  withFrame:(NSRect)cellFrame  inView:(NSView *)controlView{
	[buttonCell highlight: flag  withFrame: cellFrame  inView: controlView];
	[super highlight: flag  withFrame: cellFrame  inView: controlView];
}

@end

@implementation BDSKImagePopUpButtonCell (Private)

- (void)setButtonCell:(NSButtonCell *)aCell{
    if(aCell != buttonCell){
        [buttonCell release];
        buttonCell = [aCell retain];
    }
}

- (NSSize)iconDrawSize {
	NSSize size = [self iconSize];
	if ([self controlSize] != NSRegularControlSize) {
		// for small and mini controls we just scale the icon by 75% 
		size = NSMakeSize(size.width * 0.75, size.height * 0.75);
	}
	return size;
}

@end

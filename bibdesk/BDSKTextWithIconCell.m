//
//  BDSKTextWithIconCell.m
//  Bibdesk
//
//  Created by Adam Maxwell on 12/10/05.
/*
 This software is Copyright (c) 2005-2009
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
#import "NSFileManager_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import "NSLayoutManager_BDSKExtensions.h"

/* Almost all of this code is copy-and-paste from OATextWithIconCell, except for the text layout (which seems wrong in OATextWithIconCell). */

@implementation BDSKTextWithIconCell

// Init and dealloc

- (id)init;
{
    if (self = [super initTextCell:@""]) {
        [self setImagePosition:NSImageLeft];
        [self setEditable:YES];
        [self setDrawsHighlight:YES];
        [self setScrollable:YES];
        [self setLineBreakMode:NSLineBreakByTruncatingTail];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder;
{
    if (self = [super initWithCoder:coder]) {
        [self setImagePosition:NSImageLeft];
        [self setDrawsHighlight:YES];
    }
    return self;
}

- (void)dealloc;
{
    [icon release];
    [super dealloc];
}

// NSCopying protocol

- (id)copyWithZone:(NSZone *)zone;
{
    BDSKTextWithIconCell *copy = [super copyWithZone:zone];
    
    copy->icon = [icon retain];
    copy->_oaFlags.drawsHighlight = _oaFlags.drawsHighlight;
    
    return copy;
}

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
{
    NSColor *color = nil;
    if (_oaFlags.drawsHighlight && [self drawsBackground])
        color = [super highlightColorWithFrame:cellFrame inView:controlView];
    return color;
}

- (NSColor *)textColor;
{
    NSColor *color = nil;
    
    // this allows the expansion tooltips on 10.5 to draw with the correct color
#if defined(MAC_OS_X_VERSION_10_5) && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
    // on 10.5, we can just check background style instead of messing around with flags and checking the highlight color, which accounts for much of the code in this class
#warning 10.5 fixme
#endif
    if ([self respondsToSelector:@selector(backgroundStyle)]) {
        NSBackgroundStyle style = [self backgroundStyle];
        if (NSBackgroundStyleLight == style)
            return (!_oaFlags.drawsHighlight && _cFlags.highlighted) ? [NSColor textBackgroundColor] : [NSColor blackColor];
    }
        
    if (_oaFlags.settingUpFieldEditor)
        color = [NSColor blackColor];
    else if (!_oaFlags.drawsHighlight && _cFlags.highlighted)
        color = [NSColor textBackgroundColor];
    else
        color = [super textColor];
    return color;
}

#define BORDER_BETWEEN_EDGE_AND_IMAGE (1.0)
#define BORDER_BETWEEN_IMAGE_AND_TEXT (0.0)

- (NSSize)cellSize;
{
    NSSize cellSize = [super cellSize];
    cellSize.width += cellSize.height + BORDER_BETWEEN_EDGE_AND_IMAGE + BORDER_BETWEEN_IMAGE_AND_TEXT;
    return cellSize;
}

- (void)drawIconWithFrame:(NSRect)iconRect inView:(NSView *)controlView
{
    NSImage *img = [self icon];
    
    if (nil != img) {
        
        NSRect srcRect = NSZeroRect;
        srcRect.size = [img size];
        
        NSRect drawFrame = iconRect;
        
        // NSImage will use the largest rep if it doesn't find an exact size match; we can improve on that by choosing the next larger one with respect to our drawing rect, and scaling it down.
        NSBitmapImageRep *rep = [img bestImageRepForSize:drawFrame.size device:nil];
        
        // draw the image rep directly to avoid creating a new NSImage and adding the rep to it
        if (0 && rep) {
            
            srcRect.size = [rep size];
            float ratio = fminf(NSWidth(drawFrame) / srcRect.size.width, NSHeight(drawFrame) / srcRect.size.height);
            drawFrame.size.width = ratio * srcRect.size.width;
            drawFrame.size.height = ratio * srcRect.size.height;
            
            drawFrame = BDSKCenterRect(drawFrame, drawFrame.size, [controlView isFlipped]);
            
            CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
            CGContextSaveGState(context);
            CGContextClipToRect(context, *(CGRect *)&drawFrame);
            CGContextSetAllowsAntialiasing(context, true);
            CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
            
            // draw into a new layer so we preserve the background of the tableview
            CGContextBeginTransparencyLayer(context, NULL);
            
            if ([controlView isFlipped]) {
                CGContextTranslateCTM(context, 0, NSMaxY(drawFrame));
                CGContextScaleCTM(context, 1, -1);
                drawFrame.origin.y = 0;
                [rep drawInRect:drawFrame];
            } else {
                [rep drawInRect:drawFrame];
            }
            
            CGContextEndTransparencyLayer(context);
            CGContextRestoreGState(context);
            
        } else {
            
            float ratio = MIN(NSWidth(drawFrame) / srcRect.size.width, NSHeight(drawFrame) / srcRect.size.height);
            drawFrame.size.width = ratio * srcRect.size.width;
            drawFrame.size.height = ratio * srcRect.size.height;
            
            drawFrame = BDSKCenterRect(drawFrame, drawFrame.size, [controlView isFlipped]);
            
            NSGraphicsContext *ctxt = [NSGraphicsContext currentContext];
            [ctxt saveGraphicsState];
            
            // this is the critical part that NSImageCell doesn't do
            [ctxt setImageInterpolation:NSImageInterpolationHigh];
            
            if ([controlView isFlipped])
                [img drawFlippedInRect:drawFrame fromRect:srcRect operation:NSCompositeSourceOver fraction:1.0];
            else
                [img drawInRect:drawFrame fromRect:srcRect operation:NSCompositeSourceOver fraction:1.0];
            
            [ctxt restoreGraphicsState];
        }
    }
}

- (NSRect)textRectForBounds:(NSRect)aRect;
{
    NSRectEdge rectEdge; 
    float imageWidth = 0.0;

    if (_oaFlags.imagePosition == NSImageLeft) {
        rectEdge = NSMinXEdge;
        imageWidth = NSHeight(aRect) - 1;
    } else {
        rectEdge =  NSMaxXEdge;
        if (icon)
            imageWidth = [icon size].width;
    }

    NSRect ignored, textRect = aRect;
    if (imageWidth > 0)
        NSDivideRect(aRect, &ignored, &textRect, BORDER_BETWEEN_EDGE_AND_IMAGE + imageWidth + BORDER_BETWEEN_IMAGE_AND_TEXT, rectEdge);
    
    return textRect;
}

- (NSRect)iconRectForBounds:(NSRect)aRect;
{
    NSRectEdge rectEdge; 
    float imageWidth = 0.0;

    if (_oaFlags.imagePosition == NSImageLeft) {
        rectEdge = NSMinXEdge;
        imageWidth = NSHeight(aRect) - 1;
    } else {
        rectEdge =  NSMaxXEdge;
        if (icon == nil)
            imageWidth = [icon size].width;
    }

    NSRect ignored, imageRect = aRect;
    if (imageWidth > 0)
        NSDivideRect(aRect, &ignored, &imageRect, BORDER_BETWEEN_EDGE_AND_IMAGE, rectEdge);

    NSDivideRect(imageRect, &imageRect, &ignored, imageWidth, rectEdge);
    
    return imageRect;
}

- (void)drawWithFrame:(NSRect)aRect inView:(NSView *)controlView;
{
    // let super draw the text, but vertically center the text for tall cells, because NSTextFieldCell aligns at the top
    NSRect textRect = [self textRectForBounds:aRect];
    if (NSHeight(textRect) > [self cellSize].height + 2.0)
        textRect = BDSKCenterRectVertically(textRect, [self cellSize].height + 2.0, [controlView isFlipped]);
    [super drawWithFrame:textRect inView:controlView];
    
    // Draw the image
    NSRect imageRect = [self iconRectForBounds:aRect];
    float imageHeight = 0.0;
    if (_oaFlags.imagePosition == NSImageLeft)
        imageHeight = NSHeight(aRect) - 1;
    else if (icon == nil)
        imageHeight = [icon size].height;
    imageRect = BDSKCenterRectVertically(imageRect, imageHeight, [controlView isFlipped]);
    [self drawIconWithFrame:imageRect inView:controlView];
}

- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)flag;
{
    return [super trackMouse:theEvent inRect:cellFrame ofView:controlView untilMouseUp:flag];
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent;
{
    _oaFlags.settingUpFieldEditor = YES;
    [super editWithFrame:aRect inView:controlView editor:textObj delegate:anObject event:theEvent];
    _oaFlags.settingUpFieldEditor = NO;
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength;
{
    _oaFlags.settingUpFieldEditor = YES;
    [super selectWithFrame:[self textRectForBounds:aRect] inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
    _oaFlags.settingUpFieldEditor = NO;
}

- (void)setObjectValue:(id <NSCopying>)obj;
{
    [self setIcon:[(NSObject *)obj valueForKey:OATextWithIconCellImageKey]];
    [super setObjectValue:[(NSObject *)obj valueForKey:OATextWithIconCellStringKey]];
}

// API

- (NSImage *)icon;
{
    return icon;
}

- (void)setIcon:(NSImage *)anIcon;
{
    if (anIcon == icon)
        return;
    [icon release];
    icon = [anIcon retain];
}

- (NSCellImagePosition)imagePosition;
{
    return _oaFlags.imagePosition;
}

- (void)setImagePosition:(NSCellImagePosition)aPosition;
{
    _oaFlags.imagePosition = aPosition;
}

- (BOOL)drawsHighlight;
{
    return _oaFlags.drawsHighlight;
}

- (void)setDrawsHighlight:(BOOL)flag;
{
    _oaFlags.drawsHighlight = flag;
}

@end


@implementation BDSKFilePathCell

- (id)init;
{
    if (self = [super init]) {
        [self setDisplayType:1];
        [self setLineBreakMode:NSLineBreakByTruncatingMiddle];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder;
{
    if (self = [super initWithCoder:coder]) {
        [self setDisplayType:1];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone;
{
    BDSKFilePathCell *copy = (BDSKFilePathCell *)[super copyWithZone:zone];
    [copy setDisplayType:displayType];
    return copy;
}

- (int)displayType { return displayType; }

- (void)setDisplayType:(int)type { displayType = type; }

- (void)setObjectValue:(id <NSObject, NSCopying>)obj;
{
    NSString *path = nil;
    NSImage *image = nil;
    
    if ([obj isKindOfClass:[NSString class]]) {
        path = [(NSString *)obj stringByStandardizingPath];
        if(path && [[NSFileManager defaultManager] fileExistsAtPath:path])
            image = [NSImage imageForFile:path];
    } else if ([obj isKindOfClass:[NSURL class]]) {
        NSURL *fileURL = (NSURL *)obj;
        path = [fileURL path];
        if([[NSFileManager defaultManager] objectExistsAtFileURL:fileURL])
            image = [NSImage imageForURL:fileURL];
    } else if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)obj;
        if ([[dict objectForKey:OATextWithIconCellStringKey] isKindOfClass:[NSString class]]) {
            path = [[dict objectForKey:OATextWithIconCellStringKey] stringByStandardizingPath];
            image = [dict objectForKey:OATextWithIconCellImageKey];
            if(image == nil && path && [[NSFileManager defaultManager] fileExistsAtPath:path])
                image = [NSImage imageForFile:path];
        } else {
            [super setObjectValue:dict];
            return;
        }
    } else {
        [super setObjectValue:obj];
        return;
    }
    
	NSString *displayPath = path;
    switch (displayType) {
        case 0:
            displayPath = path;
            break;
        case 1:
            displayPath = [path stringByAbbreviatingWithTildeInPath];
            break;
        case 2:
            displayPath = [path lastPathComponent];
    }
	if(image && displayPath){
		NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                displayPath, OATextWithIconCellStringKey, 
                                image, OATextWithIconCellImageKey, nil];
        [super setObjectValue:dict];
	} else {
        [super setObjectValue:displayPath];
	}
}

@end

/* Category that implements -[NSObject valueForKey:] with OATextWithIconCellStringKey and OATextWithIconCellImageKey, so we can use any object that is KVC-compliant for -string or -attributedString and -image.  However, this breaks objects that provide these values via valueForUndefinedKey:, so it's a bad idea to pollute NSObject like this.

We should probably change the definition of OATextWithIconCell*Key to have a prefix on it since -image or -attributedString are common method names.
 */
/*
@interface NSObject (BDSKTextWithIconCell) @end
@implementation NSObject (BDSKTextWithIconCell)
- (id)string { return nil; }
- (id)image { return nil; }
@end
*/

// special cases for strings
@interface NSString (BDSKTextWithIconCell) @end
@implementation NSString (BDSKTextWithIconCell)
- (NSString *)string { return self; }
- (id)image { return nil; }
@end

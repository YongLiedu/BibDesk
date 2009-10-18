//
//  NSImage_BDSKExtensions.m
//  BibDesk
//
//  Created by Sven-S. Porst on Thu Jul 29 2004.
/*
 This software is Copyright (c) 2004-2009
 Sven-S. Porst. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Sven-S. Porst nor the names of any
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

#import "NSImage_BDSKExtensions.h"
#import "NSBezierPath_BDSKExtensions.h"
#import "NSAttributedString_BDSKExtensions.h"
#import "CIImage_BDSKExtensions.h"

@implementation NSImage (BDSKExtensions)

+ (void)drawAddBadgeAtPoint:(NSPoint)point {
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(point.x + 2.5, point.y + 6.5)];
    [path relativeLineToPoint:NSMakePoint(4.0, 0.0)];
    [path relativeLineToPoint:NSMakePoint(0.0, -4.0)];
    [path relativeLineToPoint:NSMakePoint(3.0, 0.0)];
    [path relativeLineToPoint:NSMakePoint(0.0, 4.0)];
    [path relativeLineToPoint:NSMakePoint(4.0, 0.0)];
    [path relativeLineToPoint:NSMakePoint(0.0, 3.0)];
    [path relativeLineToPoint:NSMakePoint(-4.0, 0.0)];
    [path relativeLineToPoint:NSMakePoint(0.0, 4.0)];
    [path relativeLineToPoint:NSMakePoint(-3.0, 0.0)];
    [path relativeLineToPoint:NSMakePoint(0.0, -4.0)];
    [path relativeLineToPoint:NSMakePoint(-4.0, 0.0)];
    [path closePath];
    
    NSShadow *shadow1 = [[NSShadow alloc] init];
    [shadow1 setShadowBlurRadius:1.0];
    [shadow1 setShadowOffset:NSMakeSize(0.0, 0.0)];
    [shadow1 setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.5]];
    
    [NSGraphicsContext saveGraphicsState];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:1.0] setFill];
    [path fill];
    [shadow1 set];
    [[NSColor colorWithCalibratedRed:0.257 green:0.351 blue:0.553 alpha:1.0] setStroke];
    [path stroke];
    [NSGraphicsContext restoreGraphicsState];
    
    [shadow1 release];
}

+ (void)makePreviewDisplayImages {
    static NSImage *previewDisplayTextImage = nil;
    static NSImage *previewDisplayFilesImage = nil;
    static NSImage *previewDisplayTeXImage = nil;
    
    if (previewDisplayTextImage == nil) {
        NSBezierPath *path;
        
        previewDisplayTextImage = [[NSImage alloc] initWithSize:NSMakeSize(11.0, 10.0)];
        [previewDisplayTextImage lockFocus];
        path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(0.0, 0.5)];
        [path lineToPoint:NSMakePoint(11.0, 0.5)];
        [path moveToPoint:NSMakePoint(0.0, 3.5)];
        [path lineToPoint:NSMakePoint(11.0, 3.5)];
        [path moveToPoint:NSMakePoint(0.0, 6.5)];
        [path lineToPoint:NSMakePoint(11.0, 6.5)];
        [path moveToPoint:NSMakePoint(0.0, 9.5)];
        [path lineToPoint:NSMakePoint(11.0, 9.5)];
        [path stroke];
        [previewDisplayTextImage unlockFocus];
        [previewDisplayTextImage setName:@"BDSKPreviewDisplayText"];
        
        previewDisplayFilesImage = [[NSImage alloc] initWithSize:NSMakeSize(11.0, 10.0)];
        [previewDisplayFilesImage lockFocus];
        path = [NSBezierPath bezierPath];
        [path appendBezierPathWithRect:NSMakeRect(0.5, 0.5, 3.0, 3.0)];
        [path appendBezierPathWithRect:NSMakeRect(7.5, 0.5, 3.0, 3.0)];
        [path appendBezierPathWithRect:NSMakeRect(0.5, 6.5, 3.0, 3.0)];
        [path appendBezierPathWithRect:NSMakeRect(7.5, 6.5, 3.0, 3.0)];
        [path stroke];
        [previewDisplayFilesImage unlockFocus];
        [previewDisplayFilesImage setName:@"BDSKPreviewDisplayFiles"];
        
        previewDisplayTeXImage = [[NSImage alloc] initWithSize:NSMakeSize(11.0, 10.0)];
        [previewDisplayTeXImage lockFocus];
        path = [NSBezierPath bezierPath];
        [path appendBezierPathWithOvalInRect:NSMakeRect(1.5, 1.5, 3.0, 3.0)];
        [path appendBezierPathWithOvalInRect:NSMakeRect(6.5, 1.5, 3.0, 3.0)];
        [path moveToPoint:NSMakePoint(6.5, 3.0)];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(5.5, 3.0) radius:1.0 startAngle:0.0 endAngle:180.0];
        [path moveToPoint:NSMakePoint(1.5, 3.0)];
        [path lineToPoint:NSMakePoint(0.5, 3.0)];
        [path appendBezierPathWithArcFromPoint:NSMakePoint(2.5, 10.0) toPoint:NSMakePoint(4.5, 8.0) radius:1.0];
        [path moveToPoint:NSMakePoint(9.5, 3.0)];
        [path lineToPoint:NSMakePoint(10.5, 3.0)];
        [path appendBezierPathWithArcFromPoint:NSMakePoint(8.5, 10.0) toPoint:NSMakePoint(6.5, 8.0) radius:1.0];
        [path stroke];
        [previewDisplayTeXImage unlockFocus];
        [previewDisplayTeXImage setName:@"BDSKPreviewDisplayTeX"];
    }
}

+ (NSImage *)addBookmarkToolbarImage {
    static NSImage *image = nil;
    if (image == nil) {
        image = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
        [image lockFocus];
        [[self imageNamed:@"Bookmark"] drawInRect:NSMakeRect(0.0, 0.0, 32.0, 32.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
        [[self class] drawAddBadgeAtPoint:NSMakePoint(18.0, 18.0)];
        [image unlockFocus];
    }
    return image;
}

+ (NSImage *)addFolderToolbarImage {
    static NSImage *image = nil;
    if (image == nil) {
        image = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
        [image lockFocus];
        [[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)] drawInRect:NSMakeRect(0.0, 0.0, 32.0, 32.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
        [[self class] drawAddBadgeAtPoint:NSMakePoint(18.0, 18.0)];
        [image unlockFocus];
    }
    return image;
}

+ (NSImage *)menuIcon
{
    static NSImage *menuIcon = nil;
    if (menuIcon == nil) {
        menuIcon = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
        NSShadow *s = [[[NSShadow alloc] init] autorelease];
        [s setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.33333]];
        [s setShadowBlurRadius:2.0];
        [s setShadowOffset:NSMakeSize(0.0, -1.0)];
        [menuIcon lockFocus];
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.2] set];
        [NSBezierPath fillRect:NSMakeRect(1.0, 1.0, 14.0, 13.0)];
        [NSGraphicsContext saveGraphicsState];
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(2.0, 2.0)];
        [path lineToPoint:NSMakePoint(2.0, 15.0)];
        [path lineToPoint:NSMakePoint(7.0, 15.0)];
        [path lineToPoint:NSMakePoint(7.0, 13.0)];
        [path lineToPoint:NSMakePoint(14.0, 13.0)];
        [path lineToPoint:NSMakePoint(14.0, 2.0)];
        [path closePath];
        [[NSColor whiteColor] set];
        [s set];
        [path fill];
        [NSGraphicsContext restoreGraphicsState];
        [[NSColor colorWithCalibratedRed:0.162 green:0.304 blue:0.755 alpha:1.0] set];
        NSRectFill(NSMakeRect(2.0, 13.0, 5.0, 2.0));
        [[NSColor colorWithCalibratedRed:0.894 green:0.396 blue:0.202 alpha:1.0] set];
        NSRectFill(NSMakeRect(3.0, 4.0, 1.0, 1.0));
        NSRectFill(NSMakeRect(3.0, 7.0, 1.0, 1.0));
        NSRectFill(NSMakeRect(3.0, 10.0, 1.0, 1.0));
        [[NSColor colorWithCalibratedWhite:0.6 alpha:1.0] set];
        NSRectFill(NSMakeRect(5.0, 4.0, 1.0, 1.0));
        NSRectFill(NSMakeRect(5.0, 7.0, 1.0, 1.0));
        NSRectFill(NSMakeRect(5.0, 10.0, 1.0, 1.0));
        NSUInteger i, j;
        for (i = 0; i < 7; i++) {
            for (j = 0; j < 3; j++) {
                [[NSColor colorWithCalibratedWhite:0.45 + 0.1 * rand() / RAND_MAX alpha:1.0] set];
                NSRectFill(NSMakeRect(6.0 + i, 4.0 + 3.0 * j, 1.0, 1.0));
            }
        }
        NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] endingColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.0]] autorelease];
        [gradient drawInRect:NSMakeRect(2.0, 2.0, 12.0,11.0) angle:90.0];
        [menuIcon unlockFocus];
    }
    return menuIcon;
}

+ (NSImage *)addSeparatorToolbarImage {
    static NSImage *image = nil;
    if (image == nil) {
        image = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
        [image lockFocus];
        [NSGraphicsContext saveGraphicsState];
        [[NSColor clearColor] setFill];
        NSRectFill(NSMakeRect(0.0, 0.0, 32.0, 32.0));
        NSShadow *shadow1 = [[[NSShadow alloc] init] autorelease];
        [shadow1 setShadowBlurRadius:2.0];
        [shadow1 setShadowOffset:NSMakeSize(0.0, -1.0)];
        [shadow1 setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.5]];
        [shadow1 set];
        [[NSColor colorWithCalibratedWhite:0.35 alpha:1.0] setFill];
        NSBezierPath *path = [NSBezierPath bezierPathWithRect:NSMakeRect(2.0, 14.0, 28.0, 4.0)];
        [path fill];
        [NSGraphicsContext restoreGraphicsState];
        [NSGraphicsContext saveGraphicsState];
        [[NSColor colorWithCalibratedWhite:0.65 alpha:1.0] setFill];
        path = [NSBezierPath bezierPathWithRect:NSMakeRect(3.0, 15.0, 26.0, 2.0)];
        [path fill];
        [[NSColor colorWithCalibratedWhite:0.8 alpha:1.0] setFill];
        path = [NSBezierPath bezierPathWithRect:NSMakeRect(4.0, 16.0, 24.0, 1.0)];
        [path fill];
        [[NSColor colorWithCalibratedWhite:0.45 alpha:1.0] setFill];
        path = [NSBezierPath bezierPathWithRect:NSMakeRect(3.0, 17.0, 26.0, 1.0)];
        [path fill];
        [[self class] drawAddBadgeAtPoint:NSMakePoint(18.0, 14.0)];
        [NSGraphicsContext restoreGraphicsState];
        [image unlockFocus];
    }
    return image;
}

+ (NSImage *)cautionImage {
    static NSImage *image = nil;
    if (image == nil) {
        image = [[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kAlertCautionIcon)] copy];
        [image setName:@"BDSKCautionIcon"];
	}
    return image;
}

+ (NSImage *)missingFileImage {
    static NSImage *image = nil;
    if (image == nil) {
        image = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
        NSImage *genericDocImage = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
        NSImage *questionMark = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kQuestionMarkIcon)];
        [image lockFocus];
        [genericDocImage drawInRect:NSMakeRect(0.0, 0.0, 32.0, 32.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:0.7];
        [questionMark compositeToPoint:NSMakePoint(6, 4) operation:NSCompositeSourceOver fraction:0.7];
        [image unlockFocus];
        NSImage *tinyImage = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
        [tinyImage lockFocus];
        [genericDocImage drawInRect:NSMakeRect(0.0, 0.0, 16.0, 16.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:0.7];
        [questionMark compositeToPoint:NSMakePoint(3.0, 2.0) operation:NSCompositeSourceOver fraction:0.7];
        [tinyImage unlockFocus];
        [image addRepresentation:[[tinyImage representations] lastObject]];
        [tinyImage release];
    }
    return image;
}

+ (NSImage *)imageForURL:(NSURL *)aURL{
    if (aURL == nil)
        return nil;
    else if ([aURL isFileURL])
        return [[NSWorkspace sharedWorkspace] iconForFile:[aURL path]];
    
    NSString *scheme = [aURL scheme];
    OSType typeCode = kInternetLocationGenericIcon;
    
    if([scheme caseInsensitiveCompare:@"http"] == NSOrderedSame || [scheme caseInsensitiveCompare:@"https"] == NSOrderedSame)
        typeCode = kInternetLocationHTTPIcon;
    else if([scheme caseInsensitiveCompare:@"ftp"] == NSOrderedSame)
        typeCode = kInternetLocationFTPIcon;
    else if([scheme caseInsensitiveCompare:@"mailto"] == NSOrderedSame)
        typeCode = kInternetLocationMailIcon;
    else if([scheme caseInsensitiveCompare:@"news"] == NSOrderedSame)
        typeCode = kInternetLocationNewsIcon;
    
    return [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(typeCode)];
}

static NSImage *createPaperclipImageWithColor(NSColor *color) {
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
    [image setBackgroundColor:[NSColor clearColor]];
    
    NSAffineTransform *t = [NSAffineTransform transform];
    [t rotateByDegrees:-45.0];
    [t translateXBy:-4.0 yBy:10.0];
    
    // start at the outside (right) and work inward
    NSBezierPath *path = [NSBezierPath bezierPath];    
    [path moveToPoint:NSMakePoint(10.0, 18.0)];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(5.0, 4.0) radius:5.0 startAngle:0.0 endAngle:180.0 clockwise:YES];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(3.0, 22.0) radius:3.5 startAngle:180.0 endAngle:0.0 clockwise:YES];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(5.0, 8.0) radius:2.0 startAngle:0.0 endAngle:180.0 clockwise:YES];
    [path lineToPoint:NSMakePoint(3.0, 18.0)];
    
    [image lockFocus];
    [t concat];
    [color setStroke];
    [path setLineWidth:1.0];
    [path stroke];
    [image unlockFocus];
    
    NSImage *tinyImage = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
    [tinyImage setBackgroundColor:[NSColor clearColor]];
    
    t = [NSAffineTransform transform];
    [t rotateByDegrees:-45.0];
    [t scaleBy:0.5];
    [t translateXBy:-4.0 yBy:10.0];
    
    [tinyImage lockFocus];
    [t concat];
    [color setStroke];
    [path stroke];
    [tinyImage unlockFocus];
    
    [image addRepresentation:[[tinyImage representations] lastObject]];
    [tinyImage release];
    
    return image;
}

+ (NSImage *)paperclipImage;
{
    static NSImage *image = nil;
    if(image == nil) {
        image = createPaperclipImageWithColor([NSColor blackColor]);
        [image setTemplate:YES];
    }
    return image;
}

+ (NSImage *)redPaperclipImage;
{
    static NSImage *image = nil;
    if(image == nil)
        image = createPaperclipImageWithColor([NSColor redColor]);
    return image;
}

- (NSImage *)dragImageWithCount:(NSInteger)count;
{
    return [self dragImageWithCount:count inside:NO isIcon:YES];
}

- (NSImage *)dragImageWithCount:(NSInteger)count inside:(BOOL)inside isIcon:(BOOL)isIcon;
{
    NSImage *labeledImage;
    NSRect sourceRect = {NSZeroPoint, [self size]};
    NSSize size = isIcon ? NSMakeSize(32.0, 32.0) : [self size];
    NSRect targetRect = {NSZeroPoint, size};
    
    if (count > 1) {
        
        NSAttributedString *countString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%ld", (long)count]
                                            attributeName:NSForegroundColorAttributeName attributeValue:[NSColor whiteColor]] autorelease];
        NSRect countRect = {NSZeroPoint, [countString size]};
        CGFloat countOffset;
        
        countOffset = BDSKFloor(0.5f * NSHeight(countRect)); // make sure the cap radius is integral
        countRect.size.height = 2.0 * countOffset;
        
        if (inside) {
            // large image, draw it inside the corner
            countRect.origin = NSMakePoint(NSMaxX(targetRect) - NSWidth(countRect) - countOffset - 2.0, 3.0);
        } else {
            // small image, draw it outside the corner
            countRect.origin = NSMakePoint(NSMaxX(targetRect), 0.0);
            size.width += NSWidth(countRect) + countOffset;
            size.height += countOffset;
            targetRect.origin.y += countOffset;
        }
        
        labeledImage = [[[NSImage alloc] initWithSize:size] autorelease];
        
        [labeledImage lockFocus];
        
        [self drawInRect:targetRect fromRect:sourceRect operation:NSCompositeCopy fraction:1.0];
        
        // draw a count of the rows being dragged, similar to Mail.app
        [[NSColor redColor] setFill];
        [NSBezierPath fillHorizontalOvalInRect:NSInsetRect(countRect, -0.5 * NSHeight(countRect), 0.0)];
        [countString drawInRect:countRect];
        
        [labeledImage unlockFocus];
        
        sourceRect.size = size;
        targetRect.size = size;
        targetRect.origin = NSZeroPoint;
        
    } else {
        
        labeledImage = self;
        
    }
	
    NSImage *dragImage = [[NSImage alloc] initWithSize:size];
	
	[dragImage lockFocus];
	[labeledImage drawInRect:targetRect fromRect:sourceRect operation:NSCompositeCopy fraction:0.7];
	[dragImage unlockFocus];
	
	return [dragImage autorelease];
}

static NSComparisonResult compareImageRepWidths(NSBitmapImageRep *r1, NSBitmapImageRep *r2, void *ctxt)
{
    NSSize s1 = [r1 size];
    NSSize s2 = [r2 size];
    if (NSEqualSizes(s1, s2))
        return NSOrderedSame;
    return s1.width > s2.width ? NSOrderedDescending : NSOrderedAscending;
}

- (NSBitmapImageRep *)bestImageRepForSize:(NSSize)preferredSize device:(NSDictionary *)deviceDescription
{
    // We need to get the correct color space, or we can end up with a mask image in some cases
    NSString *preferredColorSpaceName = [[self bestRepresentationForDevice:deviceDescription] colorSpaceName];

    // sort the image reps by increasing width, so we can easily pick the next largest one
    NSMutableArray *reps = [[self representations] mutableCopy];
    [reps sortUsingFunction:compareImageRepWidths context:NULL];
    NSUInteger i, iMax = [reps count];
    NSBitmapImageRep *toReturn = nil;
    
    for (i = 0; i < iMax && nil == toReturn; i++) {
        NSBitmapImageRep *rep = [reps objectAtIndex:i];
        BOOL hasPreferredColorSpace = [[rep colorSpaceName] isEqualToString:preferredColorSpaceName];
        NSSize size = [rep size];
        
        if (hasPreferredColorSpace) {
            if (NSEqualSizes(size, preferredSize))
                toReturn = rep;
            else if (size.width > preferredSize.width)
                toReturn = rep;
        }
    }
    [reps release];
    return toReturn;    
}

- (void)drawFlipped:(BOOL)isFlipped inRect:(NSRect)dstRect fromRect:(NSRect)srcRect operation:(NSCompositingOperation)op fraction:(CGFloat)delta {
    if (isFlipped) {
        [NSGraphicsContext saveGraphicsState];
        NSAffineTransform *transform = [NSAffineTransform transform];
        [transform translateXBy:0.0 yBy:NSMaxY(dstRect)];
        [transform scaleXBy:1.0 yBy:-1.0];
        [transform translateXBy:0.0 yBy:-NSMinY(dstRect)];
        [transform concat];
        [self drawInRect:dstRect fromRect:srcRect operation:op fraction:delta];
        [NSGraphicsContext restoreGraphicsState];
    } else {
        [self drawInRect:dstRect fromRect:srcRect operation:op fraction:delta];
    }
}

@end

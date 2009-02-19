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
#import <OmniFoundation/OmniFoundation.h>
#import <OmniAppKit/IconFamily.h>
#import "NSBezierPath_BDSKExtensions.h"

@implementation NSImage (BDSKExtensions)

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

+ (NSImage *)httpInternetLocationImage {
    static NSImage *image = nil;
    if (image == nil) {
        IconFamily *iconFamily = [[IconFamily alloc] initWithSystemIcon:kInternetLocationHTTPIcon];
        image = [[iconFamily imageWithAllReps] retain];
        [iconFamily release];
    }
    return image;
}

+ (NSImage *)ftpInternetLocationImage {
    static NSImage *image = nil;
    if (image == nil) {
        IconFamily *iconFamily = [[IconFamily alloc] initWithSystemIcon:kInternetLocationFTPIcon];
        image = [[iconFamily imageWithAllReps] retain];
        [iconFamily release];
    }
    return image;
}

+ (NSImage *)mailInternetLocationImage {
    static NSImage *image = nil;
    if (image == nil) {
        IconFamily *iconFamily = [[IconFamily alloc] initWithSystemIcon:kInternetLocationMailIcon];
        image = [[iconFamily imageWithAllReps] retain];
        [iconFamily release];
    }
    return image;
}

+ (NSImage *)newsInternetLocationImage {
    static NSImage *image = nil;
    if (image == nil) {
        IconFamily *iconFamily = [[IconFamily alloc] initWithSystemIcon:kInternetLocationNewsIcon];
        image = [[iconFamily imageWithAllReps] retain];
        [iconFamily release];
    }
    return image;
}

+ (NSImage *)genericInternetLocationImage {
    static NSImage *image = nil;
    if (image == nil) {
        IconFamily *iconFamily = [[IconFamily alloc] initWithSystemIcon:kInternetLocationGenericIcon];
        image = [[iconFamily imageWithAllReps] retain];
        [iconFamily release];
    }
    return image;
}

+ (NSImage *)iconWithSize:(NSSize)iconSize forToolboxCode:(OSType) code {
	int width = iconSize.width;
	int height = iconSize.height;
	IconRef iconref;
	OSErr myErr = GetIconRef (kOnSystemDisk, kSystemIconsCreator, code, &iconref);
	
	NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(width,height)]; 
	[image lockFocus]; 
	
	CGRect rect =  CGRectMake(0,0,width,height);
	
	PlotIconRefInContext((CGContextRef)[[NSGraphicsContext currentContext] graphicsPort],
                         &rect,
						 kAlignAbsoluteCenter, //kAlignNone,
						 kTransformNone,
						 NULL /*inLabelColor*/,
						 kPlotIconRefNormalFlags,
						 iconref); 
	[image unlockFocus]; 
	
	myErr = ReleaseIconRef(iconref);
	
	[image autorelease];	
	return image;
}

+ (NSImage *)imageWithSmallIconForToolboxCode:(OSType) code {
    /* ssp: 30-07-2004 
    
	A category on NSImage that creates an NSImage containing an icon from the system specified by an OSType.
    LIMITATION: This always creates 32x32 images as are useful for toolbars.
    
	Code taken from http://cocoa.mamasam.com/MACOSXDEV/2002/01/2/22427.php
    */
    
    return [self iconWithSize:NSMakeSize(32,32) forToolboxCode:code];
}

+ (NSImage *)smallMissingFileImage {
    static NSImage *image = nil;
    if(image == nil){
        image = [[NSImage alloc] initWithSize:NSMakeSize(32, 32)];
        NSImage *genericDocImage = [self iconWithSize:NSMakeSize(32, 32) forToolboxCode:kGenericDocumentIcon];
        NSImage *questionMark = [self iconWithSize:NSMakeSize(20, 20) forToolboxCode:kQuestionMarkIcon];
        [image lockFocus];
        [genericDocImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy fraction:0.7];
        [questionMark compositeToPoint:NSMakePoint(6, 4) operation:NSCompositeSourceOver fraction:0.7];
        [image unlockFocus];
    }
    return image;
}

+ (NSImage *)imageForURL:(NSURL *)aURL{
    
    if(!aURL) return nil;

    if([aURL isFileURL])
        return [self imageForFile:[aURL path]];
    
    NSString *scheme = [aURL scheme];
    
    if([scheme isEqualToString:@"http"])
        return [self httpInternetLocationImage];
    else if([scheme isEqualToString:@"ftp"])
        return [self ftpInternetLocationImage];
    else if([scheme isEqualToString:@"mailto"])
        return [self mailInternetLocationImage];
    else if([scheme isEqualToString:@"news"])
        return [self newsInternetLocationImage];
    else return [self genericInternetLocationImage];
}

+ (NSImage *)imageForFile:(NSString *)path{
    
    /* It turns out that -[NSWorkspace iconForFileType:] doesn't cache previously returned values, so we cache them here.  Mainly useful for tableview datasource methods.  
     
     This caching is problematic in that it 
     a) doesn't allow for per-file application bindings 
     b) if the user changes a LS binding while this app is open, we still show the stale value
     c) custom icons are not handled correctly
     d) it doesn't consider the custom file opening pref that overrides LS (there's no way to account for that)
     
     */
    
    static NSMutableDictionary *imageDictionary = nil;
    id image = nil;
    
    if (!path)
        return nil;
   
    // if no file type, we'll just cache the path and waste some memory
    if (imageDictionary == nil)
        imageDictionary = [[NSMutableDictionary alloc] init];
    
    NSString *pathExtension = [path pathExtension];
    
#if defined(MAC_OS_X_VERSION_10_5) && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5  // Uses API deprecated on 10.5
#warning Omni disables IconFamily on 10.5
   // .app is a valid path extension to pass here, but we must not cache the icon based on that extension!
    if(![pathExtension isEqualToString:@""] && ![@"app" isEqualToString:pathExtension]) {
        image = [imageDictionary objectForKey:pathExtension];
        if (image == nil) {
            image = [[NSWorkspace sharedWorkspace] iconForFileType:pathExtension];
            [image setFlipped:NO];
            if (image == nil)
                image = [NSNull null];
            [imageDictionary setObject:image forKey:pathExtension];
        }
    } else {    
        image = [imageDictionary objectForKey:path];
        if (image == nil) {
            image = [[NSWorkspace sharedWorkspace] iconForFile:path];
            [image setFlipped:NO];
            if (image == nil)
                image = [NSNull null];
            [imageDictionary setObject:image forKey:path];
        }
    }
#else
    // .app is a valid path extension to pass here, but we must not cache the icon based on that extension!
    if(![pathExtension isEqualToString:@""] && ![@"app" isEqualToString:pathExtension]) {
        image = [imageDictionary objectForKey:pathExtension];
        if (image == nil) {
            IconFamily *iconFamily = [[IconFamily alloc] initWithIconOfFile:path];
            image = [iconFamily imageWithAllReps];
            [image setFlipped:NO];
            if (image == nil)
                image = [NSNull null];
            [imageDictionary setObject:image forKey:pathExtension];
            [iconFamily release];
        }
    } else {    
        image = [imageDictionary objectForKey:path];
        if (image == nil) {
            IconFamily *iconFamily = [[IconFamily alloc] initWithIconOfFile:path];
            image = [iconFamily imageWithAllReps];
            [image setFlipped:NO];
            if (image == nil)
                image = [NSNull null];
            [imageDictionary setObject:image forKey:path];
            [iconFamily release];
        }
    }
#endif
    return image != [NSNull null] ? image : nil;
}

static NSImage *createPaperclipImageWithColor(NSColor *color) {
    NSSize size = NSMakeSize(32.0, 32.0);
    NSImage *image = [[NSImage alloc] initWithSize:size];
    [image setBackgroundColor:[NSColor clearColor]];
    
    NSBezierPath *path = [NSBezierPath bezierPath];    
    [image lockFocus];
    
    NSAffineTransform *t = [NSAffineTransform transform];
    [t rotateByDegrees:-45.0];
    [t translateXBy:-4.0 yBy:10.0];
    [t concat];
    
    // start at the outside (right) and work inward
    [path moveToPoint:NSMakePoint(10.0, 18.0)];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(5.0, 4.0) radius:5.0 startAngle:0.0 endAngle:180.0 clockwise:YES];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(3.0, 22.0) radius:3.5 startAngle:180.0 endAngle:0.0 clockwise:YES];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(5.0, 8.0) radius:2.0 startAngle:0.0 endAngle:180.0 clockwise:YES];
    [path lineToPoint:NSMakePoint(3.0, 18.0)];
    
    [color setStroke];
    [path setLineWidth:1.0];
    [path stroke];
    
    [image unlockFocus];
    return image;
}

+ (NSImage *)paperclipImage;
{
    static NSImage *image = nil;
    if(image == nil)
        image = createPaperclipImageWithColor([NSColor blackColor]);
    return image;
}

+ (NSImage *)redPaperclipImage;
{
    static NSImage *image = nil;
    if(image == nil)
        image = createPaperclipImageWithColor([NSColor redColor]);
    return image;
}

+ (NSImage *)arrowImage {
    static NSImage *arrowImage = nil;
    if (arrowImage == nil) {
        if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
            arrowImage = [[NSImage imageNamed:NSImageNameFollowLinkFreestandingTemplate] copy];
            [arrowImage setScalesWhenResized:YES];
            [arrowImage setSize:NSMakeSize(12, 12)];
        } else {
            arrowImage = [[NSImage imageNamed:@"ArrowImage"] retain];
        }
    }
    return arrowImage;
}

- (NSImage *)imageFlippedHorizontally;
{
	NSImage *flippedImage;
	NSAffineTransform *transform = [NSAffineTransform transform];
	NSSize size = [self size];
    NSRect rect = {NSZeroPoint, size};
	NSAffineTransformStruct flip = {-1.0, 0.0, 0.0, 1.0, size.width, 0.0};	
	flippedImage = [[[NSImage alloc] initWithSize:size] autorelease];
	[flippedImage lockFocus];
    [transform setTransformStruct:flip];
	[transform concat];
	[self drawAtPoint:NSZeroPoint fromRect:rect operation:NSCompositeCopy fraction:1.0];
	[flippedImage unlockFocus];
	return flippedImage;
}

- (NSImage *)highlightedImage;
{
    NSSize iconSize = [self size];
    NSRect iconRect = {NSZeroPoint, iconSize};
    NSImage *newImage = [[NSImage alloc] initWithSize:iconSize];
    
    [newImage lockFocus];
    // copy the original image (self)
    [self drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
    
    // blend with black to create a highlighted appearance
    [[[NSColor blackColor] colorWithAlphaComponent:0.3] set];
    NSRectFillUsingOperation(iconRect, NSCompositeSourceAtop);
    [newImage unlockFocus];
    
    return [newImage autorelease];
}

- (NSImage *)dragImageWithCount:(int)count;
{
    return [self dragImageWithCount:count inside:NO isIcon:YES];
}

- (NSImage *)dragImageWithCount:(int)count inside:(BOOL)inside isIcon:(BOOL)isIcon;
{
    NSImage *labeledImage;
    NSRect sourceRect = {NSZeroPoint, [self size]};
    NSSize size = isIcon ? NSMakeSize(32.0, 32.0) : [self size];
    NSRect targetRect = {NSZeroPoint, size};
    
    if (count > 1) {
        
        NSAttributedString *countString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%i", count]
                                            attributeName:NSForegroundColorAttributeName attributeValue:[NSColor whiteColor]] autorelease];
        NSRect countRect = {NSZeroPoint, [countString size]};
        float countOffset;
        
        countOffset = floorf(0.5f * NSHeight(countRect)); // make sure the cap radius is integral
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
        [NSBezierPath fillHorizontalOvalAroundRect:countRect];
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
    unsigned i, iMax = [reps count];
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

- (void)drawFlippedInRect:(NSRect)dstRect fromRect:(NSRect)srcRect operation:(NSCompositingOperation)op fraction:(float)delta {
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform translateXBy:NSMaxX(dstRect) yBy:0.0];
    [transform scaleXBy:-1.0 yBy:1.0];
    [transform translateXBy:-NSMinX(dstRect) yBy:0.0];
    [transform concat];
    [self drawInRect:dstRect fromRect:srcRect operation:op fraction:delta];
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawFlipped:(BOOL)isFlipped inRect:(NSRect)dstRect fromRect:(NSRect)srcRect operation:(NSCompositingOperation)op fraction:(float)delta {
    if (isFlipped) {
        [self drawFlippedInRect:dstRect fromRect:srcRect operation:op fraction:delta];
    } else {
        [self drawInRect:dstRect fromRect:srcRect operation:op fraction:delta];
    }
}

@end

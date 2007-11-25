/*
 This software is Copyright (c) 2007
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

#import <AppKit/AppKit.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include "BDSKSpotlightIconController.h"
#import "BDSKSyntaxHighlighter.h"
#import <QuartzCore/QuartzCore.h>

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    
    // return file icons for tiny sizes; this doesn't seem to be used, though; Finder asks for 108 x 107 icons when I have my desktop icon size set to 48 x 48
    if (maxSize.height > 32) {
        
        if (UTTypeEqual(contentTypeUTI, CFSTR("net.sourceforge.bibdesk.bdskcache"))) {
            NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfURL:(NSURL *)url];

            if (nil == dictionary) {
                // !!! early return
               [pool release];
                return fnfErr;
            }
               
            NSBitmapImageRep *imageRep = [BDSKSpotlightIconController imageRepWithMetadataItem:dictionary];
            if (nil == imageRep) {
                
                // !!! early return
                [pool release];
                return fnfErr;
            }
                       
            NSRect drawFrame = NSZeroRect;
            drawFrame.size = *(NSSize *)&maxSize;
            NSRect srcRect = NSZeroRect;
            srcRect.size = [imageRep size];
            CGFloat ratio = MIN(NSWidth(drawFrame) / srcRect.size.width, NSHeight(drawFrame) / srcRect.size.height);
            drawFrame.size.width = ratio * srcRect.size.width;
            drawFrame.size.height = ratio * srcRect.size.height;
            
            // tried using CoreImage here with a CILanczosScaleTransform filter, but it failed for reasons I never figured out
            // anyway, we need high-quality interpolation, because Finder does a crappy job of scaling in its icon view
            
            CGRect cgrect = *(CGRect *)&drawFrame;
            CGContextRef ctxt = QLThumbnailRequestCreateContext(thumbnail, cgrect.size, TRUE, NULL);
            [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:ctxt flipped:NO]];
            CGContextClearRect(ctxt, cgrect);
            CGContextSetInterpolationQuality(ctxt, kCGInterpolationHigh);
            [imageRep drawInRect:drawFrame];
            QLThumbnailRequestFlushContext(thumbnail, ctxt);
            CGContextRelease(ctxt);

            // !!! early return
            [pool release];
            return noErr;
            
        } else if (UTTypeEqual(contentTypeUTI, CFSTR("net.sourceforge.bibdesk.bib"))) {
            
            NSString *btString = [[NSString alloc] initWithContentsOfURL:(NSURL *)url encoding:NSUTF8StringEncoding error:NULL];
            if (nil == btString)
                btString = [[NSString alloc] initWithContentsOfURL:(NSURL *)url encoding:[NSString defaultCStringEncoding] error:NULL];
            if (nil == btString)
                btString = [[NSString alloc] initWithContentsOfURL:(NSURL *)url encoding:NSISOLatin1StringEncoding error:NULL];
            
            NSMutableAttributedString *attrString = nil;
            if (btString) {
                unsigned maxIndex = MIN(7000, [btString length]);
                attrString = [[BDSKSyntaxHighlighter highlightedStringWithBibTeXString:[btString substringToIndex:maxIndex]] mutableCopy];
                [btString release];
            }
                        
            if (attrString) {
                [attrString addAttribute:NSFontAttributeName value:[NSFont userFixedPitchFontOfSize:20.0f] range:NSMakeRange(0, [attrString length])];
                // same as [[NSPrintInfo sharedPrintInfo] paperSize], but NSPrintInfo must not be used in a non-main thread (and it's hellishly slow in some circumstances), so better to just make an approximate paper size
                NSSize paperSize = NSMakeSize(612, 792);
                
                CGContextRef ctxt = QLThumbnailRequestCreateContext(thumbnail, *(CGSize *)&paperSize, FALSE, NULL);
                NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:ctxt flipped:NO];
                [NSGraphicsContext saveGraphicsState];
                [NSGraphicsContext setCurrentContext:nsContext];
                [[NSColor whiteColor] setFill];
                NSRect pageRect = NSMakeRect(0, 0, paperSize.width, paperSize.height);
                NSRectFillUsingOperation(pageRect, NSCompositeSourceOver);
                
                NSString *iconPath = [BDSKGetQLMainBundle() pathForResource:@"FolderPenIcon" ofType:@"icns"];
                NSImage *appIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];

                NSRect iconRect = NSZeroRect;
                NSSize iconSize = NSMakeSize(paperSize.width * 0.9, paperSize.width * 0.9);
                iconRect.size = iconSize;
                iconRect.origin.x = (paperSize.width - iconSize.width) / 2;
                iconRect.origin.y = (paperSize.height - iconSize.height) / 2;
                [appIcon drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.3];
                [appIcon release];
                
                [attrString drawInRect:NSInsetRect(pageRect, 20.0f, 20.0f)];
                QLThumbnailRequestFlushContext(thumbnail, ctxt);
                CGContextRelease(ctxt);
                [attrString release];
                [NSGraphicsContext restoreGraphicsState];
                
                // !!! early return
                [pool release];
                return noErr;
            }
        }
    }
    /* fallback case: draw the file icon using Icon Services */
    
    FSRef fileRef;
    OSStatus err;
    if (CFURLGetFSRef(url, &fileRef))
        err = noErr;
    else
        err = fnfErr;
    
    IconRef iconRef;
    CGRect rect = CGRectZero;
    CGFloat side = MIN(maxSize.width, maxSize.height);
    rect.size.width = side;
    rect.size.height = side;
    if (noErr == err)
        err = GetIconRefFromFileInfo(&fileRef, 0, NULL, kFSCatInfoNone, NULL, kIconServicesNormalUsageFlag, &iconRef, NULL);
    if (noErr == err) {
        CGContextRef ctxt = QLThumbnailRequestCreateContext(thumbnail, rect.size, TRUE, NULL);
        err = PlotIconRefInContext(ctxt, &rect, kAlignAbsoluteCenter, kTransformNone, NULL, kPlotIconRefNormalFlags, iconRef);
        CGContextRelease(ctxt);
        ReleaseIconRef(iconRef);
    }
    
    [pool release];
    
    return noErr;
}

void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
    // implement only if supported
}

/*
 This software is Copyright (c) 2007-2009
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

// Same size as [[NSPrintInfo sharedPrintInfo] paperSize] on my system
// NSPrintInfo must not be used in a non-main thread (and it's hellishly slow in some circumstances)
static const NSSize _paperSize = (NSSize) { 612, 792 };

// page margins 20 pt on all edges
static const CGFloat _horizontalMargin = 20;
static const CGFloat _verticalMargin = 20;
static const NSSize _containerSize = (NSSize) { 572, 762 };

// readable in Cover Flow view, and distinguishable as text in icon view
static const CGFloat _fontSize = 20;

// returns a string with monospaced font
static NSAttributedString *createAttributedStringWithContentsOfURLByGuessingEncoding(NSURL *url, bool isBibTeX)
{
    NSStringEncoding usedEncoding;
    // this will try NSUTF8StringEncoding if the xattr fails
    NSString *content = [[NSString alloc] initWithContentsOfURL:(NSURL *)url usedEncoding:&usedEncoding error:NULL];
    if (nil == content)
        content = [[NSString alloc] initWithContentsOfURL:(NSURL *)url encoding:[NSString defaultCStringEncoding] error:NULL];
    if (nil == content)
        content = [[NSString alloc] initWithContentsOfURL:(NSURL *)url encoding:NSISOLatin1StringEncoding error:NULL];
    
    NSMutableAttributedString *attrString = nil;
    
    if (content) {
        NSString *shortString = [content substringToIndex:MIN(7000, [content length])];
        if (true == isBibTeX)
            attrString = [[BDSKSyntaxHighlighter highlightedStringWithBibTeXString:shortString] mutableCopy];
        else
            attrString = [[NSMutableAttributedString alloc] initWithString:shortString];
        [content release];
    }
    
    if (attrString) {
        NSFont *fpFont = [NSFont userFixedPitchFontOfSize:_fontSize];
        [attrString addAttribute:NSFontAttributeName value:fpFont range:NSMakeRange(0, [attrString length])];
    }
    
    return attrString;
}

// wash the app icon over a white page background
static void drawBackgroundAndApplicationIconInCurrentContext(QLThumbnailRequestRef thumbnail)
{
    [[NSColor whiteColor] setFill];
    NSRect pageRect = NSMakeRect(0, 0, _paperSize.width, _paperSize.height);
    NSRectFillUsingOperation(pageRect, NSCompositeSourceOver);
    
    NSURL *iconURL = (NSURL *)CFBundleCopyResourceURL(QLThumbnailRequestGetGeneratorBundle(thumbnail), CFSTR("FolderPenIcon"), CFSTR("icns"), NULL);
    NSImage *appIcon = [[NSImage alloc] initWithContentsOfFile:[iconURL path]];
    [iconURL release];
    
    NSRect iconRect = NSZeroRect;
    // draw the icon smaller than the text container
    NSSize iconSize = NSMakeSize(_containerSize.width * 0.9, _containerSize.width * 0.9);
    iconRect.size = iconSize;
    iconRect.origin.x = (_containerSize.width - iconSize.width) / 2;
    iconRect.origin.y = (_containerSize.height - iconSize.height) / 2;
    
    [appIcon drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.3];
    [appIcon release];    
}

// creates a new NSTextStorage/NSLayoutManager/NSTextContainer system suitable for drawing in a thread
static NSTextStorage *createTextStorage()
{
    NSTextStorage *textStorage = [[NSTextStorage alloc] init];
    NSLayoutManager *lm = [[NSLayoutManager alloc] init];
    NSTextContainer *tc = [[NSTextContainer alloc] init];
    [tc setContainerSize:_containerSize];
    [lm addTextContainer:tc];
    // don't let the layout manager use its threaded layout (see header)
    [lm setBackgroundLayoutEnabled:NO];
    [textStorage addLayoutManager:lm];
    // retained by layout manager
    [tc release];
    // retained by text storage
    [lm release];
    // see header; the CircleView example sets it to NO
    [lm setUsesScreenFonts:YES];

    return textStorage;
}

// assumes that the current NSGraphicsContext is the destination
static void drawAttributedStringInCurrentContext(NSAttributedString *attrString)
{
    CGContextRef ctxt = [[NSGraphicsContext currentContext] graphicsPort];
    
    NSTextStorage *textStorage = createTextStorage();
    [textStorage beginEditing];
    [textStorage setAttributedString:attrString];
    
    [textStorage endEditing];
    NSRect stringRect = NSZeroRect;
    stringRect.size = _paperSize;
    
    CGContextSaveGState(ctxt);
    
    CGAffineTransform t1 = CGAffineTransformMakeTranslation(_horizontalMargin, _paperSize.height - _verticalMargin);
    CGAffineTransform t2 = CGAffineTransformMakeScale(1, -1);
    CGAffineTransform pageTransform = CGAffineTransformConcat(t2, t1);
    CGContextConcatCTM(ctxt, pageTransform);
    
    // objectAtIndex:0 is safe, since we added these to the text storage (so there's at least one)
    NSLayoutManager *lm = [[textStorage layoutManagers] objectAtIndex:0];
    NSTextContainer *tc = [[lm textContainers] objectAtIndex:0];
    
    NSRange glyphRange;
    
    // we now have a properly flipped graphics context, so force layout and then draw the text
    glyphRange = [lm glyphRangeForBoundingRect:stringRect inTextContainer:tc];
    NSRect usedRect = [lm usedRectForTextContainer:tc];
    
    // NSRunStorage raises if we try drawing a zero length range (happens if you have an empty text file)
    if (glyphRange.length > 0) {
        [lm drawBackgroundForGlyphRange:glyphRange atPoint:usedRect.origin];
        [lm drawGlyphsForGlyphRange:glyphRange atPoint:usedRect.origin];
    }        
    CGContextRestoreGState(ctxt);
    [textStorage release];    
}

/*
 Primary drawing function, once you've created the attributed string.
 
 1) creates a QL context
 2) draws the background and icon
 3) draws the text content of the string
 4) flushes the context and disposes of it
 
*/
static void drawIconForThumbnailWithAttributedString(QLThumbnailRequestRef thumbnail, NSAttributedString *attrString)
{
    CGContextRef ctxt = QLThumbnailRequestCreateContext(thumbnail, *(CGSize *)&_paperSize, FALSE, NULL);
    NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:ctxt flipped:YES];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsContext];
    
    drawBackgroundAndApplicationIconInCurrentContext(thumbnail);
    drawAttributedStringInCurrentContext(attrString);
    
    QLThumbnailRequestFlushContext(thumbnail, ctxt);
    CGContextRelease(ctxt);
    
    [NSGraphicsContext restoreGraphicsState];    
}

// draws app icon and text for a thumbnail (with syntax highlighting if isBibTeX is true)
static bool generateThumbnailForTextFile(QLThumbnailRequestRef thumbnail, CFURLRef url, bool isBibTeX)
{
    bool didGenerate = false;
    NSAutoreleasePool *pool = [NSAutoreleasePool new];

    NSAttributedString *attrString = createAttributedStringWithContentsOfURLByGuessingEncoding((NSURL *)url, isBibTeX);
    
    if (attrString) {
        drawIconForThumbnailWithAttributedString(thumbnail, attrString);
        [attrString release];
        didGenerate = true;
    }
    [pool release];
    
    return didGenerate;
}

// draws index card thumbnail for a metadata cache file
static bool generateThumbnailForCacheFile(QLThumbnailRequestRef thumbnail, CFURLRef url, CGSize maxSize)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfURL:(NSURL *)url];
    NSBitmapImageRep *imageRep = nil;
    if (nil != dictionary) {
        NSURL *bundleURL = (NSURL *)CFBundleCopyBundleURL(QLThumbnailRequestGetGeneratorBundle(thumbnail));
        NSBundle *bundle = [NSBundle bundleWithPath:[bundleURL path]];
        [bundleURL release];
        imageRep = [BDSKSpotlightIconController imageRepWithMetadataItem:dictionary forBundle:bundle];
    }
    
    if (nil != imageRep) {
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
    }
    
    [pool release];
    return true;
}

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
    bool didGenerate = false;
            
    if (UTTypeEqual(contentTypeUTI, CFSTR("net.sourceforge.bibdesk.bdskcache"))) {
        didGenerate = generateThumbnailForCacheFile(thumbnail, url, maxSize);
    } else if (UTTypeEqual(contentTypeUTI, CFSTR("org.tug.tex.bibtex"))) {
        didGenerate = generateThumbnailForTextFile(thumbnail, url, true);
    } else if (UTTypeConformsTo(contentTypeUTI, kUTTypeText)) {
        // this handles RIS and other plain text types that we support, sans highlighting
        didGenerate = generateThumbnailForTextFile(thumbnail, url, false);
    }
    
    /* fallback case: draw the file icon using Icon Services */
    if (false == didGenerate) {
    
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
    }
        
    return noErr;
}

void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
    // implement only if supported
}

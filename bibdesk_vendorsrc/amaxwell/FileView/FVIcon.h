//
//  FVIcon.h
//  FileViewTest
//
//  Created by Adam Maxwell on 08/31/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FVIcon : NSObject

/*
 Note: the +iconWith... class methods are designed to be cheap, in that they do no rendering, and will require very little memory or disk access just for initialization.  Only after calling -renderOffscreen will memory usage increase substantially, as data is cached and bitmaps created.  Icons that won't be displayed for some time (scrolled out of sight) should be sent a -releaseResources message by the view in order to free up (some) of the cached data.
 
 This class is thread safe, at least within reason.
 */

// Will determine the file type based on the absolute path and returns an instance of a concrete subclass, using the iconSize parameter as a size hint.
+ (id)iconWithPath:(NSString *)absolutePath size:(NSSize)iconSize;

// Will accept any URL type and return a file thumbnail, file icon, or appropriate icon for the given URL scheme.
+ (id)iconWithURL:(NSURL *)representedURL size:(NSSize)iconSize;

// Convenience for creating an NSImage at arbitrary size; not necessarily efficient
+ (NSImage *)imageWithURL:(NSURL *)representedURL size:(NSSize)iconSize;

// Possibly releases cached resources for icons that won't be displayed.  The only way to guarantee a decrease in memory usage is to release all references to the object, though, as this call may be a noop for some subclasses.
- (void)releaseResources;

// Returns NO if the icon already has a cached version for this size; if it returns YES, this method sets the desired size in the case of Finder icons, and the caller should then send -renderOffscreen from the render thread.
- (BOOL)needsRenderForSize:(NSSize)size;

// Renders the icon into an offscreen bitmap context; should be called from a dedicated rendering thread after needsRenderForSize: has been called.  This call may be expensive, but it's required for correct drawing.
- (void)renderOffscreen;

/*
 - the image will be scaled proportionally and centered in the destination rect
 - the view is responsible for using -centerScanRect: as appropriate, but images may not end up on pixel boundaries
 - any changes to the CGContextRef are wrapped by CGContextSaveGState/CGContextRestoreGState
 - specific compositing operations should be set in the context before calling this method
 - shadow will be respected (the clip path is only changed when rendering text)
 - a placeholder icon may be drawn if -renderOffscreen has not been called or finished working
 */
- (void)drawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context;

// fastDrawInRect: draws a lower quality version if available, using the same semantics as drawInRect:inCGContext:
- (void)fastDrawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context;

// The -currentPageIndex return value is 1-based, as in CGPDFDocumentGetPageCount; only useful for multi-page formats such as PDF and PS.  Multi-page TIFFs and text documents are not supported, and calling the showNextPage/showPreviousPage methods will have no effect.
- (NSUInteger)pageCount;
- (NSUInteger)currentPageIndex;
- (void)showNextPage;
- (void)showPreviousPage;

@end

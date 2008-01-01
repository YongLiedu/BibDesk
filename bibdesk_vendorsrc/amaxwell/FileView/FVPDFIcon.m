//
//  FVPDFIcon.m
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
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

#import "FVPDFIcon.h"

// cache these so we avoid hitting NSPrintInfo; we only care to have something that approximates a page size, anyway
static NSSize __paperSize;

@implementation FVPDFIcon

+ (void)initialize
{
    static BOOL didInit = NO;
    if (NO == didInit) {
        __paperSize = [[NSPrintInfo sharedPrintInfo] paperSize];
        didInit = YES;
    }
}

static CGPDFDocumentRef createCGPDFDocumentWithPostScriptURL(NSURL *fileURL)
{
    CGPDFDocumentRef pdfDoc = NULL;
    
    NSData *psData = [[NSData alloc] initWithContentsOfURL:fileURL options:NSMappedRead error:NULL];
    if (psData) {
        CGPSConverterCallbacks converterCallbacks = { 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL };
        CGPSConverterRef converter = CGPSConverterCreate(NULL, &converterCallbacks, NULL);    
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)psData);
        
        CFMutableDataRef pdfData = CFDataCreateMutable(CFGetAllocator((CFDataRef)psData), 0);
        [psData release];
        
        CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData(pdfData);
        Boolean success = CGPSConverterConvert(converter, provider, consumer, NULL);
        
        CGDataProviderRelease(provider);
        CGDataConsumerRelease(consumer);
        CFRelease(converter);
        
        if (success) {
            provider = CGDataProviderCreateWithCFData(pdfData);
            pdfDoc = CGPDFDocumentCreateWithProvider(provider);
            CGDataProviderRelease(provider);
        }
        CFRelease(pdfData);
    }
    return pdfDoc;
}

// return the same thing as PDF; just a container for the URL, until actually asked to render the PS file
- (id)initWithPostscriptAtURL:(NSURL *)aURL;
{
    self = [self initWithPDFAtURL:aURL];
    _iconType = FVPostscriptType;
    return self;
}

- (id)initWithPDFAtURL:(NSURL *)aURL;
{
    self = [super init];
    if (self) {
        
        _drawsLinkBadge = [[self class] _shouldDrawBadgeForURL:aURL];
        if (_drawsLinkBadge)
            aURL = [[self class] _resolvedURLWithURL:aURL];

        // PDF sucks because we have to read the file and parse it to find out the page size, even if we're not going to draw it.  Since that's not very efficient, don't even open the file until we have to draw it.
        
        // Set default sizes so we can draw a blank page on the first pass; this will use a common aspect ratio.
        _fullSize = __paperSize;
        _thumbnailSize = _fullSize;
        _fileURL = [aURL copy];        
        _diskCacheName = FVCreateDiskCacheNameWithURL(aURL);
        _iconType = FVPDFType;
        _pdfDoc = NULL;
        _pdfPage = NULL;
        _thumbnailRef = NULL;
        _desiredSize = NSZeroSize;
        _inDiskCache = NO;
        
        // must be > 1 to be valid
        _currentPage = 1;
        
        // initialize to zero so we know whether to load the PDF document
        _pageCount = 0;
        
        NSInteger rc = pthread_mutex_init(&_mutex, NULL);
        if (rc)
            perror("pthread_mutex_init");
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
    [_fileURL release];
    CGImageRelease(_thumbnailRef);
    CGPDFDocumentRelease(_pdfDoc);
    free(_diskCacheName);
    [super dealloc];
}

- (NSSize)size { return _fullSize; }

- (void)releaseResources 
{
    if (pthread_mutex_trylock(&_mutex) == 0) {
        // Too expensive to create from PostScript on the fly, and PS is not that common; however, a CGPDFDocument data provider is the same size as the file on disk, so we want to get rid of them unless we're drawing full resolution.
        if (FVPostscriptType != _iconType) {
            CGPDFDocumentRelease(_pdfDoc);
            _pdfDoc = NULL;
            _pdfPage = NULL;
        }
        
        // seems OK to keep thumbnails around, now that they're 8 bit grayscale, but reset if the page has changed
        //if (_currentPage != 0) {
            //_pdfPage = NULL;
            CGImageRelease(_thumbnailRef);
            _thumbnailRef = NULL;
        //}
        pthread_mutex_unlock(&_mutex);
    }
}

+ (CGContextRef)getPDFBitmapContextForCurrentThread
{
    NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    NSString *key = @"FVPDFBitmapContext";
    CGContextRef ctxt = (CGContextRef)[threadDictionary objectForKey:key];
    return ctxt;
}

+ (void)setPDFBitmapContextForCurrentThread:(CGContextRef)ctxt
{
    NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    NSString *key = @"FVPDFBitmapContext";
    CGContextRef oldContext = (CGContextRef)[threadDictionary objectForKey:key];
    if (oldContext) {
        [threadDictionary removeObjectForKey:key];
        FVIconBitmapContextDispose(oldContext);
    }
    [threadDictionary setObject:(id)ctxt forKey:key];
}

static inline BOOL isContextLargeEnough(CGContextRef ctxt, NSSize requiredSize)
{
    return (CGBitmapContextGetWidth(ctxt) >= requiredSize.width && CGBitmapContextGetHeight(ctxt) >= requiredSize.height);
}

/*
 unused because scaling and cropping are screwy
 
 CGContextRef ctxt = [FVPDFIcon getPDFBitmapContextForCurrentThread];
 if (NULL == ctxt || isContextLargeEnough(ctxt, _thumbnailSize) == NO) {
 ctxt = FVIconBitmapContextCreateWithSize(_thumbnailSize.width, _thumbnailSize.height);
 // this will dispose of the previous context (if any)
 [FVPDFIcon setPDFBitmapContextForCurrentThread:ctxt];
 }
 */

- (NSUInteger)pageCount { return _pageCount; }

- (NSUInteger)currentPageIndex { return _currentPage; }

- (void)showNextPage;
{
    pthread_mutex_lock(&_mutex);
    _currentPage = MIN(_currentPage + 1, _pageCount);
    _pdfPage = NULL;
    CGImageRelease(_thumbnailRef);
    _thumbnailRef = NULL;
    pthread_mutex_unlock(&_mutex);
}

- (void)showPreviousPage;
{
    pthread_mutex_lock(&_mutex);
    _currentPage = _currentPage > 1 ? _currentPage - 1 : 1;
    _pdfPage = NULL;
    CGImageRelease(_thumbnailRef);
    _thumbnailRef = NULL;
    pthread_mutex_unlock(&_mutex);
}

- (void)renderOffscreen
{  
    // hold the lock while initializing these variables, so we don't waste time trying to render again, since we may be returning YES from needsRender
    pthread_mutex_lock(&_mutex);
    
    // only the first page is cached to disk; ignore this branch if we should be drawing a later page or if the size has changed
    if (NULL == _thumbnailRef && 1 == _currentPage) {
        
        _thumbnailRef = [FVIconCache newImageNamed:_diskCacheName];
        BOOL exitEarly = NO;
        
        
        // This is an optimization to avoid loading the PDF document unless absolutely necessary.  If the icon was cached by a different FVPDFIcon instance, _pageCount won't be correct and we have to continue on and load the PDF document.  In that case, our sizes will be overwritten, but the thumbnail won't be recreated.  If we need to render something that's larger than the thumbnail by 20%, we have to continue on and make sure the PDF doc is loaded as well.
        
        if (NULL != _thumbnailRef) {
            _thumbnailSize.width = CGImageGetWidth(_thumbnailRef);
            _thumbnailSize.height = CGImageGetHeight(_thumbnailRef);
            exitEarly = _thumbnailSize.height <= _desiredSize.height * 1.2 && _pageCount > 0;
        }
                
        // !!! early return
        if (exitEarly) {
            pthread_mutex_unlock(&_mutex);    
            return;
        }
    }    
    
    if (NULL == _pdfPage) {
        
        if (NULL == _pdfDoc) {
            if (FVPDFType == _iconType)
                _pdfDoc = CGPDFDocumentCreateWithURL((CFURLRef)_fileURL);
            else
                _pdfDoc = createCGPDFDocumentWithPostScriptURL(_fileURL);
            
            _pageCount = CGPDFDocumentGetNumberOfPages(_pdfDoc);
        }
        
        // 1-based indexing
        _pdfPage = _pageCount ? CGPDFDocumentGetPage(_pdfDoc, _currentPage) : NULL;
        CGRect pageRect = CGPDFPageGetBoxRect(_pdfPage, kCGPDFCropBox);
        
        // these may have been bogus before
        int rotation = CGPDFPageGetRotationAngle(_pdfPage);
        if (0 == rotation || 180 == rotation)
            _fullSize = ((NSRect *)&pageRect)->size;
        else
            _fullSize = NSMakeSize(pageRect.size.height, pageRect.size.width);
        _thumbnailSize.width = _fullSize.width / 2;
        _thumbnailSize.height = _fullSize.height / 2;
    }
                
    // Bitmap contexts for PDF files tend to be in the 2-5 MB range, and even a one point size difference in height or width (typical, even for the same page size) results in us creating a new context for each one if we use the context cache.  That sucks, so we'll just create and destroy them as needed, since drawing into a large cached context and then cropping doesn't work.
    
    // don't bother redrawing this if it already exists, since that's a big waste of time, and our thumbnail size is a fixed percentage of the document size so there's never a need to re-render it

    if (NULL == _thumbnailRef) {
        
        pthread_mutex_unlock(&_mutex);
        CGContextRef ctxt = FVIconBitmapContextCreateWithSize(_thumbnailSize.width, _thumbnailSize.height);
        
        // set a white page background
        CGContextSetRGBFillColor(ctxt, 1.0, 1.0, 1.0, 1.0);
        CGRect pageRect = CGRectMake(0, 0, _thumbnailSize.width, _thumbnailSize.height);
        CGContextClipToRect(ctxt, pageRect);
        CGContextFillRect(ctxt, pageRect);
        
        // now hold the lock until we finish
        pthread_mutex_lock(&_mutex);
        if (_pdfPage) {
            // always downscaling, so CGPDFPageGetDrawingTransform is okay to use here
            CGAffineTransform t = CGPDFPageGetDrawingTransform(_pdfPage, kCGPDFCropBox, pageRect, 0, true);
            CGContextConcatCTM(ctxt, t);
            CGContextClipToRect(ctxt, CGPDFPageGetBoxRect(_pdfPage, kCGPDFCropBox));
            CGContextDrawPDFPage(ctxt, _pdfPage);
        }
        
        CGImageRelease(_thumbnailRef);
        _thumbnailRef = CGBitmapContextCreateImage(ctxt);
        if (1 == _currentPage && NO == _inDiskCache && NULL != _thumbnailRef) {
            [FVIconCache cacheCGImage:_thumbnailRef withName:_diskCacheName];
            _inDiskCache = YES;
        }
        
        FVIconBitmapContextDispose(ctxt);
    }
    pthread_mutex_unlock(&_mutex);
}

- (BOOL)needsRenderForSize:(NSSize)size 
{
    BOOL needsRender = NO;
    if (pthread_mutex_trylock(&_mutex) == 0) {
        // tells the render method if work is needed
        _desiredSize = size;
        if (size.height <= _thumbnailSize.height * 1.2)
            needsRender = (NULL == _thumbnailRef);
        else 
            needsRender = (NULL == _pdfPage);
        pthread_mutex_unlock(&_mutex);
    }
    return needsRender;
}

/*
 For PDF/PS icons, we always use trylock and draw a blank page if that fails.  Otherwise the drawing thread will wait for rendering to relinquish the lock (which can be really slow for PDF).  This is a major problem when scrolling.
 */

- (void)fastDrawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context
{    
    // draw thumbnail if present, regardless of the size requested
    if (pthread_mutex_trylock(&_mutex) != 0) {
        // no lock, so just draw the blank page and bail out
        [self _drawPlaceholderInRect:dstRect inCGContext:context];
    }
    else if (NULL == _thumbnailRef) {
        pthread_mutex_unlock(&_mutex);
        [self _drawPlaceholderInRect:dstRect inCGContext:context];
    }
    else if (_thumbnailRef) {
        CGContextDrawImage(context, [self _drawingRectWithRect:dstRect], _thumbnailRef);
        pthread_mutex_unlock(&_mutex);
        if (_drawsLinkBadge)
            [self _drawBadgeInContext:context forIconInRect:dstRect withDrawingRect:[self _drawingRectWithRect:dstRect]];
    }
    else {
        pthread_mutex_unlock(&_mutex);
        // let drawInRect: handle the rect conversion
        [self drawInRect:dstRect inCGContext:context];
    }
}

- (void)drawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context;
{    
    if (pthread_mutex_trylock(&_mutex) != 0) {
        [self _drawPlaceholderInRect:dstRect inCGContext:context];
    }
    else {
        
        CGRect drawRect = [self _drawingRectWithRect:dstRect];
        
        // draw the thumbnail if the rect is small or we have no PDF document (yet)...if we have neither, draw a blank page
        if (CGRectGetHeight(drawRect) <= _thumbnailSize.height * 1.2 || NULL == _pdfDoc) {
            
            if (NULL != _thumbnailRef) {
                CGContextDrawImage(context, drawRect, _thumbnailRef);
                if (_drawsLinkBadge)
                    [self _drawBadgeInContext:context forIconInRect:dstRect withDrawingRect:drawRect];
            }
            else {
                // draw a blank page as a placeholder, and the real icon will get picked up next time around
                // this path is hit fairly often, but is seldom actually drawn because of the callback rate
                [self _drawPlaceholderInRect:dstRect inCGContext:context];
            }
            
        }
        else {
            CGContextSaveGState(context);
            CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
            // don't clip, because the caller has a shadow set
            CGContextFillRect(context, drawRect);
            // get rid of any shadow, or we may draw a text shadow if the page is transparent
            CGContextSetShadowWithColor(context, CGSizeZero, 0, NULL);
            if (_pdfDoc) {
                // CGPDFPageGetDrawingTransform only downscales PDF, so we have to set up the CTM manually
                // http://lists.apple.com/archives/Quartz-dev/2005/Mar/msg00118.html
                CGRect cropBox = CGPDFPageGetBoxRect(_pdfPage, kCGPDFCropBox);
                CGContextTranslateCTM(context, drawRect.origin.x, drawRect.origin.y);
                int rotation = CGPDFPageGetRotationAngle(_pdfPage);
                // only tested 0 and 90 degree rotation
                switch (rotation) {
                    case 0:
                        CGContextScaleCTM(context, drawRect.size.width / cropBox.size.width, drawRect.size.height / cropBox.size.height);
                        CGContextTranslateCTM(context, -CGRectGetMinX(cropBox), -CGRectGetMinY(cropBox));
                        break;
                    case 90:
                        CGContextScaleCTM(context, drawRect.size.width / cropBox.size.height, drawRect.size.height / cropBox.size.width);
                        CGContextRotateCTM(context, -M_PI / 2);
                        CGContextTranslateCTM(context, -CGRectGetMaxX(cropBox), -CGRectGetMinY(cropBox));
                        break;
                    case 180:
                        CGContextScaleCTM(context, drawRect.size.width / cropBox.size.width, drawRect.size.height / cropBox.size.height);
                        CGContextRotateCTM(context, M_PI);
                        CGContextTranslateCTM(context, -CGRectGetMaxX(cropBox), -CGRectGetMaxY(cropBox));
                        break;
                    case 270:
                        CGContextScaleCTM(context, drawRect.size.width / cropBox.size.height, drawRect.size.height / cropBox.size.width);
                        CGContextRotateCTM(context, M_PI / 2);
                        CGContextTranslateCTM(context, -CGRectGetMinX(cropBox), -CGRectGetMaxY(cropBox));
                        break;
                }
                CGContextClipToRect(context, cropBox);
                CGContextDrawPDFPage(context, _pdfPage);
            }
            CGContextRestoreGState(context);
            
            if (_drawsLinkBadge)
                [self _drawBadgeInContext:context forIconInRect:dstRect withDrawingRect:drawRect];

        }
        pthread_mutex_unlock(&_mutex);
    }
}

@end

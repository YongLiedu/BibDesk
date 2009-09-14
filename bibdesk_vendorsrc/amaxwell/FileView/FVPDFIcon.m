//
//  FVPDFIcon.m
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
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

#import "FVPDFIcon.h"

// cache these so we avoid hitting NSPrintInfo; we only care to have something that approximates a page size, anyway
static NSSize _paperSize;

@implementation FVPDFIcon

+ (void)initialize
{
    FVINITIALIZE(FVPDFIcon);
    _paperSize = [[NSPrintInfo sharedPrintInfo] paperSize];
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

static NSURL *createPDFURLForPDFBundleURL(NSURL *aURL)
{
    NSString *filePath = [aURL path];
    NSArray *files = [[NSFileManager defaultManager] subpathsAtPath:filePath];
    NSString *fileName = [[[filePath lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];
    NSString *pdfFile = nil;
    
    if ([files containsObject:fileName]) {
        pdfFile = fileName;
    } else {
        NSUInteger idx = [[files valueForKeyPath:@"pathExtension.lowercaseString"] indexOfObject:@"pdf"];
        if (idx != NSNotFound)
            pdfFile = [files objectAtIndex:idx];
    }
    if (pdfFile)
        pdfFile = [filePath stringByAppendingPathComponent:pdfFile];
    return pdfFile ? [[NSURL alloc] initFileURLWithPath:pdfFile] : nil;
}

// return the same thing as PDF; just a container for the URL, until actually asked to render the PS file
- (id)initWithPostscriptAtURL:(NSURL *)aURL;
{
    NSParameterAssert([aURL isFileURL]);
    self = [self initWithPDFAtURL:aURL];
    if (self) {
        _isPostscript = YES;
    }
    return self;
}

// return the same thing as PDF; just a container for the URL, until actually asked to render the PDF file
- (id)initWithPDFDAtURL:(NSURL *)aURL;
{
    NSParameterAssert([aURL isFileURL]);
    self = [self initWithPDFAtURL:aURL];
    if (self) {
        NSURL *fileURL = createPDFURLForPDFBundleURL(_fileURL);
        if (fileURL) {
            [_fileURL release];
            _fileURL = fileURL;
        } else {
            [self release];
            self = nil;
        }
    }
    return self;
}

- (id)initWithPDFAtURL:(NSURL *)aURL;
{
    NSParameterAssert([aURL isFileURL]);
    self = [super init];
    if (self) {
        
        _drawsLinkBadge = [[self class] _shouldDrawBadgeForURL:aURL copyTargetURL:&_fileURL];        

        // PDF sucks because we have to read the file and parse it to find out the page size, even if we're not going to draw it.  Since that's not very efficient, don't even open the file until we have to draw it.
        
        // Set default sizes so we can draw a blank page on the first pass; this will use a common aspect ratio.
        _fullSize = _paperSize;
        _thumbnailSize = _fullSize;
        _diskCacheName = [FVIconCache createDiskCacheNameWithURL:aURL];
        _isPostscript = NO;
        _pdfDoc = NULL;
        _pdfPage = NULL;
        _thumbnail = NULL;
        _desiredSize = NSZeroSize;
        _inDiskCache = NO;
        
        // must be > 1 to be valid
        _currentPage = 1;
        
        // initialize to zero so we know whether to load the PDF document
        _pageCount = 0;
        
        if (pthread_mutex_init(&_mutex, NULL))
            perror("pthread_mutex_init");
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
    [_fileURL release];
    CGImageRelease(_thumbnail);
    CGPDFDocumentRelease(_pdfDoc);
    free(_diskCacheName);
    [super dealloc];
}

- (BOOL)tryLock { return pthread_mutex_trylock(&_mutex) == 0; }
- (void)lock { pthread_mutex_lock(&_mutex); }
- (void)unlock { pthread_mutex_unlock(&_mutex); }

- (NSSize)size { return _fullSize; }

- (BOOL)canReleaseResources;
{
    return _isPostscript ? (NULL != _thumbnail) : (NULL != _pdfDoc || NULL != _thumbnail);
}

- (void)releaseResources 
{
    if ([self tryLock]) {
        // Too expensive to create from PostScript on the fly, and PS is not that common; however, a CGPDFDocument data provider is the same size as the file on disk, so we want to get rid of them unless we're drawing full resolution.
        if (_isPostscript != NO) {
            CGPDFDocumentRelease(_pdfDoc);
            _pdfDoc = NULL;
            _pdfPage = NULL;
        }
        CGImageRelease(_thumbnail);
        _thumbnail = NULL;
        [self unlock];
    }
}

- (NSUInteger)pageCount { return _pageCount; }

- (NSUInteger)currentPageIndex { return _currentPage; }

- (void)showNextPage;
{
    [self lock];
    _currentPage = MIN(_currentPage + 1, _pageCount);
    _pdfPage = NULL;
    CGImageRelease(_thumbnail);
    _thumbnail = NULL;
    [self unlock];
}

- (void)showPreviousPage;
{
    [self lock];
    _currentPage = _currentPage > 1 ? _currentPage - 1 : 1;
    _pdfPage = NULL;
    CGImageRelease(_thumbnail);
    _thumbnail = NULL;
    [self unlock];
}

- (void)renderOffscreen
{  
    // hold the lock while initializing these variables, so we don't waste time trying to render again, since we may be returning YES from needsRender
    [self lock];
    
    if ([NSThread instancesRespondToSelector:@selector(setName:)] && pthread_main_np() == 0)
        [[NSThread currentThread] setName:[_fileURL path]];
    
    // only the first page is cached to disk; ignore this branch if we should be drawing a later page or if the size has changed
    
    // handle the case where multiple render tasks were pushed into the queue before renderOffscreen was called
    if ((NULL != _thumbnail || NULL != _pdfDoc) && 1 == _currentPage) {
        
        BOOL exitEarly;
        // if _thumbnail is non-NULL, we're guaranteed that _thumbnailSize has been initialized correctly
        
        if (FVShouldDrawFullImageWithThumbnailSize(_desiredSize, _thumbnailSize))
            exitEarly = (NULL != _pdfDoc && NULL != _pdfPage);
        else
            exitEarly = (NULL != _thumbnail);

        if (exitEarly) {
            [self unlock];
            return;
        }
    }
    
    if (NULL == _thumbnail && 1 == _currentPage) {
        
        _thumbnail = [FVIconCache newImageNamed:_diskCacheName];
        BOOL exitEarly = NO;
        
        // This is an optimization to avoid loading the PDF document unless absolutely necessary.  If the icon was cached by a different FVPDFIcon instance, _pageCount won't be correct and we have to continue on and load the PDF document.  In that case, our sizes will be overwritten, but the thumbnail won't be recreated.  If we need to render something that's larger than the thumbnail by 20%, we have to continue on and make sure the PDF doc is loaded as well.
        
        if (NULL != _thumbnail) {
            _thumbnailSize = FVCGImageSize(_thumbnail);
            exitEarly = NO == FVShouldDrawFullImageWithThumbnailSize(_desiredSize, _thumbnailSize) && _pageCount > 0;
        }
                
        // !!! early return
        if (exitEarly) {
            [self unlock];    
            return;
        }
    }    
    
    if (NULL == _pdfPage) {
        
        if (NULL == _pdfDoc) {
            _pdfDoc = _isPostscript ? createCGPDFDocumentWithPostScriptURL(_fileURL) : CGPDFDocumentCreateWithURL((CFURLRef)_fileURL);
            
            _pageCount = CGPDFDocumentGetNumberOfPages(_pdfDoc);
        }
        
        // The file had to exist when the icon was created, but loading the document can fail if the underlying file was moved out from under us afterwards (e.g. by BibDesk's autofile).  NB: CGPDFDocument uses 1-based indexing.
        if (_pdfDoc)
            _pdfPage = _pageCount ? CGPDFDocumentGetPage(_pdfDoc, _currentPage) : NULL;
        
        if (_pdfPage) {
            CGRect pageRect = CGPDFPageGetBoxRect(_pdfPage, kCGPDFCropBox);
            
            // these may have been bogus before
            int rotation = CGPDFPageGetRotationAngle(_pdfPage);
            if (0 == rotation || 180 == rotation)
                _fullSize = ((NSRect *)&pageRect)->size;
            else
                _fullSize = NSMakeSize(pageRect.size.height, pageRect.size.width);
            
            // scale appropriately; small PDF images, for instance, don't need scaling
            _thumbnailSize = _fullSize;   
        
            // really huge PDFs (e.g. maps) will create really huge bitmaps and run us out of memory
            FVIconLimitThumbnailSize(&_thumbnailSize);
        }
    }
                
    // Bitmap contexts for PDF files tend to be in the 2-5 MB range, and even a one point size difference in height or width (typical, even for the same page size) results in us creating a new context for each one if we use the context cache.  That sucks, so we'll just create and destroy them as needed, since drawing into a large cached context and then cropping doesn't work.
    
    // don't bother redrawing this if it already exists, since that's a big waste of time, and our thumbnail size is a fixed percentage of the document size so there's never a need to re-render it

    if (NULL == _thumbnail) {
        
        CGContextRef ctxt = FVIconBitmapContextCreateWithSize(_thumbnailSize.width, _thumbnailSize.height);
        
        // set a white page background
        CGContextSetRGBFillColor(ctxt, 1.0, 1.0, 1.0, 1.0);
        CGRect pageRect = CGRectMake(0, 0, _thumbnailSize.width, _thumbnailSize.height);
        CGContextClipToRect(ctxt, pageRect);
        CGContextFillRect(ctxt, pageRect);
        
        if (_pdfPage) {
            // always downscaling, so CGPDFPageGetDrawingTransform is okay to use here
            CGAffineTransform t = CGPDFPageGetDrawingTransform(_pdfPage, kCGPDFCropBox, pageRect, 0, true);
            CGContextConcatCTM(ctxt, t);
            CGContextClipToRect(ctxt, CGPDFPageGetBoxRect(_pdfPage, kCGPDFCropBox));
            CGContextDrawPDFPage(ctxt, _pdfPage);
        }
        
        CGImageRelease(_thumbnail);
        _thumbnail = CGBitmapContextCreateImage(ctxt);
        if (1 == _currentPage && NO == _inDiskCache && NULL != _thumbnail) {
            [FVIconCache cacheImage:_thumbnail withName:_diskCacheName];
            _inDiskCache = YES;
        }
        
        FVIconBitmapContextDispose(ctxt);
    }
    [self unlock];
}

- (BOOL)needsRenderForSize:(NSSize)size 
{
    BOOL needsRender = NO;
    if ([self tryLock]) {
        // tells the render method if work is needed
        _desiredSize = size;
        if (FVShouldDrawFullImageWithThumbnailSize(size, _thumbnailSize))
            needsRender = (NULL == _pdfPage);
        else
            needsRender = (NULL == _thumbnail);
        [self unlock];
    }
    return needsRender;
}

/*
 For PDF/PS icons, we always use trylock and draw a blank page if that fails.  Otherwise the drawing thread will wait for rendering to relinquish the lock (which can be really slow for PDF).  This is a major problem when scrolling.
 */

- (void)fastDrawInRect:(NSRect)dstRect ofContext:(CGContextRef)context
{    
    // draw thumbnail if present, regardless of the size requested
    if (NO == [self tryLock]) {
        // no lock, so just draw the blank page and bail out
        [self _drawPlaceholderInRect:dstRect ofContext:context];
    }
    else if (NULL == _thumbnail) {
        [self unlock];
        [self _drawPlaceholderInRect:dstRect ofContext:context];
    }
    else if (_thumbnail) {
        CGContextDrawImage(context, [self _drawingRectWithRect:dstRect], _thumbnail);
        [self unlock];
        if (_drawsLinkBadge)
            [self _badgeIconInRect:dstRect ofContext:context];
    }
    else {
        [self unlock];
        // let drawInRect: handle the rect conversion
        [self drawInRect:dstRect ofContext:context];
    }
}

- (void)drawInRect:(NSRect)dstRect ofContext:(CGContextRef)context;
{    
    if (NO == [self tryLock]) {
        [self _drawPlaceholderInRect:dstRect ofContext:context];
    }
    else {
        
        CGRect drawRect = [self _drawingRectWithRect:dstRect];
        
        // draw the thumbnail if the rect is small or we have no PDF document (yet)...if we have neither, draw a blank page
        if (false == FVShouldDrawFullImageWithThumbnailSize(dstRect.size, _thumbnailSize) || NULL == _pdfDoc) {
            
            if (NULL != _thumbnail) {
                CGContextDrawImage(context, drawRect, _thumbnail);
                if (_drawsLinkBadge)
                    [self _badgeIconInRect:dstRect ofContext:context];
            }
            else {
                // draw a blank page as a placeholder, and the real icon will get picked up next time around
                // this path is hit fairly often, but is seldom actually drawn because of the callback rate
                [self _drawPlaceholderInRect:dstRect ofContext:context];
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
                [self _badgeIconInRect:dstRect ofContext:context];

        }
        [self unlock];
    }
}

@end

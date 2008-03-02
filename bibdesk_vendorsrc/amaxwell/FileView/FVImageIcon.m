//
//  FVImageIcon.m
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
/*
 This software is Copyright (c) 2007-2008
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

#import "FVImageIcon.h"
#import <QTKit/QTKit.h>

@implementation FVImageIcon

static CFDictionaryRef __imsrcOptions = NULL;

// thumbnail size
static const NSUInteger THUMBNAIL_THRESHOLD = 128;

// dimension at which we use FVIconCache
static const NSUInteger FVICONCACHE_THRESHOLD = 1024;

// max dimension for _fullImageRef
static const NSUInteger MAX_PIXEL_DIMENSION = 512; /* maximum height or width allowed */

+ (void)initialize
{
    if (NULL == __imsrcOptions) {
        CFMutableDictionaryRef dict = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(dict, kCGImageSourceCreateThumbnailFromImageAlways, kCFBooleanTrue);
        CFDictionarySetValue(dict, kCGImageSourceThumbnailMaxPixelSize, (void *)[NSNumber numberWithUnsignedInt:THUMBNAIL_THRESHOLD]);
        CFDictionarySetValue(dict, kCGImageSourceCreateThumbnailWithTransform, kCFBooleanTrue);
        CFDictionarySetValue(dict, kCGImageSourceShouldAllowFloat, kCFBooleanTrue);
        __imsrcOptions = CFDictionaryCreateCopy(NULL, dict);
        CFRelease(dict);
    }
}

- (id)_initWithURL:(NSURL *)aURL
{
    self = [super init];
    if (self) {
        
        _drawsLinkBadge = [[self class] _shouldDrawBadgeForURL:&aURL];
        
        _fileURL = [aURL copy];
        _fullImageRef = NULL;
        _thumbnailRef = NULL;
        _diskCacheName = [FVIconCache createDiskCacheNameWithURL:_fileURL];
        _thumbnailSize = NSZeroSize;
        _inDiskCache = NO;
        
        if (pthread_mutex_init(&_mutex, NULL) != 0)
            perror("pthread_mutex_init");             
    }
    return self;
}

- (id)initWithQTMovieAtURL:(NSURL *)aURL;
{
    self = [self _initWithURL:aURL];
    _iconType = FVQTMovieType;
    return self;
}

- (id)initWithImageAtURL:(NSURL *)aURL;
{
    self = [self _initWithURL:aURL];
    _iconType = FVImageFileType;
    return self;
}

- (void)releaseResources
{
    pthread_mutex_lock(&_mutex);
    // ??? memory usage
    // leave the thumbnail, since only the full image is cached (and 128 x 128 images are negligible)
    CGImageRelease(_fullImageRef);
    _fullImageRef = NULL;
    pthread_mutex_unlock(&_mutex);
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
    [_fileURL release];
    CGImageRelease(_thumbnailRef);
    CGImageRelease(_fullImageRef);
    free(_diskCacheName);
    [super dealloc];
}

// only guaranteed to have _thumbnailSize; returning NSZeroSize causes _drawingRectWithRect: to return garbage
- (NSSize)size { return NSEqualSizes(_thumbnailSize, NSZeroSize) ? (NSSize) { 128, 128 } : _thumbnailSize; }

static inline BOOL shouldDrawFullImageWithSize(NSSize desiredSize, NSSize thumbnailSize)
{
    return (desiredSize.height > 1.2 * thumbnailSize.height || desiredSize.width > 1.2 * thumbnailSize.width);
}

- (BOOL)needsRenderForSize:(NSSize)size
{
    // faster without trylock... why?
    // trylock needed for scrolling, though
    BOOL needsRender = NO;
    if (pthread_mutex_trylock(&_mutex) == 0) {
        if (shouldDrawFullImageWithSize(size, _thumbnailSize))
            needsRender = (NULL == _fullImageRef);
        else
            needsRender = (NULL == _thumbnailRef);
        _desiredSize = size;
        pthread_mutex_unlock(&_mutex);
    }
    return needsRender;
}

// Huge images are slow to draw, so resample them first
static CGImageRef createResampledImage(CGImageRef bigImage)
{
    size_t width = CGImageGetWidth(bigImage);
    size_t height = CGImageGetHeight(bigImage);

    if (MIN(width, height) < MAX_PIXEL_DIMENSION)
        return CGImageRetain(bigImage);
        
    // scale by 10% until one side is < 1000 pixels
    while (MIN(width, height) > MAX_PIXEL_DIMENSION) {
        width *= 0.9;
        height *= 0.9;
    }
    
    CGContextRef ctxt = FVIconBitmapContextCreateWithSize(width, height);
    CGContextDrawImage(ctxt, CGRectMake(0, 0, CGBitmapContextGetWidth(ctxt), CGBitmapContextGetHeight(ctxt)), bigImage);
    
    CGImageRef smallImage = CGBitmapContextCreateImage(ctxt);
    FVIconBitmapContextDispose(ctxt);
    
    return smallImage;
}

static inline BOOL isBigImage(CGImageRef image)
{
    return CGImageGetWidth(image) > MAX_PIXEL_DIMENSION || CGImageGetHeight(image) > MAX_PIXEL_DIMENSION;
}

- (void)renderOffscreen
{      
    
    pthread_mutex_lock(&_mutex);
    
    // !!! early returns here after a cache check
    if (NULL != _fullImageRef) {
        // note that _fullImageRef may be non-NULL if we were added to the FVIconQueue multiple times before renderOffscreen was called
        NSParameterAssert(NULL != _thumbnailRef);
        pthread_mutex_unlock(&_mutex);
        return;
    }
    else if (_inDiskCache) {
        // This check only applies to really huge icons, so we keep _inDiskCache per-instance.
        // Normally it's about as fast to use ImageIO as FVIconCache, so we don't bother with it unless the image was resampled.
        _fullImageRef = [FVIconCache newImageNamed:_diskCacheName];
        if (NULL != _fullImageRef) {
            NSParameterAssert(NULL != _thumbnailRef);
            pthread_mutex_unlock(&_mutex);
            return;
        }
    }
    
    // at this point, _fullImageRef is NULL, but _thumbnailRef may be present (if we're recovering from -releaseResources)
    NSParameterAssert(NULL == _fullImageRef);
        
    CGImageSourceRef src = NULL;
    CFDataRef imageData = NULL;
    
    if (FVQTMovieType == _iconType) {
        QTMovie *movie = [[QTMovie alloc] initWithURL:_fileURL error:NULL];
        imageData = (CFDataRef)[[movie posterImage] TIFFRepresentation];
        [movie release];
    }
    else {
        imageData = (CFDataRef)[NSData dataWithContentsOfURL:_fileURL options:NSMappedRead error:NULL];
    }
    
    src = CGImageSourceCreateWithData(imageData, __imsrcOptions);
    
    if (src) {
        
        // may not be NULL
        if (NULL == _thumbnailRef)
            _thumbnailRef = CGImageSourceCreateThumbnailAtIndex(src, 0, __imsrcOptions);
        
        // always initialize sizes
        _thumbnailSize = _thumbnailRef ? NSMakeSize(CGImageGetWidth(_thumbnailRef), CGImageGetHeight(_thumbnailRef)) : NSZeroSize;

        // Now we have a thumbnail, see if we need to create the full image.
        if (shouldDrawFullImageWithSize(_desiredSize, _thumbnailSize)) {

            CGImageRef bigImage = CGImageSourceCreateImageAtIndex(src, 0, __imsrcOptions);
            // Resample large bitmaps on the fly for better drawing/memory performance
            if (bigImage && isBigImage(bigImage)) {
                _fullImageRef = createResampledImage(bigImage);
                CGImageRelease(bigImage);
                // If it's huge, store in the disk cache since ImageIO can be slow for e.g. 10K by 10K pixel images.
                // Otherwise, we'll count on ImageIO being just as fast at reading (which is probably optimistic).
                if (CGImageGetWidth(_fullImageRef) >= FVICONCACHE_THRESHOLD || CGImageGetHeight(_fullImageRef) >= FVICONCACHE_THRESHOLD) {
                    [FVIconCache cacheImage:_fullImageRef withName:_diskCacheName];
                    _inDiskCache = YES;
                }
            }
            else {
                // Small enough to keep in-memory and draw
                _fullImageRef = bigImage;
            }
        }
                
        CFRelease(src);
    } 
    
    pthread_mutex_unlock(&_mutex);
}    

- (void)fastDrawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context;
{
    if (pthread_mutex_trylock(&_mutex) == 0) {
        if (_thumbnailRef) {
            CGContextDrawImage(context, [self _drawingRectWithRect:dstRect], _thumbnailRef);
            pthread_mutex_unlock(&_mutex);
            if (_drawsLinkBadge)
                [self _drawBadgeInContext:context forIconInRect:dstRect];
        }
        else {
            pthread_mutex_unlock(&_mutex);
            // let drawInRect: handle the rect conversion
            [self drawInRect:dstRect inCGContext:context];
        }
    }
}

- (void)drawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context;
{
    // locking immediately blocks the main thread if we have a huge image that's loading via ImageIO
    BOOL didLock = (pthread_mutex_trylock(&_mutex) == 0);
    if (didLock && (NULL != _thumbnailRef || NULL != _fullImageRef)) {
        
        CGRect drawRect = [self _drawingRectWithRect:dstRect];
        CGImageRef image;
        if (shouldDrawFullImageWithSize(((NSRect *)&drawRect)->size, _thumbnailSize) && _fullImageRef)
            image = _fullImageRef;
        else
            image = _thumbnailRef;
        
        CGContextDrawImage(context, drawRect, image);
        if (_drawsLinkBadge)
            [self _drawBadgeInContext:context forIconInRect:dstRect];
    }
    else {
        [self _drawPlaceholderInRect:dstRect inCGContext:context];
    }
    if (didLock) pthread_mutex_unlock(&_mutex);
}

@end

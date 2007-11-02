//
//  FVCGImageIcon.m
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "FVCGImageIcon.h"
#import <QTKit/QTKit.h>

@implementation FVCGImageIcon

static CFDictionaryRef __imsrcOptions = NULL;
static const NSUInteger THUMBNAIL_THRESHOLD = 128;
static const NSUInteger MAX_PIXEL_DIMENSION = 1024; /* maximum height or width allowed */

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
        _fileURL = [aURL copy];
        _fullImageRef = NULL;
        _thumbnailRef = NULL;
        _diskCacheName = FVCreateDiskCacheNameWithURL(_fileURL);
        _inDiskCache = NO;
        int rc = pthread_mutex_init(&_mutex, NULL);
        if (rc)
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

- (NSSize)size { return _fullSize; }

- (BOOL)needsRenderForSize:(NSSize)size
{
    // we can draw with either one
    if (NULL == _thumbnailRef && NULL == _fullImageRef)
        return YES;
    BOOL needsRender = NO;
    if (pthread_mutex_trylock(&_mutex) == 0) {
        if (size.height > _thumbnailSize.height)
            needsRender = (NULL == _fullImageRef);
        else
            needsRender = (NULL == _thumbnailRef);
        pthread_mutex_unlock(&_mutex);
    }
    return needsRender;
}

// Huge images are slow to draw, so resample them first; we should store this in the disk cache, also, since ImageIO can be pretty slow reading really big images (10K by 10K pixels).
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
    // !!! early return here after a cache check
    pthread_mutex_lock(&_mutex);
    if (_inDiskCache) {
        CGImageRelease(_fullImageRef);
        _fullImageRef = [FVIconCache newImageNamed:_diskCacheName];
        BOOL success = (NULL != _fullImageRef);
        if (success) {
            pthread_mutex_unlock(&_mutex);
            return;
        }
    }
    pthread_mutex_unlock(&_mutex);
    
    CGImageSourceRef src;
    if (FVQTMovieType == _iconType) {
        QTMovie *movie = [[QTMovie alloc] initWithURL:_fileURL error:NULL];
        NSData *TIFFData = [[movie posterImage] TIFFRepresentation];
        [movie release];
        if (TIFFData)
            src = CGImageSourceCreateWithData((CFDataRef)TIFFData, __imsrcOptions);
        else
            src = NULL;
    }
    else {
        src = CGImageSourceCreateWithURL((CFURLRef)_fileURL, __imsrcOptions);
    }
    
    if (src) {
        pthread_mutex_lock(&_mutex);
        CGImageRelease(_thumbnailRef);
        CGImageRelease(_fullImageRef);
        CGImageRef bigImage = CGImageSourceCreateImageAtIndex(src, 0, __imsrcOptions);
        // Only cache the image if it's large; smaller images we'll just re-read, since we have to hit the disk anyway, and we always have the thumbnail to draw while the big one is loading.
        if (isBigImage(bigImage)) {
            _fullImageRef = createResampledImage(bigImage);
            CGImageRelease(bigImage);
            [FVIconCache cacheCGImage:_fullImageRef withName:_diskCacheName];
            _inDiskCache = YES;
        }
        else {
            _fullImageRef = bigImage;
        }
        _thumbnailRef = CGImageSourceCreateThumbnailAtIndex(src, 0, __imsrcOptions);
        _thumbnailSize = _thumbnailRef ? NSMakeSize(CGImageGetWidth(_thumbnailRef), CGImageGetHeight(_thumbnailRef)) : NSZeroSize;
        _fullSize = _fullImageRef ? NSMakeSize(CGImageGetWidth(_fullImageRef), CGImageGetHeight(_fullImageRef)) : NSZeroSize;
        pthread_mutex_unlock(&_mutex);
        CFRelease(src);
    } 
}    

- (void)fastDrawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context;
{
    if (pthread_mutex_trylock(&_mutex) == 0) {
        if (_thumbnailRef) {
            CGContextDrawImage(context, [self _drawingRectWithRect:dstRect], _thumbnailRef);
            pthread_mutex_unlock(&_mutex);
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
    // this blocks the main thread if we have a huge image that's loading via ImageIO
    if (pthread_mutex_trylock(&_mutex) == 0) {
        CGRect drawRect = [self _drawingRectWithRect:dstRect];
        if (CGRectGetHeight(drawRect) > _thumbnailSize.height) {
            // prefer the full image if we're drawing in a large rect and it's available
            CGImageRef image = (_fullImageRef ? _fullImageRef : _thumbnailRef);
            if (image)
                CGContextDrawImage(context, drawRect, image);
        }
        else if (_thumbnailRef) {
            CGContextDrawImage(context, drawRect, _thumbnailRef);
        }
        pthread_mutex_unlock(&_mutex);
    }
}

@end

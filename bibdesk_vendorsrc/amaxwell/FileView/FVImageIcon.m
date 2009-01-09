//
//  FVImageIcon.m
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

#import "FVImageIcon.h"
#import "FVFinderIcon.h"

@implementation FVImageIcon

static CFDictionaryRef _imsrcOptions = NULL;

// dimension at which we use FVIconCache
static const NSUInteger FVICONCACHE_THRESHOLD = 1024;

+ (void)initialize
{
    FVINITIALIZE(FVImageIcon);
    CFMutableDictionaryRef dict = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(dict, kCGImageSourceShouldAllowFloat, kCFBooleanTrue);
    _imsrcOptions = CFDictionaryCreateCopy(NULL, dict);
    CFRelease(dict);    
}

- (id)initWithURL:(NSURL *)aURL
{
    self = [super init];
    if (self) {
        
        _drawsLinkBadge = [[self class] _shouldDrawBadgeForURL:aURL copyTargetURL:&_fileURL];        
        _fullImage = NULL;
        _thumbnail = NULL;
        _diskCacheName = [FVIconCache createDiskCacheNameWithURL:_fileURL];
        _thumbnailSize = NSZeroSize;
        
        // QTMovie fails regularly, and I've also seen a few images that ImageIO won't load; this avoids looping trying to render them
        _fallbackIcon = nil;
        _loadFailed = NO;
        
        if (pthread_mutex_init(&_mutex, NULL) != 0)
            perror("pthread_mutex_init");             
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
    [_fileURL release];
    CGImageRelease(_thumbnail);
    CGImageRelease(_fullImage);
    free(_diskCacheName);
    [_fallbackIcon release];
    [super dealloc];
}

- (BOOL)tryLock { return pthread_mutex_trylock(&_mutex) == 0; }
- (void)lock { pthread_mutex_lock(&_mutex); }
- (void)unlock { pthread_mutex_unlock(&_mutex); }

- (BOOL)canReleaseResources;
{
    return NULL != _fullImage || NULL != _thumbnail || [_fallbackIcon canReleaseResources];
}

- (void)releaseResources
{
    [self lock];
    CGImageRelease(_fullImage);
    _fullImage = NULL;
    CGImageRelease(_thumbnail);
    _thumbnail = NULL;
    [_fallbackIcon releaseResources];
    [self unlock];
}

// only guaranteed to have _thumbnailSize; returning NSZeroSize causes _drawingRectWithRect: to return garbage
- (NSSize)size { return NSEqualSizes(_thumbnailSize, NSZeroSize) ? (NSSize) { FVMaxThumbnailDimension, FVMaxThumbnailDimension } : _thumbnailSize; }

- (BOOL)needsRenderForSize:(NSSize)size
{
    // faster without trylock... why?
    // trylock needed for scrolling, though
    BOOL needsRender = NO;
    if ([self tryLock]) {
        if (YES == _loadFailed)
            needsRender = [_fallbackIcon needsRenderForSize:size];
        else if (FVShouldDrawFullImageWithThumbnailSize(size, _thumbnailSize))
            needsRender = (NULL == _fullImage);
        else
            needsRender = (NULL == _thumbnail);
        _desiredSize = size;
        [self unlock];
    }
    return needsRender;
}

// FVMovieIcon overrides this to provide its TIFF data
- (CFDataRef)_copyDataForImageSourceWhileLocked
{
    return (CFDataRef)[[NSData alloc] initWithContentsOfURL:_fileURL options:NSMappedRead error:NULL];
}

- (void)renderOffscreen
{      
    
    [self lock];
    
    if ([NSThread instancesRespondToSelector:@selector(setName:)] && pthread_main_np() == 0)
        [[NSThread currentThread] setName:[_fileURL path]];

    [_fallbackIcon renderOffscreen];
    
    // !!! early returns here after a cache check
    if (NULL != _fullImage && NULL != _thumbnail) {
        // may be non-NULL if we were added to the FVOperationQueue multiple times before renderOffscreen was actually called
        [self unlock];
        return;
    }
    else {
                
        // initialize size since it could have been cached by some other instance
        // always load the thumbnail for the fast drawing path
        if (NULL == _thumbnail) {
            _thumbnail = [FVIconCache newThumbnailNamed:_diskCacheName];
            _thumbnailSize = FVCGImageSize(_thumbnail);
        }
        
        // if thumbnail was non-NULL, full image should also be non-NULL
        if (NULL != _thumbnail) {
            
            NSParameterAssert(NSEqualSizes(_thumbnailSize, NSZeroSize) == NO);
            
        	if (FVShouldDrawFullImageWithThumbnailSize(_desiredSize, _thumbnailSize) && NULL == _fullImage) {
                _fullImage = [FVIconCache newImageNamed:_diskCacheName];
                if (_fullImage) {
                	[self unlock];
                	return;
            	}
        	}
        	else {
             	// have full image or don't need to draw it
            	[self unlock];
            	return;
        	}
    	}
    }
    
    // at this point, neither icon should be present, unless ImageIO failed previously or caching failed
    NSAssert1(NULL == _fullImage, @"unexpected full image for %@", [_fileURL path]);
    NSAssert1(NULL == _thumbnail, @"unexpected _thumbnail for %@", [_fileURL path]);
        
    CGImageSourceRef src = NULL;
    CFDataRef imageData = [self _copyDataForImageSourceWhileLocked];
    
    if (imageData) {
        src = CGImageSourceCreateWithData(imageData, _imsrcOptions);
        CFRelease(imageData);
    }
    
    if (src && CGImageSourceGetCount(src) > 0) {

        // Now we have a thumbnail, create the full image so we have both of them in the cache.  Originally only the large image was cached to disk, and then only if it was actually resampled.  ImageIO is fast, in general, so FVIconCache doesn't really benefit us significantly.  The problem is FVMovieIcon, which hits the main thread to get image data.  To avoid hiccups in the subclass, then, we'll just cache both images for consistency.
        CGImageRef bigImage = CGImageSourceCreateImageAtIndex(src, 0, _imsrcOptions);
        if (bigImage) {
            // limit the size for better drawing/memory performance
            _fullImage = FVCreateResampledFullImage(bigImage, false);
            CGImageRelease(bigImage);
            bigImage = NULL;
            [FVIconCache cacheImage:_fullImage withName:_diskCacheName];
        }
        
        // _fullImage should not be NULL
        if (NULL == _thumbnail && NULL != _fullImage)
            _thumbnail = FVCreateResampledThumbnail(_fullImage, false);
        
        // always initialize sizes
        if (_thumbnail) {
            _thumbnailSize = FVCGImageSize(_thumbnail);
            [FVIconCache cacheThumbnail:_thumbnail withName:_diskCacheName];
        }
        else {
            _thumbnailSize = NSZeroSize;
        }
        
        // dispose of this immediately if we're not going to draw it; we can read from the cache if it's needed later
        if (FVShouldDrawFullImageWithThumbnailSize(_desiredSize, _thumbnailSize) == NO) {
            CGImageRelease(_fullImage);
            _fullImage = NULL;
        }
                
        CFRelease(src);
    } 
    
    if (NULL == _thumbnail && NULL == _fullImage) {
        _loadFailed = YES;
        if (nil == _fallbackIcon)
            _fallbackIcon = [[FVFinderIcon alloc] initWithFinderIconOfURL:_fileURL];
    }        
    
    [self unlock];
}    

- (void)fastDrawInRect:(NSRect)dstRect ofContext:(CGContextRef)context;
{
    if ([self tryLock]) {
        
        if (YES == _loadFailed && nil != _fallbackIcon) {
            [_fallbackIcon fastDrawInRect:dstRect ofContext:context];
            if (_drawsLinkBadge)
                [self _badgeIconInRect:dstRect ofContext:context];
        }
        
        if (_thumbnail) {
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
    else {
        [self _drawPlaceholderInRect:dstRect ofContext:context];
    }
}

- (void)drawInRect:(NSRect)dstRect ofContext:(CGContextRef)context;
{
    // locking immediately blocks the main thread if we have a huge image that's loading via ImageIO
    BOOL didLock = ([self tryLock]);
    if (didLock) {
        
        if (NULL != _thumbnail || NULL != _fullImage) {
            CGRect drawRect = [self _drawingRectWithRect:dstRect];
            CGImageRef image;

            // compare against dstRect, since that's what needsRenderForSize: uses
            if (FVShouldDrawFullImageWithThumbnailSize(dstRect.size, _thumbnailSize) && _fullImage)
                image = _fullImage;
            else 
                image = _thumbnail;
            
            CGContextDrawImage(context, drawRect, image);
        } 
        else if (YES == _loadFailed && nil != _fallbackIcon) {
            [_fallbackIcon drawInRect:dstRect ofContext:context];
        }
        else {
            [self _drawPlaceholderInRect:dstRect ofContext:context];
        }
        
        if (_drawsLinkBadge)
            [self _badgeIconInRect:dstRect ofContext:context];
        
    }
    else {
        [self _drawPlaceholderInRect:dstRect ofContext:context];
    }
    if (didLock) [self unlock];
}

@end

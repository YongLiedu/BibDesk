//
//  FVQLIcon.m
//  FileViewTest
//
//  Created by Adam Maxwell on 09/16/07.
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

#import "FVQLIcon.h"
#import "FVFinderIcon.h"
#import <QuickLook/QLThumbnailImage.h>

static const NSUInteger THUMBNAIL_MAX = 128;

// see http://www.cocoabuilder.com/archive/message/cocoa/2005/6/15/138943 for linking; need to use bundle_loader flag to allow the linker to resolve our superclass

@implementation FVQLIcon

static BOOL FVQLIconDisabled = NO;

+ (void)initialize
{
    FVQLIconDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"FVQLIconDisabled"];
}

- (id)initWithURL:(NSURL *)theURL;
{
    if (FVQLIconDisabled) {
        [self release];
        self = nil;
    }
    else if ((self = [super init])) {
        // QL seems to fail a large percentage of the time on my system, and it's also pretty slow.  Since FVFinderIcon is now fast and relatively low overhead, preallocate the fallback icon to avoid waiting for QL to return NULL.
        _fallbackIcon = [[FVFinderIcon allocWithZone:[self zone]] initWithFinderIconOfURL:theURL];
        
        _drawsLinkBadge = [[self class] _shouldDrawBadgeForURL:&theURL];
        
        _fileURL = [theURL copy];
        _fullImageRef = NULL;
        _thumbnailSize = NSZeroSize;
        _desiredSize = NSZeroSize;
        _quickLookFailed = NO;
        
        if (pthread_mutex_init(&_mutex, NULL) != 0)
            perror("pthread_mutex_init");
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
    [_fileURL release];
    CGImageRelease(_fullImageRef);
    CGImageRelease(_thumbnailRef);
    [_fallbackIcon release];
    [super dealloc];
}

- (void)releaseResources
{
    pthread_mutex_lock(&_mutex);
    CGImageRelease(_fullImageRef);
    _fullImageRef = NULL;
    [_fallbackIcon releaseResources];
    pthread_mutex_unlock(&_mutex);
}

- (NSSize)size { return _thumbnailSize; }

static inline BOOL shouldDrawFullImageWithSize(NSSize desiredSize, NSSize thumbnailSize)
{
    return (desiredSize.height > 1.2 * thumbnailSize.height || desiredSize.width > 1.2 * thumbnailSize.width);
}

- (BOOL)needsRenderForSize:(NSSize)size
{
    BOOL needsRender = NO;
    if (pthread_mutex_trylock(&_mutex) == 0) {
        if (NO == _quickLookFailed) {
            // The _fullSize is zero or whatever quicklook returned last time, which may be something odd like 78x46.  Since we ask QL for a size but it constrains the size it actually returns based on the icon's aspect ratio, we have to check height and width.  Just checking height in this was causing an endless loop asking for a size it won't return.
            if (shouldDrawFullImageWithSize(size, _thumbnailSize))
                needsRender = (NULL == _fullImageRef);
            else
                needsRender = (NULL == _thumbnailRef);
        }
        else {
            needsRender = [_fallbackIcon needsRenderForSize:size];
        }
        _desiredSize = size;
        pthread_mutex_unlock(&_mutex);
    }
    return needsRender;
}

- (void)renderOffscreen
{        
    pthread_mutex_lock(&_mutex);
    
    if (NO == _quickLookFailed) {
        
        CGSize requestedSize = (CGSize) { THUMBNAIL_MAX, THUMBNAIL_MAX };
        
        if (NULL == _thumbnailRef)
            _thumbnailRef = QLThumbnailImageCreate(NULL, (CFURLRef)_fileURL, requestedSize, NULL);
        
        if (NULL == _thumbnailRef)
            _quickLookFailed = YES;
        
        // always initialize sizes
        _thumbnailSize = _thumbnailRef ? NSMakeSize(CGImageGetWidth(_thumbnailRef), CGImageGetHeight(_thumbnailRef)) : NSZeroSize;

        if (shouldDrawFullImageWithSize(_desiredSize, _thumbnailSize)) {
            
            if (NULL != _fullImageRef) {
                
                NSSize currentSize = NSMakeSize(CGImageGetWidth(_fullImageRef), CGImageGetHeight(_fullImageRef));
                
                NSSize targetSize;
#if __LP64__
                targetSize.width = trunc(_desiredSize.width);
                targetSize.height = trunc(_desiredSize.height);
#else
                targetSize.width = truncf(_desiredSize.width);
                targetSize.height = truncf(_desiredSize.height);
#endif
                if (NSEqualSizes(currentSize, targetSize) == NO) {
                    CGImageRelease(_fullImageRef);
                    _fullImageRef = NULL;
                }

            }
            
            if (NULL == _fullImageRef) {
                requestedSize = *(CGSize *)&_desiredSize;
                _fullImageRef = QLThumbnailImageCreate(NULL, (CFURLRef)_fileURL, requestedSize, NULL);
            }
            
            if (NULL == _fullImageRef)
                _quickLookFailed = YES;
        }
    }
    
    // preceding calls may have set the failure flag
    if (_quickLookFailed) {
        if ([_fallbackIcon needsRenderForSize:_desiredSize])
            [_fallbackIcon renderOffscreen];
    }
    
    pthread_mutex_unlock(&_mutex);
}    

- (void)drawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context;
{
    BOOL didLock = (pthread_mutex_trylock(&_mutex) == 0);
    if (didLock && (NULL != _thumbnailRef || NULL != _fullImageRef)) {
        
        CGRect drawRect = [self _drawingRectWithRect:dstRect];
            
        CGImageRef image;
        // always fall back on the thumbnail
        if (shouldDrawFullImageWithSize(((NSRect *)&drawRect)->size, _thumbnailSize) && _fullImageRef)
            image = _fullImageRef;
        else
            image = _thumbnailRef;
        
        // Apple's QL plugins for multiple page types (.pages, .plist, .xls etc) draw text right up to the margin of the icon, so we'll add a small whitespace margin.  The decoration option will do this for us, but it also draws with a dog-ear, and I don't want that because it's inconsistent with our other thumbnail classes.
        CGContextSaveGState(context);
        CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
        CGContextFillRect(context, drawRect);
        drawRect = CGRectInset(drawRect, CGRectGetWidth(drawRect) / 20, CGRectGetHeight(drawRect) / 20);
        CGContextClipToRect(context, drawRect);
        CGContextDrawImage(context, drawRect, image);
        CGContextRestoreGState(context);
        
        if (_drawsLinkBadge)
            [self _drawBadgeInContext:context forIconInRect:dstRect];
        
        pthread_mutex_unlock(&_mutex);
    }
    else if (_quickLookFailed && nil != _fallbackIcon) {
        [_fallbackIcon drawInRect:dstRect inCGContext:context];
    }
    else {
        [self _drawPlaceholderInRect:dstRect inCGContext:context];
    }
    if (didLock) pthread_mutex_unlock(&_mutex);
}

@end

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
        NSZone *zone = [self zone];
        [self release];
        self = [[FVFinderIcon allocWithZone:zone] initWithFinderIconOfURL:theURL];
    }
    else if ((self = [super init])) {
        _fileURL = [theURL copy];
        _imageRef = NULL;
        _fullSize = NSZeroSize;
        _desiredSize = NSZeroSize;
        
        // QL seems to fail a large percentage of the time on my system, and it's also pretty slow.  Since FVFinderIcon is now fast and relatively low overhead, preallocate the fallback icon to avoid waiting for QL to return NULL.
        _fallbackIcon = [[FVFinderIcon allocWithZone:[self zone]] initWithFinderIconOfURL:_fileURL];
        _quickLookFailed = NO;
        
        _drawsLinkBadge = [[self class] _shouldDrawBadgeForURL:theURL];
        if (_drawsLinkBadge)
            theURL = [[self class] _resolvedURLWithURL:theURL];
        
        NSInteger rc = pthread_mutex_init(&_mutex, NULL);
        if (rc)
            perror("pthread_mutex_init");
    }
    return self;
}

- (void)releaseResources
{
    pthread_mutex_lock(&_mutex);
    CGImageRelease(_imageRef);
    _imageRef = NULL;
    [_fallbackIcon releaseResources];
    pthread_mutex_unlock(&_mutex);
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
    [_fileURL release];
    CGImageRelease(_imageRef);
    [_fallbackIcon release];
    [super dealloc];
}

- (NSSize)size { return _fullSize; }

// allow 20% difference in either dimension
static inline bool checkSizes(NSSize currentSize, NSSize size)
{
    if (size.height > 1.2*currentSize.height && size.width > 1.2*currentSize.width)
        return true;
    else if (size.height < 0.8*currentSize.height && size.width < 0.8*currentSize.width)
        return true;
    return false;
}

- (BOOL)needsRenderForSize:(NSSize)size
{
    BOOL needsRender = NO;
    if (pthread_mutex_trylock(&_mutex) == 0) {
        if (NO == _quickLookFailed) {
            // The _fullSize is zero or whatever quicklook returned last time, which may be something odd like 78x46.  Since we ask QL for a size but it constrains the size it actually returns based on the icon's aspect ratio, we have to check height and width.  Just checking height in this was causing an endless loop asking for a size it won't return.
            needsRender = (NULL == _imageRef || checkSizes(_fullSize, size));
        }
        else {
            needsRender = [_fallbackIcon needsRenderForSize:size];
        }
        _desiredSize = size;
    }
    pthread_mutex_unlock(&_mutex);
    return needsRender;
}

- (void)renderOffscreen
{        
    pthread_mutex_lock(&_mutex);
    CGImageRelease(_imageRef);
    _imageRef = NULL;

    if (NO == _quickLookFailed)
        _imageRef = QLThumbnailImageCreate(NULL, (CFURLRef)_fileURL, *(CGSize *)&_desiredSize, NULL);

    if (NULL == _imageRef) {
        _quickLookFailed = YES;
        if ([_fallbackIcon needsRenderForSize:_desiredSize])
            [_fallbackIcon renderOffscreen];
    }
    else {
        _fullSize = NSMakeSize(CGImageGetWidth(_imageRef), CGImageGetHeight(_imageRef));
    }
    
    pthread_mutex_unlock(&_mutex);
}    

- (void)drawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context;
{
    BOOL didLock = (pthread_mutex_trylock(&_mutex) == 0);
    if (didLock && _imageRef) {
        CGContextDrawImage(context, [self _drawingRectWithRect:dstRect], _imageRef);
    }
    else if (nil != _fallbackIcon) {
        [_fallbackIcon drawInRect:dstRect inCGContext:context];
    }
    else {
        [self _drawPlaceholderInRect:dstRect inCGContext:context];
    }
    if (didLock) pthread_mutex_unlock(&_mutex);
}

- (BOOL)needsShadow { return (NULL != _imageRef || [_fallbackIcon needsShadow]); }

@end

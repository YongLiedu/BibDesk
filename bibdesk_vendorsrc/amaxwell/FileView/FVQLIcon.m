//
//  FVQLIcon.m
//  FileViewTest
//
//  Created by Adam Maxwell on 09/16/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "FVQLIcon.h"
#import "FVFinderIcon.h"
#import <QuickLook/QLThumbnailImage.h>

// see http://www.cocoabuilder.com/archive/message/cocoa/2005/6/15/138943 for linking; need to use bundle_loader flag to allow the linker to resolve our superclass

@implementation FVQLIcon

- (id)initWithURL:(NSURL *)theURL;
{
    self = [super init];
    if (self) {
        _fileURL = [theURL copy];
        _imageRef = NULL;
        _fullSize = NSZeroSize;
        _desiredSize = NSZeroSize;
        _fallbackIcon = nil;
        int rc = pthread_mutex_init(&_mutex, NULL);
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

- (BOOL)needsRenderForSize:(NSSize)size
{
    BOOL needsRender = NO;
    pthread_mutex_lock(&_mutex);
    if (NULL == _imageRef || size.height > 1.2 * _fullSize.height) {
        if (nil == _fallbackIcon) {
            _desiredSize = size;
            CGImageRelease(_imageRef);
            _imageRef = NULL;
            needsRender = YES;
        }
        else {
            needsRender = [_fallbackIcon needsRenderForSize:size];
        }
    }
    pthread_mutex_unlock(&_mutex);
    return needsRender;
}

- (void)renderOffscreen
{        
    pthread_mutex_lock(&_mutex);
    CGImageRelease(_imageRef);
    if (nil == _fallbackIcon)
        _imageRef = QLThumbnailImageCreate(NULL, (CFURLRef)_fileURL, *(CGSize *)&_desiredSize, NULL);
    if (NULL == _imageRef) {
        
        if (nil == _fallbackIcon)
            _fallbackIcon = [[FVFinderIcon allocWithZone:[self zone]] initWithFinderIconOfURL:_fileURL ofSize:_desiredSize];
        [_fallbackIcon renderOffscreen];
    }
    else
        _fullSize = NSMakeSize(CGImageGetWidth(_imageRef), CGImageGetHeight(_imageRef));
    pthread_mutex_unlock(&_mutex);
}    

- (void)drawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context;
{
    pthread_mutex_lock(&_mutex);
    if (_imageRef) {
        CGContextDrawImage(context, [self _drawingRectWithRect:dstRect], _imageRef);
    }
    else if (nil != _fallbackIcon) {
        [_fallbackIcon drawInRect:dstRect inCGContext:context];
    }
    pthread_mutex_unlock(&_mutex);
}

@end

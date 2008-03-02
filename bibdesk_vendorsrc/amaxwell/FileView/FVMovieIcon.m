//
//  FVMovieIcon.m
//  FileView
//
//  Created by Adam Maxwell on 2/22/08.
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

#import "FVMovieIcon.h"
#import "FVFinderIcon.h"
#import <QTKit/QTKit.h>

@implementation FVMovieIcon

static NSLock *_movieLock = nil;
static NSInvocation *_movieInvocation = nil;

+ (void)initialize
{
    FVINITIALIZE(FVMovieIcon);
    
    /*
     QTMovie can't be used from multiple threads simultaneously, since the underlying C functions apparently aren't thread safe.  Deallocation in particular seems to crash.  In addition, Christiaan found a case where a QT component tried to display a window and ended up trying to run NSApp in a modal session from a thread.  While modal windows are supposed to work from a thread, it appeared to cause a crash in some Carbon window drawing code.
     
     If performance problems are evident, we could just use Quick Look for thumbnailing movies, but I don't see any problems dropping ~200 movies on the test program window.
     
     Note: QTKit on 10.5 has enterQTKitOnThread/exitQTKitOnThread, which might be worth investigating as well.  Another note: enterQTKitOnThread does not seem to help, even locking beforehand so multiple threads aren't calling it simultaneously.  Trying to load certain wmv files causes it to crash very reliably.
     
     */
    
    // lock around the invocation; we can only call this from a single instance at a time
    _movieLock = [NSLock new];
    NSMethodSignature *sig = [self methodSignatureForSelector:@selector(_copyTIFFDataFromMovieAtURL:)];
    NSParameterAssert(nil != sig);
    _movieInvocation = [[NSInvocation invocationWithMethodSignature:sig] retain];
    [_movieInvocation setTarget:self];
    [_movieInvocation setSelector:@selector(_copyTIFFDataFromMovieAtURL:)];
}

+ (NSData *)_copyTIFFDataFromMovieAtURL:(NSURL *)aURL
{
    NSParameterAssert(nil != aURL);
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** +[%@ %@] requires main thread", self, NSStringFromSelector(_cmd));
    NSAssert2([_movieLock tryLock] == NO, @"*** threading violation *** +[%@ %@] requires caller to lock _movieLock", self, NSStringFromSelector(_cmd));
    NSMutableDictionary *attributes = [NSMutableDictionary new];
    [attributes setObject:aURL forKey:QTMovieURLAttribute];
    
    // Loading /DevTools/Documentation/DocSets/com.apple.ADC_Reference_Library.CoreReference.docset/Contents/Resources/Documents/documentation/QuickTime/REF/Effects/gradwip2.mov puts up a stupid modal dialog about searching for resources /after/ blocking for a long time.
    [attributes setObject:[NSNumber numberWithBool:NO] forKey:QTMovieResolveDataRefsAttribute];
    
    // QTMovieResolveDataRefsAttribute = NO probably implies QTMovieAskUnresolvedDataRefsAttribute = NO ...
    [attributes setObject:[NSNumber numberWithBool:NO] forKey:QTMovieAskUnresolvedDataRefsAttribute];
    
    QTMovie *movie = [[QTMovie alloc] initWithAttributes:attributes error:NULL];
    [attributes release];
    
    NSData *data = [[[movie posterImage] TIFFRepresentation] copy];
    [movie release];    
    
    return data;
}

+ (CFDataRef)_copyTIFFDataFromMovieOnMainThreadWithURL:(NSURL *)aURL
{
    [_movieLock lock];
    [_movieInvocation setArgument:&aURL atIndex:2];
    NSData *imageData;
    [_movieInvocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:YES modes:[NSArray arrayWithObject:(id)kCFRunLoopCommonModes]];
    [_movieInvocation getReturnValue:&imageData];
    [_movieLock unlock];
    return (CFDataRef)imageData;
}

+ (BOOL)canInitWithURL:(NSURL *)url;
{
    return [QTMovie canInitWithURL:url];
}

- (id)initWithURL:(NSURL *)aURL
{
    self = [super initWithURL:aURL];
    if (self) {
        
        // We need a failure bit and fallback icon because some movies have external resources that can't be found
        _movieFailed = NO;
        _fallbackIcon = nil;          
    }
    return self;
}

- (void)dealloc
{
    [_fallbackIcon release];
    [super dealloc];
}

- (BOOL)canReleaseResources;
{
    return NULL != _fullImage;
}

- (void)releaseResources
{
    [super releaseResources];
    [self lock];
    [_fallbackIcon releaseResources];
    [self unlock];
}

- (BOOL)needsRenderForSize:(NSSize)size
{
    BOOL needsRender = NO;
    if ([self tryLock]) {
        
        if (YES == _movieFailed) {
            needsRender = [_fallbackIcon needsRenderForSize:size];
            [self unlock];
        }
        else {
            [self unlock];
            needsRender = [super needsRenderForSize:size];
        }

    }
    return needsRender;
}

// object is locked while this is called, so we can manipulate ivars
- (CFDataRef)_copyDataForImageSourceWhileLocked
{
    NSAssert2([self tryLock] == NO, @"*** threading violation *** -[%@ %@] requires caller to lock self", [self class], NSStringFromSelector(_cmd));
    
    // !!! cache the resulting images to disk unconditionally, in order to avoid hitting the main thread again
    CFDataRef imageData = [[self class] _copyTIFFDataFromMovieOnMainThreadWithURL:_fileURL];
    if (NULL == imageData) {
        _movieFailed = YES;
        if (nil == _fallbackIcon)
            _fallbackIcon = [[FVFinderIcon alloc] initWithFinderIconOfURL:_fileURL];
    }
    return imageData;
}

- (void)fastDrawInRect:(NSRect)dstRect ofContext:(CGContextRef)context;
{
    if ([self tryLock]) {
        if (YES == _movieFailed && nil != _fallbackIcon) {
            // let drawInRect: handle the rect conversion
            [_fallbackIcon fastDrawInRect:dstRect ofContext:context];
            
            if (_drawsLinkBadge)
                [self _badgeIconInRect:dstRect ofContext:context];
            [self unlock];
        }
        else {
            [self unlock];
            [super fastDrawInRect:dstRect ofContext:context];
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
    if (didLock && (YES == _movieFailed && nil != _fallbackIcon)) {
        [_fallbackIcon drawInRect:dstRect ofContext:context];
        
        if (_drawsLinkBadge)
            [self _badgeIconInRect:dstRect ofContext:context];
        
        [self unlock];
    }
    else {
        if (didLock) [self unlock];
        [super drawInRect:dstRect ofContext:context];
    }
}

@end

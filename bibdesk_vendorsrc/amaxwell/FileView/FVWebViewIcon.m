//
//  FVWebViewIcon.m
//  FileView
//
//  Created by Adam Maxwell on 12/30/07.
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

#import "FVWebViewIcon.h"
#import "FVFinderIcon.h"
#import <WebKit/WebKit.h>
#import <SystemConfiguration/SystemConfiguration.h>

@implementation FVWebViewIcon

static BOOL FVWebIconDisabled = NO;

+ (void)initialize
{
    FVWebIconDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"FVWebIconDisabled"];
}

- (id)initWithURL:(NSURL *)aURL;
{
    NSParameterAssert([[aURL scheme] isEqualToString:@"http"]);
    
    // if this is disabled, return a finder icon instead
    if (FVWebIconDisabled) {
        NSZone *zone = [self zone];
        [self release];
        self = [[FVFinderIcon allocWithZone:zone] initWithURLScheme:[aURL scheme]];
    }
    else if ((self = [super init])) {
        _httpURL = [aURL copy];
        _fullImageRef = NULL;
        _thumbnailRef = NULL;
        _fallbackIcon = nil;
        
        // track failure messages via the delegate
        _webviewFailed = NO;
        
        // main thread only; keeps track of whether a webview has been created
        _triedWebView = NO;
        
        const char *name = [[aURL absoluteString] UTF8String];
        _diskCacheName = NSZoneMalloc([self zone], sizeof(char) * (strlen(name) + 1));
        strcpy(_diskCacheName, name);
        
        NSInteger rc = pthread_mutex_init(&_mutex, NULL);
        if (rc)
            perror("pthread_mutex_init");
    }
    return self;
}

- (void)_releaseWebView
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    [_webView stopLoading:nil];
    [_webView setFrameLoadDelegate:nil];
    [_webView release];
    _webView = nil;
}

- (void)dealloc
{
    // it's very unlikely that we'll reach this on a non-main thread or with a non-nil webview, but just in case...
    [self performSelectorOnMainThread:@selector(_releaseWebView) withObject:nil waitUntilDone:YES];
    
    pthread_mutex_destroy(&_mutex);
    CGImageRelease(_fullImageRef);
    CGImageRelease(_thumbnailRef);
    [_httpURL release];
    [_fallbackIcon release];
    NSZoneFree([self zone], _diskCacheName);
    [super dealloc];
}

- (void)releaseResources
{ 
    // the thumbnail is small enough to always keep around
    pthread_mutex_lock(&_mutex);
    CGImageRelease(_fullImageRef);
    _fullImageRef = NULL;
    
    // currently a noop
    [_fallbackIcon releaseResources];
    pthread_mutex_unlock(&_mutex);    
}

- (NSSize)size { return (NSSize){ 1000, 900 }; }

- (BOOL)needsRenderForSize:(NSSize)size
{
    BOOL needsRender = NO;
    if (pthread_mutex_trylock(&_mutex) == 0) {
        
        /*
         1) if we know the web view failed, the only thing we can use is the fallback icon
         2) if we're drawing a large icon and the web view hasn't failed (yet), we depend on _fullImageRef (which may be in disk cache)
         3) if we're drawing a small icon and the web view hasn't failed (yet), we depend on _thumbnailRef (so webview needs to load)
         */
        
        if (YES == _webviewFailed)
            needsRender = [_fallbackIcon needsRenderForSize:size];
        else if (size.height > 1.2 * [self size].height)
            needsRender = (NULL == _fullImageRef);
        else
            needsRender = (NULL == _thumbnailRef);
        pthread_mutex_unlock(&_mutex);
    }
    return needsRender;
}

// this is intended to be a fast check to see if should try to use WebView
- (BOOL)_canReachURL
{
    BOOL reachable = NO;
    SCNetworkConnectionFlags flags;
    
    if (SCNetworkCheckReachabilityByName([[_httpURL host] UTF8String], &flags))
        reachable = !(flags & kSCNetworkFlagsConnectionRequired) && (flags & kSCNetworkFlagsReachable);
    return reachable;
}

// returns a 1/5 scale image; change this if -size changes (small image should be <= 200 pixels)
- (CGImageRef)_createResampledImage;
{
    CGFloat width = [self size].width / 5;
    CGFloat height = [self size].height / 5;
        
    // these will always be the same size, so use the context cache
    CGContextRef ctxt = [FVBitmapContextCache newBitmapContextOfWidth:width height:height];
    CGContextDrawImage(ctxt, CGRectMake(0, 0, CGBitmapContextGetWidth(ctxt), CGBitmapContextGetHeight(ctxt)), _fullImageRef);
    
    CGImageRef smallImage = CGBitmapContextCreateImage(ctxt);
    [FVBitmapContextCache disposeOfBitmapContext:ctxt];
    
    return smallImage;
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame;
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    pthread_mutex_lock(&_mutex);
    _webviewFailed = YES;
    pthread_mutex_unlock(&_mutex);
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame;
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    pthread_mutex_lock(&_mutex);
    _webviewFailed = YES;
    pthread_mutex_unlock(&_mutex);
}

- (void)_mainFrameDidFinishLoading
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));

    // the delegate methods will tell us if the load failed; I see no other way to ask for status    
    if (NO == _webviewFailed) {
        
        // display the main frame's view directly to avoid showing the scrollers
        
        WebFrameView *view = [[_webView mainFrame] frameView];
        [view setAllowsScrolling:NO];
        
        NSSize size = [self size];
        CGContextRef context = [FVBitmapContextCache newBitmapContextOfWidth:size.width height:size.height];
        NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:[view isFlipped]];
        [view displayRectIgnoringOpacity:[view bounds] inContext:nsContext];
        
        pthread_mutex_lock(&_mutex);
        
        // full image is large, so cache it to disk in case we get a -releaseResources or another view needs it
        CGImageRelease(_fullImageRef);
        _fullImageRef = CGBitmapContextCreateImage(context);
        [FVIconCache cacheCGImage:_fullImageRef withName:_diskCacheName];
        
        // resample to a thumbnail size that will draw quickly
        CGImageRelease(_thumbnailRef);
        _thumbnailRef = [self _createResampledImage];
        
        pthread_mutex_unlock(&_mutex);
        
        [FVBitmapContextCache disposeOfBitmapContext:context];
    }
    else {
        // some web resource failed to load
        pthread_mutex_lock(&_mutex);
        if (nil == _fallbackIcon)
            _fallbackIcon = [[FVFinderIcon alloc] initWithURLScheme:[_httpURL scheme]];
        pthread_mutex_unlock(&_mutex);
    }
    
    // clear out the webview, since we won't need it again
    [self _releaseWebView];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    // wait for the main frame
    if ([frame isEqual:[_webView mainFrame]])
        [self _mainFrameDidFinishLoading];
}

- (void)renderOffscreenOnMainThread 
{ 
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));

    // Originally just checked nil here, but logging showed that a webview was instantiated twice and the page loaded both times.  A nil webview is not a sufficient condition, since there's a delay between needsRenderForSize: and renderOffscreen; remember that the webview isn't rendering synchronously as in the other subclasses, so it may finish in between those calls.
    if (nil == _webView && NO == _triedWebView) {
        
        _triedWebView = YES;
        
        NSSize size = [self size];
        
        // always use the WebKit cache, and use a short timeout (default is 60 seconds)
        NSURLRequest *request = [NSURLRequest requestWithURL:_httpURL cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:1.0];
        
        // See also http://lists.apple.com/archives/quicklook-dev/2007/Nov/msg00047.html
        // Note: changed from blocking to non-blocking; we now just keep state and rely on the
        // delegate methods.
        
        _webView = [[WebView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
        [_webView setFrameLoadDelegate:self];
        [[_webView mainFrame] loadRequest:request];
    }
}

- (void)renderOffscreen
{
    // !!! early return here after a cache check
    pthread_mutex_lock(&_mutex);
    
    CGImageRelease(_fullImageRef);
    _fullImageRef = [FVIconCache newImageNamed:_diskCacheName];
    if (_fullImageRef) {
        
        // this may have been added to the disk cache by another instance; in that case, we need to create a new thumbnail
        if (NULL == _thumbnailRef)
            _thumbnailRef = [self _createResampledImage];
        
        pthread_mutex_unlock(&_mutex);
        return;
    }
    pthread_mutex_unlock(&_mutex);
    
    // if we can't even reach the network, don't bother blocking the main thread for a failed load
    if ([self _canReachURL]) {
        [self performSelectorOnMainThread:@selector(renderOffscreenOnMainThread) withObject:nil waitUntilDone:YES];
    }
    else {
        // load a Finder icon and set the webview failure bit; we won't try again
        pthread_mutex_lock(&_mutex);
        _webviewFailed = YES;
        if (nil == _fallbackIcon)
            _fallbackIcon = [[FVFinderIcon alloc] initWithURLScheme:[_httpURL scheme]];
        [_fallbackIcon renderOffscreen];
        pthread_mutex_unlock(&_mutex);
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
    else {
        [self _drawPlaceholderInRect:dstRect inCGContext:context];
    }
}

- (void)drawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context 
{ 
    if (pthread_mutex_trylock(&_mutex) == 0) {
        
        CGRect drawRect = [self _drawingRectWithRect:dstRect];
        if (_fullImageRef && (NULL == _thumbnailRef || CGRectGetHeight(drawRect) > 1.2 * CGImageGetHeight(_thumbnailRef)))
            CGContextDrawImage(context, drawRect, _fullImageRef);
        else if (_thumbnailRef)
            CGContextDrawImage(context, drawRect, _thumbnailRef);
        else if (NO == _webviewFailed || nil == _fallbackIcon)
            [self _drawPlaceholderInRect:dstRect inCGContext:context];
        else 
            [_fallbackIcon drawInRect:dstRect inCGContext:context];
        
        pthread_mutex_unlock(&_mutex);
    }
    else {
        [self _drawPlaceholderInRect:dstRect inCGContext:context];
    }
}

@end

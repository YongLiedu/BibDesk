//
//  FVWebViewIcon.m
//  FileView
//
//  Created by Adam Maxwell on 12/30/07.
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

#import "FVWebViewIcon.h"
#import "FVFinderIcon.h"
#import "FVTextIcon.h"
#import "FVUtilities.h"
#import <WebKit/WebKit.h>
#import <SystemConfiguration/SystemConfiguration.h>

#if !defined(MAC_OS_X_VERSION_10_5) || (MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5)
enum {
    WebCacheModelDocumentViewer = 0,
    WebCacheModelDocumentBrowser = 1,
    WebCacheModelPrimaryWebBrowser = 2
};
@interface WebPreferences (FVWebViewIcon)
- (void)setCacheModel:(NSUInteger)cacheModel;
@end
#endif

@implementation FVWebViewIcon

static BOOL FVWebIconDisabled = NO;

// webview pool variables to keep memory usage down; pool size is tunable
static NSInteger __maxWebViews = 5;
static NSMutableArray *__availableWebViews = nil;
static NSInteger __numberOfWebViews = 0;
static NSString * const FVWebIconWebViewAvailableNotificationName = @"FVWebIconWebViewAvailableNotificationName";

// size of the view frame; large enough to fit a reasonably sized page
static const NSSize __webViewSize = (NSSize){ 1000, 900 };

// framework private; notifies the file view that a webkit-async load has finished
NSString * const FVWebIconUpdatedNotificationName = @"FVWebIconUpdatedNotificationName";

+ (void)initialize
{
    // apparently NSURLConnection has bug(s) on Tiger. We get crash reports on 10.4.10, see bug # 1904921, while on 10.4.11 it also is known to have a serious crasher, see http://www.red-sweater.com/blog/452/nsurlconnection-crashing-epidemic 
    //[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4], @"FVWebIconDisabled", nil]];
    FVWebIconDisabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"FVWebIconDisabled"];
    NSInteger maxViews = [[NSUserDefaults standardUserDefaults] integerForKey:@"FVWebIconMaximumNumberOfWebViews"];
    if (maxViews > 0)
        __maxWebViews = maxViews;
    
    __availableWebViews = [[NSMutableArray alloc] initWithCapacity:__maxWebViews];
}

// return nil if __maxWebViews is exceeded
+ (WebView *)popWebView 
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    WebView *nextView = nil;
    if ([__availableWebViews count]) {
        nextView = [__availableWebViews lastObject];
        [__availableWebViews removeLastObject];
    }
    else if (__numberOfWebViews <= __maxWebViews) {
        nextView = [[WebView alloc] initWithFrame:NSMakeRect(0, 0, __webViewSize.width, __webViewSize.height)];
        __numberOfWebViews++;
    }
    return nextView;
}

+ (void)pushWebView:(WebView *)aView
{
    NSParameterAssert(nil != aView);
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    [__availableWebViews insertObject:aView atIndex:0];
    [[NSNotificationCenter defaultCenter] postNotificationName:FVWebIconWebViewAvailableNotificationName object:self];
}

- (id)initWithURL:(NSURL *)aURL;
{    
    NSParameterAssert(nil != [aURL scheme]);
    
    // if this is disabled or not an http URL, return a finder icon instead
    if (FVWebIconDisabled || (NO == [[aURL scheme] isEqualToString:@"http"] && NO == [aURL isFileURL])) {
        NSZone *zone = [self zone];
        [self release];
        if ([aURL isFileURL])
            self = [[FVTextIcon allocWithZone:zone] initWithHTMLAtURL:aURL];
        else
            self = [[FVFinderIcon allocWithZone:zone] initWithFinderIconOfURL:aURL];
    }
    else if ((self = [super init])) {
        _httpURL = [aURL copy];
        _fullImageRef = NULL;
        _thumbnailRef = NULL;
        _fallbackIcon = nil;
        
        // track failure messages via the delegate
        _webviewFailed = NO;
        
        // keeps track of whether a webview has been created
        _isRendering = NO;
        _diskCacheName = [FVIconCache createDiskCacheNameWithURL:_httpURL];

        if (pthread_mutex_init(&_mutex, NULL) != 0)
            perror("pthread_mutex_init");
    }
    return self;
}

- (void)_releaseWebView
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    // in case we get -releaseResources or -dealloc while waiting for another webview
    [[NSNotificationCenter defaultCenter] removeObserver:self name:FVWebIconWebViewAvailableNotificationName object:[self class]];
    if (nil != _webView) {
        [_webView setPolicyDelegate:nil];
        [_webView setFrameLoadDelegate:nil];
        [_webView stopLoading:nil];
        [[self class] pushWebView:_webView];
        _webView = nil;
    }
}

- (void)dealloc
{
    // it's very unlikely that we'll see this on a non-main thread, but just in case...
    [self performSelectorOnMainThread:@selector(_releaseWebView) withObject:nil waitUntilDone:YES modes:[NSArray arrayWithObject:(id)kCFRunLoopCommonModes]];
    
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
    // Cancel any pending loads; set _isRendering to NO or -renderOffscreenOnMainThread will never complete if it gets called again
    [self performSelectorOnMainThread:@selector(_releaseWebView) withObject:nil waitUntilDone:YES modes:[NSArray arrayWithObject:(id)kCFRunLoopCommonModes]];

    // the thumbnail is small enough to always keep around
    pthread_mutex_lock(&_mutex);
    _isRendering = NO;
    
    if (_fullImageRef != NULL)
        CGImageRelease(_fullImageRef);
    _fullImageRef = NULL;
    
    // currently a noop
    [_fallbackIcon releaseResources];
    pthread_mutex_unlock(&_mutex);    
}

// size of the _fullImageRef
- (NSSize)size { return (NSSize){ 500, 450 }; }

// actual size of the webview
- (NSSize)_webviewSize { return __webViewSize; }

// size of the _thumbnailRef (1/5 of webview size)
- (NSSize)_thumbnailSize { return (NSSize){ 200, 180 }; }

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
            needsRender = (nil == _fallbackIcon || [_fallbackIcon needsRenderForSize:size]);
        else if (size.height > 1.2 * [self _thumbnailSize].height && NO == _isRendering)
            needsRender = (NULL == _fullImageRef);
        else
            needsRender = (NULL == _thumbnailRef && NO == _isRendering);
        pthread_mutex_unlock(&_mutex);
    }
    return needsRender;
}

- (CGImageRef)_createResampledImageOfSize:(NSSize)size fromCGImage:(CGImageRef)largeImage;
{
    CGFloat width = size.width;
    CGFloat height = size.height;
        
    // these will always be the same size, so use the context cache
    CGContextRef ctxt = [FVBitmapContextCache newBitmapContextOfWidth:width height:height];
    CGContextSaveGState(ctxt);
    CGContextSetInterpolationQuality(ctxt, kCGInterpolationHigh);
    CGContextDrawImage(ctxt, CGRectMake(0, 0, CGBitmapContextGetWidth(ctxt), CGBitmapContextGetHeight(ctxt)), largeImage);
    CGContextRestoreGState(ctxt);
    
    CGImageRef smallImage = CGBitmapContextCreateImage(ctxt);
    [FVBitmapContextCache disposeOfBitmapContext:ctxt];
    
    return smallImage;
}

- (void)_postIconFinishedNotification
{
    // All of the other FVIcon subclasses render synchronously in the FVIconQueue, which then calls back to the view when each batch is finished.  FVWebViewIcon loads asynchronously via WebKit, which runs its own threading; this worked better than the original attempt at a synchronous load, which blocked for too long.  The problem is that if we return YES from needsRenderForSize: while the webview is trying to load, the view keeps sending the web icons to the queue for rendering, and ultimately ends up drawing the placeholders at a fairly high rate until needsRenderForSize: finally returns NO.  This private notification is about the cleanest thing I can think of.
    [[NSNotificationCenter defaultCenter] postNotificationName:FVWebIconUpdatedNotificationName object:self];
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame;
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    NSParameterAssert([sender isEqual:_webView]);
    
    [self _releaseWebView];
    
    pthread_mutex_lock(&_mutex);
    _webviewFailed = YES;
    _isRendering = NO;
    [self _postIconFinishedNotification];
    pthread_mutex_unlock(&_mutex);
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame;
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    NSParameterAssert([sender isEqual:_webView]);

    [self _releaseWebView];

    pthread_mutex_lock(&_mutex);
    _webviewFailed = YES;
     _isRendering = NO;
    [self _postIconFinishedNotification];
    pthread_mutex_unlock(&_mutex);
}

- (void)_mainFrameDidFinishLoading
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));

    // the delegate methods will tell us if the load failed; I see no other way to ask for status    
    pthread_mutex_lock(&_mutex);
    BOOL didFail = _webviewFailed;
    pthread_mutex_unlock(&_mutex);
    
    if (NO == didFail) {
        
        // display the main frame's view directly to avoid showing the scrollers
        
        WebFrameView *view = [[_webView mainFrame] frameView];
        [view setAllowsScrolling:NO];
        
        NSSize size = [self _webviewSize];
        CGContextRef context = [FVBitmapContextCache newBitmapContextOfWidth:size.width height:size.height];
        NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:[view isFlipped]];
        
        [NSGraphicsContext saveGraphicsState]; // save previous context
        
        [NSGraphicsContext setCurrentContext:nsContext];
        [nsContext saveGraphicsState];
        [[NSColor whiteColor] setFill];
        NSRect rect = NSMakeRect(0, 0, size.width, size.height);
        [[NSBezierPath fv_bezierPathWithRoundRect:rect xRadius:5 yRadius:5] fill];
        [nsContext restoreGraphicsState];

        [_webView setFrame:NSInsetRect(rect, 10, 10)];
        
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, 10, 10);
        [view displayRectIgnoringOpacity:[view bounds] inContext:nsContext];
        CGContextRestoreGState(context);
        
        [NSGraphicsContext restoreGraphicsState]; // restore previous context
        
        // temporary CGImage from the full webview
        CGImageRef largeImage = CGBitmapContextCreateImage(context);
                
        pthread_mutex_lock(&_mutex);
        
        // full image is large, so cache it to disk in case we get a -releaseResources or another view needs it
        CGImageRelease(_fullImageRef);
        _fullImageRef = [self _createResampledImageOfSize:[self size] fromCGImage:largeImage];
        [FVIconCache cacheCGImage:_fullImageRef withName:_diskCacheName];
        
        // resample to a thumbnail size that will draw quickly
        CGImageRelease(_thumbnailRef);
        _thumbnailRef = [self _createResampledImageOfSize:[self _thumbnailSize] fromCGImage:largeImage];
        
        pthread_mutex_unlock(&_mutex);
        
        CGImageRelease(largeImage);
        [FVBitmapContextCache disposeOfBitmapContext:context];        
    }
    
    // clear out the webview, since we won't need it again
    [self _releaseWebView];

    // sets _isRendering before notifying observers we're done
    pthread_mutex_lock(&_mutex);
    _isRendering = NO;
    pthread_mutex_unlock(&_mutex);
    
    // post this regardless of failure, but webView:didFinishLoadForFrame: doesn't seem to be called in a failure case
    [self _postIconFinishedNotification];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    NSParameterAssert([sender isEqual:_webView]);
    // wait for the main frame
    if ([frame isEqual:[_webView mainFrame]])
        [self _mainFrameDidFinishLoading];
}

- (void)webView:(WebView *)sender decidePolicyForMIMEType:(NSString *)type request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    NSParameterAssert([sender isEqual:_webView]);
    
    // !!! Better to just load text/html and ignore everything else?  The point of implementing this method is to ignore PDF.  It doesn't show up in the thumbnail and it's slow to load, so there's no point in loading it.
    
    // Documentation says the default implementation checks "If request is not a directory", which is...odd.
    // See http://trac.webkit.org/projects/webkit/browser/trunk/WebKit/mac/DefaultDelegates/WebDefaultPolicyDelegate.m
    
    CFStringRef theUTI = type == nil ? NULL : UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (CFStringRef)type, NULL);
    
    // This class should never get a file URL, but we'll implement it in the standard way for consistency.
    if ([[request URL] isFileURL]) {
        BOOL isDirectory = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:[[request URL] path] isDirectory:&isDirectory];
        if (isDirectory) {
            [listener ignore];
        } else if ([[sender class] canShowMIMEType:type]) {
            [listener use];
        } else {
            [listener ignore];
        }
    }
    else if (theUTI != NULL && (UTTypeConformsTo(theUTI, kUTTypeCompositeContent) || UTTypeConformsTo(theUTI, kUTTypeArchive) || UTTypeConformsTo(theUTI, CFSTR("public.audiovisual-content")) || UTTypeConformsTo(theUTI, CFSTR("com.adobe.postscript")))) {
        // this triggers webView:didFailProvisionalLoadWithError:forFrame:
        [listener ignore];        
    }
    else if ([[sender class] canShowMIMEType:type]) {
        [listener use];
    }
    else {
        [listener ignore];
    }
    
    if (theUTI) CFRelease(theUTI);
}

- (void)renderOffscreenOnMainThread 
{ 
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));    
    // NSAssert(nil == _webView, @"*** Render error *** renderOffscreenOnMainThread called when _webView already exists");
    
    if (nil == _webView)
        _webView = [[self class] popWebView];

    if (nil == _webView) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleWebViewAvailableNotification:) name:FVWebIconWebViewAvailableNotificationName object:[self class]];
    }
    else {
        // always use the WebKit cache, and use a short timeout (default is 60 seconds)
        NSURLRequest *request = [NSURLRequest requestWithURL:_httpURL cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:10.0];
        
        // See also http://lists.apple.com/archives/quicklook-dev/2007/Nov/msg00047.html
        // Note: changed from blocking to non-blocking; we now just keep state and rely on the
        // delegate methods.
        
        Class cls = [self class];
        NSString *prefIdentifier = [NSString stringWithFormat:@"%@.%@", [[NSBundle bundleForClass:cls] bundleIdentifier], cls];
        [_webView setPreferencesIdentifier:prefIdentifier];
        
        WebPreferences *prefs = [_webView preferences];
        [prefs setPlugInsEnabled:NO];
        [prefs setJavaEnabled:NO];
        [prefs setJavaScriptCanOpenWindowsAutomatically:NO];
        [prefs setJavaScriptEnabled:NO];
        [prefs setAllowsAnimatedImages:NO];
        
        // most memory-efficient setting; remote resources are still cached to disk
        if ([prefs respondsToSelector:@selector(setCacheModel:)])
            [prefs setCacheModel:WebCacheModelDocumentViewer];
        
        [_webView setFrameLoadDelegate:self];
        [_webView setPolicyDelegate:self];
        [[_webView mainFrame] loadRequest:request];        
    }
}

- (void)_handleWebViewAvailableNotification:(NSNotification *)aNotification
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    [[NSNotificationCenter defaultCenter] removeObserver:self name:FVWebIconWebViewAvailableNotificationName object:[self class]];
    [self renderOffscreenOnMainThread];
}

- (NSString *)debugDescription
{
    NSAssert1(pthread_mutex_trylock(&_mutex) == EBUSY, @"*** threading violation *** failed to lock before %@", NSStringFromSelector(_cmd));
    return [NSString stringWithFormat:@"%@: { \n\tURL = %@\n\tFailed = %d\n\tRendering = %d\n\tWebView = %@\n\tFull image = %@\n\tThumbnail = %@\n }", [self description], _httpURL, _webviewFailed, _isRendering, _webView, _fullImageRef, _thumbnailRef];
}
    

- (void)renderOffscreen
{
    pthread_mutex_lock(&_mutex);
    
    // check the disk cache first
    // note that _fullImageRef may be non-NULL if we were added to the FVIconQueue multiple times before renderOffscreen was called
    if (NULL == _fullImageRef)
        _fullImageRef = [FVIconCache newImageNamed:_diskCacheName];

    if (_fullImageRef) {

        // image may have been added to the disk cache by another instance; in that case, we need to create a new thumbnail
        if (NULL == _thumbnailRef)
            _thumbnailRef = [self _createResampledImageOfSize:[self _thumbnailSize] fromCGImage:_fullImageRef];
    }
    else if (NO == _webviewFailed && NO == _isRendering) {
        // make sure needsRenderForSize: knows that we're actively rendering, so renderOffscreen doesn't get called again
        _isRendering = YES;
        [self performSelectorOnMainThread:@selector(renderOffscreenOnMainThread) withObject:nil waitUntilDone:NO];
    }
    else if (YES == _webviewFailed && nil == _fallbackIcon) {
        _fallbackIcon = [[FVFinderIcon allocWithZone:[self zone]] initWithFinderIconOfURL:_httpURL];
    }
    [_fallbackIcon renderOffscreen];
    pthread_mutex_unlock(&_mutex);
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
        // if we have _fullImageRef, we're guaranteed to have _thumbnailRef
        if (_fullImageRef && CGRectGetHeight(drawRect) > 1.2 * [self _thumbnailSize].height)
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

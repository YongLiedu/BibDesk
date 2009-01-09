//
//  FVWebViewIcon.m
//  FileView
//
//  Created by Adam Maxwell on 12/30/07.
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

#import "FVWebViewIcon.h"
#import "FVTextIcon.h"
#import "FVFinderIcon.h"
#import "FVMIMEIcon.h"
#import <WebKit/WebKit.h>

@implementation FVWebViewIcon

static BOOL FVWebIconDisabled = NO;

// webview pool variables to keep memory usage down; pool size is tunable
static NSInteger _maxWebViews = 5;
static NSMutableArray *_availableWebViews = nil;
static NSArray *_commonModes = nil;
static NSInteger _numberOfWebViews = 0;
static NSString * const FVWebIconWebViewAvailableNotificationName = @"FVWebIconWebViewAvailableNotificationName";
static NSSet *_webViewSchemes = nil;

// size of the view frame; large enough to fit a reasonably sized page
static const NSSize _webViewSize = (NSSize){ 1000, 900 };

// framework private; notifies the file view that a webkit-async load has finished
NSString * const FVWebIconUpdatedNotificationName = @"FVWebIconUpdatedNotificationName";

+ (void)initialize
{
    FVINITIALIZE(FVWebViewIcon);
    
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    
    //if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4)
    //    [sud registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"FVWebIconDisabled", nil]];
    
    FVWebIconDisabled = [sud boolForKey:@"FVWebIconDisabled"];
    NSInteger maxViews = [sud integerForKey:@"FVWebIconMaximumNumberOfWebViews"];
    if (maxViews > 0)
        _maxWebViews = maxViews;
    
    _availableWebViews = [[NSMutableArray alloc] initWithCapacity:_maxWebViews];
    _commonModes = [[NSArray alloc] initWithObjects:(id)kCFRunLoopCommonModes, nil];
    _webViewSchemes = [[NSSet alloc] initWithObjects:@"http", @"https", @"ftp", nil];
}

// return nil if _maxWebViews is exceeded
+ (WebView *)popWebView 
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    WebView *nextView = nil;
    if ([_availableWebViews count]) {
        nextView = [[_availableWebViews lastObject] retain];
        [_availableWebViews removeLastObject];
    }
    else if (_numberOfWebViews <= _maxWebViews) {
        nextView = [[WebView alloc] initWithFrame:NSMakeRect(0, 0, _webViewSize.width, _webViewSize.height)];
        _numberOfWebViews++;
    }
    return [nextView autorelease];
}

+ (void)pushWebView:(WebView *)aView
{
    NSParameterAssert(nil != aView);
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    [_availableWebViews insertObject:aView atIndex:0];
    [[NSNotificationCenter defaultCenter] postNotificationName:FVWebIconWebViewAvailableNotificationName object:self];
}

- (id)initWithURL:(NSURL *)aURL;
{    
    NSParameterAssert(nil != [aURL scheme]);
    
    // if this is not an http or file URL, return a finder icon instead
    if (FVWebIconDisabled || (NO == [_webViewSchemes containsObject:[aURL scheme]] && NO == [aURL isFileURL])) {
        NSZone *zone = [self zone];
        [self release];
        if ([aURL isFileURL]) 	 
            self = [[FVTextIcon allocWithZone:zone] initWithHTMLAtURL:aURL]; 	 
        else
            self = [[FVFinderIcon allocWithZone:zone] initWithFinderIconOfURL:aURL];
    }
    else if ((self = [super init])) {
        _httpURL = [aURL copy];
        _fullImage = NULL;
        _thumbnail = NULL;
        _fallbackIcon = nil;
        
        // we can predict these sizes ahead of time since we have a fixed aspect ratio
        _thumbnailSize = _webViewSize;
        FVIconLimitThumbnailSize(&_thumbnailSize);
        _fullImageSize = _webViewSize;
        FVIconLimitFullImageSize(&_fullImageSize);
        _desiredSize = NSZeroSize;
        
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
        [_webView release];
        _webView = nil;
    }
}

- (void)dealloc
{
    // it's very unlikely that we'll see this on a non-main thread, but just in case...
    [self performSelectorOnMainThread:@selector(_releaseWebView) withObject:nil waitUntilDone:YES modes:_commonModes];
    
    pthread_mutex_destroy(&_mutex);
        CGImageRelease(_fullImage);
        CGImageRelease(_thumbnail);
    [_httpURL release];
    [_fallbackIcon release];
    NSZoneFree([self zone], _diskCacheName);
    [super dealloc];
}

- (BOOL)canReleaseResources;
{
    return (nil != _webView || NULL != _fullImage || NULL != _thumbnail || [_fallbackIcon canReleaseResources]);
}

- (void)releaseResources
{     
    // Cancel any pending loads; set _isRendering to NO or -renderOffscreenOnMainThread will never complete if it gets called again
    [self performSelectorOnMainThread:@selector(_releaseWebView) withObject:nil waitUntilDone:YES modes:_commonModes];

    [self lock];
    _isRendering = NO;
    
        CGImageRelease(_fullImage);
    _fullImage = NULL;
        CGImageRelease(_thumbnail);
    _thumbnail = NULL;
    
    // currently a noop
    [_fallbackIcon releaseResources];
    [self unlock];    
}

- (BOOL)tryLock { return pthread_mutex_trylock(&_mutex) == 0; }
- (void)lock { pthread_mutex_lock(&_mutex); }
- (void)unlock { pthread_mutex_unlock(&_mutex); }

// size of the _fullImage
- (NSSize)size { return _fullImageSize; }

// actual size of the webview
- (NSSize)_webviewSize { return _webViewSize; }

// size of the _thumbnail (1/5 of webview size)
- (NSSize)_thumbnailSize { return _thumbnailSize; }

- (BOOL)needsRenderForSize:(NSSize)size
{
    BOOL needsRender = NO;
    if ([self tryLock]) {
        
        /*
         1) if we know the web view failed, the only thing we can use is the fallback icon
         2) if we're drawing a large icon and the web view hasn't failed (yet), we depend on _fullImage (which may be in disk cache)
         3) if we're drawing a small icon and the web view hasn't failed (yet), we depend on _thumbnail (so webview needs to load)
         */
        _desiredSize = size;
        
        if (YES == _webviewFailed)
            needsRender = (nil == _fallbackIcon || [_fallbackIcon needsRenderForSize:size]);
        else if (FVShouldDrawFullImageWithThumbnailSize(size, [self _thumbnailSize]) && NO == _isRendering)
            needsRender = (NULL == _fullImage);
        else
            needsRender = (NULL == _thumbnail && NO == _isRendering);
        [self unlock];
    }
    return needsRender;
}

- (void)_postIconFinishedNotification
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    // All of the other FVIcon subclasses render synchronously in the FVOperationQueue, which then calls back to the view when each batch is finished.  FVWebViewIcon loads asynchronously via WebKit, which runs its own threading; this worked better than the original attempt at a synchronous load, which blocked for too long.  The problem is that if we return YES from needsRenderForSize: while the webview is trying to load, the view keeps sending the web icons to the queue for rendering, and ultimately ends up drawing the placeholders at a fairly high rate until needsRenderForSize: finally returns NO.  This private notification is about the cleanest thing I can think of.
    [[NSNotificationCenter defaultCenter] postNotificationName:FVWebIconUpdatedNotificationName object:self];
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame;
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    NSParameterAssert([sender isEqual:_webView]);
    
    [self _releaseWebView];
    [self lock];
    _webviewFailed = YES;
    _isRendering = NO;
    [self unlock];
    [self _postIconFinishedNotification];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame;
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));
    NSParameterAssert([sender isEqual:_webView]);

    [self _releaseWebView];
    [self lock];
    _webviewFailed = YES;
     _isRendering = NO;
    [self unlock];
    [self _postIconFinishedNotification];
}

- (void)_mainFrameDidFinishLoading
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** -[%@ %@] requires main thread", [self class], NSStringFromSelector(_cmd));

    // the delegate methods will tell us if the load failed; I see no other way to ask for status    
    [self lock];
    BOOL didFail = _webviewFailed;
    [self unlock];
    
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
                 
        [self lock];
        // full image is large, so cache it to disk in case we get a -releaseResources or another view needs it
        CGImageRelease(_fullImage);
        _fullImage = FVCreateResampledFullImage(largeImage, true);
        [FVIconCache cacheImage:_fullImage withName:_diskCacheName];
        
        // resample to a thumbnail size that will draw quickly
        CGImageRelease(_thumbnail);
        _thumbnail = FVCreateResampledThumbnail(largeImage, true);
        [FVIconCache cacheThumbnail:_thumbnail withName:_diskCacheName];
        
        [self unlock];

        CGImageRelease(largeImage);
        [FVBitmapContextCache disposeOfBitmapContext:context];        
    }
    
    // clear out the webview, since we won't need it again
    [self _releaseWebView];

    [self lock];
    // sets _isRendering before notifying observers we're done
    _isRendering = NO;
    [self unlock];
    
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
    
    // !!! Better to just load text/html and ignore everything else?  The point of implementing this method is to ignore PDF.  It doesn't show up in the thumbnail and it's slow to load, so there's no point in loading it.  Plugins are disabled, so stuff like Flash should be ignored anyway, and WebKit doesn't try to display PostScript AFAIK.
    
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
    else if (NULL != theUTI && FALSE == UTTypeConformsTo(theUTI, kUTTypeText)) {
        [self lock];
        [_fallbackIcon release];
        _fallbackIcon = [[FVMIMEIcon allocWithZone:[self zone]] initWithMIMEType:type];
        [self unlock];
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
    // !!! I'm seeing occasional assertion failures here with the new operation queue setup; it's likely to be a race with releaseResources:.
    // NSAssert(nil == _webView, @"*** Render error *** renderOffscreenOnMainThread called when _webView already exists");
    
    if (nil == _webView)
        _webView = [[[self class] popWebView] retain];

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
    return [NSString stringWithFormat:@"%@: { \n\tURL = %@\n\tFailed = %d\n\tRendering = %d\n\tWebView = %@\n\tFull image = %@\n\tThumbnail = %@\n }", [self description], _httpURL, _webviewFailed, _isRendering, _webView, _fullImage, _thumbnail];
}
    

- (void)renderOffscreen
{
    [self lock];
    
    if ([NSThread instancesRespondToSelector:@selector(setName:)] && pthread_main_np() == 0)
        [[NSThread currentThread] setName:[_httpURL absoluteString]];

    // check the disk cache first
    
    // note that _fullImage may be non-NULL if we were added to the FVOperationQueue multiple times before renderOffscreen was called
    if (NULL == _fullImage && FVShouldDrawFullImageWithThumbnailSize(_desiredSize, [self _thumbnailSize]))
        _fullImage = [FVIconCache newImageNamed:_diskCacheName];
    
    // always load for the fast drawing path
    if (NULL == _thumbnail)
        _thumbnail = [FVIconCache newThumbnailNamed:_diskCacheName];

    // unlock before calling performSelectorOnMainThread:... since it could cause a callout that tries to acquire the lock (one of the delegate methods)
    
    if (NULL == _thumbnail && NULL == _fullImage && NO == _webviewFailed && NO == _isRendering) {
        // make sure needsRenderForSize: knows that we're actively rendering, so renderOffscreen doesn't get called again
        _isRendering = YES;
        [self unlock];
        [self performSelectorOnMainThread:@selector(renderOffscreenOnMainThread) withObject:nil waitUntilDone:YES modes:_commonModes];
    }
    else if (YES == _webviewFailed && nil == _fallbackIcon) {
        _fallbackIcon = [[FVFinderIcon allocWithZone:[self zone]] initWithFinderIconOfURL:_httpURL];
        [self unlock];
    }
    else {
        // no condition on this branch; we always unlock
        [_fallbackIcon renderOffscreen];
        [self unlock];
    }
}

- (void)fastDrawInRect:(NSRect)dstRect ofContext:(CGContextRef)context;
{
    if ([self tryLock]) {
        if (_thumbnail) {
            CGContextDrawImage(context, [self _drawingRectWithRect:dstRect], _thumbnail);
            [self unlock];
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

- (void)drawInRect:(NSRect)dstRect ofContext:(CGContextRef)context 
{ 
    if ([self tryLock]) {
        
        CGRect drawRect = [self _drawingRectWithRect:dstRect];
        
        BOOL shouldDrawFullImage = FVShouldDrawFullImageWithThumbnailSize(dstRect.size, [self _thumbnailSize]);
        // if we have _fullImage, we're guaranteed to have _thumbnail
        if (_fullImage && shouldDrawFullImage)
            CGContextDrawImage(context, drawRect, _fullImage);
        else if (_thumbnail)
            CGContextDrawImage(context, drawRect, _thumbnail);
        else if (NO == _webviewFailed || nil == _fallbackIcon)
            [self _drawPlaceholderInRect:dstRect ofContext:context];
        else
            [_fallbackIcon drawInRect:dstRect ofContext:context];
        
        [self unlock];
    }
    else {
        [self _drawPlaceholderInRect:dstRect ofContext:context];
    }
}

@end

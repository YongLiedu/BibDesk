//
//  FVWebViewIcon.m
//  FileView
//
//  Created by Adam Maxwell on 12/30/07.
/*
 This software is Copyright (c) 2007-2016
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
#import "FVMIMEIcon.h"
#import <WebKit/WebKit.h>

@interface WebView (FVExtensions)
- (BOOL)fv_isLoading;
@end

@implementation WebView (FVExtensions)

- (BOOL)fv_isLoading;
{
    // available in 10.4.11 and later
    if ([self respondsToSelector:@selector(isLoading)])
        return [self isLoading];
    
    // Modified from http://trac.webkit.org/browser/trunk/WebKit/mac/WebView/WebView.mm implementation of -[WebView _isLoading].
    WebFrame *mainFrame = [self mainFrame];
    return [[mainFrame dataSource] isLoading] || [[mainFrame provisionalDataSource] isLoading];
}

@end

#ifdef MAC_OS_X_VERSION_10_11
@interface FVWebViewIcon () <WebFrameLoadDelegate, WebPolicyDelegate, WebResourceLoadDelegate>
@end
#endif

@implementation FVWebViewIcon

// limit number of loading views to keep memory usage down; size is tunable
static int8_t _maxWebViews = 0;
static int8_t _numberOfWebViews = 0;
static NSMutableArray *_waitingList = nil;

#define IDLE    0
#define LOADING 1
#define LOADED  2

+ (void)initialize
{
    FVINITIALIZE(FVWebViewIcon);

    NSNumber *maxViews = [[NSUserDefaults standardUserDefaults] objectForKey:@"FVWebIconMaximumNumberOfWebViews"];
    
    // default value of 5, with valid range (0, 50)
    if (nil == maxViews) {
        _maxWebViews = 5;
    }
    else if ([maxViews integerValue] > 50) {
        FVLog(@"Limiting number of webviews to 50 (FVWebIconMaximumNumberOfWebViews = %@)", maxViews);
        _maxWebViews = 50;
    }
    else if ([maxViews integerValue] >= 0) {
        _maxWebViews = [maxViews integerValue];
    }
    else {
        // negative values
        _maxWebViews = 0;
    }
    
    _waitingList = (NSMutableArray *)CFArrayCreateMutable(NULL, 0, NULL);
}

// size of the view frame; large enough to fit a reasonably sized page
+ (NSSize)_webViewSize { return NSMakeSize(1000, 900); }

+ (BOOL)_isSupportedScheme:(NSString *)scheme
{
    NSString *lcString = [scheme lowercaseString];
    return [lcString isEqualToString:@"http"] || [lcString isEqualToString:@"https"] || [lcString isEqualToString:@"ftp"];
}

- (id)initWithURL:(NSURL *)aURL;
{    
    NSParameterAssert(nil != [aURL scheme]);
    
    // if webviews are disabled, return a finder icon to avoid problems with looping notifications
    // if this is not an http or file URL, return a finder icon instead
    if (0 == _maxWebViews || (NO == [[self class] _isSupportedScheme:[aURL scheme]] && NO == [aURL isFileURL])) {
        NSZone *zone = [self zone];
        [self release];
        self = (id)[[FVFinderIcon allocWithZone:zone] initWithURL:aURL];
    }
    else if ((self = [super init])) {
        _httpURL = [aURL copyWithZone:[self zone]];
        _fullImage = NULL;
        _thumbnail = NULL;
        _viewImage = NULL;
        _fallbackIcon = nil;
        _webView = nil;
        _redirectedFrames = [NSCountedSet new];

        // we can predict these sizes ahead of time since we have a fixed aspect ratio
        _thumbnailSize = [[self class] _webViewSize];
        FVIconLimitThumbnailSize(&_thumbnailSize);
        _fullImageSize = _thumbnailSize;
        FVIconLimitFullImageSize(&_fullImageSize);
        _desiredSize = NSZeroSize;
                
        _cacheKey = [FVCGImageCache newKeyForURL:_httpURL];
        _condLock = [[NSConditionLock allocWithZone:[self zone]] initWithCondition:IDLE];
        _cancelledLoad = false;
    }
    return self;
}

- (void)_startWebView
{
    FVAPIAssert1(pthread_main_np() != 0, @"*** threading violation *** %s requires main thread", __func__);
    // !!! Was seeing occasional assertion failures here with the new operation queue setup; it's likely to be a race with releaseResources:.  Should be eliminated with the new condition lock scheme.
    NSAssert(nil == _webView, @"*** Render error *** _startWebView called when _webView already exists");
    FVAPIParameterAssert(_maxWebViews > 0);
    
    if (nil == _webView && _numberOfWebViews < _maxWebViews) {
        NSSize size = [[self class] _webViewSize];
        _webView = [[WebView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
        _numberOfWebViews++;
        
        
        NSString *prefIdentifier = [NSString stringWithFormat:@"%@.%@", [[NSBundle bundleForClass:[self class]] bundleIdentifier], [self class]];
        [_webView setPreferencesIdentifier:prefIdentifier];
        
        WebPreferences *prefs = [_webView preferences];
        [prefs setPlugInsEnabled:NO];
        [prefs setJavaEnabled:NO];
        [prefs setJavaScriptCanOpenWindowsAutomatically:NO];
        [prefs setJavaScriptEnabled:NO];
        [prefs setAllowsAnimatedImages:NO];
        [prefs setPrivateBrowsingEnabled:YES];
        
        /*
         WebCacheModelDocumentViewer is the most memory-efficient setting; remote resources are still cached to disk,
         supposedly, but in practice this doesn't seem to happen (or else they're pruned too early).  Using
         WebCacheModelDocumentBrowser gives much better performance, and memory usage is the same or less, particularly
         if you have multiple pages loading the same resources (e.g., many ScienceDirect thumbnails).
         */
        if ([prefs respondsToSelector:@selector(setCacheModel:)])
            [prefs setCacheModel:WebCacheModelDocumentBrowser];
    }
    
    if (nil != _webView) {
        // See also http://lists.apple.com/archives/quicklook-dev/2007/Nov/msg00047.html
        // Note: changed from blocking to non-blocking; we now just keep state and rely on the delegate methods.
        
        [_webView setFrameLoadDelegate:self];
        [_webView setPolicyDelegate:self];
        [_webView setResourceLoadDelegate:self];
        
        NSURLRequest *request = [NSURLRequest requestWithURL:_httpURL cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:60.0];
        [[_webView mainFrame] loadRequest:request];
    }
    else if ([_waitingList containsObject:self] == NO) {
        [_waitingList addObject:self];
    }
}

- (void)_releaseWebView
{
    FVAPIAssert1(pthread_main_np() != 0, @"*** threading violation *** %s requires main thread", __func__);

    // in case we get -releaseResources or -dealloc while waiting for another webview
    [_waitingList removeObject:self];
    if (nil != _webView) {
        [_webView setPolicyDelegate:nil];
        [_webView setFrameLoadDelegate:nil];
        [_webView setResourceLoadDelegate:nil];
        [_webView stopLoading:nil];
        FVAPIAssert([_webView downloadDelegate] == nil, @"downloadDelegate non-nil");
        FVAPIAssert([_webView UIDelegate] == nil, @"UIDelegate non-nil");
        // autorelease instead of release to workaround rdar://problem/9923439 (WebKit: crash when loading cancelled due to policy delegate callout)
        [_webView autorelease];
        // may have frames if the load was cancelled?
        [_redirectedFrames removeAllObjects];
        _numberOfWebViews--;
        _webView = nil;
        // notify waiting icons that _numberOfWebViews has been decremented
        if ([_waitingList count] > 0) {
            // work on a copy, as _startWebView can modify the waiting list
            NSArray *icons = [_waitingList copy];
            [_waitingList removeAllObjects];
            [icons makeObjectsPerformSelector:@selector(_startWebView)];
            [icons release];
        }
    }
}

- (void)dealloc
{
    // typically on the main thread here, but not guaranteed; can never be called during a load anyway
    if (pthread_main_np() == 0) {
        [self performSelectorOnMainThread:@selector(_releaseWebView) withObject:nil waitUntilDone:YES modes:[NSArray arrayWithObject:(id)kCFRunLoopCommonModes]];
    }
    else {
        // make sure to deregister for notification
        [self _releaseWebView];
    }
    [_redirectedFrames release];
    [_condLock release];
    CGImageRelease(_viewImage);
    CGImageRelease(_fullImage);
    CGImageRelease(_thumbnail);
    [_httpURL release];
    [_fallbackIcon release];
    [_cacheKey release];
    [super dealloc];
}

- (BOOL)canReleaseResources;
{
    return ([_condLock condition] == LOADING || NULL != _fullImage || NULL != _thumbnail || [_fallbackIcon canReleaseResources]);
}

- (void)releaseResources
{     
    // allow current waiters on LOADING to exit
    if ([_condLock tryLockWhenCondition:LOADING]) {
                
        /*
         Cancel any pending loads (only occur inside LOADING condition)
         
         If webview is non-nil, we need to cancel the load.
         If webview is nil, we need to unregister for the notification.         
         */
        [self performSelectorOnMainThread:@selector(_releaseWebView) withObject:nil waitUntilDone:YES modes:[NSArray arrayWithObject:(id)kCFRunLoopCommonModes]];
        
        // should never happen, but make sure we can't cache garbage...
        if (_viewImage) {
            FVLog(@"%s found a non-NULL _viewImage, and is disposing of it", __func__);
            CFRelease(_viewImage);
            _viewImage = NULL;
        }        
        // need to avoid creating the fallback icon in this case, so we know to retry later
        _cancelledLoad = true;
        [_condLock unlockWithCondition:LOADED];
    }
    // could possibly fail to take the lock during a callout to _pageDidFinishLoading, and in that case we should just wait

    // block until IDLE is set, so current waiters don't get hosed by resetting the condition to IDLE
    [_condLock lockWhenCondition:IDLE];
    
    CGImageRelease(_fullImage);
    _fullImage = NULL;
    CGImageRelease(_thumbnail);
    _thumbnail = NULL;
    
    // currently a noop
    [_fallbackIcon releaseResources];
        
    // reset condition so -renderOffscreen will complete if it's called again
    [_condLock unlockWithCondition:IDLE];    
}

- (void)recache;
{
    [FVCGImageCache invalidateCachesForKey:_cacheKey];
    [self releaseResources];
    
    // this is a sentinel value for needsRenderForSize:
    [self lock];    
    _cancelledLoad = false;
    [_fallbackIcon release];
    _fallbackIcon = nil;
    [self unlock];
}

- (BOOL)tryLock { return [_condLock tryLock]; }
- (void)lock { [_condLock lock]; }
- (void)unlock { [_condLock unlock]; }

// size of the _fullImage
- (NSSize)size { return _fullImageSize; }

// size of the _thumbnail (1/5 of webview size)
- (NSSize)_thumbnailSize { return _thumbnailSize; }

- (BOOL)needsRenderForSize:(NSSize)size
{
    BOOL needsRender = NO;
    if ([_condLock tryLockWhenCondition:IDLE]) {
        
        /*
         1) if we know the web view failed, the only thing we can use is the fallback icon
         2) if we're drawing a large icon and the web view hasn't failed (yet), we depend on _fullImage (which may be in disk cache)
         3) if we're drawing a small icon and the web view hasn't failed (yet), we depend on _thumbnail (so webview needs to load)
         */
        _desiredSize = size;
        
        if (nil != _fallbackIcon)
            needsRender = [_fallbackIcon needsRenderForSize:size];
        else if (FVShouldDrawFullImageWithThumbnailSize(size, [self _thumbnailSize]))
            needsRender = (NULL == _fullImage);
        else
            needsRender = (NULL == _thumbnail);
        [self unlock];
    }
    return needsRender;
}

- (void)_handleWebView:(WebView *)sender loadError:(NSError *)error forFrame:(WebFrame *)frame;
{
    FVAPIAssert1(pthread_main_np() != 0, @"*** threading violation *** %s requires main thread", __func__);
    FVAPIParameterAssert([sender isEqual:_webView]);
    
    /*
     If a frame fails to load and the webview isn't loading anything else, bail out.
     ??? Not sure anymore why I chose that condition; maybe in case of partial failures?
     
     In addition, if a fallback icon has been created in decidePolicyForMIMEType:,
     we want to cancel loading here as a signal to draw that.  Otherwise, we may continue
     loading other frames, then draw the webview.
     */
    if (NO == [_webView fv_isLoading] || nil != _fallbackIcon) {
        [self _releaseWebView];
        
        // condition should always be LOADING, but -releaseResources may have the lock
        if ([_condLock tryLockWhenCondition:LOADING]) {
            // return to -renderOffscreen to handle the failure
            [_condLock unlockWithCondition:LOADED];
        }
    }    
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame;
{
    [self _handleWebView:sender loadError:error forFrame:frame];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame;
{
    [self _handleWebView:sender loadError:error forFrame:frame];
}

- (void)_pageDidFinishLoading
{
    FVAPIAssert1(pthread_main_np() != 0, @"*** threading violation *** %s requires main thread", __func__);
    FVAPIAssert1([_webView fv_isLoading] == NO, @"%s called while webview was loading", __func__);

    // release resources called after page finished loading; it calls main thread to cancel webview and we deadlock
    if ([_condLock tryLockWhenCondition:LOADING]) {
        
        // display the main frame's view directly to avoid showing the scrollers
        WebFrameView *view = [[_webView mainFrame] frameView];
        [view setAllowsScrolling:NO];
        
        // actual size of the view
        NSSize size = [[self class] _webViewSize];
        
        FVBitmapContext *bitmapContext = [FVBitmapContext bitmapContextWithSize:size];
        CGContextRef context = [bitmapContext graphicsPort];
        CGContextClearRect(context, CGRectMake(0, 0, size.width, size.height));
        NSGraphicsContext *nsContext = [_webView isFlipped] ? [bitmapContext flippedGraphicsContext] : [bitmapContext graphicsContext];
        
        [NSGraphicsContext saveGraphicsState];
        
        [NSGraphicsContext setCurrentContext:nsContext];
        [nsContext saveGraphicsState];
        [[NSColor whiteColor] setFill];
        NSRect rect = NSMakeRect(0, 0, size.width, size.height);
        [[NSBezierPath fv_bezierPathWithRoundRect:rect xRadius:5 yRadius:5] fill];
        [nsContext restoreGraphicsState];

        [_webView setFrame:NSInsetRect(rect, 10, 10)];
        
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, 10, 10);
        
        /*
         Force document layout.  This was added as a workaround for a bug introduced with Safari 4.0.3 on 10.5.8, 
         where setAllowsScrolling:NO caused a white page to be drawn.  Interestingly, it also fixes some prior
         display problems with sciencedirect.com thumbnails, so it's likely that setAllowsScrolling: has never
         worked correctly.  Note that [[view documentView] setNeedsLayout:] is not sufficient, so I conclude that
         displayRectIgnoringOpacity:inContext: doesn't go through drawRect: (impossible), or the WebDocumentView
         protocol is not correctly implemented.
         */
        [[view documentView] layout];
        [_webView displayRectIgnoringOpacity:[_webView bounds] inContext:nsContext];
        CGContextRestoreGState(context);
        
        [NSGraphicsContext restoreGraphicsState];
        
        // temporary CGImage from the full webview
        CGImageRelease(_viewImage);
        _viewImage = CGBitmapContextCreateImage(context);
            
        // clear out the webview, since we won't need it again
        [self _releaseWebView];
        [_condLock unlockWithCondition:LOADED];
        
        // return to -renderOffscreen for scaling and caching
    }
}

/*
 
 Notes on workarounds for rdar://problem/7025679
 
 Redirect and -isLoading don't work as I expected.  As an example, this page
 
 http://dx.doi.org/10.1175/1520-0426(2003)20%3C730:AACEAF%3E2.0.CO;2
 
 does a server side redirect to
 
 http://journals.allenpress.com/jrnlserv/?request=get-abstract&doi=10.1175/1520-0426(2003)20%3C730:AACEAF%3E2.0.CO;2
 
 which then does a client side redirect to
 
 http://ams.allenpress.com/perlserv/?request=get-abstract&doi=10.1175%2F1520-0426(2003)20%3C730:AACEAF%3E2.0.CO%3B2
 
 -[WebView isLoading] returns NO after the journals.allenpress.com URL has loaded, but that's before the ams.allenpress.com
 URL has started loading.  Hence, we track client side redirected frames between the redirect and their provisional load,
 and use that in conjunction with -[WebView isLoading].  This is essentially Apple's suggested workaround, and they say
 WebKit works as designed here so 7025679 was marked "Behaves Correctly."
 
 Related: rdar://problem/7046376 (add API or callback for complete loading)
          rdar://problem/7046354 (improve documentation for willPerformClientRedirectToURL:)
 
 */

- (void)webView:(WebView *)sender willPerformClientRedirectToURL:(NSURL *)URL delay:(NSTimeInterval)seconds fireDate:(NSDate *)date forFrame:(WebFrame *)frame
{
    // client redirect is delayed, and -[WebView isLoading] returns NO until the provisional load starts
    [_redirectedFrames addObject:frame];
}

- (void)webView:(WebView *)sender didCancelClientRedirectForFrame:(WebFrame *)frame;
{
    [_redirectedFrames removeObject:frame];
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame;
{
    // once a provisional load has started, -[WebView isLoading] will return correct status
    [_redirectedFrames removeObject:frame];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    FVAPIAssert1(pthread_main_np() != 0, @"*** threading violation *** %s requires main thread", __func__);
    FVAPIParameterAssert([sender isEqual:_webView]);

    // wait until all frames are loaded; perform after a delay because of redirect problems
    if (NO == [_webView fv_isLoading] && [_redirectedFrames count] == 0)
        [self _pageDidFinishLoading];
}

- (void)webView:(WebView *)sender decidePolicyForMIMEType:(NSString *)type request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener
{
    FVAPIAssert1(pthread_main_np() != 0, @"*** threading violation *** %s requires main thread", __func__);
    FVAPIParameterAssert([sender isEqual:_webView]);
    
    /*
     !!! Better to just load text/html and ignore everything else?  The point of implementing this method is to ignore PDF.  
     It doesn't show up in the thumbnail and it's slow to load, so there's no point in loading it.  Plugins are disabled, 
     so stuff like Flash should be ignored anyway, and WebKit doesn't try to display PostScript AFAIK.
    
     Documentation says the default implementation checks "If request is not a directory", which is...odd.
     See http://trac.webkit.org/projects/webkit/browser/trunk/WebKit/mac/DefaultDelegates/WebDefaultPolicyDelegate.m
     */
    
    CFStringRef theUTI = type == nil ? NULL : UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (CFStringRef)type, NULL);
    
    // FVWebViewIcon handles .webarchive files, so implement the standard file: URL handler
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
        // condition should always be LOADING, but -releaseResources may have the lock
        if ([_condLock tryLockWhenCondition:LOADING]) {
            [_fallbackIcon release];
            _fallbackIcon = [FVMIMEIcon newIconWithMIMEType:type];
            [self unlock];
        }
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

// should only be relevant for clicking links, but implement it anyway
- (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id < WebPolicyDecisionListener >)listener
{
    FVAPIAssert1(pthread_main_np() != 0, @"*** threading violation *** %s requires main thread", __func__);        
    FVAPIParameterAssert([sender isEqual:_webView]);
    [listener ignore];
}

- (void)webView:(WebView *)sender resource:(id)identifier didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge fromDataSource:(WebDataSource *)dataSource
{
    FVAPIAssert1(pthread_main_np() != 0, @"*** threading violation *** %s requires main thread", __func__);        
    FVAPIParameterAssert([sender isEqual:_webView]);
    /*
     Causes rendering of a 401 (unauthorized) page here.  Callout to stopLoading: 
     or _handleWebView:loadError:forFrame: will cause a crash in the URL loader.
     */
    [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (NSString *)debugDescription
{
    NSAssert1([self tryLock], @"*** threading violation *** failed to lock before %@", NSStringFromSelector(_cmd));
    return [NSString stringWithFormat:@"%@: { \n\tURL = %@\n\tWebView = %@\n\tFull image = %@\n\tThumbnail = %@\n }", [self description], _httpURL, _webView, _fullImage, _thumbnail];
}
    
- (void)renderOffscreen
{
    [[self class] _startRenderingForKey:_cacheKey];

    [_condLock lockWhenCondition:IDLE];
    
    if ([NSThread instancesRespondToSelector:@selector(setName:)] && pthread_main_np() == 0)
        [[NSThread currentThread] setName:[_httpURL absoluteString]];

    // check the disk cache first
    
    // note that _fullImage may be non-NULL if we were added to the FVOperationQueue multiple times before renderOffscreen was called
    if (NULL == _fullImage && FVShouldDrawFullImageWithThumbnailSize(_desiredSize, [self _thumbnailSize]))
        _fullImage = [FVCGImageCache newImageForKey:_cacheKey];
    
    // always load for the fast drawing path
    if (NULL == _thumbnail)
        _thumbnail = [FVCGImageCache newThumbnailForKey:_cacheKey];

    // unlock before calling performSelectorOnMainThread:... since it could cause a callout that tries to acquire the lock (one of the delegate methods)
    
    if (NULL == _thumbnail && NULL == _fullImage) {
        
        // make sure needsRenderForSize: knows that we're actively rendering, so renderOffscreen doesn't get called again
        [_condLock unlockWithCondition:LOADING];
        [self performSelectorOnMainThread:@selector(_startWebView) withObject:nil waitUntilDone:NO modes:[NSArray arrayWithObject:(id)kCFRunLoopCommonModes]];
        [_condLock lockWhenCondition:LOADED];
        
        CGImageRef fullImage = NULL, thumbnail = NULL;
        
        /*
         Possible states:
         1) non-NULL _viewImage: successfull load
         2) NULL view image
            a) cancelled load
            b) failed to load
         */
        
        if (NULL != _viewImage) {
            
            CGImageRelease(_fullImage);
            _fullImage = FVCreateResampledFullImage(_viewImage);
            
            // resample to a thumbnail size that will draw quickly
            CGImageRelease(_thumbnail);
            _thumbnail = FVCreateResampledThumbnail(_viewImage);
            
            // get rid of the original image
            CGImageRelease(_viewImage);
            _viewImage = NULL;
            
            // keep local references for caching, so we can unlock and notify observers for drawing (can't draw if we're holding the lock)
            fullImage = CGImageRetain(_fullImage);
            thumbnail = CGImageRetain(_thumbnail);
        }
        else if (nil == _fallbackIcon && false == _cancelledLoad) {
            _fallbackIcon = [[FVFinderIcon allocWithZone:[self zone]] initWithURL:_httpURL];
        }
        // don't allocate anything for a load that was cancelled (releaseResources called during load)
        
        // unlock before caching images so drawing can take place
        [_condLock unlockWithCondition:IDLE];
        
        if (fullImage) [FVCGImageCache cacheImage:fullImage forKey:_cacheKey];
        if (thumbnail) [FVCGImageCache cacheThumbnail:thumbnail forKey:_cacheKey];
        
        CGImageRelease(fullImage);
        CGImageRelease(thumbnail);
    }
    else {
        [_condLock unlockWithCondition:IDLE];
    }
    
    [[self class] _stopRenderingForKey:_cacheKey];
}

- (void)fastDrawInRect:(NSRect)dstRect ofContext:(CGContextRef)context;
{
    if ([_condLock tryLockWhenCondition:IDLE]) {
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
    if ([_condLock tryLockWhenCondition:IDLE]) {
        
        CGRect drawRect = [self _drawingRectWithRect:dstRect];
        
        BOOL shouldDrawFullImage = FVShouldDrawFullImageWithThumbnailSize(dstRect.size, [self _thumbnailSize]);
        // if we have _fullImage, we're guaranteed to have _thumbnail
        if (_fullImage && shouldDrawFullImage)
            CGContextDrawImage(context, drawRect, _fullImage);
        else if (_thumbnail)
            CGContextDrawImage(context, drawRect, _thumbnail);
        else if (nil == _fallbackIcon)
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

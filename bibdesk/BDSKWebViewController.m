//
//  BDSKWebViewController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/24/10.
/*
 This software is Copyright (c) 2010
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKWebViewController.h"
#import <WebKit/WebKit.h>
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKBookmarkController.h"
#import "BDSKDownloadManager.h"
#import "BDSKStatusBar.h"
#import "NSString_BDSKExtensions.h"


@implementation BDSKWebViewController

- (id)initWithDelegate:(id<BDSKWebViewControllerDelegate>)aDelegate  {
    if (self = [super init]) {
        webView = [[WebView alloc] init];
        [webView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [webView setGroupName:@"BibDeskWebGroup"];
        [webView setFrameLoadDelegate:self];
        [webView setUIDelegate:self];
        [webView setEditingDelegate:self];
        [webView setDownloadDelegate:[BDSKDownloadManager sharedManager]];
        delegate = aDelegate;
    }
    return self;
}

- (id)init {
    return [self initWithDelegate:nil];
}

- (void)dealloc {
    [webView setHostWindow:nil];
    [webView setFrameLoadDelegate:nil];
    [webView setUIDelegate:nil];
    [webView setEditingDelegate:nil];
    [webView setDownloadDelegate:nil];
    delegate = nil;
    BDSKDESTROY(webView);
    BDSKDESTROY(undoManager);
    [super dealloc];
}

- (void)notifyURL:(NSURL *)aURL {
    if ([delegate respondsToSelector:@selector(webViewController:setURL:)])
        [delegate webViewController:self setURL:aURL];
}

- (void)notifyIcon:(NSImage *)icon {
    if ([delegate respondsToSelector:@selector(webViewController:setIcon:)])
        [delegate webViewController:self setIcon:icon];
}

- (void)notifyTitle:(NSString *)title {
    if ([NSString isEmptyString:title]) {
        NSURL *url = [self URL];
        title = [url isFileURL] ? [[url path] lastPathComponent] : [[url absoluteString] stringByReplacingPercentEscapes];
    }
    if ([delegate respondsToSelector:@selector(webViewController:setTitle:)])
        [delegate webViewController:self setTitle:title ?: @""];
}

#pragma mark Accessors

- (WebView *)webView { return webView; }

- (id<BDSKWebViewControllerDelegate>)delegate { return delegate; }

- (void)setDelegate:(id<BDSKWebViewControllerDelegate>)newDelegate { delegate = newDelegate; }

- (NSURL *)URL {
    WebFrame *mainFrame = [webView mainFrame];
    WebDataSource *dataSource = [mainFrame provisionalDataSource] ?: [mainFrame dataSource];
    return [[dataSource request] URL];
}

- (void)setURL:(NSURL *)newURL {
    if (newURL && [[[[[webView mainFrame] dataSource] request] URL] isEqual:newURL] == NO) {
        [self notifyTitle:[NSLocalizedString(@"Loading", @"Placeholder web group label") stringByAppendingEllipsis]];
        [self notifyIcon:nil];
        [self notifyURL:newURL];
        [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:newURL]];
    }
}

#pragma mark Actions

- (void)bookmarkLink:(id)sender {
	NSDictionary *element = (NSDictionary *)[sender representedObject];
	NSString *URLString = [(NSURL *)[element objectForKey:WebElementLinkURLKey] absoluteString];
	NSString *title = [element objectForKey:WebElementLinkLabelKey] ?: [URLString lastPathComponent];
	
    [[BDSKBookmarkController sharedBookmarkController] addBookmarkWithUrlString:URLString proposedName:title modalForWindow:[webView window]];
}

- (void)revealLink:(id)sender {
	NSURL *linkURL = (NSURL *)[[sender representedObject] objectForKey:WebElementLinkURLKey];
    if ([linkURL isFileURL])
        [[NSWorkspace sharedWorkspace] selectFile:[linkURL path] inFileViewerRootedAtPath:nil];
    else
        NSBeep();
}

- (void)openInDefaultBrowser:(id)sender {
    NSDictionary *element = (NSDictionary *)[sender representedObject];
	NSURL *theURL = [element objectForKey:WebElementLinkURLKey];
    if (theURL)
        [[NSWorkspace sharedWorkspace] openLinkedURL:theURL];
}

#pragma mark WebFrameLoadDelegate protocol

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame{
    BOOL isMainFrame = (frame == [sender mainFrame]);
    
    if (isMainFrame) {
        [self notifyIcon:nil];
        [self notifyTitle:[NSLocalizedString(@"Loading", @"Placeholder web group label") stringByAppendingEllipsis]];
        
        if ([[frame provisionalDataSource] unreachableURL] == nil)
            [self notifyURL:[[[[webView mainFrame] provisionalDataSource] request] URL]];
    }
    
    if ([delegate respondsToSelector:@selector(webViewController:didStartLoadForMainFrame:)])
        [delegate webViewController:self didStartLoadForMainFrame:isMainFrame];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame{

    if (frame == [sender mainFrame]) {
        [self notifyIcon:[sender mainFrameIcon]];
        [self notifyTitle:[sender mainFrameTitle]];
    }
    if ([delegate respondsToSelector:@selector(webViewController:didFinishLoadForFrame:)])
        [delegate webViewController:self didFinishLoadForFrame:frame];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame{
    if ([delegate respondsToSelector:@selector(webViewControllerDidFailLoad:)])
        [delegate webViewControllerDidFailLoad:self];
    
    // !!! logs are here to help diagnose problems that users are reporting
    NSLog(@"-[%@ %@] %@", [self class], NSStringFromSelector(_cmd), error);
    
    NSURL *url = [[[frame provisionalDataSource] request] URL];
    NSString *errorHTML = [NSString stringWithFormat:@"<html><title>%@</title><body><h1>%@</h1></body></html>", NSLocalizedString(@"Error", @"Placeholder web group label"), [error localizedDescription]];
    [frame loadAlternateHTMLString:errorHTML baseURL:nil forUnreachableURL:url];
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame{
    [self webView:sender didFailLoadWithError:error forFrame:frame];
}

- (void)webView:(WebView *)sender didReceiveServerRedirectForProvisionalLoadForFrame:(WebFrame *)frame{
    if (frame == [sender mainFrame])
        [self notifyURL:[[[frame provisionalDataSource] request] URL]];
}

- (void)webView:(WebView *)sender didReceiveIcon:(NSImage *)image forFrame:(WebFrame *)frame{
    if (frame == [sender mainFrame])
        [self notifyIcon:image];
}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame {
    if (frame == [sender mainFrame])
        [self notifyTitle:title];
}

- (void)webView:(WebView *)sender didClearWindowObject:(WebScriptObject *)windowObject forFrame:(WebFrame *)frame {
    [windowObject setValue:[BDSKDownloadManager sharedManager] forKey:@"downloads"];
}

#pragma mark WebUIDelegate protocol

- (void)webView:(WebView *)sender setStatusText:(NSString *)text {
    if ([sender window] && [delegate respondsToSelector:@selector(webViewController:setStatusText:)])
        [delegate webViewController:self setStatusText:text];
}

- (void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation modifierFlags:(NSUInteger)modifierFlags {
    NSURL *aLink = [elementInformation objectForKey:WebElementLinkURLKey];
    [self webView:sender setStatusText:[[aLink absoluteString] stringByReplacingPercentEscapes]];
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems;
{
	NSMutableArray *menuItems = [NSMutableArray arrayWithArray:defaultMenuItems];
	NSMenuItem *item;
    
    NSUInteger i = [[menuItems valueForKey:@"tag"] indexOfObject:[NSNumber numberWithInteger:WebMenuItemTagOpenLinkInNewWindow]];
    
    if (i != NSNotFound) {
        item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Open Link in Browser", @"Menu item title")
                                                                    action:@selector(openInDefaultBrowser:)
                                                             keyEquivalent:@""];
        [item setTag:BDSKWebMenuItemTagOpenLinkInBrowser];
        [item setTarget:self];
        [item setRepresentedObject:element];
        [menuItems insertObject:[item autorelease] atIndex:++i];
        
        item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Bookmark Link", @"Menu item title") stringByAppendingEllipsis]
                                   action:@selector(bookmarkLink:)
                            keyEquivalent:@""];
        [item setTag:BDSKWebMenuItemTagBookmarkLink];
        [item setTarget:self];
        [item setRepresentedObject:element];
        [menuItems insertObject:[item autorelease] atIndex:++i];
        
        if ([[element objectForKey:WebElementLinkURLKey] isFileURL]) {
            item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Reveal Linked File", @"Menu item title")
                                       action:@selector(revealLink:)
                                keyEquivalent:@""];
            [item setTag:BDSKWebMenuItemTagRevealLink];
            [item setTarget:self];
            [item setRepresentedObject:element];
            [menuItems insertObject:[item autorelease] atIndex:++i];
        }
    }
    
	if ([menuItems count] > 0) 
		[menuItems addObject:[NSMenuItem separatorItem]];
	
    item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Increase Text Size", @"Menu item title")
                                                                action:@selector(makeTextLarger:)
                                                         keyEquivalent:@""];
    [item setTag:BDSKWebMenuItemTagMakeTextLarger];
	[menuItems addObject:[item autorelease]];
	
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Decrease Text Size", @"Menu item title")
                                                                action:@selector(makeTextSmaller:)
                                                         keyEquivalent:@""];
    [item setTag:BDSKWebMenuItemTagMakeTextSmaller];
	[menuItems addObject:[item autorelease]];
	
    [menuItems addObject:[NSMenuItem separatorItem]];
        
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Bookmark This Page", @"Menu item title") stringByAppendingEllipsis]
                                                                action:@selector(addBookmark:)
                                                         keyEquivalent:@""];
    [item setTag:BDSKWebMenuItemTagAddBookmark];
    [menuItems addObject:[item autorelease]];
    
    if ([delegate respondsToSelector:@selector(webViewController:contextMenuItemsForElement:defaultMenuItems:)])
        return [delegate webViewController:self contextMenuItemsForElement:element defaultMenuItems:menuItems];
    
	return menuItems;
}

- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request {
    // due to a known WebKit bug the request is always nil https://bugs.webkit.org/show_bug.cgi?id=23432
    WebView *view = nil;
    if ([delegate respondsToSelector:@selector(webViewControllerCreateWebView:)])
        view = [delegate webViewControllerCreateWebView:self];
    if (view == nil)
        view = [[BDSKNewWebWindowHandler sharedHandler] webView];
    if (request)
        [[view mainFrame] loadRequest:request];
    return view;
}

- (WebView *)webView:(WebView *)sender createWebViewModalDialogWithRequest:(NSURLRequest *)request {
    WebView *view = [[[[BDSKWebViewModalDialogController alloc] init] autorelease] webView];
    if (request)
        [[view mainFrame] loadRequest:request];
    return view;
}

// this seems to be necessary in order for webView:createWebViewModalDialogWithRequest: to work
- (void)webViewRunModal:(WebView *)sender {
    if ([delegate respondsToSelector:@selector(webViewControllerRunModal:)])
        [delegate webViewControllerRunModal:self];
}

- (void)webViewShow:(WebView *)sender {
    if ([delegate respondsToSelector:@selector(webViewControllerShow:)])
        [delegate webViewControllerShow:self];
}

- (void)webViewClose:(WebView *)sender {
    if ([delegate respondsToSelector:@selector(webViewControllerClose:)])
        [delegate webViewControllerClose:self];
}

// we don't want the default implementation to change our document window resizability
- (void)webView:(WebView *)sender setResizable:(BOOL)resizable {
    if ([delegate respondsToSelector:@selector(webViewController:setResizable:)])
        [delegate webViewController:self setResizable:resizable];
}

// we don't want the default implementation to change our document window frame
- (void)webView:(WebView *)sender setFrame:(NSRect)frame {
    if ([delegate respondsToSelector:@selector(webViewController:setFrame:)])
        [delegate webViewController:self setFrame:frame];
}

- (void)webView:(WebView *)sender setStatusBarVisible:(BOOL)visible {
    if ([delegate respondsToSelector:@selector(webViewController:setStatusBarVisible:)])
        [delegate webViewController:self setStatusBarVisible:visible];
}

- (BOOL)webViewIsStatusBarVisible:(WebView *)sender {
    if ([delegate respondsToSelector:@selector(webViewControllerIsStatusBarVisible:)])
        return [delegate webViewControllerIsStatusBarVisible:self];
    return NO;
}

- (NSString *)alertTitleForFrame:(WebFrame *)frame {
    NSURL *url = [[[frame dataSource] request] URL];
    NSString *scheme = [url scheme];
    NSString *host = [url host];
    if (scheme != nil && host != nil)
        return [NSString stringWithFormat:@"%@://%@", scheme, host];
    return NSLocalizedString(@"JavaScript", @"Default JavaScript alert title");
}

- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame {
    NSString *title = [self alertTitleForFrame:frame];
    NSAlert *alert = [NSAlert alertWithMessageText:title defaultButton:NSLocalizedString(@"OK", @"Button title") alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", message];
    [alert runModal];
}

- (BOOL)webView:(WebView *)sender runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame {
    NSString *title = [self alertTitleForFrame:frame];
    NSAlert *alert = [NSAlert alertWithMessageText:title defaultButton:NSLocalizedString(@"OK", @"Button title") alternateButton:NSLocalizedString(@"Cancel", @"Button title") otherButton:nil informativeTextWithFormat:@"%@", message];
    return NSAlertDefaultReturn == [alert runModal];
}

- (void)webView:(WebView *)sender runOpenPanelForFileButtonWithResultListener:(id < WebOpenPanelResultListener >)resultListener {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    if ([openPanel runModal] == NSFileHandlingPanelOKButton)
        [resultListener chooseFilename:[openPanel filename]];
    else
        [resultListener cancel];
}

#pragma mark WebEditingDelegate protocol

// this is needed because WebView uses the document's undo manager by default, rather than the one from the window.
// I consider this a bug
- (NSUndoManager *)undoManagerForWebView:(WebView *)sender {
    if (undoManager == nil)
        undoManager = [[NSUndoManager alloc] init];
    return undoManager;
}

@end

#pragma mark -

@implementation BDSKNewWebWindowHandler

static id sharedHandler = nil;

+ (id)sharedHandler {
    if (sharedHandler == nil)
        sharedHandler = [[self alloc] init];
    return sharedHandler;
}

- (id)init {
    if (self = [super init]) {
        webView = [[WebView alloc] init];
        [webView setPolicyDelegate:self];  
    }
    return self;
}

- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener {
    [[NSWorkspace sharedWorkspace] openURL:[actionInformation objectForKey:WebActionOriginalURLKey]];
    [listener ignore];
}

- (WebView *)webView {
    return webView;
}

- (void)dealloc {
    BDSKDESTROY(webView);
    [super dealloc];
}

@end

#pragma mark -

@implementation BDSKWebViewModalDialogController

- (id)init {
    NSUInteger mask = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask;
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 200.0, 200.0) styleMask:mask backing:NSBackingStoreBuffered defer:YES] autorelease];
    if (self = [self initWithWindow:window]) {
        [window setDelegate:self];
        webViewController = [[BDSKWebViewController alloc] initWithDelegate:self];
        WebView *webView = [webViewController webView];
        NSView *contentView = [window contentView];
        [webView setFrame:[contentView bounds]];
        [contentView addSubview:webView];
    }
    return self;
}

- (void)dealloc {
    [webViewController setDelegate:nil];
    BDSKDESTROY(webViewController);
    BDSKDESTROY(statusBar);
    [super dealloc];
}

- (WebView *)webView {
    return [webViewController webView];
}

- (void)windowWillClose:(NSNotification *)notification {
    [NSApp stopModal];
    [self autorelease];
}

- (void)webViewController:(BDSKWebViewController *)controller setTitle:(NSString *)title {
    [[self window] setTitle:title];
}

- (void)webViewController:(BDSKWebViewController *)controller setStatusText:(NSString *)text {
    [statusBar setStringValue:text ?: @""];
}

- (void)webViewControllerClose:(BDSKWebViewController *)controller {
    [[self window] close];
}

- (void)webViewControllerRunModal:(BDSKWebViewController *)controller {
    [self retain];
    // we can't use [NSApp runModalForWindow], because otherwise the webview does not download, and also it won't receive any close message from javascript
    // http://www.dejal.com/blog/2007/01/cocoa-topics-case-modal-webview
    NSModalSession session = [NSApp beginModalSessionForWindow:[self window]];
    for (;;) {
        if (NSRunContinuesResponse != [NSApp runModalSession:session]) break;
        // tickle the default run loop to let the webview download or let a close message come through
        [[NSRunLoop currentRunLoop] limitDateForMode:NSDefaultRunLoopMode];
    }
    [NSApp endModalSession:session];
}

- (void)webViewController:(BDSKWebViewController *)controller setResizable:(BOOL)resizable {
    NSWindow *window = [self window];
    [window setShowsResizeIndicator:resizable];
    [[window standardWindowButton:NSWindowZoomButton] setEnabled:resizable];
    if (resizable) {
        [window setMinSize:NSMakeSize(100.0, 100.0)];
        [window setMaxSize:[([window screen] ?: [NSScreen mainScreen]) visibleFrame].size];
    } else {
        [window setMinSize:[window frame].size];
        [window setMaxSize:[window frame].size];
    }
}

- (void)webViewController:(BDSKWebViewController *)controller setFrame:(NSRect)frame {
    [[self window] setFrame:frame display:YES];
    if ([[self window] showsResizeIndicator] == NO) {
        [[self window] setMinSize:frame.size];
        [[self window] setMaxSize:frame.size];
    }
}

- (void)webViewController:(BDSKWebViewController *)controller setStatusBarVisible:(BOOL)visible {
    if (visible != [statusBar isVisible]) {
        WebView *webView = [webViewController webView];
        if (visible && statusBar == nil) {
            statusBar = [[BDSKStatusBar alloc] initWithFrame:NSMakeRect(0.0, 0.0, NSWidth([webView frame]), 22.0)];
            [statusBar setAutoresizingMask:NSViewWidthSizable | NSViewMaxXMargin];
        }
        [statusBar toggleBelowView:webView animate:NO];
    }
}

- (BOOL)webViewControllerIsStatusBarVisible:(BDSKWebViewController *)controller {
    return [statusBar isVisible];
}

@end

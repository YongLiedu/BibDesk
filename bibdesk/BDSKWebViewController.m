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
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKBookmarkController.h"
#import "BDSKDownloadManager.h"
#import "BDSKStatusBar.h"
#import "NSString_BDSKExtensions.h"


@interface BDSKWebDelegate : NSObject {
    id <BDSKWebViewDelegate> delegate;
    id <BDSKWebViewNavigationDelegate> navigationDelegate;
    NSUndoManager *undoManager;    
}

- (id<BDSKWebViewDelegate>)delegate;
- (void)setDelegate:(id<BDSKWebViewDelegate>)newDelegate;

- (id<BDSKWebViewNavigationDelegate>)navigationDelegate;
- (void)setNavigationDelegate:(id<BDSKWebViewNavigationDelegate>)newDelegate;

@end

#pragma mark -

@implementation BDSKWebView

- (id)initWithFrame:(NSRect)frameRect frameName:(NSString *)frameName groupName:(NSString *)groupName {
    if (self = [super initWithFrame:frameRect frameName:frameName groupName:@"BibDeskWebGroup"]) {
        [self setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        webDelegate = [[BDSKWebDelegate alloc] init];
        [self setFrameLoadDelegate:webDelegate];
        [self setUIDelegate:webDelegate];
        [self setEditingDelegate:webDelegate];
        [self setDownloadDelegate:[BDSKDownloadManager sharedManager]];
    }
    return self;
}

- (void)dealloc {
    [webDelegate setDelegate:nil];
    [self setFrameLoadDelegate:nil];
    [self setUIDelegate:nil];
    [self setEditingDelegate:nil];
    [self setDownloadDelegate:nil];
    BDSKDESTROY(webDelegate);
    [super dealloc];
}

- (NSURL *)URL {
    WebFrame *mainFrame = [self mainFrame];
    WebDataSource *dataSource = [mainFrame provisionalDataSource] ?: [mainFrame dataSource];
    return [[dataSource request] URL];
}

- (void)setURL:(NSURL *)newURL {
    if (newURL && [[[[[self mainFrame] dataSource] request] URL] isEqual:newURL] == NO) {
        [[self mainFrame] loadRequest:[NSURLRequest requestWithURL:newURL]];
    }
}

- (id<BDSKWebViewDelegate>)delegate { return [webDelegate delegate]; }

- (void)setDelegate:(id<BDSKWebViewDelegate>)newDelegate { [webDelegate setDelegate:newDelegate]; }

- (id<BDSKWebViewNavigationDelegate>)navigationDelegate { return [webDelegate navigationDelegate]; }
- (void)setNavigationDelegate:(id<BDSKWebViewNavigationDelegate>)newDelegate { [webDelegate setNavigationDelegate:newDelegate]; }

@end

#pragma mark -

@implementation BDSKWebDelegate

- (void)dealloc {
    delegate = nil;
    navigationDelegate = nil;
    BDSKDESTROY(undoManager);
    [super dealloc];
}

- (void)webView:(WebView *)sender setURL:(NSURL *)aURL {
    if ([navigationDelegate respondsToSelector:@selector(webView:setURL:)])
        [navigationDelegate webView:sender setURL:aURL];
}

- (void)webView:(WebView *)sender setIcon:(NSImage *)icon {
    if ([navigationDelegate respondsToSelector:@selector(webView:setIcon:)])
        [navigationDelegate webView:sender setIcon:icon];
}

- (void)webView:(WebView *)sender setLoading:(BOOL)loading {
    if ([navigationDelegate respondsToSelector:@selector(webView:setLoading:)])
        [navigationDelegate webView:sender setLoading:loading];
}

- (void)webView:(WebView *)sender setTitle:(NSString *)title {
    if ([delegate respondsToSelector:@selector(webView:setTitle:)]) {
        if ([NSString isEmptyString:title] && [sender respondsToSelector:@selector(URL)]) {
            NSURL *url = [(BDSKWebView *)sender URL];
            title = [url isFileURL] ? [[url path] lastPathComponent] : [[url absoluteString] stringByReplacingPercentEscapes];
        }
        [delegate webView:sender setTitle:title ?: @""];
    }
}

#pragma mark Accessors

- (id<BDSKWebViewDelegate>)delegate { return delegate; }

- (void)setDelegate:(id<BDSKWebViewDelegate>)newDelegate { delegate = newDelegate; }

- (id<BDSKWebViewNavigationDelegate>)navigationDelegate { return navigationDelegate; }

- (void)setNavigationDelegate:(id<BDSKWebViewNavigationDelegate>)newDelegate { navigationDelegate = newDelegate; }

#pragma mark Actions

- (void)bookmarkLink:(id)sender {
	NSDictionary *element = (NSDictionary *)[sender representedObject];
	NSString *URLString = [(NSURL *)[element objectForKey:WebElementLinkURLKey] absoluteString];
	NSString *title = [element objectForKey:WebElementLinkLabelKey] ?: [URLString lastPathComponent];
	WebFrame *frame = [element objectForKey:WebElementFrameKey];
	
    [[BDSKBookmarkController sharedBookmarkController] addBookmarkWithUrlString:URLString proposedName:title modalForWindow:[[frame webView] window]];
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
    if (frame == [sender mainFrame]) {
        [self webView:sender setIcon:nil];
        [self webView:sender setTitle:[NSLocalizedString(@"Loading", @"Placeholder web group label") stringByAppendingEllipsis]];
        
        if ([[frame provisionalDataSource] unreachableURL] == nil)
            [self webView:sender setURL:[[[[sender mainFrame] provisionalDataSource] request] URL]];
    }
    [self webView:sender setLoading:[sender isLoading]];
    
    if ([delegate respondsToSelector:@selector(webView:didStartLoadForFrame:)])
        [delegate webView:sender didStartLoadForFrame:frame];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame{

    if (frame == [sender mainFrame]) {
        [self webView:sender setIcon:[sender mainFrameIcon]];
        [self webView:sender setTitle:[sender mainFrameTitle]];
    }
    [self webView:sender setLoading:[sender isLoading]];
    if ([delegate respondsToSelector:@selector(webView:didFinishLoadForFrame:)])
        [delegate webView:sender didFinishLoadForFrame:frame];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame{
    if ([delegate respondsToSelector:@selector(webView:didFailLoadWithError:forFrame:)])
        [delegate webView:sender didFailLoadWithError:error forFrame:frame];
    [self webView:sender setLoading:[sender isLoading]];
    
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
        [self webView:sender setURL:[[[frame provisionalDataSource] request] URL]];
}

- (void)webView:(WebView *)sender didReceiveIcon:(NSImage *)image forFrame:(WebFrame *)frame{
    if (frame == [sender mainFrame])
        [self webView:sender setIcon:image];
}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame {
    if (frame == [sender mainFrame])
        [self webView:sender setTitle:title];
}

- (void)webView:(WebView *)sender didClearWindowObject:(WebScriptObject *)windowObject forFrame:(WebFrame *)frame {
    [windowObject setValue:[BDSKDownloadManager sharedManager] forKey:@"downloads"];
}

#pragma mark WebUIDelegate protocol

- (void)webView:(WebView *)sender setStatusText:(NSString *)text {
    if ([sender window] && [delegate respondsToSelector:@selector(webView:setStatusText:)])
        [delegate webView:sender setStatusText:text];
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
    
    if ([delegate respondsToSelector:@selector(webView:contextMenuItemsForElement:defaultMenuItems:)])
        return [delegate webView:sender contextMenuItemsForElement:element defaultMenuItems:menuItems];
    
	return menuItems;
}

- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request {
    // due to a known WebKit bug the request is always nil https://bugs.webkit.org/show_bug.cgi?id=23432
    WebView *view = nil;
    if ([delegate respondsToSelector:@selector(webViewCreateWebView:)])
        view = [delegate webViewCreateWebView:sender];
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
    if ([delegate respondsToSelector:@selector(webViewRunModal:)])
        [delegate webViewRunModal:sender];
}

- (void)webViewShow:(WebView *)sender {
    if ([delegate respondsToSelector:@selector(webViewShow:)])
        [delegate webViewShow:sender];
}

- (void)webViewClose:(WebView *)sender {
    if ([delegate respondsToSelector:@selector(webViewClose:)])
        [delegate webViewClose:sender];
}

// we don't want the default implementation to change our document window resizability
- (void)webView:(WebView *)sender setResizable:(BOOL)resizable {
    if ([delegate respondsToSelector:@selector(webView:setResizable:)])
        [delegate webView:sender setResizable:resizable];
}

// we don't want the default implementation to change our document window frame
- (void)webView:(WebView *)sender setFrame:(NSRect)frame {
    if ([delegate respondsToSelector:@selector(webView:setFrame:)])
        [delegate webView:sender setFrame:frame];
}

- (void)webView:(WebView *)sender setStatusBarVisible:(BOOL)visible {
    if ([delegate respondsToSelector:@selector(webView:setStatusBarVisible:)])
        [delegate webView:sender setStatusBarVisible:visible];
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
        webView = [[BDSKWebView alloc] init];
        [webView setDelegate:self];
        NSView *contentView = [window contentView];
        [webView setFrame:[contentView bounds]];
        [contentView addSubview:webView];
    }
    return self;
}

- (void)dealloc {
    [webView setDelegate:nil];
    BDSKDESTROY(webView);
    BDSKDESTROY(statusBar);
    [super dealloc];
}

- (WebView *)webView {
    return webView;
}

- (void)windowWillClose:(NSNotification *)notification {
    [NSApp stopModal];
    [self autorelease];
}

- (void)webView:(WebView *)sender setTitle:(NSString *)title {
    [[self window] setTitle:title];
}

- (void)webView:(WebView *)sender setStatusText:(NSString *)text {
    [statusBar setStringValue:text ?: @""];
}

- (void)webViewClose:(WebView *)sender {
    [[self window] close];
}

- (void)webViewRunModal:(WebView *)sender {
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

- (void)webView:(WebView *)sender setResizable:(BOOL)resizable {
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

- (void)webView:(WebView *)sender setFrame:(NSRect)frame {
    [[self window] setFrame:frame display:YES];
    if ([[self window] showsResizeIndicator] == NO) {
        [[self window] setMinSize:frame.size];
        [[self window] setMaxSize:frame.size];
    }
}

- (void)webView:(WebView *)sender setStatusBarVisible:(BOOL)visible {
    if (visible != [statusBar isVisible]) {
        if (visible && statusBar == nil) {
            statusBar = [[BDSKStatusBar alloc] initWithFrame:NSMakeRect(0.0, 0.0, NSWidth([webView frame]), 22.0)];
            [statusBar setAutoresizingMask:NSViewWidthSizable | NSViewMaxXMargin];
        }
        [statusBar toggleBelowView:webView animate:NO];
    }
}

@end

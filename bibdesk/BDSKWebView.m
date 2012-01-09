//
//  BDSKWebView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/24/10.
/*
 This software is Copyright (c) 2010-2012
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

#import "BDSKWebView.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKBookmarkController.h"
#import "BDSKDownloadManager.h"
#import "BDSKWebViewModalDialogController.h"
#import "NSString_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSEvent_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"


@interface WebView (BDSKSnowLeopardDeclarations)
- (void)reloadFromOrigin:(id)sender;
@end

#pragma mark -

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

// workaround for loading a URL from a javasecript window.open event http://stackoverflow.com/questions/270458/cocoa-webkit-having-window-open-javascipt-links-opening-in-an-instance-of-safa
@interface BDSKNewWebWindowHandler : NSObject {
    WebView *webView;
}
+ (id)sharedHandler;
- (WebView *)webView;
@end

#pragma mark -

@implementation BDSKWebView

- (id)initWithFrame:(NSRect)frameRect frameName:(NSString *)frameName groupName:(NSString *)groupName {
    self = [super initWithFrame:frameRect frameName:frameName groupName:@"BibDeskWebGroup"];
    if (self) {
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

#pragma mark Actions

- (IBAction)reload:(id)sender {
    if (([NSEvent standardModifierFlags] & NSShiftKeyMask) && [self respondsToSelector:@selector(reloadFromOrigin:)])
		[super reloadFromOrigin:sender];
    else
        [super reload:self];
}

- (IBAction)addBookmark:(id)sender {
	WebDataSource *datasource = [[self mainFrame] dataSource];
	NSURL *theURL = [[datasource request] URL];
	NSString *name = [datasource pageTitle] ?: [theURL lastPathComponent];
    if (theURL)
        [[BDSKBookmarkController sharedBookmarkController] addBookmarkWithUrlString:[theURL absoluteString] proposedName:name modalForWindow:[self window]];
}

- (void)bookmarkLink:(id)sender {
	NSDictionary *element = (NSDictionary *)[sender representedObject];
	NSURL *theURL = [element objectForKey:WebElementLinkURLKey];
	NSString *name = [element objectForKey:WebElementLinkLabelKey] ?: [theURL lastPathComponent];
    if (theURL)
        [[BDSKBookmarkController sharedBookmarkController] addBookmarkWithUrlString:[theURL absoluteString] proposedName:name modalForWindow:[self window]];
}

- (void)revealLink:(id)sender {
	NSURL *linkURL = (NSURL *)[[sender representedObject] objectForKey:WebElementLinkURLKey];
    if ([linkURL isFileURL])
        [[NSWorkspace sharedWorkspace] selectFile:[linkURL path] inFileViewerRootedAtPath:nil];
    else
        NSBeep();
}

- (void)openLinkInBrowser:(id)sender {
    NSDictionary *element = (NSDictionary *)[sender representedObject];
	NSURL *theURL = [element objectForKey:WebElementLinkURLKey];
    if (theURL)
        [[NSWorkspace sharedWorkspace] openLinkedURL:theURL];
}

@end

#pragma mark -

@implementation BDSKWebDelegate

- (void)dealloc {
    delegate = nil;
    navigationDelegate = nil;
    BDSKDESTROY(undoManager);
    [super dealloc];
}

#pragma mark Accessors

- (id<BDSKWebViewDelegate>)delegate { return delegate; }

- (void)setDelegate:(id<BDSKWebViewDelegate>)newDelegate { delegate = newDelegate; }

- (id<BDSKWebViewNavigationDelegate>)navigationDelegate { return navigationDelegate; }

- (void)setNavigationDelegate:(id<BDSKWebViewNavigationDelegate>)newDelegate { navigationDelegate = newDelegate; }

#pragma mark Delegate forward

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
    if ([delegate respondsToSelector:@selector(webView:setTitle:)])
        [delegate webView:sender setTitle:title ?: @""];
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
        NSString *title = [sender mainFrameTitle];
        if ([NSString isEmptyString:title]) {
            NSURL *url = [[[frame dataSource] request] URL];
            title = [url isFileURL] ? [[url path] lastPathComponent] : [[url absoluteString] stringByReplacingPercentEscapes];
        }
        [self webView:sender setIcon:[sender mainFrameIcon]];
        [self webView:sender setTitle:title];
    }
    [self webView:sender setLoading:[sender isLoading]];
    if ([delegate respondsToSelector:@selector(webView:didFinishLoadForFrame:)])
        [delegate webView:sender didFinishLoadForFrame:frame];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame{
    if ([delegate respondsToSelector:@selector(webView:didFailLoadForFrame:)])
        [delegate webView:sender didFailLoadForFrame:frame];
    [self webView:sender setLoading:[sender isLoading]];
    
    // !!! logs are here to help diagnose problems that users are reporting
    NSLog(@"-[%@ %@] %@", [self class], NSStringFromSelector(_cmd), error);
    
    // "plug-in handled load" is reported as a failure with code 204
    if ([[error domain] isEqualToString:WebKitErrorDomain] == NO || [error code] != 204) {
        NSURL *url = [[[frame provisionalDataSource] request] URL];
        NSString *errorHTML = [NSString stringWithFormat:@"<html><title>%@</title><body><h1>%@</h1></body></html>", NSLocalizedString(@"Error", @"Placeholder web group label"), [error localizedDescription]];
        [frame loadAlternateHTMLString:errorHTML baseURL:nil forUnreachableURL:url];
    }
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

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
	NSMutableArray *menuItems = [NSMutableArray arrayWithArray:defaultMenuItems];
	NSMenuItem *item;
    
    NSUInteger i = [[menuItems valueForKey:@"tag"] indexOfObject:[NSNumber numberWithInteger:WebMenuItemTagOpenLinkInNewWindow]];
    
    if (i != NSNotFound) {
        item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Open Link in Browser", @"Menu item title")
                                                                    action:@selector(openLinkInBrowser:)
                                                             keyEquivalent:@""];
        [item setTag:BDSKWebMenuItemTagOpenLinkInBrowser];
        [item setTarget:sender];
        [item setRepresentedObject:element];
        [menuItems insertObject:item atIndex:++i];
        [item release];
        
        item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Bookmark Link", @"Menu item title") stringByAppendingEllipsis]
                                   action:@selector(bookmarkLink:)
                            keyEquivalent:@""];
        [item setTag:BDSKWebMenuItemTagBookmarkLink];
        [item setTarget:sender];
        [item setRepresentedObject:element];
        [menuItems insertObject:item atIndex:++i];
        [item release];
        
        if ([[element objectForKey:WebElementLinkURLKey] isFileURL]) {
            item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Reveal Linked File", @"Menu item title")
                                       action:@selector(revealLink:)
                                keyEquivalent:@""];
            [item setTag:BDSKWebMenuItemTagRevealLink];
            [item setTarget:sender];
            [item setRepresentedObject:element];
            [menuItems insertObject:item atIndex:++i];
            [item release];
        }
    }
    
	if ([menuItems count] > 0) 
		[menuItems addObject:[NSMenuItem separatorItem]];
	
    item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Increase Text Size", @"Menu item title")
                                                                action:@selector(makeTextLarger:)
                                                         keyEquivalent:@""];
    [item setTag:BDSKWebMenuItemTagMakeTextLarger];
    [item setTarget:sender];
	[menuItems addObject:item];
    [item release];
	
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Decrease Text Size", @"Menu item title")
                                                                action:@selector(makeTextSmaller:)
                                                         keyEquivalent:@""];
    [item setTag:BDSKWebMenuItemTagMakeTextSmaller];
    [item setTarget:sender];
	[menuItems addObject:item];
    [item release];
	
    [menuItems addObject:[NSMenuItem separatorItem]];
        
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Bookmark This Page", @"Menu item title") stringByAppendingEllipsis]
                                                                action:@selector(addBookmark:)
                                                         keyEquivalent:@""];
    [item setTag:BDSKWebMenuItemTagAddBookmark];
    [item setTarget:sender];
    [menuItems addObject:item];
    [item release];
    
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

// This is a private WebUIDelegate method that is called by WebPDFView
- (void)webView:(WebView *)sender saveFrameView:(WebFrameView *)frameView showingPanel:(BOOL)showingPanel {
    WebDataSource *dataSource = [[frameView webFrame] dataSource];
    NSString *downloadsDir = [[[NSUserDefaults standardUserDefaults] stringForKey:BDSKDownloadsDirectoryKey] stringByExpandingTildeInPath] ?: [[[NSFileManager defaultManager] downloadFolderURL] path];
    NSString *filename = [[dataSource response] suggestedFilename];
    filename = [[NSFileManager defaultManager] uniqueFilePathWithName:filename atPath:downloadsDir];
    if (showingPanel) {
        NSSavePanel *savePanel = [NSSavePanel savePanel];
        NSInteger returnCode = [savePanel runModalForDirectory:downloadsDir file:[filename lastPathComponent]];
        if (returnCode == NSFileHandlingPanelCancelButton)
            return;
        filename = [savePanel filename];
    }
    [[dataSource data] writeToFile:filename atomically:YES];
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
    self = [super init];
    if (self) {
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

//
//  BDSKWebView.h
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

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

enum {
    BDSKWebMenuItemTagOpenLinkInBrowser = 1001,
    BDSKWebMenuItemTagBookmarkLink,
    BDSKWebMenuItemTagRevealLink,
    BDSKWebMenuItemTagMakeTextLarger,
    BDSKWebMenuItemTagMakeTextSmaller,
    BDSKWebMenuItemTagAddBookmark
};

@class BDSKWebDelegate, BDSKStatusBar;
@protocol BDSKWebViewDelegate, BDSKWebViewNavigationDelegate;

@interface BDSKWebView : WebView {
    BDSKWebDelegate *webDelegate;
}

- (id<BDSKWebViewDelegate>)delegate;
- (void)setDelegate:(id<BDSKWebViewDelegate>)newDelegate;

- (id<BDSKWebViewNavigationDelegate>)navigationDelegate;
- (void)setNavigationDelegate:(id<BDSKWebViewNavigationDelegate>)newDelegate;

- (NSURL *)URL;
- (void)setURL:(NSURL *)newURL;

- (IBAction)addBookmark:(id)sender;

@end

#pragma mark -

@protocol BDSKWebViewDelegate <NSObject>
@optional

- (void)webView:(WebView *)sender setTitle:(NSString *)title;
- (void)webView:(WebView *)sender setStatusText:(NSString *)text;

- (WebView *)webViewCreateWebView:(WebView *)sender;
- (void)webViewShow:(WebView *)sender;
- (void)webViewClose:(WebView *)sender;
- (void)webViewRunModal:(WebView *)sender;

- (void)webView:(WebView *)sender setResizable:(BOOL)resizable;
- (void)webView:(WebView *)sender setFrame:(NSRect)frame;
- (void)webView:(WebView *)sender setStatusBarVisible:(BOOL)visible;

- (void)webView:(WebView *)sender didStartLoadForFrame:(WebFrame *)frame;
- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame;
- (void)webView:(WebView *)sender didFailLoadForFrame:(WebFrame *)frame;

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems;

@end

#pragma mark -

@protocol BDSKWebViewNavigationDelegate <NSObject>
@optional

- (void)webView:(WebView *)sender setURL:(NSURL *)aURL;
- (void)webView:(WebView *)sender setIcon:(NSImage *)icon;
- (void)webView:(WebView *)sender setLoading:(BOOL)loading;

@end

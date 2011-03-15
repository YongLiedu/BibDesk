//
//  BDSKWebViewModalDialogController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/31/10.
/*
 This software is Copyright (c) 2010-2011
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

#import "BDSKWebViewModalDialogController.h"
#import "BDSKWebView.h"
#import "BDSKStatusBar.h"


@implementation BDSKWebViewModalDialogController

- (id)init {
    NSUInteger mask = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask;
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 200.0, 200.0) styleMask:mask backing:NSBackingStoreBuffered defer:YES] autorelease];
    self = [self initWithWindow:window];
    if (self) {
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

#pragma mark BDSKWebViewDelegate protocol

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

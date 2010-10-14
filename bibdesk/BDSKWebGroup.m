//
//  BDSKWebGroup.m
//  Bibdesk
//
//  Created by Michael McCracken on 1/25/07.
/*
 This software is Copyright (c) 2007-2010
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BDSKWebGroup.h"
#import "BDSKStringConstants.h"
#import "BDSKPublicationsArray.h"
#import "BDSKMacroResolver.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKItemSearchIndexes.h"
#import "BibItem.h"
#import <WebKit/WebKit.h>
#import "BDSKWebParser.h"
#import "BDSKBibTeXParser.h"
#import "BDSKStringParser.h"
#import "BDSKBibDeskProtocol.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKBookmarkController.h"
#import "BDSKDownloadManager.h"
#import "BibDocument.h"
#import "BibDocument_UI.h"
#import "NSString_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"

// workaround for loading a URL from a javasecript window.open event http://stackoverflow.com/questions/270458/cocoa-webkit-having-window-open-javascipt-links-opening-in-an-instance-of-safa
@interface BDSKNewWebWindowHandler : NSObject {
    WebView *webView;
}
- (WebView *)webView;
@end

#pragma mark -

@implementation BDSKWebGroup

static NSString *BDSKWebLocalizedString = nil;

+ (void)initialize {
    BDSKINITIALIZE;
    
    BDSKWebLocalizedString = [NSLocalizedString(@"Web", @"Group name for web") copy];
	
    // register for bibdesk: protocol, so we can display a help page on start
	[NSURLProtocol registerClass:[BDSKBibDeskProtocol class]];
	[WebView registerURLSchemeAsLocal:BDSKBibDeskScheme];	
}

- (id)init {
	self = [super initWithName:BDSKWebLocalizedString];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [webView setFrameLoadDelegate:nil];
    [webView setUIDelegate:nil];
    [webView setPolicyDelegate:nil];
    [webView setEditingDelegate:nil];
    delegate = nil;
    BDSKDESTROY(label);
    BDSKDESTROY(webView);
    BDSKDESTROY(undoManager);
    BDSKDESTROY(newWindowHandler);
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)aZone {
	BDSKWebGroup *copy = [[[self class] allocWithZone:aZone] init];
    NSURL *url = [self URL];
    if (url)
        [copy setURL:url];
    return copy;
}

#pragma mark BDSKGroup overrides

// note that pointer equality is used for these groups, so names can overlap

- (NSImage *)icon { return [NSImage imageNamed:@"webGroup"]; }

- (BOOL)isWeb { return YES; }

- (BOOL)isRetrieving { return isRetrieving; }

- (NSString *)label {
    return [label length] > 0 ? label : NSLocalizedString(@"(Empty)", @"Empty web group label");
}

- (void)setLabel:(NSString *)newLabel {
    if (label != newLabel) {
        [label release];
        label = [newLabel retain];
    }
}

#pragma mark BDSKExternalGroup overrides

// web groups don't initiate loading themselves
- (BOOL)shouldRetrievePublications { return NO; }

#pragma mark Accessors

- (WebView *)webView {
    if (webView == nil) {
        webView = [[WebView alloc] init];
        [webView setFrameLoadDelegate:self];
        [webView setUIDelegate:self];
        [webView setPolicyDelegate:self];
        [webView setEditingDelegate:self];
        [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:BDSKBibDeskWebGroupURL]];
    }
    return webView;
}

- (id<BDSKWebGroupDelegate>)delegate {
    return delegate;
}

- (void)setDelegate:(id<BDSKWebGroupDelegate>)newDelegate {
    delegate = newDelegate;
}

- (NSURL *)URL {
    return [[[[webView mainFrame] provisionalDataSource] request] URL] ?: [[[[webView mainFrame] dataSource] request] URL];
}

- (void)setURL:(NSURL *)newURL {
    if (newURL && [[[[[[self webView] mainFrame] dataSource] request] URL] isEqual:newURL] == NO) {
        [self setLabel:[NSLocalizedString(@"Loading", @"Placeholder web group label") stringByAppendingEllipsis]];
        [delegate webGroup:self setIcon:nil];
        [delegate webGroup:self setURL:newURL];
        [[[self webView] mainFrame] loadRequest:[NSURLRequest requestWithURL:newURL]];
    }
}

#pragma mark Actions

- (void)bookmarkLink:(id)sender {
	NSDictionary *element = (NSDictionary *)[sender representedObject];
	NSString *URLString = [(NSURL *)[element objectForKey:WebElementLinkURLKey] absoluteString];
	NSString *title = [element objectForKey:WebElementLinkLabelKey] ?: [URLString lastPathComponent];
	
    [[BDSKBookmarkController sharedBookmarkController] addBookmarkWithUrlString:URLString proposedName:title modalForWindow:[webView window]];
}

- (void)downloadLink:(id)sender {
	NSURL *linkURL = (NSURL *)[[sender representedObject] objectForKey:WebElementLinkURLKey];
    if (linkURL)
        [[BDSKDownloadManager sharedManager] addDownloadForURL:linkURL];
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
        
        BDSKASSERT(loadingWebFrame == nil);
        
        [delegate webGroup:self setIcon:nil];
        [self setLabel:[NSLocalizedString(@"Loading", @"Placeholder web group label") stringByAppendingEllipsis]];
        
        isRetrieving = YES;
        [self setPublications:nil];
        loadingWebFrame = frame;
        
        if ([[frame provisionalDataSource] unreachableURL] == nil && delegate)
            [delegate webGroup:self setURL:[[[[webView mainFrame] provisionalDataSource] request] URL]];
        
    } else if (loadingWebFrame == nil) {
        
        isRetrieving = YES;
        [self addPublications:nil];
        loadingWebFrame = frame;
        
    }
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame{

	NSURL *url = [[[frame dataSource] request] URL];
    DOMDocument *domDocument = [frame DOMDocument];
    
    NSError *error = nil;
    NSArray *newPubs = [BDSKWebParser itemsFromDocument:domDocument fromURL:url error:&error];
    if ([newPubs count] == 0) {
        WebDataSource *dataSource = [frame dataSource];
        if ([[[dataSource mainResource] MIMEType] isEqualToString:@"text/plain"]) { 
            NSString *string = [[dataSource representation] documentSource];
            if(string == nil) {
                NSString *encodingName = [dataSource textEncodingName];
                CFStringEncoding cfEncoding = kCFStringEncodingInvalidId;
                NSStringEncoding nsEncoding = NSUTF8StringEncoding;
                
                if (encodingName != nil)
                    cfEncoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)encodingName);
                if (cfEncoding != kCFStringEncodingInvalidId)
                    nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
                string = [[[NSString alloc] initWithData:[dataSource data] encoding:nsEncoding] autorelease];
            }
            BDSKStringType type = [string contentStringType];
            BOOL isPartialData = NO;
            if (type == BDSKBibTeXStringType)
                newPubs = [BDSKBibTeXParser itemsFromString:string owner:nil isPartialData:&isPartialData error:&error];
            else if (type == BDSKNoKeyBibTeXStringType)
                newPubs = [BDSKBibTeXParser itemsFromString:[string stringWithPhoneyCiteKeys:@"cite-key"] owner:nil isPartialData:&isPartialData error:&error];
            else if (type != BDSKUnknownStringType)
                newPubs = [BDSKStringParser itemsFromString:string ofType:type error:&error];
        }
        else if (nil == newPubs) {
            // !!! logs are here to help diagnose problems that users are reporting
            // but unsupported web pages are far too common, we don't want to flood the console
            if ([[error domain] isEqualToString:[NSError localErrorDomain]] == NO || [error code] != kBDSKWebParserUnsupported)
                NSLog(@"-[%@ %@] %@", [self class], NSStringFromSelector(_cmd), error);
            //NSLog(@"loaded MIME type %@", [[dataSource mainResource] MIMEType]);
            // !!! what to do here? if user clicks on a PDF, we're loading application/pdf, which is clearly not an error from the user perspective...so should the error only be presented for text/plain?
            //[NSApp presentError:error];
        }
    }
    
    if (frame == [sender mainFrame]) {
        NSString *title = [sender mainFrameTitle];
        [delegate webGroup:self setIcon:[sender mainFrameIcon]];
        [self setLabel:[NSString isEmptyString:title] ?  [[self URL] absoluteString] : title];
    }
    
    if (frame == loadingWebFrame) {
        isRetrieving = NO;
        loadingWebFrame = nil;
    }
    [self addPublications:newPubs ?: [NSArray array]];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame{
    if (frame == loadingWebFrame) {
        isRetrieving = NO;
        [self addPublications:nil];
        loadingWebFrame = nil;
    }
    
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
    if (frame == [sender mainFrame] && delegate) { 
        [delegate webGroup:self setURL:[[[frame provisionalDataSource] request] URL]];
    }
}

- (void)webView:(WebView *)sender didReceiveIcon:(NSImage *)image forFrame:(WebFrame *)frame{
    if (frame == [sender mainFrame] && delegate) { 
        [delegate webGroup:self setIcon:image];
    }
}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame {
    if (frame == [sender mainFrame]) { 
        [self setLabel:title];
    }
}

#pragma mark WebPolicyDelegate protocol

- (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id < WebPolicyDecisionListener >)listener {
    [listener ignore];
    [[NSWorkspace sharedWorkspace] openURL:[request URL]];
}

#pragma mark WebUIDelegate protocol

- (void)webView:(WebView *)sender setStatusText:(NSString *)text {
    if ([sender window]) {
        if ([NSString isEmptyString:text])
            [document updateStatus];
        else
            [document setStatus:text];
    }
}

- (void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation modifierFlags:(NSUInteger)modifierFlags {
    NSURL *aLink = [elementInformation objectForKey:WebElementLinkURLKey];
    [self webView:sender setStatusText:[[aLink absoluteString] stringByReplacingPercentEscapes]];
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems;
{
	NSMutableArray *menuItems = [NSMutableArray arrayWithArray:defaultMenuItems];
	NSMenuItem *item;
    
    // @@ we may want to add support for some of these (downloading), but it's confusing to have them in the menu for now
    NSArray *itemsToRemove = [NSArray arrayWithObjects:[NSNumber numberWithInteger:WebMenuItemTagOpenLinkInNewWindow], [NSNumber numberWithInteger:WebMenuItemTagDownloadLinkToDisk], [NSNumber numberWithInteger:WebMenuItemTagOpenImageInNewWindow], [NSNumber numberWithInteger:WebMenuItemTagDownloadImageToDisk], [NSNumber numberWithInteger:WebMenuItemTagOpenFrameInNewWindow], nil];
    for (NSNumber *n in itemsToRemove) {
        NSUInteger toRemove = [[menuItems valueForKey:@"tag"] indexOfObject:n];
        if (toRemove != NSNotFound)
            [menuItems removeObjectAtIndex:toRemove];
    }
	
    NSUInteger i = [[menuItems valueForKey:@"tag"] indexOfObject:[NSNumber numberWithInteger:WebMenuItemTagCopyLinkToClipboard]];
    
    if (i != NSNotFound) {
        
        item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Open in Default Browser",@"Open web page")
                                                                    action:@selector(openInDefaultBrowser:)
                                                             keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:element];
        [menuItems insertObject:[item autorelease] atIndex:(i > 0 ? i - 1 : 0)];
        
        item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Bookmark Link",@"Bookmark linked page") stringByAppendingEllipsis]
                                   action:@selector(bookmarkLink:)
                            keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:element];
        [menuItems insertObject:[item autorelease] atIndex:++i];
        
        item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Save Link As",@"Bookmark linked page") stringByAppendingEllipsis]
                                   action:@selector(downloadLink:)
                            keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:element];
        [menuItems insertObject:[item autorelease] atIndex:++i];
    }
    
	if ([menuItems count] > 0) 
		[menuItems addObject:[NSMenuItem separatorItem]];
	
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Back", @"Menu item title")
                                                                action:@selector(goBack:)
                                                         keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Forward", @"Menu item title")
                                                                action:@selector(goForward:)
                                                         keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Reload", @"Menu item title")
                                                                action:@selector(reload:)
                                                         keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Stop", @"Menu item title")
                                                                action:@selector(stopLoading:)
                                                         keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Increase Text Size", @"Menu item title")
                                                                action:@selector(makeTextLarger:)
                                                         keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Decrease Text Size", @"Menu item title")
                                                                action:@selector(makeTextSmaller:)
                                                         keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
    [menuItems addObject:[NSMenuItem separatorItem]];
        
	item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Bookmark This Page", @"Menu item title") stringByAppendingEllipsis]
                                                                action:@selector(addBookmark:)
                                                         keyEquivalent:@""];
    [item setTarget:sender];
    [item setRepresentedObject:element];
    [menuItems addObject:[item autorelease]];
    
	return menuItems;
}

- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request {
    // due to a known WebKit bug the request is always nil https://bugs.webkit.org/show_bug.cgi?id=23432
    if (newWindowHandler == nil)
        newWindowHandler = [[BDSKNewWebWindowHandler alloc] init];
    return [newWindowHandler webView];
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

-(WebView *)webView {
    return webView;
}

- (void)dealloc {
    BDSKDESTROY(webView);
    [super dealloc];
}

@end

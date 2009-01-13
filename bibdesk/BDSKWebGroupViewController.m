//
//  BDSKWebGroupViewController.m
//  Bibdesk
//
//  Created by Michael McCracken on 1/26/07.

/*
 This software is Copyright (c) 2007-2009
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
 
 - Neither the name of Michael McCracken nor the names of any
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

#import "BDSKWebGroupViewController.h"
#import <WebKit/WebKit.h>
#import "BDSKWebParser.h"
#import "BDSKStringParser.h"
#import "BDSKWebGroup.h"
#import "BDSKCollapsibleView.h"
#import "BDSKEdgeView.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "BibDocument.h"
#import "BDSKBookmarkController.h"


@implementation BDSKWebGroupViewController

+ (void)initialize {
    OBINITIALIZE;
    
    static NSImage *backAdornImage = nil;
    static NSImage *forwardAdornImage = nil;
    static NSImage *reloadAdornImage = nil;
    static NSImage *stopAdornImage = nil;
    
    if (backAdornImage == nil) {
        NSSize size = NSMakeSize(25.0, 13.0);
        NSBezierPath *path;
        
        backAdornImage = [[NSImage alloc] initWithSize:size];
        [backAdornImage lockFocus];
        [[NSGraphicsContext currentContext] saveGraphicsState];
        [[NSColor colorWithCalibratedWhite:0.1 alpha:1.0] setFill];
        path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(16.0, 2.5)];
        [path lineToPoint:NSMakePoint(7.5, 7.0)];
        [path lineToPoint:NSMakePoint(16.0, 11.5)];
        [path closePath];
        [path fill];
        [[NSGraphicsContext currentContext] restoreGraphicsState];
        [backAdornImage unlockFocus];
        [backAdornImage setName:@"BackAdorn"];
        
        forwardAdornImage = [[NSImage alloc] initWithSize:size];
        [forwardAdornImage lockFocus];
        [[NSGraphicsContext currentContext] saveGraphicsState];
        [[NSColor colorWithCalibratedWhite:0.1 alpha:1.0] setFill];
        path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(9.0, 2.5)];
        [path lineToPoint:NSMakePoint(17.5, 7.0)];
        [path lineToPoint:NSMakePoint(9.0, 11.5)];
        [path closePath];
        [path fill];
        [[NSGraphicsContext currentContext] restoreGraphicsState];
        [forwardAdornImage unlockFocus];
        [forwardAdornImage setName:@"ForwardAdorn"];
        
        reloadAdornImage = [[NSImage alloc] initWithSize:size];
        [reloadAdornImage lockFocus];
        [[NSGraphicsContext currentContext] saveGraphicsState];
        [[NSColor colorWithCalibratedWhite:0.1 alpha:1.0] set];
        path = [NSBezierPath bezierPath];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(12.0, 6.0) radius:4.0 startAngle:0.0 endAngle:90.0 clockwise:YES];
        [path setLineWidth:2.0];
        [path stroke];
        path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(12.0, 12.5)];
        [path lineToPoint:NSMakePoint(17.0, 9.5)];
        [path lineToPoint:NSMakePoint(12.0, 7.0)];
        [path closePath];
        [path fill];
        [[NSGraphicsContext currentContext] restoreGraphicsState];
        [reloadAdornImage unlockFocus];
        [reloadAdornImage setName:@"ReloadAdorn"];
        
        stopAdornImage = [[NSImage alloc] initWithSize:size];
        [stopAdornImage lockFocus];
        [[NSGraphicsContext currentContext] saveGraphicsState];
        [[NSColor colorWithCalibratedWhite:0.1 alpha:1.0] setStroke];
        path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(8.0, 11.0)];
        [path lineToPoint:NSMakePoint(16.0, 3.0)];
        [path moveToPoint:NSMakePoint(8.0, 3.0)];
        [path lineToPoint:NSMakePoint(16.0, 11.0)];
        [path setLineWidth:2.5];
        [path setLineCapStyle:NSRoundLineCapStyle];
        [path stroke];
        [[NSGraphicsContext currentContext] restoreGraphicsState];
        [stopAdornImage unlockFocus];
        [stopAdornImage setName:@"StopAdorn"];
    }
}

- (id)initWithGroup:(BDSKWebGroup *)aGroup document:(BibDocument *)aDocument {
    if (self = [super init]) {
        [self setGroup:aGroup];
        document = aDocument;
    }
    return self;
}

- (NSString *)windowNibName { return @"BDSKWebGroupView"; }

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [group release];
    [undoManager release];
    [super dealloc];
}

- (void)windowDidLoad {
    [collapsibleView setMinSize:[collapsibleView frame].size];
    [collapsibleView setCollapseEdges:BDSKMaxXEdgeMask | BDSKMaxYEdgeMask];
    [view setEdges:BDSKMinXEdgeMask | BDSKMaxXEdgeMask | BDSKMaxYEdgeMask];
    [view setColor:[NSColor colorWithCalibratedWhite:0.6 alpha:1.0] forEdge:NSMaxYEdge];
    [webEdgeView setEdges:BDSKEveryEdgeMask];
    NSRect frame = [backForwardButton frame];
    frame.size.height = 25.0;
    [backForwardButton setFrame:frame];
    if ([backForwardButton respondsToSelector:@selector(setSegmentStyle:)])
        [backForwardButton setSegmentStyle:NSSegmentStyleTexturedRounded];
    [stopOrReloadButton setImagePosition:NSImageOnly];
    [stopOrReloadButton setImage:[NSImage imageNamed:@"ReloadAdorn"]];
    [webView setEditingDelegate:self];
    
}

- (NSView *)view {
    [self window];
    return view;
}

- (NSView *)webView {
    [self window];
    return webEdgeView;
}

- (BDSKWebGroup *)group {
    return group;
}

- (void)setGroup:(BDSKWebGroup *)newGroup {
    if (group != newGroup) {
        [group release];
        group = [newGroup retain];
    }
}

- (NSString *)URLString {
    [self window];
    return [urlField stringValue];
}

- (void)setURLString:(NSString *)newURLString {
    [self window];
    [urlField setStringValue:newURLString];
    [self changeURL:urlField];
}

- (void)loadURL:(NSURL *)theURL {
    if (theURL && [[[[[webView mainFrame] dataSource] request] URL] isEqual:theURL] == NO)
        [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:theURL]];
}

- (IBAction)changeURL:(id)sender {
    NSString *newURLString = [sender stringValue];
    
    if ([NSString isEmptyString:newURLString]) return;
    
    NSURL *theURL = [NSURL URLWithString:newURLString];
    if ([theURL scheme] == nil)
        theURL = [NSURL URLWithString:[@"http://" stringByAppendingString:newURLString]];
    
    if (theURL == nil) return;
    
    [self loadURL:[NSURL URLWithString:newURLString]];
}

- (IBAction)goBackForward:(id)sender {
    if([sender selectedSegment] == 0)
        [webView goBack:sender];
    else
        [webView goForward:sender];
}

- (IBAction)stopOrReloadAction:(id)sender {
	if ([group isRetrieving]) {
		[webView stopLoading:sender];
	} else {
		[webView reload:sender];
	}
}

- (IBAction)addBookmark:(id)sender {
    [webView addBookmark:sender];
}

- (IBAction)bookmarkLink:(id)sender {
	NSDictionary *element = (NSDictionary *)[sender representedObject];
	NSString *URLString = [(NSURL *)[element objectForKey:WebElementLinkURLKey] absoluteString];
	NSString *title = [element objectForKey:WebElementLinkLabelKey] ?: [URLString lastPathComponent];
	
    [[BDSKBookmarkController sharedBookmarkController] addBookmarkWithUrlString:URLString proposedName:title modalForWindow:[webView window]];
}

- (IBAction)openInDefaultBrowser:(id)sender {
    NSDictionary *element = (NSDictionary *)[sender representedObject];
	NSURL *theURL = [element objectForKey:WebElementLinkURLKey];
    if (theURL)
        [[NSWorkspace sharedWorkspace] openLinkedURL:theURL];
}

- (void)setRetrieving:(BOOL)retrieving {
    [group setRetrieving:retrieving];
    [backForwardButton setEnabled:[webView canGoBack] forSegment:0];
    [backForwardButton setEnabled:[webView canGoForward] forSegment:1];
    [stopOrReloadButton setEnabled:YES];
    if (retrieving) {
        [stopOrReloadButton setImage:[NSImage imageNamed:@"StopAdorn"]];
        [stopOrReloadButton setToolTip:NSLocalizedString(@"Cancel download", @"Tool tip message")];
        [stopOrReloadButton setKeyEquivalent:@"."];
    } else {
        [stopOrReloadButton setImage:[NSImage imageNamed:@"ReloadAdorn"]];
        [stopOrReloadButton setToolTip:NSLocalizedString(@"Reload page", @"Tool tip message")];
        [stopOrReloadButton setKeyEquivalent:@"r"];
    }
}

#pragma mark WebFrameLoadDelegate protocol

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame{
    
    if (frame == [sender mainFrame]) {
        
        OBASSERT(loadingWebFrame == nil);
        
        [self setRetrieving:YES];
        [group setPublications:nil];
        loadingWebFrame = frame;
        
        NSString *url = [[[[frame provisionalDataSource] request] URL] absoluteString];
        [urlField setStringValue:url];
        
    } else if (loadingWebFrame == nil) {
        
        [self setRetrieving:YES];
        loadingWebFrame = frame;
        
    }
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame{

	NSURL *url = [[[frame dataSource] request] URL];
    DOMDocument *domDocument = [frame DOMDocument];
    
    NSError *error = nil;
    NSArray *newPubs = [BDSKWebParser itemsFromDocument:domDocument fromURL:url ofType:BDSKUnknownWebType error:&error];
    if (nil == newPubs) {
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
            int type = [string contentStringType];
            if(type != BDSKUnknownStringType)
                newPubs = [document publicationsForString:string type:type verbose:NO error:&error];
        }
        if (nil == newPubs) {
            // !!! logs are here to help diagnose problems that users are reporting
            NSLog(@"-[%@ %@] %@", [self class], NSStringFromSelector(_cmd), error);
            NSLog(@"loaded MIME type %@", [[dataSource mainResource] MIMEType]);
            // !!! what to do here? if user clicks on a PDF, we're loading application/pdf, which is clearly not an error from the user perspective...so should the error only be presented for text/plain?
            //[NSApp presentError:error];
        }
    }
        
    if (frame == loadingWebFrame) {
        [self setRetrieving:NO];
        [group addPublications:newPubs ?: [NSArray array]];
        loadingWebFrame = nil;
    } else {
        [group addPublications:newPubs ?: [NSArray array]];
    }
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame{
    if (frame == loadingWebFrame) {
        [self setRetrieving:NO];
        [group addPublications:nil];
        loadingWebFrame = nil;
    }
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame{
    if (frame == loadingWebFrame) {
        [self setRetrieving:NO];
        [group addPublications:nil];
        loadingWebFrame = nil;
    }
    // !!! logs are here to help diagnose problems that users are reporting
    NSLog(@"-[%@ %@] %@", [self class], NSStringFromSelector(_cmd), error);
    [NSApp presentError:error];
}

- (void)webView:(WebView *)sender didReceiveServerRedirectForProvisionalLoadForFrame:(WebFrame *)frame{
    if (frame == loadingWebFrame){ 
        NSString *url = [[[[frame provisionalDataSource] request] URL] absoluteString];
        [urlField setStringValue:url];
    }
}


#pragma mark WebUIDelegate protocol

- (void)setStatus:(NSString *)text {
    if ([NSString isEmptyString:text])
        [document updateStatus];
    else 
        [document setStatus:text];
}

- (void)webView:(WebView *)sender setStatusText:(NSString *)text {
    [self setStatus:text];
}

- (void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation modifierFlags:(unsigned int)modifierFlags {
    NSURL *aLink = [elementInformation objectForKey:WebElementLinkURLKey];
    [self setStatus:[aLink absoluteString]];
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems;
{
	NSMutableArray *menuItems = [NSMutableArray arrayWithArray:defaultMenuItems];
	NSMenuItem *item;
    
    // @@ we may want to add support for some of these (downloading), but it's confusing to have them in the menu for now
    NSArray *itemsToRemove = [NSArray arrayWithObjects:[NSNumber numberWithInt:WebMenuItemTagOpenLinkInNewWindow], [NSNumber numberWithInt:WebMenuItemTagDownloadLinkToDisk], [NSNumber numberWithInt:WebMenuItemTagOpenImageInNewWindow], [NSNumber numberWithInt:WebMenuItemTagDownloadImageToDisk], [NSNumber numberWithInt:WebMenuItemTagOpenFrameInNewWindow], nil];
    NSNumber *n;
    NSEnumerator *removeEnum = [itemsToRemove objectEnumerator];
    while (n = [removeEnum nextObject]) {
        unsigned int toRemove = [[menuItems valueForKey:@"tag"] indexOfObject:n];
        if (toRemove != NSNotFound)
            [menuItems removeObjectAtIndex:toRemove];
    }
	
    unsigned int i = [[menuItems valueForKey:@"tag"] indexOfObject:[NSNumber numberWithInt:WebMenuItemTagCopyLinkToClipboard]];
    
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
    [item setTarget:webView];
    [item setRepresentedObject:element];
    [menuItems addObject:[item autorelease]];
    
	return menuItems;
}

#pragma mark WebEditingDelegate protocol

// this is needed because WebView uses the document's undo manager by default, rather than the one from the window.
// I consider this a bug
- (NSUndoManager *)undoManagerForWebView:(WebView *)webView {
    if (undoManager == nil)
        undoManager = [[NSUndoManager alloc] init];
    return undoManager;
}

@end

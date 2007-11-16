//
//  BDSKWebGroupViewController.m
//  Bibdesk
//
//  Created by Michael McCracken on 1/26/07.

/*
 This software is Copyright (c) 2007
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
#import "BibDocument.h"
#import "BDSKBookmarkController.h"


@implementation BDSKWebGroupViewController

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
    [super dealloc];
}

- (void)awakeFromNib {
    [view setMinSize:[view frame].size];
    [edgeView setEdges:BDSKMinXEdgeMask | BDSKMaxXEdgeMask | BDSKMaxYEdgeMask];
    [edgeView setColor:[NSColor colorWithCalibratedWhite:0.6 alpha:1.0] forEdge:NSMaxYEdge];
    [webEdgeView setEdges:BDSKEveryEdgeMask];
    [backButton setImagePosition:NSImageOnly];
    [backButton setImage:[NSImage imageNamed:@"back_small"]];
    [forwardButton setImagePosition:NSImageOnly];
    [forwardButton setImage:[NSImage imageNamed:@"forward_small"]];
    [stopOrReloadButton setImagePosition:NSImageOnly];
    [stopOrReloadButton setImage:[NSImage imageNamed:@"reload_small"]];
}

- (void)handleWebGroupUpdatedNotification:(NSNotification *)notification{
    // ?
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
        if (group)
            [[NSNotificationCenter defaultCenter] removeObserver:self name:BDSKWebGroupUpdatedNotification object:group];
        
        [group release];
        group = [newGroup retain];
        
        if (group)
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWebGroupUpdatedNotification:) name:BDSKWebGroupUpdatedNotification object:group];
    }
}

- (void)loadURL:(NSURL *)theURL {
    if (theURL && [[[[[webView mainFrame] dataSource] request] URL] isEqual:theURL] == NO)
        [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:theURL]];
}

- (IBAction)changeURL:(id)sender {
    NSString *newURLString = [sender stringValue];
    
    if ([NSString isEmptyString:newURLString]) return;
    
    if (! [newURLString hasPrefix:@"http://"]){
        newURLString = [NSString stringWithFormat:@"http://%@", newURLString];
    }
    [self loadURL:[NSURL URLWithString:newURLString]];
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

- (void)setRetrieving:(BOOL)retrieving {
    [group setRetrieving:retrieving];
    [backButton setEnabled:[webView canGoBack]];
    [forwardButton setEnabled:[webView canGoForward]];
    [stopOrReloadButton setEnabled:YES];
    if (retrieving) {
        [stopOrReloadButton setImage:[NSImage imageNamed:@"stop_small"]];
        [stopOrReloadButton setToolTip:NSLocalizedString(@"Cancel download", @"Tool tip message")];
        [stopOrReloadButton setKeyEquivalent:@""];
    } else {
        [stopOrReloadButton setImage:[NSImage imageNamed:@"reload_small"]];
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
    NSArray *newPubs = [BDSKWebParser itemsFromDocument:domDocument fromURL:url error:&error];
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
                newPubs = [document newPublicationsForString:string type:type verbose:NO error:&error];
        }
        if (nil == newPubs) {
#warning remove for release
            // !!! logs are here to help diagnose problems that users are reporting
            NSLog(@"-[%@ %@] %@", [self class], NSStringFromSelector(_cmd), error);
            [NSApp presentError:error];
        }
    }
        
    if (frame == loadingWebFrame) {
        [self setRetrieving:NO];
        [group addPublications:newPubs ? newPubs : [NSArray array]];
        loadingWebFrame = nil;
    } else {
        [group addPublications:newPubs ? newPubs : [NSArray array]];
    }
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame{
#warning FIXME: is this really a failure?
    // arm: I'm not sure what the provisional load failure implies; from the docs it sounds like things will continue loading, so do we really want to kill things here?  If anyone knows or has a test case for this, please comment.
    if (frame == loadingWebFrame) {
        [self setRetrieving:NO];
        [group addPublications:nil];
        loadingWebFrame = nil;
    }
    // !!! logs are here to help diagnose problems that users are reporting
    NSLog(@"-[%@ %@] %@", [self class], NSStringFromSelector(_cmd), error);
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

@end

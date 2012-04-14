//
//  BDSKWebGroup.m
//  Bibdesk
//
//  Created by Michael McCracken on 1/25/07.
/*
 This software is Copyright (c) 2007-2012
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
#import "BibItem.h"
#import <WebKit/WebKit.h>
#import "BDSKWebParser.h"
#import "BDSKBibTeXParser.h"
#import "BDSKStringParser.h"
#import "BDSKBibDeskProtocol.h"
#import "BibDocument.h"
#import "BibDocument_UI.h"
#import "BibDocument_Groups.h"
#import "BDSKGroupsArray.h"
#import "NSString_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"

#define BDSKOpenNewWindowsForWebGroupInBrowserKey @"BDSKOpenNewWindowsForWebGroupInBrowser"

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
    [webView setHostWindow:nil];
    [webView setDelegate:nil];
    BDSKDESTROY(label);
    BDSKDESTROY(webView);
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

- (BOOL)isRetrieving { return [webView isLoading]; }

- (NSString *)label {
    return [label length] > 0 ? label : NSLocalizedString(@"(Empty)", @"Empty group label");
}

- (void)setLabel:(NSString *)newLabel {
    if (label != newLabel) {
        [label release];
        label = [newLabel retain];
    }
}

- (void)setDocument:(BibDocument *)newDocument{
    [super setDocument:newDocument];
    if (webView)
        [webView setHostWindow:[[[document windowControllers] firstObject] window]];
}

#pragma mark BDSKExternalGroup overrides

// web groups don't initiate loading themselves
- (BOOL)shouldRetrievePublications { return NO; }

#pragma mark Accessors

- (BDSKWebView *)webView {
    if (webView == nil) {
        webView = [[BDSKWebView alloc] init];
        [webView setDelegate:self];
        [webView setHostWindow:[[[document windowControllers] firstObject] window]];
    }
    return webView;
}

- (BOOL)isWebViewLoaded {
    return webView != nil;
}

- (NSURL *)URL {
    return [webView URL];
}

- (void)setURL:(NSURL *)newURL {
    if (newURL)
        [[self webView] setURL:newURL];
}

#pragma mark BDSKWebViewDelegate protocol

- (void)webView:(WebView *)sender setTitle:(NSString *)title {
    [self setLabel:title];
}

- (void)webView:(WebView *)sender setStatusText:(NSString *)text {
    if ([NSString isEmptyString:text])
        [document updateStatus];
    else
        [document setStatus:text];
}

- (WebView *)webViewCreateWebView:(WebView *)sender {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKOpenNewWindowsForWebGroupInBrowserKey])
        return nil;
    BDSKWebGroup *group = [[[BDSKWebGroup alloc] init] autorelease];
    [[document groups] addWebGroup:group];
    return [group webView];
}

- (void)webViewShow:(WebView *)sender {
    [document selectGroup:self];
}

- (void)webViewClose:(WebView *)sender {
    [document removeGroups:[NSArray arrayWithObject:self]];
}

- (void)webView:(WebView *)sender didStartLoadForFrame:(WebFrame *)frame {
    if (frame == [sender mainFrame])
        [self setPublications:nil];
    else
        [self addPublications:nil];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
	NSURL *url = [[[frame dataSource] request] URL];
    DOMDocument *domDocument = [frame DOMDocument];
    
    NSError *error = nil;
    NSArray *newPubs = [BDSKWebParser itemsFromDocument:domDocument fromURL:url error:&error];
    if ([newPubs count] == 0) {
        WebDataSource *dataSource = [frame dataSource];
        NSString *MIMEType = [[dataSource mainResource] MIMEType];
        if ([MIMEType isEqualToString:@"text/plain"]) { 
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
            if (type == BDSKBibTeXStringType)
                newPubs = [BDSKBibTeXParser itemsFromString:string owner:nil isPartialData:NULL error:&error];
            else if (type == BDSKNoKeyBibTeXStringType)
                newPubs = [BDSKBibTeXParser itemsFromString:[string stringWithPhoneyCiteKeys:[BibItem defaultCiteKey]] owner:nil isPartialData:NULL error:&error];
            else if (type != BDSKUnknownStringType)
                newPubs = [BDSKStringParser itemsFromString:string ofType:type error:&error];
        }
        else if (nil == newPubs && [MIMEType hasPrefix:@"text/"]) {
            // !!! logs are here to help diagnose problems that users are reporting
            // but unsupported web pages are far too common, we don't want to flood the console
            if ([error isLocalErrorWithCode:kBDSKWebParserUnsupported] == NO)
                NSLog(@"-[%@ %@] %@", [self class], NSStringFromSelector(_cmd), error);
            //NSLog(@"loaded MIME type %@", [[dataSource mainResource] MIMEType]);
            // !!! what to do here? if user clicks on a PDF, we're loading application/pdf, which is clearly not an error from the user perspective...so should the error only be presented for text/plain?
            //[NSApp presentError:error];
        }
    }
    
    [self addPublications:newPubs ?: [NSArray array]];
}

- (void)webView:(WebView *)sender didFailLoadForFrame:(WebFrame *)frame {
    [self addPublications:nil];
}

@end

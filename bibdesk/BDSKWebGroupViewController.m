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
#import "BDSKBibDeskProtocol.h"
#import "BDSKCollapsibleView.h"
#import "BDSKEdgeView.h"
#import "BDSKDragTextField.h"
#import "BDSKIconTextFieldCell.h"
#import "BDSKFieldEditor.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "BibDocument.h"
#import "BibDocument_UI.h"
#import "BDSKBookmarkController.h"
#import "BDSKBookmark.h"
#import "NSMenu_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import "NSString_BDSKExtensions.h"

#define MAX_HISTORY 50

// workaround for loading a URL from a javasecript window.open event http://stackoverflow.com/questions/270458/cocoa-webkit-having-window-open-javascipt-links-opening-in-an-instance-of-safa
@interface BDSKNewWebWindowHandler : NSObject {
    WebView *webView;
}
- (WebView *)webView;
@end

#pragma mark -

@implementation BDSKWebGroupViewController

+ (void)initialize {
    BDSKINITIALIZE;
    
	// register for bibdesk: protocol, so we can display a help page on start
	[NSURLProtocol registerClass:[BDSKBibDeskProtocol class]];
	[WebView registerURLSchemeAsLocal:BDSKBibDeskProtocolName];	
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
    [downloads makeObjectsPerformSelector:@selector(cancel)];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    BDSKDESTROY(group);
    BDSKDESTROY(undoManager);
    BDSKDESTROY(downloads);
    BDSKDESTROY(fieldEditor);
    BDSKDESTROY(newWindowHandler);
    [super dealloc];
}

- (void)handleApplicationWillTerminateNotification:(NSNotification *)note {
    [downloads makeObjectsPerformSelector:@selector(cancel)];
    [downloads removeAllObjects];
}

- (void)setRetrieving:(BOOL)retrieving {
    [group setRetrieving:retrieving];
    [backForwardButton setEnabled:[webView canGoBack] forSegment:0];
    [backForwardButton setEnabled:[webView canGoForward] forSegment:1];
    [stopOrReloadButton setEnabled:YES];
    if (retrieving) {
        [stopOrReloadButton setImage:[NSImage imageNamed:NSImageNameStopProgressTemplate]];
        [stopOrReloadButton setToolTip:NSLocalizedString(@"Cancel download", @"Tool tip message")];
        [stopOrReloadButton setKeyEquivalent:@"."];
    } else {
        [stopOrReloadButton setImage:[NSImage imageNamed:NSImageNameRefreshTemplate]];
        [stopOrReloadButton setToolTip:NSLocalizedString(@"Reload page", @"Tool tip message")];
        [stopOrReloadButton setKeyEquivalent:@"r"];
    }
}

- (void)windowDidLoad {
    // navigation views
    [collapsibleView setMinSize:[collapsibleView frame].size];
    [collapsibleView setCollapseEdges:BDSKMaxXEdgeMask | BDSKMaxYEdgeMask];
    
    [view setEdges:BDSKMinYEdgeMask];
    [view setColor:[view colorForEdge:NSMaxYEdge] forEdge:NSMinYEdge];
    
    backMenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] init] autorelease];
    [backMenu setDelegate:self];
    [backForwardButton setMenu:backMenu forSegment:0];
    forwardMenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] init] autorelease];
    [forwardMenu setDelegate:self];
    [backForwardButton setMenu:forwardMenu forSegment:1];
    
    // update the buttons, we should not be retrieving at this point
    [self setRetrieving:NO];
    
    id oldCell = [urlField cell];
    BDSKConcreteIconTextFieldCell *cell = [[BDSKConcreteIconTextFieldCell alloc] initTextCell:[oldCell stringValue]];
    [cell setEditable:[oldCell isEditable]];
    [cell setSelectable:[oldCell isSelectable]];
    [cell setEnabled:[oldCell isEnabled]];
    [cell setScrollable:[oldCell isScrollable]];
    [cell setWraps:[oldCell wraps]];
    [cell setAlignment:[oldCell alignment]];
    [cell setLineBreakMode:[oldCell lineBreakMode]];
    [cell setBezeled:[oldCell isBezeled]];
    [cell setBezelStyle:[oldCell bezelStyle]];
    [cell setTarget:[oldCell target]];
    [cell setAction:[oldCell action]];
    [cell setSendsActionOnEndEditing:[oldCell sendsActionOnEndEditing]];
    [cell setPlaceholderString:[oldCell placeholderString]];
    [cell setIcon:[NSImage missingFileImage]];
    [urlField setCell:cell];
    [cell release];
    
    [urlField registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, BDSKWeblocFilePboardType, nil]];
    
    // webview
    [webView setEditingDelegate:self];
    [self loadURL: BDSKBibDeskWebGroupURL];
	
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleApplicationWillTerminateNotification:)
                                                 name:NSApplicationWillTerminateNotification
                                               object:NSApp];
}

- (NSView *)view {
    [self window];
    return view;
}

- (NSView *)webView {
    [self window];
    return webView;
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
    if (theURL && [[[[[webView mainFrame] dataSource] request] URL] isEqual:theURL] == NO) {
        [(BDSKConcreteIconTextFieldCell *)[urlField cell] setIcon:[NSImage missingFileImage]];
        [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:theURL]];
    }
}

- (IBAction)changeURL:(id)sender {
    NSString *newURLString = [sender stringValue];
    
    if ([NSString isEmptyString:newURLString]) return;
    
    NSURL *theURL = [NSURL URLWithString:newURLString];
    if ([theURL scheme] == nil)
        theURL = [NSURL URLWithString:[@"http://" stringByAppendingString:newURLString]];
    
    if (theURL == nil) return;
    
    [self loadURL:theURL];
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

- (IBAction)downloadLink:(id)sender {
	NSDictionary *element = (NSDictionary *)[sender representedObject];
	NSURL *linkURL = (NSURL *)[element objectForKey:WebElementLinkURLKey];
	NSURLDownload *download = linkURL ? [[WebDownload alloc] initWithRequest:[NSURLRequest requestWithURL:linkURL] delegate:self] : nil;
    
    if (download) {
        if (downloads == nil)
            downloads = [[NSMutableArray alloc] init];
        [downloads addObject:download];
        [download release];
    } else
        NSBeep();
}

- (IBAction)openInDefaultBrowser:(id)sender {
    NSDictionary *element = (NSDictionary *)[sender representedObject];
	NSURL *theURL = [element objectForKey:WebElementLinkURLKey];
    if (theURL)
        [[NSWorkspace sharedWorkspace] openLinkedURL:theURL];
}

- (void)goBackForwardInHistory:(id)sender {
    WebHistoryItem *item = [sender representedObject];
    if (item)
        [webView goToBackForwardItem:item];
}

#pragma mark NSMenu delegate protocol

- (void)menuNeedsUpdate:(NSMenu *)menu {
    WebBackForwardList *backForwardList = [webView backForwardList];
    id items = nil;
    if (menu == backMenu)
        items = [[backForwardList backListWithLimit:MAX_HISTORY] reverseObjectEnumerator];
    else if (menu == forwardMenu)
        items = [backForwardList forwardListWithLimit:MAX_HISTORY];
    else
        return;
    [menu removeAllItems];
    for (WebHistoryItem *item in items) {
        NSMenuItem *menuItem = [menu addItemWithTitle:([item title] ?: @"") action:@selector(goBackForwardInHistory:) keyEquivalent:@""];
        [menuItem setTarget:self];
        [menuItem setRepresentedObject:item];
    }
}

#pragma mark TextField delegates

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject {
    if (anObject == urlField) {
        if (fieldEditor == nil) {
            fieldEditor = [[BDSKFieldEditor alloc] init];
            // we could support dragging here as well, but NSTextView already handles URLs, and it's probably better not to commit when we're editing
        }
        return fieldEditor;
	}
    return nil;
}

- (NSDragOperation)dragTextField:(BDSKDragTextField *)textField validateDrop:(id <NSDraggingInfo>)sender {
    if ([sender draggingSource] != textField && 
        [[sender draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObjects:BDSKWeblocFilePboardType, NSURLPboardType, nil]])
        return NSDragOperationEvery;
    return NSDragOperationNone;
}

- (BOOL)dragTextField:(BDSKDragTextField *)textField acceptDrop:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
	NSString *dragType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKWeblocFilePboardType, NSURLPboardType, nil]];
    NSURL *url = nil;
    
    if ([dragType isEqualToString:NSURLPboardType])
        url = [NSURL URLFromPasteboard:pboard];
    else if ([dragType isEqualToString:BDSKWeblocFilePboardType])
        url = [NSURL URLWithString:[pboard stringForType:BDSKWeblocFilePboardType]];
    if (url) {
        [self setURLString:[url absoluteString]];
        return YES;
    }
    return NO;
}

- (BOOL)dragTextField:(BDSKDragTextField *)textField writeDataToPasteboard:(NSPasteboard *)pboard {
    NSString *urlString = [self URLString];
    if ([NSString isEmptyString:urlString] == NO) {
        NSURL *url = [NSURL URLWithString:urlString];
        if (url) {
            [pboard declareTypes:[NSArray arrayWithObjects:NSURLPboardType, nil] owner:nil];
            [url writeToPasteboard:pboard];
            return YES;
        }
    }
    return NO;
}

- (BOOL)control:(NSControl *)control textViewShouldAutoComplete:(NSTextView *)textView {
    return control == urlField;
}

- (NSRange)control:(NSControl *)control textView:(NSTextView *)textView rangeForUserCompletion:(NSRange)charRange {
    if (control == urlField) {
        // always complete the whole string
        return NSMakeRange(0, [[textView string] length]);
    } else {
        return charRange;
    }
}

static inline void addMatchesFromBookmarks(NSMutableArray *bookmarks, BDSKBookmark *bookmark, NSString *string) {
    if ([bookmark bookmarkType] == BDSKBookmarkTypeBookmark) {
        NSURL *url = [bookmark URL];
        NSString *urlString = [url absoluteString];
        NSUInteger loc = [urlString rangeOfString:string options:NSCaseInsensitiveSearch].location;
        if (loc == NSNotFound && [string rangeOfString:@"//:"].length == 0)
            loc = [urlString rangeOfString:[@"www." stringByAppendingString:string] options:NSCaseInsensitiveSearch].location;
        if (loc <= [[url scheme] length] + 3)
            [bookmarks addObject:urlString];
    } else if ([bookmark bookmarkType] == BDSKBookmarkTypeFolder) {
        NSUInteger i, iMax = [bookmark countOfChildren];
        for (i = 0; i < iMax; i++)
            addMatchesFromBookmarks(bookmarks, [bookmark objectInChildrenAtIndex:i], string);
    }
}

- (NSArray *)control:(NSControl *)control textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)anIndex {
    if (control == urlField) {
        NSMutableArray *matches = [NSMutableArray array];
        NSString *string = [textView string];
        if ([@"http://" hasPrefix:string] == NO && [@"https://" hasPrefix:string] == NO)
            addMatchesFromBookmarks(matches, [[BDSKBookmarkController sharedBookmarkController] bookmarkRoot], string);
        return matches;
    } else {
        return words;
    }
}

#pragma mark WebFrameLoadDelegate protocol

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame{
    
    if (frame == [sender mainFrame]) {
        
        BDSKASSERT(loadingWebFrame == nil);
        
        [self setRetrieving:YES];
        [group setPublications:nil];
        loadingWebFrame = frame;
        
        WebDataSource *dataSource = [frame provisionalDataSource];
        if ([dataSource unreachableURL] == nil) {
            NSString *url = [[[dataSource request] URL] absoluteString];
            [urlField setStringValue:url];
        }
        
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
            NSInteger type = [string contentStringType];
            if(type != BDSKUnknownStringType)
                newPubs = [document publicationsForString:string type:type verbose:NO error:&error];
        }
        if (nil == newPubs) {
            // !!! logs are here to help diagnose problems that users are reporting
            //NSLog(@"-[%@ %@] %@", [self class], NSStringFromSelector(_cmd), error);
            //NSLog(@"loaded MIME type %@", [[dataSource mainResource] MIMEType]);
            // !!! what to do here? if user clicks on a PDF, we're loading application/pdf, which is clearly not an error from the user perspective...so should the error only be presented for text/plain?
            //[NSApp presentError:error];
        }
    }
    
    if (frame == [sender mainFrame]) {
        if ([[(BDSKConcreteIconTextFieldCell *)[urlField cell] icon] isEqual:[NSImage missingFileImage]])
            [(BDSKConcreteIconTextFieldCell *)[urlField cell] setIcon:[NSImage imageNamed:@"Bookmark"]];
    }
    
    if (frame == loadingWebFrame) {
        [self setRetrieving:NO];
        loadingWebFrame = nil;
    }
    [group addPublications:newPubs ?: [NSArray array]];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame{
    if (frame == loadingWebFrame) {
        [self setRetrieving:NO];
        [group addPublications:nil];
        loadingWebFrame = nil;
    }
    
    // !!! logs are here to help diagnose problems that users are reporting
    NSLog(@"-[%@ %@] %@", [self class], NSStringFromSelector(_cmd), error);
    
    NSURL *url = [[[frame provisionalDataSource] request] URL];
    NSString *errorHTML = [NSString stringWithFormat:@"<html><body><h1>%@</h1></body></html>", [error localizedDescription]];
    [frame loadAlternateHTMLString:errorHTML baseURL:nil forUnreachableURL:url];
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame{
    [self webView:sender didFailLoadWithError:error forFrame:frame];
}

- (void)webView:(WebView *)sender didReceiveServerRedirectForProvisionalLoadForFrame:(WebFrame *)frame{
    if (frame == [sender mainFrame]) { 
        NSString *url = [[[[frame provisionalDataSource] request] URL] absoluteString];
        [urlField setStringValue:url];
    }
}

- (void)webView:(WebView *)sender didReceiveIcon:(NSImage *)image forFrame:(WebFrame *)frame{
    if (frame == [sender mainFrame]) { 
        [(BDSKConcreteIconTextFieldCell *)[urlField cell] setIcon:image];
    }
}

#pragma mark WebPolicyDelegate protocol

- (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id < WebPolicyDecisionListener >)listener {
    [listener ignore];
    [[NSWorkspace sharedWorkspace] openURL:[request URL]];
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

- (void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation modifierFlags:(NSUInteger)modifierFlags {
    NSURL *aLink = [elementInformation objectForKey:WebElementLinkURLKey];
    [self setStatus:[[aLink absoluteString] stringByReplacingPercentEscapes]];
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
    [item setTarget:webView];
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
- (NSUndoManager *)undoManagerForWebView:(WebView *)webView {
    if (undoManager == nil)
        undoManager = [[NSUndoManager alloc] init];
    return undoManager;
}

#pragma mark NSURLDownloadDelegate protocol

- (NSWindow *)downloadWindowForAuthenticationSheet:(WebDownload *)download {
    return [document windowForSheet];
}

- (void)download:(NSURLDownload *)download decideDestinationWithSuggestedFilename:(NSString *)filename {
	NSString *extension = [filename pathExtension];
   
	NSSavePanel *sPanel = [NSSavePanel savePanel];
    if (NO == [extension isEqualToString:@""]) 
		[sPanel setRequiredFileType:extension];
    [sPanel setAllowsOtherFileTypes:YES];
    [sPanel setCanSelectHiddenExtension:YES];
	
    // we need to do this modally, not using a sheet, as the download may otherwise finish on Leopard before the sheet is done
    NSInteger returnCode = [sPanel runModalForDirectory:nil file:filename];
    if (returnCode == NSOKButton) {
        [download setDestination:[sPanel filename] allowOverwrite:YES];
    } else {
        [download cancel];
    }
}

- (BOOL)download:(NSURLDownload *)download shouldDecodeSourceDataOfMIMEType:(NSString *)encodingType {
    return YES;
}

- (void)downloadDidFinish:(NSURLDownload *)download {
    [downloads removeObject:download];
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error {
    [downloads removeObject:download];
        
    NSString *errorDescription = [error localizedDescription] ?: NSLocalizedString(@"An error occured during download.", @"Informative text in alert dialog");
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Download Failed", @"Message in alert dialog when download failed")
                                     defaultButton:nil
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:errorDescription];
    [alert beginSheetModalForWindow:[document windowForSheet]
                      modalDelegate:nil
                     didEndSelector:NULL
                        contextInfo:NULL];
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


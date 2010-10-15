//
//  BDSKWebGroupViewController.m
//  Bibdesk
//
//  Created by Michael McCracken on 1/26/07.

/*
 This software is Copyright (c) 2007-2010
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
#import "BDSKCollapsibleView.h"
#import "BDSKEdgeView.h"
#import "BDSKDragTextField.h"
#import "BDSKIconTextFieldCell.h"
#import "BDSKFieldEditor.h"
#import "BibDocument.h"
#import "BDSKBookmarkController.h"
#import "BDSKBookmark.h"
#import "NSMenu_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import "NSString_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"

#define MAX_HISTORY 50

@implementation BDSKWebGroupViewController

- (id)init {
    self = [super initWithNibName:@"BDSKWebGroupView" bundle:nil];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [urlField setDelegate:nil];
    BDSKDESTROY(fieldEditor);
    [super dealloc];
}

- (void)handleGroupUpdatedNotification:(NSNotification *)note {
    [backForwardButton setEnabled:[[self webView] canGoBack] forSegment:0];
    [backForwardButton setEnabled:[[self webView] canGoForward] forSegment:1];
    [stopOrReloadButton setEnabled:YES];
    if ([[self group] isRetrieving]) {
        [stopOrReloadButton setImage:[NSImage imageNamed:NSImageNameStopProgressTemplate]];
        [stopOrReloadButton setToolTip:NSLocalizedString(@"Cancel download", @"Tool tip message")];
        [stopOrReloadButton setKeyEquivalent:@"."];
    } else {
        [stopOrReloadButton setImage:[NSImage imageNamed:NSImageNameRefreshTemplate]];
        [stopOrReloadButton setToolTip:NSLocalizedString(@"Reload page", @"Tool tip message")];
        [stopOrReloadButton setKeyEquivalent:@"r"];
    }
}

- (void)awakeFromNib {
    // navigation views
    [collapsibleView setMinSize:[collapsibleView frame].size];
    [collapsibleView setCollapseEdges:BDSKMaxXEdgeMask | BDSKMaxYEdgeMask];
    
    BDSKEdgeView *edgeView = (BDSKEdgeView *)[self view];
    [edgeView setEdges:BDSKMinYEdgeMask];
    [edgeView setColor:[edgeView colorForEdge:NSMaxYEdge] forEdge:NSMinYEdge];
    
    backMenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] init] autorelease];
    [backMenu setDelegate:self];
    [backForwardButton setMenu:backMenu forSegment:0];
    forwardMenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] init] autorelease];
    [forwardMenu setDelegate:self];
    [backForwardButton setMenu:forwardMenu forSegment:1];
    
    // update the buttons, we should not be retrieving at this point
    [self handleGroupUpdatedNotification:nil];
    
    [urlField registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, BDSKWeblocFilePboardType, nil]];
}

#pragma mark Accessors

- (WebView *)webView {
    return [[self group] webView];
}

- (BDSKWebGroup *)group {
    return [self representedObject];
}

- (void)setGroup:(BDSKWebGroup *)newGroup {
    BDSKWebGroup *oldGroup = [self representedObject];
    if (oldGroup != newGroup) {
        if (oldGroup) {
            [oldGroup setDelegate:nil];
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:BDSKExternalGroupUpdatedNotification
                                                          object:oldGroup];
        }
        [self setRepresentedObject:newGroup];
        if (newGroup) {
            [self handleGroupUpdatedNotification:nil];
            [self webGroup:newGroup setURL:[newGroup URL]];
            [self webGroup:newGroup setIcon:[[newGroup webView] mainFrameIcon]];
            [newGroup setDelegate:self];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(handleGroupUpdatedNotification:)
                                                         name:BDSKExternalGroupUpdatedNotification
                                                       object:newGroup];
        }
    }
}

#pragma mark Actions

- (IBAction)changeURL:(id)sender {
    NSString *newURLString = [sender stringValue];
    
    if ([NSString isEmptyString:newURLString] == NO) {
        NSURL *theURL = [NSURL URLWithStringByNormalizingPercentEscapes:newURLString];
        if ([theURL scheme] == nil) {
            if ([newURLString isAbsolutePath])
                theURL = [NSURL fileURLWithPath:newURLString];
            else
                theURL = [NSURL URLWithStringByNormalizingPercentEscapes:[@"http://" stringByAppendingString:newURLString]];
        }
        [[self group] setURL:theURL];
    }
}

- (IBAction)goBackForward:(id)sender {
    if([sender selectedSegment] == 0)
        [[self webView] goBack:sender];
    else
        [[self webView] goForward:sender];
}

- (IBAction)stopOrReloadAction:(id)sender {
	if ([[self group] isRetrieving]) {
		[[self webView] stopLoading:sender];
	} else {
		[[self webView] reload:sender];
	}
}

- (void)goBackForwardInHistory:(id)sender {
    WebHistoryItem *item = [sender representedObject];
    if (item)
        [[self webView] goToBackForwardItem:item];
}

#pragma mark BDSKWebGroupDelegate protocol

- (void)webGroup:(BDSKWebGroup *)aGroup setIcon:(NSImage *)icon {
    [(BDSKIconTextFieldCell *)[urlField cell] setIcon:icon ?: [NSImage imageNamed:@"Bookmark"]];
}

- (void)webGroup:(BDSKWebGroup *)aGroup setURL:(NSURL *)aURL {
    [urlField setStringValue:[aURL absoluteString] ?: @""];
}

#pragma mark NSMenu delegate protocol

- (void)menuNeedsUpdate:(NSMenu *)menu {
    WebBackForwardList *backForwardList = [[self webView] backForwardList];
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
    NSString *urlString = nil;
    
    if ([dragType isEqualToString:NSURLPboardType])
        urlString = [[NSURL URLFromPasteboard:pboard] absoluteString];
    else if ([dragType isEqualToString:BDSKWeblocFilePboardType])
        urlString = [pboard stringForType:BDSKWeblocFilePboardType];
    if (urlString) {
        [textField setStringValue:urlString];
        [self changeURL:textField];
        return YES;
    }
    return NO;
}

- (BOOL)dragTextField:(BDSKDragTextField *)textField writeDataToPasteboard:(NSPasteboard *)pboard {
    NSURL *url = [[self group] URL];
    if (url) {
        [pboard declareTypes:[NSArray arrayWithObjects:NSURLPboardType, BDSKWeblocFilePboardType, nil] owner:nil];
        [url writeToPasteboard:pboard];
        [pboard setString:[url absoluteString] forType:BDSKWeblocFilePboardType];
        return YES;
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

@end

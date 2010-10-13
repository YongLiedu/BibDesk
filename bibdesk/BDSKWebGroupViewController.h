
//
//  BDSKWebGroupViewController.h
//  Bibdesk
//
//  Created by Michael McCracken on 1/26/07.
/*
 This software is Copyright (c) 2007-2010
 Michael McCracken. All rights reserved.
 
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

#import <Cocoa/Cocoa.h>

@class BDSKCollapsibleView, BDSKEdgeView, BDSKWebGroup, WebView, WebFrame, BDSKDragTextField, BDSKFieldEditor, BDSKNewWebWindowHandler;

@protocol BDSKWebGroupViewControllerDelegate;

@interface BDSKWebGroupViewController : NSViewController <NSMenuDelegate> {
    IBOutlet BDSKCollapsibleView *collapsibleView;
    IBOutlet BDSKDragTextField *urlField;
    IBOutlet WebView *webView;
    IBOutlet NSSegmentedControl *backForwardButton;
    IBOutlet NSButton *stopOrReloadButton;
    
    id <BDSKWebGroupViewControllerDelegate> delegate;
    WebFrame *loadingWebFrame;
    NSUndoManager *undoManager;
    NSMutableArray *downloads;
    NSMenu *backMenu;
    NSMenu *forwardMenu;
    BDSKFieldEditor *fieldEditor;
    BDSKNewWebWindowHandler *newWindowHandler;
}

- (id)initWithGroup:(BDSKWebGroup *)aGroup delegate:(id<BDSKWebGroupViewControllerDelegate>)aDelegate;

- (NSView *)webView;

- (BDSKWebGroup *)group;

- (NSString *)URLString;
- (void)setURLString:(NSString *)newURLString;

- (NSImage *)icon;
- (void)setIcon:(NSImage *)icon;

- (IBAction)changeURL:(id)sender;
- (IBAction)goBackForward:(id)sender;
- (IBAction)stopOrReloadAction:(id)sender;

- (void)addBookmark:(id)sender;

@end


@protocol BDSKWebGroupViewControllerDelegate <NSObject>
- (void)webGroupViewController:(BDSKWebGroupViewController *)controller setStatusText:(NSString *)text;
@end

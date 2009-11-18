//
//  BDSKBookmarkController.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/18/07.
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


@class BDSKBookmark, BDSKOutlineView;

@interface BDSKBookmarkController : NSWindowController <NSOutlineViewDelegate, NSOutlineViewDataSource, NSToolbarDelegate> {
    IBOutlet BDSKOutlineView *outlineView;
    IBOutlet NSWindow *addBookmarkSheet;
    IBOutlet NSTextField *bookmarkField;
    IBOutlet NSPopUpButton *folderPopUp;
    BDSKBookmark *bookmarkRoot;
    NSUndoManager *undoManager;
    NSArray *draggedBookmarks;
    NSMutableDictionary *toolbarItems;
}

+ (id)sharedBookmarkController;

- (BDSKBookmark *)bookmarkRoot;

- (void)addBookmarkWithUrlString:(NSString *)urlString name:(NSString *)name;
- (void)addBookmarkWithUrlString:(NSString *)urlString name:(NSString *)name toFolder:(BDSKBookmark *)folder;
- (void)addBookmarkWithUrlString:(NSString *)urlString proposedName:(NSString *)name modalForWindow:(NSWindow *)window;

- (IBAction)insertBookmark:(id)sender;
- (IBAction)insertBookmarkFolder:(id)sender;
- (IBAction)insertBookmarkSeparator:(id)sender;
- (IBAction)deleteBookmark:(id)sender;

- (IBAction)dismissAddBookmarkSheet:(id)sender;

- (NSUndoManager *)undoManager;

@end

#pragma mark -

@interface WebView (BDSKExtensions)
- (IBAction)addBookmark:(id)sender;
@end

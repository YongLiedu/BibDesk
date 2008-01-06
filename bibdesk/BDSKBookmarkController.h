//
//  BDSKBookmarkController.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/18/07.
/*
 This software is Copyright (c) 2007,2008
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
    BDSKBookmarkTypeBookmark,
    BDSKBookmarkTypeFolder,
    BDSKBookmarkTypeSeparator
};

@class BDSKBookmark;

@interface BDSKBookmarkController : NSWindowController {
    IBOutlet NSOutlineView *outlineView;
    IBOutlet NSWindow *addBookmarkSheet;
    IBOutlet NSTextField *bookmarkField;
    IBOutlet NSPopUpButton *folderPopUp;
    NSMutableArray *bookmarks;
    NSUndoManager *undoManager;
    NSArray *draggedBookmarks;
    NSMutableDictionary *toolbarItems;
}

+ (id)sharedBookmarkController;

- (NSArray *)bookmarks;
- (void)setBookmarks:(NSArray *)newBookmarks;
- (unsigned)countOfBookmarks;
- (id)objectInBookmarksAtIndex:(unsigned)index;
- (void)insertObject:(id)obj inBookmarksAtIndex:(unsigned)index;
- (void)removeObjectFromBookmarksAtIndex:(unsigned)index;

- (void)addBookmarkWithUrlString:(NSString *)urlString name:(NSString *)name;
- (void)addBookmarkWithUrlString:(NSString *)urlString name:(NSString *)name toFolder:(BDSKBookmark *)folder;
- (void)addBookmarkWithUrlString:(NSString *)urlString proposedName:(NSString *)name modalForWindow:(NSWindow *)window;

- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification;
- (void)handleBookmarkWillBeRemovedNotification:(NSNotification *)notification;
- (void)handleBookmarkChangedNotification:(NSNotification *)notification;

- (IBAction)insertBookmark:(id)sender;
- (IBAction)insertBookmarkFolder:(id)sender;
- (IBAction)insertBookmarkSeparator:(id)sender;
- (IBAction)deleteBookmark:(id)sender;

- (IBAction)dismissAddBookmarkSheet:(id)sender;

- (NSString *)uniqueName;

- (NSUndoManager *)undoManager;

- (void)setupToolbar;

@end


@interface BDSKBookmark : NSObject <NSCopying> {
    NSString *urlString;
    NSString *name;
    NSMutableArray *children;
    BDSKBookmark *parent;
    int bookmarkType;
}

- (id)initWithUrlString:(NSString *)aUrlString name:(NSString *)aName;
- (id)initFolderWithName:(NSString *)aName;
- (id)initSeparator;
- (id)initWithDictionary:(NSDictionary *)dictionary;

- (NSDictionary *)dictionaryValue;

- (int)bookmarkType;

- (NSURL *)URL;

- (NSString *)urlString;
- (void)setUrlString:(NSString *)newUrlString;

- (NSString *)name;
- (void)setName:(NSString *)newName;

- (NSImage *)icon;

- (BDSKBookmark *)parent;
- (void)setParent:(BDSKBookmark *)newParent;
- (NSArray *)children;
- (void)insertChild:(BDSKBookmark *)child atIndex:(unsigned int)index;
- (void)addChild:(BDSKBookmark *)child;
- (void)removeChild:(BDSKBookmark *)child;

- (BOOL)isDescendantOf:(BDSKBookmark *)bookmark;
- (BOOL)isDescendantOfArray:(NSArray *)bookmarks;

@end

#pragma mark -

@interface WebView (BDSKExtensions)
- (IBAction)addBookmark:(id)sender;
@end

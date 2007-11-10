//
//  BDSKSearchBookmarkController.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/26/07.
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


enum {
    BDSKSearchBookmarkTypeBookmark,
    BDSKSearchBookmarkTypeFolder,
    BDSKSearchBookmarkTypeSeparator
};

@class BDSKSearchBookmark;

@interface BDSKSearchBookmarkController : NSWindowController {
    IBOutlet NSOutlineView *outlineView;
    NSMutableArray *bookmarks;
    NSArray *draggedBookmarks;
    NSMutableDictionary *toolbarItems;
    NSUndoManager *undoManager;
}

+ (id)sharedBookmarkController;

- (NSArray *)bookmarks;
- (void)setBookmarks:(NSArray *)newBookmarks;
- (unsigned)countOfBookmarks;
- (id)objectInBookmarksAtIndex:(unsigned)index;
- (void)insertObject:(id)obj inBookmarksAtIndex:(unsigned)index;
- (void)removeObjectFromBookmarksAtIndex:(unsigned)index;

- (void)addBookmarkWithInfo:(NSDictionary *)info label:(NSString *)label toFolder:(BDSKSearchBookmark *)folder;

- (IBAction)insertBookmarkFolder:(id)sender;
- (IBAction)insertBookmarkSeparator:(id)sender;
- (IBAction)deleteBookmark:(id)sender;

- (void)saveBookmarks;
- (void)handleSearchBookmarkChangedNotification:(NSNotification *)notification;
- (void)handleSearchBookmarkWillBeRemovedNotification:(NSNotification *)notification;

- (NSUndoManager *)undoManager;

- (void)setupToolbar;

@end


@interface BDSKSearchBookmark : NSObject <NSCopying> {
    NSString *label;
    NSDictionary *info;
    NSMutableArray *children;
    BDSKSearchBookmark *parent;
    int bookmarkType;
}

- (id)initFolderWithChildren:(NSArray *)aChildren label:(NSString *)aLabel;
- (id)initFolderWithLabel:(NSString *)aLabel;
- (id)initSeparator;
- (id)initWithInfo:(NSDictionary *)aDictionary label:(NSString *)aLabel;
- (id)initWithDictionary:(NSDictionary *)dictionary;

- (NSDictionary *)dictionaryValue;

- (int)bookmarkType;

- (NSDictionary *)info;

- (NSString *)label;
- (void)setLabel:(NSString *)newLabel;

- (NSImage *)icon;

- (BDSKSearchBookmark *)parent;
- (void)setParent:(BDSKSearchBookmark *)newParent;
- (NSArray *)children;
- (void)insertChild:(BDSKSearchBookmark *)child atIndex:(unsigned int)index;
- (void)addChild:(BDSKSearchBookmark *)child;
- (void)removeChild:(BDSKSearchBookmark *)child;

- (BOOL)isDescendantOf:(BDSKSearchBookmark *)bookmark;
- (BOOL)isDescendantOfArray:(NSArray *)bookmarks;

@end

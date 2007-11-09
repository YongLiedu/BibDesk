//
//  BDSKBookmarkController.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 18/8/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

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
- (void)addBookmarkWithUrlString:(NSString *)urlString name:(NSString *)name modalForWindow:(NSWindow *)window;

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

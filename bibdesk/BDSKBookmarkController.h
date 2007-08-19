//
//  BDSKBookmarkController.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 18/8/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BDSKBookmarkController : NSWindowController {
    NSMutableArray *bookmarks;
}

+ (id)sharedBookmarkController;

- (NSArray *)bookmarks;
- (void)setBookmarks:(NSArray *)newBookmarks;
- (unsigned)countOfBookmarks;
- (id)objectInBookmarksAtIndex:(unsigned)index;
- (void)insertObject:(id)obj inBookmarksAtIndex:(unsigned)index;
- (void)removeObjectFromBookmarksAtIndex:(unsigned)index;

- (void)addBookmarkWithUrlString:(NSString *)urlString name:(NSString *)name;

- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification;

@end


@interface BDSKBookmark : NSObject {
    NSString *urlString;
    NSString *name;
}

- (id)initWithUrlString:(NSString *)aUrlString name:(NSString *)aName;
- (id)initWithDictionary:(NSDictionary *)dictionary;

- (NSDictionary *)dictionaryValue;

- (NSURL *)URL;

- (NSString *)urlString;
- (void)setUrlString:(NSString *)newUrlString;

- (NSString *)name;
- (void)setName:(NSString *)newName;

@end

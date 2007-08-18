//
//  BDSKBookmarkController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 18/8/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BDSKBookmarkController.h"
#import "NSFileManager_BDSKExtensions.h"


@implementation BDSKBookmarkController

+ (id)sharedBookmarkController {
    id sharedBookmarkController = nil;
    if (sharedBookmarkController == nil) {
        sharedBookmarkController = [[self alloc] init];
    }
    return sharedBookmarkController;
}

- (id)init {
    if (self = [super init]) {
        bookmarks = [[NSMutableArray alloc] init];
		
		NSString *applicationSupportPath = [[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser]; 
		NSString *bookmarksPath = [applicationSupportPath stringByAppendingPathComponent:@"Bookmarks.plist"];
		if ([[NSFileManager defaultManager] fileExistsAtPath:bookmarksPath]) {
			NSEnumerator *bEnum = [[NSArray arrayWithContentsOfFile:bookmarksPath] objectEnumerator];
			NSDictionary *bm;
			
			while(bm = [bEnum nextObject]){
				[bookmarks addObject:[[bm mutableCopy] autorelease]];
			}
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillTerminateNotification:) name:NSApplicationWillTerminateNotification object:nil];
		}
    }
    return self;
}

- (void)dealloc {
    [bookmarks release];
    [super dealloc];
}

- (NSString *)windowNibName { return @"BookmarksWindow"; }

- (void)windowDidLoad {
    [self setWindowFrameAutosaveName:@"BDSKBookmarksWindow"];
}

- (NSArray *)bookmarks {
    return bookmarks;
}

- (void)setBookmarks:(NSArray *)newBookmarks {
    if (bookmarks != newBookmarks) {
        [bookmarks release];
        bookmarks = [newBookmarks mutableCopy];
    }
}

- (unsigned)countOfBookmarks {
    return [bookmarks count];
}

- (id)objectInBookmarksAtIndex:(unsigned)index {
    return [bookmarks objectAtIndex:index];
}

- (void)insertObject:(id)obj inBookmarksAtIndex:(unsigned)index {
    [bookmarks insertObject:obj atIndex:index];
}

- (void)removeObjectFromBookmarksAtIndex:(unsigned)index {
    [bookmarks removeObjectAtIndex:index];
}

- (void)addBookmarkWithURLString:(NSString *)URLString title:(NSString *)title {
    NSMutableDictionary *bookmark = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    URLString, @"URLString", title, @"Title", nil];
    [[self mutableArrayValueForKey:@"bookmarks"] addObject:bookmark];
}

- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification {
	NSString *error = nil;
	NSData *data = [NSPropertyListSerialization dataFromPropertyList:bookmarks
															  format:NSPropertyListXMLFormat_v1_0 
													errorDescription:&error];
	if (error) {
		NSLog(@"Error writing bookmarks: %@", error);
        [error release];
		return;
	}
	
	NSString *applicationSupportPath = [[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser]; 
	NSString *bookmarksPath = [applicationSupportPath stringByAppendingPathComponent:@"Bookmarks.plist"];
	[data writeToFile:bookmarksPath atomically:YES];
}

@end

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
    static id sharedBookmarkController = nil;
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
			NSDictionary *dict;
			
			while(dict = [bEnum nextObject]){
                BDSKBookmark *bookmark = [[BDSKBookmark alloc] initWithDictionary:dict];
				[bookmarks addObject:bookmark];
                [bookmark release];
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

- (void)addBookmarkWithUrlString:(NSString *)urlString name:(NSString *)name {
    BDSKBookmark *bookmark = [[BDSKBookmark alloc] initWithUrlString:urlString name:name];
    [[self mutableArrayValueForKey:@"bookmarks"] addObject:bookmark];
    [bookmark release];
}

- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification {
	NSString *error = nil;
	NSData *data = [NSPropertyListSerialization dataFromPropertyList:[bookmarks valueForKey:@"dictionaryValue"]
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


@implementation BDSKBookmark

- (id)initWithUrlString:(NSString *)aUrlString name:(NSString *)aName {
    if (self = [super init]) {
        urlString = [aUrlString copy];
        name = [aName copy];
    }
    return self;
}

- (id)init {
    return [self initWithUrlString:@"http://" name:NSLocalizedString(@"New Boookmark", @"Default name for boookmark")];
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    return [self initWithUrlString:[dictionary objectForKey:@"URLString"] name:[dictionary objectForKey:@"Title"]];
}

- (void)dealloc {
    [urlString release];
    [name release];
    [super dealloc];
}

- (NSDictionary *)dictionaryValue {
    return [NSDictionary dictionaryWithObjectsAndKeys:urlString, @"URLString", name, @"Title", nil];
}

- (NSURL *)URL {
    return [NSURL URLWithString:[self urlString]];
}

- (NSString *)urlString {
    return [[urlString retain] autorelease];
}

- (void)setUrlString:(NSString *)newUrlString {
    if (urlString != newUrlString) {
        [urlString release];
        urlString = [newUrlString retain];
    }
}

- (BOOL)validateUrlString:(id *)value error:(NSError **)error {
    NSString *string = *value;
    if (string == nil || [NSURL URLWithString:string] == nil) {
        if (error) {
            NSString *description = NSLocalizedString(@"Invalid URL.", @"Error description");
            NSString *reason = [NSString stringWithFormat:NSLocalizedString(@"\"%@\" is not a valid URL.", @"Error reason"), string];
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, nil];
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:userInfo];
        }
        return NO;
    }
    return YES;
}

- (NSString *)name {
    return [[name retain] autorelease];
}

- (void)setName:(NSString *)newName {
    if (name != newName) {
        [name release];
        name = [newName retain];
    }
}

- (BOOL)validateName:(id *)value error:(NSError **)error {log_method();
    NSArray *names = [[[BDSKBookmarkController sharedBookmarkController] bookmarks] valueForKey:@"name"];
    NSString *string = *value;
    if ([NSString isEmptyString:string] || ([name isEqualToString:string] == NO && [names containsObject:string])) {
        if (error) {
            NSString *description = NSLocalizedString(@"Invalid name.", @"Error description");
            NSString *reason = [NSString stringWithFormat:NSLocalizedString(@"The bookmark \"%@\" already exists or is empty.", @"Error reason"), string];
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, nil];
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:userInfo];
        }
        return NO;
    }
    return YES;
}

@end

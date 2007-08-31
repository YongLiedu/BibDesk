//
//  BDSKBookmarkController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 18/8/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BDSKBookmarkController.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BibDocument.h"

static NSString *BDSKBookmarkRowsPboardType = @"BDSKBookmarkRowsPboardType";

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
		undoManager = nil;
        
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
    [undoManager release];
    [super dealloc];
}

- (NSString *)windowNibName { return @"BookmarksWindow"; }

- (void)windowDidLoad {
    [self setWindowFrameAutosaveName:@"BDSKBookmarksWindow"];
    [tableView registerForDraggedTypes:[NSArray arrayWithObjects:BDSKBookmarkRowsPboardType, BDSKWeblocFilePboardType, NSURLPboardType, nil]];
}

- (NSArray *)bookmarks {
    return bookmarks;
}

- (void)setBookmarks:(NSArray *)newBookmarks {
    if (bookmarks != newBookmarks) {
        [[[self undoManager] prepareWithInvocationTarget:self] setBookmarks:[[bookmarks copy] autorelease]];
        [bookmarks release];
        bookmarks = [newBookmarks mutableCopy];
    }
}

- (unsigned)countOfBookmarks {
    return [bookmarks count];
}

- (id)objectInBookmarksAtIndex:(unsigned)idx {
    return [bookmarks objectAtIndex:idx];
}

- (void)insertObject:(id)obj inBookmarksAtIndex:(unsigned)idx {
    [[[self undoManager] prepareWithInvocationTarget:self] removeObjectFromBookmarksAtIndex:idx];
    [bookmarks insertObject:obj atIndex:idx];
}

- (void)removeObjectFromBookmarksAtIndex:(unsigned)idx {
    [[[self undoManager] prepareWithInvocationTarget:self] insertObject:[bookmarks objectAtIndex:idx] inBookmarksAtIndex:idx];
    [bookmarks removeObjectAtIndex:idx];
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

#pragma mark Undo support

- (NSUndoManager *)undoManager {
    if(undoManager == nil)
        undoManager = [[NSUndoManager alloc] init];
    return undoManager;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender {
    return [self undoManager];
}

#pragma mark NSTableView datasource methods

- (int)numberOfRowsInTableView:(NSTableView *)tv { return 0; }

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row { return nil; }

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    OBASSERT([rowIndexes count] == 1);
    [pboard declareTypes:[NSArray arrayWithObjects:BDSKBookmarkRowsPboardType, nil] owner:nil];
    [pboard setPropertyList:[NSNumber numberWithUnsignedInt:[rowIndexes firstIndex]] forType:BDSKBookmarkRowsPboardType];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBookmarkRowsPboardType, BDSKWeblocFilePboardType, NSURLPboardType, nil]];
    
    if ([type isEqualToString:BDSKBookmarkRowsPboardType]) {
        [tv setDropRow:row == -1 ? [tv numberOfRows] : row dropOperation:NSTableViewDropAbove];
        return NSDragOperationMove;
    } else if (type) {
        return NSDragOperationEvery;
    }
    return NSDragOperationNone;
}


- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBookmarkRowsPboardType, BDSKWeblocFilePboardType, NSURLPboardType, nil]];
    
    if ([type isEqualToString:BDSKBookmarkRowsPboardType]) {
        int draggedRow = [[pboard propertyListForType:BDSKBookmarkRowsPboardType] intValue];
        BDSKBookmark *bookmark = [[bookmarks objectAtIndex:draggedRow] retain];
        [self removeObjectFromBookmarksAtIndex:draggedRow];
        [self insertObject:bookmark inBookmarksAtIndex:row < draggedRow ? row : row - 1];
        [bookmark release];
        [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        return YES;
    } else if (type) {
        NSString *urlString = nil;
        if ([type isEqualToString:BDSKWeblocFilePboardType])
            urlString = [pboard stringForType:BDSKWeblocFilePboardType];
        else if ([type isEqualToString:NSURLPboardType])
            urlString = [[NSURL URLFromPasteboard:pboard] absoluteString];
        if (urlString == nil)
            return NO;
        if (op == NSTableViewDropOn && row != -1) {
            [[bookmarks objectAtIndex:row] setUrlString:urlString];
        } else {
            if (row == -1)
                row = [bookmarks count];
            BDSKBookmark *bookmark = [[BDSKBookmark alloc] initWithUrlString:urlString name:[self uniqueName]];
            [self insertObject:bookmark inBookmarksAtIndex:row];
            [bookmark release];
        }
        return YES;
    }
    return NO;
}

- (void)tableView:(NSTableView *)tv deleteRows:(NSArray *)rows {
    int row = [[rows lastObject] intValue];
    [self removeObjectFromBookmarksAtIndex:row];
}

- (NSString *)uniqueName {
    NSArray *names = [[self bookmarks] valueForKey:@"name"];
    NSString *baseName = NSLocalizedString(@"New Boookmark", @"Default name for boookmark");
    NSString *newName = baseName;
    int i = 0;
    while ([names containsObject:newName])
        newName = [baseName stringByAppendingFormat:@" %i", ++i];
    return newName;
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
    return [self initWithUrlString:@"http://" name:[[BDSKBookmarkController sharedBookmarkController] uniqueName]];
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    return [self initWithUrlString:[dictionary objectForKey:@"URLString"] name:[dictionary objectForKey:@"Title"]];
}

- (id)copyWithZone:(NSZone *)aZone {
    return [[[self class] allocWithZone:aZone] initWithUrlString:urlString name:name];
}

- (void)dealloc {
    [[[BDSKBookmarkController sharedBookmarkController] undoManager] removeAllActionsWithTarget:self];
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
        NSUndoManager *undoManager = [[BDSKBookmarkController sharedBookmarkController] undoManager];
        [[undoManager prepareWithInvocationTarget:self] setUrlString:urlString];
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
        NSUndoManager *undoManager = [[BDSKBookmarkController sharedBookmarkController] undoManager];
        [(BDSKBookmark *)[undoManager prepareWithInvocationTarget:self] setName:name];
        [name release];
        name = [newName retain];
    }
}

- (BOOL)validateName:(id *)value error:(NSError **)error {
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

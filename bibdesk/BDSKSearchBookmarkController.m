//
//  BDSKSearchBookmarkController.m
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

#import "BDSKSearchBookmarkController.h"
#import "BibPrefController.h"

static NSString *BDSKSearchBookmarkRowsPboardType = @"BDSKSearchBookmarkRowsPboardType";
static NSString *BDSKSearchBookmarkChangedNotification = @"BDSKSearchBookmarkChangedNotification";

@implementation BDSKSearchBookmarkController

+ (id)sharedBookmarkController {
    static BDSKSearchBookmarkController *sharedBookmarkController = nil;
    if (sharedBookmarkController == nil)
        sharedBookmarkController = [[self alloc] init];
    return sharedBookmarkController;
}

- (id)init {
    if (self = [super init]) {
        bookmarks = [[NSMutableArray alloc] init];
        NSEnumerator *dictEnum = [[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKSearchGroupBookmarksKey] objectEnumerator];
        NSDictionary *dict;
        
        while (dict = [dictEnum nextObject]) {
            BDSKSearchBookmark *bm = [[BDSKSearchBookmark alloc] initWithDictionary:dict];
            [bookmarks addObject:bm];
            [bm release];
        }
        
		[[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSearchBookmarkChangedNotification:)
                                                     name:BDSKSearchBookmarkChangedNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [bookmarks release];
    [super dealloc];
}

- (NSString *)windowNibName { return @"SearchBookmarksWindow"; }

- (void)windowDidLoad {
    [self setWindowFrameAutosaveName:@"BDSKSearchBookmarksWindow"];
    [tableView registerForDraggedTypes:[NSArray arrayWithObject:BDSKSearchBookmarkRowsPboardType]];
}

- (NSArray *)bookmarks {
    return bookmarks;
}

- (void)setBookmarks:(NSArray *)newBookmarks {
    [[[self undoManager] prepareWithInvocationTarget:self] setBookmarks:[[bookmarks copy] autorelease]];
    return [bookmarks setArray:newBookmarks];
}

- (unsigned)countOfBookmarks {
    return [bookmarks count];
}

- (id)objectInBookmarksAtIndex:(unsigned)index {
    return [bookmarks objectAtIndex:index];
}

- (void)insertObject:(id)obj inBookmarksAtIndex:(unsigned)index {
    [[[self undoManager] prepareWithInvocationTarget:self] removeObjectFromBookmarksAtIndex:index];
    [bookmarks insertObject:obj atIndex:index];
    [self saveBookmarks];
}

- (void)removeObjectFromBookmarksAtIndex:(unsigned)index {
    [[[self undoManager] prepareWithInvocationTarget:self] insertObject:[bookmarks objectAtIndex:index] inBookmarksAtIndex:index];
    [bookmarks removeObjectAtIndex:index];
    [self saveBookmarks];
}

- (void)addBookmarkWithInfo:(NSDictionary *)info label:(NSString *)label {
    BDSKSearchBookmark *bookmark = [[BDSKSearchBookmark alloc] initWithInfo:info label:label];
    [[self mutableArrayValueForKey:@"bookmarks"] addObject:bookmark];
    [bookmark release];
}

- (void)saveBookmarks {
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:[bookmarks valueForKey:@"dictionaryValue"] forKey:BDSKSearchGroupBookmarksKey];
}

- (void)handleSearchBookmarkChangedNotification:(NSNotification *)notification {
    [self saveBookmarks];
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

#pragma mark tableView datasource methods

- (int)numberOfRowsInTableView:(NSTableView *)tv { return 0; }

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row { return nil; }

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    OBASSERT([rowIndexes count] == 1);
    [pboard declareTypes:[NSArray arrayWithObjects:BDSKSearchBookmarkRowsPboardType, nil] owner:nil];
    [pboard setPropertyList:[NSNumber numberWithUnsignedInt:[rowIndexes firstIndex]] forType:BDSKSearchBookmarkRowsPboardType];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKSearchBookmarkRowsPboardType, nil]];
    
    if (type) {
        [tv setDropRow:row == -1 ? [tv numberOfRows] : row dropOperation:NSTableViewDropAbove];
        return NSDragOperationMove;
    }
    return NSDragOperationNone;
}


- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKSearchBookmarkRowsPboardType, nil]];
    
    if (type) {
        int draggedRow = [[pboard propertyListForType:BDSKSearchBookmarkRowsPboardType] intValue];
        NSDictionary *bookmark = [[bookmarks objectAtIndex:draggedRow] retain];
        [self removeObjectFromBookmarksAtIndex:draggedRow];
        [self insertObject:bookmark inBookmarksAtIndex:row < draggedRow ? row : row - 1];
        [bookmark release];
        [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        return YES;
    }
    return NO;
}

@end


@implementation BDSKSearchBookmark

- (id)initWithInfo:(NSDictionary *)aDictionary label:(NSString *)aLabel {
    if (self = [super init]) {
        info = [aDictionary copy];
        label = [aLabel copy];
    }
    return self;
}

- (id)init {
    [[super init] release];
    return nil;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    NSMutableDictionary *dict = [[dictionary mutableCopy] autorelease];
    [dict removeObjectForKey:@"label"];
    return [self initWithInfo:dict label:[dictionary objectForKey:@"label"]];
}

- (id)copyWithZone:(NSZone *)aZone {
    return [[[self class] allocWithZone:aZone] initWithInfo:info label:label];
}

- (void)dealloc {
    [info release];
    [label release];
    [super dealloc];
}

- (NSDictionary *)dictionaryValue {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:label, @"label", nil];
    [dictionary addEntriesFromDictionary:info];
    return dictionary;
}

- (NSDictionary *)info {
    return info;
}

- (NSString *)label {
    return label;
}

- (void)setLabel:(NSString *)newLabel {
    if (label != newLabel) {
        NSUndoManager *undoManager = [[BDSKSearchBookmarkController sharedBookmarkController] undoManager];
        [(BDSKSearchBookmark *)[undoManager prepareWithInvocationTarget:self] setLabel:label];
        [label release];
        label = [newLabel retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSearchBookmarkChangedNotification object:self];
    }
}

@end

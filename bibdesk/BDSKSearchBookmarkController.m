//
//  BDSKSearchBookmarkController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/26/07.
/*
 This software is Copyright (c) 2007-2008
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
#import "BDSKSearchBookmark.h"
#import "BDSKStringConstants.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKBookmarkOutlineView.h"

static NSString *BDSKSearchBookmarkRowsPboardType = @"BDSKSearchBookmarkRowsPboardType";

static NSString *BDSKSearchBookmarksToolbarIdentifier = @"BDSKSearchBookmarksToolbarIdentifier";
static NSString *BDSKSearchBookmarksNewFolderToolbarItemIdentifier = @"BDSKSearchBookmarksNewFolderToolbarItemIdentifier";
static NSString *BDSKSearchBookmarksNewSeparatorToolbarItemIdentifier = @"BDSKSearchBookmarksNewSeparatorToolbarItemIdentifier";
static NSString *BDSKSearchBookmarksDeleteToolbarItemIdentifier = @"BDSKSearchBookmarksDeleteToolbarItemIdentifier";

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
		[[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSearchBookmarkWillBeRemovedNotification:)
                                                     name:BDSKSearchBookmarkWillBeRemovedNotification
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
    [self setupToolbar];
    [self setWindowFrameAutosaveName:@"BDSKSearchBookmarksWindow"];
    [outlineView setAutoresizesOutlineColumn:NO];
    [outlineView registerForDraggedTypes:[NSArray arrayWithObject:BDSKSearchBookmarkRowsPboardType]];
}

- (NSArray *)bookmarks {
    return bookmarks;
}

- (void)setBookmarks:(NSArray *)newBookmarks {
    [[[self undoManager] prepareWithInvocationTarget:self] setBookmarks:[[bookmarks copy] autorelease]];
    [bookmarks setArray:newBookmarks];
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
    [self handleSearchBookmarkChangedNotification:nil];
}

- (void)removeObjectFromBookmarksAtIndex:(unsigned)idx {
    [[[self undoManager] prepareWithInvocationTarget:self] insertObject:[bookmarks objectAtIndex:idx] inBookmarksAtIndex:idx];
    [self handleSearchBookmarkWillBeRemovedNotification:nil];
    [bookmarks removeObjectAtIndex:idx];
    [self handleSearchBookmarkChangedNotification:nil];
}

- (NSArray *)childrenOfBookmark:(BDSKSearchBookmark *)bookmark {
    return bookmark ? [bookmark children] : bookmarks;
}

- (unsigned int)indexOfChildBookmark:(BDSKSearchBookmark *)bookmark {
    return [[self childrenOfBookmark:[bookmark parent]] indexOfObject:bookmark];
}

- (void)bookmark:(BDSKSearchBookmark *)bookmark insertChildBookmark:(BDSKSearchBookmark *)child atIndex:(unsigned int)idx {
    if (bookmark)
        [bookmark insertChild:child atIndex:idx];
    else
        [self insertObject:child inBookmarksAtIndex:idx];
}

- (void)removeChildBookmark:(BDSKSearchBookmark *)bookmark {
    BDSKSearchBookmark *parent = [bookmark parent];
    if (parent)
        [parent removeChild:bookmark];
    else
        [[self mutableArrayValueForKey:@"bookmarks"] removeObject:bookmark];
}

- (NSArray *)minimumCoverForBookmarks:(NSArray *)items {
    NSEnumerator *bmEnum = [items objectEnumerator];
    BDSKSearchBookmark *bm;
    BDSKSearchBookmark *lastBm = nil;
    NSMutableArray *minimalCover = [NSMutableArray array];
    
    while (bm = [bmEnum nextObject]) {
        if ([bm isDescendantOf:lastBm] == NO) {
            [minimalCover addObject:bm];
            lastBm = bm;
        }
    }
    return minimalCover;
}

- (void)addBookmarkWithInfo:(NSDictionary *)info label:(NSString *)label toFolder:(BDSKSearchBookmark *)folder {
    BDSKSearchBookmark *bookmark = [[BDSKSearchBookmark alloc] initWithInfo:info label:label];
    if (bookmark) {
        [self bookmark:folder insertChildBookmark:bookmark atIndex:[[self childrenOfBookmark:folder] count]];
    [bookmark release];
    }
}

- (NSArray *)draggedBookmarks {
    return draggedBookmarks;
}

- (void)setDraggedBookmarks:(NSArray *)items {
    if (draggedBookmarks != items) {
        [draggedBookmarks release];
        draggedBookmarks = [items retain];
    }
}

- (void)saveBookmarks {
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:[bookmarks valueForKey:@"dictionaryValue"] forKey:BDSKSearchGroupBookmarksKey];
}

#pragma mark Actions

- (IBAction)insertBookmarkFolder:(id)sender {
    BDSKSearchBookmark *folder = [[[BDSKSearchBookmark alloc] initFolderWithLabel:NSLocalizedString(@"Folder", @"default folder name")] autorelease];
    int rowIndex = [[outlineView selectedRowIndexes] lastIndex];
    BDSKSearchBookmark *item = nil;
    unsigned int idx = [bookmarks count];
    
    if (rowIndex != NSNotFound) {
        BDSKSearchBookmark *selectedItem = [outlineView itemAtRow:rowIndex];
        if ([outlineView isItemExpanded:selectedItem]) {
            item = selectedItem;
            idx = [[item children] count];
        } else {
            item = [selectedItem parent];
            idx = [self indexOfChildBookmark:selectedItem] + 1;
        }
    }
    [self bookmark:item insertChildBookmark:folder atIndex:idx];
    
    int row = [outlineView rowForItem:folder];
    [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [outlineView editColumn:0 row:row withEvent:nil select:YES];
}

- (IBAction)insertBookmarkSeparator:(id)sender {
    BDSKSearchBookmark *separator = [[[BDSKSearchBookmark alloc] initSeparator] autorelease];
    int rowIndex = [[outlineView selectedRowIndexes] lastIndex];
    BDSKSearchBookmark *item = nil;
    unsigned int idx = [bookmarks count];
    
    if (rowIndex != NSNotFound) {
        BDSKSearchBookmark *selectedItem = [outlineView itemAtRow:rowIndex];
        if ([outlineView isItemExpanded:selectedItem]) {
            item = selectedItem;
            idx = [[item children] count];
        } else {
            item = [selectedItem parent];
            idx = [self indexOfChildBookmark:selectedItem] + 1;
        }
    }
    [self bookmark:item insertChildBookmark:separator atIndex:idx];
    
    int row = [outlineView rowForItem:separator];
    [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
}

- (IBAction)deleteBookmark:(id)sender {
    [outlineView delete:sender];
}

#pragma mark Notification handlers

- (void)handleSearchBookmarkWillBeRemovedNotification:(NSNotification *)notification  {
    if ([outlineView editedRow] && [[self window] makeFirstResponder:outlineView] == NO)
        [[self window] endEditingFor:nil];
}

- (void)handleSearchBookmarkChangedNotification:(NSNotification *)notification {
    [self saveBookmarks];
    [outlineView reloadData];
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

#pragma mark NSOutlineView datasource methods

- (int)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item {
    return [[self childrenOfBookmark:item] count];
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item {
    return [item bookmarkType] == BDSKSearchBookmarkTypeFolder;
}

- (id)outlineView:(NSOutlineView *)ov child:(int)idx ofItem:(id)item {
    return [[self childrenOfBookmark:item] objectAtIndex:idx];
}

- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    NSString *tcID = [tableColumn identifier];
    if ([tcID isEqualToString:@"label"]) {
        return [NSDictionary dictionaryWithObjectsAndKeys:[item label], OATextWithIconCellStringKey, [item icon], OATextWithIconCellImageKey, nil];
    } else if ([tcID isEqualToString:@"server"]) {
        if ([item bookmarkType] == BDSKSearchBookmarkTypeFolder) {
            int count = [[item children] count];
            return count == 1 ? NSLocalizedString(@"1 item", @"Bookmark folder description") : [NSString stringWithFormat:NSLocalizedString(@"%i items", @"Bookmark folder description"), count];
        } else {
            return [[item info] valueForKey:@"name"];
        }
    } else if ([tcID isEqualToString:@"search term"]) {
        return [[item info] valueForKey:@"search term"];
    }
    return nil;
}

- (void)outlineView:(NSOutlineView *)ov setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    NSString *tcID = [tableColumn identifier];
    if ([tcID isEqualToString:@"label"]) {
        if (object == nil)
            object = @"";
        if ([object isEqualToString:[item label]] == NO)
            [item setLabel:object];
    }
}

- (BOOL)outlineView:(NSOutlineView *)ov writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard {
    [self setDraggedBookmarks:[self minimumCoverForBookmarks:items]];
    [pboard declareTypes:[NSArray arrayWithObjects:BDSKSearchBookmarkRowsPboardType, nil] owner:nil];
    [pboard setData:[NSData data] forType:BDSKSearchBookmarkRowsPboardType];
    return YES;
}

- (NSDragOperation)outlineView:(NSOutlineView *)ov validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)idx {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKSearchBookmarkRowsPboardType, nil]];
    
    if (type) {
        if (idx == NSOutlineViewDropOnItemIndex) {
            if ([item bookmarkType] == BDSKSearchBookmarkTypeFolder && [outlineView isItemExpanded:item]) {
                [ov setDropItem:item dropChildIndex:0];
            } else if ([item parent]) {
                [ov setDropItem:[item parent] dropChildIndex:[[[item parent] children] indexOfObject:item] + 1];
            } else if (item) {
                [ov setDropItem:nil dropChildIndex:[bookmarks indexOfObject:item] + 1];
            } else {
                [ov setDropItem:nil dropChildIndex:[bookmarks count]];
            }
        }
        return [item isDescendantOfArray:[self draggedBookmarks]] ? NSDragOperationNone : NSDragOperationMove;
    }
    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)ov acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)idx {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKSearchBookmarkRowsPboardType, nil]];
    
    if (type) {
        NSEnumerator *bmEnum = [[self draggedBookmarks] objectEnumerator];
        BDSKSearchBookmark *bookmark;
				
		while (bookmark = [bmEnum nextObject]) {
            int bookmarkIndex = [self indexOfChildBookmark:bookmark];
            if (item == [bookmark parent]) {
                if (idx > bookmarkIndex)
                    idx--;
                if (idx == bookmarkIndex)
                    continue;
            }
            [self removeChildBookmark:bookmark];
            [self bookmark:item insertChildBookmark:bookmark atIndex:idx++];
		}
        return YES;
    }
    return NO;
}

- (void)tableView:(NSTableView *)aTableView concludeDragOperation:(NSDragOperation)operation {
    [self setDraggedBookmarks:nil];
}

#pragma mark NSOutlineView delegate methods

- (void)outlineView:(NSOutlineView *)ov willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if ([[tableColumn identifier] isEqualToString:@"server"]) {
        if ([item bookmarkType] == BDSKSearchBookmarkTypeFolder)
            [cell setTextColor:[NSColor disabledControlTextColor]];
        else
            [cell setTextColor:[NSColor controlTextColor]];
    }
}

- (BOOL)outlineView:(NSOutlineView *)ov shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    return [[tableColumn identifier] isEqualToString:@"label"] && [item bookmarkType] != BDSKSearchBookmarkTypeSeparator;
}

- (void)tableView:(NSTableView *)tv deleteRows:(NSArray *)rows {
    NSMutableArray *items = [NSMutableArray array];
    NSEnumerator *rowEnum = [rows objectEnumerator];
    NSNumber *row;
    
    while (row = [rowEnum nextObject])
        [items addObject:[outlineView itemAtRow:[row intValue]]];
    
    NSEnumerator *itemEnum = [[self minimumCoverForBookmarks:items] reverseObjectEnumerator];
    BDSKSearchBookmark *item;
    
    while (item = [itemEnum  nextObject])
        [self removeChildBookmark:item];
}

- (BOOL)outlineView:(NSOutlineView *)ov drawSeparatorRowForItem:(id)item {
    return [item bookmarkType] == BDSKSearchBookmarkTypeSeparator;
}

#pragma mark Toolbar

- (void)setupToolbar {
    // Create a new toolbar instance, and attach it to our document window
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:BDSKSearchBookmarksToolbarIdentifier] autorelease];
    OAToolbarItem *item;
    
    toolbarItems = [[NSMutableDictionary alloc] initWithCapacity:3];
    
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeDefault];
    
    // We are the delegate
    [toolbar setDelegate: self];
    
    // Add template toolbar items
    
    item = [[OAToolbarItem alloc] initWithItemIdentifier:BDSKSearchBookmarksNewFolderToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"New Folder", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"New Folder", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Add a New Folder", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"NewFolder"]];
    [item setTarget:self];
    [item setAction:@selector(insertBookmarkFolder:)];
    [toolbarItems setObject:item forKey:BDSKSearchBookmarksNewFolderToolbarItemIdentifier];
    [item release];
    
    item = [[OAToolbarItem alloc] initWithItemIdentifier:BDSKSearchBookmarksNewSeparatorToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"New Separator", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"New Separator", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Add a New Separator", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"NewSeparator"]];
    [item setTarget:self];
    [item setAction:@selector(insertBookmarkSeparator:)];
    [toolbarItems setObject:item forKey:BDSKSearchBookmarksNewSeparatorToolbarItemIdentifier];
    [item release];
    
    item = [[OAToolbarItem alloc] initWithItemIdentifier:BDSKSearchBookmarksDeleteToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"Delete", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Delete", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Delete Selected Items", @"Tool tip message")];
    [item setImage:[NSImage imageWithLargeIconForToolboxCode:kToolbarDeleteIcon]];
    [item setTarget:self];
    [item setAction:@selector(deleteBookmark:)];
    [toolbarItems setObject:item forKey:BDSKSearchBookmarksDeleteToolbarItemIdentifier];
    [item release];
    
    // Attach the toolbar to the window
    [[self window] setToolbar:toolbar];
}

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {

    NSToolbarItem *item = [toolbarItems objectForKey:itemIdent];
    NSToolbarItem *newItem = [[item copy] autorelease];
    return newItem;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return [NSArray arrayWithObjects:
        BDSKSearchBookmarksNewFolderToolbarItemIdentifier, 
        BDSKSearchBookmarksNewSeparatorToolbarItemIdentifier, 
        BDSKSearchBookmarksDeleteToolbarItemIdentifier, nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return [NSArray arrayWithObjects: 
        BDSKSearchBookmarksNewFolderToolbarItemIdentifier, 
        BDSKSearchBookmarksNewSeparatorToolbarItemIdentifier, 
		BDSKSearchBookmarksDeleteToolbarItemIdentifier, 
        NSToolbarFlexibleSpaceItemIdentifier, 
		NSToolbarSpaceItemIdentifier, 
		NSToolbarSeparatorItemIdentifier, 
		NSToolbarCustomizeToolbarItemIdentifier, nil];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem {
    NSString *identifier = [toolbarItem itemIdentifier];
    if ([identifier isEqualToString:BDSKSearchBookmarksDeleteToolbarItemIdentifier]) {
        return [outlineView numberOfSelectedRows] > 0;
    } else {
        return YES;
    }
}

@end

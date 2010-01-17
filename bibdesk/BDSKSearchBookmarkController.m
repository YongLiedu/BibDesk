//
//  BDSKSearchBookmarkController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/26/07.
/*
 This software is Copyright (c) 2007-2010
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
#import "BDSKOutlineView.h"
#import "BDSKTextWithIconCell.h"
#import "BDSKSeparatorCell.h"

#define BDSKSearchBookmarkRowsPboardType @"BDSKSearchBookmarkRowsPboardType"

#define BDSKSearchBookmarksToolbarIdentifier                    @"BDSKSearchBookmarksToolbarIdentifier"
#define BDSKSearchBookmarksNewFolderToolbarItemIdentifier       @"BDSKSearchBookmarksNewFolderToolbarItemIdentifier"
#define BDSKSearchBookmarksNewSeparatorToolbarItemIdentifier    @"BDSKSearchBookmarksNewSeparatorToolbarItemIdentifier"
#define BDSKSearchBookmarksDeleteToolbarItemIdentifier          @"BDSKSearchBookmarksDeleteToolbarItemIdentifier"

#define CHILDREN_KEY @"children"
#define LABEL_KEY    @"label"

static char BDSKSearchBookmarkPropertiesObservationContext;


@interface BDSKSearchBookmarkController (BDSKPrivate)
- (void)setupToolbar;
- (void)endEditing;
- (void)startObservingBookmarks:(NSArray *)newBookmarks;
- (void)stopObservingBookmarks:(NSArray *)oldBookmarks;
@end

@implementation BDSKSearchBookmarkController

static BDSKSearchBookmarkController *sharedBookmarkController = nil;

+ (id)sharedBookmarkController {
    if (sharedBookmarkController == nil)
        sharedBookmarkController = [[self alloc] init];
    return sharedBookmarkController;
}

- (id)init {
    BDSKPRECONDITION(sharedBookmarkController == nil);
    if (self = [super initWithWindowNibName:@"SearchBookmarksWindow"]) {
        NSMutableArray *bookmarks = [NSMutableArray array];
        for (NSDictionary *dict in [[NSUserDefaults standardUserDefaults] arrayForKey:BDSKSearchGroupBookmarksKey]) {
            BDSKSearchBookmark *bm = [BDSKSearchBookmark searchBookmarkWithDictionary:dict];
            if (bm)
                [bookmarks addObject:bm];
        }
        
        bookmarkRoot = [[BDSKSearchBookmark alloc] initRootWithChildren:bookmarks];
        [self startObservingBookmarks:[NSArray arrayWithObject:bookmarkRoot]];
    }
    return self;
}

- (void)windowDidLoad {
    [self setupToolbar];
    [self setWindowFrameAutosaveName:@"BDSKSearchBookmarksWindow"];
    [outlineView setAutoresizesOutlineColumn:NO];
    [outlineView registerForDraggedTypes:[NSArray arrayWithObject:BDSKSearchBookmarkRowsPboardType]];
}

- (BDSKSearchBookmark *)bookmarkRoot {
    return bookmarkRoot;
}

static NSArray *minimumCoverForBookmarks(NSArray *items) {
    BDSKSearchBookmark *lastBm = nil;
    NSMutableArray *minimalCover = [NSMutableArray array];
    
    for (BDSKSearchBookmark *bm in items) {
        if ([bm isDescendantOf:lastBm] == NO) {
            [minimalCover addObject:bm];
            lastBm = bm;
        }
    }
    return minimalCover;
}

- (void)addBookmarkWithInfo:(NSDictionary *)info label:(NSString *)label toFolder:(BDSKSearchBookmark *)folder {
    BDSKSearchBookmark *bookmark = [BDSKSearchBookmark searchBookmarkWithInfo:info label:label];
    if (bookmark) {
        if (folder == nil) folder = bookmarkRoot;
        [folder insertObject:bookmark inChildrenAtIndex:[folder countOfChildren]];
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
    [[NSUserDefaults standardUserDefaults] setObject:[[bookmarkRoot children] valueForKey:@"dictionaryValue"] forKey:BDSKSearchGroupBookmarksKey];
}

#pragma mark Actions

- (IBAction)insertBookmarkFolder:(id)sender {
    BDSKSearchBookmark *folder = [BDSKSearchBookmark searchBookmarkFolderWithLabel:NSLocalizedString(@"Folder", @"default folder name")];
    NSInteger rowIndex = [[outlineView selectedRowIndexes] lastIndex];
    BDSKSearchBookmark *item = bookmarkRoot;
    NSUInteger idx = [[bookmarkRoot children] count];
    
    if (rowIndex != NSNotFound) {
        BDSKSearchBookmark *selectedItem = [outlineView itemAtRow:rowIndex];
        if ([outlineView isItemExpanded:selectedItem]) {
            item = selectedItem;
            idx = [[item children] count];
        } else {
            item = [selectedItem parent];
            idx = [[item children] indexOfObject:selectedItem] + 1;
        }
    }
    [item insertObject:folder inChildrenAtIndex:idx];
    
    NSInteger row = [outlineView rowForItem:folder];
    [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [outlineView editColumn:0 row:row withEvent:nil select:YES];
}

- (IBAction)insertBookmarkSeparator:(id)sender {
    BDSKSearchBookmark *separator = [BDSKSearchBookmark searchBookmarkSeparator];
    NSInteger rowIndex = [[outlineView selectedRowIndexes] lastIndex];
    BDSKSearchBookmark *item = bookmarkRoot;
    NSUInteger idx = [[bookmarkRoot children] count];
    
    if (rowIndex != NSNotFound) {
        BDSKSearchBookmark *selectedItem = [outlineView itemAtRow:rowIndex];
        if ([outlineView isItemExpanded:selectedItem]) {
            item = selectedItem;
            idx = [[item children] count];
        } else {
            item = [selectedItem parent];
            idx = [[item children] indexOfObject:selectedItem] + 1;
        }
    }
    [item insertObject:separator inChildrenAtIndex:idx];
    
    NSInteger row = [outlineView rowForItem:separator];
    [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
}

- (IBAction)deleteBookmark:(id)sender {
    [outlineView delete:sender];
}

- (void)endEditing {
    if ([outlineView editedRow] && [[self window] makeFirstResponder:outlineView] == NO)
        [[self window] endEditingFor:nil];
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

- (void)startObservingBookmarks:(NSArray *)newBookmarks {
    for (BDSKSearchBookmark *bm in newBookmarks) {
        if ([bm bookmarkType] != BDSKSearchBookmarkTypeSeparator) {
            [bm addObserver:self forKeyPath:LABEL_KEY options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&BDSKSearchBookmarkPropertiesObservationContext];
            if ([bm bookmarkType] == BDSKSearchBookmarkTypeFolder) {
                [bm addObserver:self forKeyPath:CHILDREN_KEY options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&BDSKSearchBookmarkPropertiesObservationContext];
                [self startObservingBookmarks:[bm children]];
            }
        }
    }
}

- (void)stopObservingBookmarks:(NSArray *)oldBookmarks {
    for (BDSKSearchBookmark *bm in oldBookmarks) {
        if ([bm bookmarkType] != BDSKSearchBookmarkTypeSeparator) {
            [bm removeObserver:self forKeyPath:LABEL_KEY];
            if ([bm bookmarkType] == BDSKSearchBookmarkTypeFolder) {
                [bm removeObserver:self forKeyPath:CHILDREN_KEY];
                [self stopObservingBookmarks:[bm children]];
            }
        }
    }
}

- (void)setChildren:(NSArray *)newChildren ofBookmark:(BDSKSearchBookmark *)bookmark {
    [[bookmark mutableArrayValueForKey:CHILDREN_KEY] setArray:newChildren];
}

- (void)insertObjects:(NSArray *)newChildren inChildrenOfBookmark:(BDSKSearchBookmark *)bookmark atIndexes:(NSIndexSet *)indexes {
    [[bookmark mutableArrayValueForKey:CHILDREN_KEY] insertObjects:newChildren atIndexes:indexes];
}

- (void)removeObjectsFromChildrenOfBookmark:(BDSKSearchBookmark *)bookmark atIndexes:(NSIndexSet *)indexes {
    [[bookmark mutableArrayValueForKey:CHILDREN_KEY] removeObjectsAtIndexes:indexes];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &BDSKSearchBookmarkPropertiesObservationContext) {
        BDSKSearchBookmark *bookmark = (BDSKSearchBookmark *)object;
        id newValue = [change objectForKey:NSKeyValueChangeNewKey];
        id oldValue = [change objectForKey:NSKeyValueChangeOldKey];
        NSIndexSet *indexes = [change objectForKey:NSKeyValueChangeIndexesKey];
        
        if ([newValue isEqual:[NSNull null]]) newValue = nil;
        if ([oldValue isEqual:[NSNull null]]) oldValue = nil;
        
        switch ([[change objectForKey:NSKeyValueChangeKindKey] unsignedIntegerValue]) {
            case NSKeyValueChangeSetting:
                if ([keyPath isEqualToString:CHILDREN_KEY]) {
                    NSMutableArray *old = [NSMutableArray arrayWithArray:oldValue];
                    NSMutableArray *new = [NSMutableArray arrayWithArray:newValue];
                    [old removeObjectsInArray:newValue];
                    [new removeObjectsInArray:oldValue];
                    [self stopObservingBookmarks:old];
                    [self startObservingBookmarks:new];
                    [[[self undoManager] prepareWithInvocationTarget:self] setChildren:oldValue ofBookmark:bookmark];
                } else if ([keyPath isEqualToString:LABEL_KEY]) {
                    [[[self undoManager] prepareWithInvocationTarget:bookmark] setLabel:oldValue];
                }
                break;
            case NSKeyValueChangeInsertion:
                if ([keyPath isEqualToString:CHILDREN_KEY]) {
                    [self startObservingBookmarks:newValue];
                    [[[self undoManager] prepareWithInvocationTarget:self] removeObjectsFromChildrenOfBookmark:bookmark atIndexes:indexes];
                }
                break;
            case NSKeyValueChangeRemoval:
                if ([keyPath isEqualToString:CHILDREN_KEY]) {
                    [self stopObservingBookmarks:oldValue];
                    [[[self undoManager] prepareWithInvocationTarget:self] insertObjects:oldValue inChildrenOfBookmark:bookmark atIndexes:indexes];
                }
                break;
            case NSKeyValueChangeReplacement:
                if ([keyPath isEqualToString:CHILDREN_KEY]) {
                    [self stopObservingBookmarks:oldValue];
                    [self startObservingBookmarks:newValue];
                    [[[self undoManager] prepareWithInvocationTarget:self] removeObjectsFromChildrenOfBookmark:bookmark atIndexes:indexes];
                    [[[self undoManager] prepareWithInvocationTarget:self] insertObjects:oldValue inChildrenOfBookmark:bookmark atIndexes:indexes];
                }
                break;
        }
        
        [outlineView reloadData];
        [self saveBookmarks];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark NSOutlineView datasource methods

- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item {
    return [[(item ?: bookmarkRoot) children] count];
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item {
    return [item bookmarkType] == BDSKSearchBookmarkTypeFolder;
}

- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)idx ofItem:(id)item {
    return [[(item ?: bookmarkRoot) children] objectAtIndex:idx];
}

- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    NSString *tcID = [tableColumn identifier];
    if ([tcID isEqualToString:@"label"]) {
        return [NSDictionary dictionaryWithObjectsAndKeys:[item label], BDSKTextWithIconCellStringKey, [item icon], BDSKTextWithIconCellImageKey, nil];
    } else if ([tcID isEqualToString:@"server"]) {
        if ([item bookmarkType] == BDSKSearchBookmarkTypeFolder) {
            NSInteger count = [[item children] count];
            return count == 1 ? NSLocalizedString(@"1 item", @"Bookmark folder description") : [NSString stringWithFormat:NSLocalizedString(@"%ld items", @"Bookmark folder description"), (long)count];
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
        // the editied object is always an NSDictionary, see BDSKTextWithIconFormatter
        NSString *newLabel = [object valueForKey:BDSKTextWithIconCellStringKey] ?: @"";
        if ([newLabel isEqualToString:[item label]] == NO)
            [item setLabel:newLabel];
    }
}

- (BOOL)outlineView:(NSOutlineView *)ov writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard {
    if (pboard == [NSPasteboard pasteboardWithName:NSDragPboard]) {
        [self setDraggedBookmarks:minimumCoverForBookmarks(items)];
        [pboard declareTypes:[NSArray arrayWithObjects:BDSKSearchBookmarkRowsPboardType, nil] owner:nil];
        [pboard setData:[NSData data] forType:BDSKSearchBookmarkRowsPboardType];
        return YES;
    }
    return NO;
}

- (NSDragOperation)outlineView:(NSOutlineView *)ov validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)idx {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKSearchBookmarkRowsPboardType, nil]];
    
    if (type) {
        if (idx == NSOutlineViewDropOnItemIndex) {
            if ([item bookmarkType] == BDSKSearchBookmarkTypeFolder && [outlineView isItemExpanded:item]) {
                [ov setDropItem:item dropChildIndex:0];
            } else if (item) {
                [ov setDropItem:(BDSKSearchBookmark *)[item parent] == bookmarkRoot ? nil : [item parent] dropChildIndex:[[[item parent] children] indexOfObject:item] + 1];
            } else {
                [ov setDropItem:nil dropChildIndex:[[bookmarkRoot children] count]];
            }
        }
        return [item isDescendantOfArray:[self draggedBookmarks]] ? NSDragOperationNone : NSDragOperationMove;
    }
    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)ov acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)idx {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKSearchBookmarkRowsPboardType, nil]];
    
    if (type) {
        if (item == nil) item = bookmarkRoot;
        
        [self endEditing];
        
		for (BDSKSearchBookmark *bookmark in [self draggedBookmarks]) {
            BDSKSearchBookmark *parent = [bookmark parent];
            NSInteger bookmarkIndex = [[parent children] indexOfObject:bookmark];
            if (item == parent) {
                if (idx > bookmarkIndex)
                    idx--;
                if (idx == bookmarkIndex)
                    continue;
            }
            [parent removeObjectFromChildrenAtIndex:bookmarkIndex];
            [(BDSKSearchBookmark *)item insertObject:bookmark inChildrenAtIndex:idx++];
		}
        return YES;
    }
    return NO;
}

- (void)outlineView:(NSOutlineView *)ov concludeDragOperation:(NSDragOperation)operation {
    [self setDraggedBookmarks:nil];
}

- (BOOL)outlineView:(NSOutlineView *)ov canCopyItems:(NSArray *)items {
    return NO;
}

#pragma mark NSOutlineView delegate methods

- (NSCell *)outlineView:(NSOutlineView *)ov dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if (tableColumn == nil)
        return [item bookmarkType] == BDSKSearchBookmarkTypeSeparator ? [[[BDSKSeparatorCell alloc] init] autorelease] : nil;
    return [tableColumn dataCellForRow:[ov rowForItem:item]];
}

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

- (void)outlineView:(NSOutlineView *)ov deleteItems:(NSArray *)items {
    [self endEditing];
    
    for (BDSKSearchBookmark *item in [minimumCoverForBookmarks(items) reverseObjectEnumerator]) {
        BDSKSearchBookmark *parent = [item parent];
        NSUInteger itemIndex = [[parent children] indexOfObject:item];
        if (itemIndex != NSNotFound)
            [parent removeObjectFromChildrenAtIndex:itemIndex];
    }
}

#pragma mark Toolbar

- (void)setupToolbar {
    // Create a new toolbar instance, and attach it to our document window
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:BDSKSearchBookmarksToolbarIdentifier] autorelease];
    NSToolbarItem *item;
    
    toolbarItems = [[NSMutableDictionary alloc] initWithCapacity:3];
    
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeDefault];
    
    // We are the delegate
    [toolbar setDelegate: self];
    
    // Add template toolbar items
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:BDSKSearchBookmarksNewFolderToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"New Folder", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"New Folder", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Add a New Folder", @"Tool tip message")];
    [item setImage:[NSImage addFolderToolbarImage]];
    [item setTarget:self];
    [item setAction:@selector(insertBookmarkFolder:)];
    [toolbarItems setObject:item forKey:BDSKSearchBookmarksNewFolderToolbarItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:BDSKSearchBookmarksNewSeparatorToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"New Separator", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"New Separator", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Add a New Separator", @"Tool tip message")];
    [item setImage:[NSImage addSeparatorToolbarImage]];
    [item setTarget:self];
    [item setAction:@selector(insertBookmarkSeparator:)];
    [toolbarItems setObject:item forKey:BDSKSearchBookmarksNewSeparatorToolbarItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:BDSKSearchBookmarksDeleteToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"Delete", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Delete", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Delete Selected Items", @"Tool tip message")];
    [item setImage:[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kToolbarDeleteIcon)]];
    [item setTarget:self];
    [item setAction:@selector(deleteBookmark:)];
    [toolbarItems setObject:item forKey:BDSKSearchBookmarksDeleteToolbarItemIdentifier];
    [item release];
    
    // Attach the toolbar to the window
    [[self window] setToolbar:toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL)willBeInserted {
    NSToolbarItem *item = [toolbarItems objectForKey:itemIdent];
    if (willBeInserted == NO)
        item = [[item copy] autorelease];
    return item;
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

//
//  BDSKBookmarkController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/18/07.
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

#import "BDSKBookmarkController.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BibDocument.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKBookmarkOutlineView.h"

static NSString *BDSKBookmarkRowsPboardType = @"BDSKBookmarkRowsPboardType";

static NSString *BDSKBookmarksToolbarIdentifier = @"BDSKBookmarksToolbarIdentifier";
static NSString *BDSKBookmarksNewBookmarkToolbarItemIdentifier = @"BDSKBookmarksNewBookmarkToolbarItemIdentifier";
static NSString *BDSKBookmarksNewFolderToolbarItemIdentifier = @"BDSKBookmarksNewFolderToolbarItemIdentifier";
static NSString *BDSKBookmarksNewSeparatorToolbarItemIdentifier = @"BDSKBookmarksNewSeparatorToolbarItemIdentifier";
static NSString *BDSKBookmarksDeleteToolbarItemIdentifier = @"BDSKBookmarksDeleteToolbarItemIdentifier";

static NSString *BDSKBookmarkChangedNotification = @"BDSKBookmarkChangedNotification";
static NSString *BDSKBookmarkWillBeRemovedNotification = @"BDSKBookmarkWillBeRemovedNotification";

static NSString *BDSKBookmarkTypeBookmarkString = @"bookmark";
static NSString *BDSKBookmarkTypeFolderString = @"folder";
static NSString *BDSKBookmarkTypeSeparatorString = @"separator";

#define CHILDREN_KEY    @"Children"
#define TITLE_KEY       @"Title"
#define URL_KEY         @"URLString"
#define TYPE_KEY        @"Type"

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
		}
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillTerminateNotification:) name:NSApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleBookmarkChangedNotification:) name:BDSKBookmarkChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleBookmarkWillBeRemovedNotification:) name:BDSKBookmarkWillBeRemovedNotification object:nil];
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
    [self setupToolbar];
    [self setWindowFrameAutosaveName:@"BDSKBookmarksWindow"];
    [outlineView setAutoresizesOutlineColumn:NO];
    [outlineView registerForDraggedTypes:[NSArray arrayWithObjects:BDSKBookmarkRowsPboardType, BDSKWeblocFilePboardType, NSURLPboardType, nil]];
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
    [self handleBookmarkChangedNotification:nil];
}

- (void)removeObjectFromBookmarksAtIndex:(unsigned)idx {
    [[[self undoManager] prepareWithInvocationTarget:self] insertObject:[bookmarks objectAtIndex:idx] inBookmarksAtIndex:idx];
    [bookmarks removeObjectAtIndex:idx];
    [self handleBookmarkChangedNotification:nil];
}

- (NSArray *)childrenOfBookmark:(BDSKBookmark *)bookmark {
    return bookmark ? [bookmark children] : bookmarks;
}

- (unsigned int)indexOfChildBookmark:(BDSKBookmark *)bookmark {
    return [[self childrenOfBookmark:[bookmark parent]] indexOfObject:bookmark];
}

- (void)bookmark:(BDSKBookmark *)bookmark insertChildBookmark:(BDSKBookmark *)child atIndex:(unsigned int)idx {
    if (bookmark)
        [bookmark insertChild:child atIndex:idx];
    else
        [self insertObject:child inBookmarksAtIndex:idx];
}

- (void)removeChildBookmark:(BDSKBookmark *)bookmark {
    BDSKBookmark *parent = [bookmark parent];
    if (parent)
        [parent removeChild:bookmark];
    else
        [[self mutableArrayValueForKey:@"bookmarks"] removeObject:bookmark];
}

- (NSArray *)minimumCoverForBookmarks:(NSArray *)items {
    NSEnumerator *bmEnum = [items objectEnumerator];
    BDSKBookmark *bm;
    BDSKBookmark *lastBm = nil;
    NSMutableArray *minimalCover = [NSMutableArray array];
    
    while (bm = [bmEnum nextObject]) {
        if ([bm isDescendantOf:lastBm] == NO) {
            [minimalCover addObject:bm];
            lastBm = bm;
        }
    }
    return minimalCover;
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

- (void)addBookmarkWithUrlString:(NSString *)urlString name:(NSString *)name {
    [self addBookmarkWithUrlString:urlString name:name toFolder:nil];
}

- (void)addBookmarkWithUrlString:(NSString *)urlString name:(NSString *)name toFolder:(BDSKBookmark *)folder {
    BDSKBookmark *bookmark = [[BDSKBookmark alloc] initWithUrlString:urlString name:name];
    if (bookmark) {
        [self bookmark:folder insertChildBookmark:bookmark atIndex:[[self childrenOfBookmark:folder] count]];
    [bookmark release];
    }
}

- (void)addBookmarkSheetDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    NSString *urlString = (NSString *)contextInfo;
	if (returnCode == NSOKButton) {
        [self addBookmarkWithUrlString:urlString name:[bookmarkField stringValue] toFolder:[[folderPopUp selectedItem] representedObject]];
	}
    [urlString release]; //the contextInfo was retained
}

- (void)addMenuItemsForBookmarks:(NSArray *)bookmarksArray level:(int)level toMenu:(NSMenu *)menu {
    int i, iMax = [bookmarksArray count];
    for (i = 0; i < iMax; i++) {
        BDSKBookmark *bm = [bookmarksArray objectAtIndex:i];
        if ([bm bookmarkType] == BDSKBookmarkTypeFolder) {
            NSString *name = [bm name];
            NSMenuItem *item = [menu addItemWithTitle:name ? name : @"" action:NULL keyEquivalent:@""];
            [item setImage:[bm icon]];
            [item setIndentationLevel:level];
            [item setRepresentedObject:bm];
            [self addMenuItemsForBookmarks:[bm children] level:level+1 toMenu:menu];
        }
    }
}

- (void)addBookmarkWithUrlString:(NSString *)urlString proposedName:(NSString *)name modalForWindow:(NSWindow *)window {
    [self window];
    [bookmarkField setStringValue:name];
    [folderPopUp removeAllItems];
    NSMenuItem *item = [[folderPopUp menu] addItemWithTitle:NSLocalizedString(@"Bookmarks Menu", @"Menu item title") action:NULL keyEquivalent:@""];
    [item setImage:[NSImage imageNamed:@"SmallMenu"]];
    [self addMenuItemsForBookmarks:bookmarks level:1 toMenu:[folderPopUp menu]];
    [folderPopUp selectItemAtIndex:0];
	
	[NSApp beginSheet:addBookmarkSheet
       modalForWindow:window
        modalDelegate:self
       didEndSelector:@selector(addBookmarkSheetDidEnd:returnCode:contextInfo:)
          contextInfo:[urlString retain]];
}

- (IBAction)dismissAddBookmarkSheet:(id)sender {
    [NSApp endSheet:addBookmarkSheet returnCode:[sender tag]];
    [addBookmarkSheet orderOut:self];
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

#pragma mark Actions

- (IBAction)insertBookmark:(id)sender {
    BDSKBookmark *bookmark = [[[BDSKBookmark alloc] initWithUrlString:@"http://" name:[self uniqueName]] autorelease];
    int rowIndex = [[outlineView selectedRowIndexes] lastIndex];
    BDSKBookmark *item = nil;
    unsigned int idx = [bookmarks count];
    
    if (rowIndex != NSNotFound) {
        BDSKBookmark *selectedItem = [outlineView itemAtRow:rowIndex];
        if ([outlineView isItemExpanded:selectedItem]) {
            item = selectedItem;
            idx = [[item children] count];
        } else {
            item = [selectedItem parent];
            idx = [self indexOfChildBookmark:selectedItem] + 1;
        }
    }
    [self bookmark:item insertChildBookmark:bookmark atIndex:idx];
    
    int row = [outlineView rowForItem:bookmark];
    [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [outlineView editColumn:0 row:row withEvent:nil select:YES];
}

- (IBAction)insertBookmarkFolder:(id)sender {
    BDSKBookmark *folder = [[[BDSKBookmark alloc] initFolderWithName:NSLocalizedString(@"Folder", @"default folder name")] autorelease];
    int rowIndex = [[outlineView selectedRowIndexes] lastIndex];
    BDSKBookmark *item = nil;
    unsigned int idx = [bookmarks count];
    
    if (rowIndex != NSNotFound) {
        BDSKBookmark *selectedItem = [outlineView itemAtRow:rowIndex];
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
    BDSKBookmark *separator = [[[BDSKBookmark alloc] initSeparator] autorelease];
    int rowIndex = [[outlineView selectedRowIndexes] lastIndex];
    BDSKBookmark *item = nil;
    unsigned int idx = [bookmarks count];
    
    if (rowIndex != NSNotFound) {
        BDSKBookmark *selectedItem = [outlineView itemAtRow:rowIndex];
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

- (void)handleBookmarkWillBeRemovedNotification:(NSNotification *)notification  {
    if ([outlineView editedRow] && [[self window] makeFirstResponder:outlineView] == NO)
        [[self window] endEditingFor:nil];
}

- (void)handleBookmarkChangedNotification:(NSNotification *)notification {
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
    return [item bookmarkType] == BDSKBookmarkTypeFolder;
}

- (id)outlineView:(NSOutlineView *)ov child:(int)idx ofItem:(id)item {
    return [[self childrenOfBookmark:item] objectAtIndex:idx];
}

- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    NSString *tcID = [tableColumn identifier];
    if ([tcID isEqualToString:@"name"]) {
        return [NSDictionary dictionaryWithObjectsAndKeys:[item name], OATextWithIconCellStringKey, [item icon], OATextWithIconCellImageKey, nil];
    } else if ([tcID isEqualToString:@"url"]) {
        if ([item bookmarkType] == BDSKBookmarkTypeFolder) {
            int count = [[item children] count];
            return count == 1 ? NSLocalizedString(@"1 item", @"Bookmark folder description") : [NSString stringWithFormat:NSLocalizedString(@"%i items", @"Bookmark folder description"), count];
        } else {
            return [item urlString];
        }
    }
    return nil;
}

- (void)outlineView:(NSOutlineView *)ov setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    NSString *tcID = [tableColumn identifier];
    if ([tcID isEqualToString:@"name"]) {
        if (object == nil)
            object = @"";
        if ([object isEqualToString:[item name]] == NO)
            [(BDSKBookmark *)item setName:object];
    } else if ([tcID isEqualToString:@"url"]) {
        if ([object length] == 0 || [NSURL URLWithString:object] == nil) {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid URL", @"Message in alert dialog when setting an invalid URL") 
                                             defaultButton:NSLocalizedString(@"OK", @"Button title")
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"\"%@\" is not a valid URL.", @"Informative text in alert dialog"), object];
            [alert beginSheetModalForWindow:[self window]
                              modalDelegate:nil
                             didEndSelector:NULL
                                contextInfo:NULL];
            [outlineView reloadData];
        } else if ([object isEqualToString:[item urlString]] == NO) {
            [(BDSKBookmark *)item setUrlString:object];
        }
    }
}

- (BOOL)outlineView:(NSOutlineView *)ov writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard {
    [self setDraggedBookmarks:[self minimumCoverForBookmarks:items]];
    [pboard declareTypes:[NSArray arrayWithObjects:BDSKBookmarkRowsPboardType, nil] owner:nil];
    [pboard setData:[NSData data] forType:BDSKBookmarkRowsPboardType];
    return YES;
}

- (NSDragOperation)outlineView:(NSOutlineView *)ov validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)idx {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBookmarkRowsPboardType, BDSKWeblocFilePboardType, NSURLPboardType, nil]];
    
    if ([type isEqualToString:BDSKBookmarkRowsPboardType]) {
        if (idx == NSOutlineViewDropOnItemIndex) {
            if ([item bookmarkType] == BDSKBookmarkTypeFolder && [outlineView isItemExpanded:item]) {
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
    } else if (type) {
        if (idx == NSOutlineViewDropOnItemIndex && (item == nil || [item bookmarkType] != BDSKBookmarkTypeBookmark)) {
            if ([item bookmarkType] == BDSKBookmarkTypeFolder && [outlineView isItemExpanded:item]) {
                [ov setDropItem:item dropChildIndex:0];
            } else if ([item parent]) {
                [ov setDropItem:[item parent] dropChildIndex:[[[item parent] children] indexOfObject:item] + 1];
            } else if (item) {
                [ov setDropItem:nil dropChildIndex:[bookmarks indexOfObject:item] + 1];
            } else {
                [ov setDropItem:nil dropChildIndex:[bookmarks count]];
            }
        }
        return NSDragOperationEvery;
    }
    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)ov acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)idx {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBookmarkRowsPboardType, BDSKWeblocFilePboardType, NSURLPboardType, nil]];
    
    if ([type isEqualToString:BDSKBookmarkRowsPboardType]) {
        NSEnumerator *bmEnum = [[self draggedBookmarks] objectEnumerator];
        BDSKBookmark *bookmark;
				
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
    } else if (type) {
        NSString *urlString = nil;
        if ([type isEqualToString:BDSKWeblocFilePboardType])
            urlString = [pboard stringForType:BDSKWeblocFilePboardType];
        else if ([type isEqualToString:NSURLPboardType])
            urlString = [[NSURL URLFromPasteboard:pboard] absoluteString];
        if (urlString == nil)
            return NO;
        if (idx == NSOutlineViewDropOnItemIndex && item && [item bookmarkType] == BDSKBookmarkTypeBookmark) {
            [item setUrlString:urlString];
        } else {
            BDSKBookmark *bookmark = [[BDSKBookmark alloc] initWithUrlString:urlString name:[self uniqueName]];
            if (idx == NSOutlineViewDropOnItemIndex)
                idx = [[self childrenOfBookmark:item] count];
            [self bookmark:item insertChildBookmark:bookmark atIndex:idx];
            [bookmark release];
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
    if ([[tableColumn identifier] isEqualToString:@"url"]) {
        if ([item bookmarkType] == BDSKBookmarkTypeFolder)
            [cell setTextColor:[NSColor disabledControlTextColor]];
        else
            [cell setTextColor:[NSColor controlTextColor]];
    }
}

- (BOOL)outlineView:(NSOutlineView *)ov shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if ([item bookmarkType] == BDSKBookmarkTypeBookmark)
        return YES;
    else if ([item bookmarkType] == BDSKBookmarkTypeFolder)
        return [[tableColumn identifier] isEqualToString:@"name"];
    return NO;
}

- (NSString *)outlineView:(NSOutlineView *)ov toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tc item:(id)item mouseLocation:(NSPoint)mouseLocation {
    NSString *tcID = [tc identifier];
    
    if ([tcID isEqualToString:@"name"]) {
        return [item name];
    } else if ([tcID isEqualToString:@"url"]) {
        return [item urlString];
    }
    return nil;
}

- (void)tableView:(NSTableView *)tv deleteRows:(NSArray *)rows {
    NSMutableArray *items = [NSMutableArray array];
    NSEnumerator *rowEnum = [rows objectEnumerator];
    NSNumber *row;
    
    while (row = [rowEnum nextObject])
        [items addObject:[outlineView itemAtRow:[row intValue]]];
    
    NSEnumerator *itemEnum = [[self minimumCoverForBookmarks:items] reverseObjectEnumerator];
    BDSKBookmark *item;
    
    while (item = [itemEnum  nextObject])
        [self removeChildBookmark:item];
}

- (BOOL)outlineView:(NSOutlineView *)ov drawSeparatorRowForItem:(id)item {
    return [item bookmarkType] == BDSKBookmarkTypeSeparator;
}

#pragma mark Toolbar

- (void)setupToolbar {
    // Create a new toolbar instance, and attach it to our document window
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:BDSKBookmarksToolbarIdentifier] autorelease];
    OAToolbarItem *item;
    
    toolbarItems = [[NSMutableDictionary alloc] initWithCapacity:3];
    
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeDefault];
    
    // We are the delegate
    [toolbar setDelegate: self];
    
    // Add template toolbar items
    
    item = [[OAToolbarItem alloc] initWithItemIdentifier:BDSKBookmarksNewBookmarkToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"New Bookmark", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"New Bookmark", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Add a New Bookmark", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"NewBookmark"]];
    [item setTarget:self];
    [item setAction:@selector(insertBookmark:)];
    [toolbarItems setObject:item forKey:BDSKBookmarksNewBookmarkToolbarItemIdentifier];
    [item release];
    
    item = [[OAToolbarItem alloc] initWithItemIdentifier:BDSKBookmarksNewFolderToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"New Folder", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"New Folder", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Add a New Folder", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"NewFolder"]];
    [item setTarget:self];
    [item setAction:@selector(insertBookmarkFolder:)];
    [toolbarItems setObject:item forKey:BDSKBookmarksNewFolderToolbarItemIdentifier];
    [item release];
    
    item = [[OAToolbarItem alloc] initWithItemIdentifier:BDSKBookmarksNewSeparatorToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"New Separator", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"New Separator", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Add a New Separator", @"Tool tip message")];
    [item setImage:[NSImage imageNamed:@"NewSeparator"]];
    [item setTarget:self];
    [item setAction:@selector(insertBookmarkSeparator:)];
    [toolbarItems setObject:item forKey:BDSKBookmarksNewSeparatorToolbarItemIdentifier];
    [item release];
    
    item = [[OAToolbarItem alloc] initWithItemIdentifier:BDSKBookmarksDeleteToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"Delete", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Delete", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Delete Selected Items", @"Tool tip message")];
    [item setImage:[NSImage imageWithLargeIconForToolboxCode:kToolbarDeleteIcon]];
    [item setTarget:self];
    [item setAction:@selector(deleteBookmark:)];
    [toolbarItems setObject:item forKey:BDSKBookmarksDeleteToolbarItemIdentifier];
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
        BDSKBookmarksNewBookmarkToolbarItemIdentifier, 
        BDSKBookmarksNewFolderToolbarItemIdentifier, 
        BDSKBookmarksNewSeparatorToolbarItemIdentifier, 
        BDSKBookmarksDeleteToolbarItemIdentifier, nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return [NSArray arrayWithObjects: 
        BDSKBookmarksNewBookmarkToolbarItemIdentifier, 
        BDSKBookmarksNewFolderToolbarItemIdentifier, 
        BDSKBookmarksNewSeparatorToolbarItemIdentifier, 
		BDSKBookmarksDeleteToolbarItemIdentifier, 
        NSToolbarFlexibleSpaceItemIdentifier, 
		NSToolbarSpaceItemIdentifier, 
		NSToolbarSeparatorItemIdentifier, 
		NSToolbarCustomizeToolbarItemIdentifier, nil];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem {
    NSString *identifier = [toolbarItem itemIdentifier];
    if ([identifier isEqualToString:BDSKBookmarksDeleteToolbarItemIdentifier]) {
        return [outlineView numberOfSelectedRows] > 0;
    } else {
        return YES;
    }
}

@end


@implementation BDSKBookmark

- (id)initWithUrlString:(NSString *)aUrlString name:(NSString *)aName {
    if (self = [super init]) {
        bookmarkType = BDSKBookmarkTypeBookmark;
        urlString = [aUrlString copy];
        name = [aName copy];
        children = nil;
    }
    return self;
}

- (id)initFolderWithChildren:(NSArray *)aChildren name:(NSString *)aName {
    if (self = [super init]) {
        bookmarkType = BDSKBookmarkTypeFolder;
        urlString = nil;
        name = [aName copy];
        children = [aChildren mutableCopy];
        [children makeObjectsPerformSelector:@selector(setParent:) withObject:self];
    }
    return self;
}

- (id)initFolderWithName:(NSString *)aName {
    return [self initFolderWithChildren:[NSArray array] name:aName];
}

- (id)initSeparator {
    if (self = [super init]) {
        bookmarkType = BDSKBookmarkTypeSeparator;
        urlString = nil;
        name = nil;
        children = nil;
    }
    return self;
}

- (id)init {
    return [self initWithUrlString:@"http://" name:[[BDSKBookmarkController sharedBookmarkController] uniqueName]];
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if ([[dictionary objectForKey:TYPE_KEY] isEqualToString:BDSKBookmarkTypeFolderString]) {
        NSEnumerator *dictEnum = [[dictionary objectForKey:CHILDREN_KEY] objectEnumerator];
        NSDictionary *dict;
        NSMutableArray *newChildren = [NSMutableArray array];
        while (dict = [dictEnum nextObject])
            [newChildren addObject:[[[[self class] alloc] initWithDictionary:dict] autorelease]];
        return [self initFolderWithChildren:newChildren name:[dictionary objectForKey:TITLE_KEY]];
    } else if ([[dictionary objectForKey:TYPE_KEY] isEqualToString:BDSKBookmarkTypeSeparatorString]) {
        return [self initSeparator];
    } else {
        return [self initWithUrlString:[dictionary objectForKey:URL_KEY] name:[dictionary objectForKey:TITLE_KEY]];
    }
}

- (id)copyWithZone:(NSZone *)aZone {
    if (bookmarkType == BDSKBookmarkTypeFolder)
        return [[[self class] allocWithZone:aZone] initFolderWithChildren:[[[NSArray alloc] initWithArray:children copyItems:YES] autorelease] name:name];
    else if (bookmarkType == BDSKBookmarkTypeSeparator)
        return [[[self class] allocWithZone:aZone] initSeparator];
    else
    return [[[self class] allocWithZone:aZone] initWithUrlString:urlString name:name];
}

- (void)dealloc {
    [[[BDSKBookmarkController sharedBookmarkController] undoManager] removeAllActionsWithTarget:self];
    [urlString release];
    [name release];
    [children release];
    [super dealloc];
}

- (NSString *)description {
    if (bookmarkType == BDSKBookmarkTypeFolder)
        return [NSString stringWithFormat:@"<%@: name=%@, children=%@>", [self class], name, children];
    else if (bookmarkType == BDSKBookmarkTypeSeparator)
        return [NSString stringWithFormat:@"<%@: separator>", [self class]];
    else
        return [NSString stringWithFormat:@"<%@: name=%@, URL=%@>", [self class], name, urlString];
}

- (NSDictionary *)dictionaryValue {
    if (bookmarkType == BDSKBookmarkTypeFolder)
        return [NSDictionary dictionaryWithObjectsAndKeys:BDSKBookmarkTypeFolderString, TYPE_KEY, [children valueForKey:@"dictionaryValue"], CHILDREN_KEY, name, TITLE_KEY, nil];
    else if (bookmarkType == BDSKBookmarkTypeSeparator)
        return [NSDictionary dictionaryWithObjectsAndKeys:BDSKBookmarkTypeSeparatorString, TYPE_KEY, nil];
    else
        return [NSDictionary dictionaryWithObjectsAndKeys:BDSKBookmarkTypeBookmarkString, TYPE_KEY, urlString, URL_KEY, name, TITLE_KEY, nil];
}

- (int)bookmarkType {
    return bookmarkType;
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

- (NSImage *)icon {
    if ([self bookmarkType] == BDSKBookmarkTypeFolder)
        return [NSImage imageNamed:@"SmallFolder"];
    else if (bookmarkType == BDSKBookmarkTypeSeparator)
        return nil;
    else
        return [NSImage imageNamed:@"SmallBookmark"];
}

- (BDSKBookmark *)parent {
    return parent;
}

- (void)setParent:(BDSKBookmark *)newParent {
    parent = newParent;
}

- (NSArray *)children {
    return children;
}

- (void)insertChild:(BDSKBookmark *)child atIndex:(unsigned int)idx {
    NSUndoManager *undoManager = [[BDSKBookmarkController sharedBookmarkController] undoManager];
    [(BDSKBookmark *)[undoManager prepareWithInvocationTarget:self] removeChild:child];
    [children insertObject:child atIndex:idx];
    [child setParent:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKBookmarkChangedNotification object:self];
}

- (void)addChild:(BDSKBookmark *)child {
    [self insertChild:child atIndex:[children count]];
}

- (void)removeChild:(BDSKBookmark *)child {
    NSUndoManager *undoManager = [[BDSKBookmarkController sharedBookmarkController] undoManager];
    [(BDSKBookmark *)[undoManager prepareWithInvocationTarget:self] insertChild:child atIndex:[[self children] indexOfObject:child]];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKBookmarkWillBeRemovedNotification object:self];
    [child setParent:nil];
    [children removeObject:child];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKBookmarkChangedNotification object:self];
}

- (BOOL)isDescendantOf:(BDSKBookmark *)bookmark {
    if (self == bookmark)
        return YES;
    NSEnumerator *childEnum = [[bookmark children] objectEnumerator];
    BDSKBookmark *child;
    while (child = [childEnum nextObject]) {
        if ([self isDescendantOf:child])
            return YES;
    }
    return NO;
}

- (BOOL)isDescendantOfArray:(NSArray *)bookmarks {
    NSEnumerator *bmEnum = [bookmarks objectEnumerator];
    BDSKBookmark *bm = nil;
    while (bm = [bmEnum nextObject]) {
        if ([self isDescendantOf:bm]) return YES;
    }
    return NO;
}

@end

#pragma mark -

@implementation WebView (BDSKExtensions)

- (IBAction)addBookmark:(id)sender {
	WebDataSource *datasource = [[self mainFrame] dataSource];
	NSString *URLString = [[[datasource request] URL] absoluteString];
	NSString *name = [datasource pageTitle];
	if(name == nil) name = [URLString lastPathComponent];
    
    if (URLString)
        [[BDSKBookmarkController sharedBookmarkController] addBookmarkWithUrlString:URLString proposedName:name modalForWindow:[self window]];
}

@end

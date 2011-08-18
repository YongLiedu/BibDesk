//
//  BDSKBookmarkController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/18/07.
/*
 This software is Copyright (c) 2007-2011
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
#import "BDSKBookmark.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BibDocument.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKOutlineView.h"
#import "BDSKTextWithIconCell.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKSeparatorCell.h"
#import "NSMenu_BDSKExtensions.h"
#import "BDSKBookmarkSheetController.h"
#import "NSWindowController_BDSKExtensions.h"

#define BDSKBookmarksWindowFrameAutosaveName @"BDSKBookmarksWindow"

#define BDSKBookmarkRowsPboardType @"BDSKBookmarkRowsPboardType"

#define BDSKBookmarksToolbarIdentifier                  @"BDSKBookmarksToolbarIdentifier"
#define BDSKBookmarksNewBookmarkToolbarItemIdentifier   @"BDSKBookmarksNewBookmarkToolbarItemIdentifier"
#define BDSKBookmarksNewFolderToolbarItemIdentifier     @"BDSKBookmarksNewFolderToolbarItemIdentifier"
#define BDSKBookmarksNewSeparatorToolbarItemIdentifier  @"BDSKBookmarksNewSeparatorToolbarItemIdentifier"
#define BDSKBookmarksDeleteToolbarItemIdentifier        @"BDSKBookmarksDeleteToolbarItemIdentifier"

#define CHILDREN_KEY    @"children"
#define NAME_KEY        @"name"
#define URLSTRING_KEY   @"urlString"

static char BDSKBookmarkPropertiesObservationContext;


@interface BDSKBookmarkController (BDSKPrivate)
- (void)setupToolbar;
- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification;
- (void)endEditing;
- (void)startObservingBookmarks:(NSArray *)newBookmarks;
- (void)stopObservingBookmarks:(NSArray *)oldBookmarks;
@end

@implementation BDSKBookmarkController

static id sharedBookmarkController = nil;

+ (id)sharedBookmarkController {
    if (sharedBookmarkController == nil)
        [[[self alloc] init] autorelease];
    return sharedBookmarkController;
}

+ (id)allocWithZone:(NSZone *)zone {
    return [sharedBookmarkController retain] ?: [super allocWithZone:zone];
}

- (id)init {
    if (sharedBookmarkController == nil) {
        self = [super initWithWindowNibName:@"BookmarksWindow"];
        if (self) {
            undoManager = nil;
            
            NSMutableArray *bookmarks = [NSMutableArray array];
            NSString *applicationSupportPath = [[NSFileManager defaultManager] applicationSupportDirectory]; 
            NSString *bookmarksPath = [applicationSupportPath stringByAppendingPathComponent:@"Bookmarks.plist"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:bookmarksPath]) {
                for (NSDictionary *dict in [NSArray arrayWithContentsOfFile:bookmarksPath]) {
                    BDSKBookmark *bookmark = [[BDSKBookmark alloc] initWithDictionary:dict];
                    if (bookmark) {
                        [bookmarks addObject:bookmark];
                        [bookmark release];
                    } else
                        NSLog(@"Failed to read bookmark: %@", dict);
                }
            }
            
            bookmarkRoot = [[BDSKBookmark alloc] initRootWithChildren:bookmarks];
            [self startObservingBookmarks:[NSArray arrayWithObject:bookmarkRoot]];
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillTerminateNotification:) name:NSApplicationWillTerminateNotification object:nil];
        }
        sharedBookmarkController = [self retain];
    } else if (self != sharedBookmarkController) {
        BDSKASSERT_NOT_REACHED("shouldn't be able to create multiple instances");
        [self release];
        self = [sharedBookmarkController retain];
    }
    return self;
}

- (void)windowDidLoad {
    [self setupToolbar];
    [self setWindowFrameAutosaveName:BDSKBookmarksWindowFrameAutosaveName];
    [outlineView setAutoresizesOutlineColumn:NO];
    [outlineView registerForDraggedTypes:[NSArray arrayWithObjects:BDSKBookmarkRowsPboardType, BDSKWeblocFilePboardType, NSURLPboardType, nil]];
}

- (BDSKBookmark *)bookmarkRoot {
    return bookmarkRoot;
}

static NSArray *minimumCoverForBookmarks(NSArray *items) {
    BDSKBookmark *lastBm = nil;
    NSMutableArray *minimalCover = [NSMutableArray array];
    
    for (BDSKBookmark *bm in items) {
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
    BDSKBookmark *bookmark = [BDSKBookmark bookmarkWithUrlString:urlString name:name];
    if (bookmark) {
        if (folder == nil) folder = bookmarkRoot;
        [folder insertObject:bookmark inChildrenAtIndex:[folder countOfChildren]];
    }
}

- (void)addBookmarkSheetDidEnd:(BDSKBookmarkSheetController *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    NSString *urlString = (NSString *)contextInfo;
	if (returnCode == NSOKButton) {
        [self addBookmarkWithUrlString:urlString name:[sheet stringValue] toFolder:[sheet selectedFolder]];
	}
    [urlString release]; //the contextInfo was retained
}

- (void)addMenuItemsForBookmarks:(NSArray *)bookmarksArray level:(NSInteger)level toMenu:(NSMenu *)menu {
    for (BDSKBookmark *bm in bookmarksArray) {
        if ([bm bookmarkType] == BDSKBookmarkTypeFolder) {
            NSString *name = [bm name];
            NSMenuItem *item = [menu addItemWithTitle:name ?: @"" action:NULL keyEquivalent:@""];
            [item setImageAndSize:[bm icon]];
            [item setIndentationLevel:level];
            [item setRepresentedObject:bm];
            [self addMenuItemsForBookmarks:[bm children] level:level+1 toMenu:menu];
        }
    }
}

- (void)addBookmarkWithUrlString:(NSString *)urlString proposedName:(NSString *)name modalForWindow:(NSWindow *)window {
    BDSKBookmarkSheetController *bookmarkSheetController = [[[BDSKBookmarkSheetController alloc] init] autorelease];
    NSPopUpButton *folderPopUp = [bookmarkSheetController folderPopUpButton];
    
    [bookmarkSheetController setStringValue:name];
    [folderPopUp removeAllItems];
    [self addMenuItemsForBookmarks:[NSArray arrayWithObjects:bookmarkRoot, nil] level:0 toMenu:[folderPopUp menu]];
    [folderPopUp selectItemAtIndex:0];
	
    [bookmarkSheetController beginSheetModalForWindow:window 
                                        modalDelegate:self
                                       didEndSelector:@selector(addBookmarkSheetDidEnd:returnCode:contextInfo:)
                                          contextInfo:[urlString retain]];
}

#pragma mark Actions

- (IBAction)insertBookmark:(id)sender {
    BDSKBookmark *bookmark = [BDSKBookmark bookmarkWithUrlString:@"http://" name:nil];
    NSInteger rowIndex = [[outlineView selectedRowIndexes] lastIndex];
    BDSKBookmark *item = bookmarkRoot;
    NSUInteger idx = [[bookmarkRoot children] count];
    
    if (rowIndex != NSNotFound) {
        BDSKBookmark *selectedItem = [outlineView itemAtRow:rowIndex];
        if ([outlineView isItemExpanded:selectedItem]) {
            item = selectedItem;
            idx = [[item children] count];
        } else {
            item = [selectedItem parent];
            idx = [[item children] indexOfObject:selectedItem] + 1;
        }
    }
    [item insertObject:bookmark inChildrenAtIndex:idx];
    
    NSInteger row = [outlineView rowForItem:bookmark];
    [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [outlineView editColumn:0 row:row withEvent:nil select:YES];
}

- (IBAction)insertBookmarkFolder:(id)sender {
    BDSKBookmark *folder = [BDSKBookmark bookmarkFolderWithName:NSLocalizedString(@"Folder", @"default folder name")];
    NSInteger rowIndex = [[outlineView selectedRowIndexes] lastIndex];
    BDSKBookmark *item = bookmarkRoot;
    NSUInteger idx = [[bookmarkRoot children] count];
    
    if (rowIndex != NSNotFound) {
        BDSKBookmark *selectedItem = [outlineView itemAtRow:rowIndex];
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
    BDSKBookmark *separator = [BDSKBookmark bookmarkSeparator];
    NSInteger rowIndex = [[outlineView selectedRowIndexes] lastIndex];
    BDSKBookmark *item = bookmarkRoot;
    NSUInteger idx = [[bookmarkRoot children] count];
    
    if (rowIndex != NSNotFound) {
        BDSKBookmark *selectedItem = [outlineView itemAtRow:rowIndex];
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

#pragma mark Notification handlers

- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification {
	NSString *error = nil;
	NSData *data = [NSPropertyListSerialization dataFromPropertyList:[[bookmarkRoot children] valueForKey:@"dictionaryValue"]
															  format:NSPropertyListXMLFormat_v1_0 
													errorDescription:&error];
	if (error) {
		NSLog(@"Error writing bookmarks: %@", error);
        [error release];
		return;
	}
	
	NSString *applicationSupportPath = [[NSFileManager defaultManager] applicationSupportDirectory]; 
	NSString *bookmarksPath = [applicationSupportPath stringByAppendingPathComponent:@"Bookmarks.plist"];
	[data writeToFile:bookmarksPath atomically:YES];
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
    for (BDSKBookmark *bm in newBookmarks) {
        if ([bm bookmarkType] != BDSKBookmarkTypeSeparator) {
            [bm addObserver:self forKeyPath:NAME_KEY options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&BDSKBookmarkPropertiesObservationContext];
            [bm addObserver:self forKeyPath:URLSTRING_KEY options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&BDSKBookmarkPropertiesObservationContext];
            if ([bm bookmarkType] == BDSKBookmarkTypeFolder) {
                [bm addObserver:self forKeyPath:CHILDREN_KEY options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&BDSKBookmarkPropertiesObservationContext];
                [self startObservingBookmarks:[bm children]];
            }
        }
    }
}

- (void)stopObservingBookmarks:(NSArray *)oldBookmarks {
    for (BDSKBookmark *bm in oldBookmarks) {
        if ([bm bookmarkType] != BDSKBookmarkTypeSeparator) {
            [bm removeObserver:self forKeyPath:NAME_KEY];
            [bm removeObserver:self forKeyPath:URLSTRING_KEY];
            if ([bm bookmarkType] == BDSKBookmarkTypeFolder) {
                [bm removeObserver:self forKeyPath:CHILDREN_KEY];
                [self stopObservingBookmarks:[bm children]];
            }
        }
    }
}

- (void)setChildren:(NSArray *)newChildren ofBookmark:(BDSKBookmark *)bookmark {
    [[bookmark mutableArrayValueForKey:CHILDREN_KEY] setArray:newChildren];
}

- (void)insertObjects:(NSArray *)newChildren inChildrenOfBookmark:(BDSKBookmark *)bookmark atIndexes:(NSIndexSet *)indexes {
    [[bookmark mutableArrayValueForKey:CHILDREN_KEY] insertObjects:newChildren atIndexes:indexes];
}

- (void)removeObjectsFromChildrenOfBookmark:(BDSKBookmark *)bookmark atIndexes:(NSIndexSet *)indexes {
    [[bookmark mutableArrayValueForKey:CHILDREN_KEY] removeObjectsAtIndexes:indexes];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &BDSKBookmarkPropertiesObservationContext) {
        BDSKBookmark *bookmark = (BDSKBookmark *)object;
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
                } else if ([keyPath isEqualToString:NAME_KEY]) {
                    [(BDSKBookmark *)[[self undoManager] prepareWithInvocationTarget:bookmark] setName:oldValue];
                } else if ([keyPath isEqualToString:URLSTRING_KEY]) {
                    [[[self undoManager] prepareWithInvocationTarget:bookmark] setUrlString:oldValue];
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
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark NSOutlineView datasource methods

- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item {
    return [[(item ?: bookmarkRoot) children] count];
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item {
    return [item bookmarkType] == BDSKBookmarkTypeFolder;
}

- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)idx ofItem:(id)item {
    return [[(item ?: bookmarkRoot) children]  objectAtIndex:idx];
}

- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    NSString *tcID = [tableColumn identifier];
    if ([tcID isEqualToString:@"name"]) {
        return [NSDictionary dictionaryWithObjectsAndKeys:[item name], BDSKTextWithIconCellStringKey, [item icon], BDSKTextWithIconCellImageKey, nil];
    } else if ([tcID isEqualToString:@"url"]) {
        if ([item bookmarkType] == BDSKBookmarkTypeFolder) {
            NSInteger count = [[item children] count];
            return count == 1 ? NSLocalizedString(@"1 item", @"Bookmark folder description") : [NSString stringWithFormat:NSLocalizedString(@"%ld items", @"Bookmark folder description"), (long)count];
        } else {
            return [item urlString];
        }
    }
    return nil;
}

- (void)outlineView:(NSOutlineView *)ov setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    NSString *tcID = [tableColumn identifier];
    if ([tcID isEqualToString:@"name"]) {
        // the editied object is always an NSDictionary, see BDSKTextWithIconFormatter
        NSString *newName = [object valueForKey:BDSKTextWithIconCellStringKey] ?: @"";
        if ([newName isEqualToString:[item name]] == NO)
            [(BDSKBookmark *)item setName:newName];
    } else if ([tcID isEqualToString:@"url"]) {
        if ([(NSString *)object length] == 0 || [NSURL URLWithString:object] == nil) {
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
    if (pboard == [NSPasteboard pasteboardWithName:NSDragPboard]) {
        [self setDraggedBookmarks:minimumCoverForBookmarks(items)];
        [pboard declareTypes:[NSArray arrayWithObjects:BDSKBookmarkRowsPboardType, nil] owner:nil];
        [pboard setData:[NSData data] forType:BDSKBookmarkRowsPboardType];
        return YES;
    }
    return NO;
}

- (NSDragOperation)outlineView:(NSOutlineView *)ov validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)idx {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBookmarkRowsPboardType, BDSKWeblocFilePboardType, NSURLPboardType, nil]];
    
    if ([type isEqualToString:BDSKBookmarkRowsPboardType]) {
        if (idx == NSOutlineViewDropOnItemIndex) {
            if ([item bookmarkType] == BDSKBookmarkTypeFolder && [outlineView isItemExpanded:item]) {
                [ov setDropItem:item dropChildIndex:0];
            } else if (item) {
                [ov setDropItem:(BDSKBookmark *)[item parent] == bookmarkRoot ? nil : [item parent] dropChildIndex:[[[item parent] children] indexOfObject:item] + 1];
            } else {
                [ov setDropItem:nil dropChildIndex:[[bookmarkRoot children] count]];
            }
        }
        return [item isDescendantOfArray:[self draggedBookmarks]] ? NSDragOperationNone : NSDragOperationMove;
    } else if (type) {
        if (idx == NSOutlineViewDropOnItemIndex && (item == nil || [item bookmarkType] != BDSKBookmarkTypeBookmark)) {
            if ([item bookmarkType] == BDSKBookmarkTypeFolder && [outlineView isItemExpanded:item]) {
                [ov setDropItem:item dropChildIndex:0];
            } else if (item) {
                [ov setDropItem:(BDSKBookmark *)[item parent] == bookmarkRoot ? nil : [item parent] dropChildIndex:[[[item parent] children] indexOfObject:item] + 1];
            } else {
                [ov setDropItem:nil dropChildIndex:[[bookmarkRoot children] count]];
            }
        }
        return NSDragOperationEvery;
    }
    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)ov acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)idx {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBookmarkRowsPboardType, BDSKWeblocFilePboardType, NSURLPboardType, nil]];
    
    if (item == nil) item = bookmarkRoot;
    
    if ([type isEqualToString:BDSKBookmarkRowsPboardType]) {
        [self endEditing];
        
		for (BDSKBookmark *bookmark in [self draggedBookmarks]) {
            BDSKBookmark *parent = [bookmark parent];
            NSInteger bookmarkIndex = [[parent children] indexOfObject:bookmark];
            if (item == parent) {
                if (idx > bookmarkIndex)
                    idx--;
                if (idx == bookmarkIndex)
                    continue;
            }
            [parent removeObjectFromChildrenAtIndex:bookmarkIndex];
            [(BDSKBookmark *)item insertObject:bookmark inChildrenAtIndex:idx++];
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
        if (idx == NSOutlineViewDropOnItemIndex && [item bookmarkType] == BDSKBookmarkTypeBookmark) {
            [item setUrlString:urlString];
        } else {
            BDSKBookmark *bookmark = [BDSKBookmark bookmarkWithUrlString:urlString name:nil];
            if (idx == NSOutlineViewDropOnItemIndex)
                idx = [[item children] count];
            if (bookmark)
                [(BDSKBookmark *)item insertObject:bookmark inChildrenAtIndex:idx];
        }
        return YES;
    }
    return NO;
}

- (void)outlineView:(NSOutlineView *)anOutlineView concludeDragOperation:(NSDragOperation)operation {
    [self setDraggedBookmarks:nil];
}

- (BOOL)outlineView:(NSOutlineView *)ov canCopyItems:(NSArray *)items {
    return NO;
}

#pragma mark NSOutlineView delegate methods

- (NSCell *)outlineView:(NSOutlineView *)ov dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if (tableColumn == nil)
        return [item bookmarkType] == BDSKBookmarkTypeSeparator ? [[[BDSKSeparatorCell alloc] init] autorelease] : nil;
    return [tableColumn dataCellForRow:[ov rowForItem:item]];
}

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

- (void)outlineView:(NSOutlineView *)ov deleteItems:(NSArray *)items {
    [self endEditing];
    
    for (BDSKBookmark *item in [minimumCoverForBookmarks(items) reverseObjectEnumerator]) {
        BDSKBookmark *parent = [item parent];
        NSUInteger itemIndex = [[parent children] indexOfObject:item];
        if (itemIndex != NSNotFound)
            [parent removeObjectFromChildrenAtIndex:itemIndex];
    }
}

#pragma mark Toolbar

- (void)setupToolbar {
    // Create a new toolbar instance, and attach it to our document window
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:BDSKBookmarksToolbarIdentifier] autorelease];
    NSToolbarItem *item;
    
    toolbarItems = [[NSMutableDictionary alloc] initWithCapacity:3];
    
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeDefault];
    
    // We are the delegate
    [toolbar setDelegate: self];
    
    // Add template toolbar items
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:BDSKBookmarksNewBookmarkToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"New Bookmark", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"New Bookmark", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Add a New Bookmark", @"Tool tip message")];
    [item setImage:[NSImage addBookmarkToolbarImage]];
    [item setTarget:self];
    [item setAction:@selector(insertBookmark:)];
    [toolbarItems setObject:item forKey:BDSKBookmarksNewBookmarkToolbarItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:BDSKBookmarksNewFolderToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"New Folder", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"New Folder", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Add a New Folder", @"Tool tip message")];
    [item setImage:[NSImage addFolderToolbarImage]];
    [item setTarget:self];
    [item setAction:@selector(insertBookmarkFolder:)];
    [toolbarItems setObject:item forKey:BDSKBookmarksNewFolderToolbarItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:BDSKBookmarksNewSeparatorToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"New Separator", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"New Separator", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Add a New Separator", @"Tool tip message")];
    [item setImage:[NSImage addSeparatorToolbarImage]];
    [item setTarget:self];
    [item setAction:@selector(insertBookmarkSeparator:)];
    [toolbarItems setObject:item forKey:BDSKBookmarksNewSeparatorToolbarItemIdentifier];
    [item release];
    
    item = [[NSToolbarItem alloc] initWithItemIdentifier:BDSKBookmarksDeleteToolbarItemIdentifier];
    [item setLabel:NSLocalizedString(@"Delete", @"Toolbar item label")];
    [item setPaletteLabel:NSLocalizedString(@"Delete", @"Toolbar item label")];
    [item setToolTip:NSLocalizedString(@"Delete Selected Items", @"Tool tip message")];
    [item setImage:[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kToolbarDeleteIcon)]];
    [item setTarget:self];
    [item setAction:@selector(deleteBookmark:)];
    [toolbarItems setObject:item forKey:BDSKBookmarksDeleteToolbarItemIdentifier];
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

//
//  BibPref_Export.m
//  Bibdesk
//
//  Created by Adam Maxwell on 05/18/06.
/*
 This software is Copyright (c) 2006
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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

#import "BibPref_Export.h"
#import "BibTypeManager.h"
#import "BDAlias.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKTemplate.h"

static NSString *BDSKTemplateRowsPboardType = @"BDSKTemplateRowsPboardType";

@implementation BibPref_Export

- (void)doInitialSetup
{
    if(nil == itemNodes)
        itemNodes = [[NSMutableArray alloc] initWithCapacity:5];
    else
        [itemNodes removeAllObjects];
    
    BDSKTemplate *template = nil;
    
    // HTML template
    template = [[BDSKTemplate alloc] init];
    [template setValue:@"Default HTML template" forKey:BDSKTemplateNameString];
    [template setValue:@"html" forKey:BDSKTemplateRoleString];
    [itemNodes addObject:template];
    [template release];
            
    // main page template
    NSURL *fileURL = [NSURL fileURLWithPath:[[[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:@"htmlExportTemplate"]];
    [template addChildWithURL:fileURL role:BDSKTemplateMainPageString];
    
    // a user could potentially have templates for multiple BibTeX types; we could add all of those, as well
    fileURL = [NSURL fileURLWithPath:[[[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:@"htmlItemExportTemplate"]];
    [template addChildWithURL:fileURL role:BDSKTemplateDefaultItemString];
    
    // RTF template
    template = [[BDSKTemplate alloc] init];
    [template setValue:@"Default RTF template" forKey:BDSKTemplateNameString];
    [template setValue:@"rtf" forKey:BDSKTemplateRoleString];
    [itemNodes addObject:template];
    [template release];
    fileURL = [NSURL fileURLWithPath:[[[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:@"rtfExportTemplate"]];
    [template addChildWithURL:fileURL role:BDSKTemplateMainPageString];
        
    // RSS template
    template = [[BDSKTemplate alloc] init];
    [template setValue:@"Default RSS template" forKey:BDSKTemplateNameString];
    [template setValue:@"rss" forKey:BDSKTemplateRoleString];
    [itemNodes addObject:template];
    [template release];
    fileURL = [NSURL fileURLWithPath:[[[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:@"rssExportTemplate"]];
    [template addChildWithURL:fileURL role:BDSKTemplateMainPageString];    
        
    // Doc template
    template = [[BDSKTemplate alloc] init];
    [template setValue:@"Default Doc template" forKey:BDSKTemplateNameString];
    [template setValue:@"doc" forKey:BDSKTemplateRoleString];
    [itemNodes addObject:template];
    [template release];
    fileURL = [NSURL fileURLWithPath:[[[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:@"docExportTemplate"]];
    [template addChildWithURL:fileURL role:BDSKTemplateMainPageString];    
}

- (void)restoreDefaultsNoPrompt;
{
    [super restoreDefaultsNoPrompt];
    [self doInitialSetup];
    [self updateUI];
}

- (void)awakeFromNib
{    
        
    [super awakeFromNib];
    
    NSData *data = [defaults objectForKey:BDSKExportTemplateTree];
    if([data length]){
        itemNodes = [[NSKeyedUnarchiver unarchiveObjectWithData:data] mutableCopy];
    } else {
        [self doInitialSetup];
    }

    fileTypes = [[NSArray alloc] initWithObjects:@"html", @"rss", @"csv", @"rtf", @"doc", nil];
    
    roles = [[NSMutableArray alloc] initWithObjects:BDSKTemplateMainPageString, BDSKTemplateDefaultItemString, BDSKTemplateAccessoryString, nil];
    [roles addObjectsFromArray:[[BibTypeManager sharedManager] bibTypesForFileType:BDSKBibtexString]];

    [outlineView setAutosaveExpandedItems:YES];
    
    // Default behavior is to expand column 0, which slides column 1 outside the clip view; since we only have one expandable column, this is more annoying than helpful.
    [outlineView setAutoresizesOutlineColumn:NO];
    
    [outlineView registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, BDSKTemplateRowsPboardType, nil]];
    
    // this will synchronize prefs, as well
    [self updateUI];
}

- (void)dealloc
{
    [itemNodes release];
    [roles release];
    [fileTypes release];
    [super dealloc];
}

- (void)synchronizePrefs
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:itemNodes];
    if(nil != data)
        [defaults setObject:data forKey:BDSKExportTemplateTree];
    else
        NSLog(@"Unable to archive %@", itemNodes);
}

- (void)updateUI
{
    [outlineView reloadData];
    [self synchronizePrefs];
}

- (IBAction)addNode:(id)sender;
{
    // may be nil
    BDSKTreeNode *selectedNode = [outlineView selectedItem];
    BDSKTemplate *newNode = [[BDSKTemplate alloc] init];

    if([selectedNode isLeaf]){
        // add as a sibling of the selected node
        [[selectedNode parent] addChild:newNode];
    } else if(nil != selectedNode && [outlineView isItemExpanded:selectedNode]){
        // add as a child of the selected node
        [selectedNode addChild:newNode];
    } else {
        // add as a non-leaf node
        [itemNodes addObject:newNode];
        
        // each style needs at least a Main Page child, and newNode will be recognized as a non-leaf node
        BDSKTemplate *child = [[BDSKTemplate alloc] init];
        [child setValue:BDSKTemplateMainPageString forKey:BDSKTemplateRoleString];
        [newNode addChild:child];
        [child release];
    }
    
    [self updateUI];
    [outlineView expandItem:newNode];
    [newNode release];
}

- (IBAction)removeNode:(id)sender;
{
    BDSKTreeNode *selectedNode = [outlineView selectedItem];
    if(nil != selectedNode){
        if([selectedNode isLeaf])
            [[selectedNode parent] removeChild:selectedNode];
        else
            [itemNodes removeObject:selectedNode];
    } else {
        NSBeep();
    }
    [self updateUI];
}

#pragma mark Outline View

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item
{
    return item ? (NO == [item isLeaf]) : YES;
}

- (int)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item
{ 
    return item ? [item numberOfChildren] : [itemNodes count];
}

- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    NSString *identifier = [tableColumn identifier];
    id value = [item valueForKey:identifier];
    if (value == nil) {
        // set some placeholder message, this will show up in red
        if ([identifier isEqualToString:BDSKTemplateRoleString])
            value = ([item isLeaf]) ? NSLocalizedString(@"Choose role",@"") : NSLocalizedString(@"Choose file type",@"");
        else if ([identifier isEqualToString:BDSKTemplateNameString])
            value = ([item isLeaf]) ? NSLocalizedString(@"Double-click to choose file",@"") : NSLocalizedString(@"Double-click to change name",@"");
    }
    return value;
}

- (id)outlineView:(NSOutlineView *)ov child:(int)index ofItem:(id)item
{
    return nil == item ? [itemNodes objectAtIndex:index] : [[item children] objectAtIndex:index];
}

- (id)outlineView:(NSOutlineView *)ov itemForPersistentObject:(id)object
{
    return [NSKeyedUnarchiver unarchiveObjectWithData:object];
}

// return archived item
- (id)outlineView:(NSOutlineView *)ov persistentObjectForItem:(id)item
{
    return [NSKeyedArchiver archivedDataWithRootObject:item];
}

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(BDSKTemplate *)aNode
{
    NSURL *fileURL = [[panel URLs] lastObject];
    if(NSOKButton == returnCode && nil != fileURL){
        
        // use last path component as file name
        [aNode setValue:[[fileURL path] lastPathComponent] forKey:BDSKTemplateNameString];
        
        // track the file by alias; if this doesn't work, it will show up as red
        [aNode setAliasFromURL:fileURL];
        
        NSString *extension = [[fileURL path] pathExtension];
        if ([NSString isEmptyString:extension] == NO && [[aNode parent] valueForKey:BDSKTemplateRoleString] == nil) 
            [[aNode parent] setValue:extension forKey:BDSKTemplateRoleString];
    }
    [aNode release];
    [panel orderOut:nil];
    [self updateUI];
}

- (BOOL)outlineView:(NSOutlineView *)ov shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item;
{
    // leaf items are fully editable, but you can only edit the name of a parent item

    NSString *identifier = [tableColumn identifier];
    if([item isLeaf]){
        // run an open panel for the filename
        if([identifier isEqualToString:BDSKTemplateNameString]){
            NSOpenPanel *openPanel = [NSOpenPanel openPanel];
            [openPanel setCanChooseDirectories:YES];
            [openPanel setCanCreateDirectories:NO];
            [openPanel setPrompt:NSLocalizedString(@"Choose", @"")];
            
            // start the panel in the same directory as the item's existing path, or fall back to app support
            NSString *dirPath = [[[item representedFileURL] path] stringByDeletingLastPathComponent];
            if(nil == dirPath)
                dirPath = dirPath;
            [openPanel beginSheetForDirectory:dirPath 
                                         file:nil 
                                        types:nil 
                               modalForWindow:[[BDSKPreferenceController sharedPreferenceController] window] 
                                modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) 
                                  contextInfo:[item retain]];
            
            // bypass the normal editing mechanism, or it'll reset the value
            return NO;
        } else if([identifier isEqualToString:BDSKTemplateRoleString]){
            if([[item valueForKey:BDSKTemplateRoleString] isEqualToString:BDSKTemplateMainPageString])
                return NO;
        } else [NSException raise:NSInternalInconsistencyException format:@"Unexpected table column identifier %@", identifier];
    }
    return YES;
}

// return NO to avoid popping the NSOpenPanel unexpectedly
- (BOOL)tableViewShouldEditNextItemWhenEditingEnds:(NSTableView *)tv { return NO; }

// this seems to be called when editing the NSComboBoxCell as well as the parent name
- (void)outlineView:(NSOutlineView *)ov setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item{
    NSString *identifier = [tableColumn identifier];
    if([identifier isEqualToString:BDSKTemplateRoleString] && [item isLeaf] && [object isEqualToString:BDSKTemplateAccessoryString] == NO && [(BDSKTemplate *)[item parent] hasChildWithRole:object]) {
        [outlineView reloadData];
        return;
    }
    [item setValue:object forKey:[tableColumn identifier]];
    [self synchronizePrefs];
}

- (void)outlineView:(NSOutlineView *)ov willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item{
    NSString *identifier = [tableColumn identifier];
    if ([cell respondsToSelector:@selector(setTextColor:)])
        [cell setTextColor:[item representedColorForKey:identifier]];
    if([identifier isEqualToString:BDSKTemplateRoleString]) {
        [cell removeAllItems];
        [cell addItemsWithObjectValues:([item isLeaf]) ? roles : fileTypes];
        if ([item isLeaf] && [[item valueForKey:BDSKTemplateRoleString] isEqualToString:BDSKTemplateMainPageString])
            [cell setEnabled:NO];
        else
            [cell setEnabled:YES];
    }
}

- (BOOL)canDeleteSelectedItem
{
    BDSKTreeNode *selItem = [outlineView selectedItem];
    return ([selItem isLeaf] == NO || [[selItem valueForKey:BDSKTemplateRoleString] isEqualToString:BDSKTemplateMainPageString] == NO);
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification;
{
    [deleteButton setEnabled:[self canDeleteSelectedItem]];
}

- (void)tableView:(NSTableView *)tableView deleteRows:(NSArray *)rows;
{
    // currently we don't allow multiple selection, so we'll ignore the rows argument
    if([self canDeleteSelectedItem])
        [self removeNode:nil];
    else
        NSBeep();
}

#pragma mark Drag / drop

- (BOOL)outlineView:(NSOutlineView *)ov writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard{
    BDSKTemplate *item = [items lastObject];
    if ([item isLeaf] == NO || [[item valueForKey:BDSKTemplateRoleString] isEqualToString:BDSKTemplateMainPageString] == NO) {
        [pboard declareTypes:[NSArray arrayWithObject:BDSKTemplateRowsPboardType] owner:nil];
        [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:[items lastObject]] forType:BDSKTemplateRowsPboardType];
        return YES;
    }
    return NO;
}

- (NSDragOperation)outlineView:(NSOutlineView *)ov validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)index{
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, BDSKTemplateRowsPboardType, nil]];
    
    if ([type isEqualToString:NSFilenamesPboardType]) {
        if ([item isLeaf] && index == NSOutlineViewDropOnItemIndex)
            return NSDragOperationCopy;
        else if ([item isLeaf] == NO && index != NSOutlineViewDropOnItemIndex && index > 0)
            return NSDragOperationCopy;
    } else if ([type isEqualToString:BDSKTemplateRowsPboardType]) {
        if (index == NSOutlineViewDropOnItemIndex)
            return NSDragOperationNone;
        id dropItem = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:BDSKTemplateRowsPboardType]];
        if ([dropItem isLeaf]) {
            if ([[item children] containsObject:dropItem] && index > 0)
                return NSDragOperationMove;
        } else {
            if (item == nil)
                return NSDragOperationMove;
        }
    }
    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)ov acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)index{
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, BDSKTemplateRowsPboardType, nil]];
    
    if ([type isEqualToString:NSFilenamesPboardType]) {
        NSString *fileName = [[pboard propertyListForType:NSFilenamesPboardType] objectAtIndex:0];
        
        if ([item isLeaf] && index == NSOutlineViewDropOnItemIndex) {
            [item setValue:[fileName lastPathComponent] forKey:BDSKTemplateNameString];
            // track the file by alias; if this doesn't work, it will show up as red
            [item setAliasFromURL:[NSURL fileURLWithPath:fileName]];
            NSString *extension = [fileName pathExtension];
            if ([NSString isEmptyString:extension] == NO && [[item parent] valueForKey:BDSKTemplateRoleString] == nil) 
                [[item parent] setValue:extension forKey:BDSKTemplateRoleString];
            [self updateUI];
            return YES;
        } else if ([item isLeaf] == NO && index != NSOutlineViewDropOnItemIndex && index > 0) {
            id newNode = [[BDSKTemplate alloc] init];
            [newNode setValue:[fileName lastPathComponent] forKey:BDSKTemplateNameString];
            [newNode setAliasFromURL:[NSURL fileURLWithPath:fileName]];
            [item insertChild:newNode atIndex:index];
            NSString *extension = [fileName pathExtension];
            if ([NSString isEmptyString:extension] == NO && [item valueForKey:BDSKTemplateRoleString] == nil) 
                [item setValue:extension forKey:BDSKTemplateRoleString];
            [self updateUI];
            return YES;
        }
    } else if ([type isEqualToString:BDSKTemplateRowsPboardType]) {
        id dropItem = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:BDSKTemplateRowsPboardType]];
        if ([dropItem isLeaf]) {
            unsigned int sourceIndex = [[item children] indexOfObject:dropItem];
            if (sourceIndex == NSNotFound)
                return NO;
            if (sourceIndex < index)
                --index;
            [item removeChild:dropItem];
            [item insertChild:dropItem atIndex:index];
            [self updateUI];
            return YES;
        } else {
            unsigned int sourceIndex = [itemNodes indexOfObject:dropItem];
            if (sourceIndex == NSNotFound)
                return NO;
            if (sourceIndex < index)
                --index;
            [[dropItem retain] autorelease];
            [itemNodes removeObjectAtIndex:sourceIndex];
            [itemNodes insertObject:dropItem atIndex:index];
            [self updateUI];
            return YES;
        }
    }
    return NO;
}

#pragma mark ToolTips and Context menu

- (NSString *)tableView:(NSTableView *)tv toolTipForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    NSString *tooltip = nil;
    if(row >= 0){
        id item = [outlineView itemAtRow:row];
        if ([[tableColumn identifier] isEqualToString:BDSKTemplateNameString] && [item isLeaf])
            tooltip = [[item representedFileURL] path];
    }
    return tooltip;
}

- (NSMenu *)tableView:(NSOutlineView *)tv contextMenuForRow:(int)row column:(int)column;
{
    NSMenu *menu = nil;
    NSURL *theURL = nil;
    
    if(0 == column && row >= 0 && [[outlineView itemAtRow:row] isLeaf])
        theURL = [[tv itemAtRow:row] representedFileURL];
    
    if(nil != theURL){
        
        NSZone *menuZone = [NSMenu menuZone];
        menu = [[[tv menu] copyWithZone:menuZone] autorelease];
        
        NSArray *applications = (NSArray *)LSCopyApplicationURLsForURL((CFURLRef)theURL, kLSRolesEditor | kLSRolesViewer);
        NSEnumerator *appEnum = [applications objectEnumerator];
        [applications release];
        NSMenuItem *item;
        
        item = [[NSMenuItem allocWithZone:menuZone] initWithTitle:NSLocalizedString(@"Open With", @"") action:NULL keyEquivalent:@""];
        NSMenu *submenu = [[[NSMenu allocWithZone:menuZone] initWithTitle:@""] autorelease];
        [item setSubmenu:submenu];
        [menu insertItem:item atIndex:0];
        [item release];
        
        while(theURL = [appEnum nextObject]){
            item = [[NSMenuItem allocWithZone:menuZone] initWithTitle:[[theURL path] lastPathComponent] action:@selector(editFile:) keyEquivalent:@""];
            [item setTarget:self];
            [item setRepresentedObject:theURL];
            [submenu insertItem:item atIndex:0];
            [item release];
        }
        
        // add the choose... item
        item = [[NSMenuItem allocWithZone:menuZone] initWithTitle:[NSString stringWithFormat:@"%@%@", NSLocalizedString(@"Choose",@""), [NSString horizontalEllipsisString]] action:@selector(editFile:) keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:nil];
        [submenu addItem:item];
        [item release];
    }
    return menu;
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem;
{
    SEL action = [menuItem action];
    BOOL validate = NO;
    if(@selector(delete:) == action){
        validate = [self canDeleteSelectedItem];
    } else if(@selector(revealInFinder:) == action || @selector(openFile:) == action || @selector(editFile:) == action){
        int row = [outlineView selectedRow];
        if(row >= 0)
            validate = [[outlineView itemAtRow:row] isLeaf];
    }
    return validate;
}

- (IBAction)revealInFinder:(id)sender;
{
    int row = [outlineView selectedRow];
    if(row >= 0)
        [[NSWorkspace sharedWorkspace] selectFile:[[[outlineView itemAtRow:row] representedFileURL] path] inFileViewerRootedAtPath:@""];
}

- (IBAction)openFile:(id)sender;
{
    int row = [outlineView selectedRow];
    if(row >= 0)
        [[NSWorkspace sharedWorkspace] openURL:[[outlineView itemAtRow:row] representedFileURL]];
}

- (void)chooseEditorPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    if(returnCode == NSOKButton){
        NSString *appName = [[openPanel filenames] objectAtIndex:0];
        NSString *filePath = [[[outlineView itemAtRow:[outlineView selectedRow]] representedFileURL] path];
        [[NSWorkspace sharedWorkspace] openFile:filePath withApplication:appName];
    }
}

- (IBAction)editFile:(id)sender;
{
    // sender should be NSMenuItem with a representedObject of the application's URL (or nil if we're supposed to choose one)
    int row = [outlineView selectedRow];
    if(row >= 0){
        
        BDSKTemplate *selectedTemplate = [outlineView itemAtRow:row];
        if([sender representedObject]){
            [[NSWorkspace sharedWorkspace] openFile:[[selectedTemplate representedFileURL] path] withApplication:[[sender representedObject] path]];
        } else {
            NSOpenPanel *openPanel = [NSOpenPanel openPanel];
            [openPanel setCanChooseDirectories:NO];
            [openPanel setAllowsMultipleSelection:NO];
            [openPanel setPrompt:NSLocalizedString(@"Choose Editor", @"")];
            
            [openPanel beginSheetForDirectory:[[NSFileManager defaultManager] applicationsDirectory] 
                                         file:nil 
                                        types:[NSArray arrayWithObjects:@"app", nil] 
                               modalForWindow:[[BDSKPreferenceController sharedPreferenceController] window] 
                                modalDelegate:self 
                               didEndSelector:@selector(chooseEditorPanelDidEnd:returnCode:contextInfo:) 
                                  contextInfo:nil];
        }
    }
}

#pragma mark Combo box

- (NSCell *)tableView:(NSTableView *)tableView column:(OADataSourceTableColumn *)tableColumn dataCellForRow:(int)row;
{
    NSCell *cell = [tableColumn dataCell];
    
    static NSPopUpButtonCell *popupCell = nil;
    if(nil == popupCell){
        popupCell = [[NSPopUpButtonCell alloc] initTextCell:@"" pullsDown:NO];
        [popupCell setFont:[cell font]];
        [popupCell setBordered:NO];
        [popupCell setControlSize:NSSmallControlSize];
        [popupCell addItemsWithTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Plain Text", @"Plain Text"), NSLocalizedString(@"RTF", @"RTF"), NSLocalizedString(@"Doc", @"Doc"), nil]];
    }
    
    // if this is a non-editable cell, don't display the combo box
    if(NO == [[(NSOutlineView *)tableView itemAtRow:row] isLeaf])
        cell = popupCell;
    
    return cell;
}

- (id)comboBoxCell:(NSComboBoxCell *)aComboBoxCell objectValueForItemAtIndex:(int)index { return [roles objectAtIndex:index]; }

- (int)numberOfItemsInComboBoxCell:(NSComboBoxCell *)aComboBoxCell { return [roles count]; }

@end

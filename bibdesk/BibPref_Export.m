//
//  BibPref_Export.m
//  Bibdesk
//
//  Created by Adam Maxwell on 05/18/06.
/*
 This software is Copyright (c) 2006-2011
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
#import "BDSKStringConstants.h"
#import "BDSKTypeManager.h"
#import "BDAlias.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKTemplate.h"
#import "BDSKAppController.h"
#import "NSMenu_BDSKExtensions.h"
#import "BDSKPreferenceRecord.h"

#define BDSKTemplateRowsPboardType @"BDSKTemplateRowsPboardType"


@interface BibPref_Export (Private)
- (void)updateUI;
- (void)setItemNodes:(NSArray *)array;
- (BOOL)canAddItem;
- (BOOL)canDeleteSelectedItem;
@end


@implementation BibPref_Export

- (id)initWithRecord:(BDSKPreferenceRecord *)aRecord forPreferenceController:(BDSKPreferenceController *)aController {
	if(self = [super initWithRecord:aRecord forPreferenceController:aController]){
        
        [self setItemNodes:[BDSKTemplate exportTemplates]];
        
        fileTypes = [[NSArray alloc] initWithObjects:@"html", @"rss", @"csv", @"txt", @"rtf", @"rtfd", @"doc", @"docx", @"odt", @"webarchive", nil];
        
        roles = [[NSMutableArray alloc] initWithObjects:[BDSKTemplate localizedMainPageString], [BDSKTemplate localizedDefaultItemString], [BDSKTemplate localizedAccessoryString], [BDSKTemplate localizedScriptString], nil];
        [roles addObjectsFromArray:[[BDSKTypeManager sharedManager] types]];
        
        templatePrefList = BDSKExportTemplateList;
	}
	return self;
}

- (void)defaultsDidRevert {
    if (templatePrefList == BDSKExportTemplateList) {
        [self setItemNodes:[BDSKTemplate defaultExportTemplates]];
    } else {
        [self setItemNodes:[BDSKTemplate defaultServiceTemplates]];
    }
    [self updateUI];
}

- (void)awakeFromNib
{    
    [outlineView setAutosaveExpandedItems:YES];
    
    // Default behavior is to expand column 0, which slides column 1 outside the clip view; since we only have one expandable column, this is more annoying than helpful.
    [outlineView setAutoresizesOutlineColumn:NO];
    
    [outlineView registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, BDSKTemplateRowsPboardType, nil]];
    [outlineView setDoubleAction:@selector(chooseFileDoubleAction:)];
    [outlineView setTarget:self];
    
    [self updateUI];
}

- (void)dealloc
{
    BDSKDESTROY(itemNodes);
    BDSKDESTROY(roles);
    BDSKDESTROY(fileTypes);
    [super dealloc];
}

- (void)synchronizePrefs
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:itemNodes];
    if(nil != data)
        [sud setObject:data forKey:(templatePrefList == BDSKExportTemplateList) ? BDSKExportTemplateTree : BDSKServiceTemplateTree];
    else
        NSLog(@"Unable to archive %@", itemNodes);
}

- (void)updateUI
{
    [prefListRadio selectCellWithTag:templatePrefList];
    [outlineView reloadData];
    [self synchronizePrefs];
    [addRemoveButton setEnabled:[self canAddItem] forSegment:0];
    [addRemoveButton setEnabled:[self canDeleteSelectedItem] forSegment:1];
}

- (void)setItemNodes:(NSArray *)array;
{
    if(array != itemNodes){
        [itemNodes release];
        itemNodes = [array mutableCopy];
    }
}

- (IBAction)changePrefList:(id)sender{
    templatePrefList = [[sender selectedCell] tag];
    [self setItemNodes:templatePrefList == BDSKExportTemplateList ? [BDSKTemplate exportTemplates] : [BDSKTemplate serviceTemplates]];
    [self updateUI];
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    if (NSAlertDefaultReturn == returnCode)
        [[NSFileManager defaultManager] copyAllExportTemplatesToApplicationSupportAndOverwrite:YES];
}

- (IBAction)resetDefaultFiles:(id)sender;
{
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Reset default template files to their original value?", @"Message in alert dialog when resetting default template files") 
									 defaultButton:NSLocalizedString(@"OK", @"Button title") 
								   alternateButton:NSLocalizedString(@"Cancel", @"Button title") 
									   otherButton:nil 
						 informativeTextWithFormat:NSLocalizedString(@"Choosing Reset Default Files will restore the original content of all the standard export and service template files.", @"Informative text in alert dialog")];
	[alert beginSheetModalForWindow:[[self view] window] 
					  modalDelegate:self
					 didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) 
						contextInfo:NULL];
}

- (IBAction)addRemoveNode:(id)sender;
{
    if (sender && [sender selectedSegment] == 0) { // add
        
        // may be nil
        NSInteger row = [outlineView selectedRow];
        BDSKTreeNode *selectedNode = row == -1 ? nil : [outlineView itemAtRow:row];
        BDSKTemplate *newNode = [[BDSKTemplate alloc] init];

        if([selectedNode isLeaf]){
            // add as a sibling of the selected node
            // we're already expanded, and newNode won't be expandable
            [[[selectedNode parent] mutableArrayValueForKey:@"children"] addObject:newNode];
        } else if(nil != selectedNode && [outlineView isItemExpanded:selectedNode]){
            // add as a child of the selected node
            // selected node is expanded, so no need to expand
            [[selectedNode mutableArrayValueForKey:@"children"] addObject:newNode];
        } else if(BDSKExportTemplateList == templatePrefList){
            // add as a non-leaf node
            [itemNodes addObject:newNode];
            
            // each style needs at least a Main Page child, and newNode will be recognized as a non-leaf node
            BDSKTemplate *child = [[BDSKTemplate alloc] init];
            [child setValue:BDSKTemplateMainPageString forKey:BDSKTemplateRoleString];
            [[newNode mutableArrayValueForKey:@"children"] addObject:child];
            [child release];
            
            // reload so we can expand this new parent node
            [outlineView reloadData];
            [outlineView expandItem:newNode];
        }
        
        [newNode release];
        
    } else { // remove
        
        NSInteger row = [outlineView selectedRow];
        BDSKTreeNode *selectedNode = row == -1 ? nil : [outlineView itemAtRow:row];
        if(nil != selectedNode){
            if([selectedNode isLeaf])
                [[[selectedNode parent] mutableArrayValueForKey:@"children"] removeObject:selectedNode];
            else
                [itemNodes removeObjectIdenticalTo:selectedNode];
        } else {
            NSBeep();
        }
        
    }
    
    [self updateUI];
}

#pragma mark Outline View

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item
{
    return item ? (NO == [item isLeaf]) : YES;
}

- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item
{ 
    return item ? [item countOfChildren] : [itemNodes count];
}

- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    NSString *columnID = [tableColumn identifier];
    id value = [item valueForKey:columnID];
    if (value == nil) {
        // set some placeholder message, this will show up in red
        if ([columnID isEqualToString:BDSKTemplateRoleString])
            value = ([item isLeaf]) ? NSLocalizedString(@"Choose role", @"Default text for template role") : NSLocalizedString(@"Choose file type", @"Default text for template type");
        else if ([columnID isEqualToString:BDSKTemplateNameString]) {
            if ([item isLeaf])
                value = NSLocalizedString(@"Double-click to choose file", @"Default text for template file");
            else
                value = NSLocalizedString(@"Click twice to change name", @"Default text for template name");
        }
    } else if ([columnID isEqualToString:BDSKTemplateRoleString]) {
        value = [BDSKTemplate localizedRoleString:value];
    }
    return value;
}

- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)idx ofItem:(id)item
{
    return nil == item ? [itemNodes objectAtIndex:idx] : [item objectInChildrenAtIndex:idx];
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

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode contextInfo:(BDSKTemplate *)aNode
{
    NSURL *fileURL = [[panel URLs] lastObject];
    if(NSOKButton == returnCode && nil != fileURL){
        // this will set the name property
        [aNode setValue:fileURL forKey:BDSKTemplateFileURLString];
    }
    [aNode release];
    [panel orderOut:nil];
    [self updateUI];
}

// Formerly implemented in outlineView:shouldEditTableColumn:item:, but on Leopard a second click on the selected row (outside the double click interval) would cause the open panel to run.  This was highly annoying.
- (IBAction)chooseFileDoubleAction:(id)sender
{
    NSInteger row = [outlineView clickedRow];
    NSInteger column = [outlineView clickedColumn];
    if (row >= 0 && column >= 0) {
        
        NSString *columnID = [[[outlineView tableColumns] objectAtIndex:column] identifier];
        BDSKTemplate *node = [outlineView itemAtRow:row];
        if ([node isLeaf] && [columnID isEqualToString:BDSKTemplateNameString])
            [self chooseFile:nil];
    }
}

- (BOOL)outlineView:(NSOutlineView *)ov shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item;
{
    // leaf items are fully editable, but you can only edit the name of a parent item

    NSString *columnID = [tableColumn identifier];
    if([item isLeaf]){
        if([columnID isEqualToString:BDSKTemplateNameString]){            
            return NO;
        } else if([columnID isEqualToString:BDSKTemplateRoleString]){
            if([[item valueForKey:BDSKTemplateRoleString] isEqualToString:BDSKTemplateMainPageString])
                return NO;
        } else [NSException raise:NSInternalInconsistencyException format:@"Unexpected table column identifier %@", columnID];
    }else if(templatePrefList == BDSKServiceTemplateList){
        return NO;
    }
    return YES;
}

// return NO to avoid popping the NSOpenPanel unexpectedly
- (BOOL)outlineViewShouldEditNextItemWhenEditingEnds:(BDSKTemplateOutlineView *)ov { return NO; }

// this seems to be called when editing the NSComboBoxCell as well as the parent name
- (void)outlineView:(NSOutlineView *)ov setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item{
    NSString *columnID = [tableColumn identifier];
    if ([columnID isEqualToString:BDSKTemplateRoleString])
        object = [BDSKTemplate unlocalizedRoleString:object];
    if([columnID isEqualToString:BDSKTemplateRoleString] && [item isLeaf] && [object isEqualToString:BDSKTemplateAccessoryString] == NO && [(BDSKTemplate *)[item parent] childForRole:object] != nil) {
        [outlineView reloadData];
    } else if (object != nil) { // object can be nil when a NSComboBoxCell is edited while the options are shown, looks like an AppKit bug
        [item setValue:object forKey:[tableColumn identifier]];
        [self synchronizePrefs];
    }
}

- (void)outlineView:(NSOutlineView *)ov willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item{
    NSString *columnID = [tableColumn identifier];
    if ([cell respondsToSelector:@selector(setTextColor:)])
        [cell setTextColor:([item valueForKey:columnID] ? [NSColor blackColor] : [NSColor redColor])];
    if([columnID isEqualToString:BDSKTemplateRoleString]) {
        [cell removeAllItems];
        [cell addItemsWithObjectValues:([item isLeaf]) ? roles : fileTypes];
        if(([item isLeaf] && [[item valueForKey:BDSKTemplateRoleString] isEqualToString:BDSKTemplateMainPageString]) || 
           ([item isLeaf] == NO && templatePrefList == BDSKServiceTemplateList))
            [cell setEnabled:NO];
        else
            [cell setEnabled:YES];
    }
}

- (BOOL)canDeleteItem:(BDSKTreeNode *)item
{
    return ((templatePrefList == BDSKExportTemplateList && [item isLeaf] == NO) || 
            ([item isLeaf]  && [[item valueForKey:BDSKTemplateRoleString] isEqualToString:BDSKTemplateMainPageString] == NO));
}

- (BOOL)canDeleteSelectedItem
{
    NSInteger row = [outlineView selectedRow];
    if (row == -1)
        return NO;
    return [self canDeleteItem:[outlineView itemAtRow:row]];
}

// we can't add items to the services outline view
- (BOOL)canAddItem
{
    return ((templatePrefList == BDSKExportTemplateList) || -1 != [outlineView selectedRow]);
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification;
{
    [addRemoveButton setEnabled:[self canAddItem] forSegment:0];
    [addRemoveButton setEnabled:[self canDeleteSelectedItem] forSegment:1];
}

- (void)outlineView:(NSOutlineView *)ov deleteItems:(NSArray *)items;
{
    // currently we don't allow multiple selection
    BDSKTreeNode *item = [items lastObject];
    if(item && [self canDeleteItem:item]) {
        [self addRemoveNode:nil];
        if ([item isLeaf])
            [[[item parent] mutableArrayValueForKey:@"children"] removeObject:item];
        else
            [itemNodes removeObjectIdenticalTo:item];
        [self updateUI];
    } else
        NSBeep();
}

- (BOOL)outlineView:(NSOutlineView *)ov canDeleteItems:(NSArray *)items {
    // currently we don't allow multiple selection
    return [self canDeleteItem:[items lastObject]];
}

- (BOOL)outlineView:(NSOutlineView *)ov isGroupItem:(id)item {
    return [item isLeaf] == NO;
}

#pragma mark Drag / drop

- (BOOL)outlineView:(NSOutlineView *)ov writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard{
    BDSKTemplate *item = [items lastObject];
    if (pboard == [NSPasteboard pasteboardWithName:NSDragPboard] && ([item isLeaf] == NO || [[item valueForKey:BDSKTemplateRoleString] isEqualToString:BDSKTemplateMainPageString] == NO)) {
        [pboard declareTypes:[NSArray arrayWithObject:BDSKTemplateRowsPboardType] owner:nil];
        [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:[items lastObject]] forType:BDSKTemplateRowsPboardType];
        return YES;
    }
    return NO;
}

- (BOOL)outlineView:(NSOutlineView *)ov canCopyItems:(NSArray *)items {
    return NO;
}

- (NSDragOperation)outlineView:(NSOutlineView *)ov validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)idx{
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, BDSKTemplateRowsPboardType, nil]];
    
    if ([type isEqualToString:NSFilenamesPboardType]) {
        if ([item isLeaf] && idx == NSOutlineViewDropOnItemIndex) {
            return NSDragOperationCopy;
        } else if (item == nil) {
            if (idx == NSOutlineViewDropOnItemIndex)
                [outlineView setDropItem:nil dropChildIndex:[itemNodes count]];
            return NSDragOperationCopy;
        } else if ([item isLeaf] == NO && idx != NSOutlineViewDropOnItemIndex && idx > 0) {
            return NSDragOperationCopy;
        }
    } else if ([type isEqualToString:BDSKTemplateRowsPboardType]) {
        if (idx == NSOutlineViewDropOnItemIndex)
            return NSDragOperationNone;
        id dropItem = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:BDSKTemplateRowsPboardType]];
        if ([dropItem isLeaf]) {
            if ([[item children] containsObject:dropItem] && idx > 0)
                return NSDragOperationMove;
        } else {
            if (item == nil)
                return NSDragOperationMove;
        }
    }
    return NSDragOperationNone;
}

- (IBAction)dismissChooseMainPageSheet:(id)sender{
    [chooseMainPageSheet orderOut:self];
    [NSApp endSheet:chooseMainPageSheet returnCode:[sender tag]];
}

- (void)chooseMainPageSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    if (returnCode == NSCancelButton)
        return;
    
    NSDictionary *info = [(NSDictionary *)contextInfo autorelease];
    NSArray *fileNames = [info objectForKey:@"fileNames"];
    NSInteger idx = [[info objectForKey:@"index"] integerValue];
    
    NSInteger mainIndex = [chooseMainPagePopup indexOfSelectedItem] - 1;
    NSInteger i, count = [fileNames count];
    id newNode = nil;
    id childNode = nil;
    NSMutableArray *addedItems = [NSMutableArray array];
    
    for (i = 0; i < count; i++) {
        if (mainIndex == -1 || i == 0) {
            newNode = [[BDSKTemplate alloc] init];
            [itemNodes insertObject:newNode atIndex:idx++];
            [newNode release];
            [addedItems addObject:newNode];
        }
        childNode = [[BDSKTemplate alloc] init];
        if (mainIndex == -1 || i == mainIndex) {
            [childNode setValue:BDSKTemplateMainPageString forKey:BDSKTemplateRoleString];
            [newNode insertObject:childNode inChildrenAtIndex:0];
        } else {
            [[newNode mutableArrayValueForKey:@"children"] addObject:childNode];
        }
        [childNode release];
        [childNode setValue:[NSURL fileURLWithPath:[fileNames objectAtIndex:i]] forKey:BDSKTemplateFileURLString];
    }
    
    [self updateUI];
    count = [addedItems count];
    for (i = 0; i < count; i++)
        [outlineView expandItem:[addedItems objectAtIndex:i]];
    [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:[outlineView rowForItem:newNode]] byExtendingSelection:NO];
}


- (BOOL)outlineView:(NSOutlineView *)ov acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)idx{
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, BDSKTemplateRowsPboardType, nil]];
    
    if ([type isEqualToString:NSFilenamesPboardType]) {
        NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
        NSString *fileName;
        id newNode = nil;
        id childNode = nil;
        
        if ([item isLeaf] && idx == NSOutlineViewDropOnItemIndex) {
            fileName = [fileNames objectAtIndex:0];
            [item setValue:[NSURL fileURLWithPath:fileName] forKey:BDSKTemplateFileURLString];
            newNode = item;
        } else if (item == nil && idx != NSOutlineViewDropOnItemIndex) {
            if ([fileNames count] == 1){
                newNode = [[BDSKTemplate alloc] init];
                childNode = [[BDSKTemplate alloc] init];
                [itemNodes insertObject:newNode atIndex:idx++];
                [[newNode mutableArrayValueForKey:@"children"] addObject:childNode];
                [newNode release];
                [childNode release];
                [childNode setValue:BDSKTemplateMainPageString forKey:BDSKTemplateRoleString];
                fileName = [fileNames objectAtIndex:0];
                [childNode setValue:[NSURL fileURLWithPath:fileName] forKey:BDSKTemplateFileURLString];
            } else {
                [chooseMainPagePopup removeAllItems];
                [chooseMainPagePopup addItemWithTitle:NSLocalizedString(@"Separate templates", @"Popup menu item title")];
                [chooseMainPagePopup addItemsWithTitles:[fileNames valueForKey:@"lastPathComponent"]];
                [chooseMainPagePopup selectItemAtIndex:0];
                NSDictionary *contextInfo = [[NSDictionary alloc] initWithObjectsAndKeys:fileNames, @"fileNames", [NSNumber numberWithInteger:idx], @"index", nil];
                [NSApp beginSheet:chooseMainPageSheet modalForWindow:[[self view] window]
                                                       modalDelegate:self
                                                      didEndSelector:@selector(chooseMainPageSheetDidEnd:returnCode:contextInfo:)
                                                         contextInfo:contextInfo];
                return YES;
            }
        } else if ([item isLeaf] == NO && idx != NSOutlineViewDropOnItemIndex && idx > 0) {
            for (fileName in fileNames) {
                newNode = [[[BDSKTemplate alloc] init] autorelease];
                [item insertObject:newNode inChildrenAtIndex:idx++];
                [newNode setValue:[NSURL fileURLWithPath:fileName] forKey:BDSKTemplateFileURLString];
            }
        } else return NO;
        [self updateUI];
        [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:[outlineView rowForItem:newNode]] byExtendingSelection:NO];
        if ([newNode isLeaf] == NO)
            [outlineView expandItem:newNode];
        return YES;
    } else if ([type isEqualToString:BDSKTemplateRowsPboardType]) {
        id dropItem = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:BDSKTemplateRowsPboardType]];
        if ([dropItem isLeaf]) {
            NSInteger sourceIndex = [[item children] indexOfObject:dropItem];
            if (sourceIndex == NSNotFound)
                return NO;
            if (sourceIndex < idx)
                --idx;
            NSMutableArray *children = [(BDSKTreeNode *)item mutableArrayValueForKey:@"children"];
            [children removeObject:dropItem];
            [children insertObject:dropItem atIndex:idx];
        } else {
            NSInteger sourceIndex = [itemNodes indexOfObject:dropItem];
            if (sourceIndex == NSNotFound)
                return NO;
            if (sourceIndex < idx)
                --idx;
            [[dropItem retain] autorelease];
            [itemNodes removeObjectAtIndex:sourceIndex];
            [itemNodes insertObject:dropItem atIndex:idx];
        }
        [self updateUI];
        [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:[outlineView rowForItem:dropItem]] byExtendingSelection:NO];
        return YES;
    }
    return NO;
}

#pragma mark ToolTips and Context menu

- (NSString *)outlineView:(NSOutlineView *)ov toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tc item:(id)item mouseLocation:(NSPoint)mouseLocation
{
    NSString *tooltip = nil;
    if ([[tc identifier] isEqualToString:BDSKTemplateNameString] && [item isLeaf])
        tooltip = [[item representedFileURL] path];
    return tooltip;
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    if (menu == [outlineView menu]) {
        NSInteger row = [outlineView clickedRow];
        [menu removeAllItems];
        if (row != -1) {
            BDSKTemplate *item = [outlineView itemAtRow:row];
            if ([outlineView clickedColumn] == 0 && [item isLeaf]) {
                NSURL *theURL = [item representedFileURL];
                NSMenuItem *menuItem = nil;
            
                if(nil != theURL){
                    menuItem = [menu addItemWithTitle:NSLocalizedString(@"Open With", @"Menu item title") andSubmenuOfApplicationsForURL:theURL];
                    
                    menuItem = [menu addItemWithTitle:NSLocalizedString(@"Reveal in Finder", @"Menu item title") action:@selector(revealInFinder:) keyEquivalent:@""];
                    [menuItem setTarget:self];
                    [menuItem setRepresentedObject:theURL];
                }
                
                menuItem = [menu addItemWithTitle:[NSLocalizedString(@"Choose File", @"Menu item title") stringByAppendingEllipsis] action:@selector(chooseFile:) keyEquivalent:@""];
                [menuItem setTarget:self];
                [menuItem setRepresentedObject:[NSNumber numberWithInteger:row]];
            }
        }
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
{
    SEL action = [menuItem action];
    BOOL validate = YES;
    if (@selector(revealInFinder:) == action || @selector(chooseFile:) == action) {
        if ([menuItem representedObject] == nil) {
            NSInteger row = [outlineView selectedRow];
            validate = row != -1 && [[outlineView itemAtRow:row] isLeaf];
        }
    }
    return validate;
}

- (IBAction)revealInFinder:(id)sender;
{
    NSURL *theURL = [sender representedObject];
    if (theURL == nil) {
        NSInteger row = [outlineView selectedRow];
        if (row >= 0)
            theURL = [[outlineView itemAtRow:row] representedFileURL];
    }
    if (theURL)
        [[NSWorkspace sharedWorkspace] selectFile:[theURL path] inFileViewerRootedAtPath:@""];
}

- (IBAction)chooseFile:(id)sender;
{
    NSNumber *rowNumber = [sender representedObject];
    NSInteger row = rowNumber ? [rowNumber integerValue] : [outlineView selectedRow];
    id item = row == -1 ? nil : [outlineView itemAtRow:row];
    
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanCreateDirectories:NO];
    [openPanel setPrompt:NSLocalizedString(@"Choose", @"Prompt for Choose panel")];
    
    // start the panel in the same directory as the item's existing path (may be nil)
    NSString *dirPath = [[[item representedFileURL] path] stringByDeletingLastPathComponent];
    [openPanel beginSheetForDirectory:dirPath 
                                 file:nil 
                                types:nil 
                       modalForWindow:[[self view] window] 
                        modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) 
                          contextInfo:[item retain]];
}

@end


@implementation BDSKTemplateOutlineView

- (void)textDidEndEditing:(NSNotification *)notification {
    NSInteger textMovement = [[[notification userInfo] objectForKey:@"NSTextMovement"] integerValue];
    if ((textMovement == NSReturnTextMovement || textMovement == NSTabTextMovement) && 
        [[self delegate] respondsToSelector:@selector(outlineViewShouldEditNextItemWhenEditingEnds:)] && [[self delegate] outlineViewShouldEditNextItemWhenEditingEnds:self] == NO) {
        // This is ugly, but just about the only way to do it. NSTableView is determined to select and edit something else, even the text field that it just finished editing, unless we mislead it about what key was pressed to end editing.
        NSMutableDictionary *newUserInfo;
        NSNotification *newNotification;

        newUserInfo = [NSMutableDictionary dictionaryWithDictionary:[notification userInfo]];
        [newUserInfo setObject:[NSNumber numberWithInteger:NSIllegalTextMovement] forKey:@"NSTextMovement"];
        newNotification = [NSNotification notificationWithName:[notification name] object:[notification object] userInfo:newUserInfo];
        [super textDidEndEditing:notification];

        // For some reason we lose firstResponder status when we do the above.
        [[self window] makeFirstResponder:self];
    } else {
        [super textDidEndEditing:notification];
    }
}

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
- (id <BDSKTemplateOutlineViewDelegate>)delegate { return (id <BDSKTemplateOutlineViewDelegate>)[super delegate]; }
- (void)setDelegate:(id <BDSKTemplateOutlineViewDelegate>)newDelegate { [super setDelegate:newDelegate]; }
#endif

@end


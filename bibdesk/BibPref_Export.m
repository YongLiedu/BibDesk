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

// these keys are private to this class at present
static NSString *BDSKExportTemplateTree = @"BDSKExportTemplateTree";
static NSString *roleString = @"role";
static NSString *nameString = @"name";

static NSString *accessoryString = @"Accessory File";
static NSString *mainPageString = @"Main Page";
static NSString *defaultItemString = @"Default Item";

@interface BDSKTemplate (Private)

- (id)childForRole:(NSString *)role;
- (BOOL)setAliasFromURL:(NSURL *)aURL;
- (NSURL *)representedFileURL;
- (NSColor *)representedColorForKey:(NSString *)key;
- (BOOL)hasChildWithRole:(NSString *)aRole;

@end


@implementation BibPref_Export

- (void)doLegacySetup
{
    itemNodes = [[NSMutableArray alloc] initWithCapacity:5];
    
    BDSKTemplate *childNode = nil;
    
    // we should only have a single template object to start with
    childNode = [[BDSKTemplate alloc] init];
    [childNode setValue:@"Default HTML template" forKey:nameString];
    [childNode setValue:[NSNumber numberWithInt:0] forKey:roleString];
    [itemNodes addObject:childNode];
    [childNode release];
    
    BDSKTemplate *tmpNode = nil;
        
    NSURL *fileURL = [NSURL fileURLWithPath:[[[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:@"htmlExportTemplate"]];
    if([[NSFileManager defaultManager] objectExistsAtFileURL:fileURL]){
        tmpNode = [[BDSKTemplate alloc] init];
        [tmpNode setValue:[[fileURL path] lastPathComponent] forKey:nameString];
        [tmpNode setValue:mainPageString forKey:roleString];
        // don't add it if the alias fails
        if([tmpNode setAliasFromURL:fileURL])
            [childNode addChild:tmpNode];
        [tmpNode release];
    }
    
    // a user could potentially have templates for multiple types; we could add all of those, as well
    fileURL = [NSURL fileURLWithPath:[[[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:@"htmlItemExportTemplate"]];
    if([[NSFileManager defaultManager] objectExistsAtFileURL:fileURL]){
        tmpNode = [[BDSKTemplate alloc] init];
        [tmpNode setValue:[[fileURL path] lastPathComponent] forKey:nameString];
        [tmpNode setValue:defaultItemString forKey:roleString];
        // don't add it if the alias fails
        if([tmpNode setAliasFromURL:fileURL])
            [childNode addChild:tmpNode];
        [tmpNode release];
    }
}

- (void)awakeFromNib
{    
        
    [super awakeFromNib];
    
    NSData *data = [defaults objectForKey:BDSKExportTemplateTree];
    if([data length]){
        itemNodes = [[NSKeyedUnarchiver unarchiveObjectWithData:data] mutableCopy];
    } else {
        [self doLegacySetup];
    }

    roles = [[NSMutableArray alloc] initWithObjects:mainPageString, defaultItemString, accessoryString, nil];
    [roles addObjectsFromArray:[[BibTypeManager sharedManager] bibTypesForFileType:BDSKBibtexString]];

    [outlineView setAutosaveExpandedItems:YES];
    
    // this will synchronize prefs, as well
    [self updateUI];
}

- (void)dealloc
{
    [itemNodes release];
    [roles release];
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
        [newNode setValue:NSLocalizedString(@"Double-click to choose file", @"") forKey:nameString];
        [[selectedNode parent] addChild:newNode];
    } else if(nil != selectedNode && [outlineView isItemExpanded:selectedNode]){
        // add as a child of the selected node
        [newNode setValue:NSLocalizedString(@"Double-click to choose file", @"") forKey:nameString];
        [selectedNode addChild:newNode];
    } else {
        // add as a non-leaf node
        [newNode setValue:NSLocalizedString(@"Double-click to change name", @"") forKey:nameString];
        [newNode setValue:[NSNumber numberWithInt:0] forKey:roleString];
        [itemNodes addObject:newNode];
        
        // add a child so newNode will be recognized as a non-leaf node
        BDSKTemplate *child = [[BDSKTemplate alloc] init];
        [child setValue:NSLocalizedString(@"Double-click to choose file", @"") forKey:nameString];
        [child setValue:accessoryString forKey:roleString];
        [newNode addChild:child];
        [child release];
    }
    
    [newNode release];
    [self updateUI];
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
    return [item valueForKey:[tableColumn identifier]];
}

- (id)outlineView:(NSOutlineView *)ov child:(int)index ofItem:(id)item
{
    return nil == item ? [itemNodes objectAtIndex:index] : [[item children] objectAtIndex:index];
}

#warning this seems to be broken
// probably uses isEqual: to determine if the object should be expanded
// object is archived; return the unarchived object (but I think NSOutlineView requires
// unique objects, so I'm using pointer equality)
- (id)outlineView:(NSOutlineView *)ov itemForPersistentObject:(id)object
{
    return [NSKeyedUnarchiver unarchiveObjectWithData:object];
}

// return archived item
- (id)outlineView:(NSOutlineView *)ov persistentObjectForItem:(id)item
{
    return [NSKeyedArchiver archivedDataWithRootObject:item];
}

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    NSURL *fileURL = [[panel URLs] lastObject];
    if(NSOKButton == returnCode && nil != fileURL){
        
        // use last path component as file name
        [(BDSKTemplate *)contextInfo setValue:[[fileURL path] lastPathComponent] forKey:nameString];
        
        // track the file by alias; if this doesn't work, it will show up as red
        [(BDSKTemplate *)contextInfo setAliasFromURL:fileURL];
    }
    [(id)contextInfo release];
    [panel orderOut:nil];
    [self updateUI];
}

- (BOOL)outlineView:(NSOutlineView *)ov shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item;
{
    // leaf items are fully editable, but you can only edit the name of a parent item

    NSString *identifier = [tableColumn identifier];
    if([item isLeaf]){
        // run an open panel for the filename
        if([identifier isEqualToString:nameString]){
            NSOpenPanel *openPanel = [NSOpenPanel openPanel];
            [openPanel setCanChooseDirectories:YES];
            [openPanel setCanCreateDirectories:NO];
            [openPanel setPrompt:NSLocalizedString(@"Choose", @"")];
            
            // start the panel in the same directory as the item's existing path, or fall back to app support
            NSString *dirPath = [[[item representedFileURL] path] stringByDeletingLastPathComponent];
            if(nil == dirPath)
                dirPath = dirPath;
            [openPanel beginSheetForDirectory:dirPath file:nil types:nil modalForWindow:[[BDSKPreferenceController sharedPreferenceController] window] modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:[item retain]];
            
            // bypass the normal editing mechanism, or it'll reset the value
            return NO;
        } else if([identifier isEqualToString:roleString]){
            if([[item valueForKey:roleString] isEqualToString:mainPageString])
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
    if([identifier isEqualToString:roleString] && [item isLeaf] && [object isEqualToString:accessoryString] == NO && [(BDSKTemplate *)[item parent] hasChildWithRole:object]) {
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
    if([identifier isEqualToString:roleString])
        [cell setEnabled:[item isLeaf] == NO || [[item valueForKey:roleString] isEqualToString:mainPageString] == NO];
}

- (BOOL)canDeleteSelectedItem
{
    BDSKTreeNode *selItem = [outlineView selectedItem];
    return ([selItem isLeaf] == NO || [[selItem valueForKey:roleString] isEqualToString:mainPageString] == NO);
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

#pragma mark ToolTps and Context menu

- (NSString *)tableView:(NSTableView *)tv toolTipForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    NSString *tooltip = nil;
    if(row >= 0){
        id item = [outlineView itemAtRow:row];
        if ([[tableColumn identifier] isEqualToString:nameString] && [item isLeaf])
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
        [popupCell addItemsWithTitles:[NSArray arrayWithObjects:NSLocalizedString(@"Plain Text", @"Plain Text"), NSLocalizedString(@"RTF", @"RTF"), nil]];
    }
    
    // if this is a non-editable cell, don't display the combo box
    if(NO == [[(NSOutlineView *)tableView itemAtRow:row] isLeaf])
        cell = popupCell;
    
    return cell;
}

- (id)comboBoxCell:(NSComboBoxCell *)aComboBoxCell objectValueForItemAtIndex:(int)index { return [roles objectAtIndex:index]; }

- (int)numberOfItemsInComboBoxCell:(NSComboBoxCell *)aComboBoxCell { return [roles count]; }

@end

#pragma mark -
#pragma mark BDSKTreeNode subclass

@implementation BDSKTemplate

#pragma mark API for templates

+ (NSArray *)allStyleNames;
{
    NSMutableArray *names = [NSMutableArray array];
    NSEnumerator *nodeE = [[NSKeyedUnarchiver unarchiveObjectWithData:[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKExportTemplateTree]] objectEnumerator];
    id aNode;
    while(aNode = [nodeE nextObject]){
        if(NO == [aNode isLeaf])
            [names addObject:[aNode valueForKey:nameString]];
    }
    return names;
}

// accesses the node array in prefs
+ (BDSKTemplate *)templateForStyle:(NSString *)styleName;
{
    NSEnumerator *nodeE = [[NSKeyedUnarchiver unarchiveObjectWithData:[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKExportTemplateTree]] objectEnumerator];
    id aNode = nil;
    
    while(aNode = [nodeE nextObject]){
        if(NO == [aNode isLeaf] && [[aNode valueForKey:nameString] isEqualToString:styleName])
            break;
    }
    return aNode;
}

- (BDSKTemplateFormat)templateFormat;
{
    OBASSERT([self isLeaf] == NO);
    return [[self valueForKey:roleString] intValue];
}

- (NSURL *)mainPageTemplateURL;
{
    return [self templateURLForType:mainPageString];
}

- (NSURL *)defaultItemTemplateURL;
{
    return [self templateURLForType:defaultItemString];
}

- (NSURL *)templateURLForType:(NSString *)pubType;
{
    OBASSERT([self isLeaf] == NO);
    NSParameterAssert(nil != pubType);
    return [[self childForRole:pubType] representedFileURL];
}

- (NSArray *)accessoryFileURLs;
{
    OBASSERT([self isLeaf] == NO);
    NSMutableArray *fileURLs = [NSMutableArray array];
    NSEnumerator *childE = [[self children] objectEnumerator];
    BDSKTemplate *aChild;
    NSURL *fileURL;
    while(aChild = [childE nextObject]){
        if([[aChild valueForKey:roleString] isEqualToString:accessoryString]){
            fileURL = [aChild representedFileURL];
            if(fileURL)
                [fileURLs addObject:fileURL];
        }
    }
    return fileURLs;
}

@end

@implementation BDSKTemplate (Private)

- (id)childForRole:(NSString *)role;
{
    NSParameterAssert(nil != role);
    NSEnumerator *nodeE = [[self children] objectEnumerator];
    id aNode = nil;
    
    // assume roles are unique by grabbing the first one; this works for any case except the accessory files
    while(aNode = [nodeE nextObject]){
        if([[aNode valueForKey:roleString] isEqualToString:role])
            break;
    }
    return aNode;
}

- (BOOL)setAliasFromURL:(NSURL *)aURL;
{
    BDAlias *alias = nil;
    alias = [[BDAlias alloc] initWithURL:aURL];
    
    BOOL rv = (nil != alias);
    
    if(alias)
        [self setValue:[alias aliasData] forKey:@"_BDAlias"];
    [alias release];
    
    return rv;
}

- (NSURL *)representedFileURL;
{
    return [[BDAlias aliasWithData:[self valueForKey:@"_BDAlias"]] fileURLNoUI];
}

- (NSColor *)representedColorForKey:(NSString *)key;
{
    NSColor *color = [NSColor controlTextColor];
    if([key isEqualToString:nameString] && [self isLeaf]){
        NSURL *fileURL = [self representedFileURL];
        if(nil == fileURL)
            color = [NSColor redColor];
    }
    return color;
}

- (BOOL)hasChildWithRole:(NSString *)aRole;
{
    NSEnumerator *roleEnum = [[self children] objectEnumerator];
    id aChild;
    while(aChild = [roleEnum nextObject]){
        if([[aChild valueForKey:roleString] isEqualToString:aRole])
            return YES;
    }
    return NO;
}

@end

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

static NSString *BDSKExportTemplateTree = @"BDSKExportTemplateTree";
static NSString *rolesString = @"role";
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
    childNode = [[BDSKTemplate alloc] initWithParent:nil];
    [childNode setValue:@"Default template" forKey:nameString];
    [itemNodes addObject:childNode];
    [childNode release];
    
    BDSKTemplate *tmpNode = nil;
        
    NSURL *fileURL = [NSURL fileURLWithPath:[[[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:@"htmlExportTemplate"]];
    if([[NSFileManager defaultManager] objectExistsAtFileURL:fileURL]){
        tmpNode = [[BDSKTemplate alloc] initWithParent:childNode];
        [tmpNode setValue:[[fileURL path] lastPathComponent] forKey:nameString];
        [tmpNode setValue:mainPageString forKey:rolesString];
        // don't add it if the alias fails
        if([tmpNode setAliasFromURL:fileURL])
            [childNode addChild:tmpNode];
        [tmpNode release];
    }
    
    // a user could potentially have templates for multiple types; we could add all of those, as well
    fileURL = [NSURL fileURLWithPath:[[[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:@"htmlItemExportTemplate"]];
    if([[NSFileManager defaultManager] objectExistsAtFileURL:fileURL]){
        tmpNode = [[BDSKTemplate alloc] initWithParent:childNode];
        [tmpNode setValue:[[fileURL path] lastPathComponent] forKey:nameString];
        [tmpNode setValue:defaultItemString forKey:rolesString];
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
    if(nil != data){
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
    BDSKTemplate *newNode = [[BDSKTemplate alloc] initWithParent:selectedNode];

    // add as a sibling of the selected node
    if([selectedNode isLeaf]){
            [newNode setValue:NSLocalizedString(@"Double-click to choose file", @"") forKey:nameString];
        [(BDSKTreeNode *)[selectedNode parent] addChild:newNode];
    } else {
        
        [newNode setValue:NSLocalizedString(@"Double-click to change name", @"") forKey:nameString];
        [itemNodes addObject:newNode];
        
            // add a child so newNode will be recognized as a non-leaf node
            BDSKTemplate *child = [[BDSKTemplate alloc] initWithParent:newNode];
            [child setValue:NSLocalizedString(@"Double-click to choose file", @"") forKey:nameString];
            [child setValue:accessoryString forKey:rolesString];
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

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return item ? (NO == [item isLeaf]) : YES;
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{ 
    return item ? [item numberOfChildren] : [itemNodes count];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    return [item valueForKey:[tableColumn identifier]];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
    return nil == item ? [itemNodes objectAtIndex:index] : [[item children] objectAtIndex:index];
}

#warning this seems to be broken
// probably uses isEqual: to determine if the object should be expanded
// object is archived; return the unarchived object (but I think NSOutlineView requires
// unique objects, so I'm using pointer equality)
- (id)outlineView:(NSOutlineView *)outlineView itemForPersistentObject:(id)object
{
    return [NSKeyedUnarchiver unarchiveObjectWithData:object];
}

// return archived item
- (id)outlineView:(NSOutlineView *)outlineView persistentObjectForItem:(id)item
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

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item;
{
    // leaf items are fully editable, but you can only edit the name of a parent item

    BOOL shouldEdit = NO;
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
            shouldEdit = NO;
        } else if([identifier isEqualToString:rolesString]){
            shouldEdit = YES;
        } else [NSException raise:NSInternalInconsistencyException format:@"Unexpected table column identifier %@", identifier];
    } else if([identifier isEqualToString:nameString]){
        shouldEdit = YES;
    }
    return shouldEdit;
}

// return NO to avoid popping the NSOpenPanel unexpectedly
- (BOOL)tableViewShouldEditNextItemWhenEditingEnds:(NSTableView *)tv { return NO; }

// this seems to be called when editing the NSComboBoxCell as well as the parent name
- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item{
    [item setValue:object forKey:[tableColumn identifier]];
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item{
    [cell setTextColor:[item representedColorForKey:[tableColumn identifier]]];
}

- (BOOL)canDeleteSelectedItem
{
    BDSKTreeNode *selItem = [outlineView selectedItem];
    return (([selItem isLeaf] && [[selItem parent] numberOfChildren] > 1) || [selItem isLeaf] == NO);
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

#pragma mark Context menu

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem;
{
    SEL action = [menuItem action];
    BOOL validate = NO;
    if(@selector(delete:) == action){
        validate = [self canDeleteSelectedItem];
    } else if(@selector(revealInFinder:) == action || @selector(openFile:) == action){
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

#pragma mark Combo box

- (NSCell *)tableView:(NSTableView *)tableView column:(OADataSourceTableColumn *)tableColumn dataCellForRow:(int)row;
{
    static NSTextFieldCell *textCell = nil;
    if(nil == textCell)
        textCell = [[NSTextFieldCell alloc] initTextCell:@""];
    
    // if this is a non-editable cell, don't display the combo box
    if(NO == [[(NSOutlineView *)tableView itemAtRow:row] isLeaf])
        return textCell;
    else
        return [tableColumn dataCell];
}

- (id)comboBoxCell:(NSComboBoxCell *)aComboBoxCell objectValueForItemAtIndex:(int)index { return [roles objectAtIndex:index]; }

- (int)numberOfItemsInComboBoxCell:(NSComboBoxCell *)aComboBoxCell { return [roles count]; }

- (IBAction)changeRole:(id)sender;
{
    NSParameterAssert(nil != sender);
    NSString *value = [sender stringValue];
    int row = [outlineView clickedRow];
    if(row >= 0){
        BDSKTemplate *item = [outlineView itemAtRow:row];
        if([item isLeaf] && NO == [[item parent] hasChildWithRole:value])
            [item setValue:value forKey:rolesString];
        else
            NSBeep();
    }
    [self updateUI];
}

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
    NSParameterAssert(nil != pubType);
    return [[self childForRole:pubType] representedFileURL];
}

- (NSArray *)accessoryFileURLs;
{
    NSMutableArray *fileURLs = [NSMutableArray array];
    NSEnumerator *childE = [[self children] objectEnumerator];
    BDSKTemplate *aChild;
    NSURL *fileURL;
    while(aChild = [childE nextObject]){
        if([[aChild valueForKey:rolesString] isEqualToString:accessoryString]){
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
        if([[aNode valueForKey:rolesString] isEqualToString:role])
            break;
    }
    return aNode;
}

- (BOOL)setAliasFromURL:(NSURL *)aURL;
{
    NSParameterAssert([aURL isFileURL]);
    BDAlias *alias = nil;
    FSRef fileRef;
    BOOL rv;

    if(CFURLGetFSRef((CFURLRef)aURL, &fileRef))
        alias = [[BDAlias alloc] initWithFSRef:&fileRef];
    
    rv = (nil != alias);
    
    if(alias)
        [self setValue:[alias aliasData] forKey:@"_BDAlias"];
    [alias release];
    
    return rv;
}

- (NSURL *)representedFileURL;
{
    BDAlias *alias = nil;
    NSURL *fileURL = nil;
    NSData *aliasData = [self valueForKey:@"_BDAlias"];
    
    if(aliasData)
        alias = [BDAlias aliasWithData:aliasData];
    if(alias)
        fileURL = [NSURL fileURLWithPath:[alias fullPathNoUI]];

    return fileURL;
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
        if([[aChild valueForKey:rolesString] isEqualToString:aRole])
            return YES;
    }
    return NO;
}

@end

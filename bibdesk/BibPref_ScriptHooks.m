//
//  BibPref_ScriptHooks.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 17/10/05.
/*
 This software is Copyright (c) 2005-2011
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

#import "BibPref_ScriptHooks.h"
#import "BDSKScriptHookManager.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKStringConstants.h"
#import "NSArray_BDSKExtensions.h"


@implementation BibPref_ScriptHooks

- (void)awakeFromNib{
	[tableView setTarget:self];
	[tableView setDoubleAction:@selector(showOrChooseScriptFile:)];
    [tableView registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
	[self tableViewSelectionDidChange:nil];
	[tableView reloadData];
}

- (void)defaultsDidRevert {
    // reset UI, but only if we loaded the nib
    if ([self isViewLoaded]) {
        [self tableViewSelectionDidChange:nil];
        [tableView reloadData];
    }
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSFileHandlingPanelCancelButton)
        return;
    
	NSString *path = [[sheet filenames] objectAtIndex: 0];
	if (path == nil)
		return;

	NSInteger row = [tableView selectedRow]; // cannot be -1
	NSString *name = [[BDSKScriptHookManager scriptHookNames] objectAtIndex:row];
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[sud dictionaryForKey:BDSKScriptHooksKey]];
	[dict setObject:path forKey:name];
	[sud setObject:dict forKey:BDSKScriptHooksKey];
	[tableView reloadData];
}

- (IBAction)addRemoveScriptHook:(id)sender{
    if (sender == nil || [sender selectedSegment] == 0) { // add
        
        if([tableView selectedRow] == -1) 
            return;
        
        NSString *directory = [[NSFileManager defaultManager] applicationSupportDirectory];
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        [openPanel setPrompt:NSLocalizedString(@"Choose", @"Prompt for Choose panel")];
        [openPanel setAllowsMultipleSelection:NO];
        [openPanel beginSheetForDirectory:directory 
                                     file:nil
                                    types:[NSArray arrayWithObjects:@"scpt", @"scptd", @"applescript", nil] 
                           modalForWindow:[[self view] window] 
                            modalDelegate:self 
                           didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) 
                              contextInfo:NULL];
        
    } else { // remove
        
        NSInteger row = [tableView selectedRow];
        if (row == -1) return;
        
        NSString *name = [[BDSKScriptHookManager scriptHookNames] objectAtIndex:row];
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[sud dictionaryForKey:BDSKScriptHooksKey]];
        [dict removeObjectForKey:name];
        [sud setObject:dict forKey:BDSKScriptHooksKey];
        [tableView reloadData];
        
    }
}

- (void)showOrChooseScriptFile:(id)sender {
	NSInteger row = [tableView clickedRow];
	
	if (row == -1)
		return;
	
	NSString *name = [[BDSKScriptHookManager scriptHookNames] objectAtIndex:row];
	NSString *path = [[sud dictionaryForKey:BDSKScriptHooksKey] objectForKey:name];
	
	if ([NSString isEmptyString:path]) {
		[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[self addRemoveScriptHook:nil];
	} else {
		NSURL *url = [NSURL fileURLWithPath:path];
		if (url)
			[[NSWorkspace sharedWorkspace] openURL:url];
		else 
			NSBeep();
	}
}

#pragma mark TableView DataSource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv{
	return [[BDSKScriptHookManager scriptHookNames] count];
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
	NSString *colID = [tableColumn identifier];
	NSString *name = [[BDSKScriptHookManager scriptHookNames] objectAtIndex:row];
	
	if([colID isEqualToString:@"name"]){
		return name;
	}else{
		return [[sud dictionaryForKey:BDSKScriptHooksKey] objectForKey:name];
	}
}

- (NSString *)tableView:(NSTableView *)tv toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation{
	NSString *colID = [tableColumn identifier];
	
	if([colID isEqualToString:@"name"])
		return nil;
	
	NSString *name = [[BDSKScriptHookManager scriptHookNames] objectAtIndex:row];
	NSString *path = [[sud dictionaryForKey:BDSKScriptHooksKey] objectForKey:name];
	
	if ([NSString isEmptyString:path])
		return NSLocalizedString(@"No script hook associated with this action. Doubleclick or use the \"+\" button to add one.", @"Tooltip message");
	else
		return [[sud dictionaryForKey:BDSKScriptHooksKey] objectForKey:name];
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op{
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
    if (type && row >= 0 && row < [tableView numberOfRows]) {
        NSString *path = [[pboard propertyListForType:NSFilenamesPboardType] firstObject];
        if ([[NSSet setWithObjects:@"scpt", @"scptd", @"applescript", nil] containsObject:[path pathExtension]]) {
            [tableView setDropRow:row dropOperation:NSTableViewDropOn];
            return NSDragOperationEvery;
        }
    }
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op{
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
    if (type) {
        NSString *path = [[pboard propertyListForType:NSFilenamesPboardType] firstObject];
        NSString *name = [[BDSKScriptHookManager scriptHookNames] objectAtIndex:row];
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[sud dictionaryForKey:BDSKScriptHooksKey]];
        [dict setObject:path forKey:name];
        [sud setObject:dict forKey:BDSKScriptHooksKey];
        [tableView reloadData];
        return YES;
    }
    return NO;
}

#pragma mark TableView Delegate methods

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification{
	NSInteger row = [tableView selectedRow];
	[addRemoveButton setEnabled:(row != -1) forSegment:0];
	[addRemoveButton setEnabled:(row != -1) forSegment:1];
}

- (BOOL)tableView:(NSTableView *)tv shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
	return NO;
}

- (void)tableView:(NSTableView *)tv deleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
    if ([rowIndexes count]) {
        NSArray *names = [BDSKScriptHookManager scriptHookNames];
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[sud dictionaryForKey:BDSKScriptHooksKey]];
        NSUInteger row = [rowIndexes firstIndex];
        while (row != NSNotFound) {
            [dict removeObjectForKey:[names objectAtIndex:row]];
            row = [rowIndexes indexGreaterThanIndex:row];
        }
        [sud setObject:dict forKey:BDSKScriptHooksKey];
        [tableView reloadData];
    }
}

@end

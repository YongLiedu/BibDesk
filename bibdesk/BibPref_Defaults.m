// BibPref_Defaults.m
// Created by Michael McCracken, 2002
/*
 This software is Copyright (c) 2002-2009
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BibPref_Defaults.h"
#import <OmniFoundation/OmniFoundation.h>
#import "BDSKTypeInfoEditor.h"
#import "BDSKBibTeXParser.h"
#import "BDSKMacroResolver.h"
#import "NSArray_BDSKExtensions.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSMenu_BDSKExtensions.h"
#import "BDSKStringConstants.h"
#import "BDSKFieldNameFormatter.h"
#import "BDSKMacroWindowController.h"
#import "BDSKPreferenceRecord.h"

// this corresponds with the menu item order in the nib
enum {
    BDSKStringType = 0,
    BDSKLocalFileType,
    BDSKRemoteURLType,
    BDSKBooleanType,
    BDSKTriStateType,
    BDSKRatingType,
    BDSKCitationType,
    BDSKPersonType
};

static NSSet *alwaysDisabledFields = nil;

@implementation BibPref_Defaults

+ (void)initialize {
    if (nil == alwaysDisabledFields)
        alwaysDisabledFields = [[NSSet alloc] initWithObjects:BDSKAuthorString, BDSKEditorString, nil];
}

- (id)initWithRecord:(BDSKPreferenceRecord *)aRecord forPreferenceController:(BDSKPreferenceController *)aController {
	if(self = [super initWithRecord:aRecord forPreferenceController:aController]){
        globalMacroFiles = [[NSMutableArray alloc] initWithArray:[[NSUserDefaults standardUserDefaults] stringArrayForKey:BDSKGlobalMacroFilesKey]];
       
        customFieldsArray = [[NSMutableArray alloc] initWithCapacity:6];
		customFieldsSet = [[NSMutableSet alloc] initWithCapacity:6];
		
		// initialize the default fields from the prefs
		NSArray *defaultFields = [[NSUserDefaults standardUserDefaults] arrayForKey:BDSKDefaultFieldsKey];
		NSEnumerator *e;
		NSString *field = nil;
		NSMutableDictionary *dict = nil;
		NSNumber *type;
		NSNumber *isDefault;
		
		// Add Local File fields
		e = [[[NSUserDefaults standardUserDefaults] arrayForKey:BDSKLocalFileFieldsKey] objectEnumerator];
		type = [NSNumber numberWithInt:BDSKLocalFileType];
		while(field = [e nextObject]){
			isDefault = [NSNumber numberWithBool:[defaultFields containsObject:field]];
			dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:field, @"field", type, @"type", isDefault, @"default", nil];
			[customFieldsArray addObject:dict];
			[customFieldsSet addObject:field];
		}
		
		// Add Remote URL fields
		e = [[[NSUserDefaults standardUserDefaults] arrayForKey:BDSKRemoteURLFieldsKey] objectEnumerator];
		type = [NSNumber numberWithInt:BDSKRemoteURLType];
		while(field = [e nextObject]){
			isDefault = [NSNumber numberWithBool:[defaultFields containsObject:field]];
			dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:field, @"field", type, @"type", isDefault, @"default", nil];
			[customFieldsArray addObject:dict];
			[customFieldsSet addObject:field];
		}
		
		// Add Boolean fields
		e = [[[NSUserDefaults standardUserDefaults] arrayForKey:BDSKBooleanFieldsKey] objectEnumerator];
		type = [NSNumber numberWithInt:BDSKBooleanType];
		while(field = [e nextObject]){
			isDefault = [NSNumber numberWithBool:[defaultFields containsObject:field]];
			dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:field, @"field", type, @"type", isDefault, @"default", nil];
			[customFieldsArray addObject:dict];
			[customFieldsSet addObject:field];
		}
        
        // Add Tri-State fields
		e = [[[NSUserDefaults standardUserDefaults] arrayForKey:BDSKTriStateFieldsKey] objectEnumerator];
		type = [NSNumber numberWithInt:BDSKTriStateType];
		while(field = [e nextObject]){
			isDefault = [NSNumber numberWithBool:[defaultFields containsObject:field]];
			dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:field, @"field", type, @"type", isDefault, @"default", nil];
			[customFieldsArray addObject:dict];
			[customFieldsSet addObject:field];
		}
        
		// Add Rating fields
		e = [[[NSUserDefaults standardUserDefaults] arrayForKey:BDSKRatingFieldsKey] objectEnumerator];
		type = [NSNumber numberWithInt:BDSKRatingType];
		while(field = [e nextObject]){
			isDefault = [NSNumber numberWithBool:[defaultFields containsObject:field]];
			dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:field, @"field", type, @"type", isDefault, @"default", nil];
			[customFieldsArray addObject:dict];
			[customFieldsSet addObject:field];
		}
        
		// Add Citation fields
		e = [[[NSUserDefaults standardUserDefaults] arrayForKey:BDSKCitationFieldsKey] objectEnumerator];
		type = [NSNumber numberWithInt:BDSKCitationType];
		while(field = [e nextObject]){
			isDefault = [NSNumber numberWithBool:[defaultFields containsObject:field]];
			dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:field, @"field", type, @"type", isDefault, @"default", nil];
			[customFieldsArray addObject:dict];
			[customFieldsSet addObject:field];
		}
        
		// Add Person fields
		e = [[[NSUserDefaults standardUserDefaults] arrayForKey:BDSKPersonFieldsKey] objectEnumerator];
		type = [NSNumber numberWithInt:BDSKPersonType];
		while(field = [e nextObject]){
			isDefault = [NSNumber numberWithBool:[defaultFields containsObject:field]];
			dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:field, @"field", type, @"type", isDefault, @"default", nil];
			[customFieldsArray addObject:dict];
			[customFieldsSet addObject:field];
		}        
		
		// Add any remaining Textual default fields at the beginning
		e = [defaultFields reverseObjectEnumerator];
		type = [NSNumber numberWithInt:BDSKStringType];
		isDefault = [NSNumber numberWithBool:YES];
		while(field = [e nextObject]){
			if([customFieldsSet containsObject:field])
				continue;
			dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:field, @"field", type, @"type", isDefault, @"default", nil];
			[customFieldsArray insertObject:dict atIndex:0];
			[customFieldsSet addObject:field];
		}
	}
	return self;
}

- (void)awakeFromNib{
    BDSKFieldNameFormatter *fieldNameFormatter = [[BDSKFieldNameFormatter alloc] init];
    [[[[defaultFieldsTableView tableColumns] objectAtIndex:0] dataCell] setFormatter:fieldNameFormatter];
    [fieldNameFormatter release];
    [globalMacroFilesTableView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
    
    NSWorkspace *sws = [NSWorkspace sharedWorkspace];
    NSArray *pdfViewers = [[NSWorkspace sharedWorkspace] editorAndViewerNamesAndBundleIDsForPathExtension:@"pdf"];
    NSString *pdfViewerID = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:BDSKDefaultViewersKey] objectForKey:@"pdf"];
    int i, iMax = [pdfViewers count];
    int idx = 0;
    
    for(i = 0; i < iMax; i++){
        NSDictionary *dict = [pdfViewers objectAtIndex:i];
        NSString *bundleID = [dict objectForKey:@"bundleID"];
        NSString *appPath = [sws absolutePathForAppBundleWithIdentifier:bundleID];
        [pdfViewerPopup insertItemWithTitle:[dict objectForKey:@"name"] atIndex:i + 2];
        [[pdfViewerPopup itemAtIndex:i + 2] setRepresentedObject:bundleID];
        [(NSMenuItem *)[pdfViewerPopup itemAtIndex:i + 2] setImageAndSize:[sws iconForFile:appPath]];
        if([pdfViewerID isEqualToString:bundleID])
            idx = i + 2;
    }
    if(idx == 0 && [pdfViewerID length]){
        NSString *name = [[[[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:pdfViewerID] lastPathComponent] stringByDeletingPathExtension];
        [pdfViewerPopup insertItemWithTitle:name atIndex:2];
        [[pdfViewerPopup itemAtIndex:2] setRepresentedObject:pdfViewerID];
        idx = 2;
    }
    
    [pdfViewerPopup selectItemAtIndex:idx];
}

- (void)updatePrefs{
	// we have to make sure that Local-Url and Url are the first in the list
	NSMutableArray *defaultFields = [[NSMutableArray alloc] initWithCapacity:6];
	NSMutableArray *localFileFields = [[NSMutableArray alloc] initWithCapacity:1];
	NSMutableArray *remoteURLFields = [[NSMutableArray alloc] initWithCapacity:1];
    NSMutableArray *ratingFields = [[NSMutableArray alloc] initWithCapacity:1];
    NSMutableArray *booleanFields = [[NSMutableArray alloc] initWithCapacity:1];
    NSMutableArray *triStateFields = [[NSMutableArray alloc] initWithCapacity:1];
    NSMutableArray *citationFields = [[NSMutableArray alloc] initWithCapacity:1];
    NSMutableArray *personFields = [[NSMutableArray alloc] initWithCapacity:1];
	
	NSEnumerator *e = [customFieldsArray objectEnumerator];
	NSDictionary *dict = nil;
	NSString *field;
	int type;
	
	while(dict = [e nextObject]){
		field = [dict objectForKey:@"field"]; 
		type = [[dict objectForKey:@"type"] intValue];
		if([[dict objectForKey:@"default"] boolValue])
			[defaultFields addObject:field];
        switch(type){
            case BDSKStringType:
                break;
            case BDSKLocalFileType:
                [localFileFields addObject:field];
                break;
            case BDSKRemoteURLType:
                [remoteURLFields addObject:field];
                break;
            case BDSKBooleanType:
                [booleanFields addObject:field];
                break;
            case BDSKRatingType:
                [ratingFields addObject:field];
                break;
            case BDSKTriStateType:
                [triStateFields addObject:field];
                break;
            case BDSKCitationType:
                [citationFields addObject:field];
                break;
            case BDSKPersonType:
                [personFields addObject:field];
                break;
            default:
                [NSException raise:NSInvalidArgumentException format:@"Attempt to set unrecognized type"];
        }
	}
	[[NSUserDefaults standardUserDefaults] setObject:defaultFields forKey:BDSKDefaultFieldsKey];
	[[NSUserDefaults standardUserDefaults] setObject:localFileFields forKey:BDSKLocalFileFieldsKey];
	[[NSUserDefaults standardUserDefaults] setObject:remoteURLFields forKey:BDSKRemoteURLFieldsKey];
    [[NSUserDefaults standardUserDefaults] setObject:ratingFields forKey:BDSKRatingFieldsKey];
    [[NSUserDefaults standardUserDefaults] setObject:booleanFields forKey:BDSKBooleanFieldsKey];
    [[NSUserDefaults standardUserDefaults] setObject:triStateFields forKey:BDSKTriStateFieldsKey];
    [[NSUserDefaults standardUserDefaults] setObject:citationFields forKey:BDSKCitationFieldsKey];
    [[NSUserDefaults standardUserDefaults] setObject:personFields forKey:BDSKPersonFieldsKey];
    [defaultFields release];
    [localFileFields release];
    [remoteURLFields release];
    [ratingFields release];
    [booleanFields release];
    [triStateFields release];
    [citationFields release];
    [personFields release];
    
	[defaultFieldsTableView reloadData];
	[self updateUI];
	
    // !!! notification of these changes is posted by the type manager, which observes the pref keys; this ensures that the type manager gets notified first, so notification observers don't get stale data; as a consequence, if you add another custom field type, the type manager needs to observe it in -init
}

- (void)updateUI{	
    [convertURLFieldsButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKAutomaticallyConvertURLFieldsKey] ? NSOnState : NSOffState];
    [removeLocalFileFieldsButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKRemoveConvertedLocalFileFieldsKey] ? NSOnState : NSOffState];
    [removeRemoteURLFieldsButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKRemoveConvertedRemoteURLFieldsKey] ? NSOnState : NSOffState];
	[removeLocalFileFieldsButton setEnabled:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKAutomaticallyConvertURLFieldsKey]];
	[removeRemoteURLFieldsButton setEnabled:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKAutomaticallyConvertURLFieldsKey]];
    
    int row = [defaultFieldsTableView selectedRow];
	if(row == -1){
		[delSelectedDefaultFieldButton setEnabled:NO];
		return;
	}
	NSString *field = [[customFieldsArray objectAtIndex:row] objectForKey:@"field"];
	if([alwaysDisabledFields containsObject:field])
		[delSelectedDefaultFieldButton setEnabled:NO];
	else
		[delSelectedDefaultFieldButton setEnabled:YES];
}

- (void)dealloc{
    [globalMacroFiles release];
    [customFieldsArray release];
    [customFieldsSet release];
    [macroWC release];
	[fieldTypeMenu release];
    [super dealloc];
}

#pragma mark URL field conversion

- (IBAction)changeConvertURLFields:(id)sender {
    BOOL autoConvert = [sender state] == NSOnState;
    [[NSUserDefaults standardUserDefaults] setBool:autoConvert forKey:BDSKAutomaticallyConvertURLFieldsKey];
	[removeLocalFileFieldsButton setEnabled:autoConvert];
	[removeRemoteURLFieldsButton setEnabled:autoConvert];
}

- (IBAction)changeRemoveLocalFileFields:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState) forKey:BDSKRemoveConvertedLocalFileFieldsKey];
}

- (IBAction)changeRemoveRemoteURLFields:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState) forKey:BDSKRemoveConvertedRemoteURLFieldsKey];
}

#pragma mark TableView DataSource methods

- (int)numberOfRowsInTableView:(NSTableView *)tableView{
    if (tableView == defaultFieldsTableView)
        return [customFieldsArray count];
    else if (tableView == globalMacroFilesTableView)
        return [globalMacroFiles count];
    return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    if (tableView == defaultFieldsTableView) {
        return [[customFieldsArray objectAtIndex:row] objectForKey:[tableColumn identifier]];
    } else if (tableView == globalMacroFilesTableView) {
        return [globalMacroFiles objectAtIndex:row];
    }
    return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    if (tableView == defaultFieldsTableView) {
        NSString *colID = [tableColumn identifier];
        NSString *field = [[customFieldsArray objectAtIndex:row] objectForKey:@"field"];
        
        if([colID isEqualToString:@"field"]){
            if([customFieldsSet containsObject:object])
                return; // don't add duplicate fields
            [customFieldsSet removeObject:field];
            if([object isEqualToString:@""]){
                [customFieldsArray removeObjectAtIndex:row];
            }else{
                [[customFieldsArray objectAtIndex:row] setObject:object forKey:colID];
                [customFieldsSet addObject:object];
            }
        }else{
            [[customFieldsArray objectAtIndex:row] setObject:object forKey:colID];
        }
        [self updatePrefs];
    } else if (tableView == globalMacroFilesTableView) {
        NSString *pathString = [object stringByStandardizingPath];
        NSString *extension = [object pathExtension];
        BOOL isDir = NO;
        NSString *error = nil;
        
        if([[NSFileManager defaultManager] fileExistsAtPath:pathString isDirectory:&isDir] == NO){
            error = [NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" does not exist.", @"Informative text in alert dialog"), object];
        } else if (isDir == YES) {
            error = [NSString stringWithFormat:NSLocalizedString(@"\"%@\" is not a file.", @"Informative text in alert dialog"), object];
        } else if ([extension caseInsensitiveCompare:@"bib"] != NSOrderedSame && [extension caseInsensitiveCompare:@"bst"] != NSOrderedSame) {
            error = [NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" is neither a BibTeX bibliography file nor a BibTeX style file.", @"Informative text in alert dialog"), object];
        }
        if (error) {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Macro File", @"Message in alert dialog when adding an invalid global macros file")
                                             defaultButton:nil
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:error];
            [alert beginSheetModalForWindow:globalMacroFileSheet modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
        } else {
            [globalMacroFiles replaceObjectAtIndex:row withObject:object];
            [[NSUserDefaults standardUserDefaults] setObject:globalMacroFiles forKey:BDSKGlobalMacroFilesKey];
        }
        [globalMacroFilesTableView reloadData];
    }
}

#pragma mark | TableView Dragging

- (NSDragOperation)tableView:(NSTableView*)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op{
    if (tableView != globalMacroFilesTableView) 
        return NSDragOperationNone;
    return NSDragOperationEvery;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo> )info row:(int)row dropOperation:(NSTableViewDropOperation)op{
    if (tableView != globalMacroFilesTableView) 
        return NO;
    NSPasteboard *pboard = [info draggingPasteboard];
    if([pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]] == nil)
        return NO;
    NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
    NSEnumerator *fileEnum = [fileNames objectEnumerator];
    NSString *file;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    while (file = [fileEnum nextObject]) {
        NSString *extension = [file pathExtension];
        if ([fm fileExistsAtPath:[file stringByStandardizingPath]] == NO ||
            ([extension caseInsensitiveCompare:@"bib"] != NSOrderedSame && [extension caseInsensitiveCompare:@"bst"] != NSOrderedSame))
            continue;
        [globalMacroFiles addObject:file];
    }
    [[NSUserDefaults standardUserDefaults] setObject:globalMacroFiles forKey:BDSKGlobalMacroFilesKey];
    
    [globalMacroFilesTableView reloadData];
    
    return YES;
}

#pragma mark TableView Delegate methods

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    if (tableView == defaultFieldsTableView) {
        
        return YES;
    } else if (tableView == globalMacroFilesTableView) {
        return YES;
    }
    return NO;
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    if (tableView == defaultFieldsTableView) {
        NSString *field = [[customFieldsArray objectAtIndex:row] objectForKey:@"field"];
        
        if([alwaysDisabledFields containsObject:field])
            [cell setEnabled:NO];
        else
            [cell setEnabled:YES];
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification{
    if ([[aNotification object] isEqual:defaultFieldsTableView]) {
        int row = [defaultFieldsTableView selectedRow];
        if(row == -1){
            [delSelectedDefaultFieldButton setEnabled:NO];
            return;
        }
        NSString *field = [[customFieldsArray objectAtIndex:row] objectForKey:@"field"];
        if([alwaysDisabledFields containsObject:field])
            [delSelectedDefaultFieldButton setEnabled:NO];
        else
            [delSelectedDefaultFieldButton setEnabled:YES];
    }
}

#pragma mark Add and Del fields buttons

- (IBAction)delSelectedDefaultField:(id)sender{
	int row = [defaultFieldsTableView selectedRow];
    if(row != -1){
		if([defaultFieldsTableView editedRow] != -1)
			[[defaultFieldsTableView window] makeFirstResponder:nil];
        [customFieldsSet removeObject:[[customFieldsArray objectAtIndex:row] objectForKey:@"field"]];
        [customFieldsArray removeObjectAtIndex:row];
        [self updatePrefs];
    }
}

- (IBAction)addDefaultField:(id)sender{
    int row = [customFieldsArray count];
	NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithObjectsAndKeys: @"Field", @"field", [NSNumber numberWithInt:BDSKStringType], @"type", [NSNumber numberWithBool:NO], @"default", nil]; // do not localize
	[customFieldsArray addObject:newDict];
    [defaultFieldsTableView reloadData];
    [defaultFieldsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	[[[defaultFieldsTableView tableColumnWithIdentifier:@"field"] dataCell] setEnabled:YES]; // hack to make sure we can edit, as the delegate method is called too late
    [defaultFieldsTableView editColumn:0 row:row withEvent:nil select:YES];
	// don't update the prefs yet, as the user should first set the field name
}


- (IBAction)showTypeInfoEditor:(id)sender{
	[[BDSKTypeInfoEditor sharedTypeInfoEditor] beginSheetModalForWindow:[[self view] window]];
}

#pragma mark default viewer

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void  *)contextInfo{
    NSString *bundleID;
    if (returnCode == NSOKButton)
        bundleID = [[NSBundle bundleWithPath:[panel filename]] bundleIdentifier];
    else
        bundleID = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:BDSKDefaultViewersKey] objectForKey:@"pdf"];
    
    if([bundleID length]){
        int i, iMax = [pdfViewerPopup numberOfItems] - 2;
        
        for(i = 2; i < iMax; i++){
            if([[[pdfViewerPopup itemAtIndex:i] representedObject] isEqualToString:bundleID]){
                [pdfViewerPopup selectItemAtIndex:i];
                break;
            }
        }
        if(i == iMax){
            NSString *appPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:bundleID];
            NSString *name = [[appPath lastPathComponent] stringByDeletingPathExtension];
            [pdfViewerPopup insertItemWithTitle:name atIndex:2];
            [[pdfViewerPopup itemAtIndex:2] setRepresentedObject:bundleID];
            [(NSMenuItem *)[pdfViewerPopup itemAtIndex:2] setImageAndSize:[[NSWorkspace sharedWorkspace] iconForFile:appPath]];
            [pdfViewerPopup selectItemAtIndex:2];
        }
    }else{
        [pdfViewerPopup selectItemAtIndex:0];
    }
    NSMutableDictionary *defaultViewers = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:BDSKDefaultViewersKey] mutableCopy];
    if ([bundleID length])
        [defaultViewers setObject:bundleID forKey:@"pdf"];
    else
        [defaultViewers removeObjectForKey:@"pdf"];
    [[NSUserDefaults standardUserDefaults] setObject:defaultViewers forKey:BDSKDefaultViewersKey];
    [defaultViewers release];
}

- (IBAction)changeDefaultPDFViewer:(id)sender{
    if([sender indexOfSelectedItem] == [sender numberOfItems] - 1){
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        [openPanel setCanChooseDirectories:NO];
        [openPanel setAllowsMultipleSelection:NO];
        [openPanel setPrompt:NSLocalizedString(@"Choose Viewer", @"Prompt for Choose panel")];
        
        [openPanel beginSheetForDirectory:[[NSFileManager defaultManager] applicationsDirectory] 
                                     file:nil 
                                    types:[NSArray arrayWithObjects:@"app", nil]
                           modalForWindow:[[self view] window]
                            modalDelegate:self
                           didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
                              contextInfo:NULL];
    }else{
        NSString *bundleID = [[sender selectedItem] representedObject];
        NSMutableDictionary *defaultViewers = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:BDSKDefaultViewersKey] mutableCopy];
        if ([bundleID length])
            [defaultViewers setObject:bundleID forKey:@"pdf"];
        else
            [defaultViewers removeObjectForKey:@"pdf"];
        [[NSUserDefaults standardUserDefaults] setObject:defaultViewers forKey:BDSKDefaultViewersKey];
        [defaultViewers release];
    }
}

#pragma mark BST macro methods

- (IBAction)showMacrosWindow:(id)sender{
	if (!macroWC){
		macroWC = [[BDSKMacroWindowController alloc] initWithMacroResolver:[BDSKMacroResolver defaultMacroResolver]];
	}
	[macroWC beginSheetModalForWindow:[[self view] window]];
}

- (IBAction)showMacroFileWindow:(id)sender{
	[NSApp beginSheet:globalMacroFileSheet
       modalForWindow:[[self view] window]
        modalDelegate:nil
       didEndSelector:NULL
          contextInfo:nil];
}

- (IBAction)closeMacroFileWindow:(id)sender{
    [globalMacroFileSheet orderOut:sender];
    [NSApp endSheet:globalMacroFileSheet];
}

- (IBAction)addGlobalMacroFile:(id)sender{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection:YES];
    [openPanel setResolvesAliases:NO];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setPrompt:NSLocalizedString(@"Choose", @"Prompt for Choose panel")];

    [openPanel beginSheetForDirectory:@"/usr" 
                                 file:nil 
                                types:[NSArray arrayWithObjects:@"bib", @"bst", nil] 
                       modalForWindow:globalMacroFileSheet
                        modalDelegate:self 
                       didEndSelector:@selector(addGlobalMacroFilePanelDidEnd:returnCode:contextInfo:) 
                          contextInfo:nil];
}

- (void)addGlobalMacroFilePanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    if(returnCode == NSCancelButton)
        return;
    
    [globalMacroFiles addNonDuplicateObjectsFromArray:[openPanel filenames]];
    [globalMacroFilesTableView reloadData];
    [[NSUserDefaults standardUserDefaults] setObject:globalMacroFiles forKey:BDSKGlobalMacroFilesKey];
}

- (IBAction)delGlobalMacroFiles:(id)sender{
    NSIndexSet *indexes = [globalMacroFilesTableView selectedRowIndexes];
    
    [globalMacroFiles removeObjectsAtIndexes:indexes];
    
    [globalMacroFilesTableView reloadData];
    [[NSUserDefaults standardUserDefaults] setObject:globalMacroFiles forKey:BDSKGlobalMacroFilesKey];
}

@end

@implementation MacroFileTableView

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
    return NSDragOperationCopy;
}

- (void)keyDown:(NSEvent *)event{
    if ([[event characters] length] == 0)
        return;
    unichar c = [[event characters] characterAtIndex:0];
    if (c == NSDeleteCharacter ||
        c == NSBackspaceCharacter) {
        [[self delegate] delGlobalMacroFiles:nil];
    }else if(c == NSNewlineCharacter ||
             c == NSEnterCharacter ||
             c == NSCarriageReturnCharacter){
                if([self numberOfSelectedRows] == 1)
                    [self editColumn:0 row:[self selectedRow] withEvent:nil select:YES];
    }else{
        [super keyDown:event];
    }
}

@end

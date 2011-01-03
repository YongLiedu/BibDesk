//  BDSKCustomCiteDrawerController.m
//  BibDesk
//
//  Created by Christiaan Hofman on 11/15/2006.
/*
 This software is Copyright (c) 2006-2011
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

#import "BDSKCustomCiteDrawerController.h"
#import "BibDocument.h"
#import "BibDocument_DataSource.h"
#import "BibDocument_Groups.h"


@implementation BDSKCustomCiteDrawerController

- (id)initForDocument:(BibDocument *)aDocument{
    if(self = [super init]){
		customStringArray = [[NSMutableArray arrayWithCapacity:6] retain];
		[customStringArray setArray:[[NSUserDefaults standardUserDefaults] arrayForKey:BDSKCustomCiteStringsKey]];
        document = aDocument;
    }
    return self;
}

- (void)dealloc{
    [tableView setDelegate:nil];
    [tableView setDataSource:nil];
    document = nil;
    BDSKDESTROY(customStringArray);
    [super dealloc];
}

- (NSString *)windowNibName{
    return @"BDSKCustomCiteDrawer";
}

- (void)awakeFromNib{
    [drawer setParentWindow:[document windowForSheet]];
    NSSize drawerSize = [drawer contentSize];
    drawerSize.width = 100.0;
    [drawer setContentSize:drawerSize];
}

- (NSTableView *)tableView{
    return tableView;
}

- (BOOL)isDrawerOpen{
    if(drawer == nil)
        return NO;
    NSInteger state = [drawer state];
    return state == NSDrawerOpenState || state == NSDrawerOpeningState;
}

#pragma mark Actions

- (IBAction)toggle:(id)sender{
    [self window];
    [drawer toggle:sender];
}

- (IBAction)addRemoveCustomCiteString:(id)sender{
    if ([sender selectedSegment] == 0) { // add
        
        NSInteger row = [customStringArray count];
        [customStringArray addObject:@"citeCommand"];
        [tableView reloadData];
        [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [tableView editColumn:0 row:row withEvent:nil select:YES];
        
    } else { // remove
        
        if([tableView numberOfSelectedRows] == 0)
            return;
        
        if ([tableView editedRow] != -1)
            [[drawer parentWindow] makeFirstResponder:tableView];
        [customStringArray removeObjectAtIndex:[tableView selectedRow]];
        [tableView reloadData];
        
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:customStringArray forKey:BDSKCustomCiteStringsKey];
}

#pragma mark -
#pragma mark TableView data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tView{
    return [customStringArray count];
}

- (id)tableView:(NSTableView *)tView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    return [customStringArray objectAtIndex:row];
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    [customStringArray replaceObjectAtIndex:row withObject:object];
    [[NSUserDefaults standardUserDefaults] setObject:customStringArray forKey:BDSKCustomCiteStringsKey];
}

#pragma mark TableView delegate

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification{
    [addRemoveButton setEnabled:([tableView numberOfSelectedRows] > 0) forSegment:1];
}

#pragma mark TableView dragging source

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard{
	NSString *citeString = [customStringArray objectAtIndex:[rowIndexes firstIndex]];
    NSArray *pubs = [document selectedPublications];
    
	BDSKPRECONDITION(pboard == [NSPasteboard pasteboardWithName:NSDragPboard] || pboard == [NSPasteboard pasteboardWithName:NSGeneralPboard]);

    [document setDragFromExternalGroups:[document hasExternalGroupsSelected]];
    
    // check the publications table to see if an item is selected, otherwise we get an error on dragging from the cite drawer
    if([pubs count] == 0){
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Nothing selected in document", @"Message in alert dialog when trying to drag from drawer with empty selection") 
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"You need to select an item in the document before dragging from the cite drawer.", @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:[drawer parentWindow] modalDelegate:nil didEndSelector:nil contextInfo:NULL];
        return NO;
    }
	
	return [document writePublications:pubs forDragCopyType:BDSKCiteDragCopyType citeString:citeString toPasteboard:pboard];
}

- (void)tableView:(NSTableView *)tv concludeDragOperation:(NSDragOperation)operation{
	[document clearPromisedDraggedItems];
}

- (NSDragOperation)tableView:(NSTableView *)tv draggingSourceOperationMaskForLocal:(BOOL)isLocal{
    return isLocal ? NSDragOperationNone : NSDragOperationCopy;
}

- (NSImage *)tableView:(NSTableView *)tv dragImageForRowsWithIndexes:(NSIndexSet *)dragRows{
    return [document dragImageForPromisedItemsUsingCiteString:[customStringArray objectAtIndex:[dragRows firstIndex]]];
}

@end

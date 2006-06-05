//
//  BDSKDocumentInfoWindowController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 5/31/06.
/*
 This software is Copyright (c) 2006
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

#import "BDSKDocumentInfoWindowController.h"
#import "BibDocument.h"


@implementation BDSKDocumentInfoWindowController

- (id)init {
    self = [self initWithDocument:nil];
    return self;
}

- (id)initWithDocument:(BibDocument *)aDocument {
    if (self = [super initWithWindowNibName:@"DocumentInfoWindow"]) {
        document = aDocument;
        keys = nil;
    }
    return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [keys release];
    [super dealloc];
}

- (void)awakeFromNib{
    [self refreshKeys];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender{
    return [document undoManager];
}

- (void)refreshKeys{
    [keys release];
    keys = nil;
}

- (NSArray *)keys{
    if (keys == nil) {
        keys = [[NSMutableArray alloc] initWithArray:[[document documentInfo] allKeys]];
        [keys sortUsingSelector:@selector(compare:)];
    }
    return keys;
}

- (void)beginSheetModalForWindow:(NSWindow *)modalWindow{
    [NSApp beginSheet:[self window] modalForWindow:modalWindow modalDelegate:nil didEndSelector:NULL contextInfo:nil];
    
    [self refreshKeys];
    [tableView reloadData];
}

- (IBAction)done:(id)sender{
	if(![[self window] makeFirstResponder:[self window]])
        [[self window] endEditingFor:nil];
    
    [self refreshKeys];
    
    [[self window] orderOut:sender];
    [NSApp endSheet:[self window] returnCode:[sender tag]];
}

- (IBAction)addKey:(id)sender{
    // find a unique new key
    [self keys]; // make sure the keys are loaded
    int i = 0;
    NSString *newKey = [NSString stringWithString:@"key"];
    while([keys containsObject:newKey] != nil){
        newKey = [NSString stringWithFormat:@"key", ++i];
    }
    
    [document setDocumentInfo:@"" forKey:newKey];
    [self refreshKeys];
    [tableView reloadData];
    [[document undoManager] setActionName:NSLocalizedString(@"Add Document Info Key", @"add document info key action name for undo")];

    int row = [[self keys] indexOfObject:newKey];
    [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [tableView editColumn:0 row:row withEvent:nil select:YES];
}

- (IBAction)removeSelectedKeys:(id)sender{
	NSIndexSet *rowIndexes = [tableView selectedRowIndexes];
	int row = [rowIndexes firstIndex];

    // used because we modify the keys array during the loop
    NSArray *shadowOfKeys = [[[self keys] copy] autorelease];
    
    // in case we're editing the selected field we need to end editing.
    // we don't give it a chance to modify state.
    [[self window] endEditingFor:[tableView selectedCell]];

    while(row != NSNotFound){
        [document setDocumentInfo:nil forKey:[shadowOfKeys objectAtIndex:row]];
		row = [rowIndexes indexGreaterThanIndex:row];
    }
    [self refreshKeys];
    [tableView reloadData];
    [[document undoManager] setActionName:NSLocalizedString(@"Remove Document Info", @"remove document info action name for undo")];
}

#pragma mark TableView DataSource methods

- (int)numberOfRowsInTableView:(NSTableView *)tv{
    return [[self keys] count];
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    NSString *key = [[self keys] objectAtIndex:row];
    
    if([[tableColumn identifier] isEqualToString:@"key"]){
         return key;
    }else{
         return [document documentInfoForKey:key];
    }
    
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    NSString *key = [[self keys] objectAtIndex:row];
    NSString *value = [document documentInfoForKey:key];
    
    if([[tableColumn identifier] isEqualToString:@"key"]){
		
		if([object isEqualToString:@""]){
			NSRunAlertPanel(NSLocalizedString(@"Empty Key", @"Empty Key"),
							NSLocalizedString(@"The key can not be empty.", @""),
							NSLocalizedString(@"OK", @"OK"), nil, nil);
			
			[tv reloadData];
			return;
		}
        
        if([document documentInfoForKey:object]){
            if([key caseInsensitiveCompare:object] != NSOrderedSame){			
                NSRunAlertPanel(NSLocalizedString(@"Duplicate Key", @"Duplicate Key"),
                                NSLocalizedString(@"The key must be unique.", @""),
                                NSLocalizedString(@"OK", @"OK"), nil, nil);
                
                [tv reloadData];
			}
            return;
		}
        
        [document setDocumentInfo:value forKey:object];
        [document setDocumentInfo:nil forKey:key];
		[[document undoManager] setActionName:NSLocalizedString(@"Change Document Info Key", @"change document info key action name for undo")];
        [self refreshKeys];
        
    }else{
        
        if([value isEqualToString:object]) return;
        
        if([value isStringTeXQuotingBalancedWithBraces:YES connected:NO] == NO){
            NSRunAlertPanel(NSLocalizedString(@"Unbalanced Braces", @"Unbalanced Braces"),
                            NSLocalizedString(@"Braces must be balanced within the value.", @""),
                            NSLocalizedString(@"OK", @"OK"), nil, nil);
            
            [tv reloadData];
            return;
		}
        
        [document setDocumentInfo:object forKey:key];
		[[document undoManager] setActionName:NSLocalizedString(@"Change Document Info", @"change document info action name for undo")];
    }
}

@end

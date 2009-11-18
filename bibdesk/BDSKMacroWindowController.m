//
//  BDSKMacroWindowController.m
//  BibDesk
//
//  Created by Michael McCracken on 2/21/05.
/*
 This software is Copyright (c) 2005-2009
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

#import "BDSKMacroWindowController.h"
#import "BDSKOwnerProtocol.h"
#import "BDSKComplexString.h" // for BDSKMacroResolver protocol
#import "BDSKStringConstants.h" // for notification name declarations
#import "BDSKComplexStringEditor.h"
#import "NSString_BDSKExtensions.h"
#import "BDSKBibTeXParser.h"
#import "BDSKGroup.h"
#import "BibItem.h"
#import "BDSKMacroResolver.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKTypeSelectHelper.h"
#import "BibDocument.h"
#import "BDSKMacro.h"

@implementation BDSKMacroWindowController

- (id)init {
    self = [self initWithMacroResolver:nil];
    return self;
}

- (id)initWithMacroResolver:(BDSKMacroResolver *)aMacroResolver {
    if (self = [super initWithWindowNibName:@"MacroWindow"]) {
        macroResolver = [aMacroResolver retain];
        
        // a shadow array to keep the macro keys of the document.
        macros = [[NSMutableArray alloc] initWithCapacity:5];
                
		tableCellFormatter = [[BDSKComplexStringFormatter alloc] initWithDelegate:self macroResolver:aMacroResolver];
		complexStringEditor = nil;
        
        isEditable = (macroResolver == [BDSKMacroResolver defaultMacroResolver] || [[macroResolver owner] isDocument]);
        
        [self reloadMacros];
        
        // register to listen for changes in the macros.
        // mostly used to correctly catch undo changes.
        if (aMacroResolver) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(handleMacroChangedNotification:)
                                                         name:BDSKMacroDefinitionChangedNotification
                                                       object:aMacroResolver];
            if (aMacroResolver != [BDSKMacroResolver defaultMacroResolver]) {
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(handleMacroChangedNotification:)
                                                             name:BDSKMacroDefinitionChangedNotification
                                                           object:[BDSKMacroResolver defaultMacroResolver]];
            }
            if (isEditable == NO) {
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(handleGroupWillBeRemovedNotification:)
                                                             name:BDSKDidAddRemoveGroupNotification
                                                           object:nil];
            }
        }
    }
    return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [macros release];
    [tableCellFormatter release];
	[complexStringEditor release];
	[macroResolver release];
    [super dealloc];
}

- (void)updateButtons{
    [addRemoveButton setEnabled:isEditable forSegment:0];
    [addRemoveButton setEnabled:isEditable && [tableView numberOfSelectedRows] forSegment:1];
}

- (void)windowDidLoad{
    if ([[macroResolver owner] isDocument])
        [self setWindowFrameAutosaveNameOrCascade:@"BDSKMacroWindow"];
    
    NSSortDescriptor *sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
    [arrayController setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    
    NSTableColumn *tc = [tableView tableColumnWithIdentifier:@"macro"];
    [[tc dataCell] setFormatter:[[[MacroKeyFormatter alloc] init] autorelease]];
    if(isEditable)
        [tableView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil]];
    tc = [tableView tableColumnWithIdentifier:@"definition"];
    [[tc dataCell] setFormatter:tableCellFormatter];
    [tableView reloadData];
    
    [self updateButtons];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName{
    NSString *title = NSLocalizedString(@"Macros", @"title for macros window");
    if ([[macroResolver owner] isKindOfClass:[BDSKGroup class]])
        title = [NSString stringWithFormat:@"%@ %@ %@", title, [NSString emdashString], [(BDSKGroup *)[macroResolver owner] stringValue]];
    if ([NSString isEmptyString:displayName] == NO)
        title = [NSString stringWithFormat:@"%@ %@ %@", title, [NSString emdashString], displayName];
    return title;
}

- (void)synchronizeWindowTitleWithDocumentName {
    [super synchronizeWindowTitleWithDocumentName];
    // clearing the proxy icon when this does not belong to the document, somehow passing nil does not work
    if ([[macroResolver owner] isDocument] == NO)
        [[self window] setRepresentedFilename:@""];
}

- (void)windowWillClose:(NSNotification *)notification{
	if(![[self window] makeFirstResponder:[self window]])
        [[self window] endEditingFor:nil];
}

// we want to have the same undoManager as our document, so we use this 
// NSWindow delegate method to return the doc's undomanager.
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender{
    return [macroResolver undoManager];
}

- (void)reloadMacros {
    NSDictionary *macroDefinitions = showAll ? [macroResolver allMacroDefinitions] : [macroResolver macroDefinitions];
    NSMutableArray *tmpMacros = [NSMutableArray arrayWithCapacity:[macroDefinitions count]];
    
    for (NSString *key in macroDefinitions) {
        BDSKMacroResolver *resolver = [macroResolver valueOfMacro:key] ? macroResolver : [BDSKMacroResolver defaultMacroResolver];
        BDSKMacro *macro = [[BDSKMacro alloc] initWithName:key macroResolver:resolver];
        [tmpMacros addObject:macro];
        [macro release];
    }
    [self setMacros:tmpMacros];
    [arrayController rearrangeObjects];
    [tableView reloadData];
}

#pragma mark Accessors

- (BDSKMacroResolver *)macroResolver{
    return macroResolver;
}

- (NSArray *)macros {
    return macros;
}

- (void)setMacros:(NSArray *)newMacros {
    [macros setArray:newMacros];
}

- (NSUInteger)countOfMacros {
    return [macros count];
}

- (id)objectInMacrosAtIndex:(NSUInteger)idx {
    return [macros objectAtIndex:idx];
}

- (void)insertObject:(id)obj inMacrosAtIndex:(NSUInteger)idx {
    [macros insertObject:obj atIndex:idx];
}

- (void)removeObjectFromMacrosAtIndex:(NSUInteger)idx {
    [macros removeObjectAtIndex:idx];
}

- (void)replaceObjectInMacrosAtIndex:(NSUInteger)idx withObject:(id)obj {
    [macros replaceObjectAtIndex:idx withObject:obj];
}

#pragma mark Notification handlers

- (void)handleGroupWillBeRemovedNotification:(NSNotification *)notif{
	NSArray *groups = [[notif userInfo] objectForKey:@"groups"];
	
	if ([groups containsObject:[macroResolver owner]])
		[self close];
}

- (void)handleMacroChangedNotification:(NSNotification *)notif{
    NSDictionary *info = [notif userInfo];
    BDSKMacroResolver *sender = [notif object];
    if (showAll) {
        // this is complicated, as macros can shadow macros from the other resolver
        if (sender == macroResolver || sender == [BDSKMacroResolver defaultMacroResolver])
            [self reloadMacros];
    } else if (sender == macroResolver) {
        NSString *type = [info objectForKey:@"type"];
        if ([type isEqualToString:@"Add macro"]) {
            NSString *key = [info objectForKey:@"macroKey"];
            BDSKMacro *macro = [[BDSKMacro alloc] initWithName:key macroResolver:macroResolver];
            [self insertObject:macro inMacrosAtIndex:[self countOfMacros]];
            [macro release];
        } else if ([type isEqualToString:@"Remove macro"]) {
            NSString *key = [info objectForKey:@"macroKey"];
            if (key) {
                NSUInteger idx = [[macros valueForKeyPath:@"name.lowercaseString"] indexOfObject:[key lowercaseString]];
                BDSKASSERT(idx != NSNotFound);
                [self removeObjectFromMacrosAtIndex:idx];
            } else {
                [self setMacros:[NSArray array]];
                return;
            }
        } else if ([type isEqualToString:@"Change key"]) {
            NSString *newKey = [info objectForKey:@"newKey"];
            NSString *oldKey = [info objectForKey:@"oldKey"];
            NSUInteger idx = [[macros valueForKeyPath:@"name.lowercaseString"] indexOfObject:[oldKey lowercaseString]];
            BDSKMacro *macro = [[BDSKMacro alloc] initWithName:newKey macroResolver:macroResolver];
            BDSKASSERT(idx != NSNotFound);
            [self replaceObjectInMacrosAtIndex:idx withObject:macro];
            [macro release];
        }
        [arrayController rearrangeObjects];
        [tableView reloadData];
    }
}

#pragma mark Actions

- (IBAction)addRemoveMacro:(id)sender{
    if (sender && [sender selectedSegment] == 0) { // add
        
        BDSKASSERT(isEditable);
        NSDictionary *macroDefinitions = [macroResolver macroDefinitions];
        // find a unique new macro key
        NSInteger i = 0;
        NSString *newKey = [NSString stringWithString:@"macro"];
        while([macroDefinitions objectForKey:newKey] != nil)
            newKey = [NSString stringWithFormat:@"macro%ld", (long)++i];
        
        [macroResolver addMacroDefinition:@"definition" forMacro:newKey];
        [[[self window] undoManager] setActionName:NSLocalizedString(@"Add Macro", @"Undo action name")];
        
        NSUInteger row = [[[arrayController arrangedObjects] valueForKey:@"name"] indexOfObject:newKey];
        [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [tableView editColumn:0 row:row withEvent:nil select:YES];
        
    } else { // remove
        
        BDSKASSERT(isEditable);
        NSArray *macrosToRemove = [[[arrayController arrangedObjects] objectsAtIndexes:[tableView selectedRowIndexes]] valueForKey:@"name"];
        for (NSString *key in macrosToRemove) {
            [macroResolver removeMacro:key];
            [[[self window] undoManager] setActionName:NSLocalizedString(@"Delete Macro", @"Undo action name")];
        }
        
    }
}

- (void)showWindow:(id)sender{
    [tableView reloadData];
    [closeButton setKeyEquivalent:@""];
    
    [super showWindow:sender];
}

- (void)beginSheetModalForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)didEndSelector contextInfo:(void *)contextInfo {
    [self window]; // make sure we loaded the nib
    [tableView reloadData];
    [closeButton setKeyEquivalent:@"\E"];
    
    [super beginSheetModalForWindow:window modalDelegate:delegate didEndSelector:didEndSelector contextInfo:contextInfo];
}

- (IBAction)closeAction:(id)sender{
	if ([[self window] isSheet]) {
		[self windowWillClose:nil];
        [self dismiss:sender];
	} else {
		[[self window] performClose:sender];
	}
}

- (IBAction)search:(id)sender {
    NSString *string = [sender stringValue];
    NSPredicate *predicate = nil;
    if ([NSString isEmptyString:string] == NO)
        predicate = [NSPredicate predicateWithFormat:@"(name CONTAINS[cd] %@) OR (value CONTAINS[cd] %@)", string, string];
    
    isEditable = showAll == NO && predicate == nil && (macroResolver == [BDSKMacroResolver defaultMacroResolver] || [[macroResolver owner] isDocument]);
    
    [self updateButtons];
    
    [arrayController setFilterPredicate:predicate];
    [tableView reloadData];
}

- (IBAction)changeShowAll:(id)sender{
    showAll = [sender state] == NSOnState;
    isEditable = showAll == NO && [arrayController filterPredicate] == nil && (macroResolver == [BDSKMacroResolver defaultMacroResolver] || [[macroResolver owner] isDocument]);
    
    [self updateButtons];
    [self reloadMacros];
}

#pragma mark Macro editing

- (IBAction)editSelectedFieldAsRawBibTeX:(id)sender{
	NSInteger row = [tableView selectedRow];
	if (row == -1 || isEditable == NO) 
		return;
    [self editSelectedCellAsMacro];
	if([tableView editedRow] != row)
		[tableView editColumn:1 row:row withEvent:nil select:YES];
}

- (BOOL)editSelectedCellAsMacro{
    NSInteger row = [tableView selectedRow];
	// this should never happen
    if ([complexStringEditor isEditing] || row == -1) 
		return NO;
	if(complexStringEditor == nil) {
        complexStringEditor = [[BDSKComplexStringEditor alloc] initWithMacroResolver:macroResolver];
        [complexStringEditor setEditable:isEditable];
    }
    BDSKMacro *macro = [[arrayController arrangedObjects] objectAtIndex:row];
	NSString *value = [macro value];
	NSText *fieldEditor = [tableView currentEditor];
	[tableCellFormatter setEditAsComplexString:YES];
	if (fieldEditor) {
		[fieldEditor setString:[tableCellFormatter editingStringForObjectValue:value]];
		[fieldEditor selectAll:self];
	}
    [complexStringEditor attachToTableView:tableView atRow:row column:1 withValue:value];
    return YES;
}

#pragma mark BDSKMacroFormatter delegate

- (BOOL)formatter:(BDSKComplexStringFormatter *)formatter shouldEditAsComplexString:(NSString *)object {
    return [self editSelectedCellAsMacro];
}

#pragma mark NSControl text delegate

- (void)controlTextDidEndEditing:(NSNotification *)aNotification {
	if ([[aNotification object] isEqual:tableView])
		[tableCellFormatter setEditAsComplexString:NO];
}

#pragma mark NSTableView datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv{
    return [[arrayController arrangedObjects] count];
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    BDSKMacro *macro = [[arrayController arrangedObjects] objectAtIndex:row];
    
    if([[tableColumn identifier] isEqualToString:@"macro"]){
         return [macro name];
    }else{
         return [macro value];
    }
    
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    NSUndoManager *undoMan = [[self window] undoManager];
	if([undoMan isUndoing] || [undoMan isRedoing]) return;
    NSArray *arrangedMacros = [arrayController arrangedObjects];
    NSParameterAssert(row >= 0 && row < (NSInteger)[arrangedMacros count]);    
    NSDictionary *macroDefinitions = [macroResolver macroDefinitions];
    BDSKMacro *macro = [arrangedMacros objectAtIndex:row];
    NSString *key = [macro name];
    
    if([[tableColumn identifier] isEqualToString:@"macro"]){
        // do nothing if there was no change.
        if([key isEqualToString:object]) return;
                
		if([object isEqualToString:@""]){
			[tableView reloadData];
            [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [tableView editColumn:0 row:row withEvent:nil select:YES];
    		
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Empty Macro", @"Message in alert dialog when entering empty macro key") 
                                             defaultButton:NSLocalizedString(@"OK", @"Button title")
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"The macro can not be empty.", @"Informative text in alert dialog when entering empty macro key")];
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
			return;
		}
                
		if([macroDefinitions objectForKey:object]){
			[tableView reloadData];
            [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [tableView editColumn:0 row:row withEvent:nil select:YES];
    		
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Duplicate Macro", @"Message in alert dialog when entering duplicate macro key") 
                                             defaultButton:NSLocalizedString(@"OK", @"Button title")
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"The macro key must be unique.", @"Informative text in alert dialog when entering duplicate macro key")];
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
			return;
		}
		
		if([macroResolver macroDefinition:[macroDefinitions objectForKey:key] dependsOnMacro:object]){
			[tableView reloadData];
            [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [tableView editColumn:0 row:row withEvent:nil select:YES];
    		
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Circular Macro", @"Message in alert dialog when entering macro with circular definition") 
                                             defaultButton:NSLocalizedString(@"OK", @"Button title")
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"The macro you try to define would lead to a circular definition.", @"Informative text in alert dialog")];
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
			return;
		}
		
        [macroResolver changeMacroKey:key to:object];

        // Rearranging objects will likely move the row we just edited (bug #1859542), so find this macro and edit its value instead of some random macro's value.  Using [[arrayController arrangedObjects] indexOfObject:macro] won't work because the notification handler just replaced it with another object (so that's probably a garbage pointer now, as well).
        NSUInteger newRow = [[[arrayController arrangedObjects] valueForKeyPath:@"name.lowercaseString"] indexOfObject:[object lowercaseString]];
        if (NSNotFound != newRow) {
            [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:YES];
            [tableView editColumn:1 row:newRow withEvent:nil select:YES];
        }
        
		[undoMan setActionName:NSLocalizedString(@"Change Macro Key", @"Undo action name")];

    }else{
        // do nothing if there was no change.
        if([[macroDefinitions objectForKey:key] isEqualAsComplexString:object]) return;
		
		if([macroResolver macroDefinition:object dependsOnMacro:key]){
			[tableView reloadData];
            [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [tableView editColumn:0 row:row withEvent:nil select:YES];
    		
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Circular Macro", @"Message in alert dialog when entering macro with circular definition") 
                                             defaultButton:NSLocalizedString(@"OK", @"Button title")
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"The macro you try to define would lead to a circular definition.", @"Informative text in alert dialog")];
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
			return;
		}
        
		[macroResolver setMacroDefinition:object forMacro:key];
		
		[undoMan setActionName:NSLocalizedString(@"Change Macro Definition", @"Undo action name")];
    }
}

#pragma mark || dragging operations

// this is also called from the copy: action defined in BDSKTableView
- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard{
    NSMutableString *pboardStr = [NSMutableString string];
    NSArray *arrangedMacros = [arrayController arrangedObjects];
    NSUInteger row = [rowIndexes firstIndex];
    [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];

    while (row != NSNotFound) {
        BDSKMacro *macro = [arrangedMacros objectAtIndex:row];
        [pboardStr appendStrings:@"@string{", [macro name], @" = ", [macro bibTeXString], @"}\n", nil];
        row = [rowIndexes indexGreaterThanIndex:row];
    }
    return [pboard setString:pboardStr forType:NSStringPboardType];
    
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op{
    if (isEditable == NO) {
        return NSDragOperationNone;    
    } else if ([info draggingSource]) {
        if([[info draggingSource] isEqual:tableView])
        {
            // can't copy onto same table
            return NSDragOperationNone;
        }
        [tv setDropRow:-1 dropOperation:NSTableViewDropOn];
        return NSDragOperationCopy;    
    }else{
        //it's not from me
        [tv setDropRow:-1 dropOperation:NSTableViewDropOn];
        return NSDragOperationEvery; // if it's not from me, copying is OK
    }
}

- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo> )info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op{
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil]];
    
    if([type isEqualToString:NSStringPboardType]) {
        NSString *pboardStr = [pboard stringForType:NSStringPboardType];
        return [self addMacrosFromBibTeXString:pboardStr];
    } else if ([type isEqualToString:NSFilenamesPboardType]) {
        NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL success = NO;
        
        for (NSString *file in fileNames) {
            NSString *extension = [file pathExtension];
            file = [file stringByStandardizingPath];
            if ([fm fileExistsAtPath:file] == NO ||
                ([extension caseInsensitiveCompare:@"bib"] != NSOrderedSame && [extension caseInsensitiveCompare:@"bst"] != NSOrderedSame))
                continue;
            NSString *fileStr = [NSString stringWithContentsOfFile:file encoding:0 guessEncoding:YES];
            if (fileStr != nil)
                success = success || [self addMacrosFromBibTeXString:fileStr];
        }
        return success;
    } else
        return NO;
}

#pragma mark OA extensions

// called from tableView insertNewline: action defined in NSTableView_OAExtensions
- (void)tableView:(NSTableView *)tv insertNewline:(id)sender {
    if(isEditable && [tableView numberOfSelectedRows] == 1)
        [tableView editColumn:0 row:[tableView selectedRow] withEvent:nil select:YES];
}

// called from tableView paste: action defined in NSTableView_OAExtensions
- (void)tableView:(NSTableView *)tv pasteFromPasteboard:(NSPasteboard *)pboard{
    if(isEditable && [pboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]]) {
        [self addMacrosFromBibTeXString:[pboard stringForType:NSStringPboardType]];
    }
}

- (BOOL)tableViewCanPasteFromPasteboard:(NSTableView *)tv {
    return isEditable;
}

// called from tableView delete: action defined in NSTableView_OAExtensions
- (void)tableView:(NSTableView *)tv deleteRows:(NSArray *)rows{
	if (isEditable)
        [self addRemoveMacro:nil];
}

- (BOOL)tableView:(NSTableView *)tv canDeleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
    return isEditable;
}

#pragma mark NSTableView delegate methods

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification{
    [self updateButtons];
}

- (BOOL)tableView:(NSTableView *)tv shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    return isEditable;
}

- (void)tableView:(NSTableView *)tv didClickTableColumn:(NSTableColumn *)tableColumn{
    NSSortDescriptor *sortDescriptor = [[arrayController sortDescriptors] lastObject];
    
    NSString *oldKey = [sortDescriptor key];
    NSString *newKey = [[tableColumn identifier] isEqualToString:@"macro"] ? @"name" : @"value";
    
    if ([newKey isEqualToString:oldKey])
        sortDescriptor = [sortDescriptor reversedSortDescriptor];
    else
       sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:newKey ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
    [arrayController setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    
    if ([newKey isEqualToString:oldKey] == NO)
        [tableView setIndicatorImage:nil inTableColumn:[tableView highlightedTableColumn]];
    [tableView setHighlightedTableColumn:tableColumn]; 
    [tableView setIndicatorImage:[sortDescriptor ascending] ? [NSImage imageNamed:@"NSAscendingSortIndicator"] : [NSImage imageNamed:@"NSDescendingSortIndicator"]
                   inTableColumn:tableColumn];
    
    [arrayController rearrangeObjects];
    [tableView reloadData];
}

- (NSArray *)tableView:(NSTableView *)tv typeSelectHelperSelectionItems:(BDSKTypeSelectHelper *)aTypeSelectHelper {
    return [arrayController arrangedObjects];
}

#pragma mark Support

- (BOOL)addMacrosFromBibTeXString:(NSString *)aString{
    // if this is called, we shouldn't belong to a group
	BibDocument *document = (BibDocument *)[macroResolver owner];
	
    BOOL hadCircular = NO;
    NSMutableDictionary *defs = [NSMutableDictionary dictionary];
    
    if([aString rangeOfString:@"@string" options:NSCaseInsensitiveSearch].location != NSNotFound)
        [defs addEntriesFromDictionary:[BDSKBibTeXParser macrosFromBibTeXString:aString document:document]];
            
    if([aString rangeOfString:@"MACRO" options:NSCaseInsensitiveSearch].location != NSNotFound)
        [defs addEntriesFromDictionary:[BDSKBibTeXParser macrosFromBibTeXStyle:aString document:document]]; // in case these are style defs

    if ([defs count] == 0)
        return NO;
    
    NSString *macroString;
    
    for (NSString *macroKey in defs) {
        macroString = [defs objectForKey:macroKey];
		if([macroResolver macroDefinition:macroString dependsOnMacro:macroKey] == NO)
            [(BDSKMacroResolver *)macroResolver setMacroDefinition:macroString forMacro:macroKey];
		else
            hadCircular = YES;
        [[[self window] undoManager] setActionName:NSLocalizedString(@"Change Macro Definition", @"Undo action name")];
    }
    
    if(hadCircular){
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Circular Macros", @"Message in alert dialog when entering macro with circular definition") 
                                         defaultButton:NSLocalizedString(@"OK", @"Button title")
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"Some macros you tried to add would lead to circular definitions and were ignored.", @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
    }
    return YES;
}

- (void)replaceEveryOccurrenceOfMacroKey:(NSString *)oldKey withKey:(NSString *)newKey{
	NSString *findStr = [NSString stringWithBibTeXString:oldKey macroResolver:macroResolver error:NULL];
	NSString *replStr = [NSString stringWithBibTeXString:newKey macroResolver:macroResolver error:NULL];
    NSArray *docs = [macroResolver isEqual:[BDSKMacroResolver defaultMacroResolver]] ? [NSApp orderedDocuments] : [NSArray arrayWithObjects:[macroResolver owner], nil]; 
    NSUInteger numRepl;
    NSString *oldValue;
    NSString *newValue;
    
    for (BibDocument *doc in docs) {
        for (BibItem *pub in [doc publications]) {
            for (NSString *field in [pub allFieldNames]) {
                oldValue = [pub valueOfField:field inherit:NO];
                if ([oldValue isComplex]) {
                    newValue = [oldValue stringByReplacingOccurrencesOfString:findStr withString:replStr options:NSCaseInsensitiveSearch replacements:&numRepl];
                    if (numRepl > 0)
                        [pub setField:field toValue:newValue];
                }
            }
        }
    }
}

@end

@implementation MacroKeyFormatter

- (NSString *)stringForObjectValue:(id)obj{
    return obj;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary *)attrs{
    // NSLog(@"attributed string for obj");
    return [[[NSAttributedString alloc] initWithString:[self stringForObjectValue:obj]] autorelease];
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error{
    *obj = string;
    return YES;
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString **)error{
    static NSCharacterSet *invalidMacroCharSet = nil;
	
	if (!invalidMacroCharSet) {
		NSMutableCharacterSet *tmpSet = [[[NSMutableCharacterSet alloc] init] autorelease];
		[tmpSet addCharactersInRange:NSMakeRange(48,10)]; // 0-9
		[tmpSet addCharactersInRange:NSMakeRange(65,26)]; // A-Z
		[tmpSet addCharactersInRange:NSMakeRange(97,26)]; // a-z
		[tmpSet addCharactersInString:@"!$&*+-./:;<>?[]^_`|"]; // see the btparse documentation
		invalidMacroCharSet = [[[[tmpSet copy] autorelease] invertedSet] retain];
	}
    
	NSString *partialString = *partialStringPtr;
    
    if( [partialString rangeOfCharacterFromSet:invalidMacroCharSet].length ||
	    ([partialString length] && 
		 [[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[partialString characterAtIndex:0]]) ){
        return NO;
    }
	*partialStringPtr = [partialString lowercaseString];
    return [*partialStringPtr isEqualToString:partialString];
}


@end

@implementation BDSKMacroTableView

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
    return NSDragOperationCopy;
}

- (void)awakeFromNib{
    BDSKTypeSelectHelper *aTypeSelectHelper = [[BDSKTypeSelectHelper alloc] init];
    [aTypeSelectHelper setCyclesSimilarResults:YES];
    [aTypeSelectHelper setMatchesPrefix:NO];
    [self setTypeSelectHelper:aTypeSelectHelper];
    [aTypeSelectHelper release];
}

- (void)dealloc{
    [typeSelectHelper release];
    [super dealloc];
}

- (void)keyDown:(NSEvent *)event{
    if ([typeSelectHelper processKeyDownEvent:event] == NO)
        [super keyDown:event];
}

// this gets called whenever an object is added/removed/changed, so it's
// a convenient place to rebuild the typeahead find cache
- (void)reloadData{
    [super reloadData];
    [typeSelectHelper rebuildTypeSelectSearchCache];
}

@end

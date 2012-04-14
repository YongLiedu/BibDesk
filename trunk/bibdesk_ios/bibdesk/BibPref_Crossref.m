//
//  BibPref_Crossref.m
//  
//
//  Created by Christiaan Hofman on 28/5/05.
/*
 This software is Copyright (c) 2005-2012
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

#import "BibPref_Crossref.h"
#import "BDSKTypeNameFormatter.h"
#import "BDSKStringConstants.h"

static char BDSKBibPrefCrossrefDefaultsObservationContext;


@interface BibPref_Crossref (Private)
- (void)updateDuplicateBooktitleUI;
- (void)updateDuplicateTypes;
@end


@implementation BibPref_Crossref

- (void)awakeFromNib{
    typesArray = [[NSMutableArray alloc] initWithCapacity:4];
	[typesArray setArray:[sud arrayForKey:BDSKTypesForDuplicateBooktitleKey]];
    BDSKTypeNameFormatter *typeNameFormatter = [[BDSKTypeNameFormatter alloc] init];
    [[[[tableView tableColumns] objectAtIndex:0] dataCell] setFormatter:typeNameFormatter];
    [typeNameFormatter release];
    
    [warnOnEditInheritedCheckButton setState:[sud boolForKey:BDSKWarnOnEditInheritedKey] ? NSOnState : NSOffState];
    [autoSortCheckButton setState:[sud boolForKey:BDSKAutoSortForCrossrefsKey] ? NSOnState : NSOffState];
    
    [duplicateBooktitleCheckButton setState:[sud boolForKey:BDSKDuplicateBooktitleKey] ? NSOnState : NSOffState];
    [forceDuplicateBooktitleCheckButton setState:[sud boolForKey:BDSKForceDuplicateBooktitleKey] ? NSOnState : NSOffState];
    
    [self updateDuplicateBooktitleUI];
    [self updateDuplicateTypes];
    
    [sudc addObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnEditInheritedKey] options:0 context:&BDSKBibPrefCrossrefDefaultsObservationContext];
}

- (void)defaultsDidRevert {
    // reset UI, but only if we loaded the nib
    if ([self isViewLoaded]) {
        [typesArray setArray:[sud arrayForKey:BDSKTypesForDuplicateBooktitleKey]];
        
        //[warnOnEditInheritedCheckButton setState:[sud boolForKey:BDSKWarnOnEditInheritedKey] ? NSOnState : NSOffState]; this should be done by KVO
        [autoSortCheckButton setState:[sud boolForKey:BDSKAutoSortForCrossrefsKey] ? NSOnState : NSOffState];
        
        [duplicateBooktitleCheckButton setState:[sud boolForKey:BDSKDuplicateBooktitleKey] ? NSOnState : NSOffState];
        [forceDuplicateBooktitleCheckButton setState:[sud boolForKey:BDSKForceDuplicateBooktitleKey] ? NSOnState : NSOffState];
        
        [self updateDuplicateBooktitleUI];
        [self updateDuplicateTypes];
    }
}

- (void)dealloc{
    @try { [sudc removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnEditInheritedKey]]; }
    @catch (id e) {}
    BDSKDESTROY(typesArray);
    [super dealloc];
}

- (void)updateDuplicateTypes {
    [sud setObject:typesArray forKey:BDSKTypesForDuplicateBooktitleKey];
	[tableView reloadData];
}

- (void)updateDuplicateBooktitleUI{
	BOOL duplicate = [sud boolForKey:BDSKDuplicateBooktitleKey];
    [forceDuplicateBooktitleCheckButton setEnabled:duplicate];
	[tableView setEnabled:duplicate];
	[addRemoveTypeButton setEnabled:duplicate forSegment:0];
	[addRemoveTypeButton setEnabled:duplicate && [tableView numberOfSelectedRows] > 0 forSegment:1];
}

- (IBAction)changeAutoSort:(id)sender{
    [sud setBool:([sender state] == NSOnState) forKey:BDSKAutoSortForCrossrefsKey];
}

- (IBAction)changeWarnOnEditInherited:(id)sender{
    [sud setBool:([sender state] == NSOnState) forKey:BDSKWarnOnEditInheritedKey];
}

- (IBAction)changeDuplicateBooktitle:(id)sender{
    BOOL duplicate = [sender state] == NSOnState;
    [sud setBool:duplicate forKey:BDSKDuplicateBooktitleKey];
    [self updateDuplicateBooktitleUI];
}

- (IBAction)changeForceDuplicateBooktitle:(id)sender{
    [sud setBool:([sender state] == NSOnState) forKey:BDSKForceDuplicateBooktitleKey];
}

- (IBAction)addRemoveType:(id)sender{
    if ([sender selectedSegment] == 0) { // add
        
        NSString *newType = @"type"; // do not localize
        [typesArray addObject:newType];
        NSInteger row = [typesArray count] - 1;
        [tableView reloadData];
        [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [tableView editColumn:0 row:row withEvent:nil select:YES];
        
    } else { // remove
        
        NSInteger row = [tableView selectedRow];
        if(row != -1){
            if ([tableView editedRow] != -1)
                [[[self view] window] makeFirstResponder:tableView];
            [typesArray removeObjectAtIndex:row];
            [self updateDuplicateTypes];
        }
        
    }
}

#pragma mark TableView datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv{
    return [typesArray count];
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    return [typesArray objectAtIndex:row];
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    if([object isEqualToString:@""])
        [typesArray removeObjectAtIndex:row];
    else
        [typesArray replaceObjectAtIndex:row withObject:[(NSString *)object entryType]];
    [self updateDuplicateTypes];
}

- (BOOL)tableView:(NSTableView *)tv shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
	return [tv isEnabled];
}

- (BOOL)tableView:(NSTableView *)tv shouldSelectRow:(NSInteger)row{
	return [tv isEnabled];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNote{
    [self updateDuplicateBooktitleUI];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &BDSKBibPrefCrossrefDefaultsObservationContext) {
        NSString *key = [keyPath substringFromIndex:7];
        if ([key isEqualToString:BDSKWarnOnEditInheritedKey]) {
            [warnOnEditInheritedCheckButton setState:[sud boolForKey:BDSKWarnOnEditInheritedKey] ? NSOnState : NSOffState];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

@implementation BDSKDisablingTableView

- (void)setEnabled:(BOOL)flag{
	[super setEnabled:flag];
	if (flag == NO) [self deselectAll:nil];
}

- (BOOL)acceptsFirstResponder{
	return [self isEnabled] && [super acceptsFirstResponder];
}

@end

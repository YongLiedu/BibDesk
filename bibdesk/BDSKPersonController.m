//
//  BDSKPersonController.m
//  BibDesk
//
//  Created by Michael McCracken on Thu Mar 18 2004.
/*
 This software is Copyright (c) 2004-2009
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

#import "BDSKPersonController.h"
#import "BDSKTypeManager.h"
#import "BibDocument.h"
#import "BibDocument_Actions.h"
#import "BibAuthor.h"
#import "BibItem.h"
#import "BDSKBibTeXParser.h"
#import "BDSKCollapsibleView.h"
#import "BDSKDragImageView.h"
#import "BDSKPublicationsArray.h"
#import "NSWindowController_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKSplitView.h"
#import "BDSKTableView.h"
#import <AddressBook/AddressBook.h>

@implementation BDSKPersonController

#pragma mark initialization

+ (void)initialize{
    [self setKeys:[NSArray arrayWithObject:@"document"] triggerChangeNotificationsForDependentKey:@"publications"];
    BDSKINITIALIZE;
}

- (NSString *)windowNibName{return @"BDSKPersonWindow";}

- (id)initWithPerson:(BibAuthor *)aPerson{

    self = [super init];
	if(self){
        owner = [[aPerson publication] owner];
        publicationItems = nil;
        names = nil;
        fields = [[[BDSKTypeManager sharedManager] personFieldsSet] copy];
        isEditable = [owner isDocument];
        [self setPerson:aPerson];
	}
	return self;

}

- (void)dealloc{
    [person release];
    [publicationItems release];
    [names release];
    [fields release];
    [super dealloc];
}

- (void)awakeFromNib{
	if ([NSWindowController instancesRespondToSelector:@selector(awakeFromNib)]){
        [super awakeFromNib];
	}
    
    [publicationTableView setFontNamePreferenceKey:BDSKPersonTableViewFontNameKey];
    [publicationTableView setFontSizePreferenceKey:BDSKPersonTableViewFontSizeKey];
	
	[collapsibleView setMinSize:NSMakeSize(0.0, 38.0)];
	[imageView setDelegate:self];
	[splitView setPositionAutosaveName:@"BibPersonView"];

    if (isEditable && nil != owner) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleBibItemAddDel:)
                                                     name:BDSKDocAddItemNotification
                                                   object:owner];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleBibItemAddDel:)
                                                     name:BDSKDocDelItemNotification
                                                   object:owner];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleBibItemAddDel:)
                                                     name:BDSKDocSetPublicationsNotification
                                                   object:owner];
    } else {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleGroupWillBeRemoved:)
                                                     name:BDSKDidAddRemoveGroupNotification
                                                   object:nil];
    }   
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleBibItemChanged:)
                                                 name:BDSKBibItemChangedNotification
                                               object:nil];
    
	[self updateUI];
    [publicationTableView setDoubleAction:@selector(openSelectedPub:)];
    
    
    if (isEditable) {
        [nameTableView setDoubleAction:@selector(edit:)];
        [imageView registerForDraggedTypes:[NSArray arrayWithObject:NSVCardPboardType]];
    }
    
    [editButton setEnabled:isEditable];
    
    NSSortDescriptor *sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"publication.title" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
    [publicationArrayController setSortDescriptors:[NSArray arrayWithObjects:sortDescriptor, nil]];
    sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"self" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
    [fieldArrayController setSortDescriptors:[NSArray arrayWithObjects:sortDescriptor, nil]];
    sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"length" ascending:NO selector:@selector(compare:)] autorelease];
    [nameArrayController setSortDescriptors:[NSArray arrayWithObjects:sortDescriptor, nil]];
    
    [self updatePublicationItems];
    [publicationTableView reloadData];
    [nameTableView selectAll:self];
    [fieldTableView selectAll:self];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName{
    return [person name];
}

- (void)synchronizeWindowTitleWithDocumentName {
    [super synchronizeWindowTitleWithDocumentName];
    // clearing the proxy icon when this does not belong to the document, somehow passing nil does not work
    if ([owner isDocument] == NO)
        [[self window] setRepresentedFilename:@""];
}

- (void)windowWillClose:(NSNotification *)note {
    [[self undoManager] removeAllActionsWithTarget:self];
    [publicationTableView setDelegate:nil];
    [publicationTableView setDataSource:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // make sure we won't try to access this, e.g. in a delayed setPublicationItems:
    owner = nil;
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(setPublicationItems:) object:nil];
}

- (void)updateFilter {
    NSSet *fieldSet = [NSSet setWithArray:[fieldArrayController selectedObjects]];
    NSSet *nameSet = [NSSet setWithArray:[nameArrayController selectedObjects]];
    
    NSExpression *lhs, *rhs;
    NSPredicate *fieldPredicate, *namePredicate, *predicate;
    
    lhs = [NSExpression expressionForKeyPath:@"fields"];
    rhs = [NSExpression expressionForConstantValue:fieldSet];
    fieldPredicate = [NSComparisonPredicate predicateWithLeftExpression:lhs rightExpression:rhs customSelector:@selector(intersectsSet:)];
    lhs = [NSExpression expressionForKeyPath:@"names"];
    rhs = [NSExpression expressionForConstantValue:nameSet];
    namePredicate = [NSComparisonPredicate predicateWithLeftExpression:lhs rightExpression:rhs customSelector:@selector(intersectsSet:)];
    predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:fieldPredicate, namePredicate, nil]];
    
    [publicationArrayController setFilterPredicate:predicate];
}

- (void)updatePublicationItems{
    if (publicationItems)
        [publicationItems release];
    publicationItems = [[NSMutableArray alloc] init];
    
    NSMutableSet *theNames = [[NSMutableSet alloc] init];
    NSMutableSet *peopleSet = [[NSMutableSet alloc] initForFuzzyAuthors];
    NSEnumerator *pubEnum = [[owner publications] objectEnumerator];
    BibItem *pub;
    
    while (pub = [pubEnum nextObject]) {
        NSEnumerator *fieldEnum = [fields objectEnumerator];
        NSString *field;
        NSDictionary *info = nil;
        NSMutableSet *fieldSet = nil;
        NSMutableSet *nameSet = nil;
        
        while (field = [fieldEnum nextObject]) {
            NSArray *people = [pub peopleArrayForField:field];
            
            [peopleSet addObjectsFromArray:people];
            
            if ([peopleSet containsObject:person]) {
                NSEnumerator *personEnum = [people objectEnumerator];
                BibAuthor *aPerson;
                NSString *name;
                
                while (aPerson = [personEnum nextObject]) {
                    if ([aPerson fuzzyEqual:person]) {
                        if (info == nil) {
                            fieldSet = [[NSMutableSet alloc] init];
                            nameSet = [[NSMutableSet alloc] init];
                            info = [[NSDictionary alloc] initWithObjectsAndKeys:pub, @"publication", nameSet, @"names", fieldSet, @"fields", nil];
                            [publicationItems addObject:info];
                            [info release];
                            [nameSet release];
                            [fieldSet release];
                        }
                        
                        name = [aPerson originalName];
                        [nameSet addObject:name];
                        [fieldSet addObject:field];
                        [theNames addObject:name];
                    }
                }
                
            }
            [peopleSet removeAllObjects];
        }
    }
    [peopleSet release];
    
    // @@ probably want to try to preserve selection
    [self setNames:theNames];
}

#pragma mark accessors

- (NSArray *)publicationItems{
    if (publicationItems == nil)
        [self updatePublicationItems];
    return publicationItems;
}

- (void)setPublicationItems:(NSArray *)items{
    if(publicationItems != items){
        [publicationItems release];
        publicationItems = [items mutableCopy];
    }
}

- (NSSet *)names {
    return names;
}

- (void)setNames:(NSSet *)newNames {
    if (names != newNames) {
        [names release];
        names = [newNames copy];
    }
}

- (NSSet *)fields {
    return fields;
}

- (void)setFields:(NSSet *)newFields {
    if (fields != newFields) {
        [fields release];
        fields = [newFields copy];
    }
}

- (BibAuthor *)person {
    return person;
}

- (void)setPerson:(BibAuthor *)newPerson {
    if(newPerson != person){        
        if (nil != person) {
            [[[self undoManager] prepareWithInvocationTarget:self] setPerson:person];
            [person release];
        }
        person = [newPerson copy];
        [self synchronizeWindowTitleWithDocumentName];
    }
}

// binding directly to person.personFromAddressBook.imageData in IB doesn't work for some reason
- (NSData *)imageData{
    return [[person personFromAddressBook] imageData] ?: [[[NSWorkspace sharedWorkspace] iconForFileType:@"vcf"] TIFFRepresentation];
}

#pragma mark actions

- (void)editSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSOKButton) {
        NSString *newName = [editField stringValue];
        if ([NSString isEmptyString:newName] == NO)
            [self changeNameToString:newName];
    }
}

- (IBAction)edit:(id)sender {
    NSString *selFields = [[fieldArrayController selectedObjects] valueForKeyPath:@"quotedStringIfNotEmpty.@componentsJoinedByCommaAndAnd"];
    NSString *selNames = [[nameArrayController selectedObjects] valueForKeyPath:@"quotedStringIfNotEmpty.@componentsJoinedByCommaAndAnd"];
	NSString *message = [NSString stringWithFormat:NSLocalizedString(@"This will change every occurrence of %@ in any %@ field of the displayed publications.", @"Informative text in alert dialog"), selNames, selFields];
    
    // @@ nameArrayController can be empty after undo; should edit be disabled in that case?
    if ([[nameArrayController selectedObjects] count]) {
        [editMessageField setStringValue:message];
        [editField setStringValue:[[nameArrayController selectedObjects] objectAtIndex:0]];
        [editField selectText:self];
        
        [NSApp beginSheet:editSheet
           modalForWindow:[self window]
            modalDelegate:self
           didEndSelector:@selector(editSheetDidEnd:returnCode:contextInfo:)
              contextInfo:NULL];
    }
}

- (IBAction)dismissEditSheet:(id)sender {
    [NSApp endSheet:editSheet returnCode:[sender tag]];
    [editSheet orderOut:self];
}

- (void)show{
    [self showWindow:self];
}

- (void)updateUI{
	[nameTextField setStringValue:[person name]];
	[publicationTableView reloadData];
}

- (void)handleBibItemChanged:(NSNotification *)note{
    NSString *key = [[note userInfo] valueForKey:@"key"];
    if (([key isPersonField] || key == nil) && owner) {
        [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(setPublicationItems:) object:nil];
        [self performSelector:@selector(setPublicationItems:) withObject:nil afterDelay:0.0];
    }
}

- (void)handleBibItemAddDel:(NSNotification *)note{
    // we may be adding or removing items, so we can't check publications for containment
    if (owner) {
        [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(setPublicationItems:) object:nil];
        [self performSelector:@selector(setPublicationItems:) withObject:nil afterDelay:0.0];
    }
}

- (void)handleGroupWillBeRemoved:(NSNotification *)note{
	NSArray *groups = [[note userInfo] objectForKey:@"groups"];
	
	if ([groups containsObject:owner])
		[self close];
}

- (void)openSelectedPub:(id)sender{
    NSInteger row = [publicationTableView selectedRow];
    if (row != -1)
        [(BibDocument *)[self document] editPub:[[[publicationArrayController arrangedObjects] objectAtIndex:row] valueForKey:@"publication"]];
}

- (void)changeNameToString:(NSString *)newNameString{
    // keep copies as they may change during iteration, depending on NSArrayControllers implementation which we do not know
    NSArray *pubs = [[[publicationArrayController arrangedObjects] copy] autorelease];
    NSSet *selFields = [NSSet setWithArray:[fieldArrayController selectedObjects]];
    NSSet *selNames = [NSSet setWithArray:[nameArrayController selectedObjects]];
    
    NSEnumerator *itemE = [pubs objectEnumerator];
    NSDictionary *item;
    NSEnumerator *fieldE;
    NSString *field;
    BibItem *pub;
    BibAuthor *aPerson;
    
    NSMutableArray *people;
    CFIndex idx;
    BOOL found;
    
    // this is only used as a placeholder for the name, so we don't care about its pub or field
    BibAuthor *newPerson = [BibAuthor authorWithName:newNameString andPub:nil];
    
    while (item = [itemE nextObject]) {
        
        pub = [item objectForKey:@"publication"];
        fieldE = [[item objectForKey:@"fields"] objectEnumerator];
        
        while (field = [fieldE nextObject]) {
            // we only replace in the selected fields
            if ([selFields containsObject:field]) {
                
                // get the array of BibAuthor objects from a person field
                people = [[pub peopleArrayForField:field inherit:NO] mutableCopy];
                idx = [people count];
                found = NO;
                
                while (idx--) {
                    aPerson = [people objectAtIndex:idx];
                    // we only replace the selected names
                    if ([selNames containsObject:[aPerson originalName]]) {
                        [people replaceObjectAtIndex:idx withObject:newPerson];
                        found = YES;
                    }
                }
                
                if (found)
                    [pub setField:field toValue:[[people valueForKey:@"originalName"] componentsJoinedByString:@" and "]];
                
                [people release];
                
            }
        }
    }
    
    [self setPerson:newPerson];
    
	[[self  undoManager] setActionName:NSLocalizedString(@"Change Author Name", @"Undo action name")];
    
    // needed to update our tableview with the new publications list after setting a new person
    [self handleBibItemChanged:nil];

	[self updateUI];
}

#pragma mark TableView delegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if ([notification object] == nameTableView || [notification object] == fieldTableView) {
        [self updateFilter];
    }
}

#pragma mark Dragging delegate methods

- (NSDragOperation)dragImageView:(BDSKDragImageView *)view validateDrop:(id <NSDraggingInfo>)sender {
    if(isEditable == NO)
        return NO;
    
    if ([[sender draggingSource] isEqual:view])
		return NSDragOperationNone;
	
	NSPasteboard *pboard = [sender draggingPasteboard];
    
    if([[pboard types] containsObject:NSVCardPboardType])
        return NSDragOperationCopy;

    return NSDragOperationNone;
}

- (BOOL)dragImageView:(BDSKDragImageView *)view acceptDrop:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    if([[pboard types] containsObject:NSVCardPboardType] == NO)
        return NO;
	
	BibAuthor *newAuthor = [BibAuthor authorWithVCardRepresentation:[pboard dataForType:NSVCardPboardType] andPub:nil];
	
	if([newAuthor isEqual:[BibAuthor emptyAuthor]])
		return NO;
    
    NSString *selFields = [[fieldArrayController selectedObjects] valueForKeyPath:@"quotedStringIfNotEmpty.@componentsJoinedByCommaAndAnd"];
    NSString *selNames = [[nameArrayController selectedObjects] valueForKeyPath:@"quotedStringIfNotEmpty.@componentsJoinedByCommaAndAnd"];
	NSString *message = [NSString stringWithFormat:NSLocalizedString(@"This will change every occurrence of %@ in any %@ field of the displayed publications.", @"Informative text in alert dialog"), selNames, selFields];
    
    [editMessageField setStringValue:message];
    [editField setStringValue:[newAuthor name]];
    [editField selectText:self];
    
    [NSApp beginSheet:editSheet
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(editSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];

    return YES;
}

- (BOOL)dragImageView:(BDSKDragImageView *)view writeDataToPasteboard:(NSPasteboard *)pboard {
	[pboard declareTypes:[NSArray arrayWithObjects:NSVCardPboardType, NSFilesPromisePboardType, nil] owner:nil];

	// if we don't have a match in the address book, this will create a new person record
	NSData *data = [[ABPerson personWithAuthor:person] vCardRepresentation];
	BDSKPOSTCONDITION(data);

	if(data == nil)
		return NO;
		
	[pboard setData:data forType:NSVCardPboardType];
	[pboard setPropertyList:[NSArray arrayWithObject:[[person name] stringByAppendingPathExtension:@"vcf"]] forType:NSFilesPromisePboardType];
	return YES;
}

- (NSArray *)dragImageView:(BDSKDragImageView *)view namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination {
    NSData *data = [[ABPerson personWithAuthor:person] vCardRepresentation];
    NSString *fileName = [[person name] stringByAppendingPathExtension:@"vcf"];
    [data writeToFile:[[dropDestination path] stringByAppendingPathComponent:fileName] atomically:YES];
    
    return [NSArray arrayWithObject:fileName];
}
 
- (NSImage *)dragImageForDragImageView:(BDSKDragImageView *)view {
	return [[[NSWorkspace sharedWorkspace] iconForFileType:@"vcf"] dragImageWithCount:1];
}

#pragma mark Splitview delegate methods

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize {
    if ([sender isEqual:splitView]) {
        
        NSView *views[2];
        NSRect frames[2];
        CGFloat contentHeight = NSHeight([sender frame]) - [sender dividerThickness];
        CGFloat factor = contentHeight / (oldSize.height - [sender dividerThickness]);
        NSInteger i, gap;
        
        [[sender subviews] getObjects:views];
        for (i = 0; i < 2; i++) {
            frames[i] = [views[i] frame];
            frames[i].size.height = BDSKFloor(factor * NSHeight(frames[i]));
        }
        
        // randomly divide the remaining gap over the two views; NSSplitView dumps it all over the last view, which grows that one more than the others
        gap = contentHeight - NSHeight(frames[0]) - NSHeight(frames[1]);
        while (gap > 0) {
            i = floor(2.0f * rand() / RAND_MAX);
            if (NSHeight(frames[i]) > 0.0) {
                frames[i].size.height += 1.0;
                gap--;
            }
        }
        frames[0].origin.y = NSMaxY(frames[1]) + [sender dividerThickness];
        
        for (i = 0; i < 2; i++)
            [views[i] setFrame:frames[i]];
        
    } else if ([sender isEqual:fieldNameSplitView]) {
        
        NSView *leftView = [[sender subviews] objectAtIndex:0];
        NSView *rightView = [[sender subviews] objectAtIndex:1];
        NSRect leftFrame = [leftView frame];
        NSRect rightFrame = [rightView frame];
        CGFloat contentWidth = NSWidth([sender frame]) - [sender dividerThickness];
        
        if (NSWidth(rightFrame) <= 1.0)
            rightFrame.size.width = 0.0;
        else if (NSWidth(leftFrame) <= 1.0)
            rightFrame.size.width = contentWidth;
        else if (contentWidth < NSWidth(rightFrame))
            rightFrame.size.width = BDSKFloor(NSWidth(rightFrame) * contentWidth / (oldSize.width - [sender dividerThickness]));
        
        leftFrame.size.width = contentWidth - NSWidth(rightFrame);
        rightFrame.origin.x = NSMaxX(leftFrame) + [sender dividerThickness];
        rightFrame.size.height = leftFrame.size.height = NSHeight([sender frame]);
        [leftView setFrame:leftFrame];
        [rightView setFrame:rightFrame];
    }
    
    [sender adjustSubviews];
}

- (void)splitView:(BDSKSplitView *)sender doubleClickedDividerAt:(NSInteger)offset {
    if ([sender isEqual:splitView]) {
        
        NSView *pickerView = [[sender subviews] objectAtIndex:0];
        NSView *pubsView = [[sender subviews] objectAtIndex:1];
        NSRect pubsFrame = [pubsView frame];
        NSRect pickerFrame = [pickerView frame];
        
        if (NSHeight(pickerFrame) > 0.0) { // can't use isSubviewCollapsed, because implementing splitView:canCollapseSubview: prevents uncollapsing
            lastPickerHeight = NSHeight(pickerFrame); // cache this
            pubsFrame.size.height += lastPickerHeight;
            pickerFrame.size.height = 0.0;
        } else {
            if(lastPickerHeight <= 0.0)
                lastPickerHeight = 150.0; // a reasonable value to start
            pickerFrame.size.height = lastPickerHeight;
            pubsFrame.size.height = NSHeight([sender frame]) - lastPickerHeight - [splitView dividerThickness];
        }
        [pubsView setFrame:pubsFrame];
        [pickerView setFrame:pickerFrame];
        [sender adjustSubviews];
        // fix for NSSplitView bug, which doesn't send this in adjustSubviews
        [[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewDidResizeSubviewsNotification object:sender];
        [[sender window] invalidateCursorRectsForView:sender];
    }
}

#pragma mark Undo Manager

- (NSUndoManager *)undoManager {
	return [owner undoManager];
}
    
// we want to have the same undoManager as our document, so we use this 
// NSWindow delegate method to return the doc's undomanager ...
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender{
	return [self undoManager];
}

@end

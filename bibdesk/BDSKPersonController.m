//
//  BDSKPersonController.m
//  BibDesk
//
//  Created by Michael McCracken on Thu Mar 18 2004.
/*
 This software is Copyright (c) 2004-2008
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
#import "BDSKOwnerProtocol.h"
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
#import <AddressBook/AddressBook.h>

@implementation BDSKPersonController

#pragma mark initialization

+ (void)initialize{
    [self setKeys:[NSArray arrayWithObject:@"document"] triggerChangeNotificationsForDependentKey:@"publications"];
}

- (NSString *)windowNibName{return @"BDSKPersonWindow";}

- (id)initWithPerson:(BibAuthor *)aPerson{

    self = [super init];
	if(self){
        [self setPerson:aPerson];
        publicationItems = nil;
        names = [[NSSet alloc] init];
        fields = [[[BDSKTypeManager sharedManager] personFieldsSet] copy];
        
        isEditable = [[[person publication] owner] isDocument];
        
        [person setPersonController:self];
        
	}
	return self;

}

- (void)dealloc{
    [publicationTableView setDelegate:nil];
    [publicationTableView setDataSource:nil];
    [person setPersonController:nil];
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
	
	[collapsibleView setMinSize:NSMakeSize(0.0, 38.0)];
	[imageView setDelegate:self];
	[splitView setPositionAutosaveName:@"OASplitView Position BibPersonView"];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleBibItemChanged:)
                                                 name:BDSKBibItemChangedNotification
                                               object:nil];
    if (isEditable) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleBibItemAddDel:)
                                                     name:BDSKDocAddItemNotification
                                                   object:[[person publication] owner]];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleBibItemAddDel:)
                                                     name:BDSKDocDelItemNotification
                                                   object:[[person publication] owner]];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleBibItemAddDel:)
                                                     name:BDSKDocSetPublicationsNotification
                                                   object:[[person publication] owner]];
    } else {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleGroupWillBeRemoved:)
                                                     name:BDSKDidAddRemoveGroupNotification
                                                   object:nil];
    }
	[self updateUI];
    [publicationTableView setDoubleAction:@selector(openSelectedPub:)];
    
    if (isEditable)
        [imageView registerForDraggedTypes:[NSArray arrayWithObject:NSVCardPboardType]];
    
    [nameTextField setEditable:isEditable];
    
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

- (NSString *)representedFilenameForWindow:(NSWindow *)aWindow {
    return [[[person publication] owner] isDocument] ? nil : @"";
}

- (void)updateFilter {
    NSSet *fieldSet = [NSSet setWithArray:[fieldArrayController selectedObjects]];
    NSSet *nameSet = [NSSet setWithArray:[nameArrayController selectedObjects]];
    
    NSExpression *lhs, *rhs;
    NSPredicate *fieldPredicate, *namePredicate, *predicate;
    
    lhs = [NSExpression expressionForKeyPath:@"fields"];
    rhs = [NSExpression expressionForConstantValue:fieldSet ? fieldSet : [NSSet set]];
    fieldPredicate = [NSComparisonPredicate predicateWithLeftExpression:lhs rightExpression:rhs customSelector:@selector(intersectsSet:)];
    lhs = [NSExpression expressionForKeyPath:@"names"];
    rhs = [NSExpression expressionForConstantValue:nameSet ? nameSet : [NSSet set]];
    namePredicate = [NSComparisonPredicate predicateWithLeftExpression:lhs rightExpression:rhs customSelector:@selector(intersectsSet:)];
    predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:fieldPredicate, namePredicate, nil]];
    
    [publicationArrayController setFilterPredicate:predicate];
}

- (void)updatePublicationItems{
    if (publicationItems)
        [publicationItems release];
    publicationItems = [[NSMutableArray alloc] init];
    
    NSMutableSet *theNames = [[NSMutableSet alloc] init];
    NSMutableSet *peopleSet = BDSKCreateFuzzyAuthorCompareMutableSet();
    NSEnumerator *pubEnum = [[[[person publication] owner] publications] objectEnumerator];
    BibItem *pub;
    
    while (pub = [pubEnum nextObject]) {
        NSEnumerator *fieldEnum = [fields objectEnumerator];
        NSString *field;
        
        while (field = [fieldEnum nextObject]) {
            NSArray *people = [pub peopleArrayForField:field];
            
            [peopleSet addObjectsFromArray:people];
            
            if ([peopleSet containsObject:person]) {
                NSMutableSet *fieldSet = [[NSMutableSet alloc] init];
                NSMutableSet *nameSet = [[NSMutableSet alloc] init];
                NSEnumerator *personEnum = [people objectEnumerator];
                BibAuthor *aPerson;
                NSString *name;
                
                while (aPerson = [personEnum nextObject]) {
                    if ([aPerson fuzzyEqual:person]) {
                        name = [aPerson originalName];
                        [nameSet addObject:name];
                        [fieldSet addObject:field];
                        [theNames addObject:name];
                    }
                }
                
                NSDictionary *info = [[NSDictionary alloc] initWithObjectsAndKeys:
                    pub, @"publication", nameSet, @"names", fieldSet, @"fields", nil];
                [publicationItems addObject:info];
                [info release];
                [nameSet release];
                [fieldSet release];
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
        [person release];
        person = [newPerson copy];
    }
}

// binding directly to person.personFromAddressBook.imageData in IB doesn't work for some reason
- (NSData *)imageData{
    return [[person personFromAddressBook] imageData] ? [[person personFromAddressBook] imageData] : [[NSImage imageForFileType:@"vcf"] TIFFRepresentation];
}

#pragma mark actions

- (void)show{
    [self showWindow:self];
}

- (void)updateUI{
	[nameTextField setStringValue:[person name]];
	[publicationTableView reloadData];
}

- (void)handleBibItemChanged:(NSNotification *)note{
    NSString *key = [[note userInfo] valueForKey:@"key"];
    if ([key isEqualToString:[person field]] || key == nil)
        [self setPublicationItems:nil];
}

- (void)handleBibItemAddDel:(NSNotification *)note{
    // we may be adding or removing items, so we can't check publications for containment
    [self setPublicationItems:nil];
}

- (void)handleGroupWillBeRemoved:(NSNotification *)note{
	NSArray *groups = [[note userInfo] objectForKey:@"groups"];
	
	if ([groups containsObject:[[person publication] owner]])
		[self close];
}

- (void)openSelectedPub:(id)sender{
    int row = [publicationTableView selectedRow];
    NSAssert(row >= 0, @"Cannot perform double-click action when no row is selected");
    [(BibDocument *)[self document] editPub:[[[publicationArrayController arrangedObjects] objectAtIndex:row] valueForKey:@"publication"]];
}

- (void)changeNameWarningSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode newName:(NSString *)newNameString;
{
    if(returnCode == NSAlertDefaultReturn)
        [self changeNameToString:newNameString];
    else
        [self updateUI];
	[newNameString release];
}


- (void)controlTextDidEndEditing:(NSNotification *)aNotification;
{
    id sender = [aNotification object];
    if(sender == nameTextField && [sender isEditable]) {// this shouldn't be called for uneditable cells, but it is
        NSString *selFields = [[fieldArrayController selectedObjects] componentsJoinedByCommaAndAnd];
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Really Change Name?", @"Message in alert dialog when trying to edit author name")
                                         defaultButton:NSLocalizedString(@"Yes", @"Button title")
                                       alternateButton:NSLocalizedString(@"No", @"Button title")
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"This will change matching names in any %@ field of the publications shown in the list below.  Do you want to do this?", @"Informative text in alert dialog"), selFields];
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:self 
                         didEndSelector:@selector(changeNameWarningSheetDidEnd:returnCode:newName:) 
                            contextInfo:[[sender stringValue] retain]];
    }
}

// @@ should we also filter for the selected names?
- (void)changeNameToString:(NSString *)newNameString{
    NSEnumerator *itemE = [publicationItems objectEnumerator];
    NSDictionary *item;
    BibItem *pub = nil;
    
    // @@ maybe handle this in the type manager?
    NSArray *pubPeople;
    CFMutableArrayRef people = CFArrayCreateMutable(CFAllocatorGetDefault(), 0, &BDSKAuthorFuzzyArrayCallBacks);
    CFIndex idx;
    BibAuthor *newAuthor;
    
    NSArray *selFields = [fieldArrayController selectedObjects];
    NSEnumerator *fieldE;
    NSString *field;
    
    // we set our person at some point in the iteration, so copy the current value now
    BibAuthor *oldPerson = [[person retain] autorelease];
    
    while(item = [itemE nextObject]){
        
        pub = [item objectForKey:@"publication"];
        
        fieldE = [selFields objectEnumerator];
        
        while (field = [fieldE nextObject]) {
            
            // get the array of BibAuthor objects from a person field (which may be nil or empty)
            pubPeople = [pub peopleArrayForField:field inherit:NO];
                    
            if([pubPeople count]){
                
                CFRange range = CFRangeMake(0, [pubPeople count]);            
                CFArrayAppendArray(people, (CFArrayRef)pubPeople, range);
                
                // use the fuzzy compare to find which author we're going to replace
                while (range.length && -1 != (idx = CFArrayGetFirstIndexOfValue(people, range, (const void *)oldPerson))) {
                    // replace this author, then create a new BibTeX author string
                    newAuthor = [BibAuthor authorWithName:newNameString andPub:pub];
                    CFArraySetValueAtIndex(people, idx, newAuthor);
                    [pub setField:field toValue:[[(NSArray *)people valueForKey:@"originalName"] componentsJoinedByString:@" and "]];
                    if([pub isEqual:[person publication]] && [field isEqualToString:[person field]])
                        [self setPerson:[[pub peopleArrayForField:field] objectAtIndex:idx]]; // changes the window title
                    range = CFRangeMake(range.location + range.length, [pubPeople count] - range.location - range.length);
                }
                CFArrayRemoveAllValues(people);
            }
        }
    }
    CFRelease(people);
    
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

- (NSString *)tableViewFontNamePreferenceKey:(NSTableView *)tv {
    if (tv == publicationTableView)
        return BDSKPersonTableViewFontNameKey;
    else 
        return nil;
}

- (NSString *)tableViewFontSizePreferenceKey:(NSTableView *)tv {
    if (tv == publicationTableView)
        return BDSKPersonTableViewFontSizeKey;
    else 
        return nil;
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
	
    NSBeginAlertSheet(NSLocalizedString(@"Really Change Name?", @"Message in alert dialog when trying to edit author name"),  NSLocalizedString(@"Yes", @"Button title"), NSLocalizedString(@"No", @"Button title"), nil, [self window], self, @selector(changeNameWarningSheetDidEnd:returnCode:newName:), NULL, [[newAuthor name] retain], NSLocalizedString(@"This will change matching names in any \"person\" field (e.g. \"Author\" and \"Editor\") of the publications shown in the list below.  Do you want to do this?", @"Informative text in alert dialog"));
    return YES;
}

- (BOOL)dragImageView:(BDSKDragImageView *)view writeDataToPasteboard:(NSPasteboard *)pboard {
	[pboard declareTypes:[NSArray arrayWithObjects:NSVCardPboardType, NSFilesPromisePboardType, nil] owner:nil];

	// if we don't have a match in the address book, this will create a new person record
	NSData *data = [[ABPerson personWithAuthor:person] vCardRepresentation];
	OBPOSTCONDITION(data);

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
	return [[NSImage imageForFileType:@"vcf"] dragImageWithCount:1];
}

#pragma mark Splitview delegate methods

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize {
    NSView *views[2];
    NSRect frames[2];
    float contentHeight = NSHeight([sender frame]) - [sender dividerThickness];
    float factor = contentHeight / (oldSize.width - [sender dividerThickness]);
    int i, gap;
    
    [[sender subviews] getObjects:views];
    for (i = 0; i < 2; i++) {
        frames[i] = [views[i] frame];
        frames[i].size.height = floorf(factor * NSHeight(frames[i]));
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
    [sender adjustSubviews];
}

- (void)splitView:(OASplitView *)sender multipleClick:(NSEvent *)mouseEvent{
    NSView *pickerView = [[splitView subviews] objectAtIndex:0];
    NSView *pubsView = [[splitView subviews] objectAtIndex:1];
    NSRect pubsFrame = [pubsView frame];
    NSRect pickerFrame = [pickerView frame];
    
    if(NSHeight(pickerFrame) > 0.0){ // can't use isSubviewCollapsed, because implementing splitView:canCollapseSubview: prevents uncollapsing
        lastPickerHeight = NSHeight(pickerFrame); // cache this
        pubsFrame.size.height += lastPickerHeight;
        pickerFrame.size.height = 0;
    } else {
        if(lastPickerHeight <= 0)
            lastPickerHeight = 150.0; // a reasonable value to start
		pickerFrame.size.height = lastPickerHeight;
        pubsFrame.size.height = NSHeight([splitView frame]) - lastPickerHeight - [splitView dividerThickness];
    }
    [pubsView setFrame:pubsFrame];
    [pickerView setFrame:pickerFrame];
    [splitView adjustSubviews];
	// fix for NSSplitView bug, which doesn't send this in adjustSubviews
	[[NSNotificationCenter defaultCenter] postNotificationName:NSSplitViewDidResizeSubviewsNotification object:splitView];
}

#pragma mark Undo Manager

- (NSUndoManager *)undoManager {
	return [[self document] undoManager];
}
    
// we want to have the same undoManager as our document, so we use this 
// NSWindow delegate method to return the doc's undomanager ...
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender{
	return [self undoManager];
}

@end

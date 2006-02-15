//
//  BDSKMainWindowController.m
//  bd2
//
//  Created by Michael McCracken on 6/16/05.
//  Copyright 2005 Michael McCracken. All rights reserved.
//

#import "BDSKMainWindowController.h"
#import "BDSKDataModelNames.h"
#import "BDSKDocument.h"
#import "BDSKGroup.h"
#import "ImageAndTextCell.h"
#import "BDSKBibTeXParser.h"

#import "BDSKPublicationTableDisplayController.h" // @@ TODO: itemdisplayflex this should be temporary
#import "BDSKNoteTableDisplayController.h" // @@ TODO: itemdisplayflex this should be temporary


@implementation BDSKMainWindowController

+ (void)initialize {
    [self setKeys:[NSArray arrayWithObject:@"sourceGroup"] triggerChangeNotificationsForDependentKey:@"sourceListSelectedItems"];
}

- (id)initWithWindowNibName:(NSString *)windowNibName{
    if (self = [super initWithWindowNibName:windowNibName]){
    }
    
    return self;
}

- (void)awakeFromNib{
    // this sets up the displayControllers
    [super awakeFromNib];

    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"priority" ascending:NO];
    [sourceListTreeController setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    [sortDescriptor release];    
    
    NSTableColumn *tc = [sourceList tableColumnWithIdentifier:@"mainColumn"];
    [tc setDataCell:[[[ImageAndTextCell alloc] init] autorelease]];
    
    [sourceListTreeController addObserver:self forKeyPath:@"selectedObjects" options:0 context:NULL];
    [sourceList selectRow:0 byExtendingSelection:NO]; //@@TODO: might want to store last row as a pref

	[sourceList registerForDraggedTypes:[NSArray arrayWithObjects:BDSKPublicationPboardType, BDSKPersonPboardType, BDSKInstitutionPboardType, BDSKVenuePboardType, BDSKNotePboardType, BDSKTagPboardType, nil]];
}

- (void)dealloc{
    [sourceListTreeController removeObserver:self forKeyPath:@"selectedObjects"];
    [super dealloc];
}

-(void)windowDidLoad{ 
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName{
    return displayName;
}

#pragma mark Accessors

- (NSSet *)sourceListSelectedItems{
    id selectedGroup = [self sourceGroup];
    return [selectedGroup valueForKey:@"itemsInSelfOrChildren"];
}

- (void)addSourceListSelectedItemsObject:(id)obj{
    id selectedGroup = [self sourceGroup];
    [[selectedGroup mutableSetValueForKey:@"items"] addObject:obj];
}

- (void)removeSourceListSelectedItemsObject:(id)obj{
    id selectedGroup = [self sourceGroup];
    [[selectedGroup mutableSetValueForKey:@"items"] removeObject:obj];
}

#pragma mark Actions

- (IBAction)showWindowForSourceListSelection:(id)sender{
    BDSKSecondaryWindowController *swc = [[BDSKSecondaryWindowController alloc] initWithWindowNibName:@"BDSKSecondaryWindow"];
    id selectedGroup = [self sourceGroup];
	[swc setSourceGroup:selectedGroup];
	[[self document] addWindowController:[swc autorelease]];
	[swc showWindow:sender];
}

- (IBAction)addNewGroup:(id)sender{
    NSManagedObject *selectedGroup = [self sourceGroup];
    NSString *entityName = [selectedGroup valueForKey:@"itemEntityName"];
    BOOL isSmart = [[selectedGroup valueForKey:@"isSmart"] boolValue];
    
    NSManagedObjectContext *context = [[self document] managedObjectContext];
    id newGroup = [NSEntityDescription insertNewObjectForEntityForName:StaticGroupEntityName
                                                inManagedObjectContext:context];
    
    [newGroup setValue:entityName forKey:@"itemEntityName"];
    [newGroup setValue:@"Untitled Group" forKey:@"name"];
    
    if (isSmart == NO && [[[selectedGroup entity] name] isEqualToString:AutoChildGroupEntityName]) {
        // for non-smart groups we add the new groups as a child
        [newGroup setValue:[NSNumber numberWithBool:NO] forKey:@"isRoot"];
        [[selectedGroup mutableSetValueForKey:@"children"] addObject:newGroup];
    } else {
        // for smart groups (including auto groups) we add the new groups as root
        [newGroup setValue:[NSNumber numberWithBool:YES] forKey:@"isRoot"];
    }
}

- (IBAction)addNewSmartGroup:(id)sender{
    NSManagedObject *selectedGroup = [self sourceGroup];
    NSString *entityName = [selectedGroup valueForKey:@"itemEntityName"];
    NSString *predicateFormat;
    
    // TODO: predicate editing
    // here we just put some arbitrary predicate
    if ([entityName isEqualToString:PublicationEntityName]){
        predicateFormat = @"any contributorRelationships.contributor.lastName like[c] %@";
    } else if ([entityName isEqualToString:PersonEntityName]){
        predicateFormat = @"lastName like[c] %@";
    } else if ([entityName isEqualToString:NoteEntityName]){
        predicateFormat = @"value contains[c] %@";
    } else if ([entityName isEqualToString:InstitutionEntityName]){
        predicateFormat = @"any personRelationships.person.lastName like[c] %@";
    } else if ([entityName isEqualToString:VenueEntityName]){
        predicateFormat = @"any publications.contributorRelationships.contributor.lastName like[c] %@";
    } else if ([entityName isEqualToString:TagEntityName]){
        predicateFormat = @"name like[c] %@";
    } else {
        NSBeep();
        return;
    }
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat, @"Blow"];
    
    NSManagedObjectContext *context = [[self document] managedObjectContext];
    id newSmartGroup = [NSEntityDescription insertNewObjectForEntityForName:SmartGroupEntityName
                                                     inManagedObjectContext:context];
    
    // we always add smart groups as root, as for now they don't take their items from the parent
    [newSmartGroup setValue:entityName forKey:@"itemEntityName"];
    [newSmartGroup setValue:predicate forKey:@"predicate"];
    [newSmartGroup setValue:[NSNumber numberWithBool:YES] forKey:@"isRoot"];
    [newSmartGroup setValue:@"Untitled Smart Group" forKey:@"name"];
}

- (IBAction)addNewAutoGroup:(id)sender{
    NSManagedObject *selectedGroup = [self sourceGroup];
    NSString *entityName = [selectedGroup valueForKey:@"itemEntityName"];
    NSString *propertyName;
    
    // TODO: propertyName editing
    // here we just put some arbitrary propertyName
    if ([entityName isEqualToString:PublicationEntityName]){
        propertyName = @"contributorRelationships.contributor.name";
    } else if ([entityName isEqualToString:PersonEntityName]){
        propertyName = @"publicationRelationships.publication.title";
    } else if ([entityName isEqualToString:NoteEntityName]){
        propertyName = @"name";
    } else if ([entityName isEqualToString:InstitutionEntityName]){
        propertyName = @"name";
    } else if ([entityName isEqualToString:VenueEntityName]){
        propertyName = @"name";
    } else if ([entityName isEqualToString:TagEntityName]){
        propertyName = @"name";
    } else {
        NSBeep();
        return;
    }
    
    NSManagedObjectContext *context = [[self document] managedObjectContext];
    id newAutoGroup = [NSEntityDescription insertNewObjectForEntityForName:AutoGroupEntityName
                                                    inManagedObjectContext:context];
    
    // we always add auto groups as root
    [newAutoGroup setValue:entityName forKey:@"itemEntityName"];
    [newAutoGroup setValue:propertyName forKey:@"itemPropertyName"];
    [newAutoGroup setValue:[NSNumber numberWithBool:YES] forKey:@"isRoot"];
    [newAutoGroup setValue:@"Untitled Auto Group" forKey:@"name"];
}

#pragma mark Source List Outline View DataSource Methods and such

// these are required by the protocol, but unused
- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item{
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item{
    return NO;
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item{
    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item{
    return nil;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)index{
    NSPasteboard *pboard = [info draggingPasteboard];
    id groupItem = [item valueForKey:@"observedObject"];
    NSString *entityName = [groupItem valueForKey:@"itemEntityName"];
    NSString *pboardType = nil;
    
    if ([groupItem isSmart])
        return NSDragOperationNone;
    
    if ([entityName isEqualToString:PublicationEntityName])
        pboardType = BDSKPublicationPboardType;
    else if ([entityName isEqualToString:PersonEntityName])
        pboardType = BDSKPersonPboardType;
    else if ([entityName isEqualToString:InstitutionEntityName])
        pboardType = BDSKInstitutionPboardType;
    else if ([entityName isEqualToString:VenueEntityName])
        pboardType = BDSKVenuePboardType;
    else if ([entityName isEqualToString:NoteEntityName])
        pboardType = BDSKNotePboardType;
    else if ([entityName isEqualToString:TagEntityName])
        pboardType = BDSKTagPboardType;
    else return NSDragOperationNone;
    
    if ([pboard availableTypeFromArray:[NSArray arrayWithObjects:pboardType, nil]] == nil)
        return NSDragOperationNone;
    if (index != NSOutlineViewDropOnItemIndex)
        [outlineView setDropItem:item dropChildIndex:NSOutlineViewDropOnItemIndex];
    
    if ([[[info draggingSource] dataSource] document] != [self document])
        return NSDragOperationNone;
    
    return NSDragOperationLink;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)index{
    NSPasteboard *pboard = [info draggingPasteboard];
    id groupItem = [item valueForKey:@"observedObject"];
    NSString *entityName = [groupItem valueForKey:@"itemEntityName"];
    NSString *pboardType = nil;
    
    if ([groupItem isSmart])
        return NO;
    
    if ([entityName isEqualToString:PublicationEntityName])
        pboardType = BDSKPublicationPboardType;
    else if ([entityName isEqualToString:PersonEntityName])
        pboardType = BDSKPersonPboardType;
    else if ([entityName isEqualToString:InstitutionEntityName])
        pboardType = BDSKInstitutionPboardType;
    else if ([entityName isEqualToString:VenueEntityName])
        pboardType = BDSKVenuePboardType;
    else if ([entityName isEqualToString:NoteEntityName])
        pboardType = BDSKNotePboardType;
    else if ([entityName isEqualToString:TagEntityName])
        pboardType = BDSKTagPboardType;
    else return NO;
    
    if ([pboard availableTypeFromArray:[NSArray arrayWithObjects:pboardType, nil]] == nil)
        return NO;
    
	NSArray *draggedURIs = [NSUnarchiver unarchiveObjectWithData:[pboard dataForType:pboardType]];
	NSEnumerator *uriE = [draggedURIs objectEnumerator];
	NSManagedObjectContext *moc = [[self document] managedObjectContext];
	NSURL *moURI;
	NSMutableSet *items = [groupItem mutableSetValueForKey:@"items"];
	while (moURI = [uriE nextObject]) {
		NSManagedObject *item = [moc objectWithID:[[moc persistentStoreCoordinator] managedObjectIDForURIRepresentation:moURI]];
		if ([items containsObject:item] == NO)
			[items addObject:item];
	}
	return YES;
}

#pragma mark other file format stuff

// importing

// TODO: should this take an argument for the dictionary? what up there?
- (void)importUsingImporter:(id /*<BDSKImporter>*/)importer{
    // open a window using the importer's view 
    // save a ptr to the current importer.
}

- (IBAction)oneShotImportFromBibTeXFile:(id)sender{
    // open file chooser
    
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    int returnCode = [openPanel runModalForTypes:[NSArray arrayWithObject:@"bib"]];
    if (returnCode == NSCancelButton)
        return;
    
	NSString *path = [[openPanel filenames] objectAtIndex: 0];
	if (path == nil)
		return;

    NSData *data = [NSData dataWithContentsOfFile:path];
    BOOL hadProblems = NO;
    
    [BDSKBibTeXParser itemsFromData:data error:&hadProblems document:(BDSKDocument *)[self document]];
}

// TODO: implementation
- (void)importFromBibTeXFile:(id)sender{

}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == sourceListTreeController && [keyPath isEqual:@"selectedObjects"]) {
        NSArray *selectedItems = [sourceListTreeController selectedObjects];
        if ([selectedItems count] > 0)
            [self setSourceGroup:[selectedItems lastObject]];
    }
}

@end

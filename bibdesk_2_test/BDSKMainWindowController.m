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

#import "BDSKPublicationTableDisplayController.h" // @@ TODO: itemdisplayflex this should be temporary
#import "BDSKNoteTableDisplayController.h" // @@ TODO: itemdisplayflex this should be temporary


@implementation BDSKMainWindowController

+ (void)initialize {
    [self setKeys:[NSArray arrayWithObject:@"sourceGroup"] triggerChangeNotificationsForDependentKey:@"sourceListSelectedItems"];
}

- (id)initWithWindowNibName:(NSString *)windowNibName{
    if (self = [super initWithWindowNibName:windowNibName]){
        topLevelSourceListItems = [[NSMutableArray alloc] initWithCapacity:5];
        sourceListSelectedIndexPath = nil;
    }
    
    return self;
}

- (void)awakeFromNib{
    // this sets up the displayControllers
    [super awakeFromNib];

    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"priority" ascending:NO];
    [sourceListTreeController setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    [sortDescriptor release];    
    
    [self setupTopLevelSourceListItems];
    
    NSTableColumn *tc = [sourceList tableColumnWithIdentifier:@"mainColumn"];
    [tc setDataCell:[[[ImageAndTextCell alloc] init] autorelease]];
    
    [sourceListTreeController addObserver:self forKeyPath:@"selectedObjects" options:0 context:NULL];
    [sourceList selectRow:0 byExtendingSelection:NO]; //@@TODO: might want to store last row as a pref

	[sourceList registerForDraggedTypes:[NSArray arrayWithObjects:BDSKPublicationPboardType, BDSKPersonPboardType, BDSKNotePboardType, nil]];
}

- (void)dealloc{
    [sourceListTreeController removeObserver:self forKeyPath:@"selectedObjects"];
    [topLevelSourceListItems release];
    [super dealloc];
}

-(void)windowDidLoad{ 
    [self reloadSourceList];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName{
    return displayName;
}

#pragma mark Source List setup

- (void)reloadSourceList{
    [sourceList reloadData];
}


- (void)setupTopLevelSourceListItems{
	BDSKDocument *doc = (BDSKDocument *)[self document];
    id rootGroup = nil;
    if (rootGroup = [doc rootPublicationGroup])
        [topLevelSourceListItems addObject:rootGroup];
    if (rootGroup = [doc rootPersonGroup])
        [topLevelSourceListItems addObject:rootGroup];
    if (rootGroup = [doc rootNoteGroup])
        [topLevelSourceListItems addObject:rootGroup];
}

#pragma mark Accessors

- (NSArray *)topLevelSourceListItems {
    return [[topLevelSourceListItems retain] autorelease];
}

- (unsigned)countOfTopLevelSourceListItems {
    return [topLevelSourceListItems count];
}

- (id)objectInTopLevelSourceListItemsAtIndex:(unsigned)index {
    return [topLevelSourceListItems objectAtIndex:index];
}

- (void)insertObject:(id)obj inTopLevelSourceListItemsAtIndex:(unsigned)index {
    [topLevelSourceListItems insertObject:obj atIndex:index];
}

- (void)removeObjectFromTopLevelSourceListItemsAtIndex:(unsigned)index {
    [topLevelSourceListItems removeObjectAtIndex:index];
}

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

- (NSIndexPath *)sourceListSelectedIndexPath {
    return sourceListSelectedIndexPath;
}

- (void)setSourceListSelectedIndexPath:(NSIndexPath *)indexPath {
    if (indexPath != sourceListSelectedIndexPath) {
        [sourceListSelectedIndexPath release];
        sourceListSelectedIndexPath = [indexPath copy];
        [self setSourceGroup:[[sourceListTreeController selectedObjects] lastObject]];
    }
}

#pragma mark Actions

- (IBAction)showWindowForSourceListSelection:(id)sender{
    BDSKSecondaryWindowController *swc = [[BDSKSecondaryWindowController alloc] initWithWindowNibName:@"BDSKSecondaryWindow"];
    id selectedGroup = [self sourceGroup];
	[swc setSourceGroup:selectedGroup];
	[[self document] addWindowController:[swc autorelease]];
	[swc showWindow:sender];
}

- (IBAction)addNewItemFromSourceListSelection:(id)sender{
    [super addNewItem:sender];
}

- (IBAction)addNewSmartGroupFromSourceListSelection:(id)sender{
    id obj = [self sourceGroup];
    
    if ([[obj valueForKey:@"isRoot"] boolValue] == YES) {
        [self addNewSmartGroupToContainer:obj];
    } else NSBeep();
}

- (IBAction)addNewGroupFromSourceListSelection:(id)sender{
    id obj = [self sourceGroup];
    NSString *entityName = [obj valueForKey:@"itemEntityName"];
        
    if ([entityName isEqualToString:PublicationEntityName]){
        [self addNewPublicationGroupToContainer:obj];
    }
    else if ([entityName isEqualToString:NoteEntityName]){
        [self addNewNoteGroupToContainer:obj];
    }
    else if ([entityName isEqualToString:PersonEntityName]){
        [self addNewPersonGroupToContainer:obj]; 
    }
    else NSBeep();
}

- (void)addNewPublicationGroupToContainer:(id)container{
    NSManagedObjectContext *managedObjectContext = [[self document] managedObjectContext];
    id newPublicationGroup = [NSEntityDescription insertNewObjectForEntityForName:PublicationGroupEntityName
                                                  inManagedObjectContext:managedObjectContext];
    
    [newPublicationGroup setValue:@"Untitled Publication Group" forKey:@"name"];

    NSMutableSet *children = [container mutableSetValueForKey:@"children"];
    [children addObject:newPublicationGroup];
}

- (void)addNewPersonGroupToContainer:(id)container{
    NSManagedObjectContext *managedObjectContext = [[self document] managedObjectContext];
    id newPersonGroup = [NSEntityDescription insertNewObjectForEntityForName:PersonGroupEntityName
                                                    inManagedObjectContext:managedObjectContext];
    
    [newPersonGroup setValue:@"Untitled Person Group" forKey:@"name"];

    NSMutableSet *children = [container mutableSetValueForKey:@"children"];
    [children addObject:newPersonGroup];
}

- (void)addNewNoteGroupToContainer:(id)container{
    NSManagedObjectContext *managedObjectContext = [[self document] managedObjectContext];
    id newNoteGroup = [NSEntityDescription insertNewObjectForEntityForName:NoteGroupEntityName
                                                 inManagedObjectContext:managedObjectContext];
    
    [newNoteGroup setValue:@"Untitled Note Group" forKey:@"name"];

    NSMutableSet *children = [container mutableSetValueForKey:@"children"];
    [children addObject:newNoteGroup];
}

- (void)addNewSmartGroupToContainer:(id)container{
    NSManagedObjectContext *managedObjectContext = [[self document] managedObjectContext];
    id newSmartGroup = [NSEntityDescription insertNewObjectForEntityForName:SmartGroupEntityName
                                                 inManagedObjectContext:managedObjectContext];
    
    [newSmartGroup setValue:[container valueForKey:@"itemEntityName"] forKey:@"itemEntityName"];
    [newSmartGroup setValue:@"Untitled Smart Group" forKey:@"name"];

    NSMutableSet *children = [container mutableSetValueForKey:@"children"];
    [children addObject:newSmartGroup];
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
    else if ([entityName isEqualToString:NoteEntityName])
        pboardType = BDSKNotePboardType;
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
    else if ([entityName isEqualToString:NoteEntityName])
        pboardType = BDSKNotePboardType;
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
    
    NSOpenPanel *op = [NSOpenPanel openPanel];
    [op runModalForDirectory:nil
                        file:@""];
    NSLog(@"import chose %@", [op filenames]);
    
    // [self importUsingImporter:[BDSKBibTeXImporter sharedImporter] ];
    
    // call into BDSKBibTeXParser stuff to get managed objects
    
    // insert into document's MOC
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

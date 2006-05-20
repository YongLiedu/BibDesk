//
//  BDSKTableDisplayController.m
//  bd2xtest
//
//  Created by Christiaan Hofman on 1/29/06.
//  Copyright 2006. All rights reserved.
//

#import "BDSKTableDisplayController.h"
#import "BDSKDataModelNames.h"


@implementation BDSKDisplayController

+ (void)initialize{
   [self setKeys:[NSArray arrayWithObject:@"document"] triggerChangeNotificationsForDependentKey:@"managedObjectContext"];
}

- (id)init{
	if (self = [super init]) {
		document = nil;
	}
	return self;
}

- (void)dealloc{
	[mainView release];
    [super dealloc];
}

- (void)awakeFromNib{
    [mainView retain];
    [self setWindow:nil];
}

- (void)windowDidLoad {
}

- (NSView *)view{
    if (mainView == nil) {
        [self window]; // force load of the nib
    }
    return mainView;
}

- (NSDocument *)document{
	return document;
}

- (void)setDocument:(NSDocument *)newDocument{
	if (newDocument != nil && [newDocument isKindOfClass:[NSPersistentDocument class]] == NO)
		[NSException raise:@"BDSWrongDocumentException" format:@"Document class %@ is not a subclass of NSPersistentDocument.", [newDocument class]];
	else
		document = newDocument;
}

- (NSManagedObjectContext *)managedObjectContext{
	return [(NSPersistentDocument *)document managedObjectContext];
}

- (NSString *)itemEntityName {
    return itemEntityName;
}

- (void)setItemEntityName:(NSString *)entityName {
    if (entityName != itemEntityName) {
        [itemEntityName release];
        itemEntityName = [entityName retain];
        [self updateUI];
    }
}

- (void)updateUI {}

#pragma mark Drag/drop

- (BOOL)addRelationshipsFromPasteboard:(NSPasteboard *)pboard forType:(NSString *)type parent:(NSManagedObject *)parent keyPath:(NSString *)keyPath {
	NSString *childKey = keyPath;
	NSString *relationshipKey = keyPath;
	BOOL hasRelationshipEntity = NO;
	NSRange dotRange = [keyPath rangeOfString:@"."];
	if (dotRange.location != NSNotFound) {
		relationshipKey = [keyPath substringToIndex:dotRange.location];
		childKey = [keyPath substringFromIndex:dotRange.location + 1];
		hasRelationshipEntity = YES;
	}
	
	NSArray *draggedURIs = [NSUnarchiver unarchiveObjectWithData:[pboard dataForType:type]];
	NSEnumerator *uriE = [draggedURIs objectEnumerator];
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSURL *moURI;
	NSString *entityName = [[[[[parent entity] relationshipsByName] objectForKey:relationshipKey] destinationEntity] name];
	BOOL isToMany = [[[[parent entity] relationshipsByName] objectForKey:relationshipKey] isToMany];
	NSMutableSet *relationships = (isToMany) ? [parent mutableSetValueForKey:relationshipKey] : nil;
	NSSet *children = relationships;
	BOOL hasIndex = NO;
	
    if (hasRelationshipEntity) {
		children = [relationships valueForKeyPath:[NSString stringWithFormat:@"@distinctUnionOfObjects.%@", childKey]];
		hasIndex = [entityName isEqualToString:ContributorPublicationRelationshipEntityName];
	}
    
	while (moURI = [uriE nextObject]) {
		NSManagedObject *child = [moc objectWithID:[[moc persistentStoreCoordinator] managedObjectIDForURIRepresentation:moURI]];
		NSManagedObject *relationship = child;
		
        if ([children containsObject:child])
			continue;
		if (hasRelationshipEntity) {
			relationship = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:moc];
			if (hasIndex) {
				NSManagedObject *publication = [childKey isEqualToString:@"publication"] ? child : parent;
				NSNumber *index = [publication valueForKeyPath:@"contributorRelationships.@count"];
				[relationship setValue:index forKey:@"index"];
				if ([[[child entity] name] isEqualToString:@"Person"] || [[[parent entity] name] isEqualToString:@"Person"])
					[relationship setValue:@"author" forKey:@"relationshipType"];
				else if ([[[child entity] name] isEqualToString:@"Institution"] || [[[parent entity] name] isEqualToString:@"Institution"])
					[relationship setValue:@"institution" forKey:@"relationshipType"];
			}
			[relationship setValue:child forKey:childKey];
		}
        if (isToMany == YES) {
            [relationships addObject:relationship];
        } else {
            [parent setValue:relationship forKey:relationshipKey];
            return YES;
        }
	}
    
	return YES;
}

@end


@implementation BDSKItemDisplayController

- (NSObjectController *)itemObjectController{
    return itemObjectController;
}

#pragma mark Drag/drop

- (BOOL)addRelationshipsFromPasteboard:(NSPasteboard *)pboard forType:(NSString *)type keyPath:(NSString *)keyPath {
	NSManagedObject *parent = [itemObjectController content];
    
    if (parent == nil || NSIsControllerMarker(parent))
        return NO;
    
    return [self addRelationshipsFromPasteboard:pboard forType:type parent:parent keyPath:keyPath];
}

@end


@implementation BDSKTableDisplayController

- (id)init{
	if (self = [super init]) {
        NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DisplayControllers" ofType:@"plist"]];
        itemDisplayControllersInfoDict = [[infoDict objectForKey:@"ItemDisplayControllers"] retain];
        itemDisplayControllers = [[NSMutableArray alloc] initWithCapacity:10];
        currentItemDisplayControllerForEntity = [[NSMutableDictionary alloc] initWithCapacity:10];
		currentItem = nil;
	}
	return self;
}

- (void)dealloc{
    [itemsArrayController removeObserver:self forKeyPath:@"selectedObjects"];
    if (currentItemDisplayView) 
        [self setItemDisplayController:nil];
    [itemDisplayControllers release];
    [currentItemDisplayControllerForEntity release];        
    [itemDisplayControllersInfoDict release];
	[currentItem release];
    [super dealloc];
}

- (void)awakeFromNib{
    [super awakeFromNib];
    [mainView retain];
    [self setWindow:nil];
    
    [self setupItemDisplayControllers];
	
    [self updateUI];
    
    [itemsArrayController addObserver:self forKeyPath:@"selectedObjects" options:0 context:NULL];
}

- (void)updateUI {
    if (currentItemDisplayController == nil && currentItemDisplayView != nil) {
        NSEntityDescription *entity = [[self currentItem] entity];
        BDSKItemDisplayController *newDisplayController = [self itemDisplayControllerForEntity:entity];
        if (newDisplayController != currentItemDisplayController){
            [self unbindItemDisplayController:currentItemDisplayController];
            [self setItemDisplayController:newDisplayController];
        }
    }
}

#pragma mark Accessors

- (NSArrayController *)itemsArrayController{
    return itemsArrayController;
}

- (NSTableView *)itemsTableView{
    return itemsTableView;
}

- (NSArray *)filterPredicates {
    // should be implemented by the subclasses
    return nil;
}

- (NSManagedObject *)currentItem{
	return currentItem;
}

// this cannot be called after the display controller has been bound, due to binding issues.
- (void)setCurrentItem:(NSManagedObject *)newItem{
	if (newItem != currentItem) {
		
		BDSKItemDisplayController *newDisplayController = nil;
		BOOL shouldChangeDisplayController = NO;
		
        if (currentItemDisplayView) {
            NSString *oldEntityClassName = [[currentItem entity] name];
            NSString *newEntityClassName = [[newItem entity] name];
            
            if ([newEntityClassName isEqualToString:oldEntityClassName] == NO) {
                newDisplayController = [self itemDisplayControllerForEntity:[newItem entity]];
                if (newDisplayController != currentItemDisplayController){
                    [self unbindItemDisplayController:currentItemDisplayController];
                    shouldChangeDisplayController = YES;
                }
            }
        }
		
		[currentItem autorelease];
		currentItem = [newItem retain];
		
		if (shouldChangeDisplayController == YES)
			[self setItemDisplayController:newDisplayController];
	}
}

- (BDSKItemDisplayController *)itemDisplayController{
    return currentItemDisplayController;
}

- (void)setItemDisplayController:(BDSKItemDisplayController *)newDisplayController{
    if(newDisplayController != currentItemDisplayController){
        [currentItemDisplayController autorelease];
        if(currentItemDisplayController)
            [self unbindItemDisplayController:currentItemDisplayController];
        
        NSView *view = [newDisplayController view];
        if (view == nil) 
            view = [[[NSView alloc] init] autorelease];
        [view setFrame:[currentItemDisplayView frame]];
        [[currentItemDisplayView superview] replaceSubview:currentItemDisplayView with:view];
        currentItemDisplayView = view;
        currentItemDisplayController = [newDisplayController retain];
        [self bindItemDisplayController:currentItemDisplayController];
    }
}

- (NSArray *)itemDisplayControllers{
	return itemDisplayControllers;
}

// TODO: this is totally incomplete.
- (NSArray *)itemDisplayControllersForCurrentType{
    NSSet* currentTypes = nil; // temporary, removed treecontroller.
    NSLog(@"itemDisplayControllersForCurrentType - currentTypes is %@.", currentTypes);
    
    return [NSArray arrayWithObjects:currentItemDisplayController, nil];
}


#pragma mark Item Display Controller management

- (void)setupItemDisplayControllers{
    
    NSArray *displayControllerClassNames = [itemDisplayControllersInfoDict allKeys];
    NSEnumerator *displayControllerClassNameE = [displayControllerClassNames objectEnumerator];
    NSString *displayControllerClassName = nil;
    
    while (displayControllerClassName = [displayControllerClassNameE nextObject]){
        Class controllerClass = NSClassFromString(displayControllerClassName);
        BDSKItemDisplayController *controllerObject = [[controllerClass alloc] init];
        [controllerObject setDocument:[self document]];
        [itemDisplayControllers addObject:controllerObject];
        [controllerObject release];

        NSDictionary *infoDict = [itemDisplayControllersInfoDict objectForKey:displayControllerClassName];
           
        //TODO: for now we have a 1:1 between DCs and entity names. 
        // this code will need to get smarter when that changes.
        NSString *displayableEntity = [[infoDict objectForKey:@"DisplayableEntities"] objectAtIndex:0];
        [currentItemDisplayControllerForEntity setObject:controllerObject
                                              forKey:displayableEntity];
    }
    
}

- (BDSKItemDisplayController *)itemDisplayControllerForEntity:(NSEntityDescription *)entity{
    NSManagedObjectContext *context = [self managedObjectContext];
    id displayController = nil;
    
    if (entity == nil)
        entity = [NSEntityDescription entityForName:[self itemEntityName] inManagedObjectContext:context];
    
    while (displayController == nil && entity != nil) {
        displayController = [currentItemDisplayControllerForEntity objectForKey:[entity name]];
        entity = [entity superentity];
    }
    return displayController;
}

- (void)bindItemDisplayController:(BDSKItemDisplayController *)displayController{
	// Not binding the contentSet will get all the managed objects for the entity
	// Binding contentSet will not update a dynamic smart group
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], NSRaisesForNotApplicableKeysBindingOption, [NSNumber numberWithBool:YES], NSConditionallySetsEnabledBindingOption, [NSNumber numberWithBool:YES], NSDeletesObjectsOnRemoveBindingsOption, nil];
    // TODO: in future, this should create multiple bindings.?    
    [[displayController itemObjectController] bind:@"contentObject" toObject:self
                                       withKeyPath:@"currentItem" options:options];
}


// TODO: as the above method creates multiple bindings, this one will have to keep up.
- (void)unbindItemDisplayController:(BDSKItemDisplayController *)displayController{
	[[displayController itemObjectController] unbind:@"contentObject"];
}

#pragma mark Actions

- (void)addItem {
	NSManagedObjectContext *moc = [self managedObjectContext];
    NSString *entityName = [self itemEntityName];
    if ([entityName isEqualToString:@"Item"])
        entityName = PublicationEntityName;
	NSManagedObject *mo = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:moc];
    [itemsArrayController addObject:mo];
    [moc processPendingChanges];
    [itemsArrayController setSelectedObjects:[NSArray arrayWithObject:mo]];
}

- (void)removeItems:(NSArray *)selectedItems {
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSEnumerator *selEnum = [selectedItems objectEnumerator];
	NSManagedObject *mo;
	while (mo = [selEnum nextObject]) 
		[moc deleteObject:mo];
    [moc processPendingChanges];
    // dirty fix for CoreData bug, which registers an extra change when objects are deleted
    [[self document] updateChangeCount:NSChangeUndone];
}

#pragma mark Drag/drop

- (BOOL)writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard forType:(NSString *)type {
    NSArray *allItems = [itemsArrayController arrangedObjects];
    NSMutableArray *draggedItems = [[NSMutableArray alloc] initWithCapacity:[rowIndexes count]];
    unsigned row = [rowIndexes firstIndex];
    NSManagedObject *mo;
    
    [pboard declareTypes:[NSArray arrayWithObject:type] owner:self];
    while (row != NSNotFound) {
        mo = [allItems objectAtIndex:row];
        [draggedItems addObject:[[mo objectID] URIRepresentation]];
        row = [rowIndexes indexGreaterThanIndex:row];
    }
    [pboard setData:[NSArchiver archivedDataWithRootObject:draggedItems] forType:type];
    [draggedItems release];
    
    return YES;
}

- (BOOL)addRelationshipsFromPasteboard:(NSPasteboard *)pboard forType:(NSString *)type parentRow:(int)row keyPath:(NSString *)keyPath {
	if (row == -1)
		row = [itemsArrayController selectionIndex];
	if (row == -1)
		return NO;
	NSManagedObject *parent = [[itemsArrayController arrangedObjects] objectAtIndex:row];
    
    return [self addRelationshipsFromPasteboard:pboard forType:type parent:parent keyPath:keyPath];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == itemsArrayController && [keyPath isEqual:@"selectedObjects"]) {
        NSArray *selectedItems = [itemsArrayController selectedObjects];
        if ([selectedItems count] > 0)
            [self setCurrentItem:[selectedItems lastObject]];
        else
            [self setCurrentItem:nil];
    }
}

@end

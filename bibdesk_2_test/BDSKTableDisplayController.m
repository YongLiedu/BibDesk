//
//  BDSKTableDisplayController.m
//  bd2xtest
//
//  Created by Christiaan Hofman on 1/29/06.
//  Copyright 2006. All rights reserved.
//

#import "BDSKTableDisplayController.h"
#import "BDSKDataModelNames.h"


@implementation BDSKTableDisplayController

+ (void)initialize{
   [self setKeys:[NSArray arrayWithObject:@"document"] triggerChangeNotificationsForDependentKey:@"managedObjectContext"];
}

- (id)init{
	if (self = [super init]) {
		mainView = nil;
		document = nil;
		[NSBundle loadNibNamed:[self viewNibName] owner:self];
	}
	return self;
}

- (void)dealloc{
	[itemsArrayController release];
	[mainView release];
    [super dealloc];
}

- (void)awakeFromNib{
    [selectionDetailsBox setBackgroundImage:[NSImage imageNamed:@"coffeeStain"]];
}

- (NSView *)view{
    if(mainView == nil){
        [NSBundle loadNibNamed:[self viewNibName] owner:self];
    }
    return mainView;
}

- (NSString *)viewNibName{
	[NSException raise:@"BDSKUnimplementedException" format:@"Display controller class %@ does not implement -viewNibname.", [self class]];
	return nil;
}

- (NSArrayController *)itemsArrayController{
    return itemsArrayController;
}

- (NSTableView *)itemsTableView{
    return itemsTableView;
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

- (NSArray *)filterPredicates {
    // should be implemented by the subclasses
    return nil;
}

// drag/drop

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
	NSManagedObject *parent = [[itemsArrayController arrangedObjects] objectAtIndex:row];
	NSString *entityName = [[[[[parent entity] relationshipsByName] objectForKey:relationshipKey] destinationEntity] name];
	NSMutableSet *relationships = [parent mutableSetValueForKey:relationshipKey];
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
		[relationships addObject:relationship];
	}
    
	return YES;
}

@end

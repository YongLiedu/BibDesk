//
//  BDSKAutoGroup.m
//  bd2xtest
//
//  Created by Christiaan Hofman on 2/8/06.
//  Copyright 2006. All rights reserved.
//

#import "BDSKAutoGroup.h"
#import "BDSKDataModelNames.h"
#import "BDSKDocument.h"
#import "BDSKSmartGroup.h"


@implementation BDSKAutoGroup

- (id)initWithEntity:(NSEntityDescription*)entity insertIntoManagedObjectContext:(NSManagedObjectContext*)context{
	if (self = [super initWithEntity:entity insertIntoManagedObjectContext:context]) {
		children = nil;
        isToMany = NO;
        recreatingChildren = NO;
		[self addObserver:self forKeyPath:@"itemPropertyName" options:0 context:NULL];
		[self addObserver:self forKeyPath:@"itemEntityName" options:0 context:NULL];
	}
	return self;
}

- (void)dealloc{
	[self removeObserver:self forKeyPath:@"itemPropertyName"];
	[self removeObserver:self forKeyPath:@"itemEntityName"];
	[super dealloc];
}

- (void)commonAwake {
    [super commonAwake];
    [self reset]; // is this necessary?
}

- (void)didTurnIntoFault {
    if ([children count]) {
        
        NSManagedObjectContext *moc = [self managedObjectContext];
        NSEnumerator *childEnum = [children objectEnumerator];
        NSManagedObject *child;
        
        [moc processPendingChanges];
        [[moc undoManager] disableUndoRegistration];
        
        while (child = [childEnum nextObject]) {
            [moc deleteObject:child];
        }
        
        [moc processPendingChanges];
        [[moc undoManager] enableUndoRegistration];
    }
    
	[children release];
    children = nil;    
    
    [super didTurnIntoFault];
}

// refresh isToMany and the children
- (void)reset {
    NSString *propertyName = [self itemPropertyName];
    NSString *entityName = [self itemEntityName];
    
    if (propertyName != nil && entityName != nil) {
        NSString *firstKey = [[propertyName componentsSeparatedByString:@"."] objectAtIndex:0];
        NSManagedObjectContext *moc = [self managedObjectContext];
        NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:moc];
        
        isToMany = [[[entity relationshipsByName] objectForKey:firstKey] isToMany];
    } else {
        isToMany = NO;
    }
    
    [self refresh];
}

- (void)refresh {
    NSManagedObjectContext *moc = [self managedObjectContext];
    [moc processPendingChanges];
    [[moc undoManager] disableUndoRegistration];
	
    if ([children count]) {
        NSEnumerator *childEnum = [children objectEnumerator];
        NSManagedObject *child;
        
        while (child = [childEnum nextObject]) {
            [moc deleteObject:child];
        }
    }    
    
    [self willChangeValueForKey:@"children"];
    
	[children release];
    children = nil;    
    
    [self didChangeValueForKey:@"children"];
	
    [moc processPendingChanges];
    [[moc undoManager] enableUndoRegistration];
}

- (void)managedObjectContextObjectsDidChange:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSMutableSet *modifiedObjects = [NSMutableSet set];
    
    // TODO: maybe we can be more smart and filter entities relevant for us
    NSSet *itemEntityNames = [NSSet setWithObjects:PublicationEntityName, PersonEntityName, InstitutionEntityName, VenueEntityName, NoteEntityName, TagEntityName, nil];
	
	[modifiedObjects unionSet:[userInfo objectForKey:NSUpdatedObjectsKey]];
	[modifiedObjects unionSet:[userInfo objectForKey:NSInsertedObjectsKey]];
	[modifiedObjects unionSet:[userInfo objectForKey:NSDeletedObjectsKey]];
	
	NSEnumerator *enumerator = [modifiedObjects objectEnumerator];	
	id object;
	BOOL refresh = NO;
	
    while (object = [enumerator nextObject]) {
		if ([itemEntityNames containsObject:[[object entity] name]]) {
			refresh = YES;
            break;
		}
	}
	    
    if (refresh == NO && [modifiedObjects count] == 0) {
        refresh = YES;
    }
	
    if (refresh) {
        // we need to call it this way, or the document gets an extra changeCount. Don't ask me why...
		[self performSelector:@selector(refresh) withObject:nil afterDelay:0.0];
    }
}

#pragma mark Accessors

- (NSString *)itemEntityName {
    NSString *entityName = nil;
    [self willAccessValueForKey:@"itemEntityName"];
    entityName = [self primitiveValueForKey:@"itemEntityName"];
    [self didAccessValueForKey:@"itemEntityName"];
    return entityName;
}

- (void)setItemEntityName:(NSString *)entityName {
    [self willChangeValueForKey:@"itemEntityName"];
    [self setPrimitiveValue:entityName forKey:@"itemEntityName"];
    [self didChangeValueForKey:@"itemEntityName"];
}

- (NSString *)itemPropertyName {
    NSString *propertyName = nil;
    [self willAccessValueForKey:@"itemPropertyName"];
    propertyName = [self primitiveValueForKey:@"itemPropertyName"];
    [self didAccessValueForKey:@"itemPropertyName"];
    return propertyName;
}

- (void)setItemPropertyName:(NSString *)propertyName {
    [self willChangeValueForKey:@"itemPropertyName"];
    [self setPrimitiveValue:propertyName forKey:@"itemPropertyName"];
    [self didChangeValueForKey:@"itemPropertyName"];
}

- (NSString *)groupImageName {  
    // TODO: add new icon
    return @"SmartGroupIcon";
}

- (BOOL)isSmart {
    return YES;
}

- (BOOL)canEdit {
    return YES;
}

- (NSSet *)items {
    return [NSSet set];
}

- (void)setItems:(NSSet *)newItems  {
    // noop   
}

- (NSSet *)children {
    if (children == nil)  {
        NSString *entityName = [self itemEntityName];
        NSString *propertyName = [self itemPropertyName];
        
        children = [[NSMutableSet alloc] init];
        if (entityName == nil || propertyName == nil || recreatingChildren == YES) 
            return children;
        
        // our fetchRequest later can call -children while we are building, effectively adding them twice. Is there a better way to avoid?
        recreatingChildren = YES;
        
        NSManagedObjectContext *moc = [self managedObjectContext];
        NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:moc];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSError *error = nil;
        NSArray *results = nil;
        
        // maybe we should get the document's root group instead?
        [fetchRequest setEntity:entity];
        @try {  results = [moc executeFetchRequest:fetchRequest error:&error];  }
        @catch ( NSException *e ) {  /* no-op */ }
        [fetchRequest release];
        
        NSString *allValuesKeyPath = (isToMany) ? [NSString stringWithFormat:@"@distinctUnionOfSets.%@", propertyName] : propertyName;
        NSSet *allValues = [results valueForKeyPath:allValuesKeyPath];
        NSEnumerator *valueEnum = [allValues objectEnumerator];
        id value;
        BDSKSmartGroup *child;
        NSString *predicateFormat = (isToMany) ? @"any %K == %@" : @"%K == %@";
        NSSet *childItems;
        NSPredicate *predicate;
	
        // adding the children should not be undoable
        [moc processPendingChanges];
        [[moc undoManager] disableUndoRegistration];
        
        while (value = [valueEnum nextObject]) {
            child = [NSEntityDescription insertNewObjectForEntityForName:AutoChildGroupEntityName inManagedObjectContext:moc];
            [child setValue:entityName forKey:@"itemEntityName"];
            [child setValue:value forKey:@"name"];
            predicate = [NSPredicate predicateWithFormat:predicateFormat, propertyName, value];
            childItems = [[NSSet alloc] initWithArray:[results filteredArrayUsingPredicate:predicate]];
            [child setValue:childItems forKey:@"items"];
            [childItems release];
            [children addObject:child];
        }
	
        [moc processPendingChanges];
        [[moc undoManager] enableUndoRegistration];
        
        recreatingChildren = NO;
    }
    return children;
}

- (void)setChildren:(NSSet *)newChildren  {
    // noop   
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"itemEntityName"] || [keyPath isEqualToString:@"itemPropertyName"]) {
        [self reset];
    }
}

@end


@implementation BDSKAutoChildGroup

- (void)commonAwake {
    [super commonAwake];
    
    items = nil;
}

- (void)didTurnIntoFault {
    [items release];
    items = nil;
    
    [super didTurnIntoFault];
}

#pragma mark Accessors

- (NSString *)itemEntityName {
    NSString *entityName = nil;
    [self willAccessValueForKey:@"itemEntityName"];
    entityName = [self primitiveValueForKey:@"itemEntityName"];
    [self didAccessValueForKey:@"itemEntityName"];
    return entityName;
}

- (void)setItemEntityName:(NSString *)entityName {
    [self willChangeValueForKey: @"itemEntityName"];
    [self setPrimitiveValue:entityName forKey:@"itemEntityName"];
    [self didChangeValueForKey:@"itemEntityName"];
}

- (BOOL)canEdit {
    return NO;
}

- (BOOL)canEditName {
    return NO;
}

- (NSSet *)items {
    return items;
}

- (void)setItems:(NSSet *)newItems  {
    if (items != newItems) {
        [items release];
        items = [newItems retain];
    }
}

- (NSSet *)children {
    return nil;
}

- (void)setChildren:(NSSet *)newChildren  {
    // noop
}

@end

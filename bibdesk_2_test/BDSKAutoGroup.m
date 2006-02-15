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
		items = nil;
        isToMany = NO;
        recreatingChildren = NO;
	}
	return self;
}

- (void)dealloc{
	[super dealloc];
}

- (void)commonAwake {
    [super commonAwake];
    
    [self addObserver:self forKeyPath:@"itemPropertyName" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"itemEntityName" options:0 context:NULL];
    
    [self willAccessValueForKey:@"priority"];
    [self setValue:[NSNumber numberWithInt:2] forKeyPath:@"priority"];
    [self didAccessValueForKey:@"priority"];
    
    [self reset]; // is this necessary?
}

- (void)didTurnIntoFault {
	[self removeObserver:self forKeyPath:@"itemPropertyName"];
	[self removeObserver:self forKeyPath:@"itemEntityName"];
    
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
    
    [super refresh]; // refresh items
}

#pragma mark Accessors

- (void)setPredicate:(NSPredicate *)newPredicate {
    // noop, we always want the TRUE predicate
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

- (NSSet *)children {
    if (children == nil)  {
        NSString *entityName = [self itemEntityName];
        NSString *propertyName = [self itemPropertyName];
        
        children = [[NSMutableSet alloc] init];
        if (entityName == nil || propertyName == nil || recreatingChildren == YES) 
            return children;
        
        // our fetchRequest in -items can call -children while we are building, effectively adding them twice. Is there a better way to avoid?
        recreatingChildren = YES;
        
        NSString *allValuesKeyPath = (isToMany) ? [NSString stringWithFormat:@"@distinctUnionOfSets.%@", propertyName] : propertyName;
        NSSet *allItems = [self items];
        NSArray *allItemsArray = [allItems allObjects];
        NSSet *allValues = [[self items] valueForKeyPath:allValuesKeyPath];
        NSEnumerator *valueEnum = [allValues objectEnumerator];
        id value;
        BDSKSmartGroup *child;
        NSString *predicateFormat = (isToMany) ? @"any %K == %@" : @"%K == %@";
        NSSet *childItems;
        NSPredicate *predicate;
	
        // adding the children should not be undoable
        NSManagedObjectContext *moc = [self managedObjectContext];
        [moc processPendingChanges];
        [[moc undoManager] disableUndoRegistration];
        
        while (value = [valueEnum nextObject]) {
            child = [NSEntityDescription insertNewObjectForEntityForName:AutoChildGroupEntityName inManagedObjectContext:moc];
            [child setValue:entityName forKey:@"itemEntityName"];
            [child setValue:value forKey:@"name"];
            predicate = [NSPredicate predicateWithFormat:predicateFormat, propertyName, value];
            childItems = [[NSSet alloc] initWithArray:[allItemsArray filteredArrayUsingPredicate:predicate]];
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

- (void)awakeFromInsert {
    [super awakeFromInsert];
    items = nil;
}

- (void)awakeFromFetch {
    [super awakeFromFetch];
    items = nil;
}

- (void)didTurnIntoFault {
    [items release];
    items = nil;
    
    [super didTurnIntoFault];
}

#pragma mark Accessors

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
    return [NSSet set];
}

- (void)setChildren:(NSSet *)newChildren  {
    // noop
}

@end

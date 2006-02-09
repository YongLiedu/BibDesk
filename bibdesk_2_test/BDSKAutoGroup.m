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

- (void)commonAwake {
    [super commonAwake];
    //[self refresh];
}

- (void)refresh {
	[self willChangeValueForKey:@"children"];
	[children release];
    children = nil;    
	[self didChangeValueForKey:@"children"];
}

- (void)managedObjectContextObjectsDidChange:(NSNotification *)notification {
	NSEnumerator *enumerator;
	id object;
	BOOL refresh = NO;
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:[self itemEntityName] inManagedObjectContext:[self managedObjectContext]];
	
	NSSet *updated = [[notification userInfo] objectForKey:NSUpdatedObjectsKey];
	NSSet *inserted = [[notification userInfo] objectForKey:NSInsertedObjectsKey];
	NSSet *deleted = [[notification userInfo] objectForKey:NSDeletedObjectsKey];
	
	enumerator = [updated objectEnumerator];	
	while ((refresh == NO) && (object = [enumerator nextObject])) {
		if ([object entity] == entity) {
			refresh = YES;	
		}
	}

	enumerator = [inserted objectEnumerator];	
	while ((refresh == NO) && (object = [enumerator nextObject])) {
		if ([object entity] == entity) {
			refresh = YES;	
		}
	}

	enumerator = [deleted objectEnumerator];	
	while ((refresh == NO) && (object = [enumerator nextObject])) {
		if ([object entity] == entity) {
			refresh = YES;	
		}
	}
	    
    if ( (refresh == NO) && (([updated count] == 0) && ([inserted count] == 0) && ([deleted count] == 0))) {
        refresh = YES;
    }
	
    if (refresh) {
		[self refresh];
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
    [self refresh];
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
    
    NSString *firstKey = [[propertyName componentsSeparatedByString:@"."] objectAtIndex:0];
    NSEntityDescription *entity = [NSEntityDescription entityForName:[self itemEntityName] inManagedObjectContext:[self managedObjectContext]];
    isToMany = [[[entity relationshipsByName] objectForKey:firstKey] isToMany];
    
    [self refresh];
}

- (NSString *)groupImageName {  
    // TODO: add new icon
    return @"SmartGroupIcon";
}

- (BOOL)isSmart {
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
        if (entityName == nil || propertyName == nil) 
            return children;
        
        NSManagedObjectContext *moc = [self managedObjectContext];
        NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:moc];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSError *error = nil;
        NSArray *results = nil;
        
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
        
        while (value = [valueEnum nextObject]) {
            child = [NSEntityDescription insertNewObjectForEntityForName:SmartGroupEntityName inManagedObjectContext:moc];
            [child setValue:entityName forKey:@"itemEntityName"];
            [child setValue:value forKey:@"name"];
            [child setValue:[NSNumber numberWithBool:NO] forKey:@"canEdit"];
            [child setPredicate:[NSPredicate predicateWithFormat:predicateFormat, propertyName, value]];
            [children addObject:child];
        }
    }
    return children;
}

- (void)setChildren:(NSSet *)newChildren  {
    // noop   
}

@end

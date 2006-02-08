// 
//  BDSKSmartGroup.m
//  bd2xtest
//
//  Created by Christiaan Hofman on 2/4/06.
//  Copyright 2006. All rights reserved.
//

#import "BDSKSmartGroup.h"


@implementation BDSKSmartGroup 

- (void)commonAwake {
    [super commonAwake];
    
    items = nil;
    
    [self willAccessValueForKey:@"priority"];
    [self setValue:[NSNumber numberWithInt:2] forKeyPath:@"priority"];
    [self didAccessValueForKey:@"priority"];
}

- (void)awakeFromInsert  {
    [super awakeFromInsert];
    [self setPredicate:[NSPredicate predicateWithValue:YES]];
}

- (void)didTurnIntoFault {
    [items release];
    items = nil;
    [fetchRequest release];
    fetchRequest = nil;
    [predicate release];
    predicate = nil;
    
    [super didTurnIntoFault];
}

- (void)refresh {
	[self willChangeValueForKey:@"items"];
	[items release];
    items = nil;    
	[self didChangeValueForKey:@"items"];
}

- (void)managedObjectContextObjectsDidChange:(NSNotification *)notification {
	NSEnumerator *enumerator;
	id object;
	BOOL refresh = NO;
	
	NSEntityDescription *entity = [[self fetchRequest] entity];
	
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

- (NSFetchRequest *)fetchRequest  {
    if ( fetchRequest == nil ) {
        NSString *entityName = [self itemEntityName];
        fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity: [NSEntityDescription entityForName:entityName inManagedObjectContext:[self managedObjectContext]]];
        [fetchRequest setPredicate:[self predicate]];
    }
    return fetchRequest;
}

- (NSPredicate *)predicate {
    NSData *predicateData;
    if (predicate == nil) {
        predicateData = [self valueForKey:@"predicateData"];
        if (predicateData != nil) {
            predicate = [(NSPredicate *)[NSKeyedUnarchiver unarchiveObjectWithData:predicateData] retain];
        }
    }
    return predicate;
}

- (void)setPredicate: (NSPredicate *)newPredicate {
    if (predicate != newPredicate)  {
        [predicate autorelease];
        if (newPredicate == nil) {
            newPredicate = [NSPredicate predicateWithValue:YES];
        }
        predicate = [newPredicate retain];
		NSData *predicateData = [NSKeyedArchiver archivedDataWithRootObject:predicate];
        [self setValue: predicateData forKey: @"predicateData"];
        [[self fetchRequest] setPredicate:predicate];
		[self refresh];
    }
}

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
    [[self fetchRequest] setEntity:[NSEntityDescription entityForName:entityName inManagedObjectContext:[self managedObjectContext]]];
    [self setPredicate:[NSPredicate predicateWithValue:YES]];
}


- (void)setGroupImageName:(NSString *)imageName {
    if (![groupImageName isEqualToString:imageName]) {
        [groupImageName release];
        groupImageName = [imageName retain];
        [cachedIcon release];
        cachedIcon = nil;
    }
}

- (NSString *)groupImageName {
    return (groupImageName != nil) ? groupImageName : @"SmartGroupIcon";
}

- (BOOL)isSmart {
    return YES;
}

- (NSSet *)items {
    if (items == nil)  {
        NSError *error = nil;
        NSArray *results = nil;
        @try {  results = [[self managedObjectContext] executeFetchRequest:[self fetchRequest] error:&error];  }
        @catch ( NSException *e ) {  /* no-op */ }
        items = ( error != nil || results == nil) ? [[NSSet alloc] init] : [[NSSet alloc] initWithArray:results];
    }
    return items;
}

- (void)setItems:(NSSet *)newRecipes  {
    // noop   
}


@end

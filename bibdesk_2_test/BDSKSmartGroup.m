// 
//  BDSKSmartGroup.m
//  bd2xtest
//
//  Created by Christiaan Hofman on 2/4/06.
//  Copyright 2006. All rights reserved.
//

#import "BDSKSmartGroup.h"


@implementation BDSKSmartGroup 

+ (void)initialize {
    // we need to call super's implementation, even though the docs say not to, because otherwise we loose dependent keys
    [super initialize]; 
    [self setKeys:[NSArray arrayWithObjects:@"predicateData", @"itemEntityName", nil]
        triggerChangeNotificationsForDependentKey:@"fetchRequest"];
    [self setKeys:[NSArray arrayWithObjects:@"fetchRequest", nil]
        triggerChangeNotificationsForDependentKey:@"items"];
}

- (id)initWithEntity:(NSEntityDescription*)entity insertIntoManagedObjectContext:(NSManagedObjectContext*)context{
	if (self = [super initWithEntity:entity insertIntoManagedObjectContext:context]) {
		canEdit = YES;
        canEditName = YES;
        
        [self addObserver:self forKeyPath:@"fetchRequest" options:0 context:NULL];
	}
	return self;
}

- (void)dealloc{
    [self removeObserver:self forKeyPath:@"fetchRequest"];
    
	[super dealloc];
}


- (void)commonAwake {
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(managedObjectContextObjectsDidChange:) 
                                                 name:NSManagedObjectContextObjectsDidChangeNotification 
                                               object:[self managedObjectContext]];        
    
    items = nil;
    
    [self willAccessValueForKey:@"priority"];
    [self setValue:[NSNumber numberWithInt:2] forKeyPath:@"priority"];
    [self didAccessValueForKey:@"priority"];
}

- (void)awakeFromInsert  {
    [super awakeFromInsert];
    [self commonAwake];
    [self setPredicate:[NSPredicate predicateWithValue:YES]];
}

- (void)awakeFromFetch {
    [super awakeFromFetch];
    [self commonAwake];
}

- (void)didTurnIntoFault {
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:NSManagedObjectContextObjectsDidChangeNotification 
                                                  object:[self managedObjectContext]];
	
    [items release];
    items = nil;
    
    [super didTurnIntoFault];
}

- (void)refresh {
	[self willChangeValueForKey:@"items"];
	[items release];
    items = nil;
	[self didChangeValueForKey:@"items"];
}

- (void)managedObjectContextObjectsDidChange:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSMutableSet *modifiedObjects = [NSMutableSet set];
	
	[modifiedObjects unionSet:[userInfo objectForKey:NSUpdatedObjectsKey]];
	[modifiedObjects unionSet:[userInfo objectForKey:NSInsertedObjectsKey]];
	[modifiedObjects unionSet:[userInfo objectForKey:NSDeletedObjectsKey]];
	
    // TODO: can depend on other entities through relationships
    NSEntityDescription *entity = [NSEntityDescription entityForName:[self itemEntityName] inManagedObjectContext:[self managedObjectContext]];
	NSEnumerator *enumerator = [modifiedObjects objectEnumerator];	
	id object;
	BOOL refresh = NO;
	
	while (object = [enumerator nextObject]) {
		if ([object entity] == entity) {
			refresh = YES;
            break;
		}
	}
	    
    if (refresh == NO && [modifiedObjects count] == 0) {
        refresh = YES;
    }
	
    if (refresh) {
		[self refresh];
    }
}

#pragma mark Accessors

- (NSFetchRequest *)fetchRequest  {
    NSFetchRequest *fetchRequest;
    [self willAccessValueForKey:@"fetchRequest"];
    fetchRequest = [self primitiveValueForKey:@"fetchRequest"];
    [self didAccessValueForKey:@"fetchRequest"];
    
    if (fetchRequest == nil) {
        NSString *entityName = [self itemEntityName];
        NSData *predicateData = [self valueForKey:@"predicateData"];
        fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
        [fetchRequest setEntity: [NSEntityDescription entityForName:entityName inManagedObjectContext:[self managedObjectContext]]];
        if (predicateData != nil) {
            [fetchRequest setPredicate:[NSKeyedUnarchiver unarchiveObjectWithData:predicateData]];
        }
        [self setPrimitiveValue:fetchRequest forKey:@"fetchRequest"];
    }
    
    return fetchRequest;
}

- (NSPredicate *)predicate {
    return [[self fetchRequest] predicate];
}

- (void)setPredicate:(NSPredicate *)newPredicate {
    [[self fetchRequest] setPredicate:newPredicate];
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
    
    NSFetchRequest *fetchRequest = [self fetchRequest];
    [fetchRequest setEntity:[NSEntityDescription entityForName:entityName inManagedObjectContext:[self managedObjectContext]]];
    [fetchRequest setPredicate:[NSPredicate predicateWithValue:YES]];
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

- (BOOL)canEdit {
    return canEdit;
}

- (void)setCanEdit:(BOOL)flag {
    canEdit = flag;
}

- (BOOL)canEditName {
    return canEditName;
}

- (void)setCanEditName:(BOOL)flag {
    canEditName = flag;
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

- (void)setItems:(NSSet *)newItems  {
    // noop   
}

- (NSSet *)itemsInSelfOrChildren {
    return [self items];
}

- (void)setItemsInSelfOrChildren:(NSSet *)newItems {
    // noop   
}

- (NSSet *)children {
    return [NSSet set];
}

- (void)setChildren:(NSSet *)newChildren  {
    // noop
}

- (void)willSave {
    NSPredicate *predicate = [[self primitiveValueForKey:@"fetchRequest"] predicate];
    NSData *predicateData = nil;
    
    if (predicate != nil) {
        predicateData = [NSKeyedArchiver archivedDataWithRootObject:predicate];
    }
    [self setPrimitiveValue:predicateData forKey:@"predicateData"];
    
    [super willSave];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"fetchRequest"]) {
        [self refresh];
    }
}

@end


@implementation BDSKLibraryGroup 

- (BOOL)isRoot {
    return YES;
}

- (BOOL)canEdit {
    return NO;
}

- (BOOL)canEditName {
    return NO;
}

- (NSString *)groupImageName {
    return (groupImageName != nil) ? groupImageName : @"RootGroupIcon";
}

@end

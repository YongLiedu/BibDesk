// 
//  BDSKGroup.m
//  bd2xtest
//
//  Created by Christiaan Hofman on 4/2/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "BDSKGroup.h"


@implementation BDSKGroup 

+ (void)initialize {
    [self setKeys:[NSArray arrayWithObjects:@"items", @"children", nil] 
        triggerChangeNotificationsForDependentKey:@"itemsInSelfOrChildren"];
    [self setKeys:[NSArray arrayWithObjects:@"name", @"groupImageName", nil] 
        triggerChangeNotificationsForDependentKey:@"nameAndIcon"];
    [self setKeys:[NSArray arrayWithObjects:@"groupImageName", nil] 
        triggerChangeNotificationsForDependentKey:@"icon"];
}

- (void)commonAwake {
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(managedObjectContextObjectsDidChange:) 
                                                 name:NSManagedObjectContextObjectsDidChangeNotification 
                                               object:[self managedObjectContext]];        
}

- (void)awakeFromInsert  {
    [super awakeFromInsert];
    [self commonAwake];
}

- (void)awakeFromFetch  {
    [super awakeFromFetch];
    [self commonAwake];
}

- (void)didTurnIntoFault {
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:NSManagedObjectContextObjectsDidChangeNotification 
                                                  object:[self managedObjectContext]];

    [cachedIcon release];
    cachedIcon = nil;
    
    [super didTurnIntoFault];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:NSManagedObjectContextObjectsDidChangeNotification 
                                                  object:[self managedObjectContext]];

    [cachedIcon release];
    [super dealloc];
}

- (void)managedObjectContextObjectsDidChange:(NSNotification *)notification {
    if ([self isSmart])
        return;
    
	NSEnumerator *enumerator;
	id object;
	BOOL refresh = NO;
    
	NSSet *deleted = [[notification userInfo] objectForKey:NSDeletedObjectsKey];
    NSMutableSet *items = [self mutableSetValueForKey:@"items"];
    
	enumerator = [deleted objectEnumerator];	
	while ((refresh == NO) && (object = [enumerator nextObject])) {
		if ([items containsObject:object]) {
			refresh = YES;	
		}
	}
    if (refresh) {
		[items minusSet:deleted];
    }
}

- (NSString *)groupImageName {
    return @"GroupIcon";
}

- (NSImage *)icon{
    if (cachedIcon == nil && [self groupImageName] != nil) {
        cachedIcon = [[NSImage imageNamed:[self groupImageName]] copy];
        [cachedIcon setScalesWhenResized:YES];
        [cachedIcon setSize:NSMakeSize(16, 16)];
    }
    return cachedIcon;
}

- (NSDictionary *)nameAndIcon{
    return [NSDictionary dictionaryWithObjectsAndKeys:[self valueForKey:@"name"], @"name", [self valueForKey:@"icon"], @"icon", nil];
}

- (void)setNameAndIcon:(NSString *)name{
    [self setValue:name forKey:@"name"];
}

- (BOOL)isSmart {
    return NO;
}

- (NSString *)itemEntityName {
    // implemented by subclass
    return nil;
}

- (NSSet *)itemsInSelfOrChildren {
    if ([self isSmart])
        return [self valueForKey:@"items"];
    
    NSMutableSet *myPubs = [NSMutableSet setWithCapacity:10];
    [myPubs unionSet:[self valueForKey:@"items"]];
    
    NSSet *children = [self valueForKey:@"children"];
    NSEnumerator *childE = [children objectEnumerator];
    id child = nil;
    while (child = [childE nextObject]) {
        if ([child isSmart] == NO)
            [myPubs unionSet:[child valueForKey:@"itemsInSelfOrChildren"]];
    }
    return myPubs;
}

- (void)addItemsInSelfOrChildrenObject:(id)obj {
    if ([self isSmart])
        return;
    [[self mutableSetValueForKey:@"items"] addObject:obj];
}

- (void)removeItemsInSelfOrChildrenObject:(id)obj {
    if ([self isSmart])
        return;
    [[self mutableSetValueForKey:@"items"] removeObject:obj];
}

@end

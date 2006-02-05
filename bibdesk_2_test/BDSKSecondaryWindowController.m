//
//  BDSKSecondaryWindowController.m
//  bd2
//
//  Created by Christiaan Hofman on 1/29/06.
//  Copyright 2006 Christiaan Hofman. All rights reserved.
//

#import "BDSKSecondaryWindowController.h"
#import "BDSKTableDisplayController.h"
#import "BDSKGroup.h"
#import "BDSKDataModelNames.h"

#import "BDSKPublicationTableDisplayController.h" // @@ TODO: itemdisplayflex this should be temporary
#import "BDSKNoteTableDisplayController.h" // @@ TODO: itemdisplayflex this should be temporary


@implementation BDSKSecondaryWindowController

- (id)initWithWindowNibName:(NSString *)windowNibName{
    if (self = [super initWithWindowNibName:windowNibName]){
        displayControllersInfoDict = [[NSDictionary alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DisplayControllers" ofType:@"plist"]];
        displayControllers = [[NSMutableArray alloc] initWithCapacity:10];
        currentDisplayControllerForEntity = [[NSMutableDictionary alloc] initWithCapacity:10];
		sourceGroup = nil;
    }
    
    return self;
}

- (void)awakeFromNib{
    
    [self setupDisplayControllers];
	
	NSString *entityClassName = [[self sourceGroup] itemEntityName];
	if (entityClassName != nil) {
		BDSKTableDisplayController *newDisplayController = [currentDisplayControllerForEntity objectForKey:entityClassName];
		if (newDisplayController != currentDisplayController){
			[self unbindDisplayController:currentDisplayController];
			[self setDisplayController:newDisplayController];
		}
	}
}

- (void)dealloc{
    [displayControllers release];
    [currentDisplayControllerForEntity release];        
    [displayControllersInfoDict release];
	[sourceGroup release];
    [super dealloc];
}

-(void)windowDidLoad{ 
}

- (void)windowWillClose:(NSNotification *)notification{
	[[self document] removeWindowController:self];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName{
	NSString *groupName = [[self sourceGroup] valueForKeyPath:@"name"];
	if (groupName != nil) {
		return [NSString stringWithFormat:@"%@ - %@", displayName, groupName];
	}
	return [super windowTitleForDocumentDisplayName:displayName];
}

#pragma mark Accessors

- (BDSKGroup *)sourceGroup{
	return sourceGroup;
}

// this cannot be called after the display controller has been bound, due to binding issues.
- (void)setSourceGroup:(BDSKGroup *)newSourceGroup{
	if (newSourceGroup != sourceGroup) {
		
		NSString *oldEntityClassName = [sourceGroup itemEntityName];
		NSString *newEntityClassName = [newSourceGroup itemEntityName];
		BDSKTableDisplayController *newDisplayController = nil;
		BOOL shouldChangeDisplayController = NO;
		
		if ([newEntityClassName isEqualToString:oldEntityClassName] == NO) {
			newDisplayController = [currentDisplayControllerForEntity objectForKey:newEntityClassName];
			if (newDisplayController != currentDisplayController){
				[self unbindDisplayController:currentDisplayController];
				shouldChangeDisplayController = YES;
			}
		}
		
		[sourceGroup autorelease];
		sourceGroup = [newSourceGroup retain];
		
		if (shouldChangeDisplayController == YES)
			[self setDisplayController:newDisplayController];
	}
}

- (NSArray *)displayControllers{
	return displayControllers;
}

// TODO: this is totally incomplete.
- (NSArray *)displayControllersForCurrentType{
    NSSet* currentTypes = nil; // temporary, removed treecontroller.
    NSLog(@"displayControllersForCurrentType - currentTypes is %@.", currentTypes);
    
    return [NSArray arrayWithObjects:currentDisplayController, nil];
}

- (void)setDisplayController:(id)newDisplayController{
    if(newDisplayController != currentDisplayController){
        [currentDisplayController autorelease];
        if(currentDisplayController)
            [self unbindDisplayController:currentDisplayController];
        
        [[newDisplayController view] setFrame:[currentDisplayView frame]];
        [[currentDisplayView superview] replaceSubview:currentDisplayView with:[newDisplayController view]];

        currentDisplayView = [newDisplayController view];
        currentDisplayController = [newDisplayController retain];
        [self bindDisplayController:currentDisplayController];
    }
}


#pragma mark Display Controller management

- (void)setupDisplayControllers{
    
    NSArray *displayControllerClassNames = [displayControllersInfoDict allKeys];
    NSEnumerator *displayControllerClassNameE = [displayControllerClassNames objectEnumerator];
    NSString *displayControllerClassName = nil;
    
    while (displayControllerClassName = [displayControllerClassNameE nextObject]){
        Class controllerClass = NSClassFromString(displayControllerClassName);
        BDSKTableDisplayController *controllerObject = [[controllerClass alloc] init];
        [controllerObject setDocument:[self document]];
        [displayControllers addObject:controllerObject];

        NSDictionary *infoDict = [displayControllersInfoDict objectForKey:displayControllerClassName];
           
        //TODO: for now we have a 1:1 between DCs and entity names. 
        // this code will need to get smarter when that changes.
        NSString *displayableEntity = [[infoDict objectForKey:@"DisplayableEntities"] objectAtIndex:0];
        [currentDisplayControllerForEntity setObject:controllerObject
                                              forKey:displayableEntity];
    }
    
}


- (void)bindDisplayController:(id)displayController{
    // TODO: bind to a particular group
	// Not binding the contentSet will get all the managed objects for the entity
	// Binding contentSet will not update a dynamic smart group
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], NSRaisesForNotApplicableKeysBindingOption, [NSNumber numberWithBool:YES], NSConditionallySetsEnabledBindingOption, [NSNumber numberWithBool:YES], NSDeletesObjectsOnRemoveBindingsOption, nil];
    // TODO: in future, this should create multiple bindings.?    
    [[displayController itemsArrayController] bind:@"contentSet" toObject:self
                                       withKeyPath:@"sourceGroup.itemsInSelfOrChildren" options:options];
    
}


// TODO: as the above method creates multiple bindings, this one will have to keep up.
// mb the display controllers themselves should be 
- (void)unbindDisplayController:(id)displayController{
	[[displayController itemsArrayController] unbind:@"contentSet"];
}


#pragma mark Actions

- (IBAction)addNewItem:(id)sender{
    NSManagedObject *obj = [self sourceGroup];
    NSString *entityName = [[obj entity] name];

    NSLog(@"entityName in addNewItemFrom is %@, obj is %@", entityName, obj);
    
    if ([entityName isEqualToString:PublicationGroupEntityName]){
        [self addNewPublicationToContainer:obj];
    }
    if ([entityName isEqualToString:NoteGroupEntityName]){
        [self addNewNoteToContainer:obj];
    }
    if ([entityName isEqualToString:PersonGroupEntityName]){
        [self addNewPersonToContainer:obj];
    }
    if ([entityName isEqualToString:SmartGroupEntityName]){
        if ([[obj valueForKey:@"isRoot"] boolValue] == YES)
            [self addNewItemToRootContainer:obj];
        else
            NSBeep();
    }
    else NSBeep();
}

- (void)addNewPublicationToContainer:(id)container{
    NSManagedObjectContext *managedObjectContext = [[self document] managedObjectContext];
    NSManagedObject *newPublication = [NSEntityDescription insertNewObjectForEntityForName:PublicationEntityName
                                           inManagedObjectContext:managedObjectContext];
    
    NSMutableSet *publications = [container mutableSetValueForKey:@"items"];
    [publications addObject:newPublication];
}

- (void)addNewPersonToContainer:(id)container{
    NSManagedObjectContext *managedObjectContext = [[self document] managedObjectContext];
    NSManagedObject *newPerson = [NSEntityDescription insertNewObjectForEntityForName:PersonEntityName
                                               inManagedObjectContext:managedObjectContext];

    NSMutableSet *people = [container mutableSetValueForKey:@"items"];
    [people addObject:newPerson];
}

- (void)addNewNoteToContainer:(id)container{
    NSManagedObjectContext *managedObjectContext = [[self document] managedObjectContext];
    NSManagedObject *newNote = [NSEntityDescription insertNewObjectForEntityForName:NoteEntityName
                                               inManagedObjectContext:managedObjectContext];
    
    NSMutableSet *notes = [container mutableSetValueForKey:@"items"];
    [notes addObject:newNote];
}

- (void)addNewItemToRootContainer:(id)container{
    NSManagedObjectContext *managedObjectContext = [[self document] managedObjectContext];
    [NSEntityDescription insertNewObjectForEntityForName:[container valueForKey:@"itemEntityName"]
                                  inManagedObjectContext:managedObjectContext];
}

@end

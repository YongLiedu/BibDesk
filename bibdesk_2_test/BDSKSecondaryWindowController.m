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

+ (void)initialize{
   [self setKeys:[NSArray arrayWithObject:@"document"] triggerChangeNotificationsForDependentKey:@"managedObjectContext"];
}

- (id)initWithWindowNibName:(NSString *)windowNibName{
    if (self = [super initWithWindowNibName:windowNibName]){
        NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DisplayControllers" ofType:@"plist"]];
        displayControllersInfoDict = [[infoDict objectForKey:@"TableDisplayControllers"] retain];
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
		BDSKTableDisplayController *newDisplayController = [self displayControllerForEntityName:entityClassName];
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
    [self setDisplayController:nil]; // needed to remove the bindings in the displayController
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName{
	NSString *groupName = [[self sourceGroup] valueForKeyPath:@"name"];
	if (groupName != nil) {
		return [NSString stringWithFormat:@"%@ - %@", displayName, groupName];
	}
	return [super windowTitleForDocumentDisplayName:displayName];
}

#pragma mark Accessors

- (NSManagedObjectContext *)managedObjectContext {
	return [[self document] managedObjectContext];
}

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
			newDisplayController = [self displayControllerForEntityName:newEntityClassName];
			if (newDisplayController != currentDisplayController){
				[self unbindDisplayController:currentDisplayController];
				shouldChangeDisplayController = YES;
			}
		}
		
		[sourceGroup autorelease];
		sourceGroup = [newSourceGroup retain];
		
		if (shouldChangeDisplayController == YES)
			[self setDisplayController:newDisplayController];
        
        [currentDisplayController setEditable:[sourceGroup canAddItems]];
	}
}

- (id)displayController{
    return currentDisplayController;
}

- (void)setDisplayController:(id)newDisplayController{
    if(newDisplayController != currentDisplayController){
        [currentDisplayController autorelease];
        if(currentDisplayController)
            [self unbindDisplayController:currentDisplayController];
        
        NSView *view = [newDisplayController view];
        if (view == nil) 
            view = [[[NSView alloc] init] autorelease];
        [view setFrame:[currentDisplayView frame]];
        [[currentDisplayView superview] replaceSubview:currentDisplayView with:view];
        currentDisplayView = view;
        currentDisplayController = [newDisplayController retain];
        [currentDisplayController setItemEntityName:[sourceGroup itemEntityName]];
        [self bindDisplayController:currentDisplayController];
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
        [controllerObject release];

        NSDictionary *infoDict = [displayControllersInfoDict objectForKey:displayControllerClassName];
           
        //TODO: for now we have a 1:1 between DCs and entity names. 
        // this code will need to get smarter when that changes.
        NSString *displayableEntity = [[infoDict objectForKey:@"DisplayableEntities"] objectAtIndex:0];
        [currentDisplayControllerForEntity setObject:controllerObject
                                              forKey:displayableEntity];
    }
    
}

- (id)displayControllerForEntityName:(NSString *)entityName{
    NSManagedObjectContext *context = [self managedObjectContext];
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:context];
    id displayController = nil;
    
    while (displayController == nil && entity != nil) {
        displayController = [currentDisplayControllerForEntity objectForKey:[entity name]];
        entity = [entity superentity];
    }
    return displayController;
}

- (void)bindDisplayController:(id)displayController{
	// Not binding the contentSet will get all the managed objects for the entity
	// Binding contentSet will not update a dynamic smart group
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], NSRaisesForNotApplicableKeysBindingOption, [NSNumber numberWithBool:YES], NSConditionallySetsEnabledBindingOption, [NSNumber numberWithBool:YES], NSDeletesObjectsOnRemoveBindingsOption, nil];
    // TODO: in future, this should create multiple bindings.?    
    [[displayController itemsArrayController] bind:@"contentSet" toObject:self
                                       withKeyPath:@"sourceGroup.items" options:options];
    // TODO: in future, this should create multiple bindings.?    
    
    NSArray *filterPredicates = [displayController filterPredicates];
    int i, count = [filterPredicates count];
    NSString *key = @"predicate";
    for (i = 0; i < count; i++) {
        if (i > 0) 
            key = [NSString stringWithFormat:@"predicate%i", i+1];
        options = [filterPredicates objectAtIndex:i];
        [searchField bind:key toObject:[displayController itemsArrayController]
                           withKeyPath:@"filterPredicate" options:options];
    }
}


// TODO: as the above method creates multiple bindings, this one will have to keep up.
// mb the display controllers themselves should be 
- (void)unbindDisplayController:(id)displayController{
    int i = [[displayController filterPredicates] count];
    NSString *key;
    while (i-- > 0) {
        key = (i == 0) ? @"predicate" : [NSString stringWithFormat:@"predicate%i", i+1];
        [searchField unbind:key];
    }
	[[displayController itemsArrayController] unbind:@"contentSet"];
}


#pragma mark Actions

- (IBAction)addNewItem:(id)sender{
    BDSKGroup *selectedGroup = [self sourceGroup];
    if (NSIsControllerMarker(selectedGroup) || [selectedGroup canAddItems] == NO) {
        NSBeep();
        return;
    }
    
    [currentDisplayController addItem];
}

- (IBAction)removeSelectedItems:(id)sender {
    BDSKGroup *selectedGroup = [self sourceGroup];
    NSArray *selectedItems = [[currentDisplayController itemsArrayController] selectedObjects];
    if (NSIsControllerMarker(selectedItems) || NSIsControllerMarker(selectedGroup) || [selectedGroup canAddItems] == NO) {
        NSBeep();
        return;
    }
    
    [currentDisplayController removeItems:selectedItems];
}

- (IBAction)delete:(id)sender {
    id firstResponder = [[self window] firstResponder];
    if ([firstResponder isKindOfClass:[NSText class]] && [firstResponder isFieldEditor])
        firstResponder = [firstResponder delegate];
    if (firstResponder == [currentDisplayController itemsTableView]) {
        [self removeSelectedItems:sender];
    } else {
        NSBeep();
    }
}

@end

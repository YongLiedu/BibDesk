//
//  BDSKMainWindowController.m
//  bd2
//
//  Created by Michael McCracken on 6/16/05.
//  Copyright 2005 Michael McCracken. All rights reserved.
//

#import "BDSKMainWindowController.h"


@implementation BDSKMainWindowController

- (id)initWithWindowNibName:(NSString *)windowNibName{
    if (self = [super initWithWindowNibName:windowNibName]){
        topLevelSourceListItems = [[NSMutableArray alloc] initWithCapacity:5];
        displayControllersInfoDict = [[NSDictionary alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DisplayControllers" ofType:@"plist"]];
        displayControllers = [[NSMutableArray alloc] initWithCapacity:10];
        currentDisplayControllerForEntity = [[NSMutableDictionary alloc] initWithCapacity:10];
    }
    
    return self;
}

- (void)awakeFromNib{
    
    [self setupTopLevelSourceListItems];
    
    [self setupDisplayControllers];

    NSTableColumn *tc = [sourceList tableColumnWithIdentifier:@"mainColumn"];
    [tc setDataCell:[[[ImageAndTextCell alloc] init] autorelease]];
}

- (void)dealloc{
    [topLevelSourceListItems release];
    [displayControllers release];
    [currentDisplayControllerForEntity release];        
    [displayControllersInfoDict release];
    [super dealloc];
}

-(void)windowDidLoad{ 
    [self reloadSourceList];
    [sourceList selectRow:0 byExtendingSelection:NO]; //@@TODO: might want to store last row as a pref
}

#pragma mark Accessors

- (NSArray *)displayControllers{ return displayControllers;}

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
        
        [mainSplitView replaceSubview:currentDisplayView with:[newDisplayController view]];

        currentDisplayView = [newDisplayController view];
        currentDisplayController = [newDisplayController retain];
        [self bindDisplayController:currentDisplayController];
    }
}

#pragma mark Source List setup

- (void)reloadSourceList{
    [sourceList reloadData];
}


- (void)setupTopLevelSourceListItems{
    NSPredicate *rootItemPredicate = [NSPredicate predicateWithFormat:@"isRoot == YES"];
    
    NSManagedObjectContext *moc = [[self document] managedObjectContext];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setPredicate:rootItemPredicate];
    
    NSError *fetchError = nil;
    NSArray *fetchResults;
    
    @try {
        [fetchRequest setEntity:[NSEntityDescription entityForName:PublicationGroupEntityName
                                            inManagedObjectContext:moc]];
        fetchResults = [moc executeFetchRequest:fetchRequest error:&fetchError];
    } @catch (NSException *exception) {
        [fetchRequest release];
        [exception raise];
    }
    
    if ((fetchResults != nil) && ([fetchResults count] == 1) && (fetchError == nil)) {
        [topLevelSourceListItems addObject:[fetchResults objectAtIndex:0]];
    }
    
    if (fetchError != nil) {
        [self presentError:fetchError];
    }

    @try {
        [fetchRequest setEntity:[NSEntityDescription entityForName:PersonGroupEntityName
                                            inManagedObjectContext:moc]];
        fetchResults = [moc executeFetchRequest:fetchRequest error:&fetchError];

    } @catch(NSException *exception) {
        [fetchRequest release];
        [exception raise];
    }
    
    if ((fetchResults != nil) && ([fetchResults count] == 1) && (fetchError == nil)) {
        [topLevelSourceListItems addObject:[fetchResults objectAtIndex:0]];
    }
    
    if (fetchError != nil) {
        [self presentError:fetchError];
    }
  
    @try {
        [fetchRequest setEntity:[NSEntityDescription entityForName:NoteGroupEntityName
                                            inManagedObjectContext:moc]];
        fetchResults = [moc executeFetchRequest:fetchRequest error:&fetchError];
        
    } @catch(NSException *exception) {
        [fetchRequest release];
        [exception raise];
    }
    
    if ((fetchResults != nil) && ([fetchResults count] == 1) && (fetchError == nil)) {
        [topLevelSourceListItems addObject:[fetchResults objectAtIndex:0]];
    }
    
    if (fetchError != nil) {
        [self presentError:fetchError];
    }
    
    
}

#pragma mark Accessors

- (NSSet *)sourceListSelectedItems{
    id selectedGroup = [sourceList itemAtRow:[sourceList selectedRow]];
    return [selectedGroup valueForKey:@"items"];
}


#pragma mark Display Controller management

- (void)setupDisplayControllers{
    
    NSArray *displayControllerClassNames = [displayControllersInfoDict allKeys];
    NSEnumerator *displayControllerClassNameE = [displayControllerClassNames objectEnumerator];
    NSString *displayControllerClassName = nil;
    
    while (displayControllerClassName = [displayControllerClassNameE nextObject]){
        Class controllerClass = NSClassFromString(displayControllerClassName);
        id controllerObject = [[controllerClass alloc] init];
        [controllerObject setDocument:[self document]];
        [displayControllers addObject:controllerObject];

        NSDictionary *infoDict = [displayControllersInfoDict objectForKey:displayControllerClassName];
           
        //TODO: for now we have a 1:1 between DCs and entity names. 
        // this code will need to get smarter when that changes.
        NSString *displayableClass = [[infoDict objectForKey:@"DisplayableClasses"] objectAtIndex:0];
        [currentDisplayControllerForEntity setObject:controllerObject
                                              forKey:displayableClass];
    }
    
}


- (void)bindDisplayController:(id)displayController{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], NSRaisesForNotApplicableKeysBindingOption, [NSNumber numberWithBool:YES], NSConditionallySetsEnabledBindingOption, nil];
    // TODO: in future, this should create multiple bindings.?    
    [[displayController itemsArrayController] bind:@"contentSet" toObject:self
                                       withKeyPath:@"sourceListSelectedItems" options:options];
    
}


// TODO: as the above method creates multiple bindings, this one will have to keep up.
// mb the display controllers themselves should be 
- (void)unbindDisplayController:(id)displayController{
    [[displayController itemsArrayController] unbind:@"contentSet"];
}


#pragma mark Actions

- (IBAction)addNewGroupFromSourceListSelection:(id)sender{
    id obj = [sourceList itemAtRow:[sourceList selectedRow]];
    NSString *entityName = [[obj entity] name];
        
    if ([entityName isEqualToString:@"PublicationGroup"]){
        [self addNewPublicationGroupToContainer:obj];
        [self reloadSourceList];
        return;
    }
    if ([entityName isEqualToString:@"NoteGroup"]){
        [self addNewNoteGroupToContainer:obj];
        [self reloadSourceList];
        return;
    }
    if ([entityName isEqualToString:@"PersonGroup"]){
        [self addNewPersonGroupToContainer:obj]; 
        [self reloadSourceList];
        return;
    }
    else NSBeep();
}

- (IBAction)addNewItemFromSourceListSelection:(id)sender{
    id obj = [sourceList itemAtRow:[sourceList selectedRow]];
    NSString *entityName = [[obj entity] name];

    NSLog(@"entityName in addNewItemFrom is %@, obj is %@", entityName, obj);
    
    if ([entityName isEqualToString:@"PublicationGroup"]){
        [self addNewPublicationToContainer:obj];
        [self reloadSourceList];
        return;
    }
    if ([entityName isEqualToString:@"NoteGroup"]){
        [self addNewNoteToContainer:obj];
        [self reloadSourceList];
        return;
    }
    if ([entityName isEqualToString:@"PersonGroup"]){
        [self addNewPersonToContainer:obj];
        [self reloadSourceList];
        return;
    }
    else NSBeep();
}

- (IBAction)addNewPublicationToContainer:(id)container{
    NSManagedObjectContext *managedObjectContext = [[self document] managedObjectContext];
    id newPublication = [NSEntityDescription insertNewObjectForEntityForName:PublicationEntityName
                                           inManagedObjectContext:managedObjectContext];
    
    NSMutableSet *publications = [container mutableSetValueForKey:@"items"];
    [self willChangeValueForKey:@"sourceListSelectedItems"];    
    [publications addObject:newPublication];
    [self didChangeValueForKey:@"sourceListSelectedItems"];
}

- (IBAction)addNewPublicationGroupToContainer:(id)container{
    NSManagedObjectContext *managedObjectContext = [[self document] managedObjectContext];
    id newPublicationGroup = [NSEntityDescription insertNewObjectForEntityForName:PublicationGroupEntityName
                                                  inManagedObjectContext:managedObjectContext];
    
    [newPublicationGroup setValue:@"Untitled Publication Group" forKey:@"name"];

    NSMutableSet *children = [container mutableSetValueForKey:@"children"];
    [children addObject:newPublicationGroup];
}


- (IBAction)addNewNoteToContainer:(id)container{
    NSManagedObjectContext *managedObjectContext = [[self document] managedObjectContext];
    id newNote = [NSEntityDescription insertNewObjectForEntityForName:NoteEntityName
                                               inManagedObjectContext:managedObjectContext];
    
    NSMutableSet *notes = [container mutableSetValueForKey:@"items"];
    [self willChangeValueForKey:@"sourceListSelectedItems"];
    [notes addObject:newNote];
    [self didChangeValueForKey:@"sourceListSelectedItems"];
}

- (IBAction)addNewNoteGroupToContainer:(id)container{
    NSManagedObjectContext *managedObjectContext = [[self document] managedObjectContext];
    id newNoteGroup = [NSEntityDescription insertNewObjectForEntityForName:NoteGroupEntityName
                                                 inManagedObjectContext:managedObjectContext];
    
    [newNoteGroup setValue:@"Untitled Note Group" forKey:@"name"];

    NSMutableSet *children = [container mutableSetValueForKey:@"children"];
    [children addObject:newNoteGroup];
}

- (IBAction)addNewPersonToContainer:(id)container{
    NSManagedObjectContext *managedObjectContext = [[self document] managedObjectContext];
    id newPerson = [NSEntityDescription insertNewObjectForEntityForName:PersonEntityName
                                               inManagedObjectContext:managedObjectContext];

    NSMutableSet *people = [container mutableSetValueForKey:@"items"];
    [self willChangeValueForKey:@"sourceListSelectedItems"];
    [people addObject:newPerson];
    [self didChangeValueForKey:@"sourceListSelectedItems"];
}

- (IBAction)addNewPersonGroupToContainer:(id)container{
    NSManagedObjectContext *managedObjectContext = [[self document] managedObjectContext];
    id newPersonGroup = [NSEntityDescription insertNewObjectForEntityForName:PersonGroupEntityName
                                                    inManagedObjectContext:managedObjectContext];
    
    [newPersonGroup setValue:@"Untitled Person Group" forKey:@"name"];

    NSMutableSet *children = [container mutableSetValueForKey:@"children"];
    [children addObject:newPersonGroup];
}

#pragma mark Source List Outline View Delegate Methods and such


- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item{
    if (item == nil) {
        return [topLevelSourceListItems objectAtIndex:index];
    } else {
        return [[[item valueForKey:@"children"] allObjects] objectAtIndex:index];
    }
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item{
    if (item == nil) {
        return YES;
    }else{
        return [[item valueForKey:@"children"] count] > 0;
    }
}


- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item{
    if (item == nil) {
        return [topLevelSourceListItems count];
    }else{
        return [[item valueForKey:@"children"] count];
    }
}


- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item{
    if (item == nil) return nil;
    
    return [item valueForKey:@"name"];
}


- (void)outlineViewSelectionDidChange:(NSNotification *)notification{
    if ([notification object] != sourceList) return;
    
    id item = [sourceList itemAtRow:[sourceList selectedRow]];
    NSString *entityClassName = NSStringFromClass([item class]);
    id newDisplayController = [currentDisplayControllerForEntity objectForKey:entityClassName];
    
    [self willChangeValueForKey:@"sourceListSelectedItems"];
    if (newDisplayController != currentDisplayController){
        [self unbindDisplayController:currentDisplayController];
        [self setDisplayController:newDisplayController];
    }
    [self didChangeValueForKey:@"sourceListSelectedItems"];
}

- (void)outlineView:(NSOutlineView *)olv 
    willDisplayCell:(NSCell *)cell 
     forTableColumn:(NSTableColumn *)tableColumn
               item:(id)item {    
    
    if ([[tableColumn identifier] isEqualToString:@"mainColumn"]) {
        [(ImageAndTextCell*)cell setLeftImage:[item icon]];
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView 
shouldEditTableColumn:(NSTableColumn *)tableColumn 
               item:(id)item{
    if([[tableColumn identifier] isEqualToString:@"mainColumn"]){
        return ![item valueForKey:@"isRoot"];
    }else{
        return NO;
    }
    
}

//@@TODO: how to get new names if I can't enable editing?
- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item{
    NSLog(@"foo");
    return;
}

#pragma mark other file format stuff

// importing

// TODO: should this take an argument for the dictionary? what up there?
- (void)importUsingImporter:(id /*<BDSKImporter>*/)importer{
    // open a window using the importer's view 
    // save a ptr to the current importer.
}

- (IBAction)oneShotImportFromBibTeXFile:(id)sender{
    // open file chooser
    
    NSOpenPanel *op = [NSOpenPanel openPanel];
    [op runModalForDirectory:nil
                        file:@""];
    NSLog(@"import chose %@", [op filenames]);
    
    // [self importUsingImporter:[BDSKBibTeXImporter sharedImporter] ];
    
    // call into BDSKBibTeXParser stuff to get managed objects
    
    // insert into document's MOC
}

@end

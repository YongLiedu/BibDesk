//  BDSKDocument.m
//  bd2
//
//  Created by Michael McCracken on 5/14/05.
//  Copyright Michael McCracken 2005 . All rights reserved.

#import "BDSKDocument.h"

@implementation BDSKDocument

- (id)init{
    self = [super init];
    if (self != nil) {
        id rootGroup = [self rootPublicationGroup];
        [rootGroup setValue:@"RootGroupIcon" forKey:@"groupImageName"];
        rootGroup = [self rootPersonGroup];
        [rootGroup setValue:@"RootGroupIcon" forKey:@"groupImageName"];
        rootGroup = [self rootNoteGroup];
        [rootGroup setValue:@"RootGroupIcon" forKey:@"groupImageName"];
    }
    return self;
}

- (id)initWithType:(NSString *)typeName error:(NSError **)outError{
    // this method is invoked exactly once per document at the initial creation
    // of the document.  It will not be invoked when a document is opened after
    // being saved to disk.
    self = [super initWithType:typeName error:outError];
    if (self == nil)
        return nil;
    
    NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
    
	// first create the root groups
	// disable undo when we add them, so the document does not appear edited
	
    [[managedObjectContext undoManager] disableUndoRegistration];
	
    id pubGroup = [NSEntityDescription insertNewObjectForEntityForName:SmartGroupEntityName
                                                  inManagedObjectContext:managedObjectContext];
    [pubGroup setValue:[NSNumber numberWithBool:YES]
                forKey:@"isRoot"];
    [pubGroup setValue:NSLocalizedString(@"All Publications", @"Top level Publication group name")
                forKey:@"name"];
    [pubGroup setValue:PublicationEntityName
                forKey:@"itemEntityName"];
    [pubGroup setValue:[NSNumber numberWithShort:9]
                forKey:@"priority"];
    [pubGroup setValue:@"RootGroupIcon"
                forKey:@"groupImageName"];
    
    id personGroup = [NSEntityDescription insertNewObjectForEntityForName:SmartGroupEntityName
                                             inManagedObjectContext:managedObjectContext];
    [personGroup setValue:[NSNumber numberWithBool:YES]
                   forKey:@"isRoot"];
    [personGroup setValue:NSLocalizedString(@"All People", @"Top level Person group name")
                   forKey:@"name"];
    [personGroup setValue:PersonEntityName
                   forKey:@"itemEntityName"];
    [personGroup setValue:[NSNumber numberWithShort:8]
                   forKey:@"priority"];
    [personGroup setValue:@"RootGroupIcon"
                   forKey:@"groupImageName"];
    
    id noteGroup = [NSEntityDescription insertNewObjectForEntityForName:SmartGroupEntityName
                                             inManagedObjectContext:managedObjectContext];
    [noteGroup setValue:[NSNumber numberWithBool:YES]
                 forKey:@"isRoot"];
    [noteGroup setValue:NSLocalizedString(@"All Notes", @"Top level Note group name")
                 forKey:@"name"];
    [noteGroup setValue:NoteEntityName
                 forKey:@"itemEntityName"];
    [noteGroup setValue:[NSNumber numberWithShort:7]
                 forKey:@"priority"];
    [noteGroup setValue:@"RootGroupIcon"
                 forKey:@"groupImageName"];
    
    [managedObjectContext processPendingChanges];
    [[managedObjectContext undoManager] enableUndoRegistration];
    
    // temporary data set up with one relationship
    
    
    id pub = [NSEntityDescription insertNewObjectForEntityForName:PublicationEntityName
                                                 inManagedObjectContext:managedObjectContext];
    [pub setValue:@"Test Pub" forKey:@"title"];
    
    id note = [NSEntityDescription insertNewObjectForEntityForName:NoteEntityName
                                           inManagedObjectContext:managedObjectContext];
    [note setValue:@"Note1" forKey:@"name"];
    [note setValue:@"Value of note1" forKey:@"value"];
    [[pub mutableSetValueForKey:@"notes"] addObject:note];
    
    id tag1 = [NSEntityDescription insertNewObjectForEntityForName:TagEntityName
                                           inManagedObjectContext:managedObjectContext];
    [tag1 setValue:@"tagsRCool" forKey:@"name"];
    [[pub mutableSetValueForKey:@"tags"] addObject:tag1];
    
	
    id person1 = [NSEntityDescription insertNewObjectForEntityForName:PersonEntityName
                                              inManagedObjectContext:managedObjectContext];
    [person1 setValue:@"Blow" forKey:@"lastNamePart"];
    [person1 setValue:@"Joe" forKey:@"firstNamePart"];

    id person2 = [NSEntityDescription insertNewObjectForEntityForName:PersonEntityName
                                            inManagedObjectContext:managedObjectContext];
    [person2 setValue:@"Blow" forKey:@"lastNamePart"];
    [person2 setValue:@"John" forKey:@"firstNamePart"];
    
    id tag2 = [NSEntityDescription insertNewObjectForEntityForName:TagEntityName
                                           inManagedObjectContext:managedObjectContext];
    [tag2 setValue:@"JohnBlowGroup" forKey:@"name"];
    [[person2 mutableSetValueForKey:@"tags"] addObject:tag2];
    
    id relationship1 = [NSEntityDescription insertNewObjectForEntityForName:ContributorPublicationRelationshipEntityName
                                              inManagedObjectContext:managedObjectContext];
    [relationship1 setValue:@"author" forKey:@"relationshipType"];
    [relationship1 setValue:[NSNumber numberWithInt:0] forKey:@"index"];
    [relationship1 setValue:person1 forKey:@"contributor"];
    [relationship1 setValue:pub forKey:@"publication"];

    id contributorPublicationRelationships = [pub mutableSetValueForKey:@"contributorRelationships"];
    [contributorPublicationRelationships addObject:relationship1];
    
    id relationship2 = [NSEntityDescription insertNewObjectForEntityForName:ContributorPublicationRelationshipEntityName
                                                 inManagedObjectContext:managedObjectContext];
    [relationship2 setValue:@"author" forKey:@"relationshipType"];
    [relationship2 setValue:[NSNumber numberWithInt:1] forKey:@"index"];
    [relationship2 setValue:person2  forKey:@"contributor"];
    [relationship2 setValue:pub forKey:@"publication"];
    
    [contributorPublicationRelationships addObject:relationship2];
    
    id institution1 = [NSEntityDescription insertNewObjectForEntityForName:@"Institution" inManagedObjectContext:managedObjectContext];
    
    [institution1 setValue:@"Penn State" forKey:@"name"];
    
    id institution2 = [NSEntityDescription insertNewObjectForEntityForName:@"Institution" inManagedObjectContext:managedObjectContext];
    
    [institution2 setValue:@"UC San Diego" forKey:@"name"];
    
    
    id institutionRelationship1 = [NSEntityDescription insertNewObjectForEntityForName:PersonInstitutionRelationshipEntityName
                                                               inManagedObjectContext:managedObjectContext];
    [institutionRelationship1 setValue:@"phd student" forKey:@"relationshipType"];
    [institutionRelationship1 setValue:person1 forKey:@"person"];
    [institutionRelationship1 setValue:institution1 forKey:@"institution"];
    [institutionRelationship1 setValue:[NSDate dateWithNaturalLanguageString:@"8/30/1997"] forKey:@"startDate"];
    [institutionRelationship1 setValue:[NSDate dateWithNaturalLanguageString:@"4/1/2001"] forKey:@"endDate"];
        
    
    id institutionRelationship2 = [NSEntityDescription insertNewObjectForEntityForName:PersonInstitutionRelationshipEntityName
                                                               inManagedObjectContext:managedObjectContext];
    [institutionRelationship2 setValue:@"phd student" forKey:@"relationshipType"];
    [institutionRelationship2 setValue:person2 forKey:@"person"];
    [institutionRelationship2 setValue:institution2 forKey:@"institution"];

    [institutionRelationship2 setValue:[NSDate dateWithNaturalLanguageString:@"9/11/2001"] forKey:@"startDate"];
    
    
    return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void)makeWindowControllers{
    BDSKMainWindowController *mwc = [[BDSKMainWindowController alloc] initWithWindowNibName:@"BDSKMainWindow"];
	[mwc setShouldCloseDocument:YES];
    [self addWindowController:[mwc autorelease]];
}


- (void)windowControllerDidLoadNib:(NSWindowController *)windowController{
    [super windowControllerDidLoadNib:windowController];
    // user interface preparation code
}

- (NSManagedObject *)rootPublicationGroup{
	return [self rootGroupForEntityName:PublicationEntityName];
}

- (NSManagedObject *)rootPersonGroup{
	return [self rootGroupForEntityName:PersonEntityName];
}

- (NSManagedObject *)rootNoteGroup{
	return [self rootGroupForEntityName:NoteEntityName];
}

- (NSManagedObject *)rootGroupForEntityName:(NSString *)entityName{
    
    NSPredicate *rootItemPredicate = [NSPredicate predicateWithFormat:@"(isRoot == YES) AND (itemEntityName == %@)", entityName];
    NSManagedObjectContext *moc = [self managedObjectContext];
    NSFetchRequest *groupFetchRequest = [[NSFetchRequest alloc] init];

    [groupFetchRequest setPredicate:rootItemPredicate];
    
    NSError *fetchError = nil;
    NSArray *fetchResults;
    @try {
        NSEntityDescription *entity = [NSEntityDescription entityForName:SmartGroupEntityName
                                                  inManagedObjectContext:moc];
        [groupFetchRequest setEntity:entity];
        fetchResults = [moc executeFetchRequest:groupFetchRequest error:&fetchError];
    } @finally {
        [groupFetchRequest release];
    }
    if ((fetchResults != nil) && ([fetchResults count] == 1) && (fetchError == nil)) {
        
        return [fetchResults objectAtIndex:0];
    }
    if (fetchError != nil) {
        [self presentError:fetchError];
        return nil;
    }
    
    return nil;   
}

@end

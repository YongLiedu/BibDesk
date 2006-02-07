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
        rootGroup = [self rootInstitutionGroup];
        [rootGroup setValue:@"RootGroupIcon" forKey:@"groupImageName"];
        rootGroup = [self rootVenueGroup];
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
    
    id institutionGroup = [NSEntityDescription insertNewObjectForEntityForName:SmartGroupEntityName
                                             inManagedObjectContext:managedObjectContext];
    [institutionGroup setValue:[NSNumber numberWithBool:YES]
                        forKey:@"isRoot"];
    [institutionGroup setValue:NSLocalizedString(@"All Institutions", @"Top level Institution group name")
                        forKey:@"name"];
    [institutionGroup setValue:InstitutionEntityName
                        forKey:@"itemEntityName"];
    [institutionGroup setValue:[NSNumber numberWithShort:6]
                        forKey:@"priority"];
    [institutionGroup setValue:@"RootGroupIcon"
                        forKey:@"groupImageName"];
    
    id venueGroup = [NSEntityDescription insertNewObjectForEntityForName:SmartGroupEntityName
                                             inManagedObjectContext:managedObjectContext];
    [venueGroup setValue:[NSNumber numberWithBool:YES]
                  forKey:@"isRoot"];
    [venueGroup setValue:NSLocalizedString(@"All Venues", @"Top level Venue group name")
                  forKey:@"name"];
    [venueGroup setValue:VenueEntityName
                  forKey:@"itemEntityName"];
    [venueGroup setValue:[NSNumber numberWithShort:5]
                  forKey:@"priority"];
    [venueGroup setValue:@"RootGroupIcon"
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

#pragma mark Default root groups

- (NSManagedObject *)rootPublicationGroup{
	return [self rootGroupForEntityName:PublicationEntityName];
}

- (NSManagedObject *)rootPersonGroup{
	return [self rootGroupForEntityName:PersonEntityName];
}

- (NSManagedObject *)rootNoteGroup{
	return [self rootGroupForEntityName:NoteEntityName];
}

- (NSManagedObject *)rootInstitutionGroup{
	return [self rootGroupForEntityName:InstitutionEntityName];
}

- (NSManagedObject *)rootVenueGroup{
	return [self rootGroupForEntityName:VenueEntityName];
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

#pragma mark Add new publications from parsed info

- (NSSet *)newPublicationsFromDictionaries:(NSSet *)dictionarySet{
    NSManagedObjectContext *moc = [self managedObjectContext];
    
    NSMutableSet *returnSet = [[NSMutableSet alloc] initWithCapacity:[dictionarySet count]];
    NSEnumerator *dictEnum = [dictionarySet objectEnumerator];
    NSDictionary *dict;
    
    while (dict = [dictEnum nextObject]) {
        
        NSManagedObject *publication = [NSEntityDescription insertNewObjectForEntityForName:@"Publication" inManagedObjectContext:moc];
        
        NSMutableSet *keyValuePairs = [publication mutableSetValueForKey:@"keyValuePairs"];
        NSMutableSet *contributors = [publication mutableSetValueForKey:@"contributorRelationships"];
        NSMutableSet *notes = [publication mutableSetValueForKey:@"notes"];
        
        NSEnumerator *keyEnum = [dict keyEnumerator];
        NSString *key;
        id value;
        
        while (key = [keyEnum nextObject]) {
            value = [dict objectForKey:key];
            key = [key capitalizedString];
            if ([key isEqualToString:@"Author"] || [key isEqualToString:@"Editor"]) {
                NSArray *names = ([value isKindOfClass:[NSArray class]]) ? value : [NSArray arrayWithObject:value];
                NSEnumerator *nameEnum = [names objectEnumerator];
                NSString *name;
                NSManagedObject *person;
                NSManagedObject *relationship;
                while (name = [nameEnum nextObject]) {
                     // TODO: identify persons with the same name
                     person = [NSEntityDescription insertNewObjectForEntityForName:PersonEntityName inManagedObjectContext:moc];
                     relationship = [NSEntityDescription insertNewObjectForEntityForName:ContributorPublicationRelationshipEntityName inManagedObjectContext:moc];
                     [person setValue:name forKey:@"name"];
                     [relationship setValue:person forKey:@"contributor"];
                     [relationship setValue:[key lowercaseString] forKey:@"relationshipType"];
                     [relationship setValue:[NSNumber numberWithInt:[contributors count]] forKey:@"index"];
                     [contributors addObject:relationship];
                }
            } else if ([key isEqualToString:@"Annotation"]) {
                NSManagedObject *note = [NSEntityDescription insertNewObjectForEntityForName:NoteEntityName inManagedObjectContext:moc];
                [notes addObject:note];
            } else if ([key isEqualToString:@"Journal"]) {
                NSManagedObject *venue = [NSEntityDescription insertNewObjectForEntityForName:VenueEntityName inManagedObjectContext:moc];
                [venue setValue:value forKey:@"name"];
                [publication setValue:venue forKey:@"venue"];
            } else if ([key isEqualToString:@"Publication Type"]) {
                [publication setValue:value forKey:@"publicationType"];
            } else if ([key isEqualToString:@"Cite Key"]) {
                [publication setValue:value forKey:@"citeKey"];
            } else if ([key isEqualToString:@"Title"]) {
                [publication setValue:value forKey:@"title"];
            } else if ([key isEqualToString:@"Short-Title"]) {
                [publication setValue:value forKey:@"shortTitle"];
            } else if ([key isEqualToString:@"Date-Added"]) {
                [publication setValue:[NSDate dateWithNaturalLanguageString:value] forKey:@"dateAdded"];
            } else if ([key isEqualToString:@"Date-Modified"]) {
                [publication setValue:[NSDate dateWithNaturalLanguageString:value] forKey:@"dateChanged"];
            } else {
                NSManagedObject *keyValuePair = [NSEntityDescription insertNewObjectForEntityForName:@"KeyValuePair" inManagedObjectContext:moc];
                [keyValuePair setValue:key forKey:@"key"];
                [keyValuePair setValue:value forKey:@"value"];
                [keyValuePairs addObject:keyValuePair];
            }
        }
        
        [returnSet addObject:publication];
    }
    
    return [returnSet autorelease];
}

@end

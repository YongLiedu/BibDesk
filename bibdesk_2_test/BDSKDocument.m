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
        // initialization code
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
    
    
    id pubGroup = [NSEntityDescription insertNewObjectForEntityForName:PublicationGroupEntityName
                                                  inManagedObjectContext:managedObjectContext];
    [pubGroup setValue:[NSNumber numberWithBool:YES]
                forKey:@"isRoot"];
    [pubGroup setValue:NSLocalizedString(@"All Publications", @"Top level Publication group name")
                forKey:@"name"];
    
    id personGroup = [NSEntityDescription insertNewObjectForEntityForName:PersonGroupEntityName
                                             inManagedObjectContext:managedObjectContext];
    [personGroup setValue:[NSNumber numberWithBool:YES]
                   forKey:@"isRoot"];
    [personGroup setValue:NSLocalizedString(@"All People", @"Top level Person group name")
                   forKey:@"name"];
    
    id noteGroup = [NSEntityDescription insertNewObjectForEntityForName:NoteGroupEntityName
                                             inManagedObjectContext:managedObjectContext];
    [noteGroup setValue:[NSNumber numberWithBool:YES]
                 forKey:@"isRoot"];
    [noteGroup setValue:NSLocalizedString(@"All Notes", @"Top level Note group name")
                 forKey:@"name"];
    
    
    // clear the undo manager and change count for the document such that
    // untitled documents start with zero unsaved changes
    [managedObjectContext processPendingChanges];
    [[managedObjectContext undoManager] removeAllActions];
    [self updateChangeCount:NSChangeCleared];
        
    
    // temporary data set up with one relationship
    
    
    id pub = [NSEntityDescription insertNewObjectForEntityForName:PublicationEntityName
                                                 inManagedObjectContext:managedObjectContext];
    [pub setValue:@"test pub"
                 forKey:@"title"];
    NSMutableSet *set = [pubGroup mutableSetValueForKey:@"items"];
    [set addObject:pub];
    
    id note = [NSEntityDescription insertNewObjectForEntityForName:@"Note"
                                           inManagedObjectContext:managedObjectContext];
    [note setValue:@"note1" forKey:@"name"];
    [note setValue:@"value of note1" forKey:@"value"];
    [[pub mutableSetValueForKey:@"notes"] addObject:note];
    
    
    id person = [NSEntityDescription insertNewObjectForEntityForName:PersonEntityName
                                              inManagedObjectContext:managedObjectContext];
    [person setValue:@"blow"
              forKey:@"lastNamePart"];
    [person setValue:@"joe"
              forKey:@"firstNamePart"];
    NSMutableSet *set2 = [personGroup mutableSetValueForKey:@"items"];
    [set2 addObject:person];

    id person2 = [NSEntityDescription insertNewObjectForEntityForName:PersonEntityName
                                            inManagedObjectContext:managedObjectContext];
    [person2 setValue:@"blow"
              forKey:@"lastNamePart"];
    [person2 setValue:@"john"
              forKey:@"firstNamePart"];
    [set2 addObject:person2];
    id tag = [NSEntityDescription insertNewObjectForEntityForName:TagEntityName
                                           inManagedObjectContext:managedObjectContext];
    [tag setValue:@"johnblowgroup" forKey:@"name"];
    [[person2 mutableSetValueForKey:@"tags"] addObject:tag];
    
    id relationship = [NSEntityDescription insertNewObjectForEntityForName:ContributorPublicationRelationshipEntityName
                                              inManagedObjectContext:managedObjectContext];
    [relationship setValue:@"author"
              forKey:@"relationshipType"];
    [relationship setValue:person
                    forKey:@"contributor"];
    [relationship setValue:pub
                    forKey:@"publication"];

    id contributorPublicationRelationships = [pub mutableSetValueForKey:@"contributorRelationships"];
    [contributorPublicationRelationships addObject:relationship];
    
    relationship = [NSEntityDescription insertNewObjectForEntityForName:ContributorPublicationRelationshipEntityName
                                                 inManagedObjectContext:managedObjectContext];
    [relationship setValue:@"author"
                    forKey:@"relationshipType"];
    [relationship setValue:person2
                    forKey:@"contributor"];
    [relationship setValue:pub
                    forKey:@"publication"];
    
    
    [contributorPublicationRelationships addObject:relationship];
    
    tag = [NSEntityDescription insertNewObjectForEntityForName:TagEntityName
                                           inManagedObjectContext:managedObjectContext];
    [tag setValue:@"tagsRCool" forKey:@"name"];
    [[pub mutableSetValueForKey:@"tags"] addObject:tag];
    
    id institution1 = [NSEntityDescription insertNewObjectForEntityForName:@"Institution" inManagedObjectContext:managedObjectContext];
    
    [institution1 setValue:@"Penn State" forKey:@"name"];
    
    id institution2 = [NSEntityDescription insertNewObjectForEntityForName:@"Institution" inManagedObjectContext:managedObjectContext];
    
    [institution2 setValue:@"UC San Diego" forKey:@"name"];
    
    
    id institutionRelationship1 = [NSEntityDescription insertNewObjectForEntityForName:PersonInstitutionRelationshipEntityName
                                                               inManagedObjectContext:managedObjectContext];
    [institutionRelationship1 setValue:@"phd student"
                               forKey:@"relationshipType"];
    [institutionRelationship1 setValue:person
                               forKey:@"person"];
    [institutionRelationship1 setValue:institution1
                               forKey:@"institution"];
    [institutionRelationship1 setValue:[NSDate dateWithNaturalLanguageString:@"8/30/1997"]
                                forKey:@"startDate"];
    [institutionRelationship1 setValue:[NSDate dateWithNaturalLanguageString:@"4/1/2001"]
                                forKey:@"endDate"];
        
    
    id institutionRelationship2 = [NSEntityDescription insertNewObjectForEntityForName:PersonInstitutionRelationshipEntityName
                                                               inManagedObjectContext:managedObjectContext];
    [institutionRelationship2 setValue:@"phd student"
                               forKey:@"relationshipType"];
    [institutionRelationship2 setValue:person
                               forKey:@"person"];
    [institutionRelationship2 setValue:institution2
                               forKey:@"institution"];

    [institutionRelationship2 setValue:[NSDate dateWithNaturalLanguageString:@"9/11/2001"]
                                forKey:@"startDate"];
    
            
    return self;
}


- (void)makeWindowControllers{
    BDSKMainWindowController *mwc = [[BDSKMainWindowController alloc] initWithWindowNibName:@"BDSKMainWindow"];
    [self addWindowController:[mwc autorelease]];
}


- (void)windowControllerDidLoadNib:(NSWindowController *)windowController{
    [super windowControllerDidLoadNib:windowController];
    // user interface preparation code
}


/* Accessors for root objects. Not currently used...
 */
- (NSManagedObject *)rootPubGroup{
    
    NSPredicate *rootItemPredicate = [NSPredicate predicateWithFormat:@"isRoot == YES "];
    
    NSManagedObjectContext *moc = [self managedObjectContext];
    
    NSFetchRequest *publicationGroupFetchRequest = [[NSFetchRequest alloc] init];
    [publicationGroupFetchRequest setPredicate:rootItemPredicate];
    
    NSError *fetchError = nil;
    NSArray *fetchResults;
    @try {
        NSEntityDescription *entity = [NSEntityDescription entityForName:PublicationGroupEntityName
                                                  inManagedObjectContext:moc];
        [publicationGroupFetchRequest setEntity:entity];
        fetchResults = [moc executeFetchRequest:publicationGroupFetchRequest error:&fetchError];
    } @finally {
        [publicationGroupFetchRequest release];
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

- (NSManagedObject *)rootPersonGroup{
    
    NSPredicate *rootItemPredicate = [NSPredicate predicateWithFormat:@"isRoot == YES"];
    NSManagedObjectContext *moc = [self managedObjectContext];
    NSFetchRequest *groupFetchRequest = [[NSFetchRequest alloc] init];

    [groupFetchRequest setPredicate:rootItemPredicate];
    
    NSError *fetchError = nil;
    NSArray *fetchResults;
    @try {
        NSEntityDescription *entity = [NSEntityDescription entityForName:PersonGroupEntityName
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

//
//  BDSKPersonTableDisplayController.m
//  bd2
//
//  Created by Michael McCracken on 7/13/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKPersonTableDisplayController.h"
#import "BDSKDocument.h"
#import "NSTableView_BDSKExtensions.h"


@implementation BDSKPersonTableDisplayController

- (NSString *)windowNibName{
    return @"BDSKPersonTableDisplay";
}

- (void)awakeFromNib{
	[super awakeFromNib];
	[itemsTableView registerForDraggedTypes:[NSArray arrayWithObjects:BDSKPublicationPboardType, BDSKPersonPboardType, BDSKInstitutionPboardType, BDSKTagPboardType, nil]];
}

#pragma mark Actions

- (IBAction)addPerson:(id)sender {
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:PersonEntityName inManagedObjectContext:moc];
    [itemsArrayController addObject:person];
    [moc processPendingChanges];
    [itemsArrayController setSelectedObjects:[NSArray arrayWithObject:person]];
}

- (IBAction)removePersons:(NSArray *)selectedItems {
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSEnumerator *selEnum = [selectedItems objectEnumerator];
	NSManagedObject *person;
	while (person = [selEnum nextObject]) 
		[moc deleteObject:person];
    [moc processPendingChanges];
    // dirty fix for CoreData bug, which registers an extra change when objects are deleted
    [[self document] updateChangeCount:NSChangeUndone];
}

#pragma mark Filter predicate binding

- (NSArray *)filterPredicates {
    static NSMutableArray *filterPredicates = nil;
    if (filterPredicates == nil) {
        NSDictionary *options;
        filterPredicates = [[NSMutableArray alloc] initWithCapacity:1];
        options = [NSDictionary dictionaryWithObjectsAndKeys:@"Name", NSDisplayNameBindingOption, @"name contains[c] $value", NSPredicateFormatBindingOption, nil];
        [filterPredicates addObject:options];
    }
    return filterPredicates;
}

#pragma mark NSTableView DataSource protocol

// dummy implementation as the NSTableView DataSource protocols requires these methods
- (int)numberOfRowsInTableView:(NSTableView *)tv {
	return 0;
}

// dummy implementation as the NSTableView DataSource protocols requires these methods
- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row {
	return nil;
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
	if (tv == itemsTableView) {
        return [self writeRowsWithIndexes:rowIndexes toPasteboard:pboard forType:BDSKPersonPboardType];
	}
    
	return NO;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op {
	if (tv == itemsTableView) {
		
        NSPasteboard *pboard = [info draggingPasteboard];
		NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKPublicationPboardType, BDSKPersonPboardType, BDSKInstitutionPboardType, BDSKTagPboardType, nil]];
        if ([tv setValidDropRow:row dropOperation:NSTableViewDropOn] == NO)
            return NSDragOperationNone;
		if ([type isEqualToString:BDSKPublicationPboardType] || [type isEqualToString:BDSKInstitutionPboardType] || [type isEqualToString:BDSKTagPboardType]) {
            if ([[[info draggingSource] dataSource] document] == [self document])
				return NSDragOperationLink;
			else
				return NSDragOperationCopy;
		} else if ([type isEqualToString:BDSKPersonPboardType] && [info draggingSource] == tv) {
			return NSDragOperationLink;
        }
        
	}
    
	return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op {
	NSPasteboard *pboard = [info draggingPasteboard];
	
    if (tv == itemsTableView) {
		
        if (!([info draggingSourceOperationMask] & NSDragOperationLink))
			return NO;
		NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKPublicationPboardType, BDSKPersonPboardType, BDSKInstitutionPboardType, BDSKTagPboardType, nil]];
		
        if ([type isEqualToString:BDSKPublicationPboardType]) {
			
            return [self addRelationshipsFromPasteboard:pboard forType:type parentRow:row keyPath:@"publicationRelationships.publication"];
            
        } else if ([type isEqualToString:BDSKInstitutionPboardType]) {
			
            return [self addRelationshipsFromPasteboard:pboard forType:type parentRow:row keyPath:@"institutionRelationships.institution"];
            
        } else if ([type isEqualToString:BDSKTagPboardType]) {
			
            return [self addRelationshipsFromPasteboard:pboard forType:type parentRow:row keyPath:@"tags"];
            
		} else if ([type isEqualToString:BDSKPersonPboardType]) {
			
            NSArray *draggedURIs = [NSUnarchiver unarchiveObjectWithData:[pboard dataForType:BDSKPersonPboardType]];
			NSEnumerator *uriE = [draggedURIs objectEnumerator];
			NSManagedObjectContext *moc = [self managedObjectContext];
			NSURL *moURI;
			NSManagedObject *person = [[itemsArrayController arrangedObjects] objectAtIndex:row];
			NSManagedObject *publication;
			NSManagedObject *institution;
			NSManagedObject *relationship;
			NSManagedObject *mo;
			NSEnumerator *relationshipE;
            NSMutableArray *removedPersons = [[NSMutableArray alloc] initWithCapacity:[draggedURIs count]];
			
            while (moURI = [uriE nextObject]) {
				mo = [moc objectWithID:[[moc persistentStoreCoordinator] managedObjectIDForURIRepresentation:moURI]];
				if (mo == person) {
					continue;
				} else if ([[mo valueForKey:@"name"] isEqualToString:[person valueForKey:@"name"]] == NO) {
					NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Renaming Person", @"Renaming person warning message")
													 defaultButton:NSLocalizedString(@"Yes", @"OK")
												   alternateButton:NSLocalizedString(@"No", @"Cancel")
													   otherButton:nil
										 informativeTextWithFormat:NSLocalizedString(@"Do you want to identify person \"%@\" with \"%@\"? This will rename \"%@\" to \"%@\" everywhere.", @""), [mo valueForKeyPath:@"name"],  [person valueForKeyPath:@"name"], [mo valueForKeyPath:@"name"],  [person valueForKeyPath:@"name"]];
					int rv = [alert runModal];
					if (rv == NSAlertAlternateReturn)
						continue;
				}
				// TODO: change other relationships. How to handle one-way relationships, like groups?
				// update index
				relationshipE = [[mo valueForKey:@"publicationRelationships"] objectEnumerator];
				while (relationship = [relationshipE nextObject]) {
					publication = [relationship valueForKey:@"publication"];
					if ([[publication valueForKeyPath:@"contributorRelationships.@distinctUnionOfObjects.contributor"] containsObject:person] == NO)
						[relationship setValue:person forKey:@"contributor"];
				}
				relationshipE = [[mo valueForKey:@"institutionRelationships"] objectEnumerator];
				while (relationship = [relationshipE nextObject]) {
					institution = [relationship valueForKey:@"institution"];
					if ([[institution valueForKeyPath:@"personRelationships.@distinctUnionOfObjects.person"] containsObject:person] == NO)
						[relationship setValue:person forKey:@"person"];
				}
				[[person mutableSetValueForKey:@"notes"] unionSet:[mo valueForKey:@"notes"]];
				[[person mutableSetValueForKey:@"tags"] unionSet:[mo valueForKey:@"tags"]];
				[[person mutableSetValueForKey:@"containingGroups"] unionSet:[mo valueForKey:@"containingGroups"]];
                [removedPersons addObject:mo];
			}
            [self removePersons:removedPersons];
            [removedPersons release];
            
			return YES;
            
		}
	}
    
	return NO;
}

@end

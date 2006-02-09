//
//  BDSKPublicationTableDisplayController.m
//  bd2
//
//  Created by Michael McCracken on 6/21/05.
//  Copyright 2005 Michael McCracken. All rights reserved.
//

#import "BDSKPublicationTableDisplayController.h"
#import "BDSKDocument.h"
#import "NSTableView_BDSKExtensions.h"

#define BDSKContributorRowsPboardType @"BDSKContributorRowsPboardType"

@implementation BDSKPublicationTableDisplayController

- (void)dealloc{
	[contributorsArrayController release];
	[tagsArrayController release];
	[notesArrayController release];
    [super dealloc];
}

- (NSString *)viewNibName{
	return @"BDSKPublicationTableDisplayController";
}

- (void)awakeFromNib{
	[super awakeFromNib];
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES];
    [contributorsArrayController setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
	[sortDescriptor release];
	[itemsTableView registerForDraggedTypes:[NSArray arrayWithObjects:BDSKPersonPboardType, BDSKInstitutionPboardType, BDSKVenuePboardType, BDSKTagPboardType, nil]];
	[tagsTableView registerForDraggedTypes:[NSArray arrayWithObjects:BDSKTagPboardType, nil]];
	[contributorsTableView registerForDraggedTypes:[NSArray arrayWithObjects:BDSKContributorRowsPboardType, BDSKPersonPboardType, nil]];
	[contributorsTableView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES]; // NSDragOperationMove is not included in the default mask
}

#pragma mark Actions

- (IBAction)addPublication:(id)sender {
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSManagedObject *publication = [NSEntityDescription insertNewObjectForEntityForName:PublicationEntityName inManagedObjectContext:moc];
    [itemsArrayController addObject:publication];
    [moc processPendingChanges];
    [itemsArrayController setSelectedObjects:[NSArray arrayWithObject:publication]];
}

- (IBAction)removePublications:(NSArray *)selectedItems {
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSEnumerator *selEnum = [selectedItems objectEnumerator];
	NSManagedObject *publication;
	while (publication = [selEnum nextObject]) 
		[moc deleteObject:publication];
    [moc processPendingChanges];
}

- (IBAction)addContributor:(id)sender {
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:PersonEntityName inManagedObjectContext:moc];
	NSManagedObject *relationship = [NSEntityDescription insertNewObjectForEntityForName:ContributorPublicationRelationshipEntityName inManagedObjectContext:moc];
	[relationship setValue:[NSNumber numberWithInt:[[contributorsArrayController arrangedObjects] count]] forKey:@"index"];
	[relationship setValue:person forKey:@"contributor"];
	[relationship setValue:@"author" forKey:@"relationshipType"];
	[contributorsArrayController addObject:relationship];
}

#pragma mark Filter predicate binding

- (NSArray *)filterPredicates {
    static NSMutableArray *filterPredicates = nil;
    if (filterPredicates == nil) {
        NSDictionary *options;
        filterPredicates = [[NSMutableArray alloc] initWithCapacity:2];
        options = [NSDictionary dictionaryWithObjectsAndKeys:@"Title", NSDisplayNameBindingOption, @"title contains[c] $value", NSPredicateFormatBindingOption, nil];
        [filterPredicates addObject:options];
        options = [NSDictionary dictionaryWithObjectsAndKeys:@"Short Title", NSDisplayNameBindingOption, @"shortTitle contains[c] $value", NSPredicateFormatBindingOption, nil];
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
	if (tv == contributorsTableView) {
		[pboard declareTypes: [NSArray arrayWithObject:BDSKContributorRowsPboardType] owner:self];
		[pboard setData:[NSArchiver archivedDataWithRootObject:rowIndexes] forType:BDSKContributorRowsPboardType];
        return YES;
	} else if (tv == itemsTableView) {
        return [self writeRowsWithIndexes:rowIndexes toPasteboard:pboard forType:BDSKPublicationPboardType];
	}
    
	return NO;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op {
	NSPasteboard *pboard = [info draggingPasteboard];
	
    if (tv == contributorsTableView) {
        
		if ([[itemsArrayController selectedObjects] count] != 1)
			return NSDragOperationNone;
		NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKContributorRowsPboardType, BDSKPersonPboardType, nil]];
		if ([type isEqualToString:BDSKContributorRowsPboardType] && [info draggingSource] == tv) {
            if ([tv setValidDropRow:row dropOperation:NSTableViewDropAbove] == NO)
                return NSDragOperationNone;
			return NSDragOperationMove;
		} else if ([type isEqualToString:BDSKPersonPboardType]) {
			[tv setDropRow:-1 dropOperation:NSTableViewDropOn];
			if ([[[info draggingSource] dataSource] document] == [self document])
				return NSDragOperationLink;
			else
				return NSDragOperationCopy;
		}
        
    } else if (tv == tagsTableView) {
		
        if ([[itemsArrayController selectedObjects] count] != 1)
			return NSDragOperationNone;
		NSPasteboard *pboard = [info draggingPasteboard];
		NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKTagPboardType, nil]];
		if ([type isEqualToString:BDSKTagPboardType]) {
			[tv setDropRow:-1 dropOperation:NSTableViewDropOn];
			if ([[[info draggingSource] dataSource] document] == [self document])
				return NSDragOperationLink;
			else
				return NSDragOperationCopy;
		}
        
	} else if (tv == itemsTableView) {
        
		NSPasteboard *pboard = [info draggingPasteboard];
		NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKPersonPboardType, BDSKInstitutionPboardType, BDSKVenuePboardType, BDSKTagPboardType, nil]];
		if ([type isEqualToString:BDSKPersonPboardType] || [type isEqualToString:BDSKInstitutionPboardType] || [type isEqualToString:BDSKVenuePboardType] || [type isEqualToString:BDSKTagPboardType]) {
			[tv setDropRow:-1 dropOperation:NSTableViewDropOn];
			if ([[[info draggingSource] dataSource] document] == [self document])
				return NSDragOperationLink;
			else
				return NSDragOperationCopy;
		}
        
	}
    
	return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op {
	NSPasteboard *pboard = [info draggingPasteboard];
    
	if (tv == contributorsTableView) {
        
		NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKContributorRowsPboardType, BDSKPersonPboardType, nil]];
		
        if ([type isEqualToString:BDSKContributorRowsPboardType]) {
			
            if (!([info draggingSourceOperationMask] & NSDragOperationMove) || [info draggingSource] != tv)
				return NO;
			
            NSData *rowData = [pboard dataForType:BDSKContributorRowsPboardType];
			NSIndexSet *removeIndexes = [NSUnarchiver unarchiveObjectWithData:rowData];
			int i, count;
			NSNumber *number;
			int insertRow = row;
			NSIndexSet *insertIndexes;
			NSArray *draggedObjects;
			NSMutableIndexSet *indexesBeforeInsertion = [removeIndexes mutableCopy];
			
            if ([removeIndexes lastIndex] >= row) 
				[indexesBeforeInsertion removeIndexesInRange:NSMakeRange(row, [removeIndexes lastIndex] - row + 1)];
			insertRow = row - [indexesBeforeInsertion count];
			[indexesBeforeInsertion release];
			insertIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(insertRow, [removeIndexes count])];
			NSMutableArray *relationships = [[contributorsArrayController arrangedObjects] mutableCopy];
			NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES];
			[relationships sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
			[sortDescriptor release];
			draggedObjects = [relationships objectsAtIndexes:removeIndexes];
			[relationships removeObjectsAtIndexes:removeIndexes];
			[relationships insertObjects:draggedObjects atIndexes:insertIndexes];
			count = [relationships count];
			for (i = 0; i < count; i++) {
				number = [[NSNumber alloc] initWithInt:i];
				[[relationships objectAtIndex:i] setValue:number forKey:@"index"];
				[number release];
			}
			[relationships release];
			[contributorsArrayController rearrangeObjects];
			return YES;
            
		} else if ([type isEqualToString:BDSKPersonPboardType] || [type isEqualToString:BDSKInstitutionPboardType]) {
			
            if ([info draggingSourceOperationMask] & NSDragOperationLink)
				return [self addRelationshipsFromPasteboard:pboard forType:type parentRow:-1 keyPath:@"contributorRelationships.contributor"];
            
		}
        
	} else if (tv == tagsTableView) {
        
        NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKTagPboardType, nil]];
		if (([info draggingSourceOperationMask] & NSDragOperationLink) &&
			[type isEqualToString:BDSKTagPboardType])
			return [self addRelationshipsFromPasteboard:pboard forType:type parentRow:-1 keyPath:@"tags"];
        
	} else if (tv == itemsTableView) {
        
		if (!([info draggingSourceOperationMask] & NSDragOperationLink))
			return NO;
		NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKPersonPboardType, BDSKInstitutionPboardType, BDSKVenuePboardType, nil]];
		if ([type isEqualToString:BDSKPersonPboardType] || [type isEqualToString:BDSKInstitutionPboardType])
			return [self addRelationshipsFromPasteboard:pboard forType:type parentRow:-1 keyPath:@"contributorRelationships.contributor"];
        else if ([type isEqualToString:BDSKVenuePboardType])
			return [self addRelationshipsFromPasteboard:pboard forType:type parentRow:-1 keyPath:@"venue"];
        
	}
    
	return NO;
}

@end

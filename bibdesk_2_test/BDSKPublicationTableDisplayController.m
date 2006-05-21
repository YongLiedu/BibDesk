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

- (NSString *)windowNibName{
	return @"BDSKPublicationTableDisplay";
}

- (void)awakeFromNib{
	[super awakeFromNib];
	[itemsTableView registerForDraggedTypes:[NSArray arrayWithObjects:BDSKPersonPboardType, BDSKInstitutionPboardType, BDSKVenuePboardType, BDSKTagPboardType, nil]];
}

#pragma mark Actions

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
	if (tv == itemsTableView) {
        return [self writeRowsWithIndexes:rowIndexes toPasteboard:pboard forType:BDSKPublicationPboardType];
	}
    
	return NO;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op {
	NSPasteboard *pboard = [info draggingPasteboard];
	
    if (tv == itemsTableView) {
        
		NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKPersonPboardType, BDSKInstitutionPboardType, BDSKVenuePboardType, BDSKTagPboardType, nil]];
        if ([tv setValidDropRow:row dropOperation:NSTableViewDropOn] == NO)
            return NSDragOperationNone;
		if ([type isEqualToString:BDSKPersonPboardType] || [type isEqualToString:BDSKInstitutionPboardType] || [type isEqualToString:BDSKVenuePboardType] || [type isEqualToString:BDSKTagPboardType]) {
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
    
	if (tv == itemsTableView) {
        
		if (!([info draggingSourceOperationMask] & NSDragOperationLink))
			return NO;
		NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKPersonPboardType, BDSKInstitutionPboardType, BDSKTagPboardType, BDSKVenuePboardType, nil]];
		if ([type isEqualToString:BDSKPersonPboardType] || [type isEqualToString:BDSKInstitutionPboardType])
			return [self addRelationshipsFromPasteboard:pboard forType:type parentRow:row keyPath:@"contributorRelationships.contributor"];
        else if ([type isEqualToString:BDSKTagPboardType])
			return [self addRelationshipsFromPasteboard:pboard forType:type parentRow:row keyPath:@"tags"];
        else if ([type isEqualToString:BDSKVenuePboardType])
			return [self addRelationshipsFromPasteboard:pboard forType:type parentRow:row keyPath:@"venue"];
        
	}
    
	return NO;
}

@end

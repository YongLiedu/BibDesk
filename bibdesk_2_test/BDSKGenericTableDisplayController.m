//
//  BDSKGenericTableDisplayController.m
//  bd2
//
//  Created by Christiaan Hofman on 5/20/06.
//  Copyright 2006 Christiaan Hofman. All rights reserved.
//

#import "BDSKGenericTableDisplayController.h"
#import "BDSKDocument.h"
#import "NSTableView_BDSKExtensions.h"

@implementation BDSKGenericTableDisplayController

- (NSString *)windowNibName{
	return @"BDSKGenericTableDisplay";
}

- (void)awakeFromNib{
	[super awakeFromNib];
}

#pragma mark Filter predicate binding

- (NSArray *)filterPredicates {
    static NSMutableArray *filterPredicates = nil;
    if (filterPredicates == nil) {
        NSDictionary *options;
        filterPredicates = [[NSMutableArray alloc] initWithCapacity:2];
        options = [NSDictionary dictionaryWithObjectsAndKeys:@"Name", NSDisplayNameBindingOption, @"name contains[c] $value", NSPredicateFormatBindingOption, nil];
        [filterPredicates addObject:options];
        options = [NSDictionary dictionaryWithObjectsAndKeys:@"Type", NSDisplayNameBindingOption, @"entity.name contains[c] $value", NSPredicateFormatBindingOption, nil];
        [filterPredicates addObject:options];
    }
    return filterPredicates;
}

# pragma mark Table Columns

- (NSArray *)columnInfo {
    NSArray *columnInfo = nil;
    if ([itemEntityName isEqualToString:PublicationEntityName]) {
        columnInfo = [NSArray arrayWithObjects:
            [NSDictionary dictionaryWithObjectsAndKeys:@"title", @"keyPath", @"Title", @"displayName", nil], 
            [NSDictionary dictionaryWithObjectsAndKeys:@"shortTitle", @"keyPath", @"Short Title", @"displayName", nil], 
            nil];
    } else if ([itemEntityName isEqualToString:PersonEntityName]) {
        columnInfo = [NSArray arrayWithObjects:
            [NSDictionary dictionaryWithObjectsAndKeys:@"firstNamePart", @"keyPath", @"First", @"displayName", nil], 
            [NSDictionary dictionaryWithObjectsAndKeys:@"lastNamePart", @"keyPath", @"Last", @"displayName", nil], 
            [NSDictionary dictionaryWithObjectsAndKeys:@"name", @"keyPath", @"Full Name", @"displayName", nil], 
            nil];
    } else if ([itemEntityName isEqualToString:InstitutionEntityName]) {
        columnInfo = [NSArray arrayWithObjects:
            [NSDictionary dictionaryWithObjectsAndKeys:@"name", @"keyPath", @"Name", @"displayName", nil], 
            [NSDictionary dictionaryWithObjectsAndKeys:@"address", @"keyPath", @"Address", @"displayName", nil], 
            nil];
    } else if ([itemEntityName isEqualToString:VenueEntityName]) {
        columnInfo = [NSArray arrayWithObjects:
            [NSDictionary dictionaryWithObjectsAndKeys:@"name", @"keyPath", @"Name", @"displayName", nil], 
            [NSDictionary dictionaryWithObjectsAndKeys:@"abbreviation", @"keyPath", @"Abbreviation", @"displayName", nil], 
            [NSDictionary dictionaryWithObjectsAndKeys:@"acronym", @"keyPath", @"Acronym", @"displayName", nil], 
            nil];
    } else if ([itemEntityName isEqualToString:NoteEntityName]) {
        columnInfo = [NSArray arrayWithObjects:
            [NSDictionary dictionaryWithObjectsAndKeys:@"name", @"keyPath", @"Name", @"displayName", nil], 
            [NSDictionary dictionaryWithObjectsAndKeys:@"value", @"keyPath", @"Value", @"displayName", nil], 
            nil];
    } else if ([itemEntityName isEqualToString:TagEntityName]) {
        columnInfo = [NSArray arrayWithObjects:
            [NSDictionary dictionaryWithObjectsAndKeys:@"name", @"keyPath", @"Name", @"displayName", nil], 
            nil];
    } else {
        columnInfo = [NSArray arrayWithObjects:
            [NSDictionary dictionaryWithObjectsAndKeys:@"name", @"keyPath", @"Name", @"displayName", nil], 
            [NSDictionary dictionaryWithObjectsAndKeys:@"entity.name", @"keyPath", @"Type", @"displayName", nil], 
            nil];
    }
    return columnInfo;
}

- (void)updateUI {
    [super updateUI];
    
    NSArray *columnInfo = [self columnInfo];
    NSArray *tableColumns = [itemsTableView tableColumns];
    NSTableColumn *tableColumn;
    int i, count = [tableColumns count];
    while (count--) {
        tableColumn = [tableColumns objectAtIndex:count];
        [tableColumn unbind:@"value"];
        [itemsTableView removeTableColumn:tableColumn];
    }
    count = [columnInfo count];
    for (i = 0; i < count; i++) {
        NSDictionary *dict = [columnInfo objectAtIndex:i];
        NSString *displayName = [dict objectForKey:@"displayName"];
        NSString *keyPath = [dict objectForKey:@"keyPath"];
        tableColumn = [[[NSTableColumn alloc] initWithIdentifier:keyPath] autorelease];
        [[tableColumn headerCell] setStringValue:displayName];
        [itemsTableView addTableColumn:tableColumn];
        keyPath = [NSString stringWithFormat:@"arrangedObjects.%@", keyPath];
        [tableColumn bind:@"value" toObject:itemsArrayController withKeyPath:keyPath options:0];
    }
    [itemsTableView sizeToFit];
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
	return NO;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op {
	return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op {
	return NO;
}

@end

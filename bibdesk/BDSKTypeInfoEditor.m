//
//  BDSKTypeInfoEditor.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 5/4/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKTypeInfoEditor.h"
#import "BDSKFieldNameFormatter.h"
#import "BibAppController.h"
#import "BibTypeManager.h"

#define BDSKTypeInfoRowsPboardType	@"BDSKTypeInfoRowsPboardType"
#define REQUIRED_KEY				@"required"
#define OPTIONAL_KEY				@"optional"
#define FIELDS_FOR_TYPES_KEY		@"FieldsForTypes"
#define TYPES_FOR_FILE_TYPE_KEY		@"TypesForFileType"
#define ALL_FIELDS_KEY				@"AllFields"
#define TYPE_INFO_FILENAME			@"TypeInfo.plist"

static BDSKTypeInfoEditor *sharedTypeInfoEditor;

@implementation BDSKTypeInfoEditor

+ (BDSKTypeInfoEditor *)sharedTypeInfoEditor{
    if (!sharedTypeInfoEditor) {
        sharedTypeInfoEditor = [[BDSKTypeInfoEditor alloc] init];
    }
    return sharedTypeInfoEditor;
}

- (id)init
{
    if (self = [super initWithWindowNibName:@"BDSKTypeInfoEditor"]) {
		// we keep a copy to the bundles TypeInfo list to see which items we shouldn't edit
		NSDictionary *tmpDict = [NSDictionary dictionaryWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"TypeInfo.plist"]];
		// we are only interested in this dictionary
		defaultFieldsForTypesDict = [[tmpDict objectForKey:FIELDS_FOR_TYPES_KEY] retain];
		
		// try to read the user file in the Application Support directory
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *applicationSupportPath = [[fm applicationSupportDirectory:kUserDomain] stringByAppendingPathComponent:@"BibDesk"];
		NSString *typeInfoPath = [applicationSupportPath stringByAppendingPathComponent:TYPE_INFO_FILENAME];
		
		if ([fm fileExistsAtPath:typeInfoPath]) {
			NSString *error = nil;
			NSPropertyListFormat format;
			NSData *data = [NSData dataWithContentsOfFile:typeInfoPath];
			
			tmpDict = [NSPropertyListSerialization propertyListFromData:data 
													   mutabilityOption:NSPropertyListMutableContainers 
																 format:&format 
													   errorDescription:&error];
			
			if (error) {
				NSLog(@"Error reading: %@", error);
			} else {
				fieldsForTypesDict = [[tmpDict objectForKey:FIELDS_FOR_TYPES_KEY] retain];
				types = [[[tmpDict objectForKey:TYPES_FOR_FILE_TYPE_KEY] objectForKey:BDSKBibtexString] retain];
			}
		} 
		
		// if we failed, we set the default types from the bundled one
		if ((fieldsForTypesDict == nil) || (types == nil)) {
			fieldsForTypesDict = [[NSMutableDictionary alloc] initWithCapacity:[defaultFieldsForTypesDict count]];
			types = [[NSMutableArray alloc] initWithCapacity:[defaultFieldsForTypesDict count]];
			[self revertAllToDefault:nil]; // this sets the default values for the types
		}
    }
    return self;
}

- (void)dealloc
{
    [fieldsForTypesDict release];
    [defaultFieldsForTypesDict release];
    [types release];
    [currentType release];
    [super dealloc];
}

- (void)awakeFromNib
{
    // we want to be able to reorder the items
	[typeTableView registerForDraggedTypes:[NSArray arrayWithObject:BDSKTypeInfoRowsPboardType]];
    [requiredTableView registerForDraggedTypes:[NSArray arrayWithObject:BDSKTypeInfoRowsPboardType]];
    [optionalTableView registerForDraggedTypes:[NSArray arrayWithObject:BDSKTypeInfoRowsPboardType]];
	
    BDSKFieldNameFormatter *fieldNameFormatter = [[[BDSKFieldNameFormatter alloc] init] autorelease];
    NSTableColumn *tc = [typeTableView tableColumnWithIdentifier:@"type"];
    [[tc dataCell] setFormatter:fieldNameFormatter];
	tc = [requiredTableView tableColumnWithIdentifier:@"required"];
    [[tc dataCell] setFormatter:fieldNameFormatter];
	tc = [optionalTableView tableColumnWithIdentifier:@"optional"];
    [[tc dataCell] setFormatter:fieldNameFormatter];
	
	[typeTableView reloadData];
	[requiredTableView reloadData];
	[optionalTableView reloadData];
	
	[self updateButtons];
}

# pragma mark Accessors

- (void)addType:(NSString *)newType withFields:(NSDictionary *)fieldsDict {
	[types addObject:newType];
	
	// create mutable containers for the fields
	NSMutableArray *requiredFields;
	NSMutableArray *optionalFields;
	
	if (fieldsDict) {
		requiredFields = [NSMutableArray arrayWithArray:[fieldsDict objectForKey:REQUIRED_KEY]];
		optionalFields = [NSMutableArray arrayWithArray:[fieldsDict objectForKey:OPTIONAL_KEY]];
	} else {
		requiredFields = [NSMutableArray arrayWithCapacity:1];
		optionalFields = [NSMutableArray arrayWithCapacity:1];
	}
	NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithObjectsAndKeys: requiredFields, REQUIRED_KEY, optionalFields, OPTIONAL_KEY, nil];
	[fieldsForTypesDict setObject:newDict forKey:newType];
	
	// select the new type
	[typeTableView selectRow:[types indexOfObject:newType] byExtendingSelection:NO];
}

- (void)setCurrentType:(NSString *)newCurrentType {
    if (currentType != newCurrentType) {
        [currentType release];
        currentType = [newCurrentType copy];
		
		if (currentType) {
			currentRequiredFields = [[fieldsForTypesDict objectForKey:currentType] objectForKey:REQUIRED_KEY];
			currentOptionalFields = [[fieldsForTypesDict objectForKey:currentType] objectForKey:OPTIONAL_KEY]; 
			currentDefaultRequiredFields = [[defaultFieldsForTypesDict objectForKey:currentType] objectForKey:REQUIRED_KEY];
			currentDefaultOptionalFields = [[defaultFieldsForTypesDict objectForKey:currentType] objectForKey:OPTIONAL_KEY];
		} else {
			currentRequiredFields = nil;
			currentOptionalFields = nil;
			currentDefaultRequiredFields = nil;
			currentDefaultOptionalFields = nil;
		}
		
		[requiredTableView reloadData];
		[optionalTableView reloadData];
		
		[self updateButtons];
    }
}

#pragma mark Actions

- (IBAction)cancel:(id)sender {
	[self close];
}

- (IBAction)saveChanges:(id)sender {
	NSMutableSet *allFields = [NSMutableSet setWithCapacity:24];
	NSEnumerator *typeEnum = [types objectEnumerator];
	NSEnumerator *fieldEnum;
	NSString *type;
	NSString *field;
	
	while (type = [typeEnum nextObject]) {
		fieldEnum = [[[fieldsForTypesDict objectForKey:type] objectForKey:REQUIRED_KEY] objectEnumerator];
		while (field = [fieldEnum nextObject]) {
			[allFields addObject:field];
		}
		fieldEnum = [[[fieldsForTypesDict objectForKey:type] objectForKey:OPTIONAL_KEY] objectEnumerator];
		while (field = [fieldEnum nextObject]) {
			[allFields addObject:field];
		}
	}
	
	NSString *error = nil;
	NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys: 
				fieldsForTypesDict, FIELDS_FOR_TYPES_KEY, 
				[NSDictionary dictionaryWithObject:types forKey:BDSKBibtexString], TYPES_FOR_FILE_TYPE_KEY, 
				[allFields allObjects], ALL_FIELDS_KEY, nil];
	
	NSData *data = [NSPropertyListSerialization dataFromPropertyList:dict
															  format:format 
													errorDescription:&error];
	if (error) {
		NSLog(@"Error writing: %@", error);
	} else {
		NSString *applicationSupportPath = [[[NSFileManager defaultManager] applicationSupportDirectory:kUserDomain] stringByAppendingPathComponent:@"BibDesk"]; 
		NSString *typeInfoPath = [applicationSupportPath stringByAppendingPathComponent:TYPE_INFO_FILENAME];
		[data writeToFile:typeInfoPath atomically:YES];
	}
	
	[self close];
}

- (IBAction)addType:(id)sender {
	NSString *newType = [NSString stringWithString:@"new-type"];
	int i = 0;
	while ([types containsObject:newType]) {
		newType = [NSString stringWithFormat:@"new-type-%i",++i];
	}
	[self addType:newType withFields:nil];
	
    [typeTableView reloadData];
	
    int row = [types indexOfObject:newType];
    [typeTableView selectRow:row byExtendingSelection:NO];
    [typeTableView editColumn:0 row:row withEvent:nil select:YES];
}

- (IBAction)removeType:(id)sender {
	NSString *oldType = [types objectAtIndex:[typeTableView selectedRow]];
	
	// make sure we stop editing
	[[self window] makeFirstResponder:typeTableView];
	
	[types removeObject:oldType];
	[fieldsForTypesDict removeObjectForKey:oldType];
	
    [typeTableView reloadData];
    [typeTableView deselectAll:nil];
}

- (IBAction)addRequired:(id)sender {
	NSString *newField = [NSString stringWithString:@"New-Field"];
	int i = 0;
	while ([currentRequiredFields containsObject:newField]) {
		newField = [NSString stringWithFormat:@"New-Field-%i",++i];
	}
	[currentRequiredFields addObject:newField];
	
    [requiredTableView reloadData];
	
    int row = [currentRequiredFields indexOfObject:newField];
    [requiredTableView selectRow:row byExtendingSelection:NO];
    [requiredTableView editColumn:0 row:row withEvent:nil select:YES];
}

- (IBAction)removeRequired:(id)sender  {
	NSEnumerator *fieldEnum = [requiredTableView selectedRowEnumerator];
	NSNumber *row;
	NSMutableArray *fieldsToRemove = [NSMutableArray arrayWithCapacity:1];
	
	// make sure we stop editing
	[[self window] makeFirstResponder:requiredTableView];
	
	while (row = [fieldEnum nextObject]) {
		[fieldsToRemove addObject:[currentRequiredFields objectAtIndex:[row intValue]]];
	}
	[currentRequiredFields removeObjectsInArray:fieldsToRemove];
	
    [requiredTableView reloadData];
    [requiredTableView deselectAll:nil];
}

- (IBAction)addOptional:(id)sender {
	NSString *newField = [NSString stringWithString:@"New-Field"];
	int i = 0;
	while ([currentOptionalFields containsObject:newField]) {
		newField = [NSString stringWithFormat:@"New-Field-%i",++i];
	}
	[currentOptionalFields addObject:newField];
	
    [optionalTableView reloadData];
	
    int row = [currentOptionalFields indexOfObject:newField];
    [optionalTableView selectRow:row byExtendingSelection:NO];
    [optionalTableView editColumn:0 row:row withEvent:nil select:YES];
}

- (IBAction)removeOptional:(id)sender {
	NSEnumerator *fieldEnum = [requiredTableView selectedRowEnumerator];
	NSNumber *row;
	NSMutableArray *fieldsToRemove = [NSMutableArray arrayWithCapacity:1];
	
	// make sure we stop editing
	[[self window] makeFirstResponder:optionalTableView];

	
	while (row = [fieldEnum nextObject]) {
		[fieldsToRemove addObject:[currentOptionalFields objectAtIndex:[row intValue]]];
	}
	[currentOptionalFields removeObjectsInArray:fieldsToRemove];
	
    [optionalTableView reloadData];
	[optionalTableView deselectAll:nil];
}

- (IBAction)revertCurrentToDefault:(id)sender {
	if (currentType == nil) 
		return;
	
	[currentRequiredFields removeAllObjects];
	[currentRequiredFields addObjectsFromArray:currentDefaultRequiredFields];
	[currentOptionalFields removeAllObjects];
	[currentOptionalFields addObjectsFromArray:currentDefaultOptionalFields];
	
	[requiredTableView reloadData];
	[optionalTableView reloadData];
}

- (IBAction)revertAllToDefault:(id)sender {
	NSEnumerator *typeEnum = [defaultFieldsForTypesDict keyEnumerator];
	NSString *type;
	
	[fieldsForTypesDict removeAllObjects];
	while (type = [typeEnum nextObject]) {
		[self addType:type withFields:[defaultFieldsForTypesDict objectForKey:type]];
	}
	[types sortUsingSelector:@selector(compare:)];
	[self setCurrentType:nil];
}

#pragma mark validation methods

- (BOOL)canEditType:(NSString *)type {
	return ([defaultFieldsForTypesDict objectForKey:type] == nil);
}

- (BOOL)canEditField:(NSString *)field{
	return (currentType != nil &&
			![currentDefaultRequiredFields containsObject:field] &&
			![currentDefaultOptionalFields containsObject:field]);
}

- (void)updateButtons {
	NSEnumerator *rowEnum;
	NSNumber *row;
	BOOL canRemove;
	NSString *field;
	
	[addTypeButton setEnabled:YES];
	[removeTypeButton setEnabled:(currentType != nil && [self canEditType:currentType])];
	
	[addRequiredButton setEnabled:currentType != nil];
	
	if ([requiredTableView numberOfSelectedRows] == 0) {
		[removeRequiredButton setEnabled:NO];
	} else {
		rowEnum = [requiredTableView selectedRowEnumerator];
		canRemove = YES;
		while (row = [rowEnum nextObject]) {
			field = [currentRequiredFields objectAtIndex:[row intValue]];
			if (![self canEditField:field]) {
				canRemove = NO;
				break;
			}
		}
		[removeRequiredButton setEnabled:canRemove];
	}
	
	[addOptionalButton setEnabled:currentType != nil];
	
	if ([optionalTableView numberOfSelectedRows] == 0) {
		[removeOptionalButton setEnabled:NO];
	} else {
		rowEnum = [optionalTableView selectedRowEnumerator];
		canRemove = YES;
		while (row = [rowEnum nextObject]) {
			field = [currentOptionalFields objectAtIndex:[row intValue]];
			if (![self canEditField:field]) {
				canRemove = NO;
				break;
			}
		}
		[removeOptionalButton setEnabled:canRemove];
	}
	
	[revertCurrentToDefaultButton setEnabled:(currentType != nil)];
}

#pragma mark NSTableview datasource

- (int)numberOfRowsInTableView:(NSTableView *)tv {
	if (tv == typeTableView) {
		return [types count];
	}
	
	if (currentType == nil) return 0;
	
	if (tv == requiredTableView) {
		return [currentRequiredFields count];
	}
	else if (tv == optionalTableView) {
		return [currentOptionalFields count];
	}
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row{
	NSString *value;
	NSDictionary *grayAttr = [NSDictionary dictionaryWithObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName];
	
	// we make default items gray, somehow setting uneditable in ...willDisplayCell:... gives problems with selection
	if (tv == typeTableView) {
		value = [types objectAtIndex:row];
		if ([self canEditType:value]) {
			return value;
		} else {
			return [[[NSAttributedString alloc] initWithString:value attributes:grayAttr] autorelease];
		}
	}
	else if (tv == requiredTableView) {
		value =  [currentRequiredFields objectAtIndex:row];
		if ([self canEditField:value]) {
			return value;
		} else {
			return [[[NSAttributedString alloc] initWithString:value attributes:grayAttr] autorelease];
		}
	}
	else if (tv == optionalTableView) {
		value =  [currentOptionalFields objectAtIndex:row];
		if ([self canEditField:value]) {
			return value;
		} else {
			return [[[NSAttributedString alloc] initWithString:value attributes:grayAttr] autorelease];
		}
	}
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row {
	NSString *oldValue;
	NSString *newValue;
	
	if (tv == typeTableView) {
		oldValue = [types objectAtIndex:row];
		newValue = [(NSString *)object lowercaseString];
		if (![newValue isEqualToString:oldValue] && 
			![types containsObject:newValue]) {
			
			[types replaceObjectAtIndex:row withObject:newValue];
			[fieldsForTypesDict setObject:[fieldsForTypesDict objectForKey:oldValue] forKey:newValue];
			[fieldsForTypesDict removeObjectForKey:oldValue];
			[self setCurrentType:newValue];
		}
	}
	else if (tv == requiredTableView) {
		oldValue = [currentRequiredFields objectAtIndex:row];
		newValue = [(NSString *)object capitalizedString];
		if (![newValue isEqualToString:oldValue] && 
			![currentRequiredFields containsObject:newValue] && 
			![currentOptionalFields containsObject:newValue]) {
			
			[currentRequiredFields replaceObjectAtIndex:row withObject:newValue];
		}
	}
	else if (tv == optionalTableView) {
		oldValue = [currentOptionalFields objectAtIndex:row];
		newValue = [(NSString *)object capitalizedString];
		if (![newValue isEqualToString:oldValue] && 
			![currentRequiredFields containsObject:newValue] && 
			![currentOptionalFields containsObject:newValue]) {
			
			[currentOptionalFields replaceObjectAtIndex:row withObject:newValue];
		}
	}
}

#pragma mark NSTableview delegate

- (BOOL)tableView:(NSTableView *)tv shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row {
	if (tv == typeTableView) {
		return [self canEditType: [types objectAtIndex:row]];
	}
	
	if ([self canEditType:currentType]) // if we can edit the type, we can edit all the fields
		return YES;
	
	if (tv == requiredTableView) {
		return [self canEditField: [currentRequiredFields objectAtIndex:row]];
	} else if (tv == optionalTableView) {
		return [self canEditField: [currentOptionalFields objectAtIndex:row]];
	}
}

#pragma mark NSTableView dragging

- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard {
	// we only drag our own rows
	[pboard declareTypes: [NSArray arrayWithObject:BDSKTypeInfoRowsPboardType] owner:self];
	// write the rows to the pasteboard
	[pboard setPropertyList:rows forType:BDSKTypeInfoRowsPboardType];
	return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op {
	if ([info draggingSource] != tv) // we don't allow dragging between tables, as we want to keep default types in the same place
		return NSDragOperationNone;
	
	if (row == -1) // redirect drops on the table to the first item
		[tv setDropRow:0 dropOperation:NSTableViewDropAbove];
	if (op == NSTableViewDropOn) // redirect drops on an item
		[tv setDropRow:row dropOperation:NSTableViewDropAbove];
	
	return NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo> )info row:(int)row dropOperation:(NSTableViewDropOperation)op {
	NSPasteboard *pboard = [info draggingPasteboard];
	NSArray *rows = [pboard propertyListForType:BDSKTypeInfoRowsPboardType];
	NSEnumerator *rowEnum = [rows objectEnumerator];
	NSNumber *rowNum;
	int i;
	int offset = 0;
	NSMutableArray *fields;
	NSString *field;
	
	// find the array of fields
	if (tv == typeTableView) {
		fields = types;
	} else if (tv == requiredTableView) {
		fields = currentRequiredFields;
	} else if (tv == requiredTableView) {
		fields = currentOptionalFields;
	} 
	
	// move the rows
	while (rowNum = [rowEnum nextObject]) {
		i = [rowNum intValue] - offset;
		if (i < row) {
			--row;
			++offset;
		}
		field = [fields objectAtIndex:i];
		[fields removeObjectAtIndex:i];
		[fields insertObject:field atIndex:row++];
	}
	
	//select the moved rows
	[tv deselectAll:nil];
	for (i = row; i > (row - [rows count]); i--) {
		[tv selectRow:i-1 byExtendingSelection:[tv allowsMultipleSelection]];
	}
	
	[tv reloadData];
}

#pragma mark NSTableView notifications

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	NSTableView *tv = [aNotification object];
	
	if (tv == typeTableView) {
		if ([typeTableView selectedRow] == -1) {
			[self setCurrentType:nil];
		} else {
			[self setCurrentType:[types objectAtIndex:[typeTableView selectedRow]]];
		}
		// the fields changed, so update their tableViews
		[requiredTableView reloadData];
		[optionalTableView reloadData];
	}
	[self updateButtons];
}

@end

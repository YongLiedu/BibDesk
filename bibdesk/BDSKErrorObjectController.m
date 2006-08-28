//
//  BDSKErrorObjectController.m
//  Bibdesk
//
//  Created by Adam Maxwell on 08/12/05.
/*
 This software is Copyright (c) 2005,2006
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
 contributors may be used to endorse or promote products derived
 from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "BDSKErrorObjectController.h"
#import <OmniBase/assertions.h>
#import "BDSKErrorEditor.h"
#import "BibPrefController.h"
#import "BibDocument.h"
#import "BibItem.h"
#import "BibEditor.h"

// put it here because IB chokes on it
@interface BDSKLineNumberTransformer : NSValueTransformer @end

#pragma mark -

@implementation BDSKErrorObjectController

static BDSKErrorObjectController *sharedErrorObjectController = nil;

+ (void)initialize;
{
    OBINITIALIZE;
	[NSValueTransformer setValueTransformer:[[[BDSKLineNumberTransformer alloc] init] autorelease]
									forName:@"BDSKLineNumberTransformer"];
}

+ (BDSKErrorObjectController *)sharedErrorObjectController;
{
    if(!sharedErrorObjectController)
        sharedErrorObjectController = [[BDSKErrorObjectController alloc] init];
    return sharedErrorObjectController;
}

- (id)init;
{
    if(self = [super initWithWindowNibName:[self windowNibName]]){
        if(sharedErrorObjectController){
            [self release];
            self = sharedErrorObjectController;
        } else {
            errors = [[NSMutableArray alloc] initWithCapacity:10];
            managers = [[NSMutableArray alloc] initWithCapacity:4];
            editors = [[NSMutableArray alloc] initWithCapacity:2];
            
            [managers addObject:[BDSKPlaceHolderFilterItem allItemsPlaceHolderFilterItem]];
            [managers addObject:[BDSKPlaceHolderFilterItem emptyItemsPlaceHolderFilterItem]];
            
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(handleErrorNotification:)
                                                         name:BDSKParserErrorNotification
                                                       object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(handleRemoveDocumentNotification:)
                                                         name:BDSKDocumentControllerRemoveDocumentNotification
                                                       object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(handleRemovePublicationNotification:)
                                                         name:BDSKDocDelItemNotification
                                                       object:nil];
        }
    }
    
    return self;
}

- (NSString *)windowNibName;
{
    return @"BDSKErrorPanel";
}


- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [errors release];
    [managers release];
    [editors release];
    [currentErrors release];
    [super dealloc];
}

- (void)awakeFromNib;
{
    [errorTableView setDoubleAction:@selector(gotoError:)];
    
    [errorsController setFilterKey:@"editor"];
    [errorsController setFilterValue:[BDSKPlaceHolderFilterItem allItemsPlaceHolderFilterItem]];
    [errorsController setWarningKey:@"errorClassName"];
    [errorsController setWarningValue:BDSKParserWarningString];
    [errorsController setHideWarnings:NO];
}

#pragma mark Accessors

// errors

- (NSArray *)errors {
    return [[errors retain] autorelease];
}

- (unsigned)countOfErrors {
    return [errors count];
}

- (id)objectInErrorsAtIndex:(unsigned)index {
    return [errors objectAtIndex:index];
}

- (void)insertObject:(id)obj inErrorsAtIndex:(unsigned)index {
    [errors insertObject:obj atIndex:index];
}

- (void)removeObjectFromErrorsAtIndex:(unsigned)index {
    [errors removeObjectAtIndex:index];
}

// managers

- (NSArray *)managers {
    return [[managers retain] autorelease];
}

- (unsigned)countOfManagers {
    return [managers count];
}

- (id)objectInManagersAtIndex:(unsigned)theIndex {
    return [managers objectAtIndex:theIndex];
}

- (void)insertObject:(id)obj inManagersAtIndex:(unsigned)theIndex {
    [managers insertObject:obj atIndex:theIndex];
}

- (void)removeObjectFromManagersAtIndex:(unsigned)theIndex {
    [managers removeObjectAtIndex:theIndex];
}

// editors

- (NSArray *)editors{
    return editors;
}

#pragma mark Error editors

- (void)addEditor:(BDSKErrorEditor *)editor{
    [editor setErrorController:self];
    [editors addObject:editor];
}

- (void)removeEditor:(BDSKErrorEditor *)editor{
    // remove all errors associated to this controller
	unsigned index = [self countOfErrors];
    BDSKErrorObject *errObj;
    
    while (index--) {
		errObj = [self objectInErrorsAtIndex:index];
        if ([errObj editor] == editor) {
            [self removeObjectFromErrorsAtIndex:index];
    	}
    }
    
    if ([errorsController filterValue] == editor)
        [errorsController setFilterValue:[BDSKPlaceHolderFilterItem allItemsPlaceHolderFilterItem]];
	if ([managers containsObject:editor])
		[self removeObjectFromManagersAtIndex:[managers indexOfObject:editor]];
    [editor setErrorController:nil];
    [editors removeObject:editor];
}

- (BDSKErrorEditor *)editorForDocument:(BibDocument *)document create:(BOOL)create{
    NSEnumerator *eEnum = [editors objectEnumerator];
    BDSKErrorEditor *editor = nil;
    BDSKErrorEditor *docEditor = nil;
    int number = 0;
    NSString *fileName = [[document fileName] lastPathComponent];
    
    while(editor = [eEnum nextObject]){
        if(document == [editor sourceDocument])
            docEditor = editor;
        if(create && [fileName isEqualToString:[[editor fileName] lastPathComponent]])
            number = MAX(number, [editor uniqueNumber] + 1);
    }
    
    if(docEditor == nil && create){
        docEditor = [[BDSKErrorEditor alloc] initWithFileName:[document fileName] andDocument:document];
        [docEditor setUniqueNumber:number];
        [self addEditor:docEditor];
        [docEditor release];
        [self insertObject:docEditor inManagersAtIndex:[self countOfManagers]];
    }
    
    return docEditor;
}

- (BDSKErrorEditor *)editorForFileName:(NSString *)fileName create:(BOOL)create{
    NSEnumerator *eEnum = [editors objectEnumerator];
    BDSKErrorEditor *editor = nil;
    
    while(editor = [eEnum nextObject]){
        if([fileName isEqualToString:[editor fileName]])
            break;
    }
    
    if(editor == nil && create){
        editor = [[BDSKErrorEditor alloc] initWithFileName:fileName];
        [self addEditor:editor];
        [editor release];
    }
    
    return editor;
}

// edit failed paste/drag data
- (void)showEditorForFileName:(NSString *)fileName{
    // we create a new editor without a document, because the data is not part of the document's source file
    BDSKErrorEditor *editor = [self editorForFileName:fileName create:YES];
    [self showErrorPanel:self];
    [editor showWindow:self];
}

// double click in the error tableview
- (void)showEditorForErrorObject:(BDSKErrorObject *)errObj{
    NSString *fileName = [errObj fileName];
    
    if ([fileName isEqualToString:BDSKParserPasteDragString]) {
        NSBeep();
    } else if ([fileName isEqualToString:BDSKAuthorString]) {
        BibItem *pub = [errObj publication];
        if(pub) {
            BibEditor *editor = [[pub document] editPub:pub];
            [editor makeKeyField:BDSKAuthorString];
        } else NSBeep();
    } else if ([[NSFileManager defaultManager] fileExistsAtPath:fileName]) {
        BDSKErrorEditor *editor = [errObj editor];
        [editor showWindow:self];
        [editor gotoLine:[errObj lineNumber]];
    } else NSBeep();
}

// failed load of a document
- (void)documentFailedLoad:(BibDocument *)document shouldEdit:(BOOL)shouldEdit{
    if(shouldEdit)
        [self showErrorPanel:self];
	
    // remove any earlier failed load editors unless we're editing them
    unsigned index = [editors count];
    BDSKErrorEditor *editor;
    
    while (index--) {
        editor = [editors objectAtIndex:index];
        if([editor sourceDocument] == document){
           [editor setSourceDocument:nil];
           if(shouldEdit)
                [editor showWindow:self];
        }else if([editor isEditing] == NO){
            [self removeEditor:editor];
        }
    }
    
    [self removePublications:[document publications]];
}

// remove a document
- (void)handleRemoveDocumentNotification:(NSNotification *)notification{
    BibDocument *document = [notification object];
    // clear reference to document in its editor and close it when it is not editing
    BDSKErrorEditor *editor = [self editorForDocument:document create:NO]; // there should be at most one
    
    if(editor){
        [editor setSourceDocument:nil];
        if([editor isEditing] == NO)
            [self removeEditor:editor];
    }
    
    [self removePublications:[document publications]];
}

// remove a publication
- (void)handleRemovePublicationNotification:(NSNotification *)notification{
    NSArray *pubs = [[notification userInfo] objectForKey:@"pubs"];
    [self removePublications:pubs];
}

- (void)removePublications:(NSArray *)pubs{
    NSEnumerator*errEnum = [errors objectEnumerator];
    BDSKErrorObject *errObj;
    BibItem *pub;
    
    while(errObj = [errEnum nextObject]){
        pub = [errObj publication];
        if([pubs containsObject:pub])
            [errObj setPublication:nil];
    }
}

#pragma mark Actions

- (IBAction)toggleShowingErrorPanel:(id)sender{
    if (![[self window] isVisible]) {
        [self showErrorPanel:sender];
    }else{
        [self hideErrorPanel:sender];
    }
}

- (IBAction)hideErrorPanel:(id)sender{
    [[self window] orderOut:sender];
}

- (IBAction)showErrorPanel:(id)sender{
    [[self window] makeKeyAndOrderFront:sender];
}

// copy error messages
- (IBAction)copy:(id)sender{
    if([[self window] isKeyWindow] && [errorTableView numberOfSelectedRows] > 0){
        NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
        NSMutableString *s = [[NSMutableString string] retain];
        NSEnumerator *objEnumerator = [[errorsController selectedObjects] objectEnumerator];
        NSString *fileName;
		int lineNumber;
        
        // Columns order:  @"File Name\t\tLine Number\t\tMessage Type\t\tMessage Text\n"];
		BDSKErrorObject *errObj;
		
        while(errObj = [objEnumerator nextObject]){
            fileName = [errObj displayFileName];
            [s appendString:fileName ? fileName : @""];
            [s appendString:@"\t\t"];
            
			lineNumber = [errObj lineNumber];
			if(lineNumber == -1)
				[s appendString:NSLocalizedString(@"Unknown line number",@"unknown line number for error")];
			else
				[s appendFormat:@"%i", lineNumber];
            [s appendString:@"\t\t"];
            
            [s appendString:[errObj errorClassName]];
            [s appendString:@"\t\t"];
            
            [s appendString:[errObj errorMessage]];
            [s appendString:@"\n\n"];
        }
        [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
        [pasteboard setString:s forType:NSStringPboardType];
    }
    
}

- (IBAction)gotoError:(id)sender{
    int clickedRow = [sender clickedRow];
    if(clickedRow != -1)
        [self showEditorForErrorObject:[[errorsController arrangedObjects] objectAtIndex:clickedRow]];
}

#pragma mark Menu validation

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem{
	SEL act = [menuItem action];

	if (act == @selector(toggleShowingErrorPanel:)){ 
		// menu item for toggling the error panel
		// set the on/off state according to the panel's visibility
		if ([[self window] isVisible]) {
			[menuItem setState:NSOnState];
		}else {
			[menuItem setState:NSOffState];
		}
	}
    return YES;
}

#pragma mark Error notification handling

- (void)startObservingErrorsForDocument:(BibDocument *)document{
    [self startObservingErrorsForDocument:document publication:nil];
}

- (void)startObservingErrorsForDocument:(BibDocument *)document publication:(BibItem *)pub{
    if(currentErrors == nil){
        currentErrors = [[NSMutableArray alloc] initWithCapacity:10];
    } else {
        OBASSERT([currentErrors count] == 0);
        [currentErrors removeAllObjects];
    }
}

- (void)endObservingErrorsForDocument:(BibDocument *)document{
    [self endObservingErrorsForDocument:document publication:nil];
}

- (void)endObservingErrorsForDocument:(BibDocument *)document publication:(BibItem *)pub{
    if([currentErrors count]){
        if(document != nil){ // this should happen only for temporary authors, which we ignore as they don't belong to any document
            id editor =  (document == nil) ? nil : [self editorForDocument:document create:YES];
            [currentErrors makeObjectsPerformSelector:@selector(setEditor:) withObject:editor];
            if(pub)
                [currentErrors makeObjectsPerformSelector:@selector(setPublication:) withObject:pub];
            [[self mutableArrayValueForKey:@"errors"] addObjectsFromArray:currentErrors];
            if([[self window] isVisible] == NO && [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShowWarningsKey])
                [self showErrorPanel:self];
        }
        [currentErrors removeAllObjects];
    }
}

- (void)handleErrorNotification:(NSNotification *)notification{
    BDSKErrorObject *errObj = [notification object];
    // don't show lexical buffer overflow warnings
    if ([[errObj errorClassName] isEqualToString:BDSKParserHarmlessWarningString] == NO)
		[currentErrors addObject:errObj];
}

#pragma mark TableView tooltips

- (NSString *)tableView:(NSTableView *)aTableView toolTipForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex{
	return [[[errorsController arrangedObjects] objectAtIndex:rowIndex] errorMessage];
}

@end

#pragma mark -
#pragma mark Error object accessors

@implementation BDSKErrorObject (BDSKExtensions)

- (NSString *)displayFileName {
	NSString *docFileName = [editor displayName];
    if (docFileName == nil)
		docFileName = [fileName lastPathComponent];
	if (docFileName == nil)
        docFileName = @"?";
    else if (fileName == nil || [fileName isEqualToString:BDSKParserPasteDragString] || [fileName isEqualToString:BDSKAuthorString])
        docFileName = [NSString stringWithFormat:@"[%@]", docFileName];
    return docFileName;
}

@end

#pragma mark -
#pragma mark Placeholder objects for filter menu

@implementation BDSKPlaceHolderFilterItem

static BDSKPlaceHolderFilterItem *allItemsPlaceHolderFilterItem = nil;
static BDSKPlaceHolderFilterItem *emptyItemsPlaceHolderFilterItem = nil;

+ (void)initialize {
	allItemsPlaceHolderFilterItem = [[BDSKPlaceHolderFilterItem alloc] initWithDisplayName:NSLocalizedString(@"All", @"All")];
	emptyItemsPlaceHolderFilterItem = [[BDSKPlaceHolderFilterItem alloc] initWithDisplayName:NSLocalizedString(@"Empty", @"Empty")];
}

+ (BDSKPlaceHolderFilterItem *)allItemsPlaceHolderFilterItem { return allItemsPlaceHolderFilterItem; };
+ (BDSKPlaceHolderFilterItem *)emptyItemsPlaceHolderFilterItem { return emptyItemsPlaceHolderFilterItem; };

- (id)valueForUndefinedKey:(NSString *)keyPath {
	return displayName;
}

- (id)initWithDisplayName:(NSString *)name {
	if (self = [super init]) {
		displayName = [name copy];
	}
	return self;
}

@end

#pragma mark -
#pragma mark Array controller for error objects

@implementation BDSKFilteringArrayController

- (NSArray *)arrangeObjects:(NSArray *)objects {
	BOOL filterByKey = (filterValue != nil && filterValue != [BDSKPlaceHolderFilterItem allItemsPlaceHolderFilterItem] && [NSString isEmptyString:filterKey] == NO);
    BOOL filterWarnings = (hideWarnings == YES && [NSString isEmptyString:warningKey] == NO && [NSString isEmptyString:warningValue] == NO);
    
    if(filterByKey || filterWarnings){
        NSMutableArray *matchedObjects = [NSMutableArray arrayWithCapacity:[objects count]];
        
        NSEnumerator *itemEnum = [objects objectEnumerator];
        id item;	
        while (item = [itemEnum nextObject]) {
            id value = [item valueForKeyPath:filterKey];
            if ((filterByKey == NO || (filterValue == [BDSKPlaceHolderFilterItem emptyItemsPlaceHolderFilterItem] && value == nil) || [value isEqual:filterValue]) &&
                (filterWarnings == NO || [warningValue isEqual:[item valueForKey:warningKey]] == NO) ) {
                [matchedObjects addObject:item];
            }
        }
        
        objects = matchedObjects;
    }
    return [super arrangeObjects:objects];
}

- (void)dealloc {
    [self setFilterValue: nil];    
    [self setFilterKey: nil];    
    [super dealloc];
}

- (id)filterValue {
	return filterValue;
}

- (void)setFilterValue:(id)newValue {
    if (filterValue != newValue) {
        [filterValue autorelease];
        filterValue = [newValue retain];
		[self rearrangeObjects];
    }
}

- (NSString *)filterKey {
    return [[filterKey retain] autorelease];
}

- (void)setFilterKey:(NSString *)newKey {
    if (filterKey != newKey) {
        [filterKey release];
        filterKey = [newKey retain];
		[self rearrangeObjects];
    }
}

- (NSString *)warningKey {
    return [[warningKey retain] autorelease];
}

- (void)setWarningKey:(NSString *)newKey {
    if (warningKey != newKey) {
        [warningKey autorelease];
        warningKey = [newKey retain];
		[self rearrangeObjects];
    }
}

- (NSString *)warningValue {
    return [[warningValue retain] autorelease];
}

- (void)setWarningValue:(NSString *)newValue {
    if (warningValue != newValue) {
        [warningValue autorelease];
        warningValue = [newValue retain];
		[self rearrangeObjects];
    }
}

- (BOOL)hideWarnings {
    return hideWarnings;
}

- (void)setHideWarnings:(BOOL)flag {
    if(hideWarnings != flag) {
        hideWarnings = flag;
		[self rearrangeObjects];
    }
}

@end

#pragma mark -
#pragma mark Line number transformer

@implementation BDSKLineNumberTransformer

+ (Class)transformedValueClass {
    return [NSObject class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)number {
	return ([number intValue] == -1) ? @"?" : number;
}

@end

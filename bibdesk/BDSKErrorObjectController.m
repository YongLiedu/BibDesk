//
//  BDSKErrorObjectController.m
//  Bibdesk
//
//  Created by Adam Maxwell on 08/12/05.
/*
 This software is Copyright (c) 2005-2011
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
#import "BDSKErrorObject.h"
#import "BDSKErrorManager.h"
#import "BDSKErrorEditor.h"
#import "BDSKStringConstants.h"
#import "BDSKOwnerProtocol.h"
#import "BibDocument.h"
#import "BibDocument_Actions.h"
#import "BibItem.h"
#import "BDSKEditor.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKTableView.h"

#define BDSKLineNumberTransformerName @"BDSKLineNumberTransformer"

#define BDSKErrorPanelFrameAutosaveName @"BDSKErrorPanel"

// put it here because IB chokes on it
@interface BDSKLineNumberTransformer : NSValueTransformer @end

#pragma mark -

@implementation BDSKErrorObjectController

static BDSKErrorObjectController *sharedErrorObjectController = nil;

+ (void)initialize;
{
    BDSKINITIALIZE;
	[NSValueTransformer setValueTransformer:[[[BDSKLineNumberTransformer alloc] init] autorelease] forName:BDSKLineNumberTransformerName];
}

+ (BDSKErrorObjectController *)sharedErrorObjectController;
{
    if (sharedErrorObjectController == nil)
        sharedErrorObjectController = [[BDSKErrorObjectController alloc] init];
    return sharedErrorObjectController;
}

- (id)init;
{
    BDSKPRECONDITION(sharedErrorObjectController == nil);
    self = [super initWithWindowNibName:@"BDSKErrorPanel"];
    if (self) {
        errors = [[NSMutableArray alloc] initWithCapacity:10];
        managers = [[NSMutableArray alloc] initWithCapacity:4];
        lastIndex = 0;
        handledNonIgnorableError = NO;
        
        [managers addObject:[BDSKErrorManager allItemsErrorManager]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRemoveDocumentNotification:)
                                                     name:BDSKDocumentControllerRemoveDocumentNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRemovePublicationNotification:)
                                                     name:BDSKDocDelItemNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)awakeFromNib;
{
    [self setWindowFrameAutosaveName:BDSKErrorPanelFrameAutosaveName];
    
    [[self window] setAutorecalculatesContentBorderThickness:NO forEdge:NSMinYEdge];
    [[self window] setContentBorderThickness:24.0 forEdge:NSMinYEdge];
    
    for (id view in [[[self window] contentView] subviews]) {
        if ([view isKindOfClass:[NSTextField class]] || [view isKindOfClass:[NSButton class]])
            [[view cell] setBackgroundStyle:NSBackgroundStyleRaised];
    }
    
    [errorTableView setDoubleAction:@selector(gotoError:)];
    
    [errorsController setFilterManager:[BDSKErrorManager allItemsErrorManager]];
    [errorsController setHideWarnings:NO];
}

#pragma mark Accessors

#pragma mark | errors

- (NSArray *)errors {
    return errors;
}

- (NSUInteger)countOfErrors {
    return [errors count];
}

- (id)objectInErrorsAtIndex:(NSUInteger)idx {
    return [errors objectAtIndex:idx];
}

- (void)insertObject:(id)obj inErrorsAtIndex:(NSUInteger)idx {
    [errors insertObject:obj atIndex:idx];
}

- (void)removeObjectFromErrorsAtIndex:(NSUInteger)idx {
    [errors removeObjectAtIndex:idx];
}

#pragma mark | managers

- (NSArray *)managers {
    return managers;
}

- (NSUInteger)countOfManagers {
    return [managers count];
}

- (id)objectInManagersAtIndex:(NSUInteger)theIndex {
    return [managers objectAtIndex:theIndex];
}

- (void)insertObject:(id)obj inManagersAtIndex:(NSUInteger)theIndex {
    [managers insertObject:obj atIndex:theIndex];
}

- (void)removeObjectFromManagersAtIndex:(NSUInteger)theIndex {
    [managers removeObjectAtIndex:theIndex];
}

- (void)addManager:(BDSKErrorManager *)manager{
    [manager setErrorController:self];
    [self insertObject:manager inManagersAtIndex:[self countOfManagers]];
}

- (void)removeManager:(BDSKErrorManager *)manager{
    if ([errorsController filterManager] == manager)
        [errorsController setFilterManager:[BDSKErrorManager allItemsErrorManager]];
    [manager setErrorController:nil];
    [self removeObjectFromManagersAtIndex:[managers indexOfObject:manager]];
}

#pragma mark Getting editors

- (BDSKErrorEditor *)editorForDocument:(BibDocument *)document pasteDragData:(NSData *)data{
    BDSKASSERT(document != nil);
    
    BDSKErrorEditor *editor = nil;
    BDSKErrorManager *manager = nil;
    
    for (manager in managers) {
        if(document == [manager sourceDocument])
            break;
    }
    
    if (manager == nil) {
        manager = [(BDSKErrorManager *)[BDSKErrorManager alloc] initWithDocument:document];
        [self addManager:manager];
        [manager release];
    }
    
    if (data) {
        editor = [[BDSKErrorEditor alloc] initWithPasteDragData:data];
        [manager addEditor:editor];
        [editor release];
    } else {
        editor = [manager mainEditor];
        if (editor == nil) {
            editor = [(BDSKErrorEditor *)[BDSKErrorEditor alloc] initWithFileName:[[document fileURL] path]];
            [manager addEditor:editor];
            [editor release];
        }
    }
    
    return editor;
}

// double click in the error tableview
- (void)showEditorForErrorObject:(BDSKErrorObject *)errObj{
    NSString *fileName = [errObj fileName];
    BDSKErrorEditor *editor = [errObj editor];
    BibItem *pub = [errObj publication];

    // fileName is nil for paste/drag and author parsing errors; check for a pub first, since that's the best way to edit
    if (pub) {
        // if we have an error for a pub, it should be from a BibDocument. Otherwise we would have ignored it, see endObservingErrorsForDocument:...
        BDSKEditor *pubEditor = [(BibDocument *)[pub owner] editPub:pub];
        [pubEditor setKeyField:BDSKAuthorString];
    } else if (nil == fileName || [[NSFileManager defaultManager] fileExistsAtPath:fileName]) {
        [editor showWindow:self];
        [editor gotoLine:[errObj lineNumber]];
    } else NSBeep();
}

// edit paste/drag error; sent via document error panel displayed when paste fails
- (void)showEditorForLastPasteDragError{
    if(lastIndex < [self countOfErrors]){
        BDSKErrorObject *errObj = [self objectInErrorsAtIndex:lastIndex];
        BDSKASSERT([[errObj editor] isPasteDrag]);
        [self showWindow:self];
        [self showEditorForErrorObject:errObj];
        NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(lastIndex, [self countOfErrors] - lastIndex)];
        [errorTableView selectRowIndexes:indexes byExtendingSelection:NO];
    }else NSBeep();
}

#pragma mark Managing managers, editors and errors

// failed load of a document
- (void)documentFailedLoad:(BibDocument *)document shouldEdit:(BOOL)shouldEdit{
    if(shouldEdit)
        [self showWindow:self];
	
    // remove any earlier failed load editors unless we're editing them
    NSUInteger idx = [managers count];
    BDSKErrorManager *manager;
    
    while (idx--) {
        manager = [managers objectAtIndex:idx];
        if([manager sourceDocument] == document){
            [manager setSourceDocument:nil];
            if(shouldEdit)
                [[manager mainEditor] showWindow:self];
        }else if([manager sourceDocument] == nil && manager != [BDSKErrorManager allItemsErrorManager]){
            [manager removeClosedEditors];
        }
    }
    
    // there shouldn't be any at this point, but just make sure
    [self removeErrorsForPublications:[document publications]];
}

// remove a document
- (void)handleRemoveDocumentNotification:(NSNotification *)notification{
    BibDocument *document = [notification object];
    // clear reference to document in its editors and close it when it is not editing
    NSUInteger idx = [managers count];
    BDSKErrorManager *manager;
    
    while (idx--) {
        manager = [managers objectAtIndex:idx];
        if([[manager sourceDocument] isEqual:document]){
            [manager setSourceDocument:nil];
            [manager removeClosedEditors];
        }
    }
    
    if ([document respondsToSelector:@selector(publications)])
    [self removeErrorsForPublications:[document publications]];
}

// remove a publication
- (void)handleRemovePublicationNotification:(NSNotification *)notification{
    NSArray *pubs = [[notification userInfo] objectForKey:BDSKDocumentPublicationsKey];
    [self removeErrorsForPublications:pubs];
}

- (void)removeErrorsForPublications:(NSArray *)pubs{
	NSUInteger idx = [self countOfErrors];
    BibItem *pub;
    
    NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];
     
    while (idx--) {
		pub = [[self objectInErrorsAtIndex:idx] publication];
        if(pub && [pubs containsObject:pub])
            [indexesToRemove addIndex:idx];
    }
    
    // batch changes
    [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexesToRemove forKey:@"errors"];
    [errors removeObjectsAtIndexes:indexesToRemove];
    [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexesToRemove forKey:@"errors"];
}

- (void)removeErrorsForEditor:(BDSKErrorEditor *)editor{
	NSUInteger idx = [self countOfErrors];
    BDSKErrorObject *errObj;
    
    NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];

    while (idx--) {
		errObj = [self objectInErrorsAtIndex:idx];
        if ([[errObj editor] isEqual:editor]) {
            [indexesToRemove addIndex:idx];
    	}
    }
    // batch these; this method is particularly slow (order of minutes) with a large number of errors, when closing the associated document, since using [self removeObjectFromErrorsAtIndex:index] in the loop causes KVO notifications to reload the tableview (although the tooltip rebuild appears to be what kills performance)
    [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexesToRemove forKey:@"errors"];
    [errors removeObjectsAtIndexes:indexesToRemove];
    [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexesToRemove forKey:@"errors"];
}

#pragma mark Actions

// copy error messages
- (IBAction)copy:(id)sender{
    if ([errorTableView canCopy])
        [errorTableView copy:nil];
    else
        NSBeep();
}

- (IBAction)gotoError:(id)sender{
    NSInteger clickedRow = [sender clickedRow];
    if(clickedRow != -1)
        [self showEditorForErrorObject:[[errorsController arrangedObjects] objectAtIndex:clickedRow]];
}

#pragma mark Error notification handling

- (void)startObservingErrors{
    if(currentErrors == nil){
        currentErrors = [[NSMutableArray alloc] initWithCapacity:10];
    } else {
        BDSKASSERT([currentErrors count] == 0);
        [currentErrors removeAllObjects];
    }
    lastIndex = [self countOfErrors];
}

- (void)endObservingErrorsForDocument:(BibDocument *)document pasteDragData:(NSData *)data {
    if([currentErrors count]){
        if(document != nil){ // this should happen only for temporary author objects, which we ignore as they don't belong to any document
            BDSKErrorEditor *editor = [self editorForDocument:document pasteDragData:data];
            [editor setErrors:currentErrors];
            [currentErrors setValue:editor forKey:@"editor"];
            [[self mutableArrayValueForKey:@"errors"] addObjectsFromArray:currentErrors];
            if([self isWindowVisible] == NO && (handledNonIgnorableError || [[NSUserDefaults standardUserDefaults] boolForKey:BDSKShowWarningsKey]))
                [self showWindow:self];
            handledNonIgnorableError = NO;
        }
        [currentErrors removeAllObjects];
    }
}

- (void)endObservingErrorsForPublication:(BibItem *)pub{
    id document = [pub owner];
    // we can't and shouldn't manage errors from external groups
    if ([document isDocument] == NO)
        document = nil;
    [currentErrors setValue:pub forKey:@"publication"];
    [self endObservingErrorsForDocument:document pasteDragData:nil];
}

- (void)reportError:(BDSKErrorObject *)obj{
    [currentErrors addObject:obj];
    
    // set a flag so we know that the window should be displayed after endObserving:...
    if (NO == handledNonIgnorableError && [obj isIgnorableWarning] == NO)
        handledNonIgnorableError = YES;
    
}

#pragma mark TableView delegate

- (NSString *)tableView:(NSTableView *)tv toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation{
	return [[[errorsController arrangedObjects] objectAtIndex:row] errorMessage];
}

#pragma mark TableView dataSource

// dummy, we use bindings
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv { return 0; }
- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)row { return nil; }

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    NSMutableString *s = [[NSMutableString string] retain];
    NSInteger lineNumber;
    
    for (BDSKErrorObject *errObj in [errorsController selectedObjects]) {
        [s appendString:[[errObj editor] displayName]];
        [s appendString:@"\t\t"];
        
        lineNumber = [errObj lineNumber];
        if(lineNumber == -1)
            [s appendString:NSLocalizedString(@"Unknown line number", @"Error message for error window")];
        else
            [s appendFormat:@"%ld", (long)lineNumber];
        [s appendString:@"\t\t"];
        
        [s appendString:[errObj errorClassName]];
        [s appendString:@"\t\t"];
        
        [s appendString:[errObj errorMessage]];
        [s appendString:@"\n\n"];
    }
    [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pboard setString:s forType:NSStringPboardType];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView draggingSourceOperationMaskForLocal:(BOOL)flag {
    return NSDragOperationEvery;
}

@end

#pragma mark -
#pragma mark Array controller for error objects

@implementation BDSKFilteringArrayController

- (NSArray *)arrangeObjects:(NSArray *)objects {
    BDSKErrorManager *manager = filterManager == [BDSKErrorManager allItemsErrorManager] ? nil : filterManager;
    if(hideWarnings || manager){
        NSMutableArray *matchedObjects = [NSMutableArray arrayWithCapacity:[objects count]];
        
        for (id item in objects) {
            if(manager && manager != [[item editor] manager])
                continue;
            if(hideWarnings && [item isIgnorableWarning])
                continue;
            [matchedObjects addObject:item];
        }
        
        objects = matchedObjects;
    }
    return [super arrangeObjects:objects];
}

- (void)dealloc {
    [self setFilterManager: nil];    
    [super dealloc];
}

- (BDSKErrorManager *)filterManager {
	return filterManager;
}

- (void)setFilterManager:(BDSKErrorManager *)manager {
    if (filterManager != manager) {
        [filterManager release];
        filterManager = [manager retain];
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
	return ([number integerValue] == -1) ? @"?" : number;
}

@end

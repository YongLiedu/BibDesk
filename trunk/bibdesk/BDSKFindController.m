//
//  BDSKFindController.m
//  Bibdesk
//
//  Created by Adam Maxwell on 06/21/05.
//
/*
 This software is Copyright (c) 2005-2012
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

#import "BDSKFindController.h"
#import "BDSKTypeManager.h"
#import "BibDocument.h"
#import "BDSKComplexString.h"
#import "BibDocument+Scripting.h"
#import "BibDocument_Search.h"
#import "BibDocument_Groups.h"
#import <AGRegex/AGRegex.h>
#import "BibItem.h"
#import "BDSKFiler.h"
#import "BDSKFindFieldEditor.h"
#import "BDSKLinkedFile.h"
#import "NSArray_BDSKExtensions.h"
#import "BDSKFieldNameFormatter.h"

#define MAX_HISTORY_COUNT	10

#define BDSKFindPanelFrameAutosaveName @"BDSKFindPanel"

#define BDSKFindErrorDomain @"BDSKFindErrorDomain"

static BDSKFindController *sharedFC = nil;

enum {
    FCTextualSearch = 0,
    FCRegexSearch = 1
};

enum {
    FCContainsSearch = 0,
    FCStartsWithSearch = 1,
    FCWholeFieldSearch = 2,
    FCEndsWithSearch = 3,
};

enum {
    FCOperationFindAndReplace = 0,
    FCOperationOverwrite = 1,
    FCOperationPrepend = 2,
    FCOperationAppend = 3,
};

@implementation BDSKFindController

+ (BDSKFindController *)sharedFindController{
    if(sharedFC == nil)
        sharedFC = [[BDSKFindController alloc] init];
    return sharedFC;
}

- (id)init {
    BDSKPRECONDITION(sharedFC == nil);
    self = [super initWithWindowNibName:@"BDSKFindPanel"];
    if (self) {
		NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSFindPboard];
		NSString *availableType = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]];
        
		findFieldEditor = nil;
		
		findHistory = [[NSMutableArray alloc] initWithCapacity:MAX_HISTORY_COUNT == NSNotFound ? 10 : MAX_HISTORY_COUNT];
		replaceHistory = [[NSMutableArray alloc] initWithCapacity:MAX_HISTORY_COUNT == NSNotFound ? 10 : MAX_HISTORY_COUNT];
        
		findString = [((availableType == nil)? @"" : [pboard stringForType:NSStringPboardType]) copy];
        replaceString = [@"" retain];
        searchType = FCTextualSearch;
        searchScope = FCContainsSearch;
        ignoreCase = YES;
        wrapAround = YES;
        searchSelection = YES;
        findAsMacro = NO;
        replaceAsMacro = NO;
		shouldSetWhenEmpty = NO;
        operation = FCOperationFindAndReplace;
		
		replaceAllTooltip = [NSLocalizedString(@"Replace all matches.", @"Tool tip message") retain];
    }
    return self;
}

- (void)dealloc {
	BDSKDESTROY(findFieldEditor);
    BDSKDESTROY(findString);
    BDSKDESTROY(replaceString);
	BDSKDESTROY(statusBar);
	BDSKDESTROY(replaceAllTooltip);
    [super dealloc];
}

- (void)windowDidLoad{
    [self setWindowFrameAutosaveName:BDSKFindPanelFrameAutosaveName];
    
    [[self window] setCollectionBehavior:NSWindowCollectionBehaviorMoveToActiveSpace];
    
    BDSKTypeManager *btm = [BDSKTypeManager sharedManager];
    NSMutableArray *extraFields = [NSMutableArray arrayWithObjects:BDSKCiteKeyString, BDSKPubTypeString, BDSKRemoteURLString, nil];
    [extraFields addObjectsFromArray:[[btm noteFieldsSet] allObjects]];
	NSArray *fields = [btm allFieldNamesIncluding:extraFields excluding:nil];
    [fieldToSearchComboBox removeAllItems];
	[fieldToSearchComboBox addItemsWithObjectValues:fields];

    // make sure we enter valid field names
    BDSKFieldNameFormatter *formatter = [[BDSKFieldNameFormatter alloc] init];
    [formatter setKnownFieldNames:fields];
    [fieldToSearchComboBox setFormatter:formatter];
    [formatter release];
	
    [[self window] setAutorecalculatesContentBorderThickness:NO forEdge:NSMinYEdge];
    [[self window] setContentBorderThickness:22.0 forEdge:NSMinYEdge];
    
	[statusBar retain]; // we need to retain, as we might remove it from the window
    if (![[NSUserDefaults standardUserDefaults] boolForKey:BDSKShowFindStatusBarKey]) {
		[self toggleStatusBar:nil];
	}
    
	// IB does not allow us to set the maxSize.height equal to the minSize.height for some reason, but it should be only horizontally resizable
	NSSize maxWindowSize = [[self window] maxSize];
	maxWindowSize.height = [[self window] minSize].height;
	[[self window] setMaxSize:maxWindowSize];
	
	// this fixes a bug with initialization of the menuItem states when using bindings
	NSInteger numItems = [searchTypePopUpButton numberOfItems];
	NSInteger i;
	for (i = 0; i < numItems; i++) 
		if ([searchTypePopUpButton indexOfSelectedItem] != i)
			[[searchTypePopUpButton itemAtIndex:i] setState:NSOffState];
	numItems = [searchScopePopUpButton numberOfItems];
	for (i = 0; i < numItems; i++) 
		if ([searchScopePopUpButton indexOfSelectedItem] != i)
			[[searchScopePopUpButton itemAtIndex:i] setState:NSOffState];
	
    [self updateUI];
}

- (void)updateUI{
	if(NO == [self findAsMacro] && [self replaceAsMacro] && FCOperationFindAndReplace == [self operation]){
        [searchScopePopUpButton setEnabled:NO];
		[statusBar setStringValue:NSLocalizedString(@"With these settings, only full strings will be replaced", @"Status message")];
	}else{
        [searchScopePopUpButton setEnabled:FCOperationFindAndReplace == [self operation]];
		[statusBar setStringValue:@""];
    }
    
    BOOL isRemoteURL = [[self field] isEqualToString:BDSKRemoteURLString];
    [findAsMacroCheckbox setEnabled:NO == isRemoteURL];
    [replaceAsMacroCheckbox setEnabled:NO == isRemoteURL];
    
	if (FCOperationOverwrite == [self operation]) {
		[self setReplaceLabel:NSLocalizedString(@"Value to set:", @"Label message")];
        if ([self searchSelection])
			[self setReplaceAllTooltip:NSLocalizedString(@"Overwrite or add the field in all selected publications.", @"Tool tip message")];
		else
			[self setReplaceAllTooltip:NSLocalizedString(@"Overwrite or add the field in all publications.", @"Tool tip message")];
	} else if (FCOperationPrepend == [self operation]) {
		[self setReplaceLabel:NSLocalizedString(@"Prefix to add:", @"Label message")];
		if ([self searchSelection])
			[self setReplaceAllTooltip:NSLocalizedString(@"Add a suffix to the field in all selected publications.", @"Tool tip message")];
		else
			[self setReplaceAllTooltip:NSLocalizedString(@"Add a suffix to the field in all publications.", @"Tool tip message")];
	} else if (FCOperationAppend == [self operation]) {
		[self setReplaceLabel:NSLocalizedString(@"Suffix to add:", @"Label message")];
		if ([self searchSelection])
			[self setReplaceAllTooltip:NSLocalizedString(@"Add a prefix to the field in all selected publications.", @"Tool tip message")];
		else
			[self setReplaceAllTooltip:NSLocalizedString(@"Add a prefix to the field in all publications.", @"Tool tip message")];
	} else {
		[self setReplaceLabel:NSLocalizedString(@"Replace with:", @"Label message")];
		if ([self searchSelection])
			[self setReplaceAllTooltip:NSLocalizedString(@"Replace all matches in all selected publications.", @"Tool tip message")];
		else
			[self setReplaceAllTooltip:NSLocalizedString(@"Replace all matches in all publications.", @"Tool tip message")];
	}
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification{
	[self updateUI];
}

- (void)swapView:(NSView *)view1 with:(NSView *)view2 {
    NSRect frame = [view2 frame];
    NSView *superview = [view2 superview];
    [view2 setFrame:[view1 frame]];
    [view1 retain];
    [[view1 superview] replaceSubview:view1 with:view2];
    [view1 setFrame:frame];
    [superview addSubview:view1];
    [view1 release];
}

- (BOOL)commitEditing {
    id firstResponder = [[self window] firstResponder];
    NSTextView *editor = nil;
    NSRange selection = {0, 0};
    if ([firstResponder isKindOfClass:[NSTextView class]]) {
        editor = firstResponder;
        selection = [editor selectedRange];
        if ([editor isFieldEditor])
            firstResponder = [firstResponder delegate];
    }
    if ([objectController commitEditing]) {
        if (editor && [[self window] firstResponder] != editor && 
            [[self window] makeFirstResponder:firstResponder] && 
            [[editor string] length] >= NSMaxRange(selection))
            [editor setSelectedRange:selection];
        return YES;
    } else {
        return NO;
    }
}

#pragma mark Accessors

- (NSInteger)operation {
    return operation;
}

- (void)setOperation:(NSInteger)newOperation {
    if (operation != newOperation) {
        operation = newOperation;
		if (FCOperationFindAndReplace != operation) {
			[self setSearchSelection:YES];
			[self setFindString:@""];
            [self setShouldSetWhenEmpty:FCOperationOverwrite == operation];
            if ([setOptionsBox window] == nil)
                [self swapView:findOptionsBox with:setOptionsBox];
		} else if ([findOptionsBox window] == nil) {
            [self swapView:setOptionsBox with:findOptionsBox];
        }
		[self updateUI];
    }
}

- (NSString *)field {
    return [[NSUserDefaults standardUserDefaults] objectForKey:BDSKFindControllerLastFindAndReplaceFieldKey];
}

- (void)setField:(NSString *)newField {
    [[NSUserDefaults standardUserDefaults] setObject:newField forKey:BDSKFindControllerLastFindAndReplaceFieldKey];
    if ([newField isEqualToString:BDSKRemoteURLString]) {
        [self setFindAsMacro:NO];
        [self setReplaceAsMacro:NO];
    }
    [self updateUI];
}

- (NSString *)findString {
    return [[(findString ?: @"") retain] autorelease];
}

- (void)setFindString:(NSString *)newFindString {
    if (findString != newFindString) {
        [findString release];
        findString = [newFindString copy];
		[self insertObject:newFindString inFindHistoryAtIndex:0];
		
		NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSFindPboard];
		[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
		[pboard setString:findString forType:NSStringPboardType];
    }
}

- (NSString *)replaceString {
    return [[(replaceString ?: @"") retain] autorelease];
}

- (void)setReplaceString:(NSString *)newReplaceString {
    if (replaceString != newReplaceString) {
        [replaceString release];
        replaceString = [newReplaceString copy];
		[self insertObject:newReplaceString inReplaceHistoryAtIndex:0];
    }
}

- (NSInteger)searchType {
    return searchType;
}

- (void)setSearchType:(NSInteger)newSearchType {
    if (searchType != newSearchType) {
        searchType = newSearchType;
    }
}

- (NSInteger)searchScope {
    return searchScope;
}

- (void)setSearchScope:(NSInteger)newSearchScope {
    if (searchScope != newSearchScope) {
        searchScope = newSearchScope;
    }
}

- (BOOL)ignoreCase {
    return ignoreCase;
}

- (void)setIgnoreCase:(BOOL)newIgnoreCase {
    if (ignoreCase != newIgnoreCase) {
        ignoreCase = newIgnoreCase;
    }
}

- (BOOL)wrapAround {
    return wrapAround;
}

- (void)setWrapAround:(BOOL)newWrapAround {
    if (wrapAround != newWrapAround) {
        wrapAround = newWrapAround;
    }
}

- (BOOL)searchSelection {
    return searchSelection;
}

- (void)setSearchSelection:(BOOL)newSearchSelection {
    if (searchSelection != newSearchSelection) {
        searchSelection = newSearchSelection;
		[self updateUI];
    }
}

- (BOOL)findAsMacro {
    return findAsMacro;
}

- (void)setFindAsMacro:(BOOL)newFindAsMacro {
    if (findAsMacro != newFindAsMacro) {
        findAsMacro = newFindAsMacro;
		[self updateUI];
    }
}

- (BOOL)replaceAsMacro {
    return replaceAsMacro;
}

- (void)setReplaceAsMacro:(BOOL)newReplaceAsMacro {
    if (replaceAsMacro != newReplaceAsMacro) {
        replaceAsMacro = newReplaceAsMacro;
		[self updateUI];
    }
}

- (BOOL)shouldSetWhenEmpty {
	return shouldSetWhenEmpty;
}

- (void)setShouldSetWhenEmpty:(BOOL)newShouldSetWhenEmpty {
    if (shouldSetWhenEmpty != newShouldSetWhenEmpty) {
        shouldSetWhenEmpty = newShouldSetWhenEmpty;
    }
}

- (NSString *)replaceAllTooltip {
    return [[replaceAllTooltip retain] autorelease];
}

- (void)setReplaceAllTooltip:(NSString *)newReplaceAllTooltip {
    if (replaceAllTooltip != newReplaceAllTooltip) {
        [replaceAllTooltip release];
        replaceAllTooltip = [newReplaceAllTooltip copy];
    }
}

- (NSString *)replaceLabel {
    return [[replaceLabel retain] autorelease];
}

- (void)setReplaceLabel:(NSString *)newReplaceLabel {
    if (replaceLabel != newReplaceLabel) {
        [replaceLabel release];
        replaceLabel = [newReplaceLabel copy];
    }
}

#pragma mark Array accessors

- (NSArray *)findHistory {
    return [[findHistory retain] autorelease];
}

- (NSUInteger)countOfFindHistory {
    return [findHistory count];
}

- (id)objectInFindHistoryAtIndex:(NSUInteger)idx {
    return [findHistory objectAtIndex:idx];
}

- (void)insertObject:(id)obj inFindHistoryAtIndex:(NSUInteger)idx {
    if ([NSString isEmptyString:obj] || [findHistory containsObject:obj])
		return;
	[findHistory insertObject:obj atIndex:idx];
	NSInteger count = [findHistory count];
	if (count > MAX_HISTORY_COUNT)
		[findHistory removeObjectAtIndex:count - 1];
}

- (void)removeObjectFromFindHistoryAtIndex:(NSUInteger)idx {
    [findHistory removeObjectAtIndex:idx];
}

- (NSArray *)replaceHistory {
    return [[replaceHistory retain] autorelease];
}

- (NSUInteger)countOfReplaceHistory {
    return [replaceHistory count];
}

- (id)objectInReplaceHistoryAtIndex:(NSUInteger)idx {
    return [replaceHistory objectAtIndex:idx];
}

- (void)insertObject:(id)obj inReplaceHistoryAtIndex:(NSUInteger)idx {
    if ([NSString isEmptyString:obj] || [replaceHistory containsObject:obj])
		return;
	[replaceHistory insertObject:obj atIndex:idx];
	NSInteger count = [findHistory count];
	if (count > MAX_HISTORY_COUNT)
		[replaceHistory removeObjectAtIndex:count - 1];
}

- (void)removeObjectFromReplaceHistoryAtIndex:(NSUInteger)idx {
    [replaceHistory removeObjectAtIndex:idx];
}

#pragma mark Validation

- (BOOL)validateField:(id *)value error:(NSError **)error {
    // this should have be handled by the formatter
	return YES;
}

- (BOOL)validateFindString:(id *)value error:(NSError **)error {
	if ([self searchType] == FCRegexSearch) { // check the regex
		if ([self regexIsValid:*value] == NO) {
            if(error != nil){
                NSString *description = NSLocalizedString(@"Invalid Regular Expression.", @"Error description");
                NSString *reason = NSLocalizedString(@"The regular expression you entered is not valid.", @"Error reason");
                NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, nil];
                *error = [NSError errorWithDomain:BDSKFindErrorDomain code:1 userInfo:userInfo];
            }
			return NO;
		}
	} else if([self findAsMacro]) { // check the "find" complex string
		NSString *reason = nil;
		if ([self stringIsValidAsComplexString:*value errorMessage:&reason] == NO) {
            if(error != nil){
                NSString *description = NSLocalizedString(@"Invalid BibTeX Macro.", @"Error description");
                NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, nil];
                *error = [NSError errorWithDomain:BDSKFindErrorDomain code:1 userInfo:userInfo];
            }
			return NO;
		}
	}  
    return YES;
}

- (BOOL)validateReplaceString:(id *)value error:(NSError **)error {
	NSString *reason = nil;
	if ([self searchType] == FCTextualSearch && [self replaceAsMacro] && 
		[self stringIsValidAsComplexString:*value errorMessage:&reason] == NO) {
        if(error != nil){
            NSString *description = NSLocalizedString(@"Invalid BibTeX Macro.", @"Error description");
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, nil];
            *error = [NSError errorWithDomain:BDSKFindErrorDomain code:1 userInfo:userInfo];
        }
		return NO;
	}
    return YES;
}

- (BOOL)validateSearchType:(id *)value error:(NSError **)error {
    if ([*value integerValue] == FCRegexSearch && 
		[self regexIsValid:[self findString]] == NO) {
        if(error != nil){
            NSString *description = NSLocalizedString(@"Invalid Regular Expression.", @"Error description");
            NSString *reason = [NSString stringWithFormat:NSLocalizedString(@"The entry \"%@\" is not a valid regular expression.", @"Error reason"), [self findString]];
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, nil];
            *error = [NSError errorWithDomain:BDSKFindErrorDomain code:1 userInfo:userInfo];
        }
		[findComboBox selectText:self];
		return NO;
    }
    return YES;
}

- (BOOL)validateSearchScope:(id *)value error:(NSError **)error {
    return YES;
}

- (BOOL)validateIgnoreCase:(id *)value error:(NSError **)error {
    return YES;
}

- (BOOL)validateSearchSelection:(id *)value error:(NSError **)error {
    return YES;
}

- (BOOL)validateFindAsMacro:(id *)value error:(NSError **)error {
	NSString *reason = nil;
    if ([*value boolValue] && [self searchType] == FCTextualSearch &&
	    [self stringIsValidAsComplexString:[self findString] errorMessage:&reason] == NO) {
        if(error != nil){
            NSString *description = NSLocalizedString(@"Invalid BibTeX Macro", @"Error description");
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, nil];
            *error = [NSError errorWithDomain:BDSKFindErrorDomain code:1 userInfo:userInfo];
        }
		[findComboBox selectText:self];
		return NO;
    }
    return YES;
}

- (BOOL)validateReplaceAsMacro:(id *)value error:(NSError **)error {
	NSString *reason = nil;
    if([*value boolValue] && [self searchType] == FCTextualSearch &&
	   [self stringIsValidAsComplexString:[self replaceString] errorMessage:&reason] == NO){
        if(error != nil){
            NSString *description = NSLocalizedString(@"Invalid BibTeX Macro", @"Error description");
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, nil];
            *error = [NSError errorWithDomain:BDSKFindErrorDomain code:1 userInfo:userInfo];
        }
		[replaceComboBox selectText:self];
		return NO;
    }
    return YES;
}

- (BOOL)validateOperation:(id *)value error:(NSError **)error {
	return YES;
}

- (BOOL)regexIsValid:(NSString *)value{
    AGRegex *testRegex = [AGRegex regexWithPattern:value];
    if(testRegex == nil)
        return NO;
    
    return YES;
}

- (BOOL)stringIsValidAsComplexString:(NSString *)btstring errorMessage:(NSString **)errString{
    volatile NSString *compStr;
    NSError *error = nil;
    
    compStr = [NSString stringWithBibTeXString:btstring macroResolver:nil error:&error];
    if (compStr == nil) {
        *errString = [error localizedDescription];
        if(*errString == nil)
            *errString = @"Complex string is invalid for unknown reason"; // shouldn't happen
        return NO;
    }
    return YES;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem{
    if ([menuItem action] == @selector(toggleStatusBar:)) {
		if ([statusBar isVisible]) {
			[menuItem setTitle:NSLocalizedString(@"Hide Status Bar", @"Menu item title")];
		} else {
			[menuItem setTitle:NSLocalizedString(@"Show Status Bar", @"Menu item title")];
		}
		return YES;
    } else if ([menuItem action] == @selector(performFindPanelAction:)) {
		switch ([menuItem tag]) {
			case NSFindPanelActionShowFindPanel:
			case NSFindPanelActionNext:
			case NSFindPanelActionPrevious:
			case NSFindPanelActionReplaceAll:
			case NSFindPanelActionReplace:
			case NSFindPanelActionReplaceAndFind:
			case NSFindPanelActionSetFindString:
				return YES;
			default:
				return NO;
		}
	}
	return YES;
}

#pragma mark Action methods

- (IBAction)openHelp:(id)sender{
    NSString *helpBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"FindAndReplace" inBook:helpBookName];
}

- (IBAction)toggleStatusBar:(id)sender{
	NSRect winFrame = [[self window] frame];
	NSSize minSize = [[self window] minSize];
	NSSize maximumSize = [[self window] maxSize];
	NSView *contentView = [[self window] contentView];
	CGFloat statusHeight = NSHeight([statusBar frame]);
	BOOL autoresizes = [contentView autoresizesSubviews];
	NSRect viewFrame;
	
	if ([statusBar superview])
		statusHeight = -statusHeight;
	
	if ([contentView isFlipped] == NO) {
		for (NSView *view in [contentView subviews]) {
			viewFrame = [view frame];
			viewFrame.origin.y += statusHeight;
			[view setFrame:viewFrame];
		}
	}
	winFrame.size.height += statusHeight;
	winFrame.origin.y -= statusHeight;
	if (minSize.height > 0.0) minSize.height += statusHeight;
	if (maximumSize.height > 0.0) maximumSize.height += statusHeight;
	if (winFrame.size.height < 0.0) winFrame.size.height = 0.0;
	if (minSize.height < 0.0) minSize.height = 0.0;
	if (maximumSize.height < 0.0) maximumSize.height = 0.0;
	
	if ([statusBar superview]) {
		[statusBar removeFromSuperview];
	} else {
		NSRect statusRect = [contentView bounds];
		statusRect.size.height = statusHeight;
		if ([contentView isFlipped])
			statusRect.origin.y = NSMaxY([contentView bounds]) - NSHeight(statusRect);
		[statusBar setFrame:statusRect];
		[contentView addSubview:statusBar positioned:NSWindowBelow relativeTo:nil];
	}
	
    [[self window] setContentBorderThickness:[statusBar isVisible] ? 22.0 : 0.0 forEdge:NSMinYEdge];
    
	[contentView setAutoresizesSubviews:NO];
	[[self window] setFrame:winFrame display:YES];
	[contentView setAutoresizesSubviews:autoresizes];
	[[self window] setMinSize:minSize];
	[[self window] setMaxSize:maximumSize];
	
    // fix an AppKit bug
    [[self window] setMovableByWindowBackground:YES];
    [[self window] setMovableByWindowBackground:NO];
    
    [[NSUserDefaults standardUserDefaults] setBool:[statusBar isVisible] forKey:BDSKShowFindStatusBarKey];
}

#pragma mark Find and Replace Action methods

- (IBAction)performFindPanelAction:(id)sender{
	switch ([sender tag]) {
		case NSFindPanelActionShowFindPanel:
			[[self window] makeKeyAndOrderFront:sender];
			break;
		case NSFindPanelActionNext:
			[self findAndHighlightWithReplace:NO next:YES];
			break;
		case NSFindPanelActionPrevious:
			[self findAndHighlightWithReplace:NO next:NO];
			break;
		case NSFindPanelActionReplaceAll:
			[self replaceAllInSelection:NO];
			break;
		case NSFindPanelActionReplace:
			[self replace];
			break;
		case NSFindPanelActionReplaceAndFind:
			[self findAndHighlightWithReplace:YES next:YES];
			break;
		case NSFindPanelActionSetFindString:
			[self setFindFromSelection];
			// nothing to support here, as we have no selection
			break;
		case NSFindPanelActionReplaceAllInSelection:
			[self replaceAllInSelection:YES];
			break;
	}
}

#pragma mark Find and Replace implementation

- (void)setFindFromSelection{
    BibDocument *theDocument = [[NSDocumentController sharedDocumentController] currentDocument];
    if(!theDocument){
        NSBeep();
		return;
	}
	NSString *selString = [theDocument selectedStringForFind];
	if ([NSString isEmptyString:selString]){
        NSBeep();
		return;
	}
	[self setFindString:selString];
}

- (void)replace{
	[statusBar setStringValue:@""];
    
    BibDocument *theDocument = [[NSDocumentController sharedDocumentController] currentDocument];
    if(!theDocument){
        NSBeep();
		[statusBar setStringValue:NSLocalizedString(@"No document selected", @"Status message")];
        return;
	}else if([theDocument hasExternalGroupsSelected]){
        NSBeep();
		[statusBar setStringValue:NSLocalizedString(@"Cannot replace in external items", @"Status message")];
        return;
	}
    
    BibItem *selItem = [[theDocument selectedPublications] firstObject];
    
    if(selItem == nil){
        NSBeep();
		[statusBar setStringValue:NSLocalizedString(@"Nothing selected", @"Status message")];
        return;
    }

    [self findAndReplaceInItems:[NSArray arrayWithObject:selItem] ofDocument:theDocument];
    // make sure we only highlight this item
    [theDocument selectPublication:selItem];
}

- (void)findAndHighlightWithReplace:(BOOL)replace next:(BOOL)next{
	[statusBar setStringValue:@""];
    
    BibDocument *theDocument = [[NSDocumentController sharedDocumentController] currentDocument];
    if(!theDocument){
        NSBeep();
		[statusBar setStringValue:NSLocalizedString(@"No document selected", @"Status message")];
        return;
	}else if(replace && ([theDocument hasExternalGroupsSelected])){
        NSBeep();
		[statusBar setStringValue:NSLocalizedString(@"Cannot replace in external items", @"Status message")];
        return;
    }else if([self commitEditing] == NO){
        NSBeep();
		[statusBar setStringValue:NSLocalizedString(@"There were invalid values", @"Status message")];
        return;
    }
   
    // this can change between clicks of the Find button, so we can't cache it
    NSArray *currItems = [self currentFoundItemsInDocument:theDocument];
    //NSLog(@"currItems has %@", currItems);
    if(currItems == nil){
        NSBeep();
		[statusBar setStringValue:NSLocalizedString(@"Nothing found", @"Status message")];
        return;
    }

    BibItem *selItem = [[theDocument selectedPublications] firstObject];
    NSUInteger indexOfSelectedItem;
    if(selItem == nil){ // no selection, so select the first one
        indexOfSelectedItem = 0;
    } else {        
        // see if the selected pub is one of the current found items, or just some random item
        indexOfSelectedItem = [[theDocument shownPublications] indexOfObjectIdenticalTo:selItem];
        
        // if we're doing a replace & find, we need to replace in this item before we change the selection
        if(replace){
            [self findAndReplaceInItems:[NSArray arrayWithObject:selItem] ofDocument:theDocument];
		}
        
        // see if current search results have an item identical to the selected one
        indexOfSelectedItem = [currItems indexOfObjectIdenticalTo:selItem];
        if(indexOfSelectedItem != NSNotFound){ // we've already selected an item from the search results...so select the next one
            if(next){
				if(++indexOfSelectedItem == [currItems count])
					indexOfSelectedItem = wrapAround ? 0 : NSNotFound; // wrap around
			}else{
				if(indexOfSelectedItem-- == 0)
					indexOfSelectedItem = wrapAround ? [currItems count] - 1 : NSNotFound; // wrap around
			}
        } else {
            // the selected pub was some item we don't care about, so select item 0
            indexOfSelectedItem = 0;
        }
    }
    
    if(indexOfSelectedItem != NSNotFound) {
        [theDocument selectPublication:[currItems objectAtIndex:indexOfSelectedItem]];
    } else {
        NSBeep();
		[statusBar setStringValue:NSLocalizedString(@"Nothing found", @"Status message")];
    }
}

- (void)replaceAllInSelection:(BOOL)selection{
	if (selection)
		[self setSearchSelection:YES];
	[statusBar setStringValue:@""];
	
    BibDocument *theDocument = [[NSDocumentController sharedDocumentController] currentDocument];
    if(!theDocument){
        NSBeep();
		[statusBar setStringValue:NSLocalizedString(@"No document selected", @"Status message")];
        return;
	}else if([theDocument hasExternalGroupsSelected]){
        NSBeep();
		[statusBar setStringValue:NSLocalizedString(@"Cannot replace in external items", @"Status message")];
        return;
    }else if([self commitEditing] == NO){
        NSBeep();
		[statusBar setStringValue:NSLocalizedString(@"There were invalid values", @"Status message")];
        return;
	}
	
    [statusBar setProgressIndicatorStyle:BDSKProgressIndicatorSpinningStyle];
	[statusBar startAnimation:nil];

    NSArray *publications;
    NSArray *shownPublications = [theDocument shownPublications];
    
    if([self searchSelection]){
        // if we're only doing a find/replace in the selected publications
        publications = [theDocument selectedPublications];
    } else {
        // we're doing a find/replace in all the document pubs
        publications = shownPublications; // we're not changing it; the cast just shuts gcc up
    }
    
	[self findAndReplaceInItems:publications ofDocument:theDocument];
	
	[statusBar stopAnimation:nil];
    [statusBar setProgressIndicatorStyle:BDSKProgressIndicatorNone];
}

- (AGRegex *)currentRegex{
	// current regex including string and/or node boundaries and case sensitivity
	
	if(!findAsMacro && replaceAsMacro)
		searchScope = FCWholeFieldSearch; // we can only reliably replace a complete string by a macro
    
	NSString *regexFormat = nil;
	
	// set string and/or node boundaries in the regex
	switch(searchScope){
		case FCContainsSearch:
			regexFormat = (findAsMacro) ? @"(?:?<=^|\\s#\\s)%@(?:?=$|\\s#\\s)" : @"%@";
			break;
		case FCStartsWithSearch:
			regexFormat = (findAsMacro) ? @"(?:?<=^)%@(?:?=$|\\s#\\s)" : @"(?:?<=^)%@";
			break;
		case FCWholeFieldSearch:
			regexFormat = @"(?:?<=^)%@(?:?=$)";
			break;
		case FCEndsWithSearch:
			regexFormat = (findAsMacro) ? @"(?:?<=^|\\s#\\s)%@(?:?=$)" : @"%@(?:?=$)";
			break;
	}
	
	return [AGRegex regexWithPattern:[NSString stringWithFormat:regexFormat, findString] 
							 options:(ignoreCase ? AGRegexCaseInsensitive : 0)];
}

- (NSArray *)currentStringFoundItemsInDocument:(BibDocument *)theDocument{
	// found items using BDSKComplexString methods
    NSString *findStr = [self findString];
	// get the current search option settings
    NSString *field = [self field];
    NSUInteger searchOpts = (ignoreCase ? NSCaseInsensitiveSearch : 0);
	
	switch (searchScope) {
		case FCEndsWithSearch:
			searchOpts = searchOpts | NSBackwardsSearch;
		case FCStartsWithSearch:
			searchOpts = searchOpts | NSAnchoredSearch;
	}
	
	if (findAsMacro)
		findStr = [NSString stringWithBibTeXString:findStr macroResolver:[theDocument macroResolver] error:NULL];
	
	// loop through the pubs to replace
    NSMutableArray *arrayOfItems = [NSMutableArray array];
    NSString *origStr;
    
    // use all shown pubs; not just selection, since our caller is going to change the selection
    
    for (BibItem *bibItem in [theDocument shownPublications]) {
        if ([field isEqualToString:BDSKRemoteURLString]) {
            
            for (BDSKLinkedFile *file in [bibItem remoteURLs]) {
                origStr = [[file URL] absoluteString];
                
                if (searchScope == FCWholeFieldSearch) {
                    if ([findStr compare:origStr options:searchOpts] == NSOrderedSame) {
                        [arrayOfItems addObject:bibItem];
                        break;
                    }
                } else {
                    if ([origStr hasSubstring:findStr options:searchOpts]) {
                        [arrayOfItems addObject:bibItem];
                        break;
                    }
                }
            }
            
        } else {
            
            origStr = [bibItem stringValueOfField:field inherit:NO];
            
            if (origStr == nil || findAsMacro != [origStr isComplex])
                continue; // we don't want to add a field or set it to nil, or find expanded values of a complex string, or interpret an ordinary string as a macro
            
            if (searchScope == FCWholeFieldSearch) {
                if ([findStr compareAsComplexString:origStr options:searchOpts] == NSOrderedSame)
                    [arrayOfItems addObject:bibItem];
            } else {
                if ([origStr hasSubstring:findStr options:searchOpts])
                    [arrayOfItems addObject:bibItem];
            }
            
        }
    }
    return ([arrayOfItems count] ? arrayOfItems : nil);
}

- (NSArray *)currentRegexFoundItemsInDocument:(BibDocument *)theDocument{
	// found items using AGRegex
	// get some search settings
    NSString *field = [self field];
    AGRegex *theRegex = [self currentRegex];
	
	// loop through the pubs to replace
    NSMutableArray *arrayOfItems = [NSMutableArray array];
    NSString *origStr;
    
    // use all shown pubs; not just selection, since our caller is going to change the selection
    
    for (BibItem *bibItem in [theDocument shownPublications]) {
        if ([field isEqualToString:BDSKRemoteURLString]) {
            
            for (BDSKLinkedFile *file in [bibItem remoteURLs]) {
                origStr = [[file URL] absoluteString];
                if([theRegex findInString:origStr]){
                    [arrayOfItems addObject:bibItem];
                    break;
                }
            }
            
        } else {
            
            origStr = [bibItem stringValueOfField:field inherit:NO];
            
            if(origStr == nil || findAsMacro != [origStr isComplex])
                continue; // we don't want to add a field or set it to nil, or find expanded values of a complex string, or interpret an ordinary string as a macro
            
            if(findAsMacro)
                origStr = [origStr stringAsBibTeXString];
            if([theRegex findInString:origStr]){
                [arrayOfItems addObject:bibItem];
            }
            
        }
    }
    return ([arrayOfItems count] ? arrayOfItems : nil);
}

- (NSArray *)currentFoundItemsInDocument:(BibDocument *)theDocument{
	if([self searchType] == FCTextualSearch)
		return [self currentStringFoundItemsInDocument:theDocument];
	else if([self regexIsValid:[self findString]])
		return [self currentRegexFoundItemsInDocument:theDocument];
	return nil;
}

- (NSUInteger)stringFindAndReplaceInItems:(NSArray *)arrayOfPubs ofDocument:(BibDocument *)theDocument{
	// find and replace using BDSKComplexString methods
    // first we setup all the search settings
    NSString *findStr = [self findString];
    NSString *replStr = [self replaceString];
	// get the current search option settings
    NSString *field = [self field];
    NSUInteger searchOpts = (ignoreCase ? NSCaseInsensitiveSearch : 0);
	
	if(!findAsMacro && replaceAsMacro)
		searchScope = FCWholeFieldSearch; // we can only reliably replace a complete string by a macro
	
	switch(searchScope){
		case FCEndsWithSearch:
			searchOpts = searchOpts | NSBackwardsSearch;
		case FCStartsWithSearch:
			searchOpts = searchOpts | NSAnchoredSearch;
	}
	
	if(findAsMacro)
		findStr = [NSString stringWithBibTeXString:findStr macroResolver:[theDocument macroResolver] error:NULL];
	if(replaceAsMacro)
		replStr = [NSString stringWithBibTeXString:replStr macroResolver:[theDocument macroResolver] error:NULL];
		
	// loop through the pubs to replace
    NSString *origStr;
    NSString *newStr;
	NSUInteger numRepl = 0;
	NSUInteger number = 0;
	
    for (BibItem *bibItem in arrayOfPubs) {
        // don't touch external items
        if ([bibItem owner] != theDocument) 
            continue;
        
        if ([field isEqualToString:BDSKRemoteURLString]) {
            
            BDSKLinkedFile *replFile;
            NSUInteger idx;
            
            for (BDSKLinkedFile *file in [bibItem remoteURLs]) {
                idx = [[bibItem files] indexOfObjectIdenticalTo:file];
                if (idx == NSNotFound) continue;
                origStr = [[file URL] absoluteString];
                newStr = nil;
                if(searchScope == FCWholeFieldSearch){
                    if([findStr compare:origStr options:searchOpts] == NSOrderedSame)
                        newStr = replStr;
                }else{
                    newStr = [origStr stringByReplacingOccurrencesOfString:findStr withString:replStr options:searchOpts replacements:&numRepl];
                    if(numRepl == 0)
                        newStr = nil;
                }
                if (newStr && (replFile = [[BDSKLinkedFile alloc] initWithURLString:newStr])) {
                    [[bibItem mutableArrayValueForKey:@"files"] replaceObjectAtIndex:idx withObject:replFile];
                    number++;
                    [replFile release];
                }
            }
            
        } else {
            
            origStr = [bibItem stringValueOfField:field inherit:NO];
            
            if(origStr == nil || findAsMacro != [origStr isComplex])
                continue; // we don't want to add a field or set it to nil, or replace expanded values of a complex string, or interpret an ordinary string as a macro
            
            if(searchScope == FCWholeFieldSearch){
                if([findStr compareAsComplexString:origStr options:searchOpts] == NSOrderedSame){
                    [bibItem setField:field toStringValue:replStr];
                    number++;
                }
            }else{
                newStr = [origStr stringByReplacingOccurrencesOfString:findStr withString:replStr options:searchOpts replacements:&numRepl];
                if(numRepl > 0){
                    [bibItem setField:field toStringValue:newStr];
                    number++;
                }
            }
            
        }
    }

	return number;
}

- (NSUInteger)regexFindAndReplaceInItems:(NSArray *)arrayOfPubs ofDocument:(BibDocument *)theDocument{
	// find and replace using AGRegex
    // first we setup all the search settings
    NSString *replStr = [self replaceString];
	// get some search settings
    NSString *field = [self field];
    AGRegex *theRegex = [self currentRegex];
	
	if(findAsMacro && !replaceAsMacro)
		replStr = [replStr stringAsBibTeXString];
	
	// loop through the pubs to replace
    NSString *origStr;
	NSString *complexStr;
	NSUInteger number = 0;
	
    for (BibItem *bibItem in arrayOfPubs) {
        // don't touch external items
        if ([bibItem owner] != theDocument) 
            continue;
        
        if ([field isEqualToString:BDSKRemoteURLString]) {
            
            BDSKLinkedFile *replFile;
            NSUInteger idx;
            
            for (BDSKLinkedFile *file in [bibItem remoteURLs]) {
                idx = [[bibItem files] indexOfObjectIdenticalTo:file];
                if (idx == NSNotFound) continue;
                origStr = [[file URL] absoluteString];
                if([theRegex findInString:origStr]){
                    origStr = [theRegex replaceWithString:replStr inString:origStr];
                    if ((replFile = [[BDSKLinkedFile alloc] initWithURLString:origStr])) {
                        [[bibItem mutableArrayValueForKey:@"files"] replaceObjectAtIndex:idx withObject:replFile];
                        number++;
                        [replFile release];
                    }
                }
            }
            
        } else {
            
            origStr = [bibItem stringValueOfField:field inherit:NO];
            
            if(origStr == nil || findAsMacro != [origStr isComplex])
                continue; // we don't want to add a field or set it to nil, or replace expanded values of a complex string, or interpret an ordinary string as a macro
            
            if(findAsMacro)
                origStr = [origStr stringAsBibTeXString];
            if([theRegex findInString:origStr]){
                origStr = [theRegex replaceWithString:replStr inString:origStr];
                if(replaceAsMacro || findAsMacro){
                    if ((complexStr = [NSString stringWithBibTeXString:origStr macroResolver:[theDocument macroResolver] error:NULL])) {
                        [bibItem setField:field toStringValue:complexStr];
                        number++;
                    }
                } else {
                    [bibItem setField:field toStringValue:origStr];
                    number++;
                }            
            }
            
        }
    }
	
	return number;
}

- (NSUInteger)overwriteInItems:(NSArray *)arrayOfPubs ofDocument:(BibDocument *)theDocument{
	// overwrite using BDSKComplexString methods
    // first we setup all the search settings
    NSString *replStr = [self replaceString];
	// get the current search option settings
    NSString *field = [self field];
	
	if(replaceAsMacro)
		replStr = [NSString stringWithBibTeXString:replStr macroResolver:[theDocument macroResolver] error:NULL];
		
	// loop through the pubs to replace
    NSString *origStr;
	NSUInteger number = 0;

    for (BibItem *bibItem in arrayOfPubs) {
        // don't touch external items
        if ([bibItem owner] != theDocument) 
            continue;
        
        if ([field isEqualToString:BDSKRemoteURLString]) {
            
            NSArray *remoteURLs = [bibItem remoteURLs];
            NSMutableArray *files = [bibItem mutableArrayValueForKey:@"files"];
            BDSKLinkedFile *replFile;
            
            if ((replFile = [[BDSKLinkedFile alloc] initWithURLString:replStr])) {
                if([remoteURLs count] == 0){
                    if(shouldSetWhenEmpty == NO) {
                        [replFile release];
                        continue;
                    }
                }else{
                    [files removeObjectsInArray:remoteURLs];
                }
                [files addObject:replFile];
                number++;
                [replFile release];
            }
            
        } else {
            
            origStr = [bibItem stringValueOfField:field inherit:NO];
            if(origStr == nil || [origStr isEqualAsComplexString:@""]){
                if(shouldSetWhenEmpty == NO) continue;
                origStr = @"";
            }
            
            if([replStr compareAsComplexString:origStr] != NSOrderedSame){
                [bibItem setField:field toStringValue:replStr];
                number++;
            }
            
        }
    }
	
	return number;
}

- (NSUInteger)prependInItems:(NSArray *)arrayOfPubs ofDocument:(BibDocument *)theDocument{
	// prepend using BDSKComplexString methods
    // first we setup all the search settings
    NSString *replStr = [self replaceString];
	// get the current search option settings
    NSString *field = [self field];
	
    if(replStr == nil || [replStr isEqualAsComplexString:@""])
        return 0;
    
	if(replaceAsMacro)
		replStr = [NSString stringWithBibTeXString:replStr macroResolver:[theDocument macroResolver] error:NULL];
		
	// loop through the pubs to replace
    NSString *origStr;
	NSUInteger number = 0;

    for (BibItem *bibItem in arrayOfPubs) {
        // don't touch external items
        if ([bibItem owner] != theDocument) 
            continue;
        
        if ([field isEqualToString:BDSKRemoteURLString]) {
            
            BDSKLinkedFile *replFile;
            NSUInteger idx;
            
            for (BDSKLinkedFile *file in [bibItem remoteURLs]) {
                idx = [[bibItem files] indexOfObjectIdenticalTo:file];
                if (idx == NSNotFound) continue;
                origStr = [[file URL] absoluteString];
                if ((replFile = [[BDSKLinkedFile alloc] initWithURLString:[replStr stringByAppendingString:origStr]])) {
                    [[bibItem mutableArrayValueForKey:@"files"] replaceObjectAtIndex:idx withObject:replFile];
                    number++;
                    [replFile release];
                }
            }
            
        } else {
                
            origStr = [bibItem stringValueOfField:field inherit:NO];
            if(origStr == nil || [origStr isEqualAsComplexString:@""]){
                if(shouldSetWhenEmpty == NO) continue;
                origStr = @"";
            }
            
            [bibItem setField:field toStringValue:[replStr complexStringByAppendingString:origStr]];
            number++;
            
        }
    }
	
	return number;
}

- (NSUInteger)appendInItems:(NSArray *)arrayOfPubs ofDocument:(BibDocument *)theDocument{
	// prepend using BDSKComplexString methods
    // first we setup all the search settings
    NSString *replStr = [self replaceString];
	// get the current search option settings
    NSString *field = [self field];
	
    if(replStr == nil || [replStr isEqualAsComplexString:@""])
        return 0;
    
	if(replaceAsMacro)
		replStr = [NSString stringWithBibTeXString:replStr macroResolver:[theDocument macroResolver] error:NULL];
		
	// loop through the pubs to replace
    NSString *origStr;
	NSUInteger number = 0;

    for (BibItem *bibItem in arrayOfPubs) {
        // don't touch external items
        if ([bibItem owner] != theDocument) 
            continue;
        
        if ([field isEqualToString:BDSKRemoteURLString]) {
            
            BDSKLinkedFile *replFile;
            NSUInteger idx;
            
            for (BDSKLinkedFile *file in [bibItem remoteURLs]) {
                idx = [[bibItem files] indexOfObjectIdenticalTo:file];
                if (idx == NSNotFound) continue;
                origStr = [[file URL] absoluteString];
                if ((replFile = [[BDSKLinkedFile alloc] initWithURLString:[origStr stringByAppendingString:replStr]])) {
                    [[bibItem mutableArrayValueForKey:@"files"] replaceObjectAtIndex:idx withObject:replFile];
                    number++;
                    [replFile release];
                }
            }
            
        } else {
                
            origStr = [bibItem stringValueOfField:field inherit:NO];
            if(origStr == nil || [origStr isEqualAsComplexString:@""]){
                if(shouldSetWhenEmpty == NO) continue;
                origStr = @"";
            }
            
            [bibItem setField:field toStringValue:[origStr complexStringByAppendingString:replStr]];
            number++;
            
        }
    }
	
	return number;
}

- (NSUInteger)findAndReplaceInItems:(NSArray *)arrayOfPubs ofDocument:(BibDocument *)theDocument{
	NSUInteger number;
    
	if(FCOperationOverwrite == [self operation])
		number = [self overwriteInItems:arrayOfPubs ofDocument:theDocument];
	else if(FCOperationPrepend == [self operation])
		number = [self prependInItems:arrayOfPubs ofDocument:theDocument];
	else if(FCOperationAppend == [self operation])
		number = [self appendInItems:arrayOfPubs ofDocument:theDocument];
	else if([self searchType] == FCTextualSearch)
		number = [self stringFindAndReplaceInItems:arrayOfPubs ofDocument:theDocument];
	else if([self regexIsValid:[self findString]])
		number = [self regexFindAndReplaceInItems:arrayOfPubs ofDocument:theDocument];
	else
		number = 0;
	
	NSString *fieldString = (number == 1)? NSLocalizedString(@"field",@"field") : NSLocalizedString(@"fields",@"fields");
	[statusBar setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Replaced in %lu %@",@"Status message: Replaced in [number] field(s)"), (unsigned long)number, fieldString]];
	
	return number;
}

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject {
	if (findFieldEditor == nil) {
		findFieldEditor = [[BDSKFindFieldEditor alloc] init];
        [findFieldEditor setFieldEditor:YES];
	}
	return findFieldEditor;
}

@end

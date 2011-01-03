//
//  BDSKFieldEditor.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 19/12/05.
/*
 This software is Copyright (c) 2005-2011
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKFieldEditor.h"
#import "BDSKTextViewCompletionController.h"

@interface BDSKFieldEditor (Private)

- (BOOL)delegateHandlesDragOperation:(id <NSDraggingInfo>)sender;
- (void)doAutoCompleteIfPossible;
- (void)handleTextDidBeginEditingNotification:(NSNotification *)note;
- (void)handleTextDidEndEditingNotification:(NSNotification *)note;

@end

@implementation BDSKFieldEditor

- (id)init {
	if (self = [super initWithFrame:NSZeroRect]) {
		[self setFieldEditor:YES];
		delegatedDraggedTypes = nil;
        isEditing = NO;
        
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(handleTextDidBeginEditingNotification:)
													 name:NSTextDidBeginEditingNotification
												   object:self];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(handleTextDidEndEditingNotification:)
													 name:NSTextDidEndEditingNotification
												   object:self];
	}
	return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	BDSKDESTROY(delegatedDraggedTypes);
	[super dealloc];
}

#pragma mark Linking methods

- (void)updateLinks {    
    if ([[self delegate] respondsToSelector:@selector(textViewShouldLinkKeys:)] == NO ||
        [[self delegate] textViewShouldLinkKeys:self] == NO)
        return;
    
    static NSCharacterSet *keySepCharSet = nil;
    static NSCharacterSet *keyCharSet = nil;
    
    if (keySepCharSet == nil) {
        keySepCharSet = [[NSCharacterSet characterSetWithCharactersInString:@", "] retain];
        keyCharSet = [[keySepCharSet invertedSet] retain];
    }
    
    NSTextStorage *textStorage = [self textStorage];
    NSString *string = [textStorage string];
    
    NSUInteger start, length = [string length];
    NSRange range = NSMakeRange(0, 0);
    NSString *keyString;
    
    [textStorage removeAttribute:NSLinkAttributeName range:NSMakeRange(0, length)];
    
    do {
        start = NSMaxRange(range);
        range = [string rangeOfCharacterFromSet:keyCharSet options:0 range:NSMakeRange(start, length - start)];
        
        if (range.length) {
            start = range.location;
            range = [string rangeOfCharacterFromSet:keySepCharSet options:0 range:NSMakeRange(start, length - start)];
            if (range.length == 0)
                range.location = length;
            if (range.location > start) {
                range = NSMakeRange(start, range.location - start);
                keyString = [string substringWithRange:range];
                if ([[self delegate] textView:self isValidKey:keyString])
                    [textStorage addAttribute:NSLinkAttributeName value:keyString range:range];
            }
        }
    } while (range.length);
}

- (void)setSelectedRange:(NSRange)charRange {
    [super setSelectedRange:charRange];
    
    // Fix bug #1825703.  On 10.5, this is called from -[NSTextStorage dealloc] with an empty range.  Our -delegate method returns a garbage pointer at that time, which causes a crash in -updateLinks.  The BDSKDragTextField (in the URL group sheet) was delegate, but the AppKit should be responsible for setting that to nil.
    if ([self textStorage] != nil)
    [self updateLinks];
}

- (void)didChangeText {
    [super didChangeText];
    [self updateLinks];
}

#pragma mark Delegated drag methods

- (void)registerForDelegatedDraggedTypes:(NSArray *)pboardTypes {
	[delegatedDraggedTypes release];
	delegatedDraggedTypes = [pboardTypes copy];
	[self updateDragTypeRegistration];
}

- (void)updateDragTypeRegistration {
	if ([delegatedDraggedTypes count] == 0) {
		[super updateDragTypeRegistration];
	} else if ([self isEditable] && [self isRichText]) {
		NSMutableArray *dragTypes = [[NSMutableArray alloc] initWithArray:[self acceptableDragTypes]];
		[dragTypes addObjectsFromArray:delegatedDraggedTypes];
		[self registerForDraggedTypes:dragTypes];
		[dragTypes release];
	} else {
		[self registerForDraggedTypes:delegatedDraggedTypes];
	}
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	if ([self delegateHandlesDragOperation:sender]) {
		if ([[self delegate] respondsToSelector:@selector(draggingEntered:)])
			return [(id)[self delegate] draggingEntered:sender];
		return NSDragOperationNone;
	} else
		return [super draggingEntered:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
	if ([self delegateHandlesDragOperation:sender]) {
		if ([[self delegate] respondsToSelector:@selector(draggingUpdated:)])
			return [(id)[self delegate] draggingUpdated:sender];
		return [sender draggingSourceOperationMask];
	} else
		return [super draggingUpdated:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
	if ([self delegateHandlesDragOperation:sender]) {
		if ([[self delegate] respondsToSelector:@selector(draggingExited:)])
			[(id)[self delegate] draggingExited:sender];
	} else
		[super draggingExited:sender];
}

- (BOOL)wantsPeriodicDraggingUpdates {
	return YES;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
	if ([self delegateHandlesDragOperation:sender]) {
		if ([[self delegate] respondsToSelector:@selector(prepareForDragOperation:)])
			return [(id)[self delegate] prepareForDragOperation:sender];
		return YES;
	} else
		return [super prepareForDragOperation:sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
	if ([self delegateHandlesDragOperation:sender]) {
		if ([[self delegate] respondsToSelector:@selector(performDragOperation:)])
			return [(id)[self delegate] performDragOperation:sender];
		return NO;
	} else
		return [super performDragOperation:sender];
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {
	if ([self delegateHandlesDragOperation:sender]) {
		if ([[self delegate] respondsToSelector:@selector(concludeDragOperation:)])
			[(id)[self delegate] concludeDragOperation:sender];
	} else
		[super concludeDragOperation:sender];
}

#pragma mark Completion methods

static inline BOOL completionWindowIsVisibleForTextView(NSTextView *textView)
{
    BDSKTextViewCompletionController *controller = [BDSKTextViewCompletionController sharedController];
    return ([[controller completionWindow] isVisible] && [[controller currentTextView] isEqual:textView]);
}

static inline BOOL forwardSelectorForCompletionInTextView(SEL selector, NSTextView *textView)
{
    BDSKPRECONDITION([[BDSKTextViewCompletionController sharedController] respondsToSelector:selector]);
    if(completionWindowIsVisibleForTextView(textView)){
        [[BDSKTextViewCompletionController sharedController] performSelector:selector withObject:nil];
        return YES;
    }
    return NO;
}

// insertText: and deleteBackward: affect the text content, so we send to super first, then autocomplete unconditionally since the completion controller needs to see the changes
- (void)insertText:(id)insertString {
    [super insertText:insertString];
    [self doAutoCompleteIfPossible];
    // passing a nil argument to the completion controller's insertText: is safe, and we can ensure the completion window is visible this way
    forwardSelectorForCompletionInTextView(_cmd, self);
}

- (void)deleteBackward:(id)sender {
    [super deleteBackward:(id)sender];
    // deleting a spelling error should also show the completions again
    [self doAutoCompleteIfPossible];
    forwardSelectorForCompletionInTextView(_cmd, self);
}

// moveLeft and moveRight should happen regardless of completion, or you can't navigate the line with arrow keys
- (void)moveLeft:(id)sender {
    forwardSelectorForCompletionInTextView(_cmd, self);
    [super moveLeft:sender];
}

- (void)moveRight:(id)sender {
    forwardSelectorForCompletionInTextView(_cmd, self);
    [super moveRight:sender];
}

// the following movement methods are conditional based on whether the autocomplete window is visible
- (void)moveUp:(id)sender {
    if(forwardSelectorForCompletionInTextView(_cmd, self) == NO)
        [super moveUp:sender];
}

- (void)moveDown:(id)sender {
    if(forwardSelectorForCompletionInTextView(_cmd, self) == NO)
        [super moveDown:sender];
}

- (void)insertTab:(id)sender {
    if(forwardSelectorForCompletionInTextView(_cmd, self) == NO)
        [super insertTab:sender];
}

- (void)insertNewline:(id)sender {
    if(forwardSelectorForCompletionInTextView(_cmd, self) == NO)
        [super insertNewline:sender];
}

- (NSRange)rangeForUserCompletion {
    // @@ check this if we have problems inserting accented characters; super's implementation can mess that up
    BDSKPRECONDITION([self markedRange].length == 0);    
    NSRange charRange = [super rangeForUserCompletion];
	if ([[self delegate] respondsToSelector:@selector(textView:rangeForUserCompletion:)]) 
		return [[self delegate] textView:self rangeForUserCompletion:charRange];
	return charRange;
}

#pragma mark Auto-completion methods

- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)idx;
{
    NSArray *completions = nil;
    
    if([[self delegate] respondsToSelector:@selector(textView:completions:forPartialWordRange:indexOfSelectedItem:)])
        completions = [[self delegate] textView:self completions:nil forPartialWordRange:charRange indexOfSelectedItem:idx];
    
    // Default is to call -[NSSpellChecker completionsForPartialWordRange:inString:language:inSpellDocumentWithTag:], but this apparently sends a DO message to CocoAspell (in a separate process), and we block the main runloop until it returns a long time later.  Lacking a way to determine whether the system speller (which works fine) or CocoAspell is in use, we'll just return our own completions.
    return completions;
}

- (void)complete:(id)sender;
{
    // forward this method so the controller can handle cancellation and undo
    if(forwardSelectorForCompletionInTextView(_cmd, self))
        return;

    NSRange selRange = [self rangeForUserCompletion];
    NSString *string = [self string];
    if(selRange.location == NSNotFound || [string isEqualToString:@""] || selRange.length == 0)
        return;

    // make sure to initialize this
    NSInteger idx = 0;
    NSArray *completions = [self completionsForPartialWordRange:selRange indexOfSelectedItem:&idx];
    
    if(sender == self) // auto-complete, don't select an item
		idx = -1;
	
    [[BDSKTextViewCompletionController sharedController] displayCompletions:completions indexOfSelectedItem:idx forPartialWordRange:selRange originalString:[string substringWithRange:selRange] atPoint:[self locationForCompletionWindow] forTextView:self];
}

- (NSRange)selectionRangeForProposedRange:(NSRange)proposedSelRange granularity:(NSSelectionGranularity)granularity {
    if(completionWindowIsVisibleForTextView(self))
        [[BDSKTextViewCompletionController sharedController] endDisplayNoComplete];
    return [super selectionRangeForProposedRange:proposedSelRange granularity:granularity];
}

- (BOOL)becomeFirstResponder {
    if(completionWindowIsVisibleForTextView(self))
        [[BDSKTextViewCompletionController sharedController] endDisplayNoComplete];
    return [super becomeFirstResponder];
}
    
- (BOOL)resignFirstResponder {
    if(completionWindowIsVisibleForTextView(self))
        [[BDSKTextViewCompletionController sharedController] endDisplayNoComplete];
    return [super resignFirstResponder];
}

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
- (id <BDSKFieldEditorDelegate>)delegate { return (id <BDSKFieldEditorDelegate>)[super delegate]; }
- (void)setDelegate:(id <BDSKFieldEditorDelegate>)newDelegate { [super setDelegate:newDelegate]; }
#endif

@end

#pragma mark -

@implementation BDSKFieldEditor (Private)

#pragma mark Delegated drag methods

- (BOOL)delegateHandlesDragOperation:(id <NSDraggingInfo>)sender {
	return ([delegatedDraggedTypes count] > 0 && [[sender draggingPasteboard] availableTypeFromArray:delegatedDraggedTypes] != nil);
}

- (void)doAutoCompleteIfPossible {
	if (completionWindowIsVisibleForTextView(self) == NO && isEditing) {
        if ([[self delegate] respondsToSelector:@selector(textViewShouldAutoComplete:)] &&
            [[self delegate] textViewShouldAutoComplete:self])
            [self complete:self]; // NB: the self argument is critical here (see comment in complete:)
    }
} 

- (void)handleTextDidBeginEditingNotification:(NSNotification *)note { isEditing = YES; }

- (void)handleTextDidEndEditingNotification:(NSNotification *)note { isEditing = NO; }

@end

#pragma mark -

@implementation NSTextField (BDSKFieldEditorDelegate)

- (NSRange)textView:(NSTextView *)textView rangeForUserCompletion:(NSRange)charRange {
	if (textView == [self currentEditor] && [[self delegate] respondsToSelector:@selector(control:textView:rangeForUserCompletion:)]) 
		return [(id<BDSKControlFieldEditorDelegate>)[self delegate] control:self textView:textView rangeForUserCompletion:charRange];
	return charRange;
}

- (BOOL)textViewShouldAutoComplete:(NSTextView *)textView {
	if (textView == [self currentEditor] && [[self delegate] respondsToSelector:@selector(control:textViewShouldAutoComplete:)]) 
		return [(id<BDSKControlFieldEditorDelegate>)[self delegate] control:self textViewShouldAutoComplete:textView];
	return NO;
}

- (BOOL)textViewShouldLinkKeys:(NSTextView *)textView {
    return textView == [self currentEditor] && 
           [[self delegate] respondsToSelector:@selector(control:textViewShouldLinkKeys:)] &&
           [(id<BDSKControlFieldEditorDelegate>)[self delegate] control:self textViewShouldLinkKeys:textView];
}

- (BOOL)textView:(NSTextView *)textView isValidKey:(NSString *)key{
    return textView == [self currentEditor] && 
           [[self delegate] respondsToSelector:@selector(control:textView:isValidKey:)] &&
           [(id<BDSKControlFieldEditorDelegate>)[self delegate] control:self textView:textView isValidKey:key];
}

- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)aLink atIndex:(NSUInteger)charIndex{
    return textView == [self currentEditor] && 
           [[self delegate] respondsToSelector:@selector(control:textView:clickedOnLink:atIndex:)] &&
           [(id<BDSKControlFieldEditorDelegate>)[self delegate] control:self textView:textView clickedOnLink:aLink atIndex:charIndex];
}

@end

#pragma mark -

@implementation NSTableView (BDSKFieldEditorDelegate)

- (NSRange)textView:(NSTextView *)textView rangeForUserCompletion:(NSRange)charRange {
	if (textView == [self currentEditor] && [[self delegate] respondsToSelector:@selector(control:textView:rangeForUserCompletion:)]) 
		return [(id<BDSKControlFieldEditorDelegate>)[self delegate] control:self textView:textView rangeForUserCompletion:charRange];
	return charRange;
}

- (BOOL)textViewShouldAutoComplete:(NSTextView *)textView {
	if (textView == [self currentEditor] && [[self delegate] respondsToSelector:@selector(control:textViewShouldAutoComplete:)]) 
		return [(id<BDSKControlFieldEditorDelegate>)[self delegate] control:self textViewShouldAutoComplete:textView];
	return NO;
}

- (BOOL)textViewShouldLinkKeys:(NSTextView *)textView {
    return textView == [self currentEditor] && 
           [[self delegate] respondsToSelector:@selector(control:textViewShouldLinkKeys:)] &&
           [(id<BDSKControlFieldEditorDelegate>)[self delegate] control:self textViewShouldLinkKeys:textView];
}

- (BOOL)textView:(NSTextView *)textView isValidKey:(NSString *)key{
    return textView == [self currentEditor] && 
           [[self delegate] respondsToSelector:@selector(control:textView:isValidKey:)] &&
           [(id<BDSKControlFieldEditorDelegate>)[self delegate] control:self textView:textView isValidKey:key];
}

- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)aLink atIndex:(NSUInteger)charIndex{
    return textView == [self currentEditor] && 
           [[self delegate] respondsToSelector:@selector(control:textView:clickedOnLink:atIndex:)] &&
           [(id<BDSKControlFieldEditorDelegate>)[self delegate] control:self textView:textView clickedOnLink:aLink atIndex:charIndex];
}

@end

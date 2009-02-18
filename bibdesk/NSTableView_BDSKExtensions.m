//
//  NSTableView_BDSKExtensions.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/11/05.
/*
 This software is Copyright (c) 2005-2009
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

#import "NSTableView_BDSKExtensions.h"
#import "BDSKStringConstants.h"
#import "NSBezierPath_BDSKExtensions.h"
#import "NSLayoutManager_BDSKExtensions.h"
#import "BDSKFieldEditor.h"
#import <OmniFoundation/OmniFoundation.h>
#import <OmniAppKit/OmniAppKit.h>


static void *BDSKTableViewFontDefaultsObservationContext = @"BDSKTableViewFontDefaultsObservationContext";

@implementation NSTableView (BDSKExtensions)

static BOOL (*originalBecomeFirstResponder)(id, SEL) = NULL;
static void (*originalDealloc)(id self, SEL _cmd) = NULL;
static void (*originalDraggedImageEndedAtOperation)(id self, SEL _cmd, id, NSPoint, NSDragOperation) = NULL;
static id (*originalDragImageForRowsWithIndexesTableColumnsEventOffset)(id, SEL, id, id, id, NSPointPointer) = NULL;

- (BOOL)validateDelegatedMenuItem:(NSMenuItem *)menuItem defaultDataSourceSelector:(SEL)dataSourceSelector{
	SEL action = [menuItem action];
	
	if ([_dataSource respondsToSelector:action]) {
		if ([_dataSource respondsToSelector:@selector(validateMenuItem:)]) {
			return [_dataSource validateMenuItem:menuItem];
		} else {
			return (action == @selector(paste:)) || ([self numberOfSelectedRows] > 0);
		}
	} else if ([_delegate respondsToSelector:action]) {
		if ([_delegate respondsToSelector:@selector(validateMenuItem:)]) {
			return [_delegate validateMenuItem:menuItem];
		} else {
			return (action == @selector(paste:)) || ([self numberOfSelectedRows] > 0);
		}
	} else if ([_dataSource respondsToSelector:dataSourceSelector]) {
		if ([_dataSource respondsToSelector:@selector(validateMenuItem:)]) {
			return [_dataSource validateMenuItem:menuItem];
		} else {
			return (action == @selector(paste:)) || ([self numberOfSelectedRows] > 0);
		}
	}else{
		// no action implemented
		return NO;
	}
}

// this is necessary as the NSTableView-OAExtensions defines these actions accordingly
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem{
	SEL action = [menuItem action];
    BOOL isOutlineView = [self isKindOfClass:[NSOutlineView class]];
	if (action == @selector(delete:)) {
		return [self validateDelegatedMenuItem:menuItem defaultDataSourceSelector:@selector(tableView:deleteRows:)];
	}
	else if (action == @selector(deleteForward:)) {
		return [_dataSource respondsToSelector:@selector(tableView:deleteRows:)];
	}
	else if (action == @selector(deleteBackward:)) {
		return [_dataSource respondsToSelector:@selector(tableView:deleteRows:)];
	}
	else if (action == @selector(cut:)) {
		return [self validateDelegatedMenuItem:menuItem defaultDataSourceSelector:isOutlineView ? @selector(outlineView:writeItems:toPasteboard:) : @selector(tableView:writeRows:toPasteboard:)];
	}
	else if (action == @selector(copy:)) {
		return [self validateDelegatedMenuItem:menuItem defaultDataSourceSelector:isOutlineView ? @selector(outlineView:writeItems:toPasteboard:) : @selector(tableView:writeRows:toPasteboard:)];
	}
	else if (action == @selector(paste:)) {
		return [self validateDelegatedMenuItem:menuItem defaultDataSourceSelector:@selector(tableView:addItemsFromPasteboard:)];
	}
	else if (action == @selector(duplicate:)) {
		return [self validateDelegatedMenuItem:menuItem defaultDataSourceSelector:isOutlineView ? @selector(outlineView:writeItems:toPasteboard:) : @selector(tableView:writeRows:toPasteboard:)];
	}
	else if (action == @selector(invertSelection:)) {
		return [self allowsMultipleSelection];
	}
    return YES; // we assume that any other implemented action is always valid
}

#pragma mark Font preferences methods

- (NSString *)fontNamePreferenceKey{
    if ([[self delegate] respondsToSelector:@selector(tableViewFontNamePreferenceKey:)])
        return [[self delegate] tableViewFontNamePreferenceKey:self];
    return nil;
}

- (NSString *)fontSizePreferenceKey{
    if ([[self delegate] respondsToSelector:@selector(tableViewFontSizePreferenceKey:)])
        return [[self delegate] tableViewFontSizePreferenceKey:self];
    return nil;
}

- (void)awakeFromNib {
    // there was no original awakeFromNib
    /*
    NSString *fontNamePrefKey = [self fontNamePreferenceKey];
    [self tableViewFontChanged:nil];
    if (fontNamePrefKey != nil) {
        [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self
            forKeyPath:[@"values." stringByAppendingString:fontNamePrefKey]
               options:0
               context:BDSKTableViewFontDefaultsObservationContext];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateFontPanel:)
                                                     name:NSWindowDidBecomeKeyNotification
                                                   object:[self window]];
    }
    */
}

- (NSControlSize)cellControlSize {
    NSCell *dataCell = [[[self tableColumns] lastObject] dataCell];
    return nil == dataCell ? NSRegularControlSize : [dataCell controlSize];
}

- (void)changeFont:(id)sender {
    NSString *fontNamePrefKey = [self fontNamePreferenceKey];
    NSString *fontSizePrefKey = [self fontSizePreferenceKey];
    if (fontNamePrefKey == nil || fontSizePrefKey == nil) 
        return;
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSUserDefaults*sud = [NSUserDefaults standardUserDefaults];
    
    NSString *fontName = [sud objectForKey:fontNamePrefKey];
    float fontSize = [sud floatForKey:fontSizePrefKey];
	NSFont *font = nil;
        
    if(fontName != nil)
        font = [NSFont fontWithName:fontName size:fontSize];
    if(font == nil)
        font = [NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:[self cellControlSize]]];
    font = [fontManager convertFont:font];
    
    // set the name last, as that's what we observe
    [sud setFloat:[font pointSize] forKey:fontSizePrefKey];
    [sud setObject:[font fontName] forKey:fontNamePrefKey];
}

- (void)tableViewFontChanged:(NSNotification *)notification {
    NSString *fontNamePrefKey = [self fontNamePreferenceKey];
    NSString *fontSizePrefKey = [self fontSizePreferenceKey];
    if (fontNamePrefKey == nil || fontSizePrefKey == nil) 
        return;

    NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:fontNamePrefKey];
    float fontSize = [[NSUserDefaults standardUserDefaults] floatForKey:fontSizePrefKey];
	NSFont *font = nil;
    
    if(fontName != nil)
        font = [NSFont fontWithName:fontName size:fontSize];
    if(font == nil)
        font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
	
	[self setFont:font];
    [self setRowHeight:[NSLayoutManager defaultViewLineHeightForFont:font] + 2.0f];
        
	[self tile];
    [self reloadData]; // othewise the change isn't immediately visible
    
}

- (void)updateFontPanel:(NSNotification *)notification {
    NSString *fontNamePrefKey = [self fontNamePreferenceKey];
    NSString *fontSizePrefKey = [self fontSizePreferenceKey];
    if ([[[self window] firstResponder] isEqual:self] && fontNamePrefKey != nil && fontSizePrefKey != nil) {
        NSString *fontName = [[NSUserDefaults standardUserDefaults] objectForKey:fontNamePrefKey];
        float fontSize = [[NSUserDefaults standardUserDefaults] floatForKey:fontSizePrefKey];
        [[NSFontManager sharedFontManager] setSelectedFont:[NSFont fontWithName:fontName size:fontSize] isMultiple:NO];
    }
}

- (IBAction)invertSelection:(id)sender;
{
    NSIndexSet *selRows = [self selectedRowIndexes];
    if ([self allowsMultipleSelection]) {
        NSMutableIndexSet *indexesToSelect = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfRows])];
        [indexesToSelect removeIndexes:selRows];
        [self selectRowIndexes:indexesToSelect byExtendingSelection:NO];
    } else {
        NSBeep();
    }
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == BDSKTableViewFontDefaultsObservationContext) {
        [self tableViewFontChanged:nil];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

#pragma mark -

@implementation NSTableView (BDSKExtensionsPrivate)

#pragma mark ToolTips for individual rows and columns

#pragma mark Font preferences overrides

- (BOOL)replacementBecomeFirstResponder {
    [self updateFontPanel:nil];
    return originalBecomeFirstResponder(self, _cmd);
}

- (void)replacementDealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#warning This is not safe!
    /*
    @try {
        NSString *fontNamePrefKey = [self fontNamePreferenceKey];
        if (fontNamePrefKey)
            [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:[@"values." stringByAppendingString:fontNamePrefKey]];
    }
    @catch (id e) {}
    */
    originalDealloc(self, _cmd);
}

#pragma mark Dragging and drag image

- (void)replacementDraggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation{
    originalDraggedImageEndedAtOperation(self, _cmd, anImage, aPoint, operation);
	
    if([[self dataSource] respondsToSelector:@selector(tableView:concludeDragOperation:)]) 
		[[self dataSource] tableView:self concludeDragOperation:operation];
    
    // flag changes during a drag are not forwarded to the application, so we fix that at the end of the drag
    [[NSNotificationCenter defaultCenter] postNotificationName:OAFlagsChangedNotification object:[NSApp currentEvent]];
}

- (NSImage *)replacementDragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns event:(NSEvent *)dragEvent offset:(NSPointPointer)dragImageOffset{
   	if([[self dataSource] respondsToSelector:@selector(tableView:dragImageForRowsWithIndexes:)]) {
		NSImage *image = [[self dataSource] tableView:self dragImageForRowsWithIndexes:dragRows];
		if (image != nil)
			return image;
	}
    if(floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_3){
        return originalDragImageForRowsWithIndexesTableColumnsEventOffset(self, _cmd, dragRows, tableColumns, dragEvent, dragImageOffset);
    } else {
        return nil;
    }
}

#pragma mark Method swizzling

+ (void)didLoad;
{
    originalBecomeFirstResponder = (typeof(originalBecomeFirstResponder))OBReplaceMethodImplementationWithSelector(self, @selector(becomeFirstResponder), @selector(replacementBecomeFirstResponder));
    originalDealloc = (void (*)(id, SEL))OBReplaceMethodImplementationWithSelector(self, @selector(dealloc), @selector(replacementDealloc));
    originalDraggedImageEndedAtOperation = (void (*)(id, SEL, id, NSPoint, NSDragOperation))OBReplaceMethodImplementationWithSelector(self, @selector(draggedImage:endedAt:operation:), @selector(replacementDraggedImage:endedAt:operation:));
    originalDragImageForRowsWithIndexesTableColumnsEventOffset = (id (*)(id, SEL, id, id, id, NSPointPointer))OBReplaceMethodImplementationWithSelector(self, @selector(dragImageForRowsWithIndexes:tableColumns:event:offset:), @selector(replacementDragImageForRowsWithIndexes:tableColumns:event:offset:));
}

#pragma mark Drop highlight

// we override this private method to draw something nicer than the default ugly black square
// from http://www.cocoadev.com/index.pl?UglyBlackHighlightRectWhenDraggingToNSTableView
// modified to use -intercellSpacing and save/restore graphics state

-(void)_drawDropHighlightOnRow:(int)rowIndex{
    NSRect drawRect = (rowIndex == -1) ? [self visibleRect] : [self rectOfRow:rowIndex];
    
    [self lockFocus];
    [NSBezierPath drawHighlightInRect:drawRect radius:4.0 lineWidth:2.0 color:[NSColor alternateSelectedControlColor]];
    [self unlockFocus];
}

#pragma mark BDSKFieldEditor delegate methods for NSControl

- (NSRange)textView:(NSTextView *)textView rangeForUserCompletion:(NSRange)charRange {
	if (textView == [self currentEditor] && [[self delegate] respondsToSelector:@selector(control:textView:rangeForUserCompletion:)]) 
		return [[self delegate] control:self textView:textView rangeForUserCompletion:charRange];
	return charRange;
}

- (BOOL)textViewShouldAutoComplete:(NSTextView *)textView {
	if (textView == [self currentEditor] && [[self delegate] respondsToSelector:@selector(control:textViewShouldAutoComplete:)]) 
		return [(id)[self delegate] control:self textViewShouldAutoComplete:textView];
	return NO;
}

- (BOOL)textViewShouldLinkKeys:(NSTextView *)textView {
    return textView == [self currentEditor] && 
           [[self delegate] respondsToSelector:@selector(control:textViewShouldLinkKeys:)] &&
           [[self delegate] control:self textViewShouldLinkKeys:textView];
}

- (BOOL)textView:(NSTextView *)textView isValidKey:(NSString *)key{
    return textView == [self currentEditor] && 
           [[self delegate] respondsToSelector:@selector(control:textView:isValidKey:)] &&
           [[self delegate] control:self textView:textView isValidKey:key];
}

- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)aLink atIndex:(unsigned)charIndex{
    return textView == [self currentEditor] && 
           [[self delegate] respondsToSelector:@selector(control:textView:clickedOnLink:atIndex:)] &&
           [[self delegate] control:self textView:textView clickedOnLink:aLink atIndex:charIndex];
}

@end

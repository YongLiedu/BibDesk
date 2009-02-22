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
#import "NSBezierPath_BDSKExtensions.h"
#import "BDSKFieldEditor.h"


@implementation NSTableView (BDSKExtensions)

// this is necessary as the NSTableView-OAExtensions defines these actions accordingly
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem{
	if ([menuItem action] == @selector(invertSelection:)) {
		return [self allowsMultipleSelection];
	}
    return YES; // we assume that any other implemented action is always valid
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

#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_4
@implementation NSTableColumn (BDSKExtensions)
- (id)dataCellForRow:(NSInteger)row {
    id cell = [self dataCell];
    id tableView = [self tableView];
    if ([tableView isKindOfClass:[NSOutlineView class]] && [[tableView delegate] respondsToSelector:@selector(outlineView:dataCellForTableColumn:item:)])
        cell = [[tableView delegate] outlineView:tableView dataCellForTableColumn:self item:[tableView itemAtRow:row]];
    else if ([tableView isKindOfClass:[NSTableView class]] && [[tableView delegate] respondsToSelector:@selector(tableView:dataCellForTableColumn:row:)])
        cell = [[tableView delegate] tableView:tableView dataCellForTableColumn:self row:row];
    return cell;
}
@end
#else
#warning fixme: remove NSTableColumn category
#endif
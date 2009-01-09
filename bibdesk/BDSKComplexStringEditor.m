// BDSKComplexStringEditor.m
// Created by Michael McCracken, January 2005

/*
 This software is Copyright (c) 2005-2009
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BDSKComplexStringEditor.h"
#import "BDSKComplexString.h"
#import "BDSKComplexStringFormatter.h"
#import "BDSKBackgroundView.h"
#import <OmniBase/OmniBase.h>
#import "NSWindowController_BDSKExtensions.h"

@interface BDSKComplexStringEditor (Private)

- (void)endEditingAndOrderOut;

- (void)attachWindow;
- (void)hideWindow;

- (NSRect)currentCellFrame;
- (id)currentCell;

- (void)setExpandedValue:(NSString *)expandedValue;
- (void)setErrorReason:(NSString *)reason errorMessage:(NSString *)message;

- (void)cellFrameDidChange:(NSNotification *)notification;
- (void)cellWindowDidBecomeKey:(NSNotification *)notification;
- (void)cellWindowDidResignKey:(NSNotification *)notification;

- (void)registerForNotifications;
- (void)unregisterForNotifications;

@end

@implementation BDSKComplexStringEditor

- (id)init {
	if (self = [super initWithWindowNibName:[self windowNibName]]) {
		tableView = nil;
        formatter = nil;
		row = -1;
		column = -1;
	}
	return self;
}

- (void)dealloc {
	[super dealloc];
}

- (NSString *)windowNibName {
    return @"ComplexStringEditor";
}

- (BOOL)attachToTableView:(NSTableView *)aTableView atRow:(int)aRow column:(int)aColumn withValue:(NSString *)aString formatter:(BDSKComplexStringFormatter *)aFormatter {
	if ([self isEditing]) 
		return NO; // we are already busy editing
    
	tableView = [aTableView retain];
	formatter = [aFormatter retain];
	row = aRow;
	column = aColumn;
	
	[self window]; // make sure we loaded the nib
	
	[tableView scrollRectToVisible:[self currentCellFrame]];
	[self setExpandedValue:aString];
	[self cellWindowDidBecomeKey:nil]; //draw the focus ring we are covering
	[self cellFrameDidChange:nil]; // reset the frame and show the window
    // track changes in the text, the frame and the window's key status of the tableView
    [self registerForNotifications];
	
	return YES;
}

- (BOOL)isEditing {
	return (tableView != nil);
}

@end

@implementation BDSKComplexStringEditor (Private)

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	NSWindow *tableViewWindow = [tableView window];
	NSView *contentView = (NSView *)[[tableView enclosingScrollView] contentView] ?: (NSView *)tableView;
	
    [nc addObserver:self
		   selector:@selector(controlTextDidChange:)
			   name:NSControlTextDidChangeNotification
			 object:tableView];
	[nc addObserver:self
		   selector:@selector(controlTextDidEndEditing:)
			   name:NSControlTextDidEndEditingNotification
			 object:tableView];

	// observe future changes in the frame and the key status of the window
	// if the target tableView has a scrollview, we should observe its content view, or we won't notice scrolling
	[nc addObserver:self
		   selector:@selector(cellFrameDidChange:)
			   name:NSViewFrameDidChangeNotification
			 object:contentView];
	[nc addObserver:self
		   selector:@selector(cellFrameDidChange:)
			   name:NSViewBoundsDidChangeNotification
			 object:contentView];
	[nc addObserver:self
		   selector:@selector(cellWindowDidBecomeKey:)
			   name:NSWindowDidBecomeKeyNotification
			 object:tableViewWindow];
	[nc addObserver:self
		   selector:@selector(cellWindowDidResignKey:)
			   name:NSWindowDidResignKeyNotification
			 object:tableViewWindow];
    [nc addObserver:self
           selector:@selector(tableViewColumnDidResize:)
               name:NSTableViewColumnDidResizeNotification
             object:tableView];
    [nc addObserver:self
           selector:@selector(tableViewColumnDidMove:)
               name:NSTableViewColumnDidMoveNotification
             object:tableView];
}

- (void)unregisterForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	NSWindow *tableViewWindow = [tableView window];
	NSView *contentView = (NSView *)[[tableView enclosingScrollView] contentView] ?: (NSView *)tableView;
	
	[nc removeObserver:self name:NSControlTextDidChangeNotification object:tableView];
	[nc removeObserver:self name:NSControlTextDidEndEditingNotification object:tableView];
	[nc removeObserver:self name:NSViewFrameDidChangeNotification object:contentView];
	[nc removeObserver:self name:NSViewBoundsDidChangeNotification object:contentView];
	[nc removeObserver:self name:NSWindowDidBecomeKeyNotification object:tableViewWindow];
	[nc removeObserver:self name:NSWindowDidResignKeyNotification object:tableViewWindow];
    [nc removeObserver:self name:NSTableViewColumnDidResizeNotification object:tableView];
    [nc removeObserver:self name:NSTableViewColumnDidMoveNotification object:tableView];
}

- (void)endEditingAndOrderOut {
    // we're going away now, so we can unregister for the notifications we registered for earlier
	[self unregisterForNotifications];
    [self hideWindow];
	
	// release the temporary objects
	[tableView release];
	tableView = nil; // we should set this to nil, as we use this as a flag that we are editing
	[formatter release];
	formatter = nil;
	row = -1;
	column = -1;
}

- (void)attachWindow {
	[[tableView window] addChildWindow:[self window] ordered:NSWindowAbove];
    [[self window] orderFront:self];
}

- (void)hideWindow {
    [[tableView window] removeChildWindow:[self window]];
    [[self window] orderOut:self];
}

- (id)currentCell {
    return [[[tableView tableColumns] objectAtIndex:column] dataCellForRow:row];
}

- (NSRect)currentCellFrame {
	return [tableView frameOfCellAtColumn:column row:row];
}

- (void)setExpandedValue:(NSString *)expandedValue {
	NSColor *color = [NSColor blueColor];
	if ([expandedValue isInherited]) 
		color = [color blendedColorWithFraction:0.4 ofColor:[NSColor textBackgroundColor]];
	[expandedValueTextField setTextColor:color];
	[expandedValueTextField setStringValue:expandedValue];
	[expandedValueTextField setToolTip:NSLocalizedString(@"This field contains macros and is being edited as it would appear in a BibTeX file. This is the expanded value.", @"Tool tip message")];
}

- (void)setErrorReason:(NSString *)reason errorMessage:(NSString *)message {
	[expandedValueTextField setTextColor:[NSColor redColor]];
	[expandedValueTextField setStringValue:reason];
	[expandedValueTextField setToolTip:message]; 
}

#pragma mark Frame change and keywindow notification handlers

- (void)cellFrameDidChange:(NSNotification *)notification {
	NSRectEdge lowerEdge = [tableView isFlipped] ? NSMaxYEdge : NSMinYEdge;
	NSRect lowerEdgeRect, ignored;
	NSRect winFrame = [[self window] frame];
	float margin = 4.0; // for the shadow and focus ring
	float minWidth = 16.0; // minimal width of the window without margins, so subviews won't get shifted
	NSView *contentView = (NSView *)[[tableView enclosingScrollView] contentView] ?: (NSView *)tableView;
	
	NSDivideRect([self currentCellFrame], &lowerEdgeRect, &ignored, 1.0, lowerEdge);
	lowerEdgeRect = NSIntersectionRect(lowerEdgeRect, [contentView visibleRect]);
	// see if the cell's lower edge is scrolled out of sight
	if (NSIsEmptyRect(lowerEdgeRect)) {
		if ([self isWindowVisible] == YES) 
			[self hideWindow];
		return;
	}
	
	lowerEdgeRect = [tableView convertRect:lowerEdgeRect toView:nil]; // takes into account isFlipped
    winFrame.origin = [[tableView window] convertBaseToScreen:lowerEdgeRect.origin];
	winFrame.origin.y -= NSHeight(winFrame);
	winFrame.size.width = fmaxf(NSWidth(lowerEdgeRect), minWidth);
	winFrame = NSInsetRect(winFrame, -margin, 0.0);
	[[self window] setFrame:winFrame display:YES];
	
	if ([self isWindowVisible] == NO) 
		[self attachWindow];
}

- (void)cellWindowDidBecomeKey:(NSNotification *)notification {
	[backgroundView setShowFocusRing:[[self currentCell] isEditable]];
}

- (void)cellWindowDidResignKey:(NSNotification *)notification {
	[backgroundView setShowFocusRing:NO];
}

#pragma mark Window close delegate method

- (void)windowWillClose:(NSNotification *)notification {
	// this gets called whenever an editor window closes
	if ([self isEditing]){
        OBASSERT_NOT_REACHED("macro textfield window closed while editing");
		[self endEditingAndOrderOut];
    }
}

#pragma mark NSControl notification handlers

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    [self endEditingAndOrderOut];
}

- (void)controlTextDidChange:(NSNotification*)notification { 
	NSString *error = [formatter parseError];
	if (error)
		[self setErrorReason:error errorMessage:[NSString stringWithFormat:NSLocalizedString(@"Invalid BibTeX string: %@. This change will not be recorded.", @"Tool tip message"),error]];
	else
		[self setExpandedValue:[formatter parsedString]];
}

#pragma mark NSTableView notification handlers

- (void)tableViewColumnDidResize:(NSNotification *)notification {
	[self cellFrameDidChange:nil];
}

- (void)tableViewColumnDidMove:(NSNotification *)notification {
	NSDictionary *userInfo = [notification userInfo];
	int oldColumn = [[userInfo objectForKey:@"oldColumn"] intValue];
	int newColumn = [[userInfo objectForKey:@"newColumn"] intValue];
	if (oldColumn == column) {
		column = newColumn;
	} else if (oldColumn < column) {
		if (newColumn >= column)
			column--;
	} else if (oldColumn > column) {
		if (newColumn < column)
			column++;
	}
	[self cellFrameDidChange:nil];
}

@end

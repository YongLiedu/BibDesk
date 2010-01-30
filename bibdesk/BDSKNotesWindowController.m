//
//  BDSKNotesWindowController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/25/07.
/*
 This software is Copyright (c) 2007-2010
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

#import "BDSKNotesWindowController.h"
#import "BDSKAppController.h"
#import "NSURL_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"


@interface BDSKNotesWindowController (Private)
- (void)reloadNotes;
@end

@implementation BDSKNotesWindowController

- (id)initWithURL:(NSURL *)aURL {
    if (self = [super init]) {
        if (aURL == nil) {
            [self release];
            return nil;
        }
        
        url = [aURL retain];
        notes = [[NSMutableArray alloc] init];
        tags = nil;
        rating = 0.0;
        
        [self refresh:nil];
    }
    return self;
}

- (void)dealloc {
    [outlineView setDelegate:nil];
    [outlineView setDataSource:nil];
    [tokenField setDelegate:nil];
    BDSKDESTROY(url);
    BDSKDESTROY(notes);
    BDSKDESTROY(tags);
    [super dealloc];
}

- (NSString *)windowNibName { return @"NotesWindow"; }

- (void)windowWillClose:(NSNotification *)notification {
    [ownerController commitEditing];
    [ownerController setContent:nil];
}

- (void)windowDidLoad {
    [self setWindowFrameAutosaveNameOrCascade:@"NotesWindow"];
    
    [splitView setAutosaveName:@"BDSKNotesWindow"];
    if ([self windowFrameAutosaveName] == nil) {
        // Only autosave the frames when the window's autosavename is set to avoid inconsistencies
        [splitView setAutosaveName:nil];
    }
    
    [tokenField setTokenizingCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName{
    return [NSString stringWithFormat:@"%@ %@ %@", [[url path] lastPathComponent], [NSString emdashString], NSLocalizedString(@"Notes", @"Partial window title")];
}

- (void)synchronizeWindowTitleWithDocumentName {
    [super synchronizeWindowTitleWithDocumentName];
    // replace the proxy icon with the url, somehow passing nil does not work
    [[self window] setRepresentedFilename:[url path] ?: @""];
}

- (void)reloadNotes {
    [notes removeAllObjects];
    for (NSDictionary *dict in [url SkimNotes]) {
        NSMutableDictionary *note = [dict mutableCopy];
        
        [note setObject:[NSNumber numberWithDouble:19.0] forKey:@"rowHeight"];
        if ([[dict valueForKey:@"type"] isEqualToString:@"Note"])
            [note setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:85.0], @"rowHeight", [dict valueForKey:@"text"], @"contents", nil] forKey:@"child"];
        
        [notes addObject:note];
        [note release];
    }
    
    [notes sortUsingDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"page" ascending:YES] autorelease]]];
}

- (NSArray *)tags {
    return tags;
}

- (void)setTags:(NSArray *)newTags {
    if (tags != newTags) {
        [tags release];
        tags = [newTags retain];
    }
}

- (double)rating {
    return rating;
}

- (void)setRating:(double)newRating {
    rating = newRating;
}

#pragma mark Actions

- (IBAction)refresh:(id)sender {
    [self reloadNotes];
    [self setTags:[url openMetaTags]];
    [self setRating:[url openMetaRating]];
}

- (IBAction)openInSkim:(id)sender {
    [[NSWorkspace sharedWorkspace] openFile:[url path] withApplication:@"Skim"];
}

#pragma mark NSOutlineView datasource and delegate methods

- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item {
    if (item == nil)
        return [notes count];
    else if ([[item valueForKey:@"type"] isEqualToString:@"Note"])
        return 1;
    return 0;
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item {
    return [[item valueForKey:@"type"] isEqualToString:@"Note"];
}

- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)idx ofItem:(id)item {
    if (item == nil) {
        return [notes objectAtIndex:idx];
    } else {
        return [item valueForKey:@"child"];
    }
}

- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    NSString *tcID = [tableColumn identifier];
    if ([tcID isEqualToString:@"note"]) {
        return [item valueForKey:@"contents"];
    } else if ([tcID isEqualToString:@"page"]) {
        NSNumber *pageNumber = [item valueForKey:@"pageIndex"];
        return pageNumber ? [NSString stringWithFormat:@"%ld", (long)[pageNumber integerValue] + 1] : nil;
    }
    return nil;
}

- (CGFloat)outlineView:(NSOutlineView *)ov heightOfRowByItem:(id)item {
    NSNumber *heightNumber = [item valueForKey:@"rowHeight"];
    return heightNumber ? [heightNumber doubleValue] : 17.0;
}

- (void)outlineView:(NSOutlineView *)ov setHeightOfRow:(NSInteger)newHeight byItem:(id)item {
    [item setObject:[NSNumber numberWithDouble:newHeight] forKey:@"rowHeight"];
}

- (BOOL)outlineView:(NSOutlineView *)ov canResizeRowByItem:(id)item {
    return nil != [item valueForKey:@"rowHeight"];
}

- (NSString *)outlineView:(NSOutlineView *)ov toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn item:(id)item mouseLocation:(NSPoint)mouseLocation {
    return [item valueForKey:@"type"] ? [item valueForKey:@"contents"] : [[item valueForKey:@"contents"] string];
}

- (BOOL)outlineView:(NSOutlineView *)tv writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard {
    id lastItem = nil;
    NSMutableString *string = [NSMutableString string];
    
    for (id item in items) {
        if ([lastItem objectForKey:@"child"] == item)
            continue;
        lastItem = item;
        NSString *contents = [item valueForKey:@"type"] ? [item valueForKey:@"contents"] : [[item valueForKey:@"contents"] string];
        
        if ([contents length]) {
            if ([string length])
                [string appendString:@"\n\n"];
            [string appendString:contents];
            contents = [[item valueForKey:@"text"] string];
            if ([contents length]) {
                [string appendString:@"\n\n"];
                [string appendString:contents];
            }
        }
    }
    
    [pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:nil];
    [pboard setString:string forType:NSStringPboardType];
    
    return YES;
}

#pragma mark NSTokenField deldegate methods

- (BOOL)tokenField:(NSTokenField *)tokenField writeRepresentedObjects:(NSArray *)objects toPasteboard:(NSPasteboard *)pboard {
    if (objects) {
        [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
        [pboard setString:[objects componentsJoinedByString:@" "] forType:NSStringPboardType];
        return YES;
    }
    return NO;
}

#pragma mark NSSplitView deldegate methods

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview {
    return [subview isEqual:tokenField];
}

- (BOOL)splitView:(NSSplitView *)sender shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex {
    return [subview isEqual:tokenField];
}

@end


@implementation BDSKNotesOutlineView

- (void)resizeRow:(NSInteger)row withEvent:(NSEvent *)theEvent {
    id item = [self itemAtRow:row];
    NSPoint startPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    CGFloat startHeight = [[self delegate] outlineView:self heightOfRowByItem:item];
	BOOL keepGoing = YES;
	
    [[NSCursor resizeUpDownCursor] push];
    
	while (keepGoing) {
		theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
		switch ([theEvent type]) {
			case NSLeftMouseDragged:
            {
                NSPoint currentPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
                CGFloat currentHeight = fmax([self rowHeight], startHeight + currentPoint.y - startPoint.y);
                
                [[self delegate] outlineView:self setHeightOfRow:currentHeight byItem:item];
                [self noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:row]];
                
                break;
			}
            
            case NSLeftMouseUp:
                keepGoing = NO;
                break;
			
            default:
                break;
        }
    }
    [NSCursor pop];
}

- (void)mouseDown:(NSEvent *)theEvent {
    if ([theEvent clickCount] == 1 && [[self delegate] respondsToSelector:@selector(outlineView:canResizeRowByItem:)] && [[self delegate] respondsToSelector:@selector(outlineView:setHeightOfRow:byItem:)]) {
        NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        NSInteger row = [self rowAtPoint:mouseLoc];
        
        if (row != -1 && [[self delegate] outlineView:self canResizeRowByItem:[self itemAtRow:row]]) {
            NSRect ignored, rect;
            NSDivideRect([self rectOfRow:row], &rect, &ignored, 5.0, [self isFlipped] ? NSMaxYEdge : NSMinYEdge);
            if (NSMouseInRect(mouseLoc, rect, [self isFlipped]) && NSLeftMouseDragged == [[NSApp nextEventMatchingMask:(NSLeftMouseUpMask | NSLeftMouseDraggedMask) untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:NO] type]) {
                [self resizeRow:row withEvent:theEvent];
                return;
            }
        }
    }
    [super mouseDown:theEvent];
}

- (void)drawRect:(NSRect)aRect {
    [super drawRect:aRect];
    if ([[self delegate] respondsToSelector:@selector(outlineView:canResizeRowByItem:)]) {
        NSRange visibleRows = [self rowsInRect:[self visibleRect]];
        
        if (visibleRows.length == 0)
            return;
        
        NSUInteger row;
        BOOL isFirstResponder = [[self window] isKeyWindow] && [[self window] firstResponder] == self;
        
        [NSGraphicsContext saveGraphicsState];
        [NSBezierPath setDefaultLineWidth:1.0];
        
        for (row = visibleRows.location; row < NSMaxRange(visibleRows); row++) {
            id item = [self itemAtRow:row];
            if ([[self delegate] outlineView:self canResizeRowByItem:item] == NO)
                continue;
            
            BOOL isHighlighted = isFirstResponder && [self isRowSelected:row];
            NSColor *color = [NSColor colorWithCalibratedWhite:isHighlighted ? 1.0 : 0.5 alpha:0.7];
            NSRect rect = [self rectOfRow:row];
            CGFloat x = ceil(NSMidX(rect));
            CGFloat y = NSMaxY(rect) - 1.5;
            
            [color set];
            [NSBezierPath strokeLineFromPoint:NSMakePoint(x - 1.0, y) toPoint:NSMakePoint(x + 1.0, y)];
            y -= 2.0;
            [NSBezierPath strokeLineFromPoint:NSMakePoint(x - 3.0, y) toPoint:NSMakePoint(x + 3.0, y)];
        }
        
        [NSGraphicsContext restoreGraphicsState];
    }
}

- (void)expandItem:(id)item expandChildren:(BOOL)collapseChildren {
    // NSOutlineView does not call resetCursorRect when expanding
    [super expandItem:item expandChildren:collapseChildren];
    [self resetCursorRects];
}

- (void)collapseItem:(id)item collapseChildren:(BOOL)collapseChildren {
    // NSOutlineView does not call resetCursorRect when collapsing
    [super collapseItem:item collapseChildren:collapseChildren];
    [self resetCursorRects];
}

-(void)resetCursorRects {
    if ([[self delegate] respondsToSelector:@selector(outlineView:canResizeRowByItem:)]) {
        [self discardCursorRects];
        [super resetCursorRects];

        NSRange visibleRows = [self rowsInRect:[self visibleRect]];
        NSUInteger row;
        
        if (visibleRows.length == 0)
            return;
        
        for (row = visibleRows.location; row < NSMaxRange(visibleRows); row++) {
            id item = [self itemAtRow:row];
            if ([[self delegate] outlineView:self canResizeRowByItem:item] == NO)
                continue;
            NSRect ignored, rect = [self rectOfRow:row];
            NSDivideRect(rect, &rect, &ignored, 5.0, [self isFlipped] ? NSMaxYEdge : NSMinYEdge);
            [self addCursorRect:rect cursor:[NSCursor resizeUpDownCursor]];
        }
    } else {
        [super resetCursorRects];
    }
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
    return isLocal ? NSDragOperationEvery : NSDragOperationCopy;
}

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
- (id <BDSKNotesOutlineViewDelegate>)delegate {
    return (id <BDSKNotesOutlineViewDelegate>)[super delegate];
}

- (void)setDelegate:(id <BDSKNotesOutlineViewDelegate>)newDelegate {
    [super setDelegate:newDelegate];
}
#endif

@end

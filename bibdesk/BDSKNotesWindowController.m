//
//  BDSKNotesWindowController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/25/07.
/*
 This software is Copyright (c) 2007-2009
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


@implementation BDSKNotesWindowController

- (id)initWithURL:(NSURL *)aURL {
    if (self = [super init]) {
        if (aURL == nil) {
            [self release];
            return nil;
        }
        
        url = [aURL retain];
        notes = [[NSMutableArray alloc] init];
        
        [self refresh:self];
    }
    return self;
}

- (void)dealloc {
    [url release];
    [notes release];
    [super dealloc];
}

- (NSString *)windowNibName { return @"NotesWindow"; }

- (void)awakeFromNib {
    [self setWindowFrameAutosaveNameOrCascade:@"NotesWindow"];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName{
    return [NSString stringWithFormat:@"%@ %@ %@", [[url path] lastPathComponent], [NSString emdashString], NSLocalizedString(@"Notes", @"Partial window title")];
}

- (NSString *)representedFilenameForWindow:(NSWindow *)aWindow {
    NSString *path = [url path];
    return path ?: @"";
}

- (NSArray *)tags {
    return [url openMetaTags];
}

- (void)setTags:(NSArray *)tags {
    [url setOpenMetaTags:tags];
}

- (double)rating {
    return [url openMetaRating];
}

- (void)setRating:(double)rating {
    [url setOpenMetaRating:rating];
}

#pragma mark Actions

- (IBAction)refresh:(id)sender {
    NSEnumerator *dictEnum = [[url SkimNotes] objectEnumerator];
    NSDictionary *dict;
    
    [notes removeAllObjects];
    while (dict = [dictEnum nextObject]) {
        NSMutableDictionary *note = [dict mutableCopy];
        
        [note setObject:[NSNumber numberWithFloat:19.0] forKey:@"rowHeight"];
        if ([[dict valueForKey:@"type"] isEqualToString:@"Note"])
            [note setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:85.0], @"rowHeight", [dict valueForKey:@"text"], @"contents", nil] forKey:@"child"];
        
        [notes addObject:note];
        [note release];
    }
    
    [notes sortUsingDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"page" ascending:YES] autorelease]]];
    
    [outlineView reloadData];
}

- (IBAction)openInSkim:(id)sender {
    [[NSWorkspace sharedWorkspace] openFile:[url path] withApplication:@"Skim"];
}

#pragma mark NSOutlineView datasource and delegate methods

- (int)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item {
    if (item == nil)
        return [notes count];
    else if ([[item valueForKey:@"type"] isEqualToString:@"Note"])
        return 1;
    return 0;
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item {
    return [[item valueForKey:@"type"] isEqualToString:@"Note"];
}

- (id)outlineView:(NSOutlineView *)ov child:(int)idx ofItem:(id)item {
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
        return pageNumber ? [NSString stringWithFormat:@"%i", [pageNumber intValue] + 1] : nil;
    }
    return nil;
}

- (float)outlineView:(NSOutlineView *)ov heightOfRowByItem:(id)item {
    NSNumber *heightNumber = [item valueForKey:@"rowHeight"];
    return heightNumber ? [heightNumber floatValue] : 17.0;
}

- (void)outlineView:(NSOutlineView *)ov setHeightOfRow:(int)newHeight byItem:(id)item {
    [item setObject:[NSNumber numberWithFloat:newHeight] forKey:@"rowHeight"];
}

- (BOOL)outlineView:(NSOutlineView *)ov canResizeRowByItem:(id)item {
    return nil != [item valueForKey:@"rowHeight"];
}

- (NSString *)outlineView:(NSOutlineView *)ov toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn item:(id)item mouseLocation:(NSPoint)mouseLocation {
    return [item valueForKey:@"type"] ? [item valueForKey:@"contents"] : [[item valueForKey:@"contents"] string];
}

- (BOOL)outlineView:(NSOutlineView *)tv writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard {
    NSEnumerator *itemEnum = [items objectEnumerator];
    id item, lastItem = nil;
    NSMutableString *string = [NSMutableString string];
    
    while (item = [itemEnum nextObject]) {
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

@end


@implementation BDSKNotesOutlineView

- (void)resizeRow:(int)row withEvent:(NSEvent *)theEvent {
    id item = [self itemAtRow:row];
    NSPoint startPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    float startHeight = [[self delegate] outlineView:self heightOfRowByItem:item];
	BOOL keepGoing = YES;
	
    [[NSCursor resizeUpDownCursor] push];
    
	while (keepGoing) {
		theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
		switch ([theEvent type]) {
			case NSLeftMouseDragged:
            {
                NSPoint currentPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
                float currentHeight = fmaxf([self rowHeight], startHeight + currentPoint.y - startPoint.y);
                
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
        int row = [self rowAtPoint:mouseLoc];
        
        if (row != -1 && [[self delegate] outlineView:self canResizeRowByItem:[self itemAtRow:row]]) {
            NSRect ignored, rect;
            NSDivideRect([self rectOfRow:row], &rect, &ignored, 5.0, [self isFlipped] ? NSMaxYEdge : NSMinYEdge);
            if (NSPointInRect(mouseLoc, rect) && NSLeftMouseDragged == [[NSApp nextEventMatchingMask:(NSLeftMouseUpMask | NSLeftMouseDraggedMask) untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:NO] type]) {
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
        
        unsigned int row;
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
            float x = ceilf(NSMidX(rect));
            float y = NSMaxY(rect) - 1.5;
            
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
        unsigned int row;
        
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

@end

//
//  BDSKDragTextField.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/14/07.
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

#import "BDSKDragTextField.h"
#import "BDSKIconTextFieldCell.h"
#import "NSBezierPath_BDSKExtensions.h"


@implementation BDSKDragTextField

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender{
    NSDragOperation dragOp = NSDragOperationNone;
	if ([[self delegate] respondsToSelector:@selector(dragTextField:validateDrop:)])
		dragOp = [[self delegate] dragTextField:self validateDrop:sender];
	if (dragOp != NSDragOperationNone) {
		highlight = YES;
		[self setNeedsDisplay:YES];
	}
	return dragOp;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender{
    highlight = NO;
	[self setNeedsDisplay:YES];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    highlight = NO;
	[self setNeedsDisplay:YES];
	if ([[self delegate] respondsToSelector:@selector(dragTextField:acceptDrop:)])
		return [[self delegate] dragTextField:self acceptDrop:sender];
	return NO;
}

- (void)drawRect:(NSRect)aRect {
	[super drawRect:aRect];
	
	if (highlight) {
        [NSGraphicsContext saveGraphicsState];
        [NSBezierPath drawHighlightInRect:[self bounds] radius:4.0 lineWidth:2.0 color:[NSColor alternateSelectedControlColor]];
        [NSGraphicsContext restoreGraphicsState];
	}
}

- (void)setKeyboardFocusRingNeedsDisplayInRect:(NSRect)rect {
    return [super setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
}

- (void)mouseDown:(NSEvent *)theEvent {
    if ([[self cell] respondsToSelector:@selector(iconRectForBounds:)] && [[self delegate] respondsToSelector:@selector(dragTextField:writeDataToPasteboard:)]) {
        NSRect iconRect = [[self cell] iconRectForBounds:[self bounds]];
        NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        if (NSMouseInRect(mouseLoc, iconRect, [self isFlipped])) {
            NSEvent *nextEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
            
            if (NSLeftMouseDragged == [nextEvent type]) {
                NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
                
                if ([[self delegate] dragTextField:self writeDataToPasteboard:pboard]) {
               
                    NSImage *dragImage = nil;
                    NSSize imageSize = NSZeroSize;
                    NSImage *image = nil;
                    NSRect drawRect = [self bounds];
                    NSRect rect = [[self cell] iconRectForBounds:drawRect];
                    NSPoint dragPoint = rect.origin;
                    if ([self isFlipped])
                        dragPoint.y += NSHeight(rect);
                    drawRect.origin.x -= NSMinX(rect);
                    drawRect.origin.y -= NSMinY(rect);
                    image = [[NSImage alloc] initWithSize:rect.size];
                    [image lockFocus];
                    [[self cell] drawInteriorWithFrame:drawRect inView:nil];
                    [image unlockFocus];
                    imageSize = [image size];
                    dragImage = [[[NSImage alloc] initWithSize:imageSize] autorelease];
                    [dragImage lockFocus];
                    [image drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:0.7];
                    [dragImage unlockFocus];
                    [image release];
                    [self dragImage:dragImage at:dragPoint offset:NSZeroSize event:theEvent pasteboard:pboard source:self slideBack:YES]; 
                }
            }
            return;
        }
    }
    [super mouseDown:theEvent];
}

// flag changes during a drag are not forwarded to the application, so we fix that at the end of the drag
- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation{
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKFlagsChangedNotification object:NSApp];
}

#pragma mark Delegate

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
- (id <BDSKDragTextFieldDelegate>)delegate {
    return (id <BDSKDragTextFieldDelegate>)[super delegate];
}

- (void)setDelegate:(id <BDSKDragTextFieldDelegate>)newDelegate {
    [super setDelegate:newDelegate];
}
#endif

@end

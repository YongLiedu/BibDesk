//
//  BDSKPreferenceIconCell.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/17/09.
/*
 This software is Copyright (c) 2009-2012
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

#import "BDSKPreferenceIconCell.h"
#import "NSGeometry_BDSKExtensions.h"


@implementation BDSKPreferenceIconCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSSize cellSize = [self cellSizeForBounds:cellFrame];
    if (cellSize.height < NSHeight(cellFrame))
        cellFrame = BDSKSliceRect(cellFrame, cellSize.height, [controlView isFlipped] ? NSMaxYEdge : NSMinYEdge);
    [super drawWithFrame:cellFrame inView:controlView];
}

- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)untilMouseUp {
    if (NSPointInRect([theEvent locationInWindow], [controlView convertRect:cellFrame toView:nil])) {
        if (NSLeftMouseDragged == [[NSApp nextEventMatchingMask:NSLeftMouseUpMask | NSLeftMouseDraggedMask untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:NO] type]) {
            [self highlight:NO withFrame:cellFrame inView:controlView];
            NSRect rect = {NSZeroPoint, [self cellSize]};
            NSImage *tmpImage = [[NSImage alloc] initWithSize:rect.size];
            NSImage *dragImage = [[NSImage alloc] initWithSize:rect.size];
            
            [tmpImage setFlipped:YES];
            [tmpImage lockFocus];
            [self drawWithFrame:rect inView:nil];
            [tmpImage unlockFocus];
            [dragImage lockFocus];
            [tmpImage drawInRect:rect fromRect:rect operation:NSCompositeSourceOver fraction:0.7];
            [dragImage unlockFocus];
            [tmpImage release];
            
            NSPoint point = cellFrame.origin;
            point.x += (NSWidth(cellFrame) - NSWidth(rect)) / 2.0;
            if ([controlView isFlipped])
                point.y += NSHeight(cellFrame);
            
            NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
            [pboard declareTypes:[NSArray arrayWithObject:@"NSToolbarIndividualItemDragType"] owner:nil];
            [pboard setString:[self representedObject] forType:@"NSToolbarItemIdentifierPboardType"];
            [controlView dragImage:dragImage at:point offset:NSZeroSize event:theEvent pasteboard:pboard source:controlView slideBack:YES];
            [dragImage release];
        } else {
            [super trackMouse:theEvent inRect:cellFrame ofView:controlView untilMouseUp:untilMouseUp];
        }
	} 
    return YES;
}

@end

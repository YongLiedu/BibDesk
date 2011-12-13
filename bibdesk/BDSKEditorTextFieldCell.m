//
//  BDSKEditorTextFieldCell.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/11/07.
/*
 This software is Copyright (c) 2007-2011
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

#import "BDSKEditorTextFieldCell.h"
#import "NSImage_BDSKExtensions.h"

#define BUTTON_MARGIN 2.0
#define BUTTON_SIZE NSMakeSize(12.0, 12.0)

@implementation BDSKEditorTextFieldCell

+ (BOOL)prefersTrackingUntilMouseUp { return YES; }

- (void)commonInit {
    [self setBezeled:YES];
    [self setDrawsBackground:YES];
    [self setHasButton:NO];
    buttonCell = [[NSButtonCell alloc] initImageCell:[NSImage imageNamed:NSImageNameFollowLinkFreestandingTemplate]];
    [buttonCell setButtonType:NSMomentaryChangeButton];
    [buttonCell setBordered:NO];
    [buttonCell setImagePosition:NSImageOnly];
    [buttonCell setImageScaling:NSImageScaleProportionallyDown];
    url = nil;
}

- (id)initTextCell:(NSString *)aString {
    self = [super initTextCell:aString];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    BDSKEditorTextFieldCell *copy = [super copyWithZone:zone];
    copy->buttonCell = [buttonCell copyWithZone:zone];
    copy->hasButton = hasButton;
    copy->url = [url retain];
    return copy;
}

- (void)dealloc {
    BDSKDESTROY(url);
    BDSKDESTROY(buttonCell);
    [super dealloc];
}

- (NSUInteger)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView
{
    NSUInteger hit = [super hitTestForEvent:event inRect:cellFrame ofView:controlView];
    // super returns 0 for button clicks, so -[NSTableView mouseDown:] doesn't track the cell
    NSRect buttonRect = [self buttonRectForBounds:cellFrame];
    NSPoint mouseLoc = [controlView convertPoint:[event locationInWindow] fromView:nil];
    if (NSMouseInRect(mouseLoc, buttonRect, [controlView isFlipped]))
        hit = NSCellHitContentArea | NSCellHitTrackableArea;
    return hit;
}

- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)untilMouseUp {
    NSRect buttonRect = [self buttonRectForBounds:cellFrame];
    NSPoint mouseLoc = [controlView convertPoint:[theEvent locationInWindow] fromView:nil];
    BOOL insideButton = NSMouseInRect(mouseLoc, buttonRect, [controlView isFlipped]);
    if (insideButton) {
		BOOL keepOn = YES;
		while (keepOn) {
            if (insideButton) {
                // NSButtonCell does not highlight itself
                [buttonCell highlight:YES withFrame:buttonRect inView:controlView];
                // tracks until a click (returns YES) or the mouse exits (returns NO)
                keepOn = (NO == [buttonCell trackMouse:theEvent inRect:buttonRect ofView:controlView untilMouseUp:NO]);
                [buttonCell highlight:NO withFrame:buttonRect inView:controlView];
                if (keepOn && [self URL]) {
                    // mouse dragged outside a URL icon, start a drag and stop tracking ourselves
                    keepOn = NO;
                    NSImage *image = [[NSImage imageForURL:[self URL]] dragImageWithCount:0];
                    NSSize imageSize = [image size];
                    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
                    if ([[self URL] isFileURL]) {
                        [pboard declareTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil] owner:nil];
                        [pboard setPropertyList:[NSArray arrayWithObjects:[[self URL] path], nil] forType:NSFilenamesPboardType];
                    } else {
                        [pboard declareTypes:[NSArray arrayWithObjects:NSURLPboardType, nil] owner:nil];
                        [[self URL] writeToPasteboard:pboard];
                    }
                    [controlView dragImage:image at:NSMakePoint(mouseLoc.x - 0.5f * imageSize.width, mouseLoc.y + 0.5f * imageSize.height) offset:NSZeroSize event:theEvent pasteboard:pboard source:controlView slideBack:YES]; 
                }
            }
            if (keepOn) {
                // we're dragging outside the button, wait for a mouseup or move back inside
                theEvent = [[controlView window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
                mouseLoc = [controlView convertPoint:[theEvent locationInWindow] fromView:nil];
                insideButton = NSMouseInRect(mouseLoc, buttonRect, [controlView isFlipped]);
                keepOn = ([theEvent type] == NSLeftMouseDragged);
            }
		}
        return YES;
    } else 
        return [super trackMouse:theEvent inRect:cellFrame ofView:controlView untilMouseUp:untilMouseUp];
}

- (NSURL *)URL {
    return url;
}

- (void)setURL:(NSURL *)newURL {
    if (url != newURL) {
        [url release];
        url = [newURL retain];
    }
}

- (BOOL)hasButton {
    return hasButton;
}

- (void)setHasButton:(BOOL)flag {
    if (hasButton != flag) {
        hasButton = flag;
    }
}

- (id)buttonTarget {
    return [buttonCell target];
}

- (void)setButtonTarget:(id)target {
    [buttonCell setTarget:target];
}

- (SEL)buttonAction {
    return [buttonCell action];
}

- (void)setButtonAction:(SEL)selector {
    [buttonCell setAction:selector];
}

- (NSRect)buttonRectForBounds:(NSRect)theRect {
	NSRect buttonRect = NSZeroRect;
    
	if ([self hasButton] || [self URL]) {
        NSSize size = BUTTON_SIZE;
        buttonRect.origin.x = NSMaxX(theRect) - size.width - BUTTON_MARGIN;
        buttonRect.origin.y = ceil(NSMidY(theRect) - 0.5 * size.height);
        buttonRect.size = size;
	}
    return buttonRect;
}

- (NSRect)drawingRectForBounds:(NSRect)theRect {
	if ([self hasButton] || [self URL]) {
        NSRect ignored;
        NSSize size = BUTTON_SIZE;
        NSDivideRect(theRect, &ignored, &theRect, size.width + BUTTON_MARGIN, NSMaxXEdge);
    }
    return [super drawingRectForBounds:theRect];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [super drawInteriorWithFrame:cellFrame inView:controlView];
	
	if ([self hasButton] || [self URL]) {
        NSRect buttonRect = [self buttonRectForBounds:cellFrame];
        NSImage *theImage = [self URL] ? [NSImage imageForURL:[self URL]] : [NSImage imageNamed:NSImageNameFollowLinkFreestandingTemplate];
        [buttonCell setImage:theImage];
        [buttonCell drawWithFrame:buttonRect inView:controlView];
    }
}

// NSTextFieldCell draws this with the wrong baseline, or possibly it wraps lines even though the cell is set to clip
- (void)drawWithExpansionFrame:(NSRect)cellFrame inView:(NSView *)view
{
    [[self attributedStringValue] drawInRect:NSInsetRect(cellFrame, 2.0, 0.0)];
}

// make sure it uses black text on Leopard when the row is selected (see bug #1866083)
- (NSBackgroundStyle)backgroundStyle { return NSBackgroundStyleLight; }
- (NSBackgroundStyle)interiorBackgroundStyle { return NSBackgroundStyleLight; }

- (NSSize)cellSizeForBounds:(NSRect)aRect {
    NSSize cellSize = [super cellSizeForBounds:aRect];
    if ([self hasButton] || [self URL])
        cellSize.width = fmin(cellSize.width + BUTTON_SIZE.width + BUTTON_MARGIN, NSWidth(aRect));
    return cellSize;
}

- (NSText *)setUpFieldEditorAttributes:(NSText *)textObj {
    textObj = [super setUpFieldEditorAttributes:textObj];
    if ([self drawsBackground])
        [textObj setBackgroundColor:[NSColor textBackgroundColor]];
    return textObj;
}

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    return nil;
}

- (NSColor *)textColor {
    return [NSColor blackColor];
}

@end

#define LABEL_EFFECTIVE_HEIGHT 20.0

@implementation BDSKLabelTextFieldCell

// make sure it uses black text on Leopard when the row is selected
- (NSBackgroundStyle)backgroundStyle { return NSBackgroundStyleLight; }
- (NSBackgroundStyle)interiorBackgroundStyle { return NSBackgroundStyleLight; }

// NSTextFieldCell seems to align the text at the top in flipped views such as NSTableView, which is weird
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    if (NSHeight(cellFrame) > LABEL_EFFECTIVE_HEIGHT) {
        if ([controlView isFlipped])
            cellFrame.origin.y += NSHeight(cellFrame) - LABEL_EFFECTIVE_HEIGHT;
        cellFrame.size.height = LABEL_EFFECTIVE_HEIGHT;
    }
    [super drawInteriorWithFrame:cellFrame inView:controlView];
}

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    return nil;
}

- (NSColor *)textColor {
    return [NSColor blackColor];
}

@end

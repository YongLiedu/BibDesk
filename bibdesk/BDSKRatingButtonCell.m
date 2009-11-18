//
//  BDSKRatingButtonCell.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/9/05.
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

#import "BDSKRatingButtonCell.h"
#import "NSBezierPath_BDSKExtensions.h"

#define OUTER_SIZE			12
#define MARKER_SIZE			10
#define PLACEHOLDER_SIZE	2
#define BUTTON_TEXT_X_SEP	4
#define BUTTON_TEXT_Y_SEP	2
#define EXTRA_BORDER_SIZE	4
#define EXTRA_BORDER_MARGIN	3


@implementation BDSKRatingButtonCell

// designated initializer
- (id)initWithMaxRating:(NSUInteger)aRating {
	if (self = [super initTextCell:@""]) {
		rating = 0;
		maxRating = aRating;
		[self setImagePosition:NSImageOnly];
		[self setBezelStyle:NSShadowlessSquareBezelStyle]; // this is mainly to make it selectable
	}
	return self;
}

// super's designated initializer
- (id)initTextCell:(NSString *)aString {
	self = [self initWithMaxRating:5];
	[self setTitle:aString];
	return self;
}

- (id)initWithCoder:(NSCoder *)coder {
	if (self = [super initWithCoder:coder]) {
		rating = 0;
		maxRating = 5;
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone {
    id cellCopy = [super copyWithZone:zone];
    [cellCopy setMaxRating:[self maxRating]];
    [cellCopy setRating:[self rating]];
    return cellCopy;
}

- (NSUInteger)rating {
    return rating;
}

- (void)setRating:(NSUInteger)newRating {
	if (newRating > maxRating)
		newRating = maxRating;
	if (rating != newRating) {
        rating = newRating;
        [(NSControl *)[self controlView] updateCellInside:self];
    }
}

- (NSUInteger)maxRating {
    return maxRating;
}

- (void)setMaxRating:(NSUInteger)newRating {
    if (maxRating != newRating) {
        maxRating = newRating;
        [(NSControl *)[self controlView] updateCell:self];
    }
}

- (void)setObjectValue:(id)object {
	[self setRating:[object integerValue]];
}

- (id)objectValue {
	return [NSNumber numberWithUnsignedInteger:rating];
}

- (int)intValue {
	return rating;
}

- (void)setIntValue:(int)anInt {
	[self setRating:anInt];
}

- (NSInteger)integerValue {
	return rating;
}

- (void)setIntegerValue:(NSInteger)anInt {
	[self setRating:anInt];
}

- (void)setNextState {
	[self setRating:[self nextState]];
}

- (NSInteger)nextState {
	if (rating < maxRating)
		return rating + 1;
	else
		return 0;
}

- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)untilMouseUp {
    if ([self isEnabled] == NO)
        return NO;

	NSPoint mouseLoc = [controlView convertPoint:[theEvent locationInWindow] fromView:nil];

	BOOL keepOn = YES;
    BOOL mouseWentUp = NO;
    NSPoint lastLoc = mouseLoc;
	CGFloat border = ([self isBordered] ? 1 : 0);
	CGFloat margin = 0;
	CGFloat offset;
	NSUInteger newRating;

	CGFloat innerWidth = OUTER_SIZE * maxRating;
	NSSize buttonSize = NSMakeSize(innerWidth, OUTER_SIZE);
	NSRect buttonRect = cellFrame;
	
	if ([self isBordered]) {
		buttonSize.width += EXTRA_BORDER_SIZE;
		buttonSize.height += EXTRA_BORDER_SIZE;
		buttonRect = NSInsetRect(buttonRect, EXTRA_BORDER_MARGIN,  EXTRA_BORDER_MARGIN);
	}
	
	switch ([self imagePosition]) {
		case NSImageOnly:
		default:
			break;
		case NSImageRight:
			buttonRect.origin.x = NSMaxX(cellFrame) - buttonSize.width;
		case NSImageLeft:
			buttonRect.size.width = buttonSize.width;
			break;
	}
	
	margin = 0.5f * (NSWidth(buttonRect) - innerWidth);
	if (margin < border)
		margin = border;
	
	if (!NSMouseInRect(mouseLoc, buttonRect, [controlView isFlipped]))
		return NO;
	
	offset = mouseLoc.x - buttonRect.origin.x - margin;
	newRating = (offset < 2) ? 0 : BDSKCeil(offset / OUTER_SIZE);
	if (newRating > maxRating)
		newRating = maxRating;
	if (rating != newRating) {
		rating = newRating;
		[(NSControl *)controlView updateCellInside:self];
	}
	
	while (keepOn) {
		lastLoc = mouseLoc;
		theEvent = [[controlView window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
        mouseLoc = [controlView convertPoint:[theEvent locationInWindow] fromView:nil];
		offset = mouseLoc.x - buttonRect.origin.x - margin;
		if (offset < border)
			offset = border;
        switch ([theEvent type]) {
            case NSLeftMouseUp:
                keepOn = NO;
                mouseWentUp = YES;
            case NSLeftMouseDragged:
                newRating = (offset < 2) ? 0 : BDSKCeil(offset / OUTER_SIZE);
                if (newRating > maxRating)
                    newRating = maxRating;
                if (rating != newRating) {
                    rating = newRating;
                    [(NSControl *)controlView updateCellInside:self];
                }
                if (keepOn == NO)
                    [(NSControl *)controlView sendAction:[self action] to:[self target]];
                break;
            default:
                break;
        }
    }
	return YES;
}

- (NSSize)cellSize {
	NSSize titleSize = [[self attributedTitle] size];
	NSSize buttonSize = NSMakeSize(OUTER_SIZE * maxRating, OUTER_SIZE);
	NSSize size = NSZeroSize;
	
	if ([self isBordered]) {
		buttonSize.width += EXTRA_BORDER_SIZE + 2 * EXTRA_BORDER_MARGIN;
		buttonSize.height += EXTRA_BORDER_SIZE + 2 * EXTRA_BORDER_MARGIN;
	}
	
	switch ([self imagePosition]) {
		case NSImageOnly:
		default:
			size = buttonSize;
			break;
		case NSImageLeft:
		case NSImageRight:
			size.width = buttonSize.width + titleSize.width + BUTTON_TEXT_X_SEP;
			size.height = BDSKMax(buttonSize.height, titleSize.height);
			if ([self isBordered])
				size.width -= EXTRA_BORDER_MARGIN;
			break;
	}
	return size;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	
	[self drawInteriorWithFrame:cellFrame inView:controlView];
	
	if ([self showsFirstResponder]) {
		
		NSSize buttonSize = NSMakeSize(OUTER_SIZE * maxRating, OUTER_SIZE);
		NSRect buttonRect = cellFrame;
		
		if ([self isBordered]) {
			buttonSize.width += EXTRA_BORDER_SIZE;
			buttonSize.height += EXTRA_BORDER_SIZE;
			buttonRect = NSInsetRect(buttonRect, EXTRA_BORDER_MARGIN, EXTRA_BORDER_MARGIN);
		}
		
		switch ([self imagePosition]) {
			case NSImageLeft:
				buttonRect.size.width = buttonSize.width;
				break;
			case NSImageRight:
				buttonRect.origin.x = NSMaxX(cellFrame) - buttonSize.width;
				buttonRect.size.width = buttonSize.width;
				break;
            default:
                break;
		}
		
		[NSGraphicsContext saveGraphicsState];
		NSSetFocusRingStyle(NSFocusRingOnly);
		NSRectFill(buttonRect);
		[NSGraphicsContext restoreGraphicsState];
	}
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	CGFloat margin = 0;
	CGFloat border = ([self isBordered] ? 1 : 0);
	CGFloat innerWidth = OUTER_SIZE * maxRating;

	NSAttributedString *titleToDisplay = [self attributedTitle];
	NSSize titleSize = [titleToDisplay size];
	NSSize buttonSize = NSMakeSize(innerWidth, OUTER_SIZE);
	NSRect buttonRect = cellFrame;
	NSRect titleRect = cellFrame;
	
	if ([self isBordered]) {
		buttonSize.width += EXTRA_BORDER_SIZE;
		buttonSize.height += EXTRA_BORDER_SIZE;
		buttonRect = NSInsetRect(buttonRect, EXTRA_BORDER_MARGIN,  EXTRA_BORDER_MARGIN);
	}
	
	switch ([self imagePosition]) {
		case NSImageOnly:
		default:
			titleToDisplay = nil;
			break;
		case NSImageLeft:
			buttonRect.size.width = buttonSize.width;
			titleRect.origin.x = NSMaxX(buttonRect) + BUTTON_TEXT_X_SEP;
			titleRect.size.width = NSMaxX(cellFrame) - titleRect.origin.x;
			break;
		case NSImageRight:
			buttonRect.origin.x = NSMaxX(cellFrame) - buttonSize.width;
			buttonRect.size.width = buttonSize.width;
			titleRect.size.width = buttonRect.origin.x - titleRect.origin.x - BUTTON_TEXT_X_SEP;
			break;
	}
	
	margin = 0.5f * (NSWidth(buttonRect) - innerWidth);
	if (margin < border)
		margin = border;
	
	NSRect rect = NSMakeRect(NSMinX(buttonRect) + margin + 0.5f * (OUTER_SIZE - MARKER_SIZE), NSMinY(buttonRect) + 0.5f * (NSHeight(buttonRect) - MARKER_SIZE), MARKER_SIZE, MARKER_SIZE);
	NSColor *color = ([self isEnabled]) ? [NSColor grayColor] : [NSColor lightGrayColor];
	BOOL selected = NO;
	NSUInteger i = 0;
	
	if ([controlView isKindOfClass:[NSTableView class]]) {
		NSTableView *tv = (NSTableView *)controlView;
		if ([[tv window] isKeyWindow] && [[[tv window] firstResponder] isEqual:tv] && [tv isRowSelected:[tv rowAtPoint:cellFrame.origin]]) {
			color = ([self isEnabled]) ? [NSColor whiteColor] : [NSColor lightGrayColor];
			selected = YES;
		}
	}
	
	[NSGraphicsContext saveGraphicsState];
	
	if ([self isBordered]) {
		[[NSColor controlBackgroundColor] set];
		NSRectFill(buttonRect);
		[[NSColor lightGrayColor] set];
		[NSBezierPath setDefaultLineWidth:1.0];
		[NSBezierPath strokeRect:NSInsetRect(buttonRect, 0.5, 0.5)];
		NSRectClip(NSInsetRect(buttonRect, 2.0, 2.0));
	}
	
	[color set];
	
	while (i++ < rating) {
		if([controlView isFlipped])
            [NSBezierPath fillInvertedStarInRect:rect];
        else
            [NSBezierPath fillStarInRect:rect];
		rect.origin.x += OUTER_SIZE;
	}
	
	if ((selected || [self isBordered]) && [self isEnabled] && rating < maxRating) {
		rect.size = NSMakeSize(PLACEHOLDER_SIZE, PLACEHOLDER_SIZE);
		rect.origin.x += 0.5f * (MARKER_SIZE - PLACEHOLDER_SIZE);
		rect.origin.y += 0.5f * (MARKER_SIZE - PLACEHOLDER_SIZE);
		[[NSColor lightGrayColor] set];
		while (i++ <= maxRating) {
			[[NSBezierPath bezierPathWithOvalInRect:rect] fill];
			rect.origin.x += OUTER_SIZE;
		}
	}
	
	[NSGraphicsContext restoreGraphicsState];
	
	if (titleToDisplay) {
		titleRect.origin.y = NSMidY(titleRect) - 0.5f * titleSize.height; 
		titleRect.size.height = titleSize.height;
		[titleToDisplay drawInRect:titleRect];
	}
}

- (NSUInteger)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView {
    return NSCellHitContentArea | NSCellHitTrackableArea;
}

#pragma mark Accessibility

- (NSArray *)accessibilityAttributeNames {
    static NSArray *attributes = nil;
    if (attributes == nil) {
        attributes = [[NSArray alloc] initWithObjects:
            NSAccessibilityRoleAttribute,
            NSAccessibilityRoleDescriptionAttribute,
            NSAccessibilityValueAttribute,
            NSAccessibilityMinValueAttribute,
            NSAccessibilityMaxValueAttribute,
            NSAccessibilityAllowedValuesAttribute,
            NSAccessibilityParentAttribute,
            NSAccessibilityChildrenAttribute,
            NSAccessibilityWindowAttribute,
            NSAccessibilityTopLevelUIElementAttribute,
            NSAccessibilityFocusedAttribute,
            NSAccessibilityPositionAttribute,
            NSAccessibilitySizeAttribute,
            nil];
    }
    return attributes;
}

- (id)accessibilityAttributeValue:(NSString *)attribute {
    if ([attribute isEqualToString:NSAccessibilityRoleAttribute]) {
        return NSAccessibilitySliderRole;
    } else if ([attribute isEqualToString:NSAccessibilityRoleDescriptionAttribute]) {
        return NSAccessibilityRoleDescriptionForUIElement(self);
    } else if ([attribute isEqualToString:NSAccessibilityValueAttribute]) {
        return [NSNumber numberWithUnsignedInteger:rating];
    } else if ([attribute isEqualToString:NSAccessibilityMinValueAttribute]) {
        return [NSNumber numberWithUnsignedInteger:0];
    } else if ([attribute isEqualToString:NSAccessibilityMaxValueAttribute]) {
        return [NSNumber numberWithUnsignedInteger:maxRating];
    } else if ([attribute isEqualToString:NSAccessibilityAllowedValuesAttribute]) {
        NSMutableArray *values = [NSMutableArray array];
        NSUInteger i;
        for (i = 0; i <= maxRating; i++)
            [values addObject:[NSNumber numberWithUnsignedInteger:i]];
        return values;
    } else if ([attribute isEqualToString:NSAccessibilityChildrenAttribute]) {
        return [NSArray array];
    } else {
        return [super accessibilityAttributeValue:attribute];
    }
}

- (BOOL)accessibilityIsAttributeSettable:(NSString *)attribute {
    if ([attribute isEqualToString:NSAccessibilityValueAttribute])
        return YES;
    else
        return [super accessibilityIsAttributeSettable:attribute];
}

- (void)accessibilitySetValue:(id)value forAttribute:(NSString *)attribute {
    if ([attribute isEqualToString:NSAccessibilityValueAttribute]) {
        [self setRating:MIN([value unsignedIntegerValue], maxRating)];
        [(NSControl *)[self controlView] updateCellInside:self];
        [(NSControl *)[self controlView] sendAction:[self action] to:[self target]];
    } else
        [super accessibilitySetValue:value forAttribute:attribute];
}

- (NSArray *)accessibilityActionNames {
    static NSArray *actions = nil;
    if (actions == nil) {
        actions = [[NSArray alloc] initWithObjects:
            NSAccessibilityIncrementAction,
            NSAccessibilityDecrementAction,
            nil];
    }
    return actions;
}

- (void)accessibilityPerformAction:(NSString *)anAction {
    if ([anAction isEqualToString:NSAccessibilityIncrementAction] && rating < maxRating) {
        [self setRating:rating + 1];
        [(NSControl *)[self controlView] updateCellInside:self];
        [(NSControl *)[self controlView] sendAction:[self action] to:[self target]];
    } else if ([anAction isEqualToString:NSAccessibilityDecrementAction] && rating > 0) {
        [self setRating:rating - 1];
        [(NSControl *)[self controlView] updateCellInside:self];
        [(NSControl *)[self controlView] sendAction:[self action] to:[self target]];
    }
}

@end

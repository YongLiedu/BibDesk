//
//  BDSKStatusBar.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/11/05.
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

#import "BDSKStatusBar.h"
#import "NSGeometry_BDSKExtensions.h"
#import "NSViewAnimation_BDSKExtensions.h"

#define LEFT_MARGIN				5.0
#define RIGHT_MARGIN			15.0
#define MARGIN_BETWEEN_ITEMS	2.0
#define VERTICAL_OFFSET         0.0


@implementation BDSKStatusBar

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        textCell = [[NSTextFieldCell alloc] initTextCell:@""];
		[textCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
        [textCell setBackgroundStyle:NSBackgroundStyleRaised];
		
        iconCell = [[NSImageCell alloc] init];
		
		progressIndicator = nil;
		
		icons = [[NSMutableArray alloc] initWithCapacity:2];
		
		delegate = nil;
        
        leftMargin = LEFT_MARGIN;
        rightMargin = RIGHT_MARGIN;
        
        animating = NO;
    }
    return self;
}

- (void)dealloc {
	BDSKDESTROY(textCell);
	BDSKDESTROY(iconCell);
	BDSKDESTROY(icons);
	[super dealloc];
}

- (NSSize)cellSizeForIcon:(NSImage *)icon {
    NSSize iconSize = [icon size];
    CGFloat cellHeight = NSHeight([self bounds]) - 2.0;
    CGFloat cellWidth = iconSize.width * cellHeight / iconSize.height;
	return NSMakeSize(cellWidth, cellHeight);
}

- (void)drawRect:(NSRect)rect {
	NSRect textRect, ignored;
    CGFloat fullRightMargin = rightMargin;
	
    if (progressIndicator)
        fullRightMargin += NSWidth([progressIndicator frame]) + MARGIN_BETWEEN_ITEMS;
    NSDivideRect([self bounds], &ignored, &textRect, leftMargin, NSMinXEdge);
    NSDivideRect(textRect, &ignored, &textRect, fullRightMargin, NSMaxXEdge);
	
	NSImage *icon;
	NSRect iconRect;    
	NSSize size;
	
	for (NSDictionary *dict in icons) {
		icon = [dict objectForKey:@"icon"];
        size = [self cellSizeForIcon:icon];
        NSDivideRect(textRect, &iconRect, &textRect, size.width, NSMaxXEdge);
        NSDivideRect(textRect, &ignored, &textRect, MARGIN_BETWEEN_ITEMS, NSMaxXEdge);
        iconRect = BDSKCenterRectVertically(iconRect, size.height, NO);
        iconRect.origin.y += VERTICAL_OFFSET;
		[iconCell setImage:icon];
		[iconCell drawWithFrame:iconRect inView:self];
	}
	
	if (textRect.size.width < 0.0)
		textRect.size.width = 0.0;
	size = [textCell cellSize];
    textRect = BDSKCenterRectVertically(textRect, size.height, NO);
    textRect.origin.y += VERTICAL_OFFSET;
	[textCell drawWithFrame:textRect inView:self];
}

- (BOOL)isVisible {
	return [self superview]  && [self isHidden] == NO;
}

- (void)endAnimation:(NSNumber *)visible {
    if ([visible boolValue] == NO) {
        [[self window] setContentBorderThickness:0.0 forEdge:NSMinYEdge];
        [self removeFromSuperview];
    } else {
        // this fixes an AppKit bug, the window does not update its draggable areas
        [[self window] setMovableByWindowBackground:YES];
        [[self window] setMovableByWindowBackground:NO];
    }
    animating = NO;
}

- (void)toggleBelowView:(NSView *)view animate:(BOOL)animate {
    if (animating)
        return;
    
	NSRect viewFrame = [view frame];
	NSView *contentView = [view superview];
	NSRect statusRect = [contentView bounds];
	CGFloat statusHeight = NSHeight([self frame]);
    BOOL visible = (nil == [self superview]);
    NSTimeInterval duration = [NSViewAnimation defaultAnimationTimeInterval];
	
    statusRect.size.height = statusHeight;
	
	if (visible) {
        [[view window] setContentBorderThickness:statusHeight forEdge:NSMinYEdge];
		if ([contentView isFlipped])
			statusRect.origin.y = NSMaxY([contentView bounds]);
		else
            statusRect.origin.y -= statusHeight;
        [self setFrame:statusRect];
		[contentView addSubview:self positioned:NSWindowBelow relativeTo:nil];
        statusHeight = -statusHeight;
	}
    viewFrame.size.height += statusHeight;
    if ([contentView isFlipped]) {
        statusRect.origin.y += statusHeight;
    } else {
        viewFrame.origin.y -= statusHeight;
        statusRect.origin.y -= statusHeight;
    }
    if (animate && duration > 0.0) {
        animating = YES;
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:duration];
        [[view animator] setFrame:viewFrame];
        [[self animator] setFrame:statusRect];
        [NSAnimationContext endGrouping];
        [self performSelector:@selector(endAnimation:) withObject:[NSNumber numberWithBool:visible] afterDelay:duration];
    } else {
        [view setFrame:viewFrame];
        if (visible) {
            [self setFrame:statusRect];
        } else {
            [[self window] setContentBorderThickness:0.0 forEdge:NSMinYEdge];
            [self removeFromSuperview];
        }
    }
}

#pragma mark Text cell accessors

- (NSString *)stringValue {
	return [textCell stringValue];
}

- (void)setStringValue:(NSString *)aString {
	[textCell setStringValue:aString];
	[self setNeedsDisplay:YES];
}

- (NSAttributedString *)attributedStringValue {
	return [textCell attributedStringValue];
}

- (void)setAttributedStringValue:(NSAttributedString *)object {
	[textCell setAttributedStringValue:object];
	[self setNeedsDisplay:YES];
}

- (NSFont *)font {
	return [textCell font];
}

- (void)setFont:(NSFont *)fontObject {
	[textCell setFont:fontObject];
	[self setNeedsDisplay:YES];
}

- (id)textCell {
	return textCell;
}

- (void)setTextCell:(NSCell *)aCell {
	if (aCell != textCell) {
		[textCell release];
		textCell = [aCell retain];
	}
}

- (CGFloat)leftMargin {
    return leftMargin;
}

- (void)setLeftMargin:(CGFloat)margin {
    leftMargin = margin;
    [self setNeedsDisplay:YES];
}

- (CGFloat)rightMargin {
    return rightMargin;
}

- (void)setRightMargin:(CGFloat)margin {
    rightMargin = margin;
    [self setNeedsDisplay:YES];
}

#pragma mark Icons

- (NSArray *)iconIdentifiers {
	NSMutableArray *IDs = [NSMutableArray arrayWithCapacity:[icons count]];
	for (NSDictionary *dict in icons) {
		[IDs addObject:[dict objectForKey:@"identifier"]];
	}
	return IDs;
}

- (void)addIcon:(NSImage *)icon withIdentifier:(NSString *)identifier{
	[self addIcon:icon withIdentifier:identifier toolTip:nil];
}

- (void)addIcon:(NSImage *)icon withIdentifier:(NSString *)identifier toolTip:(NSString *)toolTip {
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:icon, @"icon", identifier, @"identifier", nil];
	if (toolTip != nil)
		[dict setObject:toolTip forKey:@"toolTip"];
	[icons addObject:dict];
	[self rebuildToolTips];
	[self setNeedsDisplay:YES];
}

- (void)removeIconWithIdentifier:(NSString *)identifier {
	NSUInteger i = [icons count];
	while (i--) {
		if ([[[icons objectAtIndex:i] objectForKey:@"identifier"] isEqualToString:identifier]) {
			[icons removeObjectAtIndex:i];
			[self rebuildToolTips];
			[self setNeedsDisplay:YES];
			break;
		}
	}
}

- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)userData {
	if ([delegate respondsToSelector:@selector(statusBar:toolTipForIdentifier:)])
		return [delegate statusBar:self toolTipForIdentifier:(NSString *)userData];
	
	for (NSDictionary *dict in icons) {
		if ([[dict objectForKey:@"identifier"] isEqualToString:(NSString *)userData]) {
			return [dict objectForKey:@"toolTip"];
		}
	}
	return nil;
}

- (void)rebuildToolTips {
	NSRect ignored, rect;
    CGFloat fullRightMargin = rightMargin;
	
	if (progressIndicator != nil) 
		fullRightMargin += NSMinX([progressIndicator frame]) + MARGIN_BETWEEN_ITEMS;
	
    NSDivideRect([self bounds], &ignored, &rect, fullRightMargin, NSMaxXEdge);
    
	NSRect iconRect;
    NSSize size;
	
	[self removeAllToolTips];
	
	for (NSDictionary *dict in icons) {
        size = [self cellSizeForIcon:[dict objectForKey:@"icon"]];
        NSDivideRect(rect, &iconRect, &rect, size.width, NSMaxXEdge);
        NSDivideRect(rect, &ignored, &rect, MARGIN_BETWEEN_ITEMS, NSMaxXEdge);
        iconRect = BDSKCenterRectVertically(iconRect, size.height, NO);
        iconRect.origin.y += VERTICAL_OFFSET;
		[self addToolTipRect:iconRect owner:self userData:[dict objectForKey:@"identifier"]];
	}
}

- (void)resetCursorRects {
	// CMH: I am not sure if this is the right place, but toolTip rects need to be reset when the view resizes
	[self rebuildToolTips];
}

- (id<BDSKStatusBarDelegate>)delegate {
	return delegate;
}

- (void)setDelegate:(id<BDSKStatusBarDelegate>)newDelegate {
	delegate = newDelegate;
}

#pragma mark Progress indicator

- (NSProgressIndicator *)progressIndicator {
	return progressIndicator;
}

- (BDSKProgressIndicatorStyle)progressIndicatorStyle {
	if (progressIndicator == nil)
		return BDSKProgressIndicatorNone;
	else
		return [progressIndicator style];
}

- (void)setProgressIndicatorStyle:(BDSKProgressIndicatorStyle)style {
	if (style == BDSKProgressIndicatorNone) {
		if (progressIndicator == nil)
			return;
		[progressIndicator removeFromSuperview];
		progressIndicator = nil;
	} else {
		if ((NSInteger)[progressIndicator style] == style)
			return;
		if(progressIndicator == nil) {
            progressIndicator = [[NSProgressIndicator alloc] init];
        } else {
            [progressIndicator retain];
            [progressIndicator removeFromSuperview];
		}
        [progressIndicator setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin | NSViewMaxYMargin];
		[progressIndicator setStyle:style];
		[progressIndicator setControlSize:NSSmallControlSize];
		[progressIndicator setIndeterminate:YES];
		[progressIndicator setDisplayedWhenStopped:NO];
		[progressIndicator sizeToFit];
		
		NSRect rect, ignored;
		NSSize size = [progressIndicator frame].size;
        NSDivideRect([self bounds], &ignored, &rect, rightMargin, NSMaxXEdge);
        NSDivideRect(rect, &rect, &ignored, size.width, NSMaxXEdge);
        rect = BDSKCenterRect(rect, size, [self isFlipped]);
        rect.origin.y += VERTICAL_OFFSET;
		[progressIndicator setFrame:rect];
		
        [self addSubview:progressIndicator];
		[progressIndicator release];
	}
	[self rebuildToolTips];
	[[self superview] setNeedsDisplayInRect:[self frame]];
}

- (void)startAnimation:(id)sender {
	[progressIndicator startAnimation:sender];
}

- (void)stopAnimation:(id)sender {
	[progressIndicator stopAnimation:sender];
}

#pragma mark Accessibility

- (NSArray *)accessibilityAttributeNames {
    return [[super accessibilityAttributeNames] arrayByAddingObject:NSAccessibilityChildrenAttribute];
}

- (id)accessibilityAttributeValue:(NSString *)attribute {
    if ([attribute isEqualToString:NSAccessibilityRoleAttribute])
        return NSAccessibilityGroupRole;
    else if ([attribute isEqualToString:NSAccessibilityRoleDescriptionAttribute])
        return NSAccessibilityRoleDescription(NSAccessibilityGroupRole, nil);
    else if ([attribute isEqualToString:NSAccessibilityChildrenAttribute])
        return NSAccessibilityUnignoredChildren([NSArray arrayWithObjects:textCell, progressIndicator, nil]);
    return [super accessibilityAttributeValue:attribute];
}

- (id)accessibilityHitTest:(NSPoint)point {
    NSPoint localPoint = [self convertPoint:[[self window] convertScreenToBase:point] fromView:nil];
    NSRect rect, childRect, ignored;
    
    NSDivideRect([self bounds], &ignored, &rect, leftMargin, NSMinXEdge);
    NSDivideRect(rect, &ignored, &rect, rightMargin, NSMaxXEdge);
    if (progressIndicator) {
        NSDivideRect(rect, &childRect, &rect, NSWidth([progressIndicator frame]), NSMaxXEdge);
        if (NSMouseInRect(localPoint, childRect, [self isFlipped]))
            return NSAccessibilityUnignoredAncestor(progressIndicator);
        NSDivideRect(rect, &ignored, &rect, MARGIN_BETWEEN_ITEMS, NSMaxXEdge);
	}
    return NSAccessibilityUnignoredAncestor(textCell);
}

- (id)accessibilityFocusedUIElement {
    if (progressIndicator && [NSApp accessibilityFocusedUIElement] == progressIndicator)
        return NSAccessibilityUnignoredAncestor(progressIndicator);
    else
        return NSAccessibilityUnignoredAncestor(textCell);
}

- (BOOL)accessibilityIsIgnored {
    return NO;
}

@end

//
//  BDSKPreferenceIconView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/17/09.
/*
 This software is Copyright (c) 2009
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

#import "BDSKPreferenceIconView.h"
#import "BDSKPreferenceController.h"
#import "BDSKPreferenceIconCell.h"

#define MINIMUM_ICON_WIDTH 0.0
#define MINIMUM_ICON_HEIGHT 0.0
#define MAXIMUM_ICON_WIDTH 100.0
#define MAXIMUM_ICON_HEIGHT 200.0
#define TOP_MARGIN 1.0
#define BOTTOM_MARGIN 0.0
#define TOP_CAPTION_MARGIN 4.0
#define SIDE_CAPTION_MARGIN 12.0
#define SIDE_ICON_MARGIN 16.0
#define COLLAPSE_SIDE_ICON_MARGIN YES
#define ICON_SPACING 2.0
#define COLLAPSE_ICON_SPACING YES
#define TOP_ICON_MARGIN 8.0
#define BOTTOM_ICON_MARGIN 12.0


@interface BDSKPreferenceIconView (Private)
- (void)setupViewWithPreferenceController:(BDSKPreferenceController *)aController;
@end


@implementation BDSKPreferenceIconView

- (id)initWithPreferenceController:(BDSKPreferenceController *)aController {
    if (self = [super initWithFrame:NSZeroRect]) {
        NSCell *prototype = [[NSCell alloc] init];
        [prototype setEnabled:NO];
        matrix = [[NSMatrix alloc] initWithFrame:NSZeroRect mode:NSHighlightModeMatrix prototype:prototype numberOfRows:0 numberOfColumns:0];
        [prototype release];
        [matrix setSelectionByRect:NO];
        [self addSubview:matrix];
        [matrix release];
        
        captionCell = [[NSTextFieldCell alloc] init];
        [captionCell setFont:[NSFont boldSystemFontOfSize:0.0]];
        
        captionTitles = [[NSMutableArray alloc] init];
        
        [self setupViewWithPreferenceController:aController];
    }
    return self;
}

- (void)dealloc {
    [captionCell release];
    [captionTitles release];
    [super dealloc];
}

- (BOOL)isFlipped { return YES; }

- (NSString *)clickedIdentifier {
    return [[matrix selectedCell] representedObject];
}

- (id)target {
    return target;
}

- (void)setTarget:(id)newTarget {
    target = newTarget;
}

- (SEL)action {
    return action;
}

- (void)setAction:(SEL)newAction {
    action = newAction;
}

- (NSRect)iconFrameAtRow:(NSUInteger)row column:(NSUInteger)column {
    return [self convertRect:[matrix cellFrameAtRow:row column:column] fromView:matrix];
}

// flag changes during a drag are not forwarded to the application, so we fix that at the end of the drag
- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation{
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKFlagsChangedNotification object:NSApp];
}

#pragma mark Private

- (void)selectIcon:(id)sender {
    [self sendAction:[self action] to:[self target]];
}

- (void)setupViewWithPreferenceController:(BDSKPreferenceController *)preferenceController {
    NSArray *categories = [preferenceController categories];
    NSUInteger numRows = [categories count];
    NSUInteger numColumns = 0;
    NSUInteger i, iMax = numRows;
    for (i = 0; i < iMax; i++)
        numColumns = MAX(numColumns, [[preferenceController panesForCategory:[categories objectAtIndex:i]] count]);
    
    NSSize iconSize = NSZeroSize;
    [matrix renewRows:numRows columns:numColumns];
    for (i = 0; i < iMax; i++) {
        NSString *category = [categories objectAtIndex:i];
        NSArray *panes = [preferenceController panesForCategory:category];
        NSUInteger j, jMax = [panes count];
        for (j = 0; j < jMax; j++) {
            NSString *identifier = [panes objectAtIndex:j];
            BDSKPreferenceIconCell *cell = [[BDSKPreferenceIconCell alloc] initImageCell:[preferenceController iconForIdentifier:identifier]];
            [cell setTitle:[preferenceController localizedLabelForIdentifier:identifier]];
            [cell setFont:[NSFont labelFontOfSize:0.0]];
            [cell setRepresentedObject:identifier];
            [cell setImagePosition:NSImageAbove];
            [cell setBordered:NO];
            [cell setButtonType:NSMomentaryChangeButton];
            [matrix putCell:cell atRow:i column:j];
            [matrix setToolTip:[preferenceController localizedToolTipForIdentifier:identifier] forCell:cell];
			NSSize cellSize = [cell cellSize];
			iconSize.width = BDSKMax(iconSize.width, cellSize.width);
			iconSize.height = BDSKMax(iconSize.height, cellSize.height);
            [cell release];
        }
        [captionTitles addObject:[preferenceController localizedTitleForCategory:category] ?: @""];
    }
	
    CGFloat iconWidth = iconSize.width;
    CGFloat iconHeight = iconSize.height;
    CGFloat iconMargin = SIDE_ICON_MARGIN;
    CGFloat iconSpacing = ICON_SPACING;
    if (iconWidth < MINIMUM_ICON_WIDTH) {
        if (COLLAPSE_SIDE_ICON_MARGIN)
            iconMargin = BDSKMax(0.0, iconMargin - BDSKFloor((MINIMUM_ICON_WIDTH - iconWidth) / 2.0));
        if (COLLAPSE_ICON_SPACING)
            iconSpacing = BDSKMax(0.0, iconSpacing - MINIMUM_ICON_WIDTH + iconWidth);
        iconWidth = MINIMUM_ICON_WIDTH;
    } else if (iconWidth > MAXIMUM_ICON_WIDTH) {
        iconWidth = MAXIMUM_ICON_WIDTH;
    }
    if (iconHeight < MINIMUM_ICON_HEIGHT)
        iconHeight = MINIMUM_ICON_HEIGHT;
    else if (iconHeight > MAXIMUM_ICON_HEIGHT)
        iconHeight = MAXIMUM_ICON_HEIGHT;
    
	NSRect frame = NSZeroRect;
    CGFloat categoryHeight = TOP_CAPTION_MARGIN + [captionCell cellSize].height + TOP_ICON_MARGIN + iconHeight + BOTTOM_ICON_MARGIN;
	frame.size.width = 2.0 * iconMargin + numColumns * (iconWidth + iconSpacing) - iconSpacing;
	frame.size.height = TOP_MARGIN + numRows * categoryHeight;
	[self setFrame:frame];
    
    [matrix setCellSize:iconSize];
    [matrix setIntercellSpacing:NSMakeSize(iconSpacing + iconWidth - iconSize.width, categoryHeight - iconSize.height)];
    [matrix setFrameOrigin:NSMakePoint(iconMargin + BDSKFloor((iconWidth - iconSize.width) / 2.0), TOP_MARGIN + TOP_CAPTION_MARGIN + [captionCell cellSize].height + TOP_ICON_MARGIN)];
    [matrix sizeToCells];
    [matrix setTarget:self];
    [matrix setAction:@selector(selectIcon:)];
}

#pragma mark Drawing

- (void)drawRect:(NSRect)aRect {
    NSInteger i, iMax = [matrix numberOfRows];
    NSColor *backgroundColor = [NSColor colorWithCalibratedWhite:0.97 alpha:0.99];
    NSColor *dividerColor = [NSColor colorWithCalibratedWhite:0.84 alpha:1.0];
    NSRect rect = NSMakeRect(0.0, TOP_MARGIN, NSWidth([self bounds]), [matrix cellSize].height + [matrix intercellSpacing].height);
    NSRect captionRect = NSMakeRect(SIDE_CAPTION_MARGIN, NSMinY(rect) + TOP_CAPTION_MARGIN, NSWidth(rect) - SIDE_CAPTION_MARGIN, [captionCell cellSize].height);
    NSRect dividerRect = rect;
    dividerRect.size.height = 1.0;
    
    for (i = 0; i < iMax; i++, rect.origin.y += NSHeight(rect), captionRect.origin.y += NSHeight(rect), dividerRect.origin.y += NSHeight(rect)) {
        if (i == iMax - 1)
            rect.size.height += BOTTOM_MARGIN;
        if (i % 2) {
            [backgroundColor setFill];
            NSRectFillUsingOperation(rect, NSCompositePlusDarker);
        }
        if (i > 0) {
            [dividerColor setFill];
            NSRectFill(dividerRect);
        }
        [captionCell setStringValue:[captionTitles objectAtIndex:i]];
        [captionCell drawWithFrame:captionRect inView:self];
    }
}

@end

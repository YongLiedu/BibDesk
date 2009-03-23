//
//  FVColorMenuView.m
//  colormenu
//
//  Created by Adam Maxwell on 02/20/08.
/*
 This software is Copyright (c) 2008-2009
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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

#import "FVColorMenuView.h"
#import "FVUtilities.h"
#import "FVFinderLabel.h"

static NSString * const FVColorNameUpdateNotification = @"FVColorNameUpdateNotification";

@interface FVColorMenuCell : NSButtonCell
@end

@interface FVColorMenuMatrix : NSMatrix
{
    NSInteger _boxedRow;
    NSInteger _boxedColumn;
}
- (NSString *)boxedLabelName;
@end

@interface FVColorMenuView (FVPrivate)
- (void)_handleColorNameUpdate:(NSNotification *)note;
- (void)fvLabelColorAction:(id)sender;
@end

@implementation FVColorMenuView

+ (FVColorMenuView *)menuView;
{
    return [[[self alloc] initWithFrame:NSMakeRect(0.0, 0.0, 188.0, 68.0)] autorelease];
}

- (id)initWithFrame:(NSRect)aRect
{
    self = [super initWithFrame:NSMakeRect(0.0, 0.0, 188.0, 68.0)];
    if (self) {
        NSBundle *bundle = [NSBundle bundleForClass:[FVColorMenuView self]];
        _labelCell = [[NSCell alloc] initTextCell:NSLocalizedStringFromTableInBundle(@"Label:", @"FileView", bundle, @"Finder label menu item title")];
        [_labelCell setFont:[NSFont menuBarFontOfSize:0.0]];
        
        _labelNameCell = [[NSCell alloc] initTextCell:@""];
        [_labelNameCell setAlignment:NSCenterTextAlignment];
        [_labelNameCell setFont:[NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]]];
        
        _matrix = [[FVColorMenuMatrix alloc] initWithFrame:NSMakeRect(20.0, 22.0, 158.0, 18.0)];
        [_matrix setAutoresizingMask:NSViewMaxXMargin|NSViewMinYMargin];
        [_matrix setTarget:self];
        [_matrix setAction:@selector(fvLabelColorAction:)];
        [self addSubview:_matrix];
        [_matrix release];
        
        _target = nil;
        _action = nil;
        
        [self setAutoresizingMask:NSViewMaxXMargin|NSViewMinYMargin];
        if (_matrix)
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleColorNameUpdate:) name:FVColorNameUpdateNotification object:_matrix];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeConditionalObject:_matrix forKey:@"_matrix"];
    [coder encodeObject:_labelCell forKey:@"_labelCell"];
    [coder encodeObject:_labelNameCell forKey:@"_labelNameCell"];
    [coder encodeConditionalObject:_target forKey:@"_target"];
    [coder encodeObject:NSStringFromSelector(_action) forKey:@"_action"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder]) {
        // the following should be unarchived as subviews, so no need to retain them
        _matrix = [coder decodeObjectForKey:@"_matrix"];
        _labelCell = [[coder decodeObjectForKey:@"_labelCell"] retain];
        _labelNameCell = [[coder decodeObjectForKey:@"_labelNameCell"] retain];
        _target = [coder decodeObjectForKey:@"_target"];
        _action = NSSelectorFromString([coder decodeObjectForKey:@"_action"]);
        [_labelNameCell setStringValue:@""];
        if (_matrix)
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleColorNameUpdate:) name:FVColorNameUpdateNotification object:_matrix];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_labelCell release];
    [_labelNameCell release];
    [super dealloc];
}

- (void)setTarget:(id)target { _target = target; }

- (id)target { return _target; }

- (SEL)action { return _action; }

- (void)setAction:(SEL)action { _action = action; }

- (void)selectLabel:(NSUInteger)label;
{
    NSParameterAssert(nil != _matrix);
    [_matrix selectCellWithTag:label];
}

- (NSInteger)selectedTag;
{
    NSParameterAssert(nil != [_matrix selectedCell]); 
    return [[_matrix selectedCell] tag];
}

// called by the action receiver
- (NSInteger)tag
{
    return [self selectedTag];
}

- (void)drawRect:(NSRect)aRect {
    NSRect bounds = [self bounds];
    NSRect labelRect;
    
    // draw the label
    labelRect.origin.x = 20.0;
    labelRect.origin.y = NSMaxY(bounds) - 20.0;
    labelRect.size = [_labelCell cellSize];
    [_labelCell drawWithFrame:labelRect inView:self];
    
    // draw the label name
    labelRect.origin.y -= 48.0;
    labelRect.size.width = NSWidth(bounds) - 40.0;
    labelRect.size.height = [_labelNameCell cellSize].height;
    [_labelNameCell drawWithFrame:labelRect inView:self];
}


// notification posted in response to a mouseover so we can update the label name
- (void)_handleColorNameUpdate:(NSNotification *)note
{
    [_labelNameCell setStringValue:[_matrix boxedLabelName]];
    [self setNeedsDisplay:YES];
}

- (void)fvLabelColorAction:(id)sender
{
    [NSApp sendAction:[self action] to:[self target] from:self];
    
    // we have to close the menu manually
    if ([self respondsToSelector:@selector(enclosingMenuItem)] && [[[self enclosingMenuItem] menu] respondsToSelector:@selector(cancelTracking)])
        [[[self enclosingMenuItem] menu] cancelTracking];
}

@end

@implementation FVColorMenuCell

- (id)initTextCell:(NSString *)aString
{
    if (self = [super initTextCell:aString]) {
        [self setButtonType:NSRadioButton];
        [self setBordered:NO];
    }
    return self;
}

- (NSSize)cellSize
{
    return NSMakeSize(18.0, 18.0);
}

static NSRect __FVSquareRectCenteredInRect(const NSRect iconRect)
{
    // determine aspect ratio (copy paste from FVIcon)
    const NSSize s = (NSSize){ 128, 128 };
    
    CGFloat ratio = MIN(NSWidth(iconRect) / s.width, NSHeight(iconRect) / s.height);
    NSRect dstRect = iconRect;
    dstRect.size.width = ratio * s.width;
    dstRect.size.height = ratio * s.height;
    
    CGFloat dx = (iconRect.size.width - dstRect.size.width) / 2;
    CGFloat dy = (iconRect.size.height - dstRect.size.height) / 2;
    dstRect.origin.x += dx;
    dstRect.origin.y += dy;
    
    return dstRect;
}

- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)controlView
{
    frame = __FVSquareRectCenteredInRect(frame);
    CGFloat inset = NSWidth(frame) / 5;
    NSRect interiorFrame = NSInsetRect(frame, inset, inset);
    NSInteger tag = [self tag];
    
    [NSGraphicsContext saveGraphicsState];

    if (0 == tag) {
        interiorFrame = NSInsetRect(interiorFrame, 2, 2);
        NSBezierPath *p = [NSBezierPath bezierPath];
        [p moveToPoint:interiorFrame.origin];
        [p lineToPoint:NSMakePoint(NSMaxX(interiorFrame), NSMaxY(interiorFrame))];
        [p moveToPoint:NSMakePoint(NSMinX(interiorFrame), NSMaxY(interiorFrame))];
        [p lineToPoint:NSMakePoint(NSMaxX(interiorFrame), NSMinY(interiorFrame))];
        [p setLineWidth:2.0];
        [p setLineCapStyle:NSRoundLineCapStyle];
        [[NSColor darkGrayColor] setStroke];
        [p stroke];
    }
    else {
        NSShadow *labelShadow = [NSShadow new];
        [labelShadow setShadowOffset:NSMakeSize(0, -1)];
        [labelShadow setShadowBlurRadius:2.0];
        [labelShadow set];
        [FVFinderLabel drawFinderLabel:tag inRect:interiorFrame roundEnds:NO];
        [labelShadow release];
    }
    
    [NSGraphicsContext restoreGraphicsState];
}

@end

@implementation FVColorMenuMatrix

#define NO_BOX -1

- (id)initWithFrame:(NSRect)frameRect
{
    if (self = [super initWithFrame:frameRect]) {
        [self setPrototype:[[[FVColorMenuCell alloc] initTextCell:@""] autorelease]];
        [self setCellSize:NSMakeSize(18.0, 18.0)];
        [self setIntercellSpacing:NSMakeSize(2.0, 4.0)];
        [self setMode:NSRadioModeMatrix];
        [self renewRows:1 columns:8];
        [self sizeToCells];
        int column, tags[8] = {0, 6, 7, 5, 2, 4, 3, 1};
        for (column = 0; column < 8; column++)
            [[self cellAtRow:0 column:column] setTag:tags[column]];
        _boxedRow = NO_BOX;
        _boxedColumn = NO_BOX;
    }
    return self;
}

- (void)removeTrackingAreas
{
    NSEnumerator *trackEnum = [[NSArray arrayWithArray:[self trackingAreas]] objectEnumerator];
    NSTrackingArea *area;
    while ((area = [trackEnum nextObject]))
        [self removeTrackingArea:area];
}

- (void)rebuildTrackingAreas
{
    [self removeTrackingAreas];
    NSUInteger r, nr = [self numberOfRows];
    NSUInteger c, nc = [self numberOfColumns];
    
    for (r = 0; r < nr; r++) {
        
        for (c = 0; c < nc; c++) {
            
            NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingAssumeInside;
            NSRect cellFrame = [self cellFrameAtRow:r column:c];
            NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:cellFrame options:options owner:self userInfo:nil];
            [self addTrackingArea:area];
            [area release];
        }
    }
}

- (void)viewWillMoveToWindow:(NSWindow *)window
{
    _boxedRow = NO_BOX;
    _boxedColumn = NO_BOX;
    
    if (window)
        [self rebuildTrackingAreas];
    else
        [self removeTrackingAreas];
}

- (NSRect)boxRectForCellAtRow:(NSUInteger)r column:(NSUInteger)c
{
    NSRect boxRect = [self cellFrameAtRow:r column:c];
    boxRect = __FVSquareRectCenteredInRect(boxRect);
    return [self centerScanRect:NSInsetRect(boxRect, 1.0, 1.0)];
}

#define BOX_WIDTH 1.5
#define BOX_RADIUS 2

- (BOOL)_isBoxedCellSelected { return ([self selectedRow] == _boxedRow && [self selectedColumn] == _boxedColumn); }

- (BOOL)_isFirstCellSelected { return ([self selectedRow] == 0 && [self selectedColumn] == 0); }

- (void)drawRect:(NSRect)aRect
{
    [super drawRect:aRect];
        
    // draw a box around the moused-over cell (unless it's selected); the X cell always gets highlighted, since it's never drawn as selected
    if (NO_BOX != _boxedRow && NO_BOX != _boxedColumn && (NO == [self _isBoxedCellSelected] || [self _isFirstCellSelected])) {
        [[NSColor lightGrayColor] setStroke];
        NSRect boxRect = [self boxRectForCellAtRow:_boxedRow column:_boxedColumn];
        NSBezierPath *boxPath = [NSBezierPath fv_bezierPathWithRoundRect:boxRect xRadius:BOX_RADIUS yRadius:BOX_RADIUS];
        [[NSColor colorWithCalibratedWhite:0.5 alpha:0.3] setFill];
        [boxPath fill];
        [boxPath setLineWidth:BOX_WIDTH];
        [boxPath stroke];
    }
    
    // the X doesn't show as selected
    if ([self selectedRow] != 0 || [self selectedColumn] != 0) {
        [[NSColor lightGrayColor] setStroke];
        NSRect boxRect = [self boxRectForCellAtRow:[self selectedRow] column:[self selectedColumn]];
        NSBezierPath *boxPath = [NSBezierPath fv_bezierPathWithRoundRect:boxRect xRadius:BOX_RADIUS yRadius:BOX_RADIUS];
        [boxPath setLineWidth:BOX_WIDTH];
        [boxPath stroke];
    }
}

- (void)mouseEntered:(NSEvent *)event
{
    NSInteger r, c;
    if ([self getRow:&r column:&c forPoint:[self convertPoint:[event locationInWindow] fromView:nil]]) {
        _boxedRow = r;
        _boxedColumn = c;
    }
    else {
        _boxedRow = NO_BOX;
        _boxedColumn = NO_BOX;
    }       
    [self setNeedsDisplay:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:FVColorNameUpdateNotification object:self];
    [super mouseEntered:event];
}

- (void)mouseExited:(NSEvent *)event
{
    _boxedRow = NO_BOX;
    _boxedColumn = NO_BOX;
    [self setNeedsDisplay:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:FVColorNameUpdateNotification object:self];
    [super mouseExited:event];
}

- (NSString *)boxedLabelName;
{
    NSCell *cell = nil;
    
    // return @"" if a cell isn't hovered over
    if (NO_BOX != _boxedRow && NO_BOX != _boxedColumn)
        cell = [self cellAtRow:_boxedRow column:_boxedColumn];
    
    // Finder uses curly quotes around the name, and displays nothing for the X item
    return 0 == [cell tag] ? @"" : [NSString stringWithFormat:@"%C%@%C", 0x201C, [FVFinderLabel localizedNameForLabel:[cell tag]], 0x201D];
}

- (NSString *)accessibilityAttributeValue:(NSString *)attribute {
    if ([attribute isEqualToString:NSAccessibilityTitleAttribute])
        return [self boxedLabelName];
    else
        return [super accessibilityAttributeValue:attribute];
}

@end

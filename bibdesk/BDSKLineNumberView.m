//
//  BDSKLineNumberView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/5/12.
/*
 This software is Copyright (c) 2012
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

#import "BDSKLineNumberView.h"
#import "NSInvocation_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKErrorObject.h"

#define DEFAULT_THICKNESS   22.0
#define MARKER_THICKNESS    12.0
#define RULER_MARGIN        4.0

@implementation BDSKLineNumberView

static NSDictionary *lineNumberAttributes = nil;

+ (void)initialize {
    BDSKINITIALIZE;
    lineNumberAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
        [NSFont labelFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]], NSFontAttributeName, 
        [NSColor colorWithCalibratedWhite:0.33 alpha:1.0], NSForegroundColorAttributeName,
        nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    BDSKDESTROY(lineCharacterIndexes);
    if (errorMarkers) NSFreeMapTable(errorMarkers);
    errorMarkers = nil;
    [super dealloc];
}

- (void)textDidChange:(NSNotification *)notification {
	BDSKDESTROY(lineCharacterIndexes);
    [self setNeedsDisplay:YES];
}

- (void)viewFrameDidChange:(NSNotification *)notification {
    [self setNeedsDisplay:YES];
}

- (void)setClientView:(NSView *)aView {
	id oldClientView = [self clientView];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
    if ([oldClientView isKindOfClass:[NSTextView class]]) {
		[nc removeObserver:self name:NSTextStorageDidProcessEditingNotification object:[(NSTextView *)oldClientView textStorage]];
		[nc removeObserver:self name:NSViewFrameDidChangeNotification object:oldClientView ];
    }
    
    [super setClientView:aView];
    
    if ([aView isKindOfClass:[NSTextView class]]) {
		[nc addObserver:self selector:@selector(textDidChange:) name:NSTextStorageDidProcessEditingNotification object:[(NSTextView *)aView textStorage]];
		[nc addObserver:self selector:@selector(viewFrameDidChange:) name:NSViewFrameDidChangeNotification object:aView];
    }
    BDSKDESTROY(lineCharacterIndexes);
}

- (void)setMarkers:(NSArray *)markers {
    [super setMarkers:markers];
    if (errorMarkers)
        NSResetMapTable(errorMarkers);
    else
        errorMarkers = NSCreateMapTable(NSIntegerMapKeyCallBacks, NSObjectMapValueCallBacks, 0);
    for (NSRulerMarker *marker in markers) {
        id object = [marker representedObject];
        if ([object isKindOfClass:[BDSKErrorObject class]]) {
            NSInteger line = [object lineNumber];
            if (line > 0)
                NSMapInsert(errorMarkers, (const void *)(line - 1), marker);
        }
    }
}

- (void)addMarker:(NSRulerMarker *)marker {
    [super addMarker:marker];
    id object = [marker representedObject];
    if ([object isKindOfClass:[BDSKErrorObject class]]) {
        NSInteger line = [object lineNumber];
        if (line > 0) {
            if (errorMarkers == nil)
                errorMarkers = NSCreateMapTable(NSIntegerMapKeyCallBacks, NSObjectMapValueCallBacks, 0);
            NSMapInsert(errorMarkers, (const void *)(line - 1), marker);
        }
    }
}

- (void)removeMarker:(NSRulerMarker *)marker {
    [super removeMarker:marker];
    id object = [marker representedObject];
    if (errorMarkers && [object isKindOfClass:[BDSKErrorObject class]]) {
        NSInteger line = [object lineNumber];
        if (line > 0)
            NSMapRemove(errorMarkers, (const void *)(line - 1));
    }
}

static inline CGFloat ruleThicknessForLineCount(NSUInteger count) {
    NSUInteger i = (NSUInteger)log10(count) + 1;
    NSMutableString *string = [NSMutableString string];
    while (i-- > 0) [string appendString:@"0"];
    return ceilf(fmax(DEFAULT_THICKNESS, [string sizeWithAttributes:lineNumberAttributes].width + RULER_MARGIN + MARKER_THICKNESS));
}

static NSPointerArray *createLineCharacterIndexesForString(NSString *string) {
    NSUInteger idx = 0, stringLength = [string length], lineEnd, contentsEnd;
    NSPointerArray *lineCharacterIndexes = [[NSPointerArray alloc] initWithOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsIntegerPersonality];
    
    do {
        [lineCharacterIndexes addPointer:(void *)idx];
        idx = NSMaxRange([string lineRangeForRange:NSMakeRange(idx, 0)]);
    } while (idx < stringLength);

    [string getLineStart:NULL end:&lineEnd contentsEnd:&contentsEnd forRange:NSMakeRange((NSUInteger)[lineCharacterIndexes pointerAtIndex:[lineCharacterIndexes count] - 1], 0)];
    if (contentsEnd < lineEnd)
        [lineCharacterIndexes addPointer:(void *)idx];
    
    return lineCharacterIndexes;
}

- (NSPointerArray *)lineCharacterIndexes {
	if (lineCharacterIndexes == nil) {
        id view = [self clientView];
        
        if ([view isKindOfClass:[NSTextView class]]) {
            lineCharacterIndexes = createLineCharacterIndexesForString([view string]);
            
            CGFloat oldThickness = [self ruleThickness];
            CGFloat newThickness = ruleThicknessForLineCount([lineCharacterIndexes count]);
            if (fabs(oldThickness - newThickness) >= 1.0) {
                NSInvocation *invocation = [NSInvocation invocationWithTarget:self selector:@selector(setRuleThickness:)];
                [invocation setArgument:&newThickness atIndex:2];
                [invocation performSelector:@selector(invoke) withObject:nil afterDelay:0.0];
            }
        }
    }
	return lineCharacterIndexes;
}

- (NSUInteger)lineForCharacterIndex:(NSUInteger)anIndex {
	NSPointerArray *lines = [self lineCharacterIndexes];
    NSUInteger left = 0, right = [lines count], mid, lineStart;

    while (right - left > 1) {
        mid = (right + left) / 2;
        lineStart = (NSUInteger)[lines pointerAtIndex:mid];
        if (anIndex < lineStart)
            right = mid;
        else if (anIndex > lineStart)
            left = mid;
        else
            return mid;
    }
    return left;
}

- (void)drawHashMarksAndLabelsInRect:(NSRect)aRect {
    id view = [self clientView];
	
    if ([view isKindOfClass:[NSTextView class]]) {
        NSLayoutManager *lm = [view layoutManager];
        NSTextContainer *container = [view textContainer];
        NSRect visibleRect = [[[self scrollView] contentView] bounds];
        NSRange range = [lm characterRangeForGlyphRange:[lm glyphRangeForBoundingRect:visibleRect inTextContainer:container] actualGlyphRange:NULL];
        NSRange nullRange = NSMakeRange(NSNotFound, 0);
        NSString *label;
        NSRectArray rects;
        CGFloat offsetX = NSMaxX([self bounds]) - RULER_MARGIN;
        CGFloat offsetY = [view textContainerInset].height - NSMinY(visibleRect);
        NSSize labelSize;
		NSPointerArray *lines = [self lineCharacterIndexes];
        NSUInteger rectCount, i, line, count = [lines count];
        NSRulerMarker *marker;
        NSRect rect;
        
        // one extra for any newline at the end, which doesn't have a glyph
        range.length++;
        
        [self removeAllToolTips];
        
        for (line = [self lineForCharacterIndex:range.location]; line < count; line++) {
            i = (NSUInteger)[lines pointerAtIndex:line];
            
            if (NSLocationInRange(i, range)) {
                rects = [lm rectArrayForCharacterRange:NSMakeRange(i, 0) withinSelectedCharacterRange:nullRange inTextContainer:container rectCount:&rectCount];
                if (rectCount > 0) {
                    if (errorMarkers && (marker = NSMapGet(errorMarkers, (const void *)line))) {
                        rect = NSMakeRect(1.0, offsetY + NSMidY(rects[0]) - 0.5 * MARKER_THICKNESS, MARKER_THICKNESS, MARKER_THICKNESS);
                        [[marker image] drawFlipped:[self isFlipped] inRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
                        [self addToolTipRect:rect owner:[(BDSKErrorObject *)[marker representedObject] errorMessage] userData:NULL];
                    }
                    label = [NSString stringWithFormat:@"%lu", (unsigned long)(line + 1)];
                    labelSize = [label sizeWithAttributes:lineNumberAttributes];
                    rect = NSMakeRect(offsetX - labelSize.width, offsetY + NSMidY(rects[0]) - 0.5 * labelSize.height, labelSize.width, labelSize.height);
                    [label drawInRect:rect withAttributes:lineNumberAttributes];
                }
            }
			if (i > NSMaxRange(range))
				break;
        }
    }
}

- (void)drawMarkersInRect:(NSRect)aRect {}

- (void)mouseDown:(NSEvent *)theEvent {}

@end

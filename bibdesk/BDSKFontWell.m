//
//  BDSKFontWell.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/17/10.
/*
 This software is Copyright (c) 2010-2011
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

#import "BDSKFontWell.h"

#define BDSKNSFontPanelDescriptorsPboardType    @"NSFontPanelDescriptorsPboardType"
#define BDSKNSFontPanelFamiliesPboardType       @"NSFontPanelFamiliesPboardType"
#define BDSKNSFontCollectionFontDescriptors     @"NSFontCollectionFontDescriptors"

#define BDSKFontWellWillBecomeActiveNotification @"BDSKFontWellWillBecomeActiveNotification"

#define FONTNAME_KEY     @"fontName"
#define FONTSIZE_KEY     @"fontSize"
#define TEXTCOLOR_KEY    @"textColor"
#define HASTEXTCOLOR_KEY @"hasTextColor"

#define FONT_KEY         @"font"
#define ACTION_KEY       @"action"
#define TARGET_KEY       @"target"


@interface BDSKFontWell (SKPrivate)
- (void)changeActive:(id)sender;
- (void)fontChanged;
@end


@implementation BDSKFontWell

+ (Class)cellClass {
    return [BDSKFontWellCell class];
}

- (void)commonInit {
    if ([self font] == nil)
        [self setFont:[NSFont systemFontOfSize:0.0]];
    [self fontChanged];
    [super setAction:@selector(changeActive:)];
    [super setTarget:self];
    [self registerForDraggedTypes:[NSArray arrayWithObjects:BDSKNSFontPanelDescriptorsPboardType, BDSKNSFontPanelFamiliesPboardType, nil]];
}

- (id)initWithFrame:(NSRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
		NSButtonCell *oldCell = [self cell];
		if (NO == [oldCell isKindOfClass:[[self class] cellClass]]) {
			BDSKFontWellCell *newCell = [[[[self class] cellClass] alloc] init];
			[newCell setAlignment:[oldCell alignment]];
			[newCell setEditable:[oldCell isEditable]];
			[newCell setTarget:[oldCell target]];
			[newCell setAction:[oldCell action]];
			[self setCell:newCell];
			[newCell release];
		}
        action = NSSelectorFromString([decoder decodeObjectForKey:ACTION_KEY]);
        target = [decoder decodeObjectForKey:TARGET_KEY];
        [self commonInit];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:NSStringFromSelector(action) forKey:ACTION_KEY];
    [coder encodeConditionalObject:target forKey:TARGET_KEY];
}

- (void)dealloc {
    if ([self isActive])
        [self deactivate];
    [super dealloc];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    [self deactivate];
    [super viewWillMoveToWindow:newWindow];
}

- (void)fontWellWillBecomeActive:(NSNotification *)notification {
    id sender = [notification object];
    if (sender != self && [self isActive]) {
        [self deactivate];
    }
}

- (void)fontPanelWillClose:(NSNotification *)notification {
    [self deactivate];
}

- (void)changeFontFromFontManager:(id)sender {
    if ([self isActive]) {
        [self setFont:[sender convertFont:[self font]]];
        [self sendAction:[self action] to:[self target]];
    }
}

- (void)changeActive:(id)sender {
    if ([self isEnabled]) {
        if ([self isActive])
            [self activate];
        else
            [self deactivate];
    }
}

- (void)activate {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSFontManager *fm = [NSFontManager sharedFontManager];
    
    [nc postNotificationName:BDSKFontWellWillBecomeActiveNotification object:self];
    
    [fm setSelectedFont:[self font] isMultiple:NO];
    [fm orderFrontFontPanel:self];
    
    [nc addObserver:self selector:@selector(fontWellWillBecomeActive:)
               name:BDSKFontWellWillBecomeActiveNotification object:nil];
    [nc addObserver:self selector:@selector(fontPanelWillClose:)
               name:NSWindowWillCloseNotification object:[fm fontPanel:YES]];
    
    [self setState:NSOnState];
    [self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
    [self setNeedsDisplay:YES];
}

- (void)deactivate {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self setState:NSOffState];
    [self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
    [self setNeedsDisplay:YES];
}

- (void)fontChanged {
    if ([self isActive])
        [[NSFontManager sharedFontManager] setSelectedFont:[self font] isMultiple:NO];
    [self setTitle:[NSString stringWithFormat:@"%@ %li", [[self font] displayName], (long)[self fontSize]]];
    [self setNeedsDisplay:YES];
}

#pragma mark Accessors

- (SEL)action {
    return action;
}

- (void)setAction:(SEL)selector {
    if (selector != action) {
        action = selector;
    }
}

- (id)target {
    return target;
}

- (void)setTarget:(id)newTarget {
    if (target != newTarget) {
        target = newTarget;
    }
}

- (BOOL)isActive {
    return [self state] == NSOnState;
}

- (void)setFont:(NSFont *)newFont {
    BOOL didChange = [[self font] isEqual:newFont] == NO;
    [super setFont:newFont];
    if (didChange)
        [self fontChanged];
}

- (NSString *)fontName {
    return [[self font] fontName];
}

- (void)setFontName:(NSString *)fontName {
    NSFont *newFont = [NSFont fontWithName:fontName size:[[self font] pointSize]];
    if (newFont)
        [self setFont:newFont];
}

- (CGFloat)fontSize {
    return [[self font] pointSize];
}

- (void)setFontSize:(CGFloat)pointSize {
    NSFont *newFont = [NSFont fontWithName:[[self font] fontName] size:pointSize];
    if (newFont)
        [self setFont:newFont];
}

#pragma mark NSDraggingDestination protocol 

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    if ([self isEnabled] && [sender draggingSource] != self && [[sender draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObjects:BDSKNSFontPanelDescriptorsPboardType, BDSKNSFontPanelFamiliesPboardType, nil]]) {
        [[self cell] setHighlighted:YES];
        [self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
        [self setNeedsDisplay:YES];
        return NSDragOperationGeneric;
    } else
        return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
    if ([self isEnabled] && [sender draggingSource] != self && [[sender draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObjects:BDSKNSFontPanelDescriptorsPboardType, BDSKNSFontPanelFamiliesPboardType, nil]]) {
        [[self cell] setHighlighted:NO];
        [self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
        [self setNeedsDisplay:YES];
    }
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
    return [self isEnabled] && [sender draggingSource] != self && [[sender draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObjects:BDSKNSFontPanelDescriptorsPboardType, BDSKNSFontPanelFamiliesPboardType, nil]];
} 

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender{
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKNSFontPanelDescriptorsPboardType, BDSKNSFontPanelFamiliesPboardType, nil]];
    NSFont *droppedFont = nil;
    
    @try {
        if ([type isEqualToString:BDSKNSFontPanelDescriptorsPboardType]) {
            NSData *data = [pboard dataForType:type];
            NSDictionary *dict = [data isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : nil;
            if ([dict isKindOfClass:[NSDictionary class]]) {
                NSArray *fontDescriptors = [dict objectForKey:BDSKNSFontCollectionFontDescriptors];
                NSFontDescriptor *fontDescriptor = ([fontDescriptors isKindOfClass:[NSArray class]] && [fontDescriptors count]) ? [fontDescriptors objectAtIndex:0] : nil;
                if ([fontDescriptor isKindOfClass:[NSFontDescriptor class]]) {
                    NSNumber *size = [[fontDescriptor fontAttributes] objectForKey:NSFontSizeAttribute] ?: [dict objectForKey:NSFontSizeAttribute];
                    CGFloat fontSize = [size respondsToSelector:@selector(doubleValue)] ? [size doubleValue] : [self fontSize];
                    droppedFont = [NSFont fontWithDescriptor:fontDescriptor size:fontSize];
                }
            }
        } else if ([type isEqualToString:BDSKNSFontPanelFamiliesPboardType]) {
            NSArray *families = [pboard propertyListForType:type];
            NSString *family = ([families isKindOfClass:[NSArray class]] && [families count]) ? [families objectAtIndex:0] : nil;
            if ([family isKindOfClass:[NSString class]])
                droppedFont = [[NSFontManager sharedFontManager] convertFont:[self font] toFamily:family];
        }
    }
    @catch (id exception) {
        NSLog(@"Ignoring exception %@ when dropping on SKFontWell failed", exception);
    }
    
    if (droppedFont) {
        [self setFont:droppedFont];
        [self sendAction:[self action] to:[self target]];
    }
    
    [[self cell] setHighlighted:NO];
    [self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
    [self setNeedsDisplay:YES];
    
	return droppedFont != nil;
}

@end

#pragma mark -

@implementation BDSKFontWellCell

- (void)commonInit {
    [self setBezelStyle:NSShadowlessSquareBezelStyle]; // this is mainly to make it selectable
    [self setButtonType:NSPushOnPushOffButton];
    [self setState:NSOffState];
}
 
- (id)initTextCell:(NSString *)aString {
	if (self = [super initTextCell:aString]) {
		[self commonInit];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
	if (self = [super initWithCoder:decoder]) {
        [self commonInit];
	}
	return self;
}

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView {
    [NSGraphicsContext saveGraphicsState];
    
    NSColor *bgColor = [self state] == NSOnState ? [NSColor selectedControlColor] : [NSColor controlBackgroundColor];
    NSColor *edgeColor = [NSColor colorWithCalibratedWhite:0 alpha:[self isHighlighted] ? 0.33 : .11];
    
    [bgColor setFill];
    NSRectFill(frame);
    
    [edgeColor setStroke];
    [[NSBezierPath bezierPathWithRect:NSInsetRect(frame, 0.5, 0.5)] stroke];
    
    NSBezierPath *path = [NSBezierPath bezierPathWithRect:frame];
    [path appendBezierPathWithRect:NSInsetRect(frame, -2.0, -2.0)];
    [path setWindingRule:NSEvenOddWindingRule];
    NSShadow *shadow1 = [[NSShadow new] autorelease];
    [shadow1 setShadowBlurRadius:2.0];
    [shadow1 setShadowOffset:NSMakeSize(0.0, -1.0)];
    [shadow1 setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.7]];
    [shadow1 set];
    [[NSColor blackColor] setFill];
    [path fill];
    
    [NSGraphicsContext restoreGraphicsState];
    
    if ([self refusesFirstResponder] == NO && [NSApp isActive] && [[controlView window] isKeyWindow] && [[controlView window] firstResponder] == controlView) {
        [NSGraphicsContext saveGraphicsState];
        NSSetFocusRingStyle(NSFocusRingOnly);
        NSRectFill(frame);
        [NSGraphicsContext restoreGraphicsState];
    }
}

@end

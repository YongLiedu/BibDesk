//
//  BDSKButtonBar.m
//  Bibdesk
//
//  Created by Christiaan on 12/2/09.
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

#import "BDSKButtonBar.h"

#define BUTTON_HEIGHT 17.0
#define BUTTON_MARGIN 8.0
#define BUTTON_SEPARATION 2.0


@implementation BDSKButtonBar

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        buttons = [[NSMutableArray alloc] init];
        target = nil;
        action = NULL;
        [self setGradient:[[[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.82 alpha:1.0] endingColor:[NSColor colorWithCalibratedWhite:0.914 alpha:1.0]] autorelease]];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(buttons);
    [super dealloc];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize {
    [super resizeSubviewsWithOldSize:oldBoundsSize];
    [self tile];
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

- (NSArray *)buttons {
    return buttons;
}

- (NSButton *)buttonAtIndex:(NSInteger)anIndex {
	return [buttons objectAtIndex:anIndex];
}

- (void)insertButton:(NSButton *)button atIndex:(NSInteger)anIndex {
	[buttons insertObject:button atIndex:anIndex];
    [button setTarget:self];
    [button setAction:@selector(clickButton:)];
    [self addSubview:button];
    [self tile];
    [self setNeedsDisplay:YES];
}

- (void)removeButton:(NSButton *)button {
    [button setTarget:nil];
	[buttons removeObject:button];
    [button removeFromSuperviewWithoutNeedingDisplay];
    [self tile];
	[self setNeedsDisplay:YES];
}

- (void)removeButtonAtIndex:(NSInteger)anIndex {
	[self removeButton:[buttons objectAtIndex:anIndex]];
}

- (NSButton *)selectedButton {
	for (NSButton *button in buttons) {
		if ([button state] == NSOnState)
			return button;
	}
	return nil;
}

- (id)representedObjectOfSelectedButton {
	return [[[self selectedButton] cell] representedObject];
}

- (void)selectButtonWithRepresentedObject:(id)representedObject {
	for (NSButton *button in buttons) {
        if ([[[button cell] representedObject] isEqual:representedObject]) {
            [self clickButton:button];
            break;
        }
    }
}

- (void)clickButton:(id)sender {
	BOOL didChangeSelection = NO;
	for (NSButton *button in buttons) {
        if ([button isEqual:sender]) {
            // the button click already swaps the state
            if ([button state] == NSOnState)
                didChangeSelection = YES;
            else
                [button setState:NSOnState];
        } else if ([button state] == NSOnState && [button isEqual:sender] == NO) {
            [button setState:NSOffState];
            [self setNeedsDisplayInRect:[button frame]];
            didChangeSelection = YES;
        }
    }
    [self setNeedsDisplayInRect:[sender frame]];
	if (didChangeSelection)
        [NSApp sendAction:[self action] to:[self target] from:self];
}

- (void)tile {
	NSPoint origin = NSMakePoint(BUTTON_MARGIN, floor(0.5 * (NSHeight([self frame]) - BUTTON_HEIGHT)));
	for (NSButton *button in buttons) {
        [button sizeToFit];
		[button setFrameOrigin:origin];
		origin.x += NSWidth([button frame]) + BUTTON_SEPARATION;
	}
}

@end

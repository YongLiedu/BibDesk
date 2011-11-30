//
//  BDSKAddressTextField.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/26/11.
/*
 This software is Copyright (c) 2011
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

#import "BDSKAddressTextField.h"
#import "BDSKAddressTextFieldCell.h"

#define BUTTON_SIZE 16.0
#define BUTTON_MARGIN 3.0

@implementation BDSKAddressTextField

+ (Class)cellClass {
    return [BDSKAddressTextFieldCell class];
}

- (void)makeButton {
    NSRect rect, bounds = [self bounds];
    rect.origin.x = NSMaxX(bounds) - BUTTON_SIZE - BUTTON_MARGIN;
    rect.origin.y = [self isFlipped] ? NSMinY(bounds) + BUTTON_MARGIN : NSMaxY(bounds) - BUTTON_SIZE - BUTTON_MARGIN;
    rect.size.width = rect.size.height = BUTTON_SIZE;
    button = [[NSButton alloc] initWithFrame:rect];
    [button setButtonType:NSMomentaryChangeButton];
    [button setBordered:NO];
    [button setImagePosition:NSImageOnly];
    [[button cell] setImageScaling:NSImageScaleProportionallyDown];
    [button setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
    [self addSubview:button];
}

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self makeButton];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        button = [[aDecoder decodeObjectForKey:@"button"] retain];
        if (button == nil)
            [self makeButton];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
    [aCoder encodeConditionalObject:button forKey:@"button"];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    BDSKDESTROY(button);
	[super dealloc];
}

- (NSButton *)button {
    return button;
}

- (void)handleKeyOrMainStateChangedNotification:(NSNotification *)note {
    [self setNeedsDisplay:YES];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    NSWindow *window = [self window];
    if (window) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self name:NSWindowDidBecomeMainNotification object:window];
        [nc removeObserver:self name:NSWindowDidResignMainNotification object:window];
        [nc removeObserver:self name:NSWindowDidBecomeKeyNotification object:window];
        [nc removeObserver:self name:NSWindowDidResignKeyNotification object:window];
    }
    [super viewWillMoveToWindow:newWindow];
}

- (void)viewDidMoveToWindow {
    NSWindow *window = [self window];
    if (window) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(handleKeyOrMainStateChangedNotification:) name:NSWindowDidBecomeMainNotification object:window];
        [nc addObserver:self selector:@selector(handleKeyOrMainStateChangedNotification:) name:NSWindowDidResignMainNotification object:window];
        [nc addObserver:self selector:@selector(handleKeyOrMainStateChangedNotification:) name:NSWindowDidBecomeKeyNotification object:window];
        [nc addObserver:self selector:@selector(handleKeyOrMainStateChangedNotification:) name:NSWindowDidResignKeyNotification object:window];
    }
    [super viewDidMoveToWindow];
}

@end

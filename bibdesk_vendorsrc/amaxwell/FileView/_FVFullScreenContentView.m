//
//  _FVFullScreenContentView.m
//  FileView
//
//  Created by Adam R. Maxwell on 12/14/09.
/*
 This software is Copyright (c) 2009-2012
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

#import "_FVFullScreenContentView.h"
#import "FVPreviewer.h"

@implementation _FVFullScreenContentView

- (BOOL)enterFullScreenMode:(NSScreen *)screen withOptions:(NSDictionary *)options;
{
    _windowDelegate = (FVPreviewer *)[[self window] delegate];
    [self setNeedsDisplay:YES];
    return [super enterFullScreenMode:screen withOptions:options];
}

- (void)exitFullScreenModeWithOptions:(NSDictionary *)options;
{
    _windowDelegate = nil;
    [super exitFullScreenModeWithOptions:options];
    [self setNeedsDisplay:YES];
}

- (void)keyDown:(NSEvent *)event
{
    /*
     Handle escape; this is essentially overriding any key bindings, but interpretKeyEvents:
     sends complete: on my system when I get an esc.  Even if that binding is not standard, it's
     fairly common.
     
     Use space bar to dismiss as well, since the views in the previewer are not editable.
     */
    if ([[event characters] length]) {
        
        const unichar ch = [[event characters] characterAtIndex:0];
        
        if (ch == 0x001b || ch == 0x0020) {
            if ([[self window] delegate]) 
                [(FVPreviewer *)[[self window] delegate] cancel:self];
            else
                [_windowDelegate cancel:self];
        }
        
    }
    else {
        [super keyDown:event];
    }
}

- (void)drawRect:(NSRect)rect {
    if ([self isInFullScreenMode]) {
        [[NSColor blackColor] set];
        NSRectFill(rect);
    }
}

- (BOOL)isOpaque {
    return [self isInFullScreenMode];
}

@end

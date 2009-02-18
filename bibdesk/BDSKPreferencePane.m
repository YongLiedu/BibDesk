//
//  BDSKPreferencePane.m
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

#import "BDSKPreferencePane.h"
#import "BDSKPreferenceController.h"


@implementation BDSKPreferencePane

- (id)initWithNibName:(NSString *)nibName identifier:(NSString *)anIdentifier forPreferenceController:(BDSKPreferenceController *)aController {
    if (self = [super initWithWindowNibName:nibName ?: [self windowNibName]]) {
        identifier = [anIdentifier retain];
        preferenceController = aController;
    }
    return self;
}

- (void)dealloc {
    [view release];
    [identifier release];
    [title release];
    [label release];
    [icon release];
    [helpAnchor release];
    [helpURL release];
    [initialValues release];
    [super dealloc];
}

- (void)loadWindow {
    [super loadWindow];
    [view retain];
}

- (BDSKPreferenceController *)preferenceController {
    return preferenceController;
}

- (NSView *)view {
    if (view == nil)
        [self window];
    return view;
}

- (NSString *)identifier {
    return identifier;
}

- (NSString *)title {
    return (title ?: label) ?: identifier;
}

- (void)setTitle:(NSString *)newTitle {
    if (title != newTitle) {
        [title release];
        title = [newTitle retain];
    }
}

- (NSString *)label {
    return (label ?: title) ?: identifier;
}

- (void)setLabel:(NSString *)newLabel {
    if (label != newLabel) {
        [label release];
        label = [newLabel retain];
    }
}

- (NSString *)toolTip {
    return (toolTip ?: title) ?: label;
}

- (void)setToolTip:(NSString *)newToolTip {
    if (toolTip != newToolTip) {
        [toolTip release];
        toolTip = [newToolTip retain];
    }
}

- (NSImage *)icon {
    return icon;
}

- (void)setIcon:(NSImage *)newIcon {
    if (icon != newIcon) {
        [icon release];
        icon = [newIcon retain];
    }
}

- (NSString *)helpAnchor {
    return helpAnchor;
}

- (void)setHelpAnchor:(NSString *)newHelpAnchor {
    if (helpAnchor != newHelpAnchor) {
        [helpAnchor release];
        helpAnchor = [newHelpAnchor retain];
    }
}

- (NSURL *)helpURL {
    return helpURL;
}

- (void)setHelpURL:(NSURL *)newHelpURL {
    if (helpURL != newHelpURL) {
        [helpURL release];
        helpURL = [newHelpURL retain];
    }
}

- (NSDictionary *)initialValues {
    return initialValues;
}

- (void)setInitialValues:(NSDictionary *)newInitialValues {
    if (initialValues != newInitialValues) {
        [initialValues release];
        initialValues = [newInitialValues retain];
    }
}

- (void)revertDefaults {
    if ([[self initialValues] count])
        [[[NSUserDefaultsController sharedUserDefaultsController] values] setValuesForKeysWithDictionary:[self initialValues]];
}

- (void)willSelect {}
- (void)didSelect {}

- (BDSKPreferencePaneUnselectReply)shouldUnselect { return BDSKPreferencePaneUnselectNow; }
- (void)willUnselect {}
- (void)didUnselect {}

- (void)willShowWindow {}
- (void)didShowWindow {}
- (BOOL)shouldCloseWindow { return YES; }
- (void)willCloseWindow {}

@end

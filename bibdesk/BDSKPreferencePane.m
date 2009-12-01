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
#import "BDSKPreferenceRecord.h"


@implementation BDSKPreferencePane

- (id)initWithRecord:(BDSKPreferenceRecord *)aRecord forPreferenceController:(BDSKPreferenceController *)aController {
    if (self = [super initWithWindowNibName:[aRecord nibName] ?: [self windowNibName]]) {
        record = [aRecord retain];
        preferenceController = aController;
        sud = [NSUserDefaults standardUserDefaults];
        sudc = [NSUserDefaultsController sharedUserDefaultsController];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(view);
    BDSKDESTROY(record);
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

- (BDSKPreferenceRecord *)record {
    return record;
}

- (NSString *)identifier {
    return [record identifier];
}

- (NSString *)title {
    return ([record title] ?: [record label]) ?: [record identifier];
}

- (NSString *)label {
    return ([record label] ?: [record title]) ?: [record identifier];
}

- (NSString *)toolTip {
    return ([record toolTip] ?: [record title]) ?: [record label];
}

- (NSImage *)icon {
    return [record icon];
}

- (NSString *)helpAnchor {
    return [record helpAnchor];
}

- (NSURL *)helpURL {
    return [record helpURL];
}

- (NSDictionary *)initialValues {
    return [record initialValues];
}

- (void)defaultsDidRevert {}

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

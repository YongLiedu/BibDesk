//
//  BDSKPreferencePane.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/17/09.
/*
 This software is Copyright (c) 2009-2011
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
    self = [super initWithNibName:[aRecord nibName] ?: [self nibName] bundle:nil];
    if (self) {
        [self setRepresentedObject:aRecord];
        preferenceController = aController;
        isViewLoaded = NO;
        sud = [NSUserDefaults standardUserDefaults];
        sudc = [NSUserDefaultsController sharedUserDefaultsController];
    }
    return self;
}

- (void)loadView {
    [super loadView];
    isViewLoaded = YES;
}

- (BOOL)isViewLoaded {
    return isViewLoaded;
}

- (BDSKPreferenceController *)preferenceController {
    return preferenceController;
}

- (BDSKPreferenceRecord *)record {
    return [self representedObject];
}

- (NSString *)identifier {
    return [[self representedObject] identifier];
}

- (NSString *)title {
    return ([[self representedObject] title] ?: [[self representedObject] label]) ?: [[self representedObject] identifier];
}

- (NSString *)label {
    return ([[self representedObject] label] ?: [[self representedObject] title]) ?: [[self representedObject] identifier];
}

- (NSString *)toolTip {
    return ([[self representedObject] toolTip] ?: [[self representedObject] title]) ?: [[self representedObject] label];
}

- (NSImage *)icon {
    return [[self representedObject] icon];
}

- (NSString *)helpAnchor {
    return [[self representedObject] helpAnchor];
}

- (NSURL *)helpURL {
    return [[self representedObject] helpURL];
}

- (NSDictionary *)initialValues {
    return [[self representedObject] initialValues];
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

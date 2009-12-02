//
//  BDSKPreferencePane.h
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

#import <Cocoa/Cocoa.h>

enum {
    BDSKPreferencePaneUnselectCancel,
    BDSKPreferencePaneUnselectNow,
    BDSKPreferencePaneUnselectLater
};
typedef NSInteger BDSKPreferencePaneUnselectReply;

@class BDSKPreferenceController, BDSKPreferenceRecord;

@interface BDSKPreferencePane : NSViewController {
    BDSKPreferenceController *preferenceController;
    BOOL isViewLoaded;
    NSUserDefaults *sud;
    NSUserDefaultsController *sudc;
}

- (id)initWithRecord:(BDSKPreferenceRecord *)aRecord forPreferenceController:(BDSKPreferenceController *)aController;

- (BDSKPreferenceController *)preferenceController;

- (BDSKPreferenceRecord *)record;

- (NSString *)identifier;
- (NSString *)title;
- (NSString *)label;
- (NSString *)toolTip;
- (NSImage *)icon;
- (NSString *)helpAnchor;
- (NSURL *)helpURL;
- (NSDictionary *)initialValues;

- (BOOL)isViewLoaded;

// these are sent to the relevant pane(s), usually the selected pane, and by default do nothing

- (void)defaultsDidRevert;

- (void)willSelect;
- (void)didSelect;

// if this returns BDSKPreferencePaneUnselectLater, -replyToShouldUnselect: should be called when this is resolved
- (BDSKPreferencePaneUnselectReply)shouldUnselect;
- (void)willUnselect;
- (void)didUnselect;

- (void)willShowWindow;
- (void)didShowWindow;
- (BOOL)shouldCloseWindow;
- (void)willCloseWindow;

@end

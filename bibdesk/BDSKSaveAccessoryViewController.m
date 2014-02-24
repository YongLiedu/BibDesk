//
//  BDSKSaveAccessoryViewController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/9/13.
/*
 This software is Copyright (c) 2013-2014
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

#import "BDSKSaveAccessoryViewController.h"
#import "BDSKStringEncodingManager.h"

#define SAVE_FORMAT_POPUP_OFFSET 66.0


@implementation BDSKSaveAccessoryViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:@"BDSKSaveAccessoryView" bundle:nil];
    if (self) {
        // make sure the nib is loaded
        [self view];
    }
    return self;
}

- (NSView *)saveAccessoryView {
    return saveAccessoryView;
}

- (NSView *)exportAccessoryView {
    return exportAccessoryView;
}

- (void)addSaveFormatPopUpButton:(NSPopUpButton *)popup {
    NSRect popupFrame = [saveTextEncodingPopupButton frame];
    CGFloat dw = NSWidth([popup frame]) - NSWidth(popupFrame);
    if (dw > 0.0) {
        NSRect viewFrame = [exportAccessoryView frame];
        viewFrame.size.width += dw;
        [exportAccessoryView setFrame:viewFrame];
        popupFrame.size.width += dw;
    }
    popupFrame.origin.y = SAVE_FORMAT_POPUP_OFFSET;
    [popup setFrame:popupFrame];
    [exportAccessoryView addSubview:popup];
}

- (NSStringEncoding)saveTextEncoding {
    return [saveTextEncodingPopupButton encoding];
}

- (void)setSaveTextEncoding:(NSStringEncoding)encoding {
    [saveTextEncodingPopupButton setEncoding:encoding];
}

- (BOOL)exportSelection {
    return [exportSelectionCheckButton state] == NSOnState;
}

- (void)setExportSelection:(BOOL)flag {
    [exportSelectionCheckButton setState:flag ? NSOnState : NSOffState];
}

- (BOOL)isSaveTextEncodingPopupButtonEnabled {
    return [saveTextEncodingPopupButton isEnabled];
}

- (void)setSaveTextEncodingPopupButtonEnabled:(BOOL)flag {
    [saveTextEncodingPopupButton setEnabled:flag];
}

- (BOOL)isExportSelectionCheckButtonEnabled {
    return [exportSelectionCheckButton isEnabled];
}

- (void)setExportSelectionCheckButtonEnabled:(BOOL)flag {
    [exportSelectionCheckButton setEnabled:flag];
}

@end

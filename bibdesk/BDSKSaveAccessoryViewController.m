//
//  BDSKSaveAccessoryViewController.m
//  Bibdesk
//
//  Created by Christiaan on 2/9/13.
//  Copyright 2013 Christiaan Hofman. All rights reserved.
//

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

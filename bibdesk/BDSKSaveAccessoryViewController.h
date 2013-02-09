//
//  BDSKSaveAccessoryViewController.h
//  Bibdesk
//
//  Created by Christiaan on 2/9/13.
//  Copyright 2013 Christiaan Hofman. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BDSKEncodingPopUpButton;

@interface BDSKSaveAccessoryViewController : NSViewController {
    IBOutlet NSView *saveAccessoryView;
    IBOutlet NSView *exportAccessoryView;
    IBOutlet BDSKEncodingPopUpButton *saveTextEncodingPopupButton;
    IBOutlet NSButton *exportSelectionCheckButton;
}

- (NSView *)saveAccessoryView;
- (NSView *)exportAccessoryView;

- (void)addSaveFormatPopUpButton:(NSPopUpButton *)popup;

- (NSStringEncoding)saveTextEncoding;
- (void)setSaveTextEncoding:(NSStringEncoding)encoding;

- (BOOL)exportSelection;
- (void)setExportSelection:(BOOL)flag;

- (BOOL)isSaveTextEncodingPopupButtonEnabled;
- (void)setSaveTextEncodingPopupButtonEnabled:(BOOL)flag;

- (BOOL)isExportSelectionCheckButtonEnabled;
- (void)setExportSelectionCheckButtonEnabled:(BOOL)flag;

@end

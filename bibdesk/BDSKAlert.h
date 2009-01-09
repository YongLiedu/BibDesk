//
//  BDSKAlert.h
//  BibDesk
//
//  Created by Christiaan Hofman on 24/11/05.
/*
 This software is Copyright (c) 2005-2009
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
#import "BDSKSheetController.h"


@interface BDSKAlert : BDSKSheetController {
	IBOutlet NSTextField *informationField;
	IBOutlet NSTextField *messageField;
	IBOutlet NSButton *checkButton;
	IBOutlet NSImageView *imageView;
    IBOutlet NSButton *helpButton;
    NSString *helpAnchor;
    NSMutableArray *buttons;
    NSImage *unbadgedImage;
    int alertStyle;
	BOOL hasCheckButton;
	NSSize minButtonSize;
}

+ (BDSKAlert *)alertWithMessageText:(NSString *)messageTitle defaultButton:(NSString *)defaultButtonTitle alternateButton:(NSString *)alternateButtonTitle otherButton:(NSString *)otherButtonTitle informativeTextWithFormat:(NSString *)format, ...;

- (void)setMessageText:(NSString *)messageText;
- (NSString *)messageText;
- (void)setInformativeText:(NSString *)informativeText;
- (NSString *)informativeText;

- (void)setIcon:(NSImage *)icon;
- (NSImage *)icon;

- (void)setHasCheckButton:(BOOL)flag;
- (BOOL)hasCheckButton;
- (void)setCheckText:(NSString *)checkText;
- (NSString *)checkText;
- (void)setCheckValue:(BOOL)flag;
- (BOOL)checkValue;

- (NSButton *)addButtonWithTitle:(NSString *)aTitle;
- (NSArray *)buttons;
- (NSButton *)checkButton;

- (IBAction)helpAction:(id)sender;
- (void)setHelpAnchor:(NSString *)anchor;
- (NSString *)helpAnchor;
- (void)setShowsHelp:(BOOL)flag;
- (BOOL)showsHelp;

- (void)setAlertStyle:(NSAlertStyle)style;
- (NSAlertStyle)alertStyle;

@end

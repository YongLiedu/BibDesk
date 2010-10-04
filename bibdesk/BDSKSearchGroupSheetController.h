//
//  BDSKSearchGroupSheetController.h
//  Bibdesk
//
//  Created by Adam Maxwell on 12/26/06.
/*
 This software is Copyright (c) 2006-2010
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

@class BDSKSearchGroup, BDSKServerInfo, BDSKMutableServerInfo, BDSKCollapsibleView;

@interface BDSKSearchGroupSheetController : NSWindowController {
    BDSKSearchGroup *group;
    NSUndoManager *undoManager;
    BDSKMutableServerInfo *serverInfo;
    
    BOOL isCustom;
    BOOL isEditable;
    
    IBOutlet NSPopUpButton *serverPopup;
    IBOutlet NSMatrix *typeMatrix;
    
    IBOutlet NSTextField *nameField;
    IBOutlet NSTextField *addressField;
    IBOutlet NSTextField *portField;
    IBOutlet NSTextField *databaseField;
    IBOutlet NSSecureTextField *passwordField;
    IBOutlet NSTextField *userField;
    IBOutlet NSPopUpButton *syntaxPopup;
    IBOutlet NSComboBox *encodingComboBox;
    IBOutlet NSButton *removeDiacriticsButton;
    
    IBOutlet NSButton *editButton;
    IBOutlet NSButton *addRemoveButton;
    
    IBOutlet BDSKCollapsibleView *serverView;
    IBOutlet NSButton *revealButton;
    
    IBOutlet NSObjectController *objectController;
}

- (id)initWithGroup:(BDSKSearchGroup *)aGroup;

- (IBAction)selectPredefinedServer:(id)sender;
- (IBAction)selectSyntax:(id)sender;

- (IBAction)addRemoveServer:(id)sender;
- (IBAction)editServer:(id)sender;
- (IBAction)resetServers:(id)sender;

- (IBAction)toggle:(id)sender;

- (void)setCustom:(BOOL)flag;
- (BOOL)isCustom;
- (void)setEditable:(BOOL)flag;
- (BOOL)isEditable;
- (BOOL)isZoom;

- (void)setType:(NSString *)newType;
- (NSString *)type;

- (void)setTypeTag:(NSInteger)tag;
- (NSInteger)typeTag;

- (void)setServerInfo:(BDSKServerInfo *)info;
- (BDSKServerInfo *)serverInfo;

- (BDSKSearchGroup *)group;
- (IBAction)selectPredefinedServer:(id)sender;

- (BOOL)commitEditing;
- (NSUndoManager *)undoManager;

@end

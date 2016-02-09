//
//  BDSKFieldSheetController.m
//  BibDesk
//
//  Created by Christiaan Hofman on 3/18/06.
/*
 This software is Copyright (c) 2005-2016
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

#import "BDSKFieldSheetController.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKFieldNameFormatter.h"

@implementation BDSKFieldSheetController

+ (id)fieldSheetControllerWithSelectableFields:(NSArray *)selectableFields label:(NSString *)selectedFieldLabel choosableFields:(NSArray *)choosableFields label:(NSString *)chosenFieldLabel {
    BDSKFieldSheetController *controller = [[[self alloc] init] autorelease];
    [controller setSelectableFields:selectableFields];
    [controller setSelectedFieldLabel:selectedFieldLabel];
    [controller setChoosableFields:choosableFields];
    [controller setChosenFieldLabel:chosenFieldLabel];
    if (selectableFields == nil)
        [controller setDefaultButtonTitle:NSLocalizedString(@"Add", @"Button title")];
    else if (choosableFields == nil)
        [controller setDefaultButtonTitle:NSLocalizedString(@"Remove", @"Button title")];
    else
        [controller setDefaultButtonTitle:NSLocalizedString(@"Change", @"Button title")];
    return controller;
}

+ (id)fieldSheetControllerWithSelectableFields:(NSArray *)selectableFields label:(NSString *)selectedFieldLabel {
    return [self fieldSheetControllerWithSelectableFields:selectableFields label:selectedFieldLabel choosableFields:nil label:nil];
}

+ (id)fieldSheetControllerWithChoosableFields:(NSArray *)choosableFields label:(NSString *)chosenFieldLabel {
    return [self fieldSheetControllerWithSelectableFields:nil label:nil choosableFields:choosableFields label:chosenFieldLabel];
}

- (id)init {
    self = [super initWithWindowNibName:@"FieldSheet"];
    if (self) {
        [self setCancelButtonTitle:NSLocalizedString(@"Cancel", @"Button title")];
        [self setDefaultButtonTitle:NSLocalizedString(@"OK", @"Button title")];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(selectedField);
    BDSKDESTROY(selectedFieldLabel);
    BDSKDESTROY(selectableFields);
    BDSKDESTROY(chosenField);
    BDSKDESTROY(chosenFieldLabel);
    BDSKDESTROY(choosableFields);
    [super dealloc];
}

- (void)windowDidLoad {
    BDSKFieldNameFormatter *formatter = [[[BDSKFieldNameFormatter alloc] init] autorelease];
    [formatter setKnownFieldNames:[self choosableFields]];
	[chosenFieldComboBox setFormatter:formatter];
}

- (NSString *)selectedField {
    return selectedField;
}

- (void)setSelectedField:(NSString *)newField {
    if (selectedField != newField) {
        [selectedField release];
        selectedField = [newField retain];
    }
}

- (NSString *)selectedFieldLabel {
    return selectedFieldLabel;
}

- (void)setSelectedFieldLabel:(NSString *)newLabel {
    if (selectedFieldLabel != newLabel) {
        [selectedFieldLabel release];
        selectedFieldLabel = [newLabel retain];
    }
}

- (NSArray *)selectableFields {
    return selectableFields;
}

- (void)setSelectableFields:(NSArray *)array {
    if (selectableFields != array) {
        [selectableFields release];
        selectableFields = [array copy];
        if ([selectableFields count] > 0 && selectedField == nil)
            [self setSelectedField:[selectableFields objectAtIndex:0]];
    }
}

- (NSString *)chosenField {
    return chosenField;
}

- (void)setChosenField:(NSString *)newField {
    if (chosenField != newField) {
        [chosenField release];
        chosenField = [newField retain];
    }
}

- (NSString *)chosenFieldLabel {
    return chosenFieldLabel;
}

- (void)setChosenFieldLabel:(NSString *)newLabel {
    if (chosenFieldLabel != newLabel) {
        [chosenFieldLabel release];
        chosenFieldLabel = [newLabel retain];
    }
}

- (NSArray *)choosableFields {
    return choosableFields;
}

- (void)setChoosableFields:(NSArray *)array {
    if (choosableFields != array) {
        [choosableFields release];
        choosableFields = [array copy];
        [[chosenFieldComboBox formatter] setKnownFieldNames:choosableFields];
    }
}

- (NSString *)defaultButtonTitle {
    return defaultButtonTitle;
}

- (void)setDefaultButtonTitle:(NSString *)title{
    if (defaultButtonTitle != title) {
        [defaultButtonTitle release];
        defaultButtonTitle = [title retain];
    }
}

- (NSString *)cancelButtonTitle {
    return cancelButtonTitle;
}

- (void)setCancelButtonTitle:(NSString *)title {
    if (cancelButtonTitle != title) {
        [cancelButtonTitle release];
        cancelButtonTitle = [title retain];
    }
}

#define MIN_BUTTON_WIDTH 82.0
#define MAX_BUTTON_WIDTH 100.0
#define EXTRA_BUTTON_WIDTH 12.0

- (void)prepare {
    NSRect popupFrame = [selectedFieldPopUpButton frame];
    NSRect oldSelectedLabelFrame = [selectedFieldLabelField frame];
    NSRect comboboxFrame = [chosenFieldComboBox frame];
    NSRect oldChosenLabelFrame = [chosenFieldLabelField frame];
    [selectedFieldLabelField sizeToFit];
    [chosenFieldLabelField sizeToFit];
    NSRect newSelectedLabelFrame = [selectedFieldLabelField frame];
    NSRect newChosenLabelFrame = [chosenFieldLabelField frame];
    CGFloat dw;
    if (NSWidth(newSelectedLabelFrame) > NSWidth(newChosenLabelFrame)) {
        dw = NSWidth(newSelectedLabelFrame) - NSWidth(oldSelectedLabelFrame);
        newChosenLabelFrame.size.width = NSWidth(newSelectedLabelFrame);
        [chosenFieldLabelField setFrame:newChosenLabelFrame];
    } else {
        dw = NSWidth(newChosenLabelFrame) - NSWidth(oldChosenLabelFrame);
        newSelectedLabelFrame.size.width = NSWidth(newChosenLabelFrame);
        [selectedFieldPopUpButton setFrame:newSelectedLabelFrame];
    }
    popupFrame.size.width -= dw;
    popupFrame.origin.x += dw;
    comboboxFrame.size.width -= dw;
    comboboxFrame.origin.x += dw;
    [selectedFieldPopUpButton setFrame:popupFrame];
    [chosenFieldComboBox setFrame:comboboxFrame];
    
    if (selectableFields == nil || choosableFields == nil) {
        NSRect windowFrame = [[self window] frame];
        windowFrame.size.height -= NSMinY(popupFrame) - NSMinY(comboboxFrame);
        [[self window] setFrame:windowFrame display:NO];
    }
    
    CGFloat buttonX = NSMaxX([defaultButton frame]);
    for (NSButton *button in [NSArray arrayWithObjects:defaultButton, cancelButton, nil]) {
        [button sizeToFit];
        NSRect buttonFrame = [button frame];
        buttonFrame.size.width = fmin(MAX_BUTTON_WIDTH, fmax(MIN_BUTTON_WIDTH, NSWidth(buttonFrame) + EXTRA_BUTTON_WIDTH));
        buttonX -= NSWidth(buttonFrame);
        buttonFrame.origin.x = buttonX;
        [button setFrame:buttonFrame];
    }
}

- (void)beginSheetModalForWindow:(NSWindow *)window completionHandler:(void (^)(NSInteger result))handler {
    [self window];
    [self prepare];
    [super beginSheetModalForWindow:window completionHandler:handler];
}

- (IBAction)dismiss:(id)sender {
    if ([sender tag] == NSCancelButton || [objectController commitEditing]) {
        [objectController setContent:nil];
        [super dismiss:sender];
    }
}

@end

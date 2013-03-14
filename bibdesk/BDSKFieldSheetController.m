//
//  BDSKFieldSheetController.m
//  BibDesk
//
//  Created by Christiaan Hofman on 3/18/06.
/*
 This software is Copyright (c) 2005-2013
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

- (id)initWithPrompt:(NSString *)promptString fieldsArray:(NSArray *)fields{
    self = [super init];
    if (self) {
        [self window]; // make sure the nib is loaded
        field = nil;
        [self setPrompt:promptString];
        [self setFieldsArray:fields];
        [self setDefaultButtonTitle:@""];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(prompt);
    BDSKDESTROY(defaultButtonTitle);
    BDSKDESTROY(fieldsArray);
    BDSKDESTROY(field);
    [super dealloc];
}

- (NSString *)field{
    return field;
}

- (void)setField:(NSString *)newField{
    if (field != newField) {
        [field release];
        field = [newField copy];
    }
}

- (NSArray *)fieldsArray{
    return fieldsArray;
}

- (void)setFieldsArray:(NSArray *)array{
    if (fieldsArray != array) {
        [fieldsArray release];
        fieldsArray = [array retain];
    }
}

- (NSString *)prompt{
    return prompt;
}

- (void)setPrompt:(NSString *)promptString{
    if (prompt != promptString) {
        [prompt release];
        prompt = [promptString retain];
    }
}

- (NSString *)defaultButtonTitle{
    return defaultButtonTitle;
}

- (void)setDefaultButtonTitle:(NSString *)title{
    if (defaultButtonTitle != title) {
        [defaultButtonTitle release];
        defaultButtonTitle = [title retain];
    }
}

#define MIN_BUTTON_WIDTH 82.0
#define MAX_BUTTON_WIDTH 100.0
#define EXTRA_BUTTON_WIDTH 12.0

- (void)prepare{
    NSRect fieldsFrame = [fieldsControl frame];
    NSRect oldPromptFrame = [promptField frame];
    [promptField sizeToFit];
    NSRect newPromptFrame = [promptField frame];
    CGFloat dw = NSWidth(newPromptFrame) - NSWidth(oldPromptFrame);
    fieldsFrame.size.width -= dw;
    fieldsFrame.origin.x += dw;
    [fieldsControl setFrame:fieldsFrame];
    
    CGFloat buttonRight = NSMaxX([okButton frame]);
    [okButton sizeToFit];
    NSRect buttonFrame = [okButton frame];
    buttonFrame.size.width = fmin(MAX_BUTTON_WIDTH, fmax(MIN_BUTTON_WIDTH, NSWidth(buttonFrame) + EXTRA_BUTTON_WIDTH));
    buttonRight -= NSWidth(buttonFrame);
    buttonFrame.origin.x = buttonRight;
    [okButton setFrame:buttonFrame];
    buttonFrame = [cancelButton frame];
    buttonRight -= NSWidth(buttonFrame);
    [cancelButton setFrame:buttonFrame];
}

- (void)beginSheetModalForWindow:(NSWindow *)window completionHandler:(void (^)(NSInteger result))handler {
    [self prepare];
    [super beginSheetModalForWindow:window completionHandler:handler];
}

- (IBAction)dismiss:(id)sender{
    if ([sender tag] == NSCancelButton || [objectController commitEditing]) {
        [objectController setContent:nil];
        [super dismiss:sender];
    }
}

@end


@implementation BDSKAddFieldSheetController

- (id)initWithPrompt:(NSString *)promptString fieldsArray:(NSArray *)fields{
    self = [super initWithPrompt:promptString fieldsArray:fields];
    if (self) {
        [self setDefaultButtonTitle:NSLocalizedString(@"Add", @"Button title")];
    }
    return self;
}

- (void)windowDidLoad{
    BDSKFieldNameFormatter *formatter = [[[BDSKFieldNameFormatter alloc] init] autorelease];
    [formatter setKnownFieldNames:[self fieldsArray]];
	[fieldsControl setFormatter:formatter];
}

- (NSString *)windowNibName{
    return @"AddFieldSheet";
}

- (void)setFieldsArray:(NSArray *)array{
    [super setFieldsArray:array];
    [[fieldsControl formatter] setKnownFieldNames:array];
}

@end


@implementation BDSKRemoveFieldSheetController

- (id)initWithPrompt:(NSString *)promptString fieldsArray:(NSArray *)fields{
    self = [super initWithPrompt:promptString fieldsArray:fields];
    if (self) {
        [self setDefaultButtonTitle:NSLocalizedString(@"Remove", @"Button title")];
    }
    return self;
}

- (NSString *)windowNibName{
    return @"RemoveFieldSheet";
}

- (void)setFieldsArray:(NSArray *)array{
    [super setFieldsArray:array];
    if ([fieldsArray count]) {
        [self setField:[fieldsArray objectAtIndex:0]];
        [okButton setEnabled:YES];
    } else {
        [okButton setEnabled:NO];
    }
}

@end


@implementation BDSKChangeFieldSheetController

- (id)initWithPrompt:(NSString *)promptString fieldsArray:(NSArray *)fields replacePrompt:(NSString *)newPromptString replaceFieldsArray:(NSArray *)newFields {
    self = [super initWithPrompt:promptString fieldsArray:fields];
    if (self) {
        [self window]; // make sure the nib is loaded
        field = nil;
        [self setReplacePrompt:newPromptString];
        [self setReplaceFieldsArray:newFields];
        [self setDefaultButtonTitle:NSLocalizedString(@"Change", @"Button title")];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(replacePrompt);
    BDSKDESTROY(replaceFieldsArray);
    BDSKDESTROY(replaceField);
    [super dealloc];
}

- (void)windowDidLoad{
    BDSKFieldNameFormatter *formatter = [[[BDSKFieldNameFormatter alloc] init] autorelease];
    [formatter setKnownFieldNames:[self replaceFieldsArray]];
	[replaceFieldsComboBox setFormatter:formatter];
}

- (NSString *)windowNibName{
    return @"ChangeFieldSheet";
}

- (NSString *)replaceField{
    return replaceField;
}

- (void)setReplaceField:(NSString *)newNewField{
    if (replaceField != newNewField) {
        [replaceField release];
        replaceField = [newNewField copy];
    }
}

- (NSArray *)replaceFieldsArray{
    return replaceFieldsArray;
}

- (void)setReplaceFieldsArray:(NSArray *)array{
    if (replaceFieldsArray != array) {
        [replaceFieldsArray release];
        replaceFieldsArray = [array retain];
        [[replaceFieldsComboBox formatter] setKnownFieldNames:array];
    }
}

- (NSString *)replacePrompt{
    return replacePrompt;
}

- (void)setReplacePrompt:(NSString *)promptString{
    if (replacePrompt != promptString) {
        [replacePrompt release];
        replacePrompt = [promptString retain];
    }
}

- (void)prepare{
    NSRect fieldsFrame = [fieldsControl frame];
    NSRect oldPromptFrame = [promptField frame];
    NSRect replaceFieldsFrame = [replaceFieldsComboBox frame];
    NSRect oldReplacePromptFrame = [replacePromptField frame];
    [promptField sizeToFit];
    [replacePromptField sizeToFit];
    NSRect newPromptFrame = [promptField frame];
    NSRect newReplacePromptFrame = [replacePromptField frame];
    CGFloat dw;
    if (NSWidth(newPromptFrame) > NSWidth(newReplacePromptFrame)) {
        dw = NSWidth(newPromptFrame) - NSWidth(oldPromptFrame);
        newReplacePromptFrame.size.width = NSWidth(newPromptFrame);
        [replacePromptField setFrame:newReplacePromptFrame];
    } else {
        dw = NSWidth(newReplacePromptFrame) - NSWidth(oldReplacePromptFrame);
        newPromptFrame.size.width = NSWidth(newReplacePromptFrame);
        [promptField setFrame:newPromptFrame];
    }
    fieldsFrame.size.width -= dw;
    fieldsFrame.origin.x += dw;
    replaceFieldsFrame.size.width -= dw;
    replaceFieldsFrame.origin.x += dw;
    [fieldsControl setFrame:fieldsFrame];
    [replaceFieldsComboBox setFrame:replaceFieldsFrame];
}

@end

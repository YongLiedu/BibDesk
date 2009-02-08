//
//  BDSKFieldSheetController.m
//  BibDesk
//
//  Created by Christiaan Hofman on 3/18/06.
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

#import "BDSKFieldSheetController.h"
#import "BDSKFieldNameFormatter.h"

@implementation BDSKFieldSheetController

- (id)initWithPrompt:(NSString *)promptString fieldsArray:(NSArray *)fields{
    if (self = [super init]) {
        [self window]; // make sure the nib is loaded
        field = nil;
        [self setPrompt:promptString];
        [self setFieldsArray:fields];
    }
    return self;
}

- (void)dealloc {
    [prompt release];
    [fieldsArray release];
    [field release];
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

- (void)prepare{
    NSRect fieldsFrame = [fieldsControl frame];
    NSRect oldPromptFrame = [promptField frame];
    [promptField setStringValue:(prompt)? prompt : @""];
    [promptField sizeToFit];
    NSRect newPromptFrame = [promptField frame];
    float dw = NSWidth(newPromptFrame) - NSWidth(oldPromptFrame);
    fieldsFrame.size.width -= dw;
    fieldsFrame.origin.x += dw;
    [fieldsControl setFrame:fieldsFrame];
}

- (IBAction)dismiss:(id)sender{
    if ([sender tag] == NSCancelButton || [objectController commitEditing]) {
        [objectController setContent:nil];
        [super dismiss:sender];
    }
}

@end


@implementation BDSKAddFieldSheetController

- (void)awakeFromNib{
    BDSKFieldNameFormatter *formatter = [[[BDSKFieldNameFormatter alloc] init] autorelease];
	[(NSTextField *)fieldsControl setFormatter:formatter];
    [formatter setDelegate:self];
}

- (NSString *)windowNibName{
    return @"AddFieldSheet";
}

- (NSArray *)fieldNameFormatterKnownFieldNames:(BDSKFieldNameFormatter *)formatter {
    if (formatter == [(NSTextField *)fieldsControl formatter])
        return [self fieldsArray];
    else
        return nil;
}

@end


@implementation BDSKRemoveFieldSheetController

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

- (id)initWithPrompt:(NSString *)promptString fieldsArray:(NSArray *)fields addedPrompt:(NSString *)newPromptString addedFieldsArray:(NSArray *)newFields {
    if (self = [super initWithPrompt:promptString fieldsArray:fields]) {
        [self window]; // make sure the nib is loaded
        field = nil;
        [self setAddedPrompt:newPromptString];
        [self setAddedFieldsArray:newFields];
    }
    return self;
}

- (void)dealloc {
    [addedPrompt release];
    [addedFieldsArray release];
    [newField release];
    [super dealloc];
}

- (void)awakeFromNib{
    BDSKFieldNameFormatter *formatter = [[[BDSKFieldNameFormatter alloc] init] autorelease];
	[newFieldsComboBox setFormatter:formatter];
    [formatter setDelegate:self];
}

- (NSString *)windowNibName{
    return @"ChangeFieldSheet";
}

- (NSString *)newField{
    return newField;
}

- (void)setNewField:(NSString *)newNewField{
    if (newField != newNewField) {
        [newField release];
        newField = [newNewField copy];
    }
}

- (NSArray *)addedFieldsArray{
    return addedFieldsArray;
}

- (void)setAddedFieldsArray:(NSArray *)array{
    if (addedFieldsArray != array) {
        [addedFieldsArray release];
        addedFieldsArray = [array retain];
    }
}

- (NSString *)addedPrompt{
    return addedPrompt;
}

- (void)setAddedPrompt:(NSString *)promptString{
    if (addedPrompt != promptString) {
        [addedPrompt release];
        addedPrompt = [promptString retain];
    }
}

- (void)prepare{
    NSRect fieldsFrame = [fieldsControl frame];
    NSRect oldPromptFrame = [promptField frame];
    NSRect newFieldsFrame = [newFieldsComboBox frame];
    NSRect oldNewPromptFrame = [newPromptField frame];
    [promptField setStringValue:(prompt)? prompt : @""];
    [promptField sizeToFit];
    [newPromptField setStringValue:(addedPrompt)? addedPrompt : @""];
    [newPromptField sizeToFit];
    NSRect newPromptFrame = [promptField frame];
    NSRect newNewPromptFrame = [newPromptField frame];
    float dw;
    if (NSWidth(newPromptFrame) > NSWidth(newNewPromptFrame)) {
        dw = NSWidth(newPromptFrame) - NSWidth(oldPromptFrame);
        newNewPromptFrame.size.width = NSWidth(newPromptFrame);
        [newPromptField setFrame:newNewPromptFrame];
    } else {
        dw = NSWidth(newNewPromptFrame) - NSWidth(oldNewPromptFrame);
        newPromptFrame.size.width = NSWidth(newNewPromptFrame);
        [promptField setFrame:newPromptFrame];
    }
    fieldsFrame.size.width -= dw;
    fieldsFrame.origin.x += dw;
    newFieldsFrame.size.width -= dw;
    newFieldsFrame.origin.x += dw;
    [fieldsControl setFrame:fieldsFrame];
    [newFieldsComboBox setFrame:newFieldsFrame];
}

- (NSArray *)fieldNameFormatterKnownFieldNames:(BDSKFieldNameFormatter *)formatter {
    if (formatter == [(NSTextField *)newFieldsComboBox formatter])
        return [self addedFieldsArray];
    else
        return nil;
}

@end

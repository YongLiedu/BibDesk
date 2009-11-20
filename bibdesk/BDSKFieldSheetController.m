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
#import "NSWindowController_BDSKExtensions.h"

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
    CGFloat dw = NSWidth(newPromptFrame) - NSWidth(oldPromptFrame);
    fieldsFrame.size.width -= dw;
    fieldsFrame.origin.x += dw;
    [fieldsControl setFrame:fieldsFrame];
}

- (void)beginSheetModalForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)didEndSelector contextInfo:(void *)contextInfo {
    [self prepare];
    [super beginSheetModalForWindow:window modalDelegate:delegate didEndSelector:didEndSelector contextInfo:contextInfo];
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

- (id)initWithPrompt:(NSString *)promptString fieldsArray:(NSArray *)fields replacePrompt:(NSString *)newPromptString replaceFieldsArray:(NSArray *)newFields {
    if (self = [super initWithPrompt:promptString fieldsArray:fields]) {
        [self window]; // make sure the nib is loaded
        field = nil;
        [self setReplacePrompt:newPromptString];
        [self setReplaceFieldsArray:newFields];
    }
    return self;
}

- (void)dealloc {
    [replacePrompt release];
    [replaceFieldsArray release];
    [replaceField release];
    [super dealloc];
}

- (void)awakeFromNib{
    BDSKFieldNameFormatter *formatter = [[[BDSKFieldNameFormatter alloc] init] autorelease];
	[replaceFieldsComboBox setFormatter:formatter];
    [formatter setDelegate:self];
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
    [promptField setStringValue:(prompt)? prompt : @""];
    [promptField sizeToFit];
    [replacePromptField setStringValue:replacePrompt ?: @""];
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

- (NSArray *)fieldNameFormatterKnownFieldNames:(BDSKFieldNameFormatter *)formatter {
    if (formatter == [(NSTextField *)replaceFieldsComboBox formatter])
        return [self replaceFieldsArray];
    else
        return nil;
}

@end

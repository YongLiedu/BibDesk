//
//  BibItem_CiteKey.m
//  
//
//  Created by Christiaan Hofman on 11/4/04.
/*
 This software is Copyright (c) 2004-2010
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

#import "BibPref_CiteKey.h"
#import "BDSKStringConstants.h"
#import "BibItem.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKFormatParser.h"
#import "BDSKFormatStringFormatter.h"
#import "BDSKFormatStringFieldEditor.h"
#import "BDSKAppController.h"
#import "BDSKPreviewItem.h"
#import "BDSKTypeManager.h"

#define MAX_PREVIEW_WIDTH	481
#define MAX_FORMAT_WIDTH	266


@interface BibPref_CiteKey (Private)
- (void)setCiteKeyFormatInvalidWarning:(BOOL)set message:(NSString *)message;
- (void)updateFormatPresetUI;
- (void)updateFormatPreviewUI;
@end


@implementation BibPref_CiteKey

// these should correspond to the items in the popups set in IB
static NSString *presetFormatStrings[] = {@"%a1:%Y%u2", @"%a1:%Y%u0", @"%a33%y%m", @"%a1%Y%t15"};
static NSString *repositorySpecifierStrings[] = {@"", @"%a00", @"%A0", @"%p00", @"%P0", @"%t0", @"%T0", @"%Y", @"%y", @"%m", @"%k0", @"%f{}0", @"%w{}[ ]0", @"%s{}[][][]0", @"%c{}", @"%f{BibTeX Type}", @"%i{}0", @"%u0", @"%U0", @"%n0", @"%0", @"%%"};

- (void)dealloc{
    BDSKDESTROY(coloringEditor);
	[super dealloc];
}

- (void)updateUI {
    [citeKeyAutogenerateCheckButton setState:[sud boolForKey:BDSKCiteKeyAutogenerateKey] ? NSOnState : NSOffState];
    
    [citeKeyLowercaseCheckButton setState:[sud boolForKey:BDSKCiteKeyLowercaseKey] ? NSOnState : NSOffState];
    [formatCleanRadio selectCellWithTag:[sud integerForKey:BDSKCiteKeyCleanOptionKey]];
    
    [self updateFormatPresetUI];
}

- (void)awakeFromNib{
	BDSKFormatStringFormatter *formatter = [[BDSKFormatStringFormatter alloc] initWithField:BDSKCiteKeyString];
    [formatSheetField setFormatter:formatter];
	[formatter release];
    
	coloringEditor = [[BDSKFormatStringFieldEditor alloc] initWithFrame:[formatSheetField frame] parseField:BDSKCiteKeyString];
    
    [previewDisplay setStringValue:[[BDSKPreviewItem sharedItem] displayText]];
    [previewDisplay sizeToFit];
    
    [self updateUI];
}

- (void)defaultsDidRevert {
    // reset UI, but only if we loaded the nib
    if ([self isViewLoaded]) {
        [self updateUI];
    }
}

// sheet's delegate must be connected to file's owner in IB
- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject{
    return (anObject == formatSheetField ? coloringEditor : nil);
}

- (void)updateFormatPresetUI{
    NSInteger citeKeyPresetChoice = [sud integerForKey:BDSKCiteKeyFormatPresetKey];
	BOOL custom = (citeKeyPresetChoice == 0);
    
	[formatPresetPopUp selectItemAtIndex:[formatPresetPopUp indexOfItemWithTag:citeKeyPresetChoice]];
	[formatPresetSheetPopUp selectItemAtIndex:[formatPresetPopUp indexOfItemWithTag:citeKeyPresetChoice]];
    
	[formatSheetField setEnabled:custom];
	[formatRepositoryPopUp setHidden:NO == custom];
    
    [self updateFormatPreviewUI];
}

- (void)updateFormatPreviewUI{
    NSString *citeKeyFormat = [formatSheetField currentEditor] ? [formatSheetField stringValue] : [sud stringForKey:BDSKCiteKeyFormatKey];
	NSAttributedString *attrFormat = nil;
	NSString *error = nil;
	NSRect frame;
	
	// update the UI elements
	
	if ([BDSKFormatParser validateFormat:&citeKeyFormat attributedFormat:&attrFormat forField:BDSKCiteKeyString error:&error]) {
		[self setCiteKeyFormatInvalidWarning:NO message:nil];
		
		[citeKeyLine setStringValue:[[BDSKPreviewItem sharedItem] suggestedCiteKey]];
		[citeKeyLine sizeToFit];
		frame = [citeKeyLine frame];
		if (frame.size.width > MAX_PREVIEW_WIDTH) {
			frame.size.width = MAX_PREVIEW_WIDTH;
			[citeKeyLine setFrame:frame];
		}
		[[self view] setNeedsDisplay:YES];
	} else {
		[self setCiteKeyFormatInvalidWarning:YES message:error];
		[citeKeyLine setStringValue:NSLocalizedString(@"Invalid Format", @"Preview for invalid autogeneration format")];
		if (![formatSheet isVisible])
			[self showFormatSheet:self];
	}
	[formatField setAttributedStringValue:attrFormat];
	[formatField sizeToFit];
	frame = [formatField frame];
	if (frame.size.width > MAX_FORMAT_WIDTH) {
		frame.size.width = MAX_FORMAT_WIDTH;
		[formatField setFrame:frame];
	}
	[formatSheetField setAttributedStringValue:attrFormat];
}

- (IBAction)citeKeyHelp:(id)sender{
    NSString *helpBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"CitationKeys" inBook:helpBookName];
}

- (IBAction)formatHelp:(id)sender{
    NSString *helpBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"AutogenerationFormatSyntax" inBook:helpBookName];
}

- (IBAction)changeCiteKeyAutogenerate:(id)sender{
    [sud setBool:([sender state] == NSOnState) forKey:BDSKCiteKeyAutogenerateKey];
	[self updateFormatPreviewUI];
}

- (IBAction)changeCiteKeyLowercase:(id)sender{
    [sud setBool:([sender state] == NSOnState) forKey:BDSKCiteKeyLowercaseKey];
	[self updateFormatPreviewUI];
}

- (IBAction)setFormatCleanOption:(id)sender{
	[sud setInteger:[[sender selectedCell] tag] forKey:BDSKCiteKeyCleanOptionKey];
}

- (IBAction)citeKeyFormatAdd:(id)sender{
	NSInteger idx = [formatRepositoryPopUp indexOfSelectedItem];
	NSString *newSpecifier = repositorySpecifierStrings[idx];
    NSText *fieldEditor = [formatSheetField currentEditor];
	NSRange selRange;
	
	if ([NSString isEmptyString:newSpecifier])
		return;
	
    if (fieldEditor) {
		selRange = NSMakeRange([fieldEditor selectedRange].location + 2, [newSpecifier length] - 2);
		[fieldEditor insertText:newSpecifier];
	} else {
		NSString *formatString = [formatSheetField stringValue];
		selRange = NSMakeRange([formatString length] + 2, [newSpecifier length] - 2);
		[formatSheetField setStringValue:[formatString stringByAppendingString:newSpecifier]];
	}
	
	// this handles the new sud and the UI update
	[self citeKeyFormatChanged:sender];
	
	// select the 'arbitrary' numbers
	if ([newSpecifier isEqualToString:@"%0"] || [newSpecifier isEqualToString:@"%%"]) {
		selRange.location -= 1;
		selRange.length = 1;
	}
	else if ([newSpecifier isEqualToString:@"%f{}0"] || [newSpecifier isEqualToString:@"%w{}[ ]0"] || [newSpecifier isEqualToString:@"%s{}[][][]0"] || [newSpecifier isEqualToString:@"%c{}"] || [newSpecifier isEqualToString:@"%i{}0"]) {
        selRange.location += 1;
		selRange.length = 0;
	}
	else if ([newSpecifier isEqualToString:@"%f{BibTeX Type}"]) {
		selRange.location += 13;
		selRange.length = 0;
	}
	[formatSheetField selectText:self];
	[[formatSheetField currentEditor] setSelectedRange:selRange];
}

- (IBAction)citeKeyFormatChanged:(id)sender{
	NSInteger presetChoice = 0;
	NSString *formatString;
	
	if (sender == formatPresetPopUp || sender == formatPresetSheetPopUp) {
		presetChoice = [[sender selectedItem] tag];
		if (presetChoice == [sud integerForKey:BDSKCiteKeyFormatPresetKey]) 
			return; // nothing changed
		[sud setInteger:presetChoice forKey:BDSKCiteKeyFormatPresetKey];
		if (presetChoice > 0) {
			formatString = presetFormatStrings[presetChoice - 1];
		} else if (presetChoice == 0) {
			formatString = [formatSheetField stringValue];
			if (sender == formatPresetPopUp)
				[self showFormatSheet:self];
		} else {
			return;
		}
		// this one is always valid
		[sud setObject:formatString forKey:BDSKCiteKeyFormatKey];
	}
	else { //changed the text field or added from the repository
		NSString *error = nil;
		NSAttributedString *attrFormat = nil;
		formatString = [formatSheetField stringValue];
		//if ([formatString isEqualToString:[sud stringForKey:BDSKCiteKeyFormatKey]]) return; // nothing changed
		if ([BDSKFormatParser validateFormat:&formatString attributedFormat:&attrFormat forField:BDSKCiteKeyString error:&error]) {
			[sud setObject:formatString forKey:BDSKCiteKeyFormatKey];
		}
		else {
			[self setCiteKeyFormatInvalidWarning:YES message:error];
			[formatSheetField setAttributedStringValue:attrFormat];
			return;
		}
	}
	[[BDSKTypeManager sharedManager] setRequiredFieldsForCiteKey: [BDSKFormatParser requiredFieldsForFormat:formatString]];
	[self updateFormatPresetUI];
}

#pragma mark Format sheet stuff

- (IBAction)showFormatSheet:(id)sender{
	if ([[self view] window]) {
        [NSApp beginSheet:formatSheet
           modalForWindow:[[self view] window]
            modalDelegate:self
           didEndSelector:NULL
              contextInfo:nil];
    }
}

- (void)didSelect {
    [super didSelect];
    if ([formatWarningButton isHidden] == NO && [formatSheet isVisible] == NO)
        [self showFormatSheet:self];
}

- (void)didShowWindow {
    [super didShowWindow];
    [self didSelect];
}

- (BOOL)canCloseFormatSheet{
	NSString *formatString = [formatSheetField stringValue];
	NSString *error = nil;
	NSString *otherButton = nil;
	
	if ([formatSheet makeFirstResponder:nil])
		[formatSheet endEditingFor:nil];
	
	if ([BDSKFormatParser validateFormat:&formatString forField:BDSKCiteKeyString error:&error]) 
		return YES;
	
	formatString = [sud stringForKey:BDSKCiteKeyFormatKey];
	if ([BDSKFormatParser validateFormat:&formatString forField:BDSKCiteKeyString error:NULL]) {
		// The currently set cite-key format is valid, so we can keep it 
		otherButton = NSLocalizedString(@"Revert to Last", @"Button title");
	}
	
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Cite Key Format", @"Message in alert dialog when entering invalid cite key format") 
                                     defaultButton:NSLocalizedString(@"Keep Editing", @"Button title") 
                                   alternateButton:NSLocalizedString(@"Revert to Default", @"Button title") 
                                       otherButton:otherButton
                         informativeTextWithFormat:@"%@", error];
	NSInteger rv = [alert runModal];
	
	if (rv == NSAlertDefaultReturn){
		[formatSheetField selectText:self];
		return NO;
	} else if (rv == NSAlertAlternateReturn){
		formatString = [[sudc initialValues] objectForKey:BDSKCiteKeyFormatKey];
		[sud setObject:formatString forKey:BDSKCiteKeyFormatKey];
		[[BDSKTypeManager sharedManager] setRequiredFieldsForCiteKey: [BDSKFormatParser requiredFieldsForFormat:formatString]];
	}
	[self updateFormatPresetUI];
	return YES;
}

- (IBAction)closeFormatSheet:(id)sender{
	if (![self canCloseFormatSheet])
		return;
    [formatSheet orderOut:sender];
    [NSApp endSheet:formatSheet];
}

#pragma mark Invalid format warning stuff

- (IBAction)showCiteKeyFormatWarning:(id)sender{
	NSString *msg = [sender toolTip];
	
	if ([NSString isEmptyString:msg]) {
		msg = NSLocalizedString(@"The format string you entered contains invalid format specifiers.", @"Informative text in alert dialog");
	}
	
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Cite Key Format", @"Message in alert dialog when entering invalid cite key format") 
									 defaultButton:NSLocalizedString(@"OK", @"Button title") 
								   alternateButton:nil 
									   otherButton:nil 
						 informativeTextWithFormat:@"%@", msg];
	[alert beginSheetModalForWindow:formatSheet 
					  modalDelegate:nil
					 didEndSelector:NULL 
						contextInfo:NULL];
}

- (void)setCiteKeyFormatInvalidWarning:(BOOL)set message:(NSString *)message{
    [formatWarningButton setToolTip:set ? message : nil];
	[formatWarningButton setHidden:set == NO];
	[formatSheetField setTextColor:(set ? [NSColor redColor] : [NSColor blackColor])]; // overdone?
}

@end

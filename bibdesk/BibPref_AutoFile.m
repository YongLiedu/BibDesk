//
//  BibPref_AutoFile.m
//  BibDesk
//
//  Created by Michael McCracken on Wed Oct 08 2003.
/*
 This software is Copyright (c) 2003-2009
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BibPref_AutoFile.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKFormatParser.h"
#import "BDSKAppController.h"
#import "BDSKPreviewItem.h"
#import "BDSKStringConstants.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKTypeManager.h"

#define MAX_PREVIEW_WIDTH	501.0
#define MAX_FORMAT_WIDTH	288.0
#define USE_DOCUMENT_FOLDER NSLocalizedString(@"Use Document Folder", @"Placeholder string for Papers Folder")

@interface BDSKFolderPathFormatter : NSFormatter @end


@interface BibPref_AutoFile (Private)
- (void)setLocalUrlFormatInvalidWarning:(BOOL)set message:(NSString *)message;
- (void)updatePapersFolderUI;
- (void)updateFormatPresetUI;
- (void)updateFormatPreviewUI;
@end


@implementation BibPref_AutoFile

// these should correspond to the items in the popups set in IB
static NSString *presetFormatStrings[] = {@"%l%n0%e", @"%a1/%Y%u0%e", @"%a1/%T5%n0%e"};
static NSString *repositorySpecifierStrings[] = {@"", @"%a00", @"%A0", @"%p00", @"%P0", @"%t0", @"%T0", @"%Y", @"%y", @"%m", @"%k0", @"%L", @"%l", @"%e", @"%b", @"%f{}0", @"%w{}[ ]0", @"%s{}[][][]0", @"%c{}", @"%f{Cite Key}", @"%i{}0", @"%u0", @"%U0", @"%n0", @"%0", @"%%"};

- (void)dealloc{
    BDSKDESTROY(lastPapersFolderPath);
    BDSKDESTROY(coloringEditor);
	[super dealloc];
}

- (void)updateUI {
    [filePapersAutomaticallyCheckButton setState:[sud boolForKey:BDSKFilePapersAutomaticallyKey] ? NSOnState : NSOffState];
    [warnOnMoveFolderCheckButton setState:[sud boolForKey:BDSKWarnOnMoveFolderKey] ? NSOnState : NSOffState];
    
    [formatLowercaseCheckButton setState:[sud boolForKey:BDSKLocalFileLowercaseKey] ? NSOnState : NSOffState];
    [formatCleanRadio selectCellWithTag:[sud integerForKey:BDSKLocalFileCleanOptionKey]];
    
    [self updatePapersFolderUI];
    [self updateFormatPresetUI];
}

- (void)awakeFromNib{
	BDSKFormatStringFormatter *formatter = [[BDSKFormatStringFormatter alloc] initWithField:BDSKLocalFileString fileType:BDSKBibtexString];
    [formatSheetField setFormatter:formatter];
	[formatter release];
    
    coloringEditor = [[BDSKFormatStringFieldEditor alloc] initWithFrame:[formatSheetField frame] parseField:BDSKLocalFileString fileType:BDSKBibtexString];
    
    [papersFolderLocationTextField setFormatter:[[[BDSKFolderPathFormatter alloc] init] autorelease]];
    
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

- (BDSKPreferencePaneUnselectReply)shouldUnselect {
    if ([[[self view] window] attachedSheet])
        return BDSKPreferencePaneUnselectCancel;
    else
        return BDSKPreferencePaneUnselectNow;
}

- (BOOL)shouldCloseWindow {
    return [[[self view] window] attachedSheet] == nil;
}

// sheet's delegate must be connected to file's owner in IB
- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject{
    return (anObject == formatSheetField ? coloringEditor : nil);
}

- (void)updatePapersFolderUI{
	NSString *papersFolder = [[sud objectForKey:BDSKPapersFolderPathKey] stringByAbbreviatingWithTildeInPath];
	
    if ([NSString isEmptyString:papersFolder]) {
		[papersFolderLocationTextField setStringValue:USE_DOCUMENT_FOLDER];
		[papersFolderLocationTextField setEnabled:NO];
		[choosePapersFolderLocationButton setEnabled:NO];
		[papersFolderLocationRadio selectCellWithTag:1];
	} else {
		[papersFolderLocationTextField setStringValue:papersFolder];
		[papersFolderLocationTextField setEnabled:YES];
		[choosePapersFolderLocationButton setEnabled:YES];
		[papersFolderLocationRadio selectCellWithTag:0];
	}
    
    [self updateFormatPreviewUI];
}

- (void)updateFormatPresetUI{
    NSInteger formatPresetChoice = [sud integerForKey:BDSKLocalFileFormatPresetKey];
	BOOL custom = (formatPresetChoice == 0);
	
    [formatPresetPopUp selectItemAtIndex:[formatPresetPopUp indexOfItemWithTag:formatPresetChoice]];
	[formatPresetSheetPopUp selectItemAtIndex:[formatPresetPopUp indexOfItemWithTag:formatPresetChoice]];
	
    [formatSheetField setEnabled:custom];
	[formatRepositoryPopUp setHidden:NO == custom];
    
    [self updateFormatPreviewUI];
}

- (void)updateFormatPreviewUI{
    NSString *formatString = [formatSheetField currentEditor] ? [formatSheetField stringValue] : [sud stringForKey:BDSKLocalFileFormatKey];
	NSAttributedString *attrFormat = nil;
    NSString * error;
	NSRect frame;
	
	if ([BDSKFormatParser validateFormat:&formatString attributedFormat:&attrFormat forField:BDSKLocalFileString inFileType:BDSKBibtexString error:&error]) {
		[self setLocalUrlFormatInvalidWarning:NO message:nil];
		
        [previewTextField setStringValue:[[BDSKPreviewItem sharedItem] suggestedLocalFilePath]];
		[previewTextField sizeToFit];
		frame = [previewTextField frame];
		if (frame.size.width > MAX_PREVIEW_WIDTH) {
			frame.size.width = MAX_PREVIEW_WIDTH;
			[previewTextField setFrame:frame];
		}
		[[self view] setNeedsDisplay:YES];
	} else {
		[self setLocalUrlFormatInvalidWarning:YES message:error];
		[previewTextField setStringValue:NSLocalizedString(@"Invalid Format", @"Preview for invalid autogeneration format")];
		if (NO == [formatSheet isVisible])
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

- (IBAction)setPapersFolderPathFromTextField:(id)sender{
    [sud setObject:[[sender stringValue] stringByStandardizingPath] forKey:BDSKPapersFolderPathKey];
    [self updatePapersFolderUI];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if (returnCode == NSOKButton) {
		NSString *path = [[sheet filenames] objectAtIndex: 0];
		[sud setObject:path forKey:BDSKPapersFolderPathKey];
	}
	[self updatePapersFolderUI];
}

- (IBAction)choosePapersFolderLocationAction:(id)sender{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setCanChooseFiles:NO];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanCreateDirectories:YES];
	[openPanel setResolvesAliases:NO];
    [openPanel setPrompt:NSLocalizedString(@"Choose", @"Prompt for Choose panel")];
    [openPanel beginSheetForDirectory:nil 
								 file:nil
								types:nil
					   modalForWindow:[[self view] window] 
						modalDelegate:self 
					   didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) 
						  contextInfo:NULL];
}

- (IBAction)papersFolderLocationAction:(id)sender{
	if ([[sender selectedCell] tag] == 0) {
        if ([NSString isEmptyString:lastPapersFolderPath]) {
            [self choosePapersFolderLocationAction:sender];
        } else {
            [sud setObject:lastPapersFolderPath forKey:BDSKPapersFolderPathKey];
            [self updatePapersFolderUI];
        }
	} else {
        [lastPapersFolderPath release];
        lastPapersFolderPath = [[sud objectForKey:BDSKPapersFolderPathKey] retain];
		[sud setObject:@"" forKey:BDSKPapersFolderPathKey];
		[self updatePapersFolderUI];
	}
}

- (IBAction)toggleFilePapersAutomaticallyAction:(id)sender{
	[sud setBool:([filePapersAutomaticallyCheckButton state] == NSOnState)
			   forKey:BDSKFilePapersAutomaticallyKey];
}

- (IBAction)toggleWarnOnMoveFolderAction:(id)sender{
	[sud setBool:([warnOnMoveFolderCheckButton state] == NSOnState)
			   forKey:BDSKWarnOnMoveFolderKey];
}

// presently just used to display the warning if the path for autofile was invalid
- (BOOL)control:(NSControl *)control didFailToFormatString:(NSString *)string errorDescription:(NSString *)error{
    if(error != nil) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Entry", @"Message in alert dialog when entering invalid entry")
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"%@", error];
        [alert beginSheetModalForWindow:[[self view] window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
    }
    return NO;
}

#pragma mark Local-Url format stuff

- (IBAction)localUrlHelp:(id)sender{
    NSString *helpBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"AutoFiling" inBook:helpBookName];
}

- (IBAction)formatHelp:(id)sender{
    NSString *helpBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"AutogenerationFormatSyntax" inBook:helpBookName];
}

- (IBAction)changeLocalUrlLowercase:(id)sender{
    [sud setBool:([sender state] == NSOnState) forKey:BDSKLocalFileLowercaseKey];
	[self updateFormatPreviewUI];
}

- (IBAction)setFormatCleanOption:(id)sender{
	[sud setInteger:[[sender selectedCell] tag] forKey:BDSKLocalFileCleanOptionKey];
}

- (IBAction)localUrlFormatAdd:(id)sender{
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
	[self localUrlFormatChanged:sender];
	
	// select the 'arbitrary' numbers
	if ([newSpecifier isEqualToString:@"%0"] || [newSpecifier isEqualToString:@"%%"]) {
		selRange.location -= 1;
		selRange.length = 1;
	}
	else if ([newSpecifier isEqualToString:@"%f{}0"] || [newSpecifier isEqualToString:@"%w{}[ ]0"] || [newSpecifier isEqualToString:@"%s{}[][][]0"] || [newSpecifier isEqualToString:@"%c{}"] || [newSpecifier isEqualToString:@"%i{}0"]) {
		selRange.location += 1;
		selRange.length = 0;
	}
	else if ([newSpecifier isEqualToString:@"%f{Cite Key}"]) {
		selRange.location += 10;
		selRange.length = 0;
	}
	[formatSheetField selectText:self];
	[[formatSheetField currentEditor] setSelectedRange:selRange];
}

- (IBAction)localUrlFormatChanged:(id)sender{
	NSInteger presetChoice = 0;
	NSString *formatString;
	
	if (sender == formatPresetPopUp || sender == formatPresetSheetPopUp) {
		presetChoice = [[sender selectedItem] tag];
		if (presetChoice == [sud integerForKey:BDSKLocalFileFormatPresetKey]) 
			return; // nothing changed
		[sud setInteger:presetChoice forKey:BDSKLocalFileFormatPresetKey];
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
		[sud setObject:formatString forKey:BDSKLocalFileFormatKey];
	}
	else { //changed the text field or added from the repository
		NSString *error = nil;
		NSAttributedString *attrFormat = nil;
		formatString = [formatSheetField stringValue];
		//if ([formatString isEqualToString:[sud stringForKey:BDSKLocalFileFormatKey]]) return; // nothing changed
		if ([BDSKFormatParser validateFormat:&formatString attributedFormat:&attrFormat forField:BDSKLocalFileString inFileType:BDSKBibtexString error:&error]) {
			[sud setObject:formatString forKey:BDSKLocalFileFormatKey];
		}
		else {
			[self setLocalUrlFormatInvalidWarning:YES message:error];
			[formatSheetField setAttributedStringValue:attrFormat];
			return;
		}
	}
	[[BDSKTypeManager sharedManager] setRequiredFieldsForLocalFile: [BDSKFormatParser requiredFieldsForFormat:formatString]];
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
	
	if ([BDSKFormatParser validateFormat:&formatString forField:BDSKLocalFileString inFileType:BDSKBibtexString error:&error]) 
		return YES;
	
	formatString = [sud stringForKey:BDSKLocalFileFormatKey];
	if ([BDSKFormatParser validateFormat:&formatString forField:BDSKLocalFileString inFileType:BDSKBibtexString error:NULL]) {
		// The currently set local-url format is valid, so we can keep it 
		otherButton = NSLocalizedString(@"Revert to Last", @"Button title");
	}
	
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Local File Format", @"Message in alert dialog when entering invalid Local File format") 
                                     defaultButton:NSLocalizedString(@"Keep Editing", @"Button title") 
                                   alternateButton:NSLocalizedString(@"Revert to Default", @"Button title") 
                                       otherButton:otherButton
                         informativeTextWithFormat:@"%@", error];
	NSInteger rv = [alert runModal];
	
	if (rv == NSAlertDefaultReturn){
		[formatSheetField selectText:self];
		return NO;
	} else if (rv == NSAlertAlternateReturn){
		formatString = [[sudc initialValues] objectForKey:BDSKLocalFileFormatKey];
		[sud setObject:formatString forKey:BDSKLocalFileFormatKey];
		[[BDSKTypeManager sharedManager] setRequiredFieldsForLocalFile: [BDSKFormatParser requiredFieldsForFormat:formatString]];
	}
	[self updateFormatPreviewUI];
	return YES;
}

- (IBAction)closeFormatSheet:(id)sender{
    if([self canCloseFormatSheet]){
        [formatSheet orderOut:sender];
        [NSApp endSheet:formatSheet];
    }
}

#pragma mark Invalid format warning stuff

- (IBAction)showLocalUrlFormatWarning:(id)sender{
	NSString *msg = [sender toolTip];
	
	if ([NSString isEmptyString:msg]) {
		msg = NSLocalizedString(@"The format string you entered contains invalid format specifiers.", @"Informative text in alert dialog");
	}
	
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Local File Format", @"Message in alert dialog when entering invalid Local File format") 
									 defaultButton:NSLocalizedString(@"OK", @"Button title") 
								   alternateButton:nil 
									   otherButton:nil 
						 informativeTextWithFormat:@"%@", msg];
	[alert beginSheetModalForWindow:formatSheet 
					  modalDelegate:nil
					 didEndSelector:NULL 
						contextInfo:NULL];
}

- (void)setLocalUrlFormatInvalidWarning:(BOOL)set message:(NSString *)message{
    [formatWarningButton setToolTip:set ? message : nil];
	[formatWarningButton setHidden:set == NO];
	[formatSheetField setTextColor:(set ? [NSColor redColor] : [NSColor blackColor])]; // overdone?
}

@end

//
// Formatter for validating a directory in a text field
//

@implementation BDSKFolderPathFormatter

- (NSString *)stringForObjectValue:(id)obj{
    return obj;
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error{
    if ([string isEqualToString:USE_DOCUMENT_FOLDER]) {
        *obj = string;
        return YES;
    }
    
    BOOL isDir;
    // we want to return the original value if it's valid, not the expanded path; the action method should expand it
    NSString *pathString = [string stringByStandardizingPath];
    NS_DURING
        pathString = [[NSFileManager defaultManager] resolveAliasesInPath:pathString];
    NS_HANDLER
        NSLog(@"Ignoring exception %@ raised while resolving aliases in %@", [localException name], pathString);
    NS_ENDHANDLER
    if([[NSFileManager defaultManager] fileExistsAtPath:pathString isDirectory:&isDir] == NO){
        if(error)
            *error = [NSString stringWithFormat:NSLocalizedString(@"The directory \"%@\" does not exist.", @"Error description"), pathString];
        return NO;
    } else if(isDir == NO){
        if(error)
            *error = [NSString stringWithFormat:NSLocalizedString(@"The file \"%@\" is not a directory.", @"Error description"), pathString];
        return NO;
    } else
	    *obj = string;
    return YES;

}

@end



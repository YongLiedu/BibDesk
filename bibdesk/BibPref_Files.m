//
//  BibPref_Files.m
//  BibDesk
//
//  Created by Adam Maxwell on 01/02/05.
/*
 This software is Copyright (c) 2005-2010
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

 - Neither the name of Adam Maxwell nor the names of any
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

#import "BibPref_Files.h"
#import "BDSKStringConstants.h"
#import "BDSKStringEncodingManager.h"
#import "BDSKAppController.h"
#import "BDSKCharacterConversion.h"
#import "BDSKConverter.h"
#import "BDSKErrorObjectController.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"


@interface BibPref_Files (Private)
- (void)updateAutoSaveUI;
@end

@implementation BibPref_Files

- (void)awakeFromNib {
    [self updateAutoSaveUI];
    
    [encodingPopUp setEncoding:[sud integerForKey:BDSKDefaultStringEncodingKey]];
    [showErrorsCheckButton setState:[sud boolForKey:BDSKShowWarningsKey] ? NSOnState : NSOffState  ];	
    [shouldTeXifyCheckButton setState:[sud boolForKey:BDSKShouldTeXifyWhenSavingAndCopyingKey] ? NSOnState : NSOffState];
    [saveAnnoteAndAbstractAtEndButton setState:[sud boolForKey:BDSKSaveAnnoteAndAbstractAtEndOfItemKey] ? NSOnState : NSOffState];
    [useNormalizedNamesButton setState:[sud boolForKey:BDSKShouldSaveNormalizedAuthorNamesKey] ? NSOnState : NSOffState];
    [useTemplateFileButton setState:[sud boolForKey:BDSKShouldUseTemplateFileKey] ? NSOnState : NSOffState];
}

- (void)defaultsDidRevert {
    // reset UI, but only if we loaded the nib
    if ([self isViewLoaded]) {
        [self updateAutoSaveUI];
        [encodingPopUp setEncoding:[sud integerForKey:BDSKDefaultStringEncodingKey]];
        [showErrorsCheckButton setState:[sud boolForKey:BDSKShowWarningsKey] ? NSOnState : NSOffState  ];	
        [shouldTeXifyCheckButton setState:[sud boolForKey:BDSKShouldTeXifyWhenSavingAndCopyingKey] ? NSOnState : NSOffState];
        [saveAnnoteAndAbstractAtEndButton setState:[sud boolForKey:BDSKSaveAnnoteAndAbstractAtEndOfItemKey] ? NSOnState : NSOffState];
        [useNormalizedNamesButton setState:[sud boolForKey:BDSKShouldSaveNormalizedAuthorNamesKey] ? NSOnState : NSOffState];
        [useTemplateFileButton setState:[sud boolForKey:BDSKShouldUseTemplateFileKey] ? NSOnState : NSOffState];
    }
}

- (void)updateAutoSaveUI{
    // prefs time is in seconds, but we display in minutes
    NSTimeInterval saveDelay = [sud integerForKey:BDSKAutosaveTimeIntervalKey] / 60;
    [autosaveTimeField setIntegerValue:saveDelay];
    [autosaveTimeStepper setIntegerValue:saveDelay];
    
    BOOL shouldAutosave = [sud boolForKey:BDSKShouldAutosaveDocumentKey];
    [autosaveDocumentButton setState:shouldAutosave ? NSOnState : NSOffState];
    [autosaveTimeField setEnabled:shouldAutosave];
    [autosaveTimeStepper setEnabled:shouldAutosave];
}

- (IBAction)setDefaultStringEncoding:(id)sender{    
    [sud setInteger:[(BDSKEncodingPopUpButton *)sender encoding] forKey:BDSKDefaultStringEncodingKey];
}

- (IBAction)toggleShowWarnings:(id)sender{
    [sud setBool:([sender state] == NSOnState) ? YES : NO forKey:BDSKShowWarningsKey];
    if ([sender state] == NSOnState) {
        [[BDSKErrorObjectController sharedErrorObjectController] showWindow:self];
    }else{
        [[BDSKErrorObjectController sharedErrorObjectController] hideWindow:self];
    }        
}

- (IBAction)toggleShouldTeXify:(id)sender{
    [sud setBool:([sender state] == NSOnState ? YES : NO) forKey:BDSKShouldTeXifyWhenSavingAndCopyingKey];
}

- (IBAction)toggleShouldUseNormalizedNames:(id)sender{
    [sud setBool:([sender state] == NSOnState ? YES : NO) forKey:BDSKShouldSaveNormalizedAuthorNamesKey];
}

- (IBAction)toggleSaveAnnoteAndAbstractAtEnd:(id)sender{
    [sud setBool:([sender state] == NSOnState ? YES : NO) forKey:BDSKSaveAnnoteAndAbstractAtEndOfItemKey];
}

- (IBAction)toggleShouldUseTemplateFile:(id)sender{
    [sud setBool:([sender state] == NSOnState ? YES : NO) forKey:BDSKShouldUseTemplateFileKey];
}

- (IBAction)editTemplateFile:(id)sender{
    if(![[NSWorkspace sharedWorkspace] openFile:[[sud stringForKey:BDSKOutputTemplateFileKey] stringByExpandingTildeInPath]])
        if(![[NSWorkspace sharedWorkspace] openFile:[[sud stringForKey:BDSKOutputTemplateFileKey] stringByExpandingTildeInPath] withApplication:@"TextEdit"])
            NSBeep();
}

- (void)templateAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    if (returnCode == NSAlertAlternateReturn)
        return;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *templateFilePath = [[sud stringForKey:BDSKOutputTemplateFileKey] stringByExpandingTildeInPath];
    if([fileManager fileExistsAtPath:templateFilePath])
        [fileManager removeItemAtPath:templateFilePath error:NULL];
    // copy template.txt file from the bundle
    [fileManager copyItemAtPath:[[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:@"template.txt"]
                   toPath:templateFilePath error:NULL];
}

- (IBAction)resetTemplateFile:(id)sender{
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Reset the default template file to its original value?", @"Message in alert dialog when resetting bibtex template files") 
									 defaultButton:NSLocalizedString(@"OK", @"Button title") 
								   alternateButton:NSLocalizedString(@"Cancel", @"Button title") 
									   otherButton:nil 
						 informativeTextWithFormat:NSLocalizedString(@"Choosing Reset will restore the original content of the template file.", @"Informative text in alert dialog")];
	[alert beginSheetModalForWindow:[[self view] window] 
					  modalDelegate:self
					 didEndSelector:@selector(templateAlertDidEnd:returnCode:contextInfo:) 
						contextInfo:NULL];
}

- (IBAction)showConversionEditor:(id)sender{
	[[BDSKCharacterConversion sharedConversionEditor] beginSheetModalForWindow:[[self view] window]];
}

- (void)conversionsAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    if (returnCode == NSAlertAlternateReturn)
        return;
    NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *conversionsFilePath = [[fileManager currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:CHARACTER_CONVERSION_FILENAME];
    if([fileManager fileExistsAtPath:conversionsFilePath])
        [fileManager removeItemAtPath:conversionsFilePath error:NULL];
	// tell the converter to reload its dictionaries
	[[BDSKConverter sharedConverter] loadDict];
}

- (IBAction)resetConversions:(id)sender{
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Reset character conversions to their original value?", @"Message in alert dialog when resetting custom character conversions") 
									 defaultButton:NSLocalizedString(@"OK", @"Button title") 
								   alternateButton:NSLocalizedString(@"Cancel", @"Button title") 
									   otherButton:nil 
						 informativeTextWithFormat:NSLocalizedString(@"Choosing Reset will erase all custom character conversions.", @"Informative text in alert dialog")];
	[alert beginSheetModalForWindow:[[self view] window] 
					  modalDelegate:self
					 didEndSelector:@selector(conversionsAlertDidEnd:returnCode:contextInfo:) 
						contextInfo:NULL];
}

- (IBAction)setAutosaveTime:(id)sender;
{    
    NSTimeInterval saveDelay = [sender integerValue] * 60; // convert to seconds
    [sud setInteger:saveDelay forKey:BDSKAutosaveTimeIntervalKey];
    [[NSDocumentController sharedDocumentController] setAutosavingDelay:saveDelay];
    [self updateAutoSaveUI];
}

- (IBAction)setShouldAutosave:(id)sender;
{
    BOOL shouldSave = ([sender state] == NSOnState);
    [sud setBool:shouldSave forKey:BDSKShouldAutosaveDocumentKey];
    [[NSDocumentController sharedDocumentController] setAutosavingDelay:shouldSave ? [sud integerForKey:BDSKAutosaveTimeIntervalKey] : 0.0];
    [self updateAutoSaveUI];
}

@end

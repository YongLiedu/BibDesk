//
//  BibPref_Files.m
//  BibDesk
//
//  Created by Adam Maxwell on 01/02/05.
/*
 This software is Copyright (c) 2005-2009
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
#import <OmniFoundation/OmniFoundation.h>
#import "BDSKStringConstants.h"
#import "BDSKStringEncodingManager.h"
#import "BDSKAppController.h"
#import "BDSKCharacterConversion.h"
#import "BDSKConverter.h"
#import "BDSKErrorObjectController.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"

@implementation BibPref_Files

- (void)updateAutoSaveUI{
    // prefs time is in seconds, but we display in minutes
    NSTimeInterval saveDelay = [[NSUserDefaults standardUserDefaults] integerForKey:BDSKAutosaveTimeIntervalKey] / 60;
    [autosaveTimeField setIntValue:saveDelay];
    [autosaveTimeStepper setIntValue:saveDelay];
    
    BOOL shouldAutosave = [[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldAutosaveDocumentKey];
    [autosaveDocumentButton setState:shouldAutosave ? NSOnState : NSOffState];
    [autosaveTimeField setEnabled:shouldAutosave];
    [autosaveTimeStepper setEnabled:shouldAutosave];
}

- (void)updateUI{
    [self updateAutoSaveUI];
    
    [encodingPopUp setEncoding:[[NSUserDefaults standardUserDefaults] integerForKey:BDSKDefaultStringEncodingKey]];
    [showErrorsCheckButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKShowWarningsKey] ? NSOnState : NSOffState  ];	
    [shouldTeXifyCheckButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldTeXifyWhenSavingAndCopyingKey] ? NSOnState : NSOffState];
    [saveAnnoteAndAbstractAtEndButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKSaveAnnoteAndAbstractAtEndOfItemKey] ? NSOnState : NSOffState];
    [useNormalizedNamesButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldSaveNormalizedAuthorNamesKey] ? NSOnState : NSOffState];
    [useTemplateFileButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldUseTemplateFileKey] ? NSOnState : NSOffState];
}

- (IBAction)setDefaultStringEncoding:(id)sender{    
    [[NSUserDefaults standardUserDefaults] setInteger:[(BDSKEncodingPopUpButton *)sender encoding] forKey:BDSKDefaultStringEncodingKey];
}

- (IBAction)toggleShowWarnings:(id)sender{
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState) ? YES : NO forKey:BDSKShowWarningsKey];
    if ([sender state] == NSOnState) {
        [[BDSKErrorObjectController sharedErrorObjectController] showWindow:self];
    }else{
        [[BDSKErrorObjectController sharedErrorObjectController] hideWindow:self];
    }        
}

- (IBAction)toggleShouldTeXify:(id)sender{
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState ? YES : NO) forKey:BDSKShouldTeXifyWhenSavingAndCopyingKey];
}

- (IBAction)toggleShouldUseNormalizedNames:(id)sender{
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState ? YES : NO) forKey:BDSKShouldSaveNormalizedAuthorNamesKey];
}

- (IBAction)toggleSaveAnnoteAndAbstractAtEnd:(id)sender{
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState ? YES : NO) forKey:BDSKSaveAnnoteAndAbstractAtEndOfItemKey];
}

- (IBAction)toggleShouldUseTemplateFile:(id)sender{
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState ? YES : NO) forKey:BDSKShouldUseTemplateFileKey];
}

- (IBAction)editTemplateFile:(id)sender{
    if(![[NSWorkspace sharedWorkspace] openFile:[[[NSUserDefaults standardUserDefaults] stringForKey:BDSKOutputTemplateFileKey] stringByExpandingTildeInPath]])
        if(![[NSWorkspace sharedWorkspace] openFile:[[[NSUserDefaults standardUserDefaults] stringForKey:BDSKOutputTemplateFileKey] stringByExpandingTildeInPath] withApplication:@"TextEdit"])
            NSBeep();
}

- (void)templateAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    if (returnCode == NSAlertAlternateReturn)
        return;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *templateFilePath = [[[NSUserDefaults standardUserDefaults] stringForKey:BDSKOutputTemplateFileKey] stringByExpandingTildeInPath];
    if([fileManager fileExistsAtPath:templateFilePath])
        [fileManager removeFileAtPath:templateFilePath handler:nil];
    // copy template.txt file from the bundle
    [fileManager copyPath:[[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:@"template.txt"]
                   toPath:templateFilePath handler:nil];
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

- (void)conversionsAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    if (returnCode == NSAlertAlternateReturn)
        return;
    NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *conversionsFilePath = [[fileManager currentApplicationSupportPathForCurrentUser] stringByAppendingPathComponent:CHARACTER_CONVERSION_FILENAME];
    if([fileManager fileExistsAtPath:conversionsFilePath])
        [fileManager removeFileAtPath:conversionsFilePath handler:nil];
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
    NSTimeInterval saveDelay = [sender intValue] * 60; // convert to seconds
    [[NSUserDefaults standardUserDefaults] setInteger:saveDelay forKey:BDSKAutosaveTimeIntervalKey];
    [[NSDocumentController sharedDocumentController] setAutosavingDelay:saveDelay];
    [self updateAutoSaveUI];
}

- (IBAction)setShouldAutosave:(id)sender;
{
    BOOL shouldSave = ([sender state] == NSOnState);
    [[NSUserDefaults standardUserDefaults] setBool:shouldSave forKey:BDSKShouldAutosaveDocumentKey];
    [self updateAutoSaveUI];
}

@end

//  BibPref_General.m

//  Created by Michael McCracken on Sat Jun 01 2002.
/*
 This software is Copyright (c) 2002-2009
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

#import "BibPref_General.h"
#import <OmniFoundation/OmniFoundation.h>
#import "BDSKStringConstants.h"
#import "BDSKAppController.h"
#import "BDSKUpdateChecker.h"
#import "BDSKTemplate.h"
#import "BDAlias.h"

@implementation BibPref_General

- (void)awakeFromNib{
    [super awakeFromNib];
    [OFPreference addObserver:self selector:@selector(handleWarningPrefChanged:) forPreference:[OFPreference preferenceForKey:BDSKWarnOnDeleteKey]];
    [OFPreference addObserver:self selector:@selector(handleWarningPrefChanged:) forPreference:[OFPreference preferenceForKey:BDSKWarnOnRemovalFromGroupKey]];
    [OFPreference addObserver:self selector:@selector(handleWarningPrefChanged:) forPreference:[OFPreference preferenceForKey:BDSKWarnOnRenameGroupKey]];
    [OFPreference addObserver:self selector:@selector(handleWarningPrefChanged:) forPreference:[OFPreference preferenceForKey:BDSKWarnOnCiteKeyChangeKey]];
    [OFPreference addObserver:self selector:@selector(handleWarningPrefChanged:) forPreference:[OFPreference preferenceForKey:BDSKAskToTrashFilesKey]];
    [OFPreference addObserver:self selector:@selector(handleTemplatePrefsChanged:) forPreference:[OFPreference preferenceForKey:BDSKExportTemplateTree]];
    [self handleTemplatePrefsChanged:nil];
}

- (void)updateStartupBehaviorUI {
    int startupBehavior = [[defaults objectForKey:BDSKStartupBehaviorKey] intValue];
    [startupBehaviorRadio selectCellWithTag:startupBehavior];
    [defaultBibFileTextField setEnabled:startupBehavior == 3];
    [defaultBibFileButton setEnabled:startupBehavior == 3];
}

- (void)updateDefaultBibFileUI {
    NSData *aliasData = [defaults objectForKey:BDSKDefaultBibFileAliasKey];
    BDAlias *alias;
    if([aliasData length] && (alias = [BDAlias aliasWithData:aliasData]))
        [defaultBibFileTextField setStringValue:[[alias fullPath] stringByAbbreviatingWithTildeInPath]];
    else
        [defaultBibFileTextField setStringValue:@""];
}

- (void)updateWarningsUI {
    [warnOnDeleteButton setState:[defaults boolForKey:BDSKWarnOnDeleteKey] ? NSOnState : NSOffState];
    [warnOnRemovalFromGroupButton setState:[defaults boolForKey:BDSKWarnOnRemovalFromGroupKey] ? NSOnState : NSOffState];
    [warnOnRenameGroupButton setState:[defaults boolForKey:BDSKWarnOnRenameGroupKey] ? NSOnState : NSOffState];
    [warnOnGenerateCiteKeysButton setState:[defaults boolForKey:BDSKWarnOnCiteKeyChangeKey] ? NSOnState : NSOffState];
    [askToTrashFilesButton setState:[defaults boolForKey:BDSKAskToTrashFilesKey] ? NSOnState : NSOffState];
}

- (void)updateUI{
    [self updateStartupBehaviorUI];
    [self updateDefaultBibFileUI];
	[self updateWarningsUI];
    
    [editOnPasteButton setState:[defaults boolForKey:BDSKEditOnPasteKey] ? NSOnState : NSOffState];
    [checkForUpdatesButton selectItemWithTag:[defaults integerForKey:BDSKUpdateCheckIntervalKey]];
}

// tags correspond to BDSKUpdateCheckInterval enum
- (IBAction)changeUpdateInterval:(id)sender{
    BDSKUpdateCheckInterval interval = [[sender selectedItem] tag];
    [defaults setInteger:interval forKey:BDSKUpdateCheckIntervalKey];
    [defaults autoSynchronize];
    
    // an annoying dialog to be seen by annoying users...
    if (BDSKCheckForUpdatesNever == interval || BDSKCheckForUpdatesMonthly == interval) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Are you sure this is wise?", @"Message in alert dialog when setting long auto-update interval") 
                                         defaultButton:nil alternateButton:nil otherButton:nil 
                             informativeTextWithFormat:NSLocalizedString(@"Some BibDesk users complain of too-frequent updates.  However, updates generally fix bugs that affect the integrity of your data.  If you value your data, a daily or weekly interval is a better choice.", @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:[controlBox window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
    }
}

- (IBAction)setAutoOpenFilePath:(id)sender{
    BDAlias *alias = [BDAlias aliasWithPath:[[sender stringValue] stringByStandardizingPath]];
    if(alias)
        [defaults setObject:[alias aliasData] forKey:BDSKDefaultBibFileAliasKey];
    [self updateDefaultBibFileUI];
    [defaults autoSynchronize];
}

- (IBAction)changeStartupBehavior:(id)sender{
    int n = [[sender selectedCell] tag];
    [defaults setObject:[NSNumber numberWithInt:n] forKey:BDSKStartupBehaviorKey];
    [self updateStartupBehaviorUI];
    [defaults autoSynchronize];
    if(n == 3 && [[defaultBibFileTextField stringValue] isEqualToString:@""])
        [self chooseAutoOpenFile:nil];
}

-(IBAction) chooseAutoOpenFile:(id) sender {
    NSOpenPanel * openPanel = [NSOpenPanel openPanel];
    [openPanel setPrompt:NSLocalizedString(@"Choose", @"Prompt for Choose panel")];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel beginSheetForDirectory:nil 
								 file:nil 
								types:[NSArray arrayWithObject:@"bib"] 
					   modalForWindow:[[BDSKPreferenceController sharedPreferenceController] window] 
						modalDelegate:self 
					   didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) 
						  contextInfo:NULL];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSCancelButton)
        return;
    
    BDAlias *alias = [BDAlias aliasWithURL:[sheet URL]];
    
    [defaults setObject:[alias aliasData] forKey:BDSKDefaultBibFileAliasKey];
    [defaults setObject:[NSNumber numberWithInt:3] forKey:BDSKStartupBehaviorKey];
    [self updateDefaultBibFileUI];
    [self updateStartupBehaviorUI];
    [defaults autoSynchronize];
}

- (IBAction)changeEmailTemplate:(id)sender{
    int idx = [sender indexOfSelectedItem];
    NSString *style = idx == 0 ? @"" : [sender titleOfSelectedItem];
    if ([style isEqualToString:[defaults stringForKey:BDSKEmailTemplateKey]] == NO) {
        [defaults setObject:style forKey:BDSKEmailTemplateKey];
        [defaults autoSynchronize];
    }
}

- (IBAction)changeEditOnPaste:(id)sender{
    [defaults setBool:([sender state] == NSOnState) forKey:BDSKEditOnPasteKey];
    [defaults autoSynchronize];
}

- (IBAction)changeWarnOnDelete:(id)sender{
    [defaults setBool:([sender state] == NSOnState) forKey:BDSKWarnOnDeleteKey];
    [defaults autoSynchronize];
}

- (IBAction)changeWarnOnRemovalFromGroup:(id)sender{
    [defaults setBool:([sender state] == NSOnState) forKey:BDSKWarnOnRemovalFromGroupKey];
    [defaults autoSynchronize];
}

- (IBAction)changeWarnOnRenameGroup:(id)sender{
    [defaults setBool:([sender state] == NSOnState) forKey:BDSKWarnOnRenameGroupKey];
    [defaults autoSynchronize];
}

- (IBAction)changeWarnOnGenerateCiteKeys:(id)sender{
    [defaults setBool:([sender state] == NSOnState) forKey:BDSKWarnOnCiteKeyChangeKey];
    [defaults autoSynchronize];
}

- (IBAction)changeAskToTrashFiles:(id)sender{
    [defaults setBool:([sender state] == NSOnState) forKey:BDSKAskToTrashFilesKey];
    [defaults autoSynchronize];
}

- (void)dealloc{
    [OFPreference removeObserver:self forPreference:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)handleWarningPrefChanged:(NSNotification *)notification {
    [self updateWarningsUI];
}

- (void)handleTemplatePrefsChanged:(NSNotification *)notification {
    NSString *currentStyle = [defaults stringForKey:BDSKEmailTemplateKey];
    NSArray *styles = [BDSKTemplate allStyleNames];
    [emailTemplatePopup removeAllItems];
    [emailTemplatePopup addItemWithTitle:NSLocalizedString(@"Default BibTeX Format", @"Popup menu title for email format")];
    [emailTemplatePopup addItemsWithTitles:styles];
    if ([NSString isEmptyString:currentStyle]) {
        [emailTemplatePopup selectItemAtIndex:0];
    } else if ([styles containsObject:currentStyle]) {
        [emailTemplatePopup selectItemWithTitle:currentStyle];
    } else {
        [emailTemplatePopup selectItemAtIndex:0];
        [defaults setObject:[styles objectAtIndex:0] forKey:BDSKEmailTemplateKey];
        [defaults autoSynchronize];
    }
}

@end

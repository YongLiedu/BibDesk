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
#import "BDSKStringConstants.h"
#import "BDSKAppController.h"
#import "BDSKUpdateChecker.h"
#import "BDSKTemplate.h"
#import "BDAlias.h"

static void *BDSKBibPrefGeneralDefaultsObservationContext = @"BDSKBibPrefGeneralDefaultsObservationContext";

@implementation BibPref_General

- (void)awakeFromNib{
    NSUserDefaultsController *sud = [NSUserDefaultsController sharedUserDefaultsController];
    [sud addObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnDeleteKey] options:0 context:BDSKBibPrefGeneralDefaultsObservationContext];
    [sud addObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnRemovalFromGroupKey] options:0 context:BDSKBibPrefGeneralDefaultsObservationContext];
    [sud addObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnRenameGroupKey] options:0 context:BDSKBibPrefGeneralDefaultsObservationContext];
    [sud addObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnCiteKeyChangeKey] options:0 context:BDSKBibPrefGeneralDefaultsObservationContext];
    [sud addObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKAskToTrashFilesKey] options:0 context:BDSKBibPrefGeneralDefaultsObservationContext];
    [sud addObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKExportTemplateTree] options:0 context:BDSKBibPrefGeneralDefaultsObservationContext];
    [self handleTemplatePrefsChanged];
    [self updateUI];
}

- (void)updateStartupBehaviorUI {
    int startupBehavior = [[[NSUserDefaults standardUserDefaults] objectForKey:BDSKStartupBehaviorKey] intValue];
    [startupBehaviorRadio selectCellWithTag:startupBehavior];
    [defaultBibFileTextField setEnabled:startupBehavior == 3];
    [defaultBibFileButton setEnabled:startupBehavior == 3];
}

- (void)updateDefaultBibFileUI {
    NSData *aliasData = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKDefaultBibFileAliasKey];
    BDAlias *alias;
    if([aliasData length] && (alias = [BDAlias aliasWithData:aliasData]))
        [defaultBibFileTextField setStringValue:[[alias fullPath] stringByAbbreviatingWithTildeInPath]];
    else
        [defaultBibFileTextField setStringValue:@""];
}

- (void)updateWarningsUI {
    [warnOnDeleteButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKWarnOnDeleteKey] ? NSOnState : NSOffState];
    [warnOnRemovalFromGroupButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKWarnOnRemovalFromGroupKey] ? NSOnState : NSOffState];
    [warnOnRenameGroupButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKWarnOnRenameGroupKey] ? NSOnState : NSOffState];
    [warnOnGenerateCiteKeysButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKWarnOnCiteKeyChangeKey] ? NSOnState : NSOffState];
    [askToTrashFilesButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKAskToTrashFilesKey] ? NSOnState : NSOffState];
}

- (void)updateUI{
    [self updateStartupBehaviorUI];
    [self updateDefaultBibFileUI];
	[self updateWarningsUI];
    
    [editOnPasteButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKEditOnPasteKey] ? NSOnState : NSOffState];
    [checkForUpdatesButton selectItemWithTag:[[NSUserDefaults standardUserDefaults] integerForKey:BDSKUpdateCheckIntervalKey]];
}

// tags correspond to BDSKUpdateCheckInterval enum
- (IBAction)changeUpdateInterval:(id)sender{
    BDSKUpdateCheckInterval interval = [[sender selectedItem] tag];
    [[NSUserDefaults standardUserDefaults] setInteger:interval forKey:BDSKUpdateCheckIntervalKey];
    
    // an annoying dialog to be seen by annoying users...
    if (BDSKCheckForUpdatesNever == interval || BDSKCheckForUpdatesMonthly == interval) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Are you sure this is wise?", @"Message in alert dialog when setting long auto-update interval") 
                                         defaultButton:nil alternateButton:nil otherButton:nil 
                             informativeTextWithFormat:NSLocalizedString(@"Some BibDesk users complain of too-frequent updates.  However, updates generally fix bugs that affect the integrity of your data.  If you value your data, a daily or weekly interval is a better choice.", @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:[[self view] window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
    }
}

- (IBAction)setAutoOpenFilePath:(id)sender{
    BDAlias *alias = [BDAlias aliasWithPath:[[sender stringValue] stringByStandardizingPath]];
    if(alias)
        [[NSUserDefaults standardUserDefaults] setObject:[alias aliasData] forKey:BDSKDefaultBibFileAliasKey];
    [self updateDefaultBibFileUI];
}

- (IBAction)changeStartupBehavior:(id)sender{
    int n = [[sender selectedCell] tag];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:n] forKey:BDSKStartupBehaviorKey];
    [self updateStartupBehaviorUI];
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
					   modalForWindow:[[self view] window] 
						modalDelegate:self 
					   didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) 
						  contextInfo:NULL];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSCancelButton)
        return;
    
    BDAlias *alias = [BDAlias aliasWithURL:[sheet URL]];
    
    [[NSUserDefaults standardUserDefaults] setObject:[alias aliasData] forKey:BDSKDefaultBibFileAliasKey];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:3] forKey:BDSKStartupBehaviorKey];
    [self updateDefaultBibFileUI];
    [self updateStartupBehaviorUI];
}

- (IBAction)changeEmailTemplate:(id)sender{
    int idx = [sender indexOfSelectedItem];
    NSString *style = idx == 0 ? @"" : [sender titleOfSelectedItem];
    if ([style isEqualToString:[[NSUserDefaults standardUserDefaults] stringForKey:BDSKEmailTemplateKey]] == NO) {
        [[NSUserDefaults standardUserDefaults] setObject:style forKey:BDSKEmailTemplateKey];
    }
}

- (IBAction)changeEditOnPaste:(id)sender{
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState) forKey:BDSKEditOnPasteKey];
}

- (IBAction)changeWarnOnDelete:(id)sender{
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState) forKey:BDSKWarnOnDeleteKey];
}

- (IBAction)changeWarnOnRemovalFromGroup:(id)sender{
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState) forKey:BDSKWarnOnRemovalFromGroupKey];
}

- (IBAction)changeWarnOnRenameGroup:(id)sender{
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState) forKey:BDSKWarnOnRenameGroupKey];
}

- (IBAction)changeWarnOnGenerateCiteKeys:(id)sender{
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState) forKey:BDSKWarnOnCiteKeyChangeKey];
}

- (IBAction)changeAskToTrashFiles:(id)sender{
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState) forKey:BDSKAskToTrashFilesKey];
}

- (void)dealloc{
    NSUserDefaultsController *sud = [NSUserDefaultsController sharedUserDefaultsController];
    @try {
        [sud removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnDeleteKey]];
        [sud removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnRemovalFromGroupKey]];
        [sud removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnRenameGroupKey]];
        [sud removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnCiteKeyChangeKey]];
        [sud removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKAskToTrashFilesKey]];
        [sud removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKExportTemplateTree]];
    }
    @catch (id e) {}
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)handleTemplatePrefsChanged {
    NSString *currentStyle = [[NSUserDefaults standardUserDefaults] stringForKey:BDSKEmailTemplateKey];
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
        [[NSUserDefaults standardUserDefaults] setObject:[styles objectAtIndex:0] forKey:BDSKEmailTemplateKey];
    }
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == BDSKBibPrefGeneralDefaultsObservationContext) {
        NSString *key = [keyPath substringFromIndex:7];
        if ([key isEqualToString:BDSKWarnOnDeleteKey] || [key isEqualToString:BDSKWarnOnRemovalFromGroupKey] || 
            [key isEqualToString:BDSKWarnOnRenameGroupKey] || [key isEqualToString:BDSKWarnOnCiteKeyChangeKey] || 
            [key isEqualToString:BDSKAskToTrashFilesKey]) {
            [self updateWarningsUI];
        } else if ([key isEqualToString:BDSKExportTemplateTree]) {
            [self handleTemplatePrefsChanged];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

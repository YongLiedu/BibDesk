//  BibPref_General.m

//  Created by Michael McCracken on Sat Jun 01 2002.
/*
 This software is Copyright (c) 2002-2011
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
#import "BDSKTemplate.h"
#import "BDAlias.h"
#import <Sparkle/Sparkle.h>

static char BDSKBibPrefGeneralDefaultsObservationContext;
static char BDSKBibPrefGeneralUpdaterObservationContext;


@interface BibPref_General (Private)
- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)updateUpdaterUI;
- (void)updateEmailTemplateUI;
- (void)updateStartupBehaviorUI;
- (void)updateDefaultBibFileUI;
- (void)updateWarningsUI;
@end


@implementation BibPref_General

- (void)awakeFromNib{
    [sudc addObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnDeleteKey] options:0 context:&BDSKBibPrefGeneralDefaultsObservationContext];
    [sudc addObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnRemovalFromGroupKey] options:0 context:&BDSKBibPrefGeneralDefaultsObservationContext];
    [sudc addObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnRenameGroupKey] options:0 context:&BDSKBibPrefGeneralDefaultsObservationContext];
    [sudc addObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnCiteKeyChangeKey] options:0 context:&BDSKBibPrefGeneralDefaultsObservationContext];
    [sudc addObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKAskToTrashFilesKey] options:0 context:&BDSKBibPrefGeneralDefaultsObservationContext];
    [sudc addObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKExportTemplateTree] options:0 context:&BDSKBibPrefGeneralDefaultsObservationContext];
    [[SUUpdater sharedUpdater] addObserver:self forKeyPath:@"automaticallyChecksForUpdates" options:0 context:&BDSKBibPrefGeneralUpdaterObservationContext];
    [[SUUpdater sharedUpdater] addObserver:self forKeyPath:@"updateCheckInterval" options:0 context:&BDSKBibPrefGeneralUpdaterObservationContext];
    [self updateEmailTemplateUI];
    [self updateStartupBehaviorUI];
    [self updateDefaultBibFileUI];
	[self updateWarningsUI];
	[self updateUpdaterUI];
    
    [editOnPasteButton setState:[sud boolForKey:BDSKEditOnPasteKey] ? NSOnState : NSOffState];
}

- (void)updateStartupBehaviorUI {
    NSInteger startupBehavior = [[sud objectForKey:BDSKStartupBehaviorKey] integerValue];
    [startupBehaviorRadio selectCellWithTag:startupBehavior];
    [defaultBibFileTextField setEnabled:startupBehavior == 3];
    [defaultBibFileButton setEnabled:startupBehavior == 3];
}

- (void)updateDefaultBibFileUI {
    NSData *aliasData = [sud objectForKey:BDSKDefaultBibFileAliasKey];
    BDAlias *alias;
    if([aliasData length] && (alias = [BDAlias aliasWithData:aliasData]))
        [defaultBibFileTextField setStringValue:[[alias fullPath] stringByAbbreviatingWithTildeInPath]];
    else
        [defaultBibFileTextField setStringValue:@""];
}

- (void)updateWarningsUI {
    [warnOnDeleteButton setState:[sud boolForKey:BDSKWarnOnDeleteKey] ? NSOnState : NSOffState];
    [warnOnRemovalFromGroupButton setState:[sud boolForKey:BDSKWarnOnRemovalFromGroupKey] ? NSOnState : NSOffState];
    [warnOnRenameGroupButton setState:[sud boolForKey:BDSKWarnOnRenameGroupKey] ? NSOnState : NSOffState];
    [warnOnGenerateCiteKeysButton setState:[sud boolForKey:BDSKWarnOnCiteKeyChangeKey] ? NSOnState : NSOffState];
    [askToTrashFilesButton setState:[sud boolForKey:BDSKAskToTrashFilesKey] ? NSOnState : NSOffState];
}

- (void)updateUpdaterUI {
    NSInteger interval = 0;
    if ([[SUUpdater sharedUpdater] automaticallyChecksForUpdates])
        interval = [[SUUpdater sharedUpdater] updateCheckInterval];
    if (NO == [checkForUpdatesButton selectItemWithTag:interval]) {
        NSInteger i, iMax = [checkForUpdatesButton numberOfItems];
        for (i = 1; i < iMax; i++) {
            if (interval > [[checkForUpdatesButton itemAtIndex:i] tag] / 2) {
                [checkForUpdatesButton selectItemAtIndex:i];
                break;
            }
        }
        if (i == iMax)
            [checkForUpdatesButton selectItemAtIndex:iMax - 1];
        [self changeUpdateInterval:checkForUpdatesButton];
    }
}

- (void)defaultsDidRevert {
    NSTimeInterval interval = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"SUScheduledCheckInterval"] doubleValue];
    [[SUUpdater sharedUpdater] setUpdateCheckInterval:interval];
    [[SUUpdater sharedUpdater] setAutomaticallyChecksForUpdates:interval > 0.0];
}


- (IBAction)changeUpdateInterval:(id)sender{
    NSInteger interval = [[sender selectedItem] tag];
    if (interval > 0)
        [[SUUpdater sharedUpdater] setUpdateCheckInterval:interval];
    [[SUUpdater sharedUpdater] setAutomaticallyChecksForUpdates:interval > 0];
}

- (IBAction)setAutoOpenFilePath:(id)sender{
    BDAlias *alias = [BDAlias aliasWithPath:[[sender stringValue] stringByStandardizingPath]];
    if(alias)
        [sud setObject:[alias aliasData] forKey:BDSKDefaultBibFileAliasKey];
    [self updateDefaultBibFileUI];
}

- (IBAction)changeStartupBehavior:(id)sender{
    NSInteger n = [[sender selectedCell] tag];
    [sud setObject:[NSNumber numberWithInteger:n] forKey:BDSKStartupBehaviorKey];
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

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSCancelButton)
        return;
    
    BDAlias *alias = [BDAlias aliasWithURL:[sheet URL]];
    
    [sud setObject:[alias aliasData] forKey:BDSKDefaultBibFileAliasKey];
    [sud setObject:[NSNumber numberWithInteger:3] forKey:BDSKStartupBehaviorKey];
    [self updateDefaultBibFileUI];
    [self updateStartupBehaviorUI];
}

- (IBAction)changeEmailTemplate:(id)sender{
    NSInteger idx = [sender indexOfSelectedItem];
    NSString *style = idx == 0 ? @"" : [sender titleOfSelectedItem];
    if ([style isEqualToString:[sud stringForKey:BDSKEmailTemplateKey]] == NO) {
        [sud setObject:style forKey:BDSKEmailTemplateKey];
    }
}

- (IBAction)changeEditOnPaste:(id)sender{
    [sud setBool:([sender state] == NSOnState) forKey:BDSKEditOnPasteKey];
}

- (IBAction)changeWarnOnDelete:(id)sender{
    [sud setBool:([sender state] == NSOnState) forKey:BDSKWarnOnDeleteKey];
}

- (IBAction)changeWarnOnRemovalFromGroup:(id)sender{
    [sud setBool:([sender state] == NSOnState) forKey:BDSKWarnOnRemovalFromGroupKey];
}

- (IBAction)changeWarnOnRenameGroup:(id)sender{
    [sud setBool:([sender state] == NSOnState) forKey:BDSKWarnOnRenameGroupKey];
}

- (IBAction)changeWarnOnGenerateCiteKeys:(id)sender{
    [sud setBool:([sender state] == NSOnState) forKey:BDSKWarnOnCiteKeyChangeKey];
}

- (IBAction)changeAskToTrashFiles:(id)sender{
    [sud setBool:([sender state] == NSOnState) forKey:BDSKAskToTrashFilesKey];
}

- (void)dealloc{
    @try {
        [sudc removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnDeleteKey]];
        [sudc removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnRemovalFromGroupKey]];
        [sudc removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnRenameGroupKey]];
        [sudc removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKWarnOnCiteKeyChangeKey]];
        [sudc removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKAskToTrashFilesKey]];
        [sudc removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKExportTemplateTree]];
        [[SUUpdater sharedUpdater] removeObserver:self forKeyPath:@"automaticallyChecksForUpdates"];
        [[SUUpdater sharedUpdater] removeObserver:self forKeyPath:@"updateCheckInterval"];
    }
    @catch (id e) {}
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)updateEmailTemplateUI {
    NSString *currentStyle = [sud stringForKey:BDSKEmailTemplateKey];
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
        [sud setObject:[styles objectAtIndex:0] forKey:BDSKEmailTemplateKey];
    }
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &BDSKBibPrefGeneralDefaultsObservationContext) {
        NSString *key = [keyPath substringFromIndex:7];
        if ([key isEqualToString:BDSKWarnOnDeleteKey] || [key isEqualToString:BDSKWarnOnRemovalFromGroupKey] || 
            [key isEqualToString:BDSKWarnOnRenameGroupKey] || [key isEqualToString:BDSKWarnOnCiteKeyChangeKey] || 
            [key isEqualToString:BDSKAskToTrashFilesKey]) {
            [self updateWarningsUI];
        } else if ([key isEqualToString:BDSKExportTemplateTree]) {
            [self updateEmailTemplateUI];
        }
    } else if (context == &BDSKBibPrefGeneralUpdaterObservationContext) {
        [self updateUpdaterUI];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

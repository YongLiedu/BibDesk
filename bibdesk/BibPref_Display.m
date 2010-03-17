//
//  BibPref_Display.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/25/05.
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

#import "BibPref_Display.h"
#import "BDSKTemplate.h"
#import "BibAuthor.h"
#import "BDSKStringConstants.h"
#import "BDSKPreferenceController.h"
#import "BDSKStringArrayFormatter.h"
#import "BDSKFontWell.h"


@interface BibPref_Display (Private)
- (void)updateFontDisplayUI;
- (void)updatePreviewDisplayUI;
- (void)updateAuthorNameDisplayUI;
- (void)updateSortWordsDisplayUI;
@end


@implementation BibPref_Display

- (void)awakeFromNib{
    [previewMaxNumberComboBox addItemsWithObjectValues:[NSArray arrayWithObjects:NSLocalizedString(@"All", @"Display all items in preview"), @"1", @"5", @"10", @"20", nil]];
    [ignoredSortTermsField setFormatter:[[[BDSKStringArrayFormatter alloc] init] autorelease]];
    
    [displayGroupCountButton setState:[sud boolForKey:BDSKHideGroupCountKey] ? NSOffState : NSOnState];
    [self updateFontDisplayUI];
    [self updatePreviewDisplayUI];
    [self updateAuthorNameDisplayUI];
    [self updateSortWordsDisplayUI];
}

- (void)defaultsDidRevert {
    // reset UI, but only if we loaded the nib
    if ([self isViewLoaded]) {
        [displayGroupCountButton setState:[sud boolForKey:BDSKHideGroupCountKey] ? NSOffState : NSOnState];
        [self updateFontDisplayUI];
        [self updatePreviewDisplayUI];
        [self updateAuthorNameDisplayUI];
        [self updateSortWordsDisplayUI];
    }
}

- (void)updateFontDisplayUI{
    [publicationsFontWell setFontSize:[sud floatForKey:BDSKMainTableViewFontSizeKey]];
    [publicationsFontWell setFontName:[sud stringForKey:BDSKMainTableViewFontNameKey]];
    [groupsFontWell setFontSize:[sud floatForKey:BDSKGroupTableViewFontSizeKey]];
    [groupsFontWell setFontName:[sud stringForKey:BDSKGroupTableViewFontNameKey]];
    [personsFontWell setFontSize:[sud floatForKey:BDSKPersonTableViewFontSizeKey]];
    [personsFontWell setFontName:[sud stringForKey:BDSKPersonTableViewFontNameKey]];
    [abstractFontWell setFontSize:[sud floatForKey:BDSKEditorFontSizeKey]];
    [abstractFontWell setFontName:[sud stringForKey:BDSKEditorFontNameKey]];
}

- (void)updatePreviewDisplayUI{
    NSInteger maxNumber = [sud integerForKey:BDSKPreviewMaxNumberKey];
	if (maxNumber == 0)
		[previewMaxNumberComboBox setStringValue:NSLocalizedString(@"All",@"Display all items in preview")];
	else 
		[previewMaxNumberComboBox setIntegerValue:maxNumber];
}

- (void)updateAuthorNameDisplayUI{
    NSInteger mask = [sud integerForKey:BDSKAuthorNameDisplayKey];
    [authorFirstNameButton setState:(mask & BDSKAuthorDisplayFirstNameMask) ? NSOnState : NSOffState];
    [authorAbbreviateButton setState:(mask & BDSKAuthorAbbreviateFirstNameMask) ? NSOnState : NSOffState];
    [authorLastNameFirstButton setState:(mask & BDSKAuthorLastNameFirstMask) ? NSOnState : NSOffState];
    [authorAbbreviateButton setEnabled:mask & BDSKAuthorDisplayFirstNameMask];
    [authorLastNameFirstButton setEnabled:mask & BDSKAuthorDisplayFirstNameMask];
}

- (void)updateSortWordsDisplayUI{
    [ignoredSortTermsField setObjectValue:[sud stringArrayForKey:BDSKIgnoredSortTermsKey]];
}

- (IBAction)changePreviewMaxNumber:(id)sender{
    NSInteger maxNumber = [[[sender cell] objectValueOfSelectedItem] integerValue]; // returns 0 if not a number (as in @"All")
    if(maxNumber != [sud integerForKey:BDSKPreviewMaxNumberKey]){
		[sud setInteger:maxNumber forKey:BDSKPreviewMaxNumberKey];
		[[NSNotificationCenter defaultCenter] postNotificationName:BDSKPreviewDisplayChangedNotification object:nil];
	}
}

- (IBAction)changeIgnoredSortTerms:(id)sender{
    [sud setObject:[sender objectValue] forKey:BDSKIgnoredSortTermsKey];
    CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(), CFSTR("BDSKIgnoredSortTermsChangedNotification"), NULL, NULL, FALSE);
}

- (IBAction)changeDisplayGroupCount:(id)sender{
    [sud setBool:[sender state] == NSOffState forKey:BDSKHideGroupCountKey];
}

- (IBAction)changeAuthorDisplay:(id)sender;
{
    NSInteger itemMask = 1 << [sender tag];
    NSInteger prefMask = [sud integerForKey:BDSKAuthorNameDisplayKey];
    if([sender state] == NSOnState)
        prefMask |= itemMask;
    else
        prefMask &= ~itemMask;
    [sud setInteger:prefMask forKey:BDSKAuthorNameDisplayKey];
    [self updateAuthorNameDisplayUI];
}

- (IBAction)changePublicationsFont:(id)sender {
    [sud setFloat:[sender fontSize] forKey:BDSKMainTableViewFontSizeKey];
    [sud setObject:[sender fontName] forKey:BDSKMainTableViewFontNameKey];
}

- (IBAction)changeGroupsFont:(id)sender {
    [sud setFloat:[sender fontSize] forKey:BDSKGroupTableViewFontSizeKey];
    [sud setObject:[sender fontName] forKey:BDSKGroupTableViewFontNameKey];
}

- (IBAction)changePersonsFont:(id)sender {
    [sud setFloat:[sender fontSize] forKey:BDSKPersonTableViewFontSizeKey];
    [sud setObject:[sender fontName] forKey:BDSKPersonTableViewFontNameKey];
}

- (IBAction)changeAbstractFont:(id)sender {
    [sud setFloat:[sender fontSize] forKey:BDSKEditorFontNameKey];
    [sud setObject:[sender fontName] forKey:BDSKEditorFontNameKey];
}

- (BDSKFontWell *)activeFontWell{
    for (BDSKFontWell *fontWell in [NSArray arrayWithObjects:publicationsFontWell, groupsFontWell, personsFontWell, abstractFontWell, nil]) {
        if ([fontWell isActive])
            return fontWell;
    }
    return nil;
}

- (void)changeFont:(id)sender{
    [[self activeFontWell] changeFontFromFontManager:sender];
}

- (void)deactivateFontWells {
    [[self activeFontWell] deactivate];
}

- (void)handleWindowDidResignMain:(NSNotification *)notification{
    [self deactivateFontWells];
}

- (void)didSelect{
    [super didSelect];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleWindowDidResignMain:)
                                                 name:NSWindowDidResignMainNotification
                                               object:[[self view] window]];
}

- (void)willUnselect{
    [super willUnselect];
    [self deactivateFontWells];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSWindowDidResignMainNotification
                                                  object:[[self view] window]];
    
}

- (void)didShowWindow {
    [super didShowWindow];
    [self didSelect];
}

- (void)willCloseWindow {
    [super willCloseWindow];
    [self willUnselect];
}

@end


@implementation BDSKPreferenceController (BDSKFontExtension)

- (void)changeFont:(id)sender{
    if ([[self selectedPane] respondsToSelector:@selector(changeFont:)])
        [(id)[self selectedPane] performSelector:@selector(changeFont:) withObject:sender];
}

@end


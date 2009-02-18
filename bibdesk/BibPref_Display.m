//
//  BibPref_Display.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/25/05.
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

#import "BibPref_Display.h"
#import "BDSKTemplate.h"
#import "BibAuthor.h"
#import "BDSKStringConstants.h"
#import "BDSKPreferenceController.h"


@implementation BibPref_Display

- (void)awakeFromNib{
    [previewMaxNumberComboBox addItemsWithObjectValues:[NSArray arrayWithObjects:NSLocalizedString(@"All", @"Display all items in preview"), @"1", @"5", @"10", @"20", nil]];
}

- (void)updatePreviewDisplayUI{
    int maxNumber = [[NSUserDefaults standardUserDefaults] integerForKey:BDSKPreviewMaxNumberKey];
	if (maxNumber == 0)
		[previewMaxNumberComboBox setStringValue:NSLocalizedString(@"All",@"Display all items in preview")];
	else 
		[previewMaxNumberComboBox setIntValue:maxNumber];
}

- (void)updateAuthorNameDisplayUI{
    int mask = [[NSUserDefaults standardUserDefaults] integerForKey:BDSKAuthorNameDisplayKey];
    [authorFirstNameButton setState:(mask & BDSKAuthorDisplayFirstNameMask) ? NSOnState : NSOffState];
    [authorAbbreviateButton setState:(mask & BDSKAuthorAbbreviateFirstNameMask) ? NSOnState : NSOffState];
    [authorLastNameFirstButton setState:(mask & BDSKAuthorLastNameFirstMask) ? NSOnState : NSOffState];
    [authorAbbreviateButton setEnabled:mask & BDSKAuthorDisplayFirstNameMask];
    [authorLastNameFirstButton setEnabled:mask & BDSKAuthorDisplayFirstNameMask];
}

- (void)updateUI{
    [self updatePreviewDisplayUI];
    [self updateAuthorNameDisplayUI];
}    

- (IBAction)changePreviewMaxNumber:(id)sender{
    int maxNumber = [[[sender cell] objectValueOfSelectedItem] intValue]; // returns 0 if not a number (as in @"All")
    if(maxNumber != [[NSUserDefaults standardUserDefaults] integerForKey:BDSKPreviewMaxNumberKey]){
		[[NSUserDefaults standardUserDefaults] setInteger:maxNumber forKey:BDSKPreviewMaxNumberKey];
		[[NSNotificationCenter defaultCenter] postNotificationName:BDSKPreviewDisplayChangedNotification object:nil];
	}
}

//
// sorting prefs code
//

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    return [[[NSUserDefaults standardUserDefaults] arrayForKey:BDSKIgnoredSortTermsKey] objectAtIndex:rowIndex];
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [[[NSUserDefaults standardUserDefaults] arrayForKey:BDSKIgnoredSortTermsKey] count];
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    NSMutableArray *mutableArray = [[[NSUserDefaults standardUserDefaults] arrayForKey:BDSKIgnoredSortTermsKey] mutableCopy];
    [mutableArray replaceObjectAtIndex:rowIndex withObject:anObject];
    [[NSUserDefaults standardUserDefaults] setObject:mutableArray forKey:BDSKIgnoredSortTermsKey];
    [mutableArray release];
    CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(), CFSTR("BDSKIgnoredSortTermsChangedNotification"), NULL, NULL, FALSE);
}

- (IBAction)addTerm:(id)sender
{
    NSMutableArray *mutableArray = [[[NSUserDefaults standardUserDefaults] arrayForKey:BDSKIgnoredSortTermsKey] mutableCopy];
    if(!mutableArray)
        mutableArray = [[NSMutableArray alloc] initWithCapacity:1];
    [mutableArray addObject:NSLocalizedString(@"Edit or delete this text", @"")];
    [[NSUserDefaults standardUserDefaults] setObject:mutableArray forKey:BDSKIgnoredSortTermsKey];
    [tableView reloadData];
    [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[mutableArray count] - 1] byExtendingSelection:NO];
    [tableView editColumn:0 row:[tableView selectedRow] withEvent:nil select:YES];
    [mutableArray release];
    CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(), CFSTR("BDSKIgnoredSortTermsChangedNotification"), NULL, NULL, FALSE);
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    [removeButton setEnabled:([tableView numberOfSelectedRows] > 0)];
}

- (IBAction)removeSelectedTerm:(id)sender
{
    [[[self view] window] makeFirstResponder:tableView];  // end editing 
    NSMutableArray *mutableArray = [[[NSUserDefaults standardUserDefaults] arrayForKey:BDSKIgnoredSortTermsKey] mutableCopy];
    
    int selRow = [tableView selectedRow];
    NSAssert(selRow >= 0, @"row must be selected in order to delete");
    
    [mutableArray removeObjectAtIndex:selRow];
    [[NSUserDefaults standardUserDefaults] setObject:mutableArray forKey:BDSKIgnoredSortTermsKey];
    [mutableArray release];
    [tableView reloadData];
    CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(), CFSTR("BDSKIgnoredSortTermsChangedNotification"), NULL, NULL, FALSE);
}

- (IBAction)changeAuthorDisplay:(id)sender;
{
    int itemMask = 1 << [sender tag];
    int prefMask = [[NSUserDefaults standardUserDefaults] integerForKey:BDSKAuthorNameDisplayKey];
    if([sender state] == NSOnState)
        prefMask |= itemMask;
    else
        prefMask &= ~itemMask;
    [[NSUserDefaults standardUserDefaults] setInteger:prefMask forKey:BDSKAuthorNameDisplayKey];
    [self updateAuthorNameDisplayUI];
}


- (NSFont *)currentFont{
    NSString *fontNameKey = nil;
    NSString *fontSizeKey = nil;
    switch ([fontElementPopup indexOfSelectedItem]) {
        case 0:
            fontNameKey = BDSKMainTableViewFontNameKey;
            fontSizeKey = BDSKMainTableViewFontSizeKey;
            break;
        case 1:
            fontNameKey = BDSKGroupTableViewFontNameKey;
            fontSizeKey = BDSKGroupTableViewFontSizeKey;
            break;
        case 2:
            fontNameKey = BDSKPersonTableViewFontNameKey;
            fontSizeKey = BDSKPersonTableViewFontSizeKey;
            break;
        case 3:
            fontNameKey = BDSKEditorFontNameKey;
            fontSizeKey = BDSKEditorFontSizeKey;
            break;
        default:
            return nil;
    }
    return [NSFont fontWithName:[[NSUserDefaults standardUserDefaults] objectForKey:fontNameKey] size:[[NSUserDefaults standardUserDefaults] floatForKey:fontSizeKey]];
}

- (void)setCurrentFont:(NSFont *)font{
    NSString *fontNameKey = nil;
    NSString *fontSizeKey = nil;
    switch ([fontElementPopup indexOfSelectedItem]) {
        case 0:
            fontNameKey = BDSKMainTableViewFontNameKey;
            fontSizeKey = BDSKMainTableViewFontSizeKey;
            break;
        case 1:
            fontNameKey = BDSKGroupTableViewFontNameKey;
            fontSizeKey = BDSKGroupTableViewFontSizeKey;
            break;
        case 2:
            fontNameKey = BDSKPersonTableViewFontNameKey;
            fontSizeKey = BDSKPersonTableViewFontSizeKey;
            break;
        case 3:
            fontNameKey = BDSKEditorFontNameKey;
            fontSizeKey = BDSKEditorFontSizeKey;
            break;
        default:
            return;
    }
    // set the name last, as that is observed for changes
    [[NSUserDefaults standardUserDefaults] setFloat:[font pointSize] forKey:fontSizeKey];
    [[NSUserDefaults standardUserDefaults] setObject:[font fontName] forKey:fontNameKey];
}

- (void)changeFont:(id)sender{
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	NSFont *font = [self currentFont] ?: [NSFont systemFontOfSize:[NSFont systemFontSize]];
    font = [fontManager convertFont:font];
    
    [self setCurrentFont:font];
}

- (IBAction)changeFontElement:(id)sender{
    [self updateFontPanel:nil];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:sender];
}

- (void)updateFontPanel:(NSNotification *)notification{
	NSFont *font = [self currentFont] ?: [NSFont systemFontOfSize:[NSFont systemFontSize]];
	[[NSFontManager sharedFontManager] setSelectedFont:font isMultiple:NO];
	[[NSFontManager sharedFontManager] setAction:@selector(localChangeFont:)];
}

- (void)resetFontPanel:(NSNotification *)notification{
	[[NSFontManager sharedFontManager] setAction:@selector(changeFont:)];
}

- (void)didSelect{
    [super didSelect];
    [self updateFontPanel:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateFontPanel:)
                                                 name:NSWindowDidBecomeMainNotification
                                               object:[[self view] window]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resetFontPanel:)
                                                 name:NSWindowDidResignMainNotification
                                               object:[[self view] window]];
}

- (void)willUnselect{
    [super willUnselect];
    [self resetFontPanel:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSWindowDidBecomeMainNotification
                                                  object:[[self view] window]];
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

- (void)localChangeFont:(id)sender{
    if ([[self selectedPane] respondsToSelector:@selector(changeFont:)])
        [(id)[self selectedPane] performSelector:@selector(changeFont:) withObject:sender];
}

@end


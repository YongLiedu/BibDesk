// BibPref_Cite.m
// BibDesk
// Created by Michael McCracken, 2002
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

#import "BibPref_Cite.h"
#import <OmniFoundation/OmniFoundation.h>
#import "BDSKTemplate.h"
#import "BibDocument.h"
#import "BDSKStringConstants.h"

#define MAX_PREVIEW_WIDTH	465.0

@implementation BibPref_Cite

- (void)awakeFromNib{
    [super awakeFromNib];
    
    BDSKDragCopyCiteKeyFormatter *formatter = [[BDSKDragCopyCiteKeyFormatter alloc] init];
    [citeStringField setFormatter:formatter];
    [citeStringField setDelegate:self];
    [formatter release];
    
    [self handleTemplatePrefsChangedNotification:nil];
    [OFPreference addObserver:self 
                     selector:@selector(handleTemplatePrefsChangedNotification:) 
                forPreference:[OFPreference preferenceForKey:BDSKExportTemplateTree]];
}

- (void)updateDragCopyUI{
    [defaultDragCopyPopup selectItemWithTag:[defaults integerForKey:BDSKDefaultDragCopyTypeKey]];
    [alternateDragCopyPopup selectItemWithTag:[defaults integerForKey:BDSKAlternateDragCopyTypeKey]];
    [defaultDragCopyTemplatePopup setEnabled:[defaults integerForKey:BDSKDefaultDragCopyTypeKey] == BDSKTemplateDragCopyType];
    [alternateDragCopyTemplatePopup setEnabled:[defaults integerForKey:BDSKAlternateDragCopyTypeKey] == BDSKTemplateDragCopyType];
}

- (void)updateCiteCommandUI{
    NSString *citeString = [defaults stringForKey:BDSKCiteStringKey];
	NSString *startCiteBracket = [defaults stringForKey:BDSKCiteStartBracketKey]; 
	NSString *endCiteBracket = [defaults stringForKey:BDSKCiteEndBracketKey]; 
	BOOL prependTilde = [defaults boolForKey:BDSKCitePrependTildeKey];
	NSString *startCite = [NSString stringWithFormat:@"%@\\%@%@", (prependTilde? @"~" : @""), citeString, startCiteBracket];
	
    [separateCiteCheckButton setState:[defaults boolForKey:BDSKSeparateCiteKey] ? NSOnState : NSOffState];
    [prependTildeCheckButton setState:[defaults boolForKey:BDSKCitePrependTildeKey] ? NSOnState : NSOffState];
    [citeBracketRadio selectCellWithTag:[[defaults objectForKey:BDSKCiteStartBracketKey] isEqualToString:@"{"] ? 1 : 2];
    [citeStringField setStringValue:[NSString stringWithFormat:@"\\%@", citeString]];
    if([separateCiteCheckButton state] == NSOnState){
        [citeBehaviorLine setStringValue:[NSString stringWithFormat:@"%@key1%@%@key2%@", startCite, endCiteBracket, startCite, endCiteBracket]];
	}else{
		[citeBehaviorLine setStringValue:[NSString stringWithFormat:@"%@key1,key2%@", startCite, endCiteBracket]];
	}
	[citeBehaviorLine sizeToFit];
	NSRect frame = [citeBehaviorLine frame];
	if (frame.size.width > MAX_PREVIEW_WIDTH) {
		frame.size.width = MAX_PREVIEW_WIDTH;
		[citeBehaviorLine setFrame:frame];
	}
	[controlBox setNeedsDisplay:YES];
}

- (void)updateUI{
    [self updateDragCopyUI];
    [self updateCiteCommandUI];
}

- (void)handleTemplatePrefsChangedNotification:(NSNotification *)notification{
    NSString *currentDefaultStyle = [defaults stringForKey:BDSKDefaultDragCopyTemplateKey];
    NSString *currentAlternateStyle = [defaults stringForKey:BDSKAlternateDragCopyTemplateKey];
    NSArray *styles = [BDSKTemplate allStyleNames];
    [defaultDragCopyTemplatePopup removeAllItems];
    [defaultDragCopyTemplatePopup addItemsWithTitles:styles];
    [alternateDragCopyTemplatePopup removeAllItems];
    [alternateDragCopyTemplatePopup addItemsWithTitles:styles];
    if ([styles containsObject:currentDefaultStyle]) {
        [defaultDragCopyTemplatePopup selectItemWithTitle:currentDefaultStyle];
    } else if ([styles count]) {
        [defaultDragCopyTemplatePopup selectItemAtIndex:0];
        currentDefaultStyle = [styles objectAtIndex:0];
        [defaults setObject:currentDefaultStyle forKey:BDSKDefaultDragCopyTemplateKey];
        [defaults autoSynchronize];
    }
    if ([styles containsObject:currentAlternateStyle]) {
        [alternateDragCopyTemplatePopup selectItemWithTitle:currentAlternateStyle];
    } else if ([styles count]) {
        [alternateDragCopyTemplatePopup selectItemAtIndex:0];
        currentAlternateStyle = [styles objectAtIndex:0];
        [defaults setObject:currentAlternateStyle forKey:BDSKAlternateDragCopyTemplateKey];
        [defaults autoSynchronize];
    }
}

- (IBAction)changeDefaultDragCopyFormat:(id)sender{
    [defaults setInteger:[[sender selectedItem] tag] forKey:BDSKDefaultDragCopyTypeKey];
    [self updateDragCopyUI];
    [defaults autoSynchronize];
}

- (IBAction)changeDefaultDragCopyTemplate:(id)sender{
    NSString *style = [sender title];
    if ([style isEqualToString:[defaults stringForKey:BDSKDefaultDragCopyTemplateKey]] == NO) {
        [defaults setObject:style forKey:BDSKDefaultDragCopyTemplateKey];
        [defaults autoSynchronize];
    }
}

- (IBAction)changeAlternateDragCopyFormat:(id)sender{
    [defaults setInteger:[[sender selectedItem] tag] forKey:BDSKAlternateDragCopyTypeKey];
    [self updateDragCopyUI];
    [defaults autoSynchronize];
}

- (IBAction)changeAlternateDragCopyTemplate:(id)sender{
    NSString *style = [sender title];
    if ([style isEqualToString:[defaults stringForKey:BDSKAlternateDragCopyTemplateKey]] == NO) {
        [defaults setObject:style forKey:BDSKAlternateDragCopyTemplateKey];
        [defaults autoSynchronize];
    }
}

- (IBAction)changeSeparateCite:(id)sender{
    [defaults setBool:([sender state] == NSOnState) forKey:BDSKSeparateCiteKey];
	[self updateCiteCommandUI];
    [defaults autoSynchronize];
}

- (IBAction)changePrependTilde:(id)sender{
    [defaults setBool:([sender state] == NSOnState) forKey:BDSKCitePrependTildeKey];
	[self updateCiteCommandUI];
    [defaults autoSynchronize];
}

- (IBAction)citeStringFieldChanged:(id)sender{
    [defaults setObject:[[sender stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\\"]]
                 forKey:BDSKCiteStringKey];
	[self updateCiteCommandUI];
    [defaults autoSynchronize];
}

- (IBAction)setCitationBracketStyle:(id)sender{
	// 1 - tex 2 - context
	int tag = [[sender selectedCell] tag];
	if(tag == 1){
		[defaults setObject:@"{" forKey:BDSKCiteStartBracketKey];
		[defaults setObject:@"}" forKey:BDSKCiteEndBracketKey];
	}else if(tag == 2){
		[defaults setObject:@"[" forKey:BDSKCiteStartBracketKey];
		[defaults setObject:@"]" forKey:BDSKCiteEndBracketKey];
	}
	[self updateCiteCommandUI];
    [defaults autoSynchronize];
}

- (BOOL)control:(NSControl *)control didFailToFormatString:(NSString *)string errorDescription:(NSString *)error{
    if(error != nil) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Entry", @"Message in alert dialog when entering invalid entry")
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"%@", error];
        [alert beginSheetModalForWindow:[[self controlBox] window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
    }
    return NO;
}

@end

#pragma mark -

@implementation BDSKDragCopyCiteKeyFormatter

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error{
    if([string containsString:@"~"]){
        // some people apparently can't see the checkbox for adding a tilde (bug #1422451)
        if(error) *error = NSLocalizedString(@"Use the checkbox below to prepend a tilde.", @"Error description");
        return NO;
    } else if([string isEqualToString:@""] || [string characterAtIndex:0] != 0x005C){ // backslash
        if(error) *error = NSLocalizedString(@"The key must begin with a backslash.", @"Error description");
        return NO;
    }
    if(obj) *obj = string;
    return YES;
}

- (NSString *)stringForObjectValue:(id)anObject{
    return anObject;
}

@end

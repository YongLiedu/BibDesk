//
//  BibPref_AutoFile.m
//  Bibdesk
//
//  Created by Michael McCracken on Wed Oct 08 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "BibPref_AutoFile.h"
#import "NSImage+Toolbox.h"
#import <Carbon/Carbon.h>

@implementation BibPref_AutoFile

- (void)updateUI{
    NSString *formatString = [defaults stringForKey:BDSKLocalUrlFormatKey];
    int formatPresetChoice = [defaults integerForKey:BDSKLocalUrlFormatPresetKey];
	BOOL custom = (formatPresetChoice == 0);
    NSString * error;
	
    [filePapersAutomaticallyCheckButton setState:[defaults integerForKey:BDSKFilePapersAutomaticallyKey]];

    [papersFolderLocationTextField setStringValue:[[defaults objectForKey:BDSKPapersFolderPathKey] stringByAbbreviatingWithTildeInPath]];

    [formatLowercaseCheckButton setState:[defaults integerForKey:BDSKLocalUrlLowercaseKey]];
	if ([[BDSKConverter sharedConverter] validateFormat:&formatString forField:BDSKLocalUrlString inFileType:BDSKBibtexString error:&error]) {
		[self setLocalUrlFormatInvalidWarning:NO message:nil];
		
		// use a BibItem with some data to build the preview local-url
		BibItem *tmpBI = [[BibItem alloc] init];
		[tmpBI setField:BDSKTitleString toValue:@"Bibdesk, a great application to manage your bibliographies"];
		[tmpBI setField:BDSKAuthorString toValue:@"McCracken, M. and Maxwell, A. and Howison, J. and Routley, M. and Spiegel, S.  and Porst, S. S. and Hofman, C. M."];
		[tmpBI setField:BDSKYearString toValue:@"2004"];
		[tmpBI setField:BDSKMonthString toValue:@"11"];
		[tmpBI setField:BDSKJournalString toValue:@"SourceForge"];
		[tmpBI setField:BDSKVolumeString toValue:@"1"];
		[tmpBI setField:BDSKPagesString toValue:@"96"];
		[tmpBI setField:BDSKKeywordsString toValue:@"Keyword1,Keyword2"];
		[tmpBI setField:BDSKLocalUrlString toValue:@"Local%20File%20Name.pdf"];
		[previewTextField setStringValue:[[tmpBI suggestedLocalUrl] stringByAbbreviatingWithTildeInPath]];
		[tmpBI release];
	} else {
		[self setLocalUrlFormatInvalidWarning:YES message:error];
		[previewTextField setStringValue:NSLocalizedString(@"Invalid Format", @"Local-url preview for invalid format")];
	}
	[formatPresetPopUp selectItemAtIndex:[formatPresetPopUp indexOfItemWithTag:formatPresetChoice]];
    [formatField setStringValue:formatString];
	[formatField setEnabled:custom];
	if([formatRepositoryPopUp respondsToSelector:@selector(setHidden:)])
	    [formatRepositoryPopUp setHidden:!custom];
	[formatRepositoryPopUp setEnabled:custom];
}

- (void)resignCurrentPreferenceClient{
	NSString *formatString = [formatField stringValue];
	NSString *error;
	NSString *alternateButton = nil;
	int rv;
	
	if (![[BDSKConverter sharedConverter] validateFormat:&formatString forField:BDSKLocalUrlString inFileType:BDSKBibtexString error:&error]) {
		formatString = [defaults stringForKey:BDSKLocalUrlFormatKey];
		if ([[BDSKConverter sharedConverter] validateFormat:&formatString forField:BDSKLocalUrlString inFileType:BDSKBibtexString error:NULL]) {
			// The currently set local-url format is valid, so we can keep it 
			alternateButton = NSLocalizedString(@"Revert to Last", @"Revert to Last Valid Local-Url Format");
		}
		rv = NSRunCriticalAlertPanel(NSLocalizedString(@"Invalid Local-Url Format",@""), 
									 @"%@",
									 NSLocalizedString(@"Revert to Default", @"Revert to Default Local-Url Format"), 
									 alternateButton, 
									 nil,
									 error, nil);
		if (rv == NSAlertDefaultReturn){
			formatString = [[[OFPreferenceWrapper sharedPreferenceWrapper] preferenceForKey:BDSKLocalUrlFormatKey] defaultObjectValue];
			[[OFPreferenceWrapper sharedPreferenceWrapper] setObject:formatString forKey:BDSKLocalUrlFormatKey];
			[[NSApp delegate] setRequiredFieldsForLocalUrl: [[BDSKConverter sharedConverter] requiredFieldsForFormat:formatString]];
		}
	}
}

- (IBAction)choosePapersFolderLocationAction:(id)sender{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setCanChooseFiles:NO];
	[openPanel setCanChooseDirectories:YES];
	if([openPanel respondsToSelector:@selector(setCanCreateDirectories:)]){
		[openPanel setCanCreateDirectories:YES];
	}
    [openPanel setPrompt:NSLocalizedString(@"Choose", @"Choose directory")];

	if ([openPanel runModalForTypes:nil] != NSOKButton)
	{
		return;
	}
	NSString *path = [[openPanel filenames] objectAtIndex: 0];
	[papersFolderLocationTextField setStringValue:[path stringByAbbreviatingWithTildeInPath]];
	[defaults setObject:path forKey:BDSKPapersFolderPathKey];
}

- (IBAction)toggleFilePapersAutomaticallyAction:(id)sender{
	[defaults setBool:[filePapersAutomaticallyCheckButton state]
			   forKey:BDSKFilePapersAutomaticallyKey];
}

#pragma mark Local-Url format stuff

- (IBAction)formatHelp:(id)sender{
	// Panther only
	//[[NSHelpManager sharedHelpManager] openHelpAnchor:@"citekeyFormat" inBook:@"BibDesk Help"];
	// ..or we need Carbon/AppleHelp.h
	AHLookupAnchor((CFStringRef)@"BibDesk Help",(CFStringRef)@"format");
}

- (IBAction)changeLocalUrlLowercase:(id)sender{
    [defaults setInteger:[sender state] forKey:BDSKLocalUrlLowercaseKey];
	[self updateUI];
}

- (IBAction)localUrlFormatAdd:(id)sender{
	NSArray *specifierStrings = [NSArray arrayWithObjects:@"", @"%a00", @"%A0", @"%t0", @"%T0", @"%Y", @"%y", @"%m", @"%k0", @"%L", @"%l", @"%e", @"%f{}0", @"%c{}", @"%r2", @"%R2", @"%d2", @"%u0", @"%U0", @"%n0", @"%0", @"%%", nil];
	NSString *newSpecifier = [specifierStrings objectAtIndex:[formatRepositoryPopUp indexOfSelectedItem]];
    NSText *fieldEditor = [formatField currentEditor];
	NSRange selRange;
	
	if (!newSpecifier || [newSpecifier isEqualToString:@""])
		return;
	
    if (fieldEditor) {
		selRange = NSMakeRange([fieldEditor selectedRange].location + 2, [newSpecifier length] - 2);
		[fieldEditor insertText:newSpecifier];
	} else {
		NSString *formatString = [formatField stringValue];
		selRange = NSMakeRange([formatString length] + 2, [newSpecifier length] - 2);
		[formatField setStringValue:[formatString stringByAppendingString:newSpecifier]];
	}
	
	// this handles the new defaults and the UI update
	[self localUrlFormatChanged:sender];
	
	// select the 'arbitrary' numbers
	if ([newSpecifier isEqualToString:@"%0"]) {
		selRange.location -= 1;
		selRange.length = 1;
	}
	else if ([newSpecifier isEqualToString:@"%f{}0"] || [newSpecifier isEqualToString:@"%c{}"]) {
		selRange.location += 1;
		selRange.length = 0;
	}
	[formatField selectText:self];
	[[formatField currentEditor] setSelectedRange:selRange];
}

- (IBAction)localUrlFormatChanged:(id)sender{
	int presetChoice = 0;
	NSString *formatString;
	
	if (sender == formatPresetPopUp) {
		presetChoice = [[formatPresetPopUp selectedItem] tag];
		if (presetChoice == [defaults integerForKey:BDSKLocalUrlFormatPresetKey]) 
			return; // nothing changed
		[defaults setInteger:presetChoice forKey:BDSKLocalUrlFormatPresetKey];
		switch (presetChoice) {
			case 1:
				formatString = @"%L";
				break;
			case 2:
				formatString = @"%l%n0%e";
				break;
			case 3:
				formatString = @"%a1/%Y%u0.pdf";
				break;
			case 4:
				formatString = @"%a1/%T5.pdf";
				break;
			default:
				formatString = [formatField stringValue];
		}
		// this one is always valid
		[defaults setObject:formatString forKey:BDSKLocalUrlFormatKey];
	}
	else { //changed the text field or added from the repository
		NSString *error;
		formatString = [formatField stringValue];
		//if ([formatString isEqualToString:[defaults stringForKey:BDSKLocalUrlFormatKey]]) return; // nothing changed
		if ([[BDSKConverter sharedConverter] validateFormat:&formatString forField:BDSKLocalUrlString inFileType:BDSKBibtexString error:&error]) {
			[defaults setObject:formatString forKey:BDSKLocalUrlFormatKey];
		}
		else {
			[self setLocalUrlFormatInvalidWarning:YES message:error];
			return;
		}
	}
	[[NSApp delegate] setRequiredFieldsForLocalUrl: [[BDSKConverter sharedConverter] requiredFieldsForFormat:formatString]];
	[self updateUI];
}

#pragma mark Invalid format warning stuff

- (IBAction)showLocalUrlFormatWarning:(id)sender{
	NSString *msg = [sender toolTip];
	int rv;
	
	if (msg == nil || [msg isEqualToString:@""]) {
		msg = NSLocalizedString(@"The format string you entered contains invalid format specifiers.",@"");
	}
	rv = NSRunCriticalAlertPanel(NSLocalizedString(@"",@""), 
								 @"%@",
								 NSLocalizedString(@"OK",@"OK"), nil, nil, 
								 msg, nil);
}

- (void)setLocalUrlFormatInvalidWarning:(BOOL)set message:message{
	if(set){
		[formatWarningButton setImage:[NSImage cautionIconImage]];
		[formatWarningButton setToolTip:message];
	}else{
		[formatWarningButton setImage:nil];
		[formatWarningButton setToolTip:NSLocalizedString(@"",@"")]; // @@ this should be nil?
	}
	[formatWarningButton setEnabled:set];
	[formatField setTextColor:(set ? [NSColor redColor] : [NSColor blackColor])]; // overdone?
}

@end

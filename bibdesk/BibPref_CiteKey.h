//
//  BibPref_CiteKey.h
//  
//
//  Created by Christiaan Hofman on 11/4/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BibPrefController.h"
#import "BibItem.h"
#import "BDSKConverter.h"

@interface BibPref_CiteKey : OAPreferenceClient
{
    IBOutlet NSTextField *citeKeyLine;
    IBOutlet NSTextField *formatField;
    IBOutlet NSPopUpButton *formatPresetPopUp;
    IBOutlet NSPopUpButton *formatRepositoryPopUp;
    IBOutlet NSButton *formatWarningButton;
	NSImage *cautionIconImage;
}

- (IBAction)citeKeyFormatChanged:(id)sender;
- (IBAction)citeKeyFormatAdd:(id)sender;
- (IBAction)citeKeyHelp:(id)sender;
- (void)updateUI;
- (BOOL)validateCiteKeyFormat:(NSString **)formatString;
- (void)setupCautionIcon;
- (IBAction)showCiteKeyFormatWarning:(id)sender;
- (void)setCiteKeyFormatInvalidWarning:(BOOL)set;

@end

//
//  BDSKPreviewTextView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 3/6/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "BDSKPreviewTextView.h"
#import "BibPrefController.h"


@implementation BDSKPreviewTextView

- (void)updateFontPanel {
    if ([[self window] firstResponder] == self) {
        NSString *fontName = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKPreviewPaneFontFamilyKey];
        float fontSize = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:BDSKPreviewPaneFontChangedNotification];
        [[NSFontManager sharedFontManager] setSelectedFont:[NSFont fontWithName:fontName size:fontSize] isMultiple:NO];
    }
}

- (void)changeFont:(id)sender {
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	NSFont *selectedFont = [fontManager selectedFont];
	if (selectedFont == nil)
		selectedFont = [NSFont systemFontOfSize:[NSFont systemFontSize]];
	NSFont *font = [fontManager convertFont:selectedFont];
    
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:[font familyName] forKey:BDSKPreviewPaneFontFamilyKey];
    [[OFPreferenceWrapper sharedPreferenceWrapper] setFloat:[font pointSize] forKey:BDSKPreviewBaseFontSizeKey];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKPreviewPaneFontChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKPreviewDisplayChangedNotification object:nil];
}

@end

//
//  BibPref_Files.h
//  Bibdesk
//
//  Created by Adam Maxwell on 01/02/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BibPrefController.h"


@interface BibPref_Files : OAPreferenceClient {
    IBOutlet NSMatrix *exportBibTeXAutomaticallyRadio;
    IBOutlet NSPopUpButton *encodingPopUp;
    IBOutlet NSMatrix *defaultParserRadio;
}

- (IBAction)setExportBibTeXAutomatically:(id)sender;
- (IBAction)setDefaultStringEncoding:(id)sender;
- (unsigned)tagForEncoding:(NSStringEncoding)encoding;
- (IBAction)setDefaultBibTeXParser:(id)sender;

@end

//
//  BibPref_Files.m
//  Bibdesk
//
//  Created by Adam Maxwell on 01/02/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BibPref_Files.h"


@implementation BibPref_Files

- (void)updateUI{
    OFPreferenceWrapper *prefs = [OFPreferenceWrapper sharedPreferenceWrapper];
    [exportBibTeXAutomaticallyRadio selectCellWithTag:( [prefs boolForKey:BDSKExportBibTeXWithBDSKDocument] ? 0 : 1)];
    [encodingPopUp selectItemWithTag:[self tagForEncoding:[prefs integerForKey:BDSKDefaultStringEncoding]]];
    [defaultParserRadio selectCellWithTag:( [prefs boolForKey:BDSKUseUnicodeBibTeXParser] ? 1 : 0 )];
}

- (IBAction)setExportBibTeXAutomatically:(id)sender{
    [[OFPreferenceWrapper sharedPreferenceWrapper] setInteger:( [[sender selectedCell] tag] == 0 ? YES : NO ) forKey:BDSKExportBibTeXWithBDSKDocument];
}

- (IBAction)setDefaultStringEncoding:(id)sender{
    NSStringEncoding encoding;
    int encodingTag = [encodingPopUp selectedTag];
    
    switch(encodingTag){
        
        case 1:
            // ISO Latin 1
            encoding = NSISOLatin1StringEncoding;
            break;
            
        case 2:
            // ISO Latin 2
            encoding = NSISOLatin2StringEncoding;
            
        case 3:
            // UTF 8
            encoding = NSUTF8StringEncoding;
            break;
        case 4:
            // MacRoman
            encoding = NSMacOSRomanStringEncoding;
            break;
            
        default:
            encoding = NSASCIIStringEncoding;
            
    }
    
    [[OFPreferenceWrapper sharedPreferenceWrapper] setInteger:encoding forKey:BDSKDefaultStringEncoding];    
}

- (unsigned)tagForEncoding:(NSStringEncoding)encoding{
    
    switch(encoding){
        
        case NSISOLatin1StringEncoding:
            return 1;
        case NSISOLatin2StringEncoding:
            return 2;
        case NSUTF8StringEncoding:
            return 3;
        case NSMacOSRomanStringEncoding:
        default:
            return 0;
    }
}

- (IBAction)setDefaultBibTeXParser:(id)sender{
    [[OFPreferenceWrapper sharedPreferenceWrapper] setBool:( [[sender selectedCell] tag] == 0 ? NO : YES ) forKey:BDSKUseUnicodeBibTeXParser];
    // NSLog(@"use unicode parser is %@", ( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKUseUnicodeBibTeXParser] ? @"YES" : @"NO" ) );
}
    

@end

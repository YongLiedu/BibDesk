//
//  BibPref_InputManager.h
//  Bibdesk
//
//  Created by Adam Maxwell on Fri Aug 27 2004.
//  Copyright (c) 2004 Adam R. Maxwell. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BibPrefController.h"

extern NSString *BDSKInputManagerID;

@interface BibPref_InputManager : OAPreferenceClient
{
    NSString *applicationSupportPath;
    NSString *inputManagerPath;
    IBOutlet NSTableView *appList;
    IBOutlet NSButton *enableButton;
    NSMutableArray *appListArray;
}

- (void)getIconAndBundleID;
- (IBAction)enableAutocompletion:(id)sender;
- (IBAction)addApplication:(id)sender;
- (IBAction)removeApplication:(id)sender;

@end

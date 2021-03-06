//
//  Controller.h
//  z3950Test
//
//  Created by Adam Maxwell on 12/25/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <yaz/ZOOMObjC.h>

@class ZOOMConnection;

@interface Controller : NSObject {
    IBOutlet NSSearchField *_searchField;
    IBOutlet NSTextView *_textView;
    IBOutlet NSPopUpButton *_popup;
    
    NSString *_hostname;
    NSString *_database;
    int _port;
    ZOOMSyntaxType _syntaxType;
    
    IBOutlet NSTextField *_addressField;
    IBOutlet NSTextField *_dbaseField;
    IBOutlet NSTextField *_portField;
    IBOutlet NSTextField *_userField;
    IBOutlet NSTextField *_passwordField;
    IBOutlet NSPopUpButton *_syntaxPopup;
    
    ZOOMConnection *_connection;
    NSString *_currentType;
    
    BOOL _connectionNeedsReset;
    
    IBOutlet NSPopUpButton *_charSetPopup;
    NSString *_currentCharSet;
    NSDictionary *_options;
}

- (IBAction)changeCharSet:(id)sender;
- (IBAction)search:(id)sender;
- (IBAction)changeType:(id)sender;
- (IBAction)changeAddress:(id)sender;
- (IBAction)changePort:(id)sender;
- (IBAction)changeDbase:(id)sender;
- (IBAction)changeUser:(id)sender;
- (IBAction)changePassword:(id)sender;
- (IBAction)changeSyntaxType:(id)sender;

@end

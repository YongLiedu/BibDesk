//
//  BibPref_Sharing.m
//  BibDesk
//
//  Created by Adam Maxwell on Fri Mar 31 2006.
//  Copyright (c) 2006 Adam R. Maxwell. All rights reserved.
/*
 This software is Copyright (c) 2006
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

#import "BibPref_Sharing.h"
#import "BibPrefController.h"
#import "BibDocument_Sharing.h"
#import <Security/Security.h>

@implementation BibPref_Sharing

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSharingNameChanged:) name:BDSKSharingNameChangedNotification object:nil];
    
    NSData *pwData = [BibDocument sharingPasswordForCurrentUserUnhashed];
    if(pwData != nil){
        NSString *pwString = [[NSString alloc] initWithData:pwData encoding:NSUTF8StringEncoding];
        [passwordField setStringValue:pwString];
        [pwString release];
    }    
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)handleSharingNameChanged:(NSNotification *)aNotification;
{
    if([aNotification object] != self)
        [self updateUI];
}

- (void)updateUI
{
    [enableSharingButton setState:[defaults boolForKey:BDSKShouldShareFilesKey] ? NSOnState : NSOffState];
    
    [enableBrowsingButton setState:[defaults boolForKey:BDSKShouldLookForSharedFilesKey] ? NSOnState : NSOffState];
    
    if(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_3){
        NSString *disabledTip = NSLocalizedString(@"Bonjour sharing is only supported on Mac OS X Tiger at this time.", @"");
        [enableSharingButton setEnabled:NO];
        [enableSharingButton setToolTip:disabledTip];
        [enableBrowsingButton setEnabled:NO];
        [enableBrowsingButton setToolTip:disabledTip];
    }
    
    [usePasswordButton setState:[defaults boolForKey:BDSKSharingRequiresPasswordKey] ? NSOnState : NSOffState];
    [passwordField setEnabled:[defaults boolForKey:BDSKSharingRequiresPasswordKey]];
    
    [sharedNameField setStringValue:[BibDocument sharingName]];
}

- (IBAction)togglePassword:(id)sender
{
    [defaults setBool:([sender state] == NSOnState) forKey:BDSKSharingRequiresPasswordKey];
    [self updateUI];
}

- (IBAction)changePassword:(id)sender
{
    const void *passwordData = NULL;
    SecKeychainItemRef itemRef = NULL;    
    const char *userName = [NSUserName() UTF8String];
    const char *serviceName = [[BibDocument serviceNameForKeychain] UTF8String];
    
    OSStatus err;
    
    NSString *password = [sender stringValue];
    NSParameterAssert(password != nil);
    
    UInt32 passwordLength = 0;
    err = SecKeychainFindGenericPassword(NULL, strlen(serviceName), serviceName, strlen(userName), userName, &passwordLength, (void **)&passwordData, &itemRef);
    if(err == noErr){
        // pw was on keychain, so change it
        SecKeychainItemFreeContent(NULL, (void *)passwordData);
        passwordData = NULL;
        
        passwordData = [password UTF8String];
        SecKeychainAttribute attrs[] = {
        { kSecAccountItemAttr, strlen(userName), (char *)userName },
        { kSecServiceItemAttr, strlen(serviceName), (char *)serviceName } };
        const SecKeychainAttributeList attributes = { sizeof(attrs) / sizeof(attrs[0]), attrs };
        
        err = SecKeychainItemModifyAttributesAndData(itemRef, &attributes, strlen(passwordData), passwordData);
    } else {
        // pw not on keychain, so add it
        passwordData = [password UTF8String];
        err = SecKeychainAddGenericPassword(NULL, strlen(serviceName), serviceName, strlen(userName), userName, strlen(passwordData), passwordData, &itemRef);    
    }
    
    NSAssert1(err == noErr, @"error %d occurred setting password", err);    
}

// setting to the empty string will restore the default
- (IBAction)changeSharedName:(id)sender
{
    [defaults setObject:[sender stringValue] forKey:BDSKSharingNameKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingNameChangedNotification object:self];
    [self updateUI];
}

- (IBAction)toggleBrowsing:(id)sender
{
    [defaults setBool:([sender state] == NSOnState) forKey:BDSKShouldLookForSharedFilesKey];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharedBrowsingChangedNotification object:self];
}

- (IBAction)toggleSharing:(id)sender
{
    [defaults setBool:([sender state] == NSOnState) forKey:BDSKShouldShareFilesKey];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingChangedNotification object:self];
}

@end

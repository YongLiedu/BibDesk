//
//  BibPref_Sharing.m
//  BibDesk
//
//  Created by Adam Maxwell on Fri Mar 31 2006.
//  Copyright (c) 2006 Adam R. Maxwell. All rights reserved.
/*
 This software is Copyright (c) 2006-2009
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
#import "BDSKStringConstants.h"
#import "BDSKSharingBrowser.h"
#import <Security/Security.h>
#import "BDSKSharingServer.h"
#import "BDSKPasswordController.h"


@interface BibPref_Sharing (Private)
- (void)updateSettingsUI;
- (void)updateNameUI;
- (void)updateStatusUI;
- (void)handleSharingNameChanged:(NSNotification *)aNotification;
- (void)handleSharingStatusChanged:(NSNotification *)aNotification;
- (void)handleClientConnectionsChanged:(NSNotification *)aNotification;
@end


@implementation BibPref_Sharing

- (void)updateUI {
    [enableSharingButton setState:[sud boolForKey:BDSKShouldShareFilesKey] ? NSOnState : NSOffState];
    [enableBrowsingButton setState:[sud boolForKey:BDSKShouldLookForSharedFilesKey] ? NSOnState : NSOffState];
    [usePasswordButton setState:[sud boolForKey:BDSKSharingRequiresPasswordKey] ? NSOnState : NSOffState];
    
    [self updateSettingsUI];
    [self updateNameUI];
    [self updateStatusUI];
}

- (void)awakeFromNib
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSharingNameChanged:) name:BDSKSharingNameChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSharingStatusChanged:) name:BDSKSharingStatusChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleClientConnectionsChanged:) name:BDSKClientConnectionsChangedNotification object:nil];
    
    NSData *pwData = [BDSKPasswordController passwordForKeychainServiceName:BDSKServiceNameForKeychain];
    if(pwData != nil){
        NSString *pwString = [[NSString alloc] initWithData:pwData encoding:NSUTF8StringEncoding];
        [passwordField setStringValue:pwString];
        [pwString release];
    }
    
    [enableSharingButton setState:[sud boolForKey:BDSKShouldShareFilesKey] ? NSOnState : NSOffState];
    [enableBrowsingButton setState:[sud boolForKey:BDSKShouldLookForSharedFilesKey] ? NSOnState : NSOffState];
    [usePasswordButton setState:[sud boolForKey:BDSKSharingRequiresPasswordKey] ? NSOnState : NSOffState];
    
    [self updateSettingsUI];
    [self updateNameUI];
    [self updateUI];
}

- (void)defaultsDidRevert {
    // always clear the password, as that's not set in our prefs, and always send the notifications
    [BDSKPasswordController addOrModifyPassword:@"" name:BDSKServiceNameForKeychain userName:nil];
    if ([sud boolForKey:BDSKShouldLookForSharedFilesKey])
        [[BDSKSharingBrowser sharedBrowser] enableSharedBrowsing];
    else
        [[BDSKSharingBrowser sharedBrowser] disableSharedBrowsing];
    if ([sud boolForKey:BDSKShouldShareFilesKey])
        [[BDSKSharingServer defaultServer] enableSharing];
    else
        [[BDSKSharingServer defaultServer] disableSharing];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingPasswordChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingNameChangedNotification object:self];
    // reset UI, but only if we loaded the nib
    if ([self isWindowLoaded]) {
        [passwordField setStringValue:@""];
        [self updateUI];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)handleSharingNameChanged:(NSNotification *)aNotification;
{
    [self updateNameUI];
}

- (void)handleSharingStatusChanged:(NSNotification *)aNotification;
{
    [self updateStatusUI];
}

- (void)handleClientConnectionsChanged:(NSNotification *)aNotification;
{
    [self updateStatusUI];
}

- (void)updateSettingsUI
{
    [passwordField setEnabled:[sud boolForKey:BDSKSharingRequiresPasswordKey]];
}

- (void)updateNameUI
{
    [[sharedNameField cell] setPlaceholderString:[BDSKSharingServer defaultSharingName]];
    [sharedNameField setStringValue:[sud objectForKey:BDSKSharingNameKey]];
}

- (void)updateStatusUI
{
    BDSKSharingServer *server = [BDSKSharingServer defaultServer];
    NSString *statusMessage = nil;
    NSString *sharingName = nil;
    if([sud boolForKey:BDSKShouldShareFilesKey]){
        NSUInteger number = [server numberOfConnections];
        if(number == 1)
            statusMessage = NSLocalizedString(@"On, 1 user connected", @"Bonjour sharing is on status message, single connection");
        else if([server status] >= BDSKSharingStatusPublishing)
            statusMessage = [NSString stringWithFormat:NSLocalizedString(@"On, %lu users connected", @"Bonjour sharing is on status message, zero or multiple connections"), (unsigned long)number];
        else
            statusMessage = [NSString stringWithFormat:NSLocalizedString(@"Standby", @"Bonjour sharing is standby status message"), number];
        if ([server status] >= BDSKSharingStatusPublishing)
            sharingName = [server sharingName];
    }else{
        statusMessage = NSLocalizedString(@"Off", @"Bonjour sharing is off status message");
    }
    [statusField setStringValue:statusMessage];
    [usedNameField setStringValue:sharingName ?: @""];
}

- (IBAction)togglePassword:(id)sender
{
    [sud setBool:([sender state] == NSOnState) forKey:BDSKSharingRequiresPasswordKey];
    [self updateSettingsUI];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingPasswordChangedNotification object:nil];
}

- (IBAction)changePassword:(id)sender
{
    [BDSKPasswordController addOrModifyPassword:[sender stringValue] name:BDSKServiceNameForKeychain userName:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingPasswordChangedNotification object:nil];
}

// setting to the empty string will restore the default
- (IBAction)changeSharedName:(id)sender
{
    [sud setObject:[sender stringValue] forKey:BDSKSharingNameKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingNameChangedNotification object:self];
}

- (IBAction)toggleBrowsing:(id)sender
{
    BOOL flag = ([sender state] == NSOnState);
    [sud setBool:flag forKey:BDSKShouldLookForSharedFilesKey];
    if(flag)
        [[BDSKSharingBrowser sharedBrowser] enableSharedBrowsing];
    else
        [[BDSKSharingBrowser sharedBrowser] disableSharedBrowsing];
    [self updateStatusUI];
}

- (IBAction)toggleSharing:(id)sender
{
    BOOL flag = ([sender state] == NSOnState);
    [sud setBool:flag forKey:BDSKShouldShareFilesKey];
    if(flag)
        [[BDSKSharingServer defaultServer] enableSharing];
    else
        [[BDSKSharingServer defaultServer] disableSharing];
    [self updateStatusUI];
}

@end

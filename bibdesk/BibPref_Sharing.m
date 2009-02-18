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
#import <OmniFoundation/OmniFoundation.h>
#import "BDSKStringConstants.h"
#import "BDSKSharingBrowser.h"
#import <Security/Security.h>
#import "BDSKSharingServer.h"
#import "BDSKPasswordController.h"

@implementation BibPref_Sharing

- (void)awakeFromNib
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSharingNameChanged:) name:BDSKSharingNameChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleClientConnectionsChanged:) name:BDSKClientConnectionsChangedNotification object:nil];
    
    NSData *pwData = [BDSKPasswordController sharingPasswordForCurrentUserUnhashed];
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

- (void)handleClientConnectionsChanged:(NSNotification *)aNotification;
{
    [self updateUI];
}

- (void)updateUI
{
    [enableSharingButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldShareFilesKey] ? NSOnState : NSOffState];
    [enableBrowsingButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldLookForSharedFilesKey] ? NSOnState : NSOffState];
    [usePasswordButton setState:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKSharingRequiresPasswordKey] ? NSOnState : NSOffState];
    [passwordField setEnabled:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKSharingRequiresPasswordKey]];
    
    [sharedNameField setStringValue:[BDSKSharingServer sharingName]];
    NSString *statusMessage = nil;
    if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldShareFilesKey]){
        unsigned int number = [[BDSKSharingServer defaultServer] numberOfConnections];
        if(number == 1)
            statusMessage = NSLocalizedString(@"On, 1 user connected", @"Bonjour sharing is on status message, single connection");
        else
            statusMessage = [NSString stringWithFormat:NSLocalizedString(@"On, %i users connected", @"Bonjour sharing is on status message, multiple connections"), number];
    }else{
        statusMessage = NSLocalizedString(@"Off", @"Bonjour sharing is off status message");
    }
    [statusField setStringValue:statusMessage];
}

- (IBAction)togglePassword:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState) forKey:BDSKSharingRequiresPasswordKey];
    [self updateUI];
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
    [[NSUserDefaults standardUserDefaults] setObject:[sender stringValue] forKey:BDSKSharingNameKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingNameChangedNotification object:self];
    [self updateUI];
}

- (IBAction)toggleBrowsing:(id)sender
{
    BOOL flag = ([sender state] == NSOnState);
    [[NSUserDefaults standardUserDefaults] setBool:flag forKey:BDSKShouldLookForSharedFilesKey];
    if(flag == YES)
        [[BDSKSharingBrowser sharedBrowser] enableSharedBrowsing];
    else
        [[BDSKSharingBrowser sharedBrowser] disableSharedBrowsing];
}

- (IBAction)toggleSharing:(id)sender
{
    if([sender state] == NSOnState)
        [[BDSKSharingServer defaultServer] enableSharing];
    else
        [[BDSKSharingServer defaultServer] disableSharing];

    [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState) forKey:BDSKShouldShareFilesKey];
    
    [self updateUI];
}

@end

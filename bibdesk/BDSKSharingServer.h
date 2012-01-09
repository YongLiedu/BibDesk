//
//  BDSKSharingServer.h
//  Bibdesk
//
//  Created by Adam Maxwell on 04/02/06.
/*
 This software is Copyright (c) 2006-2012
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

#import <Cocoa/Cocoa.h>

extern NSString *BDSKTXTAuthenticateKey;
extern NSString *BDSKTXTVersionKey;

extern NSString *BDSKSharedArchivedDataKey;
extern NSString *BDSKSharedArchivedMacroDataKey;

extern NSString *BDSKComputerNameChangedNotification;

extern NSString *BDSKServiceNameForKeychain;

// implemented by the client
@protocol BDSKSharingClient

- (oneway void)setNeedsUpdate:(BOOL)flag;
- (BOOL)isAlive;
- (oneway void)invalidate;

@end

// implemented by the server
@protocol BDSKSharingServer

- (bycopy NSData *)archivedSnapshotOfPublications;
- (oneway void)registerClient:(byref id)clientObject forIdentifier:(bycopy NSString *)identifier version:(bycopy NSString *)version;
- (oneway void)removeClientForIdentifier:(bycopy NSString *)identifier;

@end

enum {
    BDSKSharingStatusOff,
    BDSKSharingStatusStarting,
    BDSKSharingStatusPublishing,
    BDSKSharingStatusSharing
};
typedef NSInteger BDSKSharingStatus;

@interface BDSKSharingServer : NSObject <NSNetServiceDelegate> {    
    NSNetService *netService;
    id server;
    NSString *sharingName;
    int socketDescriptor;
    BDSKSharingStatus status;
    NSInteger tryCount;
}

+ (id)defaultServer;
// base name for sharing when no pref is provided, the computer name
+ (NSString *)defaultSharingName;
// base name for sharing
+ (NSString *)sharingName;
+ (NSString *)supportedProtocolVersion;

// actual name used for sharing, unique name based on +sharingName
- (NSString *)sharingName;
- (BDSKSharingStatus)status;

- (NSUInteger)numberOfConnections;

- (void)queueDataChangedNotification:(NSNotification *)note;
- (void)handleComputerNameChangedNotification:(NSNotification *)note;
- (void)handleSharingNameChangedNotification:(NSNotification *)note;
- (void)handlePasswordChangedNotification:(NSNotification *)note;
- (void)handleApplicationWillTerminate:(NSNotification *)note;

- (void)enableSharing;
- (void)disableSharing;
- (void)restartSharingIfNeeded;

@end

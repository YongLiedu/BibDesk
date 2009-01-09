//
//  BDSKSharingBrowser.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 4/2/06.
/*
 This software is Copyright (c) 2005-2009
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKSharingBrowser.h"
#import "BDSKStringConstants.h"
#import "BibDocument_Groups.h"
#import "BDSKSharingClient.h"
#import "NSArray_BDSKExtensions.h"
#import "BDSKSharingServer.h"

// Registered at http://www.dns-sd.org/ServiceTypes.html with TXT keys "txtvers" and "authenticate."
NSString *BDSKNetServiceDomain = @"_bdsk._tcp.";

@implementation BDSKSharingBrowser

static BDSKSharingBrowser *sharedBrowser = nil;

// This is the minimal version for the server that we require
// If we introduce incompatible changes in future, bump this to avoid sharing breakage
+ (NSString *)requiredProtocolVersion { return @"0"; }

+ (id)sharedBrowser{
    if(sharedBrowser == nil)
        sharedBrowser = [[BDSKSharingBrowser alloc] init];
    return sharedBrowser;
}

+ (id)allocWithZone:(NSZone *)zone {
    return sharedBrowser ?: [super allocWithZone:zone];
}

- (id)init{
    if ((sharedBrowser == nil) && (sharedBrowser = self = [super init])) {
        sharingClients = nil;
        browser = nil;
        unresolvedNetServices = nil;        
    }
    return sharedBrowser;
}

- (id)retain { return self; }

- (id)autorelease { return self; }

- (void)release {}

- (unsigned)retainCount { return UINT_MAX; }

- (NSSet *)sharingClients{
    return sharingClients;
}

#pragma mark Reading other data

- (BOOL)shouldAddService:(NSNetService *)aNetService
{
    NSData *TXTData = [aNetService TXTRecordData];
    NSString *version = nil;
    // check the version for compatibility; this is our own versioning system
    if(TXTData)
        version = [NSString stringWithData:[[NSNetService dictionaryFromTXTRecordData:TXTData] objectForKey:BDSKTXTVersionKey] encoding:NSUTF8StringEncoding];
    return [version numericCompare:[BDSKSharingBrowser requiredProtocolVersion]] != NSOrderedAscending;
}

- (void)netServiceDidResolveAddress:(NSNetService *)aNetService
{    
    // we don't want it to message us again (the shared group will become the delegate)
    [aNetService setDelegate:nil];

    if([self shouldAddService:aNetService]){
        BDSKSharingClient *client = [[BDSKSharingClient alloc] initWithService:aNetService];
        [sharingClients addObject:client];
        [client release];
    }
    
    // remove from the list of unresolved services
    [unresolvedNetServices removeObject:aNetService];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingClientsChangedNotification object:self];
}

- (void)netService:(NSNetService *)aNetService didNotResolve:(NSDictionary *)errorDict
{
    // do we want to try again, or show the error message?
    [aNetService setDelegate:nil];
    [unresolvedNetServices removeObject:aNetService];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing 
{
    // In general, we want to ignore our own shared services, although this doesn't cause problems with the run loop anymore (since the DO servers have their own threads)  Since SystemConfiguration guarantees that we have a unique computer name, this should be safe.
    if([[BDSKSharingServer sharingName] isEqualToString:[aNetService name]] == YES && [[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKEnableSharingWithSelf"] == NO)
        return;

    // set as delegate and resolve, so we can find out if this originated from the localhost or a remote machine
    // we can't access TXT records until the service is resolved (this is documented in CFNetService, not NSNetService)
    [aNetService setDelegate:self];
    [aNetService resolveWithTimeout:5.0];
    [unresolvedNetServices addObject:aNetService];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    if([unresolvedNetServices containsObject:aNetService]){
        [aNetService setDelegate:nil];
        [unresolvedNetServices removeObject:aNetService];
    }else{
        NSString *name = [aNetService name];
        NSEnumerator *e = [sharingClients objectEnumerator];
        BDSKSharingClient *client = nil;
        
        // find the group we should remove
        while(client = [e nextObject]){
            if([[client name] isEqualToString:name])
                break;
        }
        if(client != nil){
            [sharingClients removeObject:client];
            [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingClientsChangedNotification object:self];
        }
    }
}

- (BOOL)isBrowsing;
{
    return sharingClients != nil;
}

- (void)enableSharedBrowsing;
{
    if([self isBrowsing] == NO){
        sharingClients = [[NSMutableSet alloc] initWithCapacity:5];
        browser = [[NSNetServiceBrowser alloc] init];
        [browser setDelegate:self];
        [browser searchForServicesOfType:BDSKNetServiceDomain inDomain:@""];    
        unresolvedNetServices = [[NSMutableArray alloc] initWithCapacity:5];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingClientsChangedNotification object:self];
    }
}

- (void)disableSharedBrowsing;
{
    if([self isBrowsing]){
        [sharingClients release];
        sharingClients = nil;
        [browser release];
        browser = nil;
        [unresolvedNetServices makeObjectsPerformSelector:@selector(setDelegate:) withObject:nil];
        [unresolvedNetServices release];
        unresolvedNetServices = nil;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingClientsChangedNotification object:self];
    }
}

- (void)restartSharedBrowsingIfNeeded;
{
    if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShouldLookForSharedFilesKey]){
        [self disableSharedBrowsing];
        [self enableSharedBrowsing];
    }
}

@end

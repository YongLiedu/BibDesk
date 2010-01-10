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

- (id)init{
    BDSKPRECONDITION(sharedBrowser == nil);
    if (self = [super init]) {
        sharingClients = nil;
        browser = nil;
        unresolvedNetServices = nil;
        undecidedNetServices = nil;
    }
    return sharedBrowser;
}

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
        version = [[[NSString alloc] initWithData:[[NSNetService dictionaryFromTXTRecordData:TXTData] objectForKey:BDSKTXTVersionKey] encoding:NSUTF8StringEncoding] autorelease];
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

- (void)resolveService:(NSNetService *)aNetService {
    if ([undecidedNetServices containsObject:aNetService] == NO)
        // the service was removed in the meantime
        return;
    // In general, we want to ignore our own shared services, although this doesn't cause problems with the run loop anymore (since the DO servers have their own threads)  Since SystemConfiguration guarantees that we have a unique computer name, this should be safe.
    if ([[aNetService name] isEqualToString:[[BDSKSharingServer defaultServer] sharingName]] && [[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKEnableSharingWithSelf"] == NO) {
        switch ([[BDSKSharingServer defaultServer] status]) {
            case BDSKSharingStatusOff:
            case BDSKSharingStatusStarting:
                // we're not sharing, so it can't be ours
                break;
            case BDSKSharingStatusPublishing:
                // we may be sharing, but it may still find a name collision, so check again after a second
                [self performSelector:@selector(resolveService:) withObject:aNetService afterDelay:1.0];
                return;
            case BDSKSharingStatusSharing:
                // yes, it's our own service, ignore
                [undecidedNetServices removeObject:aNetService];
                return;
        }
    }
    // set as delegate and resolve, so we can find out if this originated from the localhost or a remote machine
    // we can't access TXT records until the service is resolved (this is documented in CFNetService, not NSNetService)
    [aNetService setDelegate:self];
    [aNetService resolveWithTimeout:5.0];
    [undecidedNetServices removeObject:aNetService];
    [unresolvedNetServices addObject:aNetService];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing 
{
    [undecidedNetServices addObject:aNetService];
    [self resolveService:aNetService];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    if([undecidedNetServices containsObject:aNetService]){
        [undecidedNetServices removeObject:aNetService];
    }else if([unresolvedNetServices containsObject:aNetService]){
        [aNetService setDelegate:nil];
        [unresolvedNetServices removeObject:aNetService];
    }else{
        NSString *name = [aNetService name];
        BDSKSharingClient *client = nil;
        
        // find the client we should remove
        for (client in sharingClients) {
            if ([[client name] isEqualToString:name])
                break;
        }
        if (client != nil) {
            [client terminate];
            [sharingClients removeObject:client];
            [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingClientsChangedNotification object:self];
        }
    }
}

- (BOOL)isBrowsing;
{
    return sharingClients != nil;
}

- (void)handleApplicationWillTerminate:(NSNotification *)note;
{
    [self disableSharedBrowsing];
}

- (void)enableSharedBrowsing;
{
    // only restart when there's a document to display the shared groups, the next document that's opened will otherwise call again if necessary
    if([self isBrowsing] == NO && [[NSApp orderedDocuments] count] > 0){
        sharingClients = [[NSMutableSet alloc] initWithCapacity:5];
        browser = [[NSNetServiceBrowser alloc] init];
        [browser setDelegate:self];
        [browser searchForServicesOfType:BDSKNetServiceDomain inDomain:@""];    
        unresolvedNetServices = [[NSMutableArray alloc] initWithCapacity:5];
        undecidedNetServices = [[NSMutableSet alloc] initWithCapacity:1];
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:BDSKSharingClientsChangedNotification object:self];
        [nc addObserver:self selector:@selector(handleApplicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
    }
}

- (void)disableSharedBrowsing;
{
    if([self isBrowsing]){
        [sharingClients makeObjectsPerformSelector:@selector(terminate)];
        BDSKDESTROY(sharingClients);
        
        BDSKDESTROY(browser);
        
        [unresolvedNetServices makeObjectsPerformSelector:@selector(setDelegate:) withObject:nil];
        BDSKDESTROY(unresolvedNetServices);
        
        if ([undecidedNetServices count])
            [[self class] cancelPreviousPerformRequestsWithTarget:self];
        BDSKDESTROY(undecidedNetServices);
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:BDSKSharingClientsChangedNotification object:self];
        [nc removeObserver:self name:NSApplicationWillTerminateNotification object:nil];
    }
}

- (void)restartSharedBrowsingIfNeeded;
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldLookForSharedFilesKey]){
        [self disableSharedBrowsing];
        [self enableSharedBrowsing];
    }
}

@end

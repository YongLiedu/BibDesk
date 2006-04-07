//
//  BDSKSharedGroup.m
//  Bibdesk
//
//  Created by Adam Maxwell on 04/03/06.
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

#import "BDSKSharedGroup.h"
#import "BDSKSharingServer.h"
#import "BDSKPasswordController.h"
#import "NSArray_BDSKExtensions.h"
#import "NSImage+Toolbox.h"

#import <libkern/OSAtomic.h>

@implementation BDSKSharedGroup

- (id)initWithService:(NSNetService *)aService;
{
    NSParameterAssert(aService != nil);
    if(self = [super initWithName:@"" key:@"" count:0]){
        service = [aService retain];

        publications = nil;
        needsUpdate = YES;
        
        static int connectionIdx = 0;
        // this needs to be unique on the network and among our shared groups
        serverSharingName = [[NSString alloc] initWithFormat:@"%@%@%d", [[NSHost currentHost] name], [[self class] description], connectionIdx++];
        // this just needs to be unique on localhost
        localConnectionName = [[NSString alloc] initWithFormat:@"%@%d", [[self class] description], connectionIdx++];
        shouldKeepRunning = 1;
        
        [NSThread detachNewThreadSelector:@selector(runDOServer) toTarget:self withObject:nil];
    }
    
    return self;
}

- (void)dealloc
{
    [self stopDOServer];
    [service release];
    [publications release];
    [serverSharingName release];
    [localConnectionName release];
    [super dealloc];
}

- (oneway void)setNeedsUpdate:(BOOL)flag
{
    @synchronized(self){
        needsUpdate = flag;
    }
}

/* @@ Warning: retain cycle, since the NSThread we detach in -init retains us (and we keep running it).  Best option may be to convert this server to a separate object, and each shared group will "own" one, and then stop it when the group is deallocated.  For now, we have the document (owner) call stopDOServer when releasing the groups. */

- (void)_cleanupBDSKSharedGroupDOServer
{
    // must be on the background thread, or the connection won't be removed from the correct run loop
    [[NSSocketPortNameServer sharedInstance] removePortForName:serverSharingName];
    [connection invalidate];
    [connection setRootObject:nil];
    [connection release];
    connection = nil;
    
    // defaultConnection is still retaining us...
    [[NSConnection defaultConnection] setRootObject:nil];
    [[NSConnection defaultConnection] registerName:nil];
    
    // this seems dirty, but we need to unblock and allow the thread to release us
    CFRunLoopStop( CFRunLoopGetCurrent() );
}

- (void)stopDOServer;
{
    // we're in the main thread, so set the stop flag
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&shouldKeepRunning);
    NSConnection *conn = [NSConnection connectionWithRegisteredName:localConnectionName host:nil];
    if(conn == nil)
        NSLog(@"unable to get thread connection");
    id proxy = [conn rootProxy];
    [proxy _cleanupBDSKSharedGroupDOServer];
}

- (BOOL)connection:(NSConnection *)parentConnection shouldMakeNewConnection:(NSConnection *)newConnection
{
    // set the child connection's delegate so we get authentication messages
    [newConnection setDelegate:self];
    return YES;
}

- (void)runPasswordPrompt
{
    NSAssert([NSThread inMainThread] == 1, @"password controller must be run from the main thread");
    BDSKPasswordController *pwc = [[BDSKPasswordController alloc] init];
    [pwc runModalForName:[BDSKPasswordController keychainServiceNameWithComputerName:[self name]]];
    [pwc close];
    [pwc release];
}

- (NSData *)authenticationDataForComponents:(NSArray *)components;
{
    NSData *password = [BDSKPasswordController passwordHashedForKeychainServiceName:[BDSKPasswordController keychainServiceNameWithComputerName:[self name]]];

    if(password == nil){
        NSLog(@"no password, need to prompt; thread is %@", [NSThread currentThread]);
        [self performSelectorOnMainThread:@selector(runPasswordPrompt) withObject:nil waitUntilDone:YES];
        NSLog(@"retrying password from keychain...");
        password = [BDSKPasswordController passwordHashedForKeychainServiceName:[BDSKPasswordController keychainServiceNameWithComputerName:[self name]]];
    }
    
    return password;
}

- (void)runDOServer;
{
        
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&shouldKeepRunning);
    
    NSSocketPort *receivePort = [[[NSSocketPort alloc] init] autorelease];
    
    @try {
        if([[NSSocketPortNameServer sharedInstance] registerPort:receivePort name:serverSharingName] == NO)
            @throw [NSString stringWithFormat:@"Unable to register port %@ and name %@", receivePort, [BDSKSharingServer sharingName]];
        
        // this is our public server name for receiving change notifications from the remote server
        connection = [[NSConnection alloc] initWithReceivePort:receivePort sendPort:nil];
        
        // connection retains us also...
        [connection setRootObject:self];
        
        // for authentication
        [connection setDelegate:self];
        
        // we'll use this to communicate between threads on the localhost
        // @@ does this succeed after a stop/restart with a new thread?
        NSConnection *threadConnection = [NSConnection defaultConnection];
        if(threadConnection == nil)
            @throw @"Unable to get default connection";
        [threadConnection setRootObject:self];
        if([threadConnection registerName:localConnectionName] == NO)
            @throw @"Unable to register local connection";        
                
        do {
            [pool release];
            pool = [NSAutoreleasePool new];
            CFRunLoopRun();
        } while (shouldKeepRunning == 1);
    }
    @catch(id exception) {
        [connection release];
        connection = nil;
        NSLog(@"Discarding exception %@ raised in object %@", exception, self);
        // reset the flag
        OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&shouldKeepRunning);
    }
    
    @finally {
        [pool release];
    }
}

- (void)retrievePublications;
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    @try {
        NSConnection *conn = nil;
        id proxyObject;

        NSData *TXTData = [service TXTRecordData];
        NSDictionary *dict = nil;
        if(TXTData)
            dict = [NSNetService dictionaryFromTXTRecordData:TXTData];
        
        // we need the port name from the TXTRecord
        NSString *portName = [NSString stringWithData:[dict objectForKey:BDSKTXTComputerNameKey] encoding:NSUTF8StringEncoding];
        NSPort *sendPort = [[NSSocketPortNameServer sharedInstance] portForName:portName host:[service hostName]];
        
        if(sendPort == nil)
            NSLog(@"client: unable to look up server");
        @try {
            conn = [NSConnection connectionWithReceivePort:nil sendPort:sendPort];
            proxyObject = [conn rootProxy];
        }
        @catch (id exception) {
            NSLog(@"client: %@", exception);
            conn = nil;
            proxyObject = nil;
        }
        if(proxyObject == nil)
            NSLog(@"client: getting proxy failed");
        else
            NSLog(@"client: proxy is %@", proxyObject);
        
        
        [proxyObject setProtocolForProxy:@protocol(BDSKSharingProtocol)];
        
        // need hostname and portname for the NSSocketPort connection on the other end
        // use computer as the notification identifier for this host on the other end
        [proxyObject registerHostNameForNotifications:[NSDictionary dictionaryWithObjectsAndKeys:[[NSHost currentHost] name], @"hostname", serverSharingName, @"portname", [BDSKSharingServer sharingName], @"computer", nil]];
        
        [publications autorelease];
        publications = nil;

        // this is really slow, because it ends up copying each object; are these passed by reference?
        //publications = [[proxyObject snapshotOfPublications] copy];
        
        NSData *proxyData = [proxyObject archivedSnapshotOfPublications];
        
        if([proxyData length] != 0){
            NSString *errorString = nil;
            NSDictionary *dictionary = [NSPropertyListSerialization propertyListFromData:proxyData mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:&errorString];
            if(errorString != nil){
                NSLog(@"Error reading shared data: %@", errorString);
                [errorString release];
            } else {
                NSData *archive = [dictionary objectForKey:BDSKSharedArchivedDataKey];
                if(archive != nil){
                    publications = [[NSKeyedUnarchiver unarchiveObjectWithData:archive] retain];
                }
            }
        }    
        [self setCount:[publications count]];
        if([publications count]){
            [self setNeedsUpdate:NO];
            [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharedGroupFinishedNotification object:self];
        }
    }
    @catch(id exception){
        NSLog(@"%@: discarding exception %@ while retrieving publications", self, exception);
    }
    @finally{
        [pool release];
    }
}

- (NSString *)name { return [[[service name] retain] autorelease]; }


- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p>: {\n\tneeds update: %@\n\tname: %@\nservice: %@\n }", [self class], self, (needsUpdate ? @"yes" : @"no"), [self name], service];
}

- (NSArray *)publications
{
    if(needsUpdate == YES || publications == nil){
        [NSThread detachNewThreadSelector:@selector(retrievePublications) toTarget:self withObject:nil];
    }
    // this will likely be nil the first time; retain since our server thread could release it at any time
    return [[publications retain] autorelease];
}


- (BOOL)containsItem:(BibItem *)item {
    return [[self publications] containsObject:item];
}

- (NSNetService *)service { return service; }

- (NSImage *)icon {
	return [NSImage smallImageNamed:@"sharedFolderIcon"];
}

- (BOOL)isShared { return YES; }

- (BOOL)hasEditableName { return NO; }


@end



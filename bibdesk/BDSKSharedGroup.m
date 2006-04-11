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

NSString *BDSKSharedGroupHostNameInfoKey = @"hostname";
NSString *BDSKSharedGroupPortnameInfoKey = @"portname";
NSString *BDSKSharedGroupComputerNameInfoKey = @"computer";

typedef struct _BDSKSharedGroupFlags {
    volatile int32_t shouldKeepRunning __attribute__ ((aligned (4)));
    volatile int32_t isRetrieving __attribute__ ((aligned (4)));
    volatile int32_t authenticationFailed __attribute__ ((aligned (4)));
    volatile int32_t canceledAuthentication __attribute__ ((aligned (4)));
    volatile int32_t needsAuthentication __attribute__ ((aligned (4)));
} BDSKSharedGroupFlags;    


// private protocols for inter-thread messaging
@protocol BDSKSharedGroupServerLocalThread

- (void)cleanup; // probably shouldn't be oneway, since it gets called when quitting the app 
- (oneway void)retrievePublications;

@end

@protocol BDSKSharedGroupServerMainThread

- (void)unarchivePublications:(NSData *)archive; // must not be declared oneway 
- (int)runPasswordPrompt;
- (int)runAuthenticationFailedAlert;

@end


// private class for DO server. We have it as a separate object so we don't get a retain loop, we remove it from the thread runloop in the group's dealloc
@interface BDSKSharedGroupServer : NSObject <BDSKSharedGroupServerLocalThread, BDSKSharedGroupServerMainThread, BDSKClientProtocol> {
    NSNetService *service;
    BDSKSharedGroup *group;
    NSConnection *connection;
    BDSKSharedGroupFlags flags;

    NSString *serverSharingName;
    NSString *localConnectionName;
    NSConnection *mainThreadConnection;
}

- (id)initWithGroup:(BDSKSharedGroup *)aGroup andService:(NSNetService *)aService;

- (BOOL)isRetrieving;
- (BOOL)needsAuthentication;

- (id)mainThreadProxy;
- (id)localThreadProxy;

- (void)runDOServer;
- (void)stopDOServer;

@end


@implementation BDSKSharedGroup

static NSImage *lockedIcon = nil;
static NSImage *unlockedIcon = nil;

+ (NSImage *)icon{
    return [NSImage smallImageNamed:@"sharedFolderIcon"];
}

+ (NSImage *)lockedIcon {
    if(lockedIcon == nil){
        NSRect iconRect = NSMakeRect(0.0, 0.0, 16.0, 16.0);
        NSRect badgeRect = NSMakeRect(7.0, 0.0, 11.0, 11.0);
        NSImage *image = [[NSImage alloc] initWithSize:iconRect.size];
        NSImage *badge = [NSImage imageNamed:@"SmallLock_Locked"];
        
        [image lockFocus];
        [NSGraphicsContext saveGraphicsState];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [[self icon] drawInRect:iconRect fromRect:iconRect operation:NSCompositeSourceOver  fraction:1.0];
        [badge drawInRect:badgeRect fromRect:iconRect operation:NSCompositeSourceOver  fraction:1.0];
        [NSGraphicsContext restoreGraphicsState];
        [image unlockFocus];
        
        lockedIcon = image;
    }
    return lockedIcon;
}

+ (NSImage *)unlockedIcon {
    if(unlockedIcon == nil){
        NSRect iconRect = NSMakeRect(0.0, 0.0, 16.0, 16.0);
        NSRect badgeRect = NSMakeRect(6.0, 0.0, 11.0, 11.0);
        NSImage *image = [[NSImage alloc] initWithSize:iconRect.size];
        NSImage *badge = [NSImage imageNamed:@"SmallLock_Unlocked"];
        
        [image lockFocus];
        [NSGraphicsContext saveGraphicsState];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [[self icon] drawInRect:iconRect fromRect:iconRect operation:NSCompositeSourceOver  fraction:1.0];
        [badge drawInRect:badgeRect fromRect:iconRect operation:NSCompositeSourceOver  fraction:1.0];
        [NSGraphicsContext restoreGraphicsState];
        [image unlockFocus];
        
        unlockedIcon = image;
    }
    return unlockedIcon;
}

- (id)initWithService:(NSNetService *)aService;
{
    NSParameterAssert(aService != nil);
    if(self = [super initWithName:[aService name] key:@"" count:0]){

        publications = nil;
        needsUpdate = YES;
        
        server = [[BDSKSharedGroupServer alloc] initWithGroup:self andService:aService];
    }
    
    return self;
}

- (void)dealloc;
{
    [server stopDOServer];
    [server release];
    [publications release];
    [super dealloc];
}

// may be used in -[NSCell setObjectValue:] at some point
- (id)copyWithZone:(NSZone *)zone { return [self retain]; }

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [NSException raise:NSInternalInconsistencyException format:@"Instances of %@ do not support NSCoding", [self class]];
}

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    [NSException raise:NSInternalInconsistencyException format:@"Instances of %@ do not support NSCoding", [self class]];
    return nil;
}

- (NSString *)name { return name; }

- (NSString *)description;
{
    return [NSString stringWithFormat:@"<%@ %p>: {\n\tneeds update: %@\n\tname: %@\n }", [self class], self, (needsUpdate ? @"yes" : @"no"), name];
}

- (NSArray *)publications;
{
    if([self isRetrieving] == NO && ([self needsUpdate] == YES || publications == nil)){
        // let the server get the publications asynchronously
        [[server localThreadProxy] retrievePublications]; 
    }
    // this will likely be nil the first time
    return publications;
}

- (void)setPublications:(NSArray *)newPublications;
{
    if(newPublications != publications){
        [publications release];
        publications = [newPublications retain];
    }
    
    [self setCount:[publications count]];
    [self setNeedsUpdate:NO];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:(publications != nil)] forKey:@"succeeded"];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharedGroupFinishedNotification object:self userInfo:userInfo];
}

- (BOOL)containsItem:(BibItem *)item {
    // calling [self publications] will repeatedly reschedule a retrieval, which is undesirable if the user canceled a password; containsItem is called very frequently
    NSArray *pubs = [publications retain];
    BOOL rv = [pubs containsObject:item];
    [pubs release];
    return rv;
}

- (BOOL)isRetrieving { return (BOOL)[server isRetrieving]; }

- (BOOL)needsUpdate { return needsUpdate; }

- (void)setNeedsUpdate:(BOOL)flag { needsUpdate = flag; }

- (NSImage *)icon {
    if([server needsAuthentication])
        return (publications == nil) ? [[self class] lockedIcon] : [[self class] unlockedIcon];
    return [[self class] icon];
}

- (BOOL)isShared { return YES; }

- (BOOL)hasEditableName { return NO; }

@end


@implementation BDSKSharedGroupServer

- (id)initWithGroup:(BDSKSharedGroup *)aGroup andService:(NSNetService *)aService;
{
    if (self = [super init]) {
        group = aGroup; // don't retain since it retains us
        
        service = [aService retain];
        
        // monitor changes to the TXT data
        [service setDelegate:self];
        [service startMonitoring];
        
        static int connectionIdx = 0;
        // this just needs to be unique on localhost
        localConnectionName = [[NSString alloc] initWithFormat:@"%@%d", [[self class] description], connectionIdx++];
        // this needs to be unique on the network and among our shared group servers
        serverSharingName = [[NSString alloc] initWithFormat:@"%@%@", [[NSHost currentHost] name], localConnectionName];

        mainThreadConnection = [[NSConnection alloc] initWithReceivePort:[NSPort port] sendPort:nil];
        [mainThreadConnection setRootObject:self];
        [mainThreadConnection enableMultipleThreads];
        
        // set up flags
        memset(&flags, 0, sizeof(flags));
        flags.shouldKeepRunning = 1;
        connection = nil;
        
        NSData *TXTData = [service TXTRecordData];
        if(TXTData){
            NSDictionary *dict = [NSNetService dictionaryFromTXTRecordData:TXTData];
            if([[NSString stringWithData:[dict objectForKey:BDSKTXTAuthenticateKey] encoding:NSUTF8StringEncoding] intValue] == 1)
                OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.needsAuthentication);
        }
        
        // if we detach in -publications, connection setup doesn't happen in time
        [NSThread detachNewThreadSelector:@selector(runDOServer) toTarget:self withObject:nil];
    }
    return self;
}

- (void)dealloc;
{
    [service setDelegate:nil];
    [service release];
    [serverSharingName release];
    [localConnectionName release];
    [super dealloc];
}

- (void)stopDOServer;
{
    // we're in the main thread, so set the stop flag
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.shouldKeepRunning);
    [[self localThreadProxy] cleanup];
        
    [mainThreadConnection invalidate];
    [mainThreadConnection setRootObject:nil];
    [mainThreadConnection release];
    mainThreadConnection = nil;
}

- (oneway void)setNeedsUpdate:(BOOL)flag { [group setNeedsUpdate:flag]; }

- (BOOL)isRetrieving { return flags.isRetrieving == 1; }

- (BOOL)needsAuthentication { return flags.needsAuthentication == 1; }

#pragma mark Proxies for inter-thread communication

- (id)mainThreadProxy;
{
    NSConnection *conn = nil;
    id proxy = nil;
    @try {
        conn = [NSConnection connectionWithReceivePort:nil sendPort:[mainThreadConnection receivePort]];
        proxy = [conn rootProxy];
        [proxy setProtocolForProxy:@protocol(BDSKSharedGroupServerMainThread)];
    }
    @catch(id exception) {
        NSLog(@"Unable to connect to main thread.");
        proxy = nil;
    }
    return proxy;
}

- (id)localThreadProxy;
{
    NSConnection *conn = [NSConnection connectionWithRegisteredName:localConnectionName host:nil];
    if(conn == nil)
        NSLog(@"Unable to get local thread connection");
    id proxy = [conn rootProxy];
    [proxy setProtocolForProxy:@protocol(BDSKSharedGroupServerLocalThread)];
    return proxy;
}

#pragma mark Authentication

- (int)runPasswordPrompt;
{
    NSAssert([NSThread inMainThread] == 1, @"password controller must be run from the main thread");
    BDSKPasswordController *pwc = [[BDSKPasswordController alloc] init];
    int rv = [pwc runModalForKeychainServiceName:[BDSKPasswordController keychainServiceNameWithComputerName:[group name]] message:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Enter password for", @""), [group name]]];
    [pwc close];
    [pwc release];
    return rv;
}

- (int)runAuthenticationFailedAlert;
{
    NSAssert([NSThread inMainThread] == 1, @"runAuthenticationFailedAlert must be run from the main thread");
    return NSRunAlertPanel(NSLocalizedString(@"Authentication Failed", @""), [NSString stringWithFormat:NSLocalizedString(@"Incorrect password for BibDesk Sharing on server %@.  Reselect to try again.", @""), [group name]], nil, nil, nil);
}

- (BOOL)connection:(NSConnection *)parentConnection shouldMakeNewConnection:(NSConnection *)newConnection
{
    // set the child connection's delegate so we get authentication messages
    [newConnection setDelegate:self];
    return YES;
}

// this can be called from any thread
- (NSData *)authenticationDataForComponents:(NSArray *)components;
{
    if(flags.needsAuthentication == 0)
        return [[NSData data] sha1Signature];
    
    NSData *password = nil;
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.canceledAuthentication);
    
    int rv = 1;
    if(flags.authenticationFailed == 0)
        password = [BDSKPasswordController passwordHashedForKeychainServiceName:[BDSKPasswordController keychainServiceNameWithComputerName:[group name]]];
    
    if(password == nil){   
        
        // run the prompt on the main thread
        rv = [[self mainThreadProxy] runPasswordPrompt];
        
        // retry from the keychain
        if (rv == BDSKPasswordReturn){
            password = [BDSKPasswordController passwordHashedForKeychainServiceName:[BDSKPasswordController keychainServiceNameWithComputerName:[group name]]];
            // assume we succeeded; the exception handler for the connection will change it back if we fail again
            OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.authenticationFailed);
        }else{
            OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.canceledAuthentication);
        }
    }
    
    // doc says we're required to return empty NSData instead of nil
    return password ? password : [NSData data];
}

// monitor the TXT record in case the server changes password requirements
- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data;
{
    OBASSERT(sender == service);
    OBASSERT(data != nil);
    if(data){
        NSDictionary *dict = [NSNetService dictionaryFromTXTRecordData:data];
        int32_t val = [[NSString stringWithData:[dict objectForKey:BDSKTXTAuthenticateKey] encoding:NSUTF8StringEncoding] intValue];
        int32_t oldVal = flags.needsAuthentication;
        OSAtomicCompareAndSwap32Barrier(oldVal, val, (int32_t *)&flags.needsAuthentication);
    }
}

#pragma mark ServerThread

- (void)unarchivePublications:(NSData *)archive;
{
    NSAssert([NSThread inMainThread] == 1, @"publications must be set from the main thread");
    NSArray *publications = archive ? [NSKeyedUnarchiver unarchiveObjectWithData:archive] : nil;
    [group setPublications:publications];
}

- (oneway void)retrievePublications;
{
    
    // set so we don't try calling this multiple times
    OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.isRetrieving);
    
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
            NSLog(@"client: unable to look up server %@", [service hostName]);
        @try {
            conn = [NSConnection connectionWithReceivePort:nil sendPort:sendPort];
            // ask for password
            [conn setDelegate:self];
            proxyObject = [conn rootProxy];
        }
        @catch (id exception) {
            // flag authentication failures so we get a prompt the next time around (in case our password was wrong)
            // we also get this if the user canceled, since an empty data will be returned
            if([exception respondsToSelector:@selector(name)] && [[exception name] isEqualToString:NSFailedAuthenticationException]){
                
                // if the user didn't cancel, set an auth failure flag and show an alert
                if(flags.canceledAuthentication == 0){
                    OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.authenticationFailed);
                    
                    [[self mainThreadProxy] runAuthenticationFailedAlert];
                }
                
            } else {
                // don't log auth failures
                NSLog(@"client: %@", exception);
            }
            conn = nil;
            proxyObject = nil;
        }

        [proxyObject setProtocolForProxy:@protocol(BDSKSharingProtocol)];
        
        // need hostname and portname for the NSSocketPort connection on the other end
        // use computer as the notification identifier for this host on the other end
        [proxyObject registerHostNameForNotifications:[NSDictionary dictionaryWithObjectsAndKeys:[[NSHost currentHost] name], BDSKSharedGroupHostNameInfoKey, serverSharingName, BDSKSharedGroupPortnameInfoKey, [BDSKSharingServer sharingName], BDSKSharedGroupComputerNameInfoKey, nil]];
        
        NSArray *publications = nil;
        NSData *proxyData = [proxyObject archivedSnapshotOfPublications];
        NSData *archive = nil;
        
        if([proxyData length] != 0){
            if([proxyData mightBeCompressed])
                proxyData = [proxyData decompressedData];
            NSString *errorString = nil;
            NSDictionary *dictionary = [NSPropertyListSerialization propertyListFromData:proxyData mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:&errorString];
            if(errorString != nil){
                NSLog(@"Error reading shared data: %@", errorString);
                [errorString release];
            } else {
                archive = [dictionary objectForKey:BDSKSharedArchivedDataKey];
            }
        }
        OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.isRetrieving);
        // use the main thread; this avoids an extra (un)archiving between threads and it ends up posting notifications for UI updates
        [[self mainThreadProxy] unarchivePublications:archive];
    }
    @catch(id exception){
        NSLog(@"%@: discarding exception %@ while retrieving publications", [self class], exception);
        OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.isRetrieving);
    }
    @finally{
        [pool release];
    }
}

- (void)cleanup;
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

- (void)runDOServer;
{
    // detach a new thread to run this
    NSAssert([NSThread inMainThread] == NO, @"do not run the server in the main thread");
    NSAssert(connection == nil, @"server is already running");

    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.shouldKeepRunning);
    NSSocketPort *receivePort = [[[NSSocketPort alloc] init] autorelease];
    
    @try {
        if([[NSSocketPortNameServer sharedInstance] registerPort:receivePort name:serverSharingName] == NO)
            @throw [NSString stringWithFormat:@"Unable to register port %@ and name %@", receivePort, [BDSKSharingServer sharingName]];
        
        // this is our public server name for receiving change notifications from the remote server
        connection = [[NSConnection alloc] initWithReceivePort:receivePort sendPort:nil];
        
        // connection retains us also...
        [connection setRootObject:self];
        
        // don't set the delegate, as we don't authenticate connections here (this connection won't be used if we can't authenticate in the first place)
        
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
        } while (flags.shouldKeepRunning == 1);
    }
    @catch(id exception) {
        [connection release];
        connection = nil;
        NSLog(@"Discarding exception %@ raised in object %@", exception, self);
        // reset the flag so we can start over; shouldn't be necessary
        OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.shouldKeepRunning);
    }
    
    @finally {
        [pool release];
    }
}

@end

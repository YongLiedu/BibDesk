//
//  BDSKSharingServer.m
//  Bibdesk
//
//  Created by Adam Maxwell on 04/02/06.
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

#import "BDSKSharingServer.h"
#import "BDSKGroup.h"
#import "BDSKSharingBrowser.h"
#import "BDSKPasswordController.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "NSArray_BDSKExtensions.h"
#import "BibItem.h"
#import "BibDocument.h"
#import <libkern/OSAtomic.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

static id sharedInstance = nil;

// TXT record keys
NSString *BDSKTXTPasswordKey = @"pass";
NSString *BDSKTXTUniqueIdentifierKey = @"hostid";
NSString *BDSKTXTComputerNameKey = @"name";
NSString *BDSKTXTVersionKey = @"txtvers";

NSString *BDSKSharedArchivedDataKey = @"publications_v1";

static SCDynamicStoreRef dynamicStore = NULL;
static const void *retainCallBack(const void *info) { return [(id)info retain]; }
static void releaseCallBack(const void *info) { [(id)info release]; }
static CFStringRef copyDescriptionCallBack(const void *info) { return (CFStringRef)[[(id)info description] copy]; }
// convert this to an NSNotification
static void SCDynamicStoreChanged(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info)
{
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKComputerNameChangedNotification object:nil];
    
    // update the text field in prefs if necessary (or that could listen for computer name changes...)
    if([NSString isEmptyString:[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKSharingNameKey]])
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingNameChangedNotification object:nil];
}

// This is the computer name as set in sys prefs (sharing)
NSString *BDSKComputerName() {
    return [(id)SCDynamicStoreCopyComputerName(dynamicStore, NULL) autorelease];
}

@interface BDSKSharingServer (ServerThread)

- (void)_cleanupBDSKSharingDOServer;
- (void)runDOServer;

@end

@implementation BDSKSharingServer

+ (void)didLoad;
{
    /* Ensure that computer name changes are propagated as future clients connect to a document.  Also, note that the OS will change the computer name to avoid conflicts by appending "(2)" or similar to the previous name, which is likely the most common scenario.
    */
    if(dynamicStore == NULL){
        CFAllocatorRef alloc = CFAllocatorGetDefault();
        SCDynamicStoreContext SCNSObjectContext = {
            0,                         // version
            (id)nil,                   // any NSCF type
            &retainCallBack,
            &releaseCallBack,
            &copyDescriptionCallBack
        };
        dynamicStore = SCDynamicStoreCreate(alloc, (CFStringRef)[[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleIdentifierKey], &SCDynamicStoreChanged, &SCNSObjectContext);
        CFRunLoopSourceRef rlSource = SCDynamicStoreCreateRunLoopSource(alloc, dynamicStore, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), rlSource, kCFRunLoopCommonModes);
        CFRelease(rlSource);
        CFStringRef key = SCDynamicStoreKeyCreateComputerName(alloc);
        CFArrayRef keys = CFArrayCreate(alloc, (const void **)&key, 1, &kCFTypeArrayCallBacks);
        CFRelease(key);
        
        if(SCDynamicStoreSetNotificationKeys(dynamicStore, keys, NULL) == FALSE)
            fprintf(stderr, "unable to register for dynamic store notifications.\n");
        CFRelease(keys);
    }
    
}

// base name for sharing (also used for storing remote host names in keychain)
+ (NSString *)sharingName;
{
    // docs say to use computer name instead of host name http://developer.apple.com/qa/qa2001/qa1228.html
    NSString *sharingName = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKSharingNameKey];
    if([NSString isEmptyString:sharingName])
        sharingName = BDSKComputerName();
   
    // this is for testing purposes, so we can run several apps on the same computer
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKEnableSharingWithSelfKey"]){
        static int r = 0;
        while (r == 0) r = rand() % 100;
        sharingName = [NSString stringWithFormat:@"%@%i", sharingName, r];
    }        
    return sharingName;
}

// name for localhost thread connection
+ (NSString *)localConnectionName { return [[self class] description]; }

+ (id)defaultServer;
{
    if(sharedInstance == nil && (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_3))
        sharedInstance = [[self alloc] init];
    return sharedInstance;
}

- (id)init
{
    if(self = [super init]){
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleComputerNameChangedNotification:)
                                                     name:BDSKComputerNameChangedNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePasswordChangedNotification:)
                                                     name:BDSKSharingPasswordChangedNotification
                                                   object:nil];
        
#warning use other notifications?
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleBibItemAddDelNotification:)
                                                     name:BDSKDocAddItemNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleBibItemAddDelNotification:)
                                                     name:BDSKDocDelItemNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSharedGroupsChangedNotification:)
                                                     name:BDSKSharedGroupsChangedNotification
                                                   object:nil];

        objectsToNotify = [[NSMutableDictionary alloc] init];
        shouldKeepRunning = 1;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [connection release];
    [objectsToNotify release];
    [super dealloc];
}

- (NSNumber *)numberOfConnections { 
    // minor thread-safety issue here; this may be off by one
    return [NSNumber numberWithUnsignedInt:[objectsToNotify count]]; 
}

// we'll get these notifications on the main thread, and pass off to our secondary thread to handle
- (void)handleBibItemAddDelNotification:(NSNotification *)note;
{
    // not the default connection here; we want to call our background thread, but only if it's running
    if(shouldKeepRunning == 1){
        NSConnection *conn = [NSConnection connectionWithRegisteredName:[BDSKSharingServer localConnectionName] host:nil];
        if(conn == nil)
            NSLog(@"-[%@ %@]: unable to get thread connection", [self class], NSStringFromSelector(_cmd));
        id proxy = [conn rootProxy];
        [proxy setProtocolForProxy:@protocol(BDSKSharingProtocol)];
        [proxy notifyObserversOfChange];
    }
}

- (void)handleSharedGroupsChangedNotification:(NSNotification *)note;
{
    // not the default connection here; we want to call our background thread, but only if it's running
    NSDictionary *userInfo = [note userInfo];
    NSNetService *service = [userInfo objectForKey:@"removedservice"];
    NSString *nameToRemove = nil;
    NSData *TXTData = [service TXTRecordData];
    if(TXTData)
        nameToRemove = [[NSNetService dictionaryFromTXTRecordData:TXTData] objectForKey:BDSKTXTComputerNameKey];
    
    if(nameToRemove != nil && shouldKeepRunning == 1){
                
        NSConnection *conn = [NSConnection connectionWithRegisteredName:[BDSKSharingServer localConnectionName] host:nil];
        if(conn == nil)
            NSLog(@"-[%@ %@]: unable to get thread connection", [self class], NSStringFromSelector(_cmd));
        id proxy = [conn rootProxy];
        [proxy setProtocolForProxy:@protocol(BDSKSharingProtocol)];
        
        // get computer name from NSNetService; will this always work?
        [proxy removeRemoteObserverNamed:nameToRemove];
    }    
}

//  handle changes from the OS
- (void)handleComputerNameChangedNotification:(NSNotification *)note;
{
    // if we're using the computer name, restart sharing so the name propagates correctly; avoid conflicts with other users' share names
    if([NSString isEmptyString:[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKSharingNameKey]])
        [self restartSharingIfNeeded];
}

// handle changes from prefs
- (void)handleSharingNameChangedNotification:(NSNotification *)note;
{
    [self restartSharingIfNeeded];
}

- (void)handlePasswordChangedNotification:(NSNotification *)note;
{
    [self restartSharingIfNeeded];
}

- (void)stopDOServer
{
    // we're in the main thread, so set the stop flag
    // the connect to the remote port should tickle the runloop and cause the thread to exit after cleanup
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&shouldKeepRunning);
    NSConnection *conn = [NSConnection connectionWithRegisteredName:[BDSKSharingServer localConnectionName] host:nil];
    if(conn == nil)
        NSLog(@"-[%@ %@]: unable to get thread connection", [self class], NSStringFromSelector(_cmd));
    id proxy = [conn rootProxy];
    [proxy _cleanupBDSKSharingDOServer];   
}

- (void)enableSharing
{
    if(netService){
        // we're already sharing
        return;
    }
    
    uint16_t chosenPort = 0;
    
    // Here, create the socket from traditional BSD socket calls
    int fdForListening;
    struct sockaddr_in serverAddress;
    socklen_t namelen = sizeof(serverAddress);
    
    if((fdForListening = socket(AF_INET, SOCK_STREAM, 0)) > 0) {
        memset(&serverAddress, 0, sizeof(serverAddress));
        serverAddress.sin_family = AF_INET;
        serverAddress.sin_addr.s_addr = htonl(INADDR_ANY);
        serverAddress.sin_port = 0; // allows the kernel to choose the port for us.
        
        if(bind(fdForListening, (struct sockaddr *)&serverAddress, sizeof(serverAddress)) < 0) {
            close(fdForListening);
            return;
        }
        
        // Find out what port number was chosen for us.
        if(getsockname(fdForListening, (struct sockaddr *)&serverAddress, &namelen) < 0) {
            close(fdForListening);
            return;
        }
        
        chosenPort = ntohs(serverAddress.sin_port);
    }
    
    // lazily instantiate the NSNetService object that will advertise on our behalf
    netService = [[NSNetService alloc] initWithDomain:@"" type:BDSKNetServiceDomain name:[BDSKSharingServer sharingName] port:chosenPort];
    [netService setDelegate:self];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:4];
#warning remove?
    // computer name should be always up-to-date and unique now
    [dictionary setObject:[BDSKSharingBrowser uniqueIdentifier] forKey:BDSKTXTUniqueIdentifierKey];
    [dictionary setObject:@"0" forKey:BDSKTXTVersionKey];
    [dictionary setObject:[BDSKSharingServer sharingName] forKey:BDSKTXTComputerNameKey];
    [netService setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:dictionary]];
    
    [NSThread detachNewThreadSelector:@selector(runDOServer) toTarget:self withObject:nil];
    
    // our DO server will also use Bonjour, but this gives us a browseable name
    [netService publish];

}

- (void)disableSharing
{
    if(netService != nil && shouldKeepRunning == 1){
        [netService stop];
        [netService release];
        netService = nil;
        
        [self stopDOServer];
    }
}

- (void)restartSharingIfNeeded;
{
    if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShouldShareFilesKey]){
        [self disableSharing];
        [self enableSharing];
    }
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
    int err = [[errorDict objectForKey:NSNetServicesErrorCode] intValue];
    NSString *errorMessage = nil;
    switch(err){
        case NSNetServicesUnknownError:
            errorMessage = @"Unknown net services error";
            break;
        case NSNetServicesCollisionError:
            errorMessage = @"Net services collision error";
            break;
        case NSNetServicesNotFoundError:
            errorMessage = @"Net services not found error";
            break;
        case NSNetServicesActivityInProgress:
            errorMessage = @"Net services reports activity in progress";
            break;
        case NSNetServicesBadArgumentError:
            errorMessage = @"Net services bad argument error";
            break;
        case NSNetServicesCancelledError:
            errorMessage = @"Cancelled net service";
            break;
        case NSNetServicesInvalidError:
            errorMessage = @"Net services invalid error";
            break;
        case NSNetServicesTimeoutError:
            errorMessage = @"Net services timeout error";
            break;
        default:
            errorMessage = @"Unrecognized error code from net services";
            break;
    }
    
    errorMessage = NSLocalizedString(errorMessage, @"");
    NSLog(@"-[%@ %@] reports \"%@\"", [self class], NSStringFromSelector(_cmd), errorMessage);
    
    NSString *errorDescription = NSLocalizedString(@"Unable to Share This Document", @"");
    NSString *recoverySuggestion = NSLocalizedString(@"You may wish to disable and re-enable sharing in BibDesk's preferences to see if the error persists.", @"");
    NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:err userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorDescription, NSLocalizedDescriptionKey, errorMessage, NSLocalizedFailureReasonErrorKey, recoverySuggestion, NSLocalizedRecoverySuggestionErrorKey, nil]];

    [self disableSharing];
    
    // show the error in a modal dialog
    [NSApp presentError:error];
}

- (void)netServiceDidStop:(NSNetService *)sender
{
    // We'll need to release the NSNetService sending this, since we want to recreate it in sync with the socket at the other end. Since there's only the one NSNetService in this server, we can just release it.
    [netService release];
    netService = nil;
}

- (NSArray *)snapshotOfPublications
{
    NSMutableSet *set = nil;
    
    // this is only useful if everyone else uses the mutex, though...
    @synchronized([NSDocumentController sharedDocumentController]){
        NSEnumerator *docE = [[[[[NSDocumentController sharedDocumentController] documents] copy] autorelease] objectEnumerator];
        set = [(id)CFSetCreateMutable(CFAllocatorGetDefault(), 0, &BDSKBibItemEqualityCallBacks) autorelease];
        id document = nil;
        while(document = [docE nextObject])
            [set addObjectsFromArray:[document publications]];
    }
    return [set allObjects];
}

- (NSData *)archivedSnapshotOfPublications
{
    NSData *dataToSend = [NSKeyedArchiver archivedDataWithRootObject:[self snapshotOfPublications]];
    if(dataToSend != nil){
        // If we want to make this cross-platform (say if JabRef wanted to add Bonjour support), we could pass BibTeX as another key in the dictionary, and use an XML plist for reading at the other end
        NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:dataToSend, BDSKSharedArchivedDataKey, nil];
        NSString *errorString = nil;
        dataToSend = [NSPropertyListSerialization dataFromPropertyList:dictionary format:NSPropertyListBinaryFormat_v1_0 errorDescription:&errorString];
        if(errorString != nil){
            NSLog(@"Error serializing publications for sharing: %@", errorString);
            [errorString release];
        }
    }
    return dataToSend;
}

#pragma mark -
#pragma mark Server Thread

- (BOOL)connection:(NSConnection *)parentConnection shouldMakeNewConnection:(NSConnection *)newConnection
{
    // set the child connection's delegate so we get authentication messages
    [newConnection setDelegate:self];
    return YES;
}

- (BOOL)authenticateComponents:(NSArray *)components withData:(NSData *)authenticationData
{
    BOOL status = YES;
    if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKSharingRequiresPasswordKey]){
        NSData *myPasswordHashed = [[BDSKPasswordController sharingPasswordForCurrentUserUnhashed] sha1Signature];
        status = [authenticationData isEqual:myPasswordHashed];
    }
    return status;
}

// don't put these in a category, since we have formal protocols to deal with

- (void)runDOServer
{
    // detach a new thread to run this
    NSAssert([NSThread inMainThread] == NO, @"do not run the server in the main thread");
    
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&shouldKeepRunning);
    
    // setup our DO server that will handle requests for publications and passwords
    NSSocketPort *receivePort = [[[NSSocketPort alloc] init] autorelease];
    @try {
        if([[NSSocketPortNameServer sharedInstance] registerPort:receivePort name:[BDSKSharingServer sharingName]] == NO)
            @throw [NSString stringWithFormat:@"Unable to register port %@ and name %@", receivePort, [BDSKSharingServer sharingName]];
        connection = [[NSConnection alloc] initWithReceivePort:receivePort sendPort:nil];
        [connection setRootObject:self];
        
        // so we get connection:shouldMakeNewConnection: messages
        [connection setDelegate:self];
        
        // we'll use this to communicate between threads on the localhost
        // @@ does this succeed after a stop/restart with a new thread?
        NSConnection *threadConnection = [NSConnection defaultConnection];
        if(threadConnection == nil)
            @throw @"Unable to get default connection";
        [threadConnection setRootObject:self];
        if([threadConnection registerName:[BDSKSharingServer localConnectionName]] == NO)
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

- (void)_cleanupBDSKSharingDOServer
{
    // only safe to access this from the server thread
    [objectsToNotify removeAllObjects];
    
    [[NSSocketPortNameServer sharedInstance] removePortForName:[BDSKSharingServer sharingName]];
    [connection invalidate];
    [connection setRootObject:nil];
    [connection release];
    connection = nil;
    
    // default connection retains us as well
    [[NSConnection defaultConnection] setRootObject:nil];
    [[NSConnection defaultConnection] registerName:nil];
    
    // this seems dirty, but we need to unblock and allow the thread to release us
    CFRunLoopStop( CFRunLoopGetCurrent() );
}

- (oneway void)registerHostNameForNotifications:(NSDictionary *)info
{
    NSParameterAssert(info != nil);
    NSString *name = [info objectForKey:@"computer"];
    if(name != nil)
        [objectsToNotify setObject:info forKey:name];
    else
        NSLog(@"Error: missing computer name in %@", info);
}

- (oneway void)notifyObserversOfChange;
{
    // here is where we notify other hosts that something changed
    // get each info dictionary from our table of dictionaries
    NSEnumerator *e = [[NSDictionary dictionaryWithDictionary:objectsToNotify] objectEnumerator];
    NSDictionary *info;
    while(info = [e nextObject]){
        NSString *hostName = [info objectForKey:@"hostname"];
        NSString *portName = [info objectForKey:@"portname"];
        NSPort *sendPort = [[NSSocketPortNameServer sharedInstance] portForName:portName host:hostName];
        
        NSConnection *conn = nil;
        id proxyObject;
        @try {
            conn = [NSConnection connectionWithReceivePort:nil sendPort:sendPort];
            proxyObject = [conn rootProxy];
        }
        @catch (id exception) {
            NSLog(@"client: %@ trying to reach host %@", exception, hostName);
            conn = nil;
            proxyObject = nil;
            // since it's not accessible, remove it from future notifications (we know it has this key)
            [objectsToNotify removeObjectForKey:[info objectForKey:@"computer"]];
        }
        [proxyObject setProtocolForProxy:@protocol(BDSKClientProtocol)];
        if(proxyObject)
            [proxyObject setNeedsUpdate:YES];
        else
            NSLog(@"server: unable to get proxy object for shared group");
    }
    
}

- (oneway void)removeRemoteObserverNamed:(NSString *)computerName;
{
    NSParameterAssert(computerName != nil);
    [objectsToNotify removeObjectForKey:computerName];
}

@end
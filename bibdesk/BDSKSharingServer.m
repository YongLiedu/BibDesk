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

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

static id sharedInstance = nil;
static uint32_t numberOfConnections = 0;

// TXT record keys
NSString *BDSKTXTPasswordKey = @"pass";
NSString *BDSKTXTUniqueIdentifierKey = @"hostid";
NSString *BDSKTXTComputerNameKey = @"name";
NSString *BDSKTXTVersionKey = @"txtvers";

NSString *BDSKSharedArchivedDataKey = @"publications_v1";

// This is the computer name as set in sys prefs (sharing)
static NSString *computerName = nil;

static SCDynamicStoreRef dynamicStore = NULL;
static const void *retainCallBack(const void *info) { return [(id)info retain]; }
static void releaseCallBack(const void *info) { [(id)info release]; }
static CFStringRef copyDescriptionCallBack(const void *info) { return (CFStringRef)[[(id)info description] copy]; }
// convert this to an NSNotification
static void SCDynamicStoreChanged(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info)
{
    // clear this here, since the other handlers may depend on it
    [computerName release];
    computerName = nil;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKComputerNameChangedNotification object:nil];
    
    // update the text field in prefs if necessary (or that could listen for computer name changes...)
    if([NSString isEmptyString:[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKSharingNameKey]])
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharingNameChangedNotification object:nil];
}

NSString *BDSKComputerName() {
    if(computerName == nil){
        computerName = (NSString *)SCDynamicStoreCopyComputerName(dynamicStore, NULL);
        if(computerName == nil){
            NSLog(@"Unable to get computer name with SCDynamicStoreCopyComputerName");
            computerName = [[[[[NSProcessInfo processInfo] hostName] componentsSeparatedByString:@"."] firstObject] copy];
        }
    }
    return computerName;
}

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
    return sharingName;
}

#warning change for release
// this is for testing purposes, so we can run several apps on the same computer
+ (NSString *)sharingServiceName;
{
    static int r = 0;
    while (r == 0) r = rand() % 100;
    return [NSString stringWithFormat:@"%@%i", [self sharingName], r];
}

+ (id)defaultServer;
{
    if(sharedInstance == nil && (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_3))
        sharedInstance = [[self alloc] init];
    return sharedInstance;
}

+ (NSNumber *)numberOfConnections { return [NSNumber numberWithUnsignedInt:numberOfConnections]; }

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
    }
    return self;
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

#pragma mark Exporting our data

- (void)enableSharing
{
    if(netService && listeningSocket){
        // we're already sharing
        return;
    }
    
    uint16_t chosenPort = 0;
    
    // Here, create the socket from traditional BSD socket calls, and then set up an NSFileHandle with that to listen for incoming connections.
    int fdForListening;
    struct sockaddr_in serverAddress;
    socklen_t namelen = sizeof(serverAddress);
    
    // In order to use NSFileHandle's acceptConnectionInBackgroundAndNotify method, we need to create a file descriptor that is itself a socket, bind that socket, and then set it up for listening. At this point, it's ready to be handed off to acceptConnectionInBackgroundAndNotify.
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
        
        if(listen(fdForListening, 1) == 0) {
            listeningSocket = [[NSFileHandle alloc] initWithFileDescriptor:fdForListening closeOnDealloc:YES];
        }
    }
    
    if(!netService) {
        // lazily instantiate the NSNetService object that will advertise on our behalf
        netService = [[NSNetService alloc] initWithDomain:@"" type:BDSKNetServiceDomain name:[BDSKSharingServer sharingServiceName] port:chosenPort];
        [netService setDelegate:self];
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:4];
        [dictionary setObject:[BDSKSharingBrowser uniqueIdentifier] forKey:BDSKTXTUniqueIdentifierKey];
        [dictionary setObject:@"0" forKey:BDSKTXTVersionKey];
        [dictionary setObject:[BDSKSharingServer sharingName] forKey:BDSKTXTComputerNameKey];

        if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKSharingRequiresPasswordKey]){
            NSData *pwData = [BDSKPasswordController sharingPasswordForCurrentUserUnhashed];
            // hash with sha1 so we're not sending it in the clear
            if(pwData != nil)
                [dictionary setObject:[pwData sha1Signature] forKey:BDSKTXTPasswordKey];
        }
        NSData *TXTData = [NSNetService dataFromTXTRecordDictionary:dictionary];
        OBPOSTCONDITION(TXTData != nil);
        [netService setTXTRecordData:TXTData];
    }
    
    if(netService && listeningSocket){
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionReceived:) name:NSFileHandleConnectionAcceptedNotification object:listeningSocket];
        [listeningSocket acceptConnectionInBackgroundAndNotify];
        [netService publish];
    }
}

- (void)disableSharing
{
    if(netService && listeningSocket){
        [netService stop];
        [netService release];
        netService = nil;
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleConnectionAcceptedNotification object:listeningSocket];
        // There is at present no way to get an NSFileHandle to -stop- listening for events, so we'll just have to tear it down and recreate it the next time we need it.
        [listeningSocket release];
        listeningSocket = nil;
        numberOfConnections = 0;
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

    [listeningSocket release];
    listeningSocket = nil;
    [netService release];
    netService = nil;
    
    // show the error in a modal dialog
    [NSApp presentError:error];
}

- (void)netServiceDidStop:(NSNetService *)sender
{
    // We'll need to release the NSNetService sending this, since we want to recreate it in sync with the socket at the other end. Since there's only the one NSNetService in this application, we can just release it.
    [netService release];
    netService = nil;
}

- (NSArray *)snapshotOfPublications
{
    NSEnumerator *docE = [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
    NSMutableSet *set = [(id)CFSetCreateMutable(CFAllocatorGetDefault(), 0, &BDSKBibItemEqualityCallBacks) autorelease];
    id document = nil;
    while(document = [docE nextObject])
        [set addObjectsFromArray:[document publications]];
    return [set allObjects];
}

// This object is also listening for notifications from its NSFileHandle.
// When an incoming connection is seen by the listeningSocket object, we get the NSFileHandle representing the near end of the connection. We write the data to this NSFileHandle instance.
- (void)connectionReceived:(NSNotification *)aNotification{

    // @@ this is not decremented properly; we'd need a two-way connection to keep track for real, I think
    numberOfConnections++;
    
    NSFileHandle *incomingConnection = [[aNotification userInfo] objectForKey:NSFileHandleNotificationFileHandleItem];
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
    if(dataToSend != nil)
        [incomingConnection writeData:dataToSend];
    else
        NSLog(@"Unknown error occurred; no data to share.");
    [incomingConnection closeFile];
    [[aNotification object] acceptConnectionInBackgroundAndNotify];
}

@end

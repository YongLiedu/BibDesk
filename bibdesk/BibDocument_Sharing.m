//
//  BibDocument_Sharing.m
//  Bibdesk
//
//  Created by Adam Maxwell on 03/25/06.
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

#import "BibDocument_Sharing.h"
#import "BDSKGroup.h"
#import "NSArray_BDSKExtensions.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <Security/Security.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

// @@ register with http://www.dns-sd.org/ServiceTypes.html
NSString *BDSKNetServiceDomain = @"_bdsk._tcp.";
static NSString *uniqueIdentifier = nil;

// This is used to determine if a service listed in the browser is from the local host and for display
static NSString *computerName = nil;

/* Much of this was borrowed from Apple's sample code and modified to fit our needs
    file://localhost/Developer/Examples/Foundation/PictureSharing/
    file://localhost/Developer/Examples/Foundation/PictureSharingBrowser/
*/

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

@implementation BibDocument (Sharing)

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
            fprintf(stderr, "%s: unable to register for dynamic store notifications.\n", __PRETTY_FUNCTION__);
        CFRelease(keys);
    }
    
    // use to identify services sent from this machine
    if(uniqueIdentifier == nil){
        /* http://developer.apple.com/qa/qa2001/qa1306.html indicates that ASCII 1 is used to separate old style TXT records, so creating a TXT dictionary with a globallyUniqueString directly is almost guaranteed to fail since they contain alphanumeric characters and underscores; therefore, we'll replace it with something that doesn't seem to appear in globallyUniqueString objects.  An alternative might be to use address comparison, but the docs indicate that the stable identifier for a service is its name, since port number, IP address, and host name can be ephemeral.  Unfortunately, we can't use the service name to determine if a service should be ignored, since we want to ignore all shares from a particular process, not just a given document.
        */
        NSMutableString *pInfo = [[[NSProcessInfo processInfo] globallyUniqueString] mutableCopy];
        [pInfo replaceOccurrencesOfString:@"1" withString:@"~" options:0 range:NSMakeRange(0, [pInfo length])];
        uniqueIdentifier = [pInfo copy];
        [pInfo release];
    }
}

#pragma mark Convenience methods

// this is the name of our keychain entry
+ (NSString *)serviceNameForKeychain { return @"BibDesk Sharing"; }

// TXT record keys
+ (NSString *)TXTPasswordKey { return @"pass"; }
+ (NSString *)TXTUniqueIdentifierKey { return @"hostid"; }
+ (NSString *)TXTComputerNameKey { return @"name"; }
+ (NSString *)TXTVersionKey { return @"txtvers"; }

+ (NSData *)sharingPasswordForCurrentUserUnhashed;
{
    // find pw from keychain
    OSStatus err;
    
    void *passwordData = NULL;
    UInt32 passwordLength = 0;
    NSData *data = nil;
    
    const char *serviceName = [[BibDocument serviceNameForKeychain] UTF8String];
    const char *userName = [NSUserName() UTF8String];
    
    err = SecKeychainFindGenericPassword(NULL, strlen(serviceName), serviceName, strlen(userName), userName, &passwordLength, &passwordData, NULL);
    data = [NSData dataWithBytes:passwordData length:passwordLength];
    SecKeychainItemFreeContent(NULL, passwordData);

    return data;
}

// base name for sharing (also used for storing remote host names in keychain)
+ (NSString *)sharingName;
{
    NSString *sharingName = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKSharingNameKey];
    if([NSString isEmptyString:sharingName])
        sharingName = BDSKComputerName();
    return sharingName;
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

#pragma mark Reading other data

- (void)netServiceDidResolveAddress:(NSNetService *)aNetService
{    
    NSData *TXTData = [aNetService TXTRecordData];
    
    // +[NSNetService dictionaryFromTXTRecordData:] will crash if you pass a nil data
    NSDictionary *TXTDictionary = TXTData ? [NSNetService dictionaryFromTXTRecordData:TXTData] : nil;
    NSString *serviceIdentifier = [[NSString alloc] initWithData:[TXTDictionary objectForKey:[BibDocument TXTUniqueIdentifierKey]] encoding:NSUTF8StringEncoding];

    // In general, we want to ignore our own shared services, as the write/read occur on the same run loop, and our file handle blocks; hence, we listen here for the resolve and then check the TXT record to see where the service came from.

    // Ignore this document; quit/relaunch opening the same doc  can give us a stale service (from the previous run).  Since SystemConfiguration guarantees that we have a unique computer name, this should be safe.
    if([[self netServiceName] isEqualToString:[aNetService name]] == NO){

        // WARNING:  enabling sharing with self can lead to hangs if you use a large file; launching a separate BibDesk process should work around that
        
        // see if service is from this machine (case 1) or we are testing with a single machine (case 2)
        if(([NSString isEmptyString:serviceIdentifier] == NO && [serviceIdentifier isEqualToString:uniqueIdentifier] == NO) ||
           ([[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKEnableSharingWithSelfKey"])){
            
            // we don't want it to message the document again
            [aNetService setDelegate:nil];

            BDSKSharedGroup *group = [[BDSKSharedGroup alloc] initWithService:aNetService];
            [sharedGroups addObject:group];
            [group release];
            [groupTableView reloadData]; 
            
            // remove from the list of unresolved services
            [unresolvedNetServices removeObject:aNetService];
        }
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing 
{
    // set as delegate and resolve, so we can find out if this originated from the localhost or a remote machine
    // we can't access TXT records until the service is resolved (this is documented in CFNetService, not NSNetService)
    [aNetService setDelegate:self];
    [aNetService resolveWithTimeout:5.0];
    [unresolvedNetServices addObject:aNetService];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    NSEnumerator *e = [sharedGroups objectEnumerator];
    NSMutableArray *array = [NSMutableArray array];
    BDSKSharedGroup *group;
    
    // create an array of the groups we should keep by comparing services with the one that just went away
    while(group = [e nextObject])
        if([[group service] isEqual:aNetService] == NO)
            [array addObject:group];
    
    [sharedGroups setArray:array];
    [groupTableView reloadData];
}

- (void)enableSharedBrowsing;
{
    // lazily create the shared resources
    NSAssert(sharedGroups == nil, @"It is an error to enable browsing twice");
    
    sharedGroups = [[NSMutableArray alloc] initWithCapacity:5];
    browser = [[NSNetServiceBrowser alloc] init];
    [browser setDelegate:self];
    [browser searchForServicesOfType:BDSKNetServiceDomain inDomain:@""];    
}

- (void)disableSharedBrowsing;
{
    [sharedGroups release];
    sharedGroups = nil;
    [browser release];
    browser = nil;
    [groupTableView reloadData];
}

- (NSString *)netServiceName;
{
    NSString *documentName = [[[self fileName] lastPathComponent] stringByDeletingPathExtension];
    // @@ probably shouldn't share unsaved files
    if(documentName == nil) documentName = [self displayName];
    
    // docs say to use computer name instead of host name http://developer.apple.com/qa/qa2001/qa1228.html
    // we append document name since the same computer vends multiple documents
    return [NSString stringWithFormat:@"%@ - %@", [BibDocument sharingName], documentName];
}

#pragma mark Exporting our data

- (void)enableSharing
{
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
        netService = [[NSNetService alloc] initWithDomain:@"" type:BDSKNetServiceDomain name:[self netServiceName] port:chosenPort];
        [netService setDelegate:self];
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:4];
        [dictionary setObject:uniqueIdentifier forKey:[BibDocument TXTUniqueIdentifierKey]];
        [dictionary setObject:@"0" forKey:[BibDocument TXTVersionKey]];
        
        if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKSharingRequiresPasswordKey]){
            NSData *pwData = [BibDocument sharingPasswordForCurrentUserUnhashed];
            // hash with sha1 so we're not sending it in the clear
            if(pwData != nil)
                [dictionary setObject:[pwData sha1Signature] forKey:[BibDocument TXTPasswordKey]];
            [dictionary setObject:[BibDocument sharingName] forKey:[BibDocument TXTComputerNameKey]];
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
    [self presentError:error];
}

- (void)netServiceDidStop:(NSNetService *)sender
{
    // We'll need to release the NSNetService sending this, since we want to recreate it in sync with the socket at the other end. Since there's only the one NSNetService in this application, we can just release it.
    [netService release];
    netService = nil;
}

// This object is also listening for notifications from its NSFileHandle.
// When an incoming connection is seen by the listeningSocket object, we get the NSFileHandle representing the near end of the connection. We write the data to this NSFileHandle instance.
- (void)connectionReceived:(NSNotification *)aNotification{
    NSFileHandle *incomingConnection = [[aNotification userInfo] objectForKey:NSFileHandleNotificationFileHandleItem];
    NSData *dataToSend = [NSKeyedArchiver archivedDataWithRootObject:publications];
    if(dataToSend != nil){
        // If we want to make this cross-platform (say if JabRef wanted to add Bonjour support), we could pass BibTeX as another key in the dictionary, and use an XML plist for reading at the other end
        NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:dataToSend, [BibDocument sharedArchivedDataKey], nil];
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

+ (NSString *)sharedArchivedDataKey { return @"publications_v1"; }

@end

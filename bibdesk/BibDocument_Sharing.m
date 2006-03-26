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

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

// @@ register with http://www.dns-sd.org/ServiceTypes.html
NSString *BDSKNetServiceDomain = @"_bdsk._tcp.";

/* Much of this was borrowed from Apple's sample code and modified to fit our needs
    file://localhost/Developer/Examples/Foundation/PictureSharing/
    file://localhost/Developer/Examples/Foundation/PictureSharingBrowser/
*/

@implementation BibDocument (Sharing)

#pragma mark Reading other data

// This object is the delegate of its NSNetServiceBrowser object. We're only interested in services-related methods, so that's what we'll call.
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing 
{
#warning fixme
    // we need to keep from adding our own host's services, but this is convenient for testing
    // should be able to check the prefix of the string against our own host name
    if([[self netServiceName] isEqualToString:[aNetService name]] == NO){
        BDSKSharedGroup *group = [[BDSKSharedGroup alloc] initWithService:aNetService];
        [sharedGroups addObject:group];
        [group release];
        [groupTableView reloadData];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    NSEnumerator *e = [sharedGroups objectEnumerator];
    NSMutableArray *array = [NSMutableArray array];
    BDSKSharedGroup *group;
    while(group = [e nextObject])
        if([[group service] isEqual:aNetService] == NO)
            [array addObject:group];
    
    [sharedGroups setArray:array];
    [groupTableView reloadData];
}

// need notification handlers for enable/disable listening as well, for changes from prefs
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
    NSString *serviceName = [[[self fileName] lastPathComponent] stringByDeletingPathExtension];
    // @@ probably shouldn't share unsaved files
    if(serviceName == nil) serviceName = [self displayName];
    NSString *hostName = [(id)SCDynamicStoreCopyComputerName(NULL, NULL) autorelease];
    if(hostName == nil){
        NSLog(@"Unable to get hostname with SCDynamicStoreCopyComputerName");
        hostName = [[[[NSProcessInfo processInfo] hostName] componentsSeparatedByString:@"."] firstObject];
    }
    return [NSString stringWithFormat:@"%@ - %@", hostName, serviceName];
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

// @@ add prefs to enable/disable
- (void)handleDisableSharingNotification:(NSNotification *)note
{
    [self disableSharing];
}    

- (void)handleEnableSharingNotification:(NSNotification *)note
{
    [self enableSharing];
}    

// This object is the delegate of its NSNetService. It should implement the NSNetServiceDelegateMethods that are relevant for publication (see NSNetServices.h).
- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
    // @@ taken from Apple's code; add more error messages (use NSError and present?)
    // Display some meaningful error message here, using the longerStatusText as the explanation.
    if([[errorDict objectForKey:NSNetServicesErrorCode] intValue] == NSNetServicesCollisionError) {
        NSLog(@"A name collision occurred. A service is already running with that name someplace else.");
    } else {
        NSLog(@"Some other unknown error occurred.");
    }
    [listeningSocket release];
    listeningSocket = nil;
    [netService release];
    netService = nil;
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
    [[aNotification object] acceptConnectionInBackgroundAndNotify];
    [incomingConnection writeData:dataToSend];
    [incomingConnection closeFile];
}

@end

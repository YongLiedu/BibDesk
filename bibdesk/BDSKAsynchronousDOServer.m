//
//  BDSKAsynchronousDOServer.m
//  Bibdesk
//
//  Created by Adam Maxwell on 04/24/06.
/*
 This software is Copyright (c) 2006,2007,2008
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

#import "BDSKAsynchronousDOServer.h"

struct BDSKDOServerFlags {
    volatile int32_t shouldKeepRunning __attribute__ ((aligned (4)));
    volatile int32_t serverDidSetup __attribute__ ((aligned (4)));
    volatile int32_t serverDidStart __attribute__ ((aligned (4)));
};

// protocols for the server thread proxies, must be included in protocols used by subclasses
@protocol BDSKAsyncDOServerThread
// override for custom cleanup on the server thread; call super afterwards
- (oneway void)cleanup; 
@end

@protocol BDSKAsyncDOServerMainThread
- (void)setLocalServer:(byref id)anObject;
@end


@interface BDSKAsynchronousDOServer (Private)
// avoid categories in the implementation, since categories and formal protocols don't mix
- (void)runDOServerForPorts:(NSArray *)ports;
@end

@implementation BDSKAsynchronousDOServer

- (void)checkStartup:(NSTimer *)ignored
{
    if (0 == serverFlags->serverDidStart)
        NSLog(@"*** Warning *** %@ has not been started after 1 second", self);
}

- (id)init
{
    if (self = [super init]) {       
        // set up flags
        serverFlags = NSZoneCalloc(NSDefaultMallocZone(), 1, sizeof(struct BDSKDOServerFlags));
        serverFlags->shouldKeepRunning = 1;
        serverFlags->serverDidSetup = 0;
        serverFlags->serverDidStart = 0;

#if OMNI_FORCE_ASSERTIONS
        // check for absentminded developers; there's no actual requirement that startDOServer be called immediately
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkStartup:) userInfo:nil repeats:NO];
#endif    
        
        // these will be set when the background thread sets up
        localThreadConnection = nil;
        serverOnMainThread = nil;
        serverOnServerThread = nil;
    }
    return self;
}

- (void)dealloc
{
    NSZoneFree(NSDefaultMallocZone(), serverFlags);
    [super dealloc];
}

#pragma mark Proxies

- (Protocol *)protocolForServerThread;
{ 
    return @protocol(BDSKAsyncDOServerThread); 
}

- (Protocol *)protocolForMainThread;
{ 
    return @protocol(BDSKAsyncDOServerMainThread); 
}

// Access to these objects is limited to the creating threads (we assume that it's initially created on the main thread).  If you want to communicate with the server from yet another thread, that thread needs to create its own connection and proxy object(s), which would also require access to the server's connection ivars.  Possibly using -enableMultipleThreads on both connections would work, but the documentation is too vague to be useful.

- (id)serverOnMainThread { 
    OBASSERT([[NSThread currentThread] isEqual:serverThread]);
    return serverOnMainThread; 
}

- (id)serverOnServerThread { 
    OBASSERT([NSThread inMainThread]);
    return serverOnServerThread; 
}

#pragma mark Main Thread

- (void)setLocalServer:(byref id)anObject;
{
    OBASSERT([NSThread inMainThread]);
    [anObject setProtocolForProxy:[self protocolForServerThread]];
    serverOnServerThread = [anObject retain];
}

- (void)startDOServer;
{
    // set up a connection to communicate with the local background thread
    NSPort *port1 = [NSPort port];
    NSPort *port2 = [NSPort port];
    
    mainThreadConnection = [[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
    [mainThreadConnection setRootObject:self];
    
    // enable explicitly; we don't want this, but it's set by default on 10.5 and we need to be uniform for debugging
    [mainThreadConnection enableMultipleThreads];
    
    // run a background thread to connect to the remote server
    // this will connect back to the connection we just set up
    [NSThread detachNewThreadSelector:@selector(runDOServerForPorts:) toTarget:self withObject:[NSArray arrayWithObjects:port2, port1, nil]];
    
    // It would be really nice if we could just wait on a condition lock here, but
    // then this thread's runloop can't pick up the -setLocalServer message since
    // it's blocking (the runloop can't service the ports).
    do {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        OSMemoryBarrier();
    } while (serverFlags->serverDidSetup == 0 && serverFlags->shouldKeepRunning == 1);    
}

#pragma mark Server Thread

- (oneway void)cleanup;
{   
    OBASSERT([[NSThread currentThread] isEqual:serverThread]);
    // clean up the connection in the server thread
    [localThreadConnection setRootObject:nil];
    
    // this frees up the CFMachPorts created in -init
    [[localThreadConnection receivePort] invalidate];
    [[localThreadConnection sendPort] invalidate];
    [localThreadConnection invalidate];
    [localThreadConnection release];
    localThreadConnection = nil;
    
    [serverOnMainThread release];
    serverOnMainThread = nil;  
    serverThread = nil;
}

- (void)runDOServerForPorts:(NSArray *)ports;
{
    // detach a new thread to run this
    NSAssert([NSThread inMainThread] == NO, @"do not run the server in the main thread");
    NSAssert(localThreadConnection == nil, @"server is already running");
    
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&serverFlags->shouldKeepRunning);
    
    @try {
        
        // this thread retains the server object
        serverThread = [NSThread currentThread];
        
        // we'll use this to communicate between threads on the localhost
        localThreadConnection = [[NSConnection alloc] initWithReceivePort:[ports objectAtIndex:0] sendPort:[ports objectAtIndex:1]];
        if(localThreadConnection == nil)
            @throw @"Unable to create localThreadConnection";
        [localThreadConnection setRootObject:self];
        
        // enable explicitly; we don't need this, but it's set by default on 10.5 and we need to be uniform for debugging
        [localThreadConnection enableMultipleThreads];
        
        serverOnMainThread = [[localThreadConnection rootProxy] retain];
        [serverOnMainThread setProtocolForProxy:[self protocolForMainThread]];
        // handshake, this sets the proxy at the other side
        [serverOnMainThread setLocalServer:self];
        
        // allow subclasses to do some custom setup
        [self serverDidSetup];
        OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&serverFlags->serverDidSetup);
        
        NSRunLoop *rl = [NSRunLoop currentRunLoop];
        NSDate *distantFuture = [[NSDate distantFuture] retain];
        BOOL didRun;
        
        // see http://lists.apple.com/archives/cocoa-dev/2006/Jun/msg01054.html for a helpful explanation of NSRunLoop
        do {
            [pool release];
            pool = [NSAutoreleasePool new];
            didRun = [rl runMode:NSDefaultRunLoopMode beforeDate:distantFuture];
            OSMemoryBarrier();
        } while (serverFlags->shouldKeepRunning == 1 && didRun);
        
        [distantFuture release];
    }
    @catch(id exception) {
        NSLog(@"Exception \"%@\" raised in object %@", exception, self);
        
        // arm: I'm don't recall why shouldKeepRunning is reset; the thread will exit
        // reset the flag so we can start over; shouldn't be necessary
        OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&serverFlags->shouldKeepRunning);
        
        // allow the main thread to continue, anyway
        OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&serverFlags->serverDidSetup);
    }
    
    @finally {
        [pool release];
    }
}

- (void)serverDidSetup{}

#pragma mark API
#pragma mark Main Thread

- (void)startDOServerSync;
{
    OBASSERT([NSThread inMainThread]);   
    // no need for memory barrier functions here since there's no thread yet
    serverFlags->serverDidSetup = 0;
    serverFlags->serverDidStart = 1;
    [self startDOServer];
}

- (void)startDOServerAsync;
{
    OBASSERT([NSThread inMainThread]); 
    // no need for memory barrier functions here since there's no thread yet
    // set serverDidSetup to 1 so we don't wait in startDOServer
    serverFlags->serverDidSetup = 1;
    serverFlags->serverDidStart = 1;
    [self startDOServer];
}

- (void)stopDOServer;
{
    OBASSERT([NSThread inMainThread]);
    // this cleans up the connections, ports and proxies on both sides
    [serverOnServerThread cleanup];
    // we're in the main thread, so set the stop flag
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&serverFlags->shouldKeepRunning);
    
    // clean up the connection in the main thread; don't invalidate the ports, since they're still in use
    [mainThreadConnection setRootObject:nil];
    [mainThreadConnection invalidate];
    [mainThreadConnection release];
    mainThreadConnection = nil;
    
    [serverOnServerThread release];
    serverOnServerThread = nil;    
}

#pragma mark Thread Safe

- (BOOL)shouldKeepRunning { 
    OSMemoryBarrier();
    return serverFlags->shouldKeepRunning == 1; 
}

@end

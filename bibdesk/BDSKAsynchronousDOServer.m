//
//  BDSKAsynchronousDOServer.m
//  Bibdesk
//
//  Created by Adam Maxwell on 04/24/06.
/*
 This software is Copyright (c) 2006-2011
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
    volatile int32_t shouldKeepRunning;
    volatile int32_t serverDidSetup;
#ifdef DEBUG
    volatile int32_t serverDidStart;
#endif
};

// protocols for the server thread proxies, must be included in protocols used by subclasses
@protocol BDSKAsyncDOServerThread
- (oneway void)stopRunning; 
@end

@protocol BDSKAsyncDOServerMainThread
- (void)setLocalServer:(byref id)anObject;
@end


@interface BDSKAsynchronousDOServer (Private)
// avoid categories in the implementation, since categories and formal protocols don't mix
- (void)runDOServerForPorts:(NSArray *)ports;
@end

@implementation BDSKAsynchronousDOServer

#ifdef DEBUG
- (void)checkStartup:(NSTimer *)ignored
{
    if (0 == serverFlags->serverDidStart)
        NSLog(@"*** Warning *** %@ has not been started after 1 second", self);
}
#endif

- (id)init
{
    self = [super init];
    if (self) {       
        // set up flags
        serverFlags = NSZoneCalloc(NSDefaultMallocZone(), 1, sizeof(struct BDSKDOServerFlags));
        serverFlags->shouldKeepRunning = 1;
        serverFlags->serverDidSetup = 0;
#ifdef DEBUG
        serverFlags->serverDidStart = 0;

        // check for absentminded developers; there's no actual requirement that startDOServer be called immediately
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkStartup:) userInfo:nil repeats:NO];
#endif    
        
        // these will be set when the background thread sets up
        localThreadConnection = nil;
        serverOnMainThread = nil;
        serverOnServerThread = nil;
        stopRunning = NO;
    }
    return self;
}

- (void)dealloc
{
    BDSKZONEDESTROY(serverFlags);
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
    BDSKASSERT([[NSThread currentThread] isEqual:serverThread]);
    return serverOnMainThread; 
}

- (id)serverOnServerThread { 
    BDSKASSERT([NSThread isMainThread]);
    return serverOnServerThread; 
}

#pragma mark Main Thread

- (void)setLocalServer:(byref id)anObject;
{
    BDSKASSERT([NSThread isMainThread]);
    BDSKASSERT(protocol_conformsToProtocol([self protocolForServerThread], @protocol(BDSKAsyncDOServerThread)));
    [anObject setProtocolForProxy:[self protocolForServerThread]];
    serverOnServerThread = [anObject retain];
}

- (void)startDOServer;
{
#ifdef DEBUG
    serverFlags->serverDidStart = 1;
#endif
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
        SInt32 result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, TRUE);
        if (kCFRunLoopRunFinished == result || kCFRunLoopRunStopped == result)
            OSAtomicCompareAndSwap32Barrier(1, 0, &serverFlags->shouldKeepRunning);
        else
            OSMemoryBarrier();
    } while (serverFlags->serverDidSetup == 0 && serverFlags->shouldKeepRunning == 1);    
}

#pragma mark Server Thread

- (oneway void)stopRunning {
    BDSKASSERT([[NSThread currentThread] isEqual:serverThread]);
    // signal to stop running the run loop
    stopRunning = YES;
}

- (void)runDOServerForPorts:(NSArray *)ports;
{
    // detach a new thread to run this
    NSAssert([NSThread isMainThread] == NO, @"do not run the server in the main thread");
    NSAssert(localThreadConnection == nil, @"server is already running");
    
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
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
        BDSKASSERT(protocol_conformsToProtocol([self protocolForMainThread], @protocol(BDSKAsyncDOServerMainThread)));
        [serverOnMainThread setProtocolForProxy:[self protocolForMainThread]];
        // handshake, this sets the proxy at the other side
        [serverOnMainThread setLocalServer:self];
        
        // allow subclasses to do some custom setup
        [self serverDidSetup];
        OSAtomicCompareAndSwap32Barrier(0, 1, &serverFlags->serverDidSetup);
        
        NSRunLoop *rl = [NSRunLoop currentRunLoop];
        NSDate *distantFuture = [[NSDate distantFuture] retain];
        BOOL didRun;
        
        // see http://lists.apple.com/archives/cocoa-dev/2006/Jun/msg01054.html for a helpful explanation of NSRunLoop
        do {
            [pool release];
            pool = [NSAutoreleasePool new];
            didRun = [rl runMode:NSDefaultRunLoopMode beforeDate:distantFuture];
        } while (stopRunning == NO && didRun);
        
        [distantFuture release];
    }
    @catch(id exception) {
        NSLog(@"Exception \"%@\" raised in object %@", exception, self);
        // allow the main thread to continue, anyway
        OSAtomicCompareAndSwap32Barrier(0, 1, &serverFlags->serverDidSetup);
    }
    
    @finally {
        // allow subclasses to do some custom cleanup
        [self serverDidFinish];
        
        // clean up the connection in the server thread
        [localThreadConnection setRootObject:nil];
        
        // this frees up the CFMachPorts created in -init
        [[localThreadConnection receivePort] invalidate];
        [[localThreadConnection sendPort] invalidate];
        [localThreadConnection invalidate];
        BDSKDESTROY(localThreadConnection);
        BDSKDESTROY(serverOnMainThread);  
        serverThread = nil;
        
        [pool release];
    }
}

- (void)serverDidSetup{}
- (void)serverDidFinish{}

#pragma mark API
#pragma mark Main Thread

- (void)startDOServerSync;
{
    BDSKASSERT([NSThread isMainThread]);   
    // no need for memory barrier functions here since there's no thread yet
    serverFlags->serverDidSetup = 0;
    [self startDOServer];
}

- (void)startDOServerAsync;
{
    BDSKASSERT([NSThread isMainThread]); 
    // no need for memory barrier functions here since there's no thread yet
    // set serverDidSetup to 1 so we don't wait in startDOServer
    serverFlags->serverDidSetup = 1;
    [self startDOServer];
}

- (void)stopDOServer;
{
    BDSKASSERT([NSThread isMainThread]);
    // set the stop flag, so any long process (possibly with loops) knows it can return
    OSAtomicCompareAndSwap32Barrier(1, 0, &serverFlags->shouldKeepRunning);
    // this is mainly to tickle the runloop on the server thread so it will finish
    [serverOnServerThread stopRunning];
    
    // clean up the connection in the main thread; don't invalidate the ports, since they're still in use
    [mainThreadConnection setRootObject:nil];
    [mainThreadConnection invalidate];
    BDSKDESTROY(mainThreadConnection);
    BDSKDESTROY(serverOnServerThread);    
}

#pragma mark Thread Safe

- (BOOL)shouldKeepRunning { 
    OSMemoryBarrier();
    return serverFlags->shouldKeepRunning == 1; 
}

@end

//
//  BDSKSkimReader.m
//  Bibdesk
//
//  Created by Adam Maxwell on 04/09/07.
/*
 This software is Copyright (c) 2007-2008
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

#import "BDSKSkimReader.h"
#import "NSWorkspace_BDSKExtensions.h"

@protocol SKAgentListenerProtocol

- (bycopy NSData *)SkimNotesAtPath:(in bycopy NSString *)aFile;
- (bycopy NSData *)RTFNotesAtPath:(in bycopy NSString *)aFile;
- (bycopy NSString *)textNotesAtPath:(in bycopy NSString *)aFile;

@end

// Argument passed; this will be unique to the client app, so multiple processes can run a SkimNotesAgent.  Alternately, we could run it via launchd or as a login item and allow any app to talk to it.  This is easier for the present.
#define AGENT_IDENTIFIER @"net_sourceforge_bibdesk_skimnotesagent"
#define AGENT_TIMEOUT 1.0f

@implementation BDSKSkimReader

+ (id)sharedReader;
{
    static id sharedInstance = nil;
    if (nil == sharedInstance)
        sharedInstance = [[self alloc] init];
    return sharedInstance;
}

- (void)destroyConnection;
{
    [agent release];
    agent = nil;
    
    [[connection receivePort] invalidate];
    [[connection sendPort] invalidate];
    [connection invalidate];
    [connection release];
    connection = nil;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self destroyConnection];
    [super dealloc];
}

- (void)handleConnectionDied:(NSNotification *)note;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSConnectionDidDieNotification object:[note object]];
    // ensure the proxy ivar and ports are cleaned up; is it still okay to message it?
    [self destroyConnection];
}

- (BOOL)launchedTask;
{
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:[[NSBundle mainBundle] pathForResource:@"SkimNotesAgent" ofType:nil]];
    [task setArguments:[NSArray arrayWithObject:AGENT_IDENTIFIER]];
    BOOL taskLaunched = NO;
    
#if OMNI_FORCE_ASSERTIONS
    [task setStandardError:[NSFileHandle fileHandleWithStandardError]];
    NSPipe *aPipe = [NSPipe pipe];
    [task setStandardOutput:aPipe];
    @try {
        [task launch];
        NSData *data = [[aPipe fileHandleForReading] readDataToEndOfFile];
        NSLog(@"SkimNotesAgent started with identifier \"%@\"", [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]);
        taskLaunched = [task isRunning];
    }
#else
    // task will print the identifier to standard output; we don't care about it, since we specified it
    [task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
    [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
    @try {
        [task launch];
        taskLaunched = [task isRunning];
    }
#endif
    
    @catch(id exception){
        NSLog(@"failed to launch SkimNotesAgent: %@", exception);
        taskLaunched = NO;
    }
    [task release];
    return taskLaunched;
}    

- (void)establishConnection;
{
    static int numberOfConnectionAttempts = 0;
    if (numberOfConnectionAttempts++ > 100) {
        static BOOL didWarn = NO;
        if (NO == didWarn) {
            NSLog(@"*** Insane number of Skim agent connection failures; disabling further attempts ***");
            didWarn = YES;
        }
        return;
    }
    
    // okay to launch multiple instances, since the new one will just die, but we generally shouldn't do that
    OBPRECONDITION(nil == connection);

    // no point in trying to connect if the task didn't launch
    if ([self launchedTask]) {
        int maxTries = 5;
        connection = [[NSConnection connectionWithRegisteredName:AGENT_IDENTIFIER host:nil] retain];

        // if we try to read data before the server is fully set up, connection will still be nil
        while (nil == connection && maxTries--) { 
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            connection = [[NSConnection connectionWithRegisteredName:AGENT_IDENTIFIER host:nil] retain];
        }
        
        if (connection) {
            
            // keep an eye on the connection from our end, so we can retain the proxy object
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleConnectionDied:) name:NSConnectionDidDieNotification object:connection];
        
            // if we don't set these explicitly, timeout never seems to take place
            [connection setRequestTimeout:AGENT_TIMEOUT];
            [connection setReplyTimeout:AGENT_TIMEOUT];
            
            @try {
                id server = [connection rootProxy];
                [server setProtocolForProxy:@protocol(SKAgentListenerProtocol)];
                agent = [server retain];
            }
            @catch(id exception) {
                NSLog(@"Discarding exception %@ caught when contacting SkimNotesAgent", exception);
                [self destroyConnection];
            }
        }
    }
    OBPOSTCONDITION(nil != connection);
}    

- (BOOL)connectAndCheckTypeOfFile:(NSURL *)fileURL;
{
    OBASSERT([fileURL isFileURL]);
    if (nil == connection)
        [self establishConnection];
    
    // these checks are client side to avoid connecting to the server unless it's really necessary
    CFStringRef type = (CFStringRef)[[NSWorkspace sharedWorkspace] UTIForURL:fileURL];
    if (UTTypeConformsTo(type, kUTTypePDF) || UTTypeConformsTo(type, CFSTR("com.adobe.postscript")) ||
        UTTypeConformsTo(type, CFSTR("net.sourceforge.skim-app.pdfd")) || UTTypeConformsTo(type, CFSTR("net.sourceforge.skim-app.skimnotes")))
        return YES;

    return NO;
}

- (NSData *)SkimNotesAtURL:(NSURL *)fileURL;
{   
    NSData *data = nil;
    if ([self connectAndCheckTypeOfFile:fileURL]) {
        @try{
            data = [agent SkimNotesAtPath:[fileURL path]];
        }
        @catch(id exception){
            data = nil;
            NSLog(@"-[BDSKSkimReader SkimNotesAtURL:] caught %@ while contacting skim agent; please report this", exception);
            [self destroyConnection];
        }
    }
    return data;
}

- (NSData *)RTFNotesAtURL:(NSURL *)fileURL;
{   
    NSData *data = nil;
    if ([self connectAndCheckTypeOfFile:fileURL]) {
        @try{
            data = [agent RTFNotesAtPath:[fileURL path]];
        }
        @catch(id exception){
            data = nil;
            NSLog(@"-[BDSKSkimReader RTFNotesAtURL:] caught %@ while contacting skim agent; please report this", exception);
            [self destroyConnection];
        }
    }
    return data;
}

- (NSString *)textNotesAtURL:(NSURL *)fileURL;
{   
    NSString *string = nil;
    if ([self connectAndCheckTypeOfFile:fileURL]) {
        @try{
            string = [agent textNotesAtPath:[fileURL path]];
        }
        @catch(id exception){
            string = nil;
            NSLog(@"-[BDSKSkimReader textNotesAtURL:] caught %@ while contacting skim agent; please report this", exception);
            [self destroyConnection];
        }
    }
    return string;
}


@end

//
//  BDSKSkimReader.m
//  Bibdesk
//
//  Created by Adam Maxwell on 04/09/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BDSKSkimReader.h"
#import "NSWorkspace_BDSKExtensions.h"

@protocol ListenerProtocol

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

- (void)establishConnection;
{
    // okay to launch multiple instances, since the new one will just die
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:[[NSBundle mainBundle] pathForResource:@"SkimNotesAgent" ofType:nil]];
    [task setArguments:[NSArray arrayWithObject:AGENT_IDENTIFIER]];
    [task setStandardOutput:[NSFileHandle fileHandleWithStandardOutput]];
    [task launch];
    [task release];
    
    int maxTries = 5;
    connection = [[NSConnection connectionWithRegisteredName:AGENT_IDENTIFIER host:nil] retain];

    // if we try to read data before the server is fully set up, connection will still be nil
    while (nil == connection && maxTries--) { 
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        connection = [[NSConnection connectionWithRegisteredName:AGENT_IDENTIFIER host:nil] retain];
    }
    
    // if we don't set these explicitly, timeout never seems to take place
    [connection setRequestTimeout:AGENT_TIMEOUT];
    [connection setReplyTimeout:AGENT_TIMEOUT];
}    

- (void)destroyConnection;
{
    [[connection receivePort] invalidate];
    [[connection sendPort] invalidate];
    [connection invalidate];
    [connection release];
    connection = nil;
}

- (void)dealloc
{
    [self destroyConnection];
    [super dealloc];
}

- (BOOL)connectAndCheckTypeOfFile:(NSURL *)fileURL;
{
    NSParameterAssert([fileURL isFileURL]);
    if (nil == connection)
        [self establishConnection];
    
    BOOL isDir;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[fileURL path] isDirectory:&isDir] == NO || isDir)
        return NO;
    
    // make sure it's a PDF file before hitting the server...
    if (UTTypeConformsTo((CFStringRef)[[NSWorkspace sharedWorkspace] UTIForURL:fileURL], kUTTypePDF) == FALSE)
        return NO;
    return YES;
}

- (NSData *)RTFNotesAtURL:(NSURL *)fileURL;
{   
    NSData *data = nil;
    if ([self connectAndCheckTypeOfFile:fileURL]) {
        @try {
            id server = [connection rootProxy];
            [server setProtocolForProxy:@protocol(ListenerProtocol)];
            data = [server RTFNotesAtPath:[fileURL path]];
        }
        @catch(id exception) {
            NSLog(@"Discarding exception %@ caught when contacting SkimNotesAgent", exception);
            data = nil;
            [self destroyConnection];
        }
    }
    return data;
}

- (NSString *)textNotesAtURL:(NSURL *)fileURL;
{   
    NSData *RTF = [self RTFNotesAtURL:fileURL];
    return RTF ? [[[[NSAttributedString alloc] initWithRTF:RTF documentAttributes:NULL] autorelease] string] : nil;
    
    // not functional yet; worth it?
    NSString *string = nil;
    if ([self connectAndCheckTypeOfFile:fileURL]) {
        @try {
            id server = [connection rootProxy];
            [server setProtocolForProxy:@protocol(ListenerProtocol)];
            string = [server textNotesAtPath:[fileURL path]];
        }
        @catch(id exception) {
            NSLog(@"Discarding exception %@ caught when contacting SkimNotesAgent", exception);
            string = nil;
            [self destroyConnection];
        }
    }
    return string;
}


@end

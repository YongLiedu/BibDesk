//
//  BDSKCompletionServer.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 6/11/10.
/*
 This software is Copyright (c) 2010-2011
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKCompletionServer.h"
#import "BDSKCompletionServerProtocol.h"
#import "BibDocument.h"
#import "BDSKSearchForCommand.h"
#import "BDSKPublicationsArray.h"

#define BIBDESK_SERVER_NAME @"BDSKCompletionServer"

@implementation BDSKCompletionServer

static id sharedCompletionServer = nil;

+ (id)sharedCompletionServer {
    if (sharedCompletionServer == nil)
        sharedCompletionServer = [[self alloc] init];
    return sharedCompletionServer;
}

- (void)handleApplicationWillTerminate:(NSNotification *)note {
    [connection registerName:nil];
    [[connection receivePort] invalidate];
    [[connection sendPort] invalidate];
    [connection invalidate];
    BDSKDESTROY(connection);
}

- (id)init {
    BDSKPRECONDITION(sharedCompletionServer == nil);
    if (self = [super init]) {
        connection = [[NSConnection alloc] initWithReceivePort:[NSPort port] sendPort:nil];
        NSProtocolChecker *checker = [NSProtocolChecker protocolCheckerWithTarget:self protocol:@protocol(BDSKCompletionServer)];
        [connection setRootObject:checker];
        
        if ([connection registerName:BIBDESK_SERVER_NAME] == NO) {
            NSLog(@"failed to register completion connection; another BibDesk process must be running");
            [self handleApplicationWillTerminate:nil];
        } else {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillTerminate:) name:NSApplicationWillTerminateNotification object:NSApp];
        }
            
    }
    return self;
}

#pragma mark BDSKCompletionServer protocol

- (NSArray *)completionsForString:(NSString *)searchString;
{
	NSMutableArray *results = [NSMutableArray array];

    // for empty search string, return all items

    for (BibDocument *document in [NSApp orderedDocuments]) {
        
        NSArray *pubs = [NSString isEmptyString:searchString] ? [document publications] : [document findMatchesFor:searchString];
        [results addObjectsFromArray:[pubs valueForKey:@"completionObject"]];
    }
	return results;
}

- (NSArray *)orderedDocumentURLs;
{
    NSMutableArray *theURLs = [NSMutableArray array];
    for (id aDoc in [NSApp orderedDocuments]) {
        if ([aDoc fileURL])
            [theURLs addObject:[aDoc fileURL]];
    }
    return theURLs;
}

@end

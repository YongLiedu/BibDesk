//
//  BDSKSearchGroupServerManager.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/4/10.
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

#import "BDSKSearchGroupServerManager.h"
#import "BDSKServerInfo.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSWorkspace_BDSKExtensions.h"

#define SERVERS_FILENAME @"SearchGroupServers"
#define SERVERS_DIRNAME @"SearchGroupServers"

@implementation BDSKSearchGroupServerManager

static BDSKSearchGroupServerManager *sharedManager = nil;

+ (BDSKSearchGroupServerManager *)sharedManager {
    if (sharedManager == nil)
        sharedManager = [[self alloc] init];
    return sharedManager;
}

static BOOL isSearchFileAtPath(NSString *path) {
    return [[[NSWorkspace sharedWorkspace] typeOfFile:[[path stringByStandardizingPath] stringByResolvingSymlinksInPath] error:NULL] isEqualToUTI:@"net.sourceforge.bibdesk.bdsksearch"];
}

- (void)loadCustomServers {
    NSString *applicationSupportPath = [[NSFileManager defaultManager] applicationSupportDirectory]; 
    NSString *serversPath = [applicationSupportPath stringByAppendingPathComponent:SERVERS_DIRNAME];
    BOOL isDir = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:serversPath isDirectory:&isDir] && isDir) {
        NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:serversPath];
        NSString *file;
        while ((file = [dirEnum nextObject])) {
            if ([[[dirEnum fileAttributes] valueForKey:NSFileType] isEqualToString:NSFileTypeDirectory]) {
                [dirEnum skipDescendents];
            } else if (isSearchFileAtPath([serversPath stringByAppendingPathComponent:file])) {
                NSString *path = [serversPath stringByAppendingPathComponent:file];
                NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
                BDSKServerInfo *info = [[BDSKServerInfo alloc] initWithDictionary:dict];
                if (info) {
                    NSUInteger idx = [[searchGroupServers valueForKey:@"name"] indexOfObject:[info name]];
                    if (idx != NSNotFound)
                        [searchGroupServers replaceObjectAtIndex:idx withObject:info];
                    else
                        [searchGroupServers addObject:info];
                    [searchGroupServerFiles setObject:path forKey:[info name]];
                    [info release];
                }
            }
        }
    }
    [searchGroupServers sortUsingDescriptors:sortDescriptors];
}

- (id)init {
    BDSKPRECONDITION(sharedManager == nil);
    self = [super init];
    if (self) {
        NSSortDescriptor *typeSort = [[[NSSortDescriptor alloc] initWithKey:@"serverType" ascending:YES selector:@selector(compare:)] autorelease];
        NSSortDescriptor *nameSort = [[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
        
        searchGroupServers = [[NSMutableArray alloc] init];
        searchGroupServerFiles = [[NSMutableDictionary alloc] init];
        sortDescriptors = [[NSArray alloc] initWithObjects:typeSort, nameSort, nil];
        [self resetServers];
        [self loadCustomServers];
    }
    return self;
}
    
- (void)resetServers {
    [searchGroupServers removeAllObjects];
    [searchGroupServerFiles removeAllObjects];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:SERVERS_FILENAME ofType:@"plist"];
    
    NSArray *serverDicts = [NSArray arrayWithContentsOfFile:path];
    for (NSDictionary *dict in serverDicts) {
        BDSKServerInfo *info = [[BDSKServerInfo alloc] initWithDictionary:dict];
        if (info) {
            [searchGroupServers addObject:info];
            [info release];
        }
    }
    
    [searchGroupServers sortUsingDescriptors:sortDescriptors];
}

- (void)saveServerFile:(BDSKServerInfo *)serverInfo {
    NSString *error = nil;
    NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:[serverInfo dictionaryValue] format:format errorDescription:&error];
    if (error) {
        NSLog(@"Error writing: %@", error);
        [error release];
    } else {
        NSString *applicationSupportPath = [[NSFileManager defaultManager] applicationSupportDirectory];
        NSString *serversPath = [applicationSupportPath stringByAppendingPathComponent:SERVERS_DIRNAME];
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:serversPath isDirectory:&isDir] == NO) {
            if ([[NSFileManager defaultManager] createDirectoryAtPath:serversPath withIntermediateDirectories:NO attributes:nil error:NULL] == NO) {
                NSLog(@"Unable to save server info");
                return;
            }
        } else if (isDir == NO) {
            NSLog(@"Unable to save server info");
            return;
        }
        
        NSString *path = [searchGroupServerFiles objectForKey:[serverInfo name]];
        if (path)
            [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        path = [serversPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.bdsksearch", [serverInfo name], [serverInfo type]]];
        [data writeToFile:path atomically:YES];
        [searchGroupServerFiles setObject:path forKey:[serverInfo name]];
    }
}

- (void)deleteServerFile:(BDSKServerInfo *)serverInfo {
    NSString *path = [searchGroupServerFiles objectForKey:[serverInfo name]];
    if (path) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        [searchGroupServerFiles removeObjectForKey:[serverInfo name]];
    }
}

- (NSArray *)servers { 
    return searchGroupServers;
}

- (void)addServer:(BDSKServerInfo *)serverInfo
{
    [searchGroupServers addObject:[[serverInfo copy] autorelease]];
    [searchGroupServers sortUsingDescriptors:sortDescriptors];
    [self saveServerFile:serverInfo];
}

- (void)setServer:(BDSKServerInfo *)serverInfo atIndex:(NSUInteger)idx {
    [self deleteServerFile:[searchGroupServers objectAtIndex:idx]];
    [searchGroupServers replaceObjectAtIndex:idx withObject:[[serverInfo copy] autorelease]];
    [searchGroupServers sortUsingDescriptors:sortDescriptors];
    [self saveServerFile:serverInfo];
}

- (void)removeServerAtIndex:(NSUInteger)idx {
    [self deleteServerFile:[searchGroupServers objectAtIndex:idx]];
    [searchGroupServers removeObjectAtIndex:idx];
}

@end

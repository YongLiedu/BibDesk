//
//  BDSKURLGroup.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/17/06.
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

#import "BDSKURLGroup.h"
#import <WebKit/WebKit.h>
#import "BibTeXParser.h"
#import "BDSKSharedGroup.h"
#import "BibAppController.h"
#import "NSURL_BDSKExtensions.h"
#import "BDSKParserProtocol.h"
#import "NSError_BDSKExtensions.h"
#import "NSImage+Toolbox.h"

@implementation BDSKURLGroup

- (id)initWithURL:(NSURL *)aURL;
{
    NSParameterAssert(aURL != nil);
    if(self = [super initWithName:[aURL lastPathComponent] count:0]){
        
        publications = nil;
        URL = [aURL copy];
        isRetrieving = NO;
        failedDownload = NO;
    }
    
    return self;
}

- (void)dealloc;
{
    [URL release];
    [filePath release];
    [publications release];
    [super dealloc];
}

// Logging

- (NSString *)description;
{
    return [NSString stringWithFormat:@"<%@ %p>: {\n\tis downloading: %@\n\tname: %@\n\tURL: %@\n }", [self class], self, (isRetrieving ? @"yes" : @"no"), name, URL];
}

#pragma mark Downloading

- (void)startDownload;
{
    if ([URL isFileURL]) {
        BOOL isDir;
        if([[NSFileManager defaultManager] fileExistsAtPath:[URL path] isDirectory:&isDir] && NO == isDir){
            [self download:nil didCreateDestination:[URL path]];
            [self downloadDidFinish:nil];
        } else {
            NSError *error = [NSError mutableLocalErrorWithCode:kBDSKFileNotFound localizedDescription:nil];
            if (isDir)
                [error setValue:NSLocalizedString(@"URL points to a directory instead of a file", @"") forKey:NSLocalizedDescriptionKey];
            else
                [error setValue:NSLocalizedString(@"The URL points to a file that does not exist", @"") forKey:NSLocalizedDescriptionKey];
            [error setValue:[URL path] forKey:NSFilePathErrorKey];
            [self download:nil didFailWithError:error];
        }
    } else {
        NSURLRequest *request = [NSURLRequest requestWithURL:URL];
        // we use a WebDownload since it's supposed to add authentication dialog capability
        WebDownload *download = [[[WebDownload alloc] initWithRequest:request delegate:self] autorelease];
        [download setDestination:[[NSApp delegate] temporaryFilePath:nil createDirectory:NO] allowOverwrite:NO];
        isRetrieving = YES;
    }
}

- (void)download:(NSURLDownload *)download didCreateDestination:(NSString *)path
{
    [filePath autorelease];
    filePath = [path copy];
}

- (void)downloadDidFinish:(NSURLDownload *)download
{
    isRetrieving = NO;
    failedDownload = NO;
    NSError *error = nil;

    // tried using -[NSString stringWithContentsOfFile:usedEncoding:error:] but it fails too often
    NSString *contentString = [NSString stringWithContentsOfFile:filePath encoding:NSASCIIStringEncoding guessEncoding:YES];
    NSArray *pubs = nil;
    if (nil == contentString) {
        failedDownload = YES;
    } else {
        int type = [contentString contentStringType];
        if (type == BDSKBibTeXStringType) {
            pubs = [BibTeXParser itemsFromData:[contentString dataUsingEncoding:NSUTF8StringEncoding] error:&error document:nil];
        } else {
            pubs = [BDSKParserForStringType(type) itemsFromString:contentString error:&error frontMatter:nil filePath:filePath];
        }
        if (pubs == nil || error) {
            failedDownload = YES;
            [NSApp presentError:error];
        }
    }
    [self setPublications:pubs];
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
    isRetrieving = NO;
    failedDownload = YES;
    // redraw 
    [self setPublications:nil];
    [NSApp presentError:error];
}

#pragma mark Accessors

- (NSURL *)URL;
{
    return URL;
}

- (NSArray *)publications;
{
    if([self isRetrieving] == NO && publications == nil){
        // use this to notify the tableview to start the progress indicators
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"succeeded"];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKURLGroupUpdatedNotification object:self userInfo:userInfo];
        
        // get the publications asynchronously if remote, synchronously if local
        [self startDownload]; 
    }
    // this posts a notification that the publications of the group changed, forcing a redisplay of the table cell
    return publications;
}

- (void)setPublications:(NSArray *)newPublications;
{
    if(newPublications != publications){
        [publications release];
        publications = [newPublications retain];
    }
    
    [self setCount:[publications count]];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:(publications != nil)] forKey:@"succeeded"];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKURLGroupUpdatedNotification object:self userInfo:userInfo];
}

- (BOOL)isRetrieving { return isRetrieving; }

- (BOOL)failedDownload { return failedDownload; }

// BDSKGroup overrides

- (NSImage *)icon {
    // @@ should get its own icon
    return [NSImage smallImageNamed:@"sharedFolderIcon"];
}

- (BOOL)isURL { return YES; }

- (BOOL)hasEditableName { return NO; }

- (BOOL)containsItem:(BibItem *)item {
    // calling [self publications] will repeatedly reschedule a retrieval, which is undesirable if the the URL download is busy; containsItem is called very frequently
    NSArray *pubs = [publications retain];
    BOOL rv = [pubs containsObject:item];
    [pubs release];
    return rv;
}

- (BOOL)isValidDropTarget { return NO; }

@end

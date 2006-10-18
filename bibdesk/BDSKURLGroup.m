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

// NSCopying protocol, may be used in -[NSCell setObjectValue:] at some point

- (id)copyWithZone:(NSZone *)zone { return [self retain]; }

    // NSCoding protocol

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [NSException raise:NSInternalInconsistencyException format:@"Instances of %@ do not support NSCoding", [self class]];
}

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    [NSException raise:NSInternalInconsistencyException format:@"Instances of %@ do not support NSCoding", [self class]];
    return nil;
}

// Logging

- (NSString *)description;
{
    return [NSString stringWithFormat:@"<%@ %p>: {\n\tis downloading: %@\n\tname: %@\n }", [self class], self, (isRetrieving ? @"yes" : @"no"), name];
}

#pragma mark Downloading

- (void)startDownload;
{
    if ([URL isFileURL]) {
        [self download:nil didCreateDestination:[URL path]];
        [self downloadDidFinish:nil];
    } else {
        NSURLRequest *request = [NSURLRequest requestWithURL:URL];
        WebDownload *download = [[[WebDownload alloc] initWithRequest:request delegate:self] autorelease];
        [download setDestination:[[NSApp delegate] temporaryFilePath:nil createDirectory:YES] allowOverwrite:NO];
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
    NSError *error;
    NSStringEncoding encoding;
    NSString *contentString = [NSString stringWithContentsOfFile:filePath encoding:NSASCIIStringEncoding guessEncoding:YES];
    NSArray *pubs = nil;
    if (nil == contentString) {
        failedDownload = YES;
        [NSApp presentError:error];
    } else {
        int type = [contentString contentStringType];
        if (type == BDSKBibTeXStringType) {
            pubs = [BibTeXParser itemsFromData:[contentString dataUsingEncoding:NSUTF8StringEncoding] error:&error document:nil];
        } else {
            pubs = [BDSKParserForStringType(type) itemsFromString:contentString error:&error frontMatter:nil filePath:filePath];
        }
    }
    [self setPublications:pubs];
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
    isRetrieving = NO;
    failedDownload = YES;
}

#pragma mark Accessors

- (NSArray *)publications;
{
    if([self isRetrieving] == NO && publications == nil){
        // use this to notify the tableview to start the progress indicators
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"succeeded"];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharedGroupUpdatedNotification object:self userInfo:userInfo];
        
        // get the publications asynchronously if remote, synchronously if local
        [self startDownload]; 
    }
    // this will be nil the first time
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
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharedGroupUpdatedNotification object:self userInfo:userInfo];
}

- (BOOL)isRetrieving { return isRetrieving; }

- (BOOL)failedDownload { return failedDownload; }

    // BDSKGroup overrides

- (NSImage *)icon {
    return [BDSKSharedGroup icon];
}

- (BOOL)isShared { return YES; }

- (BOOL)hasEditableName { return NO; }

- (BOOL)containsItem:(BibItem *)item {
    // calling [self publications] will repeatedly reschedule a retrieval, which is undesirable if the user canceled a password; containsItem is called very frequently
    NSArray *pubs = [publications retain];
    BOOL rv = [pubs containsObject:item];
    [pubs release];
    return rv;
}

- (BOOL)isValidDropTarget { return NO; }

@end

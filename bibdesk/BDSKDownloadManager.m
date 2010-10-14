//
//  BDSKDownloadManager.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/14/10.
/*
 This software is Copyright (c) 2010
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

#import "BDSKDownloadManager.h"
#import <WebKit/WebKit.h>


@implementation BDSKDownloadManager

static id sharedManager = nil;

+ (id)sharedManager {
    if (sharedManager == nil)
        sharedManager = [[self alloc] init];
    return sharedManager;
}

- (id)init {
    if (self = [super init]) {
        downloads = [[NSMutableArray alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleApplicationWillTerminateNotification:)
                                                     name:NSApplicationWillTerminateNotification
                                                   object:NSApp];
    }
    return self;
}

- (void)dealloc {
    [downloads makeObjectsPerformSelector:@selector(cancel)];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    BDSKDESTROY(downloads);
    [super dealloc];
}

- (void)addDownloadForURL:(NSURL *)aURL {
	NSURLDownload *download = [[WebDownload alloc] initWithRequest:[NSURLRequest requestWithURL:aURL] delegate:self];
    if (download) {
        [downloads addObject:download];
        [download release];
    }
}

- (void)handleApplicationWillTerminateNotification:(NSNotification *)note {
    [downloads makeObjectsPerformSelector:@selector(cancel)];
    [downloads removeAllObjects];
}

#pragma mark NSURLDownloadDelegate protocol

- (void)download:(NSURLDownload *)download decideDestinationWithSuggestedFilename:(NSString *)filename {
	NSString *extension = [filename pathExtension];
   
	NSSavePanel *sPanel = [NSSavePanel savePanel];
    if (NO == [extension isEqualToString:@""]) 
		[sPanel setRequiredFileType:extension];
    [sPanel setAllowsOtherFileTypes:YES];
    [sPanel setCanSelectHiddenExtension:YES];
	
    // we need to do this modally, not using a sheet, as the download may otherwise finish on Leopard before the sheet is done
    NSInteger returnCode = [sPanel runModalForDirectory:nil file:filename];
    if (returnCode == NSOKButton) {
        [download setDestination:[sPanel filename] allowOverwrite:YES];
    } else {
        [download cancel];
    }
}

- (BOOL)download:(NSURLDownload *)download shouldDecodeSourceDataOfMIMEType:(NSString *)encodingType {
    return YES;
}

- (void)downloadDidFinish:(NSURLDownload *)download {
    [downloads removeObject:download];
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error {
    [downloads removeObject:download];
        
    NSString *errorDescription = [error localizedDescription] ?: NSLocalizedString(@"An error occured during download.", @"Informative text in alert dialog");
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Download Failed", @"Message in alert dialog when download failed")
                                     defaultButton:nil
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:errorDescription];
    [alert runModal];
}

@end

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

+ (NSString *)webScriptNameForSelector:(SEL)aSelector {
    NSString *name = nil;
    if (aSelector == @selector(clear))
        name = @"clear";
    else if (aSelector == @selector(cancel:))
        name = @"cancel";
    else if (aSelector == @selector(remove:))
        name = @"remove";
    return name;
}
 
+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector {
    if (aSelector == @selector(clear) || aSelector == @selector(cancel:) || aSelector == @selector(remove:))
        return NO;
    return YES;
}

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
	NSURLDownload *download = [[BDSKDownload alloc] initWithURL:aURL];
    if (download) {
        [downloads addObject:download];
        [download release];
    }
}

- (NSArray *)downloads {
    return downloads;
}

- (BDSKDownload *)downloadWithUniqueID:(NSUInteger)uniqueID {
    for (BDSKDownload *download in downloads) {
        if ([download uniqueID] == uniqueID)
            return download;
    }
    return nil;
}

- (void)clear {
    NSUInteger i = [downloads count];
    while (i--) {
        if ([[downloads objectAtIndex:i] status] != 0)
            [downloads removeObjectAtIndex:i];
    }
}

- (void)cancel:(NSUInteger)i {
    [[self downloadWithUniqueID:i] cancel];
}

- (void)remove:(NSUInteger)i {
    BDSKDownload *download = [self downloadWithUniqueID:i];
    if (download) {
        [download cancel];
        [downloads removeObject:download];
    }
}

- (void)handleApplicationWillTerminateNotification:(NSNotification *)note {
    [downloads makeObjectsPerformSelector:@selector(cancel)];
    [downloads removeAllObjects];
}

@end


@implementation BDSKDownload

static NSUInteger currentUniqueID = 0;

- (id)initWithURL:(NSURL *)aURL {
    if (self = [super init]) {
        uniqueID = ++currentUniqueID;
        URL = [aURL retain];
        fileURL = nil;
        status = BDSKDownloadStatusDownloading;
        download = [[WebDownload alloc] initWithRequest:[NSURLRequest requestWithURL:URL] delegate:self];
    }
    return self;
}

- (void)dealloc {
    [download cancel];
    BDSKDESTROY(URL);
    BDSKDESTROY(fileURL);
    BDSKDESTROY(download);
    [super dealloc];
}

- (NSUInteger)uniqueID {
    return uniqueID;
}

- (NSURL *)URL {
    return URL;
}

- (NSURL *)fileURL {
    return fileURL;
}

- (BDSKDownloadStatus)status {
    return status;
}

- (void)cancel {
    [download cancel];
}

#pragma mark NSURLDownloadDelegate protocol

- (void)download:(NSURLDownload *)aDownload decideDestinationWithSuggestedFilename:(NSString *)filename {
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

- (void)download:(NSURLDownload *)download didCreateDestination:(NSString *)path {
    [fileURL release];
    fileURL = path ? [[NSURL alloc] initFileURLWithPath:path] : nil;
}

- (BOOL)download:(NSURLDownload *)aDownload shouldDecodeSourceDataOfMIMEType:(NSString *)encodingType {
    return YES;
}

- (void)downloadDidFinish:(NSURLDownload *)aDownload {
    BDSKDESTROY(download);
    status = BDSKDownloadStatusFinished;
}

- (void)download:(NSURLDownload *)aDownload didFailWithError:(NSError *)error {
    BDSKDESTROY(download);
    BDSKDESTROY(fileURL);
    status = BDSKDownloadStatusFailed;
    NSString *errorDescription = [error localizedDescription] ?: NSLocalizedString(@"An error occured during download.", @"Informative text in alert dialog");
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Download Failed", @"Message in alert dialog when download failed")
                                     defaultButton:nil
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:errorDescription];
    [alert runModal];
}

@end

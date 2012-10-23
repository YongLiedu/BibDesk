//
//  BDSKDownloadManager.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/14/10.
/*
 This software is Copyright (c) 2010-2012
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
#import "NSURL_BDSKExtensions.h"

#define BDSKRemoveFinishedDownloadsKey @"BDSKRemoveFinishedDownloads"
#define BDSKRemoveFailedDownloadsKey   @"BDSKRemoveFailedDownloads"

@implementation BDSKDownloadManager

static id sharedManager = nil;

+ (id)sharedManager {
    if (sharedManager == nil)
        sharedManager = [[self alloc] init];
    return sharedManager;
}

- (id)init {
    self = [super init];
    if (self) {
        downloads = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSArray *)downloads {
    return downloads;
}

- (BOOL)removeFinishedDownloads {
    return [[NSUserDefaults standardUserDefaults] boolForKey:BDSKRemoveFinishedDownloadsKey];
}

- (void)setRemoveFinishedDownloads:(BOOL)flag {
   [[NSUserDefaults standardUserDefaults] setBool:flag forKey:BDSKRemoveFinishedDownloadsKey];
}

- (BOOL)removeFailedDownloads {
    return [[NSUserDefaults standardUserDefaults] boolForKey:BDSKRemoveFailedDownloadsKey];
}

- (void)setRemoveFailedDownloads:(BOOL)flag {
   [[NSUserDefaults standardUserDefaults] setBool:flag forKey:BDSKRemoveFailedDownloadsKey];
}

- (BDSKDownload *)downloadForURLDownload:(NSURLDownload *)URLDownload {
    for (BDSKDownload *download in downloads) {
        if ([download URLDownload] == URLDownload)
            return download;
    }
    return nil;
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

- (void)cancel:(NSUInteger)uniqueID {
    [[[self downloadWithUniqueID:uniqueID] URLDownload] cancel];
}

- (void)remove:(NSUInteger)uniqueID {
    BDSKDownload *download = [self downloadWithUniqueID:uniqueID];
    if (download)
        [downloads removeObject:download];
}

+ (NSString *)webScriptNameForSelector:(SEL)aSelector {
    NSString *name = nil;
    if (aSelector == @selector(cancel:))
        name = @"cancel";
    else if (aSelector == @selector(remove:))
        name = @"remove";
    return name;
}
 
+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector {
    return (aSelector != @selector(clear) && aSelector != @selector(cancel:) && aSelector != @selector(remove:));
}
 
+ (BOOL)isKeyExcludedFromWebScript:(const char *)aKey {
    return 0 != strcmp(aKey, "removeFinishedDownloads") && 0 != strcmp(aKey, "removeFailedDownloads");
}

// This is necessary for web scripting to check the key for exposure, otherwise it will only check the ivar names instead
- (NSArray *)attributeKeys {
    return [NSArray arrayWithObjects:@"removeFinishedDownloads", @"removeFailedDownloads", nil];
}

#pragma mark NSURLDownload delegate protocol

- (void)downloadDidBegin:(NSURLDownload *)URLDownload {
    [downloads addObject:[[[BDSKDownload alloc] initWithURLDownload:URLDownload] autorelease]];
}

- (void)downloadDidFinish:(NSURLDownload *)URLDownload {
    BDSKDownload *download = [self downloadForURLDownload:URLDownload];
    [download setStatus:BDSKDownloadStatusFinished];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKRemoveFinishedDownloadsKey] && download)
        [downloads removeObject:download];
}

- (void)download:(NSURLDownload *)URLDownload didFailWithError:(NSError *)error {
    BDSKDownload *download = [self downloadForURLDownload:URLDownload];
    [download setStatus:BDSKDownloadStatusFinished];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKRemoveFailedDownloadsKey] && download)
        [downloads removeObject:download];
    
    NSString *errorDescription = [error localizedDescription] ?: NSLocalizedString(@"An error occured during download.", @"Informative text in alert dialog");
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Download Failed", @"Message in alert dialog when download failed")
                                     defaultButton:nil
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@"%@", errorDescription];
    [alert runModal];
}

- (void)download:(NSURLDownload *)URLDownload decideDestinationWithSuggestedFilename:(NSString *)filename {
	NSString *extension = [filename pathExtension];
   
	NSSavePanel *sPanel = [NSSavePanel savePanel];
    if (NO == [extension isEqualToString:@""]) 
		[sPanel setRequiredFileType:extension];
    [sPanel setAllowsOtherFileTypes:YES];
    [sPanel setCanSelectHiddenExtension:YES];
	
    // we need to do this modally, not using a sheet, as the download may otherwise finish on Leopard before the sheet is done
    NSInteger returnCode = [sPanel runModalForDirectory:nil file:filename];
    if (returnCode == NSFileHandlingPanelOKButton)
        [URLDownload setDestination:[sPanel filename] allowOverwrite:YES];
    else
        [URLDownload cancel];
}

- (void)download:(NSURLDownload *)URLDownload didCreateDestination:(NSString *)path {
    [[self downloadForURLDownload:URLDownload] setFileURL:[NSURL fileURLWithPath:path]];
}

- (BOOL)download:(NSURLDownload *)URLDownload shouldDecodeSourceDataOfMIMEType:(NSString *)encodingType {
    return YES;
}

@end

#pragma mark -

@implementation BDSKDownload

static NSUInteger currentUniqueID = 0;

- (id)initWithURLDownload:(NSURLDownload *)aURLDownload {
    self = [super init];
    if (self) {
        uniqueID = ++currentUniqueID;
        URL = [[[aURLDownload request] URL] retain];
        fileURL = nil;
        status = BDSKDownloadStatusDownloading;
        URLDownload = [aURLDownload retain];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(URL);
    BDSKDESTROY(fileURL);
    BDSKDESTROY(URLDownload);
    [super dealloc];
}

- (NSURLDownload *)URLDownload {
    return URLDownload;
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

- (void)setFileURL:(NSURL *)newFileURL {
    if (fileURL != newFileURL) {
        [fileURL release];
        fileURL = [newFileURL retain];
    }
}

- (NSString *)fileName {
    NSString *fileName = [fileURL lastPathComponent];
    if (fileName == nil) {
        if ([[URL path] length] > 1) {
            fileName = [URL lastPathComponent];
        } else {
            fileName = [URL host];
            if (fileName == nil)
                fileName = [[[URL resourceSpecifier] lastPathComponent] stringByReplacingPercentEscapes];
        }
    }
    return fileName;
}

- (BDSKDownloadStatus)status {
    return status;
}

- (void)setStatus:(BDSKDownloadStatus)newStatus {
    if (status != newStatus) {
        status = newStatus;
        if (status != BDSKDownloadStatusDownloading)
            BDSKDESTROY(URLDownload);
        if (status == BDSKDownloadStatusFailed)
            [self setFileURL:nil];
    }
}

@end

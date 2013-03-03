//
//  BDSKBibDeskURLHandler.m
//  BibDesk
//
//  Created by Colin Smith on 11/9/12.
/*
 This software is Copyright (c) 2012-2012
 Colin A. Smith. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Colin A. Smith nor the names of any
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

#import "BDSKBibDeskURLHandler.h"

#import "BibDocument.h"
#import "BDSKFileStore.h"
#import "BDSKPublicationsArray.h"
#import "BDSKStringConstants_iOS.h"

@interface BDSKBibDeskURLHandler () {

    NSURL *_url;
    id<BDSKBibDeskURLHandlerDelegate> _delegate;
    NSArray *_bibItems;
    NSString *_filePath;
    BOOL _isLoading;
    BOOL _isFailed;
}

@end

@implementation BDSKBibDeskURLHandler

+ (BDSKBibDeskURLHandler *)urlHandlerWithURL:(NSURL *)url delegate:(id<BDSKBibDeskURLHandlerDelegate>)delegate {

    return [[[BDSKBibDeskURLHandler alloc] initWithURL:url delegate:delegate] autorelease];
}

- (id)initWithURL:(NSURL *)url delegate:(id<BDSKBibDeskURLHandlerDelegate>)delegate {

    if (self = [super init]) {
    
        _url = [url retain];
        _delegate = delegate;
        _bibItems = nil;
        _filePath = nil;
        _isLoading = NO;
        _isFailed = NO;
    }
    
    return self;
}

- (void)dealloc {

    [_url release];
    [_bibItems release];
    [_filePath release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (NSURL *)url {

    return _url;
}

- (id<BDSKBibDeskURLHandlerDelegate>)delegate {

    return _delegate;
}

- (BDSKFileStore *)fileStore {

    return [BDSKFileStore fileStoreForName:[self.url host]];
}

- (NSString *)bibFileName {

    return [[self.url path] substringFromIndex:1];
}

- (NSArray *)bibItems {

    return _bibItems;
}

- (NSString *)filePath {

    return _filePath;
}

- (BOOL)isLoading {

    return _isLoading;
}

- (BOOL)isFailed {

    return _isFailed;
}

- (void)startLoad {

    //NSLog(@"Loading URL: %@", _url);
    
    if ([[self.url scheme] isEqualToString:@"bibdesk"] && [[self.url query] hasPrefix:@"citeKey="]) {
    
        BDSKFileStore *fileStore = self.fileStore;
        
        if (fileStore) {
        
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleBibDocumentChangedNotification:) name:BDSKBibDocumentChangedNotification object:fileStore];
        
            [self loadBibItems];
            return;
        }
    }
    
    _isFailed = YES;
    [self.delegate urlHandlerUpdated:self];
}

- (void)loadBibItems {

    BDSKFileStore *fileStore = self.fileStore;
        
    if (fileStore) {
    
        NSString *bibFileName = self.bibFileName;
        BibDocument *bibDocument = [fileStore bibDocumentForName:bibFileName];
        
        if (bibDocument) {
            
            if (bibDocument.documentState == UIDocumentStateClosed) {
            
                _isLoading = YES;
                _isFailed = NO;
                [self.delegate urlHandlerUpdated:self];
                return;
                
            } else {
            
                NSString *citeKey = [[self.url query] substringFromIndex:@"citeKey=".length];
                _bibItems = [[[bibDocument publications] allItemsForCiteKey:citeKey] retain];
                _isLoading = NO;
                _isFailed = NO;
                [self.delegate urlHandlerUpdated:self];
                return;
            }
        }
    }
    
    _isFailed = YES;
    [self.delegate urlHandlerUpdated:self];
}

- (void)handleBibDocumentChangedNotification:(NSNotification *)notification {
    
    NSString *bibFileName = [notification.userInfo objectForKey:BDSKBibDocumentChangedNotificationBibFileNameKey];

    if ([bibFileName isEqualToString:self.bibFileName]) {

        [self loadBibItems];
    }
}

@end

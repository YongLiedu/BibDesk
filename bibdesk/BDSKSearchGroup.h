//
//  BDSKSearchGroup.h
//  Bibdesk
//
//  Created by Adam Maxwell on 12/23/06.
/*
 This software is Copyright (c) 2006-2010
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

#import <Cocoa/Cocoa.h>
#import "BDSKExternalGroup.h"

extern NSString *BDSKSearchGroupEntrez;
extern NSString *BDSKSearchGroupZoom;
extern NSString *BDSKSearchGroupISI;
extern NSString *BDSKSearchGroupDBLP;

@class BDSKServerInfo;

@protocol BDSKSearchGroup <BDSKOwner>
- (void)addPublications:(NSArray *)pubs;
@end

@protocol BDSKSearchGroupServer <NSObject>
- (id)initWithGroup:(id<BDSKSearchGroup>)aGroup serverInfo:(BDSKServerInfo *)info;
- (BDSKServerInfo *)serverInfo;
- (void)setServerInfo:(BDSKServerInfo *)info;
- (NSInteger)numberOfAvailableResults;
- (NSInteger)numberOfFetchedResults;
- (BOOL)failedDownload;
- (NSString *)errorMessage;
- (BOOL)isRetrieving;
- (void)retrieveWithSearchTerm:(NSString *)aSearchTerm;
- (void)reset;
- (void)terminate;
- (NSFormatter *)searchStringFormatter;
@end

@interface BDSKSearchGroup : BDSKExternalGroup <BDSKSearchGroup> {
    NSString *type;
    NSString *searchTerm; // passed in by caller
    NSArray *history;
    id<BDSKSearchGroupServer> server;
}

- (id)initWithType:(NSString *)aType serverInfo:(BDSKServerInfo *)info searchTerm:(NSString *)string;
- (id)initWithURL:(NSURL *)bdsksearchURL;

- (NSString *)type;

- (void)setServerInfo:(BDSKServerInfo *)info;
- (BDSKServerInfo *)serverInfo;

- (void)setSearchTerm:(NSString *)aTerm;
- (NSString *)searchTerm;

- (void)setHistory:(NSArray *)newHistory;
- (NSArray *)history;

- (NSInteger)numberOfAvailableResults;

- (NSString *)errorMessage;

- (BOOL)hasMoreResults;

- (void)search;

- (void)resetServerWithInfo:(BDSKServerInfo *)info;
- (NSFormatter *)searchStringFormatter;

- (NSURL *)bdsksearchURL;

@end

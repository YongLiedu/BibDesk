//
//  BDSKDBLPGroupServer.m
//  Bibdesk
//
//  Created by Adam Maxwell on 4/2/08.
/*
 This software is Copyright (c) 2008-2010
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
#import "BDSKDBLPGroupServer.h"
#import "BDSKDBLPWebServices.h"
#import "BDSKServerInfo.h"
#import "BibItem.h"
#import "BibAuthor.h"
#import "BDSKBibTeXParser.h"
#import "NSArray_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"

// private protocols for inter-thread messaging
@protocol BDSKDBLPGroupServerMainThread <BDSKAsyncDOServerMainThread>
- (void)addPublicationsFromBibTeXString:(bycopy NSString *)btString abstracts:(bycopy NSDictionary *)abstracts;
@end

@protocol BDSKDBLPGroupServerLocalThread <BDSKAsyncDOServerThread>
- (oneway void)downloadWithSearchTerm:(NSString *)searchTerm database:(NSString *)database;
@end


@implementation BDSKDBLPGroupServer

+ (BOOL)canConnect;
{
    CFURLRef theURL = (CFURLRef)[NSURL URLWithString:@"http://dblp.uni-trier.de"];
    CFNetDiagnosticRef diagnostic = CFNetDiagnosticCreateWithURL(CFGetAllocator(theURL), theURL);
    
    NSString *details;
    CFNetDiagnosticStatus status = CFNetDiagnosticCopyNetworkStatusPassively(diagnostic, (CFStringRef *)&details);
    CFRelease(diagnostic);
    [details autorelease];
    
    BOOL canConnect = kCFNetDiagnosticConnectionUp == status;
    if (NO == canConnect)
        NSLog(@"%@", details);
    
    return canConnect;
}

- (Protocol *)protocolForMainThread { return @protocol(BDSKDBLPGroupServerMainThread); }
- (Protocol *)protocolForServerThread { return @protocol(BDSKDBLPGroupServerLocalThread); }

- (id)initWithGroup:(id<BDSKSearchGroup>)aGroup serverInfo:(BDSKServerInfo *)info;
{
    self = [super init];
    if (self) {
        group = aGroup;
        serverInfo = [info copy];
        flags.failedDownload = 0;
        flags.isRetrieving = 0;
        availableResults = 0;
        fetchedResults = 0;
        errorMessage = nil;
        
        [self startDOServerSync];
    }
    return self;
}

- (void)dealloc {
    group = nil;
    BDSKDESTROY(serverInfo);
    BDSKDESTROY(scheduledService);
    BDSKDESTROY(errorMessage);
    [super dealloc];
}

#pragma mark BDSKSearchGroupServer protocol

// these are called on the main thread

- (void)reset
{
    if ([self isRetrieving]) {
        [scheduledService cancel];
        OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);
    }
    OSAtomicCompareAndSwap32Barrier(availableResults, 0, &availableResults);
    OSAtomicCompareAndSwap32Barrier(fetchedResults, 0, &fetchedResults);
}

- (void)terminate
{
    [self stopDOServer];
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);
}

- (void)retrieveWithSearchTerm:(NSString *)aSearchTerm
{
    if ([[self class] canConnect]) {
        OSAtomicCompareAndSwap32Barrier(1, 0, &flags.failedDownload);
        
        // stop the current service (if any); -cancel is thread safe, and so is calling it multiple times
        [scheduledService cancel];
        OSAtomicCompareAndSwap32Barrier(0, 1, &flags.isRetrieving);
        [[self serverOnServerThread] downloadWithSearchTerm:aSearchTerm database:[[self serverInfo] database]];
        
    } else {
        OSAtomicCompareAndSwap32Barrier(0, 1, &flags.failedDownload);
        [self setErrorMessage:NSLocalizedString(@"Unable to connect to server", @"")];
    }
}

- (void)setServerInfo:(BDSKServerInfo *)info;
{
    if (serverInfo != info) {
        [serverInfo release];
        serverInfo = [info copy];
    }
}

- (BDSKServerInfo *)serverInfo;
{
    return serverInfo;
}

- (NSInteger)numberOfAvailableResults;
{
    return availableResults;
}

- (NSInteger)numberOfFetchedResults;
{
    return fetchedResults;
}

- (BOOL)failedDownload { OSMemoryBarrier(); return 1 == flags.failedDownload; }

- (BOOL)isRetrieving { OSMemoryBarrier(); return 1 == flags.isRetrieving; }

// warning: if these ever can be set on the background thread they have to be made thread safe
- (NSString *)errorMessage {
    return errorMessage;
}

- (void)setErrorMessage:(NSString *)newErrorMessage {
    BDSKASSERT([NSThread isMainThread]);
    if (errorMessage != newErrorMessage) {
        [errorMessage release];
        errorMessage = [newErrorMessage copy];
    }
}

- (NSFormatter *)searchStringFormatter { return nil; }

#pragma mark Main thread

static void fixEEURL(BibItem *pub)
{
    NSMutableString *URLString = [NSMutableString stringWithString:[pub valueOfField:[@"ee" fieldName] inherit:NO]];
    // some URLs have been converted for compatibility with TeX
    [URLString replaceOccurrencesOfString:@"{\\&}" withString:@"&" options:0 range:NSMakeRange(0, [URLString length])];
    NSURL *aURL;
    if ([NSString isEmptyString:URLString] == NO && (aURL = [NSURL URLWithString:URLString]) != nil) {
        
        // some refs have a partial URL in the ee field that uses this as a base
        if (nil == [aURL scheme]) {
            [URLString insertString:@"http://dblp.uni-trier.de/" atIndex:0];
            aURL = [NSURL URLWithString:URLString];
        }
        
        if ([pub addFileForURL:aURL autoFile:NO runScriptHook:NO])
            [pub setField:[@"ee" fieldName] toValue:nil];
    }
}

- (void)addPublicationsFromBibTeXString:(bycopy NSString *)btString abstracts:(bycopy NSDictionary *)abstracts;
{
    BDSKASSERT([NSThread isMainThread]);
    NSArray *pubs = nil;
    
    if ([btString isEqualToString:@""]) {
        // cancelled case
        pubs = [NSArray array];
    } else if (btString) {
        pubs = [BDSKBibTeXParser itemsFromString:btString document:group isPartialData:NULL error:NULL];
        for (BibItem *pub in pubs) {
            NSString *aKey = [[pub citeKey] stringByRemovingPrefix:@"DBLP:"];
            id value = [abstracts objectForKey:aKey];
            if (value && [value isEqual:[NSNull null]] == NO)
                [pub setValue:value forKey:BDSKAbstractString];
            fixEEURL(pub);
        }
    }
    
    if (pubs) {
        int32_t count = [pubs count];
        OSAtomicCompareAndSwap32Barrier(availableResults, count, &availableResults);
        OSAtomicCompareAndSwap32Barrier(fetchedResults, count, &fetchedResults);
    }
    
    // set this flag before adding pubs, or the client will think we're still retrieving (and spinners don't stop)
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);
    
    // this will create the array if it doesn't exist
    [group addPublications:pubs];
}

#pragma mark Server thread

- (NSArray *)resultsWithSearchTerm:(NSString *)searchTerm database:(NSString *)database
{
    // no UI for providing years, so use 1900--present
    NSNumber *startYear = [NSNumber numberWithInteger:1900];
    NSNumber *endYear = [NSNumber numberWithInteger:[[NSCalendarDate date] yearOfCommonEra]];
    
    NSArray *searchResults = nil;
    if ([database caseInsensitiveCompare:@"authors"] == NSOrderedSame) {
        BibAuthor *author = [BibAuthor authorWithName:searchTerm andPub:nil];
        BDSKDBLPAllPublicationsAuthorYear *invocation = [[BDSKDBLPAllPublicationsAuthorYear alloc] init];    
        [invocation setParameters:([author firstName] ?: @"")
                                                            in_familyName:([author lastName] ?: @"")
                     in_startYear:startYear in_endYear:endYear];    
        [scheduledService autorelease];
        scheduledService = invocation;
        searchResults = [[[invocation resultValue] retain] autorelease];
    }
    else {
        BDSKDBLPAllPublicationsKeywordsYear *invocation = [[BDSKDBLPAllPublicationsKeywordsYear alloc] init];    
        [invocation setParameters:searchTerm
                     in_startYear:startYear in_endYear:endYear in_limit:[NSNumber numberWithInteger:100]];    
        [scheduledService autorelease];
        scheduledService = invocation;
        searchResults = [[[invocation resultValue] retain] autorelease];
    }
    return searchResults;
}

// Note:  WSGeneratedObj doesn't supply a way to cancel a request, so calling downloadWithSearchTerm: again with a non-empty string before the first request completes will cause a beachball.  This is mainly a problem on slow network connections.
- (oneway void)downloadWithSearchTerm:(NSString *)searchTerm database:(NSString *)database;
{    
    NSString *btString = nil;
    NSMutableDictionary *abstracts = nil;
    
    if (NO == [NSString isEmptyString:searchTerm]){
        
        NSArray *dblpKeys = [[self resultsWithSearchTerm:searchTerm database:database] valueForKeyPath:@"dblp_key"];
        int32_t dblpKeysCount = [dblpKeys count];
        
        OSAtomicCompareAndSwap32Barrier(availableResults, dblpKeysCount, &availableResults);
        
        NSMutableSet *btEntries = [NSMutableSet set];
        abstracts = [NSMutableDictionary dictionary];
        for (NSString *aKey in dblpKeys) {
            if (flags.isRetrieving == 0) break;
            
            NSURL *theURL = [NSURL URLWithString:[@"http://dblp.uni-trier.de/rec/bibtex/" stringByAppendingString:aKey]];
            NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:theURL options:NSXMLDocumentTidyHTML error:NULL];
            
            NSArray *btNodes = [doc nodesForXPath:@"//pre" error:NULL];
            for (NSXMLNode *aNode in btNodes)
                [btEntries addObject:[aNode stringValue]];
            
            [doc release];
            
            NSDictionary *pubData = [[DBLPPlusPlusService BDSKDBLPPublicationData:aKey] lastObject];
            if ([pubData objectForKey:@"abstract"])
                [abstracts setObject:[pubData objectForKey:@"abstract"] forKey:aKey];
            OSMemoryBarrier();
        }
        
        btString = (flags.isRetrieving == 0) ? @"" : [[btEntries allObjects] componentsJoinedByString:@"\n"];
    }
    
    // this will create the array if it doesn't exist
    [[self serverOnMainThread] addPublicationsFromBibTeXString:btString abstracts:abstracts];
}

@end

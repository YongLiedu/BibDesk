//
//  BDSKISIGroupServer.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/10/07.
/*
 This software is Copyright (c) 2007-2014
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

#import "BDSKISIGroupServer.h"
#import "WOKMWSAuthenticateService.h"
#import "WokSearchService.h"
#import "WokSearchLiteService.h"
#import "BDSKLinkedFile.h"
#import "BDSKServerInfo.h"
#import "BibItem.h"
#import "NSArray_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSDate+ISO8601Unparsing.h"

#define SERVER_URL @"http://search.webofknowledge.com/esti/wokmws/ws/WokSearch"
#define SERVER_URL_LITE @"http://search.webofknowledge.com/esti/wokmws/ws/WokSearchLite"

#define WOS_DB_ID @"WOS"
#define EN_QUERY_LANG @"en"

#define BDSKAddISIXMLStringToAnnoteKey @"BDSKAddISIXMLStringToAnnote"
#define BDSKDisableISITitleCasingKey @"BDSKDisableISITitleCasing"
#define BDSKISISourceXMLTagPriorityKey @"BDSKISISourceXMLTagPriority"
#define BDSKISIURLFieldNameKey @"BDSKISIURLFieldName"

#define WOK_UID_FIELDNAME @"Wok-Uid"

#define MAX_RESULTS 100

#ifdef DEBUG
static BOOL addXMLStringToAnnote = YES;
#else
static BOOL addXMLStringToAnnote = NO;
#endif

static BOOL useTitlecase = YES;
static NSArray *sourceXMLTagPriority = nil;
static NSString *ISIURLFieldName = nil;

static NSSet *WOSEditions = nil;

static NSArray *uidsFromString(NSString *uidString);

@interface NSObject (BDSKISIGroupServer)
- (NSDictionary *)newWOKPublicationInfo;
@end

// private protocols for inter-thread messaging
@protocol BDSKISIGroupServerMainThread <BDSKAsyncDOServerMainThread>
- (void)addPublicationsToGroup:(bycopy NSData *)data;
@end

@protocol BDSKISIGroupServerLocalThread <BDSKAsyncDOServerThread>
- (oneway void)downloadWithSearchTerm:(NSString *)searchTerm database:(NSString *)database options:(NSDictionary *)options;
@end

@interface BDSKISIGroupServer (BDSKPrivate)
- (void)authenticateWithOptions:(NSDictionary *)options;
@end

@implementation BDSKISIGroupServer

+ (void)initialize
{
    BDSKINITIALIZE;
    // this is messy, but may be useful for debugging
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKAddISIXMLStringToAnnoteKey])
        addXMLStringToAnnote = YES;
    // try to allow for common titlecasing in Web of Science (which gives us uppercase titles)
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKDisableISITitleCasingKey])
        useTitlecase = NO;
    // prioritized list of XML tag names for getting the source field value
    sourceXMLTagPriority = [[[NSUserDefaults standardUserDefaults] arrayForKey:BDSKISISourceXMLTagPriorityKey] retain];

    // set the ISI URL in a specified field name
    ISIURLFieldName = [[[NSUserDefaults standardUserDefaults] stringForKey:BDSKISIURLFieldNameKey] retain];
    
    WOSEditions = [[NSSet alloc] initWithObjects:@"SCI", @"SSCI", @"AHCI", @"IC", @"ISTP", @"ISSHP", @"CCR", nil];
}

- (Protocol *)protocolForMainThread { return @protocol(BDSKISIGroupServerMainThread); }
- (Protocol *)protocolForServerThread { return @protocol(BDSKISIGroupServerLocalThread); }

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
        sessionCookie = nil;
    
        [self startDOServerSync];
    }
    return self;
}

- (void)dealloc {
    group = nil;
    BDSKDESTROY(serverInfo);
    [sessionCookie release];
    [super dealloc];
}

#pragma mark BDSKSearchGroupServer protocol

// these are called on the main thread

- (NSString *)type { return BDSKSearchGroupISI; }

- (void)reset
{
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);
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
    if ([[NSURL URLWithString:[serverInfo isLite] ? SERVER_URL_LITE : SERVER_URL] canConnect]) {
        OSAtomicCompareAndSwap32Barrier(1, 0, &flags.failedDownload);
        
        OSAtomicCompareAndSwap32Barrier(0, 1, &flags.isRetrieving);
        [[self serverOnServerThread] downloadWithSearchTerm:aSearchTerm database:[[self serverInfo] database] options:[[self serverInfo] options]];
        
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
    OSMemoryBarrier();
    return availableResults;
}

- (NSInteger)numberOfFetchedResults;
{
    OSMemoryBarrier();
    return fetchedResults;
}

- (BOOL)failedDownload { OSMemoryBarrier(); return 1 == flags.failedDownload; }

- (BOOL)isRetrieving { OSMemoryBarrier(); return 1 == flags.isRetrieving; }

- (NSString *)errorMessage {
    NSString *msg;
    @synchronized(self) {
        msg = [[errorMessage copy] autorelease];
    }
    return msg;
}

- (void)setErrorMessage:(NSString *)newErrorMessage {
    @synchronized(self) {
        if (errorMessage != newErrorMessage) {
            [errorMessage release];
            errorMessage = [newErrorMessage copy];
        }
    }
}

- (NSFormatter *)searchStringFormatter { return nil; }

#pragma mark Main thread

- (void)addPublicationsToGroup:(bycopy NSData *)data;
{
    BDSKASSERT([NSThread isMainThread]);
    NSMutableArray *pubs = nil;
    if (data) {
        [NSString setMacroResolverForUnarchiving:[group macroResolver]];
        NSArray *pubInfos = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [NSString setMacroResolverForUnarchiving:nil];
        
        pubs = [NSMutableArray arrayWithCapacity:[pubInfos count]];
        for (NSDictionary *pubInfo in pubInfos) {
            NSMutableDictionary *pubFields = [pubInfo mutableCopy];
            NSArray *files = nil;
            
            NSString *pubType = [pubFields objectForKey:BDSKPubTypeString];
            [pubFields removeObjectForKey:BDSKPubTypeString];
            
            NSString *uid = [pubFields objectForKey:WOK_UID_FIELDNAME];
            if (uid) {
                NSString *wokURL = [@"http://ws.isiknowledge.com/cps/openurl/service?url_ver=Z39.88-2004&rft_id=info:ut/" stringByAppendingString:uid];
                // insert the WOK URL into the normal file array if shouldn't be put elsewhere
                if (ISIURLFieldName)
                    [pubFields setObject:wokURL forKey:ISIURLFieldName];
                else
                    files = [[NSArray alloc] initWithObjects:[BDSKLinkedFile linkedFileWithURL:[NSURL URLWithStringByNormalizingPercentEscapes:wokURL] delegate:nil], nil];
            }
            
            BibItem *pub = [[BibItem alloc] initWithType:pubType citeKey:nil pubFields:pubFields files:files isNew:YES];
            
            [pubs addObject:pub];
            [pub release];
            [pubFields release];
            [files release];
        }
    }
    [group addPublications:pubs];
}

#pragma mark Server thread
// @@ currently limited to topic search; need to figure out UI for other search types (mixing search types will require either NSTokenField or raw text string entry)
- (oneway void)downloadWithSearchTerm:(NSString *)searchTerm database:(NSString *)database options:(NSDictionary *)options;
{    
    enum operationTypes { search, citedReferences, citingArticles, relatedRecords, retrieveById } operation = search;
    NSInteger availableResultsLocal = [self numberOfAvailableResults];
    NSInteger fetchedResultsLocal = [self numberOfFetchedResults];
    NSInteger numResults = MAX_RESULTS;
    
    if (availableResultsLocal > 0)
        numResults = MIN(availableResultsLocal - fetchedResultsLocal, MAX_RESULTS);
    
    // Strip whitespace from the search term to make WOS happy
    searchTerm = [searchTerm stringByRemovingSurroundingWhitespace];
    
    database = [database stringByCollapsingWhitespaceAndRemovingSurroundingWhitespace];
    
    if ([NSString isEmptyString:searchTerm] || numResults == 0){
		
        // there is nothing to download
        OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);
        // notify that we stopped retrieving
        [[self serverOnMainThread] addPublicationsToGroup:nil];
        
    } else {
        /*
         TODO: document this syntax and the results thereof in the code, and in the help book.
         */
        
        NSRange prefixRange;
        if ((prefixRange = [searchTerm rangeOfString:@"CitedReferences:" options:NSAnchoredSearch]).location == 0) {
            searchTerm = [searchTerm substringFromIndex:NSMaxRange(prefixRange)];
            operation = citedReferences;
        } else if ((prefixRange = [searchTerm rangeOfString:@"CitingArticles:" options:NSAnchoredSearch]).location == 0) {
            searchTerm = [searchTerm substringFromIndex:NSMaxRange(prefixRange)];
            operation = citingArticles;
        } else if ((prefixRange = [searchTerm rangeOfString:@"RelatedRecords:" options:NSAnchoredSearch]).location == 0) {
            searchTerm = [searchTerm substringFromIndex:NSMaxRange(prefixRange)];
            operation = relatedRecords;
        } else if ((prefixRange = [searchTerm rangeOfString:@"RetrieveById:" options:NSAnchoredSearch]).location == 0) {
            searchTerm = [searchTerm substringFromIndex:NSMaxRange(prefixRange)];
            operation = retrieveById;
        } else if ([searchTerm rangeOfString:@"="].location == NSNotFound) {
            searchTerm = [NSString stringWithFormat:@"TS=\"%@\"", searchTerm];
        }
        
        NSArray *editionIDs = nil;
        if ([NSString isEmptyString:database]) {
            database = WOS_DB_ID;
        } else {
            NSArray *ids = [database componentsSeparatedByString:@" "];
            database = [ids firstObject];
            if ([WOSEditions containsObject:database]) {
                database = WOS_DB_ID;
                editionIDs = ids;
            } else if ([ids count] > 1) {
                editionIDs = [ids subarrayWithRange:NSMakeRange(1, [ids count] - 1)];
            }
        }
        
        // authenticate if necessary
        if (nil == sessionCookie) {
            [self authenticateWithOptions:options];
            if (nil == sessionCookie) {
                OSAtomicCompareAndSwap32Barrier(0, 1, &flags.failedDownload);
                OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);
                [[self serverOnMainThread] addPublicationsToGroup:nil];
                return;
            }
        }
        
        // perform WS query to get count of results; don't pass zero for record numbers, although it's not clear what the values mean in this context
        NSString *errorString = nil;
        WokSearchService_fullRecordSearchResults *fullRecordSearchResults = nil;
        WokSearchService_citedReferencesSearchResults *citedReferencesSearchResults = nil;
        WokSearchLiteService_searchResults *searchResults = nil;
        
        if ([[options objectForKey:@"lite"] boolValue]) {
            
            WokSearchLiteService_retrieveParameters *retrieveParameters = [[[WokSearchLiteService_retrieveParameters alloc] init] autorelease];
            [retrieveParameters setFirstRecord:[NSNumber numberWithInteger:fetchedResultsLocal + 1]];
            [retrieveParameters setCount:[NSNumber numberWithInteger:numResults]];
            
            WokSearchLiteServiceSoapBindingResponse *response = nil;
            
            WokSearchLiteServiceSoapBinding *binding = [WokSearchLiteService WokSearchLiteServiceSoapBinding];
            [binding addCookie:sessionCookie];
            //binding.logXMLInOut = YES;
            
            switch (operation) {
                case search:
                {
                    // Reto: this works for the Premium edition of WOKSearch (and not for WOKSearchLite)
                    WokSearchLiteService_search *searchRequest = [[[WokSearchLiteService_search alloc] init] autorelease];
                    WokSearchLiteService_queryParameters *queryParameters = [[[WokSearchLiteService_queryParameters alloc] init] autorelease];
                    [queryParameters setDatabaseId:database];
                    for (NSString *editionID in editionIDs) {
                        WokSearchLiteService_editionDesc *edition = [[[WokSearchLiteService_editionDesc alloc] init] autorelease];
                        [edition setCollection:database];
                        [edition setEdition:editionID];
                        [queryParameters addEditions:edition];
                    }
                    [queryParameters setUserQuery:searchTerm];
                    [queryParameters setQueryLanguage:EN_QUERY_LANG];
                    [searchRequest setQueryParameters:queryParameters];
                    [searchRequest setRetrieveParameters:retrieveParameters];
                    response = [binding searchUsingParameters:searchRequest];
                    for (id bodyPart in [response bodyParts]) {
                        if ([bodyPart isKindOfClass:[SOAPFault class]]) {
                            errorString = [(SOAPFault *)bodyPart simpleFaultString];
                        } else if ([bodyPart isKindOfClass:[WokSearchLiteService_searchResponse class]]) {
                            searchResults = [(WokSearchLiteService_searchResponse *)bodyPart return_];
                        }
                    }
                    break;
                }
                case retrieveById:
                {
                    // Reto: undocumented and untested. I'm going to check its usefulness before removing.
                    WokSearchLiteService_retrieveById *retrieveByIdRequest = [[[WokSearchLiteService_retrieveById alloc] init] autorelease];
                    [retrieveByIdRequest setDatabaseId:database];
                    for (NSString *uid in uidsFromString(searchTerm))
                        [retrieveByIdRequest addUid:uid];
                    [retrieveByIdRequest setQueryLanguage:EN_QUERY_LANG];
                    [retrieveByIdRequest setRetrieveParameters:retrieveParameters];
                    response = [binding retrieveByIdUsingParameters:retrieveByIdRequest];
                    for (id bodyPart in [response bodyParts]) {
                        if ([bodyPart isKindOfClass:[SOAPFault class]]) {
                            errorString = [(SOAPFault *)bodyPart simpleFaultString];
                        } else if ([bodyPart isKindOfClass:[WokSearchLiteService_retrieveByIdResponse class]]) {
                            searchResults = [(WokSearchLiteService_retrieveByIdResponse *)bodyPart return_];
                        }
                    }
                    break;
                }
                default:
                    break;
            }
            
        } else {
            
            NSMutableArray *editions = [NSMutableArray array];
            for (NSString *editionID in editionIDs) {
                WokSearchService_editionDesc *edition = [[[WokSearchService_editionDesc alloc] init] autorelease];
                [edition setCollection:database];
                [edition setEdition:editionID];
                [editions addObject:edition];
            }
            
            WokSearchService_retrieveParameters *retrieveParameters = [[[WokSearchService_retrieveParameters alloc] init] autorelease];
            [retrieveParameters setFirstRecord:[NSNumber numberWithInteger:fetchedResultsLocal + 1]];
            [retrieveParameters setCount:[NSNumber numberWithInteger:numResults]];
            
            WokSearchServiceSoapBindingResponse *response = nil;
            
            WokSearchServiceSoapBinding *binding = [WokSearchService WokSearchServiceSoapBinding];
            [binding addCookie:sessionCookie];
            //binding.logXMLInOut = YES;
            
            // @@ Currently limited to WOS database; extension to other WOS databases might require different WebService stubs?  
            // Note that the value we're passing as database is referred to as  "edition" in the WoS docs.
            // Reto: Edition is not really needed. If omitted, the search is performed in all WOK databases which yields
            // a more consistent result with the web search. 
            // Reto: We could actually search the whole Web of Knowledge DB by choice of
            // "WOK aas databaseID. This returns all sorts of fun references including Patents, Books etc, for which there is currently
            // no support in BibDesk anyway, so limit the search to WOS databaseID
            switch (operation) {
                case search:
                {
                    // Reto: this works for the Premium edition of WOKSearch (and not for WOKSearchLite)
                    WokSearchService_search *searchRequest = [[[WokSearchService_search alloc] init] autorelease];
                    WokSearchService_queryParameters *queryParameters = [[[WokSearchService_queryParameters alloc] init] autorelease];
                    [queryParameters setDatabaseId:database];
                    for (WokSearchService_editionDesc *edition in editions)
                        [queryParameters addEditions:edition];
                    [queryParameters setUserQuery:searchTerm];
                    [queryParameters setQueryLanguage:EN_QUERY_LANG];
                    [searchRequest setQueryParameters:queryParameters];
                    [searchRequest setRetrieveParameters:retrieveParameters];
                    response = [binding searchUsingParameters:searchRequest];
                    for (id bodyPart in [response bodyParts]) {
                        if ([bodyPart isKindOfClass:[SOAPFault class]]) {
                            errorString = [(SOAPFault *)bodyPart simpleFaultString];
                        } else if ([bodyPart isKindOfClass:[WokSearchService_searchResponse class]]) {
                            fullRecordSearchResults = [(WokSearchService_searchResponse *)bodyPart return_];
                        }
                    }
                    break;
                }
                case citedReferences:
                {
                    // Reto: undocumented and untested. I'm going to check its usefulness before removing.
                    WokSearchService_citedReferences *citedReferencesRequest = [[[WokSearchService_citedReferences alloc] init] autorelease];
                    [citedReferencesRequest setDatabaseId:database];
                    [citedReferencesRequest setUid:searchTerm];
                    //for (WokSearchService_editionDesc *edition in editions)
                    //    [citedReferencesRequest addEditions:edition];
                    // [citedReferencesRequest setTimeSpan:timeSpan];
                    [citedReferencesRequest setQueryLanguage:EN_QUERY_LANG];
                    [citedReferencesRequest setRetrieveParameters:retrieveParameters];
                    response = [binding citedReferencesUsingParameters:citedReferencesRequest];
                    for (id bodyPart in [response bodyParts]) {
                        if ([bodyPart isKindOfClass:[SOAPFault class]]) {
                            errorString = [(SOAPFault *)bodyPart simpleFaultString];
                        } else if ([bodyPart isKindOfClass:[WokSearchService_citedReferencesResponse class]]) {
                            citedReferencesSearchResults = [(WokSearchService_citedReferencesResponse *)bodyPart return_];
                        }
                    }
                    break;
                }
                case citingArticles:
                {
                    // Reto: undocumented and untested. I'm going to check its usefulness before removing.            
                    WokSearchService_citingArticles *citingArticlesRequest = [[[WokSearchService_citingArticles alloc] init] autorelease];
                    [citingArticlesRequest setDatabaseId:database];
                    [citingArticlesRequest setUid:searchTerm];
                    for (WokSearchService_editionDesc *edition in editions)
                        [citingArticlesRequest addEditions:edition];
                    WokSearchService_timeSpan *timeSpan = [[[WokSearchService_timeSpan alloc] init] autorelease];
                    timeSpan.begin = @"1600-01-01";
                    timeSpan.end = [[NSDate date] ISO8601DateStringWithTime:NO];
                    [citingArticlesRequest setTimeSpan:timeSpan];
                    [citingArticlesRequest setQueryLanguage:EN_QUERY_LANG];
                    [citingArticlesRequest setRetrieveParameters:retrieveParameters];
                    response = [binding citingArticlesUsingParameters:citingArticlesRequest];
                    for (id bodyPart in [response bodyParts]) {
                        if ([bodyPart isKindOfClass:[SOAPFault class]]) {
                            errorString = [(SOAPFault *)bodyPart simpleFaultString];
                        } else if ([bodyPart isKindOfClass:[WokSearchService_citingArticlesResponse class]]) {
                            fullRecordSearchResults = [(WokSearchService_citingArticlesResponse *)bodyPart return_];
                        }
                    }
                    break;
                }
                case relatedRecords:
                {
                    // Reto: undocumented and untested. I'm going to check its usefulness before removing.
                    WokSearchService_relatedRecords *relatedRecordsRequest = [[[WokSearchService_relatedRecords alloc] init] autorelease];
                    [relatedRecordsRequest setDatabaseId:database];
                    [relatedRecordsRequest setUid:searchTerm];
                    for (WokSearchService_editionDesc *edition in editions)
                        [relatedRecordsRequest addEditions:edition];
                    // [relatedRecordsRequest setTimeSpan:timeSpan];
                    [relatedRecordsRequest setQueryLanguage:EN_QUERY_LANG];
                    [relatedRecordsRequest setRetrieveParameters:retrieveParameters];
                    response = [binding relatedRecordsUsingParameters:relatedRecordsRequest];
                    for (id bodyPart in [response bodyParts]) {
                        if ([bodyPart isKindOfClass:[SOAPFault class]]) {
                            errorString = [(SOAPFault *)bodyPart simpleFaultString];
                        } else if ([bodyPart isKindOfClass:[WokSearchService_relatedRecordsResponse class]]) {
                            fullRecordSearchResults = [(WokSearchService_relatedRecordsResponse *)bodyPart return_];
                        }
                    }
                    break;
                }
                case retrieveById:
                {
                    // Reto: undocumented and untested. I'm going to check its usefulness before removing.
                    WokSearchService_retrieveById *retrieveByIdRequest = [[[WokSearchService_retrieveById alloc] init] autorelease];
                    [retrieveByIdRequest setDatabaseId:database];
                    for (NSString *uid in uidsFromString(searchTerm))
                        [retrieveByIdRequest addUid:uid];
                    [retrieveByIdRequest setQueryLanguage:EN_QUERY_LANG];
                    [retrieveByIdRequest setRetrieveParameters:retrieveParameters];
                    response = [binding retrieveByIdUsingParameters:retrieveByIdRequest];
                    for (id bodyPart in [response bodyParts]) {
                        if ([bodyPart isKindOfClass:[SOAPFault class]]) {
                            errorString = [(SOAPFault *)bodyPart simpleFaultString];
                        } else if ([bodyPart isKindOfClass:[WokSearchService_retrieveByIdResponse class]]) {
                            fullRecordSearchResults = [(WokSearchService_retrieveByIdResponse *)bodyPart return_];
                        }
                    }
                    break;
                }
            }
            
        }
        
        NSArray *records = nil;
        
        if (citedReferencesSearchResults) {
            records = [citedReferencesSearchResults references];
            availableResultsLocal = [[citedReferencesSearchResults recordsFound] integerValue];
        } else if (fullRecordSearchResults) {
            NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithXMLString:[fullRecordSearchResults records] options:0 error:NULL] autorelease];
            records = [doc nodesForXPath:@"/records/REC" error:NULL];
            availableResultsLocal = [[fullRecordSearchResults recordsFound] integerValue];
        } else if (searchResults) {
            records = [searchResults records];
            availableResultsLocal = [[searchResults recordsFound] integerValue];
        } else {
            // we already know that a connection can be made, so we likely don't have permission to read this edition or database
            if (errorString == nil)
                errorString = NSLocalizedString(@"Unable to retrieve results.  You may not have permission to use this database, or your query syntax may be incorrect.", @"Error message when connection to Web of Science fails.");
            else
                errorString = [errorString stringByDeletingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            [self setErrorMessage:errorString];
            if ([errorString hasPrefix:@"There is a problem with your session identifier (SID)."]) {
                // this error usually indicates the session has expired, so discard the cookie to allow authentication again
                [sessionCookie release];
                sessionCookie = nil;
            }
            OSAtomicCompareAndSwap32Barrier(0, 1, &flags.failedDownload);
            OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);
            [[self serverOnMainThread] addPublicationsToGroup:nil];
            return;
        }
        
        NSMutableArray *pubs = [NSMutableArray array];
        for (id record in records) {
            NSDictionary *pubInfo = [record newWOKPublicationInfo];
            [pubs addObject:pubInfo];
            [pubInfo release];
        }
        
        // now increment this so we don't get the same set next time; BDSKSearchGroup resets it when the search term changes
        fetchedResultsLocal += [pubs count];
        
        OSAtomicCompareAndSwap32Barrier(availableResults, availableResultsLocal, &availableResults);
        OSAtomicCompareAndSwap32Barrier(fetchedResults, fetchedResultsLocal, &fetchedResults);
        
        // set this flag before adding pubs, or the client will think we're still retrieving (and spinners don't stop)
        OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);
        
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:pubs];
        
        // this will create the array if it doesn't exist
        [[self serverOnMainThread] addPublicationsToGroup:data];
        
    }
}

- (void)authenticateWithOptions:(NSDictionary *)options {

    WOKMWSAuthenticateServiceSoapBinding *binding = [WOKMWSAuthenticateService WOKMWSAuthenticateServiceSoapBinding];
    //binding.logXMLInOut = YES;
    [binding setAuthUsername:[options objectForKey:@"username"]];
    [binding setAuthPassword:[options objectForKey:@"password"]];
    
    WOKMWSAuthenticateService_authenticate *request = [[[WOKMWSAuthenticateService_authenticate alloc] init] autorelease];
    
    WOKMWSAuthenticateServiceSoapBindingResponse *response = [binding authenticateUsingParameters:request];
    
    for (id bodyPart in [response bodyParts]) {
        
        if ([bodyPart isKindOfClass:[SOAPFault class]]) {
        
            NSString *errorString = [(SOAPFault *)bodyPart simpleFaultString];
            [self setErrorMessage:[NSString stringWithFormat:NSLocalizedString(@"WOK Authentication Error: %@", "WOK Authentication Error Format"), errorString]];
            [sessionCookie release];
            sessionCookie = nil;
        } else if ([bodyPart isKindOfClass:[WOKMWSAuthenticateService_authenticateResponse class]]) {
        
            // if we reach this point the only session cookie should be the SID
            [sessionCookie release];
            sessionCookie = [[[binding cookies] objectAtIndex:0] retain];
        }
    }
}

- (void)serverDidFinish {
    if (sessionCookie) {
        @try {
            WOKMWSAuthenticateServiceSoapBinding *binding = [WOKMWSAuthenticateService WOKMWSAuthenticateServiceSoapBinding];
            WOKMWSAuthenticateService_closeSession *request = [[[WOKMWSAuthenticateService_closeSession alloc] init] autorelease];
            [binding addCookie:sessionCookie];
            [binding closeSessionUsingParameters:request];
        }
        @catch (id exception) {
            NSLog(@"Exception \"%@\" raised in object %@", exception, self);
        }
    }
}

@end

static NSArray *uidsFromString(NSString *uidString) {
    NSCharacterSet *uidCharSet = nil;
    if (uidCharSet == nil) {
        NSMutableCharacterSet *mutableSet = [NSMutableCharacterSet alphanumericCharacterSet];
        [mutableSet addCharactersInString:@":"];
        uidCharSet = [mutableSet copy];
    }
    NSMutableArray *uids = [NSMutableArray array];
    NSScanner *scanner = [NSScanner scannerWithString:uidString];
    NSString *uid;
    [scanner scanUpToCharactersFromSet:uidCharSet intoString:NULL];
    while ([scanner isAtEnd] == NO) {
        if ([scanner scanCharactersFromSet:uidCharSet intoString:&uid])
            [uids addObject:uid];
        [scanner scanString:@" OR " intoString:NULL] || [scanner scanUpToCharactersFromSet:uidCharSet intoString:NULL];
    }
    
    return uids;
}

#pragma mark -
#pragma mark Record Parsing

// convenience to avoid creating a local variable and checking it each time
static inline void addStringToDictionaryIfNotNil(NSString *value, NSString *key, NSMutableDictionary *dict)
{
    if (value) [dict setObject:[value stringByBackslashEscapingTeXSpecials] forKey:key];
}

// convenience method to add the stringValue for the nodes from an XPath query, either the first one or all joined by a string
static void addStringForXPathToDictionary(NSXMLNode *node, NSString *XPath, NSString *join, NSString *field, NSMutableDictionary *pubFields)
{
    NSArray *nodes = [node nodesForXPath:XPath error:NULL];
    if ([nodes count]) {
        NSString *stringValue = nil;
        if (join && [nodes count] > 1)
            stringValue = [[nodes valueForKey:@"stringValue"] componentsJoinedByString:join];
        else
            stringValue = [[nodes objectAtIndex:0] stringValue];
        addStringToDictionaryIfNotNil(stringValue, field, pubFields);
    }
}

static void addDateStringToDictionary(NSString *value, NSMutableDictionary *pubFields)
{
    //             There are at least 3 variants of this, so it's not always possible to get something
    //             truly useful from it.
    
    //             <bib_date date="AUG" year="2008">AUG 2008</bib_date>
    //             <bib_date date="JUN 19" year="2008">JUN 19 2008</bib_date>
    //             <bib_date date="MAR-APR" year="2007">MAR-APR 2007</bib_date>		
    NSString *monthString;
    NSScanner *scanner = nil;
    if (value)
        scanner = [[NSScanner alloc] initWithString:value];
    static NSCharacterSet *monthSet = nil;
    if (nil == monthSet) {
        NSMutableCharacterSet *cset = [[NSCharacterSet letterCharacterSet] mutableCopy];
        [cset addCharactersInString:@"-"];
        monthSet = [cset copy];
        [cset release];
    }
    if ([scanner scanCharactersFromSet:monthSet intoString:&monthString]) {
        if ([monthString rangeOfString:@"-"].length == 0) {
            monthString = [NSString stringWithBibTeXString:[monthString lowercaseString] macroResolver:nil error:NULL];
        } else {
            monthString = [monthString titlecaseString];
            addStringToDictionaryIfNotNil(monthString, BDSKMonthString, pubFields);
        }
    } else {
        addStringToDictionaryIfNotNil(value, BDSKDateString, pubFields);
    }
    [scanner release];
}

static void addAuthorNamesToDictionary(NSArray *names, NSMutableDictionary *pubFields)
{
    NSMutableString *namesString = nil;
    static NSCharacterSet *nonUpperChars = nil;
    if (nonUpperChars == nil) {
        NSMutableCharacterSet *mutableSet = [NSMutableCharacterSet uppercaseLetterCharacterSet];
        [mutableSet formUnionWithCharacterSet:[NSCharacterSet nonBaseCharacterSet]];
        [mutableSet invert];
        nonUpperChars = [mutableSet copy];
    }
    
    for (NSString *name in names) {
        if (namesString == nil)
            namesString = [NSMutableString string];
        else
            [namesString appendString:@" and "];
        [namesString appendString:name];
        // e.g. "Petersen, JK" should become "Peterson, J. K."
        NSRange range = [name rangeOfString:@", "];
        if (range.location != NSNotFound) {
            range = NSMakeRange(NSMaxRange(range), [name length] - NSMaxRange(range));
            // if there are lower case letters or periods, don't mess with it
            if (range.length > 0 && [name rangeOfCharacterFromSet:nonUpperChars options:0 range:range].location == NSNotFound) {
                NSUInteger idx = range.location + [namesString length] - [name length];
                while (YES) {
                    idx = NSMaxRange([namesString rangeOfComposedCharacterSequenceAtIndex:idx]);
                    if (idx < [namesString length]) {
                        [namesString insertString:@". " atIndex:idx];
                        idx += 2;
                    } else {
                        [namesString appendString:@"."];
                        break;
                    }
                }
            }
        }
    }
    addStringToDictionaryIfNotNil(namesString, BDSKAuthorString, pubFields);
}

#pragma mark -

@implementation NSObject (BDSKISIGroupServer)

- (NSDictionary *)newWOKPublicationInfo {
    return [[NSDictionary alloc] initWithObjectsAndKeys:BDSKArticleString, BDSKPubTypeString, nil];
}

@end

@implementation NSXMLNode (BDSKISIGroupServer)

- (NSDictionary *)newWOKPublicationInfo {
    // this is now a field/value set for a particular publication self
    NSMutableDictionary *pubFields = [NSMutableDictionary new];
   
    // default value for publication type
    NSString *isiPubType = nil;
	NSString *journalName = nil;

	/* get some major branches of XML nodes which are used several times */
	NSXMLNode *staticChild = [[self nodesForXPath:@"./static_data" error:NULL] firstObject];
	NSXMLNode *summaryChild = [[staticChild nodesForXPath:@"./summary" error:NULL] firstObject];
	NSXMLNode *dynamicChild = [[self nodesForXPath:@"./dynamic_data" error:NULL] firstObject];
    NSXMLNode *child;
	
	/* get WOK UID */
    addStringForXPathToDictionary(self, @"./UID", nil, WOK_UID_FIELDNAME, pubFields);
    
	/* get authors */
    NSArray *authorNames = [[summaryChild nodesForXPath:@"./names/name/full_name" error:NULL] valueForKey:@"stringValue"];
    addAuthorNamesToDictionary(authorNames, pubFields);
	
	/* get title, journal name etc */
    for (child in [summaryChild nodesForXPath:@"./titles/title" error:NULL]) {
		NSString *typeString = [[(NSXMLElement *)child attributeForName:@"type"] stringValue];
        if ([typeString isEqualToString:@"item"]) {
            addStringToDictionaryIfNotNil([child stringValue], BDSKTitleString, pubFields);
        } else if ([typeString isEqualToString:@"source"]) {
			journalName = (useTitlecase ? [[child stringValue] titlecaseString] : [child stringValue]);
            addStringToDictionaryIfNotNil(journalName, BDSKJournalString, pubFields);
		} else if ([typeString isEqualToString:@"source_abbrev"]) {
            addStringToDictionaryIfNotNil((useTitlecase ? [[child stringValue] titlecaseString] : [child stringValue]), @"Iso-Source-Abbreviation", pubFields);
        }
    }
	
	/* get publication year, volume, issue and month */
	child = [[summaryChild nodesForXPath:@"./pub_info" error:NULL] firstObject];
	if (child != nil) {
		addStringForXPathToDictionary(child, @"./@pubyear", nil, BDSKYearString, pubFields);
		addStringForXPathToDictionary(child, @"./@vol", nil, BDSKVolumeString, pubFields);
		addStringForXPathToDictionary(child, @"./@issue", nil, BDSKNumberString, pubFields);
		
		isiPubType = [[(NSXMLElement *)child attributeForName:@"pubtype"] stringValue];
//		NSLog(@"isiPubType:\n%@", isiPubType);
        
        addDateStringToDictionary([[(NSXMLElement *)child attributeForName:@"pubmonth"] stringValue], pubFields);
        
        /* get page numbers */
        child = [[child nodesForXPath:@"./page" error:NULL] firstObject];
        if (child != nil) {
            NSString *begin = [[(NSXMLElement *)child attributeForName:@"begin"] stringValue];
            NSString *end = [[(NSXMLElement *)child attributeForName:@"end"] stringValue];
            if (NO == [NSString isEmptyString:begin]) {
                if (NO == [NSString isEmptyString:end])
                    addStringToDictionaryIfNotNil([NSString stringWithFormat:@"%@--%@", begin, end], BDSKPagesString, pubFields);
                else
                    addStringToDictionaryIfNotNil(begin, BDSKPagesString, pubFields);
            }
            //else if (NO == [[child stringValue] isEqualToString:@"-"])
            //    addStringToDictionaryIfNotNil([child stringValue], BDSKPagesString, pubFields);			
        }
	}	

	
	/* get the document / publication type */
	/* needs some more testing for conferences etc. maybe we also need to get the conference name? */
    NSString *pubType = BDSKArticleString;
	child = [[summaryChild nodesForXPath:@"./doctypes/doctype" error:NULL] firstObject]; 	
    if (child != nil) {		
		NSString *docType = [child stringValue];			
//		NSLog(@"docType:\n%@", docType);
		/*
		I've seen "Meeting Abstract" and "Article" as common types.  However, "Geomorphology" and 
		"Estuarine Coastal and Shelf Science" articles are sometimes listed as "Proceedings Paper"
		which is clearly wrong.  Likewise, any journal with "Review" in the name is listed as a 
		"Review" type, when it should probably be a journal (e.g., "Earth Science Reviews").
		*/
		if ([docType isEqualToString:@"Journal Paper"] || [docType isEqualToString:@"Review"] || [docType isEqualToString:@"Book Review"]) {
			pubType = BDSKArticleString;
		} else if ([docType isEqualToString:@"Meeting Abstract"]) {
			pubType = BDSKInproceedingsString;
		} else if ([docType isEqualToString:@"Proceedings Paper"]) {
			pubType = BDSKInproceedingsString;
            if (journalName)
                [pubFields setObject:journalName forKey:BDSKBooktitleString];
		} else if ([isiPubType isEqualToString:@"Journal"]) {
            pubType = BDSKArticleString;
        } else {
            // preserve the type if it's unclear
            pubType = [docType entryType];
		}
    }
    
	[pubFields setObject:pubType forKey:BDSKPubTypeString];

	/* get publisher name and address */
	child = [[summaryChild nodesForXPath:@"./publishers/publisher" error:NULL] firstObject]; 	
    if (child != nil) {		
        addStringForXPathToDictionary(child, @"./names/name/full_name", nil, BDSKPublisherString, pubFields);
        addStringForXPathToDictionary(child, @"./address_spec/full_address", nil, BDSKAddressString, pubFields);
    }
    
    /* get abstract */
    addStringForXPathToDictionary(staticChild, @"./fullrecord_metadata/abstracts/abstract/abstract_text/p", @"\n\n", BDSKAbstractString, pubFields);
    
    /* get keywords */
    NSString *keywordSeparator = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKDefaultGroupFieldSeparatorKey];
    addStringForXPathToDictionary(staticChild, @"./item/keywords_plus/keyword", keywordSeparator, BDSKKeywordsString, pubFields);						
    
    /* get identifiers (DOI, ISSN, ISBN) */
    for (child in [dynamicChild nodesForXPath:@"./cluster_related/identifiers/identifier" error:NULL]) {
        NSString *typeString = [[(NSXMLElement *)child attributeForName:@"type"] stringValue];
        if ([typeString isEqualToString:@"doi"]) {
            addStringForXPathToDictionary(child, @"./@value", nil, BDSKDoiString, pubFields);
        } else if ([typeString isEqualToString:@"issn"]) {
            addStringForXPathToDictionary(child, @"./@value", nil, @"Issn", pubFields);
        } else if ([typeString isEqualToString:@"isbn"]) {
            addStringForXPathToDictionary(child, @"./@value", nil, @"Isbn", pubFields);
        } else if ([typeString isEqualToString:@"art_no"] && [pubFields objectForKey:BDSKNumberString] == nil) {
            NSString *artnum = [[[(NSXMLElement *)child attributeForName:@"value"] stringValue] stringByRemovingPrefix:@"ARTN "];
            addStringToDictionaryIfNotNil(artnum, BDSKNumberString, pubFields);
        }
    }
    
    /* get times-cited */
    addStringForXPathToDictionary(dynamicChild, @"./citation_related/tc_list/silo_tc/@local_count", nil, @"Times-Cited", pubFields);
	
    return pubFields;
}

@end

@implementation WokSearchService_citedReference (BDSKISIGroupServer)

- (NSDictionary *)newWOKPublicationInfo {
    NSMutableDictionary *pubFields = [NSMutableDictionary new];
    
    [pubFields setObject:BDSKArticleString forKey:BDSKPubTypeString];
    
    addStringToDictionaryIfNotNil([self uid], WOK_UID_FIELDNAME, pubFields);
    
    addAuthorNamesToDictionary([NSArray arrayWithObjects:[self citedAuthor], nil], pubFields);
    
    addStringToDictionaryIfNotNil((useTitlecase ? [[self citedWork] titlecaseString] : [self citedWork]), BDSKJournalString, pubFields);

    addStringToDictionaryIfNotNil([self page], BDSKPagesString, pubFields);
    addStringToDictionaryIfNotNil([self timesCited], @"Times-Cited", pubFields);
    addStringToDictionaryIfNotNil([self volume], BDSKVolumeString, pubFields);
    addStringToDictionaryIfNotNil([self year], BDSKYearString, pubFields);
    
    return pubFields;
}

@end

@implementation WokSearchLiteService_liteRecord (BDSKISIGroupServer)

- (NSDictionary *)newWOKPublicationInfo {

    NSMutableDictionary *pubFields = [NSMutableDictionary new];
    
    [pubFields setObject:BDSKArticleString forKey:BDSKPubTypeString];

    addStringToDictionaryIfNotNil([self uid], WOK_UID_FIELDNAME, pubFields);
    
    WokSearchLiteService_labelValuesPair *pair = nil;
    
    for (pair in [self authors]) {
        if ([[pair label] isEqualToString:@"Authors"])
            addAuthorNamesToDictionary([pair value], pubFields);
    }
    
    for (pair in [self title]) {
        if ([[pair label] isEqualToString:@"Title"])
            addStringToDictionaryIfNotNil([[pair value] firstObject], BDSKTitleString, pubFields);
        else if ([[pair label] isEqualToString:@"Issue"])
            addStringToDictionaryIfNotNil([[pair value] firstObject], BDSKNumberString, pubFields);
    }
    
    for (pair in [self source]) {
        if ([[pair label] isEqualToString:@"Pages"])
            addStringToDictionaryIfNotNil([[pair value] firstObject], BDSKPagesString, pubFields);
        else if ([[pair label] isEqualToString:@"Published.BiblioDate"])
            addDateStringToDictionary([[pair value] firstObject], pubFields);
        else if ([[pair label] isEqualToString:@"Published.BiblioYear"])
            addStringToDictionaryIfNotNil([[pair value] firstObject], BDSKYearString, pubFields);
        else if ([[pair label] isEqualToString:@"SourceTitle"])
            addStringToDictionaryIfNotNil(useTitlecase ? [[[pair value] firstObject] titlecaseString] : [[pair value] firstObject], BDSKJournalString, pubFields);
        else if ([[pair label] isEqualToString:@"Volume"])
            addStringToDictionaryIfNotNil([[pair value] firstObject], BDSKVolumeString, pubFields);
    }

    NSString *keywordSeparator = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKDefaultGroupFieldSeparatorKey];
    for (pair in [self keywords]) {
        if ([[pair label] isEqualToString:@"Keywords"])
            addStringToDictionaryIfNotNil([[pair value] componentsJoinedByString:keywordSeparator], BDSKKeywordsString, pubFields);
    }
    
    for (pair in [self other]) {
        if ([[pair label] isEqualToString:@"Identifier.Doi"])
            addStringToDictionaryIfNotNil([[pair value] firstObject], BDSKDoiString, pubFields);
        else if ([[pair label] isEqualToString:@"Identifier.Issn"])
            addStringToDictionaryIfNotNil([[pair value] firstObject], @"Issn", pubFields);
        else if ([[pair label] isEqualToString:@"Identifier.Isbn"])
            addStringToDictionaryIfNotNil([[pair value] firstObject], @"Isbn", pubFields);
		else if ([[pair label] isEqualToString:@"Identifier.Article_no"] && [pubFields objectForKey:BDSKNumberString] == nil)
            addStringToDictionaryIfNotNil([[[pair value] firstObject] stringByRemovingPrefix:@"ARTN "], BDSKNumberString, pubFields);
    }
    
    return pubFields;
}

@end

//
//  BDSKISIGroupServer.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/10/07.
/*
 This software is Copyright (c) 2007-2016
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
#import "WokServiceSoapBinding.h"
#import "WOKMWSAuthenticateService.h"
#import "WokSearchService.h"
#import "WokSearchLiteService.h"
#import "BDSKLinkedFile.h"
#import "BDSKServerInfo.h"
#import "BibItem.h"
#import "BDSKMacroResolver.h"
#import "NSArray_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"

#define WOS_DB_ID @"WOS"
#define EN_QUERY_LANG @"en"

#define BDSKAddISIXMLStringToAnnoteKey @"BDSKAddISIXMLStringToAnnote"
#define BDSKDisableISITitleCasingKey @"BDSKDisableISITitleCasing"
#define BDSKISISourceXMLTagPriorityKey @"BDSKISISourceXMLTagPriority"
#define BDSKISIURLFieldNameKey @"BDSKISIURLFieldName"

#define WOK_UID_FIELDNAME @"Wok-Uid"

#define MAX_RESULTS 100

static BOOL addXMLStringToAnnote = NO;
static BOOL useTitlecase = YES;
static NSArray *sourceXMLTagPriority = nil;
static NSString *ISIURLFieldName = nil;

static NSSet *WOSEditions = nil;

static NSCharacterSet *nonMonthCharSet = nil;
static NSCharacterSet *nonUpperCharSet = nil;
static NSCharacterSet *uidCharSet = nil;

static NSArray *uidsFromString(NSString *uidString);

static NSString *dateFromSearchTerm(NSString *searchTerm, BOOL begin, NSRange *rangePtr);

// should be implemented by returned searchResults classes
@interface NSObject (BDSKWOKSearchResults)
- (NSArray *)WOKRecords;
@end

// should be implemented by record classes
@interface NSObject (BDSKWOKRecord)
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
- (BOOL)authenticateWithOptions:(NSDictionary *)options;
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
    
    NSMutableCharacterSet *mutableSet = [NSMutableCharacterSet letterCharacterSet];
    [mutableSet addCharactersInString:@"-"];
    [mutableSet invert];
    nonMonthCharSet = [mutableSet copy];
    mutableSet = [NSMutableCharacterSet uppercaseLetterCharacterSet];
    [mutableSet formUnionWithCharacterSet:[NSCharacterSet nonBaseCharacterSet]];
    [mutableSet invert];
    nonUpperCharSet = [mutableSet copy];
    mutableSet = [NSMutableCharacterSet alphanumericCharacterSet];
    [mutableSet addCharactersInString:@":"];
    uidCharSet = [mutableSet copy];
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
    BDSKDESTROY(sessionCookie);
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
    if ([[NSURL URLWithString:[serverInfo isLite] ? [WokSearchLiteService address] : [WokSearchService address]] canConnect]) {
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
            
            // we set the macroResolver so we know the fields of this item may refer to it, so we can prevent scripting from adding this to the wrong document
            [pub setMacroResolver:[group macroResolver]];
            
            [pubs addObject:pub];
            [pub release];
            [pubFields release];
            [files release];
        }
    }
    [group addPublications:pubs];
}

#pragma mark Server thread

- (oneway void)downloadWithSearchTerm:(NSString *)searchTerm database:(NSString *)database options:(NSDictionary *)options;
{    
    NSInteger availableResultsLocal = [self numberOfAvailableResults];
    NSInteger fetchedResultsLocal = [self numberOfFetchedResults];
    NSInteger numResults = MAX_RESULTS;
    NSData *data = nil;
    
    if (availableResultsLocal > 0)
        numResults = MIN(availableResultsLocal - fetchedResultsLocal, MAX_RESULTS);
    
    // Strip whitespace from the BDSKWOKSearch term to make WOS happy
    searchTerm = [searchTerm stringByRemovingSurroundingWhitespace];
    
    if (numResults > 0 && [NSString isEmptyString:searchTerm] == NO) {
        
        // authenticate if necessary
        if ([self authenticateWithOptions:options]) {
            
            enum BDSKOperationTypes { BDSKWOKSearch, BDSKWOKCitedBy, BDSKWOKCiting, BDSKWOKRelated, BDSKWOKUid } operation = BDSKWOKSearch;
            static NSString *operator[5] = {@"", @"citedby:", @"citing:", @"related:", @"uid:"};
            
            // extract special BDSKWOKSearch operators
            for (operation = BDSKWOKUid; operation > BDSKWOKSearch; --operation)
                if ([searchTerm hasCaseInsensitivePrefix:operator[operation]]) break;
            
            // extract begin: or end: dates for time span
            NSRange beginRange, endRange;
            NSString *begin = dateFromSearchTerm(searchTerm, YES, &beginRange);
            NSString *end = dateFromSearchTerm(searchTerm, NO, &endRange);
            
            if (begin || end || operation != BDSKWOKSearch) {
                // remove the operators from the BDSKWOKSearch term
                NSMutableString *tmpString = [[searchTerm mutableCopy] autorelease];
                if (end) {
                    [tmpString deleteCharactersInRange:endRange];
                    if (begin && beginRange.location > endRange.location)
                        beginRange.location -= endRange.length;
                }
                if (begin)
                    [tmpString deleteCharactersInRange:beginRange];
                if (operation != BDSKWOKSearch)
                    [tmpString deleteCharactersInRange:NSMakeRange(0, [operator[operation] length])];
                searchTerm = [tmpString stringByRemovingSurroundingWhitespace];
            }
            if (operation == BDSKWOKSearch && [searchTerm rangeOfString:@"="].location == NSNotFound)
                searchTerm = [NSString stringWithFormat:@"TS=\"%@\"", searchTerm];
            
            NSArray *editionIDs = nil;
            
            database = [database stringByCollapsingWhitespaceAndRemovingSurroundingWhitespace];
            // split the database into a database ID optionally followed by edition IDs, separated by space
            NSArray *ids = [database componentsSeparatedByString:@" "];
            database = [ids firstObject];
            // legacy, the database used to be just a WOS edition ID without the database ID
            if ([WOSEditions containsObject:database]) {
                database = WOS_DB_ID;
                editionIDs = ids;
            } else if ([ids count] > 1) {
                editionIDs = [ids subarrayWithRange:NSMakeRange(1, [ids count] - 1)];
            }
            
            WokServiceSoapBindingResponse *response = nil;
            NSString *errorString = nil;
            
            if ([[options objectForKey:@"lite"] boolValue]) {
                
                WokSearchLiteService *binding = [WokSearchLiteService soapBinding];
                [binding addCookie:sessionCookie];
                //binding.logXMLInOut = YES;
                
                WokSearchLiteService_retrieveParameters *retrieveParameters = [[[WokSearchLiteService_retrieveParameters alloc] init] autorelease];
                [retrieveParameters setFirstRecord:[NSNumber numberWithInteger:fetchedResultsLocal + 1]];
                [retrieveParameters setCount:[NSNumber numberWithInteger:numResults]];
                
                switch (operation) {
                    case BDSKWOKSearch:
                    {
                        WokSearchLiteService_search *searchRequest = [[[WokSearchLiteService_search alloc] init] autorelease];
                        WokSearchLiteService_queryParameters *queryParameters = [[[WokSearchLiteService_queryParameters alloc] init] autorelease];
                        [queryParameters setDatabaseId:database];
                        for (NSString *editionID in editionIDs) {
                            WokSearchLiteService_editionDesc *edition = [[[WokSearchLiteService_editionDesc alloc] init] autorelease];
                            NSRange range = [editionID rangeOfString:@"."];
                            [edition setCollection:range.location == NSNotFound ? database : [editionID substringToIndex:range.location]];
                            [edition setEdition:range.location == NSNotFound ? editionID : [editionID substringFromIndex:NSMaxRange(range)]];
                            [queryParameters addEditions:edition];
                        }
                        [queryParameters setUserQuery:searchTerm];
                        if (begin || end) {
                            WokSearchLiteService_timeSpan *timeSpan = [[[WokSearchLiteService_timeSpan alloc] init] autorelease];
                            [timeSpan setBegin:begin ?: @"1800-01-01"];
                            [timeSpan setEnd:end ?: dateFromSearchTerm(@"end:--", NO, NULL)];
                            [queryParameters setTimeSpan:timeSpan];
                        }
                        [queryParameters setQueryLanguage:EN_QUERY_LANG];
                        [searchRequest setQueryParameters:queryParameters];
                        [searchRequest setRetrieveParameters:retrieveParameters];
                        response = [binding searchUsingParameters:searchRequest];
                        break;
                    }
                    case BDSKWOKUid:
                    {
                        WokSearchLiteService_retrieveById *retrieveByIdRequest = [[[WokSearchLiteService_retrieveById alloc] init] autorelease];
                        [retrieveByIdRequest setDatabaseId:database];
                        for (NSString *uid in uidsFromString(searchTerm))
                            [retrieveByIdRequest addUid:uid];
                        [retrieveByIdRequest setQueryLanguage:EN_QUERY_LANG];
                        [retrieveByIdRequest setRetrieveParameters:retrieveParameters];
                        response = [binding retrieveByIdUsingParameters:retrieveByIdRequest];
                        break;
                    }
                    case BDSKWOKCitedBy:
                        errorString = [NSString stringWithFormat:NSLocalizedString(@"The WOK Light service does not support the %@ operation.", @"WOK search error message"), @"citedby:"];
                        break;
                    case BDSKWOKCiting:
                        errorString = [NSString stringWithFormat:NSLocalizedString(@"The WOK Light service does not support the %@ operation.", @"WOK search error message"), @"citing:"];
                        break;
                    case BDSKWOKRelated:
                        errorString = [NSString stringWithFormat:NSLocalizedString(@"The WOK Light service does not support the %@ operation.", @"WOK search error message"), @"related:"];
                        break;
                }
                
            } else {
                
                WokSearchService *binding = [WokSearchService soapBinding];
                [binding addCookie:sessionCookie];
                //binding.logXMLInOut = YES;
                
                NSMutableArray *editions = [NSMutableArray array];
                for (NSString *editionID in editionIDs) {
                    WokSearchService_editionDesc *edition = [[[WokSearchService_editionDesc alloc] init] autorelease];
                    NSRange range = [editionID rangeOfString:@"."];
                    [edition setCollection:range.location == NSNotFound ? database : [editionID substringToIndex:range.location]];
                    [edition setEdition:range.location == NSNotFound ? editionID : [editionID substringFromIndex:NSMaxRange(range)]];
                    [editions addObject:edition];
                }
                
                WokSearchService_timeSpan *timeSpan = nil;
                if (begin || end || operation == BDSKWOKCiting) {
                    timeSpan = [[[WokSearchService_timeSpan alloc] init] autorelease];
                    [timeSpan setBegin:begin ?: @"1800-01-01"];
                    [timeSpan setEnd:end ?: dateFromSearchTerm(@"end:--", NO, NULL)];
                }
                
                WokSearchService_retrieveParameters *retrieveParameters = [[[WokSearchService_retrieveParameters alloc] init] autorelease];
                [retrieveParameters setFirstRecord:[NSNumber numberWithInteger:fetchedResultsLocal + 1]];
                [retrieveParameters setCount:[NSNumber numberWithInteger:numResults]];
                
                // Reto: Edition is not really needed. If omitted, the BDSKWOKSearch is performed in all WOK databases which yields
                // a more consistent result with the web BDSKWOKSearch. 
                // Reto: We could actually BDSKWOKSearch the whole Web of Knowledge DB by choice of WOK as databaseID.
                switch (operation) {
                    case BDSKWOKSearch:
                    {
                        WokSearchService_search *searchRequest = [[[WokSearchService_search alloc] init] autorelease];
                        WokSearchService_queryParameters *queryParameters = [[[WokSearchService_queryParameters alloc] init] autorelease];
                        [queryParameters setDatabaseId:database];
                        for (WokSearchService_editionDesc *edition in editions)
                            [queryParameters addEditions:edition];
                        [queryParameters setUserQuery:searchTerm];
                        [queryParameters setTimeSpan:timeSpan];
                        [queryParameters setQueryLanguage:EN_QUERY_LANG];
                        [searchRequest setQueryParameters:queryParameters];
                        [searchRequest setRetrieveParameters:retrieveParameters];
                        response = [binding searchUsingParameters:searchRequest];
                        break;
                    }
                    case BDSKWOKCitedBy:
                    {
                        WokSearchService_citedReferences *citedReferencesRequest = [[[WokSearchService_citedReferences alloc] init] autorelease];
                        [citedReferencesRequest setDatabaseId:database];
                        [citedReferencesRequest setUid:searchTerm];
                        [citedReferencesRequest setQueryLanguage:EN_QUERY_LANG];
                        [citedReferencesRequest setRetrieveParameters:retrieveParameters];
                        response = [binding citedReferencesUsingParameters:citedReferencesRequest];
                        break;
                    }
                    case BDSKWOKCiting:
                    {
                        WokSearchService_citingArticles *citingArticlesRequest = [[[WokSearchService_citingArticles alloc] init] autorelease];
                        [citingArticlesRequest setDatabaseId:database];
                        [citingArticlesRequest setUid:searchTerm];
                        for (WokSearchService_editionDesc *edition in editions)
                            [citingArticlesRequest addEditions:edition];
                        [citingArticlesRequest setTimeSpan:timeSpan];
                        [citingArticlesRequest setQueryLanguage:EN_QUERY_LANG];
                        [citingArticlesRequest setRetrieveParameters:retrieveParameters];
                        response = [binding citingArticlesUsingParameters:citingArticlesRequest];
                        break;
                    }
                    case BDSKWOKRelated:
                    {
                        WokSearchService_relatedRecords *relatedRecordsRequest = [[[WokSearchService_relatedRecords alloc] init] autorelease];
                        [relatedRecordsRequest setDatabaseId:database];
                        [relatedRecordsRequest setUid:searchTerm];
                        for (WokSearchService_editionDesc *edition in editions)
                            [relatedRecordsRequest addEditions:edition];
                        [relatedRecordsRequest setTimeSpan:timeSpan];
                        [relatedRecordsRequest setQueryLanguage:EN_QUERY_LANG];
                        [relatedRecordsRequest setRetrieveParameters:retrieveParameters];
                        response = [binding relatedRecordsUsingParameters:relatedRecordsRequest];
                        break;
                    }
                    case BDSKWOKUid:
                    {
                        WokSearchService_retrieveById *retrieveByIdRequest = [[[WokSearchService_retrieveById alloc] init] autorelease];
                        [retrieveByIdRequest setDatabaseId:database];
                        for (NSString *uid in uidsFromString(searchTerm))
                            [retrieveByIdRequest addUid:uid];
                        [retrieveByIdRequest setQueryLanguage:EN_QUERY_LANG];
                        [retrieveByIdRequest setRetrieveParameters:retrieveParameters];
                        response = [binding retrieveByIdUsingParameters:retrieveByIdRequest];
                        break;
                    }
                }
                
            }
            
            // this can be a WokSearchService_fullRecordSearchResults, WokSearchService_citedReferencesSearchResults, or WokSearchLiteService_searchResults
            id searchResults = nil;
            
            for (id bodyPart in [response bodyParts]) {
                if ([bodyPart respondsToSelector:@selector(faultstring)])
                    errorString = [[(WokServiceSoapBinding_fault *)bodyPart faultstring] stringByDeletingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                else if ([bodyPart respondsToSelector:@selector(return_)])
                    searchResults = [bodyPart return_];
            }
            
            if (searchResults) {
                
                NSMutableArray *pubs = [NSMutableArray array];
                for (id record in [searchResults WOKRecords]) {
                    NSDictionary *pubInfo = [record newWOKPublicationInfo];
                    [pubs addObject:pubInfo];
                    [pubInfo release];
                }
                
                // now increment this so we don't get the same set next time; BDSKSearchGroup resets it when the BDSKWOKSearch term changes
                fetchedResultsLocal += [pubs count];
                availableResultsLocal = [[searchResults recordsFound] integerValue];
                
                OSAtomicCompareAndSwap32Barrier(availableResults, availableResultsLocal, &availableResults);
                OSAtomicCompareAndSwap32Barrier(fetchedResults, fetchedResultsLocal, &fetchedResults);
                
                data = [NSKeyedArchiver archivedDataWithRootObject:pubs];
                
            } else {
                
                // we already know that a connection can be made, so we likely don't have permission to read this edition or database
                if (errorString && [errorString rangeOfString:@"Server.sessionExpired"].location != NSNotFound) {
                    // if the session has expired, the error message will include this server error code, so discard the cookie to allow authentication again
                    [sessionCookie release];
                    sessionCookie = nil;
                }
                [self setErrorMessage:errorString ?: [[response error] localizedDescription] ?: NSLocalizedString(@"Unable to retrieve results.  You may not have permission to use this database, or your query syntax may be incorrect.", @"Error message when connection to Web of Science fails.")];
            }
        }
        
        // if we got no data at this point the BDSKWOKSearch have failed somewhere
        if (data == nil)
            OSAtomicCompareAndSwap32Barrier(0, 1, &flags.failedDownload);
    }
    
    // set this flag before adding pubs, or the client will think we're still retrieving (and spinners don't stop)
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);
    
    // this will create the array if it doesn't exist
    [[self serverOnMainThread] addPublicationsToGroup:data];
    
}

- (BOOL)authenticateWithOptions:(NSDictionary *)options {
    // if sessionCookie was not nil we already authenticated
    if (sessionCookie == nil) {
        WOKMWSAuthenticateService *binding = [WOKMWSAuthenticateService soapBinding];
        //binding.logXMLInOut = YES;
        [binding setAuthUsername:[options objectForKey:@"username"]];
        [binding setAuthPassword:[options objectForKey:@"password"]];
        
        WOKMWSAuthenticateService_authenticate *request = [[[WOKMWSAuthenticateService_authenticate alloc] init] autorelease];
        
        WokServiceSoapBindingResponse *response = [binding authenticateUsingParameters:request];
        
        for (id bodyPart in [response bodyParts]) {
            
            if ([bodyPart respondsToSelector:@selector(faultstring)]) {
            
                NSString *errorString = [(WokServiceSoapBinding_fault *)bodyPart faultstring];
                [self setErrorMessage:[NSString stringWithFormat:NSLocalizedString(@"WOK Authentication Error: %@", "WOK Authentication Error Format"), errorString]];
                [sessionCookie release];
                sessionCookie = nil;
            } else if ([bodyPart respondsToSelector:@selector(return_)]) {
            
                // if we reach this point the only session cookie should be the SID
                [sessionCookie release];
                sessionCookie = [[[binding cookies] objectAtIndex:0] retain];
            }
        }
    }
    return sessionCookie != nil;
}

- (void)serverDidFinish {
    if (sessionCookie) {
        @try {
            WOKMWSAuthenticateService *binding = [WOKMWSAuthenticateService soapBinding];
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
    NSMutableArray *uids = [NSMutableArray array];
    NSScanner *scanner = [NSScanner scannerWithString:uidString];
    NSString *uid;
    [scanner scanUpToCharactersFromSet:uidCharSet intoString:NULL];
    while ([scanner isAtEnd] == NO) {
        if ([scanner scanCharactersFromSet:uidCharSet intoString:&uid])
            [uids addObject:uid];
        [scanner scanUpToCharactersFromSet:uidCharSet intoString:NULL];
    }
    
    return uids;
}

static NSString *dateFromSearchTerm(NSString *searchTerm, BOOL begin, NSRange *rangePtr) {
    NSString *operator = begin ? @"begin:" : @"end:";
    NSScanner *scanner = [NSScanner scannerWithString:searchTerm];
    [scanner setCharactersToBeSkipped:nil];
    [scanner scanUpToString:operator intoString:NULL];
    if ([scanner isAtEnd])
        return nil;
    
    NSUInteger i = [scanner scanLocation];
    if (i > 0 && [[NSCharacterSet letterCharacterSet] characterIsMember:[searchTerm characterAtIndex:i - 1]])
        return nil;
    
    NSInteger year = -1, month = 0, day = 0;
    NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
    NSString *s = nil;
    
    [scanner scanString:operator intoString:NULL];
    
    // the date format is Y-M-D, Y-M, or Y, components can be empty
    year = [scanner scanCharactersFromSet:digits intoString:&s] ? [s integerValue] : -1;
    if ([scanner scanString:@"-" intoString:NULL]) {
        month = [scanner scanCharactersFromSet:digits intoString:&s] ? [s integerValue] : -1;
        if ([scanner scanString:@"-" intoString:NULL])
            day = [scanner scanCharactersFromSet:digits intoString:&s] ? [s integerValue] : -1;
    }
    
    if (year == -1 || month == -1 || day == -1) {
        // year, month, and/or day was empty, implied by the current date
        NSDateComponents *today = [[[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease] components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit fromDate:[NSDate date]];
        if (year == -1)
            year = [today year];
        if (month == -1)
            month = [today month];
        if (day == -1)
            day = [today day];
    }
    // allow subcentury years
    if (year < 100)
        year += 2000;
    // complete dates using first (for begin:) or last (for end:) month or day
    if (month == 0)
        month = begin ? 1 : 12;
    if (day == 0)
        day = begin ? 1 : ((((month - 1) % 7) % 2) == 0) ? 31 : (month != 2) ? 30 : ((year % 4) == 0 && ((year % 100) != 0 || (year % 400) == 0)) ? 29 : 28;
    
    if (rangePtr)
        *rangePtr = NSMakeRange(i, [scanner scanLocation] - i);
    
    return [NSString stringWithFormat:@"%.4ld-%.2ld-%.2ld", (long)year, (long)month, (long)day];
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
    // There are at least 3 variants of this, so it's not always possible to get something truly useful from it.
    // "AUG", "JUN 19", "MAR-APR"	
    NSUInteger idx = [value rangeOfCharacterFromSet:nonMonthCharSet].location;
    NSString *field = BDSKDateString;
    if (value && idx > 0) {
        if (idx != NSNotFound)
            value = [value substringToIndex:idx];
        if ([value rangeOfString:@"-"].location == NSNotFound)
            value = [[BDSKMacroResolver defaultMacroResolver] valueOfMacro:value] ?: [value capitalizedString];
        else
            value = [value capitalizedString];
        field = BDSKMonthString;
    }
    addStringToDictionaryIfNotNil(value, field, pubFields);
}

static void addAuthorNamesToDictionary(NSArray *names, NSMutableDictionary *pubFields)
{
    NSMutableString *namesString = nil;
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
            if (range.length > 0 && [name rangeOfCharacterFromSet:nonUpperCharSet options:0 range:range].location == NSNotFound) {
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

@implementation NSObject (BDSKWOKSearchResults)

- (NSArray *)WOKRecords { return nil; }

@end

@implementation WokSearchService_fullRecordSearchResults (BDSKWOKSearchResults)

- (NSArray *)WOKRecords {
    NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithXMLString:[self records] options:0 error:NULL] autorelease];
    return [doc nodesForXPath:@"/records/REC" error:NULL];
}

@end

@implementation WokSearchService_citedReferencesSearchResults (BDSKWOKSearchResults)

- (NSArray *)WOKRecords { return [self references]; }

@end

@implementation WokSearchLiteService_searchResults (BDSKWOKSearchResults)

- (NSArray *)WOKRecords { return [self records]; }

@end

@implementation NSObject (BDSKWOKRecord)

- (NSDictionary *)newWOKPublicationInfo {
    return [[NSDictionary alloc] initWithObjectsAndKeys:BDSKArticleString, BDSKPubTypeString, nil];
}

@end

@implementation NSXMLNode (BDSKWOKRecord)

- (NSDictionary *)newWOKPublicationInfo {
    // this is now a field/value set for a particular publication self
    NSMutableDictionary *pubFields = [NSMutableDictionary new];
   
    // default value for publication type
    NSString *isiPubType = nil;
	NSString *source = nil;
    NSString *source_abbrev = nil;

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
		} else if ([typeString isEqualToString:@"abbrev_iso"]) {
            addStringToDictionaryIfNotNil([child stringValue], BDSKJournalString, pubFields);
        } else if ([typeString isEqualToString:@"source"]) {
            source = useTitlecase ? [[child stringValue] titlecaseString] : [child stringValue];
		} else if ([typeString isEqualToString:@"source_abbrev"]) {
            source_abbrev = [child stringValue];
        }
    }
    if ([pubFields objectForKey:BDSKJournalString] == nil) {
        if (source_abbrev)
            addStringToDictionaryIfNotNil(source_abbrev, BDSKJournalString, pubFields);
        else if (source)
            addStringToDictionaryIfNotNil(source, BDSKJournalString, pubFields);
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
            addStringToDictionaryIfNotNil(source, BDSKBooktitleString, pubFields);
		} else if ([isiPubType isEqualToString:@"Journal"]) {
            pubType = BDSKArticleString;
        } else {
            // preserve the type if it's unclear
            pubType = [[docType stringByReplacingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] withString:@"-"] entryType];
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
    NSString *keywordSeparator = [[NSUserDefaults standardUserDefaults] stringForKey:BDSKDefaultGroupFieldSeparatorKey];
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
	
    if (addXMLStringToAnnote)
        [pubFields setValue:[self XMLString] forKey:BDSKAnnoteString];
    
    return pubFields;
}

@end

@implementation WokSearchService_citedReference (BDSKWOKRecord)

- (NSDictionary *)newWOKPublicationInfo {
    NSMutableDictionary *pubFields = [NSMutableDictionary new];
    
    [pubFields setObject:BDSKArticleString forKey:BDSKPubTypeString];
    
    addStringToDictionaryIfNotNil([self uid], WOK_UID_FIELDNAME, pubFields);
    
    addAuthorNamesToDictionary([NSArray arrayWithObjects:[self citedAuthor], nil], pubFields);
    
    addStringToDictionaryIfNotNil((useTitlecase ? [[self citedWork] titlecaseString] : [self citedWork]), BDSKJournalString, pubFields);

    addStringToDictionaryIfNotNil([self citedTitle], BDSKTitleString, pubFields);
    addStringToDictionaryIfNotNil([self page], BDSKPagesString, pubFields);
    addStringToDictionaryIfNotNil([self timesCited], @"Times-Cited", pubFields);
    addStringToDictionaryIfNotNil([self volume], BDSKVolumeString, pubFields);
    addStringToDictionaryIfNotNil([self year], BDSKYearString, pubFields);
    
    return pubFields;
}

@end

@implementation WokSearchLiteService_liteRecord (BDSKWOKRecord)

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

    NSString *keywordSeparator = [[NSUserDefaults standardUserDefaults] stringForKey:BDSKDefaultGroupFieldSeparatorKey];
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

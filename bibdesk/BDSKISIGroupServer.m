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
#import "BDSKLinkedFile.h"
#import "BDSKServerInfo.h"
#import "BibItem.h"
#import "NSArray_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"

#define SERVER_URL @"http://wok-ws.isiknowledge.com/esti/soap/SearchRetrieve"

#define WOS_DB_ID @"WOS"

#define RECORDSFOUND_KEY @"recordsFound"
#define RECORDS_KEY @"records"

#define BDSKAddISIXMLStringToAnnoteKey @"BDSKAddISIXMLStringToAnnote"
#define BDSKDisableISITitleCasingKey @"BDSKDisableISITitleCasing"
#define BDSKISISourceXMLTagPriorityKey @"BDSKISISourceXMLTagPriority"
#define BDSKISIURLFieldNameKey @"BDSKISIURLFieldName"

#define DefaultISIURLFieldName @"ISI URL"

#define MAX_RESULTS 100
#ifdef DEBUG
static BOOL addXMLStringToAnnote = YES;
#else
static BOOL addXMLStringToAnnote = NO;
#endif

static BOOL useTitlecase = YES;
static NSArray *sourceXMLTagPriority = nil;
static NSString *ISIURLFieldName = nil;

static NSArray *publicationInfosWithISIXMLString(NSString *xmlString);
static NSArray *publicationInfosWithISICitedReferences(NSArray *citedReferences);
//static NSArray *replacePubInfosByField(NSArray *targetPubs, NSArray *sourcePubs, NSString *fieldName);
static NSArray *publicationsFromData(NSData *data);

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

+ (BOOL)canConnect;
{
    CFURLRef theURL = (CFURLRef)[NSURL URLWithString:SERVER_URL];
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
    ISIURLFieldName = [([[NSUserDefaults standardUserDefaults] stringForKey:BDSKISIURLFieldNameKey] ?: DefaultISIURLFieldName) retain];
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
    if ([[self class] canConnect]) {
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
    [NSString setMacroResolverForUnarchiving:[group macroResolver]];
    NSArray *pubs = publicationsFromData(data);
    [NSString setMacroResolverForUnarchiving:nil];
    [group addPublications:pubs];
}

#pragma mark Server thread
// @@ currently limited to topic search; need to figure out UI for other search types (mixing search types will require either NSTokenField or raw text string entry)
- (oneway void)downloadWithSearchTerm:(NSString *)searchTerm database:(NSString *)database options:(NSDictionary *)options;
{    
    NSArray *pubs = nil;
    enum operationTypes { search, citedReferences, citingArticles, relatedRecords, retrieveById } operation = search;
    NSInteger availableResultsLocal = [self numberOfAvailableResults];
    NSInteger fetchedResultsLocal = [self numberOfFetchedResults];
    NSInteger numResults = MAX_RESULTS;
    
    if (availableResultsLocal > 0)
        numResults = MIN(availableResultsLocal - fetchedResultsLocal, MAX_RESULTS);
    
    // Strip whitespace from the search term to make WOS happy
    searchTerm = [searchTerm stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
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
        } else if ([searchTerm rangeOfString:@"="].location == NSNotFound)
            searchTerm = [NSString stringWithFormat:@"TS=\"%@\"", searchTerm];
        
        // authenticate if necessary
        if (!sessionCookie) {
            [self authenticateWithOptions:options];
            if (!sessionCookie) {
                OSAtomicCompareAndSwap32Barrier(0, 1, &flags.failedDownload);
                OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);
                [[self serverOnMainThread] addPublicationsToGroup:nil];
                return;
            }
        }
        
        // perform WS query to get count of results; don't pass zero for record numbers, although it's not clear what the values mean in this context
        NSString *errorString = nil;
		
        WokSearchService_editionDesc *edition = [[[WokSearchService_editionDesc alloc] init] autorelease];
        edition.collection = WOS_DB_ID;
        edition.edition = database;
        
		// Reto: WOK returns a wrong number of found records if count is set to 1, so set it to 100 by default
        WokSearchService_retrieveParameters *retrieveParameters = [[[WokSearchService_retrieveParameters alloc] init] autorelease];
        retrieveParameters.firstRecord = [NSNumber numberWithInt:fetchedResultsLocal + 1];
        retrieveParameters.count = [NSNumber numberWithInt:numResults];
        
        WokSearchService_timeSpan *timeSpan = [[[WokSearchService_timeSpan alloc] init] autorelease];
        timeSpan.begin = @"1600-01-01";
        timeSpan.end = [NSDate date]; // Reto: Obj-C dummy Question: how do I convert NSDate to a String of YYYY-MM-DD ???
        
        WokSearchService_search *searchRequest = nil;
        WokSearchService_searchResponse *searchResponse = nil;
        
        WokSearchService_citedReferences *citedReferencesRequest = nil;
        WokSearchService_citedReferencesResponse *citedReferencesResponse = nil;
        
        WokSearchService_citingArticles *citingArticlesRequest = nil;
        WokSearchService_citingArticlesResponse *citingArticlesResponse = nil;
        
        WokSearchService_relatedRecords *relatedRecordsRequest = nil;
        WokSearchService_relatedRecordsResponse *relatedRecordsResponse = nil;
        
        WokSearchService_retrieveById *retrieveByIdRequest = nil;
        WokSearchService_retrieveByIdResponse *retrieveByIdResponse = nil;
        
        WokSearchServiceSoapBindingResponse *response = nil;
        NSArray *responseBodyParts;
        WokSearchService_fullRecordSearchResults *fullRecordSearchResults = nil;
        WokSearchService_citedReferencesSearchResults *citedReferencesSearchResults = nil;
        
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
        NSScanner *scanner;
        NSString *token;
        switch (operation) {
            case search:
				// Reto: this works for the Premium edition of WOKSearch (and not for WOKSearchLite)
                searchRequest = [[[WokSearchService_search alloc] init] autorelease];
                searchRequest.queryParameters = [[[WokSearchService_queryParameters alloc] init] autorelease];
                searchRequest.queryParameters.databaseID = WOS_DB_ID;
				//                [searchRequest.queryParameters addEditions:edition];
                searchRequest.queryParameters.userQuery = searchTerm;
                searchRequest.queryParameters.queryLanguage = @"en";
                searchRequest.retrieveParameters = retrieveParameters;
                response = [binding searchUsingParameters:searchRequest];
                responseBodyParts = response.bodyParts;
                for (id bodyPart in responseBodyParts) {
                    if ([bodyPart isKindOfClass:[SOAPFault class]]) {
                        errorString = ((SOAPFault *)bodyPart).simpleFaultString;
                    } else if ([bodyPart isKindOfClass:[WokSearchService_searchResponse class]]) {
                        searchResponse = bodyPart;
                        fullRecordSearchResults = searchResponse.return_;
                        availableResultsLocal = fullRecordSearchResults.recordsFound.integerValue;
                    }
                }
                break;
            case citedReferences:
				// Reto: undocumented and untested. I'm going to check its usefulness before removing.
                citedReferencesRequest = [[[WokSearchService_citedReferences alloc] init] autorelease];
                citedReferencesRequest.databaseId = WOS_DB_ID;
                citedReferencesRequest.uid = searchTerm;
				//                [citedReferencesRequest addEditions:edition];
				//                citedReferencesRequest.timeSpan = timeSpan;
                citedReferencesRequest.queryLanguage = @"en";
                citedReferencesRequest.retrieveParameters = retrieveParameters;
                response = [binding citedReferencesUsingParameters:citedReferencesRequest];
                responseBodyParts = response.bodyParts;
                for (id bodyPart in responseBodyParts) {
                    if ([bodyPart isKindOfClass:[SOAPFault class]]) {
                        errorString = ((SOAPFault *)bodyPart).simpleFaultString;
                    } else if ([bodyPart isKindOfClass:[WokSearchService_citedReferencesResponse class]]) {
                        citedReferencesResponse = bodyPart;
                        citedReferencesSearchResults = citedReferencesResponse.return_;
                        availableResultsLocal = citedReferencesSearchResults.recordsFound.integerValue;
                        citedReferencesSearchResults = citedReferencesResponse.return_;
                    }
                }
                break;
            case citingArticles:
				// Reto: undocumented and untested. I'm going to check its usefulness before removing.            
                citingArticlesRequest = [[[WokSearchService_citingArticles alloc] init] autorelease];
                citingArticlesRequest.databaseId = WOS_DB_ID;
                citingArticlesRequest.uid = searchTerm;
				//                [citingArticlesRequest addEditions:edition];
				//                citingArticlesRequest.timeSpan = timeSpan;
                citingArticlesRequest.queryLanguage = @"en";
                citingArticlesRequest.retrieveParameters = retrieveParameters;
                response = [binding citingArticlesUsingParameters:citingArticlesRequest];
                responseBodyParts = response.bodyParts;
                for (id bodyPart in responseBodyParts) {
                    if ([bodyPart isKindOfClass:[SOAPFault class]]) {
                        errorString = ((SOAPFault *)bodyPart).simpleFaultString;
                    } else if ([bodyPart isKindOfClass:[WokSearchService_citingArticlesResponse class]]) {
                        citingArticlesResponse = bodyPart;
                        fullRecordSearchResults = citingArticlesResponse.return_;
                        availableResultsLocal = fullRecordSearchResults.recordsFound.integerValue;
                    }
                }
                break;
            case relatedRecords:
				// Reto: undocumented and untested. I'm going to check its usefulness before removing.
                relatedRecordsRequest = [[[WokSearchService_relatedRecords alloc] init] autorelease];
                relatedRecordsRequest.databaseId = WOS_DB_ID;
                relatedRecordsRequest.uid = searchTerm;
				//                [relatedRecordsRequest addEditions:edition];
				//                relatedRecordsRequest.timeSpan = timeSpan;
                relatedRecordsRequest.queryLanguage = @"en";
                relatedRecordsRequest.retrieveParameters = retrieveParameters;
                response = [binding relatedRecordsUsingParameters:relatedRecordsRequest];
                responseBodyParts = response.bodyParts;
                for (id bodyPart in responseBodyParts) {
                    if ([bodyPart isKindOfClass:[SOAPFault class]]) {
                        errorString = ((SOAPFault *)bodyPart).simpleFaultString;
                    } else if ([bodyPart isKindOfClass:[WokSearchService_relatedRecordsResponse class]]) {
                        relatedRecordsResponse = bodyPart;
                        fullRecordSearchResults = relatedRecordsResponse.return_;
                        availableResultsLocal = fullRecordSearchResults.recordsFound.integerValue;
                    }
                }
                break;
				
            case retrieveById:
				// Reto: undocumented and untested. I'm going to check its usefulness before removing.
                retrieveByIdRequest = [[[WokSearchService_retrieveById alloc] init] autorelease];
                retrieveByIdRequest.databaseId = WOS_DB_ID;
                scanner = [[[NSScanner alloc] initWithString:searchTerm] autorelease];
                [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:NULL];
                while ([scanner scanUpToCharactersFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet] intoString:&token]) {
                    [retrieveByIdRequest addUids:token];
                    [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:NULL];
                }
                retrieveByIdRequest.queryLanguage = @"en";
                retrieveByIdRequest.retrieveParameters = retrieveParameters;
                response = [binding retrieveByIdUsingParameters:retrieveByIdRequest];
                responseBodyParts = response.bodyParts;
                for (id bodyPart in responseBodyParts) {
                    if ([bodyPart isKindOfClass:[SOAPFault class]]) {
                        errorString = ((SOAPFault *)bodyPart).simpleFaultString;
                    } else if ([bodyPart isKindOfClass:[WokSearchService_retrieveByIdResponse class]]) {
                        retrieveByIdResponse = bodyPart;
                        fullRecordSearchResults = retrieveByIdResponse.return_;
                        availableResultsLocal = fullRecordSearchResults.recordsFound.integerValue;
                    }
                }
                break;
        }
        
        if (citedReferencesSearchResults) {
            pubs = publicationInfosWithISICitedReferences(citedReferencesSearchResults.records);
        } else if (fullRecordSearchResults) {
            pubs = publicationInfosWithISIXMLString(fullRecordSearchResults.records);
        } else {
            OSAtomicCompareAndSwap32Barrier(0, 1, &flags.failedDownload);
            // we already know that a connection can be made, so we likely don't have permission to read this edition or database
            if (errorString) {
                [self setErrorMessage:errorString];
            } else {
                [self setErrorMessage:NSLocalizedString(@"Unable to retrieve results.  You may not have permission to use this database, or your query syntax may be incorrect.", @"Error message when connection to Web of Science fails.")];
            }
        }
        
        // now increment this so we don't get the same set next time; BDSKSearchGroup resets it when the searcn term changes
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
    binding.logXMLInOut = YES;
    binding.authUsername = [options objectForKey:@"username"];
    binding.authPassword = [options objectForKey:@"password"];
    
    WOKMWSAuthenticateService_authenticate *request = [[[WOKMWSAuthenticateService_authenticate alloc] init] autorelease];
    
    WOKMWSAuthenticateServiceSoapBindingResponse *response = [binding authenticateUsingParameters:request];
    
    NSArray *responseBodyParts = response.bodyParts;
    
    for (id bodyPart in responseBodyParts) {
        
        if ([bodyPart isKindOfClass:[SOAPFault class]]) {
        
            NSString *errorString = ((SOAPFault *)bodyPart).simpleFaultString;
            [self setErrorMessage:[NSString stringWithFormat:NSLocalizedString(@"ISI Authentication Error: %@", "ISI Authentication Error Format"), errorString]];
            [sessionCookie release];
            sessionCookie = nil;
        }
        
        if ([bodyPart isKindOfClass:[WOKMWSAuthenticateService_authenticateResponse class]]) {
        
            // if we reach this point the only session cookie should be the SID
            [sessionCookie release];
            sessionCookie = [[binding.cookies objectAtIndex:0] retain];
        }
    }
}

#pragma mark XML Parsing

// convenience to avoid creating a local variable and checking it each time
static inline void addStringToDictionaryIfNotNil(NSString *value, NSString *key, NSMutableDictionary *dict)
{
    if (value) [dict setObject:[value stringByBackslashEscapingTeXSpecials] forKey:key];
}

// convenience to add the string value of a node; only adds if non-nil
static inline void addStringValueOfNodeForField(NSXMLNode *child, NSString *field, NSMutableDictionary *pubFields)
{
    addStringToDictionaryIfNotNil([child stringValue], field, pubFields);
}

// this returns nil if the XPath query fails, and addAuthorsFromXMLNode() relies on that behavior
static NSString *nodeStringsForXPathJoinedByString(NSXMLNode *child, NSString *XPath, NSString *join)
{
    NSArray *nodes = [child nodesForXPath:XPath error:NULL];
    NSString *toReturn = nil;
    if ([nodes count]) {
        nodes = [nodes valueForKey:@"stringValue"];
        toReturn = [nodes componentsJoinedByString:join];
    }
    return toReturn;
}

static NSDictionary *createPublicationInfoWithRecord(NSXMLNode *record)
{
    // this is now a field/value set for a particular publication record
    NSXMLNode *child = [record childCount] ? [record childAtIndex:0] : nil;
    NSMutableDictionary *pubFields = [NSMutableDictionary new];
    NSString *keywordSeparator = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKDefaultGroupFieldSeparatorKey];
    NSMutableDictionary *sourceTagValues = [NSMutableDictionary dictionary];
   
    // default value for publication type
    NSString *pubType = nil;
    NSString *ISIpubType = nil;
	NSString *journalName = nil;

	/* get some major branches of XML nodes which are used several times */
	NSXMLNode *summaryChild = [[record nodesForXPath:@"./static_data/summary" error:NULL] lastObject];
	
	/* get WOS ID */
	NSString *wosID = [[[[record nodesForXPath:@"./UID" error:NULL] lastObject] stringValue] stringByRemovingPrefix:@"WOS:"];
	if (wosID != nil) {
		[pubFields setObject:wosID forKey:@"Isi"];
		NSString *isiURL = [@"http://ws.isiknowledge.com/cps/openurl/service?url_ver=Z39.88-2004&rft_id=info:ut/" stringByAppendingString:wosID];
		[pubFields setObject:isiURL forKey:ISIURLFieldName];
	}
		
	/* get authors */
	NSString *authorString = nodeStringsForXPathJoinedByString(summaryChild, @"./names/name/full_name", @" and ");
	addStringToDictionaryIfNotNil(authorString,BDSKAuthorString,pubFields);
	
	/* get title, journal name etc */
	NSArray *titleChilds = [summaryChild nodesForXPath:@"./titles/title" error:NULL];
    for (child in titleChilds) {		
        if ([[[(NSXMLElement *)child attributeForName:@"type"] stringValue] isEqualToString:@"item"])
            addStringValueOfNodeForField(child, BDSKTitleString, pubFields);
        else if ([[[(NSXMLElement *)child attributeForName:@"type"] stringValue] isEqualToString:@"source"]) {
			journalName = (useTitlecase ? [[child stringValue] titlecaseString] : [child stringValue]);
            addStringToDictionaryIfNotNil(journalName, BDSKJournalString, pubFields);
		}
        else if ([[[(NSXMLElement *)child attributeForName:@"type"] stringValue] isEqualToString:@"source_abbrev"])
            addStringToDictionaryIfNotNil((useTitlecase ? [[child stringValue] titlecaseString] : [child stringValue]), @"Iso-Source-Abbreviation", pubFields);
    }
	
	/* get page numbers */
	child = [[summaryChild nodesForXPath:@"./pub_info/page" error:NULL] lastObject];
	if (child != nil) {
		NSString *begin = [[(NSXMLElement *)child attributeForName:@"begin"] stringValue];
		NSString *end = [[(NSXMLElement *)child attributeForName:@"end"] stringValue];
		if (NO == [NSString isEmptyString:begin] && NO == [NSString isEmptyString:end])
			addStringToDictionaryIfNotNil([NSString stringWithFormat:@"%@--%@", begin, end], BDSKPagesString, pubFields);
		else if (NO == [NSString isEmptyString:begin])
			addStringToDictionaryIfNotNil(begin, BDSKPagesString, pubFields);
//		else if (NO == [[child stringValue] isEqualToString:@"-"])
//			addStringValueOfNodeForField(child, BDSKPagesString, pubFields);			
	}
	
	/* get publication year, volume, issue and month */
	child = [[summaryChild nodesForXPath:@"./pub_info" error:NULL] lastObject];
	if (child != nil) {
		addStringValueOfNodeForField([(NSXMLElement *)child attributeForName:@"pubyear"], BDSKYearString, pubFields);
		addStringValueOfNodeForField([(NSXMLElement *)child attributeForName:@"vol"], BDSKVolumeString, pubFields);
		addStringValueOfNodeForField([(NSXMLElement *)child attributeForName:@"issue"], BDSKNumberString, pubFields);
		
		ISIpubType = [[(NSXMLElement *)child attributeForName:@"pubtype"] stringValue];
//		NSLog(@"ISIpubType:\n%@", ISIpubType);

		//             There are at least 3 variants of this, so it's not always possible to get something
		//             truly useful from it.
		
		//             <bib_date date="AUG" year="2008">AUG 2008</bib_date>
		//             <bib_date date="JUN 19" year="2008">JUN 19 2008</bib_date>
		//             <bib_date date="MAR-APR" year="2007">MAR-APR 2007</bib_date>		
		NSString *possibleMonthString = [[(NSXMLElement *)child attributeForName:@"pubmonth"] stringValue];
		NSString *monthString;
		NSScanner *scanner = nil;
		if (possibleMonthString)
			scanner = [[NSScanner alloc] initWithString:possibleMonthString];
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
			addStringToDictionaryIfNotNil(possibleMonthString, BDSKDateString, pubFields);
		}
		[scanner release];
	}	

	
	/* get the document / publication type */
	/* needs some more testing for conferences etc. maybe we also need to get the conference name? */
	child = [[summaryChild nodesForXPath:@"./doctypes/doctype" error:NULL] lastObject]; 	
    if (child != nil) {		
		NSString *docType = [child stringValue];			
//		NSLog(@"docType:\n%@", docType);
		/*
		I've seen "Meeting Abstract" and "Article" as common types.  However, "Geomorphology" and 
		"Estuarine Coastal and Shelf Science" articles are sometimes listed as "Proceedings Paper"
		which is clearly wrong.  Likewise, any journal with "Review" in the name is listed as a 
		"Review" type, when it should probably be a journal (e.g., "Earth Science Reviews").
		*/
		if ([docType isEqualToString:@"Meeting Abstract"]) {
			pubType = BDSKInproceedingsString;
		} else if ([docType isEqualToString:@"Review"]) {
			pubType = BDSKArticleString;
		} else if ([docType isEqualToString:@"Book Review"]) {
			pubType = BDSKArticleString;
		} else if ([docType isEqualToString:@"Journal Paper"]) {
			pubType = BDSKArticleString;
		} else if ([docType isEqualToString:@"Proceedings Paper"]) {
			pubType = BDSKInproceedingsString;
			[pubFields setObject:journalName forKey:BDSKBooktitleString];
		} else {
			if ([ISIpubType isEqualToString:@"Journal"]) {
				pubType = BDSKArticleString;
			} else {
				// preserve the type if it's unclear
				pubType = docType;
			}
		}
			
	}
    
	[pubFields setObject:pubType forKey:BDSKPubTypeString];

	/* get publisher name and address */
	addStringValueOfNodeForField([[summaryChild nodesForXPath:@"./publishers/publisher/names/name/full_name" error:NULL] lastObject], 
								 BDSKPublisherString, pubFields);
	addStringValueOfNodeForField([[summaryChild nodesForXPath:@"./publishers/publisher/address_spec/full_address" error:NULL] lastObject],
								 BDSKAddressString, pubFields);

	/* get abstract */
	NSString *abstractString = nodeStringsForXPathJoinedByString(record, @"./static_data/fullrecord_metadata/abstracts/abstract/abstract_text/p", @"\n\n");
	addStringToDictionaryIfNotNil(abstractString,BDSKAbstractString,pubFields);

	/* get keywords */
	NSString *keywordString = nodeStringsForXPathJoinedByString(record, @"./static_data/item/keywords_plus/keyword", keywordSeparator);
	addStringToDictionaryIfNotNil(keywordString,BDSKKeywordsString,pubFields);						
	
	/* get identifiers (DOI, ISSN, ISBN) */
	NSArray *identifierChilds = [record nodesForXPath:@"./dynamic_data/cluster_related/identifiers/identifier" error:NULL];
	for (child in identifierChilds) {
		NSString *typeString = [[(NSXMLElement *)child attributeForName:@"type"] stringValue];
		if ([typeString isEqualToString:@"doi"]) {
			addStringToDictionaryIfNotNil([[(NSXMLElement *)child attributeForName:@"value"] stringValue],BDSKDoiString,pubFields);
		}
		if ([typeString isEqualToString:@"art_no"]) {
			if ([pubFields objectForKey:BDSKNumberString] == nil) {
				NSString *artnum = [[(NSXMLElement *)child attributeForName:@"value"] stringValue];
				addStringToDictionaryIfNotNil([artnum stringByRemovingPrefix:@"ARTN "], BDSKNumberString, pubFields);
			}
		}
		if ([typeString isEqualToString:@"issn"]) {
			NSString *issn = [[(NSXMLElement *)child attributeForName:@"value"] stringValue];
			addStringToDictionaryIfNotNil(issn, @"Issn", pubFields);
		}
		if ([typeString isEqualToString:@"isbn"]) {
			NSString *isbn = [[(NSXMLElement *)child attributeForName:@"value"] stringValue];
			addStringToDictionaryIfNotNil(isbn, @"Isbn", pubFields);
		}
	}
	
	/* get times-cited */
	addStringToDictionaryIfNotNil([[[[record nodesForXPath:@"./dynamic_data/citation_related/tc_list/silo_tc" error:NULL] lastObject] 
								   attributeForName:@"local_count"] stringValue], @"Times-Cited", pubFields);
	
    return pubFields;
}

static NSArray *publicationInfosWithISIXMLString(NSString *xmlString)
{
    NSCParameterAssert(nil != xmlString);
    NSError *error;
    NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithXMLString:xmlString options:0 error:&error] autorelease];
    if (nil == doc) {
        NSLog(@"failed to create XML document from ISI string.  %@", error);
        return nil;
    }
    
    NSArray *records = [doc nodesForXPath:@"/records/REC" error:&error];
    if (nil == records)
        NSLog(@"%@", error);
    
    NSXMLNode *record = [records firstObject];
    NSMutableArray *pubs = [NSMutableArray array];
    
    while (nil != record) {
        
        NSDictionary *pub = createPublicationInfoWithRecord(record);
        [pubs addObject:pub];
        [pub release];
        
        record = [record nextSibling];
    }
    return pubs;
}

static NSDictionary *createPublicationInfoWithCitedReference(WokSearchService_citedReference *citedReference) {

    NSMutableDictionary *pubFields = [NSMutableDictionary new];
    
    [pubFields setObject:BDSKArticleString forKey:BDSKPubTypeString];
    
    NSArray *authorTokens = [citedReference.citedAuthor componentsSeparatedByString:@" "];
    if ([authorTokens count] == 2) {
        NSString *lastName = [authorTokens objectAtIndex:0];
        NSString *firstInitials = [authorTokens objectAtIndex:1];
        NSString *authorName = [[lastName capitalizedString] stringByAppendingFormat:@", %@", firstInitials];
        addStringToDictionaryIfNotNil(authorName, BDSKAuthorString, pubFields);
    }
    
    addStringToDictionaryIfNotNil((useTitlecase ? [citedReference.citedWork titlecaseString] : citedReference.citedWork), BDSKJournalString, pubFields);

    addStringToDictionaryIfNotNil(citedReference.page, BDSKPagesString, pubFields);
    addStringToDictionaryIfNotNil(citedReference.recID, @"Isi-Recid", pubFields);
    addStringToDictionaryIfNotNil(citedReference.timesCited, @"Times-Cited", pubFields);
    addStringToDictionaryIfNotNil(citedReference.volume, BDSKVolumeString, pubFields);
    addStringToDictionaryIfNotNil(citedReference.year, BDSKYearString, pubFields);
    
    return pubFields;
}

static NSArray *publicationInfosWithISICitedReferences(NSArray *citedReferences) {

    NSMutableArray *pubs = [NSMutableArray array];
    
    for (WokSearchService_citedReference *citedReference in citedReferences) {
    
        NSDictionary *pub = createPublicationInfoWithCitedReference(citedReference);
        [pubs addObject:pub];
        [pub release];
    }
    
    return pubs;
}
/*
static NSArray *replacePubInfosByField(NSArray *targetPubs, NSArray *sourcePubs, NSString *fieldName)
{
    NSMutableArray *outPubs = [NSMutableArray arrayWithCapacity:[targetPubs count]];
    NSMutableDictionary *sourcePubIndex = [NSMutableDictionary dictionaryWithCapacity:[sourcePubs count]];
    NSDictionary *pub;
    NSString *value;
    NSDictionary *replacedPub;
    
    for (pub in sourcePubs) {
        if ((value = [pub objectForKey:fieldName]))
            [sourcePubIndex setValue:pub forKey:value];
    }
    
    for (pub in targetPubs) {
        if ((value = [pub objectForKey:fieldName]) &&
            (replacedPub = [sourcePubIndex objectForKey:value]))
            pub = replacedPub;
        [outPubs addObject:pub]; 
    }
    
    return outPubs;
}
*/
static NSArray *publicationsFromData(NSData *data) {
    if (!data) return [NSArray array];
    NSArray *pubInfos = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSMutableArray *pubs = [NSMutableArray arrayWithCapacity:[pubInfos count]];
    for (NSDictionary *pubInfo in pubInfos) {
        NSMutableDictionary *pubFields = [pubInfo mutableCopy];
        NSArray *files = nil;
        
        NSString *pubType = [pubFields objectForKey:BDSKPubTypeString];
        [pubFields removeObjectForKey:BDSKPubTypeString];
        
        // insert the ISI URL into the normal file array if hasn't been put elsewhere
        NSString *isiURL = [pubFields objectForKey:DefaultISIURLFieldName];
        if (isiURL) {
            files = [[NSMutableArray alloc] initWithObjects:[BDSKLinkedFile linkedFileWithURL:[NSURL URLWithStringByNormalizingPercentEscapes:isiURL] delegate:nil], nil];
            [pubFields removeObjectForKey:DefaultISIURLFieldName];
        }
        
        BibItem *pub = [[BibItem alloc] initWithType:pubType citeKey:nil pubFields:pubFields files:files isNew:YES];
        
        [pubs addObject:pub];
        [pub release];
        [pubFields release];
        [files release];
    }
    return pubs;
}

@end

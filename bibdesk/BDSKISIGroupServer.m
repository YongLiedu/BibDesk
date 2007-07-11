//
//  BDSKISIGroupServer.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/10/07.
/*
 This software is Copyright (c) ,2007
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
#import "BDSKISIWebServices.h"
#import "BDSKServerInfo.h"
#import "BibItem.h"
#import "NSArray_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"

#define MAX_RESULTS 100

// private protocols for inter-thread messaging
@protocol BDSKISIGroupServerMainThread <BDSKAsyncDOServerMainThread>
- (void)addPublicationsToGroup:(bycopy NSArray *)pubs;
@end

@protocol BDSKISIGroupServerLocalThread <BDSKAsyncDOServerThread>
- (int)availableResults;
- (void)setAvailableResults:(int)value;
- (int)fetchedResults;
- (void)setFetchedResults:(int)value;
- (oneway void)downloadWithSearchTerm:(NSString *)searchTerm;
@end

@implementation BDSKISIGroupServer

+ (BOOL)canConnect;
{
    CFURLRef theURL = (CFURLRef)[NSURL URLWithString:@"http://wok-ws.isiknowledge.com/esti/soap/SearchRetrieve"];
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

- (Protocol *)protocolForMainThread { return @protocol(BDSKISIGroupServerMainThread); }
- (Protocol *)protocolForServerThread { return @protocol(BDSKISIGroupServerLocalThread); }

- (id)initWithGroup:(BDSKSearchGroup *)aGroup serverInfo:(BDSKServerInfo *)info;
{
    self = [super init];
    if (self) {
        group = aGroup;
        serverInfo = [info copy];
        flags.failedDownload = 0;
        flags.isRetrieving = 0;
        flags.needsReset = 1;
        availableResults = 0;
        fetchedResults = 0;
        pthread_rwlock_init(&infolock, NULL);
    }
    return self;
}

#pragma mark BDSKSearchGroupServer protocol

// these are called on the main thread

- (void)terminate
{
    [self stopDOServer];
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.isRetrieving);
}

- (void)stop
{
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.isRetrieving);
}

- (void)retrievePublications
{
    if ([[self class] canConnect]) {
        OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.failedDownload);
    
        OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.isRetrieving);
        id server = [self serverOnServerThread];
        if (server)
            [server downloadWithSearchTerm:[group searchTerm]];
        else
            [self performSelector:_cmd withObject:nil afterDelay:0.1];
    } else {
        OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.failedDownload);
        NSError *presentableError = [NSError mutableLocalErrorWithCode:kBDSKNetworkConnectionFailed localizedDescription:NSLocalizedString(@"Unable to connect to server", @"")];
        [NSApp presentError:presentableError];
    }
}

- (void)setServerInfo:(BDSKServerInfo *)info;
{
    pthread_rwlock_wrlock(&infolock);
    if (serverInfo != info) {
        [serverInfo release];
        serverInfo = [info copy];
    }
    pthread_rwlock_unlock(&infolock);
    OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.needsReset);
}

- (BDSKServerInfo *)serverInfo;
{
    pthread_rwlock_rdlock(&infolock);
    BDSKServerInfo *info = [[serverInfo copy] autorelease];
    pthread_rwlock_unlock(&infolock);
    return info;
}

- (void)setNumberOfAvailableResults:(int)value;
{
    [[self serverOnServerThread] setAvailableResults:value];
}

- (int)numberOfAvailableResults;
{
    return [[self serverOnServerThread] availableResults];
}

- (void)setNumberOfFetchedResults:(int)value;
{
    [[self serverOnServerThread] setFetchedResults:value];
}

- (int)numberOfFetchedResults;
{
    return [[self serverOnServerThread] fetchedResults];
}

- (BOOL)failedDownload { return 1 == flags.failedDownload; }

- (BOOL)isRetrieving { return 1 == flags.isRetrieving; }
- (NSFormatter *)searchStringFormatter { return nil; }

#pragma mark Main thread

- (void)addPublicationsToGroup:(bycopy NSArray *)pubs;
{
    OBASSERT([NSThread inMainThread]);
    [group addPublications:pubs];
}

#pragma mark Server thread

- (void)setAvailableResults:(int)value;
{
    availableResults = value;
}

- (int)availableResults;
{
    return availableResults;
}

- (void)setFetchedResults:(int)value;
{
    fetchedResults = value;
}

- (int)fetchedResults;
{
    return fetchedResults;
}

static BibItem *createBibItemWithRecord(NSXMLNode *record)
{
    // this is now a field/value set for a particular publication record
    NSXMLNode *child = [record childCount] ? [record childAtIndex:0] : nil;
    NSMutableDictionary *pubFields = [NSMutableDictionary new];
    NSString *keywordSeparator = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKDefaultGroupFieldSeparatorKey];

    while (nil != child) {
        
        NSString *name = [child name];
        
        if ([name isEqualToString:@"item_title"] && [child stringValue])
            [pubFields setObject:[child stringValue] forKey:BDSKTitleString];
        else if ([name isEqualToString:@"source_title"] && [child stringValue])
            [pubFields setObject:[child stringValue] forKey:BDSKJournalString];
        else if ([name isEqualToString:@"authors"]) {
            NSString *authorString = [[[child nodesForXPath:@".//AuCollectiveName" error:NULL] arrayByPerformingSelector:@selector(stringValue)] componentsJoinedByString:@" and "];
            if (authorString)
                [pubFields setObject:authorString forKey:BDSKAuthorString];
        }
        else if ([name isEqualToString:@"abstract"]) {
            NSString *abstract = [[[child nodesForXPath:@"p" error:NULL] firstObject] stringValue];
            if (abstract)
                [pubFields setObject:abstract forKey:BDSKAbstractString];
        }
        else if ([name isEqualToString:@"pub_url"] && [child stringValue])
            [pubFields setObject:[child stringValue] forKey:BDSKUrlString];
        else if ([name isEqualToString:@"keywords"] && [child stringValue]) {
            NSString *keywordString = [[[child nodesForXPath:@".//keyword" error:NULL] arrayByPerformingSelector:@selector(stringValue)] componentsJoinedByString:keywordSeparator];
            if (keywordString)
                [pubFields setObject:keywordString forKey:BDSKKeywordsString];
        }
        
        child = [child nextSibling];
    }
    
    BibItem *pub = [[BibItem alloc] initWithType:BDSKJournalString
                                        fileType:BDSKBibtexString
                                         citeKey:nil
                                       pubFields:pubFields
                                           isNew:YES];
    [pubFields release];
    return pub;
}

static NSArray *publicationsWithISIXMLString(NSString *xmlString)
{
    NSCParameterAssert(nil != xmlString);
    NSError *error;
    NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithXMLString:xmlString options:0 error:&error] autorelease];
    if (nil == xmlDoc) {
        NSLog(@"failed to create XML document from ISI string.  %@", error);
        return nil;
    }
    
    NSArray *records = [xmlDoc nodesForXPath:@"/RECORDS/REC" error:&error];
    if (nil == records)
        NSLog(@"%@", error);
    
    NSXMLNode *record = [records firstObject];
    NSMutableArray *pubs = [NSMutableArray array];
    
    while (nil != record) {
        
        BibItem *pub = createBibItemWithRecord(record);
        [pubs addObject:pub];
        [pub release];
        
        record = [record nextSibling];
    }
    return pubs;
}

- (oneway void)downloadWithSearchTerm:(NSString *)searchTerm;
{    
    NSArray *pubs = nil;
    if (NO == [NSString isEmptyString:searchTerm]){
        
        // @@ currently limited to topic search; need to figure out UI for other search types (mixing search types will require either NSTokenField or raw text string entry)
        BDSKServerInfo *info = [self serverInfo];
        if ([searchTerm rangeOfString:@"="].location == NSNotFound)
            searchTerm = [NSString stringWithFormat:@"TS=\"%@\"", searchTerm];
        
        // perform WS query to get count of results...
        NSDictionary *resultInfo;
        
        // @@ Currently limited to WOS database; extension to other WOS databases might require different WebService stubs?
        resultInfo = [SearchRetrieveService search:@"WOS"
                                          in_query:searchTerm
                                          in_depth:@""
                                       in_editions:[info database]
                                       in_firstRec:1
                                        in_numRecs:1];
        
        if (nil == resultInfo) {
            OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&flags.failedDownload);
            // we already know that a connection can be made, so we likely don't have permission to read this edition or database
            NSError *presentableError = [NSError mutableLocalErrorWithCode:kBDSKNetworkConnectionFailed localizedDescription:NSLocalizedString(@"Unable to retrieve results.  You may not have permission to use this database.", @"Error message when connection to Web of Science fails.")];
            [NSApp performSelectorOnMainThread:@selector(presentError:) withObject:presentableError waitUntilDone:NO];
        }
        
        [self setAvailableResults:[[resultInfo objectForKey:@"recordsFound"] intValue]];
        
        int numResults = MIN([self availableResults] - [self fetchedResults], MAX_RESULTS);
        //NSAssert(numResults >= 0, @"number of results to get must be non-negative");
        
        if(numResults > 0) {
            // retrieve XML results
            resultInfo = [SearchRetrieveService searchRetrieve:@"WOS"
                                                      in_query:searchTerm
                                                      in_depth:@""
                                                   in_editions:[info database]
                                                       in_sort:@""
                                                   in_firstRec:[self fetchedResults]
                                                    in_numRecs:numResults
                                                     in_fields:@"doctype authors bib_vol pubtype pub_url source_title item_title bib_issue bib_pages keywords abstract"];

            if ([resultInfo objectForKey:@"records"])
                pubs = publicationsWithISIXMLString([resultInfo objectForKey:@"records"]);
        }
        
    }
    
    // set this flag before adding pubs, or the client will think we're still retrieving (and spinners don't stop)
    OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&flags.isRetrieving);
    
    // this will create the array if it doesn't exist
    [[self serverOnMainThread] addPublicationsToGroup:pubs];
}

@end

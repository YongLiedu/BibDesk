//
//  BDSKZoomGroupServer.m
//  Bibdesk
//
//  Created by Adam Maxwell on 12/26/06.
/*
 This software is Copyright (c) 2006-2009
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

#import "BDSKZoomGroupServer.h"
#import "BDSKSearchGroup.h"
#import "BDSKStringParser.h"
#import "BDSKServerInfo.h"
#import "BibItem.h"
#import "CFString_BDSKExtensions.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "BDSKReadWriteLock.h"

#define MAX_RESULTS 100

#define USMARC_STRING   @"US MARC"
#define UNIMARC_STRING  @"UNIMARC"
#define MARCXML_STRING  @"MARC XML"
#define DCXML_STRING    @"DC XML"
#define MODS_STRING     @"MODS"

@implementation BDSKZoomGroupServer

+ (void)initialize
{
    BDSKINITIALIZE;
    [ZOOMRecord setFallbackEncoding:NSISOLatin1StringEncoding];
}

+ (NSArray *)supportedRecordSyntaxes {
    return [NSArray arrayWithObjects:USMARC_STRING, UNIMARC_STRING, MARCXML_STRING, DCXML_STRING, MODS_STRING, nil];
}

+ (ZOOMSyntaxType)zoomRecordSyntaxForRecordSyntaxString:(NSString *)syntax{
    if ([syntax isEqualToString:USMARC_STRING]) 
        return USMARC;
    else if ([syntax isEqualToString:UNIMARC_STRING]) 
        return UNIMARC;
    else if ([syntax isEqualToString:MARCXML_STRING] || [syntax isEqualToString:DCXML_STRING] || [syntax isEqualToString:MODS_STRING]) 
        return XML;
    else
        return UNKNOWN;
}

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
        errorMessage = nil;
        infoLock = [[BDSKReadWriteLock alloc] init];
        [self startDOServerSync];
    }
    return self;
}

- (void)dealloc
{
    [infoLock release];
    group = nil;
    [connection release], connection = nil;
    [serverInfo release], serverInfo = nil;
    [errorMessage release], errorMessage = nil;
    [super dealloc];
}

- (Protocol *)protocolForMainThread { return @protocol(BDSKZoomGroupServerMainThread); }
- (Protocol *)protocolForServerThread { return @protocol(BDSKZoomGroupServerLocalThread); }

#pragma mark BDSKSearchGroupServer protocol

// these are called on the main thread

- (void)terminate
{
    [self stopDOServer];
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);
}

- (void)stop
{
    [[self serverOnServerThread] terminateConnection];
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);
}

- (void)retrievePublications
{
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.failedDownload);
    
    OSAtomicCompareAndSwap32Barrier(0, 1, &flags.isRetrieving);
    [[self serverOnServerThread] downloadWithSearchTerm:[group searchTerm]];
}

- (void)setServerInfo:(BDSKServerInfo *)info;
{
    [infoLock lockForWriting];
    if (serverInfo != info) {
        [serverInfo release];
        serverInfo = [info copy];
    }
    [infoLock unlock];
    OSAtomicCompareAndSwap32Barrier(0, 1, &flags.needsReset);
}

- (BDSKServerInfo *)serverInfo;
{
    [infoLock lockForReading];
    BDSKServerInfo *info = [[serverInfo copy] autorelease];
    [infoLock unlock];
    return info;
}

- (void)setNumberOfAvailableResults:(NSInteger)value;
{
    OSAtomicCompareAndSwap32Barrier(availableResults, value, &availableResults);
}

- (NSInteger)numberOfAvailableResults;
{
    return availableResults;
}

- (void)setNumberOfFetchedResults:(NSInteger)value;
{
    OSAtomicCompareAndSwap32Barrier(fetchedResults, value, &fetchedResults);
}

- (NSInteger)numberOfFetchedResults;
{
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

- (NSFormatter *)searchStringFormatter { return [[[ZOOMCCLQueryFormatter alloc] initWithConfigString:[[[self serverInfo] options] objectForKey:@"queryConfig"]] autorelease]; }

#pragma mark Main thread 

- (void)addPublicationsToGroup:(bycopy NSArray *)pubs;
{
    BDSKASSERT([NSThread isMainThread]);
    [group addPublications:pubs];
}

#pragma mark Server thread 

- (void)resetConnection;
{
    BDSKServerInfo *info = [self serverInfo];
    
    BDSKASSERT([info host] != nil);
    
    [connection release];
    if ([info host] != nil) {
        connection = [[ZOOMConnection alloc] initWithHost:[info host] port:[[info port] intValue] database:[info database]];
        [connection setPassword:[info password]];
        [connection setUsername:[info username]];
        ZOOMSyntaxType syntax = [[self class] zoomRecordSyntaxForRecordSyntaxString:[info recordSyntax]];
        if(syntax != UNKNOWN)
            [connection setPreferredRecordSyntax:syntax];    

        [connection setResultEncodingToIANACharSetName:[info resultEncoding]];
        
        NSSet *specialKeys = [NSSet setWithObjects:@"password", @"username", @"recordSyntax", @"resultEncoding", @"removeDiacritics", @"queryConfig", nil];
        
        for (NSString *key in [info options]) {
            if ([specialKeys containsObject:key] == NO)
                [connection setOption:[[info options] objectForKey:key] forKey:key];
        }
        
        OSAtomicCompareAndSwap32Barrier(1, 0, &flags.needsReset);
    }else {
        connection = nil;
    }
    
    [self setNumberOfAvailableResults:0];
    [self setNumberOfFetchedResults:0];
} 

- (oneway void)terminateConnection;
{
    [connection release];
    connection = nil;
    OSAtomicCompareAndSwap32Barrier(0, 1, &flags.needsReset);
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);
} 

- (NSInteger)stringTypeForRecordString:(NSString *)string
{
    NSString *recordSyntax = [serverInfo recordSyntax];
    NSInteger stringType = BDSKUnknownStringType;
    if([recordSyntax isEqualToString:USMARC_STRING] || [recordSyntax isEqualToString:UNIMARC_STRING]) {
        stringType = BDSKMARCStringType;
    } else if([recordSyntax isEqualToString:MARCXML_STRING]) {
        stringType = BDSKMARCStringType;
        if ([BDSKStringParser canParseString:string ofType:stringType] == NO)
            stringType = BDSKDublinCoreStringType;
    } else if([recordSyntax isEqualToString:DCXML_STRING]) {
        stringType = BDSKDublinCoreStringType;
        if ([BDSKStringParser canParseString:string ofType:stringType] == NO)
            stringType = BDSKMARCStringType;
    } else if([recordSyntax isEqualToString:MODS_STRING]) {
        stringType = BDSKMODSStringType;
    }
    if (NO == [BDSKStringParser canParseString:string ofType:stringType])
        stringType = [string contentStringType];
    return stringType;
}

- (oneway void)downloadWithSearchTerm:(NSString *)searchTerm;
{
    // only reset the connection when we're actually going to use it, since a mixed host/database/port won't work
    OSMemoryBarrier();
    if (flags.needsReset)
        [self resetConnection];
    
    NSMutableArray *pubs = nil;
    
    if (NO == [NSString isEmptyString:searchTerm]){
        
        BDSKServerInfo *info = [self serverInfo];
        
        if ([info removeDiacritics]) {
            CFMutableStringRef mutableCopy = (CFMutableStringRef)[[searchTerm mutableCopy] autorelease];
            CFStringNormalize(mutableCopy, kCFStringNormalizationFormD);
            BDDeleteCharactersInCharacterSet(mutableCopy, CFCharacterSetGetPredefined(kCFCharacterSetNonBase));
            searchTerm = (NSString *)mutableCopy;
        }
                
        // the resultSet is cached for each searchTerm, so we have no overhead calling it for retrieving more results
        ZOOMQuery *query = [ZOOMQuery queryWithCCLString:searchTerm config:[[info options] objectForKey:@"queryConfig"]];
        
        ZOOMResultSet *resultSet = query ? [connection resultsForQuery:query] : nil;
        
        if (nil == resultSet) {
            OSAtomicCompareAndSwap32Barrier(0, 1, &flags.failedDownload);
            [self setErrorMessage:NSLocalizedString(@"Could not retrieve results", @"")];
        }
        
        [self setNumberOfAvailableResults:[resultSet countOfRecords]];
        
        NSInteger numResults = MIN([self numberOfAvailableResults] - [self numberOfFetchedResults], MAX_RESULTS);
        //NSAssert(numResults >= 0, @"number of results to get must be non-negative");
        
        if(numResults > 0){
            NSArray *records = [resultSet recordsInRange:NSMakeRange([self numberOfFetchedResults], numResults)];
            
            [self setNumberOfFetchedResults:[self numberOfFetchedResults] + numResults];
            
            pubs = [NSMutableArray array];
            NSString *record;
            NSInteger stringType;
            BibItem *anItem;
            for (id result in records) {
                record = [result rawString];
                stringType = [self stringTypeForRecordString:record];
                anItem = [[BDSKStringParser itemsFromString:record ofType:stringType error:NULL] lastObject];
                if (anItem == nil) {
                    record = [result renderedString];
                    anItem = [[BibItem alloc] initWithType:BDSKBookString
                                                  fileType:BDSKBibtexString
                                                   citeKey:nil
                                                 pubFields:[NSDictionary dictionaryWithObjectsAndKeys:record, BDSKAnnoteString, nil]
                                                     isNew:YES];
                    [anItem autorelease];
                }
                [pubs addObject:anItem];
            }
        }
        
    }
    // set this flag before adding pubs, or the client will think we're still retrieving (and spinners don't stop)
    OSAtomicCompareAndSwap32Barrier(1, 0, &flags.isRetrieving);

    // this will create the array if it doesn't exist
    [[self serverOnMainThread] addPublicationsToGroup:pubs];
}

- (void)serverDidFinish{
    [self terminateConnection];
}

@end

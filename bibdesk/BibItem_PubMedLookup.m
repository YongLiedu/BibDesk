//
//  BibItem_PubMedLookup.m
//  Bibdesk
//
//  Created by Adam Maxwell on 03/29/07.
/*
 This software is Copyright (c) 2007-2009
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

#import "BibItem_PubMedLookup.h"
#import <WebKit/WebKit.h>
#import "BDSKStringParser.h"

@interface BDSKPubMedLookupHelper : NSObject
+ (NSString *)referenceForPMID:(NSString *)pmid;
@end

@implementation BibItem (PubMedLookup)

/* Based on public domain sample code written by Oleg Khovayko, available at
 http://www.ncbi.nlm.nih.gov/entrez/query/static/eutils_example.pl
 
 - We pass tool=bibdesk for their tracking purposes.  
 - We use lower case characters in the URL /except/ for WebEnv
 - See http://www.ncbi.nlm.nih.gov/entrez/query/static/eutils_help.html for details.
 
 */

+ (id)itemWithPMID:(NSString *)pmid;
{
    NSString *string = [BDSKPubMedLookupHelper referenceForPMID:pmid];
    return string ? [[BDSKStringParser itemsFromString:string error:NULL] lastObject] : nil;
}

@end

@implementation BDSKPubMedLookupHelper

+ (NSString *)baseURLString { return @"http://eutils.ncbi.nlm.nih.gov/entrez/eutils"; }

+ (BOOL)canConnect;
{
    CFURLRef theURL = (CFURLRef)[NSURL URLWithString:[self baseURLString]];
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

+ (NSString *)referenceForPMID:(NSString *)pmid;
{
    NSParameterAssert(pmid != nil);
    
    NSString *toReturn = nil;
    
    if ([self canConnect] == NO)
        return toReturn;
        
    NSXMLDocument *document = nil;
    
    // get the initial XML document with our search parameters in it; we ask for 2 results at most
    NSString *esearch = [[[self class] baseURLString] stringByAppendingFormat:@"/esearch.fcgi?db=pubmed&retmax=2&usehistory=y&term=%@&tool=bibdesk", pmid];
    NSURL *theURL = [NSURL URLWithString:esearch]; 
    OBPRECONDITION(theURL);
    
    NSURLRequest *request = [NSURLRequest requestWithURL:theURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:1.0];
    NSURLResponse *response;
    NSError *error;
    NSData *esearchResult = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    if ([esearchResult length])
        document = [[NSXMLDocument alloc] initWithData:esearchResult options:NSXMLNodeOptionsNone error:&error];
    
    if (nil != document) {
        NSXMLElement *root = [document rootElement];

        // we need to extract WebEnv, Count, and QueryKey to construct our final URL
        NSString *webEnv = [[[root nodesForXPath:@"/eSearchResult[1]/WebEnv[1]" error:NULL] lastObject] stringValue];
        NSString *queryKey = [[[root nodesForXPath:@"/eSearchResult[1]/QueryKey[1]" error:NULL] lastObject] stringValue];
        id count = [[[root nodesForXPath:@"/eSearchResult[1]/Count[1]" error:NULL] lastObject] objectValue];

        // ensure that we only have a single result; if it's ambiguous, just return nil
        if ([count intValue] == 1) {  
            
            // get the first result (zero-based indexing)
            NSString *efetch = [[[self class] baseURLString] stringByAppendingFormat:@"/efetch.fcgi?rettype=medline&retmode=text&retstart=0&retmax=1&db=pubmed&query_key=%@&WebEnv=%@&tool=bibdesk", queryKey, webEnv];
            theURL = [NSURL URLWithString:efetch];
            OBPOSTCONDITION(theURL);
            
            request = [NSURLRequest requestWithURL:theURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:1.0];
            NSData *efetchResult = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            
            if (efetchResult) {
                
                // try to get encoding from the http headers; returned nil when I tried
                NSString *encodingName = [response textEncodingName];
                NSStringEncoding encoding = encodingName ? CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((CFStringRef)encodingName)) : kCFStringEncodingInvalidId;
                
                if (encoding != kCFStringEncodingInvalidId)
                    toReturn = [[NSString alloc] initWithData:efetchResult encoding:encoding];
                else
                    toReturn = [[NSString alloc] initWithData:efetchResult encoding:NSUTF8StringEncoding];
                
                if (nil == toReturn)
                    toReturn = [[NSString alloc] initWithData:efetchResult encoding:NSISOLatin1StringEncoding];
                
                [toReturn autorelease];
            }
        }
        [document release];
    }
    
    return toReturn;
}

@end

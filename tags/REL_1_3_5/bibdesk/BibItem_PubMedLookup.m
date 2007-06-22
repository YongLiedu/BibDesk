//
//  BibItem_PubMedLookup.m
//  Bibdesk
//
//  Created by Adam Maxwell on 03/29/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

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
            [document release];
            
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
    }
    
    return toReturn;
}

@end

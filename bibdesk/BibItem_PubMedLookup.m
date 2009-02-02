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
#import <AGRegex/AGRegex.h>
#import "NSURL_BDSKExtensions.h"
#import "NSString_BDSKExtensions.h"
#import "PDFMetadata.h"

@interface BDSKPubMedLookupHelper : NSObject
+ (NSString *)referenceForPubMedSearchTerm:(NSString *)searchTerm;
@end

@implementation NSString (PubMedLookup)

// here is another exampled of a doi regex = /(10\.[0-9]+\/[a-z0-9\.\-\+\/\(\)]+)/i;
// from http://userscripts.org/scripts/review/8939
static NSString *doiRegexString = @"doi[:\\s/]{1,2}(10\\.[0-9]{3,4})[\\s/0]{1,3}(\\S+)";

- (NSString *) stringByExtractingDOIFromString;
{
	NSString *doi=nil;

	AGRegex *doiRegex= [AGRegex regexWithPattern:doiRegexString
										 options:AGRegexMultiline|AGRegexCaseInsensitive];
	AGRegexMatch *match = [doiRegex findInString:self];
	if([match groupAtIndex:1]!=nil && [match groupAtIndex:2]!=nil)
		doi = [NSString stringWithFormat:@"%@/%@",[match groupAtIndex:1],[match groupAtIndex:2]];
	return doi;
}

- (NSString *) pubmedSearchByExtractingAllDOIsFromString;
{
	// handle strings containing multiple dois
	// eventual goal will be 
	NSString *doisearch=nil;
	
	AGRegex *doiRegex= [AGRegex regexWithPattern:doiRegexString
										 options:AGRegexMultiline|AGRegexCaseInsensitive];
	AGRegexMatch *match;
	NSEnumerator *doienum = [doiRegex findEnumeratorInString:self];
	while (match = [doienum nextObject] ) {
		NSString* doi;
		if([match groupAtIndex:1]!=nil && [match groupAtIndex:2]!=nil){			
			doi = [NSString stringWithFormat:@"\"%@/%@\" [AID]",[match groupAtIndex:1],[match groupAtIndex:2]];
			if(doisearch) doisearch=[doisearch stringByAppendingFormat:@" OR %@",doi];
			else doisearch=doi;
		}
	}
	
	return doisearch;
}

- (NSString *) stringByExtractingPIIFromString;
{
	// nb this method will NOT attempt to 'denormalise' normalised PIIs
	
	NSString *pii=nil;
	// next Elsevier PII
	// Some useful info at:
	// http://www.weizmann.ac.il/home/comartin/doi.html
	// It has the form Sxxxx-xxxx(yy)zzzzz-c,
	// where xxxx-xxxx is the 8-digit ISSN (International Systematic Serial Number) of the journal,
	// yy are the last two digits of the year, 
	// zzzzz is an article number within that year of the journal, 
	// and c is a checksum digit
	// sometimes it is also normalised by removing all non alpha characters 
	// (and this is how it is stored in PubMed)
	
	//S0092867402007006 or S0092-8674(02)00700-6
	// NB occasionally the checksum is X and once I have seen: 0092-8674(93)90422-M
	// ie terminal M and missing S
	// Unfortunately Elsevier switched from submitting the standard form to PubMed
	// to the normalised form.
	
	// I have relaxed the regex to allow a missing S in the full form BUT not the normalised form
	
	AGRegex *PIIRegex = [AGRegex regexWithPattern:@"S{0,1}[0-9]{4}-[0-9]{3}[0-9X][(][0-9]{2}[)][0-9]{5}-[0-9MX]"
										  options:AGRegexMultiline|AGRegexCaseInsensitive];
	
	AGRegexMatch *match = [PIIRegex findInString:self];
	if([match groupAtIndex:0]!=nil)
		pii = [NSString stringWithString:[match groupAtIndex:0]];
	if(pii==nil){
		// try normalised form
		AGRegex *PIIRegex2 = [AGRegex regexWithPattern:@"S[0-9]{7}[0-9X][0-9]{7}[0-9MX]"
											   options:AGRegexCaseInsensitive];
		match = [PIIRegex2 findInString:self];
		
		if([match groupAtIndex:0]!=nil)
			pii = [NSString stringWithString:[match groupAtIndex:0]];
	}
		
	return pii;
}

- (NSString *) stringByExtractingNormalisedPIIFromString;
{
	NSString *pii=[self stringByExtractingPIIFromString];
	if(pii!=nil)
	pii = [pii stringByReplacingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"()-"]
									 withString:@""];
	return pii;
}

- (NSString *) stringByMakingPubmedSearchFromAnyBibliographicIDsInString;
{
	NSString *doi=nil,*pii=nil;
	
	// first try DOI
	doi = [self stringByExtractingDOIFromString];
	if(doi) return [NSString stringWithFormat:@"%@ [AID]",doi];
	
	// next try Elsevier PII
	pii = [self stringByExtractingPIIFromString];
	// nb we need to search for both forms and the standard one must be quoted
	if(pii) return [NSString stringWithFormat:@"\"%@\" [AID] OR %@ [AID]",
					 pii,[pii stringByExtractingNormalisedPIIFromString]];

	// next try looking for any nature publishing group form
	if([self length]>(NSUInteger)6){
		// kMDItemTitle = "npgrj_nmeth_1241 821..827"
		// kMDItemTitle = "NPGRJ_NMETH_989 73..79"
		
		NSString *npg,*npglc,*firstPart,*secondPart;
		npglc=[self lowercaseString];
		firstPart = [npglc substringToIndex:6];
		secondPart = [npglc substringFromIndex:6];
		if([firstPart isEqualToString:@"npgrj_"]){
			NSArray *npgParts = [secondPart componentsSeparatedByString:@" "];
			if ([npgParts count] > 0) {
				npg = [npgParts objectAtIndex:0];
				return [NSString stringWithFormat:@"%@ [AID] OR %@ [AID]",
						npg,[npg stringByRemovingString:@"_"]];
			}
		}
	}
	
	return nil;
}
@end

@implementation BibItem (PubMedLookup)

+ (id)itemByParsingPDFDocument: (PDFDocument *) pdfd  {
	// See if we can find any bibliographic info in the pdf title attribute
	BibItem *bi=nil ;

	NSString *pubMedSearch;
	NSString *pdfTitle = [[pdfd documentAttributes] valueForKey:BDSKPDFDocumentTitleAttribute];	
	pubMedSearch=[pdfTitle stringByMakingPubmedSearchFromAnyBibliographicIDsInString];
	if(pubMedSearch!=nil){
		bi=[BibItem itemWithPubMedSearchTerm:pubMedSearch];
	}
	
	// ... else directly parse text of first two pages for doi
	NSUInteger i=0;
	for(;bi==nil && i<2 && i<[pdfd pageCount];i++){
		
		NSString *pdftextthispage = [[pdfd pageAtIndex:i] string];
		// If we've got nothing to parse, try the next page
		if(pdftextthispage==nil || [pdftextthispage length]<4) continue;
		
		// Clean up any high unicode characters which can flummox the regex
		NSCharacterSet *extendedUnicode=[NSCharacterSet characterSetWithRange:NSMakeRange(0x10000, 0x10FFFF-0x10000)];
		pdftextthispage = [pdftextthispage stringByReplacingCharactersInSet:extendedUnicode withString:@" "];

		pubMedSearch = [pdftextthispage stringByExtractingDOIFromString];
		pubMedSearch = [pdftextthispage pubmedSearchByExtractingAllDOIsFromString];
		
		if(pubMedSearch!=nil) {
			// may as well restrict doi search to pubmed AID field
//			pubMedSearch = [pubMedSearch stringByAppendingString:@" [AID]"];
			bi = [BibItem itemWithPubMedSearchTerm:pubMedSearch];
		}
	}
	
	return bi;
}

+ (id)itemByParsingPDFFile:(NSString *)pdfPath;
{
	BibItem *bi=nil;
	
	// see if we can find any bibliographic info in the filename
	NSString *pubMedSearch=nil;
	pubMedSearch=[[[pdfPath lastPathComponent] stringByDeletingPathExtension] stringByMakingPubmedSearchFromAnyBibliographicIDsInString];
	if(pubMedSearch!=nil){
		bi=[BibItem itemWithPubMedSearchTerm:pubMedSearch];
		if(bi!=nil) return bi;
	}
	
	PDFDocument *pdfd = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:pdfPath]];
	if(pdfd==NULL) return nil;
	
	bi = [self itemByParsingPDFDocument: pdfd];

	[pdfd release];

	return bi;
}

+ (id)itemWithPubMedSearchTerm:(NSString *)searchTerm;
{
    NSString *string = [BDSKPubMedLookupHelper referenceForPubMedSearchTerm:searchTerm];
    return string ? [[BDSKStringParser itemsFromString:string ofType:BDSKUnknownStringType error:NULL] lastObject] : nil;
}

@end

@implementation BDSKPubMedLookupHelper

/* Based on public domain sample code written by Oleg Khovayko, available at
 http://www.ncbi.nlm.nih.gov/entrez/query/static/eutils_example.pl
 
 - We pass tool=bibdesk for their tracking purposes.  
 - We use lower case characters in the URL /except/ for WebEnv
 - See http://www.ncbi.nlm.nih.gov/entrez/query/static/eutils_help.html for details.
 
 */

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

+ (NSString *)referenceForPubMedSearchTerm:(NSString *) searchTerm;
{
    NSParameterAssert(searchTerm != nil);
    
    NSString *toReturn = nil;
    
    if ([self canConnect] == NO)
        return toReturn;
        
    NSXMLDocument *document = nil;
    
    searchTerm = [searchTerm stringByAddingPercentEscapesIncludingReserved];
    
    // get the initial XML document with our search parameters in it; we ask for 2 results at most
    NSString *esearch = [[[self class] baseURLString] stringByAppendingFormat:@"/esearch.fcgi?db=pubmed&retmax=2&usehistory=y&term=%@&tool=bibdesk", searchTerm];
	NSURL *theURL = [NSURL URLWithStringByNormalizingPercentEscapes:esearch];
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

//
//  BibItem_PubMedLookup.m
//  Bibdesk
//
//  Created by Adam Maxwell on 03/29/07.
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

#import "BibItem_PubMedLookup.h"
#import <WebKit/WebKit.h>
#import "BDSKStringParser.h"
#import "BDSKPubMedXMLParser.h"
#import <AGRegex/AGRegex.h>
#import "NSURL_BDSKExtensions.h"
#import "NSString_BDSKExtensions.h"

@interface BDSKPubMedLookupHelper : NSObject
+ (NSData *)xmlReferenceDataForSearchTerm:(NSString *)searchTerm;
@end

@interface NSString (PubMedLookup)
- (NSArray *)extractAllDOIsFromString;
- (NSString *)stringByExtractingPIIFromString;
- (NSString *)stringByExtractingNPGRJFromString;
- (NSString *)stringByRemovingAliens;
@end

@implementation BibItem (PubMedLookup)

+ (id)itemFromAnyBibliographicIDsInString:(NSString *)string;
{
    BibItem *bi = nil;
    NSString *bibID;
    NSString *pubmedSearch;
    
    // first try Elsevier PII
    if ((bibID = [string stringByExtractingPIIFromString])) {
        // nb we need to search for both forms and the standard one must be quoted
        pubmedSearch = [NSString stringWithFormat:@"\"%@\" [AID] OR %@ [AID]", bibID, [bibID stringByDeletingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"()-"]]];
        bi = [self itemWithPubMedSearchTerm:pubmedSearch];
    
    } else if ((bibID = [[string extractAllDOIsFromString] firstObject])) {
        // next try DOI
        bi = [self itemWithDOI:bibID owner:nil];
        if (bi == nil) {
            pubmedSearch = [NSString stringWithFormat:@"%@ [AID]", bibID];
            bi = [self itemWithPubMedSearchTerm:pubmedSearch];
        }
    } else if ((bibID = [string stringByExtractingNPGRJFromString])) {
        // next try looking for any nature publishing group form
        pubmedSearch = [NSString stringWithFormat:@"%@ [AID] OR %@ [AID]", bibID, [bibID stringByRemovingString:@"_"]];
        bi = [self itemWithPubMedSearchTerm:pubmedSearch];
    }
    
    return bi;
}

+ (id)itemByParsingPDFAtURL:(NSURL *)pdfURL;
{
	BibItem *bi=nil;
    NSString *name = [[pdfURL lastPathComponent] stringByDeletingPathExtension];
	
	// see if we can find any bibliographic info in the filename
    bi = [self itemFromAnyBibliographicIDsInString:name];
	
    if (bi == nil) {
        PDFDocument *pdfDoc = [[PDFDocument alloc] initWithURL:pdfURL];
        if (pdfDoc) {
            // See if we can find any bibliographic info in the pdf title attribute
            if ((name = [[pdfDoc documentAttributes] valueForKey:PDFDocumentTitleAttribute]))
                bi = [self itemFromAnyBibliographicIDsInString:name];
            
            if (bi == nil) {
                // ... else directly parse text of first two pages for doi
                NSUInteger i = 0;
                for (; bi == nil && i < 2 && i < [pdfDoc pageCount]; i++) {
                    
                    NSString *pageText = [[pdfDoc pageAtIndex:i] string];
                    // If we've got nothing to parse, try the next page
                    if ([pageText length]>4) {
                        // Clean up any high unicode characters which can flummox the regex
                        NSArray *dois = [[pageText stringByRemovingAliens] extractAllDOIsFromString];
                        if ([dois count]) {
                            NSMutableString *pubmedSearch = [NSMutableString string];
                            for (NSString *doi in dois) {
                                bi = [self itemWithDOI:doi owner:nil];
                                if (bi) break;
                                if ([pubmedSearch length])
                                    [pubmedSearch appendString:@" OR "];
                                [pubmedSearch appendFormat:@"\"%@\" [AID]", doi];
                            }
                            if (bi == nil)
                                bi = [self itemWithPubMedSearchTerm:pubmedSearch];
                        }
                    }
                }
            }
            [pdfDoc release];
        }
    }
    
	return bi;
}

+ (id)itemWithPubMedSearchTerm:(NSString *)searchTerm;
{
    NSData *data = [BDSKPubMedLookupHelper xmlReferenceDataForSearchTerm:searchTerm];
    return [data length] ? [[BDSKPubMedXMLParser itemsFromData:data error:NULL] firstObject] : nil;
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

+ (NSData *)xmlReferenceDataForSearchTerm:(NSString *)searchTerm;
{
    NSParameterAssert(searchTerm != nil);
    
    NSData *toReturn = nil;
        
    if ([[NSURL URLWithString:[self baseURLString]] canConnect] == NO)
        return toReturn;
        
    NSXMLDocument *document = nil;
    
    searchTerm = [searchTerm stringByAddingPercentEscapesIncludingReserved];
    
    // get the initial XML document with our search parameters in it; we ask for 2 results at most
    NSString *esearch = [[[self class] baseURLString] stringByAppendingFormat:@"/esearch.fcgi?db=pubmed&retmax=2&usehistory=y&term=%@&tool=bibdesk", searchTerm];
	NSURL *theURL = [NSURL URLWithStringByNormalizingPercentEscapes:esearch];
    BDSKPRECONDITION(theURL);
    
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
        if ([count integerValue] == 1) {  
            
            // get the first result (zero-based indexing)
            NSString *efetch = [[[self class] baseURLString] stringByAppendingFormat:@"/efetch.fcgi?rettype=abstract&retmode=xml&retstart=0&retmax=1&db=pubmed&query_key=%@&WebEnv=%@&tool=bibdesk", queryKey, webEnv];
            theURL = [NSURL URLWithString:efetch];
            BDSKPOSTCONDITION(theURL);
            
            request = [NSURLRequest requestWithURL:theURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:1.0];
            toReturn = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        }
        [document release];
    }
    
    return toReturn;
}

@end

@implementation NSString (PubMedLookup)

// here is another exampled of a doi regex = /(10\.[0-9]+\/[a-z0-9\.\-\+\/\(\)]+)/i;

- (NSArray *)extractAllDOIsFromString;
{
    NSMutableArray *dois = [NSMutableArray array];
    AGRegex *doiRegex = [AGRegex regexWithPattern:@"doi[:\\s/]{1,2}(10\\.[0-9]{4,}(?:\\.[0-9]+)*)[\\s/0]{1,3}(\\S+)"
                                          options:AGRegexMultiline|AGRegexCaseInsensitive];
    AGRegexMatch *match;
    for (match in [doiRegex findEnumeratorInString:self]) {
        NSString *doi;
        if ([match groupAtIndex:1] != nil && [match groupAtIndex:2] != nil)
            [dois addObject:[NSString stringWithFormat:@"%@/%@", [match groupAtIndex:1], [match groupAtIndex:2]]];
    }
    return dois;
}

- (NSString *)stringByExtractingPIIFromString;
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

- (NSString *)stringByExtractingNPGRJFromString;
{
    // kMDItemTitle = "npgrj_nmeth_1241 821..827"
    // kMDItemTitle = "NPGRJ_NMETH_989 73..79"
    if ([self length] <= 6 || [self hasCaseInsensitivePrefix:@"npgrj_"] == NO)
        return nil;
    NSUInteger end = [self rangeOfString:@" "].location;
    if (end == NSNotFound)
        end = [self length];
    return [self substringWithRange:NSMakeRange(6, end - 6)];
}

// NS and CF character sets won't find these, due to the way CFString handles surrogate pairs.  The surrogate pair inlines were borrowed from CFCharacterSetPriv.h in CF-lite-476.13.
static inline bool __SKIsSurrogateHighCharacter(const UniChar character) {
    return ((character >= 0xD800UL) && (character <= 0xDBFFUL) ? true : false);
}

static inline bool __SKIsSurrogateLowCharacter(const UniChar character) {
    return ((character >= 0xDC00UL) && (character <= 0xDFFFUL) ? true : false);
}

static inline bool __SKIsSurrogateCharacter(const UniChar character) {
    return ((character >= 0xD800UL) && (character <= 0xDFFFUL) ? true : false);
}

static inline UTF32Char __SKGetLongCharacterForSurrogatePair(const UniChar surrogateHigh, const UniChar surrogateLow) {
    return ((surrogateHigh - 0xD800UL) << 10) + (surrogateLow - 0xDC00UL) + 0x0010000UL;
}

static inline bool __SKIsPrivateUseCharacter(const UTF32Char ch)
{
    return ((ch >= 0xE000UL && ch <= 0xF8FFUL) ||    /* private use area */
            (ch >= 0xF0000UL && ch <= 0xFFFFFUL) ||  /* supplementary private use A */
            (ch >= 0x100000UL && ch <= 0x10FFFFUL)); /* supplementary private use B */
}

// Remove anything in the private use planes, and/or malformed surrogate pair sequences rdar://problem/6273932
- (NSString *)stringByRemovingAliens {
    
    // make a mutable copy only if needed
    CFMutableStringRef theString = (void *)self;
    
    CFStringInlineBuffer inlineBuffer;
    CFIndex length = CFStringGetLength(theString);
    
    // use the current mutable string with the inline buffer, but make a new mutable copy if needed
    CFStringInitInlineBuffer(theString, &inlineBuffer, CFRangeMake(0, length));
    UniChar ch;
    
#define DELETE_CHARACTERS(n) do{if((void*)self==theString){theString=(void*)[[self mutableCopyWithZone:[self zone]] autorelease];};CFStringDelete(theString, CFRangeMake(delIdx, n));} while(0)
    
    // idx is current index into the inline buffer, and delIdx is current index in the mutable string
    CFIndex idx = 0, delIdx = 0;
    while(idx < length){
        ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, idx);
        if (__SKIsPrivateUseCharacter(ch)) {
            DELETE_CHARACTERS(1);
        } else if (__SKIsSurrogateCharacter(ch)) {
            
            if ((idx + 1) < length) {
                
                UniChar highChar = ch;
                UniChar lowChar = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, idx + 1);
                // if we only have half of a surrogate pair, delete the offending character
                if (__SKIsSurrogateLowCharacter(lowChar) == false || __SKIsSurrogateHighCharacter(highChar) == false) {
                    DELETE_CHARACTERS(1);
                    // only deleted a single char, so don't need to adjust idx
                } else if (__SKIsPrivateUseCharacter(__SKGetLongCharacterForSurrogatePair(highChar, lowChar))) {
                    // remove the pair; can't display private use characters
                    DELETE_CHARACTERS(2);
                    // adjust since we removed two characters...
                    idx++;
                } else {
                    // valid surrogate pair, so we'll leave it alone
                    delIdx += 2;
                    idx++;
                }
                
            } else {
                // insufficient length for this to be a valid sequence, so it's only half of a surrogate pair
                DELETE_CHARACTERS(1);
            }
            
        } else {
            // keep track of our index in the copy and the original
            delIdx++;
        }
        idx++;
    }
    
    return (id)theString;
}

@end

//
//  BDSKGoogleScholarParser.m
//
//  Created by Michael O. McCracken on 9/26/07.
/*
 This software is Copyright (c) 2007-2010
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BDSKGoogleScholarParser.h"
#import <WebKit/WebKit.h>
#import "BibItem.h"
#import "BDSKBibTeXParser.h"
#import "NSError_BDSKExtensions.h"
#import "BDSKBibTeXParser.h"
#import "NSXMLNode_BDSKExtensions.h"

@implementation BDSKGoogleScholarParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    // !!! other countries end up with e.g. scholar.google.be; checking for scholar.google.com may fail in those cases
    // also some sites access google scholar via an ezproxy, so the suffix could be quite complex
    if (! [[[url host] lowercaseString] hasPrefix:@"scholar.google."]){
        return NO;
    }
    
    NSString *containsBibTexLinkNode = @"//a[contains(text(),'BibTeX')]"; 
    
    NSError *error = nil;    

    NSUInteger nodecount = [[[xmlDocument rootElement] nodesForXPath:containsBibTexLinkNode error:&error] count];

    return nodecount > 0;
}


// Despite the name, this method assumes there's only one bibitem to be had from the document. 
// A potential enhancement would be to recognize documents that are index lists of citations
// and follow links two levels deep to get bibitems from each citation in the list.

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{

    NSMutableArray *items = [NSMutableArray arrayWithCapacity:0];
    
    
    //searching recursivley to containing <p class=g> doesn't work anymore wince google degraded from xhtml to html
    //NSString *googSearchResultNodePath = @"//p[@class='g']";
    
    NSString *BibTexLinkNodePath = @".//a[contains(text(),'BibTeX')]";
	
    //NSString *targetUrlNodePath = @".//span[@class='w']/a";
    
    NSError *error = nil;
            
    // fetch the google search results
    NSArray *googSearchResults = [[xmlDocument rootElement] nodesForXPath:BibTexLinkNodePath
                                                                    error:&error];
    
    // bail out with an XML error if the Xpath query fails
    if (nil == googSearchResults) {
        if (outError) *outError = error;
        return nil;
    }    
    
    NSUInteger i, iMax = [googSearchResults count];
    
    // check the number of nodes first
    if (0 == iMax) {
        error = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"No search results found", @"Google scholar error")];
        [error setValue:NSLocalizedString(@"Unable to parse this page.  Please report this to BibDesk's developers and provide the URL.", @"Google scholar error") forKey:NSLocalizedRecoverySuggestionErrorKey];
        if (outError) *outError = error;
        return nil;
    }
        
    for(i=0; i < iMax; i++){
        
        NSXMLNode *googSearchResult = [googSearchResults objectAtIndex:i];
        
        /*
        
        NSString *targetUrlHrefValue = nil;
        
        // fetch the bibtex link
        
        NSArray *BibTeXLinkNodes = [googSearchResult nodesForXPath:BibTexLinkNodePath
                                                             error:&error];
        
        if (nil == BibTeXLinkNodes) {

            // This is an error since this method isn't supposed to be called if the bibtex
            // links don't appear on the page
            NSLog(@"Google Scholar Error: unable to parse bibtex url from search result %lu due to xpath error", (unsigned long)i);
            continue;

        } else if (1 != [BibTeXLinkNodes count]) {

            // If Google ever start providing multiple alternative bibtex links for a
            // single item we will need to deal with that
            NSLog(@"Google Scholar Error: unable to parse bibtex url from search result %lu, found %lu bibtex urls (expected 1)", (unsigned long)i, (unsigned long)[BibTeXLinkNodes count]);
            continue;

        }
        
        // fetch the actual item url
        NSArray *targetUrlNodes = [googSearchResult nodesForXPath:targetUrlNodePath
                                                            error:&error];
        
        // skip if the target xpath fails, but continue with the bibtex import - some result
        // types have no url (eg. Book or Citation entries)
        if (nil != targetUrlNodes && 1 == [targetUrlNodes count]) {
            
            // successfully found the result target url
            targetUrlHrefValue = [[targetUrlNodes objectAtIndex:0] stringValueOfAttribute:@"href"];
            
            // fix relative urls
            if (![targetUrlHrefValue hasPrefix:@"http"])
                targetUrlHrefValue = [[NSURL URLWithString:targetUrlHrefValue relativeToURL:url] absoluteString];
        }
        
        NSXMLNode *btlinknode = [BibTeXLinkNodes objectAtIndex:0];
        */
        
        NSString *hrefValue = [googSearchResult stringValueOfAttribute:@"href"];
        
        
        NSURL *btURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@%@", [url host], hrefValue]];
        
        NSURLRequest *request = [NSURLRequest requestWithURL:btURL cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:60.0];
        NSURLResponse *response;
        
        NSData *theData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];   
        NSString *bibTeXString = nil;
        
        // google actually provides this information; on my system it returns "macintosh" which gets converted to NSMacOSRomanStringEncoding
        if (nil != theData) {
            
            NSString *encodingName = [response textEncodingName];
            NSStringEncoding encoding = kCFStringEncodingInvalidId;
        
            if (nil != encodingName)
                encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((CFStringRef)encodingName));

            if (encoding != kCFStringEncodingInvalidId)
                bibTeXString = [[NSString alloc] initWithData:theData encoding:encoding];
            else
                bibTeXString = [[NSString alloc] initWithData:theData encoding:NSUTF8StringEncoding];
        
            if (nil == bibTeXString)
                bibTeXString = [[NSString alloc] initWithData:theData encoding:NSISOLatin1StringEncoding];
        
            [bibTeXString autorelease];
        }

        BOOL isPartialData = NO;
        NSArray* bibtexItems = nil;
        
        if (nil != bibTeXString)
            bibtexItems = [BDSKBibTeXParser itemsFromString:bibTeXString document:nil isPartialData:&isPartialData error:&error];
        
        if ([bibtexItems count] && NO == isPartialData) {
            BibItem *bibtexItem = [bibtexItems objectAtIndex:0]; 
        
            [items addObject:bibtexItem];
			
			NSString *bracedTitle = [bibtexItem valueOfField:BDSKTitleString inherit:NO];
			
			// google scholar encloses titles in braces to force capitalization, but it's better to let styles handle that
			if ([bracedTitle hasPrefix:@"{"] && [bracedTitle hasSuffix:@"}"]) {
                NSMutableString *mutableTitle = [bracedTitle mutableCopy];
                [mutableTitle replaceCharactersInRange:NSMakeRange([mutableTitle length] - 1, 1) withString:@""];
				[mutableTitle replaceCharactersInRange:NSMakeRange(0, 1) withString:@""];
				if ([mutableTitle isStringTeXQuotingBalancedWithBraces:YES connected:NO]) 
					[bibtexItem setField:BDSKTitleString toValue:mutableTitle];
				[mutableTitle release];
			}
            
            /*
            NSString *itemUrlField = [bibtexItem valueOfField:BDSKUrlString inherit:NO];
            if (
                nil != targetUrlHrefValue &&
                (nil == itemUrlField || 0 == [itemUrlField length])
                ) {
                
                // target url was found successfully & is not explicitly set in the entry
                [bibtexItem setField:BDSKUrlString toValue:targetUrlHrefValue];
            }
            */
        }
        else {
            // display a fake item in the table so the user knows one of the items failed to parse, but still gets the rest of the data
            NSString *errMsg = NSLocalizedString(@"Unable to parse as BibTeX", @"google scholar error");
            NSDictionary *pubFields = [NSDictionary dictionaryWithObjectsAndKeys:errMsg, BDSKTitleString, [btURL absoluteString], BDSKUrlString, nil];
            BibItem *errorItem = [[BibItem alloc] initWithType:BDSKMiscString citeKey:nil pubFields:pubFields isNew:YES];
            [items addObject:errorItem];
            [errorItem release];
        }
        
    }
        
    if (0 == [items count]) {
        // signal an error condition; this page had BibTeX links, but we were unable to parse anything
        // the BibTeX parser /should/ have set the NSError
        items = nil;
        if (outError)
            *outError = error;
    }
    
    return items;  
    
}


+ (NSArray *) parserInfos {
	NSString * parserDescription = NSLocalizedString(@"Google\342\200\231s attempt to provide a universal search for and in research related literature. Please go to \342\200\230Scholar Preferences\342\200\231 and set the \342\200\230Bibliography Manager\342\200\231 option to \342\200\230Show links to import citations to BibTeX\342\200\231 for it to work.", @"Description for Google Scholar site");
	NSDictionary * parserInfo = [BDSKWebParser parserInfoWithName:@"Google Scholar" address:@"http://scholar.google.com/" description: parserDescription flags: BDSKParserFeatureNone ];
	return [NSArray arrayWithObject: parserInfo];
}


@end 


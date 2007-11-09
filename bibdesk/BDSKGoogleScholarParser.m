//
//  BDSKGoogleScholarParser.m
//
//  Created by Michael O. McCracken on 9/26/07.
/*
 This software is Copyright (c) 2007
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

@implementation BDSKGoogleScholarParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    // !!! other countries end up with e.g. scholar.google.be; checking for scholar.google.com may fail in those cases
    if (! [[url host] hasPrefix:@"scholar.google."]){
        return NO;
    }
    
    NSString *containsBibTexLinkNode = @"//a[contains(text(),'Import into BibTeX')]"; 
    
    NSError *error = nil;    

    int nodecount = [[[xmlDocument rootElement] nodesForXPath:containsBibTexLinkNode error:&error] count];

    return nodecount > 0;
}


// Despite the name, this method assumes there's only one bibitem to be had from the document. 
// A potential enhancement would be to recognize documents that are index lists of citations
// and follow links two levels deep to get bibitems from each citation in the list.

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{

    NSMutableArray *items = [NSMutableArray arrayWithCapacity:0];
    
    
    NSString *BibTexLinkNodePath = @"//a[contains(text(),'Import into BibTeX')]";
    
    NSError *error = nil;    

    NSArray *BibTeXLinkNodes = [[xmlDocument rootElement] nodesForXPath:BibTexLinkNodePath
                                                    error:&error];
    
    // bail out with an XML error if the Xpath query fails
    if (nil == BibTeXLinkNodes) {
        if (outError) *outError = error;
        return nil;
    }
    
    unsigned int i, iMax = [BibTeXLinkNodes count];
    
    // check the number of nodes first
    if (0 == iMax) {
        error = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"No BibTeX links found", @"Google scholar error")];
        [error setValue:NSLocalizedString(@"Unable to parse this page.  Please report this to BibDesk's developers and provide the URL.", @"Google scholar error")];
        if (outError) *outError = error;
        return nil;
    }
    
    for(i=0; i < iMax; i++){
        
        NSXMLNode *btlinknode = [BibTeXLinkNodes objectAtIndex:i];
        
        NSString *hrefValue = [btlinknode stringValueOfAttribute:@"href"];
        
        
        NSURL *btURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@%@", [url host], hrefValue]];
        
        NSURLRequest *request = [NSURLRequest requestWithURL:btURL];
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
            
            // TODO: get a useful link for the URL field. 
            // each item's title looks like <span class="w"><a href="link">title</a></span>
            // but it'll take some xpath hacking to make sure we match title to bibtex link correctly.
            
            [items addObject:bibtexItem];
        }
        else {
            // display a fake item in the table so the user knows one of the items failed to parse, but still gets the rest of the data
            NSString *errMsg = NSLocalizedString(@"Unable to parse as BibTeX", @"google scholar error");
            NSDictionary *pubFields = [NSDictionary dictionaryWithObjectsAndKeys:errMsg, BDSKTitleString, [btURL absoluteString], BDSKUrlString, nil];
            BibItem *errorItem = [[BibItem alloc] initWithType:BDSKMiscString fileType:BDSKBibtexString citeKey:nil pubFields:pubFields isNew:YES];
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

@end 


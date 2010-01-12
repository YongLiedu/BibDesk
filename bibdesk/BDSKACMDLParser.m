//
//  BDSKACMDLParser.m
//
//  Created by Michael O. McCracken on 9/26/07.
/*
 This software is Copyright (c) 2007-2009
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

#import "BDSKACMDLParser.h"
#import <WebKit/WebKit.h>
#import "BibItem.h"
#import "BDSKBibTeXParser.h"
#import "NSError_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"

@implementation BDSKACMDLParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    if ([[url host] caseInsensitiveCompare:@"portal.acm.org"] != NSOrderedSame){
        return NO;
    }
    
    NSString *containsBibTexLinkNode = @"//a[contains(text(),'BibTeX')]";
    
    NSError *error = nil;    

    bool nodecountisok =  [[[xmlDocument rootElement] nodesForXPath:containsBibTexLinkNode error:&error] count] > 0;

    return nodecountisok;
}


// Despite the name, this method assumes there's only one bibitem to be had from the document. 
// A potential enhancement would be to recognize documents that are index lists of citations
// and follow links two levels deep to get bibitems from each citation in the list.

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
log_method();
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:0];
    
    
    NSString *BibTeXLinkNodePath = @"//a[contains(text(),'BibTeX')]";
    
    NSError *error = nil;    

    NSArray *BibTeXLinkNodes = [[xmlDocument rootElement] nodesForXPath:BibTeXLinkNodePath
                                                    error:&error];
    
    if ([BibTeXLinkNodes count] < 1) {
        if (outError) *outError = error;
        return nil;
    }
    
    NSXMLNode *btlinknode = [BibTeXLinkNodes objectAtIndex:0];
    NSString *onClickValue = [btlinknode stringValueOfAttribute:@"onclick"];

    // string should look like "window.open('.*');". Trim off the outer stuff:
    
    // check length in case this changes at some point in future, though!
    if ([onClickValue length] < 16) {
        if (outError) {
            *outError = [NSError localErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Window URL path string shorter than expected", @"ACM parser error")];
            return nil;
        }
    }
    
    NSString *bibTeXWindowURLPath = [onClickValue substringWithRange:NSMakeRange(13, [onClickValue length] - 13 - 3)];
    
    NSURL *btwinURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/%@", [url host], bibTeXWindowURLPath]];

    NSXMLDocument *btxmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:btwinURL
                                                                   options:NSXMLDocumentTidyHTML
                                                                     error:&error];
    [btxmlDoc autorelease];
    
    
    NSString *prePath = @".//pre";
    
    NSArray *preNodes = [[btxmlDoc rootElement] nodesForXPath:prePath
                                                           error:&error];
    if ([preNodes count] < 1) {
        if (outError) *outError = error;
        return nil;
    }
    
    // see http://portal.acm.org/citation.cfm?id=1185814&coll=Portal&dl=GUIDE&CFID=42263270&CFTOKEN=40475994#
    // which gives a bibtex string in two parts, each part enclosed in a <pre> tag (is it just me or does it look like a drunk made this site?)
    NSString *preString;
    if ([preNodes count] == 0)
        preString = [[preNodes objectAtIndex:0] stringValue];
    else
        preString = [[preNodes arrayByPerformingSelector:@selector(stringValue)] componentsJoinedByString:@" "];
    
    
    BOOL isPartialData = NO;
    
    NSArray* bibtexItems = [BDSKBibTeXParser itemsFromString:preString document:nil isPartialData:&isPartialData error:&error];
    if ([bibtexItems count] == 0){
        // display a fake item in the table rather than the annoying modal failure alert
        NSString *errMsg = NSLocalizedString(@"Unable to parse as BibTeX", @"google scholar error");
        NSDictionary *pubFields = [NSDictionary dictionaryWithObjectsAndKeys:errMsg, BDSKTitleString, nil];
        BibItem *errorItem = [[BibItem alloc] initWithType:BDSKMiscString fileType:BDSKBibtexString citeKey:nil pubFields:pubFields isNew:YES];
        [items addObject:errorItem];
        [errorItem release];
    }
    else {
        [items addObjectsFromArray:bibtexItems];
    }
    
    BibItem *bibtexItem = [items objectAtIndex:0]; 

    // Get the PDF URL, if possible:
    
    NSArray *pdfLinkNodes = [[xmlDocument rootElement] nodesForXPath:@"//a[contains(@name, 'FullText')]"
                                                               error:&error];
    if ([pdfLinkNodes count] > 0){
        NSXMLNode *pdfLinkNode = [pdfLinkNodes objectAtIndex:0];
        NSString *hrefValue = [pdfLinkNode stringValueOfAttribute:@"href"];
        
        NSString *pdfURLString = [NSString stringWithFormat:@"http://%@/%@", [url host], hrefValue];
        
        [bibtexItem setField:BDSKUrlString toValue:pdfURLString];
    }
    
    return items;  
    
}


+ (NSArray *) parserInfos {
	NSDictionary * parserInfos = [BDSKWebParser parserInfoWithName:@"ACM" address:@"http://portal.acm.org/" description:nil flags:BDSKParserFeatureNone];
	return [NSArray arrayWithObject:parserInfos];
}

@end 

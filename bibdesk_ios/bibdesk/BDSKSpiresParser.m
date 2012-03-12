//
//  BDSKSpiresParser.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 5/24/08.
/*
 This software is Copyright (c) 2008-2012
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKSpiresParser.h"
#import <WebKit/WebKit.h>
#import "BibItem.h"
#import "BDSKBibTeXParser.h"
#import "NSError_BDSKExtensions.h"
#import "NSXMLNode_BDSKExtensions.h"


@implementation BDSKSpiresParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    static NSArray *spiresHosts = nil;
    if (spiresHosts == nil)
        spiresHosts = [[NSArray alloc] initWithObjects:@"www.slac.stanford.edu", @"www-library.desy.de", @"www-spires.fnal.gov", @"usparc.ihep.su", @"www-spires.dur.ac.uk", @"www.yukawa.kyoto-u.ac.jp", @"www.spires.lipi.go.id", nil];
    
    NSString *host = [[url host] lowercaseString];
    
    if ([host isEqualToString:@"inspirebeta.net"] == NO && ([spiresHosts containsObject:host] == NO || [[url path] hasCaseInsensitivePrefix:@"/spires"] == NO))
        return NO;
    
    NSString *containsBibTexLinkNode = @"//a[contains(text(),'BibTeX')]"; 
    
    NSError *error = nil;    

    NSInteger nodecount = [[[xmlDocument rootElement] nodesForXPath:containsBibTexLinkNode error:&error] count];

    return nodecount > 0;
}


// Despite the name, this method assumes there's only one bibitem to be had from the document. 
// A potential enhancement would be to recognize documents that are index lists of citations
// and follow links two levels deep to get bibitems from each citation in the list.

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{

    NSMutableArray *items = [NSMutableArray arrayWithCapacity:0];
    
    
    NSString *BibTexLinkNodePath = @"//a[contains(text(),'BibTeX')]";
    
    NSError *error = nil;    

    NSArray *BibTeXLinkNodes = [[xmlDocument rootElement] nodesForXPath:BibTexLinkNodePath
                                                    error:&error];
        
    // bail out with an XML error if the Xpath query fails
    if (nil == BibTeXLinkNodes) {
        if (outError) *outError = error;
        return nil;
    }
    
    NSUInteger i, iMax = [BibTeXLinkNodes count];
    
    // check the number of nodes first
    if (0 == iMax) {
        error = [NSError mutableLocalErrorWithCode:kBDSKWebParserFailed localizedDescription:NSLocalizedString(@"No BibTeX links found", @"Spires error")];
        [error setValue:NSLocalizedString(@"Unable to parse this page.  Please report this to BibDesk's developers and provide the URL.", @"Spires error") forKey:NSLocalizedRecoverySuggestionErrorKey];
        if (outError) *outError = error;
        return nil;
    }
    
    for(i=0; i < iMax; i++){
        
        NSXMLNode *btlinknode = [BibTeXLinkNodes objectAtIndex:i];
        
        NSString *hrefValue = [btlinknode stringValueOfAttribute:@"href"];
        
        if ([hrefValue hasCaseInsensitivePrefix:@"http://"] == NO && [hrefValue hasCaseInsensitivePrefix:@"https://"] == NO)
            hrefValue = [NSString stringWithFormat:@"http://%@%@", [url host], hrefValue];
        
        NSURL *btURL = [NSURL URLWithString:hrefValue];
        
        NSXMLDocument *btXMLDoc = [[NSXMLDocument alloc] initWithContentsOfURL:btURL options:NSXMLDocumentTidyHTML error:&error];
        
        if (btXMLDoc) {
            
            NSArray *preNodes = [[btXMLDoc rootElement] nodesForXPath:@"//pre[contains(text(),'@')]" error:&error];
            NSString *bibTeXString = nil;
            
            if ([preNodes count])
                bibTeXString = [[preNodes objectAtIndex:0] stringValue];
            
            BOOL isPartialData = NO;
            NSArray* bibtexItems = nil;
            
            if (nil != bibTeXString)
                bibtexItems = [BDSKBibTeXParser itemsFromString:bibTeXString owner:nil isPartialData:&isPartialData error:&error];
            
            if ([bibtexItems count] && NO == isPartialData) {
                BibItem *bibtexItem = [bibtexItems objectAtIndex:0]; 
                
                [items addObject:bibtexItem];
            }
            
            [btXMLDoc release];
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



+ (NSDictionary *)parserInfo {
	NSString * parserDescription = NSLocalizedString(@"INSPIRE database of literature on particle physics.", @"Description for INSPIRE site");
	return [BDSKWebParser parserInfoWithName:@"INSPIRE" address:@"http://inspirebeta.net/"  description:parserDescription feature:BDSKParserFeaturePublic];
}


@end 

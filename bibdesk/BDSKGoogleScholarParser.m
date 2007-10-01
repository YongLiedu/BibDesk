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

@implementation BDSKGoogleScholarParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    if (! [[url host] isEqualToString:@"scholar.google.com"]){
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
        
    unsigned int i;
    for(i=0; i < [BibTeXLinkNodes count]; i++){
        
        NSXMLNode *btlinknode = [BibTeXLinkNodes objectAtIndex:i];
        
        NSString *hrefValue = [btlinknode stringValueOfAttribute:@"href"];
        
        
        NSURL *btURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@%@", [url host], hrefValue]];
        
        NSString *bibTeXString = [NSString stringWithContentsOfURL:btURL 
                                                          encoding:NSUTF8StringEncoding
                                                             error:&error];
        if (bibTeXString == nil){
            if (outError) *outError = error;
            return nil;
        }
        
        BOOL isPartialData = NO;
        
        NSArray* bibtexItems = [BDSKBibTeXParser itemsFromString:bibTeXString document:nil isPartialData:&isPartialData error:&error];
        
        if (bibtexItems == nil){
            if(outError) *outError = error;
            return nil;
        }
        
        BibItem *bibtexItem = [bibtexItems objectAtIndex:0]; 
        
        // TODO: get a useful link for the URL field. 
        // each item's title looks like <span class="w"><a href="link">title</a></span>
        // but it'll take some xpath hacking to make sure we match title to bibtex link correctly.
        
        [items addObject:bibtexItem];
        
    }
    
    return items;  
    
}

@end 


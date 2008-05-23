//
//  BDSKSpiresParser.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 24/5/08.
//  Copyright 2008 Christiaan Hofman. All rights reserved.
//

#import "BDSKSpiresParser.h"
#import <WebKit/WebKit.h>
#import "BibItem.h"
#import "BDSKBibTeXParser.h"
#import "NSError_BDSKExtensions.h"
#import "NSXMLNode_BDSKExtensions.h"


@implementation BDSKSpiresParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    if ([[url host] isEqualToString:@"www.slac.stanford.edu"] == NO || [[url path] hasPrefix:@"/spires"] == NO){
        return NO;
    }
    
    NSString *containsBibTexLinkNode = @"//a[contains(text(),'BibTeX')]"; 
    
    NSError *error = nil;    

    int nodecount = [[[xmlDocument rootElement] nodesForXPath:containsBibTexLinkNode error:&error] count];

    return nodecount > 0;
}


// Despite the name, this method assumes there's only one bibitem to be had from the document. 
// A potential enhancement would be to recognize documents that are index lists of citations
// and follow links two levels deep to get bibitems from each citation in the list.

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{log_method();

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
    
    unsigned int i, iMax = [BibTeXLinkNodes count];
    
    // check the number of nodes first
    if (0 == iMax) {
        error = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"No BibTeX links found", @"Spires error")];
        [error setValue:NSLocalizedString(@"Unable to parse this page.  Please report this to BibDesk's developers and provide the URL.", @"Spires error") forKey:NSLocalizedRecoverySuggestionErrorKey];
        if (outError) *outError = error;
        return nil;
    }
    
    for(i=0; i < iMax; i++){
        
        NSXMLNode *btlinknode = [BibTeXLinkNodes objectAtIndex:i];
        
        NSString *hrefValue = [btlinknode stringValueOfAttribute:@"href"];
        
        
        NSURL *btURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@%@", [url host], hrefValue]];
        
        NSXMLDocument *btXMLDoc = [[NSXMLDocument alloc] initWithContentsOfURL:btURL options:NSXMLDocumentTidyHTML error:&error];
        
        if (btXMLDoc) {
            
            NSArray *preNodes = [[btXMLDoc rootElement] nodesForXPath:@"//pre[contains(text(),'@')]" error:&error];
            NSString *bibTeXString = nil;
            
            if ([preNodes count])
                bibTeXString = [[preNodes objectAtIndex:0] stringValue];
            
            BOOL isPartialData = NO;
            NSArray* bibtexItems = nil;
            
            if (nil != bibTeXString)
                bibtexItems = [BDSKBibTeXParser itemsFromString:bibTeXString document:nil isPartialData:&isPartialData error:&error];
            
            if ([bibtexItems count] && NO == isPartialData) {
                BibItem *bibtexItem = [bibtexItems objectAtIndex:0]; 
                
                [items addObject:bibtexItem];
            }
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

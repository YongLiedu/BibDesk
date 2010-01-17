//
//  BDSKCiteULikeParser.m
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

#import "BDSKCiteULikeParser.h"
#import <WebKit/WebKit.h>
#import "BibItem.h"
#import "BDSKBibTeXParser.h"

@implementation BDSKCiteULikeParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    if ([[url host] caseInsensitiveCompare:@"www.citeulike.org"] != NSOrderedSame){
        return NO;
    }
    
    
    NSString *containsBibtexNode = @".//textarea[@id='bibtex-body']";
   
    NSError *error = nil;    

    bool nodecountisok =  [[[xmlDocument rootElement] nodesForXPath:containsBibtexNode error:&error] count] > 0;

    return nodecountisok;
}

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{

    NSMutableArray *items = [NSMutableArray arrayWithCapacity:0];
    
    
    NSString *bibtexPath = @".//textarea[@id='bibtex-body']";
    
    NSError *error = nil;    

    NSArray *bibtexNodes = [[xmlDocument rootElement] nodesForXPath:bibtexPath
                                                    error:&error];
    
    if ([bibtexNodes count] < 1) {
        if (outError) *outError = error;
        return nil;
    }
    
    NSString *preString = [[bibtexNodes objectAtIndex:0] stringValue];
    
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

    return items;  
    
}



+ (NSArray *) parserInfos {
	NSDictionary * parserInfo = [BDSKWebParser parserInfoWithName:@"CiteULike" address:@"http://www.citeulike.org/" description:nil flags: BDSKParserFeatureNone];
	return [NSArray arrayWithObject:parserInfo];
}


@end 


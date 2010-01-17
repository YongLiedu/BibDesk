//
//  BDSKHubmedParser.m
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

#import "BDSKHubmedParser.h"
#import <WebKit/WebKit.h>
#import "BibItem.h"
#import "BDSKBibTeXParser.h"
#import <AGRegex/AGRegex.h>

@implementation BDSKHubmedParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    if ([[url host] caseInsensitiveCompare:@"www.hubmed.org"] != NSOrderedSame){
        return NO;
    }
    
    if ([[url path] caseInsensitiveCompare:@"/display.cgi"] != NSOrderedSame){
        return NO;
    }
    
    return YES;
}


+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{

    NSMutableArray *items = [NSMutableArray arrayWithCapacity:0];
    

    // query is 'uids=<somenumber>':
    //    NSString *uidString = [[url query] substringWithRange:NSMakeRange(5, [[url query] length] - 5)];
    
    AGRegex *regex = [AGRegex regexWithPattern:@".*uids=([0-9]+).*"];
    AGRegexMatch *match = [regex findInString:[url query]];
    
    if(match == nil){
        return items;
    }
    
    NSString *uidString = [match groupAtIndex:1];
    
    NSError *error = nil;
    
    NSURL *btURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/export/bibtex.cgi?uids=%@&format=.txt", [url host], uidString]];

    NSString *bibTeXString = [NSString stringWithContentsOfURL:btURL 
                                                      encoding:NSUTF8StringEncoding
                                                         error:&error];
    if (bibTeXString == nil){
        if (outError) *outError = error;
        return nil;
    }
    
    BOOL isPartialData = NO;
    
    NSArray* bibtexItems = [BDSKBibTeXParser itemsFromString:bibTeXString
                                                    document:nil
                                               isPartialData:&isPartialData
                                                       error:&error];
    if (bibtexItems == nil){
        if(outError) *outError = error;
        return nil;
    }
    
    BibItem *bibtexItem = [bibtexItems objectAtIndex:0]; 

    // Get the fulltext URL:
    
    NSString *pdfURLString = [NSString stringWithFormat:@"http://%@/fulltext.cgi?uids=%@", [url host], uidString];
    
    [bibtexItem setField:BDSKUrlString toValue:pdfURLString];
    
    
    [items addObject:bibtexItem];
    return items;  
    
}




+ (NSArray *) parserInfos {
	NSString * parserDescription = NSLocalizedString(@"Alternative interface for queries to the PubMed database of medical literature.", @"Description for HubMed site");
	NSDictionary * parserInfo = [BDSKWebParser parserInfoWithName:@"HubMed" address:@"http://www.hubmed.org/" description:parserDescription flags: BDSKParserFeatureNone];
	
	return [NSArray arrayWithObject: parserInfo];
}

@end 


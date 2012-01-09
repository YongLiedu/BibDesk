//
//  BDSKMASParser.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/9/12.
/*
 This software is Copyright (c) 2012
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

#import "BDSKMASParser.h"
#import "BDSKBibTeXParser.h"
#import "BibItem.h"
#import "NSString_BDSKExtensions.h"
#import "NSXMLNode_BDSKExtensions.h"
#import <AGRegex/AGRegex.h>


@implementation BDSKMASParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    if (nil == [url host] || NO == [[url host] isCaseInsensitiveEqual:@"academic.research.microsoft.com"])
        return NO;
    
    NSError *error;
    NSArray *nodes = [xmlDocument nodesForXPath:@".//a[starts-with(@href,'Publication/')]" error:&error];
    
    if ([nodes count] == 0)
        nodes = [xmlDocument nodesForXPath:@".//a[starts-with(@href,'/Publication/')]" error:&error];
    
    return [nodes count] > 0;
}

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
	
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:1];
	
	NSError *error = nil;

    NSArray *nodes = [xmlDocument nodesForXPath:@".//a[starts-with(@href,'Publication/')]" error:&error];
    
    if ([nodes count] == 0) {
        nodes = [xmlDocument nodesForXPath:@".//a[starts-with(@href,'/Publication/')]" error:&error];
        if ([nodes count] == 0) {
            if (outError) *outError = error;
            return nil;
        }
    }
    
    for (NSXMLNode *node in nodes) {
        NSString *href = [node stringValueOfAttribute:@"href"];
        
        AGRegex *idRegex = [AGRegex regexWithPattern:@"^/?Publication/([0-9]*)/"];
        AGRegexMatch *match = [idRegex findInString:href];
        if ([match count] != 2)
            continue;
        
        NSString *publicationID = [match groupAtIndex:1];
        
        // download BibTeX data
        NSString *bibtexURLString = [NSString stringWithFormat:@"http://academic.research.microsoft.com/%@.bib?type=2&format=0", publicationID];
        NSURL *bibtexURL = [NSURL URLWithString:bibtexURLString];
        NSStringEncoding encoding = NSUTF8StringEncoding;
        NSString *bibtexString = [NSString stringWithContentsOfURL:bibtexURL usedEncoding:&encoding error:&error];
        
        if (bibtexString == nil)
            continue;
        
        NSArray *parsedItems = [BDSKBibTeXParser itemsFromString:[bibtexString stringWithPhoneyCiteKeys:[BibItem defaultCiteKey]] owner:nil isPartialData:NULL error:&error];
        if ([parsedItems count] > 0)
            [items addObjectsFromArray:parsedItems];
    }
    
    return items;
}

+ (NSDictionary *)parserInfo {
    NSString *parserDescription = NSLocalizedString(@"Microsoft Academic Search (MAS) is a free academic search engine developed by Microsoft Research.", @"Description for the MAS microformat");
	return [BDSKWebParser parserInfoWithName:@"MAS" address:@"http://academic.research.microsoft.com/" description:parserDescription feature:BDSKParserFeaturePublic];
}

@end

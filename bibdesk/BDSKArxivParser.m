//
//  BDSKArxivParser.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/16/09.
/*
 This software is Copyright (c) 2008-2010
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

#import "BDSKArxivParser.h"
#import "BibItem.h"
#import "NSError_BDSKExtensions.h"
#import "NSXMLNode_BDSKExtensions.h"
#import <AGRegex/AGRegex.h>


@implementation BDSKArxivParser

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    
    // !!! other countries end up with e.g. fr.arxiv.org; checking for scholar.arxiv.com may fail in those cases
    if (nil == [url host] ||  NO == [[[url host] lowercaseString] hasSuffix:@"arxiv.org"]){
        return NO;
    }
    
    BOOL isAbstract = [[[url path] lowercaseString] hasPrefix:@"/abs/"];
    NSString *containsArxivLinkNode = isAbstract ? @"//td[@class='tablecell arxivid']" : @"//span[@class='list-identifier']"; 
    
    NSError *error = nil;    

    NSInteger nodecount = [[[xmlDocument rootElement] nodesForXPath:containsArxivLinkNode error:&error] count];

    return nodecount > 0;
}


// Despite the name, this method assumes there's only one bibitem to be had from the document. 
// A potential enhancement would be to recognize documents that are index lists of citations
// and follow links two levels deep to get bibitems from each citation in the list.

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{

    NSMutableArray *items = [NSMutableArray arrayWithCapacity:0];
    
    BOOL isAbstract = [[[url path] lowercaseString] hasPrefix:@"/abs/"];
    
    NSString *arxivSearchResultNodePath = @"//dl/dt";
    
    NSString *arxivLinkNodePath = @".//span[@class='list-identifier']";
    NSString *arxivIDNodePath = @"./a[contains(text(),'arXiv:')]";
    NSString *pdfURLNodePath = @"./a[contains(text(),'pdf')]";
    
    NSString *titleNodePath = @".//div[@class='list-title']";
    NSString *authorsNodePath = @".//div[@class='list-authors']/a";
    NSString *journalNodePath = @".//div[@class='list-journal-ref']";
    NSString *abstractNodePath = @".//p";
    
    if (isAbstract) {
        arxivLinkNodePath = @".//td[@class='tablecell arxivid']";
        arxivIDNodePath = @"./a[contains(text(),'arXiv:')]";
        
        pdfURLNodePath = @".//div[@class='full-text']//a[contains(text(),'PDF')]";
        titleNodePath = @".//h1[@class='title']";
        authorsNodePath = @".//div[@class='authors']/a";
        journalNodePath = @".//td[@class='tablecell jref']";
        abstractNodePath = @".//blockquote[@class='abstract']";
    }
    
    AGRegex *eprintRegex1 = [AGRegex regexWithPattern:@"([0-9]{2})([0-9]{2})\\.([0-9]{4})"
                                              options:AGRegexMultiline];
    AGRegex *eprintRegex2 = [AGRegex regexWithPattern:@"([0-9]{2})([0-9]{2})([0-9]{3})"
                                              options:AGRegexMultiline];
    
    AGRegex *journalRegex1 = [AGRegex regexWithPattern:@"(.+) +([^ ]+) +\\(([0-9]{4})\\) +([^ ]+)"
                                               options:AGRegexMultiline];
    AGRegex *journalRegex2 = [AGRegex regexWithPattern:@"(.+[^0-9]) +([^ ]+), +([^ ]+) +\\(([0-9]{4})\\)"
                                               options:AGRegexMultiline];
    AGRegex *journalRegex3 = [AGRegex regexWithPattern:@"(.+[^0-9])([0-9]+):(.*),([0-9]{4})"
                                               options:AGRegexMultiline];
    
    NSError *error = nil;
            
    // fetch the arxiv search results
    NSArray *arxivSearchResults = nil;
    if (isAbstract)
        arxivSearchResults = [NSArray arrayWithObjects:[xmlDocument rootElement], nil];
    else
        arxivSearchResults = [[xmlDocument rootElement] nodesForXPath:arxivSearchResultNodePath error:&error];
    
    // bail out with an XML error if the Xpath query fails
    if (nil == arxivSearchResults) {
        if (outError) *outError = error;
        return nil;
    }    
    
    NSUInteger i, iMax = [arxivSearchResults count];
    
    // check the number of nodes first
    if (0 == iMax) {
        error = [NSError mutableLocalErrorWithCode:kBDSKWebParserFailed localizedDescription:NSLocalizedString(@"No search results found", @"ArXiv error")];
        [error setValue:NSLocalizedString(@"Unable to parse this page.  Please report this to BibDesk's developers and provide the URL.", @"ArXiv error") forKey:NSLocalizedRecoverySuggestionErrorKey];
        if (outError) *outError = error;
        return nil;
    }
        
    for(i = 0; i < iMax; i++){
        
        NSXMLNode *arxivSearchResult = [arxivSearchResults objectAtIndex:i];
        
        // fetch the arxiv links
        
        NSArray *arxivLinkNodes = [arxivSearchResult nodesForXPath:arxivLinkNodePath
                                                             error:&error];
        
        if (nil == arxivLinkNodes) {

            // This is an error since this method isn't supposed to be called if the bibtex
            // links don't appear on the page
            NSLog(@"ArXiv Error: unable to parse bibtex url from search result %lu due to xpath error", (unsigned long)i);
            continue;

        } else if (1 != [arxivLinkNodes count]) {

            // If Google ever start providing multiple alternative bibtex links for a
            // single item we will need to deal with that
            NSLog(@"ArXiv Error: unable to parse bibtex url from search result %lu, found %lu bibtex urls (expected 1)", (unsigned long)i, (unsigned long)[arxivLinkNodes count]);
            continue;

        }
        
        NSXMLNode *arxivLinkNode = [arxivLinkNodes objectAtIndex:0];
        NSXMLNode *arxivMetaNode = isAbstract ? arxivSearchResult : [arxivSearchResult nextSibling];
        NSArray *nodes;
        
        NSMutableDictionary *pubFields = [NSMutableDictionary dictionary];
        NSString *string = nil;
        
        // search for arXiv ID
        nodes = [arxivLinkNode nodesForXPath:arxivIDNodePath error:&error];
        if (nil != nodes && 1 == [nodes count]) {
            if (string = [[nodes objectAtIndex:0] stringValue]) {
                string = [string stringByRemovingSurroundingWhitespaceAndNewlines];
                if ([string hasCaseInsensitivePrefix:@"arXiv:"])
                    string = [string substringFromIndex:6];
                [pubFields setValue:string forKey:@"Eprint"];
            }
        }
        
        if (isAbstract)
            arxivLinkNode = arxivSearchResult;
        
        if (nil != nodes && 1 == [nodes count]) {
            // successfully found the result PDF url
            if (string = [[nodes objectAtIndex:0] stringValueOfAttribute:@"href"]) {
                // fix relative urls
                if (NO == [string hasCaseInsensitivePrefix:@"http"])
                    string = [[NSURL URLWithString:string relativeToURL:url] absoluteString];
                [pubFields setValue:string forKey:BDSKUrlString];
            }
        }
        
        // search for title
        nodes = [arxivMetaNode nodesForXPath:titleNodePath error:&error];
        if (nil != nodes && 1 == [nodes count]) {
            if (string = [[[nodes objectAtIndex:0] childAtIndex:1] stringValue]) {
                string = [string stringByRemovingSurroundingWhitespaceAndNewlines];
                [pubFields setValue:string forKey:BDSKTitleString];
            }
        }
        
        // search for authors
        nodes = [arxivMetaNode nodesForXPath:authorsNodePath error:&error];
        if (nil != nodes && 0 < [nodes count]) {
            if (string = [[nodes valueForKeyPath:@"stringValue.stringByRemovingSurroundingWhitespaceAndNewlines"] componentsJoinedByString:@" and "]) {
                [pubFields setValue:string forKey:BDSKAuthorString];
            }
        }
        
        // search for journal ref
        nodes = [arxivMetaNode nodesForXPath:journalNodePath error:&error];
        if (nil != nodes && 1 == [nodes count]) {
            NSXMLNode *journalRefNode = [nodes objectAtIndex:0];
            // actual journal ref comes after a span containing a label
            if ([journalRefNode childCount] > 1) {
                if (string = [[journalRefNode childAtIndex:1] stringValue]) {
                    string = [string stringByRemovingSurroundingWhitespaceAndNewlines];
                    // try to get full journal ref components, as "Journal Volume (Year) Pages"
                    AGRegexMatch *match = [journalRegex1 findInString:string];
                    if ([match groupAtIndex:0]) {
                        [pubFields setValue:[match groupAtIndex:1] forKey:BDSKJournalString];
                        [pubFields setValue:[match groupAtIndex:2] forKey:BDSKVolumeString];
                        [pubFields setValue:[match groupAtIndex:3] forKey:BDSKYearString];
                        [pubFields setValue:[match groupAtIndex:4] forKey:BDSKPagesString];
                    } else {
                        // try the old format "Journal Volume, Pages (Year)"
                        match = [journalRegex2 findInString:string];
                        if ([match groupAtIndex:0] == nil)
                            // try the old format "JournalVolume:Pages,Year"
                            match = [journalRegex3 findInString:string];
                        if ([match groupAtIndex:0]) {
                            [pubFields setValue:[match groupAtIndex:1] forKey:BDSKJournalString];
                            [pubFields setValue:[match groupAtIndex:2] forKey:BDSKVolumeString];
                            [pubFields setValue:[match groupAtIndex:3] forKey:BDSKPagesString];
                            [pubFields setValue:[match groupAtIndex:4] forKey:BDSKYearString];
                        } else {
                            // couldn't find expected format, just set everything in the Journal field
                            [pubFields setValue:string forKey:BDSKJournalString];
                        }
                    }
                }
            }
        }
        
        // search for abstract
        nodes = [arxivMetaNode nodesForXPath:abstractNodePath error:&error];
        if (nil != nodes && 1 == [nodes count]) {
            NSXMLNode *abstractNode = [nodes objectAtIndex:0];
            if (isAbstract && [abstractNode childCount] > 1)
                abstractNode = [abstractNode childAtIndex:1];
            if (string = [abstractNode stringValue]) {
                string = [string stringByRemovingSurroundingWhitespaceAndNewlines];
                [pubFields setValue:string forKey:BDSKAbstractString];
            }
        }
        
        // fill year+month from the arxiv ID if we did not get it from a journal
        if ([pubFields valueForKey:BDSKYearString] == nil && (string = [pubFields valueForKey:@"Eprint"])) {
            // try new format, yymm.nnnn
            AGRegexMatch *match = [eprintRegex1 findInString:string];
            if (string = [match groupAtIndex:1]) {
                [pubFields setValue:[@"20" stringByAppendingString:string] forKey:BDSKYearString];
                [pubFields setValue:[match groupAtIndex:2] forKey:BDSKMonthString];
            } else {
                // try old format, yymmnnn
                match = [eprintRegex2 findInString:string];
                if (string = [match groupAtIndex:1]) {
                    [pubFields setValue:[([string integerValue] < 90 ? @"20" : @"19") stringByAppendingString:string] forKey:BDSKYearString];
                    [pubFields setValue:[match groupAtIndex:2] forKey:BDSKMonthString];
                }
            }
        }
        
        // fill URL from arxiv ID if we did not find a link
        if ([pubFields valueForKey:BDSKUrlString] == nil && (string = [pubFields valueForKey:@"Eprint"])) {
            [pubFields setValue:[NSString stringWithFormat:@"http://%@/pdf/%@", [url host], string] forKey:BDSKUrlString];
        }
        
        BibItem *item = [[BibItem alloc] initWithType:BDSKArticleString citeKey:nil pubFields:pubFields isNew:YES];
        [items addObject:item];
        [item release];
        
    }
        
    if (0 == [items count]) {
        error = [NSError mutableLocalErrorWithCode:kBDSKWebParserFailed localizedDescription:NSLocalizedString(@"No search results found", @"ArXiv error")];
        [error setValue:NSLocalizedString(@"Unable to parse this page.  Please report this to BibDesk's developers and provide the URL.", @"ArXiv error") forKey:NSLocalizedRecoverySuggestionErrorKey];
        if (outError) *outError = error;
    }
    
    return items;  
    
}


+ (NSDictionary *)parserInfo {
	NSString * parserDescription = NSLocalizedString(@"E-Print archive used frequently in mathematics and physics but also containing sections for non-linear science, computer science, quantitative biology and statistics.", @"Description for arXiv site");
	return [BDSKWebParser parserInfoWithName:@"arXiv" address:@"http://arxiv.org/" description:parserDescription feature:BDSKParserFeaturePublic];
}

@end

//
//  BDSKDublinCoreXMLParser.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/31/06.
/*
 This software is Copyright (c) 2006-2010
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

#import "BDSKDublinCoreXMLParser.h"
#import "BibItem.h"
#import <AGRegex/AGRegex.h>


@interface NSString (BDSKDublinCoreXMLParserExtensions)
- (BOOL)isDublinCoreXMLString;
- (BOOL)isOAIDublinCoreXMLString;
@end


@implementation BDSKDublinCoreXMLParser

+ (BOOL)canParseString:(NSString *)string{
    return [string isDublinCoreXMLString] || [string isOAIDublinCoreXMLString];
}

static NSString *joinedArrayComponents(NSArray *arrayOfXMLNodes, NSString *separator)
{
    NSArray *strings = [arrayOfXMLNodes valueForKeyPath:@"stringValue"];
    return [strings componentsJoinedByString:separator];
}

static NSArray *dcProperties(NSXMLNode *node, NSString *key)
{
    NSArray *array = [node nodesForXPath:[NSString stringWithFormat:@"dc:%@", key] error:NULL];
    if ([array count] == 0)
        array = [node nodesForXPath:key error:NULL];
    return [array count] ? array : nil;
}

+ (NSArray *)itemsFromString:(NSString *)xmlString error:(NSError **)outError
{
    if (nil == xmlString)
        return [NSArray array];
    
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:xmlString options:0 error:outError];
    
    if (nil == doc && [xmlString hasPrefix:@"<?xml "] == NO) {
        xmlString = [NSString stringWithFormat:@"<?xml version=\"1.0\"?>\n<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\">%@\n</rdf:RDF>", xmlString];
        doc = [[NSXMLDocument alloc] initWithXMLString:xmlString options:0 error:outError];
    }
    if (nil == doc)
        return nil;
    
    NSXMLElement *root = [doc rootElement];
    
    BOOL isOAI = [xmlString isOAIDublinCoreXMLString];
    NSMutableArray *arrayOfPubs = [NSMutableArray array];
    NSArray *records = nil;
    
    if (isOAI) {
        records = [root nodesForXPath:@"//ListRecords/record/metadata" error:NULL];
    } else {
        records = [root nodesForXPath:@"//dc:dc-record" error:NULL];
        if ([records count] == 0)
            records = [root nodesForXPath:@"//dc-record" error:NULL];
        if ([records count] == 0)
            records = [root nodesForXPath:@"//record" error:NULL];
    }
    
    for (NSXMLNode *node in records) {
        
        // I don't know how to include "oai_dc:dc" in an XPath
        if (isOAI)
            node = [node childAtIndex:0];
        
        NSMutableDictionary *pubDict = [[NSMutableDictionary alloc] initWithCapacity:5];
        NSMutableArray *authors;
        NSArray *array;
        
        authors = [NSMutableArray array];
        [authors addObjectsFromArray:dcProperties(node, @"creator")];
        [authors addObjectsFromArray:dcProperties(node, @"contributor")];
        [pubDict setObject:joinedArrayComponents(authors, @" and ") forKey:BDSKAuthorString];
        
        // arm: most of these probably don't have to be arrays, at least for ADS
        if (array = dcProperties(node, @"title"))
        [pubDict setObject:joinedArrayComponents(array, @"; ") forKey:BDSKTitleString];
        
        if (array = dcProperties(node, @"subject"))
        [pubDict setObject:joinedArrayComponents(array, @"; ") forKey:BDSKKeywordsString];
        
        if (array = dcProperties(node, @"publisher"))
        [pubDict setObject:joinedArrayComponents(array, @"; ") forKey:BDSKPublisherString];
        
        if (array = dcProperties(node, @"location"))
        [pubDict setObject:joinedArrayComponents(array, @"; ") forKey:@"Location"];
        
        if (array = dcProperties(node, @"date"))
            [pubDict setObject:joinedArrayComponents(array, @"; ") forKey:BDSKDateString];

        if (array = dcProperties(node, @"description")) {
            NSString *cleanString = joinedArrayComponents(array, @"; ");
            cleanString = [cleanString stringByCollapsingAndTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (cleanString)
                [pubDict setObject:cleanString forKey:BDSKAbstractString];
        }
        
        if (array = dcProperties(node, @"relation"))
            [pubDict setObject:joinedArrayComponents(array, @"; ") forKey:BDSKUrlString];

        // ADS lumps Journal, Volume, Issue, pages into @"source", which is stupid;
        // for conferences, it adds date/location/editors as well, so this is hopeless.
        
        // using @"Note" field is more sensible, but probably less obvious to the user
        if (array = dcProperties(node, @"source"))
            [pubDict setObject:joinedArrayComponents(array, @"; ") forKey:BDSKJournalString];

        // this XML is a mess
        [pubDict setObject:[node XMLString] forKey:BDSKAnnoteString];

        // @article is most common for ADS
        BibItem *pub = [[BibItem alloc] initWithType:BDSKArticleString
                                            fileType:BDSKBibtexString 
                                             citeKey:nil 
                                           pubFields:pubDict 
                                               isNew:YES];
        [pubDict release];
        [arrayOfPubs addObject:pub];
        [pub release];
    }
    
    [doc release];
    return arrayOfPubs;
    
}

@end


@implementation NSString (BDSKDublinCoreXMLParserExtensions)

- (BOOL)isDublinCoreXMLString{
    AGRegex *regex = [AGRegex regexWithPattern:@"(<(dc:)?record-list>[ \t\n\r]*<(dc:)?dc-record>)|(<(dc:)?(dc-)?record>[ \t\n\r]*<dc:)"];
    
    return nil != [regex findInString:self];
}

- (BOOL)isOAIDublinCoreXMLString{
    AGRegex *regex = [AGRegex regexWithPattern:@"<OAI-PMH.*>[\n\r\t -~]*<metadata>[ \t\n\r]*<oai_dc:dc.*>[ \t\n\r]*<dc:"];
    
    return nil != [regex findInString:self];
}

@end

//
//  BDSKPubMedXMLParser.m
//  Bibdesk
//
//  Created by Adam Maxwell on 5/2/09.
/*
 This software is Copyright (c) 2009
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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

#import "BDSKPubMedXMLParser.h"
#import "BibItem.h"

/*
 See documentation at
 
 http://www.nlm.nih.gov/bsd/licensee/elements_descriptions.html
 
 */

@interface NSXMLNode (BDSKPubMedExtensions)
- (NSXMLNode *)firstNodeForXPath:(NSString *)xpath;
@end

@implementation NSXMLNode (BDSKPubMedExtensions)

- (NSXMLNode *)firstNodeForXPath:(NSString *)xpath;
{
    NSError *error;
    NSArray *nodes = [self nodesForXPath:xpath error:&error];
#ifdef OMNI_ASSERTIONS_ON
    if (nil == nodes) NSLog(@"Error for XPath %@: %@", xpath, error);
#endif
    return [nodes count] ? [nodes objectAtIndex:0] : nil;
}

@end


@implementation BDSKPubMedXMLParser

static bool _useTitlecase = true;
#ifdef OMNI_ASSERTIONS_ON
static bool _addXMLStringToAnnote = true;
#else
static bool _addXMLStringToAnnote = false;
#endif

+ (void)initialize
{
    // this is messy, but may be useful for debugging
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKAddPubMedXMLStringToAnnote"])
        _addXMLStringToAnnote = true;
    // try to allow for common titlecasing in PubMed (which gives us sentence case journal titles)
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKDisablePubMedXMLTitleCasing"])
        _useTitlecase = false;
}

+ (BOOL)canParseString:(NSString *)string;
{
    return [string rangeOfString:@"<!DOCTYPE PubmedArticleSet" options:NSCaseInsensitiveSearch].length > 0;
}

// convenience to avoid creating a local variable and checking it each time
static inline void addStringToDictionaryIfNotNil(NSString *value, NSString *key, NSMutableDictionary *dict)
{
    if (value) [dict setObject:[value stringByBackslashEscapingTeXSpecials] forKey:key];
}

// convenience to add the string value of a node; only adds if non-nil
static inline void addStringValueOfNodeForField(NSXMLNode *child, NSString *field, NSMutableDictionary *pubFields)
{
    addStringToDictionaryIfNotNil([child stringValue], field, pubFields);
}

+ (void)_addPubDateNode:(NSXMLNode *)dateNode toDictionary:(NSMutableDictionary *)pubFields
{
    NSEnumerator *compEnum = [[dateNode children] objectEnumerator];
    NSXMLNode *comp;
    
    while (comp = [compEnum nextObject]) {
        
        if ([[comp name] isEqualToString:@"Year"]) {
            addStringValueOfNodeForField(comp, BDSKYearString, pubFields);
        }
        else if ([[comp name] isEqualToString:@"Month"]) {
            addStringValueOfNodeForField(comp, BDSKMonthString, pubFields);
        }
        else if ([[comp name] isEqualToString:@"MedlineDate"]) {
            // this is a fallback mechanism
            addStringValueOfNodeForField(comp, BDSKDateString, pubFields);
            
            // first 4 digits should be a date
            NSScanner *scanner = [[NSScanner alloc] initWithString:[comp stringValue]];
            NSString *year;
            if ([scanner scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:&year] && [year length] == 4)
                addStringToDictionaryIfNotNil(year, BDSKYearString, pubFields);
            [scanner release];
        }
    }
}

+ (void)_addJournalNode:(NSXMLNode *)journalNode toDictionary:(NSMutableDictionary *)pubFields
{
    /*
     <Journal>
        <ISSN IssnType="Print">1821-6404</ISSN>
        <JournalIssue CitedMedium="Print">
            <Volume>10</Volume>
            <Issue>4</Issue>
            <PubDate>
                <Year>2008</Year>
                <Month>Oct</Month>
            </PubDate>
        </JournalIssue>
        <Title>Tanzania journal of health research</Title>
     </Journal>
     */
    
    NSEnumerator *nodeEnum = [[journalNode children] objectEnumerator];
    NSXMLNode *node;
    
    while (node = [nodeEnum nextObject]) {
        
        NSString *nodeName = [node name];
        
        if ([nodeName isEqualToString:@"Title"]) {
            addStringToDictionaryIfNotNil(_useTitlecase ? [[node stringValue] titlecaseString] : [node stringValue], BDSKJournalString, pubFields);
        }
        else if ([nodeName isEqualToString:@"JournalIssue"]) {
            
            NSEnumerator *childEnum = [[node children] objectEnumerator];
            NSXMLNode *child;
            
            while (child = [childEnum nextObject]) {
                NSString *childName = [child name];
                if ([childName isEqualToString:@"Volume"]) addStringValueOfNodeForField(child, BDSKVolumeString, pubFields);
                else if ([childName isEqualToString:@"Issue"]) addStringValueOfNodeForField(child, BDSKNumberString, pubFields);
                else if ([childName isEqualToString:@"PubDate"]) [self _addPubDateNode:child toDictionary:pubFields];
            }
        }
    }
}

+ (void)_addAuthorListNode:(NSXMLNode *)authorListNode toDictionary:(NSMutableDictionary *)pubFields
{    
    /*
        <AuthorList CompleteYN="Y">
            <Author ValidYN="Y">
                <LastName>Ezekiel</LastName>
                <ForeName>M J</ForeName>
                <Initials>MJ</Initials>
                <Suffix>Jr</Suffix>
            </Author>
        </AuthorList>
     
     NB: ForeName is the only key documented, but testing reveals FirstName may be used instead.
     nlmcommon_090101.dtd sez MiddleName may appear with FirstName as well.
     
     CollectiveName is for a corporate name, although it may be interspersed with other authors.  
     Enclose these in braces as a last name only.  See PMID 18084292 for an example.
     
     */
    
    NSMutableArray *authorNames = [NSMutableArray new];
    NSEnumerator *authorEnum = [[authorListNode children] objectEnumerator];
    NSXMLNode *authorNode;
    
    while (authorNode = [authorEnum nextObject]) {
        
        // this should always be true...
        if ([[authorNode name] isEqualToString:@"Author"]) {
            
            NSString *lastName = nil;
            NSString *firstName = nil;
            NSString *middleName = nil;
            NSString *suffix = nil;
            NSEnumerator *nameEnum = [[authorNode children] objectEnumerator];
            NSXMLNode *name;
            
            while (name = [nameEnum nextObject]) {
                
                NSString *nodeName = [name name];
                
                if ([nodeName isEqualToString:@"LastName"]) lastName = [name stringValue];
                else if ([nodeName isEqualToString:@"ForeName"] || [nodeName isEqualToString:@"FirstName"]) firstName = [name stringValue];
                else if ([nodeName isEqualToString:@"Suffix"]) suffix = [name stringValue];
                else if ([nodeName isEqualToString:@"MiddleName"]) middleName = [name stringValue];
                else if ([nodeName isEqualToString:@"CollectiveName"]) lastName = [NSString stringWithFormat:@"{%@}", [name stringValue]];
            }
            
            // normalized form for btparse: von Last, Jr, First Middle
            NSMutableString *fullName = [NSMutableString new];
            if (lastName) {
                [fullName appendString:lastName];
            }
            if (suffix) {
                if ([fullName isEqualToString:@""] == NO)
                    [fullName appendString:@", "];
                [fullName appendString:suffix];
            }
            if (firstName) {
                if ([fullName isEqualToString:@""] == NO)
                    [fullName appendString:@", "];
                [fullName appendString:firstName];
            }
            if (middleName) {
                // no comma for a middle name
                if ([fullName isEqualToString:@""] == NO)
                    [fullName appendString:@" "];
                // typically just an initial, but the .bst will handle any dot for abbreviationx
                [fullName appendString:middleName];
            }
            [authorNames addObject:fullName];
            [fullName release];
        }
        else {
            NSLog(@"Unknown node name %@ in %@", [authorNode name], authorListNode);
        }
    }
    
    if ([authorNames count])
        addStringToDictionaryIfNotNil([authorNames componentsJoinedByString:@" and "], BDSKAuthorString, pubFields);
    [authorNames release];
}

+ (void)_addMeshNode:(NSXMLNode *)listNode toDictionary:(NSMutableDictionary *)pubFields
{
    if ([[listNode children] count] == 0)
        return;

    NSMutableString *meshString = [NSMutableString new];
    NSString *keywordSeparator = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKDefaultGroupFieldSeparatorKey];
    NSEnumerator *meshEnum = [[listNode children] objectEnumerator];
    NSXMLNode *meshNode;

    while (meshNode = [meshEnum nextObject]) {
        if ([[meshNode name] isEqualToString:@"MeshHeading"]) {
            NSEnumerator *headingEnum = [[meshNode children] objectEnumerator];
            NSXMLNode *headingNode;
            
            while (headingNode = [headingEnum nextObject]) {
                
                // add descriptor name and ignore qualifier name
                if ([[headingNode name] isEqualToString:@"DescriptorName"]) {
                    if ([meshString length])
                        [meshString appendString:keywordSeparator];
                    [meshString appendString:[headingNode stringValue]];
                }
            }
        }
    }
    [pubFields setObject:meshString forKey:@"Mesh"];
    [meshString release];
}

+ (void)_addKeywordNode:(NSXMLNode *)listNode toDictionary:(NSMutableDictionary *)pubFields
{
    if ([[listNode children] count] == 0)
        return;
    
    NSMutableString *keywordString = [NSMutableString new];
    NSString *keywordSeparator = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKDefaultGroupFieldSeparatorKey];
    NSEnumerator *keywordEnum = [[listNode children] objectEnumerator];
    NSXMLNode *keywordNode;
    
    while (keywordNode = [keywordEnum nextObject]) {
        
        if ([[keywordNode name] isEqualToString:@"Keyword"]) {
            if ([keywordString length])
                [keywordString appendString:keywordSeparator];
            [keywordString appendString:[keywordNode stringValue]];
        }
    }
    [pubFields setObject:keywordString forKey:BDSKKeywordsString];
    [keywordString release];
}

+ (NSArray *)_itemsFromDocument:(NSXMLDocument *)doc error:(NSError **)outError;
{
    NSArray *articles = [doc nodesForXPath:@"//PubmedArticle" error:outError];
    NSMutableArray *pubs = [NSMutableArray array];
    NSEnumerator *articleEnum = [articles objectEnumerator];
    NSXMLNode *article;
    
    while (article = [articleEnum nextObject]) {
        
        NSXMLNode *citation = [article firstNodeForXPath:@"./MedlineCitation"];        
        NSMutableDictionary *pubFields = [NSMutableDictionary new];
        
        [self _addJournalNode:[citation firstNodeForXPath:@"./Article/Journal"] toDictionary:pubFields];
        [self _addAuthorListNode:[citation firstNodeForXPath:@"./Article/AuthorList"] toDictionary:pubFields];
        
        // ex. PMID 16187791
        [self _addMeshNode:[citation firstNodeForXPath:@"./MeshHeadingList"] toDictionary:pubFields];
        [self _addKeywordNode:[citation firstNodeForXPath:@"./KeywordList"] toDictionary:pubFields];
        
        NSString *title = [[citation firstNodeForXPath:@"./Article/ArticleTitle"] stringValue];
        addStringToDictionaryIfNotNil([title stringByRemovingSuffix:@"."], BDSKTitleString, pubFields);        
        addStringValueOfNodeForField([citation firstNodeForXPath:@"./Article/Abstract/AbstractText"], BDSKAbstractString, pubFields);
        addStringValueOfNodeForField([citation firstNodeForXPath:@"./Article/Pagination/MedlinePgn"], BDSKPagesString, pubFields);
        addStringValueOfNodeForField([citation firstNodeForXPath:@"./PMID"], @"Pmid", pubFields);
        
        // grab the DOI if available
        NSArray *articleIDs = [article nodesForXPath:@"./PubmedData/ArticleIdList/ArticleId" error:NULL];
        NSEnumerator *articleIDEnum = [articleIDs objectEnumerator];
        NSXMLElement *articleID;
        
        while (articleID = [articleIDEnum nextObject]) {
            if ([articleID kind] == NSXMLElementKind && [[[articleID attributeForName:@"IdType"] stringValue] isEqualToString:@"doi"])
                addStringValueOfNodeForField(articleID, BDSKDoiString, pubFields);
        }
        
        
        // for debugging
        if (_addXMLStringToAnnote) addStringToDictionaryIfNotNil([article XMLStringWithOptions:NSXMLNodePrettyPrint], BDSKAnnoteString, pubFields);
        
        BibItem *pub = [[BibItem allocWithZone:[self zone]] initWithType:BDSKArticleString
                                                                fileType:BDSKBibtexString
                                                                 citeKey:nil
                                                               pubFields:pubFields
                                                                   isNew:YES];
        [pubs addObject:pub];
        [pub release];
        [pubFields release];
    }
    
    return pubs;    
}

+ (NSArray *)itemsFromString:(NSString *)itemString error:(NSError **)outError;
{
    NSXMLDocument *doc = [[NSXMLDocument allocWithZone:[self zone]] initWithXMLString:itemString options:NSXMLNodeOptionsNone error:outError];
    doc = [doc autorelease];
    return doc ? [self _itemsFromDocument:doc error:outError] : nil;
}

+ (NSArray *)itemsFromData:(NSData *)itemData error:(NSError **)outError;
{
    NSXMLDocument *doc = [[NSXMLDocument allocWithZone:[self zone]] initWithData:itemData options:NSXMLNodeOptionsNone error:outError];
    doc = [doc autorelease];
    return doc ? [self _itemsFromDocument:doc error:outError] : nil;
}

@end

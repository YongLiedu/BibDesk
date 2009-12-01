//
//  BDSKItemSearchIndexes.m
//  Bibdesk
//
//  Created by Adam Maxwell on 04/06/07.
/*
 This software is Copyright (c) 2007-2009
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

#import "BDSKItemSearchIndexes.h"
#import "BibAuthor.h"
#import "BibItem.h"

static CFStringRef searchIndexCopyDescription(const void *value)
{
    CFStringRef cfDesc = CFCopyDescription(value);
    CFStringRef desc = (CFStringRef)[[NSString alloc] initWithFormat:@"%@: type %ld, %ld documents", cfDesc, (long)SKIndexGetIndexType((SKIndexRef)value), (long)SKIndexGetDocumentCount((SKIndexRef)value)];
    CFRelease(cfDesc);
    return desc;
}

@implementation BDSKItemSearchIndexes

+ (NSSet *)indexedFields;
{
    // file content is also indexed, but it's handled by a separate object (BDSKFileSearchIndex) and controller, since it's threaded
    static NSSet *indexedFields = nil;
    if (nil == indexedFields)
        indexedFields = [[NSSet alloc] initWithObjects:BDSKAllFieldsString, BDSKTitleString, BDSKPersonString, nil];
    return indexedFields;
}

- (id)init
{
    self = [super init];
    if (self) {
        
        // Note: SKIndexClose() is supposed to dispose of indexes, which was the original reason for using these custom callbacks.  However, it leaks on both Tiger and Leopard unless you're using GC on Leopard.  For non-GC apps, we need to use CFRelease() on Leopard, according to the response to my bug report on the leaks.  This is still not documented, though.
        CFDictionaryValueCallBacks dcb = kCFTypeDictionaryValueCallBacks;
        dcb.copyDescription = searchIndexCopyDescription;
        searchIndexes = CFDictionaryCreateMutable(NULL, 0, &kCFCopyStringDictionaryKeyCallBacks, &dcb);        
        
        // pointer equality set
        CFSetCallBacks scb = kCFTypeSetCallBacks;
        scb.copyDescription = searchIndexCopyDescription;
        scb.equal = NULL;
        scb.hash = NULL;
        indexesToFlush = CFSetCreateMutable(NULL, 0, &scb);
        
        // ensure that we never hand out a NULL search index unless someone asks for a field that isn't indexed
        [self resetWithPublications:nil];
    }
    return self;
}

- (void)dealloc
{
    BDSKCFDESTROY(searchIndexes);
    BDSKCFDESTROY(indexesToFlush);
    [super dealloc];
}

static void addIndexToSet(const void *key, const void *value, void *context)
{
    CFSetAddValue((CFMutableSetRef)context, (SKIndexRef)value);
}

// Index flushing is fairly expensive, especially with thousands of pubs added; here we just mark all indexes as dirty (which is negligible) and flush each index when requested.
- (void)scheduleIndexFlush
{
    CFSetRemoveAllValues(indexesToFlush);
    CFDictionaryApplyFunction(searchIndexes, addIndexToSet, indexesToFlush);    
}

static void appendNormalizedNames(const void *value, void *context)
{
    BibAuthor *person = (BibAuthor *)value;
    NSMutableString *names = (NSMutableString *)context;
    if ([names isEqualToString:@""] == NO)
        [names appendString:@" "];
    [names appendString:[[person normalizedName] stringByRemovingCurlyBraces]];
}

- (void)addPublications:(NSArray *)pubs;
{
    for (BibItem *pub in pubs) {
        SKDocumentRef doc = SKDocumentCreateWithURL((CFURLRef)[pub identifierURL]);
        if (doc) {
            
            // ARM: I thought Search Kit was supposed to ignore some punctuation, but it matches curly braces (bug #1762014).  Since Title is the field most likely to have specific formatting commands, we'll remove all TeX from it, but the commands shouldn't affect search results anyway unless the commands split words.  For the allFieldsString, we'll just remove curly braces to save time, and pollute the index with a few commands.
            
            NSString *searchText = [[pub allFieldsString] stringByRemovingCurlyBraces];
            
            SKIndexRef skIndex = (void *)CFDictionaryGetValue(searchIndexes, BDSKAllFieldsString);
            if (searchText && skIndex)
                SKIndexAddDocumentWithText(skIndex, doc, (CFStringRef)searchText, TRUE);
            
            searchText = [[pub title] stringByRemovingTeX];
            skIndex = (void *)CFDictionaryGetValue(searchIndexes, BDSKTitleString);
            if (searchText && skIndex)
                SKIndexAddDocumentWithText(skIndex, doc, (CFStringRef)searchText, TRUE);
            
            // just remove curly braces from names
            NSMutableString *names = [[NSMutableString alloc] initWithCapacity:100];
            CFSetApplyFunction((CFSetRef)[pub allPeople], appendNormalizedNames, names);
            skIndex = (void *)CFDictionaryGetValue(searchIndexes, BDSKPersonString);
            if (skIndex)
                SKIndexAddDocumentWithText(skIndex, doc, (CFStringRef)names, TRUE);  
            [names release];
            
            CFRelease(doc);
        }
        
    }
    
    [self scheduleIndexFlush];
}

static void removeFromIndex(const void *key, const void *value, void *context)
{
    SKDocumentRef doc = (SKDocumentRef)context;
    SKIndexRemoveDocument((SKIndexRef)value, doc);
}

- (void)removePublications:(NSArray *)pubs;
{
    for (BibItem *pub in pubs) {
        SKDocumentRef doc = SKDocumentCreateWithURL((CFURLRef)[pub identifierURL]);
        if (doc) {
            CFDictionaryApplyFunction(searchIndexes, removeFromIndex, (void *)doc);
            CFRelease(doc);
        }
    }
    [self scheduleIndexFlush];
}

- (void)resetWithPublications:(NSArray *)pubs;
{
    
    CFDictionaryRemoveAllValues(searchIndexes);
    CFSetRemoveAllValues(indexesToFlush);
    
    CFMutableDataRef indexData;
    SKIndexRef skIndex;
    
    // Search Kit defaults to indexing the first 2000 terms.  This is almost never what we want for BibItem searching, so set it to be unlimited (zero, of course).
    NSDictionary *options = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInteger:0], (id)kSKMaximumTerms, nil];
    for (NSString *fieldName in [[self class] indexedFields]) {
        indexData = CFDataCreateMutable(NULL, 0);
        skIndex = SKIndexCreateWithMutableData(indexData, (CFStringRef)fieldName, kSKIndexInverted, (CFDictionaryRef)options);
        CFDictionaryAddValue(searchIndexes, (CFStringRef)fieldName, skIndex);
        CFRelease(indexData);
        CFRelease(skIndex);
    }
    [options release];
    
    // this will handle the index flush after adding all the pubs
    [self addPublications:pubs];
}

- (SKIndexRef)indexForField:(NSString *)field;
{
    NSParameterAssert(nil != field);
    SKIndexRef anIndex = (SKIndexRef)CFDictionaryGetValue(searchIndexes, (CFStringRef)field);
    if (CFSetContainsValue(indexesToFlush, anIndex)) {
        SKIndexFlush(anIndex);
        CFSetRemoveValue(indexesToFlush, anIndex);
    }
    return (SKIndexRef)[[(id)anIndex retain] autorelease];
}

@end

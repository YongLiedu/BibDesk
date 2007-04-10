//
//  BDSKItemSearchIndexes.m
//  Bibdesk
//
//  Created by Adam Maxwell on 04/06/07.
/*
 This software is Copyright (c) 2007
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

static CFTypeRef searchIndexDictionaryRetain(CFAllocatorRef alloc, const void *value) { return CFRetain(value); }
static void searchIndexDictionaryRelease(CFAllocatorRef alloc, const void *value) { SKIndexClose((SKIndexRef)value); }
static CFStringRef searchIndexDictionaryCopyDescription(const void *value)
{
    CFStringRef cfDesc = CFCopyDescription(value);
    CFStringRef desc = (CFStringRef)[[NSString alloc] initWithFormat:@"%@: type %d, %d documents", cfDesc, SKIndexGetIndexType((SKIndexRef)value), SKIndexGetDocumentCount((SKIndexRef)value)];
    CFRelease(cfDesc);
    return desc;
}
static Boolean searchIndexDictionaryEqual(const void *value1, const void *value2) { return CFEqual(value1, value2); }

const CFDictionaryValueCallBacks BDSKSearchIndexDictionaryValueCallBacks = {
    0,
    searchIndexDictionaryRetain,
    searchIndexDictionaryRelease,
    searchIndexDictionaryCopyDescription,
    searchIndexDictionaryEqual
};

@implementation BDSKItemSearchIndexes

+ (NSSet *)indexedFields;
{
    static NSSet *indexedFields = nil;
    if (nil == indexedFields)
        indexedFields = [[NSSet alloc] initWithObjects:BDSKAllFieldsString, BDSKTitleString, BDSKPersonString, @"SkimNotes", nil];
    return indexedFields;
}

- (id)init
{
    self = [super init];
    if (self) {
        searchIndexes = CFDictionaryCreateMutable(NULL, 0, &kCFCopyStringDictionaryKeyCallBacks, &BDSKSearchIndexDictionaryValueCallBacks);
        
        // ensure that we never hand out a NULL search index unless someone asks for a field that isn't indexed
        [self resetWithPublications:nil];
    }
    return self;
}

- (void)dealloc
{
    CFRelease(searchIndexes);
    [super dealloc];
}

static void flushAllIndexes(const void *key, const void *value, void *context)
{
    SKIndexFlush((SKIndexRef)value);
}

static void appendNormalizedNames(const void *value, void *context)
{
    BibAuthor *person = (BibAuthor *)value;
    NSMutableString *names = (NSMutableString *)context;
    if ([names isEqualToString:@""] == NO)
        [names appendString:@" "];
    [names appendString:[person normalizedName]];
}

- (void)addPublications:(NSArray *)pubs;
{
    
    NSEnumerator *pubsEnum = [pubs objectEnumerator];
    BibItem *pub;
    NSMutableString *names = [[NSMutableString alloc] initWithCapacity:100];
    
    while (pub = [pubsEnum nextObject]) {
        SKDocumentRef doc = SKDocumentCreateWithURL((CFURLRef)[pub identifierURL]);
        if (doc) {
            NSString *searchText = [pub allFieldsString];
            SKIndexRef skIndex = (void *)CFDictionaryGetValue(searchIndexes, BDSKAllFieldsString);
            if (searchText && skIndex)
                SKIndexAddDocumentWithText(skIndex, doc, (CFStringRef)searchText, TRUE);
            
            searchText = [pub title];
            skIndex = (void *)CFDictionaryGetValue(searchIndexes, BDSKTitleString);
            if (searchText && skIndex)
                SKIndexAddDocumentWithText(skIndex, doc, (CFStringRef)searchText, TRUE);
            
            [names replaceCharactersInRange:NSMakeRange(0, [names length]) withString:@""];
            CFSetApplyFunction((CFSetRef)[pub allPeople], appendNormalizedNames, names);
            skIndex = (void *)CFDictionaryGetValue(searchIndexes, BDSKPersonString);
            if (skIndex)
                SKIndexAddDocumentWithText(skIndex, doc, (CFStringRef)names, TRUE);  
            
            searchText = [pub skimNotesForLocalURL];
            skIndex = (void *)CFDictionaryGetValue(searchIndexes, CFSTR("SkimNotes"));
            if (searchText && skIndex)
                SKIndexAddDocumentWithText(skIndex, doc, (CFStringRef)searchText, TRUE);
            
            CFRelease(doc);
        }
        
    }
    
    [names release];
    CFDictionaryApplyFunction(searchIndexes, flushAllIndexes, NULL);
}

static void removeFromIndex(const void *key, const void *value, void *context)
{
    SKDocumentRef doc = (SKDocumentRef)context;
    SKIndexRemoveDocument((SKIndexRef)value, doc);
}

- (void)removePublications:(NSArray *)pubs;
{
    NSEnumerator *pubsEnum = [pubs objectEnumerator];
    BibItem *pub;
    while (pub = [pubsEnum nextObject]) {
        SKDocumentRef doc = SKDocumentCreateWithURL((CFURLRef)[pub identifierURL]);
        if (doc) {
            CFDictionaryApplyFunction(searchIndexes, removeFromIndex, doc);
            CFRelease(doc);
        }
    }
    CFDictionaryApplyFunction(searchIndexes, flushAllIndexes, NULL);
}

- (void)resetWithPublications:(NSArray *)pubs;
{
    
    CFDictionaryRemoveAllValues(searchIndexes);
    
    CFMutableDataRef indexData;
    SKIndexRef skIndex;
    NSEnumerator *fieldEnum = [[[self class] indexedFields] objectEnumerator];
    NSString *fieldName;
    while (fieldName = [fieldEnum nextObject]) {
        indexData = CFDataCreateMutable(NULL, 0);
        skIndex = SKIndexCreateWithMutableData(indexData, (CFStringRef)fieldName, kSKIndexInverted, NULL);
        CFDictionaryAddValue(searchIndexes, (CFStringRef)fieldName, skIndex);
        CFRelease(indexData);
        CFRelease(skIndex);
    }
    
    // this will handle the index flush after adding all the pubs
    [self addPublications:pubs];
}

- (SKIndexRef)indexForField:(NSString *)field;
{
    return (SKIndexRef)CFDictionaryGetValue(searchIndexes, (CFStringRef)field);
}

@end

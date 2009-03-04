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

static CFTypeRef searchIndexDictionaryRetain(CFAllocatorRef alloc, const void *value) { return CFRetain(value); }
// Note: SKIndexClose() is supposed to dispose of indexes.  However, it leaks on both Tiger and Leopard unless you're using GC on Leopard.  For non-GC apps, we need to use CFRelease() on Leopard, according to the response to my bug report on the leaks.  This is still not documented, though.
static void searchIndexDictionaryRelease(CFAllocatorRef alloc, const void *value) { CFRelease((SKIndexRef)value); }
static CFStringRef searchIndexDictionaryCopyDescription(const void *value)
{
    CFStringRef cfDesc = CFCopyDescription(value);
    CFStringRef desc = (CFStringRef)[[NSString alloc] initWithFormat:@"%@: type %d, %d documents", cfDesc, SKIndexGetIndexType((SKIndexRef)value), SKIndexGetDocumentCount((SKIndexRef)value)];
    CFRelease(cfDesc);
    return desc;
}
static Boolean searchIndexDictionaryEqual(const void *value1, const void *value2) { return CFEqual(value1, value2); }

const CFDictionaryValueCallBacks kBDSKSearchIndexDictionaryValueCallBacks = {
    0, // version
    searchIndexDictionaryRetain,
    searchIndexDictionaryRelease,
    searchIndexDictionaryCopyDescription,
    searchIndexDictionaryEqual
};

const CFSetCallBacks kBDSKSearchIndexSetCallBacks = {
    0,    // version
    NULL, // retain
    NULL, // release
    searchIndexDictionaryCopyDescription,
    NULL  // equal
};

@implementation BDSKItemSearchIndexes

+ (NSSet *)indexedFields;
{
    // file content is also indexed, but it's handled by a separate object (BDSKFileSearchIndex) and controller, since it's threaded
    static NSSet *indexedFields = nil;
    if (nil == indexedFields)
        indexedFields = [[NSSet alloc] initWithObjects:BDSKAllFieldsString, BDSKTitleString, BDSKPersonString, BDSKSkimNotesString, nil];
    return indexedFields;
}

- (id)init
{
    self = [super init];
    if (self) {
        searchIndexes = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFCopyStringDictionaryKeyCallBacks, &kBDSKSearchIndexDictionaryValueCallBacks);
        
        // pointer equality, nonretained; indexes are retained by the dictionary
        indexesToFlush = CFSetCreateMutable(kCFAllocatorDefault, 0, &kBDSKSearchIndexSetCallBacks);
        
        // ensure that we never hand out a NULL search index unless someone asks for a field that isn't indexed
        [self resetWithPublications:nil];
    }
    return self;
}

- (void)dealloc
{
    CFRelease(searchIndexes);
    CFRelease(indexesToFlush);
    [super dealloc];
}

static void addIndexToSet(const void *key, const void *value, void *context)
{
    CFSetAddValue((CFMutableSetRef)context, (SKIndexRef)value);
}

// Index flushing is fairly expensive, especially with thousands of pubs added; here we just mark all indexes as dirty (which is negligible) and flush each index when requested.
- (void)scheduleIndexFlush
{
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
    NSEnumerator *pubsEnum = [pubs objectEnumerator];
    BibItem *pub;
    
    while (pub = [pubsEnum nextObject]) {
        SKDocumentRef doc = SKDocumentCreateWithURL((CFURLRef)[pub identifierURL]);
        if (doc) {
            
            // ARM: I thought Search Kit was supposed to ignore some punctuation, but it matches curly braces (bug #1762014).  Since Title is the field most likely to have specific formatting commands, we'll remove all TeX from it, but the commands shouldn't affect search results anyway unless the commands split words.  For the allFieldsString, we'll just remove curly braces to save time, and pollute the index with a few commands.
            
            // shouldn't be any TeX junk to remove from these
            NSString *skimNotes = [pub skimNotesForLocalURL];
            
            NSString *searchText = [[pub allFieldsString] stringByRemovingCurlyBraces];
            
            // add Skim notes to all fields string as well
            if (skimNotes)
                searchText = [searchText stringByAppendingFormat:@" %@", skimNotes];
            
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
            
            skIndex = (void *)CFDictionaryGetValue(searchIndexes, (CFStringRef)BDSKSkimNotesString);
            if (skimNotes && skIndex)
                SKIndexAddDocumentWithText(skIndex, doc, (CFStringRef)skimNotes, TRUE);
            
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
    NSEnumerator *pubsEnum = [pubs objectEnumerator];
    BibItem *pub;
    while (pub = [pubsEnum nextObject]) {
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
    
    CFMutableDataRef indexData;
    SKIndexRef skIndex;
    NSEnumerator *fieldEnum = [[[self class] indexedFields] objectEnumerator];
    NSString *fieldName;
    
    // Search Kit defaults to indexing the first 2000 terms.  This is almost never what we want for BibItem searching, so set it to be unlimited (zero, of course).
    NSDictionary *options = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInt:0], (id)kSKMaximumTerms, nil];
    while (fieldName = [fieldEnum nextObject]) {
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
    return anIndex;
}

@end

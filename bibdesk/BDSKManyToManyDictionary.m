//
//  BDSKManyToManyDictionary.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/18/08.
/*
 This software is Copyright (c) 2008-2012
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
 
 - Neither the name of  Christiaan Hofman nor the names of any
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

#import "BDSKManyToManyDictionary.h"


@implementation BDSKManyToManyDictionary

- (id)init {
    self = [super init];
    if (self) {
        dictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        inverseDictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    }
    return self;
}

- (void)dealloc {
    BDSKCFDESTROY(dictionary);
    BDSKCFDESTROY(inverseDictionary);
    [super dealloc];
}

- (NSString *)description {
    return [(id)dictionary description];
}

- (CFMutableDictionaryRef)_dictionary:(BOOL)inverse {
    return inverse ? inverseDictionary : dictionary;
}

- (NSMutableSet *)_setForValue:(id)aValue inverse:(BOOL)inverse create:(BOOL)create {
    CFMutableDictionaryRef dict = [self _dictionary:inverse];
    NSMutableSet *value = (NSMutableSet *)CFDictionaryGetValue(dict, aValue);

    if (create && value == nil) {
        value = [[NSMutableSet alloc] init];
        CFDictionaryAddValue(dict, aValue, value);
        [value release];
    }
    return value;
}

- (NSUInteger)keyCount {
    return CFDictionaryGetCount(dictionary);
}

- (NSUInteger)objectCount {
    return CFDictionaryGetCount(inverseDictionary);
}

- (NSUInteger)countForKey:(id)aKey {
    return [[self _setForValue:aKey inverse:NO create:NO] count];
}

- (NSUInteger)countForObject:(id)anObject {
    return [[self _setForValue:anObject inverse:YES create:NO] count];
}

- (NSSet *)allObjectsForKey:(id)aKey {
    return [self _setForValue:aKey inverse:NO create:NO];
}

- (NSSet *)allKeysForObject:(id)anObject {
    return [self _setForValue:anObject inverse:YES create:NO];
}

- (id)anyObjectForKey:(id)aKey {
    return [[self _setForValue:aKey inverse:NO create:NO] anyObject];
}

- (id)anyKeyForObject:(id)anObject {
    return [[self _setForValue:anObject inverse:YES create:NO] anyObject];
}

- (void)addObject:(id)anObject forKey:(id)aKey {
    [[self _setForValue:aKey inverse:NO create:YES] addObject:anObject];
    [[self _setForValue:anObject inverse:YES create:YES] addObject:aKey];
}

typedef struct _addValueContext {
    BDSKManyToManyDictionary *dict;
    id value;
    BOOL inverse;
} addValueContext;

static void addValueFunction(const void *value, void *context) {
    addValueContext *ctxt = context;
    [[ctxt->dict _setForValue:(id)value inverse:ctxt->inverse create:YES] addObject:(id)(ctxt->value)];
}

- (void)addObjects:(NSSet *)newObjects forKey:(id)aKey {
    if ([newObjects count]) {
        [[self _setForValue:aKey inverse:NO create:YES] unionSet:newObjects];
        addValueContext ctxt;
        ctxt.dict = self;
        ctxt.value = aKey;
        ctxt.inverse = YES;
        CFSetApplyFunction((CFSetRef)newObjects, addValueFunction, &ctxt);
    }
}

- (void)addObject:(id)anObject forKeys:(NSSet *)newKeys {
    if ([newKeys count]) {
        [[self _setForValue:anObject inverse:YES create:YES] unionSet:newKeys];
        addValueContext ctxt;
        ctxt.dict = self;
        ctxt.value = anObject;
        ctxt.inverse = NO;
        CFSetApplyFunction((CFSetRef)newKeys, addValueFunction, &ctxt);
    }
}

- (void)removeObject:(id)anObject forKey:(id)aKey{
    NSMutableSet *objectSet = [self _setForValue:aKey inverse:NO create:NO];
    NSMutableSet *keySet = [self _setForValue:anObject inverse:YES create:NO];
    if (objectSet) {
        [objectSet removeObject:anObject];
        if ([objectSet count] == 0)
            CFDictionaryRemoveValue(dictionary, aKey);
    }
    if (keySet) {
        [keySet removeObject:anObject];
        if ([keySet count] == 0)
            CFDictionaryRemoveValue(inverseDictionary, anObject);
    }
}

- (void)removeAllObjects {
    CFDictionaryRemoveAllValues(dictionary);
    CFDictionaryRemoveAllValues(inverseDictionary);
}

static void addEntryFunction(const void *key, const void *value, void *context) {
    addValueContext *ctxt = context;
    [[ctxt->dict _setForValue:(id)key inverse:ctxt->inverse create:YES] unionSet:(NSSet *)value];
}

- (void)addEntriesFromDictionary:(BDSKManyToManyDictionary *)otherDictionary {
    addValueContext ctxt;
    ctxt.dict = self;
    ctxt.value = nil;
    ctxt.inverse = NO;
    CFDictionaryApplyFunction([otherDictionary _dictionary:NO], addEntryFunction, &ctxt);
    ctxt.inverse = YES;
    CFDictionaryApplyFunction([otherDictionary _dictionary:YES], addEntryFunction, &ctxt);
}

@end

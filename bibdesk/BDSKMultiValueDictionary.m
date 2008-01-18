//
//  BDSKMultiValueDictionary.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/18/08.
/*
 This software is Copyright (c)2008
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

#import "BDSKMultiValueDictionary.h"


@implementation BDSKMultiValueDictionary

- (id)init {
    if (self = [super init]) {
        dictionary = [[NSMutableDictionary alloc] init];
        inverseDictionary = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc {
    [dictionary release];
    [inverseDictionary release];
    [super dealloc];
}

- (NSString *)description {
    return [dictionary description];
}

- (unsigned int)count {
    return [dictionary count];
}

- (NSMutableSet *)_setForKey:(id)aKey create:(BOOL)create {
    NSMutableSet *value = [dictionary objectForKey:aKey];

    if (create && value == nil) {
        value = [[NSMutableSet alloc] init];
        [dictionary setObject:value forKey:aKey];
        [value release];
    }
    return value;
}

- (NSMutableSet *)_setForObject:(id)anObject create:(BOOL)create {
    NSMutableSet *value = [inverseDictionary objectForKey:anObject];

    if (create && value == nil) {
        value = [[NSMutableSet alloc] init];
        [inverseDictionary setObject:value forKey:anObject];
        [value release];
    }
    return value;
}

- (NSSet *)allObjectsForKey:(id)aKey {
    return [self _setForKey:aKey create:NO];
}

- (NSSet *)allKeysForObject:(id)anObject {
    return [self _setForObject:anObject create:NO];
}

- (id)anyObjectForKey:(id)aKey {
    return [[self _setForKey:aKey create:NO] anyObject];
}

- (id)anyKeyForObject:(id)anObject {
    return [[self _setForObject:anObject create:NO] anyObject];
}

- (void)addObject:(id)anObject forKey:(id)aKey {
    [[self _setForKey:aKey create:YES] addObject:anObject];
    [[self _setForObject:anObject create:YES] addObject:aKey];
}

- (void)removeObject:(id)anObject forKey:(id)aKey{
    NSMutableSet *objectSet = [self _setForKey:aKey create:NO];
    NSMutableSet *keySet = [self _setForObject:anObject create:NO];
    if (objectSet) {
        [objectSet removeObject:anObject];
        if ([objectSet count] == 0)
            [dictionary removeObjectForKey:aKey];
    }
    if (keySet) {
        [keySet removeObject:anObject];
        if ([keySet count] == 0)
            [inverseDictionary removeObjectForKey:anObject];
    }
}

- (void)removeAllObjects {
    [dictionary removeAllObjects];
    [inverseDictionary removeAllObjects];
}

typedef struct _addEntryContext {
    BDSKMultiValueDictionary *dict;
    BOOL inverse;
} addEntryContext;

static void addEntryFunction(const void *key, const void *value, void *context) {
    addEntryContext *ctxt = context;
    NSMutableSet *set = nil;
    if (ctxt->inverse)
        set = [ctxt->dict _setForObject:(id)key create:YES];
    else
        set = [ctxt->dict _setForKey:(id)key create:YES];
    [set unionSet:(NSSet *)value];
}

- (void)addEntriesFromDictionary:(BDSKMultiValueDictionary *)otherDictionary {
    addEntryContext ctxt = {self, NO};
    ctxt.dict = self;
    ctxt.inverse = NO;
    CFDictionaryApplyFunction((CFDictionaryRef)(otherDictionary->dictionary), addEntryFunction, &ctxt);
    ctxt.inverse = YES;
    CFDictionaryApplyFunction((CFDictionaryRef)(otherDictionary->inverseDictionary), addEntryFunction, &ctxt);
}

@end

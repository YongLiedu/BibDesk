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
    }
    return self;
}

- (void)dealloc {
    [dictionary release];
    [super dealloc];
}

- (unsigned int)count {
    return [dictionary count];
}

- (NSMutableSet *)_setForKey:(id)aKey create:(BOOL)create {
    NSMutableSet *value = [dictionary objectForKey:aKey];

    if (create && value == nil) {
        value = [[NSMutableArray alloc] init];
        [dictionary setObject:value forKey:aKey];
        [value release];
    }
    return value;
}

- (NSSet *)setForKey:(id)aKey {
    return [self _setForKey:aKey create:NO];
}

- (id)anyObjectForKey:(id)aKey {
    return [[self _setForKey:aKey create:NO] anyObject];
}

- (void)addObject:(id)anObject forKey:(id)aKey {
    [[self _setForKey:aKey create:YES] addObject:anObject];
}

- (void)addObjects:(NSSet *)moreObjects forKey:(id)aKey; {
    if ([moreObjects count])
        [[self _setForKey:aKey create:YES] unionSet:moreObjects];
}

- (void)setObjects:(NSSet *)replacementObjects forKey:(id)aKey {
    if (replacementObjects != nil && [replacementObjects count] > 0) {
        NSMutableSet *valueSet = [replacementObjects mutableCopy];
        [dictionary setObject:valueSet forKey:aKey];
        [valueSet release];
    } else {
        [dictionary removeObjectForKey:aKey];
    }
}

- (void)removeObject:(id)anObject forKey:(id)aKey{
    NSMutableSet *valueSet = [self _setForKey:aKey create:NO];
    if (valueSet) {
        [valueSet removeObject:anObject];
        if ([valueSet count] == 0)
            [dictionary removeObjectForKey:aKey];
    }
}

- (void)removeAllObjects {
    [dictionary removeAllObjects];
}

static void addEntryFunction(const void *key, const void *value, void *context) {
    BDSKMultiValueDictionary *self = (BDSKMultiValueDictionary *)context;
    [[self _setForKey:(id)key create:YES] unionSet:(NSSet *)value];
}

- (void)addEntriesFromDictionary:(BDSKMultiValueDictionary *)otherDictionary {
    CFDictionaryApplyFunction((CFDictionaryRef)[otherDictionary dictionary], &addEntryFunction, &self);
}

- (NSEnumerator *)keyEnumerator {
    return [dictionary keyEnumerator];
}

- (NSArray *)allKeys {
    return [dictionary allKeys];
}

static void addValuesFunction(const void *key, const void *value, void *context) {
    [(NSMutableSet *)context unionSet:(NSSet *)value];
}

- (NSSet *)allValues {
    NSMutableSet *values = [NSMutableSet set];
    CFDictionaryApplyFunction((CFDictionaryRef)dictionary, &addValuesFunction, &values);
    return values;
}

- (NSMutableDictionary *)dictionary {
    return dictionary;
}

@end

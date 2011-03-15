//
//  BDSKFieldCollection.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/8/10.
/*
 This software is Copyright (c) 2010-2011
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

#import "BDSKFieldCollection.h"
#import "BibItem.h"
#import "BDSKField.h"
#import "BDSKTypeManager.h"
#import "BDSKConverter.h"
#import "NSString_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"


@implementation BDSKFieldCollection 

- (id)initWithItem:(BibItem *)anItem{
    self = [super init];
    if (self) {
        item = anItem;
        usedFields = [[NSMutableSet alloc] init];
        type = BDSKStringFieldCollection;
    }
    return self;
}

- (void)dealloc{
    item = nil;
    BDSKDESTROY(usedFields);
    [super dealloc];
}

- (id)valueForUndefinedKey:(NSString *)key{
    id value = nil;
    key = [key fieldName];
    if (key) {
        [usedFields addObject:key];
        if (type == BDSKPersonFieldCollection) {
            value = (id)[item peopleArrayForField:key];
        } else if (type == BDSKURLFieldCollection) {
            if ([key isEqualToString:BDSKLocalUrlString])
                value = [[[item localFiles] firstObject] URL];
            else if ([key isEqualToString:BDSKUrlString])
                value = [[[item remoteURLs] firstObject] URL];
            else
                value = (id)[item URLForField:key];
        } else {
            value = (id)[item stringValueOfField:key];
            if ([key isURLField] == NO && [key isBooleanField] == NO && [key isTriStateField] == NO && [key isRatingField] == NO && [key isCitationField] == NO)
                value = (id)[value stringByDeTeXifyingString];
        }
    }
    return value;
}

- (void)setType:(NSInteger)aType{
    type = aType;
}

- (BOOL)isUsedField:(NSString *)name{
    return [usedFields containsObject:[name fieldName]];
}

- (BOOL)isEmptyField:(NSString *)name{
    return [NSString isEmptyString:[item stringValueOfField:name]];
}

- (id)fieldForName:(NSString *)name{
    name = [name fieldName];
    [usedFields addObject:name];
    return [[[BDSKField alloc] initWithName:name bibItem:item] autorelease];
}

- (id)fieldsWithNames:(NSArray *)names{
    return [[[BDSKFieldArray alloc] initWithFieldCollection:self fieldNames:names] autorelease];
}

@end

#pragma mark -

@implementation BDSKFieldArray

- (id)initWithFieldCollection:(BDSKFieldCollection *)collection fieldNames:(NSArray *)array{
    self = [super init];
    if (self) {
        fieldCollection = [collection retain];
        fieldNames = [[NSMutableArray alloc] initWithCapacity:[array count]];
        for (NSString *name in array) 
            if ([fieldCollection isUsedField:name] == NO)
                [fieldNames addObject:name];
        mutations = 0;
    }
    return self;
}

- (void)dealloc{
    BDSKDESTROY(fieldNames);
    BDSKDESTROY(fieldCollection);
    [super dealloc];
}

- (NSUInteger)count{
    return [fieldNames count];
}

- (id)objectAtIndex:(NSUInteger)idx{
    return [fieldCollection fieldForName:[fieldNames objectAtIndex:idx]];
}

- (id)nonEmpty{
    NSUInteger i = [fieldNames count];
    while (i--) 
        if ([fieldCollection isEmptyField:[fieldNames objectAtIndex:i]])
            [fieldNames removeObjectAtIndex:i];
    mutations++;
    return self;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len {
    NSUInteger i = 0, current = state->state, count = [fieldNames count];
    for (i = 0, current = state->state; current < count && i < len; i++, current++)
        stackbuf[i] = [fieldCollection fieldForName:[fieldNames objectAtIndex:current]];
    state->state = current;
    state->itemsPtr = stackbuf;
	state->mutationsPtr = &mutations;
    return i;
}

@end

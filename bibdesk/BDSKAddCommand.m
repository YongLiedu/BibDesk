//
//  BDSKAddCommand.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/8/08.
/*
 This software is Copyright (c) 2008
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

#import "BDSKAddCommand.h"
#import "NSAppleEventDescriptor_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "KFASHandlerAdditions-TypeTranslation.h"


@implementation BDSKAddCommand

 - (id)performDefaultImplementation {
    // get the actual objects to insert
    id directParameter = [self directParameter];
    id receiver = [self evaluatedReceivers];
    NSArray *insertionObjects = nil;
    NSMutableArray *returnValue = nil;
    NSEnumerator *objEnum;
    id obj;
    BOOL isArray = [directParameter isKindOfClass:[NSArray class]] || [receiver isKindOfClass:[NSArray class]];
    
    if (directParameter && [directParameter isKindOfClass:[NSArray class]] == NO)
        directParameter = [NSArray arrayWithObjects:directParameter, nil];
    
    obj = [directParameter lastObject];
    if ([obj respondsToSelector:@selector(keyClassDescription)]) {
        insertionObjects = (receiver && [receiver isKindOfClass:[NSArray class]]) ? receiver : [NSArray arrayWithObjects:receiver, nil];
    } else if ([obj isKindOfClass:[NSAppleEventDescriptor class]]) {
        if ([obj fileURLValue])
            insertionObjects = [directParameter valueForKey:@"fileURLValue"];
        else if ((obj = [obj stringValue]) && [NSURL URLWithString:obj])
            insertionObjects = [directParameter valueForKey:@"stringValue"];
    }
    
    if (insertionObjects == nil) {
        [self setScriptErrorNumber:NSArgumentsWrongScriptError];
    } else {
        
        // get the location to insert
        id locationSpecifier = [[self arguments] objectForKey:@"ToLocation"];
        id insertionContainer = nil;
        NSString *insertionKey = nil;
        int insertionIndex = -1;
        
        NSScriptClassDescription *containerClassDescription = nil;
        
        if ([locationSpecifier isKindOfClass:[NSPositionalSpecifier class]]) {
            insertionContainer = [locationSpecifier insertionContainer];
            insertionKey = [locationSpecifier insertionKey];
            insertionIndex = [locationSpecifier insertionIndex];
        } else if ([locationSpecifier isKindOfClass:[NSPropertySpecifier class]]) {
            insertionContainer = [[locationSpecifier containerSpecifier] objectsByEvaluatingSpecifier];
            insertionKey = [locationSpecifier key];
        } else if (locationSpecifier) {
            insertionContainer = [locationSpecifier objectsByEvaluatingSpecifier];
            // make sure this is a valid object, so not something like a range specifier
            if ([insertionContainer respondsToSelector:@selector(objectSpecifier)] == NO)
                insertionContainer = nil;
            containerClassDescription = (NSScriptClassDescription *)[insertionContainer classDescription];
            OBASSERT([containerClassDescription isKindOfClass:[NSScriptClassDescription class]]);
            NSEnumerator *keyEnum = [[containerClassDescription toManyRelationshipKeys] objectEnumerator];
            NSString *key;
            while (key = [keyEnum nextObject]) {
                NSScriptClassDescription *keyClassDescription = [containerClassDescription classDescriptionForKey:key];
                if ([[insertionObjects lastObject] isKindOfClass:NSClassFromString([keyClassDescription typeForKey:key])] &&
                    [containerClassDescription isLocationRequiredToCreateForKey:key] == NO) {
                    insertionKey = key;
                    break;
                }
            }
        }
        
        // check if the insertion location is valid
        if (containerClassDescription == nil && insertionContainer) {
            containerClassDescription = (NSScriptClassDescription *)[insertionContainer classDescription];
            OBASSERT([containerClassDescription isKindOfClass:[NSScriptClassDescription class]]);
        }
        if (insertionContainer == nil || insertionKey == nil || 
            [[containerClassDescription toManyRelationshipKeys] containsObject:insertionKey] == NO) {
            [self setScriptErrorNumber:NSArgumentsWrongScriptError];
            insertionObjects = nil;
        } else {
            // check if the inserted objects are valid for the insertion container key
            Class requiredClass = NSClassFromString([containerClassDescription typeForKey:insertionKey]);
            BOOL isValid = YES;
            
            returnValue = [NSMutableArray array];
            objEnum = [insertionObjects objectEnumerator];
            while (isValid && (obj = [objEnum nextObject])) {
                if ([obj isKindOfClass:requiredClass] == NO)
                    isValid = NO;
                obj = [obj respondsToSelector:@selector(objectSpecifier)] ? (id)[obj objectSpecifier] : (id)[obj aeDescriptorValue];
                if (obj)
                    [returnValue addObject:obj];
            }
            
            if (isValid == NO || (insertionIndex == -1 && [containerClassDescription isLocationRequiredToCreateForKey:insertionKey])) {
                [self setScriptErrorNumber:NSArgumentsWrongScriptError];
                insertionObjects = nil;
                returnValue = nil;
            } else {
                // insert using scripting KVC
                if (insertionIndex >= 0) {
                    objEnum = [insertionObjects reverseObjectEnumerator];
                    while (obj = [objEnum nextObject])
                        [insertionContainer insertValue:obj atIndex:insertionIndex inPropertyWithKey:insertionKey];
                } else {
                    objEnum = [insertionObjects objectEnumerator];
                    while (obj = [objEnum nextObject])
                        [insertionContainer insertValue:obj inPropertyWithKey:insertionKey];
                }
            }
        }
    }
    
    return isArray ? returnValue : [returnValue lastObject];
}

@end

//
//  BDSKRemoveCommand.m
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

#import "BDSKRemoveCommand.h"
#import "NSAppleEventDescriptor_BDSKExtensions.h"


@implementation BDSKRemoveCommand

 - (id)performDefaultImplementation {
    // get the actual objects to remove
    id directParameter = [self directParameter];
    id receiver = [self evaluatedReceivers];
    id removeObjects = nil;
    id returnValue = nil;
    NSString *className = nil;
    NSEnumerator *objEnum;
    id obj = directParameter;
    
    if ([directParameter isKindOfClass:[NSArray class]])
        obj = [directParameter lastObject];
    if ([obj respondsToSelector:@selector(keyClassDescription)]) {
        className = [[obj keyClassDescription] className];
        removeObjects = receiver;
        returnValue = directParameter;
    } else if ([obj isKindOfClass:[NSAppleEventDescriptor class]]) {
        DescType descType = [obj descriptorType];
        if ([obj fileURLValue]) {
            className = @"linked file";
            removeObjects = [directParameter valueForKey:@"fileURLValue"];
        } else if ((obj = [obj stringValue]) && [NSURL URLWithString:obj]) {
            className = @"linked URL";
            removeObjects = [directParameter valueForKey:@"stringValue"];
        } else {
            removeObjects = nil;
        }
        if (removeObjects)
            returnValue = directParameter;
    }
    
    if (removeObjects == nil) {
        [self setScriptErrorNumber:NSArgumentsWrongScriptError];
    } else {
        
        // get the container to remove from
        id containerSpecifier = [[self arguments] objectForKey:@"FromContainer"];
        id removeContainer = nil;
        NSString *removeKey = nil;
        
        NSScriptClassDescription *containerClassDescription = nil;
        
        if (containerSpecifier == nil) {
            obj = directParameter;
            if ([obj isKindOfClass:[NSArray class]])
                obj = [obj lastObject];
            containerSpecifier = [obj containerSpecifier];
        }
        
        if ([containerSpecifier isKindOfClass:[NSPropertySpecifier class]]) {
            removeContainer = [[containerSpecifier containerSpecifier] objectsByEvaluatingSpecifier];
            removeKey = [containerSpecifier key];
        } else if (containerSpecifier) {
            removeContainer = [containerSpecifier objectsByEvaluatingSpecifier];
            // make sure this is a valid object, so not something like a range specifier
            if ([removeContainer respondsToSelector:@selector(objectSpecifier)] == NO)
                removeContainer = nil;
            containerClassDescription = (NSScriptClassDescription *)[removeContainer classDescription];
            OBASSERT([containerClassDescription isKindOfClass:[NSScriptClassDescription class]]);
            NSEnumerator *keyEnum = [[containerClassDescription toManyRelationshipKeys] objectEnumerator];
            NSString *key;
            while (key = [keyEnum nextObject]) {
                NSScriptClassDescription *keyClassDescription = [containerClassDescription classDescriptionForKey:key];
                if ([className isEqualToString:[keyClassDescription className]] &&
                    [containerClassDescription isLocationRequiredToCreateForKey:key] == NO) {
                    removeKey = key;
                    break;
                }
            }
        }
        
        // check if the remove location is valid
        if (containerClassDescription == nil) {
            containerClassDescription = (NSScriptClassDescription *)[removeContainer classDescription];
            OBASSERT([containerClassDescription isKindOfClass:[NSScriptClassDescription class]]);
        }
        if ([[containerClassDescription toManyRelationshipKeys] containsObject:removeKey] == NO ||
            [className isEqualToString:[[containerClassDescription classDescriptionForKey:removeKey] className]] == NO) {
            [self setScriptErrorNumber:NSArgumentsWrongScriptError];
            returnValue = nil;
        } else {
            // remove using KVC, I don't know how to use scripting KVC as I don't know how to get the indexes in general
            if ([removeObjects isKindOfClass:[NSArray class]] == NO)
                removeObjects = [NSArray arrayWithObject:removeObjects];
            [[removeContainer mutableArrayValueForKey:removeKey] removeObjectsInArray:removeObjects];
        }
    }
    return nil;
}

@end

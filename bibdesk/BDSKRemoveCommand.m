//
//  BDSKRemoveCommand.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/8/08.
/*
 This software is Copyright (c) 2008-2010
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
#import "NSScriptClassDescription_BDSKExtensions.h"
#import "NSObject_BDSKExtensions.h"


@implementation BDSKRemoveCommand

 - (id)performDefaultImplementation {
    // get the actual objects to remove
    id directParameter = [self directParameter];
    id receiver = [self evaluatedReceivers];
    NSArray *removeObjects = nil;
    id obj = directParameter;
    
    if (directParameter && [directParameter isKindOfClass:[NSArray class]] == NO)
        directParameter = [NSArray arrayWithObjects:directParameter, nil];
    
    obj = [directParameter lastObject];
    removeObjects = (receiver && [receiver isKindOfClass:[NSArray class]]) ? receiver : [NSArray arrayWithObjects:receiver, nil];
    
    if (removeObjects == nil) {
        [self setScriptErrorNumber:NSArgumentsWrongScriptError];
        [self setScriptErrorString:NSLocalizedString(@"Invalid or missing objects to remove", @"Error description")];
    } else {
        
        // get the container to remove from
        id containerSpecifier = [[self arguments] objectForKey:@"FromContainer"];
        id removeContainer = nil;
        NSString *removeKey = nil;
        NSScriptClassDescription *containerClassDescription = nil;
        NSArray *classDescriptions = [removeObjects valueForKey:@"scriptClassDescription"];
        NSScriptClassDescription *removeClassDescription = [classDescriptions containsObject:[NSNull null]] ? nil : [NSScriptClassDescription commonAncestorForClassDescriptions:classDescriptions];
        
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
            containerClassDescription = [removeContainer scriptClassDescription];
            for (NSString *key in [containerClassDescription toManyRelationshipKeys]) {
                NSScriptClassDescription *keyClassDescription = [containerClassDescription classDescriptionForKey:key];
                if ([removeClassDescription isKindOfClassDescription:keyClassDescription]) {
                    removeKey = key;
                    break;
                }
            }
        }
        
        // check if the remove location is valid
        if (containerClassDescription == nil && removeContainer)
            containerClassDescription = [removeContainer scriptClassDescription];
        if (removeContainer == nil || removeKey == nil || 
            [[containerClassDescription toManyRelationshipKeys] containsObject:removeKey] == NO) {
            [self setScriptErrorNumber:NSArgumentsWrongScriptError];
			[self setScriptErrorString:NSLocalizedString(@"Could not find container to remove from", @"Error description")];
        } else {
            NSScriptClassDescription *requiredClassDescription = [containerClassDescription classDescriptionForKey:removeKey];
            
            if ([removeClassDescription isKindOfClassDescription:requiredClassDescription] == NO) {
                [self setScriptErrorNumber:NSArgumentsWrongScriptError];
                [self setScriptErrorString:NSLocalizedString(@"Invalid container to remove from", @"Error description")];
            } else {
                // remove using KVC, I don't know how to use scripting KVC as I don't know how to get the indexes in general
                [[removeContainer mutableArrayValueForKey:removeKey] removeObjectsInArray:removeObjects];
            }
        }
    }
    return nil;
}

@end

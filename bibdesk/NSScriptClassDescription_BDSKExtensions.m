//
//  NSScriptClassDescription_BDSKExtensions.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/23/08.
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

#import "NSScriptClassDescription_BDSKExtensions.h"


@implementation NSScriptClassDescription (BDSKExtensions)

+ (NSScriptClassDescription *)commonAncestorForClassDescriptions:(NSArray *)classDescriptionArray {
    NSEnumerator *cdEnum = [classDescriptionArray objectEnumerator];
    NSScriptClassDescription *classDescription = [cdEnum nextObject];
    NSScriptClassDescription *ancestor = classDescription;
    
    while (ancestor && (classDescription = [cdEnum nextObject]))
        ancestor = [ancestor commonAncestorForClassDescription:classDescription];
    
    return ancestor;
}

- (NSScriptClassDescription *)commonAncestorForClassDescription:(NSScriptClassDescription *)aClassDescription {
    NSScriptClassDescription *myAncestor = self;
    NSScriptClassDescription *otherAncestor = aClassDescription;
    NSMutableArray *otherAncestors = [NSMutableArray arrayWithObjects:otherAncestor, nil];
    
    while (otherAncestor = [otherAncestor superclassDescription])
        [otherAncestors addObject:otherAncestor];
    do {
        for (otherAncestor in otherAncestors) {
            if ([myAncestor isEqual:otherAncestor])
                return myAncestor;
        }
    } while (myAncestor = [myAncestor superclassDescription]);
    
    return nil;
}

- (BOOL)isKindOfClassDescription:(NSScriptClassDescription *)aClassDescription {
    if (aClassDescription == nil)
        return NO;
    else if ([self isEqual:aClassDescription])
        return YES;
    else
        return [[self superclassDescription] isKindOfClassDescription:aClassDescription];
}

@end

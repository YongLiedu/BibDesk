//
//  BDSKSortCommand.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/31/07.
/*
 This software is Copyright (c) 2007-2009
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

#import "BDSKSortCommand.h"
#import "BDSKTableSortDescriptor.h"
#import "NSString_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "BibDocument.h"
#import "BibItem.h"

@implementation BDSKSortCommand

static NSString *normalizedKey(NSString *key) {
    static NSArray *specialKeys = nil;
    if (specialKeys == nil) {
        specialKeys = [[NSMutableArray alloc] initWithObjects:
            BDSKAuthorEditorString, BDSKFirstAuthorEditorString, BDSKSecondAuthorEditorString, BDSKThirdAuthorEditorString, BDSKLastAuthorEditorString, nil];
    }

    NSString *capKey = [key fieldName];
    if ([key isEqualToString:capKey] == NO) {
        BOOL isSpecial = NO;
        for (NSString *specialKey in specialKeys) {
            if ([key caseInsensitiveCompare:specialKey]) {
                key = specialKey;
                isSpecial = YES;
                break;
            }
        }
        if (isSpecial == NO)
            key = capKey;
    }
    return key;
}

- (id)performDefaultImplementation {
    id dP = [self directParameter];
    if ([dP isKindOfClass:[NSArray class]] == NO)
        dP = [dP objectsByEvaluatingSpecifier];
    if ([dP isKindOfClass:[NSArray class]] == NO)
        return nil;
    else if ([dP count] == 0)
        return dP;
    
    id lastObject = [dP lastObject];
    if ([lastObject isKindOfClass:[BibItem class]] == NO && [lastObject respondsToSelector:@selector(objectsByEvaluatingSpecifier)])
        dP = [dP arrayByPerformingSelector:@selector(objectsByEvaluatingSpecifier)];
    
    NSDictionary *args = [self evaluatedArguments];
    NSString *key = [args objectForKey:@"by"];
    NSString *subKey = [args objectForKey:@"subsort"];
    NSNumber *ascending = [args objectForKey:@"ascending"];
    NSNumber *subAscending = [args objectForKey:@"subsortAscending"];
    BOOL isAscending = ascending ? [ascending boolValue] : YES;
    BOOL isSubAscending = subAscending ? [subAscending boolValue] : isAscending;
    
    BDSKTableSortDescriptor *sortDescriptor = [BDSKTableSortDescriptor tableSortDescriptorForIdentifier:normalizedKey(key) ascending:isAscending];
    BDSKTableSortDescriptor *subSortDescriptor = nil;
    if (subKey)
        [BDSKTableSortDescriptor tableSortDescriptorForIdentifier:normalizedKey(subKey) ascending:isSubAscending];
    
    return [dP sortedArrayUsingMergesortWithDescriptors:[NSArray arrayWithObjects:sortDescriptor, subSortDescriptor, nil]];
}

@end

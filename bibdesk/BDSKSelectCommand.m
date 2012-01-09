//
//  BDSKSelectCommand.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 4/18/11.
/*
 This software is Copyright (c) 2011-2012
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

#import "BDSKSelectCommand.h"
#import "BibDocument.h"
#import "BibDocument_Groups.h"
#import "BibItem.h"
#import "BDSKGroup.h"
#import "NSArray_BDSKExtensions.h"


@implementation BDSKSelectCommand

- (id)performDefaultImplementation {
    id dP = [self directParameter];
    if ([dP isKindOfClass:[NSArray class]] == NO && [dP respondsToSelector:@selector(objectsByEvaluatingSpecifier)])
        dP = [dP objectsByEvaluatingSpecifier];
    if ([dP isKindOfClass:[NSArray class]] == NO)
        dP = [NSArray arrayWithObjects:dP, nil];
    
    id firstObject = [dP firstObject];
    if ([firstObject respondsToSelector:@selector(objectsByEvaluatingSpecifier)])
        dP = [dP valueForKey:@"objectsByEvaluatingSpecifier"];
    BibDocument *doc = nil;
    
    firstObject = [dP firstObject];
    if ([dP count] == 0 || [firstObject isKindOfClass:[BibItem class]]) {
        doc = [firstObject owner];
        if ([doc isDocument] == NO)
            doc = [(id)doc document];
        if (doc == nil)
            doc = [[NSApp orderedDocuments] firstObject];
        [doc selectPublications:dP];
    } else if ([firstObject isKindOfClass:[BDSKGroup class]]) {
        doc = [firstObject document];
        [doc selectGroups:dP];
    }
        
    return nil;
}

@end

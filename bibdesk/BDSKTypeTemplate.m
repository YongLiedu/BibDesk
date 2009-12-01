//
//  BDSKTypeTemplate.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/9/07.
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

#import "BDSKTypeTemplate.h"
#import "BDSKTemplateDocument.h"
#import "BDSKToken.h"
#import "BDSKTypeManager.h"
#import "BDSKStringConstants.h"

NSString *BDSKTemplateDidChangeNotification = @"BDSKTemplateDidChangeNotification";

@implementation BDSKTypeTemplate

+ (NSSet *)keyPathsForValuesAffectingTextColor {
    return [NSSet setWithObjects:@"itemTemplate", @"included", @"default", nil];
}

- (id)initWithPubType:(NSString *)aPubType forDocument:(BDSKTemplateDocument *)aDocument {
    if (self = [super init]) {
        pubType = [aPubType retain];
        requiredTokens = [[NSMutableArray alloc] init];
        optionalTokens = [[NSMutableArray alloc] init];
        itemTemplate = [[NSMutableArray alloc] init];
        document = aDocument;
        
        BDSKTypeManager *tm = [BDSKTypeManager sharedManager];
        NSString *field;
        
        for (field in [tm requiredFieldsForType:pubType])
            [requiredTokens addObject:[document tokenForField:field]];
        
        for (field in [tm optionalFieldsForType:pubType])
            [optionalTokens addObject:[document tokenForField:field]];
        
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(pubType);
    BDSKDESTROY(requiredTokens);
    BDSKDESTROY(optionalTokens);
    BDSKDESTROY(itemTemplate);
    [super dealloc];
}

#pragma mark Accessors

- (NSString *)pubType {
    return pubType;
}

- (void)setPubType:(NSString *)newPubType {
    if (pubType != newPubType) {
        [pubType release];
        pubType = [newPubType retain];
    }
}

- (BOOL)isIncluded {
    return included;
}

- (void)setIncluded:(BOOL)newIncluded {
    if (included != newIncluded) {
        [[[self undoManager] prepareWithInvocationTarget:self] setIncluded:included];
        included = newIncluded;
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTemplateDidChangeNotification object:self];
    }
}

- (BOOL)isDefault {
    return [[[document typeTemplates] objectAtIndex:[document defaultTypeIndex]] isEqual:self];
}

- (NSColor *)textColor {
    NSColor *color = [NSColor controlTextColor];
    if ([[self itemTemplate] count] == 0) {
        if ([self isIncluded] || [self isDefault])
            color = [NSColor redColor];
        else
            color = [NSColor disabledControlTextColor];
    }
    return color;
}

- (NSArray *)requiredTokens {
    return requiredTokens;
}

- (void)setRequiredTokens:(NSArray *)newRequiredTokens {
    [requiredTokens setArray:newRequiredTokens];
}

- (NSArray *)optionalTokens {
    return optionalTokens;
}

- (void)setOptionalTokens:(NSArray *)newOptionalTokens {
    [optionalTokens setArray:newOptionalTokens];
}

- (NSArray *)itemTemplate {
    return itemTemplate;
}

- (void)setItemTemplate:(NSArray *)newItemTemplate {
    if ([itemTemplate isEqual:newItemTemplate] == NO) {
        [[[self undoManager] prepareWithInvocationTarget:self] setItemTemplate:[[itemTemplate copy] autorelease]];
        [itemTemplate setArray:newItemTemplate];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTemplateDidChangeNotification object:self];
    }
}

- (BDSKTemplateDocument *)document {
    return document;
}

- (NSUndoManager *)undoManager {
    return [document undoManager];
}

- (NSString *)string {
    NSMutableString *string = [NSMutableString string];
    
    for (id token in itemTemplate) {
        if ([token isKindOfClass:[BDSKToken class]])
            [string appendString:[token string]];
        else if ([token isKindOfClass:[NSString class]])
            [string appendString:token];
    }
    
    return string;
}

- (NSAttributedString *)attributedStringWithDefaultAttributes:(NSDictionary *)attributes {
    NSMutableAttributedString *attrString = [[[NSMutableAttributedString alloc] init] autorelease];
    
    for (id token in itemTemplate) {
        if ([token isKindOfClass:[BDSKToken class]])
            [attrString appendAttributedString:[token attributedStringWithDefaultAttributes:attributes]];
        else if ([token isKindOfClass:[NSString class]])
            [attrString appendAttributedString:[[[NSAttributedString alloc] initWithString:token attributes:attributes] autorelease]];
    }
    [attrString fixAttributesInRange:NSMakeRange(0, [attrString length])];
    
    return attrString;
}

@end

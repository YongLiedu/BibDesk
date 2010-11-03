//
//  BDSKTypeTemplate.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/9/07.
/*
 This software is Copyright (c) 2007-2010
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
        itemTemplate = [[NSArray alloc] init];
        document = aDocument;
        
        NSMutableArray *tmpArray = [NSMutableArray array];
        BDSKTypeManager *tm = [BDSKTypeManager sharedManager];
        NSString *field;
        
        for (field in [tm requiredFieldsForType:pubType])
            [tmpArray addObject:[document tokenForField:field]];
        requiredTokens = [tmpArray copy];
        
        [tmpArray removeAllObjects];
        for (field in [tm optionalFieldsForType:pubType])
            [tmpArray addObject:[document tokenForField:field]];
        optionalTokens = [tmpArray copy];
        
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
    included = newIncluded;
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

- (NSArray *)optionalTokens {
    return optionalTokens;
}

- (NSArray *)itemTemplate {
    return itemTemplate;
}

- (void)setItemTemplate:(NSArray *)newItemTemplate {
    if (itemTemplate != newItemTemplate) {
        [itemTemplate release];
        itemTemplate = [newItemTemplate copy] ?: [[NSArray alloc] init];
    }
}

- (BDSKTemplateDocument *)document {
    return document;
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

//
//  BDSKTemplateTag.m
//  BibDesk
//
//  Created by Christiaan Hofman on 10/12/07.
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

#import "BDSKTemplateTag.h"
#import "BDSKTemplateParser.h"


@implementation BDSKTemplateTag
- (BDSKTemplateTagType)type { return -1; }
@end

#pragma mark -

@implementation BDSKValueTemplateTag

- (id)initWithKeyPath:(NSString *)aKeyPath {
    if (self = [super init])
        keyPath = [aKeyPath copy];
    return self;
}

- (void)dealloc {
    BDSKDESTROY(keyPath);
    [super dealloc];
}

- (BDSKTemplateTagType)type { return BDSKValueTemplateTagType; }

- (NSString *)keyPath {
    return keyPath;
}

@end

#pragma mark -

@implementation BDSKRichValueTemplateTag

- (id)initWithKeyPath:(NSString *)aKeyPath attributes:(NSDictionary *)anAttributes {
    if (self = [super initWithKeyPath:aKeyPath]) {
        attributes = [anAttributes copy];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(attributes);
    [super dealloc];
}

- (NSDictionary *)attributes {
    return attributes;
}

@end

#pragma mark -

@implementation BDSKCollectionTemplateTag

- (id)initWithKeyPath:(NSString *)aKeyPath itemTemplateString:(NSString *)anItemTemplateString separatorTemplateString:(NSString *)aSeparatorTemplateString {
    if (self = [super initWithKeyPath:aKeyPath]) {
        itemTemplateString = [anItemTemplateString retain];
        separatorTemplateString = [aSeparatorTemplateString retain];
        itemTemplate = nil;
        separatorTemplate = nil;
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(itemTemplateString);
    BDSKDESTROY(separatorTemplateString);
    BDSKDESTROY(itemTemplate);
    BDSKDESTROY(separatorTemplate);
    [super dealloc];
}

- (BDSKTemplateTagType)type { return BDSKCollectionTemplateTagType; }

- (NSArray *)itemTemplate {
    if (itemTemplate == nil && itemTemplateString)
        itemTemplate = [[BDSKTemplateParser arrayByParsingTemplateString:itemTemplateString isSubtemplate:YES] retain];
    return itemTemplate;
}

- (NSArray *)separatorTemplate {
    if (separatorTemplate == nil && separatorTemplateString)
        separatorTemplate = [[BDSKTemplateParser arrayByParsingTemplateString:separatorTemplateString isSubtemplate:YES] retain];
    return separatorTemplate;
}

@end

#pragma mark -

@implementation BDSKRichCollectionTemplateTag

- (id)initWithKeyPath:(NSString *)aKeyPath itemTemplateAttributedString:(NSAttributedString *)anItemTemplateAttributedString separatorTemplateAttributedString:(NSAttributedString *)aSeparatorTemplateAttributedString {
    if (self = [super initWithKeyPath:aKeyPath]) {
        itemTemplateAttributedString = [anItemTemplateAttributedString retain];
        separatorTemplateAttributedString = [aSeparatorTemplateAttributedString retain];
        itemTemplate = nil;
        separatorTemplate = nil;
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(itemTemplateAttributedString);
    BDSKDESTROY(separatorTemplateAttributedString);
    BDSKDESTROY(itemTemplate);
    BDSKDESTROY(separatorTemplate);
    [super dealloc];
}

- (BDSKTemplateTagType)type { return BDSKCollectionTemplateTagType; }

- (NSArray *)itemTemplate {
    if (itemTemplate == nil && itemTemplateAttributedString)
        itemTemplate = [[BDSKTemplateParser arrayByParsingTemplateAttributedString:itemTemplateAttributedString isSubtemplate:YES] retain];
    return itemTemplate;
}

- (NSArray *)separatorTemplate {
    if (separatorTemplate == nil && separatorTemplateAttributedString)
        separatorTemplate = [[BDSKTemplateParser arrayByParsingTemplateAttributedString:separatorTemplateAttributedString isSubtemplate:YES] retain];
    return separatorTemplate;
}

@end

#pragma mark -

@implementation BDSKConditionTemplateTag

- (id)initWithKeyPath:(NSString *)aKeyPath matchType:(BDSKTemplateTagMatchType)aMatchType matchStrings:(NSArray *)aMatchStrings subtemplates:(NSArray *)aSubtemplates {
    if (self = [super initWithKeyPath:aKeyPath]) {
        matchType = aMatchType;
        matchStrings = [aMatchStrings copy];
        subtemplates = [aSubtemplates mutableCopy];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(subtemplates);
    BDSKDESTROY(matchStrings);
    [super dealloc];
}

- (BDSKTemplateTagType)type { return BDSKConditionTemplateTagType; }

- (BDSKTemplateTagMatchType)matchType {
    return matchType;
}

- (NSArray *)subtemplates {
    return subtemplates;
}

- (NSArray *)matchStrings {
    return matchStrings;
}

- (NSArray *)subtemplateAtIndex:(NSUInteger)anIndex {
    id subtemplate = [subtemplates objectAtIndex:anIndex];
    if ([subtemplate isKindOfClass:[NSArray class]] == NO) {
        subtemplate = [BDSKTemplateParser arrayByParsingTemplateString:subtemplate isSubtemplate:YES];
        [subtemplates replaceObjectAtIndex:anIndex withObject:subtemplate];
    }
    return subtemplate;
}

@end

#pragma mark -

@implementation BDSKRichConditionTemplateTag

- (NSArray *)subtemplateAtIndex:(NSUInteger)anIndex {
    id subtemplate = [subtemplates objectAtIndex:anIndex];
    if ([subtemplate isKindOfClass:[NSArray class]] == NO) {
        subtemplate = [BDSKTemplateParser arrayByParsingTemplateAttributedString:subtemplate isSubtemplate:YES];
        [subtemplates replaceObjectAtIndex:anIndex withObject:subtemplate];
    }
    return subtemplate;
}

@end

#pragma mark -

@implementation BDSKTextTemplateTag

- (id)initWithText:(NSString *)aText {
    if (self = [super init]) {
        text = [aText retain];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(text);
    [super dealloc];
}

- (BDSKTemplateTagType)type { return BDSKTextTemplateTagType; }

- (NSString *)text {
    return text;
}

- (void)setText:(NSString *)newText {
    if (text != newText) {
        [text release];
        text = [newText retain];
    }
}

- (void)appendText:(NSString *)newText {
    [self setText:[text stringByAppendingString:newText]];
}

@end

#pragma mark -

@implementation BDSKRichTextTemplateTag

- (id)initWithAttributedText:(NSAttributedString *)anAttributedText {
    if (self = [super init]) {
        attributedText = [anAttributedText retain];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(attributedText);
    [super dealloc];
}

- (BDSKTemplateTagType)type { return BDSKTextTemplateTagType; }

- (NSAttributedString *)attributedText {
    return attributedText;
}

- (void)setAttributedText:(NSAttributedString *)newAttributedText {
    if (attributedText != newAttributedText) {
        [attributedText release];
        attributedText = [newAttributedText retain];
    }
}

- (void)appendAttributedText:(NSAttributedString *)newAttributedText {
    NSMutableAttributedString *newAttrText = [attributedText mutableCopy];
    [newAttrText appendAttributedString:newAttributedText];
    [newAttrText fixAttributesInRange:NSMakeRange(0, [newAttrText length])];
    [self setAttributedText:newAttrText];
    [newAttrText release];
}

@end

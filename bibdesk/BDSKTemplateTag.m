//
//  BDSKTemplateTag.m
//  BibDesk
//
//  Created by Christiaan Hofman on 10/12/07.
/*
 This software is Copyright (c) 2007-2011
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


static inline BDSKAttributeTemplate *copyTemplateForLink(id aLink, NSRange range) {
    BDSKAttributeTemplate *linkTemplate = nil;
    if ([aLink isKindOfClass:[NSURL class]])
        aLink = [[aLink absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    if ([aLink isKindOfClass:[NSString class]]) {
        NSArray *template = [BDSKTemplateParser arrayByParsingTemplateString:aLink];
        if ([template count] > 1 || ([template count] == 1 && [(BDSKTemplateTag *)[template lastObject] type] != BDSKTextTemplateTagType))
            linkTemplate = [[BDSKAttributeTemplate alloc] initWithTemplate:template range:range attributeClass:[aLink class]];
    }
    return linkTemplate;
}

static inline NSArray *copyTemplatesForLinksFromAttributedString(NSAttributedString *attrString) {
    NSRange range = NSMakeRange(0, 0);
    NSUInteger len = [attrString length];
    NSMutableArray *templates = [[NSMutableArray alloc] init];
    BDSKAttributeTemplate *linkTemplate;
    
    while (NSMaxRange(range) < len) {
        id aLink = [attrString attribute:NSLinkAttributeName atIndex:NSMaxRange(range) longestEffectiveRange:&range inRange:NSMakeRange(NSMaxRange(range), len - NSMaxRange(range))];
        if ((linkTemplate = copyTemplateForLink(aLink, range))) {
            [templates addObject:linkTemplate];
            [linkTemplate release];
        }
    }
    if ([templates count] == 0)
        BDSKDESTROY(templates);
    return templates;
}


@implementation BDSKTemplateTag
- (BDSKTemplateTagType)type { return -1; }
@end

#pragma mark -

@implementation BDSKValueTemplateTag

- (id)initWithKeyPath:(NSString *)aKeyPath {
    self = [super init];
    if (self)
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
    self = [super initWithKeyPath:aKeyPath];
    if (self) {
        attributes = [anAttributes copy];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(attributes);
    BDSKDESTROY(linkTemplate);
    [super dealloc];
}

- (NSDictionary *)attributes {
    return attributes;
}

- (BDSKAttributeTemplate *)linkTemplate {
    if (linkTemplate == nil)
        linkTemplate = copyTemplateForLink([attributes objectForKey:NSLinkAttributeName], NSMakeRange(0, 0)) ?: [[BDSKAttributeTemplate alloc] init];
    return [linkTemplate template] ? linkTemplate : nil;
}

@end

#pragma mark -

@implementation BDSKCollectionTemplateTag

- (id)initWithKeyPath:(NSString *)aKeyPath itemTemplateString:(NSString *)anItemTemplateString separatorTemplateString:(NSString *)aSeparatorTemplateString {
    self = [super initWithKeyPath:aKeyPath];
    if (self) {
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
    self = [super initWithKeyPath:aKeyPath];
    if (self) {
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
    self = [super initWithKeyPath:aKeyPath];
    if (self) {
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
    self = [super init];
    if (self) {
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
    self = [super init];
    if (self) {
        attributedText = [anAttributedText retain];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(attributedText);
    BDSKDESTROY(linkTemplates);
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

- (NSArray *)linkTemplates; {
    if (linkTemplates == nil)
        linkTemplates = copyTemplatesForLinksFromAttributedString(attributedText) ?: [[NSArray alloc] init];
    return [linkTemplates count] ? linkTemplates : nil;
}

@end

#pragma mark -

@implementation BDSKAttributeTemplate

- (id)initWithTemplate:(NSArray *)aTemplate range:(NSRange)aRange attributeClass:(Class)aClass {
    self = [super init];
    if (self) {
        template = [aTemplate copy];
        range = aRange;
        attributeClass = aClass;
    }
    return self;
}

- (id)init {
    return [self initWithTemplate:nil range:NSMakeRange(0, 0) attributeClass:NULL];
}

- (void)dealloc {
    BDSKDESTROY(template);
    [super dealloc];
}

- (NSRange)range {
    return range;
}

- (NSArray *)template {
    return template;
}

- (Class)attributeClass {
    return attributeClass;
}

@end

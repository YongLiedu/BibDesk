//
//  BDSKTemplateTag.h
//  BibDesk
//
//  Created by Christiaan Hofman on 10/12/07.
/*
 This software is Copyright (c) 2007-2008
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

#import <Cocoa/Cocoa.h>

enum {
    BDSKValueTemplateTagType,
    BDSKCollectionTemplateTagType,
    BDSKConditionTemplateTagType,
    BDSKTextTemplateTagType
};
typedef NSInteger BDSKTemplateTagType;

enum {
    BDSKTemplateTagMatchOther,
    BDSKTemplateTagMatchEqual,
    BDSKTemplateTagMatchContain,
    BDSKTemplateTagMatchSmaller,
    BDSKTemplateTagMatchSmallerOrEqual,
};
typedef NSInteger BDSKTemplateTagMatchType;


@interface BDSKTemplateTag : NSObject {
}
- (BDSKTemplateTagType)type;
@end

#pragma mark -

@interface BDSKPlaceholderTemplateTag : BDSKTemplateTag {
    NSString *string;
    int inlineOptions;
}

- (id)initWithString:(NSString *)aString atStartOfLine:(BOOL)flag;

- (NSString *)string;
- (NSArray *)templateArray;

@end

#pragma mark -

@interface BDSKRichPlaceholderTemplateTag : BDSKTemplateTag {
    NSAttributedString *attributedString;
    int inlineOptions;
}

- (id)initWithAttributedString:(NSAttributedString *)anAttributedString atStartOfLine:(BOOL)flag;

- (NSAttributedString *)attributedString;
- (NSArray *)templateArray;

@end

#pragma mark -

@interface BDSKValueTemplateTag : BDSKTemplateTag {
    NSString *keyPath;
}

- (id)initWithKeyPath:(NSString *)aKeyPath;

- (NSString *)keyPath;

@end

#pragma mark -

@interface BDSKRichValueTemplateTag : BDSKValueTemplateTag {
    NSDictionary *attributes;
}

- (id)initWithKeyPath:(NSString *)aKeyPath attributes:(NSDictionary *)anAttributes;

- (NSDictionary *)attributes;

@end

#pragma mark -

@interface BDSKCollectionTemplateTag : BDSKValueTemplateTag {
    BDSKPlaceholderTemplateTag *itemPlaceholderTemplate;
    BDSKPlaceholderTemplateTag *separatorPlaceholderTemplate;
    NSArray *itemTemplate;
    NSArray *separatorTemplate;
}

- (id)initWithKeyPath:(NSString *)aKeyPath itemTemplate:(BDSKPlaceholderTemplateTag *)anItemTemplate separatorTemplate:(BDSKPlaceholderTemplateTag *)aSeparatorTemplate;

- (NSArray *)itemTemplate;
- (NSArray *)separatorTemplate;

@end

#pragma mark -

@interface BDSKRichCollectionTemplateTag : BDSKValueTemplateTag {
    BDSKRichPlaceholderTemplateTag *itemPlaceholderTemplate;
    BDSKRichPlaceholderTemplateTag *separatorPlaceholderTemplate;
    NSArray *itemTemplate;
    NSArray *separatorTemplate;
}

- (id)initWithKeyPath:(NSString *)aKeyPath itemTemplate:(BDSKRichPlaceholderTemplateTag *)anItemTemplate separatorTemplate:(BDSKRichPlaceholderTemplateTag *)aSeparatorTemplate;

- (NSArray *)itemTemplate;
- (NSArray *)separatorTemplate;

@end

#pragma mark -

@interface BDSKConditionTemplateTag : BDSKValueTemplateTag {
    BDSKTemplateTagMatchType matchType;
    NSMutableArray *subtemplates;
    NSArray *matchStrings;
}

- (id)initWithKeyPath:(NSString *)aKeyPath matchType:(BDSKTemplateTagMatchType)aMatchType matchStrings:(NSArray *)aMatchStrings subtemplates:(NSArray *)aSubtemplates;

- (BDSKTemplateTagMatchType)matchType;
- (NSArray *)matchStrings;
- (NSArray *)subtemplates;
- (NSArray *)subtemplateAtIndex:(unsigned)idx;

@end

#pragma mark -

@interface BDSKRichConditionTemplateTag : BDSKConditionTemplateTag
@end

#pragma mark -

@interface BDSKTextTemplateTag : BDSKTemplateTag {
    NSString *text;
}

- (id)initWithText:(NSString *)aText;

- (NSString *)text;
- (void)setText:(NSString *)newText;

@end

#pragma mark -

@interface BDSKRichTextTemplateTag : BDSKTemplateTag {
    NSAttributedString *attributedText;
}

- (id)initWithAttributedText:(NSAttributedString *)anAttributedText;

- (NSAttributedString *)attributedText;
- (void)setAttributedText:(NSAttributedString *)newAttributedText;

@end

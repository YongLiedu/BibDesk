//
//  BDSKToken.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/8/07.
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

#import "BDSKToken.h"
#import "BDSKTemplateDocument.h"
#import "BDSKStringConstants.h"
#import "BDSKTypeManager.h"

#define EQUAL_OR_NIL_STRINGS(string1, string2) ( (string1 == nil && string2 == nil) || [string1 isEqualToString:string2] )

#define TITLE_KEY @"title"
#define FONTNAME_KEY @"fontName"
#define FONTSIZE_KEY @"fontSize"
#define BOLD_KEY @"bold"
#define ITALIC_KEY @"italic"
#define KEY_KEY @"key"
#define APPENDINGKEY_KEY @"appendingKey"
#define PREFIX_KEY @"prefix"
#define SUFFIX_KEY @"suffix"
#define CASINGKEY_KEY @"casingKey"
#define CLEANINGKEY_KEY @"cleaningKey"
#define URLFORMATKEY_KEY @"urlFormatKey"
#define NAMESTYLEKEY_KEY @"nameStyleKey"
#define JOINSTYLEKEY_KEY @"joinStyleKey"
#define LINKEDFILEFORMATKEY_KEY @"linkedFileFormatKey"
#define LINKEDFILEJOINSTYLEKEY_KEY @"linkedFileJoinStyleKey"
#define DATEFORMATKEY_KEY @"dateFormatKey"
#define COUNTERSTYLEKEY_KEY @"counterStyleKey"
#define COUNTERCASINGKEY_KEY @"counterCasingKey"
#define FIELD_KEY @"field"
#define ALTTEXT_KEY @"altText"


NSString *BDSKRichTextString = @"Rich Text";

@implementation BDSKToken

+ (id)tokenWithField:(NSString *)field {
    id tag = nil;
    if ([field isPersonField]) {
        tag = [[BDSKPersonTagToken alloc] initWithTitle:field];
        if ([field isEqualToString:BDSKAuthorString])
            [tag setKey:@"authors"];
        else if ([field isEqualToString:BDSKEditorString])
            [tag setKey:@"editors"];
    } else if ([field isEqualToString:BDSKLocalFileString]) {
        tag = [[BDSKLinkedFileTagToken alloc] initWithTitle:BDSKLocalFileString];
        [tag setKey:@"localFiles"];
    } else if ([field isEqualToString:BDSKRemoteURLString]) {
        tag = [[BDSKLinkedFileTagToken alloc] initWithTitle:BDSKRemoteURLString];
        [tag setKey:@"remoteURLs"];
    } else if ([field isURLField]) {
        tag = [[BDSKURLTagToken alloc] initWithTitle:field];
    } else if ([field isEqualToString:BDSKRichTextString]) {
        tag = [[BDSKTextToken alloc] initWithTitle:NSLocalizedString(@"Rich Text", @"Name for template token")];
    } else if ([field isEqualToString:BDSKDateAddedString] || [field isEqualToString:BDSKDateModifiedString] || [field isEqualToString:BDSKPubDateString]) {
        tag = [[BDSKDateTagToken alloc] initWithTitle:field];
        if ([field isEqualToString:BDSKDateAddedString])
            [tag setKey:@"dateAdded"];
        else if ([field isEqualToString:BDSKDateModifiedString])
            [tag setKey:@"dateModified"];
        else if ([field isEqualToString:BDSKPubDateString])
            [tag setKey:@"date"];
    } else if ([field isEqualToString:BDSKItemNumberString]) {
        tag = [[BDSKNumberTagToken alloc] initWithTitle:field];
        if ([field isEqualToString:BDSKItemNumberString])
            [tag setKey:@"itemIndex"];
    } else {
        tag = [[BDSKFieldTagToken alloc] initWithTitle:field];
        if ([field isEqualToString:BDSKPubTypeString])
            [tag setKey:@"pubType"];
        else  if ([field isEqualToString:BDSKCiteKeyString])
            [tag setKey:@"citeKey"];
    }
    
    return [tag autorelease];
}

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super init]) {
        title = [aTitle copy];
        fontName = nil;
        fontSize = 0.0;
        bold = NSMixedState;
        italic = NSMixedState;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        title = [[decoder decodeObjectForKey:TITLE_KEY] retain];
        fontName = [[decoder decodeObjectForKey:FONTNAME_KEY] retain];
        fontSize = [decoder decodeDoubleForKey:FONTSIZE_KEY];
        bold = [decoder decodeIntegerForKey:BOLD_KEY];
        italic = [decoder decodeIntegerForKey:ITALIC_KEY];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:title forKey:TITLE_KEY];
    [encoder encodeObject:fontName forKey:FONTNAME_KEY];
    [encoder encodeDouble:fontSize forKey:FONTSIZE_KEY];
    [encoder encodeInteger:bold forKey:BOLD_KEY];
    [encoder encodeInteger:italic forKey:ITALIC_KEY];
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKToken *copy = [[[self class] allocWithZone:aZone] initWithTitle:title];
    [copy setFontName:fontName];
    [copy setFontSize:fontSize];
    [copy setBold:bold];
    [copy setItalic:italic];
    return copy;
}

- (void)dealloc {
    BDSKDESTROY(title);
    BDSKDESTROY(fontName);
    [super dealloc];
}

- (BOOL)isEqual:(id)other {
    return [self isMemberOfClass:[other class]] &&
           EQUAL_OR_NIL_STRINGS(title, [other title]) &&
           EQUAL_OR_NIL_STRINGS(fontName, [other fontName]) &&
           fabs(fontSize - [other fontSize]) < 0.00001 &&
           bold == [other bold] &&
           italic == [other italic];
}

- (NSUInteger)hash {
    return [title hash] + [fontName hash] + ((NSUInteger)fontSize >> 4) + (bold >> 5) + (italic >> 6);
}

- (BDSKTokenType)type {
    return -1;
}

- (NSString *)title {
    return title;
}

- (NSString *)fontName {
    return fontName;
}

- (void)setFontName:(NSString *)newFontName {
    if (fontName != newFontName) {
        [fontName release];
        fontName = [newFontName retain];
    }
}

- (CGFloat)fontSize {
    return fontSize;
}

- (void)setFontSize:(CGFloat)newFontSize {
    if (fabs(fontSize - newFontSize) > 0.0) {
        fontSize = newFontSize;
    }
}

- (NSInteger)bold {
    return bold;
}

- (void)setBold:(NSInteger)newBold {
    if (bold != newBold) {
        bold = newBold;
    }
}

- (NSInteger)italic {
    return italic;
}

- (void)setItalic:(NSInteger)newItalic {
    if (italic != newItalic) {
        italic = newItalic;
    }
}

- (NSString *)string {
    return nil;
}

- (NSAttributedString *)attributedStringWithDefaultAttributes:(NSDictionary *)attributes {
    NSFontManager *fm = [NSFontManager sharedFontManager];
    NSAttributedString *attrString = nil;
    NSMutableDictionary *attrs = [attributes mutableCopy];
    NSFont *font = [attrs objectForKey:NSFontAttributeName];
    NSInteger traits = [fm traitsOfFont:font];
    BOOL wasBold = (traits & NSBoldFontMask) != 0;
    BOOL wasItalic = (traits & NSItalicFontMask) != 0;
    BOOL useBold = bold == NSMixedState ? wasBold : bold;
    BOOL useItalic = italic == NSMixedState ? wasItalic : italic;
    
    if (fontName)
        font = [NSFont fontWithName:fontName size:fontSize > 0.0 ? fontSize : [font pointSize]];
    else if (fontSize > 0.0)
        font = [fm convertFont:font toSize:fontSize];
    if (fontName || useBold != wasBold)
        font = [fm convertFont:font toHaveTrait:useBold ? NSBoldFontMask : NSUnboldFontMask];
    if (fontName || useItalic != wasItalic)
        font = [fm convertFont:font toHaveTrait:useItalic ? NSItalicFontMask : NSUnitalicFontMask];
    
    [attrs setObject:font forKey:NSFontAttributeName];
    attrString = [[[NSAttributedString alloc] initWithString:[self string] attributes:attrs] autorelease];
    [attrs release];
    
    return attrString;
}

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *keys = nil;
    if (keys == nil)
        keys = [[NSSet alloc] initWithObjects:FONTNAME_KEY, FONTSIZE_KEY, BOLD_KEY, ITALIC_KEY, nil];
    return keys;
}

// used for undo, because you cannot register setValue:forKey:
- (void)setKey:(NSString *)aKey toValue:(id)aValue {
    [self setValue:aValue forKey:aKey];
}

// Needed as any option control binds to any type of token
- (id)valueForUndefinedKey:(NSString *)key { return nil; }

@end

#pragma mark -

@implementation BDSKTagToken

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super initWithTitle:aTitle]) {
        key = nil;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        key = [[decoder decodeObjectForKey:KEY_KEY] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:key forKey:KEY_KEY];
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKTagToken *copy = [super copyWithZone:aZone];
    [copy setKey:key];
    return copy;
}

- (void)dealloc {
    BDSKDESTROY(key);
    [super dealloc];
}

- (BOOL)isEqual:(id)other {
    return [super isEqual:other] &&
           EQUAL_OR_NIL_STRINGS(key, [other key]);
}

- (NSUInteger)hash {
    return [super hash] + [key hash];
}

- (NSString *)key {
    return key;
}

- (void)setKey:(NSString *)newKey {
    if (key != newKey) {
        [key release];
        key = [newKey retain];
    }
}

- (NSArray *)keys {
    if (key)
        return [NSArray arrayWithObjects:key, nil];
    else
        return [NSArray arrayWithObjects:@"fields", title, nil];
}

- (NSString *)string {
    return [NSString stringWithFormat:@"<$%@/>", [[self keys] componentsJoinedByString:@"."]];
}

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *keys = nil;
    if (keys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys addObject:KEY_KEY];
        keys = [mutableKeys copy];
        [mutableKeys release];
    }
    return keys;
}

@end

#pragma mark -

@implementation BDSKValueTagToken

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super initWithTitle:aTitle]) {
        appendingKey = nil;
        prefix = nil;
        suffix = nil;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        appendingKey = [[decoder decodeObjectForKey:APPENDINGKEY_KEY] retain];
        prefix = [[decoder decodeObjectForKey:PREFIX_KEY] retain];
        suffix = [[decoder decodeObjectForKey:SUFFIX_KEY] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:appendingKey forKey:APPENDINGKEY_KEY];
    [encoder encodeObject:prefix forKey:PREFIX_KEY];
    [encoder encodeObject:suffix forKey:SUFFIX_KEY];
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKValueTagToken *copy = [super copyWithZone:aZone];
    [copy setAppendingKey:appendingKey];
    [copy setPrefix:prefix];
    [copy setSuffix:suffix];
    return copy;
}

- (void)dealloc {
    BDSKDESTROY(appendingKey);
    BDSKDESTROY(prefix);
    BDSKDESTROY(suffix);
    [super dealloc];
}

- (BOOL)isEqual:(id)other {
    return [super isEqual:other] &&
           EQUAL_OR_NIL_STRINGS(appendingKey, [other appendingKey]) &&
           EQUAL_OR_NIL_STRINGS(prefix, [other prefix]) &&
           EQUAL_OR_NIL_STRINGS(suffix, [other suffix]);
}

- (NSUInteger)hash {
    return [super hash] + [appendingKey hash] + [prefix hash] + [suffix hash];
}

- (NSString *)appendingKey {
    return appendingKey;
}

- (void)setAppendingKey:(NSString *)newAppendingKey {
    if (appendingKey != newAppendingKey) {
        [appendingKey release];
        appendingKey = [newAppendingKey retain];
    }
}

- (NSString *)prefix {
    return prefix;
}

- (void)setPrefix:(NSString *)newPrefix {
    if (prefix != newPrefix) {
        [prefix release];
        prefix = [newPrefix retain];
    }
}

- (NSString *)suffix {
    return suffix;
}

- (void)setSuffix:(NSString *)newSuffix {
    if (suffix != newSuffix) {
        [suffix release];
        suffix = [newSuffix retain];
    }
}

- (NSArray *)keys {
    NSMutableArray *keys = [NSMutableArray array];
    
    if (key) {
        [keys addObject:key];
    } else {
        [keys addObject:@"fields"];
        [keys addObject:title];
    }
    if ([appendingKey length])
        [keys addObject:appendingKey];
    return keys;
}

- (NSString *)string {
    NSString *keyPath = [[self keys] componentsJoinedByString:@"."];
    if ([prefix length] || [suffix length]) {
        NSMutableString *string = [NSMutableString stringWithFormat:@"<$%@?>", keyPath];
        if ([prefix length])
            [string appendString:prefix];
        [string appendFormat:@"<$%@/>", keyPath];
        if ([suffix length])
            [string appendString:suffix];
        [string appendFormat:@"</$%@?>", keyPath];
        return string;
    } else {
        return [super string];
    }
}

- (NSAttributedString *)attributedString {
    NSFont *font = [NSFont fontWithName:fontName size:fontSize];
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil];
    return [[[NSAttributedString alloc] initWithString:[self string] attributes:attrs] autorelease];
}

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *keys = nil;
    if (keys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys addObject:APPENDINGKEY_KEY];
        [mutableKeys addObject:PREFIX_KEY];
        [mutableKeys addObject:SUFFIX_KEY];
        keys = [mutableKeys copy];
        [mutableKeys release];
    }
    return keys;
}

@end

#pragma mark -

@implementation BDSKFieldTagToken

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super initWithTitle:aTitle]) {
        casingKey = nil;
        cleaningKey = nil;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        casingKey = [[decoder decodeObjectForKey:CASINGKEY_KEY] retain];
        cleaningKey = [[decoder decodeObjectForKey:CLEANINGKEY_KEY] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:casingKey forKey:CASINGKEY_KEY];
    [encoder encodeObject:cleaningKey forKey:CLEANINGKEY_KEY];
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKFieldTagToken *copy = [super copyWithZone:aZone];
    [copy setCasingKey:casingKey];
    [copy setCleaningKey:cleaningKey];
    return copy;
}

- (void)dealloc {
    BDSKDESTROY(casingKey);
    BDSKDESTROY(cleaningKey);
    [super dealloc];
}

- (BOOL)isEqual:(id)other {
    return [super isEqual:other] &&
           EQUAL_OR_NIL_STRINGS(casingKey, [other casingKey]) &&
           EQUAL_OR_NIL_STRINGS(cleaningKey, [other cleaningKey]);
}

- (NSUInteger)hash {
    return [super hash] + [casingKey hash] + [cleaningKey hash];
}

- (BDSKTokenType)type {
    return BDSKFieldTokenType;
}

- (NSString *)casingKey {
    return casingKey;
}

- (void)setCasingKey:(NSString *)newCasingKey {
    if (casingKey != newCasingKey) {
        [casingKey release];
        casingKey = [newCasingKey retain];
    }
}

- (NSString *)cleaningKey {
    return cleaningKey;
}

- (void)setCleaningKey:(NSString *)newCleaningKey {
    if (cleaningKey != newCleaningKey) {
        [cleaningKey release];
        cleaningKey = [newCleaningKey retain];
    }
}

- (NSArray *)keys {
    NSMutableArray *keys = [NSMutableArray array];
    
    if (key) {
        [keys addObject:key];
    } else {
        [keys addObject:@"fields"];
        [keys addObject:title];
    }
    if ([casingKey length])
        [keys addObject:casingKey];
    if ([cleaningKey length])
        [keys addObject:cleaningKey];
    if ([appendingKey length])
        [keys addObject:appendingKey];
    return keys;
}

- (NSString *)string {
    NSString *keyPath = [[self keys] componentsJoinedByString:@"."];
    if ([prefix length] || [suffix length]) {
        NSMutableString *string = [NSMutableString stringWithFormat:@"<$%@?>", keyPath];
        if ([prefix length])
            [string appendString:prefix];
        [string appendFormat:@"<$%@/>", keyPath];
        if ([suffix length])
            [string appendString:suffix];
        [string appendFormat:@"</$%@?>", keyPath];
        return string;
    } else {
        return [super string];
    }
}

- (NSAttributedString *)attributedString {
    NSFont *font = [NSFont fontWithName:fontName size:fontSize];
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil];
    return [[[NSAttributedString alloc] initWithString:[self string] attributes:attrs] autorelease];
}

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *keys = nil;
    if (keys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys addObject:CASINGKEY_KEY];
        [mutableKeys addObject:CLEANINGKEY_KEY];
        keys = [mutableKeys copy];
        [mutableKeys release];
    }
    return keys;
}

@end

#pragma mark -

@implementation BDSKURLTagToken

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super initWithTitle:aTitle]) {
        urlFormatKey = [([aTitle isLocalFileField] ? @"path" : @"absoluteString" ) retain];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        urlFormatKey = [[decoder decodeObjectForKey:URLFORMATKEY_KEY] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:urlFormatKey forKey:URLFORMATKEY_KEY];
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKURLTagToken *copy = [super copyWithZone:aZone];
    [copy setUrlFormatKey:urlFormatKey];
    return copy;
}

- (void)dealloc {
    BDSKDESTROY(urlFormatKey);
    [super dealloc];
}

- (BOOL)isEqual:(id)other {
    return [super isEqual:other] &&
           EQUAL_OR_NIL_STRINGS(urlFormatKey, [other urlFormatKey]);
}

- (NSUInteger)hash {
    return [super hash] + [urlFormatKey hash];
}

- (BDSKTokenType)type {
    return BDSKURLTokenType;
}

- (NSString *)urlFormatKey {
    return urlFormatKey;
}

- (void)setUrlFormatKey:(NSString *)newUrlFormatKey {
    if (urlFormatKey != newUrlFormatKey) {
        [urlFormatKey release];
        urlFormatKey = [newUrlFormatKey retain];
    }
}

- (NSArray *)keys {
    NSMutableArray *keys = [NSMutableArray array];
    
    if (key) {
        [keys addObject:key];
    } else {
        [keys addObject:@"urls"];
        [keys addObject:title];
    }
    if ([urlFormatKey length])
        [keys addObject:urlFormatKey];
    if ([casingKey length])
        [keys addObject:casingKey];
    if ([cleaningKey length])
        [keys addObject:cleaningKey];
    if ([appendingKey length])
        [keys addObject:appendingKey];
    return keys;
}

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *keys = nil;
    if (keys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys addObject:URLFORMATKEY_KEY];
        keys = [mutableKeys copy];
        [mutableKeys release];
    }
    return keys;
}

@end

#pragma mark -

@implementation BDSKPersonTagToken

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super initWithTitle:aTitle]) {
        nameStyleKey = [@"name" retain];
        joinStyleKey = [@"@componentsJoinedByCommaAndAnd" retain];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        nameStyleKey = [[decoder decodeObjectForKey:NAMESTYLEKEY_KEY] retain];
        joinStyleKey = [[decoder decodeObjectForKey:JOINSTYLEKEY_KEY] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:nameStyleKey forKey:NAMESTYLEKEY_KEY];
    [encoder encodeObject:joinStyleKey forKey:JOINSTYLEKEY_KEY];
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKPersonTagToken *copy = [super copyWithZone:aZone];
    [copy setNameStyleKey:nameStyleKey];
    [copy setJoinStyleKey:joinStyleKey];
    return copy;
}

- (void)dealloc {
    BDSKDESTROY(nameStyleKey);
    BDSKDESTROY(joinStyleKey);
    [super dealloc];
}

- (BOOL)isEqual:(id)other {
    return [super isEqual:other] &&
           EQUAL_OR_NIL_STRINGS(nameStyleKey, [other nameStyleKey]) &&
           EQUAL_OR_NIL_STRINGS(joinStyleKey, [other joinStyleKey]);
}

- (NSUInteger)hash {
    return [super hash] + [nameStyleKey hash] + [joinStyleKey hash];
}

- (BDSKTokenType)type {
    return BDSKPersonTokenType;
}

- (NSString *)nameStyleKey {
    return [[nameStyleKey retain] autorelease];
}

- (void)setNameStyleKey:(NSString *)newNameStyleKey {
    if (nameStyleKey != newNameStyleKey) {
        [nameStyleKey release];
        nameStyleKey = [newNameStyleKey retain];
    }
}

- (NSString *)joinStyleKey {
    return [[joinStyleKey retain] autorelease];
}

- (void)setJoinStyleKey:(NSString *)newJoinStyleKey {
    if (joinStyleKey != newJoinStyleKey) {
        [joinStyleKey release];
        joinStyleKey = [newJoinStyleKey retain];
    }
}

- (NSArray *)keys {
    NSMutableArray *keys = [NSMutableArray array];
    
    if ([key length]) {
        [keys addObject:key];
    } else {
        [keys addObject:@"persons"];
        [keys addObject:title];
    }
    if ([nameStyleKey length])
        [keys addObject:nameStyleKey];
    if ([casingKey length])
        [keys addObject:casingKey];
    if ([cleaningKey length])
        [keys addObject:cleaningKey];
    if ([appendingKey length])
        [keys addObject:appendingKey];
    [keys addObject:joinStyleKey];
    return keys;
}

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *keys = nil;
    if (keys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys addObject:NAMESTYLEKEY_KEY];
        [mutableKeys addObject:JOINSTYLEKEY_KEY];
        keys = [mutableKeys copy];
        [mutableKeys release];
    }
    return keys;
}

@end

#pragma mark -

@implementation BDSKLinkedFileTagToken

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super initWithTitle:aTitle]) {
        linkedFileFormatKey = [([aTitle isEqualToString:BDSKLocalFileString] ? @"path" : @"URL.absoluteString" ) retain];
        linkedFileJoinStyleKey = [@"@firstObject" retain];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        linkedFileFormatKey = [[decoder decodeObjectForKey:LINKEDFILEFORMATKEY_KEY] retain];
        linkedFileJoinStyleKey = [[decoder decodeObjectForKey:LINKEDFILEJOINSTYLEKEY_KEY] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:linkedFileFormatKey forKey:LINKEDFILEFORMATKEY_KEY];
    [encoder encodeObject:linkedFileJoinStyleKey forKey:LINKEDFILEJOINSTYLEKEY_KEY];
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKLinkedFileTagToken *copy = [super copyWithZone:aZone];
    [copy setLinkedFileFormatKey:linkedFileFormatKey];
    [copy setLinkedFileJoinStyleKey:linkedFileJoinStyleKey];
    return copy;
}

- (void)dealloc {
    BDSKDESTROY(linkedFileFormatKey);
    BDSKDESTROY(linkedFileJoinStyleKey);
    [super dealloc];
}

- (BOOL)isEqual:(id)other {
    return [super isEqual:other] &&
           EQUAL_OR_NIL_STRINGS(linkedFileFormatKey, [other linkedFileFormatKey]) &&
           EQUAL_OR_NIL_STRINGS(linkedFileJoinStyleKey, [other linkedFileJoinStyleKey]);
}

- (NSUInteger)hash {
    return [super hash] + [linkedFileFormatKey hash] + [linkedFileJoinStyleKey hash];
}

- (BDSKTokenType)type {
    return BDSKLinkedFileTokenType;
}


- (NSString *)linkedFileFormatKey {
    return [[linkedFileFormatKey retain] autorelease];
}

- (void)setLinkedFileFormatKey:(NSString *)newLinkedFileFormatKey {
    if (linkedFileFormatKey != newLinkedFileFormatKey) {
        [linkedFileFormatKey release];
        linkedFileFormatKey = [newLinkedFileFormatKey retain];
    }
}

- (NSString *)linkedFileJoinStyleKey {
    return [[linkedFileJoinStyleKey retain] autorelease];
}

- (void)setLinkedFileJoinStyleKey:(NSString *)newLinkedFileJoinStyleKey {
    if (linkedFileJoinStyleKey != newLinkedFileJoinStyleKey) {
        [linkedFileJoinStyleKey release];
        linkedFileJoinStyleKey = [newLinkedFileJoinStyleKey retain];
    }
}

- (NSArray *)keys {
    NSMutableArray *keys = [NSMutableArray array];
    
    if (key) {
        [keys addObject:key];
    } else {
        // shouldn't happen
        [keys addObject:@"fields"];
        [keys addObject:title];
    }
    if ([linkedFileFormatKey length])
        [keys addObject:linkedFileFormatKey];
    if ([appendingKey length])
        [keys addObject:appendingKey];
    [keys addObject:linkedFileJoinStyleKey];
    return keys;
}

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *keys = nil;
    if (keys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys addObject:LINKEDFILEFORMATKEY_KEY];
        [mutableKeys addObject:LINKEDFILEJOINSTYLEKEY_KEY];
        keys = [mutableKeys copy];
        [mutableKeys release];
    }
    return keys;
}

@end

#pragma mark -

@implementation BDSKDateTagToken

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super initWithTitle:aTitle]) {
        dateFormatKey = [@"description" retain];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        dateFormatKey = [[decoder decodeObjectForKey:DATEFORMATKEY_KEY] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:dateFormatKey forKey:DATEFORMATKEY_KEY];
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKDateTagToken *copy = [super copyWithZone:aZone];
    [copy setDateFormatKey:dateFormatKey];
    return copy;
}

- (void)dealloc {
    BDSKDESTROY(dateFormatKey);
    [super dealloc];
}

- (BOOL)isEqual:(id)other {
    return [super isEqual:other] &&
           EQUAL_OR_NIL_STRINGS(dateFormatKey, [other dateFormatKey]);
}

- (NSUInteger)hash {
    return [super hash] + [dateFormatKey hash];
}

- (BDSKTokenType)type {
    return BDSKDateTokenType;
}

- (NSString *)dateFormatKey {
    return dateFormatKey;
}

- (void)setDateFormatKey:(NSString *)newDateFormatKey {
    if (dateFormatKey != newDateFormatKey) {
        [dateFormatKey release];
        dateFormatKey = [newDateFormatKey retain];
    }
}

- (NSArray *)keys {
    NSMutableArray *keys = [NSMutableArray array];
    
    if (key) {
        [keys addObject:key];
    } else {
        [keys addObject:@"fields"];
        [keys addObject:title];
    }
    if ([dateFormatKey length])
        [keys addObject:dateFormatKey];
    if ([casingKey length])
        [keys addObject:casingKey];
    if ([cleaningKey length])
        [keys addObject:cleaningKey];
    if ([appendingKey length])
        [keys addObject:appendingKey];
    return keys;
}

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *keys = nil;
    if (keys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys addObject:DATEFORMATKEY_KEY];
        keys = [mutableKeys copy];
        [mutableKeys release];
    }
    return keys;
}

@end

#pragma mark -

@implementation BDSKNumberTagToken

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super initWithTitle:aTitle]) {
        counterStyleKey = nil;
        counterCasingKey = nil;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        counterStyleKey = [[decoder decodeObjectForKey:COUNTERSTYLEKEY_KEY] retain];
        counterCasingKey = [[decoder decodeObjectForKey:COUNTERCASINGKEY_KEY] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:counterStyleKey forKey:COUNTERSTYLEKEY_KEY];
    [encoder encodeObject:counterCasingKey forKey:COUNTERCASINGKEY_KEY];
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKNumberTagToken *copy = [super copyWithZone:aZone];
    [copy setCounterStyleKey:counterStyleKey];
    [copy setCounterCasingKey:counterCasingKey];
    return copy;
}

- (void)dealloc {
    BDSKDESTROY(counterStyleKey);
    BDSKDESTROY(counterCasingKey);
    [super dealloc];
}

- (BOOL)isEqual:(id)other {
    return [super isEqual:other] &&
           EQUAL_OR_NIL_STRINGS(counterStyleKey, [other counterStyleKey]) &&
           EQUAL_OR_NIL_STRINGS(counterCasingKey, [other counterCasingKey]);
}

- (NSUInteger)hash {
    return [super hash] + [counterStyleKey hash] + [counterCasingKey hash];
}

- (BDSKTokenType)type {
    return BDSKNumberTokenType;
}

- (NSString *)counterStyleKey {
    return counterStyleKey;
}

- (void)setCounterStyleKey:(NSString *)newCounterStyleKey {
    if (counterStyleKey != newCounterStyleKey) {
        [counterStyleKey release];
        counterStyleKey = [newCounterStyleKey retain];
    }
}

- (NSString *)counterCasingKey {
    return counterCasingKey;
}

- (void)setCounterCasingKey:(NSString *)newCounterCasingKey {
    if (counterCasingKey != newCounterCasingKey) {
        [counterCasingKey release];
        counterCasingKey = [newCounterCasingKey retain];
    }
}

- (NSArray *)keys {
    NSMutableArray *keys = [NSMutableArray array];
    
    if (key) {
        [keys addObject:key];
    } else {
        [keys addObject:@"fields"];
        [keys addObject:title];
    }
    if ([counterStyleKey length])
        [keys addObject:counterStyleKey];
    if ([counterCasingKey length])
        [keys addObject:counterCasingKey];
    return keys;
}

- (NSString *)string {
    return [NSString stringWithFormat:@"<$%@/>", [[self keys] componentsJoinedByString:@"."]];
}

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *keys = nil;
    if (keys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys addObject:COUNTERSTYLEKEY_KEY];
        [mutableKeys addObject:COUNTERCASINGKEY_KEY];
        keys = [mutableKeys copy];
        [mutableKeys release];
    }
    return keys;
}

@end

#pragma mark -

@implementation BDSKTextToken

- (id)initWithTitle:(NSString *)aTitle {
    if (self = [super initWithTitle:aTitle]) {
        field = nil;
        altText = [@"" retain];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        field = [[decoder decodeObjectForKey:FIELD_KEY] retain];
        altText = [[decoder decodeObjectForKey:ALTTEXT_KEY] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:field forKey:FIELD_KEY];
    [encoder encodeObject:altText forKey:ALTTEXT_KEY];
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKTextToken *copy = [super copyWithZone:aZone];
    [copy setField:field];
    [copy setAltText:altText];
    return copy;
}

- (void)dealloc {
    BDSKDESTROY(field);
    BDSKDESTROY(altText);
    [super dealloc];
}

- (BOOL)isEqual:(id)other {
    return [super isEqual:other] &&
           EQUAL_OR_NIL_STRINGS(field, [other field]) &&
           EQUAL_OR_NIL_STRINGS(altText, [other altText]);
}

- (NSUInteger)hash {
    return [super hash] + [field hash] + [altText hash];
}

- (BDSKTokenType)type {
    return BDSKTextTokenType;
}

- (void)setTitle:(NSString *)newTitle {
    if (newTitle == nil)
        newTitle = @"";
    if (title != newTitle) {
        [title release];
        title = [newTitle retain];
    }
}

- (NSString *)field {
    return field;
}

- (void)setField:(NSString *)newField {
    if (field != newField) {
        [field release];
        field = [newField retain];
    }
}

- (NSString *)altText {
    return altText;
}

- (void)setAltText:(NSString *)newAltText {
    if (altText != newAltText) {
        [altText release];
        altText = [newAltText retain];
    }
}

- (NSString *)string {
    if ([field length]) {
        NSMutableString *string = [NSMutableString stringWithFormat:@"<$%@?>%@", field, title];
        if ([altText length])
            [string appendFormat:@"<?$%@?>%@", field, altText];
        [string appendFormat:@"</$%@?>", field];
        return string;
    } else {
        return title;
    }
}

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *keys = nil;
    if (keys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys addObject:FIELD_KEY];
        [mutableKeys addObject:ALTTEXT_KEY];
        keys = [mutableKeys copy];
        [mutableKeys release];
    }
    return keys;
}

@end

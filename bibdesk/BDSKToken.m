//
//  BDSKToken.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/8/07.
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

#import "BDSKToken.h"
#import "BDSKTemplateDocument.h"
#import "BDSKStringConstants.h"
#import "BDSKTypeManager.h"

#define EQUAL_OR_NIL_STRINGS(string1, string2) ( (string1 == nil && string2 == nil) || [string1 isEqualToString:string2] )

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
        if ([field isEqualToString:BDSKPubDateString])
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
        title = [[decoder decodeObjectForKey:@"title"] retain];
        fontName = [[decoder decodeObjectForKey:@"fontName"] retain];
        fontSize = [decoder decodeDoubleForKey:@"fontSize"];
        bold = [decoder decodeIntegerForKey:@"bold"];
        italic = [decoder decodeIntegerForKey:@"italic"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:title forKey:@"title"];
    [encoder encodeObject:fontName forKey:@"fontName"];
    [encoder encodeDouble:fontSize forKey:@"fontSize"];
    [encoder encodeInteger:bold forKey:@"bold"];
    [encoder encodeInteger:italic forKey:@"italic"];
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKToken *copy = [[[self class] allocWithZone:aZone] initWithTitle:title];
    copy->fontName = [fontName retain];
    copy->fontSize = fontSize;
    copy->bold = bold;
    copy->italic = italic;
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

- (NSInteger)type {
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
        keys = [[NSSet alloc] initWithObjects:@"fontName", @"fontSize", @"bold", @"italic", nil];
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
        if ([decoder allowsKeyedCoding]) {
            key = [[decoder decodeObjectForKey:@"key"] retain];
        } else {
            key = [[decoder decodeObject] retain];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    if ([encoder allowsKeyedCoding]) {
        [encoder encodeObject:key forKey:@"key"];
    } else {
        [encoder encodeObject:key];
    }
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKTagToken *copy = [super copyWithZone:aZone];
    copy->key = [key retain];
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
        [mutableKeys addObject:@"key"];
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
        if ([decoder allowsKeyedCoding]) {
            appendingKey = [[decoder decodeObjectForKey:@"appendingKey"] retain];
            prefix = [[decoder decodeObjectForKey:@"prefix"] retain];
            suffix = [[decoder decodeObjectForKey:@"suffix"] retain];
        } else {
            appendingKey = [[decoder decodeObject] retain];
            prefix = [[decoder decodeObject] retain];
            suffix = [[decoder decodeObject] retain];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    if ([encoder allowsKeyedCoding]) {
        [encoder encodeObject:appendingKey forKey:@"appendingKey"];
        [encoder encodeObject:prefix forKey:@"prefix"];
        [encoder encodeObject:suffix forKey:@"suffix"];
    } else {
        [encoder encodeObject:appendingKey];
        [encoder encodeObject:prefix];
        [encoder encodeObject:suffix];
    }
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKValueTagToken *copy = [super copyWithZone:aZone];
    copy->appendingKey = [appendingKey retain];
    copy->prefix = [prefix retain];
    copy->suffix = [suffix retain];
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
        [mutableKeys addObject:@"appendingKey"];
        [mutableKeys addObject:@"prefix"];
        [mutableKeys addObject:@"suffix"];
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
        appendingKey = nil;
        prefix = nil;
        suffix = nil;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        if ([decoder allowsKeyedCoding]) {
            casingKey = [[decoder decodeObjectForKey:@"casingKey"] retain];
            cleaningKey = [[decoder decodeObjectForKey:@"cleaningKey"] retain];
        } else {
            casingKey = [[decoder decodeObject] retain];
            cleaningKey = [[decoder decodeObject] retain];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    if ([encoder allowsKeyedCoding]) {
        [encoder encodeObject:casingKey forKey:@"casingKey"];
        [encoder encodeObject:cleaningKey forKey:@"cleaningKey"];
    } else {
        [encoder encodeObject:casingKey];
        [encoder encodeObject:cleaningKey];
        [encoder encodeObject:appendingKey];
        [encoder encodeObject:prefix];
        [encoder encodeObject:suffix];
    }
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKFieldTagToken *copy = [super copyWithZone:aZone];
    copy->casingKey = [casingKey retain];
    copy->cleaningKey = [cleaningKey retain];
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

- (NSInteger)type {
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
        [mutableKeys addObject:@"casingKey"];
        [mutableKeys addObject:@"cleaningKey"];
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
        if ([decoder allowsKeyedCoding]) {
            urlFormatKey = [[decoder decodeObjectForKey:@"urlFormatKey"] retain];
        } else {
            urlFormatKey = [[decoder decodeObject] retain];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    if ([encoder allowsKeyedCoding]) {
        [encoder encodeObject:urlFormatKey forKey:@"urlFormatKey"];
    } else {
        [encoder encodeObject:urlFormatKey];
    }
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKURLTagToken *copy = [super copyWithZone:aZone];
    copy->urlFormatKey = [urlFormatKey retain];
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

- (NSInteger)type {
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
        [mutableKeys addObject:@"urlFormatKey"];
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
        if ([decoder allowsKeyedCoding]) {
            nameStyleKey = [[decoder decodeObjectForKey:@"nameStyleKey"] retain];
            joinStyleKey = [[decoder decodeObjectForKey:@"joinStyleKey"] retain];
        } else {
            nameStyleKey = [[decoder decodeObject] retain];
            joinStyleKey = [[decoder decodeObject] retain];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    if ([encoder allowsKeyedCoding]) {
        [encoder encodeObject:nameStyleKey forKey:@"nameStyleKey"];
        [encoder encodeObject:joinStyleKey forKey:@"joinStyleKey"];
    } else {
        [encoder encodeObject:nameStyleKey];
        [encoder encodeObject:joinStyleKey];
    }
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKPersonTagToken *copy = [super copyWithZone:aZone];
    copy->nameStyleKey = [nameStyleKey retain];
    copy->joinStyleKey = [joinStyleKey retain];
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

- (NSInteger)type {
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
        [mutableKeys addObject:@"nameStyleKey"];
        [mutableKeys addObject:@"joinStyleKey"];
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
        if ([decoder allowsKeyedCoding]) {
            linkedFileFormatKey = [[decoder decodeObjectForKey:@"linkedFileFormatKey"] retain];
            linkedFileJoinStyleKey = [[decoder decodeObjectForKey:@"linkedFileJoinStyleKey"] retain];
        } else {
            linkedFileFormatKey = [[decoder decodeObject] retain];
            linkedFileJoinStyleKey = [[decoder decodeObject] retain];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    if ([encoder allowsKeyedCoding]) {
        [encoder encodeObject:linkedFileFormatKey forKey:@"linkedFileFormatKey"];
        [encoder encodeObject:linkedFileJoinStyleKey forKey:@"linkedFileJoinStyleKey"];
    } else {
        [encoder encodeObject:linkedFileFormatKey];
        [encoder encodeObject:linkedFileJoinStyleKey];
    }
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKLinkedFileTagToken *copy = [super copyWithZone:aZone];
    copy->linkedFileFormatKey = [linkedFileFormatKey retain];
    copy->linkedFileJoinStyleKey = [linkedFileJoinStyleKey retain];
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

- (NSInteger)type {
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
        [mutableKeys addObject:@"linkedFileFormatKey"];
        [mutableKeys addObject:@"linkedFileJoinStyleKey"];
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
        if ([decoder allowsKeyedCoding]) {
            dateFormatKey = [[decoder decodeObjectForKey:@"dateFormatKey"] retain];
        } else {
            dateFormatKey = [[decoder decodeObject] retain];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    if ([encoder allowsKeyedCoding]) {
        [encoder encodeObject:dateFormatKey forKey:@"dateFormatKey"];
    } else {
        [encoder encodeObject:dateFormatKey];
    }
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKDateTagToken *copy = [super copyWithZone:aZone];
    copy->dateFormatKey = [dateFormatKey retain];
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

- (NSInteger)type {
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
        [mutableKeys addObject:@"dateFormatKey"];
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
        if ([decoder allowsKeyedCoding]) {
            counterStyleKey = [[decoder decodeObjectForKey:@"counterStyleKey"] retain];
            counterCasingKey = [[decoder decodeObjectForKey:@"counterCasingKey"] retain];
        } else {
            counterStyleKey = [[decoder decodeObject] retain];
            counterCasingKey = [[decoder decodeObject] retain];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    if ([encoder allowsKeyedCoding]) {
        [encoder encodeObject:counterStyleKey forKey:@"counterStyleKey"];
        [encoder encodeObject:counterCasingKey forKey:@"counterCasingKey"];
    } else {
        [encoder encodeObject:counterStyleKey];
        [encoder encodeObject:counterCasingKey];
    }
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKNumberTagToken *copy = [super copyWithZone:aZone];
    copy->counterStyleKey = [counterStyleKey retain];
    copy->counterCasingKey = [counterCasingKey retain];
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

- (NSInteger)type {
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
        [mutableKeys addObject:@"counterStyleKey"];
        [mutableKeys addObject:@"counterCasingKey"];
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
        if ([decoder allowsKeyedCoding]) {
            field = [[decoder decodeObjectForKey:@"field"] retain];
            altText = [[decoder decodeObjectForKey:@"altText"] retain];
        } else {
            field = [[decoder decodeObject] retain];
            altText = [[decoder decodeObject] retain];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    if ([encoder allowsKeyedCoding]) {
        [encoder encodeObject:field forKey:@"field"];
        [encoder encodeObject:altText forKey:@"altText"];
    } else {
        [encoder encodeObject:field];
        [encoder encodeObject:altText];
    }
}

- (id)copyWithZone:(NSZone *)aZone {
    BDSKTextToken *copy = [super copyWithZone:aZone];
    copy->field = [field retain];
    copy->altText = [altText retain];
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

- (NSInteger)type {
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
        [mutableKeys addObject:@"title"];
        [mutableKeys addObject:@"field"];
        [mutableKeys addObject:@"altText"];
        keys = [mutableKeys copy];
        [mutableKeys release];
    }
    return keys;
}

@end

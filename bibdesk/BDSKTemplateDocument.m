//
//  BDSKTemplateDocument.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/8/07.
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

#import "BDSKTemplateDocument.h"
#import "BDSKToken.h"
#import "BDSKTypeTemplate.h"
#import "BDSKTypeManager.h"
#import "BDSKStringConstants.h"
#import "BDSKFieldNameFormatter.h"
#import "BDSKFieldSheetController.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKTemplateParser.h"
#import "BDSKTemplateTag.h"
#import "NSString_BDSKExtensions.h"
#import "NSCharacterSet_BDSKExtensions.h"
#import "BDSKRuntime.h"
#import "NSInvocation_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKPrintableView.h"

static CGFloat BDSKDefaultFontSizes[] = {8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0, 48.0, 64.0};

NSString *BDSKTextTemplateDocumentType = @"Text Template";
NSString *BDSKRichTextTemplateDocumentType = @"Rich Text Template";

#define BDSKTemplateDocumentFrameAutosaveName @"BDSKTemplateDocument"

#define BDSKTokenFieldDidChangeSelectionNotification @"BDSKTokenFieldDidChangeSelectionNotification"

#define BDSKTemplateTokensPboardType @"BDSKTemplateTokensPboardType"
#define BDSKTypeTemplateRowsPboardType @"BDSKTypeTemplateRowsPboardType"
#define BDSKValueOrNoneTransformerName @"BDSKValueOrNone"

@interface BDSKValueOrNoneTransformer : NSValueTransformer @end

@interface BDSKFlippedClipView : NSClipView @end

@interface BDSKTemplateDocument (BDSKPrivate)
- (void)updateTextViews;
- (void)updateTokenFields;
- (void)updateStrings;
- (void)updateOptionView;
- (void)setupOptionsMenus;
- (void)handleDidChangeSelectionNotification:(NSNotification *)notification;
- (void)handleDidEndEditingNotification:(NSNotification *)notification;
- (void)handleTokenDidChangeNotification:(NSNotification *)notification;
- (void)handleTemplateDidChangeNotification:(NSNotification *)notification;
- (NSDictionary *)convertPubTemplate:(NSArray *)templateArray defaultFont:(NSFont *)defaultFont;
- (NSArray *)convertItemTemplate:(NSArray *)templateArray defaultFont:(NSFont *)defaultFont;
- (NSArray *)tokensForTextTag:(BDSKTemplateTag *)tag allowText:(BOOL)allowText defaultFont:(NSFont *)defaultFont;
- (id)tokenForConditionTag:(BDSKConditionTemplateTag *)tag defaultFont:(NSFont *)defaultFont;
- (id)tokenForValueTag:(BDSKValueTemplateTag *)tag defaultFont:(NSFont *)defaultFont;
- (NSString *)propertyForKey:(NSString *)key tokenType:(NSInteger)type;
- (void)setFont:(NSFont *)font ofToken:(BDSKToken *)token defaultFont:(NSFont *)defaultFont;
@end

@implementation BDSKTemplateDocument

+ (NSSet *)keyPathsForValuesAffectingPreviewAttributedString {
    return [NSSet setWithObjects:@"attributedString", nil];
}

+ (void)initialize {
    BDSKINITIALIZE;
	[NSValueTransformer setValueTransformer:[[[BDSKValueOrNoneTransformer alloc] init] autorelease]
									forName:BDSKValueOrNoneTransformerName];
}

+ (NSArray *)writableTypes {
    return [NSArray arrayWithObjects:BDSKTextTemplateDocumentType, BDSKRichTextTemplateDocumentType, nil];
}

+ (NSArray *)nativeTypes {
    return [NSArray arrayWithObjects:BDSKTextTemplateDocumentType, BDSKRichTextTemplateDocumentType, nil];
}

- (id)init {
    if (self = [super init]) {
        NSFont *font = [NSFont userFontOfSize:0.0];
        
        specialTokens = [[NSMutableArray alloc] init];
        defaultTokens = [[NSMutableArray alloc] init];
        fieldTokens = [[NSMutableDictionary alloc] init];
        typeTemplates = [[NSMutableArray alloc] init];
        prefixTemplate = [[NSMutableAttributedString alloc] init];
        suffixTemplate = [[NSMutableAttributedString alloc] init];
        separatorTemplate = [[NSMutableAttributedString alloc] init];
        richText = NO;
        fontName = [font familyName];
        fontSize = [font pointSize];
        bold = NO;
        italic = NO;
        selectedToken = nil;
        defaultTypeIndex = 0;
        
        [self setFileType:BDSKTextTemplateDocumentType];
        
        NSMutableDictionary *tmpDict = [[NSMutableDictionary alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"TemplateOptions" ofType:@"plist"]];
        
        for (NSString *key in [tmpDict allKeys]) {
            NSMutableArray *array = [NSMutableArray array];
            for (NSDictionary *dict in [tmpDict objectForKey:key]) {
                dict = [dict mutableCopy];
                [(NSMutableDictionary *)dict setObject:[[NSBundle mainBundle] localizedStringForKey:[dict objectForKey:@"displayName"] value:@"" table:@"TemplateOptions"] forKey:@"displayName"];
                [array addObject:dict];
                [dict release];
            }
            [tmpDict setObject:array forKey:key];
        }
        templateOptions = [tmpDict copy];
        [tmpDict release];
        
        for (NSString *type in [[BDSKTypeManager sharedManager] bibTypesForFileType:BDSKBibtexString])
            [typeTemplates addObject:[[[BDSKTypeTemplate alloc] initWithPubType:type forDocument:self] autorelease]];
        
        defaultTypeIndex = [[typeTemplates valueForKey:@"pubType"] indexOfObject:BDSKArticleString];
        if (defaultTypeIndex == NSNotFound)
            defaultTypeIndex = 0;
        
        NSMutableArray *tmpFonts = [NSMutableArray array];
        NSMutableArray *fontNames = [[[[NSFontManager sharedFontManager] availableFontFamilies] mutableCopy] autorelease];
        
        [fontNames sortUsingSelector:@selector(caseInsensitiveCompare:)];
        for (NSString *name in fontNames) {
            font = [NSFont fontWithName:name size:0.0];
            [tmpFonts addObject:[NSDictionary dictionaryWithObjectsAndKeys:[font fontName], @"fontName", [font displayName], @"displayName", nil]];
        }
        fonts = [tmpFonts copy];
        [tmpFonts insertObject:[NSDictionary dictionaryWithObjectsAndKeys:@"<None>", @"fontName", NSLocalizedString(@"Same as body", @"Inerited font message in popup"), @"displayName", nil] atIndex:0];
        tokenFonts = [tmpFonts copy];
        
        NSString *field;
        
        for (field in [[BDSKTypeManager sharedManager] userDefaultFieldsForType:nil])
            [defaultTokens addObject:[self tokenForField:field]];
        
        for (field in [NSArray arrayWithObjects:BDSKPubTypeString, BDSKCiteKeyString, BDSKLocalFileString, BDSKRemoteURLString, BDSKItemNumberString, BDSKRichTextString, BDSKDateAddedString, BDSKDateModifiedString, BDSKPubDateString, nil])
            [specialTokens addObject:[self tokenForField:field]];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [specialTokens release];
    [defaultTokens release];
    [fieldTokens release];
    [typeTemplates release];
    [prefixTemplate release];
    [suffixTemplate release];
    [separatorTemplate release];
    [fontName release];
    [selectedToken release];
    [templateOptions release];
    [fonts release];
    [tokenFonts release];
    [string release];
    [attributedString release];
    [super dealloc];
}

- (NSString *)windowNibName {
    return @"TemplateDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];
    
    [aController setWindowFrameAutosaveNameOrCascade:BDSKTemplateDocumentFrameAutosaveName];
    
    NSRect frame = [itemTemplateTokenField frame];
    frame.size.height = 39.0;
    [itemTemplateTokenField setFrame:frame];
    
    [requiredTokenField setEditable:NO];
    [requiredTokenField setBezeled:NO];
    [requiredTokenField setDrawsBackground:NO];
    [requiredTokenField setObjectValue:[[typeTemplates objectAtIndex:defaultTypeIndex] requiredTokens]];
    [optionalTokenField setEditable:NO];
    [optionalTokenField setBezeled:NO];
    [optionalTokenField setDrawsBackground:NO];
    [optionalTokenField setObjectValue:[[typeTemplates objectAtIndex:defaultTypeIndex] optionalTokens]];
    [defaultTokenField setEditable:NO];
    [defaultTokenField setBezeled:NO];
    [defaultTokenField setDrawsBackground:NO];
    [defaultTokenField setObjectValue:defaultTokens];
    [specialTokenField setEditable:NO];
    [specialTokenField setBezeled:NO];
    [specialTokenField setDrawsBackground:NO];
    [specialTokenField setObjectValue:specialTokens];
    [itemTemplateTokenField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@""]];
    
    NSScrollView *scrollView = [specialTokenField enclosingScrollView];
    NSView *documentView = [[scrollView documentView] retain];
    NSClipView *clipView = [[BDSKFlippedClipView alloc] initWithFrame:[[scrollView contentView] frame]];
    [clipView setDrawsBackground:NO];
    [scrollView setContentView:clipView];
    [scrollView setDocumentView:documentView];
    [clipView release];
    [documentView release];
    
    [self updateTokenFields];
    [self updateTextViews];
    
    [self setupOptionsMenus];
    
    [tableView registerForDraggedTypes:[NSArray arrayWithObjects:BDSKTypeTemplateRowsPboardType, nil]];
    
	[fieldField setFormatter:[[[BDSKFieldNameFormatter alloc] init] autorelease]];
    
    [ownerController setContent:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidChangeSelectionNotification:) 
                                                 name:BDSKTokenFieldDidChangeSelectionNotification object:itemTemplateTokenField];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidChangeSelectionNotification:) 
                                                 name:BDSKTokenFieldDidChangeSelectionNotification object:specialTokenField];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidChangeSelectionNotification:) 
                                                 name:BDSKTokenFieldDidChangeSelectionNotification object:requiredTokenField];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidChangeSelectionNotification:) 
                                                 name:BDSKTokenFieldDidChangeSelectionNotification object:optionalTokenField];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidChangeSelectionNotification:) 
                                                 name:BDSKTokenFieldDidChangeSelectionNotification object:defaultTokenField];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidEndEditingNotification:) 
                                                 name:NSControlTextDidEndEditingNotification object:itemTemplateTokenField];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTokenDidChangeNotification:) 
                                                 name:BDSKTokenDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTemplateDidChangeNotification:) 
                                                 name:BDSKTemplateDidChangeNotification object:nil];
}

- (NSArray *)writableTypesForSaveOperation:(NSSaveOperationType)saveOperation {
    return [NSArray arrayWithObjects:richText ? BDSKRichTextTemplateDocumentType : BDSKTextTemplateDocumentType, nil];
}

- (BOOL)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError {
    BOOL success = [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
    if (success && richText == NO)
        [[NSFileManager defaultManager] setAppleStringEncoding:NSUTF8StringEncoding atPath:[absoluteURL path] error:NULL];
    return success;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    NSData *data = nil;
    if (richText) {
        NSAttributedString *attrString = [self attributedString];
        data = [attrString RTFFromRange:NSMakeRange(0, [attrString length]) documentAttributes:nil];
    } else {
        data = [[self string] dataUsingEncoding:NSUTF8StringEncoding];
    }
    return data;
}

static inline NSRange makeRange(NSUInteger start, NSUInteger end) {
    NSRange r;
    r.location = start;
    r.length = end - start;
    return r;
}

static inline NSUInteger startOfTrailingEmptyLine(NSString *string, NSRange range, BOOL requireNL) {
    NSRange lastCharRange = [string rangeOfCharacterFromSet:[NSCharacterSet nonWhitespaceCharacterSet] options:NSBackwardsSearch range:range];
    NSUInteger start = NSNotFound;
    if (lastCharRange.location != NSNotFound) {
        unichar lastChar = [string characterAtIndex:lastCharRange.location];
        NSUInteger rangeEnd = NSMaxRange(lastCharRange);
        if ([[NSCharacterSet newlineCharacterSet] characterIsMember:lastChar])
            start = rangeEnd;
    } else if (requireNL == NO) {
        start = range.location;
    }
    return start;
}

static inline NSUInteger endOfLeadingEmptyLine(NSString *string, NSRange range, BOOL requireNL) {
    NSRange firstCharRange = [string rangeOfCharacterFromSet:[NSCharacterSet nonWhitespaceCharacterSet] options:0 range:range];
    NSUInteger end = NSNotFound;
    if (firstCharRange.location != NSNotFound) {
        unichar firstChar = [string characterAtIndex:firstCharRange.location];
        NSUInteger rangeEnd = NSMaxRange(firstCharRange);
        if ([[NSCharacterSet newlineCharacterSet] characterIsMember:firstChar]) {
            if (firstChar == NSCarriageReturnCharacter && rangeEnd < NSMaxRange(range) && [string characterAtIndex:rangeEnd] == NSNewlineCharacter)
                end = rangeEnd + 1;
            else 
                end = rangeEnd;
        }
    } else if (requireNL == NO) {
        end = NSMaxRange(range);
    }
    return end;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    NSArray *parsedTemplate = nil;
    NSDictionary *templateDict = nil;
    NSFont *font = nil;
    NSAttributedString *attrString = nil;
    NSString *str = nil;
    NSRange startRange, endRange = { NSNotFound, 0 }, sepRange = { NSNotFound, 0 };
    NSUInteger length, startLoc = NSNotFound, tmpLoc;
    
    richText = [typeName isEqualToString:BDSKRichTextTemplateDocumentType];
    
    if ([self isRichText]) {
        attrString = [[[NSAttributedString alloc] initWithData:data options:nil documentAttributes:NULL error:NULL] autorelease];
        str = [attrString string];
    } else {
        str = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    }
    
    if (str) {
        length = [str length];
        
        startRange = [str rangeOfString:@"<$publications>"];
        
        if (startRange.location != NSNotFound) {
            startLoc = startRange.location;
            
            tmpLoc = startOfTrailingEmptyLine(str, makeRange(0, startRange.location), NO);
            if (tmpLoc != NSNotFound)
                startRange = makeRange(tmpLoc, NSMaxRange(startRange));
            tmpLoc = endOfLeadingEmptyLine(str, makeRange(NSMaxRange(startRange), length), YES);
            if (tmpLoc != NSNotFound)
                startRange = makeRange(startRange.location, tmpLoc);
            
            endRange = [str rangeOfString:@"</$publications>" options:NSBackwardsSearch range:makeRange(NSMaxRange(startRange), length)];
            
            if (endRange.location != NSNotFound) {
                tmpLoc = startOfTrailingEmptyLine(str, makeRange(NSMaxRange(startRange), endRange.location), YES);
                if (tmpLoc != NSNotFound)
                    endRange = makeRange(tmpLoc, NSMaxRange(endRange));
                tmpLoc = endOfLeadingEmptyLine(str, makeRange(NSMaxRange(endRange), length), NO);
                if (tmpLoc != NSNotFound)
                    endRange = makeRange(endRange.location, tmpLoc);
                
                sepRange = [str rangeOfString:@"<?$publications>" options:NSBackwardsSearch range:makeRange(NSMaxRange(startRange), endRange.location)];
                if (sepRange.location != NSNotFound) {
                    tmpLoc = startOfTrailingEmptyLine(str, makeRange(NSMaxRange(startRange), sepRange.location), YES);
                    if (tmpLoc != NSNotFound)
                        sepRange = makeRange(tmpLoc, NSMaxRange(sepRange));
                    tmpLoc = endOfLeadingEmptyLine(str, makeRange(NSMaxRange(sepRange), endRange.location), YES);
                    if (tmpLoc != NSNotFound)
                        sepRange = makeRange(sepRange.location, tmpLoc);
                }
            }
        }
        
        if (endRange.location != NSNotFound) {
            if ([self isRichText]) {
                if (startRange.location > 0)
                   [self setPrefixTemplate:[attrString attributedSubstringFromRange:makeRange(0, startRange.location)]];
                if (NSMaxRange(endRange) < length)
                    [self setSuffixTemplate:[attrString attributedSubstringFromRange:makeRange(NSMaxRange(endRange), length)]];
                if (NSMaxRange(sepRange) < endRange.location)
                    [self setSeparatorTemplate:[attrString attributedSubstringFromRange:makeRange(NSMaxRange(sepRange), endRange.location)]];
                
                parsedTemplate = [BDSKTemplateParser arrayByParsingTemplateAttributedString:[attrString attributedSubstringFromRange:makeRange(NSMaxRange(startRange), (sepRange.location == NSNotFound ? endRange.location : sepRange.location))]];
                
                font = [attrString attribute:NSFontAttributeName atIndex:startLoc effectiveRange:NULL] ?: [NSFont userFontOfSize:0.0];
                NSInteger traits = [[NSFontManager sharedFontManager] traitsOfFont:font];
                [self setFontName:[font familyName]];
                [self setFontSize:[font pointSize]];
                [self setBold:(traits & NSBoldFontMask) != 0];
                [self setItalic:(traits & NSItalicFontMask) != 0];
            } else {
                NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont userFontOfSize:0.0], NSFontAttributeName, nil];
                if (startRange.location > 0)
                    [self setPrefixTemplate:[[[NSAttributedString alloc] initWithString:[str substringWithRange:makeRange(0, startRange.location)] attributes:attrs] autorelease]];
                if (NSMaxRange(endRange) < length)
                    [self setSuffixTemplate:[[[NSAttributedString alloc] initWithString:[str substringWithRange:makeRange(NSMaxRange(endRange), length)] attributes:attrs] autorelease]];
                if (NSMaxRange(sepRange) < endRange.location)
                    [self setSeparatorTemplate:[[[NSAttributedString alloc] initWithString:[str substringWithRange:makeRange(NSMaxRange(sepRange), endRange.location)] attributes:attrs] autorelease]];
                
                parsedTemplate = [BDSKTemplateParser arrayByParsingTemplateString:[str substringWithRange:makeRange(NSMaxRange(startRange), (sepRange.location == NSNotFound ? endRange.location : sepRange.location))]];
            }
        }
    }
    
    if (parsedTemplate && (templateDict = [self convertPubTemplate:parsedTemplate defaultFont:font])) {
        NSArray *itemTemplate = [templateDict objectForKey:@""];
        NSMutableSet *includedTypes = [[[NSMutableSet alloc] initWithArray:[templateDict allKeys]] autorelease];
        BDSKTypeTemplate *template;
        NSString *type;
        NSArray *currentTypes = [typeTemplates valueForKey:@"pubType"];
        NSUInteger currentIndex;
        
        if (itemTemplate) {
            [[typeTemplates objectAtIndex:defaultTypeIndex] setItemTemplate:itemTemplate];
            [includedTypes removeObject:@""];
        }
        
        for (template in typeTemplates) {
            if (itemTemplate = [templateDict objectForKey:[template pubType]]) {
                [template setItemTemplate:itemTemplate];
                [template setIncluded:YES];
                [includedTypes removeObject:template];
            }
        }
        
        for (type in includedTypes) {
            itemTemplate = [templateDict objectForKey:type];
            type = [type entryType];
            template = [[[BDSKTypeTemplate alloc] initWithPubType:type forDocument:self] autorelease];
            [template setItemTemplate:itemTemplate];
            [template setIncluded:YES];
            currentIndex = [currentTypes indexOfObject:type];
            if (currentIndex == NSNotFound)
                [[self mutableArrayValueForKey:@"typeTemplates"] addObject:template];
            else
                [[self mutableArrayValueForKey:@"typeTemplates"] replaceObjectAtIndex:currentIndex withObject:template];
        }
        
        [[self undoManager] removeAllActions];
        [self updateChangeCount:NSChangeCleared];
        
        return YES;
        
    } else if (outError) {
        *outError = [NSError errorWithDomain:@"BDSKTemplateDocumentErrorDomain" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Unable to open file.", @"Error description"), NSLocalizedDescriptionKey, NSLocalizedString(@"This template cannot be opened by BibDesk. You should edit it manually.", @"Error description"), NSLocalizedRecoverySuggestionErrorKey, nil]];
    }
    return NO;
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
    return [NSPrintOperation printOperationWithAttributedString:[self attributedString] printInfo:[self printInfo] settings:printSettings];
}

- (BDSKToken *)tokenForField:(NSString *)field {
    id token = [fieldTokens objectForKey:field];
    if (token == nil) {
        token = [BDSKToken tokenWithField:field];
        [fieldTokens setObject:token forKey:field];
    }
    return token;
}

#pragma mark Accessors

- (NSArray *)typeTemplates {
    return typeTemplates;
}

- (void)setTypeTemplates:(NSArray *)newTypeTemplates {
    if (typeTemplates != newTypeTemplates) {
        [typeTemplates release];
        typeTemplates = [newTypeTemplates mutableCopy];
    }
}

- (NSUInteger)countOfTypeTemplates {
    return [typeTemplates count];
}

- (id)objectInTypeTemplatesAtIndex:(NSUInteger)idx {
    return [typeTemplates objectAtIndex:idx];
}

- (void)insertObject:(id)obj inTypeTemplatesAtIndex:(NSUInteger)idx {
    [typeTemplates insertObject:obj atIndex:idx];
}

- (void)removeObjectFromTypeTemplatesAtIndex:(NSUInteger)idx {
    [typeTemplates removeObjectAtIndex:idx];
}

- (NSUInteger)countOfSizes {
    return sizeof(BDSKDefaultFontSizes) / sizeof(CGFloat);
}

- (id)objectInSizesAtIndex:(NSUInteger)idx {
    return [NSNumber numberWithDouble:BDSKDefaultFontSizes[idx]];
}

- (NSUInteger)countOfTokenSizes {
    return 1 + sizeof(BDSKDefaultFontSizes) / sizeof(CGFloat);
}

- (id)objectInTokenSizesAtIndex:(NSUInteger)idx {
    return [NSNumber numberWithDouble:idx == 0 ? 0.0 : BDSKDefaultFontSizes[idx - 1]];
}

- (NSArray *)specialTokens {
    return specialTokens;
}

- (void)setSpecialTokens:(NSArray *)newSpecialTokens {
    [specialTokens setArray:newSpecialTokens];
}

- (NSArray *)defaultTokens {
    return defaultTokens;
}

- (void)setDefaultTokens:(NSArray *)newDefaultTokens {
    [defaultTokens setArray:newDefaultTokens];
}

- (NSAttributedString *)prefixTemplate {
    return prefixTemplate;
}

- (void)setPrefixTemplate:(NSAttributedString *)newPrefixTemplate {
    [[[self undoManager] prepareWithInvocationTarget:self] setPrefixTemplate:[[prefixTemplate copy] autorelease]];
    [prefixTemplate setAttributedString:newPrefixTemplate ?: [[[NSAttributedString alloc] init] autorelease]];
}

- (NSAttributedString *)suffixTemplate {
    return suffixTemplate;
}

- (void)setSuffixTemplate:(NSAttributedString *)newSuffixTemplate {
    [[[self undoManager] prepareWithInvocationTarget:self] setSuffixTemplate:[[suffixTemplate copy] autorelease]];
    [suffixTemplate setAttributedString:newSuffixTemplate ?: [[[NSAttributedString alloc] init] autorelease]];
}

- (NSAttributedString *)separatorTemplate {
    return separatorTemplate;
}

- (void)setSeparatorTemplate:(NSAttributedString *)newSeparatorTemplate {
    [[[self undoManager] prepareWithInvocationTarget:self] setSeparatorTemplate:[[separatorTemplate copy] autorelease]];
    [separatorTemplate setAttributedString:newSeparatorTemplate ?: [[[NSAttributedString alloc] init] autorelease]];
}

- (BOOL)isRichText {
    return richText;
}

- (void)setRichText:(BOOL)newRichText {
    if (richText != newRichText) {
        [[[self undoManager] prepareWithInvocationTarget:self] setRichText:richText];
        richText = newRichText;
        
        [self updateStrings];
        [self updateOptionView];
        [self updateTextViews];
        [self setFileURL:nil];
        [self setFileType:richText ? @"RTFTemplate" : @"TextTemplate"];
    }
}

- (NSString *)fontName {
    return fontName;
}

- (void)setFontName:(NSString *)newFontName {
    if (fontName != newFontName) {
        [[[self undoManager] prepareWithInvocationTarget:self] setFontName:fontName];
        [fontName release];
        fontName = [newFontName retain];
        [self updateStrings];
        [self updateTextViews];
    }
}

- (CGFloat)fontSize {
    return fontSize;
}

- (void)setFontSize:(CGFloat)newFontSize {
    if (BDSKAbs(fontSize - newFontSize) > 0.0) {
        [[[self undoManager] prepareWithInvocationTarget:self] setFontSize:fontSize];
        fontSize = newFontSize;
        [self updateStrings];
        [self updateTextViews];
    }
}

- (BOOL)isBold {
    return bold;
}

- (void)setBold:(BOOL)newBold {
    if (bold != newBold) {
        [(BDSKTemplateDocument *)[[self undoManager] prepareWithInvocationTarget:self] setBold:bold];
        bold = newBold;
        [self updateStrings];
        [self updateTextViews];
    }
}

- (BOOL)isItalic {
    return italic;
}

- (void)setItalic:(BOOL)newItalic {
    if (italic != newItalic) {
        [(BDSKTemplateDocument *)[[self undoManager] prepareWithInvocationTarget:self] setItalic:italic];
        italic = newItalic;
        [self updateStrings];
        [self updateTextViews];
    }
}

- (BDSKToken *)selectedToken {
    return selectedToken;
}

- (void)setSelectedToken:(BDSKToken *)newSelectedToken {
    if (selectedToken != newSelectedToken) {
        [selectedToken release];
        selectedToken = [newSelectedToken retain];
        [self updateOptionView];
    }
}

- (NSUInteger)defaultTypeIndex {
    return defaultTypeIndex;
}

- (void)setDefaultTypeIndex:(NSUInteger)newDefaultTypeIndex {
    if (defaultTypeIndex != newDefaultTypeIndex) {
        [[[self undoManager] prepareWithInvocationTarget:self] setDefaultTypeIndex:defaultTypeIndex];
        NSUInteger oldDefaultTypeIndex = defaultTypeIndex;
        [[typeTemplates objectAtIndex:oldDefaultTypeIndex] willChangeValueForKey:@"default"];
        [[typeTemplates objectAtIndex:newDefaultTypeIndex] willChangeValueForKey:@"default"];
        defaultTypeIndex = newDefaultTypeIndex;
        [[typeTemplates objectAtIndex:oldDefaultTypeIndex] didChangeValueForKey:@"default"];
        [[typeTemplates objectAtIndex:newDefaultTypeIndex] didChangeValueForKey:@"default"];
        [self updateStrings];
    }
}

- (NSString *)string {
    if (string == nil) {
        NSMutableString *mutString = [NSMutableString string];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"included = 1"];
        NSArray *includedTemplates = [typeTemplates filteredArrayUsingPredicate:predicate];
        BDSKTypeTemplate *template;
        NSString *altPrefix = @"";
        BOOL isSimple = [includedTemplates count] == 0 ||
            ([includedTemplates count] == 1 && [typeTemplates objectAtIndex:defaultTypeIndex] == [includedTemplates lastObject]);
        
        if ([prefixTemplate length]) {
            [mutString appendString:[prefixTemplate string]];
        }
        [mutString appendString:@"<$publications>\n"];
        if (isSimple) {
            [mutString appendString:[[typeTemplates objectAtIndex:defaultTypeIndex] string]];
        } else {
            for (template in includedTemplates) {
                if ([template isIncluded]) {
                    [mutString appendFormat:@"<%@$pubType=%@?>\n", altPrefix, [template pubType]];
                    [mutString appendString:[template string]];
                    altPrefix = @"?";
                }
            }
            [mutString appendString:@"<?$pubType?>\n"];
            [mutString appendString:[[typeTemplates objectAtIndex:defaultTypeIndex] string]];
            [mutString appendString:@"</$pubType?>\n"];
        }
        if ([separatorTemplate length]) {
            [mutString appendString:@"<?$publications>\n"];
            [mutString appendString:[separatorTemplate string]];
        }
        [mutString appendString:@"</$publications>\n"];
        if ([suffixTemplate length]) {
            [mutString appendString:[suffixTemplate string]];
        }
        string = [mutString copy];
    }
    return string;
}

- (NSAttributedString *)attributedString {
    if (attributedString == nil) {
        NSMutableAttributedString *attrString = nil;
        
        if (richText) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"included = 1"];
            NSArray *includedTemplates = [typeTemplates filteredArrayUsingPredicate:predicate];
            BDSKTypeTemplate *template;
            NSString *altPrefix = @"";
            BOOL isSimple = [includedTemplates count] == 0 ||
                ([includedTemplates count] == 1 && [typeTemplates objectAtIndex:defaultTypeIndex] == [includedTemplates lastObject]);
            NSFont *font = [NSFont fontWithName:fontName size:fontSize];
            NSDictionary *attrs;
            
            attrString = [[[NSMutableAttributedString alloc] init] autorelease];
            
            if (bold)
                font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSBoldFontMask];
            if (italic)
                font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSItalicFontMask];
            attrs = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil];
            
            if ([prefixTemplate length]) {
                [attrString appendAttributedString:prefixTemplate];
            }
            [attrString appendAttributedString:[[[NSAttributedString alloc] initWithString:@"<$publications>\n" attributes:attrs] autorelease]];
            if (isSimple) {
                [attrString appendAttributedString:[[typeTemplates objectAtIndex:defaultTypeIndex] attributedStringWithDefaultAttributes:attrs]];
            } else {
                for (template in includedTemplates) {
                    if ([template isIncluded]) {
                        NSString *s = [NSString stringWithFormat:@"<%@$pubType=%@?>\n", altPrefix, [template pubType]];
                        [attrString appendAttributedString:[[[NSAttributedString alloc] initWithString:s attributes:attrs] autorelease]];
                        [attrString appendAttributedString:[template attributedStringWithDefaultAttributes:attrs]];
                        altPrefix = @"?";
                    }
                }
                [attrString appendAttributedString:[[[NSAttributedString alloc] initWithString:@"<?$pubType?>\n" attributes:attrs] autorelease]];
                [attrString appendAttributedString:[[typeTemplates objectAtIndex:defaultTypeIndex] attributedStringWithDefaultAttributes:attrs]];
                [attrString appendAttributedString:[[[NSAttributedString alloc] initWithString:@"</$pubType?>\n" attributes:attrs] autorelease]];
            }
            if ([separatorTemplate length]) {
                [attrString appendAttributedString:[[[NSAttributedString alloc] initWithString:@"<?$publications>\n" attributes:attrs] autorelease]];
                [attrString appendAttributedString:separatorTemplate];
            }
            [attrString appendAttributedString:[[[NSAttributedString alloc] initWithString:@"</$publications>\n" attributes:attrs] autorelease]];
            if ([suffixTemplate length]) {
                [attrString appendAttributedString:suffixTemplate];
            }
            [attrString fixAttributesInRange:NSMakeRange(0, [attrString length])];
        } else {
            NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont userFontOfSize:0.0], NSFontAttributeName, nil];
            attrString = [[[NSMutableAttributedString alloc] initWithString:[self string] attributes:attrs] autorelease];
        }
        
        attributedString = [attrString copy];
    }
    return attributedString;
}

- (NSAttributedString *)previewAttributedString {
    // this should probably parse the template with a preview item
    return [self attributedString];
}

#pragma mark Actions

- (IBAction)saveDocument:(id)sender {
    if ([ownerController commitEditing])
        [super saveDocument:sender];
}

- (IBAction)saveDocumentAs:(id)sender {
    if ([ownerController commitEditing])
        [super saveDocumentAs:sender];
}

- (IBAction)saveDocumentTo:(id)sender {
    if ([ownerController commitEditing])
        [super saveDocumentTo:sender];
}

- (IBAction)printDocument:(id)sender {
    if ([ownerController commitEditing])
        [super printDocument:sender];
}

- (void)addFieldSheetDidEnd:(BDSKAddFieldSheetController *)addFieldController returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSOKButton) {
        BDSKToken *token = [self tokenForField:[addFieldController field]];
        [self setDefaultTokens:[[self defaultTokens] arrayByAddingObject:token]];
        [defaultTokenField setObjectValue:[self defaultTokens]];
        [self updateTokenFields];
    }
}

- (IBAction)addField:(id)sender {
    NSArray *allFields = [[BDSKTypeManager sharedManager] allFieldNamesIncluding:nil excluding:nil];
    BDSKAddFieldSheetController *addFieldController = [[BDSKAddFieldSheetController alloc] initWithPrompt:NSLocalizedString(@"Field:", @"Label for adding a field for a template")
                                                                                              fieldsArray:allFields];
	[addFieldController beginSheetModalForWindow:[self windowForSheet]
                                   modalDelegate:self
                                  didEndSelector:@selector(addFieldSheetDidEnd:returnCode:contextInfo:)
                                     contextInfo:NULL];
    [addFieldController release];
}

- (void)changeValueFromMenu:(id)sender {
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:BDSKValueOrNoneTransformerName];
    NSString *newValue = [transformer reverseTransformedValue:[sender representedObject]];
    [menuToken setValue:newValue forKey:[[sender menu] title]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = [menuItem action];
    if (action == @selector(changeValueFromMenu:)) {
        NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:BDSKValueOrNoneTransformerName];
        [menuItem setState:[[transformer transformedValue:[menuToken valueForKey:[[menuItem menu] title]]] isEqualToString:[menuItem representedObject]]];
        return YES;
    } else if ([[BDSKTemplateDocument superclass] instancesRespondToSelector:_cmd]) {
        return [super validateMenuItem:menuItem];
    } else {
        return YES;
    }
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem {
    if ([anItem action] == @selector(saveDocument:)) {
        return YES;
    } else if ([[BDSKTemplateDocument superclass] instancesRespondToSelector:_cmd]) {
        return [super validateUserInterfaceItem:anItem];
    } else {
        return YES;
    }
}

#pragma mark Setup and Update

- (void)setupOptionsMenu:(NSMenu *)parentMenu forKeys:(NSString *)firstKey, ... {
    va_list keyList;
    NSString *key = firstKey;
    NSUInteger i = 0;
    va_start(keyList, firstKey);
    while (key) {
        NSMenu *menu = [[parentMenu itemAtIndex:i] submenu];
        [menu setTitle:[key stringByAppendingString:@"Key"]];
        for (NSDictionary *dict in [templateOptions valueForKey:key]) {
            NSMenuItem *item = [menu addItemWithTitle:[[NSBundle mainBundle] localizedStringForKey:[dict objectForKey:@"displayName"] value:@"" table:@"TemplateOptions"]
                                               action:@selector(changeValueFromMenu:) keyEquivalent:@""];
            [item setTarget:self];
            [item setRepresentedObject:[dict objectForKey:@"key"]];
        }
        key = va_arg(keyList, NSString *);
        i++;
    }
    va_end(keyList);
}

- (void)setupOptionsMenus {
    [self setupOptionsMenu:fieldOptionsMenu forKeys:@"casing", @"cleaning", @"appending", nil];
    [self setupOptionsMenu:urlOptionsMenu forKeys:@"urlFormat", @"casing", @"cleaning", @"appending", nil];
    [self setupOptionsMenu:personOptionsMenu forKeys:@"nameStyle", @"joinStyle", @"casing", @"cleaning", @"appending", nil];
    [self setupOptionsMenu:linkedFileOptionsMenu forKeys:@"linkedFileFormat", @"linkedFileJoinStyle", @"appending", nil];
    [self setupOptionsMenu:dateOptionsMenu forKeys:@"dateFormat", @"casing", @"cleaning", @"appending", nil];
    [self setupOptionsMenu:numberOptionsMenu forKeys:@"counterStyle", @"counterCasing", nil];
}

- (void)updateTextViews {
    [prefixTemplateTextView setRichText:[self isRichText]];
    [separatorTemplateTextView setRichText:[self isRichText]];
    [suffixTemplateTextView setRichText:[self isRichText]];
    if ([self isRichText]) {
        NSFont *font = [NSFont fontWithName:[self fontName] size:[self fontSize]];
        if ([self isBold])
            font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSBoldFontMask];
        if ([self isItalic])
            font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSItalicFontMask];
        if ([[prefixTemplateTextView string] length] == 0)
            [prefixTemplateTextView setFont:font];
        if ([[separatorTemplateTextView string] length] == 0)
            [separatorTemplateTextView setFont:font];
        if ([[suffixTemplateTextView string] length] == 0)
            [suffixTemplateTextView setFont:font];
    } else {
        [prefixTemplateTextView setFont:[NSFont userFontOfSize:0.0]];
        [separatorTemplateTextView setFont:[NSFont userFontOfSize:0.0]];
        [suffixTemplateTextView setFont:[NSFont userFontOfSize:0.0]];
    }
}

- (void)updateTokenFields {
    NSRect frame;
    CGFloat width = 0.0;
    
    for (NSTokenField *tokenField in [NSArray arrayWithObjects:specialTokenField, requiredTokenField, optionalTokenField, defaultTokenField, nil]) {
        [tokenField sizeToFit];
        frame = [tokenField frame];
        width = BDSKMax(width, NSWidth(frame));
        // NSTokenField bug: add 10px to the width, because otherwise the tracking rect for the last token is broken
        frame.size.width += 10.0;
        [tokenField setFrame:frame];
    }
    
    NSScrollView *scrollView = [specialTokenField enclosingScrollView];
    frame = [[scrollView documentView] frame];
    frame.size.width = width;
    [[scrollView documentView] setFrame:frame];
    [scrollView setNeedsDisplay:YES];
}

- (void)updateStrings {
    [self willChangeValueForKey:@"string"];
    [string release];
    string = nil;
    [self didChangeValueForKey:@"string"];
    [self willChangeValueForKey:@"attributedString"];
    [attributedString release];
    attributedString = nil;
    [self didChangeValueForKey:@"attributedString"];
}

- (void)updateOptionView {
    NSArray *currentOptionViews = [[tokenOptionsBox contentView] subviews];
    NSMutableArray *optionViews = nil;
    
    if (selectedToken && [selectedToken isKindOfClass:[BDSKToken class]]) {
        switch ([selectedToken type]) {
            case BDSKFieldTokenType:
                optionViews = [NSMutableArray arrayWithObjects:fieldOptionsView, appendingOptionsView, nil];
                break;
            case BDSKURLTokenType:
                optionViews = [NSMutableArray arrayWithObjects:urlOptionsView, fieldOptionsView, appendingOptionsView, nil];
                break;
            case BDSKPersonTokenType:
                optionViews = [NSMutableArray arrayWithObjects:personOptionsView, fieldOptionsView, appendingOptionsView, nil];
                break;
            case BDSKLinkedFileTokenType:
                optionViews = [NSMutableArray arrayWithObjects:linkedFileOptionsView, appendingOptionsView, nil];
                break;
            case BDSKDateTokenType:
                optionViews = [NSMutableArray arrayWithObjects:dateOptionsView, fieldOptionsView, appendingOptionsView, nil];
                break;
            case BDSKNumberTokenType:
                optionViews = [NSMutableArray arrayWithObjects:numberOptionsView, nil];
                break;
            case BDSKTextTokenType:
                optionViews = [NSMutableArray arrayWithObjects:textOptionsView, nil];
                break;
            default:
                optionViews = [NSMutableArray array];
        }
        if (richText)
            [optionViews addObject:fontOptionsView];
    }
    
    if ([optionViews isEqualToArray:currentOptionViews] == NO) {
        NSRect frame = [[tokenOptionsBox contentView] bounds];
        NSPoint point = NSMakePoint(NSMinX(frame) + 7.0, NSMaxY(frame) - 7.0);
        
        [currentOptionViews retain];
        [currentOptionViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [currentOptionViews release];
        
        for (NSView *view in optionViews) {
            frame = [view frame];
            point.y -= NSHeight(frame);
            frame.origin = point;
            [view setFrame:frame];
            [[tokenOptionsBox contentView] addSubview:view];
        }
    }
}

#pragma mark Notification handlers

- (void)handleDidChangeSelectionNotification:(NSNotification *)notification {
    NSTextView *textView = [[notification userInfo] objectForKey:@"NSFieldEditor"];
    
    // we shouldn't remove the selectedToken when the focus turns to a text field
    if ([textView delegate]) {
        BDSKToken *token = nil;
        NSArray *selRanges = [textView selectedRanges];
        
        if ([selRanges count] == 1) {
            NSRange range = [[selRanges lastObject] rangeValue];
            
            if (range.length == 1) {
                NSDictionary *attrs = [[textView textStorage] attributesAtIndex:range.location effectiveRange:NULL];
                id attachment = [attrs objectForKey:NSAttachmentAttributeName];
                
                if (attachment) {
                    if ([attachment respondsToSelector:@selector(representedObject)])
                        token = [attachment representedObject];
                    else if ([[attachment attachmentCell] respondsToSelector:@selector(representedObject)])
                        token = [(id)[attachment attachmentCell] representedObject];
                    if (token && [token isKindOfClass:[BDSKToken class]] == NO)
                        token = nil;
                }
            } else if (NSEqualRanges(range, NSMakeRange(0,0))) // this happens when you hover over a token on Leopard, very stupid
                return;
        }
        [self setSelectedToken:token];
    }
}

- (void)handleDidEndEditingNotification:(NSNotification *)notification {
}

- (void)handleTokenDidChangeNotification:(NSNotification *)notification {
    BDSKToken *token = [notification object];
    if ([[typeTemplates valueForKeyPath:@"@unionOfArrays.itemTemplate"] indexOfObjectIdenticalTo:token] != NSNotFound) {
        [self updateStrings];
        if ([token type] == BDSKTextTokenType) {
            NSArray *currentItemTemplate = [itemTemplateTokenField objectValue];
            if ([currentItemTemplate indexOfObjectIdenticalTo:token] != NSNotFound)
                [itemTemplateTokenField setObjectValue:[[currentItemTemplate copy] autorelease]];
        }
    }
}

- (void)handleTemplateDidChangeNotification:(NSNotification *)notification {
    BDSKTypeTemplate *template = [notification object];
    if ([typeTemplates indexOfObjectIdenticalTo:template] != NSNotFound) {
        [self updateStrings];
        // KVO in NSTokenField binding does not work
        if (template == [typeTemplates objectAtIndex:[tableView selectedRow]])
            [itemTemplateTokenField setObjectValue:[template itemTemplate]];
    }
}

- (void)textDidEndEditing:(NSNotification *)notification {
    NSText *textView = [notification object];
    if (textView == separatorTemplateTextView || textView == prefixTemplateTextView || textView == suffixTemplateTextView)
        [self updateStrings];
}

- (BOOL)windowShouldClose:(id)window {
    return [ownerController commitEditing];
}

- (void)windowWillClose:(NSNotification *)notification {
    [ownerController setContent:nil];
}

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(void *)contextInfo {
    if ([ownerController commitEditing]) {
        if ([[self undoManager] groupingLevel] > 0) {
            [self updateChangeCount:NSChangeDone];
            [super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector contextInfo:contextInfo];
            [self updateChangeCount:NSChangeUndone];
        } else {
            [super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector contextInfo:contextInfo];
        }
    } else if (delegate && shouldCloseSelector) {
        NSInvocation *invocation = [NSInvocation invocationWithTarget:delegate selector:shouldCloseSelector argument:self];
        BOOL no = NO;
        [invocation setArgument:&no atIndex:3];
        [invocation setArgument:&contextInfo atIndex:4];
        [invocation invoke]; 
    }
}

#pragma mark NSTokenField delegate

// implement pasteboard delegate methods as a workaround for not doing the string->token transformation of tokenField:representedObjectForEditingString: (apparently needed for drag-and-drop on post-10.4 systems)
- (BOOL)tokenField:(NSTokenField *)tokenField writeRepresentedObjects:(NSArray *)objects toPasteboard:(NSPasteboard *)pboard {
    NSMutableString *str = [NSMutableString string];
    
    for (id object in objects)
        [str appendString:[self tokenField:tokenField displayStringForRepresentedObject:object]];
    
    [pboard declareTypes:[NSArray arrayWithObjects:BDSKTemplateTokensPboardType, NSStringPboardType, nil] owner:nil];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:objects];
    [pboard setData:data forType:BDSKTemplateTokensPboardType];
    [pboard setString:str forType:NSStringPboardType];
    return nil != data;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField readFromPasteboard:(NSPasteboard *)pboard {
    if (tokenField == itemTemplateTokenField) {
        NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKTemplateTokensPboardType, NSStringPboardType, nil]];
        if ([type isEqualToString:BDSKTemplateTokensPboardType]) {
            NSData *data = [pboard dataForType:BDSKTemplateTokensPboardType];
            return [NSKeyedUnarchiver unarchiveObjectWithData:data];
        } else if ([type isEqualToString:NSStringPboardType]) {
            return [NSArray arrayWithObjects:[pboard stringForType:NSStringPboardType], nil];
        }
    }
    return nil;
}

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject {
    if ([representedObject isKindOfClass:[BDSKToken class]])
        return [representedObject title];
    else if ([representedObject isKindOfClass:[NSString class]])
        return representedObject;
    return @"";
}

- (NSString *)tokenField:(NSTokenField *)tokenField editingStringForRepresentedObject:(id)representedObject {
    return nil;
}

- (NSTokenStyle)tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject {
    if ([representedObject isKindOfClass:[BDSKToken class]])
        return NSRoundedTokenStyle;
    else if ([representedObject isKindOfClass:[NSString class]])
        return NSPlainTextTokenStyle;
    return NSRoundedTokenStyle;
}

- (BOOL)tokenField:(NSTokenField *)tokenField hasMenuForRepresentedObject:(id)representedObject {
    return [representedObject isKindOfClass:[BDSKToken class]] && [(BDSKToken *)representedObject type] != BDSKTextTokenType;
}

- (NSMenu *)tokenField:(NSTokenField *)tokenField menuForRepresentedObject:(id)representedObject {
    NSMenu *menu = nil;
    if ([representedObject isKindOfClass:[BDSKToken class]]) {
        menuToken = representedObject;
        switch ([(BDSKToken *)representedObject type]) {
            case BDSKFieldTokenType: menu = fieldOptionsMenu; break;
            case BDSKURLTokenType: menu = urlOptionsMenu; break;
            case BDSKPersonTokenType: menu = personOptionsMenu; break;
            case BDSKLinkedFileTokenType: menu = linkedFileOptionsMenu; break;
            case BDSKDateTokenType: menu = dateOptionsMenu; break;
            case BDSKNumberTokenType: menu = numberOptionsMenu; break;
            default: menu = nil; break;
        }
    }
    return menu;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)idx {
    if (tokenField == itemTemplateTokenField) {
        for (id token in tokens) {
            if ([token isKindOfClass:[BDSKToken class]]) {
                [token setDocument:self];
            }
        }
    }
    
    return tokens;
}

- (void)tokenField:(NSTokenField *)tokenField textViewDidChangeSelection:(NSTextView *)textView {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:textView, @"NSFieldEditor", nil];
    NSNotification *note = [NSNotification notificationWithName:BDSKTokenFieldDidChangeSelectionNotification object:tokenField userInfo:userInfo];
    [[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostASAP coalesceMask:NSNotificationCoalescingOnName forModes:nil];
}

#pragma mark NSTableView delegate and dataSource

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self setSelectedToken:nil];
    [self updateTokenFields];
}

- (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation {
    if ([[tableColumn identifier] isEqualToString:@"included"])
        return NSLocalizedString(@"Check to include an item template for this type", @"Tool tip message");
    return nil;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv{ return 0; }

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row { return nil; }

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    [pboard declareTypes:[NSArray arrayWithObjects:BDSKTypeTemplateRowsPboardType, nil] owner:nil];
    [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:rowIndexes] forType:BDSKTypeTemplateRowsPboardType];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKTypeTemplateRowsPboardType, nil]];
    
    if (op == NSTableViewDropAbove)
        [tv setDropRow:row == -1 ? 0 : row dropOperation:NSTableViewDropOn];
    
    return type ? NSDragOperationCopy : NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op{
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKTypeTemplateRowsPboardType, nil]];
    
    if (type) {
        NSInteger idx = [[NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:BDSKTypeTemplateRowsPboardType]] lastIndex];
        BDSKTypeTemplate *sourceTemplate = [typeTemplates objectAtIndex:idx];
        BDSKTypeTemplate *targetTemplate = [typeTemplates objectAtIndex:row];
        [targetTemplate setItemTemplate:[[[NSArray alloc] initWithArray:[sourceTemplate itemTemplate] copyItems:YES] autorelease]];
        return YES;
    }
    return NO;
}

#pragma mark NSSplitView delegate

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset {
    if (sender == tableViewSplitView) {
        return proposedMax - 600.0;
    } else {
        return proposedMax;
    }
}

#pragma mark Reading

- (NSDictionary *)convertPubTemplate:(NSArray *)templateArray defaultFont:(NSFont *)defaultFont {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSArray *itemTemplate;
    BDSKTemplateTag *tag = [templateArray count] ? [templateArray objectAtIndex:0] : nil;
    
    if ([tag type] == BDSKConditionTemplateTagType && [[(BDSKConditionTemplateTag *)tag keyPath] isEqualToString:@"pubType"]) {
        if ([(BDSKConditionTemplateTag *)tag matchType] != BDSKTemplateTagMatchEqual)
            return nil;
        
        NSArray *matchStrings = [(BDSKConditionTemplateTag *)tag matchStrings];
        NSUInteger i = 0, keyCount = [matchStrings count], count = [[(BDSKConditionTemplateTag *)tag subtemplates] count];
        
        for (i = 0; i < count; i++) {
            if (itemTemplate = [self convertItemTemplate:[(BDSKConditionTemplateTag *)tag subtemplateAtIndex:i] defaultFont:defaultFont])
                [result setObject:itemTemplate forKey:i < keyCount ? [matchStrings objectAtIndex:i] : @""];
            else return nil;
        }
    } else {
        if (itemTemplate = [self convertItemTemplate:templateArray defaultFont:defaultFont])
            [result setObject:itemTemplate forKey:@""];
        else return nil;
    }
    
    return result;
}

- (NSArray *)convertItemTemplate:(NSArray *)templateArray defaultFont:(NSFont *)defaultFont {
    NSMutableArray *result = [NSMutableArray array];
    id token;
    
    for (BDSKTemplateTag *tag in templateArray) {
        switch ([(BDSKTemplateTag *)tag type]) {
            case BDSKTextTemplateTagType:
                if (token = [self tokensForTextTag:tag allowText:YES defaultFont:defaultFont])
                    [result addObjectsFromArray:token];
                else return nil;
                break;
            case BDSKValueTemplateTagType:
                if (token = [self tokenForValueTag:(BDSKValueTemplateTag *)tag defaultFont:defaultFont])
                    [result addObject:token];
                else return nil;
                break;
            case BDSKConditionTemplateTagType:
                if (token = [self tokenForConditionTag:(BDSKConditionTemplateTag *)tag defaultFont:defaultFont])
                    [result addObject:token];
                else return nil;
                break;
            default:
                return nil;
        }
    }
    
    return result;
}

- (NSArray *)tokensForTextTag:(BDSKTemplateTag *)tag allowText:(BOOL)allowText defaultFont:(NSFont *)defaultFont {
    NSMutableArray *tokens = [NSMutableArray array];
    if (defaultFont) {
        NSAttributedString *text = [(BDSKRichTextTemplateTag *)tag attributedText];
        NSUInteger length = [text length];
        NSRange range = NSMakeRange(0, 0);
        
        while (NSMaxRange(range) < length) {
            id token;
            NSFont *font = [text attribute:NSFontAttributeName atIndex:range.location longestEffectiveRange:&range inRange:NSMakeRange(range.location, length - range.location)];
            if (allowText && [font isEqual:defaultFont]) {
                token = [[(BDSKRichTextTemplateTag *)tag attributedText] string];
            } else {
                token = [[[BDSKTextToken alloc] initWithTitle:[text string]] autorelease];
                [self setFont:font ofToken:token defaultFont:defaultFont];
            }
            [tokens addObject:token];
        }
    } else if (allowText) {
        [tokens addObject:[(BDSKTextTemplateTag *)tag text]];
    } else {
        [tokens addObject:[[[BDSKTextToken alloc] initWithTitle:[(BDSKTextTemplateTag *)tag text]] autorelease]];
    }
    return tokens;
}

- (id)tokenForConditionTag:(BDSKConditionTemplateTag *)tag defaultFont:(NSFont *)defaultFont {
    NSInteger count = [[tag subtemplates] count];
    if ([(BDSKConditionTemplateTag *)tag matchType] != BDSKTemplateTagMatchOther || count > 2)
        return nil;
    
    NSArray *nonemptyTemplate = [tag subtemplateAtIndex:0];
    NSArray *emptyTemplate = count > 1 ? [tag subtemplateAtIndex:1] : nil;
    id token = nil;
    
    if ([nonemptyTemplate count] == 1 && [(BDSKTemplateTag *)[nonemptyTemplate lastObject] type] == BDSKTextTemplateTagType) {
        NSArray *keys = [[tag keyPath] componentsSeparatedByString:@"."];
        NSArray *tokens;
        if ([keys count] != 2 || [[keys objectAtIndex:0] isEqualToString:@"fields"] == NO)
            return nil;
        if (tokens = [self tokensForTextTag:tag allowText:NO defaultFont:defaultFont]) {
            if ([tokens count] == 1) {
                token = [tokens lastObject];
                [token setField:[keys lastObject]];
                if ([emptyTemplate count]) {
                    id textTag = [emptyTemplate lastObject];
                    if ([(BDSKTemplateTag *)textTag type] != BDSKTextTemplateTagType)
                        return nil;
                    [token setAltText:defaultFont ? [[(BDSKRichTextTemplateTag *)textTag attributedText] string] : [(BDSKTextTemplateTag *)textTag text]];
                }
            } else return nil;
        } else return nil;
    } else if ([emptyTemplate count] == 0 && [nonemptyTemplate count] < 4) {
        NSInteger i = 0;
        BDSKTemplateTag *subtag = [nonemptyTemplate objectAtIndex:i];
        NSString *prefix = nil, *suffix = nil;
        count = [nonemptyTemplate count];
        
        if ([subtag type] == BDSKTextTemplateTagType) {
            prefix = defaultFont ? [[(BDSKRichTextTemplateTag *)subtag attributedText] string] : [(BDSKTextTemplateTag *)subtag text];
            subtag = ++i < count ? [nonemptyTemplate objectAtIndex:i] : nil;
        }
        if ([subtag type] == BDSKValueTemplateTagType && [[(BDSKValueTemplateTag *)subtag keyPath] isEqualToString:[tag keyPath]]) {
            token = [self tokenForValueTag:(BDSKValueTemplateTag *)subtag defaultFont:defaultFont];
            subtag = ++i < count ? [nonemptyTemplate objectAtIndex:i] : nil;
        } else return nil;
        if (subtag) {
            if ([subtag type] == BDSKTextTemplateTagType) {
                suffix = defaultFont ? [[(BDSKRichTextTemplateTag *)subtag attributedText] string] : [(BDSKTextTemplateTag *)subtag text];
            } else return nil;
        }
        if (prefix)
            [token setPrefix:prefix];
        if (suffix)
            [token setSuffix:suffix];
    } else return nil;
    
    return token;
}

- (id)tokenForValueTag:(BDSKValueTemplateTag *)tag defaultFont:(NSFont *)defaultFont {
    NSArray *keys = [[tag keyPath] componentsSeparatedByString:@"."];
    NSString *key = [keys count] ? [keys objectAtIndex:0] : nil;
    BDSKToken *token = nil;
    NSInteger type;
    NSString *field = nil;
    NSInteger i = 0, j;
    
    if ([key isEqualToString:@"fields"] || [key isEqualToString:@"urls"] || [key isEqualToString:@"persons"])
        field = [keys objectAtIndex:++i];
    else if ([key isEqualToString:@"citeKey"])
        field = BDSKCiteKeyString;
    else if ([key isEqualToString:@"pubType"])
        field = BDSKPubTypeString;
    else if ([key isEqualToString:@"itemIndex"])
        field = BDSKItemNumberString;
    else if ([key isEqualToString:@"authors"])
        field = BDSKAuthorString;
    else if ([key isEqualToString:@"editors"])
        field = BDSKEditorString;
    else
        return nil;
    
    token = [BDSKToken tokenWithField:field];
    type = [(BDSKToken *)token type];
    keys = [keys subarrayWithRange:NSMakeRange(i + 1, [keys count] - i - 1)];
    NSInteger count = [keys count];
    NSString *property;
    
    if (type == BDSKPersonTokenType && [keys firstObjectCommonWithArray:[templateOptions valueForKeyPath:@"joinStyle.key"]] == nil)
        return nil;
    
    for (i = 0; i < count; i++) {
        for (j = count; j > i; j--) {
            key = [[keys subarrayWithRange:makeRange(i, j)] componentsJoinedByString:@"."];
            if (property = [self propertyForKey:key tokenType:type])
                break;
        }
        if (j > i)
            [token setValue:key forKey:property];
        else return nil;
        i = j - 1;
    }
    
    if (defaultFont) {
        NSFont *font = [[(BDSKRichValueTemplateTag *)tag attributes] objectForKey:NSFontAttributeName];
        [self setFont:font ofToken:token defaultFont:defaultFont];
    }
    
    return token;
}

- (NSString *)propertyForKey:(NSString *)key tokenType:(NSInteger)type {
    switch (type) {
        case BDSKFieldTokenType:
            if ([[templateOptions valueForKeyPath:@"casing.key"] containsObject:key])
                return @"casingKey";
            if ([[templateOptions valueForKeyPath:@"cleaning.key"] containsObject:key])
                return @"cleaningKey";
            if ([[templateOptions valueForKeyPath:@"appending.key"] containsObject:key])
                return @"appendingKey";
            return nil;
        case BDSKURLTokenType:
            if ([[templateOptions valueForKeyPath:@"urlFormat.key"] containsObject:key])
                return @"urlFormatKey";
            if ([[templateOptions valueForKeyPath:@"casing.key"] containsObject:key])
                return @"casingKey";
            if ([[templateOptions valueForKeyPath:@"cleaning.key"] containsObject:key])
                return @"cleaningKey";
            if ([[templateOptions valueForKeyPath:@"appending.key"] containsObject:key])
                return @"appendingKey";
            return nil;
        case BDSKPersonTokenType:
            if ([[templateOptions valueForKeyPath:@"nameStyle.key"] containsObject:key])
                return @"nameStyleKey";
            if ([[templateOptions valueForKeyPath:@"joinStyle.key"] containsObject:key])
                return @"joinStyleKey";
            if ([[templateOptions valueForKeyPath:@"casing.key"] containsObject:key])
                return @"casingKey";
            if ([[templateOptions valueForKeyPath:@"cleaning.key"] containsObject:key])
                return @"cleaningKey";
            if ([[templateOptions valueForKeyPath:@"appending.key"] containsObject:key])
                return @"appendingKey";
            return nil;
        case BDSKDateTokenType:
            if ([[templateOptions valueForKeyPath:@"dateFormat.key"] containsObject:key])
                return @"dateFormatKey";
            return nil;
        case BDSKNumberTokenType:
            if ([[templateOptions valueForKeyPath:@"counterStyle.key"] containsObject:key])
                return @"counterStyleKey";
            if ([[templateOptions valueForKeyPath:@"counterCasing.key"] containsObject:key])
                return @"counterCasingKey";
            return nil;
        default:
            return nil;
    }
}

- (void)setFont:(NSFont *)font ofToken:(BDSKToken *)token defaultFont:(NSFont *)defaultFont{
    if ([font isEqual:defaultFont] == NO) {
        NSInteger defaultTraits = [[NSFontManager sharedFontManager] traitsOfFont:defaultFont];
        NSInteger traits = [[NSFontManager sharedFontManager] traitsOfFont:font];
        BOOL defaultBold = (defaultTraits & NSBoldFontMask) != 0;
        BOOL defaultItalic = (defaultTraits & NSItalicFontMask) != 0;
        BOOL isBold = (traits & NSBoldFontMask) != 0;
        BOOL isItalic = (traits & NSItalicFontMask) != 0;
        
        if ([[font familyName] isEqualToString:[defaultFont familyName]] == NO)
            [token setFontName:[font familyName]];
        if (BDSKAbs([font pointSize] - [defaultFont pointSize]) > 0.0)
            [token setFontSize:[font pointSize]];
        if (isBold != defaultBold)
            [token setBold:isBold];
        if (isItalic != defaultItalic)
            [token setItalic:isItalic];
    }
}

@end

#pragma mark -

@implementation BDSKTokenField

- (void)textViewDidChangeSelection:(NSNotification *)notification {
    if ([[BDSKTokenField superclass] instancesRespondToSelector:_cmd])
        [super textViewDidChangeSelection:notification];
    if ([[self delegate] respondsToSelector:@selector(tokenField:textViewDidChangeSelection:)])
        [[self delegate] tokenField:self textViewDidChangeSelection:[notification object]];
}

@end

#pragma mark -

@implementation BDSKFlippedClipView
- (BOOL)isFlipped { return YES; }
@end

#pragma mark -

@implementation BDSKValueOrNoneTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)string {
	return string ?: @"<None>";
}

- (id)reverseTransformedValue:(id)string {
	return [string isEqualToString:@"<None>"] ? nil : string;
}

@end

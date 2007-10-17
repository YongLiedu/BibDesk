//
//  BDSKTemplateDocument.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/8/07.
/*
 This software is Copyright (c) 2007
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
#import "BDSKTag.h"
#import "NSString_BDSKExtensions.h"

static float BDSKDefaultFontSizes[] = {8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0, 48.0, 64.0};

NSString *BDSKTextTemplateDocumentType = @"Text Template";
NSString *BDSKRichTextTemplateDocumentType = @"Rich Text Template";

static NSString *BDSKTemplateDocumentFrameAutosaveName = @"BDSKTemplateDocument";

static NSString *BDSKTextViewDidChangeSelectionNotification = @"BDSKTextViewDidChangeSelectionNotification";

static NSString *BDSKTemplateTokensPboardType = @"BDSKTemplateTokensPboardType";
static NSString *BDSKTypeTemplateRowsPboardType = @"BDSKTypeTemplateRowsPboardType";
static NSString *BDSKValueOrNoneTransformerName = @"BDSKValueOrNone";

@interface BDSKValueOrNoneTransformer : NSValueTransformer @end

@interface BDSKFlippedClipView : NSClipView @end

@interface NSTokenFieldCell (BDSKPrivateDeclarations)
+ (id)_sharedFieldEditor;
@end

@interface BDSKTemplateDocument (BDSKPrivate)
- (void)updateTextViews;
- (void)updateTokenFields;
- (void)updatePreview;
- (void)updateOptionView;
- (void)setupOptionsMenus;
- (void)handleDidChangeSelectionNotification:(NSNotification *)notification;
- (void)handleDelayedDidChangeSelectionNotification:(NSNotification *)notification;
- (void)handleDidEndEditingNotification:(NSNotification *)notification;
- (void)handleTokenDidChangeNotification:(NSNotification *)notification;
- (void)handleTemplateDidChangeNotification:(NSNotification *)notification;
- (NSDictionary *)convertPubTemplate:(NSArray *)templateArray defaultFont:(NSFont *)defaultFont;
- (NSArray *)convertItemTemplate:(NSArray *)templateArray defaultFont:(NSFont *)defaultFont;
- (NSArray *)tokensForTextTag:(BDSKTag *)tag allowText:(BOOL)allowText defaultFont:(NSFont *)defaultFont;
- (id)tokenForConditionTag:(BDSKConditionTag *)tag defaultFont:(NSFont *)defaultFont;
- (id)tokenForValueTag:(BDSKValueTag *)tag defaultFont:(NSFont *)defaultFont;
- (NSString *)propertyForKey:(NSString *)key tokenType:(int)type;
- (void)setFont:(NSFont *)font ofToken:(BDSKToken *)token defaultFont:(NSFont *)defaultFont;
@end

@implementation BDSKTemplateDocument

+ (void)initialize {
	[NSValueTransformer setValueTransformer:[[[BDSKValueOrNoneTransformer alloc] init] autorelease]
									forName:BDSKValueOrNoneTransformerName];
}

+ (NSArray *)writableTypes {
    return [NSArray arrayWithObjects:@"Text Template", @"Rich Text Template", nil];
}

+ (NSArray *)nativeTypes {
    return [NSArray arrayWithObjects:@"Text Template", @"Rich Text Template", nil];
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
        NSEnumerator *keyEnum = [[tmpDict allKeys] objectEnumerator];
        NSString *key;
        
        while (key = [keyEnum nextObject]) {
            NSMutableArray *array = [NSMutableArray array];
            NSEnumerator *dictEnum = [[tmpDict objectForKey:key] objectEnumerator];
            NSDictionary *dict;
            
            while (dict = [dictEnum nextObject]) {
                dict = [dict mutableCopy];
                [(NSMutableDictionary *)dict setObject:NSLocalizedStringFromTable([dict objectForKey:@"displayName"], @"TemplateOptions", @"") forKey:@"displayName"];
                [array addObject:dict];
                [dict release];
            }
            [tmpDict setObject:array forKey:key];
        }
        templateOptions = [tmpDict copy];
        [tmpDict release];
        
        editors = CFArrayCreateMutable(kCFAllocatorMallocZone, 0, NULL);
        
        NSEnumerator *typeEnum = [[[BDSKTypeManager sharedManager] bibTypesForFileType:BDSKBibtexString] objectEnumerator];
        NSString *type;
        
        while (type = [typeEnum nextObject]) {
            [typeTemplates addObject:[[[BDSKTypeTemplate alloc] initWithPubType:type forDocument:self] autorelease]];
        }
        defaultTypeIndex = [[typeTemplates valueForKey:@"pubType"] indexOfObject:BDSKArticleString];
        if (defaultTypeIndex == NSNotFound)
            defaultTypeIndex = 0;
        
        NSMutableArray *tmpFonts = [NSMutableArray array];
        NSMutableArray *fontNames = [[[[NSFontManager sharedFontManager] availableFontFamilies] mutableCopy] autorelease];
        NSEnumerator *fontEnum;
        NSString *name;
        
        [fontNames sortUsingSelector:@selector(caseInsensitiveCompare:)];
        fontEnum = [fontNames objectEnumerator];
        while (name = [fontEnum nextObject]) {
            font = [NSFont fontWithName:name size:0.0];
            [tmpFonts addObject:[NSDictionary dictionaryWithObjectsAndKeys:[font fontName], @"fontName", [font displayName], @"displayName", nil]];
        }
        fonts = [tmpFonts copy];
        [tmpFonts insertObject:[NSDictionary dictionaryWithObjectsAndKeys:@"<None>", @"fontName", NSLocalizedString(@"Same as body", @"Inerited font message in popup"), @"displayName", nil] atIndex:0];
        tokenFonts = [tmpFonts copy];
        
        NSEnumerator *fieldEnum = [[[BDSKTypeManager sharedManager] userDefaultFieldsForType:nil] objectEnumerator];
        NSString *field;
        
        while (field = [fieldEnum nextObject])
            [defaultTokens addObject:[self tokenForField:field]];
        
        [specialTokens addObject:[self tokenForField:BDSKPubTypeString]];
        [specialTokens addObject:[self tokenForField:BDSKCiteKeyString]];
        [specialTokens addObject:[self tokenForField:@"Item Index"]];
        [specialTokens addObject:[self tokenForField:NSLocalizedString(@"Rich Text", @"Name for template token")]];
        [specialTokens addObject:[self tokenForField:BDSKDateAddedString]];
        [specialTokens addObject:[self tokenForField:BDSKDateModifiedString]];
        [specialTokens addObject:[self tokenForField:BDSKPubDateString]];
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
    CFRelease(editors);
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
    
    id fieldEditor = [NSTokenFieldCell respondsToSelector:@selector(_sharedFieldEditor)] ? [NSTokenFieldCell _sharedFieldEditor] : nil;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidChangeSelectionNotification:) 
                                                 name:NSTextViewDidChangeSelectionNotification object:fieldEditor];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDelayedDidChangeSelectionNotification:) 
                                                 name:BDSKTextViewDidChangeSelectionNotification object:fieldEditor];
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

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    NSData *data = nil;
    
    [self commitEditing];
    
    if (richText) {
        NSAttributedString *attrString = [self attributedString];
        data = [attrString RTFFromRange:NSMakeRange(0, [attrString length]) documentAttributes:nil];
    } else {
        data = [[self string] dataUsingEncoding:NSUTF8StringEncoding];
    }
    return data;
}

#define MAKE_RANGE(start, end) NSMakeRange(start, end - start)

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    NSArray *parsedTemplate = nil;
    NSDictionary *templateDict = nil;
    NSFont *font = nil;
    NSAttributedString *attrString = nil;
    NSString *string = nil;
    NSRange startRange, endRange = { NSNotFound, 0 }, sepRange = { NSNotFound, 0 }, wsRange;
    unsigned int length, startLoc = NSNotFound;
    BOOL onlyWs;
    
    [self setRichText:[typeName isEqualToString:BDSKRichTextTemplateDocumentType]];
    
    if ([self isRichText]) {
        attrString = [[[NSAttributedString alloc] initWithData:data options:nil documentAttributes:NULL error:NULL] autorelease];
        string = [attrString string];
    } else {
        string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    }
    
    if (string) {
        length = [string length];
        
        startRange = [string rangeOfString:@"<$publications>"];
        
        if (startRange.location != NSNotFound) {
            startLoc = startRange.location;
            
            wsRange = [string rangeOfTrailingEmptyLine:&onlyWs range:MAKE_RANGE(0, startRange.location)];
            if (wsRange.location != NSNotFound)
                startRange = MAKE_RANGE(wsRange.location, NSMaxRange(startRange));
            else if (onlyWs)
                startRange = MAKE_RANGE(0, NSMaxRange(startRange));
            wsRange = [string rangeOfLeadingEmptyLineInRange:MAKE_RANGE(NSMaxRange(startRange), length)];
            if (wsRange.location != NSNotFound)
                startRange = MAKE_RANGE(startRange.location, NSMaxRange(wsRange));
            
            endRange = [string rangeOfString:@"</$publications>" options:NSBackwardsSearch range:MAKE_RANGE(NSMaxRange(startRange), length)];
            
            if (endRange.location != NSNotFound) {
                wsRange = [string rangeOfTrailingEmptyLineInRange:MAKE_RANGE(NSMaxRange(startRange), endRange.location)];
                if (wsRange.location != NSNotFound)
                    endRange = MAKE_RANGE(wsRange.location, NSMaxRange(endRange));
                wsRange = [string rangeOfLeadingEmptyLine:&onlyWs range:MAKE_RANGE(NSMaxRange(endRange), length)];
                if (wsRange.location != NSNotFound)
                    endRange = MAKE_RANGE(endRange.location, NSMaxRange(wsRange));
                else if (onlyWs)
                    endRange = MAKE_RANGE(endRange.location, length);
                
                sepRange = [string rangeOfString:@"<?$publications>" options:NSBackwardsSearch range:MAKE_RANGE(NSMaxRange(startRange), endRange.location)];
                if (sepRange.location != NSNotFound) {
                    wsRange = [string rangeOfTrailingEmptyLineInRange:MAKE_RANGE(NSMaxRange(startRange), sepRange.location)];
                    if (wsRange.location != NSNotFound)
                        sepRange = MAKE_RANGE(wsRange.location, NSMaxRange(sepRange));
                    wsRange = [string rangeOfLeadingEmptyLineInRange:MAKE_RANGE(NSMaxRange(sepRange), endRange.location)];
                    if (wsRange.location != NSNotFound)
                        sepRange = MAKE_RANGE(sepRange.location, NSMaxRange(wsRange));
                }
            }
        }
        
        if (endRange.location != NSNotFound) {
            if ([self isRichText]) {
                if (startRange.location > 0)
                   [self setPrefixTemplate:[attrString attributedSubstringFromRange:MAKE_RANGE(0, startRange.location)]];
                if (NSMaxRange(endRange) < length)
                    [self setSuffixTemplate:[attrString attributedSubstringFromRange:MAKE_RANGE(NSMaxRange(endRange), length)]];
                if (NSMaxRange(sepRange) < endRange.location)
                    [self setSeparatorTemplate:[attrString attributedSubstringFromRange:MAKE_RANGE(NSMaxRange(sepRange), endRange.location)]];
                if (sepRange.location != NSNotFound)
                
                parsedTemplate = [BDSKTemplateParser arrayByParsingTemplateAttributedString:[attrString attributedSubstringFromRange:MAKE_RANGE(NSMaxRange(startRange), sepRange.location == NSNotFound ? endRange.location : sepRange.location)]];
                
                font = [attrString attribute:NSFontAttributeName atIndex:startLoc effectiveRange:NULL];
                if (font == nil)
                    font = [NSFont userFontOfSize:0.0];
                int traits = [[NSFontManager sharedFontManager] traitsOfFont:font];
                [self setFontName:[font familyName]];
                [self setFontSize:[font pointSize]];
                [self setBold:(traits & NSBoldFontMask) != 0];
                [self setItalic:(traits & NSItalicFontMask) != 0];
            } else {
                NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont userFontOfSize:0.0], NSFontAttributeName, nil];
                if (startRange.location > 0)
                    [self setPrefixTemplate:[[[NSAttributedString alloc] initWithString:[string substringWithRange:MAKE_RANGE(0, startRange.location)] attributes:attrs] autorelease]];
                if (NSMaxRange(endRange) < length)
                    [self setSuffixTemplate:[[[NSAttributedString alloc] initWithString:[string substringWithRange:MAKE_RANGE(NSMaxRange(endRange), length)] attributes:attrs] autorelease]];
                if (NSMaxRange(sepRange) < endRange.location)
                    [self setSeparatorTemplate:[[[NSAttributedString alloc] initWithString:[string substringWithRange:MAKE_RANGE(NSMaxRange(sepRange), endRange.location)] attributes:attrs] autorelease]];
                
                parsedTemplate = [BDSKTemplateParser arrayByParsingTemplateString:[string substringWithRange:MAKE_RANGE(NSMaxRange(startRange), (sepRange.location == NSNotFound ? endRange.location : sepRange.location))]];
            }
        }
    }
    
    if (parsedTemplate && (templateDict = [self convertPubTemplate:parsedTemplate defaultFont:font])) {
        NSArray *itemTemplate = [templateDict objectForKey:@""];
        NSEnumerator *typeEnum = [typeTemplates objectEnumerator];
        BDSKTypeTemplate *template;
        
        if (itemTemplate)
            [[typeTemplates objectAtIndex:defaultTypeIndex] setItemTemplate:itemTemplate];
        
        while (template = [typeEnum nextObject]) {
            if (itemTemplate = [templateDict objectForKey:[template pubType]])
                [template setItemTemplate:itemTemplate];
        }
        
        [[self undoManager] removeAllActions];
        [self updateChangeCount:NSChangeCleared];
        
        return YES;
        
    } else if (outError) {
        *outError = [NSError errorWithDomain:@"BDSKTemplateDocumentErrorDomain" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Unable to open file.", @"Error description"), NSLocalizedDescriptionKey, NSLocalizedString(@"This template cannot be opened by BibDesk. You should edit it manually.", @"Error description"), NSLocalizedRecoverySuggestionErrorKey, nil]];
    }
    return NO;
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

- (unsigned)countOfTypeTemplates {
    return [typeTemplates count];
}

- (id)objectInTypeTemplatesAtIndex:(unsigned)idx {
    return [typeTemplates objectAtIndex:idx];
}

- (void)insertObject:(id)obj inTypeTemplatesAtIndex:(unsigned)idx {
    [typeTemplates insertObject:obj atIndex:idx];
}

- (void)removeObjectFromTypeTemplatesAtIndex:(unsigned)idx {
    [typeTemplates removeObjectAtIndex:idx];
}

- (unsigned)countOfSizes {
    return sizeof(BDSKDefaultFontSizes) / sizeof(float);
}

- (id)objectInSizesAtIndex:(unsigned)idx {
    return [NSNumber numberWithFloat:BDSKDefaultFontSizes[idx]];
}

- (unsigned)countOfTokenSizes {
    return 1 + sizeof(BDSKDefaultFontSizes) / sizeof(float);
}

- (id)objectInTokenSizesAtIndex:(unsigned)idx {
    return [NSNumber numberWithFloat:idx == 0 ? 0.0 : BDSKDefaultFontSizes[idx - 1]];
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
    [prefixTemplate setAttributedString:newPrefixTemplate ? newPrefixTemplate : [[[NSAttributedString alloc] init] autorelease]];
}

- (NSAttributedString *)suffixTemplate {
    return suffixTemplate;
}

- (void)setSuffixTemplate:(NSAttributedString *)newSuffixTemplate {
    [[[self undoManager] prepareWithInvocationTarget:self] setSuffixTemplate:[[suffixTemplate copy] autorelease]];
    [suffixTemplate setAttributedString:newSuffixTemplate ? newSuffixTemplate : [[[NSAttributedString alloc] init] autorelease]];
}

- (NSAttributedString *)separatorTemplate {
    return separatorTemplate;
}

- (void)setSeparatorTemplate:(NSAttributedString *)newSeparatorTemplate {
    [[[self undoManager] prepareWithInvocationTarget:self] setSeparatorTemplate:[[separatorTemplate copy] autorelease]];
    [separatorTemplate setAttributedString:newSeparatorTemplate ? newSeparatorTemplate : [[[NSAttributedString alloc] init] autorelease]];
}

- (BOOL)isRichText {
    return richText;
}

- (void)setRichText:(BOOL)newRichText {
    if (richText != newRichText) {
        [[[self undoManager] prepareWithInvocationTarget:self] setRichText:richText];
        richText = newRichText;
        
        [self updatePreview];
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
        [self updatePreview];
        [self updateTextViews];
    }
}

- (float)fontSize {
    return fontSize;
}

- (void)setFontSize:(float)newFontSize {
    if (fabsf(fontSize - newFontSize) > 0.0) {
        [[[self undoManager] prepareWithInvocationTarget:self] setFontSize:fontSize];
        fontSize = newFontSize;
        [self updatePreview];
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
        [self updatePreview];
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
        [self updatePreview];
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

- (unsigned int)defaultTypeIndex {
    return defaultTypeIndex;
}

- (void)setDefaultTypeIndex:(unsigned int)newDefaultTypeIndex {
    if (defaultTypeIndex != newDefaultTypeIndex) {
        [[[self undoManager] prepareWithInvocationTarget:self] setDefaultTypeIndex:defaultTypeIndex];
        unsigned int oldDefaultTypeIndex = defaultTypeIndex;
        [[typeTemplates objectAtIndex:oldDefaultTypeIndex] willChangeValueForKey:@"default"];
        [[typeTemplates objectAtIndex:newDefaultTypeIndex] willChangeValueForKey:@"default"];
        defaultTypeIndex = newDefaultTypeIndex;
        [[typeTemplates objectAtIndex:oldDefaultTypeIndex] didChangeValueForKey:@"default"];
        [[typeTemplates objectAtIndex:newDefaultTypeIndex] didChangeValueForKey:@"default"];
        [self updatePreview];
    }
}

- (NSString *)string {
    NSMutableString *string = [NSMutableString string];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"included = 1"];
    NSArray *includedTemplates = [typeTemplates filteredArrayUsingPredicate:predicate];
    NSEnumerator *tmplEnum = [includedTemplates objectEnumerator];
    BDSKTypeTemplate *template;
    NSString *altPrefix = @"";
    BOOL isSimple = [includedTemplates count] == 0 ||
        ([includedTemplates count] == 1 && [typeTemplates objectAtIndex:defaultTypeIndex] == [includedTemplates lastObject]);
    
    if ([prefixTemplate length]) {
        [string appendString:[prefixTemplate string]];
    }
    [string appendString:@"<$publications>\n"];
    if (isSimple) {
        [string appendString:[[typeTemplates objectAtIndex:defaultTypeIndex] string]];
    } else {
        while (template = [tmplEnum nextObject]) {
            if ([template isIncluded]) {
                [string appendFormat:@"<%@$pubType=%@?>\n", altPrefix, [template pubType]];
                [string appendString:[template string]];
                altPrefix = @"?";
            }
        }
        [string appendString:@"<?$pubType?>\n"];
        [string appendString:[[typeTemplates objectAtIndex:defaultTypeIndex] string]];
        [string appendString:@"</$pubType?>\n"];
    }
    if ([separatorTemplate length]) {
        [string appendString:@"<?$publications>\n"];
        [string appendString:[separatorTemplate string]];
    }
    [string appendString:@"</$publications>\n"];
    if ([suffixTemplate length]) {
        [string appendString:[suffixTemplate string]];
    }
    
    return string;
}

- (NSAttributedString *)attributedString {
    NSMutableAttributedString *attrString = nil;
    
    if (richText) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"included = 1"];
        NSArray *includedTemplates = [typeTemplates filteredArrayUsingPredicate:predicate];
        NSEnumerator *tmplEnum = [includedTemplates objectEnumerator];
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
            while (template = [tmplEnum nextObject]) {
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
    return attrString;
}

- (NSAttributedString *)previewAttributedString {
    // this should probably parse the template with a preview item
    return [self attributedString];
}

#pragma mark Actions

- (void)addFieldSheetDidEnd:(BDSKAddFieldSheetController *)addFieldController returnCode:(int)returnCode contextInfo:(void *)contextInfo {
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

- (IBAction)changeAppending:(id)sender {
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:BDSKValueOrNoneTransformerName];
    NSString *newValue = [transformer reverseTransformedValue:[sender representedObject]];
    [menuToken setValue:newValue forKey:@"appendingKey"];
}

- (IBAction)changeCasing:(id)sender {
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:BDSKValueOrNoneTransformerName];
    NSString *newValue = [transformer reverseTransformedValue:[sender representedObject]];
    [menuToken setValue:newValue forKey:@"casingKey"];
}

- (IBAction)changeCleaning:(id)sender {
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:BDSKValueOrNoneTransformerName];
    NSString *newValue = [transformer reverseTransformedValue:[sender representedObject]];
    [menuToken setValue:newValue forKey:@"cleaningKey"];
}

- (IBAction)changeNameStyle:(id)sender {
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:BDSKValueOrNoneTransformerName];
    NSString *newValue = [transformer reverseTransformedValue:[sender representedObject]];
    [menuToken setValue:newValue forKey:@"nameStyleKey"];
}

- (IBAction)changeJoinStyle:(id)sender {
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:BDSKValueOrNoneTransformerName];
    NSString *newValue = [transformer reverseTransformedValue:[sender representedObject]];
    [menuToken setValue:newValue forKey:@"joinmStyleKey"];
}

- (IBAction)changeUrlFormat:(id)sender {
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:BDSKValueOrNoneTransformerName];
    NSString *newValue = [transformer reverseTransformedValue:[sender representedObject]];
    [menuToken setValue:newValue forKey:@"urlFormatKey"];
}

- (IBAction)changeDateFormat:(id)sender {
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:BDSKValueOrNoneTransformerName];
    NSString *newValue = [transformer reverseTransformedValue:[sender representedObject]];
    [menuToken setValue:newValue forKey:@"dateFormatKey"];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = [menuItem action];
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:BDSKValueOrNoneTransformerName];
    if (action == @selector(changeAppending:)) {
        [menuItem setState:[[transformer transformedValue:[menuToken valueForKey:@"appendingKey"]] isEqualToString:[menuItem representedObject]]];
        return YES;
    } else if (action == @selector(changeCasing:)) {
        [menuItem setState:[[transformer transformedValue:[menuToken valueForKey:@"casingKey"]] isEqualToString:[menuItem representedObject]]];
        return YES;
    } else if (action == @selector(changeCleaning:)) {
        [menuItem setState:[[transformer transformedValue:[menuToken valueForKey:@"cleaningKey"]] isEqualToString:[menuItem representedObject]]];
        return YES;
    } else if (action == @selector(changeNameStyle:)) {
        [menuItem setState:[[transformer transformedValue:[menuToken valueForKey:@"nameStyleKey"]] isEqualToString:[menuItem representedObject]]];
        return YES;
    } else if (action == @selector(changeJoinStyle:)) {
        [menuItem setState:[[transformer transformedValue:[menuToken valueForKey:@"joinStyleKey"]] isEqualToString:[menuItem representedObject]]];
        return YES;
    } else if (action == @selector(changeUrlFormat:)) {
        [menuItem setState:[[transformer transformedValue:[menuToken valueForKey:@"urlFormatKey"]] isEqualToString:[menuItem representedObject]]];
        return YES;
    } else if (action == @selector(changeDateFormat:)) {
        [menuItem setState:[[transformer transformedValue:[menuToken valueForKey:@"dateFormatKey"]] isEqualToString:[menuItem representedObject]]];
        return YES;
    } else if ([[BDSKTemplateDocument superclass] instancesRespondToSelector:_cmd]) {
        return [super validateMenuItem:menuItem];
    } else {
        return YES;
    }
}

#pragma mark Setup and Update

#define SETUP_SUBMENU(parentMenu, index, key, selector) { \
    menu = [[parentMenu itemAtIndex:index] submenu]; \
    dictEnum = [[templateOptions valueForKey:key] objectEnumerator]; \
    while (dict = [dictEnum nextObject]) { \
        item = [menu addItemWithTitle:NSLocalizedStringFromTable([dict objectForKey:@"displayName"], @"TemplateOptions", @"") \
                               action:selector keyEquivalent:@""]; \
        [item setTarget:self]; \
        [item setRepresentedObject:[dict objectForKey:@"key"]]; \
    } \
}

- (void)setupOptionsMenus {
    NSMenu *menu;
    NSMenuItem *item;
    NSEnumerator *dictEnum;
    NSDictionary *dict;
    
    SETUP_SUBMENU(fieldOptionsMenu, 0, @"casing", @selector(changeCasing:));
    SETUP_SUBMENU(fieldOptionsMenu, 1, @"cleaning", @selector(changeCleaning:));
    SETUP_SUBMENU(fieldOptionsMenu, 2, @"appending", @selector(changeAppending:));
    SETUP_SUBMENU(fileOptionsMenu, 0, @"fileFormat", @selector(changeUrlFormat:));
    SETUP_SUBMENU(fileOptionsMenu, 1, @"appending", @selector(changeAppending:));
    SETUP_SUBMENU(urlOptionsMenu, 0, @"urlFormat", @selector(changeUrlFormat:));
    SETUP_SUBMENU(urlOptionsMenu, 1, @"appending", @selector(changeAppending:));
    SETUP_SUBMENU(personOptionsMenu, 0, @"nameStyle", @selector(changeNameStyle:));
    SETUP_SUBMENU(personOptionsMenu, 1, @"joinStyle", @selector(changeJoinStyle:));
    SETUP_SUBMENU(personOptionsMenu, 2, @"appending", @selector(changeAppending:));
    SETUP_SUBMENU(dateOptionsMenu, 0, @"dateFormat", @selector(changeDateFormat:));
    SETUP_SUBMENU(dateOptionsMenu, 1, @"appending", @selector(changeAppending:));
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
    float width = 0.0;
    NSEnumerator *tfEnum = [[NSArray arrayWithObjects:specialTokenField, requiredTokenField, optionalTokenField, defaultTokenField, nil] objectEnumerator];
    NSTokenField *tokenField;
    
    while (tokenField = [tfEnum nextObject]) {
        [tokenField sizeToFit];
        frame = [tokenField frame];
        width = fmaxf(width, NSWidth(frame));
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

- (void)updatePreview {
    [self willChangeValueForKey:@"previewAttributedString"];
    [self didChangeValueForKey:@"previewAttributedString"];
}

- (void)updateOptionView {
    NSArray *currentOptionViews = [[tokenOptionsBox contentView] subviews];
    NSMutableArray *optionViews = nil;
    
    if (selectedToken && [selectedToken isKindOfClass:[BDSKToken class]]) {
        switch ([selectedToken type]) {
            case BDSKFieldTokenType:
                optionViews = [NSMutableArray arrayWithObjects:fieldOptionsView, appendingOptionsView, nil];
                break;
            case BDSKFileTokenType:
                optionViews = [NSMutableArray arrayWithObjects:fileOptionsView, appendingOptionsView, nil];
                break;
            case BDSKURLTokenType:
                optionViews = [NSMutableArray arrayWithObjects:urlOptionsView, appendingOptionsView, nil];
                break;
            case BDSKPersonTokenType:
                optionViews = [NSMutableArray arrayWithObjects:personOptionsView, appendingOptionsView, nil];
                break;
            case BDSKDateTokenType:
                optionViews = [NSMutableArray arrayWithObjects:dateOptionsView, appendingOptionsView, nil];
                break;
            case BDSKTextTokenType:
                optionViews = [NSMutableArray arrayWithObjects:textOptionsView, nil];
                break;
        }
        if (richText)
            [optionViews addObject:fontOptionsView];
    }
    
    if ([optionViews isEqualToArray:currentOptionViews] == NO) {
        NSEnumerator *viewEnum = [optionViews objectEnumerator];
        NSView *view;
        NSRect frame = [[tokenOptionsBox contentView] bounds];
        NSPoint point = NSMakePoint(NSMinX(frame) + 7.0, NSMaxY(frame) - 7.0);
        
        [currentOptionViews retain];
        [currentOptionViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [currentOptionViews release];
        
        while (view = [viewEnum nextObject]) {
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
    NSTextView *textView = [notification object];
    if (textView == [itemTemplateTokenField currentEditor] ||
        textView == [specialTokenField currentEditor] ||
        textView == [requiredTokenField currentEditor] ||
        textView == [optionalTokenField currentEditor] ||
        textView == [defaultTokenField currentEditor]) {
        NSNotification *note = [NSNotification notificationWithName:BDSKTextViewDidChangeSelectionNotification object:textView];
        [[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostWhenIdle coalesceMask:NSNotificationCoalescingOnName forModes:nil];
    }
}

- (void)handleDelayedDidChangeSelectionNotification:(NSNotification *)notification {
    NSTextView *textView = [notification object];
    if (textView == [itemTemplateTokenField currentEditor] ||
        textView == [specialTokenField currentEditor] ||
        textView == [requiredTokenField currentEditor] ||
        textView == [optionalTokenField currentEditor] ||
        textView == [defaultTokenField currentEditor]) {
        
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
            }
        }
        [self setSelectedToken:token];
    }
}

- (void)handleDidEndEditingNotification:(NSNotification *)notification {
}

- (void)handleTokenDidChangeNotification:(NSNotification *)notification {
    BDSKToken *token = [notification object];
    if ([[typeTemplates valueForKeyPath:@"@unionOfArrays.itemTemplate"] indexOfObjectIdenticalTo:token] != NSNotFound) {
        [self updatePreview];
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
        [self updatePreview];
        // KVO in NSTokenField binding does not work
        if (template == [typeTemplates objectAtIndex:[tableView selectedRow]])
            [itemTemplateTokenField setObjectValue:[template itemTemplate]];
    }
}

- (void)textDidEndEditing:(NSNotification *)notification {
    NSText *textView = [notification object];
    if (textView == separatorTemplateTextView || textView == prefixTemplateTextView || textView == suffixTemplateTextView)
        [self updatePreview];
}

- (void)windowWillClose:(NSNotification *)notification {
    [ownerController setContent:nil];
}

#pragma mark NSTokenField delegate

// implement pasteboard delegate methods as a workaround for not doing the string->token transformation of tokenField:representedObjectForEditingString: (apparently needed for drag-and-drop on post-10.4 systems)
- (BOOL)tokenField:(NSTokenField *)tokenField writeRepresentedObjects:(NSArray *)objects toPasteboard:(NSPasteboard *)pboard {
    NSMutableString *string = [NSMutableString string];
    NSEnumerator *objectEnum = [objects objectEnumerator];
    id object;
    
    while (object = [objectEnum nextObject])
        [string appendString:[self tokenField:tokenField displayStringForRepresentedObject:object]];
    
    [pboard declareTypes:[NSArray arrayWithObjects:BDSKTemplateTokensPboardType, NSStringPboardType, nil] owner:nil];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:objects];
    [pboard setData:data forType:BDSKTemplateTokensPboardType];
    [pboard setString:string forType:NSStringPboardType];
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

- (NSTokenStyle)tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject {
    if ([representedObject isKindOfClass:[BDSKToken class]])
        return NSRoundedTokenStyle;
    else if ([representedObject isKindOfClass:[NSString class]])
        return NSPlainTextTokenStyle;
    return NSRoundedTokenStyle;
}

- (BOOL)tokenField:(NSTokenField *)tokenField hasMenuForRepresentedObject:(id)representedObject {
    return [representedObject isKindOfClass:[BDSKToken class]] && [(BDSKToken *)representedObject type] != BDSKTextTokenType && [(BDSKToken *)representedObject type] != BDSKNumberTokenType;
}

- (NSMenu *)tokenField:(NSTokenField *)tokenField menuForRepresentedObject:(id)representedObject {
    NSMenu *menu = nil;
    if ([representedObject isKindOfClass:[BDSKToken class]]) {
        menuToken = representedObject;
        switch ([(BDSKToken *)representedObject type]) {
            case BDSKFieldTokenType: menu = fieldOptionsMenu; break;
            case BDSKURLTokenType: menu = urlOptionsMenu; break;
            case BDSKFileTokenType: menu = fileOptionsMenu; break;
            case BDSKPersonTokenType: menu = personOptionsMenu; break;
            case BDSKDateTokenType: menu = dateOptionsMenu; break;
            default: menu = nil; break;
        }
    }
    return menu;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(unsigned)idx {
    if (tokenField == itemTemplateTokenField) {
        NSEnumerator *tokenEnum = [tokens objectEnumerator];
        id token;
        
        while (token = [tokenEnum nextObject]) {
            if ([token isKindOfClass:[BDSKToken class]]) {
                [token setDocument:self];
            }
        }
    }
    
    return tokens;
}

#pragma mark NSTableView delegate and dataSource

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self setSelectedToken:nil];
    [self updateTokenFields];
}

- (int)numberOfRowsInTableView:(NSTableView *)tv{ return 0; }

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row { return nil; }

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    int idx = [rowIndexes firstIndex];
    [pboard declareTypes:[NSArray arrayWithObjects:BDSKTypeTemplateRowsPboardType, nil] owner:nil];
    [pboard setPropertyList:[NSArray arrayWithObjects:[NSNumber numberWithInt:idx], nil] forType:BDSKTypeTemplateRowsPboardType];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op {
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKTypeTemplateRowsPboardType, nil]];
    
    if (op == NSTableViewDropAbove)
        [tv setDropRow:row == -1 ? 0 : row dropOperation:NSTableViewDropOn];
    
    return type ? NSDragOperationCopy : NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op{
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKTypeTemplateRowsPboardType, nil]];
    
    if (type) {
        int idx = [[[pboard propertyListForType:BDSKTypeTemplateRowsPboardType] lastObject] intValue];
        BDSKTypeTemplate *sourceTemplate = [typeTemplates objectAtIndex:idx];
        BDSKTypeTemplate *targetTemplate = [typeTemplates objectAtIndex:row];
        [targetTemplate setItemTemplate:[[[NSArray alloc] initWithArray:[sourceTemplate itemTemplate] copyItems:YES] autorelease]];
        return YES;
    }
    return NO;
}

#pragma mark NSSplitView delegate

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize {
    NSView *view1 = [[sender subviews] objectAtIndex:0];
    NSView *view2 = [[sender subviews] objectAtIndex:1];
    NSRect frame1 = [view1 frame];
    NSRect frame2 = [view2 frame];
    
    float contentWidth = NSWidth([sender frame]) - [sender dividerThickness];
    
    if (NSWidth(frame1) <= 1.0)
        frame1.size.width = 0.0;
    if (contentWidth < NSWidth(frame1))
        frame1.size.width = floorf(NSWidth(frame1) * contentWidth / (oldSize.width - [sender dividerThickness]));
    
    frame2.size.width = contentWidth - NSWidth(frame1);
    frame2.origin.x = NSMaxX(frame1) + [sender dividerThickness];
    
    [view1 setFrame:frame1];
    [view2 setFrame:frame2];
    [sender adjustSubviews];
}

- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset {
    return proposedMax - 600.0;
}

#pragma mark NSEditorRegistration

- (void)objectDidBeginEditing:(id)editor {
    if (CFArrayGetFirstIndexOfValue(editors, CFRangeMake(0, CFArrayGetCount(editors)), editor) == -1)
		CFArrayAppendValue((CFMutableArrayRef)editors, editor);		
}

- (void)objectDidEndEditing:(id)editor {
    CFIndex idx = CFArrayGetFirstIndexOfValue(editors, CFRangeMake(0, CFArrayGetCount(editors)), editor);
    if (idx != -1)
		CFArrayRemoveValueAtIndex((CFMutableArrayRef)editors, idx);		
}

- (BOOL)commitEditing {
    CFIndex idx = CFArrayGetCount(editors);
    
	while (idx--)
		if([(NSObject *)(CFArrayGetValueAtIndex(editors, idx)) commitEditing] == NO)
			return NO;
    
    return YES;
}

#pragma mark Reading

- (NSDictionary *)convertPubTemplate:(NSArray *)templateArray defaultFont:(NSFont *)defaultFont {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSArray *itemTemplate;
    BDSKTag *tag = [templateArray count] ? [templateArray objectAtIndex:0] : nil;
    
    if ([tag type] == BDSKConditionTagType && [[(BDSKConditionTag *)tag keyPath] isEqualToString:@"pubType"]) {
        if ([(BDSKConditionTag *)tag matchType] != 1)
            return nil;
        
        NSArray *matchStrings = [(BDSKConditionTag *)tag matchStrings];
        unsigned int i = 0, count = [matchStrings count];
        
        for (i = 0; i < count; i++) {
            if (itemTemplate = [self convertItemTemplate:[(BDSKConditionTag *)tag subtemplateAtIndex:i] defaultFont:defaultFont])
                [result setObject:itemTemplate forKey:[matchStrings objectAtIndex:i]];
            else
                return nil;
        }
        if ([[(BDSKConditionTag *)tag subtemplates] count] > count && (itemTemplate = [self convertItemTemplate:[(BDSKConditionTag *)tag subtemplateAtIndex:count] defaultFont:defaultFont]))
            [result setObject:itemTemplate forKey:@""];
        else
            return nil;
            
    } else {
        if (itemTemplate = [self convertItemTemplate:templateArray defaultFont:defaultFont])
            [result setObject:itemTemplate forKey:@""];
        else
            return nil;
    }
    
    return result;
}

- (NSArray *)convertItemTemplate:(NSArray *)templateArray defaultFont:(NSFont *)defaultFont {
    NSMutableArray *result = [NSMutableArray array];
    int type;
    NSEnumerator *tagEnum = [templateArray objectEnumerator];
    BDSKTag *tag;
    id token;
    
    while (tag = [tagEnum nextObject]) {
        type = [(BDSKTag *)tag type];
        
        if (type == BDSKTextTagType) {
            if (token = [self tokensForTextTag:tag allowText:YES defaultFont:defaultFont])
                [result addObjectsFromArray:token];
            else
                return nil;
        } else if (type == BDSKValueTagType) {
            if (token = [self tokenForValueTag:(BDSKValueTag *)tag defaultFont:defaultFont])
                [result addObject:token];
            else
                return nil;
        } else if (type == BDSKConditionTagType) {
            if (token = [self tokenForConditionTag:(BDSKConditionTag *)tag defaultFont:defaultFont])
                [result addObject:token];
            else
                return nil;
        }
    }
    
    return result;
}

- (NSArray *)tokensForTextTag:(BDSKTag *)tag allowText:(BOOL)allowText defaultFont:(NSFont *)defaultFont {
    NSMutableArray *tokens = [NSMutableArray array];
    if (defaultFont) {
        NSAttributedString *text = [(BDSKRichTextTag *)tag attributedText];
        unsigned int length = [text length];
        NSRange range = NSMakeRange(0, 0);
        
        while (NSMaxRange(range) < length) {
            id token;
            NSFont *font = [text attribute:NSFontAttributeName atIndex:range.location longestEffectiveRange:&range inRange:NSMakeRange(range.location, length - range.location)];
            if (allowText && [font isEqual:defaultFont]) {
                token = [[(BDSKRichTextTag *)tag attributedText] string];
            } else {
                token = [[[BDSKTextToken alloc] initWithTitle:[text string]] autorelease];
                [self setFont:font ofToken:token defaultFont:defaultFont];
            }
            [tokens addObject:token];
        }
    } else if (allowText) {
        [tokens addObject:[(BDSKTextTag *)tag text]];
    } else {
        [tokens addObject:[[[BDSKTextToken alloc] initWithTitle:[(BDSKTextTag *)tag text]] autorelease]];
    }
    return tokens;
}

- (id)tokenForConditionTag:(BDSKConditionTag *)tag defaultFont:(NSFont *)defaultFont {
    int count = [[tag subtemplates] count];
    if ([(BDSKConditionTag *)tag matchType] != 0 || count > 2)
        return nil;
    
    NSArray *nonemptyTemplate = [tag subtemplateAtIndex:0];
    NSArray *emptyTemplate = count > 1 ? [tag subtemplateAtIndex:1] : nil;
    id token = nil;
    
    if ([nonemptyTemplate count] == 1 && [(BDSKTag *)[nonemptyTemplate lastObject] type] == BDSKTextTagType) {
        NSArray *keys = [[tag keyPath] componentsSeparatedByString:@"."];
        NSArray *tokens;
        if ([keys count] != 2 || [[keys objectAtIndex:0] isEqualToString:@"fields"] == NO) {
            return nil;
        }
        if (tokens = [self tokensForTextTag:tag allowText:NO defaultFont:defaultFont]) {
            if ([tokens count] == 1) {
                token = [tokens lastObject];
                [token setField:[keys lastObject]];
                if ([emptyTemplate count]) {
                    id textTag = [emptyTemplate lastObject];
                    if ([(BDSKTag *)textTag type] != BDSKTextTagType)
                        return nil;
                    [token setAltText:defaultFont ? [[(BDSKRichTextTag *)textTag attributedText] string] : [(BDSKTextTag *)textTag text]];
                }
            } else {
                return nil;
            }
        } else {
            return nil;
        }
    } else if ([emptyTemplate count] == 0 && [nonemptyTemplate count] < 3) {
        int i = 0;
        BDSKTag *subtag = [nonemptyTemplate objectAtIndex:i];
        NSString *prefix = nil, *suffix = nil;
        count = [nonemptyTemplate count];
        
        if ([subtag type] == BDSKTextTagType) {
            prefix = defaultFont ? [[(BDSKRichTextTag *)subtag attributedText] string] : [(BDSKTextTag *)subtag text];
            subtag = ++i < count ? [nonemptyTemplate objectAtIndex:i] : nil;
        }
        if ([subtag type] == BDSKValueTagType && [[(BDSKValueTag *)subtag keyPath] isEqualToString:[tag keyPath]]) {
            token = [self tokenForValueTag:(BDSKValueTag *)subtag defaultFont:defaultFont];
            subtag = ++i < count ? [nonemptyTemplate objectAtIndex:i] : nil;
        } else
            return nil;
        if (subtag) {
            if ([subtag type] == BDSKTextTagType) {
                suffix = defaultFont ? [[(BDSKRichTextTag *)subtag attributedText] string] : [(BDSKTextTag *)subtag text];
            } else
                return nil;
        }
        if (prefix)
            [token setPrefix:prefix];
        if (suffix)
            [token setSuffix:suffix];
    } else
        return nil;
    
    return token;
}

- (id)tokenForValueTag:(BDSKValueTag *)tag defaultFont:(NSFont *)defaultFont {
    NSArray *keys = [[tag keyPath] componentsSeparatedByString:@"."];
    NSString *key = [keys count] ? [keys objectAtIndex:0] : nil;
    BDSKToken *token = nil;
    int type;
    NSString *field = nil;
    int i = 0;
    
    if ([key isEqualToString:@"fields"] || [key isEqualToString:@"urls"] || [key isEqualToString:@"persons"])
        field = [keys objectAtIndex:++i];
    else if ([key isEqualToString:@"citeKey"])
        field = BDSKCiteKeyString;
    else if ([key isEqualToString:@"pubType"])
        field = BDSKPubTypeString;
    else if ([key isEqualToString:@"itemIndex"])
        field = @"Item Index";
    else if ([key isEqualToString:@"authors"])
        field = BDSKAuthorString;
    else if ([key isEqualToString:@"editors"])
        field = BDSKEditorString;
    else
        return nil;
    
    token = [BDSKToken tokenWithField:field];
    type = [(BDSKToken *)token type];
    keys = [keys subarrayWithRange:NSMakeRange(++i, [keys count] - i)];
    int count = [keys count];
    NSString *property;
    
    if (type == BDSKPersonTokenType && [keys firstObjectCommonWithArray:[templateOptions valueForKeyPath:@"joinStyle.key"]] == nil)
        return nil;
    
    for (i = 0; i < count; i++) {
        key = [keys objectAtIndex:i];
        if (type == BDSKFileTokenType && [key isEqualToString:@"path"] && i <= count) {
            key = [@"path." stringByAppendingString:[keys objectAtIndex:i + 1]];
            if ([self propertyForKey:key tokenType:type])
                i++;
            else
                key = @"path";
        }
        if (property = [self propertyForKey:key tokenType:type])
            [token setValue:key forKey:property];
        else
            return nil;
    }
    
    if (defaultFont) {
        NSFont *font = [[(BDSKRichValueTag *)tag attributes] objectForKey:NSFontAttributeName];
        [self setFont:font ofToken:token defaultFont:defaultFont];
    }
    
    return token;
}

- (NSString *)propertyForKey:(NSString *)key tokenType:(int)type {
    if (type == BDSKFieldTokenType) {
        if ([[templateOptions valueForKeyPath:@"casing.key"] containsObject:key])
            return @"casingKey";
        if ([[templateOptions valueForKeyPath:@"cleaning.key"] containsObject:key])
            return @"cleaningKey";
        if ([[templateOptions valueForKeyPath:@"appending.key"] containsObject:key])
            return @"appendingKey";
    } else if (type == BDSKURLTokenType) {
        if ([[templateOptions valueForKeyPath:@"urlFormat.key"] containsObject:key])
            return @"urlFormatKey";
        if ([[templateOptions valueForKeyPath:@"appending.key"] containsObject:key])
            return @"appendingKey";
    } else if (type == BDSKFileTokenType) {
        if ([[templateOptions valueForKeyPath:@"fileFormat.key"] containsObject:key])
            return @"fileFormatKey";
        if ([[templateOptions valueForKeyPath:@"appending.key"] containsObject:key])
            return @"appendingKey";
    } else if (type == BDSKPersonTokenType) {
        if ([[templateOptions valueForKeyPath:@"nameStyle.key"] containsObject:key])
            return @"nameStyleKey";
        if ([[templateOptions valueForKeyPath:@"joinStyle.key"] containsObject:key])
            return @"joinStyleKey";
        if ([[templateOptions valueForKeyPath:@"appending.key"] containsObject:key])
            return @"appendingKey";
    }
    return nil;
}

- (void)setFont:(NSFont *)font ofToken:(BDSKToken *)token defaultFont:(NSFont *)defaultFont{
    if ([font isEqual:defaultFont] == NO) {
        int defaultTraits = [[NSFontManager sharedFontManager] traitsOfFont:defaultFont];
        int traits = [[NSFontManager sharedFontManager] traitsOfFont:font];
        BOOL defaultBold = (defaultTraits & NSBoldFontMask) != 0;
        BOOL defaultItalic = (defaultTraits & NSItalicFontMask) != 0;
        BOOL isBold = (traits & NSBoldFontMask) != 0;
        BOOL isItalic = (traits & NSItalicFontMask) != 0;
        
        if ([[font familyName] isEqualToString:[defaultFont familyName]] == NO)
            [token setFontName:[font familyName]];
        if (fabsf([font pointSize] - [defaultFont pointSize]) > 0.0)
            [token setFontSize:[font pointSize]];
        if (isBold != defaultBold)
            [token setBold:isBold];
        if (isItalic != defaultItalic)
            [token setItalic:isItalic];
    }
}

@end

#pragma mark -

@interface BDSKTokenFieldCell : NSTokenFieldCell
@end

@implementation BDSKTokenFieldCell

+ (void)load {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    // in later versions, messing with the binding info causes an infinite loop and crash 
    if (floor(NSAppKitVersionNumber) <= 824 /* 10.4 */)
        [BDSKTokenFieldCell poseAsClass:NSClassFromString(@"NSTokenFieldCell")];
    [pool release];
}

- (void)setObjectValue:(id)value {
    [super setObjectValue:value];
    // updating in NSTokenField binding does not work for drop of tokens
	NSDictionary *valueBindingInformation = [[self controlView] infoForBinding:@"value"];
	if (valueBindingInformation != nil) {
		id valueBindingObject = [valueBindingInformation objectForKey:NSObservedObjectKey];
		NSString *valueBindingKeyPath = [valueBindingInformation objectForKey:NSObservedKeyPathKey];
		
		[valueBindingObject setValue:[self objectValue] forKeyPath:valueBindingKeyPath];
	}
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
	return string ? string : @"<None>";
}

- (id)reverseTransformedValue:(id)string {
	return [string isEqualToString:@"<None>"] ? nil : string;
}

@end

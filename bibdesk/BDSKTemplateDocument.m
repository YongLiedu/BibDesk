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

NSString *BDSKTextTemplateDocumentType = @"Text Template";
NSString *BDSKRichTextTemplateDocumentType = @"Rich Text Template";

static float BDSKDefaultFontSizes[] = {8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0, 48.0, 64.0};

static NSString *BDSKTypeTemplateRowsPboardType = @"BDSKTypeTemplateRowsPboardType";
static NSString *BDSKValueOrNoneTransformerName = @"BDSKValueOrNone";

@interface BDSKValueOrNoneTransformer : NSValueTransformer @end

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
        [specialTokens addObject:[self tokenForField:@"Rich Text"]];
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
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];
    
    [self setupOptionsMenus];
    
    [requiredTokenField setEditable:NO];
    [requiredTokenField setBezeled:NO];
    [requiredTokenField setDrawsBackground:NO];
    [optionalTokenField setEditable:NO];
    [optionalTokenField setBezeled:NO];
    [optionalTokenField setDrawsBackground:NO];
    [defaultTokenField setEditable:NO];
    [defaultTokenField setBezeled:NO];
    [defaultTokenField setDrawsBackground:NO];
    [specialTokenField setEditable:NO];
    [specialTokenField setBezeled:NO];
    [specialTokenField setDrawsBackground:NO];
    [itemTemplateTokenField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@""]];
    
    [tableView registerForDraggedTypes:[NSArray arrayWithObjects:BDSKTypeTemplateRowsPboardType, nil]];
    
	[fieldField setFormatter:[[[BDSKFieldNameFormatter alloc] init] autorelease]];
    
    [ownerController setContent:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidChangeSelectionNotification:) 
                                                 name:NSTextViewDidChangeSelectionNotification object:nil];
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

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    if (outError)
        *outError = [NSError errorWithDomain:@"BDSKTemplateDocumentErrorDomain" code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Unable to open file.", @"Error description"), NSLocalizedDescriptionKey, NSLocalizedString(@"BibDesk is currently unable to read templates.", @"Error description"), NSLocalizedRecoverySuggestionErrorKey, nil]];
    return NO;
}

- (void)updatePreview {
    [self willChangeValueForKey:@"previewAttributedString"];
    [self didChangeValueForKey:@"previewAttributedString"];
}

- (void)updateOptionView {
    NSArray *optionViews = [[[tokenOptionsBox contentView] subviews] copy];
    [optionViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [optionViews release];
    
    if (selectedToken) {
        int type = [selectedToken isKindOfClass:[BDSKToken class]] ? [selectedToken type] : -1;
        NSView *view = nil;
        
        switch (type) {
            case BDSKFieldTokenType:
                view = fieldOptionsView;
                break;
            case BDSKFileTokenType:
                view = fileOptionsView;
                break;
            case BDSKURLTokenType:
                view = urlOptionsView;
                break;
            case BDSKPersonTokenType:
                view = personOptionsView;
                break;
            case BDSKTextTokenType:
                view = textOptionsView;
                break;
        }
        NSRect frame = [[tokenOptionsBox contentView] bounds];
        NSPoint point = NSMakePoint(NSMinX(frame) + 7.0, NSMaxY(frame) - 7.0);
        if (view) {
            frame = [view frame];
            point.y -= NSHeight(frame);
            frame.origin = point;
            [view setFrame:frame];
            [[tokenOptionsBox contentView] addSubview:view];
        }
        if (type != BDSKTextTokenType) {
            frame = [appendingOptionsView frame];
            point.y -= NSHeight(frame);
            frame.origin = point;
            [appendingOptionsView setFrame:frame];
            [[tokenOptionsBox contentView] addSubview:appendingOptionsView];
        }
        if (richText) {
            frame = [fontOptionsView frame];
            point.y -= NSHeight(frame);
            frame.origin = point;
            [fontOptionsView setFrame:frame];
            [[tokenOptionsBox contentView] addSubview:fontOptionsView];
        }
    }
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
        defaultTypeIndex = newDefaultTypeIndex;
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
    } else if ([[BDSKTemplateDocument superclass] instancesRespondToSelector:_cmd]) {
        return [super validateMenuItem:menuItem];
    } else {
        return YES;
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
        
        BDSKToken *token = nil;
        NSArray *selRanges = [textView selectedRanges];
        if ([selRanges count] == 1) {
            NSRange range = [[selRanges lastObject] rangeValue];
            if (range.length == 1) {
                NSDictionary *attrs = [[textView textStorage] attributesAtIndex:range.location effectiveRange:NULL];
                id attachment = [attrs objectForKey:NSAttachmentAttributeName];
                if ([attachment respondsToSelector:@selector(representedObject)] && [[attachment representedObject] isKindOfClass:[BDSKToken class]]) {
                    token = [attachment representedObject];
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
    // only add NSStringPboardType to fool the field editor into accepting the drop on 10.4
    [pboard declareTypes:[NSArray arrayWithObjects:[super description], NSStringPboardType, nil] owner:nil];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:objects];
    [pboard setData:data forType:[super description]];
    [pboard setString:@"NSBrokenField" forType:NSStringPboardType];
    return nil != data;
}

- (NSArray *)tokenField:(NSTokenField *)tokenField readFromPasteboard:(NSPasteboard *)pboard {
    if ([[pboard types] containsObject:[super description]] == NO)
        return nil;
    
    NSData *data = [pboard dataForType:[super description]];
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
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
    return [representedObject isKindOfClass:[BDSKToken class]] && [(BDSKToken *)representedObject type] != BDSKTextTokenType;
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
            case BDSKTextTokenType: menu = nil; break;
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

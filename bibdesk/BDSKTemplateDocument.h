//
//  BDSKTemplateDocument.h
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


#import <Cocoa/Cocoa.h>

extern NSString *BDSKTextTemplateDocumentType;
extern NSString *BDSKRichTextTemplateDocumentType;

@protocol BDSKTokenFieldDelegate <NSTokenFieldDelegate>
@optional
- (void)tokenField:(NSTokenField *)tokenField textViewDidChangeSelection:(NSTextView *)textView;
@end

@class BDSKToken, BDSKTypeTemplate, BDSKTableView;

@interface BDSKTemplateDocument : NSDocument <NSTableViewDelegate, NSTableViewDataSource, BDSKTokenFieldDelegate>
{
    IBOutlet NSObjectController *ownerController;
    
    IBOutlet NSTextView *previewTextView;
    
    IBOutlet NSSplitView *textViewSplitView;
    IBOutlet NSSplitView *tableViewSplitView;
    
    IBOutlet NSPopUpButton *defaultTypePopUp;
    IBOutlet NSButton *richTextCheckButton;
    IBOutlet NSPopUpButton *fontNamePopUp;
    IBOutlet NSComboBox *fontSizeComboBox;
    IBOutlet NSButton *boldCheckButton;
    IBOutlet NSButton *italicCheckButton;
    IBOutlet NSTextView *prefixTemplateTextView;
    IBOutlet NSTextView *separatorTemplateTextView;
    IBOutlet NSTextView *suffixTemplateTextView;
    
    IBOutlet BDSKTableView *tableView;
    IBOutlet NSArrayController *templateArrayController;
    IBOutlet NSObjectController *tokenObjectController;
    IBOutlet NSTokenField *specialTokenField;
    IBOutlet NSTokenField *requiredTokenField;
    IBOutlet NSTokenField *optionalTokenField;
    IBOutlet NSTokenField *defaultTokenField;
    IBOutlet NSTokenField *itemTemplateTokenField;
    IBOutlet NSButton *addFieldButton;
    IBOutlet NSBox *tokenOptionsBox;
    
    IBOutlet NSView *fieldOptionsView;
    IBOutlet NSView *appendingOptionsView;
    IBOutlet NSView *fontOptionsView;
    IBOutlet NSView *urlOptionsView;
    IBOutlet NSView *personOptionsView;
    IBOutlet NSView *linkedFileOptionsView;
    IBOutlet NSView *dateOptionsView;
    IBOutlet NSView *numberOptionsView;
    IBOutlet NSView *textOptionsView;
    IBOutlet NSMenu *fieldOptionsMenu;
    IBOutlet NSMenu *urlOptionsMenu;
    IBOutlet NSMenu *personOptionsMenu;
    IBOutlet NSMenu *linkedFileOptionsMenu;
    IBOutlet NSMenu *dateOptionsMenu;
    IBOutlet NSMenu *numberOptionsMenu;
    IBOutlet NSPopUpButton *fieldFontNamePopUp;
    IBOutlet NSComboBox *fieldFontSizeComboBox;
    IBOutlet NSButton *fieldBoldCheckButton;
    IBOutlet NSButton *fieldItalicCheckButton;
    IBOutlet NSPopUpButton *appendingPopUp;
    IBOutlet NSTextField *prefixField;
    IBOutlet NSTextField *suffixField;
    IBOutlet NSPopUpButton *capitalizationPopUp;
    IBOutlet NSPopUpButton *cleaningPopUp;
    IBOutlet NSPopUpButton *urlPopUp;
    IBOutlet NSPopUpButton *nameStylePopUp;
    IBOutlet NSPopUpButton *joinStylePopUp;
    IBOutlet NSPopUpButton *linkedFileFormatStylePopUp;
    IBOutlet NSPopUpButton *linkedFileJoinStylePopUp;
    IBOutlet NSPopUpButton *datePopUp;
    IBOutlet NSPopUpButton *counterStylePopUp;
    IBOutlet NSPopUpButton *counterCapitalizationPopUp;
    IBOutlet NSTextField *textField;
    IBOutlet NSTextField *fieldField;
    IBOutlet NSTextField *altTextField;
    
    NSArray *fonts;
    NSArray *tokenFonts;
    NSDictionary *templateOptions;
    NSMutableArray *typeTemplates;
    NSMutableArray *specialTokens;
    NSMutableArray *defaultTokens;
    NSMutableDictionary *fieldTokens;
    NSMutableAttributedString *prefixTemplate;
    NSMutableAttributedString *suffixTemplate;
    NSMutableAttributedString *separatorTemplate;
    BOOL richText;
    NSString *fontName;
    CGFloat fontSize;
    BOOL bold;
    BOOL italic;
    BDSKToken *selectedToken;
    BDSKToken *menuToken;
    NSUInteger defaultTypeIndex;
    
    NSString *string;
    NSAttributedString *attributedString;
}

- (NSArray *)typeTemplates;

- (NSArray *)specialTokens;
- (void)setSpecialTokens:(NSArray *)newSpecialTokens;

- (NSArray *)defaultTokens;
- (void)setDefaultTokens:(NSArray *)newDefaultTokens;

- (NSAttributedString *)prefixTemplate;
- (void)setPrefixTemplate:(NSAttributedString *)newPrefixTemplate;

- (NSAttributedString *)suffixTemplate;
- (void)setSuffixTemplate:(NSAttributedString *)newSuffixTemplate;

- (NSAttributedString *)separatorTemplate;
- (void)setSeparatorTemplate:(NSAttributedString *)newSeparatorTemplate;

- (BOOL)isRichText;
- (void)setRichText:(BOOL)newRichText;

- (NSString *)fontName;
- (void)setFontName:(NSString *)newFontName;

- (CGFloat)fontSize;
- (void)setFontSize:(CGFloat)newFontSize;

- (BOOL)isBold;
- (void)setBold:(BOOL)newBold;

- (BOOL)isItalic;
- (void)setItalic:(BOOL)newItalic;

- (BDSKToken *)selectedToken;
- (void)setSelectedToken:(BDSKToken *)newSelectedToken;

- (NSUInteger)defaultTypeIndex;
- (void)setDefaultTypeIndex:(NSUInteger)newDefaultTypeIndex;

- (NSAttributedString *)attributedString;
- (NSString *)string;

- (NSAttributedString *)previewAttributedString;

- (IBAction)addField:(id)sender;

- (void)startObservingTypeTemplate:(BDSKTypeTemplate *)typeTemplate;
- (void)stopObservingTypeTemplate:(BDSKTypeTemplate *)typeTemplate;
- (void)startObservingTokens:(NSArray *)tokens;
- (void)stopObservingTokens:(NSArray *)tokens;

@end

#pragma mark -

@interface BDSKTokenField : NSTokenField
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
- (id <BDSKTokenFieldDelegate>)delegate;
- (void)setDelegate:(id <BDSKTokenFieldDelegate>)newDelegate;
#endif
@end

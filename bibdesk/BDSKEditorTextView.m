//
//  BDSKEditorTextView.m
//  Bibdesk
//
//  Created by Adam Maxwell on 02/28/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "BDSKEditorTextView.h"

static NSString *BDSKEditorFontNameKey = @"BDSKEditorFontNameKey";
static NSString *BDSKEditorFontSizeKey = @"BDSKEditorFontSizeKey";

@implementation BDSKEditorTextView

- (void)awakeFromNib
{
    NSString *fontName = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKEditorFontNameKey];
    float fontSize = [[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:BDSKEditorFontSizeKey];
    NSFont *font = nil;
    if(fontName != nil)
        font = [NSFont fontWithName:fontName size:fontSize];
    // could be nil
    if(font == nil)
        font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
    
    [self setFont:font];
    [[self textStorage] setDelegate:self];
}

- (void)changeFont:(id)sender
{
    // probably not necessary, but won't hurt
    [super changeFont:sender];
    
    // get the new font from the font panel
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSFont *font = [fontManager convertFont:[fontManager selectedFont]];
    
    // apply the new font to the entire range; this shouldn't dirty the document, though
    NSTextStorage *textStorage = [self textStorage];
    [[self undoManager] disableUndoRegistration];
    [textStorage beginEditing];
    [textStorage addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, [textStorage length])];
    [textStorage endEditing];
    [[self undoManager] enableUndoRegistration];

    // save it to prefs for next time
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:[font fontName] forKey:BDSKEditorFontNameKey];
    [[OFPreferenceWrapper sharedPreferenceWrapper] setFloat:[font pointSize] forKey:BDSKEditorFontSizeKey];
}

- (NSString *)editedWordFromRange:(NSRange *)editedRange inString:(NSString *)string
{
    NSRange range = [string rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] options:NSBackwardsSearch range:NSMakeRange(0, editedRange->location)];
    NSString *lastWord = nil;
    if(range.length){
        // account for the whitespace character
        range.location += 1;
        
        // use the end of the edited range to determine the length
        range.length = NSMaxRange(*editedRange) - range.location;
        lastWord = [string substringWithRange:range];    
        *editedRange = range;
    }
    return lastWord;
}

- (void)fixAttributesForURLs
{
    NSTextStorage *textStorage = [self textStorage];
    NSString *string = [textStorage string];
    
    int start, length = [string length];
    NSRange wordRange, range = NSMakeRange(0, 0);
    NSString *urlString;
    NSURL *url;
    
    do {
        start = NSMaxRange(range);
        range = [string rangeOfString:@"://" options:0 range:NSMakeRange(start, length - start)];
        
        if(range.length){
            // get the next word boundary (use punctuation?)
            wordRange = [string rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] options:0 range:NSMakeRange(range.location, length - range.location)];
            wordRange.length -= 1; // lose the whitespace
            wordRange.location = wordRange.location == NSNotFound ? length : wordRange.location;
            
            range = NSUnionRange(range, wordRange);
            urlString = [self editedWordFromRange:&range inString:string];
            url = urlString ? [[NSURL alloc] initWithString:urlString] : nil;
            if([url scheme]) [textStorage addAttribute:NSLinkAttributeName value:url range:range];
        }
        
    } while (range.length);
}

- (void)textStorageDidProcessEditing:(NSNotification *)notification
{    
    NSTextStorage *textStorage = [notification object];    
    NSString *string = [textStorage string];
    
    NSRange editedRange = [textStorage editedRange];
    
    // if this is > 1, it's likely a paste or initial insertion, so fix the whole thing
    if(editedRange.length > 1){
        [self fixAttributesForURLs];
    } else if(editedRange.length && editedRange.location != NSNotFound){
        NSString *editedWord = [self editedWordFromRange:&editedRange inString:string];
        if([editedWord rangeOfString:@"://"].length == 0)
            editedWord = nil;
        NSURL *url = editedWord ? [[NSURL alloc] initWithString:editedWord] : nil;
        if(url != nil)
            [textStorage addAttribute:NSLinkAttributeName value:url range:editedRange];
        else
            [textStorage removeAttribute:NSLinkAttributeName range:editedRange];
        [url release];
    }
}

@end

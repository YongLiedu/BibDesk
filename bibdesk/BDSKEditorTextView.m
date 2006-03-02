//
//  BDSKEditorTextView.m
//  Bibdesk
//
//  Created by Adam Maxwell on 02/28/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "BDSKEditorTextView.h"
#import "NSURL_BDSKExtensions.h"

// these constants are private to the textview
static NSString *BDSKEditorFontNameKey = @"BDSKEditorFontNameKey";
static NSString *BDSKEditorFontSizeKey = @"BDSKEditorFontSizeKey";
static NSString *BDSKEditorTextViewFontChangedNotification = nil;

@interface BDSKEditorTextView (Private)

- (void)handleFontChangedNotification:(NSNotification *)note;
- (NSString *)URLStringFromRange:(NSRange *)startRange inString:(NSString *)string;
- (void)fixAttributesForURLs;

@end

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
    
    // make sure no one else uses this notification name, since it's going into the default notification center
    if(BDSKEditorTextViewFontChangedNotification == nil)
        BDSKEditorTextViewFontChangedNotification = [[[NSProcessInfo processInfo] globallyUniqueString] copy];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleFontChangedNotification:) name:BDSKEditorTextViewFontChangedNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)changeFont:(id)sender
{
    // this change shouldn't dirty our document
    [[self undoManager] disableUndoRegistration];

    // probably not necessary, but won't hurt
    [super changeFont:sender];
    
    // get the new font from the font panel
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSFont *font = [fontManager convertFont:[fontManager selectedFont]];
    
    // apply the new font to the entire range
    NSTextStorage *textStorage = [self textStorage];
    [textStorage beginEditing];
    [textStorage addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, [textStorage length])];
    [textStorage endEditing];
    
    [[self undoManager] enableUndoRegistration];

    // save it to prefs for next time
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:[font fontName] forKey:BDSKEditorFontNameKey];
    [[OFPreferenceWrapper sharedPreferenceWrapper] setFloat:[font pointSize] forKey:BDSKEditorFontSizeKey];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKEditorTextViewFontChangedNotification object:self];
}

- (void)textStorageDidProcessEditing:(NSNotification *)notification
{    
    NSTextStorage *textStorage = [notification object];    
    NSString *string = [textStorage string];
    
    NSRange editedRange = [textStorage editedRange];
    
    // if this is > 1, it's likely a paste or initial insertion, so fix the whole thing
    if(editedRange.length > 1){
        [self fixAttributesForURLs];
    } else if(editedRange.location != NSNotFound){
        NSString *editedWord = [self URLStringFromRange:&editedRange inString:string];
        if([editedWord rangeOfString:@"://"].length == 0)
            editedWord = nil;
        NSURL *url = editedWord ? [[NSURL alloc] initWithString:editedWord] : nil;
        if(url != nil)
            [textStorage addAttribute:NSLinkAttributeName value:url range:editedRange];
        else
            [textStorage removeAttribute:NSLinkAttributeName range:editedRange];
        [url release];
    } else {
        NSLog(@"I am confused: edited range is %@", NSStringFromRange(editedRange));
    }
}

@end

@implementation BDSKEditorTextView (Private)

- (void)handleFontChangedNotification:(NSNotification *)note;
{
    if([note object] != self){
        NSLog(@"%@ fix me", NSStringFromSelector(_cmd));
    }
}

static inline BOOL hasValidPercentEscapeFromIndex(NSString *string, unsigned startIndex)
{
    NSCParameterAssert(startIndex == 0 || [string length] > startIndex);
    // require % and at least two additional chars
    if([string isEqualToString:@""] || [string characterAtIndex:startIndex] != '%' || [string length] <= (startIndex + 2))
        return NO;
    
    // both characters following the % should be digits 0-9
    unichar ch1 = [string characterAtIndex:(startIndex + 1)];
    unichar ch2 = [string characterAtIndex:(startIndex + 2)];
    return ((ch1 <= '9' && ch1 >= '0') && (ch2 <= '9' && ch2 >= '0')) ? YES : NO;
}

// Starts in the middle of a "word" (some range of interest) and searches forward and backward to find boundaries marked by characters that would be illegal for a URL
- (NSString *)URLStringFromRange:(NSRange *)startRange inString:(NSString *)string
{
    unsigned startIdx = NSNotFound, endIdx = NSNotFound;
    NSRange range = NSMakeRange(0, startRange->location);
    
    do {
        range = [string rangeOfCharacterFromSet:[NSURL illegalURLCharacterSet] options:NSBackwardsSearch range:range];
        
        if(range.location != NSNotFound){
            // advance past the illegal character
            startIdx = range.location + 1;
        } else {
            // this has a URL as the first word in the string
            startIdx = 0;
            break;
        }
        
        // move the search range interval towards the beginning of the string
        range = NSMakeRange(0, range.location);
           
    } while (startIdx != NSNotFound && hasValidPercentEscapeFromIndex(string, startIdx - 1));

    NSString *lastWord = nil;
    if(startIdx != NSNotFound){

        range = NSMakeRange(startRange->location, [string length] - startRange->location);
        
        do {
            range = [string rangeOfCharacterFromSet:[NSURL illegalURLCharacterSet] options:0 range:range];

            // if the entire string is valid...
            if(range.location == NSNotFound){
                endIdx = [string length];
                break;
            } else {
                endIdx = range.location;
            }
            
            // move the search range interval towards the end of the string
            range = NSMakeRange(range.location + 1, [string length] - range.location - 1);
            
        } while (endIdx != NSNotFound && hasValidPercentEscapeFromIndex(string, endIdx));
        
        if(endIdx != NSNotFound && startIdx != NSNotFound && endIdx > startIdx){
            range = NSMakeRange(startIdx, endIdx - startIdx);
            lastWord = [string substringWithRange:range]; 
            *startRange = range;
        }
    }
    return lastWord;
}

- (void)fixAttributesForURLs;
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
            urlString = [self URLStringFromRange:&range inString:string];
            url = urlString ? [[NSURL alloc] initWithString:urlString] : nil;
            if([url scheme]) [textStorage addAttribute:NSLinkAttributeName value:url range:range];
        }
        
    } while (range.length);
}

@end

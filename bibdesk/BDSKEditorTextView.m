//
//  BDSKEditorTextView.m
//  Bibdesk
//
//  Created by Adam Maxwell on 02/28/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "BDSKEditorTextView.h"
#import "NSURL_BDSKExtensions.h"

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

static inline BOOL checkForPercentEscapeFromIndex(NSString *string, unsigned startIndex)
{
    NSCParameterAssert([string length] > startIndex);
    // require % and two additional chars
    if([string characterAtIndex:startIndex] != '%' || [string length] <= (startIndex + 2))
        return NO;
    
    unichar ch1 = [string characterAtIndex:(startIndex + 1)];
    unichar ch2 = [string characterAtIndex:(startIndex + 2)];
    return ((ch1 <= '9' && ch1 >= '0') && (ch2 <= '9' && ch2 >= '0')) ? YES : NO;
}

// searches backwards; forwards search uses edited range as word boundary
- (NSString *)URLStringFromRange:(NSRange *)startRange inString:(NSString *)string
{
    NSRange range;
    NSRange searchRange = NSMakeRange(0, startRange->location);
    
    do {
        range = [string rangeOfCharacterFromSet:[NSURL illegalURLCharacterSet] options:NSBackwardsSearch range:searchRange];
        
        // if we didn't find one, reset the range to the last useful value and break
        if(range.location == NSNotFound){
            range.location = searchRange.location;
            break;
        }
           
        // move the search range interval towards the beginning of the string
        searchRange.length = range.location;
           
    } while (checkForPercentEscapeFromIndex(string, range.location));

    NSString *lastWord = nil;
    if(range.length){
        
        // skip the illegal character
        range.location += 1;

        NSRange endRange;
        searchRange = NSMakeRange(range.location, [string length] - range.location);
        
        do {
            endRange = [string rangeOfCharacterFromSet:[NSURL illegalURLCharacterSet] options:0 range:searchRange];
            
            // if the entire string is valid...
            if(endRange.location == NSNotFound){
                endRange = NSMakeRange([string length], 0);
                break;
            }
            
            // move the search range interval towards the end of the string
            searchRange = NSMakeRange(searchRange.location, endRange.location - searchRange.location);
            
        } while (checkForPercentEscapeFromIndex(string, endRange.location));
        
        range = NSMakeRange(range.location, endRange.location - range.location);
        if(range.length) lastWord = [string substringWithRange:range];    
        *startRange = range;
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
            urlString = [self URLStringFromRange:&range inString:string];
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

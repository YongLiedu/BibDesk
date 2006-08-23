//
//  BDSKErrorEditor.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/21/06.
/*
 This software is Copyright (c) 2005,2006
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

#import "BDSKErrorEditor.h"
#import <OmniBase/assertions.h>
#import <OmniAppKit/OAFindControllerTargetProtocol.h>
#import "BDSKErrorObjectController.h"
#import "NSTextView_BDSKExtensions.h"
#import "NSString_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BibDocument.h"


@implementation BDSKErrorEditor

+ (void)initialize;
{
    OBINITIALIZE;
    [self setKeys:[NSArray arrayWithObjects:@"document", @"fileName", @"uniqueNumber", nil] triggerChangeNotificationsForDependentKey:@"displayName"];
}

- (id)initWithFileName:(NSString *)aFileName andDocument:(id)aDocument;
{
    if(self = [super init]){
        errorController = nil;
        document = [aDocument retain];
        fileName = [aFileName retain];
        uniqueNumber = 0;
        enableSyntaxHighlighting = YES;
        isPasteDrag = NO;
    }
    return self;
}

- (id)initWithFileName:(NSString *)aFileName;
{
    if(self = [self initWithFileName:aFileName andDocument:nil]){
        isPasteDrag = YES;
    }
    return self;
}

- (void)dealloc;
{
    [document release];
    [fileName release];
    [super dealloc];
}

- (NSString *)windowNibName;
{
    return @"BDSKErrorEditWindow";
}

- (void)awakeFromNib;
{
    NSString *prefix = (isPasteDrag) ? NSLocalizedString(@"Edit Paste/Drag", @"Edit Paste/Drag") : NSLocalizedString(@"Edit Source", @"Edit Source");
    
    [[self window] setRepresentedFilename:fileName];
	[[self window] setTitle:[NSString stringWithFormat:@"%@: %@", prefix, [self displayName]]];
    
    // set the frame from prefs first, or setFrameAutosaveName: will overwrite the prefs with the nib values if it returns NO
    [[self window] setFrameUsingName:@"Edit Source Window"];
    // we should only cascade windows if we have multiple documents open; bug #1299305
    // the default cascading does not reset the next location when all windows have closed, so we do cascading ourselves
    static NSPoint nextWindowLocation = {0.0, 0.0};
    [self setShouldCascadeWindows:NO];
    if ([[self window] setFrameAutosaveName:@"Edit Source Window"]) {
        NSRect windowFrame = [[self window] frame];
        nextWindowLocation = NSMakePoint(NSMinX(windowFrame), NSMaxY(windowFrame));
    }
    nextWindowLocation = [[self window] cascadeTopLeftFromPoint:nextWindowLocation];
    
    if(isPasteDrag)
        [reopenButton setEnabled:NO];
    
    [[textView textStorage] setDelegate:self];
    [syntaxHighlightCheckbox setState:NSOnState];
    
    [self loadFile:self];
    
    isEditing = YES;
}

- (void)windowWillClose:(NSNotification *)notification{
    isEditing = NO;
    if (document == nil)
        [errorController removeEditor:self];
}

#pragma mark Accessors

- (BDSKErrorObjectController *)errorController;
{
    return errorController;
}

- (void)setErrorController:(BDSKErrorObjectController *)newController;
{
    if(errorController != newController){
        errorController = newController;
    }
}

- (NSString *)fileName;
{
    return fileName;
}

- (int)uniqueNumber;
{
    return uniqueNumber;
}

- (void)setUniqueNumber:(int)newNumber;
{
    uniqueNumber = newNumber;
}

- (NSString *)displayName;
{
    NSString *displayName = [fileName lastPathComponent];
    if(displayName == nil)
        displayName = @"?";
    return (uniqueNumber == 0) ? displayName : [NSString stringWithFormat:@"%@ (%d)", displayName, uniqueNumber];
}

- (BibDocument *)sourceDocument;
{
    return document;
}

- (void)setSourceDocument:(BibDocument *)newDocument;
{
    if (document != newDocument) {
        [document release];
        document = [newDocument retain];
    }
}

- (BOOL)isEditing;
{
    return isEditing;
}

- (BOOL)isPasteDrag;
{
    return isPasteDrag;
}

#pragma mark Editing

- (id <OAFindControllerTarget>)omniFindControllerTarget { return textView; }

- (IBAction)loadFile:(id)sender{
    NSFileManager *dfm = [NSFileManager defaultManager];
    if (!fileName) return;
    
    // let's see if the document has an encoding (hopefully the user guessed correctly); if not, fall back to the default C string encoding
    NSStringEncoding encoding = (document != nil ? [document documentStringEncoding] : [NSString defaultCStringEncoding]);
        
    if ([dfm fileExistsAtPath:fileName]) {
        NSString *fileStr = [[NSString alloc] initWithContentsOfFile:fileName encoding:encoding guessEncoding:YES];;
        if(!fileStr)
            fileStr = [[NSString alloc] initWithString:NSLocalizedString(@"Unable to determine the correct character encoding.", @"")];
        [textView setString:fileStr];
        [fileStr release];
    }
}

- (IBAction)reopenDocument:(id)sender{
    NSString *expandedFileName = [[self fileName] stringByExpandingTildeInPath];
    
    expandedFileName = [[NSFileManager defaultManager] uniqueFilePath:expandedFileName createDirectory:NO];
    
    // write this out with the user's default encoding, so the openDocumentWithContentsOfFile is more likely to succeed
    NSData *fileData = [[textView string] dataUsingEncoding:[[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKDefaultStringEncodingKey] allowLossyConversion:NO];
    [fileData writeToFile:expandedFileName atomically:YES];
    
    [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile:expandedFileName display:YES];
}

- (void)gotoLine:(int)lineNumber{
    // we're not using getLineStart:end:contentsEnd:forRange: because btparse only recognized \n as a newline
    static NSCharacterSet *newlineCharacterSet = nil;
    
    if(newlineCharacterSet == nil)
        newlineCharacterSet = [[NSCharacterSet characterSetWithRange:NSMakeRange('\n', 1)] retain];
    
    int i = 0;
    NSString *string = [textView string];
    unsigned start = 0;
    unsigned end = 0;
    unsigned length = [string length];
    NSRange range;
    
    while (++i <= lineNumber) {
        start = end;
        range = [string rangeOfCharacterFromSet:newlineCharacterSet options:NSLiteralSearch range:NSMakeRange(start, length - start)];
        if (range.location == NSNotFound) {
            end = length;
            if (i < lineNumber)
                start = length;
            break;
        }
        end = NSMaxRange(range);
    }
    range.location = start;
    range.length = (end - start);
    [textView setSelectedRange:range];
    [textView scrollRangeToVisible:range];
}

- (IBAction)changeSyntaxHighlighting:(id)sender;
{
    enableSyntaxHighlighting = !enableSyntaxHighlighting;
        
    NSTextStorage *textStorage = [textView textStorage];
    if(enableSyntaxHighlighting == NO)
        [textStorage addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:NSMakeRange(0, [textStorage length])];
    [textStorage edited:NSTextStorageEditedAttributes range:NSMakeRange(0, [textStorage length]) changeInLength:0];
}

#pragma mark Syntax highlighting

static inline Boolean isLeftBrace(UniChar ch) { return ch == '{'; }
static inline Boolean isRightBrace(UniChar ch) { return ch == '}'; }
static inline Boolean isAt(UniChar ch) { return ch == '@'; }
static inline Boolean isBackslash(UniChar ch) { return ch == '\\'; }

// extend the edited range of the textview to include the previous and next newline; including the previous/next delimiter is less reliable
static inline NSRange invalidatedRange(NSTextStorage *textStorage, NSRange proposedRange){
    
    static NSCharacterSet *delimSet = nil;
    if(delimSet == nil)
        delimSet = [[NSCharacterSet characterSetWithCharactersInString:@"@{}"] retain];
    
    static NSMutableCharacterSet *newlineSet = nil;
    if(newlineSet == nil){
        newlineSet = (NSMutableCharacterSet *)CFCharacterSetCreateMutableCopy(CFAllocatorGetDefault(), CFCharacterSetGetPredefined(kCFCharacterSetWhitespace));
        CFCharacterSetInvert((CFMutableCharacterSetRef)newlineSet); // no whitespace in this one, but it also has all letters...
        CFCharacterSetIntersect((CFMutableCharacterSetRef)newlineSet, CFCharacterSetGetPredefined(kCFCharacterSetWhitespaceAndNewline));
    }
    
    NSString *string = [textStorage string];
    NSColor *quotedColor = [NSColor brownColor];
    
    unsigned start = proposedRange.location;
    unsigned end = NSMaxRange(proposedRange);
    
    // quoted text can have multiple lines
    do{
        start = [string rangeOfCharacterFromSet:newlineSet options:NSBackwardsSearch|NSLiteralSearch range:NSMakeRange(0, start)].location;
        if(start == NSNotFound)
            start = 0;
    } while (start > 0 && [textStorage attribute:NSForegroundColorAttributeName atIndex:start - 1 effectiveRange:NULL] == quotedColor);
    
    end = NSMaxRange([string rangeOfCharacterFromSet:newlineSet options:NSLiteralSearch range:NSMakeRange(end, [string length] - end)]);
    if(end == NSNotFound)
        end = [string length];
    
    return NSMakeRange(start, end - start);
}
    
#define SetColor(color, start, length) [textStorage addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(editedRange.location + start, length)];


- (void)textStorageDidProcessEditing:(NSNotification *)notification{
    
    if(enableSyntaxHighlighting == NO)
        return;
    
    NSTextStorage *textStorage = [notification object];    
    CFStringRef string = (CFStringRef)[textStorage string];
    CFIndex length = CFStringGetLength(string);

    NSRange editedRange = [textStorage editedRange];
    
    // see what range we should actually invalidate; if we're not adding any special characters, the default edited range is probably fine
    editedRange = invalidatedRange(textStorage, editedRange);
    
    CFIndex cnt = editedRange.location;
    
    CFStringInlineBuffer inlineBuffer;
    CFStringInitInlineBuffer(string, &inlineBuffer, CFRangeMake(cnt, editedRange.length));
    
    //[textStorage addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:editedRange];
    SetColor([NSColor blackColor], 0, editedRange.length)
    
    // inline buffer only covers the edited range, starting from 0; adjust length to length of buffer
    length = editedRange.length;
    UniChar ch;
    CFIndex lbmark, atmark;
    
    NSColor *braceColor = [NSColor blueColor];
    NSColor *typeColor = [NSColor purpleColor];
    NSColor *quotedColor = [NSColor brownColor];
    
    CFIndex braceDepth = 0;
     
    // This is fairly crude; I don't think it's worthwhile to implement a full BibTeX parser here, since we need this to be fast (and it won't be used that often).
    // remember that cnt and length determine the index and length of the inline buffer, not the textStorage
    for(cnt = 0; cnt < length; cnt++){
        ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, cnt);
        if(isAt(ch) && (cnt == 0 || BDIsNewlineCharacter(CFStringGetCharacterAtIndex(string, cnt - 1)))){
            atmark = cnt;
            while(++cnt < length){
                ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, cnt);
                if(isLeftBrace(ch)){
                    SetColor(braceColor, cnt, 1);
                    break;
                }
            }
            SetColor(typeColor, atmark, cnt - atmark);
            // sneaky hack: don't rewind here, since cite keys don't have a closing brace (of course)
        }else if(isLeftBrace(ch)){
            braceDepth = 1;
            SetColor(braceColor, cnt, 1)
            lbmark = cnt + 1;
            while(++cnt < length){
                if(isBackslash(ch)){ // ignore escaped braces
                    ch = 0;
                    continue;
                }
                ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, cnt);
                if(isRightBrace(ch)){
                    braceDepth--;
                    if(braceDepth == 0){
                        SetColor(braceColor, cnt, 1);
                        break;
                    }
                } else if(isLeftBrace(ch)){
                    braceDepth++;
                }
            }
            SetColor(quotedColor, lbmark, cnt - lbmark);
        }else if(isRightBrace(ch)){
            SetColor(braceColor, cnt, 1);
        }
    }

}

@end

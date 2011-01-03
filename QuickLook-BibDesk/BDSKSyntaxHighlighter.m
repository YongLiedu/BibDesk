//
//  BDSKSyntaxHighlighter.m
//  QuickLookBibDesk
//
//  Created by Adam Maxwell on 01/16/07.
/*
 This software is Copyright (c) 2007-2011
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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

#import "BDSKSyntaxHighlighter.h"

@implementation BDSKSyntaxHighlighter

+ (NSData *)HTMLDataWithBibTeXString:(NSString *)aString;
{
    NSAttributedString *attrString = [self highlightedStringWithBibTeXString:aString];
    NSDictionary *docAttrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInteger:NSUTF8StringEncoding], NSCharacterEncodingDocumentAttribute, NSHTMLTextDocumentType, NSDocumentTypeDocumentAttribute, [NSColor whiteColor], NSBackgroundColorDocumentAttribute, nil];
    return [attrString dataFromRange:NSMakeRange(0, [attrString length]) documentAttributes:docAttrs error:NULL];
}

// RTF wraps to the window and is simpler to return
+ (NSData *)RTFDataWithBibTeXString:(NSString *)aString;
{
    NSAttributedString *attrString = [self highlightedStringWithBibTeXString:aString];
    return [attrString RTFFromRange:NSMakeRange(0, [attrString length]) documentAttributes:nil];
}

static inline Boolean isLeftBrace(UniChar ch) { return ch == '{'; }
static inline Boolean isRightBrace(UniChar ch) { return ch == '}'; }
static inline Boolean isDoubleQuote(UniChar ch) { return ch == '"'; }
static inline Boolean isAt(UniChar ch) { return ch == '@'; }
static inline Boolean isPercent(UniChar ch) { return ch == '%'; }
static inline Boolean isHash(UniChar ch) { return ch == '#'; }
static inline Boolean isBackslash(UniChar ch) { return ch == '\\'; }
static inline Boolean isCommentOrQuotedColor(NSColor *color) { return [color isEqual:[NSColor brownColor]] || [color isEqual:[NSColor grayColor]]; }
   
#define SetColor(color, start, length) [attributedString addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(start, length)];


+ (NSAttributedString *)highlightedStringWithBibTeXString:(NSString *)aString;
{
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:aString];

    NSCharacterSet *newlineSet = [NSCharacterSet newlineCharacterSet];
    
    CFStringRef string = (CFStringRef)[attributedString string];
    CFIndex length = CFStringGetLength(string);
    SetColor([NSColor orangeColor], 0, length);

    CFIndex cnt = 0;
    CFStringInlineBuffer inlineBuffer;
    CFStringInitInlineBuffer(string, &inlineBuffer, CFRangeMake(cnt, length));
        
    UniChar ch;
    CFIndex lbmark, atmark, percmark;
    
    NSColor *braceColor = [NSColor blueColor];
    NSColor *typeColor = [NSColor purpleColor];
    NSColor *quotedColor = [NSColor brownColor];
    NSColor *commentColor = [NSColor grayColor];
    NSColor *hashColor = [NSColor magentaColor];
    CFStringRef commentString = CFSTR("comment");
    
    CFIndex braceDepth = 0;
     
    // This is fairly crude; I don't think it's worthwhile to implement a full BibTeX parser here, since we need this to be fast (and it won't be used that often).
    // remember that cnt and length determine the index and length of the inline buffer, not the attributedString
    for(cnt = 0; cnt < length; cnt++){
        ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, cnt);
        if(isAt(ch)){
            atmark = cnt;
            while(++cnt < length){
                ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, cnt);
                if(isLeftBrace(ch)){
                    SetColor(braceColor, cnt, 1);
                    break;
                }
            }
            SetColor(typeColor, atmark, cnt - atmark);
            // in fact whitespace is allowed at the end of "comment", but harder to check
            if(cnt - atmark == 8 && CFStringCompareWithOptions(string, commentString, CFRangeMake(atmark + 1, 7), kCFCompareCaseInsensitive) == kCFCompareEqualTo){
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
                SetColor(commentColor, lbmark, cnt - lbmark);
            }
            // sneaky hack: don't rewind here, since cite keys don't have a closing brace (of course)
        }else if(isPercent(ch)){
            percmark = cnt;
            while(++cnt < length){
                ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, cnt);
                if([newlineSet characterIsMember:ch]){
                    break;
                }
            }
            SetColor(commentColor, percmark, cnt - percmark);
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
        }else if(isDoubleQuote(ch)){
            braceDepth = 1;
            SetColor(braceColor, cnt, 1)
            lbmark = cnt + 1;
            while(++cnt < length){
                if(isBackslash(ch)){ // ignore escaped braces
                    ch = 0;
                    continue;
                }
                ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, cnt);
                if(isDoubleQuote(ch)){
                    braceDepth--;
                    SetColor(braceColor, cnt, 1);
                    break;
                }
            }
            SetColor(quotedColor, lbmark, cnt - lbmark);
        }else if(isRightBrace(ch)){
            SetColor(braceColor, cnt, 1);
        }else if(isHash(ch)){
            SetColor(hashColor, cnt, 1);
        }
    }
    
    [attributedString addAttribute:NSFontAttributeName value:[NSFont userFixedPitchFontOfSize:10.0] range:NSMakeRange(0, [attributedString length])];
    return [attributedString autorelease];
}

@end
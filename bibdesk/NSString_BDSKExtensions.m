//  NSString_BDSKExtensions.m

//  Created by Michael McCracken on Sun Jul 21 2002.
/*
 This software is Copyright (c) 2002-2010
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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
 
/*
 Some methods in this category are copied from OmniFoundation 
 and are subject to the following licence:
 
 Omni Source License 2007

 OPEN PERMISSION TO USE AND REPRODUCE OMNI SOURCE CODE SOFTWARE

 Omni Source Code software is available from The Omni Group on their 
 web site at http://www.omnigroup.com/www.omnigroup.com. 

 Permission is hereby granted, free of charge, to any person obtaining 
 a copy of this software and associated documentation files (the 
 "Software"), to deal in the Software without restriction, including 
 without limitation the rights to use, copy, modify, merge, publish, 
 distribute, sublicense, and/or sell copies of the Software, and to 
 permit persons to whom the Software is furnished to do so, subject to 
 the following conditions:

 Any original copyright notices and this permission notice shall be 
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY 
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "NSString_BDSKExtensions.h"
#import <Cocoa/Cocoa.h>
#import "NSCharacterSet_BDSKExtensions.h"
#import "CFString_BDSKExtensions.h"
#import <AGRegex/AGRegex.h>
#import "BDSKStringConstants.h"
#import "CFString_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSScanner_BDSKExtensions.h"
#import "html2tex.h"
#import "NSDictionary_BDSKExtensions.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKStringEncodingManager.h"
#import "BDSKTypeManager.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSAttributedString_BDSKExtensions.h"


@implementation NSString (BDSKExtensions)

// This method is copied from NSString-OFStringExtensions.m
+ (BOOL)isEmptyString:(NSString *)string {
    return string == nil || [string isEqualToString:@""];
}

// This method is copied from NSString-OFStringExtensions.m
+ (NSString *)horizontalEllipsisString; // '...'
{
    static NSString *string = nil;
    if (string == nil)
        string = [[self stringWithFormat:@"%C", 0x2026] retain];
    return string;
}

// This method is copied from NSString-OFStringExtensions.m
+ (NSString *)emdashString; // '---'
{
    static NSString *string = nil;
    if (string == nil)
        string = [[self stringWithFormat:@"%C", 0x2014] retain];
    return string;
}

// This method is copied from NSString-OFStringExtensions.m
+ (NSString *)endashString; // '--'
{
    static NSString *string = nil;
    if (string == nil)
        string = [[self stringWithFormat:@"%C", 0x2013] retain];
    return string;
}

// This method is copied from NSString-OFStringExtensions.m
+ (NSString *)commandKeyIndicatorString;
{
    static NSString *string = nil;
    if (string == nil)
        string = [[self stringWithFormat:@"%C", 0x2318] retain];
    return string;
}

// This method is copied from NSString-OFStringExtensions.m
+ (NSString *)controlKeyIndicatorString;
{
    static NSString *string = nil;
    if (string == nil)
        string = [[self stringWithFormat:@"%C", 0x2303] retain];
    return string;
}

// This method is copied from NSString-OFStringExtensions.m
+ (NSString *)alternateKeyIndicatorString;
{
    static NSString *string = nil;
    if (string == nil)
        string = [[self stringWithFormat:@"%C", 0x2325] retain];
    return string;
}

// This method is copied from NSString-OFStringExtensions.m
+ (NSString *)shiftKeyIndicatorString;
{
    static NSString *string = nil;
    if (string == nil)
        string = [[self stringWithFormat:@"%C", 0x21E7] retain];
    return string;
}

// This method is copied from NSString-OFStringExtensions.m
+ (NSString *)hexStringForCharacter:(unichar)ch{
    NSMutableString *string = [NSMutableString stringWithCapacity:4];
    [string appendFormat:@"%X", ch];
    while([string length] < 4)
        [string insertString:@"0" atIndex:0];
    [string insertString:@"0x" atIndex:0];
    return string;
}

static NSInteger MAX_RATING = 5;
+ (NSString *)ratingStringWithInteger:(NSInteger)rating;
{
    NSParameterAssert(rating >= 0 && rating <= MAX_RATING);
    static NSString **ratingStrings = NULL;
    if(ratingStrings == NULL){
        ratingStrings = NSZoneMalloc(NULL, (MAX_RATING + 1) * sizeof(NSString *));
        NSInteger i = 0;
        NSMutableString *ratingString = [NSMutableString string];
        do {
            ratingStrings[rating] = [ratingString copy];
            [ratingString appendFormat:@"%C", (0x278A + i)];
        } while(i++ < MAX_RATING);
    }
    if (rating >= 0 && rating <= MAX_RATING)
        return ratingStrings[rating];
    return nil;
}

+ (NSString *)stringWithBool:(BOOL)boolValue {
	return boolValue ? @"1" : @"0";
}

+ (NSString *)stringWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)encoding guessEncoding:(BOOL)try;
{
    return [[[self alloc] initWithContentsOfFile:path encoding:encoding guessEncoding:try] autorelease];
}

+ (NSString *)stringWithFileSystemRepresentation:(const char *)cstring;
{
    NSParameterAssert(cstring != NULL);
    return [(id)CFStringCreateWithFileSystemRepresentation(CFAllocatorGetDefault(), cstring) autorelease];
}

+ (NSString *)stringWithTriStateValue:(NSCellStateValue)triStateValue {
    switch (triStateValue) {
        case NSOffState:
            return @"0";
        case NSOnState:
            return @"1";
        case NSMixedState:
        default:
            return @"-";
    }
}

+ (NSString *)unicodeNameOfCharacter:(unichar)ch;
{
    CFMutableStringRef charString = CFStringCreateMutable(CFAllocatorGetDefault(), 0);
    CFStringAppendCharacters(charString, &ch, 1);
    
    // ignore failures for now
    CFStringTransform(charString, NULL, kCFStringTransformToUnicodeName, FALSE);
    
    return [(id)charString autorelease];
} 

+ (NSString *)IANACharSetNameForEncoding:(NSStringEncoding)enc;
{
    CFStringEncoding cfEnc = CFStringConvertNSStringEncodingToEncoding(enc);
    NSString *encName = nil;
    if (kCFStringEncodingInvalidId != cfEnc)
        encName = (NSString *)CFStringConvertEncodingToIANACharSetName(cfEnc);
    return encName;
}

+ (NSStringEncoding)encodingForIANACharSetName:(NSString *)name
{
    NSStringEncoding nsEnc = 0;
    CFStringEncoding cfEnc = kCFStringEncodingInvalidId;
    
    if (name)
        cfEnc = CFStringConvertIANACharSetNameToEncoding((CFStringRef)name);

    if (kCFStringEncodingInvalidId != cfEnc)
        nsEnc = CFStringConvertEncodingToNSStringEncoding(cfEnc);
    
    return nsEnc;
}

static inline BOOL dataHasUnicodeByteOrderMark(NSData *data)
{
    NSUInteger len = [data length];
    size_t size = sizeof(UniChar);
    BOOL rv = NO;
    if(len >= size){
        const UniChar bigEndianBOM = 0xfeff;
        const UniChar littleEndianBOM = 0xfffe;
        
        UniChar possibleBOM = 0;
        [data getBytes:&possibleBOM length:size];
        rv = (possibleBOM == bigEndianBOM || possibleBOM == littleEndianBOM);
    }
    return rv;
}

- (NSString *)initWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)encoding guessEncoding:(BOOL)try;
{
    NSData *data = [[NSData allocWithZone:[self zone]] initWithContentsOfFile:path options:NSMappedRead error:NULL];
    
    NSString *string = nil;
    Class stringClass = [self isKindOfClass:[NSMutableString class]] ? [NSMutableString class] : [NSString class];
    
    // if we're guessing, try the reliable encodings first
    if(try && dataHasUnicodeByteOrderMark(data) && encoding != NSUnicodeStringEncoding)
        string = [[stringClass allocWithZone:[self zone]] initWithData:data encoding:NSUnicodeStringEncoding];
    if(try && nil == string && encoding != NSUTF8StringEncoding)
        string = [[stringClass allocWithZone:[self zone]] initWithData:data encoding:NSUTF8StringEncoding];
    
    // read com.apple.TextEncoding on Leopard, or when reading a Tiger file saved on Leopard
    if(try && nil == string) {
        // don't clobber the encoding parameter in case this fails...
        NSStringEncoding xattrEncoding = [[NSFileManager defaultManager] appleStringEncodingAtPath:path error:NULL];
        if (xattrEncoding > 0)
            string = [[stringClass allocWithZone:[self zone]] initWithData:data encoding:xattrEncoding];
    }
    
    // try the encoding passed as a parameter, if non-zero (zero encoding is never valid)
    if(nil == string && encoding > 0)
        string = [[stringClass allocWithZone:[self zone]] initWithData:data encoding:encoding];
    
    // now we just try a few wild guesses
    if(nil == string && try && encoding != [NSString defaultCStringEncoding])
        string = [[stringClass allocWithZone:[self zone]] initWithData:data encoding:[NSString defaultCStringEncoding]];
    if(nil == string && try && encoding != [BDSKStringEncodingManager defaultEncoding])
        string = [[stringClass allocWithZone:[self zone]] initWithData:data encoding:[BDSKStringEncodingManager defaultEncoding]];
    // final fallback is Mac Roman (gapless)
    if(nil == string && try && encoding != NSMacOSRomanStringEncoding)
        string = [[stringClass allocWithZone:[self zone]] initWithData:data encoding:NSMacOSRomanStringEncoding];
    
    [data release];
    [self release];
    return string;
}

#pragma mark TeX cleaning

- (NSString *)stringByConvertingDoubleHyphenToEndash{
    NSString *string = self;
    NSString *doubleHyphen = @"--";
    NSRange range = [self rangeOfString:doubleHyphen];
    if (range.location != NSNotFound) {
        NSMutableString *mutString = [[self mutableCopy] autorelease];
        do {
            [mutString replaceCharactersInRange:range withString:[NSString endashString]];
            range = [mutString rangeOfString:doubleHyphen];
        } while (range.location != NSNotFound);
        string = mutString;
    }
    return string;
}

- (NSString *)stringByConvertingTripleHyphenToEmdash{
    NSString *string = self;
    NSString *tripleHyphen = @"---";
    NSRange range = [self rangeOfString:tripleHyphen];
    if (range.location != NSNotFound) {
        NSMutableString *mutString = [[self mutableCopy] autorelease];
        do {
            [mutString replaceCharactersInRange:range withString:[NSString emdashString]];
            range = [mutString rangeOfString:tripleHyphen];
        } while (range.location != NSNotFound);
        string = mutString;
    }
    return string;
}

- (NSString *)stringByConvertingHyphensToDashes{
    return [[self stringByConvertingTripleHyphenToEmdash] stringByConvertingDoubleHyphenToEndash];
}

- (NSString *)stringByRemovingCurlyBraces{
    return [self stringByReplacingCharactersInSet:[NSCharacterSet curlyBraceCharacterSet] withString:@""];
}

- (NSString *)stringByRemovingTeX{
    NSRange searchRange = NSMakeRange(0, [self length]);
    NSRange foundRange = [self rangeOfTeXCommandInRange:searchRange];
    
    if (foundRange.length == 0 && [self rangeOfCharacterFromSet:[NSCharacterSet curlyBraceCharacterSet]].length == 0)
        return self;
    
    NSMutableString *mutableString = [[self mutableCopy] autorelease];
    while(foundRange.length){
        [mutableString replaceCharactersInRange:foundRange withString:@""];
        searchRange.length = NSMaxRange(searchRange) - NSMaxRange(foundRange);
        searchRange.location = foundRange.location;
        foundRange = [mutableString rangeOfTeXCommandInRange:searchRange];
    }
    [mutableString deleteCharactersInCharacterSet:[NSCharacterSet curlyBraceCharacterSet]];
    return mutableString;
}

#pragma mark TeX parsing

- (NSString *)entryType;
{
    // we could save a little memory by using a case-insensitive dictionary, but this is faster (and these strings are small)
    static NSMutableDictionary *entryDictionary = nil;
    if (nil == entryDictionary)
        entryDictionary = [[NSMutableDictionary alloc] initWithCapacity:100];
    
    NSString *entryType = [entryDictionary objectForKey:self];
    if (nil == entryType) {
        entryType = [self lowercaseString];
        [entryDictionary setObject:entryType forKey:self];
    }
    return entryType;
}

- (NSString *)fieldName;
{
    // we could save a little memory by using a case-insensitive dictionary, but this is faster (and these strings are small)
    static NSMutableDictionary *fieldDictionary = nil;
    if (nil == fieldDictionary)
        fieldDictionary = [[NSMutableDictionary alloc] initWithCapacity:100];
    
    NSString *fieldName = [fieldDictionary objectForKey:self];
    if (nil == fieldName) {
        fieldName = [self capitalizedString];
        [fieldDictionary setObject:fieldName forKey:self];
    }
    return fieldName;
}

- (NSString *)localizedFieldName;
{
    // this is used for display, for now we don't do anything
    return self;
}

- (NSUInteger)indexOfRightBraceMatchingLeftBraceAtIndex:(NSUInteger)startLoc
{
    return [self indexOfRightBraceMatchingLeftBraceInRange:NSMakeRange(startLoc, [self length] - startLoc)];
}

- (NSUInteger)indexOfRightBraceMatchingLeftBraceInRange:(NSRange)range
{
    
    CFStringInlineBuffer inlineBuffer;
    CFIndex length = CFStringGetLength((CFStringRef)self);
    CFIndex startLoc = range.location;
    CFIndex endLoc = NSMaxRange(range);
    CFIndex cnt;
    BOOL matchFound = NO;
    
    CFStringInitInlineBuffer((CFStringRef)self, &inlineBuffer, CFRangeMake(0, length));
    UniChar ch;
    NSInteger nesting = 0;
    
    if(CFStringGetCharacterFromInlineBuffer(&inlineBuffer, startLoc) != '{')
        [NSException raise:NSInternalInconsistencyException format:@"character at index %ld is not a brace", (long)startLoc];
    
    // we don't consider escaped braces yet
    for(cnt = startLoc; cnt < endLoc; cnt++){
        ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, cnt);
        if(ch == '\\')
            cnt++;
        else if(ch == '{')
            nesting++;
        else if(ch == '}')
            nesting--;
        if(nesting == 0){
            //NSLog(@"match found at index %ld", (long)cnt);
            matchFound = YES;
            break;
        }
    }
    
    return matchFound ? (NSUInteger)cnt : NSNotFound;    
}

- (BOOL)isStringTeXQuotingBalancedWithBraces:(BOOL)braces connected:(BOOL)connected{
	return [self isStringTeXQuotingBalancedWithBraces:braces connected:connected range:NSMakeRange(0,[self length])];
}

- (BOOL)isStringTeXQuotingBalancedWithBraces:(BOOL)braces connected:(BOOL)connected range:(NSRange)range{
	NSInteger nesting = 0;
	NSCharacterSet *delimCharSet;
	unichar rightDelim;
	
	if (braces) {
		delimCharSet = [NSCharacterSet curlyBraceCharacterSet];
		rightDelim = '}';
	} else {
		delimCharSet = [NSCharacterSet characterSetWithCharactersInString:@"\""];
		rightDelim = '"';
	}
	
	NSRange delimRange = [self rangeOfCharacterFromSet:delimCharSet options:NSLiteralSearch range:range];
	NSInteger delimLoc = delimRange.location;
	
	while (delimLoc != NSNotFound) {
		if (delimLoc == 0 || braces || [self characterAtIndex:delimLoc - 1] != '\\') {
			// we found an unescaped delimiter
			if (connected && nesting == 0) // connected quotes cannot have a nesting of 0 in the middle
				return NO;
			if ([self characterAtIndex:delimLoc] == rightDelim) {
				--nesting;
			} else {
				++nesting;
			}
			if (nesting < 0) // we should never get a negative nesting
				return NO;
		}
		// set the range to the part of the range after the last found brace
		range = NSMakeRange(delimLoc + 1, range.length - delimLoc + range.location - 1);
		// search for the next brace
		delimRange = [self rangeOfCharacterFromSet:delimCharSet options:NSLiteralSearch range:range];
		delimLoc = delimRange.location;
	}
	
	return (nesting == 0);
}

// transforms a bibtex string to have temp cite keys, using the method in openWithPhoneyKeys.
- (NSString *)stringWithPhoneyCiteKeys:(NSString *)tmpKey{
		// ^(@[[:alpha:]]+{),?$ will grab either "@type{,eol" or "@type{eol", which is what we get
		// from Bookends and EndNote, respectively.
		AGRegex *theRegex = [AGRegex regexWithPattern:@"^([ \\t]*@[[:alpha:]]+[ \\t]*{)[ \\t]*,?$" options:AGRegexCaseInsensitive];

		// should assert that the noKeysString matches theRegex
		//NSAssert([theRegex findInString:self] != nil, @"stringWithPhoneyCiteKeys called on non-matching string");

		// replace with "@type{FixMe,eol" (add the comma in, since we remove it if present)
		NSCharacterSet *newlineCharacterSet = [NSCharacterSet newlineCharacterSet];
		
		NSScanner *scanner = [NSScanner scannerWithString:self];
		NSMutableString *mutableFileString = [NSMutableString stringWithCapacity:[self length]];
		NSString *tmp = nil;
		NSInteger scanLocation = 0;
        NSString *replaceRegex = [NSString stringWithFormat:@"$1%@,", tmpKey];
        
        [scanner setCharactersToBeSkipped:nil];
		
		// we scan up to an (newline@) sequence, then to a newline; we then replace only in that line using theRegex, which is much more efficient than using AGRegex to find/replace in the entire string
		do {
			// append the previous part to the mutable string
            if ([scanner scanUpToString:@"@" intoString:&tmp])
                [mutableFileString appendString:tmp];
			
			scanLocation = [scanner scanLocation];
			if(scanLocation == 0 || [newlineCharacterSet characterIsMember:[self characterAtIndex:scanLocation - 1]]){
				// if we read something between the @ and newline, see if we can do the regex find/replace
				if([scanner scanUpToCharactersFromSet:newlineCharacterSet intoString:&tmp]){
					// this should be a noop if the pattern isn't matched
					[mutableFileString appendString:[theRegex replaceWithString:replaceRegex inString:tmp]]; // guaranteed non-nil result from AGRegex
				}
			} else
				[scanner scanCharacter:NULL];
                        
		} while([scanner isAtEnd] == NO);
		
		NSString *toReturn = [NSString stringWithString:mutableFileString];
		
		return toReturn;
}

- (NSRange)rangeOfTeXCommandInRange:(NSRange)searchRange;
{
    static CFCharacterSetRef nonLetterCharacterSet = NULL;
    
    if (NULL == nonLetterCharacterSet) {
        CFMutableCharacterSetRef letterCFCharacterSet = CFCharacterSetCreateMutableCopy(CFAllocatorGetDefault(), CFCharacterSetGetPredefined(kCFCharacterSetLetter));
        CFCharacterSetInvert(letterCFCharacterSet);
        nonLetterCharacterSet = CFCharacterSetCreateCopy(CFAllocatorGetDefault(), letterCFCharacterSet);
        CFRelease(letterCFCharacterSet);
    }
    
    CFRange bsSearchRange = *(CFRange*)&searchRange;
    CFRange cmdStartRange, cmdEndRange;
    CFIndex endLoc = NSMaxRange(searchRange);    
    
    while(bsSearchRange.length > 4 && BDStringFindCharacter((CFStringRef)self, '\\', bsSearchRange, &cmdStartRange) &&
          CFStringFindCharacterFromSet((CFStringRef)self, nonLetterCharacterSet, CFRangeMake(cmdStartRange.location + 1, endLoc - cmdStartRange.location - 1), 0, &cmdEndRange)){
        // if the char right behind the backslash is a non-letter char, it's a one-letter command
        if(cmdEndRange.location == cmdStartRange.location + 1)
            cmdEndRange.location++;
        // see if we found a left brace, we ignore commands like \LaTeX{} which we want to keep
        if('{' == CFStringGetCharacterAtIndex((CFStringRef)self, cmdEndRange.location) && 
           '}' != CFStringGetCharacterAtIndex((CFStringRef)self, cmdEndRange.location + 1))
            return NSMakeRange(cmdStartRange.location, cmdEndRange.location - cmdStartRange.location);
        
        bsSearchRange = CFRangeMake(cmdEndRange.location, endLoc - cmdEndRange.location);
    }
    
    return NSMakeRange(NSNotFound, 0);
}

- (NSString *)stringByBackslashEscapingTeXSpecials;
{
    static NSCharacterSet *charSet = nil;
    // We could really go crazy with this, but the main need is to escape characters that commonly appear in titles and journal names when importing from z39.50 and other non-RIS/non-BibTeX search group sources.  Those sources aren't processed by the HTML->TeX path that's used for RIS, since they generally don't have embedded HTML.
    if (nil == charSet)
        charSet = [[NSCharacterSet characterSetWithCharactersInString:@"%&"] copy];
    return [self stringByBackslashEscapingCharactersInSet:charSet];
}

- (NSString *)stringByBackslashEscapingCharactersInSet:(NSCharacterSet *)charSet;
{
    NSRange r = [self rangeOfCharacterFromSet:charSet options:NSLiteralSearch];
    if (r.location == NSNotFound)
        return self;
    
    NSMutableString *toReturn = [self mutableCopy];
    while (r.length) {
        NSUInteger start;
        if (r.location == 0 || [toReturn characterAtIndex:(r.location - 1)] != '\\') {
            // insert the backslash, then advance the search range by two characters
            [toReturn replaceCharactersInRange:NSMakeRange(r.location, 0) withString:@"\\"];
            start = r.location + 2;
            r = [toReturn rangeOfCharacterFromSet:charSet options:NSLiteralSearch range:NSMakeRange(start, [toReturn length] - start)];
        } else {
            // this one was already escaped, so advance a character and repeat the search, unless that puts us over the end
            if (r.location < [toReturn length]) {
                start = r.location + 1;
                r = [toReturn rangeOfCharacterFromSet:charSet options:NSLiteralSearch range:NSMakeRange(start, [toReturn length] - start)];
            } else {
                r = NSMakeRange(NSNotFound, 0);
            }
        }
    }
    return [toReturn autorelease];
}

- (NSString *)stringByConvertingHTMLToTeX;
{
    static NSCharacterSet *asciiSet = nil;
    if(asciiSet == nil)
        asciiSet = [[NSCharacterSet characterSetWithRange:NSMakeRange(0, 127)] retain];
    
    // set these up here, so we don't autorelease them every time we parse an entry
    // Some entries from Compendex have spaces in the tags, which is why we match 0-1 spaces between each character.
    static AGRegex *findSubscriptLeadingTag = nil;
    if(findSubscriptLeadingTag == nil)
        findSubscriptLeadingTag = [[AGRegex alloc] initWithPattern:@"< ?s ?u ?b ?>"];
    static AGRegex *findSubscriptOrSuperscriptTrailingTag = nil;
    if(findSubscriptOrSuperscriptTrailingTag == nil)
        findSubscriptOrSuperscriptTrailingTag = [[AGRegex alloc] initWithPattern:@"< ?/ ?s ?u ?[bp] ?>"];
    static AGRegex *findSuperscriptLeadingTag = nil;
    if(findSuperscriptLeadingTag == nil)
        findSuperscriptLeadingTag = [[AGRegex alloc] initWithPattern:@"< ?s ?u ?p ?>"];
    
    // This one might require some explanation.  An entry with TI of "Flapping flight as a bifurcation in Re<sub>&omega;</sub>"
    // was run through the html conversion to give "...Re<sub>$\omega$</sub>", then the find sub/super regex replaced the sub tags to give
    // "...Re$_$omega$$", which LaTeX barfed on.  So, we now search for <sub></sub> tags with matching dollar signs inside, and remove the inner
    // dollar signs, since we'll use the dollar signs from our subsequent regex search and replace; however, we have to
    // reject the case where there is a <sub><\sub> by matching [^<]+ (at least one character which is not <), or else it goes to the next </sub> tag
    // and deletes dollar signs that it shouldn't touch.  Yuck.
    static AGRegex *findNestedDollar = nil;
    if(findNestedDollar == nil)
        findNestedDollar = [[AGRegex alloc] initWithPattern:@"(< ?s ?u ?[bp] ?>[^<]+)(\\$)(.*)(\\$)(.*< ?/ ?s ?u ?[bp] ?>)"];
    
    // Run the value string through the HTML2LaTeX conversion, to clean up &theta; and friends.
    // NB: do this before the regex find/replace on <sub> and <sup> tags, or else your LaTeX math
    // stuff will get munged.  Unfortunately, the C code for HTML2LaTeX will destroy accented characters, so we only send it ASCII, and just keep
    // the accented characters to let BDSKConverter deal with them later.
    
    NSScanner *scanner = [[NSScanner alloc] initWithString:self];
    NSString *asciiAndHTMLChars, *nonAsciiAndHTMLChars;
    NSMutableString *fullString = [[NSMutableString alloc] initWithCapacity:[self length]];
    
    while(![scanner isAtEnd]){
        if([scanner scanCharactersFromSet:asciiSet intoString:&asciiAndHTMLChars])
            [fullString appendString:[NSString TeXStringWithHTMLString:asciiAndHTMLChars ]];
		if([scanner scanUpToCharactersFromSet:asciiSet intoString:&nonAsciiAndHTMLChars])
			[fullString appendString:nonAsciiAndHTMLChars];
    }
    [scanner release];
    
    NSString *newValue = [[fullString copy] autorelease];
    [fullString release];
    
    // see if we have nested math modes and try to fix them; see note earlier on findNestedDollar
    if([findNestedDollar findInString:newValue] != nil){
        NSLog(@"WARNING: found nested math mode; trying to repair...");
        newValue = [findNestedDollar replaceWithString:@"$1$3$5"
                                              inString:newValue];
    }
    
    // Do a regex find and replace to put LaTeX subscripts and superscripts in place of the HTML
    // that Compendex (and possibly others) give us.
    newValue = [findSubscriptLeadingTag replaceWithString:@"\\$_{" inString:newValue];
    newValue = [findSuperscriptLeadingTag replaceWithString:@"\\$^{" inString:newValue];
    newValue = [findSubscriptOrSuperscriptTrailingTag replaceWithString:@"}\\$" inString:newValue];
    
    return newValue;
}

+ (NSString *)TeXStringWithHTMLString:(NSString *)htmlString;
{
    const char *str = [htmlString UTF8String];
    NSInteger ln = strlen(str);
    FILE *freport = stdout;
    char *html_fn = NULL;
    BOOL in_math = NO;
    BOOL in_verb = NO;
    BOOL in_alltt = NO;
    
/* ARM:  this code was taken directly from HTML2LaTeX.  I modified it to return
 an NSString object, since working with FILE* streams led to really nasty problems
 with NSPipe needing asynchronous reads to avoid blocking.
 The NSMutableString appendFormat method was used to replace all of the calls to
 fputc, fprintf, and fputs.
 
 Frans Faase, the author of HTML2LaTeX, gave permission to include this in BibDesk under the BSD license. 
 The following copyright notice was taken verbatim from the HTML2LaTeX code:
    
HTML2LaTeX -- Converting HTML files to LaTeX
Copyright (C) 1995-2003 Frans Faase

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

GNU General Public License:
http://home.planet.nl/~faase009/GNU.txt
*/
     

    NSMutableString *mString = [NSMutableString stringWithCapacity:ln];
    
    BOOL option_warn = YES;
    
	for(; *str; str++)
	{   BOOL special = NO;
		NSInteger v = 0;
		char ch = '\0';
		char html_ch[10];
		html_ch[0] = '\0';

            if (*str == '&')
            {   NSInteger i = 0;
                BOOL correct = NO;
                
                if (isalpha(str[1]))
                {   for (i = 0; i < 9; i++)
					if (isalpha(str[i+1]))
						html_ch[i] = str[i+1];
					else
						break;
                    html_ch[i] = '\0';
                    for (v = 0; v < NR_CH_TABLE; v++)
                        if (   ch_table[v].html_ch != NULL
                               && !strcmp(html_ch, ch_table[v].html_ch))
                        {   special = YES;
                            correct = YES;
                            ch = ch_table[v].ch;
                            break;
                        }
                }
                    else if (str[1] == '#')
                    {   NSInteger code = 0;
                        html_ch[0] = '#';
                        for (i = 1; i < 9; i++)
                            if (isdigit(str[i+1]))
                            {   html_ch[i] = str[i+1];
                                code = code * 10 + str[i+1] - '0';
                            }
                                else
                                    break;
                        if ((code >= ' ' && code < 127) || code == 8)
                        {   correct = YES;
                            ch = code;
                        }
                        else if (code >= 160 && code <= 255)
                        {
                            correct = YES;
                            special = YES;
                            v = code - 160;
                            ch = ch_table[v].ch;
                        }
                    }
                    html_ch[i] = '\0';
                    
                    if (correct)
                    {   str += i;
                        if (str[1] == ';')
                            str++;
                    }
                    else 
                    {   if (freport != NULL && option_warn)
                        if (html_ch[0] == '\0')
                            fprintf(freport,
                                    "%s (%ld) : Replace `&' by `&amp;'.\n",
                                    html_fn, (long)ln);
                        else
                            fprintf(freport,
                                    "%s (%ld) : Unknown sequence `&%s;'.\n",
                                    html_fn, (long)ln, html_ch);
                        ch = *str;
                    }
            }
                else if (((unsigned char)*str >= ' ' && (unsigned char)*str <= HIGHASCII) || *str == '\t')
                    ch = *str;
                else if (option_warn && freport != NULL)
                    fprintf(freport,
                            "%s (%ld) : Unknown character %c (decimal)\n",
                            html_fn, (long)ln, (unsigned char)*str);
                if (mString)
                {   if (in_verb)
                {   
                    [mString appendFormat:@"%c", ch != '\0' ? ch : ' '];
                    if (   special && freport != NULL && option_warn
                           && v < NR_CH_M)
                    {   fprintf(freport, "%s (%ld) : ", html_fn, (long)ln);
                        if (html_ch[0] == '\0')
                            fprintf(freport, "character %c (decimal)", 
                                    (unsigned char) *str);
                        else
                            fprintf(freport, "sequence `&%s;'", html_ch);
                        fprintf(freport, " rendered as `%c' in verbatim\n",
                                ch != '\0' ? ch : ' ');
                    }
                }
                    else if (in_alltt)
                    {   if (special)
                    {   char *o = ch_table[v].tex_ch;
                        if (o != NULL)
                            if (*o == '$')
                                [mString appendFormat:@"\\(%s\\)", o + 1];
                            else
                                [mString appendFormat:@"%s", o];
                    }
                        else if (ch == '{' || ch == '}')
                            [mString appendFormat:@"\\%c", ch];
                        else if (ch == '\\')
                            [mString appendFormat:@"\\%c", ch];
                        else if (ch != '\0')
                            [mString appendFormat:@"%c", ch];
                    }
                    else if (special)
                    {   char *o = ch_table[v].tex_ch;
                        if (o == NULL)
                        {   if (freport != NULL && option_warn)
                        {   fprintf(freport,
                                    "%s (%ld) : no LaTeX representation for ",
                                    html_fn, (long)ln);
                            if (html_ch[0] == '\0')
                                fprintf(freport, "character %c (decimal)\n", 
                                        (unsigned char) *str);
                            else
                                fprintf(freport, "sequence `&%s;'\n", html_ch);
                        }
                        }
                        else if (*o == '$')
                            if (in_math)
                                [mString appendFormat:@"%s", o+1];
                            else
                                [mString appendFormat:@"{%s$}", o];
                        else
                            [mString appendFormat:@"%s", o];
                    }
                    else if (in_math)
                    {   if (ch == '#' || ch == '%')
                            [mString appendFormat:@"\\%c", ch];
                        else
                            [mString appendFormat:@"%c", ch];
                    }
                    else
                    {   switch(ch)
                    {   case '\0' : break;
                                        case '\t': [mString appendString:@"        "]; break;
					case '_': case '{': case '}':
					case '#': case '$': case '%':
                       [mString appendFormat:@"{\\%c}", ch]; break;
                                        case '@' : [mString appendFormat:@"{\\char64}"]; break;
					case '[' :
					case ']' : [mString appendFormat:@"{$%c$}", ch]; break;
					case '~' : [mString appendString:@"\\~{}"]; break;
                                        case '^' : [mString appendString:@"\\^{}"]; break;
					case '|' : [mString appendString:@"{$|$}"]; break;
					case '\\': [mString appendString:@"{$\\backslash$}"]; break;
					case '&' : [mString appendString:@"\\&"]; break;
                                        default: [mString appendFormat:@"%c", ch]; break;
                    }
                    }
                }
	}
    return mString;
}

- (NSArray *)sourceLinesBySplittingString;
{
    // ARM:  This code came from Art Isbell to cocoa-dev on Tue Jul 10 22:13:11 2001.  Comments are his.
    //       We were using componentsSeparatedByString:@"\r", but this is not robust.  Files from ScienceDirect
    //       have \n as newlines, so this code handles those cases as well as PubMed.
    NSUInteger stringLength = [self length];
    NSUInteger startIndex;
    NSUInteger lineEndIndex = 0;
    NSUInteger contentsEndIndex;
    NSRange range;
    NSMutableArray *sourceLines = [NSMutableArray array];
    
    // There is more than one way to terminate this loop.  Beware of an
    // invalid termination test which might exist in this untested example :-)
    while (lineEndIndex < stringLength)
    {
        // Include only a single character in range.  Not sure whether
        // this will work with empty lines, but if not, try a length of 0.
        range = NSMakeRange(lineEndIndex, 1);
        [self getLineStart:&startIndex 
                          end:&lineEndIndex 
                  contentsEnd:&contentsEndIndex 
                     forRange:range];
        
        // If you want to exclude line terminators...
        [sourceLines addObject:[self substringWithRange:NSMakeRange(startIndex, contentsEndIndex - startIndex)]];
    }
    return sourceLines;
}

- (NSString *)stringByEscapingGroupPlistEntities{
	NSMutableString *escapedValue = [self mutableCopy];
	// escape braces as they can give problems with btparse
	[escapedValue replaceOccurrencesOfString:@"%" withString:@"%25" options:0 range:NSMakeRange(0, [escapedValue length])]; // this should come first
	[escapedValue replaceOccurrencesOfString:@"{" withString:@"%7B" options:0 range:NSMakeRange(0, [escapedValue length])];
	[escapedValue replaceOccurrencesOfString:@"}" withString:@"%7D" options:0 range:NSMakeRange(0, [escapedValue length])];
	[escapedValue replaceOccurrencesOfString:@"<" withString:@"%3C" options:0 range:NSMakeRange(0, [escapedValue length])];
	[escapedValue replaceOccurrencesOfString:@">" withString:@"%3E" options:0 range:NSMakeRange(0, [escapedValue length])];
	return [escapedValue autorelease];
}

- (NSString *)stringByUnescapingGroupPlistEntities{
	NSMutableString *escapedValue = [self mutableCopy];
	// escape braces as they can give problems with btparse, and angles as they can give problems with the plist xml
	[escapedValue replaceOccurrencesOfString:@"%7B" withString:@"{" options:0 range:NSMakeRange(0, [escapedValue length])];
	[escapedValue replaceOccurrencesOfString:@"%7D" withString:@"}" options:0 range:NSMakeRange(0, [escapedValue length])];
	[escapedValue replaceOccurrencesOfString:@"%3C" withString:@"<" options:0 range:NSMakeRange(0, [escapedValue length])];
	[escapedValue replaceOccurrencesOfString:@"%3E" withString:@">" options:0 range:NSMakeRange(0, [escapedValue length])];
	[escapedValue replaceOccurrencesOfString:@"%25" withString:@"%" options:0 range:NSMakeRange(0, [escapedValue length])]; // this should come last
	return [escapedValue autorelease];
}

- (NSString *)lossyASCIIString{
    NSData *asciiData = [self dataUsingEncoding:NSASCIIStringEncoding];
    if (asciiData == nil) {
        NSMutableString *ms = [self mutableCopyWithZone:[self zone]];
        // do as much transliteration as possible, then strip all combining marks; works with ideographs as well
        CFStringTransform((CFMutableStringRef)ms, NULL, kCFStringTransformToLatin, FALSE);
        CFStringTransform((CFMutableStringRef)ms, NULL, kCFStringTransformStripCombiningMarks, FALSE);
        // final step to guarantee ASCII
        asciiData = [ms dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        [ms release];
    }
    return asciiData ? [[[NSString alloc] initWithData:asciiData encoding:NSASCIIStringEncoding] autorelease] : nil;
}

#pragma mark Comparisons

- (NSComparisonResult)localizedCaseInsensitiveNumericCompare:(NSString *)aStr{
    return [self compare:aStr
                 options:NSCaseInsensitiveSearch | NSNumericSearch
                   range:NSMakeRange(0, [self length])
                  locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
}

// -[NSString compare: options:NSNumericSearch] is buggy for string literals (tested on 10.4.3), but CFStringCompare() works and returns the same comparison constants.  Neither -[NSString compare:] or CFStringCompare() correctly handle negative numbers, though.
- (NSComparisonResult)numericCompare:(NSString *)otherString{
    NSDecimalNumber *a = [[NSDecimalNumber alloc] initWithString:self];
    NSDecimalNumber *b = [[NSDecimalNumber alloc] initWithString:otherString];
    NSComparisonResult ret = [a compare:b];
    [a release];
    [b release];
    return ret;    
}

- (NSString *)stringByRemovingTeXAndStopWords;
{
    CFMutableStringRef modifiedSelf = CFStringCreateMutableCopy(CFAllocatorGetDefault(), CFStringGetLength((CFStringRef)self), (CFStringRef)self);
    BDDeleteArticlesForSorting(modifiedSelf);
    BDDeleteTeXForSorting(modifiedSelf);
    return [(id)modifiedSelf autorelease];
}
    
- (NSComparisonResult)localizedCaseInsensitiveNonTeXNonArticleCompare:(NSString *)otherString;
{
    
    // Check before passing to CFStringCompare, as a nil argument causes a crash.  The caller has to handle nil comparisons.
    NSParameterAssert(otherString != nil);
    
    CFAllocatorRef allocator = CFAllocatorGetDefault();
    CFMutableStringRef modifiedSelf = CFStringCreateMutableCopy(allocator, CFStringGetLength((CFStringRef)self), (CFStringRef)self);
    CFMutableStringRef modifiedOther = CFStringCreateMutableCopy(allocator, CFStringGetLength((CFStringRef)otherString), (CFStringRef)otherString);
    
    BDDeleteArticlesForSorting(modifiedSelf);
    BDDeleteArticlesForSorting(modifiedOther);
    BDDeleteTeXForSorting(modifiedSelf);
    BDDeleteTeXForSorting(modifiedOther);
    
    // the mutating functions above should only create an empty string, not a nil string
    BDSKASSERT(modifiedSelf != nil);
    BDSKASSERT(modifiedOther != nil);
    
    // CFComparisonResult returns same values as NSComparisonResult
    CFComparisonResult result = CFStringCompare(modifiedSelf, modifiedOther, kCFCompareCaseInsensitive | kCFCompareLocalized);
    CFRelease(modifiedSelf);
    CFRelease(modifiedOther);
    
    return result;
}

- (NSComparisonResult)sortCompare:(NSString *)other{
    BOOL otherIsEmpty = [NSString isEmptyString:other];
	if ([self isEqualToString:@""]) {
		return (otherIsEmpty)? NSOrderedSame : NSOrderedDescending;
	} else if (otherIsEmpty) {
		return NSOrderedAscending;
	}
	return [self localizedCaseInsensitiveNumericCompare:other];
}    

- (NSComparisonResult)extensionCompare:(NSString *)other{
    NSString *myExtension = [self pathExtension];
    NSString *otherExtension = [other pathExtension];
    BOOL otherIsEmpty = [NSString isEmptyString:otherExtension];
	if ([myExtension isEqualToString:@""])
		return otherIsEmpty ? NSOrderedSame : NSOrderedDescending;
    if (otherIsEmpty)
		return NSOrderedAscending;
	return [myExtension localizedCaseInsensitiveCompare:otherExtension];
}    

- (NSComparisonResult)triStateCompare:(NSString *)other{
    // we order increasingly as 0, -1, 1
    NSInteger myValue = [self triStateValue];
    NSInteger otherValue = [other triStateValue];
    if (myValue == otherValue)
        return NSOrderedSame;
    else if (myValue == 0 || otherValue == 1)
        return NSOrderedAscending;
    else 
        return NSOrderedDescending;
}    

static NSURL *CreateFileURLFromPathOrURLString(NSString *aPath, NSString *basePath)
{
    // default return values
    NSURL *fileURL = nil;

    if ([aPath hasPrefix:@"file://"]) {
        fileURL = [[NSURL alloc] initWithString:aPath];
    } else if ([aPath length]) {
        unichar ch = [aPath characterAtIndex:0];
        if ('/' != ch && '~' != ch)
            aPath = [basePath stringByAppendingPathComponent:aPath];
        if (aPath)
            fileURL = [[NSURL alloc] initFileURLWithPath:[aPath stringByStandardizingPath]];
    }
    return fileURL;
}

static NSString *UTIForPathOrURLString(NSString *aPath, NSString *basePath)
{
    NSString *theUTI = nil;
    NSURL *fileURL = nil;
    // !!! We return nil when a file doesn't exist if it's a properly resolvable path/URL, but we have no way of checking existence with a relative path.  Returning nil is preferable, since then nonexistent files will be sorted to the top or bottom and they're easy to find.
    if (fileURL = CreateFileURLFromPathOrURLString(aPath, basePath)) {
        // UTI will be nil for a file that doesn't exist, yet had an absolute/resolvable path
        if (fileURL) {
            theUTI = [[NSWorkspace sharedWorkspace] typeOfFile:[[[fileURL path] stringByStandardizingPath] stringByResolvingSymlinksInPath] error:NULL];
            [fileURL release];
        }
        
    } else {
        
        // fall back to extension; this is probably a relative path, so we'll assume it exists
        NSString *extension = [aPath pathExtension];
        if ([extension isEqualToString:@""] == NO)
            theUTI = [(id)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)extension, NULL) autorelease];
    }
    return theUTI;
}

- (NSComparisonResult)UTICompare:(NSString *)other{
    return [self UTICompare:other basePath:nil];
}

- (NSComparisonResult)UTICompare:(NSString *)other basePath:(NSString *)basePath{
    NSString *otherUTI = UTIForPathOrURLString(other, basePath);
    NSString *selfUTI = UTIForPathOrURLString(self, basePath);
    if (nil == selfUTI)
        return (nil == otherUTI ? NSOrderedSame : NSOrderedDescending);
    if (nil == otherUTI)
        return NSOrderedAscending;
    return [selfUTI caseInsensitiveCompare:otherUTI];
}

#pragma mark -

- (BOOL)booleanValue{
    // check for "oui" for backard compatibility with French localization
    if([self isEqualToString:@"1"] ||
       [self compare:@"y" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
       [self compare:@"yes" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
       [self compare:@"oui" options:NSCaseInsensitiveSearch] == NSOrderedSame)
        return YES;
    else
        return NO;
}

- (NSCellStateValue)triStateValue{
    // check for "non" for backard compatibility with French localization
    if([self booleanValue]){
        return NSOnState;
    }else if([self isEqualToString:@""] ||
             [self isEqualToString:@"0"] ||
             [self compare:@"n" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
             [self compare:@"no" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
             [self compare:@"non" options:NSCaseInsensitiveSearch] == NSOrderedSame){
        return NSOffState;
    }else{
        return NSMixedState;
    }
}

- (NSString *)acronymValueIgnoringWordLength:(NSUInteger)ignoreLength{
    NSMutableString *result = [NSMutableString string];
	NSUInteger currentIgnoreLength;
    
    for (NSString *component in [self componentsSeparatedByString:@" "]) {
		currentIgnoreLength = ignoreLength;
        if(![component isEqualToString:@""]) // stringByTrimmingCharactersInSet will choke on an empty string
            component = [component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if([component length] > 1 && [component characterAtIndex:[component length] - 1] == '.')
			currentIgnoreLength = 0;
		if(![component isEqualToString:@""])
            component = [component stringByTrimmingCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]];
		if([component length] > currentIgnoreLength)
            [result appendString:[[component substringToIndex:1] uppercaseString]];
    }
    return result;
}

#pragma mark -

- (BOOL)containsWord:(NSString *)aWord{
    
    NSRange subRange = [self rangeOfString:aWord];
    
    if(subRange.location == NSNotFound)
        return NO;
    
    CFIndex wordLength = [aWord length];
    CFIndex myLength = [self length];
    
    // trivial case; we contain the word, and have the same length
    if(myLength == wordLength)
        return YES;
    
    CFIndex beforeIndex, afterIndex;
    
    beforeIndex = subRange.location - 1;
    afterIndex = NSMaxRange(subRange);
    
    UniChar beforeChar = '\0', afterChar = '\0';
    
    if(beforeIndex >= 0)
        beforeChar = [self characterAtIndex:beforeIndex];
    
    if(afterIndex < myLength)
        afterChar = [self characterAtIndex:afterIndex];
    
    static NSCharacterSet *wordTestSet = nil;
    if(wordTestSet == nil){
        NSMutableCharacterSet *set = [[NSCharacterSet punctuationCharacterSet] mutableCopy];
        [set formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        wordTestSet = [set copy];
        [set release];
    }
    
    // if a character appears before the start of the substring match, see if it is punctuation or whitespace
    if(beforeChar && [wordTestSet characterIsMember:beforeChar] == NO)
        return NO;
    
    // now check after the substring match
    if(afterChar && [wordTestSet characterIsMember:afterChar] == NO)
        return NO;
    
    return YES;
}

- (BOOL)hasCaseInsensitivePrefix:(NSString *)prefix;
{
    NSUInteger length = [prefix length];
    if(prefix == nil || length > [self length])
        return NO;
    
    return (CFStringCompareWithOptions((CFStringRef)self,(CFStringRef)prefix, CFRangeMake(0, length), kCFCompareCaseInsensitive) == kCFCompareEqualTo ? YES : NO);
}

#pragma mark -

- (NSArray *)componentsSeparatedByCharactersInSet:(NSCharacterSet *)charSet trimWhitespace:(BOOL)trim;
{
    return [(id)BDStringCreateComponentsSeparatedByCharacterSetTrimWhitespace(CFAllocatorGetDefault(), (CFStringRef)self, (CFCharacterSetRef)charSet, trim) autorelease];
}

- (NSArray *)componentsSeparatedByStringCaseInsensitive:(NSString *)separator;
{
    return [(id)BDStringCreateArrayBySeparatingStringsWithOptions(CFAllocatorGetDefault(), (CFStringRef)self, (CFStringRef)separator, kCFCompareCaseInsensitive) autorelease];
}

- (NSArray *)componentsSeparatedByFieldSeparators;
{
    NSCharacterSet *acSet = [[BDSKTypeManager sharedManager] separatorCharacterSetForField:BDSKKeywordsString];
    if([self rangeOfCharacterFromSet:acSet].length)
        return [self componentsSeparatedByCharactersInSet:acSet trimWhitespace:YES];
    else 
        return [self componentsSeparatedByStringCaseInsensitive:@" and "];
}

- (NSArray *)componentsSeparatedByAnd;
{
    return [self componentsSeparatedByStringCaseInsensitive:@" and "];
}

- (NSArray *)componentsSeparatedByComma;
{
    return [self componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","] trimWhitespace:YES];
}

- (NSString *)stringByCollapsingAndTrimmingCharactersInSet:(NSCharacterSet *)charSet;
{
    return [(id)BDStringCreateByCollapsingAndTrimmingCharactersInSet(CFAllocatorGetDefault(), (CFStringRef)self, (CFCharacterSetRef)charSet) autorelease];
}

- (NSString *)stringByNormalizingSpacesAndLineBreaks;
{
    return [(id)BDStringCreateByNormalizingWhitespaceAndNewlines(CFAllocatorGetDefault(), (CFStringRef)self) autorelease];
}

- (NSString *)stringByAppendingEllipsis{
    return [self stringByAppendingString:[NSString horizontalEllipsisString]];
}

- (NSString *)stringBySurroundingWithSpacesIfNotEmpty 
{ 
    return [self isEqualToString:@""] ? self : [NSString stringWithFormat:@" %@ ", self];
}

- (NSString *)stringByAppendingSpaceIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [self stringByAppendingString:@" "];
}

- (NSString *)stringByAppendingDoubleSpaceIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [self stringByAppendingString:@"  "];
}

- (NSString *)stringByPrependingSpaceIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [NSString stringWithFormat:@" %@", self];
}

- (NSString *)stringByAppendingCommaIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [self stringByAppendingString:@","];
}

- (NSString *)stringByAppendingFullStopIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [self stringByAppendingString:@"."];
}

- (NSString *)stringByAppendingCommaAndSpaceIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [self stringByAppendingString:@", "];
}

- (NSString *)stringByAppendingFullStopAndSpaceIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [self stringByAppendingString:@". "];
}

- (NSString *)stringByPrependingCommaAndSpaceIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [NSString stringWithFormat:@", %@", self];
}

- (NSString *)stringByPrependingFullStopAndSpaceIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [NSString stringWithFormat:@". %@", self];
}

- (NSString *)quotedStringIfNotEmpty 
{ 
    return [self isEqualToString:@""] ? self : [NSString stringWithFormat:@"\"%@\"", self];
}

- (NSString *)parenthesizedStringIfNotEmpty
{
    return [self isEqualToString:@""] ? self : [NSString stringWithFormat:@"(%@)", self];
}

- (NSString *)titlecaseString;
{
    CFAllocatorRef alloc = CFGetAllocator((CFStringRef)self);
    CFMutableStringRef mutableString = CFStringCreateMutableCopy(alloc, 0, (CFStringRef)self);
    CFLocaleRef locale = CFLocaleCopyCurrent();
    CFStringCapitalize(mutableString, locale);
    CFRelease(locale);
    
    CFArrayRef comp = BDStringCreateComponentsSeparatedByCharacterSetTrimWhitespace(alloc, mutableString, CFCharacterSetGetPredefined(kCFCharacterSetWhitespace), TRUE);
    CFRelease(mutableString);
    NSMutableArray *words = nil;
    
    if (comp) {
        words = (NSMutableArray *)CFArrayCreateMutableCopy(alloc, CFArrayGetCount(comp), comp);
        CFRelease(comp);
    }
    
    const NSString *uppercaseWords[] = {
        @"A",
        @"An",
        @"The",
        @"Of",
        @"And",
    };
    
    const NSString *lowercaseWords[] = {
        @"a",
        @"an",
        @"the",
        @"of",
        @"and",
    };
    
    NSUInteger i, j, iMax = sizeof(uppercaseWords) / sizeof(NSString *);
    
    for (i = 0; i < iMax; i++) {
        
        const NSString *ucWord = uppercaseWords[i];
        const NSString *lcWord = lowercaseWords[i];
        
        // omit the first word, since it should always be capitalized
        while (NSNotFound != (j = [words indexOfObject:ucWord]) && j > 0)
            [words replaceObjectAtIndex:j withObject:lcWord];
    }
    
    NSString *toReturn = nil;
    if (words) {
        toReturn = (NSString *)CFStringCreateByCombiningStrings(alloc, (CFArrayRef)words, CFSTR(" "));
        [words release];
    }
    return [toReturn autorelease];
}

- (NSString *)stringByTrimmingFromLastPunctuation{
    NSRange range = [self rangeOfCharacterFromSet:[NSCharacterSet punctuationCharacterSet] options:NSBackwardsSearch];
    
    if(range.location != NSNotFound && (range.location += 1) < [self length])
        return [self substringWithRange:NSMakeRange(range.location, [self length] - range.location)];
    else
        return self;
}

- (NSString *)stringByTrimmingPrefixCharactersFromSet:(NSCharacterSet *)characterSet;
{
    NSString *string = nil;
    NSScanner *scanner = [[NSScanner alloc] initWithString:self];
    [scanner setCharactersToBeSkipped:nil];
    [scanner scanCharactersFromSet:characterSet intoString:nil];
    NSRange range = NSMakeRange(0, [scanner scanLocation]);
    [scanner release];
    
    if(range.length){
        NSMutableString *mutableCopy = [self mutableCopy];
        [mutableCopy deleteCharactersInRange:range];
        string = [mutableCopy autorelease];
    }
    return string ?: self;
}

- (NSString *)stringByDeletingCharactersInSet:(NSCharacterSet *)removeSet;
{
    if ([self rangeOfCharacterFromSet:removeSet].length == 0)
        return self;
    NSMutableString *string = [self mutableCopy];
    [string deleteCharactersInCharacterSet:removeSet];
    return [string autorelease];
}

- (NSString *)stringByReplacingCharactersInSet:(NSCharacterSet *)set withString:(NSString *)replaceString;
{
    if ([self rangeOfCharacterFromSet:set].length == 0)
        return self;
    NSMutableString *string = [self mutableCopy];
    [string replaceOccurrencesOfCharactersInSet:set withString:replaceString];
    return [string autorelease];
}

- (NSString *)stringByRemovingWhitespace {
    return [self stringByDeletingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (NSString *)stringByRemovingReturns {
    return [self stringByDeletingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

- (NSString *)stringByRemovingString:(NSString *)removeString {
    if ([removeString length] == 0 || [self rangeOfString:removeString].length == 0)
        return self;
    return [[self componentsSeparatedByString:removeString] componentsJoinedByString:@""];
}

// This method is copied from NSString-OFStringExtensions.m
- (NSString *)stringByRemovingPrefix:(NSString *)prefix {
    NSUInteger length = [prefix length];
    if (length && [self hasPrefix:prefix])
        return [self substringFromIndex:length];
    return self;
}

// This method is copied from NSString-OFStringExtensions.m
- (NSString *)stringByRemovingSuffix:(NSString *)suffix {
    NSUInteger length = [suffix length];
    if (length && [self hasSuffix:suffix])
        return [self substringToIndex:[self length] - length];
    return self;
}

- (NSString *)stringByRemovingSurroundingWhitespaceAndNewlines {
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (NSString *)stringByRemovingSurroundingWhitespace {
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (NSString *)stringByCollapsingWhitespaceAndRemovingSurroundingWhitespace {
    return [self stringByCollapsingAndTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

// This method is copied and modified from NSString-OFStringExtensions.m
- (NSString *)fullyEncodeAsIURI {
    static const char hexDigits[16] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};
    static NSCharacterSet *unsafeCharacterSet = nil;
    if (unsafeCharacterSet == nil) {
        // unsafeCharacterSet is approximately the inverse of the set of characters that may appear in a URI according to RFC2396.  Note that it's a bit different from AcceptableCharacterSet; it has a different purpose.
        NSMutableCharacterSet *tmpSet = [[NSMutableCharacterSet alloc] initWithString:@"!$%&'()*+,-./0123456789:;=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~"];
        // Note: RFC2396 requires us to escape backslashes, carets, and pipes, which we don't do because this prevents us from interoperating with some web servers which don't correctly decode their requests.  See <bug://bugs/4467>: Should we stop escaping the pipe | char in URLs? (breaks counters, lycos.de).
        [tmpSet addCharactersInString:@"\\^|"];
        [tmpSet invert];
        unsafeCharacterSet = [tmpSet copy];
        [tmpSet release];
    }
    
    // Omni uses the inverse check here, which seems to completely negate the use of this method
    if ([self rangeOfCharacterFromSet:unsafeCharacterSet].length == 0)
        return self;
    
    NSData *utf8Data = [self dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    const unsigned char *source = [utf8Data bytes];
    NSUInteger sourceSize = [utf8Data length];
    NSUInteger destSize = sourceSize;
    
    if (destSize < 20)
        destSize *= 3;
    else
        destSize += ( destSize >> 1 );
    
    unsigned char *dest = NSZoneMalloc(NULL, destSize);
    NSUInteger i, j = 0;
    
    for (i = 0; i < sourceSize; i++) {
        unsigned char ch = source[i];
        
        // Headroom: we may insert up to three bytes into destination.
        if (j + 3 >= destSize) {
            NSInteger newSize = destSize + ( destSize >> 1 );
            dest = NSZoneRealloc(NULL, dest, newSize);
            destSize = newSize;
        }
        
        if ([unsafeCharacterSet characterIsMember:ch]) {
            dest[j++] = '%';
            dest[j++] = (unichar)hexDigits[((ch & 0xF0) >> 4)];
            dest[j++] = (unichar)hexDigits[(ch & 0x0F)];
        } else {
            dest[j++] = ch;
        }
    }
    
    NSString *resultString = (NSString *)CFStringCreateWithBytes(kCFAllocatorDefault, dest, j, kCFStringEncodingASCII, FALSE);
    NSZoneFree(NULL, dest);
    
    return [resultString autorelease];
}

#pragma mark Paths

// These methods are copied and modified from NSString-OFStringExtensions.m

+ (NSString *)pathSeparator {
    return [NSOpenStepRootDirectory() substringToIndex:1];
}

- (NSArray *)commonRootPathComponentsOfFilename:(NSString *)filename components:(NSArray **)components otherComponents:(NSArray **)otherComponents {
    NSArray *array = [self pathComponents];
    NSArray *otherArray = [[filename stringByStandardizingPath] pathComponents];
    NSUInteger i, minLength = MIN([array count], [otherArray count]);
    NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:minLength];

    for (i = 0; i < minLength; i++) {
        if ([[array objectAtIndex:i] isEqualToString:[otherArray objectAtIndex:i]])
            [resultArray addObject:[array objectAtIndex:i]];
        else
            break;
    }
        
    if ([resultArray count] == 0)
        return nil;

    if (components)
        *components = [array subarrayWithRange:NSMakeRange(i, [array count] - i)];
    if (otherComponents)
        *otherComponents = [otherArray subarrayWithRange:NSMakeRange(i, [otherArray count] - i)];
    
    return resultArray;
}

- (NSString *)commonRootPathOfFile:(NSString *)filename {
    NSArray *components = [self commonRootPathComponentsOfFilename:filename components:NULL otherComponents:NULL];
    return components ? [NSString pathWithComponents:components] : nil;
}

- (NSString *)relativePathFromPath:(NSString *)basePath {
    NSArray *commonRoot, *myUniquePart, *baseUniquePart;
    NSInteger numberOfStepsUp, i;

    basePath = [basePath stringByStandardizingPath];
    commonRoot = [[self stringByStandardizingPath] commonRootPathComponentsOfFilename:basePath components:&myUniquePart otherComponents:&baseUniquePart];
    if (commonRoot == nil || [commonRoot count] == 0)
        return self;
    
    numberOfStepsUp = [baseUniquePart count];
    if (numberOfStepsUp == 0)
        return [NSString pathWithComponents:myUniquePart];
    if ([[baseUniquePart lastObject] isEqualToString:@""])
        numberOfStepsUp --;
    if (numberOfStepsUp == 0)
        return [NSString pathWithComponents:myUniquePart];
    
    NSMutableArray *stepsUpArray = [[myUniquePart mutableCopy] autorelease];
    for (i = 0; i < numberOfStepsUp; i++) {
        NSString *steppingUpPast = [baseUniquePart objectAtIndex:i];
        if ([steppingUpPast isEqualToString:@".."]) {
            if ([[stepsUpArray objectAtIndex:0] isEqualToString:@".."])
                [stepsUpArray removeObjectAtIndex:0];
            else {
                // Gack! Just give up.
                return nil;
            }
        } else
            [stepsUpArray insertObject:@".." atIndex:0];
    }

    return [[NSString pathWithComponents:stepsUpArray] stringByStandardizingPath];
}

- (NSString *)stringByNormalizingPath {
    // Split on slashes and chop out '.' and '..' correctly.
    NSArray *pathElements = [self pathComponents];
    NSUInteger i, count = [pathElements count], preserveCount;
    NSMutableArray *newPathElements = [NSMutableArray arrayWithCapacity:count];
    if (count > 0 && [[pathElements objectAtIndex:0] isEqualToString:@"/"])
        preserveCount = 1;
    else
        preserveCount = 0;
    for (i = 0; i < count; i++) {
        NSString *pathElement = [pathElements objectAtIndex:i];
        if ([pathElement isEqualToString:@".."]) {
            if (count > preserveCount)
                [newPathElements removeLastObject];
        } else if ([pathElement isEqualToString:@"."] == NO)
            [newPathElements addObject:pathElement];
    }
    return [NSString pathWithComponents:newPathElements];
}

#pragma mark HTML/XML

- (NSString *)stringByConvertingHTMLLineBreaks{
    NSMutableString *rv = [self mutableCopy];
    [rv replaceOccurrencesOfString:@"\n" 
                        withString:@"<br>"
                           options:NSCaseInsensitiveSearch
                             range:NSMakeRange(0,[self length])];
    return [rv autorelease];
}

- (NSString *)stringByEscapingBasicXMLEntitiesUsingUTF8;
{
    return [(NSString *)BDXMLCreateStringWithEntityReferencesInCFEncoding((CFStringRef)self, kCFStringEncodingUTF8) autorelease];
}
    
#define APPEND_PREVIOUS() \
    string = [[NSString alloc] initWithCharacters:begin length:(ptr - begin)]; \
        [result appendString:string]; \
            [string release]; \
                begin = ptr + 1;

// Stolen and modified from the OmniFoundation -htmlString.
- (NSString *)htmlStringEscapingBreak:(BOOL)escapeBreak;
{
    unichar *ptr, *begin, *end;
    NSMutableString *result;
    NSString *string;
    NSInteger length;
    
    length = [self length];
    ptr = NSZoneMalloc([self zone], length * sizeof(unichar));
    void *originalPtr = ptr;
    end = ptr + length;
    [self getCharacters:ptr];
    result = [NSMutableString stringWithCapacity:length];
    
    begin = ptr;
    while (ptr < end) {
        if (*ptr > 127) {
            APPEND_PREVIOUS();
            [result appendFormat:@"&#%ld;", (long)*ptr];
        } else if (*ptr == '&') {
            APPEND_PREVIOUS();
            [result appendString:@"&amp;"];
        } else if (*ptr == '\"') {
            APPEND_PREVIOUS();
            [result appendString:@"&quot;"];
        } else if (*ptr == '<') {
             APPEND_PREVIOUS();
            [result appendString:@"&lt;"];
        } else if (*ptr == '>') {
            APPEND_PREVIOUS();
            [result appendString:@"&gt;"];
        } else if (*ptr == '\n') {
            APPEND_PREVIOUS();
            if (escapeBreak == NO)
                [result appendString:@"<br/>"];
            else if (ptr + 1 != end && *(ptr + 1) == '\n') {
                [result appendString:@"&lt;p&gt;"];
                ptr++;
            } else
                [result appendString:@"&lt;br&gt;"];
        }
        ptr++;
    }
    APPEND_PREVIOUS();
    NSZoneFree([self zone], originalPtr);
    return result;
}

- (NSString *)htmlString {
    return [self htmlStringEscapingBreak:NO];
}

- (NSString *)xmlString {
    return [self htmlStringEscapingBreak:YES];
}

- (NSString *)csvString;
{
    unichar *ptr, *begin, *end;
    NSMutableString *result;
    NSString *string;
    NSInteger length;
    BOOL isQuoted, needsSpace;
    
    length = [self length];
    ptr = NSZoneMalloc([self zone], length * sizeof(unichar));
    void *originalPtr = ptr;
    end = ptr + length;
    [self getCharacters:ptr];
    result = [NSMutableString stringWithCapacity:length];
    isQuoted = length > 0 && (*ptr == ' ' || *(end-1) == ' ');
    needsSpace = NO;
    
    if(isQuoted == NO && [self rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r\t\","]].length == 0) {
        NSZoneFree([self zone], originalPtr);
        return self;
    }
    
    begin = ptr;
    while (ptr < end) {
        switch (*ptr) {
            case '\n':
            case '\r':
                APPEND_PREVIOUS();
                if (needsSpace)
                    [result appendString:@" "];
            case ' ':
            case '\t':
                needsSpace = NO;
                break;
            case '"':
                APPEND_PREVIOUS();
                [result appendString:@"\"\""];
            case ',':
                isQuoted = YES;
            default:
                needsSpace = YES;
                break;
        }
        ptr++;
    }
    APPEND_PREVIOUS();
    if (isQuoted) {
        [result insertString:@"\"" atIndex:0];
        [result appendString:@"\""];
    }
    NSZoneFree([self zone], originalPtr);
    return result;
}

- (NSString *)tsvString;
{
    if([self rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\t\n\r"]].length == 0)
        return self;
    
    unichar *ptr, *begin, *end;
    NSMutableString *result;
    NSString *string;
    NSInteger length;
    BOOL needsSpace;
    
    length = [self length];
    ptr = NSZoneMalloc([self zone], length * sizeof(unichar));
    void *originalPtr = ptr;
    end = ptr + length;
    [self getCharacters:ptr];
    result = [NSMutableString stringWithCapacity:length];
    needsSpace = NO;
    
    begin = ptr;
    while (ptr < end) {
        switch (*ptr) {
            case '\t':
                needsSpace = YES;
            case '\n':
            case '\r':
                APPEND_PREVIOUS();
                if (needsSpace)
                    [result appendString:@" "];
            case ' ':
                needsSpace = NO;
                break;
            default:
                needsSpace = YES;
                break;
        }
        ptr++;
    }
    APPEND_PREVIOUS();
    NSZoneFree([self zone], originalPtr);
    return result;
}

#pragma mark -
#pragma mark Script arguments

// parses a space separated list of shell script argments
// allows quoting parts of an argument and escaped characters outside quotes, according to shell rules
- (NSArray *)shellScriptArgumentsArray {
    static NSCharacterSet *specialChars = nil;
    static NSCharacterSet *quoteChars = nil;
    
    if (specialChars == nil) {
        NSMutableCharacterSet *tmpSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
        [tmpSet addCharactersInString:@"\\\"'`"];
        specialChars = [tmpSet copy];
        [tmpSet release];
        quoteChars = [[NSCharacterSet characterSetWithCharactersInString:@"\"'`"] retain];
    }
    
    NSScanner *scanner = [NSScanner scannerWithString:self];
    NSString *s = nil;
    unichar ch = 0;
    NSMutableString *currArg = [scanner isAtEnd] ? nil : [NSMutableString string];
    NSMutableArray *arguments = [NSMutableArray array];
    
    [scanner setCharactersToBeSkipped:nil];
    [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
    
    while ([scanner isAtEnd] == NO) {
        if ([scanner scanUpToCharactersFromSet:specialChars intoString:&s])
            [currArg appendString:s];
        if ([scanner scanCharacter:&ch] == NO)
            break;
        if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:ch]) {
            // argument separator, add the last one we found and ignore more whitespaces
            [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
            [arguments addObject:currArg];
            currArg = [scanner isAtEnd] ? nil : [NSMutableString string];
        } else if (ch == '\\') {
            // escaped character
            if ([scanner scanCharacter:&ch] == NO)
                [NSException raise:NSInternalInconsistencyException format:@"Missing character"];
            if ([currArg length] == 0 && [[NSCharacterSet newlineCharacterSet] characterIsMember:ch])
                // ignore escaped newlines between arguments, as they should be considered whitespace
                [scanner scanCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:NULL];
            else // real escaped character, just add the character, so we can ignore it if it is a special character
                [currArg appendFormat:@"%C", ch];
        } else if ([quoteChars characterIsMember:ch]) {
            // quoted part of an argument, scan up to the matching quote
            if ([scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithRange:NSMakeRange(ch, 1)] intoString:&s])
                [currArg appendString:s];
            if ([scanner scanCharacter:NULL] == NO)
                [NSException raise:NSInternalInconsistencyException format:@"Unmatched %C", ch];
        }
    }
    if (currArg)
        [arguments addObject:currArg];
    return arguments;
}

// parses a comma separated list of AppleScript type arguments
- (NSArray *)appleScriptArgumentsArray {
    NSMutableArray *arguments = [NSMutableArray array];
    NSScanner *scanner = [NSScanner scannerWithString:self];
    unichar ch = 0;
    id object;
    
    [scanner setCharactersToBeSkipped:nil];
    
    while ([scanner isAtEnd] == NO) {
        if ([scanner scanAppleScriptValueUpToCharactersInSet:[NSCharacterSet commaCharacterSet] intoObject:&object])
            [arguments addObject:object];
        if ([scanner scanCharacter:&ch] == NO)
            break;
        if (ch != ',')
            [NSException raise:NSInternalInconsistencyException format:@"Missing ,"];
    }
    return arguments;
}

#pragma mark Some convenience keys for templates

- (NSURL *)url {
    NSURL *url = nil;
    if ([self rangeOfString:@"://"].location != NSNotFound)
        url = [NSURL URLWithStringByNormalizingPercentEscapes:self];
    else
        url = [NSURL fileURLWithPath:[self stringByExpandingTildeInPath]];
    return url;
}

- (NSAttributedString *)linkedText {
    return [[[NSAttributedString alloc] initWithString:self attributeName:NSLinkAttributeName attributeValue:[self url]] autorelease];
}

- (NSAttributedString *)icon {
    return [[self url] icon];
}

- (NSAttributedString *)smallIcon {
    return [[self url] smallIcon];
}

- (NSAttributedString *)linkedIcon {
    return [[self url] linkedIcon];
}

- (NSAttributedString *)linkedSmallIcon {
    return [[self url] linkedSmallIcon];
}

- (NSArray *)SkimNotes {
    return [[self url] SkimNotes];
}

- (NSString *)textSkimNotes {
    return [[self url] textSkimNotes];
}

- (NSAttributedString *)richTextSkimNotes {
    return [[self url] richTextSkimNotes];
}

- (NSString *)titleCapitalizedString {
    NSScanner *scanner = [[NSScanner alloc] initWithString:self];
    NSString *s = nil;
    NSMutableString *returnString = [NSMutableString stringWithCapacity:[self length]];
    NSInteger nesting = 0;
    unichar ch;
    NSUInteger location;
    NSRange range;
    BOOL foundFirstLetter = NO;
    
    [scanner setCharactersToBeSkipped:nil];
    
    while([scanner isAtEnd] == NO){
        if([scanner scanUpToCharactersFromSet:[NSCharacterSet curlyBraceCharacterSet] intoString:&s])
            [returnString appendString:nesting == 0 ? [s lowercaseString] : s];
        if (foundFirstLetter == NO) {
            range = [returnString rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]];
            if (range.location != NSNotFound) {
                foundFirstLetter = YES;
                if (nesting == 0)
                    [returnString replaceCharactersInRange:range withString:[[returnString substringWithRange:range] uppercaseString]];
            }
        }
        if([scanner scanCharacter:&ch] == NO)
            break;
        [returnString appendFormat:@"%C", ch];
        location = [scanner scanLocation];
        if(location > 0 && [self characterAtIndex:location - 1] == '\\')
            continue;
        if(ch == '{')
            nesting++;
        else
            nesting--;
    }
    
    [scanner release];
    
    return returnString;
}

- (NSString *)firstLetter{
    return [self length] ? [self substringToIndex:1] : nil;
}

- (NSString *)stringByAddingPercentEscapesIncludingReserved{
    return [(NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)self, NULL, CFSTR(";/?:@&=+$,"), kCFStringEncodingUTF8) autorelease];
}

- (NSString *)stringByAddingPercentEscapes{
    return [self stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)stringByReplacingPercentEscapes{
    return [self stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (unichar)firstCharacter{
    return [self length] ? [self characterAtIndex:0] : '\0';
}

- (unichar)lastCharacter{
    return [self length] ? [self characterAtIndex:[self length] - 1] : '\0';
}

- (NSString *)lowercaseFirst{
    return [[[self substringToIndex:1] lowercaseString] stringByAppendingString:[self substringFromIndex:1]];
}

- (NSString *)uppercaseFirst{
    return [[[self substringToIndex:1] uppercaseString] stringByAppendingString:[self substringFromIndex:1]];
}

@end


@implementation NSMutableString (BDSKExtensions)

- (BOOL)isMutableString {
    BOOL isMutable = YES;
    @try{
        unichar ch = 'X';
        CFStringAppendCharacters((CFMutableStringRef)self, &ch, 1);
    }
    @catch(NSException *localException){
        if([[localException name] isEqual:NSInvalidArgumentException])
            isMutable = NO;
        else
            @throw;
    }
    @catch(id localException){
        @throw;
    }
    
    [self deleteCharactersInRange:NSMakeRange([self length] - 1, 1)];
    return isMutable;
}

- (void)deleteCharactersInCharacterSet:(NSCharacterSet *)characterSet {
    BDDeleteCharactersInCharacterSet((CFMutableStringRef)self, (CFCharacterSetRef)characterSet);
}

- (void)replaceOccurrencesOfCharactersInSet:(NSCharacterSet *)set withString:(NSString *)replaceString {
    BDReplaceCharactersInCharacterSet((CFMutableStringRef)self, (CFCharacterSetRef)set, (CFStringRef)replaceString);
}

// This method is copied from NSMutableString-OFStringExtensions.m
- (void)appendStrings:(NSString *)first, ... {
    va_list argList;
    NSString *next;
    if (first == nil)
        return;
    [self appendString:first];
    va_start(argList, first);
    while ((next = va_arg(argList, NSString *)))
        [self appendString:next];
    va_end(argList);
}

@end

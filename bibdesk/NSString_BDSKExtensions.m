//  NSString_BDSKExtensions.m

//  Created by Michael McCracken on Sun Jul 21 2002.
/*
 This software is Copyright (c) 2002,2003,2004,2005,2006
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

#import "NSString_BDSKExtensions.h"
#import <OmniFoundation/NSString-OFExtensions.h>
#import <Cocoa/Cocoa.h>
#import <AGRegex/AGRegex.h>
#import <OmniFoundation/OFCharacterSet.h>
#import <OmniFoundation/OFStringScanner.h>
#import "BibPrefController.h"
#import "CFString_BDSKExtensions.h"
#import "OFCharacterSet_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"

static AGRegex *tipRegex = nil;
static AGRegex *andRegex = nil;
static AGRegex *orRegex = nil;
static NSString *yesString = nil;
static NSString *noString = nil;
static NSString *mixedString = nil;

@implementation NSString (BDSKExtensions)

+ (void)didLoad
{
    // match any words up to but not including '+' or '|' if they exist (see "Lookahead assertions" and "CONDITIONAL SUBPATTERNS" in pcre docs)
    tipRegex = [[AGRegex alloc] initWithPattern:@"(?(?=^.+(\\+|\\|))(^.+(?=\\+|\\|))|^.++)" options:AGRegexLazy];
    // match the word following a '+'; we consider a word boundary to be + or |
    andRegex = [[AGRegex alloc] initWithPattern:@"\\+[^+|]+"];
    // match the first word following a '|'
    orRegex = [[AGRegex alloc] initWithPattern:@"\\|[^+|]+"]; 
    
    yesString = [NSLocalizedString(@"Yes", @"Yes") copy];
    noString = [NSLocalizedString(@"No", @"No") copy];
    mixedString = [NSLocalizedString(@"-", @"indeterminate or mixed value indicator") copy];
    
}

+ (NSString *)hexStringForCharacter:(unichar)ch{
    NSMutableString *string = [NSMutableString stringWithCapacity:4];
    [string appendFormat:@"%X", ch];
    while([string length] < 4)
        [string insertString:@"0" atIndex:0];
    [string insertString:@"0x" atIndex:0];
    return string;
}

+ (NSString *)lossyASCIIStringWithString:(NSString *)aString{
    return [[[NSString alloc] initWithData:[aString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES] encoding:NSASCIIStringEncoding] autorelease];
}

static int MAX_RATING = 5;
+ (NSString *)ratingStringWithInteger:(int)rating;
{
    NSParameterAssert(rating <= MAX_RATING);
    static CFMutableDictionaryRef ratings = NULL;
    if(ratings == NULL){
        ratings = CFDictionaryCreateMutable(CFAllocatorGetDefault(), MAX_RATING + 1, &OFIntegerDictionaryKeyCallbacks, &OFNSObjectDictionaryValueCallbacks);
        int i = 0;
        NSMutableString *ratingString = [NSMutableString string];
        do {
            CFDictionaryAddValue(ratings, (const void *)i, (const void *)[[ratingString copy] autorelease]);
            [ratingString appendCharacter:(0x278A + i)];
        } while(i++ < MAX_RATING);
        OBPOSTCONDITION([(id)ratings count] == MAX_RATING + 1);
    }
    return (NSString *)CFDictionaryGetValue(ratings, (const void *)rating);
}

+ (NSString *)stringWithBool:(BOOL)boolValue {
	return boolValue ? yesString : noString;
}

+ (NSString *)stringWithCString:(const char *)byteString usingEncoding:(NSStringEncoding)encoding{
    return byteString == NULL ? nil : [(NSString *)CFStringCreateWithCString(CFAllocatorGetDefault(), byteString, CFStringConvertNSStringEncodingToEncoding(encoding)) autorelease];
}

+ (NSString *)stringWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)encoding guessEncoding:(BOOL)try;
{
    return [[self alloc] initWithContentsOfFile:path encoding:encoding guessEncoding:try];
}

+ (NSString *)stringWithTriStateValue:(NSCellStateValue)triStateValue {
    switch (triStateValue) {
        case NSOffState:
            return noString;
            break;
        case NSOnState:
            return yesString;
            break;
        case NSMixedState:
        default:
            return mixedString;
            break;
    }
}

+ (NSString *)unicodeNameOfCharacter:(unichar)ch;
{
    CFMutableStringRef charString = CFStringCreateMutable(CFAllocatorGetDefault(), 0);
    CFStringAppendCharacters(charString, &ch, 1);
    
    // ignore failures for now
    Boolean status;
    
    // This is a 10.4+ method; we'll just return the unichar as a string object in earlier versions.
    if(CFStringTransform != NULL)
        status = CFStringTransform(charString, NULL, kCFStringTransformToUnicodeName, FALSE);
    
    return [(id)charString autorelease];
} 
 
- (NSString *)initWithCString:(const char *)byteString usingEncoding:(NSStringEncoding)encoding{
    return byteString == NULL ? nil : (NSString *)CFStringCreateWithCString(CFAllocatorGetDefault(), byteString, CFStringConvertNSStringEncodingToEncoding(encoding));
}

static inline BOOL dataHasUnicodeByteOrderMark(NSData *data)
{
    unsigned len = [data length];
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
    if(self = [self init]){
        NSData *data = [[NSData alloc] initWithContentsOfFile:path];

        NSString *string = nil;
        if(encoding > 0)
            string = [[NSString alloc] initWithData:data encoding:encoding];
        if(nil == string && try && dataHasUnicodeByteOrderMark(data) && encoding != NSUnicodeStringEncoding)
            string = [[NSString alloc] initWithData:data encoding:NSUnicodeStringEncoding];
        if(nil == string && try && encoding != NSUTF8StringEncoding)
            string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if(nil == string && try && encoding != [NSString defaultCStringEncoding])
            string = [[NSString alloc] initWithData:data encoding:[NSString defaultCStringEncoding]];
        if(nil == string && try && encoding != NSISOLatin1StringEncoding)
            string = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];

        [data release];
        [self release];
        self = string;
    }
    return self;
}


#pragma mark TeX cleaning

- (NSString *)stringByConvertingDoubleHyphenToEndash{
    NSString *string = nil;
    NSRange range = [self rangeOfString:@"--"];
    if(range.length){
        string = [[NSMutableString stringWithString:self] replaceCharactersInRange:range withString:[NSString endashString]];
    }
    return string ? string : self;
}

- (NSString *)stringByRemovingCurlyBraces{
    return [self stringByRemovingCharactersInOFCharacterSet:[OFCharacterSet curlyBraceCharacterSet]];
}

- (NSString *)stringByRemovingTeX{
    static AGRegex *command = nil;    
    if(command == nil)
        command = [[AGRegex alloc] initWithPattern:@"\\\\[a-z].+\\{" options:AGRegexLazy];
    
    NSString *string = [command replaceWithString:@"" inString:self];
    return [string stringByRemovingCharactersInOFCharacterSet:[OFCharacterSet curlyBraceCharacterSet]];
    
}

#pragma mark TeX parsing

- (unsigned)indexOfRightBraceMatchingLeftBraceAtIndex:(unsigned)startLoc
{
    
    CFStringInlineBuffer inlineBuffer;
    CFIndex length = CFStringGetLength((CFStringRef)self);
    CFIndex cnt;
    BOOL matchFound = NO;
    
    CFStringInitInlineBuffer((CFStringRef)self, &inlineBuffer, CFRangeMake(0, length));
    UniChar ch;
    int rb = 0, lb = 0;
    
    if(CFStringGetCharacterFromInlineBuffer(&inlineBuffer, startLoc) != '{')
        [NSException raise:NSInternalInconsistencyException format:@"character at index %i is not a brace", startLoc];
    
    // we don't consider escaped braces yet
    for(cnt = startLoc; cnt < length; cnt++){
        ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, cnt);
        if(ch == '{')
            rb++;
        if(ch == '}')
            lb++;
        if(rb == lb){
            //NSLog(@"match found at index %i", cnt);
            matchFound = YES;
            break;
        }
    }
    
    return (matchFound == YES) ? cnt : NSNotFound;    
}

- (BOOL)isStringTeXQuotingBalancedWithBraces:(BOOL)braces connected:(BOOL)connected{
	return [self isStringTeXQuotingBalancedWithBraces:braces connected:connected range:NSMakeRange(0,[self length])];
}

- (BOOL)isStringTeXQuotingBalancedWithBraces:(BOOL)braces connected:(BOOL)connected range:(NSRange)range{
	int nesting = 0;
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
	int delimLoc = delimRange.location;
	
	while (delimLoc != NSNotFound) {
		if (delimLoc == 0 || [self characterAtIndex:delimLoc - 1] != '\\') {
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

- (BOOL)isRISString{ // sniff the string to see if it's or RIS
    NSScanner *scanner = [[NSScanner alloc] initWithString:self];
    [scanner setCharactersToBeSkipped:nil];
    BOOL isRIS = NO;
    
    // skip leading whitespace
    [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
    int rewindLoc = [scanner scanLocation];
    
    if([scanner scanString:@"PMID-" intoString:nil] &&
       [scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil]) // for Medline
        isRIS = YES;
    else {
        [scanner setScanLocation:rewindLoc];
        if([scanner scanString:@"TY" intoString:nil] &&
           [scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil] &&
           [scanner scanString:@"-" intoString:nil]) // for RIS
            isRIS = YES;
    }
    [scanner release];
    return isRIS;
}

- (BOOL)isJSTORString{ // sniff the string to see if it's JSTOR
	return [self hasPrefix:@"JSTOR CITATION LIST"];
}

- (BOOL)isBibTeXString{
    AGRegex *btRegex = [[AGRegex alloc] initWithPattern:@"^@[[:alpha:]]+[ \t]*[{(].+?[ \t]*," options:AGRegexMultiline];
    
    // AGRegex doesn't recognize \r as a $, so we normalize it first (bug #1420791)
    NSString *normalizedString = [self stringByNormalizingSpacesAndLineBreaks];
    BOOL found = ([btRegex findInString:normalizedString] != nil);
    [btRegex release];
    return found;
}

- (BOOL)isWebOfScienceString{
    // remove leading newlines in case this originates from copy/paste
    return [[self stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]] hasPrefix:@"FN ISI Export Format"];
}

- (int)contentStringType{
	if([self isBibTeXString])
		return BDSKBibTeXStringType;
	if([self isRISString])
		return BDSKRISStringType;
	if([self isJSTORString])
		return BDSKJSTORStringType;
	if([self isWebOfScienceString])
		return BDSKWOSStringType;
	return BDSKUnknownStringType;
}

- (NSRange)rangeOfTeXCommandInRange:(NSRange)searchRange;
{
    CFRange cmdStartRange;
    CFIndex maxLen = CFStringGetLength((CFStringRef)self);    
    
    if(BDStringFindCharacter((CFStringRef)self, '\\', CFRangeMake(0, maxLen), &cmdStartRange) == FALSE)
        return NSMakeRange(NSNotFound, 0);
    
    CFRange lbraceRange;
    CFRange cmdSearchRange = CFRangeMake(cmdStartRange.location, maxLen - cmdStartRange.location);
    
    // find the nearest left brace, but return NSNotFound if there's a space between the command start and the left brace
    if(BDStringFindCharacter((CFStringRef)self, '{', cmdSearchRange, &lbraceRange) == FALSE ||
       BDStringFindCharacter((CFStringRef)self, ' ', CFRangeMake(cmdSearchRange.location, lbraceRange.location - cmdSearchRange.location), NULL) == TRUE)
        return NSMakeRange(NSNotFound, 0);
    
    // search for the next right brace matching our left brace
    CFRange rbraceRange;
    Boolean foundRBrace = BDStringFindCharacter((CFStringRef)self, '}', CFRangeMake(lbraceRange.location, maxLen - lbraceRange.location), &rbraceRange);
    
    // check for an immediate right brace after the left brace, as in \LaTeX{}, since we
    // don't want to remove those, either
    if(foundRBrace && (rbraceRange.location == lbraceRange.location + 1)){
        // if we want to consider \LaTeX a command to be removed, cmdStop = spaceLoc; this can mess
        // up sorting, though, since \LaTeX is a word /and/ a command.
        return NSMakeRange(NSNotFound, 0);
    } else {
        return NSMakeRange(cmdStartRange.location, (lbraceRange.location - cmdStartRange.location));
    }
    
}

- (NSString *)stringByAddingRISEndTagsToPubMedString;
{
    OFStringScanner *scanner = [[OFStringScanner alloc] initWithString:self];
    NSMutableString *fixedString = [[NSMutableString alloc] initWithCapacity:[self length]];
    
    NSString *scannedString = [scanner readFullTokenUpToString:@"PMID- "];
    unsigned start;
    unichar prevChar;
    BOOL scannedPMID = NO;
    
    // this means we scanned some garbage before the PMID tag, or else this isn't a PubMed string...
    OBPRECONDITION(scannedString == nil);
    
    do {
        
        start = scannerScanLocation(scanner);
        
        // scan past the PMID tag
        scannedPMID = scannerReadString(scanner, @"PMID- ");
        OBPRECONDITION(scannedPMID);
        
        // scan to the next PMID tag
        scannedString = [scanner readFullTokenUpToString:@"PMID- "];
        [fixedString appendString:[self substringWithRange:NSMakeRange(start, scannerScanLocation(scanner) - start)]];
        
        // see if the previous character is a newline; if not, then some clod put a "PMID- " in the text
        if(scannerScanLocation(scanner)){
            prevChar = *(scanner->scanLocation - 1);
            if(BDIsNewlineCharacter(prevChar))
                [fixedString appendString:@"ER  - \r\n"];
        }
        
        OBASSERT(scannedString);
        
    } while(scannerHasData(scanner));
    
    OBPOSTCONDITION(!scannerHasData(scanner));
    
    [scanner release];
    OBPOSTCONDITION(![NSString isEmptyString:fixedString]);
    
#if OMNI_FORCE_ASSERTIONS
    // Here's our reference method, which caused swap death on large strings (AGRegex uses a lot of autoreleased NSData objects)
	NSString *tmpStr;
	
    AGRegex *regex = [AGRegex regexWithPattern:@"(?<!\\A)^PMID- " options:AGRegexMultiline];
    tmpStr = [regex replaceWithString:@"ER  - \r\nPMID- " inString:self];
	
    tmpStr = [tmpStr stringByAppendingString:@"ER  - \r\n"];
    OBPOSTCONDITION([tmpStr isEqualToString:fixedString]);
#endif
    
    return [fixedString autorelease];
}

#pragma mark Comparisons

- (NSComparisonResult)localizedCaseInsensitiveNumericCompare:(NSString *)aStr{
    return [self compare:aStr
                 options:NSCaseInsensitiveSearch | NSNumericSearch
                   range:NSMakeRange(0, [self length])
                  locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
}

// -[NSString compare: options:NSNumericSearch] is buggy for string literals (tested on 10.4.3), but CFStringCompare() works and returns the same comparison constants
- (NSComparisonResult)numericCompare:(NSString *)otherString{
    return CFStringCompare((CFStringRef)self, (CFStringRef)otherString, kCFCompareNumerically);
}

- (NSString *)stringByRemovingTeXAndStopWords;
{
    CFMutableStringRef modifiedSelf = CFStringCreateMutableCopy(CFAllocatorGetDefault(), CFStringGetLength((CFStringRef)self), (CFStringRef)self);
    BDDeleteTeXForSorting(modifiedSelf);
    BDDeleteArticlesForSorting(modifiedSelf);
    return [(id)modifiedSelf autorelease];
}
    
- (NSComparisonResult)localizedCaseInsensitiveNonTeXNonArticleCompare:(NSString *)otherString;
{
    
    // Check before passing to CFStringCompare, as a nil argument causes a crash.  The caller has to handle nil comparisons.
    NSParameterAssert(otherString != nil);
    
    CFAllocatorRef allocator = CFAllocatorGetDefault();
    CFMutableStringRef modifiedSelf = CFStringCreateMutableCopy(allocator, CFStringGetLength((CFStringRef)self), (CFStringRef)self);
    CFMutableStringRef modifiedOther = CFStringCreateMutableCopy(allocator, CFStringGetLength((CFStringRef)otherString), (CFStringRef)otherString);
    
    BDDeleteTeXForSorting(modifiedSelf);
    BDDeleteTeXForSorting(modifiedOther);
    BDDeleteArticlesForSorting(modifiedSelf);
    BDDeleteArticlesForSorting(modifiedOther);
    
    // the mutating functions above should only create an empty string, not a nil string
    OBASSERT(modifiedSelf != nil);
    OBASSERT(modifiedOther != nil);
    
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

- (NSComparisonResult)triStateCompare:(NSString *)other{
    // we order increasingly as 0, -1, 1
    int myValue = [self triStateValue];
    int otherValue = [other triStateValue];
    if (myValue == otherValue)
        return NSOrderedSame;
    else if (myValue == 0 || otherValue == 1)
        return NSOrderedAscending;
    else 
        return NSOrderedDescending;
}    

#pragma mark -

- (BOOL)booleanValue{
    // Omni's boolValue method uses YES, Y, yes, y and 1 with isEqualToString
    if([self compare:[NSString stringWithBool:YES] options:NSCaseInsensitiveSearch] == NSOrderedSame ||
       [self compare:@"y" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
       [self isEqualToString:@"1"])
        return YES;
    else
        return NO;
}

- (NSCellStateValue)triStateValue{
    if([self booleanValue] == YES){
        return NSOnState;
    }else if([self isEqualToString:@""] ||
             [self compare:[NSString stringWithBool:NO] options:NSCaseInsensitiveSearch] == NSOrderedSame ||
             [self compare:@"n" options:NSCaseInsensitiveSearch] == NSOrderedSame ||
             [self isEqualToString:@"0"]){
        return NSOffState;
    }else{
        return NSMixedState;
    }
}

- (NSString *)acronymValueIgnoringWordLength:(unsigned int)ignoreLength{
    NSMutableString *result = [NSMutableString string];
    NSArray *allComponents = [self componentsSeparatedByString:@" "]; // single whitespace
    NSEnumerator *e = [allComponents objectEnumerator];
    NSString *component = nil;
	unsigned int currentIgnoreLength;
    
    while(component = [e nextObject]){
		currentIgnoreLength = ignoreLength;
        if(![component isEqualToString:@""]) // stringByTrimmingCharactersInSet will choke on an empty string
            component = [component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if([component length] > 1 && [component characterAtIndex:[component length] - 1] == '.')
			currentIgnoreLength = 0;
		if(![component isEqualToString:@""])
            component = [component stringByTrimmingCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]];
		if([component length] > currentIgnoreLength){
            [result appendString:[[component substringToIndex:1] uppercaseString]];
        }
    }
    return result;
}

#pragma mark -

- (BOOL)containsString:(NSString *)searchString options:(unsigned int)mask range:(NSRange)aRange{
    return !searchString || [searchString length] == 0 || [self rangeOfString:searchString options:mask range:aRange].length > 0;
}

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
    CFIndex length = [prefix length];
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

- (NSString *)fastStringByCollapsingWhitespaceAndRemovingSurroundingWhitespace;
{
    return [(id)BDStringCreateByCollapsingAndTrimmingWhitespace(CFAllocatorGetDefault(), (CFStringRef)self) autorelease];
}

- (NSString *)fastStringByCollapsingWhitespaceAndNewlinesAndRemovingSurroundingWhitespaceAndNewlines;
{
    return [(id)BDStringCreateByCollapsingAndTrimmingWhitespaceAndNewlines(CFAllocatorGetDefault(), (CFStringRef)self) autorelease];
}

- (NSString *)stringByNormalizingSpacesAndLineBreaks;
{
    return [(id)BDStringCreateByNormalizingWhitespaceAndNewlines(CFAllocatorGetDefault(), (CFStringRef)self) autorelease];
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
    return string ? string : self;
}

- (NSString *)stringByAppendingEllipsis{
    return [self stringByAppendingString:[NSString horizontalEllipsisString]];
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
    return [OFXMLCreateStringWithEntityReferencesInCFEncoding(self, OFXMLBasicEntityMask, nil, kCFStringEncodingUTF8) autorelease];
}

// Stolen and modified from the OmniFoundation -htmlString.
- (NSString *)xmlString;
{
    unichar *ptr, *begin, *end;
    NSMutableString *result;
    NSString *string;
    int length;
    
#define APPEND_PREVIOUS() \
    string = [[NSString alloc] initWithCharacters:begin length:(ptr - begin)]; \
        [result appendString:string]; \
            [string release]; \
                begin = ptr + 1;
            
            length = [self length];
            ptr = alloca(length * sizeof(unichar));
            end = ptr + length;
            [self getCharacters:ptr];
            result = [NSMutableString stringWithCapacity:length];
            
            begin = ptr;
            while (ptr < end) {
                if (*ptr > 127) {
                    APPEND_PREVIOUS();
                    [result appendFormat:@"&#%d;", (int)*ptr];
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
                    if (ptr + 1 != end && *(ptr + 1) == '\n') {
                        [result appendString:@"&lt;p&gt;"];
                        ptr++;
                    } else
                        [result appendString:@"&lt;br&gt;"];
                }
                ptr++;
            }
            APPEND_PREVIOUS();
            return result;
}

#pragma mark -
#pragma mark Search string splitting

- (NSArray *)allSearchComponents;
{
    NSMutableArray *array = [NSMutableArray arrayWithArray:[self andSearchComponents]];
    [array addObjectsFromArray:[self orSearchComponents]];
    return array;
}

- (NSArray *)andSearchComponents;
{
    NSArray *matchArray = [andRegex findAllInString:self]; // an array of AGRegexMatch objects
    NSMutableArray *andArray = [[NSMutableArray alloc] initWithCapacity:[matchArray count]]; // an array of all the AND terms we're looking for
    
    // get the tip of the search string first (always an AND)
    NSString *tip = [[[tipRegex findInString:self] group] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if(!tip)
        return [NSArray array];
    else
        [andArray addObject:tip];
    
    NSEnumerator *e = [matchArray objectEnumerator];
    AGRegexMatch *m;
    
    NSString *s;
    
    while(m = [e nextObject]){ // get the resulting string from the match, and strip the AND from it; there might be a better way, but this works
        s = [[m group] stringByTrimmingCharactersInSet:[NSCharacterSet searchStringSeparatorCharacterSet]];
        if(![NSString isEmptyString:s])
            [andArray addObject:s];
    }    
    return [andArray autorelease];
}

- (NSArray *)orSearchComponents;
{
    NSArray *matchArray = [orRegex findAllInString:self];
    NSEnumerator *e = [matchArray objectEnumerator];
    AGRegexMatch *m;
    NSString *s;
    
    NSMutableArray *orArray = [[NSMutableArray alloc] initWithCapacity:[matchArray count]]; // an array of all the OR terms we're looking for
        
    while(m = [e nextObject]){ // now get all of the OR strings and strip the OR from them
        s = [[m group] stringByTrimmingCharactersInSet:[NSCharacterSet searchStringSeparatorCharacterSet]];
        if(![NSString isEmptyString:s])
            [orArray addObject:s];
    }
    return [orArray autorelease];
}

#pragma mark Empty lines

// whitespace at the beginning of the string up to the end or until (and including) a newline
- (NSRange)rangeOfLeadingEmptyLine {
    return [self rangeOfLeadingEmptyLineInRange:NSMakeRange(0, [self length])];
}

- (NSRange)rangeOfLeadingEmptyLineInRange:(NSRange)range {
    NSRange firstCharRange = [self rangeOfCharacterFromSet:[NSCharacterSet nonWhitespaceCharacterSet] options:0 range:range];
    NSRange wsRange = NSMakeRange(NSNotFound, 0);
    unsigned int start = range.location;
    if (firstCharRange.location == NSNotFound) {
        wsRange = range;
    } else {
        unichar firstChar = [self characterAtIndex:firstCharRange.location];
        unsigned int rangeEnd = NSMaxRange(firstCharRange);
        if([[NSCharacterSet newlineCharacterSet] characterIsMember:firstChar]) {
            if (firstChar == '\r' && rangeEnd < NSMaxRange(range) && [self characterAtIndex:rangeEnd] == '\n')
                wsRange = NSMakeRange(start, rangeEnd + 1 - start);
            else 
                wsRange = NSMakeRange(start, rangeEnd - start);
        }
    }
    return wsRange;
}

// whitespace at the end of the string from the beginning or after a newline
- (NSRange)rangeOfTrailingEmptyLine {
    return [self rangeOfTrailingEmptyLineInRange:NSMakeRange(0, [self length])];
}

- (NSRange)rangeOfTrailingEmptyLineInRange:(NSRange)range {
    NSRange lastCharRange = [self rangeOfCharacterFromSet:[NSCharacterSet nonWhitespaceCharacterSet] options:NSBackwardsSearch range:range];
    NSRange wsRange = NSMakeRange(NSNotFound, 0);
    unsigned int end = NSMaxRange(range);
    if (lastCharRange.location == NSNotFound) {
        wsRange = range;
    } else {
        unichar lastChar = [self characterAtIndex:lastCharRange.location];
        unsigned int rangeEnd = NSMaxRange(lastCharRange);
        if (rangeEnd < end && [[NSCharacterSet newlineCharacterSet] characterIsMember:lastChar]) 
            wsRange = NSMakeRange(rangeEnd, end - rangeEnd);
    }
    return wsRange;
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

@end


@implementation NSMutableString (BDSKExtensions)

- (BOOL)isMutableString;
{
    @try{
        [self appendCharacter:'X'];
    }
    @catch(id localException){
        if([[localException name] isEqualToString:NSInvalidArgumentException])
            return NO;
        else
            @throw;
    }
    
    [self deleteCharactersInRange:NSMakeRange([self length] - 1, 1)];
    return YES;
}

- (void)deleteCharactersInCharacterSet:(NSCharacterSet *)characterSet;
{
    BDDeleteCharactersInCharacterSet((CFMutableStringRef)self, (CFCharacterSetRef)characterSet);
}

@end

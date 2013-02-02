//
//  CFString_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 01/02/06.
/*
 This software is Copyright (c) 2006-2012
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

#import "CFString_BDSKExtensions.h"

// This object is a cache for our stop words, so we don't have to hit user defaults every time __BDDeleteArticlesForSorting() is called (which is fairly often).

typedef struct __BDSKStopWordCache {
    CFArrayRef stopWords;
    CFIndex    numberOfWords;
} _BDSKStopWordCache;

static _BDSKStopWordCache *stopWordCache = NULL;

static void 
stopWordNotificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    if (stopWordCache->stopWords)
        CFRelease(stopWordCache->stopWords);
    stopWordCache->stopWords = CFPreferencesCopyAppValue((CFStringRef)BDSKIgnoredSortTermsKey, kCFPreferencesCurrentApplication);
    if (stopWordCache->stopWords)
        stopWordCache->numberOfWords = CFArrayGetCount(stopWordCache->stopWords);
    else
        stopWordCache->numberOfWords = 0;
}

__attribute__((constructor))
static void initializeStopwordCache(void)
{
    stopWordCache = NSZoneMalloc(NULL, sizeof(_BDSKStopWordCache));
    stopWordCache->stopWords = NULL;
    stopWordCache->numberOfWords = 0;
    stopWordNotificationCallback(NULL, NULL, NULL, NULL, NULL);
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), stopWordCache, stopWordNotificationCallback, CFSTR("BDSKIgnoredSortTermsChangedNotification"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}

__attribute__((destructor))
static void destroyStopwordCache(void)
{
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetLocalCenter(), stopWordCache, CFSTR("BDSKIgnoredSortTermsChangedNotification"), NULL);
    if (stopWordCache->stopWords) CFRelease(stopWordCache->stopWords);
    NSZoneFree(NULL, stopWordCache);
}

static inline CFArrayRef __BDSKGetStopwords(void) { return stopWordCache->stopWords; }
static inline CFIndex __BDSKGetStopwordCount(void) { return stopWordCache->numberOfWords; }

#pragma mark -

#define STACK_BUFFER_SIZE 256

static CFCharacterSetRef whitespaceCharacterSet = NULL;
static CFCharacterSetRef punctuationCharacterSet = NULL;

__attribute__((constructor))
static void initializeStaticCharacterSets(void)
{
    whitespaceCharacterSet = CFRetain(CFCharacterSetGetPredefined(kCFCharacterSetWhitespace));
    punctuationCharacterSet = CFRetain(CFCharacterSetGetPredefined(kCFCharacterSetPunctuation));
}

static inline
BOOL __BDCharacterIsContainedInASCIISet(UniChar c, CFCharacterSetRef charSet)
{
    // minor optimization: check for an ASCII character, since those are most common in TeX
    return ( (c <= 0x007E && c >= 0x0021) ? NO : CFCharacterSetIsCharacterMember(charSet, c) );
}

static inline
BOOL __BDCharacterIsWhitespace(UniChar c)
{
    return __BDCharacterIsContainedInASCIISet(c, whitespaceCharacterSet);
}

static inline
BOOL __BDCharacterIsPunctuation(UniChar c)
{
    return ( CFCharacterSetIsCharacterMember(punctuationCharacterSet, c) );
}

static inline
Boolean __BDStringContainsCharacterFromSet(CFStringRef string, CFIndex length, CFCharacterSetRef charSet)
{
    // we assume that charSet only contains ASCII characters to allow some optimzation; this is OK as we will only use this for whitespace and whitespaceAndNewlines
    const UniChar *ptr = CFStringGetCharactersPtr(string);
    if(ptr != NULL){
        while(length--)
            if(__BDCharacterIsContainedInASCIISet(ptr[length], charSet))
                return TRUE;
    } else {
        CFStringInlineBuffer inlineBuffer;
        CFStringInitInlineBuffer(string, &inlineBuffer, CFRangeMake(0, length));
        
        while(length--)
            if(__BDCharacterIsContainedInASCIISet(CFStringGetCharacterFromInlineBuffer(&inlineBuffer, length), charSet))
                return TRUE;
    }

    return FALSE;
}

static inline
CFStringRef __BDStringCreateByCollapsingAndTrimmingCharactersInSet(CFAllocatorRef allocator, CFStringRef aString, CFCharacterSetRef charSet)
{
    
    CFIndex length = CFStringGetLength(aString);
    
    if(length == 0)
        return CFRetain(CFSTR(""));
    
    // improves efficiency somewhat when adding autocomplete strings, since we can completely avoid allocation
    if(__BDStringContainsCharacterFromSet(aString, length, charSet) == FALSE)
        return CFRetain(aString);
    
    // set up the buffer to fetch the characters
    CFIndex cnt = 0;
    CFStringInlineBuffer inlineBuffer;
    CFStringInitInlineBuffer(aString, &inlineBuffer, CFRangeMake(0, length));
    UniChar ch;
    UniChar *buffer, stackBuffer[STACK_BUFFER_SIZE];
    CFStringRef retStr;
    allocator = (allocator == NULL) ? CFGetAllocator(aString) : allocator;

    if(length >= STACK_BUFFER_SIZE) {
        buffer = (UniChar *)CFAllocatorAllocate(allocator, (length + 1) * sizeof(UniChar), 0);
    } else {
        buffer = stackBuffer;
    }
    
    NSCAssert1(buffer != NULL, @"failed to allocate memory for string of length %ld", (long)length);
    
    BOOL isFirst = NO;
    NSInteger bufCnt = 0;
    for(cnt = 0; cnt < length; cnt++){
        ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, cnt);
        if(!__BDCharacterIsContainedInASCIISet(ch, charSet)){
            isFirst = YES;
            buffer[bufCnt++] = ch; // not whitespace, so we want to keep it
        } else {
            if(isFirst){
                buffer[bufCnt++] = ' '; // if it's the first whitespace, we add a single space
                isFirst = NO;
            }
        }
    }
    
    if(buffer[(bufCnt-1)] == ' ') // we've collapsed any trailing whitespace, so disregard it
        bufCnt--;
    
    retStr = CFStringCreateWithCharacters(allocator, buffer, bufCnt);
    if(buffer != stackBuffer) CFAllocatorDeallocate(allocator, buffer);
    return retStr;
}

static inline Boolean
__BDShouldRemoveUniChar(UniChar c){ return (c == '`' || c == '$' || c == '\\' || __BDCharacterIsPunctuation(c)); }

// private function for removing some tex special characters from a string
// (only those I consider relevant to sorting)
static inline
void __BDDeleteTeXCharactersForSorting(CFMutableStringRef texString)
{
    if(BDIsEmptyString(texString))
        return;
    
    CFAllocatorRef allocator = CFGetAllocator(texString);

    CFStringInlineBuffer inlineBuffer;
    CFIndex length = CFStringGetLength(texString);
    CFIndex cnt = 0;
    
    // create an immutable copy to use with the inline buffer
    CFStringRef myCopy = CFStringCreateCopy(allocator, texString);
    CFStringInitInlineBuffer(myCopy, &inlineBuffer, CFRangeMake(0, length));
    UniChar ch;
    
    // delete the {`$\\( characters, since they're irrelevant to sorting, and typically
    // appear at the beginning of a word
    CFIndex delCnt = 0;
    while(cnt < length){
        ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, cnt);
        if(__BDShouldRemoveUniChar(ch)){
            // remove from the mutable string; we have to keep track of our index in the copy and the original
            CFStringDelete(texString, CFRangeMake(delCnt, 1));
        } else {
            delCnt++;
        }
        cnt++;
    }
    CFRelease(myCopy); // dispose of our temporary copy
}

static inline
void __BDDeleteArticlesForSorting(CFMutableStringRef mutableString)
{
    if(mutableString == nil)
        return;
    
    CFIndex count = __BDSKGetStopwordCount();
    if(!count) return;
    
    // remove certain terms for sorting, according to preferences
    // each one is typically an article, and we only look
    // for these at the beginning of a string   
    CFArrayRef articlesToRemove = __BDSKGetStopwords();    
    
    // get the max string length of any of the strings in the plist; we don't want to search any farther than necessary
    CFIndex maxRemoveLength = 0; 
    CFIndex idx = count;
    while(idx--)
        maxRemoveLength = MAX(CFStringGetLength(CFArrayGetValueAtIndex(articlesToRemove, idx)), maxRemoveLength);
    
    idx = count;
    CFRange searchRange, articleRange;
    Boolean found;
    CFIndex start = 0, length = CFStringGetLength(mutableString);
    
    while (start < length && __BDShouldRemoveUniChar(CFStringGetCharacterAtIndex(mutableString, start)))
        start++;
    
    searchRange = CFRangeMake(start, MIN(length - start, maxRemoveLength));
    
    while(idx--){
        found = CFStringFindWithOptions(mutableString, CFArrayGetValueAtIndex(articlesToRemove, idx), searchRange, kCFCompareAnchored | kCFCompareCaseInsensitive, &articleRange);
        
        // make sure the next character is whitespace before deleting, after checking bounds
        if(found && length > articleRange.location + articleRange.length && 
           (__BDCharacterIsWhitespace(CFStringGetCharacterAtIndex(mutableString, articleRange.location + articleRange.length)) ||
            __BDCharacterIsPunctuation(CFStringGetCharacterAtIndex(mutableString, articleRange.location + articleRange.length)))) {
            articleRange.length++;
            CFStringDelete(mutableString, articleRange);
            break;
        }
    }        
}

static inline
void __BDDeleteTeXCommandsForSorting(CFMutableStringRef mutableString)
{
    // this will go into an endless loop if the string is nil, but /only/ if the function is declared inline
    if(mutableString == nil)
        return;
    
    NSRange searchRange = NSMakeRange(0, CFStringGetLength(mutableString));
    NSRange cmdRange;
    NSUInteger startLoc;
        
    // This will find and remove the commands such as \textit{some word} that can confuse the sort order;
    // unfortunately, we can't remove things like {\textit some word}, since it could also be something
    // like {\LaTeX is great}, so this is a compromise
    while( (cmdRange = [(NSMutableString *)mutableString rangeOfTeXCommandInRange:searchRange]).location != NSNotFound){
        // delete the command
        [(NSMutableString *)mutableString deleteCharactersInRange:cmdRange];
        startLoc = cmdRange.location;
        searchRange.location = startLoc;
        searchRange.length = [(NSMutableString *)mutableString length] - startLoc;
    }
}

static inline
uint32_t __BDFastHash(CFStringRef aString)
{
    
    // Golden ratio - arbitrary start value to avoid mapping all 0's to all 0's
    // or anything like that.
    uint32_t PHI = 0x9e3779b9U;
    
    // Paul Hsieh's SuperFastHash
    // http://www.azillionmonkeys.com/qed/hash.html
    // Implementation from Apple's WebCore/khtml/xml/dom_stringimpl.cpp, designed
    // to hash UTF-16 characters.
    
    CFIndex l = CFStringGetLength(aString);
    uint32_t fastHash = PHI;
    uint32_t tmp;
    
    const UniChar *s = CFStringGetCharactersPtr(aString);
    UniChar *buf = NULL, stackBuffer[STACK_BUFFER_SIZE];
    CFAllocatorRef allocator = NULL;
    
    if(s == NULL){
        
        if(l > STACK_BUFFER_SIZE){
            allocator = CFGetAllocator(aString);
            buf = (UniChar *)CFAllocatorAllocate(allocator, l * sizeof(UniChar), 0);
            NSCAssert(buf != NULL, @"unable to allocate memory");
        } else {
            buf = stackBuffer;
        }
        CFStringGetCharacters(aString, CFRangeMake(0, l), buf);
        s = buf;
    }
    
    CFIndex rem = l & 1;
    l >>= 1;
    
    // Main loop
    for (; l > 0; l--) {
        fastHash += s[0];
        tmp = (s[1] << 11) ^ fastHash;
        fastHash = (fastHash << 16) ^ tmp;
        s += 2;
        fastHash += fastHash >> 11;
    }
    
    // Handle end case
    if (rem) {
        fastHash += s[0];
        fastHash ^= fastHash << 11;
        fastHash += fastHash >> 17;
    }
    
    if(buf != stackBuffer) CFAllocatorDeallocate(allocator, buf);
    
    // Force "avalanching" of final 127 bits
    fastHash ^= fastHash << 3;
    fastHash += fastHash >> 5;
    fastHash ^= fastHash << 2;
    fastHash += fastHash >> 15;
    fastHash ^= fastHash << 10;
    
    // this avoids ever returning a hash code of 0, since that is used to
    // signal "hash not computed yet", using a value that is likely to be
    // effectively the same as 0 when the low bits are masked
    if (fastHash == 0)
        fastHash = 0x80000000;
    
    return fastHash;
}

static inline
CFStringRef __BDStringCreateByNormalizingWhitespaceAndNewlines(CFAllocatorRef allocator, CFStringRef aString)
{
    
    CFIndex length = CFStringGetLength(aString);
    
    if(length == 0)
        return CFRetain(CFSTR(""));
    
    // set up the buffer to fetch the characters
    CFIndex cnt = 0;
    CFStringInlineBuffer inlineBuffer;
    CFStringInitInlineBuffer(aString, &inlineBuffer, CFRangeMake(0, length));
    UniChar ch;
    UniChar *buffer, stackBuffer[STACK_BUFFER_SIZE];
    CFStringRef retStr;
        
    if(length >= STACK_BUFFER_SIZE) {
        buffer = (UniChar *)CFAllocatorAllocate(allocator, (length + 1) * sizeof(UniChar), 0);
    } else {
        buffer = stackBuffer;
    }
    
    NSCAssert1(buffer != NULL, @"failed to allocate memory for string of length %ld", (long)length);
    
    NSInteger bufCnt = 0;
    BOOL ignoreNextNewline = NO;
    
    for(cnt = 0; cnt < length; cnt++){
        ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, cnt);
        if(__BDCharacterIsWhitespace(ch)){
            ignoreNextNewline = NO;
            buffer[bufCnt++] = ' ';   // replace with a single space
        } else if('\r' == ch){        // we can have \r\n, which should appear as a single \n
            ignoreNextNewline = YES;
            buffer[bufCnt++] = '\n';
        } else if('\n' == ch){        // see if previous char was \r
            if(!ignoreNextNewline)  
                buffer[bufCnt++] = '\n';
            ignoreNextNewline = NO;
        } else if(BDIsNewlineCharacter(ch)){
            ignoreNextNewline = NO;
            buffer[bufCnt++] = '\n';
        } else { 
            ignoreNextNewline = NO;
            buffer[bufCnt++] = ch;
        }
    }
    
    retStr = CFStringCreateWithCharacters(allocator, buffer, bufCnt);
    if(buffer != stackBuffer) CFAllocatorDeallocate(allocator, buffer);
    return retStr;
}

static inline void
__BDDeleteCharactersInCharacterSet(CFMutableStringRef theString, CFCharacterSetRef charSet)
{    
    CFStringInlineBuffer inlineBuffer;
    CFIndex length = CFStringGetLength(theString);
    CFIndex cnt = 0;
    
    // create an immutable copy to use with the inline buffer
    CFStringRef myCopy = CFStringCreateCopy(kCFAllocatorDefault, theString);
    CFStringInitInlineBuffer(myCopy, &inlineBuffer, CFRangeMake(0, length));
    UniChar ch;
    
    CFIndex delCnt = 0;
    while(cnt < length){
        ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, cnt);
        if(CFCharacterSetIsCharacterMember(charSet, ch)){
            // remove from the mutable string; we have to keep track of our index in the copy and the original
            CFStringDelete(theString, CFRangeMake(delCnt, 1));
        } else {
            delCnt++;
        }
        cnt++;
    }
    CFRelease(myCopy); // dispose of our temporary copy
}

static inline void
__BDReplaceCharactersInCharacterSet(CFMutableStringRef theString, CFCharacterSetRef charSet, CFStringRef replacement)
{    
    CFStringInlineBuffer inlineBuffer;
    CFIndex length = CFStringGetLength(theString);
    CFIndex replacementLength = CFStringGetLength(replacement);
    CFIndex cnt = 0;
    
    // create an immutable copy to use with the inline buffer
    CFStringRef myCopy = CFStringCreateCopy(kCFAllocatorDefault, theString);
    CFStringInitInlineBuffer(myCopy, &inlineBuffer, CFRangeMake(0, length));
    UniChar ch;
    
    CFIndex delCnt = 0;
    while(cnt < length){
        ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, cnt);
        if(CFCharacterSetIsCharacterMember(charSet, ch)){
            // replace in the mutable string; we have to keep track of our index in the copy and the original
            CFStringReplace(theString, CFRangeMake(delCnt, 1), replacement);
            delCnt += replacementLength;
        } else {
            delCnt++;
        }
        cnt++;
    }
    CFRelease(myCopy); // dispose of our temporary copy
}

/* This is very similar to CFStringTrimWhitespace from CF-368.1.  It takes a buffer of unichars, and removes the whitespace characters from each end, then returns the contents in the original buffer (the pointer is unchanged).  The length returned is the new length, and the length passed is the buffer length. */
static inline CFIndex __BDCharactersTrimmingWhitespace(UniChar *chars, CFIndex length)
{
    CFIndex newStartIndex = 0;
    CFIndex buffer_idx = 0;
    
    while (buffer_idx < length && __BDCharacterIsWhitespace(chars[buffer_idx]))
        buffer_idx++;
    newStartIndex = buffer_idx;
    
    if (newStartIndex < length) {
        
        buffer_idx = length - 1;
        while (0 <= buffer_idx && __BDCharacterIsWhitespace(chars[buffer_idx]))
            buffer_idx--;
        length = buffer_idx - newStartIndex + 1;
        
        // @@ CFStringTrimWhitespace uses memmove(chars, chars + newStartIndex * sizeof(UniChar), length * sizeof(UniChar)), but that doesn't work in my testing here.
        memmove(chars, chars + newStartIndex, length * sizeof(UniChar));        
    } else {
        // whitespace only
        length = 0;
    }
    
    return length;
}

#pragma mark XML cleaning

// This code is mostly copied from OFXMLString

// Replace characters with basic entities
CFStringRef __BDXMLCreateStringWithEntityReferences(CFStringRef sourceString) {
    static CFCharacterSetRef entityCharacters = NULL;
    if (entityCharacters == nil) {
        // XML doesn't allow low ASCII characters.  See the 'Char' production in section 2.2 of the spec:
        //
        // Char := #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]	/* any Unicode character, excluding the surrogate blocks, FFFE, and FFFF. */
        CFMutableCharacterSetRef set = CFCharacterSetCreateMutable(kCFAllocatorDefault);
        CFCharacterSetAddCharactersInRange(set, (CFRange){0, 0x20});
        CFCharacterSetRemoveCharactersInRange(set, (CFRange){0x9, 1});
        CFCharacterSetRemoveCharactersInRange(set, (CFRange){0xA, 1});
        CFCharacterSetRemoveCharactersInRange(set, (CFRange){0xD, 1});
        
        // Additionally, XML uses a few special characters for elements, entities and quoting.  We'll write character entities for all of these (unless some quoting flags tell us differently)
        CFCharacterSetAddCharactersInString(set, CFSTR("&<>\"'\n"));
        
        entityCharacters = CFCharacterSetCreateCopy(kCFAllocatorDefault, set);
        CFRelease(set);
    }
    
    CFIndex charIndex, charCount = CFStringGetLength(sourceString);
    CFRange fullRange = (CFRange){0, charCount};

    // Early out check
    if (false == CFStringFindCharacterFromSet(sourceString, entityCharacters, fullRange, 0/*options*/, NULL)) {
        CFRetain(sourceString);
        return sourceString;
    }
    
    CFStringInlineBuffer charBuffer;
    CFStringInitInlineBuffer(sourceString, &charBuffer, fullRange);

    CFMutableStringRef result = CFStringCreateMutable(kCFAllocatorDefault, 0);

    for (charIndex = 0; charIndex < charCount; charIndex++) {
        unichar c = CFStringGetCharacterFromInlineBuffer(&charBuffer, charIndex);
        if (c == '&') {
            CFStringAppend(result, CFSTR("&amp;"));
        } else if (c == '<') {
            CFStringAppend(result, CFSTR("&lt;"));
        } else if (c == '>') {
            CFStringAppend(result, CFSTR("&gt;"));
        } else if (c == '\"') {
             CFStringAppend(result, CFSTR("&quot;"));
        } else if (c == '\'') {
             CFStringAppend(result, CFSTR("&apos;"));
        } else if (c == '\n') { // 0xA
            CFStringAppendCharacters(result, &c, 1);
        } else if (c == '\t' || c == '\r') { // 0x9 || 0xD
                CFStringAppendCharacters(result, &c, 1);
        } else if (CFCharacterSetIsCharacterMember(entityCharacters, c)) {
            // This is a low-ascii, non-whitespace byte and isn't allowed in XML character at all.  Drop it.
            BDSKASSERT(c < 0x20 && c != 0x9 && c != 0xA && c != 0xD);
        } else {
            CFStringAppendCharacters(result, &c, 1);
        }
    }

    return result;
}

CFIndex __BDIndexOfCharacterNotRepresentableInCFEncoding(CFStringRef string, CFStringEncoding anEncoding, CFRange scanningRange) {
    CFIndex usedBufLen;
    CFIndex thisBufferCharacters;
    CFIndex bufLen = 1024;  // warning: this routine will fail if any single character requires more than 1024 bytes to represent! (ha, ha)
    
    while (1) {
        if (scanningRange.length == 0)
            return NSNotFound;
            
        usedBufLen = 0;
        thisBufferCharacters = CFStringGetBytes(string, scanningRange, anEncoding, 0, FALSE, NULL, bufLen, &usedBufLen);
        if (thisBufferCharacters == 0)
            break;
        BDSKASSERT(thisBufferCharacters <= scanningRange.length);
        scanningRange.location += thisBufferCharacters;
        scanningRange.length -= thisBufferCharacters;
    }
    
    return scanningRange.location;
}

enum _BDSurrogate { BDNoSurrogate, BDHighSurrogate, BDLowSurrogate };

// The surrogate ranges are conveniently lined up on power-of-two boundaries.
// Since the common case is that a character is not a surrogate at all, we
// test for that first.
static inline enum _BDSurrogate BDCharacterIsSurrogate(unichar ch) {
    if ((ch & 0xF800) != 0xD800) return BDNoSurrogate;
    else if ((ch & 0x0400) == 0) return BDHighSurrogate;
    else return BDLowSurrogate;
}

/* Combines a high and a low surrogate character into a 21-bit Unicode character value */
static inline UnicodeScalarValue BDCharacterFromSurrogatePair(unichar high, unichar low) {
    return 0x10000 + ( ( (UnicodeScalarValue)(high & 0x3FF) << 10 ) | (UnicodeScalarValue)(low & 0x3FF) );
}

// Replace characters not representable in string encoding with numbered character references
CFStringRef __BDXMLCreateStringInCFEncoding(CFStringRef sourceString, CFStringEncoding anEncoding)
{
    CFMutableStringRef resultString;
    CFStringRef substring;
    CFIndex badIndex;
    CFRange scanningRange, range, composedRange;
    unichar *composedCharacter;
    CFIndex componentIndex;

    resultString = nil;

    scanningRange.location = 0;
    scanningRange.length = CFStringGetLength(sourceString);
    while (scanningRange.length > 0) {
        badIndex = __BDIndexOfCharacterNotRepresentableInCFEncoding(sourceString, anEncoding, scanningRange);
        if (badIndex == NSNotFound) {
            if (scanningRange.location == 0) {
                CFRetain(sourceString);
                return sourceString;  // Shortcut for common case
            } else if (!resultString)
                // Remainder of string has no characters needing quoting
                resultString = CFStringCreateMutable(kCFAllocatorDefault, 0);
            substring = CFStringCreateWithSubstring(kCFAllocatorDefault, sourceString, scanningRange);
            CFStringAppend(resultString, substring);
            CFRelease(substring);
            break;
        } else if (!resultString)
            // Some character of string needs quoting
            resultString = CFStringCreateMutable(kCFAllocatorDefault, 0);
        
        range.location = scanningRange.location;
        range.length = badIndex - range.location;
        if (range.length > 0) {
            substring = CFStringCreateWithSubstring(kCFAllocatorDefault, sourceString, range);
            CFStringAppend(resultString, substring);
            CFRelease(substring);
        }
        
        composedRange = CFStringGetRangeOfComposedCharactersAtIndex(sourceString, badIndex);
        composedCharacter = malloc(composedRange.length * sizeof(*composedCharacter));
        CFStringGetCharacters(sourceString, composedRange, composedCharacter);
        for (componentIndex = 0; componentIndex < composedRange.length; componentIndex++) {
            UnicodeScalarValue ch;  // this is a full 32-bit Unicode value

            if (BDCharacterIsSurrogate(composedCharacter[componentIndex]) == BDHighSurrogate &&
                (componentIndex + 1 < composedRange.length) &&
                BDCharacterIsSurrogate(composedCharacter[componentIndex+1]) == BDLowSurrogate) {
                ch = BDCharacterFromSurrogatePair(composedCharacter[componentIndex], composedCharacter[componentIndex+1]);
                componentIndex ++;
            } else {
                ch = composedCharacter[componentIndex];
            }

            CFStringAppendFormat(resultString, NULL, CFSTR("&#%u;"), ch);
        }
        free(composedCharacter);
        composedCharacter = NULL;
        scanningRange.location = composedRange.location + composedRange.length;
        scanningRange.length -= range.length + composedRange.length;
    }

    // (this point is not reached if no changes are necessary to the source string)
    // resultString can be nil if the input was zero length.  Returning [sourceString retain] would work too, but static strings can be sent -release w/o doing anything, so this is ever-so-slightly faster.
    return resultString ? resultString : CFSTR("");
}

#pragma mark API

// Copied from CFString.c (CF368.25) with the addition of a single parameter for specifying comparison options (e.g. case-insensitive).
CFArrayRef BDStringCreateArrayBySeparatingStringsWithOptions(CFAllocatorRef allocator, CFStringRef string, CFStringRef separatorString, CFOptionFlags compareOptions)
{
    CFArrayRef separatorRanges;
    CFIndex length = CFStringGetLength(string);

    if (!(separatorRanges = CFStringCreateArrayWithFindResults(allocator, string, separatorString, CFRangeMake(0, length), compareOptions))) {
        return CFArrayCreate(allocator, (const void**)&string, 1, & kCFTypeArrayCallBacks);
    } else {
        CFIndex idx;
        CFIndex count = CFArrayGetCount(separatorRanges);
        CFIndex startIndex = 0;
        CFIndex numChars;
        CFMutableArrayRef array = CFArrayCreateMutable(allocator, count + 2, & kCFTypeArrayCallBacks);
        const CFRange *currentRange;
        CFStringRef substring;
        
        for (idx = 0;idx < count;idx++) {
            currentRange = CFArrayGetValueAtIndex(separatorRanges, idx);
            numChars = currentRange->location - startIndex;
            substring = CFStringCreateWithSubstring(allocator, string, CFRangeMake(startIndex, numChars));
            CFArrayAppendValue(array, substring);
            CFRelease(substring);
            startIndex = currentRange->location + currentRange->length;
        }
        substring = CFStringCreateWithSubstring(allocator, string, CFRangeMake(startIndex, length - startIndex));
        CFArrayAppendValue(array, substring);
        CFRelease(substring);
        
        CFRelease(separatorRanges);
        
        return array;
    }
}

CFArrayRef BDStringCreateComponentsSeparatedByCharacterSetTrimWhitespace(CFAllocatorRef allocator, CFStringRef string, CFCharacterSetRef charSet, Boolean trim)
{
    
    CFIndex length = CFStringGetLength(string);
    CFStringInlineBuffer inlineBuffer;
    CFStringInitInlineBuffer(string, &inlineBuffer, CFRangeMake(0, length));
    
    if(allocator == NULL) allocator = CFAllocatorGetDefault();
    CFMutableArrayRef array = CFArrayCreateMutable(allocator, 0, &kCFTypeArrayCallBacks);
    CFIndex cnt;
    UniChar ch;
    
    // full length of string has to be large enough for the buffer
    UniChar *buffer, stackBuffer[STACK_BUFFER_SIZE];
    if(length >= STACK_BUFFER_SIZE) {
        buffer = (UniChar *)CFAllocatorAllocate(allocator, length * sizeof(UniChar), 0);
    } else {
        buffer = stackBuffer;
    }
    
    NSCAssert1(buffer != NULL, @"Unable to allocate buffer for %@", string);
    CFIndex bufCnt = 0;
    CFStringRef component;
    
    // scan characters into a buffer; when a character from the charSet is reached, stop and create a string
    for(cnt = 0; cnt < length; cnt++){
        ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, cnt);
        if(CFCharacterSetIsCharacterMember(charSet, ch) == FALSE){
            buffer[bufCnt++] = ch;
        } else {
            if(bufCnt){
                if(trim) bufCnt = __BDCharactersTrimmingWhitespace(buffer, bufCnt);
                component = CFStringCreateWithCharacters(allocator, buffer, bufCnt);
                CFArrayAppendValue(array, component);
                CFRelease(component);
                bufCnt = 0;
            }
        }
    }
    
    // get the final component from the buffer and create a string
    if(bufCnt){
        if(trim) bufCnt = __BDCharactersTrimmingWhitespace(buffer, bufCnt);
        component = CFStringCreateWithCharacters(allocator, buffer, (bufCnt));
        CFArrayAppendValue(array, component);
        CFRelease(component);
    }
    
    if(buffer != stackBuffer) CFAllocatorDeallocate(allocator, buffer);
    
    return array;
}

CFHashCode BDCaseInsensitiveStringHash(const void *value)
{
    if(value == NULL) return 0;
    
    CFAllocatorRef allocator = CFGetAllocator(value);
    CFIndex len = CFStringGetLength(value);
    
    // use a generous length, in case the lowercase changes the number of characters
    UniChar *buffer, stackBuffer[STACK_BUFFER_SIZE];
    if(len + 10 >= STACK_BUFFER_SIZE) {
        buffer = (UniChar *)CFAllocatorAllocate(allocator, (len + 10) * sizeof(UniChar), 0);
    } else {
        buffer = stackBuffer;
    }
    CFStringGetCharacters(value, CFRangeMake(0, len), buffer);
    
    // If we create the string with external characters, CFStringGetCharactersPtr is guaranteed to succeed; since we're going to call CFStringGetCharacters anyway in fastHash if CFStringGetCharactsPtr fails, let's do it now when we lowercase the string
    CFMutableStringRef mutableString = CFStringCreateMutableWithExternalCharactersNoCopy(allocator, buffer, len, len + 10, (buffer != stackBuffer ? allocator : kCFAllocatorNull));
    CFStringLowercase(mutableString, NULL);
    uint32_t hash = __BDFastHash(mutableString);
    
    // if we used the allocator, this should free the buffer for us
    CFRelease(mutableString);
    return hash;
}
    
CFStringRef BDStringCreateByCollapsingAndTrimmingCharactersInSet(CFAllocatorRef allocator, CFStringRef string, CFCharacterSetRef charSet){ return __BDStringCreateByCollapsingAndTrimmingCharactersInSet(allocator, string, charSet); }

CFStringRef BDStringCreateByNormalizingWhitespaceAndNewlines(CFAllocatorRef allocator, CFStringRef string){ return __BDStringCreateByNormalizingWhitespaceAndNewlines(allocator, string); }

// useful when you want the range of a single character without messing with character sets, or just to know if a character exists in a string (pass NULL for resultRange if you don't care where the result is located)
Boolean BDStringFindCharacter(CFStringRef string, UniChar character, CFRange searchRange, CFRange *resultRange)
{
    if(CFStringGetLength(string) == 0) return FALSE;
    CFStringInlineBuffer inlineBuffer;
    
    CFStringInitInlineBuffer(string, &inlineBuffer, searchRange);
    CFIndex cnt = 0;
    
    do {
        if(CFStringGetCharacterFromInlineBuffer(&inlineBuffer, cnt) == character){
            if(resultRange != NULL){
                resultRange->location = searchRange.location + cnt;
                resultRange->length = 1;
            }
            return TRUE;
        }
    } while(++cnt < searchRange.length);
    
    return FALSE;
}

Boolean BDIsNewlineCharacter(UniChar c)
{
    // minor optimization: check for an ASCII character, since those are most common in TeX
    return ( (c <= 0x007E && c >= 0x0021) ? NO : CFCharacterSetIsCharacterMember((CFCharacterSetRef)[NSCharacterSet newlineCharacterSet], c) );
}

Boolean BDStringHasAccentedCharacters(CFStringRef string)
{
    CFMutableStringRef mutableString = CFStringCreateMutableCopy(CFGetAllocator(string), CFStringGetLength(string), string);
    CFStringNormalize(mutableString, kCFStringNormalizationFormD);
    Boolean success = CFStringFindCharacterFromSet(mutableString, CFCharacterSetGetPredefined(kCFCharacterSetNonBase), CFRangeMake(0, CFStringGetLength(mutableString)), 0, NULL);
    CFRelease(mutableString);
    return success;
}

// 1. Replace characters with basic entities
// 2. Replace characters not representable in string encoding with numbered character references
CFStringRef BDXMLCreateStringWithEntityReferencesInCFEncoding(CFStringRef string, CFStringEncoding encoding) {
    CFStringRef tmpString = __BDXMLCreateStringWithEntityReferences(string);
    BDSKASSERT(tmpString);
    CFStringRef result = __BDXMLCreateStringInCFEncoding(tmpString, encoding);
    CFRelease(tmpString);
    return result;
}

#pragma mark Mutable Strings

void BDDeleteTeXForSorting(CFMutableStringRef mutableString){ 
    __BDDeleteTeXCommandsForSorting(mutableString); 
    // get rid of braces and such...
    __BDDeleteTeXCharactersForSorting(mutableString);
}

void BDDeleteArticlesForSorting(CFMutableStringRef mutableString){ __BDDeleteArticlesForSorting(mutableString); }

void BDDeleteCharactersInCharacterSet(CFMutableStringRef mutableString, CFCharacterSetRef charSet){
    __BDDeleteCharactersInCharacterSet(mutableString, charSet);
}

void BDReplaceCharactersInCharacterSet(CFMutableStringRef mutableString, CFCharacterSetRef charSet, CFStringRef replacement){
    __BDReplaceCharactersInCharacterSet(mutableString, charSet, replacement);
}

CFStringRef BDCreateUniqueString() {
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef uuidStr = CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);
    return uuidStr;
}


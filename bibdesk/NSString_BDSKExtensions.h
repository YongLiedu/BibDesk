//  NSString_BDSKExtensions.h

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

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

@interface NSString (BDSKExtensions)

+ (BOOL)isEmptyString:(NSString *)string;

+ (NSString *)horizontalEllipsisString; // '...'
+ (NSString *)emdashString; // '---'
+ (NSString *)endashString; // '--'
+ (NSString *)commandKeyIndicatorString;
+ (NSString *)controlKeyIndicatorString;
+ (NSString *)alternateKeyIndicatorString;
+ (NSString *)shiftKeyIndicatorString;

/*!
    @method     hexStringForCharacter:
    @abstract   Returns the hex value of a unichar (useful for lookups in the character palette)
    @discussion (comprehensive description)
    @param      ch (description)
    @result     (description)
*/
+ (NSString *)hexStringForCharacter:(unichar)ch;

/*!
    @method     ratingStringWithInteger:
    @abstract   Returns a sequence of digits as bubbles surrounding each character
    @discussion Requires a font with characters 0x278A-278E
    @param      rating (description)
    @result     (description)
*/
+ (NSString *)ratingStringWithInteger:(NSInteger)rating;

/*!
 @method     stringWithBool:
 @abstract   Returns a localized string describing the boolean value. 
 @discussion (comprehensive description)
 @param      boolValue The value of the boolean.
 @result     (description)
 */
+ (NSString *)stringWithBool:(BOOL)boolValue;

/*!
    @method     stringWithFileSystemRepresentation:
    @abstract   More convenient than using NSFileManager, and thread safe.  Calls CFStringCreateWithFileSystemRepresentation.
    @discussion Returns nil if the encoding was incorrect.
    @param      cString NULL-terminated C string
    @result     (description)
*/
+ (NSString *)stringWithFileSystemRepresentation:(const char *)cString;

/*!
@method     stringWithTriStateValue:
 @abstract   Returns a localized string describing the value as one of {NO, YES, -}
 @discussion (comprehensive description)
 @param      triStateValue The value of the checkBox.
 @result     (description)
 */
+ (NSString *)stringWithTriStateValue:(NSCellStateValue)triStateValue;

/*!
    @method     stringWithContentsOfFile:encoding:guessEncoding:
    @abstract   Tries to load a file with the specified encoding; if guessEncoding is set to YES, it will employ some heuristics to guess the encoding if the specified encoding fails or is set to 0.
    @discussion (comprehensive description)
    @param      path (description)
    @param      encoding (description)
    @param      try (description)
    @result     (description)
*/
+ (NSString *)stringWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)encoding guessEncoding:(BOOL)try;

    /*!
    @method     unicodeNameOfCharacter:
     @abstract   Returns the unicode name of a character via CFStringTransform.
     @discussion (comprehensive description)
     @param      ch (description)
     @result     (description)
     */
+ (NSString *)unicodeNameOfCharacter:(unichar)ch;

/*!
    @method     IANACharSetNameForEncoding:
    @abstract   See http://www.iana.org/assignments/character-sets.  Returns nil if conversion failed.
    @discussion (comprehensive description)
    @param      enc (description)
    @result     (description)
*/
+ (NSString *)IANACharSetNameForEncoding:(NSStringEncoding)enc;

/*!
    @method     encodingForIANACharSetName:
    @abstract   Name is in the list at http://www.iana.org/assignments/character-sets.  Returns 0 if conversion failed.
    @discussion (comprehensive description)
    @param      name
*/
+ (NSStringEncoding)encodingForIANACharSetName:(NSString *)name;
    
/*!
    @method     initWithContentsOfFile:encoding:guessEncoding:
    @abstract   Tries to load a file with the specified encoding; if guessEncoding is set to YES, it will employ some heuristics to guess the encoding if the specified encoding fails or is set to 0.
    @discussion (comprehensive description)
    @param      path (description)
    @param      encoding (description)
    @param      try (description)
    @result     (description)
*/
- (NSString *)initWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)encoding guessEncoding:(BOOL)try;

#pragma mark TeX cleaning

/*!
    @method     stringByConvertingDoubleHyphenToEndash
    @abstract   Converts "--" to en dash.  See http://en.wikipedia.org/wiki/Dash for info on dashes.
    @discussion (comprehensive description)
    @result     (description)
*/
- (NSString *)stringByConvertingDoubleHyphenToEndash;

/*!
    @method     stringByConvertingTripleHyphenToEmdash
    @abstract   Converts "---" to em dash.  See http://en.wikipedia.org/wiki/Dash for info on dashes.
    @discussion (comprehensive description)
    @result     (description)
*/
- (NSString *)stringByConvertingTripleHyphenToEmdash;

/*!
    @method     stringByConvertingHyphensToDashes
    @abstract   Converts "---" to em dash and "--" to en dash.  See http://en.wikipedia.org/wiki/Dash for info on dashes.
    @discussion (comprehensive description)
    @result     (description)
*/
- (NSString *)stringByConvertingHyphensToDashes;

    /*!
    @method     stringByRemovingCurlyBraces
     @abstract   Removes curly braces from a string
     @discussion Used for searching; removes curly braces from search results, so that a search for "Kynch theory" works even if the title has "{K}ynch theory"
     @result     (description)
     */
- (NSString *)stringByRemovingCurlyBraces;

/*!
 @method     stringByRemovingTeX
 @abstract   Removes TeX commands and curly braces from the receiver.
 @discussion May return a different instance.  A TeX command is considered to match a regex of the form "\\[a-z].+\{", with the AGRegexLazy option.
 @result     (description)
 */
- (NSString *)stringByRemovingTeX;

#pragma mark TeX parsing

/*!
    @method     entryType
    @abstract   Wrapper around lowercaseString for BibTeX types, caching values.  Note that lowercasing is an implementation detail, and this allows us to change at any time.
    @discussion (comprehensive description)
    @result     (description)
*/
- (NSString *)entryType;

/*!
    @method     fieldName
    @abstract   Wrapper around capitalizedString that caches them for use as BibTeX fields.  Note that capitalizing is an implementation detail, and this allows us to change at any time.
    @discussion (comprehensive description)
    @result     (description)
*/
- (NSString *)fieldName;
    
/*!
    @method     localizedFieldName
    @abstract   Returns the localized field name used for display.
    @discussion (comprehensive description)
    @result     (description)
*/
- (NSString *)localizedFieldName;

/*!
@method     indexOfRightBraceMatchingLeftBraceInRange:
@abstract   Counts curly braces from left-to-right, in order to find a match for a left brace <tt>{</tt>.
@discussion Raises an exception if the character at <tt>startLoc</tt> is not a brace, and escaped braces are not (yet?) considered.
An inline buffer is used for speed in accessing each character.
@param      range The range to search for matching braces, the first character should be the left brace.
@result     The index of the matching brace character.
*/
- (NSUInteger)indexOfRightBraceMatchingLeftBraceInRange:(NSRange)range;

- (NSUInteger)indexOfRightBraceMatchingLeftBraceAtIndex:(NSUInteger)startLoc;
    
    /*!
    @method     isStringTeXQuotingBalancedWithBraces:connected:
    @abstract   Invoces isStringTeXQuotingBalancedWithBraces:connected:range: with the full range of the receiver. 
    @discussion (discussion)
    @result     (description)
*/
- (BOOL)isStringTeXQuotingBalancedWithBraces:(BOOL)braces connected:(BOOL)connected;

/*!
    @method     isStringTeXQuotingBalancedWithBraces:connected:range:
    @abstract   Checks if the receiver has balanced braces or doublequotes in range. 
    @discussion Used in parsing a bibtex string to see if a substring has balanced quotes. Ignores TeX-escaped delimiters, and checks for correct order of delimiters. 
    @param      braces Boolean, determines whether to use braces (or double-quotes) for quoting. 
    @param      connected Boolean, determines whether curly braces have to quote a connected range. 
    @param      range The range of the receiver in which to check for balanced braces.
    @result     Boolean
*/
- (BOOL)isStringTeXQuotingBalancedWithBraces:(BOOL)braces connected:(BOOL)connected range:(NSRange)range;

- (BOOL)isStringTeXQuotingBalancedWithBraces:(BOOL)braces connected:(BOOL)connected range:(NSRange)range;

/*!
@method     rangeOfTeXCommandInRange:
@abstract   Returns the range of a TeX command, considered simplistically as <tt>\command</tt> followed by a space or curly brace.
@discussion (comprehensive description)
@param      searchRange (description)
@result     (description)
*/
- (NSRange)rangeOfTeXCommandInRange:(NSRange)searchRange;

/*!
@method     stringWithPhoneyCiteKeys:
@abstract   Adds temporary cite keys to the string, which should be a BibTeX string without citekeys.  uses code from openWithPhoneyKeys
@discussion (comprehensive description)
@param      tmpKey (description)
@result     Returns an altered NSString
*/
- (NSString *)stringWithPhoneyCiteKeys:(NSString *)tmpKey;

/*!
    @method     stringByBackslashEscapingTeXSpecials
    @abstract   Adds backslash escapes (if needed) for a few characters.
    @discussion Mainly to escape characters that commonly appear in titles or journal names when importing from z39.50 and other non-RIS/non-BibTeX search group sources, since those aren't processed by the HTML->TeX path that's used for RIS.
    @result     The escaped string.
*/
- (NSString *)stringByBackslashEscapingTeXSpecials;
- (NSString *)stringByBackslashEscapingCharactersInSet:(NSCharacterSet *)charSet;

- (NSString *)stringByConvertingHTMLToTeX;
+ (NSString *)TeXStringWithHTMLString:(NSString *)htmlString;

- (NSArray *)sourceLinesBySplittingString;

- (NSString *)stringByEscapingGroupPlistEntities;
- (NSString *)stringByUnescapingGroupPlistEntities;

- (NSString *)lossyASCIIString;

#pragma mark Comparisons

/*!
@method     localizedCaseInsensitiveNumericCompare:
@abstract   Returns a case insensitve, numeric comparison in the user's default locale.
@discussion (comprehensive description)
@param      aStr (description)
@result     (description)
*/
- (NSComparisonResult)localizedCaseInsensitiveNumericCompare:(NSString *)aStr;
    
/*!
@method     caseInsensitiveNonTeXCompare:
@abstract   (brief description)
@discussion (comprehensive description)
@param      otherString (description)
@result     (description)
*/
- (NSComparisonResult)localizedCaseInsensitiveNonTeXNonArticleCompare:(NSString *)otherString;

/*!
@method     numericCompare:
@abstract   Compares strings as numbers, using NSNumericSearch
@discussion (comprehensive description)
@param      otherString (description)
@result     (description)
*/
- (NSComparisonResult)numericCompare:(NSString *)otherString;

/*!
    @method     sortCompare:
    @abstract   For sorting collections containing empty strings, which are handled in reverse order from compare:
    @discussion (comprehensive description)
    @param      other (description)
    @result     (description)
*/
- (NSComparisonResult)sortCompare:(NSString *)other;

- (NSComparisonResult)extensionCompare:(NSString *)other;

/*!
    @method     triStateCompare:
    @abstract   For sorting triState string values
    @discussion (comprehensive description)
    @param      other (description)
    @result     (description)
*/
- (NSComparisonResult)triStateCompare:(NSString *)other;

/*!
    @method     UTICompare:
    @abstract   Compares the UTI of two files on disk case-insensitively.  
    @discussion The receiver and/or argument may be an absolute or relative path, or string representation of a URL.  If a file is a relative path, the UTI from its path extension is used.  Aliases are resolved in this comparison, so it may be slow.
    @param      other (description)
    @result     (description)
*/
- (NSComparisonResult)UTICompare:(NSString *)other;

/*!
    @method     UTICompare:basePath:
    @abstract   Compares the UTI of two files on disk case-insensitively.  
    @discussion The receiver and/or argument may be an absolute or relative path, or string representation of a URL.  If a file is a relative path, it is completed using basePath. If a file is a relative path and basePath is nil, the UTI from its path extension is used.  Aliases are resolved in this comparison, so it may be slow.
    @param      other (description)
    @param      basePath (description)
    @result     (description)
*/
- (NSComparisonResult)UTICompare:(NSString *)other basePath:(NSString *)basePath;

#pragma mark -

/*!
@method     booleanValue
@abstract   Compares with Yes, y, or 1 using case insensitive search to return YES.
@discussion (comprehensive description)
@result     (description)
*/
- (BOOL)booleanValue;

/*!
     @method     triStateValue
     @abstract   Translates from string value to an NSCellStateValue
     @discussion For compatibility with booleanValue, we accept {Yes,y,1} = checked and {No,n,0,""} = unchecked. Anything else is treated as indeterminate, or "mixed".
     @result     (description)
 */
- (NSCellStateValue)triStateValue;

- (NSString *)acronymValueIgnoringWordLength:(NSUInteger)ignoreLength;

#pragma mark -

/*!
    @method     componentsSeparatedByCharactersInSet:trimWhitespace:
    @abstract   Returns an array composed by splitting the string at any of the characters in charSet, optionally trimming whitespace from each component.
    @discussion (comprehensive description)
    @param      charSet (description)
    @param      trim (description)
    @result     (description)
*/
- (NSArray *)componentsSeparatedByCharactersInSet:(NSCharacterSet *)charSet trimWhitespace:(BOOL)trim;

/*!
    @method     componentsSeparatedByStringCaseInsensitive:
    @abstract   Same as componentsSeparatedByString:, but uses case-insensitive comparison
    @discussion (comprehensive description)
    @param      separator (description)
    @result     (description)
*/

- (NSArray *)componentsSeparatedByStringCaseInsensitive:(NSString *)separator;
- (NSArray *)componentsSeparatedByAnd;
- (NSArray *)componentsSeparatedByComma;

- (NSArray *)componentsSeparatedByFieldSeparators;

/*!
@method     containsWord:
@abstract   Determine whether a string contains the argument aWord; if it contains aWord as a substring, it then tests to see if it is bounded by null, punctuation, or whitespace.
@discussion (comprehensive description)
@param      aWord (description)
@result     (description)
*/
- (BOOL)containsWord:(NSString *)aWord;

- (NSString *)stringByCollapsingAndTrimmingCharactersInSet:(NSCharacterSet *)charSet;

- (BOOL)hasCaseInsensitivePrefix:(NSString *)prefix;

/*!
    @method     stringByNormalizingSpacesAndLineBreaks
    @abstract   Converts all whitespace characters to a single space, and all newline characters to a \n
    @discussion (comprehensive description)
    @result     (description)
*/
- (NSString *)stringByNormalizingSpacesAndLineBreaks;

/*!
@method     stringByTrimmingFromLastPunctuation
@abstract   Returns the portion of a string following the last punctuation character.
@discussion (comprehensive description)
@result     (description)
*/
- (NSString *)stringByTrimmingFromLastPunctuation;

/*!
    @method     stringByTrimmingPrefixCharactersFromSet:
    @abstract   Trims leading characters in characterSet from the string.
    @discussion (comprehensive description)
    @param      characterSet (description)
    @result     (description)
*/
- (NSString *)stringByTrimmingPrefixCharactersFromSet:(NSCharacterSet *)characterSet;

- (NSString *)stringByAppendingEllipsis;

/*!
    @method     titlecaseString
    @abstract   Converts string to -capitalizedString, then selectively transforms certain words to lowercase.
    @discussion Words are whitespace-delimited, similar to -capitalizedString, but not necessarily identical.
    @result     (description)
*/
- (NSString *)titlecaseString;

- (NSString *)stringByDeletingCharactersInSet:(NSCharacterSet *)removeSet;
- (NSString *)stringByReplacingCharactersInSet:(NSCharacterSet *)set withString:(NSString *)replaceString;

- (NSString *)stringByRemovingWhitespace;
- (NSString *)stringByRemovingReturns;

- (NSString *)stringByRemovingString:(NSString *)removeString;

- (NSString *)stringByRemovingPrefix:(NSString *)prefix;
- (NSString *)stringByRemovingSuffix:(NSString *)suffix;

- (NSString *)stringByRemovingSurroundingWhitespace;
- (NSString *)stringByCollapsingWhitespaceAndRemovingSurroundingWhitespace;
- (NSString *)stringByRemovingSurroundingWhitespaceAndNewlines;

- (NSString *)fullyEncodeAsIURI;

+ (NSString *)pathSeparator;
- (NSString *)commonRootPathOfFile:(NSString *)filename;
- (NSString *)relativePathFromPath:(NSString *)basePath;
- (NSString *)stringByNormalizingPath;

#pragma mark HTML/XML

- (NSString *)stringByConvertingHTMLLineBreaks;
- (NSString *)stringByEscapingBasicXMLEntitiesUsingUTF8;
- (NSString *)htmlString;
- (NSString *)xmlString;

- (NSString *)csvString;
- (NSString *)tsvString;

#pragma mark Script arguments

- (NSArray *)shellScriptArgumentsArray;
- (NSArray *)appleScriptArgumentsArray;

#pragma mark Some convenience keys for templates

- (NSURL *)url;
- (NSAttributedString *)linkedText;
- (NSAttributedString *)icon;
- (NSAttributedString *)smallIcon;
- (NSAttributedString *)linkedIcon;
- (NSAttributedString *)linkedSmallIcon;
- (NSArray *)SkimNotes;
- (NSString *)textSkimNotes;
- (NSAttributedString *)richTextSkimNotes;

- (NSString *)titleCapitalizedString;

- (NSString *)firstLetter;

- (NSString *)stringByAddingPercentEscapesIncludingReserved;
- (NSString *)stringByAddingPercentEscapes;
- (NSString *)stringByReplacingPercentEscapes;

- (unichar)firstCharacter;
- (unichar)lastCharacter;
- (NSString *)lowercaseFirst;
- (NSString *)uppercaseFirst;

@end

@interface NSMutableString (BDSKExtensions)

- (BOOL)isMutableString;
- (void)deleteCharactersInCharacterSet:(NSCharacterSet *)characterSet;
- (void)replaceOccurrencesOfCharactersInSet:(NSCharacterSet *)set withString:(NSString *)replaceString;
- (void)appendStrings:(NSString *)first, ...;
- (void)backslashEscapeCharactersInSet:(NSCharacterSet *)charSet;

@end

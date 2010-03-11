//
//  BDSKBibTeXParser.m
//  BibDesk
//
//  Created by Michael McCracken on Thu Nov 28 2002.
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

#import "BDSKBibTeXParser.h"
#import <BTParse/btparse.h>
#import <BTParse/BDSKErrorObject.h>
#import <AGRegex/AGRegex.h>
#import "BDSKAppController.h"
#include <stdio.h>
#import "BibItem.h"
#import "BDSKConverter.h"
#import "BDSKComplexString.h"
#import "BDSKStringConstants.h"
#import "BibDocument_Groups.h"
#import "NSString_BDSKExtensions.h"
#import "BibAuthor.h"
#import "BDSKErrorObjectController.h"
#import "BDSKStringNode.h"
#import "BDSKMacroResolver.h"
#import "BDSKOwnerProtocol.h"
#import "BDSKGroupsArray.h"
#import "BDSKStringEncodingManager.h"
#import "NSScanner_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import "BDSKCompletionManager.h"
#import "NSData_BDSKExtensions.h"
#import "CFString_BDSKExtensions.h"

static NSLock *parserLock = nil;

@interface BDSKBibTeXParser (Private)

// private function to check the string for encoding.
static inline BOOL checkStringForEncoding(NSString *s, NSInteger line, NSString *filePath, NSStringEncoding parserEncoding);
// private function to do create a string from a c-string with encoding checking.
static inline NSString *copyCheckedString(const char *cstring, NSInteger line, NSString *filePath, NSStringEncoding parserEncoding);

// private function to get array value from field:
// "foo" # macro # {string} # 19
static NSString *copyStringFromBTField(AST *field, NSString *filePath, BDSKMacroResolver *macroResolver, NSStringEncoding parserEncoding);

// private functions for handling different entry types; these functions do not do any locking around the parser
static BOOL appendPreambleToFrontmatter(AST *entry, NSMutableString *frontMatter, NSString *filePath, NSStringEncoding encoding);
static BOOL addMacroToResolver(AST *entry, BDSKMacroResolver *macroResolver, NSString *filePath, NSStringEncoding encoding, NSError **error);
static BOOL appendCommentToFrontmatterOrAddGroups(AST *entry, NSMutableString *frontMatter, NSString *filePath, BibDocument *document, NSStringEncoding encoding);

// private function for preserving newlines in annote/abstract fields; does not lock the parser
static NSString *copyStringFromNoteField(AST *field, const char *data, NSUInteger inputDataLength, NSString *filePath, NSStringEncoding encoding, NSString **error);

// parses an individual entry and adds it's field/value pairs to the dictionary
static BOOL addValuesFromEntryToDictionary(AST *entry, NSMutableDictionary *dictionary, const char *buf, NSUInteger inputDataLength, BDSKMacroResolver *macroResolver, NSString *filePath, NSStringEncoding parserEncoding);

@end

@implementation BDSKBibTeXParser

+ (void)initialize{
    BDSKINITIALIZE;
    parserLock = [[NSLock alloc] init];
}

static NSString *stringWithoutComments(NSString *string) {
    NSScanner *scanner = [NSScanner scannerWithString:string];
    while ([scanner isAtEnd] == NO) {
        if ([scanner scanString:@"%" intoString:NULL]) {
            [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:NULL];
        } else {
            [scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:NULL];
        }
        if (NO == [scanner scanCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:NULL])
            break;
    }
    if ([scanner isAtEnd])
        return @"";
    NSUInteger start = [scanner scanLocation];
    return start == 0 ? string : [string substringFromIndex:[scanner scanLocation]];
}

+ (BOOL)canParseString:(NSString *)string{
    
    /* This regex needs to handle the following, for example:
     
     @Article{
     citeKey ,
     Author = {Some One}}
     
     The cite key regex is from Maarten Sneep on the TextMate mailing list.  Spaces and linebreaks must be fixed first.
     
     */
    
    
    AGRegex *btRegex = [[AGRegex alloc] initWithPattern:/* type of item */ @"^@[[:alpha:]]+[ \\t]*[{(]" 
                                                        /* spaces       */ @"[ \\n\\r\\t]*" 
                                                        /* cite key     */ @"[a-zA-Z0-9\\.,:/*!&$^_-]+?" 
                                                        /* spaces       */ @"[ \\n\\r\\t]*," 
                                                options:AGRegexMultiline];
    
    // AGRegex doesn't recognize \r as a $ (bug #1420791), but normalizing is slow; use \r\n in regex instead
    BOOL found = ([btRegex findInString:stringWithoutComments(string)] != nil);
    [btRegex release];
    return found;
}

+ (BOOL)canParseStringAfterFixingKeys:(NSString *)string{
	// ^(@[[:alpha:]]+{),?$ will grab either "@type{,eol" or "@type{eol", which is what we get from Bookends and EndNote, respectively.
    // same regex used in -[NSString stringWithPhoneyCiteKeys:]
	AGRegex *theRegex = [[AGRegex alloc]  initWithPattern:@"^@[[:alpha:]]+[ \\t]*{[ \\t]*,?$" options:AGRegexMultiline];
    BOOL found = ([theRegex findInString:stringWithoutComments(string)] != nil);
    [theRegex release];
				
    return found;
}

/// libbtparse methods
+ (NSArray *)itemsFromString:(NSString *)aString owner:(id<BDSKOwner>)anOwner isPartialData:(BOOL *)isPartialData
error:(NSError **)outError{
    NSData *inData = [aString dataUsingEncoding:NSUTF8StringEncoding];
    return [self itemsFromData:inData frontMatter:nil filePath:BDSKParserPasteDragString owner:anOwner encoding:NSUTF8StringEncoding isPartialData:isPartialData error:outError];
}

+ (NSArray *)itemsFromData:(NSData *)inData frontMatter:(NSMutableString *)frontMatter filePath:(NSString *)filePath owner:(id<BDSKOwner>)anOwner encoding:(NSStringEncoding)parserEncoding isPartialData:(BOOL *)isPartialData error:(NSError **)outError{
    
    NSUInteger inputDataLength = [inData length];
    
    // btparse will crash if we pass it a zero-length data, so we'll return here for empty files
    if (isPartialData)
        *isPartialData = NO;
    
    if (inputDataLength == 0)
        return [NSArray array];
    
    [[BDSKErrorObjectController sharedErrorObjectController] startObservingErrors];
    
    // btparse chokes on classic Macintosh line endings, so we'll replace all returns with a newline; this takes < 0.01 seconds on a 1000+ item file with Unix line endings, so performance is not affected.  Windows line endings will be replaced by a single newline.
    NSMutableData *fixedData = [[inData mutableCopy] autorelease];
    NSUInteger currIndex, nextIndex;
    NSRange replaceRange;
    const char lf[1] = {'\n'};
    unsigned char *bytePtr = [fixedData mutableBytes];
    unsigned char ch;
    BOOL didReplaceNewlines = NO;
    
    for (currIndex = 0; currIndex < inputDataLength; currIndex++) {
        
        ch = bytePtr[currIndex];
        
        if (ch == '\r') {
            
            replaceRange.location = currIndex;
            // check the next char to see if we have a Windows line ending
            nextIndex = currIndex + 1;
            if (inputDataLength > nextIndex && bytePtr[nextIndex] == '\n') 
                replaceRange.length = 2;
            else
                replaceRange.length = 1;
        
            [fixedData replaceBytesInRange:replaceRange withBytes:lf length:1];
            inputDataLength -= replaceRange.length - 1;
            didReplaceNewlines = YES;
        }
    }
    // If we replace any characters, swap data, or else the parser will still choke on it (in the case of Mac line ends).
    // Error reporting should not be affected, because old and new line endings correspond exactly.
    if (didReplaceNewlines)
        inData = fixedData;
	
    BibItem *newBI = nil;
    BibDocument *document = [anOwner isDocument] ? (BibDocument *)anOwner : nil;
    BDSKMacroResolver *macroResolver = [anOwner macroResolver];	
    
    AST *entry = NULL;
    NSString *entryType = nil;
    NSMutableArray *returnArray = [NSMutableArray arrayWithCapacity:100];
    
    const char *buf = NULL;

    //dictionary is the bibtex entry
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:6];
    
    const char * fs_path = NULL;
    FILE *infile = NULL;
    BOOL isPasteOrDrag = [filePath isEqualToString:BDSKParserPasteDragString];
    
    
    NSError *error = nil;
    
    if (isPasteOrDrag || [[NSFileManager defaultManager] fileExistsAtPath:filePath] == NO) {
        fs_path = NULL; // used for error context in libbtparse
        infile = [inData openReadStream];
    } else {
        fs_path = [[NSFileManager defaultManager] fileSystemRepresentationWithPath:filePath];
        infile = didReplaceNewlines ? [inData openReadStream] : fopen(fs_path, "r");
    }

    buf = (const char *) [inData bytes];

    if([parserLock tryLock] == NO)
        [NSException raise:NSInternalInconsistencyException format:@"Attempt to reenter the parser.  Please report this error."];
    
    bt_initialize();
    bt_set_stringopts(BTE_PREAMBLE, BTO_EXPAND);
    bt_set_stringopts(BTE_MACRODEF, BTO_MINIMAL);
    // Passing BTO_COLLAPSE causes problems.  The comments on bt_postprocess_value indicate that BibTeX-style collapsing must take place /after/ pasting, but we do this with BDSKComplexString instead of BTO_PASTE.  See bug #1803091 for an example, although that case could be avoided by having bt_postprocess_string consider a single space " " as collapsed instead of deleting it.
    bt_set_stringopts(BTE_REGULAR, BTO_MINIMAL);
    
    NSString *tmpStr = nil;
    BOOL hadProblems = NO;
    BOOL ignoredMacros = NO;
    BOOL ignoredFrontmatter = NO;
    int parsed_ok = 1;

    while(entry =  bt_parse_entry(infile, (char *)fs_path, 0, &parsed_ok)){

        if (parsed_ok) {
            
            bt_metatype metatype = bt_entry_metatype (entry);
            if (metatype != BTE_REGULAR) {
                
                if (nil != frontMatter) {
                
                    // put @preamble etc. into the frontmatter string so we carry them along.
                    // without frontMatter, e.g. with paste or drag, we eventually ignore these entries (except macros)
                    if (BTE_PREAMBLE == metatype){
                        if(NO == appendPreambleToFrontmatter(entry, frontMatter, filePath, parserEncoding))
                            hadProblems = YES;
                    }else if(BTE_MACRODEF == metatype){
                        if(NO == addMacroToResolver(entry, macroResolver, filePath, parserEncoding, &error))
                            hadProblems = YES;
                    }else if(BTE_COMMENT == metatype && document){
                        if(NO == appendCommentToFrontmatterOrAddGroups(entry, frontMatter, filePath, document, parserEncoding))
                            hadProblems = YES;
                    }
                } else if (BTE_MACRODEF == metatype) {
                    ignoredMacros = YES;
                } else {
                    ignoredFrontmatter = YES;
                }
                    
                
            } else {
                
                // regular type (@article, @proceedings, etc.)
                // don't skip the loop if this fails, since it'll have partial data in the dictionary
                if (NO == addValuesFromEntryToDictionary(entry, dictionary, buf, inputDataLength, macroResolver, filePath, parserEncoding))
                    hadProblems = YES;
                
                // get the entry type as a string
                tmpStr = copyCheckedString(bt_entry_type(entry), entry->line, filePath, parserEncoding);
                entryType = [tmpStr entryType];
                [tmpStr release];
                
                if ([entryType isEqualToString:@"bibdesk_info"]) {
                    if(nil != frontMatter)
                        [document setDocumentInfoWithoutUndo:dictionary];
                } else if (entryType) {
                    
                    NSString *citeKey = copyCheckedString(bt_entry_key(entry), entry->line, filePath, parserEncoding);
                    
                    if(citeKey) {
                        [[BDSKCompletionManager sharedManager] addString:citeKey forCompletionEntry:BDSKCrossrefString];
                        
                        newBI = [[BibItem alloc] initWithType:entryType
                                                      citeKey:citeKey
                                                    pubFields:dictionary
                                                        isNew:isPasteOrDrag];
                        // we set the macroResolver so we know the fields were parsed with this macroResolver, mostly to prevent scripting to add the item to the wrong document
                        [newBI setMacroResolver:macroResolver];
                        
                        [citeKey release];
                        
                        [returnArray addObject:newBI];
                        [newBI release];
                    } else {
                        // no citekey
                        hadProblems = YES;
                        [BDSKErrorObject reportError:NSLocalizedString(@"Missing citekey for entry (skipped entry)", @"Error description") forFile:filePath line:entry->line];
                    }
                    
                } else {
                    // no entry type
                    hadProblems = YES;
                    [BDSKErrorObject reportError:NSLocalizedString(@"Missing entry type (skipped entry)", @"Error description") forFile:filePath line:entry->line];
                }
                
                [dictionary removeAllObjects];
            } // end generate BibItem from ENTRY metatype.
        } else {
            // wasn't ok, record it and deal with it later.
            hadProblems = YES;
        }
        bt_free_ast(entry);

    } // while (scanning through file) 
        
    // generic error message; the error tableview will have specific errors and context
    if(parsed_ok == 0 || hadProblems){
        error = [NSError localErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Unable to parse string as BibTeX", @"Error description") underlyingError:error];
        
    // If no critical errors, warn about ignoring macros or frontmatter; callers can ignore this by passing a valid NSMutableString for frontmatter (or ignoring the partial data flag).  Mainly relevant for paste/drag on the document.
    } else if (ignoredMacros && ignoredFrontmatter) {
        error = [NSError mutableLocalErrorWithCode:kBDSKParserIgnoredFrontMatter localizedDescription:NSLocalizedString(@"Macros and front matter ignored while parsing BibTeX", @"")];
        [error setValue:NSLocalizedString(@"Frontmatter (preamble and comments) from pasted data should be added via a text editor, and macros should be added via the macro editor (cmd-shift-M)", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
        hadProblems = YES;
    } else if (ignoredMacros) {
        error = [NSError mutableLocalErrorWithCode:kBDSKParserIgnoredFrontMatter localizedDescription:NSLocalizedString(@"Macros ignored while parsing BibTeX", @"")];
        [error setValue:NSLocalizedString(@"Macros must be added via the macro editor (cmd-shift-M)", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
        hadProblems = YES;
    } else if (ignoredFrontmatter) {
        error = [NSError mutableLocalErrorWithCode:kBDSKParserIgnoredFrontMatter localizedDescription:NSLocalizedString(@"Macros ignored while parsing BibTeX", @"")];
        [error setValue:NSLocalizedString(@"Frontmatter from pasted data should be added via a text editor", @"") forKey:NSLocalizedRecoverySuggestionErrorKey];
        hadProblems = YES;
    }

    // execute this regardless, so the parser isn't left in an inconsistent state
    bt_cleanup();
    fclose(infile);
    
    if(outError) *outError = error;
    [parserLock unlock];
    
    if (isPartialData)
        *isPartialData = hadProblems;
	
    [[BDSKErrorObjectController sharedErrorObjectController] endObservingErrorsForDocument:document pasteDragData:isPasteOrDrag ? inData : nil];
    
    return returnArray;
}

+ (NSDictionary *)macrosFromBibTeXString:(NSString *)stringContents macroResolver:(BDSKMacroResolver *)macroResolver{
    NSScanner *scanner = [[NSScanner alloc] initWithString:stringContents];
    [scanner setCharactersToBeSkipped:nil];
    
    NSMutableDictionary *macros = [NSMutableDictionary dictionary];
    NSString *key = nil;
    NSMutableString *value = nil;
    BOOL endOfValue = NO;
    BOOL quoted = NO;
    BOOL parenthesis = NO;
    
	NSString *s;
	NSInteger nesting;
	unichar ch;
    
    NSError *error= nil;
    
    static NSCharacterSet *bracesQuotesAndCommaCharSet = nil;
    if (bracesQuotesAndCommaCharSet == nil) {
        bracesQuotesAndCommaCharSet = [[NSCharacterSet characterSetWithCharactersInString:@"{})\","] retain];
    }
    
    // NSScanner is case-insensitive by default
    
    while(![scanner isAtEnd]){
        
        [scanner scanUpToString:@"@STRING" intoString:nil]; // don't check the return value on this, in case there are no characters between the initial location and the keyword
        
        // scan past the keyword
        if(![scanner scanString:@"@STRING" intoString:nil])
            break;
        
		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
		
        parenthesis = NO;
        
        if(NO == [scanner scanString:@"{" intoString:nil]){
            if(NO == [scanner scanString:@"(" intoString:nil])
                continue;
            parenthesis = YES;
        }
        
        // scan macro=value items up to the closing brace 
        nesting = 1;
        while(nesting > 0 && ![scanner isAtEnd]){
            
            // scan the key
            if(![scanner scanUpToString:@"=" intoString:&key] ||
               ![scanner scanString:@"=" intoString:nil])
                break;
            
            // scan the value, up to the next comma or the closing brace, passing through nested braces
            endOfValue = NO;
            value = [NSMutableString string];
            while(endOfValue == NO && ![scanner isAtEnd]){
                if([scanner scanUpToCharactersFromSet:bracesQuotesAndCommaCharSet intoString:&s])
                    [value appendString:s];
                if([scanner scanCharacter:&ch] == NO) break;
                if(ch == '{'){
                    if(nesting == 1)
                        quoted = NO;
                    ++nesting;
                }else if(ch == '}'){
                    if(nesting == 1)
                        endOfValue = YES;
                    --nesting;
                }else if(ch == '"'){
                    if(nesting == 1){
                        quoted = YES;
                        ++nesting;
                    }else if(quoted && nesting == 2)
                        --nesting;
                }else if(ch == ','){
                    if(nesting == 1)
                        endOfValue = YES;
                }else if(ch == ')' && parenthesis && nesting == 1){
                    endOfValue = YES;
                    --nesting;
                }
                if (endOfValue == NO) // we don't include the outer braces or the separating commas
                    [value appendFormat:@"%C", ch];
            }
            if(endOfValue == NO)
                break;
            
            CFStringTrimWhitespace((CFMutableStringRef)value);
            
            key = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (value = [NSString stringWithBibTeXString:value macroResolver:macroResolver error:&error])
                [macros setObject:value forKey:key];
            else
                NSLog(@"Ignoring invalid complex macro: %@", [error localizedDescription]);
            
        }
		
    }
	
    [scanner release];
    
    return ([macros count] ? macros : nil);
}

+ (NSDictionary *)macrosFromBibTeXStyle:(NSString *)styleContents macroResolver:(BDSKMacroResolver *)macroResolver{
    NSScanner *scanner = [[NSScanner alloc] initWithString:styleContents];
    [scanner setCharactersToBeSkipped:nil];
    
    NSMutableDictionary *macros = [NSMutableDictionary dictionary];
    NSString *key = nil;
    NSMutableString *value = nil;
    BOOL quoted = NO;

	NSString *s;
	NSInteger nesting;
	unichar ch;
    
    NSError *error = nil;
    
    static NSCharacterSet *bracesAndQuotesCharSet = nil;
    if (bracesAndQuotesCharSet == nil) {
        bracesAndQuotesCharSet = [[NSCharacterSet characterSetWithCharactersInString:@"{}\""] retain];
    }
    
    // NSScanner is case-insensitive by default
    
    while(![scanner isAtEnd]){
        
        [scanner scanUpToString:@"MACRO" intoString:nil]; // don't check the return value on this, in case there are no characters between the initial location and the keyword
        
        // scan past the keyword
        if(![scanner scanString:@"MACRO" intoString:nil])
            break;
        
		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];

        // scan the key
		if(![scanner scanString:@"{" intoString:nil] ||
           ![scanner scanUpToString:@"}" intoString:&key] ||
           ![scanner scanString:@"}" intoString:nil])
            continue;
        
        [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
        
        if(![scanner scanString:@"{" intoString:nil])
            continue;
        
        value = [NSMutableString string];
        nesting = 1;
        while(nesting > 0 && ![scanner isAtEnd]){
            if([scanner scanUpToCharactersFromSet:bracesAndQuotesCharSet intoString:&s])
                [value appendString:s];
            if([scanner scanCharacter:&ch] == NO) break;
            // we found an unquoted brace
            if(ch == '{'){
                if(nesting == 1)
                    quoted = NO;
                ++nesting;
            }else if(ch == '}'){
                --nesting;
            }else if(ch == '"'){
                if(nesting == 1){
                    quoted = YES;
                    ++nesting;
                }else if(quoted && nesting == 2)
                    --nesting;
            }
            if (nesting > 0) // we don't include the outer braces
                [value appendFormat:@"%C",ch];
        }
        if(nesting > 0)
            continue;
        
        CFStringTrimWhitespace((CFMutableStringRef)value);
        
        key = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (value = [NSString stringWithBibTeXString:value macroResolver:macroResolver error:&error])
            [macros setObject:value forKey:key];
        else
            NSLog(@"Ignoring invalid complex macro: %@", [error localizedDescription]);
		
    }
	
    [scanner release];
    
    return ([macros count] ? macros : nil);
}

static CFArrayRef
__BDCreateArrayOfNamesByCheckingBraceDepth(CFArrayRef names)
{
    CFIndex i, iMax = CFArrayGetCount(names);
    if(iMax <= 1)
        return CFRetain(names);
    
    CFAllocatorRef allocator = CFAllocatorGetDefault();
    
    CFStringInlineBuffer inlineBuffer;
    CFMutableStringRef mutableString = CFStringCreateMutable(allocator, 0);
    CFIndex idx, braceDepth = 0;
    CFStringRef name;
    CFIndex nameLen;
    UniChar ch;
    Boolean shouldAppend = FALSE;
    
    CFMutableArrayRef mutableArray = CFArrayCreateMutable(allocator, iMax, &kCFTypeArrayCallBacks);
    
    for(i = 0; i < iMax; i++){
        name = CFArrayGetValueAtIndex(names, i);
        nameLen = CFStringGetLength(name);
        CFStringInitInlineBuffer(name, &inlineBuffer, CFRangeMake(0, nameLen));

        // check for balanced braces in this name (including braces from a previous name)
        for(idx = 0; idx < nameLen; idx++){
            ch = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, idx);
            if(ch == '{')
                braceDepth++;
            else if(ch == '}')
                braceDepth--;
        }
        // if we had an unbalanced string last time, we need to keep appending to the mutable string; likewise, we want to append this name to the mutable string if braces are still unbalanced
        if(shouldAppend || braceDepth != 0){
            if(BDIsEmptyString(mutableString) == FALSE)
                CFStringAppend(mutableString, CFSTR(" and "));
            CFStringAppend(mutableString, name);
            shouldAppend = TRUE;
        } else {
            // braces balanced, so append the value, and reset the mutable string
            CFArrayAppendValue(mutableArray, name);
            CFStringReplaceAll(mutableString, CFSTR(""));
            // don't append next time unless the next name has unbalanced braces in its own right
            shouldAppend = FALSE;
        }
    }
    
    if(BDIsEmptyString(mutableString) == FALSE)
        CFArrayAppendValue(mutableArray, mutableString);
    CFRelease(mutableString);
    
    // returning NULL will signify our error condition
    if(braceDepth != 0){
        CFRelease(mutableArray);
        mutableArray = NULL;
    }
    
    return mutableArray;
}

+ (NSArray *)authorsFromBibtexString:(NSString *)aString withPublication:(BibItem *)pub forField:(NSString *)field{
    
	NSMutableArray *authors = [NSMutableArray arrayWithCapacity:2];
    
    if ([NSString isEmptyString:aString])
        return authors;

    // This is equivalent to btparse's bt_split_list(str, "and", "BibTex Name", 0, ""), but avoids UTF8String conversion
    CFArrayRef array = BDStringCreateArrayBySeparatingStringsWithOptions(CFAllocatorGetDefault(), (CFStringRef)aString, CFSTR(" and "), kCFCompareCaseInsensitive);
    
    // check brace depth; corporate authors such as {Someone and Someone Else, Inc} use braces, so this parsing is BibTeX-specific, rather than general string handling
    CFArrayRef names = __BDCreateArrayOfNamesByCheckingBraceDepth(array);
    
    // shouldn't ever see this case as far as I know, as long as we're using btparse
    if(names == NULL){
        [[BDSKErrorObjectController sharedErrorObjectController] startObservingErrors];
        [BDSKErrorObject reportError:[NSString stringWithFormat:@"%@ \"%@\"", NSLocalizedString(@"Unbalanced braces in author names:", @"Error description"), [(id)array description]] forFile:nil line:-1];
        [[BDSKErrorObjectController sharedErrorObjectController] endObservingErrorsForPublication:pub];
        CFRelease(array);

        // @@ return the empty array or nil?
        return authors;
    }
    CFRelease(array);
    
    CFIndex i = 0, iMax = CFArrayGetCount(names);
    BibAuthor *anAuthor;
    
    for(i = 0; i < iMax; i++){
        anAuthor = [[BibAuthor alloc] initWithName:(id)CFArrayGetValueAtIndex(names, i) andPub:pub forField:(NSString *)field];
        [authors addObject:anAuthor];
        [anAuthor release];
    }
    [[BDSKCompletionManager sharedManager] addNamesForCompletion:(NSArray *)names];
	CFRelease(names);
	return authors;
}

@end

/// private functions used with libbtparse code

static inline NSInteger numberOfValuesInField(AST *field)
{
    AST *simple_value = field->down;
    NSInteger cnt = 0;
    while (simple_value && simple_value->text) {
        simple_value = simple_value->right;
        cnt++;
    }
    return cnt;
}

static inline BOOL checkStringForEncoding(NSString *s, NSInteger line, NSString *filePath, NSStringEncoding parserEncoding){
    if(![s canBeConvertedToEncoding:parserEncoding]){
        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Unable to convert characters to encoding %@", @"Error description"), [NSString localizedNameOfStringEncoding:parserEncoding]];
        [BDSKErrorObject reportError:message forFile:filePath line:line];      
        return NO;
    } 
    
    return YES;
}

static inline NSString *copyCheckedString(const char *cstring, NSInteger line, NSString *filePath, NSStringEncoding parserEncoding){
    NSString *nsString = cstring ? [[NSString alloc] initWithCString:cstring encoding:parserEncoding] : nil;
    if (nsString && checkStringForEncoding(nsString, line, filePath, parserEncoding) == NO) {
        [nsString release];
        nsString = nil;
    }
    return nsString;
}

static NSString *copyStringFromBTField(AST *field, NSString *filePath, BDSKMacroResolver *macroResolver, NSStringEncoding parserEncoding){
            
    NSString *s = nil;
    BDSKStringNode *sNode = nil;
    AST *simple_value;
    
	if(field->nodetype != BTAST_FIELD){
		NSLog(@"error! expected field here");
	}
    
	simple_value = field->down;
    
    // traverse the AST and find out how many fields we have
    NSInteger nodeCount = numberOfValuesInField(field);
    
    // from profiling: optimize for the single quoted string node case; avoids the array, node, and complex string overhead
    if (1 == nodeCount && simple_value->nodetype == BTAST_STRING) {
        // collapse whitespace in single-node strings
        bt_postprocess_field(field, BTO_COLLAPSE, true);
        
        s = copyCheckedString(simple_value->text, field->line, filePath, parserEncoding);
        NSString *translatedString = nil;
        
        if (s) {
            translatedString = [s copyDeTeXifiedString];
            [s release];
        }
        
        // return nil for errors
        return translatedString;
    }
    
    // create a fixed-size mutable array, since we've counted the number of nodes
    NSMutableArray *nodes = (NSMutableArray *)CFArrayCreateMutable(CFAllocatorGetDefault(), nodeCount, &kCFTypeArrayCallBacks);

	while(simple_value){
        if (simple_value->text){
            switch (simple_value->nodetype){
                case BTAST_MACRO:
                    s = copyCheckedString(simple_value->text, field->line, filePath, parserEncoding);
                    if (!s) {
                        [nodes release];
                        return nil;
                    }
                    
                    // We parse the macros in itemsFromData, but for reference, if we wanted to get the 
                    // macro value we could do this:
                    // expanded_text = bt_macro_text (simple_value->text, (char *)[filePath fileSystemRepresentation], simple_value->line);
                    sNode = [[BDSKStringNode alloc] initWithMacroString:s];
            
                    break;
                case BTAST_STRING:
                    s = copyCheckedString(simple_value->text, field->line, filePath, parserEncoding);
                    NSString *translatedString = [s copyDeTeXifiedString];
                
                    if (nil == s || nil == translatedString) {
                        [nodes release];
                        [translatedString release];
                        return nil;
                    }
                        
                    sNode = [[BDSKStringNode alloc] initWithQuotedString:translatedString];
                    [translatedString release];

                    break;
                case BTAST_NUMBER:
                    s = copyCheckedString(simple_value->text, field->line, filePath, parserEncoding);
                    if (!s) {
                        [nodes release];
                        return nil;
                    }
                        
                    sNode = [[BDSKStringNode alloc] initWithNumberString:s];

                    break;
                default:
                    [NSException raise:@"bad node type exception" format:@"Node type %d is unexpected.", simple_value->nodetype];
            }
            [nodes addObject:sNode];
            [s release];
            [sNode release];
        }
        
            simple_value = simple_value->right;
	} // while simple_value
	
    // This will return a single string-type node as a non-complex string.
    NSString *returnValue = [[NSString alloc] initWithNodes:nodes macroResolver:macroResolver];
    [nodes release];
    
    return returnValue;
}

static BOOL appendPreambleToFrontmatter(AST *entry, NSMutableString *frontMatter, NSString *filePath, NSStringEncoding encoding)
{
    
    [frontMatter appendString:@"\n@preamble{\""];
    AST *field = NULL;
    bt_nodetype type = BTAST_STRING;
    BOOL paste = NO;
    NSString *tmpStr = nil;
    BOOL success = YES;
    
    // bt_get_text() just gives us \\ne for the field, so we'll manually traverse it and poke around in the AST to get what we want.  This is sort of nasty, so if someone finds a better way, go for it.
    while(field = bt_next_value(entry, field, &type, NULL)){
        char *text = field->text;
        if(text){
            if(paste) [frontMatter appendString:@"\" #\n   \""];
            tmpStr = copyCheckedString(text, field->line, filePath, encoding);
            if(tmpStr) 
                [frontMatter appendString:tmpStr];
            else
                success = NO;
            [tmpStr release];
            paste = YES;
        }
    }
    [frontMatter appendString:@"\"}"];
    return success;
}

static BOOL addMacroToResolver(AST *entry, BDSKMacroResolver *macroResolver, NSString *filePath, NSStringEncoding encoding, NSError **error)
{
    // get the field name, there can be several macros in a single entry
    AST *field = NULL;
    char *fieldname = NULL;
    BOOL success = YES;
    
    while (field = bt_next_field (entry, field, &fieldname)){
        NSString *macroKey = copyCheckedString(field->text, field->line, filePath, encoding);
        NSCAssert(macroKey != nil, @"Macro keys must be ASCII");
        NSString *macroString = copyStringFromBTField(field, filePath, macroResolver, encoding); // handles TeXification
        if([macroResolver string:macroString dependsOnMacro:macroKey]){
            NSString *message = NSLocalizedString(@"Macro leads to circular definition, ignored.", @"Error description");            
            [BDSKErrorObject reportError:message forFile:filePath line:field->line];
            if (error)
                *error = [NSError localErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Circular macro ignored.", @"Error description")];
        }else if(nil != macroString){
            [macroResolver setMacroWithoutUndo:macroKey toValue:macroString];
        }else {
            // set this to NO, but don't subsequently set it to YES; signals partial data
            success = NO;
        }
        [macroKey release];
        [macroString release];
    } // end while field - process next macro    
    return success;
}

static BOOL appendCommentToFrontmatterOrAddGroups(AST *entry, NSMutableString *frontMatter, NSString *filePath, BibDocument *document, NSStringEncoding encoding)
{
    NSMutableString *commentStr = [[NSMutableString alloc] init];
    AST *field = NULL;
    char *text = NULL;
    NSString *tmpStr = nil;
    
    // this is our identifier string for a smart group
    const char *smartGroupStr = "BibDesk Smart Groups";
    size_t smartGroupStrLength = strlen(smartGroupStr);
    Boolean isSmartGroup = FALSE;
    const char *staticGroupStr = "BibDesk Static Groups";
    size_t staticGroupStrLength = strlen(staticGroupStr);
    Boolean isStaticGroup = FALSE;
    const char *urlGroupStr = "BibDesk URL Groups";
    size_t urlGroupStrLength = strlen(urlGroupStr);
    Boolean isURLGroup = FALSE;
    const char *scriptGroupStr = "BibDesk Script Groups";
    size_t scriptGroupStrLength = strlen(scriptGroupStr);
    Boolean isScriptGroup = FALSE;
    Boolean firstValue = TRUE;
    
    NSStringEncoding groupsEncoding = [[BDSKStringEncodingManager sharedEncodingManager] isUnparseableEncoding:encoding] ? encoding : NSUTF8StringEncoding;
    BOOL success = YES;
    
    while(field = bt_next_value(entry, field, NULL, &text)){
        if(text){
            if(firstValue){
                firstValue = FALSE;
                if(strlen(text) >= smartGroupStrLength && strncmp(text, smartGroupStr, smartGroupStrLength) == 0)
                    isSmartGroup = TRUE;
                else if(strlen(text) >= staticGroupStrLength && strncmp(text, staticGroupStr, staticGroupStrLength) == 0)
                    isStaticGroup = TRUE;
                else if(strlen(text) >= urlGroupStrLength && strncmp(text, urlGroupStr, urlGroupStrLength) == 0)
                    isURLGroup = TRUE;
                else if(strlen(text) >= scriptGroupStrLength && strncmp(text, scriptGroupStr, scriptGroupStrLength) == 0)
                    isScriptGroup = TRUE;
            }
            
            // encoding will be UTF-8 for the plist, so make sure we use it for each line
            tmpStr = copyCheckedString(text, field->line, filePath, ((isSmartGroup || isStaticGroup || isURLGroup || isScriptGroup)? groupsEncoding : encoding));
            
            if(tmpStr) 
                [commentStr appendString:tmpStr];
            else
                success = NO;

            [tmpStr release];
        }
    }
    if(isSmartGroup || isStaticGroup || isURLGroup || isScriptGroup){
        if(document){
            NSRange range = [commentStr rangeOfString:@"{"];
            if(range.location != NSNotFound){
                [commentStr deleteCharactersInRange:NSMakeRange(0,NSMaxRange(range))];
                range = [commentStr rangeOfString:@"}" options:NSBackwardsSearch];
                if(range.location != NSNotFound){
                    [commentStr deleteCharactersInRange:NSMakeRange(range.location,[commentStr length] - range.location)];
                    if (isSmartGroup)
                        [[document groups] setGroupsOfType:BDSKSmartGroupType fromSerializedData:[commentStr dataUsingEncoding:NSUTF8StringEncoding]];
                    else if (isStaticGroup)
                        [[document groups] setGroupsOfType:BDSKStaticGroupType fromSerializedData:[commentStr dataUsingEncoding:NSUTF8StringEncoding]];
                    else if (isURLGroup)
                        [[document groups] setGroupsOfType:BDSKURLGroupType fromSerializedData:[commentStr dataUsingEncoding:NSUTF8StringEncoding]];
                    else if (isScriptGroup)
                        [[document groups] setGroupsOfType:BDSKScriptGroupType fromSerializedData:[commentStr dataUsingEncoding:NSUTF8StringEncoding]];
                }
            }
        }
    }else{
        [frontMatter appendString:@"\n@comment{"];
        [frontMatter appendString:commentStr];
        [frontMatter appendString:@"}"];
    }
    [commentStr release];    
    return success;
}

static NSString *copyStringFromNoteField(AST *field, const char *data, NSUInteger inputDataLength, NSString *filePath, NSStringEncoding encoding, NSString **errorString)
{
    NSString *returnString = nil;
    unsigned long cidx = 0; // used to scan through buf for annotes.
    NSInteger braceDepth = 0;
    BOOL lengthOverrun = NO;
    if(field->down){
        cidx = field->down->offset;
        
        // the delimiter is at cidx-1
        if(data[cidx-1] == '{'){
            // scan up to the balanced brace
            for(braceDepth = 1; braceDepth > 0; cidx++){
                if (cidx >= inputDataLength) {
                    lengthOverrun = YES;
                    break;
                }
                if(data[cidx] == '{') braceDepth++;
                if(data[cidx] == '}') braceDepth--;
            }
            cidx--;     // just advanced cidx one past the end of the field.
        }else if(data[cidx-1] == '"'){
            // scan up to the next quote.
            for(; (data[cidx] != '"' || data[cidx-1] == '\\'); cidx++) {
                if (cidx >= inputDataLength) {
                    lengthOverrun = YES;
                    break;
                }
            }
                    
        }else{ 
            // no brace and no quote => unknown problem
            if (errorString)
                *errorString = [NSString stringWithFormat:NSLocalizedString(@"Unexpected delimiter \"%@\" encountered at line %d.", @"Error description"), [[[NSString alloc] initWithBytes:&data[cidx-1] length:1 encoding:encoding] autorelease], field->line];
        }
        if (lengthOverrun) {
            if (errorString)
                *errorString = [NSString stringWithFormat:@"Unbalanced delimiters at line %d (%s)", field->line, field->down->text];
            returnString = nil;
        } else {
            returnString = [[NSString alloc] initWithBytes:&data[field->down->offset] length:(cidx- (field->down->offset)) encoding:encoding];
            if (NO == checkStringForEncoding(returnString, field->line, filePath, encoding) && errorString) {
                *errorString = NSLocalizedString(@"Encoding conversion failure", @"Error description");
                [returnString release];
                returnString = nil;
            }
        }
    }else{
        if(errorString)
            *errorString = NSLocalizedString(@"Unable to parse string as BibTeX", @"Error description");
    }
    return returnString;
}

static BOOL addValuesFromEntryToDictionary(AST *entry, NSMutableDictionary *dictionary, const char *buf, NSUInteger inputDataLength, BDSKMacroResolver *macroResolver, NSString *filePath, NSStringEncoding parserEncoding)
{
    AST *field = NULL;
    NSString *fieldName, *fieldValue, *tmpStr;
    char *fieldname;
    BOOL hadProblems = NO;
    
    while (field = bt_next_field (entry, field, &fieldname))
    {
        // Get fieldname as a capitalized NSString
        tmpStr = copyCheckedString(fieldname, field->line, filePath, parserEncoding);
        fieldName = [tmpStr fieldName];
        [tmpStr release];
        
        fieldValue = nil;
        
        // Special case handling of abstract & annote is to avoid losing newlines in preexisting files.
        // In addition, we need to preserve newlines in file fields for base64 decoding, instead of replacing with a space.
        if([fieldName isNoteField] || [fieldName hasPrefix:@"Bdsk-File-"]){
            
            // this is guaranteed to point to a meaningful error if copyStringFromNoteField fails
            NSString *errorString = nil;
            tmpStr = copyStringFromNoteField(field, buf, inputDataLength, filePath, parserEncoding, &errorString);
            
            // this can happen with badly formed annote/abstract fields, and leads to data loss
            if(nil == tmpStr){
                hadProblems = YES;
                [BDSKErrorObject reportError:errorString forFile:filePath line:field->line];
            } else {
                
                // this returns nil in case of a syntax error; it isn't an encoding failure
                fieldValue = [tmpStr copyDeTeXifiedString];
                
                if (nil == fieldValue) {
                    hadProblems = YES;
                    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Unable to convert TeX string \"%@\"", @"Error description"), tmpStr];
                    [BDSKErrorObject reportError:message forFile:filePath line:field->line];  
                }
            }
            [tmpStr release];
            
        }else{
            // this method returns nil and posts an error in case of failure
            fieldValue = copyStringFromBTField(field, filePath, macroResolver, parserEncoding);
        }
        
        if (fieldName && fieldValue) {
            // add the expanded values to the autocomplete dictionary; authors are handled elsewhere
            if ([fieldName isPersonField] == NO)
                [[BDSKCompletionManager sharedManager] addString:fieldValue forCompletionEntry:fieldName];
            
            [dictionary setObject:fieldValue forKey:fieldName];
        } else {
            hadProblems = YES;
        }
        [fieldValue release];
        
    }// end while field - process next bt field      
    return hadProblems == NO;
}

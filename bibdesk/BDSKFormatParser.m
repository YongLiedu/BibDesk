//
//  BDSKFormatParser.m
//  BibDesk
//
//  Created by Christiaan Hofman on 17/4/05.
/*
 This software is Copyright (c) 2005-2009
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

#import "BDSKFormatParser.h"
#import "BDSKStringConstants.h"
#import "BibAuthor.h"
#import "BDSKConverter.h"
#import "BDSKTypeManager.h"
#import "NSString_BDSKExtensions.h"
#import "NSAttributedString_BDSKExtensions.h"
#import "NSDate_BDSKExtensions.h"
#import "NSScanner_BDSKExtensions.h"
#import "BDSKStringNode.h"
#import "BDSKLinkedFile.h"
#import "BDSKAppController.h"

@implementation BDSKFormatParser

+ (NSString *)parseFormat:(NSString *)format forField:(NSString *)fieldName ofItem:(id <BDSKParseableItem>)pub
{
    return [self parseFormat:format forField:fieldName ofItem:pub suggestion:nil];
}

+ (NSString *)parseFormat:(NSString *)format forField:(NSString *)fieldName ofItem:(id <BDSKParseableItem>)pub suggestion:(NSString *)suggestion
{
    return [self parseFormat:format forField:fieldName linkedFile:nil ofItem:pub suggestion:suggestion];
}

+ (NSString *)parseFormatForLinkedFile:(BDSKLinkedFile *)file ofItem:(id <BDSKParseableItem>)pub
{
	NSString *localFileFormat = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKLocalFileFormatKey];
    
    return [self parseFormat:localFileFormat forLinkedFile:file ofItem:pub];
}

+ (NSString *)parseFormat:(NSString *)format forLinkedFile:(BDSKLinkedFile *)file ofItem:(id <BDSKParseableItem>)pub
{
	NSString *papersFolderPath = [[NSApp delegate] folderPathForFilingPapersFromDocument:[pub owner]];
    
    NSString *oldPath = [[file URL] path];
    if ([oldPath hasPrefix:[papersFolderPath stringByAppendingString:@"/"]]) 
        oldPath = [oldPath substringFromIndex:[papersFolderPath length] + 1];
    else
        oldPath = nil;
      
    return [self parseFormat:format forField:BDSKLocalFileString linkedFile:file ofItem:pub suggestion:oldPath];
}

+ (NSString *)parseFormat:(NSString *)format forField:(NSString *)fieldName linkedFile:(BDSKLinkedFile *)file ofItem:(id <BDSKParseableItem>)pub suggestion:(NSString *)suggestion
{
	static NSCharacterSet *nonLowercaseLetterCharSet = nil;
	static NSCharacterSet *nonUppercaseLetterCharSet = nil;
	static NSCharacterSet *nonDecimalDigitCharSet = nil;
	
    if (nonLowercaseLetterCharSet == nil) {
        nonLowercaseLetterCharSet = [[[NSCharacterSet characterSetWithRange:NSMakeRange('a',26)] invertedSet] copy];
        nonUppercaseLetterCharSet = [[[NSCharacterSet characterSetWithRange:NSMakeRange('A',26)] invertedSet] copy];
        nonDecimalDigitCharSet = [[[NSCharacterSet characterSetWithRange:NSMakeRange('0',10)] invertedSet] copy];
    }
    
    NSMutableString *parsedStr = [NSMutableString string];
	NSString *prefixStr = nil;
	NSScanner *scanner = [NSScanner scannerWithString:format];
    NSUInteger uniqueNumber;
	unichar specifier, nextChar, uniqueSpecifier = 0;
    NSString *uniqueSeparator = nil;
	NSCharacterSet *slashCharSet = [NSCharacterSet characterSetWithCharactersInString:@"/"];
	BOOL isLocalFile = [fieldName isLocalFileField] || [fieldName isEqualToString:BDSKLocalFileString];
	
	[scanner setCharactersToBeSkipped:nil];
	
	while (NO == [scanner isAtEnd]) {
		// scan non-specifier parts
        NSString *string = nil;
		if ([scanner scanUpToString:@"%" intoString:&string]) {
			// if we are not sure about a valid format, we should sanitize string
			[parsedStr appendString:string];
		}
		// does nothing at the end; allows but ignores % at end
		[scanner scanString:@"%" intoString:NULL];
        // found %, so now there should be a specifier char
		if ([scanner scanCharacter:&specifier]) {
			switch (specifier) {
				case 'a':
				case 'p':
                {
					// author names, optional [separator], [etal], #names and #chars
					NSUInteger numChars = 0;
					NSUInteger i, numAuth = 0;
					NSString *authSep = @"";
					NSString *etal = @"";
                    BOOL isLast = NO;
					if (NO == [scanner isAtEnd]) {
						// look for [separator]
						if ([scanner scanString:@"[" intoString:NULL]) {
							if (NO == [scanner scanUpToString:@"]" intoString:&authSep]) authSep = @"";
							[scanner scanString:@"]" intoString:NULL];
							// look for [etal]
							if ([scanner scanString:@"[" intoString:NULL]) {
								if (NO == [scanner scanUpToString:@"]" intoString:&etal]) etal = @"";
								[scanner scanString:@"]" intoString:NULL];
							}
						}
						if ([scanner peekCharacter:&nextChar]) {
							// look for #names
                            if (nextChar == '-') {
                                [scanner setScanLocation:[scanner scanLocation]+1];
                                if ([scanner peekCharacter:&nextChar] && [[NSCharacterSet decimalDigitCharacterSet] characterIsMember:nextChar]) {
                                    isLast = YES;
                                } else {
                                    [scanner setScanLocation:[scanner scanLocation]-1];
                                    nextChar = '-';
                                }
                            }
                            if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:nextChar]) {
								[scanner setScanLocation:[scanner scanLocation]+1];
								numAuth = (NSUInteger)(nextChar - '0');
								// scan for #chars per name
								if (NO == [scanner scanUnsignedInteger:&numChars]) numChars = 0;
							}
						}
					}
					NSArray *authArray = [pub peopleArrayForField:BDSKAuthorString];
					if ([authArray count] == 0 && specifier == 'p') {
						authArray = [pub peopleArrayForField:BDSKEditorString];
					}
					if ([authArray count] == 0) {
						break;
					}
					if (numAuth == 0 || numAuth > [authArray count]) {
						numAuth = [authArray count];
					}
					for (i = 0; i < numAuth; i++) {
						if (i > 0) {
							[parsedStr appendString:authSep];
						}
						NSString *authName = [self stringByStrictlySanitizingString:[[authArray objectAtIndex:isLast ? [authArray count] - numAuth + i : i] lastName] forField:fieldName inFileType:[pub fileType]];
						if (isLocalFile) {
							authName = [authName stringByReplacingCharactersInSet:slashCharSet withString:@"-"];
						}
						if ([authName length] > numChars && numChars > 0) {
							authName = [authName substringToIndex:numChars];
						}
						[parsedStr appendString:authName];
					}
					if (numAuth < [authArray count]) {
						[parsedStr appendString:etal];
					}
					break;
				}
                case 'A':
				case 'P':
				{
                	// author names with initials, optional [author separator], [name separator], [etal], #names
					NSUInteger i, numAuth = 0;
					NSString *authSep = @";";
					NSString *nameSep = @".";
					NSString *etal = @"";
                    BOOL isLast = NO;
					if (NO == [scanner isAtEnd]) {
						// look for [author separator]
						if ([scanner scanString:@"[" intoString:NULL]) {
							if (NO == [scanner scanUpToString:@"]" intoString:&authSep]) authSep = @"";
							[scanner scanString:@"]" intoString:NULL];
							// look for [name separator]
							if ([scanner scanString:@"[" intoString:NULL]) {
								if (NO == [scanner scanUpToString:@"]" intoString:&nameSep]) nameSep = @"";
								[scanner scanString:@"]" intoString:NULL];
								// look for [etal]
								if ([scanner scanString:@"[" intoString:NULL]) {
									if (NO == [scanner scanUpToString:@"]" intoString:&etal]) etal = @"";
									[scanner scanString:@"]" intoString:NULL];
								}
							}
						}
						if ([scanner peekCharacter:&nextChar]) {
							// look for #names
                            if (nextChar == '-') {
                                [scanner setScanLocation:[scanner scanLocation]+1];
                                if ([scanner peekCharacter:&nextChar] && [[NSCharacterSet decimalDigitCharacterSet] characterIsMember:nextChar]) {
                                    isLast = YES;
                                } else {
                                    [scanner setScanLocation:[scanner scanLocation]-1];
                                    nextChar = '-';
                                }
                            }
							if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:nextChar]) {
								[scanner setScanLocation:[scanner scanLocation]+1];
								numAuth = (NSUInteger)(nextChar - '0');
							}
						}
					}
					NSArray *authArray = [pub peopleArrayForField:BDSKAuthorString];
					if ([authArray count] == 0 && specifier == 'P') {
						authArray = [pub peopleArrayForField:BDSKEditorString];
					}
					if ([authArray count] == 0) {
						break;
					}
					if (numAuth == 0 || numAuth > [authArray count]) {
						numAuth = [authArray count];
					}
					for (i = 0; i < numAuth; i++) {
						if (i > 0) {
							[parsedStr appendString:authSep];
						}
						BibAuthor *auth = [authArray objectAtIndex:isLast ? [authArray count] - numAuth + i : i];
						NSString *authName;
                        NSString *firstName = [self stringByStrictlySanitizingString:[auth firstName] forField:fieldName inFileType:[pub fileType]];
						NSString *lastName = [self stringByStrictlySanitizingString:[auth lastName] forField:fieldName inFileType:[pub fileType]];
						if ([firstName length] > 0) {
							authName = [NSString stringWithFormat:@"%@%@%C", lastName, nameSep, [firstName characterAtIndex:0]];
						} else {
							authName = lastName;
						}
						if (isLocalFile) {
							authName = [authName stringByReplacingCharactersInSet:slashCharSet withString:@"-"];
						}
						[parsedStr appendString:authName];
					}
					if (numAuth < [authArray count]) {
						[parsedStr appendString:etal];
					}
					break;
				}
                case 't':
				{
                	// title, optional #chars
                    NSUInteger numChars = 0;
                    NSString *title = [pub title];
					title = [self stringByStrictlySanitizingString:title forField:fieldName inFileType:[pub fileType]];
					if ([NSString isEmptyString:title] == NO) {
                        if (isLocalFile) {
                            title = [title stringByReplacingCharactersInSet:slashCharSet withString:@"-"];
                        }
                        if (NO == [scanner scanUnsignedInteger:&numChars]) numChars = 0;
                        if (numChars > 0 && [title length] > numChars) {
                            [parsedStr appendString:[title substringToIndex:numChars]];
                        } else {
                            [parsedStr appendString:title];
                        }
                    }
					break;
				}
                case 'T':
				{
                	// title, optional #words
                    NSUInteger i, numWords = 0;
                    NSUInteger smallWordLength = 3;
                    NSString *numString = nil;
                    NSString *title = [pub title];
                    if ([scanner scanString:@"[" intoString:NULL]) {
                        if ([scanner scanUpToString:@"]" intoString:&numString])
                            smallWordLength = (NSUInteger)[numString intValue];
                        else
                            smallWordLength = 0;
                        [scanner scanString:@"]" intoString:NULL];
                    }
					if (NO == [scanner scanUnsignedInteger:&numWords]) numWords = 0;
					if ([NSString isEmptyString:title] == NO) {
						NSMutableArray *words = [NSMutableArray array];
                        NSString *word;
						// split the title into words using the same methodology as addString:forCompletionEntry:
						NSRange wordSpacingRange = [title rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
						if (wordSpacingRange.location != NSNotFound) {
							NSScanner *wordScanner = [NSScanner scannerWithString:title];
							
							while (NO == [wordScanner isAtEnd]) {
								if ([wordScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&word]){
									[words addObject:word];
								}
								[wordScanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
							}
						} else {
							[words addObject:title];
						}
						if (numWords == 0) numWords = [words count];
                        BOOL isFirst = YES;
						for (i = 0; i < [words count] && numWords > 0; i++) { 
                            word = [self stringByStrictlySanitizingString:[words objectAtIndex:i] forField:fieldName inFileType:[pub fileType]]; 
							if (isLocalFile) {
								word = [word stringByReplacingCharactersInSet:slashCharSet withString:@"-"];
							}
                            if (numString == nil || [word length] > smallWordLength) {
                                if (isFirst) isFirst = NO;
                                else [parsedStr appendString:[self stringByStrictlySanitizingString:@" " forField:fieldName inFileType:[pub fileType]]]; 
                                [parsedStr appendString:word]; 
                                if ([word length] > smallWordLength) --numWords;
                            }
						}
					}
					break;
				}
                case 'y':
				{
                	// year without century
                    NSString *yearString = [pub stringValueOfField:BDSKYearString];
                    if ([NSString isEmptyString:yearString] == NO) {
                        NSDate *date = [[NSDate alloc] initWithMonthString:@"6" yearString:yearString];
						yearString = [date descriptionWithCalendarFormat:@"%y" timeZone:nil locale:nil];
						[parsedStr appendString:yearString];
                        [date release];
					}
					break;
				}
                case 'Y':
				{
                	// year with century
                    NSString *yearString = [pub stringValueOfField:BDSKYearString];
                    if ([NSString isEmptyString:yearString] == NO) {
                        NSDate *date = [[NSDate alloc] initWithMonthString:@"6" yearString:yearString];
						yearString = [date descriptionWithCalendarFormat:@"%Y" timeZone:nil locale:nil];
						[parsedStr appendString:yearString];
                        [date release];
					}
					break;
				}
                case 'm':
				{
                	// month
                    NSString *monthString = [pub stringValueOfField:BDSKMonthString];
                    if ([NSString isEmptyString:monthString] == NO) {
                        if([monthString isComplex]) {
                            NSArray *nodes = [monthString nodes];
                            if ([nodes count] > 1 && [(BDSKStringNode *)[nodes objectAtIndex:1] type] == BDSKStringNodeMacro)
                                monthString = [(BDSKStringNode *)[nodes objectAtIndex:1] value];
                            else if ([nodes count] > 2 && [(BDSKStringNode *)[nodes objectAtIndex:2] type] == BDSKStringNodeMacro)
                                monthString = [(BDSKStringNode *)[nodes objectAtIndex:2] value];
                            else
                                monthString = [(BDSKStringNode *)[nodes objectAtIndex:0] value];
                        }
                        NSDate *date = [[NSDate alloc] initWithMonthString:monthString yearString:@"2000"];
						monthString = [date descriptionWithCalendarFormat:@"%m" timeZone:nil locale:nil];
						[parsedStr appendString:monthString];
                        [date release];
					}
					break;
				}
                case 'k':
				{
                	// keywords
					// look for [slash]
					NSString *slash = (isLocalFile) ? @"-" : @"/";
					if ([scanner scanString:@"[" intoString:NULL]) {
						if (NO == [scanner scanUpToString:@"]" intoString:&slash]) slash = @"";
						[scanner scanString:@"]" intoString:NULL];
					}
					NSString *keywordsString = [pub stringValueOfField:BDSKKeywordsString];
					NSUInteger i, numWords = 0;
                    if (NO == [scanner scanUnsignedInteger:&numWords]) numWords = 0;
					if ([NSString isEmptyString:keywordsString] == NO) {
						NSMutableArray *keywords = [NSMutableArray array];
                        NSString *keyword;
						// split the keyword string using the same methodology as addString:forCompletionEntry:, treating ,:; as possible dividers
                        NSCharacterSet *sepCharSet = [[BDSKTypeManager sharedManager] separatorCharacterSetForField:BDSKKeywordsString];
                        NSRange keywordPunctuationRange = [keywordsString rangeOfCharacterFromSet:sepCharSet];
						if (keywordPunctuationRange.location != NSNotFound) {
							NSScanner *wordScanner = [NSScanner scannerWithString:keywordsString];
							[wordScanner setCharactersToBeSkipped:nil];
							
							while (NO == [wordScanner isAtEnd]) {
								if ([wordScanner scanUpToCharactersFromSet:sepCharSet intoString:&keyword])
									[keywords addObject:keyword];
								[wordScanner scanCharactersFromSet:sepCharSet intoString:nil];
							}
						} else {
							[keywords addObject:keywordsString];
						}
						for (i = 0; i < [keywords count] && (numWords == 0 || i < numWords); i++) { 
                            keyword = [[keywords objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]; 
                            keyword = [self stringByStrictlySanitizingString:keyword forField:fieldName inFileType:[pub fileType]]; 
							if (NO == [slash isEqualToString:@"/"])
								keyword = [keyword stringByReplacingCharactersInSet:slashCharSet withString:slash];
							[parsedStr appendString:keyword]; 
						}
					}
					break;
				}
                case 'l':
				{
                	// old filename without extension
					NSString *filename = nil;
                    if (file)
						filename = [[file URL] path];
                    else if ([fieldName isLocalFileField])
						filename = [[pub localFileURLForField:fieldName] path];
					else
						filename = [[pub localFileURLForField:BDSKLocalUrlString] path];
					if (filename != nil) {
						filename = [[filename lastPathComponent] stringByDeletingPathExtension];
						filename = [self stringBySanitizingString:filename forField:fieldName inFileType:[pub fileType]]; 
						[parsedStr appendString:filename];
					}
					break;
				}
                case 'L':
				{
                	// old filename with extension
					NSString *filename = nil;
                    if (file)
						filename = [[file URL] path];
                    else if ([fieldName isLocalFileField])
						filename = [[pub localFileURLForField:fieldName] path];
					else
						filename = [[pub localFileURLForField:BDSKLocalUrlString] path];
					if (filename != nil) {
						filename = [filename lastPathComponent];
						filename = [self stringBySanitizingString:filename forField:fieldName inFileType:[pub fileType]]; 
						[parsedStr appendString:filename];
					}
					break;
				}
                case 'e':
				{
                	// old file extension
					NSString *filename = nil;
                    if (file)
						filename = [[file URL] path];
                    else if ([fieldName isLocalFileField])
						filename = [[pub localFileURLForField:fieldName] path];
					else
						filename = [[pub localFileURLForField:BDSKLocalUrlString] path];
					if (filename != nil) {
						filename = [filename pathExtension];
						if (NO == [filename isEqualToString:@""]) {
							filename = [self stringBySanitizingString:filename forField:fieldName inFileType:[pub fileType]]; 
							[parsedStr appendFormat:@".%@", filename];
						}
					}
					break;
				}
                case 'b':
				{
                	// document filename
					NSString *filename = [[[[[pub owner] fileURL] path] lastPathComponent] stringByDeletingPathExtension];
					if (filename != nil) {
						filename = [self stringBySanitizingString:filename forField:fieldName inFileType:[pub fileType]]; 
						[parsedStr appendString:filename];
					}
					break;
				}
                case 'f':
				{
                	// arbitrary field
                    NSString *key = nil;
                    NSString *value = nil;
                    NSString *slash = (isLocalFile) ? @"-" : @"/";
                    NSUInteger numChars = 0;
					if ([scanner scanString:@"{" intoString:NULL] &&
						[scanner scanUpToString:@"}" intoString:&key] &&
						[scanner scanString:@"}" intoString:NULL]) {
						// look for [slash]
						if ([scanner scanString:@"[" intoString:NULL]) {
							if (NO == [scanner scanUpToString:@"]" intoString:&slash]) slash = @"";
							[scanner scanString:@"]" intoString:NULL];
						}
                        
						if (NO == [scanner scanUnsignedInteger:&numChars]) numChars = 0;
						if (NO == [fieldName isEqualToString:BDSKCiteKeyString] &&
							[key isEqualToString:BDSKCiteKeyString]) {
							value = [pub citeKey];
						} else if ([key isEqualToString:BDSKContainerString]) {
							value = [pub container];
						} else {
							value = [pub stringValueOfField:key];
						}
						if ([NSString isEmptyString:value] == NO) {
							value = [self stringByStrictlySanitizingString:value forField:fieldName inFileType:[pub fileType]];
							if (NO == [slash isEqualToString:@"/"])
								value = [value stringByReplacingCharactersInSet:slashCharSet withString:slash];
							if (numChars > 0 && [value length] > numChars) {
								[parsedStr appendString:[value substringToIndex:numChars]];
							} else {
								[parsedStr appendString:value];
							}
						}
					}
					else {
						NSLog(@"Missing {'field'} after format specifier %%f in format.");
					}
					break;
				}
                case 'w':
				{
                	// words
                    NSString *key = nil;
                    NSString *sepChars = nil;
                    NSString *slash = (isLocalFile) ? @"-" : @"/";
                    if ([scanner scanString:@"{" intoString:NULL] &&
						[scanner scanUpToString:@"}" intoString:&key] &&
						[scanner scanString:@"}" intoString:NULL]) {
                        // look for [sep]
                        if ([scanner scanString:@"[" intoString:NULL]) {
                            if (NO == [scanner scanUpToString:@"]" intoString:&sepChars]) sepChars = @" ";
                            [scanner scanString:@"]" intoString:NULL];
                        }
                        // look for [slash]
                        if ([scanner scanString:@"[" intoString:NULL]) {
                            if (NO == [scanner scanUpToString:@"]" intoString:&slash]) slash = @"";
                            [scanner scanString:@"]" intoString:NULL];
                        }
                        NSString *wordsString = [pub stringValueOfField:key];
                        NSUInteger i, numWords = 0;
                        if (NO == [scanner scanUnsignedInteger:&numWords]) numWords = 0;
                        if ([NSString isEmptyString:wordsString] == NO) {
                            NSMutableArray *words = [NSMutableArray array];
                            NSString *word;
                            // split the word string using the same methodology as addString:forCompletionEntry:, treating sepChars as possible dividers
                            NSCharacterSet *sepCharSet = [NSCharacterSet characterSetWithCharactersInString:sepChars];
                            NSRange wordPunctuationRange = [wordsString rangeOfCharacterFromSet:sepCharSet];
                            if (wordPunctuationRange.location != NSNotFound) {
                                NSScanner *wordScanner = [NSScanner scannerWithString:wordsString];
                                [wordScanner setCharactersToBeSkipped:nil];
                                
                                while (NO == [wordScanner isAtEnd]) {
                                    if ([wordScanner scanUpToCharactersFromSet:sepCharSet intoString:&word])
                                        [words addObject:word];
                                    [wordScanner scanCharactersFromSet:sepCharSet intoString:nil];
                                }
                            } else {
                                [words addObject:wordsString];
                            }
                            for (i = 0; i < [words count] && (numWords == 0 || i < numWords); i++) { 
                                word = [[words objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]; 
                                word = [self stringByStrictlySanitizingString:word forField:fieldName inFileType:[pub fileType]]; 
                                if (NO == [slash isEqualToString:@"/"])
                                    word = [word stringByReplacingCharactersInSet:slashCharSet withString:slash];
                                [parsedStr appendString:word]; 
                            }
                        }
					}
					else {
						NSLog(@"Missing {'field'} after format specifier %%w in format.");
					}
					break;
				}
                case 'c':
				{
                	// This handles acronym specifiers of the form %c{FieldName}
					NSString *key = nil;
                    NSString *value = nil;
                    NSUInteger smallWordLength = 3;
                    if ([scanner scanString:@"{" intoString:NULL] &&
						[scanner scanUpToString:@"}" intoString:&key] &&
						[scanner scanString:@"}" intoString:NULL]) {
						if (NO == [scanner scanUnsignedInteger:&smallWordLength]) smallWordLength = 3;
				
						value = [[pub stringValueOfField:key] acronymValueIgnoringWordLength:smallWordLength];
						value = [self stringByStrictlySanitizingString:value forField:fieldName inFileType:[pub fileType]];
						[parsedStr appendString:value];
					}
					else {
						NSLog(@"Missing {'field'} after format specifier %%c in format.");
					}
					break;
				}
                case 's':
				{
                	// arbitrary boolean or tri-value field
                    NSString *key = nil;
                    NSString *yesValue = @"";
                    NSString *noValue = @"";
                    NSString *mixedValue = @"";
                    NSUInteger numChars = 0;
                    NSInteger intValue = 0;
                    NSString *value = nil;
					if ([scanner scanString:@"{" intoString:NULL] &&
						[scanner scanUpToString:@"}" intoString:&key] &&
						[scanner scanString:@"}" intoString:NULL]) {
						// look for [yes value]
						if ([scanner scanString:@"[" intoString:NULL]) {
							if (NO == [scanner scanUpToString:@"]" intoString:&yesValue]) yesValue = @"";
							[scanner scanString:@"]" intoString:NULL];
                            // look for [no value]
                            if ([scanner scanString:@"[" intoString:NULL]) {
                                if (NO == [scanner scanUpToString:@"]" intoString:&noValue]) noValue = @"";
                                [scanner scanString:@"]" intoString:NULL];
                                // look for [mixed value]
                                if ([scanner scanString:@"[" intoString:NULL]) {
                                    if (NO == [scanner scanUpToString:@"]" intoString:&mixedValue]) mixedValue = @"";
                                    [scanner scanString:@"]" intoString:NULL];
                                }
                            }
                        }
						if (NO == [scanner scanUnsignedInteger:&numChars]) numChars = 0;
                        intValue = [pub intValueOfField:key];
                        value = (intValue == 0 ? noValue : (intValue == 1 ? yesValue : mixedValue));
                        if (numChars > 0 && [value length] > numChars) {
                            [parsedStr appendString:[value substringToIndex:numChars]];
                        } else {
                            [parsedStr appendString:value];
                        }
					}
					else {
						NSLog(@"Missing {'field'} after format specifier %%s in format.");
					}
					break;
				}
                case 'i':
				{
                	// arbitrary document info
                    NSString *key = nil;
                    NSString *value = nil;
                    NSUInteger numChars = 0;
					if ([scanner scanString:@"{" intoString:NULL] &&
						[scanner scanUpToString:@"}" intoString:&key] &&
						[scanner scanString:@"}" intoString:NULL]) {
					
						if (NO == [scanner scanUnsignedInteger:&numChars]) numChars = 0;
                        value = [[pub owner] documentInfoForKey:key];
						if ([NSString isEmptyString:value] == NO) {
							value = [self stringByStrictlySanitizingString:value forField:fieldName inFileType:[pub fileType]];
							if (numChars > 0 && [value length] > numChars) {
								[parsedStr appendString:[value substringToIndex:numChars]];
							} else {
								[parsedStr appendString:value];
							}
						}
					}
					else {
						NSLog(@"Missing {'key'} after format specifier %%i in format.");
					}
					break;
				}
                case 'r':
				{
                	// random lowercase letters
					NSUInteger numChars = 1;
                    if (NO == [scanner scanUnsignedInteger:&numChars]) numChars = 1;
					while (numChars-- > 0) {
						[parsedStr appendFormat:@"%c",'a' + (char)(rand() % 26)];
					}
					break;
				}
                case 'R':
				{
                	// random uppercase letters
					NSUInteger numChars = 1;
					if (NO == [scanner scanUnsignedInteger:&numChars]) numChars = 1;
					while (numChars-- > 0) {
						[parsedStr appendFormat:@"%c",'A' + (char)(rand() % 26)];
					}
					break;
				}
                case 'd':
				{
                	// random digits
					NSUInteger numChars = 1;
					if (NO == [scanner scanUnsignedInteger:&numChars]) numChars = 1;
					while (numChars-- > 0) {
						[parsedStr appendFormat:@"%ld",(long)(rand() % 10)];
					}
					break;
				}
                case '0':
				case '1':
				case '2':
				case '3':
				case '4':
				case '5':
				case '6':
				case '7':
				case '8':
				case '9':
				case '%':
				case '[':
				case ']':
				case '-':
				{
                	// escaped character
					[parsedStr appendFormat:@"%C", specifier];
					break;
				}
                case 'u':
				case 'U':
				case 'n':
				{
                	// unique characters, these may only occur once
					if (uniqueSpecifier == 0) {
						uniqueSpecifier = specifier;
						prefixStr = parsedStr;
						parsedStr = [NSMutableString string];
                        if ([scanner scanString:@"[" intoString:NULL]) {
                            [scanner scanUpToString:@"]" intoString:&uniqueSeparator];
                            [scanner scanString:@"]" intoString:NULL];
                        }
						if (NO == [scanner scanUnsignedInteger:&uniqueNumber]) uniqueNumber = 1;
					}
					else {
						NSLog(@"Specifier %%%C can only be used once in the format.", specifier);
					}
					break;
				}
                default: 
					NSLog(@"Unknown format specifier %%%C in format.", specifier);
			}
		}
	}
	
	if (uniqueSpecifier != 0) {
        NSString *suggestedUnique = nil;
        NSUInteger prefixLength = [prefixStr length];
        NSUInteger suffixLength = [parsedStr length];
        NSUInteger suggestionLength = [suggestion length] - prefixLength - suffixLength;
        if (suggestion && ((uniqueNumber == 0 && suggestionLength >= 0) || suggestionLength == uniqueNumber) &&
            (prefixLength == 0 || [suggestion hasPrefix:prefixStr]) && (suffixLength == 0 || [suggestion hasSuffix:parsedStr])) {
            suggestedUnique = [suggestion substringWithRange:NSMakeRange(prefixLength, suggestionLength)];
            if ([uniqueSeparator length] && suggestionLength) {
                if (suggestionLength > [uniqueSeparator length] && [suggestedUnique hasPrefix:uniqueSeparator])
                    suggestedUnique = [suggestedUnique substringFromIndex:[uniqueSeparator length]];
                else
                    suggestedUnique = nil;
            }
        }
		switch (uniqueSpecifier) {
			case 'u':
				// unique lowercase letters
                if (suggestedUnique && [suggestedUnique rangeOfCharacterFromSet:nonLowercaseLetterCharSet].location == NSNotFound) {
                    [parsedStr setString:suggestion];
                } else {
                    [parsedStr setString:[self uniqueString:prefixStr 
                                                     suffix:parsedStr
                                                  separator:uniqueSeparator
                                                   forField:fieldName
                                                     ofItem:pub
                                              numberOfChars:uniqueNumber 
                                                       from:'a' to:'z' 
                                                      force:(uniqueNumber == 0)]];
                }
				break;
			case 'U':
				// unique uppercase letters
                if (suggestedUnique && [suggestedUnique rangeOfCharacterFromSet:nonUppercaseLetterCharSet].location == NSNotFound) {
                    [parsedStr setString:suggestion];
                } else {
                    [parsedStr setString:[self uniqueString:prefixStr 
                                                     suffix:parsedStr
                                                  separator:uniqueSeparator
                                                   forField:fieldName
                                                     ofItem:pub
                                              numberOfChars:uniqueNumber 
                                                       from:'A' to:'Z' 
                                                      force:(uniqueNumber == 0)]];
				}
                break;
			case 'n':
				// unique number
                if (suggestedUnique && [suggestedUnique rangeOfCharacterFromSet:nonDecimalDigitCharSet].location == NSNotFound) {
                    [parsedStr setString:suggestion];
                } else {
                    [parsedStr setString:[self uniqueString:prefixStr 
                                                     suffix:parsedStr
                                                  separator:uniqueSeparator
                                                   forField:fieldName
                                                     ofItem:pub
                                              numberOfChars:uniqueNumber 
                                                       from:'0' to:'9' 
                                                      force:(uniqueNumber == 0)]];
				}
                break;
		}
	}
	
	if([NSString isEmptyString:parsedStr]) {
		NSInteger i = 0;
        NSString *string = nil;
		do {
			string = [@"empty" stringByAppendingFormat:@"%ld", (long)i++];
		} while (NO == [self stringIsValid:string forField:fieldName ofItem:pub]);
		return string;
	} else {
	   return parsedStr;
	}
}

// returns a 'valid' string rather than a 'unique' one
+ (NSString *)uniqueString:(NSString *)baseStr
					suffix:(NSString *)suffix
                 separator:(NSString *)separator
				  forField:(NSString *)fieldName 
					ofItem:(id <BDSKParseableItem>)pub
			 numberOfChars:(NSUInteger)number 
					  from:(unichar)fromChar 
						to:(unichar)toChar 
					 force:(BOOL)force {
	
	NSString *uniqueStr = nil;
	char c;
	
	if (number > 0) {
		for (c = fromChar; c <= toChar; c++) {
			// try with the first added char set to c
			uniqueStr = [baseStr stringByAppendingFormat:@"%@%C", separator ?: @"", c];
			uniqueStr = [self uniqueString:uniqueStr suffix:suffix separator:nil forField:fieldName ofItem:pub numberOfChars:number - 1 from:fromChar to:toChar force:NO];
			if ([self stringIsValid:uniqueStr forField:fieldName ofItem:pub])
				return uniqueStr;
		}
	}
	else {
		uniqueStr = [baseStr stringByAppendingString:suffix];
	}
	
	if (force && NO == [self stringIsValid:uniqueStr forField:fieldName ofItem:pub]) {
		// not unique yet, so try with 1 more char
		return [self uniqueString:baseStr suffix:suffix separator:separator forField:fieldName ofItem:pub numberOfChars:number + 1 from:fromChar to:toChar force:YES];
	}
	
	return uniqueStr;
}

// this might be changed when more fields are available
// do we want to add character checks as in CiteKeyFormatter?
+ (BOOL)stringIsValid:(NSString *)proposedStr forField:(NSString *)fieldName ofItem:(id <BDSKParseableItem>)pub
{
	if ([fieldName isEqualToString:BDSKCiteKeyString]) {
		return [pub isValidCiteKey:proposedStr];
	}
	else if ([fieldName isEqualToString:BDSKLocalFileString] || [fieldName isLocalFileField]) {
		return [pub isValidLocalFilePath:proposedStr];
	}
	else if ([[[NSUserDefaults standardUserDefaults] stringArrayForKey:BDSKRemoteURLFieldsKey] containsObject:fieldName]) {
		if ([NSString isEmptyString:proposedStr])
			return NO;
		return YES;
	}
	else {
		return YES;
	}
}

+ (NSString *)stringBySanitizingString:(NSString *)string forField:(NSString *)fieldName inFileType:(NSString *)type
{
	NSCharacterSet *invalidCharSet = [[BDSKTypeManager sharedManager] invalidCharactersForField:fieldName inFileType:type];
    NSString *newString = nil;

	if ([fieldName isEqualToString:BDSKCiteKeyString]) {
		
		if ([NSString isEmptyString:string]) {
			return @"";
		}
		newString = [string stringByDeTeXifyingString];
		newString = [newString stringByReplacingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
													 withString:@"-"];
		newString = [newString stringByReplacingCharactersInSet:invalidCharSet withString:@""];
		
		return newString;
	}
	else if ([fieldName isEqualToString:BDSKLocalFileString] || [fieldName isLocalFileField]) {
		
		if ([NSString isEmptyString:string]) {
			return @"";
		}
		newString = [string stringByDeTeXifyingString];
		newString = [newString stringByReplacingCharactersInSet:invalidCharSet withString:@""];
		
		return newString;
	}
	else if ([[[NSUserDefaults standardUserDefaults] stringArrayForKey:BDSKRemoteURLFieldsKey] containsObject:fieldName]) {
		
		if ([NSString isEmptyString:string]) {
			return @"";
		}
		newString = [string stringByDeTeXifyingString];
		newString = [newString stringByReplacingCharactersInSet:invalidCharSet withString:@""];
		
		return newString;
	}
	else {
		newString = [string stringByReplacingCharactersInSet:invalidCharSet withString:@""];
		return newString;
	}
}

+ (NSString *)stringByStrictlySanitizingString:(NSString *)string forField:(NSString *)fieldName inFileType:(NSString *)type
{
	NSCharacterSet *invalidCharSet = [[BDSKTypeManager sharedManager] strictInvalidCharactersForField:fieldName inFileType:type];
    NSString *newString = nil;
	NSInteger cleanOption = 0;

	if ([fieldName isEqualToString:BDSKCiteKeyString]) {
		cleanOption = [[NSUserDefaults standardUserDefaults] integerForKey:BDSKCiteKeyCleanOptionKey];
		
		if ([NSString isEmptyString:string]) {
			return @"";
		}
		newString = [string stringByDeTeXifyingString];
		if (cleanOption == 1) {
			newString = [newString stringByRemovingCurlyBraces];
		} else if (cleanOption == 2) {
			newString = [newString stringByRemovingTeX];
		}
		newString = [newString stringByReplacingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
													 withString:@"-"];
		newString = [newString lossyASCIIString];
		newString = [newString stringByReplacingCharactersInSet:invalidCharSet withString:@""];
		
		return newString;
	}
	else if ([fieldName isEqualToString:BDSKLocalFileString] || [fieldName isLocalFileField]) {
		cleanOption = [[NSUserDefaults standardUserDefaults] integerForKey:BDSKLocalFileCleanOptionKey];
		
		if (cleanOption >= 3)
			invalidCharSet = [[BDSKTypeManager sharedManager] veryStrictInvalidCharactersForField:fieldName inFileType:type];
		
		if ([NSString isEmptyString:string]) {
			return @"";
		}
		newString = [string stringByDeTeXifyingString];
		if (cleanOption == 1) {
			newString = [newString stringByRemovingCurlyBraces];
		} else if (cleanOption >= 2) {
			newString = [newString stringByRemovingTeX];
            if (cleanOption == 4)
                newString = [newString lossyASCIIString];
		}
		newString = [newString stringByReplacingCharactersInSet:invalidCharSet withString:@""];
		
		return newString;
	}
	else if ([fieldName isEqualToString:BDSKRemoteURLString] || [fieldName isRemoteURLField]) {
		if ([NSString isEmptyString:string]) {
			return @"";
		}
		newString = [string stringByDeTeXifyingString];
		newString = [newString lossyASCIIString];
		newString = [newString stringByRemovingTeX];
		newString = [newString stringByReplacingCharactersInSet:invalidCharSet withString:@""];
		
		return newString;
	}
	else {
#warning newString unused
		newString = [newString stringByReplacingCharactersInSet:invalidCharSet withString:@""];
		return string;
	}
}

+ (BOOL)validateFormat:(NSString **)formatString forField:(NSString *)fieldName inFileType:(NSString *)type error:(NSString **)error
{
	return [self validateFormat:formatString attributedFormat:NULL forField:fieldName inFileType:type error:error];
}

#define AppendStringToFormatStrings(s, attr) \
	[sanitizedFormatString appendString:s]; \
	[attrString appendString:s attributes:attr]; \
	location = [scanner scanLocation];

+ (BOOL)validateFormat:(NSString **)formatString attributedFormat:(NSAttributedString **)attrFormatString forField:(NSString *)fieldName inFileType:(NSString *)type error:(NSString **)error
{
	static NSCharacterSet *validSpecifierChars = nil;
	static NSCharacterSet *validParamSpecifierChars = nil;
	static NSCharacterSet *validUniqueSpecifierChars = nil;
	static NSCharacterSet *validLocalFileSpecifierChars = nil;
	static NSCharacterSet *validEscapeSpecifierChars = nil;
	static NSCharacterSet *validArgSpecifierChars = nil;
	static NSCharacterSet *validOptArgSpecifierChars = nil;
	static NSCharacterSet *validAuthorSpecifierChars = nil;
	static NSDictionary *specAttr = nil;
	static NSDictionary *paramAttr = nil;
	static NSDictionary *argAttr = nil;
	static NSDictionary *textAttr = nil;
	static NSDictionary *errorAttr = nil;
	
	if (validSpecifierChars == nil) {
		validSpecifierChars = [[NSCharacterSet characterSetWithCharactersInString:@"aApPtTmyYlLebkfwcsirRduUn0123456789%[]"] retain];
		validParamSpecifierChars = [[NSCharacterSet characterSetWithCharactersInString:@"aApPtTkfwciuUn"] retain];
		validUniqueSpecifierChars = [[NSCharacterSet characterSetWithCharactersInString:@"uUn"] retain];
		validLocalFileSpecifierChars = [[NSCharacterSet characterSetWithCharactersInString:@"lLe"] retain];
		validEscapeSpecifierChars = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789%[]"] retain];
		validArgSpecifierChars = [[NSCharacterSet characterSetWithCharactersInString:@"fwcsi"] retain];
		validOptArgSpecifierChars = [[NSCharacterSet characterSetWithCharactersInString:@"aApPTkfwsuUn"] retain];
		validAuthorSpecifierChars = [[NSCharacterSet characterSetWithCharactersInString:@"aApP"] retain];
        
		NSFont *font = [NSFont systemFontOfSize:0];
		NSFont *boldFont = [NSFont boldSystemFontOfSize:0];
		specAttr = [[NSDictionary alloc] initWithObjectsAndKeys:boldFont, NSFontAttributeName, [NSColor blueColor], NSForegroundColorAttributeName, nil];
		paramAttr = [[NSDictionary alloc] initWithObjectsAndKeys:boldFont, NSFontAttributeName, [NSColor colorWithCalibratedRed:0.0 green:0.5 blue:0.0 alpha:1.0], NSForegroundColorAttributeName, nil];
		argAttr = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, [NSColor controlTextColor], NSForegroundColorAttributeName, nil];
		textAttr = [[NSDictionary alloc] initWithObjectsAndKeys:boldFont, NSFontAttributeName, [NSColor controlTextColor], NSForegroundColorAttributeName, nil];
		errorAttr = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, [NSColor redColor], NSForegroundColorAttributeName, nil];
	}
	
	NSCharacterSet *invalidCharSet = [[BDSKTypeManager sharedManager] invalidCharactersForField:fieldName inFileType:type];
	NSCharacterSet *digitCharSet = [NSCharacterSet decimalDigitCharacterSet];
	NSScanner *scanner = [NSScanner scannerWithString:*formatString];
	NSMutableString *sanitizedFormatString = [[NSMutableString alloc] init];
	NSString *string = nil;
	unichar specifier;
	BOOL foundUnique = NO;
	NSMutableAttributedString *attrString = nil;
	NSString *errorMsg = nil;
	NSUInteger location = 0;
	
	if (attrFormatString != NULL)
		attrString = [[NSMutableAttributedString alloc] init];
	
	[scanner setCharactersToBeSkipped:nil];
	
	while (NO == [scanner isAtEnd]) {
		
		// scan non-specifier parts
		if ([scanner scanUpToString:@"%" intoString:&string]) {
			string = [self stringBySanitizingString:string forField:fieldName inFileType:type];
			AppendStringToFormatStrings(string, textAttr);
		}
		if (NO == [scanner scanString:@"%" intoString: NULL]) { // we're at the end, so done
			break;
		}
		
		// found %, so now there should be a specifier char
		if (NO == [scanner scanCharacter:&specifier]) {
			errorMsg = NSLocalizedString(@"Empty specifier % at end of format.", @"Error description");
			break;
		}
		
		// see if it is a valid specifier
		if (NO == [validSpecifierChars characterIsMember:specifier]) {
			errorMsg = [NSString stringWithFormat:NSLocalizedString(@"Invalid specifier %%%C in format.", @"Error description"), specifier];
			break;
		}
		else if ([validEscapeSpecifierChars characterIsMember:specifier] && [invalidCharSet characterIsMember:specifier]) {
			errorMsg = [NSString stringWithFormat: NSLocalizedString(@"Invalid escape specifier %%%C in format.", @"Error description"), specifier];
			break;
		}
		else if ([validUniqueSpecifierChars characterIsMember:specifier]) {
			if (foundUnique) { // a second 'unique' specifier was found
				errorMsg = [NSString stringWithFormat: NSLocalizedString(@"Unique specifier %%%C can appear only once in format.", @"Error description"), specifier];
				break;
			}
			foundUnique = YES;
		}
		else if ([validLocalFileSpecifierChars characterIsMember:specifier] && [fieldName isEqualToString:BDSKLocalFileString] == NO && [fieldName isLocalFileField] == NO) {
			errorMsg = [NSString stringWithFormat: NSLocalizedString(@"Specifier %%%C is only valid in format for local file.", @"Error description"), specifier];
			break;
		}
		string = [NSString stringWithFormat:@"%%%C", specifier];
		AppendStringToFormatStrings(string, specAttr);
		
		// check compulsory argument
		if ([validArgSpecifierChars characterIsMember:specifier]) {
			if ( [scanner isAtEnd] || 
				 NO == [scanner scanString:@"{" intoString: NULL] ||
				 NO == [scanner scanUpToString:@"}" intoString:&string] ||
				 NO == [scanner scanString:@"}" intoString:NULL]) {
				errorMsg = [NSString stringWithFormat: NSLocalizedString(@"Specifier %%%C must be followed by a {'field'} name.", @"Error description"), specifier];
				break;
			}
            if ([string caseInsensitiveCompare:BDSKCiteKeyString] == NSOrderedSame || [string caseInsensitiveCompare:@"Cite-Key"] == NSOrderedSame || [string caseInsensitiveCompare:@"Citekey"] == NSOrderedSame)
				string = BDSKCiteKeyString;
			else if ([string caseInsensitiveCompare:BDSKPubTypeString] == NSOrderedSame)
				string = BDSKPubTypeString;
            else
                string = [[self stringBySanitizingString:string forField:BDSKCiteKeyString inFileType:type] fieldName]; // cite-key sanitization is strict, so we use that for fieldnames
			AppendStringToFormatStrings(@"{", specAttr);
			AppendStringToFormatStrings(string, argAttr);
			AppendStringToFormatStrings(@"}", specAttr);
		}
		
		// check optional arguments
		if ([validOptArgSpecifierChars characterIsMember:specifier]) {
			if (NO == [scanner isAtEnd]) {
				NSInteger i, numOpts = ((specifier == 'A' || specifier == 'P' || specifier == 's')? 3 : ((specifier == 'a' || specifier == 'p' || specifier == 'w')? 2 : 1));
				for (i = 0; i < numOpts && [scanner scanString:@"[" intoString: NULL]; i++) {
					if (NO == [scanner scanUpToString:@"]" intoString:&string]) 
						string = @"";
					if (NO == [scanner scanString:@"]" intoString:NULL]) {
						errorMsg = [NSString stringWithFormat: NSLocalizedString(@"Missing \"]\" after specifier %%%C.", @"Error description"), specifier];
						break;
					}
                    if (specifier != 'w' || i > 0)
                        string = [self stringBySanitizingString:string forField:fieldName inFileType:type];
					AppendStringToFormatStrings(@"[", paramAttr);
					AppendStringToFormatStrings(string, paramAttr);
					AppendStringToFormatStrings(@"]", paramAttr);
				}
				if (errorMsg != nil)
					break;
			}
		}
		
		// check numeric optional parameters
		if ([validParamSpecifierChars characterIsMember:specifier]) {
            if ([validAuthorSpecifierChars characterIsMember:specifier] && [scanner scanString:@"-" intoString:NULL]) {
                if ([scanner scanCharactersFromSet:digitCharSet intoString:&string]) {
                    AppendStringToFormatStrings(@"-", paramAttr);
                    AppendStringToFormatStrings(string, paramAttr);
                } else {
                    [scanner setScanLocation:[scanner scanLocation] - 1];
                }
            } else if ([scanner scanCharactersFromSet:digitCharSet intoString:&string]) {
                AppendStringToFormatStrings(string, paramAttr);
            }
		}
	}
	
    if (foundUnique == NO && [fieldName isEqualToString:BDSKLocalFileString] && errorMsg == nil)
        errorMsg = NSLocalizedString(@"Format for local file requires a unique specifier to ensure unique file names (%u, %U or %n).", @"Error description");
    
	if (errorMsg == nil) {
		// change formatString
		*formatString = [[sanitizedFormatString copy] autorelease];
	} else {
		// there were errors. Don't change formatString, but append the rest to the attributed format
		if (attrString != nil && location < [*formatString length]) {
			string = [*formatString substringFromIndex:location];
			AppendStringToFormatStrings(string, errorAttr);
		}
		if (error != NULL)
			*error = errorMsg;
	}
	if (attrString != nil) 
		*attrFormatString = [attrString autorelease];
	
	[sanitizedFormatString release];
	
	return (errorMsg == nil);
}

+ (NSArray *)requiredFieldsForFormat:(NSString *)formatString
{
	NSMutableArray *arr = [NSMutableArray arrayWithCapacity:3];
    NSUInteger i = 0, j, l = [formatString length];
    
	while (i != NSNotFound && i < l) {
		i = NSMaxRange([formatString rangeOfString:@"%" options:0 range:NSMakeRange(i, l - i)]);
        if (i == NSNotFound || i >= l) break;
        switch ([formatString characterAtIndex:i]) {
			case 'a':
			case 'A':
				[arr addObject:BDSKAuthorString];
				break;
			case 'p':
			case 'P':
				[arr addObject:BDSKAuthorEditorString];
				break;
			case 't':
			case 'T':
				[arr addObject:BDSKTitleString];
				break;
			case 'y':
			case 'Y':
				[arr addObject:BDSKYearString];
				break;
			case 'm':
				[arr addObject:BDSKMonthString];
				break;
			case 'l':
			case 'L':
			case 'e':
				[arr addObject:BDSKLocalFileString];
				break;
			case 'b':
				[arr addObject:@"Document Filename"];
				break;
            case 'k':
                [arr addObject:BDSKKeywordsString];
                break;
			case 'f':
			case 'c':
                j = [formatString rangeOfString:@"}" options:0 range:NSMakeRange(i, l - i)].location;
                if (j != NSNotFound && j > i + 2)
                    [arr addObject:[formatString substringWithRange:NSMakeRange(i + 2, j - i - 2)]];
                break;
			case 'i':
                j = [formatString rangeOfString:@"}" options:0 range:NSMakeRange(i, l - i)].location;
                if (j != NSNotFound && j > i + 2)
                    [arr addObject:[@"Document: " stringByAppendingString:[formatString substringWithRange:NSMakeRange(i + 2, j - i - 2)]]];
				break;
            default:
                break;
		}
        i++;
	}
	return arr;
}

@end

#pragma mark -

@implementation BDSKFormatStringFieldEditor

- (id)initWithFrame:(NSRect)frameRect parseField:(NSString *)field fileType:(NSString *)fileType;
{
    // initWithFrame sets up the entire text system for us
    if(self = [super initWithFrame:frameRect]){
        BDSKASSERT(field != nil);
        parseField = [field copy];
        
        BDSKASSERT(fileType != nil);
        parseFileType = [fileType copy];
    }
    return self;
}

- (void)dealloc
{
    [parseFileType release];
    [parseField release];
    [super dealloc];
}

- (BOOL)isFieldEditor { return YES; }

- (void)recolorText
{
    NSTextStorage *textStorage = [self textStorage];
    NSUInteger length = [textStorage length];
    
    NSRange range;
    NSDictionary *attributes;
    
    range.length = 0;
    range.location = 0;
	
    // get the attributed string from the format parser
    NSAttributedString *attrString = nil;
    NSString *format = [[[self string] copy] autorelease]; // pass a copy so we don't change the backing store of our text storage
    [BDSKFormatParser validateFormat:&format attributedFormat:&attrString forField:parseField inFileType:parseFileType error:NULL];   
    
	if ([[self string] isEqualToString:[attrString string]] == NO) 
		return;
    
    // get the attributes of the parsed string and apply them to our NSTextStorage; it may not be safe to set it directly at this point
    NSUInteger start = 0;
    while(start < length){
        
        attributes = [attrString attributesAtIndex:start effectiveRange:&range];        
        [textStorage setAttributes:attributes range:range];
        
        start += range.length;
    }
}    

// this is a convenient override point that gets called often enough to recolor everything
- (void)setSelectedRange:(NSRange)charRange
{
    [super setSelectedRange:charRange];
    [self recolorText];
}

- (void)didChangeText
{
    [super didChangeText];
    [self recolorText];
}

@end

@implementation BDSKFormatStringFormatter

- (id)initWithField:(NSString *)field fileType:(NSString *)fileType; {
    // initWithFrame sets up the entire text system for us
    if(self = [super init]){
        BDSKASSERT(field != nil);
        parseField = [field copy];
        
        BDSKASSERT(fileType != nil);
        parseFileType = [fileType copy];
    }
    return self;
}

- (void)dealloc
{
    [parseFileType release];
    [parseField release];
    [super dealloc];
}

- (NSString *)stringForObjectValue:(id)obj{
    return obj;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary *)attrs{
    NSAttributedString *attrString = nil;
    NSString *format = [[obj copy] autorelease];
    
	[BDSKFormatParser validateFormat:&format attributedFormat:&attrString forField:parseField inFileType:parseFileType error:NULL];
    
    return attrString;
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error{
    *obj = string;
    return YES;
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString **)error{
    NSAttributedString *attrString = nil;
    NSString *format = [[*partialStringPtr copy] autorelease];
    
	[BDSKFormatParser validateFormat:&format attributedFormat:&attrString forField:parseField inFileType:parseFileType error:NULL];
    format = [attrString string];
	
	if (NO == [format isEqualToString:*partialStringPtr]) {
		NSUInteger length = [format length];
		*partialStringPtr = format;
		if ([format isEqualToString:origString]) 
			*proposedSelRangePtr = origSelRange;
		else if (NSMaxRange(*proposedSelRangePtr) > length){
			if ((*proposedSelRangePtr).location <= length)
				*proposedSelRangePtr = NSIntersectionRange(*proposedSelRangePtr, NSMakeRange(0, length));
			else
				*proposedSelRangePtr = NSMakeRange(length, 0);
		}
		return NO;
	} else return YES;
}


@end


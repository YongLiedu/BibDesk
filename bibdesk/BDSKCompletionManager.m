//
//  BDSKCompletionManager.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 5/17/08.
/*
 This software is Copyright (c) 2008-2009
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

#import "BDSKCompletionManager.h"
#import "BDSKStringConstants.h"
#import "BDSKTypeManager.h"
#import "NSArray_BDSKExtensions.h"
#import "CFString_BDSKExtensions.h"


@implementation BDSKCompletionManager

static id sharedManager = nil;

+ (id)sharedManager {
    if (sharedManager == nil)
        sharedManager = [[self alloc] init];
    return sharedManager;
}

- (id)init {
    BDSKPRECONDITION(sharedManager == nil);
    if(self = [super init]) {
        autoCompletionDict = [[NSMutableDictionary alloc] initWithCapacity:15]; // arbitrary
    }
    return self;
}

- (void)addNamesForCompletion:(NSArray *)names {
    NSMutableSet *nameSet = [autoCompletionDict objectForKey:BDSKAuthorString];
    if (nil == nameSet) {
        nameSet = [[NSMutableSet alloc] initWithCapacity:500];
        [autoCompletionDict setObject:nameSet forKey:BDSKAuthorString];
        [nameSet release];
    }
    for (NSString *name in names)
        [nameSet addObject:([name isComplex] ? [NSString stringWithString:name] : name)];
}

- (void)addString:(NSString *)string forCompletionEntry:(NSString *)entry{
    
	if(BDIsEmptyString((CFStringRef)entry) || [entry isNumericField] || [entry isURLField] || [entry isPersonField] || [entry isCitationField] || [entry hasPrefix:@"Bdsk-"])	
		return;

    if([entry isEqualToString:BDSKBooktitleString])	
		entry = BDSKTitleString;
	
	NSMutableSet *completionSet = [autoCompletionDict objectForKey:entry];
	
    if (completionSet == nil) {
        completionSet = [[NSMutableSet alloc] initWithCapacity:500];
        [autoCompletionDict setObject:completionSet forKey:entry];
        [completionSet release];
    }
    
    // more efficient for the splitting and checking functions
    // also adding complex strings can lead to a crash after the containing document closes
    if([string isComplex]) string = [NSString stringWithString:string];

    if([entry isSingleValuedField]){ // add the whole string 
        [completionSet addObject:[string stringByCollapsingAndTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
        return;
    }
    
    NSCharacterSet *acSet = [[BDSKTypeManager sharedManager] separatorCharacterSetForField:entry];
    if([string rangeOfCharacterFromSet:acSet].location != NSNotFound){
        [completionSet addObjectsFromArray:[string componentsSeparatedByCharactersInSet:acSet trimWhitespace:YES]];
    } else if([entry isEqualToString:BDSKKeywordsString]){
        // if it wasn't punctuated, try this; Elsevier uses "and" as a separator, and it's annoying to have the whole string autocomplete on you
        [completionSet addObjectsFromArray:[[string componentsSeparatedByString:@" and "] arrayByPerformingSelector:@selector(stringByCollapsingWhitespaceAndRemovingSurroundingWhitespace)]];
    } else {
        [completionSet addObject:[string stringByCollapsingAndTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    }
}

- (NSSet *)stringsForCompletionEntry:(NSString *)entry{
    NSSet* autoCompleteStrings = [autoCompletionDict objectForKey:entry];
	if (autoCompleteStrings)
		return autoCompleteStrings;
	else 
		return [NSSet set];
}

- (NSRange)entry:(NSString *)entry rangeForUserCompletion:(NSRange)charRange ofString:(NSString *)fullString {
    NSCharacterSet *wsCharSet = [NSCharacterSet whitespaceCharacterSet];
    NSCharacterSet *acSet = [[BDSKTypeManager sharedManager] separatorCharacterSetForField:entry];

	if ([entry isEqualToString:BDSKEditorString])	
		entry = BDSKAuthorString;
	else if ([entry isEqualToString:BDSKBooktitleString])	
		entry = BDSKTitleString;
	
	// find a string to match, be consistent with addString:forCompletionEntry:
	NSRange searchRange = NSMakeRange(0, charRange.location);
	// find the first separator preceding the current word being entered
    NSRange punctuationRange = [fullString rangeOfCharacterFromSet:acSet
														   options:NSBackwardsSearch
															 range:searchRange];
    NSRange andRange = [fullString rangeOfString:@" and "
										 options:NSBackwardsSearch | NSLiteralSearch
										   range:searchRange];
	NSUInteger matchStart = 0;
	// now find the beginning of the match, reflecting addString:forCompletionEntry:. We might be more sophisticated, like in groups
    if ([entry isPersonField]) {
		// these are delimited by "and"
		if (andRange.location != NSNotFound)
			matchStart = NSMaxRange(andRange);
    } else if([entry isSingleValuedField]){
		// these are added as the whole string. Shouldn't there be more?
	} else if (punctuationRange.location != NSNotFound) {
		// should we delimited by these punctuations by default?
		matchStart = NSMaxRange(punctuationRange);
	} else if ([entry isEqualToString:BDSKKeywordsString] && andRange.location != NSNotFound) {
		// keywords can be delimited also by "and"
		matchStart = NSMaxRange(andRange);
    }
	// ignore leading spaces
	while (matchStart < charRange.location && [wsCharSet characterIsMember:[fullString characterAtIndex:matchStart]])
		matchStart++;
	return NSMakeRange(matchStart, NSMaxRange(charRange) - matchStart);
}

- (NSArray *)entry:(NSString *)entry completions:(NSArray *)words forPartialWordRange:(NSRange)charRange ofString:(NSString *)fullString indexOfSelectedItem:(NSInteger *)idx {
    // all persons are keyed to author
	if ([entry isPersonField])	
		entry = BDSKAuthorString;
	else if ([entry isEqualToString:BDSKBooktitleString])	
		entry = BDSKTitleString;
	else if ([entry isCitationField])	
		entry = BDSKCrossrefString;
	
	NSString *matchString = [[fullString substringWithRange:charRange] stringByRemovingCurlyBraces];
    
    // in case this is only a brace, return an empty array to avoid returning every value in the file
    if([matchString isEqualToString:@""])
        return [NSArray array];
    
    NSSet *strings = [self stringsForCompletionEntry:entry];
    NSString *string = nil;
    NSMutableArray *completions = [NSMutableArray arrayWithCapacity:[strings count]];

    for (string in strings) {
        if ([[string stringByRemovingCurlyBraces] hasCaseInsensitivePrefix:matchString])
            [completions addObject:string];
    }
    
    [completions sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
	NSInteger i, count = [completions count];
	for (i = 0; i < count; i++) {
        string = [completions objectAtIndex:i];
		if ([[string stringByRemovingCurlyBraces] caseInsensitiveCompare:matchString]) {
            *idx = i;
			break;
		}
    }
    
    return completions;
}

- (NSRange)rangeForUserCompletion:(NSRange)charRange forBibTeXString:(NSString *)fullString {
    static NSCharacterSet *punctuationCharSet = nil;
	if (punctuationCharSet == nil) {
		NSMutableCharacterSet *tmpSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
		[tmpSet addCharactersInString:@"#"];
		punctuationCharSet = [tmpSet copy];
		[tmpSet release];
	}
	// we extend, as we use a different set of punctuation characters as Apple does
	NSUInteger prefixLength = 0;
	while (charRange.location > prefixLength && ![punctuationCharSet characterIsMember:[fullString characterAtIndex:charRange.location - prefixLength - 1]]) 
		prefixLength++;
	if (prefixLength > 0) {
		charRange.location -= prefixLength;
		charRange.length += prefixLength;
	}
	return charRange;
}

- (NSArray *)possibleMatches:(NSDictionary *)definitions forBibTeXString:(NSString *)fullString partialWordRange:(NSRange)charRange indexOfBestMatch:(NSInteger *)idx{
    NSString *partialString = [fullString substringWithRange:charRange];
    NSMutableArray *matches = [NSMutableArray arrayWithCapacity:[definitions count]];
    NSString *key = nil;
    
    // Search the definitions case-insensitively; we match on key or value, but only return keys.
    for (key in definitions) {
        if ([key rangeOfString:partialString options:NSCaseInsensitiveSearch].location != NSNotFound ||
			([definitions valueForKey:key] != nil && [[definitions valueForKey:key] rangeOfString:partialString options:NSCaseInsensitiveSearch].location != NSNotFound))
            [matches addObject:key];
    }
    [matches sortUsingSelector:@selector(caseInsensitiveCompare:)];

    NSInteger i, count = [matches count];
    for (i = 0; i < count; i++) {
        key = [matches objectAtIndex:i];
        if ([key hasPrefix:partialString]) {
            // If the key has the entire partialString as prefix, it's a good match, so we'll select it by default.
            *idx = i;
			break;
        }
    }

    return matches;
}

@end

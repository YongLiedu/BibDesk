// Copyright 1997-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/NSMutableString-OFExtensions.h>

#import <OmniFoundation/OFStringDecoder.h>
#import <OmniFoundation/OFStringScanner.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease_2007-10-25/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSMutableString-OFExtensions.m 93428 2007-10-25 16:36:11Z kc $")

@implementation NSMutableString (OFExtensions)

- (void)replaceAllOccurrencesOfCharactersInSet:(NSCharacterSet *)set withString:(NSString *)replaceString;
{
    NSRange characterRange, searchRange;
    unsigned int replaceStringLength;

    searchRange = NSMakeRange(0, [self length]);
    replaceStringLength = [replaceString length];
    while ((characterRange = [self rangeOfCharacterFromSet:set options:NSLiteralSearch range:searchRange]).length) {
	[self replaceCharactersInRange:characterRange withString:replaceString];
	searchRange.location = characterRange.location + replaceStringLength;
	searchRange.length = [self length] - searchRange.location;
	if (searchRange.length == 0)
	    break; // Might as well save that extra method call.
    }
}

// This is similar to the above, but replaces contiguous sequences of characters from the pattern set with a single occurrence of the replacement string
- (void)collapseAllOccurrencesOfCharactersInSet:(NSCharacterSet *)set toString:(NSString *)replaceString;
{
    NSRange characterRange, searchRange, replaceRange;
    unsigned int replaceStringLength, selfLength;

    replaceStringLength = [replaceString length];
    selfLength = [self length];
    characterRange = [self rangeOfCharacterFromSet:set options:NSLiteralSearch range:NSMakeRange(0, selfLength)];
    while (characterRange.length > 0) {
        replaceRange = characterRange;
        searchRange.location = replaceRange.location + replaceRange.length;
        searchRange.length = selfLength - searchRange.location;
        for (;;) {
            characterRange = [self rangeOfCharacterFromSet:set options:NSLiteralSearch range:searchRange];
            if (characterRange.length == 0 ||
                characterRange.location != searchRange.location)
                break;
            replaceRange.length += characterRange.length;
            searchRange.length -= characterRange.length;
            searchRange.location += characterRange.length;
        }
        [self replaceCharactersInRange:replaceRange withString:replaceString];
        characterRange.location += replaceStringLength - replaceRange.length;
        selfLength += replaceStringLength - replaceRange.length;
        OBASSERT(selfLength == [self length]);
    }
}

- (BOOL)replaceAllOccurrencesOfString:(NSString *)matchString withString:(NSString *)newString;
{
    OBPRECONDITION([matchString length] != 0);
    if ([matchString length] == 0)
        return NO; // Perhaps raise an NSInvalidArgumentException instead?  Or modify the API so we can return an NSError?

    OFStringScanner *scanner = [[OFStringScanner alloc] initWithString:self];
    if (![scanner scanUpToString:matchString]) {
        [scanner release];
        return NO;
    }

    NSMutableString *replacementString = [[NSMutableString alloc] init];
    unsigned int matchStringLength = [matchString length];
    unsigned int lastPosition = 0;

    do {
        NSRange copyRange = NSMakeRange(lastPosition, [scanner scanLocation] - lastPosition);
        [replacementString appendString:[self substringWithRange:copyRange]];
        [replacementString appendString:newString];
        lastPosition += copyRange.length + matchStringLength;
        [scanner skipCharacters:matchStringLength];
    } while ([scanner scanUpToString:matchString]);

    [replacementString appendString:[self substringFromIndex:lastPosition]];
    [self setString:replacementString];
    [replacementString release];
    [scanner release];

    return YES;
}

- (BOOL)replaceAllOccurrencesOfRegularExpressionString:(NSString *)matchString withString:(NSString *)newString;
{
    NSString *replacementString = [self stringByReplacingAllOccurrencesOfRegularExpressionString:matchString withString:newString];
    if (replacementString == self) {
        return NO;
    } else {
        [self setString:replacementString];
        return YES;
    }
}

- (void)replaceAllLineEndingsWithString:(NSString *)newString;
{
    // It might be nice to make this more efficient by doing everything in one pass rather than three (but this was sure simpler to write!)
    [self replaceAllOccurrencesOfString:@"\r\n" withString:@"\n"];
    [self replaceAllOccurrencesOfString:@"\r" withString:@"\n"];
    if (![@"\n" isEqualToString:newString]) // Trivial optimization of a reasonably likely case
        [self replaceAllOccurrencesOfString:@"\n" withString:newString];
}

- (void)appendCharacter:(unsigned int)aCharacter;
{
    unichar utf16[2];
    
    OBASSERT(sizeof(aCharacter)*CHAR_BIT >= 21);
    /* aCharacter must be at least 21 bits to contain a full Unicode character */
    
    if (aCharacter <= 0xFFFF) {
        utf16[0] = (unichar)aCharacter;
        /* There isn't a particularly efficient way to do this using the ObjC interface, so... */
        CFStringAppendCharacters((CFMutableStringRef)self, utf16, 1);
    } else {
        /* Convert Unicode characters in supplementary planes into pairs of UTF-16 surrogates */
        OFCharacterToSurrogatePair(aCharacter, utf16);
        CFStringAppendCharacters((CFMutableStringRef)self, utf16, 2);
    }
}

- (void)appendStrings: (NSString *)first, ...
{
    va_list argList;
    NSString *next;

    if (!first)
        return;

    [self appendString:first];

    va_start(argList, first);
    while ((next = va_arg(argList, NSString *)))
        [self appendString:next];
    va_end(argList);
}

- (void)removeSurroundingWhitespace;
{
    NSCharacterSet *nonWhitespace = [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
    NSRange firstValidCharacter, lastValidCharacter;
    
    firstValidCharacter = [self rangeOfCharacterFromSet:nonWhitespace];
    if (firstValidCharacter.length == 0) {
	[self setString:@""];
        return;
    }
    
    lastValidCharacter = [self rangeOfCharacterFromSet:nonWhitespace options:NSBackwardsSearch];
    // Delete tail first.  If we delete the head first, the range for the tail would need to be offset.
    if (lastValidCharacter.length > 0 && NSMaxRange(lastValidCharacter) < [self length])
        [self deleteCharactersInRange:NSMakeRange(NSMaxRange(lastValidCharacter), [self length] - NSMaxRange(lastValidCharacter))];
    if (firstValidCharacter.length > 0 && firstValidCharacter.location > 0)
        [self deleteCharactersInRange:NSMakeRange(0, firstValidCharacter.location)];
}

@end

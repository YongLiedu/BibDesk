//
//  BDSKFieldNameFormatter.m
//  BibDesk
//
//  Created by Michael McCracken on Sat Sep 27 2003.
/*
 This software is Copyright (c) 2003-2011
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

//
//  File Description: BDSKFieldNameFormatter
//
//  This is a formatter that makes sure you can't enter invalid field names.
//



#import "BDSKFieldNameFormatter.h"


@implementation BDSKFieldNameFormatter

- (id)delegate {
    return delegate;
}

- (void)setDelegate:(id)newDelegate {
    BDSKPRECONDITION(newDelegate == nil || [newDelegate respondsToSelector:@selector(fieldNameFormatterKnownFieldNames:)]);
    delegate = newDelegate;
}

- (NSString *)stringForObjectValue:(id)obj{
    return obj;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary *)attrs{
    return [[[NSAttributedString alloc] initWithString:[self stringForObjectValue:obj] attributes:attrs] autorelease];
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error{
    // first check the delegate for known field names, which may include special names containing spaces such as Cite Key, this is called on Leopard when auto-completing an item from the combobox
    if ([[delegate fieldNameFormatterKnownFieldNames:self] containsObject:string]) {
        *obj = string;
        return YES;
    }
    NSCharacterSet *invalidSet = [[BDSKTypeManager sharedManager] invalidFieldNameCharacterSet];
    NSRange r = [string rangeOfCharacterFromSet:invalidSet];
    if (r.location != NSNotFound) {
        if (error) *error = NSLocalizedString(@"The field name contains an invalid character", @"field name warning");
		return NO;
    }
    if ([string length] && [[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[string characterAtIndex:0]]) {
        if (error) *error = NSLocalizedString(@"The first character must not be a digit", @"field name warning");
		return NO; // BibTeX chokes if the first character of a field name is a digit
    }
    if ([string hasPrefix:@"Bdsk-File"]) {
        if (error) *error = NSLocalizedString(@"\"Bdsk-File\" fields are reserved for BibDesk's internal usage", @"field name warning");
        return NO;
    }
    else if ([string hasPrefix:@"Bdsk-Url"]) {
        if (error) *error = NSLocalizedString(@"\"Bdsk-Url\" fields are reserved for BibDesk's internal usage", @"field name warning");
        return NO;
    }
    else {
        *obj = string;
        return YES;
    }
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString **)error {
    NSString *partialString = *partialStringPtr;
    // first check the delegate for known field names, which may include special names containing spaces such as Cite Key, this is called on Leopard when auto-completing an item from the combobox
    if ([[delegate fieldNameFormatterKnownFieldNames:self] containsObject:partialString]) {
        return YES;
    }
    NSCharacterSet *invalidSet = [[BDSKTypeManager sharedManager] invalidFieldNameCharacterSet];
    NSRange r = [partialString rangeOfCharacterFromSet:invalidSet];
    if (r.location != NSNotFound) {
        if (error) *error = NSLocalizedString(@"The field name contains an invalid character", @"field name warning");
        NSMutableString *new = [[partialString mutableCopy] autorelease];
        [new replaceOccurrencesOfCharactersInSet:invalidSet withString:@""];
        if ([new length]) {
            *partialStringPtr = new;
            if (NSMaxRange(*proposedSelRangePtr) > [new length])
                *proposedSelRangePtr = NSMakeRange(r.location, 0);
        } else {
            *partialStringPtr = origString;
            *proposedSelRangePtr = origSelRange;
        }
		return NO;
    } else if ([partialString length] && [[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[partialString characterAtIndex:0]]) {
        *partialStringPtr = nil;
        if (error) *error = NSLocalizedString(@"The first character must not be a digit", @"field name warning");
		return NO; // BibTeX chokes if the first character of a field name is a digit
    }
	NSString *capitalizedString = [partialString fieldName];
    if (![capitalizedString isEqualToString:partialString]) {
		// This is a BibDesk requirement, since we expect field names to be capitalized; BibTeX is case-insensitive of itself.  This will convert "FieldName" to "Fieldname" and "Field-name" to "Field-Name".
		*partialStringPtr = capitalizedString;
        if (error) *error = NSLocalizedString(@"Field names must be capitalized in BibDesk", @"field name warning");
		return NO;
	} else return YES;
}


@end

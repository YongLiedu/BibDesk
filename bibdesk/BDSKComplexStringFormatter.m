//  BDSKComplexStringFormatter.m

//  Created by Michael McCracken on Mon Jul 22 2002.
/*
 This software is Copyright (c) 2002-2009
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

#import "BDSKComplexStringFormatter.h"
#import "BDSKComplexString.h"
#import "NSString_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import "BDSKMacroResolver.h"

@implementation BDSKComplexStringFormatter

- (id)init {
    return [self initWithDelegate:nil macroResolver:nil];
}

- (id)initWithDelegate:(id<BDSKComplexStringFormatterDelegate>)anObject macroResolver:(BDSKMacroResolver *)aMacroResolver {
    if (self = [super init]) {
		editAsComplexString = NO;
		[self setMacroResolver:aMacroResolver];
		[self setDelegate:anObject];
    }
    return self;
}

- (void)dealloc {
    [macroResolver release];
    [super dealloc];
}

#pragma mark Implementation of formatter methods

- (NSString *)stringForObjectValue:(id)obj {
    return obj;
}

- (NSString *)editingStringForObjectValue:(id)obj {
	NSString *string = [self stringForObjectValue:obj];
	if ([obj isComplex] && editAsComplexString == NO) {
		if ([delegate respondsToSelector:@selector(formatter:shouldEditAsComplexString:)])
			editAsComplexString = [delegate formatter:self shouldEditAsComplexString:obj];
	}
	return editAsComplexString ? [string stringAsBibTeXString] : string;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary *)defaultAttrs{

    if ([obj isComplex] == NO && [obj isInherited] == NO)
        return nil;
    
    NSMutableDictionary *attrs = [[NSMutableDictionary alloc] initWithDictionary:defaultAttrs];
	NSColor *color = nil;
	BOOL highlighted = [[[attrs objectForKey:NSForegroundColorAttributeName] colorUsingColorSpaceName:NSDeviceRGBColorSpace] isEqual:[NSColor colorWithDeviceRed:1 green:1 blue:1 alpha:1]];
    
	if ([obj isComplex]) {
		if ([obj isInherited]) {
			if (highlighted)
				color = [[NSColor blueColor] blendedColorWithFraction:0.5 ofColor:[NSColor controlBackgroundColor]];
			else
				color = [[NSColor blueColor] blendedColorWithFraction:0.4 ofColor:[NSColor controlBackgroundColor]];
		} else {
			if (highlighted)
				color = [[NSColor blueColor] blendedColorWithFraction:0.8 ofColor:[NSColor controlBackgroundColor]];
			else
				color = [NSColor blueColor];
		}
	} else if ([obj isInherited]) {
        if (highlighted)
            color = [NSColor lightGrayColor];
        else
            color = [NSColor disabledControlTextColor];
	}
	if (color)
        [attrs setObject:color forKey:NSForegroundColorAttributeName];
    NSAttributedString *attStr = [[[NSAttributedString alloc] initWithString:obj attributes:attrs] autorelease];
    [attrs release];
	return attStr;
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error{
    
    // convert newlines to a single space, then collapse (mainly for paste/drag text, RFE #1457532)
    if([string rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].length){
        string = [string stringByReplacingCharactersInSet:[NSCharacterSet newlineCharacterSet] withString:@" "];
        string = [string stringByCollapsingAndTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    // remove control and other non-characters (mainly for paste/drag text, BUG #1481675)
    string = [string stringByReplacingCharactersInSet:[NSCharacterSet controlCharacterSet] withString:@""];
    string = [string stringByReplacingCharactersInSet:[NSCharacterSet illegalCharacterSet] withString:@""];
    
    if (editAsComplexString) {
        NSError *complexError = nil;
        string = [NSString stringWithBibTeXString:string macroResolver:macroResolver error:&complexError];
        if (string == nil && error)
            *error = [complexError localizedDescription];
    } else if ([string isStringTeXQuotingBalancedWithBraces:YES connected:NO] == NO) {
        string = nil;
        if (error)
            *error = NSLocalizedString(@"Unbalanced braces", @"error description");
    }
    
    if (string == nil)
        return NO;
    else if (obj)
        *obj = string;
    return YES;
}

#pragma mark Accessors

- (id)macroResolver {
    return macroResolver;
}

- (void)setMacroResolver:(BDSKMacroResolver *)newMacroResolver {
    if (macroResolver != newMacroResolver) {
        [macroResolver release];
        macroResolver = [newMacroResolver retain];
    }
}

- (BOOL)editAsComplexString {
	return editAsComplexString;
}

- (void)setEditAsComplexString:(BOOL)newEditAsComplexString {
	if (editAsComplexString != newEditAsComplexString) {
		editAsComplexString = newEditAsComplexString;
	}
}

- (id<BDSKComplexStringFormatterDelegate>)delegate {
    return delegate;
}

- (void)setDelegate:(id<BDSKComplexStringFormatterDelegate>)newDelegate {
	delegate = newDelegate;
}

@end

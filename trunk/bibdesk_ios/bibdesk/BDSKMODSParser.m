//
//  BDSKMODSParser.m
//  Bibdesk
//
//  Created by Adam Maxwell on 05/14/07.
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

#import "BDSKMODSParser.h"
#import "BDSKMARCParser.h"

@interface NSString (BDSKMODSParserExtensions)
- (BOOL)isMODSString;
@end


@implementation BDSKMODSParser

static NSData *MODSToMARCXSLTData = nil;

+ (void)initialize{
    BDSKINITIALIZE;
    MODSToMARCXSLTData = [[NSData alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"MODS2MARC21slim" ofType:@"xsl"] options:NSMappedRead error:NULL];
}

+ (BOOL)canParseString:(NSString *)string{
	return [string isMODSString];
}

+ (NSArray *)itemsFromString:(NSString *)itemString error:(NSError **)outError {
    
    if (nil == itemString)
        return [NSArray array];
    
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:itemString options:0 error:outError];
    if (nil == doc)
        return [NSArray array];
    
    NSXMLDocument *marcDoc = [doc objectByApplyingXSLT:MODSToMARCXSLTData arguments:nil error:outError];
    [doc autorelease];
    if (nil == marcDoc)
        return [NSArray array];
    
    NSData *xmlData = [marcDoc XMLData];
    NSString *encodingName = [marcDoc characterEncoding];
    NSStringEncoding encoding = 0;
    if (encodingName) {
        CFStringEncoding cfEnc = CFStringConvertIANACharSetNameToEncoding((CFStringRef)encodingName);
        if (kCFStringEncodingInvalidId == cfEnc)
            encoding = NSUTF8StringEncoding;
        else
            encoding = CFStringConvertEncodingToNSStringEncoding(cfEnc);
    }
    
    NSString *xmlString = [[NSString alloc] initWithData:xmlData encoding:encoding];
    NSArray *parsedItems = [BDSKMARCParser itemsFromMARCXMLString:xmlString error:outError];
    [xmlString release];
    
    return parsedItems;
}

@end

@implementation NSString (BDSKMODSParserExtensions)

- (BOOL)isMODSString {
    // as of 5 November 2007, COPAC MODS no longer has an <?xml prefix, and starts with <mods xmlns:xlink="http://www.w3.org/1999/xlink"
    if ([self rangeOfString:@"<mods"].location == NSNotFound)
        return NO;
    
    NSError *nsError;
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:self options:0 error:&nsError];
    if (nil == doc)
        return NO;
    
    NSXMLDocument *marcDoc = [doc objectByApplyingXSLT:MODSToMARCXSLTData arguments:nil error:&nsError];
    [doc release];
    if (nil == marcDoc)
        return NO;
    
    return YES;
}

@end

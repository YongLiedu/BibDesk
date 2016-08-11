//
//  BDSKDOIParser.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/11/16.
/*
 This software is Copyright (c) 2016
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

#import "BDSKDOIParser.h"
#import "BDSKBibTeXParser.h"
#import "NSURL_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"

@implementation BDSKDOIParser

+ (BOOL)canParseString:(NSString *)string{
    string = [string lowercaseString];
    return ([string hasPrefix:@"doi:10."] || [string hasPrefix:@"http://doi.org/10."] || [string hasPrefix:@"https://doi.org/10."] || [string hasPrefix:@"http://dx.doi.org/10."] || [string hasPrefix:@"https://dx.doi.org/10."] || [string hasPrefix:@"10."]) &&
    [string rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location == NSNotFound;
}

// See http://www.crossref.org/CrossTech/2011/11/turning_dois_into_formatted_ci.html

+ (NSArray *)itemsFromString:(NSString *)itemString error:(NSError **)outError{
    // DOI manual says this is a safe URL to resolve with for the foreseeable future
    NSURL *baseURL = [NSURL URLWithString:@"http://dx.doi.org/"];
    // remove any text prefix, which is not required for a valid DOI, but may be present; DOI starts with "10"
    // http://www.doi.org/handbook_2000/enumeration.html#2.2
    NSRange range = [itemString rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]];
    if(range.length && range.location > 0)
        itemString = [itemString substringFromIndex:range.location];
    itemString = [itemString stringByAddingPercentEscapes];
    NSURL *doiURL = [[NSURL URLWithStringByNormalizingPercentEscapes:itemString baseURL:baseURL] absoluteURL];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:doiURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:1.0];
    [request setValue:@"text/bibliography; style=bibtex" forHTTPHeaderField:@"Accept"];
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *result = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSString *bibtexString = nil;
    NSArray *items = nil;
    
    if (result)
        bibtexString = [[[[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding] autorelease] stringByRemovingSurroundingWhitespace];
    if ([BDSKBibTeXParser canParseString:bibtexString])
        items = [BDSKBibTeXParser itemsFromString:bibtexString owner:nil error:&error];
    
    if ([items count] == 0 && outError) *outError = error ?: [NSError localErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Unable to get bibtex data for DOI", @"Error description")];
    
    return items;
}

@end

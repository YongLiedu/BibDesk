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
#import "BibItem.h"
#import <AGRegex/AGRegex.h>

@implementation BDSKDOIParser

+ (BOOL)canParseString:(NSString *)string{
    AGRegex *doiRegex = [AGRegex regexWithPattern:@"^((doi:)|(https?://(dx\\.)?doi\\.org/))?10\\.[0-9]{4,}(\\.[0-9]+)*/\\S+$"];
    return [doiRegex findInString:string] != nil;
}

// See http://www.crossref.org/CrossTech/2011/11/turning_dois_into_formatted_ci.html

+ (NSArray *)itemsFromString:(NSString *)itemString error:(NSError **)outError{
    BibItem *item = [BibItem itemWithDOI:itemString owner:nil];
    
    if (item == nil && outError) *outError = [NSError localErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Unable to get bibtex data for DOI", @"Error description")];
    
    return item ? [NSArray arrayWithObject:item] : nil;
}

@end

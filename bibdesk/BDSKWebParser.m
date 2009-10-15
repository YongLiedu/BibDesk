//
//  BDSKWebParser.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 4/2/07.
/*
 This software is Copyright (c) 2007-2009
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

#import "BDSKWebParser.h"
#import "BDSKHCiteParser.h"
#import "BDSKCiteULikeParser.h"
#import "BDSKACMDLParser.h"
#import "BDSKHubmedParser.h"
#import "BDSKGoogleScholarParser.h"
#import "BDSKSpiresParser.h"
#import "BDSKArxivParser.h"
#import "BDSKMathSciNetParser.h"
#import "BDSKZentralblattParser.h"
#import "BDSKMathSiteParser.h"
#import "BDSKCOinSParser.h"
#import "BDSKIEEEXploreParser.h"
#import "NSError_BDSKExtensions.h"
#import "BDSKRuntime.h"

#define NAME_KEY        @"name"
#define ADDRESS_KEY     @"address"
#define DESCRIPTION_KEY @"description"
#define FLAGS_KEY       @"flags"

@implementation BDSKWebParser

static Class webParserClassForType(NSInteger stringType)
{
    switch(stringType){
        case BDSKGoogleScholarWebType:
            return [BDSKGoogleScholarParser class];
        case BDSKACMDLWebType:
            return [BDSKACMDLParser class];
        case BDSKCiteULikeWebType:
            return [BDSKCiteULikeParser class];
        case BDSKHubmedWebType:
            return [BDSKHubmedParser class];
		case BDSKSpiresWebType: 
            return [BDSKSpiresParser class];
		case BDSKArxivWebType: 
            return [BDSKArxivParser class];
        case BDSKMathSciNetWebType: 
            return [BDSKMathSciNetParser class];
		case BDSKZentralblattWebType: 
            return [BDSKZentralblattParser class];
		case BDSKProjectEuclidWebType:
			return [BDSKProjectEuclidParser class];
		case BDSKNumdamWebType:
			return [BDSKNumdamParser class];
		case BDSKCOinSWebType:
			return [BDSKCOinSParser class];
		case BDSKHCiteWebType: 
            return [BDSKHCiteParser class];
        case BDSKIEEEXploreWebType:
            return [BDSKIEEEXploreParser class];
        default:
            return Nil;
    }    
}

+ (Class) webParserClassForType: (NSInteger) stringType {
	return webParserClassForType(stringType);
}

+ (NSInteger)webTypeOfDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    if([BDSKGoogleScholarParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
        return BDSKGoogleScholarWebType;
    if([BDSKHubmedParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
        return BDSKHubmedWebType;
    if([BDSKCiteULikeParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
        return BDSKCiteULikeWebType;
    if([BDSKACMDLParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
        return BDSKACMDLWebType;
    if([BDSKSpiresParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
		return BDSKSpiresWebType;
    if([BDSKArxivParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
		return BDSKArxivWebType;
    if([BDSKMathSciNetParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
		return BDSKMathSciNetWebType;
    if([BDSKZentralblattParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
		return BDSKZentralblattWebType;
    if([BDSKProjectEuclidParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
		return BDSKProjectEuclidWebType;
    if([BDSKNumdamParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
		return BDSKNumdamWebType;
    if([BDSKIEEEXploreParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
		return BDSKIEEEXploreWebType;

    if([BDSKCOinSParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
		return BDSKCOinSWebType;
    if([BDSKHCiteParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
		return BDSKHCiteWebType;
    return BDSKUnknownWebType;
}

// entry point from view controller
+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument fromURL:(NSURL *)url error:(NSError **)outError{
    BDSKASSERT(self == [BDSKWebParser class]);
    
    NSError *error = nil;    
    
    NSString *htmlString = [(id)[domDocument documentElement] outerHTML];
    if (nil == htmlString) {
        if (outError) {
            *outError = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Failed to read HTML string from document", @"web view error; should never occur")];
            [*outError setValue:NSLocalizedString(@"Please inform the developer of this error and provide the URL.", @"web view error") 
                         forKey:NSLocalizedRecoverySuggestionErrorKey];
        }
        return nil;
    }
    
    NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithXMLString:htmlString
                                                             options:NSXMLDocumentTidyXML|NSXMLNodePreserveEmptyElements
                                                               error:&error];
    [xmlDoc autorelease];
    if(xmlDoc == nil){
        if(outError) *outError = error;
        return nil;
    }
    
    NSInteger webType = [self webTypeOfDocument:domDocument xmlDocument:xmlDoc fromURL:url];
    
    Class parserClass = webParserClassForType(webType);
    
    BDSKASSERT(parserClass != [BDSKWebParser class]);
    
    // this may lead to some false negatives if the heuristics for canParseDocument::: change.
    if (Nil == parserClass) {
        if (outError) {
            *outError = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Unsupported URL", @"error when parsing text fails")];
            [*outError setValue:NSLocalizedString(@"BibDesk was not able to find a parser for this web page.", @"error description") forKey:NSLocalizedRecoverySuggestionErrorKey];
        }
        return nil;
    }
    
    return [parserClass itemsFromDocument:domDocument xmlDocument:xmlDoc fromURL:url error:outError];
}

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    BDSKRequestConcreteImplementation(self, _cmd);
    return NO;
}

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError{
    BDSKRequestConcreteImplementation(self, _cmd);
    return nil;
}



+ (NSDictionary *) parserInfoWithName: (NSString *) name address: (NSString *) address description: (NSString *) description flags: (NSUInteger) flags {
	NSDictionary * result = nil;
	NSMutableDictionary * dict = [NSMutableDictionary dictionaryWithCapacity:4];

	if (name) { // name of the site or format is required for a parser dictionary. 
		[dict setObject:name forKey:NAME_KEY];
		if (address) { [dict setObject:address forKey:ADDRESS_KEY]; }
		if (description) { [dict setObject:description forKey:DESCRIPTION_KEY]; }
		NSNumber * flagsNumber = [NSNumber numberWithInt:flags];
		[dict setObject:flagsNumber forKey:FLAGS_KEY];
		result = dict;
	}

	return result;
}


+ (NSArray *) parserInfos {
	return nil;
}


@end

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
#import <OmniBase/OmniBase.h>
#import "BDSKHCiteParser.h"
#import "BDSKCiteULikeParser.h"
#import "BDSKACMDLParser.h"
#import "BDSKHubmedParser.h"
#import "BDSKGoogleScholarParser.h"
#import "BDSKSpiresParser.h"
#import "NSError_BDSKExtensions.h"

@implementation BDSKWebParser

static Class webParserClassForType(int stringType)
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
		case BDSKHCiteWebType: 
            return [BDSKHCiteParser class];
		case BDSKSpiresWebType: 
            return [BDSKSpiresParser class];
        default:
            return nil;
    }    
}

+ (int)webTypeOfDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    if([BDSKGoogleScholarParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
        return BDSKGoogleScholarWebType;
    if([BDSKHubmedParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
        return BDSKHubmedWebType;
    if([BDSKCiteULikeParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
        return BDSKCiteULikeWebType;
    if([BDSKACMDLParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
        return BDSKACMDLWebType;
    if([BDSKHCiteParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
		return BDSKHCiteWebType;
    if([BDSKSpiresParser canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url])
		return BDSKSpiresWebType;
    return BDSKUnknownWebType;
}

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url ofType:(int)webType{
    Class parserClass = webParserClassForType(webType);
    return parserClass != Nil ? [parserClass canParseDocument:domDocument xmlDocument:xmlDocument fromURL:url] : NO;
}

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url{
    return NO;
}

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument 
                   xmlDocument:(NSXMLDocument *)xmlDocument 
                       fromURL:(NSURL *)url
                        ofType:(int)webType error:(NSError **)outError{
        
    Class parserClass = Nil;
    if (webType == BDSKUnknownWebType)
        webType = [self webTypeOfDocument:domDocument xmlDocument:xmlDocument fromURL:url];
    
    parserClass = webParserClassForType(webType);
    
    // don't return nil here; this may be the Google Scholar homepage or something, and we don't want to display an error message for it
    // this may lead to some false negatives if the heuristics for canParseDocument::: change.
    if (Nil == parserClass)
        return [NSArray array];
    
    return [parserClass itemsFromDocument:domDocument xmlDocument:xmlDocument fromURL:url error:outError];
}

// entry point from view controller
+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument fromURL:(NSURL *)url error:(NSError **)outError{
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
                                                             options:NSXMLDocumentTidyHTML error:&error];
    [xmlDoc autorelease];
    if(xmlDoc == nil){
        if(outError) *outError = error;
        return nil;
    }
    
    return [self itemsFromDocument:domDocument xmlDocument:xmlDoc fromURL:url error:outError];
}

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument
                   xmlDocument:(NSXMLDocument *)xmlDocument 
                       fromURL:(NSURL *)url
                         error:(NSError **)outError{

    if([self class] == [BDSKWebParser class]){
        return [self itemsFromDocument:domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url ofType:BDSKUnknownWebType error:outError];
    }else{
        OBRequestConcreteImplementation(self, _cmd);
        return nil;
    }
}

@end

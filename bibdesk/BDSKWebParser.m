//
//  BDSKWebParser.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 4/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BDSKWebParser.h"
#import <OmniBase/OBUtilities.h>
#import "BDSKHCiteParser.h"
#import "BDSKCiteULikeParser.h"
#import "BDSKACMDLParser.h"
#import "BDSKHubmedParser.h"
#import "BDSKGoogleScholarParser.h"

@implementation BDSKWebParser

static Class webParserClassForType(int stringType)
{
    Class parserClass = Nil;
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
    
    
    return [parserClass itemsFromDocument:domDocument xmlDocument:xmlDocument fromURL:url error:outError];
}

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument fromURL:(NSURL *)url error:(NSError **)outError{
    NSError *error = nil;    
    
    NSString *htmlString = [(id)[domDocument documentElement] outerHTML];
    if (nil == htmlString)
        return nil;
    
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

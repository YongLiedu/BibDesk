//
//  BDSKWebParser.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 4/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

enum {
	BDSKUnknownWebType = -1, 
    BDSKHCiteWebType,
    BDSKCiteULikeWebType,
    BDSKACMDLWebType
};

@interface BDSKWebParser : NSObject

// IMPORTANT NOTE:
// Use this method as the main interface to this class. It will build the XMLDocument and figure out the type for you:
+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument fromURL:(NSURL *)url error:(NSError **)outError;


+ (int)webTypeOfDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url;

+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url ofType:(int)webType;
+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url;

+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url ofType:(int)webType error:(NSError **)outError;
+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError;


@end

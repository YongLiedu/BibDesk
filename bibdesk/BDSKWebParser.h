//
//  BDSKWebParser.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 4/2/07.
/*
 This software is Copyright (c) 2007-2010
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

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


enum {
    BDSKParserFeatureNone = 0,
// flag indicating that full usage of the parser's feature requires some sort of subscription
    BDSKParserFeatureSubscriptionMask = 1 << 0,
// flag indicating that the parser's feature looks for specific data on all pages:
    BDSKParserFeatureAllPagesMask = 1 << 1
};

enum {
	BDSKUnknownWebType = -1, 
    BDSKCiteULikeWebType,
    BDSKACMDLWebType,
    BDSKHubmedWebType,
    BDSKGoogleScholarWebType,
    BDSKSpiresWebType,
    BDSKArxivWebType,
	BDSKMathSciNetWebType,
	BDSKZentralblattWebType,
	BDSKProjectEuclidWebType,
	BDSKNumdamWebType,
    BDSKIEEEXploreWebType,
	// parsers for microformats which are not site-specific should better be at the end 
	BDSKCOinSWebType,
    BDSKHCiteWebType
};

@interface BDSKWebParser : NSObject
+ (Class) webParserClassForType: (NSInteger) stringType;
// this method is the main entry point for the BDSKWebParser class it should not be overridden by the concrete subclasses
+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument fromURL:(NSURL *)url error:(NSError **)outError;
// Helper method for creating a correctly formatted parser feature information dictionary. 
+ (NSDictionary *) parserInfoWithName: (NSString *) name address: (NSString *) address description: (NSString *) description flags:(NSUInteger) flags;
@end

@interface BDSKWebParser (SubclassResponsibility)
// these methods must be implemented by the concrete subclasses, and are invalid for the BDSKWebParser class
+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url;
+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError;
// Subclasses return an array of parser feature information dictionaries which are used to create the Web Group start page.
+ (NSArray *) parserInfos;
@end

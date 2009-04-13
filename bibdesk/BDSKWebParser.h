//
//  BDSKWebParser.h
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

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

// keys for site dictionaries
#define BDSKSITENAME @"name"
#define BDSKSITEADDRESS @"address"
#define BDSKSITEINFORMATION @"information"

enum {
	BDSKUnknownWebType = -1, 
    BDSKHCiteWebType,
    BDSKCiteULikeWebType,
    BDSKACMDLWebType,
    BDSKHubmedWebType,
    BDSKGoogleScholarWebType,
    BDSKSpiresWebType,
    BDSKArxivWebType,
	BDSKMathSciNetWebType,
	BDSKZentralblattWebType,
	BDSKProjectEuclidWebType,
	BDSKNumdamWebType
};

@interface BDSKWebParser : NSObject
+ (Class) webParserClassForType: (int) stringType;
// this method is the main entry point for the BDSKWebParser class it should not be overridden by the concrete subclasses
+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument fromURL:(NSURL *)url error:(NSError **)outError;
// helper method for creating correctly formatted site dictionaries 
+ (NSDictionary *) siteInfoWithName: (NSString *) name address: (NSString *) address andTitle: (NSString *) title;
@end

@interface BDSKWebParser (SubclassResponsibility)
// these methods must be implemented by the concrete subclasses, and are invalid for the BDSKWebParser class
+ (BOOL)canParseDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url;
+ (NSArray *)itemsFromDocument:(DOMDocument *)domDocument xmlDocument:(NSXMLDocument *)xmlDocument fromURL:(NSURL *)url error:(NSError **)outError;
// Subclasses return site info dictionaries here to be listed on the web group start page.
+ (NSArray *) publicSites;
+ (NSArray *) subscriptionSites;
@end

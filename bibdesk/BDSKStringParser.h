//
// BDSKStringParser.h
// Bibdesk
//
// Created by Adam Maxwell on 02/07/06.
/*
 This software is Copyright (c) 2006-2016
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

#import <Foundation/Foundation.h>

enum {
	BDSKUnknownStringType = -1, 
	BDSKBibTeXStringType, 
	BDSKNoKeyBibTeXStringType, 
	BDSKPubMedStringType, 
	BDSKRISStringType, 
	BDSKMARCStringType, 
	BDSKReferenceMinerStringType, 
	BDSKJSTORStringType, 
	BDSKWOSStringType, 
	BDSKDublinCoreStringType,
    BDSKReferStringType,
    BDSKMODSStringType,
    BDSKSciFinderStringType,
    BDSKPubMedXMLStringType,
    BDSKDOIStringType
};
typedef NSInteger BDSKStringType;

@protocol BDSKOwner;

@interface BDSKStringParser : NSObject
// passing BDSKUnknownStringType will use the appropriate -contentStringType
+ (BOOL)canParseString:(NSString *)string ofType:(BDSKStringType)stringType;
// only for non-BibTeX string types
+ (NSArray *)itemsFromString:(NSString *)string ofType:(BDSKStringType)stringType error:(NSError **)outError;
// all string types including BibTeX
+ (NSArray *)itemsFromString:(NSString *)string ofType:(BDSKStringType)stringType owner:(id <BDSKOwner>)owner error:(NSError **)outError;
@end


@protocol BDSKStringParser <NSObject>
+ (BOOL)canParseString:(NSString *)string;
+ (NSArray *)itemsFromString:(NSString *)string error:(NSError **)outError;
@end


@interface NSString (BDSKStringParserExtensions)
- (BDSKStringType)contentStringType;
@end

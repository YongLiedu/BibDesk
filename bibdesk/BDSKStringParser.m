//
// BDSKStringParser.h
// Bibdesk
//
// Created by Adam Maxwell on 02/07/06.
/*
 This software is Copyright (c) 2006-2010
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

#import "BDSKStringParser.h"
#import "NSError_BDSKExtensions.h"
#import "BDSKBibTeXParser.h"
#import "BDSKPubMedParser.h"
#import "BDSKRISParser.h"
#import "BDSKMARCParser.h"
#import "BDSKReferenceMinerParser.h"
#import "BDSKJSTORParser.h"
#import "BDSKWebOfScienceParser.h"
#import "BDSKDublinCoreXMLParser.h"
#import "BDSKReferParser.h"
#import "BDSKMODSParser.h"
#import "BDSKSciFinderParser.h"
#import "BDSKPubMedXMLParser.h"
#import "BDSKRuntime.h"

@implementation BDSKStringParser

static Class classForType(NSInteger stringType)
{
    Class parserClass = Nil;
    switch(stringType){
		case BDSKPubMedStringType: 
            parserClass = [BDSKPubMedParser class];
            break;
		case BDSKRISStringType:
            parserClass = [BDSKRISParser class];
            break;
		case BDSKMARCStringType:
            parserClass = [BDSKMARCParser class];
            break;
		case BDSKReferenceMinerStringType:
            parserClass = [BDSKReferenceMinerParser class];
            break;
		case BDSKJSTORStringType:
            parserClass = [BDSKJSTORParser class];
            break;
        case BDSKWOSStringType:
            parserClass = [BDSKWebOfScienceParser class];
            break;
        case BDSKDublinCoreStringType:
            parserClass = [BDSKDublinCoreXMLParser class];
            break;
        case BDSKReferStringType:
            parserClass = [BDSKReferParser class];
            break;
        case BDSKMODSStringType:
            parserClass = [BDSKMODSParser class];
            break;
        case BDSKSciFinderStringType:
            parserClass = [BDSKSciFinderParser class];
            break;
        case BDSKPubMedXMLStringType:
            parserClass = [BDSKPubMedXMLParser class];
            break;
        default:
            parserClass = Nil;
    }
    return parserClass;
}

+ (BOOL)canParseString:(NSString *)string ofType:(NSInteger)stringType{
    if (stringType == BDSKUnknownStringType)
        stringType = [string contentStringType];
    Class parserClass = classForType(stringType);
    BDSKASSERT(parserClass == Nil || [parserClass conformsToProtocol:@protocol(BDSKStringParser)]);
    return [parserClass canParseString:string];
}

+ (NSArray *)itemsFromString:(NSString *)string ofType:(NSInteger)stringType error:(NSError **)outError{
    if (stringType == BDSKUnknownStringType)
        stringType = [string contentStringType];
    BDSKASSERT(stringType != BDSKBibTeXStringType);
    BDSKASSERT(stringType != BDSKNoKeyBibTeXStringType);
    Class parserClass = classForType(stringType);
    BDSKASSERT(parserClass == Nil || [parserClass conformsToProtocol:@protocol(BDSKStringParser)]);
    if (Nil == parserClass && outError){
        *outError = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Unsupported or invalid format", @"error when parsing text fails")];
        [*outError setValue:NSLocalizedString(@"BibDesk was not able to determine the syntax of this data.  It may be incorrect or an unsupported type of text.", @"error description when parsing text fails") forKey:NSLocalizedRecoverySuggestionErrorKey];
    }
    return [parserClass itemsFromString:string error:outError];
}

@end


@implementation NSString (BDSKStringParserExtensions)

- (NSInteger)contentStringType{
    if([BDSKBibTeXParser canParseString:self])
        return BDSKBibTeXStringType;
    if([BDSKReferenceMinerParser canParseString:self])
        return BDSKReferenceMinerStringType;
    if([BDSKPubMedParser canParseString:self])
        return BDSKPubMedStringType;
    if([BDSKRISParser canParseString:self])
        return BDSKRISStringType;
    if([BDSKMARCParser canParseString:self])
        return BDSKMARCStringType;
    if([BDSKJSTORParser canParseString:self])
        return BDSKJSTORStringType;
    if([BDSKWebOfScienceParser canParseString:self])
        return BDSKWOSStringType;
    if([BDSKBibTeXParser canParseStringAfterFixingKeys:self])
        return BDSKNoKeyBibTeXStringType;
    if([BDSKReferParser canParseString:self])
        return BDSKReferStringType;
    if([BDSKMODSParser canParseString:self])
        return BDSKMODSStringType;
    if([BDSKSciFinderParser canParseString:self])
        return BDSKSciFinderStringType;
    if([BDSKPubMedXMLParser canParseString:self])
        return BDSKPubMedXMLStringType;
	// don't check DC, as the check is too unreliable
    return BDSKUnknownStringType;
}

@end

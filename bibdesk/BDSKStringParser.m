//
// BDSKStringParser.h
// Bibdesk
//
// Created by Adam Maxwell on 02/07/06.
/*
 This software is Copyright (c) 2006-2012
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
#import "BDSKErrorObjectController.h"

@implementation BDSKStringParser

static Class classForType(BDSKStringType stringType)
{
    switch(stringType){
		case BDSKPubMedStringType:          return [BDSKPubMedParser class];
		case BDSKRISStringType:             return [BDSKRISParser class];
		case BDSKMARCStringType:            return [BDSKMARCParser class];
		case BDSKReferenceMinerStringType:  return [BDSKReferenceMinerParser class];
		case BDSKJSTORStringType:           return [BDSKJSTORParser class];
        case BDSKWOSStringType:             return [BDSKWebOfScienceParser class];
        case BDSKDublinCoreStringType:      return [BDSKDublinCoreXMLParser class];
        case BDSKReferStringType:           return [BDSKReferParser class];
        case BDSKMODSStringType:            return [BDSKMODSParser class];
        case BDSKSciFinderStringType:       return [BDSKSciFinderParser class];
        case BDSKPubMedXMLStringType:       return [BDSKPubMedXMLParser class];
        default:                            return Nil;
    }
}

+ (BOOL)canParseString:(NSString *)string ofType:(BDSKStringType)stringType{
    if (stringType == BDSKUnknownStringType)
        stringType = [string contentStringType];
    Class parserClass = classForType(stringType);
    BDSKASSERT(parserClass == Nil || [parserClass conformsToProtocol:@protocol(BDSKStringParser)]);
    return [parserClass canParseString:string];
}

+ (NSArray *)itemsFromString:(NSString *)string ofType:(BDSKStringType)stringType error:(NSError **)outError{
    if (stringType == BDSKUnknownStringType)
        stringType = [string contentStringType];
    BDSKASSERT(stringType != BDSKBibTeXStringType);
    BDSKASSERT(stringType != BDSKNoKeyBibTeXStringType);
    Class parserClass = classForType(stringType);
    BDSKASSERT(parserClass == Nil || [parserClass conformsToProtocol:@protocol(BDSKStringParser)]);
    if (Nil == parserClass && outError){
        *outError = [NSError mutableLocalErrorWithCode:kBDSKParserUnsupported localizedDescription:NSLocalizedString(@"Unsupported or invalid format", @"error when parsing text fails")];
        [*outError setValue:NSLocalizedString(@"BibDesk was not able to determine the syntax of this data.  It may be incorrect or an unsupported type of text.", @"error description when parsing text fails") forKey:NSLocalizedRecoverySuggestionErrorKey];
    }
    return [parserClass itemsFromString:string error:outError];
}

+ (NSArray *)itemsFromString:(NSString *)string ofType:(BDSKStringType)type owner:(id <BDSKOwner>)owner isPartialData:(BOOL *)isPartialData error:(NSError **)outError {
    NSArray *newPubs = nil;
    NSError *parseError = nil;
    
    // @@ BDSKStringParser doesn't handle any BibTeX types, so it's not really useful as a funnel point for any string type, since each usage requires special casing for BibTeX.
    if(BDSKUnknownStringType == type)
        type = [string contentStringType];
    
    if(type == BDSKBibTeXStringType){
        newPubs = [BDSKBibTeXParser itemsFromString:string owner:owner isPartialData:isPartialData error:&parseError];
    }else if(type == BDSKNoKeyBibTeXStringType){
        newPubs = [BDSKBibTeXParser itemsFromString:[string stringWithPhoneyCiteKeys:@"FixMe"] owner:owner isPartialData:isPartialData error:&parseError];
	}else{
        // this will create the NSError if the type is unrecognized
        newPubs = [self itemsFromString:string ofType:type error:&parseError];
        if(isPartialData)
            *isPartialData = newPubs != nil;
    }
    
    if([parseError isLocalError] && [parseError code] == kBDSKBibTeXParserFailed){
        NSError *error = [NSError mutableLocalErrorWithCode:kBDSKBibTeXParserFailed localizedDescription:NSLocalizedString(@"Error Reading String", @"Message in alert dialog when failing to parse dropped or copied string")];
        [error setValue:NSLocalizedString(@"There was a problem inserting the data. Do you want to ignore this data, open a window containing the data to edit it and remove the errors, or keep going and use everything that BibDesk could parse?\n(It's likely that choosing \"Keep Going\" will lose some data.)", @"Informative text in alert dialog") forKey:NSLocalizedRecoverySuggestionErrorKey];
        [error setValue:self forKey:NSRecoveryAttempterErrorKey];
        [error setValue:[NSArray arrayWithObjects:NSLocalizedString(@"Cancel", @"Button title"), NSLocalizedString(@"Keep going", @"Button title"), NSLocalizedString(@"Edit data", @"Button title"), nil] forKey:NSLocalizedRecoveryOptionsErrorKey];
        [error setValue:parseError forKey:NSUnderlyingErrorKey];
        parseError = error;
    }
    
	if(type == BDSKNoKeyBibTeXStringType && parseError == nil){
        // return an error when we inserted temporary keys, let the caller decide what to do with it
        // don't override a parseError though, as that is probably more relevant
        parseError = [NSError mutableLocalErrorWithCode:kBDSKHadMissingCiteKeys localizedDescription:NSLocalizedString(@"Temporary Cite Keys", @"Error description")];
        [parseError setValue:@"FixMe" forKey:@"temporaryCiteKey"];
    }
    
	if(outError) *outError = parseError;
    return newPubs;
}

+ (BOOL)attemptRecoveryFromError:(NSError *)error optionIndex:(NSUInteger)recoveryOptionIndex {
    if (recoveryOptionIndex == 2)
        [[BDSKErrorObjectController sharedErrorObjectController] showEditorForLastPasteDragError];
    return recoveryOptionIndex == 1;
}

@end


@implementation NSString (BDSKStringParserExtensions)

- (BDSKStringType)contentStringType{
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

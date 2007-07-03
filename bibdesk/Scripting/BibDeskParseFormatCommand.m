//
//  BibDeskParseFormatCommand.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/18/05.
/*
 This software is Copyright (c) 2005,2006,2007
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

#import "BibDeskParseFormatCommand.h"
#import "BDSKFormatParser.h"
#import "BibField.h"
#import "BibItem.h"
#import "BibPrefController.h"
#import "BibAppController.h"
#import "BDSKOwnerProtocol.h"

@implementation BibDeskParseFormatCommand

- (id)performDefaultImplementation {
	// the direct object is the format string
	NSString *formatString = [self directParameter];
	// the other parameters are either a field or a field name and a publication
	NSDictionary *params = [self evaluatedArguments];
	id field = [params objectForKey:@"for"];
	BibItem *pub = [params objectForKey:@"from"];
	BOOL check = [[params objectForKey:@"check"] boolValue];
    
	if (formatString == nil || params == nil) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
		return nil;
	}
	if ([formatString isKindOfClass:[NSString class]] == NO) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
		return nil;
	}
	
	
	if (field == nil) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
		return nil;
	}
	if ([field isKindOfClass:[BibField class]]) {
		if (!pub) {
			pub = [(BibField *)field publication];
		}
		field = [field name];
	} else if ([field isKindOfClass:[NSString class]] == NO) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
		return nil;
	} else {
        field = [field fieldName];
	}
	
	if (pub == nil) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
		return nil;
	}
	if ([pub isKindOfClass:[BibItem class]] == NO) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
		return nil;
	}
	
	NSString *error = nil;
	
	if (NO == [BDSKFormatParser validateFormat:&formatString forField:field inFileType:BDSKBibtexString error:&error]) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
		[self setScriptErrorString:[NSString stringWithFormat:@"Invalid format string: %@", error]]; 
		return nil;
	}
    
    BOOL isLocalFile = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKLocalFileFieldsKey] containsObject:field];
    NSString *papersFolderPath = nil;
    if (isLocalFile)
        papersFolderPath = [[NSApp delegate] folderPathForFilingPapersFromDocument:[pub owner]];
	
    if (check) {
        NSArray *requiredFields = [BDSKFormatParser requiredFieldsForFormat:formatString];
        
        if (isLocalFile &&
            ([NSString isEmptyString:[[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:BDSKPapersFolderPathKey]] && 
             [NSString isEmptyString:[[[[pub owner] fileURL] path] stringByDeletingLastPathComponent]]))
            return [NSNull null];
        
        NSEnumerator *fEnum = [requiredFields objectEnumerator];
        NSString *fieldName;
        
        while (fieldName = [fEnum nextObject]) {
            if ([fieldName isEqualToString:BDSKCiteKeyString]) {
                if([pub hasEmptyOrDefaultCiteKey])
                    return [NSNull null];
            } else if ([fieldName isEqualToString:@"Document Filename"]) {
                if ([NSString isEmptyString:[[[pub owner] fileURL] path]])
                    return [NSNull null];
            } else if ([fieldName hasPrefix:@"Document: "]) {
                if ([NSString isEmptyString:[[pub owner] documentInfoForKey:[fieldName substringFromIndex:10]]])
                    return [NSNull null];
            } else if ([fieldName isEqualToString:BDSKAuthorEditorString]) {
                if ([NSString isEmptyString:[pub valueOfField:BDSKAuthorString]] && 
                    [NSString isEmptyString:[pub valueOfField:BDSKEditorString]])
                    return [NSNull null];
            } else {
                if ([NSString isEmptyString:[pub valueOfField:fieldName]]) 
                    return [NSNull null];
            }
        }
    }
    
    NSString *suggestion = nil;
    if ([field isEqualToString:BDSKCiteKeyString]) {
        suggestion = [pub citeKey];
    } else if (isLocalFile) {
        suggestion = [pub localFilePathForField:field inherit:NO];
        if ([suggestion hasPrefix:[papersFolderPath stringByAppendingString:@"/"]]) 
            suggestion = [suggestion substringFromIndex:[papersFolderPath length]];
        else
            suggestion = nil;
    } else {
        suggestion = [pub valueOfField:field inherit:NO];
    }
    
	NSString *string = [BDSKFormatParser parseFormat:formatString forField:field ofItem:pub suggestion:suggestion];
	
	if (isLocalFile) {
		return [[NSURL fileURLWithPath:[papersFolderPath stringByAppendingPathComponent:string]] absoluteString];
	} 
	
	return string;
}

@end

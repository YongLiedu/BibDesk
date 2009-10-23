//
//  BDSKParseFormatCommand.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/18/05.
/*
 This software is Copyright (c) 2005-2009
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

#import "BDSKParseFormatCommand.h"
#import "BDSKFormatParser.h"
#import "BDSKField.h"
#import "BibItem.h"
#import "BDSKStringConstants.h"
#import "BDSKAppController.h"
#import "BDSKOwnerProtocol.h"
#import "BDSKTypeManager.h"

@implementation BDSKParseFormatCommand

- (id)performDefaultImplementation {
	// the direct object is the format string
	NSString *formatString = [self directParameter];
	// the other parameters are either a field or a field name and a publication
	NSDictionary *params = [self evaluatedArguments];
	id field = [params objectForKey:@"for"];
	NSNumber *indexNumber = [params objectForKey:@"index"];
	BibItem *pub = [params objectForKey:@"from"];
	BOOL check = [[params objectForKey:@"check"] boolValue];
    NSUInteger i = indexNumber ? [indexNumber unsignedIntValue] - 1 : 0;
    BOOL isFile = field == nil;
    
	if (formatString == nil || params == nil) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
		return nil;
	}
	if ([formatString isKindOfClass:[NSString class]] == NO) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
		return nil;
	}
	
	if (field == nil) {
        field = BDSKLocalFileString;
    } else if ([field isKindOfClass:[BDSKField class]]) {
		if (pub == nil) {
			pub = [(BDSKField *)field publication];
		}
		field = [field name];
	} else if (field && [field isKindOfClass:[NSString class]] == NO) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
		return nil;
	} else if ([field isEqualToString:BDSKCiteKeyString] == NO) {
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
    
    BOOL isFileField = [field isLocalFileField];
    NSString *papersFolderPath = nil;
    if (isFileField || isFile)
        papersFolderPath = [BDSKFormatParser folderPathForFilingPapersFromDocumentAtPath:[[[pub owner] fileURL] path]];
	
    BDSKLinkedFile *file = nil;
    if (isFile)
        file = [[pub localFiles] objectAtIndex:i];
    
    if (check) {
        NSArray *requiredFields = [BDSKFormatParser requiredFieldsForFormat:formatString];
        
        if ((isFileField || isFile) &&
            ([NSString isEmptyString:[[NSUserDefaults standardUserDefaults] stringForKey:BDSKPapersFolderPathKey]] && 
             [NSString isEmptyString:[[[[pub owner] fileURL] path] stringByDeletingLastPathComponent]]))
            return [NSNull null];
        
        for (NSString *fieldName in requiredFields) {
            if ([fieldName isEqualToString:BDSKCiteKeyString]) {
                if([pub hasEmptyOrDefaultCiteKey])
                    return [NSNull null];
            } else if ([fieldName isEqualToString:BDSKLocalFileString]) {
                if ((isFile && [file URL] == nil) || [pub localFileURLForField:field] == nil)
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
    } else if (isFileField) {
        suggestion = [[pub localFileURLForField:field] path];
        if ([suggestion hasPrefix:[papersFolderPath stringByAppendingString:@"/"]]) 
            suggestion = [suggestion substringFromIndex:[papersFolderPath length]];
        else
            suggestion = nil;
    } else if (isFile == NO) {
        suggestion = [pub valueOfField:field inherit:NO];
    }
    
	NSString *string = nil;
    
    if (isFile)
        string = [BDSKFormatParser parseFormat:formatString forLinkedFile:file ofItem:pub];
    else
        string = [BDSKFormatParser parseFormat:formatString forField:field ofItem:pub suggestion:suggestion];
	
	if (isFileField)
		return [[NSURL fileURLWithPath:[papersFolderPath stringByAppendingPathComponent:string]] absoluteString];
	else if (isFile)
		return [papersFolderPath stringByAppendingPathComponent:string];
	else
        return string;
}

@end

//
//  BDSKAutofileCommand.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 7/3/07.
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

#import "BDSKAutofileCommand.h"
#import "BDSKStringConstants.h"
#import "BibItem.h"
#import "BibDocument.h"
#import "BDSKOwnerProtocol.h"
#import "BDSKFiler.h"
#import "BDSKTypeManager.h"
#import "BDSKAppController.h"


@implementation BDSKAutoFileCommand

- (id)performDefaultImplementation {
    BibItem *pub = [self evaluatedReceivers];
	NSDictionary *params = [self evaluatedArguments];
	NSNumber *indexNumber = [params objectForKey:@"index"];
    NSString *location = [params objectForKey:@"to"];
    NSNumber *checkNumber = [params objectForKey:@"check"];
	BOOL check = checkNumber ? [checkNumber boolValue] : YES;
    NSInteger mask = 0;
    NSUInteger i = indexNumber ? [indexNumber unsignedIntegerValue] - 1 : 0;
    
	if (pub == nil) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
		return nil;
	}
	if ([pub isKindOfClass:[BibItem class]] == NO) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
		return nil;
	} else if ([[pub owner] isDocument] == NO) {
        [self setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    }
    
    NSArray *localFiles = [pub localFiles];
	
    if (i >= [localFiles count]) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
		return nil;
	}
    
    NSArray *paperInfos = nil;
    
    if ([localFiles count]) {
        if (location) {
            if ([location isKindOfClass:[NSString class]] == NO) {
                [self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
                return nil;
            }
            if ([location isAbsolutePath] == NO) {
                NSString *papersFolderPath = [BDSKFormatParser folderPathForFilingPapersFromDocumentAtPath:[[[pub owner] fileURL] path]];
                [papersFolderPath stringByAppendingPathComponent:location]; 
            }
            paperInfos = [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:pub, @"publication", [localFiles objectAtIndex:i], @"file", location, @"path", nil]];
        } else {
            mask |= BDSKInitialAutoFileOptionMask;
            if (check)
                mask |= BDSKCheckCompleteAutoFileOptionMask;
            if (indexNumber)
                paperInfos = [NSArray arrayWithObject:[localFiles objectAtIndex:i]];
            else
                paperInfos = [pub localFiles];
        }
    }
    
    if (paperInfos) {
        [[BDSKFiler sharedFiler] movePapers:paperInfos forField:BDSKLocalFileString fromDocument:(BibDocument *)[pub owner] options:mask];
        [[pub undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    }
    
    return nil;
}

@end

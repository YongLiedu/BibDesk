//
//  BDSKAutofileCommand.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 7/3/07.
/*
 This software is Copyright (c) 2007-2012
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
    BibDocument *doc = (BibDocument *)[pub owner];
	NSDictionary *params = [self evaluatedArguments];
	NSNumber *indexNumber = [params objectForKey:@"index"];
    NSString *location = [params objectForKey:@"to"];
    NSNumber *checkNumber = [params objectForKey:@"check"];
	BOOL check = checkNumber ? [checkNumber boolValue] : YES;
    BDSKFilerOptions mask = 0;
    NSUInteger i = indexNumber ? [indexNumber unsignedIntegerValue] - 1 : 0;
    
	if (pub == nil) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
		return nil;
	}
	if ([pub isKindOfClass:[BibItem class]] == NO) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
		return nil;
	} else if ([doc isDocument] == NO) {
        [self setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    }
    
    NSArray *localFiles = [pub localFiles];
	
    if (i >= [localFiles count]) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
		return nil;
	} else if ([localFiles count] == 0) {
        return nil;
    }
    
    if (location) {
        if ([location isKindOfClass:[NSString class]] == NO) {
            [self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
            return nil;
        }
        if ([location isAbsolutePath] == NO) {
            NSString *papersFolderPath = [BDSKFormatParser folderPathForFilingPapersFromDocumentAtPath:[[doc fileURL] path]];
            [papersFolderPath stringByAppendingPathComponent:location]; 
        }
        NSArray *paperInfos = [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:[localFiles objectAtIndex:i], BDSKFilerFileKey, pub, BDSKFilerPublicationKey, location, BDSKFilerNewPathKey, nil]];
        if ([[BDSKFiler sharedFiler] movePapers:paperInfos forField:BDSKLocalFileString fromDocument:doc options:mask])
            [[pub undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSArray *files = indexNumber ? [NSArray arrayWithObject:[localFiles objectAtIndex:i]] : [pub localFiles];
        if ([[BDSKFiler sharedFiler] autoFileLinkedFiles:files fromDocument:doc check:check])
            [[pub undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    }
    
    return nil;
}

@end

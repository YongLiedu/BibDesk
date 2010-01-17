//
//  BDSKExportUsingTemplateCommand.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/19/06.
/*
 This software is Copyright (c) 2006-2010
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

#import "BDSKExportUsingTemplateCommand.h"
#import "BibDocument.h"
#import "BDSKTemplate.h"
#import "BDSKPublicationsArray.h"
#import "NSArray_BDSKExtensions.h"
#import "BibItem.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"


@implementation BDSKExportUsingTemplateCommand

- (id)performDefaultImplementation {

	// figure out parameters first
	NSDictionary *params = [self evaluatedArguments];
	if (!params) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
			return @"";
	}
	
	BibDocument *document = nil;
	id receiver = [self evaluatedReceivers];
    NSScriptObjectSpecifier *dP = [self directParameter];
	id dPO = [dP objectsByEvaluatingSpecifier];

	if ([receiver isKindOfClass:[BibDocument class]]) {
        document = receiver;
    } else if ([dPO isKindOfClass:[BibDocument class]]) {
        document = dPO;
    } else {
		// give up
		[self setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
		[self setScriptErrorString:NSLocalizedString(@"The templated text command can only be sent to the documents.", @"Error description")];
		return nil;
	}
	
	// the 'to' parameters gives the file to save to, either as a path or a url (it seems)
	id fileObj = [params objectForKey:@"to"];
    NSURL *fileURL = nil;
	// make sure we get something
	if (!fileObj) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
		return nil;
	}
	// make sure we get the right thing
	if ([fileObj isKindOfClass:[NSString class]]) {
        fileURL = [NSURL fileURLWithPath:(NSString*)fileObj];
        if (fileURL == nil)
            return nil;
    } else if ([fileObj isKindOfClass:[NSURL class]]) {
        fileURL = (NSURL *)fileObj;
    } else if ([fileObj isKindOfClass:[NSPropertySpecifier class]] == NO || [[fileObj key] isEqualToString:@"clipboard"] == NO) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
        return nil;
	}
	
	// the 'using' parameters gives the template name to use
	id templateStyle = [params objectForKey:@"using"];
	id templateString = [params objectForKey:@"usingText"];
	id templateAttrString = [params objectForKey:@"usingRichText"];
	BDSKTemplate *template = nil;
    // make sure we get something
	if (templateStyle == nil && templateString == nil && templateAttrString == nil) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
        return nil;
	}
	// make sure we get the right thing
	if ([templateStyle isKindOfClass:[NSString class]] ) {
        template = [BDSKTemplate templateForStyle:templateStyle];
	} else if ([templateStyle isKindOfClass:[NSURL class]] ) {
        NSString *fileType = [[templateStyle path] pathExtension];
        template = [BDSKTemplate templateWithName:@"" mainPageURL:templateStyle fileType:fileType ?: @"txt"];
	} else if ([templateString isKindOfClass:[NSString class]] ) {
        NSString *fileType = [[fileURL path] pathExtension];
        template = [BDSKTemplate templateWithString:templateString fileType:fileType ?: @"txt"];
	} else if ([templateAttrString isKindOfClass:[NSAttributedString class]] ) {
        NSString *fileType = [[fileURL path] pathExtension];
        template = [BDSKTemplate templateWithAttributedString:templateAttrString fileType:fileType ?: @"rtf"];
    }
    if (template == nil) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
        return nil;
	}
	
	// the 'for' parameter can select the items to template
	NSArray *publications = [document publications];
    id obj = [params objectForKey:@"for"];
    NSArray *items = nil;
	if (obj) {
		// the parameter is present
		if ([obj isKindOfClass:[BibItem class]]) {
            items = [NSArray arrayWithObject:obj];
		} else if ([obj isKindOfClass:[NSArray class]]) {
            items = obj;
            id lastObject = [obj lastObject];
            if ([lastObject isKindOfClass:[BibItem class]] == NO && [lastObject respondsToSelector:@selector(objectsByEvaluatingSpecifier)])
                items = [obj arrayByPerformingSelector:@selector(objectsByEvaluatingSpecifier)];
        } else {
			// wrong kind of argument
			[self setScriptErrorNumber:NSArgumentsWrongScriptError];
			[self setScriptErrorString:NSLocalizedString(@"The 'for' option needs to be a publication or a list of publications.",@"Error description")];
			return nil;
		}
		
	} else {
        items = publications;
    }
	
	// the 'in' parameter can select the items context to template
    obj = [params objectForKey:@"in"];
    NSArray *itemsContext = nil;
	if (obj) {
		// the parameter is present
		if ([obj isKindOfClass:[BibItem class]]) {
            items = [NSArray arrayWithObject:obj];
		} else if ([obj isKindOfClass:[NSArray class]]) {
            id lastObject = [obj lastObject];
            if ([lastObject isKindOfClass:[BibItem class]] == NO && [lastObject respondsToSelector:@selector(objectsByEvaluatingSpecifier)])
                items = [obj arrayByPerformingSelector:@selector(objectsByEvaluatingSpecifier)];
        } else {
			// wrong kind of argument
			[self setScriptErrorNumber:NSArgumentsWrongScriptError];
			[self setScriptErrorString:NSLocalizedString(@"The 'in' option needs to be a publication or a list of publications.",@"Error description")];
			return [[[NSTextStorage alloc] init] autorelease];
		}
		
	}
    
    NSData *fileData = nil;
    
    if ([template templateFormat] & BDSKRichTextTemplateFormat) {
        fileData = [document attributedStringDataForPublications:items publicationsContext:itemsContext usingTemplate:template];
    } else {
        fileData = [document stringDataForPublications:items publicationsContext:itemsContext usingTemplate:template];
    }
    
    if (fileData == nil) {
        [self setScriptErrorNumber:NSInternalScriptError];
        [self setScriptErrorString:NSLocalizedString(@"Could not parse template.",@"Error description")];
        return nil;
    }
    
    if (fileURL) {
        [fileData writeToURL:fileURL atomically:YES];
        
        NSURL *destDirURL = [fileURL URLByDeletingLastPathComponent];
        for (NSURL *accessoryURL in [template accessoryFileURLs])
            [[NSFileManager defaultManager] copyObjectAtURL:accessoryURL toDirectoryAtURL:destDirURL error:NULL];
    } else {
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        NSString *string = nil;
        if ([template templateFormat] & BDSKRichTextTemplateFormat) {
            [pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NSRTFPboardType, nil] owner:nil];
            string = [[[[NSAttributedString alloc] initWithRTF:fileData documentAttributes:NULL] autorelease] string];
            [pboard setData:fileData forType:NSRTFPboardType];
        } else {
            [pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:nil];
            string = [[[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding] autorelease];
        }
        [pboard setString:string forType:NSStringPboardType];
    }
    
	return nil;
}

@end

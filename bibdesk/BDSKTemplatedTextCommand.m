//
//  BDSKTemplatedTextCommand.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/18/06.
/*
 This software is Copyright (c) 2006-2009
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

#import "BDSKTemplatedTextCommand.h"
#import "BibDocument.h"
#import "BDSKTemplate.h"
#import "BDSKTemplateObjectProxy.h"
#import "BDSKPublicationsArray.h"
#import "NSArray_BDSKExtensions.h"
#import "BibItem.h"

@implementation BDSKTemplatedTextCommand

- (id)performDefaultImplementation {

	// figure out parameters first
	NSDictionary *params = [self evaluatedArguments];
	if (!params) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
        return [NSNull null];
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
        return [NSNull null];
	}
	
	// the 'using' parameters gives the template name or file to use
	id templateStyle = [params objectForKey:@"using"];
	id templateString = [params objectForKey:@"usingText"];
	BDSKTemplate *template = nil;
    // make sure we get something
	if (templateStyle == nil && templateString == nil) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
        return [NSNull null];
	}
	// make sure we get the right thing
	if ([templateStyle isKindOfClass:[NSString class]] ) {
        template = [BDSKTemplate templateForStyle:templateStyle];
	} else if ([templateStyle isKindOfClass:[NSURL class]] ) {
        NSString *fileType = [[templateStyle path] pathExtension];
        template = [BDSKTemplate templateWithName:@"" mainPageURL:templateStyle fileType:fileType ?: @"txt"];
	} else if ([templateString isKindOfClass:[NSString class]] ) {
        template = [BDSKTemplate templateWithString:templateString fileType:@"txt"];
    }
    if (template == nil) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
        return [NSNull null];
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
            id lastObject = [obj lastObject];
            if ([lastObject isKindOfClass:[BibItem class]] == NO && [lastObject respondsToSelector:@selector(objectsByEvaluatingSpecifier)])
                items = [obj arrayByPerformingSelector:@selector(objectsByEvaluatingSpecifier)];
        } else {
			// wrong kind of argument
			[self setScriptErrorNumber:NSArgumentsWrongScriptError];
			[self setScriptErrorString:NSLocalizedString(@"The 'for' option needs to be a publication or a list of publications.",@"Error description")];
            return [NSNull null];
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
            return [NSNull null];
		}
		
	}
    
    NSString *templatedText = nil;
    
    if ([template templateFormat] & BDSKRichTextTemplateFormat) {
        templatedText = [[BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:document publications:items publicationsContext:itemsContext documentAttributes:NULL] string];
    } else {
        templatedText = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:document publications:items publicationsContext:itemsContext];
    }
	
	return templatedText;
}

@end


@implementation BDSKTemplatedRichTextCommand

- (id)performDefaultImplementation {

	// figure out parameters first
	NSDictionary *params = [self evaluatedArguments];
	if (!params) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
        return [NSNull null];
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
		[self setScriptErrorString:NSLocalizedString(@"The templated rich text command can only be sent to the documents.", @"Error description")];
        return [NSNull null];
	}
	
	// the 'using' parameters gives the template name to use
	id templateStyle = [params objectForKey:@"using"];
	id templateAttrString = [params objectForKey:@"usingRichText"];
	id templateRTF = [params objectForKey:@"usingRTF"];
	BDSKTemplate *template = nil;
    // make sure we get something
	if (templateStyle == nil && templateAttrString == nil && templateRTF == nil) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
        return [NSNull null];
	}
	// make sure we get the right thing
	if ([templateStyle isKindOfClass:[NSString class]] ) {
        template = [BDSKTemplate templateForStyle:templateStyle];
	} else if ([templateStyle isKindOfClass:[NSURL class]] ) {
        NSString *fileType = [[templateStyle path] pathExtension];
        template = [BDSKTemplate templateWithName:@"" mainPageURL:templateStyle fileType:fileType ?: @"rtf"];
	} else if ([templateAttrString isKindOfClass:[NSAttributedString class]] ) {
        template = [BDSKTemplate templateWithAttributedString:templateAttrString fileType:@"rtf"];
	} else if ([templateRTF isKindOfClass:[NSAppleEventDescriptor class]] ) {
        templateAttrString = [[[NSAttributedString alloc] initWithRTF:[templateRTF data] documentAttributes:nil] autorelease];
        template = [BDSKTemplate templateWithAttributedString:templateAttrString fileType:@"rtf"];
    }
    if (template == nil) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
        return [NSNull null];
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
            id lastObject = [obj lastObject];
            if ([lastObject isKindOfClass:[BibItem class]] == NO && [lastObject respondsToSelector:@selector(objectsByEvaluatingSpecifier)])
                items = [obj arrayByPerformingSelector:@selector(objectsByEvaluatingSpecifier)];
        } else {
			// wrong kind of argument
			[self setScriptErrorNumber:NSArgumentsWrongScriptError];
			[self setScriptErrorString:NSLocalizedString(@"The 'for' option needs to be a publication or a list of publications.",@"Error description")];
            return [NSNull null];
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
            return [NSNull null];
		}
		
	}
    
    if ([template templateFormat] & BDSKRichTextTemplateFormat) {
        NSAttributedString *templatedRichText = [BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:document publications:items publicationsContext:itemsContext documentAttributes:NULL];
        return [[[NSTextStorage alloc] initWithAttributedString:templatedRichText] autorelease];
    } else {
        NSString *templatedText = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:document publications:items publicationsContext:itemsContext];
        return [[[NSTextStorage alloc] initWithString:templatedText] autorelease];
    }
}

@end


@implementation BDSKTemplatedRTFCommand

- (id)performDefaultImplementation {

	// figure out parameters first
	NSDictionary *params = [self evaluatedArguments];
	if (!params) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
        return [NSAppleEventDescriptor descriptorWithDescriptorType:'RTF ' data:[[[[NSAttributedString alloc] init] autorelease] RTFFromRange:NSMakeRange(0, 0) documentAttributes:nil]];
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
		[self setScriptErrorString:NSLocalizedString(@"The templated RTF command can only be sent to the documents.", @"Error description")];
        return [NSNull null];
	}
	
	// the 'using' parameters gives the template name to use
	id templateStyle = [params objectForKey:@"using"];
	id templateAttrString = [params objectForKey:@"usingRichText"];
	id templateRTF = [params objectForKey:@"usingRTF"];
	BDSKTemplate *template = nil;
    // make sure we get something
	if (templateStyle == nil && templateAttrString == nil && templateRTF == nil) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
        return [NSNull null];
	}
	// make sure we get the right thing
	if ([templateStyle isKindOfClass:[NSString class]] ) {
        template = [BDSKTemplate templateForStyle:templateStyle];
	} else if ([templateStyle isKindOfClass:[NSURL class]] ) {
        NSString *fileType = [[templateStyle path] pathExtension];
        template = [BDSKTemplate templateWithName:@"" mainPageURL:templateStyle fileType:fileType ?: @"rtf"];
	} else if ([templateAttrString isKindOfClass:[NSAttributedString class]] ) {
        template = [BDSKTemplate templateWithAttributedString:templateAttrString fileType:@"rtf"];
	} else if ([templateRTF isKindOfClass:[NSAppleEventDescriptor class]] ) {
        templateAttrString = [[[NSAttributedString alloc] initWithRTF:[templateRTF data] documentAttributes:nil] autorelease];
        template = [BDSKTemplate templateWithAttributedString:templateAttrString fileType:@"rtf"];
    }
    if (template == nil) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
        return [NSNull null];
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
            id lastObject = [obj lastObject];
            if ([lastObject isKindOfClass:[BibItem class]] == NO && [lastObject respondsToSelector:@selector(objectsByEvaluatingSpecifier)])
                items = [obj arrayByPerformingSelector:@selector(objectsByEvaluatingSpecifier)];
        } else {
			// wrong kind of argument
			[self setScriptErrorNumber:NSArgumentsWrongScriptError];
			[self setScriptErrorString:NSLocalizedString(@"The 'for' option needs to be a publication or a list of publications.",@"Error description")];
            return [NSNull null];
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
            return [NSNull null];
		}
		
	}
    
    if ([template templateFormat] & BDSKRichTextTemplateFormat) {
        NSAttributedString *templatedRichText = [BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:document publications:items publicationsContext:itemsContext documentAttributes:NULL];
        return [NSAppleEventDescriptor descriptorWithDescriptorType:'RTF ' data:[templatedRichText RTFFromRange:NSMakeRange(0, [templatedRichText length]) documentAttributes:nil]];
    } else {
        NSString *templatedText = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:document publications:items publicationsContext:itemsContext];
        NSAttributedString *templatedRichText = [[[NSAttributedString alloc] initWithString:templatedText] autorelease];
        return [NSAppleEventDescriptor descriptorWithDescriptorType:'RTF ' data:[templatedRichText RTFFromRange:NSMakeRange(0, [templatedRichText length]) documentAttributes:nil]];
    }
}

@end

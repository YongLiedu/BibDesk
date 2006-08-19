//
//  BibDeskTemplatedTextCommand.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 18/8/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "BibDeskTemplatedTextCommand.h"
#import "BibDocument.h"
#import "BDSKTemplate.h"


@implementation BibDeskTemplatedTextCommand

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
    } else if ([dPO isKindOfClass:[BibDocument class]] == NO) {
        document = dPO;
    } else {
		// give up
		[self setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
		[self setScriptErrorString:NSLocalizedString(@"The templated text command can only be sent to the documents.", @"")];
		return @"";
	}
	
	// the 'using' parameters gives the template name to use
	NSString *templateStyle = [params objectForKey:@"using"];
	// make sure we get something
	if (!templateStyle) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
		return [NSArray array];
	}
	// make sure we get the right thing
	if (![templateStyle isKindOfClass:[NSString class]] ) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
			return @"";
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
            NSEnumerator *e = [(NSArray *)obj objectEnumerator];
            NSIndexSpecifier *i;
            NSMutableArray *pubs = [NSMutableArray array];
            
            while (i = [e nextObject]) {
                [pubs addObject:[publications objectAtIndex:[i index]]];
            }
            items = pubs;
        } else {
			// wrong kind of argument
			[self setScriptErrorNumber:NSArgumentsWrongScriptError];
			[self setScriptErrorString:NSLocalizedString(@"The 'for' option needs to be a publication or a list of publications.",@"")];
			return @"";
		}
		
	} else {
        items = publications;
    }
    
    BDSKTemplate *template = [BDSKTemplate templateForStyle:templateStyle];
    NSString *templatedText = nil;
    
    if ([template templateFormat] & BDSKRichTextTemplateFormat) {
        templatedText = [[BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:document publications:items documentAttributes:NULL] string];
    } else {
        templatedText = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:document publications:items];
    }
	
	return templatedText;
}

@end


@implementation BibDeskTemplatedRichTextCommand

- (id)performDefaultImplementation {

	// figure out parameters first
	NSDictionary *params = [self evaluatedArguments];
	if (!params) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
		return [[[NSTextStorage alloc] init] autorelease];
	}
	
	BibDocument *document = nil;
	id receiver = [self evaluatedReceivers];
    NSScriptObjectSpecifier *dP = [self directParameter];
	id dPO = [dP objectsByEvaluatingSpecifier];

	if ([receiver isKindOfClass:[BibDocument class]]) {
        document = receiver;
    } else if ([dPO isKindOfClass:[BibDocument class]] == NO) {
        document = dPO;
    } else {
		// give up
		[self setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
		[self setScriptErrorString:NSLocalizedString(@"The templated text command can only be sent to the documents.", @"")];
		return [[[NSTextStorage alloc] init] autorelease];
	}
	
	// the 'using' parameters gives the template name to use
	NSString *templateStyle = [params objectForKey:@"using"];
	// make sure we get something
	if (!templateStyle) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
		return [[[NSTextStorage alloc] init] autorelease];
	}
	// make sure we get the right thing
	if (![templateStyle isKindOfClass:[NSString class]] ) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
		return [NSArray array];
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
            NSEnumerator *e = [(NSArray *)obj objectEnumerator];
            NSIndexSpecifier *i;
            NSMutableArray *pubs = [NSMutableArray array];
            
            while (i = [e nextObject]) {
                [pubs addObject:[publications objectAtIndex:[i index]]];
            }
            items = pubs;
        } else {
			// wrong kind of argument
			[self setScriptErrorNumber:NSArgumentsWrongScriptError];
			[self setScriptErrorString:NSLocalizedString(@"The 'for' option needs to be a publication or a list of publications.",@"")];
		return [[[NSTextStorage alloc] init] autorelease];
		}
		
	} else {
        items = publications;
    }
    
    BDSKTemplate *template = [BDSKTemplate templateForStyle:templateStyle];
    
    if ([template templateFormat] & BDSKRichTextTemplateFormat) {
        NSAttributedString *templatedRichText = [BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:document publications:items documentAttributes:NULL];
        return [[[NSTextStorage alloc] initWithAttributedString:templatedRichText] autorelease];
    } else {
        NSString *templatedText = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:document publications:items];
        return [[[NSTextStorage alloc] initWithString:templatedText] autorelease];
    }
	
}

@end

//
//  BDSKSearchForCommand.m
//  BibDesk
//
//  Created by Sven-S. Porst on Wed Jul 21 2004.
/*
 This software is Copyright (c) 2004-2011
 Sven-S. Porst. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Sven-S. Porst nor the names of any
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

#import "BDSKSearchForCommand.h"
#import "BibAuthor.h"
#import "BibItem.h"
#import "BibDocument.h"
#import "BibDocument_Search.h"


@interface BibItem (Finding)
- (NSString *)stringForCompletion;
@end


/* ssp: 2004-07-20
To be used for finding bibliography information from a keyword with AppleScript.
The command should have the form
	search (document|application) for (searchterm) [for autocompletion (yes|no)]
*/
@implementation BDSKSearchForCommand

- (id)performDefaultImplementation {

	// figure out parameters first
	NSDictionary *params = [self evaluatedArguments];
	if (!params) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
		return [NSArray array];
	}
	
	// the 'for' parameters gives the term to search for
	NSString *searchterm = [params objectForKey:@"for"];
	// make sure we get something
	if (!searchterm) {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
		return [NSArray array];
	}
	// make sure we get the right thing
	if (![searchterm isKindOfClass:[NSString class]] ) {
		[self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
		return [NSArray array];
	}
	
	// the 'forCompletion' parameter can modify what we return
	BOOL forCompletion = NO;
	id fC = [params objectForKey:@"forCompletion"];
	if (fC) {
		// the parameter is present
		if (![fC isKindOfClass:[NSNumber class]]) {
			// wrong kind of argument
			[self setScriptErrorNumber:NSArgumentsWrongScriptError];
			[self setScriptErrorString:NSLocalizedString(@"The 'for completion' option needs to be specified as yes or no. E.g.: search for search_term for completion yes", @"Error description")];
			return [NSArray array];
		}
		
		forCompletion = [(NSNumber*)fC boolValue];
	}
	
	
	// now let's get some results
	
	NSMutableArray *results = [NSMutableArray array];
	id receiver = [self evaluatedReceivers];
    NSScriptObjectSpecifier *dP = [self directParameter];
	id dPO = [dP objectsByEvaluatingSpecifier];

	if ([receiver isKindOfClass:[NSApplication class]] && dP == nil) {
		// we are sent to the application and there is no direct paramter that might redirect the command
		for (BibDocument *bd in [NSApp orderedDocuments])
			[results addObjectsFromArray:[bd publicationsMatchingString:searchterm]];
	} else if ([receiver isKindOfClass:[BibDocument class]] || [dPO isKindOfClass:[BibDocument class]]) {
		// the condition above might not be good enough
		// we are sent or addressed to a document
		[results addObjectsFromArray:[(BibDocument*)dPO publicationsMatchingString:searchterm]];
	} else if ([receiver isKindOfClass:[NSArray class]]){
        for (id anObject in receiver) {
            if ([anObject isKindOfClass:[BibDocument class]])
                [results addObjectsFromArray:[anObject publicationsMatchingString:searchterm]];
        }
        
    } else {
		// give up
		[self setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
		[self setScriptErrorString:NSLocalizedString(@"The search command can only be sent to the application itself or to documents. Usually it is used in the form \"search for search_term\".", @"Error description")];
		return [NSArray array];
	}

	
	if (forCompletion) {
		// we're doing this for completion, so return a different array. Instead of an array of publications (BibItems) this will simply be an array of strings containing the cite key, the authors' surnames and the title for the publication. This could be sufficient for completion and allows the application possibly integrating with BibDesk to remain ignorant of the inner workings of BibItems.
		NSInteger i, n = [results count];
		BibItem * result;
		for (i = 0; i < n; i++)
			[results replaceObjectAtIndex:i withObject:[[results objectAtIndex:i] stringForCompletion]];
		// sort alphabetically
		[results sortUsingSelector:@selector(caseInsensitiveCompare:)];
	}
	
	
	return results;
}

@end


@implementation BibItem (Finding)

// returns a string displayed by the autocomplete plugin

- (NSString *) stringForCompletion {
	// concatenate author surnames first
    NSArray *pubAuthors = [self pubAuthors];
	NSEnumerator *authEnum = [pubAuthors objectEnumerator];
	BibAuthor *auth = nil;
	NSMutableString * surnames = [NSMutableString string];
	auth = [authEnum nextObject];
	if (auth) {
        NSString *name = [auth lastName] ?: [auth name];
        if (nil != name)
            [surnames appendString:name];	
		if([pubAuthors count] > 2){
            [surnames appendString:@" et al"];
		} else {
            while ((auth = [authEnum nextObject]))
                [surnames appendFormat:@"-%@", [auth lastName]];
        }
	}
	
	return [[self citeKey] stringByAppendingFormat: @" %% %@, %@", surnames, [self displayTitle]];
	
}
@end

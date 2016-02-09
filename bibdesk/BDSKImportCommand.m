//
//  BDSKImportCommand.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/5/08.
/*
 This software is Copyright (c) 2008-2016
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
//  Created by Christiaan Hofman on 12/5/08.
/*
 This software is Copyright (c) 2008-2016
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

#import "BDSKImportCommand.h"
#import "BibDocument.h"
#import "BibItem.h"
#import "BibItem_PubMedLookup.h"
#import "NSString_BDSKExtensions.h"
#import "BDSKStringParser.h"
#import "BDSKSearchGroup.h"
#import "BDSKPublicationsArray.h"
#import "BDSKServerInfo.h"
#import "BDSKSearchGroupServerManager.h"
#import "BDSKGroup+Scripting.h"


@interface BDSKImportSearch : NSObject <BDSKSearchGroup> {
    NSArray *publications;
    BOOL importFinished;
}
- (NSArray *)searchUsingSearchTerm:(NSString *)searchTerm serverInfo:(BDSKServerInfo *)serverInfo;
@end


@implementation BDSKImportCommand

- (id)performDefaultImplementation {

	// figure out parameters first
	NSDictionary *params = [self evaluatedArguments];
	if (params == nil) {
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
		[self setScriptErrorString:NSLocalizedString(@"The import command can only be sent to the documents.", @"Error description")];
		return nil;
	}
	
	// the 'from' parameters gives the template name to use
	id string = [params objectForKey:@"from"];
	id searchTerm = [params objectForKey:@"searchTerm"];
	id url = [params objectForKey:@"with"];
    NSArray *pubs = nil;
    
    if ([url isKindOfClass:[NSString class]]) {
        url = [url hasPrefix:@"/"] ? [NSURL fileURLWithPath:url] : [NSURL URLWithString:url];
    } else if (url && [url isKindOfClass:[NSURL class]] == NO) {
        [self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
        return nil;
    }
    // make sure we get something
	if (string) {
        // make sure we get the right thing
        if ([string isKindOfClass:[NSURL class]]) {
            string = [NSString stringWithContentsOfFile:[string path] guessedEncoding:0];
        } else if ([string isKindOfClass:[NSString class]] == NO) {
            [self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
            return nil;
        }
        pubs = [BDSKStringParser itemsFromString:string ofType:BDSKUnknownStringType owner:document error:NULL];
    } else if (searchTerm) {
        id server = [params objectForKey:@"server"];
        if (server) {
            BDSKServerInfo *serverInfo = nil;
            // the server can be a scriptingServerInfo dictionary, a .bdsksearch file URL, a x-bdsk-search URL, or a default server name
            if ([server isKindOfClass:[NSDictionary class]]) {
                if ([server count] == 1 && [server objectForKey:@"name"])
                    server = [server objectForKey:@"name"];
                else
                    serverInfo = [[BDSKSearchGroup newServerInfo:nil withScriptingServerInfo:server] autorelease];
            } else if ([server isKindOfClass:[NSURL class]]) {
                serverInfo = [[[BDSKServerInfo alloc] initWithDictionary:[NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:server]]] autorelease];
            }
            if ([server isKindOfClass:[NSString class]]) {
                if ([server hasPrefix:@"x-bdsk-search://"]) {
                    serverInfo = [[[BDSKServerInfo alloc] initWithDictionary:[BDSKSearchGroup dictionaryWithBdsksearchURL:[NSURL URLWithString:server]]] autorelease];
                } else {
                    NSArray *servers = [[BDSKSearchGroupServerManager sharedManager] servers];
                    NSUInteger i = [[servers valueForKey:@"name"] indexOfObject:server];
                    if (i != NSNotFound)
                        serverInfo = [servers objectAtIndex:i];
                }
            } 
            if (serverInfo == nil) {
                [self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
                return nil;
            }
            BDSKImportSearch *search = [[BDSKImportSearch alloc] init];
            pubs = [search searchUsingSearchTerm:searchTerm serverInfo:serverInfo];
            // we have to hand the pubs over to the document with the correct macro resolver
            if (pubs)
                pubs = [document transferredPublications:pubs];
            [search release];
        } else {
            pubs = [NSArray arrayWithObjects:[BibItem itemWithPubMedSearchTerm:searchTerm], nil];
        }
    } else if (url) {
        if ([url isKindOfClass:[NSURL class]]) {
            if ([url isFileURL])
                pubs = [NSArray arrayWithObjects:[BibItem itemWithFileURL:url owner:document], nil];
            else
                pubs = [NSArray arrayWithObjects:[BibItem itemWithURL:url title:nil], nil];
        } else {
            [self setScriptErrorNumber:NSArgumentsWrongScriptError]; 
            return nil;
        }
    } else {
		[self setScriptErrorNumber:NSRequiredArgumentsMissingScriptError]; 
        return nil;
	}
	if ([pubs count] > 0) {
        if (url != nil && (string != nil || searchTerm != nil)) {
            for (BibItem *pub in pubs)
                [pub addFileForURL:url autoFile:NO runScriptHook:NO];
        }
    	[document importPublications:pubs publicationsToAutoFile:([url isFileURL] ? pubs : nil) temporaryCiteKey:nil options:BDSKImportAggregate | BDSKImportNoEdit];
    }
	
    return pubs ?: [NSArray array];
}

@end


@implementation BDSKImportSearch

- (void)dealloc {
    BDSKDESTROY(publications);
    [super dealloc];
}

- (NSArray *)searchUsingSearchTerm:(NSString *)searchTerm serverInfo:(BDSKServerInfo *)serverInfo {
    id<BDSKSearchGroupServer> server = [BDSKSearchGroup copyServerWithGroup:self serverInfo:serverInfo];
    
    importFinished = NO;
    
    [server retrieveWithSearchTerm:searchTerm];
    
	NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
	while (importFinished == NO && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
    
    [server terminate];
    [server release];
    
    return [publications count] > 0 ? publications : nil;
}

#pragma mark BDSKSearchGroup protocol

- (void)addPublications:(NSArray *)pubs {
    BDSKDESTROY(publications);
    if ([pubs count] > 0)
        publications = [pubs copy];
    importFinished = YES;
}

- (BDSKPublicationsArray *)publications { return nil; }

- (BDSKMacroResolver *)macroResolver { return nil; }

- (NSUndoManager *)undoManager { return nil; }

- (NSURL *)fileURL { return nil; }

- (NSString *)documentInfoForKey:(NSString *)key { return nil; }

- (BOOL)isDocument { return NO; }

- (BDSKItemSearchIndexes *)searchIndexes{ return nil; }

@end

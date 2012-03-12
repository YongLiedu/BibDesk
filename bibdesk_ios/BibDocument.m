//
//  BibDocument.m
//  BibDesk
//
//  Created by Colin A. Smith on 3/9/12.
/*
 This software is Copyright (c) 2012-2012
 Colin A. Smith. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Colin A. Smith nor the names of any
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

#import "BibDocument.h"
#import "BDSKPublicationsArray.h"
#import "BDSKMacroResolver.h"
#import "BDSKBibTeXParser.h"
#import "BDSKGroupsArray.h"
#import "NSDictionary_BDSKExtensions.h"

@implementation BibDocument

- (id)initWithFileURL:(NSURL *)url {

    if ((self = [super initWithFileURL:url])) {
    
        publications = [[BDSKPublicationsArray alloc] init];
        macroResolver = [[BDSKMacroResolver alloc] initWithOwner:self];
        documentInfo = nil;
        wasLoaded = NO;
    }

    return self;
}

- (void) dealloc {

    [publications release];
    [macroResolver release];
    [documentInfo release];
    
    [super dealloc];
}

- (BOOL)isDocument {

    return YES;
}

- (BDSKMacroResolver *)macroResolver {

    return macroResolver;
}

- (NSString *)documentInfoForKey:(NSString *)key {

    return [documentInfo valueForKey:key];
}

- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError **)outError {

    NSData *data = contents;

    NSStringEncoding encoding = NSUTF8StringEncoding;
    NSStringEncoding parserEncoding = NSUTF8StringEncoding;

    NSError *error = nil;
    BOOL isPartialData;
    NSArray *newPubs;
    NSDictionary *newMacros = nil;
    NSDictionary *newGroups = nil;
    NSDictionary *newDocumentInfo = nil;
    NSString *filePath = self.fileURL.path;
    NSString *newFrontMatter = nil;
    
    newPubs = [BDSKBibTeXParser itemsFromData:data macros:&newMacros documentInfo:&newDocumentInfo groups:&newGroups frontMatter:&newFrontMatter filePath:filePath owner:self encoding:parserEncoding isPartialData:&isPartialData error:&error];
    
    if (isPartialData == NO) {
        [self setPublications:newPubs macros:newMacros documentInfo:newDocumentInfo groups:newGroups frontMatter:newFrontMatter encoding:encoding];
        return YES;
    } else {
        return NO;
    }
}

- (void)setPublications:(NSArray *)newPubs macros:(NSDictionary *)newMacros documentInfo:(NSDictionary *)newDocumentInfo groups:(NSDictionary *)newGroups frontMatter:(NSString *)newFrontMatter encoding:(NSStringEncoding)newEncoding {
    
    if (wasLoaded) {
        NSArray *oldPubs = [[publications copy] autorelease];
        NSDictionary *oldMacros = [[[[self macroResolver] macroDefinitions] copy] autorelease];
        NSMutableDictionary *oldGroups = [NSMutableDictionary dictionary];
        NSData *groupData;
        
        if ((groupData = [[self groups] serializedGroupsDataOfType:BDSKSmartGroupType]))
            [oldGroups setObject:groupData forKey:[NSNumber numberWithInteger:BDSKSmartGroupType]];
        if ((groupData = [[self groups] serializedGroupsDataOfType:BDSKStaticGroupType]))
            [oldGroups setObject:groupData forKey:[NSNumber numberWithInteger:BDSKStaticGroupType]];
        if ((groupData = [[self groups] serializedGroupsDataOfType:BDSKURLGroupType]))
            [oldGroups setObject:groupData forKey:[NSNumber numberWithInteger:BDSKURLGroupType]];
        if ((groupData = [[self groups] serializedGroupsDataOfType:BDSKScriptGroupType]))
            [oldGroups setObject:groupData forKey:[NSNumber numberWithInteger:BDSKScriptGroupType]];
         
        [[[self undoManager] prepareWithInvocationTarget:self] setPublications:oldPubs macros:oldMacros documentInfo:documentInfo groups:oldGroups frontMatter:frontMatter encoding:[self documentStringEncoding]];
        
        // make sure we clear all groups that are saved in the file, should only have those for revert
        // better do this here, so we don't remove them when reading the data fails
        [groups removeAllUndoableGroups]; // this also removes editor windows for external groups
    }
    
    [self setDocumentStringEncoding:newEncoding];
    [self setPublications:newPubs];
    [documentInfo release];
    documentInfo = [[NSDictionary alloc] initForCaseInsensitiveKeysWithDictionary:newDocumentInfo];
    [[self macroResolver] setMacroDefinitions:newMacros];
    // important that groups are loaded after publications, otherwise the static groups won't find their publications
    for (NSNumber *groupType in newGroups)
        [[self groups] setGroupsOfType:[groupType integerValue] fromSerializedData:[newGroups objectForKey:groupType]];
    [frontMatter release];
    frontMatter = [newFrontMatter retain];
    
    if (wasLoaded) {
        //[self sortGroupsByKey:nil]; // resort
        //[self sortPubsByKey:nil]; // resort
    }
    
    wasLoaded = YES;
}

#pragma mark -
#pragma mark Publications acessors

// This is not undoable!
- (void)setPublications:(NSArray *)newPubs{
    [publications setValue:nil forKey:@"owner"];
    [publications setArray:newPubs];
    [publications setValue:self forKey:@"owner"];
}    

- (BDSKPublicationsArray *)publications{
    return publications;
}

#pragma mark Groups accessors

- (BDSKGroupsArray *)groups{
    return groups;
}

#pragma mark -

- (void)setDocumentStringEncoding:(NSStringEncoding)encoding{
    documentStringEncoding = encoding;
}

- (NSStringEncoding)documentStringEncoding{
    return documentStringEncoding;
}


@end

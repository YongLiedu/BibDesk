//
//  BDSKGroup+Scripting.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/5/08.
/*
 This software is Copyright (c) 2008-2011
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

#import <Cocoa/Cocoa.h>
#import "BDSKGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKSmartGroup.h"
#import "BDSKCategoryGroup.h"
#import "BDSKURLGroup.h"
#import "BDSKScriptGroup.h"
#import "BDSKSearchGroup.h"
#import "BDSKSharedGroup.h"
#import "BDSKLibraryGroup.h"
#import "BDSKLastImportGroup.h"
#import "BDSKWebGroup.h"

@class BDSKMacro, BibItem, BibAuthor, BDSKCondition;

@interface BDSKGroup (Scripting)

- (id)valueInScriptingPublicationsWithUniqueID:(NSString *)uniqueID;
- (NSArray *)scriptingPublications;

- (NSArray *)authors;
- (BibAuthor *)valueInAuthorsWithName:(NSString *)aName;

- (NSArray *)editors;
- (BibAuthor *)valueInEditorsWithName:(NSString *)aName;

- (BDSKMacro *)valueInMacrosWithName:(NSString *)aName;
- (NSArray *)macros;

- (NSString *)scriptingName;

@end

#pragma mark -

@interface BDSKLibraryGroup (Scripting)

- (void)insertObject:(BibItem *)pub inScriptingPublicationsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromScriptingPublicationsAtIndex:(NSUInteger)idx;

@end

#pragma mark -

@interface BDSKMutableGroup (Scripting)

- (void)setScriptingName:(NSString *)newName;

@end

#pragma mark -

@interface BDSKStaticGroup (Scripting)

- (void)insertObject:(BibItem *)pub inScriptingPublicationsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromScriptingPublicationsAtIndex:(NSUInteger)idx;

@end

#pragma mark -

@interface BDSKLastImportGroup (Scripting)
@end

#pragma mark -

@interface BDSKSmartGroup (Scripting)

- (NSArray *)conditions;
- (void)insertObject:(BDSKCondition *)condition inConditionsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromConditionsAtIndex:(NSUInteger)idx;

- (BOOL)satisfyAll;
- (void)setSatisfyAll:(BOOL)flag;

@end

#pragma mark -

@interface BDSKCategoryGroup (Scripting)

- (void)insertObject:(BibItem *)pub inScriptingPublicationsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromScriptingPublicationsAtIndex:(NSUInteger)idx;

@end

#pragma mark -

@interface BDSKURLGroup (Scripting)

- (NSString *)URLString;
- (void)setURLString:(NSString *)newURLString;

- (NSURL *)scriptingFileURL;
- (void)setScriptingFileURL:(NSURL *)newURL;

@end

#pragma mark -

@interface BDSKScriptGroup (Scripting)

- (NSURL *)scriptURL;
- (void)setScriptURL:(NSURL *)newScriptURL;

- (NSString *)scriptingScriptArguments;
- (void)setScriptingScriptArguments:(NSString *)newArguments;

@end

#pragma mark -

@interface BDSKSearchGroup (Scripting)

- (NSString *)scriptingSearchTerm;
- (void)setScriptingSearchTerm:(NSString *)newSerachTerm;

- (NSDictionary *)scriptingServerInfo;
- (void)setScriptingServerInfo:(NSDictionary *)info;

- (NSString *)scriptingServerType;

- (NSString *)scriptingServerName;

@end

#pragma mark -

@interface BDSKSharedGroup (Scripting)
@end

#pragma mark -

@interface BDSKWebGroup (Scripting)

- (NSString *)URLString;
- (void)setURLString:(NSString *)newURLString;

@end

//
//  BibDocument+Scripting.h
//  BibDesk
//
//  Created by Sven-S. Porst on Thu Jul 08 2004.
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

#import "BibDocument.h"

@class BDSKMacro, BDSKGroup, BDSKStaticGroup, BDSKSmartGroup, BDSKCategoryGroup, BDSKURLGroup, BDSKScriptGroup, BDSKSearchGroup, BDSKSharedGroup, BDSKLibraryGroup, BDSKLastImportGroup, BDSKWebGroup;

@interface BibDocument (Scripting) 

- (id)valueInScriptingPublicationsWithUniqueID:(NSString *)uniqueID;
- (NSArray *)scriptingPublications;
- (void)insertObject:(BibItem *)pub inScriptingPublicationsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromScriptingPublicationsAtIndex:(NSUInteger)idx;

- (BDSKMacro *)valueInMacrosWithName:(NSString *)name;
- (NSArray *)macros;

- (NSArray *)authors;
- (BibAuthor *)valueInAuthorsWithName:(NSString *)name;

- (NSArray *)editors;
- (BibAuthor *)valueInEditorsWithName:(NSString *)name;

- (NSArray *)scriptingGroups;
- (BDSKGroup *)valueInScriptingGroupsWithUniqueID:(NSString *)aUniqueID;
- (BDSKGroup *)valueInScriptingGroupsWithName:(NSString *)name;
- (void)insertObject:(BDSKGroup *)group inScriptingGroupsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromScriptingGroupsAtIndex:(NSUInteger)idx;

- (NSArray *)staticGroups;
- (BDSKStaticGroup *)valueInStaticGroupsWithUniqueID:(NSString *)aUniqueID;
- (BDSKStaticGroup *)valueInStaticGroupsWithName:(NSString *)name;
- (void)insertObject:(BDSKStaticGroup *)group inStaticGroupsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromStaticGroupsAtIndex:(NSUInteger)idx;

- (NSArray *)smartGroups;
- (BDSKSmartGroup *)valueInSmartGroupsWithUniqueID:(NSString *)aUniqueID;
- (BDSKSmartGroup *)valueInSmartGroupsWithName:(NSString *)name;
- (void)insertObject:(BDSKSmartGroup *)group inSmartGroupsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromSmartGroupsAtIndex:(NSUInteger)idx;

- (NSArray *)fieldGroups;
- (BDSKCategoryGroup *)valueInFieldGroupsWithUniqueID:(NSString *)aUniqueID;
- (BDSKCategoryGroup *)valueInFieldGroupsWithName:(NSString *)name;

- (NSArray *)externalFileGroups;
- (BDSKURLGroup *)valueInExternalFileGroupsWithUniqueID:(NSString *)aUniqueID;
- (BDSKURLGroup *)valueInExternalFileGroupsWithName:(NSString *)name;
- (void)insertObject:(BDSKURLGroup *)group inExternalFileGroupsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromExternalFileGroupsAtIndex:(NSUInteger)idx;

- (NSArray *)scriptGroups;
- (BDSKScriptGroup *)valueInScriptGroupsWithUniqueID:(NSString *)aUniqueID;
- (BDSKScriptGroup *)valueInScriptGroupsWithName:(NSString *)name;
- (void)removeObjectFromScriptGroupsAtIndex:(NSUInteger)idx;

- (NSArray *)webGroups;
- (BDSKWebGroup *)valueInWebGroupsWithUniqueID:(NSString *)aUniqueID;
- (BDSKWebGroup *)valueInWebGroupsWithName:(NSString *)name;
- (void)insertObject:(BDSKWebGroup *)group inWebGroupsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromWebGroupsAtIndex:(NSUInteger)idx;

- (NSArray *)searchGroups;
- (BDSKSearchGroup *)valueInSearchGroupsWithUniqueID:(NSString *)aUniqueID;
- (BDSKSearchGroup *)valueInSearchGroupsWithName:(NSString *)name;
- (void)insertObject:(BDSKSearchGroup *)group inSearchGroupsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromSearchGroupsAtIndex:(NSUInteger)idx;

- (NSArray *)sharedGroups;
- (BDSKSharedGroup *)valueInSharedGroupsWithUniqueID:(NSString *)aUniqueID;
- (BDSKSharedGroup *)valueInSharedGroupsWithName:(NSString *)name;

- (NSArray *)libraryGroups;
- (BDSKGroup *)valueInLibraryGroupsWithUniqueID:(NSString *)aUniqueID;
- (BDSKGroup *)valueInLibraryGroupsWithName:(NSString *)name;

- (NSArray *)lastImportGroups;
- (BDSKGroup *)valueInLastImportGroupsWithUniqueID:(NSString *)aUniqueID;
- (BDSKGroup *)valueInLastImportGroupsWithName:(NSString *)name;


- (NSArray*) selection;
- (void) setSelection: (NSArray*) newSelection;

- (NSArray *)groupSelection;
- (void)setGroupSelection:(NSArray *)newSelection;

@end

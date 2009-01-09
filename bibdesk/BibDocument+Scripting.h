//
//  BibDocument+Scripting.h
//  BibDesk
//
//  Created by Sven-S. Porst on Thu Jul 08 2004.
/*
 This software is Copyright (c) 2004-2009
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

- (NSArray *)scriptingPublications;
- (void)insertInScriptingPublications:(BibItem *)pub;
- (void)insertObject:(BibItem *)pub inScriptingPublicationsAtIndex:(unsigned int)idx;
- (void)removeObjectFromScriptingPublicationsAtIndex:(unsigned int)idx;

- (BDSKMacro *)valueInMacrosWithName:(NSString *)name;
- (NSArray *)macros;

- (NSArray *)authors;
- (BibAuthor *)valueInAuthorsWithName:(NSString *)name;

- (NSArray *)editors;
- (BibAuthor *)valueInEditorsWithName:(NSString *)name;

- (void)insertInGroups:(BDSKGroup *)group;
- (void)insertObject:(BDSKGroup *)group inGroupsAtIndex:(unsigned int)idx;
- (void)removeObjectFromGroupsAtIndex:(unsigned int)idx;

- (NSArray *)staticGroups;
- (BDSKStaticGroup *)valueInStaticGroupsWithName:(NSString *)name;
- (void)insertInStaticGroups:(BDSKStaticGroup *)group;
- (void)insertObject:(BDSKStaticGroup *)group inStaticGroupsAtIndex:(unsigned int)idx;
- (void)removeObjectFromStaticGroupsAtIndex:(unsigned int)idx;

- (NSArray *)smartGroups;
- (BDSKSmartGroup *)valueInSmartGroupsWithName:(NSString *)name;
- (void)insertInSmartGroups:(BDSKSmartGroup *)group;
- (void)insertObject:(BDSKSmartGroup *)group inSmartGroupsAtIndex:(unsigned int)idx;
- (void)removeObjectFromSmartGroupsAtIndex:(unsigned int)idx;

- (NSArray *)fieldGroups;
- (BDSKCategoryGroup *)valueInFieldGroupsWithName:(NSString *)name;

- (NSArray *)externalFileGroups;
- (BDSKURLGroup *)valueInExternalFileGroupsWithName:(NSString *)name;
- (void)insertInExternalFileGroups:(BDSKURLGroup *)group;
- (void)insertObject:(BDSKURLGroup *)group inExternalFileGroupsAtIndex:(unsigned int)idx;
- (void)removeObjectFromExternalFileGroupsAtIndex:(unsigned int)idx;

- (NSArray *)scriptGroups;
- (BDSKScriptGroup *)valueInScriptGroupsWithName:(NSString *)name;
- (void)insertInScriptGroups:(BDSKScriptGroup *)group;
- (void)removeObjectFromScriptGroupsAtIndex:(unsigned int)idx;

- (NSArray *)searchGroups;
- (BDSKSearchGroup *)valueInSearchGroupsWithName:(NSString *)name;
- (void)insertInSearchGroups:(BDSKSearchGroup *)group;
- (void)insertObject:(BDSKSearchGroup *)group inSearchGroupsAtIndex:(unsigned int)idx;
- (void)removeObjectFromSearchGroupsAtIndex:(unsigned int)idx;

- (NSArray *)sharedGroups;
- (BDSKSharedGroup *)valueInSharedGroupsWithName:(NSString *)name;

- (NSArray *)libraryGroups;
- (BDSKGroup *)valueInLibraryGroupsWithName:(NSString *)name;

- (NSArray *)lastImportGroups;
- (BDSKGroup *)valueInLastImportGroupsWithName:(NSString *)name;

- (NSArray *)webGroups;
- (BDSKWebGroup *)valueInWebGroupsWithName:(NSString *)name;


- (NSArray*) selection;
- (void) setSelection: (NSArray*) newSelection;

- (NSArray *)groupSelection;
- (void)setGroupSelection:(NSArray *)newSelection;

- (NSTextStorage*) textStorageForPublications:(NSArray *)pubs;

@end

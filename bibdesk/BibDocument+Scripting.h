//
//  BibDocument+Scripting.h
//  BibDesk
//
//  Created by Sven-S. Porst on Thu Jul 08 2004.
/*
 This software is Copyright (c) 2004-2008
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

- (unsigned int)countOfPublications;
- (BibItem *)objectInPublicationsAtIndex:(unsigned int)idx;
- (BibItem *)valueInPublicationsAtIndex:(unsigned int)index;
- (void)insertInPublications:(BibItem *)pub  atIndex:(unsigned int)index;
- (void)insertInPublications:(BibItem *)pub;
- (void)insertObject:(BibItem *)pub inPublicationsAtIndex:(unsigned int)idx;
- (void)removeFromPublicationsAtIndex:(unsigned int)index;
- (void)removeObjectFromPublicationsAtIndex:(unsigned int)idx;

- (BDSKMacro *)valueInMacrosWithName:(NSString *)name;
- (NSArray *)macros;

- (NSArray *)authors;
- (BibAuthor *)valueInAuthorsWithName:(NSString *)name;

- (NSArray *)editors;
- (BibAuthor *)valueInEditorsWithName:(NSString *)name;

- (unsigned int)countOfGroups;
- (BDSKGroup *)valueInGroupsAtIndex:(unsigned int)idx;
- (BDSKGroup *)objectInGroupsAtIndex:(unsigned int)idx;
- (BDSKGroup *)valueInGroupsWithName:(NSString *)name;
- (void)insertInGroups:(BDSKGroup *)group;
- (void)insertInGroups:(BDSKGroup *)group atIndex:(unsigned int)idx;
- (void)insertObject:(BDSKGroup *)group inGroupsAtIndex:(unsigned int)idx;
- (void)removeFromGroupsAtIndex:(unsigned int)idx;
- (void)removeObjectFromGroupsAtIndex:(unsigned int)idx;

- (unsigned int)countOfStaticGroups;
- (BDSKStaticGroup *)valueInStaticGroupsAtIndex:(unsigned int)idx;
- (BDSKStaticGroup *)objectInStaticGroupsAtIndex:(unsigned int)idx;
- (BDSKStaticGroup *)valueInStaticGroupsWithName:(NSString *)name;
- (void)insertInStaticGroups:(BDSKStaticGroup *)group;
- (void)insertInStaticGroups:(BDSKStaticGroup *)group atIndex:(unsigned int)idx;
- (void)insertObject:(BDSKStaticGroup *)group inStaticGroupsAtIndex:(unsigned int)idx;
- (void)removeFromStaticGroupsAtIndex:(unsigned int)idx;
- (void)removeObjectFromStaticGroupsAtIndex:(unsigned int)idx;

- (unsigned int)countOfSmartGroups;
- (BDSKSmartGroup *)valueInSmartGroupsAtIndex:(unsigned int)idx;
- (BDSKSmartGroup *)objectInSmartGroupsAtIndex:(unsigned int)idx;
- (BDSKSmartGroup *)valueInSmartGroupsWithName:(NSString *)name;
- (void)insertInSmartGroups:(BDSKSmartGroup *)group;
- (void)insertInSmartGroups:(BDSKSmartGroup *)group atIndex:(unsigned int)idx;
- (void)insertObject:(BDSKSmartGroup *)group inSmartGroupsAtIndex:(unsigned int)idx;
- (void)removeFromSmartGroupsAtIndex:(unsigned int)idx;
- (void)removeObjectFromSmartGroupsAtIndex:(unsigned int)idx;

- (unsigned int)countOfFieldGroups;
- (BDSKCategoryGroup *)valueInFieldGroupsAtIndex:(unsigned int)idx;
- (BDSKCategoryGroup *)objectInFieldGroupsAtIndex:(unsigned int)idx;
- (BDSKCategoryGroup *)valueInFieldGroupsWithName:(NSString *)name;

- (unsigned int)countOfExternalFileGroups;
- (BDSKURLGroup *)valueInExternalFileGroupsAtIndex:(unsigned int)idx;
- (BDSKURLGroup *)objectInExternalFileGroupsAtIndex:(unsigned int)idx;
- (BDSKURLGroup *)valueInExternalFileGroupsWithName:(NSString *)name;
- (void)insertInExternalFileGroups:(BDSKURLGroup *)group;
- (void)insertInExternalFileGroups:(BDSKURLGroup *)group atIndex:(unsigned int)idx;
- (void)insertObject:(BDSKURLGroup *)group inExternalFileGroupsAtIndex:(unsigned int)idx;
- (void)removeFromExternalFileGroupsAtIndex:(unsigned int)idx;
- (void)removeObjectFromExternalFileGroupsAtIndex:(unsigned int)idx;

- (unsigned int)countOfScriptGroups;
- (BDSKScriptGroup *)valueInScriptGroupsAtIndex:(unsigned int)idx;
- (BDSKScriptGroup *)objectInScriptGroupsAtIndex:(unsigned int)idx;
- (BDSKScriptGroup *)valueInScriptGroupsWithName:(NSString *)name;
- (void)insertInScriptGroups:(BDSKScriptGroup *)group;
- (void)insertInScriptGroups:(BDSKScriptGroup *)group atIndex:(unsigned int)idx;
- (void)insertObject:(BDSKScriptGroup *)group inScriptGroupsAtIndex:(unsigned int)idx;
- (void)removeFromScriptGroupsAtIndex:(unsigned int)idx;
- (void)removeObjectFromScriptGroupsAtIndex:(unsigned int)idx;

- (unsigned int)countOfSearchGroups;
- (BDSKSearchGroup *)valueInSearchGroupsAtIndex:(unsigned int)idx;
- (BDSKSearchGroup *)objectInSearchGroupsAtIndex:(unsigned int)idx;
- (BDSKSearchGroup *)valueInSearchGroupsWithName:(NSString *)name;
- (void)insertInSearchGroups:(BDSKSearchGroup *)group;
- (void)insertInSearchGroups:(BDSKSearchGroup *)group atIndex:(unsigned int)idx;
- (void)insertObject:(BDSKSearchGroup *)group inSearchGroupsAtIndex:(unsigned int)idx;
- (void)removeFromSearchGroupsAtIndex:(unsigned int)idx;
- (void)removeObjectFromSearchGroupsAtIndex:(unsigned int)idx;

- (unsigned int)countOfSharedGroups;
- (BDSKSharedGroup *)valueInSharedGroupsAtIndex:(unsigned int)idx;
- (BDSKSharedGroup *)objectInSharedGroupsAtIndex:(unsigned int)idx;
- (BDSKSharedGroup *)valueInSharedGroupsWithName:(NSString *)name;

- (unsigned int)countOfLibraryGroups;
- (BDSKGroup *)valueInLibraryGroupsAtIndex:(unsigned int)idx;
- (BDSKGroup *)objectInLibraryGroupsAtIndex:(unsigned int)idx;
- (BDSKGroup *)valueInLibraryGroupsWithName:(NSString *)name;

- (unsigned int)countOfLastImportGroups;
- (BDSKGroup *)valueInLastImportGroupsAtIndex:(unsigned int)idx;
- (BDSKGroup *)objectInLastImportGroupsAtIndex:(unsigned int)idx;
- (BDSKGroup *)valueInLastImportGroupsWithName:(NSString *)name;

- (unsigned int)countOfWebGroups;
- (BDSKWebGroup *)valueInWebGroupsAtIndex:(unsigned int)idx;
- (BDSKWebGroup *)objectInWebGroupsAtIndex:(unsigned int)idx;
- (BDSKWebGroup *)valueInWebGroupsWithName:(NSString *)name;


- (NSArray*) selection;
- (void) setSelection: (NSArray*) newSelection;

- (NSArray *)groupSelection;
- (void)setGroupSelection:(NSArray *)newSelection;

- (NSTextStorage*) textStorageForPublications:(NSArray *)pubs;

@end

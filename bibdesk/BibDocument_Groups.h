//
//  BibDocument_Groups.h
//  Bibdesk
//
/*
 This software is Copyright (c) 2005
 Michael O. McCracken. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Michael O. McCracken nor the names of any
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
#import "BibDocument.h"

@class BDSKSmartGroup, BDSKStaticGroup, BDSKURLGroup, BDSKScriptGroup, BDSKFilterController;

@interface BibDocument (Groups)

- (unsigned int)countOfGroups;
- (BDSKGroup *)objectInGroupsAtIndex:(unsigned int)index;

- (NSRange)rangeOfSharedGroups;
- (NSRange)rangeOfURLGroups;
- (NSRange)rangeOfScriptGroups;
- (NSRange)rangeOfSmartGroups;
- (NSRange)rangeOfStaticGroups;
- (NSRange)rangeOfCategoryGroups;
- (unsigned int)numberOfSharedGroupsAtIndexes:(NSIndexSet *)indexes;
- (unsigned int)numberOfURLGroupsAtIndexes:(NSIndexSet *)indexes;
- (unsigned int)numberOfScriptGroupsAtIndexes:(NSIndexSet *)indexes;
- (unsigned int)numberOfSmartGroupsAtIndexes:(NSIndexSet *)indexes;
- (unsigned int)numberOfStaticGroupsAtIndexes:(NSIndexSet *)indexes;
- (unsigned int)numberOfCategoryGroupsAtIndexes:(NSIndexSet *)indexes;
- (BOOL)hasSharedGroupsAtIndexes:(NSIndexSet *)indexes;
- (BOOL)hasSharedGroupsSelected;
- (BOOL)hasURLGroupsAtIndexes:(NSIndexSet *)indexes;
- (BOOL)hasURLGroupsSelected;
- (BOOL)hasScriptGroupsAtIndexes:(NSIndexSet *)indexes;
- (BOOL)hasScriptGroupsSelected;
- (BOOL)hasSmartGroupsAtIndexes:(NSIndexSet *)indexes;
- (BOOL)hasSmartGroupsSelected;
- (BOOL)hasStaticGroupsAtIndexes:(NSIndexSet *)indexes;
- (BOOL)hasStaticGroupsSelected;
- (BOOL)hasCategoryGroupsAtIndexes:(NSIndexSet *)indexes;
- (BOOL)hasCategoryGroupsSelected;
- (BOOL)hasExternalGroupsSelected;

- (void)addURLGroup:(BDSKURLGroup *)group;
- (void)removeURLGroup:(BDSKURLGroup *)group;
- (void)addScriptGroup:(BDSKScriptGroup *)group;
- (void)removeScriptGroup:(BDSKScriptGroup *)group;
- (void)addSmartGroup:(BDSKSmartGroup *)group;
- (void)removeSmartGroup:(BDSKSmartGroup *)group;
- (void)addStaticGroup:(BDSKStaticGroup *)group;
- (void)removeStaticGroup:(BDSKStaticGroup *)group;

- (void)setCurrentGroupField:(NSString *)field;
- (NSString *)currentGroupField;

- (NSMutableArray *)staticGroups;

- (NSArray *)selectedGroups;
- (void)updateGroupsPreservingSelection:(BOOL)preserve;
- (void)displaySelectedGroups;
- (void)selectGroup:(BDSKGroup *)aGroup;
- (void)selectGroups:(NSArray *)theGroups;

- (void)updateAllSmartGroups;
- (NSArray *)publicationsInCurrentGroups;
- (BOOL)addPublications:(NSArray *)pubs toGroup:(BDSKGroup *)group;
- (BOOL)removePublications:(NSArray *)pubs fromGroups:(NSArray *)groupArray;
- (BOOL)movePublications:(NSArray *)pubs fromGroup:(BDSKGroup *)group toGroupNamed:(NSString *)newGroupName;
- (NSMenu *)groupFieldsMenu;

- (IBAction)changeGroupFieldAction:(id)sender;
- (IBAction)addGroupFieldAction:(id)sender;
- (IBAction)removeGroupFieldAction:(id)sender;

- (void)handleGroupFieldChangedNotification:(NSNotification *)notification;
- (void)handleGroupAddRemoveNotification:(NSNotification *)notification;
- (void)handleStaticGroupChangedNotification:(NSNotification *)notification;
- (void)handleSharedGroupUpdatedNotification:(NSNotification *)notification;
- (void)handleSharedGroupsChangedNotification:(NSNotification *)notification;
- (void)handleGroupTableSelectionChangedNotification:(NSNotification *)notification;
- (void)handleURLGroupUpdatedNotification:(NSNotification *)notification;
- (void)handleScriptGroupUpdatedNotification:(NSNotification *)notification;

- (IBAction)sortGroupsByGroup:(id)sender;
- (IBAction)sortGroupsByCount:(id)sender;
- (IBAction)addSmartGroupAction:(id)sender;
- (IBAction)addStaticGroupAction:(id)sender;
- (IBAction)addURLGroupAction:(id)sender;
- (IBAction)dismissAddURLGroupSheet:(id)sender;
- (IBAction)chooseURLForGroupAction:(id)sender;
- (IBAction)addScriptGroupAction:(id)sender;
- (IBAction)dismissAddScriptGroupSheet:(id)sender;
- (IBAction)chooseScriptForGroupAction:(id)sender;
- (IBAction)addGroupButtonAction:(id)sender;
- (IBAction)removeSelectedGroups:(id)sender;
- (IBAction)editGroupAction:(id)sender;
- (IBAction)renameGroupAction:(id)sender;
- (IBAction)selectAllPublicationsGroup:(id)sender;
- (IBAction)changeIntersectGroupsAction:(id)sender;
- (IBAction)editNewGroupWithSelection:(id)sender;
- (void)addSmartGroupSheetDidEnd:(BDSKFilterController *)filterController returnCode:(int) returnCode contextInfo:(void *)contextInfo;
- (void)addURLGroupSheetDidEnd:(NSWindow *)sheet returnCode:(int) returnCode contextInfo:(void *)contextInfo;
- (void)addScriptGroupSheetDidEnd:(NSWindow *)sheet returnCode:(int) returnCode contextInfo:(void *)contextInfo;

- (IBAction)mergeInSharedGroup:(id)sender;
- (IBAction)mergeInSharedPublications:(id)sender;
- (NSArray *)mergeInPublications:(NSArray *)items;
- (IBAction)refreshURLGroups:(id)sender;
- (IBAction)refreshScriptGroups:(id)sender;

- (void)setSmartGroupsFromSerializedData:(NSData *)data;
- (void)setStaticGroupsFromSerializedData:(NSData *)data;
- (void)setURLGroupsFromSerializedData:(NSData *)data;
- (void)setScriptGroupsFromSerializedData:(NSData *)data;
- (NSData *)serializedSmartGroupsData;
- (NSData *)serializedStaticGroupsData;
- (NSData *)serializedURLGroupsData;
- (NSData *)serializedScriptGroupsData;

- (void)handleFilterChangedNotification:(NSNotification *)notification;
- (void)sortGroupsByKey:(NSString *)key;

- (NSIndexSet *)_indexesOfRowsToHighlightInRange:(NSRange)indexRange tableView:(BDSKGroupTableView *)tview;
- (NSIndexSet *)_tableViewSingleSelectionIndexes:(BDSKGroupTableView *)tview;

@end

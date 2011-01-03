//
//  BibDocument_Groups.h
//  Bibdesk
//
/*
 This software is Copyright (c) 2005-2011
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

@class BDSKGroup, BDSKSmartGroup, BDSKStaticGroup, BDSKExternalGroup, BDSKURLGroup, BDSKScriptGroup, BDSKWebGroup, BDSKFilterController, BDSKURLGroupSheetController, BDSKScriptGroupSheetController;

@interface BibDocument (Groups)

- (BOOL)hasLibraryGroupSelected;
- (BOOL)hasLastImportGroupSelected;
- (BOOL)hasWebGroupsSelected;
- (BOOL)hasSharedGroupsSelected;
- (BOOL)hasURLGroupsSelected;
- (BOOL)hasScriptGroupsSelected;
- (BOOL)hasSearchGroupsSelected;
- (BOOL)hasSmartGroupsSelected;
- (BOOL)hasStaticGroupsSelected;
- (BOOL)hasCategoryGroupsSelected;
- (BOOL)hasExternalGroupsSelected;

- (BOOL)hasLibraryGroupClickedOrSelected;
- (BOOL)hasLastImportGroupClickedOrSelected;
- (BOOL)hasWebGroupsClickedOrSelected;
- (BOOL)hasSharedGroupsClickedOrSelected;
- (BOOL)hasURLGroupsClickedOrSelected;
- (BOOL)hasScriptGroupsClickedOrSelected;
- (BOOL)hasSearchGroupsClickedOrSelected;
- (BOOL)hasSmartGroupsClickedOrSelected;
- (BOOL)hasStaticGroupsClickedOrSelected;
- (BOOL)hasCategoryGroupsClickedOrSelected;
- (BOOL)hasExternalGroupsClickedOrSelected;

- (void)setCurrentGroupField:(NSString *)field;
- (NSString *)currentGroupField;

- (NSArray *)selectedGroups;
- (NSArray *)clickedOrSelectedGroups;
- (void)updateCategoryGroupsPreservingSelection:(BOOL)preserve;
- (void)updateSmartGroupsCount;
- (void)updateSmartGroups;
- (void)displaySelectedGroups;
- (BOOL)selectGroup:(BDSKGroup *)aGroup;
- (BOOL)selectGroups:(NSArray *)theGroups;

- (BOOL)addPublications:(NSArray *)pubs toGroup:(BDSKGroup *)group;
- (BOOL)removePublications:(NSArray *)pubs fromGroups:(NSArray *)groupArray;
- (BOOL)movePublications:(NSArray *)pubs fromGroup:(BDSKGroup *)group toGroupNamed:(NSString *)newGroupName;

- (IBAction)changeGroupFieldAction:(id)sender;
- (IBAction)addGroupFieldAction:(id)sender;
- (IBAction)removeGroupFieldAction:(id)sender;

- (void)showWebGroupView;
- (void)hideWebGroupView;

- (void)showSearchGroupView;
- (void)hideSearchGroupView;

- (void)handleGroupNameChangedNotification:(NSNotification *)notification;
- (void)handleStaticGroupChangedNotification:(NSNotification *)notification;
- (void)handleSharedGroupsChangedNotification:(NSNotification *)notification;
- (void)handleGroupTableSelectionChangedNotification:(NSNotification *)notification;
- (void)handleExternalGroupUpdatedNotification:(NSNotification *)notification;
- (void)handleWillRemoveGroupsNotification:(NSNotification *)notification;
- (void)handleDidAddRemoveGroupNotification:(NSNotification *)notification;

- (NSProgressIndicator *)spinnerForGroup:(BDSKGroup *)group;
- (void)removeSpinnerForGroup:(BDSKGroup *)group;
- (void)removeSpinnersFromSuperview;

- (IBAction)sortGroupsByGroup:(id)sender;
- (IBAction)sortGroupsByCount:(id)sender;

- (IBAction)addSmartGroupAction:(id)sender;
- (IBAction)addStaticGroupAction:(id)sender;
- (IBAction)addURLGroupAction:(id)sender;
- (IBAction)addScriptGroupAction:(id)sender;
- (IBAction)addWebGroupAction:(id)sender;
- (IBAction)addSearchGroupAction:(id)sender;
- (IBAction)newSearchGroupFromBookmark:(id)sender;
- (IBAction)addSearchBookmark:(id)sender;
- (void)removeGroups:(NSArray *)theGroups;
- (IBAction)removeSelectedGroups:(id)sender;
- (void)editGroup:(BDSKGroup *)group;
- (IBAction)editGroupAction:(id)sender;
- (IBAction)renameGroupAction:(id)sender;
- (IBAction)copyGroupURLAction:(id)sender;
- (IBAction)selectLibraryGroup:(id)sender;
- (IBAction)changeIntersectGroupsAction:(id)sender;
- (IBAction)editNewStaticGroupWithSelection:(id)sender;
- (IBAction)editNewCategoryGroupWithSelection:(id)sender;
- (void)smartGroupSheetDidEnd:(BDSKFilterController *)filterController returnCode:(NSInteger) returnCode contextInfo:(void *)contextInfo;
- (void)URLGroupSheetDidEnd:(BDSKURLGroupSheetController *)sheetController returnCode:(NSInteger) returnCode contextInfo:(void *)contextInfo;
- (void)scriptGroupSheetDidEnd:(BDSKScriptGroupSheetController *)sheetController returnCode:(NSInteger) returnCode contextInfo:(void *)contextInfo;

- (IBAction)mergeInExternalGroup:(id)sender;
- (IBAction)mergeInExternalPublications:(id)sender;
- (NSArray *)mergeInPublications:(NSArray *)items;
- (IBAction)refreshURLGroups:(id)sender;
- (IBAction)refreshScriptGroups:(id)sender;
- (IBAction)refreshSearchGroups:(id)sender;
- (IBAction)refreshAllExternalGroups:(id)sender;
- (IBAction)refreshSelectedGroups:(id)sender;
- (IBAction)openBookmark:(id)sender;
- (IBAction)addBookmark:(id)sender;

- (void)handleFilterChangedNotification:(NSNotification *)notification;
- (void)sortGroupsByKey:(NSString *)key;

- (void)setImported:(BOOL)flag forPublications:(NSArray *)pubs inGroup:(BDSKExternalGroup *)aGroup;

- (BOOL)openURL:(NSURL *)url;

@end

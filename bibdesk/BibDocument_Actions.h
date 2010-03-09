//
//  BibDocument_Actions.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/14/06.
/*
 This software is Copyright (c) 2006-2010
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
#import "BibDocument.h"


@interface BibDocument (Actions)

#pragma mark Publication Actions

- (void)addNewPubAndEdit:(BibItem *)item;
- (void)createNewPub;
- (void)createNewPubUsingCrossrefForItem:(BibItem *)item;
- (IBAction)createNewPubUsingCrossrefAction:(id)sender;

/*!
@method newPub:
    @abstract creates a new publication (BibItem)
 @discussion This is the action method for the 'new' button. It calls [self createNewBlankPubAndEdit:YES] 
    @param sender The sending object (not used, we assume it's the 'new' button.)
*/
- (IBAction)newPub:(id)sender; // new pub button pressed.

- (void)deletePublications:(NSArray *)pubs;

- (IBAction)deleteSelectedPubs:(id)sender;

- (void)removePublicationsFromSelectedGroups:(NSArray *)pubs;

- (IBAction)removeSelectedPubs:(id)sender;

/*!
    @method copyAsAction:
    @abstract copy items in a particular format, depending on the tag of the sender
    @discussion puts the format for the currently selected publications onto the general pasteboard.
    @param sender The sender.
*/
- (IBAction)copyAsAction:(id)sender;

- (BDSKEditor *)editorForPublication:(BibItem *)pub create:(BOOL)createNew;

/*!
    @method editPubCmd
    @abstract an action to edit a publication has happened. 
    @discussion -
    @param sender Not Used!
*/
- (IBAction)editPubCmd:(id)sender;

- (void)editPublications:(NSArray *)pubs;

/*!
    @method editPub
    @abstract Opens the edit window
    @discussion Creates a bibeditor if one doesn't exist, and tells it to show itself. 
    @param pub The BibItem that should be edited.
*/
- (BDSKEditor *)editPub:(BibItem *)pub;

- (BDSKEditor *)editPubBeforePub:(BibItem *)pub;
- (BDSKEditor *)editPubAfterPub:(BibItem *)pub;

/*!
    @method editAction:
    @abstract General edit action. Edits the selected publications or the selected smart group, depending on the selected tableView. 
    @discussion - 
    @param sender The sender. Not used.
*/
- (void)editAction:(id)sender;

- (void)editRepresentedPub:(id)sender;

/*!
    @method editPubOrOpenURLAction:
    @abstract 
    @discussion This is the tableview's doubleaction and the action of the edit pub button. It calls editPub with the tableview's selected publication.
    @param sender The sender. Not used.
*/
- (void)editPubOrOpenURLAction:(id)sender;

/*!
    @method showPerson:
    @abstract Opens the personcontroller window
    @discussion Creates a personcontroller if one doesn't exist, and tells it to show itself. 
    @param person The BibAuthor that should be displayed.
*/
- (void)showPerson:(BibAuthor *)person;

- (IBAction)emailPubCmd:(id)sender;
- (IBAction)sendToLyX:(id)sender;
- (IBAction)postItemToWeblog:(id)sender;

#pragma mark URL actions

#pragma mark | URL Field actions

/*!
    @method openLocalURL:
    @abstract Opens the linked file of the selected publication with the default application
    @discussion - 
    @param sender The sender. Not used.
*/
- (IBAction)openLocalURL:(id)sender;

- (void)openLocalURLForField:(NSString *)field;

/*!
    @method revealLocalURL:
    @abstract Reveals the linked file of the selected publication in the Finder
    @discussion 
    @param sender The sender. Not used.
*/
- (IBAction)revealLocalURL:(id)sender;

- (void)revealLocalURLForField:(NSString *)field;

/*!
    @method openRemoteURL:
    @abstract Opens the remote URL of the selected publication in the default browser
    @discussion - 
    @param sender The sender. Not used.
*/
- (IBAction)openRemoteURL:(id)sender;

- (void)openRemoteURLForField:(NSString *)field;

/*!
    @method showNotesForLocalURL:
    @abstract Shows Skim notes of the selected publication in separate windows
    @discussion - 
    @param sender The sender. Not used.
*/
- (IBAction)showNotesForLocalURL:(id)sender;

- (void)showNotesForLocalURLForField:(NSString *)field;

- (IBAction)copyNotesForLocalURL:(id)sender;

- (void)copyNotesForLocalURLForField:(NSString *)field;

- (IBAction)chooseLinkedFile:(id)sender;
- (IBAction)chooseLinkedURL:(id)sender;

#pragma mark | Linked File and URL actions

- (void)openLinkedFileAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)openLinkedURLAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

- (IBAction)openLinkedFile:(id)sender;

- (IBAction)revealLinkedFile:(id)sender;

- (IBAction)openLinkedURL:(id)sender;

- (IBAction)showNotesForLinkedFile:(id)sender;

- (IBAction)copyNotesForLinkedFile:(id)sender;

- (IBAction)previewAction:(id)sender;

- (IBAction)migrateFiles:(id)sender;

#pragma mark View Actions

/*!
    @method selectAllPublications:
    @abstract Selects all publications
    @discussion - 
    @param sender The sender. Not used.
*/
- (IBAction)selectAllPublications:(id)sender;

/*!
    @method deselectAllPublications:
    @abstract Deselects all publications
    @discussion - 
    @param sender The sender. Not used.
*/
- (IBAction)deselectAllPublications:(id)sender;

- (IBAction)toggleGroups:(id)sender;
- (IBAction)toggleSidebar:(id)sender;

- (IBAction)toggleStatusBar:(id)sender;

- (IBAction)changeMainTableFont:(id)sender;
- (IBAction)changeGroupTableFont:(id)sender;

- (IBAction)changePreviewDisplay:(id)sender;
- (IBAction)changeSidePreviewDisplay:(id)sender;

/*!
    @method     pageDownInPreview:
    @abstract   Page down in the lower pane of the splitview using spacebar.
    @discussion Currently sent by the tableview, which gets keyDown: events.
    @param      sender (description)
*/
- (void)pageDownInPreview:(id)sender;

/*!
    @method     pageUpInPreview:
    @abstract   Page up in the lower pane of the splitview using spacebar.
    @discussion Currently sent by the tableview, which gets keyDown: events.
    @param      sender (description)
*/
- (void)pageUpInPreview:(id)sender;

/*!
    @method     consolidateLinkedFiles:
    @abstract   invokes autofile. see BDSKFiler.h,m for info
    
*/

#pragma mark Showing related info windows

- (IBAction)toggleShowingCustomCiteDrawer:(id)sender;

- (IBAction)showDocumentInfoWindow:(id)sender;

- (IBAction)showMacrosWindow:(id)sender;

#pragma mark Sharing Actions

- (IBAction)refreshSharing:(id)sender;
- (IBAction)refreshSharedBrowsing:(id)sender;

#pragma mark Text import sheet support

- (IBAction)importFromPasteboardAction:(id)sender;
- (IBAction)importFromFileAction:(id)sender;
- (IBAction)importFromWebAction:(id)sender;

#pragma mark AutoFile stuff

- (IBAction)consolidateLinkedFiles:(id)sender;

#pragma mark Cite Keys and Crossref support

- (void)generateCiteKeysForPublications:(NSArray *)pubs;
- (IBAction)generateCiteKey:(id)sender;

- (IBAction)sortForCrossrefs:(id)sender;

- (void)performSortForCrossrefs;

- (void)selectCrossrefParentForItem:(BibItem *)item;
- (IBAction)selectCrossrefParentAction:(id)sender;

- (IBAction)selectCrossrefs:(id)sender;

- (IBAction)duplicateTitleToBooktitle:(id)sender;

#pragma mark Duplicate and Incomplete searching

- (IBAction)selectPossibleDuplicates:(id)sender;
- (IBAction)selectDuplicates:(id)sender;
- (IBAction)selectIncompletePublications:(id)sender;
- (IBAction)selectPublicationsFromAuxFile:(id)sender;

@end

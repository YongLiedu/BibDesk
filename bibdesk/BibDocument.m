//  BibDocument.m

//  Created by Michael McCracken on Mon Dec 17 2001.
/*
 This software is Copyright (c) 2001-2012
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

#import "BibDocument.h"
#import "BDSKOwnerProtocol.h"
#import "BibItem.h"
#import "BibAuthor.h"
#import "BibDocument_DataSource.h"
#import "BibDocument_UI.h"
#import "BibDocument_Actions.h"
#import "BibDocument_Toolbar.h"
#import "BDSKAppController.h"
#import "BDSKStringConstants.h"
#import "BDSKGroup.h"
#import "BDSKParentGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKSearchGroup.h"
#import "BDSKPublicationsArray.h"
#import "BDSKGroupsArray.h"

#import "BDSKUndoManager.h"
#import "NSPrintOperation_BDSKExtensions.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKStringEncodingManager.h"
#import "BDSKGroupCell.h"
#import "BDSKScriptHookManager.h"
#import "BDSKFilterController.h"
#import "BibDocument_Groups.h"
#import "BibDocument_Search.h"
#import "BDSKTableSortDescriptor.h"
#import "BDSKTableSortDescriptor.h"
#import "BDSKFieldSheetController.h"
#import "BDSKPreviewer.h"
#import "BDSKEditor.h"

#import "BDSKMainTableView.h"
#import "BDSKConverter.h"
#import "BDSKBibTeXParser.h"
#import "BDSKStringParser.h"

#import <ApplicationServices/ApplicationServices.h>
#import "BDSKImagePopUpButton.h"
#import "BDSKRatingButton.h"
#import "BDSKCollapsibleView.h"
#import "BDSKZoomablePDFView.h"
#import "BDSKZoomableTextView.h"
#import "BDSKGradientView.h"

#import "BDSKMacroResolver.h"
#import "BDSKErrorObjectController.h"
#import "BDSKGroupOutlineView.h"
#import "BDSKFileContentSearchController.h"
#import "NSString_BDSKExtensions.h"
#import "BDSKStatusBar.h"
#import "NSArray_BDSKExtensions.h"
#import "NSTableView_BDSKExtensions.h"
#import "NSDictionary_BDSKExtensions.h"
#import "NSSet_BDSKExtensions.h"
#import "BDSKSharingServer.h"
#import "BDSKSharingBrowser.h"
#import "BDSKTemplate.h"
#import "BDSKGroupOutlineView.h"
#import "BDSKTemplateParser.h"
#import "BDSKTemplateObjectProxy.h"
#import "NSMenu_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "NSData_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import "BDSKColoredView.h"
#import "BDSKCustomCiteDrawerController.h"
#import "BDSKDocumentController.h"
#import "BDSKFiler.h"
#import "BibItem_PubMedLookup.h"
#import "BDSKItemSearchIndexes.h"
#import "BDSKNotesSearchIndex.h"
#import "PDFDocument_BDSKExtensions.h"
#import <FileView/FileView.h>
#import "BDSKLinkedFile.h"
#import "NSDate_BDSKExtensions.h"
#import "BDSKFileMigrationController.h"
#import "BDSKDocumentSearch.h"
#import "NSImage_BDSKExtensions.h"
#import <SkimNotesBase/SkimNotesBase.h>
#import "NSWorkspace_BDSKExtensions.h"
#import "NSView_BDSKExtensions.h"
#import "NSColor_BDSKExtensions.h"
#import "BDSKTask.h"
#import "NSInvocation_BDSKExtensions.h"
#import "NSEvent_BDSKExtensions.h"
#import "BDSKMetadataCacheOperation.h"
#import "NSSplitView_BDSKExtensions.h"
#import "NSAttributedString_BDSKExtensions.h"

// these are the same as in Info.plist
NSString *BDSKBibTeXDocumentType = @"BibTeX Database";
NSString *BDSKRISDocumentType = @"RIS/Medline File";
NSString *BDSKMinimalBibTeXDocumentType = @"Minimal BibTeX Database";
NSString *BDSKLTBDocumentType = @"Amsrefs LTB";
NSString *BDSKEndNoteDocumentType = @"EndNote XML";
NSString *BDSKMODSDocumentType = @"MODS XML";
NSString *BDSKAtomDocumentType = @"Atom XML";
NSString *BDSKArchiveDocumentType = @"BibTeX and Papers Archive";

NSString *BDSKReferenceMinerStringPboardType = @"CorePasteboardFlavorType 0x57454253";
NSString *BDSKBibItemPboardType = @"edu.ucsd.mmccrack.bibdesk.BibItemPasteboardType";
NSString *BDSKWeblocFilePboardType = @"CorePasteboardFlavorType 0x75726C20";

NSString *BDSKDocumentPublicationsKey = @"publications";

// private keys used for storing window information in xattrs
#define BDSKMainWindowExtendedAttributeKey @"net.sourceforge.bibdesk.BDSKDocumentWindowAttributes"
#define BDSKGroupSplitViewFractionKey @"BDSKGroupSplitViewFractionKey"
#define BDSKMainTableSplitViewFractionKey @"BDSKMainTableSplitViewFractionKey"
#define BDSKWebViewFractionKey @"BDSKWebViewFractionKey"
#define BDSKDocumentWindowFrameKey @"BDSKDocumentWindowFrameKey"
#define BDSKSelectedPublicationsKey @"BDSKSelectedPublicationsKey"
#define BDSKDocumentStringEncodingKey @"BDSKDocumentStringEncodingKey"
#define BDSKDocumentScrollPercentageKey @"BDSKDocumentScrollPercentageKey"
#define BDSKSelectedGroupsKey @"BDSKSelectedGroupsKey"
#define BDSKDocumentGroupsToExpandKey @"BDSKDocumentGroupsToExpandKey"

#define BDSKDisableMigrationWarningKey @"BDSKDisableMigrationWarning"
#define BDSKRemoveExtendedAttributesFromDocumentsKey @"BDSKRemoveExtendedAttributesFromDocuments"
#define BDSKDisableDocumentExtendedAttributesKey @"BDSKDisableDocumentExtendedAttributes"
#define BDSKDisableExportAttributesKey @"BDSKDisableExportAttributes"

#pragma mark -

@interface NSDocument (BDSKPrivateExtensions)
// declare a private NSDocument method so we can override it
- (void)changeSaveType:(id)sender;
@end

@implementation BibDocument

static NSOperationQueue *metadataCacheQueue = nil;

+ (void)handleApplicationWillTerminate:(NSNotification *)note {
    [metadataCacheQueue cancelAllOperations];
}

+ (void)initialize {
    BDSKINITIALIZE;
    
    metadataCacheQueue = [[NSOperationQueue alloc] init];
    [metadataCacheQueue setMaxConcurrentOperationCount:1];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillTerminate:) name:NSApplicationWillTerminateNotification object:NSApp];
    
    [NSImage makePreviewDisplayImages];
}

+ (NSSet *)keyPathsForValuesAffectingDisplayName {
    return [NSSet setWithObjects:@"fileURL", nil];
}

- (id)init{
    if(self = [super init]){
        
        publications = [[BDSKPublicationsArray alloc] init];
        shownPublications = [[NSMutableArray alloc] init];
        groupedPublications = [[NSMutableArray alloc] init];
        groups = [(BDSKGroupsArray *)[BDSKGroupsArray alloc] initWithDocument:self];
        
        frontMatter = nil;
        documentInfo = nil;
        macroResolver = [[BDSKMacroResolver alloc] initWithOwner:self];
        
        BDSKUndoManager *newUndoManager = [[[BDSKUndoManager alloc] init] autorelease];
        [newUndoManager setDelegate:self];
        [self setUndoManager:newUndoManager];
		
        pboardHelper = [[BDSKItemPasteboardHelper alloc] init];
        [pboardHelper setDelegate:self];
        
        docFlags.isDocumentClosed = NO;
        
        // need to set this for new documents
        [self setDocumentStringEncoding:[[NSDocumentController sharedDocumentController] lastSelectedEncoding]]; 
        
        // these are set in windowControllerDidLoadNib: from the xattr defaults if available
        bottomPreviewDisplay = BDSKPreviewDisplayText;
        bottomPreviewDisplayTemplate = nil;
        sidePreviewDisplay = BDSKPreviewDisplayFiles;
        sidePreviewDisplayTemplate = nil;
        tableColumnWidths = nil;
        sortKey = nil;
        previousSortKey = nil;
        tmpSortKey = nil;
        sortGroupsKey = nil;
        currentGroupField = nil;
        docFlags.sortDescending = NO;
        docFlags.previousSortDescending = NO;
        docFlags.tmpSortDescending = NO;
        docFlags.sortGroupsDescending = NO;
        docFlags.didImport = NO;
        docFlags.itemChangeMask = 0;
        docFlags.displayMigrationAlert = NO;
        docFlags.inOptionKeyState = NO;
        
        // these are created lazily when needed
        fileSearchController = nil;
        drawerController = nil;
        previewer = nil;
        toolbarItems = nil;
        docState.lastPreviewHeight = 0.0;
        docState.lastGroupViewWidth = 0.0;
        docState.lastFileViewWidth = 0.0;
        docState.lastWebViewFraction = 0.0;
        docFlags.isAnimating = NO;
        docFlags.ignoreSelectionChange = NO;
        docFlags.ignoreGroupSelectionChange = NO;
        
        // these are temporary state variables
        docFlags.dragFromExternalGroups = NO;
        docState.currentSaveOperationType = 0;
        
        [self registerForNotifications];
        
        searchIndexes = [[BDSKItemSearchIndexes alloc] init];   
        notesSearchIndex = [[BDSKNotesSearchIndex alloc] init];   
        documentSearch = [[BDSKDocumentSearch alloc] initWithDelegate:(id)self];
        rowToSelectAfterDelete = -1;
    }
    return self;
}

// implement a dummy implementation for NSCoding, as the Action popup toolbar item can call this because we're the delegate of a menu item
// I consider this an AppKit bug
- (id)initWithCoder:(NSCoder *)coder {
    [self release];
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)encoder {}

- (void)invalidateSearchFieldCellTimer{
    // AppKit bug workarounds:  NSSearchFieldCell's timer creates a retain cycle after typing in it, so we manually invalidate it when the document is deallocated to avoid leaking the cell and timer.  Further, if the insertion point is in the searchfield cell when the window closes, the field editor (and associated text system) and undo manager also leak, so we send -[documentWindow endEditingFor:nil] in windowWillClose:.
    id timer = [[searchField cell] valueForKey:@"_partialStringTimer"];
    if (timer && [timer respondsToSelector:@selector(invalidate)]) {
        [timer invalidate];
        [[searchField cell] setValue:nil forKey:@"_partialStringTimer"];
    }
    [searchField setCell:nil];
}

- (void)dealloc{
    if ([self undoManager])
        [[self undoManager] removeAllActions];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    // workaround for crash: to reproduce, create empty doc, hit cmd-n for new editor window, then cmd-q to quit, choose "don't save"; this results in an -undoManager message to the dealloced document
    [publications setValue:nil forKey:@"owner"];
    [groups setValue:nil forKey:@"document"];
    [(BDSKUndoManager *)[self undoManager] setDelegate:nil];
    [pboardHelper setDelegate:nil];
    [fileSearchController setDelegate:nil];
    BDSKDESTROY(fileSearchController);
    BDSKDESTROY(pboardHelper);
    BDSKDESTROY(macroResolver);
    BDSKDESTROY(publications);
    BDSKDESTROY(shownPublications);
    BDSKDESTROY(groupedPublications);
    BDSKDESTROY(groups);
    BDSKDESTROY(shownFiles);
    BDSKDESTROY(frontMatter);
    BDSKDESTROY(documentInfo);
    BDSKDESTROY(drawerController);
    BDSKDESTROY(toolbarItems);
	BDSKDESTROY(statusBar);
    [[tableView enclosingScrollView] release];
    BDSKDESTROY(previewer);
    BDSKDESTROY(bottomPreviewDisplayTemplate);
    BDSKDESTROY(sidePreviewDisplayTemplate);
    BDSKDESTROY(tableColumnWidths);
    BDSKDESTROY(sortKey);
    BDSKDESTROY(previousSortKey);
    BDSKDESTROY(tmpSortKey);
    BDSKDESTROY(sortGroupsKey);
    BDSKDESTROY(currentGroupField);
    BDSKDESTROY(searchGroupViewController);
    BDSKDESTROY(webGroupViewController);
    BDSKDESTROY(searchIndexes);
    BDSKDESTROY(notesSearchIndex);
    BDSKDESTROY(searchButtonEdgeView);
    BDSKDESTROY(fileContentItem);
    BDSKDESTROY(skimNotesItem);
    BDSKDESTROY(migrationController);
    BDSKDESTROY(documentSearch);
    BDSKDESTROY(mainWindowSetupDictionary);
    BDSKDESTROY(groupSpinners);
    [super dealloc];
}

- (NSString *)windowNibName{
        return @"BibDocument";
}

- (void)migrationAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)unused {
    
    if ([[alert suppressionButton] state] == NSOnState)
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:BDSKDisableMigrationWarningKey];
    
    if (NSAlertDefaultReturn == returnCode)
        [self migrateFiles:self];
}

- (void)showWindows{
    [super showWindows];
    
    // Get the search string keyword if available (Spotlight passes this)
    NSAppleEventDescriptor *event = [[NSAppleEventManager sharedAppleEventManager] currentAppleEvent];
    NSString *searchString = [[event descriptorForKeyword:keyAESearchText] stringValue];
    
    if([event eventID] == kAEOpenDocuments && [NSString isEmptyString:searchString] == NO){
        // We want to handle open events for our Spotlight cache files differently; rather than setting the search field, we can jump to them immediately since they have richer context.  This code gets the path of the document being opened in order to check the file extension.
        NSString *hfsPath = [[[event descriptorForKeyword:keyAEResult] coerceToDescriptorType:typeFileURL] stringValue];
        
        // hfsPath will be nil for under some conditions, which seems strange; possibly because I wasn't checking eventID == 'odoc'?
        if(hfsPath == nil) NSLog(@"No path available from event %@ (descriptor %@)", event, [event descriptorForKeyword:keyAEResult]);
        NSURL *fileURL = (hfsPath == nil ? nil : [(id)CFURLCreateWithFileSystemPath(CFAllocatorGetDefault(), (CFStringRef)hfsPath, kCFURLHFSPathStyle, FALSE) autorelease]);
        
        BDSKPOSTCONDITION(fileURL != nil);
        if(fileURL == nil || [[[NSWorkspace sharedWorkspace] typeOfFile:[[[fileURL path] stringByStandardizingPath] stringByResolvingSymlinksInPath] error:NULL] isEqualToUTI:@"net.sourceforge.bibdesk.bdskcache"] == NO){
            if ([searchString length] > 2 && [searchString characterAtIndex:0] == '"' && [searchString characterAtIndex:[searchString length] - 1] == '"') {
                //strip quotes
                searchString = [searchString substringWithRange:NSMakeRange(1, [searchString length] - 2)];
            } else {
                // strip extra search criteria
                NSRange range = [searchString rangeOfString:@":"];
                if (range.location != NSNotFound) {
                    range = [searchString rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet] options:NSBackwardsSearch range:NSMakeRange(0, range.location)];
                    if (range.location != NSNotFound && range.location > 0)
                        searchString = [searchString substringWithRange:NSMakeRange(0, range.location)];
                }
            }
            [self selectLibraryGroup:nil];
            [self setSearchString:searchString];
        }
    }
    
    if (docFlags.displayMigrationAlert) {
        docFlags.displayMigrationAlert = NO;
        // If a single file was migrated, this alert will be shown even if all other BibItems already use BDSKLinkedFile.  However, I think that's an edge case, since the user had to manually add that pub in a text editor or by setting the local-url field.  Items imported or added in BD will already use BDSKLinkedFile, so this notification won't be posted.
        NSString *verify = NSLocalizedString(@"Verify", @"button title for migration alert");
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Local File and URL fields have been automatically converted", @"warning in document")
                                          defaultButton:verify 
                                        alternateButton:NSLocalizedString(@"Later", @"") 
                                            otherButton:nil
                              informativeTextWithFormat:NSLocalizedString(@"These fields are being deprecated.  BibDesk now uses a more flexible storage format in place of these fields.  Choose \"%@\" to manually verify the conversion and optionally remove the old fields.  Conversion can be done at any time from the \"%@\" menu.  See the Defaults preferences for more options.", @"alert text"), verify, NSLocalizedString(@"Database", @"Database main menu title")];
        
        // @@ Should we show a check button? If the user saves the doc as-is, it'll have local-url and bdsk-file fields in it, and there will be no warning the next time it's opened.  Someone who uses a script hook to convert bdsk-file back to local-url won't want to see it, though.
        [alert setShowsSuppressionButton:YES];
        [alert setShowsHelp:YES];
        [alert setHelpAnchor:@"FileMigration"];
        
        if ([documentWindow attachedSheet])
            [self migrationAlertDidEnd:alert returnCode:[alert runModal] contextInfo:NULL];
        else
            [alert beginSheetModalForWindow:documentWindow modalDelegate:self didEndSelector:@selector(migrationAlertDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    }
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [groupOutlineView expandItem:[groupOutlineView itemAtRow:0]];
    [self selectLibraryGroup:nil];
    
    [super windowControllerDidLoadNib:aController];
    
    // this is the controller for the main window
    [aController setShouldCloseDocument:YES];
    
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    
    // hidden default to remove xattrs; this presently occurs before we use them, but it may need to be earlier at some point
    if ([sud boolForKey:BDSKRemoveExtendedAttributesFromDocumentsKey] && [self fileURL])
        [[SKNExtendedAttributeManager sharedNoSplitManager] removeAllExtendedAttributesAtPath:[[self fileURL] path] traverseLink:YES error:NULL];
    
    // get document-specific attributes (returns empty dictionary if there are none, so defaultValue works correctly)
    NSDictionary *xattrDefaults = [self mainWindowSetupDictionaryFromExtendedAttributes];
    
    [self setupToolbar];
    
    [documentWindow setAutorecalculatesContentBorderThickness:NO forEdge:NSMinYEdge];
    [documentWindow setContentBorderThickness:NSHeight([statusBar frame]) forEdge:NSMinYEdge];
    
    // First remove the statusbar if we should, as it affects proper resizing of the window and splitViews
	[statusBar retain]; // we need to retain, as we might remove it from the window
    [statusBar setAlignment:NSCenterTextAlignment];
	if ([sud boolForKey:BDSKShowStatusBarKey] == NO)
		[self toggleStatusBar:nil];
    
    [groupButtonView setMinSize:[groupButtonView frame].size];
    [groupButtonView setCollapseEdges:BDSKMaxXEdgeMask | BDSKMaxYEdgeMask];
    
    bottomPreviewDisplay = [xattrDefaults integerForKeyOrDefaultValue:BDSKBottomPreviewDisplayKey];
    bottomPreviewDisplayTemplate = [[xattrDefaults objectForKeyOrDefaultValue:BDSKBottomPreviewDisplayTemplateKey] retain];
    sidePreviewDisplay = [xattrDefaults integerForKeyOrDefaultValue:BDSKSidePreviewDisplayKey];
    sidePreviewDisplayTemplate = [[xattrDefaults objectForKeyOrDefaultValue:BDSKSidePreviewDisplayTemplateKey] retain];
        
    bottomTemplatePreviewMenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] init] autorelease];
    [bottomTemplatePreviewMenu setDelegate:self];
    [bottomPreviewButton setMenu:bottomTemplatePreviewMenu forSegment:0];
    [bottomPreviewButton setEnabled:[sud boolForKey:BDSKUsesTeXKey] forSegment:BDSKPreviewDisplayTeX];
    [bottomPreviewButton selectSegmentWithTag:bottomPreviewDisplay];
    
    sideTemplatePreviewMenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] init] autorelease];
    [sideTemplatePreviewMenu setDelegate:self];
    [sidePreviewButton setMenu:sideTemplatePreviewMenu forSegment:0];
    [sidePreviewButton selectSegmentWithTag:sidePreviewDisplay];
    
    // this gives NSZeroRect for incompatible or nil values
    NSRect frameRect = NSRectFromString([xattrDefaults objectForKey:BDSKDocumentWindowFrameKey]);
    
    [aController setWindowFrameAutosaveNameOrCascade:@"Main Window Frame Autosave" setFrame:frameRect];
            
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6)
        [documentWindow setCollectionBehavior:[documentWindow collectionBehavior] | (1 << 7)]; // NSWindowCollectionBehaviorFullScreenPrimary = 1 << 7
    
    [documentWindow makeFirstResponder:tableView];	
    
    // set autosave names first
	[splitView setAutosaveName:@"Main Window"];
    [groupSplitView setAutosaveName:@"Group Table"];
    if ([aController windowFrameAutosaveName] == nil) {
        // Only autosave the frames when the window's autosavename is set to avoid inconsistencies
        [splitView setAutosaveName:nil];
        [groupSplitView setAutosaveName:nil];
    }
    
    // set previous splitview frames
    CGFloat fract = [xattrDefaults doubleForKey:BDSKGroupSplitViewFractionKey defaultValue:-1.0];
    if (fract >= 0)
        [groupSplitView setFraction:fract];
    fract = [xattrDefaults doubleForKey:BDSKMainTableSplitViewFractionKey defaultValue:-1.0];
    if (fract >= 0)
        [splitView setFraction:fract];
    
    [self splitViewDidResizeSubviews:nil];
    
    docState.lastWebViewFraction = [xattrDefaults doubleForKey:BDSKWebViewFractionKey defaultValue:0.0];
    
    [mainBox setBackgroundColor:[NSColor controlBackgroundColor]];
    
    // this might be replaced by the file content tableView
    [[tableView enclosingScrollView] retain];
    frameRect = [mainView bounds];
    frameRect.size.height += 1.0;
    [[tableView enclosingScrollView] setFrame:frameRect];
    
    // TableView setup
    [tableView removeAllTableColumns];
    
    [tableView setFontNamePreferenceKey:BDSKMainTableViewFontNameKey];
    [tableView setFontSizePreferenceKey:BDSKMainTableViewFontSizeKey];
    [groupOutlineView setFontNamePreferenceKey:BDSKGroupTableViewFontNameKey];
    [groupOutlineView setFontSizePreferenceKey:BDSKGroupTableViewFontSizeKey];
    
    tableColumnWidths = [[xattrDefaults objectForKey:BDSKColumnWidthsKey] retain];
    [tableView setupTableColumnsWithIdentifiers:[xattrDefaults objectForKeyOrDefaultValue:BDSKShownColsNamesKey]];
    sortKey = [[xattrDefaults objectForKeyOrDefaultValue:BDSKDefaultSortedTableColumnKey] retain];
    docFlags.sortDescending = [xattrDefaults boolForKeyOrDefaultValue:BDSKDefaultSortedTableColumnIsDescendingKey];
    previousSortKey = [[xattrDefaults objectForKeyOrDefaultValue:BDSKDefaultSubsortedTableColumnKey] retain];
    docFlags.previousSortDescending = [xattrDefaults boolForKeyOrDefaultValue:BDSKDefaultSubsortedTableColumnIsDescendingKey];
    if (previousSortKey == nil) {
        previousSortKey = [sortKey retain];
        docFlags.previousSortDescending = docFlags.sortDescending;
    }
    [tableView setHighlightedTableColumn:[tableView tableColumnWithIdentifier:sortKey]];
    
    [sortGroupsKey autorelease];
    sortGroupsKey = [[xattrDefaults objectForKeyOrDefaultValue:BDSKSortGroupsKey] retain];
    docFlags.sortGroupsDescending = [xattrDefaults boolForKeyOrDefaultValue:BDSKSortGroupsDescendingKey];
    // don't use setter, because we don't want to change the prefs here, and the value should be nil at this point
    currentGroupField = [[xattrDefaults objectForKeyOrDefaultValue:BDSKCurrentGroupFieldKey] copy];
    [[groups categoryParent] setName:[NSString isEmptyString:currentGroupField] ? NSLocalizedString(@"FIELD", @"source list group row title") : [currentGroupField uppercaseString]];
    
    [tableView setDoubleAction:@selector(editPubOrOpenURLAction:)];
    NSArray *dragTypes = [NSArray arrayWithObjects:BDSKBibItemPboardType, BDSKWeblocFilePboardType, BDSKReferenceMinerStringPboardType, NSStringPboardType, NSFilenamesPboardType, NSURLPboardType, NSColorPboardType, nil];
    [tableView registerForDraggedTypes:dragTypes];
    [groupOutlineView registerForDraggedTypes:dragTypes];
    
    [[sideFileView enclosingScrollView] setBackgroundColor:[sideFileView backgroundColor]];
    [bottomFileView setBackgroundColor:[[NSColor controlAlternatingRowBackgroundColors] lastObject]];
    [[bottomFileView enclosingScrollView] setBackgroundColor:[bottomFileView backgroundColor]];
    
    CGFloat iconScale = [xattrDefaults doubleForKeyOrDefaultValue:BDSKSideFileViewIconScaleKey];
    FVDisplayMode displayMode = [xattrDefaults doubleForKeyOrDefaultValue:BDSKSideFileViewDisplayModeKey];
    [sideFileView setDisplayMode:displayMode];
    if (displayMode == FVDisplayModeGrid) {
        if (iconScale < 0.00001)
            [sideFileView setDisplayMode:FVDisplayModeColumn];
        else
            [sideFileView setIconScale:iconScale];
    }

    iconScale = [xattrDefaults doubleForKeyOrDefaultValue:BDSKBottomFileViewIconScaleKey];
    displayMode = [xattrDefaults integerForKeyOrDefaultValue:BDSKBottomFileViewDisplayModeKey];
    [bottomFileView setDisplayMode:displayMode];
    if (displayMode == FVDisplayModeGrid) {
        if (iconScale < 0.00001)
            [bottomFileView setDisplayMode:FVDisplayModeRow];
        else
            [bottomFileView setIconScale:iconScale];
    }
    
    [(BDSKZoomableTextView *)sidePreviewTextView setScaleFactor:[xattrDefaults doubleForKey:BDSKSidePreviewScaleFactorKey defaultValue:1.0]];
    [(BDSKZoomableTextView *)bottomPreviewTextView setScaleFactor:[xattrDefaults doubleForKey:BDSKBottomPreviewScaleFactorKey defaultValue:1.0]];
    
	// ImagePopUpButtons setup
	[[actionMenuButton cell] setAltersStateOfSelectedItem:NO];
	[actionMenuButton setMenu:actionMenu];
	
	[[groupActionMenuButton cell] setAltersStateOfSelectedItem:NO];
	[groupActionMenuButton setMenu:groupMenu];
    
    // array of BDSKSharedGroup objects and zeroconf support, doesn't do anything when already enabled
    // we don't do this in appcontroller as we want our data to be loaded
    if([sud boolForKey:BDSKShouldLookForSharedFilesKey]){
        if([[BDSKSharingBrowser sharedBrowser] isBrowsing])
            // force an initial update of the tableview, if browsing is already in progress
            [self handleSharedGroupsChangedNotification:nil];
        else
            [[BDSKSharingBrowser sharedBrowser] enableSharedBrowsing];
    }
    if([sud boolForKey:BDSKShouldShareFilesKey])
        [[BDSKSharingServer defaultServer] enableSharing];
    
    // The UI update from setPublications is too early when loading a new document
    [self updateSmartGroupsCount];
    [self updateCategoryGroupsPreservingSelection:NO];
    
    [saveTextEncodingPopupButton setEncoding:BDSKNoStringEncoding];
    
    // this shouldn't be necessary
    [documentWindow recalculateKeyViewLoop];
    [documentWindow makeFirstResponder:tableView];
    
    [self startObserving];
    
    NSArray *groupsToExpand = [xattrDefaults objectForKey:BDSKDocumentGroupsToExpandKey];
    for (BDSKParentGroup *parent in groups) {
        if (parent != [groups libraryParent] && (groupsToExpand == nil || [groupsToExpand containsObject:NSStringFromClass([parent class])]))
            [groupOutlineView expandItem:parent];
    }
    // make sure the groups are sorted and have their sort descriptors set
    [self sortGroupsByKey:nil];
    
    NSData *groupData = [xattrDefaults objectForKey:BDSKSelectedGroupsKey];
    if ([groupData length]) {
        NSSet *allGroups = [NSSet setWithArray:[groups allChildren]];
        NSMutableArray *groupsToSelect = [NSMutableArray array];
        for (BDSKGroup *group in [NSKeyedUnarchiver unarchiveObjectWithData:groupData]) {
            if ((group = [allGroups member:group]))
                [groupsToSelect addObject:group];
        }
        if ([groupsToSelect count])
            [self selectGroups:groupsToSelect];
    }
    
    [self selectItemsForCiteKeys:[xattrDefaults objectForKey:BDSKSelectedPublicationsKey] ?: [NSArray array] selectLibrary:NO];
    
    // this gives NSZeroPoint when the value is incompatible or missing
    NSPoint scrollPoint = NSPointFromString([xattrDefaults objectForKey:BDSKDocumentScrollPercentageKey]);
    [tableView setScrollPositionAsPercentage:scrollPoint];
    
    [self updatePreviews];
}

- (BOOL)undoManagerShouldUndoChange:(id)sender{
	if (![self isDocumentEdited]) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Warning", @"Message in alert dialog") 
                                         defaultButton:NSLocalizedString(@"Yes", @"Button title") 
                                       alternateButton:NSLocalizedString(@"No", @"Button title") 
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"You are about to undo past the last point this file was saved. Do you want to do this?", @"Informative text in alert dialog") ];

		NSInteger rv = [alert runModal];
		if (rv == NSAlertAlternateReturn)
			return NO;
	}
	return YES;
}

// this is needed for the BDSKOwner protocol
- (NSUndoManager *)undoManager {
    return [super undoManager];
}

- (BOOL)isMainDocument {
    return [[[NSDocumentController sharedDocumentController] mainDocument] isEqual:self];
}

- (BOOL)commitPendingEdits {
    for (id editor in [self windowControllers]) {
        // not all window controllers are editors...
        if ([editor respondsToSelector:@selector(commitEditing)] && [editor commitEditing] == NO)
            return NO;
    }
    return YES;
}

- (void)windowWillClose:(NSNotification *)notification{
        
    docFlags.isDocumentClosed = YES;
    
    // remove all queued invocations
    [[self class] cancelPreviousPerformRequestsWithTarget:self];
    
    [documentSearch terminate];
    [fileSearchController terminateForDocumentURL:[self fileURL]];
    [notesSearchIndex terminate];
    
    if([drawerController isDrawerOpen])
        [drawerController toggle:nil];
    [self saveWindowSetupInExtendedAttributesAtURL:[self fileURL] forEncoding:BDSKNoStringEncoding];
    
    // reset the previewer; don't send [self updatePreviews:] here, as the tableview will be gone by the time the queue posts the notification
    if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey] &&
       [[BDSKPreviewer sharedPreviewer] isWindowVisible] &&
       [self isMainDocument] &&
       [self numberOfSelectedPubs] != 0)
        [[BDSKPreviewer sharedPreviewer] updateWithBibTeXString:nil];    
	
	[pboardHelper setDelegate:nil];
    [pboardHelper release];
    pboardHelper = nil;
    
    [sideFileView setDataSource:nil];
    [sideFileView setDelegate:nil];
    
    [bottomFileView setDataSource:nil];
    [bottomFileView setDelegate:nil];
    
    [self endObserving];
    
    // safety call here, in case the pasteboard is retaining the document; we don't want notifications after the window closes, since all the pointers to UI elements will be garbage
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject {
    if ([self isDisplayingWebGroupView] && [webGroupViewController respondsToSelector:_cmd])
        return [webGroupViewController windowWillReturnFieldEditor:sender toObject:anObject];
    return nil;
}

// returns empty dictionary if no attributes set
- (NSDictionary *)mainWindowSetupDictionaryFromExtendedAttributes {
    if (mainWindowSetupDictionary == nil) {
        if ([self fileURL]) {
            mainWindowSetupDictionary = [[[SKNExtendedAttributeManager sharedNoSplitManager] propertyListFromExtendedAttributeNamed:BDSKMainWindowExtendedAttributeKey atPath:[[self fileURL] path] traverseLink:YES error:NULL] retain];
            if (mainWindowSetupDictionary && [mainWindowSetupDictionary isKindOfClass:[NSDictionary class]] == NO) {
                NSLog(@"Window setup EAs had wrong class %@", [mainWindowSetupDictionary class]);
                BDSKDESTROY(mainWindowSetupDictionary);
            }
        }
        if (nil == mainWindowSetupDictionary)
            mainWindowSetupDictionary = [[NSDictionary alloc] init];
    }
    return mainWindowSetupDictionary;
}

- (NSDictionary *)saveWindowSetupInExtendedAttributesAtURL:(NSURL *)anURL forEncoding:(NSStringEncoding)encoding {
    
    NSString *path = [anURL path];
    NSMutableDictionary *dictionary = nil;
    
    if (path && [[NSUserDefaults standardUserDefaults] boolForKey:BDSKDisableDocumentExtendedAttributesKey] == NO) {
        
        // We could set each of these as a separate attribute name on the file, but then we'd need to muck around with prepending net.sourceforge.bibdesk. to each key, and that seems messy.
        dictionary = [[self mainWindowSetupDictionaryFromExtendedAttributes] mutableCopy];
        
        [dictionary setObject:[[[tableView tableColumnIdentifiers] arrayByRemovingObject:BDSKImportOrderString] arrayByRemovingObject:BDSKRelevanceString] forKey:BDSKShownColsNamesKey];
        [dictionary setObject:[self currentTableColumnWidthsAndIdentifiers] forKey:BDSKColumnWidthsKey];
        [dictionary setObject:sortKey ?: BDSKTitleString forKey:BDSKDefaultSortedTableColumnKey];
        [dictionary setBool:docFlags.sortDescending forKey:BDSKDefaultSortedTableColumnIsDescendingKey];
        if (previousSortKey) {
            [dictionary setObject:previousSortKey forKey:BDSKDefaultSubsortedTableColumnKey];
            [dictionary setBool:docFlags.previousSortDescending forKey:BDSKDefaultSubsortedTableColumnIsDescendingKey];
        }
        [dictionary setObject:sortGroupsKey forKey:BDSKSortGroupsKey];
        [dictionary setBool:docFlags.sortGroupsDescending forKey:BDSKSortGroupsDescendingKey];
        [dictionary setObject:NSStringFromRect([documentWindow frame]) forKey:BDSKDocumentWindowFrameKey];
        [dictionary setDouble:[groupSplitView fraction] forKey:BDSKGroupSplitViewFractionKey];
        // of the 3 splitviews, the fraction of the first divider would be considered, so fallback to the fraction from the nib
        if (NO == [self hasWebGroupsSelected])
            [dictionary setDouble:[splitView fraction] forKey:BDSKMainTableSplitViewFractionKey];
        [dictionary setDouble:docState.lastWebViewFraction forKey:BDSKWebViewFractionKey];
        [dictionary setObject:currentGroupField forKey:BDSKCurrentGroupFieldKey];
        
        // we can't just use -documentStringEncoding, because that may be different for SaveTo
        if (encoding != BDSKNoStringEncoding)
            [dictionary setUnsignedInteger:encoding forKey:BDSKDocumentStringEncodingKey];
        
        // encode groups so we can select them later with isEqual: (saving row indexes would not be as reliable)
        [dictionary setObject:([self hasExternalGroupsSelected] ? [NSData data] : [NSKeyedArchiver archivedDataWithRootObject:[self selectedGroups]]) forKey:BDSKSelectedGroupsKey];
        
        NSArray *selectedKeys = [[self selectedPublications] valueForKey:@"citeKey"];
        if ([selectedKeys count] == 0 || [self hasExternalGroupsSelected])
            selectedKeys = [NSArray array];
        [dictionary setObject:selectedKeys forKey:BDSKSelectedPublicationsKey];
        [dictionary setObject:NSStringFromPoint([tableView scrollPositionAsPercentage]) forKey:BDSKDocumentScrollPercentageKey];
        
        [dictionary setInteger:bottomPreviewDisplay forKey:BDSKBottomPreviewDisplayKey];
        [dictionary setObject:bottomPreviewDisplayTemplate forKey:BDSKBottomPreviewDisplayTemplateKey];
        [dictionary setInteger:sidePreviewDisplay forKey:BDSKSidePreviewDisplayKey];
        [dictionary setObject:sidePreviewDisplayTemplate forKey:BDSKSidePreviewDisplayTemplateKey];
        
        [dictionary setInteger:[bottomFileView displayMode] forKey:BDSKBottomFileViewDisplayModeKey];
        [dictionary setDouble:([bottomFileView displayMode] == FVDisplayModeGrid ? [bottomFileView iconScale] : 0.0) forKey:BDSKBottomFileViewIconScaleKey];
        [dictionary setInteger:[sideFileView displayMode] forKey:BDSKSideFileViewDisplayModeKey];
        [dictionary setDouble:([sideFileView displayMode] == FVDisplayModeGrid ? [sideFileView iconScale] : 0.0) forKey:BDSKSideFileViewIconScaleKey];
        
        [dictionary setDouble:[(BDSKZoomableTextView *)bottomPreviewTextView scaleFactor] forKey:BDSKBottomPreviewScaleFactorKey];
        [dictionary setDouble:[(BDSKZoomableTextView *)sidePreviewTextView scaleFactor] forKey:BDSKSidePreviewScaleFactorKey];
        
        if(previewer){
            [dictionary setDouble:[previewer PDFScaleFactor] forKey:BDSKPreviewPDFScaleFactorKey];
            [dictionary setDouble:[previewer RTFScaleFactor] forKey:BDSKPreviewRTFScaleFactorKey];
        }
        
        if(fileSearchController){
            [dictionary setObject:[fileSearchController sortDescriptorData] forKey:BDSKFileContentSearchSortDescriptorKey];
        }
        
        NSMutableArray *groupsToExpand = [NSMutableArray array];
        for (BDSKParentGroup *parent in groups) {
            if (parent != [groups libraryParent] && [groupOutlineView isItemExpanded:parent])
                [groupsToExpand addObject:NSStringFromClass([parent class])];
            
        }
        [dictionary setObject:groupsToExpand forKey:BDSKDocumentGroupsToExpandKey];
        
        NSError *error;
        
        if ([[SKNExtendedAttributeManager sharedNoSplitManager] setExtendedAttributeNamed:BDSKMainWindowExtendedAttributeKey 
                                                  toPropertyListValue:dictionary
                                                               atPath:path options:0 error:&error] == NO) {
            NSLog(@"failed to save EAs for %@: %@", self, error);
            if ([[error domain] isEqualToString:NSPOSIXErrorDomain] && [error code] == E2BIG) {
                // the dictionary was too big, remove the items that are most likely to cause this as they can grow indefinitely
                [dictionary removeObjectForKey:BDSKSelectedPublicationsKey]; 
                [dictionary removeObjectForKey:BDSKSelectedGroupsKey]; 
                if ([[SKNExtendedAttributeManager sharedNoSplitManager] setExtendedAttributeNamed:BDSKMainWindowExtendedAttributeKey 
                                                          toPropertyListValue:dictionary
                                                                       atPath:path options:0 error:&error] == NO) {
                    NSLog(@"failed to save partial EAs for %@: %@", self, error);
                }
            }
        }
    }
    
    return [dictionary autorelease];
}

#pragma mark -
#pragma mark Publications acessors

// This is not undoable!
- (void)setPublications:(NSArray *)newPubs{
    [publications setValue:nil forKey:@"owner"];
    [publications setArray:newPubs];
    [publications setValue:self forKey:@"owner"];
    
    [searchIndexes resetWithPublications:newPubs];
    [notesSearchIndex resetWithPublications:newPubs];
}    

- (BDSKPublicationsArray *)publications{
    return publications;
}

- (NSArray *)shownPublications{
    return shownPublications;
}

- (void)insertPublications:(NSArray *)pubs atIndexes:(NSIndexSet *)indexes{
    // this assertion is only necessary to preserve file order for undo
    NSParameterAssert([indexes count] == [pubs count]);
    [[[self undoManager] prepareWithInvocationTarget:self] removePublicationsAtIndexes:indexes];
		
	[publications insertObjects:pubs atIndexes:indexes];        
    
	[pubs setValue:self forKey:@"owner"];
	
    [searchIndexes addPublications:pubs];
    [notesSearchIndex addPublications:pubs];

	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:pubs, BDSKDocumentPublicationsKey, nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocAddItemNotification
														object:self
													  userInfo:notifInfo];
}

- (void)addPublications:(NSArray *)pubs{
    [self insertPublications:pubs atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,[pubs count])]];
}

- (void)addPublication:(BibItem *)pub{
    // insert new pubs at the beginning, so item number is handled properly
    [self insertPublications:[NSArray arrayWithObject:pub] atIndexes:[NSIndexSet indexSetWithIndex:0]];
}

- (void)removePublicationsAtIndexes:(NSIndexSet *)indexes{
    NSArray *pubs = [publications objectsAtIndexes:indexes];
	[[[self undoManager] prepareWithInvocationTarget:self] insertPublications:pubs atIndexes:indexes];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:pubs, BDSKDocumentPublicationsKey, nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocWillRemoveItemNotification
														object:self
													  userInfo:notifInfo];	
    
    [[groups lastImportGroup] removePublicationsInArray:pubs];
    [[groups staticGroups] makeObjectsPerformSelector:@selector(removePublicationsInArray:) withObject:pubs];
    [searchIndexes removePublications:pubs];
    [notesSearchIndex removePublications:pubs];
    
	[publications removeObjectsAtIndexes:indexes];
	
	[pubs setValue:nil forKey:@"owner"];
    [[NSFileManager defaultManager] removeSpotlightCacheFilesForCiteKeys:[pubs valueForKey:@"citeKey"]];
	
	notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:pubs, BDSKDocumentPublicationsKey, nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocDelItemNotification
														object:self
													  userInfo:notifInfo];
}

- (void)removePublications:(NSArray *)pubs{
    [self removePublicationsAtIndexes:[publications indexesOfObjectsIdenticalTo:pubs]];
}

- (void)removePublication:(BibItem *)pub{
    [self removePublicationsAtIndexes:[NSIndexSet indexSetWithIndex:[publications indexOfObjectIdenticalTo:pub]]];
}

#pragma mark Groups accessors

- (BDSKGroupsArray *)groups{
    return groups;
}

#pragma mark Searching

- (BDSKItemSearchIndexes *)searchIndexes{
    return searchIndexes;
}

#pragma mark Document Info

- (NSDictionary *)documentInfo{
    return documentInfo;
}

- (void)setDocumentInfo:(NSDictionary *)dict{
    if (dict != documentInfo) {
        [[[self undoManager] prepareWithInvocationTarget:self] setDocumentInfo:documentInfo];
        [documentInfo release];
        documentInfo = [[NSDictionary alloc] initForCaseInsensitiveKeysWithDictionary:dict];
    }
}

- (NSString *)documentInfoForKey:(NSString *)key{
    return [documentInfo valueForKey:key];
}

- (id)valueForUndefinedKey:(NSString *)key{
    return [self documentInfoForKey:key];
}

- (NSString *)documentInfoString{
    NSMutableString *string = [NSMutableString stringWithString:@"@bibdesk_info{document_info"];
    for (NSString *key in documentInfo) 
        [string appendStrings:@",\n\t", key, @" = ", [[self documentInfoForKey:key] stringAsBibTeXString], nil];
    [string appendString:@"\n}\n"];
    
    return string;
}

#pragma mark Macro stuff

- (BDSKMacroResolver *)macroResolver{
    return macroResolver;
}

#pragma mark -
#pragma mark  Document Saving

+ (NSArray *)writableTypes
{
    NSMutableArray *writableTypes = [[[super writableTypes] mutableCopy] autorelease];
    [writableTypes addObjectsFromArray:[BDSKTemplate allStyleNames]];
    return writableTypes;
}

- (NSString *)fileNameExtensionForType:(NSString *)typeName saveOperation:(NSSaveOperationType)saveOperation
{
    // this will never be called on 10.4, so we can safely call super
    return [super fileNameExtensionForType:typeName saveOperation:saveOperation] ?: [[BDSKTemplate templateForStyle:typeName] fileExtension];
}

#define SAVE_ENCODING_VIEW_OFFSET 30.0
#define SAVE_FORMAT_POPUP_OFFSET 66.0

static NSPopUpButton *popUpButtonSubview(NSView *view)
{
	if ([view isKindOfClass:[NSPopUpButton class]])
		return (NSPopUpButton *)view;
	
	NSPopUpButton *popup;
	
	for (NSView *subview in [view subviews]) {
		if ((popup = popUpButtonSubview(subview)))
			return popup;
	}
	return nil;
}

// if the user is saving in one of our plain text formats, give them an encoding option as well
// this also requires overriding saveToURL:ofType:forSaveOperation:delegate:didSaveSelector:contextInfo:
// to set the document's encoding before after to the file
- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel{
    if([super prepareSavePanel:savePanel] == NO)
        return NO;
    
    if(NSSaveToOperation == docState.currentSaveOperationType){
        NSView *accessoryView = [savePanel accessoryView];
        BDSKASSERT(accessoryView != nil);
        BDSKASSERT(saveFormatPopupButton == nil);
        saveFormatPopupButton = popUpButtonSubview(accessoryView);
        BDSKASSERT(saveFormatPopupButton != nil);
        NSRect savFrame = [saveAccessoryView frame];
        NSRect exportFrame = [exportAccessoryView frame];
        savFrame.origin = NSMakePoint(0.0, SAVE_ENCODING_VIEW_OFFSET);
        [saveAccessoryView setFrame:savFrame];
        exportFrame.size.width = NSWidth(savFrame);
        [exportAccessoryView setFrame:exportFrame];
        [exportAccessoryView addSubview:saveAccessoryView];
        NSRect popupFrame = [saveTextEncodingPopupButton frame];
        popupFrame.origin.y = SAVE_FORMAT_POPUP_OFFSET;
        [saveFormatPopupButton setFrame:popupFrame];
        [exportAccessoryView addSubview:saveFormatPopupButton];
        [savePanel setAccessoryView:exportAccessoryView];
    }else{
        [savePanel setAccessoryView:saveAccessoryView];
    }
    
    // set the popup to reflect the document's present string encoding
    [saveTextEncodingPopupButton setEncoding:[self documentStringEncoding]];
    [saveTextEncodingPopupButton setEnabled:YES];
    
    [exportSelectionCheckButton setState:NSOffState];
    if(NSSaveToOperation == docState.currentSaveOperationType)
        [exportSelectionCheckButton setEnabled:[self numberOfSelectedPubs] > 0 || [self hasLibraryGroupSelected] == NO];
    
    return YES;
}

- (BOOL)needsEncodingForType:(NSString *)typeName {
    return [[NSSet setWithObjects:BDSKBibTeXDocumentType, BDSKRISDocumentType, BDSKMinimalBibTeXDocumentType, BDSKLTBDocumentType, BDSKArchiveDocumentType, nil] containsObject:typeName];
}

// this is a private method, the action of the file format poup
- (void)changeSaveType:(id)sender{
    [saveTextEncodingPopupButton setEnabled:[self needsEncodingForType:[[sender selectedItem] representedObject]]];
    if ([NSDocument instancesRespondToSelector:@selector(changeSaveType:)])
        [super changeSaveType:sender];
}

- (NSArray *)publicationsForSaving {
    if (docState.currentSaveOperationType != NSSaveToOperation || [exportSelectionCheckButton state] != NSOnState)
        return publications;
    else if ([self numberOfSelectedPubs] == 0)
        return groupedPublications;
    else
        return [self selectedPublications];
}

- (NSStringEncoding)encodingForSaving {
    NSStringEncoding encoding = 0;
    
    // export operations need their own encoding
    if (NSSaveToOperation == docState.currentSaveOperationType)
        encoding = [saveTextEncodingPopupButton encoding] != BDSKNoStringEncoding ? [saveTextEncodingPopupButton encoding] : [BDSKStringEncodingManager defaultEncoding];
    else if (NSSaveAsOperation == docState.currentSaveOperationType && [saveTextEncodingPopupButton encoding] != BDSKNoStringEncoding)
        encoding = [saveTextEncodingPopupButton encoding];
    else
        encoding = [self documentStringEncoding];
    
    BDSKASSERT(encoding != 0 && encoding != BDSKNoStringEncoding);
    
    return encoding;
}

- (void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo {
    // save this early, so we can setup the panel correctly, the other setting will come later
    docState.currentSaveOperationType = saveOperation;
    [super runModalSavePanelForSaveOperation:saveOperation delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}

- (void)document:(NSDocument *)doc didSave:(BOOL)didSave contextInfo:(void *)contextInfo {
    NSDictionary *info = [(id)contextInfo autorelease];
    NSString *typeName = [info objectForKey:@"typeName"];
    NSInvocation *invocation = [info objectForKey:@"callback"];
    
    if (didSave) {
        NSStringEncoding encoding = NSUTF8StringEncoding;
        if ([self needsEncodingForType:typeName]) {
            encoding = [self encodingForSaving];
            // Set the string encoding according to the popup when Save As changed it
            if (docState.currentSaveOperationType == NSSaveAsOperation)
                [self setDocumentStringEncoding:encoding];
        }
        
        // set com.apple.TextEncoding for other apps
        NSString *UTI = [[NSWorkspace sharedWorkspace] typeOfFile:[saveTargetURL path] error:NULL];
        if (UTI && [[NSWorkspace sharedWorkspace] type:UTI conformsToType:(id)kUTTypePlainText])
            [[NSFileManager defaultManager] setAppleStringEncoding:encoding atPath:[saveTargetURL path] error:NULL];
        
        if (docState.currentSaveOperationType == NSSaveToOperation) {
            
            // write template accessory files if necessary
            BDSKTemplate *selectedTemplate = [BDSKTemplate templateForStyle:typeName];
            if(selectedTemplate){
                NSURL *destDirURL = [saveTargetURL URLByDeletingLastPathComponent];
                for (NSURL *accessoryURL in [selectedTemplate accessoryFileURLs])
                    [[NSFileManager defaultManager] copyObjectAtURL:accessoryURL toDirectoryAtURL:destDirURL error:NULL];
            }
            
        } else if (docState.currentSaveOperationType == NSSaveOperation || docState.currentSaveOperationType == NSSaveAsOperation) {
            
            // rebuild metadata cache for this document whenever we save
            NSMutableArray *pubsInfo = [[NSMutableArray alloc] initWithCapacity:[publications count]];
            NSDictionary *cacheInfo;
            BOOL update = (docState.currentSaveOperationType == NSSaveOperation); // for saveTo we should update all items, as our path changes
            
            for (BibItem *anItem in [self publications]) {
                NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
                @try {
                    if(cacheInfo = [anItem metadataCacheInfoForUpdate:update])
                        [pubsInfo addObject:cacheInfo];
                }
                @catch (id e) { @throw(e); }
                @finally { [pool release]; }
            }
            
            BDSKMetadataCacheOperation *operation = [[[BDSKMetadataCacheOperation alloc] initWithPublicationInfos:pubsInfo forDocumentURL:saveTargetURL] autorelease];
            [metadataCacheQueue addOperation:operation];
            [pubsInfo release];
            
        }
        
        // save our window setup if we save or export to BibTeX
        if ([[self class] isNativeType:typeName] || [typeName isEqualToString:BDSKMinimalBibTeXDocumentType]) {
            NSDictionary *dictionary = [self saveWindowSetupInExtendedAttributesAtURL:saveTargetURL forEncoding:encoding];
            if (dictionary && (docState.currentSaveOperationType == NSSaveOperation || docState.currentSaveOperationType == NSSaveAsOperation)) {
                [mainWindowSetupDictionary release];
                mainWindowSetupDictionary = [dictionary copy];
            }
        }
    }
    
    BDSKDESTROY(saveTargetURL);
    
    // reset the encoding popup so we know when it wasn't shown to the user next time
    [saveTextEncodingPopupButton setEncoding:BDSKNoStringEncoding];
    // in case we saved using the panel, we should reset that
    [exportSelectionCheckButton setState:NSOffState];
    [saveFormatPopupButton removeFromSuperview];
    saveFormatPopupButton = nil;
    
    if (invocation) {
        [invocation setArgument:&doc atIndex:2];
        [invocation setArgument:&didSave atIndex:3];
        [invocation invoke];
    }
    
    if (didSave && (docState.currentSaveOperationType == NSSaveOperation || docState.currentSaveOperationType == NSSaveAsOperation)) {
        [[BDSKScriptHookManager sharedManager] runScriptHookWithName:BDSKSaveDocumentScriptHookName 
                                                     forPublications:publications
                                                            document:self];
    }
}

- (void)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo {
    // Override so we can determine if this is an autosave in writeToURL:ofType:error:.
    docState.currentSaveOperationType = saveOperation;
    saveTargetURL = [absoluteURL copy];
    
    NSInvocation *invocation = nil;
    if (delegate && didSaveSelector) {
        invocation = [NSInvocation invocationWithTarget:delegate selector:didSaveSelector];
        [invocation setArgument:&contextInfo atIndex:4];
    }
    NSDictionary *info = [[NSDictionary alloc] initWithObjectsAndKeys:typeName, @"typeName", invocation, @"callback", nil];
    [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation delegate:self didSaveSelector:@selector(document:didSave:contextInfo:) contextInfo:info];
}

- (BOOL)writeToURL:(NSURL *)fileURL ofType:(NSString *)docType error:(NSError **)outError{
    BOOL success = YES;
    NSError *nsError = nil;
    
    // callers are responsible for making sure all edits are committed
    NSParameterAssert([self commitPendingEdits]);
    
    if ([docType isEqualToString:BDSKArchiveDocumentType])
        success = [self writeArchiveToURL:fileURL error:&nsError];
    else
        success = [super writeToURL:fileURL ofType:docType error:&nsError];
    
    // see if this is our error or Apple's
    if (NO == success && [nsError isLocalError]) {
        NSString *errTitle = NSAutosaveOperation == docState.currentSaveOperationType ? NSLocalizedString(@"Unable to autosave file", @"Error description") : NSLocalizedString(@"Unable to save file", @"Error description");
        
        // @@ do this in fileWrapperOfType:forPublications:error:?  should just use error localizedDescription
        NSString *errMsg = [nsError valueForKey:NSLocalizedRecoverySuggestionErrorKey] ?: NSLocalizedString(@"The underlying cause of this error is unknown.  Please submit a bug report with the file attached.", @"Error informative text");
        
        nsError = [NSError mutableLocalErrorWithCode:kBDSKDocumentSaveError localizedDescription:errTitle underlyingError:nsError];
        [nsError setValue:errMsg forKey:NSLocalizedRecoverySuggestionErrorKey];        
    }
    
    // setting to nil is okay
    if (outError) *outError = nsError;
    
    return success;
}

- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError;
{
    /*
     Apple's safe-saving is broken on NFS http://sourceforge.net/tracker/index.php?func=detail&aid=2822780&group_id=61487&atid=497423
     Always use the workaround path in that case, based on the mount type.  Tested by automounting an RHEL5 export on 10.5.7.
     Unknown whether this is needed on 10.4, but NSAppKitVersionNumber check is needed because of the condition below.
     */
     NSString *fsType = nil;
     if ([[NSWorkspace sharedWorkspace] getFileSystemInfoForPath:[absoluteURL path] isRemovable:NULL isWritable:NULL isUnmountable:NULL description:NULL type:&fsType] == NO)
         fsType = nil;
     BOOL didSave;

     // same conditional as used for workaround code path
     if ([absoluteURL isFileURL] && NSAutosaveOperation != saveOperation && [[fsType lowercaseString] isEqualToString:@"nfs"])
         didSave = NO;
     else
         didSave = [super writeSafelyToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
    
    /* 
     This is a workaround for https://sourceforge.net/tracker/index.php?func=detail&aid=1867790&group_id=61487&atid=497423
     Filed as rdar://problem/5679370
     
     I'm not sure what the semantics of this operation are for NSAutosaveOperation, so it's excluded (but uses a different code path anyway, at least on Leopard).  This also doesn't get hit for save-as or save-to since they don't do a safe-save, but they're handled anyway.  FSExchangeObjects apparently avoids the bugs in FSPathReplaceObject, but doesn't preserve all of the metadata that those do.  It's a shame that Apple can't preserve the file content as well as they preserve the metadata; I'd rather lose the ACLs than lose my bibliography.
     
     TODO:  xattr handling, package vs. flat file (overwrite directory)?  
     xattrs from BibDesk seem to be preserved, so I'm not going to bother with that.
     
     TESTED:  On AFP volume served by 10.4.11 Server, saving from 10.5.1 client; on AFP volume served by 10.5.1 client, saving from 10.5.1 client.  Autosave, Save-As, and Save were tested.  Saving to a local HFS+ volume doesn't hit this code path, and neither does saving to a FAT-32 thumb drive.
     
     */
    
    if (NO == didSave && [absoluteURL isFileURL] && NSAutosaveOperation != saveOperation) {
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        // this will create a new file on the same volume as the original file, which we will overwrite
        // FSExchangeObjects requires both files to be on the same volume
        NSString *tmpPath = [fileManager temporaryPathForWritingToPath:[absoluteURL path] error:outError];
        NSURL *saveToURL = nil;
        
        // at this point, we're guaranteed that absoluteURL is non-nil and is a fileURL, but the file may not exist
        
        // save to or save as; file doesn't exist, so overwrite it
        if (NSSaveOperation != saveOperation)
            saveToURL = absoluteURL;
        else if (nil != tmpPath)
            saveToURL = [NSURL fileURLWithPath:tmpPath];
        
        // if tmpPath failed, saveToURL is nil
        if (nil != saveToURL)
            didSave = [self writeToURL:saveToURL ofType:typeName forSaveOperation:saveOperation originalContentsURL:absoluteURL error:outError];
        
        if (didSave) {
            NSMutableDictionary *fattrs = [NSMutableDictionary dictionary];
            [fattrs addEntriesFromDictionary:[self fileAttributesToWriteToURL:saveToURL ofType:typeName forSaveOperation:saveOperation originalContentsURL:absoluteURL error:outError]];
            
            // copy POSIX permissions from the old file
            NSNumber *posixPerms = nil;
            
            if ([fileManager fileExistsAtPath:[absoluteURL path]])
                posixPerms = [[fileManager attributesOfItemAtPath:[absoluteURL path] error:NULL] objectForKey:NSFilePosixPermissions];
            
            if (nil != posixPerms)
                [fattrs setObject:posixPerms forKey:NSFilePosixPermissions];
            
            // not checking return value here; non-critical
            if ([fattrs count])
                [fileManager setAttributes:fattrs ofItemAtPath:[saveToURL path] error:NULL];
        }
        
        // If this is not an overwriting operation, we already saved to absoluteURL, and we're done
        // If this is an overwriting operation, do an atomic swap of the files
        if (didSave && NSSaveOperation == saveOperation) {
            
            FSRef originalRef, newRef;
            OSStatus err = coreFoundationUnknownErr;
            
            FSCatalogInfo catalogInfo;
            if (CFURLGetFSRef((CFURLRef)absoluteURL, &originalRef))
                err = noErr;
            
            if (noErr == err)
                err = FSGetCatalogInfo(&originalRef, kFSCatInfoVolume, &catalogInfo, NULL, NULL, NULL);
            
            GetVolParmsInfoBuffer infoBuffer;
            if (noErr == err)
                err = FSGetVolumeParms(catalogInfo.volume, &infoBuffer, sizeof(GetVolParmsInfoBuffer));
            
            if (noErr == err) {
                
                // only meaningful in v3 or greater GetVolParmsInfoBuffer
                SInt32 vmExtAttr = infoBuffer.vMExtendedAttributes;
                
                // in v2 or less or v3 without HFS+ support, the File Manager will implement FSExchangeObjects if bHasFileIDs is set
                
                // MoreFilesX.h has macros that show how to read the bitfields for the enums
                if (infoBuffer.vMVersion > 2 && (vmExtAttr & (1L << bSupportsHFSPlusAPIs)) != 0 && (vmExtAttr & (1L << bSupportsFSExchangeObjects)) != 0)
                    err = noErr;
                else if ((infoBuffer.vMVersion <= 2 || (vmExtAttr & (1L << bSupportsHFSPlusAPIs)) == 0) && (infoBuffer.vMAttrib & (1L << bHasFileIDs)) != 0)
                    err = noErr;
                else
                    err = errFSUnknownCall;
                
                // do an atomic swap of the files
                // On an AFP volume (Server 10.4.11), xattrs from the original file are preserved using either function
                
                if (noErr == err && CFURLGetFSRef((CFURLRef)saveToURL, &newRef)) {   
                    // this avoids breaking aliases and FSRefs
                    err = FSExchangeObjects(&newRef, &originalRef);
                }
                else /* if we couldn't get an FSRef or bSupportsFSExchangeObjects is not supported */ {
                    // rename() is atomic, but it probably breaks aliases and FSRefs
                    // FSExchangeObjects() uses exchangedata() so there's no point in trying that
                    err = rename([[saveToURL path] fileSystemRepresentation], [[absoluteURL path] fileSystemRepresentation]);
                }
            }
            
            if (noErr != err) {
                didSave = NO;
                if (outError) *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
            }
            else if ([self keepBackupFile] == NO) {
                // not checking return value here; non-critical, and fails if rename() was used
                [fileManager removeItemAtPath:[saveToURL path] error:NULL];
            }
        }
    }
    
    return didSave;
}

- (void)clearChangeCount{
	[self updateChangeCount:NSChangeCleared];
}

- (BOOL)writeArchiveToURL:(NSURL *)fileURL error:(NSError **)outError{
    NSString *dirPath = [[fileURL path] stringByDeletingLastPathComponent];
    NSString *targetName = [[saveTargetURL lastPathComponent] stringByDeletingPathExtension];
    NSString *folderPath = [dirPath stringByAppendingPathComponent:targetName];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *filePath;
    NSString *commonParent = nil;
    BOOL success = YES;
    NSMutableSet *localFiles = [NSMutableSet set];
    
    if ((success = [fm createDirectoryAtPath:folderPath withIntermediateDirectories:NO attributes:nil error:NULL])) {
        for (BibItem *item in [self publicationsForSaving]) {
            for (BDSKLinkedFile *file in [item localFiles]) {
                if ((filePath = [file path])) {
                    [localFiles addObject:filePath];
                    if (commonParent)
                        commonParent = [[filePath stringByDeletingLastPathComponent] commonRootPathOfFile:commonParent];
                    else
                        commonParent = [filePath stringByDeletingLastPathComponent];
                }
            }
        }
        
        NSData *bibtexData = [self bibTeXDataDroppingInternal:NO relativeToPath:commonParent error:outError];
        NSString *bibtexPath = [[folderPath stringByAppendingPathComponent:targetName] stringByAppendingPathExtension:@"bib"];
        
        success = [bibtexData writeToFile:bibtexPath options:0 error:outError];
        
        for (filePath in localFiles) {
            if (success == NO) break;
            if ([fm fileExistsAtPath:filePath]) {
                NSString *relativePath = commonParent ? [filePath relativePathFromPath:commonParent] : [filePath lastPathComponent];
                NSString *targetPath = [folderPath stringByAppendingPathComponent:relativePath];
                
                if ([fm fileExistsAtPath:targetPath])
                    targetPath = [fm uniqueFilePathWithName:[targetPath stringByDeletingLastPathComponent] atPath:[targetPath lastPathComponent]];
                success = [fm createPathToFile:targetPath attributes:nil];
                if (success)
                success = [fm copyItemAtPath:filePath toPath:targetPath error:NULL];
            }
        }
        
        if (success) {
            NSTask *task = [[[BDSKTask alloc] init] autorelease];
            [task setLaunchPath:@"/usr/bin/tar"];
            [task setArguments:[NSArray arrayWithObjects:@"czf", [[fileURL path] lastPathComponent], targetName, nil]];
            [task setCurrentDirectoryPath:dirPath];
            [task launch];
            if ([task isRunning])
                [task waitUntilExit];
            success = [task terminationStatus] == 0;
            [fm removeItemAtPath:folderPath error:NULL];
        }
    }
    
    return success;
}

#pragma mark Data representations

- (NSFileWrapper *)fileWrapperOfType:(NSString *)aType error:(NSError **)outError
{
    NSFileWrapper *fileWrapper = nil;
    
    // check if we need a fileWrapper; only needed for RTFD templates
    BDSKTemplate *selectedTemplate = [BDSKTemplate templateForStyle:aType];
    if([selectedTemplate templateFormat] & BDSKRTFDTemplateFormat){
        fileWrapper = [self fileWrapperUsingTemplate:selectedTemplate];
        if(fileWrapper == nil){
            if (outError) 
                *outError = [NSError localErrorWithCode:kBDSKDocumentSaveError localizedDescription:NSLocalizedString(@"Unable to create file wrapper for the selected template", @"Error description")];
        }
    }else if ([aType isEqualToString:BDSKArchiveDocumentType]){
        BDSKASSERT_NOT_REACHED("Should not save a fileWrapper for archive");
    }else{
        fileWrapper = [super fileWrapperOfType:aType error:outError];
    }
    return fileWrapper;
}

- (NSData *)dataOfType:(NSString *)aType error:(NSError **)outError
{
    NSData *data = nil;
    NSError *error = nil;
    BOOL isBibTeX = [aType isEqualToString:BDSKBibTeXDocumentType] || [aType isEqualToString:BDSKMinimalBibTeXDocumentType];
    
    if (isBibTeX){
        if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKAutoSortForCrossrefsKey])
            [self performSortForCrossrefs];
        NSString *basePath = [[saveTargetURL path] stringByDeletingLastPathComponent];
        BOOL drop = [aType isEqualToString:BDSKMinimalBibTeXDocumentType];
        data = [self bibTeXDataDroppingInternal:drop relativeToPath:basePath error:&error];
    }else if ([aType isEqualToString:BDSKRISDocumentType]){
        data = [self RISDataAndReturnError:&error];
    }else if ([aType isEqualToString:BDSKLTBDocumentType]){
        data = [self LTBDataAndReturnError:&error];
    }else if ([aType isEqualToString:BDSKEndNoteDocumentType]){
        data = [self endNoteData];
    }else if ([aType isEqualToString:BDSKMODSDocumentType]){
        data = [self MODSData];
    }else if ([aType isEqualToString:BDSKAtomDocumentType]){
        data = [self atomData];
    }else{
        data = [self dataUsingTemplate:[BDSKTemplate templateForStyle:aType]];
    }
    
    // grab the underlying error; if we recognize it, pass it up as a kBDSKDocumentSaveError
    if(nil == data && outError){
        // see if this was an encoding failure; if so, we can suggest how to fix it
        // NSLocalizedRecoverySuggestion is appropriate for display as error message in alert
        if([error isLocalErrorWithCode:kBDSKStringEncodingError]){
            // encoding conversion failure (string to data)
            NSStringEncoding usedEncoding = [[error valueForKey:NSStringEncodingErrorKey] integerValue];
            NSMutableString *message = [NSMutableString stringWithFormat:NSLocalizedString(@"The document cannot be saved using %@ encoding.", @"Error informative text"), [NSString localizedNameOfStringEncoding:usedEncoding]];
            
            // this is likely nil, so keep NSMutableString from raising
            if ([error valueForKey:NSLocalizedRecoverySuggestionErrorKey]) {
                [message appendString:@"  "];
                [message appendString:[error valueForKey:NSLocalizedRecoverySuggestionErrorKey]];
            }
            [message appendString:@"  "];
            
            // see if TeX conversion is enabled; it will help for ASCII, and possibly other encodings, but not UTF-8
            // only for BibTeX, though!
            if (isBibTeX && [[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldTeXifyWhenSavingAndCopyingKey] == NO) {
                [message appendFormat:NSLocalizedString(@"You should enable accented character conversion in the Files preference pane or save using an encoding such as %@.", @"Error informative text"), [NSString localizedNameOfStringEncoding:NSUTF8StringEncoding]];
            } else if (NSUTF8StringEncoding != usedEncoding){
                // could suggest disabling TeX conversion, but the error might be from something out of the range of what we try to convert, so combining TeXify && UTF-8 would work
                [message appendFormat:NSLocalizedString(@"You should save using an encoding such as %@.", @"Error informative text"), [NSString localizedNameOfStringEncoding:NSUTF8StringEncoding]];
            } else {
                // if UTF-8 fails, you're hosed...
                [message appendString:NSLocalizedString(@"Please report this error to BibDesk's developers.", @"Error informative text")];
            }
            
            error = [NSError mutableLocalErrorWithCode:kBDSKDocumentSaveError localizedDescription:NSLocalizedString(@"Unable to save document", @"Error description") underlyingError:error];
            [error setValue:message forKey:NSLocalizedRecoverySuggestionErrorKey];
                        
        }
        *outError = error;
    }
    
    return data;    
}

- (NSData *)bibTeXDataDroppingInternal:(BOOL)drop relativeToPath:(NSString *)basePath error:(NSError **)outError{
    NSMutableData *outputData = [NSMutableData dataWithCapacity:4096];
    NSData *pubData;
    NSError *error = nil;
    BOOL isOK = YES;
    BOOL hasData = NO;
        
    BOOL shouldAppendFrontMatter = YES;
    NSStringEncoding encoding = [self encodingForSaving];
    NSString *encodingName = [NSString localizedNameOfStringEncoding:encoding];
    NSStringEncoding groupsEncoding = [[BDSKStringEncodingManager sharedEncodingManager] isUnparseableEncoding:encoding] ? encoding : NSUTF8StringEncoding;
    
    NSInteger options = 0;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldTeXifyWhenSavingAndCopyingKey])
        options |= BDSKBibTeXOptionTeXifyMask;
    if (drop)
        options |= BDSKBibTeXOptionDropInternalMask;
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldUseTemplateFileKey]){
        NSMutableString *templateFile = [NSMutableString stringWithContentsOfFile:[[[NSUserDefaults standardUserDefaults] stringForKey:BDSKOutputTemplateFileKey] stringByExpandingTildeInPath] usedEncoding:NULL error:NULL] ?: [NSMutableString string];
        
        NSString *userName = NSFullUserName();
        if ([userName canBeConvertedToEncoding:encoding] == NO)
            userName = [[[NSString alloc] initWithData:[userName dataUsingEncoding:encoding allowLossyConversion:YES] encoding:encoding] autorelease];
        
        [templateFile appendFormat:@"\n%%%% Created for %@ at %@ \n\n", userName, [[NSDate date] standardDescription]];

        [templateFile appendFormat:@"\n%%%% Saved with string encoding %@ \n\n", encodingName];
        
        // remove all whitespace so we can make a comparison; just collapsing isn't quite good enough, unfortunately
        NSString *collapsedTemplate = [[templateFile stringByRemovingWhitespace] stringByCollapsingAndTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        NSString *collapsedFrontMatter = [[frontMatter stringByRemovingWhitespace] stringByCollapsingAndTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        if([NSString isEmptyString:collapsedFrontMatter]){
            shouldAppendFrontMatter = NO;
        }else if([collapsedTemplate rangeOfString:collapsedFrontMatter].length){
            NSLog(@"*** WARNING! *** Found duplicate preamble %@.  Using template from preferences.", frontMatter);
            shouldAppendFrontMatter = NO;
        }
        
        isOK = [outputData appendDataFromString:templateFile encoding:encoding error:&error];
        if(NO == isOK){
            if ([error isMutable] == NO) error = [[error mutableCopy] autorelease];
            [error setValue:NSLocalizedString(@"Unable to convert template string.", @"string encoding error context") forKey:NSLocalizedRecoverySuggestionErrorKey];
        }
    } else if ([NSString isEmptyString:frontMatter]) {
        shouldAppendFrontMatter = NO;
    }
    
    NSData *doubleNewlineData = [@"\n\n" dataUsingEncoding:encoding];

    // only append this if it wasn't redundant (this assumes that the original frontmatter is either a subset of the necessary frontmatter, or that the user's preferences should override in case of a conflict)
    if(isOK && shouldAppendFrontMatter){
        hasData = YES;
        isOK = [outputData appendDataFromString:frontMatter encoding:encoding error:&error];
        if(NO == isOK){
            if ([error isMutable] == NO) error = [[error mutableCopy] autorelease];
            [error setValue:NSLocalizedString(@"Unable to convert file header.", @"string encoding error context") forKey:NSLocalizedRecoverySuggestionErrorKey];
        }
        [outputData appendData:doubleNewlineData];
    }
        
    if(isOK && [documentInfo count]){
        hasData = YES;
        isOK = [outputData appendDataFromString:[self documentInfoString] encoding:encoding error:&error];
        if(NO == isOK){
            if ([error isMutable] == NO) error = [[error mutableCopy] autorelease];
            [error setValue:NSLocalizedString(@"Unable to convert document info.", @"string encoding error context") forKey:NSLocalizedRecoverySuggestionErrorKey];
        }
    }
    
    // output the document's macros:
    if(isOK){
        NSString *macroString = [[self macroResolver] bibTeXString];
        if ([NSString isEmptyString:macroString] == NO) {
            hasData = YES;
            isOK = [outputData appendDataFromString:macroString encoding:encoding error:&error];
            if(NO == isOK){
                if ([error isMutable] == NO) error = [[error mutableCopy] autorelease];
                [error setValue:NSLocalizedString(@"Unable to convert macros.", @"string encoding error context") forKey:NSLocalizedRecoverySuggestionErrorKey];
            }
        }
    }
    
    // output the bibs
    
    NSArray *pubs = [self publicationsForSaving];
    if ([pubs count] > 0) {
        hasData = YES;
        for (BibItem *pub in pubs){
            if (isOK == NO) break;
            pubData = [pub bibTeXDataWithOptions:options relativeToPath:basePath encoding:encoding error:&error];
            if((isOK = (pubData != nil))){
                [outputData appendData:doubleNewlineData];
                [outputData appendData:pubData];
            }else if([error valueForKey:NSLocalizedRecoverySuggestionErrorKey] == nil){
                if ([error isMutable] == NO) error = [[error mutableCopy] autorelease];
                [error setValue:[NSString stringWithFormat:NSLocalizedString(@"Unable to convert item with cite key %@.", @"string encoding error context"), [pub citeKey]] forKey:NSLocalizedRecoverySuggestionErrorKey];
            }
        }
    }
    
    if (drop == NO) {
        // The data from groups is always UTF-8, and we shouldn't convert it unless we have an unparseable encoding; the comment key strings should be representable in any encoding
        if(isOK && ([[groups staticGroups] count] > 0)){
            hasData = YES;
            isOK = [outputData appendDataFromString:@"\n\n@comment{BibDesk Static Groups{\n" encoding:encoding error:&error] &&
                   [outputData appendStringData:[groups serializedGroupsDataOfType:BDSKStaticGroupType] convertedFromUTF8ToEncoding:groupsEncoding error:&error] &&
                   [outputData appendDataFromString:@"}}" encoding:encoding error:&error];
            if(NO == isOK){
                if ([error isMutable] == NO) error = [[error mutableCopy] autorelease];
                [error setValue:NSLocalizedString(@"Unable to convert static groups.", @"string encoding error context") forKey:NSLocalizedRecoverySuggestionErrorKey];
            }
        }
        if(isOK && ([[groups smartGroups] count] > 0)){
            hasData = YES;
            isOK = [outputData appendDataFromString:@"\n\n@comment{BibDesk Smart Groups{\n" encoding:encoding error:&error] &&
                   [outputData appendStringData:[groups serializedGroupsDataOfType:BDSKSmartGroupType] convertedFromUTF8ToEncoding:groupsEncoding error:&error] &&
                   [outputData appendDataFromString:@"}}" encoding:encoding error:&error];
            if(NO == isOK){
                if ([error isMutable] == NO) error = [[error mutableCopy] autorelease];
                [error setValue:NSLocalizedString(@"Unable to convert smart groups.", @"string encoding error context") forKey:NSLocalizedRecoverySuggestionErrorKey];
            }
        }
        if(isOK && ([[groups URLGroups] count] > 0)){
            hasData = YES;
            isOK = [outputData appendDataFromString:@"\n\n@comment{BibDesk URL Groups{\n" encoding:encoding error:&error] &&
                   [outputData appendStringData:[groups serializedGroupsDataOfType:BDSKURLGroupType] convertedFromUTF8ToEncoding:groupsEncoding error:&error] &&
                   [outputData appendDataFromString:@"}}" encoding:encoding error:&error];
            if(NO == isOK){
                if ([error isMutable] == NO) error = [[error mutableCopy] autorelease];
                [error setValue:NSLocalizedString(@"Unable to convert external file groups.", @"string encoding error context") forKey:NSLocalizedRecoverySuggestionErrorKey];
            }
        }
        if(isOK && ([[groups scriptGroups] count] > 0)){
            hasData = YES;
            isOK = [outputData appendDataFromString:@"\n\n@comment{BibDesk Script Groups{\n" encoding:encoding error:&error] &&
                   [outputData appendStringData:[groups serializedGroupsDataOfType:BDSKScriptGroupType] convertedFromUTF8ToEncoding:groupsEncoding error:&error] &&
                   [outputData appendDataFromString:@"}}" encoding:encoding error:&error];
            if(NO == isOK){
                if ([error isMutable] == NO) error = [[error mutableCopy] autorelease];
                [error setValue:NSLocalizedString(@"Unable to convert script groups.", @"string encoding error context") forKey:NSLocalizedRecoverySuggestionErrorKey];
            }
        }
    }
    
    if (hasData == NO)
        [outputData setLength:0];
    else if(isOK)
        [outputData appendDataFromString:@"\n" encoding:encoding error:&error];
        
    if (NO == isOK && outError != NULL) *outError = error;

    return isOK ? outputData : nil;
        
}

- (NSData *)RISDataAndReturnError:(NSError **)error{
    NSString *RISString = [self RISStringForPublications:[self publicationsForSaving]];
    NSStringEncoding encoding = [self encodingForSaving];
    NSData *data = [RISString dataUsingEncoding:encoding allowLossyConversion:NO];
    if (nil == data && error) {
        *error = [NSError mutableLocalErrorWithCode:kBDSKStringEncodingError localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"Unable to convert the bibliography to encoding %@", @"Error description"), [NSString localizedNameOfStringEncoding:encoding]]];
        [*error setValue:[NSNumber numberWithUnsignedInteger:encoding] forKey:NSStringEncodingErrorKey];
    }
	return data;
}

- (NSData *)LTBDataAndReturnError:(NSError **)error{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];
    [pboardHelper declareType:NSStringPboardType dragCopyType:BDSKLTBDragCopyType forItems:[self publicationsForSaving] forPasteboard:pboard];
    NSString *ltbString = [pboard stringForType:NSStringPboardType];
    [pboardHelper clearPromisedTypesForPasteboard:pboard];
	if(ltbString == nil){
        if (error)
            *error = [NSError localErrorWithCode:kBDSKDocumentSaveError localizedDescription:NSLocalizedString(@"Unable to run TeX processes for these publications", @"Error description")];
		return nil;
    }
    
    NSMutableString *s = [NSMutableString stringWithString:@"\\documentclass{article}\n\\usepackage{amsrefs}\n\\begin{document}\n\n"];
	[s appendString:ltbString];
	[s appendString:@"\n\\end{document}\n"];
    
    NSStringEncoding encoding = [self encodingForSaving];
    NSData *data = [s dataUsingEncoding:encoding allowLossyConversion:NO];
    if (nil == data && error) {
        *error = [NSError mutableLocalErrorWithCode:kBDSKStringEncodingError localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"Unable to convert the bibliography to encoding %@", @"Error description"), [NSString localizedNameOfStringEncoding:encoding]]];
        [*error setValue:[NSNumber numberWithUnsignedInteger:encoding] forKey:NSStringEncodingErrorKey];
    }        
	return data;
}

- (NSData *)atomData{
    NSMutableData *d = [NSMutableData data];
    
    [d appendUTF8DataFromString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><feed xmlns=\"http://purl.org/atom/ns#\">"];
    
    // TODO: output general feed info
    
	for (BibItem *pub in [self publicationsForSaving]){
        [d appendUTF8DataFromString:@"<entry><title>foo</title><description>foo-2</description>"];
        [d appendUTF8DataFromString:@"<content type=\"application/xml+mods\">"];
        [d appendUTF8DataFromString:[pub MODSString]];
        [d appendUTF8DataFromString:@"</content>"];
        [d appendUTF8DataFromString:@"</entry>\n"];
    }
    [d appendUTF8DataFromString:@"</feed>"];
    
    return d;    
}

- (NSData *)MODSData{
    NSMutableData *d = [NSMutableData data];
    
    [d appendUTF8DataFromString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><modsCollection xmlns=\"http://www.loc.gov/mods/v3\">"];
	for (BibItem *pub in [self publicationsForSaving]){
        [d appendUTF8DataFromString:[pub MODSString]];
        [d appendUTF8DataFromString:@"\n"];
    }
    [d appendUTF8DataFromString:@"</modsCollection>"];
    
    return d;
}

- (NSData *)endNoteData{
    NSMutableData *d = [NSMutableData data];
    
    [d appendUTF8DataFromString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<xml>\n<records>\n"];
    for (BibItem *pub in [self publicationsForSaving])
        [d appendUTF8DataFromString:[pub endNoteString]];
    [d appendUTF8DataFromString:@"</records>\n</xml>\n"];
    
    return d;
}

- (NSData *)dataUsingTemplate:(BDSKTemplate *)template{
    BDSKPRECONDITION(nil != template);
    
    NSData *data = nil;
    
    if ([template scriptPath]) {
        data = [BDSKTemplateObjectProxy dataByParsingTemplate:template withObject:self publications:[self publicationsForSaving]];
    } else if ([template templateFormat] & BDSKPlainTextTemplateFormat) {
        NSString *string = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:self publications:[self publicationsForSaving]];
        
        data = [string dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    } else {
        BDSKPRECONDITION([template templateFormat] != BDSKRTFDTemplateFormat);
        
        NSDictionary *docAttributes = nil;
        NSAttributedString *attrString = [BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:self publications:[self publicationsForSaving] documentAttributes:&docAttributes];
        NSMutableDictionary *mutableAttributes = [NSMutableDictionary dictionaryWithDictionary:docAttributes];
        
        // create some useful metadata, with an option to disable for the paranoid
        if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKDisableExportAttributesKey])
            [mutableAttributes addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:NSFullUserName(), NSAuthorDocumentAttribute, [NSDate date], NSCreationTimeDocumentAttribute, [NSLocalizedString(@"BibDesk export of ", @"Error description") stringByAppendingString:[[[self fileURL] path] lastPathComponent]], NSTitleDocumentAttribute, nil]];
        [mutableAttributes setObject:[template documentType] forKey:NSDocumentTypeDocumentAttribute];
        
        data = [attrString dataFromRange:NSMakeRange(0, [attrString length]) documentAttributes:mutableAttributes error:NULL];
    }
    return data;
}

- (NSFileWrapper *)fileWrapperUsingTemplate:(BDSKTemplate *)template{
    BDSKPRECONDITION(nil != template && [template templateFormat] & BDSKRTFDTemplateFormat);
    NSDictionary *docAttributes = nil;
    NSAttributedString *fileTemplate = [BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:self publications:[self publicationsForSaving] documentAttributes:&docAttributes];
    
    return [fileTemplate RTFDFileWrapperFromRange:NSMakeRange(0,[fileTemplate length]) documentAttributes:docAttributes];
}

#pragma mark -
#pragma mark Opening and Loading Files

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)aType error:(NSError **)outError
{
    BOOL success = NO;
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:absoluteURL options:NSUncachedRead error:&error];
    if (nil == data) {
        if (outError) *outError = error;
        return NO;
    }
    
    // when using the Open panel this should be initialized to the selected encoding, otherwise the default encoding from the prefs, or for revert whatever it was
    NSStringEncoding encoding = [self documentStringEncoding];
    
    // This is only a sanity check; an encoding of 0 is not valid, so is a signal we should ignore xattrs; could only check for public.text UTIs, but it will be zero if it was never written (and we don't warn in that case).  The user can do many things to make the attribute incorrect, so this isn't very robust.
    NSStringEncoding encodingFromFile = [[self mainWindowSetupDictionaryFromExtendedAttributes] unsignedIntegerForKey:BDSKDocumentStringEncodingKey defaultValue:BDSKNoStringEncoding];
    if (encodingFromFile != BDSKNoStringEncoding && encodingFromFile != encoding) {
        
        NSInteger rv;
        
        error = [NSError mutableLocalErrorWithCode:kBDSKStringEncodingError localizedDescription:NSLocalizedString(@"Incorrect encoding", @"Message in alert dialog when opening a document with different encoding")];
        [error setValue:[NSString stringWithFormat:NSLocalizedString(@"BibDesk tried to open the document using encoding %@, but it should have been opened with encoding %@.", @"Informative text in alert dialog when opening a document with different encoding"), [NSString localizedNameOfStringEncoding:encoding], [NSString localizedNameOfStringEncoding:encodingFromFile]] forKey:NSLocalizedRecoverySuggestionErrorKey];
        [error setValue:absoluteURL forKey:NSURLErrorKey];
        [error setValue:[NSNumber numberWithUnsignedInteger:encoding] forKey:NSStringEncodingErrorKey];
        
        // If we allow the user to reopen here, NSDocumentController puts up an open failure here when we return NO from this instance, and the message appears after the successfully opened file is on-screen...which is confusing, to say the least.
        NSAlert *encodingAlert = [NSAlert alertWithMessageText:NSLocalizedString(@"Incorrect encoding", @"error title when opening file")
                                                 defaultButton:NSLocalizedString(@"Cancel", @"Button title")
                                               alternateButton:NSLocalizedString(@"Ignore", @"Button title")
                                                   otherButton:NSLocalizedString(@"Reopen", @"Button title")
                                     informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"The document will be opened with encoding %@, but it was previously saved with encoding %@.  You should cancel opening and then reopen with the correct encoding.", @"Informative text in alert dialog when opening a document with different encoding"), [NSString localizedNameOfStringEncoding:encoding], [NSString localizedNameOfStringEncoding:encodingFromFile]]];
        rv = [encodingAlert runModal];

        if (rv == NSAlertDefaultReturn) {
            // the user said to give up
            if (outError) *outError = error; 
            return NO;
        }else if (rv == NSAlertAlternateReturn){
            NSLog(@"User ignored encoding alert");
        }else if (rv == NSAlertOtherReturn){
            // we just use the encoding whach was used for saving
            encoding = encodingFromFile;
        }
    }
    
	if ([aType isEqualToString:BDSKBibTeXDocumentType]){
        success = [self readFromBibTeXData:data fromURL:absoluteURL encoding:encoding error:&error];
    }else{
		// sniff the string to see what format we got
		NSString *string = [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
        BDSKStringType type = [string contentStringType];
        if(string == nil){
            error = [NSError mutableLocalErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Unable To Open Document", @"Error description")];
            [error setValue:NSLocalizedString(@"This document does not appear to be a text file.", @"Error informative text") forKey:NSLocalizedRecoverySuggestionErrorKey];
        }else if(type == BDSKBibTeXStringType){
            success = [self readFromBibTeXData:data fromURL:absoluteURL encoding:encoding error:&error];
		}else if (type == BDSKNoKeyBibTeXStringType){
            error = [NSError mutableLocalErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Unable To Open Document", @"Error description")];
            [error setValue:NSLocalizedString(@"This file appears to contain invalid BibTeX because of missing cite keys. Try to open using temporary cite keys to fix this.", @"Error informative text") forKey:NSLocalizedRecoverySuggestionErrorKey];
		}else if (type == BDSKUnknownStringType){
            error = [NSError mutableLocalErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Unable To Open Document", @"Error description")];
            [error setValue:NSLocalizedString(@"This text file does not contain a recognized data type.", @"Error informative text") forKey:NSLocalizedRecoverySuggestionErrorKey];
        }else{
            success = [self readFromData:data ofStringType:type fromURL:absoluteURL encoding:encoding error:&error];
        }
	}
    
    if(success == NO && outError) *outError = error;
    
    return success;
}

- (void)setPublications:(NSArray *)newPubs macros:(NSDictionary *)newMacros documentInfo:(NSDictionary *)newDocumentInfo groups:(NSDictionary *)newGroups frontMatter:(NSString *)newFrontMatter encoding:(NSStringEncoding)newEncoding {
    NSEnumerator *wcEnum = [[self windowControllers] objectEnumerator];
    BOOL wasLoaded = nil != [wcEnum nextObject]; // initial read is before makeWindowControllers
    
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
        
        // we need to stop the file search controller on revert, as this will be invalid after we update our publications
        if ([self isDisplayingFileContentSearch])
            [self setSearchString:@""];
        [fileSearchController terminateForDocumentURL:[self fileURL]];
        BDSKDESTROY(fileSearchController);
        
        // first remove all editor windows, as they will be invalid afterwards
        NSWindowController *wc;
        while ((wc = [wcEnum nextObject])) {
            if ([wc respondsToSelector:@selector(discardEditing)])
                [wc discardEditing];
            [wc close];
        }
        
        // make sure we clear all groups that are saved in the file, should only have those for revert
        // better do this here, so we don't remove them when reading the data fails
        for (BDSKGroup *group in [groups URLGroups])
            [self removeSpinnerForGroup:group];
        for (BDSKGroup *group in [groups scriptGroups])
            [self removeSpinnerForGroup:group];
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
        [self setSearchString:@""];
        [self updateSmartGroupsCount];
        [self updateCategoryGroupsPreservingSelection:YES];
        [self sortGroupsByKey:nil]; // resort
		[tableView deselectAll:self]; // clear before resorting
		[self redoSearch]; // redo the search
        [self sortPubsByKey:nil]; // resort
    }
}

- (BOOL)readFromBibTeXData:(NSData *)data fromURL:(NSURL *)absoluteURL encoding:(NSStringEncoding)encoding error:(NSError **)outError {
    NSString *filePath = [absoluteURL path];
    NSStringEncoding parserEncoding = [[BDSKStringEncodingManager sharedEncodingManager] isUnparseableEncoding:encoding] ? NSUTF8StringEncoding : encoding;
    
    if(parserEncoding != encoding){
        NSString *string = [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
        if([string canBeConvertedToEncoding:NSUTF8StringEncoding]){
            data = [string dataUsingEncoding:NSUTF8StringEncoding];
            filePath = [[NSFileManager defaultManager] temporaryFileWithBasename:[filePath lastPathComponent]];
            [data writeToFile:filePath atomically:YES];
        }else{
            parserEncoding = encoding;
            NSLog(@"Unable to convert data from encoding %@ to UTF-8", [NSString localizedNameOfStringEncoding:encoding]);
        }
    }
    
    NSError *error = nil;
    BOOL isPartialData;
	NSArray *newPubs;
	NSDictionary *newMacros = nil;
	NSDictionary *newGroups = nil;
	NSDictionary *newDocumentInfo = nil;
	NSString *newFrontMatter = nil;
    
    newPubs = [BDSKBibTeXParser itemsFromData:data macros:&newMacros documentInfo:&newDocumentInfo groups:&newGroups frontMatter:&newFrontMatter filePath:filePath owner:self encoding:parserEncoding isPartialData:&isPartialData error:&error];
    
    // @@ move this to NSDocumentController; need to figure out where to add it, though
    if (isPartialData) {
        NSError *recoveryError = [NSError mutableLocalErrorWithCode:[error code] localizedDescription:[error localizedDescription] ?: NSLocalizedString(@"Error reading file!", @"Message in alert dialog when unable to read file")];
        [recoveryError setValue:NSLocalizedString(@"There was a problem reading the file.  Do you want to give up, edit the file to correct the errors, or keep going with everything that could be analyzed?\n\nIf you choose \"Keep Going\" and then save the file, you will probably lose data.", @"Informative text in alert dialog") forKey:NSLocalizedRecoverySuggestionErrorKey];
        [recoveryError setValue:[BDSKErrorObjectController sharedErrorObjectController] forKey:NSRecoveryAttempterErrorKey];
        [recoveryError setValue:[NSArray arrayWithObjects:NSLocalizedString(@"Give Up", @"Button title"), NSLocalizedString(@"Keep Going", @"Button title"), NSLocalizedString(@"Edit File", @"Button title"), nil] forKey:NSLocalizedRecoveryOptionsErrorKey];
        [recoveryError setValue:self forKey:@"failedDocument"];
        [recoveryError setValue:error forKey:NSUnderlyingErrorKey];
        
        if ([self presentError:recoveryError])
            // the user said to keep going, so if they save, they might clobber data...
            // if we don't return YES, NSDocumentController puts up its lame alert saying the document could not be opened, and we get no partial data
            isPartialData = NO;
        else if (outError)
            // return NSUserCancelledError so NSDocumentController won't show another alert
            *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:error, NSUnderlyingErrorKey, nil]];
    }
    
    if (isPartialData == NO) {
        [self setPublications:newPubs macros:newMacros documentInfo:newDocumentInfo groups:newGroups frontMatter:newFrontMatter encoding:encoding];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)readFromData:(NSData *)data ofStringType:(BDSKStringType)type fromURL:(NSURL *)absoluteURL encoding:(NSStringEncoding)encoding error:(NSError **)outError {
    
    NSError *error = nil;    
    NSString *dataString = [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
    NSArray *newPubs = nil;
    
    if(dataString == nil){
        error = [NSError mutableLocalErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Unable to Interpret", @"Error description")];
        [error setValue:[NSString stringWithFormat:NSLocalizedString(@"Unable to interpret data as %@.  Try a different encoding.", @"Error informative text"), [NSString localizedNameOfStringEncoding:encoding]] forKey:NSLocalizedRecoverySuggestionErrorKey];
        [error setValue:[NSNumber numberWithUnsignedInteger:encoding] forKey:NSStringEncodingErrorKey];
    } else {
        newPubs = [BDSKStringParser itemsFromString:dataString ofType:type error:&error];
    }
    
    if (newPubs) {
        [self setPublications:newPubs macros:nil documentInfo:nil groups:nil frontMatter:nil encoding:[self documentStringEncoding]];
        // since we can't save other files in their native format (BibTeX is handled separately)
        [self setFileURL:nil];
        return YES;
    } else {
        if (outError) *outError = error;
        return NO;
    }
}

#pragma mark -

- (void)setDocumentStringEncoding:(NSStringEncoding)encoding{
    docState.documentStringEncoding = encoding;
}

- (NSStringEncoding)documentStringEncoding{
    return docState.documentStringEncoding;
}

#pragma mark -

- (void)markAsImported {
    [self setFileURL:nil];
    // set date-added for imports
    NSString *importDate = [[NSDate date] description];
    for (BibItem *pub in publications)
        [pub setField:BDSKDateAddedString toValue:importDate];
    [[self undoManager] removeAllActions];
    // mark as dirty, since we've changed the content
    [self updateChangeCount:NSChangeDone];
}

- (void)temporaryCiteKeysAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    NSString *tmpKey = [(NSString *)contextInfo autorelease];
    if(returnCode == NSAlertDefaultReturn){
        NSArray *selItems = [self selectedPublications];
        [self selectPublications:[[self publications] allItemsForCiteKey:tmpKey]];
        [self generateCiteKeysForPublications:[self selectedPublications]];
        [self selectPublications:selItems];
    }
}

- (void)reportTemporaryCiteKeys:(NSString *)tmpKey forNewDocument:(BOOL)isNew{
    if([publications count] == 0)
        return;
    
    NSArray *tmpKeyItems = [[self publications] allItemsForCiteKey:tmpKey];
    
    if([tmpKeyItems count] == 0)
        return;
    
    if(isNew)
        [self selectPublications:tmpKeyItems];
    
    NSString *infoFormat = isNew ? NSLocalizedString(@"This document was opened using the temporary cite key \"%@\" for the selected publications.  In order to use your file with BibTeX, you must generate valid cite keys for all of these items.  Do you want me to do this now?", @"Informative text in alert dialog")
                            : NSLocalizedString(@"New items are added using the temporary cite key \"%@\".  In order to use your file with BibTeX, you must generate valid cite keys for these items.  Do you want me to do this now?", @"Informative text in alert dialog");
    
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Temporary Cite Keys", @"Message in alert dialog when opening a file with temporary cite keys") 
                                     defaultButton:NSLocalizedString(@"Generate", @"Button title") 
                                   alternateButton:NSLocalizedString(@"Don't Generate", @"Button title") 
                                       otherButton:nil
                         informativeTextWithFormat:infoFormat, tmpKey];
    if ([documentWindow attachedSheet])
        [self temporaryCiteKeysAlertDidEnd:alert returnCode:[alert runModal] contextInfo:[tmpKey retain]];
    else
        [alert beginSheetModalForWindow:documentWindow
                          modalDelegate:self
                         didEndSelector:@selector(temporaryCiteKeysAlertDidEnd:returnCode:contextInfo:)
                            contextInfo:[tmpKey retain]];
}

#pragma mark -
#pragma mark String representations

- (NSString *)bibTeXStringForPublications:(NSArray *)items{
	return [self bibTeXStringDroppingInternal:NO forPublications:items];
}

- (NSString *)bibTeXStringDroppingInternal:(BOOL)drop forPublications:(NSArray *)items{
    NSMutableString *s = [NSMutableString string];
	NSInteger options = 0;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldTeXifyWhenSavingAndCopyingKey])
        options |= BDSKBibTeXOptionTeXifyMask;
    if (drop)
        options |= BDSKBibTeXOptionDropInternalMask;
    
    for (BibItem *pub in items)
        [s appendStrings:@"\n", [pub bibTeXStringWithOptions:options], @"\n", nil];
	
	return s;
}

- (NSString *)previewBibTeXStringForPublications:(NSArray *)items{
    
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);

	NSUInteger numberOfPubs = [items count];
	NSMutableString *bibString = [[NSMutableString alloc] initWithCapacity:(numberOfPubs * 100)];
    
    NSInteger options = BDSKBibTeXOptionDropLinkedURLsMask;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldTeXifyWhenSavingAndCopyingKey])
        options |= BDSKBibTeXOptionTeXifyMask;
    
	// in case there are @preambles in it
	if (frontMatter) {
        [bibString appendString:frontMatter];
        [bibString appendString:@"\n"];
	}
    
    [bibString appendString:[[BDSKMacroResolver defaultMacroResolver] bibTeXString]];
    [bibString appendString:[[self macroResolver] bibTeXString]];
	
	BibItem *aPub = nil;
	BibItem *aParent = nil;
	NSMutableArray *selItems = [[NSMutableArray alloc] initWithCapacity:numberOfPubs];
	NSMutableSet *parentItems = [[NSMutableSet alloc] initWithCapacity:numberOfPubs];
	NSMutableArray *selParentItems = [[NSMutableArray alloc] initWithCapacity:numberOfPubs];
    
	for (aPub in items) {
		[selItems addObject:aPub];

		if(aParent = [aPub crossrefParent])
			[parentItems addObject:aParent];
	}
	
	for (aPub in selItems) {
		if([parentItems containsObject:aPub]){
			[parentItems removeObject:aPub];
			[selParentItems addObject:aPub];
		}else{
            [bibString appendString:[aPub bibTeXStringWithOptions:options]];
		}
	}
	
	for (aPub in selParentItems) {
        [bibString appendString:[aPub bibTeXStringWithOptions:options]];
	}
	
	for (aPub in parentItems) {
        [bibString appendString:[aPub bibTeXStringWithOptions:options]];
	}
					
	[selItems release];
	[parentItems release];
	[selParentItems release];
	
	return [bibString autorelease];
}

- (NSString *)RISStringForPublications:(NSArray *)items{
    return [[items valueForKey:@"RISStringValue"] componentsJoinedByString:@"\n\n"];
}

- (NSString *)citeStringForPublications:(NSArray *)items citeString:(NSString *)citeString{
	NSUserDefaults*sud = [NSUserDefaults standardUserDefaults];
    
    if (citeString == nil)
        citeString = [sud stringForKey:BDSKCiteStringKey];
    
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    
    NSString *startBracket = [sud stringForKey:BDSKCiteStartBracketKey];
	NSString *startCite = [NSString stringWithFormat:@"%@\\%@%@", ([sud boolForKey:BDSKCitePrependTildeKey] ? @"~" : @""), citeString, startBracket]; 
	NSString *endCite = [sud stringForKey:BDSKCiteEndBracketKey]; 
	NSInteger separateCite = [sud integerForKey:BDSKSeparateCiteKey];
    NSString *separator = separateCite == 1 ? [endCite stringByAppendingString:startCite] : separateCite == 2 ? [endCite stringByAppendingString:startBracket] : @",";
    
    return [NSString stringWithFormat:@"%@%@%@", startCite, [[items valueForKey:@"citeKey"] componentsJoinedByString:separator], endCite];
}

#pragma mark -
#pragma mark New publications from pasteboard

- (NSArray *)publicationsForFiles:(NSArray *)filenames {
    NSMutableArray *newPubs = [NSMutableArray arrayWithCapacity:[filenames count]];
	NSURL *url = nil;
    	
	for (NSString *fnStr in filenames) {
        fnStr = [fnStr stringByStandardizingPath];
		if(url = [NSURL fileURLWithPath:fnStr]){
            NSError *xerror = nil;
            BibItem *newBI = nil;
            
            // most reliable metadata should be our private EA
            if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKReadExtendedAttributesKey]){
                NSData *btData = [[SKNExtendedAttributeManager sharedNoSplitManager] extendedAttributeNamed:BDSK_BUNDLE_IDENTIFIER @".bibtexstring" atPath:fnStr traverseLink:NO error:&xerror];
                if(btData){
                    NSString *btString = [[NSString alloc] initWithData:btData encoding:NSUTF8StringEncoding];
                    BOOL isPartialData;
                    NSArray *items = [BDSKBibTeXParser itemsFromString:btString owner:self isPartialData:&isPartialData error:&xerror];
                    newBI = isPartialData ? nil : [items firstObject];
                    [btString release];
                }
            }
            
			// GJ try parsing pdf to extract info that is then used to get a PubMed record
			if(newBI == nil && [[[NSWorkspace sharedWorkspace] typeOfFile:[[fnStr stringByStandardizingPath] stringByResolvingSymlinksInPath] error:NULL] isEqualToUTI:(NSString *)kUTTypePDF]){
                if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldParsePDFToGeneratePubMedSearchTermKey])
                    newBI = [BibItem itemByParsingPDFFile:fnStr];			
                // fall back on the least reliable metadata source (hidden pref)
                if(newBI == nil && [[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldUsePDFMetadataKey])
                    newBI = [BibItem itemWithPDFMetadataFromURL:url];
			}
            if(newBI == nil)
                newBI = [[[BibItem alloc] init] autorelease];
            
            [newBI addFileForURL:url autoFile:NO runScriptHook:NO];
			[newPubs addObject:newBI];
		}
	}
	
	return newPubs;
}

- (NSArray *)publicationsForURL:(NSURL *)aURL title:(NSString *)aTitle {
    NSDictionary *pubFields = [NSDictionary dictionaryWithObjectsAndKeys:[[NSDate date] dateDescription], @"Lastchecked", aTitle, BDSKTitleString, nil];
    NSArray *files = [NSArray arrayWithObjects:[BDSKLinkedFile linkedFileWithURL:aURL delegate:nil], nil];
    BibItem *newBI = [[BibItem alloc] initWithType:@"webpage" citeKey:nil pubFields:pubFields files:files isNew:YES];
    NSArray *pubs = [NSArray arrayWithObject:newBI];
    [newBI release];
    
	return pubs;
}

// sniff the contents of each file, returning them in an array of BibItems, while unparseable files are added to the mutable array passed as a parameter
- (NSArray *)extractPublicationsFromFiles:(NSArray *)filenames unparseableFiles:(NSArray **)unparseableFiles verbose:(BOOL)verbose error:(NSError **)outError {
    NSMutableArray *array = [NSMutableArray array];
    NSMutableArray *unparseableFilesArray = nil;
    BDSKStringType type = BDSKUnknownStringType;
    
    // some common types that people might use as attachments; we don't need to sniff these
    NSSet *unreadableTypes = [NSSet setForCaseInsensitiveStringsWithObjects:@"pdf", @"ps", @"eps", @"doc", @"htm", @"textClipping", @"webloc", @"html", @"rtf", @"tiff", @"tif", @"png", @"jpg", @"jpeg", nil];
    
    for (NSString *fileName in filenames) {
        type = BDSKUnknownStringType;
        
        // we /can/ create a string from these (usually), but there's no point in wasting the memory
        
        NSString *theUTI = [[NSWorkspace sharedWorkspace] typeOfFile:[[fileName stringByStandardizingPath] stringByResolvingSymlinksInPath] error:NULL];
        if ([theUTI isEqualToUTI:@"net.sourceforge.bibdesk.bdsksearch"]) {
            NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:fileName];
            Class aClass = NSClassFromString([dictionary objectForKey:@"class"]);
            BDSKSearchGroup *group = [[[(aClass ?: [BDSKSearchGroup class]) alloc] initWithDictionary:dictionary] autorelease];
            if(group)
                [groups addSearchGroup:group];
        } else {
            NSError *parseError = nil;
            BOOL isPartialData = NO;
            NSArray *contentArray = nil;
            
            if ([unreadableTypes containsObject:[fileName pathExtension]] == NO) {
        
                // try to create a string
                NSString *contentString = [[NSString alloc] initWithContentsOfFile:fileName guessedEncoding:[self documentStringEncoding]];
                
                if (contentString != nil) {
                    if ([theUTI isEqualToUTI:@"org.tug.tex.bibtex"])
                        type = BDSKBibTeXStringType;
                    else if([theUTI isEqualToUTI:@"net.sourceforge.bibdesk.ris"])
                        type = BDSKRISStringType;
                    else
                        type = [contentString contentStringType];
                    
                    if (type != BDSKUnknownStringType) {
                        contentArray = [BDSKStringParser itemsFromString:contentString ofType:type owner:self isPartialData:&isPartialData error:&parseError];
                        
                        if (isPartialData) {
                            if ([parseError isLocalErrorWithCode:kBDSKParserIgnoredFrontMatter]) {
                                if (verbose) [self presentError:parseError];
                                parseError = nil;
                            } else if([parseError isLocalErrorWithCode:kBDSKBibTeXParserFailed]) {
                                if (verbose == NO || [self presentError:parseError] == NO)
                                    contentArray = nil;
                            }
                        }
                    }
                    
                    [contentString release];
                }
            }
            if (contentArray) {
                // forward any temporaryCiteKey warning
                if (parseError && outError) *outError = parseError;
                [array addObjectsFromArray:contentArray];
            } else if (unparseableFiles) {
                // unable to parse or find valid type, we link the file and can ignore the error
                if (unparseableFilesArray == nil)
                    unparseableFilesArray = [NSMutableArray array];
                [unparseableFilesArray addObject:fileName];
            }
        }
    }
    
    if (unparseableFiles)
        *unparseableFiles = unparseableFilesArray;
    
    return array;
}

- (void)addPublications:(NSArray *)newPubs publicationsToAutoFile:(NSArray *)pubsToAutoFile temporaryCiteKey:(NSString *)tmpCiteKey selectLibrary:(BOOL)shouldSelect edit:(BOOL)shouldEdit {
    BibItem *pub;
    
    if (shouldSelect)
        [self selectLibraryGroup:nil];    
	[self addPublications:newPubs];
    if ([self hasLibraryGroupSelected])
        [self selectPublications:newPubs];
    
    BOOL autoGenerate = [[NSUserDefaults standardUserDefaults] boolForKey:BDSKCiteKeyAutogenerateKey];
    NSMutableArray *autogeneratePubs = [NSMutableArray arrayWithCapacity:[newPubs count]];
    BOOL hasDuplicateCiteKey = NO;
    
    for (pub in newPubs) {
        if ((autoGenerate == NO && [pub hasEmptyOrDefaultCiteKey]) ||
            (autoGenerate && [pub canGenerateAndSetCiteKey])) { // @@ or should we check for hasEmptyOrDefaultCiteKey ?
            [autogeneratePubs addObject:pub];
        } else if ([pub isValidCiteKey:[pub citeKey]] == NO) {
            hasDuplicateCiteKey = YES;
        }
    }
    [self generateCiteKeysForPublications:autogeneratePubs];
    
    for (pub in pubsToAutoFile) {
        for (BDSKLinkedFile *file in [pub localFiles])
            [pub autoFileLinkedFile:file];
    }
    
    // set Date-Added to the current date, since unarchived items will have their own (incorrect) date
    NSString *importDate = [[NSDate date] description];
    for (pub in newPubs)
        [pub setField:BDSKDateAddedString toValue:importDate];
	
	if(shouldEdit)
		[self editPublications:newPubs]; // this will ask the user when there are many pubs
	
	[[self undoManager] setActionName:NSLocalizedString(@"Add Publication", @"Undo action name")];
    
    NSMutableArray *importedItems = [NSMutableArray array];
    if (shouldSelect == NO && docFlags.didImport)
        [importedItems addObjectsFromArray:[[groups lastImportGroup] publications]];
    docFlags.didImport = (shouldSelect == NO);
    [importedItems addObjectsFromArray:newPubs];
    
    // set up the smart group that shows the latest import
    // @@ do this for items added via the editor?  doesn't seem as useful
    [groups setLastImportedPublications:importedItems];

	[[BDSKScriptHookManager sharedManager] runScriptHookWithName:BDSKImportPublicationsScriptHookName forPublications:newPubs document:self];
    
    if (tmpCiteKey != nil) {
        [self reportTemporaryCiteKeys:tmpCiteKey forNewDocument:NO];
    } else if (hasDuplicateCiteKey) { // should we do this when we don't edit?
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Duplicate Cite Key", @"Message in alert dialog when duplicate citye key was found") 
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"One or more items you added have a cite key which is either already used in this document. You should provide a unique one.", @"Informative text in alert dialog")];
        // don't begin a sheet, because the edit command may have one put up already
        [alert runModal];
    }
}

- (NSArray *)addPublicationsFromPasteboard:(NSPasteboard *)pb selectLibrary:(BOOL)shouldSelect verbose:(BOOL)verbose error:(NSError **)outError{
	// these are the types we support, the order here is important!
    NSString *type = [pb availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, BDSKWeblocFilePboardType, BDSKReferenceMinerStringPboardType, NSStringPboardType, NSFilenamesPboardType, NSURLPboardType, nil]];
    NSArray *newPubs = nil;
    NSArray *newFilePubs = nil;
    NSArray *newFiles = nil;
    NSURL *newURL = nil;
	NSError *error = nil;
    BOOL isPartialData = NO;
    NSString *temporaryCiteKey = nil;
    BOOL shouldEdit = [[NSUserDefaults standardUserDefaults] boolForKey:BDSKEditOnPasteKey];
    
    if([type isEqualToString:BDSKBibItemPboardType]){
        NSData *pbData = [pb dataForType:BDSKBibItemPboardType];
		newPubs = [BibItem publicationsFromArchivedData:pbData macroResolver:[self macroResolver]];
    }else if([type isEqualToString:BDSKReferenceMinerStringPboardType]){
        NSString *pbString = [pb stringForType:NSStringPboardType]; 	
        // sniffing the string for RIS is broken because RefMiner puts junk at the beginning
		newPubs = [BDSKStringParser itemsFromString:pbString ofType:BDSKReferenceMinerStringType owner:self isPartialData:&isPartialData error:&error];
    }else if([type isEqualToString:NSStringPboardType]){
        NSString *pbString = [pb stringForType:NSStringPboardType]; 	
        // sniff the string to see what its type is
		newPubs = [BDSKStringParser itemsFromString:pbString ofType:BDSKUnknownStringType owner:self isPartialData:&isPartialData error:&error];
    }else if([type isEqualToString:NSFilenamesPboardType]){
		NSArray *pbArray = [pb propertyListForType:NSFilenamesPboardType]; // we will get an array
        // try this first, in case these files are a type we can open
        newPubs = [self extractPublicationsFromFiles:pbArray unparseableFiles:&newFiles verbose:verbose error:&error];
    }else if([type isEqualToString:BDSKWeblocFilePboardType]){
        newURL = [NSURL URLWithString:[pb stringForType:BDSKWeblocFilePboardType]]; 	
    }else if([type isEqualToString:NSURLPboardType]){
        newURL = [NSURL URLFromPasteboard:pb]; 	
	}else{
        // errors are key, value
        error = [NSError localErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Did not find anything appropriate on the pasteboard", @"Error description")];
	}
    
    if(newURL){
		if([newURL isFileURL])
            newFiles = [NSArray arrayWithObject:[newURL path]];
        else
            newPubs = [self publicationsForURL:newURL title:[WebView URLTitleFromPasteboard:pb]];
    }
    if([newFiles count]){
        newFilePubs = [self publicationsForFiles:newFiles];
        newPubs = newPubs ? [newPubs arrayByAddingObjectsFromArray:newFilePubs]: newFilePubs;
    }
    
    if([error isLocalErrorWithCode:kBDSKHadMissingCiteKeys]) {
        temporaryCiteKey = [[error userInfo] objectForKey:@"temporaryCiteKey"];
        error = nil; // accept temporary cite keys, but show a warning later
    }else if([error isLocalErrorWithCode:kBDSKParserIgnoredFrontMatter]){
        // just warn about this error when verbose, don't treat this as an error further
        if (verbose)
            [self presentError:error];
        error = nil;
    }else if([error isLocalErrorWithCode:kBDSKBibTeXParserFailed]){
        // this asks whether to ignore partially failed bibtex when verbose, otherwise just ignore, for NSFilenamesPboardType this was already handled
        if(isPartialData && (verbose == NO || [self presentError:error] == NO))
            newPubs = nil;
    }else if(error && verbose){
        // display error for non-bibtex string parsers when verbose
        [self presentError:error];
    }
    
    if([newPubs count] > 0)
		[self addPublications:newPubs publicationsToAutoFile:newFilePubs temporaryCiteKey:temporaryCiteKey selectLibrary:shouldSelect edit:shouldEdit];
    else if (newPubs == nil && outError)
        *outError = error;
    
    return newPubs;
}

#pragma mark -
#pragma mark BDSKItemPasteboardHelper delegate

- (void)pasteboardHelperWillBeginGenerating:(BDSKItemPasteboardHelper *)helper{
	[self setStatus:[NSLocalizedString(@"Generating data. Please wait", @"Status message when generating drag/paste data") stringByAppendingEllipsis]];
    [statusBar setProgressIndicatorStyle:BDSKProgressIndicatorSpinningStyle];
	[statusBar startAnimation:nil];
}

- (void)pasteboardHelperDidEndGenerating:(BDSKItemPasteboardHelper *)helper{
	[statusBar stopAnimation:nil];
    [statusBar setProgressIndicatorStyle:BDSKProgressIndicatorNone];
	[self updateStatus];
}

- (NSString *)pasteboardHelper:(BDSKItemPasteboardHelper *)pboardHelper bibTeXStringForItems:(NSArray *)items{
    return [self previewBibTeXStringForPublications:items];
}

#pragma mark -
#pragma mark Sorting

- (void)sortPubsByKey:(NSString *)key{
    if (key == nil && sortKey == nil)
        return;
    
    BOOL shouldSave = NO;
    
    if (key == nil) {
        // a nil argument means resort the current column in the same order
    } else if ([key isEqualToString:BDSKImportOrderString] == NO && [key isEqualToString:BDSKRelevanceString] == NO) {
        if ([sortKey isEqualToString:key] == NO) {
            [previousSortKey release];
            previousSortKey = [sortKey retain];
            docFlags.previousSortDescending = docFlags.sortDescending;
            [sortKey release];
            sortKey = [key retain];
            docFlags.sortDescending = NO;
            shouldSave = YES;
        } else if (tmpSortKey == nil) {
            // User clicked same column, change sort order, 
            // however if tmpSortKey was set this is probably after removing an ImportOrder or Relevance column, and we should reinstate the previous sort order
            docFlags.sortDescending = !docFlags.sortDescending;
            shouldSave = YES;
        }
        BDSKDESTROY(tmpSortKey);
    } else if ([tmpSortKey isEqualToString:key]) {
        // User clicked same column, change sort order
        docFlags.tmpSortDescending = !docFlags.tmpSortDescending;
    } else {
        [tmpSortKey release];
        tmpSortKey = [key retain];
        docFlags.tmpSortDescending = [key isEqualToString:BDSKRelevanceString];
    }
    
    if (previousSortKey == nil) {
        previousSortKey = [sortKey retain];
        docFlags.previousSortDescending = docFlags.sortDescending;
    }
    
    if (shouldSave) {
        NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
        [sud setObject:sortKey forKey:BDSKDefaultSortedTableColumnKey];
        [sud setBool:docFlags.sortDescending forKey:BDSKDefaultSortedTableColumnIsDescendingKey];
        [sud setObject:previousSortKey forKey:BDSKDefaultSubsortedTableColumnKey];
        [sud setBool:docFlags.previousSortDescending forKey:BDSKDefaultSubsortedTableColumnIsDescendingKey];
    }
    
    NSMutableArray *sortDescriptors = [NSMutableArray arrayWithObjects:
        [BDSKTableSortDescriptor tableSortDescriptorForIdentifier:sortKey ascending:!docFlags.sortDescending], 
        [BDSKTableSortDescriptor tableSortDescriptorForIdentifier:previousSortKey ascending:!docFlags.previousSortDescending], nil];
    
    // Set the graphic for the new column header
    NSTableColumn *oldTC = [tableView highlightedTableColumn];
    NSTableColumn *newTC;
    BOOL ascending;
    if (tmpSortKey) {
        newTC = [tableView tableColumnWithIdentifier:tmpSortKey];
        ascending = !docFlags.tmpSortDescending;
        [sortDescriptors insertObject:[BDSKTableSortDescriptor tableSortDescriptorForIdentifier:tmpSortKey ascending:!docFlags.tmpSortDescending] atIndex:0];
    } else {
        newTC = [tableView tableColumnWithIdentifier:sortKey];
        ascending = !docFlags.sortDescending;
    }
    if ([oldTC isEqual:newTC] == NO) {
        [tableView setHighlightedTableColumn:newTC];
        if (oldTC)
            [tableView setIndicatorImage:nil inTableColumn:oldTC];
    }
    [tableView setIndicatorImageForAscending:ascending inTableColumn:newTC];
    
    // @@ DON'T RETURN WITHOUT RESETTING THIS!
    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    docFlags.ignoreSelectionChange = YES;
    
    // cache the selection; this works for multiple publications
    NSArray *pubsToSelect = nil;
    if ([tableView numberOfSelectedRows])
        pubsToSelect = [shownPublications objectsAtIndexes:[tableView selectedRowIndexes]];
    
    // sort by new primary column, subsort with previous primary column
    [shownPublications mergeSortUsingDescriptors:sortDescriptors];
    
    // have to reload so the rows get set up right, but a full updateStatus flashes the preview, which is annoying (and the preview won't change if we're maintaining the selection)
    [tableView reloadData];
    
    // fix the selection
    [self selectPublications:pubsToSelect];
    [tableView scrollRowToCenter:[tableView selectedRow]]; // just go to the last one
    
    // reset
    docFlags.ignoreSelectionChange = NO;
}

#pragma mark -
#pragma mark Selection

- (NSInteger)numberOfSelectedPubs{
    if ([self isDisplayingFileContentSearch])
        return [[fileSearchController selectedIdentifierURLs] count];
    else
        return [tableView numberOfSelectedRows];
}

- (NSArray *)selectedPublications{
    NSArray *selPubs = nil;
    if ([self isDisplayingFileContentSearch]) {
        if ([[fileSearchController tableView] numberOfSelectedRows])
            selPubs =  [publications itemsForIdentifierURLs:[fileSearchController selectedIdentifierURLs]];
    } else if ([tableView numberOfSelectedRows]) {
        selPubs = [shownPublications objectsAtIndexes:[tableView selectedRowIndexes]];
    }
    return selPubs;
}

- (NSInteger)numberOfClickedOrSelectedPubs{
    if ([self isDisplayingFileContentSearch])
        return [[fileSearchController clickedOrSelectedIdentifierURLs] count];
    else
        return [tableView numberOfClickedOrSelectedRows];
}

- (NSArray *)clickedOrSelectedPublications{
    NSArray *selPubs = nil;
    if ([self isDisplayingFileContentSearch]) {
        if ([[fileSearchController tableView] numberOfClickedOrSelectedRows])
            selPubs =  [publications itemsForIdentifierURLs:[fileSearchController clickedOrSelectedIdentifierURLs]];
    } else if ([tableView numberOfClickedOrSelectedRows]) {
        selPubs = [shownPublications objectsAtIndexes:[tableView clickedOrSelectedRowIndexes]];
    }
    return selPubs;
}

- (BOOL)selectItemsForCiteKeys:(NSArray *)citeKeys selectLibrary:(BOOL)flag {

    // make sure we can see the publication, if it's still in the document
    if (flag)
        [self selectLibraryGroup:nil];
    [tableView deselectAll:self];
    [self setSearchString:@""];

    NSMutableArray *itemsToSelect = [NSMutableArray array];
    for (NSString *key in citeKeys) {
        BibItem *anItem = [publications itemForCiteKey:key];
        if (anItem)
            [itemsToSelect addObject:anItem];
    }
    [self selectPublications:itemsToSelect];
    return [itemsToSelect count] > 0;
}

- (BOOL)selectItemForPartialItem:(NSDictionary *)partialItem{
        
    NSString *itemKey = [partialItem objectForKey:@"net_sourceforge_bibdesk_citekey"] ?: [partialItem objectForKey:BDSKCiteKeyString];
    
    BOOL matchFound = NO;

    if(itemKey != nil)
        matchFound = [self selectItemsForCiteKeys:[NSArray arrayWithObject:itemKey] selectLibrary:YES];
    
    return matchFound;
}

- (void)selectPublication:(BibItem *)bib{
	[self selectPublications:[NSArray arrayWithObject:bib]];
}

- (void)selectPublications:(NSArray *)bibArray{
    
	NSIndexSet *indexes = [shownPublications indexesOfObjectsIdenticalTo:bibArray];
    
    [tableView selectRowIndexes:indexes byExtendingSelection:NO];
    if([indexes count])
        [tableView scrollRowToCenter:[indexes firstIndex]];
}

- (NSArray *)selectedFileURLs {
    if ([self isDisplayingFileContentSearch])
        return [fileSearchController selectedURLs];
    else
        return [[self selectedPublications] valueForKeyPath:@"@unionOfArrays.localFiles.URL"];
}

- (NSArray *)clickedOrSelectedFileURLs {
    if ([self isDisplayingFileContentSearch])
        return [fileSearchController clickedOrSelectedURLs];
    else
        return [[self clickedOrSelectedPublications] valueForKeyPath:@"@unionOfArrays.localFiles.URL"];
}

#pragma mark -
#pragma mark Printing support

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
    NSString *string = [self bibTeXStringForPublications:[self publications]];
    NSAttributedString *attrString = [[[NSAttributedString alloc] initWithString:string attributeName:NSFontAttributeName attributeValue:[NSFont userFontOfSize:0.0]] autorelease];
    return [NSPrintOperation printOperationWithAttributedString:attrString printInfo:[self printInfo] settings:printSettings];
}

#pragma mark -
#pragma mark Auto handling of changes

- (NSInteger)userChangedField:(NSString *)fieldName ofPublications:(NSArray *)pubs from:(NSArray *)oldValues to:(NSArray *)newValues{
    NSInteger rv = 0;
    
    NSMutableArray *generateKeyPubs = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSMutableArray *autofileFiles = [NSMutableArray arrayWithCapacity:[pubs count]];
    
    for (BibItem *pub in pubs) {
        
        // ??? will this ever happen?
        if ([[self editorForPublication:pub create:NO] commitEditing] == NO)
            continue;
        
        // generate cite key if we have enough information
        if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKCiteKeyAutogenerateKey] && [pub canGenerateAndSetCiteKey])
            [generateKeyPubs addObject:pub];
        
        // autofile paper if we have enough information
        if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKFilePapersAutomaticallyKey]){
            for (BDSKLinkedFile *file in [pub localFiles])
                if ([[pub filesToBeFiled] containsObject:file] && [pub canSetURLForLinkedFile:file])
                    [autofileFiles addObject:file];
        }
	}
    
    if([generateKeyPubs count]){
        [self generateCiteKeysForPublications:generateKeyPubs];
        rv |= 1;
    }
    if([autofileFiles count]){
        [[BDSKFiler sharedFiler] autoFileLinkedFiles:autofileFiles fromDocument:self check:NO];
        rv |= 2;
    }
    
	[[BDSKScriptHookManager sharedManager] runScriptHookWithName:BDSKChangeFieldScriptHookName
        forPublications:pubs document:self field:fieldName oldValues:oldValues newValues:newValues];
    
    return rv;
}

- (void)userAddedURL:(NSURL *)aURL forPublication:(BibItem *)pub {
	BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
    if ([aURL isFileURL] == NO && [NSString isEmptyString:[pub valueOfField:BDSKUrlString]] && [[pub remoteURLs] count] == 1 && 
        ([[typeMan requiredFieldsForType:[pub pubType]] containsObject:BDSKUrlString] || [[typeMan optionalFieldsForType:[pub pubType]] containsObject:BDSKUrlString])) {
        [pub setField:BDSKUrlString toValue:[aURL absoluteString]];
    }
    
    [[BDSKScriptHookManager sharedManager] runScriptHookWithName:BDSKAddFileScriptHookName
        forPublications:[NSArray arrayWithObjects:pub, nil] document:self 
        field:[aURL isFileURL] ? BDSKLocalFileString : BDSKRemoteURLString 
        oldValues:[NSArray array] newValues:[NSArray arrayWithObjects:[aURL isFileURL] ? [aURL path] : [aURL absoluteString], nil]];
}

- (void)userRemovedURL:(NSURL *)aURL forPublication:(BibItem *)pub {
	[[BDSKScriptHookManager sharedManager] runScriptHookWithName:BDSKRemoveFileScriptHookName
        forPublications:[NSArray arrayWithObjects:pub, nil] document:self 
        field:([aURL isEqual:[NSNull null]] || [aURL isFileURL]) ? BDSKLocalFileString : BDSKRemoteURLString 
        oldValues:[NSArray arrayWithObjects:[aURL isEqual:[NSNull null]] ? (id)aURL : [aURL isFileURL] ? [aURL path] : [aURL absoluteString], nil] newValues:[NSArray array]];
}

- (void)setFileURL:(NSURL *)absoluteURL{ 
    [super setFileURL:absoluteURL];
    if (absoluteURL)
        [[publications valueForKeyPath:@"@unionOfArrays.files"]  makeObjectsPerformSelector:@selector(update)];
    [self updateFileViews];
    [self updatePreviews];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocumentFileURLDidChangeNotification object:self];
}

// avoid warning for BDSKOwner protocol conformance
- (NSURL *)fileURL {
    return [super fileURL];
}

- (BOOL)isDocument{
    return YES;
}

@end

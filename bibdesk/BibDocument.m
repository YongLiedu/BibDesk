//  BibDocument.m

//  Created by Michael McCracken on Mon Dec 17 2001.
/*
 This software is Copyright (c) 2001-2009
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
#import "BibDocument_Actions.h"
#import "BibDocumentView_Toolbar.h"
#import "BDSKAppController.h"
#import "BDSKStringConstants.h"
#import "BDSKGroup.h"
#import "BDSKStaticGroup.h"
#import "BDSKSearchGroup.h"
#import "BDSKPublicationsArray.h"
#import "BDSKGroupsArray.h"
#import "BDSKApplication.h"

#import "BDSKUndoManager.h"
#import "BDSKPrintableView.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKStringEncodingManager.h"
#import "BDSKHeaderPopUpButtonCell.h"
#import "BDSKGroupCell.h"
#import "BDSKScriptHookManager.h"
#import "BDSKCountedSet.h"
#import "BDSKFilterController.h"
#import "BibDocument_Groups.h"
#import "BibDocument_Search.h"
#import "BDSKTableSortDescriptor.h"
#import "BDSKAlert.h"
#import "BDSKFieldSheetController.h"
#import "BDSKPreviewer.h"
#import "BDSKTeXTask.h"
#import "BDSKOverlay.h"
#import "BDSKEditor.h"

#import "BDSKItemPasteboardHelper.h"
#import "BDSKMainTableView.h"
#import "BDSKConverter.h"
#import "BDSKBibTeXParser.h"
#import "BDSKStringParser.h"

#import <ApplicationServices/ApplicationServices.h>
#import "BDSKImagePopUpButton.h"
#import "BDSKRatingButton.h"
#import "BDSKGradientSplitView.h"
#import "BDSKCollapsibleView.h"
#import "BDSKZoomablePDFView.h"
#import "BDSKZoomableTextView.h"

#import "BDSKMacroResolver.h"
#import "BDSKErrorObjectController.h"
#import "BDSKGroupTableView.h"
#import "BDSKFileContentSearchController.h"
#import "NSString_BDSKExtensions.h"
#import "BDSKStatusBar.h"
#import "NSArray_BDSKExtensions.h"
#import "NSTextView_BDSKExtensions.h"
#import "NSTableView_BDSKExtensions.h"
#import "NSDictionary_BDSKExtensions.h"
#import "NSSet_BDSKExtensions.h"
#import "PDFMetadata.h"
#import "BDSKSharingServer.h"
#import "BDSKSharingBrowser.h"
#import "BDSKTemplate.h"
#import "BDSKGroupTableView.h"
#import "BDSKFileContentSearchController.h"
#import "BDSKTemplateParser.h"
#import "BDSKTemplateObjectProxy.h"
#import "NSMenu_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "NSData_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import "BDSKColoredBox.h"
#import "BDSKCustomCiteDrawerController.h"
#import "NSObject_BDSKExtensions.h"
#import "BDSKDocumentController.h"
#import "BDSKFiler.h"
#import "BibItem_PubMedLookup.h"
#import "BDSKItemSearchIndexes.h"
#import "PDFDocument_BDSKExtensions.h"
#import <FileView/FileView.h>
#import "BDSKLinkedFile.h"
#import "NSDate_BDSKExtensions.h"
#import "BDSKFileMigrationController.h"
#import "NSViewAnimation_BDSKExtensions.h"
#import "BDSKDocumentSearch.h"
#import "NSImage_BDSKExtensions.h"
#import <SkimNotes/SkimNotes.h>
#import "NSWorkspace_BDSKExtensions.h"
#import "NSView_BDSKExtensions.h"
#import "BDSKMessageQueue.h"

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
NSString *BDSKBibItemPboardType = @"edu.ucsd.mmccrack.bibdesk BibItem pboard type";
NSString *BDSKWeblocFilePboardType = @"CorePasteboardFlavorType 0x75726C20";

// private keys used for storing window information in xattrs
static NSString *BDSKMainWindowExtendedAttributeKey = @"net.sourceforge.bibdesk.BDSKDocumentWindowAttributes";
static NSString *BDSKGroupSplitViewFractionKey = @"BDSKGroupSplitViewFractionKey";
static NSString *BDSKMainTableSplitViewFractionKey = @"BDSKMainTableSplitViewFractionKey";
static NSString *BDSKDocumentWindowFrameKey = @"BDSKDocumentWindowFrameKey";
static NSString *BDSKSelectedPublicationsKey = @"BDSKSelectedPublicationsKey";
static NSString *BDSKDocumentStringEncodingKey = @"BDSKDocumentStringEncodingKey";
static NSString *BDSKDocumentScrollPercentageKey = @"BDSKDocumentScrollPercentageKey";
static NSString *BDSKSelectedGroupsKey = @"BDSKSelectedGroupsKey";

static NSString *BDSKDocumentFileViewObservationContext = @"BDSKDocumentFileViewObservationContext";
static NSString *BDSKDocumentDefaultsObservationContext = @"BDSKDocumentDefaultsObservationContext";

enum {
    BDSKItemChangedGroupFieldMask = 1,
    BDSKItemChangedSearchKeyMask = 2,
    BDSKItemChangedSortKeyMask = 4,
    BDSKItemChangedFilesMask = 8
};

@interface BDSKFileViewObject : NSObject {
    NSURL *URL;
    NSString *string;
}
- (id)initWithURL:(NSURL *)aURL string:(NSString *)aString;
- (NSURL *)URL;
- (NSString *)string;
@end

@implementation BDSKFileViewObject

- (id)initWithURL:(NSURL *)aURL string:(NSString *)aString {
    if (self = [super init]) {
        URL = [aURL copy];
        string = [aString copy];
    }
    return self;
}

- (void)dealloc {
    [URL release];
    [string release];
    [super dealloc];
}

- (NSURL *)URL { return URL; }

- (NSString *)string { return string; }

@end


@interface NSFileWrapper (BDSKExtensions)
- (NSFileWrapper *)addFileWrapperWithPath:(NSString *)path relativeTo:(NSString *)basePath recursive:(BOOL)recursive;
@end

@interface NSDocument (BDSKPrivateExtensions)
// declare a private NSDocument method so we can override it
- (void)changeSaveType:(id)sender;
@end

@implementation BibDocument

+ (void)initialize {
    BDSKINITIALIZE;
    
    [NSImage makePreviewDisplayImages];
}

- (id)init{
    if(self = [super init]){
        
        publications = [[BDSKPublicationsArray alloc] initWithCapacity:1];
        shownPublications = [[NSMutableArray alloc] initWithCapacity:1];
        groupedPublications = [[NSMutableArray alloc] initWithCapacity:1];
        groups = [(BDSKGroupsArray *)[BDSKGroupsArray alloc] initWithDocument:self];
        
        frontMatter = [[NSMutableString alloc] initWithString:@""];
        documentInfo = [[NSMutableDictionary alloc] initForCaseInsensitiveKeys];
        macroResolver = [[BDSKMacroResolver alloc] initWithOwner:self];
        
        BDSKUndoManager *newUndoManager = [[[BDSKUndoManager alloc] init] autorelease];
        [newUndoManager setDelegate:self];
        [self setUndoManager:newUndoManager];
		
        pboardHelper = [[BDSKItemPasteboardHelper alloc] init];
        [pboardHelper setDelegate:self];
        
        docState.isDocumentClosed = NO;
        
        // need to set this for new documents
        [self setDocumentStringEncoding:[BDSKStringEncodingManager defaultEncoding]]; 
        
        // these are set in windowControllerDidLoadNib: from the xattr defaults if available
        bottomPreviewDisplay = BDSKPreviewDisplayText;
        bottomPreviewDisplayTemplate = nil;
        sidePreviewDisplay = BDSKPreviewDisplayFiles;
        sidePreviewDisplayTemplate = nil;
        tableColumnWidths = nil;
        sortKey = nil;
        previousSortKey = nil;
        sortGroupsKey = nil;
        currentGroupField = nil;
        docState.sortDescending = NO;
        docState.sortGroupsDescending = NO;
        docState.didImport = NO;
        docState.itemChangeMask = 0;
        docState.displayMigrationAlert = NO;
        docState.inOptionKeyState = NO;
        
        // these are created lazily when needed
        fileSearchController = nil;
        drawerController = nil;
        macroWC = nil;
        infoWC = nil;
        previewer = nil;
        toolbarItems = nil;
        docState.lastPreviewHeight = 0.0;
        docState.lastGroupViewWidth = 0.0;
        docState.lastFileViewWidth = 0.0;
        
        // these are temporary state variables
        promiseDragColumnIdentifier = nil;
        docState.dragFromExternalGroups = NO;
        docState.currentSaveOperationType = 0;
        
        [self registerForNotifications];
        
        searchIndexes = [[BDSKItemSearchIndexes alloc] init];   
        documentSearch = [[BDSKDocumentSearch alloc] initWithDocument:(id)self];
        rowToSelectAfterDelete = -1;
    }
    return self;
}

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
    @try {
        NSUserDefaultsController *sud = [NSUserDefaultsController sharedUserDefaultsController];
        [sud removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKIgnoredSortTermsKey]];
        [sud removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKAuthorNameDisplayKey]];
        [sud removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKBTStyleKey]];
        [sud removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKUsesTeXKey]];
    }
    @catch (id e) {}
    // workaround for crash: to reproduce, create empty doc, hit cmd-n for new editor window, then cmd-q to quit, choose "don't save"; this results in an -undoManager message to the dealloced document
    [publications makeObjectsPerformSelector:@selector(setOwner:) withObject:nil];
    [groups makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
    [fileSearchController release];
    [pboardHelper setDelegate:nil];
    [pboardHelper release];
    [macroResolver release];
    [publications release];
    [shownPublications release];
    [groupedPublications release];
    [groups release];
    [shownFiles release];
    [frontMatter release];
    [documentInfo release];
    [drawerController release];
    [toolbarItems release];
	[statusBar release];
    [[tableView enclosingScrollView] release];
    [previewer release];
    [bottomPreviewDisplayTemplate release];
    [sidePreviewDisplayTemplate release];
    [macroWC release];
    [infoWC release];
    [promiseDragColumnIdentifier release];
    [tableColumnWidths release];
    [sortKey release];
    [sortGroupsKey release];
    [searchGroupViewController release];
    [webGroupViewController release];
    [searchIndexes release];
    [searchButtonController release];
    [migrationController release];
    [documentSearch release];
    [mainWindowSetupDictionary release];
    [super dealloc];
}

- (NSString *)windowNibName{
        return @"BibDocument";
}

- (void)migrationAlertDidEnd:(BDSKAlert *)alert returnCode:(int)returnCode contextInfo:(void *)unused {
    
    if ([alert checkValue] == YES)
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"BDSKDisableMigrationWarning"];
    
    if (NSAlertDefaultReturn == returnCode)
        [self migrateFiles:self];
}

- (void)showWindows{
    [super showWindows];
    
    // some xattr setup has to be done after the window is on-screen
    NSDictionary *xattrDefaults = [self mainWindowSetupDictionaryFromExtendedAttributes];
    
    NSData *groupData = [xattrDefaults objectForKey:BDSKSelectedGroupsKey];
    if ([groupData length])
        [self selectGroups:[NSKeyedUnarchiver unarchiveObjectWithData:groupData]];

    [self selectItemsForCiteKeys:[xattrDefaults objectForKey:BDSKSelectedPublicationsKey defaultObject:[NSArray array]] selectLibrary:NO];
    NSPoint scrollPoint = [xattrDefaults pointForKey:BDSKDocumentScrollPercentageKey defaultValue:NSZeroPoint];
    [[tableView enclosingScrollView] setScrollPositionAsPercentage:scrollPoint];
    
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
        if(fileURL == nil || [[[NSWorkspace sharedWorkspace] UTIForURL:fileURL] isEqualToUTI:@"net.sourceforge.bibdesk.bdskcache"] == NO){
            // strip extra search criteria
            NSRange range = [searchString rangeOfString:@":"];
            if (range.location != NSNotFound) {
                range = [searchString rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet] options:NSBackwardsSearch range:NSMakeRange(0, range.location)];
                if (range.location != NSNotFound && range.location > 0)
                    searchString = [searchString substringWithRange:NSMakeRange(0, range.location)];
            }
            [self selectLibraryGroup:nil];
            [self setSearchString:searchString];
        }
    }
    
    [self updatePreviews];
    
    if (docState.displayMigrationAlert) {
        docState.displayMigrationAlert = NO;
        // If a single file was migrated, this alert will be shown even if all other BibItems already use BDSKLinkedFile.  However, I think that's an edge case, since the user had to manually add that pub in a text editor or by setting the local-url field.  Items imported or added in BD will already use BDSKLinkedFile, so this notification won't be posted.
        NSString *verify = NSLocalizedString(@"Verify", @"button title for migration alert");
        BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Local File and URL fields have been automatically converted", @"warning in document")
                                             defaultButton:verify 
                                           alternateButton:NSLocalizedString(@"Later", @"") 
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"These fields are being deprecated.  BibDesk now uses a more flexible storage format in place of these fields.  Choose \"%@\" to manually verify the conversion and optionally remove the old fields.  Conversion can be done at any time from the \"%@\" menu.  See the Defaults preferences for more options.", @"alert text"), verify, NSLocalizedString(@"Database", @"Database main menu title")];
        
        // @@ Should we show a check button? If the user saves the doc as-is, it'll have local-url and bdsk-file fields in it, and there will be no warning the next time it's opened.  Someone who uses a script hook to convert bdsk-file back to local-url won't want to see it, though.
        [alert setHasCheckButton:YES];
        [alert setCheckValue:NO];
        [alert setShowsHelp:YES];
        [alert setHelpAnchor:@"FileMigration"];
        [alert beginSheetModalForWindow:[self windowForSheet] modalDelegate:self didEndSelector:@selector(migrationAlertDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    }
}

static void replaceSplitViewSubview(NSView *view, NSSplitView *splitView, NSInteger i) {
    NSView *placeholderView = [[splitView subviews] objectAtIndex:i];
    [view setFrame:[placeholderView frame]];
    [splitView replaceSubview:placeholderView with:view];
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
    
    // this is the controller for the main window
    [aController setShouldCloseDocument:YES];
    
    // hidden default to remove xattrs; this presently occurs before we use them, but it may need to be earlier at some point
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKRemoveExtendedAttributesFromDocuments"] && [self fileURL]) {
        [[SKNExtendedAttributeManager sharedNoSplitManager] removeAllExtendedAttributesAtPath:[[self fileURL] path] traverseLink:YES error:NULL];
    }
    
    // get document-specific attributes (returns empty dictionary if there are none, so defaultValue works correctly)
    NSDictionary *xattrDefaults = [self mainWindowSetupDictionaryFromExtendedAttributes];
    NSUserDefaults*sud = [NSUserDefaults standardUserDefaults];
    
    [self setupToolbar];
    
    replaceSplitViewSubview(bottomPreviewTabView, splitView, 1);
    replaceSplitViewSubview([[groupTableView enclosingScrollView] superview], groupSplitView, 0);
    replaceSplitViewSubview([mainBox superview], groupSplitView, 1);
    replaceSplitViewSubview([sidePreviewTabView superview], groupSplitView, 2);
    
    // First remove the statusbar if we should, as it affects proper resizing of the window and splitViews
	[statusBar retain]; // we need to retain, as we might remove it from the window
	if (![sud boolForKey:BDSKShowStatusBarKey]) {
		[self toggleStatusBar:nil];
	} else {
		// make sure they are ordered correctly, mainly for the focus ring
		[statusBar removeFromSuperview];
		[[mainBox superview] addSubview:statusBar positioned:NSWindowBelow relativeTo:nil];
	}
	[statusBar setProgressIndicatorStyle:BDSKProgressIndicatorSpinningStyle];
    [statusBar setTextOffset:NSMaxX([bottomPreviewButton frame]) - 2.0];
    
    bottomPreviewDisplay = [xattrDefaults intForKey:BDSKBottomPreviewDisplayKey defaultValue:[sud integerForKey:BDSKBottomPreviewDisplayKey]];
    bottomPreviewDisplayTemplate = [[xattrDefaults objectForKey:BDSKBottomPreviewDisplayTemplateKey defaultObject:[sud stringForKey:BDSKBottomPreviewDisplayTemplateKey]] retain];
    sidePreviewDisplay = [xattrDefaults intForKey:BDSKSidePreviewDisplayKey defaultValue:[sud integerForKey:BDSKSidePreviewDisplayKey]];
    sidePreviewDisplayTemplate = [[xattrDefaults objectForKey:BDSKSidePreviewDisplayTemplateKey defaultObject:[sud stringForKey:BDSKSidePreviewDisplayTemplateKey]] retain];
        
    bottomTemplatePreviewMenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] init] autorelease];
    [bottomTemplatePreviewMenu setDelegate:self];
    [bottomPreviewButton setMenu:bottomTemplatePreviewMenu forSegment:0];
    [bottomPreviewButton setEnabled:[sud boolForKey:BDSKUsesTeXKey] forSegment:BDSKPreviewDisplayTeX];
    [bottomPreviewButton selectSegmentWithTag:bottomPreviewDisplay];
    
    sideTemplatePreviewMenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] init] autorelease];
    [sideTemplatePreviewMenu setDelegate:self];
    [sidePreviewButton setMenu:sideTemplatePreviewMenu forSegment:0];
    [sidePreviewButton selectSegmentWithTag:sidePreviewDisplay];
    
    // This must also be done before we resize the window and the splitViews
    [groupCollapsibleView setCollapseEdges:BDSKMinXEdgeMask];
    [groupCollapsibleView setMinSize:NSMakeSize(56.0, 22.0)];
    [groupGradientView setUpperColor:[NSColor colorWithCalibratedWhite:0.9 alpha:1.0]];
    [groupGradientView setLowerColor:[NSColor colorWithCalibratedWhite:0.75 alpha:1.0]];

    // make sure they are ordered correctly, mainly for the focus ring
	[groupCollapsibleView retain];
    [groupCollapsibleView removeFromSuperview];
    [[[groupTableView enclosingScrollView] superview] addSubview:groupCollapsibleView positioned:NSWindowBelow relativeTo:nil];
	[groupCollapsibleView release];

    NSRect frameRect = [xattrDefaults rectForKey:BDSKDocumentWindowFrameKey defaultValue:NSZeroRect];
    
    [aController setWindowFrameAutosaveNameOrCascade:@"Main Window Frame Autosave" setFrame:frameRect];
            
    [documentWindow setAutorecalculatesKeyViewLoop:YES];
    [documentWindow makeFirstResponder:tableView];	
    
    // SplitViews setup
    [groupSplitView setBlendStyle:BDSKStatusBarBlendStyleMask];
    [splitView setBlendStyle:BDSKMinBlendStyleMask | BDSKMaxBlendStyleMask];
    
    // set autosave names first
	[splitView setPositionAutosaveName:@"Main Window"];
    [groupSplitView setPositionAutosaveName:@"Group Table"];
    if ([aController windowFrameAutosaveName] == nil) {
        // Only autosave the frames when the window's autosavename is set to avoid inconsistencies
        [splitView setPositionAutosaveName:nil];
        [groupSplitView setPositionAutosaveName:nil];
    }
    
    // set previous splitview frames
    float fract;
    fract = [xattrDefaults floatForKey:BDSKGroupSplitViewFractionKey defaultValue:-1.0];
    if (fract >= 0)
        [groupSplitView setFraction:fract];
    fract = [xattrDefaults floatForKey:BDSKMainTableSplitViewFractionKey defaultValue:-1.0];
    if (fract >= 0)
        [splitView setFraction:fract];
    
    [mainBox setBackgroundColor:[NSColor controlBackgroundColor]];
    
    // this might be replaced by the file content tableView
    [[tableView enclosingScrollView] retain];
    [[tableView enclosingScrollView] setFrame:[mainView bounds]];
    
    // TableView setup
    [tableView removeAllTableColumns];
    
    [tableView setFontNamePreferenceKey:BDSKMainTableViewFontNameKey];
    [tableView setFontSizePreferenceKey:BDSKMainTableViewFontSizeKey];
    [groupTableView setFontNamePreferenceKey:BDSKGroupTableViewFontNameKey];
    [groupTableView setFontSizePreferenceKey:BDSKGroupTableViewFontSizeKey];
    
    tableColumnWidths = [[xattrDefaults objectForKey:BDSKColumnWidthsKey] retain];
    [tableView setupTableColumnsWithIdentifiers:[xattrDefaults objectForKey:BDSKShownColsNamesKey defaultObject:[sud objectForKey:BDSKShownColsNamesKey]]];
    sortKey = [[xattrDefaults objectForKey:BDSKDefaultSortedTableColumnKey defaultObject:[sud objectForKey:BDSKDefaultSortedTableColumnKey]] retain];
    previousSortKey = [sortKey retain];
    docState.sortDescending = [xattrDefaults  boolForKey:BDSKDefaultSortedTableColumnIsDescendingKey defaultValue:[sud boolForKey:BDSKDefaultSortedTableColumnIsDescendingKey]];
    [tableView setHighlightedTableColumn:[tableView tableColumnWithIdentifier:sortKey]];
    
    [sortGroupsKey autorelease];
    sortGroupsKey = [[xattrDefaults objectForKey:BDSKSortGroupsKey defaultObject:[sud objectForKey:BDSKSortGroupsKey]] retain];
    docState.sortGroupsDescending = [xattrDefaults boolForKey:BDSKSortGroupsDescendingKey defaultValue:[sud boolForKey:BDSKSortGroupsDescendingKey]];
    [self setCurrentGroupField:[xattrDefaults objectForKey:BDSKCurrentGroupFieldKey defaultObject:[sud objectForKey:BDSKCurrentGroupFieldKey]]];
    
    [tableView setDoubleAction:@selector(editPubOrOpenURLAction:)];
    NSArray *dragTypes = [NSArray arrayWithObjects:BDSKBibItemPboardType, BDSKWeblocFilePboardType, BDSKReferenceMinerStringPboardType, NSStringPboardType, NSFilenamesPboardType, NSURLPboardType, NSColorPboardType, nil];
    [tableView registerForDraggedTypes:dragTypes];
    [groupTableView registerForDraggedTypes:dragTypes];
    
    [sideFileView setBackgroundColor:[[sideFileView enclosingScrollView] backgroundColor]];
    [bottomFileView setBackgroundColor:[[bottomFileView enclosingScrollView] backgroundColor]];
    
    [fileCollapsibleView setCollapseEdges:BDSKMaxXEdgeMask];
    [fileCollapsibleView setMinSize:NSMakeSize(65.0, 22.0)];
    [fileGradientView setUpperColor:[NSColor colorWithCalibratedWhite:0.9 alpha:1.0]];
    [fileGradientView setLowerColor:[NSColor colorWithCalibratedWhite:0.75 alpha:1.0]];
    
    float iconScale = [xattrDefaults floatForKey:BDSKSideFileViewIconScaleKey defaultValue:[sud floatForKey:BDSKSideFileViewIconScaleKey]];
    if (iconScale < 0.00001) {
        [sideFileView setAutoScales:YES];
    } else {
        [sideFileView setAutoScales:NO];
        [sideFileView setIconScale:iconScale];
    }
    [sideFileView setAutoScales:YES];
    [sideFileView addObserver:self forKeyPath:@"iconScale" options:0 context:BDSKDocumentFileViewObservationContext];

    iconScale = [xattrDefaults floatForKey:BDSKBottomFileViewIconScaleKey defaultValue:[sud floatForKey:BDSKBottomFileViewIconScaleKey]];
    if (iconScale < 0.00001) {
        [bottomFileView setAutoScales:YES];
    } else {
        [bottomFileView setAutoScales:NO];
        [bottomFileView setIconScale:iconScale];
    }
    [bottomFileView addObserver:self forKeyPath:@"iconScale" options:0 context:BDSKDocumentFileViewObservationContext];
    
    [(BDSKZoomableTextView *)sidePreviewTextView setScaleFactor:[xattrDefaults floatForKey:BDSKSidePreviewScaleFactorKey defaultValue:1.0]];
    [(BDSKZoomableTextView *)bottomPreviewTextView setScaleFactor:[xattrDefaults floatForKey:BDSKBottomPreviewScaleFactorKey defaultValue:1.0]];
    
	// ImagePopUpButtons setup
	[actionMenuButton setShowsMenuWhenIconClicked:YES];
	[[actionMenuButton cell] setAltersStateOfSelectedItem:NO];
	[[actionMenuButton cell] setAlwaysUsesFirstItemAsSelected:NO];
	[[actionMenuButton cell] setUsesItemFromMenu:NO];
	[[actionMenuButton cell] setRefreshesMenu:YES];
	[actionMenuButton setDelegate:self];
	
	[groupActionMenuButton setShowsMenuWhenIconClicked:YES];
	[[groupActionMenuButton cell] setAltersStateOfSelectedItem:NO];
	[[groupActionMenuButton cell] setAlwaysUsesFirstItemAsSelected:NO];
	[[groupActionMenuButton cell] setUsesItemFromMenu:NO];
	[[groupActionMenuButton cell] setRefreshesMenu:NO];
	
	[groupActionButton setArrowImage:nil];
	[groupActionButton setAlternateImage:[NSImage imageNamed:@"GroupAction_Pressed"]];
	[groupActionButton setShowsMenuWhenIconClicked:YES];
	[[groupActionButton cell] setAltersStateOfSelectedItem:NO];
	[[groupActionButton cell] setAlwaysUsesFirstItemAsSelected:NO];
	[[groupActionButton cell] setUsesItemFromMenu:NO];
	[[groupActionButton cell] setRefreshesMenu:NO];
    
	BDSKHeaderPopUpButtonCell *headerCell = (BDSKHeaderPopUpButtonCell *)[groupTableView popUpHeaderCell];
	[headerCell setAction:@selector(changeGroupFieldAction:)];
	[headerCell setTarget:self];
	[headerCell setMenu:[self groupFieldsMenu]];
	[headerCell setIndicatorImage:[NSImage imageNamed:docState.sortGroupsDescending ? @"NSDescendingSortIndicator" : @"NSAscendingSortIndicator"]];
    [headerCell setUsesItemFromMenu:NO];
	[headerCell setTitle:[currentGroupField localizedFieldName]];
    if([headerCell indexOfItemWithRepresentedObject:currentGroupField] != -1)
        [headerCell selectItemAtIndex:[headerCell indexOfItemWithRepresentedObject:currentGroupField]];
    else
        [headerCell selectItemAtIndex:0];
    
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
    [self updateSmartGroupsCountAndContent:NO];
    [self updateCategoryGroupsPreservingSelection:NO];
    
    [saveTextEncodingPopupButton setEncoding:0];
    
}

- (BOOL)undoManagerShouldUndoChange:(id)sender{
	if (![self isDocumentEdited]) {
		BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Warning", @"Message in alert dialog") 
											 defaultButton:NSLocalizedString(@"Yes", @"Button title") 
										   alternateButton:NSLocalizedString(@"No", @"Button title") 
											   otherButton:nil
								 informativeTextWithFormat:NSLocalizedString(@"You are about to undo past the last point this file was saved. Do you want to do this?", @"Informative text in alert dialog") ];

		int rv = [alert runSheetModalForWindow:documentWindow];
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

- (void)windowWillClose:(NSNotification *)notification{
        
    // see comment in invalidateSearchFieldCellTimer
    if (floor(NSAppKitVersionNumber <= NSAppKitVersionNumber10_4)) {
        [documentWindow endEditingFor:nil];
        [self invalidateSearchFieldCellTimer];
    }

    docState.isDocumentClosed = YES;

    [documentSearch terminate];
    [fileSearchController terminate];
    
    if([drawerController isDrawerOpen])
        [drawerController toggle:nil];
    [self saveSortOrder];
    [self saveWindowSetupInExtendedAttributesAtURL:[self fileURL] forSave:NO];
    
    // reset the previewer; don't send [self updatePreviews:] here, as the tableview will be gone by the time the queue posts the notification
    if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey] &&
       [[BDSKPreviewer sharedPreviewer] isWindowVisible] &&
       [self isMainDocument] &&
       [self numberOfSelectedPubs] != 0)
        [[BDSKPreviewer sharedPreviewer] updateWithBibTeXString:nil];    
	
	[pboardHelper setDelegate:nil];
    [pboardHelper release];
    pboardHelper = nil;
    
    [sideFileView removeObserver:self forKeyPath:@"iconScale"];
    [sideFileView setDataSource:nil];
    [sideFileView setDelegate:nil];
    
    [bottomFileView removeObserver:self forKeyPath:@"iconScale"];
    [bottomFileView setDataSource:nil];
    [bottomFileView setDelegate:nil];
    
    // safety call here, in case the pasteboard is retaining the document; we don't want notifications after the window closes, since all the pointers to UI elements will be garbage
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// returns empty dictionary if no attributes set
- (NSDictionary *)mainWindowSetupDictionaryFromExtendedAttributes {
    if (mainWindowSetupDictionary == nil) {
        if ([self fileURL])
            mainWindowSetupDictionary = [[[SKNExtendedAttributeManager sharedNoSplitManager] propertyListFromExtendedAttributeNamed:BDSKMainWindowExtendedAttributeKey atPath:[[self fileURL] path] traverseLink:YES error:NULL] retain];
        if (nil == mainWindowSetupDictionary)
            mainWindowSetupDictionary = [[NSDictionary alloc] init];
    }
    return mainWindowSetupDictionary;
}

- (void)saveWindowSetupInExtendedAttributesAtURL:(NSURL *)anURL forSave:(BOOL)isSave{
    
    NSString *path = [anURL path];
    if (path && [[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKDisableDocumentExtendedAttributes"] == NO) {
        
        // We could set each of these as a separate attribute name on the file, but then we'd need to muck around with prepending net.sourceforge.bibdesk. to each key, and that seems messy.
        NSMutableDictionary *dictionary = [[self mainWindowSetupDictionaryFromExtendedAttributes] mutableCopy];
        
        NSString *savedSortKey = nil;
        if ([sortKey isEqualToString:BDSKImportOrderString] || [sortKey isEqualToString:BDSKRelevanceString]) {
            if ([previousSortKey isEqualToString:BDSKImportOrderString] == NO && [previousSortKey isEqualToString:BDSKRelevanceString] == NO) 
                savedSortKey = previousSortKey;
        } else {
            savedSortKey = sortKey;
        }
        
        [dictionary setObject:[[[tableView tableColumnIdentifiers] arrayByRemovingObject:BDSKImportOrderString] arrayByRemovingObject:BDSKRelevanceString] forKey:BDSKShownColsNamesKey];
        [dictionary setObject:[self currentTableColumnWidthsAndIdentifiers] forKey:BDSKColumnWidthsKey];
        [dictionary setObject:savedSortKey ?: BDSKTitleString forKey:BDSKDefaultSortedTableColumnKey];
        [dictionary setBoolValue:docState.sortDescending forKey:BDSKDefaultSortedTableColumnIsDescendingKey];
        [dictionary setObject:sortGroupsKey forKey:BDSKSortGroupsKey];
        [dictionary setBoolValue:docState.sortGroupsDescending forKey:BDSKSortGroupsDescendingKey];
        [dictionary setRectValue:[documentWindow frame] forKey:BDSKDocumentWindowFrameKey];
        [dictionary setFloatValue:[groupSplitView fraction] forKey:BDSKGroupSplitViewFractionKey];
        // of the 3 splitviews, the fraction of the first divider would be considered, so fallback to the fraction from the nib
        if (NO == [self hasWebGroupSelected])
            [dictionary setFloatValue:[splitView fraction] forKey:BDSKMainTableSplitViewFractionKey];
        [dictionary setObject:currentGroupField forKey:BDSKCurrentGroupFieldKey];
        
        // if this isn't a save operation, the encoding in xattr is already correct, while our encoding might be different from the actual file encoding, if the user might ignored an encoding warning without saving
        if(isSave)
            [dictionary setUnsignedIntValue:[self documentStringEncoding] forKey:BDSKDocumentStringEncodingKey];
        
        // encode groups so we can select them later with isEqual: (saving row indexes would not be as reliable)
        [dictionary setObject:([self hasExternalGroupsSelected] ? [NSData data] : [NSKeyedArchiver archivedDataWithRootObject:[self selectedGroups]]) forKey:BDSKSelectedGroupsKey];
        
        NSArray *selectedKeys = [[self selectedPublications] arrayByPerformingSelector:@selector(citeKey)];
        if ([selectedKeys count] == 0 || [self hasExternalGroupsSelected])
            selectedKeys = [NSArray array];
        [dictionary setObject:selectedKeys forKey:BDSKSelectedPublicationsKey];
        [dictionary setPointValue:[[tableView enclosingScrollView] scrollPositionAsPercentage] forKey:BDSKDocumentScrollPercentageKey];
        
        [dictionary setIntValue:bottomPreviewDisplay forKey:BDSKBottomPreviewDisplayKey];
        [dictionary setObject:bottomPreviewDisplayTemplate forKey:BDSKBottomPreviewDisplayTemplateKey];
        [dictionary setIntValue:sidePreviewDisplay forKey:BDSKSidePreviewDisplayKey];
        [dictionary setObject:sidePreviewDisplayTemplate forKey:BDSKSidePreviewDisplayTemplateKey];
        
        [dictionary setFloatValue:[bottomFileView autoScales] ? 0.0 : [bottomFileView iconScale] forKey:BDSKBottomFileViewIconScaleKey];
        [dictionary setFloatValue:[sideFileView autoScales] ? 0.0 : [sideFileView iconScale] forKey:BDSKSideFileViewIconScaleKey];
        
        [dictionary setFloatValue:[(BDSKZoomableTextView *)bottomPreviewTextView scaleFactor] forKey:BDSKBottomPreviewScaleFactorKey];
        [dictionary setFloatValue:[(BDSKZoomableTextView *)sidePreviewTextView scaleFactor] forKey:BDSKSidePreviewScaleFactorKey];
        
        if(previewer){
            [dictionary setFloatValue:[previewer PDFScaleFactor] forKey:BDSKPreviewPDFScaleFactorKey];
            [dictionary setFloatValue:[previewer RTFScaleFactor] forKey:BDSKPreviewRTFScaleFactorKey];
        }
        
        if(fileSearchController){
            [dictionary setObject:[fileSearchController sortDescriptorData] forKey:BDSKFileContentSearchSortDescriptorKey];
        }
        
        NSError *error;
        
        if ([[SKNExtendedAttributeManager sharedNoSplitManager] setExtendedAttributeNamed:BDSKMainWindowExtendedAttributeKey 
                                                  toPropertyListValue:dictionary
                                                               atPath:path options:0 error:&error] == NO) {
            NSLog(@"%@: %@", self, error);
        }
        
        [mainWindowSetupDictionary release];
        mainWindowSetupDictionary = [dictionary copy];
        [dictionary release];
    } 
}

#pragma mark -
#pragma mark Publications acessors

- (void)setPublicationsWithoutUndo:(NSArray *)newPubs{
    [publications makeObjectsPerformSelector:@selector(setOwner:) withObject:nil];
    [publications setArray:newPubs];
    [publications makeObjectsPerformSelector:@selector(setOwner:) withObject:self];
    
    [searchIndexes resetWithPublications:newPubs];
}    

- (void)setPublications:(NSArray *)newPubs{
    if(newPubs != publications){
        NSUndoManager *undoManager = [self undoManager];
        [[undoManager prepareWithInvocationTarget:self] setPublications:publications];
        
        [self setPublicationsWithoutUndo:newPubs];
        
        NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:newPubs, @"pubs", nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocSetPublicationsNotification
                                                            object:self
                                                          userInfo:notifInfo];
    }
}

- (BDSKPublicationsArray *) publications{
    return publications;
}

- (NSArray *) shownPublications{
    return shownPublications;
}

- (void)insertPublications:(NSArray *)pubs atIndexes:(NSIndexSet *)indexes{
    // this assertion is only necessary to preserve file order for undo
    NSParameterAssert([indexes count] == [pubs count]);
    [[[self undoManager] prepareWithInvocationTarget:self] removePublicationsAtIndexes:indexes];
		
	[publications insertObjects:pubs atIndexes:indexes];        
    
	[pubs makeObjectsPerformSelector:@selector(setOwner:) withObject:self];
	
    [searchIndexes addPublications:pubs];

	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:pubs, @"pubs", [pubs arrayByPerformingSelector:@selector(searchIndexInfo)], @"searchIndexInfo", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocAddItemNotification
														object:self
													  userInfo:notifInfo];
}

- (void)insertPublication:(BibItem *)pub atIndex:(unsigned int)idx {
    [self insertPublications:[NSArray arrayWithObject:pub] atIndexes:[NSIndexSet indexSetWithIndex:idx]];
}

- (void)addPublications:(NSArray *)pubs{
    [self insertPublications:pubs atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,[pubs count])]];
}

- (void)addPublication:(BibItem *)pub{
    [self insertPublication:pub atIndex:0]; // insert new pubs at the beginning, so item number is handled properly
}

- (void)removePublicationsAtIndexes:(NSIndexSet *)indexes{
    NSArray *pubs = [publications objectsAtIndexes:indexes];
	[[[self undoManager] prepareWithInvocationTarget:self] insertPublications:pubs atIndexes:indexes];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:pubs, @"pubs", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocWillRemoveItemNotification
														object:self
													  userInfo:notifInfo];	
    
    [[groups lastImportGroup] removePublicationsInArray:pubs];
    [[groups staticGroups] makeObjectsPerformSelector:@selector(removePublicationsInArray:) withObject:pubs];
    [searchIndexes removePublications:pubs];
    
	[publications removeObjectsAtIndexes:indexes];
	
	[pubs makeObjectsPerformSelector:@selector(setOwner:) withObject:nil];
    [[NSFileManager defaultManager] removeSpotlightCacheFilesForCiteKeys:[pubs arrayByPerformingSelector:@selector(citeKey)]];
	
	notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:pubs, @"pubs", [pubs arrayByPerformingSelector:@selector(searchIndexInfo)], @"searchIndexInfo", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocDelItemNotification
														object:self
													  userInfo:notifInfo];
}

- (void)removePublications:(NSArray *)pubs{
    [self removePublicationsAtIndexes:[publications indexesOfObjectsIdenticalTo:pubs]];
}

- (void)removePublication:(BibItem *)pub{
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:[publications indexOfObjectIdenticalTo:pub]];
    [self removePublicationsAtIndexes:indexes];
}

#pragma mark Groups accessors

- (BDSKGroupsArray *)groups{
    return groups;
}

#pragma mark Searching

- (BDSKItemSearchIndexes *)searchIndexes{
    return searchIndexes;
}

#pragma mark -

- (void)getCopyOfPublicationsOnMainThread:(NSMutableArray *)dstArray{
    if([NSThread isMainThread] == NO){
        [self performSelectorOnMainThread:_cmd withObject:dstArray waitUntilDone:YES];
    } else {
        NSArray *array = [[NSArray alloc] initWithArray:[self publications] copyItems:YES];
        [dstArray addObjectsFromArray:array];
        [array release];
    }
}

- (void)getCopyOfMacrosOnMainThread:(NSMutableDictionary *)dstDict{
    if([NSThread isMainThread] == NO){
        [self performSelectorOnMainThread:_cmd withObject:dstDict waitUntilDone:YES];
    } else {
        NSDictionary *dict = [[NSDictionary alloc] initWithDictionary:[macroResolver macroDefinitions] copyItems:YES];
        [dstDict addEntriesFromDictionary:dict];
        [dict release];
    }
}

#pragma mark Document Info

- (NSDictionary *)documentInfo{
    return documentInfo;
}

- (void)setDocumentInfoWithoutUndo:(NSDictionary *)dict{
    [documentInfo setDictionary:dict];
}

- (void)setDocumentInfo:(NSDictionary *)dict{
    [[[self undoManager] prepareWithInvocationTarget:self] setDocumentInfo:[[documentInfo copy] autorelease]];
    [documentInfo setDictionary:dict];
}

- (NSString *)documentInfoForKey:(NSString *)key{
    return [documentInfo valueForKey:key];
}

- (id)valueForUndefinedKey:(NSString *)key{
    return [self documentInfoForKey:key];
}

- (NSString *)documentInfoString{
    NSMutableString *string = [NSMutableString stringWithString:@"@bibdesk_info{document_info"];
    NSEnumerator *keyEnum = [documentInfo keyEnumerator];
    NSString *key;
    
    while (key = [keyEnum nextObject]) 
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
	
	NSEnumerator *viewEnum = [[view subviews] objectEnumerator];
	NSView *subview;
	NSPopUpButton *popup;
	
	while (subview = [viewEnum nextObject]) {
		if (popup = popUpButtonSubview(subview))
			return popup;
	}
	return nil;
}

// if the user is saving in one of our plain text formats, give them an encoding option as well
// this also requires overriding saveToURL:ofType:forSaveOperation:error:
// to set the document's encoding before writing to the file
- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel{
    if([super prepareSavePanel:savePanel] == NO)
        return NO;
    
    if(NSSaveToOperation == docState.currentSaveOperationType){
        NSView *accessoryView = [savePanel accessoryView];
        BDSKASSERT(accessoryView != nil);
        NSPopUpButton *saveFormatPopupButton = popUpButtonSubview(accessoryView);
        BDSKASSERT(saveFormatPopupButton != nil);
        NSRect savFrame = [saveAccessoryView frame];
        savFrame.size.width = NSWidth([accessoryView frame]);
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

// this is a private method, the action of the file format poup
- (void)changeSaveType:(id)sender{
    NSSet *typesWithEncoding = [NSSet setWithObjects:BDSKBibTeXDocumentType, BDSKRISDocumentType, BDSKMinimalBibTeXDocumentType, BDSKLTBDocumentType, BDSKArchiveDocumentType, nil];
    NSString *selectedType = [[sender selectedItem] representedObject];
    [saveTextEncodingPopupButton setEnabled:[typesWithEncoding containsObject:selectedType]];
    if ([NSDocument instancesRespondToSelector:@selector(changeSaveType:)])
        [super changeSaveType:sender];
}

- (void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo {
    // Override so we can determine if this is a save, saveAs or export operation, so we can prepare the correct accessory view
    docState.currentSaveOperationType = saveOperation;
    [super runModalSavePanelForSaveOperation:saveOperation delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}

- (BOOL)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError{
    
    // Set the string encoding according to the popup.  
    // NB: the popup has the incorrect encoding if it wasn't displayed, for example for the Save action and saving using AppleScript, so don't reset encoding unless we're actually modifying this document through a menu .
    if (NSSaveAsOperation == saveOperation && [saveTextEncodingPopupButton encoding] != 0)
        [self setDocumentStringEncoding:[saveTextEncodingPopupButton encoding]];
    
    saveTargetURL = [absoluteURL copy];
    
    BOOL success = [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
    
    // set com.apple.TextEncoding for other apps
    NSString *UTI = [[NSWorkspace sharedWorkspace] UTIForURL:absoluteURL];
    if (success && UTI && UTTypeConformsTo((CFStringRef)UTI, kUTTypePlainText)) 
        [[NSFileManager defaultManager] setAppleStringEncoding:[self documentStringEncoding] atPath:[absoluteURL path] error:NULL];
    
    [saveTargetURL release];
    saveTargetURL = nil;
    
    // reset the encoding popup so we know when it wasn't shown to the user next time
    [saveTextEncodingPopupButton setEncoding:0];
    [exportSelectionCheckButton setState:NSOffState];
    
    if(success == NO)
        return NO;
    
    if(saveOperation == NSSaveToOperation){
        // write template accessory files if necessary
        BDSKTemplate *selectedTemplate = [BDSKTemplate templateForStyle:typeName];
        if(selectedTemplate){
            NSEnumerator *accessoryFileEnum = [[selectedTemplate accessoryFileURLs] objectEnumerator];
            NSURL *accessoryURL = nil;
            NSURL *destDirURL = [absoluteURL URLByDeletingLastPathComponent];
            while(accessoryURL = [accessoryFileEnum nextObject]){
                [[NSFileManager defaultManager] copyObjectAtURL:accessoryURL toDirectoryAtURL:destDirURL error:NULL];
            }
        }
        
        // save our window setup if we export to BibTeX or RIS
        if([[self class] isNativeType:typeName] || [typeName isEqualToString:BDSKMinimalBibTeXDocumentType])
            [self saveWindowSetupInExtendedAttributesAtURL:absoluteURL forSave:YES];
        
    }else if(saveOperation == NSSaveOperation || saveOperation == NSSaveAsOperation){
        [[BDSKScriptHookManager sharedManager] runScriptHookWithName:BDSKSaveDocumentScriptHookName 
                                                     forPublications:publications
                                                            document:self];
        
        // rebuild metadata cache for this document whenever we save
        NSEnumerator *pubsE = [[self publications] objectEnumerator];
        NSMutableArray *pubsInfo = [[NSMutableArray alloc] initWithCapacity:[publications count]];
        BibItem *anItem;
        NSDictionary *info;
        BOOL update = (saveOperation == NSSaveOperation); // for saveTo we should update all items, as our path changes
        
        while(anItem = [pubsE nextObject]){
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            @try {
                if(info = [anItem metadataCacheInfoForUpdate:update])
                    [pubsInfo addObject:info];
            }
            @catch (id e) { @throw(e); }
            @finally { [pool release]; }
        }
        
        NSDictionary *infoDict = [[NSDictionary alloc] initWithObjectsAndKeys:pubsInfo, @"publications", absoluteURL, @"fileURL", nil];
        [pubsInfo release];
        [[NSApp delegate] rebuildMetadataCache:infoDict];
        [infoDict release];
        
        // save window setup to extended attributes, so it is set also if we use saveAs
        [self saveWindowSetupInExtendedAttributesAtURL:absoluteURL forSave:YES];
    }
    
    return YES;
}

- (BOOL)writeToURL:(NSURL *)absoluteURL 
            ofType:(NSString *)typeName 
  forSaveOperation:(NSSaveOperationType)saveOperation 
originalContentsURL:(NSURL *)absoluteOriginalContentsURL 
             error:(NSError **)outError {
    // Override so we can determine if this is an autosave in writeToURL:ofType:error:.
    // This is necessary on 10.4 to keep from calling the clearChangeCount hack for an autosave, which incorrectly marks the document as clean.
    docState.currentSaveOperationType = saveOperation;
    return [super writeToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation originalContentsURL:absoluteOriginalContentsURL error:outError];
}

- (BOOL)writeToURL:(NSURL *)fileURL ofType:(NSString *)docType error:(NSError **)outError{

    BOOL success = YES;
    NSError *nsError = nil;
    NSArray *items = publications;
    
    // first we make sure all edits are committed
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKFinalizeChangesNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionary]];
    
    if(docState.currentSaveOperationType == NSSaveToOperation && [exportSelectionCheckButton state] == NSOnState)
        items = [self numberOfSelectedPubs] > 0 ? [self selectedPublications] : groupedPublications;
    
    if ([docType isEqualToString:BDSKArchiveDocumentType] || [docType isEqualToUTI:[[NSWorkspace sharedWorkspace] UTIForPathExtension:@"tgz"]]) {
        success = [self writeArchiveToURL:fileURL forPublications:items error:outError];
    } else {
        NSFileWrapper *fileWrapper = [self fileWrapperOfType:docType forPublications:items error:&nsError];
        success = nil == fileWrapper ? NO : [fileWrapper writeToFile:[fileURL path] atomically:NO updateFilenames:NO];
    }
    
    // see if this is our error or Apple's
    if (NO == success && [nsError isLocalError]) {
        
        // get offending BibItem if possible
        BibItem *theItem = [nsError valueForKey:BDSKUnderlyingItemErrorKey];
        if (theItem)
            [self selectPublication:theItem];
        
        NSString *errTitle = NSAutosaveOperation == docState.currentSaveOperationType ? NSLocalizedString(@"Unable to autosave file", @"Error description") : NSLocalizedString(@"Unable to save file", @"Error description");
        
        // @@ do this in fileWrapperOfType:forPublications:error:?  should just use error localizedDescription
        NSString *errMsg = [nsError valueForKey:NSLocalizedRecoverySuggestionErrorKey] ?: NSLocalizedString(@"The underlying cause of this error is unknown.  Please submit a bug report with the file attached.", @"Error informative text");
        
        nsError = [NSError mutableLocalErrorWithCode:kBDSKDocumentSaveError localizedDescription:errTitle underlyingError:nsError];
        [nsError setValue:errMsg forKey:NSLocalizedRecoverySuggestionErrorKey];        
    }
    // needed because of finalize changes; don't send -clearChangeCount if the save failed for any reason, or if we're autosaving!
    else if (docState.currentSaveOperationType != NSAutosaveOperation && docState.currentSaveOperationType != NSSaveToOperation)
        [self performSelector:@selector(clearChangeCount) withObject:nil afterDelay:0.01];
    
    // setting to nil is okay
    if (outError) *outError = nsError;
    
    return success;
}

- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError;
{
    BOOL didSave = [super writeSafelyToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
    
#if defined(MAC_OS_X_VERSION_10_5) && (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5)
    
    /* 
     This is a workaround for https://sourceforge.net/tracker/index.php?func=detail&aid=1867790&group_id=61487&atid=497423
     Filed as rdar://problem/5679370
     
     I'm not sure what the semantics of this operation are for NSAutosaveOperation, so it's excluded (but uses a different code path anyway, at least on Leopard).  This also doesn't get hit for save-as or save-to since they don't do a safe-save, but they're handled anyway.  FSExchangeObjects apparently avoids the bugs in FSPathReplaceObject, but doesn't preserve all of the metadata that those do.  It's a shame that Apple can't preserve the file content as well as they preserve the metadata; I'd rather lose the ACLs than lose my bibliography.
     
     TODO:  xattr handling, package vs. flat file (overwrite directory)?  
     xattrs from BibDesk seem to be preserved, so I'm not going to bother with that.
     
     TESTED:  On AFP volume served by 10.4.11 Server, saving from 10.5.1 client; on AFP volume served by 10.5.1 client, saving from 10.5.1 client.  Autosave, Save-As, and Save were tested.  Saving to a local HFS+ volume doesn't hit this code path, and neither does saving to a FAT-32 thumb drive.
     
     */
    
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4 && NO == didSave && [absoluteURL isFileURL] && NSAutosaveOperation != saveOperation) {
        
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
                posixPerms = [[fileManager fileAttributesAtPath:[absoluteURL path] traverseLink:YES] objectForKey:NSFilePosixPermissions];
            
            if (nil != posixPerms)
                [fattrs setObject:posixPerms forKey:NSFilePosixPermissions];
            
            // not checking return value here; non-critical
            if ([fattrs count])
                [fileManager changeFileAttributes:fattrs atPath:[saveToURL path]];
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
                [fileManager removeFileAtPath:[saveToURL path] handler:nil];
            }
        }
    }
    
#endif
    
    return didSave;
}

- (void)clearChangeCount{
	[self updateChangeCount:NSChangeCleared];
}

- (BOOL)writeArchiveToURL:(NSURL *)fileURL forPublications:(NSArray *)items error:(NSError **)outError{
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    
    NSString *path = [[fileURL path] stringByDeletingPathExtension];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSEnumerator *itemEnum = [items objectEnumerator];
    BibItem *item;
    NSString *filePath;
    NSString *commonParent = nil;
    BOOL success = YES;
    NSMutableSet *localFiles = [NSMutableSet set];
    
    if (success = [fm createDirectoryAtPath:path attributes:nil]) {
        while (item = [itemEnum nextObject]) {
            NSEnumerator *fileEnum = [[item localFiles] objectEnumerator];
            BDSKLinkedFile *file;
            while (file = [fileEnum nextObject]) {
                if (filePath = [[file URL] path]) {
                    [localFiles addObject:filePath];
                    if (commonParent)
                        commonParent = [[filePath stringByDeletingLastPathComponent] commonRootPathOfFile:commonParent];
                    else
                        commonParent = [filePath stringByDeletingLastPathComponent];
                }
            }
        }
        
        NSStringEncoding encoding = [saveTextEncodingPopupButton encoding] ?: [BDSKStringEncodingManager defaultEncoding];
        NSData *bibtexData = [self bibTeXDataForPublications:items encoding:encoding droppingInternal:NO relativeToPath:commonParent error:outError];
        NSString *bibtexPath = [[path stringByAppendingPathComponent:[path lastPathComponent]] stringByAppendingPathExtension:@"bib"];
        
        success = [bibtexData writeToFile:bibtexPath options:0 error:outError];
        itemEnum = [localFiles objectEnumerator];
        
        while (success && (filePath = [itemEnum nextObject])) {
            if ([fm fileExistsAtPath:filePath]) {
                NSString *relativePath = commonParent ? [commonParent relativePathToFile:filePath] : [filePath lastPathComponent];
                NSString *targetPath = [path stringByAppendingPathComponent:relativePath];
                
                if ([fm fileExistsAtPath:targetPath])
                    targetPath = [fm uniqueFilePathWithName:[targetPath stringByDeletingLastPathComponent] atPath:[targetPath lastPathComponent]];
                success = [fm createPathToFile:targetPath attributes:nil];
                if (success)
                success = [fm copyPath:filePath toPath:targetPath handler:nil];
            }
        }
        
        if (success) {
            NSTask *task = [[[NSTask alloc] init] autorelease];
            [task setLaunchPath:@"/usr/bin/tar"];
            [task setArguments:[NSArray arrayWithObjects:@"czf", [[fileURL path] lastPathComponent], [path lastPathComponent], nil]];
            [task setCurrentDirectoryPath:[path stringByDeletingLastPathComponent]];
            [task launch];
            if ([task isRunning])
                [task waitUntilExit];
            success = [task terminationStatus] == 0;
            [fm removeFileAtPath:path handler:nil];
        }
    }
    
    return success;
}

#pragma mark Data representations

- (NSFileWrapper *)fileWrapperOfType:(NSString *)aType error:(NSError **)outError
{
    return [self fileWrapperOfType:aType forPublications:publications error:outError];
}

- (NSFileWrapper *)fileWrapperOfType:(NSString *)aType forPublications:(NSArray *)items error:(NSError **)outError
{
    NSFileWrapper *fileWrapper = nil;
    
    // check if we need a fileWrapper; only needed for RTFD templates
    BDSKTemplate *selectedTemplate = [BDSKTemplate templateForStyle:aType];
    if([selectedTemplate templateFormat] & BDSKRTFDTemplateFormat){
        fileWrapper = [self fileWrapperForPublications:items usingTemplate:selectedTemplate];
        if(fileWrapper == nil){
            if (outError) 
                *outError = [NSError mutableLocalErrorWithCode:kBDSKDocumentSaveError localizedDescription:NSLocalizedString(@"Unable to create file wrapper for the selected template", @"Error description")];
        }
    }else if ([aType isEqualToString:BDSKArchiveDocumentType] || [aType isEqualToUTI:[[NSWorkspace sharedWorkspace] UTIForPathExtension:@"tgz"]]){
        BDSKASSERT_NOT_REACHED("Should not save a fileWrapper for archive");
    }else{
        NSError *error = nil;
        NSData *data = [self dataOfType:aType forPublications:items error:&error];
        if(data != nil && error == nil){
            fileWrapper = [[[NSFileWrapper alloc] initRegularFileWithContents:data] autorelease];
        } else {
            if(outError != NULL)
                *outError = error;
        }
    }
    return fileWrapper;
}

- (NSData *)dataOfType:(NSString *)aType error:(NSError **)outError
{
    return [self dataOfType:aType forPublications:publications error:outError];
}

- (NSData *)dataOfType:(NSString *)aType forPublications:(NSArray *)items error:(NSError **)outError
{
    NSData *data = nil;
    NSError *error = nil;
    NSStringEncoding encoding = [self documentStringEncoding];
    NSParameterAssert(encoding != 0);
    
    BOOL isBibTeX = [aType isEqualToString:BDSKBibTeXDocumentType] || [aType isEqualToUTI:[[NSWorkspace sharedWorkspace] UTIForPathExtension:@"bib"]];
    
    // export operations need their own encoding
    if(NSSaveToOperation == docState.currentSaveOperationType)
        encoding = [saveTextEncodingPopupButton encoding] ?: [BDSKStringEncodingManager defaultEncoding];
    
    if (isBibTeX){
        if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKAutoSortForCrossrefsKey])
            [self performSortForCrossrefs];
        data = [self bibTeXDataForPublications:items encoding:encoding droppingInternal:NO relativeToPath:[[saveTargetURL path] stringByDeletingLastPathComponent] error:&error];
    }else if ([aType isEqualToString:BDSKRISDocumentType] || [aType isEqualToUTI:[[NSWorkspace sharedWorkspace] UTIForPathExtension:@"ris"]]){
        data = [self RISDataForPublications:items encoding:encoding error:&error];
    }else if ([aType isEqualToString:BDSKMinimalBibTeXDocumentType]){
        data = [self bibTeXDataForPublications:items encoding:encoding droppingInternal:YES relativeToPath:[[saveTargetURL path] stringByDeletingLastPathComponent] error:&error];
    }else if ([aType isEqualToString:BDSKLTBDocumentType] || [aType isEqualToUTI:[[NSWorkspace sharedWorkspace] UTIForPathExtension:@"ltb"]]){
        data = [self LTBDataForPublications:items encoding:encoding error:&error];
    }else if ([aType isEqualToString:BDSKEndNoteDocumentType]){
        data = [self endNoteDataForPublications:items];
    }else if ([aType isEqualToString:BDSKMODSDocumentType] || [aType isEqualToUTI:[[NSWorkspace sharedWorkspace] UTIForPathExtension:@"mods"]]){
        data = [self MODSDataForPublications:items];
    }else if ([aType isEqualToString:BDSKAtomDocumentType] || [aType isEqualToUTI:[[NSWorkspace sharedWorkspace] UTIForPathExtension:@"atom"]]){
        data = [self atomDataForPublications:items];
    }else{
        BDSKTemplate *selectedTemplate = [BDSKTemplate templateForStyle:aType];
        NSParameterAssert(nil != selectedTemplate);
        BDSKTemplateFormat templateFormat = [selectedTemplate templateFormat];
        
        if (templateFormat & BDSKRTFDTemplateFormat) {
            // @@ shouldn't reach here, should have already redirected to fileWrapperOfType:forPublications:error:
        } else if ([selectedTemplate scriptPath] != nil) {
            data = [self dataForPublications:items usingTemplate:selectedTemplate];
        } else if (templateFormat & BDSKPlainTextTemplateFormat) {
            data = [self stringDataForPublications:items usingTemplate:selectedTemplate];
        } else {
            data = [self attributedStringDataForPublications:items usingTemplate:selectedTemplate];
        }
    }
    
    // grab the underlying error; if we recognize it, pass it up as a kBDSKDocumentSaveError
    if(nil == data && outError){
        // see if this was an encoding failure; if so, we can suggest how to fix it
        // NSLocalizedRecoverySuggestion is appropriate for display as error message in alert
        if(kBDSKStringEncodingError == [error code]){
            // encoding conversion failure (string to data)
            NSStringEncoding usedEncoding = [[error valueForKey:NSStringEncodingErrorKey] intValue];
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

- (NSData *)atomDataForPublications:(NSArray *)items{
    NSEnumerator *e = [items objectEnumerator];
	BibItem *pub = nil;
    NSMutableData *d = [NSMutableData data];
    
    [d appendUTF8DataFromString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><feed xmlns=\"http://purl.org/atom/ns#\">"];
    
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    
    // TODO: output general feed info
    
	while(pub = [e nextObject]){
        [d appendUTF8DataFromString:@"<entry><title>foo</title><description>foo-2</description>"];
        [d appendUTF8DataFromString:@"<content type=\"application/xml+mods\">"];
        [d appendUTF8DataFromString:[pub MODSString]];
        [d appendUTF8DataFromString:@"</content>"];
        [d appendUTF8DataFromString:@"</entry>\n"];
    }
    [d appendUTF8DataFromString:@"</feed>"];
    
    return d;    
}

- (NSData *)MODSDataForPublications:(NSArray *)items{
    NSEnumerator *e = [items objectEnumerator];
	BibItem *pub = nil;
    NSMutableData *d = [NSMutableData data];
    
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);

    [d appendUTF8DataFromString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><modsCollection xmlns=\"http://www.loc.gov/mods/v3\">"];
	while(pub = [e nextObject]){
        [d appendUTF8DataFromString:[pub MODSString]];
        [d appendUTF8DataFromString:@"\n"];
    }
    [d appendUTF8DataFromString:@"</modsCollection>"];
    
    return d;
}

- (NSData *)endNoteDataForPublications:(NSArray *)items{
    NSMutableData *d = [NSMutableData data];
    
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    
    [d appendUTF8DataFromString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<xml>\n<records>\n"];
    [d performSelector:@selector(appendUTF8DataFromString:) withObjectsByMakingObjectsFromArray:items performSelector:@selector(endNoteString)];
    [d appendUTF8DataFromString:@"</records>\n</xml>\n"];
    
    return d;
}

- (NSData *)bibTeXDataForPublications:(NSArray *)items encoding:(NSStringEncoding)encoding droppingInternal:(BOOL)drop relativeToPath:(NSString *)basePath error:(NSError **)outError{
    NSParameterAssert(encoding != 0);

    NSEnumerator *e = [items objectEnumerator];
	BibItem *pub = nil;
    NSMutableData *outputData = [NSMutableData dataWithCapacity:4096];
    NSData *pubData;
    NSError *error = nil;
    BOOL isOK = YES;
        
    BOOL shouldAppendFrontMatter = YES;
    NSString *encodingName = [NSString localizedNameOfStringEncoding:encoding];
    NSStringEncoding groupsEncoding = [[BDSKStringEncodingManager sharedEncodingManager] isUnparseableEncoding:encoding] ? encoding : NSUTF8StringEncoding;
    
    int options = 0;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldTeXifyWhenSavingAndCopyingKey])
        options |= BDSKBibTeXOptionTeXifyMask;
    if (drop)
        options |= BDSKBibTeXOptionDropInternalMask;
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldUseTemplateFileKey]){
        NSMutableString *templateFile = [NSMutableString stringWithContentsOfFile:[[[NSUserDefaults standardUserDefaults] stringForKey:BDSKOutputTemplateFileKey] stringByExpandingTildeInPath] usedEncoding:NULL error:NULL] ?: [NSMutableString string];
        
        NSString *userName = NSFullUserName();
        if ([userName canBeConvertedToEncoding:encoding] == NO)
            userName = [[[NSString alloc] initWithData:[userName dataUsingEncoding:encoding allowLossyConversion:YES] encoding:encoding] autorelease];
        
        [templateFile appendFormat:@"\n%%%% Created for %@ at %@ \n\n", userName, [NSCalendarDate calendarDate]];

        [templateFile appendFormat:@"\n%%%% Saved with string encoding %@ \n\n", encodingName];
        
        // remove all whitespace so we can make a comparison; just collapsing isn't quite good enough, unfortunately
        NSString *collapsedTemplate = [templateFile stringByRemovingWhitespace];
        NSString *collapsedFrontMatter = [frontMatter stringByRemovingWhitespace];
        if([NSString isEmptyString:collapsedFrontMatter]){
            shouldAppendFrontMatter = NO;
        }else if([collapsedTemplate rangeOfString:collapsedFrontMatter].length){
            NSLog(@"*** WARNING! *** Found duplicate preamble %@.  Using template from preferences.", frontMatter);
            shouldAppendFrontMatter = NO;
        }
        
        isOK = [outputData appendDataFromString:templateFile encoding:encoding error:&error];
        if(NO == isOK)
            [error setValue:NSLocalizedString(@"Unable to convert template string.", @"string encoding error context") forKey:NSLocalizedRecoverySuggestionErrorKey];
    }
    
    NSData *doubleNewlineData = [@"\n\n" dataUsingEncoding:encoding];

    // only append this if it wasn't redundant (this assumes that the original frontmatter is either a subset of the necessary frontmatter, or that the user's preferences should override in case of a conflict)
    if(isOK && shouldAppendFrontMatter){
        isOK = [outputData appendDataFromString:frontMatter encoding:encoding error:&error];
        if(NO == isOK)
            [error setValue:NSLocalizedString(@"Unable to convert file header.", @"string encoding error context") forKey:NSLocalizedRecoverySuggestionErrorKey];
        [outputData appendData:doubleNewlineData];
    }
        
    if(isOK && [documentInfo count]){
        isOK = [outputData appendDataFromString:[self documentInfoString] encoding:encoding error:&error];
        if(NO == isOK)
            [error setValue:NSLocalizedString(@"Unable to convert document info.", @"string encoding error context") forKey:NSLocalizedRecoverySuggestionErrorKey];
    }
    
    // output the document's macros:
    if(isOK){
        isOK = [outputData appendDataFromString:[[self macroResolver] bibTeXString] encoding:encoding error:&error];
        if(NO == isOK)
            [error setValue:NSLocalizedString(@"Unable to convert macros.", @"string encoding error context") forKey:NSLocalizedRecoverySuggestionErrorKey];
    }
    
    // output the bibs
    
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);

    while(isOK && (pub = [e nextObject])){
        pubData = [pub bibTeXDataWithOptions:options relativeToPath:basePath encoding:encoding error:&error];
        if(isOK = pubData != nil){
            [outputData appendData:doubleNewlineData];
            [outputData appendData:pubData];
        }else if([error valueForKey:NSLocalizedRecoverySuggestionErrorKey] == nil)
            [error setValue:[NSString stringWithFormat:NSLocalizedString(@"Unable to convert item with cite key %@.", @"string encoding error context"), [pub citeKey]] forKey:NSLocalizedRecoverySuggestionErrorKey];
    }
    
    if (drop == NO) {
        // The data from groups is always UTF-8, and we shouldn't convert it unless we have an unparseable encoding; the comment key strings should be representable in any encoding
        if(isOK && ([[groups staticGroups] count] > 0)){
            isOK = [outputData appendDataFromString:@"\n\n@comment{BibDesk Static Groups{\n" encoding:encoding error:&error] &&
                   [outputData appendStringData:[groups serializedGroupsDataOfType:BDSKStaticGroupType] convertedFromUTF8ToEncoding:groupsEncoding error:&error] &&
                   [outputData appendDataFromString:@"}}" encoding:encoding error:&error];
            if(NO == isOK)
                [error setValue:NSLocalizedString(@"Unable to convert static groups.", @"string encoding error context") forKey:NSLocalizedRecoverySuggestionErrorKey];
        }
        if(isOK && ([[groups smartGroups] count] > 0)){
            isOK = [outputData appendDataFromString:@"\n\n@comment{BibDesk Smart Groups{\n" encoding:encoding error:&error] &&
                   [outputData appendStringData:[groups serializedGroupsDataOfType:BDSKSmartGroupType] convertedFromUTF8ToEncoding:groupsEncoding error:&error] &&
                   [outputData appendDataFromString:@"}}" encoding:encoding error:&error];
                [error setValue:NSLocalizedString(@"Unable to convert smart groups.", @"string encoding error context") forKey:NSLocalizedRecoverySuggestionErrorKey];
        }
        if(isOK && ([[groups URLGroups] count] > 0)){
            isOK = [outputData appendDataFromString:@"\n\n@comment{BibDesk URL Groups{\n" encoding:encoding error:&error] &&
                   [outputData appendStringData:[groups serializedGroupsDataOfType:BDSKURLGroupType] convertedFromUTF8ToEncoding:groupsEncoding error:&error] &&
                   [outputData appendDataFromString:@"}}" encoding:encoding error:&error];
            if(NO == isOK)
                [error setValue:NSLocalizedString(@"Unable to convert external file groups.", @"string encoding error context") forKey:NSLocalizedRecoverySuggestionErrorKey];
        }
        if(isOK && ([[groups scriptGroups] count] > 0)){
            isOK = [outputData appendDataFromString:@"\n\n@comment{BibDesk Script Groups{\n" encoding:encoding error:&error] &&
                   [outputData appendStringData:[groups serializedGroupsDataOfType:BDSKScriptGroupType] convertedFromUTF8ToEncoding:groupsEncoding error:&error] &&
                   [outputData appendDataFromString:@"}}" encoding:encoding error:&error];
            if(NO == isOK)
                [error setValue:NSLocalizedString(@"Unable to convert script groups.", @"string encoding error context") forKey:NSLocalizedRecoverySuggestionErrorKey];
        }
    }
    
    if(isOK)
        [outputData appendDataFromString:@"\n" encoding:encoding error:&error];
        
    if (NO == isOK && outError != NULL) *outError = error;

    return isOK ? outputData : nil;
        
}

- (NSData *)RISDataForPublications:(NSArray *)items encoding:(NSStringEncoding)encoding error:(NSError **)error{

    NSParameterAssert(encoding);
    
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    NSString *RISString = [self RISStringForPublications:items];
    NSData *data = [RISString dataUsingEncoding:encoding allowLossyConversion:NO];
    if (nil == data && error) {
        *error = [NSError mutableLocalErrorWithCode:kBDSKStringEncodingError localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"Unable to convert the bibliography to encoding %@", @"Error description"), [NSString localizedNameOfStringEncoding:encoding]]];
        [*error setValue:[NSNumber numberWithInt:encoding] forKey:NSStringEncodingErrorKey];
    }
	return data;
}

- (NSData *)LTBDataForPublications:(NSArray *)items encoding:(NSStringEncoding)encoding error:(NSError **)error{

    NSParameterAssert(encoding);
    
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    
    NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];
    [pboardHelper declareType:NSStringPboardType dragCopyType:BDSKLTBDragCopyType forItems:items forPasteboard:pboard];
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
    
    NSData *data = [s dataUsingEncoding:encoding allowLossyConversion:NO];
    if (nil == data && error) {
        *error = [NSError mutableLocalErrorWithCode:kBDSKStringEncodingError localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"Unable to convert the bibliography to encoding %@", @"Error description"), [NSString localizedNameOfStringEncoding:encoding]]];
        [*error setValue:[NSNumber numberWithInt:encoding] forKey:NSStringEncodingErrorKey];
    }        
	return data;
}

- (NSData *)stringDataForPublications:(NSArray *)items usingTemplate:(BDSKTemplate *)template{
    return [self stringDataForPublications:items publicationsContext:nil usingTemplate:template];
}

- (NSData *)stringDataForPublications:(NSArray *)items publicationsContext:(NSArray *)itemsContext usingTemplate:(BDSKTemplate *)template{
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    
    BDSKPRECONDITION(nil != template && ([template templateFormat] & BDSKPlainTextTemplateFormat));
    
    NSString *fileTemplate = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:self publications:items publicationsContext:itemsContext];
    return [fileTemplate dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
}

- (NSData *)attributedStringDataForPublications:(NSArray *)items usingTemplate:(BDSKTemplate *)template{
    return [self attributedStringDataForPublications:items publicationsContext:nil usingTemplate:template];
}

- (NSData *)attributedStringDataForPublications:(NSArray *)items publicationsContext:(NSArray *)itemsContext usingTemplate:(BDSKTemplate *)template{
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    
    BDSKPRECONDITION(nil != template);
    BDSKTemplateFormat format = [template templateFormat];
    BDSKPRECONDITION(format & (BDSKRTFTemplateFormat | BDSKDocTemplateFormat | BDSKDocxTemplateFormat | BDSKOdtTemplateFormat | BDSKRichHTMLTemplateFormat));
    NSDictionary *docAttributes = nil;
    NSAttributedString *fileTemplate = [BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:self publications:items publicationsContext:itemsContext documentAttributes:&docAttributes];
    NSMutableDictionary *mutableAttributes = [NSMutableDictionary dictionaryWithDictionary:docAttributes];
    
    // create some useful metadata, with an option to disable for the paranoid
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKDisableExportAttributes"]){
        [mutableAttributes addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:NSFullUserName(), NSAuthorDocumentAttribute, [NSDate date], NSCreationTimeDocumentAttribute, [NSLocalizedString(@"BibDesk export of ", @"Error description") stringByAppendingString:[[self fileURL] lastPathComponent]], NSTitleDocumentAttribute, nil]];
    }
    
    if (format & BDSKRTFTemplateFormat) {
        return [fileTemplate RTFFromRange:NSMakeRange(0,[fileTemplate length]) documentAttributes:mutableAttributes];
    } else if (format & BDSKRichHTMLTemplateFormat) {
        [mutableAttributes setObject:NSHTMLTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
        NSError *error = nil;
        return [fileTemplate dataFromRange:NSMakeRange(0,[fileTemplate length]) documentAttributes:mutableAttributes error:&error];
    } else if (format & BDSKDocTemplateFormat) {
        return [fileTemplate docFormatFromRange:NSMakeRange(0,[fileTemplate length]) documentAttributes:mutableAttributes];
    } else if ((format & BDSKDocxTemplateFormat) && floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
        [mutableAttributes setObject:@"NSOfficeOpenXML" forKey:NSDocumentTypeDocumentAttribute];
        NSError *error = nil;
        return [fileTemplate dataFromRange:NSMakeRange(0,[fileTemplate length]) documentAttributes:mutableAttributes error:&error];
    } else if ((format & BDSKOdtTemplateFormat) && floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
        [mutableAttributes setObject:@"NSOpenDocument" forKey:NSDocumentTypeDocumentAttribute];
        NSError *error = nil;
        return [fileTemplate dataFromRange:NSMakeRange(0,[fileTemplate length]) documentAttributes:mutableAttributes error:&error];
    } else return nil;
}

- (NSData *)dataForPublications:(NSArray *)items usingTemplate:(BDSKTemplate *)template{
    return [self dataForPublications:items publicationsContext:nil usingTemplate:template];
}

- (NSData *)dataForPublications:(NSArray *)items publicationsContext:(NSArray *)itemsContext usingTemplate:(BDSKTemplate *)template{
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    
    BDSKPRECONDITION(nil != template && nil != [template scriptPath]);
    
    NSData *fileTemplate = [BDSKTemplateObjectProxy dataByParsingTemplate:template withObject:self publications:items publicationsContext:itemsContext];
    return fileTemplate;
}

- (NSFileWrapper *)fileWrapperForPublications:(NSArray *)items usingTemplate:(BDSKTemplate *)template{
    return [self fileWrapperForPublications:items publicationsContext:nil usingTemplate:template];
}

- (NSFileWrapper *)fileWrapperForPublications:(NSArray *)items publicationsContext:(NSArray *)itemsContext usingTemplate:(BDSKTemplate *)template{
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    
    BDSKPRECONDITION(nil != template && [template templateFormat] & BDSKRTFDTemplateFormat);
    NSDictionary *docAttributes = nil;
    NSAttributedString *fileTemplate = [BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:self publications:items publicationsContext:itemsContext documentAttributes:&docAttributes];
    
    return [fileTemplate RTFDFileWrapperFromRange:NSMakeRange(0,[fileTemplate length]) documentAttributes:docAttributes];
}

#pragma mark -
#pragma mark Opening and Loading Files

- (BOOL)revertToContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)aType error:(NSError **)outError
{
	// first remove all editor windows, as they will be invalid afterwards
    unsigned int idx = [[self windowControllers] count];
    while(--idx)
        [[[self windowControllers] objectAtIndex:idx] close];
    
    if([super revertToContentsOfURL:absoluteURL ofType:aType error:outError]){
        [self setSearchString:@""];
        [self updateSmartGroupsCountAndContent:NO];
        [self updateCategoryGroupsPreservingSelection:YES];
        [self sortGroupsByKey:sortGroupsKey]; // resort
		[tableView deselectAll:self]; // clear before resorting
		[self search:searchField]; // redo the search
        [self sortPubsByKey:nil]; // resort
		return YES;
	}
	return NO;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)aType error:(NSError **)outError
{
    NSStringEncoding encoding = [BDSKStringEncodingManager defaultEncoding];
    return [self readFromURL:absoluteURL ofType:aType encoding:encoding error:outError];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)aType encoding:(NSStringEncoding)encoding error:(NSError **)outError
{
    BOOL success;
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:absoluteURL options:NSUncachedRead error:&error];
    if (nil == data) {
        if (outError) *outError = error;
        return NO;
    }
    
    // make sure we clear all macros and groups that are saved in the file, should only have those for revert
    // better do this here, so we don't remove them when reading the data fails
    [macroResolver removeAllMacros];
    [groups removeAllNonSharedGroups]; // this also removes spinners and editor windows for external groups
    [frontMatter setString:@""];
    
    // This is only a sanity check; an encoding of 0 is not valid, so is a signal we should ignore xattrs; could only check for public.text UTIs, but it will be zero if it was never written (and we don't warn in that case).  The user can do many things to make the attribute incorrect, so this isn't very robust.
    NSStringEncoding encodingFromFile = [[self mainWindowSetupDictionaryFromExtendedAttributes] unsignedIntForKey:BDSKDocumentStringEncodingKey defaultValue:0];
    if (encodingFromFile != 0 && encodingFromFile != encoding) {
        
        int rv;
        
        error = [NSError mutableLocalErrorWithCode:kBDSKStringEncodingError localizedDescription:NSLocalizedString(@"Incorrect encoding", @"Message in alert dialog when opening a document with different encoding")];
        [error setValue:[NSString stringWithFormat:NSLocalizedString(@"BibDesk tried to open the document using encoding %@, but it should have been opened with encoding %@.", @"Informative text in alert dialog when opening a document with different encoding"), [NSString localizedNameOfStringEncoding:encoding], [NSString localizedNameOfStringEncoding:encodingFromFile]] forKey:NSLocalizedRecoverySuggestionErrorKey];
        [error setValue:absoluteURL forKey:NSURLErrorKey];
        [error setValue:[NSNumber numberWithUnsignedInt:encoding] forKey:NSStringEncodingErrorKey];
        
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
    
	if ([aType isEqualToString:BDSKBibTeXDocumentType] || [aType isEqualToUTI:[[NSWorkspace sharedWorkspace] UTIForPathExtension:@"bib"]]){
        success = [self readFromBibTeXData:data fromURL:absoluteURL encoding:encoding error:&error];
    }else{
		// sniff the string to see what format we got
		NSString *string = [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
		if(string == nil){
            error = [NSError mutableLocalErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Unable To Open Document", @"Error description")];
            [error setValue:NSLocalizedString(@"This document does not appear to be a text file.", @"Error informative text") forKey:NSLocalizedRecoverySuggestionErrorKey];
            if(outError) *outError = error;
            
            // bypass the partial data warning, since we have no data
			return NO;
        }
        int type = [string contentStringType];
        if(type == BDSKBibTeXStringType){
            success = [self readFromBibTeXData:data fromURL:absoluteURL encoding:encoding error:&error];
		}else if (type == BDSKNoKeyBibTeXStringType){
            error = [NSError mutableLocalErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Unable To Open Document", @"Error description")];
            [error setValue:NSLocalizedString(@"This file appears to contain invalid BibTeX because of missing cite keys. Try to open using temporary cite keys to fix this.", @"Error informative text") forKey:NSLocalizedRecoverySuggestionErrorKey];
            if (outError) *outError = error;
            
            // bypass the partial data warning; we have no data in this case
            return NO;
		}else if (type == BDSKUnknownStringType){
            error = [NSError mutableLocalErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Unable To Open Document", @"Error description")];
            [error setValue:NSLocalizedString(@"This text file does not contain a recognized data type.", @"Error informative text") forKey:NSLocalizedRecoverySuggestionErrorKey];
            if (outError) *outError = error;
            
            // bypass the partial data warning; we have no data in this case
            return NO;
        }else{
            success = [self readFromData:data ofStringType:type fromURL:absoluteURL encoding:encoding error:&error];
        }

	}
    
    // @@ move this to NSDocumentController; need to figure out where to add it, though
    if(success == NO){
        int rv;
        // run a modal dialog asking if we want to use partial data or give up
        NSAlert *alert = [NSAlert alertWithMessageText:[error localizedDescription] ?: NSLocalizedString(@"Error reading file!", @"Message in alert dialog when unable to read file")
                                         defaultButton:NSLocalizedString(@"Give Up", @"Button title")
                                       alternateButton:NSLocalizedString(@"Edit File", @"Button title")
                                           otherButton:NSLocalizedString(@"Keep Going", @"Button title")
                             informativeTextWithFormat:NSLocalizedString(@"There was a problem reading the file.  Do you want to give up, edit the file to correct the errors, or keep going with everything that could be analyzed?\n\nIf you choose \"Keep Going\" and then save the file, you will probably lose data.", @"Informative text in alert dialog")];
        [alert setAlertStyle:NSCriticalAlertStyle];
        rv = [alert runModal];
        if (rv == NSAlertDefaultReturn) {
            // the user said to give up
            [[BDSKErrorObjectController sharedErrorObjectController] documentFailedLoad:self shouldEdit:NO]; // this hands the errors to a new error editor and sets that as the documentForErrors
        }else if (rv == NSAlertAlternateReturn){
            // the user said to edit the file.
            [[BDSKErrorObjectController sharedErrorObjectController] documentFailedLoad:self shouldEdit:YES]; // this hands the errors to a new error editor and sets that as the documentForErrors
        }else if(rv == NSAlertOtherReturn){
            // the user said to keep going, so if they save, they might clobber data...
            // if we don't return YES, NSDocumentController puts up its lame alert saying the document could not be opened, and we get no partial data
            success = YES;
        }
    }
    if(outError) *outError = error;
    return success;        
}

- (BOOL)readFromBibTeXData:(NSData *)data fromURL:(NSURL *)absoluteURL encoding:(NSStringEncoding)encoding error:(NSError **)outError {
    NSString *filePath = [absoluteURL path];
    NSStringEncoding parserEncoding = [[BDSKStringEncodingManager sharedEncodingManager] isUnparseableEncoding:encoding] ? NSUTF8StringEncoding : encoding;
    
    [self setDocumentStringEncoding:encoding];
    
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
	NSArray *newPubs = [BDSKBibTeXParser itemsFromData:data frontMatter:frontMatter filePath:filePath document:self encoding:parserEncoding isPartialData:&isPartialData error:&error];
	if(isPartialData && outError) *outError = error;	
    [self setPublicationsWithoutUndo:newPubs];
    
    return isPartialData == NO;
}

- (BOOL)readFromData:(NSData *)data ofStringType:(int)type fromURL:(NSURL *)absoluteURL encoding:(NSStringEncoding)encoding error:(NSError **)outError {
    
    NSError *error = nil;    
    NSString *dataString = [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
    NSArray *newPubs = nil;
    
    if(dataString == nil){
        error = [NSError mutableLocalErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Unable to Interpret", @"Error description")];
        [error setValue:[NSString stringWithFormat:NSLocalizedString(@"Unable to interpret data as %@.  Try a different encoding.", @"Error informative text"), [NSString localizedNameOfStringEncoding:encoding]] forKey:NSLocalizedRecoverySuggestionErrorKey];
        [error setValue:[NSNumber numberWithInt:encoding] forKey:NSStringEncodingErrorKey];
        if(outError) *outError = error;
        return NO;
    }
    
	newPubs = [BDSKStringParser itemsFromString:dataString ofType:type error:&error];
        
    if(outError) *outError = error;
    [self setPublicationsWithoutUndo:newPubs];
    
    // since we can't save other files in their native format (BibTeX is handled separately)
    if (type != BDSKRISStringType)
        [self setFileName:nil];
    
    return newPubs != nil;
}

#pragma mark -

- (void)setDocumentStringEncoding:(NSStringEncoding)encoding{
    docState.documentStringEncoding = encoding;
}

- (NSStringEncoding)documentStringEncoding{
    return docState.documentStringEncoding;
}

#pragma mark -

- (void)temporaryCiteKeysAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
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
	NSEnumerator *e = [items objectEnumerator];
	BibItem *pub;
	int options = 0;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldTeXifyWhenSavingAndCopyingKey])
        options |= BDSKBibTeXOptionTeXifyMask;
    if (drop)
        options |= BDSKBibTeXOptionDropInternalMask;
    
    while(pub = [e nextObject])
            [s appendStrings:@"\n", [pub bibTeXStringWithOptions:options], @"\n", nil];
	
	return s;
}

- (NSString *)previewBibTeXStringForPublications:(NSArray *)items{
    
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);

	unsigned numberOfPubs = [items count];
	NSMutableString *bibString = [[NSMutableString alloc] initWithCapacity:(numberOfPubs * 100)];
    
    int options = BDSKBibTeXOptionDropLinkedURLsMask;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldTeXifyWhenSavingAndCopyingKey])
        options |= BDSKBibTeXOptionTeXifyMask;
    
	// in case there are @preambles in it
	[bibString appendString:frontMatter];
	[bibString appendString:@"\n"];
	
    [bibString appendString:[[BDSKMacroResolver defaultMacroResolver] bibTeXString]];
    [bibString appendString:[[self macroResolver] bibTeXString]];
	
	NSEnumerator *e = [items objectEnumerator];
	BibItem *aPub = nil;
	BibItem *aParent = nil;
	NSMutableArray *selItems = [[NSMutableArray alloc] initWithCapacity:numberOfPubs];
	NSMutableSet *parentItems = [[NSMutableSet alloc] initWithCapacity:numberOfPubs];
	NSMutableArray *selParentItems = [[NSMutableArray alloc] initWithCapacity:numberOfPubs];
    
	while(aPub = [e nextObject]){
		[selItems addObject:aPub];

		if(aParent = [aPub crossrefParent])
			[parentItems addObject:aParent];
	}
	
	e = [selItems objectEnumerator];
	while(aPub = [e nextObject]){
		if([parentItems containsObject:aPub]){
			[parentItems removeObject:aPub];
			[selParentItems addObject:aPub];
		}else{
            [bibString appendString:[aPub bibTeXStringWithOptions:options]];
		}
	}
	
	e = [selParentItems objectEnumerator];
	while(aPub = [e nextObject]){
        [bibString appendString:[aPub bibTeXStringWithOptions:options]];
	}
	
	e = [parentItems objectEnumerator];        
	while(aPub = [e nextObject]){
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
	NSString *startCite = [NSString stringWithFormat:@"%@\\%@%@", ([sud boolForKey:BDSKCitePrependTildeKey] ? @"~" : @""), citeString, [sud stringForKey:BDSKCiteStartBracketKey]]; 
	NSString *endCite = [sud stringForKey:BDSKCiteEndBracketKey]; 
	NSString *separator = [sud boolForKey:BDSKSeparateCiteKey] ? [endCite stringByAppendingString:startCite] : @",";
    
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    
    return [NSString stringWithFormat:@"%@%@%@", startCite, [[items valueForKey:@"citeKey"] componentsJoinedByString:separator], endCite];
}

#pragma mark -
#pragma mark New publications from pasteboard

- (void)addPublications:(NSArray *)newPubs publicationsToAutoFile:(NSArray *)pubsToAutoFile temporaryCiteKey:(NSString *)tmpCiteKey selectLibrary:(BOOL)shouldSelect edit:(BOOL)shouldEdit {
    NSEnumerator *pubEnum;
    BibItem *pub;
    
    if (shouldSelect)
        [self selectLibraryGroup:nil];    
	[self addPublications:newPubs];
    if ([self hasLibraryGroupSelected])
        [self selectPublications:newPubs];
	if (pubsToAutoFile != nil){
        // tried checking [pb isEqual:[NSPasteboard pasteboardWithName:NSDragPboard]] before using delay, but pb is a CFPasteboardUnique
        pubEnum = [pubsToAutoFile objectEnumerator];
        while (pub = [pubEnum nextObject])
            [pub performSelector:@selector(autoFileLinkedFile:) withObjectsFromArray:[pub localFiles]];
    }
    
    BOOL autoGenerate = [[NSUserDefaults standardUserDefaults] boolForKey:BDSKCiteKeyAutogenerateKey];
    NSMutableArray *pubs = [NSMutableArray arrayWithCapacity:[newPubs count]];
    
    pubEnum = [newPubs objectEnumerator];
    
    while (pub = [pubEnum nextObject]) {
        if ((autoGenerate == NO && [pub hasEmptyOrDefaultCiteKey]) ||
            (autoGenerate && [pub canGenerateAndSetCiteKey])) // @@ or should we check for hasEmptyOrDefaultCiteKey ?
            [pubs addObject:pub];
    }
    [self generateCiteKeysForPublications:pubs];
    
    // set Date-Added to the current date, since unarchived items will have their own (incorrect) date
    NSCalendarDate *importDate = [NSCalendarDate date];
    [newPubs makeObjectsPerformSelector:@selector(setField:toValue:) withObject:BDSKDateAddedString withObject:[importDate description]];
	
	if(shouldEdit) {
		[self editPublications:newPubs]; // this will ask the user when there are many pubs
	}
	
	[[self undoManager] setActionName:NSLocalizedString(@"Add Publication", @"Undo action name")];
    
    NSMutableArray *importedItems = [NSMutableArray array];
    if (shouldSelect == NO && docState.didImport)
        [importedItems addObjectsFromArray:[[groups lastImportGroup] publications]];
    docState.didImport = (shouldSelect == NO);
    [importedItems addObjectsFromArray:newPubs];
    
    // set up the smart group that shows the latest import
    // @@ do this for items added via the editor?  doesn't seem as useful
    [groups setLastImportedPublications:importedItems];

	[[BDSKScriptHookManager sharedManager] runScriptHookWithName:BDSKImportPublicationsScriptHookName forPublications:newPubs document:self];
    
    if(tmpCiteKey != nil)
        [self reportTemporaryCiteKeys:tmpCiteKey forNewDocument:NO];
}

- (BOOL)addPublicationsFromPasteboard:(NSPasteboard *)pb selectLibrary:(BOOL)shouldSelect verbose:(BOOL)verbose error:(NSError **)outError{
	// these are the types we support, the order here is important!
    NSString *type = [pb availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, BDSKWeblocFilePboardType, BDSKReferenceMinerStringPboardType, NSStringPboardType, NSFilenamesPboardType, NSURLPboardType, nil]];
    NSArray *newPubs = nil;
    NSArray *newFilePubs = nil;
	NSError *error = nil;
    NSString *temporaryCiteKey = nil;
    BOOL shouldEdit = [[NSUserDefaults standardUserDefaults] boolForKey:BDSKEditOnPasteKey];
    
    if([type isEqualToString:BDSKBibItemPboardType]){
        NSData *pbData = [pb dataForType:BDSKBibItemPboardType];
		newPubs = [self publicationsFromArchivedData:pbData];
    } else if([type isEqualToString:BDSKReferenceMinerStringPboardType]){ // pasteboard type from Reference Miner, determined using Pasteboard Peeker
        NSString *pbString = [pb stringForType:BDSKReferenceMinerStringPboardType]; 	
        // sniffing the string for RIS is broken because RefMiner puts junk at the beginning
		newPubs = [self publicationsForString:pbString type:BDSKReferenceMinerStringType verbose:verbose error:&error];
        if(temporaryCiteKey = [[error userInfo] valueForKey:@"temporaryCiteKey"])
            error = nil; // accept temporary cite keys, but show a warning later
    }else if([type isEqualToString:NSStringPboardType]){
        NSString *pbString = [pb stringForType:NSStringPboardType]; 	
		// sniff the string to see what its type is
		newPubs = [self publicationsForString:pbString type:BDSKUnknownStringType verbose:verbose error:&error];
        if(temporaryCiteKey = [[error userInfo] valueForKey:@"temporaryCiteKey"])
            error = nil; // accept temporary cite keys, but show a warning later
    }else if([type isEqualToString:NSFilenamesPboardType]){
		NSArray *pbArray = [pb propertyListForType:NSFilenamesPboardType]; // we will get an array
        // try this first, in case these files are a type we can open
        NSMutableArray *unparseableFiles = [[NSMutableArray alloc] initWithCapacity:[pbArray count]];
        newPubs = [self extractPublicationsFromFiles:pbArray unparseableFiles:unparseableFiles verbose:verbose error:&error];
		if(temporaryCiteKey = [[error userInfo] objectForKey:@"temporaryCiteKey"])
            error = nil; // accept temporary cite keys, but show a warning later
        if ([unparseableFiles count] > 0) {
            newFilePubs = [self publicationsForFiles:unparseableFiles error:&error];
            newPubs = [newPubs arrayByAddingObjectsFromArray:newFilePubs];
        }
        [unparseableFiles release];
    }else if([type isEqualToString:BDSKWeblocFilePboardType]){
        NSURL *pbURL = [NSURL URLWithString:[pb stringForType:BDSKWeblocFilePboardType]]; 	
		if([pbURL isFileURL])
            newPubs = newFilePubs = [self publicationsForFiles:[NSArray arrayWithObject:[pbURL path]] error:&error];
        else
            newPubs = [self publicationsForURLFromPasteboard:pb error:&error];
    }else if([type isEqualToString:NSURLPboardType]){
        NSURL *pbURL = [NSURL URLFromPasteboard:pb]; 	
		if([pbURL isFileURL])
            newPubs = newFilePubs = [self publicationsForFiles:[NSArray arrayWithObject:[pbURL path]] error:&error];
        else
            newPubs = [self publicationsForURLFromPasteboard:pb error:&error];
	}else{
        // errors are key, value
        error = [NSError localErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Did not find anything appropriate on the pasteboard", @"Error description")];
	}
    
    if (newPubs == nil){
        if(outError) *outError = error;
		return NO;
    }else if ([newPubs count] > 0) 
		[self addPublications:newPubs publicationsToAutoFile:newFilePubs temporaryCiteKey:temporaryCiteKey selectLibrary:shouldSelect edit:shouldEdit];
    
    return YES;
}

- (BOOL)addPublicationsFromFile:(NSString *)fileName verbose:(BOOL)verbose error:(NSError **)outError{
    NSError *error = nil;
    NSString *temporaryCiteKey = nil;
    NSArray *newPubs = [self extractPublicationsFromFiles:[NSArray arrayWithObject:fileName] unparseableFiles:nil verbose:verbose error:&error];
    BOOL shouldEdit = [[NSUserDefaults standardUserDefaults] boolForKey:BDSKEditOnPasteKey];
    
    if(temporaryCiteKey = [[error userInfo] valueForKey:@"temporaryCiteKey"])
        error = nil; // accept temporary cite keys, but show a warning later
    
    if([newPubs count] == 0){
        if(outError) *outError = error;
        return NO;
    }
    
    [self addPublications:newPubs publicationsToAutoFile:nil temporaryCiteKey:temporaryCiteKey selectLibrary:YES edit:shouldEdit];
    
    return YES;
}

- (NSArray *)publicationsFromArchivedData:(NSData *)data{
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    
    [NSString setMacroResolverForUnarchiving:macroResolver];
    
    NSArray *newPubs = [unarchiver decodeObjectForKey:@"publications"];
    [unarchiver finishDecoding];
    [unarchiver release];
    
    [NSString setMacroResolverForUnarchiving:nil];
    
    return newPubs;
}

// pass BDSKUnkownStringType to allow BDSKStringParser to sniff the text and determine the format
- (NSArray *)publicationsForString:(NSString *)string type:(int)type verbose:(BOOL)verbose error:(NSError **)outError {
    NSArray *newPubs = nil;
    NSError *parseError = nil;
    BOOL isPartialData = NO;
    
    // @@ BDSKStringParser doesn't handle any BibTeX types, so it's not really useful as a funnel point for any string type, since each usage requires special casing for BibTeX.
    if(BDSKUnknownStringType == type)
        type = [string contentStringType];
    
    if(type == BDSKBibTeXStringType){
        newPubs = [BDSKBibTeXParser itemsFromString:string document:self isPartialData:&isPartialData error:&parseError];
    }else if(type == BDSKNoKeyBibTeXStringType){
        newPubs = [BDSKBibTeXParser itemsFromString:[string stringWithPhoneyCiteKeys:@"FixMe"] document:self isPartialData:&isPartialData error:&parseError];
	}else {
        // this will create the NSError if the type is unrecognized
        newPubs = [BDSKStringParser itemsFromString:string ofType:type error:&parseError];
    }
    
	if(nil == newPubs || isPartialData) {
        
        if (verbose) {
        // @@ should just be able to create an alert from the NSError, unless it's unknown type
        NSString *message = nil;
        NSString *defaultButton = NSLocalizedString(@"Cancel", @"");
        NSString *alternateButton = nil;
        NSString *otherButton = nil;
        NSString *alertTitle = NSLocalizedString(@"Error Reading String", @"Message in alert dialog when failing to parse dropped or copied string");
        int errorCode = [parseError code];
        
        // the partial data alert only applies to BibTeX; we could show the editor window for non-BibTeX data (I think...), but we also have to deal with alerts being shown twice if NSError is involved
        if(type == BDSKBibTeXStringType || type == BDSKNoKeyBibTeXStringType){
            // here we want to display an alert, but don't propagate a nil/error back up, since it's not a failure
            if (errorCode == kBDSKParserIgnoredFrontMatter) {
                message = [parseError localizedRecoverySuggestion];
                alertTitle = [parseError localizedDescription];
                defaultButton = nil;
                // @@ fixme: NSError
                parseError = nil;
            } else {
                // this was BibTeX, but the user may want to try going with partial data
                message = NSLocalizedString(@"There was a problem inserting the data. Do you want to ignore this data, open a window containing the data to edit it and remove the errors, or keep going and use everything that BibDesk could parse?\n(It's likely that choosing \"Keep Going\" will lose some data.)", @"Informative text in alert dialog");
                alternateButton = NSLocalizedString(@"Edit data", @"Button title");
                otherButton = NSLocalizedString(@"Keep going", @"Button title");
            }
            
            // run a modal dialog asking if we want to use partial data or give up
            NSAlert *alert = [NSAlert alertWithMessageText:alertTitle
                                             defaultButton:defaultButton
                                           alternateButton:alternateButton
                                               otherButton:otherButton
                                 informativeTextWithFormat:message];
            int rv = [alert runModal];
            
            if(rv == NSAlertDefaultReturn && errorCode != kBDSKParserIgnoredFrontMatter){
                // the user said to give up
                newPubs = nil;
            }else if (rv == NSAlertAlternateReturn){
                // they said to edit the file.
                [[BDSKErrorObjectController sharedErrorObjectController] showEditorForLastPasteDragError];
                newPubs = nil;	
            }else if(rv == NSAlertOtherReturn){
                // the user said to keep going, so if they save, they might clobber data...
                // @@ should we ignore the error as well?
            }
            
        }
        
        // if not BibTeX, it's an unknown type or failed due to parser error; in either case, we must have a valid NSError since the parser returned nil
        // no partial data here since that only applies to BibTeX parsing; all we can do is just return nil and propagate the error back up, although I suppose we could display the error editor...
		} else {
            newPubs = nil;
        }
        
	}else if(type == BDSKNoKeyBibTeXStringType){
        
        BDSKASSERT(parseError == nil);
        
        // return an error when we inserted temporary keys, let the caller decide what to do with it
        // don't override a parseError though, as that is probably more relevant
        parseError = [NSError mutableLocalErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Temporary Cite Keys", @"Error description")];
        [parseError setValue:@"FixMe" forKey:@"temporaryCiteKey"];
    }
    
	if(outError) *outError = parseError;
    return newPubs;
}

// sniff the contents of each file, returning them in an array of BibItems, while unparseable files are added to the mutable array passed as a parameter
- (NSArray *)extractPublicationsFromFiles:(NSArray *)filenames unparseableFiles:(NSMutableArray *)unparseableFiles verbose:(BOOL)verbose error:(NSError **)outError {
    NSEnumerator *e = [filenames objectEnumerator];
    NSString *fileName;
    NSString *contentString;
    NSMutableArray *array = [NSMutableArray array];
    int type = BDSKUnknownStringType;
    
    // some common types that people might use as attachments; we don't need to sniff these
    NSSet *unreadableTypes = [NSSet caseInsensitiveStringSetWithObjects:@"pdf", @"ps", @"eps", @"doc", @"htm", @"textClipping", @"webloc", @"html", @"rtf", @"tiff", @"tif", @"png", @"jpg", @"jpeg", nil];
    
    while(fileName = [e nextObject]){
        type = BDSKUnknownStringType;
        
        // we /can/ create a string from these (usually), but there's no point in wasting the memory
        
        NSString *theUTI = [[NSWorkspace sharedWorkspace] UTIForURL:[NSURL fileURLWithPath:fileName]];
        if([theUTI isEqualToUTI:@"net.sourceforge.bibdesk.bdsksearch"]){
            NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:fileName];
            Class aClass = NSClassFromString([dictionary objectForKey:@"class"]);
            BDSKSearchGroup *group = [[[(aClass ?: [BDSKSearchGroup class]) alloc] initWithDictionary:dictionary] autorelease];
            if(group)
                [groups addSearchGroup:group];
        }else if([unreadableTypes containsObject:[fileName pathExtension]]){
            [unparseableFiles addObject:fileName];
        }else {
        
            // try to create a string
            contentString = [[NSString alloc] initWithContentsOfFile:fileName encoding:[self documentStringEncoding] guessEncoding:YES];
            
            if(contentString != nil){
                if([theUTI isEqualToUTI:@"org.tug.tex.bibtex"])
                    type = BDSKBibTeXStringType;
                else if([theUTI isEqualToUTI:@"net.sourceforge.bibdesk.ris"])
                    type = BDSKRISStringType;
                else
                    type = [contentString contentStringType];
                
                NSError *parseError = nil;
                NSArray *contentArray = (type == BDSKUnknownStringType) ? nil : [self publicationsForString:contentString type:type verbose:verbose error:&parseError];
                
                if(contentArray == nil){
                    // unable to parse, we link the file and can ignore the error
                    [unparseableFiles addObject:fileName];
                } else {
                    // forward any temporaryCiteKey warning
                    if(parseError && outError) *outError = parseError;
                    [array addObjectsFromArray:contentArray];
                }
                
                [contentString release];
                contentString = nil;
                
            } else {
                // unable to create the string
                [unparseableFiles addObject:fileName];
            }
        }
    }

    return array;
}

- (NSArray *)publicationsForFiles:(NSArray *)filenames error:(NSError **)error {
    NSMutableArray *newPubs = [NSMutableArray arrayWithCapacity:[filenames count]];
	NSEnumerator *e = [filenames objectEnumerator];
	NSString *fnStr = nil;
	NSURL *url = nil;
    	
	while(fnStr = [e nextObject]){
        fnStr = [fnStr stringByStandardizingPath];
		if(url = [NSURL fileURLWithPath:fnStr]){
            NSError *xerror = nil;
            BibItem *newBI = nil;
            
            // most reliable metadata should be our private EA
            if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKReadExtendedAttributesKey]){
                NSData *btData = [[SKNExtendedAttributeManager sharedNoSplitManager] extendedAttributeNamed:OMNI_BUNDLE_IDENTIFIER @".bibtexstring" atPath:fnStr traverseLink:NO error:&xerror];
                if(btData){
                    NSString *btString = [[NSString alloc] initWithData:btData encoding:NSUTF8StringEncoding];
                    BOOL isPartialData;
                    NSArray *items = [BDSKBibTeXParser itemsFromString:btString document:self isPartialData:&isPartialData error:&xerror];
                    newBI = isPartialData ? nil : [items firstObject];
                    [btString release];
                }
            }
            
			// GJ try parsing pdf to extract info that is then used to get a PubMed record
			if(newBI == nil && [[[NSWorkspace sharedWorkspace] UTIForURL:url] isEqualToUTI:(NSString *)kUTTypePDF] && [[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldParsePDFToGeneratePubMedSearchTermKey])
				newBI = [BibItem itemByParsingPDFFile:fnStr];			
			
            // fall back on the least reliable metadata source (hidden pref)
            if(newBI == nil && [[[NSWorkspace sharedWorkspace] UTIForURL:url] isEqualToUTI:(NSString *)kUTTypePDF] && [[NSUserDefaults standardUserDefaults] boolForKey:BDSKShouldUsePDFMetadataKey])
                newBI = [BibItem itemWithPDFMetadata:[PDFMetadata metadataForURL:url error:&xerror]];
			
            if(newBI == nil)
                newBI = [[[BibItem alloc] init] autorelease];
            
            [newBI addFileForURL:url autoFile:NO runScriptHook:NO];
			[newPubs addObject:newBI];
		}
	}
	
	return newPubs;
}

- (NSArray *)publicationsForURLFromPasteboard:(NSPasteboard *)pboard error:(NSError **)error {
    
    NSMutableArray *pubs = nil;
    
    NSURL *theURL = [WebView URLFromPasteboard:pboard];
    if (theURL) {
        BibItem *newBI = [[[BibItem alloc] init] autorelease];
        pubs = [NSMutableArray array];
        [newBI addFileForURL:theURL autoFile:NO runScriptHook:YES];
        [newBI setPubType:@"webpage"];
        [newBI setField:@"Lastchecked" toValue:[[NSCalendarDate date] dateDescription]];
        NSString *title = [WebView URLTitleFromPasteboard:pboard];
        if (title)
            [newBI setField:BDSKTitleString toValue:title];
        [pubs addObject:newBI];
    } else if (error) {
        *error = [NSError localErrorWithCode:kBDSKParserFailed localizedDescription:NSLocalizedString(@"Did not find expected URL on the pasteboard", @"Error description")];
    }
    
	return pubs;
}

#pragma mark -
#pragma mark BDSKItemPasteboardHelper delegate

- (void)pasteboardHelperWillBeginGenerating:(BDSKItemPasteboardHelper *)helper{
	[self setStatus:[NSLocalizedString(@"Generating data. Please wait", @"Status message when generating drag/paste data") stringByAppendingEllipsis]];
	[statusBar startAnimation:nil];
}

- (void)pasteboardHelperDidEndGenerating:(BDSKItemPasteboardHelper *)helper{
	[statusBar stopAnimation:nil];
	[self updateStatus];
}

- (NSString *)pasteboardHelper:(BDSKItemPasteboardHelper *)pboardHelper bibTeXStringForItems:(NSArray *)items{
    return [self previewBibTeXStringForPublications:items];
}

#pragma mark -
#pragma mark Sorting

- (void)sortPubsByKey:(NSString *)key{
    
    NSTableColumn *tableColumn = nil;
    
    // cache the selection; this works for multiple publications
    NSArray *pubsToSelect = nil;
    if([tableView numberOfSelectedRows])
        pubsToSelect = [shownPublications objectsAtIndexes:[tableView selectedRowIndexes]];
    
    // a nil argument means resort the current column in the same order
    if(key == nil){
        if(sortKey == nil)
            return;
        key = sortKey;
        docState.sortDescending = !docState.sortDescending; // we'll reverse this again in the next step
    }
    
    tableColumn = [tableView tableColumnWithIdentifier:key];
    
    if ([sortKey isEqualToString:key]) {
        // User clicked same column, change sort order
        docState.sortDescending = !docState.sortDescending;
    } else {
        // User clicked new column, change old/new column headers,
        // save new sorting selector, and re-sort the array.
        docState.sortDescending = [key isEqualToString:BDSKRelevanceString];
        if (sortKey)
            [tableView setIndicatorImage:nil inTableColumn:[tableView tableColumnWithIdentifier:sortKey]];
        if([previousSortKey isEqualToString:sortKey] == NO){
            [previousSortKey release];
            previousSortKey = sortKey; // this is retained
        }else{
            [sortKey release];
        }
        sortKey = [key retain];
        [tableView setHighlightedTableColumn:tableColumn]; 
	}
    
    if(previousSortKey == nil)
        previousSortKey = [sortKey retain];
    
    NSString *userInfo = [self fileName];
    NSArray *sortDescriptors = [NSArray arrayWithObjects:[BDSKTableSortDescriptor tableSortDescriptorForIdentifier:sortKey ascending:!docState.sortDescending userInfo:userInfo], [BDSKTableSortDescriptor tableSortDescriptorForIdentifier:previousSortKey ascending:!docState.sortDescending userInfo:userInfo], nil];
    [tableView setSortDescriptors:sortDescriptors]; // just using this to store them; it's really a no-op
    

    // @@ DON'T RETURN WITHOUT RESETTING THIS!
    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    [tableView setDelegate:nil];
    
    // sort by new primary column, subsort with previous primary column
    [shownPublications mergeSortUsingDescriptors:sortDescriptors];

    // Set the graphic for the new column header
    [tableView setIndicatorImage: (docState.sortDescending ?
                                   [NSImage imageNamed:@"NSDescendingSortIndicator"] :
                                   [NSImage imageNamed:@"NSAscendingSortIndicator"])
                   inTableColumn: tableColumn];

    // have to reload so the rows get set up right, but a full updateStatus flashes the preview, which is annoying (and the preview won't change if we're maintaining the selection)
    [tableView reloadData];

    // fix the selection
    [self selectPublications:pubsToSelect];
    [tableView scrollRowToCenter:[tableView selectedRow]]; // just go to the last one

    // reset ourself as delegate
    [tableView setDelegate:self];
}

- (void)saveSortOrder{ 
    // @@ if we switch to NSArrayController, we should just archive the sort descriptors (see BDSKFileContentSearchController)
    NSUserDefaults*sud = [NSUserDefaults standardUserDefaults];
    NSString *savedSortKey = nil;
    if ([sortKey isEqualToString:BDSKImportOrderString] || [sortKey isEqualToString:BDSKRelevanceString]) {
        if ([previousSortKey isEqualToString:BDSKImportOrderString] == NO && [previousSortKey isEqualToString:BDSKRelevanceString] == NO) 
            savedSortKey = previousSortKey;
    } else {
        savedSortKey = sortKey;
    }
    if (savedSortKey)
        [sud setObject:savedSortKey forKey:BDSKDefaultSortedTableColumnKey];
    [sud setBool:docState.sortDescending forKey:BDSKDefaultSortedTableColumnIsDescendingKey];
    [sud setObject:sortGroupsKey forKey:BDSKSortGroupsKey];
    [sud setBool:docState.sortGroupsDescending forKey:BDSKSortGroupsDescendingKey];    
}  

#pragma mark -
#pragma mark Selection

- (int)numberOfSelectedPubs{
    if ([self isDisplayingFileContentSearch])
        return [[fileSearchController selectedIdentifierURLs] count];
    else
        return [tableView numberOfSelectedRows];
}

- (NSArray *)selectedPublications{
    NSArray *selPubs = nil;
    if ([self isDisplayingFileContentSearch]) {
        if ([[fileSearchController tableView] numberOfSelectedRows]) {
            NSMutableArray *tmpArray = [NSMutableArray array];
            NSEnumerator *itemEnum = [[fileSearchController selectedIdentifierURLs] objectEnumerator];
            NSURL *idURL;
            BibItem *pub;
            while (idURL = [itemEnum nextObject]) {
                if (pub = [publications itemForIdentifierURL:idURL])
                    [tmpArray addObject:pub];
            }
            selPubs = tmpArray;
        }
    } else if ([tableView numberOfSelectedRows]) {
        selPubs = [shownPublications objectsAtIndexes:[tableView selectedRowIndexes]];
    }
    return selPubs;
}

- (BOOL)selectItemsForCiteKeys:(NSArray *)citeKeys selectLibrary:(BOOL)flag {

    // make sure we can see the publication, if it's still in the document
    if (flag)
        [self selectLibraryGroup:nil];
    [tableView deselectAll:self];
    [self setSearchString:@""];

    NSEnumerator *keyEnum = [citeKeys objectEnumerator];
    NSString *key;
    NSMutableArray *itemsToSelect = [NSMutableArray array];
    while (key = [keyEnum nextObject]) {
        BibItem *anItem = [publications itemForCiteKey:key];
        if (anItem)
            [itemsToSelect addObject:anItem];
    }
    [self selectPublications:itemsToSelect];
    return [itemsToSelect count];
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
    
    if([indexes count]){
        [tableView selectRowIndexes:indexes byExtendingSelection:NO];
        [tableView scrollRowToCenter:[indexes firstIndex]];
    }
}

- (NSArray *)selectedFileURLs {
    if ([self isDisplayingFileContentSearch])
        return [fileSearchController selectedURLs];
    else
        return [[self selectedPublications] valueForKeyPath:@"@unionOfArrays.localFiles.URL"];
}

#pragma mark -
#pragma mark Notification handlers

- (void)registerForNotifications{
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        
		[nc addObserver:self
               selector:@selector(handleGroupFieldChangedNotification:)
	               name:BDSKGroupFieldChangedNotification
                 object:self];
		[nc addObserver:self
               selector:@selector(handleGroupFieldAddRemoveNotification:)
	               name:BDSKGroupFieldAddRemoveNotification
                 object:nil];
		[nc addObserver:self
               selector:@selector(handleTableSelectionChangedNotification:)
	               name:BDSKTableSelectionChangedNotification
                 object:self];
		[nc addObserver:self
               selector:@selector(handleGroupTableSelectionChangedNotification:)
	               name:BDSKGroupTableSelectionChangedNotification
                 object:self];
		[nc addObserver:self
               selector:@selector(handleBibItemChangedNotification:)
	               name:BDSKBibItemChangedNotification
                 object:nil];
		[nc addObserver:self
               selector:@selector(handleBibItemAddDelNotification:)
	               name:BDSKDocSetPublicationsNotification
                 object:self];
		[nc addObserver:self
               selector:@selector(handleBibItemAddDelNotification:)
	               name:BDSKDocAddItemNotification
                 object:self];
		[nc addObserver:self
               selector:@selector(handleBibItemAddDelNotification:)
	               name:BDSKDocDelItemNotification
                 object:self];
        [nc addObserver:self
               selector:@selector(handleMacroChangedNotification:)
                   name:BDSKMacroDefinitionChangedNotification
                 object:nil];
        [nc addObserver:self
               selector:@selector(handleFilterChangedNotification:)
                   name:BDSKFilterChangedNotification
                 object:nil];
        [nc addObserver:self
               selector:@selector(handleGroupNameChangedNotification:)
                   name:BDSKGroupNameChangedNotification
                 object:nil];
        [nc addObserver:self
               selector:@selector(handleStaticGroupChangedNotification:)
                   name:BDSKStaticGroupChangedNotification
                 object:nil];
		[nc addObserver:self
               selector:@selector(handleSharedGroupUpdatedNotification:)
	               name:BDSKSharedGroupUpdatedNotification
                 object:nil];
        [nc addObserver:self
               selector:@selector(handleSharedGroupsChangedNotification:)
                   name:BDSKSharingClientsChangedNotification
                 object:nil];
        [nc addObserver:self
               selector:@selector(handleURLGroupUpdatedNotification:)
                   name:BDSKURLGroupUpdatedNotification
                 object:nil];
        [nc addObserver:self
               selector:@selector(handleScriptGroupUpdatedNotification:)
                   name:BDSKScriptGroupUpdatedNotification
                 object:nil];
        [nc addObserver:self
               selector:@selector(handleSearchGroupUpdatedNotification:)
                   name:BDSKSearchGroupUpdatedNotification
                 object:nil];
        [nc addObserver:self
               selector:@selector(handleWebGroupUpdatedNotification:)
                   name:BDSKWebGroupUpdatedNotification
                 object:nil];
        [nc addObserver:self
               selector:@selector(handleWillAddRemoveGroupNotification:)
                   name:BDSKWillAddRemoveGroupNotification
                 object:nil];
        [nc addObserver:self
               selector:@selector(handleDidAddRemoveGroupNotification:)
                   name:BDSKDidAddRemoveGroupNotification
                 object:nil];
        [nc addObserver:self
               selector:@selector(handleFlagsChangedNotification:)
                   name:BDSKFlagsChangedNotification
                 object:nil];
        [nc addObserver:self
               selector:@selector(handleApplicationWillTerminateNotification:)
                   name:NSApplicationWillTerminateNotification
                 object:nil];
        [nc addObserver:self
               selector:@selector(handleTemporaryFileMigrationNotification:)
                   name:BDSKTemporaryFileMigrationNotification
                 object:self];
        // observe this on behalf of our BibItems, or else all BibItems register for these notifications and -[BibItem dealloc] gets expensive when unregistering; this means that (shared) items without a document won't get these notifications
        [nc addObserver:self
               selector:@selector(handleCustomFieldsDidChangeNotification:)
                   name:BDSKCustomFieldsChangedNotification
                 object:nil];
        // Header says NSNotificationSuspensionBehaviorCoalesce is the default if suspensionBehavior isn't specified, but at least on 10.5 it appears to be NSNotificationSuspensionBehaviorDeliverImmediately.
        [[NSDistributedNotificationCenter defaultCenter] 
            addObserver:self
               selector:@selector(handleSkimFileDidSaveNotification:)
                   name:@"SKSkimFileDidSaveNotification"
                 object:nil
     suspensionBehavior:NSNotificationSuspensionBehaviorCoalesce];
        
        NSUserDefaultsController *sud = [NSUserDefaultsController sharedUserDefaultsController];
        
        [sud addObserver:self
              forKeyPath:[@"values." stringByAppendingString:BDSKIgnoredSortTermsKey]
                 options:0
                 context:BDSKDocumentDefaultsObservationContext];
        [sud addObserver:self
              forKeyPath:[@"values." stringByAppendingString:BDSKAuthorNameDisplayKey]
                 options:0
                 context:BDSKDocumentDefaultsObservationContext];
        [sud addObserver:self
              forKeyPath:[@"values." stringByAppendingString:BDSKBTStyleKey]
                 options:0
                 context:BDSKDocumentDefaultsObservationContext];
        [sud addObserver:self
              forKeyPath:[@"values." stringByAppendingString:BDSKUsesTeXKey]
                 options:0
                 context:BDSKDocumentDefaultsObservationContext];
}           

- (void)handleBibItemAddDelNotification:(NSNotification *)notification{
    // NB: this method gets called for setPublications: also, so checking for AddItemNotification might not do what you expect
	BOOL isDelete = [[notification name] isEqualToString:BDSKDocDelItemNotification];
    if(isDelete == NO && [self hasLibraryGroupSelected])
		[self setSearchString:@""]; // clear the search when adding

    // update smart group counts
    [self updateSmartGroupsCountAndContent:NO];
    // this handles the remaining UI updates necessary (tableView and previews)
	[self updateCategoryGroupsPreservingSelection:YES];
    
    NSArray *pubs = [[notification userInfo] objectForKey:@"pubs"];
    [self setImported:isDelete == NO forPublications:pubs inGroup:nil];
}

- (BOOL)sortKeyDependsOnKey:(NSString *)key{
    if (key == nil)
        return YES;
    else if([sortKey isEqualToString:BDSKTitleString])
        return [key isEqualToString:BDSKTitleString] || [key isEqualToString:BDSKChapterString] || [key isEqualToString:BDSKPagesString] || [key isEqualToString:BDSKPubTypeString];
    else if([sortKey isEqualToString:BDSKContainerString])
        return [key isEqualToString:BDSKContainerString] || [key isEqualToString:BDSKJournalString] || [key isEqualToString:BDSKBooktitleString] || [key isEqualToString:BDSKVolumeString] || [key isEqualToString:BDSKSeriesString] || [key isEqualToString:BDSKPubTypeString];
    else if([sortKey isEqualToString:BDSKPubDateString])
        return [key isEqualToString:BDSKYearString] || [key isEqualToString:BDSKMonthString];
    else if([sortKey isEqualToString:BDSKFirstAuthorString] || [sortKey isEqualToString:BDSKSecondAuthorString] || [sortKey isEqualToString:BDSKThirdAuthorString] || [sortKey isEqualToString:BDSKLastAuthorString])
        return [key isEqualToString:BDSKAuthorString];
    else if([sortKey isEqualToString:BDSKFirstAuthorEditorString] || [sortKey isEqualToString:BDSKSecondAuthorEditorString] || [sortKey isEqualToString:BDSKThirdAuthorEditorString] || [sortKey isEqualToString:BDSKLastAuthorEditorString])
        return [key isEqualToString:BDSKAuthorString] || [key isEqualToString:BDSKEditorString];
    else
        return [sortKey isEqualToString:key];
}

- (BOOL)searchKeyDependsOnKey:(NSString *)key{
    NSString *searchKey = [[searchField stringValue] isEqualToString:@""] ? nil : [searchButtonController selectedItemIdentifier];
    if ([searchKey isEqualToString:BDSKSkimNotesString] || [searchKey isEqualToString:BDSKFileContentSearchString])
        return [key isEqualToString:BDSKLocalFileString];
    else if (key == nil)
        return YES;
    else if ([searchKey isEqualToString:BDSKAllFieldsString])
        return [key isEqualToString:BDSKLocalFileString] == NO && [key isEqualToString:BDSKRemoteURLString] == NO;
    else if ([searchKey isEqualToString:BDSKPersonString])
        return [key isPersonField];
    else
        return [key isEqualToString:searchKey];
}

- (void)handlePrivateBibItemChanged{
    // we can be called from a queue after the document was closed
    if (docState.isDocumentClosed)
        return;
    
    if ((docState.itemChangeMask & BDSKItemChangedFilesMask) != 0)
        [self updateFileViews];

    BOOL shouldUpdateGroups = [NSString isEmptyString:[self currentGroupField]] == NO && (docState.itemChangeMask & BDSKItemChangedGroupFieldMask) != 0;
    
    // allow updating a smart group if it's selected
	[self updateSmartGroupsCountAndContent:YES];
    
    if(shouldUpdateGroups){
        // this handles all UI updates if we call it, so don't bother with any others
        [self updateCategoryGroupsPreservingSelection:YES];
    } else if ((docState.itemChangeMask & BDSKItemChangedSearchKeyMask) != 0) {
        // this handles all UI updates if we call it, so don't bother with any others
        [searchField sendAction:[searchField action] to:[searchField target]];
    } else {
        // groups and quicksearch won't update for us
        if ((docState.itemChangeMask & BDSKItemChangedSortKeyMask) != 0)
            [self sortPubsByKey:nil];
        else
            [tableView reloadData];
        [self updateStatus];
        [self updatePreviews];
    }
    
    docState.itemChangeMask = 0;
}

// this structure is only used in the following CFSetApplierFunction
typedef struct __BibItemCiteKeyChangeInfo {
    BibItem *pub;
    NSCharacterSet *invalidSet;
    NSString *key;
    NSString *oldKey;
} _BibItemCiteKeyChangeInfo;

static void applyChangesToCiteFieldsWithInfo(const void *citeField, void *context)
{
    NSString *field = (NSString *)citeField;
    _BibItemCiteKeyChangeInfo *changeInfo = context;
    NSString *value = [changeInfo->pub valueOfField:field inherit:NO];
    // value may be nil, so check before calling rangeOfString:
    if (nil != value) {
        NSRange range = [value rangeOfString:changeInfo->oldKey];
        if (range.location != NSNotFound &&
            (range.location == 0 || [changeInfo->invalidSet characterIsMember:[value characterAtIndex:range.location]]) &&
            (NSMaxRange(range) == [value length] || [changeInfo->invalidSet characterIsMember:[value characterAtIndex:NSMaxRange(range)]])) {
            NSMutableString *tmpString = [value mutableCopy];
            [tmpString replaceCharactersInRange:range withString:changeInfo->key];
            [changeInfo->pub setField:field toValue:tmpString];
            [tmpString release];
        }
    }
}

- (void)handleBibItemChangedNotification:(NSNotification *)notification{

    // note: userInfo is nil if -[BibItem setFields:] is called
	NSDictionary *userInfo = [notification userInfo];
    BibItem *pub = [notification object];
    
    // see if it's ours
	if([pub owner] != self)
        return;

	NSString *changedKey = [userInfo objectForKey:@"key"];
    NSString *key = [pub citeKey];
    NSString *oldKey = nil;
    NSEnumerator *pubEnum = [publications objectEnumerator];
    
    // need to handle cite keys and crossrefs if a cite key changed
    if([changedKey isEqualToString:BDSKCiteKeyString]){
        oldKey = [userInfo objectForKey:@"oldValue"];
        [publications changeCiteKey:oldKey toCiteKey:key forItem:pub];
        if([NSString isEmptyString:oldKey])
            oldKey = nil;
    }
    
    // -[BDSKItemSearchIndexes addPublications:] will overwrite previous values for this pub
    if ([changedKey isIntegerField] == NO && [changedKey isURLField] == NO)
        [searchIndexes addPublications:[NSArray arrayWithObject:pub]];
    
    // access type manager outside the enumerator, since it's @synchronized...
    BDSKTypeManager *typeManager = [BDSKTypeManager sharedManager];
    NSCharacterSet *invalidSet = [typeManager invalidCharactersForField:BDSKCiteKeyString inFileType:BDSKBibtexString];
    NSSet *citeFields = [typeManager citationFieldsSet];
    
    _BibItemCiteKeyChangeInfo changeInfo;
    changeInfo.invalidSet = invalidSet;
    changeInfo.key = key;
    changeInfo.oldKey = oldKey;
    
    while (pub = [pubEnum nextObject]) {
        NSString *crossref = [pub valueOfField:BDSKCrossrefString inherit:NO];
        if([NSString isEmptyString:crossref])
            continue;
        
        // invalidate groups that depend on inherited values
        if ([key caseInsensitiveCompare:crossref] == NSOrderedSame)
            [pub invalidateGroupNames];
        
        // change the crossrefs if we change the parent cite key
        if (oldKey) {
            if ([oldKey caseInsensitiveCompare:crossref] == NSOrderedSame)
                [pub setField:BDSKCrossrefString toValue:key];
            changeInfo.pub = pub;
            
            // faster than creating an enumerator for what's typically a tiny set (helpful when generating keys for an entire file)
            CFSetApplyFunction((CFSetRef)citeFields, applyChangesToCiteFieldsWithInfo, &changeInfo);
        }
    }
    
    if ([changedKey isEqualToString:[self currentGroupField]] || changedKey == nil)
        docState.itemChangeMask |= BDSKItemChangedGroupFieldMask;
    if ([self sortKeyDependsOnKey:changedKey])
        docState.itemChangeMask |= BDSKItemChangedSortKeyMask;
    if ([self searchKeyDependsOnKey:changedKey])
        docState.itemChangeMask |= BDSKItemChangedSearchKeyMask;
    if ([changedKey isEqualToString:BDSKLocalFileString] || [changedKey isEqualToString:BDSKRemoteURLString])
        docState.itemChangeMask |= BDSKItemChangedFilesMask;
    
    
    // queue for UI updating, in case the item is changed as part of a batch process such as Find & Replace or AutoFile
    [self queueSelectorOnce:@selector(handlePrivateBibItemChanged)];
}

- (void)handleMacroChangedNotification:(NSNotification *)aNotification{
	id changedOwner = [[aNotification object] owner];
	if(changedOwner && changedOwner != self)
		return; // only macro changes for ourselves or the global macros
	
    [tableView reloadData];
    [self updatePreviews];
}

- (void)handleTableSelectionChangedNotification:(NSNotification *)notification{
    [self updateFileViews];
    [self updatePreviews];
    [groupTableView updateHighlights];
}

- (void)handleFlagsChangedNotification:(NSNotification *)notification{
    BOOL isOptionKeyState = ([NSApp currentModifierFlags] & NSAlternateKeyMask) != 0;
    
    if (docState.inOptionKeyState != isOptionKeyState) {
        docState.inOptionKeyState = isOptionKeyState;
        
        NSToolbarItem *toolbarItem = [toolbarItems objectForKey:@"BibDocumentToolbarNewItemIdentifier"];
        
        if (isOptionKeyState) {
            [groupAddButton setImage:[NSImage imageNamed:@"GroupAddSmart"]];
            [groupAddButton setAlternateImage:[NSImage imageNamed:@"GroupAddSmart_Pressed"]];
            [groupAddButton setToolTip:NSLocalizedString(@"Add new smart group.", @"Tool tip message")];
            
            static NSImage *alternateNewToolbarImage = nil;
            if (alternateNewToolbarImage == nil) {
                alternateNewToolbarImage = [[NSImage alloc] initWithSize:NSMakeSize(32, 32)];
                [alternateNewToolbarImage lockFocus];
                NSImage *srcImage = [NSImage imageNamed:@"newdoc"];
                [srcImage drawInRect:NSMakeRect(0, 0, 32, 32) fromRect:NSMakeRect(0, 0, [srcImage size].width, [srcImage size].height) operation:NSCompositeSourceOver fraction:1.0]; 
                [[NSImage imageWithSmallIconForToolboxCode:kAliasBadgeIcon] compositeToPoint:NSMakePoint(8,-10) operation:NSCompositeSourceOver];
                [alternateNewToolbarImage unlockFocus];
            }
            
            [toolbarItem setLabel:NSLocalizedString(@"New with Crossref", @"Toolbar item label")];
            [toolbarItem setToolTip:NSLocalizedString(@"Create new publication with crossref", @"Tool tip message")];
            [toolbarItem setImage:alternateNewToolbarImage];
            [toolbarItem setAction:@selector(createNewPubUsingCrossrefAction:)];
        } else {
            [groupAddButton setImage:[NSImage imageNamed:@"GroupAdd"]];
            [groupAddButton setAlternateImage:[NSImage imageNamed:@"GroupAdd_Pressed"]];
            [groupAddButton setToolTip:NSLocalizedString(@"Add new group.", @"Tool tip message")];
            
            [toolbarItem setLabel:NSLocalizedString(@"New", @"Toolbar item label")];
            [toolbarItem setToolTip:NSLocalizedString(@"Create new publication", @"Tool tip message")];
            [toolbarItem setImage:[NSImage imageNamed: @"newdoc"]];
            [toolbarItem setAction:@selector(newPub:)];
        }
    }
}

- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification{
    [self saveSortOrder];
}

- (void)handleCustomFieldsDidChangeNotification:(NSNotification *)notification{
    [publications makeObjectsPerformSelector:@selector(customFieldsDidChange:) withObject:notification];
    [tableView setupTableColumnsWithIdentifiers:[tableView tableColumnIdentifiers]];
    // current group field may have changed its type (string->person)
    [self updateSmartGroupsCountAndContent:YES];
    [self updateCategoryGroupsPreservingSelection:YES];
    [self updatePreviews];
}

- (void)handleTemporaryFileMigrationNotification:(NSNotification *)notification{
    // display after the window loads so we can use a sheet, and the migration controller window is in front
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKDisableMigrationWarning"] == NO)
        docState.displayMigrationAlert = YES;
}

- (void)handleSkimFileDidSaveNotification:(NSNotification *)notification{
    NSString *path = [notification object];
    NSEnumerator *pubEnum = [publications objectEnumerator];
    BibItem *pub;
    NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:BDSKLocalFileString, @"key", nil];
    
    while (pub = [pubEnum nextObject]) {
        if ([[[pub existingLocalFiles] valueForKey:@"path"] containsObject:path])
            [[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibItemChangedNotification object:pub userInfo:notifInfo];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == BDSKDocumentFileViewObservationContext) {
        if (object == sideFileView) {
            float iconScale = [sideFileView autoScales] ? 0.0 : [sideFileView iconScale];
            [[NSUserDefaults standardUserDefaults] setFloat:iconScale forKey:BDSKSideFileViewIconScaleKey];
        } else if (object == bottomFileView) {
            float iconScale = [bottomFileView autoScales] ? 0.0 : [bottomFileView iconScale];
            [[NSUserDefaults standardUserDefaults] setFloat:iconScale forKey:BDSKBottomFileViewIconScaleKey];
        }
    } else if (context == BDSKDocumentDefaultsObservationContext) {
        NSString *key = [keyPath substringFromIndex:7];
        if ([key isEqualToString:BDSKIgnoredSortTermsKey]) {
            [self sortPubsByKey:nil];
        } else if ([key isEqualToString:BDSKAuthorNameDisplayKey]) {
            [tableView reloadData];
            if ([currentGroupField isPersonField])
                [groupTableView reloadData];
        } else if ([key isEqualToString:BDSKBTStyleKey]) {
            if ([previewer isVisible])
                [self updatePreviews];
            else if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey] &&
                    [[BDSKPreviewer sharedPreviewer] isWindowVisible] &&
                    [self isMainDocument])
                [self updatePreviewer:[BDSKPreviewer sharedPreviewer]];
        } else if ([key isEqualToString:BDSKUsesTeXKey]) {
            [bottomPreviewButton setEnabled:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey] forSegment:BDSKPreviewDisplayTeX];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -
#pragma mark Preview updating

- (void)doUpdatePreviews{
    // we can be called from a queue after the document was closed
    if (docState.isDocumentClosed)
        return;

    BDSKASSERT([NSThread isMainThread]);
    
    //take care of the preview field (NSTextView below the pub table); if the enumerator is nil, the view will get cleared out
    [self updateBottomPreviewPane];
    [self updateSidePreviewPane];
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey] &&
	   [[BDSKPreviewer sharedPreviewer] isWindowVisible] &&
       [self isMainDocument])
        [self updatePreviewer:[BDSKPreviewer sharedPreviewer]];
}

- (void)updatePreviews{
    // Coalesce these messages here, since something like select all -> generate cite keys will force a preview update for every
    // changed key, so we have to update all the previews each time.  This should be safer than using cancelPrevious... since those
    // don't get performed on the main thread (apparently), and can lead to problems.
    if (docState.isDocumentClosed == NO && [documentWindow isVisible])
        [self queueSelectorOnce:@selector(doUpdatePreviews)];
}

- (void)updatePreviewer:(BDSKPreviewer *)aPreviewer{
    NSArray *items = [self selectedPublications];
    NSString *bibString = [items count] ? [self previewBibTeXStringForPublications:items] : nil;
    [aPreviewer updateWithBibTeXString:bibString citeKeys:[items valueForKey:@"citeKey"]];
}

- (void)displayTemplatedPreview:(NSString *)templateStyle inTextView:(NSTextView *)textView{
    
    if([textView isHidden] || NSIsEmptyRect([textView visibleRect]))
        return;
    
    NSArray *items = [self selectedPublications];
    unsigned int maxItems = [[NSUserDefaults standardUserDefaults] integerForKey:BDSKPreviewMaxNumberKey];
    
    if (maxItems > 0 && [items count] > maxItems)
        items = [items subarrayWithRange:NSMakeRange(0, maxItems)];
    
    BDSKTemplate *template = [BDSKTemplate templateForStyle:templateStyle] ?: [BDSKTemplate templateForStyle:[BDSKTemplate defaultStyleNameForFileType:@"rtf"]];
    NSAttributedString *templateString = nil;
    
    // make sure this is really one of the attributed string types...
    if([template templateFormat] & BDSKRichTextTemplateFormat){
        templateString = [BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:self publications:items documentAttributes:NULL];
    } else if([template templateFormat] & BDSKPlainTextTemplateFormat){
        // parse as plain text, so the HTML is interpreted properly by NSAttributedString
        NSString *str = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:self publications:items];
        // we generally assume UTF-8 encoding for all template-related files
        if ([template templateFormat] == BDSKPlainHTMLTemplateFormat)
            templateString = [[[NSAttributedString alloc] initWithHTML:[str dataUsingEncoding:NSUTF8StringEncoding] documentAttributes:NULL] autorelease];
        else
            templateString = [[[NSAttributedString alloc] initWithString:str attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont userFontOfSize:0.0], NSFontAttributeName, nil]] autorelease];
    }
    
    // do this _before_ messing with the text storage; otherwise you can have a leftover selection that ends up being out of range
    static NSArray *zeroRanges = nil;
    if (zeroRanges == nil) zeroRanges = [[NSArray alloc] initWithObjects:[NSValue valueWithRange: NSMakeRange(0, 0)], nil];
    
    NSTextStorage *textStorage = [textView textStorage];
    [textView setSelectedRanges:zeroRanges];
    [textStorage beginEditing];
    if (templateString)
        [textStorage setAttributedString:templateString];
    else
        [[textStorage mutableString] setString:@""];
    [textStorage endEditing];
    
    if([NSString isEmptyString:[searchField stringValue]] == NO)
        [textView highlightComponentsOfSearchString:[searchField stringValue]];    
}

- (void)prepareForTeXPreview {
    if(previewer == nil && [[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey]){
        previewer = [[BDSKPreviewer alloc] init];
        NSDictionary *xatrrDefaults = [self mainWindowSetupDictionaryFromExtendedAttributes];
        [previewer setPDFScaleFactor:[xatrrDefaults floatForKey:BDSKPreviewPDFScaleFactorKey defaultValue:0.0]];
        [previewer setRTFScaleFactor:[xatrrDefaults floatForKey:BDSKPreviewRTFScaleFactorKey defaultValue:1.0]];
        [previewer setGeneratedTypes:BDSKGeneratePDF];
        BDSKEdgeView *previewerBox = [[[BDSKEdgeView alloc] init] autorelease];
        [previewerBox setEdges:BDSKEveryEdgeMask];
        [previewerBox setColor:[NSColor lightGrayColor] forEdge:NSMaxYEdge];
        [previewerBox setContentView:[previewer pdfView]];
        [[bottomPreviewTabView tabViewItemAtIndex:BDSKPreviewDisplayTeX] setView:previewerBox];
    }
    
    [[previewer progressOverlay] overlayView:bottomPreviewTabView];
}

- (void)cleanupAfterTeXPreview {
    [[previewer progressOverlay] remove];
    [previewer updateWithBibTeXString:nil];
}

- (void)updateBottomPreviewPane{
    int tabIndex = [bottomPreviewTabView indexOfTabViewItem:[bottomPreviewTabView selectedTabViewItem]];
    if (bottomPreviewDisplay != tabIndex) {
        if (bottomPreviewDisplay == BDSKPreviewDisplayTeX)
            [self prepareForTeXPreview];
        else if (tabIndex == BDSKPreviewDisplayTeX)
            [self cleanupAfterTeXPreview];
        [bottomPreviewTabView selectTabViewItemAtIndex:bottomPreviewDisplay];
    }
    
    if (bottomPreviewDisplay == BDSKPreviewDisplayTeX)
        [self updatePreviewer:previewer];
    else if (bottomPreviewDisplay == BDSKPreviewDisplayFiles)
        [bottomFileView reloadIcons];
    else
        [self displayTemplatedPreview:bottomPreviewDisplayTemplate inTextView:bottomPreviewTextView];
}

- (void)updateSidePreviewPane{
    int tabIndex = [sidePreviewTabView indexOfTabViewItem:[sidePreviewTabView selectedTabViewItem]];
    if (sidePreviewDisplay != tabIndex) {
        [sidePreviewTabView selectTabViewItemAtIndex:sidePreviewDisplay];
    }
    
    if (sidePreviewDisplay == BDSKPreviewDisplayFiles)
        [sideFileView reloadIcons];
    else
        [self displayTemplatedPreview:sidePreviewDisplayTemplate inTextView:sidePreviewTextView];
}

#pragma mark FileView

typedef struct _fileViewObjectContext {
    CFMutableArrayRef array;
    NSString *title;
} fileViewObjectContext;

static void addFileViewObjectForURLToArray(const void *value, void *context)
{
    fileViewObjectContext *ctxt = context;
    // value is BDSKLinkedFile *
    BDSKFileViewObject *obj = [[BDSKFileViewObject alloc] initWithURL:[(BDSKLinkedFile *)value displayURL] string:ctxt->title];
    CFArrayAppendValue(ctxt->array, obj);
    [obj release];
}

static void addAllFileViewObjectsForItemToArray(const void *value, void *context)
{
    CFArrayRef allURLs = (CFArrayRef)[(BibItem *)value files];
    if (CFArrayGetCount(allURLs)) {
        fileViewObjectContext ctxt;
        ctxt.array = context;
        ctxt.title = [(BibItem *)value displayTitle];
        CFArrayApplyFunction(allURLs, CFRangeMake(0, CFArrayGetCount(allURLs)), addFileViewObjectForURLToArray, &ctxt);
    }
}

- (NSArray *)shownFiles {
    if (shownFiles == nil) {
        if ([self isDisplayingFileContentSearch]) {
            shownFiles = [[fileSearchController selectedResults] mutableCopy];
        } else {
            NSArray *selPubs = [self selectedPublications];
            if (selPubs) {
                shownFiles = [[NSMutableArray alloc] initWithCapacity:[selPubs count]];
                CFArrayApplyFunction((CFArrayRef)selPubs, CFRangeMake(0, [selPubs count]), addAllFileViewObjectsForItemToArray, shownFiles);
            }
        }
    }
    return shownFiles;
}

- (void)updateFileViews {
    [shownFiles release];
    shownFiles = nil;
    
    [sideFileView reloadIcons];
    [bottomFileView reloadIcons];
}

#pragma mark -
#pragma mark Status bar

- (void)setStatus:(NSString *)status {
	[self setStatus:status immediate:YES];
}

- (void)setStatus:(NSString *)status immediate:(BOOL)now {
	if(now)
		[statusBar setStringValue:status];
	else
		[statusBar performSelector:@selector(setStringValue:) withObject:status afterDelay:0.01];
}

- (void)updateStatus{
	NSMutableString *statusStr = [[NSMutableString alloc] init];
	NSString *ofStr = NSLocalizedString(@"of", @"partial status message: [number] of [number] publications");
    
    if ([self isDisplayingFileContentSearch]) {
        
        int shownItemsCount = [[fileSearchController filteredResults] count];
        int totalItemsCount = [[fileSearchController results] count];
        
        [statusStr appendFormat:@"%i %@", shownItemsCount, (shownItemsCount == 1) ? NSLocalizedString(@"item", @"item, in status message") : NSLocalizedString(@"items", @"items, in status message")];
        
        if (shownItemsCount != totalItemsCount) {
            NSString *groupStr = ([groupTableView numberOfSelectedRows] == 1) ?
                [NSString stringWithFormat:@"%@ \"%@\"", NSLocalizedString(@"in group", @"Partial status message"), [[[self selectedGroups] lastObject] stringValue]] :
                NSLocalizedString(@"in multiple groups", @"Partial status message");
            [statusStr appendFormat:@" %@ (%@ %i)", groupStr, ofStr, totalItemsCount];
        }
        
    } else {

        int shownPubsCount = [shownPublications count];
        int groupPubsCount = [groupedPublications count];
        int totalPubsCount = [publications count];
        
        if (shownPubsCount != groupPubsCount) { 
            [statusStr appendFormat:@"%i %@ ", shownPubsCount, ofStr];
        }
        [statusStr appendFormat:@"%i %@", groupPubsCount, (groupPubsCount == 1) ? NSLocalizedString(@"publication", @"publication, in status message") : NSLocalizedString(@"publications", @"publications, in status message")];
        // we can have only a single external group selected at a time
        if ([self hasWebGroupSelected] == YES) {
            [statusStr appendFormat:@" %@", NSLocalizedString(@"in web group", @"Partial status message")];
        } else if ([self hasSharedGroupsSelected] == YES) {
            [statusStr appendFormat:@" %@ \"%@\"", NSLocalizedString(@"in shared group", @"Partial status message"), [[[self selectedGroups] lastObject] stringValue]];
        } else if ([self hasURLGroupsSelected] == YES) {
            [statusStr appendFormat:@" %@ \"%@\"", NSLocalizedString(@"in external file group", @"Partial status message"), [[[self selectedGroups] lastObject] stringValue]];
        } else if ([self hasScriptGroupsSelected] == YES) {
            [statusStr appendFormat:@" %@ \"%@\"", NSLocalizedString(@"in script group", @"Partial status message"), [[[self selectedGroups] lastObject] stringValue]];
        } else if ([self hasSearchGroupsSelected] == YES) {
            BDSKSearchGroup *group = [[self selectedGroups] firstObject];
            [statusStr appendFormat:NSLocalizedString(@" in \"%@\" search group", @"Partial status message"), [[group serverInfo] name]];
            int matchCount = [group numberOfAvailableResults];
            if (matchCount == 1)
                [statusStr appendFormat:NSLocalizedString(@". There was 1 match.", @"Partial status message")];
            else if (matchCount > 1)
                [statusStr appendFormat:NSLocalizedString(@". There were %i matches.", @"Partial status message"), matchCount];
            if ([group hasMoreResults])
                [statusStr appendString:NSLocalizedString(@" Hit \"Search\" to load more.", @"Partial status message")];
            else if (groupPubsCount < matchCount)
                [statusStr appendString:NSLocalizedString(@" Some results could not be parsed.", @"Partial status message")];
        } else if (groupPubsCount != totalPubsCount) {
            NSString *groupStr = ([groupTableView numberOfSelectedRows] == 1) ?
                [NSString stringWithFormat:@"%@ \"%@\"", NSLocalizedString(@"in group", @"Partial status message"), [[[self selectedGroups] lastObject] stringValue]] :
                NSLocalizedString(@"in multiple groups", @"Partial status message");
            [statusStr appendFormat:@" %@ (%@ %i)", groupStr, ofStr, totalPubsCount];
        }
        
    }
    
	[self setStatus:statusStr];
    [statusStr release];
}

#pragma mark -
#pragma mark Control view animation

- (BOOL)isDisplayingSearchButtons { return [documentWindow isEqual:[[searchButtonController view] window]]; }
- (BOOL)isDisplayingFileContentSearch { return [documentWindow isEqual:[[fileSearchController tableView] window]]; }
- (BOOL)isDisplayingSearchGroupView { return [documentWindow isEqual:[[searchGroupViewController view] window]]; }
- (BOOL)isDisplayingWebGroupView { return [documentWindow isEqual:[[webGroupViewController view] window]]; }

- (void)insertControlView:(NSView *)controlView atTop:(BOOL)insertAtTop {
    if ([documentWindow isEqual:[controlView window]])
        return;
    
    NSArray *views = [[[mainBox contentView] subviews] copy];
    NSEnumerator *viewEnum;
    NSView *view;
    NSRect controlFrame = [controlView frame];
    NSRect startRect, endRect = [splitView frame];
    
    if (insertAtTop) {
        viewEnum = [views objectEnumerator];
        while (view = [viewEnum nextObject])
            endRect = NSUnionRect(endRect, [view frame]);
    }
    startRect = endRect;
    startRect.size.height += NSHeight(controlFrame);
    controlFrame.size.width = NSWidth(endRect);
    controlFrame.origin.x = NSMinX(endRect);
    controlFrame.origin.y = NSMaxY(endRect);
    [controlView setFrame:controlFrame];
    
    NSView *clipView = [[[NSView alloc] initWithFrame:endRect] autorelease];
    NSView *resizeView = [[[NSView alloc] initWithFrame:startRect] autorelease];
    
    [mainBox addSubview:clipView];
    [clipView addSubview:resizeView];
    if (insertAtTop) {
        viewEnum = [views objectEnumerator];
        while (view = [viewEnum nextObject])
            [resizeView addSubview:view];
    } else {
        [resizeView addSubview:splitView];
    }
    [resizeView addSubview:controlView];
    [views release];
    
    [NSViewAnimation animateResizeView:resizeView toRect:endRect];
    
    views = [[resizeView subviews] copy];
    viewEnum = [views objectEnumerator];
    while (view = [viewEnum nextObject])
        [mainBox addSubview:view];
    [clipView removeFromSuperview];
    
    [views release];
    
    [mainBox setNeedsDisplay:YES];
    [documentWindow displayIfNeeded];
}

- (void)removeControlView:(NSView *)controlView {
    if ([documentWindow isEqual:[controlView window]] == NO)
        return;
    
    NSArray *views = [[NSArray alloc] initWithArray:[[mainBox contentView] subviews] copyItems:NO];
    NSRect controlFrame = [controlView frame];
    NSRect endRect, startRect = NSUnionRect([splitView frame], controlFrame);
    
    endRect = startRect;
    endRect.size.height += NSHeight(controlFrame);
    
    NSView *clipView = [[[NSView alloc] initWithFrame:startRect] autorelease];
    NSView *resizeView = [[[NSView alloc] initWithFrame:startRect] autorelease];
    
    /* Retaining the graphics context is a workaround for our bug #1714565.
        
        To reproduce:
        1) search LoC for "Bob Dylan"
        2) enter "ab" in the document's searchfield
        3) click the "Import" button for any one of the items
        4) crash when trying to retain a dealloced instance of NSWindowGraphicsContext (enable zombies) in [resizeView addSubview:]

       This seems to be an AppKit focus stack bug.  Something still isn't quite correct, since the button for -[BDSKMainTableView importItem:] is in the wrong table column momentarily, but I think that's unrelated to the crasher.
    */
    [[[NSGraphicsContext currentContext] retain] autorelease];
    
    [mainBox addSubview:clipView];
    [clipView addSubview:resizeView];
    NSEnumerator *viewEnum = [views objectEnumerator];
    NSView *view;

    while (view = [viewEnum nextObject]) {
        if (NSContainsRect(startRect, [view frame]))
            [resizeView addSubview:view];
    }
    [resizeView addSubview:controlView];
    [views release];
    
    [NSViewAnimation animateResizeView:resizeView toRect:endRect];
    
    [controlView removeFromSuperview];
    views = [[resizeView subviews] copy];
    viewEnum = [views objectEnumerator];
    while (view = [viewEnum nextObject])
        [mainBox addSubview:view];
    [clipView removeFromSuperview];
    
    [views release];
    
    [mainBox setNeedsDisplay:YES];
    [documentWindow displayIfNeeded];
}

#pragma mark -
#pragma mark Columns Menu

- (NSMenu *)columnsMenu{
    return [tableView columnsMenu];
}

- (NSMenu *)menuForImagePopUpButton:(BDSKImagePopUpButton *)view{
    NSMenu *menu = actionMenu;
    NSMenu *submenu = nil;
    int i, count = [menu numberOfItems];
    
    for (i = 0; submenu == nil && i < count; i++)
        submenu = [[menu itemAtIndex:i] submenu];
    if (submenu) {
        while ([submenu numberOfItems])
            [submenu removeItemAtIndex:0];
        NSArray *styles = [BDSKTemplate allStyleNames];
        count = [styles count];
        for (i = 0; i < count; i++) {
            NSMenuItem *item = [submenu addItemWithTitle:[styles objectAtIndex:i] action:@selector(copyAsAction:) keyEquivalent:@""];
            [item setTarget:self];
            [item setTag:BDSKTemplateDragCopyType + i];
        }
    }
    return menu;
}

#pragma mark Template Menu

- (void)menuNeedsUpdate:(NSMenu *)menu {
    if (menu == bottomTemplatePreviewMenu || menu == sideTemplatePreviewMenu) {
        NSMutableArray *styles = [NSMutableArray arrayWithArray:[BDSKTemplate allStyleNamesForFileType:@"rtf"]];
        [styles addObjectsFromArray:[BDSKTemplate allStyleNamesForFileType:@"rtfd"]];
        [styles addObjectsFromArray:[BDSKTemplate allStyleNamesForFileType:@"doc"]];
        [styles addObjectsFromArray:[BDSKTemplate allStyleNamesForFileType:@"html"]];
        
        while ([menu numberOfItems])
            [menu removeItemAtIndex:0];
        
        NSEnumerator *styleEnum = [styles objectEnumerator];
        NSString *style;
        NSMenuItem *item;
        SEL action = menu == bottomTemplatePreviewMenu ? @selector(changePreviewDisplay:) : @selector(changeSidePreviewDisplay:);
        
        while (style = [styleEnum nextObject]) {
            item = [menu addItemWithTitle:style action:action keyEquivalent:@""];
            [item setTarget:self];
            [item setTag:BDSKPreviewDisplayText];
            [item setRepresentedObject:style];
        }
    }
}

#pragma mark -
#pragma mark Printing support

- (IBAction)printDocument:(id)sender{
    if (bottomPreviewDisplay == BDSKPreviewDisplayTeX)
        [[previewer pdfView] printWithInfo:[self printInfo] autoRotate:YES];
    else
        [super printDocument:sender];
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
    NSAttributedString *attrString = nil;
    NSString *string = nil;
    if (bottomPreviewDisplay == BDSKPreviewDisplayText)
        attrString = [bottomPreviewTextView textStorage];
    else if (sidePreviewDisplay == BDSKPreviewDisplayText)
        attrString = [sidePreviewTextView textStorage];
    else
        // this occurs only when both FileViews are displayed, probably never happens
        string = [self bibTeXStringForPublications:[self selectedPublications]];
    
    NSPrintInfo *info = [[self printInfo] copy];
    [[info dictionary] addEntriesFromDictionary:printSettings];
    [info setHorizontalPagination:NSFitPagination];
    [info setHorizontallyCentered:NO];
    [info setVerticallyCentered:NO];
    
    NSTextView *printableView = nil;
    if (attrString)
        printableView = [[BDSKPrintableView alloc] initWithAttributedString:attrString printInfo:info];
    else
        printableView = [[BDSKPrintableView alloc] initWithString:string printInfo:info];
    if (attrString == nil && string == nil)
        string = NSLocalizedString(@"Error: nothing to print from document preview", @"printing error");
    
    NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:printableView printInfo:info];
    [printableView release];
    [info release];
    
    NSPrintPanel *printPanel = [printOperation printPanel];
    if ([printPanel respondsToSelector:@selector(setOptions:)])
        [printPanel setOptions:NSPrintPanelShowsCopies | NSPrintPanelShowsPageRange | NSPrintPanelShowsPaperSize | NSPrintPanelShowsOrientation | NSPrintPanelShowsScaling | NSPrintPanelShowsPreview];
    
    return printOperation;
}

#pragma mark SplitView delegate

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize {
    int i = [[sender subviews] count] - 2;
    BDSKASSERT(i >= 0);
	NSView *zerothView = i == 0 ? nil : [[sender subviews] objectAtIndex:0];
	NSView *firstView = [[sender subviews] objectAtIndex:i];
	NSView *secondView = [[sender subviews] objectAtIndex:++i];
	NSRect zerothFrame = zerothView ? [zerothView frame] : NSZeroRect;
	NSRect firstFrame = [firstView frame];
	NSRect secondFrame = [secondView frame];
	
	if (sender == splitView) {
		// first = table, second = preview, zeroth = web
        float contentHeight = NSHeight([sender frame]) - i * [sender dividerThickness];
        float factor = contentHeight / (oldSize.height - i * [sender dividerThickness]);
        secondFrame = NSIntegralRect(secondFrame);
        zerothFrame.size.height = floorf(factor * NSHeight(zerothFrame));
        firstFrame.size.height = floorf(factor * NSHeight(firstFrame));
        secondFrame.size.height = floorf(factor * NSHeight(secondFrame));
        if (NSHeight(zerothFrame) < 1.0)
            zerothFrame.size.height = 0.0;
        if (NSHeight(firstFrame) < 1.0)
            firstFrame.size.height = 0.0;
        if (NSHeight(secondFrame) < 1.0)
            secondFrame.size.height = 0.0;
        // randomly divide the remaining gap over the two views; NSSplitView dumps it all over the last view, which grows that one more than the others
        int gap = (int)(contentHeight - NSHeight(zerothFrame) - NSHeight(firstFrame) - NSHeight(secondFrame));
        while (gap > 0) {
            i = floorf((3.0f * rand()) / RAND_MAX);
            if (i == 0 && NSHeight(zerothFrame) > 0.0) {
                zerothFrame.size.height += 1.0;
                gap--;
            } else if (i == 1 && NSHeight(firstFrame) > 0.0) {
                firstFrame.size.height += 1.0;
                gap--;
            } else if (i == 2 && NSHeight(secondFrame) > 0.0) {
                secondFrame.size.height += 1.0;
                gap--;
            }
        }
        zerothFrame.size.width = firstFrame.size.width = secondFrame.size.width = NSWidth([sender frame]);
        if (zerothView)
            firstFrame.origin.y = NSMaxY(zerothFrame) + [sender dividerThickness];
        secondFrame.origin.y = NSMaxY(firstFrame) + [sender dividerThickness];
	} else {
		// zeroth = group, first = table+preview, second = fileview
        float contentWidth = NSWidth([sender frame]) - 2 * [sender dividerThickness];
        if (NSWidth(zerothFrame) < 1.0)
            zerothFrame.size.width = 0.0;
        if (NSWidth(secondFrame) < 1.0)
            secondFrame.size.width = 0.0;
        if (contentWidth < NSWidth(zerothFrame) + NSWidth(secondFrame)) {
            float factor = contentWidth / (oldSize.width - [sender dividerThickness]);
            zerothFrame.size.width = floorf(factor * NSWidth(zerothFrame));
            secondFrame.size.width = floorf(factor * NSWidth(secondFrame));
        }
        firstFrame.size.width = contentWidth - NSWidth(zerothFrame) - NSWidth(secondFrame);
        firstFrame.origin.x = NSMaxX(zerothFrame) + [sender dividerThickness];
        secondFrame.origin.x = NSMaxX(firstFrame) + [sender dividerThickness];
        zerothFrame.size.height = firstFrame.size.height = secondFrame.size.height = NSHeight([sender frame]);
    }
	
	[zerothView setFrame:zerothFrame];
	[firstView setFrame:firstFrame];
	[secondView setFrame:secondFrame];
    [sender adjustSubviews];
}

- (void)splitView:(BDSKGradientSplitView *)sender doubleClickedDividerAt:(int)offset {
    int i = [[sender subviews] count] - 2;
    BDSKASSERT(i >= 0);
	NSView *zerothView = i == 0 ? nil : [[sender subviews] objectAtIndex:0];
	NSView *firstView = [[sender subviews] objectAtIndex:i];
	NSView *secondView = [[sender subviews] objectAtIndex:++i];
	NSRect zerothFrame = zerothView ? [zerothView frame] : NSZeroRect;
	NSRect firstFrame = [firstView frame];
	NSRect secondFrame = [secondView frame];
	
	if (sender == splitView && offset == i - 1) {
		// first = table, second = preview, zeroth = web
		if(NSHeight(secondFrame) > 0){ // can't use isSubviewCollapsed, because implementing splitView:canCollapseSubview: prevents uncollapsing
			docState.lastPreviewHeight = NSHeight(secondFrame); // cache this
			firstFrame.size.height += docState.lastPreviewHeight;
			secondFrame.size.height = 0;
		} else {
			if(docState.lastPreviewHeight <= 0)
				docState.lastPreviewHeight = floorf(NSHeight([sender frame]) / 3); // a reasonable value for uncollapsing the first time
			firstFrame.size.height = NSHeight(firstFrame) + NSHeight(secondFrame) - docState.lastPreviewHeight;
			secondFrame.size.height = docState.lastPreviewHeight;
		}
	} else if (sender == groupSplitView) {
		// zeroth = group, first = table+preview, second = fileview
        if (offset == 0) {
            if(NSWidth(zerothFrame) > 0){
                docState.lastGroupViewWidth = NSWidth(zerothFrame); // cache this
                firstFrame.size.width += docState.lastGroupViewWidth;
                zerothFrame.size.width = 0;
            } else {
                if(docState.lastGroupViewWidth <= 0)
                    docState.lastGroupViewWidth = fminf(120, NSWidth(firstFrame)); // a reasonable value for uncollapsing the first time
                firstFrame.size.width -= docState.lastGroupViewWidth;
                zerothFrame.size.width = docState.lastGroupViewWidth;
            }
        } else {
            if(NSWidth(secondFrame) > 0){
                docState.lastFileViewWidth = NSWidth(secondFrame); // cache this
                firstFrame.size.width += docState.lastFileViewWidth;
                secondFrame.size.width = 0;
            } else {
                if(docState.lastFileViewWidth <= 0)
                    docState.lastFileViewWidth = fminf(120, NSWidth(firstFrame)); // a reasonable value for uncollapsing the first time
                firstFrame.size.width -= docState.lastFileViewWidth;
                secondFrame.size.width = docState.lastFileViewWidth;
            }
        }
	} else return;
	
	[zerothView setFrame:zerothFrame];
	[firstView setFrame:firstFrame];
	[secondView setFrame:secondFrame];
    [sender adjustSubviews];
    [[sender window] invalidateCursorRectsForView:sender];
}

#pragma mark -

- (int)userChangedField:(NSString *)fieldName ofPublications:(NSArray *)pubs from:(NSArray *)oldValues to:(NSArray *)newValues{
    int rv = 0;
    
    NSEnumerator *pubEnum = [pubs objectEnumerator];
    BibItem *pub;
    NSMutableArray *generateKeyPubs = [NSMutableArray arrayWithCapacity:[pubs count]];
    NSMutableArray *autofileFiles = [NSMutableArray arrayWithCapacity:[pubs count]];
    
    while(pub = [pubEnum nextObject]){
        [[self editorForPublication:pub create:NO] finalizeChanges:nil];
        
        // generate cite key if we have enough information
        if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKCiteKeyAutogenerateKey] && [pub canGenerateAndSetCiteKey])
            [generateKeyPubs addObject:pub];
        
        // autofile paper if we have enough information
        if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKFilePapersAutomaticallyKey]){
            NSEnumerator *fileEnum = [[pub localFiles] objectEnumerator];
            BDSKLinkedFile *file;
            while (file = [fileEnum nextObject])
                if ([[pub filesToBeFiled] containsObject:file] && [pub canSetURLForLinkedFile:file])
                    [autofileFiles addObject:file];
        }
	}
    
    if([generateKeyPubs count]){
        [self generateCiteKeysForPublications:generateKeyPubs];
        rv |= 1;
    }
    if([autofileFiles count]){
        [[BDSKFiler sharedFiler] filePapers:autofileFiles fromDocument:self check:NO];
        rv |= 2;
    }
    
	BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKChangeFieldScriptHookName];
	if (scriptHook) {
		[scriptHook setField:fieldName];
		[scriptHook setOldValues:oldValues];
		[scriptHook setNewValues:newValues];
		[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:pubs document:self];
	}
    
    return rv;
}

- (void)userAddedURL:(NSURL *)aURL forPublication:(BibItem *)pub {
	BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
    if ([aURL isFileURL] == NO && [NSString isEmptyString:[pub valueOfField:BDSKUrlString]] && [[pub remoteURLs] count] == 1 && 
        ([[typeMan requiredFieldsForType:[pub pubType]] containsObject:BDSKUrlString] || [[typeMan optionalFieldsForType:[pub pubType]] containsObject:BDSKUrlString])) {
        [pub setField:BDSKUrlString toValue:[aURL absoluteString]];
    }
    
    BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKAddFileScriptHookName];
	if (scriptHook) {
		[scriptHook setField:[aURL isFileURL] ? BDSKLocalFileString : BDSKRemoteURLString];
		[scriptHook setOldValues:[NSArray array]];
		[scriptHook setNewValues:[NSArray arrayWithObjects:[aURL isFileURL] ? [aURL path] : [aURL absoluteString], nil]];
		[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObjects:pub, nil] document:self];
	}
}

- (void)userRemovedURL:(NSURL *)aURL forPublication:(BibItem *)pub {
	BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKRemoveFileScriptHookName];
	if (scriptHook) {
		[scriptHook setField:([aURL isEqual:[NSNull null]] || [aURL isFileURL]) ? BDSKLocalFileString : BDSKRemoteURLString];
		[scriptHook setOldValues:[NSArray arrayWithObjects:[aURL isEqual:[NSNull null]] ? (id)aURL : [aURL isFileURL] ? [aURL path] : [aURL absoluteString], nil]];
		[scriptHook setNewValues:[NSArray array]];
		[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObjects:pub, nil] document:self];
	}
}

#pragma mark -
#pragma mark Protocols forwarding

// Declaring protocol conformance in the category headers shuts the compiler up, but causes a hang in -[NSObject conformsToProtocol:], which sucks.  Therefore, we use wrapper methods here to call the real (category) implementations.
- (void)removeFileContentSearch:(BDSKFileContentSearchController *)controller{ 
    [self privateRemoveFileContentSearch:controller]; 
}

- (NSIndexSet *)indexesOfRowsToHighlightInRange:(NSRange)indexRange tableView:(BDSKGroupTableView *)tview{
    return [self _indexesOfRowsToHighlightInRange:indexRange tableView:tview];
}

- (NSIndexSet *)tableViewSingleSelectionIndexes:(BDSKGroupTableView *)tview{
    return [self _tableViewSingleSelectionIndexes:tview];
}

- (void)tableView:(BDSKGroupTableView *)tview doubleClickedOnIconOfRow:(int)row{
    [self editGroupAtRow:row];
}

#pragma mark DisplayName KVO

- (void)setFileURL:(NSURL *)absoluteURL{ 
    // make sure that changes in the displayName are observed, as NSDocument doesn't use a KVC compliant method for setting it
    [self willChangeValueForKey:@"displayName"];
    [super setFileURL:absoluteURL];
    [self didChangeValueForKey:@"displayName"];
    
    if (absoluteURL)
        [[publications valueForKeyPath:@"@unionOfArrays.files"]  makeObjectsPerformSelector:@selector(update)];
    [self updateFileViews];
    [self updatePreviews];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocumentFileURLDidChangeNotification object:self];
}

// just create this setter to avoid a run time warning
- (void)setDisplayName:(NSString *)newName{}

// avoid warning for BDSKOwner protocol conformance
- (NSURL *)fileURL {
    return [super fileURL];
}

- (BOOL)isDocument{
    return YES;
}

@end

#pragma mark -

@implementation NSFileWrapper (BDSKExtensions)

- (NSFileWrapper *)addFileWrapperWithPath:(NSString *)path relativeTo:(NSString *)basePath recursive:(BOOL)recursive {
    NSFileWrapper *fileWrapper = nil;
    BOOL isDir;
    if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]) {
        NSString *filename = [path lastPathComponent];
        NSString *relativePath = basePath ? [basePath relativePathToFile:path] : filename;
        NSFileWrapper *container = self;
        
        if ([relativePath isEqualToString:filename] == NO)
            container = [self addFileWrapperWithPath:[path stringByDeletingLastPathComponent] relativeTo:basePath recursive:NO];
        
        fileWrapper = [[container fileWrappers] objectForKey:filename];
        if (fileWrapper == nil || [fileWrapper isDirectory] != isDir) {
            if (isDir)
                fileWrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:[NSDictionary dictionary]];
            else
                fileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents:[NSData dataWithContentsOfFile:path]];
            [fileWrapper setPreferredFilename:filename];
            [container addFileWrapper:fileWrapper];
            [fileWrapper release];
        }
        
        if (isDir && recursive) {
            NSEnumerator *fileEnum = [[[NSFileManager defaultManager] subpathsAtPath:path] objectEnumerator];
            NSString *file;
            while (file = [fileEnum nextObject])
                [self addFileWrapperWithPath:[path stringByAppendingPathComponent:file] relativeTo:path recursive:YES];
        }
    }
    return fileWrapper;
}

@end

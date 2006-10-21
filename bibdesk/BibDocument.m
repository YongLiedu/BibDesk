//  BibDocument.m

//  Created by Michael McCracken on Mon Dec 17 2001.
/*
 This software is Copyright (c) 2001,2002,2003,2004,2005,2006
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
#import "BibItem.h"
#import "BibAuthor.h"
#import "BibDocument_DataSource.h"
#import "BibDocument_Actions.h"
#import "BibDocumentView_Toolbar.h"
#import "BibAppController.h"
#import "BibPrefController.h"
#import "BDSKGroup.h"
#import "BDSKStaticGroup.h"

#import "BDSKUndoManager.h"
#import "MultiplePageView.h"
#import "BDSKPrintableView.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKFontManager.h"
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
#import "BDSKMainTableView.h"
#import "BDSKConverter.h"
#import "BibTeXParser.h"
#import "PubMedParser.h"
#import "BDSKJSTORParser.h"
#import "BDSKWebOfScienceParser.h"

#import "ApplicationServices/ApplicationServices.h"
#import "BDSKImagePopUpButton.h"
#import "BDSKRatingButton.h"
#import "BDSKSplitView.h"
#import "BDSKCollapsibleView.h"

#import "BDSKMacroResolver.h"
#import "MacroWindowController.h"
#import "BDSKErrorObjectController.h"
#import "BDSKGroupTableView.h"
#import "BDSKFileContentSearchController.h"
#import "NSString_BDSKExtensions.h"
#import "BDSKStatusBar.h"
#import "BDSKPreviewMessageQueue.h"
#import "NSArray_BDSKExtensions.h"
#import "NSTextView_BDSKExtensions.h"
#import "NSTableView_BDSKExtensions.h"
#import "NSDictionary_BDSKExtensions.h"
#import "NSSet_BDSKExtensions.h"
#import "NSFileManager_ExtendedAttributes.h"
#import "PDFMetadata.h"
#import "BDSKSharingServer.h"
#import "BDSKSharingBrowser.h"
#import "BDSKTemplate.h"
#import "BDSKDocumentInfoWindowController.h"
#import "NSMutableArray+ThreadSafety.h"
#import "BDSKGroupTableView.h"
#import "BDSKFileContentSearchController.h"
#import "BDSKTemplateParser.h"
#import "BDSKTemplateObjectProxy.h"
#import "NSMenu_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "NSData_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "BDSKShellTask.h"
#import "NSError_BDSKExtensions.h"

// these are the same as in Info.plist
NSString *BDSKBibTeXDocumentType = @"BibTeX Database";
NSString *BDSKRISDocumentType = @"RIS/Medline File";
NSString *BDSKMinimalBibTeXDocumentType = @"Minimal BibTeX Database";
NSString *BDSKWOSDocumentType = @"Web of Science File";
NSString *BDSKLTBDocumentType = @"Amsrefs LTB";
NSString *BDSKAtomDocumentType = @"Atom XML";

NSString *BDSKReferenceMinerStringPboardType = @"CorePasteboardFlavorType 0x57454253";
NSString *BDSKBibItemPboardType = @"edu.ucsd.mmccrack.bibdesk BibItem pboard type";
NSString *BDSKWeblocFilePboardType = @"CorePasteboardFlavorType 0x75726C20";

// private keys used for storing window information in xattrs
static NSString *BDSKMainWindowExtendedAttributeKey = @"net.sourceforge.bibdesk.BDSKDocumentWindowAttributes";
static NSString *BDSKGroupSplitViewFractionKey = @"BDSKGroupSplitViewFractionKey";
static NSString *BDSKMainTableSplitViewFractionKey = @"BDSKMainTableSplitViewFractionKey";
static NSString *BDSKDocumentWindowFrameKey = @"BDSKDocumentWindowFrameKey";

@interface NSDocument (BDSKPrivateExtensions)
// declare a private NSDocument method so we can override it
- (void)changeSaveType:(id)sender;
@end

@implementation BibDocument

- (id)init{
    if(self = [super init]){
        publications = [[NSMutableArray alloc] initWithCapacity:1];
        shownPublications = [[NSMutableArray alloc] initWithCapacity:1];
        groupedPublications = [[NSMutableArray alloc] initWithCapacity:1];
        categoryGroups = [[NSMutableArray alloc] initWithCapacity:1];
        smartGroups = [[NSMutableArray alloc] initWithCapacity:1];
        urlGroups = [[NSMutableArray alloc] initWithCapacity:1];
        scriptGroups = [[NSMutableArray alloc] initWithCapacity:1];
        staticGroups = nil;
        tmpStaticGroups = nil;
		allPublicationsGroup = [[BDSKGroup alloc] initWithAllPublications];
		lastImportGroup = nil;
                
        frontMatter = [[NSMutableString alloc] initWithString:@""];
		
        documentInfo = [[NSMutableDictionary alloc] initForCaseInsensitiveKeys];
    
        currentGroupField = [[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKCurrentGroupFieldKey] retain];

        quickSearchKey = [[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKCurrentQuickSearchKey] retain];
        
        // @@ Changed from "All Fields" to localized "Any Field" in 1.2.2; prefs may still have the old key, so this is a temporary workaround for bug #1420837 as of 31 Jan 2006
        if([quickSearchKey isEqualToString:@"All Fields"]){
            [quickSearchKey release];
            quickSearchKey = [BDSKAllFieldsString copy];
        } else if(quickSearchKey == nil || [quickSearchKey isEqualToString:@"Added"] || [quickSearchKey isEqualToString:@"Created"] || [quickSearchKey isEqualToString:@"Modified"]){
            quickSearchKey = [BDSKTitleString copy];
        }
		
		texTask = [[BDSKTeXTask alloc] initWithFileName:@"bibcopy"];
		[texTask setDelegate:self];
        
        macroResolver = [(BDSKMacroResolver *)[BDSKMacroResolver alloc] initWithDocument:self];
        
        BDSKUndoManager *newUndoManager = [[[BDSKUndoManager alloc] init] autorelease];
        [newUndoManager setDelegate:self];
        [self setUndoManager:newUndoManager];
		
        itemsForCiteKeys = [[OFMultiValueDictionary alloc] initWithKeyCallBacks:&BDSKCaseInsensitiveStringKeyDictionaryCallBacks];
		
		promisedPboardTypes = [[NSMutableDictionary alloc] initWithCapacity:2];
        
        isDocumentClosed = NO;
        
		customStringArray = [[NSMutableArray arrayWithCapacity:6] retain];
		[customStringArray setArray:[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKCustomCiteStringsKey]];
        
        // need to set this for new documents
        [self setDocumentStringEncoding:[BDSKStringEncodingManager defaultEncoding]]; 

		sortDescending = NO;
		sortGroupsDescending = [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKSortGroupsDescendingKey];
		sortGroupsKey = [[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKSortGroupsKey] retain];
		
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        
		[nc addObserver:self
               selector:@selector(handlePreviewDisplayChangedNotification:)
	               name:BDSKPreviewDisplayChangedNotification
                 object:nil];

		[nc addObserver:self
               selector:@selector(handleGroupFieldChangedNotification:)
	               name:BDSKGroupFieldChangedNotification
                 object:self];

		[nc addObserver:self
               selector:@selector(handleGroupAddRemoveNotification:)
	               name:BDSKGroupAddRemoveNotification
                 object:nil];

		// register for selection changes notifications:
		[nc addObserver:self
               selector:@selector(handleTableSelectionChangedNotification:)
	               name:BDSKTableSelectionChangedNotification
                 object:self];

		[nc addObserver:self
               selector:@selector(handleGroupTableSelectionChangedNotification:)
	               name:BDSKGroupTableSelectionChangedNotification
                 object:self];

		//  register to observe for item change notifications here.
		[nc addObserver:self
               selector:@selector(handleBibItemChangedNotification:)
	               name:BDSKBibItemChangedNotification
                 object:nil];

		// register to observe for add/delete items.
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
               selector:@selector(handleStaticGroupChangedNotification:)
                   name:BDSKStaticGroupChangedNotification
                 object:nil];
        
		[nc addObserver:self
               selector:@selector(handleSharedGroupUpdatedNotification:)
	               name:BDSKSharedGroupUpdatedNotification
                 object:nil];
        
        [nc addObserver:self
               selector:@selector(handleSharedGroupsChangedNotification:)
                   name:BDSKSharedGroupsChangedNotification
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
               selector:@selector(handleFlagsChangedNotification:)
                   name:OAFlagsChangedNotification
                 object:nil];
        
        [nc addObserver:self
               selector:@selector(handleApplicationWillTerminateNotification:)
                   name:NSApplicationWillTerminateNotification
                 object:nil];
        
        // observe these on behalf of our BibItems, or else all BibItems register for these notifications and -[BibItem dealloc] gets expensive when unregistering; this means that (shared) items without a document won't get these notifications
        [nc addObserver:self
               selector:@selector(handleTypeInfoDidChangeNotification:)
                   name:BDSKBibTypeInfoChangedNotification
                 object:[BibTypeManager sharedManager]];
        
        [nc addObserver:self
               selector:@selector(handleCustomFieldsDidChangeNotification:)
                   name:BDSKCustomFieldsChangedNotification
                 object:nil];
        
        [OFPreference addObserver:self
                         selector:@selector(handleIgnoredSortTermsChangedNotification:)
                    forPreference:[OFPreference preferenceForKey:BDSKIgnoredSortTermsKey]];
        
        [OFPreference addObserver:self
                         selector:@selector(handleNameDisplayChangedNotification:)
                    forPreference:[OFPreference preferenceForKey:BDSKShouldDisplayFirstNamesKey]];
        
        [OFPreference addObserver:self
                         selector:@selector(handleNameDisplayChangedNotification:)
                    forPreference:[OFPreference preferenceForKey:BDSKShouldAbbreviateFirstNamesKey]];
        
        [OFPreference addObserver:self
                         selector:@selector(handleNameDisplayChangedNotification:)
                    forPreference:[OFPreference preferenceForKey:BDSKShouldDisplayLastNameFirstKey]];
        
    }
    return self;
}

- (void)dealloc{
#if DEBUG
    NSLog(@"bibdoc dealloc");
#endif
    [fileSearchController release];
    if ([self undoManager]) {
        [[self undoManager] removeAllActionsWithTarget:self];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [OFPreference removeObserver:self forPreference:nil];
    [macroResolver release];
    [itemsForCiteKeys release];
    [publications release];
    [shownPublications release];
    [groupedPublications release];
    [categoryGroups release];
    [smartGroups release];
    [staticGroups release];
    [allPublicationsGroup release];
    [lastImportGroup release];
    [frontMatter release];
    [documentInfo release];
    [quickSearchKey release];
    [customStringArray release];
    [toolbarItems release];
	[statusBar release];
	[texTask release];
    [macroWC release];
    [infoWC release];
    [promiseDragColumnIdentifier release];
    [lastSelectedColumnForSort release];
    [sortGroupsKey release];
	[promisedPboardTypes release];
    [sharedGroups release];
    [sharedGroupSpinners release];
    [super dealloc];
}

- (NSString *)windowNibName{
        return @"BibDocument";
}

- (void)showWindows{
    [super showWindows];
    
    // Get the search string keyword if available (Spotlight passes this)
    NSAppleEventDescriptor *event = [[NSAppleEventManager sharedAppleEventManager] currentAppleEvent];
    NSString *searchString = [[event descriptorForKeyword:keyAESearchText] stringValue];
    
    if([event eventID] == kAEOpenDocuments && searchString != nil){
        // We want to handle open events for our Spotlight cache files differently; rather than setting the search field, we can jump to them immediately since they have richer context.  This code gets the path of the document being opened in order to check the file extension.
        NSString *hfsPath = [[[event descriptorForKeyword:keyAEResult] coerceToDescriptorType:typeFileURL] stringValue];
        
        // hfsPath will be nil for under some conditions, which seems strange; possibly because I wasn't checking eventID == 'odoc'?
        if(hfsPath == nil) NSLog(@"No path available from event %@ (descriptor %@)", event, [event descriptorForKeyword:keyAEResult]);
        NSURL *fileURL = (hfsPath == nil ? nil : [(id)CFURLCreateWithFileSystemPath(CFAllocatorGetDefault(), (CFStringRef)hfsPath, kCFURLHFSPathStyle, FALSE) autorelease]);
        
        OBPOSTCONDITION(fileURL != nil);
        if(fileURL == nil || [[[NSWorkspace sharedWorkspace] UTIForURL:fileURL] isEqualToUTI:@"net.sourceforge.bibdesk.bdskcache"] == NO){
            [self selectGroup:allPublicationsGroup];
            [self setSelectedSearchFieldKey:BDSKAllFieldsString];
            [self setFilterField:searchString];
        }
    }
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
    
    // this is the controller for the main window
    [aController setShouldCloseDocument:YES];
    
    // hidden default to remove xattrs; this presently occurs before we use them, but it may need to be earlier at some point
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKRemoveExtendedAttributesFromDocuments"] && [self fileURL]) {
        [[NSFileManager defaultManager] removeAllExtendedAttributesAtPath:[[self fileURL] path] traverseLink:YES error:NULL];
    }
        
    [self setupToolbar];
	[self setupSearchField];
    
    // First remove the toolbar if we should, as it affects proper resizing of the window and splitViews
	[statusBar retain]; // we need to retain, as we might remove it from the window
	if (![[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShowStatusBarKey]) {
		[self toggleStatusBar:nil];
	} else {
		// make sure they are ordered correctly, mainly for the focus ring
		[statusBar removeFromSuperview];
		[[mainBox superview] addSubview:statusBar positioned:NSWindowBelow relativeTo:nil];
	}
	[statusBar setProgressIndicatorStyle:BDSKProgressIndicatorSpinningStyle];
    
    // This must also be done before we resize the window and the splitViews
    [groupCollapsibleView setCollapseEdges:BDSKMinXEdgeMask];
    [groupCollapsibleView setMinSize:NSMakeSize(56.0, 20.0)];
    [groupGradientView setUpperColor:[NSColor colorWithCalibratedWhite:0.9 alpha:1.0]];
    [groupGradientView setLowerColor:[NSColor colorWithCalibratedWhite:0.75 alpha:1.0]];

    // make sure they are ordered correctly, mainly for the focus ring
	[groupCollapsibleView retain];
    [groupCollapsibleView removeFromSuperview];
    [[[groupTableView enclosingScrollView] superview] addSubview:groupCollapsibleView positioned:NSWindowBelow relativeTo:nil];
	[groupCollapsibleView release];
    
    // get document-specific attributes (returns nil if there are none)
    NSDictionary *xattrDefaults = [self mainWindowSetupDictionaryFromExtendedAttributes];

    NSRect frameRect = [xattrDefaults rectForKey:BDSKDocumentWindowFrameKey defaultValue:NSZeroRect];
    
    // we should only cascade windows if we have multiple documents open; bug #1299305
    // the default cascading does not reset the next location when all windows have closed, so we do cascading ourselves
    static NSPoint nextWindowLocation = {0.0, 0.0};
    
    if (nil != xattrDefaults && NSEqualRects(frameRect, NSZeroRect) == NO) {
        [[aController window] setFrame:frameRect display:YES];
        [aController setShouldCascadeWindows:NO];
        nextWindowLocation = [[aController window] cascadeTopLeftFromPoint:NSMakePoint(NSMinX(frameRect), NSMaxY(frameRect))];
    } else {
        // set the frame from prefs first, or setFrameAutosaveName: will overwrite the prefs with the nib values if it returns NO
        [[aController window] setFrameUsingName:@"Main Window Frame Autosave"];

        [aController setShouldCascadeWindows:NO];
        if ([[aController window] setFrameAutosaveName:@"Main Window Frame Autosave"]) {
            NSRect windowFrame = [[aController window] frame];
            nextWindowLocation = NSMakePoint(NSMinX(windowFrame), NSMaxY(windowFrame));
        }
        nextWindowLocation = [[aController window] cascadeTopLeftFromPoint:nextWindowLocation];
    }
            
    [documentWindow setAutorecalculatesKeyViewLoop:YES];
    [documentWindow makeFirstResponder:tableView];	
    
    // SplitViews setup
    [groupSplitView setDrawEnd:YES];
    [splitView setDrawEnd:YES];
    
    // set autosave names first
	[splitView setPositionAutosaveName:@"OASplitView Position Main Window"];
    [groupSplitView setPositionAutosaveName:@"OASplitView Position Group Table"];
    
    // set previous splitview frames
    if (nil != xattrDefaults) {
        float fraction;
        fraction = [xattrDefaults floatForKey:BDSKGroupSplitViewFractionKey defaultValue:-1.0];
        if (fraction > 0)
            [groupSplitView setFraction:fraction];
        fraction = [xattrDefaults floatForKey:BDSKMainTableSplitViewFractionKey defaultValue:-1.0];
        if (fraction > 0)
            [splitView setFraction:fraction];
    }
    
    // TableView setup
    [tableView removeAllTableColumns];
    
	[self setupDefaultTableColumns];
    [self sortPubsByDefaultColumn];
    
    [tableView setDoubleAction:@selector(editPubOrOpenURLAction:)];
    NSArray *dragTypes = [NSArray arrayWithObjects:BDSKBibItemPboardType, BDSKWeblocFilePboardType, BDSKReferenceMinerStringPboardType, NSStringPboardType, NSFilenamesPboardType, NSURLPboardType, nil];
    [tableView registerForDraggedTypes:dragTypes];
    [groupTableView registerForDraggedTypes:dragTypes];

    // Cite Drawer setup
    // workaround for IB flakiness...
    NSSize drawerSize = [customCiteDrawer contentSize];
    [customCiteDrawer setContentSize:NSMakeSize(100.0, drawerSize.height)];
	showingCustomCiteDrawer = NO;
	
	// ImagePopUpButtons setup
	[actionMenuButton setArrowImage:[NSImage imageNamed:@"ArrowPointingDown"]];
	[actionMenuButton setShowsMenuWhenIconClicked:YES];
	[[actionMenuButton cell] setAltersStateOfSelectedItem:NO];
	[[actionMenuButton cell] setAlwaysUsesFirstItemAsSelected:NO];
	[[actionMenuButton cell] setUsesItemFromMenu:NO];
	[[actionMenuButton cell] setRefreshesMenu:NO];
	
	[groupActionMenuButton setArrowImage:[NSImage imageNamed:@"ArrowPointingDown"]];
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
	
	BDSKImagePopUpButton *cornerViewButton = (BDSKImagePopUpButton*)[tableView cornerView];
	[cornerViewButton setAlternateImage:[NSImage imageNamed:@"cornerColumns_Pressed"]];
	[cornerViewButton setShowsMenuWhenIconClicked:YES];
	[[cornerViewButton cell] setAltersStateOfSelectedItem:NO];
	[[cornerViewButton cell] setAlwaysUsesFirstItemAsSelected:NO];
	[[cornerViewButton cell] setUsesItemFromMenu:NO];
	[[cornerViewButton cell] setRefreshesMenu:NO];
    
	BDSKHeaderPopUpButtonCell *headerCell = (BDSKHeaderPopUpButtonCell *)[groupTableView popUpHeaderCell];
	[headerCell setAction:@selector(changeGroupFieldAction:)];
	[headerCell setTarget:self];
	[headerCell setMenu:[self groupFieldsMenu]];
	[headerCell setIndicatorImage:[NSImage imageNamed:sortGroupsDescending ? @"NSDescendingSortIndicator" : @"NSAscendingSortIndicator"]];
    [headerCell setUsesItemFromMenu:NO];
	[headerCell setTitle:currentGroupField];
    if([headerCell itemWithTitle:currentGroupField])
        [headerCell selectItemWithTitle:currentGroupField];
    else
        [headerCell selectItemAtIndex:0];
    
    // Accessor view setup
    [saveTextEncodingPopupButton removeAllItems];
    [saveTextEncodingPopupButton addItemsWithTitles:[[BDSKStringEncodingManager sharedEncodingManager] availableEncodingDisplayedNames]];
    
    // array of BDSKSharedGroup objects and zeroconf support, doesn't do anything when already enabled
    // we don't do this in appcontroller as we want our data to be loaded
    sharedGroups = nil;
    sharedGroupSpinners = nil;
    if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShouldLookForSharedFilesKey]){
        [[BDSKSharingBrowser sharedBrowser] enableSharedBrowsing];
        // force an initial update of the tableview, if browsing is already in progress
        [self handleSharedGroupsChangedNotification:nil];
    }
    if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShouldShareFilesKey])
        [[BDSKSharingServer defaultServer] enableSharing];
    
    // @@ awakeFromNib is called long after the document's data is loaded, so the UI update from setPublications is too early when loading a new document; there may be a better way to do this
    [self updateGroupsPreservingSelection:NO];
    [self updateAllSmartGroups];
}

- (BOOL)undoManagerShouldUndoChange:(id)sender{
	if (![self isDocumentEdited]) {
		BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Warning", @"Warning") 
											 defaultButton:NSLocalizedString(@"Yes", @"Yes") 
										   alternateButton:NSLocalizedString(@"No", @"No") 
											   otherButton:nil
								 informativeTextWithFormat:NSLocalizedString(@"You are about to undo past the last point this file was saved. Do you want to do this?", @"") ];

		int rv = [alert runSheetModalForWindow:documentWindow];
		if (rv == NSAlertAlternateReturn)
			return NO;
	}
	return YES;
}

- (void)windowWillClose:(NSNotification *)notification{

    if([notification object] != documentWindow) // this is critical; 
        return;
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocumentWindowWillCloseNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionary]];
    isDocumentClosed = YES;
    [customCiteDrawer close];
    [self saveSortOrder];
    [self saveWindowSetupInExtendedAttributesAtURL:[self fileURL]];
    
    // reset the previewer; don't send [self updatePreviews:] here, as the tableview will be gone by the time the queue posts the notification
    if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKUsesTeXKey] &&
       [[BDSKPreviewer sharedPreviewer] isWindowVisible] &&
       [tableView selectedRow] != -1 )
        [[BDSKPreviewer sharedPreviewer] updateWithBibTeXString:nil];    
	
	[self providePromisedTypes];
	
    // safety call here, in case the pasteboard is retaining the document; we don't want notifications after the window closes, since all the pointers to UI elements will be garbage
    [[NSNotificationCenter defaultCenter] removeObserver:self];

}

// returns nil if no attributes set
- (NSDictionary *)mainWindowSetupDictionaryFromExtendedAttributes {
    return [self fileURL] ? [[NSFileManager defaultManager] propertyListFromExtendedAttributeNamed:BDSKMainWindowExtendedAttributeKey atPath:[[self fileURL] path] traverseLink:YES error:NULL] : nil;
}

- (void)saveWindowSetupInExtendedAttributesAtURL:(NSURL *)anURL {
    
    NSString *path = [anURL path];
    if (path && [[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKDisableDocumentExtendedAttributes"] == NO) {
        
        // We could set each of these as a separate attribute name on the file, but then we'd need to muck around with prepending net.sourceforge.bibdesk. to each key, and that seems messy.
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [dictionary setBoolValue:sortDescending forKey:BDSKDefaultSortedTableColumnIsDescendingKey];
        [dictionary setObject:[lastSelectedColumnForSort identifier] forKey:BDSKDefaultSortedTableColumnKey];
        [dictionary setObject:[self currentTableColumnWidthsAndIdentifiers] forKey:BDSKColumnWidthsKey];
        [dictionary setObject:[tableView tableColumnIdentifiers] forKey:BDSKShownColsNamesKey];
        [dictionary setObject:sortGroupsKey forKey:BDSKSortGroupsKey];
        [dictionary setBoolValue:sortGroupsDescending forKey:BDSKSortGroupsDescendingKey];
        [dictionary setRectValue:[documentWindow frame] forKey:BDSKDocumentWindowFrameKey];
        [dictionary setFloatValue:[groupSplitView fraction] forKey:BDSKGroupSplitViewFractionKey];
        [dictionary setFloatValue:[splitView fraction] forKey:BDSKMainTableSplitViewFractionKey];

        NSError *error;
        
        if ([[NSFileManager defaultManager] setExtendedAttributeNamed:BDSKMainWindowExtendedAttributeKey 
                                                  toPropertyListValue:dictionary
                                                               atPath:path options:nil error:&error] == NO) {
            NSLog(@"%@: %@", self, error);
        }
        
    } 
}

#pragma mark Publications acessors

- (void)setPublications:(NSArray *)newPubs undoable:(BOOL)undo{
    if(newPubs != publications){

        // we don't want to undo when initially setting the publications array, or the document is dirty
        // we do want to have undo otherwise though, e.g. for undoing -sortForCrossrefs:
        if(undo){
            NSUndoManager *undoManager = [self undoManager];
            [[undoManager prepareWithInvocationTarget:self] setPublications:publications];
        }
        
		// current publications (if any) will no longer have a document
		[publications makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
        
		[publications setArray:newPubs];
		[publications makeObjectsPerformSelector:@selector(setDocument:) withObject:self];
        [self rebuildItemsForCiteKeys];
		
		NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:newPubs, @"pubs", nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocSetPublicationsNotification
															object:self
														  userInfo:notifInfo];
    }
}    

- (void)setPublications:(NSArray *)newPubs{
    [self setPublications:newPubs undoable:YES];
}

- (NSMutableArray *) publications{
    return publications;
}

- (void)insertPublications:(NSArray *)pubs atIndexes:(NSIndexSet *)indexes{
    // this assertion is only necessary to preserve file order for undo
    NSParameterAssert([indexes count] == [pubs count]);
    [[[self undoManager] prepareWithInvocationTarget:self] removePublicationsAtIndexes:indexes];
		
	[publications insertObjects:pubs atIndexes:indexes];        
    
	[pubs makeObjectsPerformSelector:@selector(setDocument:) withObject:self];
	[self addToItemsForCiteKeys:pubs];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:pubs, @"pubs", [pubs arrayByPerformingSelector:@selector(searchIndexInfo)], @"searchIndexInfo", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocAddItemNotification
														object:self
													  userInfo:notifInfo];
}

- (void)insertPublication:(BibItem *)pub atIndex:(unsigned int)index {
    [self insertPublications:[NSArray arrayWithObject:pub] atIndexes:[NSIndexSet indexSetWithIndex:index]];
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
    
    [lastImportGroup removePublicationsInArray:pubs];
    [[self staticGroups] makeObjectsPerformSelector:@selector(removePublicationsInArray:) withObject:pubs];
    
	[publications removeObjectsAtIndexes:indexes];
	
	[pubs makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
	[self removeFromItemsForCiteKeys:pubs];
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

- (NSArray *)publicationsForAuthor:(BibAuthor *)anAuthor{
    NSMutableSet *auths = BDSKCreateFuzzyAuthorCompareMutableSet();
    NSEnumerator *pubEnum = [publications objectEnumerator];
    BibItem *bi;
    NSMutableArray *anAuthorPubs = [NSMutableArray array];
    
    while(bi = [pubEnum nextObject]){
        [auths addObjectsFromArray:[bi pubAuthors]];
        if([auths containsObject:anAuthor]){
            [anAuthorPubs addObject:bi];
        }
        [auths removeAllObjects];
    }
    [auths release];
    return anAuthorPubs;
}

- (void)getCopyOfPublicationsOnMainThread:(NSMutableArray *)dstArray{
    if([NSThread inMainThread] == NO){
        [self performSelectorOnMainThread:_cmd withObject:dstArray waitUntilDone:YES];
    } else {
        NSArray *array = [[NSArray alloc] initWithArray:[self publications] copyItems:YES];
        [dstArray addObjectsFromArray:array];
        [array release];
    }
}

- (NSNumber *)fileOrderOfPublication:(BibItem *)thePub{
    unsigned int order = [publications indexOfObjectIdenticalTo:thePub];
    return NSNotFound == order ? nil : [NSNumber numberWithInt:(order + 1)];
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

- (void)setDocumentInfo:(NSString *)value forKey:(NSString *)key{
    [[[self undoManager] prepareWithInvocationTarget:self] setDocumentInfo:[self documentInfoForKey:key] forKey:key];
    [documentInfo setValue:value forKey:key];
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

- (IBAction)showDocumentInfoWindow:(id)sender{
    if (!infoWC) {
        infoWC = [(BDSKDocumentInfoWindowController *)[BDSKDocumentInfoWindowController alloc] initWithDocument:self];
    }
    if ([[self windowControllers] containsObject:infoWC] == NO) {
        [self addWindowController:infoWC];
    }
    [infoWC beginSheetModalForWindow:documentWindow];
}

#pragma mark Macro stuff

- (BDSKMacroResolver *)macroResolver{
    return macroResolver;
}

- (IBAction)showMacrosWindow:(id)sender{
    if (!macroWC) {
        macroWC = [[MacroWindowController alloc] initWithMacroResolver:[self macroResolver]];
    }
    if ([[self windowControllers] containsObject:macroWC] == NO) {
        [self addWindowController:macroWC];
    }
    [macroWC showWindow:self];
}

#pragma mark -
#pragma mark  Document Saving

+ (NSArray *)writableTypes
{
    NSMutableArray *writableTypes = [[[super writableTypes] mutableCopy] autorelease];
    [writableTypes addObjectsFromArray:[BDSKTemplate allStyleNames]];
    return writableTypes;
}

#define SAVE_ENCODING_VIEW_OFFSET 30.0
#define SAVE_FORMAT_POPUP_OFFSET 31.0

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
    
    NSView *accessoryView = [savePanel accessoryView];
    NSPopUpButton *saveFormatPopupButton = popUpButtonSubview(accessoryView);
    OBASSERT(saveFormatPopupButton != nil);
    NSRect popupFrame = [saveTextEncodingPopupButton frame];
    popupFrame.origin.y += SAVE_FORMAT_POPUP_OFFSET;
    [saveFormatPopupButton setFrame:popupFrame];
    [saveAccessoryView addSubview:saveFormatPopupButton];
    NSRect savFrame = [saveAccessoryView frame];
    savFrame.size.width = NSWidth([accessoryView frame]);
    
    if(NSSaveToOperation == currentSaveOperationType){
        savFrame.origin = NSMakePoint(0.0, SAVE_ENCODING_VIEW_OFFSET);
        [saveAccessoryView setFrame:savFrame];
        [exportAccessoryView addSubview:saveAccessoryView];
        accessoryView = exportAccessoryView;
    }else{
        [saveAccessoryView setFrame:savFrame];
        accessoryView = saveAccessoryView;
    }
    [savePanel setAccessoryView:accessoryView];
    
    // set the popup to reflect the document's present string encoding
    NSString *documentEncodingName = [[BDSKStringEncodingManager sharedEncodingManager] displayedNameForStringEncoding:[self documentStringEncoding]];
    [saveTextEncodingPopupButton selectItemWithTitle:documentEncodingName];
    [saveTextEncodingPopupButton setEnabled:YES];
    
    if(NSSaveToOperation == currentSaveOperationType){
        [exportSelectionCheckButton setState:NSOffState];
        [exportSelectionCheckButton setEnabled:[self numberOfSelectedPubs] > 0];
    }
    [accessoryView setNeedsDisplay:YES];
    
    return YES;
}

// this is a private method, the action of the file format poup
- (void)changeSaveType:(id)sender{
    NSSet *typesWithEncoding = [NSSet setWithObjects:BDSKBibTeXDocumentType, BDSKRISDocumentType, BDSKMinimalBibTeXDocumentType, BDSKLTBDocumentType, nil];
    NSString *selectedType = [[sender selectedItem] representedObject];
    [saveTextEncodingPopupButton setEnabled:[typesWithEncoding containsObject:selectedType]];
    if ([[self superclass] instancesRespondToSelector:@selector(changeSaveType:)])
        [super changeSaveType:sender];
}

- (void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo {
    // Override so we can determine if this is a save, saveAs or export operation, so we can prepare the correct accessory view
    currentSaveOperationType = saveOperation;
    [super runModalSavePanelForSaveOperation:saveOperation delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}

- (BOOL)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError{
    
    // Set the string encoding according to the popup.  NB: the popup has the incorrect encoding if it wasn't displayed, so don't reset encoding unless we're actually modifying this document.
    if (NSSaveAsOperation == saveOperation)
        [self setDocumentStringEncoding:[[BDSKStringEncodingManager sharedEncodingManager] stringEncodingForDisplayedName:[saveTextEncodingPopupButton titleOfSelectedItem]]];
    
    BOOL success = [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
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
            [self saveWindowSetupInExtendedAttributesAtURL:absoluteURL];
        
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
            OMNI_POOL_START {
                if(info = [anItem metadataCacheInfoForUpdate:update])
                    [pubsInfo addObject:info];
            } OMNI_POOL_END;
        }
        
        NSDictionary *infoDict = [[NSDictionary alloc] initWithObjectsAndKeys:pubsInfo, @"publications", absoluteURL, @"fileURL", nil];
        [pubsInfo release];
        [[NSApp delegate] rebuildMetadataCache:infoDict];
        [infoDict release];
        
        // save window setup to extended attributes, so it is set also if we use saveAs
        [self saveWindowSetupInExtendedAttributesAtURL:absoluteURL];
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
    currentSaveOperationType = saveOperation;
    return [super writeToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation originalContentsURL:absoluteOriginalContentsURL error:outError];
}

- (BOOL)writeToURL:(NSURL *)fileURL ofType:(NSString *)docType error:(NSError **)outError{

    BOOL success = YES;
    NSError *nsError = nil;
    NSArray *items = publications;
    
    if(currentSaveOperationType == NSSaveToOperation && [exportSelectionCheckButton state] == NSOnState)
        items = [self selectedPublications];
    
    NSFileWrapper *fileWrapper = [self fileWrapperOfType:docType forPublications:items error:&nsError];
    success = nil == fileWrapper ? NO : [fileWrapper writeToFile:[fileURL path] atomically:YES updateFilenames:NO];
    
    // see if this is our error or Apple's
    if (NO == success && [nsError isLocalError]) {
        
        // get offending BibItem if possible
        BibItem *theItem = [nsError valueForKey:BDSKUnderlyingItemErrorKey];
        if (theItem)
            [self highlightBib:theItem];
        
        NSString *errTitle = NSAutosaveOperation == currentSaveOperationType ? NSLocalizedString(@"Unable to autosave file", @"") : NSLocalizedString(@"Unable to save file", @"");
        
        // @@ do this in fileWrapperOfType:forPublications:error:?  should just use error localizedDescription
        NSString *errMsg = [nsError valueForKey:NSLocalizedRecoverySuggestionErrorKey];
        if (nil == errMsg)
            errMsg = NSLocalizedString(@"The underlying cause of this error is unknown.  Please submit a bug report with the file attached.", @"");
        
        nsError = [NSError mutableLocalErrorWithCode:kBDSKDocumentSaveError localizedDescription:errTitle underlyingError:nsError];
        [nsError setValue:errMsg forKey:NSLocalizedRecoverySuggestionErrorKey];        
    }
    // needed because of finalize changes; don't send -clearChangeCount if the save failed for any reason, or if we're autosaving!
    else if (currentSaveOperationType != NSAutosaveOperation)
        [self performSelector:@selector(clearChangeCount) withObject:nil afterDelay:0.01];
    
    // setting to nil is okay
    if (outError) *outError = nsError;
    
    return success;
}

- (void)clearChangeCount{
	[self updateChangeCount:NSChangeCleared];
}

#pragma mark Data representations

- (NSFileWrapper *)fileWrapperOfType:(NSString *)aType error:(NSError **)outError
{
    return [self fileWrapperOfType:aType forPublications:publications error:outError];
}

- (NSFileWrapper *)fileWrapperOfType:(NSString *)aType forPublications:(NSArray *)items error:(NSError **)outError
{
    // first we make sure all edits are committed
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKFinalizeChangesNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionary]];
    
    NSFileWrapper *fileWrapper = nil;
    
    // check if we need a fileWrapper; only needed for RTFD templates
    BDSKTemplate *selectedTemplate = [BDSKTemplate templateForStyle:aType];
    if([selectedTemplate templateFormat] & BDSKRTFDTemplateFormat){
        fileWrapper = [self fileWrapperForPublications:items usingTemplate:selectedTemplate];
        if(fileWrapper == nil){
            if (outError) 
                *outError = [NSError mutableLocalErrorWithCode:kBDSKDocumentSaveError localizedDescription:NSLocalizedString(@"Unable to create file wrapper for the selected template", @"")];
        }
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
    
    // export operations need their own encoding
    if(NSSaveToOperation == currentSaveOperationType)
        encoding = [[BDSKStringEncodingManager sharedEncodingManager] stringEncodingForDisplayedName:[saveTextEncodingPopupButton titleOfSelectedItem]];
        
    if ([aType isEqualToString:BDSKBibTeXDocumentType] || [aType isEqualToUTI:[[NSWorkspace sharedWorkspace] UTIForPathExtension:@"bib"]]){
        if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKAutoSortForCrossrefsKey])
            [self performSortForCrossrefs];
        data = [self bibTeXDataForPublications:items encoding:encoding droppingInternal:NO error:&error];
    }else if ([aType isEqualToString:BDSKRISDocumentType] || [aType isEqualToUTI:[[NSWorkspace sharedWorkspace] UTIForPathExtension:@"ris"]]){
        data = [self RISDataForPublications:items encoding:encoding error:&error];
    }else if ([aType isEqualToString:BDSKMinimalBibTeXDocumentType]){
        data = [self bibTeXDataForPublications:items encoding:encoding droppingInternal:YES error:&error];
    }else if ([aType isEqualToString:BDSKLTBDocumentType]){
        data = [self LTBDataForPublications:items encoding:encoding error:&error];
    }else if ([aType isEqualToString:BDSKAtomDocumentType] || [aType isEqualToUTI:[[NSWorkspace sharedWorkspace] UTIForPathExtension:@"atom"]]){
        data = [self atomDataForPublications:items];
    }else{
        BDSKTemplate *selectedTemplate = [BDSKTemplate templateForStyle:aType];
        BDSKTemplateFormat templateFormat = [selectedTemplate templateFormat];
        
        if (templateFormat & BDSKRTFDTemplateFormat) {
            // @@ shouldn't reach here, should have already redirected to fileWrapperOfType:forPublications:error:
        } else if (templateFormat & BDSKTextTemplateFormat) {
            data = [self stringDataForPublications:items usingTemplate:selectedTemplate];
        } else {
            data = [self attributedStringDataForPublications:items usingTemplate:selectedTemplate];
        }
    }
    
    // grab the underlying error; if we recognize it, pass it up as a kBDSKDocumentSaveError
    if(nil == data && outError){
        // see if this was an encoding failure; if so, we can suggest how to fix it
        // NSLocalizedRecoverySuggestion is appropriate for display as error message in alert
        if(kBDSKDocumentEncodingSaveError == [error code]){
            // encoding conversion failure (string to data)
            NSStringEncoding usedEncoding = [[error valueForKey:NSStringEncodingErrorKey] intValue];
            NSString *usedName = [NSString localizedNameOfStringEncoding:usedEncoding];
            NSString *UTF8Name = [NSString localizedNameOfStringEncoding:NSUTF8StringEncoding];
            
            error = [NSError mutableLocalErrorWithCode:kBDSKDocumentSaveError localizedDescription:NSLocalizedString(@"Unable to save document", @"") underlyingError:error];
            
            // see if TeX conversion is enabled; it will help for ASCII, and possibly other encodings, but not UTF-8
            if ([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShouldTeXifyWhenSavingAndCopyingKey] == NO) {
                [error setValue:[NSString stringWithFormat:NSLocalizedString(@"The document cannot be saved using %@ encoding.  You should enable accented character conversion in the Files preference pane or save using an encoding such as %@.", @""), usedName, UTF8Name] forKey:NSLocalizedRecoverySuggestionErrorKey];
            } else if (NSUTF8StringEncoding != usedEncoding){
                // could suggest disabling TeX conversion, but the error might be from something out of the range of what we try to convert, so combining TeXify && UTF-8 would work
                [error setValue:[NSString stringWithFormat:NSLocalizedString(@"The document cannot be saved using %@ encoding.  You should save using an encoding such as %@.", @""), usedName, UTF8Name] forKey:NSLocalizedRecoverySuggestionErrorKey];
            } else {
                // if UTF-8 fails, you're hosed...
                [error setValue:[NSString stringWithFormat:NSLocalizedString(@"The document cannot be saved using %@ encoding.  Please report this error to BibDesk's developers.", @""), UTF8Name] forKey:NSLocalizedRecoverySuggestionErrorKey];
            }
                        
        } else if(kBDSKDocumentTeXifySaveError == [error code]) {
            NSError *underlyingError = [[error copy] autorelease];
            // TeXification error; this has a specific item
            error = [NSError mutableLocalErrorWithCode:kBDSKDocumentSaveError localizedDescription:NSLocalizedString(@"Unable to save document", @"") underlyingError:underlyingError];
            [error setValue:[underlyingError valueForKey:BDSKUnderlyingItemErrorKey] forKey:BDSKUnderlyingItemErrorKey];
            [error setValue:[NSString stringWithFormat:@"%@  %@", [error localizedDescription], NSLocalizedString(@"If you are unable to fix this item, you must disable character conversion in BibDesk's preferences and save your file in an encoding such as UTF-8.", @"")] forKey:NSLocalizedRecoverySuggestionErrorKey];
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
    NSEnumerator *e = [items objectEnumerator];
	BibItem *pub = nil;
    NSMutableData *d = [NSMutableData data];
    
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);

    [d appendUTF8DataFromString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<xml>\n<records>\n"];
	while(pub = [e nextObject]){
        [d appendUTF8DataFromString:[pub endNoteString]];
    }
    [d appendUTF8DataFromString:@"</records>\n</xml>\n"];
    
    return d;
}

- (NSData *)bibTeXDataForPublications:(NSArray *)items encoding:(NSStringEncoding)encoding droppingInternal:(BOOL)drop error:(NSError **)outError{
    NSParameterAssert(encoding != 0);

    NSEnumerator *e = [items objectEnumerator];
	BibItem *pub = nil;
    NSMutableData *outputData = [NSMutableData dataWithCapacity:4096];
    NSError *error = nil;
        
    BOOL shouldAppendFrontMatter = YES;
    NSString *encodingName = [[BDSKStringEncodingManager sharedEncodingManager] displayedNameForStringEncoding:encoding];

    @try{
    
        if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShouldUseTemplateFile]){
            NSMutableString *templateFile = [NSMutableString stringWithContentsOfFile:[[[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:BDSKOutputTemplateFileKey] stringByExpandingTildeInPath]];
            
            [templateFile appendFormat:@"\n%%%% Created for %@ at %@ \n\n", NSFullUserName(), [NSCalendarDate calendarDate]];

            [templateFile appendFormat:@"\n%%%% Saved with string encoding %@ \n\n", encodingName];
            
            // remove all whitespace so we can make a comparison; just collapsing isn't quite good enough, unfortunately
            NSString *collapsedTemplate = [templateFile stringByRemovingWhitespace];
            NSString *collapsedFrontMatter = [frontMatter stringByRemovingWhitespace];
            if([NSString isEmptyString:collapsedFrontMatter]){
                shouldAppendFrontMatter = NO;
            }else if([collapsedTemplate containsString:collapsedFrontMatter]){
                NSLog(@"*** WARNING! *** Found duplicate preamble %@.  Using template from preferences.", frontMatter);
                shouldAppendFrontMatter = NO;
            }
            
            [outputData appendDataFromString:templateFile useEncoding:encoding];
        }
        
        NSData *doubleNewlineData = [@"\n\n" dataUsingEncoding:encoding];

        // only append this if it wasn't redundant (this assumes that the original frontmatter is either a subset of the necessary frontmatter, or that the user's preferences should override in case of a conflict)
        if(shouldAppendFrontMatter){
            [outputData appendDataFromString:frontMatter useEncoding:encoding];
            [outputData appendData:doubleNewlineData];
        }
            
        if([documentInfo count]){
            [outputData appendDataFromString:[self documentInfoString] useEncoding:encoding];
        }
        
        // output the document's macros:
        [outputData appendDataFromString:[[self macroResolver] bibTeXString] useEncoding:encoding];
        
        // output the bibs
        
        if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);

        while(pub = [e nextObject]){
            [outputData appendData:doubleNewlineData];
            [outputData appendDataFromString:[pub bibTeXStringDroppingInternal:drop] useEncoding:encoding];
        }
        
        // The data from groups is always UTF-8, and we shouldn't convert it; the comment key strings should be representable in any encoding
        if([staticGroups count] > 0){
            [outputData appendDataFromString:@"\n\n@comment{BibDesk Static Groups{\n" useEncoding:encoding];
            [outputData appendData:[self serializedStaticGroupsData]];
            [outputData appendDataFromString:@"}}" useEncoding:encoding];
        }
        if([smartGroups count] > 0){
            [outputData appendDataFromString:@"\n\n@comment{BibDesk Smart Groups{\n" useEncoding:encoding];
            [outputData appendData:[self serializedSmartGroupsData]];
            [outputData appendDataFromString:@"}}" useEncoding:encoding];
        }
        if([urlGroups count] > 0){
            [outputData appendDataFromString:@"\n\n@comment{BibDesk URL Groups{\n" useEncoding:encoding];
            [outputData appendData:[self serializedURLGroupsData]];
            [outputData appendDataFromString:@"}}" useEncoding:encoding];
        }
        if([scriptGroups count] > 0){
            [outputData appendDataFromString:@"\n\n@comment{BibDesk Script Groups{\n" useEncoding:encoding];
            [outputData appendData:[self serializedScriptGroupsData]];
            [outputData appendDataFromString:@"}}" useEncoding:encoding];
        }
        [outputData appendDataFromString:@"\n" useEncoding:encoding];
        
    }
    
    @catch(id exception){
        
        // We used to throw the exception back up, but that caused major grief with the NSErrors.  Since we had multiple call levels adding a local NSError, when we jumped to the handler in writeToURL:ofType:error:, it had an uninitialized error (since dataOfType:error: never returned).  This would occasionally cause a crash when saving or autosaving, since NSDocumentController would apparently try to use the error.  It's much safer just to catch and discard the exception here, then propagate the NSError back up and return nil.
        
        if([exception respondsToSelector:@selector(name)] && [[exception name] isEqual:BDSKEncodingConversionException]){
            // encoding conversion failed
            NSLog(@"Unable to save file with encoding %@", encodingName);
            error = [NSError mutableLocalErrorWithCode:kBDSKDocumentEncodingSaveError localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"Unable to convert the bibliography to encoding %@", @""), encodingName]];
            [error setValue:[NSNumber numberWithInt:encoding] forKey:NSStringEncodingErrorKey];
            
        } else if([exception isKindOfClass:[NSException class]] && [[exception name] isEqual:BDSKTeXifyException]){
            // TeXification failed
            error = [NSError mutableLocalErrorWithCode:kBDSKDocumentTeXifySaveError localizedDescription:[exception reason]];
            [error setValue:[[exception userInfo] valueForKey:@"item"] forKey:BDSKUnderlyingItemErrorKey];
            
        } else {
            // some unknown exception
            NSLog(@"Exception %@ in %@", exception, NSStringFromSelector(_cmd));
            error = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:[exception description]];
        }
        outputData = nil;
    }
	
    if (outError) *outError = error;

    return outputData;
        
}

- (NSData *)RISDataForPublications:(NSArray *)items encoding:(NSStringEncoding)encoding error:(NSError **)error{

    NSParameterAssert(encoding);
    
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    NSString *RISString = [self RISStringForPublications:items];
    NSData *data = [RISString dataUsingEncoding:encoding allowLossyConversion:NO];
    if (nil == data && error) {
        OFError(error, "BDSKSaveError", NSLocalizedDescriptionKey, [NSString stringWithFormat:NSLocalizedString(@"Unable to convert the bibliography to encoding %@", @""), [NSString localizedNameOfStringEncoding:encoding]], NSStringEncodingErrorKey, [NSNumber numberWithInt:encoding], nil);
    }
	return data;
}

- (NSData *)LTBDataForPublications:(NSArray *)items encoding:(NSStringEncoding)encoding error:(NSError **)error{

    NSParameterAssert(encoding);
    
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    
	NSString *bibString = [self previewBibTeXStringForPublications:items];
	if(bibString == nil || 
	   [texTask runWithBibTeXString:bibString generatedTypes:BDSKGenerateLTB] == NO || 
	   [texTask hasLTB] == NO) {
        if (error) OFError(error, "BDSKSaveError", NSLocalizedDescriptionKey, NSLocalizedString(@"Unable to run TeX processes for these publications", @""), nil);
		return nil;
    }
    
    NSMutableString *s = [NSMutableString stringWithString:@"\\documentclass{article}\n\\usepackage{amsrefs}\n\\begin{document}\n\n"];
	[s appendString:[texTask LTBString]];
	[s appendString:@"\n\\end{document}\n"];
    
    NSData *data = [s dataUsingEncoding:encoding allowLossyConversion:NO];
    if (nil == data && error) {
        OFError(error, "BDSKSaveError", NSLocalizedDescriptionKey, [NSString stringWithFormat:NSLocalizedString(@"Unable to convert the bibliography to encoding %@", @""), [NSString localizedNameOfStringEncoding:encoding]], NSStringEncodingErrorKey, [NSNumber numberWithInt:encoding], nil);
    }        
	return data;
}

- (NSData *)stringDataForPublications:(NSArray *)items usingTemplate:(BDSKTemplate *)template{
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    
    OBPRECONDITION(nil != template && ([template templateFormat] & BDSKTextTemplateFormat));
    
    NSString *fileTemplate = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:self publications:items];
    return [fileTemplate dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
}

- (NSData *)attributedStringDataForPublications:(NSArray *)items usingTemplate:(BDSKTemplate *)template{
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    
    OBPRECONDITION(nil != template);
    BDSKTemplateFormat format = [template templateFormat];
    OBPRECONDITION(format & (BDSKRTFTemplateFormat | BDSKDocTemplateFormat | BDSKRichHTMLTemplateFormat));
    NSDictionary *docAttributes = nil;
    NSAttributedString *fileTemplate = [BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:self publications:items documentAttributes:&docAttributes];
    NSMutableDictionary *mutableAttributes = [NSMutableDictionary dictionaryWithDictionary:docAttributes];
    
    // create some useful metadata, with an option to disable for the paranoid
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKDisableExportAttributesKey"]){
        [mutableAttributes addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:NSFullUserName(), NSAuthorDocumentAttribute, [NSDate date], NSCreationTimeDocumentAttribute, [NSLocalizedString(@"BibDesk export of ", @"") stringByAppendingString:[[self fileName] lastPathComponent]], NSTitleDocumentAttribute, nil]];
    }
    
    if (format & BDSKRTFTemplateFormat) {
        return [fileTemplate RTFFromRange:NSMakeRange(0,[fileTemplate length]) documentAttributes:mutableAttributes];
    } else if (format & BDSKRichHTMLTemplateFormat) {
        [mutableAttributes setObject:NSHTMLTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
        NSError *error = nil;
        return [fileTemplate dataFromRange:NSMakeRange(0,[fileTemplate length]) documentAttributes:mutableAttributes error:&error];
    } else if (format & BDSKDocTemplateFormat) {
        return [fileTemplate docFormatFromRange:NSMakeRange(0,[fileTemplate length]) documentAttributes:mutableAttributes];
    } else return nil;
}

- (NSFileWrapper *)fileWrapperForPublications:(NSArray *)items usingTemplate:(BDSKTemplate *)template{
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    
    OBPRECONDITION(nil != template && [template templateFormat] & BDSKRTFDTemplateFormat);
    NSDictionary *docAttributes = nil;
    NSAttributedString *fileTemplate = [BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:self publications:items documentAttributes:&docAttributes];
    
    return [fileTemplate RTFDFileWrapperFromRange:NSMakeRange(0,[fileTemplate length]) documentAttributes:docAttributes];
}

#pragma mark -
#pragma mark Opening and Loading Files

- (BOOL)revertToContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)aType error:(NSError **)outError
{
	// first remove all editor windows, as they will be invalid afterwards
    unsigned int index = [[self windowControllers] count];
    while(--index)
        [[[self windowControllers] objectAtIndex:index] close];
    
    if([super revertToContentsOfURL:absoluteURL ofType:aType error:outError]){
        [staticGroups release];
        staticGroups = nil;
		[tableView deselectAll:self]; // clear before resorting
		[self searchFieldAction:searchField]; // redo the search
        [self sortPubsByColumn:nil]; // resort
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
    
	if ([aType isEqualToString:BDSKBibTeXDocumentType] || [aType isEqualToUTI:[[NSWorkspace sharedWorkspace] UTIForPathExtension:@"bib"]]){
        success = [self readFromBibTeXData:data fromURL:absoluteURL encoding:encoding error:&error];
    }else if([aType isEqualToString:BDSKRISDocumentType] || [aType isEqualToUTI:[[NSWorkspace sharedWorkspace] UTIForPathExtension:@"ris"]]){
		success = [self readFromData:data ofStringType:BDSKRISStringType fromURL:absoluteURL encoding:encoding error:&error];
    }else{
		// sniff the string to see what format we got
		NSString *string = [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
		if(string == nil){
            OFError(&error, BDSKParserError, NSLocalizedDescriptionKey, NSLocalizedString(@"Unable To Open Document", @""), NSLocalizedRecoverySuggestionErrorKey, NSLocalizedString(@"This document does not appear to be a text file.", @""), nil);
            if(outError) *outError = error;
            
            // bypass the partial data warning, since we have no data
			return NO;
        }
        int type = [string contentStringType];
        if(type == BDSKBibTeXStringType){
            success = [self readFromBibTeXData:data fromURL:absoluteURL encoding:encoding error:&error];
		}else if (type == BDSKNoKeyBibTeXStringType){
            OFError(&error, BDSKParserError, NSLocalizedDescriptionKey, NSLocalizedString(@"Unable To Open Document", @""), NSLocalizedRecoverySuggestionErrorKey, NSLocalizedString(@"This file appears to contain invalid BibTeX because of missing cite keys. Try to open using temporary cite keys to fix this.", @""), nil);
            if (outError) *outError = error;
            
            // bypass the partial data warning; we have no data in this case
            return NO;
		}else if (type == BDSKUnknownStringType){
            OFError(&error, BDSKParserError, NSLocalizedDescriptionKey, NSLocalizedString(@"Unable To Open Document", @""), NSLocalizedRecoverySuggestionErrorKey, NSLocalizedString(@"This text file does not contain a recognized data type.", @""), nil);
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
        rv = NSRunCriticalAlertPanel([error localizedDescription] ? [error localizedDescription] : NSLocalizedString(@"Error reading file!",@""),
                                     [NSString stringWithFormat:NSLocalizedString(@"There was a problem reading the file.  Do you want to give up, edit the file to correct the errors, or keep going with everything that could be analyzed?\n\nIf you choose \"Keep Going\" and then save the file, you will probably lose data.",@""), [error localizedDescription]],
                                     NSLocalizedString(@"Give Up",@""),
                                     NSLocalizedString(@"Edit File", @""),
                                     NSLocalizedString(@"Keep Going",@""));
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
    NSMutableArray *newPubs;

    [self setDocumentStringEncoding:encoding];

    NSError *error = nil;
	newPubs = [BibTeXParser itemsFromData:data error:&error frontMatter:frontMatter filePath:[absoluteURL path] document:self];
	if(outError) *outError = error;	
    [self setPublications:newPubs undoable:NO];

    return error == nil;
}

- (BOOL)readFromData:(NSData *)data ofStringType:(int)type fromURL:(NSURL *)absoluteURL encoding:(NSStringEncoding)encoding error:(NSError **)outError {
    
    NSAssert(type == BDSKRISStringType || type == BDSKJSTORStringType || type == BDSKWOSStringType, @"Unknown data type");

    NSError *error = nil;    
    NSString *dataString = [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
    NSMutableArray *newPubs = nil;
    
    if(dataString == nil && outError){
        OFError(&error, BDSKParserError, NSLocalizedDescriptionKey, NSLocalizedString(@"Unable to Interpret", @""), NSLocalizedRecoverySuggestionErrorKey, [NSString stringWithFormat:NSLocalizedString(@"Unable to interpret data as %@.  Try a different encoding.", @"need a single NSString format specifier"), [NSString localizedNameOfStringEncoding:encoding]], NSStringEncodingErrorKey, [NSNumber numberWithInt:encoding], nil);
        *outError = error;
        return NO;
    }
    
	newPubs = [BDSKParserForStringType(type) itemsFromString:dataString
                                                       error:&error
                                                 frontMatter:frontMatter
                                                    filePath:[absoluteURL path]];
        
    if(outError) *outError = error;
    [self setPublications:newPubs undoable:NO];
    
    if (type == BDSKRISStringType) // since we can't save pubmed files as pubmed files:
        [self updateChangeCount:NSChangeDone];
    else // since we can't save other files in its native format
        [self setFileName:nil];
    
    return error == nil;
}

#pragma mark -

- (void)setDocumentStringEncoding:(NSStringEncoding)encoding{
    documentStringEncoding = encoding;
}

- (NSStringEncoding)documentStringEncoding{
    return documentStringEncoding;
}

#pragma mark -

- (void)temporaryCiteKeysAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    NSString *tmpKey = [(NSString *)contextInfo autorelease];
    if(returnCode == NSAlertDefaultReturn){
        NSArray *selItems = [self selectedPublications];
        [self highlightBibs:[self allPublicationsForCiteKey:tmpKey]];
        [self generateCiteKeysForSelectedPublications];
        [self highlightBibs:selItems];
    }
}

- (void)reportTemporaryCiteKeys:(NSString *)tmpKey forNewDocument:(BOOL)isNew{
    if([publications count] == 0)
        return;
    
    NSArray *tmpKeyItems = [self allPublicationsForCiteKey:tmpKey];
    
    if([tmpKeyItems count] == 0)
        return;
    
    if(isNew)
        [self highlightBibs:tmpKeyItems];
    
    NSString *infoFormat = isNew ? NSLocalizedString(@"This document was opened using the temporary cite key \"%@\" for the selected publications.  In order to use your file with BibTeX, you must generate valid cite keys for all of these items.  Do you want me to do this now?", @"")
                            : NSLocalizedString(@"New items are added using the temporary cite key \"%@\".  In order to use your file with BibTeX, you must generate valid cite keys for these items.  Do you want me to do this now?", @"");
    
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Temporary Cite Keys", @"Temporary Cite Keys") 
                                     defaultButton:NSLocalizedString(@"Generate", @"generate cite keys") 
                                   alternateButton:NSLocalizedString(@"Don't Generate", @"don't generate cite keys") 
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
	
    while(pub = [e nextObject]){
		NS_DURING
			[s appendString:@"\n"];
			[s appendString:[pub bibTeXStringDroppingInternal:drop]];
			[s appendString:@"\n"];
		NS_HANDLER
			if([[localException name] isEqualToString:BDSKTeXifyException])
				NSLog(@"Discarding exception raised for item \"%@\"", [pub citeKey]);
			else
				[localException raise];
		NS_ENDHANDLER
    }
	
	return s;
}

- (NSString *)previewBibTeXStringForPublications:(NSArray *)items{
    
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);

	unsigned numberOfPubs = [items count];
	
	NSMutableString *bibString = [[NSMutableString alloc] initWithCapacity:(numberOfPubs * 100)];

	// in case there are @preambles in it
	[bibString appendString:frontMatter];
	[bibString appendString:@"\n"];
	
    @try{
        [bibString appendString:[[self macroResolver] bibTeXString]];
    }
    @catch(id exception){
        if([exception isKindOfClass:[NSException class]] && [[exception name] isEqualToString:BDSKTeXifyException])
            NSLog(@"Discarding exception %@", [exception reason]);
        else
            @throw;
    }
	
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
			NS_DURING
				[bibString appendString:[aPub bibTeXStringDroppingInternal:NO]];
			NS_HANDLER
				if([[localException name] isEqualToString:BDSKTeXifyException])
					NSLog(@"Discarding exception raised for item \"%@\"", [aPub citeKey]);
				else
					[localException raise];
			NS_ENDHANDLER
		}
	}
	
	e = [selParentItems objectEnumerator];
	while(aPub = [e nextObject]){
		NS_DURING
			[bibString appendString:[aPub bibTeXStringDroppingInternal:NO]];
		NS_HANDLER
			if([[localException name] isEqualToString:BDSKTeXifyException])
				NSLog(@"Discarding exception raised for item \"%@\"", [aPub citeKey]);
			else
				[localException raise];
		NS_ENDHANDLER
	}
	
	e = [parentItems objectEnumerator];        
	while(aPub = [e nextObject]){
		NS_DURING
			[bibString appendString:[aPub bibTeXStringDroppingInternal:NO]];
		NS_HANDLER
			if([[localException name] isEqualToString:BDSKTeXifyException])
				NSLog(@"Discarding exception raised for item \"%@\"", [aPub citeKey]);
			else
				[localException raise];
		NS_ENDHANDLER
	}
					
	[selItems release];
	[parentItems release];
	[selParentItems release];
	
	return [bibString autorelease];
}

- (NSString *)RISStringForPublications:(NSArray *)items{
    NSMutableString *s = [NSMutableString string];
	NSEnumerator *e = [items objectEnumerator];
	BibItem *pub;
	
    while(pub = [e nextObject]){
		[s appendString:@"\n"];
		[s appendString:[pub RISStringValue]];
		[s appendString:@"\n"];
    }
	
	return s;
}

- (NSString *)citeStringForPublications:(NSArray *)items citeString:(NSString *)citeString{
	OFPreferenceWrapper *sud = [OFPreferenceWrapper sharedPreferenceWrapper];
	BOOL prependTilde = [sud boolForKey:BDSKCitePrependTildeKey];
	NSString *startCite = [NSString stringWithFormat:@"%@\\%@%@", (prependTilde? @"~" : @""), citeString, [sud stringForKey:BDSKCiteStartBracketKey]]; 
	NSString *endCite = [sud stringForKey:BDSKCiteEndBracketKey]; 
    NSMutableString *s = [NSMutableString stringWithString:startCite];
	
    BOOL sep = [sud boolForKey:BDSKSeparateCiteKey];
	NSString *separator = (sep)? [NSString stringWithFormat:@"%@%@", endCite, startCite] : @",";
    BibItem *pub;
	BOOL first = YES;
    
    if([items count]) NSParameterAssert([[items objectAtIndex:0] isKindOfClass:[BibItem class]]);
    
    NSEnumerator *e = [items objectEnumerator];
    while(pub = [e nextObject]){
		if(first) first = NO;
		else [s appendString:separator];
        [s appendString:[pub citeKey]];
    }
	[s appendString:endCite];
	
	return s;
}

#pragma mark -
#pragma mark New publications from pasteboard

- (BOOL)addPublicationsFromPasteboard:(NSPasteboard *)pb error:(NSError **)outError{
	// these are the types we support, the order here is important!
    NSString *type = [pb availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, BDSKWeblocFilePboardType, BDSKReferenceMinerStringPboardType, NSStringPboardType, NSFilenamesPboardType, NSURLPboardType, nil]];
    NSArray *newPubs = nil;
    NSArray *newFilePubs = nil;
	NSError *error = nil;
    NSString *temporaryCiteKey = nil;
    
    if([type isEqualToString:BDSKBibItemPboardType]){
        NSData *pbData = [pb dataForType:BDSKBibItemPboardType];
		newPubs = [self newPublicationsFromArchivedData:pbData];
    } else if([type isEqualToString:BDSKReferenceMinerStringPboardType]){ // pasteboard type from Reference Miner, determined using Pasteboard Peeker
        NSString *pbString = [pb stringForType:BDSKReferenceMinerStringPboardType]; 	
        // sniffing the string for RIS is broken because RefMiner puts junk at the beginning
		newPubs = [self newPublicationsForString:pbString type:BDSKRISStringType error:&error];
        if(temporaryCiteKey = [[error userInfo] valueForKey:@"temporaryCiteKey"])
            error = nil; // accept temporary cite keys, but show a warning later
    }else if([type isEqualToString:NSStringPboardType]){
        NSString *pbString = [pb stringForType:NSStringPboardType]; 	
		// sniff the string to see what its type is
		newPubs = [self newPublicationsForString:pbString type:[pbString contentStringType] error:&error];
        if(temporaryCiteKey = [[error userInfo] valueForKey:@"temporaryCiteKey"])
            error = nil; // accept temporary cite keys, but show a warning later
    }else if([type isEqualToString:NSFilenamesPboardType]){
		NSArray *pbArray = [pb propertyListForType:NSFilenamesPboardType]; // we will get an array
        // try this first, in case these files are a type we can open
        NSMutableArray *unparseableFiles = [[NSMutableArray alloc] initWithCapacity:[pbArray count]];
        newPubs = [self extractPublicationsFromFiles:pbArray unparseableFiles:unparseableFiles error:&error];
		if(temporaryCiteKey = [[error userInfo] objectForKey:@"temporaryCiteKey"])
            error = nil; // accept temporary cite keys, but show a warning later
        if ([unparseableFiles count] > 0) {
            newFilePubs = [self newPublicationsForFiles:unparseableFiles error:&error];
            newPubs = [newPubs arrayByAddingObjectsFromArray:newFilePubs];
        }
        [unparseableFiles release];
    }else if([type isEqualToString:BDSKWeblocFilePboardType]){
        NSURL *pbURL = [NSURL URLWithString:[pb stringForType:BDSKWeblocFilePboardType]]; 	
		if([pbURL isFileURL])
            newPubs = newFilePubs = [self newPublicationsForFiles:[NSArray arrayWithObject:[pbURL path]] error:&error];
        else
            newPubs = [self newPublicationForURL:pbURL error:&error];
    }else if([type isEqualToString:NSURLPboardType]){
        NSURL *pbURL = [NSURL URLFromPasteboard:pb]; 	
		if([pbURL isFileURL])
            newPubs = newFilePubs = [self newPublicationsForFiles:[NSArray arrayWithObject:[pbURL path]] error:&error];
        else
            newPubs = [self newPublicationForURL:pbURL error:&error];
	}else{
        // errors are key, value
        OFError(&error, BDSKParserError, NSLocalizedDescriptionKey, NSLocalizedString(@"Did not find anything appropriate on the pasteboard", @"BibDesk couldn't find any files or bibliography information in the data it received."), nil);
	}
	
    if (newPubs == nil || error != nil){
        if(outError) *outError = error;
		return NO;
    }
    
	if ([newPubs count] == 0) 
		return YES; // nothing to do
	
    [groupTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];    
	[self addPublications:newPubs];
	[self highlightBibs:newPubs];
	if (newFilePubs != nil){
        // tried checking [pb isEqual:[NSPasteboard pasteboardWithName:NSDragPboard]] before using delay, but pb is a CFPasteboardUnique
        [newFilePubs makeObjectsPerformSelector:@selector(autoFilePaperAfterDelay)];
    }
    
    // set Date-Added to the current date, since unarchived items will have their own (incorrect) date
    NSCalendarDate *importDate = [NSCalendarDate date];
    [newPubs makeObjectsPerformSelector:@selector(setField:toValue:) withObject:BDSKDateAddedString withObject:[importDate description]];
	
	if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKEditOnPasteKey]) {
		[self editPubCmd:nil]; // this will ask the user when there are many pubs
	}
	
	[[self undoManager] setActionName:NSLocalizedString(@"Add Publication",@"")];
    
    // set up the smart group that shows the latest import
    // @@ do this for items added via the editor?  doesn't seem as useful
    if(lastImportGroup == nil)
        lastImportGroup = [[BDSKStaticGroup alloc] initWithLastImport:newPubs];
    else 
        [lastImportGroup setPublications:newPubs];
    
    if(temporaryCiteKey != nil)
        [self reportTemporaryCiteKeys:temporaryCiteKey forNewDocument:NO];
    
    return YES;
}

- (NSArray *)newPublicationsFromArchivedData:(NSData *)data{
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    
    // we set the delegate so we can pass it the macroresolver for any complex string it might decode
    [unarchiver setDelegate:self];
    
    NSArray *newPubs = [unarchiver decodeObjectForKey:@"publications"];
    [unarchiver finishDecoding];
    [unarchiver release];
    
    return newPubs;
}

- (BDSKMacroResolver *)unarchiverMacroResolver:(NSKeyedUnarchiver *)unarchiver{
    return macroResolver;
}

- (NSArray *)newPublicationsForString:(NSString *)string type:(int)type error:(NSError **)outError {
    NSArray *newPubs = nil;
    NSData *data = nil;
    NSError *parseError = nil;
    
    if(type == BDSKBibTeXStringType){
        data = [string dataUsingEncoding:NSUTF8StringEncoding];
        newPubs = [BibTeXParser itemsFromData:data error:&parseError document:self];
    }else if(type == BDSKNoKeyBibTeXStringType){
        data = [[string stringWithPhoneyCiteKeys:@"FixMe"] dataUsingEncoding:NSUTF8StringEncoding];
        newPubs = [BibTeXParser itemsFromData:data error:&parseError document:self];
	}else if (type != BDSKUnknownStringType){
        newPubs = [BDSKParserForStringType(type) itemsFromString:string error:&parseError];
    }
    
    // The parser methods may return a non-empty array (partial data) if they failed; we check for parseError != nil as an error condition, then, although that's generally not correct
	if(parseError != nil) {

		// run a modal dialog asking if we want to use partial data or give up
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error reading file!",@"")
                                         defaultButton:NSLocalizedString(@"Cancel",@"")
                                       alternateButton:NSLocalizedString(@"Edit data", @"")
                                           otherButton:NSLocalizedString(@"Keep going",@"")
                             informativeTextWithFormat:NSLocalizedString(@"There was a problem inserting the data. Do you want to ignore this data, open a window containing the data to edit it and remove the errors, or keep going and use everything that BibDesk could analyse?\n(It's likely that choosing \"Keep Going\" will lose some data.)",@"")];
		int rv = [alert runModal];
        
		if(rv == NSAlertDefaultReturn){
			// the user said to give up
			newPubs = nil;
		}else if (rv == NSAlertAlternateReturn){
			// they said to edit the file.
			[[BDSKErrorObjectController sharedErrorObjectController] showEditorForLastPasteDragError];
			newPubs = nil;	
		}else if(rv == NSAlertOtherReturn){
			// the user said to keep going, so if they save, they might clobber data...
		}		
	}else if(type == BDSKNoKeyBibTeXStringType && parseError == nil){

        // return an error when we inserted temporary keys, let the caller decide what to do with it
        // don't override a parseError though, as that is probably more relevant
        OFError(&parseError, BDSKParserError, NSLocalizedDescriptionKey, NSLocalizedString(@"Temporary Cite Keys", @"Temporary Cite Keys"), @"temporaryCiteKey", @"FixMe", nil);
    }

    // we reach this for unsupported data types (BDSKUnknownStringType)
	if ([newPubs count] == 0 && parseError == nil)
        OFError(&parseError, BDSKParserError, NSLocalizedDescriptionKey, NSLocalizedString(@"BibDesk couldn't find bibliography data in this text.", @"Error message when pasting unknown text in."), nil);

	if(outError) *outError = parseError;
    return newPubs;
}

// sniff the contents of each file, returning them in an array of BibItems, while unparseable files are added to the mutable array passed as a parameter
- (NSArray *)extractPublicationsFromFiles:(NSArray *)filenames unparseableFiles:(NSMutableArray *)unparseableFiles error:(NSError **)outError {
    
    NSParameterAssert(unparseableFiles != nil);
    NSParameterAssert([unparseableFiles count] == 0);
    
    NSEnumerator *e = [filenames objectEnumerator];
    NSString *fileName;
    NSString *contentString;
    NSMutableArray *array = [NSMutableArray array];
    int type = -1;
    
    // some common types that people might use as attachments; we don't need to sniff these
    NSSet *unreadableTypes = [NSSet caseInsensitiveStringSetWithObjects:@"pdf", @"ps", @"eps", @"doc", @"htm", @"textClipping", @"webloc", @"html", @"rtf", @"tiff", @"tif", @"png", @"jpg", @"jpeg", nil];
    
    while(fileName = [e nextObject]){
        type = -1;
        
        // we /can/ create a string from these (usually), but there's no point in wasting the memory
        if([unreadableTypes containsObject:[fileName pathExtension]]){
            [unparseableFiles addObject:fileName];
            continue;
        }
        
        contentString = [[NSString alloc] initWithContentsOfFile:fileName encoding:[self documentStringEncoding] guessEncoding:YES];
        
        if(contentString != nil){
            type = [contentString contentStringType];
    
            if(type >= 0){
                NSError *parseError = nil;
                [array addObjectsFromArray:[self newPublicationsForString:contentString type:type error:&parseError]];
                if(parseError && outError) *outError = parseError;
            } else {
                [contentString release];
                contentString = nil;
            }
        }
        if(contentString == nil || type == -1)
            [unparseableFiles addObject:fileName];
    }

    return array;
}

- (NSArray *)newPublicationsForFiles:(NSArray *)filenames error:(NSError **)error {
    NSMutableArray *newPubs = [NSMutableArray arrayWithCapacity:[filenames count]];
	NSEnumerator *e = [filenames objectEnumerator];
	NSString *fnStr = nil;
	NSURL *url = nil;
	BibItem *newBI = nil;
    	
	while(fnStr = [e nextObject]){
        fnStr = [fnStr stringByStandardizingPath];
		if(url = [NSURL fileURLWithPath:fnStr]){
            NSError *xerror = nil;
			NSData *btData = nil;
            
            if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKReadExtendedAttributesKey])
                btData = [[NSFileManager defaultManager] extendedAttributeNamed:OMNI_BUNDLE_IDENTIFIER @".bibtexstring" atPath:fnStr traverseLink:NO error:&xerror];

            if(btData == nil && [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShouldUsePDFMetadata])
                newBI = [BibItem itemWithPDFMetadata:[PDFMetadata metadataForURL:url error:&xerror]];
            
            if(newBI == nil && (btData == nil || (newBI = [[BibTeXParser itemsFromData:btData error:&xerror document:self] firstObject]) == nil))
                newBI = [[[BibItem alloc] init] autorelease];
            
            [newBI setField:BDSKLocalUrlString toValue:[url absoluteString]];
			[newPubs addObject:newBI];
            
            newBI = nil;
		}
	}
	
	return newPubs;
}

- (NSArray *)newPublicationForURL:(NSURL *)url error:(NSError **)error {
    if(url == nil){
        OFError(error, BDSKParserError, NSLocalizedDescriptionKey, NSLocalizedString(@"Did not find expected URL on the pasteboard", @"BibDesk couldn't find any URL in the data it received."), nil);
        return nil;
    }
    
	BibItem *newBI = [[[BibItem alloc] init] autorelease];
    
    [newBI setField:BDSKUrlString toValue:[url absoluteString]];
    
	return [NSArray arrayWithObject:newBI];
}

#pragma mark -
#pragma mark Cite Key and Crossref lookup

- (OFMultiValueDictionary *)itemsForCiteKeys{
	return itemsForCiteKeys;
}

- (void)rebuildItemsForCiteKeys{
	[itemsForCiteKeys release];
    itemsForCiteKeys = [[OFMultiValueDictionary alloc] initWithKeyCallBacks:&BDSKCaseInsensitiveStringKeyDictionaryCallBacks];
	NSArray *pubs = [publications copy];
	[self addToItemsForCiteKeys:pubs];
	[pubs release];
}

- (void)addToItemsForCiteKeys:(NSArray *)pubs{
	BibItem *pub;
	NSEnumerator *e = [pubs objectEnumerator];
	
	while(pub = [e nextObject])
		[itemsForCiteKeys addObject:pub forKey:[pub citeKey]];
}

- (void)removeFromItemsForCiteKeys:(NSArray *)pubs{
	BibItem *pub;
	NSEnumerator *e = [pubs objectEnumerator];
	
	while(pub = [e nextObject])
		[itemsForCiteKeys removeObject:pub forKey:[pub citeKey]];
}

- (BibItem *)publicationForCiteKey:(NSString *)key{
	if ([NSString isEmptyString:key]) 
		return nil;
    
	NSArray *items = [[self itemsForCiteKeys] arrayForKey:key];
	
	if ([items count] == 0)
		return nil;
    // may have duplicate items for the same key, so just return the first one
    return [items objectAtIndex:0];
}

- (NSArray *)allPublicationsForCiteKey:(NSString *)key{
	NSArray *items = nil;
    if ([NSString isEmptyString:key] == NO) 
		items = [[self itemsForCiteKeys] arrayForKey:key];
    return (items == nil) ? [NSArray array] : items;
}

- (BOOL)citeKeyIsUsed:(NSString *)aCiteKey byItemOtherThan:(BibItem *)anItem{
    NSArray *items = [[self itemsForCiteKeys] arrayForKey:aCiteKey];
    
	if ([items count] > 1)
		return YES;
	if ([items count] == 1 && [items objectAtIndex:0] != anItem)	
		return YES;
	return NO;
}

- (BOOL)citeKeyIsCrossreffed:(NSString *)key{
	if ([NSString isEmptyString:key]) 
		return NO;
    
	NSEnumerator *pubEnum = [publications objectEnumerator];
	BibItem *pub;
	
	while (pub = [pubEnum nextObject]) {
		if ([key caseInsensitiveCompare:[pub valueOfField:BDSKCrossrefString inherit:NO]] == NSOrderedSame) {
			return YES;
        }
	}
	return NO;
}

- (void)changeCrossrefKey:(NSString *)oldKey toKey:(NSString *)newKey{
	if ([NSString isEmptyString:oldKey]) 
		return;
    
	NSEnumerator *pubEnum = [publications objectEnumerator];
	BibItem *pub;
	
	while (pub = [pubEnum nextObject]) {
		if ([oldKey caseInsensitiveCompare:[pub valueOfField:BDSKCrossrefString inherit:NO]] == NSOrderedSame) {
			[pub setField:BDSKCrossrefString toValue:newKey];
        }
	}
}

- (void)invalidateGroupsForCrossreffedCiteKey:(NSString *)key{
	if ([NSString isEmptyString:key]) 
		return;
    
	NSEnumerator *pubEnum = [publications objectEnumerator];
	BibItem *pub;
	
	while (pub = [pubEnum nextObject]) {
		if ([key caseInsensitiveCompare:[pub valueOfField:BDSKCrossrefString inherit:NO]] == NSOrderedSame) {
			[pub invalidateGroupNames];
        }
	}
}

#pragma mark -
#pragma mark Sorting

- (void) tableView: (NSTableView *) theTableView didClickTableColumn: (NSTableColumn *) tableColumn{
	// check whether this is the right kind of table view and don't re-sort when we have a contextual menu click
    if ([[NSApp currentEvent] type] == NSRightMouseDown) 
        return;
    if (tableView == theTableView){
        [self sortPubsByColumn:tableColumn];
	}else if (groupTableView == theTableView){
        [self sortGroupsByKey:nil];
	}

}

- (NSSortDescriptor *)sortDescriptorForTableColumnIdentifier:(NSString *)tcID ascending:(BOOL)ascend{

    NSParameterAssert([NSString isEmptyString:tcID] == NO);
    
    NSSortDescriptor *sortDescriptor = nil;
    
	if([tcID isEqualToString:BDSKCiteKeyString]){
		sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"citeKey" ascending:ascend selector:@selector(localizedCaseInsensitiveNumericCompare:)];
        
	}else if([tcID isEqualToString:BDSKTitleString]){
		
		sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"title.stringByRemovingTeXAndStopWords" ascending:ascend selector:@selector(localizedCaseInsensitiveCompare:)];
		
	}else if([tcID isEqualToString:BDSKContainerString]){
		
        sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"container.stringByRemovingTeXAndStopWords" ascending:ascend selector:@selector(localizedCaseInsensitiveCompare:)];
        
	}else if([tcID isEqualToString:BDSKDateString]){
		
		sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"date" ascending:ascend selector:@selector(compare:)];		
        
	}else if([tcID isEqualToString:BDSKDateAddedString]){
		
        sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"dateAdded" ascending:ascend selector:@selector(compare:)];
        
	}else if([tcID isEqualToString:BDSKDateModifiedString]){
		
        sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"dateModified" ascending:ascend selector:@selector(compare:)];
        
	}else if([tcID isEqualToString:BDSKFirstAuthorString] ||
             [tcID isEqualToString:BDSKAuthorString] || [tcID isEqualToString:@"Authors"]){
        
        sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"firstAuthor" ascending:ascend selector:@selector(sortCompare:)];
        
	}else if([tcID isEqualToString:BDSKSecondAuthorString]){
		
        sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"secondAuthor" ascending:ascend selector:@selector(sortCompare:)];
		
	}else if([tcID isEqualToString:BDSKThirdAuthorString]){
		
        sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"thirdAuthor" ascending:ascend selector:@selector(sortCompare:)];
        
	}else if([tcID isEqualToString:BDSKLastAuthorString]){
		
        sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"lastAuthor" ascending:ascend selector:@selector(sortCompare:)];
        
	}else if([tcID isEqualToString:BDSKFirstAuthorEditorString] ||
             [tcID isEqualToString:BDSKAuthorEditorString]){
        
        sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"firstAuthorOrEditor" ascending:ascend selector:@selector(sortCompare:)];
        
	}else if([tcID isEqualToString:BDSKSecondAuthorEditorString]){
		
        sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"secondAuthorOrEditor" ascending:ascend selector:@selector(sortCompare:)];
		
	}else if([tcID isEqualToString:BDSKThirdAuthorEditorString]){
		
        sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"thirdAuthorOrEditor" ascending:ascend selector:@selector(sortCompare:)];
        
	}else if([tcID isEqualToString:BDSKLastAuthorEditorString]){
		
        sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"lastAuthorOrEditor" ascending:ascend selector:@selector(sortCompare:)];
        
	}else if([tcID isEqualToString:BDSKEditorString]){
		
        sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"pubEditors.@firstObject" ascending:ascend selector:@selector(sortCompare:)];

	}else if([tcID isEqualToString:BDSKPubTypeString]){

        sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"pubType" ascending:ascend selector:@selector(localizedCaseInsensitiveCompare:)];
        
    }else if([tcID isEqualToString:BDSKItemNumberString]){
        
        sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"fileOrder" ascending:ascend selector:@selector(compare:)];		
        
    }else if([tcID isEqualToString:BDSKBooktitleString]){
        
        sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:@"Booktitle.stringByRemovingTeXAndStopWords" ascending:ascend selector:@selector(localizedCaseInsensitiveCompare:)];
        
    }else if([[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKBooleanFieldsKey] containsObject:tcID] ||
             [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKTriStateFieldsKey] containsObject:tcID] ||
             [[BibTypeManager sharedManager] isURLField:tcID]){
        
        // use the triStateCompare: for URL fields so the subsort is more useful (this turns the URL comparison into empty/non-empty)
        sortDescriptor = [[NSSortDescriptor alloc] initWithKey:tcID ascending:ascend selector:@selector(triStateCompare:)];
        
    }else if([[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRatingFieldsKey] containsObject:tcID]){
        
        // Use NSSortDescriptor instead of the BDSKTableSortDescriptor, so 0 values are handled correctly; if we ever store these as NSNumbers, the selector must be changed to compare:.
        sortDescriptor = [[NSSortDescriptor alloc] initWithKey:tcID ascending:ascend selector:@selector(numericCompare:)];
        
    }else{
        // this assumes that all other columns must be NSString objects
        sortDescriptor = [[BDSKTableSortDescriptor alloc] initWithKey:tcID ascending:ascend selector:@selector(localizedCaseInsensitiveNumericCompare:)];
	}
 
    OBASSERT(sortDescriptor);
    return [sortDescriptor autorelease];
}

- (void)sortPubsByColumn:(NSTableColumn *)tableColumn{
    
    // use this for a subsort
    NSString *lastSortedTableColumnIdentifier = [lastSelectedColumnForSort identifier];
        
    // cache the selection; this works for multiple publications
    NSArray *pubsToSelect = nil;
    if([tableView numberOfSelectedRows])
        pubsToSelect = [self selectedPublications];
    
    // a nil argument means resort the current column in the same order
    if(tableColumn == nil){
        if(lastSelectedColumnForSort == nil)
            return;
        tableColumn = lastSelectedColumnForSort; // use the previous one
        sortDescending = !sortDescending; // we'll reverse this again in the next step
    }
    
    if (lastSelectedColumnForSort == tableColumn) {
        // User clicked same column, change sort order
        sortDescending = !sortDescending;
    } else {
        // User clicked new column, change old/new column headers,
        // save new sorting selector, and re-sort the array.
        sortDescending = NO;
        if (lastSelectedColumnForSort) {
            [tableView setIndicatorImage: nil
                           inTableColumn: lastSelectedColumnForSort];
            [lastSelectedColumnForSort release];
        }
        lastSelectedColumnForSort = [tableColumn retain];
        [tableView setHighlightedTableColumn: tableColumn]; 
	}
    
    // should never be nil at this point
    OBPRECONDITION(lastSortedTableColumnIdentifier);
    
    NSArray *sortDescriptors = [NSArray arrayWithObjects:[self sortDescriptorForTableColumnIdentifier:[tableColumn identifier] ascending:!sortDescending], [self sortDescriptorForTableColumnIdentifier:lastSortedTableColumnIdentifier ascending:!sortDescending], nil];
    [tableView setSortDescriptors:sortDescriptors]; // just using this to store them; it's really a no-op
    

    // @@ DON'T RETURN WITHOUT RESETTING THIS!
    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    [tableView setDelegate:nil];
    
    // sort by new primary column, subsort with previous primary column
    [shownPublications mergeSortUsingDescriptors:sortDescriptors];

    // Set the graphic for the new column header
    [tableView setIndicatorImage: (sortDescending ?
                                   [NSImage imageNamed:@"NSDescendingSortIndicator"] :
                                   [NSImage imageNamed:@"NSAscendingSortIndicator"])
                   inTableColumn: tableColumn];

    // have to reload so the rows get set up right, but a full updateUI flashes the preview, which is annoying (and the preview won't change if we're maintaining the selection)
    [tableView reloadData];

    // fix the selection
    [self highlightBibs:pubsToSelect];
    [tableView scrollRowToCenter:[tableView selectedRow]]; // just go to the last one

    // reset ourself as delegate
    [tableView setDelegate:self];
}

- (void)sortPubsByDefaultColumn{

    NSDictionary *windowSetup = [self mainWindowSetupDictionaryFromExtendedAttributes];        
    
    NSString *colName = nil == windowSetup ? [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKDefaultSortedTableColumnKey] : [windowSetup objectForKey:BDSKDefaultSortedTableColumnKey];
    if([NSString isEmptyString:colName])
        return;
    
    NSTableColumn *tc = [tableView tableColumnWithIdentifier:colName];
    if(tc == nil)
        return;
    
    lastSelectedColumnForSort = [tc retain];
    sortDescending = nil == windowSetup ? [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKDefaultSortedTableColumnIsDescendingKey] : [windowSetup boolForKey:BDSKDefaultSortedTableColumnIsDescendingKey];
    [self sortPubsByColumn:nil];
    [tableView setHighlightedTableColumn:tc];
}

- (void)saveSortOrder{ 
    // @@ if we switch to NSArrayController, we should just archive the sort descriptors (see BDSKFileContentSearchController)
    OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
    [pw setObject:[lastSelectedColumnForSort identifier] forKey:BDSKDefaultSortedTableColumnKey];
    [pw setBool:sortDescending forKey:BDSKDefaultSortedTableColumnIsDescendingKey];
    [pw setObject:sortGroupsKey forKey:BDSKSortGroupsKey];
    [pw setBool:sortGroupsDescending forKey:BDSKSortGroupsDescendingKey];    
}  

#pragma mark -
#pragma mark Table Column Setup

- (NSImage *)headerImageForField:(NSString *)field {
	static NSMutableDictionary *headerImageCache = nil;
	
	if (headerImageCache == nil) {
		NSDictionary *paths = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKTableHeaderImagesKey];
		headerImageCache = [[NSMutableDictionary alloc] initWithCapacity:1];
		if (paths) {
			NSEnumerator *keyEnum = [paths keyEnumerator];
			NSString *key, *path;
			NSImage *image;
			
			while (key = [keyEnum nextObject]) {
				path = [paths objectForKey:key];
				if ([[NSFileManager defaultManager] fileExistsAtPath:path] &&
					(image = [[NSImage alloc] initWithContentsOfFile:path])) {
					[headerImageCache setObject:image forKey:key];
					[image release];
				}
			}
		}
		if ([headerImageCache objectForKey:BDSKLocalUrlString] == nil)
			[headerImageCache setObject:[NSImage imageNamed:@"TinyFile"] forKey:BDSKLocalUrlString];
	}
	
	return [headerImageCache objectForKey:field];
}

- (NSString *)headerTitleForField:(NSString *)field {
	static NSMutableDictionary *headerTitleCache = nil;
	
	if (headerTitleCache == nil) {
		NSDictionary *titles = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKTableHeaderTitlesKey];
		headerTitleCache = [[NSMutableDictionary alloc] initWithCapacity:1];
		if (titles) {
			NSEnumerator *keyEnum = [titles keyEnumerator];
			NSString *key, *title;
			
			while (key = [keyEnum nextObject]) {
				title = [titles objectForKey:key];
				[headerTitleCache setObject:title forKey:key];
			}
		}
		if ([headerTitleCache objectForKey:BDSKUrlString] == nil)
			[headerTitleCache setObject:@"@" forKey:BDSKUrlString];
	}
	
	return [headerTitleCache objectForKey:field];
}

- (NSArray *)defaultTableColumnIdentifiers {
    NSArray *array = [[self mainWindowSetupDictionaryFromExtendedAttributes] objectForKey:BDSKShownColsNamesKey];
    if (nil == array)
        array = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKShownColsNamesKey];
    return array;
}

- (NSDictionary *)defaultTableColumnWidthsAndIdentifiers {
    NSDictionary *dict = [[self mainWindowSetupDictionaryFromExtendedAttributes] objectForKey:BDSKColumnWidthsKey];
    if (nil == dict)
        dict = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKColumnWidthsKey];
    return dict;
}

- (void)setupDefaultTableColumns{
    [self setupTableColumnsWithIdentifiers:[self defaultTableColumnIdentifiers]];
}

//note - ********** the notification handling method will add NSTableColumn instances to the tableColumns dictionary.
- (void)setupTableColumnsWithIdentifiers:(NSArray *)identifiers {
    
    NSEnumerator *shownColNamesE = [identifiers objectEnumerator];
    NSTableColumn *tc;
    NSString *colName;
    BibTypeManager *typeManager = [BibTypeManager sharedManager];
    
    // get width settings from this doc's xattrs or from prefs
    NSDictionary *tcWidthsByIdentifier = [self defaultTableColumnWidthsAndIdentifiers];
    NSNumber *tcWidth = nil;
    NSImageCell *imageCell = [[[NSImageCell alloc] init] autorelease];
	
    NSMutableArray *columns = [NSMutableArray arrayWithCapacity:[identifiers count]];
	
	while(colName = [shownColNamesE nextObject]){
		tc = [tableView tableColumnWithIdentifier:colName];
		
		if(tc == nil){
			NSImage *image;
			NSString *title;
			
			// it is a new column, so create it
			tc = [[[NSTableColumn alloc] initWithIdentifier:colName] autorelease];
            [tc setResizingMask:(NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask)];
			[tc setEditable:NO];

            if([typeManager isURLField:colName]){
                [tc setDataCell:imageCell];
            }else if([typeManager isRatingField:colName]){
				BDSKRatingButtonCell *ratingCell = [[[BDSKRatingButtonCell alloc] initWithMaxRating:5] autorelease];
				[ratingCell setBordered:NO];
				[ratingCell setAlignment:NSCenterTextAlignment];
                [tc setDataCell:ratingCell];
            }else if([typeManager isBooleanField:colName]){
				NSButtonCell *switchButtonCell = [[[NSButtonCell alloc] initTextCell:@""] autorelease];
				[switchButtonCell setButtonType:NSSwitchButton];
				[switchButtonCell setImagePosition:NSImageOnly];
				[switchButtonCell setControlSize:NSSmallControlSize];
                [switchButtonCell setAllowsMixedState:NO];
                [tc setDataCell:switchButtonCell];
			}else if([typeManager isTriStateField:colName]){
				NSButtonCell *switchButtonCell = [[[NSButtonCell alloc] initTextCell:@""] autorelease];
				[switchButtonCell setButtonType:NSSwitchButton];
				[switchButtonCell setImagePosition:NSImageOnly];
				[switchButtonCell setControlSize:NSSmallControlSize];
                [switchButtonCell setAllowsMixedState:YES];
                [tc setDataCell:switchButtonCell];
			}
			if(image = [self headerImageForField:colName]){
				[(NSCell *)[tc headerCell] setImage:image];
			}else if(title = [self headerTitleForField:colName]){
				[[tc headerCell] setStringValue:title];
			}else{	
				[[tc headerCell] setStringValue:NSLocalizedStringFromTable(colName, @"BibTeXKeys", @"")];
			}
		}
		
		[columns addObject:tc];
	}
	
    [tableView removeAllTableColumns];
    NSEnumerator *columnsE = [columns objectEnumerator];
	
    while(tc = [columnsE nextObject]){
        if(tcWidthsByIdentifier && 
		  (tcWidth = [tcWidthsByIdentifier objectForKey:[tc identifier]])){
			[tc setWidth:[tcWidth floatValue]];
        }

		[tableView addTableColumn:tc];
    }
    [tableView setHighlightedTableColumn: lastSelectedColumnForSort]; 
    [tableView tableViewFontChanged:nil];
    
    [self updateColumnsMenu];
}

- (NSMenu *)tableView:(NSTableView *)tv menuForTableHeaderColumn:(NSTableColumn *)tc{
	if(tv != tableView)
		return nil;
	// for now, just returns the same all the time.
	// Could customize menu for details of selected item.
	return columnsMenu;
}

- (IBAction)columnsMenuSelectTableColumn:(id)sender{
    
    NSMutableArray *shownColumns = [NSMutableArray arrayWithArray:[tableView tableColumnIdentifiers]];

    if ([sender state] == NSOnState) {
        [shownColumns removeObject:[sender title]];
        [sender setState:NSOffState];
    }else{
        if(![shownColumns containsObject:[sender title]]){
            [shownColumns addObject:[sender title]];
        }
        [sender setState:NSOnState];
    }
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:shownColumns
                                                      forKey:BDSKShownColsNamesKey];
    [self setupTableColumnsWithIdentifiers:shownColumns];
    [self updateUI];
}
    
- (void)addColumnSheetDidEnd:(BDSKAddFieldSheetController *)addFieldController returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    NSString *newColumnName = [addFieldController field];
    
    if(newColumnName == nil || returnCode == NSCancelButton)
        return;
    
    NSMutableArray *shownColumns = [NSMutableArray arrayWithArray:[tableView tableColumnIdentifiers]];

    // Check if an object already exists in the tableview, bail without notification if it does
    // This means we can't have a column more than once.
    if ([shownColumns containsObject:newColumnName])
        return;

    // Store the new column in the preferences
    [shownColumns addObject:newColumnName];
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:shownColumns
                                                      forKey:BDSKShownColsNamesKey];
    
    // Actually redraw the view now with the new column.
    [self setupTableColumnsWithIdentifiers:shownColumns];
    [self updateUI];
}

- (IBAction)columnsMenuAddTableColumn:(id)sender{
    // first we fill the popup
	BibTypeManager *typeMan = [BibTypeManager sharedManager];
    NSArray *colNames = [typeMan allFieldNamesIncluding:[NSArray arrayWithObjects:BDSKPubTypeString, BDSKCiteKeyString, BDSKDateString, BDSKDateAddedString, BDSKDateModifiedString, BDSKFirstAuthorString, BDSKSecondAuthorString, BDSKThirdAuthorString, BDSKLastAuthorString, BDSKFirstAuthorEditorString, BDSKSecondAuthorEditorString, BDSKThirdAuthorEditorString, BDSKAuthorEditorString, BDSKLastAuthorEditorString, BDSKItemNumberString, BDSKContainerString, nil]
                                              excluding:[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKShownColsNamesKey]];
    
    BDSKAddFieldSheetController *addFieldController = [[BDSKAddFieldSheetController alloc] initWithPrompt:NSLocalizedString(@"Name of column to add:",@"")
                                                                                              fieldsArray:colNames];
	[addFieldController beginSheetModalForWindow:documentWindow
                                   modalDelegate:self
                                  didEndSelector:@selector(addColumnSheetDidEnd:returnCode:contextInfo:)
                                     contextInfo:NULL];
    [addFieldController release];
}

/*
 Returns action/contextual menu that contains items appropriate for the current selection.
 The code may need to be revised if the menu's contents are changed.
*/
- (NSMenu *)tableView:(NSTableView *)tv contextMenuForRow:(int)row column:(int)column {
	NSMenu *myMenu = nil;
    NSMenuItem *theItem = nil;
    
	if (column == -1 || row == -1) 
		return nil;
	
	if(tv == tableView){
		
		NSString *tcId = [[[tableView tableColumns] objectAtIndex:column] identifier];
        NSURL *theURL = nil;
        
		if([[BibTypeManager sharedManager] isLocalFileField:tcId]){
			myMenu = [[fileMenu copyWithZone:[NSMenu menuZone]] autorelease];
			[[myMenu itemAtIndex:0] setRepresentedObject:tcId];
			[[myMenu itemAtIndex:1] setRepresentedObject:tcId];
            if([tableView numberOfSelectedRows] == 1)
                theURL = [[shownPublications objectAtIndex:row] URLForField:tcId];
            if(nil != theURL){
                theItem = [myMenu insertItemWithTitle:NSLocalizedString(@"Open With", @"Open with") 
                                    andSubmenuOfApplicationsForURL:theURL atIndex:1];
            }
		}else if([[BibTypeManager sharedManager] isRemoteURLField:tcId]){
			myMenu = [[URLMenu copyWithZone:[NSMenu menuZone]] autorelease];
			[[myMenu itemAtIndex:0] setRepresentedObject:tcId];
            if([tableView numberOfSelectedRows] == 1)
                theURL = [[shownPublications objectAtIndex:row] URLForField:tcId];
            if(nil != theURL){
                theItem = [myMenu insertItemWithTitle:NSLocalizedString(@"Open With", @"Open with") 
                                    andSubmenuOfApplicationsForURL:theURL atIndex:1];
            }            
		}else{
			myMenu = [[actionMenu copyWithZone:[NSMenu menuZone]] autorelease];
		}
		
	}else if (tv == groupTableView){
		myMenu = [[groupMenu copyWithZone:[NSMenu menuZone]] autorelease];
	}else{
		return nil;
	}
	
	// kick out every item we won't need:
	int i = [myMenu numberOfItems];
    BOOL wasSeparator = YES;
	
	while (--i >= 0) {
		theItem = (NSMenuItem*)[myMenu itemAtIndex:i];
		if ([self validateMenuItem:theItem] == NO || ((wasSeparator || i == 0) && [theItem isSeparatorItem]))
			[myMenu removeItem:theItem];
        else
            wasSeparator = [theItem isSeparatorItem];
	}
	while([myMenu numberOfItems] > 0 && [(NSMenuItem*)[myMenu itemAtIndex:0] isSeparatorItem])	
		[myMenu removeItemAtIndex:0];
	
	if([myMenu numberOfItems] == 0)
		return nil;
	
	return myMenu;
}

- (NSMenu *)columnsMenu{
    return columnsMenu;
}

- (void)updateColumnsMenu{
    
    NSArray *shownColumns = [tableView tableColumnIdentifiers];
    NSEnumerator *shownColNamesE = [shownColumns reverseObjectEnumerator];
	NSString *colName;
	NSMenuItem *item = nil;
	
    while([[columnsMenu itemAtIndex:0] isSeparatorItem] == NO)
        [columnsMenu removeItemAtIndex:0];
    
	// next add all the shown columns in the order they are shown
	while(colName = [shownColNamesE nextObject]){
        item = [[[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:colName 
                                                                     action:@selector(columnsMenuSelectTableColumn:)
                                                              keyEquivalent:@""] autorelease];
		[item setState:NSOnState];
		[columnsMenu insertItem:item atIndex:0];
	}    
}

#pragma mark -
#pragma mark Notification handlers

- (void)handlePreviewDisplayChangedNotification:(NSNotification *)notification{
    // note: this is only supposed to handle the pretty-printed preview, /not/ the TeX preview
    [self displayPreviewForItems:[self selectedPublications]];
}

- (void)handleBibItemAddDelNotification:(NSNotification *)notification{
    // NB: this method gets called for setPublications: also, so checking for AddItemNotification might not do what you expect
	if([[notification name] isEqualToString:BDSKDocDelItemNotification] == NO)
		[self setFilterField:@""]; // clear the search when adding

    // this handles the remaining UI updates necessary (tableView and previews)
	[self updateGroupsPreservingSelection:YES];
    // update smart group counts
    [self updateAllSmartGroups];
}

- (void)handlePrivateBibItemChanged:(NSString *)changedKey{
    // we can be called from a queue after the document was closed
    if (isDocumentClosed)
        return;

	[self updateAllSmartGroups];
    
    if([[self currentGroupField] isEqualToString:changedKey]){
        // this handles all UI updates if we call it, so don't bother with any others
        [self updateGroupsPreservingSelection:YES];
    } else if(![[searchField stringValue] isEqualToString:@""] && 
       ([quickSearchKey isEqualToString:changedKey] || [quickSearchKey isEqualToString:BDSKAllFieldsString]) ){
        // don't perform a search if the search field is empty
		[self searchFieldAction:searchField];
	} else { 
        // groups and quicksearch won't update for us
        if([[lastSelectedColumnForSort identifier] isEqualToString:changedKey])
            [self sortPubsByColumn:nil]; // resort if the changed value was in the currently sorted column
        [self updateUI];
        [self updatePreviews:nil];
    }
}

- (void)handleBibItemChangedNotification:(NSNotification *)notification{

	NSDictionary *userInfo = [notification userInfo];
    
    // see if it's ours
	if([userInfo objectForKey:@"document"] != self || [userInfo objectForKey:@"document"] == nil)
        return;

	NSString *changedKey = [userInfo objectForKey:@"key"];
    
    // need to handle crossrefs if a cite key changed
    if([changedKey isEqualToString:BDSKCiteKeyString]){
        BibItem *pub = [notification object];
        NSString *oldKey = [userInfo objectForKey:@"oldCiteKey"];
        NSString *newKey = [pub citeKey];
        [itemsForCiteKeys removeObjectIdenticalTo:pub forKey:oldKey];
        [itemsForCiteKeys addObject:pub forKey:newKey];
		[self changeCrossrefKey:oldKey toKey:newKey];
    }

    [self invalidateGroupsForCrossreffedCiteKey:[[notification object] citeKey]];
    
    // queue for UI updating, in case the item is changed as part of a batch process such as Find & Replace or AutoFile
    [self queueSelectorOnce:@selector(handlePrivateBibItemChanged:) withObject:changedKey];
}

- (void)handleMacroChangedNotification:(NSNotification *)aNotification{
	BibDocument *changedDoc = [[aNotification object] document];
	if(changedDoc && changedDoc != self)
		return; // only macro changes for ourselves or the global macros
	
    [tableView reloadData];
    [self updatePreviews:nil];
}

- (void)handleTableSelectionChangedNotification:(NSNotification *)notification{
    [self updatePreviews:nil];
    [groupTableView updateHighlights];
}

- (void)handleIgnoredSortTermsChangedNotification:(NSNotification *)notification{
    [self sortPubsByColumn:nil];
}

- (void)handleNameDisplayChangedNotification:(NSNotification *)notification{
    [tableView reloadData];
    [self handlePreviewDisplayChangedNotification:notification];
}

- (void)handleFlagsChangedNotification:(NSNotification *)notification{
    unsigned int modifierFlags = [[notification object] modifierFlags];
    
    if (modifierFlags & NSAlternateKeyMask) {
        [groupAddButton setImage:[NSImage imageNamed:@"GroupAddSmart"]];
        [groupAddButton setAlternateImage:[NSImage imageNamed:@"GroupAddSmart_Pressed"]];
        [groupAddButton setToolTip:NSLocalizedString(@"Add new smart group.", @"")];
    } else {
        [groupAddButton setImage:[NSImage imageNamed:@"GroupAdd"]];
        [groupAddButton setAlternateImage:[NSImage imageNamed:@"GroupAdd_Pressed"]];
        [groupAddButton setToolTip:NSLocalizedString(@"Add new group.", @"")];
    }
}

- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification{
    [self saveSortOrder];
}

- (void)handleTypeInfoDidChangeNotification:(NSNotification *)notification{
    [publications makeObjectsPerformSelector:@selector(typeInfoDidChange:) withObject:notification];
}

- (void)handleCustomFieldsDidChangeNotification:(NSNotification *)notification{
    [publications makeObjectsPerformSelector:@selector(customFieldsDidChange:) withObject:notification];
}

#pragma mark UI updating

- (void)handlePrivateUpdatePreviews{
    // we can be called from a queue after the document was closed
    if (isDocumentClosed)
        return;

    OBASSERT([NSThread inMainThread]);
            
    NSArray *selPubs = [self selectedPublications];
    
    //take care of the preview field (NSTextView below the pub table); if the enumerator is nil, the view will get cleared out
    [self displayPreviewForItems:selPubs];

    if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKUsesTeXKey] &&
	   [[BDSKPreviewer sharedPreviewer] isWindowVisible]){

		if(!selPubs){
			// clear the previews
			[[BDSKPreviewer sharedPreviewer] updateWithBibTeXString:nil];
			return;
		}

        NSString *bibString = [self previewBibTeXStringForPublications:selPubs];
        [[BDSKPreviewer sharedPreviewer] updateWithBibTeXString:bibString];
    }
}

- (void)updatePreviews:(NSNotification *)aNotification{
    // Coalesce these notifications here, since something like select all -> generate cite keys will force a preview update for every
    // changed key, so we have to update all the previews each time.  This should be safer than using cancelPrevious... since those
    // don't get performed on the main thread (apparently), and can lead to problems.
    if (isDocumentClosed == NO)
        [self queueSelectorOnce:@selector(handlePrivateUpdatePreviews)];
}

- (void)displayPreviewForItems:(NSArray *)items{

    if(NSIsEmptyRect([previewField visibleRect]))
        return;
        
    static NSAttributedString *noAttrDoubleLineFeed;
    if(noAttrDoubleLineFeed == nil)
        noAttrDoubleLineFeed = [[NSAttributedString alloc] initWithString:@"\n\n" attributes:nil];
    
    int displayType = [[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKPreviewDisplayKey];
    
    NSDictionary *bodyAttributes = nil;
    NSDictionary *titleAttributes = nil;
    if (displayType == 1 || displayType == 2) {
        NSDictionary *cachedFonts = [[NSFontManager sharedFontManager] cachedFontsForPreviewPane];
        bodyAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[cachedFonts objectForKey:@"Body"], NSFontAttributeName, nil];
        titleAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[cachedFonts objectForKey:@"Body"], NSFontAttributeName, [NSNumber numberWithBool:YES], NSUnderlineStyleAttributeName, nil];
    }
    
    NSMutableAttributedString *s;
  
    int maxItems = [[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKPreviewMaxNumberKey];
    
    if (maxItems > 0 && [items count] > maxItems)
        items = [items subarrayWithRange:NSMakeRange(0, maxItems)];
    
    NSTextStorage *textStorage = [previewField textStorage];

    // do this _before_ messing with the text storage; otherwise you can have a leftover selection that ends up being out of range
    NSRange zeroRange = NSMakeRange(0, 0);
    static NSArray *zeroRanges = nil;
    if(!zeroRanges) zeroRanges = [[NSArray alloc] initWithObjects:[NSValue valueWithRange:zeroRange], nil];
    [previewField setSelectedRanges:zeroRanges];
            
    NSLayoutManager *layoutManager = [[textStorage layoutManagers] lastObject];
    [layoutManager retain];
    [textStorage removeLayoutManager:layoutManager]; // optimization: make sure the layout manager doesn't do any work while we're loading

    [textStorage beginEditing];
    [[textStorage mutableString] setString:@""];
    
    unsigned int numberOfSelectedPubs = [items count];
    NSEnumerator *enumerator = [items objectEnumerator];
    BibItem *pub = nil;
    NSString *fieldValue;
    BOOL isFirst = YES;
    static NSAttributedString *attributedFormFeed = nil;
    if (nil == attributedFormFeed)
        attributedFormFeed = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%C", NSFormFeedCharacter] attributes:nil];
    
    switch(displayType){
        case 0:
            while(pub = [enumerator nextObject]){
                if (isFirst == YES) isFirst = NO;
                else [textStorage appendAttributedString:attributedFormFeed]; // page break for printing; doesn't display
                [textStorage appendAttributedString:[pub attributedStringValue]];
                [textStorage appendAttributedString:noAttrDoubleLineFeed];
            }
            break;
        case 1:
            while(pub = [enumerator nextObject]){
                // Write out the title
                if(numberOfSelectedPubs > 1){
                    s = [[NSMutableAttributedString alloc] initWithString:[pub displayTitle]
                                                               attributes:titleAttributes];
                    [s appendAttributedString:noAttrDoubleLineFeed];
                    [textStorage appendAttributedString:s];
                    [s release];
                }
                fieldValue = [pub valueOfField:BDSKAnnoteString inherit:NO];
                if([fieldValue isEqualToString:@""])
                    fieldValue = NSLocalizedString(@"No notes.",@"");
                s = [[NSMutableAttributedString alloc] initWithString:fieldValue
                                                           attributes:bodyAttributes];
                [textStorage appendAttributedString:s];
                [s release];
                [textStorage appendAttributedString:noAttrDoubleLineFeed];
            }
            break;
        case 2:
            while(pub = [enumerator nextObject]){
                // Write out the title
                if(numberOfSelectedPubs > 1){
                    s = [[NSMutableAttributedString alloc] initWithString:[pub displayTitle]
                                                               attributes:titleAttributes];
                    [s appendAttributedString:noAttrDoubleLineFeed];
                    [textStorage appendAttributedString:s];
                    [s release];
                }
                fieldValue = [pub valueOfField:BDSKAbstractString inherit:NO];
                if([fieldValue isEqualToString:@""])
                    fieldValue = NSLocalizedString(@"No abstract.",@"");
                s = [[NSMutableAttributedString alloc] initWithString:fieldValue
                                                           attributes:bodyAttributes];
                [textStorage appendAttributedString:s];
                [s release];
                [textStorage appendAttributedString:noAttrDoubleLineFeed];
            }
            break;
        case 3:
            do{
                NSString *style = [[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:BDSKPreviewTemplateStyleKey];
                BDSKTemplate *template = [BDSKTemplate templateForStyle:style];
                if (template == nil)
                    template = [BDSKTemplate templateForStyle:[BDSKTemplate defaultStyleNameForFileType:@"rtf"]];
                NSAttributedString *templateString;
                
                // make sure this is really one of the attributed string types...
                if([template templateFormat] & BDSKRichTextTemplateFormat){
                    templateString = [BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:self publications:items documentAttributes:NULL];
                    [textStorage appendAttributedString:templateString];
                } else if([template templateFormat] & BDSKTextTemplateFormat){
                    // parse as plain text, so the HTML is interpreted properly by NSAttributedString
                    NSString *str = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:self publications:items];
                    // we generally assume UTF-8 encoding for all template-related files
                    templateString = [[NSAttributedString alloc] initWithHTML:[str dataUsingEncoding:NSUTF8StringEncoding] documentAttributes:NULL];
                    [textStorage appendAttributedString:templateString];
                    [templateString release];
                }
            }while(0);
            break;
    }
    
    [textStorage endEditing];
    [textStorage addLayoutManager:layoutManager];
    [layoutManager release];
    
    if([NSString isEmptyString:[searchField stringValue]] == NO)
        [previewField highlightComponentsOfSearchString:[searchField stringValue]];
    
}

- (void)updateUI{
	[tableView reloadData];
    
	int shownPubsCount = [shownPublications count];
	int groupPubsCount = [groupedPublications count];
	int totalPubsCount = [publications count];
    // show the singular form correctly
	NSMutableString *statusStr = [[NSMutableString alloc] init];
	NSString *ofStr = NSLocalizedString(@"of", @"of");

	if (shownPubsCount != groupPubsCount) { 
		[statusStr appendFormat:@"%i %@ ", shownPubsCount, ofStr];
	}
	[statusStr appendFormat:@"%i %@", groupPubsCount, (groupPubsCount == 1) ? NSLocalizedString(@"publication", @"publication") : NSLocalizedString(@"publications", @"publications")];
	if ([self hasSharedGroupsSelected] == YES) {
        // we can only one shared group selected at a time
        [statusStr appendFormat:@" %@ \"%@\"", NSLocalizedString(@"in shared group", @"in shared group"), [[[self selectedGroups] lastObject] stringValue]];
	} else if ([self hasURLGroupsSelected] == YES) {
        // we can only one URL group selected at a time
        [statusStr appendFormat:@" %@ \"%@\"", NSLocalizedString(@"in external file group", @"in URL group"), [[[self selectedGroups] lastObject] stringValue]];
	} else if ([self hasScriptGroupsSelected] == YES) {
        // we can only one URL group selected at a time
        [statusStr appendFormat:@" %@ \"%@\"", NSLocalizedString(@"in script group", @"in URL group"), [[[self selectedGroups] lastObject] stringValue]];
	} else if (groupPubsCount != totalPubsCount) {
		NSString *groupStr = ([groupTableView numberOfSelectedRows] == 1) ?
			[NSString stringWithFormat:@"%@ \"%@\"", NSLocalizedString(@"group", @"group"), [[[self selectedGroups] lastObject] stringValue]] :
			NSLocalizedString(@"multiple groups", @"multiple groups");
        [statusStr appendFormat:@" %@ %@ (%@ %i)", NSLocalizedString(@"in", @"in"), groupStr, ofStr, totalPubsCount];
	}
	[self setStatus:statusStr];
    [statusStr release];
}

#pragma mark -
#pragma mark Selection

- (int)numberOfSelectedPubs{
    return [tableView numberOfSelectedRows];
}

- (NSArray *)selectedPublications{

    if(nil == tableView || [tableView selectedRow] == -1)
        return nil;
    
    return [shownPublications objectsAtIndexes:[tableView selectedRowIndexes]];
}

- (BOOL)highlightItemForPartialItem:(NSDictionary *)partialItem{
    
    // make sure we can see the publication, if it's still here
    [self selectGroup:allPublicationsGroup];
    [tableView deselectAll:self];
    [self setFilterField:@""];
    
    NSString *itemKey = [partialItem objectForKey:@"net_sourceforge_bibdesk_citekey"];
    if(itemKey == nil)
        itemKey = [partialItem objectForKey:BDSKCiteKeyString];
    
    OBPOSTCONDITION(itemKey != nil);
    
    NSEnumerator *pubEnum = [shownPublications objectEnumerator];
    BibItem *anItem;
    BOOL matchFound = NO;
    
    while(anItem = [pubEnum nextObject]){
        if([[anItem citeKey] isEqualToString:itemKey]){
            [self highlightBib:anItem];
            matchFound = YES;
        }
    }
    return matchFound;
}

- (void)highlightBib:(BibItem *)bib{
	[self highlightBibs:[NSArray arrayWithObject:bib]];
}

- (void)highlightBibs:(NSArray *)bibArray{
    
	NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
	NSEnumerator *pubEnum = [bibArray objectEnumerator];
	BibItem *bib;
	int i;
	
	while(bib = [pubEnum nextObject]){
		i = [shownPublications indexOfObjectIdenticalTo:bib];    
		if(i != NSNotFound)
			[indexes addIndex:i];
	}
    
    if([indexes count]){
        [tableView selectRowIndexes:indexes byExtendingSelection:NO];
        [tableView scrollRowToCenter:[indexes firstIndex]];
    }
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

#pragma mark -
#pragma mark TeXTask delegate

- (BOOL)texTaskShouldStartRunning:(BDSKTeXTask *)aTexTask{
	[self setStatus:[NSString stringWithFormat:@"%@%C",NSLocalizedString(@"Generating data. Please wait", @"Generating data. Please wait..."), 0x2026]];
	[statusBar startAnimation:nil];
	return YES;
}

- (void)texTask:(BDSKTeXTask *)aTexTask finishedWithResult:(BOOL)success{
	[statusBar stopAnimation:nil];
	[self updateUI];
}

#pragma mark -
#pragma mark Printing support

- (NSView *)printableView{
    BDSKPrintableView *printableView = [[BDSKPrintableView alloc] initForScreenDisplay:NO];
    [printableView setAttributedString:[previewField textStorage]];    
    return [printableView autorelease];
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
    NSPrintInfo *info = [self printInfo];
    [[info dictionary] addEntriesFromDictionary:printSettings];
    return [NSPrintOperation printOperationWithView:[self printableView] printInfo:info];
}

- (void)printShowingPrintPanel:(BOOL)showPanels {
    // Obtain a custom view that will be printed
    NSView *printView = [self printableView];
	
    // Construct the print operation and setup Print panel
    NSPrintOperation *op = [NSPrintOperation printOperationWithView:printView
                                                          printInfo:[self printInfo]];
    [op setShowPanels:showPanels];
    [op setCanSpawnSeparateThread:YES];
    if (showPanels) {
        // Add accessory view, if needed
    }
	
    // Run operation, which shows the Print panel if showPanels was YES
    [op runOperationModalForWindow:[self windowForSheet] delegate:nil didRunSelector:NULL contextInfo:NULL];
}

#pragma mark -
#pragma mark Protocols forwarding

// Declaring protocol conformance in the category headers shuts the compiler up, but causes a hang in -[NSObject conformsToProtocol:], which sucks.  Therefore, we use wrapper methods here to call the real (category) implementations.
- (void)restoreDocumentStateByRemovingSearchView:(NSView *)view{ 
    [self _restoreDocumentStateByRemovingSearchView:view]; 
}

- (NSIndexSet *)indexesOfRowsToHighlightInRange:(NSRange)indexRange tableView:(BDSKGroupTableView *)tview{
    return [self _indexesOfRowsToHighlightInRange:indexRange tableView:tview];
}

- (NSIndexSet *)tableViewSingleSelectionIndexes:(BDSKGroupTableView *)tview{
    return [self _tableViewSingleSelectionIndexes:tview];
}

#pragma mark DisplayName KVO

- (void)setFileURL:(NSURL *)absoluteURL{ 
    // make sure that changes in the displayName are observed, as NSDocument doesn't use a KVC compliant method for setting it
    [self willChangeValueForKey:@"displayName"];
    [super setFileURL:absoluteURL];
    [self didChangeValueForKey:@"displayName"];
}

// just create this setter to avoid a run time warning
- (void)setDisplayName:(NSString *)newName{}

@end

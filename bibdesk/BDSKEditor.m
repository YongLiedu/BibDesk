//  BDSKEditor.m

//  Created by Michael McCracken on Mon Dec 24 2001.
/*
 This software is Copyright (c) 2001-2016
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


#import "BDSKEditor.h"
#import "BDSKOwnerProtocol.h"
#import "BibDocument.h"
#import "BibDocument_Actions.h"
#import "BibDocument_DataSource.h"
#import "BDSKAlias.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKComplexString.h"
#import "BDSKScriptHookManager.h"
#import "BDSKEdgeView.h"
#import "NSString_BDSKExtensions.h"
#import "BDSKFieldSheetController.h"
#import "BDSKFiler.h"
#import "BibItem.h"
#import "BDSKCiteKeyFormatter.h"
#import "BDSKAppController.h"
#import "BDSKRatingButton.h"
#import "BDSKComplexStringEditor.h"
#import "BDSKStatusBar.h"
#import "BibAuthor.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKFieldEditor.h"
#import "NSURL_BDSKExtensions.h"
#import "BDSKPreviewer.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKPersistentSearch.h"
#import "BDSKMacroResolver.h"
#import "NSMenu_BDSKExtensions.h"
#import "BDSKBibTeXParser.h"
#import "BDSKStringParser.h"
#import "NSArray_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKNotesWindowController.h"
#import "BDSKLinkedFile.h"
#import "BDSKEditorTableView.h"
#import "BDSKEditorTextFieldCell.h"
#import "BDSKCompletionManager.h"
#import "NSEvent_BDSKExtensions.h"
#import "NSColor_BDSKExtensions.h"
#import "BDSKURLSheetController.h"
#import "NSEvent_BDSKExtensions.h"
#import "BDSKColoredView.h"
#import "BDSKSplitView.h"
#import "BDSKTemplate.h"
#import "BDSKGroupsArray.h"
#import "NSTableView_BDSKExtensions.h"
#import "NSInvocation_BDSKExtensions.h"
#import "NSTextView_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import "NSPasteboard_BDSKExtensions.h"

#define WEAK_NULL NULL

#define BDSKEditorFrameAutosaveName @"BDSKEditor window autosave name"
#define BDSKEditorMainSplitViewAutosaveName @"BDSKEditorMainSplitView"
#define BDSKEditorFileSplitViewAutosaveName @"BDSKEditorFileSplitView"

static char BDSKEditorObservationContext;

// offset of the table from the left window edge
#define TABLE_OFFSET 13.0

// this was copied verbatim from a Finder saved search for all items of kind document modified in the last week
static NSString * const recentDownloadsQuery = @"(kMDItemContentTypeTree = 'public.content') && (kMDItemFSContentChangeDate >= $time.today(-7)) && (kMDItemContentType != com.apple.mail.emlx) && (kMDItemContentType != public.vcard)";

enum { BDSKMoveToTrashAsk = -1, BDSKMoveToTrashNo = 0, BDSKMoveToTrashYes = 1 };

@interface BDSKEditor (Private)

- (void)setupButtonCells;
- (void)setupMatrix;
- (void)matrixFrameDidChange:(NSNotification *)notification;
- (void)setupTypePopUp;
- (NSArray *)currentFields;
- (void)resetFields;
- (void)resetFieldsIfNeeded;
- (void)reloadTable;
- (void)reloadTableWithFields:(NSArray *)newFields;
- (void)registerForNotifications;
- (void)breakTextStorageConnections;
- (void)updateCiteKeyDuplicateWarning;

@end

@implementation BDSKEditor

+ (void)initialize
{
    BDSKINITIALIZE;
    
    // limit the scope to the default downloads directory (from Internet Config)        
    NSURL *downloadURL = [[NSFileManager defaultManager] downloadFolderURL];
    if(downloadURL){
        [[BDSKPersistentSearch sharedSearch] addQuery:recentDownloadsQuery scopes:[NSArray arrayWithObject:downloadURL]];
    }
}

- (NSString *)windowNibName{
    return @"BDSKEditor";
}

- (id)initWithPublication:(BibItem *)aBib{
    self = [super initWithWindowNibName:@"BDSKEditor"];
    if (self) {
        
        publication = [aBib retain];
        fields = [[NSMutableArray alloc] init];
        editorFlags.isEditable = [[publication owner] isDocument];
                
        editorFlags.didSetupFields = NO;
    }
    return self;
}

// implement NSCoding because we might be encoded as the delegate of some menus
// mainly for the toolbar popups in a customization palette 
- (id)initWithCoder:(NSCoder *)decoder{
    [[self init] release];
    self = nil;
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)coder{}

- (void)windowDidLoad{
	
    // we should have a document at this point, as the nib is not loaded before -window is called, which shouldn't happen before the document shows us
    BDSKASSERT([self document]);
    
    [[self window] setAutorecalculatesContentBorderThickness:NO forEdge:NSMinYEdge];
    [[self window] setContentBorderThickness:NSHeight([statusBar frame]) forEdge:NSMinYEdge];
    
    BDSKEditorTextFieldCell *dataCell = [[tableView tableColumnWithIdentifier:@"value"] dataCell];
    [dataCell setButtonAction:@selector(tableButtonAction:)];
    [dataCell setButtonTarget:self];
    [dataCell setEditable:editorFlags.isEditable];
    [dataCell setSelectable:YES]; // the previous call may reset this
    
    if (editorFlags.isEditable)
        [tableView setDoubleAction:@selector(raiseChangeFieldName:)];
    
    [tableView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
    [tableView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    
    [bibTypeButton setEnabled:editorFlags.isEditable];
    [addFieldButton setEnabled:editorFlags.isEditable];
    
    [self setupButtonCells];
    
    // Setup the statusbar
    [statusBar retain];
	[statusBar setDelegate:self];
    [statusBar setLeftMargin:NSMaxX([actionButton frame]) + 5.0];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKShowEditorStatusBarKey] == NO)
        [self toggleStatusBar:nil];
    
    // Insert the tabView in the main window
    NSView *view = [[mainSplitView subviews] objectAtIndex:0];
    [[tabView superview] setFrame:[view frame]];
    [view addSubview:tabView];
    [(BDSKColoredView *)[mainSplitView superview] setBackgroundColor:[NSColor windowBackgroundColor]];
    
    BDSKEdgeView *edgeView = (BDSKEdgeView *)[[[matrix enclosingScrollView] superview] superview];
	[edgeView setEdges:BDSKMaxYEdgeMask];
	[edgeView setColor:[edgeView colorForEdge:NSMinYEdge] forEdge:NSMaxYEdge];
    
    [self setWindowFrameAutosaveNameOrCascade:BDSKEditorFrameAutosaveName];
    
    // Setup the splitview autosave frames, should be done after the statusBar and splitViews are setup
    [mainSplitView setAutosaveName:BDSKEditorMainSplitViewAutosaveName];
    [fileSplitView setAutosaveName:BDSKEditorFileSplitViewAutosaveName];
    if ([self windowFrameAutosaveName] == nil) {
        // Only autosave the frames when the window's autosavename is set to avoid inconsistencies
        [mainSplitView setAutosaveName:nil];
        [fileSplitView setAutosaveName:nil];
    }
    
    tableCellFormatter = [[BDSKComplexStringFormatter alloc] initWithDelegate:self macroResolver:[publication macroResolver]];
    crossrefFormatter = [[BDSKCiteKeyFormatter alloc] init];
    [crossrefFormatter setAllowsEmptyString:YES];
    citationFormatter = [[BDSKCitationFormatter alloc] initWithDelegate:self];
    
    [self resetFields];
    [self setupMatrix];
    if (editorFlags.isEditable)
        [tableView registerForDraggedTypes:[NSArray arrayWithObjects:BDSKPasteboardTypePublications, NSPasteboardTypeString, (NSString *)kUTTypeURL, (NSString *)kUTTypeFileURL, NSURLPboardType, NSFilenamesPboardType, nil]];
    
    // Setup the citekey textfield
    BDSKCiteKeyFormatter *citeKeyFormatter = [[BDSKCiteKeyFormatter alloc] init];
    [citeKeyField setFormatter:citeKeyFormatter];
    [citeKeyFormatter release];
	[citeKeyField setStringValue:[publication citeKey]];
    [citeKeyField setEditable:editorFlags.isEditable];
	
    // Setup the type popup
    [self setupTypePopUp];
    
    [authorTableView setDoubleAction:@selector(showPersonDetail:)];
    
    // Setup the textviews
    NSString *currentValue = [publication valueOfField:BDSKAnnoteString inherit:NO];
    if (currentValue)
        [notesView setString:currentValue];
    [notesView setEditable:editorFlags.isEditable];
    currentValue = [publication valueOfField:BDSKAbstractString inherit:NO];
    if (currentValue)
        [abstractView setString:currentValue];
    [abstractView setEditable:editorFlags.isEditable];
    currentValue = [publication valueOfField:BDSKRssDescriptionString inherit:NO];
    if (currentValue)
        [rssDescriptionView setString:currentValue];
    [rssDescriptionView setEditable:editorFlags.isEditable];
	currentEditedView = nil;
    
    // Set up identifiers for the tab view items, since we receive delegate messages from it
    NSArray *tabViewItems = [tabView tabViewItems];
    [[tabViewItems objectAtIndex:0] setIdentifier:BDSKBibtexString];
    [[tabViewItems objectAtIndex:1] setIdentifier:BDSKAnnoteString];
    [[tabViewItems objectAtIndex:2] setIdentifier:BDSKAbstractString];
    [[tabViewItems objectAtIndex:3] setIdentifier:BDSKRssDescriptionString];
	
	// Update the statusbar message and icons
    [self needsToBeFiledDidChange:nil];
	[self updateCiteKeyAutoGenerateStatus];
    
    [self registerForNotifications];
    
    [[self window] setDelegate:self];
    if (editorFlags.isEditable)
        [[self window] registerForDraggedTypes:[NSArray arrayWithObjects:BDSKPasteboardTypePublications, NSPasteboardTypeString, nil]];					
	
    [self updateCiteKeyDuplicateWarning];
    
    if ([fileView backgroundColor])
        [[fileView enclosingScrollView] setBackgroundColor:[fileView backgroundColor]];
    [fileView setDisplayMode:[[NSUserDefaults standardUserDefaults] integerForKey:BDSKEditorFileViewDisplayModeKey]];
    [fileView setIconScale:[[NSUserDefaults standardUserDefaults] doubleForKey:BDSKEditorFileViewIconScaleKey]];
    [fileView addObserver:self forKeyPath:@"iconScale" options:0 context:&BDSKEditorObservationContext];
    [fileView addObserver:self forKeyPath:@"displayMode" options:0 context:&BDSKEditorObservationContext];
    [fileView setEditable:editorFlags.isEditable];
    [fileView setAllowsDownloading:editorFlags.isEditable];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName{
    return [publication displayTitle];
}

- (void)synchronizeWindowTitleWithDocumentName {
    [super synchronizeWindowTitleWithDocumentName];
    // replace the proxy icon with the first linked file, somehow passing nil does not work
    [[self window] setRepresentedFilename:[[[publication localFiles] firstObject] path] ?: @""];
}

- (BibItem *)publication{
    return publication;
}

- (void)dealloc{
    BDSKDESTROY(publication);
    BDSKDESTROY(fields);
    BDSKDESTROY(addedFields);
    BDSKDESTROY(statusBar);
    BDSKDESTROY(previousValueForCurrentEditedView);
    BDSKDESTROY(notesViewUndoManager);
    BDSKDESTROY(abstractViewUndoManager);
    BDSKDESTROY(rssDescriptionViewUndoManager);   
    BDSKDESTROY(booleanButtonCell);
    BDSKDESTROY(triStateButtonCell);
    BDSKDESTROY(ratingButtonCell);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	BDSKDESTROY(dragFieldEditor);
	BDSKDESTROY(complexStringEditor);
    BDSKDESTROY(tableCellFormatter);
    BDSKDESTROY(crossrefFormatter);
    BDSKDESTROY(citationFormatter);
    BDSKDESTROY(disableAutoFileButton);
    [super dealloc];
}

static inline BOOL validRanges(NSArray *ranges, NSUInteger max) {
    for (NSValue *range in ranges) {
        if (NSMaxRange([range rangeValue]) > max)
            return NO;
    }
    return YES;
}

- (BOOL)validateCurrentEditedView
{
    NSParameterAssert(currentEditedView);
    BOOL rv = ([[currentEditedView string] isStringTeXQuotingBalancedWithBraces:YES connected:NO]);
    if (NO == rv) {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText:NSLocalizedString(@"Invalid Value", @"Message in alert dialog when entering an invalid value")];
        [alert setInformativeText:NSLocalizedString(@"The value you entered contains unbalanced braces and cannot be saved.", @"Informative text in alert dialog")];
        
        [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];   
    }
    return rv;
}

- (void)discardEditing
{
    id firstResponder = [[self window] firstResponder];
    // check textviews first
    if (currentEditedView == firstResponder) {
        // need some reasonable state for annote et al. textviews
        NSParameterAssert(nil != previousValueForCurrentEditedView);
        [currentEditedView setString:previousValueForCurrentEditedView];
    }
    // now handle any field editor(s)
    else if ([firstResponder isKindOfClass:[NSText class]]) {
     
        /*
         Omit the standard check for [[self window] fieldEditor:NO forObject:nil],
         since that returns nil for the tableview's field editor.
         */
        
        NSControl *control = (NSControl *)[(NSText *)firstResponder delegate];
        
        // may be self, if a textview was being edited (but we should have taken the first branch in that case)
        if ([control respondsToSelector:@selector(abortEditing)]) {
            [control abortEditing];
        }
        else {
            fprintf(stderr, "%s, control does not respond to abortEditing\n", __func__);
        }
    }
    if (editorFlags.isEditing) {
        [[self document] objectDidEndEditing:self];
        editorFlags.isEditing = NO;
    }
}

- (void)commitEditingWithDelegate:(id)delegate didCommitSelector:(SEL)didCommitSelector contextInfo:(void *)contextInfo
{
    BOOL didCommit = [self commitEditing];
    if (delegate && didCommitSelector) {
        // - (void)editor:(id)editor didCommit:(BOOL)didCommit contextInfo:(void *)contextInfo
        NSInvocation *invocation = [NSInvocation invocationWithTarget:delegate selector:didCommitSelector];
        [invocation setArgument:&self atIndex:2];
        [invocation setArgument:&didCommit atIndex:3];
        [invocation setArgument:&contextInfo atIndex:4];
        [invocation invoke];
    }
}

- (BOOL)commitEditing
{
    NSResponder *firstResponder = [[self window] firstResponder];
    
	/*
     Need to finalize text field cells being edited or the abstract/annote text views, since the 
     text views bypass the normal undo mechanism for speed, and won't cause the doc to be marked 
     dirty on subsequent edits.
     */
	if([firstResponder isKindOfClass:[NSText class]]){
        
        NSTextView *textView = (NSTextView *)firstResponder;
		NSInteger editedRow = -1;
		NSArray *selection = [textView selectedRanges];
        if ([textView isFieldEditor]) {
            firstResponder = (NSResponder *)[textView delegate];
            if (firstResponder == tableView)
                editedRow = [tableView editedRow];
        }
        
		editorFlags.didSetupFields = NO; // if we we rebuild the fields, the selection will become meaningless
        
        // check textviews for balanced braces as needed
        if (currentEditedView && [self validateCurrentEditedView] == NO)
            return NO;
        
        // commit edits (formatters may refuse to allow this)
        if ([[self window] makeFirstResponder:[self window]] == NO)
            return NO;
        
        // for inherited fields, we should do something here to make sure the user doesn't have to go through the warning sheet
		
		if ([[self window] makeFirstResponder:firstResponder] && editorFlags.didSetupFields == NO) {
            if (firstResponder == tableView && editedRow != -1)
                [tableView editColumn:1 row:editedRow withEvent:nil select:NO];
            [textView setSafeSelectedRanges:selection];
        }
        
    }
    return YES;
}

#pragma mark Actions

- (IBAction)copy:(id)sender {
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    NSString *copyTypeKey = ([NSEvent standardModifierFlags] & NSAlternateKeyMask) ? BDSKAlternateDragCopyTypeKey : BDSKDefaultDragCopyTypeKey;
	NSInteger copyType = [sud integerForKey:copyTypeKey];
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    NSArray *pubs = [NSArray arrayWithObject:publication];
    
    if (copyType == BDSKTemplateDragCopyType) {
        NSString *dragCopyTemplateKey = ([NSEvent standardModifierFlags] & NSAlternateKeyMask) ? BDSKAlternateDragCopyTemplateKey : BDSKDefaultDragCopyTemplateKey;
        NSString *template = [sud stringForKey:dragCopyTemplateKey];
        NSUInteger templateIdx = [[BDSKTemplate allStyleNames] indexOfObject:template];
        if (templateIdx != NSNotFound)
            copyType += templateIdx;
    }
    
    [[self document] writePublications:pubs forDragCopyType:copyType toPasteboard:pboard];
}

- (IBAction)copyAsAction:(id)sender {
	NSInteger copyType = [sender tag];
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    NSArray *pubs = [NSArray arrayWithObject:publication];
	[[self document] writePublications:pubs forDragCopyType:copyType toPasteboard:pboard];
}

- (IBAction)openLinkedFile:(id)sender{
    NSArray *urls;
	NSURL *fileURL = [sender representedObject];
    
    if (fileURL)
        urls = [NSArray arrayWithObject:fileURL];
    else
        urls = [publication valueForKeyPath:@"localFiles.URL"];
    
    for (fileURL in urls) {
        if ([fileURL isEqual:[NSNull null]] == NO) {
            [[NSWorkspace sharedWorkspace] openLinkedURL:fileURL];
        }
    }
}

- (IBAction)revealLinkedFile:(id)sender{
    NSArray *urls;
	NSURL *fileURL = [sender representedObject];
    
    if (fileURL)
        urls = [NSArray arrayWithObject:fileURL];
    else
        urls = [publication valueForKeyPath:@"localFiles.URL"];
    
    for (fileURL in urls) {
        if ([fileURL isEqual:[NSNull null]] == NO) {
            [[NSWorkspace sharedWorkspace]  selectFile:[fileURL path] inFileViewerRootedAtPath:@""];
        }
    }
}

- (IBAction)openLinkedURL:(id)sender{
    NSArray *urls;
	NSURL *remoteURL = [sender representedObject];
    
    if (remoteURL)
        urls = [NSArray arrayWithObject:remoteURL];
    else
        urls = [publication valueForKeyPath:@"remoteURLs.URL"];
    
    for (remoteURL in urls) {
        if ([remoteURL isEqual:[NSNull null]] == NO) {
			[[NSWorkspace sharedWorkspace] openLinkedURL:remoteURL];
        }
    }
}

- (IBAction)showNotesForLinkedFile:(id)sender{
    NSArray *urls;
	NSURL *fileURL = [sender representedObject];
    
    if (fileURL)
        urls = [NSArray arrayWithObject:fileURL];
    else
        urls = [publication valueForKeyPath:@"localFiles.URL"];
    
    for (fileURL in urls) {
        if ([fileURL isEqual:[NSNull null]] == NO) {
            BDSKNotesWindowController *notesController = [[[BDSKNotesWindowController alloc] initWithURL:fileURL] autorelease];
        
            [[self document] addWindowController:notesController];
            [notesController showWindow:self];
        }
    }
}

- (IBAction)copyNotesForLinkedFile:(id)sender{
    NSArray *urls;
	NSURL *fileURL = [sender representedObject];
    NSMutableString *string = [NSMutableString string];
    
    if (fileURL)
        urls = [NSArray arrayWithObject:fileURL];
    else
        urls = [publication valueForKeyPath:@"localFiles.URL"];
    
    for (fileURL in urls) {
        if ([fileURL isEqual:[NSNull null]] == NO) {
            NSString *notes = [fileURL textSkimNotes];
            
            if ([notes length]) {
                if ([string length])
                    [string appendString:@"\n\n"];
                [string appendString:notes];
            }
            
        }
    }
    if ([string length]) {
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        [pboard clearContents];
        [pboard writeObjects:[NSArray arrayWithObjects:string, nil]];
    }
}

- (IBAction)previewAction:(id)sender {
    if (editorFlags.controllingFVPreviewPanel || editorFlags.controllingQLPreviewPanel) {
        [self stopPreviewing];
    } else {
        NSArray *theURLs = [publication valueForKeyPath:@"localFiles.URL"];
        if ([theURLs count] == 0)
            theURLs = [publication valueForKeyPath:@"remoteURLs.URL"];
        [self previewURLs:theURLs];
    }
}

- (IBAction)showCiteKeyWarning:(id)sender{
    if ([publication hasEmptyOrDefaultCiteKey]) {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText:NSLocalizedString(@"Cite Key Not Set", @"Message in alert dialog when duplicate citye key was found")];
        [alert setInformativeText:NSLocalizedString(@"The cite key has not been set. Please provide one.", @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:NULL];
    } else if ([publication isValidCiteKey:[publication citeKey]] == NO) {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText:NSLocalizedString(@"Duplicate Cite Key", @"Message in alert dialog when duplicate citye key was found")];
         [alert setInformativeText:NSLocalizedString(@"The cite key you entered is either already used in this document. Please provide a unique one.", @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:nil
                         didEndSelector:NULL
                            contextInfo:NULL];
    }
}

- (IBAction)chooseLocalFile:(id)sender{
    NSUInteger anIndex = NSNotFound;
    NSNumber *indexNumber = [sender representedObject];
    NSURL *url = nil;
    if (indexNumber) {
        anIndex = [indexNumber unsignedIntegerValue];
        url = [[publication objectInFilesAtIndex:anIndex] URL];
    }
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:NO];
    [oPanel setResolvesAliases:NO];
    [oPanel setCanChooseDirectories:YES];
    [oPanel setPrompt:NSLocalizedString(@"Choose", @"Prompt for Choose panel")];
    if (url) {
        [oPanel setDirectoryURL:[url URLByDeletingLastPathComponent]];
        [oPanel setNameFieldStringValue:[url lastPathComponent]];
    }
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKFilePapersAutomaticallyKey]) {
        if (disableAutoFileButton == nil) {
            disableAutoFileButton = [[NSButton alloc] init];
            [disableAutoFileButton setBezelStyle:NSRoundedBezelStyle];
            [disableAutoFileButton setButtonType:NSSwitchButton];
            [disableAutoFileButton setTitle:NSLocalizedString(@"Disable Auto File", @"Choose local file button title")];
            [disableAutoFileButton sizeToFit];
        }
        [disableAutoFileButton setState:NSOffState];
        [oPanel setAccessoryView:disableAutoFileButton];
	}
    
    [oPanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
        if(result == NSFileHandlingPanelOKButton){
            NSURL *aURL = [[oPanel URLs] objectAtIndex:0];
            BOOL shouldAutoFile = [disableAutoFileButton state] == NSOffState && [[NSUserDefaults standardUserDefaults] boolForKey:BDSKFilePapersAutomaticallyKey];
            if (anIndex != NSNotFound) {
                BDSKLinkedFile *aFile = [BDSKLinkedFile linkedFileWithURL:aURL delegate:publication];
                if (aFile == nil)
                    return;
                NSURL *oldURL = [[[publication objectInFilesAtIndex:anIndex] URL] retain];
                [publication removeObjectFromFilesAtIndex:anIndex];
                [publication insertObject:aFile inFilesAtIndex:anIndex];
                [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
                if (oldURL)
                    [[self document] userRemovedURL:oldURL forPublication:publication];
                [oldURL release];
                [[self document] userAddedURL:aURL forPublication:publication];
                if (shouldAutoFile)
                    [publication autoFileLinkedFile:aFile];
            } else {
                [publication addFileForURL:aURL autoFile:shouldAutoFile runScriptHook:YES];
                [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
            }
        }        
    }];
}

- (void)addLinkedFileFromMenuItem:(NSMenuItem *)sender{
	NSURL *aURL = [sender representedObject];
    [publication addFileForURL:aURL autoFile:YES runScriptHook:YES];
    [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
}

- (IBAction)chooseRemoteURL:(id)sender{
    NSUInteger anIndex = NSNotFound;
    NSNumber *indexNumber = [sender representedObject];
    NSString *urlString = @"http://";
    if (indexNumber) {
        anIndex = [indexNumber unsignedIntegerValue];
        urlString = [[[publication objectInFilesAtIndex:anIndex] URL] absoluteString];
    }
    
    BDSKURLSheetController *urlController = [[[BDSKURLSheetController alloc] init] autorelease];
    
    [urlController setUrlString:urlString];
    [urlController beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
        if (result == NSOKButton) {
            // remove the sheet in case we get an alert
            [[urlController window] orderOut:nil];
            
            NSURL *aURL = [urlController URL];
            if (aURL == nil)
                return;
            if (anIndex != NSNotFound) {
                BDSKLinkedFile *aFile = [BDSKLinkedFile linkedFileWithURL:aURL delegate:publication];
                if (aFile == nil)
                    return;
                NSURL *oldURL = [[[publication objectInFilesAtIndex:anIndex] URL] retain];
                [publication removeObjectFromFilesAtIndex:anIndex];
                [publication insertObject:aFile inFilesAtIndex:anIndex];
                if (oldURL)
                    [[self document] userRemovedURL:oldURL forPublication:publication];
                [oldURL release];
                [[self document] userAddedURL:aURL forPublication:publication];
                [publication autoFileLinkedFile:aFile];
            } else {
                [publication addFileForURL:aURL autoFile:NO runScriptHook:YES];
                [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
            }
        }
    }];
}

- (void)addRemoteURLFromMenuItem:(NSMenuItem *)sender{
    NSURL *aURL = [sender representedObject];
    [publication addFileForURL:aURL autoFile:YES runScriptHook:YES];
    [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
}

- (IBAction)trashLinkedFiles:(id)sender{
    [self deleteURLsAtIndexes:[sender representedObject] moveToTrash:BDSKMoveToTrashYes];
}

// raises the add field sheet
- (IBAction)raiseAddField:(id)sender{
    BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
    NSArray *fieldNames;
    NSMutableArray *currentFields = [fields mutableCopy];
    
    [currentFields addObjectsFromArray:[[typeMan ratingFieldsSet] allObjects]];
    [currentFields addObjectsFromArray:[[typeMan booleanFieldsSet] allObjects]];
    [currentFields addObjectsFromArray:[[typeMan triStateFieldsSet] allObjects]];
    [currentFields addObjectsFromArray:[[typeMan noteFieldsSet] allObjects]];
    
    fieldNames = [typeMan allFieldNamesIncluding:[NSArray arrayWithObject:BDSKCrossrefString] excluding:currentFields];
    
    if ([self commitEditing]) {
        BDSKFieldSheetController *addFieldController = [BDSKFieldSheetController fieldSheetControllerWithChoosableFields:fieldNames
                                                                                 label:NSLocalizedString(@"Name of field to add:", @"Label for adding field")];
        [addFieldController beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
            NSString *newField = [addFieldController chosenField];
            if(result == NSCancelButton || newField == nil)
                return;
            
            // remove the sheet in case we get an alert
            [[addFieldController window] orderOut:nil];
            
            newField = [newField fieldName];
            if([currentFields containsObject:newField] == NO){
                if (addedFields == nil)
                    addedFields = [[NSMutableSet alloc] init];
                [addedFields addObject:newField];
                [tabView selectFirstTabViewItem:nil];
                [self resetFields];
                [self setKeyField:newField];
            }
        }];
    }
}

- (IBAction)raiseDelField:(id)sender{
    // populate the popupbutton
    NSString *currentType = [publication pubType];
	BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
	NSMutableArray *removableFields = [fields mutableCopy];
	[removableFields removeObjectsInArray:[typeMan requiredFieldsForType:currentType]];
	[removableFields removeObjectsInArray:[typeMan optionalFieldsForType:currentType]];
	[removableFields removeObjectsInArray:[typeMan userDefaultFieldsForType:currentType]];
    
    NSString *prompt = NSLocalizedString(@"Name of field to remove:", @"Label for removing field");
	if ([removableFields count]) {
		[removableFields sortUsingSelector:@selector(caseInsensitiveCompare:)];
	} else {
		prompt = NSLocalizedString(@"No fields to remove", @"Label when no field to remove");
	}
    
    BDSKFieldSheetController *removeFieldController = [BDSKFieldSheetController fieldSheetControllerWithSelectableFields:removableFields
                                                                                label:prompt];
    NSInteger selectedRow = [tableView clickedOrSelectedRow];
    NSString *selectedField = selectedRow == -1 ? nil : [fields objectAtIndex:selectedRow];
    BOOL didValidate = YES;
    if([removableFields containsObject:selectedField]){
        [removeFieldController setSelectedField:selectedField];
        // if we don't deselect this cell, we can't remove it from the form
        didValidate = [self commitEditing];
    }
	
    if (didValidate) {
        [removeFieldController beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
            NSString *oldField = [removeFieldController selectedField];
            NSString *oldValue = [[[publication valueOfField:oldField inherit:NO] retain] autorelease];
            
            if (result == NSOKButton && oldField != nil && [removableFields count]) {
                // remove the sheet in case we get an alert
                [[removeFieldController window] orderOut:nil];
                
                [addedFields removeObject:oldField];
                [tabView selectFirstTabViewItem:nil];
                if ([NSString isEmptyString:oldValue]) {
                    [self resetFields];
                } else {
                    [publication setField:oldField toValue:nil];
                    [[self undoManager] setActionName:NSLocalizedString(@"Remove Field", @"Undo action name")];
                    [self userChangedField:oldField from:oldValue to:@""];
                }
            }
        }];
    }
    
	[removableFields release];
}

- (void)raiseChangeFieldSheetForField:(NSString *)field{
    
    if ([self commitEditing] == NO)
        return;
    
    BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
    NSArray *fieldNames;
    NSMutableArray *currentFields = [fields mutableCopy];
    
    [currentFields addObjectsFromArray:[[typeMan ratingFieldsSet] allObjects]];
    [currentFields addObjectsFromArray:[[typeMan booleanFieldsSet] allObjects]];
    [currentFields addObjectsFromArray:[[typeMan triStateFieldsSet] allObjects]];
    [currentFields addObjectsFromArray:[[typeMan noteFieldsSet] allObjects]];
    
    fieldNames = [typeMan allFieldNamesIncluding:[NSArray arrayWithObject:BDSKCrossrefString] excluding:currentFields];
    
    if([fields count] == 0){
        [currentFields release];
        NSBeep();
        return;
    }
    
    BDSKFieldSheetController *changeFieldController = [BDSKFieldSheetController fieldSheetControllerWithSelectableFields:fields
                                                                                label:NSLocalizedString(@"Name of field to change:", @"Label for changing field name")
                                                                                choosableFields:fieldNames
                                                                                label:NSLocalizedString(@"New field name:", @"Label for changing field name")];
    if (field == nil)
        field = [tableView selectedRow] == -1 ? nil : [fields objectAtIndex:[tableView selectedRow]];
    
    BDSKASSERT(field == nil || [fields containsObject:field]);
    if (field)
        [changeFieldController setSelectedField:field];
    
	[changeFieldController beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
        NSString *oldField = [changeFieldController selectedField];
        NSString *newField = [changeFieldController chosenField];
        NSString *oldValue = [[[publication valueOfField:oldField inherit:NO] retain] autorelease];
        NSInteger autoGenerateStatus = 0;
        
        if (result == NSOKButton && [NSString isEmptyString:newField] == NO  && 
            [newField isEqualToString:oldField] == NO && [fields containsObject:newField] == NO) {
            // remove the sheet in case we get an alert
            [[changeFieldController window] orderOut:nil];
            
            [addedFields removeObject:oldField];
            [addedFields addObject:newField];
            [tabView selectFirstTabViewItem:nil];
            [publication setField:oldField toValue:nil];
            [publication setField:newField toValue:oldValue];
            [[self undoManager] setActionName:NSLocalizedString(@"Change Field Name", @"Undo action name")];
            [self setKeyField:newField];
            autoGenerateStatus = [self userChangedField:oldField from:oldValue to:@""];
            [self userChangedField:newField from:@"" to:oldValue didAutoGenerate:autoGenerateStatus];
        }
	}];
    [currentFields release];
}

- (IBAction)raiseChangeFieldName:(id)sender{
    NSString *field = nil;
    NSInteger clickedRow = [tableView clickedRow];
    if (clickedRow != -1)
        field = [fields objectAtIndex:clickedRow];
    [self raiseChangeFieldSheetForField:field];
}

- (void)generateCiteKeyAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if([[alert suppressionButton] state] == NSOnState)
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:BDSKWarnOnCiteKeyChangeKey];
    
    if(returnCode == NSAlertSecondButtonReturn)
        return;
    
    // remove the sheet in case we get an alert
    [[alert window] orderOut:nil];
    
    // could use [[alert window] orderOut:nil] here, but we're using the didDismissSelector instead
    BDSKPRECONDITION([self commitEditing]);
	
	NSString *oldKey = [publication citeKey];
	NSString *newKey = [publication suggestedCiteKey];
	
	[[BDSKScriptHookManager sharedManager] runScriptHookWithName:BDSKWillGenerateCiteKeyScriptHookName 
        forPublications:[NSArray arrayWithObject:publication] document:[self document] 
        field:BDSKCiteKeyString oldValues:[NSArray arrayWithObject:oldKey] newValues:[NSArray arrayWithObject:newKey]];
	
	// get them again, as the script hook might have changed some values
	oldKey = [publication citeKey];
	newKey = [publication suggestedCiteKey];
    
    NSString *crossref = [publication valueOfField:BDSKCrossrefString inherit:NO];
    if (crossref != nil && [crossref isCaseInsensitiveEqual:newKey]) {
        alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText:NSLocalizedString(@"Could not generate cite key", @"Message in alert dialog when failing to generate cite key")];
        [alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"The cite key for \"%@\" could not be generated because the generated key would be the same as the crossref key.", @"Informative text in alert dialog"), oldKey]];
        [alert beginSheetModalForWindow:[self window]
                            modalDelegate:nil
                           didEndSelector:NULL
                              contextInfo:NULL];
        return;
    }
	[publication setCiteKey:newKey];
	
	[[self undoManager] setActionName:NSLocalizedString(@"Generate Cite Key", @"Undo action name")];
	[tabView selectFirstTabViewItem:self];
	
	[[BDSKScriptHookManager sharedManager] runScriptHookWithName:BDSKDidGenerateCiteKeyScriptHookName 
        forPublications:[NSArray arrayWithObject:publication] document:[self document] 
		field:BDSKCiteKeyString oldValues:[NSArray arrayWithObject:oldKey] newValues:[NSArray arrayWithObject:newKey]];
}

- (IBAction)generateCiteKey:(id)sender{
    
    /*
     If citekey is being edited, abort that edit, which avoids any validation for whatever is
     currently in the field.  If any other field is being edited, validate pending changes to 
     other controls before trying to generate a key.
     */
    if ([citeKeyField currentEditor]) {
        [self discardEditing];
        [citeKeyField selectText:nil];
    } else if ([self commitEditing] == NO) {
        NSBeep();
        return;
    }
    
    if([publication hasEmptyOrDefaultCiteKey] == NO && 
       [[NSUserDefaults standardUserDefaults] boolForKey:BDSKWarnOnCiteKeyChangeKey]){
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText:NSLocalizedString(@"Really Generate Cite Key?", @"Message in alert dialog when generating cite keys")];
        [alert setInformativeText:NSLocalizedString(@"This action will generate a new cite key for the publication.  This action is undoable.", @"Informative text in alert dialog")];
        [alert addButtonWithTitle:NSLocalizedString(@"Generate", @"Button title")];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Button title")];
        [alert setShowsSuppressionButton:YES];
        
        // use didDismissSelector or else we can have sheets competing for the window
        [alert beginSheetModalForWindow:[self window] 
                          modalDelegate:self 
                         didEndSelector:@selector(generateCiteKeyAlertDidEnd:returnCode:contextInfo:) 
                            contextInfo:NULL];
    } else {
        [self generateCiteKeyAlertDidEnd:nil returnCode:NSAlertFirstButtonReturn contextInfo:NULL];
    }
}

- (void)consolidateAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    NSArray *files = nil;
    NSUInteger anIndex = (NSUInteger)contextInfo;
    
    if (anIndex == NSNotFound)
        files = [publication localFiles];
    else
        files = [NSArray arrayWithObject:[publication objectInFilesAtIndex:anIndex]];
    
    if (returnCode == NSAlertThirdButtonReturn)
        return;
    
    // remove the sheet in case we get an alert
    [[alert window] orderOut:nil];
    
    if (returnCode == NSAlertSecondButtonReturn) {
        NSMutableArray *tmpFiles = [NSMutableArray array];
        
        for (BDSKLinkedFile *file in files) {
            if([publication canSetURLForLinkedFile:file])
                [tmpFiles addObject:file];
            else if([file URL])
                [publication addFileToBeFiled:file];
        }
        files = tmpFiles;
    }
    
    if ([files count] == 0)
        return;
    
	if ([[BDSKFiler sharedFiler] autoFileLinkedFiles:files fromDocument:[self document] check:NO])
        [[[self document] undoManager] setActionName:NSLocalizedString(@"Move File", @"Undo action name")];
    
	[tabView selectFirstTabViewItem:self];
}

- (IBAction)consolidateLinkedFiles:(id)sender{
    
    if ([self commitEditing] == NO)
        return;
	
    // context menu sets item index as represented object; otherwise we try to autofile everything
    NSNumber *indexNumber = [sender representedObject];
    NSUInteger anIndex = NSNotFound;
	BOOL canSet = YES;
    
    if (indexNumber) {
        anIndex = [indexNumber unsignedIntegerValue];
        canSet = [publication canSetURLForLinkedFile:[publication objectInFilesAtIndex:anIndex]];
    } else {
        for (BDSKLinkedFile *file in [publication localFiles]){
            if([publication canSetURLForLinkedFile:file] == NO){
                canSet = NO;
                break;
            }
        }
    }
    
	if (canSet == NO){
		NSString *message = NSLocalizedString(@"Not all fields needed for generating the file location are set.  Do you want me to file the paper now using the available fields, or cancel autofile for this paper?",@"Informative text in alert dialog");
		NSString *otherButton = nil;
		if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKFilePapersAutomaticallyKey]){
			message = NSLocalizedString(@"Not all fields needed for generating the file location are set. Do you want me to file the paper now using the available fields, cancel autofile for this paper, or wait until the necessary fields are set?", @"Informative text in alert dialog"),
			otherButton = NSLocalizedString(@"Wait", @"Button title");
		}
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText:NSLocalizedString(@"Warning", @"Message in alert dialog")];
        [alert setInformativeText:message];
        [alert addButtonWithTitle:NSLocalizedString(@"File Now", @"Button title")];
        if (otherButton)
            [alert addButtonWithTitle:otherButton];
        [[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Button title")] setTag:NSAlertThirdButtonReturn];
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:self
                         didEndSelector:@selector(consolidateAlertDidEnd:returnCode:contextInfo:) 
                            contextInfo:(void *)anIndex];
	} else {
        [self consolidateAlertDidEnd:nil returnCode:NSAlertFirstButtonReturn contextInfo:(void *)anIndex];
    }
}

- (IBAction)duplicateTitleToBooktitle:(id)sender{
	if ([self commitEditing]) {
        [publication duplicateTitleToBooktitleOverwriting:YES];
        [[self undoManager] setActionName:NSLocalizedString(@"Duplicate Title", @"Undo action name")];
    }
}

- (IBAction)bibTypeDidChange:(id)sender{
	if ([self commitEditing]) {
        NSString *newType = [bibTypeButton titleOfSelectedItem];
        if(![[publication pubType] isEqualToString:newType]){
            [publication setPubType:newType];
            [[NSUserDefaults standardUserDefaults] setObject:newType
                                                              forKey:BDSKPubTypeStringKey];
            
            [[self undoManager] setActionName:NSLocalizedString(@"Change Type", @"Undo action name")];
        }
    } else {
        // revert to previous
        [bibTypeButton selectItemWithTitle:[publication pubType]];
    }
}

- (void)updateTypePopup{ // used to update UI after dragging into the editor
    [bibTypeButton selectItemWithTitle:[publication pubType]];
}

- (IBAction)changeRating:(id)sender{
	BDSKRatingButtonCell *cell = [sender selectedCell];
	NSString *field = [cell representedObject];
	NSInteger oldRating = [publication ratingValueOfField:field];
	NSInteger newRating = [cell rating];
		
	if(newRating != oldRating) {
		[publication setField:field toRatingValue:newRating];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Rating", @"Undo action name")];
        [self userChangedField:field from:[NSString stringWithFormat:@"%ld", (long)oldRating] to:[NSString stringWithFormat:@"%ld", (long)newRating]];
	}
}

- (IBAction)changeFlag:(id)sender{
	NSButtonCell *cell = [sender selectedCell];
	NSString *field = [cell representedObject];
    BOOL isTriState = [[[NSUserDefaults standardUserDefaults] stringArrayForKey:BDSKTriStateFieldsKey] containsObject:field];
    
    if(isTriState){
        NSCellStateValue oldState = [publication triStateValueOfField:field];
        NSCellStateValue newState = [cell state];
        
        if(newState == oldState) return;
        
        [publication setField:field toTriStateValue:newState];
        [[self undoManager] setActionName:NSLocalizedString(@"Change Flag", @"Undo action name")];
        [self userChangedField:field from:[NSString stringWithTriStateValue:oldState] to:[NSString stringWithTriStateValue:newState]];
    }else{
        BOOL oldBool = [publication boolValueOfField:field];
        BOOL newBool = [cell state] == NSOnState ? YES : NO;
        
        if(newBool == oldBool) return;    
        
        [publication setField:field toBoolValue:newBool];
        [[self undoManager] setActionName:NSLocalizedString(@"Change Flag", @"Undo action name")];
        [self userChangedField:field from:[NSString stringWithBool:oldBool] to:[NSString stringWithBool:newBool]];
    }
	
}

- (IBAction)tableButtonAction:(id)sender{
    NSString *field = [fields objectAtIndex:[tableView clickedRow]];
    if ([field isURLField])
        [[NSWorkspace sharedWorkspace] openLinkedURL:[publication URLForField:field]];
    else
        [self openParentItemForField:[field isEqualToString:BDSKCrossrefString] ? nil : field];
}

// these methods are for crossref interaction with the table
- (void)openParentItemForField:(NSString *)field{
    BibItem *parent = [publication crossrefParent];
    if (parent)
        [[self document] editPub:parent forField:field];
}

- (IBAction)selectCrossrefParentAction:(id)sender{
    [[self document] selectCrossrefParentForItem:publication];
}

- (IBAction)createNewPubUsingCrossrefAction:(id)sender{
    [[self document] createNewPubUsingCrossrefForItem:publication];
}

- (IBAction)showPersonDetail:(id)sender{
    NSInteger i = [authorTableView clickedRow];
    
    if(i == -1)
        NSBeep();
    else
        [[self document] showPerson:[self personAtIndex:i]];
}

- (IBAction)toggleSidebar:(id)sender {
    CGFloat position = [mainSplitView maxPossiblePositionOfDividerAtIndex:0];
    
    if ([mainSplitView isSubviewCollapsed:fileSplitView]) {
        if (lastFileViewWidth <= 0.0)
            lastFileViewWidth = 150.0; // a reasonable value to start
        position -= lastFileViewWidth;
    } else {
        lastFileViewWidth = NSWidth([fileSplitView frame]);
    }
    
    [(BDSKSplitView *)mainSplitView setPosition:position ofDividerAtIndex:0 animate:sender != nil];
}

- (void)endStatusBarAnimation:(NSNumber *)visible {
    if ([visible boolValue] == NO) {
        [[self window] setContentBorderThickness:0.0 forEdge:NSMinYEdge];
        [statusBar removeFromSuperview];
    }
    editorFlags.isAnimating = NO;
}

- (IBAction)toggleStatusBar:(id)sender {
	[[NSUserDefaults standardUserDefaults] setBool:[statusBar isVisible] == NO forKey:BDSKShowEditorStatusBarKey];
    [statusBar toggleBelowView:[mainSplitView superview] animate:sender != nil];
}

- (IBAction)editAction:(id)sender {
    NSIndexSet *rowIndexes = [authorTableView selectedRowIndexes];
    NSUInteger i = [rowIndexes firstIndex];
    
    while (i != NSNotFound) {
        [[self document] showPerson:[self personAtIndex:i]];
        i = [rowIndexes indexGreaterThanIndex:i];
    }
}

- (IBAction)printSelection:(id)sender {
    [[self document] printPublications:[NSArray arrayWithObjects:publication, nil]];
}

#pragma mark Menus

- (void)menuNeedsUpdate:(NSMenu *)menu{
    NSString *menuTitle = [menu title];
    if([menuTitle isEqualToString:@"previewRecentDocumentsMenu"])
        [self updatePreviewRecentDocumentsMenu:menu];
    else if([menuTitle isEqualToString:@"safariRecentDownloadsMenu"])
        [self updateSafariRecentDownloadsMenu:menu];
    else if([menuTitle isEqualToString:@"safariRecentURLsMenu"])
        [self updateSafariRecentURLsMenu:menu];
    else if (menu == [tableView menu])
        [self updateContextMenu:menu];
}

// prevents the menus from being updated just to look for key equivalents
- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action{
    return NO;
}

- (void)fileView:(FVFileView *)aFileView willPopUpMenu:(NSMenu *)menu onIconAtIndex:(NSUInteger)anIndex {
    
    NSURL *theURL = anIndex == NSNotFound ? nil : [[publication objectInFilesAtIndex:anIndex] URL];
	NSMenu *submenu;
	NSMenuItem *item;
    NSInteger i = 0;
    
    if (theURL && [[aFileView selectionIndexes] count] <= 1) {
        i = [menu indexOfItemWithTag:FVOpenMenuItemTag];
        [menu insertItemWithTitle:NSLocalizedString(@"Open With", @"Menu item title")
                andSubmenuOfApplicationsForURL:theURL atIndex:++i];
        
        if ([theURL isFileURL]) {
            i = [menu indexOfItemWithTag:FVRevealMenuItemTag];
            item = [menu insertItemWithTitle:[NSLocalizedString(@"Skim Notes", @"Menu item title") stringByAppendingEllipsis]
                                      action:@selector(showNotesForLinkedFile:)
                               keyEquivalent:@""
                                     atIndex:++i];
            [item setRepresentedObject:theURL];
            
            item = [menu insertItemWithTitle:[NSLocalizedString(@"Copy Skim Notes", @"Menu item title") stringByAppendingEllipsis]
                                      action:@selector(copyNotesForLinkedFile:)
                               keyEquivalent:@""
                                     atIndex:++i];
            [item setRepresentedObject:theURL];
            
            if (editorFlags.isEditable) {
                i = [menu indexOfItemWithTag:FVRemoveMenuItemTag];
                item = [menu insertItemWithTitle:NSLocalizedString(@"AutoFile Linked File", @"Menu item title")
                                          action:@selector(consolidateLinkedFiles:)
                                   keyEquivalent:@""
                                         atIndex:++i];
                [item setRepresentedObject:[NSNumber numberWithUnsignedInteger:anIndex]];
                
                item = [menu insertItemWithTitle:[NSLocalizedString(@"Replace File", @"Menu item title") stringByAppendingEllipsis]
                                          action:@selector(chooseLocalFile:)
                                   keyEquivalent:@""
                                         atIndex:++i];
                [item setRepresentedObject:[NSNumber numberWithUnsignedInteger:anIndex]];

            }
        } else if (editorFlags.isEditable) {
            i = [menu indexOfItemWithTag:FVRemoveMenuItemTag];
            item = [menu insertItemWithTitle:[NSLocalizedString(@"Replace URL", @"Menu item title") stringByAppendingEllipsis]
                                      action:@selector(chooseRemoteURL:)
                               keyEquivalent:@""
                                     atIndex:++i];
            [item setRepresentedObject:[NSNumber numberWithUnsignedInteger:anIndex]];
        }
    }
    
    if (editorFlags.isEditable) {
        NSIndexSet *selectedIndexes = [fileView selectionIndexes];
        if ([[[[publication files] objectsAtIndexes:selectedIndexes] valueForKey:@"isFileURL"] containsObject:[NSNumber numberWithInteger:1]]) {
            i = [menu indexOfItemWithTag:FVRemoveMenuItemTag];
            item = [menu insertItemWithTitle:NSLocalizedString(@"Move To Trash", @"Menu item title")
                                      action:@selector(trashLinkedFiles:)
                               keyEquivalent:@""
                                     atIndex:++i];
            [item setRepresentedObject:selectedIndexes];
        }
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        [menu addItemWithTitle:[NSLocalizedString(@"Choose File", @"Menu item title") stringByAppendingEllipsis]
                        action:@selector(chooseLocalFile:)
                 keyEquivalent:@""];
        
        // get Safari recent downloads
        item = [menu addItemWithTitle:NSLocalizedString(@"Safari Recent Downloads", @"Menu item title")
                         submenuTitle:@"safariRecentDownloadsMenu"
                      submenuDelegate:self];

        // get recent downloads (Tiger only) by searching the system downloads directory
        // should work for browsers other than Safari, if they use IC to get/set the download directory
        // don't create this in the delegate method; it needs to start working in the background
        if(submenu = [self recentDownloadsMenu]){
            item = [menu addItemWithTitle:NSLocalizedString(@"Link to Recent Download", @"Menu item title") submenu:submenu];
        }
        
        // get Preview recent documents
        [menu addItemWithTitle:NSLocalizedString(@"Link to Recently Opened File", @"Menu item title")
                  submenuTitle:@"previewRecentDocumentsMenu"
               submenuDelegate:self];
            
        [menu addItem:[NSMenuItem separatorItem]];
        
        [menu addItemWithTitle:[NSLocalizedString(@"Choose URL", @"Menu item title") stringByAppendingEllipsis]
                        action:@selector(chooseRemoteURL:)
                 keyEquivalent:@""];
        
        // get Safari recent URLs
        [menu addItemWithTitle:NSLocalizedString(@"Link to Download URL", @"Menu item title")
                  submenuTitle:@"safariRecentURLsMenu"
               submenuDelegate:self];
    }
}

- (NSArray *)safariDownloadHistory{
    static NSURL *downloadPlistURL = NULL;
    if(NULL == downloadPlistURL){
        NSString *downloadPlistFileName = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
        downloadPlistFileName = [downloadPlistFileName stringByAppendingPathComponent:@"Safari"];
        downloadPlistFileName = [downloadPlistFileName stringByAppendingPathComponent:@"Downloads.plist"];
        downloadPlistURL = [[NSURL alloc] initFileURLWithPath:downloadPlistFileName];
    }
    
    NSDictionary *theDictionary = [NSDictionary dictionaryWithContentsOfURL:downloadPlistURL];
    
    if(nil == theDictionary)
        NSLog(@"failed to read Safari download property list %@ ", downloadPlistURL);
    
    return [theDictionary objectForKey:@"DownloadHistory"];
}

- (void)updateSafariRecentDownloadsMenu:(NSMenu *)menu{
	NSArray *historyArray = [self safariDownloadHistory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    [menu removeAllItems];
    
	for (NSDictionary *itemDict in historyArray) {
		NSString *filePath = [itemDict objectForKey:@"DownloadEntryPath"];
		filePath = [filePath stringByStandardizingPath];
        
        // after uncompressing the file, the original path is gone
        if([fileManager fileExistsAtPath:filePath] == NO)
            filePath = [[itemDict objectForKey:@"DownloadEntryPostPath"] stringByStandardizingPath];
		if([fileManager fileExistsAtPath:filePath]){
			NSMenuItem *item = [menu addItemWithTitle:[filePath lastPathComponent]
                                               action:@selector(addLinkedFileFromMenuItem:)
                                        keyEquivalent:@""];
			[item setRepresentedObject:[NSURL fileURLWithPath:filePath]];
			[item setImageAndSize:[[NSWorkspace sharedWorkspace] iconForFile:filePath]];
		}
	}
    
    if ([menu numberOfItems] == 0) {
        [menu addItemWithTitle:NSLocalizedString(@"No Recent Downloads", @"Menu item title") action:NULL keyEquivalent:@""];
    }
}


- (void)updateSafariRecentURLsMenu:(NSMenu *)menu{
	NSArray *historyArray = [self safariDownloadHistory];
    
    [menu removeAllItems];
	
	for (NSDictionary *itemDict in historyArray) {
		NSString *URLString = [itemDict objectForKey:@"DownloadEntryURL"];
        NSURL *aURL;
		if (![NSString isEmptyString:URLString] && (aURL = [NSURL URLWithString:URLString])) {
			NSMenuItem *item = [menu addItemWithTitle:URLString
                                               action:@selector(addRemoteURLFromMenuItem:)
                                        keyEquivalent:@""];
			[item setRepresentedObject:aURL];
			[item setImageAndSize:[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kInternetLocationGenericIcon)]];
		}
	}
    
    if ([menu numberOfItems] == 0) {
        [menu addItemWithTitle:NSLocalizedString(@"No Recent Downloads", @"Menu item title") action:NULL keyEquivalent:@""];
    }
}

- (void)updatePreviewRecentDocumentsMenu:(NSMenu *)menu{
    // get all of the items from the Apple menu (works on 10.4, anyway), and build a set of the file paths for easy comparison as strings
    NSMutableArray *globalRecentURLs = [[NSMutableArray alloc] initWithCapacity:10];
    NSDictionary *itemDict;
    NSData *aliasData;
    NSURL *fileURL;
    BDSKAlias *alias;
    
    if (&LSSharedFileListCreate != WEAK_NULL) {
        
        LSSharedFileListRef fileList = LSSharedFileListCreate(kCFAllocatorDefault, kLSSharedFileListRecentDocumentItems, NULL);
        if (NULL == fileList) {
            [globalRecentURLs release];
            return;
        }
        UInt32 seed;
        CFArrayRef fileListItems = LSSharedFileListCopySnapshot(fileList, &seed);
        CFRelease(fileList);
        
        if (fileListItems) {
            
            CFIndex idx;
            for (idx = 0; idx < CFArrayGetCount(fileListItems); idx++) {
                
                LSSharedFileListItemRef item = (void *)CFArrayGetValueAtIndex(fileListItems, idx);
                CFURLRef itemURL;
                if (noErr != LSSharedFileListItemResolve(item, 0, &itemURL, NULL))
                    [globalRecentURLs addObject:(NSURL *)itemURL];
            }
            CFRelease(fileListItems);
        }
        
    } else {
        
        CFDictionaryRef globalRecentDictionary = CFPreferencesCopyAppValue(CFSTR("Documents"), CFSTR("com.apple.recentitems"));
        NSArray *globalItems = [(NSDictionary *)globalRecentDictionary objectForKey:@"CustomListItems"];
        [(id)globalRecentDictionary autorelease];
        
        for (itemDict in globalItems) {
            aliasData = [itemDict objectForKey:@"Alias"];
            alias = [[BDSKAlias alloc] initWithData:aliasData];
            fileURL = [alias fileURLNoUI];
            if(fileURL)
                [globalRecentURLs addObject:fileURL];
            [alias release];
        }
        
    }
    
    // now get all of the recent items from the default PDF viewer; this does not include items opened since the viewer's last launch, unfortunately, regardless of the call to CFPreferencesSynchronize
    NSMutableArray *previewRecentURLs = [[NSMutableArray alloc] initWithCapacity:10];
    
    NSArray *appIDs = (NSArray *)LSCopyAllRoleHandlersForContentType(kUTTypePDF, kLSRolesEditor | kLSRolesViewer);
    NSString *appIdentifier = [appIDs count] ? [appIDs objectAtIndex:0] : @"com.apple.Preview";
    
    CFArrayRef tmpArray = CFPreferencesCopyAppValue(CFSTR("NSRecentDocumentRecords"), (CFStringRef)appIdentifier);
    
    [appIDs release];
    
    if (tmpArray) {
        for (itemDict in (NSArray *)tmpArray) {
            aliasData = [[itemDict objectForKey:@"_NSLocator"] objectForKey:@"_NSAlias"];
            alias = [[BDSKAlias alloc] initWithData:aliasData];
            fileURL = [alias fileURLNoUI];
            if(fileURL)
                [previewRecentURLs addObject:fileURL];
            [alias release];
        }
        
        CFRelease(tmpArray);
    }
    
    NSString *fileName;
    NSMenuItem *item;
    
    [menu removeAllItems];
    
    // now add all of the items from Preview, which are most likely what we want
    for (fileURL in previewRecentURLs) {
        if([[NSFileManager defaultManager] objectExistsAtFileURL:fileURL]){
            fileName = [fileURL lastPathComponent];            
            item = [menu addItemWithTitle:fileName
                                   action:@selector(addLinkedFileFromMenuItem:)
                            keyEquivalent:@""];
            [item setRepresentedObject:fileURL];
            [item setImageAndSize:[[NSWorkspace sharedWorkspace] iconForFile:[fileURL path]]];
        }
    }
    
    // add a separator between Preview and global recent items, unless Preview has never been used
    if ([previewRecentURLs count])
        [menu addItem:[NSMenuItem separatorItem]];

    // now add all of the items that /were not/ in Preview's recent items path; this works for files opened from Preview's open panel, as well as from the Finder
    for (fileURL in globalRecentURLs) {
        
        if(![previewRecentURLs containsObject:fileURL] && [[NSFileManager defaultManager] objectExistsAtFileURL:fileURL]){
            fileName = [fileURL lastPathComponent];            
            item = [menu addItemWithTitle:fileName
                                   action:@selector(addLinkedFileFromMenuItem:)
                            keyEquivalent:@""];
            [item setRepresentedObject:fileURL];
            [item setImageAndSize:[[NSWorkspace sharedWorkspace] iconForFile:[fileURL path]]];
        }
    }  
    
    if ([menu numberOfItems] == 0)
        [menu addItemWithTitle:NSLocalizedString(@"No Recent Documents", @"Menu item title") action:NULL keyEquivalent:@""];
    
    [globalRecentURLs release];
    [previewRecentURLs release];
}

- (NSMenu *)recentDownloadsMenu{
    NSMenu *menu = [[NSMenu allocWithZone:[NSMenu menuZone]] init];
    
    NSArray *paths = [[BDSKPersistentSearch sharedSearch] resultsForQuery:recentDownloadsQuery attribute:(NSString *)kMDItemPath];
    NSMenuItem *item;
    
    for (NSString *filePath in paths) {            
        item = [menu addItemWithTitle:[filePath lastPathComponent]
                               action:@selector(addLinkedFileFromMenuItem:)
                        keyEquivalent:@""];
        [item setRepresentedObject:[NSURL fileURLWithPath:filePath]];
        [item setImageAndSize:[[NSWorkspace sharedWorkspace] iconForFile:filePath]];
    }
    
    if ([menu numberOfItems] == 0) {
        [menu release];
        menu = nil;
    }
    
    return [menu autorelease];
}

- (void)updateContextMenu:(NSMenu *)menu {
    NSInteger row = [tableView clickedRow];
    NSInteger column = [tableView clickedColumn];
    if (row != -1 && column == 0 && editorFlags.isEditable) {
        [menu removeAllItems];
        [menu addItemsFromMenu:contextMenu];
        
        // kick out every item we won't need:
        NSInteger i = [menu numberOfItems];
        BOOL wasSeparator = YES;
        
        while (--i >= 0) {
            NSMenuItem *item = [menu itemAtIndex:i];
            if (([item isSeparatorItem] == NO && [self validateMenuItem:item] == NO) || ((wasSeparator || i == 0) && [item isSeparatorItem]))
                [menu removeItem:item];
            else
                wasSeparator = [item isSeparatorItem];
        }
        while ([menu numberOfItems] > 0 && [(NSMenuItem*)[menu itemAtIndex:0] isSeparatorItem])	
            [menu removeItemAtIndex:0];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem{
    
    SEL theAction = [menuItem action];
    
	if (theAction == @selector(copy:)) {
		return (editorFlags.isEditable && [[publication localFiles] count]);
	}
	else if (theAction == @selector(copyAsAction:)) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey])
            return YES;
        NSInteger copyType = [menuItem tag];
        return (copyType != BDSKPDFDragCopyType && copyType != BDSKRTFDragCopyType && copyType != BDSKLaTeXDragCopyType && copyType != BDSKLTBDragCopyType);
	}
    else if (theAction == @selector(generateCiteKey:)) {
		return editorFlags.isEditable;
	}
	else if (theAction == @selector(consolidateLinkedFiles:)) {
		return (editorFlags.isEditable && [[publication localFiles] count]);
	}
	else if (theAction == @selector(duplicateTitleToBooktitle:)) {
		return (editorFlags.isEditable && ![NSString isEmptyString:[publication valueOfField:BDSKTitleString]]);
	}
	else if (theAction == @selector(selectCrossrefParentAction:)) {
        return ([NSString isEmptyString:[publication valueOfField:BDSKCrossrefString inherit:NO]] == NO);
	}
	else if (theAction == @selector(createNewPubUsingCrossrefAction:)) {
        return (editorFlags.isEditable && [NSString isEmptyString:[publication valueOfField:BDSKCrossrefString inherit:NO]]);
	}
	else if (theAction == @selector(openLinkedFile:)) {
		return [menuItem representedObject] != nil || [[publication valueForKey:@"linkedFiles"] count] > 0;
	}
	else if (theAction == @selector(revealLinkedFile:)) {
		return [menuItem representedObject] != nil || [[publication valueForKey:@"linkedFiles"] count] > 0;
	}
	else if (theAction == @selector(openLinkedURL:)) {
		return [menuItem representedObject] != nil || [[publication valueForKey:@"linkedFiles"] count] > 0;
	}
	else if (theAction == @selector(showNotesForLinkedFile:)) {
		return [menuItem representedObject] != nil || [[publication valueForKey:@"linkedFiles"] count] > 0;
	}
	else if (theAction == @selector(copyNotesForLinkedFile:)) {
		return [menuItem representedObject] != nil || [[publication valueForKey:@"linkedFiles"] count] > 0;
	}
	else if (theAction == @selector(previewAction:)) {
		return [[publication files] count];
	}
    else if (theAction == @selector(editSelectedFieldAsRawBibTeX:)) {
        if (editorFlags.isEditable == NO)
            return NO;
        NSInteger row = [tableView editedRow];
		return (row != -1 && [complexStringEditor isAttached] == NO && 
                [[fields objectAtIndex:row] isEqualToString:BDSKCrossrefString] == NO && [[fields objectAtIndex:row] isCitationField] == NO);
    }
	else if (theAction == @selector(toggleSidebar:)) {
		if ([mainSplitView isSubviewCollapsed:fileSplitView])
            [menuItem setTitle:NSLocalizedString(@"Show Sidebar", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Hide Sidebar", @"Menu item title")];
        return YES;
	}
	else if (theAction == @selector(toggleStatusBar:)) {
		if ([statusBar isVisible])
            [menuItem setTitle:NSLocalizedString(@"Hide Status Bar", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Status Bar", @"Menu item title")];
        return YES;
	}
	else if (theAction == @selector(editAction:)) {
        return [[self window] firstResponder] == authorTableView && [authorTableView numberOfSelectedRows] > 0;
    }
    else if (theAction == @selector(raiseAddField:) || 
             theAction == @selector(raiseDelField:) || 
             theAction == @selector(raiseChangeFieldName:) || 
             theAction == @selector(chooseLocalFile:) || 
             theAction == @selector(chooseRemoteURL:) || 
             theAction == @selector(addLinkedFileFromMenuItem:) || 
             theAction == @selector(addRemoteURLFromMenuItem:)) {
        return editorFlags.isEditable;
    }

	return YES;
}

#pragma mark FVFileView support

- (NSUInteger)numberOfURLsInFileView:(FVFileView *)aFileView { return [publication countOfFiles]; }

- (NSURL *)fileView:(FVFileView *)aFileView URLAtIndex:(NSUInteger)idx;
{
    return [[publication objectInFilesAtIndex:idx] displayURL];
}

- (BOOL)fileView:(FVFileView *)aFileView moveURLsAtIndexes:(NSIndexSet *)aSet toIndex:(NSUInteger)anIndex forDrop:(id <NSDraggingInfo>)info dropOperation:(FVDropOperation)operation;
{
    BDSKASSERT(anIndex != NSNotFound);
    [publication moveFilesAtIndexes:aSet toIndex:anIndex];
    return YES;
}

- (BOOL)fileView:(FVFileView *)fileView replaceURLsAtIndexes:(NSIndexSet *)aSet withURLs:(NSArray *)newURLs forDrop:(id <NSDraggingInfo>)info dropOperation:(FVDropOperation)operation;
{
    BDSKLinkedFile *aFile = nil;
    NSEnumerator *enumerator = [newURLs objectEnumerator];
    NSURL *aURL;
    NSUInteger idx = [aSet firstIndex];
    
    while (NSNotFound != idx) {
        if ((aURL = [enumerator nextObject]) && 
            (aFile = [BDSKLinkedFile linkedFileWithURL:aURL delegate:publication])) {
            NSURL *oldURL = [[[publication objectInFilesAtIndex:idx] URL] retain];
            [publication removeObjectFromFilesAtIndex:idx];
            [publication insertObject:aFile inFilesAtIndex:idx];
            if (oldURL)
                [[self document] userRemovedURL:oldURL forPublication:publication];
            [oldURL release];
            [[self document] userAddedURL:aURL forPublication:publication];
            if (([NSEvent standardModifierFlags] & NSCommandKeyMask) == 0)
                [publication autoFileLinkedFile:aFile];
        }
        idx = [aSet indexGreaterThanIndex:idx];
    }
    return YES;
}

- (void)fileView:(FVFileView *)aFileView insertURLs:(NSArray *)absoluteURLs atIndexes:(NSIndexSet *)aSet forDrop:(id <NSDraggingInfo>)info dropOperation:(FVDropOperation)operation;
{
    BDSKLinkedFile *aFile;
    NSEnumerator *enumerator = [absoluteURLs objectEnumerator];
    NSURL *aURL;
    NSUInteger idx = [aSet firstIndex], offset = 0;
    
    while (NSNotFound != idx) {
        if ((aURL = [enumerator nextObject]) && 
            (aFile = [BDSKLinkedFile linkedFileWithURL:aURL delegate:publication])) {
            [publication insertObject:aFile inFilesAtIndex:idx - offset];
            [[self document] userAddedURL:aURL forPublication:publication];
            if (([NSEvent standardModifierFlags] & NSCommandKeyMask) == 0)
                [publication autoFileLinkedFile:aFile];
        } else {
            // the indexes in aSet assume that we inserted the file
            offset++;
        }
        idx = [aSet indexGreaterThanIndex:idx];
    }
}

- (BOOL)fileView:(FVFileView *)fileView deleteURLsAtIndexes:(NSIndexSet *)indexSet;
{
    NSInteger moveToTrash = [[NSUserDefaults standardUserDefaults] boolForKey:BDSKAskToTrashFilesKey] ? BDSKMoveToTrashAsk : BDSKMoveToTrashNo;
    [self deleteURLsAtIndexes:indexSet moveToTrash:moveToTrash];
    return YES;
}

- (BOOL)fileView:(FVFileView *)aFileView shouldOpenURL:(NSURL *)aURL {
    return [[NSWorkspace sharedWorkspace] openLinkedURL:aURL] == NO;
}

- (NSDragOperation)fileView:(FVFileView *)aFileView validateDrop:(id <NSDraggingInfo>)info proposedIndex:(NSUInteger)anIndex proposedDropOperation:(FVDropOperation)dropOperation proposedDragOperation:(NSDragOperation)dragOperation {
    NSDragOperation dragOp = dragOperation;
    if ([[info draggingSource] isEqual:fileView] && dropOperation == FVDropOn && dragOperation != NSDragOperationCopy) {
        // redirect local drop on icon and drop on view
        NSIndexSet *dragIndexes = [fileView selectionIndexes];
        NSUInteger firstIndex = [dragIndexes firstIndex], endIndex = [dragIndexes lastIndex] + 1, count = [publication countOfFiles];
        if (anIndex == NSNotFound)
            anIndex = count;
        // if we're dragging a continuous range, don't move when we drop on that range
        if ([dragIndexes count] != endIndex - firstIndex || anIndex < firstIndex || anIndex > endIndex) {
            dragOp = NSDragOperationMove;
            if (anIndex == count) // note that the count must be > 0, or we wouldn't have a local drag
                [fileView setDropIndex:count - 1 dropOperation:FVDropAfter];
            else
                [fileView setDropIndex:anIndex dropOperation:FVDropBefore];
        }
    } else if (dragOperation == NSDragOperationLink && ([NSEvent standardModifierFlags] & NSCommandKeyMask) == 0) {
        dragOp = NSDragOperationGeneric;
    }
    return dragOp;
}

- (NSURL *)fileView:(FVFileView *)aFileView downloadDestinationWithSuggestedFilename:(NSString *)filename {
    NSURL *fileURL = nil;
    NSString *extension = [filename pathExtension];
    NSString *downloadsDirectory = [[[NSUserDefaults standardUserDefaults] stringForKey:BDSKDownloadsDirectoryKey] stringByExpandingTildeInPath];
    BOOL isDir;
    
    if (downloadsDirectory == nil && [[NSUserDefaults standardUserDefaults] boolForKey:BDSKFilePapersAutomaticallyKey] && [NSString isEmptyString:extension] == NO)
        downloadsDirectory = [[[NSFileManager defaultManager] downloadFolderURL] path];
    
    if ([NSString isEmptyString:extension] == NO && [[NSFileManager defaultManager] fileExistsAtPath:downloadsDirectory isDirectory:&isDir] && isDir) {
        fileURL = [NSURL fileURLWithPath:[downloadsDirectory stringByAppendingPathComponent:filename]];
    } else {
        NSSavePanel *sPanel = [NSSavePanel savePanel];
        if (NO == [extension isEqualToString:@""]) 
            [sPanel setAllowedFileTypes:[NSArray arrayWithObjects:extension, nil]];
        [sPanel setAllowsOtherFileTypes:YES];
        [sPanel setCanSelectHiddenExtension:YES];
        [sPanel setNameFieldStringValue:filename];
        
        // we need to do this modally, not using a sheet, as the download may otherwise finish on Leopard before the sheet is done
        if (NSFileHandlingPanelOKButton == [sPanel runModal])
            fileURL = [sPanel URL];
    }
    return fileURL;
}

- (void)trashAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if (alert && [[alert suppressionButton] state] == NSOnState)
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:BDSKAskToTrashFilesKey];
    NSArray *fileURLs = [(NSArray *)contextInfo autorelease];
    if (returnCode == NSAlertSecondButtonReturn) {
        for (NSURL *url in fileURLs) {
            NSString *path = [url path];
            NSString *folderPath = [path stringByDeletingLastPathComponent];
            NSString *fileName = [path lastPathComponent];
            NSInteger tag = 0;
            [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:folderPath destination:@"" files:[NSArray arrayWithObjects:fileName, nil] tag:&tag];
        }
    }
}

- (void)deleteURLsAtIndexes:(NSIndexSet *)indexSet moveToTrash:(NSInteger)moveToTrash{
    NSUInteger idx = [indexSet lastIndex];
    NSMutableArray *fileURLs = [NSMutableArray array];
    while (NSNotFound != idx) {
        NSURL *aURL = [[[publication objectInFilesAtIndex:idx] URL] retain];
        if ([aURL isFileURL])
            [fileURLs addObject:aURL];
        [publication removeObjectFromFilesAtIndex:idx];
        if (aURL)
            [[self document] userRemovedURL:aURL forPublication:publication];
        [aURL release];
        idx = [indexSet indexLessThanIndex:idx];
    }
    if ([fileURLs count]) {
        if (moveToTrash == BDSKMoveToTrashYes) {
            [self trashAlertDidEnd:nil returnCode:NSAlertSecondButtonReturn contextInfo:[fileURLs retain]];
        } else if (moveToTrash == BDSKMoveToTrashAsk) {
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setMessageText:NSLocalizedString(@"Move Files to Trash?", @"Message in alert dialog when deleting a file")];
            [alert setInformativeText:NSLocalizedString(@"Do you want to move the removed files to the trash?", @"Informative text in alert dialog")];
            [alert addButtonWithTitle:NSLocalizedString(@"No", @"Button title")];
            [alert addButtonWithTitle:NSLocalizedString(@"Yes", @"Button title")];
            [alert setShowsSuppressionButton:YES];
            [alert beginSheetModalForWindow:[self window]
                              modalDelegate:self 
                             didEndSelector:@selector(trashAlertDidEnd:returnCode:contextInfo:)  
                                contextInfo:[fileURLs retain]];
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &BDSKEditorObservationContext) {
        [[NSUserDefaults standardUserDefaults] setInteger:[fileView displayMode] forKey:BDSKEditorFileViewDisplayModeKey];
        [[NSUserDefaults standardUserDefaults] setDouble:[fileView iconScale] forKey:BDSKEditorFileViewIconScaleKey];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark People

- (NSInteger)numberOfPersons {
    NSArray *allArrays = [[publication people] allValues];
    NSUInteger count = 0, i = [allArrays count];
    
    while(i--)
        count += [[allArrays objectAtIndex:i] count];
    
    return count;
}

- (BibAuthor *)personAtIndex:(NSUInteger)anIndex {
    return [[self persons] objectAtIndex:anIndex];
}

- (NSArray *)persons {
    NSMutableArray *array = [NSMutableArray array];
    
    for (NSArray *arr in [[publication people] allValues])
        [array addObjectsFromArray:arr];
    [array sortUsingSelector:@selector(sortCompare:)];
    
    return array;
}

#pragma mark Quick Look support

- (void)previewURLs:(NSArray *)theURLs {
    if ([theURLs count] == 1 && [FVPreviewer useQuickLookForURL:[theURLs lastObject]] == NO) {
        NSRect previewRect = NSZeroRect;
        if (editorFlags.controllingQLPreviewPanel) {
            previewRect = [[QLPreviewPanel sharedPreviewPanel] frame];
            [[QLPreviewPanel sharedPreviewPanel] performSelector:@selector(orderOut:) withObject:nil afterDelay:0.0];
        }
        if ([[FVPreviewer sharedPreviewer] isPreviewing] && editorFlags.controllingFVPreviewPanel == NO) {
            [[FVPreviewer sharedPreviewer] stopPreviewing];
        }
        [[FVPreviewer sharedPreviewer] setWebViewContextMenuDelegate:self];
        [[FVPreviewer sharedPreviewer] previewURL:[theURLs lastObject] forIconInRect:previewRect];    
        editorFlags.controllingFVPreviewPanel = YES;
    } else if ([theURLs count] == 0) {
        [self stopPreviewing];
    } else {
        if (editorFlags.controllingQLPreviewPanel) {
            if ([[FVPreviewer sharedPreviewer] isPreviewing]) {
                [[FVPreviewer sharedPreviewer] stopPreviewing];
            }
            [[QLPreviewPanel sharedPreviewPanel] reloadData];
            [[QLPreviewPanel sharedPreviewPanel] refreshCurrentPreviewItem];
        } else {
            // the QL preview panel uses the responder chain, so make sure a file view does not steal it from us
            if ([[[self window] firstResponder] isEqual:fileView]) {
                [[self window] makeFirstResponder:[self window]]; 
            }
            if ([[FVPreviewer sharedPreviewer] isPreviewing]) {
                [[FVPreviewer sharedPreviewer] stopPreviewing];
            }
            [[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront:nil]; 
        }
    }
}

- (void)stopPreviewing {
    if ([[FVPreviewer sharedPreviewer] isPreviewing]) {
        [[FVPreviewer sharedPreviewer] stopPreviewing];
    } else if (editorFlags.controllingQLPreviewPanel) {
        [[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
        [[QLPreviewPanel sharedPreviewPanel] setDataSource:nil];
        [[QLPreviewPanel sharedPreviewPanel] setDelegate:nil];
    }
}

- (void)updatePreviewing {
    if (editorFlags.controllingFVPreviewPanel || editorFlags.controllingQLPreviewPanel) {
        NSArray *theURLs = [publication valueForKeyPath:@"localFiles.URL"];
        if ([theURLs count] == 0)
            theURLs = [publication valueForKeyPath:@"remoteURLs.URL"];
        [self previewURLs:theURLs];
    }
}

- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel {
    return YES;
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel {
    editorFlags.controllingQLPreviewPanel = YES;
    [[QLPreviewPanel sharedPreviewPanel] setDataSource:self];
    [[QLPreviewPanel sharedPreviewPanel] setDelegate:self];
    [[QLPreviewPanel sharedPreviewPanel] reloadData];    
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel {
    editorFlags.controllingQLPreviewPanel = NO;
    [[QLPreviewPanel sharedPreviewPanel] setDataSource:nil];
    [[QLPreviewPanel sharedPreviewPanel] setDelegate:nil];
}

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel {
    return [[publication localFiles] count] ?: [[publication remoteURLs] count];
}

- (id <QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)idx {
    NSArray *files = [publication localFiles];
    if ([files count] == 0)
        files = [publication remoteURLs];
    return [[files objectAtIndex:idx] URL];
}

- (BOOL)previewPanel:(QLPreviewPanel *)panel handleEvent:(NSEvent *)event {
    if ([event type] == NSKeyDown && [[[self window] firstResponder] respondsToSelector:@selector(keyDown:)]) {
        [[[self window] firstResponder] keyDown:event];
        return YES;
    }
    return NO;
}

#pragma mark Key field

- (NSString *)keyField{
    NSString *keyField = nil;
    NSString *tabId = [[tabView selectedTabViewItem] identifier];
    if([tabId isEqualToString:BDSKBibtexString]){
        id firstResponder = [[self window] firstResponder];
        if ([firstResponder isKindOfClass:[NSText class]] && [firstResponder isFieldEditor])
            firstResponder = [firstResponder delegate];
        if(firstResponder == tableView)
            keyField = [tableView selectedRow] == -1 ? nil : [fields objectAtIndex:[tableView selectedRow]];
        else if(firstResponder == matrix)
            keyField = [[matrix keyCell] representedObject];
        else if(firstResponder == citeKeyField)
            keyField = BDSKCiteKeyString;
        else if(firstResponder == bibTypeButton)
            keyField = BDSKPubTypeString;
    }else{
        keyField = tabId;
    }
    return keyField;
}

- (void)setKeyField:(NSString *)fieldName{
    if([NSString isEmptyString:fieldName]){
        return;
    }else if([fieldName isNoteField]){
        [tabView selectTabViewItemWithIdentifier:fieldName];
    }else if([fieldName isEqualToString:BDSKPubTypeString]){
        [[self window] makeFirstResponder:bibTypeButton];
    }else if([fieldName isEqualToString:BDSKCiteKeyString]){
        [citeKeyField selectText:nil];
    }else if([fieldName isIntegerField]){
        NSInteger i, j, numRows = [matrix numberOfRows], numCols = [matrix numberOfColumns];
        id cell;
        
        for (i = 0; i < numRows; i++) {
            for (j = 0; j < numCols; j++) {
                cell = [matrix cellAtRow:i column:j];
                if ([[cell representedObject] isEqualToString:fieldName]) {
                    [[self window] makeFirstResponder:matrix];
                    [matrix setKeyCell:cell];
                    return;
                }
            }
        }
    }else{
        NSUInteger row = [fields indexOfObject:fieldName];
        if (row != NSNotFound) {
            [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [tableView editColumn:1 row:row withEvent:nil select:YES];
        }
    }
}

#pragma mark Text Change handling

- (IBAction)editSelectedFieldAsRawBibTeX:(id)sender{
	NSInteger row = [tableView selectedRow];
	if (row == -1) 
		return;
    [self editSelectedCellAsMacro];
	if ([tableView editedRow] != row)
		[tableView editColumn:1 row:row withEvent:nil select:YES];
}

- (BOOL)editSelectedCellAsMacro{
	NSInteger row = [tableView selectedRow];
    // this should never happen
    if ([complexStringEditor isAttached] || row == -1) 
        return NO;
	if (complexStringEditor == nil)
    	complexStringEditor = [[BDSKComplexStringEditor alloc] initWithMacroResolver:[publication macroResolver] enabled:editorFlags.isEditable];
    NSString *value = [publication valueOfField:[fields objectAtIndex:row]];
	NSText *fieldEditor = [tableView currentEditor];
	[tableCellFormatter setEditAsComplexString:YES];
	if (fieldEditor) {
		[fieldEditor setString:[tableCellFormatter editingStringForObjectValue:value]];
		[fieldEditor selectAll:self];
	}
	[complexStringEditor attachToTableView:tableView atRow:row column:1 withValue:value];
    return YES;
}

- (BOOL)formatter:(BDSKComplexStringFormatter *)formatter shouldEditAsComplexString:(NSString *)object {
    return [self editSelectedCellAsMacro];
}

// this is called when the user actually starts editing
- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor{
    BOOL canEdit = editorFlags.isEditable;
    
    if (canEdit && control == tableView) {
        // check if we're editing an inherited field
        NSString *field = [fields objectAtIndex:[tableView editedRow]];
        NSString *value = [publication valueOfField:field];
        
        if([value isInherited] &&
           [[NSUserDefaults standardUserDefaults] boolForKey:BDSKWarnOnEditInheritedKey]){
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setMessageText:NSLocalizedString(@"Inherited Value", @"Message in alert dialog when trying to edit inherited value")];
            [alert setInformativeText:NSLocalizedString(@"The value was inherited from the item linked to by the Crossref field. Do you want to overwrite the inherited value?", @"Informative text in alert dialog")];
            [alert addButtonWithTitle:NSLocalizedString(@"OK", @"Button title")];
            [alert addButtonWithTitle:NSLocalizedString(@"Edit Parent", @"Button title")];
            [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Button title")];
            [alert setShowsSuppressionButton:YES];
            
            NSInteger rv = [alert runModal];
            
            if ([[alert suppressionButton] state] == NSOnState)
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:BDSKWarnOnEditInheritedKey];
            
            if (rv == NSAlertThirdButtonReturn) {
                canEdit = NO;
            } else if (rv == NSAlertSecondButtonReturn) {
                [self openParentItemForField:field];
                canEdit = NO;
            }
        }
	}
    return canEdit;
}

- (void)controlTextDidBeginEditing:(NSNotification *)note {
    if (editorFlags.isEditing == NO) {
        [[self document] objectDidBeginEditing:self];
        editorFlags.isEditing = YES;
    }
}

// send by the formatter when validation failed
- (void)control:(NSControl *)control didFailToValidatePartialString:(NSString *)string errorDescription:(NSString *)error{
    // Don't show an annoying warning. This fails only when invalid cite key characters are used, which are simply removed by the formatter.
}

// send by the formatter when formatting in getObjectValue... failed
- (BOOL)control:(NSControl *)control didFailToFormatString:(NSString *)aString errorDescription:(NSString *)error{
	BOOL accept = NO;
    
    if (nil == error) {
        // shouldn't get here
        NSLog(@"%@:%d formatter failed for unknown reason", __FILENAMEASNSSTRING__, __LINE__);
    } else if (control == tableView) {
        
        NSString *fieldName = [fields objectAtIndex:[tableView editedRow]];
		if ([fieldName isEqualToString:BDSKCrossrefString]) {
            // this may occur if the cite key formatter fails to format
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setMessageText:NSLocalizedString(@"Invalid Crossref Key", @"Message in alert dialog when entering invalid Crossref key")];
            [alert setInformativeText:error];
            
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
		} else if ([fieldName isCitationField]) {
            // this may occur if the citation formatter fails to format
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setMessageText:NSLocalizedString(@"Invalid Citation Key", @"Message in alert dialog when entering invalid Crossref key")];
            [alert setInformativeText:error];
            
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
        } else if (NO == [tableCellFormatter editAsComplexString]) {
			// this is a simple string, an error means that there are unbalanced braces
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setMessageText:NSLocalizedString(@"Invalid Value", @"Message in alert dialog when entering an invalid value")];
            [alert setInformativeText:NSLocalizedString(@"The value you entered contains unbalanced braces and cannot be saved.", @"Informative text in alert dialog")];
            
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
        }
        
	} else if (control == citeKeyField) {
        // !!! may have to revisit this with strict invalid keys?
        // this may occur if the cite key formatter fails to format
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText:NSLocalizedString(@"Invalid Cite Key", @"Message in alert dialog when enetring invalid cite key")];
        [alert setInformativeText:error];
        [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
    }
    return accept;
}

// send when the user wants to end editing
// @@ why is this delegate method used instead of an action?  is this layer of validation called after the formatter succeeds?
- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor{
    BOOL endEdit = YES;
    
    if (control == tableView) {
        
        NSString *field = [fields objectAtIndex:[tableView editedRow]];
        NSString *value = [fieldEditor string];
        
        if ([field isEqualToString:BDSKCrossrefString] && [NSString isEmptyString:value] == NO) {
            NSString *message = nil;
            
            // check whether we won't get a crossref chain
            NSInteger errorCode = [publication canSetCrossref:value andCiteKey:[publication citeKey]];
            if (errorCode == BDSKSelfCrossrefError)
                message = NSLocalizedString(@"An item cannot cross reference to itself.", @"Informative text in alert dialog");
            else if (errorCode == BDSKChainCrossrefError)
                message = NSLocalizedString(@"Cannot cross reference to an item that has the Crossref field set.", @"Informative text in alert dialog");
            else if (errorCode == BDSKIsCrossreffedCrossrefError)
                message = NSLocalizedString(@"Cannot set the Crossref field, as the current item is cross referenced.", @"Informative text in alert dialog");
            
            if (message) {
                NSAlert *alert = [[[NSAlert alloc] init] autorelease];
                [alert setMessageText:NSLocalizedString(@"Invalid Crossref Value", @"Message in alert dialog when entering an invalid Crossref key")];
                [alert setInformativeText:message];
                
                [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
                endEdit = NO;
            }
        }
        
    } else if (control == citeKeyField) {
		
        NSString *message = nil;
        NSString *cancelButton = nil;
        NSString *defaultButton = nil;
        NSCharacterSet *invalidSet = [[BDSKTypeManager sharedManager] fragileCiteKeyCharacterSet];
        NSRange r = [[control stringValue] rangeOfCharacterFromSet:invalidSet];
        
        // check for fragile invalid characters, as the formatter doesn't do this
        if (r.location != NSNotFound) {
            
            message = NSLocalizedString(@"The cite key you entered contains characters that could be invalid in TeX. Do you want to keep them or remove them?", @"Informative text in alert dialog");
            defaultButton = NSLocalizedString(@"Remove", @"Button title");
            cancelButton = NSLocalizedString(@"Keep", @"Button title");
            
        } else {
            // check whether we won't crossref to the new citekey
            NSInteger errorCode = [publication canSetCrossref:[publication valueOfField:BDSKCrossrefString inherit:NO] andCiteKey:[control stringValue]];
            if (errorCode == BDSKSelfCrossrefError)
                message = NSLocalizedString(@"An item cannot cross reference to itself.", @"Informative text in alert dialog");
            else if (errorCode != BDSKNoCrossrefError) // shouldn't happen
                message = NSLocalizedString(@"Cannot set this cite key as this would lead to a crossreff chain.", @"Informative text in alert dialog");
        }
        
        if (message) {
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setMessageText:NSLocalizedString(@"Invalid Value", @"Message in alert dialog when entering an invalid value")];
            [alert setInformativeText:message];
            [alert addButtonWithTitle:defaultButton];
            [alert addButtonWithTitle:cancelButton];
            
            NSInteger rv = [alert runModal];
            
            if (rv == NSAlertFirstButtonReturn) {
                [control setStringValue:[[control stringValue] stringByReplacingCharactersInSet:invalidSet withString:@""]];
                endEdit = NO;
            } else {
                 [citeKeyField setStringValue:[control stringValue]];
            }
		}
	}
	
	return endEdit;
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification{
    if (editorFlags.isEditing) {
        [[self document] objectDidEndEditing:self];
        editorFlags.isEditing = NO;
    }
	
    id control = [aNotification object];
	
    if (control == tableView) {
        
        [tableCellFormatter setEditAsComplexString:NO];
        
	} else if (control == citeKeyField) {

        NSString *newKey = [control stringValue];
        NSString *oldKey = [[[publication citeKey] retain] autorelease];
        
        if(editorFlags.isEditable && [newKey isEqualToString:oldKey] == NO){
            [publication setCiteKey:newKey];
            
            [[self undoManager] setActionName:NSLocalizedString(@"Change Cite Key", @"Undo action name")];
            
            [self userChangedField:BDSKCiteKeyString from:oldKey to:newKey];
            
            [self updateCiteKeyDuplicateWarning];
            
        }
    }
}

- (void)recordChangingField:(NSString *)fieldName toValue:(NSString *)value{
    NSString *oldValue = [[[publication valueOfField:fieldName] copy] autorelease];
    
    [[fieldName retain] autorelease];
    
    [publication setField:fieldName toValue:value];
	
	[[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
    
    [self userChangedField:fieldName from:oldValue to:value];
}

- (NSInteger)userChangedField:(NSString *)fieldName from:(NSString *)oldValue to:(NSString *)newValue didAutoGenerate:(NSInteger)mask{
    mask |= [[self document] userChangedField:fieldName ofPublications:[NSArray arrayWithObject:publication] from:[NSArray arrayWithObject:oldValue ?: @""] to:[NSArray arrayWithObject:newValue]];
    
    if (mask != 0) {
        NSString *status = nil;
		if (mask == 1)
            status = NSLocalizedString(@"Autogenerated Cite Key.", @"Status message");
		else if (mask == 2)
            status = NSLocalizedString(@"Autofiled linked file.", @"Status message");
		else if (mask == 3)
            status = NSLocalizedString(@"Autogenerated Cite Key and autofiled linked file.", @"Status message");
		[self setStatus:status];
    }
    
    return mask;
}

- (NSInteger)userChangedField:(NSString *)fieldName from:(NSString *)oldValue to:(NSString *)newValue{
    return [self userChangedField:fieldName from:oldValue to:newValue didAutoGenerate:0];
}

#pragma mark annote/abstract/rss
 
- (void)setPreviousValueForCurrentEditedNotesView:(NSString *)aString {
    if (aString != previousValueForCurrentEditedView) {
        [previousValueForCurrentEditedView release];
        previousValueForCurrentEditedView = [aString copy];
    }
}

- (void)textDidBeginEditing:(NSNotification *)aNotification{
    // Add the mutableString of the text storage to the item's pubFields, so changes
    // are automatically tracked.  We still have to update the UI manually.
    // The contents of the text views are initialized with the current contents of the BibItem in windowDidLoad:
	currentEditedView = [aNotification object];
    editorFlags.ignoreFieldChange = YES;
    // we need to preserve selection manually; otherwise you end up editing at the end of the string after the call to setField: below
    NSArray *selRanges = [currentEditedView selectedRanges];
    if(currentEditedView == notesView){
        [publication setField:BDSKAnnoteString toValue:[[notesView textStorage] mutableString]];
        [[self undoManager] setActionName:NSLocalizedString(@"Edit Annotation",@"Undo action name")];
    } else if(currentEditedView == abstractView){
        [publication setField:BDSKAbstractString toValue:[[abstractView textStorage] mutableString]];
        [[self undoManager] setActionName:NSLocalizedString(@"Edit Abstract",@"Undo action name")];
    }else if(currentEditedView == rssDescriptionView){
        [publication setField:BDSKRssDescriptionString toValue:[[rssDescriptionView textStorage] mutableString]];
        [[self undoManager] setActionName:NSLocalizedString(@"Edit RSS Description",@"Undo action name")];
    }
    if([selRanges count] > 0 && validRanges(selRanges, [[currentEditedView string] length]))
        [currentEditedView setSelectedRanges:selRanges];
    editorFlags.ignoreFieldChange = NO;
    
    // save off the old value in case abortEditing gets called
    [self setPreviousValueForCurrentEditedNotesView:[currentEditedView string]];
    if (editorFlags.isEditing == NO) {
        [[self document] objectDidBeginEditing:self];
        editorFlags.isEditing = YES;
    }
}

// Clear all the undo actions when changing tab items, just in case; otherwise we
// crash if you edit in one view, switch tabs, switch back to the previous view and hit undo.
// We can't use textDidEndEditing, since just switching tabs doesn't change first responder.
- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem{
    [notesViewUndoManager removeAllActions];
    [abstractViewUndoManager removeAllActions];
    [rssDescriptionViewUndoManager removeAllActions];
}

- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem{
    return [self commitEditing];
}

- (BOOL)textShouldEndEditing:(NSText *)aTextObject {
    BDSKASSERT(aTextObject == currentEditedView);
    if (aTextObject == currentEditedView)
        return [self validateCurrentEditedView];
    return YES;
}

// sent by the textViews
- (void)textDidEndEditing:(NSNotification *)aNotification{
    if (editorFlags.isEditing) {
        [[self document] objectDidEndEditing:self];
        editorFlags.isEditing = NO;
    }
    
    NSString *field = nil;
    if(currentEditedView == notesView)
        field = BDSKAnnoteString;
    else if(currentEditedView == abstractView)
        field = BDSKAbstractString;
    else if(currentEditedView == rssDescriptionView)
        field = BDSKRssDescriptionString;
    if (field) {
        // this is needed to update the search index and tex preview
        NSString *value = [publication valueOfField:field];
        NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:field, BDSKBibItemKeyKey, value, BDSKBibItemNewValueKey, value, BDSKBibItemOldValueKey, nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibItemChangedNotification
                                                            object:publication
                                                          userInfo:notifInfo];
    }
    
    // this is called multiple times when switching tabs
    if (currentEditedView) {
        NSParameterAssert([self validateCurrentEditedView]);
        currentEditedView = nil;
        [self setPreviousValueForCurrentEditedNotesView:nil];
    }
}

// sent by the textviews; this ensures that the document's annote/abstract preview gets updated
// post with document as object; if you have multiple docs, others can ignore these notifications
- (void)textDidChange:(NSNotification *)aNotification{
    NSNotification *notif = [NSNotification notificationWithName:BDSKPreviewDisplayChangedNotification object:[self document]];
    [[NSNotificationQueue defaultQueue] enqueueNotification:notif 
                                               postingStyle:NSPostWhenIdle 
                                               coalesceMask:NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender
                                                   forModes:nil];
}

#pragma mark Notification handling

- (void)bibDidChange:(NSNotification *)notification{
	NSDictionary *userInfo = [notification userInfo];
	NSString *changeKey = [userInfo objectForKey:BDSKBibItemKeyKey];
	NSString *newValue = [userInfo objectForKey:BDSKBibItemNewValueKey];
	BibItem *sender = (BibItem *)[notification object];
	NSString *crossref = [publication valueOfField:BDSKCrossrefString inherit:NO];
	BOOL parentDidChange = (crossref != nil && 
							([crossref isCaseInsensitiveEqual:[sender citeKey]] || 
							 [crossref isCaseInsensitiveEqual:[userInfo objectForKey:BDSKBibItemOldValueKey]]));
	
    // If it is not our item or his crossref parent, we don't care, but our parent may have changed his cite key
	if (sender != publication && NO == parentDidChange) {
        // though a change of the cite key of another item may change the duplicate status
        if ([changeKey isEqualToString:BDSKCiteKeyString])
            [self updateCiteKeyDuplicateWarning];
		return;
	}
    
	if([changeKey isEqualToString:BDSKLocalFileString]){
        [fileView reloadIcons];
        [self synchronizeWindowTitleWithDocumentName];
        [self updatePreviewing];
    }
	else if([changeKey isEqualToString:BDSKRemoteURLString]){
        [fileView reloadIcons];
        [self updatePreviewing];
    }
	else if([changeKey isEqualToString:BDSKPubTypeString]){
		[self resetFieldsIfNeeded];
		[self updateTypePopup];
	}
	else if([changeKey isEqualToString:BDSKCiteKeyString]){
		[citeKeyField setStringValue:[publication citeKey]];
		[self updateCiteKeyAutoGenerateStatus];
        [self updateCiteKeyDuplicateWarning];
	}
	else if([changeKey isEqualToString:BDSKCrossrefString] || 
	   (parentDidChange && [changeKey isEqualToString:BDSKCiteKeyString])){
        // Reset if the crossref changed, or our parent's cite key changed.
        // If we are editing a crossref field, we should first set the new value, because resetFields will set the edited value. This happens when it is set through drag/drop
		NSInteger editedRow = [tableView editedRow];
        if (editedRow != -1 && [[fields objectAtIndex:editedRow] isEqualToString:changeKey])
            [[tableView currentEditor] setString:newValue ?: @""];
        if ([changeKey isEqualToString:BDSKCrossrefString] && [NSString isEmptyString:newValue] == [fields containsObject:changeKey]) {
			// Crossref field was added or removed
            [self resetFields];
        } else {
            // every field value could change, but not the displayed field names
            [self reloadTable];
        }
		[authorTableView reloadData];
		[self synchronizeWindowTitleWithDocumentName];
	}
    else if([changeKey isNoteField]){
        if(editorFlags.ignoreFieldChange == NO) {
            if([changeKey isEqualToString:BDSKAnnoteString]){
               // make a copy of the current value, so we don't overwrite it when we set the field value to the text storage
                NSString *tmpValue = [[publication valueOfField:BDSKAnnoteString inherit:NO] copy];
                [notesView setString:(tmpValue == nil ? @"" : tmpValue)];
                [tmpValue release];
                if(currentEditedView == notesView)
                    [[self window] makeFirstResponder:[self window]];
                [notesViewUndoManager removeAllActions];
            } else if([changeKey isEqualToString:BDSKAbstractString]){
                NSString *tmpValue = [[publication valueOfField:BDSKAbstractString inherit:NO] copy];
                [abstractView setString:(tmpValue == nil ? @"" : tmpValue)];
                [tmpValue release];
                if(currentEditedView == abstractView)
                    [[self window] makeFirstResponder:[self window]];
                [abstractViewUndoManager removeAllActions];
            } else if([changeKey isEqualToString:BDSKRssDescriptionString]){
                NSString *tmpValue = [[publication valueOfField:BDSKRssDescriptionString inherit:NO] copy];
                [rssDescriptionView setString:(tmpValue == nil ? @"" : tmpValue)];
                [tmpValue release];
                if(currentEditedView == rssDescriptionView)
                    [[self window] makeFirstResponder:[self window]];
                [rssDescriptionViewUndoManager removeAllActions];
            }
        }
    }
	else if([changeKey isIntegerField]){
		for (NSButtonCell *entry in [matrix cells]){
			if([[entry representedObject] isEqualToString:changeKey]){
				[entry setIntegerValue:[publication integerValueOfField:changeKey]];
				[matrix setNeedsDisplay:YES];
				break;
			}
		}
	}
    else if (changeKey){
        // this is a normal field displayed in the tableView
        
        if([changeKey isEqualToString:BDSKTitleString] || [changeKey isEqualToString:BDSKChapterString] || [changeKey isEqualToString:BDSKPagesString])
            [self synchronizeWindowTitleWithDocumentName];
        else if([changeKey isPersonField])
            [authorTableView reloadData];
        
        if ([tableView editedRow] != -1 && [[fields objectAtIndex:[tableView editedRow]] isEqualToString:changeKey]) {
            NSString *tmpValue = [publication valueOfField:changeKey] ?: @"";
            if ([changeKey isCitationField] == NO && [tableCellFormatter editAsComplexString])
                tmpValue = [tmpValue stringAsBibTeXString];
            [[tableView currentEditor] setString:tmpValue];
        }
        
        if ([NSString isEmptyAsComplexString:newValue] == [fields containsObject:changeKey]) {
			// a field was added or removed
            [self resetFields];
		} else {
            // a field value changed
            [self reloadTable];
        }
    }
	else{
        // changeKey == nil, all fields are set
        if ([tableView editedRow] != -1) {
            NSString *key = [fields objectAtIndex:[tableView editedRow]];
            NSString *tmpValue = [publication valueOfField:key] ?: @"";
            if ([changeKey isCitationField] == NO && [tableCellFormatter editAsComplexString])
                tmpValue = [tmpValue stringAsBibTeXString];
            [[tableView currentEditor] setString:tmpValue];
        }
		[self resetFields];
        [self setupMatrix];
        if(editorFlags.ignoreFieldChange == NO) {
           // make a copy of the current value, so we don't overwrite it when we set the field value to the text storage
            NSString *tmpValue = [[publication valueOfField:BDSKAnnoteString inherit:NO] copy];
            [notesView setString:(tmpValue == nil ? @"" : tmpValue)];
            [tmpValue release];
            tmpValue = [[publication valueOfField:BDSKAbstractString inherit:NO] copy];
            [abstractView setString:(tmpValue == nil ? @"" : tmpValue)];
            [tmpValue release];
            tmpValue = [[publication valueOfField:BDSKRssDescriptionString inherit:NO] copy];
            [rssDescriptionView setString:(tmpValue == nil ? @"" : tmpValue)];
            [tmpValue release];
            if(currentEditedView)
                [[self window] makeFirstResponder:[self window]];
            [notesViewUndoManager removeAllActions];
            [abstractViewUndoManager removeAllActions];
            [rssDescriptionViewUndoManager removeAllActions];
        }
	}
    
}
	
- (void)bibWasAddedOrRemoved:(NSNotification *)notification{
	NSString *crossref = [publication valueOfField:BDSKCrossrefString inherit:NO];
	
	if ([NSString isEmptyString:crossref] == NO) {
        for (id pub in [[notification userInfo] objectForKey:BDSKDocumentPublicationsKey]) {
            if ([crossref isCaseInsensitiveEqual:[pub valueForKey:@"citeKey"]]) {
                // changes in the parent cannot change the field names, as custom fields are never inherited
                [self reloadTable];
                break;
            }
        }
    }
}
 
- (void)typeInfoDidChange:(NSNotification *)aNotification{
    if ([self commitEditing]) {
        [self setupTypePopUp];
        [self resetFieldsIfNeeded];
    }
}
 
- (void)customFieldsDidChange:(NSNotification *)aNotification{
    // ensure that the pub updates first, since it observes this notification also
    [publication customFieldsDidChange:aNotification];
    if ([self commitEditing]) {
        [self resetFieldsIfNeeded];
        [self setupMatrix];
        [authorTableView reloadData];
    }
}

- (void)macrosDidChange:(NSNotification *)notification{
	id changedOwner = [[notification object] owner];
	if(changedOwner == nil || changedOwner == [publication owner]) {
        for (NSString *field in fields) {
            if ([[publication valueOfField:field] isComplex] && [self commitEditing]) {
                [self reloadTable];
                break;
            }
        }
    }
}

- (void)fileURLDidChange:(NSNotification *)notification{
    [fileView reloadIcons];
}

- (void)appDidBecomeActive:(NSNotification *)notification{
    // resolve all the URLs, when a file was renamed on disk this will trigger an update notification
    [[publication files] valueForKey:@"URL"];
}

- (void)handlePreviewerWillClose:(NSNotification *)aNote {
    /*
     Necessary to reset in case of the window close button, which doesn't go through
     our action methods.
     */
    editorFlags.controllingFVPreviewPanel = NO;
}

#pragma mark document interaction
	
- (void)bibWillBeRemoved:(NSNotification *)notification{
	NSArray *pubs = [[notification userInfo] objectForKey:BDSKDocumentPublicationsKey];
	
	if ([pubs containsObject:publication])
		[self close];
}
	
- (void)groupWillBeRemoved:(NSNotification *)notification{
	NSArray *groups = [[notification userInfo] objectForKey:BDSKGroupsArrayGroupsKey];
	
	if ([groups containsObject:[publication owner]])
		[self close];
}

#pragma mark control text delegate methods

- (NSRange)control:(NSControl *)control textView:(NSTextView *)textView rangeForUserCompletion:(NSRange)charRange {
    if (control != tableView) {
		return charRange;
	} else if ([complexStringEditor isAttached]) {
		return [[BDSKCompletionManager sharedManager] rangeForUserCompletion:charRange 
								  forBibTeXString:[textView string]];
	} else {
		return [[BDSKCompletionManager sharedManager] entry:[fields objectAtIndex:[tableView editedRow]] 
				rangeForUserCompletion:charRange 
							  ofString:[textView string]];

	}
}

- (BOOL)control:(NSControl *)control textViewShouldAutoComplete:(NSTextView *)textview {
    if (control == tableView)
		return [[NSUserDefaults standardUserDefaults] boolForKey:BDSKEditorFormShouldAutoCompleteKey];
	return NO;
}

- (NSArray *)control:(NSControl *)control textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)idx{
    if (control != tableView) {
		return words;
	} else if ([complexStringEditor isAttached]) {
		return [[BDSKCompletionManager sharedManager] possibleMatches:[[publication macroResolver] allMacroDefinitions] 
						   forBibTeXString:[textView string] 
								partialWordRange:charRange 
								indexOfBestMatch:idx];
	} else {
		return [[BDSKCompletionManager sharedManager] entry:[fields objectAtIndex:[tableView editedRow]] 
						   completions:words 
				   forPartialWordRange:charRange 
							  ofString:[textView string] 
				   indexOfSelectedItem:idx];

	}
}

- (BOOL)control:(NSControl *)control textViewShouldLinkKeys:(NSTextView *)textView {
    return [control isEqual:tableView] && [[fields objectAtIndex:[tableView editedRow]] isCitationField];
}

static NSString *queryStringWithCiteKey(NSString *citekey)
{
    return [NSString stringWithFormat:@"(net_sourceforge_bibdesk_citekey = '%@'cd) && ((kMDItemContentType != *) || (kMDItemContentType != com.apple.mail.emlx))", citekey];
}

- (BOOL)citationFormatter:(BDSKCitationFormatter *)formatter isValidKey:(NSString *)key {
    BOOL isValid;
    if ([[[publication owner] publications] itemForCiteKey:key] == nil) {
        NSString *queryString = queryStringWithCiteKey(key);
        if ([[BDSKPersistentSearch sharedSearch] hasQuery:queryString] == NO) {
            [[BDSKPersistentSearch sharedSearch] addQuery:queryString scopes:[NSArray arrayWithObject:[[[NSFileManager defaultManager] spotlightCacheFolderURLByCreating:NULL] path]]];
        }
        isValid = ([[[BDSKPersistentSearch sharedSearch] resultsForQuery:queryString attribute:(id)kMDItemPath] count] > 0);
    } else {
        isValid = YES;
    }
    return isValid;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView isValidKey:(NSString *)key {
    if ([control isEqual:tableView]) {
        return [self citationFormatter:citationFormatter isValidKey:key];
    }
    return NO;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView clickedOnLink:(id)aLink atIndex:(NSUInteger)charIndex {
    if ([control isEqual:tableView]) {
        BibItem *pub = [[[publication owner] publications] itemForCiteKey:aLink];
        if (nil == pub) {
            NSString *path = [[[BDSKPersistentSearch sharedSearch] resultsForQuery:queryStringWithCiteKey(aLink) attribute:(id)kMDItemPath] firstObject];
            // if it was a valid key/link, we should definitely have a path, but better make sure
            if (path)
                [[NSWorkspace sharedWorkspace] openLinkedURL:[NSURL fileURLWithPath:path]];
            else
                NSBeep();
        } else {
            [[self document] editPub:[[[publication owner] publications] itemForCiteKey:aLink]];
        }
        return YES;
    }
    return NO;
}

#pragma mark Status

- (NSString *)status {
	return [statusBar stringValue];
}

- (void)setStatus:(NSString *)status {
	[statusBar setStringValue:status];
}

- (NSString *)statusBar:(BDSKStatusBar *)statusBar toolTipForIdentifier:(NSString *)identifier {
	NSArray *requiredFields = nil;
	NSMutableArray *missingFields = [NSMutableArray arrayWithCapacity:5];
	NSString *tooltip = nil;
	
	if ([identifier isEqualToString:@"NeedsToGenerateCiteKey"]) {
		requiredFields = [[BDSKTypeManager sharedManager] requiredFieldsForCiteKey];
		tooltip = NSLocalizedString(@"The cite key needs to be generated.", @"Tool tip message");
	} else if ([identifier isEqualToString:@"NeedsToBeFiled"]) {
		requiredFields = [[BDSKTypeManager sharedManager] requiredFieldsForLocalFile];
		tooltip = NSLocalizedString(@"The linked file needs to be filed.", @"Tool tip message");
	} else {
		return nil;
	}
	
	for (NSString *field in requiredFields) {
		if ([field isEqualToString:BDSKCiteKeyString]) {
			if ([publication hasEmptyOrDefaultCiteKey])
				[missingFields addObject:field];
		} else if ([field isEqualToString:@"Document Filename"]) {
			if ([NSString isEmptyString:[[[self document] fileURL] path]])
				[missingFields addObject:field];
		} else if ([field isEqualToString:BDSKAuthorEditorString]) {
			if ([NSString isEmptyString:[publication valueOfField:BDSKAuthorString]] && [NSString isEmptyString:[publication valueOfField:BDSKEditorString]])
				[missingFields addObject:field];
		} else if ([NSString isEmptyString:[publication valueOfField:field]]) {
			[missingFields addObject:field];
		}
	}
	
	if ([missingFields count])
		return [tooltip stringByAppendingFormat:@" %@ %@", NSLocalizedString(@"Missing fields:", @"Tool tip message"), [missingFields componentsJoinedByString:@", "]];
	else
		return tooltip;
}

- (void)needsToBeFiledDidChange:(NSNotification *)notification{
	if ([[publication filesToBeFiled] count]) {
		[self setStatus:NSLocalizedString(@"Linked file needs to be filed.",@"Linked file needs to be filed.")];
		if ([[statusBar iconIdentifiers] containsObject:@"NeedsToBeFiled"] == NO) {
			NSString *tooltip = NSLocalizedString(@"The linked file needs to be filed.", @"Tool tip message");
			[statusBar addIcon:[NSImage imageNamed:NSImageNameFolder] withIdentifier:@"NeedsToBeFiled" toolTip:tooltip];
		}
	} else {
		[self setStatus:@""];
		[statusBar removeIconWithIdentifier:@"NeedsToBeFiled"];
	}
}

- (void)updateCiteKeyAutoGenerateStatus{
	if ([publication hasEmptyOrDefaultCiteKey] && [[NSUserDefaults standardUserDefaults] boolForKey:BDSKCiteKeyAutogenerateKey]) {
		if ([[statusBar iconIdentifiers] containsObject:@"NeedsToGenerateCiteKey"] == NO) {
			NSString *tooltip = NSLocalizedString(@"The cite key needs to be generated.", @"Tool tip message");
			[statusBar addIcon:[NSImage imageNamed:@"key"] withIdentifier:@"NeedsToGenerateCiteKey" toolTip:tooltip];
		}
	} else {
		[statusBar removeIconWithIdentifier:@"NeedsToGenerateCiteKey"];
	}
}

#pragma mark dragging destination methods

// NSWindow forwards these to its delegate, if implemented

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    // weblocs also put strings on the pboard, so check for that type first so we don't get a false positive on NSStringPboardType
    BOOL canRead = [pboard canReadItemWithDataConformingToTypes:[NSArray arrayWithObjects:BDSKPasteboardTypePublications, nil]];
    
    if (canRead == NO) {
        NSArray *strings = [pboard readObjectsForClasses:[NSArray arrayWithObject:[NSString class]] options:[NSDictionary dictionary]];
        // sniff the string to see if it's a format we can parse
        if ([strings count] > 0 && [[strings objectAtIndex:0] contentStringType] != BDSKUnknownStringType)
            canRead = YES;
    }
	
    if (canRead) {
        NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
        // get the correct cursor depending on the modifiers
        if ( ([NSEvent standardModifierFlags] & (NSAlternateKeyMask | NSCommandKeyMask)) == (NSAlternateKeyMask | NSCommandKeyMask) )
            return NSDragOperationLink;
        else if (sourceDragMask & NSDragOperationCopy)
            return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    return [self draggingUpdated:sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    
    NSPasteboard *pboard = [sender draggingPasteboard];
	NSArray *draggedPubs = nil;
    BOOL hasTemporaryCiteKey = NO;
    
    if ([pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKPasteboardTypePublications, nil]]) {
		NSData *pbData = [pboard dataForType:BDSKPasteboardTypePublications];
        // we can't just unarchive, as this gives complex strings with the wrong macroResolver
		draggedPubs = [BibItem publicationsFromArchivedData:pbData macroResolver:[publication macroResolver]];
    } else {
        NSArray *strings = [pboard readObjectsForClasses:[NSArray arrayWithObject:[NSString class]] options:[NSDictionary dictionary]];
        if ([strings count] > 0) {
            NSString *pbString = [strings objectAtIndex:0];
            NSError *error = nil;
            // this returns nil when there was a parser error and the user didn't decide to proceed anyway
            draggedPubs = [BDSKStringParser itemsFromString:pbString ofType:[pbString contentStringType] owner:[self document] error:&error];
            // we ignore warnings for parsing with temporary keys, but we want to ignore the cite key in that case
            if ([error isLocalErrorWithCode:kBDSKHadMissingCiteKeys]) {
                hasTemporaryCiteKey = YES;
                error = nil;
            } else if ([error isLocalErrorWithCode:kBDSKBibTeXParserFailed]) {
                // should we accept partially parsed bibtex?
                draggedPubs = nil;
            }
        }
    }
    
    // this happens when we didn't find a valid pboardType or parsing failed
    if([draggedPubs count] == 0) 
        return NO;
	
	BibItem *tempBI = [draggedPubs objectAtIndex:0]; // no point in dealing with multiple pubs for a single editor

	// Test a keyboard mask so that we can override all fields when dragging into the editor window (option)
	// create a crossref (cmd-option), or fill empty fields (no modifiers)
    
    // uses the Carbon function since [NSApp modifierFlags] won't work if we're not the front app
	NSUInteger modifierFlags = [NSEvent standardModifierFlags];
	
	// we always have sourceDragMask & NSDragOperationLink here for some reason, so test the mask manually
	if((modifierFlags & (NSAlternateKeyMask | NSCommandKeyMask)) == (NSAlternateKeyMask | NSCommandKeyMask)){
		
		// linking, try to set the crossref field
        NSString *crossref = [tempBI citeKey];
		NSString *message = nil;
		
		// first check if we don't create a Crossref chain
        NSInteger errorCode = [publication canSetCrossref:crossref andCiteKey:[publication citeKey]];
		if (errorCode == BDSKSelfCrossrefError)
			message = NSLocalizedString(@"An item cannot cross reference to itself.", @"Informative text in alert dialog");
		else if (errorCode == BDSKChainCrossrefError)
            message = NSLocalizedString(@"Cannot cross reference to an item that has the Crossref field set.", @"Informative text in alert dialog");
		else if (errorCode == BDSKIsCrossreffedCrossrefError)
            message = NSLocalizedString(@"Cannot set the Crossref field, as the current item is cross referenced.", @"Informative text in alert dialog");
		
		if (message) {
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setMessageText:NSLocalizedString(@"Invalid Crossref Value", @"Message in alert dialog when entering an invalid Crossref key")];
            [alert setInformativeText:message];
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
			return NO;
		}
		
        // add the crossref field if it doesn't exist, then set it to the citekey of the drag source's bibitem
		[self recordChangingField:BDSKCrossrefString toValue:crossref];
		
        return YES;
        
	} else {
	
        // we aren't linking, so here we decide which fields to overwrite, and just copy values over
        NSString *oldValue = nil;
        NSString *newValue = nil;
        BOOL shouldOverwrite = (modifierFlags & NSAlternateKeyMask) != 0;
        NSInteger autoGenerateStatus = 0;
        
        [publication setPubType:[tempBI pubType]]; // do we want this always?
        
        for (NSString *key in [tempBI allFieldNames]) {
            newValue = [tempBI valueOfField:key inherit:NO];
            if([newValue isEqualToString:@""])
                continue;
            
            oldValue = [[[publication valueOfField:key inherit:NO] retain] autorelease]; // value is the value of key in the dragged-onto window.
            
            // only set the field if we force or the value was empty
            if(shouldOverwrite || [NSString isEmptyString:oldValue]){
                // if it's a crossref we should check if we don't create a crossref chain, otherwise we ignore
                if([key isEqualToString:BDSKCrossrefString] && 
                   [publication canSetCrossref:newValue andCiteKey:[publication citeKey]] != BDSKNoCrossrefError)
                    continue;
                if ([key hasPrefix:@"Bdsk-File-"]) {
                    BDSKLinkedFile *aFile = [[BDSKLinkedFile alloc] initWithBase64String:newValue delegate:publication];
                    if (aFile) {
                        [publication insertObject:aFile inFilesAtIndex:[[publication localFiles] count]];
                        [aFile release];
                    }
                } else if ([key hasPrefix:@"Bdsk-Url-"]) {
                    BDSKLinkedFile *aURL = [[BDSKLinkedFile alloc] initWithURLString:newValue];
                    if (aURL) {
                        [publication insertObject:aURL inFilesAtIndex:[publication countOfFiles]];
                        [aURL release];
                    }
                }
                [publication setField:key toValue:newValue];
                autoGenerateStatus = [self userChangedField:key from:oldValue to:newValue didAutoGenerate:autoGenerateStatus];
            }
        }
        
        // check cite key here in case we didn't autogenerate, or we're supposed to overwrite
        if((shouldOverwrite || [publication hasEmptyOrDefaultCiteKey]) && 
           [tempBI hasEmptyOrDefaultCiteKey] == NO && hasTemporaryCiteKey == NO && 
           [publication canSetCrossref:[publication valueOfField:BDSKCrossrefString inherit:NO] andCiteKey:[tempBI citeKey]] == BDSKNoCrossrefError) {
            oldValue = [[[publication citeKey] retain] autorelease];
            newValue = [tempBI citeKey];
            [publication setCiteKey:newValue];
            autoGenerateStatus = [self userChangedField:BDSKCiteKeyString from:oldValue to:newValue didAutoGenerate:autoGenerateStatus];
        }
        
        [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
        
        return YES;
    }
}

#pragma mark NSWindow delegate methods

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject {
	if (anObject != tableView)
		return nil;
	if (dragFieldEditor == nil) {
		dragFieldEditor = [[BDSKFieldEditor alloc] init];
        if (editorFlags.isEditable)
            [(BDSKFieldEditor *)dragFieldEditor registerForDelegatedDraggedTypes:[NSArray arrayWithObjects:BDSKPasteboardTypePublications, (NSString *)kUTTypeURL, (NSString *)kUTTypeFileURL, NSURLPboardType, NSFilenamesPboardType, nil]];
	}
	return dragFieldEditor;
}

- (void)shouldCloseAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    switch (returnCode){
        case NSAlertSecondButtonReturn:
            break; // do nothing
        case NSAlertThirdButtonReturn:
            // we have a hard retain until -[BDSKEditor dealloc]
            [[self document] removePublication:publication];
            // now fall through to default
        default:
            [[alert window] orderOut:nil];
            [self close];
    }
}

- (BOOL)windowShouldClose:(id)sender{
    
    // this may trigger warning sheets, so we can't close the window
    if ([self commitEditing] == NO)
        return NO;
    
	// we shouldn't further check external items, though they could have had a macro editor
    if (editorFlags.isEditable == NO)
        return YES;
        
    NSString *errMsg = nil;
    NSString *discardMsg = nil;
    
    if (NO == [publication hasBeenEdited]) {
        // case 1: the item has not been edited
        errMsg = NSLocalizedString(@"The item has not been edited.  Would you like to close the window and keep it, discard it, or continue editing?", @"Informative text in alert dialog");
        discardMsg = NSLocalizedString(@"Discard", @"Button title");
    } else if ([[publication filesToBeFiled] count] && [[NSUserDefaults standardUserDefaults] boolForKey:BDSKFilePapersAutomaticallyKey]) {
        if ([publication hasEmptyOrDefaultCiteKey]) {
            // case 2: cite key hasn't been set, and paper needs to be filed
            errMsg = NSLocalizedString(@"The cite key for this entry has not been set, and AutoFile did not have enough information to file the paper.  Would you like to continue editing, or close the window and keep this entry as-is?", @"Informative text in alert dialog");
        } else {
            // case 3: only the paper needs to be filed
            errMsg = NSLocalizedString(@"AutoFile did not have enough information to file this paper.  Would you like to continue editing, or close the window and keep this entry as-is?", @"Informative text in alert dialog");
        }
    } else if ([publication hasEmptyOrDefaultCiteKey]) {
        // case 4: only the cite key needs to be set
        errMsg = NSLocalizedString(@"The cite key for this entry has not been set.  Would you like to edit the cite key, or close the window and keep this entry as-is?", @"Informative text in alert dialog");
    }
	
    if (errMsg) {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText:NSLocalizedString(@"Warning!", @"Message in alert dialog")];
        [alert setInformativeText:errMsg];
        [alert addButtonWithTitle:NSLocalizedString(@"Keep", @"Button title")];
        [alert addButtonWithTitle:NSLocalizedString(@"Edit", @"Button title")];
        if (discardMsg)
            [alert addButtonWithTitle:discardMsg];
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:self 
                         didEndSelector:@selector(shouldCloseAlertDidEnd:returnCode:contextInfo:) 
                            contextInfo:NULL];
        return NO; // this method returns before the callback
    } else {
        return YES;
    }
}

- (void)windowWillClose:(NSNotification *)notification{
    // make sure we're not registered as editor because we will be invalid, this shouldn't be necessary but there have been reports of crashes
    if (editorFlags.isEditing && [self commitEditing] == NO)
        [self discardEditing];
	
    // close so it's not hanging around by itself; this works if the doc window closes, also
    [complexStringEditor close];
    
    // see method for notes
    [self breakTextStorageConnections];
    
    @try {
        [fileView removeObserver:self forKeyPath:@"iconScale"];
        [fileView removeObserver:self forKeyPath:@"displayMode"];
    }
    @catch (id e) {}
    [fileView setDataSource:nil];
    [fileView setDelegate:nil];
    [tableView setDataSource:nil];
    [tableView setDelegate:nil];
    [authorTableView setDataSource:nil];
    [authorTableView setDelegate:nil];
    
	// this can give errors when the application quits when an editor window is open
	[[BDSKScriptHookManager sharedManager] runScriptHookWithName:BDSKCloseEditorWindowScriptHookName 
												 forPublications:[NSArray arrayWithObject:publication]
                                                        document:[self document]];
    
    // document still has a retain up to this point
    // @@ CMH: is this really necessary? it seems wrong
    [[self document] removeWindowController:self];
}

- (void)setDocument:(NSDocument *)document {
    // in case the document is reset before windowWillClose: is called, I think this can happen on Tiger
    if ([self document] && document == nil && editorFlags.isEditing) {
        if ([self commitEditing] == NO)
            [self discardEditing];
        if (editorFlags.isEditing) {
            [[self document] objectDidEndEditing:self];
            editorFlags.isEditing = NO;
        }
    }
    [super setDocument:document];
}

#pragma mark undo manager

- (NSUndoManager *)undoManager {
	return [[self document] undoManager];
}
    
// we want to have the same undoManager as our document, so we use this 
// NSWindow delegate method to return the doc's undomanager ...
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender{
	return [self undoManager];
}

// ... except for the abstract/annote/rss text views.
- (NSUndoManager *)undoManagerForTextView:(NSTextView *)aTextView {
	if(aTextView == notesView){
        if(notesViewUndoManager == nil)
            notesViewUndoManager = [[NSUndoManager alloc] init];
        return notesViewUndoManager;
    }else if(aTextView == abstractView){
        if(abstractViewUndoManager == nil)
            abstractViewUndoManager = [[NSUndoManager alloc] init];
        return abstractViewUndoManager;
    }else if(aTextView == rssDescriptionView){
        if(rssDescriptionViewUndoManager == nil)
            rssDescriptionViewUndoManager = [[NSUndoManager alloc] init];
        return rssDescriptionViewUndoManager;
	}else return [self undoManager];
}

#pragma mark TableView datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv{
	if ([tv isEqual:tableView]) {
        return [fields count];
	} else if ([tv isEqual:authorTableView]) {
        return [self numberOfPersons];
    }
    return 0;
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
	if ([tv isEqual:tableView]) {
        NSString *tcID = [tableColumn identifier];
        NSString *field = [fields objectAtIndex:row];
        if ([tcID isEqualToString:@"field"]) {
            return [field localizedFieldName];
        } else {
            return [publication valueOfField:field];
        }
	} else if ([tv isEqual:authorTableView]) {
        return [[self personAtIndex:row] displayName];
    }
    return nil;
}

- (void)tableView:(NSTableView *)tv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if ([tv isEqual:tableView] && [[tableColumn identifier] isEqualToString:@"value"]) {
        NSString *field = [fields objectAtIndex:row];
        NSString *oldValue = [publication valueOfField:field] ?: @"";
        if (object == nil)
            object = @"";
        
        if (NO == [object isEqualAsComplexString:oldValue])
            [self recordChangingField:field toValue:object];
    }
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op{
    if ([tv isEqual:tableView]) {
        if (op ==  NSTableViewDropAbove) {
            row = fmin(row, [tableView numberOfRows] - 1);
            [tableView setDropRow:row dropOperation:NSTableViewDropOn];
        }
        
        NSPasteboard *pboard = [info draggingPasteboard];
        NSString *field = row == -1 ? nil : [fields objectAtIndex:row];
        
        if ([info draggingSource] == tableView) {
            return NSDragOperationNone;
        } else if ([field isCitationField] || [field isEqualToString:BDSKCrossrefString]) {
            if ([pboard canReadItemWithDataConformingToTypes:[NSArray arrayWithObjects:BDSKPasteboardTypePublications, nil]])
                return NSDragOperationEvery;
        } else if ([field isLocalFileField]) {
            if ([pboard canReadFileURLOfTypes:nil]) {
                NSDragOperation mask = [info draggingSourceOperationMask];
                return mask == NSDragOperationGeneric ? NSDragOperationLink : mask == NSDragOperationCopy ? NSDragOperationCopy : NSDragOperationEvery;
            }
        } else if ([field isRemoteURLField]) {
            if ([pboard canReadURL])
                return NSDragOperationEvery;
        } else {
            [tableView setDropRow:-1 dropOperation:NSTableViewDropOn];
            return [self draggingUpdated:info];
        }
    }
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op{
    if ([tv isEqual:tableView]) {
        NSPasteboard *pboard = [info draggingPasteboard];
        NSString *field = row == -1 ? nil : [fields objectAtIndex:row];
        
        if ([field isEqualToString:BDSKCrossrefString]){
            if ([pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKPasteboardTypePublications, nil]]) {
                
                NSData *pbData = [pboard dataForType:BDSKPasteboardTypePublications];
                NSArray *draggedPubs = [BibItem publicationsFromArchivedData:pbData macroResolver:[publication macroResolver]];
                NSString *crossref = [[draggedPubs firstObject] citeKey];
                
                if ([NSString isEmptyString:crossref])
                    return NO;
                
                // first check if we don't create a Crossref chain
                NSInteger errorCode = [publication canSetCrossref:crossref andCiteKey:[publication citeKey]];
                NSString *message = nil;
                if (errorCode == BDSKSelfCrossrefError)
                    message = NSLocalizedString(@"An item cannot cross reference to itself.", @"Informative text in alert dialog");
                else if (errorCode == BDSKChainCrossrefError)
                    message = NSLocalizedString(@"Cannot cross reference to an item that has the Crossref field set.", @"Informative text in alert dialog");
                else if (errorCode == BDSKIsCrossreffedCrossrefError)
                    message = NSLocalizedString(@"Cannot set the Crossref field, as the current item is cross referenced.", @"Informative text in alert dialog");
                
                if (message) {
                    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
                    [alert setMessageText:NSLocalizedString(@"Invalid Crossref Value", @"Message in alert dialog when entering an invalid Crossref key")];
                    [alert setInformativeText:message];
                    [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
                    return NO;
                }
                
                [self recordChangingField:BDSKCrossrefString toValue:crossref];
                
                return YES;
                
            }
        } else if ([field isCitationField]) {
            if ([pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKPasteboardTypePublications, nil]]) {
                
                NSData *pbData = [pboard dataForType:BDSKPasteboardTypePublications];
                NSArray *draggedPubs = [BibItem publicationsFromArchivedData:pbData macroResolver:[publication macroResolver]];
                
                if ([draggedPubs count]) {
                    
                    NSString *citeKeys = [[draggedPubs valueForKey:@"citeKey"] componentsJoinedByString:@","];
                    NSString *oldValue = [[[publication valueOfField:field inherit:NO] retain] autorelease];
                    NSString *newValue = [NSString isEmptyString:oldValue] ? citeKeys : [NSString stringWithFormat:@"%@,%@", oldValue, citeKeys];
                    
                    [self recordChangingField:field toValue:newValue];
                    
                    return YES;
                }
                
            }
        } else if ([field isLocalFileField]) {
            NSArray *fileURLs = [pboard readFileURLsOfTypes:nil];
            
            if ([fileURLs count] > 0) {
                
                NSURL *url = [fileURLs objectAtIndex:0];
                NSString *filename = nil;
                NSDragOperation mask = [info draggingSourceOperationMask];
                if (mask == NSDragOperationGeneric) {
                    NSString *basePath = [publication basePath];
                    filename = [url path];
                    if (basePath)
                        filename = [filename relativePathFromPath:basePath];
                } else if (mask == NSDragOperationCopy) {
                    filename = [url path];
                } else {
                    filename = [url absoluteString];
                }
                [self recordChangingField:field toValue:filename];
                return YES;
                
            }
        } else if ([field isRemoteURLField]) {
            NSArray *urls = [pboard readURLs];
            
            if ([urls count] > 0) {
                [self recordChangingField:field toValue:[[urls objectAtIndex:0] absoluteString]];
                return YES;
            }
        } else {
            return [self performDragOperation:info];
        }
    }
    return NO;
}

#pragma mark TableView delegate methods

- (BOOL)tableView:(NSTableView *)tv shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
	if ([tv isEqual:tableView] && [[tableColumn identifier] isEqualToString:@"value"]) {
        // we always want to "edit" even when we are not editable, so we can always select, and the cell will prevent editing when editorFlags.isEditable == NO
        return YES;
    }
    return NO;
}

- (void)tableView:(NSTableView *)tv willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
	if ([tv isEqual:tableView]) {
        NSString *field = [fields objectAtIndex:row];
        if([[tableColumn identifier] isEqualToString:@"field"]){
            BOOL isDefault = [[[BDSKTypeManager sharedManager] requiredFieldsForType:[publication pubType]] containsObject:field];
            [cell setFont:isDefault ? [NSFont boldSystemFontOfSize:13.0] : [NSFont systemFontOfSize:13.0]];
        } else {
            NSFormatter *formatter = tableCellFormatter;
            if ([field isEqualToString:BDSKCrossrefString])
                formatter = crossrefFormatter;
            else if ([field isCitationField])
                formatter = citationFormatter;
            [cell setFormatter:formatter];
            [cell setHasButton:[[publication valueOfField:field] isInherited] || ([field isEqualToString:BDSKCrossrefString] && [NSString isEmptyString:[publication valueOfField:field inherit:NO]] == NO)];
            [cell setURL:[field isURLField] ? [publication URLForField:field] : nil];
        }
    }
}

- (NSString *)tableView:(NSTableView *)tv toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation{
	if ([tv isEqual:authorTableView]) {
        BibAuthor *person = [self personAtIndex:row];
        return [NSString stringWithFormat:@"%@ (%@)", [person displayName], [[person field] localizedFieldName]];
    }
    return nil;
}

#pragma mark Splitview delegate methods

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview {
    if ([sender isEqual:mainSplitView]) {
        return [subview isEqual:fileSplitView];
    } else if ([sender isEqual:fileSplitView]) {
        return [subview isEqual:[authorTableView enclosingScrollView]];
    }
    return NO;
}

- (BOOL)splitView:(NSSplitView *)sender shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex {
    if ([sender isEqual:mainSplitView]) {
        if ([subview isEqual:fileSplitView])
            [self toggleSidebar:sender];
    } else if ([sender isEqual:fileSplitView]) {
        if ([subview isEqual:[authorTableView enclosingScrollView]]) {
            CGFloat position = [fileSplitView maxPossiblePositionOfDividerAtIndex:dividerIndex];
            if ([fileSplitView isSubviewCollapsed:subview]) {
                if (lastAuthorsHeight <= 0.0)
                    lastAuthorsHeight = 150.0;
                if (lastAuthorsHeight > NSHeight([[fileView enclosingScrollView] frame]))
                    lastAuthorsHeight = floor(0.5 * NSHeight([[fileView enclosingScrollView] frame]));
                position -= lastAuthorsHeight;
            } else {
                lastAuthorsHeight = NSHeight([subview frame]);
            }
            [(BDSKSplitView *)fileSplitView setPosition:position ofDividerAtIndex:dividerIndex animate:YES];
        }
    }
    return NO;
}

- (BOOL)splitView:(NSSplitView *)sender shouldHideDividerAtIndex:(NSInteger)dividerIndex {
    return NO;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex {
    return proposedMax - 50.0;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex {
    if ([sender isEqual:mainSplitView]) {
        return fmax(proposedMin, 390.0);
    }
    return proposedMin;
}

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize {
    NSView *mainView = [[sender subviews] objectAtIndex:0];
    NSView *sideView = [[sender subviews] objectAtIndex:1];
    BOOL collapsed = [sender isSubviewCollapsed:sideView];
    NSSize mainSize = [mainView frame].size;
    NSSize sideSize = [sideView frame].size;
    
    if ([sender isEqual:mainSplitView]) {
        CGFloat contentWidth = NSWidth([sender frame]) - [sender dividerThickness];
        if (collapsed)
            sideSize.width = 0.0;
        else if (contentWidth < sideSize.width)
            sideSize.width = floor(contentWidth * sideSize.width / (oldSize.width - [sender dividerThickness]));
        mainSize.width = contentWidth - sideSize.width;
        sideSize.height = mainSize.height = NSHeight([sender frame]);
    } else if ([sender isEqual:fileSplitView]) {
        CGFloat contentHeight = NSHeight([sender frame]) - [sender dividerThickness];
        if (collapsed)
            sideSize.height = 0.0;
        else if (contentHeight < sideSize.height)
            sideSize.height = floor(contentHeight * sideSize.height / (oldSize.height - [sender dividerThickness]));
        mainSize.height = contentHeight - sideSize.height;
        sideSize.width = mainSize.width = NSHeight([sender frame]);
    }
    if (collapsed == NO)
        [sideView setFrameSize:sideSize];
    [mainView setFrameSize:mainSize];
    [sender adjustSubviews];
}

@end

@implementation BDSKEditor (Private)

- (NSArray *)currentFields {
    // build the new set of fields
    NSMutableArray *currentFields = [NSMutableArray array];
    NSMutableArray *allFields = [[NSMutableArray alloc] init];
    NSString *field;
    BDSKTypeManager *tm = [BDSKTypeManager sharedManager];
    NSString *type = [publication pubType];
	NSMutableSet *ignoredKeys = [[NSMutableSet alloc] initWithObjects:BDSKDateAddedString, BDSKDateModifiedString, BDSKColorString, nil];
    
    [ignoredKeys unionSet:[tm noteFieldsSet]];
    [ignoredKeys unionSet:[tm ratingFieldsSet]];
    [ignoredKeys unionSet:[tm booleanFieldsSet]];
    [ignoredKeys unionSet:[tm triStateFieldsSet]];
    
    [allFields addObjectsFromArray:[tm requiredFieldsForType:type]];
    [allFields addObjectsFromArray:[tm optionalFieldsForType:type]];
    [allFields addObjectsFromArray:[tm userDefaultFieldsForType:type]];
	
    for (field in allFields) {
        if ([ignoredKeys containsObject:field] == NO) {
            [ignoredKeys addObject:field];
            [currentFields addObject:field];
        }
    }
	
    [allFields release];
    allFields = [[publication allFieldNames] mutableCopy];
    [allFields addObjectsFromArray:[addedFields allObjects]];
    [allFields sortUsingSelector:@selector(caseInsensitiveCompare:)];
    
    for (field in allFields) {
        if ([ignoredKeys containsObject:field] == NO) {
            [ignoredKeys addObject:field];
            if ([addedFields containsObject:field] || NO == [[publication valueOfField:field inherit:NO] isEqualAsComplexString:@""])
                [currentFields addObject:field];
        }
    }
    
    [allFields release];
    [ignoredKeys release];
    
    return currentFields;
}

- (void)reloadTableWithFields:(NSArray *)newFields{
	// if we were editing in the tableView, we will restore the selected cell and the selection
	NSTextView *fieldEditor = (NSTextView *)[tableView currentEditor];
	NSString *editedTitle = nil;
	NSArray *selection = nil;
	if(fieldEditor){
		selection = [fieldEditor selectedRanges];
		editedTitle = [[fields objectAtIndex:[tableView editedRow]] retain];
        if ([[self window] makeFirstResponder:[self window]] == NO) 	 
             [NSException raise:NSInternalInconsistencyException format:@"Failed to commit edits in %s, trouble ahead", __func__];
	}
	
    if (newFields && [fields isEqualToArray:newFields] == NO) {
        
        [fields setArray:newFields];
        
        // align the cite key field with the form cells
        if([fields count] > 0){
            NSTableColumn *tableColumn = [tableView tableColumnWithIdentifier:@"field"];
            id cell;
            NSInteger numberOfRows = [fields count];
            NSInteger row, column = [[tableView tableColumns] indexOfObject:tableColumn];
            CGFloat maxWidth = NSWidth([citeKeyTitle frame]) + 4.0;
            
            for (row = 0; row < numberOfRows; row++) {
                cell = [tableView preparedCellAtColumn:column row:row];
                maxWidth = fmax(maxWidth, [cell cellSize].width);
            }
            maxWidth = ceil(maxWidth);
            [tableColumn setMinWidth:maxWidth];
            [tableColumn setMaxWidth:maxWidth];
            [tableView sizeToFit];
            NSRect frame = [citeKeyField frame];
            NSRect oldFrame = frame;
            CGFloat offset = fmin(NSMaxX(frame) - 20.0, maxWidth + NSMinX([citeKeyTitle frame]) + 4.0);
            frame.size.width = NSMaxX(frame) - offset;
            frame.origin.x = offset;
            [citeKeyField setFrame:frame];
            [[citeKeyField superview] setNeedsDisplayInRect:NSUnionRect(oldFrame, frame)];
        }
    }
    
    [tableView reloadData];
    
	// restore the edited cell and its selection
	if(editedTitle){
        NSUInteger editedRow = [fields indexOfObject:editedTitle];
        if (editedRow != NSNotFound && [tableView editedRow] != (NSInteger)editedRow) {
            [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:editedRow] byExtendingSelection:NO];
            [tableView editColumn:1 row:editedRow withEvent:nil select:NO];
            fieldEditor = (NSTextView *)[tableView currentEditor];
            if (validRanges(selection, [[fieldEditor string] length]))
                [fieldEditor setSelectedRanges:selection];
        }
        [editedTitle release];
	}
}

- (void)reloadTable {
    [self reloadTableWithFields:nil];
}

- (void)resetFields{
    [self reloadTableWithFields:[self currentFields]];
    
	editorFlags.didSetupFields = YES;
}

- (void)resetFieldsIfNeeded{
    NSArray *currentFields = [self currentFields];
    
    if ([fields isEqualToArray:currentFields] == NO)
        [self reloadTableWithFields:currentFields];
    
	editorFlags.didSetupFields = YES;
}

- (void)getNumberOfRows:(NSInteger *)rows columns:(NSInteger *)columns forMatrixCellSize:(NSSize)cellSize {
    BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
    NSInteger numEntries = [[typeMan booleanFieldsSet] count] + [[typeMan triStateFieldsSet] count] + [[typeMan ratingFieldsSet] count];
    NSSize size = [[matrix enclosingScrollView] frame].size;
    NSSize spacing = [matrix intercellSpacing];
    CGFloat colWidth = fmax(cellSize.width + spacing.width, 1.0);
    NSInteger numRows, numCols = MIN(floor((size.width + spacing.width) / colWidth), numEntries);
    numCols = MAX(numCols, 1);
    numRows = (numEntries + numCols - 1) / numCols;
    if (numRows * (cellSize.height + spacing.height) > 190.0 + spacing.height) {
        numCols = MIN(floor((size.width - [NSScroller scrollerWidth] + spacing.width) / colWidth), numEntries);
        numRows = (numEntries + numCols - 1) / numCols;
    }
    if (columns)
        *columns = numCols;
    if (rows)
        *rows = numRows;
}

- (NSSize)addMatrixButtonCell:(NSButtonCell *)templateCell toArray:(NSMutableArray *)cells forField:(NSString *)field {
    NSSize size;
    NSButtonCell *buttonCell = [templateCell copy];
    [buttonCell setTitle:[field localizedFieldName]];
    [buttonCell setRepresentedObject:field];
    [buttonCell setIntegerValue:[publication integerValueOfField:field]];
    [cells addObject:buttonCell];
    size = [buttonCell cellSize];
    [buttonCell release];
    return size;
}

- (void)setupMatrix{
	NSUserDefaults*sud = [NSUserDefaults standardUserDefaults];
    NSArray *ratingFields = [sud stringArrayForKey:BDSKRatingFieldsKey];
    NSArray *booleanFields = [sud stringArrayForKey:BDSKBooleanFieldsKey];
    NSArray *triStateFields = [sud stringArrayForKey:BDSKTriStateFieldsKey];
    NSInteger numRows, numCols, numEntries = [ratingFields count] + [booleanFields count] + [triStateFields count], i;
    NSPoint origin = [matrix frame].origin;
    NSString *field;
    NSMutableArray *cells = [NSMutableArray arrayWithCapacity:numEntries];
    NSSize size, cellSize = NSZeroSize;
	NSString *editedTitle = nil;
	
    for (field in ratingFields) {
		size = [self addMatrixButtonCell:ratingButtonCell toArray:cells forField:field];
        cellSize = NSMakeSize(fmax(size.width, cellSize.width), fmax(size.height, cellSize.height));
    }
	
    for (field in booleanFields) {
		size = [self addMatrixButtonCell:booleanButtonCell toArray:cells forField:field];
        cellSize = NSMakeSize(fmax(size.width, cellSize.width), fmax(size.height, cellSize.height));
    }
	
    for (field in triStateFields) {
		size = [self addMatrixButtonCell:triStateButtonCell toArray:cells forField:field];
        cellSize = NSMakeSize(fmax(size.width, cellSize.width), fmax(size.height, cellSize.height));
    }
    
    if ([[self window] firstResponder] == matrix)
        editedTitle = [(NSCell *)[matrix selectedCell] representedObject];
	
    while ([matrix numberOfRows])
		[matrix removeRow:0];
    
    [self getNumberOfRows:&numRows columns:&numCols forMatrixCellSize:cellSize];
    [matrix renewRows:numRows columns:numCols];
    
    for (i = 0; i < numEntries; i++)
		[matrix putCell:[cells objectAtIndex:i] atRow:i / numCols column:i % numCols];
    
	[matrix sizeToFit];
    [matrix setFrameOrigin:origin];
	
    NSView *matrixEdgeView = [[[matrix enclosingScrollView] superview] superview];
    NSView *tableScrollView = [tableView enclosingScrollView];
    NSRect tableFrame = [tableScrollView frame];
    NSRect matrixFrame = [matrixEdgeView frame];
    CGFloat dh = fmin(NSHeight([matrix frame]), 190.0) + 1.0 - NSHeight(matrixFrame);
    if ([cells count] == 0)
        dh -= 1.0;
    if (fabs(dh) > 0.1) {
        tableFrame.size.height -= dh;
        tableFrame.origin.y += dh;
        matrixFrame.size.height += dh;
        [tableScrollView setFrame:tableFrame];
        [matrixEdgeView setFrame:matrixFrame];
        [[tableScrollView superview] setNeedsDisplay:YES];
    } else {
        [matrix setNeedsDisplay:YES];
    }
    
	// restore the edited cell
    if (editedTitle) {
        NSUInteger editedIndex = [[cells valueForKey:@"representedObject"] indexOfObject:editedTitle];
        if (editedIndex != NSNotFound) {
            [[self window] makeFirstResponder:matrix];
            [matrix selectCellAtRow:editedIndex / numCols column:editedIndex % numCols];
        }
    }
}

- (void)setupButtonCells {
    // Setup the default cells for the matrix
	booleanButtonCell = [[NSButtonCell alloc] initTextCell:@""];
	[booleanButtonCell setButtonType:NSSwitchButton];
	[booleanButtonCell setTarget:self];
	[booleanButtonCell setAction:@selector(changeFlag:)];
    [booleanButtonCell setEnabled:editorFlags.isEditable];
	
	triStateButtonCell = [booleanButtonCell copy];
	[triStateButtonCell setAllowsMixedState:YES];
	
	ratingButtonCell = [[BDSKRatingButtonCell alloc] initWithMaxRating:5];
	[ratingButtonCell setImagePosition:NSImageLeft];
	[ratingButtonCell setAlignment:NSLeftTextAlignment];
	[ratingButtonCell setTarget:self];
	[ratingButtonCell setAction:@selector(changeRating:)];
    [ratingButtonCell setEnabled:editorFlags.isEditable];
	
	NSCell *cell = [[NSCell alloc] initTextCell:@""];
	[matrix setPrototype:cell];
	[cell release];
}

- (void)matrixFrameDidChange:(NSNotification *)notification {
    NSInteger numberOfColumns;
    [self getNumberOfRows:NULL columns:&numberOfColumns forMatrixCellSize:[matrix cellSize]];
    if (numberOfColumns != [matrix numberOfColumns])
        [self setupMatrix];
}

- (void)setupTypePopUp{
    [bibTypeButton removeAllItems];
    [bibTypeButton addItemsWithTitles:[[BDSKTypeManager sharedManager] types]];
    if ([bibTypeButton itemWithTitle:[publication pubType]] == nil)
        [bibTypeButton addItemWithTitle:[publication pubType]];
    [bibTypeButton selectItemWithTitle:[publication pubType]];
}

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(appDidBecomeActive:)
               name:NSApplicationDidBecomeActiveNotification
             object:NSApp];
    [nc addObserver:self
           selector:@selector(bibDidChange:)
               name:BDSKBibItemChangedNotification
             object:nil];
    [nc addObserver:self
           selector:@selector(needsToBeFiledDidChange:)
               name:BDSKNeedsToBeFiledChangedNotification
             object:publication];
    [nc addObserver:self
           selector:@selector(bibWasAddedOrRemoved:)
               name:BDSKDocAddItemNotification
             object:[self document]];
    [nc addObserver:self
           selector:@selector(bibWasAddedOrRemoved:)
               name:BDSKDocDelItemNotification
             object:[self document]];
    [nc addObserver:self
           selector:@selector(bibWillBeRemoved:)
               name:BDSKDocWillRemoveItemNotification
             object:[self document]];
    if(editorFlags.isEditable == NO)
        [nc addObserver:self
                   selector:@selector(groupWillBeRemoved:)
                       name:BDSKDidAddRemoveGroupNotification
                     object:nil];
    [nc addObserver:self
           selector:@selector(fileURLDidChange:)
               name:BDSKDocumentFileURLDidChangeNotification
             object:[self document]];
    [nc addObserver:self
           selector:@selector(typeInfoDidChange:)
               name:BDSKBibTypeInfoChangedNotification
             object:[BDSKTypeManager sharedManager]];
    [nc addObserver:self
           selector:@selector(customFieldsDidChange:)
               name:BDSKCustomFieldsChangedNotification
             object:nil];
    [nc addObserver:self
           selector:@selector(macrosDidChange:)
               name:BDSKMacroDefinitionChangedNotification
             object:nil];
    NSView *view = [[matrix enclosingScrollView] superview];
    [nc addObserver:self
           selector:@selector(matrixFrameDidChange:)
               name:NSViewFrameDidChangeNotification
             object:view];
    [nc addObserver:self
           selector:@selector(matrixFrameDidChange:)
               name:NSViewBoundsDidChangeNotification
             object:view];
    [nc addObserver:self
           selector:@selector(handlePreviewerWillClose:)
               name:FVPreviewerWillCloseNotification
             object:nil];
}


- (void)breakTextStorageConnections {
    
    // This is a fix for bug #1483613 (and others).  We set some of the BibItem's fields to -[[NSTextView textStorage] mutableString] for efficiency in tracking changes for live editing updates in the main window preview.  However, this causes a retain cycle, as the text storage retains its text view; any font changes to the editor text view will cause the retained textview to message its delegate (BDSKEditor) which is garbage in -[NSTextView _addToTypingAttributes].
    for (NSString *field in [[BDSKTypeManager sharedManager] noteFieldsSet])
        [publication replaceValueOfFieldByCopy:field];
}

- (void)updateCiteKeyDuplicateWarning{
    if (editorFlags.isEditable == NO)
        return;
    NSString *message = nil;
    if ([publication hasEmptyOrDefaultCiteKey])
        message = NSLocalizedString(@"The cite-key has not been set", @"Tool tip message");
    else if ([publication isValidCiteKey:[publication citeKey]] == NO)
        message = NSLocalizedString(@"This cite-key is a duplicate", @"Tool tip message");
	[citeKeyWarningButton setHidden:message == nil];
    [citeKeyWarningButton setToolTip:message];
	[citeKeyField setTextColor:(message ? [NSColor redColor] : [NSColor blackColor])];
}

@end


@implementation BDSKTabView

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent{
    NSEventType type = [theEvent type];
    // workaround for an NSForm bug: when selecting a button in a modal dialog after committing an edit it can try a keyEquivalent with the mouseUp event
    if (type != NSKeyDown && type != NSKeyUp)
        return NO;
    unichar c = [theEvent firstCharacter];
    NSUInteger flags = [theEvent deviceIndependentModifierFlags];
    
    if((c == NSRightArrowFunctionKey || c == NSDownArrowFunctionKey) && (flags & NSCommandKeyMask) && (flags & NSAlternateKeyMask)){
        if([self indexOfTabViewItem:[self selectedTabViewItem]] == [self numberOfTabViewItems] - 1)
            [self selectFirstTabViewItem:nil];
        else
            [self selectNextTabViewItem:nil];
        return YES;
    }else if((c == NSLeftArrowFunctionKey || c == NSUpArrowFunctionKey)  && (flags & NSCommandKeyMask) && (flags & NSAlternateKeyMask)){
        if([self indexOfTabViewItem:[self selectedTabViewItem]] == 0)
            [self selectLastTabViewItem:nil];
        else
            [self selectPreviousTabViewItem:nil];
        return YES;
    }else if(c - '1' >= 0 && c - '1' < [self numberOfTabViewItems] && flags == NSCommandKeyMask){
        [self selectTabViewItemAtIndex:c - '1'];
        return YES;
    }
    return [super performKeyEquivalent:theEvent];
}

@end

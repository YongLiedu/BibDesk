//
//  BDSKTextImportController.m
//  BibDesk
//
//  Created by Michael McCracken on 4/13/05.
/*
 This software is Copyright (c) 2005-2010
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

#import "BDSKTextImportController.h"
#import "BDSKOwnerProtocol.h"
#import "BibItem.h"
#import "BDSKTypeManager.h"
#import "BDSKComplexStringEditor.h"
#import "BDSKTypeSelectHelper.h"
#import <WebKit/WebKit.h>
#import "BDSKCrossrefFormatter.h"
#import "BDSKCiteKeyFormatter.h"
#import "BDSKFieldNameFormatter.h"
#import "BDSKEdgeView.h"
#import "BibDocument.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKAppController.h"
#import "BDSKFieldEditor.h"
#import "BDSKFieldSheetController.h"
#import "BDSKMacroResolver.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKFiler.h"
#import "BDSKStringParser.h"
#import "NSArray_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKBookmarkController.h"
#import "BDSKLinkedFile.h"
#import "BDSKCompletionManager.h"
#import "NSEvent_BDSKExtensions.h"
#import "NSInvocation_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "NSEvent_BDSKExtensions.h"


@interface BDSKTextImportController (Private)

- (void)handleFlagsChangedNotification:(NSNotification *)notification;
- (void)handleBibItemChangedNotification:(NSNotification *)notification;

- (void)finalizeChangesPreservingSelection:(BOOL)shouldPreserveSelection;

- (void)loadPasteboardData;
- (void)showWebViewWithURLString:(NSString *)urlString;
- (void)setShowingWebView:(BOOL)showWebView;
- (void)setupTypeUI;
- (void)setType:(NSString *)type;

- (void)initialOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)initialUrlSheetDidEnd:(NSPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)urlSheetDidEnd:(NSPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)autoDiscoverFromFrameAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)autoDiscoverFromStringAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

- (void)setLoading:(BOOL)loading;

- (void)cancelDownload;
- (void)setLocalUrlFromDownload;
- (void)setDownloading:(BOOL)downloading;

- (BOOL)addCurrentSelectionToFieldAtIndex:(NSUInteger)index;
- (void)recordChangingField:(NSString *)fieldName toValue:(NSString *)value;
- (BOOL)autoFileLinkedFile:(BDSKLinkedFile *)file;

- (BOOL)editSelectedCellAsMacro;
- (void)autoDiscoverDataFromFrame:(WebFrame *)frame;
- (void)autoDiscoverDataFromString:(NSString *)string;
- (void)setCiteKeyDuplicateWarning:(BOOL)set;

@end

@implementation BDSKTextImportController

- (id)initWithDocument:(BibDocument *)doc{
    self = [super initWithWindowNibName:[self windowNibName]];
    if(self){
        document = doc;
        item = [[BibItem alloc] init];
        [item setOwner:self];
        fields = [[NSMutableArray alloc] init];
        showingWebView = NO;
        itemsAdded = [[NSMutableArray alloc] init];
		webSelection = nil;
		tableCellFormatter = [[BDSKComplexStringFormatter alloc] initWithDelegate:self macroResolver:[doc macroResolver]];
		crossrefFormatter = [[BDSKCrossrefFormatter alloc] init];
		citationFormatter = [[BDSKCitationFormatter alloc] initWithDelegate:self];
		complexStringEditor = nil;
    }
    return self;
}

- (void)dealloc{
    BDSKASSERT(download == nil);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // next line is a workaround for a nasty webview crasher; looks like it messages a garbage pointer to its undo manager
    [webView setEditingDelegate:nil];
    BDSKDESTROY(item);
    BDSKDESTROY(fields);
    BDSKDESTROY(itemsAdded);
    BDSKDESTROY(tableCellFormatter);
    BDSKDESTROY(crossrefFormatter);
    BDSKDESTROY(citationFormatter);
    BDSKDESTROY(sourceBox);
    BDSKDESTROY(webViewView);
	BDSKDESTROY(complexStringEditor);
	BDSKDESTROY(webSelection);
    BDSKDESTROY(tableFieldEditor);
    BDSKDESTROY(downloadFileName);
    BDSKDESTROY(undoManager);
    [super dealloc];
}

- (NSString *)windowNibName { return @"TextImport"; }

- (void)windowDidLoad{
    [citeKeyField setFormatter:[[[BDSKCiteKeyFormatter alloc] init] autorelease]];
    [citeKeyField setStringValue:[item citeKey]];
    
    [statusLine setStringValue:@""];
	
    [webViewBox setEdges:BDSKEveryEdgeMask];
	[webViewBox setContentView:webView];
    
    [self setupTypeUI];
    
    // these can be swapped in/out
    [sourceBox retain];
    [webViewView retain];
	
    [webView setEditingDelegate:self];
	
    [itemTableView registerForDraggedTypes:[NSArray arrayWithObject:NSStringPboardType]];
    [itemTableView setDoubleAction:@selector(addTextToCurrentFieldAction:)];
    
    [self setWindowFrameAutosaveName:@"BDSKTextImportController Frame Autosave Name"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleFlagsChangedNotification:)
                                                 name:BDSKFlagsChangedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleBibItemChangedNotification:)
                                                 name:BDSKBibItemChangedNotification
                                               object:nil];
}

#pragma mark Calling the main sheet

- (void)beginSheetForPasteboardModalForWindow:(NSWindow *)docWindow {
	// we start with the pasteboard data, so we can directly show the main sheet 
    // make sure we loaded the nib
    [self window];
	[self loadPasteboardData];
	
    [super beginSheetModalForWindow:docWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (void)beginSheetForWebModalForWindow:(NSWindow *)docWindow {
	// we start with a webview, so we first ask for the URL to load
    // make sure we loaded the nib;
    [self window];
	[self setShowingWebView:YES];
	
	[self retain]; // make sure we stay around till we are done
	
	// now show the URL sheet. We will show the main sheet when that is done.
	[NSApp beginSheet:urlSheet
	   modalForWindow:docWindow
		modalDelegate:self
	   didEndSelector:@selector(initialUrlSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:[docWindow retain]];
}
		
- (void)beginSheetForFileModalForWindow:(NSWindow *)docWindow {
	// we start with a file, so we first ask for the file to load
    // make sure we loaded the nib
    [self window];
	
	[self retain]; // make sure we stay around till we are done
	
	NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	[oPanel setAllowsMultipleSelection:NO];
	[oPanel setCanChooseDirectories:NO];

	[oPanel beginSheetForDirectory:nil 
							  file:nil 
							 types:nil
					modalForWindow:docWindow
					 modalDelegate:self 
					didEndSelector:@selector(initialOpenPanelDidEnd:returnCode:contextInfo:) 
					   contextInfo:[docWindow retain]];
}

#pragma mark Actions

- (IBAction)addItemAction:(id)sender{
    NSInteger optKey = [NSEvent standardModifierFlags] & NSAlternateKeyMask;
    BibItem *newItem = (optKey) ? [item copy] : [[BibItem alloc] init];
    
    // make the tableview stop editing:
    [self finalizeChangesPreservingSelection:NO];
    
	[itemsAdded addObject:item];
    [[self undoManager] removeAllActions];
    [item setOwner:nil];
    [document addPublication:item];
    
    if ([item hasEmptyOrDefaultCiteKey])
        [item setCiteKey:[item suggestedCiteKey]];
    if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKFilePapersAutomaticallyKey] && [[item filesToBeFiled] count]){
        NSMutableArray *files = [NSMutableArray array];
        
        for (BDSKLinkedFile *file in [item filesToBeFiled]) {
            if([item canSetURLForLinkedFile:file] == NO)
                continue;
            [files addObject:file];
        }
        if ([files count])
            [[BDSKFiler sharedFiler] filePapers:files fromDocument:document check:NO];
    }
    
    [item release];
    
    item = newItem;
    [item setOwner:self];
	
	NSInteger numItems = [itemsAdded count];
	NSString *pubSingularPlural = (numItems == 1) ? NSLocalizedString(@"publication", @"publication, in status message") : NSLocalizedString(@"publications", @"publications, in status message");
    [statusLine setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%ld %@ added.", @"format string for pubs added. args: one NSInteger for number added, then one string for singular or plural of publication(s)."), (long)numItems, pubSingularPlural]];
    
    [itemTypeButton selectItemWithTitle:[item pubType]];
    [citeKeyField setStringValue:[item citeKey]];
    [self setCiteKeyDuplicateWarning:[item isValidCiteKey:[item citeKey]] == NO];
    [itemTableView reloadData];
}

- (IBAction)closeAction:(id)sender{
    // make the tableview stop editing:
    [self finalizeChangesPreservingSelection:NO];
    [[self undoManager] removeAllActions];
    [item setOwner:nil];
    [item release];
    item = nil;
    [super dismiss:sender];
}

- (IBAction)addItemAndCloseAction:(id)sender{
	[self addItemAction:sender];
	[self closeAction:sender];
}

- (IBAction)clearAction:(id)sender{
    [[self undoManager] removeAllActions];
    [item setOwner:nil];
    [item release];
    item = [[BibItem alloc] init];
    [item setOwner:self];
    
    [itemTypeButton selectItemWithTitle:[item pubType]];
    [citeKeyField setStringValue:[item citeKey]];
    [self setCiteKeyDuplicateWarning:[item isValidCiteKey:[item citeKey]] == NO];
    [itemTableView reloadData];
}

- (IBAction)showHelpAction:(id)sender{
    NSString *helpBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"AddingReferencesFromTextSources" inBook:helpBookName];
}

- (IBAction)addTextToCurrentFieldAction:(id)sender{
    
    if ([self addCurrentSelectionToFieldAtIndex:[sender selectedRow]] == NO)
        NSBeep();
}

- (IBAction)changeTypeOfBibAction:(id)sender{
    NSString *type = [[sender selectedItem] title];
    [self setType:type];
    [[NSUserDefaults standardUserDefaults] setObject:type
                                                      forKey:BDSKPubTypeStringKey];

	[[item undoManager] setActionName:NSLocalizedString(@"Change Type", @"Undo action name")];
    [itemTableView reloadData];
}

- (IBAction)importFromPasteboardAction:(id)sender{
	[self loadPasteboardData];
}

- (IBAction)importFromWebAction:(id)sender{
	[NSApp beginSheet:urlSheet
       modalForWindow:[self window]
        modalDelegate:self
       didEndSelector:@selector(urlSheetDidEnd:returnCode:contextInfo:)
          contextInfo:NULL];
}

- (IBAction)dismissUrlSheet:(id)sender{
    [urlSheet orderOut:sender];
    [NSApp endSheet:urlSheet returnCode:[sender tag]];
}

- (IBAction)importFromFileAction:(id)sender{
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:NO];
    [oPanel setCanChooseDirectories:NO];

    [oPanel beginSheetForDirectory:nil 
                              file:nil 
							 types:nil
                    modalForWindow:[self window]
                     modalDelegate:self 
                    didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) 
                       contextInfo:nil];
}

- (IBAction)openBookmark:(id)sender{
    NSURL *url = [sender representedObject];
    [self setShowingWebView:YES];
    [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];
}

- (IBAction)stopOrReloadAction:(id)sender{
	if(isDownloading){
		[self setDownloading:NO];
	}else if (isLoading){
		[webView stopLoading:sender];
	}else{
		[webView reload:sender];
	}
}

- (void)addFieldSheetDidEnd:(BDSKAddFieldSheetController *)addFieldController returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
	NSString *newField = [addFieldController field];
    newField = [newField fieldName];
    
    if(newField == nil || [fields containsObject:newField])
        return;
    
    NSInteger row = [fields count];
    
    [fields addObject:newField];
    [item setField:newField toValue:[NSString stringWithFormat:@"%@ %@",NSLocalizedString(@"Add data for field:", @"Default value for new field"), newField]];
    [[item undoManager] setActionName:NSLocalizedString(@"Add Field", @"Undo action name")];
    [itemTableView reloadData];
    [itemTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [itemTableView editColumn:2 row:row withEvent:nil select:YES];
}

- (IBAction)addField:(id)sender{
    BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
    NSArray *currentFields = [item allFieldNames];
    NSArray *fieldNames = [typeMan allFieldNamesIncluding:[NSArray arrayWithObject:BDSKCrossrefString] excluding:currentFields];
    
    BDSKAddFieldSheetController *addFieldController = [[BDSKAddFieldSheetController alloc] initWithPrompt:NSLocalizedString(@"Name of field to add:",@"Label for adding field")
                                                                                              fieldsArray:fieldNames];
	[addFieldController beginSheetModalForWindow:[self window]
                                   modalDelegate:self
                                  didEndSelector:@selector(addFieldSheetDidEnd:returnCode:contextInfo:)
                                     contextInfo:NULL];
    [addFieldController release];
}

- (IBAction)editSelectedFieldAsRawBibTeX:(id)sender{
	NSInteger row = [itemTableView selectedRow];
	if (row == -1) 
		return;
    [self editSelectedCellAsMacro];
	if([itemTableView editedRow] != row)
		[itemTableView editColumn:2 row:row withEvent:nil select:YES];
}

- (IBAction)generateCiteKey:(id)sender{
    // make the tableview stop editing:
    [self finalizeChangesPreservingSelection:YES];
	
    [item setCiteKey:[item suggestedCiteKey]];
    [[item undoManager] setActionName:NSLocalizedString(@"Generate Cite Key", @"Undo action name")];
}

- (IBAction)showCiteKeyWarning:(id)sender{
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Duplicate Cite Key", @"Message in alert dialog when duplicate citye key was found")
                                     defaultButton:nil
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:NSLocalizedString(@"The citation key you entered is either already used in this document or is empty. Please provide a unique one.", @"Informative text in alert dialog")];
    [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (void)consolidateAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    NSArray *files = nil;
    
    if (returnCode == NSAlertAlternateReturn){
        return;
    }else if(returnCode == NSAlertOtherReturn){
        files = [NSMutableArray array];
        
        for (BDSKLinkedFile *file in [item localFiles]){
            if([item canSetURLForLinkedFile:file] == NO)
                [item addFileToBeFiled:file];
            else
                [(NSMutableArray *)files addObject:file];
        }
    }else{
        files = [item localFiles];
    }
    
    if ([files count] == 0)
        return;
    
    [[BDSKFiler sharedFiler] filePapers:files fromDocument:document check:NO];
	
	[[self undoManager] setActionName:NSLocalizedString(@"Move File", @"Undo action name")];
}

- (IBAction)consolidateLinkedFiles:(id)sender{
    // make the tableview stop editing:
    [self finalizeChangesPreservingSelection:YES];
	BOOL canSet = YES;
    
    for (BDSKLinkedFile *file in [item localFiles]) {
        if ([item canSetURLForLinkedFile:file] == NO) {
            canSet = NO;
            break;
        }
    }
    
	if (canSet == NO){
		NSString *message = NSLocalizedString(@"Not all fields needed for generating the file location are set.  Do you want me to file the paper now using the available fields, or cancel autofile for this paper?", @"Informative text in alert");
		NSString *otherButton = nil;
		if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKFilePapersAutomaticallyKey]){
			message = NSLocalizedString(@"Not all fields needed for generating the file location are set. Do you want me to file the paper now using the available fields, cancel autofile for this paper, or wait until the necessary fields are set?", @"Informative text in alert dialog"),
			otherButton = NSLocalizedString(@"Wait", @"Button title");
		}
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Warning", @"Message in alert dialog") 
                                         defaultButton:NSLocalizedString(@"File Now", @"Button title")
                                       alternateButton:NSLocalizedString(@"Cancel", @"Button title")
                                           otherButton:otherButton
                             informativeTextWithFormat:message];
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:self
                         didEndSelector:@selector(consolidateAlertDidEnd:returnCode:contextInfo:) 
                            contextInfo:NULL];
	} else {
        [self consolidateAlertDidEnd:nil returnCode:NSAlertDefaultReturn contextInfo:NULL];
    }
}

#pragma mark WebView contextual menu actions

- (void)copyLocationAsRemoteUrl:(id)sender{
	NSURL *aURL = [[[[webView mainFrame] dataSource] request] URL];
	
	if (aURL) {
        [item addFileForURL:aURL autoFile:YES runScriptHook:NO];
        [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
	}
}

- (void)copyLinkedLocationAsRemoteUrl:(id)sender{
	NSURL *aURL = (NSURL *)[sender representedObject];
	
	if (aURL) {
        [item addFileForURL:aURL autoFile:YES runScriptHook:NO];
        [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
	}
}

- (void)saveFileAsLocalUrl:(id)sender{
	WebDataSource *dataSource = [[webView mainFrame] dataSource];
	if (!dataSource || [dataSource isLoading]) 
		return;
	
	NSString *fileName = [[[[dataSource request] URL] relativePath] lastPathComponent];
	NSString *extension = [fileName pathExtension];

    NSSavePanel *sPanel = [NSSavePanel savePanel];
    if (![extension isEqualToString:@""]) 
		[sPanel setRequiredFileType:extension];
    [sPanel setCanCreateDirectories:YES];

    [sPanel beginSheetForDirectory:nil 
                              file:fileName 
                    modalForWindow:[self window]
                     modalDelegate:self 
                    didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) 
                       contextInfo:nil];
}

- (void)downloadLinkedFileAsLocalUrl:(id)sender{
	NSURL *linkURL = (NSURL *)[sender representedObject];
    if (isDownloading)
        return;
	if (linkURL) {
		download = [[WebDownload alloc] initWithRequest:[NSURLRequest requestWithURL:linkURL] delegate:self];
	}
	if (!download) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid or Unsupported URL", @"Message in alert dialog when unable to download file for Local-Url")
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"The URL to download is either invalid or unsupported.", @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
	}
}

- (void)bookmarkLink:(id)sender{
	NSDictionary *element = (NSDictionary *)[sender representedObject];
	NSString *URLString = [(NSURL *)[element objectForKey:WebElementLinkURLKey] absoluteString];
	NSString *title = [element objectForKey:WebElementLinkLabelKey] ?: [URLString lastPathComponent];
	
    [[BDSKBookmarkController sharedBookmarkController] addBookmarkWithUrlString:URLString proposedName:title modalForWindow:[self window]];
}

#pragma mark UndoManager

- (NSUndoManager *)undoManager {
    if (undoManager == nil)
        undoManager = [[NSUndoManager alloc] init];
    return undoManager;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender {
    return [self undoManager];
}

#pragma mark BDSKOwner protocol

- (BDSKPublicationsArray *)publications {
    return [document publications];
}

- (BDSKMacroResolver *)macroResolver {
    return [document macroResolver];
}

- (NSURL *)fileURL {
    return [document fileURL];
}

- (NSString *)documentInfoForKey:(NSString *)key {
    return [document documentInfoForKey:key];
}

- (BOOL)isDocument { return NO; }

- (BDSKItemSearchIndexes *)searchIndexes { return nil; }

#pragma mark Private

- (void)handleFlagsChangedNotification:(NSNotification *)notification{
    NSUInteger modifierFlags = [NSEvent standardModifierFlags];
    
    if (modifierFlags & NSAlternateKeyMask) {
        [addButton setTitle:NSLocalizedString(@"Add & Copy", @"Button title")];
    } else {
        [addButton setTitle:NSLocalizedString(@"Add", @"Button title")];
    }
}

- (void)handleBibItemChangedNotification:(NSNotification *)notification{
    if ([notification object] != item)
        return;
	
	NSString *changeKey = [[notification userInfo] objectForKey:@"key"];
    
	if([changeKey isEqualToString:BDSKCiteKeyString]) {
		[citeKeyField setStringValue:[item citeKey]];
        [self setCiteKeyDuplicateWarning:[item isValidCiteKey:[item citeKey]] == NO];
    } else {
        [itemTableView reloadData];
    }
}

- (void)finalizeChangesPreservingSelection:(BOOL)shouldPreserveSelection{
    NSResponder *firstResponder = [[self window] firstResponder];
    
	if([firstResponder isKindOfClass:[NSText class]]){
		NSText *textView = (NSText *)firstResponder;
		NSRange selection = [textView selectedRange];
        NSInteger editedRow = -1;
		id textDelegate = [textView delegate];
        if(textDelegate == itemTableView || textDelegate == citeKeyField){
            firstResponder = textDelegate;
            if(textDelegate == itemTableView)
                editedRow = [itemTableView editedRow];
            
            // now make sure we submit the edit
            if (NO == [[self window] makeFirstResponder:[self window]])
                [[self window] endEditingFor:nil];
            
            if(shouldPreserveSelection && [[self window] makeFirstResponder:firstResponder]){
                if(editedRow != -1)
                    [itemTableView editColumn:2 row:editedRow withEvent:nil select:YES];
                if([[textView string] length] < NSMaxRange(selection)) // check range for safety
                    selection = NSMakeRange([[textView string] length], 0);
                [textView setSelectedRange:selection];
            }
        }
	}
}

#pragma mark Setup

- (void)loadPasteboardData{
    NSPasteboard* pb = [NSPasteboard generalPasteboard];

    NSArray *typeArray = [NSArray arrayWithObjects:NSURLPboardType, NSRTFDPboardType, 
        NSRTFPboardType, NSStringPboardType, nil];
    
    NSString *pbType = [pb availableTypeFromArray:typeArray];    
    if([pbType isEqualToString:NSURLPboardType]){
        // setup webview and load page
        
		[self setShowingWebView:YES];
        
        NSArray *urls = (NSArray *)[pb propertyListForType:pbType];
        NSURL *url = [NSURL URLWithString:[urls objectAtIndex:0]];
        NSURLRequest *urlreq = [NSURLRequest requestWithURL:url];
        
        [[webView mainFrame] loadRequest:urlreq];
        
    }else{
		
		[self setShowingWebView:NO];
		
        NSString *pbString = nil;
        NSData *pbData;
        
		if([pbType isEqualToString:NSRTFPboardType]){
            pbData = [pb dataForType:pbType];
            pbString = [[[NSAttributedString alloc] initWithRTF:pbData
                                             documentAttributes:NULL] autorelease];
            pbString = [[(NSAttributedString *)pbString string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            if([pbString rangeOfString:@"http://"].location == 0){
                [self showWebViewWithURLString:pbString];
            }else{
                NSRange r = NSMakeRange(0,[[sourceTextView string] length]);
                [sourceTextView replaceCharactersInRange:r withRTF:pbData];
			}
            
		}else if([pbType isEqualToString:NSRTFDPboardType]){
            pbData = [pb dataForType:pbType];
            pbString = [[[NSAttributedString alloc] initWithRTFD:pbData
                                              documentAttributes:NULL] autorelease];
            pbString = [[(NSAttributedString *)pbString string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            if([pbString rangeOfString:@"http://"].location == 0){
                [self showWebViewWithURLString:pbString];
            }else{
                NSRange r = NSMakeRange(0,[[sourceTextView string] length]);
                [sourceTextView replaceCharactersInRange:r withRTFD:pbData];
            }
            
		}else if([pbType isEqualToString:NSStringPboardType]){
            pbData = [pb dataForType:pbType];
            pbString = [pb stringForType:pbType];
            pbString = [pbString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if([pbString rangeOfString:@"http://"].location == 0){
                [self showWebViewWithURLString:pbString];
            }else{
                [sourceTextView setString:pbString];
            }
		}else {
			
			[sourceTextView setString:NSLocalizedString(@"Sorry, BibDesk can't read this data type.", @"warning message when choosing \"new publication from pasteboard\" for an unsupported type")];
            return;
		}
        [self autoDiscoverDataFromString:[sourceTextView string]];
	}
}

- (void)showWebViewWithURLString:(NSString *)urlString{
    [self setShowingWebView:YES];
    NSURL *url = [NSURL URLWithString:[urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    NSURLRequest *urlreq = [NSURLRequest requestWithURL:url];
    
    [[webView mainFrame] loadRequest:urlreq];
        
}

- (void)setShowingWebView:(BOOL)showWebView{
	if (showWebView != showingWebView) {
		showingWebView = showWebView;
		if (showingWebView) {
			[webViewView setFrame:[sourceBox frame]];
			[splitView replaceSubview:sourceBox with:webViewView];
		} else {
			[splitView replaceSubview:webViewView with:sourceBox];
		}
	}
}

- (void)setupTypeUI{

    // setup the type popup:
    [itemTypeButton removeAllItems];
    [itemTypeButton addItemsWithTitles:[[BDSKTypeManager sharedManager] types]];
    
    NSString *type = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKPubTypeStringKey];
    
    [self setType:type];
    
    [itemTableView reloadData];
}

- (void)setType:(NSString *)type{
    
    [itemTypeButton selectItemWithTitle:type];
    [item setPubType:type];

    BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];

    [fields removeAllObjects];
    
    [fields addObjectsFromArray:[typeMan requiredFieldsForType:type]];
    [fields addObjectsFromArray:[typeMan optionalFieldsForType:type]];
	
	// the default fields can contain fields already contained in typeInfo
    [fields addNonDuplicateObjectsFromArray:[typeMan userDefaultFieldsForType:type]];
    [fields addNonDuplicateObjectsFromArray:[NSArray arrayWithObjects:BDSKAbstractString, BDSKAnnoteString, nil]];
}

#pragma mark Sheet callbacks

- (void)didEndSheet:(NSPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    // cleanup
    [self cancelDownload];
	[webView stopLoading:nil];
    [webView setFrameLoadDelegate:nil];
    [webView setUIDelegate:nil];
	// select the items we just added
	[document selectPublications:itemsAdded];
	[itemsAdded removeAllObjects];
    
    [super didEndSheet:sheet returnCode:returnCode contextInfo:contextInfo];
}

- (void)initialOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    // this is the initial file load, the main window is not yet there
    NSWindow *docWindow = [(NSWindow *)contextInfo autorelease];
    
    if (returnCode == NSOKButton) {
        NSString *fileName = [sheet filename];
        // first try to parse the file
        if([document addPublicationsFromFile:fileName verbose:NO error:NULL]){
            // succeeded to parse the file, we return immediately
            [self didEndSheet:sheet returnCode:returnCode contextInfo:NULL];
        }else{
            [sheet orderOut:nil];
            
            // show the main window
            [super beginSheetModalForWindow:docWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
            [self release];
            
            // then load the data from the file
            [self openPanelDidEnd:sheet returnCode:returnCode contextInfo:NULL];
        }
    } else {
        // the user cancelled. As we don't end the main sheet we have to call our didEndSelector ourselves
        [self didEndSheet:sheet returnCode:returnCode contextInfo:NULL];
    }
}
	
- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    if(returnCode == NSOKButton){
        NSURL *url = [[sheet URLs] lastObject];
		NSTextStorage *text = [sourceTextView textStorage];
		NSLayoutManager *layoutManager = [[text layoutManagers] objectAtIndex:0];

		[[text mutableString] setString:@""];	// Empty the document
		
		[self setShowingWebView:NO];
		
		[layoutManager retain];			// Temporarily remove layout manager so it doesn't do any work while loading
		[text removeLayoutManager:layoutManager];
		[text beginEditing];			// Bracket with begin/end editing for efficiency
		[text readFromURL:url options:nil documentAttributes:NULL];	// Read!
		[text endEditing];
		[text addLayoutManager:layoutManager];	// Hook layout manager back up
		[layoutManager release];
        
        [self autoDiscoverDataFromString:[text string]];

    }        
}

- (void)initialUrlSheetDidEnd:(NSPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    // this is the initial web load, the main window is not yet there
    NSWindow *docWindow = [(NSWindow *)contextInfo autorelease];
    
    if (returnCode == NSOKButton) {
        [sheet orderOut:nil];
        
        // show the main window
        [super beginSheetModalForWindow:docWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
        [self release];
        
        // then load the data from the file
        [self urlSheetDidEnd:sheet returnCode:returnCode contextInfo:NULL];
        
    } else {
        // the user cancelled. As we don't end the main sheet we have to call our didEndSelector ourselves
        [self didEndSheet:sheet returnCode:returnCode contextInfo:NULL];
    }
}

- (void)urlSheetDidEnd:(NSPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    if(returnCode == NSOKButton){
		// setup webview and load page
        
		[self setShowingWebView:YES];
        
        NSString *urlString = [urlTextField stringValue];
        
        NSURL *url = [NSURL URLWithString:urlString];
        
        if(url == nil){
            [sheet orderOut:nil];
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error", @"Message in alert dialog when error occurs")
                                             defaultButton:nil
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"Mac OS X does not recognize this as a valid URL.  Please re-enter the address and try again.", @"Informative text in alert dialog")];
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
        } else {        
            NSURLRequest *urlreq = [NSURLRequest requestWithURL:url];
            [[webView mainFrame] loadRequest:urlreq];
        }
    }        
}

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    
	if (returnCode == NSOKButton) {
		if ([[[[webView mainFrame] dataSource] data] writeToFile:[sheet filename] atomically:YES]) {
			NSURL *fileURL = [NSURL fileURLWithPath:[sheet filename]];
			
            [item addFileForURL:fileURL autoFile:YES runScriptHook:NO];
            [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
		} else {
			NSLog(@"Could not write downloaded file.");
		}
    }

    [itemTableView reloadData];
}

#pragma mark Page loading methods

- (void)setLoading:(BOOL)loading{
    if (isLoading != loading) {
        isLoading = loading;
        if (isLoading) {
			NSString *message = [NSLocalizedString(@"Loading page", @"Tool tip message") stringByAppendingEllipsis];
			[progressIndicator setToolTip:message];
			[statusLine setStringValue:@""];
			[stopOrReloadButton setImage:[NSImage imageNamed:NSImageNameStopProgressTemplate]];
			[stopOrReloadButton setToolTip:NSLocalizedString(@"Stop loading page", @"Tool tip message")];
			[stopOrReloadButton setKeyEquivalent:@""];
			[progressIndicator startAnimation:self];
			[progressIndicator setToolTip:message];
			[statusLine setStringValue:message];
		} else {
			[stopOrReloadButton setImage:[NSImage imageNamed:NSImageNameRefreshTemplate]];
			[stopOrReloadButton setToolTip:NSLocalizedString(@"Reload page", @"Tool tip message")];
			[stopOrReloadButton setKeyEquivalent:@"r"];
			[progressIndicator stopAnimation:self];
			[progressIndicator setToolTip:@""];
			[statusLine setStringValue:@""];
		}
	}
}

#pragma mark Download methods

- (void)cancelDownload{
	[download cancel];
	[self setDownloading:NO];
}

- (void)setLocalUrlFromDownload{
	NSURL *fileURL = [NSURL fileURLWithPath:downloadFileName];
	
    [item addFileForURL:fileURL autoFile:YES runScriptHook:NO];
    [[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
}

- (void)setDownloading:(BOOL)downloading{
    if (isDownloading != downloading) {
        isDownloading = downloading;
        if (isDownloading) {
			NSString *message = [[NSString stringWithFormat:NSLocalizedString(@"Downloading file. Received %ld%%", @"Tool tip message"), (long)0] stringByAppendingEllipsis];
			[progressIndicator setToolTip:message];
			[statusLine setStringValue:@""];
			[stopOrReloadButton setImage:[NSImage imageNamed:NSImageNameStopProgressTemplate]];
			[stopOrReloadButton setToolTip:NSLocalizedString(@"Cancel download", @"Tool tip message")];
			[stopOrReloadButton setKeyEquivalent:@""];
            [progressIndicator startAnimation:self];
			[progressIndicator setToolTip:message];
			[statusLine setStringValue:message];
            [downloadFileName release];
			downloadFileName = nil;
        } else {
			[stopOrReloadButton setImage:[NSImage imageNamed:NSImageNameRefreshTemplate]];
			[stopOrReloadButton setToolTip:NSLocalizedString(@"Reload page", @"Tool tip message")];
			[stopOrReloadButton setKeyEquivalent:@"r"];
            [progressIndicator stopAnimation:self];
			[progressIndicator setToolTip:@""];
			[statusLine setStringValue:@""];
            [download release];
            download = nil;
            receivedContentLength = 0;
        }
    }
}

#pragma mark Menu validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem{
	if ([menuItem action] == @selector(saveFileAsLocalUrl:)) {
		return ![[[webView mainFrame] dataSource] isLoading];
	} else if ([menuItem action] == @selector(importFromPasteboardAction:)) {
		[menuItem setTitle:NSLocalizedString(@"Load Clipboard", @"Menu item title")];
		return YES;
	} else if ([menuItem action] == @selector(importFromFileAction:)) {
		[menuItem setTitle:[NSLocalizedString(@"Load File", @"Menu item title") stringByAppendingEllipsis]];
		return YES;
	} else if ([menuItem action] == @selector(importFromWebAction:)) {
		[menuItem setTitle:[NSLocalizedString(@"Load Website", @"Menu item title") stringByAppendingEllipsis]];
		return YES;
	} else if ([menuItem action] == @selector(editSelectedFieldAsRawBibTeX:)) {
		NSInteger row = [itemTableView selectedRow];
		return (row != -1 && [complexStringEditor isEditing] == NO && [[fields objectAtIndex:row] isEqualToString:BDSKCrossrefString] == NO && [[fields objectAtIndex:row] isCitationField] == NO);
	} else if ([menuItem action] == @selector(generateCiteKey:)) {
		// need to set the title, as the document can change it in the main menu
		[menuItem setTitle: NSLocalizedString(@"Generate Cite Key", @"Menu item title")];
		return YES;
	} else if ([menuItem action] == @selector(consolidateLinkedFiles:)) {
		[menuItem setTitle: NSLocalizedString(@"AutoFile Linked File", @"Menu item title")];
        return [[item localFiles] count] > 0;
	}
	return YES;
}

#pragma mark WebUIDelegate methods

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems{
	NSMutableArray *menuItems = [NSMutableArray arrayWithCapacity:6];
	NSMenuItem *menuItem;
	
	for (menuItem in defaultMenuItems) { 
		if ([menuItem tag] == WebMenuItemTagCopy) {
			// copy text items
			if ([menuItems count] > 0)
				[menuItems addObject:[NSMenuItem separatorItem]];
			
			[menuItems addObject:menuItem];
		}
		if ([menuItem tag] == WebMenuItemTagCopyLinkToClipboard) {
			NSURL *linkURL = [element objectForKey:WebElementLinkURLKey];
			// copy link items
			if ([menuItems count] > 0)
				[menuItems addObject:[NSMenuItem separatorItem]];
			
			[menuItems addObject:menuItem];
			
			menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Copy Link To Url Field",@"Copy link to url field")
											  action:@selector(copyLinkedLocationAsRemoteUrl:)
									   keyEquivalent:@""];
			[menuItem setTarget:self];
			[menuItem setRepresentedObject:linkURL];
			[menuItems addObject:[menuItem autorelease]];
			
			menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Save Link As Local File",@"Save link as local file") stringByAppendingEllipsis]
											  action:@selector(downloadLinkedFileAsLocalUrl:)
									   keyEquivalent:@""];
			[menuItem setTarget:self];
			[menuItem setRepresentedObject:linkURL];
			[menuItems addObject:[menuItem autorelease]];
			
			menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Bookmark Link",@"Bookmark linked page") stringByAppendingEllipsis]
											  action:@selector(bookmarkLink:)
									   keyEquivalent:@""];
			[menuItem setTarget:self];
			[menuItem setRepresentedObject:element];
			[menuItems addObject:[menuItem autorelease]];
		}
	}
	
	// current location items
	if ([menuItems count] > 0) 
		[menuItems addObject:[NSMenuItem separatorItem]];
		
	menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Copy Page Location To Url Field", @"Menu item title")
									  action:@selector(copyLocationAsRemoteUrl:)
							   keyEquivalent:@""];
	[menuItem setTarget:self];
	[menuItems addObject:[menuItem autorelease]];
	
	menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Save Page As Local File", @"Menu item title") stringByAppendingEllipsis]
									  action:@selector(saveFileAsLocalUrl:)
							   keyEquivalent:@""];
	[menuItem setTarget:self];
	[menuItems addObject:[menuItem autorelease]];
	
	menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Bookmark This Page", @"Menu item title") stringByAppendingEllipsis]
									  action:@selector(addBookmark:)
							   keyEquivalent:@""];
	[menuItem setTarget:webView];
	[menuItems addObject:[menuItem autorelease]];
	
	// navigation items
	[menuItems addObject:[NSMenuItem separatorItem]];
	
	menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Back", @"Menu item title")
									  action:@selector(goBack:)
							   keyEquivalent:@"["];
	[menuItems addObject:[menuItem autorelease]];
	
	menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Forward", @"Menu item title")
									  action:@selector(goForward:)
							   keyEquivalent:@"]"];
	[menuItems addObject:[menuItem autorelease]];
	
	menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Reload", @"Menu item title")
									  action:@selector(reload:)
							   keyEquivalent:@"r"];
	[menuItems addObject:[menuItem autorelease]];
	
	menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Stop", @"Menu item title")
									  action:@selector(stopLoading:)
							   keyEquivalent:@""];
	[menuItems addObject:[menuItem autorelease]];
	
	// text size items
	[menuItems addObject:[NSMenuItem separatorItem]];
	
	menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Increase Text Size", @"Menu item title")
									  action:@selector(makeTextLarger:)
							   keyEquivalent:@""];
	[menuItems addObject:[menuItem autorelease]];
	
	menuItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Decrease Text Size", @"Menu item title")
									  action:@selector(makeTextSmaller:)
							   keyEquivalent:@""];
	[menuItems addObject:[menuItem autorelease]];
	
	return menuItems;
}

- (void)webView:(WebView *)sender setStatusText:(NSString *)text {
    [statusLine setStringValue:text];
}

- (void)webView:(WebView *)sender mouseDidMoveOverElement:(NSDictionary *)elementInformation modifierFlags:(NSUInteger)modifierFlags {
    NSURL *aLink = [elementInformation objectForKey:WebElementLinkURLKey];
    [statusLine setStringValue:aLink ? [aLink absoluteString] : @""];
}

#pragma mark WebEditingDelegate methods

// workaround for webview bug, which looses its selection when the focus changes to another view
- (void)webViewDidChangeSelection:(NSNotification *)notification{
	NSString *selString = [[[notification object] selectedDOMRange] toString];
	if ([NSString isEmptyString:selString] || selString == webSelection)
		return;
	[webSelection release];
	webSelection = [[selString stringByCollapsingAndTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
}

#pragma mark WebFrameLoadDelegate methods

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame{
	[self setLoading:YES];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame{
	[self setLoading:NO];
	[backButton setEnabled:[sender canGoBack]];
	[forwardButton setEnabled:[sender canGoForward]];

    [self autoDiscoverDataFromFrame:frame];
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame{
	[self setLoading:NO];
	
	if ([error code] == NSURLErrorCancelled) {// don't warn when the user cancels
		return;
	}
	
    NSString *errorDescription = [error localizedDescription];
    if (!errorDescription) {
        errorDescription = NSLocalizedString(@"An error occured during page load.", @"Informative text in alert dialog");
    }
    
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Page Load Failed", @"Message in alert dialog when web page did not load")
                                     defaultButton:nil
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@"%@", errorDescription];
    [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame{
	[self setLoading:NO];
	
	if ([error code] == NSURLErrorCancelled) {// don't warn when the user cancels
		return;
	}
	
    NSString *errorDescription = [error localizedDescription];
    if (!errorDescription) {
        errorDescription = NSLocalizedString(@"An error occured during page load.", @"Informative text in alert dialog");
    }
    
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Page Load Failed", @"Message in alert dialog when web page did not load")
                                     defaultButton:nil
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@"%@", errorDescription];
    [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

#pragma mark NSURLDownloadDelegate methods

- (void)downloadDidBegin:(NSURLDownload *)download{
    [self setDownloading:YES];
}

- (NSWindow *)downloadWindowForAuthenticationSheet:(WebDownload *)download{
    return [self window];
}

- (void)download:(NSURLDownload *)theDownload didReceiveResponse:(NSURLResponse *)response{
    expectedContentLength = [response expectedContentLength];

    if (expectedContentLength > 0) {
    }
}

- (void)download:(NSURLDownload *)theDownload decideDestinationWithSuggestedFilename:(NSString *)filename{
	NSString *extension = [filename pathExtension];
   
	NSSavePanel *sPanel = [NSSavePanel savePanel];
    if (NO == [extension isEqualToString:@""]) 
		[sPanel setRequiredFileType:extension];
    [sPanel setAllowsOtherFileTypes:YES];
    [sPanel setCanSelectHiddenExtension:YES];
	
    // we need to do this modally, not using a sheet, as the download may otherwise finish on Leopard before the sheet is done
    NSInteger returnCode = [sPanel runModalForDirectory:nil file:filename];
    if (returnCode == NSOKButton) {
        [download setDestination:[sPanel filename] allowOverwrite:YES];
    } else {
        [self cancelDownload];
    }
}

- (void)download:(NSURLDownload *)theDownload didReceiveDataOfLength:(NSUInteger)length{
    if (expectedContentLength > 0) {
        receivedContentLength += length;
        NSInteger percent = round(100.0 * (double)receivedContentLength / (double)expectedContentLength);
		NSString *message = [[NSString stringWithFormat:NSLocalizedString(@"Downloading file. Received %ld%%", @"Tool tip message"), (long)percent] stringByAppendingEllipsis];
		[progressIndicator setToolTip:message];
		[statusLine setStringValue:message];
    }
}

- (BOOL)download:(NSURLDownload *)download shouldDecodeSourceDataOfMIMEType:(NSString *)encodingType;{
    return YES;
}

- (void)download:(NSURLDownload *)download didCreateDestination:(NSString *)path{
    [downloadFileName release];
	downloadFileName = [path copy];
}

- (void)downloadDidFinish:(NSURLDownload *)theDownload{
    [self setDownloading:NO];
	
	[self setLocalUrlFromDownload];
}

- (void)download:(NSURLDownload *)theDownload didFailWithError:(NSError *)error
{
    [self setDownloading:NO];
        
    NSString *errorDescription = [error localizedDescription];
    if (!errorDescription) {
        errorDescription = NSLocalizedString(@"An error occured during download.", @"Informative text in alert dialog");
    }
    
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Download Failed", @"Message in alert dialog when download failed")
                                     defaultButton:nil
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@"%@", errorDescription];
    [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

#pragma mark Editing

- (BOOL)addCurrentSelectionToFieldAtIndex:(NSUInteger)idx{
    if ([fields count] <= idx)
        return NO;
    
    NSString *selKey = [fields objectAtIndex:idx];
    NSString *selString = nil;

    if(showingWebView){
		selString = webSelection;
        //NSLog(@"selstr %@", selString);
    }else{
        NSRange selRange = [sourceTextView selectedRange];
        NSLayoutManager *layoutManager = [sourceTextView layoutManager];
        NSColor *foregroundColor = [NSColor lightGrayColor]; 
        NSDictionary *highlightAttrs = [NSDictionary dictionaryWithObjectsAndKeys: foregroundColor, NSForegroundColorAttributeName, nil];

        selString = [[sourceTextView string] substringWithRange:selRange];
        [layoutManager addTemporaryAttributes:highlightAttrs
                            forCharacterRange:selRange];
    }
	if ([NSString isEmptyString:selString])
		return NO;
	
    NSString *oldValue = [item valueOfField:selKey];
    
    if(([NSEvent standardModifierFlags] & NSControlKeyMask) != 0 && 
       [NSString isEmptyString:oldValue] == NO && 
       [selKey isSingleValuedField] == NO){
        
        NSString *separator;
        if([selKey isPersonField])
            separator = @" and ";
        else
            separator = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKDefaultGroupFieldSeparatorKey];
        selString = [NSString stringWithFormat:@"%@%@%@", oldValue, separator, selString];
    }
    
    // convert newlines to a single space, then collapse (RFE #1480354)
    if ([selKey isNoteField] == NO && [selString rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].length) {
        selString = [selString stringByReplacingCharactersInSet:[NSCharacterSet newlineCharacterSet] withString:@" "];
        selString = [selString stringByCollapsingAndTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    
    [self recordChangingField:selKey toValue:selString];
    return YES;
}

- (NSRange)control:(NSControl *)control textView:(NSTextView *)textView rangeForUserCompletion:(NSRange)charRange {
    if (control != itemTableView) {
		return charRange;
	} else if ([complexStringEditor isEditing]) {
		return [[BDSKCompletionManager sharedManager] rangeForUserCompletion:charRange 
								  forBibTeXString:[textView string]];
	} else {
		return [[BDSKCompletionManager sharedManager] entry:[fields objectAtIndex:[itemTableView selectedRow]] 
				rangeForUserCompletion:charRange 
							  ofString:[textView string]];

	}
}

- (NSArray *)control:(NSControl *)control textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)idx{
    if (control != itemTableView) {
		return words;
	} else if ([complexStringEditor isEditing]) {
		return [[BDSKCompletionManager sharedManager] possibleMatches:[[document macroResolver] allMacroDefinitions] 
						   forBibTeXString:[textView string] 
								partialWordRange:charRange 
								indexOfBestMatch:idx];
	} else {
		return [[BDSKCompletionManager sharedManager] entry:[fields objectAtIndex:[itemTableView selectedRow]] 
						   completions:words 
				   forPartialWordRange:charRange 
							  ofString:[textView string] 
				   indexOfSelectedItem:idx];
	}
}

- (BOOL)control:(NSControl *)control textViewShouldAutoComplete:(NSTextView *)textview {
    if (control == itemTableView)
		return [[NSUserDefaults standardUserDefaults] boolForKey:BDSKEditorFormShouldAutoCompleteKey];
	return NO;
}

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject {
	if (anObject != itemTableView)
		return nil;
	if (tableFieldEditor == nil) {
		tableFieldEditor = [[BDSKFieldEditor alloc] init];
	}
	return tableFieldEditor;
}

#pragma mark Macro editing

- (BOOL)editSelectedCellAsMacro{
	NSInteger row = [itemTableView selectedRow];
    // this should never happen
	if ([complexStringEditor isEditing] || row == -1 || [[fields objectAtIndex:row] isEqualToString:BDSKCrossrefString] || [[fields objectAtIndex:row] isCitationField]) 
		return NO;
	if (complexStringEditor == nil)
    	complexStringEditor = [[BDSKComplexStringEditor alloc] initWithMacroResolver:[self macroResolver]];
    NSString *value = [item valueOfField:[fields objectAtIndex:row]];
	NSText *fieldEditor = [itemTableView currentEditor];
	[tableCellFormatter setEditAsComplexString:YES];
	if (fieldEditor) {
		[fieldEditor setString:[tableCellFormatter editingStringForObjectValue:value]];
		[fieldEditor selectAll:self];
	}
    [complexStringEditor attachToTableView:itemTableView atRow:row column:2 withValue:value];
    return YES;
}

#pragma mark BDSKMacroFormatter delegate

- (BOOL)formatter:(BDSKComplexStringFormatter *)formatter shouldEditAsComplexString:(NSString *)object {
    return [self editSelectedCellAsMacro];
}

#pragma mark BDSKCitationFormatter and BDSKTextImportItemTableView delegate

- (BOOL)citationFormatter:(BDSKCitationFormatter *)formatter isValidKey:(NSString *)key {
    return [[self publications] itemForCiteKey:key] != nil;
}

- (BOOL)control:(NSControl *)control textViewShouldLinkKeys:(NSTextView *)textView {
    NSInteger row = [itemTableView editedRow];
    return control == itemTableView && row != -1 && [[fields objectAtIndex:row] isCitationField];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView isValidKey:(NSString *)key {
    return control == itemTableView && [[self publications] itemForCiteKey:key] != nil;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)aTextView clickedOnLink:(id)aLink atIndex:(NSUInteger)charIndex {
    // we don't open the linked item from the text import sheet
    return NO;
}

#pragma mark NSControl text delegate

// @@ should we do some more error chacking for valid entries and cite keys, as well as showing warnings for formatter errors?

- (void)controlTextDidEndEditing:(NSNotification *)aNotification {
	if([[aNotification object] isEqual:itemTableView]){
		[tableCellFormatter setEditAsComplexString:NO];
	}else if([[aNotification object] isEqual:citeKeyField]){
        [item setCiteKey:[citeKeyField stringValue]];
        [[item undoManager] setActionName:NSLocalizedString(@"Edit Cite Key", @"Undo action name")];
        [self setCiteKeyDuplicateWarning:[item isValidCiteKey:[item citeKey]] == NO];
    }
}

#pragma mark Setting a field

- (void)recordChangingField:(NSString *)fieldName toValue:(NSString *)value{
    [item setField:fieldName toValue:value];
	[[self undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
    if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKCiteKeyAutogenerateKey] &&
       [item canGenerateAndSetCiteKey]){
        [self generateCiteKey:nil];
        if ([item hasEmptyOrDefaultCiteKey] == NO)
            [statusLine setStringValue:NSLocalizedString(@"Autogenerated Cite Key.", @"Status message")];
    }
    [itemTableView reloadData];
}

// we don't use the one from the item befcause it doesn't know about the document yet
- (BOOL)autoFileLinkedFile:(BDSKLinkedFile *)file
{
    // we can't autofile if it's disabled or there is nothing to file
	if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKFilePapersAutomaticallyKey] == NO || [file URL] == nil)
		return NO;
	
	if ([item canSetURLForLinkedFile:file]) {
        [[BDSKFiler sharedFiler] filePapers:[NSArray arrayWithObject:file] fromDocument:document check:NO]; 
        return YES;
	} else {
		[item addFileToBeFiled:file];
	}
	return NO;
}

#pragma mark Cite key duplicate warning

- (void)setCiteKeyDuplicateWarning:(BOOL)set{
    [citeKeyWarningButton setToolTip:set ? NSLocalizedString(@"This cite-key is a duplicate", @"Tool tip message") : nil];
	[citeKeyWarningButton setHidden:set == NO];
	[citeKeyField setTextColor:(set ? [NSColor redColor] : [NSColor blackColor])];
}

#pragma mark TableView Data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView{
    return [fields count]; 
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    NSString *key = [fields objectAtIndex:row];
    NSString *tcID = [tableColumn identifier];
    
    if([tcID isEqualToString:@"FieldName"]){
        return [key localizedFieldName];
    }else if([tcID isEqualToString:@"Num"]){
        if(row < 10)
            return [NSString stringWithFormat:@"%@%ld", [NSString commandKeyIndicatorString], (long)((row + 1) % 10)];
        else if(row < 20)
            return [NSString stringWithFormat:@"%@%@%ld", [NSString alternateKeyIndicatorString], [NSString commandKeyIndicatorString], (long)((row + 1) % 10)];
        else return @"";
    }else{
        return [item valueOfField:key];
    }
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
	NSString *tcID = [tableColumn identifier];
    if([tcID isEqualToString:@"FieldName"] ||
       [tcID isEqualToString:@"Num"] ){
        return; // don't edit the first 2 columns. Shouldn't happen anyway.
    }
    
    NSString *key = [fields objectAtIndex:row];
	if ([object isEqualAsComplexString:[item valueOfField:key]])
		return;
	
	[self recordChangingField:key toValue:object];
}

// This method is used by NSTableView to determine a valid drop target.  Based on the mouse position, the table view will suggest a proposed drop location.  This method must return a value that indicates which dragging operation the data source will perform.  The data source may "re-target" a drop if desired by calling setDropRow:dropOperation: and returning something other than NSDragOperationNone.  One may choose to re-target for various reasons (eg. for better visual feedback when inserting into a sorted position).
- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op{
    if(op ==  NSTableViewDropOn)
        return NSDragOperationCopy;
    else return NSDragOperationNone;
}

// This method is called when the mouse is released over a table view that previously decided to allow a drop via the validateDrop method.  The data source should incorporate the data from the dragging pasteboard at this time.
- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op{
    NSPasteboard *pb = [info draggingPasteboard];
    NSString *pbType = [pb availableTypeFromArray:[NSArray arrayWithObjects:NSStringPboardType, nil]];
    if ([NSStringPboardType isEqualToString:pbType]){

        NSString *value = [pb stringForType:NSStringPboardType];
        NSString *key = [fields objectAtIndex:row];
        NSString *oldValue = [item valueOfField:key];
        
        if(([NSEvent standardModifierFlags] & NSControlKeyMask) != 0 && 
           [NSString isEmptyString:oldValue] == NO && 
           [key isSingleValuedField] == NO){
            
            NSString *separator;
            if([key isPersonField])
                separator = @" and ";
            else
                separator = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKDefaultGroupFieldSeparatorKey];
            value = [NSString stringWithFormat:@"%@%@%@", oldValue, separator, value];
        }
        
        [self recordChangingField:key toValue:value];
    }
    return YES;
}

- (void)tableView:(NSTableView *)tv pasteFromPasteboard:(NSPasteboard *)pboard{
	NSInteger idx = [tv selectedRow];
	NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]];
	
	if (type && idx != -1) {
        NSString *selKey = [fields objectAtIndex:idx];
        NSString *string = [pboard stringForType:NSStringPboardType];
        NSString *oldValue = [item valueOfField:selKey];
        
        if(([NSEvent standardModifierFlags] & NSControlKeyMask) != 0 && 
           [NSString isEmptyString:oldValue] == NO && 
           [selKey isSingleValuedField] == NO){
            
            NSString *separator;
            if([selKey isPersonField])
                separator = @" and ";
            else
                separator = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKDefaultGroupFieldSeparatorKey];
            string = [NSString stringWithFormat:@"%@%@%@", oldValue, separator, string];
        }
        
        [self recordChangingField:selKey toValue:string];
    }
}

- (void)tableView:(NSTableView *)tv deleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
    if([rowIndexes count]){
        NSString *field = [fields objectAtIndex:[rowIndexes firstIndex]];
        [self recordChangingField:field toValue:@""];
    }
}

#pragma mark TableView delegate methods

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    if([[tableColumn identifier] isEqualToString:@"FieldValue"])
        return YES;
	return NO;
}

- (void)tableView:(NSTableView *)tv willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
	if([[tableColumn identifier] isEqualToString:@"FieldValue"]){
		NSString *field = [fields objectAtIndex:row];
		NSFormatter *formatter;
		if ([field isEqualToString:BDSKCrossrefString]) {
			formatter = crossrefFormatter;
		} else if ([field isCitationField]) {
			formatter = citationFormatter;
		} else {
			formatter = tableCellFormatter;
		}
		[cell setFormatter:formatter];
	}
}

#pragma mark || Methods to support the type-select selector.

- (void)tableView:(NSTableView *)tv typeSelectHelper:(BDSKTypeSelectHelper *)typeSelectHelper updateSearchString:(NSString *)searchString{
    if (searchString)
        [statusLine setStringValue:[NSString stringWithFormat:@"%@ \"%@\"", NSLocalizedString(@"Finding field:", @"Status message"), [searchString fieldName]]];
    else if ([(BDSKTextImportItemTableView *)tv isInTemporaryTypeSelectMode])
        [statusLine setStringValue:NSLocalizedString(@"Press Enter to set or Tab to cancel.", @"Status message")];
    else
        [statusLine setStringValue:@""];
}

- (void)tableView:(NSTableView *)tv typeSelectHelper:(BDSKTypeSelectHelper *)typeSelectHelper didFailToFindMatchForSearchString:(NSString *)searchString{
    [statusLine setStringValue:[NSString stringWithFormat:@"%@ \"%@\"", NSLocalizedString(@"No field:", @"Status message"), [searchString fieldName]]];
}

- (NSArray *)tableView:(NSTableView *)tv typeSelectHelperSelectionItems:(BDSKTypeSelectHelper *)typeSelectHelper{
    return fields;
}

- (void)tableViewDidChangeTemporaryTypeSelectMode:(NSTableView *)tv {
    if ([(BDSKTextImportItemTableView *)tv isInTemporaryTypeSelectMode])
        [statusLine setStringValue:NSLocalizedString(@"Start typing to select a field. Press Enter to set or Tab to cancel.", @"Status message")];
    else
        [statusLine setStringValue:@""];
}

- (BOOL)tableView:(NSTableView *)tView performActionForRow:(NSInteger)row {
    if (row != -1)
        return [self addCurrentSelectionToFieldAtIndex:row];
    return NO;
}

#pragma mark Splitview delegate methods

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset{
	return proposedMin + 126; // from IB
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset{
	return proposedMax - 200.0;
}

#pragma mark Auto-Discovery methods

- (void)autoDiscoverDataFromFrame:(WebFrame *)frame{
    
    WebDataSource *dataSource = [frame dataSource];
    NSString *MIMEType = [[dataSource mainResource] MIMEType];
    
    if ([MIMEType isEqualToString:@"text/plain"]) { 
        // @@ should we also try other MIME types, such as text/richtext?
        
        NSString *string = [[dataSource representation] documentSource];
        
        if(string == nil) {
            NSString *encodingName = [dataSource textEncodingName];
            CFStringEncoding cfEncoding = kCFStringEncodingInvalidId;
            NSStringEncoding nsEncoding = NSUTF8StringEncoding;
            
            if (encodingName != nil)
                cfEncoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)encodingName);
            if (cfEncoding != kCFStringEncodingInvalidId)
                nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
            string = [[[NSString alloc] initWithData:[dataSource data] encoding:nsEncoding] autorelease];
        }
        
        if (string != nil) 
            [self autoDiscoverDataFromString:string];
        
    } else if ([MIMEType isEqualToString:@"text/html"] || [MIMEType isEqualToString:@"text/xhtml+xml"]) {
            
        // This only reads Dublin Core for now.
        // In the future, we should handle other HTML encodings like a nascent microformat.
        // perhaps then a separate HTML parser would be useful to keep this file small.
        
        DOMDocument *domDoc = [frame DOMDocument];
        
        DOMNodeList *headList = [domDoc getElementsByTagName:@"head"];
        if([headList length] != 1) return;
        DOMNode *headNode = [headList item:0];
        DOMNodeList *headChildren = [headNode childNodes];
        NSUInteger i = 0;
        NSUInteger length = [headChildren length];
        NSMutableDictionary *metaTagDict = [[NSMutableDictionary alloc] initWithCapacity:length];    
        
        
        for (i = 0; i < length; i++) {
            DOMNode *node = [headChildren item:i];
            DOMNamedNodeMap *attributes = [node attributes];
            NSInteger typeIndex = 0;
            
            NSString *nodeName = [node nodeName];
            if([nodeName isEqualToString:@"META"]){
                
                NSString *metaName = [[attributes getNamedItem:@"name"] nodeValue];
                NSString *metaVal = [[attributes getNamedItem:@"content"] nodeValue];
                
                if(metaVal == nil) continue;

                // Catch repeated DC.creator or contributor and append them: 
                if([metaName isEqualToString:@"DC.creator"] ||
                   [metaName isEqualToString:@"DC.contributor"]){
                    NSString *currentVal = [metaTagDict objectForKey:metaName];
                    if(currentVal != nil){
                        metaVal = [NSString stringWithFormat:@"%@ and %@", currentVal, metaVal];
                    }
                }
                
                // Catch repeated DC.type and store them separately:
                if([metaName isEqualToString:@"DC.type"]){
                    NSString *currentVal = [metaTagDict objectForKey:metaName];
                    if(currentVal != nil){
                        metaName = [NSString stringWithFormat:@"DC.type.%ld", (long)++typeIndex];
                    }
                }
                
                if(metaVal && metaName)
                    [metaTagDict setObject:metaVal
                                    forKey:metaName];

                
            }else if([nodeName isEqualToString:@"LINK"]){
                // it might be the link rel="alternate" class="fulltext"
                NSString *classVal = [[attributes getNamedItem:@"class"] nodeValue];
                NSString *relVal = [[attributes getNamedItem:@"rel"] nodeValue];
                
                if( [classVal isEqualToString:@"fulltext"] &&
                    [relVal isEqualToString:@"alternate"]){
                    DOMNode *hrefAttr = [attributes getNamedItem:@"href"];
                    if(hrefAttr)
                        [metaTagDict setObject:[hrefAttr nodeValue]
                                        forKey:BDSKUrlString];
                }
            }
        }// for child of HEAD
        
        if([metaTagDict count]){
            if([item hasBeenEdited]){
                NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Autofill bibliography information", @"Message in alert dialog when trying to auto-fill information in text import") 
                                                 defaultButton:NSLocalizedString(@"Yes", @"Button title")
                                               alternateButton:NSLocalizedString(@"No", @"Button title")
                                                   otherButton:nil
                                     informativeTextWithFormat:NSLocalizedString(@"Do you want me to autofill information from Dublin Core META tags? This may overwrite fields that are already set.", @"Informative text in alert dialog")];
                [alert beginSheetModalForWindow:[self window]
                                  modalDelegate:self
                                 didEndSelector:@selector(autoDiscoverFromFrameAlertDidEnd:returnCode:contextInfo:)
                                    contextInfo:metaTagDict];
            }else{
                [self autoDiscoverFromFrameAlertDidEnd:nil returnCode:NSAlertDefaultReturn contextInfo:metaTagDict];
            }
        }else{
            [metaTagDict release];
        }
    }
}

- (void)autoDiscoverFromFrameAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    NSDictionary *metaTagDict = [(NSDictionary *)contextInfo autorelease];
    BDSKTypeManager *typeMan = [BDSKTypeManager sharedManager];
    
    if(returnCode == NSAlertAlternateReturn)
        return;
    
    for (NSString *metaName in metaTagDict) {
        NSString *fieldName = [typeMan fieldNameForDublinCoreTerm:metaName];
        fieldName = (fieldName ?: [metaName fieldName]);
        NSString *fieldValue = [metaTagDict objectForKey:metaName];
        
        // Special-case DC.date to get month and year, but still insert "DC.date"
        //  to capture the day, which may be useful.
        if([fieldName isEqualToString:@"Date"]){
            NSCalendarDate *date = [NSCalendarDate dateWithString:fieldValue
                                                   calendarFormat:@"%Y-%m-%d"];
            [item setField:BDSKYearString
                   toValue:[date descriptionWithCalendarFormat:@"%Y"]];
            [item setField:BDSKMonthString
                   toValue:[date descriptionWithCalendarFormat:@"%m"]];
            // fieldName is "Date" here, don't just insert that.
            // we use "Date" to generate a nice table column, and we shouldn't override that.
            [item setField:@"DC.date"
                   toValue:fieldValue];
        }else if([fieldName isEqualToString:BDSKAuthorString]){
            // DC.creator and DC.contributor both map to Author, so append them in the appropriate order
            NSString *currentVal = [item valueOfField:BDSKAuthorString];
            if(currentVal != nil){
                if([metaName isEqualToString:@"DC.creator"])
                    [item setField:fieldName
                           toValue:[NSString stringWithFormat:@"%@ and %@", fieldValue, currentVal]];
                else
                    [item setField:fieldName
                           toValue:[NSString stringWithFormat:@"%@ and %@", currentVal, fieldValue]];
            }
        }else{
            [item setField:fieldName
                   toValue:fieldValue];
        }

    }

    NSString *bibtexType = [typeMan bibTeXTypeForDublinCoreType:[metaTagDict objectForKey:@"DC.type"]];
    [self setType:(bibtexType ?: @"misc")];

    [itemTableView reloadData];
}

- (void)autoDiscoverDataFromString:(NSString *)string{
    NSInteger type = [string contentStringType];
    
    if(type == BDSKUnknownStringType)
        return;
		
    NSError *error = nil;
    NSArray *pubs = [document publicationsForString:string type:type verbose:NO error:&error];
    
    // ignore warnings for parsing with temporary citekeys, as we're not interested in the cite key
    if ([[error userInfo] valueForKey:@"temporaryCiteKey"] != nil)
        error = nil;
    
    if(error || [pubs count] == 0)
        return;
    
    if([item hasBeenEdited]){
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Autofill bibliography information", @"Message in alert dialog when trying to auto-fill information in text import") 
                                         defaultButton:NSLocalizedString(@"Yes", @"Button title")
                                       alternateButton:NSLocalizedString(@"No", @"Button title")
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"Do you want me to autofill information from the text? This may overwrite fields that are already set.", @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:self
                         didEndSelector:@selector(autoDiscoverFromStringAlertDidEnd:returnCode:contextInfo:)
                            contextInfo:[[pubs objectAtIndex:0] retain]];
    }else{
        [self autoDiscoverFromStringAlertDidEnd:nil returnCode:NSAlertDefaultReturn contextInfo:[[pubs objectAtIndex:0] retain]];
    }
}

- (void)autoDiscoverFromStringAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    BibItem *pub = [(BibItem *)contextInfo autorelease];
    
    if(returnCode == NSAlertDefaultReturn){
        [item setPubType:[pub pubType]];
        [item setFields:[pub pubFields]];
        
        [itemTableView reloadData];
    }
}

@end

#pragma mark -

@implementation BDSKTextImportItemTableView

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent{
    
    unichar c = [theEvent firstCharacter];
    NSUInteger flags = [theEvent modifierFlags];
    
    if (flags & NSCommandKeyMask) {
        
        if (c >= '0' && c <= '9') {
        
            NSUInteger idx = c == '0' ? 9 : (NSUInteger)(c - '1');
            if (flags & NSAlternateKeyMask)
                idx += 10;
            BOOL rv = [self performActionForRow:idx];
            if (temporaryTypeSelectMode)
                [self endTemporaryTypeSelectMode];
            return rv;
        
        } else if (temporaryTypeSelectMode) {
        
            if (c == NSTabCharacter || c == 0x001b) {
                [self endTemporaryTypeSelectMode];
            } else if (c == NSCarriageReturnCharacter || c == NSEnterCharacter || c == NSNewlineCharacter) {
                [self endTemporaryTypeSelectMode];
                [self performActionForRow:[self selectedRow]];
            }
            if (temporaryTypeSelectMode == NO) {
                NSInteger row = [self selectedRow];
                if (row != -1)
                    [self editColumn:2 row:row withEvent:nil select:YES];
                return YES;
            }
        
        } else if (c == '=') {
        
            [self startTemporaryTypeSelectMode];
            return YES;
        }
    }
    
    return [super performKeyEquivalent:theEvent];
}

- (void)keyDown:(NSEvent *)event{
    unichar c = [event firstCharacter];
    NSUInteger flags = ([event deviceIndependentModifierFlags] & ~NSAlphaShiftKeyMask);
    
    static NSCharacterSet *fieldNameCharSet = nil;
    if (fieldNameCharSet == nil) 
        fieldNameCharSet = [[[[BDSKTypeManager sharedManager] strictInvalidCharactersForField:BDSKCiteKeyString] invertedSet] copy];
    
    if (temporaryTypeSelectMode) {
        if ((c == NSTabCharacter || c == 0x001b) && flags == 0) {
            [self endTemporaryTypeSelectMode];
            return;
        } else if ((c == NSCarriageReturnCharacter || c == NSEnterCharacter || c == NSNewlineCharacter) && flags == 0) {
            [self endTemporaryTypeSelectMode];
            [self performActionForRow:[self selectedRow]];
            return;
        } else if ([[self typeSelectHelper] isTypeSelectEvent:event] == NO && 
            (c != NSDownArrowFunctionKey && c != NSUpArrowFunctionKey && c != NSHomeFunctionKey && c != NSEndFunctionKey)) {
            // we allow navigation in the table using arrow keys
            NSBeep();
            return;
        }
    }
    
    [super keyDown:event];
}

- (BOOL)isInTemporaryTypeSelectMode {
    return temporaryTypeSelectMode;
}

- (void)startTemporaryTypeSelectMode {
    if (temporaryTypeSelectMode)
        return;
    temporaryTypeSelectMode = YES;
    savedFirstResponder = [[self window] firstResponder];
    if ([savedFirstResponder isKindOfClass:[NSTextView class]] && [(NSTextView *)savedFirstResponder isFieldEditor])
        savedFirstResponder = (NSResponder *)[(NSTextView *)savedFirstResponder delegate];
    [[self window] makeFirstResponder:self];
    if ([self selectedRow] == -1 && [self numberOfRows] > 0)
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    [[self delegate] tableViewDidChangeTemporaryTypeSelectMode:self];
}

- (void)endTemporaryTypeSelectMode  {
    if (temporaryTypeSelectMode == NO)
        return;
    temporaryTypeSelectMode = NO;
    [[self window] makeFirstResponder:savedFirstResponder];
    savedFirstResponder = nil;
    [[self delegate] tableViewDidChangeTemporaryTypeSelectMode:self];
}

- (BOOL)performActionForRow:(NSInteger)row {
    if ([[self delegate] tableView:self performActionForRow:row]) {
        return YES;
    } else {
        NSBeep();
        return NO;
    }
}

- (BOOL)resignFirstResponder {
    [self endTemporaryTypeSelectMode];
    return [super resignFirstResponder];
}

- (void)awakeFromNib{
    BDSKTypeSelectHelper *aTypeSelectHelper = [[BDSKTypeSelectHelper alloc] init];
    [aTypeSelectHelper setCyclesSimilarResults:YES];
    [self setTypeSelectHelper:aTypeSelectHelper];
    [aTypeSelectHelper release];
}

#pragma mark Delegate and DataSource

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
- (id <BDSKTextImportItemTableViewDelegate>)delegate {
    return (id <BDSKTextImportItemTableViewDelegate>)[super delegate];
}

- (void)setDelegate:(id <BDSKTextImportItemTableViewDelegate>)newDelegate {
    [super setDelegate:newDelegate];
}
#endif

@end

#pragma mark -

@implementation BDSKImportTextView

- (IBAction)makePlainText:(id)sender{
    NSTextStorage *textStorage = [self textStorage];
    [textStorage setAttributes:nil range:NSMakeRange(0,[textStorage length])];
}

- (NSMenu *)menuForEvent:(NSEvent *)event{
    NSMenu *menu = [super menuForEvent:event];
    NSInteger i, count = [menu numberOfItems];
    
    for (i = 0; i < count; i++) {
        if ([[menu itemAtIndex:i] action] == @selector(paste:)) {
            [menu insertItemWithTitle:NSLocalizedString(@"Paste as Plain Text", @"Menu item title") action:@selector(pasteAsPlainText:) keyEquivalent:@"" atIndex:i+1];
            break;
        }
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:NSLocalizedString(@"Make Plain Text", @"Menu item title") action:@selector(makePlainText:) keyEquivalent:@""];
    
    return menu;
}

@end

#pragma mark -

@implementation BDSKURLWindow

- (IBAction)openBookmark:(id)sender {
    NSString *urlString = [[sender representedObject] absoluteString];
    [URLField setStringValue:urlString];
    [OKButton performClick:OKButton];
}

@end

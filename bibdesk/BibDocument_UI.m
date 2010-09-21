//
//  BibDocument_UI.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 5/26/09.
/*
 This software is Copyright (c) 2009-2010
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
 
 - Neither the name of Adam Maxwell nor the names of any
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

#import "BibDocument_UI.h"
#import "BibDocument_Groups.h"
#import "BibDocument_Search.h"
#import "BibDocument_Actions.h"
#import "BibItem.h"
#import "BDSKGroup.h"
#import "BDSKSearchGroup.h"
#import "BDSKLinkedFile.h"
#import "BDSKTypeManager.h"
#import "BDSKPublicationsArray.h"
#import <Quartz/Quartz.h>
#import <FileView/FileView.h>
#import "BDSKGroupOutlineView.h"
#import "BDSKMainTableView.h"
#import "BDSKContainerView.h"
#import "BDSKEdgeView.h"
#import "BDSKSplitView.h"
#import "BDSKPreviewer.h"
#import "BDSKOverlayWindow.h"
#import "BDSKTeXTask.h"
#import "BDSKTemplateParser.h"
#import "BDSKTemplate.h"
#import "BDSKTemplateObjectProxy.h"
#import "BDSKFileContentSearchController.h"
#import "NSArray_BDSKExtensions.h"
#import "NSDictionary_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "NSViewAnimation_BDSKExtensions.h"
#import "NSTextView_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import "NSEvent_BDSKExtensions.h"
#import "BDSKButtonBar.h"
#import "NSMenu_BDSKExtensions.h"
#import "BDSKGroupsArray.h"
#import "NSTableView_BDSKExtensions.h"

static char BDSKDocumentFileViewObservationContext;
static char BDSKDocumentDefaultsObservationContext;

enum {
    BDSKItemChangedGroupFieldMask = 1 << 0,
    BDSKItemChangedSearchKeyMask  = 1 << 1,
    BDSKItemChangedSortKeyMask    = 1 << 2,
    BDSKItemChangedFilesMask      = 1 << 3
};

#pragma mark -

@interface BDSKFileViewObject : NSObject {
    NSURL *URL;
    NSString *string;
}
- (id)initWithURL:(NSURL *)aURL string:(NSString *)aString;
- (NSURL *)URL;
- (NSString *)string;
@end

#pragma mark -

@implementation BibDocument (UI)

#pragma mark Preview updating

- (void)doUpdatePreviews{
    // we can be called from a queue after the document was closed
    if (docFlags.isDocumentClosed)
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
    if (docFlags.isDocumentClosed == NO && [documentWindow isVisible]) {
        [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(doUpdatePreviews) object:nil];
        [self performSelector:@selector(doUpdatePreviews) withObject:nil afterDelay:0.0];
    }
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
    NSUInteger maxItems = [[NSUserDefaults standardUserDefaults] integerForKey:BDSKPreviewMaxNumberKey];
    
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
        [previewer setPDFScaleFactor:[xatrrDefaults doubleForKey:BDSKPreviewPDFScaleFactorKey defaultValue:0.0]];
        [previewer setRTFScaleFactor:[xatrrDefaults doubleForKey:BDSKPreviewRTFScaleFactorKey defaultValue:1.0]];
        [previewer setGeneratedTypes:BDSKGeneratePDF];
        [[bottomPreviewTabView tabViewItemAtIndex:BDSKPreviewDisplayTeX] setView:[previewer pdfView]];
    }
    
    [[previewer progressOverlay] overlayView:bottomPreviewTabView];
}

- (void)cleanupAfterTeXPreview {
    [[previewer progressOverlay] remove];
    [previewer updateWithBibTeXString:nil];
}

- (void)updateBottomPreviewPane{
    NSInteger tabIndex = [bottomPreviewTabView indexOfTabViewItem:[bottomPreviewTabView selectedTabViewItem]];
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
    NSInteger tabIndex = [sidePreviewTabView indexOfTabViewItem:[sidePreviewTabView selectedTabViewItem]];
    if (sidePreviewDisplay != tabIndex) {
        [sidePreviewTabView selectTabViewItemAtIndex:sidePreviewDisplay];
    }
    
    if (sidePreviewDisplay == BDSKPreviewDisplayFiles)
        [sideFileView reloadIcons];
    else
        [self displayTemplatedPreview:sidePreviewDisplayTemplate inTextView:sidePreviewTextView];
}

#pragma mark FVFileView

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
        
        NSInteger shownItemsCount = [[fileSearchController filteredResults] count];
        NSInteger totalItemsCount = [[fileSearchController results] count];
        
        [statusStr appendFormat:@"%ld %@", (long)shownItemsCount, (shownItemsCount == 1) ? NSLocalizedString(@"item", @"item, in status message") : NSLocalizedString(@"items", @"items, in status message")];
        
        if (shownItemsCount != totalItemsCount) {
            NSString *groupStr = ([groupOutlineView numberOfSelectedRows] == 1) ?
                [NSString stringWithFormat:@"%@ \"%@\"", NSLocalizedString(@"in group", @"Partial status message"), [[[self selectedGroups] lastObject] stringValue]] :
                NSLocalizedString(@"in multiple groups", @"Partial status message");
            [statusStr appendFormat:@" %@ (%@ %ld)", groupStr, ofStr, (long)totalItemsCount];
        }
        
    } else if ([[[self selectedGroups] firstObject] failedDownload]) {
        
        [statusStr setString:[[[self selectedGroups] firstObject] errorMessage] ?: @""];
        
    } else {
        
        NSInteger shownPubsCount = [shownPublications count];
        NSInteger groupPubsCount = [groupedPublications count];
        NSInteger totalPubsCount = [publications count];
        
        if (shownPubsCount != groupPubsCount) { 
            [statusStr appendFormat:@"%ld %@ ", (long)shownPubsCount, ofStr];
        }
        [statusStr appendFormat:@"%ld %@", (long)groupPubsCount, (groupPubsCount == 1) ? NSLocalizedString(@"publication", @"publication, in status message") : NSLocalizedString(@"publications", @"publications, in status message")];
        // we can have only a single external group selected at a time
        if ([self hasWebGroupSelected]) {
            [statusStr appendFormat:@" %@", NSLocalizedString(@"in web group", @"Partial status message")];
        } else if ([self hasSharedGroupsSelected]) {
            [statusStr appendFormat:@" %@ \"%@\"", NSLocalizedString(@"in shared group", @"Partial status message"), [[[self selectedGroups] lastObject] stringValue]];
        } else if ([self hasURLGroupsSelected]) {
            [statusStr appendFormat:@" %@ \"%@\"", NSLocalizedString(@"in external file group", @"Partial status message"), [[[self selectedGroups] lastObject] stringValue]];
        } else if ([self hasScriptGroupsSelected]) {
            [statusStr appendFormat:@" %@ \"%@\"", NSLocalizedString(@"in script group", @"Partial status message"), [[[self selectedGroups] lastObject] stringValue]];
        } else if ([self hasSearchGroupsSelected]) {
            BDSKSearchGroup *group = [[self selectedGroups] firstObject];
            [statusStr appendFormat:NSLocalizedString(@" in \"%@\" search group", @"Partial status message"), [[group serverInfo] name]];
            NSInteger matchCount = [group numberOfAvailableResults];
            if (matchCount == 1)
                [statusStr appendString:NSLocalizedString(@". There was 1 match.", @"Partial status message")];
            else if (matchCount > 1)
                [statusStr appendFormat:NSLocalizedString(@". There were %ld matches.", @"Partial status message"), (long)matchCount];
            if ([group hasMoreResults])
                [statusStr appendString:NSLocalizedString(@" Hit \"Search\" to load more.", @"Partial status message")];
            else if (groupPubsCount < matchCount)
                [statusStr appendString:NSLocalizedString(@" Some results could not be parsed.", @"Partial status message")];
        } else if (groupPubsCount != totalPubsCount) {
            NSString *groupStr = ([groupOutlineView numberOfSelectedRows] == 1) ?
                [NSString stringWithFormat:@"%@ \"%@\"", NSLocalizedString(@"in group", @"Partial status message"), [[[self selectedGroups] lastObject] stringValue]] :
                NSLocalizedString(@"in multiple groups", @"Partial status message");
            [statusStr appendFormat:@" %@ (%@ %ld)", groupStr, ofStr, (long)totalPubsCount];
        }
        
    }
    
	[self setStatus:statusStr];
    [statusStr release];
}

#pragma mark Control view animation

- (BOOL)isDisplayingSearchButtons { return [documentWindow isEqual:[searchButtonEdgeView window]]; }
- (BOOL)isDisplayingFileContentSearch { return [documentWindow isEqual:[[fileSearchController tableView] window]]; }
- (BOOL)isDisplayingSearchGroupView { return [documentWindow isEqual:[[searchGroupViewController view] window]]; }
- (BOOL)isDisplayingWebGroupView { return [documentWindow isEqual:[[webGroupViewController view] window]]; }

- (void)insertControlView:(NSView *)controlView atTop:(BOOL)insertAtTop {
    if ([documentWindow isEqual:[controlView window]])
        return;
    
    NSArray *views = [[mainBox subviews] copy];
    NSView *view;
    NSRect controlFrame = [controlView frame];
    NSRect startRect, endRect = [splitView frame];
    
    if (insertAtTop) {
        for (view in views)
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
        for (view in views)
            [resizeView addSubview:view];
    } else {
        [resizeView addSubview:splitView];
    }
    [resizeView addSubview:controlView];
    [views release];
    
    [NSViewAnimation animateResizeView:resizeView toRect:endRect];
    
    views = [[resizeView subviews] copy];
    for (view in views)
        [mainBox addSubview:view];
    [clipView removeFromSuperview];
    
    [views release];
    
    [mainBox setNeedsDisplay:YES];
    [documentWindow displayIfNeeded];
}

- (void)removeControlView:(NSView *)controlView {
    if ([documentWindow isEqual:[controlView window]] == NO)
        return;
    
    NSArray *views = [[NSArray alloc] initWithArray:[mainBox subviews] copyItems:NO];
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
    NSView *view;

    for (view in views) {
        if (NSContainsRect(startRect, [view frame]))
            [resizeView addSubview:view];
    }
    [resizeView addSubview:controlView];
    [views release];
    
    [NSViewAnimation animateResizeView:resizeView toRect:endRect];
    
    [controlView removeFromSuperview];
    views = [[resizeView subviews] copy];
    for (view in views)
        [mainBox addSubview:view];
    [clipView removeFromSuperview];
    
    [views release];
    
    [mainBox setNeedsDisplay:YES];
    [documentWindow displayIfNeeded];
}

#pragma mark Columns Menu

- (NSMenu *)columnsMenu{
    return [tableView columnsMenu];
}

#pragma mark Template Menu

static BOOL menuHasNoValidItems(id validator, NSMenu *menu) {
    NSInteger i = [menu numberOfItems];
	while (--i >= 0) {
        NSMenuItem *item = [menu itemAtIndex:i];
        if ([item isSeparatorItem] == NO && [validator validateMenuItem:item])
            return NO;
    }
    return YES;
}

static void removeInvalidItemsFromMenu(id validator, NSMenu *menu) {
    // kick out every item we won't need:
    NSInteger i = [menu numberOfItems];
    BOOL wasSeparator = YES;
    
    while (--i >= 0) {
        NSMenuItem *item = [menu itemAtIndex:i];
        if (([item isSeparatorItem] == NO && [validator validateMenuItem:item] == NO) || ((wasSeparator || i == 0) && [item isSeparatorItem]) || ([item submenu] && menuHasNoValidItems(validator, [item submenu])))
            [menu removeItem:item];
        else
            wasSeparator = [item isSeparatorItem];
    }
    while ([menu numberOfItems] > 0 && [(NSMenuItem*)[menu itemAtIndex:0] isSeparatorItem])	
        [menu removeItemAtIndex:0];
}

static void addSubmenuForURLsToItem(NSArray *urls, NSMenuItem *anItem) {
    NSMenu *submenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] init] autorelease];
    for (NSURL *url in urls) {
        NSString *title = [url isFileURL] ? [[NSFileManager defaultManager] displayNameAtPath:[url path]] : [url absoluteString];
        NSMenuItem *item = [submenu addItemWithTitle:title action:[anItem action] keyEquivalent:@""];
        [item setTarget:[anItem target]];
        [item setRepresentedObject:url];
    }
    [anItem setSubmenu:submenu];
}

- (void)updateTemplatePreviewMenu:(NSMenu *)menu {
    NSArray *styles = [BDSKTemplate allStyleNamesForFileTypes:[NSSet setWithObjects:@"rtf", @"rtfd", @"doc", @"html", nil]];
    
    while ([menu numberOfItems])
        [menu removeItemAtIndex:0];
    
    NSMenuItem *item;
    SEL action = menu == bottomTemplatePreviewMenu ? @selector(changePreviewDisplay:) : @selector(changeSidePreviewDisplay:);
    
    for (NSString *style in styles) {
        item = [menu addItemWithTitle:style action:action keyEquivalent:@""];
        [item setTarget:self];
        [item setTag:BDSKPreviewDisplayText];
        [item setRepresentedObject:style];
    }
}

- (void)updateCopyAsMenu:(NSMenu *)menu {
    while ([menu numberOfItems])
        [menu removeItemAtIndex:0];
    NSArray *styles = [BDSKTemplate allStyleNames];
    NSUInteger i, count = [styles count];
    for (i = 0; i < count; i++) {
        NSMenuItem *item = [menu addItemWithTitle:[styles objectAtIndex:i] action:@selector(copyAsAction:) keyEquivalent:@""];
        [item setTarget:self];
        [item setTag:BDSKTemplateDragCopyType + i];
    }
}

- (void)updateMainTableMenu:(NSMenu *)menu {
    NSInteger row = [tableView clickedRow];
    NSInteger column = [tableView clickedColumn];
    
    [menu removeAllItems];
    if (row != -1 && column != -1) {
        NSMenuItem *item = nil;
        NSString *tcId = [[[tableView tableColumns] objectAtIndex:column] identifier];
        NSArray *linkedURLs;
        NSURL *theURL;
        
        if([tcId isGeneralURLField]){
            if([tcId isURLField]){
                if([tcId isLocalFileField]){
                    item = [menu addItemWithTitle:NSLocalizedString(@"Open Linked File", @"Menu item title") action:@selector(openLocalURL:) keyEquivalent:@""];
                    [item setTarget:self];
                    [item setRepresentedObject:tcId];
                    item = [menu addItemWithTitle:NSLocalizedString(@"Reveal Linked File in Finder", @"Menu item title") action:@selector(revealLocalURL:) keyEquivalent:@""];
                    [item setTarget:self];
                    [item setRepresentedObject:tcId];
                    item = [menu addItemWithTitle:NSLocalizedString(@"Show Skim Notes For Linked File", @"Menu item title") action:@selector(showNotesForLocalURL:) keyEquivalent:@""];
                    [item setTarget:self];
                    [item setRepresentedObject:tcId];
                    item = [menu addItemWithTitle:NSLocalizedString(@"Copy Skim Notes For Linked File", @"Menu item title") action:@selector(copyNotesForLocalURL:) keyEquivalent:@""];
                    [item setTarget:self];
                    [item setRepresentedObject:tcId];
                }else{
                    item = [menu addItemWithTitle:NSLocalizedString(@"Open URL in Browser", @"Menu item title") action:@selector(openRemoteURL:) keyEquivalent:@""];
                    [item setTarget:self];
                    [item setRepresentedObject:tcId];
                }
                if([tableView numberOfClickedOrSelectedRows] == 1 &&
                   (theURL = [[shownPublications objectAtIndex:row] URLForField:tcId])){
                    item = [menu insertItemWithTitle:NSLocalizedString(@"Open With", @"Menu item title") 
                                        andSubmenuOfApplicationsForURL:theURL atIndex:1];
                }
            }else if([tcId isEqualToString:BDSKLocalFileString]){
                linkedURLs = [self clickedOrSelectedFileURLs];
                
                if([linkedURLs count]){
                    item = [menu addItemWithTitle:NSLocalizedString(@"Quick Look", @"Menu item title") action:@selector(previewAction:) keyEquivalent:@""];
                    [item setTarget:self];
                    [item setRepresentedObject:linkedURLs];
                    item = [menu addItemWithTitle:NSLocalizedString(@"Open Linked Files", @"Menu item title") action:@selector(openLinkedFile:) keyEquivalent:@""];
                    [item setTarget:self];
                    if ([linkedURLs count] > 1)
                        addSubmenuForURLsToItem(linkedURLs, item);
                    item = [menu addItemWithTitle:NSLocalizedString(@"Reveal Linked Files in Finder", @"Menu item title") action:@selector(revealLinkedFile:) keyEquivalent:@""];
                    [item setTarget:self];
                    if ([linkedURLs count] > 1)
                        addSubmenuForURLsToItem(linkedURLs, item);
                    item = [menu addItemWithTitle:NSLocalizedString(@"Show Skim Notes For Linked Files", @"Menu item title") action:@selector(showNotesForLinkedFile:) keyEquivalent:@""];
                    [item setTarget:self];
                    if ([linkedURLs count] > 1)
                        addSubmenuForURLsToItem(linkedURLs, item);
                    item = [menu addItemWithTitle:NSLocalizedString(@"Copy Skim Notes For Linked Files", @"Menu item title") action:@selector(copyNotesForLinkedFile:) keyEquivalent:@""];
                    [item setTarget:self];
                    if ([linkedURLs count] > 1)
                        addSubmenuForURLsToItem(linkedURLs, item);
                    if([linkedURLs count] == 1 && (theURL = [linkedURLs lastObject]) && [theURL isEqual:[NSNull null]] == NO){
                        item = [menu insertItemWithTitle:NSLocalizedString(@"Open With", @"Menu item title") 
                                            andSubmenuOfApplicationsForURL:theURL atIndex:1];
                    }
                }
            }else if([tcId isEqualToString:BDSKRemoteURLString]){
                linkedURLs = [[self clickedOrSelectedPublications] valueForKeyPath:@"@unionOfArrays.remoteURLs.URL"];
                
                if([linkedURLs count]){
                    item = [menu addItemWithTitle:NSLocalizedString(@"Quick Look", @"Menu item title") action:@selector(previewAction:) keyEquivalent:@""];
                    [item setTarget:self];
                    [item setRepresentedObject:linkedURLs];
                    item = [menu addItemWithTitle:NSLocalizedString(@"Open URLs in Browser", @"Menu item title") action:@selector(openLinkedURL:) keyEquivalent:@""];
                    [item setTarget:self];
                    if ([linkedURLs count] > 1)
                        addSubmenuForURLsToItem(linkedURLs, item);
                    if([linkedURLs count] == 1 && (theURL = [linkedURLs lastObject]) && [theURL isEqual:[NSNull null]] == NO){
                        item = [menu insertItemWithTitle:NSLocalizedString(@"Open With", @"Menu item title") 
                                            andSubmenuOfApplicationsForURL:theURL atIndex:1];
                    }
                }
            }
            [menu addItem:[NSMenuItem separatorItem]];
            item = [menu addItemWithTitle:NSLocalizedString(@"Get Info", @"Menu item title") action:@selector(editPubCmd:) keyEquivalent:@""];
            [item setTarget:self];
            item = [menu addItemWithTitle:NSLocalizedString(@"Remove", @"Menu item title") action:@selector(removeSelectedPubs:) keyEquivalent:@""];
            [item setTarget:self];
            item = [menu addItemWithTitle:NSLocalizedString(@"Delete", @"Menu item title") action:@selector(deleteSelectedPubs:) keyEquivalent:@""];
            [item setTarget:self];
            [item setKeyEquivalentModifierMask:NSAlternateKeyMask];
            [item setAlternate:YES];
        }else if([tcId isCitationField]){
            NSMutableArray *linkedPubs = [NSMutableArray array];
            BibItem *pub;
            for (pub in [self clickedOrSelectedPublications])
                [linkedPubs addObjectsFromArray:[pub citationValueOfField:tcId]];
            for (pub in linkedPubs) {
                item = [menu addItemWithTitle:[pub citeKey] action:@selector(editRepresentedPub:) keyEquivalent:@""];
                [item setTarget:self];
                [item setRepresentedObject:pub];
            }
            [menu addItem:[NSMenuItem separatorItem]];
            item = [menu addItemWithTitle:NSLocalizedString(@"Get Info", @"Menu item title") action:@selector(editPubCmd:) keyEquivalent:@""];
            [item setTarget:self];
            item = [menu addItemWithTitle:NSLocalizedString(@"Remove", @"Menu item title") action:@selector(removeSelectedPubs:) keyEquivalent:@""];
            [item setTarget:self];
            item = [menu addItemWithTitle:NSLocalizedString(@"Delete", @"Menu item title") action:@selector(deleteSelectedPubs:) keyEquivalent:@""];
            [item setTarget:self];
            [item setKeyEquivalentModifierMask:NSAlternateKeyMask];
            [item setAlternate:YES];
        }else{
            [self menuNeedsUpdate:copyAsMenu];
            [menu addItemsFromMenu:actionMenu];
            [menu removeItemAtIndex:0];
        }
        
        removeInvalidItemsFromMenu(self, menu);
    }
}

- (void)updateGroupTableMenu:(NSMenu *)menu {
    NSInteger row = [groupOutlineView clickedRow];
    
    [menu removeAllItems];
    if (row != -1) {
        id item = [groupOutlineView itemAtRow:row];
        
        if (item == [groups categoryParent]) {
            [menu addItemsFromMenu:groupFieldMenu];
            while ([[menu itemAtIndex:1] isSeparatorItem] == NO)
                [menu removeItemAtIndex:1];
            for (NSString *field in [[[NSUserDefaults standardUserDefaults] stringArrayForKey:BDSKGroupFieldsKey] reverseObjectEnumerator]) {
                NSMenuItem *menuItem = [menu insertItemWithTitle:field action:@selector(changeGroupFieldAction:) keyEquivalent:@"" atIndex:1];
                [menuItem setTarget:self];
                [menuItem setRepresentedObject:field];
            }
        } else {
            [menu addItemsFromMenu:groupMenu];
            [menu removeItemAtIndex:0];
            
            removeInvalidItemsFromMenu(self, menu);
        }
    }
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    if (menu == bottomTemplatePreviewMenu || menu == sideTemplatePreviewMenu)
        [self updateTemplatePreviewMenu:menu];
    else if (menu == copyAsMenu)
        [self updateCopyAsMenu:menu];
    else if (menu == [tableView menu])
        [self updateMainTableMenu:menu];
    else if (menu == [groupOutlineView menu])
        [self updateGroupTableMenu:menu];
}

#pragma mark SplitView delegate

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview {
    if ([sender isEqual:groupSplitView]) {
        return [subview isEqual:[[sender subviews] objectAtIndex:1]] == NO;
    } else if ([sender isEqual:splitView]) {
        return [subview isEqual:[[sender subviews] lastObject]];
    }
    return NO;
}

- (BOOL)splitView:(NSSplitView *)sender shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex {
    if ([sender isEqual:groupSplitView]) {
        if ([subview isEqual:[[sender subviews] objectAtIndex:0]])
            [self toggleGroups:sender];
        else if ([subview isEqual:[[sender subviews] objectAtIndex:2]])
            [self toggleSidebar:sender];
    } else if ([sender isEqual:splitView]) {
        if ([subview isEqual:[[sender subviews] lastObject]]) {
            CGFloat position = [splitView maxPossiblePositionOfDividerAtIndex:dividerIndex];
            if ([splitView isSubviewCollapsed:subview]) {
                if (docState.lastPreviewHeight <= 0.0)
                    docState.lastPreviewHeight = 200.0;
                if (docState.lastPreviewHeight > NSHeight([[[sender subviews] objectAtIndex:dividerIndex] frame]))
                    docState.lastPreviewHeight = floor(0.5 * NSHeight([[[sender subviews] objectAtIndex:dividerIndex] frame]));
                position -= docState.lastPreviewHeight;
            } else {
                docState.lastPreviewHeight = NSHeight([[[sender subviews] lastObject] frame]);
            }
            [(BDSKSplitView *)splitView setPosition:position ofDividerAtIndex:dividerIndex animate:YES];
        }
    }
    return NO;
}

- (BOOL)splitView:(NSSplitView *)sender shouldHideDividerAtIndex:(NSInteger)dividerIndex {
    return [sender isEqual:groupSplitView];
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex {
    if ([sender isEqual:groupSplitView]) {
        if (dividerIndex == 0)
            return proposedMax - 150.0;
        else
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
            return floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_5 ? proposedMax - 100.0 - [groupSplitView dividerThickness] : proposedMax - 100.0;
#else
            return proposedMax - 100.0 - [groupSplitView dividerThickness];
#endif
    } else if ([sender isEqual:splitView]) {
        if (dividerIndex == (NSInteger)[[splitView subviews] count] - 2)
            return proposedMax - 50.0;
        else
            return proposedMax;
    }
    return proposedMax;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex {
    if ([sender isEqual:groupSplitView]) {
        if (dividerIndex == 0)
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
            return floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_5 ? proposedMin + 100.0 + [groupSplitView dividerThickness] : proposedMin + 100.0;
#else
            return proposedMin + 100.0 + [groupSplitView dividerThickness];
#endif
        else
            return proposedMin + 150.0;
    }
    return proposedMin;
}

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize {
    if ([sender isEqual:groupSplitView]) {
        NSView *leftView = [[sender subviews] objectAtIndex:0];
        NSView *centerView = [[sender subviews] objectAtIndex:1];
        NSView *rightView = [[sender subviews] objectAtIndex:2];
        BOOL leftCollapsed = [sender isSubviewCollapsed:leftView];
        BOOL rightCollapsed = [sender isSubviewCollapsed:rightView];
        NSSize leftSize = [leftView frame].size;
        NSSize centerSize = [centerView frame].size;
        NSSize rightSize = [rightView frame].size;
        CGFloat contentWidth = NSWidth([sender frame]);
        
        if (leftCollapsed)
            leftSize.width = 0.0;
        else
            contentWidth -= [sender dividerThickness];
        if (rightCollapsed)
            rightSize.width = 0.0;
        else
            contentWidth -= [sender dividerThickness];
        
        if (contentWidth < leftSize.width + rightSize.width) {
            CGFloat oldContentWidth = oldSize.width;
            if (leftCollapsed == NO)
                oldContentWidth -= [sender dividerThickness];
            if (rightCollapsed == NO)
                oldContentWidth -= [sender dividerThickness];
            CGFloat resizeFactor = contentWidth / oldContentWidth;
            leftSize.width = floor(resizeFactor * leftSize.width);
            rightSize.width = floor(resizeFactor * rightSize.width);
        }
        
        centerSize.width = contentWidth - leftSize.width - rightSize.width;
        leftSize.height = rightSize.height = centerSize.height = NSHeight([sender frame]);
        if (leftCollapsed == NO)
            [leftView setFrameSize:leftSize];
        if (rightCollapsed == NO)
            [rightView setFrameSize:rightSize];
        [centerView setFrameSize:centerSize];
    }
    [sender adjustSubviews];
}

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification {
    if ([[aNotification object] isEqual:groupSplitView] || aNotification == nil) {
        NSArray *subviews = [groupSplitView subviews];
        BOOL isLeftHidden = [groupSplitView isSubviewCollapsed:[subviews objectAtIndex:0]];
        BOOL isRightHidden = [groupSplitView isSubviewCollapsed:[subviews objectAtIndex:2]];
        NSView *view = [subviews objectAtIndex:1];
        NSRect rect = [view convertRect:[view bounds] toView:[documentWindow contentView]];
        NSRect frame = [bottomPreviewButton frame];
        frame.origin.x = fmax(8.0, NSMinX(rect));
        [bottomPreviewButton setFrame:frame];
        [statusBar setLeftMargin:NSMaxX(frame) + 8.0];
        [statusBar setRightMargin:fmax(15.0, NSWidth([statusBar frame]) - NSMaxX(rect) + 8.0)];
        [groupButtonView setHidden:isLeftHidden];
        [sidePreviewButton setHidden:isRightHidden];
        if (isLeftHidden == NO) {
            frame = [groupButtonView frame];
            frame.size.width = NSMinX(rect) - [groupSplitView dividerThickness];
            [groupButtonView setFrame:frame];
        }
        if (isRightHidden == NO) {
            frame = [sidePreviewButton frame];
            frame.origin.x = NSMaxX(rect) + [groupSplitView dividerThickness];
            [sidePreviewButton setFrame:frame];
        }
    }
}

#pragma mark -
#pragma mark Notification handlers

- (void)handleBibItemAddDelNotification:(NSNotification *)notification{
    // NB: this method gets called for setPublications: also, so checking for AddItemNotification might not do what you expect
	BOOL isDelete = [[notification name] isEqualToString:BDSKDocDelItemNotification];
    if(isDelete == NO && [self hasLibraryGroupSelected])
		[self setSearchString:@""]; // clear the search when adding

    // update smart group counts
    [self updateSmartGroupsCount];
    // this handles the remaining UI updates necessary (tableView and previews)
	[self updateCategoryGroupsPreservingSelection:YES];
    
    NSArray *pubs = [[notification userInfo] objectForKey:BDSKDocumentPublicationsKey];
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
    else if([sortKey isEqualToString:BDSKColorString] || [sortKey isEqualToString:BDSKColorLabelString])
        return [key isEqualToString:BDSKColorString] || [key isEqualToString:BDSKColorLabelString];
    else
        return [sortKey isEqualToString:key];
}

- (BOOL)searchKeyDependsOnKey:(NSString *)key{
    NSString *searchKey = [[searchField stringValue] isEqualToString:@""] ? nil : [searchButtonBar representedObjectOfSelectedButton];
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
    if (docFlags.isDocumentClosed)
        return;
    
    BOOL displayingLocal = (NO == [self hasExternalGroupsSelected]);
    
    if (displayingLocal && (docFlags.itemChangeMask & BDSKItemChangedFilesMask) != 0)
        [self updateFileViews];

    BOOL shouldUpdateGroups = [NSString isEmptyString:[self currentGroupField]] == NO && (docFlags.itemChangeMask & BDSKItemChangedGroupFieldMask) != 0;
    
    // allow updating a smart group if it's selected
	[self updateSmartGroups];
    
    if(shouldUpdateGroups){
        // this handles all UI updates if we call it, so don't bother with any others
        [self updateCategoryGroupsPreservingSelection:YES];
    } else if (displayingLocal && (docFlags.itemChangeMask & BDSKItemChangedSearchKeyMask) != 0) {
        // this handles all UI updates if we call it, so don't bother with any others
        [self redoSearch];
    } else if (displayingLocal) {
        // groups and quicksearch won't update for us
        if ((docFlags.itemChangeMask & BDSKItemChangedSortKeyMask) != 0)
            [self sortPubsByKey:nil];
        else
            [tableView reloadData];
        [self updateStatus];
        [self updatePreviews];
    }
    
    docFlags.itemChangeMask = 0;
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

	NSString *changedKey = [userInfo objectForKey:BDSKBibItemKeyKey];
    NSString *key = [pub citeKey];
    NSString *oldKey = nil;
    
    // need to handle cite keys and crossrefs if a cite key changed
    if([changedKey isEqualToString:BDSKCiteKeyString]){
        oldKey = [userInfo objectForKey:BDSKBibItemOldValueKey];
        [publications changeCiteKey:oldKey toCiteKey:key forItem:pub];
        if([NSString isEmptyString:oldKey])
            oldKey = nil;
    }
    
    // -[BDSKItemSearchIndexes addPublications:] will overwrite previous values for this pub
    if ([changedKey isIntegerField] == NO && [changedKey isURLField] == NO) {
        NSArray *pubs = [NSArray arrayWithObject:pub];
        [searchIndexes addPublications:pubs];
        [notesSearchIndex addPublications:pubs];
    }
    
    // access type manager outside the enumerator, since it's @synchronized...
    BDSKTypeManager *typeManager = [BDSKTypeManager sharedManager];
    NSCharacterSet *invalidSet = [typeManager invalidCharactersForField:BDSKCiteKeyString];
    NSSet *citeFields = [typeManager citationFieldsSet];
    
    _BibItemCiteKeyChangeInfo changeInfo;
    changeInfo.invalidSet = invalidSet;
    changeInfo.key = key;
    changeInfo.oldKey = oldKey;
    
    for (pub in publications) {
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
        docFlags.itemChangeMask |= BDSKItemChangedGroupFieldMask;
    if ([self sortKeyDependsOnKey:changedKey])
        docFlags.itemChangeMask |= BDSKItemChangedSortKeyMask;
    if ([self searchKeyDependsOnKey:changedKey])
        docFlags.itemChangeMask |= BDSKItemChangedSearchKeyMask;
    if ([changedKey isEqualToString:BDSKLocalFileString] || [changedKey isEqualToString:BDSKRemoteURLString])
        docFlags.itemChangeMask |= BDSKItemChangedFilesMask;
    
    
    // queue for UI updating, in case the item is changed as part of a batch process such as Find & Replace or AutoFile
    if (docFlags.isDocumentClosed == NO) {
        [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(handlePrivateBibItemChanged) object:nil];
        [self performSelector:@selector(handlePrivateBibItemChanged) withObject:nil afterDelay:0.0];
    }
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
    [groupOutlineView setNeedsDisplay:YES];
    BOOL fileViewEditable = [self isDisplayingFileContentSearch] == NO && [self hasExternalGroupsSelected] == NO && [[self selectedPublications] count] == 1;
    [sideFileView setEditable:fileViewEditable];
    [bottomFileView setEditable:fileViewEditable]; 
}

- (void)handleFlagsChangedNotification:(NSNotification *)notification{
    BOOL isOptionKeyState = ([NSEvent standardModifierFlags] & NSAlternateKeyMask) != 0;
    
    if (docFlags.inOptionKeyState != isOptionKeyState) {
        docFlags.inOptionKeyState = isOptionKeyState;
        
        NSToolbarItem *toolbarItem = [toolbarItems objectForKey:@"BibDocumentToolbarNewItemIdentifier"];
        
        if (isOptionKeyState) {
            static NSImage *alternateNewToolbarImage = nil;
            if (alternateNewToolbarImage == nil) {
                alternateNewToolbarImage = [[NSImage alloc] initWithSize:NSMakeSize(32, 32)];
                [alternateNewToolbarImage lockFocus];
                NSImage *srcImage = [NSImage imageNamed:@"newdoc"];
                [srcImage drawInRect:NSMakeRect(0, 0, 32, 32) fromRect:NSMakeRect(0, 0, [srcImage size].width, [srcImage size].height) operation:NSCompositeSourceOver fraction:1.0]; 
                [[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kAliasBadgeIcon)] drawInRect:NSMakeRect(24, 0, 32, 32) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
                [alternateNewToolbarImage unlockFocus];
            }
            
            [toolbarItem setLabel:NSLocalizedString(@"New with Crossref", @"Toolbar item label")];
            [toolbarItem setToolTip:NSLocalizedString(@"Create new publication with crossref", @"Tool tip message")];
            [toolbarItem setImage:alternateNewToolbarImage];
            [toolbarItem setAction:@selector(createNewPubUsingCrossrefAction:)];
        } else {
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

- (void)handleApplicationDidBecomeActiveNotification:(NSNotification *)notification{
    // resolve all the shown URLs, when a file was renamed on disk this will trigger an update notification
    [self selectedFileURLs];
}

- (void)handleCustomFieldsDidChangeNotification:(NSNotification *)notification{
    [publications makeObjectsPerformSelector:@selector(customFieldsDidChange:) withObject:notification];
    [tableView setupTableColumnsWithIdentifiers:[tableView tableColumnIdentifiers]];
    // current group field may have changed its type (string->person)
    [self updateSmartGroups];
    [self updateCategoryGroupsPreservingSelection:YES];
    [self updatePreviews];
}

- (void)handleTemporaryFileMigrationNotification:(NSNotification *)notification{
    // display after the window loads so we can use a sheet, and the migration controller window is in front
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKDisableMigrationWarning"] == NO)
        docFlags.displayMigrationAlert = YES;
}

- (void)handleSkimFileDidSaveNotification:(NSNotification *)notification{
    NSString *path = [notification object];
    NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:BDSKLocalFileString, BDSKBibItemKeyKey, nil];
    
    for (BibItem *pub in publications) {
        if ([[[pub existingLocalFiles] valueForKey:@"path"] containsObject:path])
            [[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibItemChangedNotification object:pub userInfo:notifInfo];
    }
}

- (void)registerForNotifications{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(handleGroupFieldChangedNotification:)
               name:BDSKGroupFieldChangedNotification
             object:self];
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
           selector:@selector(handleSharedGroupsChangedNotification:)
               name:BDSKSharingClientsChangedNotification
             object:nil];
    [nc addObserver:self
           selector:@selector(handleExternalGroupUpdatedNotification:)
               name:BDSKExternalGroupUpdatedNotification
             object:nil];
    [nc addObserver:self
           selector:@selector(handleWillRemoveGroupsNotification:)
               name:BDSKWillRemoveGroupsNotification
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
           selector:@selector(handleApplicationDidBecomeActiveNotification:)
               name:NSApplicationDidBecomeActiveNotification
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
}           

#pragma mark KVO

- (void)startObserving {
    NSUserDefaultsController *sud = [NSUserDefaultsController sharedUserDefaultsController];
    
    [sud addObserver:self
          forKeyPath:[@"values." stringByAppendingString:BDSKIgnoredSortTermsKey]
             options:0
             context:&BDSKDocumentDefaultsObservationContext];
    [sud addObserver:self
          forKeyPath:[@"values." stringByAppendingString:BDSKAuthorNameDisplayKey]
             options:0
             context:&BDSKDocumentDefaultsObservationContext];
    [sud addObserver:self
          forKeyPath:[@"values." stringByAppendingString:BDSKBTStyleKey]
             options:0
             context:&BDSKDocumentDefaultsObservationContext];
    [sud addObserver:self
          forKeyPath:[@"values." stringByAppendingString:BDSKUsesTeXKey]
             options:0
             context:&BDSKDocumentDefaultsObservationContext];
    [sud addObserver:self
          forKeyPath:[@"values." stringByAppendingString:BDSKHideGroupCountKey]
             options:0
             context:&BDSKDocumentDefaultsObservationContext];
    
    [sideFileView addObserver:self forKeyPath:@"iconScale" options:0 context:&BDSKDocumentFileViewObservationContext];
    [sideFileView addObserver:self forKeyPath:@"displayMode" options:0 context:&BDSKDocumentFileViewObservationContext];
    [bottomFileView addObserver:self forKeyPath:@"iconScale" options:0 context:&BDSKDocumentFileViewObservationContext];
    [bottomFileView addObserver:self forKeyPath:@"displayMode" options:0 context:&BDSKDocumentFileViewObservationContext];
}

- (void)endObserving {
    @try {
        [sideFileView removeObserver:self forKeyPath:@"iconScale"];
        [sideFileView removeObserver:self forKeyPath:@"displayMode"];
    }
    @catch(id e) {}
    @try {
        [bottomFileView removeObserver:self forKeyPath:@"iconScale"];
        [bottomFileView removeObserver:self forKeyPath:@"displayMode"];
    }
    @catch(id e) {}
    @try {
        NSUserDefaultsController *sud = [NSUserDefaultsController sharedUserDefaultsController];
        [sud removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKIgnoredSortTermsKey]];
        [sud removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKAuthorNameDisplayKey]];
        [sud removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKBTStyleKey]];
        [sud removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKUsesTeXKey]];
        [sud removeObserver:self forKeyPath:[@"values." stringByAppendingString:BDSKHideGroupCountKey]];
    }
    @catch(id e) {}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &BDSKDocumentFileViewObservationContext) {
        if (object == sideFileView) {
            FVDisplayMode displayMode = [sideFileView displayMode];
            CGFloat iconScale = displayMode == FVDisplayModeGrid ? [sideFileView iconScale] : 0.0;
            [[NSUserDefaults standardUserDefaults] setFloat:iconScale forKey:BDSKSideFileViewIconScaleKey];
            [[NSUserDefaults standardUserDefaults] setInteger:displayMode forKey:BDSKSideFileViewDisplayModeKey];
        } else if (object == bottomFileView) {
            FVDisplayMode displayMode = [bottomFileView displayMode];
            CGFloat iconScale = displayMode == FVDisplayModeGrid ? [bottomFileView iconScale] : 0.0;
            [[NSUserDefaults standardUserDefaults] setFloat:iconScale forKey:BDSKBottomFileViewIconScaleKey];
            [[NSUserDefaults standardUserDefaults] setInteger:displayMode forKey:BDSKBottomFileViewDisplayModeKey];
        }
    } else if (context == &BDSKDocumentDefaultsObservationContext) {
        NSString *key = [keyPath substringFromIndex:7];
        if ([key isEqualToString:BDSKIgnoredSortTermsKey]) {
            [self sortPubsByKey:nil];
        } else if ([key isEqualToString:BDSKAuthorNameDisplayKey]) {
            [tableView reloadData];
            if ([currentGroupField isPersonField])
                [groupOutlineView reloadData];
        } else if ([key isEqualToString:BDSKBTStyleKey]) {
            if ([previewer isVisible])
                [self updatePreviews];
            else if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey] &&
                    [[BDSKPreviewer sharedPreviewer] isWindowVisible] &&
                    [self isMainDocument])
                [self updatePreviewer:[BDSKPreviewer sharedPreviewer]];
        } else if ([key isEqualToString:BDSKUsesTeXKey]) {
            [bottomPreviewButton setEnabled:[[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey] forSegment:BDSKPreviewDisplayTeX];
        } else if ([key isEqualToString:BDSKHideGroupCountKey]) {
            // if we were hiding the count, the smart group counts weren't updated, so we need to update them now when we're showing the count, otherwise just reload
            if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKHideGroupCountKey])
                [groupOutlineView reloadData];
            else
                [self updateSmartGroupsCount];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

#pragma mark -

@implementation BDSKFileViewObject

- (id)initWithURL:(NSURL *)aURL string:(NSString *)aString {
    if (self = [super init]) {
        URL = [aURL copy];
        string = [aString copy];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(URL);
    BDSKDESTROY(string);
    [super dealloc];
}

- (NSURL *)URL { return URL; }

- (NSString *)string { return string; }

@end

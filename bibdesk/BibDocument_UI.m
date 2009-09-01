//
//  BibDocument_UI.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 5/26/09.
/*
 This software is Copyright (c) 2009
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
#import "BibItem.h"
#import "BDSKGroup.h"
#import "BDSKSearchGroup.h"
#import "BDSKLinkedFile.h"
#import "BDSKApplication.h"
#import "BDSKTypeManager.h"
#import "BDSKPublicationsArray.h"
#import <Quartz/Quartz.h>
#import <FileView/FileView.h>
#import "BDSKGroupOutlineView.h"
#import "BDSKMainTableView.h"
#import "BDSKContainerView.h"
#import "BDSKSplitView.h"
#import "BDSKGradientSplitView.h"
#import "BDSKEdgeView.h"
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
    if (docState.isDocumentClosed == NO && [documentWindow isVisible]) {
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
        [previewer setPDFScaleFactor:[xatrrDefaults floatForKey:BDSKPreviewPDFScaleFactorKey defaultValue:0.0]];
        [previewer setRTFScaleFactor:[xatrrDefaults floatForKey:BDSKPreviewRTFScaleFactorKey defaultValue:1.0]];
        [previewer setGeneratedTypes:BDSKGeneratePDF];
        BDSKEdgeView *previewerBox = [[[BDSKEdgeView alloc] init] autorelease];
        [previewerBox setEdges:BDSKEveryEdgeMask];
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
                [statusStr appendFormat:NSLocalizedString(@". There was 1 match.", @"Partial status message")];
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

- (BOOL)isDisplayingSearchButtons { return [documentWindow isEqual:[[searchButtonController view] window]]; }
- (BOOL)isDisplayingFileContentSearch { return [documentWindow isEqual:[[fileSearchController tableView] window]]; }
- (BOOL)isDisplayingSearchGroupView { return [documentWindow isEqual:[[searchGroupViewController view] window]]; }
- (BOOL)isDisplayingWebGroupView { return [documentWindow isEqual:[[webGroupViewController view] window]]; }

- (void)insertControlView:(NSView *)controlView atTop:(BOOL)insertAtTop {
    if ([documentWindow isEqual:[controlView window]])
        return;
    
    NSArray *views = [[mainBox subviews] copy];
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

#pragma mark Columns Menu

- (NSMenu *)columnsMenu{
    return [tableView columnsMenu];
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
    } else if (menu == copyAsMenu) {
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
}

#pragma mark SplitView delegate

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize {
    NSInteger i = [[sender subviews] count] - 2;
    BDSKASSERT(i >= 0);
	NSView *zerothView = i == 0 ? nil : [[sender subviews] objectAtIndex:0];
	NSView *firstView = [[sender subviews] objectAtIndex:i];
	NSView *secondView = [[sender subviews] objectAtIndex:++i];
	NSRect zerothFrame = zerothView ? [zerothView frame] : NSZeroRect;
	NSRect firstFrame = [firstView frame];
	NSRect secondFrame = [secondView frame];
	
	if (sender == splitView) {
		// first = table, second = preview, zeroth = web
        CGFloat contentHeight = NSHeight([sender frame]) - i * [sender dividerThickness];
        CGFloat factor = contentHeight / (oldSize.height - i * [sender dividerThickness]);
        secondFrame = NSIntegralRect(secondFrame);
        zerothFrame.size.height = BDSKFloor(factor * NSHeight(zerothFrame));
        firstFrame.size.height = BDSKFloor(factor * NSHeight(firstFrame));
        secondFrame.size.height = BDSKFloor(factor * NSHeight(secondFrame));
        if (NSHeight(zerothFrame) < 1.0)
            zerothFrame.size.height = 0.0;
        if (NSHeight(firstFrame) < 1.0)
            firstFrame.size.height = 0.0;
        if (NSHeight(secondFrame) < 1.0)
            secondFrame.size.height = 0.0;
        // randomly divide the remaining gap over the two views; NSSplitView dumps it all over the last view, which grows that one more than the others
        NSInteger gap = (NSInteger)(contentHeight - NSHeight(zerothFrame) - NSHeight(firstFrame) - NSHeight(secondFrame));
        while (gap > 0) {
            i = BDSKFloor((3.0f * rand()) / RAND_MAX);
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
        CGFloat contentWidth = NSWidth([sender frame]) - 2 * [sender dividerThickness];
        if (NSWidth(zerothFrame) < 1.0)
            zerothFrame.size.width = 0.0;
        if (NSWidth(secondFrame) < 1.0)
            secondFrame.size.width = 0.0;
        if (contentWidth < NSWidth(zerothFrame) + NSWidth(secondFrame)) {
            CGFloat factor = contentWidth / (oldSize.width - [sender dividerThickness]);
            zerothFrame.size.width = BDSKFloor(factor * NSWidth(zerothFrame));
            secondFrame.size.width = BDSKFloor(factor * NSWidth(secondFrame));
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

- (void)splitView:(BDSKGradientSplitView *)sender doubleClickedDividerAt:(NSInteger)offset {
    NSInteger i = [[sender subviews] count] - 2;
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
				docState.lastPreviewHeight = BDSKFloor(NSHeight([sender frame]) / 3); // a reasonable value for uncollapsing the first time
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
                    docState.lastGroupViewWidth = BDSKMin(120, NSWidth(firstFrame)); // a reasonable value for uncollapsing the first time
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
                    docState.lastFileViewWidth = BDSKMin(120, NSWidth(firstFrame)); // a reasonable value for uncollapsing the first time
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
    else if([sortKey isEqualToString:BDSKColorString] || [sortKey isEqualToString:BDSKColorLabelString])
        return [key isEqualToString:BDSKColorString] || [key isEqualToString:BDSKColorLabelString];
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
    
    BOOL displayingLocal = (NO == [self hasExternalGroupsSelected]);
    
    if (displayingLocal && (docState.itemChangeMask & BDSKItemChangedFilesMask) != 0)
        [self updateFileViews];

    BOOL shouldUpdateGroups = [NSString isEmptyString:[self currentGroupField]] == NO && (docState.itemChangeMask & BDSKItemChangedGroupFieldMask) != 0;
    
    // allow updating a smart group if it's selected
	[self updateSmartGroups];
    
    if(shouldUpdateGroups){
        // this handles all UI updates if we call it, so don't bother with any others
        [self updateCategoryGroupsPreservingSelection:YES];
    } else if (displayingLocal && (docState.itemChangeMask & BDSKItemChangedSearchKeyMask) != 0) {
        // this handles all UI updates if we call it, so don't bother with any others
        [searchField sendAction:[searchField action] to:[searchField target]];
    } else if (displayingLocal) {
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
    if ([changedKey isIntegerField] == NO && [changedKey isURLField] == NO) {
        NSArray *pubs = [NSArray arrayWithObject:pub];
        [searchIndexes addPublications:pubs];
        [notesSearchIndex addPublications:pubs];
    }
    
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
    if (docState.isDocumentClosed == NO) {
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
    [groupOutlineView updateHighlights];
    BOOL fileViewEditable = [self isDisplayingFileContentSearch] == NO && [self hasExternalGroupsSelected] == NO && [[self selectedPublications] count] == 1;
    [sideFileView setEditable:fileViewEditable];
    [bottomFileView setEditable:fileViewEditable]; 
}

- (void)handleFlagsChangedNotification:(NSNotification *)notification{
    BOOL isOptionKeyState = ([NSApp currentModifierFlags] & NSAlternateKeyMask) != 0;
    
    if (docState.inOptionKeyState != isOptionKeyState) {
        docState.inOptionKeyState = isOptionKeyState;
        
        NSToolbarItem *toolbarItem = [toolbarItems objectForKey:@"BibDocumentToolbarNewItemIdentifier"];
        
        if (isOptionKeyState) {
            [groupAddButton setImage:[NSImage imageNamed:@"GroupAddSmart"]];
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
    [URL release];
    [string release];
    [super dealloc];
}

- (NSURL *)URL { return URL; }

- (NSString *)string { return string; }

@end

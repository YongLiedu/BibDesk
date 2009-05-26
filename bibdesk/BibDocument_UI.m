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
#import "BibItem.h"
#import "BDSKGroup.h"
#import "BDSKSearchGroup.h"
#import "BDSKLinkedFile.h"
#import <Quartz/Quartz.h>
#import <FileView/FileView.h>
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

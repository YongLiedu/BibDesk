//
//  BDSKFileMatcher.m
//  Bibdesk
//
//  Created by Adam Maxwell on 02/09/07.
/*
 This software is Copyright (c) 2007-2009
 Adam Maxwell. All rights reserved.
 
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

#import "BDSKFileMatcher.h"
#import "BibItem.h"
#import "BDSKTreeNode.h"
#import "BDSKTextWithIconCell.h"
#import "BDSKDocumentController.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "BibDocument_Actions.h"
#import "NSImage_BDSKExtensions.h"
#import "BibAuthor.h"
#import <libkern/OSAtomic.h>
#import "BDSKFileMatchConfigController.h"
#import "NSGeometry_BDSKExtensions.h"
#import "NSBezierPath_BDSKExtensions.h"
#import "BDSKLevelIndicatorCell.h"
#import "BDSKLinkedFile.h"
#import "NSParagraphStyle_BDSKExtensions.h"
#import "NSInvocation_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"

#define MAX_SEARCHKIT_RESULTS 10
static CGFloat LEAF_ROW_HEIGHT = 20.0;
static CGFloat GROUP_ROW_HEIGHT = 24.0;

@interface BDSKCountOvalCell : NSTextFieldCell
@end
@interface BDSKBoldShadowFormatter : BDSKTextWithIconFormatter
@end

@interface BDSKFileMatcher (Private)

- (NSArray *)currentPublications;
- (void)setCurrentPublications:(NSArray *)pubs;
- (NSArray *)copyTreeNodesWithCurrentPublications;
- (void)doSearch;
- (void)makeNewIndex;

// only use from main thread
- (void)updateProgressIndicatorWithNumber:(NSNumber *)val;

// entry point to the searching/matching; acquire indexingLock first
- (void)indexFiles:(NSArray *)absoluteURLs;

@end

@implementation BDSKFileMatcher

+ (id)sharedInstance;
{
    static id sharedInstance = nil;
    if (nil == sharedInstance)
        sharedInstance = [[self alloc] init];
    return sharedInstance;
}

- (id)init
{
    self = [super initWithWindowNibName:[self windowNibName]];
    if (self) {
        matches = [[NSMutableArray alloc] init];
        searchIndex = NULL;
        indexingLock = [[NSLock alloc] init];
        currentPublications = nil;
        _matchFlags.shouldAbortThread = 0;
    }
    return self;
}

- (NSString *)windowNibName { return @"FileMatcher"; }

- (void)dealloc
{
    [matches release];
    [indexingLock release];
    if (searchIndex)
        CFRelease(searchIndex);
    [super dealloc];
}

- (void)awakeFromNib
{
    [outlineView setAutosaveExpandedItems:YES];
    [outlineView setAutoresizesOutlineColumn:NO];

    BDSKTextWithIconCell *titleCell = [[BDSKTextWithIconCell alloc] initTextCell:@""];
    [titleCell setHasDarkHighlight:YES];
    [[outlineView tableColumnWithIdentifier:@"title"] setDataCell:titleCell];
    [titleCell release];
    
    BDSKLevelIndicatorCell *levelCell = [[BDSKLevelIndicatorCell alloc] initWithLevelIndicatorStyle:NSRelevancyLevelIndicatorStyle];
    [levelCell setMaxValue:(double)1.0];
    [levelCell setEnabled:NO];
    [levelCell setMaxHeight:(LEAF_ROW_HEIGHT * 0.7)];
    [[outlineView tableColumnWithIdentifier:@"score"] setDataCell:levelCell];
    [levelCell release];
    
    [outlineView setDoubleAction:@selector(openAction:)];
    [outlineView setTarget:self];
    [outlineView registerForDraggedTypes:[NSArray arrayWithObject:NSURLPboardType]];
    [progressIndicator setUsesThreadedAnimation:YES];
    [abortButton setEnabled:NO];
    [statusField setStringValue:@""];
}

- (void)outlineView:(NSOutlineView *)ov willDisplayOutlineCell:(id)cell forTableColumn:(NSTableColumn *)tc item:(id)item;
{
    NSButtonCell *outlineCell = cell;
    static NSImage *rightImage = nil;
    static NSImage *downImage = nil;
    
    // -[NSButtonCell setImage:] and -setAlternateImage: are apparently the only public ways to modify the indentation marker, and we can't do this with -[[ov outlineTableColumn] dataCell], since that seems to operate on the BDSKTextWithIconCell 
    if (nil == rightImage && [outlineCell image]) {
        NSSize size = [[outlineCell image] size];
        
        NSImage *image = [[NSImage alloc] initWithSize:size];
        [image lockFocus];
        [[NSColor clearColor] setFill];
        NSRect r = NSZeroRect;
        r.size = [image size];
        NSRectFill(r);
        r = NSInsetRect(r, 2.0, 2.0);
        NSBezierPath *bezierPath = [NSBezierPath bezierPath];
        [bezierPath moveToPoint:NSMakePoint(NSMinX(r), NSMinY(r))];
        [bezierPath lineToPoint:NSMakePoint(NSMinX(r), NSMaxY(r))];
        [bezierPath lineToPoint:NSMakePoint(NSMaxX(r), NSMidY(r))];
        [bezierPath closePath];
        [[NSColor colorWithCalibratedWhite:1.0 alpha:1.0] setFill];
        [bezierPath fill];
        [image unlockFocus];
        
        rightImage = [image copy];
        
        [image lockFocus];
        [[NSColor clearColor] setFill];
        r = NSZeroRect;
        r.size = [image size];
        NSRectFill(r);
        r = NSInsetRect(r, 2.0, 2.0);
        bezierPath = [NSBezierPath bezierPath];
        [bezierPath moveToPoint:NSMakePoint(NSMinX(r), NSMaxY(r))];
        [bezierPath lineToPoint:NSMakePoint(NSMaxX(r), NSMaxY(r))];
        [bezierPath lineToPoint:NSMakePoint(NSMidX(r), NSMinY(r))];
        [bezierPath closePath];
        [[NSColor colorWithCalibratedWhite:1.0 alpha:1.0] setFill];
        [bezierPath fill];
        [image unlockFocus];
        
        downImage = [image copy];
        [image release];
    }
    [outlineCell setImage:rightImage];
    [outlineCell setAlternateImage:downImage];
}

// API: try to match these files (pass nil for pubs to use the front document)
- (void)matchFiles:(NSArray *)absoluteURLs withPublications:(NSArray *)pubs;
{
    
    if (nil == pubs) {
        BibDocument *doc = [[NSDocumentController sharedDocumentController] mainDocument];
        if (nil == doc) {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"No front document", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"You need to open a document in order to match publications.", @"")];
            [alert runModal];
            return;
        }
        pubs = (id)[doc publications];
    }
    
    // for the progress indicator
    [[self window] makeKeyAndOrderFront:self];
    [abortButton setEnabled:YES];

    OSAtomicCompareAndSwap32Barrier(0, 1, &_matchFlags.shouldAbortThread);
    
    // block if necessary until the thread aborts
    [indexingLock lock];
    
    [matches removeAllObjects];
    [outlineView reloadData];

    // okay to set pubs here, since we have the lock
    [self setCurrentPublications:pubs];
    OSAtomicCompareAndSwap32Barrier(1, 0, &_matchFlags.shouldAbortThread);
    [NSThread detachNewThreadSelector:@selector(indexFiles:) toTarget:self withObject:absoluteURLs];
    
    // the first thing the thread will do is block until it acquires the lock, so let it go
    [indexingLock unlock];
}

- (IBAction)openAction:(id)sender;
{
    id clickedItem = [outlineView itemAtRow:[outlineView clickedRow]];
    id obj = [clickedItem valueForKey:@"pub"];
    if (obj && [[obj owner] respondsToSelector:@selector(editPub:)])
        [[obj owner] editPub:obj];
    else if ((obj = [clickedItem valueForKey:@"fileURL"]))
        [[NSWorkspace sharedWorkspace] openURL:obj withSearchString:[clickedItem valueForKey:@"searchString"]];
    else NSBeep();
}

- (IBAction)abort:(id)sender;
{
    if (false == OSAtomicCompareAndSwap32Barrier(0, 1, &_matchFlags.shouldAbortThread))
        NSBeep();
    [abortButton setEnabled:NO];
}

- (void)configSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)code contextInfo:(void *)context;
{
    BDSKFileMatchConfigController *config = (id)context;
    [config autorelease];
    [self matchFiles:[config files] withPublications:[config publications]];
}

- (IBAction)configure:(id)sender;
{
    BDSKFileMatchConfigController *config = [[BDSKFileMatchConfigController alloc] init];
    [config beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(configSheetDidEnd:returnCode:contextInfo:) contextInfo:config];
}

#pragma mark Outline view drag-and-drop

- (BOOL)outlineView:(NSOutlineView *)olv writeItems:(NSArray*)items toPasteboard:(NSPasteboard*)pboard;
{
    id item = [items lastObject];
    if ([item isLeaf]) {
        [pboard declareTypes:[NSArray arrayWithObject:NSURLPboardType] owner:nil];
        [[item valueForKey:@"fileURL"] writeToPasteboard:pboard];
        return YES;
    }
    return NO;
}

- (NSDragOperation)outlineView:(NSOutlineView*)olv validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)idx;
{
    if ([[info draggingSource] isEqual:outlineView] && [item isLeaf] == NO) {
        [olv setDropItem:item dropChildIndex:NSOutlineViewDropOnItemIndex];
        return NSDragOperationLink;
    }
    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView*)olv acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)idx;
{
    NSArray *types = [[info draggingPasteboard] types];
    NSURL *fileURL = ([types containsObject:NSURLPboardType] ? [NSURL URLFromPasteboard:[info draggingPasteboard]] : nil);
    if (nil == fileURL)
        return NO;
    
    BibItem *pub = [item valueForKey:@"pub"];
    [pub addFileForURL:fileURL autoFile:NO runScriptHook:YES];
    [[pub undoManager] setActionName:NSLocalizedString(@"Edit Publication", @"Undo action name")];
    return YES;
}

#pragma mark Delegate display methods

// return a larger row height for the items; tried using a spotlight controller image, but row size is too large to be practical
- (CGFloat)outlineView:(NSOutlineView *)ov heightOfRowByItem:(id)item
{
    return [item isLeaf] ? LEAF_ROW_HEIGHT : GROUP_ROW_HEIGHT;
}

- (BOOL)outlineView:(NSOutlineView *)ov shouldSelectItem:(id)item;
{
    return [item isLeaf];
}

// this allows us to return the count cell for top-level rows, since they have a count instead of a score
- (NSCell *)outlineView:(NSOutlineView *)ov dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSCell *cell = [tableColumn dataCell];
    if ([[tableColumn identifier] isEqualToString:@"score"]) {
        static id prototype = nil;
        if (nil == prototype) {
            prototype = [[BDSKCountOvalCell alloc] initTextCell:@""];
            [prototype setFont:[outlineView font]];
            [prototype setBordered:NO];
            [prototype setControlSize:[cell controlSize]];
        }
        if ([item isLeaf])
            cell = prototype;
    }
    return cell;
}

// change text appearance in top-level rows via a formatter, so we don't have to mess with custom text/icon cells
- (void)outlineView:(NSOutlineView *)ov willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item;
{
    if ([[tableColumn identifier] isEqualToString:@"title"]) {
        if ([item isLeaf]) {
            static BDSKTextWithIconFormatter *textWithIconFormatter = nil;
            if (nil == textWithIconFormatter)
                textWithIconFormatter = [[BDSKTextWithIconFormatter alloc] init];
            [cell setFormatter:textWithIconFormatter];
            [cell setTextColor:[NSColor blackColor]];
        } else {
            static BDSKBoldShadowFormatter *boldShadowFormatter = nil;
            if (nil == boldShadowFormatter)
                boldShadowFormatter = [[BDSKBoldShadowFormatter alloc] init];
            [cell setFormatter:boldShadowFormatter];
            [cell setTextColor:[NSColor whiteColor]];
        }
    }
}

#pragma mark Outline view datasource

- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)idx ofItem:(id)item;
{
    return nil == item ? [matches objectAtIndex:idx] : [item childAtIndex:idx];
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item;
{
    return item ? (NO == [item isLeaf]) : YES;
}

- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item;
{
    return item ? [item numberOfChildren] : [matches count];
}

- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item;
{
    return [[tableColumn identifier] isEqualToString:@"title"] ? item : [item valueForKey:@"score"];
}

- (id)outlineView:(NSOutlineView *)ov itemForPersistentObject:(id)object
{
    return [NSKeyedUnarchiver unarchiveObjectWithData:object];
}

// return archived item
- (id)outlineView:(NSOutlineView *)ov persistentObjectForItem:(id)item
{
    return [NSKeyedArchiver archivedDataWithRootObject:item];
}

@end

@implementation BDSKFileMatcher (Private)

- (NSArray *)currentPublications { return currentPublications; }
- (void)setCurrentPublications:(NSArray *)pubs;
{
    if (pubs != currentPublications) {
        [currentPublications release];
        // strangely, -[NSArray copy] gives us a deep copy, and copied pubs have a nil owner
        currentPublications = [[NSArray alloc] initWithArray:pubs copyItems:NO];
    }
}

static NSString *searchStringWithPub(BibItem *pub)
{
    // may be better ways to do this, but we'll try search for title and then append the first author's last name (if available) (note that we're not using phrase search at the moment, since it causes an occasional crash; that would require enclosing title in double quotes
    NSMutableString *searchString = [NSMutableString stringWithString:[[pub title] stringByRemovingTeX]];
    NSString *name = [[pub firstAuthorOrEditor] lastName];
    if (name)
        [searchString appendStrings:@" AND ", name, nil];
    return searchString;
}

static NSString *titleStringWithPub(BibItem *pub)
{
    return [NSString stringWithFormat:@"%@ (%@)", [pub displayTitle], [pub pubAuthorsForDisplay]];
}

// caller is reponsible for releasing the array, since the autorelease pool on the main thread may pop before the invocation's return value is requested
- (NSArray *)copyTreeNodesWithCurrentPublications;
{
    NSAssert([NSThread isMainThread], @"method must be called from the main thread");

    NSMutableArray *nodes = [[NSMutableArray alloc] initWithCapacity:[[self currentPublications] count]];
    for (BibItem *pub in [self currentPublications]) {
        BDSKTreeNode *theNode = [[BDSKTreeNode alloc] init];

        // we add the pub to the tree so it's retained, but don't touch it in the thread!
        [theNode setValue:pub forKey:@"pub"];
        
        // grab these strings on the main thread, since we need them in the worker thread
        [theNode setValue:titleStringWithPub(pub)  forKey:BDSKTextWithIconCellStringKey];
        [theNode setValue:searchStringWithPub(pub) forKey:@"searchString"];

        [theNode setValue:[NSImage imageNamed:@"cacheDoc"] forKey:BDSKTextWithIconCellImageKey];

        [nodes addObject:theNode];
        [theNode release];
    }
    return nodes;
}

// normalize scores on a per-parent basis
static void normalizeScoresForItem(BDSKTreeNode *parent, CGFloat maxScore)
{
    // nodes are shallow, so we only traverse 1 deep
    NSUInteger i, iMax = [parent numberOfChildren];
    for (i = 0; i < iMax; i++) {
        BDSKTreeNode *child = [parent childAtIndex:i];
        NSNumber *score = [child valueForKey:@"score"];
        if (score) {
            CGFloat oldValue = [score floatValue];
            double newValue = oldValue/maxScore;
            [child setValue:[NSNumber numberWithDouble:newValue] forKey:@"score"];
        }
    }
}

static NSComparisonResult scoreComparator(id obj1, id obj2, void *context)
{
    return [[obj2 valueForKey:@"score"] compare:[obj1 valueForKey:@"score"]];
}

// this method iterates available publications, trying to match them up with a file
- (void)doSearch;
{
    // get the root nodes array on the main thread, since it uses BibItem methods
    NSArray *treeNodes = nil;
    NSInvocation *invocation = [NSInvocation invocationWithTarget:self selector:@selector(copyTreeNodesWithCurrentPublications)];
    [invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:YES];
    [invocation getReturnValue:&treeNodes];
    [treeNodes autorelease];
    
    BDSKPOSTCONDITION([treeNodes count]);
        
    NSParameterAssert(NULL != searchIndex);
    SKIndexFlush(searchIndex);

    [self performSelectorOnMainThread:@selector(updateProgressIndicatorWithNumber:) withObject:[NSNumber numberWithDouble:(1.0)] waitUntilDone:NO];
    [statusField performSelectorOnMainThread:@selector(setStringValue:) withObject:[NSLocalizedString(@"Searching document", @"") stringByAppendingEllipsis] waitUntilDone:NO];

    double val = 0;
    double max = [treeNodes count];
    
    for (BDSKTreeNode *node in treeNodes) {
    
        if (_matchFlags.shouldAbortThread) break;
        
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        
        NSString *searchString = [node valueForKey:@"searchString"];
        
        SKSearchRef search = SKSearchCreate(searchIndex, (CFStringRef)searchString, kSKSearchOptionDefault);
        
        // if we get more than 10 matches back per pub, the results will be pretty useless anyway
        SKDocumentID docID[MAX_SEARCHKIT_RESULTS];
        CGFloat scores[MAX_SEARCHKIT_RESULTS];
        
        CFIndex numFound;
        
        Boolean moreToFind;
        CGFloat thisScore, maxScore = 0.0f;
        
        do {
            
            moreToFind = SKSearchFindMatches(search, MAX_SEARCHKIT_RESULTS, docID, scores, (CFTimeInterval)(MAX_SEARCHKIT_RESULTS/2.0), &numFound);
            
            if (numFound) {
                
                CFURLRef urls[MAX_SEARCHKIT_RESULTS];
                SKIndexCopyDocumentURLsForDocumentIDs(searchIndex, numFound, docID, urls);
                
                NSInteger i, iMax = numFound;
                
                // now we have a matching file; we could remove it from the index, but multiple matches are reasonable
                for (i =  0; i < iMax; i++) {
                    BDSKTreeNode *child = [[BDSKTreeNode alloc] init];
                    [child setValue:(id)urls[i] forKey:@"fileURL"];
                    [child setValue:[[(id)urls[i] path] stringByAbbreviatingWithTildeInPath] forKey:BDSKTextWithIconCellStringKey];
                    [child setValue:[[NSWorkspace sharedWorkspace] iconForFile:[(NSURL *)urls[i] path]] forKey:BDSKTextWithIconCellImageKey];
                    [child setValue:searchString forKey:@"searchString"];
                    thisScore = scores[i];
                    maxScore = MAX(maxScore, thisScore);
                    [child setValue:[NSNumber numberWithFloat:thisScore] forKey:@"score"];
                    [node addChild:child];
                    [child release];
                    CFRelease(urls[i]);
                }
                [matches addObject:node];
            }
            
        } while (numFound && moreToFind);
        
        SKSearchCancel(search);
        CFRelease(search);
        
        normalizeScoresForItem(node, maxScore);
        [node setValue:[NSString stringWithFormat:@"%ld", (long)[node numberOfChildren]] forKey:@"score"];
        [node sortChildrenUsingFunction:scoreComparator context:NULL];
        
        val++;
        [outlineView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
        [self performSelectorOnMainThread:@selector(updateProgressIndicatorWithNumber:) withObject:[NSNumber numberWithDouble:(val/max)] waitUntilDone:NO];
        [pool release];
    }
    
    if (0 == _matchFlags.shouldAbortThread) {
        [self performSelectorOnMainThread:@selector(updateProgressIndicatorWithNumber:) withObject:[NSNumber numberWithDouble:(1.0)] waitUntilDone:NO];
        [statusField performSelectorOnMainThread:@selector(setStringValue:) withObject:NSLocalizedString(@"Search complete!", @"") waitUntilDone:NO];
    } else {
        [statusField performSelectorOnMainThread:@selector(setStringValue:) withObject:NSLocalizedString(@"Search aborted.", @"") waitUntilDone:NO];
    }
}

- (void)makeNewIndex;
{
    if (searchIndex)
        CFRelease(searchIndex);
    CFMutableDataRef indexData = CFDataCreateMutable(CFAllocatorGetDefault(), 0);
    
    CFMutableDictionaryRef opts = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    // we generally shouldn't need to index the (default) first 2000 terms just to get title and author
    CFDictionaryAddValue(opts, kSKMaximumTerms, (CFNumberRef)[NSNumber numberWithInt:200]);
    
    // kSKProximityIndexing is unused for now, since it slows things down and caused a crash on one of my files rdar://problem/4988691 (fixed in 10.5)
    CFDictionaryAddValue(opts, kSKProximityIndexing, kCFBooleanTrue);
    searchIndex = SKIndexCreateWithMutableData(indexData, NULL, kSKIndexInverted, opts);
    CFRelease(opts);
    CFRelease(indexData);
}   

- (void)updateProgressIndicatorWithNumber:(NSNumber *)val;
{
    [progressIndicator setDoubleValue:[val doubleValue]];
}

- (void)indexFiles:(NSArray *)absoluteURLs;
{    
    NSAutoreleasePool *threadPool = [NSAutoreleasePool new];
    
    [indexingLock lock];
    
    // empty out a previous index (if any)
    [self makeNewIndex];
    
    double val = 0;
    double max = [absoluteURLs count];
    
    [self performSelectorOnMainThread:@selector(updateProgressIndicatorWithNumber:) withObject:[NSNumber numberWithDouble:(0.0)] waitUntilDone:NO];
    [statusField performSelectorOnMainThread:@selector(setStringValue:) withObject:[NSLocalizedString(@"Indexing files", @"") stringByAppendingEllipsis] waitUntilDone:NO];
    
    // some HTML files cause a deadlock or crash in -[NSHTMLReader _loadUsingLibXML2] rdar://problem/4988303 (fixed in 10.5)
    BOOL shouldLog = [[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKShouldLogFilesAddedToMatchingSearchIndex"];
    
    for (NSURL *url in absoluteURLs) {
        if (_matchFlags.shouldAbortThread) break;
        
        SKDocumentRef doc = SKDocumentCreateWithURL((CFURLRef)url);
        
        if (shouldLog)
            NSLog(@"%@", url);
        
        if (doc) {
            SKIndexAddDocument(searchIndex, doc, NULL, TRUE);
            CFRelease(doc);
        }
        // forcing a redisplay at every step is ok since adding documents to the index is pretty slow
        val++;      
        [self performSelectorOnMainThread:@selector(updateProgressIndicatorWithNumber:) withObject:[NSNumber numberWithDouble:(val/max)] waitUntilDone:NO];
    }
    
    if (0 == _matchFlags.shouldAbortThread) {
        [self performSelectorOnMainThread:@selector(updateProgressIndicatorWithNumber:) withObject:[NSNumber numberWithDouble:(1.0)] waitUntilDone:NO];
        [statusField performSelectorOnMainThread:@selector(setStringValue:) withObject:NSLocalizedString(@"Indexing complete!", @"") waitUntilDone:NO];
        [self doSearch];
    } else {
        [statusField performSelectorOnMainThread:@selector(setStringValue:) withObject:NSLocalizedString(@"Indexing aborted.", @"") waitUntilDone:NO];
    }

    // disable the stop button
    BOOL state = NO;
    NSInvocation *invocation = [NSInvocation invocationWithTarget:abortButton selector:@selector(setEnabled:) argument:&state];
    [invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:YES];
    
    [indexingLock unlock];
    [threadPool release];
}

@end

/* Returning an attributed string on a per-cell basis is easier than drawing a custom cell for each row, since we'd then have to handle the string drawing.  This way NSTextFieldCell still does all the rendering for us.  Color doesn't seem to work correctly for some reason, though.
*/

@implementation BDSKBoldShadowFormatter

static NSDictionary *attributes = nil;

+ (void)initialize
{
    BDSKINITIALIZE;
    NSMutableDictionary *newAttrs = [[NSMutableDictionary alloc] initWithCapacity:10];
    
    [newAttrs setObject:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]] forKey:NSFontAttributeName];
    [newAttrs setObject:[NSColor colorWithCalibratedWhite:1.0 alpha:1.0] forKey:NSForegroundColorAttributeName];
    [newAttrs setObject:[NSParagraphStyle defaultTruncatingTailParagraphStyle] forKey:NSParagraphStyleAttributeName];

    attributes = [newAttrs copy];
    [newAttrs release];
}

- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary *)attrs;
{
    NSMutableAttributedString *attrString = [[[NSMutableAttributedString alloc] initWithString:[self stringForObjectValue:obj]] autorelease];
    NSMutableDictionary *newAttrs = [attrs mutableCopy];
    [newAttrs addEntriesFromDictionary:attributes];
    [attrString addAttributes:newAttrs range:NSMakeRange(0, [attrString length])];
    [newAttrs release];
    return attrString;
}

@end

/* This cell draws a centered (horizontally and vertically) string, and surrounds the string with a filled oval. 
*/

@implementation BDSKCountOvalCell

static NSColor *fillColor = nil;

+ (void)initialize
{
    BDSKINITIALIZE;
    fillColor = [[[NSColor keyboardFocusIndicatorColor] colorWithAlphaComponent:0.8] copy];
}

- (id)initTextCell:(NSString *)string;
{
    self = [super initTextCell:string];
    if (self) {
        [self setAlignment:NSCenterTextAlignment];
        [self setTextColor:[NSColor whiteColor]];
    }
    return self;
}

// borrowed from RSVerticallyCenteredTextFieldCell at http://www.red-sweater.com/blog/148/what-a-difference-a-cell-makes
- (NSRect)drawingRectForBounds:(NSRect)theRect;
{
	// Get the parent's idea of where we should draw
	NSRect newRect = [super drawingRectForBounds:theRect];
    
	// Further mods needed if the cell is editable
    
    // Get our ideal size for current text
    NSSize textSize = [self cellSizeForBounds:theRect];
    
    // Center that in the proposed rect
    CGFloat heightDelta = newRect.size.height - textSize.height;	
    if (heightDelta > 0) {
        newRect.size.height -= heightDelta;
        newRect.origin.y += (heightDelta / 2);
    }
	
	return newRect;
}

@end

#pragma mark -

@implementation BDSKGroupingOutlineView

- (void)dealloc
{
    [topColor release];
    [bottomColor release];
    [super dealloc];
}

- (void)awakeFromNib
{
    if ([[BDSKGroupingOutlineView superclass] instancesRespondToSelector:_cmd])
        [super awakeFromNib];
    
    // colors similar to Spotlight's window: darker blue at bottom, lighter at top
    topColor = [[NSColor colorWithCalibratedRed:106.0/255.0 green:158.0/255.0 blue:238.0/255.0 alpha:1.0] retain];
    bottomColor = [[NSColor colorWithCalibratedRed:72.0/255.0 green:139.0/255.0 blue:244.0/255.0 alpha:1.0] retain];
}

// these accessors are bound to the hidden color wells in the nib, which allow playing with the colors easily
- (NSColor *)topColor
{
    return topColor;
}

- (void)setTopColor:(NSColor *)color
{
    if (topColor != color) {
        [topColor release];
        topColor = [color retain];
    }
}

- (void)setBottomColor:(NSColor *)color
{
    if (bottomColor != color) {
        [bottomColor release];
        bottomColor = [color retain];
    }
}

- (NSColor *)bottomColor 
{ 
    return bottomColor;
}

// grid looks silly when the table is empty
- (void)drawGridInClipRect:(NSRect)rect;
{
    if ([self numberOfRows])
        [super drawGridInClipRect:rect];
}

- (void)drawRow:(NSInteger)rowIndex clipRect:(NSRect)clipRect
{
    if ([self isExpandable:[self itemAtRow:rowIndex]]) {

        NSGradient *gradient;
        if ([self isFlipped])
            gradient = [[[NSGradient alloc] initWithStartingColor:topColor endingColor:bottomColor] autorelease];
        else
            gradient = [[[NSGradient alloc] initWithStartingColor:bottomColor endingColor:topColor] autorelease];
        [gradient drawInRect:[self rectOfRow:rowIndex] angle:90.0];
    }
    [super drawRow:rowIndex clipRect:clipRect];
}

-(void)_drawDropHighlightOnRow:(NSInteger)rowIndex{
    NSRect drawRect = (rowIndex == -1) ? [self visibleRect] : [self rectOfRow:rowIndex];
    
    [self lockFocus];
    [NSBezierPath drawHighlightInRect:drawRect radius:4.0 lineWidth:2.0 color:[NSColor whiteColor]];
    [self unlockFocus];
}

@end

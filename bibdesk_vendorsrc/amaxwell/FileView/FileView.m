//
//  FileView.m
//  FileViewTest
//
//  Created by Adam Maxwell on 06/23/07.
/*
 This software is Copyright (c) 2007
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

#import "FileView.h"
#import <QTKit/QTKit.h>
#import "FVIcon.h"
#import "FVIconQueue.h"
#import "FVPreviewer.h"
#import "FVArrowButton.h"

// functions for dealing with multiple URLs and weblocs on the pasteboard
static NSArray *URLSFromPasteboard(NSPasteboard *pboard);
static BOOL writeURLsToPasteboard(NSArray *URLs, NSPasteboard *pboard, PasteboardRef *pboardPtr);
static BOOL pasteboardHasType(NSPasteboard *pboard, NSString *aType);

@interface NSBezierPath (Leopard)
+ (NSBezierPath*)bezierPathWithRoundedRect:(NSRect)rect xRadius:(CGFloat)xRadius yRadius:(CGFloat)yRadius;
@end

@interface NSBezierPath (RoundRect)
+ (NSBezierPath*)bezierPathWithRoundRect:(NSRect)rect xRadius:(CGFloat)xRadius yRadius:(CGFloat)yRadius;
@end

enum {
    FVDropOnIcon,
    FVDropOnView,
    FVDropInsert
};
typedef NSUInteger FVDropOperation;

static NSString *FVWeblocFilePboardType = @"CorePasteboardFlavorType 0x75726C20";

static const NSSize DEFAULT_ICON_SIZE = { 64, 64 };
static const CGFloat DEFAULT_PADDING = 32;          // 16 per side

// don't bother removing icons from the cache if there are fewer than this value
static const NSUInteger ZOMBIE_CACHE_THRESHOLD = 100;

// thin the icons if we have more than this value; 25 is a good value, but 5 is good for cache testing
static const NSUInteger RELEASE_CACHE_THRESHOLD = 25;

// check the icon cache every five minutes and get rid of stale icons
static const CFTimeInterval ZOMBIE_TIMER_INTERVAL = 300.0;
static void zombieTimerFired(CFRunLoopTimerRef timer, void *context);

static NSDictionary *__textAttributes = nil;
static NSShadow *__shadow = nil;

@implementation FileView

+ (void)initialize {
    NSMutableDictionary *ta = [NSMutableDictionary dictionary];
    [ta setObject:[NSFont systemFontOfSize:12.0] forKey:NSFontAttributeName];
    [ta setObject:[NSColor darkGrayColor] forKey:NSForegroundColorAttributeName];
    NSMutableParagraphStyle *ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [ps setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [ps setAlignment:NSCenterTextAlignment];
    [ta setObject:ps forKey:NSParagraphStyleAttributeName];
    [ps release];
    __textAttributes = [ta copy];
    
    __shadow = [[NSShadow alloc] init];
    [__shadow setShadowOffset:NSMakeSize(2.0,-3.0)];
    [__shadow setShadowBlurRadius:5.0];
    
    // QTMovie raises if +initialize isn't sent on the AppKit thread
    [QTMovie class];
    
    // binding an NSSlider in IB 3 results in a crash on 10.4
    [self exposeBinding:@"iconScale"];
    [self exposeBinding:@"iconURLs"];
    [self exposeBinding:@"selectionIndexes"];
}

+ (NSColor *)defaultBackgroundColor
{
    // from Mail.app on 10.4
    CGFloat red = (231.0f/255.0f), green = (237.0f/255.0f), blue = (246.0f/255.0f);
    return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0];
}

+ (BOOL)accessInstanceVariablesDirectly { return NO; }

// not part of the API because padding is private, and that's a can of worms
- (CGFloat)_columnWidth { return _iconSize.width + _padding; }
- (CGFloat)_rowHeight { return _iconSize.height + _padding; }

static Boolean intEqual(const void *v1, const void *v2) { return v1 == v2; }
static CFStringRef intDesc(const void *value) { return (CFStringRef)[[NSString alloc] initWithFormat:@"%d", value]; }
static CFHashCode intHash(const void *value) { return (CFHashCode)value; }

- (void)_commonInit {
    _iconCache = [[NSMutableDictionary alloc] init];
    _iconSize = DEFAULT_ICON_SIZE;
    _padding = DEFAULT_PADDING;
    _lastMouseDownLocInView = NSZeroPoint;
    _dropRectForHighlight = NSZeroRect;
    _isRescaling = NO;
    _selectedIndexes = [[NSMutableIndexSet alloc] init];
    _rubberBandRect = NSZeroRect;
    _iconURLs = nil;
    [self setBackgroundColor:[[self class] defaultBackgroundColor]];
        
    // pass NULL for retain/release/description callbacks, so the timer does not retain the target and create a retain cycle
    CFRunLoopTimerContext timerContext = {  0, self, NULL, NULL, NULL };
    CFAllocatorRef alloc = CFAllocatorGetDefault();
    
    // I'm not removing the timer in viewWillMoveToSuperview:nil because we may need to free up that memory, and the frequency is so low that it's insignificant overhead
    CFAbsoluteTime fireTime = CFAbsoluteTimeGetCurrent() + ZOMBIE_TIMER_INTERVAL;
    // runloop will retain this timer, but we'll retain it too and release in -dealloc
    _zombieTimer = CFRunLoopTimerCreate(alloc, fireTime, ZOMBIE_TIMER_INTERVAL, 0, 0, zombieTimerFired, &timerContext);
    CFRunLoopAddTimer([[NSRunLoop currentRunLoop] getCFRunLoop], _zombieTimer, kCFRunLoopDefaultMode);
    
    _lastOrigin = NSZeroPoint;
    _timeOfLastOrigin = CFAbsoluteTimeGetCurrent();
    const CFDictionaryKeyCallBacks integerKeyCallBacks = { 0, NULL, NULL, intDesc, intEqual, intHash };
    const CFDictionaryValueCallBacks integerValueCallBacks = { 0, NULL, NULL, intDesc, intEqual };
    _trackingRectMap = CFDictionaryCreateMutable(alloc, 0, &integerKeyCallBacks, &integerValueCallBacks);
    
    _leftArrow = [[FVArrowButton alloc] initLeftArrowWithFrame:NSMakeRect(0.0, 0.0, 16.0, 16.0)];
    [_leftArrow setTarget:self];
    [_leftArrow setAction:@selector(leftArrowAction:)];
    
    _rightArrow = [[FVArrowButton alloc] initRightArrowWithFrame:NSMakeRect(0.0, 0.0, 16.0, 16.0)];
    [_rightArrow setTarget:self];
    [_rightArrow setAction:@selector(rightArrowAction:)];
    
    /*
     Add as subviews and setHidden.  
     
     If I use addSubview: when the mouse enters, it kills the tooltip on 10.5.  In the long run, it may be better to accept that limitation.  On 10.4, tooltips seem to interfere with the buttons in either case, causing the buttons to flicker when moving the mouse around; for now, I've decided to ignore that since it's evidently a bug.
     */
    [_leftArrow setHidden:YES];
    [self addSubview:_leftArrow];
    [_rightArrow setHidden:YES];
    [self addSubview:_rightArrow];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"selectionIndexes"]) {
        if ([FVPreviewer isPreviewing] && NSNotFound != [_selectedIndexes firstIndex])
            [FVPreviewer previewURL:[self iconURLAtIndex:[_selectedIndexes firstIndex]]];
        [self setNeedsDisplay:YES];
    }
}

#pragma mark NSView overrides

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    [self _commonInit];
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    [self _commonInit];
    return self;
}

- (void)dealloc
{
    [_leftArrow release];
    [_rightArrow release];
    [_iconURLs release];
    CFRunLoopTimerInvalidate(_zombieTimer);
    CFRelease(_zombieTimer);
    [_iconCache release];
    [_selectedIndexes release];
    [_backgroundColor release];
    // this variable is accessed in super's dealloc, so set it to NULL
    CFRelease(_trackingRectMap);
    _trackingRectMap = NULL;
    [super dealloc];
}

- (BOOL)isOpaque { return YES; }
- (BOOL)isFlipped { return YES; }

- (void)setBackgroundColor:(NSColor *)aColor;
{
    if (_backgroundColor != aColor) {
        [_backgroundColor release];
        _backgroundColor = [aColor copy];
    }
}

- (NSColor *)backgroundColor
{ 
    return _backgroundColor;
}

#pragma mark API

- (void)setIconScale:(CGFloat)scale;
{
    NSParameterAssert(scale > 0);
    _iconSize.width = DEFAULT_ICON_SIZE.width * scale;
    _iconSize.height = DEFAULT_ICON_SIZE.height * scale;
    // ??? magic number here...
    _padding = DEFAULT_PADDING + DEFAULT_PADDING * scale / 7;
    
    // the full view will likely need repainting
    [self reloadIcons];
    
    // Schedule a reload so we always have the correct quality icons, but don't do it while scaling in response to a slider.
    // This will also scroll to the first selected icon; maintaining scroll position while scaling is too jerky.
    if (NO == _isRescaling) {
        _isRescaling = YES;
        // this is only sent in the default runloop mode, so it's not sent during event tracking
        [self performSelector:@selector(_rescaleComplete) withObject:nil afterDelay:0.0];
    }
}

- (CGFloat)iconScale;
{
    return _iconSize.width / DEFAULT_ICON_SIZE.width;
}

- (void)awakeFromNib
{
    if ([[FileView superclass] instancesRespondToSelector:@selector(awakeFromNib)])
        [super awakeFromNib];
    
    // if the delegate connection is made in the nib, the drag type setup doesn't get done
    [self setDelegate:[self delegate]];
    [self setDataSource:[self dataSource]];
}

- (void)setDataSource:(id)obj;
{
    if (obj) {
        NSParameterAssert([obj respondsToSelector:@selector(numberOfIconsInFileView:)]);
        NSParameterAssert([obj respondsToSelector:@selector(fileView:URLAtIndex:)]);
    }
    _dataSource = obj;
    // convenient time to do this, although the timer would also handle it
    [_iconCache removeAllObjects];
}

- (BOOL)isEditable { return nil != [self delegate]; }

// must be unique to this instance
- (NSString *)_localDragType
{
    return [NSString stringWithFormat:@"com.mac.amaxwell.fileview.%p", self];
}

- (void)setDelegate:(id)obj;
{
    // assign before checking isEditable
    _delegate = obj;
    
    if ([self isEditable]) {
        
        [self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, [self _localDragType], NSURLPboardType, FVWeblocFilePboardType, (NSString *)kUTTypeURL, nil]];
        
        const SEL selectors[] = { 
            @selector(fileView:insertURLs:atIndexes:), @selector(fileView:replaceURLsAtIndexes:withURLs:),
            @selector(fileView:deleteURLsAtIndexes:),  @selector(fileView:moveURLsAtIndexes:toIndex:)
        };
        
        NSUInteger i = sizeof(selectors) / sizeof(SEL);
        while (i--)
            NSAssert1([obj respondsToSelector:selectors[i]], @"delegate must implement %@", NSStringFromSelector(selectors[i]));
    }
    else {
        // in case the view moved and/or we changed delegates
        [self registerForDraggedTypes:nil];
    }
}

- (id)dataSource { return _dataSource; }
- (id)delegate { return _delegate; }

- (NSUInteger)numberOfRows;
{
    NSUInteger nc = [self numberOfColumns];
    NSUInteger ni = [self numberOfIcons];
    NSUInteger r = ni % nc > 0 ? 1 : 0;
    return (ni/nc + r);
}

- (NSUInteger)numberOfColumns;
{
    return MAX(1, trunc((NSWidth([self frame]) - _padding) / [self _columnWidth]));
}

// This is the square rect the icon is drawn in.  It doesn't include padding, so rects aren't contiguous.
// Caller is responsible for any centering before drawing.
- (NSRect)_rectOfIconInRow:(NSUInteger)row column:(NSUInteger)column;
{
    NSPoint origin = [self frame].origin;
    CGFloat leftEdge = origin.x + _padding / 2 + ([self _columnWidth]) * column;
    CGFloat bottomEdge = origin.y + _padding / 2 + ([self _rowHeight]) * row;
    return NSMakeRect(leftEdge, bottomEdge, _iconSize.width, _iconSize.height);
}

static void _removeTrackingRectTagFromView(const void *key, const void *value, void *context)
{
    [(NSView *)context removeTrackingRect:(NSTrackingRectTag)key];
}

- (void)_removeAllTrackingRects
{
    if (_trackingRectMap) {
        CFDictionaryApplyFunction(_trackingRectMap, _removeTrackingRectTagFromView, self);
        CFDictionaryRemoveAllValues(_trackingRectMap);
    }
}

// We assume that all existing tracking rects and tooltips have been removed prior to invoking this method, so don't call it directly.  Use -[NSWindow invalidateCursorRectsForView:] instead.
- (void)_resetTrackingRectsAndToolTips
{    
    // no guarantee that we have a window, in which case these will all be wrong
    if (nil != [self window]) {
        NSUInteger r, rMin = 0, rMax = [self numberOfRows];
        NSUInteger c, cMin = 0, cMax = [self numberOfColumns];
        NSUInteger i, iMin = 0, iMax = [self numberOfIcons];
        
        for (r = rMin, i = iMin; r < rMax; r++) 
        {
            for (c = cMin; c < cMax && i < iMax; c++, i++) 
            {
                NSRect aRect = [self _rectOfIconInRow:r column:c];
                // Getting the location from the mouseEntered: event isn't reliable if you move the mouse slowly, so we either need to enlarge this tracking rect, or keep a map table of tag->index.  Since we have to keep a set of tags anyway, we'll use the latter method.
                NSTrackingRectTag tag = [self addTrackingRect:aRect owner:self userData:NULL assumeInside:NO];
                CFDictionarySetValue(_trackingRectMap, (const void *)tag, (const void *)i);
                
                // don't pass the URL as owner, as it's not retained; use the delegate method instead
                [self addToolTipRect:aRect owner:self userData:NULL];
            }
        }    
    }
}

// Here again, use -[NSWindow invalidateCursorRectsForView:] instead of calling this directly.
- (void)_discardTrackingRectsAndToolTips
{
    [self _removeAllTrackingRects];
    [self removeAllToolTips];    
}

/*  
   10.4 docs say "You need never invoke this method directly; it’s invoked automatically before the receiver's cursor rectangles are reestablished using resetCursorRects."
   10.5 docs say "You need never invoke this method directly; neither is it typically invoked during the invalidation of cursor rectangles. [...] This method is invoked just before the receiver is removed from a window and when the receiver is deallocated."
 
   This is a pretty radical change that makes -discardCursorRects sound pretty useless.  Maybe that explains why cursor rects have always sucked in Apple's apps and views?  Anyway, I'm explicitly discarding before resetting, just to be safe.  I'm also telling the window to invalidate cursor rects for this view explicitly whenever the grid changes due to number of icons or resize.  Even though I don't use cursor rects right now, this is a convenient funnel point for tracking rect handling.
 
   It is important to note that discardCursorRects /has/ to be safe during dealloc (hence the _trackingRectMap is explicitly set to NULL).
 
 */
- (void)discardCursorRects
{
    [super discardCursorRects];
    [self _discardTrackingRectsAndToolTips];
}

// automatically invoked as needed after -[NSWindow invalidateCursorRectsForView:]
- (void)resetCursorRects
{
    [super resetCursorRects];
    [self _discardTrackingRectsAndToolTips];
    [self _resetTrackingRectsAndToolTips];
}

- (void)reloadIcons;
{
    // grid may have changed, so do a full redisplay
    [self setNeedsDisplay:YES];
    // any time the grid or scale changes, cursor rects are garbage
    [[self window] invalidateCursorRectsForView:self];
}

#pragma mark Binding support

- (void)bind:(NSString *)binding toObject:(id)observable withKeyPath:(NSString *)keyPath options:(NSDictionary *)options;
{
    [super bind:binding toObject:observable withKeyPath:keyPath options:options];
    [self reloadIcons];
}

- (void)viewWillMoveToSuperview:(NSView *)newSuperview
{
    [super viewWillMoveToSuperview:newSuperview];
    
    // mmalc's example unbinds here for a nil superview, but that causes problems if you remove the view and add it back in later (and also can cause crashes as a side effect, if we're not careful with the datasource)
    if (nil == newSuperview) {
        [self removeObserver:self forKeyPath:@"selectionIndexes"];
    }
    else {
        [self addObserver:self forKeyPath:@"selectionIndexes" options:0 context:NULL];
    }
}

- (void)unbind:(NSString *)binding
{
    [super unbind:binding];
    [self reloadIcons];
}

- (void)setIconURLs:(NSArray *)anArray;
{
    [_iconURLs autorelease];
    _iconURLs = [anArray copy];
    // delegate/datasource methods all trigger a redisplay, so we have to do the same here
    [self reloadIcons];
}

- (NSArray *)iconURLs;
{
    return _iconURLs;
}

- (void)setSelectionIndexes:(NSIndexSet *)indexSet;
{
    NSParameterAssert(nil != indexSet);
    [_selectedIndexes autorelease];
    _selectedIndexes = [indexSet mutableCopy];
}

- (NSIndexSet *)selectionIndexes;
{
    return [[_selectedIndexes copy] autorelease];
}

#pragma mark Binding/datasource wrappers

// following two methods are for binding compatibility with the datasource methods

// this returns nil when the datasource or bound array returns NSNull, or else we end up with exceptions everywhere
- (NSURL *)iconURLAtIndex:(NSUInteger)anIndex
{
    NSURL *aURL = [[self iconURLs] objectAtIndex:anIndex];
    if (nil == aURL)
        aURL = [_dataSource fileView:self URLAtIndex:anIndex];
    if ([[NSNull null] isEqual:aURL])
        aURL = nil;
    return aURL;
}

- (NSUInteger)numberOfIcons
{
    return nil == _iconURLs ? [_dataSource numberOfIconsInFileView:self] : [_iconURLs count];
}

- (FVIcon *)_cachedIconForURL:(NSURL *)aURL;
{
    // delegate returns nil for nonexistent paths, so cache that in the dictionary as a normal key
    if (nil == aURL)
        aURL = (id)[NSNull null];
    
    // we don't cache paths, but we do cache icons
    FVIcon *icon = [_iconCache objectForKey:aURL];
    if (nil == icon) {
        icon = [FVIcon iconWithURL:aURL size:_iconSize];
        [_iconCache setObject:icon forKey:aURL];
    }
    return icon;
}

// use this instead of iterating _cachedIconForURL: when you want more than a few icons, since it may fetch in bulk
- (NSArray *)iconsAtIndexes:(NSIndexSet *)indexes
{
    NSMutableArray *icons = [NSMutableArray arrayWithCapacity:[indexes count]];
    if ([self iconURLs] != nil) {
        icons = (id)[_iconCache objectsForKeys:[[self iconURLs] objectsAtIndexes:indexes] 
                                notFoundMarker:[[FVIcon new] autorelease]];
    }
    else {
        NSUInteger anIndex = [indexes firstIndex];
        while (NSNotFound != anIndex) {
            [icons addObject:[self _cachedIconForURL:[self iconURLAtIndex:anIndex]]];
            anIndex = [indexes indexGreaterThanIndex:anIndex];
        }
    }
    return icons;
}

- (NSArray *)_selectedURLs
{
    NSMutableArray *array = [NSMutableArray array];
    NSUInteger idx = [_selectedIndexes firstIndex];
    while (NSNotFound != idx) {
        [array addObject:[self iconURLAtIndex:idx]];
        idx = [_selectedIndexes indexGreaterThanIndex:idx];
    }
    return array;
}

#pragma mark Drawing layout

// this method is called from -drawRect:, so it /must not/ mark rects as needing display
- (void)_recalculateGridSize
{
    NSUInteger nr = [self numberOfRows];
    NSUInteger nc = [self numberOfColumns];
    CGFloat w = ([self _columnWidth]) * nc + _padding / 2;
    // add one extra padding increment because we draw in the padding, plus a bit more so we always have whitespace around the bottom row
    CGFloat h = ([self _rowHeight]) * nr + 2.5 * _padding;
    
    NSClipView *cv = [[self enclosingScrollView] contentView];
    if (cv) {
        NSRect frame = [cv frame];
        if (h < NSHeight(frame))
            h = NSHeight(frame);
        
        if (w < NSWidth(frame))
            w = NSWidth(frame);
    }
    [self setFrameSize:NSMakeSize(w, h)];
    [self setFrameOrigin:NSZeroPoint];
}    

- (NSUInteger)_indexForGridRow:(NSUInteger)rowIndex column:(NSUInteger)colIndex;
{
    // nc * (r-1) + c
    // assumes all slots are filled, so check the length of the delegate's file array first
    NSUInteger fileIndex = rowIndex * [self numberOfColumns] + colIndex;
    return fileIndex >= [self numberOfIcons] ? NSNotFound : fileIndex;
}

- (BOOL)_getGridRow:(NSUInteger *)rowIndex column:(NSUInteger *)colIndex ofIndex:(NSUInteger)anIndex;
{
    NSUInteger cMax = [self numberOfColumns], rMax = [self numberOfRows];
    
    if (0 == cMax || 0 == rMax)
        return NO;

    // initialize all of these, in case we don't make it to the inner loop
    NSUInteger r, c = 0, i = 0;
    
    // iterate columns within each row
    for (r = 0; r < rMax && i <= anIndex; r++)
    {
        for (c = 0; c < cMax && i <= anIndex; c++) 
        {
            i++;
        }
    }
    
    // grid row/index are zero based
    r--;
    c--;

    if (i <= [self numberOfIcons]) {
        if (NULL != rowIndex)
            *rowIndex = r;
        if (NULL != colIndex)
            *colIndex = c;
        return YES;
    }
    return NO;
}

// this is only used for hit testing, so we should ignore padding
- (BOOL)_getGridRow:(NSUInteger *)rowIndex column:(NSUInteger *)colIndex atPoint:(NSPoint)point;
{
    // check for this immediately
    if (point.x <= _padding / 2 || point.y <= _padding / 2)
        return NO;
    
    // column width is padding + icon width
    // row height is padding + icon width
    NSUInteger idx, nc = [self numberOfColumns], nr = [self numberOfRows];
    
    idx = 0;
    CGFloat start;
    
    while (idx < nc) {
        
        start = _padding / 2 + (_iconSize.width + _padding) * idx;
        if (start < point.x && point.x < (start + _iconSize.width))
            break;
        idx++;
        
        if (idx == nc)
            return NO;
    }
    
    if (colIndex)
        *colIndex = idx;
    
    idx = 0;
    
    while (idx < nr) {
        
        start = _padding / 2 + (_iconSize.height + _padding) * idx;
        if (start < point.y && point.y < (start + _iconSize.height))
            break;
        idx++;
        
        if (idx == nr)
            return NO;
    }
    
    if (rowIndex)
        *rowIndex = idx;
    
    return YES;
}

#pragma mark Cache thread

- (void)_rescaleComplete;
{    
    NSUInteger scrollIndex = [_selectedIndexes firstIndex];
    if (NSNotFound != scrollIndex) {
        NSUInteger r, c;
        [self _getGridRow:&r column:&c ofIndex:scrollIndex];
        // this won't necessarily trigger setNeedsDisplay:, which we need unconditionally
        [self scrollRectToVisible:[self _rectOfIconInRow:r column:c]];
    }
    [self setNeedsDisplay:YES];
    _isRescaling = NO;
}

- (void)_updateThreadQueue:(NSArray *)icons;
{    
    if ([icons count])
        [[FVIconQueue sharedQueue] enqueueRenderIcons:icons forObject:self];
}

- (void)iconQueueUpdated;
{
    [self setNeedsDisplay:YES];
}

// drawRect: uses -releaseResources on icons that aren't visible but present in the datasource, so we just need a way to cull icons that are cached but not currently in the datasource
- (void)_handleZombieTimerCallback
{
    NSUInteger i, iMax = [self numberOfIcons];
    
    // don't do anything unless there's a meaningful discrepancy between the number of items reported by the datasource and our cache
    if ((iMax + ZOMBIE_CACHE_THRESHOLD) < [_iconCache count]) {
        
        NSMutableSet *iconURLsToKeep = [NSMutableSet set];
        
        if ([self iconURLs] != nil) {
            [iconURLsToKeep addObjectsFromArray:[self iconURLs]];
        }
        else {
            for (i = 0; i < iMax; i++) {
                NSURL *aURL = [self iconURLAtIndex:i];
                if (aURL) [iconURLsToKeep addObject:aURL];
            }
        }
        
        NSMutableSet *toRemove = [NSMutableSet setWithArray:[_iconCache allKeys]];
        [toRemove minusSet:iconURLsToKeep];
        
        // anything remaining in toRemove is not present in the dataSource, so remove it from the cache
        NSEnumerator *keyEnum = [toRemove objectEnumerator];
        NSURL *aURL;
        while (aURL = [keyEnum nextObject])
            [_iconCache removeObjectForKey:aURL];
    }
}

static void zombieTimerFired(CFRunLoopTimerRef timer, void *context)
{
    FileView *fv = (id)context;
    [fv _handleZombieTimerCallback];
}

#pragma mark Drawing

// no save/restore needed because of when these are called in -drawRect: (this is why they're private)

- (void)_drawDropHighlightInRect:(NSRect)aRect;
{
    [[[NSColor alternateSelectedControlColor] colorWithAlphaComponent:0.2] setFill];
    [[[NSColor alternateSelectedControlColor] colorWithAlphaComponent:0.8] setStroke];
    CGFloat lineWidth = 2.0;
    NSBezierPath *p;
    
    // if the rect is larger than the padding size, it's a drop on a cell or the entire rect
    if (NSWidth(aRect) > _padding) {
        p = [NSBezierPath bezierPathWithRoundRect:NSInsetRect(aRect, 0.5 * lineWidth, 0.5 * lineWidth) xRadius:7 yRadius:7];
    }
    else {
        
        // similar to NSTableView's between-row drop indicator
        NSRect rect = aRect;
        rect.size.height = NSWidth(aRect);
        rect.origin.y -= NSWidth(aRect);
        p = [NSBezierPath bezierPathWithOvalInRect:rect];
        
        NSPoint point = NSMakePoint(NSMidX(aRect), NSMinY(aRect));
        [p moveToPoint:point];
        point = NSMakePoint(NSMidX(aRect), NSMaxY(aRect));
        [p lineToPoint:point];
        
        rect = aRect;
        rect.origin.y = NSMaxY(aRect);
        rect.size.height = NSWidth(aRect);
        [p appendBezierPathWithOvalInRect:rect];
    }
    [p setLineWidth:lineWidth];
    [p setLineDash:NULL count:0 phase:0.0];
    [p stroke];
    [p fill];
}

- (void)_drawHighlightInRect:(NSRect)aRect;
{
    static NSColor *strokeColor = nil;
    static NSColor *fillColor = nil;
    if (nil == strokeColor) {
        strokeColor = [[NSColor colorWithCalibratedWhite:1.0 alpha:0.8] retain];
        fillColor = [[NSColor colorWithCalibratedWhite:0.0 alpha:0.2] retain];
    }
    [strokeColor setStroke];
    [fillColor setFill];
    NSBezierPath *p = [NSBezierPath bezierPathWithRoundRect:aRect xRadius:5 yRadius:5];
    [p setLineDash:NULL count:0 phase:0.0];
    [p setLineWidth:2.0f];
    [p fill];
    [p stroke];
}

- (void)_drawRubberbandRect
{
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.3] setFill];
    NSRect r = [self centerScanRect:NSInsetRect(_rubberBandRect, 0.5, 0.5)];
    NSRectFillUsingOperation(r, NSCompositeSourceOver);
    // NSFrameRect doesn't respect setStroke
    [[NSColor lightGrayColor] set];
    NSFrameRectWithWidth(r, 1.0);
}

- (void)_drawDropMessage;
{
    NSRect aRect = [self centerScanRect:NSInsetRect([self visibleRect], 20, 20)];
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundRect:aRect xRadius:10 yRadius:10];
    [path setLineWidth:3.0];
    CGFloat pattern[2] = { 12.0, 6.0 };
    
    // This sets all future paths to have a dash pattern, and it's not affected by save/restore gstate on Tiger.  Lame.
    [path setLineDash:pattern count:2 phase:0.0];
    [[NSColor lightGrayColor] setStroke];
    [path stroke];
    
    NSString *message = NSLocalizedString(@"Drop Files Here", @"placeholder message for empty file view");
    NSMutableAttributedString *attrString = [[[NSMutableAttributedString alloc] initWithString:message] autorelease];
    [attrString addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:24.0f] range:NSMakeRange(0, [attrString length])];
    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor lightGrayColor] range:NSMakeRange(0, [attrString length])];
    NSMutableParagraphStyle *ps = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [ps setAlignment:NSCenterTextAlignment];
    [attrString addAttribute:NSParagraphStyleAttributeName value:ps range:NSMakeRange(0, [attrString length])];
    
    NSRect r = [attrString boundingRectWithSize:aRect.size options:0];
    aRect.origin.y = (NSHeight(aRect) - NSHeight(r)) * 1 / 2;
    [attrString drawInRect:aRect];
}

// redraw at full quality after a resize
- (void)viewDidEndLiveResize
{
    [self reloadIcons];
}

// only invoked when autoscrolling or in response to user action
- (NSRect)adjustScroll:(NSRect)proposedVisibleRect
{
    NSRect r = [super adjustScroll:proposedVisibleRect];
    _timeOfLastOrigin = CFAbsoluteTimeGetCurrent();
    _lastOrigin = [self visibleRect].origin;
    return r;
}

// positive = scroller moving down
// negative = scroller moving upward
- (CGFloat)_scrollVelocity
{
    return ([self visibleRect].origin.y - _lastOrigin.y) / (CFAbsoluteTimeGetCurrent() - _timeOfLastOrigin);
}

// This method is conservative.  It doesn't test icon rects for intersection in the rect argument, but simply estimates the maximum range of rows and columns required for complete drawing in the given rect.  Hence, it can't be used for determining rubber band selection indexes or anything requiring a precise range (this is why it's private), but it's guaranteed to be fast.
- (void)_getRangeOfRows:(NSRange *)rowRange columns:(NSRange *)columnRange inRect:(NSRect)aRect;
{
    NSUInteger rmin, rmax, cmin, cmax;
    
    NSRect bounds = [self bounds];
    
    // account for padding around edges of the view
    bounds.origin.x += _padding / 2;
    bounds.origin.y += _padding / 2;
    
    rmin = (NSMinY(aRect) - NSMinY(bounds)) / [self _rowHeight];
    rmax = (NSMinY(aRect) - NSMinY(bounds)) / [self _rowHeight] + NSHeight(aRect) / [self _rowHeight];
    // add 1 to account for integer truncation
    rmax = MIN(rmax + 1, [self numberOfRows]);
    
    cmin = (NSMinX(aRect) - NSMinX(bounds)) / [self _columnWidth];
    cmax = (NSMinX(aRect) - NSMinX(bounds)) / [self _columnWidth] + NSWidth(aRect) / [self _columnWidth];
    // add 1 to account for integer truncation
    cmax = MIN(cmax + 1, [self numberOfColumns]);

    rowRange->location = rmin;
    rowRange->length = rmax - rmin;
    columnRange->location = cmin;
    columnRange->length = cmax - cmin; 
}

- (BOOL)_isFastScrolling { return ABS([self _scrollVelocity]) > 10000.0f; }

- (void)_scheduleIconsInRange:(NSRange)indexRange;
{
    NSMutableIndexSet *visibleIndexes = [NSMutableIndexSet indexSetWithIndexesInRange:indexRange];

    // this method is now called with only the icons being drawn, not necessarily everything that's visible; we need to compute visibility to avoid calling -releaseResources on the wrong icons
    NSRange visRows, visCols;
    [self _getRangeOfRows:&visRows columns:&visCols inRect:[self visibleRect]];
    NSUInteger iMin, iMax = [self numberOfIcons];
    
    // _indexForGridRow:column: returns NSNotFound if we're in a short row (empty column)
    iMin = [self _indexForGridRow:visRows.location column:visCols.location];
    if (NSNotFound == iMin)
        iMin = [self numberOfIcons];
    else
        iMax = MIN([self numberOfIcons], iMin + visRows.length * [self numberOfColumns]);
    
    if (iMax > iMin)
        [visibleIndexes addIndexesInRange:NSMakeRange(iMin, iMax - iMin)];
    
    NSMutableIndexSet *additionalIndexes = [NSMutableIndexSet indexSet];
    
    NSMutableArray *iconsToRender = [[NSMutableArray alloc] initWithArray:[self iconsAtIndexes:visibleIndexes]];
    CGFloat velocity = [self _scrollVelocity];
    
    // don't bother with the extra computation if the view isn't moving or we have no icons
    if ([visibleIndexes count] && ABS(velocity) > 10.0f) {
        
        NSUInteger nc = [self numberOfColumns];
        NSUInteger visibleRows = [visibleIndexes count] / nc;
        
        // this is a heuristic, and it's untuned so far
        
        // going down
        if (velocity > 0) { 
            NSUInteger lastIdx = [visibleIndexes lastIndex], newLast = MIN([self numberOfIcons] - 1, lastIdx + (visibleRows * nc));
            [additionalIndexes addIndexesInRange:NSMakeRange(lastIdx, newLast - lastIdx)];
        }
        else {
            // going up
            NSUInteger firstIdx = [visibleIndexes firstIndex], newFirst = visibleRows * nc;
            newFirst = firstIdx > newFirst ? firstIdx - newFirst : 0;
            [additionalIndexes addIndexesInRange:NSMakeRange(newFirst, firstIdx - newFirst)];
        }
    }
    
    if ([additionalIndexes count] > 0)
        [iconsToRender addObjectsFromArray:[self iconsAtIndexes:additionalIndexes]];
    
    NSUInteger cnt = [iconsToRender count];
    
    // if it doesn't need to be rendered, then remove it from this array
    
    // call needsRenderForSize: after initial display has taken place, since it may flush the icon's cache
    // this isn't obvious from the method name; it all takes place in a single op to avoid locking twice
    
    while (cnt--) {
        if ([[iconsToRender objectAtIndex:cnt] needsRenderForSize:_iconSize] == NO)
            [iconsToRender removeObjectAtIndex:cnt];
    }
    
    [self _updateThreadQueue:iconsToRender];
    [iconsToRender release];
    
    // Call this only for icons that we're not going to display "soon."  The problem with this approach is that if you only have a single icon displayed at a time (say in a master-detail view), FVIcon cache resources will continue to be used up since each one is cached and then never touched again (if it doesn't show up in this loop, that is).  We handle this by using a timer that culls icons which are no longer present in the datasource.  I suppose this is only a symptom of the larger problem of a view maintaining a cache of model objects...but expecting a client to be aware of our caching strategy and icon management is a bit much.  
    
    // Don't release resources while scrolling; caller has already checked -inLiveResize and _isRescaling for us

    if ([_iconCache count] > RELEASE_CACHE_THRESHOLD && NO == [self _isFastScrolling]) {
        
        // make sure we don't call this on any icons that we just added to the render queue
        NSMutableIndexSet *unusedIndexes = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfIcons])];
        [unusedIndexes removeIndexes:visibleIndexes];
        [unusedIndexes removeIndexes:additionalIndexes];

        if ([unusedIndexes count]) {
            [[FVIconQueue sharedQueue] enqueueReleaseResourcesForIcons:[self iconsAtIndexes:unusedIndexes]];
        }
        
    }
}

- (void)_drawIconsInRange:(NSRange)indexRange rows:(NSRange)rows columns:(NSRange)columns
{
    BOOL isResizing = [self inLiveResize];

    NSUInteger r, rMin = rows.location, rMax = NSMaxRange(rows);
    NSUInteger c, cMin = columns.location, cMax = NSMaxRange(columns);
    NSUInteger i, iMin = indexRange.location, iMax = NSMaxRange(indexRange);
        
    NSGraphicsContext *ctxt = [NSGraphicsContext currentContext];
    CGContextRef cgContext = [ctxt graphicsPort];
    CGContextSetBlendMode(cgContext, kCGBlendModeNormal);
    
    // don't limit quality based on scrolling unless we really need to
    if (isResizing || _isRescaling) {
        CGContextSetInterpolationQuality(cgContext, kCGInterpolationNone);
        CGContextSetShouldAntialias(cgContext, false);
    }
    else if (_iconSize.height > 256) {
        CGContextSetInterpolationQuality(cgContext, kCGInterpolationHigh);
        CGContextSetShouldAntialias(cgContext, true);
    }
    else {
        CGContextSetInterpolationQuality(cgContext, kCGInterpolationDefault);
        CGContextSetShouldAntialias(cgContext, true);
    }
            
    // we should use the fast path when scrolling at small sizes; PDF sucks in that case...
    
    BOOL useFastDrawingPath = (isResizing || _isRescaling || ([self _isFastScrolling] && _iconSize.height <= 256));
    
    // iterate each row/column to see if it's in the dirty rect, and evaluate the current cache state
    for (r = rMin, i = iMin; r < rMax; r++) 
    {
        for (c = cMin; c < cMax && i < iMax; c++, i++) 
        {
            // @@ i hate continue...
            // don't draw icons that aren't selected if we're creating a drag image
            if (_isDrawingDragImage && [_selectedIndexes containsIndex:i] == NO)
                continue;
            
            NSRect fileRect = [self _rectOfIconInRow:r column:c];
            
            NSURL *aURL = [self iconURLAtIndex:i];
            
            // allow some extra for the shadow
            BOOL willDrawIcon = [self needsToDrawRect:NSInsetRect(fileRect, -5, -5)];
            FVIcon *image = [self _cachedIconForURL:aURL];
            
            // note that iconRect will be transformed for a flipped context
            NSRect iconRect = fileRect;
            
            NSRect textRect = fileRect;
            textRect.origin.y += NSHeight(iconRect);
            textRect.size.height = _padding;
            // allow the text rect to extend outside the grid cell
            textRect = NSInsetRect(textRect, -_padding / 3, 2.0);
            
            BOOL willDrawText = [self needsToDrawRect:textRect];
            
            // avoid redraw all of the icons           
            if (willDrawIcon) {
                
                // draw highlight, then draw icon over it, as Finder does
                if ([_selectedIndexes containsIndex:i])
                    [self _drawHighlightInRect:NSInsetRect(fileRect, -4, -4)];
                
                CGContextSaveGState(cgContext);
                
                // draw a shadow behind the image/page
                [__shadow set];
                
                // possibly better performance by caching all bitmaps in a flipped state, but bookkeeping is a pain
                CGContextTranslateCTM(cgContext, 0, NSMaxY(iconRect));
                CGContextScaleCTM(cgContext, 1, -1);
                iconRect.origin.y = 0;
                iconRect = [self centerScanRect:iconRect];
                
                // Note: let the icon handle making the rect integral and scaling the icon proportionally
                
                if (useFastDrawingPath)
                    [image fastDrawInRect:iconRect inCGContext:cgContext];
                else
                    [image drawInRect:iconRect inCGContext:cgContext];

                CGContextRestoreGState(cgContext);
            }
            
            if (willDrawText) {
                CGContextSaveGState(cgContext);
                
                // @@ this is a hack for drawing into the drag image context
                if (NO == [ctxt isFlipped]) {
                    CGContextTranslateCTM(cgContext, 0, NSMaxY(textRect));
                    CGContextScaleCTM(cgContext, 1, -1);
                    textRect.origin.y = 0;
                }
                textRect = [self centerScanRect:textRect];
                
                // draw text over the icon/shadow
                NSString *name = [aURL isFileURL] ? [[aURL path] lastPathComponent] : [aURL absoluteString];
#if 1
                [name drawInRect:textRect withAttributes:__textAttributes];  
#else
                NSRect tr = textRect;
                textRect.origin.y += NSHeight(textRect);
                NSStringDrawingOptions opts = NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine;
                [name drawWithRect:tr options:opts attributes:__textAttributes];
#endif
                CGContextRestoreGState(cgContext);
            }            
        }
    }
    
    // avoid hitting the cache thread while a live resize is in progress, but allow cache updates while scrolling
    // use the same range criteria that we used in iterating icons
    if (NO == isResizing && NO == _isRescaling)
        [self _scheduleIconsInRange:NSMakeRange(iMin, iMax - iMin)];
}

- (void)drawRect:(NSRect)rect;
{
    NSRect visRect = [self visibleRect];
    [self _recalculateGridSize];
    
    // downscaling changes the view origin, so enlarge the rect if needed after _recalculateGridSize
    if (_isRescaling) {
        CGFloat dy = visRect.origin.y - [self visibleRect].origin.y;
        CGFloat dx = visRect.origin.x - [self visibleRect].origin.x;
        if (dy > 0 || dx > 0)
            rect = NSInsetRect(rect, -dx, -dy);
    }

    [super drawRect:rect];

    [[self backgroundColor] setFill];
    NSRectFillUsingOperation(rect, NSCompositeCopy);
    
    // Only iterate icons in the visible range, since we know the overall geometry
    NSRange rowRange, columnRange;
    [self _getRangeOfRows:&rowRange columns:&columnRange inRect:rect];
    
    NSUInteger iMin, iMax = [self numberOfIcons];
    
    // _indexForGridRow:column: returns NSNotFound if we're in a short row (empty column)
    iMin = [self _indexForGridRow:rowRange.location column:columnRange.location];
    if (NSNotFound == iMin)
        iMin = [self numberOfIcons];
    else
        iMax = MIN([self numberOfIcons], iMin + rowRange.length * [self numberOfColumns]);

    // only draw icons if we actually have some in this rect
    if (iMax > iMin) {
        [self _drawIconsInRange:NSMakeRange(iMin, iMax - iMin) rows:rowRange columns:columnRange];
    }
    else if (0 == iMax && [self isEditable]) {
        [[NSGraphicsContext currentContext] setShouldAntialias:YES];
        [self _drawDropMessage];
    }
    
    // drop highlight and rubber band are mutually exclusive
    if (NSIsEmptyRect(_dropRectForHighlight) == NO) {
        [self _drawDropHighlightInRect:[self centerScanRect:_dropRectForHighlight]];
    }
    else if (NSIsEmptyRect(_rubberBandRect) == NO) {
        [self _drawRubberbandRect];
    }
}

#pragma mark Drag source

// called after namesOfPromisedFilesDroppedAtDestination:
- (void)draggedImage:(NSImage *)image endedAt:(NSPoint)screenPoint operation:(NSDragOperation)operation;
{
    // only called if we originated the drag, so the row/column must be valid
    if ((operation & NSDragOperationDelete) != 0) {
        [[self delegate] fileView:self deleteURLsAtIndexes:_selectedIndexes];
        [self setSelectionIndexes:[NSIndexSet indexSet]];
        [self reloadIcons];
    }
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    return isLocal ? NSDragOperationLink | NSDragOperationMove : NSDragOperationCopy | NSDragOperationDelete;
}

- (void)dragImage:(NSImage *)anImage at:(NSPoint)viewLocation offset:(NSSize)unused event:(NSEvent *)event pasteboard:(NSPasteboard *)pboard source:(id)sourceObj slideBack:(BOOL)slideFlag;
{        
    // we want the lower left corner of the scrollview, converted to this view's coordinates
    
    // upper left
    NSPoint p = [[self enclosingScrollView] bounds].origin;
    // lower left
    p.y += NSHeight([[self enclosingScrollView] bounds]);
    p = [[self enclosingScrollView] convertPoint:p toView:self];
    
    // this will force a redraw of the entire area into the cached image
    NSRect bounds = [[self enclosingScrollView] documentVisibleRect];

    NSBitmapImageRep *imageRep = [self bitmapImageRepForCachingDisplayInRect:bounds];
    
    // temporarily set the background color to clear, and set a flag so only the selected icons are drawn
    NSColor *c = [[self backgroundColor] retain];
    [self setBackgroundColor:[NSColor clearColor]];
    _isDrawingDragImage = YES;
    
    // this is not the recommended way to draw into a bitmap context, but the CTM isn't set up properly using the AppKit's mechanism as far as I can tell, so I can't make use of the higher-level drawing routines
    NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsContext];
    CGContextRef cgContext = [nsContext graphicsPort];
    CGContextTranslateCTM(cgContext, 0, NSMaxY(bounds));
    CGContextScaleCTM(cgContext, 1, -1);
    [self drawRect:bounds];
    
    // reset flag and restore background color
    _isDrawingDragImage = NO;
    [self setBackgroundColor:c];
    [c release];
    [NSGraphicsContext restoreGraphicsState];

    NSImage *newImage = [[[NSImage alloc] initWithSize:bounds.size] autorelease];
    [newImage addRepresentation:imageRep];
    
    // redraw with transparency, so it's easier to see a target
    anImage = [[[NSImage alloc] initWithSize:bounds.size] autorelease];
    [anImage lockFocus];
    [newImage drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:0.7];
    [anImage unlockFocus];
    newImage = anImage;
    
    [super dragImage:newImage at:p offset:unused event:event pasteboard:pboard source:sourceObj slideBack:slideFlag];
}

#pragma mark Event handling

- (BOOL)acceptsFirstResponder { return YES; }

- (BOOL)canBecomeKeyView { return YES; }

- (void)_updateButtonsForIcon:(FVIcon *)anIcon;
{
    NSUInteger curPage = [anIcon currentPageIndex];
    if (curPage == [anIcon pageCount]) {
        [_leftArrow setEnabled:YES];
        [_rightArrow setEnabled:NO];
    }
    else if (curPage == 1) {
        [_leftArrow setEnabled:NO];
        [_rightArrow setEnabled:YES];
    }
    else {
        [_leftArrow setEnabled:YES];
        [_rightArrow setEnabled:YES];
    }    
}

- (void)leftArrowAction:(id)sender
{
    FVIcon *anIcon = [[sender cell] representedObject];
    [anIcon showPreviousPage];
    [self _updateButtonsForIcon:anIcon];
    [self setNeedsDisplay:YES];
}

- (void)rightArrowAction:(id)sender
{
    FVIcon *anIcon = [[sender cell] representedObject];
    [anIcon showNextPage];
    [self _updateButtonsForIcon:anIcon];
    [self setNeedsDisplay:YES];
}

- (void)mouseEntered:(NSEvent *)event;
{
    NSUInteger r, c, anIndex;
    const NSTrackingRectTag tag = [event trackingNumber];
    
    if (CFDictionaryGetValueIfPresent(_trackingRectMap, (const void *)tag, (const void **)&anIndex) &&
        [self _getGridRow:&r column:&c ofIndex:anIndex]) {
        
        FVIcon *anIcon = [self _cachedIconForURL:[self iconURLAtIndex:anIndex]];
        
        if ([anIcon pageCount] > 1) {
        
            NSRect iconRect = [self _rectOfIconInRow:r column:c];
            
            NSRect leftRect = NSZeroRect, rightRect = NSZeroRect;
            
            // determine a min/max size for the arrow buttons
            CGFloat side = roundf(NSHeight(iconRect) / 5);
            side = MIN(side, 32);
            side = MAX(side, 10);
            leftRect.size = NSMakeSize(side, side);
            rightRect.size = NSMakeSize(side, side);
            
            // 2 pixels between arrows horizontally, and 4 pixels between bottom of arrow and bottom of iconRect
            leftRect.origin = NSMakePoint(NSMidX(iconRect) - 2 - NSWidth(leftRect), NSMaxY(iconRect) - NSHeight(leftRect) - 4);
            rightRect.origin = NSMakePoint(NSMidX(iconRect) + 2, NSMaxY(iconRect) - NSHeight(rightRect) - 4);
            
            [_leftArrow setFrame:leftRect];
            [[_leftArrow cell] setRepresentedObject:anIcon];
            [_rightArrow setFrame:rightRect];
            [[_rightArrow cell] setRepresentedObject:anIcon];
            
            // set enabled states
            [self _updateButtonsForIcon:anIcon];
            [_leftArrow setHidden:NO];
            [_rightArrow setHidden:NO];
            // adding buttons as subviews here seems to kill the tooltips; maybe that's good, though...they can easily hide the arrow buttons, depending on where the mouse enters
        }
    }
    
    // !!! calling this before adding buttons seems to disable the tooltip on 10.4; what does it do on 10.5?
    [super mouseEntered:event];
}

- (void)mouseExited:(NSEvent *)event;
{
    [super mouseExited:event];
    [_leftArrow setHidden:YES];
    [_rightArrow setHidden:YES];
}

- (NSURL *)_URLAtPoint:(NSPoint)point;
{
    NSUInteger anIndex = NSNotFound, r, c;
    if ([self _getGridRow:&r column:&c atPoint:point])
        anIndex = [self _indexForGridRow:r column:c];
    return NSNotFound == anIndex ? nil : [self iconURLAtIndex:anIndex];
}

- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)userData
{
    NSURL *theURL = [self _URLAtPoint:point];
    return [theURL isFileURL] ? [[theURL path] stringByAbbreviatingWithTildeInPath] : [theURL absoluteString];
}

// this method and shouldDelayWindowOrderingForEvent: are overriden to allow dragging from the view without making our window key
- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    return ([self _URLAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]] != nil);
}

- (BOOL)shouldDelayWindowOrderingForEvent:(NSEvent *)event
{
    return ([self _URLAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]] != nil);
}

- (void)keyDown:(NSEvent *)event
{
    NSString *chars = [event characters];
    if ([chars length] > 0) {
        unichar ch = [[event characters] characterAtIndex:0];
        NSUInteger flags = [event modifierFlags];
        
        switch(ch) {
            case 0x0020:
                if ((flags & NSShiftKeyMask) != 0)
                    [[self enclosingScrollView] pageUp:self];
                else
                    [[self enclosingScrollView] pageDown:self];
                break;
            default:
                [self interpretKeyEvents:[NSArray arrayWithObject:event]];
        }
    }
    else {
        // no character, so pass it to the next responder
        [super keyDown:event];
    }
}

- (void)mouseDown:(NSEvent *)event
{
    NSPoint p = [event locationInWindow];
    p = [self convertPoint:p fromView:nil];
    _lastMouseDownLocInView = p;

    NSUInteger flags = [event modifierFlags];
    
    NSUInteger r, c, i;
    
    // mark this icon for highlight if necessary
    if ([self _getGridRow:&r column:&c atPoint:p]) {
        
        // remember _indexForGridRow:column: returns NSNotFound if you're in an empty slot of an existing row/column, but that's a deselect event so we still need to remove all selection indexes and mark for redisplay
        i = [self _indexForGridRow:r column:c];
        
        if ([_selectedIndexes containsIndex:i] == NO) {
            
            // deselect all if command key was not pressed, or i == NSNotFound
            if ((flags & NSCommandKeyMask) == 0 || NSNotFound == i) {
                [self setSelectionIndexes:[NSIndexSet indexSet]];
            }
            
            // add to the current selection (which we may have just reset)
            if (NSNotFound != i) {
                [self willChangeValueForKey:@"selectionIndexes"];
                [_selectedIndexes addIndex:i];
                [self didChangeValueForKey:@"selectionIndexes"];
                [self setNeedsDisplay:YES];     
            }
        }
        else if ((flags & NSCommandKeyMask) != 0) {
            // cmd-clicked a previously selected index, so remove it from the selection
            [self willChangeValueForKey:@"selectionIndexes"];
            [_selectedIndexes removeIndex:i];
            [self didChangeValueForKey:@"selectionIndexes"];
            [self setNeedsDisplay:YES];
        }
        
        // change selection first, as Finder does
        if ([event clickCount] > 1 && [self _URLAtPoint:p] != nil)
            [[NSWorkspace sharedWorkspace] openURL:[self _URLAtPoint:p]];

    }
    else if ([_selectedIndexes count]) {
        // deselect all, since we had a previous selection and clicked on a non-icon area
        [self setSelectionIndexes:[NSIndexSet indexSet]];
    }
    else {
        [super mouseDown:event];
    }    
}

static NSRect _rectWithCorners(NSPoint aPoint, NSPoint bPoint) {
    NSRect rect;
    rect.origin.x = MIN(aPoint.x, bPoint.x);
    rect.origin.y = MIN(aPoint.y, bPoint.y);
    rect.size.width = MAX(aPoint.x, bPoint.x) - NSMinX(rect);
    rect.size.height = MAX(aPoint.y, bPoint.y) - NSMinY(rect);
    return rect;
}

- (NSIndexSet *)_allIndexesInRubberBandRect
{
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    
    // do a fast check to avoid hit testing every icon in the grid
    NSRange rowRange, columnRange;
    [self _getRangeOfRows:&rowRange columns:&columnRange inRect:_rubberBandRect];
            
    // this is a useful test to see exactly what _getRangeOfRows:columns:inRect: is giving us
    /*
     // _indexForGridRow:column: returns NSNotFound if we're in a short row (empty column)
     NSUInteger iMin = [self _indexForGridRow:rowRange.location column:columnRange.location];
     if (NSNotFound == iMin)
     iMin = 0;
     
     NSUInteger i, j = iMin, nc = [self numberOfColumns];
     for (i = 0; i < rowRange.length; i++) {
         [indexSet addIndexesInRange:NSMakeRange(j, columnRange.length)];
         j += nc;
     }
     return indexSet;
    */
    
    NSUInteger r, rMax = NSMaxRange(rowRange);
    NSUInteger c, cMax = NSMaxRange(columnRange);
    
    NSUInteger idx;
    
    // now iterate each row/column to see if it intersects the rect
    for (r = rowRange.location; r < rMax; r++) 
    {
        for (c = columnRange.location; c < cMax; c++) 
        {    
            if (NSIntersectsRect([self _rectOfIconInRow:r column:c], _rubberBandRect)) {
                idx = [self _indexForGridRow:r column:c];
                if (NSNotFound != idx)
                    [indexSet addIndex:idx];
            }
        }
    }
    
    return indexSet;
}

- (void)mouseUp:(NSEvent *)event
{
    if (NO == NSIsEmptyRect(_rubberBandRect)) {
        _rubberBandRect = NSZeroRect;
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseDragged:(NSEvent *)event
{
    // in mouseDragged:, we're either drawing a rubber band selection or initiating a drag
    
    NSArray *selectedURLs = nil;
    NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
    NSURL *pointURL = [self _URLAtPoint:p];

    // No previous rubber band selection, so check to see if we're dragging an icon at this point.
    // The condition is also false when we're getting a repeated call to mouseDragged: for rubber band drawing.
    if (NSIsEmptyRect(_rubberBandRect) && nil != pointURL) {
                
        // we may have a selection based on a previous rubber band, but only use that if we dragged one of the icons in it
        selectedURLs = [self _selectedURLs];
        if ([selectedURLs containsObject:pointURL] == NO) {
            selectedURLs = nil;
            [self setSelectionIndexes:[NSIndexSet indexSet]];
        }
        
        NSUInteger i, r, c;

        // not using a rubber band, so select and use the clicked URL if available (mouseDown: should have already done this)
        if (0 == [selectedURLs count] && nil != pointURL && [self _getGridRow:&r column:&c atPoint:p]) {
            selectedURLs = [NSArray arrayWithObject:pointURL];
            i = [self _indexForGridRow:r column:c];
            [self setSelectionIndexes:[NSIndexSet indexSetWithIndex:i]];
        }
        
        // if we have anything to drag, start a drag session
        if ([selectedURLs count]) {
            
            NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
            
            // add all URLs (file and other schemes)
            // Finder will create weblocs for us unless schemes are mixed (gives a stupid file busy error message)
            
            PasteboardRef carbonPboard;
            if (writeURLsToPasteboard(selectedURLs, pboard, &carbonPboard)) {
            
                // using the Carbon pboard seems to screw up our call to -types on Tiger, since the private type isn't listed (although it shows up in PasteboardPeeker)
                CFDataRef data = (CFDataRef)[@"What are /you/ looking at, pervert?" dataUsingEncoding:NSUTF8StringEncoding];
                    
                // any pointer type; private to the creating application
                PasteboardItemID itemID = (void *)[self _localDragType];
                PasteboardPutItemFlavor(carbonPboard, itemID, (CFStringRef)[self _localDragType], data, kPasteboardFlavorNoFlags);
                if (NULL != carbonPboard)
                    CFRelease(carbonPboard);

                // OK to pass nil for the image, since we totally ignore it anyway
                [self dragImage:nil at:p offset:NSZeroSize event:event pasteboard:pboard source:self slideBack:YES];
            }
        }
        else {
            [super mouseDragged:event];
        }
        
    }
    else {   
        
        // no icons to drag, so we must draw the rubber band rectangle
        _rubberBandRect = _rectWithCorners(_lastMouseDownLocInView, p);
        [self setSelectionIndexes:[self _allIndexesInRubberBandRect]];
        [self setNeedsDisplay:YES];
        [self autoscroll:event];
        [super mouseDragged:event];
    }
}

- (NSURL *)URLForLastMouseDown
{
    return [self _URLAtPoint:_lastMouseDownLocInView];
}

#pragma mark Drop target

- (BOOL)_isLocalDraggingInfo:(id <NSDraggingInfo>)sender
{
    return pasteboardHasType([sender draggingPasteboard], [self _localDragType]);
}

// get lots of updates for autoscrolling
- (BOOL)wantsPeriodicDraggingUpdates { return YES; }

- (FVDropOperation)_dropOperationAtPointInView:(NSPoint)point highlightRect:(NSRect *)dropRect insertionIndex:(NSUInteger *)anIndex
{
    NSUInteger r, c;
    FVDropOperation op;
    NSRect aRect;
    NSUInteger insertIndex = NSNotFound;

    if ([self _getGridRow:&r column:&c atPoint:point]) {
        
        // check to avoid highlighting empty cells as individual icons; that's a DropOnView, not DropOnIcon

        if ([self _indexForGridRow:r column:c] > [self numberOfIcons]) {
            aRect = [self visibleRect];
            op = FVDropOnView;
        }
        else {
            aRect = [self _rectOfIconInRow:r column:c];
            op = FVDropOnIcon;
        }
    }
    else {
            
        NSPoint left = NSMakePoint(point.x - _iconSize.width, point.y), right = NSMakePoint(point.x + _iconSize.width, point.y);
        
        // can't insert between nonexisting cells either, so check numberOfIcons first...

        if ([self _getGridRow:&r column:&c atPoint:left] && ([self _indexForGridRow:r column:c] < [self numberOfIcons])) {
            
            aRect = [self _rectOfIconInRow:r column:c];
            // rect size is 1/5 of padding, and should be centered between icons vertically
            aRect.origin.x += _iconSize.width + _padding * 2 / 5;
            aRect.size.width = _padding / 5;    
            op = FVDropInsert;
            insertIndex = [self _indexForGridRow:r column:c] + 1;
        }
        else if ([self _getGridRow:&r column:&c atPoint:right] && ([self _indexForGridRow:r column:c] < [self numberOfIcons])) {
            
            aRect = [self _rectOfIconInRow:r column:c];
            aRect.origin.x -= _padding * 2 / 5;
            aRect.size.width = _padding * 1 / 5;
            op = FVDropInsert;
            insertIndex = [self _indexForGridRow:r column:c];
        }
        else {
            
            aRect = [self visibleRect];
            op = FVDropOnView;
        }
    }
    
    if (NULL != dropRect) *dropRect = aRect;
    if (NULL != anIndex) *anIndex = insertIndex;
    return op;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    NSPoint dragLoc = [sender draggingLocation];
    dragLoc = [self convertPoint:dragLoc fromView:nil];
    NSDragOperation dragOp = NSDragOperationNone;
    
    NSUInteger insertIndex;
    // this will set a default highlight based on geometry, but does no validation
    FVDropOperation dropOp = [self _dropOperationAtPointInView:dragLoc highlightRect:&_dropRectForHighlight insertionIndex:&insertIndex];
    
    if (FVDropOnIcon == dropOp) {
        
        if ([self _isLocalDraggingInfo:sender]) {
                
            dragOp = NSDragOperationNone;
            _dropRectForHighlight = NSZeroRect;
        }
        else {
            dragOp = NSDragOperationLink;
        }
    }
    else if (FVDropOnView == dropOp) {
        
        // drop on the whole view (add operation) makes no sense for a local drag
        if ([self _isLocalDraggingInfo:sender]) {
            
            dragOp = NSDragOperationNone;
            _dropRectForHighlight = NSZeroRect;
        }
        else {
            dragOp = NSDragOperationLink;
        }
    }
    else if (FVDropInsert == dropOp) {
        
        // inserting inside the block we're dragging doesn't make sense; this does allow dropping a disjoint selection at some locations within the selection, but that needs to be examined more carefully
        if ([self _isLocalDraggingInfo:sender] && [_selectedIndexes containsIndex:insertIndex]) {
            dragOp = NSDragOperationNone;
            _dropRectForHighlight = NSZeroRect;
        }
        else {
            dragOp = [self _isLocalDraggingInfo:sender] ? NSDragOperationMove : NSDragOperationLink;
        }
    }
    
    NSPoint curPt = [[self window] mouseLocationOutsideOfEventStream];
    // autoscrolling at the top of the scroll view seems to work fine, so don't screw with it
    // tried using a timer, but drags into the view from outside were too problematic for starting/stopping
    if (ABS([self convertPoint:curPt fromView:nil].y - NSMaxY([self visibleRect])) <= 10) {
        
        NSEvent *currentEvent = [[self window] currentEvent];
        NSEvent *newEvent;
        
        // Current event may be (at least) a ProcessNotification or MouseExited event when the drag source is external, so create an event from scratch to avoid assertion failures when sending -eventNumber, -clickCount, and -pressure.
        if ([currentEvent type] > NSRightMouseDragged) {
            newEvent = [NSEvent mouseEventWithType:NSLeftMouseDragged
                                          location:curPt
                                     modifierFlags:[currentEvent modifierFlags]
                                         timestamp:[currentEvent timestamp]
                                      windowNumber:[currentEvent windowNumber]
                                           context:[currentEvent context]
                                       eventNumber:INT_MAX
                                        clickCount:1
                                          pressure:0];            
        }
        else {
            // local drag: work around the problem with autoscrolling at the bottom by using an offset
            newEvent = [NSEvent mouseEventWithType:[currentEvent type]
                                          location:NSMakePoint(curPt.x, curPt.y - _padding)
                                     modifierFlags:[currentEvent modifierFlags]
                                         timestamp:[currentEvent timestamp]
                                      windowNumber:[currentEvent windowNumber]
                                           context:[currentEvent context]
                                       eventNumber:[currentEvent eventNumber]
                                        clickCount:[currentEvent clickCount]
                                          pressure:[currentEvent pressure]];          
        }
        [self autoscroll:newEvent];
    }
    [self setNeedsDisplay:YES];
    return dragOp;
}

// this is called as soon as the mouse is moved to start a drag, or enters the window from outside
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    return NSDragOperationLink;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    _dropRectForHighlight = NSZeroRect;
    [self setNeedsDisplay:YES];
}

// only invoked if performDragOperation returned YES
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;
{
    _dropRectForHighlight = NSZeroRect;
    [self reloadIcons];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPoint dragLoc = [sender draggingLocation];
    dragLoc = [self convertPoint:dragLoc fromView:nil];
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSArray *types = [pboard types];
    
    BOOL didPerform = NO;
    
    // if we return NO, concludeDragOperation doesn't get called
    _dropRectForHighlight = NSZeroRect;
    [self setNeedsDisplay:YES];
    
    NSUInteger r, c, idx;
        
    NSUInteger insertIndex;
    FVDropOperation dropOp = [self _dropOperationAtPointInView:dragLoc highlightRect:NULL insertionIndex:&insertIndex];

    // see if we're targeting a particular cell, then make sure that cell is a legal replace operation
    [self _getGridRow:&r column:&c atPoint:dragLoc];
    if (FVDropOnIcon == dropOp && (idx = [self _indexForGridRow:r column:c]) < [self numberOfIcons]) {
        
        NSURL *aURL = [URLSFromPasteboard(pboard) lastObject];
        
        // only drop a single file on a given cell!
        
        if (nil == aURL && [types containsObject:NSFilenamesPboardType]) {
            aURL = [NSURL fileURLWithPath:[[pboard propertyListForType:NSFilenamesPboardType] lastObject]];
        }
        if (aURL)
            didPerform = [[self delegate] fileView:self replaceURLsAtIndexes:[NSIndexSet indexSetWithIndex:idx] withURLs:[NSArray arrayWithObject:aURL]];
    }
    else if (FVDropInsert == dropOp) {
        
        NSArray *allURLs = URLSFromPasteboard([sender draggingPasteboard]);
        
        // move is implemented as delete/insert
        if ([self _isLocalDraggingInfo:sender]) {
            
            // if inserting after the ones we're removing, offset the insertion index accordingly
            NSUInteger firstIndex = [_selectedIndexes firstIndex];
            if ([_selectedIndexes containsIndex:insertIndex]) {
                didPerform = NO;
            }
            else {
                if (insertIndex > firstIndex && insertIndex >= [_selectedIndexes count])
                    insertIndex -= [_selectedIndexes count];
                didPerform = [[self delegate] fileView:self moveURLsAtIndexes:[self selectionIndexes] toIndex:insertIndex];
            }
        }
        else {
            NSIndexSet *insertSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(insertIndex, [allURLs count])];
            [[self delegate] fileView:self insertURLs:allURLs atIndexes:insertSet];
            didPerform = YES;
        }
    }
    else if ([self _isLocalDraggingInfo:sender] == NO) {
           
        // this must be an add operation, and only non-local drag sources can do that
        NSArray *allURLs = URLSFromPasteboard(pboard);
        NSIndexSet *insertSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([self numberOfIcons], [allURLs count])];
        [[self delegate] fileView:self insertURLs:allURLs atIndexes:insertSet];
        didPerform = YES;

    }
    // reload is handled in concludeDragOperation:
    return didPerform;
}

#pragma mark User interaction

- (void)scrollItemAtIndexToVisible:(NSUInteger)anIndex
{
    NSUInteger r = 0, c = 0;
    if ([self _getGridRow:&r column:&c ofIndex:anIndex])
        [self scrollRectToVisible:[self _rectOfIconInRow:r column:c]];
}

- (void)moveUp:(id)sender;
{
    NSUInteger curIdx = [_selectedIndexes firstIndex];
    NSUInteger next = (NSNotFound == curIdx || curIdx < [self numberOfColumns]) ? 0 : curIdx - [self numberOfColumns];
    if (next >= [self numberOfIcons]) {
        NSBeep();
    }
    else {
        [self scrollItemAtIndexToVisible:next];
        [self setSelectionIndexes:[NSIndexSet indexSetWithIndex:next]];
    }
}

- (void)moveDown:(id)sender;
{
    NSUInteger curIdx = [_selectedIndexes firstIndex];
    NSUInteger next = NSNotFound == curIdx ? 0 : curIdx + [self numberOfColumns];
    if ([self numberOfIcons] == 0) {
        NSBeep();
    }
    else {
        if (next >= [self numberOfIcons])
            next = [self numberOfIcons] - 1;

        [self scrollItemAtIndexToVisible:next];
        [self setSelectionIndexes:[NSIndexSet indexSetWithIndex:next]];
    }
}

- (void)moveRight:(id)sender;
{
    [self selectNextIcon:self];
}

- (void)moveLeft:(id)sender;
{
    [self selectPreviousIcon:self];
}

- (void)insertTab:(id)sender;
{
    [self selectNextIcon:self];
}

- (void)insertBacktab:(id)sender;
{
    [self selectPreviousIcon:self];
}

- (void)deleteForward:(id)sender;
{
    [self delete:self];
}

- (void)deleteBackward:(id)sender;
{
    [self delete:self];
}

// scrollRectToVisible doesn't scroll the entire rect to visible
- (void)scrollRectToVisible:(NSRect)aRect
{
    NSRect visibleRect = [self visibleRect];

    if (NSContainsRect(visibleRect, aRect) == NO) {
        
        CGFloat heightDifference = NSHeight(visibleRect) - NSHeight(aRect);
        if (heightDifference > 0) {
            // scroll to a rect equal in height to the visible rect but centered on the selected rect
            aRect = NSInsetRect(aRect, 0.0, -(heightDifference / 2.0));
        } else {
            // force the top of the selectionRect to the top of the view
            aRect.size.height = NSHeight(visibleRect);
        }
        [super scrollRectToVisible:aRect];
    }
} 

- (IBAction)selectPreviousIcon:(id)sender;
{
    NSUInteger curIdx = [_selectedIndexes firstIndex];
    NSUInteger previous;
    
    if (NSNotFound == curIdx)
        previous = 0;
    else if (0 == curIdx && [self numberOfIcons] > 0) 
        previous = ([self numberOfIcons] - 1);
    else
        previous = curIdx - 1;
    
    [self scrollItemAtIndexToVisible:previous];
    [self setSelectionIndexes:[NSIndexSet indexSetWithIndex:previous]];
}

- (IBAction)selectNextIcon:(id)sender;
{
    NSUInteger curIdx = [_selectedIndexes firstIndex];
    NSUInteger next = NSNotFound == curIdx ? 0 : curIdx + 1;
    if (next >= [self numberOfIcons])
        next = 0;

    [self scrollItemAtIndexToVisible:next];
    [self setSelectionIndexes:[NSIndexSet indexSetWithIndex:next]];
}

- (IBAction)revealInFinder:(id)sender
{
    [[NSWorkspace sharedWorkspace] selectFile:[[self URLForLastMouseDown] path] inFileViewerRootedAtPath:nil];
}

- (IBAction)openURL:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[self URLForLastMouseDown]];
}

- (IBAction)zoomIn:(id)sender;
{
    [self setIconScale:([self iconScale] * 2)];
}

- (IBAction)zoomOut:(id)sender;
{
    [self setIconScale:([self iconScale] / 2)];
}

- (IBAction)previewAction:(id)sender;
{
    [FVPreviewer previewURL:[self URLForLastMouseDown]];
}

- (IBAction)delete:(id)sender;
{
    if (NO == [[self delegate] fileView:self deleteURLsAtIndexes:_selectedIndexes])
        NSBeep();
    else
        [self reloadIcons];
}

- (IBAction)selectAll:(id)sender;
{
    [self setSelectionIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfIcons])]];
}

- (IBAction)copy:(id)sender;
{
    if (NO == writeURLsToPasteboard([self _selectedURLs], [NSPasteboard generalPasteboard], NULL))
        NSBeep();
}

- (IBAction)paste:(id)sender;
{
    if ([self isEditable]) {
        NSArray *URLs = URLSFromPasteboard([NSPasteboard generalPasteboard]);
        if ([URLs count])
            [[self delegate] fileView:self insertURLs:URLs atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange([self numberOfIcons], [URLs count])]];
        else
            NSBeep();
    }
    else NSBeep();
}

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
    NSURL *aURL = [self URLForLastMouseDown];  
    SEL action = [anItem action];
    if (action == @selector(zoomOut:) || action == @selector(zoomIn:))
        return YES;
    else if (action == @selector(revealInFinder:))
        return [aURL isFileURL] && [[NSFileManager defaultManager] fileExistsAtPath:[aURL path]];
    else if (action == @selector(openURL:) && nil != aURL) {
        [anItem setTitle:([aURL isFileURL] ? NSLocalizedString(@"Open File", @"") : NSLocalizedString(@"Open in Browser", @""))];
        return YES;
    }
    else if (action == @selector(delete:) || action == @selector(copy:))
        return [self isEditable] && [_selectedIndexes count] > 0;
    else if (action == @selector(selectAll:))
        return ([self numberOfIcons] > 0);
    else if (action == @selector(openURL:) || action == @selector(previewAction:))
        return (nil != aURL);
    else if (action == @selector(paste:))
        return [self isEditable];
    // need to handle print: and other actions
    return ([self respondsToSelector:action]);
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
    _lastMouseDownLocInView = [self convertPoint:[event locationInWindow] fromView:nil];
    return [super menuForEvent:event];
}

+ (NSMenu *)defaultMenu
{
    static NSMenu *sharedMenu = nil;
    if (nil == sharedMenu) {
        sharedMenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@""];
        NSMenuItem *anItem;
        anItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Zoom Out", @"") action:@selector(zoomOut:) keyEquivalent:@""];
        [sharedMenu insertItem:anItem atIndex:0];
        [anItem release];
        anItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Zoom In", @"") action:@selector(zoomIn:) keyEquivalent:@""];
        [sharedMenu insertItem:anItem atIndex:0];
        [anItem release];
        
        [sharedMenu insertItem:[NSMenuItem separatorItem] atIndex:0];
        
        anItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Reveal in Finder", @"") action:@selector(revealInFinder:) keyEquivalent:@""];
        [sharedMenu insertItem:anItem atIndex:0];
        [anItem release];
        anItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open File", @"") action:@selector(openURL:) keyEquivalent:@""];
        [sharedMenu insertItem:anItem atIndex:0];
        [anItem release];
        anItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Quick Look", @"") action:@selector(previewAction:) keyEquivalent:@""];
        [sharedMenu insertItem:anItem atIndex:0];
        [anItem release];
    }
    return sharedMenu;
}

@end

#pragma mark -
#pragma mark Logging

void CLogv(NSString *format, va_list argList)
{
    NSString *logString = [[NSString alloc] initWithFormat:format arguments:argList];
    
    char *buf;
    char stackBuf[1024];
    
    // add 1 for the NULL terminator (length arg to getCString:maxLength:encoding: needs to include space for this)
    unsigned requiredLength = ([logString maximumLengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
    
    if (requiredLength <= sizeof(stackBuf) && [logString getCString:stackBuf maxLength:sizeof(stackBuf) encoding:NSUTF8StringEncoding]) {
        buf = stackBuf;
    } else if (NULL != (buf = NSZoneMalloc(NULL, requiredLength * sizeof(char))) ){
        [logString getCString:buf maxLength:requiredLength encoding:NSUTF8StringEncoding];
    } else {
        fprintf(stderr, "unable to allocate log buffer\n");
        abort();
    }
    [logString release];
    
    fprintf(stderr, "%s\n", buf);
    
    if (buf != stackBuf) NSZoneFree(NULL, buf);
}

void CLog(NSString *format, ...)
{
    va_list list;
    va_start(list, format);
    CLogv(format, list);
    va_end(list);
}

#pragma mark Pasteboard URL functions

static BOOL pasteboardHasType(NSPasteboard *pboard, NSString *aType)
{
    OSStatus err;
    
    PasteboardRef carbonPboard;
    err = PasteboardCreate((CFStringRef)[pboard name], &carbonPboard);
    
    PasteboardSyncFlags syncFlags;
#pragma unused(syncFlags)
    if (noErr == err)
        syncFlags = PasteboardSynchronize(carbonPboard);
    
    ItemCount itemCount, itemIndex;
    if (noErr == err)
        err = PasteboardGetItemCount(carbonPboard, &itemCount);
    
    BOOL hasType = NO;
        
    // wtf? this has 1-based indexing!
    for (itemIndex = 1; noErr == err && itemIndex <= itemCount && NO == hasType; itemIndex++) {
        
        PasteboardItemID itemID;
        CFArrayRef flavors;
        
        err = PasteboardGetItemIdentifier(carbonPboard, itemIndex, &itemID);
        
        if (noErr == err)
            err = PasteboardCopyItemFlavors(carbonPboard, itemID, &flavors);
        
        if (noErr == err)
            hasType = CFArrayContainsValue(flavors, CFRangeMake(0, CFArrayGetCount(flavors)), (CFStringRef)aType);
        
        if (noErr == err && NULL != flavors)
            CFRelease(flavors);
        
    }
    
    if (carbonPboard) CFRelease(carbonPboard);
    
    return hasType;
}

// NSPasteboard only lets us read a single webloc or NSURL instance from the pasteboard, which isn't very considerate of it.  Fortunately, we can create a Carbon pasteboard that isn't as fundamentally crippled (except in its moderately annoying API).  
static NSArray *URLSFromPasteboard(NSPasteboard *pboard)
{
    OSStatus err;
    
    PasteboardRef carbonPboard;
    err = PasteboardCreate((CFStringRef)[pboard name], &carbonPboard);
    
    PasteboardSyncFlags syncFlags;
#pragma unused(syncFlags)
    if (noErr == err)
        syncFlags = PasteboardSynchronize(carbonPboard);
    
    ItemCount itemCount, itemIndex;
    if (noErr == err)
        err = PasteboardGetItemCount(carbonPboard, &itemCount);
    
    NSMutableArray *toReturn = [NSMutableArray arrayWithCapacity:itemCount];
    NSMutableSet *allURLsReadFromPasteboard = [NSMutableSet setWithCapacity:itemCount];
    
    // wtf? this has 1-based indexing!
    for (itemIndex = 1; noErr == err && itemIndex <= itemCount; itemIndex++) {
        
        PasteboardItemID itemID;
        CFArrayRef flavors;
        CFIndex flavorIndex, flavorCount = 0;
        
        err = PasteboardGetItemIdentifier(carbonPboard, itemIndex, &itemID);
        
        if (noErr == err)
            err = PasteboardCopyItemFlavors(carbonPboard, itemID, &flavors);
        
        if (noErr == err)
            flavorCount = CFArrayGetCount(flavors);
        
        CFURLRef fileURL = NULL;
        CFURLRef destURL = NULL;
        
        for (flavorIndex = 0; noErr == err && flavorIndex < flavorCount; flavorIndex++) {
            
            CFStringRef flavor;
            CFDataRef data;
            CFIndex dataSize;
            
            flavor = CFArrayGetValueAtIndex(flavors, flavorIndex);
            
            // !!! I'm assuming that the URL bytes are UTF-8, but that should be checked...
            
            // UTIs determined with PasteboardPeeker
            
            if (UTTypeConformsTo(flavor, kUTTypeFileURL)) {
                
                // this is the URL of a file on disk
                err = PasteboardCopyItemFlavorData(carbonPboard, itemID, flavor, &data);
                if (noErr == err && NULL != data) {
                    dataSize = CFDataGetLength(data);
                    
                    fileURL = CFURLCreateWithBytes(NULL, CFDataGetBytePtr(data), dataSize, kCFStringEncodingUTF8, NULL);
                    CFRelease(data);
                }
                
            }
            else if (UTTypeConformsTo(flavor, kUTTypeURL)) {
                
                // if we have a webloc or other URL, this is the URL that it points to
                err = PasteboardCopyItemFlavorData(carbonPboard, itemID, flavor, &data);
                if (noErr == err && NULL != data) {
                    dataSize = CFDataGetLength(data);
                    
                    destURL = CFURLCreateWithBytes(NULL, CFDataGetBytePtr(data), dataSize, kCFStringEncodingUTF8, NULL);
                    CFRelease(data);
                }
                
            }
            // ignore any other type; we don't care
        }
        
        if (noErr == err && NULL != flavors)
            CFRelease(flavors);
        
        // only add the file URL if the destination URL didn't exist
        if (fileURL) {
            [allURLsReadFromPasteboard addObject:(id)fileURL];
            if (NULL == destURL)
                [toReturn addObject:(id)fileURL];
            CFRelease(fileURL);
        }
        
        // always add this if it exists
        if (destURL) {
            [toReturn addObject:(id)destURL];
            [allURLsReadFromPasteboard addObject:(id)destURL];
            CFRelease(destURL);
        }
        
    }
    
    if (carbonPboard) CFRelease(carbonPboard);

    // NSPasteboard only allows a single NSURL for some idiotic reason, and NSURLPboardType isn't automagically coerced to a Carbon URL pboard type.  This step handles a program like BibDesk which presently adds a webloc promise + NSURLPboardType, where we want the NSURLPboardType data and ignore the HFS promise.  However, Finder puts all of these on the pboard, so don't add duplicate items to the array...since we may have already added the content (remote URL) if this is a webloc file.
    if ([[pboard types] containsObject:NSURLPboardType]) {
        NSURL *nsURL = [NSURL URLFromPasteboard:pboard];
        if (nsURL && [allURLsReadFromPasteboard containsObject:nsURL] == NO)
            [toReturn addObject:nsURL];
    }

    return toReturn;
}

// Once we treat the NSPasteboard as a Carbon pboard, bad things seem to happen on Tiger (-types doesn't work), so return the PasteboardRef by reference to allow the caller to add more types to it or whatever.
static BOOL writeURLsToPasteboard(NSArray *URLs, NSPasteboard *pboard, PasteboardRef *pboardPtr)
{
    OSStatus err;
    
    PasteboardRef carbonPboard;
    err = PasteboardCreate((CFStringRef)[pboard name], &carbonPboard);
    
    if (noErr == err)
        err = PasteboardClear(carbonPboard);
    
    PasteboardSyncFlags syncFlags;
#pragma unused(syncFlags)
    if (noErr == err)
        syncFlags = PasteboardSynchronize(carbonPboard);
    
    NSUInteger i, iMax = [URLs count];
    NSMutableArray *fileNames = [NSMutableArray array];
    
    for (i = 0; i < iMax && noErr == err; i++) {
        
        NSURL *theURL = [URLs objectAtIndex:i];
        NSString *string = [theURL absoluteString];
        CFDataRef utf8Data = (CFDataRef)[string dataUsingEncoding:NSUTF8StringEncoding];
        
        // any pointer type; private to the creating application
        PasteboardItemID itemID = (void *)theURL;
        
        // Finder adds a file URL and destination URL for weblocs, but only a file URL for regular files
        // could also put a string representation of the URL, but Finder doesn't do that

        if ([theURL isFileURL]) {
            err = PasteboardPutItemFlavor(carbonPboard, itemID, kUTTypeFileURL, utf8Data, kPasteboardFlavorNoFlags);
            
            // add as NSFilenamesPboardType later
            [fileNames addObject:[theURL path]];
        }
        else {
            err = PasteboardPutItemFlavor(carbonPboard, itemID, kUTTypeURL, utf8Data, kPasteboardFlavorNoFlags);
        }
    }
    
    if (carbonPboard && NULL == pboardPtr) 
        CFRelease(carbonPboard);
    else if (NULL != pboardPtr)
        *pboardPtr = carbonPboard;
    
    return noErr == err;
}

@implementation NSBezierPath (RoundRect)

+ (NSBezierPath*)bezierPathWithRoundRect:(NSRect)rect xRadius:(CGFloat)xRadius yRadius:(CGFloat)yRadius;
{    
    if ([self respondsToSelector:@selector(bezierPathWithRoundedRect:xRadius:yRadius:)])
        return [self bezierPathWithRoundedRect:rect xRadius:xRadius yRadius:yRadius];
    
    // Make sure radius doesn't exceed a maximum size to avoid artifacts:
    CGFloat mr = MIN(NSHeight(rect), NSWidth(rect));
    CGFloat radius = MIN(xRadius, 0.5f * mr);
    
    // Make sure silly values simply lead to un-rounded corners:
    if( radius <= 0 )
        return [self bezierPathWithRect:rect];
    
    NSRect innerRect = NSInsetRect(rect, radius, radius); // Make rect with corners being centers of the corner circles.
	static NSBezierPath *path = nil;
    if(path == nil)
        path = [[self bezierPath] retain];
    
    [path removeAllPoints];    
    
    // Now draw our rectangle:
    [path moveToPoint: NSMakePoint(NSMinX(innerRect) - radius, NSMinY(innerRect))];
    
    // Bottom left (origin):
    [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(innerRect), NSMinY(innerRect)) radius:radius startAngle:180.0 endAngle:270.0];
    // Bottom edge and bottom right:
    [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(innerRect), NSMinY(innerRect)) radius:radius startAngle:270.0 endAngle:360.0];
    // Left edge and top right:
    [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(innerRect), NSMaxY(innerRect)) radius:radius startAngle:0.0  endAngle:90.0 ];
    // Top edge and top left:
    [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(innerRect), NSMaxY(innerRect)) radius:radius startAngle:90.0  endAngle:180.0];
    // Left edge:
    [path closePath];
    
    return path;
}
@end

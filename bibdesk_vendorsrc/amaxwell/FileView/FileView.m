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
#import "FVIcon_Private.h"
#import "FVIconQueue.h"
#import "FVPreviewer.h"
#import "FVArrowButton.h"

// functions for dealing with multiple URLs and weblocs on the pasteboard
static NSArray *URLSFromPasteboard(NSPasteboard *pboard);
static BOOL writeURLsToPasteboard(NSArray *URLs, NSPasteboard *pboard);
static BOOL pasteboardHasURL(NSPasteboard *pboard);

enum {
    FVDropOnIcon,
    FVDropOnView,
    FVDropInsert
};
typedef NSUInteger FVDropOperation;

static NSString *FVWeblocFilePboardType = @"CorePasteboardFlavorType 0x75726C20";

static const NSSize DEFAULT_ICON_SIZE = { 64, 64 };
static const CGFloat DEFAULT_PADDING = 32;          // 16 per side

static NSSize _paddingForScale(CGFloat scale)
{
    // ??? magic number here... using a fixed padding looked funny at some sizes, so this is now adjustable
    return NSMakeSize(5.0 * round(2.0 + scale), round(DEFAULT_PADDING * (1.0 + scale / 8.0)));
}

// don't bother removing icons from the cache if there are fewer than this value
static const NSUInteger ZOMBIE_CACHE_THRESHOLD = 100;

// thin the icons if we have more than this value; 25 is a good value, but 5 is good for cache testing
static const NSUInteger RELEASE_CACHE_THRESHOLD = 25;

// check the icon cache every five minutes and get rid of stale icons
static const CFTimeInterval ZOMBIE_TIMER_INTERVAL = 300.0;
static void zombieTimerFired(CFRunLoopTimerRef timer, void *context);

static NSDictionary *__titleAttributes = nil;
static NSDictionary *__subtitleAttributes = nil;
static NSShadow *__shadow = nil;

#pragma mark -

@interface FileView (Private)
// wrapper that calls bound array or datasource transparently; for internal use
// clients should access the datasource or bound array directly
- (NSURL *)iconURLAtIndex:(NSUInteger)anIndex;
- (NSUInteger)numberOfIcons;

- (void)_commonInit;
- (void)_registerForDraggedTypes;
- (CGFloat)_columnWidth;
- (CGFloat)_rowHeight;
- (FVIcon *)_cachedIconForURL:(NSURL *)aURL;
- (NSRect)_rectOfIconInRow:(NSUInteger)row column:(NSUInteger)column;
- (NSRect)_rectOfTextForIconRect:(NSRect)iconRect;
- (NSArray *)_selectedURLs;
- (void)_removeAllTrackingRects;
- (void)_resetTrackingRectsAndToolTips;
- (void)_discardTrackingRectsAndToolTips;
- (void)_recalculateGridSize;
- (NSUInteger)_indexForGridRow:(NSUInteger)rowIndex column:(NSUInteger)colIndex;
- (BOOL)_getGridRow:(NSUInteger *)rowIndex column:(NSUInteger *)colIndex ofIndex:(NSUInteger)anIndex;
- (BOOL)_getGridRow:(NSUInteger *)rowIndex column:(NSUInteger *)colIndex atPoint:(NSPoint)point;
- (void)_drawDropHighlightInRect:(NSRect)aRect;
- (void)_drawHighlightInRect:(NSRect)aRect;
- (void)_drawRubberbandRect;
- (void)_drawDropMessage;
- (CGFloat)_scrollVelocity;
- (void)_getRangeOfRows:(NSRange *)rowRange columns:(NSRange *)columnRange inRect:(NSRect)aRect;
- (BOOL)_isFastScrolling;
- (void)_scheduleIconsInRange:(NSRange)indexRange;
- (void)_drawIconsInRange:(NSRange)indexRange rows:(NSRange)rows columns:(NSRange)columns;
- (void)_updateButtonsForIcon:(FVIcon *)anIcon;
- (void)_showArrowsForIconAtIndex:(NSUInteger)anIndex;
- (void)_hideArrows;
- (BOOL)_hasArrows;
- (NSURL *)_URLAtPoint:(NSPoint)point;
- (NSIndexSet *)_allIndexesInRubberBandRect;
- (BOOL)_isLocalDraggingInfo:(id <NSDraggingInfo>)sender;
- (FVDropOperation)_dropOperationAtPointInView:(NSPoint)point highlightRect:(NSRect *)dropRect insertionIndex:(NSUInteger *)anIndex;

@end

#pragma mark -

@implementation FileView

+ (void)initialize {
    NSMutableDictionary *ta = [NSMutableDictionary dictionary];
    [ta setObject:[NSFont systemFontOfSize:12.0] forKey:NSFontAttributeName];
    [ta setObject:[NSColor darkGrayColor] forKey:NSForegroundColorAttributeName];
    NSMutableParagraphStyle *ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    // Apple uses this in IKImageBrowserView
    [ps setLineBreakMode:NSLineBreakByTruncatingTail];
    [ps setAlignment:NSCenterTextAlignment];
    [ta setObject:ps forKey:NSParagraphStyleAttributeName];
    [ps release];
    __titleAttributes = [ta copy];
    
    [ta setObject:[NSFont systemFontOfSize:10.0] forKey:NSFontAttributeName];
    [ta setObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName];
    __subtitleAttributes = [ta copy];
    
    __shadow = [[NSShadow alloc] init];
    // IconServices shadows look darker than the normal NSShadow (especially Leopard folder shadows) so try to match
    [__shadow setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:0.4]];
    [__shadow setShadowOffset:NSMakeSize(0.0, -2.0)];
    // this will have to be scaled when drawing, since it's in a global coordinate space
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
- (CGFloat)_columnWidth { return _iconSize.width + _padding.width; }
- (CGFloat)_rowHeight { return _iconSize.height + _padding.height; }

static Boolean intEqual(const void *v1, const void *v2) { return v1 == v2; }
static CFStringRef intDesc(const void *value) { return (CFStringRef)[[NSString alloc] initWithFormat:@"%ld", (long)value]; }
static CFHashCode intHash(const void *value) { return (CFHashCode)value; }

- (void)_commonInit {
    _iconCache = [[NSMutableDictionary alloc] init];
    _iconSize = DEFAULT_ICON_SIZE;
    _padding = _paddingForScale(1.0);
    _lastMouseDownLocInView = NSZeroPoint;
    _dropRectForHighlight = NSZeroRect;
    _isRescaling = NO;
    _selectedIndexes = [[NSMutableIndexSet alloc] init];
    _lastClickedIndex = NSNotFound;
    _rubberBandRect = NSZeroRect;
    _iconURLs = nil;
    _isEditable = NO;
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
    
    _leftArrow = [[FVArrowButtonCell alloc] initWithArrowDirection:FVArrowLeft];
    [_leftArrow setTarget:self];
    [_leftArrow setAction:@selector(leftArrowAction:)];
    
    _rightArrow = [[FVArrowButtonCell alloc] initWithArrowDirection:FVArrowRight];
    [_rightArrow setTarget:self];
    [_rightArrow setAction:@selector(rightArrowAction:)];
    
    _leftArrowFrame = NSZeroRect;
    _rightArrowFrame = NSZeroRect;
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"selectionIndexes"]) {
        if ([FVPreviewer isPreviewing] && NSNotFound != [_selectedIndexes firstIndex]) {
            [FVPreviewer setWebViewContextMenuDelegate:[self delegate]];
            [FVPreviewer previewURL:[self iconURLAtIndex:[_selectedIndexes firstIndex]]];
        }
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
    _padding = _paddingForScale(scale);
    
    // arrows out of place now, they will be added again when required when resetting the tracking rects
    [self _hideArrows];
    
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
    
- (void)_registerForDraggedTypes
{
    if (_isEditable && _dataSource) {
        NSParameterAssert([_dataSource respondsToSelector:@selector(fileView:insertURLs:atIndexes:)]);
        NSParameterAssert([_dataSource respondsToSelector:@selector(fileView:replaceURLsAtIndexes:withURLs:)]);
        NSParameterAssert([_dataSource respondsToSelector:@selector(fileView:moveURLsAtIndexes:toIndex:)]);
        NSParameterAssert([_dataSource respondsToSelector:@selector(fileView:deleteURLsAtIndexes:)]);
        [self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, FVWeblocFilePboardType, (NSString *)kUTTypeURL, (NSString *)kUTTypeUTF8PlainText, NSStringPboardType, nil]];
    } else {
        [self registerForDraggedTypes:nil];
    }
}

- (void)awakeFromNib
{
    if ([[FileView superclass] instancesRespondToSelector:@selector(awakeFromNib)])
        [super awakeFromNib];
    // if the datasource connection is made in the nib, the drag type setup doesn't get done
    [self _registerForDraggedTypes];
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
    
    [self _registerForDraggedTypes];
}

- (id)dataSource { return _dataSource; }

- (BOOL)isEditable 
{ 
    return _isEditable;
}

- (void)setEditable:(BOOL)flag 
{
    if (_isEditable != flag) {
        _isEditable = flag;
        
        [self _registerForDraggedTypes];
    }
}

- (void)setDelegate:(id)obj;
{
    _delegate = obj;
}

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
    // compute width ignoring the width of the vertical scroller (if any), so we can get more symmetric empty space on either side
    NSView *view = [self enclosingScrollView];
    if (nil == view)
        view = self;
    return MAX(1, trunc((NSWidth([view frame]) - _padding.width / 2) / [self _columnWidth]));
}

// This is the square rect the icon is drawn in.  It doesn't include padding, so rects aren't contiguous.
// Caller is responsible for any centering before drawing.
- (NSRect)_rectOfIconInRow:(NSUInteger)row column:(NSUInteger)column;
{
    NSPoint origin = [self bounds].origin;
    CGFloat leftEdge = origin.x + _padding.width / 2 + ([self _columnWidth]) * column;
    CGFloat bottomEdge = origin.y + _padding.height / 2 + ([self _rowHeight]) * row;
    return NSMakeRect(leftEdge, bottomEdge, _iconSize.width, _iconSize.height);
}

- (NSRect)_rectOfTextForIconRect:(NSRect)iconRect;
{
    NSRect textRect = NSMakeRect(NSMinX(iconRect), NSMaxY(iconRect), NSWidth(iconRect), _padding.height);
    // allow the text rect to extend outside the grid cell
    return NSInsetRect(textRect, -_padding.width / 3.0, 2.0);
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
        NSRect visibleRect = [self visibleRect];
        NSUInteger r, rMin = 0, rMax = [self numberOfRows];
        NSUInteger c, cMin = 0, cMax = [self numberOfColumns];
        NSUInteger i, iMin = 0, iMax = [self numberOfIcons];
        NSPoint mouseLoc = [self convertPoint:[[self window] mouseLocationOutsideOfEventStream] fromView:nil];
        NSUInteger mouseIndex = NSNotFound;
        
        for (r = rMin, i = iMin; r < rMax; r++) 
        {
            for (c = cMin; c < cMax && i < iMax; c++, i++) 
            {
                NSRect iconRect = NSIntersectionRect(visibleRect, [self _rectOfIconInRow:r column:c]);
                
                if (NSIsEmptyRect(iconRect) == NO) {
                    BOOL mouseInside = NSPointInRect(mouseLoc, iconRect);
                    
                    if (mouseInside)
                        mouseIndex = i;
                    
                    // Getting the location from the mouseEntered: event isn't reliable if you move the mouse slowly, so we either need to enlarge this tracking rect, or keep a map table of tag->index.  Since we have to keep a set of tags anyway, we'll use the latter method.
                    NSTrackingRectTag tag = [self addTrackingRect:iconRect owner:self userData:NULL assumeInside:mouseInside];
                    CFDictionarySetValue(_trackingRectMap, (const void *)tag, (const void *)i);
                    
                    // don't pass the URL as owner, as it's not retained; use the delegate method instead
                    [self addToolTipRect:iconRect owner:self userData:NULL];
                }
            }
        }    
        
        FVIcon *anIcon = mouseIndex == NSNotFound ? nil : [self _cachedIconForURL:[self iconURLAtIndex:mouseIndex]];
        if ([anIcon pageCount] > 1)
            [self _showArrowsForIconAtIndex:mouseIndex];
        else
            [self _hideArrows];
    }
}

// Here again, use -[NSWindow invalidateCursorRectsForView:] instead of calling this directly.
- (void)_discardTrackingRectsAndToolTips
{
    [self _removeAllTrackingRects];
    [self removeAllToolTips];   
}

/*  
   10.4 docs say "You need never invoke this method directly; it's invoked automatically before the receiver's cursor rectangles are reestablished using resetCursorRects."
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
    // Problem exposed in BibDesk: select all, scroll halfway down in file pane, then change selection to a single row.  FileView content didn't update correctly, even though reloadIcons was called.  Logging drawRect: indicated that the wrong region was being updated, but calling _recalculateGridSize here fixed it.
    [self _recalculateGridSize];
    
    // As of r12243, tracking rects were not being invalidated by passing self to invalidateCursorRectsForView: unless the scrollview changed.  As a consequence, minor changes in scale that didn't result in addition of a vertical scroller were not triggering resetCursorRects.  Passing the scrollview to invalidateCursorRectsForView: fixed that.
    NSView *view = [self enclosingScrollView];
    if (nil == view) view = self;
    
    // grid may have changed, so do a full redisplay
    [view setNeedsDisplay:YES];
    // any time the grid or scale changes, cursor rects are garbage
    [[self window] invalidateCursorRectsForView:view];
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
        [[NSNotificationCenter defaultCenter] removeObserver:self name:FVWebIconUpdatedNotificationName object:nil];
    }
    else {
        [self addObserver:self forKeyPath:@"selectionIndexes" options:0 context:NULL];
        
        // special case; see FVWebViewIcon for posting and comments
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(_handleWebIconNotification:) 
                                                     name:FVWebIconUpdatedNotificationName object:nil];        
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
    // datasource methods all trigger a redisplay, so we have to do the same here
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
    if (nil == aURL || [[NSNull null] isEqual:aURL])
        aURL = [FVIcon missingFileURL];
    return aURL;
}

- (NSUInteger)numberOfIcons
{
    return nil == _iconURLs ? [_dataSource numberOfIconsInFileView:self] : [_iconURLs count];
}

- (FVIcon *)_cachedIconForURL:(NSURL *)aURL;
{
    // datasource returns nil for nonexistent paths, so cache that in the dictionary as a normal key
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
    NSClipView *cv = [[self enclosingScrollView] contentView];
    NSRect minFrame = cv ? [cv frame] : NSZeroRect;
    NSRect frame = NSZeroRect;
    frame.size.width = MAX([self _columnWidth] * [self numberOfColumns], NSWidth(minFrame));
    // Add half an extra padding for the top margin
    frame.size.height = MAX([self _rowHeight] * [self numberOfRows] + 0.5 * _padding.height, NSHeight(minFrame));
    
    if (NSEqualRects(frame, [self frame]) == NO)
        [self setFrame:frame];
}    

- (NSUInteger)_indexForGridRow:(NSUInteger)rowIndex column:(NSUInteger)colIndex;
{
    // nc * (r-1) + c
    // assumes all slots are filled, so check numberOfIcons before returning a value
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
    if (point.x <= _padding.width / 2 || point.y <= _padding.height / 2)
        return NO;
    
    // column width is padding + icon width
    // row height is padding + icon width
    NSUInteger idx, nc = [self numberOfColumns], nr = [self numberOfRows];
    
    idx = 0;
    CGFloat start;
    
    while (idx < nc) {
        
        start = _padding.width / 2 + (_iconSize.width + _padding.width) * idx;
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
        
        start = _padding.height / 2 + (_iconSize.height + _padding.height) * idx;
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

- (void)_handleWebIconNotification:(NSNotification *)aNote
{
    [self iconQueueUpdated:[NSArray arrayWithObject:[aNote object]]];
}

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

- (void)iconQueueUpdated:(NSArray *)updatedIcons;
{
    // Only iterate icons in the visible range, since we know the overall geometry
    NSRange rowRange, columnRange;
    [self _getRangeOfRows:&rowRange columns:&columnRange inRect:[self visibleRect]];
    
    NSUInteger iMin, iMax = [self numberOfIcons];
    
    // _indexForGridRow:column: returns NSNotFound if we're in a short row (empty column)
    iMin = [self _indexForGridRow:rowRange.location column:columnRange.location];
    if (NSNotFound == iMin)
        iMin = [self numberOfIcons];
    else
        iMax = MIN([self numberOfIcons], iMin + rowRange.length * [self numberOfColumns]);
    
    NSArray *visibleIcons = [self iconsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(iMin, iMax - iMin)]];
    NSUInteger i;
    NSSet *updatedIconSet = [[NSSet alloc] initWithArray:updatedIcons];
    CGFloat padding = 3.0 * [self iconScale];
    
    // If an icon isn't visible, there's no need to redisplay anything.  Similarly, if 20 icons are displayed and only 5 updated, there's no need to redraw all 20.  Geometry calculations are much faster than redrawing, in general.
    for (i = iMin; i < iMax; i++) {
        
        if ([updatedIconSet containsObject:[visibleIcons objectAtIndex:(i - iMin)]]) {
            NSUInteger r, c;
            if ([self _getGridRow:&r column:&c ofIndex:i])
                [self setNeedsDisplayInRect:NSInsetRect([self _rectOfIconInRow:r column:c], -padding, -padding)];
        }
    }
    [updatedIconSet release];
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
    NSUInteger r, c;
    
    if (NSEqualRects(aRect, [self visibleRect]) || [self _getGridRow:&r column:&c atPoint:NSMakePoint(NSMidX(aRect), NSMidY(aRect))]) {
        // it's either a drop on the whole table or on top of a cell
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

    NSBundle *bundle = [NSBundle bundleForClass:[FileView class]];
    NSString *message = NSLocalizedStringFromTableInBundle(@"Drop Files Here", @"FileView", bundle, @"placeholder message for empty file view");
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
    bounds.origin.x += _padding.width / 2;
    bounds.origin.y += _padding.height / 2;
    
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
    NSUInteger i;
        
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
    BOOL useSubtitle = [_dataSource respondsToSelector:@selector(fileView:subtitleAtIndex:)];
    
    // shadow needs to be scaled as the icon scale changes to approximate the IconServices shadow
    [__shadow setShadowBlurRadius:2.0 * [self iconScale]];
    [__shadow setShadowOffset:NSMakeSize(0.0, -[self iconScale])];
    
    // iterate each row/column to see if it's in the dirty rect, and evaluate the current cache state
    for (r = rMin; r < rMax; r++) 
    {
        for (c = cMin; c < cMax; c++) 
        {
            i = [self _indexForGridRow:r column:c];

            // if we're creating a drag image, only draw selected icons
            if (NSNotFound != i && (NO == _isDrawingDragImage || [_selectedIndexes containsIndex:i])) {
            
                NSRect fileRect = [self _rectOfIconInRow:r column:c];
                
                NSURL *aURL = [self iconURLAtIndex:i];
                
                // we may only be drawing icon and/or text
                // allow some extra for the shadow (-5)
                BOOL willDrawIcon = [self needsToDrawRect:NSInsetRect(fileRect, -5, -5)];
                NSRect textRect = [self _rectOfTextForIconRect:fileRect];
                BOOL willDrawText = [self needsToDrawRect:textRect];
                                
                if (willDrawIcon) {

                    FVIcon *image = [self _cachedIconForURL:aURL];
                    
                    // note that iconRect will be transformed for a flipped context
                    NSRect iconRect = fileRect;
                    
                    // draw highlight, then draw icon over it, as Finder does
                    if ([_selectedIndexes containsIndex:i])
                        [self _drawHighlightInRect:NSInsetRect(fileRect, -4, -4)];
                    
                    CGContextSaveGState(cgContext);
                    
                    // draw a shadow behind the image/page
                    if ([image needsShadow])
                        [__shadow set];
                    
                    // possibly better performance by caching all bitmaps in a flipped state, but bookkeeping is a pain
                    CGContextTranslateCTM(cgContext, 0, NSMaxY(iconRect));
                    CGContextScaleCTM(cgContext, 1, -1);
                    iconRect.origin.y = 0;
                    
                    // Note: don't use integral rects here to avoid res independence issues (on Tiger, centerScanRect: just makes an integral rect).  The icons may create an integral bitmap context, but it'll still be drawn into this rect with correct scaling.
                    iconRect = [self centerScanRect:iconRect];
                                    
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
                    NSString *name;
                    if ([aURL isFileURL]) {
                        if (noErr == LSCopyDisplayNameForURL((CFURLRef)aURL, (CFStringRef *)&name))
                            name = [name autorelease];
                        else
                            name = [[aURL path] lastPathComponent];
                    } else {
                        name = [aURL absoluteString];
                    }
                    [name drawInRect:textRect withAttributes:__titleAttributes];  
                    if (useSubtitle) {
                        CGFloat titleHeight = ([name sizeWithAttributes:__titleAttributes].height);
                        if ([ctxt isFlipped])
                            textRect.origin.y += titleHeight;
                        textRect.size.height -= titleHeight;
                        [[_dataSource fileView:self subtitleAtIndex:i] drawInRect:textRect withAttributes:__subtitleAttributes];
                    }
                    CGContextRestoreGState(cgContext);
                } 
            }
        }
    }
    
    // avoid hitting the cache thread while a live resize is in progress, but allow cache updates while scrolling
    // use the same range criteria that we used in iterating icons
    NSUInteger iMin = indexRange.location, iMax = NSMaxRange(indexRange);
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
    
    if ([self _hasArrows] && _isDrawingDragImage == NO) {
        if (NSIntersectsRect(rect, _leftArrowFrame))
            [_leftArrow drawWithFrame:_leftArrowFrame inView:self];
        if (NSIntersectsRect(rect, _rightArrowFrame))
            [_rightArrow drawWithFrame:_rightArrowFrame inView:self];
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

- (void)draggedImage:(NSImage *)image endedAt:(NSPoint)screenPoint operation:(NSDragOperation)operation;
{
    // only called if we originated the drag, so the row/column must be valid
    if ((operation & NSDragOperationDelete) != 0 && [self isEditable]) {
        [[self dataSource] fileView:self deleteURLsAtIndexes:_selectedIndexes];
        [self setSelectionIndexes:[NSIndexSet indexSet]];
        [self reloadIcons];
    }
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    // Adding NSDragOperationLink for non-local drags gives us behavior similar to the NSDocument proxy icon, allowing the receiving app to decide what is appropriate; hence, in Finder it now defaults to alias, and you can use option to force a copy.
    NSDragOperation mask = NSDragOperationCopy | NSDragOperationLink;
    if (isLocal)
        mask |= NSDragOperationMove;
    else if ([self isEditable])
        mask |= NSDragOperationDelete;
    return mask;
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
    [_leftArrow setEnabled:curPage != 1];
    [_rightArrow setEnabled:curPage != [anIcon pageCount]];
    NSUInteger r, c;
    // _getGridRow should always succeed.  Drawing entire icon since a mouseover can occur between the time the icon is loaded and drawn, so only the part of the icon below the buttons is drawn (at least, I think that's what happens...)
    if ([self _getGridRow:&r column:&c atPoint:_leftArrowFrame.origin])
        [self setNeedsDisplayInRect:NSInsetRect([self _rectOfIconInRow:r column:c], -2.0 * [self iconScale], -3.0 * [self iconScale])];
}

- (void)leftArrowAction:(id)sender
{
    FVIcon *anIcon = [_leftArrow representedObject];
    [anIcon showPreviousPage];
    [self _updateButtonsForIcon:anIcon];
    NSUInteger r, c;
    // _getGridRow should always succeed
    if ([self _getGridRow:&r column:&c atPoint:_leftArrowFrame.origin])
        [self setNeedsDisplayInRect:NSInsetRect([self _rectOfIconInRow:r column:c], -2.0 * [self iconScale], -3.0 * [self iconScale])];
}

- (void)rightArrowAction:(id)sender
{
    FVIcon *anIcon = [_rightArrow representedObject];
    [anIcon showNextPage];
    [self _updateButtonsForIcon:anIcon];
    NSUInteger r, c;
    // _getGridRow should always succeed
    if ([self _getGridRow:&r column:&c atPoint:_rightArrowFrame.origin])
        [self setNeedsDisplayInRect:NSInsetRect([self _rectOfIconInRow:r column:c], -2.0 * [self iconScale], -3.0 * [self iconScale])];
}

- (BOOL)_hasArrows {
    return [_leftArrow representedObject] != nil;
}

- (void)_showArrowsForIconAtIndex:(NSUInteger)anIndex
{
    NSUInteger r, c;
    
    if ([self _getGridRow:&r column:&c ofIndex:anIndex]) {
    
        FVIcon *anIcon = [self _cachedIconForURL:[self iconURLAtIndex:anIndex]];
        
        if ([anIcon pageCount] > 1) {
        
            NSRect iconRect = [self _rectOfIconInRow:r column:c];
            
            // determine a min/max size for the arrow buttons
            CGFloat side;
#if __LP64__
            side = round(NSHeight(iconRect) / 5);
#else
            side = roundf(NSHeight(iconRect) / 5);
#endif
            side = MIN(side, 32);
            side = MAX(side, 10);
            // 2 pixels between arrows horizontally, and 4 pixels between bottom of arrow and bottom of iconRect
            _leftArrowFrame = _rightArrowFrame = NSMakeRect(NSMidX(iconRect) + 2, NSMaxY(iconRect) - side - 4, side, side);
            _leftArrowFrame.origin.x -= side + 4;
            
            [_leftArrow setRepresentedObject:anIcon];
            [_rightArrow setRepresentedObject:anIcon];
            
            // set enabled states
            [self _updateButtonsForIcon:anIcon];
            
            [self setNeedsDisplayInRect:NSUnionRect(_leftArrowFrame, _rightArrowFrame)];
        }
    }
}

- (void)_hideArrows
{
    if ([self _hasArrows]) {
        [_leftArrow setRepresentedObject:nil];
        [_rightArrow setRepresentedObject:nil];
        [self setNeedsDisplayInRect:NSUnionRect(_leftArrowFrame, _rightArrowFrame)];
    }
}

- (void)mouseEntered:(NSEvent *)event;
{
    const NSTrackingRectTag tag = [event trackingNumber];
    NSUInteger anIndex;
    
    if (CFDictionaryGetValueIfPresent(_trackingRectMap, (const void *)tag, (const void **)&anIndex))
        [self _showArrowsForIconAtIndex:anIndex];
    
    // !!! calling this before adding buttons seems to disable the tooltip on 10.4; what does it do on 10.5?
    [super mouseEntered:event];
}

- (void)mouseExited:(NSEvent *)event;
{
    [super mouseExited:event];
    [self _hideArrows];
}

- (NSURL *)_URLAtPoint:(NSPoint)point;
{
    NSUInteger anIndex = NSNotFound, r, c;
    if ([self _getGridRow:&r column:&c atPoint:point])
        anIndex = [self _indexForGridRow:r column:c];
    return NSNotFound == anIndex ? nil : [self iconURLAtIndex:anIndex];
}

- (void)_openURLs:(NSArray *)URLs
{
    NSEnumerator *e = [URLs objectEnumerator];
    NSURL *aURL;
    while (aURL = [e nextObject]) {
        if ([aURL isEqual:[NSNull null]] == NO &&
            [[self delegate] respondsToSelector:@selector(fileView:shouldOpenURL:)] == NO ||
            [[self delegate] fileView:self shouldOpenURL:aURL] == YES)
            [[NSWorkspace sharedWorkspace] openURL:aURL];
    }
}

- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)userData
{
    NSURL *theURL = [self _URLAtPoint:point];
    NSString *name;
    if ([theURL isFileURL] && noErr == LSCopyDisplayNameForURL((CFURLRef)theURL, (CFStringRef *)&name))
        name = [name autorelease];
    else
        name = [theURL absoluteString];
    return name;
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
    
    if ([self _hasArrows] && NSMouseInRect(p, _leftArrowFrame, [self isFlipped])) {
        [_leftArrow trackMouse:event inRect:_leftArrowFrame ofView:self untilMouseUp:YES];
    }
    else if ([self _hasArrows] && NSMouseInRect(p, _rightArrowFrame, [self isFlipped])) {
        [_rightArrow trackMouse:event inRect:_rightArrowFrame ofView:self untilMouseUp:YES];
    }
    // mark this icon for highlight if necessary
    else if ([self _getGridRow:&r column:&c atPoint:p]) {
        
        // remember _indexForGridRow:column: returns NSNotFound if you're in an empty slot of an existing row/column, but that's a deselect event so we still need to remove all selection indexes and mark for redisplay
        i = [self _indexForGridRow:r column:c];

        if ([_selectedIndexes containsIndex:i] == NO) {
            
            // deselect all if modifier key was not pressed, or i == NSNotFound
            if ((flags & (NSCommandKeyMask | NSShiftKeyMask)) == 0 || NSNotFound == i) {
                [self setSelectionIndexes:[NSIndexSet indexSet]];
            }
            
            // if there's an icon in this cell, add to the current selection (which we may have just reset)
            if (NSNotFound != i) {
                // add a single index for an unmodified or cmd-click
                // add a single index for shift click only if there is no current selection
                if ((flags & NSShiftKeyMask) == 0 || [_selectedIndexes count] == 0) {
                    [self willChangeValueForKey:@"selectionIndexes"];
                    [_selectedIndexes addIndex:i];
                    [self didChangeValueForKey:@"selectionIndexes"];
                }
                else if ((flags & NSShiftKeyMask) != 0) {
                    // Shift-click extends by a region; this is equivalent to iPhoto's grid view.  Finder treats shift-click like cmd-click in icon view, but we have a fixed layout, so this behavior is convenient and will be predictable.
                    
                    // at this point, we know that [_selectedIndexes count] > 0
                    NSParameterAssert([_selectedIndexes count]);
                    
                    NSUInteger start = [_selectedIndexes firstIndex];
                    NSUInteger end = [_selectedIndexes lastIndex];

                    if (i < start) {
                        [self willChangeValueForKey:@"selectionIndexes"];
                        [_selectedIndexes addIndexesInRange:NSMakeRange(i, start - i)];
                        [self didChangeValueForKey:@"selectionIndexes"];
                    }
                    else if (i > end) {
                        [self willChangeValueForKey:@"selectionIndexes"];
                        [_selectedIndexes addIndexesInRange:NSMakeRange(end + 1, i - end)];
                        [self didChangeValueForKey:@"selectionIndexes"];
                    }
                    else if (NSNotFound != _lastClickedIndex) {
                        // This handles the case of clicking in a deselected region between two selected regions.  We want to extend from the last click to the current one, instead of randomly picking an end to start from.
                        [self willChangeValueForKey:@"selectionIndexes"];
                        if (_lastClickedIndex > i)
                            [_selectedIndexes addIndexesInRange:NSMakeRange(i, _lastClickedIndex - i)];
                        else
                            [_selectedIndexes addIndexesInRange:NSMakeRange(_lastClickedIndex + 1, i - _lastClickedIndex)];
                        [self didChangeValueForKey:@"selectionIndexes"];
                    }
                }
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
        
        // always reset this
        _lastClickedIndex = i;
        
        // change selection first, as Finder does
        if ([event clickCount] > 1 && [self _URLAtPoint:p] != nil) {
            if (flags & NSAlternateKeyMask) {
                [FVPreviewer setWebViewContextMenuDelegate:[self delegate]];
                [FVPreviewer previewURL:[self _URLAtPoint:p]];
            } else {
                [self openSelectedURLs:self];
            }
        }
        
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
    rect.size.width = MAX(3.0, fmaxf(aPoint.x, bPoint.x) - NSMinX(rect));
    rect.size.height = MAX(3.0, fmaxf(aPoint.y, bPoint.y) - NSMinY(rect));
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
        [self setNeedsDisplayInRect:_rubberBandRect];
        _rubberBandRect = NSZeroRect;
    }
}

- (void)mouseDragged:(NSEvent *)event
{
    // in mouseDragged:, we're either tracking an arrow button, drawing a rubber band selection, or initiating a drag
    
    NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
    NSURL *pointURL = [self _URLAtPoint:p];
    
    if (NSEqualRects(_rubberBandRect, NSZeroRect) && nil != pointURL) {
        // No previous rubber band selection, so check to see if we're dragging an icon at this point.
        // The condition is also false when we're getting a repeated call to mouseDragged: for rubber band drawing.
        
        NSArray *selectedURLs = nil;
                
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
            
            if (writeURLsToPasteboard(selectedURLs, pboard)) {
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
        [self setNeedsDisplayInRect:_rubberBandRect];
        [self autoscroll:event];
        [super mouseDragged:event];
    }
}

#pragma mark Drop target

- (BOOL)_isLocalDraggingInfo:(id <NSDraggingInfo>)sender
{
    return [[sender draggingSource] isEqual:self];
}

- (BOOL)wantsPeriodicDraggingUpdates { return NO; }

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
            aRect.origin.x += _iconSize.width + _padding.width * (c == [self numberOfColumns] - 1 ? 1 : 2) / 5;
            aRect.size.width = _padding.width / 5;    
            op = FVDropInsert;
            insertIndex = [self _indexForGridRow:r column:c] + 1;
        }
        else if ([self _getGridRow:&r column:&c atPoint:right] && ([self _indexForGridRow:r column:c] < [self numberOfIcons])) {
            
            aRect = [self _rectOfIconInRow:r column:c];
            aRect.origin.x -= _padding.width * (c == 0 ? 2 : 3) / 5;
            aRect.size.width = _padding.width / 5;
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
    
    NSUInteger insertIndex, firstIndex, endIndex;
    // this will set a default highlight based on geometry, but does no validation
    FVDropOperation dropOp = [self _dropOperationAtPointInView:dragLoc highlightRect:&_dropRectForHighlight insertionIndex:&insertIndex];
    
    // We have to make sure the pasteboard really has a URL here, since most NSStrings aren't valid URLs
    if (pasteboardHasURL([sender draggingPasteboard]) == NO) {
        
        dragOp = NSDragOperationNone;
        _dropRectForHighlight = NSZeroRect;
    }
    else if (FVDropOnIcon == dropOp) {
        
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
        
        // inserting inside the block we're dragging doesn't make sense; this does allow dropping a disjoint selection at some locations within the selection
        if ([self _isLocalDraggingInfo:sender]) {
            firstIndex = [_selectedIndexes firstIndex], endIndex = [_selectedIndexes lastIndex] + 1;
            if ([_selectedIndexes containsIndexesInRange:NSMakeRange(firstIndex, endIndex - firstIndex)] &&
                insertIndex >= firstIndex && insertIndex <= endIndex) {
                dragOp = NSDragOperationNone;
                _dropRectForHighlight = NSZeroRect;
            } 
            else {
                dragOp = NSDragOperationMove;
            }
        } 
        else {
            dragOp = NSDragOperationLink;
        }
    }
    
    [self setNeedsDisplay:YES];
    return dragOp;
}

// this is called as soon as the mouse is moved to start a drag, or enters the window from outside
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    if ([self _isLocalDraggingInfo:sender] || pasteboardHasURL([sender draggingPasteboard]))
        return NSDragOperationLink;
    else
        return NSDragOperationNone;
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
        
        if (nil == aURL && [[pboard types] containsObject:NSFilenamesPboardType]) {
            aURL = [NSURL fileURLWithPath:[[pboard propertyListForType:NSFilenamesPboardType] lastObject]];
        }
        if (aURL)
            didPerform = [[self dataSource] fileView:self replaceURLsAtIndexes:[NSIndexSet indexSetWithIndex:idx] withURLs:[NSArray arrayWithObject:aURL]];
    }
    else if (FVDropInsert == dropOp) {
        
        NSArray *allURLs = URLSFromPasteboard([sender draggingPasteboard]);
        
        // move is implemented as delete/insert
        if ([self _isLocalDraggingInfo:sender]) {
            
            // if inserting after the ones we're removing, let the delegate handle the offset the insertion index if necessary
            if ([_selectedIndexes containsIndex:insertIndex] || [_selectedIndexes containsIndex:insertIndex - 1]) {
                didPerform = NO;
            }
            else {
                didPerform = [[self dataSource] fileView:self moveURLsAtIndexes:[self selectionIndexes] toIndex:insertIndex];
            }
        } else {
            NSIndexSet *insertSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(insertIndex, [allURLs count])];
            [[self dataSource] fileView:self insertURLs:allURLs atIndexes:insertSet];
            didPerform = YES;
        }
    }
    else if ([self _isLocalDraggingInfo:sender] == NO) {
           
        // this must be an add operation, and only non-local drag sources can do that
        NSArray *allURLs = URLSFromPasteboard(pboard);
        NSIndexSet *insertSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([self numberOfIcons], [allURLs count])];
        [[self dataSource] fileView:self insertURLs:allURLs atIndexes:insertSet];
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

- (void)insertNewline:(id)sender;
{
    if ([_selectedIndexes count])
        [self openSelectedURLs:sender];
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
    NSUInteger previous = NSNotFound;
    
    if (NSNotFound == curIdx)
        previous = 0;
    else if (0 == curIdx && [self numberOfIcons] > 0) 
        previous = ([self numberOfIcons] - 1);
    else if ([self numberOfIcons] > 0)
        previous = curIdx - 1;
    
    if (NSNotFound != previous) {
        [self scrollItemAtIndexToVisible:previous];
        [self setSelectionIndexes:[NSIndexSet indexSetWithIndex:previous]];
    }
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
    [[NSWorkspace sharedWorkspace] selectFile:[[[self _selectedURLs] lastObject] path] inFileViewerRootedAtPath:nil];
}

- (IBAction)openSelectedURLs:(id)sender
{
    [self _openURLs:[self _selectedURLs]];
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
    [FVPreviewer setWebViewContextMenuDelegate:[self delegate]];
    [FVPreviewer previewURL:[[self _selectedURLs] lastObject]];
}

- (IBAction)delete:(id)sender;
{
    if (NO == [self isEditable] || NO == [[self dataSource] fileView:self deleteURLsAtIndexes:_selectedIndexes])
        NSBeep();
    else
        [self reloadIcons];
}

- (IBAction)selectAll:(id)sender;
{
    [self setSelectionIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfIcons])]];
}

- (IBAction)deselectAll:(id)sender;
{
    [self setSelectionIndexes:[NSIndexSet indexSet]];
}

- (IBAction)copy:(id)sender;
{
    if (NO == writeURLsToPasteboard([self _selectedURLs], [NSPasteboard generalPasteboard]))
        NSBeep();
}

- (IBAction)cut:(id)sender;
{
    [self copy:sender];
    [self delete:sender];
}

- (IBAction)paste:(id)sender;
{
    if ([self isEditable]) {
        NSArray *URLs = URLSFromPasteboard([NSPasteboard generalPasteboard]);
        if ([URLs count])
            [[self dataSource] fileView:self insertURLs:URLs atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange([self numberOfIcons], [URLs count])]];
        else
            NSBeep();
    }
    else NSBeep();
}

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
    NSURL *aURL = [[self _selectedURLs] lastObject];  
    SEL action = [anItem action];
    if (action == @selector(zoomOut:) || action == @selector(zoomIn:))
        return YES;
    else if (action == @selector(revealInFinder:))
        return [aURL isFileURL] && [_selectedIndexes count] == 1;
    else if (action == @selector(openSelectedURLs:) && nil != aURL)
        return YES;
    else if (action == @selector(delete:) || action == @selector(copy:) || action == @selector(cut:))
        return [self isEditable] && [_selectedIndexes count] > 0;
    else if (action == @selector(selectAll:))
        return ([self numberOfIcons] > 0);
    else if (action == @selector(previewAction:))
        return (nil != aURL) && [_selectedIndexes count] == 1;
    else if (action == @selector(paste:))
        return [self isEditable];
    // need to handle print: and other actions
    return (action && [self respondsToSelector:action]);
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
    _lastMouseDownLocInView = [self convertPoint:[event locationInWindow] fromView:nil];
    NSMenu *menu = [[[[self class] defaultMenu] copyWithZone:[NSMenu menuZone]] autorelease];
    
    NSUInteger i,r,c,idx = NSNotFound;
    if ([self _getGridRow:&r column:&c atPoint:_lastMouseDownLocInView])
        idx = [self _indexForGridRow:r column:c];
    
    // Finder changes selection only if the clicked item isn't in the current selection
    if (menu && NO == [_selectedIndexes containsIndex:idx])
        [self setSelectionIndexes:idx == NSNotFound ? [NSIndexSet indexSet] : [NSIndexSet indexSetWithIndex:idx]];

    // remove disabled items and double separators
    i = [menu numberOfItems];
    BOOL wasSeparator = YES;
    while (i--) {
        if ([[menu itemAtIndex:i] isSeparatorItem]) {
            // see if this is a double separator, if so remove it
            if (wasSeparator)
                [menu removeItemAtIndex:i];
        } else if ([self validateMenuItem:[menu itemAtIndex:i]]) {
            // valid menu item, keep it, and it wasn't a separator
            wasSeparator = NO;
        } else {
            // disabled menu item
            [menu removeItemAtIndex:i];
        }
    }
    // remove a separator at index 0
    if ([[menu itemAtIndex:0] isSeparatorItem])
        [menu removeItemAtIndex:0];
        
    if ([[self delegate] respondsToSelector:@selector(fileView:willPopUpMenu:onIconAtIndex:)])
        [[self delegate] fileView:self willPopUpMenu:menu onIconAtIndex:idx];
    
    if ([menu numberOfItems] == 0)
        menu = nil;

    return menu;
}

+ (NSMenu *)defaultMenu
{
    static NSMenu *sharedMenu = nil;
    if (nil == sharedMenu) {
        NSMenuItem *anItem;
        
        sharedMenu = [[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@""];
        NSBundle *bundle = [NSBundle bundleForClass:[FileView class]];
        
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Quick Look", @"FileView", bundle, @"context menu title") action:@selector(previewAction:) keyEquivalent:@""];
        [anItem setTag:FVQuickLookMenuItemTag];
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Open", @"FileView", bundle, @"context menu title") action:@selector(openSelectedURLs:) keyEquivalent:@""];
        [anItem setTag:FVOpenMenuItemTag];
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Reveal in Finder", @"FileView", bundle, @"context menu title") action:@selector(revealInFinder:) keyEquivalent:@""];
        [anItem setTag:FVRevealMenuItemTag];
        
        [sharedMenu addItem:[NSMenuItem separatorItem]];
        
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Zoom In", @"FileView", bundle, @"context menu title") action:@selector(zoomIn:) keyEquivalent:@""];
        [anItem setTag:FVZoomInMenuItemTag];
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Zoom Out", @"FileView", bundle, @"context menu title") action:@selector(zoomOut:) keyEquivalent:@""];
        [anItem setTag:FVZoomOutMenuItemTag];
    }
    return sharedMenu;
}

@end

#pragma mark -
#pragma mark Logging

void CLogv(NSString *format, va_list argList)
{
    NSString *logString = [[NSString alloc] initWithFormat:format arguments:argList];
    
    char *buf = NULL;
    char stackBuf[1024];
    
    // add 1 for the NULL terminator (length arg to getCString:maxLength:encoding: needs to include space for this)
    NSUInteger requiredLength = ([logString maximumLengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
    
    if (requiredLength <= sizeof(stackBuf) && [logString getCString:stackBuf maxLength:sizeof(stackBuf) encoding:NSUTF8StringEncoding]) {
        buf = stackBuf;
    } else if (NULL != (buf = NSZoneMalloc(NULL, requiredLength * sizeof(char))) ){
        [logString getCString:buf maxLength:requiredLength encoding:NSUTF8StringEncoding];
    } else {
        fprintf(stderr, "unable to allocate log buffer\n");
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

static BOOL pasteboardHasURL(NSPasteboard *pboard)
{ 	 
    // also catches case of file URL, which conforms to kUTTypeURL, and strings that might be URLs
    return [URLSFromPasteboard(pboard) count] > 0;
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
            else if (UTTypeConformsTo(flavor, kUTTypeUTF8PlainText)) {
                
                // this is a string that may be a URL; FireFox and other apps don't use any of the standard URL pasteboard types
                err = PasteboardCopyItemFlavorData(carbonPboard, itemID, flavor, &data);
                if (noErr == err && NULL != data) {
                    dataSize = CFDataGetLength(data);
                    
                    destURL = CFURLCreateWithBytes(NULL, CFDataGetBytePtr(data), dataSize, kCFStringEncodingUTF8, NULL);
                    CFRelease(data);
                    
                    // CFURLCreateWithBytes will create a URL from any arbitrary string
                    if (destURL && nil == [(NSURL *)destURL scheme]) {
                        CFRelease(destURL);
                        destURL = NULL;
                    }
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
    
    // ??? On 10.5, NSStringPboardType and kUTTypeUTF8PlainText point to the same data, according to pasteboard peeker; if that's the case on 10.4, we can remove this and the registration for NSStringPboardType.
    if ([[pboard types] containsObject:NSStringPboardType]) {
        NSURL *nsURL = [NSURL URLWithString:[pboard stringForType:NSStringPboardType]];
        if ([nsURL scheme] != nil && [allURLsReadFromPasteboard containsObject:nsURL] == NO)
            [toReturn addObject:nsURL];
    }

    return toReturn;
}

// Once we treat the NSPasteboard as a Carbon pboard, bad things seem to happen on Tiger (-types doesn't work), so return the PasteboardRef by reference to allow the caller to add more types to it or whatever.
static BOOL writeURLsToPasteboard(NSArray *URLs, NSPasteboard *pboard)
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
        }
        else {
            err = PasteboardPutItemFlavor(carbonPboard, itemID, kUTTypeURL, utf8Data, kPasteboardFlavorNoFlags);
        }
    }
    
    if (carbonPboard) 
        CFRelease(carbonPboard);
    
    return noErr == err;
}

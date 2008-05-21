//
//  FileView.m
//  FileViewTest
//
//  Created by Adam Maxwell on 06/23/07.
/*
 This software is Copyright (c) 2007-2008
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

#import <FileView/FileView.h>
#import <FileView/FVFinderLabel.h>
#import <FileView/FVPreviewer.h>

#import <QTKit/QTKit.h>
#import <WebKit/WebKit.h>

#import "FVIcon.h"
#import "FVArrowButtonCell.h"
#import "FVUtilities.h"
#import "FVOperationQueue.h"
#import "FVIconOperation.h"
#import "FVDownload.h"
#import "FVSlider.h"
#import "FVColorMenuView.h"
#import "FVBitmapContextCache.h"
#import "FVAccessibilityIconElement.h"


static NSString *FVWeblocFilePboardType = @"CorePasteboardFlavorType 0x75726C20";

static const NSSize DEFAULT_ICON_SIZE = { 64.0, 64.0 };
static const NSSize DEFAULT_PADDING = { 10.0, 4.0 };
static const CGFloat DEFAULT_MARGIN = 4.0;

// don't bother removing icons from the cache if there are fewer than this value
static const NSUInteger ZOMBIE_CACHE_THRESHOLD = 100;

// thin the icons if we have more than this value; 25 is a good value, but 5 is good for cache testing
static const NSUInteger RELEASE_CACHE_THRESHOLD = 25;

// check the icon cache every five minutes and get rid of stale icons
static const CFTimeInterval ZOMBIE_TIMER_INTERVAL = 300.0;

// time interval for indeterminate download progress indicator updates
static const CFTimeInterval PROGRESS_TIMER_INTERVAL = 0.1;

static NSDictionary *_titleAttributes = nil;
static NSDictionary *_labeledAttributes = nil;
static NSDictionary *_subtitleAttributes = nil;
static CGFloat _titleHeight = 0.0;
static CGFloat _subtitleHeight = 0.0;
static CGColorRef _shadowColor = NULL;

#pragma mark -

@interface FileView (Private)
// wrapper that calls bound array or datasource transparently; for internal use
// clients should access the datasource or bound array directly
- (NSURL *)iconURLAtIndex:(NSUInteger)anIndex;
- (NSUInteger)numberOfIcons;

// only declare methods here to shut the compiler up if we can't rearrange
- (FVIcon *)_cachedIconForURL:(NSURL *)aURL;
- (NSSize)_paddingForScale:(CGFloat)scale;
- (void)_recalculateGridSize;
- (void)_getRangeOfRows:(NSRange *)rowRange columns:(NSRange *)columnRange inRect:(NSRect)aRect;
- (void)_showArrowsForIconAtIndex:(NSUInteger)anIndex;
- (void)_hideArrows;
- (BOOL)_hasArrows;
- (void)_cancelActiveDownloads;
- (void)_addDownload:(FVDownload *)fvDownload;
- (void)_invalidateProgressTimer;

@end

#pragma mark -

@implementation FileView

+ (void)initialize 
{
    FVINITIALIZE(FileView);
    
    NSMutableDictionary *ta = [NSMutableDictionary dictionary];
    [ta setObject:[NSFont systemFontOfSize:12.0] forKey:NSFontAttributeName];
    [ta setObject:[NSColor darkGrayColor] forKey:NSForegroundColorAttributeName];
    NSMutableParagraphStyle *ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    // Apple uses this in IKImageBrowserView
    [ps setLineBreakMode:NSLineBreakByTruncatingTail];
    [ps setAlignment:NSCenterTextAlignment];
    [ta setObject:ps forKey:NSParagraphStyleAttributeName];
    [ps release];
    _titleAttributes = [ta copy];
    
    [ta setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
    _labeledAttributes = [ta copy];
    
    [ta setObject:[NSFont systemFontOfSize:10.0] forKey:NSFontAttributeName];
    [ta setObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName];
    _subtitleAttributes = [ta copy];
    
    NSLayoutManager *lm = [[NSLayoutManager alloc] init];
    _titleHeight = [lm defaultLineHeightForFont:[_titleAttributes objectForKey:NSFontAttributeName]];
    _subtitleHeight = [lm defaultLineHeightForFont:[_subtitleAttributes objectForKey:NSFontAttributeName]];
    [lm release];
    
    CGColorSpaceRef cspace = CGColorSpaceCreateDeviceRGB();
    CGFloat shadowComponents[] = { 0, 0, 0, 0.4 };
    _shadowColor = CGColorCreate(cspace, shadowComponents);
    CGColorSpaceRelease(cspace);
    
    // QTMovie raises if +initialize isn't sent on the AppKit thread
    [QTMovie class];
    
    // binding an NSSlider in IB 3 results in a crash on 10.4
    [self exposeBinding:@"iconScale"];
    [self exposeBinding:@"autoScales"];
    [self exposeBinding:@"iconURLs"];
    [self exposeBinding:@"selectionIndexes"];
}

+ (NSColor *)defaultBackgroundColor
{
    // from Mail.app on 10.4
    CGFloat red = (231.0f/255.0f), green = (237.0f/255.0f), blue = (246.0f/255.0f);
    return [[NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
}

+ (BOOL)accessInstanceVariablesDirectly { return NO; }

// not part of the API because padding is private, and that's a can of worms
- (CGFloat)_columnWidth { return _iconSize.width + _padding.width; }
- (CGFloat)_rowHeight { return _iconSize.height + _padding.height; }

- (void)_commonInit {
    _iconCache = [[NSMutableDictionary alloc] init];
    _iconSize = DEFAULT_ICON_SIZE;
    _autoScales = NO;
    _padding = [self _paddingForScale:1.0];
    _lastMouseDownLocInView = NSZeroPoint;
    // the next two are set to an illegal combination to indicate that no drop is in progress
    _dropIndex = NSNotFound;
    _dropOperation = FVDropBefore;
    _isRescaling = NO;
    _selectedIndexes = [[NSMutableIndexSet alloc] init];
    _lastClickedIndex = NSNotFound;
    _rubberBandRect = NSZeroRect;
    _isMouseDown = NO;
    _iconURLs = nil;
    _isEditable = NO;
    [self setBackgroundColor:[[self class] defaultBackgroundColor]];
    _selectionOverlay = NULL;
    _numberOfColumns = 1;
    _numberOfRows = 1;
    
    CFAllocatorRef alloc = CFAllocatorGetDefault();
    
    // I'm not removing the timer in viewWillMoveToSuperview:nil because we may need to free up that memory, and the frequency is so low that it's insignificant overhead
    CFAbsoluteTime fireTime = CFAbsoluteTimeGetCurrent() + ZOMBIE_TIMER_INTERVAL;
    // runloop will retain this timer, but we'll retain it too and release in -dealloc
    _zombieTimer = FVCreateWeakTimerWithTimeInterval(ZOMBIE_TIMER_INTERVAL, fireTime, self, @selector(_zombieTimerFired:));
    CFRunLoopAddTimer(CFRunLoopGetCurrent(), _zombieTimer, kCFRunLoopDefaultMode);
    
    _lastOrigin = NSZeroPoint;
    _timeOfLastOrigin = CFAbsoluteTimeGetCurrent();
    _trackingRectMap = CFDictionaryCreateMutable(alloc, 0, &FVIntegerKeyDictionaryCallBacks, &FVIntegerValueDictionaryCallBacks);
    
    _iconIndexMap = CFDictionaryCreateMutable(alloc, 0, &FVIntegerKeyDictionaryCallBacks, NULL);
    
    _leftArrow = [[FVArrowButtonCell alloc] initWithArrowDirection:FVArrowLeft];
    [_leftArrow setTarget:self];
    [_leftArrow setAction:@selector(leftArrowAction:)];
    
    _rightArrow = [[FVArrowButtonCell alloc] initWithArrowDirection:FVArrowRight];
    [_rightArrow setTarget:self];
    [_rightArrow setAction:@selector(rightArrowAction:)];
    
    _leftArrowFrame = NSZeroRect;
    _rightArrowFrame = NSZeroRect;
    
    // this is created lazily when needed
    _sliderWindow = nil;
    // always initialize this to -1
    _topSliderTag = -1;
    _bottomSliderTag = -1;

    _activeDownloads = NULL;
    _progressTimer = NULL;
    
    _operationQueue = [FVOperationQueue new];
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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_leftArrow release];
    [_rightArrow release];
    [_iconURLs release];
    CFRelease(_iconIndexMap);
    CFRunLoopTimerInvalidate(_zombieTimer);
    CFRelease(_zombieTimer);
    [_iconCache release];
    [_selectedIndexes release];
    [_backgroundColor release];
    [_sliderWindow release];
    // this variable is accessed in super's dealloc, so set it to NULL
    CFRelease(_trackingRectMap);
    _trackingRectMap = NULL;
    // takes care of the timer as well
    if (_activeDownloads != NULL) {
        [self _cancelActiveDownloads];
        CFRelease(_activeDownloads);
    }
    [_operationQueue terminate];
    [_operationQueue release];
    CGLayerRelease(_selectionOverlay);
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
    if (_autoScales == NO) {
        FVAPIAssert(scale > 0, @"scale must be greater than zero");
        _iconSize.width = DEFAULT_ICON_SIZE.width * scale;
        _iconSize.height = DEFAULT_ICON_SIZE.height * scale;
        
        // arrows out of place now, they will be added again when required when resetting the tracking rects
        [self _hideArrows];
        
        CGLayerRelease(_selectionOverlay);
        _selectionOverlay = NULL;
        
        // the full view will likely need repainting, this also recalculates the grid
        [self reloadIcons];
        
        // Schedule a reload so we always have the correct quality icons, but don't do it while scaling in response to a slider.
        // This will also scroll to the first selected icon; maintaining scroll position while scaling is too jerky.
        if (NO == _isRescaling) {
            _isRescaling = YES;
            // this is only sent in the default runloop mode, so it's not sent during event tracking
            [self performSelector:@selector(_rescaleComplete) withObject:nil afterDelay:0.0];
        }
    }
}

- (CGFloat)iconScale;
{
    return _iconSize.width / DEFAULT_ICON_SIZE.width;
}

- (CGFloat)_autoScaleIconScale;
{
    return _iconSize.width / DEFAULT_ICON_SIZE.width;
}

- (void)_registerForDraggedTypes
{
    if (_isEditable && _dataSource) {
        const SEL selectors[] = 
        { 
            @selector(fileView:insertURLs:atIndexes:forDrop:dropOperation:), 
            @selector(fileView:replaceURLsAtIndexes:withURLs:forDrop:dropOperation:), 
            @selector(fileView:moveURLsAtIndexes:toIndex:forDrop:dropOperation:),
            @selector(fileView:deleteURLsAtIndexes:) 
        };
        NSUInteger i, iMax = sizeof(selectors) / sizeof(SEL);
        for (i = 0; i < iMax; i++)
            FVAPIAssert1([_dataSource respondsToSelector:selectors[i]], @"datasource must implement %@", NSStringFromSelector(selectors[i]));

        [self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, FVWeblocFilePboardType, (NSString *)kUTTypeURL, (NSString *)kUTTypeUTF8PlainText, NSStringPboardType, nil]];
    } else {
        [self registerForDraggedTypes:nil];
    }
}

- (BOOL)autoScales {
    return _autoScales;
}

- (void)setAutoScales:(BOOL)flag {
    if (_autoScales != flag) {
        _autoScales = flag;
        
        // arrows out of place now, they will be added again when required when resetting the tracking rects
        [self _hideArrows];
        
        // the full view will likely need repainting, this also recalculates the grid
        [self reloadIcons];
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
        FVAPIAssert1([obj respondsToSelector:@selector(numberOfURLsInFileView:)], @"datasource must implement %@", NSStringFromSelector(@selector(numberOfURLsInFileView:)));
        FVAPIAssert1([obj respondsToSelector:@selector(fileView:URLAtIndex:)], @"datasource must implement %@", NSStringFromSelector(@selector(fileView:URLAtIndex:)));
    }
    _dataSource = obj;
    // convenient time to do this, although the timer would also handle it
    [_iconCache removeAllObjects];
    CFDictionaryRemoveAllValues(_iconIndexMap);
    
    // make sure these get cleaned up; if the datasource is now nil, we're probably going to deallocate soon
    [self _cancelActiveDownloads];
    [_operationQueue cancel];
    _padding = [self _paddingForScale:[self iconScale]];
    
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

- (BOOL)allowsDownloading 
{
    return _activeDownloads != NULL;
}

- (void)setAllowsDownloading:(BOOL)flag
{
    if (flag && _activeDownloads == NULL) {
        _activeDownloads = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    } else if (flag == NO && _activeDownloads != NULL) {
        [self _cancelActiveDownloads];
        CFRelease(_activeDownloads);
        _activeDownloads = NULL;
    }
}

- (void)setDelegate:(id)obj;
{
    _delegate = obj;
}

- (id)delegate { return _delegate; }

// overall borders around the view
- (CGFloat)_leftMargin { return _padding.width / 2 + DEFAULT_MARGIN; }
- (CGFloat)_rightMargin { return _padding.width / 2 + DEFAULT_MARGIN; }
- (CGFloat)_topMargin { return _titleHeight; }
- (CGFloat)_bottomMargin { return 0.0; }

- (NSUInteger)numberOfRows;
{
    return _numberOfRows;
}

- (NSUInteger)numberOfColumns;
{
    return _numberOfColumns;
}

- (NSSize)_paddingForScale:(CGFloat)scale;
{
    // ??? magic number here... using a fixed padding looked funny at some sizes, so this is now adjustable
    NSSize size = NSZeroSize;
    
    // if we autoscale, we should always derive the scale from the current bounds,  but rather the current bounds. This calculation basically inverts the calculation in _recalculateGridSize
    size.width = DEFAULT_PADDING.width + FVRound(4.0 * scale);
    size.height = size.width + DEFAULT_PADDING.height - DEFAULT_PADDING.width + _titleHeight;
    if ([_dataSource respondsToSelector:@selector(fileView:subtitleAtIndex:)])
        size.height += _subtitleHeight;
    return size;
}

- (FVSliderWindow *)_sliderWindow {
    if (_sliderWindow == nil) {
        _sliderWindow = [[FVSliderWindow alloc] init];
        FVSlider *slider = [_sliderWindow slider];
        // binding & unbinding is handled in viewWillMoveToSuperview:
        [slider setMaxValue:16.0];
        [slider setMinValue:0.5];
        if ([self superview])
            [[_sliderWindow slider] bind:@"value" toObject:self withKeyPath:@"iconScale" options:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSliderMouseExited:) name:FVSliderMouseExitedNotificationName object:slider];
    }
    return _sliderWindow;
}

#define MIN_SLIDER_WIDTH 50.0
#define MAX_SLIDER_WIDTH 200.0
#define SLIDER_HEIGHT 15.0
#define TOP_SLIDER_OFFSET 1.0
#define BOTTOM_SLIDER_OFFSET 19.0

- (NSRect)_topSliderRect
{
    NSRect r = [self visibleRect];
    CGFloat l = FVFloor( NSMidX(r) - FVMax( MIN_SLIDER_WIDTH / 2, FVMin( MAX_SLIDER_WIDTH / 2, NSWidth(r) / 5 ) ) );
    r.origin.x += l;
    r.origin.y += TOP_SLIDER_OFFSET;
    r.size.width -= 2 * l;
    r.size.height = SLIDER_HEIGHT;
    return r;
}

- (NSRect)_bottomSliderRect
{
    NSRect r = [self visibleRect];
    CGFloat l = FVFloor( NSMidX(r) - FVMax( MIN_SLIDER_WIDTH / 2, FVMin( MAX_SLIDER_WIDTH / 2, NSWidth(r) / 5 ) ) );
    r.origin.x += l;
    r.origin.y += NSHeight(r) - BOTTOM_SLIDER_OFFSET;
    r.size.width -= 2 * l;
    r.size.height = SLIDER_HEIGHT;
    return r;
}

// This is the square rect the icon is drawn in.  It doesn't include padding, so rects aren't contiguous.
// Caller is responsible for any centering before drawing.
- (NSRect)_rectOfIconInRow:(NSUInteger)row column:(NSUInteger)column;
{
    NSPoint origin = [self bounds].origin;
    CGFloat leftEdge = origin.x + [self _leftMargin] + [self _columnWidth] * column;
    CGFloat topEdge = origin.y + [self _topMargin] + [self _rowHeight] * row;
    return NSMakeRect(leftEdge, topEdge, _iconSize.width, _iconSize.height);
}

- (NSRect)_rectOfTextForIconRect:(NSRect)iconRect;
{
    NSRect textRect = NSMakeRect(NSMinX(iconRect), NSMaxY(iconRect), NSWidth(iconRect), _padding.height);
    // allow the text rect to extend outside the grid cell
    return NSInsetRect(textRect, -_padding.width / 3.0, 2.0);
}

- (void)_setNeedsDisplayForIconInRow:(NSUInteger)row column:(NSUInteger)column {
    NSRect dirtyRect = [self _rectOfIconInRow:row column:column];
    dirtyRect = NSUnionRect(NSInsetRect(dirtyRect, -2.0 * [self iconScale], -[self iconScale]), [self _rectOfTextForIconRect:dirtyRect]);
    [self setNeedsDisplayInRect:dirtyRect];
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
    if (-1 != _topSliderTag)
        [self removeTrackingRect:_topSliderTag];
    if (-1 != _bottomSliderTag)
        [self removeTrackingRect:_bottomSliderTag];
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
        
        if (_autoScales == NO) {
            NSRect sliderRect = NSIntersectionRect([self _topSliderRect], visibleRect);
            _topSliderTag = [self addTrackingRect:sliderRect owner:self userData:[self _sliderWindow] assumeInside:NSPointInRect(mouseLoc, sliderRect)];  
            sliderRect = NSIntersectionRect([self _bottomSliderRect], visibleRect);
            _bottomSliderTag = [self addTrackingRect:sliderRect owner:self userData:[self _sliderWindow] assumeInside:NSPointInRect(mouseLoc, sliderRect)];  
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

- (void)_rebuildIconIndexMap
{
    CFDictionaryRemoveAllValues(_iconIndexMap);
    
    // -[FileView _cachedIconForURL:]
    id (*cachedIcon)(id, SEL, id);
    cachedIcon = (id (*)(id, SEL, id))[self methodForSelector:@selector(_cachedIconForURL:)];
    
    // -[FileView iconURLAtIndex:]
    id (*iconURLAtIndex)(id, SEL, NSUInteger);
    iconURLAtIndex = (id (*)(id, SEL, NSUInteger))[self methodForSelector:@selector(iconURLAtIndex:)];
    
    NSUInteger i, iMax = [self numberOfIcons];
    
    for (i = 0; i < iMax; i++) {
        NSURL *aURL = iconURLAtIndex(self, @selector(iconURLAtIndex:), i);
        FVIcon *icon = cachedIcon(self, @selector(_cachedIconForURL:), aURL);
        NSParameterAssert(nil != icon);
        CFDictionarySetValue(_iconIndexMap, (const void *)i, (const void *)icon);
    }    
}

- (void)reloadIcons;
{
    // Problem exposed in BibDesk: select all, scroll halfway down in file pane, then change selection to a single row.  FileView content didn't update correctly, even though reloadIcons was called.  Logging drawRect: indicated that the wrong region was being updated, but calling _recalculateGridSize here fixed it.
    [self _recalculateGridSize];
    [self _rebuildIconIndexMap];
    
    // grid may have changed, so do a full redisplay
    [self setNeedsDisplay:YES];
    
    /* 
     Any time the number of icons or scale changes, cursor rects are garbage and need to be reset.  The approved way to do this is by calling invalidateCursorRectsForView:, and the docs say to never invoke -[NSView resetCursorRects] manually.  Unfortunately, tracking rects are still active even though the window isn't key, and we show buttons for non-key windows.  As a consequence, if the number of icons just changed from (say) 3 to 1 in a non-key view, it can receive mouseEntered: events for the now-missing icons.  Possibly we don't need to reset cursor rects since they only change for the key window, but we'll reset everything manually just in case.  Allow NSWindow to handle it if the window is key.
     */
    NSWindow *window = [self window];
    [window invalidateCursorRectsForView:self];
    if ([window isKeyWindow] == NO)
        [self resetCursorRects];
}

#pragma mark Binding support

- (void)bind:(NSString *)binding toObject:(id)observable withKeyPath:(NSString *)keyPath options:(NSDictionary *)options;
{
    [super bind:binding toObject:observable withKeyPath:keyPath options:options];
    if ([binding isEqualToString:@"iconScale"] || [binding isEqualToString:@"autoScales"] || [binding isEqualToString:@"iconURLs"]) {
        [self reloadIcons];
    }
}


- (void)_handleSuperviewDidResize:(NSNotification *)notification {
    NSScrollView *scrollView = [self enclosingScrollView];
    if ((scrollView && [[notification object] isEqual:[self superview]]) || (scrollView == nil && [[notification object] isEqual:self]))
        [self _recalculateGridSize];
}

- (void)viewWillMoveToSuperview:(NSView *)newSuperview
{
    [super viewWillMoveToSuperview:newSuperview];
    
    // mmalc's example unbinds here for a nil superview, but that causes problems if you remove the view and add it back in later (and also can cause crashes as a side effect, if we're not careful with the datasource)
    if (nil == newSuperview) {
        [self removeObserver:self forKeyPath:@"selectionIndexes"];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:FVWebIconUpdatedNotificationName object:nil];
        
        // break a retain cycle; binding is retaining this view
        [[_sliderWindow slider] unbind:@"value"];
    }
    else {
        [self addObserver:self forKeyPath:@"selectionIndexes" options:0 context:NULL];
        
        // bind here (noop if we don't have a slider)
        [[_sliderWindow slider] bind:@"value" toObject:self withKeyPath:@"iconScale" options:nil];
        
        // special case; see FVWebViewIcon for posting and comments
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(_handleWebIconNotification:) 
                                                     name:FVWebIconUpdatedNotificationName object:nil];        
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewBoundsDidChangeNotification object:nil];
}

- (void)viewDidMoveToSuperview {
    NSView *superview = [self superview];
    NSView *observedView = [self enclosingScrollView] ? superview : self;
    
    // this can be send in a dealloc when the view hierarchy is decomposed
    if (superview) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleSuperviewDidResize:) name:NSViewFrameDidChangeNotification object:observedView];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleSuperviewDidResize:) name:NSViewBoundsDidChangeNotification object:observedView];
        
        [self _recalculateGridSize];
        [[self window] invalidateCursorRectsForView:self];
        if ([self window] && [[self window] isKeyWindow] == NO)
            [self resetCursorRects];
    }
}

- (void)unbind:(NSString *)binding
{
    [super unbind:binding];
    if ([binding isEqualToString:@"iconScale"] || [binding isEqualToString:@"autoScales"] || [binding isEqualToString:@"iconURLs"]) {
        [self reloadIcons];
    }
}

- (void)setIconURLs:(NSArray *)anArray;
{
    [_iconURLs autorelease];
    _iconURLs = [anArray copy];
    [self _cancelActiveDownloads];
    // datasource methods all trigger a redisplay, so we have to do the same here
    [self reloadIcons];
}

- (NSArray *)iconURLs;
{
    return _iconURLs;
}

- (void)setSelectionIndexes:(NSIndexSet *)indexSet;
{
    FVAPIAssert(nil != indexSet, @"index set must not be nil");
    [_selectedIndexes autorelease];
    _selectedIndexes = [indexSet mutableCopy];
    NSAccessibilityPostNotification(NSAccessibilityUnignoredAncestor(self), NSAccessibilityFocusedUIElementChangedNotification);
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
    NSParameterAssert(anIndex < [self numberOfIcons]);
    NSURL *aURL = [[self iconURLs] objectAtIndex:anIndex];
    if (nil == aURL)
        aURL = [_dataSource fileView:self URLAtIndex:anIndex];
    if (nil == aURL || [NSNull null] == (id)aURL)
        aURL = [FVIcon missingFileURL];
    return aURL;
}

- (NSUInteger)numberOfIcons
{
    return nil == _iconURLs ? [_dataSource numberOfURLsInFileView:self] : [_iconURLs count];
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
    // I was using [_iconCache objectsForKeys:notFoundMarker], but that assumed that _iconCache was fully populated (and it's filled lazily).  Likewise, using -iconURLs directly causes problems since it may contain NSNull, so there's really no way to get icons in bulk here.
    NSMutableArray *icons = [NSMutableArray arrayWithCapacity:[indexes count]];
        
    // -[NSMutableArray addObject:]
    void (*addObject)(id, SEL, id);
    addObject = (void (*)(id, SEL, id))[icons methodForSelector:@selector(addObject:)];
    
    NSUInteger buffer[512];
    NSRange range = NSMakeRange([indexes firstIndex], [indexes lastIndex] - [indexes firstIndex] + 1);
    NSUInteger i, iMax;
    
    // ??? why isn't this created initially when bindings are used?
    if (0 == CFDictionaryGetCount(_iconIndexMap))
        [self _rebuildIconIndexMap];
    
    NSParameterAssert(CFDictionaryGetCount(_iconIndexMap) == (CFIndex)[self numberOfIcons]);
    
    while ((iMax = [indexes getIndexes:buffer maxCount:sizeof(buffer)/sizeof(NSUInteger) inIndexRange:&range]) > 0) {

        for (i = 0; i < iMax; i++) {
            NSUInteger indexInView = buffer[i];
            FVIcon *icon = (id)CFDictionaryGetValue(_iconIndexMap, (const void *)indexInView);
            NSParameterAssert(nil != icon);
            addObject(icons, @selector(addObject:), icon);
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

- (void)_recalculateGridSize
{
    NSScrollView *scrollView = [self enclosingScrollView];
    NSSize contentSize = scrollView ? [scrollView contentSize] : [self bounds].size;
    NSUInteger numIcons = [self numberOfIcons];
    
    if (_autoScales) {
        
        CGFloat iconScale = FVMax( 0.1, ( contentSize.width - DEFAULT_PADDING.width - 2 * DEFAULT_MARGIN ) / DEFAULT_ICON_SIZE.width );
        _padding = [self _paddingForScale:iconScale];
        
        _numberOfColumns = 1;
        _numberOfRows = numIcons;
        
        iconScale = FVMax( 0.1, ( contentSize.width - [self _leftMargin] - [self _rightMargin] ) / DEFAULT_ICON_SIZE.width );
        _iconSize = NSMakeSize(iconScale * DEFAULT_ICON_SIZE.width, iconScale * DEFAULT_ICON_SIZE.height);
        
        CGLayerRelease(_selectionOverlay);
        _selectionOverlay = NULL;
        
    } else {
        
        _padding = [self _paddingForScale:[self iconScale]];
        
        _numberOfColumns = MAX( 1,  (NSInteger)FVFloor( ( contentSize.width - [self _leftMargin] - [self _rightMargin] + _padding.width ) / [self _columnWidth] ) );
        _numberOfRows = ( [self numberOfIcons]  + _numberOfColumns - 1 ) / _numberOfColumns;
    }
    
    if (scrollView) {
        NSRect frame = { NSZeroPoint, contentSize };
        frame.size.width = FVMax( FVCeil( [self _columnWidth] * _numberOfColumns - _padding.width + [self _leftMargin] + [self _rightMargin] ), contentSize.width );
        frame.size.height = FVMax( FVCeil( [self _rowHeight] * _numberOfRows + [self _topMargin] + [self _bottomMargin] ), contentSize.height );
        if (NSEqualRects([self frame], frame) == NO) {
            [super setFrame:frame];
            if (_autoScales && [scrollView autohidesScrollers] && FVAbs(NSHeight(frame) - contentSize.height) <= [NSScroller scrollerWidth])
                [scrollView tile];
        }
    }
    
    // ??? move to -reloadIcons
    NSUInteger lastSelIndex = [_selectedIndexes lastIndex];
    if (lastSelIndex != NSNotFound && lastSelIndex >= numIcons) {
        NSMutableIndexSet *tmpIndexes = [_selectedIndexes mutableCopy];
        [tmpIndexes removeIndexesInRange:NSMakeRange(numIcons, lastSelIndex + 1 - numIcons)];
        [self setSelectionIndexes:tmpIndexes];
        [tmpIndexes release];
    }
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
    if (point.x <= [self _leftMargin] || point.y <= [self _topMargin])
        return NO;
    
    // column width is padding + icon width
    // row height is padding + icon width
    NSUInteger idx, nc = [self numberOfColumns], nr = [self numberOfRows];
    
    idx = 0;
    CGFloat start;
    
    while (idx < nc) {
        
        start = [self _leftMargin] + (_iconSize.width + _padding.width) * idx;
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
        
        start = [self _topMargin] + (_iconSize.height + _padding.height) * idx;
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

- (void)_enqueueReleaseOperationForIcons:(NSArray *)icons;
{    
    NSUInteger i, iMax = [icons count];
    NSMutableArray *operations = [[NSMutableArray alloc] initWithCapacity:iMax];
    FVIcon *icon;
    for (i = 0; i < iMax; i++) {
        icon = [icons objectAtIndex:i];
        if ([icon canReleaseResources]) {
            FVReleaseOperation *op = [[FVReleaseOperation alloc] initWithIcon:icon view:nil];
            [op setQueuePriority:FVOperationQueuePriorityLow];
            [operations addObject:op];
            [op release];
        }
    }
    if ([operations count])
        [_operationQueue addOperations:operations];
    [operations release];
}

- (void)_enqueueRenderOperationForIcons:(NSArray *)icons withPriority:(FVOperationQueuePriority)priority;
{    
    NSUInteger i, iMax = [icons count];
    NSMutableArray *operations = [[NSMutableArray alloc] initWithCapacity:iMax];
    FVIcon *icon;
    for (i = 0; i < iMax; i++) {
        icon = [icons objectAtIndex:i];
        if ([icon needsRenderForSize:_iconSize]) {
            FVRenderOperation *op = [[FVRenderOperation alloc] initWithIcon:icon view:self];
            [op setQueuePriority:priority];
            [operations addObject:op];
            [op release];
        }
    }
    if ([operations count])
        [_operationQueue addOperations:operations];
    [operations release];
}

- (void)iconUpdated:(FVIcon *)updatedIcon;
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

    NSUInteger i;
    
    // If an icon isn't visible, there's no need to redisplay anything.  Similarly, if 20 icons are displayed and only 5 updated, there's no need to redraw all 20.  Geometry calculations are much faster than redrawing, in general.
    for (i = iMin; i < iMax; i++) {
        
        FVIcon *anIcon = (id)CFDictionaryGetValue(_iconIndexMap, (const void *)i);
        if (anIcon == updatedIcon) {
            NSUInteger r, c;
            if ([self _getGridRow:&r column:&c ofIndex:i])
                [self _setNeedsDisplayForIconInRow:r column:c];
        }
    }
}

// drawRect: uses -releaseResources on icons that aren't visible but present in the datasource, so we just need a way to cull icons that are cached but not currently in the datasource
- (void)_zombieTimerFired:(CFRunLoopTimerRef)timer
{
    NSUInteger i, iMax = [self numberOfIcons];
    
    // don't do anything unless there's a meaningful discrepancy between the number of items reported by the datasource and our cache
    if ((iMax + ZOMBIE_CACHE_THRESHOLD) < [_iconCache count]) {
        
        NSMutableSet *iconURLsToKeep = [NSMutableSet set];        
        for (i = 0; i < iMax; i++) {
            NSURL *aURL = [self iconURLAtIndex:i];
            if (aURL) [iconURLsToKeep addObject:aURL];
        }
        
        NSMutableSet *toRemove = [NSMutableSet setWithArray:[_iconCache allKeys]];
        [toRemove minusSet:iconURLsToKeep];
        
        // anything remaining in toRemove is not present in the dataSource, so remove it from the cache
        NSEnumerator *keyEnum = [toRemove objectEnumerator];
        NSURL *aURL;
        while ((aURL = [keyEnum nextObject]))
            [_iconCache removeObjectForKey:aURL];
    }
}

- (void)_handleWebIconNotification:(NSNotification *)aNote
{
    [self iconUpdated:[aNote object]];
}

#pragma mark Drawing

// no save/restore needed because of when these are called in -drawRect: (this is why they're private)

- (void)_drawDropHighlight;
{
    CGFloat lineWidth = 2.0;
    NSBezierPath *p;
    NSUInteger r, c;
    NSRect aRect = NSZeroRect;
    
    switch (_dropOperation) {
        case FVDropOn:
            if (_dropIndex == NSNotFound) {
                aRect = [self visibleRect];
            } else {
                [self _getGridRow:&r column:&c ofIndex:_dropIndex];
                aRect = [self _rectOfIconInRow:r column:c];
            }
            break;
        case FVDropBefore:
            [self _getGridRow:&r column:&c ofIndex:_dropIndex];
            aRect = [self _rectOfIconInRow:r column:c];
            // aRect size is 6, and should be centered between icons horizontally
            aRect.origin.x -= _padding.width / 2 + 3.0;
            aRect.size.width = 6.0;    
            break;
        case FVDropAfter:
            [self _getGridRow:&r column:&c ofIndex:_dropIndex];
            aRect = [self _rectOfIconInRow:r column:c];
            // aRect size is 6, and should be centered between icons horizontally
            aRect.origin.x += _iconSize.width + _padding.width / 2 - 3.0;
            aRect.size.width = 6.0;
            break;
        default:
            break;
    }
    
    if (NSIsEmptyRect(aRect) == NO) {
        aRect = [self centerScanRect:aRect];
        
        [[[NSColor alternateSelectedControlColor] colorWithAlphaComponent:0.2] setFill];
        [[[NSColor alternateSelectedControlColor] colorWithAlphaComponent:0.8] setStroke];
        
        if (_dropOperation == FVDropOn) {
            // it's either a drop on the whole table or on top of a cell
            p = [NSBezierPath fv_bezierPathWithRoundRect:NSInsetRect(aRect, 0.5 * lineWidth, 0.5 * lineWidth) xRadius:7 yRadius:7];
            [p fill];
        }
        else {
            // similar to NSTableView's between-row drop indicator
            CGFloat radius = NSWidth(aRect) / 2;
            NSPoint point = NSMakePoint(NSMidX(aRect), NSMaxY(aRect));
            p = [NSBezierPath bezierPath];
            [p appendBezierPathWithArcWithCenter:point radius:radius startAngle:-90 endAngle:270];
            point.y = NSMinY(aRect);
            [p appendBezierPathWithArcWithCenter:point radius:radius startAngle:90 endAngle:450];
        }
        [p setLineWidth:lineWidth];
        [p stroke];
        [p setLineWidth:1.0];
    }
}

- (void)_drawHighlightInRect:(NSRect)aRect;
{
    CGContextRef drawingContext = [[NSGraphicsContext currentContext] graphicsPort];
    
    // drawing into a CGImage and then overlaying it keeps the rubber band highlight much more responsive
    if (NULL == _selectionOverlay) {
        
        _selectionOverlay = CGLayerCreateWithContext(drawingContext, CGSizeMake(NSWidth(aRect), NSHeight(aRect)), NULL);
        CGContextRef layerContext = CGLayerGetContext(_selectionOverlay);
        NSRect imageRect = NSZeroRect;
        CGSize layerSize = CGLayerGetSize(_selectionOverlay);
        imageRect.size.height = layerSize.height;
        imageRect.size.width = layerSize.width;
        CGContextClearRect(layerContext, *(CGRect *)&imageRect);
        
        [NSGraphicsContext saveGraphicsState];
        NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:layerContext flipped:YES];
        [NSGraphicsContext setCurrentContext:nsContext];
        [nsContext saveGraphicsState];
        
        NSColor *strokeColor = [[NSColor colorWithCalibratedWhite:1.0 alpha:0.8] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
        NSColor *fillColor = [[NSColor colorWithCalibratedWhite:0.0 alpha:0.2] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
        [strokeColor setStroke];
        [fillColor setFill];
        imageRect = NSInsetRect(imageRect, 1.0, 1.0);
        NSBezierPath *p = [NSBezierPath fv_bezierPathWithRoundRect:imageRect xRadius:5 yRadius:5];
        [p setLineWidth:2.0];
        [p fill];
        [p stroke];
        [p setLineWidth:1.0];
        
        [nsContext restoreGraphicsState];
        [NSGraphicsContext restoreGraphicsState];
    }
    // make sure we use source over for drawing the image
    CGContextSaveGState(drawingContext);
    CGContextSetBlendMode(drawingContext, kCGBlendModeNormal);
    CGContextDrawLayerInRect(drawingContext, *(CGRect *)&aRect, _selectionOverlay);
    CGContextRestoreGState(drawingContext);
}

- (void)_drawRubberbandRect
{
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.3] setFill];
    NSRect r = [self centerScanRect:NSInsetRect(_rubberBandRect, 0.5, 0.5)];
    NSRectFillUsingOperation(r, NSCompositeSourceOver);
    // NSFrameRect doesn't respect setStroke
    [[NSColor lightGrayColor] setFill];
    NSFrameRectWithWidth(r, 1.0);
}

- (void)_drawDropMessage;
{
    NSRect aRect = [self centerScanRect:NSInsetRect([self visibleRect], 20, 20)];
    NSBezierPath *path = [NSBezierPath fv_bezierPathWithRoundRect:aRect xRadius:10 yRadius:10];
    CGFloat pattern[2] = { 12.0, 6.0 };
    
    // This sets all future paths to have a dash pattern, and it's not affected by save/restore gstate on Tiger.  Lame.
    CGFloat previousLineWidth = [path lineWidth];
    // ??? make this a continuous function of width <= 3
    [path setLineWidth:(NSWidth(aRect) > 100 ? 3.0 : 2.0)];
    [path setLineDash:pattern count:2 phase:0.0];
    [[NSColor lightGrayColor] setStroke];
    [path stroke];
    [path setLineWidth:previousLineWidth];
    [path setLineDash:NULL count:0 phase:0.0];

    NSBundle *bundle = [NSBundle bundleForClass:[FileView class]];
    NSString *message = NSLocalizedStringFromTableInBundle(@"Drop Files Here", @"FileView", bundle, @"placeholder message for empty file view");
    NSMutableAttributedString *attrString = [[[NSMutableAttributedString alloc] initWithString:message] autorelease];
    CGFloat fontSize = 24.0;
    [attrString addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:fontSize] range:NSMakeRange(0, [attrString length])];
    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor lightGrayColor] range:NSMakeRange(0, [attrString length])];
    
    NSMutableParagraphStyle *ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [ps setAlignment:NSCenterTextAlignment];
    [attrString addAttribute:NSParagraphStyleAttributeName value:ps range:NSMakeRange(0, [attrString length])];
    [ps release];
    
    // avoid drawing text right up to the path at really small widths
    aRect = NSInsetRect(aRect, NSWidth(aRect) / 10, 0);
    
    CGFloat singleLineHeight = NSHeight([attrString boundingRectWithSize:aRect.size options:0]);
    
    // NSLayoutManager's defaultLineHeightForFont doesn't include padding that NSStringDrawing uses
    NSRect r = [attrString boundingRectWithSize:aRect.size options:NSStringDrawingUsesLineFragmentOrigin];
    
    /*  Assumes that localizations also use space to separate words; on 10.5 could use componentsSeparatedByCharactersInSet:.  Another route would be to use NSSpellChecker, but it's not clear what language to pass, and is buggy in some versions (only works if you're checking spelling).  Hence we'll just avoid overengineering here...
     */
    NSUInteger wordCount = [[message componentsSeparatedByString:@" "] count];
    
    // reduce font size until we have no more than wordCount lines
    while (NSHeight(r) > wordCount * singleLineHeight) {
        fontSize -= 1.0;
        [attrString addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:fontSize] range:NSMakeRange(0, [attrString length])];
        singleLineHeight = NSHeight([attrString boundingRectWithSize:aRect.size options:0]);
        r = [attrString boundingRectWithSize:aRect.size options:NSStringDrawingUsesLineFragmentOrigin];
    }
    aRect.origin.y = (NSHeight(aRect) - NSHeight(r)) * 1 / 2;
    [attrString drawWithRect:aRect options:NSStringDrawingUsesLineFragmentOrigin];
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
    bounds.origin.x += [self _leftMargin];
    bounds.origin.y += [self _topMargin];
    
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
    
    // Queuing will call needsRenderForSize: after initial display has taken place, since it may flush the icon's cache
    // this isn't obvious from the method name; it all takes place in a single op to avoid locking twice
    
    // enqueue visible icons with high priority
    NSArray *iconsToRender = [self iconsAtIndexes:visibleIndexes];
    [self _enqueueRenderOperationForIcons:iconsToRender withPriority:FVOperationQueuePriorityHigh];
    
    // Call this only for icons that we're not going to display "soon."  The problem with this approach is that if you only have a single icon displayed at a time (say in a master-detail view), FVIcon cache resources will continue to be used up since each one is cached and then never touched again (if it doesn't show up in this loop, that is).  We handle this by using a timer that culls icons which are no longer present in the datasource.  I suppose this is only a symptom of the larger problem of a view maintaining a cache of model objects...but expecting a client to be aware of our caching strategy and icon management is a bit much.  
    
    // Don't release resources while scrolling; caller has already checked -inLiveResize and _isRescaling for us

    if ([_iconCache count] > RELEASE_CACHE_THRESHOLD && NO == [self _isFastScrolling]) {
        
        // make sure we don't call this on any icons that we just added to the render queue
        NSMutableIndexSet *unusedIndexes = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfIcons])];
        [unusedIndexes removeIndexes:visibleIndexes];
        
        // If scrolling quickly, avoid releasing icons that may become visible
        CGFloat velocity = [self _scrollVelocity];
        
        if (ABS(velocity) > 10.0f && [unusedIndexes count] > 0) {
            // going down: don't release anything between end of visible range and the last icon
            // going up: don't release anything between the first icon and the start of visible range
            if (velocity > 0) { 
                [unusedIndexes removeIndexesInRange:NSMakeRange([visibleIndexes lastIndex], [self numberOfIcons] - [visibleIndexes lastIndex])];
            }
            else {
                [unusedIndexes removeIndexesInRange:NSMakeRange(0, [visibleIndexes firstIndex])];
            }
        }

        if ([unusedIndexes count]) {
            // Since the same FVIcon instance is returned for duplicate URLs, the same icon instance may receive -renderOffscreen and -releaseResources in the same pass if it represents a visible icon and a hidden icon.
            NSSet *renderSet = [[NSSet alloc] initWithArray:iconsToRender];
            NSMutableArray *unusedIcons = [[self iconsAtIndexes:unusedIndexes] mutableCopy];
            NSUInteger i = [unusedIcons count];
            while (i--) {
                FVIcon *anIcon = [unusedIcons objectAtIndex:i];
                if ([renderSet containsObject:anIcon])
                    [unusedIcons removeObjectAtIndex:i];
            }
            [self _enqueueReleaseOperationForIcons:unusedIcons];
            [renderSet release];
            [unusedIcons release];
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
    CGFloat shadowBlur = 2.0 * [self iconScale];
    CGSize shadowOffset = CGSizeMake(0.0, -[self iconScale]);
    
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
                
                // allow some extra for the shadow (-5)
                NSRect textRect = [self _rectOfTextForIconRect:fileRect];
                // always draw icon and text together, as they may overlap due to shadow and finder label, and redrawing a part may look odd
                BOOL willDrawIcon = _isDrawingDragImage || [self needsToDrawRect:NSUnionRect(NSInsetRect(fileRect, -2.0 * [self iconScale], -[self iconScale]), textRect)];
                                
                if (willDrawIcon) {

                    FVIcon *image = [self _cachedIconForURL:aURL];
                    
                    // note that iconRect will be transformed for a flipped context
                    NSRect iconRect = fileRect;
                    
                    // draw highlight, then draw icon over it, as Finder does
                    if ([_selectedIndexes containsIndex:i])
                        [self _drawHighlightInRect:NSInsetRect(fileRect, -4, -4)];
                    
                    CGContextSaveGState(cgContext);
                    
                    // draw a shadow behind the image/page
                    CGContextSetShadowWithColor(cgContext, shadowOffset, shadowBlur, _shadowColor);
                    
                    // possibly better performance by caching all bitmaps in a flipped state, but bookkeeping is a pain
                    CGContextTranslateCTM(cgContext, 0, NSMaxY(iconRect));
                    CGContextScaleCTM(cgContext, 1, -1);
                    iconRect.origin.y = 0;
                    
                    // Note: don't use integral rects here to avoid res independence issues (on Tiger, centerScanRect: just makes an integral rect).  The icons may create an integral bitmap context, but it'll still be drawn into this rect with correct scaling.
                    iconRect = [self centerScanRect:iconRect];
                                    
                    if (useFastDrawingPath)
                        [image fastDrawInRect:iconRect ofContext:cgContext];
                    else
                        [image drawInRect:iconRect ofContext:cgContext];

                    CGContextRestoreGState(cgContext);
                    CGContextSaveGState(cgContext);
                    
                    BOOL isFlippedContext = [ctxt isFlipped];
                    
                    // @@ this is a hack for drawing into the drag image context
                    if (NO == isFlippedContext) {
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
                        name = [[aURL absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                    }
                    
                    NSUInteger label = [FVFinderLabel finderLabelForURL:aURL];
                    if (label > 0) {
                        CGRect labelRect = *(CGRect *)&textRect;
                        
                        // for drag image context
                        if (NO == isFlippedContext)
                            labelRect.origin.y += _titleHeight;
                        labelRect.size.height = _titleHeight;                        
                        [FVFinderLabel drawFinderLabel:label inRect:labelRect ofContext:cgContext flipped:isFlippedContext roundEnds:YES];
                        
                        // labeled title uses black text for greater contrast; inset horizontally because of the rounded end caps
                        NSRect titleRect = NSInsetRect(textRect, _titleHeight / 2.0, 0);
                        [name drawWithRect:titleRect options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingOneShot attributes:_labeledAttributes];
                    }
                    else {
                        [name drawWithRect:textRect options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingOneShot attributes:_titleAttributes];
                    }
                    
                    if (useSubtitle) {
                        if (isFlippedContext)
                            textRect.origin.y += _titleHeight;
                        textRect.size.height -= _titleHeight;
                        [[_dataSource fileView:self subtitleAtIndex:i] drawWithRect:textRect options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingOneShot attributes:_subtitleAttributes];
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

- (NSRect)_rectOfProgressIndicatorForIconAtIndex:(NSUInteger)anIndex;
{
    NSUInteger r, c;
    NSRect frame = NSZeroRect;
    if ([self _getGridRow:&r column:&c ofIndex:anIndex]) {    
        frame = [self _rectOfIconInRow:r column:c];
        NSPoint center = NSMakePoint(NSMidX(frame), NSMidY(frame));
        
        CGFloat size = NSHeight(frame) / 2;
        frame.size.height = size;
        frame.size.width = size;
        frame.origin.x = center.x - NSWidth(frame) / 2;
        frame.origin.y = center.y - NSHeight(frame) / 2;
    }
    return frame;
}

static void _drawProgressIndicatorForDownload(const void *key, const void *value, void *view)
{
    FileView *self = view;
    FVDownload *fvDownload = (id)value;
    
    NSUInteger anIndex = [fvDownload indexInView];
    
    // we only draw a if there's an active download for this URL/index pair
    if (anIndex < [self numberOfIcons] && [[self iconURLAtIndex:anIndex] isEqual:[fvDownload downloadURL]]) {
        
        NSRect frame = [self _rectOfProgressIndicatorForIconAtIndex:anIndex];
        [[fvDownload progressIndicator] drawWithFrame:frame inView:self];
    }
}

- (void)drawRect:(NSRect)rect;
{
    NSRect visRect = [self visibleRect];
    
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
    if (_dropIndex != NSNotFound || _dropOperation == FVDropOn) {
        [self _drawDropHighlight];
    }
    else if (NSIsEmptyRect(_rubberBandRect) == NO) {
        [self _drawRubberbandRect];
    }
    
    if ([self allowsDownloading])
        CFDictionaryApplyFunction(_activeDownloads, _drawProgressIndicatorForDownload, self);
}

#pragma mark Drag source

- (void)draggedImage:(NSImage *)image endedAt:(NSPoint)screenPoint operation:(NSDragOperation)operation;
{
    // only called if we originated the drag, so the row/column must be valid
    if ((operation & NSDragOperationDelete) != 0 && operation != NSDragOperationEvery && [self isEditable]) {
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
        [self _setNeedsDisplayForIconInRow:r column:c];
}

- (void)_redisplayIconAfterPageChanged:(FVIcon *)anIcon
{
    [self _updateButtonsForIcon:anIcon];
    NSUInteger r, c;
    // _getGridRow should always succeed; either arrow frame would work here, since both are in the same icon
    if ([self _getGridRow:&r column:&c atPoint:_leftArrowFrame.origin]) {
        // render immediately so the placeholder path doesn't draw
        if ([anIcon needsRenderForSize:_iconSize])
            [anIcon renderOffscreen];
        [self _setNeedsDisplayForIconInRow:r column:c];
    }    
}

- (void)leftArrowAction:(id)sender
{
    FVIcon *anIcon = [_leftArrow representedObject];
    [anIcon showPreviousPage];
    [self _redisplayIconAfterPageChanged:anIcon];
}

- (void)rightArrowAction:(id)sender
{
    FVIcon *anIcon = [_rightArrow representedObject];
    [anIcon showNextPage];
    [self _redisplayIconAfterPageChanged:anIcon];
}

- (BOOL)_hasArrows {
    return [_leftArrow representedObject] != nil;
}

- (void)_showArrowsForIconAtIndex:(NSUInteger)anIndex
{
    NSUInteger r, c;
    
    // this can happen if we screwed up in managing cursor rects
    NSParameterAssert(anIndex < [self numberOfIcons]);
    
    if ([self _getGridRow:&r column:&c ofIndex:anIndex]) {
    
        FVIcon *anIcon = [self _cachedIconForURL:[self iconURLAtIndex:anIndex]];
        
        if ([anIcon pageCount] > 1) {
        
            NSRect iconRect = [self _rectOfIconInRow:r column:c];
            
            // determine a min/max size for the arrow buttons
            CGFloat side;
            side = FVRound(NSHeight(iconRect) / 5);
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
    
    // Finder doesn't show buttons unless it's the front app.  If Finder is the front app, it shows them for any window, regardless of main/key state, so we'll do the same.
    if ([NSApp isActive]) {
        if (CFDictionaryGetValueIfPresent(_trackingRectMap, (const void *)tag, (const void **)&anIndex)) {
            [self _showArrowsForIconAtIndex:anIndex];
        } else if (_autoScales == NO && _sliderWindow && [event userData] == _sliderWindow) {
            
            if ([_sliderWindow parentWindow] == nil) {
                NSRect sliderRect = tag == _bottomSliderTag ? [self _bottomSliderRect] : [self _topSliderRect];
                sliderRect = [self convertRect:sliderRect toView:nil];
                sliderRect.origin = [[self window] convertBaseToScreen:sliderRect.origin];
                // looks cool to use -animator here, but makes it hard to hit...
                if (NSEqualRects([_sliderWindow frame], sliderRect) == NO)
                    [_sliderWindow setFrame:sliderRect display:NO];
                
                [_sliderWindow orderFront:self];
                [[self window] addChildWindow:_sliderWindow ordered:NSWindowAbove];
            }
        }
    }
    
    
    // !!! calling this before adding buttons seems to disable the tooltip on 10.4; what does it do on 10.5?
    [super mouseEntered:event];
}

// we can't do this in mouseExited: since it's received as soon as the mouse enters the slider's window (and checking the mouse location just postpones the problems)
- (void)handleSliderMouseExited:(NSNotification *)aNote
{
    if ([[_sliderWindow parentWindow] isEqual:[self window]]) {
        [[self window] removeChildWindow:_sliderWindow];
        [_sliderWindow orderOut:self];
    }
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
    while ((aURL = [e nextObject])) {
        if ([aURL isEqual:[FVIcon missingFileURL]] == NO &&
            ([[self delegate] respondsToSelector:@selector(fileView:shouldOpenURL:)] == NO ||
             [[self delegate] fileView:self shouldOpenURL:aURL] == YES))
            [[NSWorkspace sharedWorkspace] openURL:aURL];
    }
}

- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)userData
{
    NSURL *theURL = [self _URLAtPoint:point];
    NSString *name;
    if ([theURL isFileURL]) {
        if (noErr == LSCopyDisplayNameForURL((CFURLRef)theURL, (CFStringRef *)&name))
            name = [name autorelease];
        else
            name = [[theURL path] lastPathComponent];
    } else {
        name = [[theURL absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
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
    _isMouseDown = YES;
    
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
    rect.size.width = FVMax(3.0, FVMax(aPoint.x, bPoint.x) - NSMinX(rect));
    rect.size.height = FVMax(3.0, FVMax(aPoint.y, bPoint.y) - NSMinY(rect));
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
    _isMouseDown = NO;
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
    
    // _isMouseDown tells us if the mouseDown: event originated in this view; if not, just ignore it
    
    if (NSEqualRects(_rubberBandRect, NSZeroRect) && nil != pointURL && _isMouseDown) {
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
            
            if (FVWriteURLsToPasteboard(selectedURLs, pboard)) {
                // OK to pass nil for the image, since we totally ignore it anyway
                [self dragImage:nil at:p offset:NSZeroSize event:event pasteboard:pboard source:self slideBack:YES];
            }
        }
        else {
            [super mouseDragged:event];
        }
        
    }
    else if (_isMouseDown) {   
        
        // no icons to drag, so we must draw the rubber band rectangle
        _rubberBandRect = NSIntersectionRect(_rectWithCorners(_lastMouseDownLocInView, p), [self bounds]);
        [self setSelectionIndexes:[self _allIndexesInRubberBandRect]];
        [self setNeedsDisplayInRect:_rubberBandRect];
        [self autoscroll:event];
        [super mouseDragged:event];
    }
}

- (void)magnifyWithEvent:(NSEvent *)theEvent;
{
    float dz = [theEvent deltaZ];
    dz = dz > 0 ? FVMin(0.2, dz) : FVMax(-0.2, dz);
    [self setIconScale:FVMax(0.1, [self iconScale] + 0.5 * dz)];
}

#pragma mark Drop target

- (void)setDropIndex:(NSUInteger)anIndex dropOperation:(FVDropOperation)anOperation
{
    _dropIndex = anIndex;
    _dropOperation = anOperation;
}

- (BOOL)_isLocalDraggingInfo:(id <NSDraggingInfo>)sender
{
    return [[sender draggingSource] isEqual:self];
}

- (BOOL)wantsPeriodicDraggingUpdates { return NO; }

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    NSPoint dragLoc = [self convertPoint:[sender draggingLocation] fromView:nil];
    NSPoint p = dragLoc;
    NSUInteger r, c;
    NSDragOperation dragOp = [sender draggingSourceOperationMask] & ~NSDragOperationMove;
    BOOL isCopy = [self allowsDownloading] && dragOp == NSDragOperationCopy;
    NSUInteger insertIndex, firstIndex, endIndex;
    
    // !!! this is quite expensive to call repeatedly in -draggingUpdated
    NSArray *draggedURLs = FVURLsFromPasteboard([sender draggingPasteboard]);
    
    // First determine the drop location, check whether the index is not NSNotFound, because the grid cell can be empty
    if ([self _getGridRow:&r column:&c atPoint:p] && NSNotFound != (_dropIndex = [self _indexForGridRow:r column:c])) {
        _dropOperation = FVDropOn;
    } else {
        p = NSMakePoint(dragLoc.x + _iconSize.width - 0.5, dragLoc.y);

        if ([self _getGridRow:&r column:&c atPoint:p] && NSNotFound != (_dropIndex = [self _indexForGridRow:r column:c])) {
            _dropOperation = FVDropBefore;
        } else {
            p = NSMakePoint(dragLoc.x - _iconSize.width + 0.5, dragLoc.y);
            
            if ([self _getGridRow:&r column:&c atPoint:p] && NSNotFound != (_dropIndex = [self _indexForGridRow:r column:c])) {
                _dropOperation = FVDropAfter;
            } else {
                // drop on the whole view
                _dropOperation = FVDropOn;
                _dropIndex = NSNotFound;
            }
        }
    }
    
    // We won't reset the drop location info when we propose NSDragOperationNone, because the delegate may want to override our decision, we will reset it at the end
    
    if ([draggedURLs count] == 0) {
        // We have to make sure the pasteboard really has a URL here, since most NSStrings aren't valid URLs, but the delegate may accept other types
        dragOp = NSDragOperationNone;
    }
    else if ([self _isLocalDraggingInfo:sender] && isCopy == NO) {
        // invalidate some local drags, otherwise make sure we use a Move operation
        if (FVDropOn == _dropOperation) {
            // drop on the whole view (add operation) or an icon (replace operation) makes no sense for a local drag, but the delegate may override
            dragOp = NSDragOperationNone;
        } 
        else if (FVDropBefore == _dropOperation || FVDropAfter == _dropOperation) {
            // inserting inside the block we're dragging doesn't make sense; this does allow dropping a disjoint selection at some locations within the selection; the delegate may override
            insertIndex = FVDropAfter == _dropOperation ? _dropIndex + 1 : _dropIndex;
            firstIndex = [_selectedIndexes firstIndex], endIndex = [_selectedIndexes lastIndex] + 1;
            if ([_selectedIndexes containsIndexesInRange:NSMakeRange(firstIndex, endIndex - firstIndex)] &&
                insertIndex >= firstIndex && insertIndex <= endIndex) {
                dragOp = NSDragOperationNone;
            } 
            else {
                dragOp = NSDragOperationMove;
            }
        }
    }
    else if (isCopy == NO) {
        dragOp = NSDragOperationLink;
    }
    
    // we could allow the delegate to change the _dropIndex and _dropOperation as NSTableView does, but we don't use that at present
    if ([[self delegate] respondsToSelector:@selector(fileView:validateDrop:draggedURLs:proposedIndex:proposedDropOperation:proposedDragOperation:)])
        dragOp = [[self delegate] fileView:self validateDrop:sender draggedURLs:draggedURLs proposedIndex:_dropIndex proposedDropOperation:_dropOperation proposedDragOperation:dragOp];
    
    // make sure we're consistent, also see comment above
    if (dragOp == NSDragOperationNone) {
        _dropIndex = NSNotFound;
        _dropOperation = FVDropBefore;
    }
    
    [self setNeedsDisplay:YES];
    return dragOp;
}

// this is called as soon as the mouse is moved to start a drag, or enters the window from outside
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    return [self draggingUpdated:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    _dropIndex = NSNotFound;
    _dropOperation = FVDropBefore;
    [self setNeedsDisplay:YES];
}

// only invoked if performDragOperation returned YES
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;
{
    _dropIndex = NSNotFound;
    _dropOperation = FVDropBefore;
    [self reloadIcons];
}

static NSURL *makeCopyOfFileAtURL(NSURL *fileURL) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [fileURL path];
    NSString *basePath = [path stringByDeletingPathExtension];
    NSString *ext = [path pathExtension];
    NSUInteger i = 0;
    NSString *newPath = nil;
    
    do {
        newPath = [[NSString stringWithFormat:@"%@-%i", basePath, ++i] stringByAppendingPathExtension:ext];
    } while ([fm fileExistsAtPath:newPath]);
    
    if ([fm copyPath:path toPath:newPath handler:nil]) {
        return [NSURL fileURLWithPath:newPath];
    } else {
        return nil;
    }
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSDragOperation dragOp = [sender draggingSourceOperationMask] & ~NSDragOperationMove;
    BOOL isCopy = [self allowsDownloading] && dragOp == NSDragOperationCopy;
    BOOL isMove = [self _isLocalDraggingInfo:sender] && isCopy == NO;
    BOOL didPerform = NO;
    NSArray *draggedURLs = isMove ? nil : FVURLsFromPasteboard(pboard);
    NSArray *allURLs = draggedURLs;
    NSMutableArray *downloads = nil;
    NSUInteger insertIndex = 0;
    
    if (FVDropBefore == _dropOperation) {
        insertIndex = _dropIndex;
    } else if (FVDropAfter == _dropOperation) {
        insertIndex = _dropIndex + 1;
    } else if (_dropIndex == NSNotFound) {
        insertIndex = [self numberOfIcons];
    } else {
        insertIndex = _dropIndex;
        if ([allURLs count] > 1)
            allURLs = [NSArray arrayWithObject:[allURLs objectAtIndex:0]];
    }
    
    if (isCopy) {
        NSMutableArray *copiedURLs = [NSMutableArray array];
        NSEnumerator *urlEnum = [allURLs objectEnumerator];
        NSURL *aURL;
        NSUInteger i = insertIndex;
        
        downloads = [NSMutableArray array];
        
        while (aURL = [urlEnum nextObject]) {
            if ([aURL isFileURL])
                aURL = makeCopyOfFileAtURL(aURL);
            else
                [downloads addObject:[[[FVDownload alloc] initWithDownloadURL:aURL indexInView:i] autorelease]];
            if (aURL) {
                [copiedURLs addObject:aURL];
                i++;
            }
        }
        allURLs = copiedURLs;
    }
    
    if (isMove) {
        
        didPerform = [[self dataSource] fileView:self moveURLsAtIndexes:[self selectionIndexes] toIndex:_dropIndex forDrop:sender dropOperation:_dropOperation];
        
    } else if (FVDropBefore == _dropOperation || FVDropAfter == _dropOperation || NSNotFound == _dropIndex) {
           
        // drop on the whole view
        NSIndexSet *insertSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(insertIndex, [allURLs count])];
        [[self dataSource] fileView:self insertURLs:allURLs atIndexes:insertSet forDrop:sender dropOperation:_dropOperation];
        didPerform = YES;

    }
    else {
        // we're targeting a particular cell, make sure that cell is a legal replace operation
        
        NSURL *aURL = [allURLs lastObject];
        
        // only drop a single file on a given cell!
        
        if (nil == aURL && [[pboard types] containsObject:NSFilenamesPboardType]) {
            aURL = [NSURL fileURLWithPath:[[pboard propertyListForType:NSFilenamesPboardType] lastObject]];
        }
        if (aURL)
            didPerform = [[self dataSource] fileView:self replaceURLsAtIndexes:[NSIndexSet indexSetWithIndex:_dropIndex] withURLs:[NSArray arrayWithObject:aURL] forDrop:sender dropOperation:_dropOperation];
    }
    
    if ([downloads count]) {
        NSUInteger i = 0, count = [downloads count];
        for (i = 0; i < count; i++) {
            FVDownload *download = [downloads objectAtIndex:i];
            if (i + insertIndex < [self numberOfIcons] && [[download downloadURL] isEqual:[self iconURLAtIndex:i + insertIndex]]) {
                [self _addDownload:download];
            }
        }
    }
    
    // if we return NO, concludeDragOperation doesn't get called
    _dropIndex = NSNotFound;
    _dropOperation = FVDropBefore;
    [self setNeedsDisplay:YES];
    
    // reload is handled in concludeDragOperation:
    return didPerform;
}

#pragma mark User interaction

// override to select the first or last item when (back)tabbing into the file view
- (BOOL)becomeFirstResponder {
    if ([super becomeFirstResponder]) {
        if (YES) {
            NSUInteger idx = NSNotFound, numIcons = [self numberOfIcons];
            if (numIcons > 0) {
                switch ([[self window] keyViewSelectionDirection]) {
                    case NSSelectingNext:
                        idx = 0;
                        break;
                    case NSSelectingPrevious:
                        idx = numIcons - 1;
                        break;
                    default:
                        break;
                }
                if (idx != NSNotFound) {
                    [self scrollItemAtIndexToVisible:idx];
                    [self setSelectionIndexes:[NSIndexSet indexSetWithIndex:idx]];
                }
            }
        }
        return YES;
    } else {
        return NO;
    }
}

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
    NSUInteger curIdx = [_selectedIndexes lastIndex];
    
    if ([self numberOfIcons] > 0 && curIdx != numIcons - 1)
        [self selectNextIcon:self];
    else
        [[self window] selectNextKeyView:self]; 
}

- (void)insertBacktab:(id)sender;
{
    NSUInteger curIdx = [_selectedIndexes firstIndex];
    
    if ([self numberOfIcons] > 0 && curIdx != 0)
        [self selectPreviousIcon:self];
    else
        [[self window] selectPreviousKeyView:self]; 
}

- (void)moveToBeginningOfLine:(id)sender;
{
    if ([_selectedIndexes count] == 1) {
        FVIcon *anIcon = [self _cachedIconForURL:[self iconURLAtIndex:[_selectedIndexes firstIndex]]];
        if ([anIcon currentPageIndex] > 1) {
            [anIcon showPreviousPage];
            [self _redisplayIconAfterPageChanged:anIcon];
        }
    }
}

- (void)moveToEndOfLine:(id)sender;
{
    if ([_selectedIndexes count] == 1) {
        FVIcon *anIcon = [self _cachedIconForURL:[self iconURLAtIndex:[_selectedIndexes firstIndex]]];
        if ([anIcon currentPageIndex] < [anIcon pageCount]) {
            [anIcon showNextPage];
            [self _redisplayIconAfterPageChanged:anIcon];
        }
    }
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

- (void)scrollToBeginningOfDocument:(id)sender {
    NSRect bounds = [self bounds];
    [self scrollRectToVisible:NSMakeRect(NSMinX(bounds), NSMinY(bounds), 1.0, 1.0)];
}

- (void)scrollToEndOfDocument:(id)sender {
    NSRect bounds = [self bounds];
    [self scrollRectToVisible:NSMakeRect(NSMaxX(bounds) - 1.0, NSMaxY(bounds) - 1.0, 1.0, 1.0)];
}

- (void)scrollPageUp:(id)sender {
    [[self enclosingScrollView] pageUp:sender];
}

- (void)scrollPageDown:(id)sender {
    [[self enclosingScrollView] pageDown:sender];
}

- (void)_selectFirstVisibleIcon {
    NSRect rect = [self visibleRect];
    NSRange rowRange, columnRange;
    
    [self _getRangeOfRows:&rowRange columns:&columnRange inRect:[self visibleRect]];
    
    NSUInteger r, rMax = NSMaxRange(rowRange);
    NSUInteger c, cMax = NSMaxRange(columnRange);
    NSUInteger idx;
    
    // now iterate each row/column to see if it intersects the rect
    for (r = rowRange.location; r < rMax; r++)  {
        for (c = columnRange.location; c < cMax; c++) {    
            if (NSIntersectsRect([self _rectOfIconInRow:r column:c], rect)) {
                idx = [self _indexForGridRow:r column:c];
                if (NSNotFound != idx) {
                    [self setSelectionIndexes:[NSIndexSet indexSetWithIndex:idx]];
                    return;
                }
            }
        }
    }
}

- (void)pageUp:(id)sender {
    [[self enclosingScrollView] pageUp:sender];
    [self _selectFirstVisibleIcon];
}

- (void)pageDown:(id)sender {
    [[self enclosingScrollView] pageDown:sender];
    [self _selectFirstVisibleIcon];
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
    NSUInteger previous = NSNotFound, numIcons = [self numberOfIcons];
    
    if (numIcons > 0) {
        if (NSNotFound != curIdx && curIdx > 0)
            previous = curIdx - 1;
        else
            previous = numIcons - 1;
        
        [self scrollItemAtIndexToVisible:previous];
        [self setSelectionIndexes:[NSIndexSet indexSetWithIndex:previous]];
    }
}

- (IBAction)selectNextIcon:(id)sender;
{
    NSUInteger curIdx = [_selectedIndexes lastIndex];
    NSUInteger next = NSNotFound, numIcons = [self numberOfIcons];
    
    if (numIcons > 0) {
        if (NSNotFound != curIdx && curIdx + 1 < numIcons) 
            next = curIdx + 1;
        else
            next = 0;
        
        [self scrollItemAtIndexToVisible:next];
        [self setSelectionIndexes:[NSIndexSet indexSetWithIndex:next]];
    }
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

- (IBAction)toggleAutoScales:(id)sender;
{
    [self setAutoScales:[self autoScales] == NO];
}

- (IBAction)previewAction:(id)sender;
{
    if ([_selectedIndexes count] == 1) {
        [FVPreviewer setWebViewContextMenuDelegate:[self delegate]];
        [FVPreviewer previewURL:[[self _selectedURLs] lastObject]];
    }
    else {
        [FVPreviewer setWebViewContextMenuDelegate:nil];
        [FVPreviewer previewFileURLs:[self _selectedURLs]];
    }
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
    if (NO == FVWriteURLsToPasteboard([self _selectedURLs], [NSPasteboard generalPasteboard]))
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
        NSArray *URLs = FVURLsFromPasteboard([NSPasteboard generalPasteboard]);
        if ([URLs count])
            [[self dataSource] fileView:self insertURLs:URLs atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange([self numberOfIcons], [URLs count])] forDrop:nil dropOperation:FVDropOn];
        else
            NSBeep();
    }
    else NSBeep();
}

#pragma mark Context menu

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
    NSURL *aURL = [[self _selectedURLs] lastObject];  
    SEL action = [anItem action];
    
    // generally only check this for actions that are dependent on single selection
    BOOL isMissing = [aURL isEqual:[FVIcon missingFileURL]];
    BOOL isEditable = [self isEditable];
    BOOL selectionCount = [_selectedIndexes count];
    
    if (action == @selector(zoomOut:) || action == @selector(zoomIn:))
        return _autoScales == NO;
    else if (action == @selector(toggleAutoScales:)) {
        [anItem setState:_autoScales ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(revealInFinder:))
        return [aURL isFileURL] && [_selectedIndexes count] == 1 && NO == isMissing;
    else if (action == @selector(openSelectedURLs:) || action == @selector(copy:))
        return selectionCount > 0;
    else if (action == @selector(delete:) || action == @selector(cut:))
        return isEditable && selectionCount > 0;
    else if (action == @selector(selectAll:))
        return ([self numberOfIcons] > 0);
    else if (action == @selector(previewAction:))
        return selectionCount > 0;
    else if (action == @selector(paste:))
        return [self isEditable];
    else if (action == @selector(submenuAction:))
        return selectionCount > 1 || ([_selectedIndexes count] == 1 && [aURL isFileURL]);
    else if (action == @selector(changeFinderLabel:) || [anItem tag] == FVChangeLabelMenuItemTag) {

        BOOL enabled = NO;
        NSInteger state = NSOffState;

        // if multiple selection, enable unless all the selected URLs are missing or non-files
        if (selectionCount > 1) {
            NSEnumerator *urlEnum = [[self _selectedURLs] objectEnumerator];
            NSURL *url;
            while ((url = [urlEnum nextObject])) {
                // if we find a single file URL that isn't the missing file URL, enable the menu
                if ([url isEqual:[FVIcon missingFileURL]] == NO && [url isFileURL])
                    enabled = YES;
            }
        }
        else if (selectionCount == 1 && NO == isMissing && [aURL isFileURL]) {
            
            NSInteger label = [FVFinderLabel finderLabelForURL:aURL];
            // 10.4
            if (label == [anItem tag])
                state = NSOnState;
            
            // 10.5+
            if ([anItem respondsToSelector:@selector(setView:)])
                [(FVColorMenuView *)[anItem view] selectLabel:label];
            
            enabled = YES;
        }
        
        if ([anItem respondsToSelector:@selector(setView:)])
            [(FVColorMenuView *)[anItem view] setTarget:self];
        
        // no effect on menu items with a custom view
        [anItem setState:state];
        return enabled;
    }
    else if (action == @selector(downloadSelectedLink:)) {
        if ([self allowsDownloading]) {
            FVDownload *download = aURL ? [[[FVDownload alloc] initWithDownloadURL:aURL indexInView:[_selectedIndexes firstIndex]] autorelease] : nil;
            Boolean alreadyDownloading = CFDictionaryContainsValue(_activeDownloads, download);
            // don't check reachability; just handle the error if it fails
            return isMissing == NO && isEditable && selectionCount == 1 && [aURL isFileURL] == NO && FALSE == alreadyDownloading;
        } else return NO;
    }
    
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
        NSMenuItem *menuItem = [menu itemAtIndex:i];
        if ([menuItem isSeparatorItem]) {
            // see if this is a double separator, if so remove it
            if (wasSeparator)
                [menu removeItemAtIndex:i];
            wasSeparator = YES;
        } else if ([self validateMenuItem:menuItem]) {
            if ([menuItem submenu] && [self validateMenuItem:[[menuItem submenu] itemAtIndex:0]] == NO) {
                // disabled submenu item
                [menu removeItemAtIndex:i];
            } else {
                // valid menu item, keep it, and it wasn't a separator
                wasSeparator = NO;
            }
        } else {
            // disabled menu item
            [menu removeItemAtIndex:i];
        }
    }
    // remove a separator at index 0
    if ([menu numberOfItems] > 0 && [[menu itemAtIndex:0] isSeparatorItem])
        [menu removeItemAtIndex:0];
        
    if ([[self delegate] respondsToSelector:@selector(fileView:willPopUpMenu:onIconAtIndex:)])
        [[self delegate] fileView:self willPopUpMenu:menu onIconAtIndex:idx];
    
    if ([menu numberOfItems] == 0)
        menu = nil;

    return menu;
}

// sender must respond to -tag, and may respond to -enclosingMenuItem
- (IBAction)changeFinderLabel:(id)sender;
{
    // Sender tag corresponds to the Finder label integer
    NSInteger label = [sender tag];
    FVAPIAssert1(label >=0 && label <= 7, @"invalid label %d (must be between 0 and 7)", label);
    
    NSArray *selectedURLs = [self _selectedURLs];
    NSUInteger i, iMax = [selectedURLs count];
    for (i = 0; i < iMax; i++) {
        [FVFinderLabel setFinderLabel:label forURL:[selectedURLs objectAtIndex:i]];
    }
    [self setNeedsDisplay:YES];
    
    // we have to close the menu manually; FVColorMenuCell returns its control view's menu item
    if ([sender respondsToSelector:@selector(enclosingMenuItem)] && [[[sender enclosingMenuItem] menu] respondsToSelector:@selector(cancelTracking)])
        [[[sender enclosingMenuItem] menu] cancelTracking];
}

static void addFinderLabelsToSubmenu(NSMenu *submenu)
{
    NSInteger i = 0;
    NSRect iconRect = NSZeroRect;
    iconRect.size = NSMakeSize(12, 12);
    NSBezierPath *clipPath = [NSBezierPath fv_bezierPathWithRoundRect:iconRect xRadius:3.0 yRadius:3.0];
    
    for (i = 0; i < 8; i++) {
        NSMenuItem *anItem = [submenu addItemWithTitle:[FVFinderLabel localizedNameForLabel:i] action:@selector(changeFinderLabel:) keyEquivalent:@""];
        [anItem setTag:i];
        
        NSImage *image = [[NSImage alloc] initWithSize:iconRect.size];
        [image lockFocus];
        
        // round off the corners of the swatches, but don't draw the full rounded ends
        [clipPath addClip];
        [FVFinderLabel drawFinderLabel:i inRect:iconRect roundEnds:NO];
        
        // Finder displays an unbordered cross for clearing the label, so we'll do something similar
        [[NSColor darkGrayColor] setStroke];
        if (0 == i) {
            NSBezierPath *p = [NSBezierPath bezierPath];
            [p moveToPoint:NSMakePoint(3, 3)];
            [p lineToPoint:NSMakePoint(9, 9)];
            [p moveToPoint:NSMakePoint(3, 9)];
            [p lineToPoint:NSMakePoint(9, 3)];
            [p setLineWidth:2.0];
            [p setLineCapStyle:NSRoundLineCapStyle];
            [p stroke];
            [p setLineWidth:1.0];
            [p setLineCapStyle:NSButtLineCapStyle];
        }
        else {
            // stroke clip path for a subtle border; stroke is wide enough to display a thin line inside the clip region
            [clipPath stroke];
        }
        [image unlockFocus];
        [anItem setImage:image];
        [image release];
    }
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
        
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Remove", @"FileView", bundle, @"context menu title") action:@selector(delete:) keyEquivalent:@""];
        [anItem setTag:FVRemoveMenuItemTag];
        
        // Finder labels: submenu on 10.4, NSView on 10.5
        if ([anItem respondsToSelector:@selector(setView:)])
            [sharedMenu addItem:[NSMenuItem separatorItem]];
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Set Finder Label", @"FileView", bundle, @"context menu title") action:NULL keyEquivalent:@""];
        [anItem setTag:FVChangeLabelMenuItemTag];
        
        if ([anItem respondsToSelector:@selector(setView:)]) {
            FVColorMenuView *view = [FVColorMenuView menuView];
            [view setTarget:nil];
            [view setAction:@selector(changeFinderLabel:)];
            [anItem setView:view];
        }
        else {
            NSMenu *submenu = [[NSMenu allocWithZone:[sharedMenu zone]] initWithTitle:@""];
            [anItem setSubmenu:submenu];
            [submenu release];
            addFinderLabelsToSubmenu(submenu);
        }
        
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Download and Replace", @"FileView", bundle, @"context menu title") action:@selector(downloadSelectedLink:) keyEquivalent:@""];
        [anItem setTag:FVDownloadMenuItemTag];
        
        [sharedMenu addItem:[NSMenuItem separatorItem]];
        
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Zoom In", @"FileView", bundle, @"context menu title") action:@selector(zoomIn:) keyEquivalent:@""];
        [anItem setTag:FVZoomInMenuItemTag];
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Zoom Out", @"FileView", bundle, @"context menu title") action:@selector(zoomOut:) keyEquivalent:@""];
        [anItem setTag:FVZoomOutMenuItemTag];
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Single Column", @"FileView", bundle, @"context menu title") action:@selector(toggleAutoScales:) keyEquivalent:@""];
        [anItem setTag:FVAutoScalesMenuItemTag];

    }
    return sharedMenu;
}

#pragma mark Download support

- (void)download:(NSURLDownload *)download decideDestinationWithSuggestedFilename:(NSString *)filename;
{
    NSString *fullPath = nil;
    if ([[self delegate] respondsToSelector:@selector(fileView:downloadDestinationWithSuggestedFilename:)])
        fullPath = [[[self delegate] fileView:self downloadDestinationWithSuggestedFilename:filename] path];
    else
        fullPath = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    
    if (nil == fullPath) {
        FVDownload *fvDownload = (id)CFDictionaryGetValue(_activeDownloads, download);
        [download cancel];
        if (fvDownload) {
            CFDictionaryRemoveValue(_activeDownloads, download);
            [self setNeedsDisplay:YES];
        }
        if (CFDictionaryGetCount(_activeDownloads) == 0)
            [self _invalidateProgressTimer];

    } else {
        [download setDestination:fullPath allowOverwrite:NO];
    }
}

- (void)download:(NSURLDownload *)download didCreateDestination:(NSString *)path
{
    FVDownload *fvDownload = (id)CFDictionaryGetValue(_activeDownloads, download);
    [fvDownload setFileURL:[NSURL fileURLWithPath:path]];
}

- (void)_invalidateProgressTimer
{
    if (_progressTimer) {
        CFRunLoopTimerInvalidate(_progressTimer);
        CFRelease(_progressTimer);
        _progressTimer = NULL;
    }
}

- (void)_progressTimerFired:(CFRunLoopTimerRef)timer
{
    [self setNeedsDisplay:YES];
}

- (void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response;
{
    FVDownload *fvDownload = (id)CFDictionaryGetValue(_activeDownloads, download);
    long long expectedLength = [response expectedContentLength];
    [fvDownload setExpectedLength:expectedLength];
    if (NSURLResponseUnknownLength == expectedLength && NULL == _progressTimer) {
        // runloop will retain this timer, but we'll retain it too and release in -dealloc
        _progressTimer = FVCreateWeakTimerWithTimeInterval(PROGRESS_TIMER_INTERVAL, CFAbsoluteTimeGetCurrent() + PROGRESS_TIMER_INTERVAL, self, @selector(_progressTimerFired:));
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), _progressTimer, kCFRunLoopDefaultMode);
    }
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length;
{
    FVDownload *fvDownload = (id)CFDictionaryGetValue(_activeDownloads, download);
    [fvDownload incrementReceivedLengthBy:length];
    NSURL *currentURL = [self iconURLAtIndex:[fvDownload indexInView]];
    NSURL *dest = [fvDownload fileURL];
    // things could have been rearranged since the download was started
    if (nil != dest && [currentURL isEqual:[fvDownload downloadURL]]) {
        NSUInteger r, c;
        [self _getGridRow:&r column:&c ofIndex:[fvDownload indexInView]];
        [self _setNeedsDisplayForIconInRow:r column:c];
    }
}

- (void)downloadDidFinish:(NSURLDownload *)download;
{
    FVDownload *fvDownload = (id)CFDictionaryGetValue(_activeDownloads, download);
    if (fvDownload) {
        NSUInteger idx = [fvDownload indexInView];
        NSURL *currentURL = [self iconURLAtIndex:idx];
        NSURL *downloadURL = [fvDownload downloadURL];
        NSURL *dest = [fvDownload fileURL];
        // things could have been rearranged since the download was started, so don't replace the wrong one
        if (nil != dest) {
            if (NO == [currentURL isEqual:downloadURL]) {
                idx = [self numberOfIcons];
                while (idx-- > 0) {
                    currentURL = [self iconURLAtIndex:idx];
                    if ([currentURL isEqual:downloadURL])
                        break;
                }
            }
            if ([currentURL isEqual:downloadURL] && [[self dataSource] fileView:self replaceURLsAtIndexes:[NSIndexSet indexSetWithIndex:idx] withURLs:[NSArray arrayWithObject:dest] forDrop:nil dropOperation:FVDropOn]) {
                NSUInteger r, c;
                if ([self _getGridRow:&r column:&c ofIndex:idx])
                    [self _setNeedsDisplayForIconInRow:r column:c];
            }
        }
        CFDictionaryRemoveValue(_activeDownloads, download);
    }
    if (CFDictionaryGetCount(_activeDownloads) == 0)
        [self _invalidateProgressTimer];
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error;
{
    // could badge with a failure icon here, but that would be a pain to keep track of
    FVDownload *fvDownload = (id)CFDictionaryGetValue(_activeDownloads, download);
    if (fvDownload) {
        CFDictionaryRemoveValue(_activeDownloads, download);
        [self setNeedsDisplay:YES];
    }
    if (CFDictionaryGetCount(_activeDownloads) == 0)
        [self _invalidateProgressTimer];
}

- (NSWindow *)downloadWindowForAuthenticationSheet:(WebDownload *)download
{
    return [self window];
}

static void cancelDownload(const void *key, const void *value, void *context)
{
    [(NSURLDownload *)key cancel];
}

- (void)_cancelActiveDownloads;
{
    if ([self allowsDownloading]) {
        CFDictionaryApplyFunction(_activeDownloads, cancelDownload, NULL);
        CFDictionaryRemoveAllValues(_activeDownloads);
        [self _invalidateProgressTimer];
        [self setNeedsDisplay:YES];
    }
}

- (void)_addDownload:(FVDownload *)fvDownload
{
    if ([self allowsDownloading]) {
        NSURL *theURL = [fvDownload downloadURL];
        WebDownload *download = [[WebDownload alloc] initWithRequest:[NSURLRequest requestWithURL:theURL] delegate:self];
        CFDictionarySetValue(_activeDownloads, download, fvDownload);
        [download release];
        [self setNeedsDisplay:YES];
    }
}

- (void)downloadSelectedLink:(id)sender
{
    if ([self allowsDownloading]) {
        // validation ensures that we have a single selection, and that there is no current download with this URL
        NSUInteger selIndex = [_selectedIndexes firstIndex];
        if (NSNotFound != selIndex) {
            NSURL *theURL = [self iconURLAtIndex:selIndex];
            FVDownload *fvDownload = [[FVDownload alloc] initWithDownloadURL:theURL indexInView:selIndex];       
            [self _addDownload:fvDownload];  
            [fvDownload release];
        }
    }
}

#pragma mark Accessibility

- (NSArray *)accessibilityAttributeNames {
    static NSArray *attributes = nil;
    if (attributes == nil)
        attributes = [[[super accessibilityAttributeNames] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:NSAccessibilityChildrenAttribute, NSAccessibilitySelectedChildrenAttribute, nil]] retain];
    return attributes;
}

- (id)accessibilityAttributeValue:(NSString *)attribute {
    if ([attribute isEqualToString:NSAccessibilityRoleAttribute]) {
        return NSAccessibilityGroupRole;
    } else if ([attribute isEqualToString:NSAccessibilityRoleDescriptionAttribute]) {
        return NSAccessibilityRoleDescription(NSAccessibilityGroupRole, nil);
    } else if ([attribute isEqualToString:NSAccessibilityChildrenAttribute]) {
        NSMutableArray *children = [NSMutableArray array];
        NSUInteger i, count = [self numberOfIcons];
        for (i = 0; i < count; i++)
            [children addObject:[FVAccessibilityIconElement elementWithIndex:i parent:self]];
        return NSAccessibilityUnignoredChildren(children);
    } else if ([attribute isEqualToString:NSAccessibilitySelectedChildrenAttribute]) {
        NSMutableArray *children = [NSMutableArray array];
        NSUInteger i = [_selectedIndexes firstIndex];
        while (i != NSNotFound) {
            [children addObject:[FVAccessibilityIconElement elementWithIndex:i parent:self]];
            i = [_selectedIndexes indexGreaterThanIndex:i];
        }
        return NSAccessibilityUnignoredChildren(children);
    } else {
        return [super accessibilityAttributeValue:attribute];
    }
}

- (BOOL)accessibilityIsIgnored {
    return NO;
}

- (id)accessibilityHitTest:(NSPoint)point {
    NSUInteger i, r, c;
    NSPoint localPoint = [self convertPoint:[[self window] convertScreenToBase:point] fromView:nil];
    if ([self _getGridRow:&r column:&c atPoint:localPoint]) {
        i = [self _indexForGridRow:r column:c];
        if (i != NSNotFound)
            return [[FVAccessibilityIconElement elementWithIndex:i parent:self] accessibilityHitTest:point];
    }
    return NSAccessibilityUnignoredAncestor(self);
}

- (id)accessibilityFocusedUIElement {
    NSUInteger i = [_selectedIndexes firstIndex];
    if (i != NSNotFound)
        return [[FVAccessibilityIconElement elementWithIndex:i parent:self] accessibilityFocusedUIElement];
    else
        return NSAccessibilityUnignoredAncestor(self);
}

- (NSURL *)URLForIconElement:(id)element {
    return [self iconURLAtIndex:[element index]];
}

- (NSRect)screenRectForIconElement:(id)element {
    NSRect rect = NSZeroRect;
    NSUInteger r, c;
    if ([self _getGridRow:&r column:&c ofIndex:[element index]]) {
        rect = [self _rectOfIconInRow:r column:c];
        rect = [self convertRect:rect toView:nil];
        rect.origin = [[self window] convertBaseToScreen:rect.origin];
    }
    return rect;
}

- (BOOL)isIconElementSelected:(id)element {
    return [[self selectionIndexes] containsIndex:[element index]];
}

- (void)setSelected:(BOOL)selected forIconElement:(id)element {
    NSUInteger i = [element index];
    if (selected) {
        [self setSelectionIndexes:[NSIndexSet indexSetWithIndex:i]];
    } else if ([[self selectionIndexes] containsIndex:i]) {
        NSMutableIndexSet *indexes = [[self selectionIndexes] mutableCopy];
        [indexes removeIndex:i];
        [self setSelectionIndexes:indexes];
        [indexes release];
    }
}

- (void)openIconElement:(id)element {
    [self _openURLs:[NSArray arrayWithObjects:[self iconURLAtIndex:[element index]], nil]];
}

@end

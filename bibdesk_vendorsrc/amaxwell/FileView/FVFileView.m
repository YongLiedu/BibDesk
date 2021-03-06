//
//  FVFileView.m
//  FileView
//
//  Created by Adam Maxwell on 06/23/07.
/*
 This software is Copyright (c) 2007-2016
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

#import "FVFileView.h"
#import "FVFinderLabel.h"
#import "FVPreviewer.h"

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
#import "FVAccessibilityIconElement.h"

#import <sys/stat.h>
#import <sys/time.h>
#import <pthread.h>
#include <sys/attr.h>
#include <unistd.h>

// draws grid and margin frames
#define DEBUG_GRID 0

static Class QLPreviewPanelClass = Nil;

static NSString *FVWeblocFilePboardType = @"CorePasteboardFlavorType 0x75726C20";

static char _FVFileViewContentObservationContext;

#define SELECTIONINDEXES_BINDING_NAME  @"selectionIndexes"
#define CONTENT_BINDING_NAME           @"content"
#define ICONSCALE_BINDING_NAME         @"iconScale"
#define MINICONSCALE_BINDING_NAME      @"minIconScale"
#define MAXICONSCALE_BINDING_NAME      @"maxIconScale"
#define DISPLAYMODE_BINDING_NAME       @"displayMode"
#define EDITABLE_BINDING_NAME          @"editable"
#define ALLOWSDOWNLOADING_BINDING_NAME @"allowsDownloading"
#define BACKGROUNDCOLOR_BINDING_NAME   @"backgroundColor"
#define TEXTCOLOR_BINDING_NAME         @"textColor"
#define SUBTITLECOLOR_BINDING_NAME     @"subtitleColor"
#define FONT_BINDING_NAME              @"font"
#define SUBTITLEFONT_BINDING_NAME      @"subtitleFont"

// it's important that DEFAULT_PADDING.height >= TEXT_OFFSET - HIGHLIGHT_INSET
#define DEFAULT_ICON_SIZE ((NSSize) { 64.0, 64.0 })
#define DEFAULT_PADDING   ((NSSize) { 10.0, 8.0 })
#define DEFAULT_MARGIN    ((NSSize) { 4.0, 8.0 })
#define PADDING_STRETCH   ((CGFloat) 4.0)
#define TEXT_OFFSET       ((CGFloat) 4.0)
#define HIGHLIGHT_INSET   ((CGFloat) -4.0)

// the minimum scale used when auto-scaling in column or row mode
#define MIN_AUTO_ICON_SCALE ((CGFloat) 0.125)

// check the icon cache every five minutes and get rid of stale icons
#define ZOMBIE_TIMER_INTERVAL 60.0

// time interval for indeterminate download progress indicator updates
#define PROGRESS_TIMER_INTERVAL 0.1

@interface _FVURLInfo : NSObject
{
@public;
    NSString   *_name;
    NSUInteger  _label;
}
- (id)initWithURL:(NSURL *)aURL;
- (NSString *)name;
- (NSUInteger)label;
@end

#pragma mark -

@interface _FVControllerFileKey : FVObject
{
@public;
    char            *_filePath;
    NSUInteger       _hash;
    struct timespec  _mtimespec;
}
+ (id)newWithURL:(NSURL *)aURL;
- (id)initWithURL:(NSURL *)aURL;
@end

#pragma mark -

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5

@protocol FVAnimationDelegate <NSAnimationDelegate>
@optional
- (void)animation:(NSAnimation *)animation didReachProgress:(NSAnimationProgress)progress;
@end

#import <Quartz/Quartz.h>

@interface FVFileView (FVSnowLeopard) <FVAnimationDelegate, QLPreviewPanelDataSource, QLPreviewPanelDelegate>
@end

#endif

@interface FVAnimation : NSAnimation
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
- (id <FVAnimationDelegate>)delegate;
- (void)setDelegate:(id <FVAnimationDelegate>)newDelegate;
#endif
@end

#if !defined(MAC_OS_X_VERSION_10_7) || MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_7

enum {
   NSScrollerStyleLegacy,
   NSScrollerStyleOverlay
};
typedef NSInteger NSScrollerStyle;

@interface NSScroller (SKLionDeclarations)
- (NSScrollerStyle)scrollerStyle;
@end

#endif

#pragma mark -

@interface FVFileView (Private)
// wrapper that calls bound array or datasource transparently; for internal use
// clients should access the datasource or bound array directly
- (NSURL *)URLAtIndex:(NSUInteger)anIndex;
- (NSUInteger)numberOfIcons;

// only declare methods here to shut the compiler up if we can't rearrange
- (FVIcon *)iconAtIndex:(NSUInteger)anIndex;
- (FVIcon *)_cachedIconForURL:(NSURL *)aURL;
- (void)_getDisplayName:(NSString **)name andLabel:(NSUInteger *)label forURL:(NSURL *)aURL;
- (NSSize)_paddingForScale:(CGFloat)scale;
- (void)_recalculateGridSize;
- (void)_reloadIcons;
- (void)_resetViewLayout;
- (void)_resetTrackingRectsAndToolTips;
- (void)_getRangeOfRows:(NSRange *)rowRange columns:(NSRange *)columnRange inRect:(NSRect)aRect;
- (void)_showArrowsForIconAtIndex:(NSUInteger)anIndex;
- (void)_hideArrows;
- (BOOL)_hasArrows;
- (void)_cancelDownloads;
- (void)_downloadURLAtIndex:(NSUInteger)anIndex;
- (void)_invalidateProgressTimer;
- (void)_handleFinderLabelChanged:(NSNotification *)note;
- (void)_updateBinding:(NSString *)binding;
- (void)_setSelectionIndexes:(NSIndexSet *)indexSet;
- (void)_previewURLs:(NSArray *)iconURLs;
- (void)_previewURL:(NSURL *)aURL forIconInRect:(NSRect)iconRect;
- (void)_stopPreviewing;
- (void)_updatePreviewer;
- (void)handlePreviewerWillClose:(NSNotification *)aNote;

@end

#pragma mark -

@implementation FVFileView

+ (void)initialize 
{
    FVINITIALIZE(FVFileView);
    
    // binding an NSSlider in IB 3 results in a crash on 10.4
    [self exposeBinding:ICONSCALE_BINDING_NAME];
    [self exposeBinding:MINICONSCALE_BINDING_NAME];
    [self exposeBinding:MAXICONSCALE_BINDING_NAME];
    [self exposeBinding:DISPLAYMODE_BINDING_NAME];
    [self exposeBinding:EDITABLE_BINDING_NAME];
    [self exposeBinding:ALLOWSDOWNLOADING_BINDING_NAME];
    [self exposeBinding:CONTENT_BINDING_NAME];
    [self exposeBinding:SELECTIONINDEXES_BINDING_NAME];
    [self exposeBinding:BACKGROUNDCOLOR_BINDING_NAME];
    [self exposeBinding:TEXTCOLOR_BINDING_NAME];
    [self exposeBinding:SUBTITLECOLOR_BINDING_NAME];
    [self exposeBinding:FONT_BINDING_NAME];
    [self exposeBinding:SUBTITLEFONT_BINDING_NAME];
    
    // even without loading the framework on 10.5, this returns a class
    QLPreviewPanelClass = Nil;
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_5) 
        QLPreviewPanelClass = NSClassFromString(@"QLPreviewPanel");
#endif
    
    // Hidden pref; 10.7 and later http://mjtsai.com/blog/2012/03/12/qlenabletextselection/
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"QLEnableTextSelection"];
}

+ (NSColor *)defaultBackgroundColor
{
    NSColor *color = nil;
    
    // Magic source list color: http://lists.apple.com/archives/cocoa-dev/2008/Jun/msg02138.html
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
        // !!! return nil for 10.7 and later to deal with gradient colors
    } else if ([NSOutlineView instancesRespondToSelector:@selector(setSelectionHighlightStyle:)]) {
        NSOutlineView *outlineView = [[NSOutlineView alloc] initWithFrame:NSMakeRect(0,0,1,1)];
        [outlineView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
        color = [[[outlineView backgroundColor] retain] autorelease];
        [outlineView release];
    }
    else {
        // from Mail.app on 10.4
        CGFloat red = (231.0f/255.0f), green = (237.0f/255.0f), blue = (246.0f/255.0f);
        color = [[NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    }
    return color;
}

+ (BOOL)accessInstanceVariablesDirectly { return NO; }

- (void)_commonInit {
     // Icons keyed by URL; may contain icons that are no longer displayed.  Keeping this as primary storage means that
     // rearranging/reloading is relatively cheap, since we don't recreate all FVIcon instances every time -reload is called.
    _iconCache = [[NSMutableDictionary alloc] init];
    // Icons keyed by URL that aren't in the current datasource; this is purged and repopulated every ZOMBIE_TIMER_INTERVAL
    _zombieIconCache = [[NSMutableDictionary alloc] init];
    _iconSize = DEFAULT_ICON_SIZE;
    _fvFlags.displayMode = FVDisplayModeGrid;
    _padding = [self _paddingForScale:1.0];
    _lastMouseDownLocInView = NSZeroPoint;
    // the next two are set to an illegal combination to indicate that no drop is in progress
    _dropIndex = NSNotFound;
    _fvFlags.dropOperation = FVDropBefore;
    _fvFlags.isRescaling = NO;
    _fvFlags.scheduledLiveResize = NO;
    _fvFlags.controllingSharedPreviewer = NO;
    _fvFlags.controllingQLPreviewPanel = NO;
    _selectionIndexes = [[NSIndexSet alloc] init];
    _lastClickedIndex = NSNotFound;
    _rubberBandRect = NSZeroRect;
    _fvFlags.isMouseDown = NO;
    _iconURLs = nil;
    _fvFlags.isEditable = NO;
    [self setBackgroundColor:[[self class] defaultBackgroundColor]];
    _selectionOverlay = NULL;
    _numberOfColumns = 1;
    _numberOfRows = 1;
    
    /*
     Arrays associate FVIcon <--> NSURL in view order.  This is primarily because NSURL is a slow and expensive key 
     for NSDictionary since it copies strings to compute -hash instead of storing it inline; as a consequence, 
     calling [_iconCache objectForKey:[_datasource URLAtIndex:]] is a memory and CPU hog.  We use parallel arrays 
     instead of one array filled with NSDictionaries because there will only be two, and this is less memory and fewer calls.
     */
    _orderedIcons = [[NSMutableArray alloc] init];
   
    // created lazily in case it's needed (only if using a datasource)
    _orderedURLs = nil;
    
    // only created when datasource is set
    _orderedSubtitles = nil;
    
    CFAllocatorRef alloc = CFAllocatorGetDefault();
    
    /*
     This avoids doing file operations on every URL while drawing, just to get the name and label.  
     This table is purged by -reload, so we can use pointer keys and avoid hashing CFURL instances 
     (and avoid copying keys...be sure to use CF to add values!).
     */
    const CFDictionaryKeyCallBacks pointerKeyCallBacks = { 0, kCFTypeDictionaryKeyCallBacks.retain, kCFTypeDictionaryKeyCallBacks.release,
                                                            kCFTypeDictionaryKeyCallBacks.copyDescription, NULL, NULL };
    _infoTable = CFDictionaryCreateMutable(alloc, 0, &pointerKeyCallBacks, &kCFTypeDictionaryValueCallBacks);        
    
    // I'm not removing the timer in viewWillMoveToSuperview:nil because we may need to free up that memory, and the frequency is so low that it's insignificant overhead
    CFAbsoluteTime fireTime = CFAbsoluteTimeGetCurrent() + ZOMBIE_TIMER_INTERVAL;
    // runloop will retain this timer, but we'll retain it too and release in -dealloc
    _zombieTimer = FVCreateWeakTimerWithTimeInterval(ZOMBIE_TIMER_INTERVAL, fireTime, self, @selector(_zombieTimerFired:));
    CFRunLoopAddTimer(CFRunLoopGetCurrent(), _zombieTimer, kCFRunLoopDefaultMode);
    
    _lastOrigin = NSZeroPoint;
    _timeOfLastOrigin = CFAbsoluteTimeGetCurrent();
    _trackingRectMap = CFDictionaryCreateMutable(alloc, 0, &FVIntegerKeyDictionaryCallBacks, &FVIntegerValueDictionaryCallBacks);
    
    _titleCell = [[NSTextFieldCell alloc] initTextCell:@""];
    [_titleCell setFont:[NSFont systemFontOfSize:12.0]];
    [_titleCell setTextColor:[NSColor darkGrayColor]];
    [_titleCell setLineBreakMode:NSLineBreakByTruncatingTail];
    [_titleCell setAlignment:NSCenterTextAlignment];
    
    _subtitleCell = [[NSTextFieldCell alloc] initTextCell:@""];
    [_subtitleCell setFont:[NSFont systemFontOfSize:10.0]];
    [_subtitleCell setTextColor:[NSColor grayColor]];
    [_subtitleCell setLineBreakMode:NSLineBreakByTruncatingTail];
    [_subtitleCell setAlignment:NSCenterTextAlignment];
    
    _leftArrow = [[FVArrowButtonCell alloc] initWithArrowDirection:FVArrowLeft];
    [_leftArrow setTarget:self];
    [_leftArrow setAction:@selector(leftArrowAction:)];
    
    _rightArrow = [[FVArrowButtonCell alloc] initWithArrowDirection:FVArrowRight];
    [_rightArrow setTarget:self];
    [_rightArrow setAction:@selector(rightArrowAction:)];
    
    _leftArrowFrame = NSZeroRect;
    _rightArrowFrame = NSZeroRect;
    _arrowAlpha = 0.0;
    _arrowAnimation = nil;
    _fvFlags.hasArrows = NO;
    
    _minScale = 0.5;
    _maxScale = 16.0;
    
    // this is created lazily when needed
    _sliderWindow = nil;
    // always initialize this to -1
    _topSliderTag = -1;
    _bottomSliderTag = -1;

    // array of FVDownload instances
    _downloads = nil;
    
    // timer to update the view when a download's length is indeterminate
    _progressTimer = NULL;
    
    // set of _FVFileKey instances
    _modificationSet = [NSMutableSet new];
    _modificationLock = [NSLock new];
    
    _operationQueue = [FVOperationQueue new];
    
    _contentBinding = nil;
    
    _fvFlags.updatingFromSlider = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleFinderLabelChanged:) name:FVFinderLabelDidChangeNotification object:nil];
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
    [_titleCell release];
    [_subtitleCell release];
    [_arrowAnimation stopAnimation];
    [_leftArrow release];
    [_rightArrow release];
    [_iconURLs release];
    CFRunLoopTimerInvalidate(_zombieTimer);
    CFRelease(_zombieTimer);
    [_iconCache release];
    [_zombieIconCache release];
    [_orderedIcons release];
    [_orderedURLs release];
    [_orderedSubtitles release];
    CFRelease(_infoTable);
    [_selectionIndexes release];
    [_backgroundColor release];
    [_sliderWindow release];
    // this variable is accessed in super's dealloc, so set it to NULL
    CFRelease(_trackingRectMap);
    _trackingRectMap = NULL;
    // takes care of the timer as well
    [self _cancelDownloads];
    [_downloads release];
    [_modificationSet release];
    [_modificationLock release];
    [_operationQueue terminate];
    [_operationQueue release];
    CGLayerRelease(_selectionOverlay);
    [super dealloc];
}

- (BOOL)isOpaque { return YES; }
- (BOOL)isFlipped { return YES; }

#pragma mark API

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

- (void)setTextColor:(NSColor *)aColor;
{
    [_titleCell setTextColor:aColor];
}

- (NSColor *)textColor
{
    return [_titleCell textColor];
}

- (void)setSubtitleColor:(NSColor *)aColor;
{
    [_subtitleCell setTextColor:aColor];
}

- (NSColor *)subtitleColor
{
    return [_subtitleCell textColor];
}

- (void)setFont:(NSFont *)aFont
{
    [_titleCell setFont:aFont];
}

- (NSFont *)font
{
    return [_titleCell font];
}

- (void)setSubtitleFont:(NSFont *)aFont
{
    [_subtitleCell setFont:aFont];
}

- (NSFont *)subtitleFont
{
    return [_subtitleCell font];
}

// scrollPositionAsPercentage borrowed and modified from the Omni frameworks
- (NSPoint)scrollPercentage;
{
    NSRect bounds = [self bounds];
    NSScrollView *enclosingScrollView = [self enclosingScrollView];
    
    // avoid returning a struct from a nil message
    if (nil == enclosingScrollView)
        return NSZeroPoint;
    
    NSRect documentVisibleRect = [enclosingScrollView documentVisibleRect];
    
    NSPoint scrollPosition;
    
    // Vertical position
    if (NSHeight(documentVisibleRect) >= NSHeight(bounds)) {
        scrollPosition.y = 0.0; // We're completely visible
    } else {
        scrollPosition.y = (NSMinY(documentVisibleRect) - NSMinY(bounds)) / (NSHeight(bounds) - NSHeight(documentVisibleRect));
        scrollPosition.y = fmax(scrollPosition.y, 0.0);
        scrollPosition.y = fmin(scrollPosition.y, 1.0);
    }
    
    // Horizontal position
    if (NSWidth(documentVisibleRect) >= NSWidth(bounds)) {
        scrollPosition.x = 0.0; // We're completely visible
    } else {
        scrollPosition.x = (NSMinX(documentVisibleRect) - NSMinX(bounds)) / (NSWidth(bounds) - NSWidth(documentVisibleRect));
        scrollPosition.x = fmax(scrollPosition.x, 0.0);
        scrollPosition.x = fmin(scrollPosition.x, 1.0);
    }
    
    return scrollPosition;
}

- (void)setScrollPercentage:(NSPoint)scrollPosition;
{
    NSRect bounds = [self bounds];
    NSScrollView *enclosingScrollView = [self enclosingScrollView];
    
    // do nothing if we don't have a scrollview
    if (nil == enclosingScrollView)
        return;
    
    NSRect desiredRect = [enclosingScrollView documentVisibleRect];
    
    // Vertical position
    if (NSHeight(desiredRect) < NSHeight(bounds)) {
        scrollPosition.y = fmax(scrollPosition.y, 0.0);
        scrollPosition.y = fmin(scrollPosition.y, 1.0);
        desiredRect.origin.y = round(NSMinY(bounds) + scrollPosition.y * (NSHeight(bounds) - NSHeight(desiredRect)));
        if (NSMinY(desiredRect) < NSMinY(bounds))
            desiredRect.origin.y = NSMinY(bounds);
        else if (NSMaxY(desiredRect) > NSMaxY(bounds))
            desiredRect.origin.y = NSMaxY(bounds) - NSHeight(desiredRect);
    }
    
    // Horizontal position
    if (NSWidth(desiredRect) < NSWidth(bounds)) {
        scrollPosition.x = fmax(scrollPosition.x, 0.0);
        scrollPosition.x = fmin(scrollPosition.x, 1.0);
        desiredRect.origin.x = round(NSMinX(bounds) + scrollPosition.x * (NSWidth(bounds) - NSWidth(desiredRect)));
        if (NSMinX(desiredRect) < NSMinX(bounds))
            desiredRect.origin.x = NSMinX(bounds);
        else if (NSMaxX(desiredRect) > NSMaxX(bounds))
            desiredRect.origin.x = NSMaxX(bounds) - NSHeight(desiredRect);
    }
    
    [self scrollPoint:desiredRect.origin];
}

- (void)_setIconScale:(double)scale;
{
    if (_fvFlags.displayMode == FVDisplayModeGrid) {
        [self setIconScale:scale];
        [self _updateBinding:ICONSCALE_BINDING_NAME];
    }
}

- (void)setIconScale:(double)scale;
{
    if (_fvFlags.displayMode == FVDisplayModeGrid) {
        FVAPIAssert(scale > 0, @"scale must be greater than zero");
        _iconSize.width = DEFAULT_ICON_SIZE.width * scale;
        _iconSize.height = DEFAULT_ICON_SIZE.height * scale;
        
        // arrows out of place now, they will be added again when required when resetting the tracking rects
        [self _hideArrows];
        
        CGLayerRelease(_selectionOverlay);
        _selectionOverlay = NULL;
        
        NSPoint scrollPoint = [self scrollPercentage];
        
        // the full view will likely need repainting, this also recalculates the grid
        [self _resetViewLayout];
        
        [self setScrollPercentage:scrollPoint];
        
        // Schedule a reload so we always have the correct quality icons, but don't do it while scaling in response to a slider.
        // This will also scroll to the first selected icon; maintaining scroll position while scaling is too jerky.
        if (NO == _fvFlags.isRescaling) {
            _fvFlags.isRescaling = YES;
            // this is only sent in the default runloop mode, so it's not sent during event tracking
            [self performSelector:@selector(_rescaleComplete) withObject:nil afterDelay:0.0];
        }
        
        if (_fvFlags.updatingFromSlider == NO)
            [[_sliderWindow slider] setDoubleValue:log([self iconScale])];
    }
}

- (double)iconScale;
{
    return _iconSize.width / DEFAULT_ICON_SIZE.width;
}

- (double)maxIconScale { return _maxScale; }

- (void)setMaxIconScale:(double)scale { 
    _maxScale = scale; 
    [[_sliderWindow slider] setMaxValue:log(scale)];
    if ([self iconScale] > scale && scale > 0)
        [self setIconScale:scale];
}

- (double)minIconScale { return _minScale; }

- (void)setMinIconScale:(double)scale { 
    _minScale = scale; 
    [[_sliderWindow slider] setMinValue:log(scale)];
    if ([self iconScale] < scale && scale > 0)
        [self setIconScale:scale];
}

- (CGFloat)_autoScaleIconScale;
{
    return _iconSize.width / DEFAULT_ICON_SIZE.width;
}

- (void)_registerForDraggedTypes
{
    if (_fvFlags.isEditable && _dataSource) {
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
        [self unregisterDraggedTypes];
    }
}

- (void)_setDisplayMode:(FVDisplayMode)mode {
    if (_fvFlags.displayMode != mode) {
        [self setDisplayMode:mode];
        [self _updateBinding:DISPLAYMODE_BINDING_NAME];
    }
}

- (void)setDisplayMode:(FVDisplayMode)mode {
    if (_fvFlags.displayMode != mode) {
        _fvFlags.displayMode = mode;
        
        // arrows out of place now, they will be added again when required when resetting the tracking rects
        [self _hideArrows];
        
        if (_sliderWindow) {
            if (_fvFlags.displayMode == FVDisplayModeGrid) {
                [[_sliderWindow slider] setDoubleValue:log([self iconScale])];
            } else {
                [_sliderWindow orderOut:nil];
                [_sliderWindow release];
                _sliderWindow = nil;
            }
        }
        
        NSPoint scrollPoint = [self scrollPercentage];
        
        // the full view will likely need repainting, this also recalculates the grid
        [self reloadIcons];
        
        [self setScrollPercentage:scrollPoint];
        
        [self _resetTrackingRectsAndToolTips];
    }
}

- (FVDisplayMode)displayMode {
    return _fvFlags.displayMode;
}

- (void)setDataSource:(id<FVFileViewDataSource>)obj;
{
    // I was asserting these conditions, but that crashes the IB simulator if you set a datasource in IB.  Setting datasource to nil in case of failure avoids other exceptions later (notably in FVViewController).
    BOOL failed = NO;
    if (obj && [obj respondsToSelector:@selector(numberOfURLsInFileView:)] == NO) {
        FVLog(@"*** ERROR *** datasource %@ must implement %@", obj, NSStringFromSelector(@selector(numberOfURLsInFileView:)));
        failed = YES;
    }
    if (obj && [obj respondsToSelector:@selector(fileView:URLAtIndex:)] == NO) {
        FVLog(@"*** ERROR *** datasource %@ must implement %@", obj, NSStringFromSelector(@selector(fileView:URLAtIndex:)));
        failed = YES;
    }
    if (failed) obj = nil;
    
    _dataSource = obj;
    
    [_operationQueue cancel];
    
    [self _cancelDownloads];

    [_orderedSubtitles release];
    _orderedSubtitles = [obj respondsToSelector:@selector(fileView:subtitleAtIndex:)] ? [[NSMutableArray alloc] init] : nil;
    
    // convenient time to do this, although the timer would also handle it
    [_iconCache removeAllObjects];
    [_zombieIconCache removeAllObjects];
    
    // not critical; just avoid blocking here...
    if ([_modificationLock tryLock]) {
        [_modificationSet removeAllObjects];
        [_modificationLock unlock];
    }
    
    // datasource may implement subtitles, which affects our drawing layout (padding height)
    [self reloadIcons];
}

- (id<FVFileViewDataSource>)dataSource { return _dataSource; }

- (BOOL)isEditable 
{ 
    return _fvFlags.isEditable;
}

- (void)setEditable:(BOOL)flag 
{
    if (_fvFlags.isEditable != flag) {
        _fvFlags.isEditable = flag;
        
        [self _registerForDraggedTypes];
    }
}

- (BOOL)allowsDownloading 
{
    return _downloads != NULL;
}

- (void)setAllowsDownloading:(BOOL)flag
{
    if (flag && _downloads == nil) {
        _downloads = [[NSMutableArray alloc] init];
    } else if (flag == NO && _downloads != nil) {
        [self _cancelDownloads];
        [_downloads release];
        _downloads = nil;
    }
}

- (void)setDelegate:(id<FVFileViewDelegate>)obj;
{
    _delegate = obj;
}

- (id<FVFileViewDelegate>)delegate { return _delegate; }

- (void)_setSelectionIndexes:(NSIndexSet *)indexSet {
    [self setSelectionIndexes:indexSet];
    [self _updateBinding:SELECTIONINDEXES_BINDING_NAME];
}

- (void)setSelectionIndexes:(NSIndexSet *)indexSet;
{
    FVAPIAssert(nil != indexSet, @"index set must not be nil");
    if (indexSet != _selectionIndexes) {
        [_selectionIndexes release];
        _selectionIndexes = [[NSIndexSet alloc] initWithIndexSet:indexSet];
        
        [self setNeedsDisplay:YES];
        
        NSAccessibilityPostNotification(NSAccessibilityUnignoredAncestor(self), NSAccessibilityFocusedUIElementChangedNotification);
        
        if (_fvFlags.controllingSharedPreviewer || _fvFlags.controllingQLPreviewPanel)
            [self _updatePreviewer];
    }
}

- (NSIndexSet *)selectionIndexes;
{
    return _selectionIndexes;
}

- (void)setIconURLs:(NSArray *)array
{
    if (_orderedURLs != array) {
        [_orderedURLs release];
        _orderedURLs = [[NSMutableArray alloc] initWithArray:array];
    }    
}

- (NSArray *)iconURLs
{
    return _orderedURLs;
}

#pragma mark Binding/datasource wrappers

- (FVIcon *)iconAtIndex:(NSUInteger)anIndex { 
    FVAPIAssert(anIndex < [_orderedIcons count], @"invalid icon index requested; likely missing a call to -reloadIcons");
    return [_orderedIcons objectAtIndex:anIndex]; 
}

- (NSString *)subtitleAtIndex:(NSUInteger)anIndex { 
    // _orderedSubtitles is nil if the datasource doesn't implement the optional method
    if (_orderedSubtitles) FVAPIAssert(anIndex < [_orderedSubtitles count], @"invalid subtitle index requested; likely missing a call to -reloadIcons");
    return [_orderedSubtitles objectAtIndex:anIndex]; 
}

- (NSArray *)iconsAtIndexes:(NSIndexSet *)indexes { 
    FVAPIAssert([indexes lastIndex] < [self numberOfIcons], @"invalid number of icons requested; likely missing a call to -reloadIcons");
    return [_orderedIcons objectsAtIndexes:indexes]; 
}

/*
 Wrap datasource/bindings and return [FVIcon missingFileURL] when the datasource or bound array 
 returns nil or NSNull, or else we end up with exceptions everywhere.
 */

- (NSURL *)URLAtIndex:(NSUInteger)anIndex {
    NSParameterAssert(anIndex < [self numberOfIcons]);
    NSURL *aURL = [_orderedURLs objectAtIndex:anIndex];
    if (__builtin_expect(nil == aURL || [NSNull null] == (id)aURL, 0))
        aURL = [FVIcon missingFileURL];
    return aURL;
}

- (NSUInteger)numberOfIcons { return [_orderedURLs count]; }

- (void)_getDisplayName:(NSString **)name andLabel:(NSUInteger *)label forURL:(NSURL *)aURL;
{
    _FVURLInfo *info = [(id)_infoTable objectForKey:aURL];
    if (nil == info) {
        info = [[_FVURLInfo allocWithZone:[self zone]] initWithURL:aURL];
        CFDictionarySetValue(_infoTable, (CFURLRef)aURL, info);
        [info release];
    }
    if (name) *name = [info name];
    if (label) *label = [info label];
}

- (FVIcon *)_cachedIconForURL:(NSURL *)aURL;
{
    NSParameterAssert([aURL isKindOfClass:[NSURL class]]);
    FVIcon *icon = [_iconCache objectForKey:aURL];
    
    // try zombie cache first
    if (nil == icon) {
        icon = [_zombieIconCache objectForKey:aURL];
        if (icon) {
            [_iconCache setObject:icon forKey:aURL];
            [_zombieIconCache removeObjectForKey:aURL];
        }
    }
    
    // still no icon, so make a new one and cache it
    if (nil == icon) {
        icon = [[FVIcon allocWithZone:NULL] initWithURL:aURL];
        [_iconCache setObject:icon forKey:aURL];
        [icon release];
    }
    return icon;
}

- (NSArray *)_selectedURLs
{
    NSMutableArray *array = [NSMutableArray array];
    NSUInteger idx = [_selectionIndexes firstIndex];
    while (NSNotFound != idx) {
        [array addObject:[self URLAtIndex:idx]];
        idx = [_selectionIndexes indexGreaterThanIndex:idx];
    }
    return array;
}

#pragma mark Binding support

- (void)bind:(NSString *)binding toObject:(id)observable withKeyPath:(NSString *)keyPath options:(NSDictionary *)options;
{
    if ([binding isEqualToString:CONTENT_BINDING_NAME]) {
     
        FVAPIAssert3(nil == _contentBinding, @"attempt to bind %@ to %@ when bound to %@", keyPath, observable, [_contentBinding objectForKey:NSObservedObjectKey]);
        
        // keep a record of the observervable object for unbinding; this is strictly for observation, not a manual binding
        _contentBinding = [[NSDictionary alloc] initWithObjectsAndKeys:observable, NSObservedObjectKey, [[keyPath copy] autorelease], NSObservedKeyPathKey, [[options copy] autorelease], NSOptionsKey, nil];
        [observable addObserver:self forKeyPath:keyPath options:0 context:&_FVFileViewContentObservationContext];
        [self observeValueForKeyPath:keyPath ofObject:observable change:nil context:&_FVFileViewContentObservationContext];
    }
    else {
        // ??? the IB inspector doesn't show values properly unless I call super for that case as well
        [super bind:binding toObject:observable withKeyPath:keyPath options:options];
    }
}

- (void)unbind:(NSString *)binding
{
    if ([binding isEqualToString:CONTENT_BINDING_NAME]) {
        FVAPIAssert2(nil != _contentBinding, @"%@: attempt to unbind %@ when unbound", self, binding);
        
        [[_contentBinding objectForKey:NSObservedObjectKey] removeObserver:self forKeyPath:[_contentBinding objectForKey:NSObservedKeyPathKey]];
        [_contentBinding release];
        _contentBinding = nil;
        
        [self setIconURLs:nil];
        [self reloadIcons];
        [self setSelectionIndexes:[NSIndexSet indexSet]];
    }
    else {
        [super unbind:binding];
    }
    [self reloadIcons];
}

- (NSDictionary *)infoForBinding:(NSString *)binding;
{
    return [binding isEqualToString:CONTENT_BINDING_NAME] ? _contentBinding : [super infoForBinding:binding];
}

- (Class)valueClassForBinding:(NSString *)binding
{
    if ([binding isEqualToString:CONTENT_BINDING_NAME])
        return [NSArray class];
    else if ([binding isEqualToString:SELECTIONINDEXES_BINDING_NAME])
        return [NSIndexSet class];
    else if ([binding isEqualToString:ICONSCALE_BINDING_NAME] || [binding isEqualToString:MINICONSCALE_BINDING_NAME] || [binding isEqualToString:MAXICONSCALE_BINDING_NAME] || [binding isEqualToString:DISPLAYMODE_BINDING_NAME] || [binding isEqualToString:EDITABLE_BINDING_NAME] || [binding isEqualToString:ALLOWSDOWNLOADING_BINDING_NAME])
        return [NSNumber class];
    else if ([binding isEqualToString:BACKGROUNDCOLOR_BINDING_NAME] || [binding isEqualToString:TEXTCOLOR_BINDING_NAME] || [binding isEqualToString:SUBTITLECOLOR_BINDING_NAME])
        return [NSColor class];
    else if ([binding isEqualToString:FONT_BINDING_NAME] || [binding isEqualToString:SUBTITLEFONT_BINDING_NAME])
        return [NSFont class];
    else
        return [super valueClassForBinding:binding];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{    
    if (context == &_FVFileViewContentObservationContext) {
        NSParameterAssert([keyPath isEqualToString:[_contentBinding objectForKey:NSObservedKeyPathKey]]);
        NSParameterAssert(object == [_contentBinding objectForKey:NSObservedObjectKey]);
        
        id observedArray = [[_contentBinding objectForKey:NSObservedObjectKey] valueForKeyPath:[_contentBinding objectForKey:NSObservedKeyPathKey]];
        if (NSIsControllerMarker(observedArray) == NO) {
            NSDictionary *options = [_contentBinding objectForKey:NSOptionsKey];
            NSValueTransformer *transformer = [options objectForKey:NSValueTransformerBindingOption];
            if (transformer == nil) {
                NSString *transformerName = [options objectForKey:NSValueTransformerNameBindingOption];
                if (transformerName)
                    transformer = [NSValueTransformer valueTransformerForName:transformerName];
            }
            if (transformer)
                observedArray = [transformer transformedValue:observedArray];
            
            [self setIconURLs:observedArray];
            [self reloadIcons];
        }
    }
    else {
        // not our context, so use super's implementation; documentation is totally wrong on this
        // http://lists.apple.com/archives/cocoa-dev/2008/Oct/msg01096.html
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)_updateBinding:(NSString *)binding {
    NSDictionary *info = [self infoForBinding:binding];
    if (info) {
        id value = [self valueForKey:binding];
        id observable = [info objectForKey:NSObservedObjectKey];
        NSString *keyPath = [info objectForKey:NSObservedKeyPathKey];
        NSDictionary *options = [info objectForKey:NSOptionsKey];
        NSValueTransformer *transformer = [options objectForKey:NSValueTransformerBindingOption];
        if (transformer == nil || [transformer isEqual:[NSNull null]]) {
            NSString *transformerName = [options objectForKey:NSValueTransformerNameBindingOption];
            if (transformerName && [transformer isEqual:[NSNull null]] == NO)
                transformer = [NSValueTransformer valueTransformerForName:transformerName];
        }
        if (transformer && [transformer isEqual:[NSNull null]] == NO)
            value = [transformer reverseTransformedValue:value];
        
        [observable setValue:value forKeyPath:keyPath];
    }
}

#pragma mark View and Window notifications

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
        NSEnumerator *bindingEnum = [[self exposedBindings] objectEnumerator];
        NSString *binding;
        while (binding = [bindingEnum nextObject]) {
            if (nil != [self infoForBinding:binding])
                [self unbind:binding];
        }
        
        if ([[_sliderWindow parentWindow] isEqual:[self window]]) {
            [_sliderWindow orderOut:nil];
        }
        
        [_operationQueue cancel];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:FVPreviewerWillCloseNotification object:nil];
    }
    else {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePreviewerWillClose:)
                                                     name:FVPreviewerWillCloseNotification
                                                   object:nil];
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

- (void)_handleKeyOrMainStateNotification:(NSNotification *)note {
    NSView *view = (id)[self enclosingScrollView] ?: (id)self;
    [view setNeedsDisplay:YES];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    NSWindow *window = [self window];
    if (newWindow == nil && [[_sliderWindow parentWindow] isEqual:window]) {
        [_sliderWindow orderOut:nil];
    }
    if (window) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self name:NSWindowDidBecomeMainNotification object:window];
        [nc removeObserver:self name:NSWindowDidResignMainNotification object:window];
        [nc removeObserver:self name:NSWindowDidBecomeKeyNotification object:window];
        [nc removeObserver:self name:NSWindowDidResignKeyNotification object:window];
    }
    [super viewWillMoveToWindow:newWindow];
}

- (void)viewDidMoveToWindow {
    // for redrawing background color
    NSWindow *window = [self window];
    if (window) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(_handleKeyOrMainStateNotification:) name:NSWindowDidBecomeMainNotification object:window];
        [nc addObserver:self selector:@selector(_handleKeyOrMainStateNotification:) name:NSWindowDidResignMainNotification object:window];
        [nc addObserver:self selector:@selector(_handleKeyOrMainStateNotification:) name:NSWindowDidBecomeKeyNotification object:window];
        [nc addObserver:self selector:@selector(_handleKeyOrMainStateNotification:) name:NSWindowDidResignKeyNotification object:window];
    }
    [super viewDidMoveToWindow];
}

#pragma mark Layout

- (CGFloat)_columnWidth { return _iconSize.width + _padding.width; }

- (CGFloat)_rowHeight { return _iconSize.height + _padding.height; }

// overall borders around the view
- (CGFloat)_leftMargin { return _padding.width / 2 + DEFAULT_MARGIN.width; }

- (CGFloat)_rightMargin { return _padding.width / 2 + DEFAULT_MARGIN.width; }

- (CGFloat)_topMargin { return DEFAULT_MARGIN.height; }

- (CGFloat)_bottomMargin { return 0.0; }

- (NSUInteger)numberOfRows { return _numberOfRows; }

- (NSUInteger)numberOfColumns { return _numberOfColumns; }

- (CGFloat)_textHeight;
{
    CGFloat textHeight = [_titleCell cellSize].height;
    if ([_dataSource respondsToSelector:@selector(fileView:subtitleAtIndex:)])
        textHeight += [_subtitleCell cellSize].height;
    return textHeight;
}

- (NSSize)_paddingForScale:(CGFloat)scale;
{
    NSSize size = DEFAULT_PADDING;
    // ??? magic number here... using a fixed padding looked funny at some sizes, so this is now adjustable
    CGFloat extraPadding = round(PADDING_STRETCH * scale);
    size.width += extraPadding;
    size.height += extraPadding + [self _textHeight];
    return size;
}

// This is the square rect the icon is drawn in.  It doesn't include padding, so rects aren't contiguous.
// Caller is responsible for any centering before drawing.
- (NSRect)_rectOfIconInRow:(NSUInteger)row column:(NSUInteger)column;
{
    NSRect rect = [self bounds];
    rect.origin.x += [self _leftMargin] + [self _columnWidth] * column;
    rect.origin.y += [self _topMargin] + [self _rowHeight] * row;
    rect.size = _iconSize;
    return rect;
}

- (NSRect)_rectOfTextForIconRect:(NSRect)iconRect;
{
    // add a couple of points between the icon and text, which is useful if we're drawing a Finder label
    // don't draw all the way into the padding vertically, so we don't draw over the selection highlight of the next icon
    NSRect textRect = NSMakeRect(NSMinX(iconRect), NSMaxY(iconRect) + TEXT_OFFSET, NSWidth(iconRect), [self _textHeight]);
    // allow the text rect to extend outside the grid cell
    return NSInsetRect(textRect, -_padding.width / 3.0, 0.0);
}

- (void)_setNeedsDisplayForIconInRow:(NSUInteger)row column:(NSUInteger)column {
    NSRect dirtyRect = [self _rectOfIconInRow:row column:column];
    // extend the icon rect to account for shadow in case text is narrower than the icon
    // extend downward to account for the text area
    dirtyRect = NSUnionRect(NSInsetRect(dirtyRect, -ceil(2.0 * [self iconScale]), -ceil([self iconScale])), [self _rectOfTextForIconRect:dirtyRect]);
    [self setNeedsDisplayInRect:dirtyRect];
}

#pragma mark Drawing layout

- (CGFloat)_frameWidth {
    return ceil( [self _columnWidth] * _numberOfColumns - _padding.width + [self _leftMargin] + [self _rightMargin] );
}

- (CGFloat)_frameHeight {
    return ceil( [self _rowHeight] * _numberOfRows + [self _topMargin] + [self _bottomMargin] );
}

- (void)_setPaddingAndIconSizeFromContentWidth:(CGFloat)width {
    // guess the iconScale, ignoring the variable padding because that depends on the iconScale
    CGFloat iconScale = fmax( MIN_AUTO_ICON_SCALE, ( ( width - 2 * DEFAULT_MARGIN.width ) / _numberOfColumns - [self _paddingForScale:0.0].width ) / ( DEFAULT_ICON_SIZE.width + PADDING_STRETCH ));
    _padding = [self _paddingForScale:iconScale];
    // recalculate exactly based on this padding, inverting the calculation in _frameWidth
    iconScale = fmax( MIN_AUTO_ICON_SCALE, ( ( width - [self _leftMargin] - [self _rightMargin] + _padding.width ) / _numberOfColumns - _padding.width ) / DEFAULT_ICON_SIZE.width );
    _iconSize = NSMakeSize(iconScale * DEFAULT_ICON_SIZE.width, iconScale * DEFAULT_ICON_SIZE.height);
}

- (void)_setPaddingAndIconSizeFromContentHeight:(CGFloat)height {
    // guess the iconScale, ignoring the variable padding because that depends on the iconScale
    CGFloat iconScale = fmax( MIN_AUTO_ICON_SCALE, ( ( height - DEFAULT_MARGIN.height ) / _numberOfRows - [self _paddingForScale:0.0].height ) / ( DEFAULT_ICON_SIZE.height + PADDING_STRETCH ) );
    _padding = [self _paddingForScale:iconScale];
    // recalculate exactly based on this padding, inverting the calculation in _frameHeight
    iconScale = fmax( MIN_AUTO_ICON_SCALE, ( ( height - [self _topMargin] - [self _bottomMargin] ) / _numberOfRows - _padding.height ) / DEFAULT_ICON_SIZE.height );
    _iconSize = NSMakeSize(iconScale * DEFAULT_ICON_SIZE.width, iconScale * DEFAULT_ICON_SIZE.height);
}


- (void)_setColumnsAndRowsFromContentWidth:(CGFloat)width {
    _numberOfColumns = MAX( 1,  (NSInteger)floor( ( width - [self _leftMargin] - [self _rightMargin] + _padding.width ) / [self _columnWidth] ) );
    _numberOfRows = ( [self numberOfIcons]  + _numberOfColumns - 1 ) / _numberOfColumns;
}

static CGFloat _scrollerWidthForScroller(NSScroller *scroller) {
    if ([scroller respondsToSelector:@selector(scrollerStyle)] && [scroller scrollerStyle] == NSScrollerStyleOverlay)
        return 0.0;
    return [[scroller class] scrollerWidthForControlSize:[scroller controlSize]];
}

- (NSSize)_contentSizeForScrollView:(NSScrollView *)scrollView minWidth:(CGFloat)minWidth hasVerticalScroller:(BOOL)hasVerticalScroller {
    // NSScrollView does not have a method to get the content size for arbitrary controlSize, so we substract the scroller widths ourselves
    NSSize contentSize = [[scrollView class] contentSizeForFrameSize:[scrollView frame].size hasHorizontalScroller:NO hasVerticalScroller:NO borderType:[scrollView borderType]];
    if (hasVerticalScroller)
        contentSize.width -= _scrollerWidthForScroller([scrollView verticalScroller]);
    // if the icons reach the minimum size, we should have a horizontal scroller if it's available
    if ([scrollView hasHorizontalScroller] && contentSize.width < minWidth)
        contentSize.height -= _scrollerWidthForScroller([scrollView horizontalScroller]);
    return contentSize;
}

- (NSSize)_contentSizeForScrollView:(NSScrollView *)scrollView minHeight:(CGFloat)minHeight hasHorizontalScroller:(BOOL)hasHorizontalScroller {
    // NSScrollView does not have a method to get the content size for arbitrary controlSize, so we substract the scroller widths ourselves
    NSSize contentSize = [[scrollView class] contentSizeForFrameSize:[scrollView frame].size hasHorizontalScroller:NO hasVerticalScroller:NO borderType:[scrollView borderType]];
    if (hasHorizontalScroller)
        contentSize.height -= _scrollerWidthForScroller([scrollView horizontalScroller]);
    // if the icons reach the minimum size, we should have a vertical scroller if it's available
    if ([scrollView hasVerticalScroller] && contentSize.height < minHeight)
        contentSize.width -= _scrollerWidthForScroller([scrollView verticalScroller]);
    return contentSize;
}

- (void)_recalculateGridSize
{
    NSScrollView *scrollView = [self enclosingScrollView];
    NSSize contentSize = scrollView ? [scrollView contentSize] : [self bounds].size;
    
    if (_fvFlags.displayMode == FVDisplayModeColumn) {
        
        _numberOfColumns = 1;
        _numberOfRows = [self numberOfIcons];
        
        // if we have an auto-hiding vertical scroller, we may or may not have scroll bars, which affects the effective width
        if ([scrollView autohidesScrollers] && [scrollView hasVerticalScroller]) {
            CGFloat minWidth = ceil( DEFAULT_PADDING.width + MIN_AUTO_ICON_SCALE * DEFAULT_ICON_SIZE.width + 2 * DEFAULT_MARGIN.width );
            
            // first assume we need a vertical scroller...
            contentSize = [self _contentSizeForScrollView:scrollView minWidth:minWidth hasVerticalScroller:YES];
            [self _setPaddingAndIconSizeFromContentWidth:contentSize.width];
            
            if (contentSize.height > [self _frameHeight]) {
                // we have sufficient height to fit all icons, so recalculate without vertical scroller
                contentSize = [self _contentSizeForScrollView:scrollView minWidth:minWidth hasVerticalScroller:NO];
                [self _setPaddingAndIconSizeFromContentWidth:contentSize.width];
                
                if (_numberOfRows > 0 && contentSize.height < [self _frameHeight]) {
                    // the height with this wider icons becomes too much, so we now recalculate by fitting the height, still without vertical scroller
                    // this should come out in between the previous two calculations
                    [self _setPaddingAndIconSizeFromContentHeight:contentSize.height];
                }
            }
            
        } else {
        
            [self _setPaddingAndIconSizeFromContentWidth:contentSize.width];
            
        }
        
        CGLayerRelease(_selectionOverlay);
        _selectionOverlay = NULL;
            
    } else if (_fvFlags.displayMode == FVDisplayModeRow) {
        
        _numberOfColumns = [self numberOfIcons];
        _numberOfRows = 1;
        
        // if we have an auto-hiding horizontal scroller, we may or may not have scroll bars, which affects the effective height
        if ([scrollView autohidesScrollers] && [scrollView hasHorizontalScroller]) {
            CGFloat minHeight = ceil( DEFAULT_PADDING.height + MIN_AUTO_ICON_SCALE * DEFAULT_ICON_SIZE.height + DEFAULT_MARGIN.height );
            
            // first assume we need a horizontal scroller...
            contentSize = [self _contentSizeForScrollView:scrollView minHeight:minHeight hasHorizontalScroller:YES];
            [self _setPaddingAndIconSizeFromContentHeight:contentSize.height];
            
            if (contentSize.width > [self _frameWidth]) {
                // we have sufficient width to fit all icons, so recalculate without horizontal scroller
                contentSize = [self _contentSizeForScrollView:scrollView minHeight:minHeight hasHorizontalScroller:NO];
                [self _setPaddingAndIconSizeFromContentHeight:contentSize.height];
                
                if (_numberOfColumns > 0 && contentSize.width < [self _frameWidth]) {
                    // the width with this wider icons becomes too much, so we now recalculate by fitting the width, still without horizontal scroller
                    // this should come out in between the previous two calculations
                    [self _setPaddingAndIconSizeFromContentWidth:contentSize.width];
                }
            }
            
        } else {
        
            [self _setPaddingAndIconSizeFromContentHeight:contentSize.height];
            
        }
        
        CGLayerRelease(_selectionOverlay);
        _selectionOverlay = NULL;
        
    } else {
        
        _padding = [self _paddingForScale:[self iconScale]];
        
        // if we have an auto-hiding vertical scroller, we may or may not have scroll bars, which affects the effective width
        if ([scrollView autohidesScrollers] && [scrollView hasVerticalScroller]) {
            // set the number of columns to 1 to calculate the minimal required width
            _numberOfColumns = 1;
            CGFloat minWidth = [self _frameWidth];
            
            // first assume we don't need a vertical scroller...
            contentSize = [self _contentSizeForScrollView:scrollView minWidth:minWidth hasVerticalScroller:NO];
            [self _setColumnsAndRowsFromContentWidth:contentSize.width];
            
            if (contentSize.height < [self _frameHeight]) {
                // we have insufficient height to fit all icons, so recalculate with vertical scroller
                contentSize = [self _contentSizeForScrollView:scrollView minWidth:minWidth hasVerticalScroller:YES];
                [self _setColumnsAndRowsFromContentWidth:contentSize.width];
            }
            
        } else {
            
            [self _setColumnsAndRowsFromContentWidth:contentSize.width];
            
        }
    }
    
    if (scrollView) {
        NSRect frame = NSMakeRect(0.0, 0.0, fmax([self _frameWidth], contentSize.width), fmax([self _frameHeight], contentSize.height));
        if (NSEqualRects([self frame], frame) == NO) {
            [super setFrame:frame];
            [scrollView reflectScrolledClipView:[scrollView contentView]];
            contentSize = [scrollView contentSize];
            // make sure the scrollView did not hide a scroller unexpectedly and we get too small
            if (contentSize.width > NSWidth(frame) || contentSize.height > NSHeight(frame)) {
                if (contentSize.width > NSWidth(frame))
                    frame.size.width = contentSize.width;
                if (contentSize.height > NSHeight(frame))
                    frame.size.height = contentSize.height;
                [super setFrame:frame];
            }
        }
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

// This returns NO when the row/column operation is NULL and the point is in between rows/column
- (BOOL)_getGridRow:(NSUInteger *)rowIndex column:(NSUInteger *)colIndex rowOperation:(FVDropOperation *)rowOp columnOperation:(FVDropOperation *)colOp atPoint:(NSPoint)point;
{
    // column width is padding + icon width
    // row height is padding + icon width
    NSInteger idx, nc = [self numberOfColumns], nr = [self numberOfRows];
    CGFloat columnWidth = [self _columnWidth];
    CGFloat rowHeight = [self _rowHeight];
    CGFloat start;
    
    if (nc == 0 || nr == 0)
        return NO;
    
    start = [self _leftMargin];
    
    if (point.x <= start) {
        if (colOp == NULL)
            return NO;
        if (colIndex)
            *colIndex = 0;
        *colOp = FVDropBefore;
    } else {
        
        for (idx = 0; idx < nc; idx++, start += columnWidth) {
            if (point.x < (start + _iconSize.width)) {
                if (colIndex)
                    *colIndex = idx;
                if (colOp)
                    *colOp = FVDropOn;
                break;
            } else if (point.x <= (start + columnWidth)) {
                if (colOp == NULL)
                    return NO;
                if (colIndex)
                    *colIndex = idx;
                *colOp = FVDropAfter;
                break;
            }
        }
        
        if (idx == nc)
            return NO;
    }
    
    start = [self _topMargin];
    
    if (point.y <= start) {
        if (rowOp == NULL)
            return NO;
        if (rowIndex)
            *rowIndex = 0;
        *rowOp = FVDropBefore;
    } else {
        
        for (idx = 0; idx < nr; idx++, start += rowHeight) {
            
            if (point.y < (start + _iconSize.height)) {
                if (rowIndex)
                    *rowIndex = idx;
                if (rowOp)
                    *rowOp = FVDropOn;
                break;
            } else if (point.y <= (start + rowHeight)) {
                if (rowOp == NULL)
                    return NO;
                if (rowIndex)
                    *rowIndex = idx;
                *rowOp = FVDropAfter;
                break;
            }
        }
        
        if (idx == nr)
            return NO;
    }
    
    return YES;
}

// This is only used for hit testing in the icons, so we should ignore padding
- (BOOL)_getGridRow:(NSUInteger *)rowIndex column:(NSUInteger *)colIndex atPoint:(NSPoint)point;
{
    return [self _getGridRow:rowIndex column:colIndex rowOperation:NULL columnOperation:NULL atPoint:point];
}

#pragma mark Slider

- (void)_sliderAction:(id)sender {
    if (_fvFlags.displayMode == FVDisplayModeGrid) {
        _fvFlags.updatingFromSlider = YES;
        [self _setIconScale:exp([sender doubleValue])];
        _fvFlags.updatingFromSlider = NO;
    }
}

- (FVSliderWindow *)_sliderWindow {
    if (_sliderWindow == nil && _fvFlags.displayMode == FVDisplayModeGrid) {
        _sliderWindow = [[FVSliderWindow alloc] init];
        FVSlider *slider = [_sliderWindow slider];
        [slider setMaxValue:log(_maxScale)];
        [slider setMinValue:log(_minScale)];
        [slider setDoubleValue:log([self iconScale])];
        [slider setAction:@selector(_sliderAction:)];
        [slider setTarget:self];
    }
    return _sliderWindow;
}

#define MIN_SLIDER_WIDTH     ((CGFloat) 50.0)
#define MAX_SLIDER_WIDTH     ((CGFloat) 200.0)
#define SLIDER_HEIGHT        ((CGFloat) 15.0)
#define TOP_SLIDER_OFFSET    ((CGFloat) 1.0)
#define BOTTOM_SLIDER_OFFSET ((CGFloat) 19.0)

- (NSRect)_topSliderRect
{
    NSRect r = [self visibleRect];
    CGFloat l = floor( NSMidX(r) - fmax( MIN_SLIDER_WIDTH / 2, fmin( MAX_SLIDER_WIDTH / 2, NSWidth(r) / 5 ) ) );
    r.origin.x += l;
    r.origin.y += TOP_SLIDER_OFFSET;
    r.size.width -= 2 * l;
    r.size.height = SLIDER_HEIGHT;
    return r;
}

- (NSRect)_bottomSliderRect
{
    NSRect r = [self visibleRect];
    CGFloat l = floor( NSMidX(r) - fmax( MIN_SLIDER_WIDTH / 2, fmin( MAX_SLIDER_WIDTH / 2, NSWidth(r) / 5 ) ) );
    r.origin.x += l;
    r.origin.y += NSHeight(r) - BOTTOM_SLIDER_OFFSET;
    r.size.width -= 2 * l;
    r.size.height = SLIDER_HEIGHT;
    return r;
}

#pragma mark Layout and content updating

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
        
        FVIcon *anIcon = mouseIndex == NSNotFound ? nil : [self iconAtIndex:mouseIndex];
        if ([anIcon pageCount] > 1)
            [self _showArrowsForIconAtIndex:mouseIndex];
        else
            [self _hideArrows];
        
        if (_fvFlags.displayMode == FVDisplayModeGrid) {
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

- (void)_resetViewLayout;
{
    // Problem exposed in BibDesk: select all, scroll halfway down in file pane, then change selection to a single row.  FVFileView content didn't update correctly, even though reloadIcons was called.  Logging drawRect: indicated that the wrong region was being updated, but calling _recalculateGridSize here fixed it.
    [self _recalculateGridSize];
    
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

static inline bool __equal_timespecs(const struct timespec *ts1, const struct timespec *ts2)
{
    return ts1->tv_nsec == ts2->tv_nsec && ts1->tv_sec == ts2->tv_sec;
}

- (void)_setViewNeedsDisplay
{
    NSAssert(pthread_main_np() != 0, @"main thread required");
    [self setNeedsDisplay:YES];
}

- (void)_recacheIconsWithInfo:(NSDictionary *)info
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    // if there's ever any contention, don't block
    if ([_modificationLock tryLock]) {

        NSArray *orderedIcons = [info objectForKey:@"orderedIcons"];
        NSArray *orderedURLs = [info objectForKey:@"orderedURLs"];
        NSParameterAssert([orderedIcons count] == [orderedURLs count]);
        
        NSUInteger cnt = [orderedURLs count];
        NSNull *nsnull = [NSNull null];
        bool redisplay = false;
        while (cnt--) {
            id aURL = [orderedURLs objectAtIndex:cnt];
            FVIcon *icon = [orderedIcons objectAtIndex:cnt];
            if (aURL != nsnull && [aURL isFileURL]) {
                _FVControllerFileKey *newKey = [_FVControllerFileKey newWithURL:aURL];
                _FVControllerFileKey *oldKey = [_modificationSet member:newKey];
                /*
                 Check to see if the icon has cached resources calling recache.  This is of marginal
                 benefit, since recache should be cheap in that case, but avoids redisplay.  We can't
                 use it to avoid the stat() call, since otherwise the modification set doesn't get
                 populated with initial values.
                 */
                if (oldKey && __equal_timespecs(&newKey->_mtimespec, &oldKey->_mtimespec) == false && [icon canReleaseResources]) {
                    [[orderedIcons objectAtIndex:cnt] recache];
                    [_modificationSet removeObject:oldKey];
                    redisplay = true;
                }
                [_modificationSet addObject:newKey];
                [newKey release];
            }
        }

        [_modificationLock unlock];
        
        /*
         When the view calls -recache on an icon, it has to reload the controller as well.
         In this case, we know that the URL itself is the same, but the underlying data
         has changed.  Consequently, setNeedsDisplay:YES should be sufficient.
         */
        if (redisplay)
            [self performSelectorOnMainThread:@selector(_setViewNeedsDisplay) withObject:nil waitUntilDone:NO];
        
    }
    else {
#if DEBUG
        // keep an eye out for this; it gets hit with the test program during view setup
        FVLog(@"FileView: called %@ while another call was in progress.", NSStringFromSelector(_cmd));
#endif
    }
    [pool release];
}

- (void)_recacheIconsInBackgroundIfNeeded
{
    if ([_orderedURLs count]) {
        NSArray *orderedIcons = [[NSArray alloc] initWithArray:_orderedIcons copyItems:NO];
        NSArray *orderedURLs = [[NSArray alloc] initWithArray:_orderedURLs copyItems:NO];
        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:orderedIcons, @"orderedIcons", orderedURLs, @"orderedURLs", nil];
        [orderedIcons release];
        [orderedURLs release];
        [NSThread detachNewThreadSelector:@selector(_recacheIconsWithInfo:) toTarget:self withObject:info];
    }
}

- (void)_reloadIcons;
{
    BOOL isBound = nil != _contentBinding;
    
    if (NO == isBound) {
        if (nil == _orderedURLs)
            _orderedURLs = [[NSMutableArray alloc] init];
        else
            [_orderedURLs removeAllObjects];
    }
    
    [_orderedIcons removeAllObjects];
    [_orderedSubtitles removeAllObjects];
    
    CFDictionaryRemoveAllValues(_infoTable);
    
    // datasource URL method
    SEL URLSel = @selector(fileView:URLAtIndex:);
    id (*URLAtIndex)(id, SEL, id, NSUInteger);
    URLAtIndex = (id (*)(id, SEL, id, NSUInteger))[(id)_dataSource methodForSelector:URLSel];
    
    // -[NSCFArray objectAtIndex:] (do /not/ use +[NSMutableArray instanceMethodForSelector:]!)
    SEL objectSel = @selector(objectAtIndex:);
    id (*objectAtIndex)(id, SEL, NSUInteger);
    objectAtIndex = (id (*)(id, SEL, NSUInteger))[_orderedIcons methodForSelector:objectSel];
    
    // -[FVViewController _cachedIconForURL:]
    SEL cachedIconSel = @selector(_cachedIconForURL:);
    id (*cachedIcon)(id, SEL, id);
    cachedIcon = (id (*)(id, SEL, id))[self methodForSelector:cachedIconSel];
    
    // -[NSCFArray insertObject:atIndex:] (do /not/ use +[NSMutableArray instanceMethodForSelector:]!)
    SEL insertSel = @selector(insertObject:atIndex:);
    void (*insertObjectAtIndex)(id, SEL, id, NSUInteger);
    insertObjectAtIndex = (void (*)(id, SEL, id, NSUInteger))[_orderedIcons methodForSelector:insertSel];
    
    // datasource subtitle method; may result in a NULL IMP (in which case _orderedSubtitles is nil)
    SEL subtitleSel = @selector(fileView:subtitleAtIndex:);
    id (*subtitleAtIndex)(id, SEL, id, NSUInteger);
    subtitleAtIndex = (id (*)(id, SEL, id, NSUInteger))[(id)_dataSource methodForSelector:subtitleSel];
    
    NSUInteger i, iMax = isBound ? [_orderedURLs count] : [_dataSource numberOfURLsInFileView:self];
    
    for (i = 0; i < iMax; i++) {
        NSURL *aURL = isBound ? objectAtIndex(_orderedURLs, objectSel, i) : URLAtIndex(_dataSource, URLSel, self, i);
        if (__builtin_expect(nil == aURL || [NSNull null] == (id)aURL, 0))
            aURL = [FVIcon missingFileURL];
        NSParameterAssert(nil != aURL && [NSNull null] != (id)aURL);
        FVIcon *icon = cachedIcon(self, cachedIconSel, aURL);
        NSParameterAssert(nil != icon);
        if (NO == isBound)
            insertObjectAtIndex(_orderedURLs, insertSel, aURL, i);
        insertObjectAtIndex(_orderedIcons, insertSel, icon, i);
        if (_orderedSubtitles)
            insertObjectAtIndex(_orderedSubtitles, insertSel, subtitleAtIndex(_dataSource, subtitleSel, self, i), i);
    }  
}

- (void)reloadIcons;
{
    [self _reloadIcons];
    
    // Follow NSTableView's example and clear selection outside the current range of indexes
    NSUInteger lastSelIndex = [_selectionIndexes lastIndex], numIcons = [self numberOfIcons];
    if (NSNotFound != lastSelIndex && lastSelIndex >= numIcons) {
        NSMutableIndexSet *newSelIndexes = [_selectionIndexes mutableCopy];
        [newSelIndexes removeIndexesInRange:NSMakeRange(numIcons, lastSelIndex + 1 - numIcons)];
        [self _setSelectionIndexes:newSelIndexes];
        [newSelIndexes release];
    }
    else if (_fvFlags.controllingSharedPreviewer || _fvFlags.controllingQLPreviewPanel) {
        // Content or ordering of selection (may) have changed, so reload any previews
        // Only modify the previewer if this view is controlling it, though!
        [self _updatePreviewer];
    }
    
    [self _resetViewLayout];
}

- (void)_handleFinderLabelChanged:(NSNotification *)note {
    NSURL *url = [note object];
    if (CFDictionaryContainsKey(_infoTable, url)) {
        CFDictionaryRemoveValue(_infoTable, url);
        [self setNeedsDisplay:YES];
    }
}

#pragma mark Cache thread

- (void)_rescaleComplete;
{    
    NSUInteger scrollIndex = [_selectionIndexes firstIndex];
    if (NSNotFound != scrollIndex) {
        NSUInteger r, c;
        [self _getGridRow:&r column:&c ofIndex:scrollIndex];
        // this won't necessarily trigger setNeedsDisplay:, which we need unconditionally
        [self scrollRectToVisible:[self _rectOfIconInRow:r column:c]];
    }
    [self setNeedsDisplay:YES];
    _fvFlags.isRescaling = NO;
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
        
        FVIcon *anIcon = [self iconAtIndex:i];
        if (anIcon == updatedIcon) {
            NSUInteger r, c;
            if ([self _getGridRow:&r column:&c ofIndex:i])
                [self _setNeedsDisplayForIconInRow:r column:c];
        }
    }
}

// -drawRect: uses -releaseResources on icons that aren't visible but present in the datasource, so we just need a way to cull icons that are cached but not currently in the datasource.
- (void)_zombieTimerFired:(CFRunLoopTimerRef)timer
{
    NSMutableSet *iconURLsToKeep = [NSMutableSet setWithArray:_orderedURLs];        

    // find any icons in _zombieIconCache that we want to move back to _iconCache (may never be hit...)
    NSMutableSet *toRemove = [NSMutableSet setWithArray:[_zombieIconCache allKeys]];
    [toRemove intersectSet:iconURLsToKeep];
    
    NSEnumerator *keyEnum = [toRemove objectEnumerator];
    NSURL *aURL;
    while ((aURL = [keyEnum nextObject])) {
        NSParameterAssert([_iconCache objectForKey:aURL] == nil);
        [_iconCache setObject:[_zombieIconCache objectForKey:aURL] forKey:aURL];
        [_zombieIconCache removeObjectForKey:aURL];
    }

    // now remove the remaining undead...
    [_zombieIconCache removeAllObjects];

    // now find stale keys in _iconCache
    toRemove = [NSMutableSet setWithArray:[_iconCache allKeys]];
    [toRemove minusSet:iconURLsToKeep];
    
    // anything remaining in toRemove is not present in the dataSource, so transfer from _iconCache to _zombieIconCache
    keyEnum = [toRemove objectEnumerator];
    while ((aURL = [keyEnum nextObject])) {
        [_zombieIconCache setObject:[_iconCache objectForKey:aURL] forKey:aURL];
        [_iconCache removeObjectForKey:aURL];
    }
}

#pragma mark Drawing

// no save/restore needed because of when these are called in -drawRect: (this is why they're private)

- (void)_drawDropHighlight;
{
    CGFloat lineWidth = 2.0;
    NSBezierPath *p;
    NSUInteger r, c;
    NSRect aRect = NSZeroRect;
    BOOL isColumn = (_fvFlags.displayMode == FVDisplayModeColumn);
    
    switch (_fvFlags.dropOperation) {
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
            // aRect size is 6, and should be centered between icons
            if (isColumn) {
                aRect.origin.y -= 6.0;
                aRect.size.height = 6.0;
            } else {
                aRect.origin.x -= _padding.width / 2 + 3.0;
                aRect.size.width = 6.0;    
            }
            break;
        case FVDropAfter:
            [self _getGridRow:&r column:&c ofIndex:_dropIndex];
            aRect = [self _rectOfIconInRow:r column:c];
            // aRect size is 6, and should be centered between icons
            if (isColumn) {
                aRect.origin.y += _iconSize.height + _padding.height - 6.0;
                aRect.size.height = 6.0;
            } else {
                aRect.origin.x += _iconSize.width + _padding.width / 2 - 3.0;
                aRect.size.width = 6.0;
            }
            break;
        default:
            break;
    }
    
    if (NSIsEmptyRect(aRect) == NO) {
        aRect = [self centerScanRect:aRect];
        
        [[[NSColor alternateSelectedControlColor] colorWithAlphaComponent:0.2] setFill];
        [[[NSColor alternateSelectedControlColor] colorWithAlphaComponent:0.8] setStroke];
        
        if (_fvFlags.dropOperation == FVDropOn) {
            // it's either a drop on the whole table or on top of a cell
            p = [NSBezierPath fv_bezierPathWithRoundRect:NSInsetRect(aRect, 0.5 * lineWidth, 0.5 * lineWidth) xRadius:7 yRadius:7];
            [p fill];
        }
        else if (isColumn) {
            // similar to NSTableView's between-row drop indicator
            CGFloat radius = NSHeight(aRect) / 2;
            NSPoint point = NSMakePoint(NSMaxX(aRect), NSMidY(aRect));
            p = [NSBezierPath bezierPath];
            [p appendBezierPathWithArcWithCenter:point radius:radius startAngle:-180 endAngle:180];
            point.x = NSMinX(aRect);
            [p appendBezierPathWithArcWithCenter:point radius:radius startAngle:0 endAngle:360];
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
        CGContextClearRect(layerContext, NSRectToCGRect(imageRect));
        
        NSGraphicsContext *savedContext = [[NSGraphicsContext currentContext] retain];
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
        [NSGraphicsContext setCurrentContext:savedContext];
        [savedContext release];
    }
    // make sure we use source over for drawing the image
    CGContextSaveGState(drawingContext);
    CGContextSetBlendMode(drawingContext, kCGBlendModeNormal);
    CGContextDrawLayerInRect(drawingContext, NSRectToCGRect(aRect), _selectionOverlay);
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

#define DROP_MESSAGE_MIN_FONTSIZE ((CGFloat) 8.0)
#define DROP_MESSAGE_MAX_INSET    ((CGFloat) 20.0)

- (NSMutableAttributedString *)_dropMessageWithFontSize:(CGFloat)fontSize
{
    NSBundle *bundle = [NSBundle bundleForClass:[FVFileView class]];
    NSString *message = NSLocalizedStringFromTableInBundle(@"Drop Files Here", @"FileView", bundle, @"placeholder message for empty file view");
    NSMutableAttributedString *attrString = [[[NSMutableAttributedString alloc] initWithString:message] autorelease];
    [attrString addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:fontSize] range:NSMakeRange(0, [attrString length])];
    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor lightGrayColor] range:NSMakeRange(0, [attrString length])];
    
    NSMutableParagraphStyle *ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [ps setAlignment:NSCenterTextAlignment];
    [attrString addAttribute:NSParagraphStyleAttributeName value:ps range:NSMakeRange(0, [attrString length])];
    [ps release];
    
    return attrString;
}

static NSArray * _wordsFromAttributedString(NSAttributedString *attributedString)
{
    NSString *string = [attributedString string];
    
    // !!! early return on 10.4, CFStringTokenizerCreate is not weakly linked, so we can't just check for NULL
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4)
        return [string componentsSeparatedByString:@" "];
    
    CFStringTokenizerRef tokenizer = CFStringTokenizerCreate(NULL, (CFStringRef)string, CFRangeMake(0, [string length]), kCFStringTokenizerUnitWord, NULL);
    NSMutableArray *words = [NSMutableArray array];
    while (kCFStringTokenizerTokenNone != CFStringTokenizerAdvanceToNextToken(tokenizer)) {
        CFStringRef word = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription);
        if (word) {
            [words addObject:(id)word];
            CFRelease(word);
        }
    }
    CFRelease(tokenizer);
    return words;
}

- (CGFloat)_widthOfLongestWordInDropMessage
{
    NSMutableAttributedString *message = [self _dropMessageWithFontSize:DROP_MESSAGE_MIN_FONTSIZE];
    NSString *word;
    NSArray *words = _wordsFromAttributedString(message);
    NSUInteger i, wordCount = [words count];
    CGFloat width = 0;
    for (i = 0; i < wordCount; i++) {
        word = [words objectAtIndex:i];
        [[message mutableString] setString:word];
        width = fmax(width, NSWidth([message boundingRectWithSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin]));
    }
    return ceil(width);
}

- (void)_drawDropMessage;
{
    CGFloat minWidth = [self _widthOfLongestWordInDropMessage];    
    NSRect visibleRect = [self visibleRect];
    CGFloat containerInset = (NSWidth(visibleRect) - minWidth) / 2.0;
    containerInset = fmin(containerInset, DROP_MESSAGE_MAX_INSET);
    NSRect containerRect = containerInset > 0 ? [self centerScanRect:NSInsetRect(visibleRect, containerInset, containerInset)] : visibleRect;
    
    // avoid drawing text right up to the path at small widths (inset < 20)
    NSRect pathRect;
    if (containerInset < DROP_MESSAGE_MAX_INSET)
        pathRect = NSInsetRect(containerRect, -2, -2);
    else
        pathRect = NSInsetRect(visibleRect, DROP_MESSAGE_MAX_INSET, DROP_MESSAGE_MAX_INSET);
    
    // negative inset at small view widths may extend outside the view; in that case, don't draw the path
    if (NSContainsRect(visibleRect, pathRect)) {
        NSBezierPath *path = [NSBezierPath fv_bezierPathWithRoundRect:[self centerScanRect:pathRect] xRadius:10 yRadius:10];
        CGFloat pattern[2] = { 12.0, 6.0 };
        
        // This sets all future paths to have a dash pattern, and it's not affected by save/restore gstate on Tiger.  Lame.
        CGFloat previousLineWidth = [path lineWidth];
        // ??? make this a continuous function of width <= 3
        [path setLineWidth:(NSWidth(containerRect) > 100 ? 3.0 : 2.0)];
        [path setLineDash:pattern count:2 phase:0.0];
        [[NSColor lightGrayColor] setStroke];
        [path stroke];
        [path setLineWidth:previousLineWidth];
        [path setLineDash:NULL count:0 phase:0.0];
    }
    
    CGFloat fontSize = 24.0;
    NSMutableAttributedString *message = [self _dropMessageWithFontSize:fontSize];
    CGFloat singleLineHeight = NSHeight([message boundingRectWithSize:containerRect.size options:0]);
    
    // NSLayoutManager's defaultLineHeightForFont doesn't include padding that NSStringDrawing uses
    NSRect r = [message boundingRectWithSize:containerRect.size options:NSStringDrawingUsesLineFragmentOrigin];
    NSUInteger wordCount = [_wordsFromAttributedString(message) count];
    
    // reduce font size until we have no more than wordCount lines
    while (fontSize > DROP_MESSAGE_MIN_FONTSIZE && NSHeight(r) > wordCount * singleLineHeight) {
        fontSize -= 1.0;
        [message addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:fontSize] range:NSMakeRange(0, [message length])];
        singleLineHeight = NSHeight([message boundingRectWithSize:containerRect.size options:0]);
        r = [message boundingRectWithSize:containerRect.size options:NSStringDrawingUsesLineFragmentOrigin];
    }
    containerRect.origin.y = (NSHeight(containerRect) - NSHeight(r)) / 2;
    
    // draw nothing if words are broken across lines, or the font size is too small
    if (fontSize >= DROP_MESSAGE_MIN_FONTSIZE && NSHeight(r) <= wordCount * singleLineHeight)
        [message drawWithRect:containerRect options:NSStringDrawingUsesLineFragmentOrigin];
}

// redraw at full quality after a resize
- (void)viewDidEndLiveResize
{
    [self reloadIcons];
    _fvFlags.scheduledLiveResize = NO;
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
    
    // Don't release resources while scrolling; caller has already checked -inLiveResize and _fvFlags.isRescaling for us

    if (NO == [self _isFastScrolling]) {
        
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

- (void)_drawIconsInRows:(NSRange)rows columns:(NSRange)columns forDragImage:(BOOL)isDrawingDragImage
{
    BOOL isResizing = [self inLiveResize];

    NSUInteger r, rMin = rows.location, rMax = NSMaxRange(rows);
    NSUInteger c, cMin = columns.location, cMax = NSMaxRange(columns);
    NSUInteger i;
        
    NSGraphicsContext *ctxt = [NSGraphicsContext currentContext];
    CGContextRef cgContext = [ctxt graphicsPort];
    CGContextSetBlendMode(cgContext, kCGBlendModeNormal);
    
    // don't limit quality based on scrolling unless we really need to
    if (isResizing || _fvFlags.isRescaling) {
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
    
    BOOL useFastDrawingPath = (isResizing || _fvFlags.isRescaling || ([self _isFastScrolling] && _iconSize.height <= 256));
    
    // redraw at high quality after scrolling
    if (useFastDrawingPath && NO == _fvFlags.scheduledLiveResize && [self _isFastScrolling]) {
        _fvFlags.scheduledLiveResize = YES;
        [self performSelector:@selector(viewDidEndLiveResize) withObject:nil afterDelay:0 inModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
    }
    
    // shadow needs to be scaled as the icon scale changes to approximate the IconServices shadow
    CGFloat shadowBlur = 2.0 * [self iconScale];
    CGSize shadowOffset = CGSizeMake(0.0, -[self iconScale]);
    CGColorSpaceRef cspace = CGColorSpaceCreateDeviceRGB();
    CGFloat shadowComponents[] = { 0, 0, 0, 0.4 };
    CGColorRef shadowColor = CGColorCreate(cspace, shadowComponents);
    CGColorSpaceRelease(cspace);
    
    // iterate each row/column to see if it's in the dirty rect, and evaluate the current cache state
    for (r = rMin; r < rMax; r++) 
    {
        for (c = cMin; c < cMax; c++) 
        {
            i = [self _indexForGridRow:r column:c];

            // if we're creating a drag image, only draw selected icons
            if (NSNotFound != i && (NO == isDrawingDragImage || [_selectionIndexes containsIndex:i])) {
            
                NSRect fileRect = [self _rectOfIconInRow:r column:c];
                
                // allow some extra for the shadow (-5)
                NSRect textRect = [self _rectOfTextForIconRect:fileRect];
                // always draw icon and text together, as they may overlap due to shadow and finder label, and redrawing a part may look odd
                BOOL willDrawIcon = isDrawingDragImage || [self needsToDrawRect:NSUnionRect(NSInsetRect(fileRect, -2.0 * [self iconScale], -[self iconScale]), textRect)];
                                
                if (willDrawIcon) {

                    FVIcon *image = [self iconAtIndex:i];
                    
                    // note that iconRect will be transformed for a flipped context
                    NSRect iconRect = fileRect;
                    
                    // draw highlight, then draw icon over it, as Finder does
                    if ([_selectionIndexes containsIndex:i])
                        [self _drawHighlightInRect:NSInsetRect(fileRect, HIGHLIGHT_INSET, HIGHLIGHT_INSET)];
                    
                    CGContextSaveGState(cgContext);
                    
                    // draw a shadow behind the image/page
                    CGContextSetShadowWithColor(cgContext, shadowOffset, shadowBlur, shadowColor);
                    
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
                    
                    textRect = [self centerScanRect:NSInsetRect(textRect, -4.0, 0.0)];
                    
                    NSString *name, *subtitle = [self subtitleAtIndex:i];
                    NSUInteger label;
                    [self _getDisplayName:&name andLabel:&label forURL:[self URLAtIndex:i]];
                    CGFloat titleHeight = [_titleCell cellSize].height;
                    
                    [_titleCell setStringValue:name ?: @""];
                    if (label > 0) {
                        CGRect labelRect = NSRectToCGRect([self centerScanRect:NSInsetRect(textRect, 4.0, 0.0)]);
                        
                        labelRect.size.height = titleHeight;                        
                        [FVFinderLabel drawFinderLabel:label inRect:labelRect ofContext:cgContext flipped:NO roundEnds:YES];
                        
                        // labeled title uses black text for greater contrast; inset horizontally because of the rounded end caps
                        NSColor *titleColor = [[_titleCell textColor] retain];
                        [_titleCell setTextColor:[NSColor controlTextColor]];
                        [_titleCell drawWithFrame:NSInsetRect(textRect, titleHeight / 2.0 , 0) inView:self];
                        [_titleCell setTextColor:titleColor];
                        [titleColor release];
                    }
                    else {
                        [_titleCell drawWithFrame:textRect inView:self];
                    }
                    
                    if (subtitle) {
                        textRect.origin.y += titleHeight;
                        textRect.size.height -= titleHeight;
                        [_subtitleCell setStringValue:subtitle];
                        [_subtitleCell drawWithFrame:textRect inView:self];
                    }
                    CGContextRestoreGState(cgContext);
                } 
#if DEBUG_GRID
                [NSGraphicsContext saveGraphicsState];
                if ((c + r) % 2)
                    [[NSColor redColor] setFill];
                else
                    [[NSColor greenColor] setFill];
                NSFrameRect(NSUnionRect(NSInsetRect(fileRect, -2.0 * [self iconScale], 0), textRect));                
                [NSGraphicsContext restoreGraphicsState];
#endif
            }
        }
    }
    
    CGColorRelease(shadowColor);
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

- (void)_fillBackgroundColorOrGradientInRect:(NSRect)rect
{
    // any solid color background should override the gradient code
    if ([self backgroundColor]) {
        [[self backgroundColor] setFill];
        NSRectFillUsingOperation(rect, NSCompositeCopy);
    }
    else {
        /*
         The NSTableView magic source list color no longer works properly on 10.7, either
         because they changed it from a solid color to a gradient, or just changed the
         drawing.  I couldn't see a reasonable way to subclass NSColor and draw a gradient
         as Apple does, or to force the color to update properly, so we'll just cheat and
         do it the easy way.  Using 10.5 and later API is okay, since 10.4 gets a solid
         color anyway.
         */
        FVAPIAssert(floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6, @"gradient background is only available on 10.7 and later");
        
        // otherwise we see a blocky transition, which fades on the redraw when scrolling stops
        if ([[[self enclosingScrollView] contentView] copiesOnScroll])
            [[[self enclosingScrollView] contentView] setCopiesOnScroll:NO];
            
        // should be RGBA space, since we're drawing to the screen
        CGColorSpaceRef cspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
        const CGFloat locations[] = { 0, 1 };
        CGGradientRef gradient;
        
        // color values from DigitalColor Meter on 10.7, using Generic RGB space
        if ([[self window] isKeyWindow] || [[self window] isMainWindow]) {
            // ordered as lower/upper
            const CGFloat components[8] = { 198.0 / 255.0, 207.0 / 255.0, 216.0 / 255.0, 1.0, 227.0 / 255.0, 232.0 / 255.0, 238.0 / 255.0, 1.0 };
            gradient = CGGradientCreateWithColorComponents(cspace, components, locations, 2);
        }
        else {
            // ordered as lower/upper
            const CGFloat components[8] = { 230.0 / 255.0, 230.0 / 255.0, 230.0 / 255.0, 1.0, 246.0 / 255.0, 246.0 / 255.0, 246.0 / 255.0, 1.0 };
            gradient = CGGradientCreateWithColorComponents(cspace, components, locations, 2);
        }
        CGContextRef ctxt = [[NSGraphicsContext currentContext] graphicsPort];

        // only draw the dirty part, but we need to use the full visible bounds as the gradient extent
        CGContextSaveGState(ctxt);
        CGContextClipToRect(ctxt, NSRectToCGRect(rect));
        const NSRect bounds = [self visibleRect];
        CGContextDrawLinearGradient(ctxt, gradient, CGPointMake(0, NSMaxY(bounds)), CGPointMake(0, NSMinY(bounds)), 0);
        CGContextRestoreGState(ctxt);

        CGGradientRelease(gradient);
        CGColorSpaceRelease(cspace);
    }
}

- (void)drawRect:(NSRect)rect;
{
    BOOL isDrawingToScreen = [[NSGraphicsContext currentContext] isDrawingToScreen];
    
    if (isDrawingToScreen)
        [self _fillBackgroundColorOrGradientInRect:rect];
    
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
        [self _drawIconsInRows:rowRange columns:columnRange forDragImage:NO];
        
        // avoid hitting the cache thread while a live resize is in progress, but allow cache updates while scrolling
        // use the same range criteria that we used in iterating icons
        if (NO == [self inLiveResize] && NO == _fvFlags.isRescaling)
            [self _scheduleIconsInRange:NSMakeRange(iMin, iMax - iMin)];
    }
    else if (0 == iMax && [self isEditable]) {
        [[NSGraphicsContext currentContext] setShouldAntialias:YES];
        [self _drawDropMessage];
    }
    
    if (isDrawingToScreen) {
        
        if (_fvFlags.hasArrows || _arrowAnimation) {
            if (NSIntersectsRect(rect, _leftArrowFrame))
                [(FVArrowButtonCell *)_leftArrow drawWithFrame:_leftArrowFrame inView:self alpha:_arrowAlpha];
            if (NSIntersectsRect(rect, _rightArrowFrame))
                [(FVArrowButtonCell *)_rightArrow drawWithFrame:_rightArrowFrame inView:self alpha:_arrowAlpha];
        }
        
        // drop highlight and rubber band are mutually exclusive
        if (_dropIndex != NSNotFound || _fvFlags.dropOperation == FVDropOn) {
            [self _drawDropHighlight];
        }
        else if (NSIsEmptyRect(_rubberBandRect) == NO) {
            [self _drawRubberbandRect];
        }
        
        if ([self allowsDownloading] && [_downloads count]) {
            NSEnumerator *dlEnum = [_downloads objectEnumerator];
            FVDownload *download;
            while ((download = [dlEnum nextObject])) {
                NSUInteger anIndex = [download indexInView];
                // we only draw a if there's an active download for this URL/index pair
                if (anIndex < [self numberOfIcons] && [[self URLAtIndex:anIndex] isEqual:[download downloadURL]])
                    [[download progressIndicator] drawWithFrame:[self _rectOfProgressIndicatorForIconAtIndex:anIndex] inView:self];
            }
        }
    }
#if DEBUG_GRID 
    [[NSColor grayColor] set];
    NSRect r = NSInsetRect([self bounds], [self _leftMargin], [self _topMargin]);
    r.size.height += [self _topMargin] - [self _bottomMargin];
    NSFrameRect(r);
#endif
}

#pragma mark Drag source

- (void)draggedImage:(NSImage *)image endedAt:(NSPoint)screenPoint operation:(NSDragOperation)operation;
{
    // only called if we originated the drag, so the row/column must be valid
    if ((operation & NSDragOperationDelete) != 0 && operation != NSDragOperationEvery && [self isEditable]) {
        [[self dataSource] fileView:self deleteURLsAtIndexes:[[_selectionIndexes retain] autorelease]];
        [self _setSelectionIndexes:[NSIndexSet indexSet]];
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

- (void)dragImageForEvent:(NSEvent *)event pasteboard:(NSPasteboard *)pboard;
{
    NSUInteger r, c, cMin = NSUIntegerMax, cMax = 0, rMin = NSUIntegerMax, rMax = 0;
    NSUInteger i = [_selectionIndexes firstIndex];
    while (i != NSNotFound) {
        [self _getGridRow:&r column:&c ofIndex:i];
        cMin = MIN(cMin, c);
        cMax = MAX(cMax, c);
        rMin = MIN(rMin, r);
        rMax = MAX(rMax, r);
        i = [_selectionIndexes indexGreaterThanIndex:i];
    }
    
    NSRect rect = NSZeroRect;
    for (r = rMin, c = cMin; r <= rMax && c <= cMax;) {
        NSRect iconRect = [self _rectOfIconInRow:r column:c];
        NSRect textRect = [self _rectOfTextForIconRect:iconRect];
        iconRect = NSUnionRect(NSInsetRect([self centerScanRect:iconRect], HIGHLIGHT_INSET, HIGHLIGHT_INSET), [self centerScanRect:textRect]);
        rect = NSUnionRect(rect, iconRect);
        if (r >= rMax && c >= cMax)
            break;
        r = rMax;
        c = cMax;
    }
    
    NSRect bounds = [self bounds];
    
    NSImage *newImage = [[[NSImage alloc] initWithSize:bounds.size] autorelease];
    [newImage lockFocusFlipped:YES];
    [self _drawIconsInRows:NSMakeRange(rMin, rMax + 1 - rMin) columns:NSMakeRange(cMin, cMax + 1 - cMax) forDragImage:YES];
    [newImage unlockFocus];
    
    // redraw with transparency, so it's easier to see a target
    NSPoint drawPoint = NSMakePoint(NSMinX(bounds) - NSMinX(rect), NSMaxY(rect) - NSMaxY(bounds));
    NSImage *dragImage = [[[NSImage alloc] initWithSize:rect.size] autorelease];
    [dragImage lockFocus];
    [newImage drawAtPoint:drawPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:0.7];
    [dragImage unlockFocus];
    
    NSPoint dragPoint = NSMakePoint(NSMinX(rect), NSMaxY(rect));
    
    [self dragImage:dragImage at:dragPoint offset:NSZeroSize event:event pasteboard:pboard source:self slideBack:YES];
}

#pragma mark Drop target

- (void)setDropIndex:(NSUInteger)anIndex dropOperation:(FVDropOperation)anOperation
{
    _dropIndex = anIndex;
    _fvFlags.dropOperation = anOperation;
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
    NSUInteger r, c, dropOp;
    BOOL found;
    NSDragOperation dragOp = [sender draggingSourceOperationMask] & ~NSDragOperationMove;
    BOOL isCopy = [self allowsDownloading] && dragOp == NSDragOperationCopy;
    NSUInteger insertIndex, firstIndex, endIndex;
    
    // !!! this is quite expensive to call repeatedly in -draggingUpdated
    BOOL hasURLs = FVPasteboardHasURL([sender draggingPasteboard]);
    
    // First determine the drop location, drop between rows in column mode, and between columns otherwise
    if (_fvFlags.displayMode == FVDisplayModeColumn)
        found = [self _getGridRow:&r column:&c rowOperation:&dropOp columnOperation:NULL atPoint:p];
    else
        found = [self _getGridRow:&r column:&c rowOperation:NULL columnOperation:&dropOp atPoint:p];
    _fvFlags.dropOperation = dropOp;
    _dropIndex = found ? [self _indexForGridRow:r column:c] : NSNotFound;
    // Check whether the index is not NSNotFound, because the grid cell can be empty
    if (_dropIndex == NSNotFound)
        _fvFlags.dropOperation = FVDropOn;
    
    // We won't reset the drop location info when we propose NSDragOperationNone, because the delegate may want to override our decision, we will reset it at the end
    
    if (hasURLs == NO) {
        // We have to make sure the pasteboard really has a URL here, since most NSStrings aren't valid URLs, but the delegate may accept other types
        dragOp = NSDragOperationNone;
    }
    else if ([self _isLocalDraggingInfo:sender] && isCopy == NO) {
        // invalidate some local drags, otherwise make sure we use a Move operation
        if (FVDropOn == _fvFlags.dropOperation) {
            // drop on the whole view (add operation) or an icon (replace operation) makes no sense for a local drag, but the delegate may override
            dragOp = NSDragOperationNone;
        } 
        else if (FVDropBefore == _fvFlags.dropOperation || FVDropAfter == _fvFlags.dropOperation) {
            // inserting inside the block we're dragging doesn't make sense; this does allow dropping a disjoint selection at some locations within the selection; the delegate may override
            insertIndex = FVDropAfter == _fvFlags.dropOperation ? _dropIndex + 1 : _dropIndex;
            firstIndex = [_selectionIndexes firstIndex], endIndex = [_selectionIndexes lastIndex] + 1;
            if ([_selectionIndexes containsIndexesInRange:NSMakeRange(firstIndex, endIndex - firstIndex)] &&
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
    
    // we could allow the delegate to change the _dropIndex and _fvFlags.dropOperation as NSTableView does, but we don't use that at present
    if ([[self delegate] respondsToSelector:@selector(fileView:validateDrop:proposedIndex:proposedDropOperation:proposedDragOperation:)])
        dragOp = [[self delegate] fileView:self validateDrop:sender proposedIndex:_dropIndex proposedDropOperation:_fvFlags.dropOperation proposedDragOperation:dragOp];
    
    // make sure we're consistent, also see comment above
    if (dragOp == NSDragOperationNone) {
        _dropIndex = NSNotFound;
        _fvFlags.dropOperation = FVDropBefore;
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
    _fvFlags.dropOperation = FVDropBefore;
    [self setNeedsDisplay:YES];
}

// only invoked if performDragOperation returned YES
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;
{
    _dropIndex = NSNotFound;
    _fvFlags.dropOperation = FVDropBefore;
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
        newPath = [[NSString stringWithFormat:@"%@-%lu", basePath, (unsigned long)++i] stringByAppendingPathExtension:ext];
    } while ([fm fileExistsAtPath:newPath]);
    
    if ([fm copyItemAtPath:path toPath:newPath error:NULL]) {
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
    
    if (FVDropBefore == _fvFlags.dropOperation) {
        insertIndex = _dropIndex;
    } else if (FVDropAfter == _fvFlags.dropOperation) {
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
            else if ([self allowsDownloading])
                [downloads addObject:[NSDictionary dictionaryWithObjectsAndKeys:aURL, @"URL", [NSNumber numberWithUnsignedInteger:i], @"index", nil]];
            if (aURL) {
                [copiedURLs addObject:aURL];
                i++;
            }
        }
        allURLs = copiedURLs;
    }
    
    if (isMove) {
        
        didPerform = [[self dataSource] fileView:self moveURLsAtIndexes:[[_selectionIndexes retain] autorelease] toIndex:insertIndex forDrop:sender dropOperation:_fvFlags.dropOperation];
        
    } else if (FVDropBefore == _fvFlags.dropOperation || FVDropAfter == _fvFlags.dropOperation || NSNotFound == _dropIndex) {
           
        // drop on the whole view
        NSIndexSet *insertSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(insertIndex, [allURLs count])];
        [[self dataSource] fileView:self insertURLs:allURLs atIndexes:insertSet forDrop:sender dropOperation:_fvFlags.dropOperation];
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
            didPerform = [[self dataSource] fileView:self replaceURLsAtIndexes:[NSIndexSet indexSetWithIndex:_dropIndex] withURLs:[NSArray arrayWithObject:aURL] forDrop:sender dropOperation:_fvFlags.dropOperation];
    }
    
    if ([downloads count]) {
        NSEnumerator *dlEnum = [downloads objectEnumerator];
        NSDictionary *dl;
        while (dl = [dlEnum nextObject]) {
            NSUInteger anIndex = [[dl objectForKey:@"index"] unsignedIntegerValue];
            NSURL *aURL = [dl objectForKey:@"URL"];
            if (anIndex < [self numberOfIcons] && [aURL isEqual:[self URLAtIndex:anIndex]])
                [self _downloadURLAtIndex:anIndex];
        }
    }
    
    // if we return NO, concludeDragOperation doesn't get called
    _dropIndex = NSNotFound;
    _fvFlags.dropOperation = FVDropBefore;
    [self setNeedsDisplay:YES];
    
    // reload is handled in concludeDragOperation:
    return didPerform;
}

#pragma mark Event handling

- (BOOL)acceptsFirstResponder { return YES; }

- (BOOL)canBecomeKeyView { return YES; }

- (void)scrollWheel:(NSEvent *)event
{
    // Run in NSEventTrackingRunLoopMode for scroll wheel events, in order to avoid continuous tracking/tooltip rect resets while scrolling.
    while ((event = [NSApp nextEventMatchingMask:NSScrollWheelMask untilDate:[NSDate dateWithTimeIntervalSinceNow:0.5] inMode:NSEventTrackingRunLoopMode dequeue:YES]))
        [super scrollWheel:event];
}

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

- (void)animationDidStop:(NSAnimation *)animation
{
    [_arrowAnimation release];
    _arrowAnimation = nil;
    _arrowAlpha = _fvFlags.hasArrows ? 1.0 : 0.0;
    [self setNeedsDisplayInRect:NSUnionRect(_leftArrowFrame, _rightArrowFrame)];
}

- (void)animationDidEnd:(NSAnimation *)animation
{
    [_arrowAnimation release];
    _arrowAnimation = nil;
    _arrowAlpha = _fvFlags.hasArrows ? 1.0 : 0.0;
    [self setNeedsDisplayInRect:NSUnionRect(_leftArrowFrame, _rightArrowFrame)];
}

- (void)animation:(NSAnimation *)animation didReachProgress:(NSAnimationProgress)progress
{
    _arrowAlpha = _fvFlags.hasArrows ? progress : (1 - progress);
    [self setNeedsDisplayInRect:NSUnionRect(_leftArrowFrame, _rightArrowFrame)];
}

- (void)_startArrowAlphaTimer
{
    // animate ~30 fps for 0.3 seconds, using NSAnimation to get the alpha curve
    _arrowAnimation = [[FVAnimation alloc] initWithDuration:0.3 animationCurve:NSAnimationEaseInOut]; 
    [_arrowAnimation setAnimationBlockingMode:NSAnimationNonblocking];
    [_arrowAnimation setDelegate:self];
    [_arrowAnimation startAnimation];
}

- (void)_showArrowsForIconAtIndex:(NSUInteger)anIndex
{
    NSUInteger r, c;
    
    // this can happen if we screwed up in managing cursor rects
    NSParameterAssert(anIndex < [self numberOfIcons]);
    
    if ([self _getGridRow:&r column:&c ofIndex:anIndex]) {
    
        FVIcon *anIcon = [self iconAtIndex:anIndex];
        
        if ([anIcon pageCount] > 1) {
            
            if (_arrowAnimation) {
                [_arrowAnimation stopAnimation];
                // make sure we redraw whatever area previously had the arrows
                [self setNeedsDisplayInRect:NSUnionRect(_leftArrowFrame, _rightArrowFrame)];
            }
        
            NSRect iconRect = [self _rectOfIconInRow:r column:c];
            
            // determine a min/max size for the arrow buttons
            CGFloat side, sep;
            side = round(0.2 * NSHeight(iconRect));
            side = fmax(fmin(side, 32.0), 10.0);
            sep = fmin(0.5 * side - 4.0, 4.0);
            // 2 pixels between arrows horizontally, and 4 pixels between bottom of arrow and bottom of iconRect
            _leftArrowFrame = _rightArrowFrame = NSMakeRect(ceil(NSMidX(iconRect) + 0.5 * sep), NSMaxY(iconRect) - side - sep, side, side);
            _leftArrowFrame.origin.x -= side + sep;
            
            [_leftArrow setRepresentedObject:anIcon];
            [_rightArrow setRepresentedObject:anIcon];
            _fvFlags.hasArrows = YES;

            // set enabled states
            [self _updateButtonsForIcon:anIcon];  
                        
            if (nil == _arrowAnimation)
                [self _startArrowAlphaTimer];
        }
    }
}

- (void)_hideArrows
{
    if (_fvFlags.hasArrows) {
        _fvFlags.hasArrows = NO;
        [_leftArrow setRepresentedObject:nil];
        [_rightArrow setRepresentedObject:nil];
        if (nil == _arrowAnimation)
            [self _startArrowAlphaTimer];
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
        } else if (_fvFlags.displayMode == FVDisplayModeGrid && _sliderWindow && [event userData] == _sliderWindow) {
            
            if ([_sliderWindow parentWindow] == nil) {
                NSRect sliderRect = tag == _bottomSliderTag ? [self _bottomSliderRect] : [self _topSliderRect];
                sliderRect = [self convertRect:sliderRect toView:nil];
                sliderRect.origin = [[self window] convertBaseToScreen:sliderRect.origin];
                // looks cool to use -animator here, but makes it hard to hit...
                if (NSEqualRects([_sliderWindow frame], sliderRect) == NO)
                    [_sliderWindow setFrame:sliderRect display:NO];
                
                [_sliderWindow fadeIn:self];
                [[self window] addChildWindow:_sliderWindow ordered:NSWindowAbove];
            }
        }
    }
    
    
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
    return NSNotFound == anIndex ? nil : [self URLAtIndex:anIndex];
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
    _fvFlags.isMouseDown = YES;
    
    NSPoint p = [event locationInWindow];
    p = [self convertPoint:p fromView:nil];
    _lastMouseDownLocInView = p;

    NSUInteger flags = [event modifierFlags];
    NSUInteger r, c, i;
    
    if (_fvFlags.hasArrows && NSMouseInRect(p, _leftArrowFrame, [self isFlipped])) {
        [_leftArrow trackMouse:event inRect:_leftArrowFrame ofView:self untilMouseUp:YES];
    }
    else if (_fvFlags.hasArrows && NSMouseInRect(p, _rightArrowFrame, [self isFlipped])) {
        [_rightArrow trackMouse:event inRect:_rightArrowFrame ofView:self untilMouseUp:YES];
    }
    // mark this icon for highlight if necessary
    else if ([self _getGridRow:&r column:&c atPoint:p]) {
        
        // remember _indexForGridRow:column: returns NSNotFound if you're in an empty slot of an existing row/column, but that's a deselect event so we still need to remove all selection indexes and mark for redisplay
        i = [self _indexForGridRow:r column:c];
        
        NSMutableIndexSet *newSelection = nil;
        
        if ([_selectionIndexes containsIndex:i] == NO) {
            
            // deselect all if modifier key was not pressed, or i == NSNotFound
            if ((flags & (NSCommandKeyMask | NSShiftKeyMask)) == 0 || NSNotFound == i)
                newSelection = [[NSMutableIndexSet alloc] init];
            else
                newSelection = [_selectionIndexes mutableCopy];
            
            // if there's an icon in this cell, add to the current selection (which we may have just reset)
            if (NSNotFound != i) {
                // add a single index for an unmodified or cmd-click
                // add a single index for shift click only if there is no current selection
                if ((flags & NSShiftKeyMask) == 0 || [newSelection count] == 0) {
                    [newSelection addIndex:i];
                }
                else if ((flags & NSShiftKeyMask) != 0) {
                    // Shift-click extends by a region; this is equivalent to iPhoto's grid view.  Finder treats shift-click like cmd-click in icon view, but we have a fixed layout, so this behavior is convenient and will be predictable.
                    
                    // at this point, we know that [_selectionIndexes count] > 0
                    NSParameterAssert([newSelection count]);
                    
                    NSUInteger start = [newSelection firstIndex];
                    NSUInteger end = [newSelection lastIndex];

                    if (i < start) {
                        [newSelection addIndexesInRange:NSMakeRange(i, start - i)];
                    }
                    else if (i > end) {
                        [newSelection addIndexesInRange:NSMakeRange(end + 1, i - end)];
                    }
                    else if (NSNotFound != _lastClickedIndex) {
                        // This handles the case of clicking in a deselected region between two selected regions.  We want to extend from the last click to the current one, instead of randomly picking an end to start from.
                        if (_lastClickedIndex > i)
                            [newSelection addIndexesInRange:NSMakeRange(i, _lastClickedIndex - i)];
                        else
                            [newSelection addIndexesInRange:NSMakeRange(_lastClickedIndex + 1, i - _lastClickedIndex)];
                    }
                }
            }
        }
        else if ((flags & NSCommandKeyMask) != 0) {
            // cmd-clicked a previously selected index, so remove it from the selection
            newSelection = [_selectionIndexes mutableCopy];
            [newSelection removeIndex:i];
        }
        
        if (newSelection) {
            [self _setSelectionIndexes:newSelection];
            [newSelection release];
        }
        
        // always reset this
        _lastClickedIndex = i;
        
        // change selection first, as Finder does
        if ([event clickCount] > 1 && [self _URLAtPoint:p] != nil) {
            if (flags & NSAlternateKeyMask) {
                [self _getGridRow:&r column:&c atPoint:p];
                [self _previewURL:[self _URLAtPoint:p] forIconInRect:[self _rectOfIconInRow:r column:c]];
            } else {
                [self openSelectedURLs:self];
            }
        }
        
    }
    else if ([_selectionIndexes count]) {
        // deselect all, since we had a previous selection and clicked on a non-icon area
        [self _setSelectionIndexes:[NSIndexSet indexSet]];
    }
    else {
        [super mouseDown:event];
    }    
}

static NSRect _rectWithCorners(const NSPoint aPoint, const NSPoint bPoint) {
    NSRect rect;
    rect.origin.x = fmin(aPoint.x, bPoint.x);
    rect.origin.y = fmin(aPoint.y, bPoint.y);
    rect.size.width = fmax(3.0, fmax(aPoint.x, bPoint.x) - NSMinX(rect));
    rect.size.height = fmax(3.0, fmax(aPoint.y, bPoint.y) - NSMinY(rect));
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
    _fvFlags.isMouseDown = NO;
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
    
    // _fvFlags.isMouseDown tells us if the mouseDown: event originated in this view; if not, just ignore it
    
    if (NSEqualRects(_rubberBandRect, NSZeroRect) && nil != pointURL && _fvFlags.isMouseDown) {
        // No previous rubber band selection, so check to see if we're dragging an icon at this point.
        // The condition is also false when we're getting a repeated call to mouseDragged: for rubber band drawing.
        
        NSArray *selectedURLs = nil;
                
        // we may have a selection based on a previous rubber band, but only use that if we dragged one of the icons in it
        selectedURLs = [self _selectedURLs];
        if ([selectedURLs containsObject:pointURL] == NO) {
            selectedURLs = nil;
            [self _setSelectionIndexes:[NSIndexSet indexSet]];
        }
        
        NSUInteger i, r, c;

        // not using a rubber band, so select and use the clicked URL if available (mouseDown: should have already done this)
        if (0 == [selectedURLs count] && nil != pointURL && [self _getGridRow:&r column:&c atPoint:p]) {
            selectedURLs = [NSArray arrayWithObject:pointURL];
            i = [self _indexForGridRow:r column:c];
            [self _setSelectionIndexes:[NSIndexSet indexSetWithIndex:i]];
        }
        
        // if we have anything to drag, start a drag session
        if ([selectedURLs count]) {
            
            NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
            
            // add all URLs (file and other schemes)
            // Finder will create weblocs for us unless schemes are mixed (gives a stupid file busy error message)
            
            if (FVWriteURLsToPasteboard(selectedURLs, pboard)) {
                [self dragImageForEvent:event pasteboard:pboard];
            }
        }
        else {
            [super mouseDragged:event];
        }
        
    }
    else if (_fvFlags.isMouseDown) {   
        
        // no icons to drag, so we must draw the rubber band rectangle
        _rubberBandRect = NSIntersectionRect(_rectWithCorners(_lastMouseDownLocInView, p), [self bounds]);
        [self _setSelectionIndexes:[self _allIndexesInRubberBandRect]];
        [self setNeedsDisplayInRect:_rubberBandRect];
        [self autoscroll:event];
        [super mouseDragged:event];
    }
}

- (void)magnifyWithEvent:(NSEvent *)theEvent;
{
    CGFloat dz = [theEvent deltaZ];
    dz = dz > 0 ? fmin(0.2, dz) : fmax(-0.2, dz);
    [self _setIconScale:fmax(0.1, [self iconScale] + 0.5 * dz)];
}

#pragma mark User interaction

- (void)scrollItemAtIndexToVisible:(NSUInteger)anIndex
{
    NSUInteger r = 0, c = 0;
    if ([self _getGridRow:&r column:&c ofIndex:anIndex])
        [self scrollRectToVisible:[self _rectOfIconInRow:r column:c]];
}

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
                    [self _setSelectionIndexes:[NSIndexSet indexSetWithIndex:idx]];
                }
            }
        }
        return YES;
    } else {
        return NO;
    }
}

- (void)moveUp:(id)sender;
{
    NSUInteger curIdx = [_selectionIndexes firstIndex];
    NSUInteger next = (NSNotFound == curIdx || curIdx < [self numberOfColumns]) ? 0 : curIdx - [self numberOfColumns];
    if (next >= [self numberOfIcons]) {
        NSBeep();
    }
    else {
        [self scrollItemAtIndexToVisible:next];
        [self _setSelectionIndexes:[NSIndexSet indexSetWithIndex:next]];
    }
}

- (void)moveDown:(id)sender;
{
    NSUInteger curIdx = [_selectionIndexes firstIndex];
    NSUInteger next = NSNotFound == curIdx ? 0 : curIdx + [self numberOfColumns];
    if ([self numberOfIcons] == 0) {
        NSBeep();
    }
    else {
        if (next >= [self numberOfIcons])
            next = [self numberOfIcons] - 1;

        [self scrollItemAtIndexToVisible:next];
        [self _setSelectionIndexes:[NSIndexSet indexSetWithIndex:next]];
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
    NSUInteger curIdx = [_selectionIndexes lastIndex], numIcons = [self numberOfIcons];
    
    if (numIcons > 0 && curIdx != numIcons - 1)
        [self selectNextIcon:self];
    else
        [[self window] selectNextKeyView:self]; 
}

- (void)insertBacktab:(id)sender;
{
    NSUInteger curIdx = [_selectionIndexes firstIndex];
    
    if ([self numberOfIcons] > 0 && curIdx != 0)
        [self selectPreviousIcon:self];
    else
        [[self window] selectPreviousKeyView:self]; 
}

- (void)moveToBeginningOfLine:(id)sender;
{
    if ([_selectionIndexes count] == 1) {
        FVIcon *anIcon = [self iconAtIndex:[_selectionIndexes firstIndex]];
        if ([anIcon currentPageIndex] > 1) {
            [anIcon showPreviousPage];
            [self _redisplayIconAfterPageChanged:anIcon];
        }
    }
}

- (void)moveToEndOfLine:(id)sender;
{
    if ([_selectionIndexes count] == 1) {
        FVIcon *anIcon = [self iconAtIndex:[_selectionIndexes firstIndex]];
        if ([anIcon currentPageIndex] < [anIcon pageCount]) {
            [anIcon showNextPage];
            [self _redisplayIconAfterPageChanged:anIcon];
        }
    }
}

- (void)moveToBeginningOfDocument:(id)sender;
{
    if ([_selectionIndexes count] == 1) {
        FVIcon *anIcon = [self iconAtIndex:[_selectionIndexes firstIndex]];
        if ([anIcon currentPageIndex] > 1) {
            [anIcon showFirstPage];
            [self _redisplayIconAfterPageChanged:anIcon];
        }
    }
}

- (void)moveToEndOfDocument:(id)sender;
{
    if ([_selectionIndexes count] == 1) {
        FVIcon *anIcon = [self iconAtIndex:[_selectionIndexes firstIndex]];
        if ([anIcon currentPageIndex] < [anIcon pageCount]) {
            [anIcon showLastPage];
            [self _redisplayIconAfterPageChanged:anIcon];
        }
    }
}

- (void)insertNewline:(id)sender;
{
    if ([_selectionIndexes count])
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
                    [self _setSelectionIndexes:[NSIndexSet indexSetWithIndex:idx]];
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
- (BOOL)scrollRectToVisible:(NSRect)aRect
{
    NSRect visibleRect = [self visibleRect];
    BOOL didScroll = NO;
    if (NSContainsRect(visibleRect, aRect) == NO) {
        
        CGFloat heightDifference = NSHeight(visibleRect) - NSHeight(aRect);
        if (heightDifference > 0) {
            // scroll to a rect equal in height to the visible rect but centered on the selected rect
            aRect = NSInsetRect(aRect, 0.0, -(heightDifference / 2.0));
        } else {
            // force the top of the selectionRect to the top of the view
            aRect.size.height = NSHeight(visibleRect);
        }
        didScroll = [super scrollRectToVisible:aRect];
    }
    return didScroll;
}  

- (IBAction)selectPreviousIcon:(id)sender;
{
    NSUInteger curIdx = [_selectionIndexes firstIndex];
    NSUInteger previous = NSNotFound, numIcons = [self numberOfIcons];
    
    if (numIcons > 0) {
        if (NSNotFound != curIdx && curIdx > 0)
            previous = curIdx - 1;
        else
            previous = numIcons - 1;
        
        [self scrollItemAtIndexToVisible:previous];
        [self _setSelectionIndexes:[NSIndexSet indexSetWithIndex:previous]];
    }
}

- (IBAction)selectNextIcon:(id)sender;
{
    NSUInteger curIdx = [_selectionIndexes lastIndex];
    NSUInteger next = NSNotFound, numIcons = [self numberOfIcons];
    
    if (numIcons > 0) {
        if (NSNotFound != curIdx && curIdx + 1 < numIcons) 
            next = curIdx + 1;
        else
            next = 0;
        
        [self scrollItemAtIndexToVisible:next];
        [self _setSelectionIndexes:[NSIndexSet indexSetWithIndex:next]];
    }
}

- (IBAction)revealInFinder:(id)sender
{
    [[NSWorkspace sharedWorkspace] selectFile:[[[self _selectedURLs] lastObject] path] inFileViewerRootedAtPath:@""];
}

- (IBAction)openSelectedURLs:(id)sender
{
    [self _openURLs:[self _selectedURLs]];
}

- (IBAction)zoomIn:(id)sender;
{
    [self _setIconScale:fmin([self maxIconScale], [self iconScale] * sqrt(2.0))];
}

- (IBAction)zoomOut:(id)sender;
{
    [self _setIconScale:fmax([self minIconScale], [self iconScale] * sqrt(0.5))];
}

- (IBAction)displayGrid:(id)sender;
{
    [self _setDisplayMode:FVDisplayModeGrid];
}

- (IBAction)displayColumn:(id)sender;
{
    [self _setDisplayMode:FVDisplayModeColumn];
}

- (IBAction)displayRow:(id)sender;
{
    [self _setDisplayMode:FVDisplayModeRow];
}

- (IBAction)previewAction:(id)sender;
{
    if (_fvFlags.controllingSharedPreviewer || _fvFlags.controllingQLPreviewPanel) {
        [self _stopPreviewing];
    }
    else if ([_selectionIndexes count] == 1) {
        NSUInteger r, c;
        [self _getGridRow:&r column:&c ofIndex:[_selectionIndexes lastIndex]];
        [self _previewURL:[[self _selectedURLs] lastObject] forIconInRect:[self _rectOfIconInRow:r column:c]];
    }
    else {
        [self _previewURLs:[self _selectedURLs]];
    }
}

- (IBAction)delete:(id)sender;
{
    if (NO == [self isEditable] || NO == [[self dataSource] fileView:self deleteURLsAtIndexes:[[_selectionIndexes retain] autorelease]])
        NSBeep();
    else
        [self reloadIcons];
}

- (IBAction)selectAll:(id)sender;
{
    [self _setSelectionIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfIcons])]];
}

- (IBAction)deselectAll:(id)sender;
{
    [self _setSelectionIndexes:[NSIndexSet indexSet]];
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

- (IBAction)reloadSelectedIcons:(id)sender;
{
    [[self iconsAtIndexes:[self selectionIndexes]] makeObjectsPerformSelector:@selector(recache)];
    // ensure consistency between URL and icon, since this will require re-reading the URL from disk/net
    [self reloadIcons];
}

#pragma mark Context menu

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
    NSURL *aURL = [[self _selectedURLs] lastObject];  
    SEL action = [anItem action];
    
    // generally only check this for actions that are dependent on single selection
    BOOL isMissing = [aURL isEqual:[FVIcon missingFileURL]];
    BOOL isEditable = [self isEditable];
    BOOL selectionCount = [_selectionIndexes count];
    
    if (action == @selector(zoomIn:))
        return _fvFlags.displayMode == FVDisplayModeGrid && [self iconScale] < [self maxIconScale];
    else if (action == @selector(zoomOut:))
        return _fvFlags.displayMode == FVDisplayModeGrid && [self iconScale] > [self minIconScale];
    else if (action == @selector(displayGrid:)) {
        [anItem setState:_fvFlags.displayMode == FVDisplayModeGrid ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(displayColumn:)) {
        [anItem setState:_fvFlags.displayMode == FVDisplayModeColumn ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(displayRow:)) {
        [anItem setState:_fvFlags.displayMode == FVDisplayModeRow ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(revealInFinder:))
        return [aURL isFileURL] && [_selectionIndexes count] == 1 && NO == isMissing;
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
        return selectionCount > 1 || ([_selectionIndexes count] == 1 && [aURL isFileURL]);
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
        
        // no effect on menu items with a custom view
        [anItem setState:state];
        return enabled;
    }
    else if (action == @selector(downloadSelectedLink:)) {
        if ([self allowsDownloading]) {
            BOOL alreadyDownloading = [[_downloads valueForKey:@"downloadURL"] containsObject:aURL];
            // don't check reachability; just handle the error if it fails
            return isMissing == NO && isEditable && selectionCount == 1 && [aURL isFileURL] == NO && FALSE == alreadyDownloading;
        } else return NO;
    }
    else if (action == @selector(reloadSelectedIcons:)) {
        return selectionCount > 0;
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
    if (menu && NO == [_selectionIndexes containsIndex:idx])
        [self _setSelectionIndexes:idx == NSNotFound ? [NSIndexSet indexSet] : [NSIndexSet indexSetWithIndex:idx]];

    // remove disabled items and double separators
    i = [menu numberOfItems];
    BOOL wasSeparator = YES;
    while (i--) {
        NSMenuItem *menuItem = [menu itemAtIndex:i];
        if ([menuItem tag] == FVChangeLabelMenuItemTag && [menuItem respondsToSelector:@selector(setView:)])
            [(FVColorMenuView *)[menuItem view] setTarget:self];
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
    FVAPIAssert1(label >=0 && label <= 7, @"invalid label %ld (must be between 0 and 7)", (long)label);
    
    NSArray *selectedURLs = [self _selectedURLs];
    NSUInteger i, iMax = [selectedURLs count];
    for (i = 0; i < iMax; i++)
        [FVFinderLabel setFinderLabel:label forURL:[selectedURLs objectAtIndex:i]];
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
        NSBundle *bundle = [NSBundle bundleForClass:[FVFileView class]];
        
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Quick Look", @"FileView", bundle, @"context menu title") action:@selector(previewAction:) keyEquivalent:@""];
        [anItem setTag:FVQuickLookMenuItemTag];
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Open", @"FileView", bundle, @"context menu title") action:@selector(openSelectedURLs:) keyEquivalent:@""];
        [anItem setTag:FVOpenMenuItemTag];
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Reveal in Finder", @"FileView", bundle, @"context menu title") action:@selector(revealInFinder:) keyEquivalent:@""];
        [anItem setTag:FVRevealMenuItemTag];
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Reload", @"FileView", bundle, @"context menu title") action:@selector(reloadSelectedIcons:) keyEquivalent:@""];
        [anItem setTag:FVReloadMenuItemTag];        
        
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
        
        [sharedMenu addItem:[NSMenuItem separatorItem]];
        
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Grid", @"FileView", bundle, @"context menu title") action:@selector(displayGrid:) keyEquivalent:@""];
        [anItem setTag:FVGridMenuItemTag];
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Column", @"FileView", bundle, @"context menu title") action:@selector(displayColumn:) keyEquivalent:@""];
        [anItem setTag:FVColumnMenuItemTag];
        anItem = [sharedMenu addItemWithTitle:NSLocalizedStringFromTableInBundle(@"Row", @"FileView", bundle, @"context menu title") action:@selector(displayRow:) keyEquivalent:@""];
        [anItem setTag:FVRowMenuItemTag];

    }
    return sharedMenu;
}

#pragma mark Download support

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

- (void)downloadUpdated:(FVDownload *)download
{    
    if (NSURLResponseUnknownLength == [download expectedLength] && NULL == _progressTimer) {
        // runloop will retain this timer, but we'll retain it too and release in -dealloc
        _progressTimer = FVCreateWeakTimerWithTimeInterval(PROGRESS_TIMER_INTERVAL, CFAbsoluteTimeGetCurrent() + PROGRESS_TIMER_INTERVAL, self, @selector(_progressTimerFired:));
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), _progressTimer, kCFRunLoopDefaultMode);
    }
    [self setNeedsDisplay:YES];
}

- (void)download:(FVDownload *)download setDestinationWithSuggestedFilename:(NSString *)filename;
{
    NSString *fullPath = nil;
    if ([[self delegate] respondsToSelector:@selector(fileView:downloadDestinationWithSuggestedFilename:)])
        fullPath = [[[self delegate] fileView:self downloadDestinationWithSuggestedFilename:filename] path];
    
    if (nil == fullPath)
        fullPath = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    
    [download setFileURL:[NSURL fileURLWithPath:fullPath]];
}

- (void)downloadFinished:(FVDownload *)download
{
    NSUInteger idx = [download indexInView];
    NSURL *currentURL = [self URLAtIndex:idx];
    NSURL *downloadURL = [download downloadURL];
    NSURL *dest = [download fileURL];
    // things could have been rearranged since the download was started, so don't replace the wrong one
    if (nil != dest) {
        if (NO == [currentURL isEqual:downloadURL]) {
            idx = [self numberOfIcons];
            while (idx-- > 0) {
                currentURL = [self URLAtIndex:idx];
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
    [_downloads removeObject:download];
    if ([_downloads count] == 0)
        [self _invalidateProgressTimer];
}

- (void)downloadFailed:(FVDownload *)download
{
    [_downloads removeObject:download];
    if ([_downloads count] == 0)
        [self _invalidateProgressTimer];
    [self setNeedsDisplay:YES];
}

- (NSWindow *)downloadWindowForSheet:(FVDownload *)download
{
    return [self window];
}

- (void)_cancelDownloads;
{
    [_downloads makeObjectsPerformSelector:@selector(cancel)];
    [_downloads removeAllObjects];
    [self _invalidateProgressTimer];
    [self setNeedsDisplay:YES];
}

- (void)_downloadURLAtIndex:(NSUInteger)anIndex;
{
    if ([self allowsDownloading]) {
        NSURL *theURL = [self URLAtIndex:anIndex];
        FVDownload *download = [[FVDownload alloc] initWithDownloadURL:theURL indexInView:anIndex];       
        [_downloads addObject:download];
        [download release];
        [download setDelegate:self];
        [download start];
    }
}

- (void)downloadSelectedLink:(id)sender
{
    if ([self allowsDownloading]) {
        // validation ensures that we have a single selection, and that there is no current download with this URL
        NSUInteger selIndex = [_selectionIndexes firstIndex];
        if (NSNotFound != selIndex)
            [self _downloadURLAtIndex:selIndex];
    }
}

#pragma mark Quick Look support

- (void)handlePreviewerWillClose:(NSNotification *)aNote
{
    /*
     Necessary to reset in case of the window close button, which doesn't go through
     our action methods.
     */
    _fvFlags.controllingSharedPreviewer = NO;
}

- (void)_previewURLs:(NSArray *)iconURLs
{
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
    if (_fvFlags.controllingQLPreviewPanel) {
        if ([[FVPreviewer sharedPreviewer] isPreviewing]) {
            [[FVPreviewer sharedPreviewer] stopPreviewing];
        }
        [[QLPreviewPanelClass sharedPreviewPanel] reloadData];
        [[QLPreviewPanelClass sharedPreviewPanel] refreshCurrentPreviewItem];
    }
    else if (QLPreviewPanelClass) {
        if ([[FVPreviewer sharedPreviewer] isPreviewing]) {
            [[FVPreviewer sharedPreviewer] stopPreviewing];
        }
        [[QLPreviewPanelClass sharedPreviewPanel] makeKeyAndOrderFront:nil];        
    }
    else
#endif
    {
        if ([[FVPreviewer sharedPreviewer] isPreviewing] && _fvFlags.controllingSharedPreviewer == NO) {
            [[FVPreviewer sharedPreviewer] stopPreviewing];
        }
        [[FVPreviewer sharedPreviewer] setWebViewContextMenuDelegate:nil];
        [[FVPreviewer sharedPreviewer] previewFileURLs:iconURLs];
        _fvFlags.controllingSharedPreviewer = YES;
    }
}

- (void)_previewURL:(NSURL *)aURL forIconInRect:(NSRect)iconRect
{
    if (Nil == QLPreviewPanelClass || [FVPreviewer useQuickLookForURL:aURL] == NO) {
        iconRect = [self convertRect:iconRect toView:nil];
        iconRect.origin = [[self window] convertBaseToScreen:iconRect.origin];
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
        // note: controllingQLPreviewPanel is only true if QLPreviewPanelClass exists, but clang doesn't know that
        if (_fvFlags.controllingQLPreviewPanel && Nil != QLPreviewPanelClass) {
            iconRect = [[QLPreviewPanelClass sharedPreviewPanel] frame];
            [[QLPreviewPanelClass sharedPreviewPanel] performSelector:@selector(orderOut:) withObject:nil afterDelay:0.0];
        }
#endif
        if ([[FVPreviewer sharedPreviewer] isPreviewing] && _fvFlags.controllingSharedPreviewer == NO) {
            [[FVPreviewer sharedPreviewer] stopPreviewing];
        }
        [[FVPreviewer sharedPreviewer] setWebViewContextMenuDelegate:[self delegate]];
        [[FVPreviewer sharedPreviewer] previewURL:aURL forIconInRect:iconRect];    
        _fvFlags.controllingSharedPreviewer = YES;
    }
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
    else if (_fvFlags.controllingQLPreviewPanel) {
        if ([[FVPreviewer sharedPreviewer] isPreviewing]) {
            [[FVPreviewer sharedPreviewer] stopPreviewing];
        }
        [[QLPreviewPanelClass sharedPreviewPanel] reloadData];
        [[QLPreviewPanelClass sharedPreviewPanel] refreshCurrentPreviewItem];
    }
    else {
        if ([[FVPreviewer sharedPreviewer] isPreviewing]) {
            [[FVPreviewer sharedPreviewer] stopPreviewing];
        }
        [[QLPreviewPanelClass sharedPreviewPanel] makeKeyAndOrderFront:nil]; 
    }
#endif
}

- (void)_stopPreviewing
{
    if ([[FVPreviewer sharedPreviewer] isPreviewing]) {
        [[FVPreviewer sharedPreviewer] stopPreviewing];
    }
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
    else if (_fvFlags.controllingQLPreviewPanel) {
        [[QLPreviewPanelClass sharedPreviewPanel] orderOut:nil];
        [[QLPreviewPanelClass sharedPreviewPanel] setDataSource:nil];
        [[QLPreviewPanelClass sharedPreviewPanel] setDelegate:nil];
    }
#endif
}

- (void)_updatePreviewer
{
    // reload might result in an empty view...
    if ([_selectionIndexes count] == 0) {
        [self _stopPreviewing];
    }
    else if ([_selectionIndexes count] == 1) {
        NSUInteger r, c;
        if ([self _getGridRow:&r column:&c ofIndex:[_selectionIndexes firstIndex]])
            [self _previewURL:[self URLAtIndex:[_selectionIndexes firstIndex]] forIconInRect:[self _rectOfIconInRow:r column:c]];
    }
    else {
        [self _previewURLs:[self _selectedURLs]];
    }
}

- (BOOL)_tryToPerform:(SEL)aSelector inViewAndDescendants:(NSView *)aView
{
    if ([aView isHiddenOrHasHiddenAncestor])
        return NO;
    
    /*
     Since WebView returns YES from tryToPerform:@selector(pageDown:), but actually does nothing,
     we have to find an enclosing scrollview.  This sucks, but it'll at least work for anything
     in FVPreviewer.
     */
    if ([aView enclosingScrollView] && [[aView enclosingScrollView] tryToPerform:aSelector with:nil])
        return YES;
    
    NSEnumerator *subviewEnum = [[aView subviews] objectEnumerator];
    while ((aView = [subviewEnum nextObject]) != nil) {
        if ([aView isHiddenOrHasHiddenAncestor])
            continue;
        if ([self _tryToPerform:aSelector inViewAndDescendants:aView])
            return YES;
    }
    return NO;
}

- (void)doCommandBySelector:(SEL)aSelector
{
    NSWindow *previewWindow = nil;
    
    if (aSelector == @selector(pageUp:) || aSelector == @selector(pageDown:)) {
        /*
         When you show a Quick Look panel in Finder, arrow keys control Finder icon navigation,
         but page up/page down control the Quick Look panel.  Since the QL panel actually appears
         to intercept pageUp:/pageDown: without sending them to the delegate, this code is 
         currently only called on FVPreviewer.
         
         Implementing pageUp:/pageDown: in FVPreviewer and walking the responder chain
         led to an infinite loop with the PDFView.  Walking subviews is slightly unpleasant, but
         it doesn't (and shouldn't) crash.
         */        
        if ([[FVPreviewer sharedPreviewer] isPreviewing])
            previewWindow = [[FVPreviewer sharedPreviewer] window];
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
        else if (_fvFlags.controllingQLPreviewPanel)
            previewWindow = [QLPreviewPanelClass sharedPreviewPanel];
#endif
    }
    if (previewWindow == nil || [self _tryToPerform:aSelector inViewAndDescendants:[previewWindow contentView]] == NO)
        [super doCommandBySelector:aSelector];
}

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5

// gets sent while doing keyboard navigation when the panel is up
- (BOOL)previewPanel:(QLPreviewPanel *)panel handleEvent:(NSEvent *)event;
{
    /*
     This works fine if navigating icons via the FileView with arrow keys, but breaks
     down when navigating BibDesk's tableview with arrow keys and the QL panel, since in that
     case the delegate should be the table's delegate.  FVPreviewer works better in that case,
     since it doesn't frob the responder chain like QLPreviewPanel.  This is enough of an edge 
     case that it's not worth a great deal of trouble, though.
     */
    if ([event type] == NSKeyDown) {
        [self interpretKeyEvents:[NSArray arrayWithObject:event]];
        return YES;
    }
    return NO;
}

- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel;
{
    return YES;
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel;
{
    _fvFlags.controllingQLPreviewPanel = YES;
    [[QLPreviewPanelClass sharedPreviewPanel] setDataSource:self];
    [[QLPreviewPanelClass sharedPreviewPanel] setDelegate:self];
    [[QLPreviewPanelClass sharedPreviewPanel] reloadData];    
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel;
{
    _fvFlags.controllingQLPreviewPanel = NO;
    [[QLPreviewPanelClass sharedPreviewPanel] setDataSource:nil];
    [[QLPreviewPanelClass sharedPreviewPanel] setDelegate:nil];
}

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel;
{
    return [[self _selectedURLs] count];
}

- (id <QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)idx;
{
    return [[self _selectedURLs] objectAtIndex:idx];
}

- (NSRect)previewPanel:(QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)item;
{
    NSRect iconRect = NSZeroRect;
    NSUInteger r, c, i = [_orderedURLs indexOfObject:item];
    if (i != NSNotFound && [self _getGridRow:&r column:&c ofIndex:i]) {
        iconRect = [self _rectOfIconInRow:r column:c];
        iconRect = [self convertRect:iconRect toView:nil];
        iconRect.origin = [[self window] convertBaseToScreen:iconRect.origin];
    }
    return iconRect;
}

- (NSImage *)previewPanel:(QLPreviewPanel *)panel transitionImageForPreviewItem:(id <QLPreviewItem>)item contentRect:(NSRect *)contentRect {
    NSImage *image = nil;
    NSUInteger i = [_orderedURLs indexOfObject:item];
    if (i != NSNotFound) {
        NSRect iconRect = NSMakeRect(0.0, 0.0, ceil(_iconSize.width), ceil(_iconSize.height));
        image = [[[NSImage alloc] initWithSize:iconRect.size] autorelease];
        [image lockFocus];
        [[self iconAtIndex:i] drawInRect:iconRect ofContext:[[NSGraphicsContext currentContext] graphicsPort]];
        [image unlockFocus];
    }
    return image;
}

#endif

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
        NSUInteger i = [_selectionIndexes firstIndex];
        while (i != NSNotFound) {
            [children addObject:[FVAccessibilityIconElement elementWithIndex:i parent:self]];
            i = [_selectionIndexes indexGreaterThanIndex:i];
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
    NSUInteger i = [_selectionIndexes firstIndex];
    if (i != NSNotFound)
        return [[FVAccessibilityIconElement elementWithIndex:i parent:self] accessibilityFocusedUIElement];
    else
        return NSAccessibilityUnignoredAncestor(self);
}

- (NSURL *)URLForIconElement:(FVAccessibilityIconElement *)element {
    return [self URLAtIndex:[element index]];
}

- (NSRect)screenRectForIconElement:(FVAccessibilityIconElement *)element {
    NSRect rect = NSZeroRect;
    NSUInteger r, c;
    if ([element index] < [_orderedURLs count] && [self _getGridRow:&r column:&c ofIndex:[element index]]) {
        rect = [self _rectOfIconInRow:r column:c];
        rect = [self convertRect:rect toView:nil];
        rect.origin = [[self window] convertBaseToScreen:rect.origin];
    }
    return rect;
}

- (BOOL)isIconElementSelected:(FVAccessibilityIconElement *)element {
    return [[self selectionIndexes] containsIndex:[element index]];
}

- (void)setSelected:(BOOL)selected forIconElement:(FVAccessibilityIconElement *)element {
    NSUInteger i = [element index];
    if (i >= [_orderedURLs count])
        return;
    if (selected) {
        [self _setSelectionIndexes:[NSIndexSet indexSetWithIndex:i]];
    } else if ([[self selectionIndexes] containsIndex:i]) {
        NSMutableIndexSet *indexes = [[self selectionIndexes] mutableCopy];
        [indexes removeIndex:i];
        [self _setSelectionIndexes:indexes];
        [indexes release];
    }
}

- (void)openIconElement:(FVAccessibilityIconElement *)element {
    if ([element index] < [_orderedURLs count])
        [self _openURLs:[NSArray arrayWithObjects:[self URLAtIndex:[element index]], nil]];
}

@end

#pragma mark -

@implementation _FVURLInfo

- (id)initWithURL:(NSURL *)aURL;
{
    if (self = [super init]) {
        if ([aURL isFileURL]) {
            CFStringRef name;
            if (noErr != LSCopyDisplayNameForURL((CFURLRef)aURL, &name))
                _name = [[[aURL path] lastPathComponent] copyWithZone:[self zone]];
            else
                _name = (NSString *)name;
        } else {
            NSString *name = [aURL absoluteString];
            NSRange range = [name rangeOfString:@"://"];
            if (range.location != NSNotFound)
                name = [name substringFromIndex:NSMaxRange(range)];
            _name = [[name stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] copyWithZone:[self zone]];
        }
        _label = [FVFinderLabel finderLabelForURL:aURL];
    }
    return self;
}

- (void)dealloc
{
    [_name release];
    [super dealloc];
}

- (NSString *)name { return _name; }

- (NSUInteger)label { return _label; }

@end

#pragma mark -

@implementation _FVControllerFileKey

/* 
 NOTE: the following applies only to the SuperFastHash function and the
 macros it uses.
 
 By Paul Hsieh (C) 2004, 2005.  Covered under the Paul Hsieh derivative 
 license. See: 
 http://www.azillionmonkeys.com/qed/weblicense.html for license details.
 
 http://www.azillionmonkeys.com/qed/hash.html 
 */

#undef get16bits
#if (defined(__GNUC__) && defined(__i386__)) || defined(__WATCOMC__) \
|| defined(_MSC_VER) || defined (__BORLANDC__) || defined (__TURBOC__)
#define get16bits(d) (*((const uint16_t *) (d)))
#endif

#if !defined (get16bits)
#define get16bits(d) ((((uint32_t)(((const uint8_t *)(d))[1])) << 8)\
+(uint32_t)(((const uint8_t *)(d))[0]) )
#endif

static uint32_t SuperFastHash (const char * data, int len) {
    uint32_t hash = 0, tmp;
    int rem;
    
	if (len <= 0 || data == NULL) return 0;
    
	rem = len & 3;
	len >>= 2;
    
	/* Main loop */
	for (;len > 0; len--) {
		hash  += get16bits (data);
		tmp    = (get16bits (data+2) << 11) ^ hash;
		hash   = (hash << 16) ^ tmp;
		data  += 2*sizeof (uint16_t);
		hash  += hash >> 11;
	}
    
	/* Handle end cases */
	switch (rem) {
		case 3:	hash += get16bits (data);
            hash ^= hash << 16;
            hash ^= data[sizeof (uint16_t)] << 18;
            hash += hash >> 11;
            break;
		case 2:	hash += get16bits (data);
            hash ^= hash << 11;
            hash += hash >> 17;
            break;
		case 1: hash += *data;
            hash ^= hash << 10;
            hash += hash >> 1;
	}
    
	/* Force "avalanching" of final 127 bits */
	hash ^= hash << 3;
	hash += hash >> 5;
	hash ^= hash << 4;
	hash += hash >> 17;
	hash ^= hash << 25;
	hash += hash >> 6;
    
	return hash;
}

+ (id)newWithURL:(NSURL *)aURL
{
    return [[self allocWithZone:[self zone]] initWithURL:aURL];
}

/*
 Has to be path-based, since we can't guarantee that device/inode will remain
 the same after a file is modified.  This is unfortunate, since path-based
 comparisons are inherently slow.
 */

- (id)initWithURL:(NSURL *)aURL
{
    NSParameterAssert([aURL isFileURL]);
    self = [super init];
    if (self) {
        
        CFStringRef absolutePath = CFURLCopyFileSystemPath((CFURLRef)aURL, kCFURLPOSIXPathStyle);
        NSUInteger maxLen = CFStringGetMaximumSizeOfFileSystemRepresentation(absolutePath);
        _filePath = NSZoneMalloc(NSDefaultMallocZone(), maxLen);
        CFStringGetFileSystemRepresentation(absolutePath, _filePath, maxLen);        
        CFRelease(absolutePath);

        _hash = SuperFastHash(_filePath, strlen(_filePath));

        int err;
        
       /*
        getattrlist values are always 4-byte aligned, so we have to force that
        in order to avoid crashing on x86_64.
         
        NB: #pragma pack(push, 4) worked with gcc, but fails with with llvm
        in Xcode 4.3.
         
        http://code.google.com/p/fileview/issues/detail?id=4
         
        */
       struct _mod_time_buf {
           uint32_t        len;
           struct timespec ts;
       } __attribute__((aligned(4), packed));
       typedef struct _mod_time_buf mod_time_buf;
        
       mod_time_buf mtb;
        
       /*
        Try to use getattrlist() first, since we can explicitly request the desired
        attributes, instead of getting them all from stat().  Fall back to stat() in
        case getattrlist() isn't supported, though.
        */
       struct attrlist alist;
       memset(&alist, 0, sizeof(alist));
       alist.bitmapcount = ATTR_BIT_MAP_COUNT;
       alist.commonattr = ATTR_CMN_MODTIME;
       err = getattrlist(_filePath, &alist, &mtb, sizeof(mod_time_buf), 0);
       if (noErr == err) {
           assert(mtb.len == sizeof(mod_time_buf));
           _mtimespec = mtb.ts;
       }
       else if (ENOTSUP == err) {
            
           struct stat sb;
           err = stat(_filePath, &sb);
            
           if (noErr == err)
               _mtimespec = sb.st_mtimespec;
       }
	           
    }
    return self;
}

- (void)dealloc
{
    NSZoneFree(NSDefaultMallocZone(), _filePath);
    [super dealloc];
}

- (NSString *)description { return [NSString stringWithFormat:@"%@: %s", [super description], _filePath]; }

- (id)copyWithZone:(NSZone *)aZone
{
    return [self retain];
}

- (BOOL)isEqual:(_FVControllerFileKey *)other
{
    if ([other isKindOfClass:[self class]] == NO)
        return NO;

    return strcmp(_filePath, other->_filePath) == 0;
}

- (NSUInteger)hash { return _hash; }

@end

#pragma mark -

@implementation FVAnimation

- (void)setCurrentProgress:(NSAnimationProgress)progress {
    [super setCurrentProgress:progress];
    if ([[self delegate] respondsToSelector:@selector(animation:didReachProgress:)])
        [[self delegate] animation:self didReachProgress:progress];
}

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
- (id <FVAnimationDelegate>)delegate { return (id <FVAnimationDelegate>)[super delegate]; }
- (void)setDelegate:(id <FVAnimationDelegate>)newDelegate { [super setDelegate:newDelegate]; }
#endif

@end

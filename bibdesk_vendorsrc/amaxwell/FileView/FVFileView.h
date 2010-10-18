//
//  FVFileView.h
//  FileView
//
//  Created by Adam Maxwell on 06/23/07.
/*
 This software is Copyright (c) 2007-2010
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

#import <Cocoa/Cocoa.h>

enum {
    FVZoomInMenuItemTag      = 1001,
    FVZoomOutMenuItemTag     = 1002,
    FVGridMenuItemTag        = 1003,
    FVColumnMenuItemTag      = 1004,
    FVRowMenuItemTag         = 1005,
    FVQuickLookMenuItemTag   = 1006,
    FVOpenMenuItemTag        = 1007,
    FVRevealMenuItemTag      = 1008,
    FVChangeLabelMenuItemTag = 1009,
    FVDownloadMenuItemTag    = 1010,
    FVRemoveMenuItemTag      = 1011,
    FVReloadMenuItemTag      = 1012 
};

enum {
    FVDropOn,
    FVDropBefore,
    FVDropAfter
};
typedef NSUInteger FVDropOperation;

enum {
    FVDisplayModeGrid,
    FVDisplayModeColumn,
    FVDisplayModeRow
};
typedef NSInteger FVDisplayMode;


@class FVFileView;

/** Formal protocol for datasources.
 
 An object passed to FVFileView::setDataSource: must implement all required methods.  Results are cached internally on each call to FVFileView::reloadIcons, so datasource methods don't need to be incredibly efficient (so long as you avoid gratuitous calls to FVFileView::reloadIcons).  However, the view's internal cache requests all values when FVFileView::reloadIcons is called, not just visible rows/columns.  
 */
@protocol FVFileViewDataSource <NSObject>

/** Required.
 
 Return the current number of icons provided by your datasource.
 
 @param aFileView The view requesting information
 */
- (NSUInteger)numberOfURLsInFileView:(FVFileView *)aFileView;

/** Required.
 
 The datasource must return an NSURL for each index < numberOfFiles.
 
 @param aFileView The view requesting information
 @param anIndex The requested index (row-major ordered)
 @return An NSURL instance or nil/NSNull for a missing file.
 */
- (NSURL *)fileView:(FVFileView *)aFileView URLAtIndex:(NSUInteger)anIndex;

@optional

/** Optional.  
 
 String displayed below the URL name.  If you're using bindings and need a subtitle, you need to implement this method (and add dummy implementations of the required methods).  Either way, values are cached.
 
 @param aFileView The view requesting information
 @param anIndex The requested index (row-major ordered)
 @return NSString instance
 */
- (NSString *)fileView:(FVFileView *)aFileView subtitleAtIndex:(NSUInteger)anIndex;

/** Datasource must implement all of these methods or dropping/rearranging will be disabled.  
 */

/** Implement to do something (or nothing) with the dropped URLs
 */
- (void)fileView:(FVFileView *)aFileView insertURLs:(NSArray *)absoluteURLs atIndexes:(NSIndexSet *)aSet forDrop:(id <NSDraggingInfo>)info dropOperation:(FVDropOperation)operation;

/** The datasource may replace the files at the given indexes
 @return YES if the replacement occurred.
 */
- (BOOL)fileView:(FVFileView *)aFileView replaceURLsAtIndexes:(NSIndexSet *)aSet withURLs:(NSArray *)newURLs forDrop:(id <NSDraggingInfo>)info dropOperation:(FVDropOperation)operation;

/** Rearranging files in the view
 @return YES if the rearrangement occurred.
 */
- (BOOL)fileView:(FVFileView *)aFileView moveURLsAtIndexes:(NSIndexSet *)aSet toIndex:(NSUInteger)anIndex forDrop:(id <NSDraggingInfo>)info dropOperation:(FVDropOperation)operation;

/** Does not delete the file from disk; this is the datasource's responsibility
 @return YES if the deletion occurred.
 */
- (BOOL)fileView:(FVFileView *)aFileView deleteURLsAtIndexes:(NSIndexSet *)indexSet;

@end

/** Formal protocol for delegates.
 
 The delegate object may implement any or all of these methods to modify the the view's default behavior.  In addition, the delegate can be sent the WebUIDelegate method webView:contextMenuItemsForElement:defaultMenuItems: if implemented.
 */
@protocol FVFileViewDelegate <NSObject>

@optional

/** Allows modification of the contextual menu.
 
 Called immediately before display; the delegate can safely modify the menu, as a new copy is presented each time.   The anIndex parameter will be NSNotFound if there is not a URL at the mouse event location.  If you remove all items, the menu will not be shown.
 
 @param aFileView The requesting view
 @param aMenu The menu that will be displayed
 @param anIndex The index of the selected item
 */
- (void)fileView:(FVFileView *)aFileView willPopUpMenu:(NSMenu *)aMenu onIconAtIndex:(NSUInteger)anIndex;

/** Allows ignoring the default open handler.
 
 If unimplemented or returns YES, fileview will open the URL using NSWorkspace.  You can return NO to open the URL yourself, for instance if you override the user's default application for a file type.
 
 @param aFileView The requesting view
 @param aURL The URL to open
 @return YES to allow FileView to open the URL
 */
- (BOOL)fileView:(FVFileView *)aFileView shouldOpenURL:(NSURL *)aURL;

/** For download and replace of selection.
 
 If unimplemented or returns nil, FileView will use a system temporary directory.  If a file currently exists at the returned URL, it may be overwritten.  Used with FileView::FVDownloadMenuItemTag context menu item.
 
 @param aFileView The requesting view
 @param filename The suggested filename, which may be incorporated into the returned URL
 @return The URL to write the download data to, or nil to use a temporary file.
 */
- (NSURL *)fileView:(FVFileView *)aFileView downloadDestinationWithSuggestedFilename:(NSString *)filename;

/** Allows modification of the current drag operation.
 
 Called during a drop operation to validate the drop.   You can call FVFileView::setDropIndex:dropOperation: to change the index and/or operation for the drop.
 
 @param aFileView The requesting view
 @param info The dragging info for the drop
 @param proposedIndex The proposedindex for the drop
 @param proposedDropOperation The proposed drop operation for the drop
 @param proposedDragOperation The propsed drag operation for the drop; this will be returned when this method is not implemented.
 */
- (NSDragOperation)fileView:(FVFileView *)aFileView validateDrop:(id <NSDraggingInfo>)info proposedIndex:(NSUInteger)anIndex proposedDropOperation:(FVDropOperation)dropOperation proposedDragOperation:(NSDragOperation)dragOperation;

@end


@class FVSliderWindow, FVOperationQueue;

/**
 FVFileView is the primary class in the framework.  
 
 FVFileView is an NSView subclass that provides automatic layout of icons, and handles update queueing transparently.  The data source may be an NSArrayController (via the view's Content binding), or an object that implements the @link <FVFileViewDataSource> @endlink formal protocol.  If the view is to be a drag-and-drop destination, the datasource must implement the dragging related methods in the @link <FVFileViewDataSource> @endlink formal protocol.
 
 @see @link NSObject(FVFileViewDataSource) @endlink
 */
@interface FVFileView : NSView 
{
@private
    id<FVFileViewDelegate>   _delegate;
    id<FVFileViewDataSource> _dataSource;
    NSMutableArray          *_orderedIcons;
    NSMutableArray          *_orderedURLs;
    NSMutableArray          *_orderedSubtitles;
    NSMutableDictionary     *_iconCache;
    NSMutableDictionary     *_zombieIconCache;
    CFMutableDictionaryRef   _infoTable;
    NSUInteger               _numberOfColumns;
    NSUInteger               _numberOfRows;
    NSColor                 *_backgroundColor;
    CFRunLoopTimerRef        _zombieTimer;
    NSMutableIndexSet       *_selectionIndexes;
    CGLayerRef               _selectionOverlay;
    NSUInteger               _lastClickedIndex;
    NSUInteger               _dropIndex;
    NSRect                   _rubberBandRect;
    struct __fvFlags {
        unsigned int displayMode:2;
        unsigned int dropOperation:2;
        unsigned int isEditable:1;
        unsigned int isMouseDown:1;
        unsigned int isRescaling:1;
        unsigned int scheduledLiveResize:1;
        unsigned int updatingFromSlider:1;
        unsigned int hasArrows:1;
    } _fvFlags;
    NSSize                   _padding;
    NSSize                   _iconSize;
    double                   _minScale;
    double                   _maxScale;
    NSPoint                  _lastMouseDownLocInView;
    CFAbsoluteTime           _timeOfLastOrigin;
    NSPoint                  _lastOrigin;
    NSTextFieldCell         *_titleCell;
    NSTextFieldCell         *_subtitleCell;
    CFMutableDictionaryRef   _trackingRectMap;
    NSButtonCell            *_leftArrow;
    NSButtonCell            *_rightArrow;
    NSRect                   _leftArrowFrame;
    NSRect                   _rightArrowFrame;
    CGFloat                  _arrowAlpha;
    NSAnimation             *_arrowAnimation;
    FVSliderWindow          *_sliderWindow;
    NSTrackingRectTag        _topSliderTag;
    NSTrackingRectTag        _bottomSliderTag;
    FVOperationQueue        *_operationQueue;
    NSDictionary            *_contentBinding;
    NSMutableArray          *_downloads;
    CFRunLoopTimerRef        _progressTimer;
    NSMutableSet            *_modificationSet;
    NSLock                  *_modificationLock;
    NSArray                 *_iconURLs;
}

/** The icon URLs.
 
 This property is KVO-compliant and supports Cocoa bindings.*/
- (NSArray *)iconURLs;

/** Set the icon URLs.
 
  This property is KVO-compliant and supports Cocoa bindings.
 
 @param anArray Must not be nil.  Pass an empty NSArray to clear selection.*/
- (void)setIconURLs:(NSArray *)anArray;

/** Currently selected indexes.
 
 This property is KVO-compliant and supports Cocoa bindings.  Indexes are numbered in ascending order order from left to right, top to bottom (row-major order).*/
- (NSIndexSet *)selectionIndexes;

/** Set current selection indexes.
 
  This property is KVO-compliant and supports Cocoa bindings.  Indexes are numbered in ascending order order from left to right, top to bottom (row-major order).
 
 @param indexSet Must not be nil.  Pass an empty NSIndexSet to clear selection.*/
- (void)setSelectionIndexes:(NSIndexSet *)indexSet;

/** The current icon scale of the view.
 
 This property has no physical meaning; it's proportional to internal constants which determine the cached sizes of icons.  Can be bound.*/
- (double)iconScale;

/** Set the current icon scale.
 @param scale The new value of FVFileView::iconScale. */
- (void)setIconScale:(double)scale;

/** Maximum value of iconScale
 
 Default value is 16.  Legitimate values are from 0.01 -- 100 in IB, but this is not enforced in the view (i.e. you can set anything programmatically).  Can be bound.*/
- (double)maxIconScale;

/** Set maximum value of iconScale
 
 Legitmate values are from 0.01 -- 100 in IB, but this is not enforced in the view (i.e. you can set anything programmatically).  Can be bound.
 @param scale The new value of FileView::maxIconScale. */
- (void)setMaxIconScale:(double)scale;

/** Minimum value of iconScale
 
 Default value is 0.5.  Legitmate values are from 0.01 -- 100 in IB, but this is not enforced in the view (i.e. you can set anything programmatically).  Can be bound. */
- (double)minIconScale;

/** Set minimum value of iconScale

 Legitmate values are from 0.01 -- 100 in IB, but this is not enforced in the view (i.e. you can set anything programmatically).  Can be bound.
 @param scale The new value of FileView::minIconScale. */
- (void)setMinIconScale:(double)scale;

/** Whether the icons scale are ordered in a grid or a single auto-scaled column or row.
 
 When this is not set to FVDisplayModeGrid, setIconScale: will be ignored, and the view shows the icons in a single column or row with a scale determined by the current width or height of the view.  Can be bound.*/
- (FVDisplayMode)displayMode;

/** Set whether the icons are ordered in a grid or a single auto-scaled column or row.
 @param mode The new value of FVFileView::displayMode. */
- (void)setDisplayMode:(FVDisplayMode)mode;

/** Current number of rows displayed.*/
- (NSUInteger)numberOfRows;

/** Current number of columns displayed.*/
- (NSUInteger)numberOfColumns;

/** Whether the view can be edited.
 
 Can be bound.*/
- (BOOL)isEditable;

/** Change the view's editable property.
 
 Default is NO for views created in code.  Can be bound.
 
 @param flag If set to YES, requires the datasource to implement the dragging related methods in the @link <FVFileViewDataSource> @endlink formal protocol.  If set to NO, drop/paste/delete actions will be ignored, even if the protocol is implemented.  */
- (void)setEditable:(BOOL)flag;

/** Whether the view allows downloading URLs.
 
 Can be bound.*/
- (BOOL)allowsDownloading;

/** Change the view's allowsDownloading property.
 
 Default is NO for views created in code.  Can be bound.
 
 @param flag If set to YES, a contextual download menu item is added for external URLs, and external URLs dropped while holding the Option key will be automatically downloaded.  */
- (void)setAllowsDownloading:(BOOL)flag;

/** The current background color.
 
 The default is NSOutlineView's source list color, or an approximation thereof on 10.4.  Can be bound. */
- (NSColor *)backgroundColor;

/** Change the background color.
 
 The default is NSOutlineView's source list color, or an approximation thereof on 10.4.  Can be bound.
 @param aColor The new background color. */
- (void)setBackgroundColor:(NSColor *)aColor;

/** The current text color.
 
 The default is +[NSColor darkGrayColor].  Can be bound. */
- (NSColor *)textColor;

/** Change the text color.
 
 The default is +[NSColor darkGrayColor].  Can be bound.
 @param aColor The new text color. */
- (void)setTextColor:(NSColor *)aColor;

/** The current subtitle color.
 
 The default is +[NSColor grayColor].  Can be bound. */
- (NSColor *)subtitleColor;

/** Change the subtitle color.
 
 The default is +[NSColor grayColor].  Can be bound.
 @param aColor The new subtitle color. */
- (void)setSubtitleColor:(NSColor *)aColor;

/** The current text font.
 
 The default is the system font at 12pt.  Can be bound. */
- (NSFont *)font;

/** Change the text font.
 
 The default is the system font at 12pt.  Can be bound.
 @param aFont The new text font. */
- (void)setFont:(NSFont *)aFont;

/** The current subtitle font.
 
 The default is the system font at 10pt.  Can be bound. */
- (NSFont *)subtitleFont;

/** Change the subtitle font.
 
 The default is the system font at 10pt.  Can be bound.
 @param aFont The new subtitle font. */
- (void)setSubtitleFont:(NSFont *)aFont;

/** Invalidates all content and marks view for redisplay.
 
 This must be called if the URLs provided by a datasource change, either in number or content, unless the Content binding is used.  May be fairly expensive if your datasource is slow, since it requests all values (unlike NSTableView).  Icon data such as bitmaps will be generated lazily as needed, however, and is also persistent for the life of the application.*/
- (void)reloadIcons;

/** Selects the previous icon in row-major order.*/
- (IBAction)selectPreviousIcon:(id)sender;

/** Selects the previous icon in row-major order.*/
- (IBAction)selectNextIcon:(id)sender;

/** Deletes the selected icon(s).
 
 Requires implementation of the dragging related @link <FVFileViewDataSource> @endlink formal protocol methods.  If the view is editable, it sends  <FVFileViewDataSource>::fileView:deleteURLsAtIndexes: to the datasource object, which can then handle the action as needed.
 
 @see @link <FVFileViewDataSource> @endlink
 @see setEditable: */
- (IBAction)delete:(id)sender;

/** Invalidates existing cached data.
 
 Invalidates any cached bitmaps for the selected icons and marks the view for redisplay.*/
- (IBAction)reloadSelectedIcons:(id)sender;

/** Change Finder label color for selected icons.
 
 Changes the Finder label color for the current selection.  Non-file: URLs and nonexistent files are ignored.
 
 @param sender Must implement -tag to return a valid Finder label integer (0--7).  Typically an NSMenuItem.
 */
- (IBAction)changeFinderLabel:(id)sender;

/** Opens the selected items using the default application.
 
 Wraps -[NSWorkspace openURL:].*/
- (IBAction)openSelectedURLs:(id)sender;

/** Receiver forFileViewDataSource and @link <FVFileViewDataSource> @endlink messages.
 
 A non-nil datasource is required for drag-and-drop support.
 
 @param obj Nonretained, and may be set to nil.
 @see @link <FVFileViewDataSource> @endlink */
- (void)setDataSource:(id<FVFileViewDataSource>)obj;

/** Current datasource or nil.*/
- (id<FVFileViewDataSource>)dataSource;

/** Set a delegate for the view.
 
 The delegate may implement any or all of the methods in the @link NSObject(FileViewDelegate) @endlink informal protocol.
 
 @param obj The object to set as delegate.  Not retained.*/
- (void)setDelegate:(id<FVFileViewDelegate>)obj;

/** Returns the current delegate or nil.*/
- (id<FVFileViewDelegate>)delegate;

/** Change drop index and drop operation for a drop on the view.
 
 This can be used in the @link <FVFileViewDelegate> @endlink drop validation method to change the drop index or drop operation.
 
 @param anIndex The new drop index.
 @param anOperation The new drop operation.  */
- (void)setDropIndex:(NSUInteger)anIndex dropOperation:(FVDropOperation)anOperation;

@end

/** @var FVZoomInMenuItemTag 
 Zoom in by @f$\sqrt 2@f$
 */
/** @var FVZoomOutMenuItemTag 
 Zoom out by @f$\sqrt 2@f$
 */
/** @var FVZoomGridMenuItemTag 
 Display icons in a grid
 */
/** @var FVZoomColumnMenuItemTag 
 Display icons in a single column
 */
/** @var FVZoomRowMenuItemTag 
 Display icons in a single row
 */
/** @var FVQuickLookMenuItemTag 
 Quick Look 
 */
/** @var FVOpenMenuItemTag 
 Open in Finder 
 */
/** @var FVRevealMenuItemTag 
 Reveal in Finder 
 */
/** @var FVChangeLabelMenuItemTag 
 Change Finder label (color) 
 */
/** @var FVDownloadMenuItemTag 
 Download and replace 
 */
/** @var FVRemoveMenuItemTag 
 Delete from view 
 */
/** @var FVReloadMenuItemTag 
 Recache the selected icon(s) 
 */

/** @var FVDropOn 
 Drop on an icon 
 */
/** @var FVDropBefore 
 Drop before an icon
 */
/** @var FVDropAfter 
 Drop after an icon
 */

/** @var FVDisplayModeGrid 
 Display icons in a grid with the specified scale
 */
/** @var FVDisplayModeColumn 
 Display icons in a single column fit to the width
 */
/** @var FVDisplayModeRow 
 Display icons in a single row fit to the height
 */

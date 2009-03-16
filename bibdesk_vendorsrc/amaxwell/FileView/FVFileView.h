//
//  FVFileView.h
//  FileView
//
//  Created by Adam Maxwell on 06/23/07.
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

#import <Cocoa/Cocoa.h>

enum {
    FVZoomInMenuItemTag = 1001,
    FVZoomOutMenuItemTag = 1002,
    FVAutoScalesMenuItemTag = 1003,
    FVQuickLookMenuItemTag = 1004,
    FVOpenMenuItemTag = 1005,
    FVRevealMenuItemTag = 1006,
    FVChangeLabelMenuItemTag = 1007,
    FVDownloadMenuItemTag    = 1008,
    FVRemoveMenuItemTag = 1009
};

typedef enum _FVDropOperation {
    FVDropOn,
    FVDropBefore,
    FVDropAfter
} FVDropOperation;

@class FVSliderWindow, FVOperationQueue;

/**
 FVFileView is the primary class in the framework.  
 
 FVFileView is an NSView subclass that provides automatic layout of icons, and handles update queueing transparently.  The data source may be an NSArrayController (via the view's Content binding), or an object that implements the @link NSObject(FVFileViewDataSource) @endlink informal protocol.  If the view is to be a drag-and-drop destination, the datasource must implement the @link NSObject(FVFileViewDragDataSource) @endlink informal protocol.
 
 @see @link NSObject(FVFileViewDataSource) @endlink
 @see @link NSObject(FVFileViewDataSource) @endlink
 */
@interface FVFileView : NSView 
{
@private
    id                      _delegate;
    id                      _dataSource;
    NSMutableArray         *_orderedIcons;
    NSMutableArray         *_orderedURLs;
    NSMutableArray         *_orderedSubtitles;
    NSMutableDictionary    *_iconCache;
    CFMutableDictionaryRef  _infoTable;
    NSUInteger              _numberOfColumns;
    NSUInteger              _numberOfRows;
    NSColor                *_backgroundColor;
    CFRunLoopTimerRef       _zombieTimer;
    NSMutableIndexSet      *_selectionIndexes;
    CGLayerRef              _selectionOverlay;
    NSUInteger              _lastClickedIndex;
    NSUInteger              _dropOperation;
    NSUInteger              _dropIndex;
    NSRect                  _rubberBandRect;
    struct __fvFlags {
        unsigned int isMouseDown : 1;
        unsigned int isEditable : 1;
        unsigned int autoScales : 1;
        unsigned int isRescaling: 1;
        unsigned int scheduledLiveResize : 1;
        unsigned int isDrawingDragImage : 1;
        unsigned int updatingFromSlider : 1;
    } _fvFlags;
    NSSize                  _padding;
    NSSize                  _iconSize;
    double                  _minScale;
    double                  _maxScale;
    NSPoint                 _lastMouseDownLocInView;
    CFAbsoluteTime          _timeOfLastOrigin;
    NSPoint                 _lastOrigin;
    CFMutableDictionaryRef  _trackingRectMap;
    NSButtonCell           *_leftArrow;
    NSButtonCell           *_rightArrow;
    NSRect                  _leftArrowFrame;
    NSRect                  _rightArrowFrame;
    FVSliderWindow         *_sliderWindow;
    NSTrackingRectTag       _topSliderTag;
    NSTrackingRectTag       _bottomSliderTag;
    FVOperationQueue       *_operationQueue;
    NSDictionary           *_contentBinding;
    NSMutableArray         *_downloads;
    CFRunLoopTimerRef       _progressTimer;
    NSArray                *_iconURLs;
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

/** Whether the icons scale automatically.
 
 When this is set to YES, setIconScale: will be ignored, and the views shows the icons in a single column with a scale determined by the current width of the view.  Can be bound.*/
- (BOOL)autoScales;

/** Set whether the icons scale automatically.
 @param flag The new value of FVFileView::autoScales. */
- (void)setAutoScales:(BOOL)flag;

/** Current number of rows displayed.*/
- (NSUInteger)numberOfRows;

/** Current number of columns displayed.*/
- (NSUInteger)numberOfColumns;

/** Invalidates all content and marks view for redisplay.
 
 This must be called if the URLs provided by a datasource change, either in number or content, unless the Content binding is used.  May be fairly expensive if your datasource is slow, since it requests all values (unlike NSTableView).  Icon data such as bitmaps will be generated lazily as needed, however, and is also persistent for the life of the application.*/
- (void)reloadIcons;

/** The current background color.
 
 The default is NSOutlineView's source list color, or an approximation thereof on 10.4.  Can be bound. */
- (NSColor *)backgroundColor;

/** Change the background color.
 
 The default is NSOutlineView's source list color, or an approximation thereof on 10.4.  Can be bound.
 @param aColor The new background color. */
- (void)setBackgroundColor:(NSColor *)aColor;

/** Selects the previous icon in row-major order.*/
- (IBAction)selectPreviousIcon:(id)sender;

/** Selects the previous icon in row-major order.*/
- (IBAction)selectNextIcon:(id)sender;

/** Deletes the selected icon(s).
 
 Requires implementation of the @link NSObject(FVFileViewDragDataSource) @endlink informal protocol.  If the view is editable, it sends  NSObject(FVFileViewDragDataSource)::fileView:deleteURLsAtIndexes: to the datasource object, which can then handle the action as needed.
 
 @see @link NSObject(FVFileViewDragDataSource) @endlink
 @see setEditable: */
- (IBAction)delete:(id)sender;

/** Change Finder label color for selected icons.
 
 Changes the Finder label color for the current selection.  Non-file: URLs and nonexistent files are ignored.
 
 @param sender Must implement -tag to return a valid Finder label integer (0--7).  Typically an NSMenuItem.
 */
- (IBAction)changeFinderLabel:(id)sender;

/** Opens the selected items using the default application.
 
 Wraps -[NSWorkspace openURL:].*/
- (IBAction)openSelectedURLs:(id)sender;

/** Whether the view can be edited.
 
 Can be bound.*/
- (BOOL)isEditable;

/** Change the view's editable property.
 
 Default is NO for views created in code.  Can be bound.
 
 @param flag If set to YES, requires the datasource to implement the @link NSObject(FVFileViewDragDataSource) @endlink informal protocol.  If set to NO, drop/paste/delete actions will be ignored, even if the protocol is implemented.  */
- (void)setEditable:(BOOL)flag;

/** Receiver forFileViewDataSource and @link NSObject(FVFileViewDragDataSource) @endlink messages.
 
 A non-nil datasource is required for drag-and-drop support.
 
 @param obj Nonretained, and may be set to nil.
 @see @link NSObject(FVFileViewDataSource) @endlink
 @see @link NSObject(FVFileViewDragDataSource) @endlink */
- (void)setDataSource:(id)obj;

/** Current datasource or nil.*/
- (id)dataSource;

/** Set a delegate for the view.
 
 The delegate may implement any or all of the methods in the @link NSObject(FileViewDelegate) @endlink informal protocol.
 
 @param obj The object to set as delegate.  Not retained.*/
- (void)setDelegate:(id)obj;

/** Returns the current delegate or nil.*/
- (id)delegate;

/** Whether the view allows downloading URLs.
 
 Can be bound.*/
- (BOOL)allowsDownloading;

/** Change the view's allowsDownloading property.
 
 Default is NO for views created in code.  Can be bound.
 
 @param flag If set to YES, a contextual download menu item is added for external URLs, and external URLs dropped while holding the Option key will be automatically downloaded.  */
- (void)setAllowsDownloading:(BOOL)flag;

/** Change drop index and drop operation for a drop on the view.
 
 This can be used in the @link NSObject(FVFileViewDelegate) @endlink drop validation method to change the drop index or drop operation.
 
 @param anIndex The new drop index.
 @param anOperation The new drop operation.  */
- (void)setDropIndex:(NSUInteger)anIndex dropOperation:(FVDropOperation)anOperation;

@end


/** Informal protocol for datasources.
 
 An object passed to FVFileView::setDataSource: must implement all required methods.  Results are cached internally on each call to FVFileView::reloadIcons, so datasource methods don't need to be incredibly efficient (so long as you avoid gratuitous calls to FVFileView::reloadIcons).  However, the view's internal cache requests all values when FVFileView::reloadIcons is called, not just visible rows/columns.  
 */
@interface NSObject (FVFileViewDataSource)

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

/** Optional.  
 
 String displayed below the URL name.  If you're using bindings and need a subtitle, you need to implement this method (and add dummy implementations of the required methods).  Either way, values are cached.
 
 @param aFileView The view requesting information
 @param anIndex The requested index (row-major ordered)
 @return NSString instance
 */
- (NSString *)fileView:(FVFileView *)aFileView subtitleAtIndex:(NSUInteger)anIndex;

@end

/** Informal protocol for datasources.
 
 Datasource must implement all of these methods or dropping/rearranging will be disabled.  
 */
@interface NSObject (FVFileViewDragDataSource)

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

/** Informal protocol for delegates.
 
 The delegate object may implement any or all of these methods to modify the the view's default behavior.  In addition, the delegate can be sent the WebUIDelegate method webView:contextMenuItemsForElement:defaultMenuItems: if implemented.
 */
@interface NSObject (FVFileViewDelegate)

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
 @param draggedURLs The URLs on the pasteboard for the drop
 @param proposedIndex The proposedindex for the drop
 @param proposedDropOperation The proposed drop operation for the drop
 @param proposedDragOperation The propsed drag operation for the drop; this will be returned when this method is not implemented.
 */
- (NSDragOperation)fileView:(FVFileView *)aFileView validateDrop:(id <NSDraggingInfo>)info draggedURLs:(NSArray *)draggedURLs proposedIndex:(NSUInteger)anIndex proposedDropOperation:(FVDropOperation)dropOperation proposedDragOperation:(NSDragOperation)dragOperation;

@end

/** @var FVZoomInMenuItemTag 
 Zoom in by @f$\sqrt 2@f$
 */
/** @var FVZoomOutMenuItemTag 
 Zoom out by @f$\sqrt 2@f$
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


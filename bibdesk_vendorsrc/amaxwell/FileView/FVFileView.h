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

@interface FVFileView : NSView 
{
@private
    id                      _delegate;
    id                      _dataSource;
    NSMutableDictionary    *_iconCache;
    CFMutableDictionaryRef  _iconIndexMap;
    CFMutableDictionaryRef  _iconURLMap;
    NSUInteger              _numberOfColumns;
    NSUInteger              _numberOfRows;
    NSColor                *_backgroundColor;
    CFRunLoopTimerRef       _zombieTimer;
    NSMutableIndexSet      *_selectedIndexes;
    CGLayerRef              _selectionOverlay;
    NSUInteger              _lastClickedIndex;
    NSUInteger              _dropOperation;
    NSUInteger              _dropIndex;
    NSRect                  _rubberBandRect;
    BOOL                    _isMouseDown;
    NSSize                  _padding;
    NSSize                  _iconSize;
    NSPoint                 _lastMouseDownLocInView;
    BOOL                    _isEditable;
    BOOL                    _isRescaling;
    BOOL                    _isDrawingDragImage;
    BOOL                    _isObservingSelectionIndexes;
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
    
    CFMutableDictionaryRef  _activeDownloads;
    CFRunLoopTimerRef       _progressTimer;
    NSArray                *_iconURLs;
    
    BOOL                    _autoScales;
}

// bindings compatibility, although this can be set directly
- (void)setIconURLs:(NSArray *)anArray;
- (NSArray *)iconURLs;

// this is the only way to get selection information at present
- (NSIndexSet *)selectionIndexes;
- (void)setSelectionIndexes:(NSIndexSet *)indexSet;

// bind a slider or other control to this
- (CGFloat)iconScale;
- (void)setIconScale:(CGFloat)scale;

- (BOOL)autoScales;
- (void)setAutoScales:(BOOL)flag;

- (NSUInteger)numberOfRows;
- (NSUInteger)numberOfColumns;
- (void)reloadIcons;

// default is Mail's source list color
- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)aColor;

// actions that NSResponder doesn't declare
- (IBAction)selectPreviousIcon:(id)sender;
- (IBAction)selectNextIcon:(id)sender;
- (IBAction)delete:(id)sender;

// sender must implement -tag to return a valid Finder label integer (0-7); non-file URLs are ignored
- (IBAction)changeFinderLabel:(id)sender;
- (IBAction)openSelectedURLs:(id)sender;

- (BOOL)isEditable;
- (void)setEditable:(BOOL)flag;

- (void)setDropIndex:(NSUInteger)anIndex dropOperation:(FVDropOperation)anOperation;

// required for drag-and-drop support
- (void)setDataSource:(id)obj;
- (id)dataSource;

- (void)setDelegate:(id)obj;
- (id)delegate;

- (BOOL)allowsDownloading;
- (void)setAllowsDownloading:(BOOL)flag;

@end


// dataSource must conform to this
@interface NSObject (FileViewDataSource)

// delegate must return an NSURL or nil (a missing value) for each index < numberOfFiles
- (NSUInteger)numberOfURLsInFileView:(FVFileView *)aFileView;
- (NSURL *)fileView:(FVFileView *)aFileView URLAtIndex:(NSUInteger)anIndex;

// optional method for a subtitle
- (NSString *)fileView:(FVFileView *)aFileView subtitleAtIndex:(NSUInteger)anIndex;

@end

// datasource must implement all of these methods or dropping/rearranging will be disabled
@interface NSObject (FileViewDragDataSource)

// implement to do something (or nothing) with the dropped URLs
- (void)fileView:(FVFileView *)aFileView insertURLs:(NSArray *)absoluteURLs atIndexes:(NSIndexSet *)aSet forDrop:(id <NSDraggingInfo>)info dropOperation:(FVDropOperation)operation;

// the datasource may replace the files at the given indexes
- (BOOL)fileView:(FVFileView *)aFileView replaceURLsAtIndexes:(NSIndexSet *)aSet withURLs:(NSArray *)newURLs forDrop:(id <NSDraggingInfo>)info dropOperation:(FVDropOperation)operation;

// rearranging files in the view
- (BOOL)fileView:(FVFileView *)aFileView moveURLsAtIndexes:(NSIndexSet *)aSet toIndex:(NSUInteger)anIndex forDrop:(id <NSDraggingInfo>)info dropOperation:(FVDropOperation)operation;

// does not delete the file from disk; this is the datasource's responsibility
- (BOOL)fileView:(FVFileView *)aFileView deleteURLsAtIndexes:(NSIndexSet *)indexSet;

@end

@interface NSObject (FileViewDelegate)

// Called immediately before display.   The anIndex parameter will be NSNotFound if there is not a URL at the mouse event location.  If you remove all items, the menu will not be shown.
- (void)fileView:(FVFileView *)aFileView willPopUpMenu:(NSMenu *)aMenu onIconAtIndex:(NSUInteger)anIndex;

// In addition, it can be sent the WebUIDelegate method webView:contextMenuItemsForElement:defaultMenuItems:

// If unimplemented or returns YES, fileview will open the URL using NSWorkspace
- (BOOL)fileView:(FVFileView *)aFileView shouldOpenURL:(NSURL *)aURL;

// If unimplemented, fileview will use a system temporary directory; if returns nil, cancels download.  Used with FVDownloadMenuItemTag menu item.
- (NSURL *)fileView:(FVFileView *)aFileView downloadDestinationWithSuggestedFilename:(NSString *)filename;

// If unimplemented, uses the proposedDragOperation
- (NSDragOperation)fileView:(FVFileView *)aFileView validateDrop:(id <NSDraggingInfo>)info draggedURLs:(NSArray *)draggedURLs proposedIndex:(NSUInteger)anIndex proposedDropOperation:(FVDropOperation)dropOperation proposedDragOperation:(NSDragOperation)dragOperation;

@end

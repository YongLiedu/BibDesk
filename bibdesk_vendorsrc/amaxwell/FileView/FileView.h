//
//  FileView.h
//  FileViewTest
//
//  Created by Adam Maxwell on 06/23/07.
/*
 This software is Copyright (c) 2007,2008
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

// define here, since this is the only public header for the project
// From NSObjCRuntime.h
#ifndef NSINTEGER_DEFINED
typedef int NSInteger;
typedef unsigned int NSUInteger;
#define NSIntegerMax    LONG_MAX
#define NSIntegerMin    LONG_MIN
#define NSUIntegerMax   ULONG_MAX
#define NSINTEGER_DEFINED 1
#endif /* NSINTEGER_DEFINED */

// From CGBase.h
#ifndef	CGFLOAT_DEFINED
typedef float CGFloat;
#define CGFLOAT_MIN FLT_MIN
#define CGFLOAT_MAX FLT_MAX
#define CGFLOAT_IS_DOUBLE 0
#define CGFLOAT_DEFINED 1
#endif /* CGFLOAT_DEFINED */

#ifndef NSAppKitVersionNumber10_4
#define NSAppKitVersionNumber10_4 824
#endif

enum {
    FVZoomInMenuItemTag = 1001,
    FVZoomOutMenuItemTag = 1002,
    FVQuickLookMenuItemTag = 1003,
    FVOpenMenuItemTag = 1004,
    FVRevealMenuItemTag = 1005    
};

@interface FileView : NSView 
{
@private
    id                      _delegate;
    id                      _dataSource;
    NSMutableDictionary    *_iconCache;
    NSColor                *_backgroundColor;
    CFRunLoopTimerRef       _zombieTimer;
    NSMutableIndexSet      *_selectedIndexes;
    NSUInteger              _lastClickedIndex;
    NSRect                  _rubberBandRect;
    NSRect                  _dropRectForHighlight;
    NSSize                  _padding;
    NSSize                  _iconSize;
    NSPoint                 _lastMouseDownLocInView;
    BOOL                    _isEditable;
    BOOL                    _isRescaling;
    BOOL                    _isDrawingDragImage;
    CFAbsoluteTime          _timeOfLastOrigin;
    NSPoint                 _lastOrigin;
    CFMutableDictionaryRef  _trackingRectMap;
    NSButtonCell           *_leftArrow;
    NSButtonCell           *_rightArrow;
    NSRect                  _leftArrowFrame;
    NSRect                  _rightArrowFrame;
    
    NSArray                *_iconURLs;
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

- (NSUInteger)numberOfRows;
- (NSUInteger)numberOfColumns;
- (void)reloadIcons;

// default is Mail's source list color
- (void)setBackgroundColor:(NSColor *)aColor;

// actions that NSResponder doesn't declare
- (IBAction)selectPreviousIcon:(id)sender;
- (IBAction)selectNextIcon:(id)sender;
- (IBAction)delete:(id)sender;

- (IBAction)openSelectedURLs:(id)sender;

- (BOOL)isEditable;
- (void)setEditable:(BOOL)flag;

// required for drag-and-drop support
- (void)setDataSource:(id)obj;
- (id)dataSource;

- (void)setDelegate:(id)obj;
- (id)delegate;

@end


// dataSource must conform to this
@interface NSObject (FileViewDataSource)

// delegate must return an NSURL or nil (a missing value) for each index < numberOfFiles
- (NSUInteger)numberOfIconsInFileView:(FileView *)aFileView;
- (NSURL *)fileView:(FileView *)aFileView URLAtIndex:(NSUInteger)anIndex;

// optional method for a subtitle
- (NSString *)fileView:(FileView *)aFileView subtitleAtIndex:(NSUInteger)anIndex;

@end

// datasource must implement all of these methods or dropping/rearranging will be disabled
@interface NSObject (FileViewDragDataSource)

// implement to do something (or nothing) with the dropped URLs
- (void)fileView:(FileView *)aFileView insertURLs:(NSArray *)absoluteURLs atIndexes:(NSIndexSet *)aSet;

// the datasource may replace the files at the given indexes
- (BOOL)fileView:(FileView *)aFileView replaceURLsAtIndexes:(NSIndexSet *)aSet withURLs:(NSArray *)newURLs;

// rearranging files in the view
- (BOOL)fileView:(FileView *)aFileView moveURLsAtIndexes:(NSIndexSet *)aSet toIndex:(NSUInteger)anIndex;

// does not delete the file from disk; this is the datasource's responsibility
- (BOOL)fileView:(FileView *)aFileView deleteURLsAtIndexes:(NSIndexSet *)indexSet;

@end

@interface NSObject (FileViewDelegate)

// Called immediately before display.   The anIndex parameter will be NSNotFound if there is not a URL at the mouse event location.  If you remove all items, the menu will not be shown.
- (void)fileView:(FileView *)aFileView willPopUpMenu:(NSMenu *)aMenu onIconAtIndex:(NSUInteger)anIndex;

// In addition, it can be sent the WebUIDelegate method webView:contextMenuItemsForElement:defaultMenuItems:

// If unimplemented or returns YES, fileview will open the URL using NSWorkspace
- (BOOL)fileView:(FileView *)aFileView shouldOpenURL:(NSURL *)aURL;

@end

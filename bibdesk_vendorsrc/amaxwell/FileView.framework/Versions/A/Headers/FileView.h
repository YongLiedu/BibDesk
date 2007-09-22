//
//  FileView.h
//  FileViewTest
//
//  Created by Adam Maxwell on 06/23/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// define here, since this is the only public header for the project
#ifndef NSINTEGER_DEFINED
#define NSUInteger unsigned
#define NSInteger int
#define CGFloat float
#endif

#ifndef NSAppKitVersionNumber10_4
#define NSAppKitVersionNumber10_4 824
#endif

@interface FileView : NSView 
{
@private
    id                      _delegate;
    id                      _dataSource;
    NSMutableDictionary    *_iconCache;
    NSColor                *_backgroundColor;
    CFRunLoopTimerRef       _zombieTimer;
    NSString               *_localDragType;
    NSMutableIndexSet      *_selectedIndexes;
    NSRect                  _rubberBandRect;
    NSRect                  _dropRectForHighlight;
    CGFloat                 _padding;
    NSSize                  _iconSize;
    NSPoint                 _lastMouseDownLocInView;
    BOOL                    _isRescaling;
    BOOL                    _isDrawingDragImage;
    CFAbsoluteTime          _timeOfLastOrigin;
    NSPoint                 _lastOrigin;
    CFMutableDictionaryRef  _trackingRectMap;
    NSButton               *_leftArrow;
    NSButton               *_rightArrow;
    
    NSArray                *_iconURLs;
}

// bindings compatibility, although this can be set directly
- (void)setIconURLs:(NSArray *)anArray;
- (NSArray *)iconURLs;

// this is the only way to get selection information at present
- (NSIndexSet *)selectionIndexes;
- (void)setSelectionIndexes:(NSIndexSet *)indexSet;

// wrapper that calls bound array or datasource transparently
- (NSURL *)iconURLAtIndex:(NSUInteger)anIndex;
- (NSUInteger)numberOfIcons;

// bind a slider or other control to this
- (CGFloat)iconScale;
- (void)setIconScale:(CGFloat)scale;

// primarily for use with datasource methods
- (void)setDataSource:(id)obj;
- (id)dataSource;
- (NSUInteger)numberOfRows;
- (NSUInteger)numberOfColumns;
- (void)reloadIcons;

// default is Mail's source list color
- (void)setBackgroundColor:(NSColor *)aColor;

// actions that NSResponder doesn't declare
- (IBAction)selectPreviousIcon:(id)sender;
- (IBAction)selectNextIcon:(id)sender;
- (IBAction)delete:(id)sender;

// required for editing support (dropping files on the view, deleting)
- (void)setDelegate:(id)obj;
- (id)delegate;

@end


// datasource must conform to this
@interface NSObject (FileViewDataSource)

// delegate must return an NSURL or nil for each index < numberOfFiles
- (NSUInteger)numberOfIconsInFileView:(FileView *)aFileView;
- (NSURL *)fileView:(FileView *)aFileView URLAtIndex:(NSUInteger)index;

@end

@interface NSObject (FileViewDelegateDragAndDrop)

// If the delegate implements allowsEditingFileView to return YES, all other methods in this informal protocol /must/ be implemented.  This method is only called when setting the delegate.
- (BOOL)allowsEditingFileView:(FileView *)aView;

// implement to do something (or nothing) with the dropped URLs
- (void)fileView:(FileView *)aFileView insertURLs:(NSArray *)absoluteURLs atIndexes:(NSIndexSet *)aSet;

// replaces the files at the given indexes; this may be a rearranging operation
- (BOOL)fileView:(FileView *)fileView replaceURLsAtIndexes:(NSIndexSet *)aSet withURLs:(NSArray *)newURLs;

// does not delete the file from disk; just from the view
- (BOOL)fileView:(FileView *)fileView deleteURLsAtIndexes:(NSIndexSet *)indexSet;

@end

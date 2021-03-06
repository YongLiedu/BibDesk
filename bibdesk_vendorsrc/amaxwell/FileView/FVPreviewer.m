//
//  FVPreviewer.m
//  FileViewTest
//
//  Created by Adam Maxwell on 09/01/07.
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

#import <FileView/FVPreviewer.h>
#import "FVScaledImageView.h"
#import <QTKit/QTKit.h>
#import <WebKit/WebKit.h>
#import <pthread.h>
#import "_FVPreviewerWindow.h"
#import "FVTextIcon.h" // for NSAttributedString initialization check

NSString * const FVPreviewerWillCloseNotification = @"FVPreviewerWillCloseNotification";

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
@interface FVPreviewer (FVSnowLeopard) <NSAnimationDelegate>
@end
#endif

#ifdef MAC_OS_X_VERSION_10_11
@interface FVPreviewer () <WebFrameLoadDelegate>
@end
#endif

@implementation FVPreviewer

+ (FVPreviewer *)sharedPreviewer;
{
    FVAPIAssert(pthread_main_np() != 0, @"FVPreviewer must only be used on the main thread");
    static id sharedInstance = nil;
    if (nil == sharedInstance)
        sharedInstance = [[self alloc] init];
    return sharedInstance;
}

+ (BOOL)useQuickLookForURL:(NSURL *)aURL;
{
    /*
     !!! The conditions here must be consistent with those in contentViewForURL:shouldUseQuickLook:
     or else we'll end up using qlmanage unintentionally.
     */
    
    // !!! Early return; 10.7 and later support text selection in QL preview via a hidden pref set in +[FileView initialize].
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6)
        return YES;    
    
    // early return
    NSSet *webviewSchemes = [NSSet setWithObjects:@"http", @"https", @"ftp", nil];
    if ([aURL scheme] && [webviewSchemes containsObject:[aURL scheme]])
        return NO;
    
    // everything from here on safely assumes a file URL
    
    OSStatus err = noErr;
    
    FSRef fileRef;
    
    // return nil if we can't resolve the path
    if (FALSE == CFURLGetFSRef((CFURLRef)aURL, &fileRef))
        err = fnfErr;
    
    // kLSItemContentType returns a CFStringRef, according to the header
    CFTypeRef theUTI = NULL;
    if (noErr == err)
        err = LSCopyItemAttribute(&fileRef, kLSRolesAll, kLSItemContentType, &theUTI);
    [(id)theUTI autorelease];
        
    // we get this for e.g. doi or unrecognized schemes; let FVPreviewer handle those
    if (fnfErr == err)
        return NO;

    if (nil == theUTI || UTTypeEqual(theUTI, kUTTypeData)) {
        NSAttributedString *string = [[[NSAttributedString alloc] initWithURL:aURL documentAttributes:NULL] autorelease];
        return (string == nil);
    }
    else if (UTTypeConformsTo(theUTI, kUTTypePDF) || UTTypeConformsTo(theUTI, FVSTR("com.adobe.postscript"))) {
        return NO;
    }
    else if ([FVTextIcon canInitWithUTI:(NSString *)theUTI]) {
        NSAttributedString *string = [[[NSAttributedString alloc] initWithURL:aURL documentAttributes:NULL] autorelease];
        return (string == nil);
    }
    
    // not NSTextView, WebView, or PDFView content, so use Quick Look
    return YES;
}

- (id)init
{
    // initWithWindowNibName searches the class' bundle automatically
    self = [super initWithWindowNibName:[self windowNibName]];
    if (self) {
        // window is now loaded lazily, but we have to use a flag to avoid a hit when calling isPreviewing
        windowLoaded = NO;
    }
    return self;
}

- (BOOL)isPreviewing;
{
    return (windowLoaded && ([[self window] isVisible] || [qlTask isRunning]));
}

- (void)setWebViewContextMenuDelegate:(id)anObject;
{
    webviewContextMenuDelegate = anObject;
}

- (NSString *)windowFrameAutosaveName;
{
    return @"FileView preview window frame";
}

- (NSRect)savedFrame
{
    NSString *savedFrame = [[NSUserDefaults standardUserDefaults] objectForKey:[self windowFrameAutosaveName]];
    return (nil == savedFrame) ? NSZeroRect : NSRectFromString(savedFrame);
}

- (void)windowDidLoad
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    // Finder hides QL when it loses focus, then restores when it regains it; we can't do that easily, so just get rid of it
    [nc addObserver:self selector:@selector(stopPreview:) name:NSApplicationWillHideNotification object:nil];
    [nc addObserver:self selector:@selector(stopPreview:) name:NSApplicationWillResignActiveNotification object:nil];
    [nc addObserver:self selector:@selector(stopPreview:) name:NSApplicationWillTerminateNotification object:nil];
    
    windowLoaded = YES;
}

- (void)awakeFromNib
{
    // revert to the previously saved size, or whatever was set in the nib
    [self setWindowFrameAutosaveName:@""];
    [[self window] setFrameAutosaveName:@""];

    NSRect savedFrame = [self savedFrame];
    if (NSEqualRects(savedFrame, NSZeroRect))
        [[NSUserDefaults standardUserDefaults] setObject:NSStringFromRect([[self window] frame]) forKey:[self windowFrameAutosaveName]];
    
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
        [[fullScreenButton cell] setBackgroundStyle:NSBackgroundStyleDark];
        [fullScreenButton setImage:[NSImage imageNamed:NSImageNameEnterFullScreenTemplate]];
        [fullScreenButton setAlternateImage:[NSImage imageNamed:NSImageNameExitFullScreenTemplate]];
        [fullScreenButton setRefusesFirstResponder:YES];
    }
    else {
        [fullScreenButton removeFromSuperview];
        fullScreenButton = nil;
        [contentView setFrame:[[[self window] contentView] frame]];
    }
}

- (void)windowWillClose:(NSNotification *)notification
{
    [self setWebViewContextMenuDelegate:nil];
    // notify observers that they're no longer managing the previewer
    [[NSNotificationCenter defaultCenter] postNotificationName:FVPreviewerWillCloseNotification object:self];
}

- (void)animationDidEnd:(NSAnimation*)animation;
{
    if (NO == closeAfterAnimation) {
        [contentView selectFirstTabViewItem:nil];
        // highlight around button isn't drawn unless the window is key, which happens randomly unless we force it here
        [[self window] makeKeyAndOrderFront:nil];
        [[self window] makeFirstResponder:fullScreenButton];
    }
}

- (BOOL)windowShouldClose:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setObject:NSStringFromRect([[self window] frame]) forKey:[self windowFrameAutosaveName]];

    // make sure it doesn't respond to keystrokes while fading out
    [[self window] makeFirstResponder:nil];
    // image is now possibly out of sync due to scrolling/resizing
    NSView *currentView = [[contentView tabViewItemAtIndex:0] view];
    NSBitmapImageRep *imageRep = [currentView bitmapImageRepForCachingDisplayInRect:[currentView bounds]];
    [currentView cacheDisplayInRect:[currentView bounds] toBitmapImageRep:imageRep];
    NSImage *image = [[NSImage alloc] initWithSize:[imageRep size]];
    [image addRepresentation:imageRep];
    [animationView setImage:image];
    [image release];
    [contentView selectLastTabViewItem:nil];

    closeAfterAnimation = YES;
    // using NSAnimationEaseOut causes a double animation or something; it seems badly broken
    NSViewAnimation *animation = [[NSViewAnimation alloc] initWithDuration:0.3 animationCurve:NSAnimationEaseInOut]; 
    [animation setAnimationBlockingMode:NSAnimationBlocking];
    [animation setFrameRate:30.0];
    NSMutableDictionary *windowDict = [NSMutableDictionary dictionary];
    [windowDict setObject:[self window] forKey:NSViewAnimationTargetKey];
    if (NSIsEmptyRect(previousIconFrame) == NO) {
        [windowDict setObject:[NSValue valueWithRect:[[self window] frame]] forKey:NSViewAnimationStartFrameKey];
        [windowDict setObject:[NSValue valueWithRect:previousIconFrame] forKey:NSViewAnimationEndFrameKey];
    }
    [windowDict setObject:NSViewAnimationFadeOutEffect forKey:NSViewAnimationEffectKey];
    [animation setViewAnimations:[NSArray arrayWithObject:windowDict]];
    [animation setDelegate:self];
    [animation startAnimation];
    [animation release];   

    return YES;
}

- (void)_killTask
{
    [qlTask terminate];
    // wait until the task actually exits, or we can end up launching a new task before this one quits (happened when duplicate KVO notifications were sent)
    [qlTask waitUntilExit];
    [qlTask release];
    qlTask = nil;    
}

- (void)setCurrentURL:(NSURL *)aURL
{
    [currentURL autorelease];
    currentURL = [aURL copy];
}

- (void)stopPreviewing;
{
    [self setCurrentURL:nil];
    [self _killTask];

    if (windowLoaded && [[self window] isVisible]) {
        
        if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4 && [[[self window] contentView] isInFullScreenMode]) {
            [[[self window] contentView] exitFullScreenModeWithOptions:nil];
        }
        
        // performClose: invokes windowShouldClose: and then closes the window, so state gets saved
        [[self window] performClose:nil];
        [self setWebViewContextMenuDelegate:nil];
    }    
}

- (void)stopPreview:(NSNotification *)note
{
    [self stopPreviewing];
}

- (NSString *)windowNibName { return @"FVPreviewer"; }

static NSData *PDFDataWithPostScriptDataAtURL(NSURL *aURL)
{
    NSData *psData = [[NSData alloc] initWithContentsOfURL:aURL options:NSMappedRead error:NULL];
    CGPSConverterCallbacks converterCallbacks = { 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL };
    CGPSConverterRef converter = CGPSConverterCreate(NULL, &converterCallbacks, NULL);
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)psData);
    [psData release];
    
    CFMutableDataRef pdfData = CFDataCreateMutable(CFGetAllocator((CFDataRef)psData), 0);
    CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData(pdfData);
    Boolean success = CGPSConverterConvert(converter, provider, consumer, NULL);
    
    CGDataProviderRelease(provider);
    CGDataConsumerRelease(consumer);
    CFRelease(converter);
    
    if(success == FALSE){
        CFRelease(pdfData);
        pdfData = nil;
    }
    
    return [(id)pdfData autorelease];
}

- (void)_loadAttributedString:(NSAttributedString *)string documentAttributes:(NSDictionary *)attrs inView:(NSTextView *)theView
{
    [theView setSelectedRange:NSMakeRange(0, 0)];
    [theView scrollRangeToVisible:NSMakeRange(0, 0)];
    
    NSTextStorage *textStorage = [theView textStorage];
    [textStorage setAttributedString:string];
    NSColor *backgroundColor = nil;
    if (nil == attrs || [[attrs objectForKey:NSDocumentTypeDocumentAttribute] isEqualToString:NSPlainTextDocumentType]) {
        NSFont *plainFont = [NSFont userFixedPitchFontOfSize:10.0f];
        [textStorage addAttribute:NSFontAttributeName value:plainFont range:NSMakeRange(0, [textStorage length])];
    }
    else {
        backgroundColor = [attrs objectForKey:NSBackgroundColorDocumentAttribute];
    }
    if (nil == backgroundColor)
        backgroundColor = [NSColor whiteColor];
    [theView setBackgroundColor:backgroundColor];    
}

- (NSView *)contentViewForURL:(NSURL *)representedURL shouldUseQuickLook:(BOOL *)shouldUseQuickLook;
{
    // general case
    *shouldUseQuickLook = NO;
    
    // early return
    NSSet *webviewSchemes = [NSSet setWithObjects:@"http", @"https", @"ftp", nil];
    if ([representedURL scheme] && [webviewSchemes containsObject:[representedURL scheme]]) {
        [webView setFrameLoadDelegate:self];
        
        // wth? why doesn't WebView accept an NSURL?
        if ([webView respondsToSelector:@selector(setMainFrameURL:)]) {
            [webView setMainFrameURL:[representedURL absoluteString]];
        }
        else {
            [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:representedURL]];
        }

        return webView;
    }
    
    // everything from here on safely assumes a file URL
    
    OSStatus err = noErr;
    
    FSRef fileRef;
    
    // return nil if we can't resolve the path
    if (FALSE == CFURLGetFSRef((CFURLRef)representedURL, &fileRef))
        err = fnfErr;
    
    // kLSItemContentType returns a CFStringRef, according to the header
    CFTypeRef theUTI = NULL;
    if (noErr == err)
        err = LSCopyItemAttribute(&fileRef, kLSRolesAll, kLSItemContentType, &theUTI);
    [(id)theUTI autorelease];
    
    NSView *theView = nil;
    
    // we get this for e.g. doi or unrecognized schemes; let FVIcon handle those
    if (fnfErr == err) {
        theView = imageView;
        [(FVScaledImageView *)theView displayImageAtURL:representedURL];
    }
    else if (nil == theUTI || UTTypeEqual(theUTI, kUTTypeData)) {
        theView = textView;
        NSDictionary *attrs;
        NSAttributedString *string = [[NSAttributedString alloc] initWithURL:representedURL documentAttributes:&attrs];
        if (string)
            [self _loadAttributedString:string documentAttributes:attrs inView:[textView documentView]];
        else
            theView = nil;
        [string release]; 
    }
    else if (UTTypeConformsTo(theUTI, kUTTypePDF)) {
        theView = pdfView;
        PDFDocument *pdfDoc = [[PDFDocument alloc] initWithURL:representedURL];
        [pdfView setDocument:pdfDoc];
        [pdfDoc release];
    }
    else if (UTTypeConformsTo(theUTI, FVSTR("com.adobe.postscript"))) {
        theView = pdfView;
        PDFDocument *pdfDoc = [[PDFDocument alloc] initWithData:PDFDataWithPostScriptDataAtURL(representedURL)];
        [pdfView setDocument:pdfDoc];
        [pdfDoc release];         
    }
    else if (UTTypeConformsTo(theUTI, kUTTypeImage)) {
        theView = imageView;
        [(FVScaledImageView *)theView displayImageAtURL:representedURL];
    }
    else if (UTTypeConformsTo(theUTI, kUTTypeAudiovisualContent)) {
        // use A/V content instead of just movie, since audio is fair game for the preview
        QTMovie *movie = [[QTMovie alloc] initWithURL:representedURL error:NULL];
        if (nil != movie) {
            theView = movieView;
            [movieView setMovie:movie];
            [movie release];
        }
    }
    else if ([FVTextIcon canInitWithUTI:(NSString *)theUTI]) {
        theView = textView;
        NSDictionary *attrs;
        NSAttributedString *string = [[NSAttributedString alloc] initWithURL:representedURL documentAttributes:&attrs];
        if (string)
            [self _loadAttributedString:string documentAttributes:attrs inView:[textView documentView]];
        else
            theView = nil;
        [string release]; 
    }
    
    // probably just a Finder icon, but NSWorkspace returns a crappy little icon (so use Quick Look if possible)
    if (nil == theView) {
        theView = imageView;
        [(FVScaledImageView *)theView displayIconForURL:representedURL];
        *shouldUseQuickLook = YES;
    }

    return theView;
    
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    [spinner stopAnimation:nil];
    [spinner removeFromSuperview];
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
    const CGFloat spinnerSideLength = 32;
    WebFrame *mainFrame = [webView mainFrame];
    if (nil == spinner) {
        spinner = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, spinnerSideLength, spinnerSideLength)];
        [spinner setStyle:NSProgressIndicatorSpinningStyle];
        [spinner setUsesThreadedAnimation:YES];
        [spinner setDisplayedWhenStopped:NO];
        [spinner setControlSize:NSRegularControlSize];
    }
    if ([spinner isDescendantOf:[mainFrame frameView]] == NO) {
        [spinner removeFromSuperview];
        NSRect wvFrame = [[mainFrame frameView] frame];
        NSRect spFrame;
        spFrame.origin.x = wvFrame.origin.x + (wvFrame.size.width - spinnerSideLength) / 2;
        spFrame.origin.y = wvFrame.origin.y + (wvFrame.size.height - spinnerSideLength) / 2;
        spFrame.size = NSMakeSize(spinnerSideLength, spinnerSideLength);
        [spinner setFrame:spFrame];
        [spinner setAutoresizingMask:(NSViewMinXMargin|NSViewMinYMargin|NSViewMaxXMargin|NSViewMaxYMargin)];
        [[mainFrame frameView] addSubview:spinner];
    }
    [spinner startAnimation:nil];
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
    if ([webviewContextMenuDelegate respondsToSelector:_cmd]) {
        return [webviewContextMenuDelegate webView:sender contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems];
    } else {
        NSMutableArray *items = [NSMutableArray array];
        NSEnumerator *itemEnum = [defaultMenuItems objectEnumerator];
        NSMenuItem *item;
        while ((item = [itemEnum nextObject])) {
            NSInteger tag = [item tag];
            if (tag == WebMenuItemTagCopyLinkToClipboard || tag == WebMenuItemTagCopyImageToClipboard || tag == WebMenuItemTagCopy || tag == WebMenuItemTagGoBack || tag == WebMenuItemTagGoForward || tag == WebMenuItemTagStop || tag == WebMenuItemTagReload || tag == WebMenuItemTagOther)
                [items addObject:item];
        }
        return items;
    }
}

- (void)previewFileURLs:(NSArray *)absoluteURLs;
{
    previousIconFrame = NSZeroRect;
    
    [self _killTask];
    
    NSMutableArray *paths = [NSMutableArray array];
    NSUInteger cnt = [absoluteURLs count];
    
    // ignore non-file URLs; this isn't technically necessary for our pseudo-Quick Look, but it's consistent
    while (cnt--) {
        if ([[absoluteURLs objectAtIndex:cnt] isFileURL])
            [paths insertObject:[[absoluteURLs objectAtIndex:cnt] path] atIndex:0];
    }
    
    if ([paths count] && [[NSFileManager defaultManager] isExecutableFileAtPath:@"/usr/bin/qlmanage"]) {
        
        NSMutableArray *args = paths;
        [args insertObject:@"-p" atIndex:0];
        NSParameterAssert(nil == qlTask);
        qlTask = [[NSTask alloc] init];
        @try {
            [qlTask setLaunchPath:@"/usr/bin/qlmanage"];
            [qlTask setArguments:args];
            // qlmanage is really verbose, so don't fill the log with its spew
            [qlTask setStandardError:[NSFileHandle fileHandleWithNullDevice]];
            [qlTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
            [qlTask launch];
        }
        @catch(id exception) {
            NSLog(@"Unable to run qlmanage: %@", exception);
        }
    }
    else if([paths count]) {
        [self previewURL:[NSURL fileURLWithPath:[paths objectAtIndex:0]] forIconInRect:[[self window] frame]];
    }
}

- (void)_previewURL:(NSURL *)absoluteURL
{    
    [self _killTask];

    BOOL shouldUseQuickLook;
    NSView *newView = [self contentViewForURL:absoluteURL shouldUseQuickLook:&shouldUseQuickLook];
    
    /*
     Quick Look (qlmanage) handles more types than our setup, but you can't copy any content from 
     PDF/text sources, which sucks; hence, we only use it as a fallback (basically a replacement 
     for FVScaledImageView).  There are some slight behavior mismatches, but they're minor in 
     comparison.  Quick Look also can't handle network resources, so we use a custom view for those.
     */
    if (shouldUseQuickLook && [absoluteURL isFileURL] && [[NSFileManager defaultManager] isExecutableFileAtPath:@"/usr/bin/qlmanage"]) {
        
        if ([[self window] isVisible])
            [[self window] performClose:self];
        
        NSParameterAssert(nil == qlTask);
        qlTask = [[NSTask alloc] init];
        @try {
            [qlTask setLaunchPath:@"/usr/bin/qlmanage"];
            [qlTask setArguments:[NSArray arrayWithObjects:@"-p", [absoluteURL path], nil]];
            // qlmanage is really verbose, so don't fill the log with its spew
            [qlTask setStandardError:[NSFileHandle fileHandleWithNullDevice]];
            [qlTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
            [qlTask launch];
        }
        @catch(id exception) {
            NSLog(@"Unable to run qlmanage: %@", exception);
        }
    }
    else {
        NSWindow *theWindow = [self window];

        [[contentView tabViewItemAtIndex:0] setView:newView];
        
        if ([absoluteURL isFileURL]) {
            [theWindow setTitleWithRepresentedFilename:[absoluteURL path]];
        }
        else {
            // raises on nil
            [theWindow setTitleWithRepresentedFilename:@""];
        }
        
        if ([theWindow isVisible]) {
            // don't animate the window if it's already on-screen
            
            // select the new view
            [contentView selectFirstTabViewItem:nil];
            // highlight around button isn't drawn unless the window is key, which happens randomly unless we force it here
            [theWindow makeKeyAndOrderFront:nil];
            [theWindow makeFirstResponder:fullScreenButton];
            
        } else {
            
            NSRect newWindowFrame = [self savedFrame];            
            [theWindow setAlphaValue:0.0];
            [theWindow makeKeyAndOrderFront:nil];
            
            // select the new view and set the window's frame in order to get the view's new frame
            [contentView selectFirstTabViewItem:nil];
            NSRect oldWindowFrame = [theWindow frame];
            [theWindow setFrame:newWindowFrame display:YES];
            
            // cache the new view to an image
            NSBitmapImageRep *imageRep = [newView bitmapImageRepForCachingDisplayInRect:[newView bounds]];
            [newView cacheDisplayInRect:[newView bounds] toBitmapImageRep:imageRep];
            [[self window] setFrame:oldWindowFrame display:NO];
            NSImage *image = [[NSImage alloc] initWithSize:[imageRep size]];
            [image addRepresentation:imageRep];
            [animationView setImage:image];
            [image release];
            
            [contentView selectLastTabViewItem:nil];
            
            // animate ~30 fps for 0.3 seconds
            NSViewAnimation *animation = [[NSViewAnimation alloc] initWithDuration:0.3 animationCurve:NSAnimationEaseIn]; 
            [animation setFrameRate:30.0];
            [animation setAnimationBlockingMode:NSAnimationBlocking];
            NSMutableDictionary *windowDict = [NSMutableDictionary dictionary];
            [windowDict setObject:theWindow forKey:NSViewAnimationTargetKey];
            [windowDict setObject:NSViewAnimationFadeInEffect forKey:NSViewAnimationEffectKey];

            // if we had a previously saved frame in the defaults database, set it as the target
            if (NO == NSEqualRects(newWindowFrame, NSZeroRect)) {            
                [windowDict setObject:[NSValue valueWithRect:[theWindow frame]] forKey:NSViewAnimationStartFrameKey];
                [windowDict setObject:[NSValue valueWithRect:newWindowFrame] forKey:NSViewAnimationEndFrameKey]; 
            }
            
            [animation setViewAnimations:[NSArray arrayWithObject:windowDict]];
            [animation setDelegate:self];
            closeAfterAnimation = NO;
            [animation startAnimation];
            [animation release];
            
        }
        
        [(_FVPreviewerWindow *)[self window] resetKeyStatus];
    }
}

- (void)previewURL:(NSURL *)absoluteURL forIconInRect:(NSRect)screenRect
{
    FVAPIParameterAssert(nil != absoluteURL);
    [self setCurrentURL:absoluteURL];

    // don't animate the window size for zero icon rect
    if (NSEqualRects(screenRect, NSZeroRect)) {
        previousIconFrame = NSZeroRect;
        screenRect = [self savedFrame];
    }
    // we have a valid rect, but enforce a minimum window size of 128 x 128
    else {
        if (NSHeight(screenRect) < 128)
            screenRect.size.height = 128;
        if (NSWidth(screenRect) < 128)
            screenRect.size.width = 128;
        // closing the window will animate back to this frame
        previousIconFrame = screenRect;
    }
    
    // if currently on screen, this will screw up the saved frame
    if ([[self window] isVisible] == NO && NSIsEmptyRect(screenRect) == NO)
        [[self window] setFrame:screenRect display:NO];
    [self _previewURL:absoluteURL];
}

- (void)previewURL:(NSURL *)absoluteURL;
{
    FVAPIParameterAssert(nil != absoluteURL);
    [self previewURL:absoluteURL forIconInRect:NSZeroRect];
}

- (void)previewAction:(id)sender 
{
    [self stopPreview:nil];
}

- (void)toggleFullscreen:(id)sender
{
    FVAPIAssert(floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4, @"Full screen is only available on 10.5 and later");
    if ([[[self window] contentView] isInFullScreenMode]) {
        [[[self window] contentView] exitFullScreenModeWithOptions:nil];
    }
    else {
        [[[self window] contentView] enterFullScreenMode:[[self window] screen] withOptions:nil];
    }
}

- (void)doubleClickedPreviewWindow
{
    NSParameterAssert([[self window] isVisible]);
    NSParameterAssert(currentURL);
    [[NSWorkspace sharedWorkspace] openURL:currentURL];
}

// esc is typically bound to complete: instead of cancelOperation: in a textview
- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
{
    if (@selector(cancelOperation:) == aSelector || @selector(cancel:) == aSelector || @selector(complete:) == aSelector) {
        [self stopPreviewing];
        return YES;
    }
    return NO;
}

// end up getting this via the responder chain for most views
- (void)cancelOperation:(id)sender
{
    // !!! since this is now part of the API, make sure it's save to call
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4)
        return;
    
    if ([[[self window] contentView] isInFullScreenMode]) {
        [[[self window] contentView] exitFullScreenModeWithOptions:nil];
    }
    else {
        [self stopPreviewing];
    }
}    


@end

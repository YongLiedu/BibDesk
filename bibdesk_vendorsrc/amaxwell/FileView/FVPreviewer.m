//
//  FVPreviewer.m
//  FileViewTest
//
//  Created by Adam Maxwell on 09/01/07.
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

#import "FVPreviewer.h"
#import "FVScaledImageView.h"
#import <Quartz/Quartz.h>
#import <QTKit/QTKit.h>
#import <WebKit/WebKit.h>

@interface PDFDocument (FVSkimNotesExtensions)
- (id)initWithURL:(NSURL *)url readSkimNotes:(NSArray **)notes;
@end

@implementation FVPreviewer

+ (id)sharedInstance;
{
    static id sharedInstance = nil;
    if (nil == sharedInstance)
        sharedInstance = [[self alloc] init];
    return sharedInstance;
}

+ (void)previewURL:(NSURL *)absoluteURL;
{
    [[self sharedInstance] previewURL:absoluteURL];
}

+ (void)previewFileURLs:(NSArray *)absoluteURLs;
{
    [[self sharedInstance] previewFileURLs:absoluteURLs];
}

+ (BOOL)isPreviewing;
{
    return [[self sharedInstance] isPreviewing];
}

- (BOOL)isPreviewing;
{
    return ([[self window] isVisible] || [qlTask isRunning]);
}

+ (void)setWebViewContextMenuDelegate:(id)anObject;
{
    [[self sharedInstance] setWebViewContextMenuDelegate:anObject];
}

- (void)setWebViewContextMenuDelegate:(id)anObject;
{
    webviewContextMenuDelegate = anObject;
}

- (id)init
{
    // initWithWindowNibName searches the class' bundle automatically
    self = [super initWithWindowNibName:[self windowNibName]];
    // force the window to load, so we get -awakeFromNib
    [self window];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    if (self) {
        // Finder hides QL when it loses focus, then restores when it regains it; we can't do that easily, so just get rid of it
        [nc addObserver:self selector:@selector(stopPreview:) name:NSApplicationWillHideNotification object:nil];
        [nc addObserver:self selector:@selector(stopPreview:) name:NSApplicationWillResignActiveNotification object:nil];
        [nc addObserver:self selector:@selector(appTerminate:) name:NSApplicationWillTerminateNotification object:nil];
    }
    return self;
}

- (void)awakeFromNib
{
    fvImageView = [[FVScaledImageView alloc] initWithFrame:[[[self window] contentView] frame]];
    [fvImageView setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
    // forgot to set this in the nib; needed for viewing icons
    [[self window] setMinSize:[[self window] frame].size];
    [[self window] setDelegate:self];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"FVPreviewerPDFScaleFactor"]) {
        float pdfScaleFactor = [[NSUserDefaults standardUserDefaults] floatForKey:@"FVPreviewerPDFScaleFactor"];
        if (pdfScaleFactor > 0.0)
            [pdfView setScaleFactor:pdfScaleFactor];
        else
            [pdfView setAutoScales:YES];
    }
    
    id animation = [NSClassFromString(@"CABasicAnimation") animation];
    if (animation && [[self window] respondsToSelector:@selector(setAnimations:)]) {
        [animation setDelegate:self];
        [[self window] setAnimations:[NSDictionary dictionaryWithObject:animation forKey:@"alphaValue"]];
    }
}

- (void)windowWillClose:(NSNotification *)notification
{
    [self setWebViewContextMenuDelegate:nil];
}

- (NSWindow *)animator
{
    NSWindow *theWindow = [self window];
    return [theWindow respondsToSelector:@selector(animator)] ? [theWindow animator] : theWindow;
}

- (BOOL)windowShouldClose:(id)sender
{
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
        // make sure it doesn't respond to keystrokes while fading out
        [[self window] makeFirstResponder:nil];
        [[self animator] setAlphaValue:0.0];
        return NO;
    }
    return YES;
}

- (void)animationDidStop:(id)animation finished:(BOOL)flag  {
    if ([[self window] alphaValue] < 0.0001 && [[self window] isVisible])
        [self close];
}

- (void)stopPreview:(NSNotification *)note
{
    if ([qlTask isRunning])
        [qlTask terminate];
    [[self window] orderOut:self];
    [self setWebViewContextMenuDelegate:nil];
}

- (void)appTerminate:(NSNotification *)note
{
    if (pdfView)
        [[NSUserDefaults standardUserDefaults] setFloat:([pdfView autoScales] ? 0.0 : [pdfView scaleFactor]) forKey:@"FVPreviewerPDFScaleFactor"];
    [self stopPreview:note];
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

- (NSView *)contentViewForURL:(NSURL *)representedURL;
{
    // early return
    if ([representedURL isFileURL] == NO) {
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
        return nil;
    
    // kLSItemContentType returns a CFStringRef, according to the header
    CFTypeRef theUTI = NULL;
    if (noErr == err)
        err = LSCopyItemAttribute(&fileRef, kLSRolesAll, kLSItemContentType, &theUTI);
    [(id)theUTI autorelease];
    
    NSView *theView = nil;
    
    if (nil == theUTI) {
        theView = textView;
        NSDictionary *attrs;
        NSAttributedString *string = [[NSAttributedString alloc] initWithURL:representedURL documentAttributes:&attrs];
        if (string) {
            NSTextStorage *textStorage = [[textView documentView] textStorage];
            [textStorage setAttributedString:string];
            if (nil == attrs || [[attrs objectForKey:NSDocumentTypeDocumentAttribute] isEqualToString:NSPlainTextDocumentType]) {
                NSFont *plainFont = [NSFont userFixedPitchFontOfSize:10.0f];
                [textStorage addAttribute:NSFontAttributeName value:plainFont range:NSMakeRange(0, [textStorage length])];
            }
        }
        else
            theView = nil;
        [string release]; 
    }
    else if (UTTypeConformsTo(theUTI, kUTTypePDF) || UTTypeConformsTo(theUTI, CFSTR("net.sourceforge.skim-app.pdfd"))) {
        theView = pdfView;
        PDFDocument *pdfDoc = [PDFDocument instancesRespondToSelector:@selector(initWithURL:readSkimNotes:)] ? [[PDFDocument alloc] initWithURL:representedURL readSkimNotes:NULL] : [[PDFDocument alloc] initWithURL:representedURL];
        [pdfView setDocument:pdfDoc];
        [pdfDoc release];
    }
    else if (UTTypeConformsTo(theUTI, CFSTR("com.adobe.postscript"))) {
        theView = pdfView;
        PDFDocument *pdfDoc = [[PDFDocument alloc] initWithData:PDFDataWithPostScriptDataAtURL(representedURL)];
        [pdfView setDocument:pdfDoc];
        [pdfDoc release];         
    }
    else if (UTTypeConformsTo(theUTI, kUTTypeImage)) {
        theView = fvImageView;
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
    else if (UTTypeConformsTo(theUTI, CFSTR("public.composite-content")) || UTTypeConformsTo(theUTI, kUTTypeText)) {
        theView = textView;
        NSDictionary *attrs;
        NSAttributedString *string = [[NSAttributedString alloc] initWithURL:representedURL documentAttributes:&attrs];
        if (string) {
            NSTextStorage *textStorage = [[textView documentView] textStorage];
            [textStorage setAttributedString:string];
            if (nil == attrs || [[attrs objectForKey:NSDocumentTypeDocumentAttribute] isEqualToString:NSPlainTextDocumentType]) {
                NSFont *plainFont = [NSFont userFixedPitchFontOfSize:10.0f];
                [textStorage addAttribute:NSFontAttributeName value:plainFont range:NSMakeRange(0, [textStorage length])];
            }
        }
        else
            theView = nil;
        [string release]; 
    }
    
    // probably just a Finder icon, but NSWorkspace returns a crappy little icon
    if (nil == theView) {
        theView = fvImageView;
        [(FVScaledImageView *)theView displayIconForURL:representedURL];
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
    if ([qlTask isRunning]) {
        [qlTask terminate];
        [qlTask release];
        
        // set to nil, since we may alternate between QL and our own previewing
        qlTask = nil;
    }
    
    NSMutableArray *paths = [NSMutableArray array];
    NSUInteger cnt = [absoluteURLs count];
    
    // ignore non-file URLs; this isn't technically necessary for our pseudo-Quick Look, but it's consistent
    while (cnt--)
        if ([[absoluteURLs objectAtIndex:cnt] isFileURL])
            [paths insertObject:[[absoluteURLs objectAtIndex:cnt] path] atIndex:0];
    
    if ([paths count] && [[NSFileManager defaultManager] isExecutableFileAtPath:@"/usr/bin/qlmanage"]) {
        
        NSMutableArray *args = paths;
        [args insertObject:@"-p" atIndex:0];
        
        qlTask = [[NSTask alloc] init];
        [qlTask setLaunchPath:@"/usr/bin/qlmanage"];
        [qlTask setArguments:args];
        // qlmanage is really verbose, so don't fill the log with its spew
        [qlTask setStandardError:[NSFileHandle fileHandleWithNullDevice]];
        [qlTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
        [qlTask launch];
    }
    else if([paths count]) {
        [[self class] previewURL:[NSURL fileURLWithPath:[paths objectAtIndex:0]]];
    }
}

- (void)previewURL:(NSURL *)absoluteURL;
{
    
    if ([qlTask isRunning]) {
        [qlTask terminate];
        [qlTask release];
        
        // set to nil, since we may alternate between QL and our own previewing
        qlTask = nil;
    }
    
    if (absoluteURL) {
        
        NSView *newView = [self contentViewForURL:absoluteURL];
        
        // Quick Look (qlmanage) handles more types than our setup, but you can't copy any content from PDF/text sources, which sucks; hence, we only use it as a fallback (basically a replacement for fvImageView).  There are some slight behavior mismatches, and we lose fullscreen (I think), but that's minor in comparison.
        if ([fvImageView isEqual:newView] && [absoluteURL isFileURL] && [[NSFileManager defaultManager] isExecutableFileAtPath:@"/usr/bin/qlmanage"]) {
            
            // !!! Should animate the window fade as Quick Look does, but -animator doesn't help with that AFAICT.  Using an NSAnimation isn't quite smooth enough.  I tried using layer-backed view, but display craps out when loading a PDF because it apparently doesn't tile correctly (the entire image won't fit on the GPU).
            if ([[self window] isVisible])
                [[self window] close];

            qlTask = [[NSTask alloc] init];
            [qlTask setLaunchPath:@"/usr/bin/qlmanage"];
            [qlTask setArguments:[NSArray arrayWithObjects:@"-p", [absoluteURL path], nil]];
            // qlmanage is really verbose, so don't fill the log with its spew
            [qlTask setStandardError:[NSFileHandle fileHandleWithNullDevice]];
            [qlTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
            [qlTask launch];
        }
        else {
            NSWindow *theWindow = [self window];
            NSArray *subviews = [[theWindow contentView] subviews];
            NSView *oldView = [subviews count] ? [subviews objectAtIndex:0] : nil;
            
            if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4)
                [theWindow setAlphaValue:0.0];
            
            NSView *contentView = [theWindow contentView];
            if (oldView)
                [contentView replaceSubview:oldView with:newView];
            else
                [contentView addSubview:newView];
            
            // Inset margins for the HUD window on Leopard; Tiger uses NSPanel
            NSRect frame = NSInsetRect([[theWindow contentView] frame], 1.0, 1.0);
            if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
                frame.size.height -= 20;
                frame.origin.y += 20;
            }
            [newView setFrame:frame];

            // it's annoying to recenter if this is just in response to a selection change or something
            if (NO == [theWindow isVisible])
                [theWindow center];

            if ([absoluteURL isFileURL]) {
                [theWindow setTitleWithRepresentedFilename:[absoluteURL path]];
            }
            else {
                // raises on nil
                [theWindow setTitleWithRepresentedFilename:@""];
            }

            if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) {
                [[self window] setAlphaValue:0.0];
                [[self window] makeKeyAndOrderFront:nil];
                [[self animator] setAlphaValue:1.0];
            }
            else {
                [self showWindow:self];
            }
            
            // make sure the view updates properly, in case it was previously on screen
            [[[self window] contentView] setNeedsDisplay:YES];
        }
    }
    else {
        NSBeep();
    }
}

- (IBAction)previewAction:(id)sender {
    // make this action toggle the previewer
    [[self window] performClose:self];
}

@end

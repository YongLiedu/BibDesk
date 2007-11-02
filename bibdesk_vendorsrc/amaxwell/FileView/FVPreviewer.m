//
//  FVPreviewer.m
//  FileViewTest
//
//  Created by Adam Maxwell on 09/01/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "FVPreviewer.h"
#import "FVScaledImageView.h"

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

+ (BOOL)isPreviewing;
{
    return [[self sharedInstance] isPreviewing];
}

- (BOOL)isPreviewing;
{
    return ([[self window] isVisible] || [qlTask isRunning]);
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
        [nc addObserver:self selector:@selector(stopPreview:) name:NSApplicationWillTerminateNotification object:nil];
    }
    return self;
}

- (void)awakeFromNib
{
    fvImageView = [[FVScaledImageView alloc] initWithFrame:[[[self window] contentView] frame]];
    [fvImageView setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
    // forgot to set this in the nib; needed for viewing icons
    [[self window] setMinSize:[[self window] frame].size];
}

- (void)stopPreview:(NSNotification *)note
{
    if ([qlTask isRunning])
        [qlTask terminate];
    [[self window] orderOut:self];
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
            [webView performSelector:@selector(setMainFrameURL:) withObject:[representedURL absoluteString]];
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
    else if (UTTypeConformsTo(theUTI, kUTTypePDF)) {
        theView = pdfView;
        PDFDocument *pdfDoc = [[PDFDocument alloc] initWithURL:representedURL];
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
    const CGFloat spinnerSideLength = 50.0f;
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

- (void)previewURL:(NSURL *)absoluteURL;
{
    
    if ([qlTask isRunning]) {
        [qlTask terminate];
        [qlTask release];
    }
    
    if (absoluteURL) {
        
        NSView *newView = [self contentViewForURL:absoluteURL];
        
        // Quick Look (qlmanage) handles more types than our setup, but you can't copy any content from PDF/text sources, which sucks; hence, we only use it as a fallback (basically a replacement for fvImageView).  There are some slight behavior mismatches, and we lose fullscreen (I think), but that's minor in comparison.
        if ([fvImageView isEqual:newView] && [absoluteURL isFileURL] && [[NSFileManager defaultManager] isExecutableFileAtPath:@"/usr/bin/qlmanage"]) {

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
            if (oldView)
                [[theWindow contentView] replaceSubview:oldView with:newView];
            else
                [[theWindow contentView] addSubview:newView];
            
            // Margins currently set for the HUD window on Leopard; Tiger uses NSPanel, which doesn't look as good
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
            [self showWindow:nil];
            
            // make sure the view updates properly, in case it was previously on screen
            [[[self window] contentView] setNeedsDisplay:YES];
        }
    }
    else {
        NSBeep();
    }
}

@end

//  BDSKPreviewer.m

//  Created by Michael McCracken on Tue Jan 29 2002.
/*
 This software is Copyright (c) 2002-2013
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BDSKPreviewer.h"
#import "BDSKStringConstants.h"
#import "BDSKTeXTask.h"
#import "BDSKOverlayWindow.h"
#import "BDSKAppController.h"
#import "BDSKZoomableTextView.h"
#import "BDSKZoomablePDFView.h"
#import "BibDocument.h"
#import "BibDocument_UI.h"
#import "NSString_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKCollapsibleView.h"
#import "BDSKDocumentController.h"
#import "NSImage_BDSKExtensions.h"
#import "NSPrintOperation_BDSKExtensions.h"
#import "BDSKPreferenceController.h"

#define BDSKPreviewPanelFrameAutosaveName @"BDSKPreviewPanel"

enum {
    BDSKPreviewerTabIndexPDF,
    BDSKPreviewerTabIndexLog,
};

static NSData *createPDFDataWithStringAndColor(NSString *string, NSColor *color);

@implementation BDSKPreviewer

static BDSKPreviewer *sharedPreviewer = nil;

+ (BDSKPreviewer *)sharedPreviewer{
    
    if (sharedPreviewer == nil) {
        sharedPreviewer = [[self alloc] init];
    }
    return sharedPreviewer;
}

- (id)init{
    if(self = [super init]){
        // this reflects the currently expected state, not necessarily the actual state
        // it corresponds to the last drawing item added to the mainQueue
        previewState = BDSKUnknownPreviewState;
        
        // otherwise a document's previewer might mess up the window position of the shared previewer
        [self setShouldCascadeWindows:NO];
        
        texTask = [[BDSKTeXTask alloc] initWithFileName:@"bibpreview" synchronous:NO];
        [texTask setDelegate:self];
    }
    return self;
}

// Using isEqual:[BDSKSharedPreviewer sharedPreviewer] will lead to a leak if awakeFromNib is called while +sharedPreviewer is on the stack for the first time, since it calls isSharedPreviewer.  This is readily seen from the backtrace in http://sourceforge.net/tracker/index.php?func=detail&aid=1936951&group_id=61487&atid=497423 although it doesn't fix that problem.
- (BOOL)isSharedPreviewer { return [self isEqual:sharedPreviewer]; }

#pragma mark UI setup and display

- (void)windowDidLoad{
    CGFloat pdfScaleFactor = 0.0;
    BDSKCollapsibleView *collapsibleView = (BDSKCollapsibleView *)[[[progressOverlay contentView] subviews] firstObject];
    NSSize minSize = [progressIndicator frame].size;
    NSRect rect = [warningImageView bounds];
    NSRect targetRect = {NSZeroPoint, rect.size};
    NSImage *image = [[NSImage alloc] initWithSize:rect.size];
    
    [image lockFocus];
    [[warningImageView image] drawInRect:targetRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.7];
    [image unlockFocus];
    [warningImageView setImage:image];
    [image release];
	
    // we use threads, so better let the progressIndicator also use them
    [progressIndicator setUsesThreadedAnimation:YES];
    minSize.height += NSMinY([[progressIndicator superview] frame]);
    [collapsibleView setMinSize:minSize];
    [collapsibleView setCollapseEdges:BDSKMaxXEdgeMask | BDSKMaxYEdgeMask];
    
    if([self isSharedPreviewer]){
        [self setWindowFrameAutosaveName:BDSKPreviewPanelFrameAutosaveName];
        
        rect = [warningView frame];
        rect.origin.x += 22.0;
        [warningView setFrame:rect];
        
        // overlay the progressIndicator over the contentView
        [progressOverlay overlayView:[[self window] contentView]];
        
        pdfScaleFactor = [[NSUserDefaults standardUserDefaults] doubleForKey:BDSKPreviewPDFScaleFactorKey];
        
        // register to observe when the preview needs to be updated (handle this here rather than on a per document basis as the preview is currently global for the application)
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleApplicationWillTerminate:)
                                                     name:NSApplicationWillTerminateNotification
                                                   object:NSApp];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleMainDocumentDidChangeNotification:)
                                                     name:BDSKDocumentControllerDidChangeMainDocumentNotification
                                                   object:nil];
    }
        
    // empty document to avoid problem when zoom is set to auto
    static NSData *emptyPDFData = nil;
    if (emptyPDFData == nil)
        emptyPDFData = createPDFDataWithStringAndColor(@"", nil);
    
    PDFDocument *pdfDoc = [[[PDFDocument alloc] initWithData:emptyPDFData] autorelease];
    [pdfView setDocument:pdfDoc];
    
    [pdfView setDisplaysPageBreaks:NO];
    [pdfView setBackgroundColor:[NSColor controlBackgroundColor]];
    
    // don't reset the scale factor until there's a document loaded, or else we get a huge gray border
    [pdfView setScaleFactor:pdfScaleFactor];
    
    [self displayPreviewsForState:BDSKEmptyPreviewState success:YES];
    
    [pdfView retain];
}

- (NSString *)windowNibName
{
    return @"Previewer";
}

- (void)handleMainDocumentDidChangeNotification:(NSNotification *)notification
{
    BDSKASSERT([self isSharedPreviewer]);
    if([[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey] && [self isWindowVisible])
        [[[NSDocumentController sharedDocumentController] mainDocument] updatePreviewer:self];
}

- (void)updateRepresentedFilename
{
    NSString *path = nil;
	if(previewState == BDSKShowingPreviewState){
        NSInteger tabIndex = [tabView indexOfTabViewItem:[tabView selectedTabViewItem]];
        if(tabIndex == BDSKPreviewerTabIndexPDF)
            path = [texTask PDFFilePath];
        else
            path = [texTask logFilePath];
    }
    [[self window] setRepresentedFilename:path ?: @""];
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    [self updateRepresentedFilename];
}

- (PDFView *)pdfView;
{
    [self window];
    return pdfView;
}

- (BDSKOverlayPanel *)progressOverlay;
{
    [self window];
    return progressOverlay;
}

- (CGFloat)PDFScaleFactor;
{
    [self window];
    return [pdfView autoScales] ? 0.0 : [pdfView scaleFactor];
}

- (void)setPDFScaleFactor:(CGFloat)scaleFactor;
{
    [self window];
    [pdfView setScaleFactor:scaleFactor];
}

- (BOOL)isVisible{
    return [[pdfView window] isVisible] || [[logView window] isVisible];
}

#pragma mark Actions

- (IBAction)showWindow:(id)sender{
    BDSKASSERT([self isSharedPreviewer]);
	[super showWindow:self];
	[progressOverlay orderFront:sender];
	[(BibDocument *)[[NSDocumentController sharedDocumentController] currentDocument] updatePreviewer:self];
    if(![[NSUserDefaults standardUserDefaults] boolForKey:BDSKUsesTeXKey]){
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Previewing is Disabled.", @"Message in alert dialog when showing preview with TeX preview disabled")
                                         defaultButton:NSLocalizedString(@"Yes", @"Button title")
                                       alternateButton:NSLocalizedString(@"No", @"Button title")
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"TeX previewing must be enabled in BibDesk's preferences in order to use this feature.  Would you like to open the preference pane now?", @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:self
                         didEndSelector:@selector(shouldShowTeXPreferences:returnCode:contextInfo:)
                            contextInfo:NULL];
                          
    }
}

- (void)shouldShowTeXPreferences:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    if(returnCode == NSAlertDefaultReturn){
        [[BDSKPreferenceController sharedPreferenceController] showWindow:nil];
        [[BDSKPreferenceController sharedPreferenceController] selectPaneWithIdentifier:@"edu.ucsd.cs.mmccrack.bibdesk.prefpane.TeX"];
    }else{
		[self hideWindow:nil];
	}
}

// first responder gets this
- (void)printDocument:(id)sender{
    NSInteger tabIndex = [tabView indexOfTabViewItem:[tabView selectedTabViewItem]];
    if (tabIndex == BDSKPreviewerTabIndexPDF)
        [pdfView printSelection:sender];
    else if (tabIndex == BDSKPreviewerTabIndexLog)
        [(BDSKZoomableTextView *)logView printSelection:sender];
}

#pragma mark Drawing methods

- (void)displayPreviewsForState:(BDSKPreviewState)state success:(BOOL)success{

    NSAssert2([NSThread isMainThread], @"-[%@ %@] must be called from the main thread!", [self class], NSStringFromSelector(_cmd));
    
    // From Shark: if we were waiting before, and we're still waiting, there's nothing to do.  This is a big performance win when scrolling the main tableview selection, primarily because changing the text storage of rtfPreviewView ends up calling fixFontAttributes.  This in turn causes a disk hit at the ATS cache due to +[NSFont coveredCharacterCache], and parsing the binary plist uses lots of memory.
    if (BDSKWaitingPreviewState == previewState && BDSKWaitingPreviewState == state)
        return;
    
	previewState = state;
		
    // start or stop the spinning wheel
    if(state == BDSKWaitingPreviewState)
        [progressIndicator startAnimation:nil];
    else
        [progressIndicator stopAnimation:nil];
	
    // if we're offscreen, no point in doing any extra work; we want to be able to reset offscreen though
    if(![self isVisible] && state != BDSKEmptyPreviewState){
        return;
    }
	
    [warningView setHidden:success];
    
    NSString *logString = @"";
    NSData *pdfData = nil;
	static NSData *errorMessagePDFData = nil;
	static NSData *emptyMessagePDFData = nil;
	static NSData *generatingMessagePDFData = nil;
	
	// get the data to display
	if(state == BDSKShowingPreviewState){
        
        logString = [texTask logFileString] ?: NSLocalizedString(@"Unable to read log file from TeX run.", @"Preview message");
        
		pdfData = [self PDFData];
        if(success == NO || pdfData == nil){
			// show the TeX log file in the view
			NSMutableString *errorString = [[NSMutableString alloc] initWithCapacity:200];
			[errorString appendString:NSLocalizedString(@"TeX preview generation failed.  Please review the log below to determine the cause.", @"Preview message")];
			[errorString appendString:@"\n\n"];
            
            // now that we correctly check return codes from the NSTask, users blame us for TeX preview failures that have been failing all along, so we'll try to give them a clue to the error if possible (which may save a LART later on)
            NSSet *standardStyles = [NSSet setWithObjects:@"abbrv", @"acm", @"alpha", @"apalike", @"ieeetr", @"plain", @"siam", @"unsrt", nil];
            NSString *btStyle = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKBTStyleKey];
            if([standardStyles containsObject:btStyle] == NO)
                [errorString appendFormat:NSLocalizedString(@"***** WARNING: You are using a non-standard BibTeX style *****\nThe style \"%@\" may require additional \\usepackage commands to function correctly.\n\n", @"possible cause of TeX failure"), btStyle];
            
			[errorString appendString:logString];
            logString = [errorString autorelease];
            
            if(pdfData == nil) {
                if (errorMessagePDFData)
                    errorMessagePDFData = createPDFDataWithStringAndColor(NSLocalizedString(@"***** ERROR:  unable to create preview *****\n\nsee the logs in the TeX Preview window", @"Preview message"), [NSColor redColor]);
                pdfData = errorMessagePDFData;
            }
		}
        
	}else if(state == BDSKEmptyPreviewState){
		
        logString = @"";
        
		if (emptyMessagePDFData == nil)
			emptyMessagePDFData = createPDFDataWithStringAndColor(NSLocalizedString(@"No items are selected.", @"Preview message"), [NSColor grayColor]);
		pdfData = emptyMessagePDFData;
		
	}else if(state == BDSKWaitingPreviewState){
		
        logString = @"";
        
		if (generatingMessagePDFData == nil)
			generatingMessagePDFData = createPDFDataWithStringAndColor([NSLocalizedString(@"Generating preview", @"Preview message") stringByAppendingEllipsis], [NSColor grayColor]);
		pdfData = generatingMessagePDFData;
		
	}
	
	BDSKPOSTCONDITION(pdfData != nil);
	
	// draw the PDF preview
    PDFDocument *pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
    [pdfView setDocument:pdfDocument];
    [pdfDocument release];
    
	[logView setString:@""];
	[logView setTextContainerInset:NSMakeSize(20,20)];  // pad the edges of the text
    [logView setString:logString];
    
    if([self isSharedPreviewer])
        [self updateRepresentedFilename];
}

#pragma mark TeX Tasks

- (void)updateWithBibTeXString:(NSString *)bibStr{
    [self updateWithBibTeXString:bibStr citeKeys:nil];
}

- (void)updateWithBibTeXString:(NSString *)bibStr citeKeys:(NSArray *)citeKeys{
    [texTask cancel];
    
	if([NSString isEmptyString:bibStr]){
		// reset, also removes any waiting tasks from the nextTask
        [self displayPreviewsForState:BDSKEmptyPreviewState success:YES];
    } else {
		// this will start the spinning wheel
        [self displayPreviewsForState:BDSKWaitingPreviewState success:YES];
        // run the tex task in the background
        [texTask runWithBibTeXString:bibStr citeKeys:citeKeys generatedTypes:BDSKGeneratePDF];
	}	
}

- (void)texTask:(BDSKTeXTask *)texTask finishedWithResult:(BOOL)success{
    // ignore this task if we finished a task that was running when the previews were reset
	if(previewState != BDSKEmptyPreviewState) {
        // if we didn't have success, the drawing method will show the log file
        [self displayPreviewsForState:BDSKShowingPreviewState success:success];
    }
}

#pragma mark Data accessors

- (NSData *)PDFData{
	if(previewState != BDSKShowingPreviewState || [self isVisible] == NO)
        return nil;
    return [texTask PDFData];
}

- (NSString *)LaTeXString{
	if(previewState != BDSKShowingPreviewState || [self isVisible] == NO)
        return nil;
    return [texTask LaTeXString];
}

#pragma mark Cleanup

- (void)windowWillClose:(NSNotification *)notification{
	[self displayPreviewsForState:BDSKEmptyPreviewState success:YES];
}

- (void)handleApplicationWillTerminate:(NSNotification *)notification{
    BDSKASSERT([self isSharedPreviewer]);
    
	// save the visibility of the previewer
	[[NSUserDefaults standardUserDefaults] setBool:[self isWindowVisible] forKey:BDSKShowingPreviewKey];
    // save the scalefactors of the views
    CGFloat scaleFactor = ([pdfView autoScales] ? 0.0 : [pdfView scaleFactor]);

	if (fabs(scaleFactor - [[NSUserDefaults standardUserDefaults] doubleForKey:BDSKPreviewPDFScaleFactorKey]) > 0.01)
		[[NSUserDefaults standardUserDefaults] setDouble:scaleFactor forKey:BDSKPreviewPDFScaleFactorKey];
    
    // make sure we don't process anything else; the TeX task will take care of its own cleanup
    [texTask terminate];
    BDSKDESTROY(texTask);
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // make sure we don't process anything else; the TeX task will take care of its own cleanup
    [texTask terminate];
    BDSKDESTROY(texTask);
    [pdfView release];
    [super dealloc];
}

@end


static NSData *createPDFDataWithStringAndColor(NSString *string, NSColor *color) {
    NSRect rect = NSMakeRect(0.0, 0.0, 612.0, 792.0);
    NSTextView *textView = [[NSTextView alloc] initWithFrame:rect];
    [textView setVerticallyResizable:YES];
    [textView setHorizontallyResizable:NO];
    [textView setTextContainerInset:NSMakeSize(20.0, 20.0)];
    
    NSTextStorage *textStorage = [textView textStorage];
    [textStorage beginEditing];
    if (string)
        [[textStorage mutableString] setString:string];
    [textStorage addAttribute:NSFontAttributeName value:[NSFont userFontOfSize:0.0] range:NSMakeRange(0, [textStorage length])];
    if (color)
        [textStorage addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, [textStorage length])];
    [textStorage endEditing];
	
    NSData *data = [textView dataWithPDFInsideRect:rect];
    
    [textView release];
    
    return [data retain];
}

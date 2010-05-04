//  BDSKPreviewer.m

//  Created by Michael McCracken on Tue Jan 29 2002.
/*
 This software is Copyright (c) 2002-2010
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
#import "BDSKAsynchronousDOServer.h"
#import "BDSKDocumentController.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKPrintableView.h"
#import "BDSKPreferenceController.h"

#define BDSKPreviewPanelFrameAutosaveName @"BDSKPreviewPanel"

enum {
    BDSKPreviewerTabIndexPDF,
    BDSKPreviewerTabIndexRTF,
    BDSKPreviewerTabIndexLog,
};


@interface BDSKPreviewTask : NSObject {
    NSString *bibTeXString;
    NSArray *citeKeys;
    NSInteger generatedTypes;
}
+ (id)previewTaskWithBibTeXString:(NSString *)aString citeKeys:(NSArray *)aKeys generatedTypes:(NSInteger)aTypes;
- (id)initWithBibTeXString:(NSString *)aString citeKeys:(NSArray *)aKeys generatedTypes:(NSInteger)aTypes;
- (NSString *)bibTeXString;
- (NSArray *)citeKeys;
- (NSInteger)generatedTypes;
@end

#pragma mark -

@protocol BDSKPreviewerServerThread <BDSKAsyncDOServerThread>
- (oneway void)processNextTask;
@end

@protocol BDSKPreviewerServerMainThread <BDSKAsyncDOServerMainThread>
- (void)serverFinishedWithResult:(BOOL)success;
@end

@protocol BDSKPreviewerServerDelegate <NSObject>
@optional
- (void)server:(BDSKPreviewerServer *)server finishedWithResult:(BOOL)success;
@end

@interface BDSKPreviewerServer : BDSKAsynchronousDOServer {
    BDSKTeXTask *texTask;
    id<BDSKPreviewerServerDelegate> delegate;
    NSString *bibString;
    NSRecursiveLock *nextTaskLock;
    BDSKPreviewTask *nextTask;
    volatile int32_t isProcessing;
    volatile int32_t notifyWhenDone;
}

- (id<BDSKPreviewerServerDelegate>)delegate;
- (void)setDelegate:(id<BDSKPreviewerServerDelegate>)newDelegate;
- (BDSKTeXTask *)texTask;
- (void)runTeXTaskInBackgroundWithInfo:(BDSKPreviewTask *)previewTask;

@end

#pragma mark -

@interface BDSKPreviewer (BDSKPreviewerServerDelegate) <BDSKPreviewerServerDelegate>
@end

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
        
        generatedTypes = BDSKGenerateRTF;
        
        // otherwise a document's previewer might mess up the window position of the shared previewer
        [self setShouldCascadeWindows:NO];
        
        server = [[BDSKPreviewerServer alloc] init];
        [server setDelegate:self];
    }
    return self;
}

// Using isEqual:[BDSKSharedPreviewer sharedPreviewer] will lead to a leak if awakeFromNib is called while +sharedPreviewer is on the stack for the first time, since it calls isSharedPreviewer.  This is readily seen from the backtrace in http://sourceforge.net/tracker/index.php?func=detail&aid=1936951&group_id=61487&atid=497423 although it doesn't fix that problem.
- (BOOL)isSharedPreviewer { return [self isEqual:sharedPreviewer]; }

#pragma mark UI setup and display

- (void)windowDidLoad{
    CGFloat pdfScaleFactor = 0.0;
    CGFloat rtfScaleFactor = 1.0;
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
        
        pdfScaleFactor = [[NSUserDefaults standardUserDefaults] floatForKey:BDSKPreviewPDFScaleFactorKey];
        rtfScaleFactor = [[NSUserDefaults standardUserDefaults] floatForKey:BDSKPreviewRTFScaleFactorKey];
        
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
    PDFDocument *pdfDoc = [[[PDFDocument alloc] initWithData:[self PDFDataWithString:@"" color:nil]] autorelease];
    [pdfView setDocument:pdfDoc];
    
    [pdfView setDisplaysPageBreaks:NO];
    [pdfView setBackgroundColor:[NSColor controlBackgroundColor]];
    
    // don't reset the scale factor until there's a document loaded, or else we get a huge gray border
    [pdfView setScaleFactor:pdfScaleFactor];
	[(BDSKZoomableTextView *)rtfPreviewView setScaleFactor:rtfScaleFactor];
    
    [self displayPreviewsForState:BDSKEmptyPreviewState success:YES];
    
    [pdfView retain];
    [[rtfPreviewView enclosingScrollView] retain];
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
            path = [[server texTask] PDFFilePath];
        else if(tabIndex == BDSKPreviewerTabIndexRTF)
            path = [[server texTask] RTFFilePath];
        else
            path = [[server texTask] logFilePath];
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

- (NSTextView *)textView;
{
    [self window];
    return rtfPreviewView;
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

- (CGFloat)RTFScaleFactor;
{
    [self window];
    return [(BDSKZoomableTextView *)rtfPreviewView scaleFactor];
}

- (void)setRTFScaleFactor:(CGFloat)scaleFactor;
{
    [self window];
    [(BDSKZoomableTextView *)rtfPreviewView setScaleFactor:scaleFactor];
}


- (NSInteger)generatedTypes;
{
    return generatedTypes;
}

- (void)setGeneratedTypes:(NSInteger)newGeneratedTypes;
{
    generatedTypes = newGeneratedTypes;
}

- (BOOL)isVisible{
    return [[pdfView window] isVisible] || [[rtfPreviewView window] isVisible] || [[logView window] isVisible];
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
    if (tabIndex == BDSKPreviewerTabIndexPDF) {
        [pdfView printWithInfo:[NSPrintInfo sharedPrintInfo] autoRotate:NO];
    } else {
        NSTextView *textView = tabIndex == BDSKPreviewerTabIndexRTF ? rtfPreviewView : logView;
        NSPrintOperation *printOp = [NSPrintOperation printOperationWithAttributedString:[textView textStorage] printInfo:nil settings:nil];
        [printOp setShowsPrintPanel:YES];
        [printOp setShowsProgressPanel:YES];
        [printOp setCanSpawnSeparateThread:YES];
        [printOp runOperationModalForWindow:[self window] delegate:nil didRunSelector:NULL contextInfo:NULL];
    }
}

#pragma mark Drawing methods

- (NSData *)PDFDataWithString:(NSString *)string color:(NSColor *)color{
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
    
    return data;
}

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
    
    NSString *message = nil;
    NSString *logString = @"";
    NSData *pdfData = nil;
	NSAttributedString *attrString = nil;
	static NSData *emptyMessagePDFData = nil;
	static NSData *generatingMessagePDFData = nil;
	
	// get the data to display
	if(state == BDSKShowingPreviewState){
        
        NSData *rtfData = [self RTFData];
		if(rtfData != nil)
			attrString = [[NSAttributedString alloc] initWithRTF:rtfData documentAttributes:NULL];
		else
			message = NSLocalizedString(@"***** ERROR:  unable to create preview *****", @"Preview message");
		
        logString = [[server texTask] logFileString] ?: NSLocalizedString(@"Unable to read log file from TeX run.", @"Preview message");
        
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
            
            if(pdfData == nil)
                pdfData = [self PDFDataWithString:NSLocalizedString(@"***** ERROR:  unable to create preview *****", @"Preview message") color:[NSColor redColor]];
		}
        
	}else if(state == BDSKEmptyPreviewState){
		
		message = NSLocalizedString(@"No items are selected.", @"Preview message");
		
        logString = @"";
        
		if (emptyMessagePDFData == nil)
			emptyMessagePDFData = [[self PDFDataWithString:message color:[NSColor grayColor]] retain];
		pdfData = emptyMessagePDFData;
		
	}else if(state == BDSKWaitingPreviewState){
		
		message = [NSLocalizedString(@"Generating preview", @"Preview message") stringByAppendingEllipsis];
		
        logString = @"";
        
		if (generatingMessagePDFData == nil)
			generatingMessagePDFData = [[self PDFDataWithString:message color:[NSColor grayColor]] retain];
		pdfData = generatingMessagePDFData;
		
	}
	
	BDSKPOSTCONDITION(pdfData != nil);
	
	// draw the PDF preview
    PDFDocument *pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
    [pdfView setDocument:pdfDocument];
    [pdfDocument release];
    
    // draw the RTF preview
	[rtfPreviewView setString:@""];
	[rtfPreviewView setTextContainerInset:NSMakeSize(20,20)];  // pad the edges of the text
	if(attrString){
		[[rtfPreviewView textStorage] appendAttributedString:attrString];
		[attrString release];
	} else if (message){
        NSTextStorage *ts = [rtfPreviewView textStorage];
        [[ts mutableString] setString:message];
        [ts addAttribute:NSForegroundColorAttributeName value:[NSColor grayColor] range:NSMakeRange(0, [ts length])];
	}
    
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
    
	if([NSString isEmptyString:bibStr]){
		// reset, also removes any waiting tasks from the nextTask
        [self displayPreviewsForState:BDSKEmptyPreviewState success:YES];
        // clean the server
        [server runTeXTaskInBackgroundWithInfo:nil];
    } else {
		// this will start the spinning wheel
        [self displayPreviewsForState:BDSKWaitingPreviewState success:YES];
        // run the tex task in the background
        [server runTeXTaskInBackgroundWithInfo:[BDSKPreviewTask previewTaskWithBibTeXString:bibStr citeKeys:citeKeys generatedTypes:generatedTypes]];
	}	
}

- (void)server:(BDSKPreviewerServer *)server finishedWithResult:(BOOL)success{
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
    return [[server texTask] PDFData];
}

- (NSData *)RTFData{
	if(previewState != BDSKShowingPreviewState || [self isVisible] == NO)
        return nil;
    return [[server texTask] RTFData];
}

- (NSString *)LaTeXString{
	if(previewState != BDSKShowingPreviewState || [self isVisible] == NO)
        return nil;
    return [[server texTask] LaTeXString];
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

	if (fabs(scaleFactor - [[NSUserDefaults standardUserDefaults] floatForKey:BDSKPreviewPDFScaleFactorKey]) > 0.01)
		[[NSUserDefaults standardUserDefaults] setFloat:scaleFactor forKey:BDSKPreviewPDFScaleFactorKey];
	scaleFactor = [(BDSKZoomableTextView *)rtfPreviewView scaleFactor];
	if (fabs(scaleFactor - [[NSUserDefaults standardUserDefaults] floatForKey:BDSKPreviewRTFScaleFactorKey]) > 0.01)
		[[NSUserDefaults standardUserDefaults] setFloat:scaleFactor forKey:BDSKPreviewRTFScaleFactorKey];
    
    // make sure we don't process anything else; the TeX task will take care of its own cleanup
    [server stopDOServer];
    [server release];
    server = nil;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // make sure we don't process anything else; the TeX task will take care of its own cleanup
    [server stopDOServer];
    BDSKDESTROY(server);
    [pdfView release];
    [[rtfPreviewView enclosingScrollView] release];
    [super dealloc];
}

@end

#pragma mark -

@implementation BDSKPreviewerServer

- (id)init;
{
    self = [super init];
    if (self) {
        texTask = [[BDSKTeXTask alloc] initWithFileName:@"bibpreview"];
        delegate = nil;
        bibString = nil;
        nextTaskLock = [NSRecursiveLock new];
        nextTask = nil;
        isProcessing = 0;
        notifyWhenDone = 0;
        [self startDOServerSync];
    }
    return self;
}

- (void)dealloc;
{
    BDSKDESTROY(texTask);
    BDSKDESTROY(nextTaskLock);
    BDSKDESTROY(nextTask);
    [super dealloc];
}

- (void)serverDidFinish{
    [bibString release];
    bibString = nil;
    [texTask terminate];
}

// superclass overrides

- (Protocol *)protocolForServerThread { return @protocol(BDSKPreviewerServerThread); }

- (Protocol *)protocolForMainThread { return @protocol(BDSKPreviewerServerMainThread); }

// main thread API

- (id<BDSKPreviewerServerDelegate>)delegate { return delegate; }

- (void)setDelegate:(id<BDSKPreviewerServerDelegate>)newDelegate { delegate = newDelegate; }

- (BDSKTeXTask *)texTask{
    return texTask;
}

- (void)runTeXTaskInBackgroundWithInfo:(BDSKPreviewTask *)previewTask{
    [nextTaskLock lock];
    [nextTask release];
    nextTask = [previewTask retain];
    [nextTaskLock unlock];
    if(previewTask){
        // If it's still working, we don't have to do anything; sending too many of these messages just replaces nextTask until the port starts dropping them.
        OSMemoryBarrier();
        if(isProcessing == 0)
            [[self serverOnServerThread] processNextTask];
        // start sending task finished messages to the previewer
        OSAtomicCompareAndSwap32Barrier(0, 1, &notifyWhenDone);
    }else{
        // don't notify the previewer of any pending task results; it might be better if the previewer learned to ignore the messages?
        OSAtomicCompareAndSwap32Barrier(1, 0, &notifyWhenDone);
    }
}

// Server thread protocol

- (oneway void)processNextTask{
    OSAtomicCompareAndSwap32Barrier(0, 1, &isProcessing);
    
    BDSKPreviewTask *previewTask = nil;
    [nextTaskLock lock];
    NSDate *distantFuture = [NSDate distantFuture];
    NSRunLoop *rl = [NSRunLoop currentRunLoop];
    
    do { 
        // we're only interested in the latest addition to the nextTask
        previewTask = nextTask;
        // get rid of the nextTask, then allow the main thread to keep putting strings in it
        nextTask = nil;
        [nextTaskLock unlock];
        
        BOOL success = YES;
        if (previewTask) {
            BOOL didRun = YES;
            if ([texTask isProcessing]) {
                // poll the runloop while the task is still running
                do {
                    didRun = [rl runMode:NSDefaultRunLoopMode beforeDate:distantFuture];
                } while (didRun && [texTask isProcessing]);
                
                // get the latest string; the nextTask may have changed while we waited for this task to finish (doesn't seem to be the case in practice)
                [nextTaskLock lock];
                if (nextTask) {
                    [previewTask release];
                    previewTask = nextTask;
                    nextTask = nil;
                }
                [nextTaskLock unlock];
            }
            // previous task is done, so we can start a new one
            success = [texTask runWithBibTeXString:[previewTask bibTeXString] citeKeys:[previewTask citeKeys] generatedTypes:[previewTask generatedTypes]];
            [previewTask release];
        }
        
        // always lock going into the top of the loop for checking count
        [nextTaskLock lock];
        
        // Don't notify the main thread until we've processed all of the entries in the nextTask
        OSMemoryBarrier();
        if (1 == notifyWhenDone && nextTask == nil) {
            // If the main thread is blocked on the nextTaskLock, we're hosed because it can't service the DO port!
            [nextTaskLock unlock];
            [[self serverOnMainThread] serverFinishedWithResult:success];
            [nextTaskLock lock];
        }
        OSMemoryBarrier();
    } while (1 == notifyWhenDone && nextTask);

    // swap, then unlock, so if a potential caller is blocking on the lock, they know to call processNextTask
    OSAtomicCompareAndSwap32Barrier(1, 0, &isProcessing);
    [nextTaskLock unlock];
}

// Main thread protocol

// If this message is sent oneway, there's no guarantee that any results exist when it's delivered, since some other task could have stomped on the files by that time, and the success variable would be stale.
- (void)serverFinishedWithResult:(BOOL)success{
    if([delegate respondsToSelector:@selector(server:finishedWithResult:)])
        [delegate server:self finishedWithResult:success];
}

@end

#pragma mark -

@implementation BDSKPreviewTask

+ (id)previewTaskWithBibTeXString:(NSString *)aString citeKeys:(NSArray *)aKeys generatedTypes:(NSInteger)aTypes {
    return [[[self alloc] initWithBibTeXString:aString citeKeys:aKeys generatedTypes:aTypes] autorelease];
}

- (id)initWithBibTeXString:(NSString *)aString citeKeys:(NSArray *)aKeys generatedTypes:(NSInteger)aTypes {
    if (self = [super init]) {
        bibTeXString = [aString copy];
        citeKeys = [aKeys copy];
        generatedTypes = aTypes;
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(bibTeXString);
    BDSKDESTROY(citeKeys);
    [super dealloc];
}

- (NSString *)bibTeXString { return bibTeXString; }
- (NSArray *)citeKeys { return citeKeys; }
- (NSInteger)generatedTypes { return generatedTypes; }

@end

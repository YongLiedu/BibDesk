//
//  BDSKZoomablePDFView.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/23/05.
/*
 This software is Copyright (c) 2005-2016
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

#import "BDSKZoomablePDFView.h"
#import "NSString_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSScrollView_BDSKExtensions.h"
#import "NSView_BDSKExtensions.h"
#import "BDSKHighlightingPopUpButton.h"
#import "BDSKCollapsibleView.h"
#import "BDSKColoredView.h"


@interface BDSKZoomablePDFView (BDSKPrivate)

- (void)makeScalePopUpButton;
- (void)scalePopUpAction:(id)sender;
- (void)setScaleFactor:(CGFloat)factor adjustPopup:(BOOL)flag;

@end

@implementation BDSKZoomablePDFView

static NSString *BDSKDefaultScaleMenuLabels[] = {@"Auto", @"10%", @"20%", @"25%", @"35%", @"50%", @"60%", @"71%", @"85%", @"100%", @"120%", @"141%", @"170%", @"200%", @"300%", @"400%", @"600%", @"800%"};
static CGFloat BDSKDefaultScaleMenuFactors[] = {0.0, 0.1, 0.2, 0.25, 0.35, 0.5, 0.6, 0.71, 0.85, 1.0, 1.2, 1.41, 1.7, 2.0, 3.0, 4.0, 6.0, 8.0};

#define BDSKMinDefaultScaleMenuFactor (BDSKDefaultScaleMenuFactors[1])
#define BDSKDefaultScaleMenuFactorsCount (sizeof(BDSKDefaultScaleMenuFactors) / sizeof(CGFloat))

#define BDSKScaleMenuFontSize 10.0
#define BDSKScaleMenuHeight 15.0
#define BDSKScaleMenuWidthOffset 20.0

#pragma mark Instance methods

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    BDSKDESTROY(scalePopUpButton);
    [super dealloc];
}

- (void)awakeFromNib {
    [self makeScalePopUpButton];
}

- (IBAction)printSelection:(id)sender {
    NSPrintInfo *printInfo = [[[[self window] windowController] document] printInfo];
    if (printInfo == nil)
        printInfo = [NSPrintInfo sharedPrintInfo];
    [self printWithInfo:printInfo autoRotate:YES];
}

// we don't want to steal the printDocument: action from the responder chain
- (void)printDocument:(id)sender{}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return aSelector != @selector(printDocument:) && [super respondsToSelector:aSelector];
}

#pragma mark Copying

// override so we can put the entire document on the pasteboard if there is no selection
- (void)copy:(id)sender;
{
    PDFSelection *theSelection = [self currentSelection] ?: [[self document] selectionForEntireDocument];
    NSAttributedString *attrString = [theSelection attributedString];
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    NSPasteboardItem *item = [[[NSPasteboardItem alloc] init] autorelease];
    [item setData:[[self document] dataRepresentation] forType:NSPasteboardTypePDF];
    [pboard clearContents];
    [pboard writeObjects:[NSArray arrayWithObjects:attrString, item, nil]];
}

- (void)copyAsPDF:(id)sender;
{
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    [pboard clearContents];
    [pboard setData:[[self document] dataRepresentation] forType:NSPasteboardTypePDF];
}

- (void)copyAsText:(id)sender;
{
    PDFSelection *theSelection = [self currentSelection] ?: [[self document] selectionForEntireDocument];
    NSAttributedString *attrString = [theSelection attributedString];
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    [pboard clearContents];
    [pboard writeObjects:[NSArray arrayWithObjects:attrString, nil]];
}

- (void)copyPDFPage:(id)sender;
{
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    [pboard clearContents];
    [pboard setData:[[self currentPage] dataRepresentation] forType:NSPasteboardTypePDF];
}

- (void)savePDFAs:(id)sender;
{
    NSString *name = [[[self document] documentURL] lastPathComponent];
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setNameFieldStringValue:name ?: NSLocalizedString(@"Untitled.pdf", @"Default file name for saved PDF")];
    [savePanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
        if(result == NSFileHandlingPanelOKButton){
            // -[PDFDocument writeToURL:] returns YES even if you don't have write permission, so we'll use NSData rdar://problem/4475062
            NSError *error = nil;
            NSData *data = [[self document] dataRepresentation];
            
            if([data writeToURL:[savePanel URL] options:NSDataWritingAtomic error:&error] == NO){
                [savePanel orderOut:nil];
                [self presentError:error];
            }
        }
    }];
}

- (void)doActualSize:(id)sender;
{
    [self setScaleFactor:1.0];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent;
{
    NSMenu *menu = [super menuForEvent:theEvent];
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Copy Document as PDF", @"Menu item title") action:@selector(copyAsPDF:) keyEquivalent:@""];
    [menu addItem:item];
    [item release];
    
    item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Copy Page as PDF", @"Menu item title") action:@selector(copyPDFPage:) keyEquivalent:@""];
    [menu addItem:item];
    [item release];

    NSString *title = (0 == [[[self currentSelection] string] length]) ? NSLocalizedString(@"Copy All Text", @"Menu item title") : NSLocalizedString(@"Copy Selected Text", @"Menu item title");
    
    item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:title action:@selector(copyAsText:) keyEquivalent:@""];
    [menu addItem:item];
    [item release];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Save PDF As", @"Menu item title") stringByAppendingEllipsis] action:@selector(savePDFAs:) keyEquivalent:@""];
    [menu addItem:item];
    [item release];
    
    NSInteger i = [menu indexOfItemWithTarget:self andAction:NSSelectorFromString(@"_setActualSize:")];
    if (i != -1)
        [[menu itemAtIndex:i] setAction:@selector(doActualSize:)];

    return menu;
}
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(doActualSize:)) {
        [menuItem setState:fabs([self scaleFactor] - 1.0) < 0.1 ? NSOnState : NSOffState];
        return YES;
    } else if ([[BDSKZoomablePDFView superclass] instancesRespondToSelector:_cmd]) {
        return [super validateMenuItem:menuItem];
    }
    return YES;
}

// Fix a bug in Tiger's PDFKit, tooltips lead to a crash when you reload a PDFDocument in a PDFView
// see http://www.cocoabuilder.com/archive/message/cocoa/2007/3/12/180190
- (void)scheduleAddingToolips {}
    
#pragma mark Popup button

- (void)handleScrollerStyleDidChange:(NSNotification *)notification {
    NSView *view = [self superview];
    if ([view respondsToSelector:@selector(setBackgroundColor:)]) {
        CGFloat white = [NSScroller preferredScrollerStyle] == NSScrollerStyleLegacy ? 0.97 : 1.0;
        [(BDSKColoredView *)view setBackgroundColor:[NSColor colorWithCalibratedWhite:white alpha:1.0]];
        [view setNeedsDisplay:YES];
    }
}

- (void)makeScalePopUpButton {
    
    if (scalePopUpButton == nil) {
        
        NSScrollView *scrollView = [self scrollView];
        
        // create it        
        scalePopUpButton = [[BDSKHighlightingPopUpButton allocWithZone:[self zone]] initWithFrame:NSMakeRect(0.0, 0.0, 1.0, 1.0) pullsDown:NO];
        
        [[scalePopUpButton cell] setControlSize:NSSmallControlSize];
		[scalePopUpButton setBordered:NO];
		[scalePopUpButton setEnabled:YES];
		[scalePopUpButton setRefusesFirstResponder:YES];
		[[scalePopUpButton cell] setUsesItemFromMenu:YES];
        
        // set a suitable font, the control size is 0, 1 or 2
        [scalePopUpButton setFont:[NSFont toolTipsFontOfSize:BDSKScaleMenuFontSize]];
        
        NSUInteger cnt, numberOfDefaultItems = BDSKDefaultScaleMenuFactorsCount;
        id curItem;
        NSString *label;
        CGFloat width, maxWidth = 0.0;
        NSSize size = NSMakeSize(1000.0, 1000.0);
        NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:[scalePopUpButton font], NSFontAttributeName, nil];
        NSUInteger maxIndex = 0;
        
        // fill it
        for (cnt = 0; cnt < numberOfDefaultItems; cnt++) {
            label = [[NSBundle mainBundle] localizedStringForKey:BDSKDefaultScaleMenuLabels[cnt] value:@"" table:@"ZoomValues"];
            width = NSWidth([label boundingRectWithSize:size options:0 attributes:attrs]);
            if (width > maxWidth) {
                maxWidth = width;
                maxIndex = cnt;
            }
            [scalePopUpButton addItemWithTitle:label];
            curItem = [scalePopUpButton itemAtIndex:cnt];
            [curItem setRepresentedObject:(BDSKDefaultScaleMenuFactors[cnt] > 0.0 ? [NSNumber numberWithDouble:BDSKDefaultScaleMenuFactors[cnt]] : nil)];
        }
        
        // Make sure the popup is big enough to fit the largest cell
        [scalePopUpButton selectItemAtIndex:maxIndex];
        [scalePopUpButton sizeToFit];
        [scalePopUpButton setFrameSize:NSMakeSize(NSWidth([scalePopUpButton frame]) - BDSKScaleMenuWidthOffset, BDSKScaleMenuHeight)];
        
        // select the appropriate item, adjusting the scaleFactor if necessary
        if([self autoScales])
            [self setScaleFactor:0.0 adjustPopup:YES];
        else
            [self setScaleFactor:[self scaleFactor] adjustPopup:YES];
        
		// don't let it become first responder
		[scalePopUpButton setRefusesFirstResponder:YES];
        
        // hook it up
        [scalePopUpButton setTarget:self];
        [scalePopUpButton setAction:@selector(scalePopUpAction:)];
        
        if ([NSScroller respondsToSelector:@selector(preferredScrollerStyle)]) {
            
            // on 10.7+, put it in an enclosing collapsible view
            NSRect popUpRect, pdfRect = [self frame];
            
            BDSKCollapsibleView *containerView = [[[BDSKCollapsibleView alloc] initWithFrame:pdfRect] autorelease];
            
            pdfRect.origin = NSZeroPoint;
            NSDivideRect(pdfRect, &popUpRect, &pdfRect, NSHeight([scalePopUpButton frame]), NSMinYEdge);
            popUpRect.size.width = NSWidth([scalePopUpButton frame]);
            
            [containerView setContentView:[[[BDSKColoredView alloc] init] autorelease]];
            [containerView setMinSize:popUpRect.size];
            [containerView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
            [[self superview] addSubview:containerView];
            
            [scalePopUpButton setAutoresizingMask:NSViewMaxXMargin | NSViewMaxYMargin];
            [scalePopUpButton setFrame:popUpRect];
            [containerView addSubview:scalePopUpButton];
            
            [self setFrame:pdfRect];
            [containerView addSubview:self];
            
            [self handleScrollerStyleDidChange:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleScrollerStyleDidChange:) name:@"NSPreferredScrollerStyleDidChangeNotification" object:nil];
            
        } else {
            
            // on 10.6, put it in the scroll view
            [scrollView setHasHorizontalScroller:YES];
            [scrollView setPlacards:[NSArray arrayWithObject:scalePopUpButton]];
            
        }
    }
}

- (void)scalePopUpAction:(id)sender {
    NSNumber *selectedFactorObject = [[sender selectedCell] representedObject];
    if(!selectedFactorObject)
        [super setAutoScales:YES];
    else
        [self setScaleFactor:[selectedFactorObject doubleValue] adjustPopup:NO];
}

- (NSUInteger)lowerIndexForScaleFactor:(CGFloat)scaleFactor {
    NSUInteger i, count = BDSKDefaultScaleMenuFactorsCount;
    for (i = count - 1; i > 0; i--) {
        if (scaleFactor * 1.01 > BDSKDefaultScaleMenuFactors[i])
            return i;
    }
    return 1;
}

- (NSUInteger)upperIndexForScaleFactor:(CGFloat)scaleFactor {
    NSUInteger i, count = BDSKDefaultScaleMenuFactorsCount;
    for (i = 1; i < count; i++) {
        if (scaleFactor * 0.99 < BDSKDefaultScaleMenuFactors[i])
            return i;
    }
    return count - 1;
}

- (NSUInteger)indexForScaleFactor:(CGFloat)scaleFactor {
    NSUInteger lower = [self lowerIndexForScaleFactor:scaleFactor], upper = [self upperIndexForScaleFactor:scaleFactor];
    if (upper > lower && scaleFactor < 0.5 * (BDSKDefaultScaleMenuFactors[lower] + BDSKDefaultScaleMenuFactors[upper]))
        return lower;
    return upper;
}

- (void)setScaleFactor:(CGFloat)newScaleFactor {
    NSView *docView = [[[self documentView] enclosingScrollView] documentView];
    NSPoint scrollPoint = [docView scrollPositionAsPercentage];
	[self setScaleFactor:newScaleFactor adjustPopup:YES];
    [docView setScrollPositionAsPercentage:scrollPoint];
}

- (void)setScaleFactor:(CGFloat)newScaleFactor adjustPopup:(BOOL)flag {
    
	if (flag) {
		if (newScaleFactor < 0.01) {
            newScaleFactor = 0.0;
        } else {
            NSUInteger i = [self indexForScaleFactor:newScaleFactor];
            [scalePopUpButton selectItemAtIndex:i];
            newScaleFactor = BDSKDefaultScaleMenuFactors[i];
        }
    }
    
    if(newScaleFactor < 0.01)
        [self setAutoScales:YES];
    else
        [super setScaleFactor:newScaleFactor];
}

- (void)setAutoScales:(BOOL)newAuto {
    [super setAutoScales:newAuto];
    
    if(newAuto)
		[scalePopUpButton selectItemAtIndex:0];
}

- (IBAction)zoomIn:(id)sender{
    if([self autoScales]){
        [super zoomIn:sender];
    }else{
        NSUInteger numberOfDefaultItems = BDSKDefaultScaleMenuFactorsCount;
        NSUInteger i = [self lowerIndexForScaleFactor:[self scaleFactor]];
        if (i < numberOfDefaultItems - 1) i++;
        [self setScaleFactor:BDSKDefaultScaleMenuFactors[i]];
    }
}

- (IBAction)zoomOut:(id)sender{
    if([self autoScales]){
        [super zoomOut:sender];
    }else{
        NSUInteger i = [self upperIndexForScaleFactor:[self scaleFactor]];
        if (i > 1) i--;
        [self setScaleFactor:BDSKDefaultScaleMenuFactors[i]];
    }
}

- (BOOL)canZoomIn{
    if ([super canZoomIn] == NO)
        return NO;
    if([self autoScales])   
        return YES;
    NSUInteger numberOfDefaultItems = BDSKDefaultScaleMenuFactorsCount;
    NSUInteger i = [self lowerIndexForScaleFactor:[self scaleFactor]];
    return i < numberOfDefaultItems - 1;
}

- (BOOL)canZoomOut{
    if ([super canZoomOut] == NO)
        return NO;
    if([self autoScales])   
        return YES;
    NSUInteger i = [self upperIndexForScaleFactor:[self scaleFactor]];
    return i > 1;
}

- (void)changeFont:(id)sender {
    switch ([sender currentFontAction]) {
        case NSSizeUpFontAction:
            if ([self canZoomIn])
                [self zoomIn:sender];
            else
                NSBeep();
            break;
        case NSSizeDownFontAction:
            if ([self canZoomOut])
                [self zoomOut:sender];
            else
                NSBeep();
            break;
        default:
            break;
    }
}

// PDFView steals key equivalents like Cmd-+/-, which it shouldn't do
- (BOOL)performKeyEquivalent:(NSEvent *)theEvent { return NO; }

#pragma mark Scrollview

- (NSScrollView *)scrollView;
{
    return [[self documentView] enclosingScrollView];
}

#pragma mark Gestures

- (void)beginGestureWithEvent:(NSEvent *)theEvent {
    if ([[BDSKZoomablePDFView superclass] instancesRespondToSelector:_cmd])
        [super beginGestureWithEvent:theEvent];
    startScale = [self scaleFactor];
}

- (void)endGestureWithEvent:(NSEvent *)theEvent {
    if (fabs(startScale - [self scaleFactor]) > 0.001)
        [self setScaleFactor:fmax([self scaleFactor], BDSKMinDefaultScaleMenuFactor)];
    if ([[BDSKZoomablePDFView superclass] instancesRespondToSelector:_cmd])
        [super endGestureWithEvent:theEvent];
}

- (void)magnifyWithEvent:(NSEvent *)theEvent {
    if ([theEvent respondsToSelector:@selector(magnification)]) {
        CGFloat magnifyFactor = (1.0 + fmax(-0.5, fmin(1.0 , [theEvent magnification])));
        [super setScaleFactor:magnifyFactor * [self scaleFactor]];
    }
}

@end

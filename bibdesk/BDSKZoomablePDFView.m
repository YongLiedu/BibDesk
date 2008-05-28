//
//  BDSKZoomablePDFView.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/23/05.
/*
 This software is Copyright (c) 2005-2008
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
#import <OmniAppKit/NSView-OAExtensions.h>
#import <OmniBase/OBUtilities.h>
#import "BDSKHeaderPopUpButton.h"
#import "NSString_BDSKExtensions.h"
#import <OmniFoundation/NSString-OFExtensions.h>
#import "NSURL_BDSKExtensions.h"
#import "NSScrollView_BDSKExtensions.h"


@implementation BDSKZoomablePDFView

/* For genstrings:
    NSLocalizedStringFromTable(@"Auto", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"10%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"25%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"50%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"75%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"100%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"128%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"200%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"400%", @"ZoomValues", @"Zoom popup entry")
    NSLocalizedStringFromTable(@"800%", @"ZoomValues", @"Zoom popup entry")
*/   
static NSString *BDSKDefaultScaleMenuLabels[] = {/* @"Set...", */ @"Auto", @"10%", @"25%", @"50%", @"75%", @"100%", @"128%", @"150%", @"200%", @"400%", @"800%"};
static float BDSKDefaultScaleMenuFactors[] = {/* 0.0, */ 0, 0.1, 0.25, 0.5, 0.75, 1.0, 1.28, 1.5, 2.0, 4.0, 8.0};
static float BDSKScaleMenuFontSize = 11.0;

#pragma mark Instance methods

- (id)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        scalePopUpButton = nil;
        [self makeScalePopUpButton];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        scalePopUpButton = nil;
        [self makeScalePopUpButton];
    }
    return self;
}

#pragma mark Copying

// override so we can put the entire document on the pasteboard if there is no selection
- (void)copy:(id)sender;
{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    [pboard declareTypes:[NSArray arrayWithObjects:NSPDFPboardType, NSStringPboardType, NSRTFPboardType, nil] owner:nil];
    
    PDFSelection *theSelection = [self currentSelection];
    if(!theSelection)
        theSelection = [[self document] selectionForEntireDocument];
    NSAttributedString *attrString = [theSelection attributedString];
    
    [pboard setData:[[self document] dataRepresentation] forType:NSPDFPboardType];
    [pboard setString:[attrString string] forType:NSStringPboardType];
    [pboard setData:[attrString RTFFromRange:NSMakeRange(0, [attrString length]) documentAttributes:nil] forType:NSRTFPboardType];
}

- (void)copyAsPDF:(id)sender;
{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    [pboard declareTypes:[NSArray arrayWithObjects:NSPDFPboardType, nil] owner:nil];
    [pboard setData:[[self document] dataRepresentation] forType:NSPDFPboardType];
}

- (void)copyAsText:(id)sender;
{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    [pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NSRTFPboardType, nil] owner:nil];
    
    PDFSelection *theSelection = [self currentSelection];
    if(!theSelection)
        theSelection = [[self document] selectionForEntireDocument];
    NSAttributedString *attrString = [theSelection attributedString];
    
    [pboard setString:[attrString string] forType:NSStringPboardType];
    [pboard setData:[attrString RTFFromRange:NSMakeRange(0, [attrString length]) documentAttributes:nil] forType:NSRTFPboardType];
}

- (void)copyPDFPage:(id)sender;
{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    [pboard declareTypes:[NSArray arrayWithObjects:NSPDFPboardType, nil] owner:self];
    [pboard setData:[[self currentPage] dataRepresentation] forType:NSPDFPboardType];
}

- (void)saveDocumentSheetDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode  contextInfo:(void  *)contextInfo;
{
    NSError *error = nil;
    if(returnCode == NSOKButton){
        // -[PDFDocument writeToURL:] returns YES even if you don't have write permission, so we'll use NSData rdar://problem/4475062
        NSData *data = [[self document] dataRepresentation];
        
        if([data writeToURL:[sheet URL] options:NSAtomicWrite error:&error] == NO){
            [sheet orderOut:nil];
            [self presentError:error];
        }
    }
}
    
- (void)saveDocumentAs:(id)sender;
{
    NSString *name = [[[self document] documentURL] lastPathComponent];
    [[NSSavePanel savePanel] beginSheetForDirectory:nil file:(name ? name : NSLocalizedString(@"Untitled.pdf", @"Default file name for saved PDF")) modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(saveDocumentSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
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

    NSString *title = (nil == [self currentSelection]) ? NSLocalizedString(@"Copy All Text", @"Menu item title") : NSLocalizedString(@"Copy Selected Text", @"Menu item title");
    
    item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:title action:@selector(copyAsText:) keyEquivalent:@""];
    [menu addItem:item];
    [item release];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    item = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Save PDF As", @"Menu item title") stringByAppendingEllipsis] action:@selector(saveDocumentAs:) keyEquivalent:@""];
    [menu addItem:item];
    [item release];

    return menu;
}

// Fix a bug in Tiger's PDFKit, tooltips lead to a crash when you reload a PDFDocument in a PDFView
// see http://www.cocoabuilder.com/archive/message/cocoa/2007/3/12/180190
- (void)scheduleAddingToolips {}
    
#pragma mark Popup button

- (void)makeScalePopUpButton {
    
    if (scalePopUpButton == nil) {
        
        NSScrollView *scrollView = [self scrollView];
        [scrollView setHasHorizontalScroller:YES];

        // create it        
        scalePopUpButton = [[BDSKHeaderPopUpButton allocWithZone:[self zone]] initWithFrame:NSMakeRect(0.0, 0.0, 1.0, 1.0) pullsDown:NO];
        
        NSControlSize controlSize = [[scrollView horizontalScroller] controlSize];
        [[scalePopUpButton cell] setControlSize:controlSize];

        // set a suitable font, the control size is 0, 1 or 2
        [scalePopUpButton setFont:[NSFont toolTipsFontOfSize: BDSKScaleMenuFontSize - controlSize]];

        unsigned cnt, numberOfDefaultItems = (sizeof(BDSKDefaultScaleMenuLabels) / sizeof(NSString *));
        id curItem;
        NSString *label;
        float width, maxWidth = 0.0;
        NSSize size = NSMakeSize(1000.0, 1000.0);
        NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:[scalePopUpButton font], NSFontAttributeName, nil];
        unsigned maxIndex = 0;
        
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
            [curItem setRepresentedObject:(BDSKDefaultScaleMenuFactors[cnt] > 0.0 ? [NSNumber numberWithFloat:BDSKDefaultScaleMenuFactors[cnt]] : nil)];
        }
        // select the appropriate item, adjusting the scaleFactor if necessary
        if([self autoScales])
            [self setScaleFactor:0.0 adjustPopup:YES];
        else
            [self setScaleFactor:[self scaleFactor] adjustPopup:YES];

        // Make sure the popup is big enough to fit the largest cell
        cnt = [scalePopUpButton indexOfSelectedItem];
        [scalePopUpButton selectItemAtIndex:maxIndex];
        [scalePopUpButton sizeToFit];
        [scalePopUpButton selectItemAtIndex:cnt];

		// don't let it become first responder
		[scalePopUpButton setRefusesFirstResponder:YES];

        // hook it up
        [scalePopUpButton setTarget:self];
        [scalePopUpButton setAction:@selector(scalePopUpAction:)];

        // put it in the scrollview
        [scrollView setPlacards:[NSArray arrayWithObject:scalePopUpButton]];
        [scalePopUpButton release];
    }
}

- (void)scalePopUpAction:(id)sender {
    NSNumber *selectedFactorObject = [[sender selectedCell] representedObject];
    if(!selectedFactorObject)
        [super setAutoScales:YES];
    else
        [self setScaleFactor:[selectedFactorObject floatValue] adjustPopup:NO];
}

- (void)setScaleFactor:(float)newScaleFactor {
    NSPoint scrollPoint = (NSPoint)[self scrollPositionAsPercentage];
	[self setScaleFactor:newScaleFactor adjustPopup:YES];
    [self setScrollPositionAsPercentage:scrollPoint];
}

- (void)setScaleFactor:(float)newScaleFactor adjustPopup:(BOOL)flag {
    
	if (flag) {
		if (newScaleFactor < 0.01) {
            newScaleFactor = 0.0;
        } else {
            unsigned cnt = 1, numberOfDefaultItems = (sizeof(BDSKDefaultScaleMenuFactors) / sizeof(float));
            
            // We only work with some preset zoom values, so choose one of the appropriate values
            while (cnt < numberOfDefaultItems - 1 && newScaleFactor > 0.5 * (BDSKDefaultScaleMenuFactors[cnt] + BDSKDefaultScaleMenuFactors[cnt + 1])) cnt++;
            [scalePopUpButton selectItemAtIndex:cnt];
            newScaleFactor = BDSKDefaultScaleMenuFactors[cnt];
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
        int cnt = 0, numberOfDefaultItems = (sizeof(BDSKDefaultScaleMenuFactors) / sizeof(float));
        float scaleFactor = [self scaleFactor];
        
        // We only work with some preset zoom values, so choose one of the appropriate values (Fudge a little for floating point == to work)
        while (cnt < numberOfDefaultItems && scaleFactor * .99 > BDSKDefaultScaleMenuFactors[cnt]) cnt++;
        cnt++;
        while (cnt >= numberOfDefaultItems) cnt--;
        [self setScaleFactor:BDSKDefaultScaleMenuFactors[cnt]];
    }
}

- (IBAction)zoomOut:(id)sender{
    if([self autoScales]){
        [super zoomOut:sender];
    }else{
        int cnt = 0, numberOfDefaultItems = (sizeof(BDSKDefaultScaleMenuFactors) / sizeof(float));
        float scaleFactor = [self scaleFactor];
        
        // We only work with some preset zoom values, so choose one of the appropriate values (Fudge a little for floating point == to work)
        while (cnt < numberOfDefaultItems && scaleFactor * .99 > BDSKDefaultScaleMenuFactors[cnt]) cnt++;
        cnt--;
        if (cnt < 0) cnt++;
        [self setScaleFactor:BDSKDefaultScaleMenuFactors[cnt]];
    }
}

- (BOOL)canZoomIn{
    if ([super canZoomIn] == NO)
        return NO;
    if([self autoScales])   
        return YES;
    unsigned cnt = 0, numberOfDefaultItems = (sizeof(BDSKDefaultScaleMenuFactors) / sizeof(float));
    float scaleFactor = [self scaleFactor];
    // We only work with some preset zoom values, so choose one of the appropriate values (Fudge a little for floating point == to work)
    while (cnt < numberOfDefaultItems && scaleFactor * .99 > BDSKDefaultScaleMenuFactors[cnt]) cnt++;
    return cnt < numberOfDefaultItems - 1;
}

- (BOOL)canZoomOut{
    if ([super canZoomOut] == NO)
        return NO;
    if([self autoScales])   
        return YES;
    unsigned cnt = 0, numberOfDefaultItems = (sizeof(BDSKDefaultScaleMenuFactors) / sizeof(float));
    float scaleFactor = [self scaleFactor];
    // We only work with some preset zoom values, so choose one of the appropriate values (Fudge a little for floating point == to work)
    while (cnt < numberOfDefaultItems && scaleFactor * .99 > BDSKDefaultScaleMenuFactors[cnt]) cnt++;
    return cnt > 0;
}

#pragma mark Scrollview

- (NSScrollView *)scrollView;
{
    return [[self documentView] enclosingScrollView];
}

- (void)setScrollerSize:(NSControlSize)controlSize;
{
    NSScrollView *scrollView = [[self documentView] enclosingScrollView];
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setHasVerticalScroller:YES];
    [[scrollView horizontalScroller] setControlSize:controlSize];
    [[scrollView verticalScroller] setControlSize:controlSize];
	if(scalePopUpButton){
		[[scalePopUpButton cell] setControlSize:controlSize];
        [scalePopUpButton setFont:[NSFont toolTipsFontOfSize: BDSKScaleMenuFontSize - controlSize]];
	}
}

@end

//
//  BDSKGroupCell.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 26/10/05.
/*
 This software is Copyright (c) 2005-2009
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKGroupCell.h"
#import "BDSKGroup.h"
#import "NSBezierPath_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import "NSGeometry_BDSKExtensions.h"
#import "NSParagraphStyle_BDSKExtensions.h"
#import "BDSKCFCallBacks.h"

static CFMutableDictionaryRef integerStringDictionary = NULL;

// names of these globals were changed to support key-value coding on BDSKGroup
NSString *BDSKGroupCellStringKey = @"stringValue";
NSString *BDSKGroupCellImageKey = @"icon";
NSString *BDSKGroupCellCountKey = @"numberValue";

@interface BDSKGroupCell (Private)
- (void)recacheCountAttributes;
@end

@implementation BDSKGroupCell

+ (void)initialize;
{
    BDSKINITIALIZE;
    
    if (NULL == integerStringDictionary) {
        integerStringDictionary = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kBDSKIntegerDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        int zero = 0;
        CFDictionaryAddValue(integerStringDictionary,  (const void *)&zero, CFSTR(""));
    }
    
}

- (id)init {
    if (self = [super initTextCell:[[[BDSKGroup alloc] initWithName:@"" count:0] autorelease]]) {
        
        [self setEditable:YES];
        [self setScrollable:YES];
        
        label = [[NSMutableAttributedString alloc] initWithString:@""];
        countString = [[NSMutableAttributedString alloc] initWithString:@""];
        
        countAttributes = [[NSMutableDictionary alloc] initWithCapacity:5];
        [self recacheCountAttributes];

    }
    return self;
}

// NSCoding

- (id)initWithCoder:(NSCoder *)coder {
	if (self = [super initWithCoder:coder]) {
        // recreates the dictionary
        countAttributes = [[NSMutableDictionary alloc] initWithCapacity:5];
        [self recacheCountAttributes];
        
        // could encode these, but presumably we want a fresh string
        label = [[NSMutableAttributedString alloc] initWithString:@""];
        countString = [[NSMutableAttributedString alloc] initWithString:@""];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[super encodeWithCoder:encoder];
}

// NSCopying

- (id)copyWithZone:(NSZone *)zone {
    BDSKGroupCell *copy = [super copyWithZone:zone];

    // count attributes are shared between this cell and all copies, but not with new instances
    copy->countAttributes = [countAttributes retain];
    copy->label = [label mutableCopy];
    copy->countString = [countString mutableCopy];

    return copy;
}

- (void)dealloc {
    [label release];
    [countString release];
    [countAttributes release];
	[super dealloc];
}

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
{
    return nil;
}

- (NSColor *)textColor;
{
    if (settingUpFieldEditor)
        return [NSColor textColor];
    else if (_cFlags.highlighted)
        return [NSColor textBackgroundColor];
    else
        return [super textColor];
}

- (void)setFont:(NSFont *)font {
    [super setFont:font];
    [self recacheCountAttributes];
}


// all the -[NSNumber stringValue] does is create a string with a localized format description, so we'll cache more strings than Foundation does, since this shows up in Shark as a bottleneck
static NSString *stringWithInteger(int count)
{
    CFStringRef string;
    if (CFDictionaryGetValueIfPresent(integerStringDictionary, (const void *)&count, (const void **)&string) == FALSE) {
        string = CFStringCreateWithFormat(CFAllocatorGetDefault(), NULL, CFSTR("%d"), count);
        CFDictionaryAddValue(integerStringDictionary, (const void *)&count, (const void *)string);
        CFRelease(string);
    }
    return (NSString *)string;
}

- (void)setObjectValue:(id <NSObject, NSCopying>)obj {
    // we should not set a derived value such as the group name here, otherwise NSTableView will call tableView:setObjectValue:forTableColumn:row: whenever a cell is selected
    BDSKASSERT([obj isKindOfClass:[BDSKGroup class]]);
    
    [super setObjectValue:obj];
    
    [label replaceCharactersInRange:NSMakeRange(0, [label length]) withString:obj == nil ? @"" : [(BDSKGroup *)obj stringValue]];
    [countString replaceCharactersInRange:NSMakeRange(0, [countString length]) withString:stringWithInteger([(BDSKGroup *)obj count])];
}

#pragma mark Drawing

#define BORDER_BETWEEN_EDGE_AND_IMAGE (2.0)
#define BORDER_BETWEEN_IMAGE_AND_TEXT (3.0)
#define SIZE_OF_TEXT_FIELD_BORDER (1.0)
#define BORDER_BETWEEN_EDGE_AND_COUNT (2.0)
#define BORDER_BETWEEN_COUNT_AND_TEXT (1.0)

- (NSSize)iconSizeForBounds:(NSRect)aRect;
{
    return NSMakeSize(NSHeight(aRect) + 1, NSHeight(aRect) + 1);
}

- (NSRect)iconRectForBounds:(NSRect)aRect;
{
    NSSize imageSize = [self iconSizeForBounds:aRect];
    NSRect imageRect, ignored;
    NSDivideRect(aRect, &ignored, &imageRect, BORDER_BETWEEN_EDGE_AND_IMAGE, NSMinXEdge);
    NSDivideRect(imageRect, &imageRect, &ignored, imageSize.width, NSMinXEdge);
    return imageRect;
}

// compute the oval padding based on the overall height of the cell
- (float)countPaddingForCellSize:(NSSize)aSize;
{
    return ([[self objectValue] failedDownload] || [[self objectValue] isRetrieving]) ? 1.0 : 0.5 * aSize.height + 0.5;
}

- (NSRect)countRectForBounds:(NSRect)aRect;
{
    NSSize countSize = NSZeroSize;
    
    float countSep = [self countPaddingForCellSize:aRect.size];
    if([[self objectValue] failedDownload] || [[self objectValue] isRetrieving]) {
        countSize = NSMakeSize(16, 16);
    }
    else if([[self objectValue] count] > 0) {
        countSize = [countString boundingRectWithSize:aRect.size options:0].size;
    }
    NSRect countRect, ignored;
    // set countRect origin to the string drawing origin (number has countSep on either side for oval padding)
    NSDivideRect(aRect, &countRect, &ignored, countSize.width + countSep + BORDER_BETWEEN_EDGE_AND_COUNT, NSMaxXEdge);
    // now set the size of it to the string size
    countRect.size = countSize;
    return countRect;
}    

- (NSRect)textRectForBounds:(NSRect)aRect;
{
    NSRect textRect = aRect;
    textRect.origin.x = NSMaxX([self iconRectForBounds:aRect]) + BORDER_BETWEEN_IMAGE_AND_TEXT;
    textRect.size.width = NSMinX([self countRectForBounds:aRect]) - BORDER_BETWEEN_COUNT_AND_TEXT - [self countPaddingForCellSize:aRect.size] - NSMinX(textRect);
    return textRect;
}

- (NSSize)cellSize;
{
    NSSize cellSize = [super cellSize];
    NSSize countSize = NSZeroSize;
    float countSep = [self countPaddingForCellSize:cellSize];
    if ([[self objectValue] isRetrieving] || [[self objectValue] failedDownload]) {
        countSize = NSMakeSize(16, 16);
    }
    else if ([[self objectValue] count] > 0) {
        countSize = [countString boundingRectWithSize:cellSize options:0].size;
    }
    float countWidth = countSize.width + 2 * countSep + BORDER_BETWEEN_EDGE_AND_COUNT;
    // cellSize.height approximates the icon size
    cellSize.width += cellSize.height + countWidth;
    cellSize.width += BORDER_BETWEEN_EDGE_AND_IMAGE + BORDER_BETWEEN_IMAGE_AND_TEXT + BORDER_BETWEEN_COUNT_AND_TEXT;
    return cellSize;
}

- (void)drawInteriorWithFrame:(NSRect)aRect inView:(NSView *)controlView {

    NSRange labelRange = NSMakeRange(0, [label length]);
    [label addAttribute:NSFontAttributeName value:[self font] range:labelRange];
    [label addAttribute:NSForegroundColorAttributeName value:[self textColor] range:labelRange];
        	
	NSColor *highlightColor = [self highlightColorWithFrame:aRect inView:controlView];
	BOOL highlighted = [self isHighlighted];
	NSColor *bgColor = [NSColor disabledControlTextColor];
    NSRange countRange = NSMakeRange(0, [countString length]);
    [countString addAttributes:countAttributes range:countRange];

	if (highlighted) {
		// add the alternate text color attribute.
		if ([highlightColor isEqual:[NSColor alternateSelectedControlColor]])
			[label addAttribute:NSForegroundColorAttributeName value:[NSColor alternateSelectedControlTextColor] range:labelRange];
		[countString addAttribute:NSForegroundColorAttributeName value:[NSColor disabledControlTextColor] range:countRange];
		bgColor = [[NSColor alternateSelectedControlTextColor] colorWithAlphaComponent:0.8];
	} else {
		[countString addAttribute:NSForegroundColorAttributeName value:[NSColor alternateSelectedControlTextColor] range:countRange];
		bgColor = [bgColor colorWithAlphaComponent:0.7];
	}

    // Draw the text
    // @@ Mail.app uses NSLineBreakByTruncatingTail for this
    [label addAttribute:NSParagraphStyleAttributeName value:[NSParagraphStyle defaultTruncatingTailParagraphStyle] range:labelRange];
    NSRect textRect = NSInsetRect([self textRectForBounds:aRect], SIZE_OF_TEXT_FIELD_BORDER, 0.0); 
    
    [label drawWithRect:textRect options:NSStringDrawingUsesLineFragmentOrigin];
    
    BOOL controlViewIsFlipped = [controlView isFlipped];
    NSRect countRect = [self countRectForBounds:aRect];
    
    if ([[self objectValue] isRetrieving] == NO) {
        if ([[self objectValue] failedDownload]) {
            NSImage *cautionImage = [NSImage imageNamed:@"BDSKSmallCautionIcon"];
            NSSize cautionImageSize = [cautionImage size];
            NSRect cautionIconRect = NSMakeRect(0, 0, cautionImageSize.width, cautionImageSize.height);
            [cautionImage drawFlipped:controlViewIsFlipped inRect:countRect fromRect:cautionIconRect operation:NSCompositeSourceOver fraction:1.0];
        } else if ([[self objectValue] count] > 0) {
            [NSGraphicsContext saveGraphicsState];
            [bgColor setFill];
            [NSBezierPath fillHorizontalOvalAroundRect:countRect];
            [NSGraphicsContext restoreGraphicsState];

            [countString drawWithRect:countRect options:NSStringDrawingUsesLineFragmentOrigin];
        }
    }
    
    // Draw the image
    NSRect imageRect = BDSKCenterRect([self iconRectForBounds:aRect], [self iconSizeForBounds:aRect], controlViewIsFlipped);
    [NSGraphicsContext saveGraphicsState];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    [[[self objectValue] icon] drawFlipped:controlViewIsFlipped inRect:imageRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength;
{
    
    settingUpFieldEditor = YES;
    [super selectWithFrame:[self textRectForBounds:aRect] inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
    settingUpFieldEditor = NO;
}

- (NSUInteger)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView
{
    NSUInteger hit = [super hitTestForEvent:event inRect:cellFrame ofView:controlView];
    // super returns 0 for button clicks, so -[NSTableView mouseDown:] doesn't track the cell
    NSRect iconRect = [self iconRectForBounds:cellFrame];
    NSPoint mouseLoc = [controlView convertPoint:[event locationInWindow] fromView:nil];
    if (NSMouseInRect(mouseLoc, iconRect, [controlView isFlipped]))
        hit = NSCellHitContentArea;
    return hit;
}

@end

@implementation BDSKGroupCell (Private)

- (void)recacheCountAttributes {
	NSFont *countFont = [NSFont fontWithName:@"Helvetica-Bold" size:([[self font] pointSize] - 1)] ?: [NSFont boldSystemFontOfSize:([[self font] pointSize] - 1)];
	BDSKPRECONDITION(countFont);     

	[countAttributes removeAllObjects];
    [countAttributes setObject:[NSColor alternateSelectedControlTextColor] forKey:NSForegroundColorAttributeName];
    [countAttributes setObject:countFont forKey:NSFontAttributeName];
    [countAttributes setObject:[NSNumber numberWithFloat:-1.0] forKey:NSKernAttributeName];
    [countAttributes setObject:[NSParagraphStyle defaultClippingParagraphStyle] forKey:NSParagraphStyleAttributeName];
}

@end

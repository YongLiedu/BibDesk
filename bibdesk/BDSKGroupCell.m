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
#import "NSBezierPath_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import "NSGeometry_BDSKExtensions.h"
#import "NSString_BDSKExtensions.h"
#import "NSParagraphStyle_BDSKExtensions.h"
#import "BDSKCenterScaledImageCell.h"


// names of these globals were changed to support key-value coding on BDSKGroup
NSString *BDSKGroupCellStringKey = @"stringValue";
NSString *BDSKGroupCellEditingStringKey = @"editingStringValue";
NSString *BDSKGroupCellImageKey = @"icon";
NSString *BDSKGroupCellCountKey = @"numberValue";
NSString *BDSKGroupCellIsRetrievingKey = @"isRetrieving";
NSString *BDSKGroupCellFailedDownloadKey = @"failedDownload";

static id nonNullObjectValueForKey(id object, NSString *key) {
    id value = [object valueForKey:key];
    return [value isEqual:[NSNull null]] ? nil : value;
}

@interface BDSKGroupCellFormatter : NSFormatter
@end

#pragma mark

@interface BDSKGroupCell (Private)
- (void)recacheCountAttributes;
- (NSImage *)icon;
- (int)count;
- (BOOL)isRetrieving;
- (BOOL)failedDownload;
@end

@implementation BDSKGroupCell

static NSMutableDictionary *numberStringDictionary = nil;
static BDSKGroupCellFormatter *groupCellFormatter = nil;

+ (void)initialize;
{
    BDSKINITIALIZE;
    
    numberStringDictionary = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@"", [NSNumber numberWithInt:0], nil];
    groupCellFormatter = [[BDSKGroupCellFormatter alloc] init];
    
}

- (id)init {
    if (self = [super initTextCell:@""]) {
        
        [self setEditable:YES];
        [self setScrollable:YES];
        
        label = [[NSMutableAttributedString alloc] initWithString:@""];
        countString = [[NSMutableAttributedString alloc] initWithString:@""];
        
        countAttributes = [[NSMutableDictionary alloc] initWithCapacity:5];
        [self recacheCountAttributes];

        [self setFormatter:groupCellFormatter];
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
        
        if ([self formatter] == nil)
            [self setFormatter:groupCellFormatter];
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
    NSColor *color = nil;
    
    // this allows the expansion tooltips on 10.5 to draw with the correct color
#if defined(MAC_OS_X_VERSION_10_5) && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
    // on 10.5, we can just check background style instead of messing around with flags and checking the highlight color, which accounts for much of the code in this class
#warning 10.5 fixme
#endif
    if ([self respondsToSelector:@selector(backgroundStyle)] && NSBackgroundStyleLight == [self backgroundStyle])
        return [self isHighlighted] ? [NSColor textBackgroundColor] : [NSColor blackColor];
        
    if (settingUpFieldEditor)
        color = [NSColor blackColor];
    else if ([self isHighlighted])
        color = [NSColor textBackgroundColor];
    else
        color = [super textColor];
    return color;
}

- (void)setFont:(NSFont *)font {
    [super setFont:font];
    [self recacheCountAttributes];
    [countString addAttributes:countAttributes range:NSMakeRange(0, [countString length])];
}


// all the -[NSNumber stringValue] does is create a string with a localized format description, so we'll cache more strings than Foundation does, since this shows up in Shark as a bottleneck
static NSString *stringWithNumber(NSNumber *number)
{
    if (number == nil)
        return @"";
    NSString *string = [numberStringDictionary objectForKey:number];
    if (string == nil) {
        string = [number stringValue];
        [numberStringDictionary setObject:string forKey:number];
    }
    return string;
}

- (void)setObjectValue:(id <NSCopying>)obj {
    // we should not set a derived value such as the group name here, otherwise NSTableView will call tableView:setObjectValue:forTableColumn:row: whenever a cell is selected
    
    // this can happen initially from the init, as there's no initializer passing an objectValue
    if ([(id)obj isKindOfClass:[NSString class]])
        obj = [NSDictionary dictionaryWithObjectsAndKeys:obj, BDSKGroupCellStringKey, nil];
    
    [super setObjectValue:obj];
    
    [label replaceCharactersInRange:NSMakeRange(0, [label length]) withString:nonNullObjectValueForKey(obj, BDSKGroupCellStringKey) ?: @""];
    [countString replaceCharactersInRange:NSMakeRange(0, [countString length]) withString:stringWithNumber(nonNullObjectValueForKey(obj, BDSKGroupCellCountKey))];
    [countString addAttributes:countAttributes range:NSMakeRange(0, [countString length])];
}

#pragma mark Drawing

#define BORDER_BETWEEN_EDGE_AND_IMAGE (3.0)
#define BORDER_BETWEEN_IMAGE_AND_TEXT (3.0)
#define SIZE_OF_TEXT_FIELD_BORDER (1.0)
#define BORDER_BETWEEN_EDGE_AND_COUNT (2.0)
#define BORDER_BETWEEN_COUNT_AND_TEXT (1.0)
#define IMAGE_OFFSET (1.0)

- (NSSize)iconSizeForBounds:(NSRect)aRect;
{
    return NSMakeSize(NSHeight(aRect) - 1.0, NSHeight(aRect) - 1.0);
}

- (NSRect)iconRectForBounds:(NSRect)aRect;
{
    NSSize imageSize = [self iconSizeForBounds:aRect];
    NSRect imageRect, ignored;
    NSDivideRect(aRect, &ignored, &imageRect, BORDER_BETWEEN_EDGE_AND_IMAGE, NSMinXEdge);
    NSDivideRect(imageRect, &imageRect, &ignored, imageSize.width, NSMinXEdge);
    return imageRect;
}

- (NSRect)countRectForBounds:(NSRect)aRect;
{
    NSSize countSize = NSZeroSize;
    
    if([self failedDownload] || [self isRetrieving]) {
        countSize = NSMakeSize(16.0, 16.0);
    } else if ([self count] > 0) {
        countSize = [countString boundingRectWithSize:aRect.size options:0].size;
        countSize.width += [self count] < 100 ? countSize.height : 0.5 * countSize.height; // add oval pading around count
    }
    NSRect countRect, ignored;
    if (countSize.width > 0.0) {
        NSDivideRect(aRect, &ignored, &countRect, BORDER_BETWEEN_EDGE_AND_COUNT, NSMaxXEdge);
        NSDivideRect(countRect, &countRect, &ignored, countSize.width, NSMaxXEdge);
        // now set the size of it to the string size
        countRect = BDSKCenterRect(countRect, countSize, YES);
    } else {
        NSDivideRect(aRect, &countRect, &ignored, 0.0, NSMaxXEdge);
    }
    return countRect;
}    

- (NSRect)textRectForBounds:(NSRect)aRect;
{
    NSRect textRect = aRect, countRect = [self countRectForBounds:aRect];
    textRect.origin.x = NSMaxX([self iconRectForBounds:aRect]) + BORDER_BETWEEN_IMAGE_AND_TEXT;
    if (NSWidth(countRect) > 0.0)
        textRect.size.width = NSMinX(countRect) - BORDER_BETWEEN_COUNT_AND_TEXT - NSMinX(textRect);
    else
        textRect.size.width = NSMaxX(aRect) - NSMinX(textRect);
    return textRect;
}

- (NSSize)cellSize;
{
    NSSize cellSize = [super cellSize];
    NSSize countSize = NSZeroSize;
    if ([self isRetrieving] || [self failedDownload]) {
        countSize = NSMakeSize(16, 16);
    } else if ([self count] > 0) {
        countSize = [countString boundingRectWithSize:cellSize options:0].size;
        countSize.width += countSize.height;
    }
    // cellSize.height approximates the icon size
    cellSize.width += BORDER_BETWEEN_EDGE_AND_IMAGE + cellSize.height + BORDER_BETWEEN_IMAGE_AND_TEXT;
    if (countSize.width > 0.0)
        cellSize.width += BORDER_BETWEEN_COUNT_AND_TEXT + countSize.width + BORDER_BETWEEN_EDGE_AND_COUNT;
    return cellSize;
}

- (void)drawInteriorWithFrame:(NSRect)aRect inView:(NSView *)controlView {
    // Draw the text
    NSRect textRect = NSInsetRect([self textRectForBounds:aRect], SIZE_OF_TEXT_FIELD_BORDER, 0.0); 
    NSRange labelRange = NSMakeRange(0, [label length]);
    NSFont *font = [self font];
    BOOL isHighlighted = [self isHighlighted];
    if ([self respondsToSelector:@selector(backgroundStyle)])
        isHighlighted = ([self backgroundStyle] == NSBackgroundStyleDark || [self backgroundStyle] == NSBackgroundStyleLowered);
    
    if (isHighlighted) {
        font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSBoldFontMask];
        NSShadow *shade = [[NSShadow alloc] init];
        [shade setShadowOffset:NSMakeSize(0.0, -1.0)];
        [shade setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.5]];
        [label addAttribute:NSShadowAttributeName value:shade range:labelRange];
        [shade release];
    } else {
        [label removeAttribute:NSShadowAttributeName range:labelRange];
    }
    [label addAttribute:NSFontAttributeName value:font range:labelRange];
    [label addAttribute:NSForegroundColorAttributeName value:[self textColor] range:labelRange];
    [label addAttribute:NSParagraphStyleAttributeName value:[NSParagraphStyle defaultTruncatingTailParagraphStyle] range:labelRange];
    
    [label drawWithRect:textRect options:NSStringDrawingUsesLineFragmentOrigin];
    
    if ([self isRetrieving] == NO) {
        NSRect countRect = [self countRectForBounds:aRect];
        int count = [self count];
        if ([self failedDownload]) {
            [self drawIcon:[NSImage imageNamed:@"BDSKSmallCautionIcon"] withFrame:countRect inView:controlView];
        } else if (count > 0) {
            float countInset = count < 100 ? 0.5 * NSHeight(countRect) : 0.25 * NSHeight(countRect);
            NSColor *fgColor;
            NSColor *bgColor;
            if ([controlView respondsToSelector:@selector(setSelectionHighlightStyle:)]) {
                if ([[controlView window] isMainWindow] == NO) {
                    if (isHighlighted) {
                        fgColor = [NSColor colorWithDeviceRed:40606.0/65535.0 green:40606.0/65535.0 blue:40606.0/65535.0 alpha:1.0];
                        bgColor = [NSColor colorWithDeviceWhite:1.0 alpha:0.95];
                    } else {
                        fgColor = [NSColor colorWithDeviceWhite:1.0 alpha:1.0];
                        bgColor = [NSColor colorWithDeviceRed:40606.0/65535.0 green:40606.0/65535.0 blue:40606.0/65535.0 alpha:0.95];
                    }
                } else if ([[controlView window] isKeyWindow] && [[controlView window] firstResponder] == controlView) {
                    if (isHighlighted) {
                        fgColor = [NSColor colorWithDeviceRed:14135.0/65535.0 green:29298.0/65535.0 blue:48830.0/65535.0 alpha:1.0];
                        bgColor = [NSColor colorWithDeviceWhite:1.0 alpha:0.95];
                    } else {
                        fgColor = [NSColor colorWithDeviceWhite:1.0 alpha:1.0];
                        bgColor = [NSColor colorWithDeviceRed:34695.0/65535.0 green:39064.0/65535.0 blue:48316.0/65535.0 alpha:0.95];
                    }
                } else {
                    if (isHighlighted) {
                        fgColor = [NSColor colorWithDeviceRed:34695.0/65535.0 green:39064.0/65535.0 blue:48316.0/65535.0 alpha:1.0];
                        bgColor = [NSColor colorWithDeviceWhite:1.0 alpha:0.95];
                    } else {
                        fgColor = [NSColor colorWithDeviceWhite:1.0 alpha:1.0];
                        bgColor = [NSColor colorWithDeviceRed:34695.0/65535.0 green:39064.0/65535.0 blue:48316.0/65535.0 alpha:0.95];
                    }
                }
            } else {
                if (isHighlighted) {
                    fgColor = [NSColor disabledControlTextColor];
                    bgColor = [NSColor colorWithDeviceWhite:1.0 alpha:0.8];
                } else {
                    fgColor = [NSColor colorWithDeviceWhite:1.0 alpha:1.0];
                    bgColor = [[NSColor disabledControlTextColor] colorWithAlphaComponent:0.7];
                }
            }
            
            [NSGraphicsContext saveGraphicsState];
            [bgColor setFill];
            [NSBezierPath fillHorizontalOvalInRect:countRect];
            [NSGraphicsContext restoreGraphicsState];
            
            [countString addAttribute:NSForegroundColorAttributeName value:fgColor range:NSMakeRange(0, [countString length])];
            [countString drawWithRect:NSInsetRect(countRect, countInset, 0.0) options:NSStringDrawingUsesLineFragmentOrigin];
        }
    }
    
    // Draw the image
    NSRect imageRect = BDSKCenterRect([self iconRectForBounds:aRect], [self iconSizeForBounds:aRect], [controlView isFlipped]);
    imageRect.origin.y += [controlView isFlipped] ? -IMAGE_OFFSET : IMAGE_OFFSET;
    if ([self icon])
        [self drawIcon:[self icon] withFrame:imageRect inView:controlView];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength;
{
    
    settingUpFieldEditor = YES;
    [super selectWithFrame:[self textRectForBounds:aRect] inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
    settingUpFieldEditor = NO;
}

- (NSUInteger)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView
{
    NSRect textRect = [self textRectForBounds:cellFrame];
    NSPoint mouseLoc = [controlView convertPoint:[event locationInWindow] fromView:nil];
    NSUInteger hit = NSCellHitNone;
    if (NSMouseInRect(mouseLoc, textRect, [controlView isFlipped]))
        hit = [super hitTestForEvent:event inRect:textRect ofView:controlView];
    else if (NSMouseInRect(mouseLoc, [self iconRectForBounds:cellFrame], [controlView isFlipped]))
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

- (NSImage *)icon {
    return nonNullObjectValueForKey([self objectValue], BDSKGroupCellImageKey);
}

- (int)count {
    return [nonNullObjectValueForKey([self objectValue], BDSKGroupCellCountKey) intValue];
}

- (BOOL)isRetrieving {
    return [nonNullObjectValueForKey([self objectValue], BDSKGroupCellIsRetrievingKey) boolValue];
}

- (BOOL)failedDownload {
    return [nonNullObjectValueForKey([self objectValue], BDSKGroupCellFailedDownloadKey) boolValue];
}

@end

#pragma mark -

@implementation BDSKGroupCellFormatter

// this is actually never used, as BDSKGroupCell doesn't go through the formatter for display
- (NSString *)stringForObjectValue:(id)obj{
    BDSKASSERT([obj isKindOfClass:[NSDictionary class]]);
    return [obj isKindOfClass:[NSString class]] ? obj : nonNullObjectValueForKey(obj, BDSKGroupCellStringKey);
}

- (NSString *)editingStringForObjectValue:(id)obj{
    BDSKASSERT([obj isKindOfClass:[NSDictionary class]]);
    return nonNullObjectValueForKey(obj, BDSKGroupCellEditingStringKey) ?: nonNullObjectValueForKey(obj, BDSKGroupCellStringKey);
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error{
    // even though 'string' is reported as immutable, it's actually changed after this method returns and before it's returned by the control!
    string = [[string copy] autorelease];
    *obj = [NSDictionary dictionaryWithObjectsAndKeys:string, BDSKGroupCellStringKey, string, BDSKGroupCellEditingStringKey, nil];
    return YES;
}

@end

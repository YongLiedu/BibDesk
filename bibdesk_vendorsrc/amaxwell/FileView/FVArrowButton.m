//
//  FVArrowButton.m
//  FileViewTest
//
//  Created by Adam Maxwell on 09/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "FVArrowButton.h"

static NSBezierPath *rightArrowBezierPathWithSize(NSSize size);

enum {
    FVArrowLeft,
    FVArrowRight
};

@interface FVArrowButtonCell : NSButtonCell
@end

@implementation FVArrowButtonCell

- (id)init
{
    self = [super init];
    // handle highlight drawing manually, since NSButtonCell draws a rectangular background mask
    [self setHighlightsBy:NSNoCellMask];
    return self;
}

- (void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView;
{
    if ([self isHighlighted]) {
        // could check to see if [controlView isFlipped], but the icon is symmetric
        [image drawInRect:frame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [[NSColor colorWithCalibratedWhite:0.5 alpha:0.5] setFill];
        [[NSBezierPath bezierPathWithOvalInRect:frame] fill];
    }
    else {
        [super drawImage:image withFrame:frame inView:controlView];
        
        if ([self isEnabled] == NO) {
            [NSGraphicsContext saveGraphicsState];
            [[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] setFill];
            [[NSBezierPath bezierPathWithOvalInRect:frame] fill];
            [NSGraphicsContext restoreGraphicsState];
        }
    }
}

@end

@implementation FVArrowButton

+ (Class)cellClass { return [FVArrowButtonCell class]; }

- (NSImage *)rightArrowImage;
{
    NSSize size = [self frame].size;
    NSImage *image = [[NSImage alloc] initWithSize:size];
    [image lockFocus];
    
    NSRect arrowRect = NSZeroRect;
    arrowRect.size = size;
    
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:arrowRect];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.3] setFill];
    [circle fill];
    
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.7] setFill];
    [rightArrowBezierPathWithSize(size) fill];
    
    [image unlockFocus];
    return [image autorelease];
}

- (NSImage *)leftArrowImage;
{
    NSSize size = [self frame].size;
    NSImage *image = [[NSImage alloc] initWithSize:size];
    
    NSRect arrowRect = NSZeroRect;
    arrowRect.size = size;
    
    [image lockFocus];
    
    // reverse the CTM so the arrow points left
    CGContextRef ctxt = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextTranslateCTM(ctxt, size.width, 0);
    CGContextScaleCTM(ctxt, -1, 1);
    
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:arrowRect];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.3] setFill];
    [circle fill];
    
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.7] setFill];
    [rightArrowBezierPathWithSize(size) fill];
    
    [image unlockFocus];
    
    return [image autorelease];
}

+ (id)newLeftArrowWithSize:(NSSize)size;
{
    FVArrowButton *button = [[self allocWithZone:[self zone]] initWithFrame:NSMakeRect(0,0,size.width,size.height)];
    [button setImage:[button leftArrowImage]];
    [button setImagePosition:NSImageOnly];
    [button setBordered:NO];
    button->_arrowDirection = FVArrowLeft;
    return button;
}

+ (id)newRightArrowWithSize:(NSSize)size;
{
    FVArrowButton *button = [[self allocWithZone:[self zone]] initWithFrame:NSMakeRect(0,0,size.width,size.height)];
    [button setImage:[button rightArrowImage]];
    [button setImagePosition:NSImageOnly];
    [button setBordered:NO];
    button->_arrowDirection = FVArrowRight;
    return button;    
}

// any time the frame changes, create a new image at the correct size
- (void)setFrame:(NSRect)aFrame
{
    [super setFrame:aFrame];
    [self setImage:(FVArrowLeft == _arrowDirection ? [self leftArrowImage] : [self rightArrowImage])];
}

// Modify mouseDown: behavior slightly.  Wince this control is superimposed on another pseudo-control (the FileView), we want to avoid passing some events to the next responder.
- (void)mouseDown:(NSEvent *)event
{
    // convert double-clicks to a single-click event, so you can click the button rapidly without passing a double-click to the FileView
    if ([event clickCount] > 1) {
        NSEvent *newEvent;
        newEvent = [NSEvent mouseEventWithType:[event type]
                                      location:[event locationInWindow]
                                 modifierFlags:[event modifierFlags]
                                     timestamp:[event timestamp]
                                  windowNumber:[event windowNumber]
                                       context:[event context]
                                   eventNumber:([event eventNumber] + 1)
                                    clickCount:1
                                      pressure:[event pressure]]; 
        event = newEvent;
    }
    
    // swallow clicks when disabled to avoid changing FileView selection
    if ([self isEnabled])
        [super mouseDown:event];
}

@end

static NSBezierPath *rightArrowBezierPathWithSize(NSSize size)
{
    CGFloat w = size.width, h = size.height;
    NSBezierPath *arrow = [NSBezierPath bezierPath];
    [arrow moveToPoint:NSMakePoint(3.0/16.0*w, 6.0/16.0*h)];
    [arrow lineToPoint:NSMakePoint(3.0/16.0*w, 10.0/16.0*h)];
    [arrow lineToPoint:NSMakePoint(8.0/16.0*w, 10.0/16.0*h)];
    
    // top point of triangle
    [arrow lineToPoint:NSMakePoint(8.0/16.0*w, 13.0/16.0*h)];
    // right point of triangle
    [arrow lineToPoint:NSMakePoint(14.0/16.0*w, 8.0/16.0*h)];
    // bottom point of triangle
    [arrow lineToPoint:NSMakePoint(8.0/16.0*w, 3.0/16.0*h)];
    
    [arrow lineToPoint:NSMakePoint(8.0/16.0*w, 6.0/16.0*h)];
    [arrow closePath];
    return arrow;
}

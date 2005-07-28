#import "RYZImagePopUpButton.h"
#import "RYZImagePopUpButtonCell.h"


@implementation RYZImagePopUpButton

// -----------------------------------------
//	Initialization and termination
// -----------------------------------------

+ (Class)cellClass
{
    return [RYZImagePopUpButtonCell class];
}

// --------------------------------------------
//      Initializing in IB
// --------------------------------------------

- (id)initWithCoder:(NSCoder *)coder
{
	if (self = [super initWithCoder:coder]) {
		if (![[self cell] isKindOfClass:[RYZImagePopUpButtonCell class]]) {
			RYZImagePopUpButtonCell *cell = [[[RYZImagePopUpButtonCell alloc] init] autorelease];
			
			if ([self image] != nil) {
				[cell setIconImage:[self image]];
				[cell setIconSize:[[self image] size]];
			}
			if ([self menu] != nil) {
				if ([self pullsDown])	
					[[self menu] removeItemAtIndex:0];
				[cell setMenu:[self menu]];
			}
			[self setCell:cell];
		}
	}
	return self;
}

// --------------------------------------------
//      Getting and setting the icon size
// --------------------------------------------

- (NSSize)iconSize
{
    return [[self cell] iconSize];
}


- (void) setIconSize:(NSSize)iconSize
{
    [[self cell] setIconSize:iconSize];
}


// ---------------------------------------------------------------------------------
//      Getting and setting whether the menu is shown when the icon is clicked
// ---------------------------------------------------------------------------------

- (BOOL)showsMenuWhenIconClicked
{
    return [[self cell] showsMenuWhenIconClicked];
}


- (void)setShowsMenuWhenIconClicked:(BOOL)showsMenuWhenIconClicked
{
    [[self cell] setShowsMenuWhenIconClicked: showsMenuWhenIconClicked];
}


// ---------------------------------------------
//      Getting and setting the icon image
// ---------------------------------------------

- (NSImage *)iconImage
{
    return [[self cell] iconImage];
}
- (void)fadeIconImageToImage:(NSImage *)iconImage;
{

    if(![self iconImage]){
        [self setIconImage:iconImage];
        return;
    }
    
    alpha = 0;
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0/30.0  target:self selector:@selector(timerFired:)  userInfo:iconImage  repeats:YES];    
    [[NSRunLoop currentRunLoop] addTimer:timer  forMode:NSDefaultRunLoopMode];
    [[NSRunLoop currentRunLoop] addTimer:timer  forMode:NSEventTrackingRunLoopMode];
}

- (void)timerFired:(NSTimer *)timer;
{
    if(alpha >= 0.99){
        [timer invalidate];
        return;
    }

    NSImage *newImage = [timer userInfo];
    NSImage *oldImage = [self iconImage];
    alpha += 0.1;
    [oldImage lockFocus];
    [oldImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy fraction:(1 - alpha/3)];
    [newImage compositeToPoint:NSZeroPoint operation:NSCompositeDestinationOver fraction:alpha];
    [oldImage unlockFocus];
    [self setIconImage:oldImage];
}

- (void)setIconImage:(NSImage *)iconImage
{
    [[self cell] setIconImage: iconImage];
	[self setNeedsDisplay:YES];
}


// ----------------------------------------------
//      Getting and setting the arrow image
// ----------------------------------------------

- (NSImage *)arrowImage
{
    return [[self cell] arrowImage];
	[self setNeedsDisplay:YES];
}


- (void)setArrowImage:(NSImage *)arrowImage
{
    [[self cell] setArrowImage: arrowImage];
}


// ----------------------------------------------
//      Getting and setting the action enabled flag
// ----------------------------------------------

- (BOOL)iconActionEnabled
{
    return [[self cell] iconActionEnabled];
}


- (void)setIconActionEnabled:(BOOL)iconActionEnabled
{
    [[self cell] setIconActionEnabled: iconActionEnabled];
}

@end

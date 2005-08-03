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
		currentTimer = nil;
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

- (void)dealloc{
	[currentTimer invalidate];
	[currentTimer release];
	[super dealloc];
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
	// first make sure we stop a previous timer
	if(currentTimer){
		[currentTimer invalidate];
		[currentTimer release];
		currentTimer = nil;
    }
	
    if(![self iconImage]){
        [self setIconImage:iconImage];
        return;
    }
	
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithFloat:0], @"time", iconImage, @"newImage", [self iconImage], @"oldImage", nil];
    currentTimer = [[NSTimer scheduledTimerWithTimeInterval:0.03  target:self selector:@selector(timerFired:)  userInfo:userInfo  repeats:YES] retain];
}

- (void)timerFired:(NSTimer *)timer;
{
    
    NSImage *newImage = [[timer userInfo] objectForKey:@"newImage"];
    float time = [[[timer userInfo] objectForKey:@"time"] floatValue];
	
    time += 0.1;
	
    if(time >= M_PI_2){
        [self setIconImage:newImage];
		if(![timer isEqual:currentTimer]){
			[timer invalidate]; // this should never happen
		}else if(currentTimer){
			[currentTimer invalidate];
			[currentTimer release];
			currentTimer = nil;
		}
        return;
    }
    
    NSNumber *timeNumber = [[NSNumber alloc] initWithFloat:time];
	[[timer userInfo] setObject:timeNumber forKey:@"time"];
    [timeNumber release];

    // original image we started with
    NSImage *oldImage = [[timer userInfo] objectForKey:@"oldImage"];
    
    // we need a clear image to draw into, or else the shadows get superimposed
    NSImage *image = [[NSImage alloc] initWithSize:[self iconSize]];
    
    [image lockFocus];
    [oldImage dissolveToPoint:NSZeroPoint fraction:cos(time)]; // decreasing amount of old image
    [newImage dissolveToPoint:NSZeroPoint fraction:sin(time)]; // increasing amount of new image
    [image unlockFocus];
    [self setIconImage:image];
    [image release];
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

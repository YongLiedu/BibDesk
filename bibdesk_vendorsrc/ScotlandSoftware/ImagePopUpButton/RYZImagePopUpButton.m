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
		highlight = NO;
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
		currentTimer = nil;
    }
	
    if(![self iconImage]){
        [self setIconImage:iconImage];
        return;
    }
	
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithFloat:0], @"time", iconImage, @"newImage", [self iconImage], @"oldImage", nil];
    currentTimer = [NSTimer scheduledTimerWithTimeInterval:0.03  target:self selector:@selector(timerFired:)  userInfo:userInfo  repeats:YES];
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

- (void)registerForDraggedTypes:(NSArray *)pboardTypes;
{
    [super registerForDraggedTypes:pboardTypes];
    if(pboardTypes != registeredDraggedTypes){
        [registeredDraggedTypes release];
        registeredDraggedTypes = [pboardTypes copy];
    }
}

- (NSArray *)registeredDraggedTypes;
{
    return ([super respondsToSelector:@selector(registeredDraggedTypes)] ? [super registeredDraggedTypes] : registeredDraggedTypes);
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard;
	NSString *pboardType;
    NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
	
	NSMutableSet *types = [NSMutableSet setWithArray:[[sender draggingPasteboard] types]];
	
	[types intersectSet:[NSSet setWithArray:[self registeredDraggedTypes]]];
    
    pboard = [sender draggingPasteboard];
    
    id delegate = [[self cell] delegate];
    if (delegate &&
	 	(sourceDragMask & NSDragOperationCopy) && 
        [delegate respondsToSelector:@selector(receiveDragFromPasteboard:forView:)] && 
        [delegate respondsToSelector:@selector(canReceiveDraggedTypes:forView:)] && 
        [delegate canReceiveDraggedTypes:types forView:self]) {
		
		highlight = YES;
		[self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
		return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
    highlight = NO;
	[self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
	highlight = NO;
	[self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
	return YES;
} 

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard;
    pboard = [sender draggingPasteboard];
	id delegate = [[self cell] delegate];
    
    if(delegate == nil) return NO;
    
    return [delegate receiveDragFromPasteboard:pboard forView:self];
}

-(void)drawRect:(NSRect)rect {
	[super drawRect:rect];
	if(!highlight)  
		return;
	
	[NSGraphicsContext saveGraphicsState];
	NSSetFocusRingStyle(NSFocusRingOnly);
	NSRectFill([self bounds]);
	[NSGraphicsContext restoreGraphicsState];
}

@end

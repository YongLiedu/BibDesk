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

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
    return NSDragOperationCopy;
}

- (BOOL)startDraggingWithEvent:(NSEvent *)theEvent {
	NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	
	if ([[[self cell] delegate] respondsToSelector:@selector(imagePopUpButton:writeDataToPasteboard:)] == NO ||
		[[[self cell] delegate] imagePopUpButton:self writeDataToPasteboard:pboard] == NO) 
		return NO;
		
	NSImage *iconImage;
	NSSize size = [[self cell] iconSize];
	NSImage *dragImage = [[[NSImage alloc] initWithSize:size] autorelease];
	NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	
	mouseLoc.x -= size.width / 2;
	mouseLoc.y += size.height / 2;
	
	if ([[self cell] usesItemFromMenu] == NO) {
		iconImage = [self iconImage];
	} else {
		iconImage = [[self selectedItem] image];
	}
	[dragImage lockFocus];
	[iconImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy fraction:0.6];
	[dragImage unlockFocus];

	[self dragImage:dragImage at:mouseLoc offset:NSZeroSize event:theEvent pasteboard:pboard source:self slideBack:YES];
	
	return YES;
}

- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination {
	if ([[[self cell] delegate] respondsToSelector:@selector(imagePopUpButton:namesOfPromisedFilesDroppedAtDestination:)])
		return [[[self cell] delegate] imagePopUpButton:self namesOfPromisedFilesDroppedAtDestination:dropDestination];
	return nil;
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation{
	if ([[[self cell] delegate] respondsToSelector:@selector(imagePopUpButton:concludeDragOperation:)])
		return [[[self cell] delegate] imagePopUpButton:self concludeDragOperation:operation];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
	
    id delegate = [[self cell] delegate];
    if (delegate &&
	 	(sourceDragMask & NSDragOperationCopy) && 
        [delegate respondsToSelector:@selector(receiveDrag:forView:)] && 
        [delegate respondsToSelector:@selector(canReceiveDrag:forView:)] && 
        [delegate canReceiveDrag:sender forView:self]) {
		
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
	id delegate = [[self cell] delegate];
    
    if(delegate == nil) return NO;
    
    return [delegate receiveDrag:sender forView:self];
}

-(void)drawRect:(NSRect)rect {
	[super drawRect:rect];
	
	if(highlight || 
	   ([[self window] firstResponder] == self &&
		[[self window] isKeyWindow] &&
		[[self cell] acceptsFirstResponder]))  {
	
		[NSGraphicsContext saveGraphicsState];
		NSSetFocusRingStyle(NSFocusRingOnly);
		NSRectFill([self bounds]);
		[NSGraphicsContext restoreGraphicsState];
	}
}

@end

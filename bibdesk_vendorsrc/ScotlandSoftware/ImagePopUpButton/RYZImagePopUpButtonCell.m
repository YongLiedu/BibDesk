#import "RYZImagePopUpButtonCell.h"
#import "BibEditor.h"

@implementation RYZImagePopUpButtonCell

// -----------------------------------------
//	Initialization and termination
// -----------------------------------------

- (id) init
{
    if (self = [super init])
    {
	RYZ_buttonCell = [[NSButtonCell alloc] initTextCell: @""];
	[RYZ_buttonCell setBordered: NO];
	[RYZ_buttonCell setHighlightsBy: NSContentsCellMask];
	[RYZ_buttonCell setImagePosition: NSImageLeft];
	
	RYZ_iconSize = NSMakeSize(32, 32);
	RYZ_showsMenuWhenIconClicked = NO;
	RYZ_iconActionEnabled = YES;
	RYZ_alwaysUsesFirstItemAsSelected = NO;

	[self setIconImage: [NSImage imageNamed: @"NSApplicationIcon"]];	
	[self setArrowImage: [NSImage imageNamed: @"ArrowPointingDown"]];
    }
    
    return self;
}


- (void) dealloc
{
    [RYZ_buttonCell release];
    [RYZ_iconImage release];
    [RYZ_arrowImage release];
    [super dealloc];
}

- (id)delegate {
    return RYZ_delegate;
}

- (void)setDelegate:(id)newDelegate {
	RYZ_delegate = newDelegate;
}



// --------------------------------------------
//	Getting and setting the icon size
// --------------------------------------------

- (NSSize) iconSize
{
    return RYZ_iconSize;
}


- (void) setIconSize: (NSSize) iconSize
{
    RYZ_iconSize = iconSize;
}

- (BOOL)iconActionEnabled {
    return RYZ_iconActionEnabled;
}

- (void)seticonActionEnabled:(BOOL)newiconActionEnabled {
	RYZ_iconActionEnabled = newiconActionEnabled;
}


// ---------------------------------------------------------------------------------
//	Getting and setting whether the menu is shown when the icon is clicked
// ---------------------------------------------------------------------------------

- (BOOL) showsMenuWhenIconClicked
{
    return RYZ_showsMenuWhenIconClicked;
}


- (void) setShowsMenuWhenIconClicked: (BOOL) showsMenuWhenIconClicked
{
    RYZ_showsMenuWhenIconClicked = showsMenuWhenIconClicked;
}


// ---------------------------------------------
//      Getting and setting the icon image
// ---------------------------------------------

- (NSImage *) iconImage
{
    return RYZ_iconImage;
}


- (void) setIconImage: (NSImage *) iconImage
{
    [iconImage retain];
    [RYZ_iconImage release];
    RYZ_iconImage = iconImage;
}


// ----------------------------------------------
//      Getting and setting the arrow image
// ----------------------------------------------

- (NSImage *) arrowImage
{
    return RYZ_arrowImage;
}


- (void) setArrowImage: (NSImage *) arrowImage
{
    [arrowImage retain];
    [RYZ_arrowImage release];
    RYZ_arrowImage = arrowImage;
}

- (BOOL)alwaysUsesFirstItemAsSelected {
    return RYZ_alwaysUsesFirstItemAsSelected;
}

- (void)setAlwaysUsesFirstItemAsSelected:(BOOL)newAlwaysUsesFirstItemAsSelected {
        RYZ_alwaysUsesFirstItemAsSelected = newAlwaysUsesFirstItemAsSelected;
}

- (NSMenuItem *)selectedItem{
	if(RYZ_alwaysUsesFirstItemAsSelected){
		return (NSMenuItem *)[self itemAtIndex:0];
	}else{
		return (NSMenuItem *)[super selectedItem];
	}
}

- (BOOL)refreshesMenu {
    return RYZ_refreshesMenu;
}

- (void)setRefreshesMenu:(BOOL)newRefreshesMenu {
    if (RYZ_refreshesMenu != newRefreshesMenu) {
        RYZ_refreshesMenu = newRefreshesMenu;
    }
}


// -----------------------------------------
//	Handling mouse/keyboard events
// -----------------------------------------

- (BOOL) trackMouse: (NSEvent *) event
	     inRect: (NSRect) cellFrame
	     ofView: (NSView *) controlView
       untilMouseUp: (BOOL) untilMouseUp{
    BOOL trackingResult = YES;
    if ([event type] == NSKeyDown){
		// Keyboard event
		unichar upAndDownArrowCharacters[2];
		upAndDownArrowCharacters[0] = NSUpArrowFunctionKey;
		upAndDownArrowCharacters[1] = NSDownArrowFunctionKey;
		NSString *upAndDownArrowString = [NSString stringWithCharacters: upAndDownArrowCharacters  length: 2];
		NSCharacterSet *upAndDownArrowCharacterSet = [NSCharacterSet characterSetWithCharactersInString: upAndDownArrowString];
		
		if ([self showsMenuWhenIconClicked] == YES ||
			[[event characters] rangeOfCharacterFromSet: upAndDownArrowCharacterSet].location != NSNotFound){
			NSEvent *newEvent = [NSEvent keyEventWithType: [event type]
												 location: NSMakePoint([controlView frame].origin.x, [controlView frame].origin.y - 4)
											modifierFlags: [event modifierFlags]
												timestamp: [event timestamp]
											 windowNumber: [event windowNumber]
												  context: [event context]
											   characters: [event characters]
							  charactersIgnoringModifiers: [event charactersIgnoringModifiers]
												isARepeat: [event isARepeat]
												  keyCode: [event keyCode]];
			
			[NSMenu popUpContextMenu: [self menu]  withEvent: newEvent  forView: controlView];
		}else if ([[event characters] rangeOfString: @" "].location != NSNotFound){
			[self performClick: controlView];
		}
    }else{
		// Mouse event
		NSPoint mouseLocation = [controlView convertPoint: [event locationInWindow]  fromView: nil];
		NSSize iconSize = [self iconSize];
		NSSize arrowSize = [[self arrowImage] size];
		NSRect arrowRect = NSMakeRect(cellFrame.origin.x + iconSize.width + 1,
									  cellFrame.origin.y,
									  arrowSize.width,
									  arrowSize.height);
		
		if ([controlView isFlipped]){
			arrowRect.origin.y += iconSize.height;
			arrowRect.origin.y -= arrowSize.height;
		}
		
/*		NSLog(@"mouseLocation: %@", NSStringFromPoint(mouseLocation));
		NSLog(@"isFlipped: %d", [controlView isFlipped]);
		NSLog(@"arrowRect: %@", NSStringFromRect(arrowRect));
*/		
		BOOL shouldSendAction = NO;

		
		if ([event type] == NSLeftMouseDown){
			if(([self showsMenuWhenIconClicked] == YES && [self iconActionEnabled])
			   || [controlView mouse: mouseLocation  inRect: arrowRect]){
				[self showMenuInView:controlView withEvent:event];
			}else{
				// Here we use periodic events to get 
				// the menu to show up after a delay, but 
				// only if we didn't mouse-up first.
				// Mouse-up causes the action to be sent
				// Drag or waiting for the delay causes the menu to show.
				// The period is meaningless because we 
				// cancel after the first event every time.
				[NSEvent startPeriodicEventsAfterDelay:0.7
											withPeriod:1];
				
				NSEvent *nextEvent = [NSApp nextEventMatchingMask:(NSLeftMouseUpMask | NSPeriodicMask | NSLeftMouseDraggedMask)
														untilDate:[NSDate distantFuture]
														   inMode:NSEventTrackingRunLoopMode
														  dequeue:YES];
				[NSEvent stopPeriodicEvents];
				if([nextEvent type] == NSLeftMouseUp){
					// if we mouse-up inside the button, send the action.
					// note that because we show the menu on drags,
					// we don't need to check that we're still inside 
					// before we send the action.
					
					if([self iconActionEnabled]){
						shouldSendAction = YES;
					}else{
						[self showMenuInView:controlView withEvent:nextEvent];
					}
					
				}else if([nextEvent type] == NSLeftMouseDraggedMask){
					// NSLog(@"drag event %@" , nextEvent);
					shouldSendAction = NO;
					[self showMenuInView:controlView withEvent:nextEvent];

				}else{
					// NSLog(@"periodicEvent %@", nextEvent);
					shouldSendAction = NO;
					
					// showMenu expects a mouseEvent, 
					// so we send it the original event:
					[self showMenuInView:controlView withEvent:event];
				}

			}
		}else{
			trackingResult = [RYZ_buttonCell trackMouse: event
											  inRect: cellFrame
											  ofView: controlView
										untilMouseUp: [[RYZ_buttonCell class] prefersTrackingUntilMouseUp]];  // NO for NSButton
			
			if (trackingResult == YES && [self iconActionEnabled]){
				shouldSendAction = YES;
			}
		}
		if(shouldSendAction){
			NSMenuItem *selectedItem = [self selectedItem];
			[NSEvent stopPeriodicEvents];
			[[NSApplication sharedApplication] sendAction: [selectedItem action]  
								   to: [selectedItem target]
								 from: selectedItem];
			
		}
    }
    
//    NSLog(@"trackingResult: %d", trackingResult);
    
    return trackingResult;
}

- (void)showMenuInView:(NSView *)controlView withEvent:(NSEvent *)event{
	NSEvent *newEvent = [NSEvent mouseEventWithType: [event type]
										   location: NSMakePoint([controlView frame].origin.x, [controlView frame].origin.y - 4)
									  modifierFlags: [event modifierFlags]
										  timestamp: [event timestamp]
									   windowNumber: [event windowNumber]
											context: [event context]
										eventNumber: [event eventNumber]
										 clickCount: [event clickCount]
										   pressure: [event pressure]];
	
	if([self refreshesMenu]){
		[self setMenu:[[self delegate] menuForImagePopUpButton]];
	}
	[NSMenu popUpContextMenu: [self menu]  withEvent: newEvent  forView: controlView];
}


- (void) performClick: (id) sender
{
    [RYZ_buttonCell performClick: sender];
    [super performClick: sender];
}


// -----------------------------------
//	Drawing and highlighting
// -----------------------------------

- (void) drawWithFrame: (NSRect) cellFrame  inView: (NSView *) controlView
{
    NSImage *iconImage;
    
    if ([self usesItemFromMenu] == NO)
    {
	iconImage = [self iconImage];
    }
    else
    {
	iconImage = [[[[self selectedItem] image] copy] autorelease];
    }
    
    [iconImage setSize: [self iconSize]];    
    NSImage *arrowImage = [self arrowImage];
    NSSize iconSize = [iconImage size];
    NSSize arrowSize = [arrowImage size];
    NSImage *popUpImage = [[NSImage alloc] initWithSize: NSMakeSize(iconSize.width + arrowSize.width, iconSize.height)];
    
    NSRect iconRect = NSMakeRect(0, 0, iconSize.width, iconSize.height);
    NSRect arrowRect = NSMakeRect(0, 0, arrowSize.width, arrowSize.height);
    NSRect iconDrawRect = NSMakeRect(0, 0, iconSize.width, iconSize.height);
    NSRect arrowDrawRect = NSMakeRect(iconSize.width, 1, arrowSize.width, arrowSize.height);
    
    [popUpImage lockFocus];
    [iconImage drawInRect: iconDrawRect  fromRect: iconRect  operation: NSCompositeSourceOver  fraction: 1.0];
    [arrowImage drawInRect: arrowDrawRect  fromRect: arrowRect  operation: NSCompositeSourceOver  fraction: 1.0];
    [popUpImage unlockFocus];
    
    [RYZ_buttonCell setImage: popUpImage];
    [popUpImage release];
    
    if ([[controlView window] firstResponder] == controlView &&
	[controlView respondsToSelector: @selector(selectedCell)] &&
	[controlView performSelector: @selector(selectedCell)] == self)
    {
	[RYZ_buttonCell setShowsFirstResponder: YES];
    }
    else
    {
	[RYZ_buttonCell setShowsFirstResponder: NO];
    }
    
	 //   NSLog(@"cellFrame: %@  selectedItem: %@", NSStringFromRect(cellFrame), [[self selectedItem] title]);
    
    [RYZ_buttonCell drawWithFrame: cellFrame  inView: controlView];
}


- (void) highlight: (BOOL) flag  withFrame: (NSRect) cellFrame  inView: (NSView *) controlView
{
	[RYZ_buttonCell highlight: flag  withFrame: cellFrame  inView: controlView];
	[super highlight: flag  withFrame: cellFrame  inView: controlView];
}

@end
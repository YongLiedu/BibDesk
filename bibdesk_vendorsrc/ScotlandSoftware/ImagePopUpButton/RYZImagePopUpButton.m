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


- (void)setIconImage:(NSImage *)iconImage
{
    [[self cell] setIconImage: iconImage];
}


// ----------------------------------------------
//      Getting and setting the arrow image
// ----------------------------------------------

- (NSImage *)arrowImage
{
    return [[self cell] arrowImage];
}


- (void)setArrowImage:(NSImage *)arrowImage
{
    [[self cell] setArrowImage: arrowImage];
}

@end

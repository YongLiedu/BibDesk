@interface RYZImagePopUpButton : NSPopUpButton
{
}

// --- Getting and setting the icon size ---
- (NSSize) iconSize;
- (void) setIconSize: (NSSize) iconSize;


// --- Getting and setting whether the menu is shown when the icon is clicked ---
- (BOOL) showsMenuWhenIconClicked;
- (void) setShowsMenuWhenIconClicked: (BOOL) showsMenuWhenIconClicked;


// --- Getting and setting the icon image ---
- (NSImage *) iconImage;
- (void) setIconImage: (NSImage *) iconImage;


// --- Getting and setting the arrow image ---
- (NSImage *) arrowImage;
- (void) setArrowImage: (NSImage *) arrowImage;

@end
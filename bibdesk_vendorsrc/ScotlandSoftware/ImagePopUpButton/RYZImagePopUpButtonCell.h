@interface RYZImagePopUpButtonCell : NSPopUpButtonCell
{
    NSButtonCell *_buttonCell;
    NSSize _iconSize;
    BOOL _showsMenuWhenIconClicked;
    NSImage *_iconImage;
    NSImage *_arrowImage;
	BOOL _iconEnabled;
}

// -- Setting if the icon is enabled, leaves the menu enabled --
// -- meaningless if showsmenuwheniconclicked is true.
- (BOOL)iconEnabled;
- (void)setIconEnabled:(BOOL)iconEnabled;


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
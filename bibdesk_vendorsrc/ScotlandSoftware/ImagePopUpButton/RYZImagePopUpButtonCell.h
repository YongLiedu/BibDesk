@interface RYZImagePopUpButtonCell : NSPopUpButtonCell
{
    NSButtonCell *_buttonCell;
    NSSize _iconSize;
    BOOL _showsMenuWhenIconClicked;
    NSImage *_iconImage;
    NSImage *_arrowImage;
	BOOL _iconActionEnabled;
	BOOL _alwaysUsesFirstItemAsSelected;
	BOOL _refreshesMenu;
	id _delegate;
}

- (id)delegate;
- (void)setDelegate:(id)newDelegate;

// -- Setting if the icon is enabled, leaves the menu enabled --
// -- meaningless if showsmenuwheniconclicked is true.
- (BOOL)iconActionEnabled;
- (void)seticonActionEnabled:(BOOL)iconActionEnabled;


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

// --- changing whether or not the selected item changes.
- (BOOL)alwaysUsesFirstItemAsSelected;
- (void)setAlwaysUsesFirstItemAsSelected:(BOOL)newAlwaysUsesFirstItemAsSelected;

- (BOOL)refreshesMenu;
- (void)setRefreshesMenu:(BOOL)newRefreshesMenu;


// Private methods

- (void)showMenuInView:(NSView *)controlView withEvent:(NSEvent *)event;

@end
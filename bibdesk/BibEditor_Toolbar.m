//
//  BibEditor_Toolbar.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/4/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BibEditor_Toolbar.h"


NSString* 	BibEditorToolbarIdentifier 		= @"BibDesk Editor Toolbar Identifier";
NSString*	ViewLocalEditorToolbarItemIdentifier 	= @"View Local Editor Item Identifier";
NSString*	ViewRemoteEditorToolbarItemIdentifier 	= @"View Remote Editor Item Identifier";
NSString*	ToggleSnoopDrawerToolbarItemIdentifier 	= @"Toggle Snoop Drawer Identifier";
NSString*	AuthorTableToolbarItemIdentifier 	= @"Author Table Item Identifier";

@implementation BibEditor (Toolbar)

// ----------------------------------------------------------------------------------------
// toolbar stuff
// ----------------------------------------------------------------------------------------

// label, palettelabel, toolTip, action, and menu can all be NULL, depending upon what you want the item to do
static void addToolbarItem(NSMutableDictionary *theDict,NSString *identifier,NSString *label,NSString *paletteLabel,NSString *toolTip,id target,SEL settingSelector, id itemContent,SEL action, NSMenuItem *menuItem)
{
    NSMenuItem *mItem;
    // here we create the NSToolbarItem and setup its attributes in line with the parameters
    NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];
    [item setLabel:label];
    [item setPaletteLabel:paletteLabel];
    [item setToolTip:toolTip];
    [item setTarget:target];
    // the settingSelector parameter can either be @selector(setView:) or @selector(setImage:).  Pass in the right
    // one depending upon whether your NSToolbarItem will have a custom view or an image, respectively
    // (in the itemContent parameter).  Then this next line will do the right thing automatically.
    [item performSelector:settingSelector withObject:itemContent];
    [item setAction:action];
    // The menuItem to be shown in text only mode. Don't reset this when we use the default behavior. 
	if (menuItem)
		[item setMenuFormRepresentation:menuItem];
    // Now that we've setup all the settings for this new toolbar item, we add it to the dictionary.
    // The dictionary retains the toolbar item for us, which is why we could autorelease it when we created
    // it (above).
    [theDict setObject:item forKey:identifier];
}

// called from WindowControllerDidLoadNib.
- (void) setupToolbar {
    // Create a new toolbar instance, and attach it to our document window
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:BibEditorToolbarIdentifier] autorelease];
    NSMenuItem *menuItem;

    toolbarItems=[[NSMutableDictionary dictionary] retain];
    
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeDefault];

    // We are the delegate
    [toolbar setDelegate: self];

    // add toolbaritems:

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"View File",@"") 
										   action:@selector(viewLocal:)
									keyEquivalent:@""] autorelease];
    [menuItem setTarget:self];
	addToolbarItem(toolbarItems, ViewLocalEditorToolbarItemIdentifier,
                   NSLocalizedString(@"View File",@""), 
				   NSLocalizedString(@"View File",@""),
                   NSLocalizedString(@"View File",@""),
                   nil, @selector(setView:),
				   viewLocalButton, 
				   NULL,
                   menuItem);

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"View Remote",@"") 
										   action:@selector(viewRemote:)
									keyEquivalent:@""] autorelease];
    [menuItem setTarget:self];
    addToolbarItem(toolbarItems, ViewRemoteEditorToolbarItemIdentifier,
                   NSLocalizedString(@"View Remote",@""), 
				   NSLocalizedString(@"View Remote URL",@""),
                   NSLocalizedString(@"View in Web Browser",@""),
                   nil, @selector(setView:),
				   viewRemoteButton, 
				   NULL,
                   menuItem);

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"View in Drawer",@"") 
										   action:@selector(toggleSnoopDrawer:)
									keyEquivalent:@""] autorelease];
    [menuItem setTarget:self];
    addToolbarItem(toolbarItems, ToggleSnoopDrawerToolbarItemIdentifier,
                   NSLocalizedString(@"View in Drawer",@""), 
				   NSLocalizedString(@"View in Drawer",@""),
                   NSLocalizedString(@"View File in Drawer",@""),
                   nil, @selector(setView:),
				   documentSnoopButton, 
				   NULL,
                   menuItem);

    addToolbarItem(toolbarItems, AuthorTableToolbarItemIdentifier,
                   NSLocalizedString(@"Authors",@""), 
				   NSLocalizedString(@"Authors Table",@""),
                   NSLocalizedString(@"Authors Table",@""),
                   nil, @selector(setView:),  
				   authorScrollView,
				   NULL,
                   nil);
    
    // Attach the toolbar to the document window
    [[self window] setToolbar: toolbar];
}



- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar
      itemForItemIdentifier: (NSString *)itemIdent
  willBeInsertedIntoToolbar:(BOOL) willBeInserted {

    OAToolbarItem *newItem = [[[OAToolbarItem alloc] initWithItemIdentifier:itemIdent] autorelease];
    NSToolbarItem *item=[toolbarItems objectForKey:itemIdent];

    [newItem setLabel:[item label]];
    [newItem setPaletteLabel:[item paletteLabel]];
    if ([item view]!=nil)
    {
        [newItem setView:[item view]];
		[newItem setDelegate:self];
    }
    else
    {
        [newItem setImage:[item image]];
    }
    [newItem setToolTip:[item toolTip]];
    [newItem setTarget:[item target]];
    [newItem setAction:[item action]];
    [newItem setMenuFormRepresentation:[item menuFormRepresentation]];
    // If we have a custom view, we *have* to set the min/max size - otherwise, it'll default to 0,0 and the custom
    // view won't show up at all!  This doesn't affect toolbar items with images, however.
    if ([newItem view]!=nil)
    {
        [newItem setMinSize:[[item view] bounds].size];
        [newItem setMaxSize:[[item view] bounds].size];
    }

    return newItem;
}



- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar {
    return [NSArray arrayWithObjects:
		ViewLocalEditorToolbarItemIdentifier,
		ViewRemoteEditorToolbarItemIdentifier,
		ToggleSnoopDrawerToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier, 
		AuthorTableToolbarItemIdentifier, nil];
}


- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar {
    return [NSArray arrayWithObjects: 
		ViewLocalEditorToolbarItemIdentifier,
		ViewRemoteEditorToolbarItemIdentifier,
		ToggleSnoopDrawerToolbarItemIdentifier,
		AuthorTableToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier, 
		NSToolbarSpaceItemIdentifier, 
		NSToolbarSeparatorItemIdentifier, 
		NSToolbarCustomizeToolbarItemIdentifier, nil];
}

- (void) toolbarWillAddItem: (NSNotification *) notif {
    NSToolbarItem *addedItem = [[notif userInfo] objectForKey: @"item"];

}

/*
- (void) toolbarDidRemoveItem: (NSNotification *) notif {
    // Optional delegate method   After an item is removed from a toolbar the notification is sent   self allows
    // the chance to tear down information related to the item that may have been cached   The notification object
    // is the toolbar to which the item is being added   The item being added is found by referencing the @"item"
    // key in the userInfo
    NSToolbarItem *removedItem = [[notif userInfo] objectForKey: @"item"];


}*/

- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem {
    // Optional method   self message is sent to us since we are the target of some toolbar item actions
    // (for example:  of the save items action)
    BOOL enable = YES;

    return enable;
}


@end

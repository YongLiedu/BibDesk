//
//  BibPref_InputManager.m
//  Bibdesk
//
//  Created by Adam Maxwell on Fri Aug 27 2004.
//  Copyright (c) 2004 Adam R. Maxwell. All rights reserved.
//


#import "BibPref_InputManager.h"

NSString *BDSKInputManagerID = @"net.sourceforge.bibdesk.inputmanager";

@implementation BibPref_InputManager

- (void)awakeFromNib{
    [super awakeFromNib];
    applicationSupportPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Application Support/BibDeskInputManager"] retain];
    inputManagerPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"/Library/InputManagers/BibDeskInputManager"] retain];
    if(![[NSFileManager defaultManager] fileExistsAtPath:applicationSupportPath]){
	appListArray = [[NSMutableArray arrayWithObjects:[NSMutableDictionary dictionaryWithObject:[@"/Applications/TextEdit.app" stringByStandardizingPath] forKey:@"Path"], 
							 [NSMutableDictionary dictionaryWithObject:[@"/Developer/Applications/Xcode.app" stringByStandardizingPath] forKey:@"Path"], nil] retain];
	[[NSFileManager defaultManager] createDirectoryAtPath:applicationSupportPath attributes:nil];
    } else {
	appListArray = [[NSArray arrayWithContentsOfFile:[applicationSupportPath stringByAppendingPathComponent:@"EnabledApplications.plist"]] mutableCopy];
    }
    [[appList tableColumnWithIdentifier:@"AppList"] setDataCell:[[[NSBrowserCell alloc] init] autorelease]];
}

- (void)dealloc{
    [applicationSupportPath release];
    [inputManagerPath release];
    [appListArray release];
    [super dealloc];
}

- (void)updateUI{
    if([[NSFileManager defaultManager] fileExistsAtPath:inputManagerPath]){
	[enableButton setTitle:NSLocalizedString(@"Reinstall",@"Reinstall input manager")];
	[enableButton sizeToFit];
    }    
    [self getIconAndBundleID];
    [appList reloadData];
}

- (void)getIconAndBundleID{
    NSEnumerator *e = [appListArray objectEnumerator];
    NSBundle *bundle;
    NSDictionary *plist;
    NSMutableDictionary *dict;
    
    while(dict = [e nextObject]){
	bundle = [NSBundle bundleWithPath:[dict objectForKey:@"Path"]];
	plist = [bundle infoDictionary];
	NSString *iconName = [plist objectForKey:@"CFBundleIconFile"];
	[dict setObject:[bundle pathForImageResource:iconName] forKey:@"IconPath"];
	[dict setObject:[plist objectForKey:@"CFBundleIdentifier"] forKey:@"BundleID"];
    }
    [self cacheAppList];

}

- (int)numberOfRowsInTableView:(NSTableView *)tableView{
    return [appListArray count];
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex{
    [aCell setStringValue:[[[[appListArray objectAtIndex:rowIndex] objectForKey:@"Path"] lastPathComponent] stringByDeletingPathExtension]];
    NSImage *image = [[[NSImage alloc] initWithContentsOfFile:[[appListArray objectAtIndex:rowIndex] objectForKey:@"IconPath"]] autorelease];
    [image setSize:NSMakeSize(16, 16)];
    [aCell setImage:image];
    [aCell setLeaf:YES];
}

- (IBAction)enableAutocompletion:(id)sender{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL err = NO;
    
    if([fm fileExistsAtPath:inputManagerPath]){
	if([fm isDeletableFileAtPath:inputManagerPath]){
	    if(![fm removeFileAtPath:inputManagerPath handler:nil]){
		NSLog(@"error occurred while removing file");
		err = YES;
	    }
	} else {
	    err = YES;
	    NSLog(@"unable to remove file, check permissions");
	}
    }
    if(!err){
	[fm copyPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"BibDeskInputManager"]
	      toPath:inputManagerPath
	     handler:nil];
    } else {
	NSAlert *anAlert = [NSAlert alertWithMessageText:@"Error!"
					   defaultButton:nil
					 alternateButton:nil
					     otherButton:nil
			       informativeTextWithFormat:@"Unable to remove file at %@, please check file or directory permissions.", inputManagerPath];
	[anAlert beginSheetModalForWindow:[sender window]
			    modalDelegate:nil
			   didEndSelector:nil
			      contextInfo:nil];    
    }
    [self updateUI]; // change button to "Reinstall"
    
}

- (IBAction)addApplication:(id)sender{
    NSOpenPanel *op = [NSOpenPanel openPanel];
    [op setCanChooseDirectories:NO];
    [op setAllowsMultipleSelection:NO];
    [op beginSheetForDirectory:@"/Applications"
			  file:nil
			 types:[NSArray arrayWithObject:@"app"]
		modalForWindow:[controlBox window]
		 modalDelegate:self
		didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
		   contextInfo:nil];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    if(returnCode == NSOKButton){
	[appListArray addObject:[NSMutableDictionary dictionaryWithObject:[[sheet filenames] objectAtIndex:0] forKey:@"Path"]];
	[self updateUI];
    } else {
	if(returnCode == NSCancelButton){
	    // do nothing
	}
    }
}

- (void)cacheAppList{
    if(![[[appListArray copy] autorelease] writeToFile:[applicationSupportPath stringByAppendingPathComponent:@"EnabledApplications.plist"] atomically:YES]){
	NSLog(@"unable to write autocompletion cache");
    }
}

- (IBAction)removeApplication:(id)sender{
    [appListArray removeObjectAtIndex:[appList selectedRow]];
    [self updateUI];
}

@end

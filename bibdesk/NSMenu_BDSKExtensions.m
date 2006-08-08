//
//  NSMenu_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/09/06.
/*
 This software is Copyright (c) 2006
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
 contributors may be used to endorse or promote products derived
 from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSMenu_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import "NSArray_BDSKExtensions.h"

static NSString *BDSKMenuTargetURL = @"BDSKMenuTargetURL";
static NSString *BDSKMenuApplicationURL = @"BDSKMenuApplicationURL";

@interface BDSKOpenWithMenuController : NSObject 
+ (id)sharedInstance;
- (void)openURLWithApplication:(id)sender;
@end

@interface NSMenu (BDSKPrivate)
- (void)replaceAllItemsWithApplicationsForURL:(NSURL *)aURL;
@end

@implementation NSMenu (BDSKExtensions)

- (void)addItemsFromMenu:(NSMenu *)other;
{
    unsigned i, count = [other numberOfItems];
    NSMenuItem *anItem;
    NSZone *zone = [self zone];
    for(i = 0; i < count; i++){
        anItem = [[other itemAtIndex:i] copyWithZone:zone];
        [self addItem:anItem];
        [anItem release];
    }
}

- (id <NSMenuItem>)insertItemWithTitle:(NSString *)itemTitle submenu:(NSMenu *)submenu atIndex:(unsigned int)index;
{
    NSMenuItem *item = [[NSMenuItem allocWithZone:[self zone]] initWithTitle:itemTitle action:NULL keyEquivalent:@""];
    [item setSubmenu:submenu];
    [self insertItem:item atIndex:index];
    [item release];
    return item;
}

- (id <NSMenuItem>)addItemWithTitle:(NSString *)itemTitle submenu:(NSMenu *)submenu;
{
    return [self insertItemWithTitle:itemTitle submenu:submenu atIndex:[self numberOfItems]];
}

- (id <NSMenuItem>)insertItemWithTitle:(NSString *)itemTitle submenuTitle:(NSString *)submenuTitle submenuDelegate:(id)delegate atIndex:(unsigned int)index;
{
    NSMenuItem *item = [[NSMenuItem allocWithZone:[self zone]] initWithTitle:itemTitle action:NULL keyEquivalent:@""];
    NSMenu *submenu = [[NSMenu allocWithZone:[self zone]] initWithTitle:submenuTitle];
    [submenu setDelegate:delegate];
    [item setSubmenu:submenu];
    [self insertItem:item atIndex:index];
    [submenu release];
    [item release];
    return item;
}

- (id <NSMenuItem>)addItemWithTitle:(NSString *)itemTitle submenuTitle:(NSString *)submenuTitle submenuDelegate:(id)delegate;
{
    return [self insertItemWithTitle:itemTitle submenuTitle:submenuTitle submenuDelegate:delegate atIndex:[self numberOfItems]];
}

- (id <NSMenuItem>)insertItemWithTitle:(NSString *)itemTitle andSubmenuOfApplicationsForURL:(NSURL *)theURL atIndex:(unsigned int)index;
{
    NSMenuItem *item = [[NSMenuItem allocWithZone:[self zone]] initWithTitle:itemTitle action:NULL keyEquivalent:@""];
    NSMenu *submenu = [[NSMenu allocWithZone:[self zone]] initWithTitle:@""];
    NSMenuItem *placeholderItem = [submenu addItemWithTitle:@"" action:NULL keyEquivalent:@""];
    [placeholderItem setRepresentedObject:[NSDictionary dictionaryWithObjectsAndKeys:theURL, BDSKMenuTargetURL, nil]];
    [submenu setDelegate:[BDSKOpenWithMenuController sharedInstance]];
    [item setSubmenu:submenu];
    [self insertItem:item atIndex:index];
    [submenu release];
    [item release];
    return item;
}

- (id <NSMenuItem>)addItemWithTitle:(NSString *)itemTitle andSubmenuOfApplicationsForURL:(NSURL *)theURL;
{
    return [self insertItemWithTitle:itemTitle andSubmenuOfApplicationsForURL:theURL atIndex:[self numberOfItems]];
}

@end


@implementation NSMenu (BDSKPrivate)

- (void)replaceAllItemsWithApplicationsForURL:(NSURL *)aURL;
{    
    // if a menu item is the only thing retaining this URL, removing all items will cause it to become invalid
    [[aURL retain] autorelease];
    [self removeAllItems];
    
    // if there's no url, just return an empty submenu, since we can't find applications
    if(nil == aURL)
        return;
    
    NSZone *menuZone = [NSMenu menuZone];
    NSMenuItem *item;
    
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSEnumerator *appEnum = [[workspace editorAndViewerURLsForURL:aURL] objectEnumerator];
    NSURL *defaultEditorURL = [workspace defaultEditorOrViewerURLForURL:aURL];
    
    NSString *menuTitle;
    NSDictionary *representedObject;
    NSURL *applicationURL;
    
    while(applicationURL = [appEnum nextObject]){
        menuTitle = [applicationURL lastPathComponent];
        
        // mark the default app, if we have one
        if([defaultEditorURL isEqual:applicationURL])
            menuTitle = [menuTitle stringByAppendingString:NSLocalizedString(@" (Default)", @"Need a single leading space")];
        
        item = [[NSMenuItem allocWithZone:menuZone] initWithTitle:menuTitle action:@selector(openURLWithApplication:) keyEquivalent:@""];
        
        // BDSKOpenWithMenuController singleton implements this
        [item setTarget:[BDSKOpenWithMenuController sharedInstance]];
        representedObject = [[NSDictionary alloc] initWithObjectsAndKeys:aURL, BDSKMenuTargetURL, applicationURL, BDSKMenuApplicationURL, nil];
        [item setRepresentedObject:representedObject];
        
        // use NSWorkspace to get an image; using [NSImage imageForURL:] doesn't work for some reason
        NSImage *image = [workspace iconForFileURL:applicationURL];
        [image setSize:NSMakeSize(16,16)];
        [item setImage:image];
        [representedObject release];
        if([defaultEditorURL isEqual:applicationURL])
            [self insertItem:item atIndex:0];
        else
            [self addItem:item];
        [item release];
    }
    
    // add the choose... item
    item = [[NSMenuItem allocWithZone:menuZone] initWithTitle:[NSLocalizedString(@"Choose",@"Choose") stringByAppendingEllipsis] action:@selector(openURLWithApplication:) keyEquivalent:@""];
    [item setTarget:[BDSKOpenWithMenuController sharedInstance]];
    representedObject = [[NSDictionary alloc] initWithObjectsAndKeys:aURL, BDSKMenuTargetURL, nil];
    [item setRepresentedObject:representedObject];
    [representedObject release];
    [self addItem:item];
    [item release];
}

@end

#pragma mark -

/* Private singleton to act as target for the "Open With..." menu item, or run a modal panel to choose a different application.
*/

@implementation BDSKOpenWithMenuController

static id sharedOpenWithController = nil;

+ (id)sharedInstance
{
    if(nil == sharedOpenWithController)
        sharedOpenWithController = [[self alloc] init];
    return sharedOpenWithController;
}

- (oneway void)release
{
    [self doesNotRecognizeSelector:_cmd];
}

- (void)chooseApplicationToOpenURL:(NSURL *)aURL;
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setPrompt:NSLocalizedString(@"Choose Viewer", @"")];
    
    int rv = [openPanel runModalForDirectory:[[NSFileManager defaultManager] applicationsDirectory] 
                                        file:nil 
                                       types:[NSArray arrayWithObjects:@"app", nil]];
    if(NSFileHandlingPanelOKButton == rv)
        [[NSWorkspace sharedWorkspace] openURL:aURL withApplicationURL:[[openPanel URLs] firstObject]];
}

// action for opening a file with a specific application
- (void)openURLWithApplication:(id)sender;
{
    NSURL *applicationURL = [[sender representedObject] valueForKey:BDSKMenuApplicationURL];
    NSURL *targetURL = [[sender representedObject] valueForKey:BDSKMenuTargetURL];
    
    if(nil == applicationURL)
        [self chooseApplicationToOpenURL:targetURL];
    else if([[NSWorkspace sharedWorkspace] openURL:targetURL withApplicationURL:applicationURL] == NO)
        NSBeep();
}

- (void)menuNeedsUpdate:(NSMenu *)menu{
    NSURL *theURL = [[[[menu itemArray] lastObject] representedObject] valueForKey:BDSKMenuTargetURL];
    if(theURL != nil)
        [menu replaceAllItemsWithApplicationsForURL:theURL];
}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem{
    if ([menuItem action] == @selector(openURLWithApplication:)) {
        NSURL *theURL = [[menuItem representedObject] valueForKey:BDSKMenuTargetURL];
        if([theURL isFileURL])
            theURL = [theURL fileURLByResolvingAliases];
        return (theURL == nil ? NO : YES);
    }
    return YES;
}

@end


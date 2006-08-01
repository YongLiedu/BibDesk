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

NSString *BDSKMenuTargetURL = @"BDSKMenuTargetURL";
NSString *BDSKMenuApplicationURL = @"BDSKMenuApplicationURL";

@implementation NSMenu (BDSKExtensions)

+ (NSMenu *)submenuOfApplicationsForURL:(NSURL *)aURL;
{
    NSMenu *submenu = [[[self allocWithZone:[self menuZone]] initWithTitle:@""] autorelease];
    [submenu fillWithApplicationsForURL:aURL];
    return submenu;
}

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

- (void)fillWithApplicationsForURL:(NSURL *)aURL;
{    
    int i = [self numberOfItems];
    while(i--)
        [self removeItemAtIndex:i];
    
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
        
        // -[NSApp delegate] implements this
        [item setTarget:nil];
        representedObject = [[NSDictionary alloc] initWithObjectsAndKeys:aURL, BDSKMenuTargetURL, applicationURL, BDSKMenuApplicationURL, nil];
        [item setRepresentedObject:representedObject];
        
        // use the application's icon as an image; using [NSImage imageForURL:] doesn't work for some reason
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
    item = [[NSMenuItem allocWithZone:menuZone] initWithTitle:[NSLocalizedString(@"Choose",@"") stringByAppendingEllipsis] action:@selector(openURLWithApplication:) keyEquivalent:@""];
    [item setTarget:nil];
    representedObject = [[NSDictionary alloc] initWithObjectsAndKeys:aURL, BDSKMenuTargetURL, nil];
    [item setRepresentedObject:representedObject];
    [representedObject release];
    [self addItem:item];
    [item release];
}

- (id <NSMenuItem>)insertItemWithTitle:(NSString *)itemTitle submenu:(NSMenu *)submenu atIndex:(unsigned int)index;
{
    NSMenuItem *item = [[NSMenuItem allocWithZone:[self zone]] initWithTitle:itemTitle action:NULL keyEquivalent:@""];
    [item setSubmenu:submenu];
    [self insertItem:item atIndex:index];
    [submenu release];
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

@end

//
//  NSMenu_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 07/09/06.
/*
 This software is Copyright (c) 2006-2009
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
#import "BDSKVersionNumber.h"

#define BDSKMenuTargetURL @"BDSKMenuTargetURL"
#define BDSKMenuApplicationURL @"BDSKMenuApplicationURL"

@interface BDSKOpenWithMenuController : NSObject <NSMenuDelegate>
+ (id)sharedInstance;
- (void)openURLWithApplication:(id)sender;
@end

@interface NSMenu (BDSKPrivate)
- (void)replaceAllItemsWithApplicationsForURL:(NSURL *)aURL;
@end

@implementation NSMenu (BDSKExtensions)

- (void)removeAllItems {
    NSUInteger numItems = 0;
    while (numItems = [self numberOfItems])
        [self removeItemAtIndex:numItems - 1];
}

- (NSMenuItem *)itemWithAction:(SEL)action {
    NSUInteger i = [self numberOfItems];
    while (i--) {
        NSMenuItem *item = [self itemAtIndex:i];
        if ([item action] == action)
            return item;
    }
    return nil;
}

- (void)addItemsFromMenu:(NSMenu *)other;
{
    NSUInteger i, count = [other numberOfItems];
    NSMenuItem *anItem;
    NSZone *zone = [self zone];
    for(i = 0; i < count; i++){
        anItem = [[other itemAtIndex:i] copyWithZone:zone];
        [self addItem:anItem];
        [anItem release];
    }
}

- (NSMenuItem *)insertItemWithTitle:(NSString *)itemTitle submenu:(NSMenu *)submenu atIndex:(NSUInteger)idx;
{
    NSMenuItem *item = [[NSMenuItem allocWithZone:[self zone]] initWithTitle:itemTitle action:NULL keyEquivalent:@""];
    [item setSubmenu:submenu];
    [self insertItem:item atIndex:idx];
    [item release];
    return item;
}

- (NSMenuItem *)addItemWithTitle:(NSString *)itemTitle submenu:(NSMenu *)submenu;
{
    return [self insertItemWithTitle:itemTitle submenu:submenu atIndex:[self numberOfItems]];
}

- (NSMenuItem *)insertItemWithTitle:(NSString *)itemTitle submenuTitle:(NSString *)submenuTitle submenuDelegate:(id)delegate atIndex:(NSUInteger)idx;
{
    NSMenuItem *item = [[NSMenuItem allocWithZone:[self zone]] initWithTitle:itemTitle action:NULL keyEquivalent:@""];
    NSMenu *submenu = [[NSMenu allocWithZone:[self zone]] initWithTitle:submenuTitle];
    [submenu setDelegate:delegate];
    [item setSubmenu:submenu];
    [self insertItem:item atIndex:idx];
    [submenu release];
    [item release];
    return item;
}

- (NSMenuItem *)addItemWithTitle:(NSString *)itemTitle submenuTitle:(NSString *)submenuTitle submenuDelegate:(id)delegate;
{
    return [self insertItemWithTitle:itemTitle submenuTitle:submenuTitle submenuDelegate:delegate atIndex:[self numberOfItems]];
}

- (NSMenuItem *)insertItemWithTitle:(NSString *)itemTitle andSubmenuOfApplicationsForURL:(NSURL *)theURL atIndex:(NSUInteger)idx;
{
    if (theURL == nil) {
        // just return an empty item
        return [self insertItemWithTitle:itemTitle action:NULL keyEquivalent:@"" atIndex:idx];
    }
    
    NSMenu *submenu;
    NSMenuItem *item;
    NSDictionary *representedObject;
    BDSKOpenWithMenuController *controller = [BDSKOpenWithMenuController sharedInstance];
    
    submenu = [[[NSMenu allocWithZone:[self zone]] initWithTitle:@""] autorelease];
    [submenu setDelegate:controller];
    
    // add the choose... item, the other items are inserted lazily by BDSKOpenWithMenuController
    item = [submenu addItemWithTitle:[NSLocalizedString(@"Choose", @"Menu item title") stringByAppendingEllipsis] action:@selector(openURLWithApplication:) keyEquivalent:@""];
    [item setTarget:controller];
    representedObject = [[NSDictionary alloc] initWithObjectsAndKeys:theURL, BDSKMenuTargetURL, nil];
    [item setRepresentedObject:representedObject];
    [representedObject release];
    
    return [self insertItemWithTitle:itemTitle submenu:submenu atIndex:idx];
}

- (NSMenuItem *)addItemWithTitle:(NSString *)itemTitle andSubmenuOfApplicationsForURL:(NSURL *)theURL;
{
    return [self insertItemWithTitle:itemTitle andSubmenuOfApplicationsForURL:theURL atIndex:[self numberOfItems]];
}

@end


@implementation NSMenu (BDSKPrivate)

static BOOL fileIsInApplicationsOrSystem(NSURL *fileURL)
{
    NSCParameterAssert([fileURL isFileURL]);    
    FSRef fileRef;
    Boolean result = false;
    if (CFURLGetFSRef((CFURLRef)fileURL, &fileRef)) {
        FSDetermineIfRefIsEnclosedByFolder(0, kApplicationsFolderType, &fileRef, &result);
        if (result == false)
            FSDetermineIfRefIsEnclosedByFolder(0, kSystemFolderType, &fileRef, &result);
    }
    return result;
}

static inline NSString *displayNameForURL(NSURL *appURL) {
    return [[[NSFileManager defaultManager] displayNameAtPath:[appURL path]] stringByDeletingPathExtension];
}

static inline NSArray *copyUniqueVersionedNamesAndURLsForURLs(NSArray *appURLs, NSURL *defaultAppURL) {
    NSMutableArray *uniqueNamesAndURLs = [[NSMutableArray alloc] init];
    NSInteger i, count = [appURLs count];
    
    if (count > 1) {
        NSMutableSet *versionStrings = [[NSMutableSet alloc] init];
        
        for (i = 0; i < count; i++) {
            NSURL *appURL = [appURLs objectAtIndex:i];
            NSDictionary *appInfo = [[NSBundle bundleWithPath:[appURL path]] infoDictionary];
            NSString *versionString = [appInfo objectForKey:@"CFBundleVersion"];
            NSString *shortVersionString = [appInfo objectForKey:@"CFBundleShortVersionString"];
            if (versionString == nil)
                versionString = shortVersionString;
            if (shortVersionString == nil)
                shortVersionString = versionString;
            // we always include the default app and any version in Applications or System
            BOOL isDefault = [defaultAppURL isEqual:appURL];
            BOOL isInApplications = fileIsInApplicationsOrSystem(appURL);
            BOOL isPreferred = isDefault || isInApplications;
            if (isPreferred) {
                // if it's preferred, remove any alternative
                NSUInteger idx = [[uniqueNamesAndURLs valueForKey:@"versionString"] indexOfObject:versionString];
                if (idx != NSNotFound) {
                    NSURL *altURL = [[uniqueNamesAndURLs objectAtIndex:idx] objectForKey:@"appURL"];
                    BOOL altIsInApplications = fileIsInApplicationsOrSystem(altURL);
                    if ([defaultAppURL isEqual:altURL] == NO && altIsInApplications == NO)
                        [uniqueNamesAndURLs removeObjectAtIndex:idx];
                    else if (isDefault == NO && altIsInApplications)
                        isPreferred = NO;
                }
            }
            if ([versionStrings containsObject:versionString ?: (id)[NSNull null]] == NO || isPreferred) {
                BDSKVersionNumber *versionNumber = versionString ? [[BDSKVersionNumber alloc] initWithVersionString:versionString] : nil;
                NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:appURL, @"appURL", versionString, @"versionString", shortVersionString, @"shortVersionString", versionNumber, @"versionNumber", nil];
                [versionStrings addObject:versionString ?: (id)[NSNull null]];
                [versionNumber release];
                [uniqueNamesAndURLs addObject:dict];
                [dict release];
            }
        }
        
        [versionStrings release];
        
        NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"versionNumber" ascending:NO selector:@selector(compareToVersionNumber:)];
        [uniqueNamesAndURLs sortUsingDescriptors:[NSArray arrayWithObject:sort]];
        [sort release];
    } else if (count == 1) {
        NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:[appURLs lastObject], @"appURL", nil];
        [uniqueNamesAndURLs addObject:dict];
        [dict release];
    }
    
    return uniqueNamesAndURLs;
}

- (void)replaceAllItemsWithApplicationsForURL:(NSURL *)aURL;
{    
    // assumption: last item is "Choose..." item; note that this item may be the only thing retaining aURL
    BDSKASSERT([self numberOfItems] > 0);
    while([self numberOfItems] > 1)
        [self removeItemAtIndex:0];
    
    NSZone *menuZone = [NSMenu menuZone];
    NSMenuItem *item;
    
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSArray *appURLs = [workspace editorAndViewerURLsForURL:aURL];
    NSURL *defaultAppURL = [workspace defaultEditorOrViewerURLForURL:aURL];
    NSArray *namesAndURLs;
    NSURL *appURL;
    NSString *appName;
    NSString *menuTitle;
    NSString *version;
    NSDictionary *dict;
    NSUInteger i, j, subCount, count = [appURLs count];
    
    for (i = 0; i < count; i++) {
        appURL = [appURLs objectAtIndex:i];
        appName = displayNameForURL(appURL);
        
        j = i + 1;
        while (j < count && [displayNameForURL([appURLs objectAtIndex:j]) isEqualToString:appName]) j++;
        namesAndURLs = copyUniqueVersionedNamesAndURLsForURLs([appURLs subarrayWithRange:NSMakeRange(i, j - i)], defaultAppURL);
        i = j - 1;
        
        subCount = [namesAndURLs count];
        for (j = 0; j < subCount; j++) {
            dict = [namesAndURLs objectAtIndex:j];
            appURL = [dict objectForKey:@"appURL"];
            menuTitle = appName;
            if ([appURL isEqual:defaultAppURL])
                menuTitle = [menuTitle stringByAppendingString:NSLocalizedString(@" (Default)", @"Menu item title, Need a single leading space")];
            if (subCount > 1 && (version = [dict objectForKey:@"shortVersionString"]))
                menuTitle = [menuTitle stringByAppendingFormat:@" (%@)", version];
            item = [[NSMenuItem allocWithZone:menuZone] initWithTitle:menuTitle action:@selector(openURLWithApplication:) keyEquivalent:@""];        
            [item setTarget:[BDSKOpenWithMenuController sharedInstance]];
            
            dict = [[NSDictionary alloc] initWithObjectsAndKeys:aURL, BDSKMenuTargetURL, appURL, BDSKMenuApplicationURL, nil];
            [item setRepresentedObject:dict];
            [dict release];
            
            // use NSWorkspace to get an image; using [NSImage imageForURL:] doesn't work for some reason
            [item setImageAndSize:[workspace iconForFile:[appURL path]]];
            if ([appURL isEqual:defaultAppURL]) {
                [self insertItem:[NSMenuItem separatorItem] atIndex:0];
                [self insertItem:item atIndex:0];
            } else {
                [self insertItem:item atIndex:[self numberOfItems] - 1];
            }
            [item release];
        }
        [namesAndURLs release];
    }
    
    if ([self numberOfItems] > 1 && [[self itemAtIndex:[self numberOfItems] - 2] isSeparatorItem] == NO)
        [self insertItem:[NSMenuItem separatorItem] atIndex:[self numberOfItems] - 1];
}

@end

#pragma mark -

/* Private singleton to act as target for the "Open With..." menu item, or run a modal panel to choose a different application.
*/

@implementation BDSKOpenWithMenuController

static id sharedOpenWithController = nil;

+ (id)sharedInstance
{
    if (sharedOpenWithController == nil)
        [[self alloc] init];
    return sharedOpenWithController;
}

+ (id)allocWithZone:(NSZone *)zone
{
    if (sharedOpenWithController == nil)
        sharedOpenWithController = [[super allocWithZone:zone] init];
    return sharedOpenWithController;
}

- (id)copyWithZone:(NSZone *)zone{ return self; }

- (void)encodeWithCoder:(NSCoder *)coder{}

- (id)initWithCoder:(NSCoder *)decoder { return self; }

- (id)retain { return self; }

- (id)autorelease { return self; }

- (void)release {}

- (NSUInteger)retainCount { return NSUIntegerMax; }

- (void)chooseApplicationToOpenURL:(NSURL *)aURL;
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setPrompt:NSLocalizedString(@"Choose Viewer", @"Prompt for Choose panel")];
    
    NSInteger rv = [openPanel runModalForDirectory:[[NSFileManager defaultManager] applicationsDirectory] 
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
    BDSKASSERT([menu numberOfItems] > 0);
    NSURL *theURL = [[[[menu itemArray] lastObject] representedObject] valueForKey:BDSKMenuTargetURL];
    BDSKASSERT(theURL != nil);
    if(theURL != nil)
        [menu replaceAllItemsWithApplicationsForURL:theURL];
}

// this is needed to prevent the menu from being updated just to look for key equivalents, 
// which would lead to considerable slowdown of key events
- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action{
    return NO;
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

@implementation NSMenuItem (BDSKImageExtensions)

- (void)setImageAndSize:(NSImage *)image;
{
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [layoutManager setTypesetterBehavior:NSTypesetterBehavior_10_4];
    CGFloat lineHeight = [layoutManager defaultLineHeightForFont:[NSFont menuFontOfSize:0]];
    [layoutManager release];
    NSSize dstSize = { lineHeight, lineHeight };
    NSSize srcSize = [image size];
    if (NSEqualSizes(srcSize, dstSize)) {
        [self setImage:image];
    } else {
        NSImage *newImage = [[NSImage alloc] initWithSize:dstSize];
        [newImage lockFocus];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [image drawInRect:NSMakeRect(0, 0, dstSize.width, dstSize.height) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
        [newImage unlockFocus];
        [self setImage:newImage];
        [newImage release];
    }
}
        
@end

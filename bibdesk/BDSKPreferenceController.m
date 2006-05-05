//
//  BDSKPreferenceController.m
//  Bibdesk
//
//  Created by Adam Maxwell on 05/04/06.
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

#import "BDSKPreferenceController.h"
#import "BDSKOverlay.h"
#import <OmniAppKit/OAPreferencesIconView.h>
#import <OmniAppKit/NSToolbar-OAExtensions.h>
#import <OmniAppKit/OAPreferenceClient.h>

// Implement this in pref clients to add search terms; could add in the plist, but that requires overriding another private method for registering client records (and Obj-C is easier than XML anyway)
@interface OAPreferenceClient (Search)
- (NSArray *)searchIndexTerms;
@end

@interface NSArray (Search)
- (BOOL)containsCaseInsensitiveSubstring:(NSString *)substring;
@end

@implementation NSArray (Search)

- (BOOL)containsCaseInsensitiveSubstring:(NSString *)substring;
{
    unsigned idx = [self count];
    id anObject;
    Class NSStringClass = [NSString class];
    while(idx--){
        anObject = [self objectAtIndex:idx];
        if([anObject isKindOfClass:NSStringClass] && [anObject rangeOfString:substring options:NSCaseInsensitiveSearch].length > 0)
            return YES;
    }
    return NO;
}

@end

@implementation BDSKPreferenceController

+ (id)sharedPreferenceController;
{
    static id sharedController = nil;

    if(nil == sharedController){
        if(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_3)
            sharedController = [[super sharedPreferenceController] retain];
        else
            sharedController = [[BDSKPreferenceController alloc] init];
    }
    return sharedController;
}

- (id)init
{
    if(self = [super init]){
        NSWindow *theWindow = [self window];
        overlayWindow = [[BDSKOverlayWindow alloc] initWithContentRect:[[theWindow contentView] frame] styleMask:[theWindow styleMask] backing:[theWindow backingType] defer:YES];
        NSView *view = [[BDSKSpotlightView alloc] initWithFrame:[[theWindow contentView] frame] delegate:self];
        [overlayWindow overlayView:[theWindow contentView]];
        [[overlayWindow contentView] addSubview:view];
        [view release];
        isSearchActive = NO;
    }
    return self;
}

- (void)dealloc
{
    [searchTerm release];
    [overlayWindow release];
    [super dealloc];
}

- (void)iconView:(OAPreferencesIconView *)iconView buttonHitAtIndex:(unsigned int)index;
{
    isSearchActive = NO;
    [[overlayWindow contentView] setNeedsDisplay:YES];
    [super iconView:iconView buttonHitAtIndex:index];
}

- (IBAction)showPreferencesPanel:(id)sender;
{
    [super showPreferencesPanel:sender];
    [overlayWindow orderFront:nil];
}

- (BOOL)isSearchActive { return isSearchActive; }

- (NSArray *)highlightRects;
{
    // we have an array of OAPreferencesIconViews; one per category (row)
    NSEnumerator *viewE = [preferencesIconViews objectEnumerator];
    OAPreferencesIconView *view;
    NSMutableArray *rectArray = [NSMutableArray arrayWithCapacity:10];
    
    while(view = [viewE nextObject]){
        NSArray *records = [view preferenceClientRecords];
        unsigned i, numberOfRecords = [records count];
    
        for(i = 0; i < numberOfRecords; i++){
            
            OAPreferenceClient *client = [self clientWithIdentifier:[[records objectAtIndex:i] identifier]];
            NSArray *array = nil;
            
            if([client respondsToSelector:@selector(searchIndexTerms)] && (array = [client searchIndexTerms]) != nil && [array containsCaseInsensitiveSubstring:searchTerm]){
                // this is a private method, but declared in the header
                NSRect rect = [view _boundsForIndex:i];
                
                // convert from view-local to window coordinates
                rect = [view convertRect:rect toView:nil];
                [rectArray addObject:[NSValue valueWithRect:NSInsetRect(rect, 5, 5)]];
            }
        }
    }
        
    return rectArray;
}

// override this private method so we can add the searchfield to the toolbar item array (don't call super)
- (void)_setupCustomizableToolbar;
{
    NSArray *constantToolbarItems, *defaultClients;
    NSMutableArray *allClients;
    NSEnumerator *enumerator;
    id aClientRecord;
    
    constantToolbarItems = [NSArray arrayWithObjects:@"OAPreferencesShowAll", @"OAPreferencesPrevious", @"OAPreferencesNext", NSToolbarSeparatorItemIdentifier, @"PreferencesSearchField", nil];
    
    defaultClients = [[NSUserDefaults standardUserDefaults] arrayForKey:@"FavoritePreferenceIdentifiers"];
    
    allClients = [[NSMutableArray alloc] initWithCapacity:[_clientRecords count]];
    enumerator = [_clientRecords objectEnumerator];
    while ((aClientRecord = [enumerator nextObject])) {
        [allClients addObject:[(OAPreferenceClientRecord *)aClientRecord identifier]];
    }
    
    defaultToolbarItems = [[constantToolbarItems arrayByAddingObjectsFromArray:defaultClients] retain];
    allowedToolbarItems = [[constantToolbarItems arrayByAddingObjectsFromArray:allClients] retain];
    
    toolbar = [[NSToolbar alloc] initWithIdentifier:@"OAPreferenceIdentifiers"];
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:NO]; // Don't store the configured items or new items won't show up!
    [toolbar setDelegate:self];
    [toolbar setAlwaysCustomizableByDrag:YES];
    [toolbar setShowsContextMenu:NO];
    [window setToolbar:toolbar];
    [toolbar setIndexOfFirstMovableItem:([constantToolbarItems count] - 1)];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)tb;
{
    NSMutableArray *array = [NSMutableArray arrayWithArray:[super toolbarSelectableItemIdentifiers:tb]];
    [array removeObject:@"PreferencesSearchField"];
    return array;
}

- (void)setSearchTerm:(NSString *)term;
{
    [searchTerm autorelease];
    searchTerm = [term copy];
}    

- (void)search:(id)sender;
{
    if([[[preferenceBox contentView] subviews] lastObject] != showAllIconsView){
        if([self respondsToSelector:@selector(_showAllIcons:)])
            [self performSelector:@selector(_showAllIcons:) withObject:nil];
        [[self window] makeFirstResponder:sender];
        // @@ fix selected range in cell
    }
    NSString *term = [sender stringValue];
    isSearchActive = ([term isEqualToString:@""] || nil == term) ? NO : YES;
    [self setSearchTerm:[sender stringValue]];
    [[overlayWindow contentView] setNeedsDisplay:YES];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)tb itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;
{
    NSToolbarItem *tbItem = nil;
    if([itemIdentifier isEqual:@"PreferencesSearchField"]){
        tbItem = [[NSToolbarItem alloc] initWithItemIdentifier:@"PreferencesSearchField"];
        NSSearchField *searchField = [[NSSearchField alloc] initWithFrame:NSMakeRect(0, 0, 30, 22)];
        [searchField setTarget:self];
        [searchField setAction:@selector(search:)];
        
        [tbItem setAction:@selector(search:)];
        [tbItem setTarget:self];
        [tbItem setMinSize:NSMakeSize(60, NSHeight([searchField frame]))];
        [tbItem setMaxSize:NSMakeSize(200,NSHeight([searchField frame]))];
        [tbItem setView:searchField];
        [searchField release];
        
        [tbItem setLabel:NSLocalizedString(@"Search", @"")];
        [tbItem setPaletteLabel:NSLocalizedString(@"Search", @"")];
        [tbItem setEnabled:YES];
        [tbItem autorelease];
    }        
    else tbItem = [super toolbar:tb itemForItemIdentifier:itemIdentifier willBeInsertedIntoToolbar:flag];
    
    return tbItem;
}

@end
